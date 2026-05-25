---
name: flow-doctor
description: Audit host project for flow-metrics tools. Lists what to install and config init.
---


# flow-doctor

Scans the host project, detects language(s), reports which `flow-metrics` tools are present vs missing, and prints exact install + config-init commands per missing piece. Read-only — never modifies the host project.

## Input

```bash
/flow-doctor                 # Auto-detect languages at cwd
/flow-doctor --target PATH   # Audit a different project root
```

## Output

Per detected language, a status table:

```
OK    coverage         @vitest/coverage-v8 (devDep)
MISS  duplication      jscpd
```

followed by `## To complete the kit` (install command tuned to the host's package manager) and `## Config init` (eslint rules, stryker config, etc.).

Exit code: 0 always (read-only audit).

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/flow-doctor/scripts/run.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/flow-doctor/scripts/run.sh" "$ARGS"
```

Print script output verbatim. Do NOT add commentary or analysis.
