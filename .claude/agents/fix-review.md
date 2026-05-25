---
name: fix-review
description: Fix .dev/review.md (strict) or failing flow metrics (--flow).
agent: true
model: sonnet
---


# fix-review

Fix review issues.

- **Strict (default):** fix findings listed in `$DEV_DIR/review.md`, then re-review via `review-code` + deterministic `verify.sh`.
- **Flow (`--flow`):** fix failing AND warning metrics from `$DEV_DIR/flow/data.json`, re-measure via `flow-metrics`. Iterates up to 3 rounds.

**Runtime:** Sub-skill delegation uses **Task tool** (NEVER Skill tool — anthropics/claude-code#17351). `validate`, `flow-metrics`, `verify-rules` run as **inline Bash**.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/fix-review/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/fix-review/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. Mode parsing, F1–F4 (flow), and Steps 1–7 (strict) all live in the playbook. End by printing `FIX-REVIEW COMPLETE`.
