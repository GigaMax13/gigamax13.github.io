#!/bin/bash
# verify-stop — Stop-hook gate for verify-rules.
#
# Mirrors validate-fast.sh's marker pattern. Runs verify.sh --diff only when
# an edit-skill has written $DEV_DIR/.verify-rules-required. Skills that
# don't touch source code (creation/read-only skills, /new-commit, /git-diff,
# /summary, …) never write the marker, so the Stop hook is silent for them.
#
# Bypass: AGENTS_SKIP_VERIFY_HOOK=1 short-circuits even when marker present
# (matches AGENTS_SKIP_VALIDATE_HOOK for symmetry).
#
# Exit codes are forwarded from verify.sh (0 pass, 2 violations, 1 internal).

set -u

if [ "${AGENTS_SKIP_VERIFY_HOOK:-0}" = "1" ]; then
    echo "verify-stop: skipped (AGENTS_SKIP_VERIFY_HOOK=1)"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=resolve-paths.sh
source "$SCRIPT_DIR/resolve-paths.sh"

MARKER="$DEV_DIR/.verify-rules-required"
if [ ! -f "$MARKER" ]; then
    exit 0
fi
rm -f "$MARKER"

out=$(bash "$SCRIPT_DIR/verify.sh" --diff 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
    echo "$out" >&2
fi
exit $rc
