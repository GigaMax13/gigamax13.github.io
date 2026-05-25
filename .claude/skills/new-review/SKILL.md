---
name: new-review
description: Review uncommitted changes. Writes .dev/review.md.
model: sonnet
---

# new-review

This skill delegates to the `new-review` custom agent. The agent definition lives at `.claude/agents/new-review.md` (project-local) or `$HOME/.claude/agents/new-review.md` (global install).

## Execution

When invoked via `/new-review`:

### Step 0: Resolve agent definition path

**Bash tool**:
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/agents/new-review.md" ] || _sh="$HOME/.claude"; [ -f "$_sh/agents/new-review.md" ] && echo "$_sh/agents/new-review.md" || echo NOT_FOUND
```

If the output is `NOT_FOUND`: print exactly `SKILL BLOCKED: agent definition not found at .claude/agents/new-review.md or $HOME/.claude/agents/new-review.md` and STOP. Do NOT improvise from this skill description — the full workflow lives in the agent file and skipping it bypasses validation, completion markers, and re-review gates.

### Step 1: Load agent

**Read tool**: the absolute path printed by Step 0.

### Step 2: Execute

Follow the agent instructions exactly. Pass through all user arguments.

## Input

```bash
/new-review [args]
```
