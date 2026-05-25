---
name: incremental-review
description: Scoped review. Diffs, PRs, folder filters.
agent: true
model: sonnet
---


# incremental-review

Scoped review for diffs, PRs, or folder subsets. Wraps `review-code` with file selection.

## Usage

```
/incremental-review                              # All files (batched)
/incremental-review this branch                  # Branch diff vs main/master
/incremental-review PR 42                        # PR files
/incremental-review in apps/web                  # Folder filter
/incremental-review this branch in apps/web      # Branch + folder
```

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/incremental-review/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/incremental-review/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step. Use the **Task tool** (NEVER Skill tool) for `review-code` delegation. End by printing `INCREMENTAL-REVIEW COMPLETE`.
