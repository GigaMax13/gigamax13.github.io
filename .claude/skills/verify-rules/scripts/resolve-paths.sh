#!/bin/bash
# Shared path resolution for agents framework scripts.
#
# Source this file AFTER setting SCRIPT_DIR in the calling script.
# Exports: PROJECT_ROOT, SKILLS_HOME, DEV_DIR
#
# Resolution for PROJECT_ROOT:
#   1. $AGENTS_PROJECT_ROOT (explicit override)
#   2. git rev-parse --show-toplevel (cwd-anchored, beats stale env)
#   3. $CLAUDE_PROJECT_DIR (set by Claude Code for hooks)
#   4. Walk up from CWD looking for CLAUDE.md or AGENTS.md  # sync:keep
#   5. Fallback: CWD
#
# When step 2 wins and disagrees with $CLAUDE_PROJECT_DIR (i.e. a stale
# env var from a previous session), a one-line warning goes to stderr
# so the divergence is visible without aborting the run.
#
# Resolution for SKILLS_HOME:
#   1. $AGENTS_SKILLS_HOME (explicit override)
#   2. Walk up from SCRIPT_DIR to find .claude/, .kimi/, or .agents/ parent  # sync:keep
#   3. Fallback: $PROJECT_ROOT/.claude, then $HOME/.claude
#
# Resolution for DEV_DIR:
#   1. $AGENTS_DEV_DIR (explicit override)
#   2. $PROJECT_ROOT/.dev if it already exists (host project owns it)
#   3. $SKILLS_HOME/.dev (framework dir — never creates .dev at project root)
#
# Boundary guard: the chosen DEV_DIR must live under either PROJECT_ROOT
# or SKILLS_HOME. If $AGENTS_DEV_DIR is an explicit override pointing
# outside both, it's rejected with a stderr warning and we fall back to
# $SKILLS_HOME/.dev. This prevents one project's loop from writing
# artifacts into a sibling project's tree.

_resolve_project_root() {
    if [ -n "${AGENTS_PROJECT_ROOT:-}" ]; then
        echo "$AGENTS_PROJECT_ROOT"
        return
    fi
    local root
    if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        echo "$root"
        return
    fi
    if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
        echo "$CLAUDE_PROJECT_DIR"
        return
    fi
    local cur
    cur="$(pwd)"
    while [ "$cur" != "/" ]; do
        if [ -f "$cur/CLAUDE.md" ] || [ -f "$cur/AGENTS.md" ]; then  # sync:keep
            echo "$cur"
            return
        fi
        cur="$(dirname "$cur")"
    done
    pwd
}

_resolve_skills_home() {
    if [ -n "${AGENTS_SKILLS_HOME:-}" ]; then
        echo "$AGENTS_SKILLS_HOME"
        return
    fi
    local d="${SCRIPT_DIR:-$(pwd)}"
    while [ "$d" != "/" ]; do
        local base
        base="$(basename "$d")"
        if [ "$base" = ".claude" ] || [ "$base" = ".kimi" ] || [ "$base" = ".agents" ]; then  # sync:keep
            echo "$d"
            return
        fi
        d="$(dirname "$d")"
    done
    local proj="$1"
    if [ -d "$proj/.claude/skills" ]; then
        echo "$proj/.claude"
    elif [ -d "$HOME/.claude/skills" ]; then
        echo "$HOME/.claude"
    else
        echo "$proj/.claude"
    fi
}

# Real path canonicalization that works on macOS (no GNU readlink -f).
_abspath() {
    local p="$1"
    [ -z "$p" ] && return 1
    if [ -d "$p" ]; then
        (cd "$p" 2>/dev/null && pwd -P)
    elif [ -e "$p" ]; then
        (cd "$(dirname "$p")" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$(basename "$p")")
    else
        # Doesn't exist yet — best-effort: canonicalize the parent.
        local parent
        parent="$(dirname "$p")"
        if [ -d "$parent" ]; then
            printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$(basename "$p")"
        else
            echo "$p"
        fi
    fi
}

# Returns 0 if $1 is the same path as $2 or a descendant of it.
_is_within() {
    local child parent
    child="$(_abspath "$1")"
    parent="$(_abspath "$2")"
    [ -z "$child" ] || [ -z "$parent" ] && return 1
    case "$child/" in
        "$parent/"*) return 0 ;;
        *) return 1 ;;
    esac
}

_resolve_dev_dir() {
    local proj="${1:-$(pwd)}"
    local skills="${2:-$proj/.claude}"
    local candidate
    if [ -n "${AGENTS_DEV_DIR:-}" ]; then
        candidate="$AGENTS_DEV_DIR"
    elif [ -d "$proj/.dev" ]; then
        candidate="$proj/.dev"
    else
        candidate="$skills/.dev"
    fi
    # Boundary guard: candidate must live under PROJECT_ROOT or SKILLS_HOME.
    # Otherwise we're at risk of writing into a sibling project (e.g. stale
    # AGENTS_DEV_DIR or a misresolved root). Fall back to $skills/.dev.
    if _is_within "$candidate" "$proj" || _is_within "$candidate" "$skills"; then
        echo "$candidate"
    else
        echo "[resolve-paths] warning: rejecting DEV_DIR=$candidate (outside PROJECT_ROOT=$proj and SKILLS_HOME=$skills); using $skills/.dev" >&2
        echo "$skills/.dev"
    fi
}

PROJECT_ROOT="$(_resolve_project_root)"
SKILLS_HOME="$(_resolve_skills_home "$PROJECT_ROOT")"
DEV_DIR="$(_resolve_dev_dir "$PROJECT_ROOT" "$SKILLS_HOME")"

# Coherence warning: surface (but don't act on) a stale CLAUDE_PROJECT_DIR
# that disagrees with the resolved root. Helps debugging cross-project bugs.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] \
   && [ -z "${AGENTS_PROJECT_ROOT:-}" ] \
   && ! _is_within "$CLAUDE_PROJECT_DIR" "$PROJECT_ROOT" \
   && ! _is_within "$PROJECT_ROOT" "$CLAUDE_PROJECT_DIR" ; then
    echo "[resolve-paths] warning: CLAUDE_PROJECT_DIR=$CLAUDE_PROJECT_DIR diverges from resolved PROJECT_ROOT=$PROJECT_ROOT (using PROJECT_ROOT)" >&2
fi

export PROJECT_ROOT
export SKILLS_HOME
export DEV_DIR
