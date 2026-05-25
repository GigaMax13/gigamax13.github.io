---
name: commit-workflow
description: Create task-workflow commit. Needs approval.
model: sonnet
---


# commit-workflow

Create conventional commits for task workflow. **REQUIRES explicit user approval.** Called by `new-commit` in workflow mode, after `mark-task-done`, or at end of development workflow.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/commit-workflow/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/commit-workflow/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `COMMIT-WORKFLOW COMPLETE`.
