# validate playbook


# validate

Run validation commands from project rules.

**Contract:** Callers MUST treat `VALIDATE FAILED` as blocking. Do not print any downstream COMPLETE marker until this skill prints `VALIDATE COMPLETE`.

## Input

```bash
/validate              # Full mode (default)
/validate full         # Explicit full mode
/validate scoped       # Scoped — only tests for changed files (requires .dev/.test-map.md)
```

**Modes:**
- **full**: Runs all Validation table commands (TypeCheck + Lint + Test). Final gate.
- **scoped**: TypeCheck/Lint full codebase. Test only changed files via `.dev/.test-map.md`. Auto-invokes `/discover-tests` if map missing, then re-reads.

## Load Rules

**If RULES ENVELOPE provided** (delimited by `==== RULES ENVELOPE ====` / `==== END RULES ====`): extract PROJECT_ID and validation commands from it, skip file reads, print `Rules loaded: from envelope`.

**Otherwise**, load from files:

Read `CLAUDE.md` (first found at project root). Extract `PROJECT_ID`.

**Resolve rules directory** (first match wins):
```bash
for d in .claude/skills/_rules .claude/skills/_rules "$HOME/.claude/skills/_rules" "$HOME/.kimi/skills/_rules"; do [ -d "$d" ] && echo "RULES_DIR=$d" && break; done
```

Read from `$RULES_DIR/`:
1. `guard-clauses.md`
2. `tdd.md`
3. `code-quality.md`
4. `project-{PROJECT_ID}.md` (if exists)
5. Language rules (first match):
   - `package.json` → `react.md` (if `"react"` in deps) else `typescript.md`
   - `go.mod` → `go.md`
   - `pyproject.toml` or `requirements.txt` → `python.md`
   - `Cargo.toml` → `rust.md`
6. `database.md` if `prisma/schema.prisma`, `"@prisma/client"`, `drizzle.config.ts`, or `"drizzle-orm"` detected.

Print: `Rules loaded: guard-clauses.md, tdd.md, code-quality.md, project-{PROJECT_ID}.md, {language}.md[, database.md]`

## Steps

### Determine Test Command

Resolve dev directory:
```bash
DEV_DIR=$(_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh")
```

**If `scoped`:**
1. Check `$DEV_DIR/.test-map.md` exists.
2. If missing: invoke `/discover-tests`, wait for `DISCOVER-TESTS COMPLETE`, re-check. If still missing (e.g., no Test row in Validation table), warn and fall back to full.
3. Read it. Get changed files:
   ```bash
   (git diff --name-only HEAD 2>/dev/null; git diff --cached --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null) | sort -u
   ```
4. For each changed file, look up in File Mappings tables:
   - **Found**: collect Scoped Command from that row
   - **Unmapped but in a test root**: collect that root's Full Command
   - **Is a test file** (`test_*`, `*_test.*`, `*.test.*`, `*.spec.*`): run directly via root's Command Prefix + file path
   - **Not in any test root**: skip
5. Deduplicate. If no commands collected, skip Test step.

**If `full`:** use Test command from Validation table as-is.

### Run Validation

Run each command in order. Collect ALL errors — don't stop at first failure.

```bash
<typecheck-command>
<lint-command>
<test-command>
```

## Handle Failures

1. Collect ALL errors from all commands
2. Group by type, fix in order: type → lint → test
3. Re-validate after each group. Max 3 cycles; report remaining errors and stop.

```
Cycle 1: Fix type errors -> re-validate all
Cycle 2: Fix lint errors -> re-validate all
Cycle 3: Fix test failures -> re-validate all
```

New errors during fixes join the appropriate group.

## Exit

- [ ] All validation commands run
- [ ] ALL pass with ZERO errors — no exceptions, no skips

On success print: `VALIDATE COMPLETE`
On failure after 3 cycles print: `VALIDATE FAILED` and stop.
