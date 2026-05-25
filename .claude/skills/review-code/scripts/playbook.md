# review-code playbook

## Mode parsing

Parse first argument (or stdin) for a standalone `--flow` token. Strip it if present; set `MODE=flow|strict`; pass the rest through as PROJECT_ID / files.

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/_shared/parse-mode.sh" ] || _sh="$HOME/.claude"
eval "$(bash "$_sh/skills/_shared/parse-mode.sh" "$INPUT")"
```

## Output formats

### MODE=strict

````
==== REVIEW FINDINGS ====
#### File: `path/to/file` (Line X)

- **Severity:** error|warning
- **Rule:** violated rule name
- **Issue:** specific problem
- **Fix:**
  ```language
  fixed code
  ```
---
...
==== END FINDINGS ====
````

If no issues: `==== NO ISSUES ====`

### MODE=flow

- Writes `$DEV_DIR/flow/data.json` (via collector).
- Writes `$DEV_DIR/flow/report.md` (rendered by collector).
- Prints one-line summary (Summary row from the report).
- If `summary.fails == 0 AND summary.warns == 0` → prints `==== NO ISSUES ====`.
- Otherwise prints `==== REVIEW FINDINGS ==== see $DEV_DIR/flow/report.md ==== END FINDINGS ====`.

## Workflow

### Step 0: Resolve dev directory

**Bash tool**:
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh"
```
Capture output as `DEV_DIR` for ALL `.dev/` operations below.

### Step 0a — MODE=flow branch (early exit)

When `MODE=flow`, delegate to `flow-metrics` and skip the rest of the strict workflow.

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/flow-metrics/scripts/collect.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/flow-metrics/scripts/collect.sh" --dev-dir "$DEV_DIR" $SCOPE_ARG
```

Pass through the scope folder from input (if any). The collector writes `$DEV_DIR/flow/data.json` + `$DEV_DIR/flow/report.md` including coverage, complexity, duplication, dep cycles, and mutation entries with their severity. Coverage below the thresholds in `flow.md` surfaces as a `fail`-severity entry automatically.

Read `$DEV_DIR/flow/data.json`:
- `summary.fails == 0 AND summary.warns == 0` → print `==== NO ISSUES ====` and the Summary line from `report.md`, then print `REVIEW COMPLETE`. Done.
- Otherwise → print `==== REVIEW FINDINGS ==== see $DEV_DIR/flow/report.md ==== END FINDINGS ====`, the Summary line, then `REVIEW COMPLETE`. Done.

Do NOT proceed to strict Steps 1–6.

### Step 0b — MODE=strict: Deterministic pre-pass

**DO NOT** call `/verify-rules` via the Skill tool — nested Skill calls trigger anthropics/claude-code#17351. Since review-code runs as a Task-tool subagent, it cannot spawn further subagents per #19077. Call the script directly via **Bash tool**:

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/verify.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/verify.sh" <files>
```

- Exit 0 → VERIFY-RULES PASSED, continue with empty seed list.
- Non-zero → VERIFY-RULES FAILED. Read `$DEV_DIR/verify-rules.md` if it exists and seed findings with each mechanical violation (severity: error, rule: verify-rules, fix: remove the forbidden pattern / shrink the file). Continue to Step 1 — LLM pass adds on top.

### Step 1: Load Rules (FULL SET — no targeted selection)

**IF a RULES ENVELOPE is provided** (delimited by `==== RULES ENVELOPE ====` / `==== END RULES ====`): extract PROJECT_ID and rules content, skip file reads, print `Rules loaded: from envelope`.

**OTHERWISE**, load the complete applicable rule set. Do NOT do per-file targeted selection — causes shallow reviews.

Read project rules (`CLAUDE.md`, first found in project root). Extract `PROJECT_ID`.

**Resolve rules directory** (first match wins):
```bash
for d in .claude/skills/_rules .claude/skills/_rules "$HOME/.claude/skills/_rules" "$HOME/.kimi/skills/_rules"; do [ -d "$d" ] && echo "RULES_DIR=$d" && break; done
```

**Always load shared rules from `$RULES_DIR/`:**
1. `guard-clauses.md`
2. `code-quality.md`
3. `tdd.md`
4. `security.md`
5. `project-{PROJECT_ID}.md` (if exists)

**Language rules — load ALL languages present in the file set:**
- Any `.ts`/`.tsx` → `typescript.md`
- Any `.tsx` OR `"react"` in `package.json` → ALSO `react.md`
- Any `.py` → `python.md`
- Any `.go` → `go.md`
- Any `.rs` → `rust.md`

**Database rules — load if ANY of:** `prisma/schema.prisma` exists; `"@prisma/client"` or `"drizzle-orm"` in `package.json`; `drizzle.config.ts` exists; any changed file matches `*router*`, `*trpc*`, `*api*`, `*.prisma`.

**Report before proceeding:**
```
Rules loaded (full set): guard-clauses.md, code-quality.md, tdd.md, security.md, project-{PROJECT_ID}.md, typescript.md, react.md[, database.md, ...]
```

Do NOT proceed until the report is printed.

### Step 2: Parse Input

No files → output `==== NO ISSUES ====` and exit.

### Step 3: File Batching

If >50 files, process in batches of 50, accumulating findings.

### Step 4: First Pass — File-by-File Review

**Role:** Rule compliance checker. Only flag violations of loaded rules. No improvements, style changes, or alternatives outside the rule set. No padding observations.

For each file, evaluate against the FULL loaded rule set.

**Evidence gate — EVERY finding must pass ALL 4 checks before emission:**

1. Can you name the SPECIFIC rule being violated? (e.g., "No string concatenation in SQL" — not "security best practice")
2. Can you quote the EXACT line(s) where the violation occurs?
3. Is the violation verifiable from this file alone? (Not "might be missing auth" because middleware could handle it)
4. If you removed this finding, would a real bug, data loss, or exploitable vulnerability exist?

Any "no" → DROP the finding.

**ONLY flag:** Bug, security risk, broken logic, or clear rule violation passing the evidence gate.
**NEVER flag:** Info, suggestions, style preferences, documentation gaps, "could be improved" observations.
**Default:** When in doubt, do NOT report. Err toward silence.

**Severity calibration:**
- **error**: Will cause a bug, data loss, or exploitable vulnerability in production. >95% certain.
- **warning**: Violates a specific named rule unambiguously. >85% certain.
- Below these → DROP.

**DO NOT flag (common false positives):**

| Category | Why it's a false positive |
|----------|--------------------------|
| Security rules on non-user-facing code (build scripts, CLI tools, migrations, seeds, test helpers) | Security.md applies only to code handling external/user input |
| Architectural security (CSRF tokens, rate limiting, session timeout, security headers, HTTPS) | Deployment/infrastructure — only flag if code explicitly disables a security mechanism |
| "Every endpoint checks authorization" / IDOR | Auth may be enforced at middleware/route level, not visible in the handler |
| Missing tests on modified (not new) code | Existing untested functions are tech debt, not a review finding |
| Guard clause style on functions under 5 lines | Trivially short functions don't need refactoring |
| "Composition over prop bloat", "don't overuse memoization", "search before creating" | Subjective guidance, not mechanical rules |
| "Consistent empty/error/loading states", "entire row clickable" | Require cross-project or runtime analysis |
| Rules already enforced by verify-rules (file length, `any`, `TODO`, `console.log`, `@ts-ignore`) | Deterministic pre-pass catches these. Do not duplicate. |
| "Could be improved" or "consider using X instead" | Not a finding if it works and violates no named rule |

**Severity:** Only "error" or "warning" (no "info")
**Fix:** Concrete code, not vague advice.

**Skip:** non-code files (`.md`, `.json`, `.yaml`, `.html`, `.css`), `.vscode/`, `.idea/`

### Step 5: Second-Pass Sweep (scoped)

After file-by-file pass, sweep for cross-cutting issues. Apply the same 4-check evidence gate from Step 4.

- **Dead exports** — ONLY flag if you actually ran `rg` and confirmed zero importers across the ENTIRE repo. If unsure, DO NOT flag. Assume the export is used.
- **Duplicate helpers** — ONLY flag if two functions have >90% identical tokens AND serve the same purpose. `formatDate` vs `formatDateTime` are NOT duplicates.
- **Missing project-specific wiring** — ONLY flag concrete, named conventions from `project-{PROJECT_ID}.md` (e.g., Arena TCG: `is_active: true` filter; zero-horizon: runtime fetch). Must cite the specific rule.
- **Missing tests** — ONLY flag if ALL of: (a) NEW exported function (not modified), (b) contains branching logic (if/else, switch, try/catch), (c) no test file exists anywhere in the repo for that module, (d) sibling modules have tests establishing a convention. If any condition unclear, DO NOT flag.

**REMOVED:** "Inconsistent patterns across files" — subjective, #1 source of false positives. Handled by humans in PR review.

Add findings from this sweep to the list.

### Step 5.5: Deduplicate and Final Filter

1. **Deduplicate**: If verify-rules (Step 0b) already flagged a file+line, remove any LLM finding for the same location. The deterministic finding wins.
2. **Re-check evidence gate**: Review each remaining finding against the 4-check gate. Drop uncertain ones.
3. **Sanity check**: A typical <20-file changeset should produce 0-3 findings. More than 5 signals over-aggressive review — tighten, don't loosen.

### Step 6: Output Findings to stdout

Merge verify-rules seed (Step 0b) + first-pass (Step 4) + second-pass (Step 5). Print directly — Task-tool parent receives stdout and handles file writing.

```
if no findings:
    print "==== NO ISSUES ===="
else:
    print "==== REVIEW FINDINGS ===="
    print <findings block>
    print "==== END FINDINGS ===="
```

## Exit

- [ ] `MODE` resolved (strict|flow)
- [ ] (strict) verify-rules script invoked as deterministic pre-pass (direct Bash, not Skill tool)
- [ ] (strict) PROJECT_ID received as first argument or from envelope
- [ ] (strict) Files received as remaining arguments
- [ ] (strict) FULL rule set loaded (not targeted per-file)
- [ ] (strict) First-pass file-by-file review completed
- [ ] (strict) Second-pass cross-cutting sweep completed
- [ ] (flow) flow-metrics collector invoked; `$DEV_DIR/flow/data.json` + `$DEV_DIR/flow/report.md` written
- [ ] Findings (or `==== NO ISSUES ====`) output on stdout

## Completion

After findings (or `==== NO ISSUES ====`) are output, print: `REVIEW COMPLETE`
