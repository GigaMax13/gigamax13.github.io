# new-tasks playbook


# new-tasks

Create tasks from PRD. Auto-split oversized. For existing projects, analyze codebase for context-aware tasks.

## Input

```bash
/new-tasks            # auto-detect phase from .dev/
/new-tasks m1-core-mvp  # specify phase
```

## Resolve dev directory

```bash
DEV_DIR=$(_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh")
```

Use `$DEV_DIR` for ALL operations below.

## Parse Input

```bash
INPUT=$(cat)
PHASE=$(echo "$INPUT" | xargs)

if [ -z "$PHASE" ]; then
    PHASE=$(
        for dir in $(ls -1 $DEV_DIR/ 2>/dev/null | sort -V); do
            [ ! -d "$DEV_DIR/$dir" ] && continue
            prd_found=$(find "$DEV_DIR/$dir" -maxdepth 1 -iname "prd.md" 2>/dev/null | head -1)
            if [ -n "$prd_found" ] && [ ! -d "$DEV_DIR/$dir/tasks" ]; then
                echo "$dir"; break
            fi
        done
    )
    [ -z "$PHASE" ] && PHASE=$(ls -1 $DEV_DIR/ 2>/dev/null | sort -V | head -1)
fi
```

## Check Project Rules

Read `CLAUDE.md` (first found). Look for MaxLines.

## Analyze Project State (Non-Greenfield)

If project has existing code:

```bash
for f in package.json Cargo.toml pyproject.toml; do [ -f "$f" ] && echo "=== $f ===" && cat "$f"; done
[ -f go.mod ] && echo "=== go.mod ===" && head -50 go.mod

find . -type d \( -name "src" -o -name "lib" -o -name "app" -o -name "api" \) 2>/dev/null | head -20
find . -type f \( -name "*.rs" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) 2>/dev/null \
    | grep -v node_modules | grep -v target | grep -v dist | head -30
find . -type d \( -name "migrations" -o -name "db" -o -name "models" -o -name "entities" \
    -o -name "routes" -o -name "controllers" -o -name "handlers" -o -name "endpoints" \
    -o -name "tests" -o -name "__tests__" -o -name "spec" \) 2>/dev/null | head -20
find . -type f \( -name "*.sql" -o -name "schema.prisma" -o -name "*.migration" \) 2>/dev/null | head -10
```

## Output

Creates in phase folder:
- `state.md` — task tracking (only source of truth)
- `tasks/NN-task.md` — standard tasks
- `tasks/NN-task-NNN.md` — subtasks (oversized split)

## PR Grouping

- Cohesion: related files/features in same PR
- Size: ~400 changed lines max; single feature stays together if slightly larger
- Max 4 tasks per PR group; kebab-case names (e.g., `setup-auth-middleware`)

## state.md Format

**CRITICAL:** Task names MUST match task file names exactly.

```markdown
# Phase X: [Name]

## M1: Auth Backend

<!-- PR: setup-auth-middleware -->
- [ ] 01-add-auth-types.md
- [ ] 02-implement-middleware.md

<!-- PR: auth-error-handling -->
- [ ] 03-auth-error-types.md
- [ ] 04-error-middleware.md
```

Rules: exact filename, no descriptions, `[x]`/`[ ]` status, subtasks tracked via parent, every task under a `<!-- PR: {name} -->` comment.

## Task File Format

```markdown
# Task: [Name]

## Description
## Acceptance Criteria
- [ ] Criterion 1
## Files
## Dependencies
## Analysis Notes
<!-- Non-greenfield: existing code, patterns to follow, integration points -->
Linear: [ID]
PR Group: [pr-group-name]
```

Subtask: same structure with `## Parent Task` and `Linear: [ID] (parent)`.

## Task Creation Guidelines

**Greenfield:** Create from PRD requirements, establish foundational patterns.

**Existing projects:** Each task MUST include in Analysis Notes:
1. Existing Code to Reuse: files, modules, utilities
2. Patterns to Follow: naming, structure, conventions
3. Integration Points: where new code connects
4. Migration Considerations: if modifying schemas/data
5. Test Strategy: how to test with existing setup

Prefer modifying existing files over creating new ones. Group related changes. Identify prerequisite tasks for schema changes.

## Split Criteria

Split if: >3 files, >1 content type, cross-layer, or >MaxLines.

Strategies: by content type, operation (CRUD), dependency chain, component, codebase area. Naming: `NN-task-001.md`, `NN-task-002.md`.

## Workflow

```
Find phase with PRD.md but no tasks/
Read PRD, check project rules for MaxLines
IF existing code: Analyze project state
Plan sequential tasks (with analysis for existing projects)
Group tasks into PR-sized chunks
Split oversized tasks
Create task files (with Analysis Notes for existing projects)
Create state.md with grouped subtasks
/map-linear  # if subtasks exist
```

## Exit

- [ ] tasks/ directory created
- [ ] All tasks created with proper naming
- [ ] Oversized tasks split
- [ ] state.md with todo list
- [ ] For existing projects: Analysis Notes included
- [ ] Every task assigned to a PR group (in state.md and task file)
- [ ] PR groups have <=4 tasks each
- [ ] map-linear done (if subtasks exist)
