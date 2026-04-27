#!/usr/bin/env bash
# sync.sh — Vault の publish/ を Quartz の content/ に同期する
#
# 設定の優先順:
#   1. 環境変数 VAULT_PUBLISH_DIR
#   2. ./.publish.config (YAML) の vault_publish_dir
#   3. デフォルト: $HOME/Documents/main_vault/publish
#
# .publish.config の形式（簡易 YAML サブセット）:
#   - フラットな key: value のみ (ネスト・配列は非対応)
#   - 値に `:` を含める場合は "..." または '...' で囲む
#   - 行頭または末尾の `# ...` はコメント
#
# 安全のため:
# - rsync --delete で publish/ にないファイルは content/ から消す
# - .obsidian, .trash, .git, .DS_Store は除外
# - content/.gitkeep は温存

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DST="$SCRIPT_DIR/content"
CONFIG_FILE="$SCRIPT_DIR/.publish.config"

# ──────────────────────────────────────────────────────────────
# 簡易 YAML パーサ (key: value のみ)
# 結果は CONFIG_<UPPER_KEY> という変数にセットする
# ──────────────────────────────────────────────────────────────
parse_publish_config() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 行頭・行末の空白を除去
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        # 空行・コメント行はスキップ
        [[ -z "$line" || "$line" == \#* ]] && continue
        # `:` で分割（値側に `:` を含む可能性は前から1つ目で切る）
        [[ "$line" != *:* ]] && continue
        key="${line%%:*}"
        value="${line#*:}"
        # 値の末尾コメントを除去（クォート外の場合のみ簡易判定）
        if [[ "$value" != *\"* && "$value" != *\'* ]]; then
            value="${value%%#*}"
        fi
        # それぞれの空白を除去
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        # 周囲のクォートを除去
        if [[ "$value" == \"*\" ]]; then
            value="${value#\"}"
            value="${value%\"}"
        elif [[ "$value" == \'*\' ]]; then
            value="${value#\'}"
            value="${value%\'}"
        fi
        # キーを UPPER_SNAKE_CASE 化
        local var_name="CONFIG_$(printf '%s' "$key" | tr '[:lower:]-' '[:upper:]_')"
        printf -v "$var_name" '%s' "$value"
    done < "$file"
}

parse_publish_config "$CONFIG_FILE"

# ──────────────────────────────────────────────────────────────
# 同期元の解決
# ──────────────────────────────────────────────────────────────
if [[ -n "${VAULT_PUBLISH_DIR:-}" ]]; then
    SRC="$VAULT_PUBLISH_DIR"
elif [[ -n "${CONFIG_VAULT_PUBLISH_DIR:-}" ]]; then
    SRC="$CONFIG_VAULT_PUBLISH_DIR"
else
    SRC="$HOME/Documents/main_vault/publish"
fi

# ~ 展開（YAML から読んだ場合 bash の tilde expansion が効かないので手動）
SRC="${SRC/#\~/$HOME}"

if [[ ! -d "$SRC" ]]; then
    echo "❌ source not found: $SRC"
    echo
    echo "次のいずれかで解決してください:"
    echo "  - 環境変数で指定:"
    echo "      VAULT_PUBLISH_DIR=/path/to/vault/publish ./sync.sh"
    echo "  - 設定ファイル ($CONFIG_FILE) を作成:"
    echo "      cp .publish.config.example .publish.config"
    echo "      # その後 vault_publish_dir の値を編集"
    echo "  - デフォルトパスに publish/ を配置:"
    echo "      $HOME/Documents/main_vault/publish"
    exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
    echo "❌ rsync が見つかりません"
    exit 1
fi

mkdir -p "$DST"

# ──────────────────────────────────────────────────────────────
# Docker フォールバックモード（.env 未設定）の検出と警告バナー管理
# - /.dockerenv が存在 = コンテナ内で実行されている
# - HOST_VAULT_PUBLISH_DIR が空 = ホスト側 .env で VAULT_PUBLISH_DIR が
#   指定されていない（compose が ./.no-vault-stub にフォールバックした）
# 両方を満たすときだけ index.md に警告バナーを差し込み、それ以外では除去する。
# ──────────────────────────────────────────────────────────────
ENV_BANNER_START='<!-- ENV_NOT_CONFIGURED_BANNER:START -->'
ENV_BANNER_END='<!-- ENV_NOT_CONFIGURED_BANNER:END -->'

add_env_banner() {
    local idx="$DST/index.md"
    [[ -f "$idx" ]] || return 0
    if grep -qF "$ENV_BANNER_START" "$idx" 2>/dev/null; then
        return 0  # 既に追加済み
    fi
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'BANNER'
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

BANNER
    cat "$idx" >> "$tmp"
    mv "$tmp" "$idx"
    echo "ℹ️  index.md に '.env 未設定' 警告バナーを追加しました"
}

remove_env_banner() {
    local idx="$DST/index.md"
    [[ -f "$idx" ]] || return 0
    if ! grep -qF "$ENV_BANNER_START" "$idx" 2>/dev/null; then
        return 0  # 元から無い
    fi
    local tmp
    tmp="$(mktemp)"
    # 1) START〜END 行を削除
    sed "/$ENV_BANNER_START/,/$ENV_BANNER_END/d" "$idx" > "$tmp"
    # 2) 先頭の空行を除去 + 連続空行を1行に圧縮
    awk 'BEGIN{seen=0; prev_blank=0}
         /^[[:space:]]*$/ {
             if (!seen) next
             if (!prev_blank) { print; prev_blank=1 }
             next
         }
         { seen=1; prev_blank=0; print }' "$tmp" > "$idx"
    rm -f "$tmp"
    echo "ℹ️  index.md から '.env 未設定' 警告バナーを除去しました"
}

if [[ -f /.dockerenv ]] && [[ -z "${HOST_VAULT_PUBLISH_DIR:-}" ]]; then
    add_env_banner
else
    remove_env_banner
fi

# ──────────────────────────────────────────────────────────────
# Vault が空の場合は同期をスキップ
# 初回利用時 (Vault に publish/ ディレクトリだけ作って中身が空) でも、
# content/ にバンドル済みのサンプルページが残ってプレビュー表示できるようにする。
# 同期したい場合は Vault に .md ファイルを1つでも置けば自動で開始する。
# ──────────────────────────────────────────────────────────────
SRC_MD_COUNT=$(find "$SRC" -type f -name '*.md' 2>/dev/null | wc -l)
if (( SRC_MD_COUNT == 0 )); then
    echo "ℹ️  Vault が空です ($SRC に .md ファイルなし)"
    echo "   content/ のバンドル済みサンプルをそのまま使います"
    echo "   公開対象を増やしたら Vault publish/ にノートを追加して再実行してください"
    if [[ -f "$SCRIPT_DIR/package.json" ]]; then
        echo
        echo "次にやること:"
        echo "  プレビュー: npx quartz build --serve"
    fi
    exit 0
fi

echo "🔄 sync"
echo "   from: $SRC"
echo "   to:   $DST"
echo

rsync -av --delete --delete-excluded \
    --exclude='.obsidian' \
    --exclude='.trash' \
    --exclude='.git' \
    --exclude='.DS_Store' \
    --exclude='.gitkeep' \
    --exclude='README.md' \
    --exclude='_*.md' \
    "$SRC/" "$DST/"

# .gitkeep を復活（rsync --delete で消えるのを避ける）
touch "$DST/.gitkeep"

echo
echo "✅ sync complete"

if [[ -f "$SCRIPT_DIR/package.json" ]]; then
    echo
    echo "次にやること:"
    echo "  プレビュー: npx quartz build --serve"
    echo "  公開:       git add content && git commit -m '...' && git push"
fi
