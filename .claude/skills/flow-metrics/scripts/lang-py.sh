#!/bin/bash
# lang-py.sh — Python metric collector.
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

LANG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-config.sh
[ -f "$LANG_SCRIPT_DIR/load-config.sh" ] && . "$LANG_SCRIPT_DIR/load-config.sh" && flow_load_config "$DEV_DIR"

cd "$TARGET" 2>/dev/null || { echo '{"language":"py","status":"bad_target"}'; exit 0; }

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
    if cells[1].lower() != "pytest":
        continue
    cmd = cells[4]
    if cmd and cmd != "(unsupported runner)":
        print(cmd)
    break
PY
}

# Discover python package roots under the current target.
# Returns newline-separated dirs containing __init__.py across common
# monorepo layouts. Empty output => caller should skip with an accurate reason.
discover_py_packages() {
    local pattern pkg
    local seen=""
    for pattern in \
        "src/*/__init__.py" \
        "*/__init__.py" \
        "apps/*/src/*/__init__.py" \
        "packages/*/src/*/__init__.py" \
        "apps/*/*/__init__.py" \
        "packages/*/*/__init__.py"
    do
        for pkg in $pattern; do
            [ -f "$pkg" ] || continue
            local d
            d="$(dirname "$pkg")"
            case " $seen " in *" $d "*) continue ;; esac
            seen="$seen $d"
            echo "$d"
        done
    done
}

# Resolve a python venv with the tools we need. We prefer a venv that
# actually has `radon` installed (our most-used tool), falling back to
# any venv with python, then to system python. The skill-local venv
# ($SCRIPT_DIR/../.venv, created by setup.sh) is the fallback when the
# host project has no venv of its own.
PY="python3"
PYBIN_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANDIDATES=(".venv/bin" "venv/bin" "tools/sync/.venv/bin" "$SCRIPT_DIR/../.venv/bin")

for candidate in "${CANDIDATES[@]}"; do
    if [ -x "$candidate/radon" ]; then PYBIN_DIR="$candidate"; break; fi
done
if [ -z "$PYBIN_DIR" ]; then
    for candidate in "${CANDIDATES[@]}"; do
        if [ -x "$candidate/python" ]; then PYBIN_DIR="$candidate"; break; fi
    done
fi

METRICS_JSON=""
SKIPPED_JSON=""

add_metric() {
    local entry
    entry=$($PY -c "import json,sys; print(json.dumps({'tool':sys.argv[1],'metric':sys.argv[2],'value':sys.argv[3],'threshold':sys.argv[4],'severity':sys.argv[5],'location':sys.argv[6]}))" "$1" "$2" "$3" "$4" "$5" "$6")
    if [ -z "$METRICS_JSON" ]; then METRICS_JSON="$entry"; else METRICS_JSON="$METRICS_JSON,$entry"; fi
}

add_skipped() {
    local entry
    entry=$($PY -c "import json,sys; print(json.dumps({'tool':sys.argv[1],'reason':sys.argv[2]}))" "$1" "$2")
    if [ -z "$SKIPPED_JSON" ]; then SKIPPED_JSON="$entry"; else SKIPPED_JSON="$SKIPPED_JSON,$entry"; fi
}

run_in_env() {
    # $1 = binary name; rest = args. Prefer $PYBIN_DIR/$1 if available.
    local bin="$1"; shift
    if [ -n "$PYBIN_DIR" ] && [ -x "$PYBIN_DIR/$bin" ]; then
        "$PYBIN_DIR/$bin" "$@"
    elif have "$bin"; then
        "$bin" "$@"
    else
        return 127
    fi
}

# ---------- File sizes ----------
while IFS= read -r f; do
    lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
    [ -z "$lines" ] && continue
    if [ "$lines" -gt "$FLOW_FILE_LINES" ]; then
        add_metric "wc" "file-lines" "$lines" "$FLOW_FILE_LINES" "fail" "$f"
    fi
done < <(find . -type f -name "*.py" \
    ! -path "*/.venv/*" ! -path "*/venv/*" ! -path "*/__pycache__/*" \
    ! -path "*/.mypy_cache/*" ! -path "*/node_modules/*" 2>/dev/null)

# ---------- Complexity (radon) ----------
CC_JSON=""
if flow_skip_contains complexity; then
    add_skipped "radon" "skipped via flow.config.yaml"
elif CC_JSON=$(run_in_env radon cc -j -a -n C . 2>/dev/null); then
    echo "$CC_JSON" | $PY -c "
import json, os, sys
warn = int(os.environ.get('FLOW_CYCLO_WARN', '10'))
fail = int(os.environ.get('FLOW_CYCLO_FAIL', '15'))
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for fpath, items in d.items():
    for it in items:
        c = it.get('complexity', 0)
        if c > fail:
            sev = 'fail'
        elif c > warn:
            sev = 'warn'
        else:
            continue
        loc = f\"{fpath}:{it.get('lineno',0)}\"
        name = it.get('name','?')
        print(f\"{c}|{sev}|{loc}|{name}\")
" > /tmp/flow-radon-$$.txt 2>/dev/null
    while IFS='|' read -r c sev loc name; do
        [ -z "$c" ] && continue
        add_metric "radon" "cyclomatic" "$c" "$FLOW_CYCLO_WARN" "$sev" "$loc ($name)"
    done < /tmp/flow-radon-$$.txt
    rm -f /tmp/flow-radon-$$.txt
else
    add_skipped "radon" "not installed"
fi

# ---------- Coverage (pytest --cov) ----------
cov_fail() {
    add_metric "coverage" "line-%" "unmeasured" "$FLOW_COV_LINE" "fail" "$1"
}
if flow_skip_contains coverage; then
    add_skipped "coverage" "skipped via flow.config.yaml"
elif [ "$QUICK" = "1" ]; then
    add_skipped "coverage" "quick mode"
else
    COV_JSON=""
    if [ -f "coverage.json" ]; then
        COV_JSON="coverage.json"
    else
        MAP_CMD="$(read_coverage_cmd_from_test_map)"
        if [ -n "$MAP_CMD" ]; then
            ERR=$(eval "$MAP_CMD" 2>&1 >/dev/null) || true
            [ -f "coverage.json" ] && COV_JSON="coverage.json"
            if [ -z "$COV_JSON" ]; then
                short=$(printf '%s' "$ERR" | tail -n1 | head -c 200)
                cov_fail "test-map cmd produced no coverage.json: ${short:-no stderr}"
            fi
        elif ! run_in_env pytest --version >/dev/null 2>&1; then
            cov_fail "pytest not installed"
        elif ! run_in_env python3 -c "import pytest_cov" >/dev/null 2>&1; then
            cov_fail "pytest-cov not installed"
        else
            run_in_env pytest --cov --cov-report=json:coverage.json --cov-report= -q >/dev/null 2>&1 || true
            if [ -f "coverage.json" ]; then
                COV_JSON="coverage.json"
            else
                cov_fail "pytest-cov run produced no coverage.json"
            fi
        fi
    fi
    if [ -n "$COV_JSON" ]; then
        read -r line_pct branch_pct < <($PY -c "
import json
d = json.load(open('$COV_JSON'))
t = d.get('totals', {})
print(t.get('percent_covered', 0), t.get('percent_covered_display', 0))
")
        if awk "BEGIN {exit !($line_pct < $FLOW_COV_LINE)}"; then
            add_metric "pytest-cov" "line-%" "$line_pct" "$FLOW_COV_LINE" "fail" "-"
        fi
    fi
fi

# ---------- Duplication (skipped by default — pylint is slow) ----------
add_skipped "duplication" "pylint duplicate-code not run (too slow for collector)"

# ---------- Dependency cycles (pydeps) ----------
if flow_skip_contains dependencies; then
    add_skipped "dependencies" "skipped via flow.config.yaml"
elif run_in_env pydeps --version >/dev/null 2>&1; then
    # pydeps requires a module path; best-effort: first package discovered.
    PKG="$(discover_py_packages | head -1)"
    if [ -n "$PKG" ]; then
        CYCLE_OUT=$(run_in_env pydeps --show-cycles --no-show --no-output "$PKG" 2>&1 || true)
        cycle_count=$(echo "$CYCLE_OUT" | grep -cE '^cycle' || true)
        if [ "$cycle_count" -gt "$FLOW_DEP_CYCLES" ]; then
            add_metric "pydeps" "dep-cycles" "$cycle_count" "$FLOW_DEP_CYCLES" "warn" "$PKG"
        fi
    else
        add_skipped "dependencies" "no python package found"
    fi
else
    add_skipped "dependencies" "pydeps not installed"
fi

# ---------- Mutation (mutmut) ----------
# Off by default (slow). FLOW_RUN_MUTATION=1 (set by collect.sh
# --include-mutation) opts in: scaffold a [tool.mutmut] block if missing,
# run mutmut, parse killed/total ratio, gate against $FLOW_MUT_MIN.
mutmut_configured() {
    grep -q '\[tool\.mutmut\]' pyproject.toml 2>/dev/null && return 0
    { [ -f "setup.cfg" ] && grep -q '\[mutmut\]' setup.cfg 2>/dev/null; } && return 0
    return 1
}
if flow_skip_contains mutation; then
    add_skipped "mutation" "skipped via flow.config.yaml"
elif [ "${FLOW_RUN_MUTATION:-0}" != "1" ]; then
    if mutmut_configured; then
        add_skipped "mutation" "mutmut configured; pass --include-mutation to run (slow)"
    else
        add_skipped "mutation" "no mutmut config; run scaffold-mutation.sh + --include-mutation"
    fi
elif ! have mutmut; then
    add_skipped "mutation" "mutmut not installed (pip install mutmut)"
else
    if ! mutmut_configured; then
        bash "$LANG_SCRIPT_DIR/scaffold-mutation.sh" --target . --lang py >/dev/null 2>&1 || true
    fi
    mutmut run >/dev/null 2>&1 || true
    JSON_OUT=$(mutmut results --json 2>/dev/null || echo "")
    if [ -n "$JSON_OUT" ]; then
        score=$(printf '%s' "$JSON_OUT" | python3 - <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
killed = len(d.get("killed", []))
survived = len(d.get("survived", []))
timeout = len(d.get("timeout", []))
suspicious = len(d.get("suspicious", []))
total = killed + survived + timeout + suspicious
if total == 0:
    sys.exit(0)
print(round(100.0 * killed / total, 1))
PY
)
        if [ -n "$score" ] && awk "BEGIN {exit !($score < $FLOW_MUT_MIN)}"; then
            add_metric "mutmut" "mutation-score" "$score" "$FLOW_MUT_MIN" "info" "-"
        elif [ -z "$score" ]; then
            add_skipped "mutation" "mutmut ran but no mutants produced"
        fi
    else
        add_skipped "mutation" "mutmut produced no parseable results"
    fi
fi

# ---------- Emit JSON ----------
printf '{"language":"py","metrics":[%s],"skipped":[%s]}\n' "$METRICS_JSON" "$SKIPPED_JSON"
exit 0
