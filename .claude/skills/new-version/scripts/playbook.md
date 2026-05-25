# new-version playbook


# new-version

Bump version across project files. Does NOT commit or tag.

## Usage

```
/new-version          # Auto-detect from git history
/new-version patch
/new-version minor
/new-version 1.2.3
```

Bump type (`major`, `minor`, `patch`) or explicit `X.Y.Z`. Omitted: auto-detect from conventional commits since last version tag.

## Workflow

### 1. Read Project Rules

```bash
AGENTS_FILE="./CLAUDE.md"
[ -f "$AGENTS_FILE" ] || AGENTS_FILE="./CLAUDE.md"
[ -f "$AGENTS_FILE" ] || { echo "No CLAUDE.md found"; exit 1; }
```

### 2. Read and Validate Current Version

```bash
CURRENT=$(cat VERSION | tr -d '[:space:]')
[[ "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid semver in VERSION: $CURRENT"; exit 1; }
```

### 3. Auto-detect Bump Type (if no input)

```bash
# Base: tag for current version, latest v* tag, or root commit
if git rev-parse "v$CURRENT" >/dev/null 2>&1; then
  BASE="v$CURRENT"
elif BASE=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null); then
  true
else
  BASE=$(git rev-list --max-parents=0 HEAD)
fi

SUBJECTS=$(git log "$BASE..HEAD" --pretty=format:"%s" 2>/dev/null)
BODIES=$(git log "$BASE..HEAD" --pretty=format:"%b" 2>/dev/null)
UNCOMMITTED=$(git diff --stat HEAD 2>/dev/null)
```

If `SUBJECTS` and `UNCOMMITTED` both empty: print "No commits or changes since $BASE — nothing to bump." and exit.

```bash
BUMP="patch"
if echo "$SUBJECTS" | grep -qE '^[a-z]+(\(.*\))?!:'; then
  BUMP="major"
elif echo "$BODIES" | grep -qE '^BREAKING CHANGE:'; then
  BUMP="major"
elif echo "$SUBJECTS" | grep -qE '^feat(\(.*\))?:'; then
  BUMP="minor"
fi
```

Print: `Auto-detect from git history: Base: $BASE, Commits: N, Detected: $BUMP`. Set `INPUT="$BUMP"`.

### 4. Compute New Version

- `major` -> increment major, reset minor/patch to 0
- `minor` -> increment minor, reset patch to 0
- `patch` -> increment patch
- `X.Y.Z` -> use as-is after validating semver

```bash
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$INPUT" in
  major) NEW="$((MAJOR + 1)).0.0" ;;
  minor) NEW="$MAJOR.$((MINOR + 1)).0" ;;
  patch) NEW="$MAJOR.$MINOR.$((PATCH + 1))" ;;
  *)
    [[ "$INPUT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid input: $INPUT"; exit 1; }
    NEW="$INPUT"
    ;;
esac
```

If new == current: print "Already at $CURRENT" and exit.

### 5. Update Files

**VERSION:** Write `$NEW` (single line).

**CHANGELOG.md** (Edit tool):
- If `## [Unreleased]` exists: rename to `## [$NEW] - YYYY-MM-DD`
- Else insert before first `## [` version section:
  ```markdown
  ## [$NEW] - YYYY-MM-DD

  ### Added

  ### Changed

  ### Fixed
  ```
- Compare links: add `[$NEW]: $REPO_URL/compare/v$CURRENT...v$NEW` as first link.

**README.md:** Replace `$CURRENT` with `$NEW` if version references exist.

### 6. Run Sync

```bash
./tools/sync/run.sh --target all
```

### 7. Print Summary

```
Version bumped: $CURRENT → $NEW

Updated files:
  - VERSION
  - CHANGELOG.md
  - README.md (if changed)
  - Synced to .claude/ and .kimi/
```

## Exit Criteria

- [ ] Project rules read
- [ ] VERSION updated
- [ ] CHANGELOG.md has `## [$NEW] - YYYY-MM-DD` section
- [ ] Compare links updated
- [ ] README.md updated (if version references exist)
- [ ] Sync completed via `./tools/sync/run.sh --target all`
- [ ] Auto-detect analyzed git history when no input provided
- [ ] No git commit made
