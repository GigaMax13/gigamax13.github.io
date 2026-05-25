---
name: incremental-security
description: Scoped security audit. Diffs, PRs, folders.
agent: true
model: sonnet
---


# incremental-security

Scoped security audit for diffs, PRs, or folder subsets. Wraps `security-audit` with file selection.

## Usage

```
/incremental-security                              # All files (batched)
/incremental-security this branch                  # Branch diff vs main/master
/incremental-security PR 42                        # PR files
/incremental-security in apps/web                  # Folder filter
/incremental-security this branch in apps/web      # Branch + folder
```

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/incremental-security/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/incremental-security/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step. Use the **Task tool** (NEVER Skill tool) for `security-audit` delegation. End by printing `INCREMENTAL-SECURITY COMPLETE`.
