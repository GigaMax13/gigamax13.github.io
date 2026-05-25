---
name: new-release
description: Create GitHub release with cross-platform binaries.
model: haiku
---


# new-release

Build, tag, and publish a GitHub release with cross-platform binaries.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-release/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-release/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `NEW-RELEASE COMPLETE`.
