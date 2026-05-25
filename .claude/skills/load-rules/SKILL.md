---
name: load-rules
description: Load CLAUDE.md and stack-relevant rules.
model: haiku
---


# load-rules

Load project rules once and output a structured envelope for downstream skills (review-code, do-development, validate).

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/load-rules/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/load-rules/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `LOAD-RULES COMPLETE` after the envelope is printed.
