#!/bin/bash
# parse-mode.sh — strip a leading `--flow` flag from a skill invocation input.
#
# Usage (inline in a skill's Step 0):
#
#   _sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
#   [ -f "$_sh/skills/_shared/parse-mode.sh" ] || _sh="$HOME/.claude"
#   eval "$(echo "$INPUT" | bash "$_sh/skills/_shared/parse-mode.sh")"
#   # After eval:
#   #   $MODE = "flow" | "strict"
#   #   $REMAINING = the original input with --flow removed (leading/interior token)
#
# Input: whitespace-separated tokens on stdin OR "$1".
# Output: two shell-safe assignments to stdout:
#   MODE=flow|strict
#   REMAINING=<original input minus the --flow token, trimmed>
#
# Does not error on missing input (MODE defaults to strict).

set -u

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat <<'EOF'
parse-mode.sh — detect --flow flag in skill input

Usage:
    echo "--flow CURB-123"   | parse-mode.sh
    echo "CURB-123"          | parse-mode.sh
    parse-mode.sh "--flow feature, add auth"
    parse-mode.sh "feature, add auth"

Stdout:
    MODE=flow
    REMAINING='CURB-123'

Eval the output to import MODE and REMAINING into the caller's shell.
EOF
    exit 0
fi

if [ -n "${1:-}" ]; then
    INPUT="$1"
else
    INPUT="$(cat 2>/dev/null || true)"
fi

MODE="strict"
REMAINING="$INPUT"

# Match --flow as a stand-alone token: start/end of string or surrounded by whitespace.
# Strip the token and any leading/trailing whitespace it created.
if echo "$INPUT" | grep -qE '(^|[[:space:]])--flow($|[[:space:]])'; then
    MODE="flow"
    REMAINING="$(echo "$INPUT" | sed -E 's/(^|[[:space:]])--flow($|[[:space:]])/\1\2/; s/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g')"
fi

# Single-quote REMAINING safely (escape any embedded single quotes).
ESC_REMAINING=$(printf '%s' "$REMAINING" | sed "s/'/'\\\\''/g")
printf "MODE=%s\nREMAINING='%s'\n" "$MODE" "$ESC_REMAINING"
