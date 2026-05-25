---
name: new-workflow
description: Create TDD workflow skill.
model: sonnet
---


# new-workflow

Create a TDD workflow orchestration skill scaffold.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-workflow/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-workflow/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `NEW-WORKFLOW COMPLETE`.
