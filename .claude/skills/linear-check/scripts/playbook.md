# linear-check playbook


# linear-check

Verify uncommitted changes against Linear issue requirements. Creates `$DEV_DIR/review.md` with ONLY gaps; deletes it if all requirements met.

## Input

```bash
/linear-check TEAM-52
```

## Workflow

### Step 0: Resolve dev directory

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh"
```

Capture output as `DEV_DIR` for all `.dev/` operations.

### Step 1: Parse Input

```bash
ISSUE_ID=$(echo "$INPUT" | xargs)
[[ ! "$ISSUE_ID" =~ ^[A-Z]+-[0-9]+$ ]] && echo "Error: Input must be a Linear issue ID (e.g., TEAM-52)" && exit 1
```

### Step 2: Fetch Linear Issue

```bash
ISSUE_JSON=$(linear issue view "$ISSUE_ID" --json 2>/dev/null)
[ -z "$ISSUE_JSON" ] || [ "$ISSUE_JSON" = "null" ] && echo "Error: Could not fetch issue $ISSUE_ID" && exit 1
TITLE=$(echo "$ISSUE_JSON" | jq -r '.title // empty')
DESCRIPTION=$(echo "$ISSUE_JSON" | jq -r '.description // empty')
[ -z "$TITLE" ] && echo "Error: Could not retrieve issue title" && exit 1
```

### Step 3: Get Uncommitted Changes

```bash
FULL_DIFF="$(git diff --staged)$(git diff HEAD)"
UNIQUE_FILES=$(git diff --name-only HEAD; git diff --name-only --staged | sort -u)
```

### Step 4: Extract Requirements

```bash
CHECKBOXES=$(echo "$DESCRIPTION" | grep -E '^\s*- \[.?\]' | sed 's/^\s*- \[.\?\]\s*//')
BULLETS=$(echo "$DESCRIPTION" | grep -E '^\s*[-*]\s' | sed 's/^\s*[-*]\s*//')
NUMBERED=$(echo "$DESCRIPTION" | grep -E '^\s*\d+\.' | sed 's/^\s*[0-9]*\.\s*//')
ALL_REQUIREMENTS=$(echo -e "${CHECKBOXES}\n${BULLETS}\n${NUMBERED}" | grep -v '^$' | sort -u)
```

### Step 5: Analyze Coverage

Per requirement, check keywords in changed files, tests if mentioned, docs if mentioned. Uncertain = NOT covered.

### Step 6: Generate review.md

**All addressed:**
```bash
rm -f "$DEV_DIR/review.md"
echo "YES - All topics from $ISSUE_ID are covered by current changes"
```

**Gaps found:**
```bash
mkdir -p "$DEV_DIR"
cat > "$DEV_DIR/review.md" << 'REVIEWEOF'
# Review: $ISSUE_ID - $TITLE

## Missing Requirements

### Not Implemented
- [ ] Requirement that is missing

### Missing Tests
- [ ] Tests for feature X

### Missing Documentation
- [ ] Documentation for feature Y

## Required Changes

1. Implement [specific missing requirement]
2. Add tests for [specific feature]

---
*Generated from Linear issue $ISSUE_ID*
REVIEWEOF
echo "NO - $(grep -c '^- \[ \]' "$DEV_DIR/review.md" || echo '0') items missing"
echo "   See: $DEV_DIR/review.md for details"
exit 1
```

**review.md rules:** ONLY missing items; `- [ ]` checkboxes; grouped by category; delete if all covered; NEVER create a success report.

## Rules

- **NO CODE CHANGES** — only modify review.md
- **NO LINEAR UPDATES** — never change issue state/comments
- Conservative: uncertain = missing

## Exit Criteria

- [ ] Linear issue ID validated and fetched
- [ ] Uncommitted changes retrieved (git diff)
- [ ] Requirements extracted and analyzed
- [ ] YES + review.md deleted (all covered)
- [ ] NO + review.md created with missing items (gaps found)
- [ ] NO code changes made
- [ ] NO Linear updates made
