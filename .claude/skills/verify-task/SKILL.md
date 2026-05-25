---
name: verify-task
description: Verify task implementation against requirements.
model: sonnet
---


# verify-task

Verify the current task's implementation against its declared requirements.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/verify-task/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/verify-task/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `VERIFY-TASK COMPLETE`.
