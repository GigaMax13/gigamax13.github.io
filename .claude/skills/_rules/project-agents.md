---
alwaysApply: false
description: "Rules for project-agents"
---

# Project Rules: agents

> Extends: python.md

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** edit `.claude/` or `.kimi/` directly — source is `.claude/`
- [ ] Tool tests must pass before committing

<!-- verify-rules:start
max-lines:399 ext:py,sh,ts,tsx,js,go,rs exclude:tools/
verify-rules:end -->

## Source of Truth

- [ ] `.claude/` is canonical — sync with `./tools/sync/run.sh --target all` after any edit
- [ ] `--dry-run` before destructive changes, `--check` after sync
- [ ] `.sync-manifest.json` auto-generated — never edit

## Tool Isolation (CRITICAL)

- [ ] Each tool under `tools/{name}/` has its own `.venv/`
- [ ] NEVER run `pip install`, `python`, or `pytest` outside a tool's venv — use `tools/{tool}/.venv/bin/python`
- [ ] No shared venvs between tools

## Tool Structure

- [ ] `setup.sh` creates venv + installs deps; `run.sh` validates venv + runs tool
- [ ] `pyproject.toml` for third-party deps; `requirements.txt` for stdlib-only
- [ ] `justfile` for tools with multiple validation commands

## Skill & Rule Authoring

- [ ] Shell: `#!/bin/bash` + `set -e`
- [ ] Rules use checklist format (`- [ ]`); `> Extends:` header when building on shared rules
- [ ] Skill frontmatter: `name` and `description` required
- [ ] Every skill is a thin wrapper: `SKILL.md` body ≤ 50 lines + `scripts/` with ≥ 1 file
- [ ] Logic lives in `scripts/`, not in SKILL.md prose — SKILL.md describes input/output and shells out
- [ ] Run `bash tools/validate/run.sh` before PR

## Validation

| Type       | Command                                                                    |
| ---------- | -------------------------------------------------------------------------- |
| Sync Test  | `cd tools/sync && .venv/bin/python -m pytest`                              |
| Validate   | `cd tools/validate && bash run.sh`                                         |
| Shellcheck | `shellcheck .claude/scripts/**/*.sh 2>/dev/null \|\| echo "No shellcheck"` |

## Before Submitting PR

- [ ] Sync tool tests pass; typecheck and lint clean
- [ ] `./tools/sync/run.sh --target all` succeeds
- [ ] No direct edits to `.claude/` or `.kimi/`
