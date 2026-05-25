# do-development playbook


# do-development

Implements a task following project rules using TDD (red → green → refactor). **TDD is mandatory in both strict and flow modes.**

**Runtime:** Invoked as a Task-tool subagent (`subagent_type: do-development`) by orchestrators like `fix-review`. Per anthropics/claude-code#19077, subagents cannot spawn further subagents via Task tool; per #17351, using the Skill tool yields control to the user. All validation and rule-checking uses **direct Bash invocations** only.

**NO SHORTCUTS:** Do NOT print `DO-DEVELOPMENT COMPLETE` until:
- (strict) Step 3 validation exits 0, self-verification checklist is all PASS, and `verify.py` (Step 5) exits 0.
- (flow) Step 3 validation exits 0, self-verification checklist is all PASS, AND Step 5 `verify.sh --json` reports zero violations — OR max-2 verify revision cap hit → print `DO-DEVELOPMENT BLOCKED: verify-rules violations remain after 2 revisions`. Code-shape metrics (coverage, complexity, duplication, dep cycles) are NOT collected here; `review-code --flow` runs the single flow-metrics pass later in the pipeline.

## Mode

Parse input: if it contains `--flow` as a standalone token, strip it and set `MODE=flow`. Otherwise `MODE=strict`. The envelope (Step 0) and the gate (Step 5) branch on `MODE`; TDD (Step 2) is identical in both.

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/_shared/parse-mode.sh" ] || _sh="$HOME/.claude"
eval "$(bash "$_sh/skills/_shared/parse-mode.sh" "$INPUT")"
```

## Step 0: Resolve Dev Dir + Load Rules

**Bash tool:**
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh"
```
Capture output as `DEV_DIR`. Use for all `.dev/` operations.

**If a RULES ENVELOPE is provided** (delimited by `==== RULES ENVELOPE ====` / `==== END RULES ====`): extract `MODE`, PROJECT_ID, rules content, and validation commands from it; skip file reads; print `Rules loaded: from envelope (MODE=$MODE)`.

**Otherwise**, read `CLAUDE.md` (first found at project root). Extract `PROJECT_ID` from `PROJECT_ID="..."`.

Resolve rules directory (first match):
```bash
for d in .claude/skills/_rules .claude/skills/_rules "$HOME/.claude/skills/_rules" "$HOME/.kimi/skills/_rules"; do [ -d "$d" ] && echo "RULES_DIR=$d" && break; done
```

**Load rules from `$RULES_DIR/` — same set in both modes:**

1. `guard-clauses.md`
2. `tdd.md`
3. `code-quality.md`
4. `security.md`
5. `project-{PROJECT_ID}.md` (if exists)
6. Language rules (first match):
   - `package.json` with `"react"` in deps → `react.md` + `typescript.md`
   - `package.json` without react → `typescript.md`
   - `go.mod` → `go.md`
   - `pyproject.toml` or `requirements.txt` → `python.md`
   - `Cargo.toml` → `rust.md`
7. Database rules if detected: `prisma/schema.prisma`, `"@prisma/client"`, `drizzle.config.ts`, or `"drizzle-orm"` → `database.md`
8. **Flow only** — append `flow.md` last. It documents metric thresholds and the metric-driven gate philosophy. Strict mode MUST NOT load it.

`commit.md` and `pr.md` are NEVER loaded here — they're owned by the commit / PR skills.

Extract every `- [ ]` bullet under `## CRITICAL — ENFORCED BY verify-rules` from each loaded file into a CONSTRAINTS LIST (both modes). Print:

```
==== CONSTRAINTS (MUST HOLD BEFORE COMPLETE) ====
{numbered list of every CRITICAL bullet}
==== END CONSTRAINTS ====
```

Then print: `Rules loaded (MODE=$MODE): {comma-separated filenames in load order}`

## Step 1: Understand Task

Parse `$REMAINING` (input minus `--flow`). Fall back to `$DEV_DIR/current-task`, git branch, or `state.md`.

Input format: `"$TYPE, $SCOPE, $TITLE"`
- `$TYPE`: feature|bug|refactor|test
- `$SCOPE`: module-name (optional)
- `$TITLE`: short description

## Step 2: TDD Cycle (mandatory in BOTH modes)

1. **Red** — write failing test
2. **Green** — minimal code to pass
3. **Refactor** — clean up, keep tests green
4. Repeat for all criteria

All tests use mocks (no real API / DB / FS / network) per `tdd.md`.

After Green and Refactor of each cycle, reprint (both modes):
```
REMINDER — CRITICAL constraints still in force:
- max 399 lines per file
- no `any`, no `@ts-ignore`, no suppression comments
- no TODO/FIXME/XXX markers
- TDD: ALL tests mocked (no real DB/API/FS)
- {top 3 project-specific constraints}
```

In flow mode these constraints are mechanically gated by `verify.sh --json` in Step 5 (parity with strict's `verify.sh` gate); the reminder accurately describes the gate, not just guidance.

## Step 3: Validate (inline Bash only — never Skill tool)

Read the Validation table from `CLAUDE.md`. Run all rows (TypeCheck, Lint, Test, etc.).

**Scoped test resolution:** Check if `$DEV_DIR/.test-map.md` exists:
```bash
test -f $DEV_DIR/.test-map.md && echo "TEST_MAP=EXISTS" || echo "TEST_MAP=MISSING"
```

If EXISTS: read it, get changed files:
```bash
(git diff --name-only HEAD 2>/dev/null; git diff --cached --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null) | sort -u
```
For each changed file, look up in the test map's File Mappings tables:
- Found → use its Scoped Command
- In a test root but unmapped → use that root's Full Command
- Changed file IS a test file → root's Command Prefix + test file path
- Not in any test root → skip

Deduplicate and run scoped commands instead of the full Test command.

If MISSING: invoke `/discover-tests` via the Skill tool, wait for `DISCOVER-TESTS COMPLETE`, then re-check `$DEV_DIR/.test-map.md`.
- If now EXISTS → read it and proceed with scoped resolution above.
- If still MISSING (e.g., no Test row in Validation table) → fall back to the full Test command with a one-line warning.

Run all commands via Bash tool:
```bash
yarn typecheck || { echo "TYPECHECK FAILED"; exit 1; }
yarn lint || { echo "LINT FAILED"; exit 1; }
{test_command} || { echo "TEST FAILED"; exit 1; }
echo "VALIDATE COMPLETE"
```

- TypeCheck and Lint always run on full codebase.
- On non-zero exit: print concise failure summary, return to Step 2, re-run Step 3. **Max 3 loops (strict), max 2 loops (flow).** If still failing: abort with `DO-DEVELOPMENT BLOCKED: validation failed after N retries`.
- Do not proceed to Step 4 until all commands exit 0 and `VALIDATE COMPLETE` is printed.

## Step 4: Self-Verification Checklist (both modes)

For every item in CONSTRAINTS LIST, state PASS or FAIL with a one-line justification tied to a specific file/line in the diff:

```
==== SELF-VERIFICATION ====
[1] max 399 lines per file — PASS (max is src/foo.ts:287)
[2] no `any` type — PASS (grepped diff, zero hits)
...
[N] {constraint} — PASS/FAIL ({justification})
==== END SELF-VERIFICATION ====
```

If ANY item is FAIL: return to Step 2, fix, re-run Steps 3–4. **Max 3 loops.** If still failing: abort with `DO-DEVELOPMENT BLOCKED: {reason}`.

In flow mode, the CONSTRAINTS LIST is the same as strict (Step 0 builds it identically). Self-verification gives the agent a chance to self-correct before the verify.sh gate (Step 5) runs.

## Step 5: Gate

### MODE=strict — Deterministic grep gate (direct Bash)

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/verify.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/verify.sh" <changed files>
```

- Exit 0 → proceed to Step 6.
- Non-zero → read `$DEV_DIR/verify-rules.md`, fix violations, return to Step 2, re-run script. **Max 2 additional iterations.** If still failing: abort with `DO-DEVELOPMENT BLOCKED: verify-rules failed after 2 retries`.

### MODE=flow — Mechanical grep gate (direct Bash)

Run the grep gate to cover forbidden tokens / file size / TODO markers (parity with strict's `verify.sh`). Code-shape metrics (coverage, complexity, duplication, dep cycles) are deferred to `review-code --flow` later in the pipeline — do NOT collect them here.

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/verify.sh" ] || _sh="$HOME/.claude"
mkdir -p "$DEV_DIR/flow"
bash "$_sh/skills/verify-rules/scripts/verify.sh" --json > "$DEV_DIR/flow/critical.json" || true
```

**Read**: `$DEV_DIR/flow/critical.json`. Each entry in `violations` counts as a `fail`.

- `violations` empty → proceed to Step 6.
- `violations` non-empty → revise: remove the `any` cast, split the file under 399 lines, drop the TODO marker, etc. Re-run Step 3 + 5. **Max 2 revision rounds.**
- After 2 rounds still failing → print `DO-DEVELOPMENT BLOCKED: verify-rules violations remain after 2 revisions`, include remaining violations, STOP.

## Step 6: Completion

When the chosen gate passes, write the Stop-hook opt-in markers so the
verify-rules and validate-fast hooks run as a final safety net (only
edit-skills trigger these; creation/read-only skills do not):

```bash
mkdir -p "$DEV_DIR" 2>/dev/null && touch "$DEV_DIR/.validate-fast-required" "$DEV_DIR/.verify-rules-required"
```

Then print: `DO-DEVELOPMENT COMPLETE`

## Exit Criteria

- [ ] `MODE` resolved (strict or flow)
- [ ] All criteria have tests
- [ ] Inline Bash validate printed `VALIDATE COMPLETE` (typecheck + lint + test all exit 0)
- [ ] ALL tests pass (unit + integration + e2e)
- [ ] ALL type checking passes
- [ ] ALL lint checks pass
- [ ] No TODOs in code (verify.sh enforces in both modes)
- [ ] ZERO errors across codebase
- [ ] Self-verification checklist printed, every item PASS (both modes)
- [ ] (strict) `verify.py` exited 0 (no mechanical violations)
- [ ] (flow) `verify.sh --json` reported zero violations OR max-2 cap hit with `BLOCKED` marker. Flow-metrics is collected by `review-code --flow` downstream, not here.
