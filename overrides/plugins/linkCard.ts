import { Root, Paragraph, PhrasingContent, RootContent } from "mdast"
import { visit } from "unist-util-visit"
import { QuartzTransformerPlugin } from "../types"
import fs from "fs"
import path from "path"
import crypto from "crypto"

/**
 * LinkCard — 記事内に単独で貼られた外部 URL を OGP カードに変換する。
 *
 * Quartz v4 本体にはこの機能が無いため自作している（本体の popover は
 * `a.internal` のみが対象で、外部リンクには効かない）。
 *
 * 変換対象は「段落の中身が外部 URL のリンク1個だけ」の場合に限る。
 * 文中に埋め込まれたリンクや、`[表示テキスト](url)` のように別テキストを
 * 与えたリンクはそのまま残す。
 *
 *   https://example.com/article        ← カードになる
 *   詳細は https://example.com を参照   ← ならない（文中）
 *   [参考記事](https://example.com)     ← ならない（別テキスト指定）
 *
 * OGP はビルド時に取得し、`og-cache/` に URL ハッシュごとの JSON として保存する。
 * キャッシュがあればネットワークアクセスは発生しない。取得に失敗した場合は
 * 何もせず素のリンクのまま残すので、リンク先が落ちていてもビルドは通る。
 */

export interface Options {
  /** 1 URL あたりの取得タイムアウト (ms) */
  timeout: number
  /** キャッシュディレクトリ（リポジトリルートからの相対パス） */
  cacheDir: string
  /** キャッシュを無視して常に取得しにいく */
  ignoreCache: boolean
  /** OGP 取得時に送る User-Agent */
  userAgent: string
  /** カードにサムネイル画像を表示する */
  showThumbnail: boolean
}

const defaultOptions: Options = {
  timeout: 8000,
  cacheDir: "og-cache",
  ignoreCache: false,
  userAgent: "Mozilla/5.0 (compatible; QuartzLinkCard/1.0; +https://quartz.jzhao.xyz/)",
  showThumbnail: true,
}

interface OgData {
  url: string
  title?: string
  description?: string
  image?: string
  siteName?: string
  /** 取得に失敗した URL も記録して、ビルドのたびに再試行しないようにする */
  failed?: boolean
}

// ── HTML から meta タグを拾う ────────────────────────────────────
// 外部 HTML のパースに専用ライブラリを足したくないので正規表現で処理する。
// property/name のどちらでも、属性の順序が逆でも拾えるようにしている。

const META_RE = /<meta\s+([^>]*?)\/?>/gi
const ATTR_RE = /([a-zA-Z-:]+)\s*=\s*("([^"]*)"|'([^']*)'|([^\s"'>]+))/g

function parseMetaTags(html: string): Map<string, string> {
  const result = new Map<string, string>()
  // <head> 以降は不要なので、あれば </head> までに絞って走査量を減らす
  const headEnd = html.search(/<\/head>/i)
  const scope = headEnd === -1 ? html.slice(0, 100_000) : html.slice(0, headEnd)

  for (const tag of scope.matchAll(META_RE)) {
    const attrs = new Map<string, string>()
    for (const attr of tag[1].matchAll(ATTR_RE)) {
      const value = attr[3] ?? attr[4] ?? attr[5] ?? ""
      attrs.set(attr[1].toLowerCase(), value)
    }
    const key = attrs.get("property") ?? attrs.get("name")
    const content = attrs.get("content")
    if (key && content && !result.has(key.toLowerCase())) {
      result.set(key.toLowerCase(), content)
    }
  }
  return result
}

function parseTitleTag(html: string): string | undefined {
  return html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1]?.trim()
}

const ENTITIES: Record<string, string> = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: " ",
  "#39": "'",
}

function decodeEntities(s: string): string {
  return s
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(parseInt(code, 16)))
    .replace(/&([a-z]+|#\d+);/gi, (match, name) => ENTITIES[name.toLowerCase()] ?? match)
}

function clean(s: string | undefined, maxLength: number): string | undefined {
  if (!s) return undefined
  const normalized = decodeEntities(s).replace(/\s+/g, " ").trim()
  if (!normalized) return undefined
  return normalized.length > maxLength ? normalized.slice(0, maxLength) + "…" : normalized
}

// ── キャッシュ ──────────────────────────────────────────────────
// ワーカースレッドが並列でパースするため、単一の JSON ファイルにまとめると
// 書き込みが競合する。URL ごとに別ファイルへ書くことで競合を避けている。

function cachePathFor(cacheDir: string, url: string): string {
  const hash = crypto.createHash("sha256").update(url).digest("hex").slice(0, 16)
  return path.join(cacheDir, `${hash}.json`)
}

function readCache(cacheDir: string, url: string): OgData | undefined {
  try {
    const raw = fs.readFileSync(cachePathFor(cacheDir, url), "utf8")
    const parsed = JSON.parse(raw) as OgData
    // ハッシュ衝突や手編集による取り違えを防ぐ
    return parsed.url === url ? parsed : undefined
  } catch {
    return undefined
  }
}

function writeCache(cacheDir: string, data: OgData): void {
  try {
    fs.mkdirSync(cacheDir, { recursive: true })
    const target = cachePathFor(cacheDir, data.url)
    // 同一 URL を複数ワーカーが同時に書いても壊れないよう、
    // 一時ファイルに書いてから rename する
    const tmp = `${target}.${process.pid}.tmp`
    fs.writeFileSync(tmp, JSON.stringify(data, null, 2) + "\n", "utf8")
    fs.renameSync(tmp, target)
  } catch (err) {
    console.log(`\nLinkCard: キャッシュの書き込みに失敗しました (${data.url}): ${err}`)
  }
}

// ── OGP 取得 ────────────────────────────────────────────────────

async function fetchOgData(url: string, opts: Options): Promise<OgData> {
  const response = await fetch(url, {
    redirect: "follow",
    signal: AbortSignal.timeout(opts.timeout),
    headers: {
      "User-Agent": opts.userAgent,
      Accept: "text/html,application/xhtml+xml",
    },
  })

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`)
  }

  const contentType = response.headers.get("Content-Type") ?? ""
  if (!contentType.includes("html")) {
    throw new Error(`HTML ではありません (Content-Type: ${contentType})`)
  }

  const html = await response.text()
  const meta = parseMetaTags(html)
  const finalUrl = response.url || url

  const image = meta.get("og:image") ?? meta.get("twitter:image")

  return {
    url,
    title: clean(meta.get("og:title") ?? meta.get("twitter:title") ?? parseTitleTag(html), 120),
    description: clean(meta.get("og:description") ?? meta.get("description"), 160),
    // og:image が相対パスの場合があるので最終 URL を基準に絶対化する
    image: image ? new URL(decodeEntities(image), finalUrl).toString() : undefined,
    siteName: clean(meta.get("og:site_name"), 60) ?? new URL(finalUrl).hostname,
  }
}

async function resolveOgData(url: string, opts: Options): Promise<OgData | undefined> {
  if (!opts.ignoreCache) {
    const cached = readCache(opts.cacheDir, url)
    if (cached) return cached.failed ? undefined : cached
  }

  try {
    const data = await fetchOgData(url, opts)
    writeCache(opts.cacheDir, data)
    return data
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err)
    console.log(`\nLinkCard: OGP を取得できませんでした (${url}): ${reason}`)
    console.log(`  素のリンクとして出力します。再試行するには ${opts.cacheDir}/ の該当ファイルを削除してください。`)
    writeCache(opts.cacheDir, { url, failed: true })
    return undefined
  }
}

// ── mdast ノードの判定と組み立て ────────────────────────────────

/** 段落の中身が「外部 URL のリンク1個」だけかを判定し、その URL を返す */
function bareExternalLinkUrl(node: Paragraph): string | undefined {
  const children = node.children.filter(
    (child: PhrasingContent) => !(child.type === "text" && child.value.trim() === ""),
  )
  if (children.length !== 1) return undefined

  const link = children[0]
  if (link.type !== "link") return undefined
  if (!/^https?:\/\//i.test(link.url)) return undefined

  // 表示テキストが URL 自体でない（= 別名を付けたリンク）ならカードにしない
  if (link.children.length !== 1) return undefined
  const label = link.children[0]
  if (label.type !== "text") return undefined
  const normalized = label.value.trim().replace(/\/$/, "")
  if (normalized !== link.url.trim().replace(/\/$/, "")) return undefined

  return link.url
}

type HastChild = {
  type: "element"
  tagName: string
  properties: Record<string, unknown>
  children: HastChild[] | { type: "text"; value: string }[]
}

function textEl(tagName: string, className: string, value: string): HastChild {
  return {
    type: "element",
    tagName,
    properties: { className: [className] },
    children: [{ type: "text", value }],
  }
}

/**
 * カード用のノードを組み立てる。
 *
 * 生 HTML 文字列（mdast の `html` ノード）は rehype-raw がパイプラインに
 * 入っているときしか描画されない。このリポジトリは
 * ObsidianFlavoredMarkdown を `enableInHtmlEmbed: false` で使っているため、
 * hName / hProperties / hChildren で hast を直接指定する。
 */
function buildCardNode(data: OgData, opts: Options): RootContent {
  const body: HastChild[] = []

  body.push(textEl("div", "og-card-title", data.title ?? data.url))
  if (data.description) {
    body.push(textEl("div", "og-card-description", data.description))
  }
  if (data.siteName) {
    body.push(textEl("div", "og-card-site", data.siteName))
  }

  const children: HastChild[] = [
    {
      type: "element",
      tagName: "div",
      properties: { className: ["og-card-body"] },
      children: body,
    },
  ]

  if (opts.showThumbnail && data.image) {
    children.push({
      type: "element",
      tagName: "div",
      properties: { className: ["og-card-thumbnail"] },
      children: [
        {
          type: "element",
          tagName: "img",
          properties: {
            src: data.image,
            alt: "",
            loading: "lazy",
            // リンク先の画像を直接参照するため、リファラは送らない
            referrerPolicy: "no-referrer",
          },
          children: [],
        },
      ],
    })
  }

  return {
    type: "paragraph",
    children: [],
    data: {
      hName: "a",
      hProperties: {
        // CrawlLinks が付ける `external` クラスと外部リンクアイコンは
        // CSS 側で打ち消している
        className: ["og-card"],
        href: data.url,
        target: "_blank",
        rel: "noopener noreferrer",
      },
      hChildren: children,
    },
  } as unknown as RootContent
}

// ── プラグイン本体 ──────────────────────────────────────────────

export const LinkCard: QuartzTransformerPlugin<Partial<Options>> = (userOpts) => {
  const opts = { ...defaultOptions, ...userOpts }

  return {
    name: "LinkCard",
    markdownPlugins() {
      return [
        () => {
          return async (tree: Root, _file) => {
            // URL の収集と置換を分ける。visit は同期なので、
            // 先に対象を集めてから並列で取得する。
            const targets: { node: Paragraph; url: string }[] = []
            visit(tree, "paragraph", (node: Paragraph) => {
              const url = bareExternalLinkUrl(node)
              if (url) targets.push({ node, url })
            })

            if (targets.length === 0) return

            const resolved = await Promise.all(
              targets.map(({ url }) => resolveOgData(url, opts)),
            )

            targets.forEach(({ node }, i) => {
              const data = resolved[i]
              // 取得できなかったものは素のリンクのまま残す
              if (!data) return
              const card = buildCardNode(data, opts) as unknown as Paragraph
              node.data = card.data
              node.children = []
            })
          }
        },
      ]
    },
  }
}
