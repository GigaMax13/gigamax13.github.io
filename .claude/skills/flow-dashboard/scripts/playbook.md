# flow-dashboard playbook


# flow-dashboard

Read-only manager-level dashboard: current state, per-metric trend vs a base ref, worst-offending files. Populates the `baseline` key in `$DEV_DIR/flow/data.json` and appends a Trend section to `$DEV_DIR/flow/report.md`.

**Never modifies source.** Git ops are read-only or `git stash` (reversible).

## Usage

```
/flow-dashboard                 # compare HEAD vs origin/main (or main)
/flow-dashboard --base develop  # compare HEAD vs develop
```

## Workflow

### Step 0: Resolve dev directory

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh"
```
Capture as `DEV_DIR`.

### Step 1: Measure current (HEAD) state

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/flow-metrics/scripts/collect.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/flow-metrics/scripts/collect.sh" --dev-dir "$DEV_DIR"
```

HEAD is measured **fully** (no `--quick`) — coverage and mutation are part of the dashboard's headline result, so silently skipping them would hide regressions. The baseline pass below uses `--quick` because the dashboard cares about HEAD vs baseline deltas, not about historical absolute scores. Coverage runs the project's installed test runner (`./node_modules/.bin/vitest` or `./node_modules/.bin/jest`); if missing, the collector emits `skipped[].coverage` with an actionable reason instead of falling through silently.

### Step 2: Capture baseline in a temp dir

Determine base ref (in order): `--base <ref>` flag → `origin/main` → `main` → `master` → skip and set `BASE_REF=""`.

If a base ref exists, stash uncommitted changes, check out base, measure into a temp dir, return:

```bash
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if [ -n "$BASE_REF" ]; then
    git diff --quiet && STASH_OK=0 || { git stash push -u -m "flow-dashboard-stash" >/dev/null 2>&1 && STASH_OK=1; }
    CURRENT=$(git rev-parse --abbrev-ref HEAD)
    if git checkout --quiet "$BASE_REF" 2>/dev/null; then
        # Collect baseline into an isolated temp dev dir so it doesn't clobber HEAD data.
        mkdir -p "$TMPDIR/dev"
        bash "$_sh/skills/flow-metrics/scripts/collect.sh" --dev-dir "$TMPDIR/dev" --quick
        cp "$TMPDIR/dev/flow/data.json" "$TMPDIR/base.json"
        git checkout --quiet "$CURRENT"
    fi
    [ "$STASH_OK" = "1" ] && git stash pop >/dev/null 2>&1
fi
```

Abort cleanly on any failure; never leave the working tree broken. If baseline is skipped, dashboard shows current state only (no Trend section).

### Step 3: Merge baseline into `$DEV_DIR/flow/data.json`

```bash
if [ -f "$TMPDIR/base.json" ]; then
    python3 - "$DEV_DIR/flow/data.json" "$TMPDIR/base.json" "$BASE_REF" <<'PY'
import json, sys
head_path, base_path, base_ref = sys.argv[1], sys.argv[2], sys.argv[3]
with open(head_path) as f:
    head = json.load(f)
with open(base_path) as f:
    base = json.load(f)
head["baseline"] = {
    "ref": base_ref,
    "summary": base.get("summary", {}),
    "metrics": base.get("metrics", []),
    "generatedAt": base.get("generatedAt"),
}
with open(head_path, "w") as f:
    json.dump(head, f, indent=2, sort_keys=True)
PY
fi
```

### Step 4: Re-render `$DEV_DIR/flow/report.md`

Re-invoke the collector's renderer in `--render-only` mode — collectors do **not** re-run, so the full HEAD metrics from step 1 (coverage, mutation, etc.) survive. The renderer reads the merged `baseline` from `data.json` and writes the Trend section into `report.md`.

```bash
bash "$_sh/skills/flow-metrics/scripts/collect.sh" --dev-dir "$DEV_DIR" --render-only
```

### Step 5: Print headline and complete

Extract the Summary line and Trend table from `$DEV_DIR/flow/report.md` and echo them, then:

```
FLOW-DASHBOARD COMPLETE
```

## Exit Criteria

- [ ] `DEV_DIR` resolved
- [ ] HEAD metrics collected (`$DEV_DIR/flow/data.json`)
- [ ] Baseline captured into `mktemp -d` (not under `$DEV_DIR`) when a base ref exists; otherwise single-point mode
- [ ] `baseline` key populated in `$DEV_DIR/flow/data.json` when baseline is available
- [ ] Trend section rendered into `$DEV_DIR/flow/report.md`
- [ ] Working tree preserved (no leftover checkouts, stash restored)
- [ ] Printed `FLOW-DASHBOARD COMPLETE`
