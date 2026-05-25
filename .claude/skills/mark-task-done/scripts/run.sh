#!/bin/bash
# mark-task-done — mark the next pending task complete in state.md.
#
# Resolves DEV_DIR, finds the latest phase, and replaces the first `- [ ]` bullet
# with `- [x]` plus `(completed YYYY-MM-DD)`. No external tracker updates.
#
# Exit 0 on success, 2 on error.

set -u

_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"
DEV_DIR="$(bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh" 2>/dev/null || true)"
if [ -z "$DEV_DIR" ] || [ ! -d "$DEV_DIR" ]; then
    echo "MARK-TASK-DONE FAILED: could not resolve DEV_DIR" >&2
    exit 2
fi

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
    echo "MARK-TASK-DONE FAILED: no phase directory under $DEV_DIR" >&2
    exit 2
fi

STATE_FILE="$DEV_DIR/$PHASE/state.md"
if [ ! -f "$STATE_FILE" ]; then
    echo "MARK-TASK-DONE FAILED: $STATE_FILE not found" >&2
    exit 2
fi

PENDING_LINE="$(grep -nE '^- \[ \] ' "$STATE_FILE" | head -n1 || true)"
if [ -z "$PENDING_LINE" ]; then
    echo "No pending tasks to mark done — $STATE_FILE is already complete."
    echo "MARK-TASK-DONE COMPLETE"
    exit 0
fi

LINE_NO="${PENDING_LINE%%:*}"
LINE_BODY="${PENDING_LINE#*:}"
TASK_FILE="$(printf '%s' "$LINE_BODY" | sed -E 's/^- \[ \] *([^ ]+).*/\1/')"

TODAY="$(date +%Y-%m-%d)"

# Portable in-place edit: write to a temp file then move it.
TMP="$(mktemp)"
awk -v target="$LINE_NO" -v today="$TODAY" '
    NR == target {
        # Replace the first `- [ ]` with `- [x]` and append the completion note
        # before any existing trailing whitespace/newline.
        sub(/^- \[ \] /, "- [x] ")
        if ($0 !~ /\(completed [0-9-]+\)/) {
            # Append suffix at end of line.
            sub(/[[:space:]]*$/, "")
            $0 = $0 " (completed " today ")"
        }
    }
    { print }
' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

echo "Marked done: $TASK_FILE (in $STATE_FILE, line $LINE_NO)"
echo "MARK-TASK-DONE COMPLETE"
