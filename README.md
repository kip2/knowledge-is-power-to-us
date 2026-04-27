# Obsidian → Quartz → GitHub Pages Template

Obsidian Vault に書いたノートのうち、`publish/` ディレクトリに置いたものだけを [Quartz v4](https://quartz.jzhao.xyz/) で静的サイト化して **GitHub Pages** に公開する仕組みを、すぐ使える形でまとめたテンプレートリポジトリ。

## このテンプレートが解決する課題

- Obsidian でノートを書いている。一部だけ Web で公開したい
- Quartz の素のテンプレを clone しただけだと、一般人にとって不要なファイル（`docs/`, `Dockerfile`, テスト用 CI 等）が大量に commit される

## 特徴

- **普段の編集はそのまま Obsidian で**: 公開したいノートだけを Vault の `publish/` に移動 → このテンプレートから作成したリポジトリコミットして push すれば公開される
- **`publish/` 配下だけが公開対象**: 残りの私的ノートはローカルにとどまる
- **GitHub Actions で自動デプロイ**: `main` ブランチへ push → 1〜3 分でサイト更新

## はじめかた（このテンプレートから自分のリポジトリを作る）

このリポジトリは GitHub の **テンプレートリポジトリ** として公開されている。`git clone` ではなく **「Use this template」ボタン** から自分用のリポジトリを作成して開始する。

### 1. テンプレートから自分のリポジトリを作成

1. このリポジトリのページ上部にある **「Use this template」 → 「Create a new repository」** をクリック
   ([テンプレートからの作成手順 - GitHub Docs](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template))
2. **Owner** と **Repository name**（例: `my-notes`）を入力して作成
   - Public / Private はお好みで（GitHub Pages を無料で使うなら Public 推奨）
3. 作成された自分のリポジトリの URL が `https://github.com/YOUR_NAME/my-notes` の形になる

> CLI 派の場合は `gh repo create YOUR_NAME/my-notes --template ORIGINAL_OWNER/publish-site-template --public --clone` でも同等。

### 2. 自分のリポジトリを clone

```bash
git clone https://github.com/YOUR_NAME/my-notes.git
cd my-notes
```

以降の手順（`.env` / `.publish.config` の作成、プレビュー、push）はすべてこの clone したディレクトリで作業する。

## 前提環境（ローカルで動作確認するため）

`http://localhost:8080` でプレビュー表示するために必要なツール。下記いずれかを満たせば良い。

- **Docker 版（推奨・最も簡単）**: Docker / Docker Compose のみ
- **ネイティブ版**: Node.js 22 LTS 以上 / git / rsync / bash 4 以上

> GitHub Pages へのデプロイは上記に加えて GitHub アカウントが必要。デプロイ自体は Actions が CI 上で行うので、ローカルにビルド環境がなくても push さえできれば公開可能。

## Docker で動かす

ホストに Node などを入れずに動かす最短ルート。clone 済みのリポジトリ直下で作業する。

### 1. `.env` を作成

リポジトリ直下に `.env` ファイルを作成し、自分の Vault `publish/` への絶対パスを書く。`.env` は `.gitignore` 済みなのでコミットされない。

```env
VAULT_PUBLISH_DIR=/home/USER/Documents/your-vault/publish
```

`.env.example` は設定可能な変数の一覧・説明が書かれた**参考用ファイル**。`USER_ID` / `GROUP_ID` などオプション項目を追加したいときに参照する。コピー必須ではない。

### 2. プレビュー起動

```bash
docker compose up preview          # http://localhost:8080 でプレビュー
docker compose run --rm build      # 静的ビルドのみ実行 (public/ を生成)
docker compose run --rm shell      # コンテナ内 bash で個別操作
```

初回は Docker イメージのビルド + Quartz の取得 + `npm ci` で 1〜2 分。2回目以降はキャッシュが効いて速い。

> **Vault が空でも動く**: 指定した Vault `publish/` に `.md` ファイルが1つも無い場合、`sync.sh` は同期をスキップして `content/` 同梱のサンプルページ（welcome / hello-quartz）を表示する。Vault にノートを追加して再度 `./sync.sh` するとサンプルが自分のノートで上書きされる。

## ネイティブで動かす

clone 済みのリポジトリ直下で作業する。

### 1. `.publish.config` を作成

リポジトリ直下に `.publish.config` ファイルを作成し、自分の Vault `publish/` への絶対パスを書く。`.gitignore` 済み。

```yaml
vault_publish_dir: /home/USER/Documents/your-vault/publish
```

`.publish.config.example` は YAML 形式での設定例とキー一覧を載せた**参考用ファイル**。

### 2. プレビュー

```bash
./bootstrap.sh                # Quartz を取得
npm ci                        # 依存をインストール
./sync.sh                     # Vault publish/ → content/
npx quartz build --serve      # http://localhost:8080 でプレビュー
```

## GitHub に push してデプロイ

ローカルで動作確認できたら GitHub に push する。

### 1. テンプレ向け記述を自分用に書き換え（**必須**）

公開する前に、必ず以下を実施してください。

- [ ] **`LICENSE`** の `{{YEAR}}` `{{Your Name}}` を自分の値に置換
- [ ] **`LICENSE` の Content License セクションを書き換え**（**最重要**）
  - テンプレートはコンテンツ用のライセンスをデフォルトで指定していません
  - サイトに掲載する記事・画像・スクショなど**自作コンテンツのライセンスは利用者本人が選んで明記する責任があります**
  - 参考になるライセンスの一覧は `LICENSE` 内のコメントに列挙されています（CC BY 4.0 / CC BY-SA 4.0 / CC BY-NC 4.0 / CC0 / All Rights Reserved 等）
  - スクショ・引用コード・他者画像など第三者素材を含める場合は、それらが元の権利者の所有物であることを明記してください
- [ ] **`README.md`** をあなたのサイト用の説明に書き換え

### 2. push

「Use this template」で作成したリポジトリは既に `origin` が設定されている。書き換えた内容を commit して push するだけ:

```bash
git add .
git commit -m "initial: my notes site"
git push
```

### 3. GitHub Pages を有効化（**必須・初回のみ**）

「Use this template」で作成したリポジトリでは **GitHub Pages がデフォルトで無効** になっている。push 後に Actions が走っても、deploy ステップで以下のようなエラーで止まるため、初回だけ手動で有効化する必要がある。

```
Error: Failed to create deployment (status: 404)
Ensure GitHub Pages has been enabled: https://github.com/YOUR_NAME/YOUR_REPO/settings/pages
```

手順:

1. リポジトリの **Settings → Pages** を開く
   （URL 直打ちなら `https://github.com/YOUR_NAME/YOUR_REPO/settings/pages`）
2. **Source** のドロップダウンを **「GitHub Actions」** に変更して保存
3. **Actions タブ** に戻って失敗していたワークフローを **「Re-run all jobs」** で再実行
   （または何かもう一度 commit して push すれば自動的に走る）

成功すると `https://YOUR_NAME.github.io/YOUR_REPO/` でサイトが見られる。次回以降の push ではこの手順は不要。詳細は [documents/SETUP.md](./documents/SETUP.md)。

## Daily workflow（運用が始まったら）

1. **Obsidian でノートを編集**し、公開したいものを Vault の `publish/` フォルダに入れる
2. **このリポジトリ側で同期 → コミット → プッシュ**すると、1〜3 分で GitHub Pages に反映される

```
┌─────────────────────────┐         ┌──────────────────────────┐         ┌──────────────────┐
│  Obsidian Vault         │         │  This repository         │         │  GitHub Pages    │
│                         │         │                          │         │                  │
│  notes/                 │         │  content/                │         │                  │
│  └── publish/  ─────────┼── sync ─┼─►  (同期される)          │         │                  │
│       └── *.md          │         │                          │         │                  │
└─────────────────────────┘         │  git commit && git push  │         │                  │
                                    │            │             │         │                  │
                                    │            ▼             │         │                  │
                                    │  GitHub Actions ─────────┼── deploy┼─► サイト更新     │
                                    └──────────────────────────┘         └──────────────────┘
```

### ラッパースクリプト（推奨）

毎回 `sync` → `git add` → `commit` → `push` を打つのが面倒なので、ラッパーを2つ用意している。両方とも Docker / native を自動判定する。

```bash
./do-sync.sh                            # 同期だけ実行（プレビュー確認用）
./do-push.sh "update: 新しい記事を追加"  # 同期 + commit + push を一括
./do-push.sh                            # commit message を対話的に入力
```

`./do-push.sh` は content/ に変更が無ければ何もせず終了し、`origin` が未設定なら commit までで止まる。明示的にモードを指定したい場合は `./do-push.sh --docker "msg..."` / `./do-push.sh --native "msg..."`。

### 個別コマンドで動かす場合

ネイティブ:

```bash
./sync.sh && git add content && git commit -m "update: ..." && git push
```

Docker:

```bash
docker compose run --rm shell bash -c "./sync.sh"
git add content && git commit -m "update: ..." && git push
```

## カスタマイズ

| 何を変えるか | どこを編集 |
|---|---|
| サイトタイトル・URL | `.publish.config` (ローカル) / GitHub Variables (CI) |
| レイアウト・テーマ | `overrides/quartz.layout.ts` `overrides/quartz.config.ts` |
| Quartz のバージョン | `quartz.version` を書き換えて `./bootstrap.sh --force` |
| コンテンツライセンス | `LICENSE` を書き換え（`LICENSE-Quartz.txt` には触らない） |

## Documents

- [documents/SETUP.md](./documents/SETUP.md) — 初回セットアップ詳細手順
- [documents/STRUCTURE.md](./documents/STRUCTURE.md) — リポジトリ構成・設計方針

## License

- **テンプレート本体** (`bootstrap.sh`, `sync.sh`, `overrides/`, scripts/configs) — [MIT License](./LICENSE)
- **Quartz 由来コード** — [MIT License](./LICENSE-Quartz.txt)
- **`content/` 配下のコンテンツ** — **利用者本人が選んで明記する**（後述）

### ⚠️ コンテンツのライセンスについて（必読）

このテンプレートは `content/` 配下に置く記事・画像・スクショなどに対するライセンスを **デフォルトで指定していません**。テンプレートを利用したら、`LICENSE` ファイル内の「Content License」セクションを **利用者本人が必ず編集** してください。

- `LICENSE` ファイルには参考用に主要ライセンスの一覧（CC BY 4.0 / CC BY-SA 4.0 / CC BY-NC 4.0 / CC0 / All Rights Reserved 等）と公式リンクが記載されています
- どのライセンスが適切かはコンテンツの性質と利用者の意図によって異なるため、**テンプレート提供者は推奨や保証を行いません**。利用者自身の判断で選択してください
- スクショ・他者のコード・引用文など **第三者素材を記事に含める場合**、それらは元の権利者の著作物のままです。自作コンテンツのライセンスは適用されないことを併記してください

詳細な書き換え手順は [GitHub に push してデプロイ § 1](#1-テンプレ向け記述を自分用に書き換え必須) を参照。
