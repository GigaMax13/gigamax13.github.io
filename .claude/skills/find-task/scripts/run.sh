#!/bin/bash
# find-task — resolve latest active phase (highest-numbered with state.md),
# find first pending task in state.md, print details.
#
# Exit 0 on success (task found or no pending task — both are acceptable).
# Exit 2 on script error (no DEV_DIR, no active phase).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve DEV_DIR via the canonical helper.
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"
DEV_DIR="$(bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh" 2>/dev/null || true)"
if [ -z "$DEV_DIR" ] || [ ! -d "$DEV_DIR" ]; then
    echo "FIND-TASK FAILED: could not resolve DEV_DIR" >&2
    exit 2
fi

# Pick latest active phase directory: sort by version (m1 < m1.1 < m1.9 < m2 < m2.10),
# but only consider phases that already have state.md (non-active phases hold just PRD.md).
PHASE="$(
    ls -1 "$DEV_DIR" 2>/dev/null \
    | grep -E '^m[0-9]+(\.[0-9]+)?$' \
    | while IFS= read -r p; do [ -f "$DEV_DIR/$p/state.md" ] && printf '%s\n' "$p"; done \
    | awk -F'[m.]' '{printf "%d.%d\t%s\n", $2, ($3 == "" ? 0 : $3), $0}' \
    | sort -t$'\t' -k1,1n -k2,2n \
    | tail -n1 \
    | cut -f2
)"
if [ -z "$PHASE" ]; then
    echo "FIND-TASK FAILED: no phase under $DEV_DIR has state.md (run /new-tasks for the active phase)" >&2
    exit 2
fi

STATE_FILE="$DEV_DIR/$PHASE/state.md"

echo "Phase: $PHASE"
echo "State: $STATE_FILE"

# First unchecked line.
PENDING_LINE="$(grep -nE '^- \[ \] ' "$STATE_FILE" | head -n1 || true)"
if [ -z "$PENDING_LINE" ]; then
    echo "No pending tasks — all items in $STATE_FILE are checked."
    echo "FIND-TASK COMPLETE"
    exit 0
fi

LINE_NO="${PENDING_LINE%%:*}"
LINE_BODY="${PENDING_LINE#*:}"

# Extract task filename (first token after `- [ ]`).
TASK_FILE="$(printf '%s' "$LINE_BODY" | sed -E 's/^- \[ \] *([^ ]+).*/\1/')"

# Extract description after ` - ` separator if present.
TASK_DESC="$(printf '%s' "$LINE_BODY" | sed -E 's/^- \[ \] *[^ ]+ *-? *//; s/[[:space:]]+$//')"

# Find nearest `<!-- PR: name -->` comment ABOVE this line (same file).
PR_GROUP="$(awk -v target="$LINE_NO" '
    /<!-- PR: / {
        match($0, /<!-- PR: ([^ ]+) -->/, m)
        if (m[1] != "") current = m[1]
    }
    NR == target { print current; exit }
' "$STATE_FILE" 2>/dev/null)"
[ -z "$PR_GROUP" ] && PR_GROUP="(none)"

TASK_PATH="$DEV_DIR/$PHASE/tasks/$TASK_FILE"

echo "Task file: $TASK_FILE"
echo "Task path: $TASK_PATH"
[ -n "$TASK_DESC" ] && echo "Description: $TASK_DESC"
echo "PR group: $PR_GROUP"

if [ -f "$TASK_PATH" ]; then
    echo ""
    echo "--- $TASK_FILE (first 40 lines) ---"
    head -n 40 "$TASK_PATH"
else
    echo "WARN: task file not found at $TASK_PATH" >&2
fi

echo ""
echo "FIND-TASK COMPLETE"
