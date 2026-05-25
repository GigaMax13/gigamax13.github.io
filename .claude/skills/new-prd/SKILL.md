---
name: new-prd
description: Create PRD.md. Single or multi-phase.
model: opus
---


# new-prd

Create text-only PRDs inside phase directories. Single-phase or multi-phase.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-prd/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-prd/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `NEW-PRD COMPLETE`.
