---
name: do-task
description: Feature/bugfix via TDD. Branch + development. --flow for metric-gated mode.
agent: true
model: opus
---


# do-task

Complete a task using TDD. Orchestrates `new-branch` and `do-development`. Does NOT create commits.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/do-task/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/do-task/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `DO-TASK COMPLETE`.
