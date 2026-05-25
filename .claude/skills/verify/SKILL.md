---
name: verify
description: Pre-PR gate: build, typecheck, lint, tests, security.
model: sonnet
---


# verify

Pre-PR loop. Extends `/validate` (typecheck/lint/test) with build, security, diff review.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/verify/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/verify/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `VERIFY COMPLETE`.
