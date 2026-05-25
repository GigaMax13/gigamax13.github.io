---
name: flow-dashboard
description: Metric dashboard vs main. Read-only.
model: sonnet
---


# flow-dashboard

Read-only manager-level dashboard: current state, per-metric trend vs a base ref, worst-offending files. Populates the `baseline` key in `$DEV_DIR/flow/data.json` and appends a Trend section to `$DEV_DIR/flow/report.md`.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/flow-dashboard/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/flow-dashboard/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `FLOW-DASHBOARD COMPLETE`.
