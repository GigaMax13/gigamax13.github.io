#!/bin/bash
# Print the resolved .dev directory path.
#
# Used by skills (markdown instructions) to determine where to read/write
# .dev/ artifacts (review.md, .test-map.md, state.md, etc.).
#
# Usage: bash <path>/resolve-dev.sh
# Output: absolute path to .dev directory (no trailing slash)
#
# Resolution order (from resolve-paths.sh):
#   1. $AGENTS_DEV_DIR (explicit override)
#   2. $PROJECT_ROOT/.dev if it already exists
#   3. $SKILLS_HOME/.dev (framework dir)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=resolve-paths.sh
source "$SCRIPT_DIR/resolve-paths.sh"

echo "$DEV_DIR"
