# commit-interactive playbook


# commit-interactive

Analyze uncommitted changes, group into logical commits, ask approval before executing.

## Input Modes

| Mode | Input | Behavior |
|------|-------|----------|
| Default | *(none)* | Group files logically, NO issue refs |
| Instructions | `make a single commit` / `group by component` | Guides grouping |
| Auto-Find Issues | `find/create issues for these commits` | Finds/creates Linear issues per group |
| Specific Issues | `use CURB-10 for commit 1, CURB-11 for commits 2-3` | Validate and use specified IDs |
| Linear Reference | `linear:CURB-10` or `linear:CURB-10:instructions` | Use specified issue for all commits |

## Process

### 0. Load Rules

Resolve rules dir (first match: `.claude/skills/_rules/`, `.claude/skills/_rules/`, `~/.claude/skills/_rules/`). Read `$RULES_DIR/commit.md`, then project rules (`CLAUDE.md` or `CLAUDE.md`, first found).

### 1. Analyze Changes

```bash
git status --porcelain
git diff --stat
git diff --cached --stat
git ls-files --others --exclude-standard
```

Untracked files (`??` or from `git ls-files --others`) not in `.gitignore` MUST be included. Never silently omit.

### 2. Parse Instructions (if any)

| Instruction | Behavior |
|-------------|----------|
| `make a single commit` | Squash all into one |
| `group by component` | Group by module boundaries |
| `group by type` | Group by change type (feat/fix/test) |
| `focus on <area>` | Only files matching area |
| `skip <pattern>` | Exclude files matching pattern |

### 3. Group Files

Group by type (feat/fix/refactor/test/docs/style/chore/perf/ci/build) and related files (component + test + styles). Apply instructions.

### 4. Handle Issue References (if requested)

**Auto-find:**
```bash
if [ -d ".linear" ]; then
  linear issue list --all-states -A --limit 20
fi
```

**Specific issues:**
```bash
linear issue view TEAM-XXX --json
```

**Linear reference:**
```bash
ISSUE_ID=$(echo "$INPUT" | grep -oE 'linear:[A-Z]+-[0-9]+' | sed 's/linear://')
linear issue view "$ISSUE_ID" --json
```

### 5. Propose Commits

```
Proposed Commit 1/3
Type: feat
Message: add OAuth2 login flow
Files:
  - src/auth/oauth.ts
Refs: CURB-15 (if issues requested or linear:CURB-15 provided)
```

### 6. Ask for Approval

**NEVER PROCEED WITHOUT EXPLICIT APPROVAL.**

### 7. Verify Rules Gate

After approval, run verify-rules on files about to be committed:

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/verify-rules/scripts/verify.sh" ] || _sh="$HOME/.claude"
bash "$_sh"/skills/verify-rules/scripts/verify.sh <files-to-commit>
```

- **Pass (exit 0)**: proceed to step 8.
- **Fail (exit 2)**: show violations, ask user whether to fix first or proceed anyway.

### 8. Execute After Verification

```bash
git add <files>

if [ -n "$ISSUE_ID" ]; then
  git commit -m "type: description" -m "Refs: $ISSUE_ID"
else
  git commit -m "type: description"
fi
```

## Commit Message Rules

- Format: `type: description` (NO scope), max 72 chars
- Imperative mood, no capital first letter, no period
- Footer `Refs: TEAM-XXX` only with explicit issue request
- No bullet lists

## Rules

1. **NEVER act without approval**
2. **NO issue refs by default** — only if explicitly requested
3. **Validate issue IDs** — check specified issues exist
4. **Include all non-ignored files** — untracked not in `.gitignore` MUST be included
5. **Logical grouping** — group related files
6. **Follow instructions** — apply any provided
7. **English only**
8. **Never push** — local commits only

## Exit Criteria

- [ ] Commit rules loaded (`$RULES_DIR/commit.md`)
- [ ] Project rules read (if exists)
- [ ] All uncommitted changes analyzed
- [ ] Logical commit groups proposed
- [ ] Issue refs only if explicitly requested
- [ ] Instructions applied (if any)
- [ ] User explicitly approved
- [ ] Verify-rules passed (or user chose to proceed despite violations)
- [ ] Files staged and committed after approval
