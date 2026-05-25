# verify-task playbook


# verify-task

## Prerequisites

Read project rules (`CLAUDE.md` or `CLAUDE.md`, first found).

## Usage

```bash
/verify-task CURB-123                              # Linear mode
/verify-task feature, Implement user auth with JWT  # Spec mode
```

**Input (one of):**
1. **Linear issue ID** (e.g., `CURB-123`) — fetches issue details
2. **Task spec** — `type, title` (type defaults to `feature`)

## Workflow

### Step 1: Parse Input

```bash
INPUT=$(cat)

if [[ "$INPUT" =~ ^[A-Z]+-[0-9]+$ ]]; then
    MODE="linear"
    ISSUE_ID="$INPUT"
elif echo "$INPUT" | grep -q ','; then
    MODE="spec"
    TYPE=$(echo "$INPUT" | cut -d',' -f1 | xargs)
    TITLE=$(echo "$INPUT" | cut -d',' -f2- | xargs)
    [ -z "$TYPE" ] && TYPE="feature"
else
    echo "Error: Provide either a Linear issue ID (TEAM-XXX) or a task spec: type, title"
    exit 1
fi
```

### Step 2: Fetch Task Details

**Linear Mode:**
```bash
ISSUE_JSON=$(linear issue view "$ISSUE_ID" --json 2>/dev/null)
TITLE=$(echo "$ISSUE_JSON" | jq -r '.title' 2>/dev/null)
DESCRIPTION=$(echo "$ISSUE_JSON" | jq -r '.description' 2>/dev/null)

[ -z "$TITLE" ] && echo "Error: Could not fetch issue $ISSUE_ID" && exit 1
echo "Verifying: [$ISSUE_ID] $TITLE"
```

**Spec Mode:**
```bash
echo "Verifying: [$TYPE] $TITLE"
```

### Step 3: Analyze Implementation

```bash
KEYWORDS=$(echo "$TITLE" | tr ' ' '\n' | grep -v 'the\|a\|an\|and\|or\|with' | head -5)

for keyword in $KEYWORDS; do
    find . -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" \) \
        -not -path "./.git/*" -not -path "./node_modules/*" \
        | xargs grep -l "$keyword" 2>/dev/null | head -10
done
```

### Step 4: Verify Requirements

```bash
echo "=== VERIFICATION CHECKLIST ==="

TEST_FILES=$(find . -type f \( -name "*test*" -o -name "*spec*" \) -not -path "./.git/*" | head -10)
[ -n "$TEST_FILES" ] && echo "Test files found" || echo "No test files found"

grep -r "interface\|type\|struct\|class" --include="*.ts" --include="*.py" --include="*.go" . 2>/dev/null | head -5 > /dev/null && echo "Type definitions found" || echo "No type definitions found"
```

### Step 5: Generate Report

```bash
echo "=== VERIFICATION REPORT ==="
echo "Task: $TITLE"
[ -n "$ISSUE_ID" ] && echo "Issue: $ISSUE_ID"
echo "Mode: $MODE"
echo ""
echo "Next Steps:"
echo "- Review findings above"
echo "- Address any issues"
echo "- Mark task complete when all criteria pass"
```

## Exit Criteria

- [ ] Project rules read (if exists)
- [ ] Input parsed (issue ID OR spec)
- [ ] Task details fetched or extracted
- [ ] Implementation analyzed
- [ ] Requirements verified
- [ ] Report generated
