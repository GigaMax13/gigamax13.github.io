---
name: new-review
description: Review uncommitted changes. Writes .dev/review.md.
agent: true
model: sonnet
---


# new-review

Review uncommitted changes. Delegates to `review-code` subagent via **Task tool**, then writes (or deletes) `.dev/review.md` in the same turn.

## Usage

```
/new-review                        # All uncommitted changes (default)
/new-review $PROJECT_ID
/new-review src/server/routers/    # Only files in directory
/new-review src/a.ts src/b.ts      # Specific files only
```

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/new-review/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/new-review/scripts/playbook.sh"
```

Read the playbook output and execute every step in order. **Use the Task tool (NOT Skill tool) for the review-code delegation step** — this prevents control yielding before `.dev/review.md` is written.
