---
name: flow-metrics
description: Collect coverage, complexity, duplication, mutation.
model: haiku
---


# flow-metrics

Collects quality metrics across TypeScript, Python, Go, Rust. Called by `/flow-review`, `/flow-develop`, `/flow-fix`, `/flow-dashboard`; also invokable directly.

**No LLM reasoning** — shell-heavy runner. Work is delegated to per-language collectors under `scripts/`.

## Usage

```
/flow-metrics                     # full repo
/flow-metrics src/app             # scoped to a folder
/flow-metrics --quick             # skip slow metrics
/flow-metrics --include-mutation  # opt-in: Stryker/mutmut/etc, slow; auto-scaffolds config via scripts/scaffold-mutation.sh
```

## Output

Writes `$DEV_DIR/flow/data.json` (canonical structured artifact) and `$DEV_DIR/flow/report.md` (unified human view). Schema and retired paths: see `scripts/SCHEMA.md`.

## Workflow

### Step 0: Resolve dev directory
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh"
```
Capture as `DEV_DIR`.

### Step 1: Run collector
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/flow-metrics/scripts/collect.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/flow-metrics/scripts/collect.sh" --dev-dir "$DEV_DIR" $ARGS
```

Exit `0` = outputs present; non-zero = collector bug (print stderr, STOP). **Missing tools are NOT errors** — recorded as `SKIPPED`, exit still 0.

### Step 2: Confirm and report
```bash
test -f "$DEV_DIR/flow/data.json" && test -f "$DEV_DIR/flow/report.md" && echo OK || echo MISSING
```

`MISSING` → print `FLOW-METRICS INCOMPLETE` and STOP. `OK` → print one-line summary (first `Summary:` line of `report.md`), then `FLOW-METRICS COMPLETE`.

## Exit Criteria

- [ ] `DEV_DIR` resolved
- [ ] Collector script invoked
- [ ] `$DEV_DIR/flow/data.json` and `$DEV_DIR/flow/report.md` written
- [ ] One-line summary printed
- [ ] Printed `FLOW-METRICS COMPLETE`
