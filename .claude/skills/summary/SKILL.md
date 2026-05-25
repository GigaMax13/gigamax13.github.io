---
name: summary
description: Print workflow completion summary.
model: haiku
---


# summary

Thin wrapper around `scripts/run.sh`. Prints a read-only summary of the latest completed task, the last commit, and the diff stat vs HEAD~1. Omits rows without data.

Read project rules (`CLAUDE.md`, first found) before invoking.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/summary/scripts/run.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/summary/scripts/run.sh"
```

Exit 0 = `SUMMARY COMPLETE`. Print script output verbatim; do not improvise.
