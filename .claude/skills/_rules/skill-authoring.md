---
alwaysApply: false
description: "Rules for skill-authoring"
---

# Skill Authoring Rules

Every skill in `.claude/skills/{name}/` is a **thin wrapper**: tiny `SKILL.md` + executable `scripts/`. This rule defines the patterns and the why.

## Why thin

Per [Anthropic Agent Skills docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview), skills use 3-level progressive disclosure:

| Level | When loaded | Cost |
|---|---|---|
| 1. Frontmatter (name + description) | Always at session start | ~100 tokens/skill |
| 2. SKILL.md body | When skill is triggered | <5k tokens |
| 3. Bundled files (`scripts/`) | Only when SKILL.md references them | 0 until accessed |

Kimi CLI follows the same model. **Claude Code currently has bug [#14882](https://github.com/anthropics/claude-code/issues/14882) where bodies leak into Level 1** — thin bodies cap that bleed.

## Anatomy of a thin skill

```
.claude/skills/my-skill/
├── SKILL.md              # ≤ 50 body lines, frontmatter + IO contract + execution stanza
└── scripts/
    ├── run.sh            # bash work (or run.py for Python — see Python rule below)
    └── playbook.md       # ONLY for prompt-only skills, see playbook pattern below
```

### SKILL.md template (executable / bash skill)

````markdown
---
name: my-skill
description: One imperative sentence ≤80 chars. No "(Recommended)". No impl hints.
---

# my-skill

One-paragraph what + when.

## Input
`/my-skill [arg1] [arg2]` — describe options.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/my-skill/scripts/run.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/my-skill/scripts/run.sh" "$ARGS"
```

Print script output verbatim.
````

The `_sh` chain (`AGENTS_SKILLS_HOME` → `CLAUDE_PROJECT_DIR/.claude` → `~/.claude`) is **load-bearing**: it makes the same SKILL.md work in project install, global install, and Kimi sessions. Never inline a different resolution.

### Canonical references

- `git-diff` — minimal bash skill (26 body lines, 1 script).
- `flow-metrics` — bash skill with multi-script delegation.
- `verify-rules` — Python (stdlib-only) skill with bash wrapper.

## Playbook-as-script (for prompt-only skills)

When a skill is irreducibly LLM-driven (review, generation, audit), `scripts/run.sh` cannot do the work — only Claude can. Comply by moving the prompt content into `scripts/playbook.md` and `cat`ting it from a tiny shim:

```
.claude/skills/review-code/
├── SKILL.md              # ≤15 body lines, routes to playbook.sh
└── scripts/
    ├── playbook.sh       # 2-line: cat $(dirname $0)/playbook.md
    └── playbook.md       # the actual instructions (today's body, verbatim)
```

```bash
# scripts/playbook.sh
#!/bin/bash
cat "$(dirname "$0")/playbook.md"
```

The SKILL.md body says: "Run `bash scripts/playbook.sh`, then execute every numbered step in the output." This satisfies the validator (scripts/ non-empty, body thin) without changing what reaches Claude on invocation. Cost: one extra Bash tool roundtrip per invocation (~10-20 wrapper tokens). Trade-off is dominated by the session-start savings.

## Python dependency decision rule

1. **Default: stdlib-only.** Use `re`, `json`, `pathlib`, `subprocess`, `tomllib` (3.11+), `argparse`. Mirrors `verify-rules/scripts/verify.py`. Runs in any Python 3.11+ — hooks, Kimi, anywhere. No install step.
2. **Escape hatch: skill-local venv with fail-soft dispatch.** Mirrors `flow-metrics/.venv/`. Bootstrapped on first use; missing tools degrade to `SKIPPED`, never `FAIL`. Use only when third-party deps are genuinely required.
3. **Power-user: PEP 723 + `uv run`.** Inline `# /// script` headers; runs via `uv run script.py`. Requires `uv` on host. Document at top of SKILL.md.

Never `pip install` into the user's site-packages or `~/.local/`.

## Wrapper strategy (orchestrators only)

Orchestrators in `tools/sync/sync_agents.py` migrate to `.claude/agents/{name}.md` plus a wrapper SKILL.md. Two wrapper kinds:

| Kind | When to use | Effect |
|---|---|---|
| **read-and-follow** (default) | Pipeline orchestrators that drive the main conversation step-by-step (`do-task`, `do-development`, `run-task`, `new-commit`) | Wrapper resolves the agent file path, reads it, executes inline. User sees coordination. |
| **Agent-tool dispatch** (populate `AGENT_DISPATCH_WRAPPERS`) | Self-contained orchestrators that produce an artifact (`review-code`, `fix-review`, `incremental-*`, `new-review`, `flow-review-loop`) | Wrapper invokes the Agent tool with `subagent_type`. Subagent runs in isolated context, returns final result. Allows model pinning. |

## Description style guide

Frontmatter `description` is **always loaded** at session start across both Claude Code and Kimi. Keep it terse:

- ≤ 80 characters.
- Imperative voice: "Show…", "Run…", "Create…", "Fix…".
- One sentence. No subordinate clauses. No parenthetical notes.
- No implementation hints (drop "via verify.py", "with --json").
- No "(Recommended)" or marketing copy.

## Validation

`bash tools/validate/run.sh` enforces:
- frontmatter present;
- body ≤ 50 lines;
- `scripts/` exists and non-empty;
- sync manifests not drifted.
