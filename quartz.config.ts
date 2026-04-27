import { QuartzConfig } from "./quartz/cfg"
import * as Plugin from "./quartz/plugins"
import { readFileSync, existsSync } from "fs"
import { dirname, join } from "path"
import { fileURLToPath } from "url"

/**
 * publish-site の Quartz 設定。
 * bootstrap.sh 実行時に Quartz 標準の quartz.config.ts を上書きする。
 *
 * 個人情報（GitHub ユーザー名・リポジトリ名・サイトタイトル）は
 * このファイルに直接書かず、以下の優先順で解決される:
 *
 *   1. 環境変数 QUARTZ_BASE_URL / QUARTZ_PAGE_TITLE
 *   2. .publish.config の base_url / page_title
 *   3. フォールバック ("localhost:8080" / "Notes")
 *
 * GitHub Actions では deploy.yml が github.repository から自動派生して
 * QUARTZ_BASE_URL を env にセットするため、リポジトリ secret は不要。
 *
 * 詳しい設定項目は https://quartz.jzhao.xyz/configuration を参照。
 */

const __dirname = dirname(fileURLToPath(import.meta.url))
const PUBLISH_CONFIG_PATH = join(__dirname, ".publish.config")

function parsePublishConfig(): Record<string, string> {
  if (!existsSync(PUBLISH_CONFIG_PATH)) return {}
  const content = readFileSync(PUBLISH_CONFIG_PATH, "utf-8")
  const result: Record<string, string> = {}
  for (const raw of content.split("\n")) {
    const line = raw.trim()
    if (!line || line.startsWith("#")) continue
    const colonIdx = line.indexOf(":")
    if (colonIdx < 0) continue
    const key = line.slice(0, colonIdx).trim()
    let value = line.slice(colonIdx + 1).trim()
    if (!value.includes('"') && !value.includes("'")) {
      const hashIdx = value.indexOf("#")
      if (hashIdx >= 0) value = value.slice(0, hashIdx).trim()
    }
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1)
    }
    result[key] = value
  }
  return result
}

const userConfig = parsePublishConfig()

const PAGE_TITLE =
  process.env.QUARTZ_PAGE_TITLE ?? userConfig.page_title ?? "Notes"
const BASE_URL =
  process.env.QUARTZ_BASE_URL ?? userConfig.base_url ?? "localhost:8080"

if (BASE_URL === "localhost:8080") {
  console.warn(
    "⚠ baseUrl が未設定のため 'localhost:8080' で動作中。\n" +
      "   本番ビルドには QUARTZ_BASE_URL 環境変数か、\n" +
      "   .publish.config の base_url を設定してください。",
  )
}

const config: QuartzConfig = {
  configuration: {
    pageTitle: PAGE_TITLE,
    pageTitleSuffix: "",
    enableSPA: true,
    enablePopovers: true,
    analytics: null,
    locale: "ja-JP",
    baseUrl: BASE_URL,
    ignorePatterns: ["private", "templates", ".obsidian"],
    defaultDateType: "modified",
    theme: {
      fontOrigin: "googleFonts",
      cdnCaching: true,
      typography: {
        header: "Schibsted Grotesk",
        body: "Source Sans Pro",
        code: "IBM Plex Mono",
      },
      colors: {
        lightMode: {
          light: "#faf8f8",
          lightgray: "#e5e5e5",
          gray: "#b8b8b8",
          darkgray: "#4e4e4e",
          dark: "#2b2b2b",
          secondary: "#284b63",
          tertiary: "#84a59d",
          highlight: "rgba(143, 159, 169, 0.15)",
          textHighlight: "#fff23688",
        },
        darkMode: {
          light: "#161618",
          lightgray: "#393639",
          gray: "#646464",
          darkgray: "#d4d4d4",
          dark: "#ebebec",
          secondary: "#7b97aa",
          tertiary: "#84a59d",
          highlight: "rgba(143, 159, 169, 0.15)",
          textHighlight: "#b3aa0288",
        },
      },
    },
  },
  plugins: {
    transformers: [
      Plugin.FrontMatter(),
      Plugin.CreatedModifiedDate({
        priority: ["frontmatter", "git", "filesystem"],
      }),
      Plugin.SyntaxHighlighting({
        theme: {
          light: "github-light",
          dark: "github-dark",
        },
        keepBackground: false,
      }),
      Plugin.ObsidianFlavoredMarkdown({ enableInHtmlEmbed: false }),
      Plugin.GitHubFlavoredMarkdown(),
      Plugin.TableOfContents(),
      Plugin.CrawlLinks({ markdownLinkResolution: "shortest" }),
      Plugin.Description(),
      Plugin.Latex({ renderEngine: "katex" }),
    ],
    filters: [Plugin.RemoveDrafts()],
    emitters: [
      Plugin.AliasRedirects(),
      Plugin.ComponentResources(),
      Plugin.ContentPage(),
      Plugin.FolderPage(),
      Plugin.TagPage(),
      Plugin.ContentIndex({
        enableSiteMap: true,
        enableRSS: true,
      }),
      Plugin.Assets(),
      Plugin.Static(),
      Plugin.Favicon(),
      Plugin.NotFoundPage(),
      Plugin.CustomOgImages(),
    ],
  },
}

export default config
