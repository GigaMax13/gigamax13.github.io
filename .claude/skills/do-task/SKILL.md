---
name: do-task
description: Feature/bugfix via TDD. Branch + development. --flow for metric-gated mode.
model: opus
---

# do-task

This skill delegates to the `do-task` custom agent. The agent definition lives at `.claude/agents/do-task.md` (project-local) or `$HOME/.claude/agents/do-task.md` (global install).

## Execution

When invoked via `/do-task`:

### Step 0: Resolve agent definition path

**Bash tool**:
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/agents/do-task.md" ] || _sh="$HOME/.claude"; [ -f "$_sh/agents/do-task.md" ] && echo "$_sh/agents/do-task.md" || echo NOT_FOUND
```

If the output is `NOT_FOUND`: print exactly `SKILL BLOCKED: agent definition not found at .claude/agents/do-task.md or $HOME/.claude/agents/do-task.md` and STOP. Do NOT improvise from this skill description — the full workflow lives in the agent file and skipping it bypasses validation, completion markers, and re-review gates.

### Step 1: Load agent

**Read tool**: the absolute path printed by Step 0.

### Step 2: Execute

Follow the agent instructions exactly. Pass through all user arguments.

## Input

```bash
/do-task [args]
```
