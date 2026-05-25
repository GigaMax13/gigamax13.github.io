---
name: check-phase
description: Verify phase against PRD, tasks, state.md, Linear.
model: opus
---


# check-phase

Verify current branch fully implements all phase requirements. Creates `$DEV_DIR/review.md` with ONLY gaps; deletes it if all requirements met.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/check-phase/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/check-phase/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `CHECK-PHASE COMPLETE`.
