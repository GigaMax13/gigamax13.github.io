---
name: task-2-branch
description: Task name to kebab-case branch (max 2 words).
model: haiku
---


# task-2-branch

Convert a task name to a kebab-case branch (max 2 words, optional type prefix preserved).

## Input

```bash
/task-2-branch $TASK_NAME       # or via stdin
```

Prefixes auto-detected: `feature/` `fix/` `hotfix/` `bugfix/` `chore/` `refactor/` `test/` `docs/` `ci/` `build/` `perf/` `style/`.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/task-2-branch/scripts/run.sh" ] || _sh="$HOME/.claude"
echo "$TASK_NAME" | bash "$_sh/skills/task-2-branch/scripts/run.sh"
```

Print script output verbatim — exactly one line, branch name only.

## Examples

```
"Add user authentication to the dashboard"  -> add-user
"fix: child list reordering save error"     -> fix/child-list
"feature/Implement dark mode for mobile"    -> feature/implement-dark
```
