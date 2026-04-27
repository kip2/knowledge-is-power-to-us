<!-- ENV_NOT_CONFIGURED_BANNER:START -->
> [!error] ❌ `.env` ファイルが未設定です（Docker フォールバックモード）
>
> リポジトリ直下に `.env` を作成し、自分の Vault `publish/` への絶対パスを記入してください:
>
> ```env
> VAULT_PUBLISH_DIR=/path/to/your/vault/publish
> ```
>
> 現在は `./.no-vault-stub`（空のスタブディレクトリ）を仮の Vault としてマウントしているため、
> 同期は行われず、テンプレ同梱のサンプル `content/` がそのまま表示されています。
>
> `.env` を作成して `docker compose down && docker compose up preview` で再起動すると、
> Vault のノートが反映されてこの警告は消えます。
<!-- ENV_NOT_CONFIGURED_BANNER:END -->

> [!warning] ⚠️ これはテンプレート同梱のサンプルページです
>
> このページは `content/index.md`（テンプレートのバンドル）から生成されています。Vault `publish/` に `.md` ファイルが無い場合のフォールバックとして表示されています。
>
> **本番公開する前に必ず差し替えてください**:
> - Vault の `publish/index.md` を作って `./sync.sh` する（推奨）
> - または `content/index.md` を直接編集する

---

# 🎉 Welcome — テンプレートのセットアップに成功しました

このページが見えているということは、**Obsidian → Quartz → GitHub Pages テンプレート**のローカル起動が正しく動いています。

## 動作確認

下記のページから、Quartz の主要機能が動いているか確認できます:

- [[hello-quartz|hello-quartz]] — Markdown / Mermaid / コードハイライト / 内部リンクのテスト

## 次にやること

1. **Vault を準備**: 公開したいノートだけを Vault の `publish/` フォルダに置く
2. **ローカル確認**: `./sync.sh` 後にブラウザを再読込（Vault のノートが index.md を上書きします）
3. **GitHub に push**: `main` ブランチへ push すれば自動デプロイ

詳細はリポジトリ直下の `README.md` を参照（テンプレ利用後は自分のサイト用に書き換え）。

## サンプルページの仕組み

- このページの中身は `content/index.md` にあります
- Vault `publish/` に `index.md` を置いて `./sync.sh` すると、このサンプルが上書きされます
- Vault `publish/` が空のとき、`sync.sh` は同期をスキップしてこのサンプルを表示します（`content/` を保護）

---

🔁 再掲: **このページは `content/index.md` のテンプレートサンプル**です。本番公開時は必ず差し替えてください。
