# discover-tests playbook


# discover-tests

Generate `$DEV_DIR/.test-map.md` — a source-file-to-test-command map used by `do-development`, `validate scoped`, and `fix-review` for scoped test runs. Generated once; regenerate when test structure changes.

## Input

```bash
/discover-tests              # Generate test map for current project
/discover-tests --force      # Regenerate even if .test-map.md exists
echo "--force" | /discover-tests
```

## Workflow

### Step 1: Resolve DEV_DIR

**Bash tool**:
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh"
```

Capture output as `DEV_DIR`. Use for ALL `.dev/` operations.

### Step 2: Check Existing Map

```bash
test -f $DEV_DIR/.test-map.md && echo "EXISTS" || echo "MISSING"
```

- `EXISTS` without `--force`: print `Test map already exists at $DEV_DIR/.test-map.md — use --force to regenerate`, then `DISCOVER-TESTS COMPLETE`, STOP.
- `MISSING` or `--force`: continue.

### Step 3: Read Validation Table

**Read tool**: `CLAUDE.md` (fall back to `CLAUDE.md`).

Extract `PROJECT_ID` from `PROJECT_ID="..."`. Extract Validation table — find `Test` row, capture full command string.

If no `Test` row: print `No Test command in Validation table — cannot generate test map` and STOP.

### Step 4: Parse Test Roots

Split Test command on `&&` or `;`. For each segment:

1. Extract `cd <dir>` target → **test root directory** (default `.` if no `cd`).
2. Detect **runner**: `pytest`/`python -m pytest` → pytest | `vitest` → vitest | `jest`/`npx jest` → jest | `go test` → go | `cargo test` → cargo
3. Extract **command prefix** — full command excluding specific test file args
4. Store **full command** as-is
5. Derive **coverage command** — preferring the project's existing dedicated coverage script over a synthesized one:

   **5a. Prefer `package.json` `coverage` script (vitest/jest only).**
   When the test root contains `package.json`, read `scripts.coverage`. If it exists AND its value mentions the detected runner (`vitest` or `jest`), use the project's own script:
   - **Detect package manager** from lockfiles at the test root (in priority order):
     `pnpm-lock.yaml` → `pnpm` | `yarn.lock` → `yarn` | `bun.lockb` → `bun` | else `npm`
   - **Build the base command** from package manager:
     `pnpm coverage` | `yarn coverage` | `bun run coverage` | `npm run coverage`
   - **Append the runner's json-summary reporter** so the collector can parse the result:
     - vitest → ` --coverage.reporter=json-summary` (pnpm/bun/yarn pass through; npm/yarn need `-- ` separator: `npm run coverage -- --coverage.reporter=json-summary`)
     - jest   → ` --coverageReporters=json-summary` (same `-- ` separator rule)

   **5b. Otherwise, synthesize from the Test row** — same prefix, appending the runner-specific coverage flags below. This is the fallback for projects without a dedicated coverage script:

   | Runner | Append to full command | Output file checked |
   |--------|-----------------------|---------------------|
   | pytest | `--cov=. --cov-report=json:coverage.json --cov-report=` | `coverage.json` |
   | vitest | `--coverage --coverage.reporter=json-summary` | `coverage/coverage-summary.json` |
   | jest   | `--coverage --coverageReporters=json-summary` | `coverage/coverage-summary.json` |
   | go     | replace `go test` with `go test -cover ./...` | stdout (`coverage: N%`) |
   | cargo  | replace `cargo test` with `cargo tarpaulin --no-fail-fast` | stdout (`N% coverage`) |

   If the runner is unknown, set coverage command to `(unsupported runner)` rather than guessing.

**Examples:**
```
A) package.json with dedicated coverage script (preferred path):
   Test row:           pnpm test
   package.json scripts.coverage: "vitest run --coverage"
   Lockfile present:   pnpm-lock.yaml → pm=pnpm
   Result:
     Root 1: dir=., runner=vitest,
             prefix="pnpm test", full="pnpm test",
             coverage="pnpm coverage --coverage.reporter=json-summary"

B) No coverage script — fall back to synthesis:
   Input:  cd tools/sync && .venv/bin/python -m pytest
   Result:
     Root 1: dir=tools/sync, runner=pytest,
             prefix="cd tools/sync && .venv/bin/python -m pytest",
             coverage="cd tools/sync && .venv/bin/python -m pytest --cov=. --cov-report=json:coverage.json --cov-report="
```

Print: `Found {N} test root(s): {root1}, {root2}, ...`

### Step 5: Scan and Map Files

For each test root:

**Bash tool** (per root):
```bash
# Source files
find {root} -type f \( -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.go" -o -name "*.rs" \) \
  ! -path "*/test*" ! -path "*/__pycache__/*" ! -path "*/node_modules/*" ! -path "*/.venv/*" \
  ! -name "test_*" ! -name "*_test.*" ! -name "*.test.*" ! -name "*.spec.*" | head -200

# Test files
find {root} -type f \( -name "test_*.py" -o -name "*_test.py" -o -name "*.test.ts" -o -name "*.test.tsx" \
  -o -name "*.spec.ts" -o -name "*_test.go" \) \
  ! -path "*/__pycache__/*" ! -path "*/node_modules/*" ! -path "*/.venv/*" | head -200
```

**Match source files to tests** (strategies in order):

1. **Name convention** (runner-dependent):
   - pytest: `src/foo/bar.py` → `test_bar.py`, `bar_test.py`
   - vitest/jest: `src/foo/bar.ts` → `bar.test.ts`, `bar.spec.ts`
   - go: `src/foo/bar.go` → `bar_test.go` (same dir)
   - cargo: `src/foo/bar.rs` → `tests/bar.rs` or inline `#[cfg(test)]`

2. **Directory mirroring**: `tools/sync/sync_agents.py` → `tools/sync/test_sync_agents.py` or mirrored under `tests/`

3. **Import grep** (only if 1–2 found nothing):
   ```bash
   # Python
   grep -rl "from.*{module_name} import\|import {module_name}" {test_dir}/ 2>/dev/null | head -10
   # TypeScript
   grep -rl "from.*['\"].*{module_name}['\"]" {test_dir}/ 2>/dev/null | head -10
   ```

**Categorize each source file:**
- **Mapped**: specific test file(s) found → scoped command: `{prefix} {test_file1} {test_file2}`
- **Unmapped-in-root**: inside a test root, no specific test → full root command at runtime
- **Outside**: not in any test root → skip

### Step 6: Write Test Map

```bash
mkdir -p $DEV_DIR
```

**Write tool**: `$DEV_DIR/.test-map.md`:

```markdown
# Test Map
*Generated: {ISO-8601 UTC timestamp}*
*Source: CLAUDE.md Validation table*
*Project: {PROJECT_ID}*

## Test Roots

| Root | Runner | Command Prefix | Full Command | Coverage Command |
|------|--------|----------------|--------------|------------------|
| {root1} | {runner1} | {prefix1} | {full_cmd1} | {coverage_cmd1} |

## File Mappings

### {root1}

| Source | Test Files | Scoped Command |
|--------|-----------|----------------|
| {source1} | {test1} | {scoped_cmd1} |
| {source2} | {test2a}, {test2b} | {scoped_cmd2} |

## Unmapped Files

Files in test roots with no specific test mapping (full root tests will run):
- {unmapped1}
```

### Step 7: Summary

```
Test map written to $DEV_DIR/.test-map.md
  Roots: {N}
  Mapped files: {M}
  Unmapped files: {U}
```

Print: `DISCOVER-TESTS COMPLETE`

## How Downstream Skills Use the Test Map

Skills (do-development, validate, fix-review) check `$DEV_DIR/.test-map.md`:

1. Get changed files: `git diff --name-only HEAD; git ls-files --others --exclude-standard`
2. Read `$DEV_DIR/.test-map.md`
3. For each changed file:
   - **In table**: use Scoped Command
   - **In root, not in table**: use root's Full Command
   - **Not in any root**: skip
   - **Changed file IS a test file**: run it directly using root's Command Prefix
4. Deduplicate and combine all scoped commands
5. Run combined command instead of full Test command

## Exit Criteria

- [ ] Resolved `DEV_DIR` via resolve-dev.sh
- [ ] Checked for existing `$DEV_DIR/.test-map.md`
- [ ] Validation table parsed, Test command extracted
- [ ] Test roots identified with runner type, command prefix, AND coverage command
- [ ] Source files scanned and matched to test files
- [ ] `$DEV_DIR/.test-map.md` written with roots, mappings, and unmapped files
- [ ] Summary printed
- [ ] Printed `DISCOVER-TESTS COMPLETE`
