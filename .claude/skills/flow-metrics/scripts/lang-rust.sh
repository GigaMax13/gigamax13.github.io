#!/bin/bash
# lang-rust.sh — Rust metric collector.
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

cd "$TARGET" 2>/dev/null || { echo '{"language":"rust","status":"bad_target"}'; exit 0; }

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
    if cells[1].lower() != "cargo":
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
done < <(find . -type f -name "*.rs" ! -path "*/target/*" 2>/dev/null)

# ---------- Complexity (clippy cognitive_complexity) ----------
if flow_skip_contains complexity; then
    add_skipped "complexity" "skipped via flow.config.yaml"
elif have cargo; then
    OUT=$(cargo clippy --message-format=json -- -W clippy::cognitive_complexity 2>/dev/null || true)
    echo "$OUT" | python3 -c "
import json, sys
for raw in sys.stdin:
    try:
        obj = json.loads(raw)
    except Exception:
        continue
    msg = obj.get('message')
    if not msg or msg.get('code', {}).get('code', '') != 'clippy::cognitive_complexity':
        continue
    for span in msg.get('spans', []):
        if span.get('is_primary'):
            print(f\"{span.get('file_name','?')}:{span.get('line_start',0)}|{msg.get('message','')}\")
            break
" > /tmp/flow-clippy-$$.txt 2>/dev/null
    while IFS='|' read -r loc msg; do
        [ -z "$loc" ] && continue
        n=$(echo "$msg" | grep -oE '[0-9]+' | head -1)
        [ -z "$n" ] && n="?"
        sev="warn"
        case "$n" in ''|*[!0-9]*) ;; *) [ "$n" -gt "$FLOW_CYCLO_FAIL" ] && sev="fail" ;; esac
        add_metric "clippy" "cognitive" "$n" "$FLOW_COGNI_WARN" "$sev" "$loc"
    done < /tmp/flow-clippy-$$.txt
    rm -f /tmp/flow-clippy-$$.txt
else
    add_skipped "complexity" "cargo not installed"
fi

# ---------- Coverage (cargo tarpaulin) ----------
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
        PCT=$(echo "$OUT" | grep -oE '[0-9.]+% coverage' | head -1 | awk '{print $1}' | tr -d '%')
        if [ -n "$PCT" ]; then
            if awk "BEGIN {exit !($PCT < $FLOW_COV_LINE)}"; then
                add_metric "tarpaulin" "line-%" "$PCT" "$FLOW_COV_LINE" "fail" "-"
            fi
        else
            short=$(printf '%s' "$OUT" | tail -n1 | head -c 200)
            cov_fail "test-map cmd produced no coverage output: ${short:-no stderr}"
        fi
    elif ! have cargo; then
        cov_fail "cargo not installed"
    elif ! cargo tarpaulin --version >/dev/null 2>&1; then
        cov_fail "cargo-tarpaulin not installed"
    else
        PCT=$(cargo tarpaulin --no-fail-fast 2>/dev/null | grep -oE '[0-9.]+% coverage' | head -1 | awk '{print $1}' | tr -d '%')
        if [ -n "$PCT" ]; then
            if awk "BEGIN {exit !($PCT < $FLOW_COV_LINE)}"; then
                add_metric "tarpaulin" "line-%" "$PCT" "$FLOW_COV_LINE" "fail" "-"
            fi
        else
            cov_fail "tarpaulin produced no output"
        fi
    fi
fi

# ---------- Duplication: no standard Rust tool ----------
add_skipped "duplication" "no standard rust duplication tool"

# ---------- Dependency cycles (cargo modules) ----------
if flow_skip_contains dependencies; then
    add_skipped "dependencies" "skipped via flow.config.yaml"
elif have cargo && cargo modules --version >/dev/null 2>&1; then
    add_skipped "dependencies" "cargo-modules installed; cycle detection not implemented in collector"
else
    add_skipped "dependencies" "cargo-modules not installed"
fi

# ---------- Mutation (cargo mutants) ----------
# Off by default (slow). FLOW_RUN_MUTATION=1 (set by collect.sh
# --include-mutation) opts in. cargo-mutants reads Cargo.toml — no scaffold.
# When the flag is off but a recent mutants.out/outcomes.json already exists,
# the cache is reused so the metric still surfaces in the report (mirrors
# how the TS collector reuses reports/mutation/mutation.json).

parse_cargo_mutants_score() {
    python3 - "$1" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
caught = d.get('caught', 0)
missed = d.get('missed', 0)
timeout = d.get('timeout', 0)
total = caught + missed + timeout
if total == 0:
    sys.exit(0)
print(round(100.0 * caught / total, 1))
PY
}

CARGO_MUTANTS_REPORT="mutants.out/outcomes.json"

if flow_skip_contains mutation; then
    add_skipped "mutation" "skipped via flow.config.yaml"
elif [ "${FLOW_RUN_MUTATION:-0}" != "1" ]; then
    if [ -f "$CARGO_MUTANTS_REPORT" ]; then
        AGE_DAYS=$(python3 -c "import os,time,sys;print(int((time.time()-os.path.getmtime(sys.argv[1]))//86400))" "$CARGO_MUTANTS_REPORT" 2>/dev/null)
        MTIME=$(python3 -c "import os,time,sys;print(time.strftime('%Y-%m-%dT%H:%MZ',time.gmtime(os.path.getmtime(sys.argv[1]))))" "$CARGO_MUTANTS_REPORT" 2>/dev/null)
        if [ -n "$AGE_DAYS" ] && [ "$AGE_DAYS" -gt 7 ]; then
            add_skipped "mutation" "cargo-mutants report stale (>7d, ${AGE_DAYS}d old at $CARGO_MUTANTS_REPORT); pass --include-mutation to refresh"
        else
            score=$(parse_cargo_mutants_score "$CARGO_MUTANTS_REPORT")
            if [ -n "$score" ]; then
                add_metric "cargo-mutants" "mutation-score" "$score" "$FLOW_MUT_MIN" "info" "cached: $CARGO_MUTANTS_REPORT (mtime $MTIME)"
            else
                add_skipped "mutation" "cargo-mutants cache present but no testable mutants in $CARGO_MUTANTS_REPORT"
            fi
        fi
    elif have cargo && cargo mutants --version >/dev/null 2>&1; then
        add_skipped "mutation" "cargo-mutants installed; pass --include-mutation to run (slow)"
    else
        add_skipped "mutation" "cargo-mutants not installed (cargo install cargo-mutants)"
    fi
elif ! have cargo || ! cargo mutants --version >/dev/null 2>&1; then
    add_skipped "mutation" "cargo-mutants not installed"
else
    rm -rf mutants.out 2>/dev/null
    cargo mutants --no-shuffle >/dev/null 2>&1 || true
    if [ -f "$CARGO_MUTANTS_REPORT" ]; then
        score=$(parse_cargo_mutants_score "$CARGO_MUTANTS_REPORT")
        if [ -n "$score" ] && awk "BEGIN {exit !($score < $FLOW_MUT_MIN)}"; then
            add_metric "cargo-mutants" "mutation-score" "$score" "$FLOW_MUT_MIN" "info" "-"
        elif [ -z "$score" ]; then
            add_skipped "mutation" "cargo-mutants ran but produced no testable mutants"
        fi
    else
        add_skipped "mutation" "cargo-mutants run produced no outcomes.json"
    fi
fi

printf '{"language":"rust","metrics":[%s],"skipped":[%s]}\n' "$METRICS_JSON" "$SKIPPED_JSON"
exit 0
