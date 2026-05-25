---
name: new-rules
description: Generate lean project rule files from codebase analysis.
model: sonnet
---


# new-rules

Emit a minimal **CLAUDE.md** (open standard, loaded by Claude Code, Kimi CLI, Codex, Cursor) plus a 1-line **CLAUDE.md** that imports it via `@CLAUDE.md`. One source of truth, zero duplication.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-rules/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-rules/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `NEW-RULES COMPLETE`.
