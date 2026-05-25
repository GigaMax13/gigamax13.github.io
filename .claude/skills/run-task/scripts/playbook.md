# run-task playbook


# run-task

Pure development orchestrator.

## Mode

Parse input: if it contains `--flow` as a standalone token, strip it and set `MODE=flow`. Otherwise `MODE=strict`.

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/_shared/parse-mode.sh" ] || _sh="$HOME/.claude"
eval "$(bash "$_sh/skills/_shared/parse-mode.sh" "$INPUT")"
# MODE = flow | strict; REMAINING = input with --flow removed.
```

## Flow mode overrides

When `MODE=flow`, run the 10-step pipeline below (not the 11-step strict pipeline):

1. `/preflight` → `[1/10] preflight done (9 left)`
2. `/find-task` → `[2/10] find-task done (8 left)`
3. **Test map** — same resolution as strict (see Step 3). Print `[3/10] test map generated (7 left)` or `[3/10] test map exists (7 left)`.
4. `/do-development --flow` — on `DO-DEVELOPMENT COMPLETE` (or `DO-DEVELOPMENT INCOMPLETE` in flow mode), print `[4/10] do-development done (6 left)`.
5. `/validate full` → `[5/10] validate done (5 left)` — typecheck + lint + test (parity with strict step 5; closes the gap that let type errors slip into review).
6. `/review-code --flow` — on `REVIEW COMPLETE`, print `[6/10] review done (4 left)`.
7. If `$DEV_DIR/flow/data.json`'s `summary.fails` or `summary.warns` is non-zero: `/fix-review --flow` (one call — handles its own loop). Print `[7/10] fix-review done (3 left)`. Else: `[7/10] no fixes needed (3 left)`.
8. `/mark-task-done` → `[8/10] mark-task-done done (2 left)`
9. **PR group status** (see below) → `[9/10] pr-group checked (1 left)`
10. `/summary` → `[10/10] complete`

Strict mode overrides NONE of the flow steps — run the 11-step pipeline.

## Prerequisites

Read project rules (`CLAUDE.md` or `CLAUDE.md`, first found).

## Rules

1. Invoke sub-skills via `/skill-name` (Skill tool)
2. Stop on ANY failure
3. (strict) Max 3 review/fix iterations; (flow) `/fix-review --flow` self-caps at 3 rounds
4. **FIX ALL ERRORS** before proceeding

## Workflow (strict, `MODE=strict` — default)

**AUTONOMOUS:** After each sub-skill's COMPLETE marker, immediately proceed. Do NOT pause between steps. Only valid stopping point is step 11.

1. `/preflight` → `[1/11] preflight done (10 left)`
2. `/find-task` → `[2/11] find-task done (9 left)`
3. **Test map** — resolve `DEV_DIR` via `_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh"`, then check `$DEV_DIR/.test-map.md`. If missing: `/discover-tests`. Print `[3/11] test map generated (8 left)` or `[3/11] test map exists (8 left)`
4. `/do-development` → `[4/11] do-development done (7 left)`
5. `/validate full` → `[5/11] validate done (6 left)`
6. `/new-review` → `[6/11] new-review done (5 left)`
7. If review.md exists: `/fix-review` then `/validate full` (max 3x). Print `[7/11] fixes done (4 left)`. Else: `[7/11] no fixes needed (4 left)`
8. `/verify-rules` — must exit 0. If `VERIFY-RULES FAILED`: `/fix-review` once then re-run. If still fails, STOP. Print `[8/11] verify-rules passed (3 left)`
9. `/mark-task-done` → `[9/11] mark-task-done done (2 left)`
10. **PR group status** (see below) → `[10/11] pr-group checked (1 left)`
11. `/summary` → `[11/11] complete`

## PR Group Status

Read state.md after marking done:

1. Find `<!-- PR: {name} -->` above the completed task
2. Count total and remaining `[ ]` tasks in that group
3. Print:
   - More remain: `PR "{pr-group}": completed {N}/{total} tasks ({remaining} left)`
   - All done: `PR "{pr-group}": all {total} tasks complete — ready to commit & open PR`

## Context Management

- **Safe to compact after:** step 4, step 7 (strict) / step 5, step 7 (flow)
- **NEVER compact during:** active TDD cycle, mid-validation, mid-review
- **Preserve across compaction:** task file path, state.md path, current step, branch name, `MODE`

## Exit Criteria (strict)

- [ ] `MODE` resolved
- [ ] Project rules read (if exists)
- [ ] preflight passed
- [ ] find-task found task
- [ ] .test-map.md available ($DEV_DIR/.test-map.md exists or generated)
- [ ] do-development complete
- [ ] validate full passed
- [ ] new-review passed (no violations or all fixed)
- [ ] review/fix ≤3 iterations
- [ ] verify-rules passed
- [ ] mark-task-done complete

## Exit Criteria (flow)

- [ ] `MODE` resolved as flow
- [ ] Project rules read (if exists)
- [ ] preflight passed
- [ ] find-task found task
- [ ] .test-map.md available
- [ ] do-development --flow done (COMPLETE — verify.sh exited zero violations; flow-metrics is NOT collected here)
- [ ] validate full passed (typecheck + lint + test — parity with strict)
- [ ] review-code --flow done (`$DEV_DIR/flow/report.md` written; this is the single flow-metrics collection point in the pipeline)
- [ ] fix-review --flow invoked iff summary had fails/warns (reuses review-code's data.json when fresh); else explicit "no fixes needed"
- [ ] mark-task-done complete
- [ ] PR group status printed

## Summary (strict)

```
Task Complete: {task-file} - {title}

| Step         | Result                         |
|--------------|--------------------------------|
| Mode         | strict                         |
| Preflight    | Clean working tree             |
| Find task    | {task-file}                    |
| Development  | TDD cycle complete             |
| Validate     | Typecheck, Tests, Lint pass    |
| Review       | No violations / All fixed      |
| Mark done    | state.md updated               |
| PR Group     | {pr-group}: {N}/{total} done   |

Changes
  {file}  (+{N}/-{M})  {brief description}
```

## Summary (flow)

```
Task Complete: {task-file} - {title}

| Step               | Result                         |
|--------------------|--------------------------------|
| Mode               | flow                           |
| Preflight          | Clean working tree             |
| Find task          | {task-file}                    |
| Development (flow) | DO-DEVELOPMENT COMPLETE        |
| Review (flow)      | Clean / {N} fails / {N} warns  |
| Fix (flow)         | {N} rounds — resolved / remaining
| Mark done          | state.md updated               |
| PR Group           | {pr-group}: {N}/{total} done   |

Changes
  {file}  (+{N}/-{M})  {brief description}
```

Use `git diff --stat` for change stats. Omit Review row if review.md wasn't created (strict) or fails/warns were both 0 (flow).
