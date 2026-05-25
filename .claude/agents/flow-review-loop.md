---
name: flow-review-loop
description: Loop review-code --flow and fix-review --flow until 3 clean.
agent: true
model: opus
---


# flow-review-loop

Iterates `/review-code --flow` → (if dirty) `/fix-review --flow` until **3 consecutive clean reviews**. Hands-off cleanup — no manual re-runs or model reselection between iterations.

**Runtime:** Runs inline on the **session model** (Opus recommended). Sub-calls to `/review-code --flow` and `/fix-review --flow` spawn as separate **Sonnet** subagents via the **Task tool** (NOT Skill tool — anthropics/claude-code#17351 nested-yield bug).

## Usage

```
/flow-review-loop                 # full repo, default thresholds
```

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/flow-review-loop/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/flow-review-loop/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `FLOW-REVIEW-LOOP COMPLETE`.
