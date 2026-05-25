#!/bin/bash
# flow-metrics setup — creates a skill-local venv with the Python tools
# needed by lang-py.sh (radon, pydeps, pytest-cov). The venv lives at
# $SKILL_DIR/.venv so it's not synced into .claude/ / .kimi/ copies of
# the framework. Idempotent: exits quickly if the venv already exists.
#
# Network access is required on first run to pip-install the deps.
# When offline, this script exits non-zero and lang-py.sh will skip
# tools that need the venv — graceful degradation.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$SKILL_DIR/.venv"
MARKER="$VENV_DIR/.flow-metrics-installed"

if [ -f "$MARKER" ]; then
    exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "flow-metrics setup: python3 not found; skipping" >&2
    exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR" >/dev/null 2>&1 || {
        echo "flow-metrics setup: failed to create venv at $VENV_DIR" >&2
        exit 1
    }
fi

"$VENV_DIR/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1 || true
if ! "$VENV_DIR/bin/pip" install --quiet \
    radon pydeps pytest pytest-cov pyyaml >/dev/null 2>&1; then
    echo "flow-metrics setup: pip install failed (offline?)" >&2
    exit 1
fi

touch "$MARKER"
exit 0
