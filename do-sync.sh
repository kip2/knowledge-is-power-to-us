#!/usr/bin/env bash
# do-sync.sh — Vault → content/ への同期を Docker / native 自動判定で実行する。
#
# 使い方:
#   ./do-sync.sh                # 自動判定で実行
#   ./do-sync.sh --docker       # Docker で実行を強制
#   ./do-sync.sh --native       # ホスト直接実行を強制
#
# 自動判定の優先順:
#   1. ./node_modules/ がありホストに node がある            → native
#   2. docker-compose.yml がありホストに docker がある       → docker
#   3. ホストに rsync と node がある                         → native
#   4. ホストに docker がある                                → docker
#   5. どれもない                                            → エラー終了

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MODE=""
case "${1:-}" in
    --docker) MODE="docker" ;;
    --native) MODE="native" ;;
    "")       MODE="" ;;
    *)        echo "Usage: $0 [--docker | --native]" >&2; exit 1 ;;
esac

if [[ -z "$MODE" ]]; then
    if [[ -d node_modules ]] && command -v node >/dev/null 2>&1; then
        MODE="native"
    elif [[ -f docker-compose.yml ]] && command -v docker >/dev/null 2>&1; then
        MODE="docker"
    elif command -v rsync >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
        MODE="native"
    elif command -v docker >/dev/null 2>&1; then
        MODE="docker"
    else
        echo "❌ Docker も native の Node 環境も利用できません" >&2
        exit 1
    fi
fi

case "$MODE" in
    docker)
        echo "🐳 sync via Docker (docker compose run --rm shell ./sync.sh)"
        docker compose run --rm shell ./sync.sh
        ;;
    native)
        echo "💻 sync via native (./sync.sh)"
        ./sync.sh
        ;;
esac
