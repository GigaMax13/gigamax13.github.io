#!/bin/bash
# lang-go.sh — Go metric collector.
# Emits JSON to stdout with {language, metrics[], skipped[]}. Never exits non-zero.

set -u

TARGET="."
DEV_DIR=""
QUICK=0
while [ $# -gt 0 ]; do
    case "$1" in
        --target)  TARGET="$2"; shift 2 ;;
        --dev-dir) DEV_DIR="$2"; shift 2 ;;
        --quick)   QUICK="$2"; shift 2 ;;
        *) shift ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-config.sh
[ -f "$SCRIPT_DIR/load-config.sh" ] && . "$SCRIPT_DIR/load-config.sh" && flow_load_config "$DEV_DIR"

cd "$TARGET" 2>/dev/null || { echo '{"language":"go","status":"bad_target"}'; exit 0; }

have() { command -v "$1" >/dev/null 2>&1; }

read_coverage_cmd_from_test_map() {
    [ -n "$DEV_DIR" ] || return 0
    local map="$DEV_DIR/.test-map.md"
    [ -f "$map" ] || return 0
    python3 - "$map" <<'PY' 2>/dev/null
import sys
path = sys.argv[1]
try:
    with open(path) as f:
        text = f.read()
except Exception:
    sys.exit(0)
in_table = False
for line in text.splitlines():
    if line.startswith("## Test Roots"):
        in_table = True
        continue
    if in_table and line.startswith("## "):
        break
    if not in_table or not line.strip().startswith("|"):
        continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) < 5:
        continue
    if cells[0] in ("Root", "") or cells[1].lower() in ("runner", ""):
        continue
    if all(set(c) <= set("- :") for c in cells):
        continue
    if cells[1].lower() != "go":
        continue
    cmd = cells[4]
    if cmd and cmd != "(unsupported runner)":
        print(cmd)
    break
PY
}

METRICS_JSON=""
SKIPPED_JSON=""

add_metric() {
    local entry
    entry=$(python3 -c "import json,sys; print(json.dumps({'tool':sys.argv[1],'metric':sys.argv[2],'value':sys.argv[3],'threshold':sys.argv[4],'severity':sys.argv[5],'location':sys.argv[6]}))" "$1" "$2" "$3" "$4" "$5" "$6")
    if [ -z "$METRICS_JSON" ]; then METRICS_JSON="$entry"; else METRICS_JSON="$METRICS_JSON,$entry"; fi
}

add_skipped() {
    local entry
    entry=$(python3 -c "import json,sys; print(json.dumps({'tool':sys.argv[1],'reason':sys.argv[2]}))" "$1" "$2")
    if [ -z "$SKIPPED_JSON" ]; then SKIPPED_JSON="$entry"; else SKIPPED_JSON="$SKIPPED_JSON,$entry"; fi
}

# ---------- File sizes ----------
while IFS= read -r f; do
    lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
    [ -z "$lines" ] && continue
    if [ "$lines" -gt "$FLOW_FILE_LINES" ]; then
        add_metric "wc" "file-lines" "$lines" "$FLOW_FILE_LINES" "fail" "$f"
    fi
done < <(find . -type f -name "*.go" ! -path "*/vendor/*" 2>/dev/null)

# ---------- Complexity (gocyclo) ----------
if flow_skip_contains complexity; then
    add_skipped "gocyclo" "skipped via flow.config.yaml"
elif have gocyclo; then
    while read -r line; do
        [ -z "$line" ] && continue
        c=$(echo "$line" | awk '{print $1}')
        loc=$(echo "$line" | awk '{print $NF}')
        name=$(echo "$line" | awk '{print $3}')
        [ -z "$c" ] && continue
        case "$c" in ''|*[!0-9]*) continue ;; esac
        if [ "$c" -gt "$FLOW_CYCLO_FAIL" ]; then sev="fail"
        elif [ "$c" -gt "$FLOW_CYCLO_WARN" ]; then sev="warn"
        else continue; fi
        add_metric "gocyclo" "cyclomatic" "$c" "$FLOW_CYCLO_WARN" "$sev" "$loc ($name)"
    done < <(gocyclo -over "$FLOW_CYCLO_WARN" . 2>/dev/null || true)
else
    add_skipped "gocyclo" "not installed"
fi

# ---------- Coverage (go test -cover) ----------
cov_fail() {
    add_metric "coverage" "line-%" "unmeasured" "$FLOW_COV_LINE" "fail" "$1"
}
if flow_skip_contains coverage; then
    add_skipped "coverage" "skipped via flow.config.yaml"
elif [ "$QUICK" = "1" ]; then
    add_skipped "coverage" "quick mode"
else
    MAP_CMD="$(read_coverage_cmd_from_test_map)"
    if [ -n "$MAP_CMD" ]; then
        OUT=$(eval "$MAP_CMD" 2>&1 || true)
        TOTAL=$(echo "$OUT" | grep -oE 'coverage: [0-9.]+%' | awk '{s+=$2; n++} END {if (n>0) print s/n; else print ""}')
        if [ -n "$TOTAL" ]; then
            if awk "BEGIN {exit !($TOTAL < $FLOW_COV_LINE)}"; then
                add_metric "go-test" "line-%" "$TOTAL" "$FLOW_COV_LINE" "fail" "-"
            fi
        else
            short=$(printf '%s' "$OUT" | tail -n1 | head -c 200)
            cov_fail "test-map cmd produced no coverage output: ${short:-no stderr}"
        fi
    elif ! have go; then
        cov_fail "go not installed"
    else
        TOTAL=$(go test -cover ./... 2>/dev/null | grep -oE 'coverage: [0-9.]+%' | awk '{s+=$2; n++} END {if (n>0) print s/n; else print ""}')
        if [ -n "$TOTAL" ]; then
            if awk "BEGIN {exit !($TOTAL < $FLOW_COV_LINE)}"; then
                add_metric "go-test" "line-%" "$TOTAL" "$FLOW_COV_LINE" "fail" "-"
            fi
        else
            cov_fail "go test -cover produced no output"
        fi
    fi
fi

# ---------- Duplication (dupl) ----------
if flow_skip_contains duplication; then
    add_skipped "dupl" "skipped via flow.config.yaml"
elif have dupl; then
    HITS=$(dupl -t 50 . 2>/dev/null | grep -c '^found' || true)
    if [ "$HITS" -gt "$FLOW_DUP_TOKENS" ]; then
        add_metric "dupl" "duplication-hits" "$HITS" "$FLOW_DUP_TOKENS" "warn" "-"
    fi
else
    add_skipped "dupl" "not installed"
fi

# ---------- Dependency cycles (go mod graph + parser) ----------
if flow_skip_contains dependencies; then
    add_skipped "dependencies" "skipped via flow.config.yaml"
elif have go; then
    # Build adjacency, then DFS for cycles. Minimal implementation.
    HAS_CYCLES=$(go mod graph 2>/dev/null | python3 -c "
import sys
from collections import defaultdict
g = defaultdict(list)
for line in sys.stdin:
    parts = line.split()
    if len(parts) == 2:
        g[parts[0]].append(parts[1])
visited = set()
stack = set()
found = [False]
def dfs(n):
    if n in stack:
        found[0] = True; return
    if n in visited: return
    visited.add(n); stack.add(n)
    for nb in g[n]:
        dfs(nb)
        if found[0]: return
    stack.discard(n)
for node in list(g):
    if found[0]: break
    dfs(node)
print('yes' if found[0] else 'no')
")
    if [ "$HAS_CYCLES" = "yes" ]; then
        add_metric "go-mod" "dep-cycles" "1+" "$FLOW_DEP_CYCLES" "warn" "-"
    fi
else
    add_skipped "dependencies" "go not installed"
fi

# ---------- Mutation (go-mutesting) ----------
# Off by default (slow). FLOW_RUN_MUTATION=1 (set by collect.sh
# --include-mutation) opts in. go-mutesting needs no config, so no scaffold.
if flow_skip_contains mutation; then
    add_skipped "mutation" "skipped via flow.config.yaml"
elif [ "${FLOW_RUN_MUTATION:-0}" != "1" ]; then
    if have go-mutesting; then
        add_skipped "mutation" "go-mutesting installed; pass --include-mutation to run (slow)"
    else
        add_skipped "mutation" "go-mutesting not installed (go install github.com/zimmski/go-mutesting/cmd/go-mutesting@latest)"
    fi
elif ! have go-mutesting; then
    add_skipped "mutation" "go-mutesting not installed"
else
    # go-mutesting prints a final line: "The mutation score is 0.750000 (3 passed, 1 failed, 0 duplicated, 0 skipped, total is 4)"
    OUT=$(go-mutesting ./... 2>&1 || true)
    score=$(printf '%s' "$OUT" | python3 -c "
import re, sys
text = sys.stdin.read()
m = re.search(r'mutation score is ([\d.]+)', text)
if not m:
    sys.exit(0)
print(round(float(m.group(1)) * 100, 1))
" 2>/dev/null)
    if [ -n "$score" ] && awk "BEGIN {exit !($score < $FLOW_MUT_MIN)}"; then
        add_metric "go-mutesting" "mutation-score" "$score" "$FLOW_MUT_MIN" "info" "-"
    elif [ -z "$score" ]; then
        add_skipped "mutation" "go-mutesting ran but score line missing from output"
    fi
fi

printf '{"language":"go","metrics":[%s],"skipped":[%s]}\n' "$METRICS_JSON" "$SKIPPED_JSON"
exit 0
