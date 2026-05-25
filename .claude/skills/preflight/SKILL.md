---
name: preflight
description: Pre-flight: clean git, pending tasks exist.
model: haiku
---


# preflight

Pre-flight checks before TDD. Read project rules (`CLAUDE.md`, first found), then run the script.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/preflight/scripts/run.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/preflight/scripts/run.sh"
```

Exit 0 = `PREFLIGHT COMPLETE`, exit 1 = `PREFLIGHT FAILED`. Print script output verbatim; do not improvise.
