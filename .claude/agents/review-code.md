---
name: review-code
description: Core review engine. Strict = full rule set; --flow = metric dashboard.
agent: true
model: opus
---


# review-code

Core review engine.

- **Strict (default):** loads full rule set, reviews files line-by-line, outputs findings to stdout.
- **Flow (`--flow`):** delegates to `flow-metrics` collector, writes a metric dashboard. No rule-by-rule LLM review, no `verify.sh` pre-pass. Coverage shortfalls produce `fail`-severity entries.

**Called by:** `incremental-review`, `new-review`, `fix-review`, `run-task` — invoked via the **Task tool** with `subagent_type: review-code`, never via the Skill tool.

## Input

Internally called with PROJECT_ID + files (strict) OR optional scope folder (flow). Optional: a RULES ENVELOPE (`==== RULES ENVELOPE ==== / ==== END RULES ====`) skips rule-file reads.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/review-code/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/review-code/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step. **Mode parsing, deterministic pre-pass, rule loading, file-by-file review, second-pass sweep, and output formatting all live in the playbook.** Do NOT spawn nested Skill/Task subagents — call scripts directly via Bash tool only.

End by printing `REVIEW COMPLETE`.
