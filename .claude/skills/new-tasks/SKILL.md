---
name: new-tasks
description: Create tasks from PRD. Auto-splits oversized.
model: opus
---


# new-tasks

Create tasks from PRD. Auto-split oversized. For existing projects, analyze codebase for context-aware tasks.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-tasks/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-tasks/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `NEW-TASKS COMPLETE`.
