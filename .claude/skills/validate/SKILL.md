---
name: validate
description: Run typecheck, lint, tests per Validation table.
model: sonnet
---


# validate

Run validation commands from project rules: typecheck, lint, tests. Inline Bash, no sub-skills.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/validate/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/validate/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `VALIDATE COMPLETE`.
