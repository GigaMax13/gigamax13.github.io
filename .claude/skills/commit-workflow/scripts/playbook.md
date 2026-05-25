# commit-workflow playbook


# commit-workflow

Create conventional commits for task workflow. REQUIRES explicit user approval. Called by `new-commit` in workflow mode, after `mark-task-done`, or at end of development workflow.

## Input Modes

```bash
/commit-workflow                                       # Standard - includes issue ref if found
/commit-workflow no-linear                             # Skip issue reference
/commit-workflow no-linear: make a single commit       # No refs + instructions
/commit-workflow linear:CURB-10                        # Specific Linear issue
/commit-workflow linear:CURB-10: make a single commit  # Specific issue + instructions
/commit-workflow make a single commit                  # Instructions only (uses task file ref)
```

## Load Rules

Resolve rules directory (first match: `.claude/skills/_rules/`, `.claude/skills/_rules/`, `~/.claude/skills/_rules/`). Read `$RULES_DIR/commit.md`, then project rules (`CLAUDE.md` or `CLAUDE.md`, first found).

```bash
if [ -d ".linear" ]; then echo "Linear enabled"; fi
grep "^team_id" .linear.toml 2>/dev/null | cut -d'"' -f2
```

## Finding Issue Reference

```bash
DEV_DIR=$(_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh")
```

Check task file in `$DEV_DIR/**/tasks/`:
1. Read `state.md` for most recent completed task OR check `$DEV_DIR/current-task`
2. Extract: `Linear: TEAM-XXX`, `Refs: TEAM-XXX`, or `GitHub: #XXX`
3. **Subtasks** (`-NNN.md` suffix): use parent task's issue ID
4. Skip if `no-linear` mode

```bash
INPUT=$(cat)
NO_LINEAR=false
SPECIFIC_ISSUE=""
INSTRUCTIONS=""

if echo "$INPUT" | grep -q "^no-linear"; then
  NO_LINEAR=true
  INSTRUCTIONS=$(echo "$INPUT" | grep "^no-linear:" | sed 's/^no-linear://')
elif echo "$INPUT" | grep -qE '^linear:[A-Z]+-[0-9]+'; then
  SPECIFIC_ISSUE=$(echo "$INPUT" | grep -oE '^linear:[A-Z]+-[0-9]+' | sed 's/linear://')
  INSTRUCTIONS=$(echo "$INPUT" | sed "s/^linear:$SPECIFIC_ISSUE://")
else
  INSTRUCTIONS="$INPUT"
fi

get_issue_id() {
  local task_file="$1"
  local filename=$(basename "$task_file")

  [ "$NO_LINEAR" = true ] && return 1
  [ -n "$SPECIFIC_ISSUE" ] && echo "$SPECIFIC_ISSUE" && return 0

  if grep -iE "Linear:\s*[A-Z]+-[0-9]+" "$task_file" > /dev/null 2>&1; then
    grep -iE "Linear:\s*[A-Z]+-[0-9]+" "$task_file" | head -1 | grep -oE '[A-Z]+-[0-9]+'
    return 0
  fi

  if echo "$filename" | grep -E '^[0-9]+-.*-[0-9]{3}\.md$' > /dev/null; then
    local parent_file="$(dirname "$task_file")/$(echo "$filename" | sed -E 's/-[0-9]{3}\.md$/.md/')"
    if [ -f "$parent_file" ]; then
      grep -iE "Linear:\s*[A-Z]+-[0-9]+" "$parent_file" | head -1 | grep -oE '[A-Z]+-[0-9]+'
      return 0
    fi
  fi
  return 1
}
```

## Commit Format

**Subject:** `<type>[scope]: <description>` — max 72 chars, imperative mood, no capital, no period
**Footer (if issue):** `Refs: TEAM-XXX` — subtasks use parent issue ID

## Process

```bash
UNTRACKED=$(git ls-files --others --exclude-standard)
[ -n "$UNTRACKED" ] && echo "Untracked files to include: $UNTRACKED"

ignored=$(git ls-files --others --ignored --exclude-standard)
[ -n "$ignored" ] && echo "Warning: Ignored files: $ignored"

git add .

if [ -n "$ISSUE_ID" ]; then
  git commit -m "type(scope): description" -m "Refs: $ISSUE_ID"
else
  git commit -m "type(scope): description"
fi
```

## Examples

```
feat(manuscripts): add create server action

Refs: CURB-10
```

```
refactor(db): extract query helpers
```

## Rules

1. Use `git add .` not `git add -A` (respects .gitignore)
2. No bullet lists in commit body
3. Include `Refs: TEAM-XXX` if available (unless `no-linear` mode); subtasks use parent issue ID
4. Apply any provided instructions
5. NEVER add co-authors, NEVER push, NEVER delete issues
6. English only

## Exit Criteria

- [ ] Commit rules loaded (`$RULES_DIR/commit.md`)
- [ ] Project rules read (if exists)
- [ ] All changes staged
- [ ] Subject follows conventional format
- [ ] Instructions applied if provided
- [ ] **User explicitly approved git commands**
- [ ] Issue reference included if available (parent for subtasks), OR skipped in `no-linear` mode
- [ ] No co-authors
- [ ] Commit created (local only)
