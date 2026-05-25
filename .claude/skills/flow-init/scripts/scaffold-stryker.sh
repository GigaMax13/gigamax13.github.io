#!/bin/bash
# scaffold-stryker.sh — write a default stryker.config.json on the host project.
# Delegates to flow-metrics' scaffold-mutation.sh (single source of truth).
# Idempotent: skips if any stryker.config.* / .stryker.conf.* already exists.

set -eu

TARGET="."
while [ $# -gt 0 ]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        *) shift ;;
    esac
done

_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/flow-metrics/scripts/scaffold-mutation.sh" ] || _sh="$HOME/.claude"

bash "$_sh/skills/flow-metrics/scripts/scaffold-mutation.sh" --target "$TARGET" --lang ts
