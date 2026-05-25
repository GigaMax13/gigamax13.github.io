---
name: new-pr
description: Create GitHub PR with issue refs from commits.
model: sonnet
---


# new-pr

Create PR with comprehensive description and ALL issue references from commits.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-pr/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-pr/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `NEW-PR COMPLETE`.
