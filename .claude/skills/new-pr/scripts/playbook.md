# new-pr playbook


# new-pr

Create PR with comprehensive description and ALL issue references from commits.

## Input

```bash
/new-pr                # Default base branch
/new-pr main           # Explicit base
/new-pr main, draft    # Draft PR
```

**Format:** `[base_branch[, options...]]`
- `base_branch`: Target branch (default: auto-detected `main` or `master`)
- `draft`: Create as draft PR

## Process

### 0. Load Rules
Resolve rules directory (first match: `.claude/skills/_rules/`, `.claude/skills/_rules/`, `~/.claude/skills/_rules/`). Read `$RULES_DIR/pr.md` and project rules (`CLAUDE.md`, first found).

### 1. Parse Input and Get Branch Info

```bash
INPUT=$(cat)
BASE_BRANCH=$(echo "$INPUT" | cut -d',' -f1 | xargs)
OPTIONS=$(echo "$INPUT" | cut -d',' -f2- | xargs)

if [ -z "$BASE_BRANCH" ]; then
    git show-ref --verify --quiet refs/remotes/origin/main && BASE_BRANCH="main" || BASE_BRANCH="master"
fi

DRAFT=false
echo "$OPTIONS" | grep -qi "draft" && DRAFT=true

git branch --show-current
```

### 2. Get Git User
```bash
git config user.name
```
Store as PR assignee.

### 3. Get Commits
```bash
git log main..HEAD --pretty=format:"%s" 2>/dev/null || \
git log master..HEAD --pretty=format:"%s"
```

### 4. Extract ALL Issue IDs
```bash
git log main..HEAD --pretty=format:"%s%n%b" 2>/dev/null | grep -oE "[A-Z]+-[0-9]+|#[0-9]+" | sort -u
```

Capture: `Refs:`/`Fixes:`/`Closes:` prefixes, `(TEAM-XXX)` in subjects, `#XXX` GitHub issues, any `TEAM-XXX` in body.

### 5. Build Title

**Priority 1 — Branch Name:** If branch follows `feat/`, `fix/`, etc., extract part after prefix, convert kebab-case to Title Case, prefix with type. Example: `feat/mvp-implementation` -> `Feat: MVP Implementation`.

**Priority 2 — First Commit Subject:** Remove conventional prefix, capitalize.

### 6. Build Description

```markdown
## Summary
[2-3 sentences on overall purpose/impact from all commits]

## Key Changes
- **[Category]**: [Brief description]

## Issue References
Refs: TEAM-XXX, TEAM-YYY, TEAM-ZZZ [ALL issues, comma-separated]
```

Categories: Database Schema, Auth, API/Server Actions, UI Components, CRUD, Testing, Refactoring, Config/DevEx.

### 7. Show PR Preview

```
PR Preview

| Property    | Value                          |
|-------------|--------------------------------|
| **Branch**  | `branch-name`                  |
| **Base**    | `main`                         |
| **Commits** | N commits                      |
| **Assignee**| `@me` (current git user)       |

PR Title: Title Here
PR Description: [Full description]
Issue References: TEAM-XXX (N commits), ...
```

### 8. Ask for Approval

**NEVER PROCEED WITHOUT EXPLICIT APPROVAL.**

### 9. Create PR After Approval

```bash
gh pr create --title "Title" --body "Description" --assignee "@me"
```

### 10. Verify PR is Live

```bash
sleep 3
gh pr view <number> --json state,url --jq '"PR #\(.url | split("/") | last) is \(.state): \(.url)"'
```

Retry once after 5s if not found. Report URL only after confirming live.

## Exit Criteria

- [ ] PR rules and project rules loaded (if exist)
- [ ] ALL issue references extracted (not just first)
- [ ] Title derived from branch name or commits
- [ ] PR preview displayed with assignee
- [ ] User explicitly approved
- [ ] PR created via `gh pr create --assignee`
- [ ] PR verified live via `gh pr view` (state: OPEN), URL reported
