#!/bin/bash
# load-config.sh — sourceable helper that exports FLOW_* threshold vars
# read from $DEV_DIR/flow.config.yaml (per-project override) on top of
# the defaults documented in _rules/flow.md.
#
# Contract: defines `flow_load_config <dev_dir>`. Caller passes its
# resolved DEV_DIR; missing/invalid file → silently keep defaults.
# Never hard-fails — coverage / size checks must keep working even
# when the config file is malformed.

# Defaults (must match _rules/flow.md table). Exported so subprocesses
# (python3 inline blocks in lang-*.sh) can read them via os.environ.
export FLOW_COV_LINE="${FLOW_COV_LINE:-80}"
export FLOW_COV_BRANCH="${FLOW_COV_BRANCH:-60}"
export FLOW_CYCLO_WARN="${FLOW_CYCLO_WARN:-10}"
export FLOW_CYCLO_FAIL="${FLOW_CYCLO_FAIL:-15}"
export FLOW_COGNI_WARN="${FLOW_COGNI_WARN:-15}"
export FLOW_FILE_LINES="${FLOW_FILE_LINES:-399}"
export FLOW_DUP_TOKENS="${FLOW_DUP_TOKENS:-5}"
export FLOW_MUT_MIN="${FLOW_MUT_MIN:-60}"
export FLOW_DEP_CYCLES="${FLOW_DEP_CYCLES:-0}"
export FLOW_SKIP="${FLOW_SKIP:-}"

flow_load_config() {
    local dev_dir="$1"
    [ -n "$dev_dir" ] || return 0
    local cfg="$dev_dir/flow.config.yaml"
    [ -f "$cfg" ] || return 0

    # Prefer whichever python has PyYAML available so we get real YAML
    # parsing. Fall back to any python (the inline script then uses its
    # built-in regex parser for the small known schema).
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local venv_py="$(cd "$script_dir/.." && pwd)/.venv/bin/python"
    local py=""
    local candidate
    for candidate in "$venv_py" "python3"; do
        [ -n "$candidate" ] || continue
        if [ "$candidate" = "$venv_py" ] && [ ! -x "$candidate" ]; then
            continue
        fi
        if "$candidate" -c "import yaml" 2>/dev/null; then
            py="$candidate"
            break
        fi
    done
    if [ -z "$py" ]; then
        if [ -x "$venv_py" ]; then py="$venv_py"
        elif command -v python3 >/dev/null 2>&1; then py="python3"
        else return 0
        fi
    fi

    local exports
    exports=$("$py" - "$cfg" <<'PY' 2>/dev/null
import re, sys
path = sys.argv[1]
try:
    with open(path) as f:
        text = f.read()
except Exception:
    sys.exit(0)

data = None
try:
    import yaml  # type: ignore
    data = yaml.safe_load(text) or {}
except Exception:
    data = None

if data is None:
    # Minimal fallback parser for the known schema. Recognises 2-space
    # indentation, scalar leaf values, inline lists `[a, b]`, and
    # block lists introduced by `key:` followed by `- item` lines.
    data = {}
    # Stack entries: (indent, container, key_in_grandparent, grandparent).
    # The grandparent ref lets us swap a placeholder dict to a list when
    # we discover the next line is a `- ` item.
    stack = [(-1, data, None, None)]
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        key_part = line.strip()
        while len(stack) > 1 and indent <= stack[-1][0]:
            stack.pop()
        parent_indent, parent, parent_key, grandparent = stack[-1]
        if key_part.startswith("- "):
            # Promote the placeholder dict to a list if needed.
            if isinstance(parent, dict) and not parent and grandparent is not None:
                parent = []
                grandparent[parent_key] = parent
                stack[-1] = (parent_indent, parent, parent_key, grandparent)
            if isinstance(parent, list):
                parent.append(key_part[2:].strip().strip('"').strip("'"))
            continue
        if ":" not in key_part:
            continue
        key, _, value = key_part.partition(":")
        key = key.strip()
        value = value.strip()
        if value == "":
            new = {}
            if isinstance(parent, dict):
                parent[key] = new
                stack.append((indent, new, key, parent))
        elif value.startswith("[") and value.endswith("]"):
            items = [v.strip().strip('"').strip("'") for v in value[1:-1].split(",") if v.strip()]
            if isinstance(parent, dict):
                parent[key] = items
        else:
            v = value.strip('"').strip("'")
            if isinstance(parent, dict):
                parent[key] = v

def get(d, *path, default=None):
    cur = d
    for p in path:
        if not isinstance(cur, dict) or p not in cur:
            return default
        cur = cur[p]
    return cur if cur is not None else default

mapping = [
    ("FLOW_COV_LINE",    get(data, "coverage", "line")),
    ("FLOW_COV_BRANCH",  get(data, "coverage", "branch")),
    ("FLOW_CYCLO_WARN",  get(data, "complexity", "cyclomatic", "warn")),
    ("FLOW_CYCLO_FAIL",  get(data, "complexity", "cyclomatic", "fail")),
    ("FLOW_COGNI_WARN",  get(data, "complexity", "cognitive", "warn")),
    ("FLOW_FILE_LINES",  get(data, "files", "lines", "fail")),
    ("FLOW_DUP_TOKENS",  get(data, "duplication", "tokens")),
    ("FLOW_MUT_MIN",     get(data, "mutation", "minScore")),
    ("FLOW_DEP_CYCLES",  get(data, "dependencies", "cyclesAllowed")),
]
for name, value in mapping:
    if value is None:
        continue
    s = str(value).replace("'", "")
    print(f"export {name}='{s}'")

skip = get(data, "skip", default=[])
if isinstance(skip, list) and skip:
    joined = " ".join(str(s).replace("'", "") for s in skip)
    print(f"export FLOW_SKIP='{joined}'")
PY
    )
    if [ -n "$exports" ]; then
        eval "$exports"
    fi
}

flow_skip_contains() {
    # Returns 0 if $1 is in $FLOW_SKIP (space-separated).
    local needle="$1"
    case " ${FLOW_SKIP:-} " in
        *" $needle "*) return 0 ;;
        *) return 1 ;;
    esac
}
