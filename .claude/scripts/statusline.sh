#!/bin/bash
# Claude Code statusline script
# Reads JSON session data from stdin, outputs color-coded context window usage

set -e

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "[no jq]"
  exit 0
fi

# Read JSON from stdin
INPUT=$(cat)

# Extract fields
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"')
PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty')
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // empty')

# Segment colors (real ESC chars via $'...')
REVIEW_COLOR=$'\033[36m'    # cyan
ISSUE_COLOR=$'\033[1;35m'   # bright magenta
LAST_COLOR=$'\033[90m'      # dim gray
RESET=$'\033[0m'

# Review counter + last command (existing)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COUNT=0
LAST_CMD=""
if [ -n "$CWD" ]; then
  COUNT=$(bash "$SCRIPT_DIR/new-review-counter.sh" get "$CWD" 2>/dev/null || echo 0)
  LAST_CMD=$(bash "$SCRIPT_DIR/new-review-counter.sh" get-last "$CWD" 2>/dev/null || echo "")
fi

# Resolve DEV_DIR: use existing .dev/ at project root, else .claude/.dev
DEV_DIR=""
if [ -n "$CWD" ]; then
  if [ -d "$CWD/.dev" ]; then
    DEV_DIR="$CWD/.dev"
  else
    for d in ".claude" ".kimi" ".agents"; do  # sync:keep
      if [ -d "$CWD/$d/.dev" ]; then
        DEV_DIR="$CWD/$d/.dev"
        break
      fi
    done
    if [ -z "$DEV_DIR" ] && [ -d "$HOME/.claude/.dev" ]; then
      DEV_DIR="$HOME/.claude/.dev"
    fi
  fi
fi

# Parse review.md for issue counts (findings block only)
ISSUE_TOTAL=0
ISSUE_ERRORS=0
ISSUE_WARNINGS=0
if [ -n "$DEV_DIR" ] && [ -f "$DEV_DIR/review.md" ]; then
  FINDINGS=$(sed -n '/^==== REVIEW FINDINGS ====/,/^==== END FINDINGS ====/p' "$DEV_DIR/review.md" 2>/dev/null || true)
  if [ -n "$FINDINGS" ]; then
    ISSUE_TOTAL=$(printf '%s\n' "$FINDINGS" | grep -c '^#### File:' | tr -d '[:space:]')
    ISSUE_ERRORS=$(printf '%s\n' "$FINDINGS" | grep -c '^- \*\*Severity:\*\* error$' | tr -d '[:space:]')
    ISSUE_WARNINGS=$(printf '%s\n' "$FINDINGS" | grep -c '^- \*\*Severity:\*\* warning$' | tr -d '[:space:]')
    [ -z "$ISSUE_TOTAL" ] && ISSUE_TOTAL=0
    [ -z "$ISSUE_ERRORS" ] && ISSUE_ERRORS=0
    [ -z "$ISSUE_WARNINGS" ] && ISSUE_WARNINGS=0
  fi
fi

# Suffix priority: issues (from review.md) > review counter > last command
SUFFIX=""
if [ "$ISSUE_TOTAL" -gt 0 ] 2>/dev/null; then
  if [ "$ISSUE_TOTAL" = "1" ]; then
    LABEL="1 Issue"
  else
    LABEL="${ISSUE_TOTAL} Issues"
  fi
  SUFFIX=" ${ISSUE_COLOR}- ${LABEL} (${ISSUE_ERRORS}E ${ISSUE_WARNINGS}W)${RESET}"
elif [ "$COUNT" = "1" ]; then
  SUFFIX=" ${REVIEW_COLOR}- 1 Review${RESET}"
elif [ "$COUNT" -gt 1 ] 2>/dev/null; then
  SUFFIX=" ${REVIEW_COLOR}- ${COUNT} Reviews${RESET}"
elif [ -n "$LAST_CMD" ]; then
  SUFFIX=" ${LAST_COLOR}${LAST_CMD}${RESET}"
fi

# Handle missing percentage
if [ -z "$PCT" ]; then
  printf "[%s] ░░░░░░░░░░ --%%%s" "$MODEL" "$SUFFIX"
  exit 0
fi

# Round to integer
PCT_INT=$(printf "%.0f" "$PCT")

# Context color thresholds
if [ "$PCT_INT" -ge 90 ]; then
  CTX_COLOR=$'\033[31m'  # red
elif [ "$PCT_INT" -ge 70 ]; then
  CTX_COLOR=$'\033[33m'  # yellow
else
  CTX_COLOR=$'\033[32m'  # green
fi

# Build 10-char progress bar
FILLED=$((PCT_INT / 10))
EMPTY=$((10 - FILLED))

BAR=""
for ((i = 0; i < FILLED; i++)); do BAR+="▓"; done
for ((i = 0; i < EMPTY; i++)); do BAR+="░"; done

printf "%s[%s] %s %d%%%s%s" "$CTX_COLOR" "$MODEL" "$BAR" "$PCT_INT" "$RESET" "$SUFFIX"
