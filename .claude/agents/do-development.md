---
name: do-development
description: TDD development. Strict gates via verify.py; --flow gates via verify.sh.
agent: true
model: opus
---


# do-development

Implements a task following project rules using TDD (red → green → refactor). **TDD is mandatory in both strict and flow modes.** Sub-skills run via **Task tool** (NEVER Skill tool — anthropics/claude-code#17351).

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/do-development/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/do-development/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `DO-DEVELOPMENT COMPLETE`.
