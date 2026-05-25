---
name: new-version
description: Bump VERSION, CHANGELOG.md, README.md.
model: haiku
---


# new-version

Bump version across project files. Does NOT commit or tag.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-version/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-version/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `NEW-VERSION COMPLETE`.
