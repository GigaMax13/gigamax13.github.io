---
name: security-audit
description: Core security audit. Loads rules, emits findings.
model: opus
---


# security-audit

Core security audit engine. Loads applicable rules, audits files, emits findings to stdout.

**Called by:** `incremental-security` — invoked via the **Task tool** with `subagent_type: security-audit`, never via the Skill tool.

## Input

Internal: `$PROJECT_ID, $files`.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/security-audit/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/security-audit/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step. Findings go to stdout in the standard `==== REVIEW FINDINGS ====` / `==== END FINDINGS ====` envelope (or `==== NO ISSUES ====`). End by printing `SECURITY-AUDIT COMPLETE`.
