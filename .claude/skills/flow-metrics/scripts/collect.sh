#!/bin/bash
# flow-metrics collector — detects languages, dispatches per-language scripts,
# merges results into $DEV_DIR/flow/data.json and $DEV_DIR/flow/report.md.
#
# Design goals:
#   - No hard failures on missing tools. Emit SKIPPED entries instead.
#   - Zero LLM involvement. All work is shell + standard CLIs.
#   - Idempotent. Safe to re-run.
#   - Output lives under $DEV_DIR/flow/ (a single consolidated folder), not
#     at the $DEV_DIR root. $DEV_DIR itself is resolved by the caller via
#     resolve-dev.sh — do not hardcode ./.dev/ anywhere.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Bootstrap skill-local venv (radon/pydeps/pytest-cov) so Python metrics
# don't depend on host-side tooling. Non-fatal: offline hosts just skip
# the tools that would have used the venv.
if [ -f "$SCRIPT_DIR/setup.sh" ]; then
    bash "$SCRIPT_DIR/setup.sh" >/dev/null 2>&1 || true
fi

DEV_DIR=""
SCOPE=""
QUICK=0
RENDER_ONLY=0
INCLUDE_MUTATION=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dev-dir)           DEV_DIR="$2"; shift 2 ;;
        --scope)             SCOPE="$2"; shift 2 ;;
        --quick)             QUICK=1; shift ;;
        --render-only)       RENDER_ONLY=1; shift ;;
        --include-mutation)  INCLUDE_MUTATION=1; shift ;;
        --help|-h)
            echo "Usage: collect.sh --dev-dir <path> [--scope <path>] [--quick] [--render-only] [--include-mutation]"
            exit 0
            ;;
        *)
            # Positional arg treated as scope for convenience.
            if [ -z "$SCOPE" ] && [ -d "$1" ]; then
                SCOPE="$1"; shift
            else
                echo "Unknown argument: $1" >&2; exit 2
            fi
            ;;
    esac
done

if [ -z "$DEV_DIR" ]; then
    echo "collect.sh: --dev-dir is required" >&2
    exit 2
fi

mkdir -p "$DEV_DIR/flow"

# Source the per-project threshold loader so the writer block (and the
# no-language / --render-only early-exits) can render the *active*
# thresholds from $DEV_DIR/flow.config.yaml. Per-language collectors
# re-source this themselves; sourcing here is idempotent.
if [ -f "$SCRIPT_DIR/load-config.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/load-config.sh"
    flow_load_config "$DEV_DIR"
fi

# Self-documenting glossary appended to every report so a reader can
# interpret the numbers without leaving the file. Threshold cells read
# the resolved $FLOW_* env vars so per-project overrides surface here.
_emit_metrics_reference() {
    local out="$1"
    cat >> "$out" <<EOF

## Metrics reference

What flow-metrics checks, the active thresholds, and how to read the numbers.

| Metric | What it tests | Threshold | Severity |
|--------|---------------|-----------|----------|
| Line coverage | % of executable lines hit by tests | ≥ ${FLOW_COV_LINE:-80}% | fail |
| Branch coverage | % of conditional branches hit by tests | ≥ ${FLOW_COV_BRANCH:-60}% | fail |
| Cyclomatic complexity | decision paths per function | ≤ ${FLOW_CYCLO_WARN:-10} warn / ≤ ${FLOW_CYCLO_FAIL:-15} fail | warn / fail |
| Cognitive complexity | reading-difficulty score per function | ≤ ${FLOW_COGNI_WARN:-15} | warn |
| File size | source lines per file | ≤ ${FLOW_FILE_LINES:-399} | fail |
| Duplication | % duplicated tokens across files | ≤ ${FLOW_DUP_TOKENS:-5}% | warn |
| Dependency cycles | circular import chains | ${FLOW_DEP_CYCLES:-0} allowed | warn |
| Mutation score | % injected mutations caught (opt-in via \`--include-mutation\`) | ≥ ${FLOW_MUT_MIN:-60}% | info |

**Severity:** \`fail\` marks the run FAILED · \`warn\` counts in aggregate, run still completes · \`info\` reported only.

**Tools per language:**
- ts → vitest/jest, ESLint, jscpd, madge, stryker
- py → pytest-cov, radon, pylint, pydeps, mutmut
- go → \`go test -cover\`, gocyclo, dupl, \`go mod graph\`, go-mutesting
- rust → cargo tarpaulin, clippy, cargo modules, cargo-mutants

Missing tool → \`SKIPPED\` row, never a hard fail. Coverage outside \`--quick\` is the one exception — counts as fail since unmeasured ≠ 0%. Override per project via \`\$DEV_DIR/flow.config.yaml\` (see \`_rules/flow.md\`).
EOF
}

# Mutation runs are slow (Stryker / mutmut / cargo-mutants / go-mutesting).
# Default off so flow-review-loop iterations stay fast; opt-in for pre-merge
# / nightly via --include-mutation. Exported so per-language collectors see it.
export FLOW_RUN_MUTATION="$INCLUDE_MUTATION"

JSON_OUT="$DEV_DIR/flow/data.json"
MD_OUT="$DEV_DIR/flow/report.md"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

REPO_ROOT="$(pwd)"
[ -n "$SCOPE" ] && TARGET="$SCOPE" || TARGET="$REPO_ROOT"

if [ "$RENDER_ONLY" = "1" ]; then
    if [ ! -f "$JSON_OUT" ]; then
        echo "collect.sh: --render-only requires existing $JSON_OUT" >&2
        exit 2
    fi
    # Skip detection, collection, and merge — jump straight to renderer below.
else

# ---------- Language detection ----------
LANGS=()
[ -f "$TARGET/package.json" ] || [ -f "$REPO_ROOT/package.json" ] && LANGS+=("ts")
if [ -f "$TARGET/pyproject.toml" ] || [ -f "$REPO_ROOT/pyproject.toml" ] \
   || [ -f "$TARGET/requirements.txt" ] || [ -f "$REPO_ROOT/requirements.txt" ]; then
    LANGS+=("py")
fi
[ -f "$TARGET/go.mod" ] || [ -f "$REPO_ROOT/go.mod" ] && LANGS+=("go")
[ -f "$TARGET/Cargo.toml" ] || [ -f "$REPO_ROOT/Cargo.toml" ] && LANGS+=("rust")

if [ ${#LANGS[@]} -eq 0 ]; then
    # Nothing to measure. Write empty-ish outputs and exit 0.
    python3 - "$JSON_OUT" <<'PY'
import datetime, json, sys
out = {
    "languages": [],
    "metrics": [],
    "skipped": [],
    "snapshot": [],
    "baseline": None,
    "summary": {"fails": 0, "warns": 0, "infos": 0, "severity": "PASS"},
    "generatedAt": datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z",
    "notes": "no recognised language sentinel files",
}
with open(sys.argv[1], "w") as f:
    json.dump(out, f, indent=2, sort_keys=True)
PY
    {
        echo "# Flow report"
        echo ""
        echo "Summary: PASS — no recognised language sentinels (package.json, pyproject.toml, go.mod, Cargo.toml)."
        echo ""
        echo "Nothing to measure."
    } > "$MD_OUT"
    _emit_metrics_reference "$MD_OUT"
    exit 0
fi

# ---------- Run per-language collectors ----------
PER_LANG_JSON=()
for lang in "${LANGS[@]}"; do
    script="$SCRIPT_DIR/lang-${lang}.sh"
    out="$TMP_DIR/${lang}.json"
    if [ -x "$script" ] || [ -f "$script" ]; then
        bash "$script" --target "$TARGET" --dev-dir "$DEV_DIR" --quick "$QUICK" > "$out" 2> "$TMP_DIR/${lang}.err" || {
            # Script crashed. Record as an error entry but continue.
            printf '{"language":"%s","status":"collector_error","message":%s}' \
                "$lang" "$(printf '%s' "$(cat "$TMP_DIR/${lang}.err" 2>/dev/null | head -c 500)" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" > "$out"
        }
    else
        echo "{\"language\":\"$lang\",\"status\":\"missing_collector\"}" > "$out"
    fi
    PER_LANG_JSON+=("$out")
done

# ---------- Merge into single JSON ----------
# Preserves the "baseline" key from prior runs (written by flow-dashboard) so
# successive flow-metrics invocations don't erase the dashboard snapshot.
python3 - "$JSON_OUT" "${PER_LANG_JSON[@]}" <<'PY'
import datetime, json, os, sys
out_path = sys.argv[1]
paths = sys.argv[2:]
prior_baseline = None
if os.path.exists(out_path):
    try:
        with open(out_path) as f:
            prior = json.load(f)
        prior_baseline = prior.get("baseline")
    except Exception:
        prior_baseline = None
merged = {
    "languages": [],
    "metrics": [],
    "skipped": [],
    "snapshot": [],
    "baseline": prior_baseline,
    "generatedAt": datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z",
}
for p in paths:
    try:
        with open(p) as f:
            data = json.load(f)
    except Exception as e:
        merged["metrics"].append({"source": p, "status": "parse_error", "error": str(e)})
        continue
    lang = data.get("language", "unknown")
    merged["languages"].append(lang)
    for entry in data.get("metrics", []):
        entry.setdefault("language", lang)
        merged["metrics"].append(entry)
    for skip in data.get("skipped", []):
        skip.setdefault("language", lang)
        merged["skipped"].append(skip)
    for snap in data.get("snapshot", []):
        snap.setdefault("language", lang)
        merged["snapshot"].append(snap)
    if data.get("status") and data.get("status") not in ("ok",):
        merged["metrics"].append({
            "language": lang,
            "tool": "collector",
            "status": data.get("status"),
            "message": data.get("message", ""),
        })
fails = sum(1 for m in merged["metrics"] if m.get("severity") == "fail")
warns = sum(1 for m in merged["metrics"] if m.get("severity") == "warn")
infos = sum(1 for m in merged["metrics"] if m.get("severity") == "info")
merged["summary"] = {
    "fails": fails,
    "warns": warns,
    "infos": infos,
    "severity": "FAIL" if fails else "PASS",
}
with open(out_path, "w") as f:
    json.dump(merged, f, indent=2, sort_keys=True)
PY

fi  # end of RENDER_ONLY skip-block

# ---------- Write markdown report ----------
python3 - "$JSON_OUT" "$MD_OUT" <<'PY'
import json, sys
json_path, md_path = sys.argv[1], sys.argv[2]
with open(json_path) as f:
    data = json.load(f)

langs = sorted(set(data.get("languages", [])))
metrics = data.get("metrics", [])
skipped = data.get("skipped", [])
snapshot = data.get("snapshot", [])
summary = data.get("summary", {})
baseline = data.get("baseline")

fails = [m for m in metrics if m.get("severity") == "fail"]
warns = [m for m in metrics if m.get("severity") == "warn"]
infos = [m for m in metrics if m.get("severity") == "info"]

lines = []
lines.append("# Flow report")
lines.append("")
lines.append(
    f"Summary: {summary.get('severity', 'PASS')} — "
    f"{summary.get('fails', 0)} fail / {summary.get('warns', 0)} warn / "
    f"{summary.get('infos', 0)} info across {', '.join(langs) or 'no languages'}."
)
lines.append("")
lines.append(f"*Generated: {data.get('generatedAt', '')}*")
lines.append("")

if snapshot:
    lines.append("## Snapshot")
    lines.append("")
    lines.append("Current values for every measured metric (independent of pass/fail).")
    lines.append("")
    lines.append("| Lang | Tool | Metric | Value | Threshold | Status |")
    lines.append("|------|------|--------|-------|-----------|--------|")
    for s in snapshot:
        lines.append(
            f"| {s.get('language','-')} | {s.get('tool','-')} | {s.get('metric','-')} "
            f"| {s.get('value','-')} | {s.get('threshold','-')} | {s.get('status','-')} |"
        )
    lines.append("")

def section(title, items):
    if not items:
        return
    lines.append(f"## {title}")
    lines.append("")
    lines.append("| Lang | Tool | Metric | Value | Threshold | Location |")
    lines.append("|------|------|--------|-------|-----------|----------|")
    for m in items:
        lines.append(
            f"| {m.get('language','-')} | {m.get('tool','-')} | {m.get('metric','-')} "
            f"| {m.get('value','-')} | {m.get('threshold','-')} | {m.get('location','-')} |"
        )
    lines.append("")

section("Fails", fails)
section("Warnings", warns)
section("Info", infos)

if skipped:
    lines.append("## Skipped tools")
    lines.append("")
    for s in skipped:
        lines.append(
            f"- `{s.get('tool','?')}` ({s.get('language','?')}): "
            f"{s.get('reason','not installed')}"
        )
    lines.append("")

if fails or warns:
    lines.append("## How to fix")
    lines.append("")
    lines.append("- **Coverage below threshold** → add mocked tests for uncovered files.")
    lines.append("- **High complexity** → split the function or extract helpers; target ≤ 10 cyclomatic.")
    lines.append("- **Large file** → split by cohesion; target ≤ 399 lines.")
    lines.append("- **Dependency cycles** → break the cycle by inverting imports or moving shared types to a leaf.")
    lines.append("- **Duplication** → extract shared logic; target ≤ 5% duplicated tokens.")
    lines.append("")
    lines.append("Run `/fix-review --flow` to let the agent iterate on these metrics automatically.")
    lines.append("")

if baseline:
    b_summary = baseline.get("summary", {})
    lines.append("## Trend vs base")
    lines.append("")
    lines.append(f"*Base ref: {baseline.get('ref', 'unknown')}*")
    lines.append("")
    lines.append("| Bucket | HEAD | Base | Δ |")
    lines.append("|--------|------|------|---|")
    for key in ("fails", "warns", "infos"):
        head_v = summary.get(key, 0)
        base_v = b_summary.get(key, 0)
        delta = head_v - base_v
        sign = "+" if delta > 0 else ""
        lines.append(f"| {key} | {head_v} | {base_v} | {sign}{delta} |")
    lines.append("")

with open(md_path, "w") as f:
    f.write("\n".join(lines))
PY

_emit_metrics_reference "$MD_OUT"

exit 0
