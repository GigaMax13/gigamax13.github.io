---
name: linear-check
description: Check if uncommitted changes resolve Linear issue.
model: opus
---


# linear-check

Verify uncommitted changes against Linear issue requirements. Creates `$DEV_DIR/review.md` with ONLY gaps; deletes it if all requirements met.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/linear-check/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/linear-check/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `LINEAR-CHECK COMPLETE`.
