---
name: optimize
description: Reduce token count without changing behavior.
model: opus
---


# optimize

Condense without losing information. Token-count reduction pass.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/optimize/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/optimize/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `OPTIMIZE COMPLETE`.
