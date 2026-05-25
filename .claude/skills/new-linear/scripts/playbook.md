# new-linear playbook


# new-linear

**MANDATORY when `.linear/` exists** (unless `linear:none`). Run before code changes.

**Constraints:** Never skip if `.linear/` exists; never create issues for subtasks; never delete issues; silently skip if already correct.

## Input

```bash
/new-linear                    # Auto-detect/create
/new-linear linear:CURB-50     # Use specific ID
```

When input starts with `linear:`, extract ID and use directly.

## Prerequisites

Read project rules (`CLAUDE.md`, first found).

- Linear CLI authenticated (`linear auth login`)
- Task file at `$DEV_DIR/[phase]/tasks/[task-name].md` (resolve `DEV_DIR` via resolve-dev.sh first)
- `.linear/` folder exists

## Execution

### Step 0: Resolve DEV_DIR and Check Input

```bash
DEV_DIR=$(_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh")

if [ -n "$INPUT" ]; then
  if echo "$INPUT" | grep -qE '^linear:[A-Z]+-[0-9]+$'; then
    ISSUE_ID=$(echo "$INPUT" | sed 's/^linear://')
    ISSUE_JSON=$(linear issue view "$ISSUE_ID" --json 2>/dev/null)
    [ -z "$ISSUE_JSON" ] && echo "ERROR: Issue $ISSUE_ID not found" && exit 1

    CURRENT_STATE=$(echo "$ISSUE_JSON" | jq -r '.state.name' 2>/dev/null || echo "unknown")
    [ "$CURRENT_STATE" != "In Progress" ] && linear issue update "$ISSUE_ID" -s "In Progress"

    TASK_FILE=$(find $DEV_DIR -type f -name "*.md" -path "*/tasks/*" | head -1)
    [ -n "$TASK_FILE" ] && ! grep -q "Linear: $ISSUE_ID" "$TASK_FILE" && echo -e "\nLinear: $ISSUE_ID" >> "$TASK_FILE"

    echo "Linear issue $ISSUE_ID ready (state: In Progress)"
    exit 0
  fi
fi
```

### Step 1: Verify Linear Configuration

```bash
if [ ! -d ".linear" ]; then
  echo "Linear not configured - skipping"
  exit 0
fi
```

### Step 2: Find and Read Task File

```bash
find $DEV_DIR -type f -name "*[task-name]*.md" -path "*/tasks/*"
```

Exit if no match or multiple matches. Extract: **Title** (H1, remove "Task: " prefix), **What** (1-2 sentences), **Linear ID** (`Linear: TEAM-XXX`).

### Step 3: Detect and Handle Subtasks

Subtask pattern: `NN-task-name-NNN.md`

```bash
FILENAME=$(basename "[task-file-path]")
if echo "$FILENAME" | grep -qE '^[0-9]+-.*-[0-9]{3}\.md$'; then
  if grep -iE "Linear:\s*[A-Z]+-[0-9]+" "[task-file-path]" > /dev/null; then
    PARENT_ID=$(grep -iE "Linear:\s*[A-Z]+-[0-9]+" "[task-file-path]" | head -1 | grep -oE '[A-Z]+-[0-9]+')
  else
    PARENT_FILENAME=$(echo "$FILENAME" | sed -E 's/-[0-9]{3}\.md$/.md/')
    PARENT_FILE_PATH="$(dirname "[task-file-path]")/$PARENT_FILENAME"
    [ ! -f "$PARENT_FILE_PATH" ] && echo "ERROR: Parent file not found: $PARENT_FILENAME" && exit 1
    ! grep -iE "Linear:\s*[A-Z]+-[0-9]+" "$PARENT_FILE_PATH" > /dev/null && echo "ERROR: Parent missing Linear reference" && exit 1
    PARENT_ID=$(grep -iE "Linear:\s*[A-Z]+-[0-9]+" "$PARENT_FILE_PATH" | head -1 | grep -oE '[A-Z]+-[0-9]+')
    echo -e "\nLinear: $PARENT_ID" >> "[task-file-path]"
  fi

  PARENT_STATE=$(linear issue view "$PARENT_ID" --json 2>/dev/null | jq -r '.state.name' 2>/dev/null || echo "unknown")
  [ "$PARENT_STATE" = "In Progress" ] && echo "Parent $PARENT_ID already In Progress" && exit 0
  echo "Will update parent $PARENT_ID to In Progress"
fi
```

### Step 4: Check Linear State

**If task has `Linear: TEAM-XXX`:**

```bash
ISSUE_JSON=$(linear issue view TEAM-XXX --json 2>/dev/null)
CURRENT_STATE=$(echo "$ISSUE_JSON" | jq -r '.state.name' 2>/dev/null || echo "unknown")
CURRENT_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title' 2>/dev/null || echo "")

NEEDS_UPDATE=false
[ "$CURRENT_STATE" != "In Progress" ] && NEEDS_UPDATE=true
[ "$CURRENT_TITLE" != "[Task Title]" ] && NEEDS_UPDATE=true

[ "$NEEDS_UPDATE" = "false" ] && echo "Linear issue TEAM-XXX already correct" && exit 0
```

**If no Linear ID:**

```bash
EXISTING=$(linear issue list --all-states -A 2>/dev/null | grep -i "[task title]" || true)

if [ -n "$EXISTING" ]; then
  EXISTING_ID=$(echo "$EXISTING" | grep -oE '[A-Z]+-[0-9]+' | head -1)
  EXISTING_STATE=$(linear issue view "$EXISTING_ID" --json 2>/dev/null | jq -r '.state.name' 2>/dev/null || echo "unknown")

  if [ "$EXISTING_STATE" = "In Progress" ]; then
    echo -e "\nLinear: $EXISTING_ID" >> "[task-file-path]"
    echo "Existing issue $EXISTING_ID already In Progress - linked"
    exit 0
  fi
else
  echo "No existing issue found - need to create new"
fi
```

### Step 5: Confirm Changes

**STOP — WAIT FOR EXPLICIT "yes"**

```
LINEAR ISSUE SYNC - CONFIRMATION REQUIRED
Task: [Task Title]
Action: [Create new / Update status / Update details]
Proceed? (yes/no):
```

### Step 6: Execute Changes

**Create:** `linear issue create -t "[Task Name]" -d "[Brief description]" -a self -s "In Progress"`

**Update:**
```bash
linear issue update TEAM-XXX -s "In Progress"
linear issue update TEAM-XXX -t "[Task Name]" -d "[Brief description]"
```

**Subtask:** `linear issue update "$PARENT_ID" -s "In Progress"`

### Step 7: Repurpose Placeholder (With Confirmation)

```bash
linear issue list --all-states -A | grep "Unused - Repurpose Later"
# If found and confirmed:
linear issue update TEAM-XXX -t "[Task Name]" -d "[Brief description]" -s "In Progress"
```

### Step 8: Save Linear Reference

```bash
if ! grep -q "Linear: TEAM-XXX" "[task-file-path]"; then
  echo -e "\nLinear: TEAM-XXX" >> "[task-file-path]"
fi
```

### Step 9: Verify

```bash
STATE=$(linear issue view TEAM-XXX --json 2>/dev/null | jq -r '.state.name' 2>/dev/null || echo "unknown")
[ "$STATE" != "In Progress" ] && echo "ERROR: Issue not In Progress. Current: $STATE" && exit 1
```

Report: Issue ID, URL, state, and parent (subtasks only).

## Exit Criteria

- [x] Project rules read (if exists)
- [x] Linear configuration checked; task file found
- [x] Current state checked; silently skipped if already correct
- [x] User confirmation received IF changes needed
- [x] Issue exists/created; status "In Progress"
- [x] Linear ID saved (or subtask references parent)
- [x] Issue URL reported
