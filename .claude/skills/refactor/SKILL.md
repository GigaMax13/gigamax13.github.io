---
name: refactor
description: Refactor per rules. Loops with validate, max 3.
model: opus
---


# refactor

Analyze against CLAUDE.md / CLAUDE.md and refactor. Loops with `/validate`, max 3 iterations.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/refactor/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/refactor/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `REFACTOR COMPLETE`.
