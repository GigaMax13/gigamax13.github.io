---
name: new-linear
description: Create or update Linear issue from task.
model: sonnet
---


# new-linear

Create or update a Linear issue tied to the current task. **MANDATORY when `.linear/` exists** (unless `linear:none`). Run before code changes.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-linear/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-linear/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `NEW-LINEAR COMPLETE`.
