# new-prd playbook


# new-prd

Create text-only PRDs inside phase directories.

- **Single-phase**: one PRD from a brief description
- **Multi-phase**: analyze a plan document, split into multiple phase PRDs

## Critical Rules

- **TEXT ONLY** — no code, commands, schemas, API specs, file structures, or implementation details
- Describe WHAT the system does, NOT HOW to build it
- Each PRD must be self-contained (readable without the source plan)

## Input

**Linear shorthand:** `/new-prd TEAM-123`
- Single bare Linear ID. Project name is read from `CLAUDE.md` / `CLAUDE.md`, phase auto-named (`m1`). Auto-switches to multi-phase if the issue body contains 2+ Phase/Milestone headings.

**Single-phase:** `project_name, phase, description`
```bash
/new-prd Project Name, m1-core-mvp, Brief description of the phase
/new-prd Project Name, m1-core-mvp, TEAM-123       # brief fetched from Linear issue
```

**Multi-phase:** `project_name, file_path_or_stdin`
```bash
/new-prd Project Name, path/to/plan.md
/new-prd Project Name                              # plan via stdin
/new-prd Project Name, TEAM-123                    # plan body fetched from Linear issue
```

A bare Linear ID (regex `^[A-Z]+-[0-9]+$`) is auto-detected wherever a description or plan path would normally go. Behavior downstream is identical — only the source of the text differs.

## Mode Detection

```bash
INPUT=$(cat)
INPUT_TRIM=$(echo "$INPUT" | xargs)
LINEAR_RE='^[A-Z]+-[0-9]+$'
PHASE_MARKER_RE='^(##? +)?(Phase|Milestone) +[0-9]+|^### +m[0-9]+'

fetch_linear_json() {
  local id="$1" json
  json=$(linear issue view "$id" --json --no-comments 2>/dev/null)
  { [ -z "$json" ] || [ "$json" = "null" ]; } && \
    echo "Error: Could not fetch issue $id (run 'linear auth' if unauthenticated)" >&2 && exit 1
  printf '%s' "$json"
}
fetch_linear_body()  { fetch_linear_json "$1" | jq -r '.description // empty'; }
fetch_linear_title() { fetch_linear_json "$1" | jq -r '.title // empty'; }

# Shortcut: input is a single bare Linear ID, no commas
if echo "$INPUT_TRIM" | grep -qE "$LINEAR_RE" && ! echo "$INPUT" | grep -q ','; then
    LINEAR_ID="$INPUT_TRIM"
    BODY=$(fetch_linear_body "$LINEAR_ID")
    [ -z "$BODY" ] && echo "Error: Linear issue $LINEAR_ID has no description body" >&2 && exit 1
    TITLE=$(fetch_linear_title "$LINEAR_ID")
    PHASE_HITS=$(printf '%s\n' "$BODY" | grep -ciE "$PHASE_MARKER_RE" || true)
    PROJECT_NAME=""
    PROJECT_NAME_SOURCE="rules-file"
    if [ "${PHASE_HITS:-0}" -ge 2 ]; then
        MODE="multi"
        PLAN_SOURCE="linear:$LINEAR_ID"
        PLAN_BODY="$BODY"
    else
        MODE="single"
        PHASE="m1"
        DESCRIPTION_SOURCE="linear:$LINEAR_ID"
        DESCRIPTION="$BODY"
    fi
else
    PROJECT_NAME=$(echo "$INPUT" | cut -d',' -f1 | xargs)
    SECOND_FIELD=$(echo "$INPUT" | cut -d',' -f2 | xargs)
    THIRD_FIELD=$(echo "$INPUT" | cut -d',' -f3- | xargs)

    [ -z "$PROJECT_NAME" ] && \
        echo "Error: project name required (or pass a bare Linear ID like CURB-78)" >&2 && exit 1

    # Multi-phase triggers: 2nd field ends in .md, OR 2nd field is a bare Linear ID, OR input has >3 lines
    if echo "$SECOND_FIELD" | grep -q '\.md$' \
       || echo "$SECOND_FIELD" | grep -qE "$LINEAR_RE" \
       || [ "$(echo "$INPUT" | wc -l)" -gt 3 ]; then
        MODE="multi"
        if echo "$SECOND_FIELD" | grep -qE "$LINEAR_RE"; then
            PLAN_SOURCE="linear:$SECOND_FIELD"
            PLAN_BODY=$(fetch_linear_body "$SECOND_FIELD")
            [ -z "$PLAN_BODY" ] && echo "Error: Linear issue $SECOND_FIELD has no description body" >&2 && exit 1
        else
            PLAN_SOURCE="$SECOND_FIELD"   # file path or empty (stdin)
            PLAN_BODY=""                  # loaded from file/stdin downstream
        fi
    else
        MODE="single"
        PHASE="$SECOND_FIELD"
        [ -z "$PHASE" ] && echo "Error: phase required" >&2 && exit 1
        if echo "$THIRD_FIELD" | grep -qE "$LINEAR_RE"; then
            DESCRIPTION_SOURCE="linear:$THIRD_FIELD"
            DESCRIPTION=$(fetch_linear_body "$THIRD_FIELD")
            [ -z "$DESCRIPTION" ] && echo "Error: Linear issue $THIRD_FIELD has no description body" >&2 && exit 1
        else
            DESCRIPTION_SOURCE="inline"
            DESCRIPTION="$THIRD_FIELD"
        fi
    fi
fi
```

Read project rules (`CLAUDE.md`, first found).

- If `PROJECT_NAME` is empty (bare Linear ID input), derive it from the rules file:
  1. First H1 (`# X`) at the top of `CLAUDE.md` (then `CLAUDE.md`).
  2. Else first line matching `^Project:\s*(.+)$` or `^PROJECT_ID="?([^"]+)"?$`.
  3. Else the basename of `git rev-parse --show-toplevel`, prettified.
  4. If none yields a confident name, ASK the user once: "Could not derive a project name from CLAUDE.md / CLAUDE.md. What is the project name?"
- When `PROJECT_NAME_SOURCE=rules-file`, do NOT ask for a phase name — `m1` (single) or sequential `m{N}` (multi) is authoritative.

**Resolve dev directory:**
```bash
DEV_DIR=$(_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh")
```
Use `$DEV_DIR` in place of `./.dev` for all operations.

## Single-Phase Output

Create `$DEV_DIR/[PHASE]/PRD.md`:

```markdown
# [Project] - PRD

## Overview
Brief description of goals.

## Target Platform
Operating systems, high-level dependencies, general requirements.

## Core Features

### Feature 1
**Description:** What this feature enables for the user.
**Acceptance Criteria:**
- [ ] When [action], then [expected outcome]

## User Flows
Step-by-step user interactions from their perspective.

## Constraints & Assumptions
Performance, security, scalability expectations.

## Future Phases
Out of scope for this phase.

## Development Notes
High-level guidance, NOT implementation details.
```

## Multi-Phase Output

### Step 1: Save Plan
Save original plan to `$DEV_DIR/plan.md` (or `$DEV_DIR/{original_filename}` if from file).

If `PLAN_SOURCE` starts with `linear:`, write the fetched `PLAN_BODY` to `$DEV_DIR/plan.md` and prepend a single audit line so the origin is recoverable:
```bash
mkdir -p "$DEV_DIR"
{ echo "# Source: $PLAN_SOURCE"; echo; echo "$PLAN_BODY"; } > "$DEV_DIR/plan.md"
```
All downstream steps (boundary detection, naming, cross-reference) operate on `$DEV_DIR/plan.md` exactly as for file/stdin sources.

### Step 2: Analyze Phase Boundaries
Identify natural phases by:
1. **Explicit markers**: `Phase N:`, `Milestone N:`, `### mN:`, numbered top-level sections
2. **Dependency chains**: sections requiring outputs from prior sections
3. **Scope shifts**: transitions between subsystems, layers, or concerns
4. **Deliverable clusters**: groups of features forming a coherent, testable increment

### Step 3: Right-Size Phases
- **>5 features**: split by subsystem or dependency layer
- **1-2 features**: merge with adjacent phase sharing dependencies
- **3-5 features**: keep as-is

Each phase produces a deployable/testable increment.

### Step 4: Assign Names and Dependencies
- Name directories sequentially: `m1`, `m2`, `m3`, ...
- Map dependencies: prior phases (by `m{N}`) providing required outputs
- Root milestone has no dependencies

### Step 5: Create PRDs

For each phase, create `$DEV_DIR/m{N}/PRD.md`:

```markdown
# [Project] m{N}: [Short Name] - PRD

## Overview
What this phase delivers and why.

## Dependencies
Which prior phases are required and what is needed from them. "None" for root milestone.

## Target Platform
Operating systems, runtime, high-level dependencies.

## Core Features

### Feature 1
**Description:** What this feature enables for the user.
**Acceptance Criteria:**
- [ ] When [action], then [expected outcome]

## User Flows
Step-by-step user interactions from their perspective.

## Constraints & Assumptions
Performance, security, scalability expectations.

## Future Phases
What subsequent phases will build on this phase's outputs.

## Development Notes
High-level guidance, NOT implementation details.
```

### Step 6: Cross-Reference
Verify across all PRDs:
- Every dependency target (`m{N}`) exists as a phase
- No circular dependencies
- Sequential numbering, no gaps (m1, m2, m3, ...)
- All source plan content covered by at least one PRD

## Steps Summary

**Single-phase:**
1. Create `$DEV_DIR/[PHASE]/` directory
2. Write PRD.md, text only
3. Strip code/commands/specs
4. Verify every section answers "WHAT" not "HOW"

**Multi-phase:**
1. Save plan to `$DEV_DIR/plan.md`
2. Read project rules
3. Identify phase boundaries
4. Right-size phases (split >5 features, merge tiny phases)
5. Assign `m{N}` names, map dependencies
6. Create `$DEV_DIR/m{N}/PRD.md` for each phase
7. Cross-reference: dependency consistency, full coverage, no gaps
8. Strip code/commands/specs from each PRD

## Exit Criteria

**Single-phase:**
- [ ] Directory created at `$DEV_DIR/[PHASE]/`
- [ ] PRD.md created with text-only content
- [ ] No code, commands, schemas, or technical specs
- [ ] All content describes requirements, not implementation
- [ ] If `DESCRIPTION_SOURCE` was a Linear ID, the fetched description body was used; PRD content references no issue ID
- [ ] If input was a bare Linear ID and MODE=single, phase dir is `$DEV_DIR/m1/` and PROJECT_NAME was sourced from `CLAUDE.md` / `CLAUDE.md`

**Multi-phase:**
- [ ] Plan saved to `$DEV_DIR/plan.md`
- [ ] All phases have directories at `$DEV_DIR/m{N}/`
- [ ] Each phase has a PRD.md with all required sections
- [ ] Dependencies consistent (no dangling refs, no cycles)
- [ ] Phase numbering sequential (m1, m2, ..., no gaps)
- [ ] Every source plan section covered by at least one PRD
- [ ] No code, commands, schemas, or technical specs in any PRD
- [ ] Each PRD is self-contained (readable without the plan)
- [ ] If `PLAN_SOURCE` started with `linear:`, the fetched body was saved to `$DEV_DIR/plan.md` with a `# Source: linear:TEAM-XXX` header; PRDs reference no issue ID
- [ ] If input was a bare Linear ID and MODE=multi (auto-detected via 2+ Phase/Milestone markers), plan was saved with the `# Source: linear:<ID>` header and PRDs were generated per phase
