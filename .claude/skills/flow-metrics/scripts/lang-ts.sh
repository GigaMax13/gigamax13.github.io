#!/bin/bash
# lang-ts.sh — TypeScript/React metric collector.
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

cd "$TARGET" 2>/dev/null || { echo '{"language":"ts","status":"bad_target"}'; exit 0; }

have() { command -v "$1" >/dev/null 2>&1; }

# pm_exec — invoke a node tool from host project deps, fall back to npx.
# Order: ./node_modules/.bin → pnpm exec → yarn → bun x → npx -y <pkg>
# $1 = bin name, $2 = npx-spec (e.g. "jscpd@4"), rest = args
pm_exec() {
    local bin="$1"; local spec="$2"; shift 2
    if [ -x "./node_modules/.bin/$bin" ]; then
        "./node_modules/.bin/$bin" "$@"
    elif [ -f "pnpm-lock.yaml" ] && command -v pnpm >/dev/null 2>&1 && pnpm list "$bin" --depth 0 >/dev/null 2>&1; then
        pnpm exec "$bin" "$@"
    elif [ -f "yarn.lock" ] && command -v yarn >/dev/null 2>&1; then
        yarn --silent "$bin" "$@" 2>/dev/null || yarn "$bin" "$@"
    elif [ -f "bun.lockb" ] && command -v bun >/dev/null 2>&1; then
        bun x "$bin" "$@"
    elif command -v npx >/dev/null 2>&1; then
        npx -y "$spec" "$@"
    else
        return 127
    fi
}

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
    runner = cells[1].lower()
    if runner not in ("vitest", "jest"):
        continue
    cmd = cells[4]
    if cmd and cmd != "(unsupported runner)":
        print(cmd)
    break
PY
}

# Walk the repo and return space-separated source directories.
# Works for single-root ("src/"), pnpm/yarn/lerna monorepos ("apps/*/src",
# "packages/*/src"), and arbitrary workspace layouts (any package.json
# with a sibling src/app/lib/pages dir). Falls back to "." if nothing
# is found so downstream tools still have something to operate on.
discover_ts_sources() {
    local dirs=""
    local d parent child s pkg pdir

    for d in src app lib pages; do
        [ -d "$d" ] && dirs="$dirs $d"
    done

    for parent in apps packages services libs; do
        [ -d "$parent" ] || continue
        for child in "$parent"/*/; do
            [ -d "$child" ] || continue
            for s in src app lib pages; do
                [ -d "${child}${s}" ] && dirs="$dirs ${child%/}/${s}"
            done
        done
    done

    while IFS= read -r pkg; do
        pdir=$(dirname "$pkg")
        for s in src app lib pages; do
            [ -d "$pdir/$s" ] && dirs="$dirs $pdir/$s"
        done
    done < <(find . -maxdepth 4 -type f -name package.json \
        ! -path "*/node_modules/*" ! -path "*/dist/*" ! -path "*/build/*" \
        ! -path "*/.next/*" ! -path "*/.stryker-tmp/*" 2>/dev/null)

    if [ -z "$(echo "$dirs" | tr -d ' ')" ]; then
        echo "."
        return
    fi
    # Normalize (strip leading ./) and dedupe.
    echo "$dirs" \
        | tr ' ' '\n' \
        | sed 's|^\./||' \
        | awk 'NF && !seen[$0]++' \
        | tr '\n' ' ' \
        | sed 's/ $//'
}

METRICS_JSON=""
SKIPPED_JSON=""
SNAPSHOT_JSON=""

add_metric() {
    # args: tool metric value threshold severity location
    local entry
    entry=$(python3 -c "import json,sys; print(json.dumps({'tool':sys.argv[1],'metric':sys.argv[2],'value':sys.argv[3],'threshold':sys.argv[4],'severity':sys.argv[5],'location':sys.argv[6]}))" "$1" "$2" "$3" "$4" "$5" "$6")
    if [ -z "$METRICS_JSON" ]; then METRICS_JSON="$entry"; else METRICS_JSON="$METRICS_JSON,$entry"; fi
}

add_skipped() {
    local entry
    entry=$(python3 -c "import json,sys; print(json.dumps({'tool':sys.argv[1],'reason':sys.argv[2]}))" "$1" "$2")
    if [ -z "$SKIPPED_JSON" ]; then SKIPPED_JSON="$entry"; else SKIPPED_JSON="$SKIPPED_JSON,$entry"; fi
}

# Always-on dashboard rows. Independent of pass/fail — collect.sh renders
# these into a "## Snapshot" table so a clean run still has visible numbers.
# args: tool metric value threshold status (OK|WARN|FAIL|INFO)
add_snapshot() {
    local entry
    entry=$(python3 -c "import json,sys; print(json.dumps({'tool':sys.argv[1],'metric':sys.argv[2],'value':sys.argv[3],'threshold':sys.argv[4],'status':sys.argv[5]}))" "$1" "$2" "$3" "$4" "$5")
    if [ -z "$SNAPSHOT_JSON" ]; then SNAPSHOT_JSON="$entry"; else SNAPSHOT_JSON="$SNAPSHOT_JSON,$entry"; fi
}

# ---------- File sizes (no external tool needed) ----------
# Flag any .ts/.tsx file over the configured cap (default 399).
OVERSIZED_COUNT=0
TOTAL_COUNT=0
while IFS= read -r f; do
    lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
    [ -z "$lines" ] && continue
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if [ "$lines" -gt "$FLOW_FILE_LINES" ]; then
        OVERSIZED_COUNT=$((OVERSIZED_COUNT + 1))
        add_metric "wc" "file-lines" "$lines" "$FLOW_FILE_LINES" "fail" "$f"
    fi
done < <(find . -type f \( -name "*.ts" -o -name "*.tsx" \) \
    ! -path "*/node_modules/*" ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/.next/*" ! -path "*/.stryker-tmp/*" 2>/dev/null)
if [ "$TOTAL_COUNT" -gt 0 ]; then
    if [ "$OVERSIZED_COUNT" -gt 0 ]; then status=FAIL; else status=OK; fi
    add_snapshot "wc" "files-over-limit" "$OVERSIZED_COUNT/$TOTAL_COUNT" "≤ $FLOW_FILE_LINES lines" "$status"
fi

# ---------- Coverage (vitest/jest) ----------
# Invariant: every code path MUST leave either a coverage metric (fail on
# any tooling problem outside --quick) or an `add_skipped` entry (only for
# the --quick opt-in or an explicit FLOW_SKIP). Pass case emits nothing.
cov_fail() {
    add_metric "coverage" "line-%" "unmeasured" "$FLOW_COV_LINE" "fail" "$1"
}
COV_JSON=""
COV_HANDLED=0
TESTS_RC=""
TESTS_RUNNER=""
if flow_skip_contains coverage; then
    add_skipped "coverage" "skipped via flow.config.yaml"; COV_HANDLED=1
elif [ "$QUICK" = "1" ]; then
    add_skipped "coverage" "quick mode"; COV_HANDLED=1
elif [ -f "coverage/coverage-summary.json" ]; then
    # Pre-existing report wins — avoids re-running tests on every dashboard pass.
    COV_JSON="coverage/coverage-summary.json"
else
    MAP_CMD="$(read_coverage_cmd_from_test_map)"
    if [ -n "$MAP_CMD" ]; then
        ERR=$(eval "$MAP_CMD" 2>&1 >/dev/null); TESTS_RC=$?; TESTS_RUNNER="test-map"
        if [ -f "coverage/coverage-summary.json" ]; then
            COV_JSON="coverage/coverage-summary.json"
        else
            short=$(printf '%s' "$ERR" | tail -n1 | head -c 200)
            cov_fail "test-map cmd produced no coverage-summary.json: ${short:-no stderr}"
            COV_HANDLED=1
        fi
    elif [ ! -f "package.json" ]; then
        cov_fail "no package.json"; COV_HANDLED=1
    elif grep -q '"vitest"' package.json 2>/dev/null; then
        if [ ! -x "./node_modules/.bin/vitest" ]; then
            cov_fail "vitest in package.json but ./node_modules/.bin/vitest missing — run install (pnpm/npm/yarn) first"
            COV_HANDLED=1
        elif [ ! -d "node_modules/@vitest/coverage-v8" ] && [ ! -d "node_modules/@vitest/coverage-istanbul" ]; then
            cov_fail "@vitest/coverage-v8 not installed (try: pnpm add -D @vitest/coverage-v8)"
            COV_HANDLED=1
        else
            ERR=$(./node_modules/.bin/vitest run --coverage --coverage.reporter=json-summary 2>&1 >/dev/null); TESTS_RC=$?; TESTS_RUNNER="vitest"
            if [ -f "coverage/coverage-summary.json" ]; then
                COV_JSON="coverage/coverage-summary.json"
            else
                short=$(printf '%s' "$ERR" | tail -n1 | head -c 200)
                cov_fail "vitest exited without producing coverage-summary.json: ${short:-no stderr}"
                COV_HANDLED=1
            fi
        fi
    elif grep -q '"jest"' package.json 2>/dev/null; then
        if [ ! -x "./node_modules/.bin/jest" ]; then
            cov_fail "jest in package.json but ./node_modules/.bin/jest missing — run install first"
            COV_HANDLED=1
        else
            ERR=$(./node_modules/.bin/jest --coverage --coverageReporters=json-summary 2>&1 >/dev/null); TESTS_RC=$?; TESTS_RUNNER="jest"
            if [ -f "coverage/coverage-summary.json" ]; then
                COV_JSON="coverage/coverage-summary.json"
            else
                short=$(printf '%s' "$ERR" | tail -n1 | head -c 200)
                cov_fail "jest exited without producing coverage-summary.json: ${short:-no stderr}"
                COV_HANDLED=1
            fi
        fi
    else
        cov_fail "no vitest or jest in package.json"; COV_HANDLED=1
    fi
fi
if [ -n "$COV_JSON" ] && [ -f "$COV_JSON" ]; then
    read -r line_pct branch_pct < <(python3 -c "
import json
d = json.load(open('$COV_JSON'))
t = d.get('total', {})
print(t.get('lines', {}).get('pct', 0), t.get('branches', {}).get('pct', 0))
")
    awk_less() { awk "BEGIN {exit !($1 < $2)}"; }
    line_fail=0; br_fail=0
    if awk_less "$line_pct" "$FLOW_COV_LINE"; then
        add_metric "coverage" "line-%" "$line_pct" "$FLOW_COV_LINE" "fail" "-"; line_fail=1
        line_status=FAIL
    else
        line_status=OK
    fi
    if awk_less "$branch_pct" "$FLOW_COV_BRANCH"; then
        add_metric "coverage" "branch-%" "$branch_pct" "$FLOW_COV_BRANCH" "fail" "-"; br_fail=1
        br_status=FAIL
    else
        br_status=OK
    fi
    add_snapshot "coverage" "line-%" "$line_pct" "≥ $FLOW_COV_LINE" "$line_status"
    add_snapshot "coverage" "branch-%" "$branch_pct" "≥ $FLOW_COV_BRANCH" "$br_status"
elif [ "$COV_HANDLED" = "0" ]; then
    # Defensive: any unforeseen branch lands here so coverage is never silent.
    cov_fail "collector reached unhandled branch (please report)"
fi

# ---------- Tests (gate: any non-zero exit from the runner = fail) ----------
# The coverage block above runs the test suite. If the runner exited non-zero
# the suite has failures or errors — emit a fail metric so flow doesn't pass.
if [ -n "$TESTS_RC" ] && [ "$TESTS_RC" != "0" ]; then
    short=$(printf '%s' "${ERR:-}" | tail -n1 | head -c 200)
    add_metric "${TESTS_RUNNER:-tests}" "tests" "failed" "0" "fail" "exit ${TESTS_RC}: ${short:-no stderr}"
fi

# ---------- Complexity (ESLint: cyclomatic + sonarjs cognitive if configured) ----------
if flow_skip_contains complexity; then
    add_skipped "complexity" "skipped via flow.config.yaml"
elif ! have npx; then
    add_skipped "complexity" "npx not installed"
else
    # Run eslint with complexity warning; parse for functions > threshold.
    # Only honor it if an eslint config exists.
    if ls .eslintrc* eslint.config.* 2>/dev/null | head -1 | grep -q .; then
        # Use --no-eslintrc fallback not possible if config is project; just run and filter.
        # shellcheck disable=SC2046
        # We override `complexity` to ensure cyclomatic always runs. Other configured
        # rules (incl. sonarjs/cognitive-complexity) still fire and are parsed below.
        OUT=$(npx --no-install eslint --rule "{\"complexity\":[\"warn\",$FLOW_CYCLO_WARN]}" --format json $(discover_ts_sources) 2>/dev/null || echo "[]")
        echo "$OUT" | python3 -c "
import json, sys, re
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for file_report in data:
    for msg in file_report.get('messages', []):
        rule = msg.get('ruleId') or ''
        text = msg.get('message', '')
        if rule == 'complexity':
            m = re.search(r'complexity of (\d+)', text)
            if m: print(f\"cyclomatic|{file_report['filePath']}|{msg.get('line',0)}|{m.group(1)}\")
        elif rule == 'sonarjs/cognitive-complexity':
            m = re.search(r'Cognitive Complexity from (\d+)', text)
            if m: print(f\"cognitive|{file_report['filePath']}|{msg.get('line',0)}|{m.group(1)}\")
" > /tmp/flow-complexity-ts.$$ 2>/dev/null
        while IFS='|' read -r kind fpath fline n; do
            [ -z "$kind" ] && continue
            [ -z "$n" ] && continue
            if [ "$kind" = "cyclomatic" ]; then
                # Severity tiers: > FAIL -> fail, > WARN -> warn, else info.
                if [ "$n" -gt "$FLOW_CYCLO_FAIL" ]; then sev="fail"
                elif [ "$n" -gt "$FLOW_CYCLO_WARN" ]; then sev="warn"
                else sev="info"
                fi
                add_metric "eslint" "cyclomatic" "$n" "$FLOW_CYCLO_WARN" "$sev" "${fpath}:${fline}"
            elif [ "$kind" = "cognitive" ]; then
                if [ "$n" -gt "$FLOW_COGNI_WARN" ]; then sev="warn"
                else sev="info"
                fi
                add_metric "sonarjs" "cognitive" "$n" "$FLOW_COGNI_WARN" "$sev" "${fpath}:${fline}"
            fi
        done < /tmp/flow-complexity-ts.$$
        rm -f /tmp/flow-complexity-ts.$$
    else
        add_skipped "complexity" "no eslint config"
    fi
fi

# ---------- Duplication (jscpd) ----------
# Prefers host project's local jscpd (devDep) via pm_exec; falls back to
# `npx -y jscpd@4` so the metric still works without a project install.
if flow_skip_contains duplication; then
    add_skipped "duplication" "skipped via flow.config.yaml"
elif ! have npx && [ ! -x "./node_modules/.bin/jscpd" ]; then
    add_skipped "duplication" "no local jscpd and npx not installed"
else
    OUT=$(pm_exec jscpd "jscpd@4" --silent --reporters json \
        --ignore "**/node_modules/**,**/dist/**,**/build/**,**/.next/**,**/coverage/**,**/.venv/**,**/.stryker-tmp/**" \
        --output "/tmp/flow-jscpd-$$" . 2>/dev/null || true)
    if [ -f "/tmp/flow-jscpd-$$/jscpd-report.json" ]; then
        pct=$(python3 -c "
import json
d = json.load(open('/tmp/flow-jscpd-$$/jscpd-report.json'))
print(d.get('statistics', {}).get('total', {}).get('percentage', 0))
")
        if awk "BEGIN {exit !($pct > $FLOW_DUP_TOKENS)}"; then
            add_metric "jscpd" "duplication-%" "$pct" "$FLOW_DUP_TOKENS" "warn" "-"
            dup_status=WARN
        else
            dup_status=OK
        fi
        add_snapshot "jscpd" "duplication-%" "$pct" "≤ $FLOW_DUP_TOKENS" "$dup_status"
        rm -rf "/tmp/flow-jscpd-$$"
    else
        add_skipped "jscpd" "jscpd fetch failed (offline?) or no report produced"
    fi
fi

# ---------- Dependency cycles (madge) ----------
# Runs against auto-discovered source dirs so monorepos without a root
# ./src still get analysed. Prefers host project's local madge (devDep)
# via pm_exec; falls back to `npx -y madge@8`.
if flow_skip_contains dependencies; then
    add_skipped "dependencies" "skipped via flow.config.yaml"
elif ! have npx && [ ! -x "./node_modules/.bin/madge" ]; then
    add_skipped "dependencies" "no local madge and npx not installed"
else
    SRC_DIRS="$(discover_ts_sources)"
    # shellcheck disable=SC2086
    CYCLES=$(pm_exec madge "madge@8" --json --circular $SRC_DIRS 2>/dev/null || echo "[]")
    count=$(echo "$CYCLES" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(len(d) if isinstance(d, list) else 0)
except Exception:
    print(0)
")
    if [ "$count" -gt "$FLOW_DEP_CYCLES" ]; then
        loc="$SRC_DIRS"
        [ ${#loc} -gt 60 ] && loc="${loc:0:57}..."
        add_metric "madge" "dep-cycles" "$count" "$FLOW_DEP_CYCLES" "warn" "$loc"
        cyc_status=WARN
    else
        cyc_status=OK
    fi
    add_snapshot "madge" "dep-cycles" "$count" "= $FLOW_DEP_CYCLES" "$cyc_status"
fi

# ---------- Mutation (stryker) ----------
# Off by default (slow). FLOW_RUN_MUTATION=1 (set by collect.sh
# --include-mutation) opts in: scaffold a default config if missing, run
# Stryker, parse mutationScore, gate against $FLOW_MUT_MIN.
# When the flag is off but a recent reports/mutation/mutation.json already
# exists, the cache is reused (mirrors how coverage reuses
# coverage/coverage-summary.json) so the metric still surfaces in the report.

# Parse a Stryker JSON report and print "<score>" or empty on failure.
# Handles both legacy schemas (precomputed mutationScore) and v1.0+ raw
# mutants. $1 = report path.
parse_stryker_score() {
    python3 - "$1" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
m = d.get('systemUnderTestMetrics') or {}
m = m.get('metrics') or d.get('metrics') or {}
score = m.get('mutationScore', d.get('mutationScore'))
if score is None and isinstance(d.get('files'), dict):
    killed = timeout = survived = nocov = 0
    for f in d['files'].values():
        for mut in f.get('mutants', []):
            s = mut.get('status', '')
            if s == 'Killed': killed += 1
            elif s == 'Timeout': timeout += 1
            elif s == 'Survived': survived += 1
            elif s == 'NoCoverage': nocov += 1
    detected = killed + timeout
    valid = detected + survived + nocov
    if valid > 0:
        score = round(detected / valid * 100, 2)
print(score if score is not None else '')
PY
}

find_stryker_report() {
    for cand in reports/mutation/mutation.json reports/mutation/mutation-report.json; do
        if [ -f "$cand" ]; then
            echo "$cand"
            return
        fi
    done
}

if flow_skip_contains mutation; then
    add_skipped "mutation" "skipped via flow.config.yaml"
elif [ "${FLOW_RUN_MUTATION:-0}" != "1" ]; then
    CACHED_REPORT="$(find_stryker_report)"
    if [ -n "$CACHED_REPORT" ]; then
        # Detect staleness without depending on stat's --format flag (BSD vs GNU).
        # python3 .stat already on the dependency line for everything else here.
        AGE_DAYS=$(python3 -c "import os,time,sys;print(int((time.time()-os.path.getmtime(sys.argv[1]))//86400))" "$CACHED_REPORT" 2>/dev/null)
        MTIME=$(python3 -c "import os,time,sys;print(time.strftime('%Y-%m-%dT%H:%MZ',time.gmtime(os.path.getmtime(sys.argv[1]))))" "$CACHED_REPORT" 2>/dev/null)
        if [ -n "$AGE_DAYS" ] && [ "$AGE_DAYS" -gt 7 ]; then
            add_skipped "mutation" "stryker report stale (>7d, ${AGE_DAYS}d old at $CACHED_REPORT); pass --include-mutation to refresh"
        else
            score=$(parse_stryker_score "$CACHED_REPORT")
            if [ -n "$score" ]; then
                if awk "BEGIN {exit !($score < $FLOW_MUT_MIN)}"; then mut_status=INFO; else mut_status=OK; fi
                add_snapshot "stryker" "mutation-score" "$score" "≥ $FLOW_MUT_MIN" "$mut_status"
            else
                add_skipped "mutation" "stryker cache present but no parseable mutationScore at $CACHED_REPORT"
            fi
        fi
    elif ls stryker.config.* .stryker.conf.* stryker.conf.* 2>/dev/null | head -1 | grep -q .; then
        add_skipped "mutation" "stryker configured; pass --include-mutation to run (slow)"
    else
        add_skipped "mutation" "no stryker config; run scaffold-mutation.sh + --include-mutation"
    fi
else
    PM="npm"
    if [ -f "pnpm-lock.yaml" ] || [ -f "pnpm-workspace.yaml" ]; then
        PM="pnpm"
    elif [ -f "yarn.lock" ]; then
        PM="yarn"
    fi
    if [ ! -x "./node_modules/.bin/stryker" ]; then
        add_skipped "mutation" "stryker not installed; run '$PM add -D @stryker-mutator/core' (and the matching test-runner plugin)"
    else
        if ! ls stryker.config.* .stryker.conf.* stryker.conf.* 2>/dev/null | head -1 | grep -q .; then
            bash "$SCRIPT_DIR/scaffold-mutation.sh" --target . --lang ts >/dev/null 2>&1 || true
        fi
        rm -rf reports/mutation 2>/dev/null
        # Capture stderr+stdout to a log so silent failures stay diagnosable.
        STRYKER_LOG="${DEV_DIR:-.}/stryker.log"
        mkdir -p "$(dirname "$STRYKER_LOG")" 2>/dev/null
        case "$PM" in
            pnpm) pnpm exec stryker run --reporters json >"$STRYKER_LOG" 2>&1 || true ;;
            yarn) yarn stryker run --reporters json >"$STRYKER_LOG" 2>&1 || true ;;
            *)    ./node_modules/.bin/stryker run --reporters json >"$STRYKER_LOG" 2>&1 || true ;;
        esac
        REPORT="$(find_stryker_report)"
        if [ -n "$REPORT" ]; then
            score=$(parse_stryker_score "$REPORT")
            if [ -n "$score" ]; then
                if awk "BEGIN {exit !($score < $FLOW_MUT_MIN)}"; then mut_status=INFO; else mut_status=OK; fi
                add_snapshot "stryker" "mutation-score" "$score" "≥ $FLOW_MUT_MIN" "$mut_status"
            else
                add_skipped "mutation" "stryker ran but mutationScore missing from report"
            fi
        else
            add_skipped "mutation" "stryker run produced no JSON report (see $STRYKER_LOG)"
        fi
    fi
fi

# ---------- Emit JSON ----------
printf '{"language":"ts","metrics":[%s],"skipped":[%s],"snapshot":[%s]}\n' "$METRICS_JSON" "$SKIPPED_JSON" "$SNAPSHOT_JSON"
exit 0
