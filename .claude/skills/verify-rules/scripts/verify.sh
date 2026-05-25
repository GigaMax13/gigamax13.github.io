#!/bin/bash
# verify-rules thin wrapper — locates verify.py and execs python3
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared path resolution (exports SKILLS_HOME, PROJECT_ROOT)
# shellcheck source=resolve-paths.sh
source "$SCRIPT_DIR/resolve-paths.sh"

VERIFY_PY="$SCRIPT_DIR/verify.py"

if [ ! -f "$VERIFY_PY" ]; then
    for cand in \
        "$SKILLS_HOME/skills/verify-rules/scripts/verify.py" \
        ".claude/skills/verify-rules/scripts/verify.py" \
        ".kimi/skills/verify-rules/scripts/verify.py" \
        ".agents/skills/verify-rules/scripts/verify.py"; do  # sync:keep
        if [ -f "$cand" ]; then
            VERIFY_PY="$cand"
            break
        fi
    done
fi

if [ ! -f "$VERIFY_PY" ]; then
    echo "verify-rules: verify.py not found" >&2
    exit 1
fi

exec python3 "$VERIFY_PY" "$@"
