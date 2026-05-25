---
name: find-task
description: Find next pending task in state.md.
model: haiku
---


# find-task

Thin wrapper around `scripts/run.sh`. Resolves the latest phase dir under `$DEV_DIR`, finds the first unchecked task in `state.md`, prints its path + PR group + first 40 lines of the task file.

Read project rules (`CLAUDE.md`, first found) before invoking.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/find-task/scripts/run.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/find-task/scripts/run.sh"
```

Exit 0 = `FIND-TASK COMPLETE`, non-zero = `FIND-TASK FAILED`. Print script output verbatim; do not improvise.
