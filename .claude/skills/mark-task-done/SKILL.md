---
name: mark-task-done
description: Mark task complete locally. No external trackers.
model: haiku
---


# mark-task-done

Thin wrapper around `scripts/run.sh`. Resolves the latest phase under `$DEV_DIR`, flips the first `- [ ]` in its `state.md` to `- [x]` and appends `(completed YYYY-MM-DD)`. Never updates Linear or GitHub.

Read project rules (`CLAUDE.md`, first found) before invoking.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/mark-task-done/scripts/run.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/mark-task-done/scripts/run.sh"
```

Exit 0 = `MARK-TASK-DONE COMPLETE`, non-zero = `MARK-TASK-DONE FAILED`. Print script output verbatim.
