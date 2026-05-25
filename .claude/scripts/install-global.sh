#!/bin/bash
# install-global.sh — Install agents framework globally.
#
# Self-contained — no dependency on tools/sync/ or .claude/.
# Copies skills, agents, rules, and scripts from the framework directory
# (where this script lives) to the global location, making them available
# in any project without a local install.
#
# Auto-detects framework type from parent directory name:
#   .claude/scripts/install-global.sh -> installs to ~/.claude/
#   .kimi/scripts/install-global.sh   -> installs to ~/.kimi/
#   .agents/scripts/install-global.sh -> installs to ~/.claude/ (default)  # sync:keep
#
# Usage:
#   bash .claude/scripts/install-global.sh              # Install to ~/.claude/
#   bash .kimi/scripts/install-global.sh                # Install to ~/.kimi/
#   bash ~/.claude/scripts/install-global.sh             # Re-install from global

set -e

# Detect framework dir: parent of scripts/ where this file lives
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_TYPE="$(basename "$SOURCE")"

# Determine target based on framework type
case "$FRAMEWORK_TYPE" in
    .claude) TARGET="$HOME/.claude" ;;
    .kimi)   TARGET="$HOME/.kimi" ;;
    .agents) TARGET="$HOME/.claude" ;;  # sync:keep
    *)       TARGET="$HOME/.claude" ;;
esac

DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY_RUN=true ;;
        --help|-h)
            echo "Usage: bash <path>/install-global.sh [--dry-run]"
            echo ""
            echo "Install agents framework globally."
            echo "Target is auto-detected from the framework directory name."
            echo ""
            echo "Options:"
            echo "  --dry-run    Preview what would be copied"
            echo ""
            echo "Directories copied: skills/, agents/, rules/, scripts/"
            echo "Settings are merged into the global config."
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

# Validate source has framework content
if [ ! -d "$SOURCE/skills" ]; then
    echo "Error: $SOURCE/skills/ not found. Not a valid framework directory." >&2
    exit 1
fi

# Don't copy onto self
SOURCE_REAL="$(cd "$SOURCE" && pwd -P)"
TARGET_REAL="$(mkdir -p "$TARGET" && cd "$TARGET" && pwd -P)"
if [ "$SOURCE_REAL" = "$TARGET_REAL" ]; then
    echo "Already installed at $SOURCE_REAL — nothing to copy."
    echo ""
    echo "To update, run this script from a project-local or repo copy:"
    echo "  bash /path/to/repo/.claude/scripts/install-global.sh"  # sync:keep
    exit 0
fi

echo "Installing agents framework globally"
echo "  Source: $SOURCE"
echo "  Target: $TARGET"
echo ""

# Directories to copy
DIRS=(skills agents rules scripts)

for dir in "${DIRS[@]}"; do
    src="$SOURCE/$dir"
    dst="$TARGET/$dir"
    if [ ! -d "$src" ]; then
        echo "  skip $dir/ (not found in source)"
        continue
    fi
    if $DRY_RUN; then
        count=$(find "$src" -type f | wc -l | tr -d ' ')
        echo "  [dry-run] would copy $dir/ ($count files)"
    else
        mkdir -p "$dst"
        rsync -a --delete "$src/" "$dst/"
        count=$(find "$dst" -type f | wc -l | tr -d ' ')
        echo "  copied $dir/ ($count files)"
    fi
done

# Merge hooks into global settings
SETTINGS_SRC="$SOURCE/settings.json"
SETTINGS_DST="$TARGET/settings.json"
CONFIG_SRC="$SOURCE/config.toml"
CONFIG_DST="$TARGET/config.toml"

# Claude target: merge settings.json
if [ -f "$SETTINGS_SRC" ] && [ "$FRAMEWORK_TYPE" != ".kimi" ]; then
    if $DRY_RUN; then
        echo "  [dry-run] would merge hooks into $SETTINGS_DST"
    else
        if [ ! -f "$SETTINGS_DST" ]; then
            mkdir -p "$TARGET"
            cp "$SETTINGS_SRC" "$SETTINGS_DST"
            echo "  created $SETTINGS_DST"
        else
            python3 -c "
import json
from pathlib import Path

MARKER_KEY = '_managed_by_sync'
MARKER_VAL = 'tools/sync (do not edit by hand)'

src = json.loads(Path('$SETTINGS_SRC').read_text())
dst = json.loads(Path('$SETTINGS_DST').read_text())

hooks = dict(dst.get('hooks', {}) or {})
for event, entries in list(hooks.items()):
    kept = [e for e in (entries or []) if not (isinstance(e, dict) and e.get(MARKER_KEY) == MARKER_VAL)]
    if kept:
        hooks[event] = kept
    else:
        hooks.pop(event, None)

for event, entries in (src.get('hooks', {}) or {}).items():
    managed = [e for e in entries if isinstance(e, dict) and e.get(MARKER_KEY) == MARKER_VAL]
    if managed:
        hooks.setdefault(event, []).extend(managed)

if hooks:
    dst['hooks'] = hooks
else:
    dst.pop('hooks', None)

if 'statusLine' in src:
    dst['statusLine'] = src['statusLine']

Path('$SETTINGS_DST').write_text(json.dumps(dst, indent=2) + '\n')
" 2>&1
            echo "  merged hooks into $SETTINGS_DST"
        fi
    fi
fi

# Kimi target: merge config.toml
if [ -f "$CONFIG_SRC" ] && [ "$FRAMEWORK_TYPE" = ".kimi" ]; then
    if $DRY_RUN; then
        echo "  [dry-run] would merge hooks into $CONFIG_DST"
    else
        if [ ! -f "$CONFIG_DST" ]; then
            mkdir -p "$TARGET"
            cp "$CONFIG_SRC" "$CONFIG_DST"
            echo "  created $CONFIG_DST"
        else
            cp "$CONFIG_SRC" "$CONFIG_DST"
            echo "  replaced $CONFIG_DST"
        fi
    fi
fi

echo ""
if $DRY_RUN; then
    echo "Dry run complete. No files were modified."
else
    echo "Installation complete."
    echo ""
    echo "The framework is now available globally. Skills will auto-detect"
    echo "whether to use local or global paths."
    echo "Local project installs always take priority over global."
fi
