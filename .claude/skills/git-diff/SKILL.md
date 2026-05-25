---
name: git-diff
description: Show git diff. Nothing else.
model: haiku
---


# git-diff

**RAW GIT DIFF ONLY. NO DELTA. NO SUMMARY. NO COMMENTARY.**

## Input

```bash
/git-diff                              # Unstaged (default)
/git-diff staged                       # Staged changes
/git-diff range, HEAD~1..HEAD, stat    # Specific range with stats
/git-diff paths, src/file.ts           # Specific files
/git-diff staged, stat, context:5      # Combined options
```

Options: `staged`, `stat`, `range, RANGE`, `paths, FILE1, FILE2...`, `context:N`.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/git-diff/scripts/run.sh" ] || _sh="$HOME/.claude"
echo "$ARGS" | bash "$_sh/skills/git-diff/scripts/run.sh"
```

Print script output verbatim. Do NOT analyze, summarize, or comment.
