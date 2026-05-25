# verify playbook


# verify

Pre-PR loop. Extends `validate` (typecheck/lint/test) with build, security, diff review.

## Input

```
/verify              # all uncommitted changes
/verify <files>      # specific files
```

## Load Rules

Read `CLAUDE.md` or `CLAUDE.md` (first found). Extract `PROJECT_ID`.

## Workflow

**Phase 1 — Build:** Run build command from Validation table (if exists). Record PASS/FAIL/SKIP.

**Phase 2-4 — Validate:** Invoke `/validate`. On `VALIDATE COMPLETE`, map to Typecheck/Lint/Tests PASS/FAIL. Never stop on failure — proceed.

**Phase 5 — Security:**
```bash
FILES=$(git diff --name-only HEAD 2>/dev/null || git diff --name-only)
```
If files exist, invoke `/incremental-security`. On `INCREMENTAL-SECURITY COMPLETE`, record PASS (no findings) or FAIL. No files → SKIP. Proceed.

**Phase 6 — Diff Review:** Scan `git diff` for:
- Debug statements (`console.log`, `print()`, `fmt.Println`)
- Commented-out code blocks
- TODO/FIXME without ticket references
- Hardcoded secrets or credentials
- Files that shouldn't be committed (`.env`, binaries)

## Output

```
==== VERIFICATION REPORT ====

| Phase      | Result |
|------------|--------|
| Build      | PASS   |
| Typecheck  | PASS   |
| Lint       | PASS   |
| Tests      | PASS   |
| Security   | PASS   |
| Diff Review| PASS   |

Result: ALL PASSED
==== END REPORT ====
```

On failure, add Details column and append:

```
Result: FAILED (3 phases)

### Failures

#### Typecheck
- src/lib/utils.ts:42 — Type 'string' is not assignable to type 'number'

#### Tests
- test/auth.test.ts — "should validate token" FAILED

#### Diff Review
- src/api/handler.ts:15 — console.log("debug")
==== END REPORT ====
```

## Exit

- [ ] All 6 phases attempted (or SKIP with reason)
- [ ] Structured report printed with per-phase PASS/FAIL
- [ ] Failed phases include detail summary
- [ ] Final result: ALL PASSED or FAILED (N phases)

Print `VERIFY COMPLETE` after the report.
