---
name: map-linear
description: Map parent and subtasks to Linear via state.md.
model: sonnet
---


# map-linear

Map parent tasks (with subtasks) to Linear issues and ensure proper task file structure.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/map-linear/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/map-linear/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `MAP-LINEAR COMPLETE`.
