#!/bin/bash
# validate-fast — deterministic typecheck + lint gate for Stop hooks.
#
# Parses the Validation table from CLAUDE.md (or AGENTS.md) and runs the  # sync:keep
# TypeCheck and Lint rows. Skips the Test row — tests are too slow for a
# per-turn blocking hook and are enforced in-skill via /validate.
#
# Exit codes:
#   0  — all commands passed (or nothing to do, or bypassed)
#   2  — a typecheck/lint command failed (blocking for Stop hooks)
#
# Bypass: set AGENTS_SKIP_VALIDATE_HOOK=1 to skip (useful mid-refactor).
#
# Opt-in gate: skill-side. Edit-skills (do-development, fix-review, refactor,
# cleanup) write $DEV_DIR/.validate-fast-required before exiting. This script
# checks for the marker, consumes it (one-shot), and runs validation. Skills
# that don't edit code (new-rules, new-prd, find-task, review-only, …) never
# write the marker, so the Stop hook is silent for them.
#
# Companion gate: verify-stop.sh uses the same pattern with its own marker
# ($DEV_DIR/.verify-rules-required) for the verify-rules Stop hook. Both
# markers are typically written together by edit-skills.
#
# Arguments are accepted for signature parity with verify.sh but ignored —
# typecheck/lint commands from CLAUDE.md are whole-project by design.

set -u

if [ "${AGENTS_SKIP_VALIDATE_HOOK:-0}" = "1" ]; then
    echo "validate-fast: skipped (AGENTS_SKIP_VALIDATE_HOOK=1)"
    exit 0
fi

# Source shared path resolution (exports SKILLS_HOME, PROJECT_ROOT, DEV_DIR)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=resolve-paths.sh
source "$SCRIPT_DIR/resolve-paths.sh"

ROOT="$PROJECT_ROOT"

if [ -z "$ROOT" ]; then
    # No project root found — nothing to validate.
    exit 0
fi

# Opt-in marker gate. No marker = creation/read-only skill ran; skip silently.
MARKER="$DEV_DIR/.validate-fast-required"
if [ ! -f "$MARKER" ]; then
    exit 0
fi
rm -f "$MARKER"

RULES_FILE=""
if [ -f "$ROOT/CLAUDE.md" ]; then
    RULES_FILE="$ROOT/CLAUDE.md"
elif [ -f "$ROOT/AGENTS.md" ]; then  # sync:keep
    RULES_FILE="$ROOT/AGENTS.md"  # sync:keep
fi

if [ -z "$RULES_FILE" ]; then
    # No project rules file — nothing to validate.
    exit 0
fi

# Extract TypeCheck and Lint command cells from the Validation table.
# Table format:
#   ## Validation
#   | Type      | Command                |
#   | --------- | ---------------------- |
#   | TypeCheck | `cmd here`             |
#   | Lint      | `cmd here`             |
#   | Test      | `cmd here`             |
#
# Strategy: find the "## Validation" heading, read following lines until the
# next blank-then-heading, pick rows whose first column matches TypeCheck/Lint
# (case-insensitive), and extract the backtick-quoted command from column 2.

extract_cmd() {
    local label="$1"
    awk -v label="$label" '
        BEGIN { in_section = 0; IGNORECASE = 1 }
        /^## Validation[[:space:]]*$/ { in_section = 1; next }
        in_section && /^## / { in_section = 0 }
        in_section && /^\|/ {
            # Split on pipe, trim whitespace
            n = split($0, cells, "|")
            if (n < 3) next
            type = cells[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", type)
            cmd  = cells[3]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd)
            if (tolower(type) == tolower(label)) {
                # Strip surrounding backticks if present
                sub(/^`/, "", cmd); sub(/`$/, "", cmd)
                print cmd
                exit
            }
        }
    ' "$RULES_FILE"
}

TYPECHECK_CMD="$(extract_cmd TypeCheck)"
LINT_CMD="$(extract_cmd Lint)"

if [ -z "$TYPECHECK_CMD" ] && [ -z "$LINT_CMD" ]; then
    # No commands defined — nothing to enforce.
    exit 0
fi

REPORT_DIR="$DEV_DIR"
REPORT_FILE="$REPORT_DIR/validate-fast.md"
mkdir -p "$REPORT_DIR" 2>/dev/null || true

failures=0
tmp_out="$(mktemp)"
trap 'rm -f "$tmp_out"' EXIT

run_cmd() {
    local label="$1"
    local cmd="$2"
    [ -z "$cmd" ] && return 0

    # Run in a subshell from project root so `cd foo && ...` works.
    (cd "$ROOT" && eval "$cmd") >"$tmp_out" 2>&1
    local rc=$?

    if [ $rc -ne 0 ]; then
        failures=$((failures + 1))
        {
            echo "==== $label FAILED (exit $rc) ===="
            echo "\$ $cmd"
            echo
            cat "$tmp_out"
            echo
        } >&2

        {
            echo "## $label FAILED"
            echo
            echo '```'
            echo "\$ $cmd"
            cat "$tmp_out"
            echo '```'
            echo
        } >>"$REPORT_FILE.tmp"
    fi
}

# Fresh report
: >"$REPORT_FILE.tmp"
{
    echo "# validate-fast report"
    echo
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
} >>"$REPORT_FILE.tmp"

run_cmd "TypeCheck" "$TYPECHECK_CMD"
run_cmd "Lint"      "$LINT_CMD"

if [ "$failures" -gt 0 ]; then
    mv "$REPORT_FILE.tmp" "$REPORT_FILE"
    echo "==== VALIDATE-FAST FAILED ====" >&2
    echo "Report written to $REPORT_FILE" >&2
    echo "Bypass (mid-refactor only): export AGENTS_SKIP_VALIDATE_HOOK=1" >&2
    exit 2
fi

rm -f "$REPORT_FILE.tmp" "$REPORT_FILE"
echo "VALIDATE-FAST PASSED"
exit 0
