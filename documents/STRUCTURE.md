# STRUCTURE — リポジトリ構成と運用方針

このリポジトリは Quartz v4 の枠組みを取り込んで個人の Obsidian Vault を公開するサイトの実装。本ドキュメントは「なぜこのファイルがあるのか/ないのか」「何を消したか」「ライセンス・ブランチの方針」を記録する。

## 1. ディレクトリ構成

```
<your-repo>/
├── [git で追跡される]
│   ├── .github/workflows/deploy.yml    ← GitHub Actions: main push で Pages デプロイ
│   ├── content/                        ← Quartz が読むサイトソース (sync.sh で埋める)
│   │   └── .gitkeep
│   ├── overrides/                      ← Quartz 標準ファイルを差し替えるための保管庫
│   │   ├── deploy.yml
│   │   ├── quartz.config.ts
│   │   └── quartz.layout.ts
│   ├── README.md                       ← クイックスタート
│   ├── documents/SETUP.md              ← 詳細セットアップ手順
│   ├── documents/STRUCTURE.md          ← このファイル
│   ├── LICENSE                         ← テンプレ同梱のプレースホルダ（利用者が必ず編集）
│   ├── LICENSE-Quartz.txt              ← Quartz MIT License (再配布の courtesy)
│   ├── bootstrap.sh                    ← Quartz 取得・overrides 適用
│   ├── sync.sh                         ← Vault publish/ → content/ 同期
│   ├── quartz.version                  ← 取得する Quartz のタグ/コミット
│   ├── .publish.config.example         ← .publish.config のテンプレ
│   ├── Dockerfile                      ← Node 22 + git + rsync の最小イメージ
│   ├── docker-compose.yml              ← preview/build/shell サービス定義
│   ├── .dockerignore                   ← docker build 用の除外パターン
│   ├── .env.example                    ← Docker 用環境変数のテンプレ
│   ├── .gitignore
│   ├── .gitattributes                  ← EOL を LF に統一
│   ├── .node-version                   ← nvm/asdf 用 Node バージョン指示
│   ├── .npmrc                          ← engine-strict=true
│   └── package.json / package-lock.json ← Quartz 依存（npm ci で再現）
│
└── [git ignore — bootstrap.sh / npm / build が生成]
    ├── quartz/                         ← Quartz エンジン本体 (bootstrap.sh が取得)
    ├── node_modules/                   ← npm install 後
    ├── public/                         ← quartz build 出力
    ├── .quartz-cache/                  ← ビルドキャッシュ
    ├── quartz.config.ts                ← overrides/quartz.config.ts から bootstrap が生成
    ├── quartz.layout.ts                ← overrides/quartz.layout.ts から bootstrap が生成
    ├── globals.d.ts / index.d.ts       ← Quartz upstream の TS ambient 型定義
    ├── tsconfig.json                   ← Quartz upstream の TS ビルド設定
    ├── .prettierrc / .prettierignore   ← Quartz upstream のフォーマッタ設定
    ├── .publish.config                 ← マシン依存設定（個人情報含む）
    └── .env                            ← Docker 用の VAULT_PUBLISH_DIR 等
```

### Docker 関連ファイルの役割

| ファイル | 役割 |
|---|---|
| `Dockerfile` | Node 22 + git + rsync + bash を含む実行環境イメージ |
| `docker-compose.yml` | 3サービス（`preview` 8080公開 / `build` 静的ビルドのみ / `shell` 対話シェル）を定義 |
| `.env.example` | `VAULT_PUBLISH_DIR` ほか環境変数のテンプレ。`.env` にコピーして編集 |
| `.dockerignore` | `docker build` を直接実行する場合の除外設定 |

## 2. 削除した Quartz 由来ファイル

`bootstrap.sh` は Quartz 公式リポジトリを clone するが、Quartz の枠組み開発用に存在する一部ファイルはサイト運用には不要なので削除している。

| 削除対象 | 削除理由 |
|---|---|
| `docs/` (91 files, 2.3MB) | Quartz framework 自身のドキュメント。`content/` ではないので**サイトには表示されない**死蔵ファイル |
| `CODE_OF_CONDUCT.md` | Quartz プロジェクトの行動規範。サイト運用には無関係 |
| `.github/FUNDING.yml` | Quartz 開発者向け寄付リンク |
| `.github/dependabot.yml` | Quartz 自身の依存更新（残しておくと意図しない PR が大量発生する） |
| `.github/ISSUE_TEMPLATE/` | Quartz の Issue テンプレ |
| `.github/pull_request_template.md` | Quartz の PR テンプレ |
| `.github/workflows/build-preview.yaml` | Quartz の PR プレビュー CI |
| `.github/workflows/ci.yaml` | Quartz の単体テスト CI |
| `.github/workflows/deploy-preview.yaml` | Quartz のプレビューデプロイ |
| `.github/workflows/docker-build-push.yaml` | Quartz の Docker イメージ公開 |

`bootstrap.sh` は再実行時にもこれらを自動で削除する（`# Quartz リポジトリ自身のファイル...` セクション参照）。

## 3. 残すファイルの理由

| ファイル | 残す理由 |
|---|---|
| `package.json` / `package-lock.json` | `npm ci` で同一依存関係を再現するため CI に必須 |
| `LICENSE-Quartz.txt` | Quartz 配布物の著作権表示を保持する courtesy ファイル（gitignore でも法的にOKだが、明示しておく方が筋が良い） |
| `.gitattributes` (`* text=auto eol=lf`) | クロスプラットフォームで EOL を統一 |
| `.node-version` (`v22.16.0`) | nvm/asdf でローカル Node バージョン自動選択 |
| `.npmrc` (`engine-strict=true`) | Node バージョン要件を強制 |
| `quartz.version` | Quartz の取得バージョンを pin（再現可能ビルドのため） |
| `Dockerfile` | Docker 運用のための実行環境（自前イメージ）。bootstrap.sh の skip-existing で温存される |

### 3-A. リポジトリに含めず bootstrap で再生成するもの

以下は Quartz upstream または `overrides/` から `./bootstrap.sh` 実行時に自動生成されるため、リポジトリに commit せず `.gitignore` 対象とする。初回チェックアウト直後はこれらが存在しないため、IDE の TypeScript 解析や `npx quartz build` を試す前に必ず `./bootstrap.sh` を実行する必要がある。

| ファイル | 生成元 |
|---|---|
| `quartz.config.ts` / `quartz.layout.ts` | `overrides/` から bootstrap.sh がコピー |
| `globals.d.ts` / `index.d.ts` / `tsconfig.json` | Quartz upstream の git clone から取得 |
| `.prettierrc` / `.prettierignore` | 同上（任意のフォーマッタ設定） |

## 3-A. `quartz/` を gitignore する設計

Quartz エンジン本体（`quartz/`、32MB / 171 ファイル）はベンダーコードであり、自分で改変しない限りリポジトリに commit する必要がない。本リポジトリでは:

- `quartz/` を `.gitignore` で追跡対象外にする
- `bootstrap.sh` が `quartz.version` の指定バージョンを `git clone` で取得する
- ローカル: 初回 `./bootstrap.sh` 実行で `quartz/` が出現
- CI: deploy.yml の `Fetch Quartz framework` ステップで毎回取得

利点:
- リポジトリサイズが大幅に小さくなる
- `git log` / `git blame` がノイズなく自分の変更だけを示す
- Quartz をアップデートするには `quartz.version` の値を書き換えて `./bootstrap.sh --force`

注意点:
- ローカルで初回 clone した直後はビルドできない（`./bootstrap.sh` が必須）
- CI で Quartz を fetch する分、ビルド時間が +5〜10 秒
- `package.json` / `package-lock.json` は引き続き commit しているため、Quartz が大きく構造変更すると stale になる可能性。`./bootstrap.sh --force` で再生成する

## 4. ライセンス方針

このテンプレートは **コード（テンプレ由来のスクリプト・設定）と コンテンツ（`content/` 配下）でライセンスの扱いを分ける** 設計になっている。コードは MIT を提供する一方、コンテンツのライセンスは**テンプレート提供者側では指定しない**（利用者が選んで明記する責任を持つ）。

### コンテンツ — 利用者が必ず選んで明記する

`content/` 配下のテキスト・図表、サイトに表示される本文のライセンスについて、**テンプレートはデフォルト値を持たず、推奨も保証も行わない**。テンプレートを利用したら、`LICENSE` ファイル内の「Content License」セクションを **利用者本人が編集して**、自分が選んだライセンスの正式な文面を記入する必要がある。

`LICENSE` には参考用に世間で広く使われているライセンスの一覧（情報提供のみ・推奨ではない）が記載されている:

- Creative Commons Attribution 4.0 International (CC BY 4.0)
- Creative Commons Attribution-ShareAlike 4.0 (CC BY-SA 4.0)
- Creative Commons Attribution-NonCommercial 4.0 (CC BY-NC 4.0)
- Creative Commons Zero / Public Domain Dedication (CC0 1.0)
- All Rights Reserved（明示的な許諾なし）

どれが適切かはコンテンツの性質と利用者の意図によって異なるため、利用者自身の判断で選択する。各ライセンスの正式な文面・適用条件は公式ドキュメントを参照のこと。

**第三者素材の扱い**: スクリーンショット・引用コード・他者画像など第三者の著作物を記事に含める場合、それらは元の権利者の所有物のままで、自作コンテンツのライセンスは適用されない。`LICENSE` 本文にはその旨も併記する。

### コード — MIT License

`quartz/` および Quartz 由来のコード一式は **MIT License**（`LICENSE-Quartz.txt`、原著作権者: jackyzha0, 2021）で配布されている。MIT は再配布時の著作権表示保持を義務付けるため、このファイルは削除しない。

テンプレ由来の自作コード（`bootstrap.sh`, `sync.sh`, `overrides/`, `.publish.config.example` 等）も MIT License で提供する。利用者が追加で書いたスクリプトについても、特に明記しない限り MIT を引き継ぐ前提（変更したい場合は `LICENSE` の Code License セクションを書き換える）。

## 5. ブランチ運用

- **`main`**: 唯一のブランチ。push されると GitHub Actions が走り Pages にデプロイされる
- `master` などの他ブランチは使わない
- `.github/workflows/deploy.yml` の trigger は `main` のみ

ブランチ命名は GitHub の現行デフォルトに合わせて `main` を採用（旧称 `master` は廃止）。

## 6. 個人情報・秘密情報の扱い

GitHub ユーザー名・リポジトリ名・サイトタイトルは `quartz.config.ts` に直接書かない設計:

| 値 | ローカル | CI (GitHub Actions) |
|---|---|---|
| baseUrl | `.publish.config` の `base_url`、または env `QUARTZ_BASE_URL` | `${{ github.repository_owner }}.github.io/${{ github.event.repository.name }}` から自動派生 |
| pageTitle | `.publish.config` の `page_title`、または env `QUARTZ_PAGE_TITLE` | repo variable `vars.QUARTZ_PAGE_TITLE`、未設定時はリポジトリ名 |
| Vault 同期元 | `.publish.config` の `vault_publish_dir`、または env `VAULT_PUBLISH_DIR` | （CI では不使用、`content/` に同期済みの内容をビルド） |

`.publish.config` は `.gitignore` 済みでリポジトリには commit されない。CI は GitHub のコンテキストから自動派生するため repository secret も不要。

## 6-A. Docker サポート

Node 22 やその他ツールをホストに入れたくない利用者向けに、Docker による実行環境を同梱している。

### 提供サービス

| サービス | 役割 | 使い方 |
|---|---|---|
| `preview` | ホットリロード付きプレビュー (port 8080) | `docker compose up preview` |
| `build` | 静的ビルドのみ (`public/` 生成) | `docker compose run --rm build` |
| `shell` | コンテナ内 bash で個別作業 | `docker compose run --rm shell` |

### 設計判断

- **bind mount で `.:/app` をマウント**: ホスト側で編集した変更が即反映される。`quartz/` `node_modules/` `public/` もホスト側に出現するためキャッシュが効く
- **Vault は readonly マウント**: `${VAULT_PUBLISH_DIR}:/vault-publish:ro`。コンテナから Vault を破壊することはない
- **ベースイメージは公式 `node:22-bookworm-slim`**: bootstrap.sh / sync.sh / quartz が必要とする git・rsync・bash のみ追加
- **`USER_ID` / `GROUP_ID` を `.env` で指定可**: Linux で生成ファイルが root 所有になるのを避ける
- **CI とは別系統**: GitHub Actions は Docker を使わず ubuntu-22.04 ランナー直接で動かす（より速い）

### Docker と native の関係

両者は同じ `bootstrap.sh` `sync.sh` `package.json` `quartz.version` を使う。Docker はこれらを Node 22 入りコンテナで実行するラッパに過ぎないため、**どちらで動かしてもサイトの出力は同一**になる。

## 7. デプロイ動線

```
Vault publish/ で編集
      │
      ▼
./sync.sh                ← rsync で content/ にコピー
      │
      ▼
git commit + git push    ← main ブランチへ
      │
      ▼
GitHub Actions
  ├─ checkout
  ├─ ./bootstrap.sh --ci ← quartz.version の指定で quartz/ を取得
  ├─ npm ci
  ├─ npx quartz build    ← QUARTZ_BASE_URL は github コンテキストから設定
  └─ deploy-pages
      │
      ▼
GitHub Pages (https://YOUR_USER.github.io/YOUR_REPO/)
```

## 8. 主要メンテナンスポイント

- **Quartz をアップデートしたい**: `quartz.version` を書き換え → `./bootstrap.sh --force` → `npm install` → 動作確認 → commit
- **コンテンツライセンスを設定/変えたい**: `LICENSE` の「Content License」セクションを書き換え（テンプレ初回利用時の必須作業でもある）。`LICENSE-Quartz.txt` には触らない
- **CI で動かす Node バージョンを変えたい**: `.github/workflows/deploy.yml` の `node-version` と `.node-version` を揃えて変更
- **新しい Vault に切り替えたい**: `.publish.config` の `vault_publish_dir` を変更
- **個人情報をリポジトリ secret に出したくない**: 既にそうなっている。`.publish.config` 経由でローカルだけに残る
- **このリポジトリを別マシンで clone した**: `./bootstrap.sh` → `npm ci` → `cp .publish.config.example .publish.config` → 編集 → `./sync.sh`
- **Docker で動かしたい**: `cp .env.example .env` → `VAULT_PUBLISH_DIR` を編集 → `docker compose up preview`
- **Docker と native を切り替えたい**: 両者は同じ設定ファイル群を共有しているので、自由に行き来可能。`.env` (Docker) と `.publish.config` (native) はどちらか片方でも、両方併存でも動く
