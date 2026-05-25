---
name: flow-init
description: Install and configure flow-metrics tooling on a TS/JS host. Asks per phase.
---


# flow-init

Bootstrap the `flow-metrics` toolchain on a host TypeScript / JavaScript project. Audits via `flow-doctor --json`, then walks four user-confirmed phases:

1. install missing devDependencies (PM-aware: npm / yarn / pnpm / bun),
2. scaffold `stryker.config.json` (delegates to flow-metrics),
3. add `package.json` scripts (`test:coverage`, `mutate`, `flow:metrics`),
4. append a managed block to `.gitignore` for generated artifacts.

Each phase requires explicit `yes` before any file is written or any install runs. Idempotent — re-running on a configured host is a no-op.

## Input

```bash
/flow-init                       # operate on current project
/flow-init --target PATH         # operate on a different project root
/flow-init --force               # overwrite existing package.json scripts (phase 3)
```

## Output

Per-phase status line plus a final `FLOW-INIT COMPLETE` summary with any manual follow-ups (e.g. ESLint rule additions surfaced by flow-doctor's `configNotes`).

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/flow-init/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/flow-init/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. Use the `--target` value from the user's invocation (default: cwd) and `--force` flag throughout. End by printing `FLOW-INIT COMPLETE` with the per-phase status summary.
