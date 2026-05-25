#!/bin/bash
# summary — print a workflow-completion summary. Read-only.
#
# Pulls the latest phase's completed task from state.md, the last commit's
# short hash/subject, and the diff stat vs HEAD~1. Omits rows with no data.
#
# Exit 0 always (read-only; worst case prints "no data").

set -u

_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"
DEV_DIR="$(bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh" 2>/dev/null || true)"

PHASE=""
STATE_FILE=""
LAST_DONE=""
TASK_FILE=""
TITLE=""

if [ -n "$DEV_DIR" ] && [ -d "$DEV_DIR" ]; then
    PHASE="$(
        ls -1 "$DEV_DIR" 2>/dev/null \
        | grep -E '^m[0-9]+(\.[0-9]+)?$' \
        | while IFS= read -r p; do [ -f "$DEV_DIR/$p/state.md" ] && printf '%s\n' "$p"; done \
        | awk -F'[m.]' '{printf "%d.%d\t%s\n", $2, ($3 == "" ? 0 : $3), $0}' \
        | sort -t$'\t' -k1,1n -k2,2n \
        | tail -n1 \
        | cut -f2 \
    )"
    if [ -n "$PHASE" ]; then
        STATE_FILE="$DEV_DIR/$PHASE/state.md"
        if [ -f "$STATE_FILE" ]; then
            LAST_DONE="$(grep -E '^- \[x\] ' "$STATE_FILE" | tail -n1 || true)"
            TASK_FILE="$(printf '%s' "$LAST_DONE" | sed -E 's/^- \[x\] *([^ ]+).*/\1/')"
            if [ -n "$TASK_FILE" ] && [ -f "$DEV_DIR/$PHASE/tasks/$TASK_FILE" ]; then
                TITLE="$(grep -m1 -E '^# ' "$DEV_DIR/$PHASE/tasks/$TASK_FILE" 2>/dev/null | sed -E 's/^# *//')"
            fi
        fi
    fi
fi

COMMIT=""
SUBJECT=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    COMMIT="$(git log -1 --format='%h' 2>/dev/null || true)"
    SUBJECT="$(git log -1 --format='%s' 2>/dev/null || true)"
fi

echo "Task Complete: ${TASK_FILE:-(unknown)}${TITLE:+ — $TITLE}"
echo ""
echo "| Step      | Result                           |"
echo "|-----------|----------------------------------|"
[ -n "$PHASE" ]      && echo "| Phase     | $PHASE                           |"
[ -n "$TASK_FILE" ]  && echo "| Task      | $TASK_FILE                       |"
[ -n "$COMMIT" ]     && echo "| Commit    | $COMMIT — ${SUBJECT:-(no subject)} |"
if git rev-parse HEAD~1 >/dev/null 2>&1; then
    echo ""
    echo "Changes (HEAD~1..HEAD):"
    git diff HEAD~1 --stat 2>/dev/null || true
fi

echo ""
echo "SUMMARY COMPLETE"
