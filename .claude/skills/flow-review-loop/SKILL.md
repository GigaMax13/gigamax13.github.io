---
name: flow-review-loop
description: Loop review-code --flow and fix-review --flow until 3 clean.
model: opus
---

# flow-review-loop

This skill delegates to the `flow-review-loop` custom agent. The agent definition lives at `.claude/agents/flow-review-loop.md` (project-local) or `$HOME/.claude/agents/flow-review-loop.md` (global install).

## Execution

When invoked via `/flow-review-loop`:

### Step 0: Resolve agent definition path

**Bash tool**:
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/agents/flow-review-loop.md" ] || _sh="$HOME/.claude"; [ -f "$_sh/agents/flow-review-loop.md" ] && echo "$_sh/agents/flow-review-loop.md" || echo NOT_FOUND
```

If the output is `NOT_FOUND`: print exactly `SKILL BLOCKED: agent definition not found at .claude/agents/flow-review-loop.md or $HOME/.claude/agents/flow-review-loop.md` and STOP. Do NOT improvise from this skill description — the full workflow lives in the agent file and skipping it bypasses validation, completion markers, and re-review gates.

### Step 1: Load agent

**Read tool**: the absolute path printed by Step 0.

### Step 2: Execute

Follow the agent instructions exactly. Pass through all user arguments.

## Input

```bash
/flow-review-loop [args]
```
