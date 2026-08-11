# Knowledge Is Power To us

技術記事・マンガ/ゲームの感想を書き溜めていく個人サイトです。

[アクセス](https://kip2.github.io/Knowledge-Is-Power-To-us/)

## このサイトの内容

ジャンルを絞らず、以下のような記事を不定期で書いていきます。

- **技術記事** — 開発・学習中に得た知見、調べたことのメモ
- **マンガの感想** — 読んだマンガの感想・レビュー
- **ゲームの感想** — プレイしたゲームの感想・レビュー

## 仕組み

Obsidianで編集した記事をそのまま公開できるように構築しています。

- **編集**: Obsidian Vault（ローカル）で普段通り書く
- **公開対象**: Vault の `publish/` 配下のみ。残りの私的ノートはローカルにとどまる
- **静的サイト生成**: [Quartz v4](https://quartz.jzhao.xyz/)
- **ホスティング**: GitHub Pages
- **デプロイ**: GitHub Actions（`main` ブランチへの push をトリガー、1〜3 分で反映）

詳細は以下のテンプレートリポジトリを参照。

[サイト作成テンプレートリポジトリ](https://github.com/kip2/publish-site-template/tree/main)

## 使い方

記事の実体は Vault の `publish/` 配下にあります。`content/` は同期先なので直接編集しないでください（`rsync --delete` で消えます）。

### ローカルで確認する

```bash
docker compose up preview
# → http://localhost:8080
```

Vault の `publish/` を直接 serve するので、**Obsidian で保存すればブラウザが自動リロードされます。** 同期コマンドを手で叩く必要はありません。止めるときは `Ctrl+C`、コンテナを片付けるなら `docker compose down`。

ホスト側の 8080 が他のアプリに使われている場合は `.env` でポートを変更します。

```env
PREVIEW_PORT=8090
QUARTZ_BASE_URL=localhost:8090
```

公開時と同じ静的ビルドを手元で再現したい場合はこちら。`public/` に出力されます。

```bash
docker compose run --rm build
```

### 公開する

```bash
./do-push.sh "update: 記事タイトル"
```

`sync.sh` による同期 → `git add content` → commit → push までを一括で実行します。push 後 GitHub Actions が走り、1〜3 分でサイトに反映されます。`content/` に差分が無ければ commit はスキップされます。

同期だけ先に済ませて差分を確認したいときは以下。

```bash
./do-sync.sh
git diff --stat content
```

`do-sync.sh` / `do-push.sh` は Docker とネイティブ実行を自動判定します。強制したい場合は `--docker` / `--native` を付けてください。

### 公開されないもの

`publish/` 配下に置いても、以下はプレビューにも公開物にも出ません。

| 対象 | 用途 |
|---|---|
| `_` で始まる `.md` | 下書き（`_foo.md` のままなら公開されない） |
| `README.md` | Vault 側の説明書き |
| `.obsidian/`, `.trash/` | Obsidian の内部データ |
| `private/`, `templates/` | 非公開ノート・テンプレート |

初回構築の手順は [documents/SETUP.md](documents/SETUP.md)、ディレクトリ構成は [documents/STRUCTURE.md](documents/STRUCTURE.md) を参照。

## License

このリポジトリには複数のライセンスが混在しているので注意してください。

| 対象 | ライセンス | ファイル |
|---|---|---|
| `content/` 配下のコンテンツ（記事本文・画像・図表など著作者本人が作成したもの） | **All Rights Reserved** © 2026 kip2 | [LICENSE](./LICENSE) |
| スクリプト・設定（`bootstrap.sh`, `sync.sh`, `do-*.sh`, `overrides/` 等） | **MIT License** © 2026 kip2 | [LICENSE](./LICENSE) |
| Quartz 由来コード（`quartz/` 配下、ビルド時に取得） | **MIT License** © Jacky Zhao and contributors | [LICENSE-Quartz.txt](./LICENSE-Quartz.txt) |
| 第三者素材（スクショ・引用コード・埋め込み画像など） | 元の権利者に帰属（本サイトのライセンスは非適用） | — |

### コンテンツについての補足

- `content/` 配下の記事・画像・図表など、kip2 が作成したオリジナル著作物については **すべての権利を留保（All Rights Reserved）** しています。事前の書面による許諾なく、複製・転載・改変・再配布・商用利用・翻訳・派生作品の作成を禁じます。
- 著作権法上認められる範囲（出所明示・必要最小限・主従関係の明確化など）での **引用は可能** です。
- 記事内に含まれる第三者素材（ソフトのスクショ、他人のコード、引用文、出版社/権利者の画像など）は元の権利者の著作物のままで、本サイトのライセンスとは独立しています。各素材の利用条件は元のライセンスに従ってください。

詳細は [LICENSE](./LICENSE) を参照。
