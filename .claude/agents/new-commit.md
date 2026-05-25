---
name: new-commit
description: Route to commit sub-skill by mode prefix.
agent: true
model: sonnet
---


# new-commit

Routes to commit sub-skill based on input mode prefix. Invoke sub-skills via `/skill-name` (Skill tool).

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-commit/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-commit/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `NEW-COMMIT COMPLETE`.
