---
name: run-task
description: TDD one task. No worktrees, commits, or Linear. --flow for metric-gated mode.
model: opus
---

# run-task

This skill delegates to the `run-task` custom agent. The agent definition lives at `.claude/agents/run-task.md` (project-local) or `$HOME/.claude/agents/run-task.md` (global install).

## Execution

When invoked via `/run-task`:

### Step 0: Resolve agent definition path

**Bash tool**:
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/agents/run-task.md" ] || _sh="$HOME/.claude"; [ -f "$_sh/agents/run-task.md" ] && echo "$_sh/agents/run-task.md" || echo NOT_FOUND
```

If the output is `NOT_FOUND`: print exactly `SKILL BLOCKED: agent definition not found at .claude/agents/run-task.md or $HOME/.claude/agents/run-task.md` and STOP. Do NOT improvise from this skill description — the full workflow lives in the agent file and skipping it bypasses validation, completion markers, and re-review gates.

### Step 1: Load agent

**Read tool**: the absolute path printed by Step 0.

### Step 2: Execute

Follow the agent instructions exactly. Pass through all user arguments.

## Input

```bash
/run-task [args]
```
