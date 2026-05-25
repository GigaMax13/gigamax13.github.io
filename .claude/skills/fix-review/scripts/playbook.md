# fix-review playbook

**Runtime:** Sub-skill delegation uses the **Task tool** (`subagent_type: ...`), NEVER the Skill tool — `Skill()` yields to user after completion (anthropics/claude-code#17351), breaking autonomous workflows. `validate`, `flow-metrics`, and `verify-rules` run as **inline Bash** (subagents can't spawn subagents, #19077; these do no LLM reasoning).

## Mode

Parse input:

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/_shared/parse-mode.sh" ] || _sh="$HOME/.claude"
eval "$(bash "$_sh/skills/_shared/parse-mode.sh" "$INPUT")"
```

## Tool Mapping

| Action | Tool |
|--------|------|
| Read a file | Read |
| Run a shell command | Bash |
| Write content to a file | Write |
| Delete a file | Bash: `rm -f <path>` |
| Delegate to a subagent | **Task** (`subagent_type: <name>`) — NEVER Skill |

## Completion Rule

Execute all steps for the resolved mode. **NOT done** until `FIX-REVIEW COMPLETE` is printed.

## Step 0: Resolve dev directory

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh"
```
Capture output as `DEV_DIR`.

## MODE=flow — Metric-targeted fix loop (early exit)

### F1: Ensure fresh metrics

Reuse `$DEV_DIR/flow/data.json` if it was written within the last 5 minutes (typically by `review-code --flow` immediately upstream in the run-task pipeline). Otherwise re-collect.

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/flow-metrics/scripts/collect.sh" ] || _sh="$HOME/.claude"
DATA="$DEV_DIR/flow/data.json"
MTIME=$(stat -f %m "$DATA" 2>/dev/null || stat -c %Y "$DATA" 2>/dev/null || echo 0)
AGE=$(( $(date +%s) - MTIME ))
if [ -f "$DATA" ] && [ "$AGE" -lt 300 ]; then
    echo "F1: reusing fresh data.json (age ${AGE}s, threshold 300s)"
else
    bash "$_sh/skills/flow-metrics/scripts/collect.sh" --dev-dir "$DEV_DIR" $SCOPE
fi
```

**Read**: `$DEV_DIR/flow/data.json`.

### F2: Check for work

If `summary.fails == 0 && summary.warns == 0`:
- Print: `[1/1] nothing to fix — no failing or warning metrics`
- Print: `FIX-REVIEW COMPLETE`
- STOP.

Otherwise print: `[1/N] {K_fail} failing + {K_warn} warning metrics — starting fix loop`

### F3: Fix loop (max 3 rounds)

For each round (1..3):

1. **Read** freshest `$DEV_DIR/flow/data.json`.
2. **Group fails AND warns by kind**:
   - `coverage` / `line-%` (low overall coverage) — identify worst-covered non-trivial source file (via language coverage JSON: `coverage/coverage-summary.json`, `coverage.json`, tarpaulin output). Add mocked tests until line coverage crosses the threshold.
   - `cyclomatic` / `cognitive` — split flagged functions into smaller helpers or extract early-return guard clauses.
   - `file-lines` — split the file by cohesion into a new module.
   - `dep-cycles` — break the cycle by inverting an import or moving a shared type to a leaf module.
   - `duplication-*` — extract shared logic into a helper.
3. **Apply fixes** via Edit / Write. Keep edits tight — not a refactor session.
4. **Re-run** `flow-metrics` via direct Bash (same command as F1).
5. **Re-read** `$DEV_DIR/flow/data.json`. Inspect `summary.fails` and `summary.warns`.
   - `summary.fails == 0 AND summary.warns == 0` → break; go to F4.
   - Round 3 → break anyway; go to F4 with remaining issues noted.
   - Else → continue.

After each round print: `[round {R}/3] fails: {F_before} -> {F_after}, warns: {W_before} -> {W_after}`

### F4: Final state

**Read** `$DEV_DIR/flow/data.json` one last time.

- **`summary.fails == 0 && summary.warns == 0`** → print `All metrics clean. See $DEV_DIR/flow/report.md.`
- **Otherwise** → print `Remaining: {N_fail} fail / {N_warn} warn. See $DEV_DIR/flow/report.md.`

Write the Stop-hook opt-in markers (edit-skill safety net):

```bash
mkdir -p "$DEV_DIR" 2>/dev/null && touch "$DEV_DIR/.validate-fast-required" "$DEV_DIR/.verify-rules-required"
```

Print: `FIX-REVIEW COMPLETE` and STOP.

(Strict steps 1–7 below do NOT run in flow mode.)

## MODE=strict — Review-targeted fix loop (default)

### Step 1: Read Review & Load Context

**Read**: `$DEV_DIR/review.md`

If missing: print `[1/7] no review.md — nothing to fix` then `FIX-REVIEW COMPLETE` and STOP.

**Read**: `CLAUDE.md` (fall back to `CLAUDE.md`). Extract `PROJECT_ID` and Validation table commands (TypeCheck, Lint, Test).

Print: `[1/7] review read, PROJECT_ID={ID} — continuing to step 2`

### Step 2: Analyze Issues & Snapshot

Parse findings. For each issue extract: file path, rule violated, root cause, fix approach.

Determine:
- `ISSUE_FILES`: files with issues
- `VIOLATED_RULES`: rule names from findings
- `VALIDATION_SCOPE`: logic-changing (need tests) or cosmetic (typecheck + lint only)

**Bash** — snapshot pre-fix state:
```bash
(git diff --name-only HEAD 2>/dev/null; git diff --cached --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null) | sort -u
```
Store as `PRE_FIX_FILES`.

Print: `[2/7] analysis done — {N} issues in {M} files — continuing to step 3`

### Step 3: Apply Fixes (Task → do-development)

**Task**:
- `subagent_type`: `"do-development"`
- `description`: `"Fix review issues"`
- `prompt`:
  ```
  PROJECT_ID=$PROJECT_ID
  Task: fix review violations

  Issues to fix (from .dev/review.md):
  <issue 1 file path + rule + fix approach>
  <issue 2 ...>
  ...

  Files involved:
  $ISSUE_FILES

  Follow do-development's TDD workflow. Validate inline (Step 3 of do-development
  runs typecheck/lint/test directly via Bash — never via sub-skill). Run verify.py
  directly (Step 5). Output `DO-DEVELOPMENT COMPLETE` when all gates pass.
  ```

On `DO-DEVELOPMENT COMPLETE`: print `[3/7] fixes applied — continuing to step 4` and proceed.

On `DO-DEVELOPMENT BLOCKED`: print `FIX-REVIEW BLOCKED: do-development failed` and STOP.

### Step 4: Compute Fixed Files

**Bash**:
```bash
(git diff --name-only HEAD 2>/dev/null; git diff --cached --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null) | sort -u
```
Compare with `PRE_FIX_FILES` to identify `FIXED_FILES` (added/modified since step 2).

Print: `[4/7] {N} files changed — continuing to step 5`

### Step 5: Validation (inline Bash — no sub-skill, no subagent)

#### Scoped Test Resolution

**Bash**:
```bash
test -f $DEV_DIR/.test-map.md && echo "TEST_MAP=EXISTS" || echo "TEST_MAP=MISSING"
```

**IF EXISTS:** Read `$DEV_DIR/.test-map.md`. Get changed files:
```bash
(git diff --name-only HEAD 2>/dev/null; git diff --cached --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null) | sort -u
```
For each changed file, look up in test map File Mappings:
- **Found in table**: use the Scoped Command from that row
- **In a test root but unmapped**: use that root's Full Command
- **Changed file IS a test file**: run directly via root's Command Prefix + file path
- **Not in any test root**: skip

Deduplicate commands. Use these instead of the full Test command.

**IF MISSING:** Invoke `/discover-tests` via the Skill tool. Wait for `DISCOVER-TESTS COMPLETE`. Re-check `$DEV_DIR/.test-map.md`.
- If now EXISTS → read it and use scoped resolution above.
- If still MISSING (e.g., no Test row in Validation table) → fall back to full Test command with a one-line warning.

#### Run Validation

```bash
yarn typecheck && yarn lint && {scoped_or_full_test_command}
```

- All exit 0 → print `[5/7] validation passed — continuing to step 6` and proceed.
- Any non-zero → loop back to Step 3 with the validation error as context. **Max 3 total loops**; if still failing, print `FIX-REVIEW BLOCKED: validate failed` and STOP.

### Step 6: Full-Scope Re-review

Re-review ALL `FIXED_FILES` against the FULL applicable rule set (not just originally violated rules — fixes often introduce new violations).

#### 6a. Deterministic gate — verify.sh (Bash)

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/verify.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/verify.sh" $FIXED_FILES
```

- Exit 0 → continue to 6b.
- Non-zero → read `$DEV_DIR/verify-rules.md`, loop back to Step 3 with violations as context. **Max 2 loops**.

#### 6b. LLM re-review (Task → review-code)

**Task**:
- `subagent_type`: `"review-code"`
- `description`: `"Re-review fixed files"`
- `prompt`:
  ```
  Re-review these files for PROJECT_ID=$PROJECT_ID against the FULL applicable rule set.
  Files:
  $FIXED_FILES

  Output findings in the standard format:
    ==== REVIEW FINDINGS ====
    ...
    ==== END FINDINGS ====
  OR, if clean:
    ==== NO ISSUES ====
  End with `REVIEW COMPLETE`.
  ```

Parse result in the same turn:

**IF** `==== NO ISSUES ====`:
1. **Bash**: `rm -f $DEV_DIR/review.md`
2. Print: `[6/7] re-review passed — all issues resolved — continuing to step 7`

**IF** `==== REVIEW FINDINGS ====`:
1. Extract block between `==== REVIEW FINDINGS ====` and `==== END FINDINGS ====`.
2. **Bash**: `mkdir -p $DEV_DIR`
3. **Write**: `$DEV_DIR/review.md`:
   ```
   # Review: $PROJECT_ID
   *Generated: <ISO-8601 UTC timestamp>*

   <extracted findings block>
   ```
4. Print: `[6/7] re-review done — {N} issues remain — continuing to step 7`

### Step 7: Final Check

**Bash**: `test -f $DEV_DIR/review.md && echo "EXISTS" || echo "GONE"`

- `GONE`: print `[7/7] all issues resolved`
- `EXISTS`: print `[7/7] issues remain in .dev/review.md`

Write the Stop-hook opt-in markers (edit-skill safety net):

```bash
mkdir -p "$DEV_DIR" 2>/dev/null && touch "$DEV_DIR/.validate-fast-required" "$DEV_DIR/.verify-rules-required"
```

Print: `FIX-REVIEW COMPLETE`

## Exit Criteria

- [ ] `MODE` resolved (strict|flow)
- [ ] (flow) Fresh `$DEV_DIR/flow/data.json` generated in F1
- [ ] (flow) If no fails AND no warns: early-exit with `FIX-REVIEW COMPLETE`
- [ ] (flow) Otherwise: up to 3 rounds of fix → re-measure
- [ ] (strict) `$DEV_DIR/review.md` read via Read tool
- [ ] (strict) PROJECT_ID and Validation commands extracted from CLAUDE.md
- [ ] (strict) Issues analyzed with files, rules, and validation scope identified
- [ ] (strict) Pre-fix file state captured via Bash tool
- [ ] (strict) `do-development` invoked via **Task tool** (NOT Skill tool)
- [ ] (strict) Inline Bash validation passed (typecheck + lint + test)
- [ ] (strict) `verify.sh` exited 0 (Step 6a)
- [ ] (strict) `review-code` invoked via **Task tool** (NOT Skill tool)
- [ ] (strict) `$DEV_DIR/review.md` written or deleted in Step 6b based on Task result
- [ ] (strict) Step 7 executed: `$DEV_DIR/review.md` checked via Bash
- [ ] Printed `FIX-REVIEW COMPLETE`
