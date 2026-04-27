# SETUP — Quartz サイトの初回構築手順

このリポジトリを一から動かすまでの完全な手順。Vault は別パスにあり、本リポジトリは Vault の外側に独立して置かれる前提で書く。

## 前提

利用方法は2通り。

### Docker 版（推奨）

- Docker
- Docker Compose v2 以上
- GitHub アカウント
- 公開用リポジトリの作成権限

これだけ。Node や rsync などはコンテナ側に内蔵されているので、ホストには不要。

### ネイティブ版

- Node.js **22 LTS 以上**（Quartz v4 が要求）
- npm（Node に同梱）
- git
- bash 4 以上（macOS 標準の bash 3 は `read -r -p` などで動くが、bash 5 以上推奨）
- rsync
- GitHub アカウント
- 公開用リポジトリの作成権限

Node.js が無い場合の例（nvm 使用）:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# シェル再起動後
nvm install 22
nvm use 22
node --version  # v22.x
```

## Docker での起動（最短ルート）

ネイティブ版で進める場合は次節「ステップ1」へ飛ばす。

### D-1. リポジトリ取得

```bash
git clone <this-template>.git my-notes
cd my-notes
```

### D-2. `.env` の作成

```bash
cp .env.example .env
$EDITOR .env
```

最低限 `VAULT_PUBLISH_DIR` を自分の Vault の `publish/` 絶対パスに変更する。

```bash
VAULT_PUBLISH_DIR=/home/USER/Documents/your-vault/publish

# 任意（Linux で root 所有ファイル生成を防ぐ）
USER_ID=1000
GROUP_ID=1000
```

### D-3. プレビュー起動

```bash
docker compose up preview
# ブラウザで http://localhost:8080
```

初回は Quartz の取得・依存インストールで 1〜2 分かかる。2回目以降は `node_modules/` `quartz/` がホスト側のディレクトリに残るので速い。

### D-4. 公開ビルド（任意）

CI と同じ手順を手元で再現する:

```bash
docker compose run --rm \
    -e QUARTZ_BASE_URL=YOUR_USER.github.io/YOUR_REPO \
    build
# public/ に静的サイトが生成される
```

### D-5. コンテナ内で個別作業

```bash
docker compose run --rm shell
# コンテナ内 bash で ./sync.sh や git や任意のコマンドを実行
```

GitHub への push と Pages 設定はネイティブ版と同じ（次節 ステップ7 以降を参照）。

---

以下、ネイティブ版で進める場合の詳細手順。

## ステップ1: 個別環境設定 `.publish.config` を作成

`sync.sh` が「どの Vault の publish/ を同期するか」を知る必要がある。

### 方法A: 設定ファイルで指定（推奨）

```bash
cd ~/Programfiles/Obsidian/publish-site
cp .publish.config.example .publish.config
$EDITOR .publish.config   # vault_publish_dir を自分のパスに変更
```

`.publish.config` の中身（YAML サブセット）:

```yaml
vault_publish_dir: /home/User/Documents/main_vault/publish
# preview_port: 8080         # （将来用、現状は未使用）
```

`.publish.config` は git 管理外（`.gitignore` 済み）。マシンごとに違う値を持てる。

### 方法B: 環境変数で指定

`~/.bashrc` などに:

```bash
export VAULT_PUBLISH_DIR="$HOME/Documents/main_vault/publish"
```

環境変数のほうが `.publish.config` より優先される。

### 方法C: デフォルト位置に置く

`$HOME/Documents/main_vault/publish` が存在すれば、何も設定しなくても動く。

## ステップ2: Quartz を取得・初期化

`bootstrap.sh` が:

1. 公式 Quartz リポジトリを `git clone` でこのディレクトリに展開
2. `overrides/` の設定ファイルで Quartz 標準設定を上書き
3. `.github/workflows/deploy.yml` を配置
4. clone 元の `.git` を削除

```bash
cd ~/Programfiles/Obsidian/publish-site
./bootstrap.sh
```

実行後の構造:

```
publish-site/
├── README.md
├── SETUP.md
├── bootstrap.sh
├── sync.sh
├── .publish.config         ← 自分の Vault パス等を YAML で記述（git 管理外）
├── .publish.config.example
├── content/                ← まだ空
├── overrides/              ← 自分の設定の保管庫
├── quartz/                 ← Quartz本体（bootstrap で展開）
├── quartz.config.ts        ← overrides から上書き済み
├── quartz.layout.ts        ← overrides から上書き済み
├── package.json
├── tsconfig.json
├── .github/workflows/deploy.yml
└── .gitignore
```

## ステップ3: サイト設定の調整

`quartz.config.ts` には個人情報を書かない設計。代わりに `.publish.config` を編集する。

```yaml
# .publish.config の該当行のコメントを外して値を入れる
page_title: "My Notes"
base_url: YOUR_USER.github.io/YOUR_REPO
```

`base_url` は GitHub Pages の URL から `https://` を取り末尾スラッシュ無しの形:

| GitHub Pages の URL | base_url の値 |
|---|---|
| `https://YOUR_USER.github.io/YOUR_REPO/` | `YOUR_USER.github.io/YOUR_REPO` |
| `https://notes.example.com/` | `notes.example.com` |

> **CI では設定不要**: GitHub Actions で走るビルドは `${{ github.repository_owner }}.github.io/${{ github.event.repository.name }}` から自動派生する。`.publish.config` の `base_url` はあくまでローカルプレビュー用。
>
> CI のページタイトルを変えたい場合は、GitHub の Settings → Secrets and variables → Actions → **Variables** で `QUARTZ_PAGE_TITLE` を設定する（未設定時はリポジトリ名）。

### 一時的に上書きしたい場合

環境変数で上書き可能。`.publish.config` の値より優先される。

```bash
QUARTZ_BASE_URL=preview.example.com npx quartz build
```

## ステップ4: 依存パッケージをインストール

```bash
npm install
```

## ステップ5: Vault → content/ 同期

```bash
./sync.sh
```

正常なら `🔄 sync` のあと `from:`/`to:` が表示され、ファイル一覧が出る。

## ステップ6: ローカルプレビュー

```bash
npx quartz build --serve
```

`http://localhost:8080` で確認。レイアウトに不満があれば `quartz.layout.ts` を編集。

## ステップ7: GitHub リポジトリを作成

GitHub にログインして新規リポジトリを作る:

- 名前: `notes` など好きなもの（`baseUrl` と一致させる）
- Public（GitHub Pages 無料枠は public のみ。Pro なら private 可）
- README/`.gitignore`/ライセンスの自動追加は **しない**（手元と衝突するため）

## ステップ8: 初回 push

```bash
cd ~/Programfiles/Obsidian/publish-site
git init
git add .
git commit -m "initial commit: quartz site"
git branch -M main
git remote add origin git@github.com:USERNAME/REPO_NAME.git
git push -u origin main
```

## ステップ9: GitHub Pages の設定

リポジトリページで:

1. **Settings** → **Pages**
2. **Source** を **GitHub Actions** に変更
3. Actions タブで build/deploy 成功を確認
4. **Settings → Pages** に戻ると公開 URL が表示される

数分以内にサイトが立ち上がる。

## 日々の運用ループ

```bash
# Obsidian で <vault>/publish/ のノートを編集

cd ~/Programfiles/Obsidian/publish-site
./sync.sh                        # publish/ → content/
git status                       # 何が変わったか確認
git add content
git commit -m "update: 記事タイトル"
git push
# 1〜3 分で公開反映
```

## 自動同期したい場合（オプション）

毎回 `./sync.sh` を手で打つのが面倒なら、git の **pre-commit hook** で自動化できる:

`.git/hooks/pre-commit` を作成:

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
"$REPO_ROOT/sync.sh"
git add content
```

実行権限を付与:

```bash
chmod +x .git/hooks/pre-commit
```

これで `git commit` するたびに `sync.sh` が走る。

## 複数 Vault に対応する

Vault Aと B で別サイトを運用したい場合:

```bash
# サイトA
git clone git@github.com:USER/notes-a.git ~/Programfiles/Obsidian/publish-site-a
cd ~/Programfiles/Obsidian/publish-site-a
cp .publish.config.example .publish.config
# .publish.config を開き vault_publish_dir: $HOME/Documents/vault-a/publish に編集
./bootstrap.sh && npm install && ./sync.sh

# サイトB
git clone git@github.com:USER/notes-b.git ~/Programfiles/Obsidian/publish-site-b
cd ~/Programfiles/Obsidian/publish-site-b
cp .publish.config.example .publish.config
# .publish.config を開き vault_publish_dir: $HOME/Documents/vault-b/publish に編集
./bootstrap.sh && npm install && ./sync.sh
```

## トラブルシューティング

### `npx quartz build` でエラー

- Node 22 LTS 以上か確認
- `rm -rf node_modules package-lock.json && npm install`

### CI が失敗する

- リポジトリ Settings → Pages → Source が "GitHub Actions" になっているか
- workflow ファイルパス: `.github/workflows/deploy.yml`
- Actions タブのログでエラー内容を確認

### サイトが 404

- `baseUrl` の値とリポジトリ名が一致しているか
- Pages のデプロイ完了から 1〜2 分待つ

### sync.sh で source not found

- `VAULT_PUBLISH_DIR` を `export` し忘れ、または `.publish.config` 未作成
- `.publish.config` の YAML が壊れている（`key: value` のフォーマットを再確認）
- パスにシンボリックリンクがある場合は実体パスを指定

### 画像が表示されない

- 画像が `<vault>/publish/` 配下にあるか
- `sync.sh` 後に `content/` 配下に画像が来ているか
- ノート内の `![[...]]` パスが publish/ 内で解決可能か

### 日本語ファイル名の URL がエンコードされて醜い

- `<vault>/publish/` 配下のファイル名を英数字に変える
- 例: `Unity農業ゲーム制作ガイド.md` → `unity-farming-game-guide.md`

## 参考

- Quartz v4 公式: https://quartz.jzhao.xyz/
- GitHub Actions Pages: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
- Node.js 22 LTS: https://nodejs.org/
