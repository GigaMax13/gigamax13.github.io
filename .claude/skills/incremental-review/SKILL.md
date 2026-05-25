---
name: incremental-review
description: Scoped review. Diffs, PRs, folder filters.
model: sonnet
---

# incremental-review

This skill delegates to the `incremental-review` custom agent. The agent definition lives at `.claude/agents/incremental-review.md` (project-local) or `$HOME/.claude/agents/incremental-review.md` (global install).

## Execution

When invoked via `/incremental-review`:

### Step 0: Resolve agent definition path

**Bash tool**:
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/agents/incremental-review.md" ] || _sh="$HOME/.claude"; [ -f "$_sh/agents/incremental-review.md" ] && echo "$_sh/agents/incremental-review.md" || echo NOT_FOUND
```

If the output is `NOT_FOUND`: print exactly `SKILL BLOCKED: agent definition not found at .claude/agents/incremental-review.md or $HOME/.claude/agents/incremental-review.md` and STOP. Do NOT improvise from this skill description — the full workflow lives in the agent file and skipping it bypasses validation, completion markers, and re-review gates.

### Step 1: Load agent

**Read tool**: the absolute path printed by Step 0.

### Step 2: Execute

Follow the agent instructions exactly. Pass through all user arguments.

## Input

```bash
/incremental-review [args]
```
