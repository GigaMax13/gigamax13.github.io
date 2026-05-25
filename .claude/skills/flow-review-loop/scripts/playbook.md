
# flow-review-loop playbook

## Original heading: flow-review-loop

Iterates `/review-code --flow` → (if dirty) `/fix-review --flow` until **3 consecutive clean reviews**. Hands-off cleanup — no manual re-runs or model reselection between iterations.

**Runtime:** Runs inline on the **session model** (Opus recommended — this loop is designed for hands-off Opus cleanup). The `model: opus` frontmatter is advisory under read-and-follow dispatch; the harness cannot enforce it without creating a nested-subagent chain that Claude Code does not support (anthropics/claude-code#19077). Sub-calls to `/review-code --flow` and `/fix-review --flow` spawn as separate **Sonnet** subagents via the Agent tool so each sub-task runs on its pinned model. Do NOT invoke sub-skills via the Skill tool — that reintroduces the nested-Skill yielding bug (anthropics/claude-code#17351).

## Usage

```
/flow-review-loop                 # full repo, default thresholds
/flow-review-loop src/app         # scoped folder (passthrough)
/flow-review-loop --quick         # skip slow metrics (coverage, mutation)
/flow-review-loop src/app --quick # combined
```

Arguments pass through verbatim to every `/flow-review` and `/flow-fix` invocation.

## Rules

1. Invoke sub-agents via the **Agent tool** with `subagent_type: review-code` or `fix-review` (prompt must include `--flow`) — never Skill, never inline Read.
2. **AUTONOMOUS:** Never pause or ask the user between iterations.
3. Valid stopping points: 3 consecutive clean reviews (success), `MAX_ITER=10` (cap), or sub-agent failure.
4. A review is **clean** iff `$DEV_DIR/flow/data.json`'s `summary.fails == 0` after `/flow-review` completes. Warnings are advisory (most aren't auto-fixable — they need human refactoring decisions); they appear in the final summary but do NOT block convergence. `report.md` always exists; the JSON summary is the authoritative clean signal.
5. Any dirty review resets the consecutive-clean counter to 0.
6. **Loop state lives in `$DEV_DIR/flow/.loop-state` — a bash-sourceable file.** Do NOT track `CONSECUTIVE_CLEAN` or `ITER` as narrative variables. Every increment, reset, and gate check MUST go through the state file via Bash.
7. Do NOT modify `$DEV_DIR/flow/report.md` or `$DEV_DIR/flow/data.json` — only observe them.

## Constants

| Name | Value | Meaning |
|---|---|---|
| `TARGET` | 3 | Consecutive clean reviews to exit successfully |
| `MAX_ITER` | 10 | Safety cap on total iterations |

## Workflow

### Step 0: Resolve dev directory

**Bash**:
```bash
export AGENTS_PROJECT_ROOT="${AGENTS_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
_sh="${AGENTS_SKILLS_HOME:-"$AGENTS_PROJECT_ROOT/.claude"}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh"
```
Capture as `DEV_DIR` and export it. The `AGENTS_PROJECT_ROOT` pin overrides any stale `$CLAUDE_PROJECT_DIR` left over from a previous session, ensuring `DEV_DIR` lands in this project's tree.

### Step 1: Capture arguments

Capture the entire user-supplied arg string as `ARGS` (may be empty, a folder, `--quick`, or both). Pass unchanged to every sub-agent prompt.

### Step 2: Initialize state file

**Bash**:
```bash
mkdir -p "$DEV_DIR/flow"
cat > "$DEV_DIR/flow/.loop-state" <<'EOF'
CONSECUTIVE_CLEAN=0
ITER=0
EOF
cat "$DEV_DIR/flow/.loop-state"
```

Print: `flow-review-loop starting — target: 3 consecutive clean, max: 10 iterations`

### Step 3: Main loop iteration

Repeat until the Step 4 gate passes. The state file is the source of truth — never skip the Bash increment/reset.

**3a — Increment ITER:**
```bash
. "$DEV_DIR/flow/.loop-state"
ITER=$((ITER + 1))
cat > "$DEV_DIR/flow/.loop-state" <<EOF
CONSECUTIVE_CLEAN=$CONSECUTIVE_CLEAN
ITER=$ITER
EOF
echo "[iter $ITER] running /flow-review"
```

**3b — Run review-code --flow via Agent (Sonnet):**

Call the **Agent tool**:
- `subagent_type`: `review-code`
- `description`: `review-code --flow iter N` (N = current ITER)
- `prompt`: `--flow $ARGS` (prepend `--flow` to the args)

Wait for completion.

**3c — Classify result and update state** (reads `summary.fails` + `summary.warns` from the consolidated JSON):
```bash
. "$DEV_DIR/flow/.loop-state"
CLEAN_FLAG=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); s=d.get("summary",{}); print("1" if s.get("fails",0)==0 else "0")' "$DEV_DIR/flow/data.json" 2>/dev/null || echo 0)
if [ "$CLEAN_FLAG" = "1" ]; then
  CONSECUTIVE_CLEAN=$((CONSECUTIVE_CLEAN + 1))
  echo "[iter $ITER] clean ($CONSECUTIVE_CLEAN/3)"
  RESULT=CLEAN
else
  CONSECUTIVE_CLEAN=0
  echo "[iter $ITER] dirty — running /flow-fix (counter reset)"
  RESULT=DIRTY
fi
cat > "$DEV_DIR/flow/.loop-state" <<EOF
CONSECUTIVE_CLEAN=$CONSECUTIVE_CLEAN
ITER=$ITER
EOF
echo "RESULT=$RESULT"
```

**3d — If DIRTY, run fix-review --flow via Agent (Sonnet):**

Only when 3c output contains `RESULT=DIRTY`, call the **Agent tool**:
- `subagent_type`: `fix-review`
- `description`: `fix-review --flow iter N`
- `prompt`: `--flow $ARGS` (prepend `--flow` to the args)

Do NOT short-circuit on fix-review's internal clean state — the next Step 3b confirms. Skip on CLEAN.

**3e — Loop decision:**

```bash
. "$DEV_DIR/flow/.loop-state"
if [ "$CONSECUTIVE_CLEAN" -ge 3 ]; then
  echo "LOOP_DECISION=EXIT_SUCCESS"
elif [ "$ITER" -ge 10 ]; then
  echo "LOOP_DECISION=EXIT_CAP"
else
  echo "LOOP_DECISION=CONTINUE"
fi
```

- `CONTINUE` → back to Step 3a
- `EXIT_SUCCESS` or `EXIT_CAP` → Step 4

### Step 4: Pre-completion gate (MANDATORY)

Before printing any completion marker, run this. Non-zero exit means the contract is unmet — loop back to Step 3a.

```bash
. "$DEV_DIR/flow/.loop-state"
if [ "$CONSECUTIVE_CLEAN" -lt 3 ] && [ "$ITER" -lt 10 ]; then
  echo "GATE_FAILED: CONSECUTIVE_CLEAN=$CONSECUTIVE_CLEAN ITER=$ITER — loop must continue"
  exit 1
fi
echo "GATE_PASSED: CONSECUTIVE_CLEAN=$CONSECUTIVE_CLEAN ITER=$ITER"
```

On `GATE_FAILED`, return to Step 3a. Do NOT print a completion marker.

### Step 5: Final summary and marker

Only reachable after Step 4 printed `GATE_PASSED`.

- **IF `CONSECUTIVE_CLEAN >= 3`**:
  - Print: `flow-review-loop: clean after {ITER} iteration(s) — {CONSECUTIVE_CLEAN} consecutive clean reviews`
  - Print: `FLOW-REVIEW-LOOP COMPLETE`

- **ELSE** (hit `MAX_ITER`):
  - Print: `flow-review-loop: hit safety cap at iteration {ITER} — CONSECUTIVE_CLEAN={CONSECUTIVE_CLEAN}/3`
  - Print: `See $DEV_DIR/flow/report.md for remaining issues.`
  - Print: `FLOW-REVIEW-LOOP INCOMPLETE`

Substitute `{ITER}` and `{CONSECUTIVE_CLEAN}` from a final `. "$DEV_DIR/flow/.loop-state"` read.

### Step 6: Clean up state file

```bash
rm -f "$DEV_DIR/flow/.loop-state"
```

## Context Management

- **Safe to compact after:** Step 3d (before next 3a).
- **NEVER compact during:** an active `/flow-review` or `/flow-fix` subagent call.
- **Preserve across compaction:** `DEV_DIR`, `ARGS`. `CONSECUTIVE_CLEAN` and `ITER` live on disk — re-sourcing recovers them losslessly.

## Exit Criteria

- [ ] `DEV_DIR` resolved and `$DEV_DIR/flow/.loop-state` initialized
- [ ] At least one `/review-code --flow` subagent executed via Agent tool (not Skill)
- [ ] Step 4 gate printed `GATE_PASSED` (never `GATE_FAILED` as the last gate call)
- [ ] Summary line printed
- [ ] Printed `FLOW-REVIEW-LOOP COMPLETE` (success) or `FLOW-REVIEW-LOOP INCOMPLETE` (cap hit)
- [ ] `$DEV_DIR/flow/.loop-state` removed
