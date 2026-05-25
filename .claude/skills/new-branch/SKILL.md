---
name: new-branch
description: Create feature/bugfix branch. Uses Linear if .linear/.
model: sonnet
---


# new-branch

Create branch with optional Linear integration. Git commands require explicit user approval.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-branch/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-branch/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `NEW-BRANCH COMPLETE`.
