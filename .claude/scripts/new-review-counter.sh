#!/bin/bash
# Per-project /new-review counter + last-command tracker.
#
# Subcommands:
#   update           — reads UserPromptSubmit hook JSON from stdin, mutates state
#   get <cwd>        — prints current review counter for the given project path (0 if unset)
#   get-last <cwd>   — prints last slash command for the given project path (empty if unset)
#
# State file: alongside this script as .new-review-counter.json
#   { "<absolute-project-path>": { "reviews": <int>, "last": "<string>" }, ... }

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="$SCRIPT_DIR/.new-review-counter.json"

if ! command -v jq &>/dev/null; then
  exit 0
fi

ensure_state() {
  if [ ! -f "$STATE_FILE" ]; then
    echo '{}' > "$STATE_FILE"
  fi
}

case "${1:-}" in
  get)
    PROJECT="${2:-}"
    if [ -z "$PROJECT" ] || [ ! -f "$STATE_FILE" ]; then
      echo 0
      exit 0
    fi
    # Support both old flat format (int) and new nested format (object)
    RAW=$(jq -r --arg k "$PROJECT" '.[$k]' "$STATE_FILE" 2>/dev/null || echo "null")
    if echo "$RAW" | jq -e 'type == "object"' &>/dev/null; then
      echo "$RAW" | jq -r '.reviews // 0'
    elif echo "$RAW" | jq -e 'type == "number"' &>/dev/null; then
      echo "$RAW"
    else
      echo 0
    fi
    ;;

  get-last)
    PROJECT="${2:-}"
    if [ -z "$PROJECT" ] || [ ! -f "$STATE_FILE" ]; then
      echo ""
      exit 0
    fi
    RAW=$(jq -r --arg k "$PROJECT" '.[$k]' "$STATE_FILE" 2>/dev/null || echo "null")
    if echo "$RAW" | jq -e 'type == "object"' &>/dev/null; then
      echo "$RAW" | jq -r '.last // ""'
    else
      echo ""
    fi
    ;;

  update)
    INPUT=$(cat)
    PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || echo "")
    CWD=$(echo "$INPUT" | jq -r '.cwd // .workspace.current_dir // empty' 2>/dev/null || echo "")

    [ -z "$PROMPT" ] && exit 0
    [ -z "$CWD" ] && exit 0

    # First whitespace-delimited token
    FIRST=$(printf '%s' "$PROMPT" | awk '{print $1}')

    # Non-slash prompt → do nothing
    case "$FIRST" in
      /*) ;;
      *) exit 0 ;;
    esac

    # /clear → no changes
    if [ "$FIRST" = "/clear" ]; then
      exit 0
    fi

    ensure_state

    # Migrate old flat format to nested if needed
    RAW=$(jq -r --arg k "$CWD" '.[$k]' "$STATE_FILE" 2>/dev/null || echo "null")
    if echo "$RAW" | jq -e 'type == "number"' &>/dev/null; then
      TMP="$STATE_FILE.tmp.$$"
      jq --arg k "$CWD" --argjson v "$RAW" '.[$k] = {"reviews": $v, "last": ""}' "$STATE_FILE" > "$TMP"
      mv "$TMP" "$STATE_FILE"
    elif ! echo "$RAW" | jq -e 'type == "object"' &>/dev/null; then
      TMP="$STATE_FILE.tmp.$$"
      jq --arg k "$CWD" '.[$k] = {"reviews": 0, "last": ""}' "$STATE_FILE" > "$TMP"
      mv "$TMP" "$STATE_FILE"
    fi

    TMP="$STATE_FILE.tmp.$$"

    if [ "$FIRST" = "/new-review" ]; then
      # Increment reviews, do NOT update last (review has its own counter)
      jq --arg k "$CWD" \
        '.[$k].reviews = ((.[$k].reviews // 0) + 1)' \
        "$STATE_FILE" > "$TMP"
    else
      # Any other slash command: reset reviews, update last command
      jq --arg k "$CWD" --arg cmd "$FIRST" \
        '.[$k].reviews = 0 | .[$k].last = $cmd' \
        "$STATE_FILE" > "$TMP"
    fi

    mv "$TMP" "$STATE_FILE"
    ;;

  -h|--help|"")
    echo "Usage: $0 update           # reads hook JSON from stdin"
    echo "       $0 get <cwd>        # prints review counter for project"
    echo "       $0 get-last <cwd>   # prints last command for project"
    ;;
esac
