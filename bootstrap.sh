#!/usr/bin/env bash
# bootstrap.sh — Quartz v4 をこのディレクトリに展開し、overrides/ で設定を上書きする
#
# 使い方:
#   ./bootstrap.sh           # 通常実行（quartz/ が無ければ取得、あればスキップ）
#   ./bootstrap.sh --force   # 既存の quartz/ を消して再取得（Quartz アップデート時）
#   ./bootstrap.sh --ci      # 非対話モード（CI 用、警告で止まらない）
#
# 取得バージョンは ./quartz.version の1行目から読む（既定: v4 ブランチ）
# 例: "v4.5.2" や commit SHA "abc123..." を書ける

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── オプション解析 ───────────────────────────────────────────
FORCE=0
CI_MODE=0
if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    CI_MODE=1
fi
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        --ci)    CI_MODE=1 ;;
        *)       echo "unknown arg: $arg"; exit 1 ;;
    esac
done

# ── 取得対象バージョンの決定 ────────────────────────────────
QUARTZ_VERSION="v4"
if [[ -f quartz.version ]]; then
    QUARTZ_VERSION="$(head -n 1 quartz.version | tr -d '[:space:]')"
fi

# ── 依存コマンドの確認 ──────────────────────────────────────
for cmd in git node npm; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ required command not found: $cmd"
        exit 1
    fi
done

# Node のバージョン確認（22 以上）
NODE_MAJOR="$(node -e 'console.log(process.versions.node.split(".")[0])')"
if (( NODE_MAJOR < 22 )); then
    echo "⚠ Node.js $NODE_MAJOR 検出。Quartz v4 は 22 以上を推奨"
    if (( CI_MODE == 0 )); then
        read -r -p "  続行する場合は Enter（中断は Ctrl+C）"
    fi
fi

# ── quartz/ の取得（既存があればスキップ、--force で再取得） ──
if [[ -d quartz ]]; then
    if (( FORCE == 1 )); then
        echo "🗑  --force: removing existing quartz/"
        rm -rf quartz
    else
        echo "⏭  quartz/ already exists, skipping fetch"
        echo "   (Quartz をアップデートしたい場合は ./bootstrap.sh --force)"
    fi
fi

if [[ ! -d quartz ]]; then
    TMP="$(mktemp -d)"
    echo "📥 fetching Quartz $QUARTZ_VERSION → $TMP"
    if ! git clone --depth 1 --branch "$QUARTZ_VERSION" \
            https://github.com/jackyzha0/quartz.git "$TMP" 2>/dev/null; then
        echo "  branch/tag '$QUARTZ_VERSION' が見つからないため commit 指定として再試行"
        if ! git clone https://github.com/jackyzha0/quartz.git "$TMP"; then
            echo "❌ git clone failed"
            rm -rf "$TMP"
            exit 1
        fi
        ( cd "$TMP" && git checkout "$QUARTZ_VERSION" )
    fi

    rm -rf "$TMP/.git"

    echo "📂 moving Quartz files into $SCRIPT_DIR"
    shopt -s dotglob
    for f in "$TMP"/*; do
        name="$(basename "$f")"
        if [[ -e "./$name" ]]; then
            echo "  ⏭  skip existing: $name"
            continue
        fi
        mv "$f" ./
    done
    shopt -u dotglob
    rm -rf "$TMP"

    # Quartz の upstream-only ファイルを除去
    # - .github: Quartz の workflow / governance（後段で deploy.yml だけ復元）
    # - docs:    Quartz framework 自体の説明書（quartz.jzhao.xyz 相当）
    # - CODE_OF_CONDUCT.md: Quartz プロジェクトの行動規範
    # - Dockerfile: Quartz の Docker ビルド（GitHub Pages 経由なら不要）
    # - LICENSE.txt: LICENSE-Quartz.txt にリネーム保持
    echo "🧹 cleaning Quartz's upstream-only files"
    rm -rf .github docs CODE_OF_CONDUCT.md Dockerfile
    if [[ -f LICENSE.txt && ! -f LICENSE-Quartz.txt ]]; then
        mv LICENSE.txt LICENSE-Quartz.txt
        echo "  ✓ LICENSE.txt → LICENSE-Quartz.txt"
    elif [[ -f LICENSE.txt ]]; then
        rm -f LICENSE.txt
    fi
fi

# ── overrides を常に適用 ───────────────────────────────────
# bootstrap 再実行時にも自分の設定が確実に反映されるよう、毎回コピーする
echo "📝 applying overrides/"
if [[ -f overrides/quartz.config.ts ]]; then
    cp overrides/quartz.config.ts ./quartz.config.ts
    echo "  ✓ quartz.config.ts"
fi
if [[ -f overrides/quartz.layout.ts ]]; then
    cp overrides/quartz.layout.ts ./quartz.layout.ts
    echo "  ✓ quartz.layout.ts"
fi
if [[ -f overrides/deploy.yml ]]; then
    mkdir -p .github/workflows
    cp overrides/deploy.yml .github/workflows/deploy.yml
    echo "  ✓ .github/workflows/deploy.yml"
fi

# content/ が空でも残るように .gitkeep を入れておく
mkdir -p content
touch content/.gitkeep

echo
echo "✅ bootstrap complete (quartz: $QUARTZ_VERSION)"

if (( CI_MODE == 0 )); then
    echo
    echo "次にやること:"
    echo "  1. .publish.config を編集（cp .publish.config.example .publish.config）"
    echo "  2. npm ci  または  npm install"
    echo "  3. ./sync.sh"
    echo "  4. npx quartz build --serve  # http://localhost:8080"
fi
