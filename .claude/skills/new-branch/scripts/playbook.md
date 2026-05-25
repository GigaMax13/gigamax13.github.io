# new-branch playbook


# new-branch

Create branch with optional Linear integration. Git commands require explicit user approval.

## Input

```bash
/new-branch feature, Short description
/new-branch feature, Short description, CURB-123
```

**Format:** `type, title[, issue_id]`
- `type`: feature|bug|refactor|test|docs|chore (default: feature)
- `title`: branch name + Linear title
- `issue_id`: existing Linear issue (skips creation)

## Steps

### 0. Read project rules
Check `CLAUDE.md`, use first found.

### 1. Parse Input

```bash
INPUT=$(cat)
TYPE=$(echo "$INPUT" | cut -d',' -f1 | xargs)
TITLE=$(echo "$INPUT" | cut -d',' -f2 | xargs)
ISSUE_ID=$(echo "$INPUT" | cut -d',' -f3 | xargs)

[ -z "$TYPE" ] && TYPE="feature"
[ -z "$TITLE" ] && echo "Error: title required" && exit 1
```

### 2. Check Linear

```bash
[ -d ".linear" ] && LINEAR_ENABLED=true || LINEAR_ENABLED=false
```

### 3. Create Linear Issue (if enabled and no issue_id)

Title truncated to 50 chars. Extract issue ID from output. Continue on failure with warning.

```bash
TEAM=$(grep "team_id" .linear.toml 2>/dev/null | cut -d'"' -f2 || echo "CURB")
linear issue create -t "$SHORT_TITLE" -d "$DESCRIPTION" -a self -s "In Progress" --team "$TEAM"
```

### 4. Create Branch

```bash
DEFAULT=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's|origin/||' || echo "main")
git checkout "$DEFAULT" && git pull origin "$DEFAULT"
```

**With Linear:**
```bash
SHORT_NAME=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' ' ' | sed 's/^ *//;s/ *$//' | cut -d' ' -f1-2 | tr ' ' '-')
[ ${#SHORT_NAME} -gt 30 ] && SHORT_NAME=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' ' ' | sed 's/^ *//;s/ *$//' | cut -d' ' -f1 | tr ' ' '-')
BRANCH_NAME="${type}/${ISSUE_ID}-${SHORT_NAME}"
```

**Without Linear:**
```bash
BRANCH_NAME="${type}/$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' ' ' | sed 's/^ *//;s/ *$//' | cut -d' ' -f1-2 | tr ' ' '-')"
[ ${#BRANCH_NAME} -gt 40 ] && BRANCH_NAME="${type}/$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' ' ' | sed 's/^ *//;s/ *$//' | cut -d' ' -f1 | tr ' ' '-')"
```

```bash
git checkout -b "$BRANCH_NAME"
```

Exit if branch exists or git fails.

## Examples

```bash
$ /new-branch bug, Fix child list reordering save error
# Created: CURB-45, branch: bug/CURB-45-child-list

$ /new-branch bug, Fix login redirect, CURB-12
# Using CURB-12, branch: bug/CURB-12-login-redirect

$ /new-branch bug, Fix login redirect  # (no Linear)
# branch: bug/login-redirect
```

## Exit Criteria

- [ ] Project rules read (if exists)
- [x] Input parsed, title present
- [x] **User explicitly approved git commands**
- [x] Linear issue created (if configured and no issue_id)
- [x] Branch created: `{type}/{ISSUE_ID}-{max-2-words}` (Linear) or `{type}/{max-2-words}` (no Linear)
- [x] Branch auto-linked to Linear via issue ID in name
- [x] Results reported
