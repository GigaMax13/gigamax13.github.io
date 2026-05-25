#!/bin/bash
# task-2-branch: task name -> kebab-case branch, max 2 words, optional type prefix
set -e

INPUT="${1:-$(cat 2>/dev/null || true)}"

if [ -z "$INPUT" ]; then
    echo "ERROR: empty task name" >&2
    exit 1
fi

# Detect and strip type prefix: feature/, fix/, fix:, etc.
PREFIX=""
REMAINDER="$INPUT"
for type in feature fix hotfix bugfix chore refactor test docs ci build perf style; do
    if [[ "$REMAINDER" =~ ^${type}[/:]\ ?(.*)$ ]]; then
        PREFIX="${type}/"
        REMAINDER="${BASH_REMATCH[1]}"
        break
    fi
done

SLUG=$(echo "$REMAINDER" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9' ' ' \
    | awk 'BEGIN{fillers="the a an to for in on of and with from is be that this it "}
           {for(i=1;i<=NF;i++){if(index(fillers,$i" ")==0)printf "%s ",$i}}')

SLUG=$(echo "$SLUG" | awk '{print $1 (NF>1?"-"$2:"")}')

if [ "${#SLUG}" -gt 30 ]; then
    SLUG=$(echo "$SLUG" | cut -d'-' -f1)
fi

echo "${PREFIX}${SLUG}"
