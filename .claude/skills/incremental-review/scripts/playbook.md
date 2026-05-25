
# incremental-review playbook

## Original heading: incremental-review

## Usage

```
/incremental-review                              # All files (batched)
/incremental-review this branch                  # Branch diff vs main/master
/incremental-review PR 42                        # PR files
/incremental-review in apps/web                  # Folder filter
/incremental-review this branch in apps/web      # Branch + folder
/incremental-review PR 123 in packages/shared    # PR + folder
BATCH_SIZE=50; /incremental-review               # Custom batch size (all-files only)
```

## Rules

1. **NEVER STOP BETWEEN STEPS** — no user output until step 5 completes.
2. Sub-skill output is intermediate; only valid final output is the step 5c status line.
3. **MUST write `$DEV_DIR/review.md`** before any user output — the file IS the deliverable.
4. Findings exist but `$DEV_DIR/review.md` not written = FAILED.

## Workflow

### 1. Setup

```bash
AGENTS_FILE="./CLAUDE.md"
[ -f "$AGENTS_FILE" ] || AGENTS_FILE="./CLAUDE.md"
DEV_DIR=$(_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh")
REVIEW_FILE="$DEV_DIR/review.md"
BATCH_SIZE="${BATCH_SIZE:-50}"

[ -f "$AGENTS_FILE" ] || exit 1
AGENTS_CONTENT=$(cat "$AGENTS_FILE")

PROJECT_ID=$(echo "$AGENTS_CONTENT" | grep -o 'PROJECT_ID="[^"]*"' | head -1 | sed 's/PROJECT_ID="//;s/"$//')
[ -z "$PROJECT_ID" ] && PROJECT_ID=$(grep -m1 '^id:' "$AGENTS_FILE" | sed 's/^id: *//' | tr -d '"')
[ -z "$PROJECT_ID" ] && PROJECT_ID=$(grep -m1 '^# ' "$AGENTS_FILE" | sed 's/^# *//')
[ -z "$PROJECT_ID" ] && exit 1

RAW_INPUT=$(cat | xargs)
```

### 2. Parse Scope

Deterministic regex — no LLM interpretation.

```bash
SCOPE="all"
FOLDER_FILTER=""
INPUT="$RAW_INPUT"

if echo "$INPUT" | grep -qiE '\bin\s+\S+\s*$'; then
    FOLDER_FILTER=$(echo "$INPUT" | sed -E 's/.*\bin\s+(\S+)\s*$/\1/')
    INPUT=$(echo "$INPUT" | sed -E 's/\s*\bin\s+\S+\s*$//')
fi

if echo "$INPUT" | grep -qiE '(pr|pull\s*request)\s*#?\s*[0-9]+'; then
    PR_NUMBER=$(echo "$INPUT" | grep -oiE '(pr|pull\s*request)\s*#?\s*([0-9]+)' | grep -oE '[0-9]+')
    SCOPE="pr"
fi

if [ "$SCOPE" = "all" ] && echo "$INPUT" | grep -qiE '(this|current)\s+branch|branch\s+\S+'; then
    SCOPE="branch"
fi

if [ "$SCOPE" = "all" ] && [ -n "$INPUT" ] && [ -d "$INPUT" ]; then
    FOLDER_FILTER="$INPUT"
fi
# incremental-review playbook

## Original heading: Fallback: empty or unrecognized -> "all"
```

Output: `Incremental Review — Project: $PROJECT_ID, Scope: $SCOPE, Folder: $FOLDER_FILTER (or "none")`

### 3. Resolve File List

Never scan `.vscode/`, `.idea/`, or editor config directories.

```bash
EXCLUDE='(node_modules/|vendor/|\.venv/|venv/|__pycache__/|\.pytest_cache/|target/|dist/|build/|\.git/|\.idea/|\.vscode/)'
EXTS='\.(py|js|ts|jsx|tsx|go|rs|java|rb|php|c|cpp|h|hpp|swift|kt|scala|sh|bash|zsh|fish|ps1|sql|prisma|dockerfile|makefile|cmake)$'

case "$SCOPE" in
    all)
        if [ -d ".git" ]; then
            ALL_FILES=$(git ls-files --cached --others --exclude-standard | grep -E "$EXTS" | grep -vE "$EXCLUDE")
        else
            ALL_FILES=$(find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.go" -o -name "*.rs" -o -name "*.prisma" \) | grep -vE "$EXCLUDE")
        fi
        ;;
    branch)
        DEFAULT_BRANCH=$(git rev-parse --verify main 2>/dev/null && echo "main" || echo "master")
        ALL_FILES=$(git diff "${DEFAULT_BRANCH}...HEAD" --name-only 2>/dev/null | grep -E "$EXTS" | grep -vE "$EXCLUDE")
        ;;
    pr)
        if ! command -v gh &>/dev/null; then echo "Error: gh CLI required for PR scope."; exit 1; fi
        ALL_FILES=$(gh pr diff "$PR_NUMBER" --name-only 2>/dev/null | grep -E "$EXTS" | grep -vE "$EXCLUDE")
        ;;
esac

[ -n "$FOLDER_FILTER" ] && ALL_FILES=$(echo "$ALL_FILES" | grep -E "^${FOLDER_FILTER}/")

FILE_COUNT=$(echo "$ALL_FILES" | grep -c '^' || echo 0)
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No code files in scope."
    [ -f "$REVIEW_FILE" ] && rm "$REVIEW_FILE"
    exit 0
fi
```

Output: `Files in scope: $FILE_COUNT`

### 4. Resolve Batch

```bash
if [ -f "$REVIEW_FILE" ]; then
    LAST_BATCH=$(grep -m1 '^<!-- batch: ' "$REVIEW_FILE" | sed 's/<!-- batch: \([0-9]*\).*/\1/')
    TOTAL_FILES=$(grep -m1 '^<!-- total_files: ' "$REVIEW_FILE" | sed 's/<!-- total_files: \([0-9]*\).*/\1/')
    FILES_REVIEWED=$(grep -m1 '^<!-- files_reviewed: ' "$REVIEW_FILE" | sed 's/<!-- files_reviewed: \([0-9]*\).*/\1/')
else
    LAST_BATCH=0; TOTAL_FILES=$FILE_COUNT; FILES_REVIEWED=0
fi

BATCH_NUM=$((LAST_BATCH + 1))
BATCH_FILES=$(echo "$ALL_FILES" | tail -n +$((FILES_REVIEWED + 1)) | head -n "$BATCH_SIZE")
BATCH_COUNT=$(echo "$BATCH_FILES" | grep -c '^')
[ "$BATCH_COUNT" -eq 0 ] && exit 0
NEW_FILES_REVIEWED=$((FILES_REVIEWED + BATCH_COUNT))
```

Output: `Batch $BATCH_NUM: $BATCH_COUNT files ($((FILES_REVIEWED + 1))-$NEW_FILES_REVIEWED of $FILE_COUNT)`

### 5. Execute Review and Write Report

#### 5a. Call Review Skill

`/review-code $PROJECT_ID, $BATCH_FILES`

Capture FINDINGS. Check for `==== NO ISSUES ====` to determine HAS_FINDINGS.

#### 5b. Write .dev/review.md (MANDATORY)

- No findings + no prior review.md: no file created
- No findings + prior review.md: update metadata only
- Findings exist:

```bash
mkdir -p "$DEV_DIR"
SCOPE_DESC="$SCOPE"
[ -n "$FOLDER_FILTER" ] && SCOPE_DESC="$SCOPE_DESC in $FOLDER_FILTER"

if [ ! -f "$REVIEW_FILE" ]; then
    echo "# Incremental Review: $PROJECT_ID ($SCOPE_DESC)" > "$REVIEW_FILE"
    echo "<!-- batch: 0 -->" >> "$REVIEW_FILE"
    echo "<!-- total_files: $TOTAL_FILES -->" >> "$REVIEW_FILE"
    echo "<!-- files_reviewed: 0 -->" >> "$REVIEW_FILE"
    echo "<!-- last_updated: $(date -u '+%Y-%m-%dT%H:%M:%SZ') -->" >> "$REVIEW_FILE"
fi

echo "### Batch $BATCH_NUM ($(date '+%Y-%m-%d %H:%M:%S'))" >> "$REVIEW_FILE"
# incremental-review playbook

## Original heading: Append findings between ==== markers

sed -i.bak \
    -e "s/<!-- batch: [0-9]* -->/<!-- batch: $BATCH_NUM -->/" \
    -e "s/<!-- total_files: [0-9]* -->/<!-- total_files: $TOTAL_FILES -->/" \
    -e "s/<!-- files_reviewed: [0-9]* -->/<!-- files_reviewed: $NEW_FILES_REVIEWED -->/" \
    -e "s/<!-- last_updated: [^>]* -->/<!-- last_updated: $(date -u '+%Y-%m-%dT%H:%M:%SZ') -->/" \
    "$REVIEW_FILE"
rm -f "${REVIEW_FILE}.bak"
```

#### 5c. Output Status

`Progress: $NEW_FILES_REVIEWED/$FILE_COUNT — $REMAINING remaining` (or `All files reviewed!`).
If any batch had findings: `Review failed: $ISSUE_COUNT issue(s)` — Exit 1.

## Exit Criteria

- [ ] **review.md written to disk** (findings + metadata updated) — PRIMARY DELIVERABLE
- [ ] PROJECT_ID auto-detected
- [ ] Scope parsed (all/branch/pr + optional folder filter)
- [ ] File list resolved via git per scope
- [ ] Folder filter applied as post-filter
- [ ] Batch resolved (up to BATCH_SIZE files per invocation)
- [ ] review-code called with PROJECT_ID and batch files
- [ ] No report file when no issues found
- [ ] Status line output AFTER file write

After status line, print: `INCREMENTAL-REVIEW COMPLETE`
