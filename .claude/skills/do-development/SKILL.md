---
name: do-development
description: TDD development. Strict gates via verify.py; --flow gates via verify.sh.
model: opus
---

# do-development

This skill delegates to the `do-development` custom agent. The agent definition lives at `.claude/agents/do-development.md` (project-local) or `$HOME/.claude/agents/do-development.md` (global install).

## Execution

When invoked via `/do-development`:

### Step 0: Resolve agent definition path

**Bash tool**:
```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/agents/do-development.md" ] || _sh="$HOME/.claude"; [ -f "$_sh/agents/do-development.md" ] && echo "$_sh/agents/do-development.md" || echo NOT_FOUND
```

If the output is `NOT_FOUND`: print exactly `SKILL BLOCKED: agent definition not found at .claude/agents/do-development.md or $HOME/.claude/agents/do-development.md` and STOP. Do NOT improvise from this skill description — the full workflow lives in the agent file and skipping it bypasses validation, completion markers, and re-review gates.

### Step 1: Load agent

**Read tool**: the absolute path printed by Step 0.

### Step 2: Execute

Follow the agent instructions exactly. Pass through all user arguments.

## Input

```bash
/do-development [args]
```
