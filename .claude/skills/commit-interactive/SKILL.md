---
name: commit-interactive
description: Group changes into commits, ask for approval.
model: sonnet
---


# commit-interactive

Analyze uncommitted changes, group into logical commits, ask approval before executing. Git commands require explicit user approval.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/commit-interactive/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/commit-interactive/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `COMMIT-INTERACTIVE COMPLETE` after the user accepts (or rejects) each commit.
