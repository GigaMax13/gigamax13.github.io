#!/bin/bash
# preflight checks: clean working tree + pending tasks exist
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"
DEV_DIR="$(bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh")"

fail=0

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "FAIL: uncommitted changes in working tree"
    fail=1
fi

if ! grep -lq "\[ \]" "$DEV_DIR"/*/state.md 2>/dev/null; then
    echo "FAIL: no pending tasks in any phase state.md"
    fail=1
fi

if [ "$fail" -eq 1 ]; then
    echo "PREFLIGHT FAILED"
    exit 1
fi

echo "PREFLIGHT COMPLETE"
