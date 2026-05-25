---
name: run-task
description: TDD one task. No worktrees, commits, or Linear. --flow for metric-gated mode.
agent: true
model: opus
---


# run-task

Pure development orchestrator. Runs one task via TDD. Sub-skills run via **Task tool** (NEVER Skill tool — anthropics/claude-code#17351).

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/run-task/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/run-task/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `RUN-TASK COMPLETE`.
