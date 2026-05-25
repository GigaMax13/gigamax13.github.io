# new-review playbook

**Why Task tool, not Skill tool:** anthropics/claude-code#17351 — `Skill()` yields control to user after nested skill completes, preventing post-call logic. Task-tool subagent runtime does not yield; parent turn continues with subagent output as a result message. Step 3 uses `Task(subagent_type=review-code)` so Step 4 reliably executes the `.dev/review.md` write.

## Tool Mapping

| Action | Tool |
|--------|------|
| Read a file | Read tool |
| Run a shell command | Bash tool |
| Write content to a file | Write tool |
| Delete a file | Bash tool: `rm -f <path>` |
| Delegate to a subagent | **Task tool** (`subagent_type: <name>`) — NEVER Skill tool |

## Workflow

### Step 0: Resolve dev directory

**Bash tool**:
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh"
```

Capture output as `DEV_DIR`. Use for ALL `.dev/` operations below.

### Step 1: Detect PROJECT_ID

**Read tool**: `CLAUDE.md` (fall back to `CLAUDE.md`). Extract `PROJECT_ID` from `PROJECT_ID="..."` line. If passed as input, use that instead.

Print: `Review — Project: $PROJECT_ID`

### Step 2: Get Changed Files

Parse input:

**IF input contains specific file paths** (paths with extensions, space or comma separated):
- Use those files directly. Verify each exists via Bash tool.
- Set `CHANGED_FILES` to the verified list.

**ELSE IF input is a directory path** (exists as directory):
- Use as `FOLDER_FILTER`.
- Get all uncommitted files (below), filter to files under `FOLDER_FILTER/`.

**ELSE** (default — all uncommitted changes):

**Bash tool**:

```bash
EXCLUDE='(node_modules/|vendor/|\.venv/|venv/|__pycache__/|\.pytest_cache/|target/|dist/|build/|\.git/|\.idea/|\.vscode/)'
EXTS='\.(py|js|ts|jsx|tsx|go|rs|java|rb|php|c|cpp|h|hpp|swift|kt|scala|sh|bash|zsh|fish|ps1|sql|prisma|dockerfile|makefile|cmake)$'
(git diff --name-only HEAD 2>/dev/null; git diff --cached --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null) | sort -u | grep -E "$EXTS" | grep -vE "$EXCLUDE"
```

**IF `FOLDER_FILTER` is set**, post-filter:
```bash
echo "$ALL_FILES" | grep -E "^${FOLDER_FILTER}/"
```

Print: `Changed code files: $COUNT`

### Step 2.4: Announce loaded rules (ALWAYS — table UI)

Always render a rule table before any review work, so users can verify which shared / project / language / database rules will be evaluated. Prints on every path, including the 0-changed-files short-circuit below.

**Bash tool** — resolve `RULES_DIR` (first match wins):

```bash
for d in .claude/skills/_rules .agents/skills/_rules "$HOME/.claude/skills/_rules" "$HOME/.kimi/skills/_rules"; do [ -d "$d" ] && RULES_DIR="$d" && break; done  # sync:keep
```

**Bash tool** — pipe `applicable-rules.sh` into `render-rules-table.sh`:

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/scripts/applicable-rules.sh" ] || _sh="$HOME/.claude"
MODE=""; [ "$COUNT" = "0" ] && MODE="--no-changes"
bash "$_sh/scripts/applicable-rules.sh" "$PROJECT_ID" "$RULES_DIR" $CHANGED_FILES \
  | bash "$_sh/skills/new-review/scripts/render-rules-table.sh" "$PROJECT_ID" "$RULES_DIR" $MODE
```

Table is independent of whether review-code runs; must print even when `$COUNT == 0`.

**Then, in the same turn, re-emit the full table as plain markdown in your visible assistant reply** — copy the heading line and every row the Bash call produced verbatim. The terminal UI collapses long Bash output behind "ctrl+o to expand"; echoing as assistant text keeps it visible. Do not summarize, truncate, or paraphrase.

**IF `$COUNT == 0`** (no changed code files):
- **Bash tool**: `rm -f $DEV_DIR/review.md`
- Print: `Changed code files: 0 — review.md removed.`
- Print: `NEW-REVIEW COMPLETE`
- STOP (success).

### Step 2.5: Deterministic pre-gate — verify-rules script (direct Bash, not sub-skill)

**Bash tool**:

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/verify.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/verify.sh" $CHANGED_FILES
```

- Exit 0 → PASSED, continue to Step 3.
- Non-zero → FAILED, but do NOT short-circuit; continue to Step 3. `review-code` re-runs verify.py as its pre-pass and folds mechanical findings into output.

### Step 3: Delegate review to the `review-code` subagent (Task tool)

**Task tool**:
- `subagent_type`: `"review-code"`
- `description`: `"Review changed files"`
- `prompt`:
  ```
  Review these files for PROJECT_ID=$PROJECT_ID against the FULL applicable rule set.
  Files:
  $CHANGED_FILES

  Follow the review-code skill's workflow. Output findings in the standard format:
    ==== REVIEW FINDINGS ====
    ...
    ==== END FINDINGS ====
  OR, if clean:
    ==== NO ISSUES ====
  End with `REVIEW COMPLETE`.
  ```

Task tool returns subagent's full stdout as a single result message. Because this is Task tool (NOT Skill tool), parent turn continues into Step 4 without yielding.

### Step 4: Process subagent result and write `.dev/review.md`

Inspect Task result text:

**IF** contains `==== NO ISSUES ====`:
1. **Bash tool**: `rm -f $DEV_DIR/review.md`
2. Print: `Review passed — no issues. review.md deleted.`

**IF** contains `==== REVIEW FINDINGS ====`:
1. Extract block between `==== REVIEW FINDINGS ====` and `==== END FINDINGS ====` (inclusive of markers).
2. **Bash tool**: `mkdir -p $DEV_DIR`
3. **Write tool**: write to `$DEV_DIR/review.md`:
   ```
   # Review: $PROJECT_ID
   *Generated: <ISO-8601 UTC timestamp>*

   <the extracted findings block>
   ```
4. Print: `Review failed: $COUNT issue(s) written to .dev/review.md`

### Step 5: Verify final state and complete

**Bash tool**: `test -f $DEV_DIR/review.md && echo "EXISTS" || echo "GONE"`

- Issues expected, got `GONE` → retry Step 4 Write tool.
- No issues expected, got `EXISTS` → retry Step 4 rm.

Print: `NEW-REVIEW COMPLETE`

## Exit Criteria

- [ ] `DEV_DIR` resolved via resolve-dev.sh
- [ ] PROJECT_ID resolved
- [ ] Changed code files identified (excluding non-code files)
- [ ] Rules table printed AND re-emitted as visible assistant text (Step 2.4) on EVERY path — including the 0-files short-circuit
- [ ] `verify.py` invoked as direct Bash call (not sub-skill)
- [ ] `review-code` invoked via **Task tool** with `subagent_type: review-code` (NOT via Skill tool)
- [ ] Task result parsed; `.dev/review.md` written (findings) or deleted (no issues) in same turn
- [ ] Step 5 verification (`test -f`) run
- [ ] Printed `NEW-REVIEW COMPLETE`
