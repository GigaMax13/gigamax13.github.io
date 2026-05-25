# map-linear playbook


# map-linear

Map parent tasks (with subtasks) to Linear issues and ensure proper task file structure.

## Prerequisites

- Project rules read (`CLAUDE.md`, first found)
- Linear CLI authenticated (`linear auth login`)
- State file at `$DEV_DIR/[PHASE]/state.md`
- Subtask files exist (`-NNN.md` suffix)

## Process

**Step 0: Resolve dev directory**
```bash
DEV_DIR=$(_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"; bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh")
```

**Step 1: Find latest phase**
```bash
ls -1 $DEV_DIR/ | sort -V | tail -1
```

**Step 2: Parse state.md** — Identify parents with subtasks ("Parent: XX-task-name" sections); group subtasks (`-NNN.md` pattern) by parent.

**Step 3: Check for existing parent task files**
```bash
[ -f "$DEV_DIR/[PHASE]/tasks/[parent-task-name].md" ] && echo "Exists" || echo "MISSING"
```

**Step 4: Create missing parent task files.** For each missing parent:
1. Get title from section header, subtask list from state.md
2. Check existing Linear issue: `linear issue list --all-states -A | grep -i "[task title]"`
3. Use existing if found (prioritize "Unused - Repurpose Later"), else create new
4. Create parent task file:
   ```markdown
   # Task: [Title]
   ## Description
   [Aggregated description from subtasks]
   ## Linear: [TEAM-XXX]
   ## Subtasks
   - [ ] XX-task-name-001.md - [Description]
   ## Exit Criteria
   [Aggregated from subtasks]
   ## Notes
   - All subtasks use this Linear issue ([TEAM-XXX])
   - Do not create separate Linear issues for subtasks
   ```

**Step 5: Update subtask files** — Add parent Linear reference:
```bash
if ! grep -q "CURB-[0-9]\+" "$SUBTASK_FILE"; then
  sed -i '' 's/- This subtask uses parent Linear task/- This subtask uses parent Linear task [TEAM-XXX]/' "$SUBTASK_FILE"
fi
```

**Step 6: Update state.md Linear mappings**
```markdown
## Linear Issue Mappings
| Parent Task  | Linear Issue | Description   |
| ------------ | ------------ | ------------- |
| XX-task-name | TEAM-XXX     | [Description] |
```

## Rules

1. Only parent tasks get Linear issues — subtasks never get their own
2. Reuse existing issues when possible
3. New issues marked "Backlog" unless explicitly starting work
4. Preserve "Unused" placeholders — mark for repurposing, don't delete
5. Update all files atomically: state.md, parent files, subtask files

## Exit Criteria

- [ ] Project rules read (if exists)
- [ ] All parent tasks with subtasks have parent files
- [ ] All parent files contain `Linear: TEAM-XXX`
- [ ] All subtask files reference parent Linear issue
- [ ] state.md contains Linear mappings table
- [ ] Linear issues in appropriate state (Backlog for new work)
