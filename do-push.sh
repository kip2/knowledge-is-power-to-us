#!/usr/bin/env bash
# do-push.sh — Vault → content/ 同期 → git add content → commit → push を一括実行。
#
# 使い方:
#   ./do-push.sh                            # 同期後、対話的に commit message を入力
#   ./do-push.sh "update: 新しい記事を追加"  # 引数をそのまま commit message に使う
#   ./do-push.sh --docker "msg..."          # 同期モードを Docker に強制
#   ./do-push.sh --native "msg..."          # 同期モードを native に強制
#
# - content/ に差分が無ければ commit/push はスキップする
# - origin が未設定なら push はスキップ（commit までで止まる）
# - commit message の対話入力で空 Enter するとキャンセル（staging も戻す）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 先頭引数が --docker / --native なら同期モードフラグとして抜き出す
MODE_FLAG=""
case "${1:-}" in
    --docker|--native)
        MODE_FLAG="$1"
        shift
        ;;
esac

# ── 1. Sync ───────────────────────────────────────────────
"$SCRIPT_DIR/do-sync.sh" $MODE_FLAG

# ── 2. Stage content/ ─────────────────────────────────────
echo
echo "📦 staging content/"
git add content

if git diff --cached --quiet; then
    echo "ℹ️  content/ に変更なし、commit はスキップします"
    exit 0
fi

# ── 3. Commit message を決定 ─────────────────────────────
if [[ $# -gt 0 ]]; then
    MESSAGE="$*"
else
    echo
    echo "📝 commit message を入力してください (空 Enter でキャンセル):"
    printf "> "
    IFS= read -r MESSAGE
    if [[ -z "$MESSAGE" ]]; then
        echo "❌ キャンセルしました (staging を取り消します)"
        git restore --staged content
        exit 1
    fi
fi

# ── 4. Commit ─────────────────────────────────────────────
echo
echo "💾 commit"
git commit -m "$MESSAGE"

# ── 5. Push (origin がある場合のみ) ──────────────────────
if git remote get-url origin >/dev/null 2>&1; then
    echo
    echo "🚀 push"
    git push
    echo
    echo "✅ published"
else
    echo
    echo "ℹ️  origin 未設定のため push はスキップしました"
fi
