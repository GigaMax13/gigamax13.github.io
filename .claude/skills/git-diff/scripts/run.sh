#!/bin/bash
# git-diff: raw diff output. No delta, no summary, no analysis.
set -e

INPUT="${1:-$(cat 2>/dev/null || true)}"
OPTION=$(echo "$INPUT" | cut -d',' -f1 | xargs)

STAGED=false
STAT=false
CONTEXT=""
RANGE=""
PATHS=""

echo "$INPUT" | grep -q "staged" && STAGED=true
echo "$INPUT" | grep -q "stat" && STAT=true

if echo "$INPUT" | grep -q "context:"; then
    CONTEXT=$(echo "$INPUT" | grep -o "context:[0-9]*" | cut -d':' -f2)
fi

case "$OPTION" in
    "range") RANGE=$(echo "$INPUT" | cut -d',' -f2 | xargs) ;;
    "paths") PATHS=$(echo "$INPUT" | cut -d',' -f2- | tr ',' ' ') ;;
esac

build_diff() {
    local base="$1"
    [ "$STAT" = true ] && base="$base --stat"
    [ -n "$CONTEXT" ] && [ "$CONTEXT" != " " ] && base="$base -U$CONTEXT"
    [ -n "$PATHS" ] && eval "$base -- $PATHS" || eval "$base"
}

if [ -n "$RANGE" ] && [ "$RANGE" != "range:" ]; then
    build_diff "git diff --no-ext-diff $RANGE"
elif [ "$STAGED" = true ]; then
    build_diff "git diff --no-ext-diff --staged"
else
    build_diff "git diff --no-ext-diff"
    if [ -z "$PATHS" ]; then
        UNTRACKED=$(git ls-files --others --exclude-standard)
        if [ -n "$UNTRACKED" ]; then
            echo ""
            for file in $UNTRACKED; do
                [ -f "$file" ] && git diff --no-ext-diff --no-index /dev/null "$file" 2>/dev/null || true
            done
        fi
    fi
fi
