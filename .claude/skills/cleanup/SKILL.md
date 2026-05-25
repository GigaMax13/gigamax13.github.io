---
name: cleanup
description: Remove console.log, TODOs, commented code, unused imports.
model: haiku
---


# cleanup

Remove development artifacts from changed files. Run after development, before review.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/cleanup/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/cleanup/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `CLEANUP COMPLETE`.
