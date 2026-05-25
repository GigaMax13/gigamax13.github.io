# new-workflow playbook


# new-workflow

Create TDD workflow orchestration.

## Output

Creates in `.claude/skills/`:
- `run-task/SKILL.md` - Orchestrator
- `preflight/SKILL.md` - Git/task checks
- `find-task/SKILL.md` - Find pending task
- `new-linear/SKILL.md` - Linear integration
- `do-development/SKILL.md` - TDD implementation
- `validate/SKILL.md` - Run validations
- `refactor/SKILL.md` - Fix violations
- `mark-task-done/SKILL.md` - Mark complete
- `new-commit/SKILL.md` - Conventional commits

## Prerequisites

Read project rules (`CLAUDE.md`, first found).

## Workflow

```
run-task
├── preflight
├── find-task
├── new-linear (if .linear/ exists)
├── do-development
├── validate
├── refactor
├── validate
├── mark-task-done
└── new-commit
```

## Rules

1. Skills ONLY — no inline implementation
2. Stop on failure
3. Max 3 refactor iterations

## Structure

`DEV_DIR` resolved at runtime via `resolve-dev.sh` (`./.dev`, `.claude/.dev`, or `~/.claude/.dev`).

```
$DEV_DIR/[PHASE]/
├── PRD.md
├── state.md
└── tasks/*.md
```

## Exit

- [ ] Project rules read (if exists)
- [ ] All skills created
- [ ] run-task is pure orchestrator
- [ ] No co-authors, no push rules
- [ ] Max 3 iterations documented
