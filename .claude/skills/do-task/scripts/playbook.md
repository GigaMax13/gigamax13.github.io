# do-task playbook


# do-task

Complete a task using TDD. Orchestrates `new-branch` and `do-development`. Does NOT create commits.

## Mode

Parse input: if it contains `--flow` as a standalone token, strip it and set `MODE=flow`. Otherwise `MODE=strict`.

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/_shared/parse-mode.sh" ] || _sh="$HOME/.claude"
eval "$(bash "$_sh/skills/_shared/parse-mode.sh" "$INPUT")"
# MODE is now "flow" or "strict"; REMAINING is the input with --flow removed.
```

## Flow mode overrides

When `MODE=flow`:
- Step 4 invokes `/do-development --flow` (relaxed rules + `flow-metrics` gate; TDD still mandatory).
- Summary row "Development" becomes "Development (metric-gated)".

Strict prose below is the default path.

## Usage

```
/do-task CURB-123                             # strict (Linear issue)
/do-task feature, Implement user auth         # strict (spec)
/do-task --flow CURB-123                      # metric-gated
/do-task --flow feature, add exploratory tool # metric-gated (spec)
```

Input: Linear issue ID (e.g., `CURB-123`) OR `type, title` spec (type defaults to `feature`). Optionally prefixed with `--flow`.

## Rules

1. Invoke sub-skills via `/skill-name` (Skill tool)
2. Stop on ANY failure

## Workflow

**AUTONOMOUS:** proceed immediately after each sub-skill. Do NOT pause except at step 3 approval gate.

1. Read project rules (`CLAUDE.md`, first found) → print `[1/4] prerequisites done (3 left)`
2. Parse input (apply the Mode block above, then parse `$REMAINING`) → print `[2/4] input parsed (2 left) — MODE=$MODE`
3. Ask approval for branch creation. If approved: `/new-branch` → print `[3/4] branch created (1 left)`. If declined: stop.
4. Invoke development:
   - `MODE=strict` → `/do-development` — when it prints `DO-DEVELOPMENT COMPLETE`, print `[4/4] complete`
   - `MODE=flow` → `/do-development --flow` — when it prints `DO-DEVELOPMENT COMPLETE`, print `[4/4] complete`; on `DO-DEVELOPMENT INCOMPLETE` print `[4/4] complete (metrics failing — see $DEV_DIR/flow/report.md)`

## Compaction

- Safe after: step 3 (branch created)
- NEVER during: step 4 (active TDD)
- Preserve: task input, branch name, project rules path, `MODE`
- Safe to lose: rule file contents (re-read), Linear API responses (re-fetch)

## Step 2: Parse Input

```bash
INPUT=$(cat)

# Strip --flow (if present) before parsing the rest.
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/_shared/parse-mode.sh" ] || _sh="$HOME/.claude"
eval "$(bash "$_sh/skills/_shared/parse-mode.sh" "$INPUT")"
INPUT="$REMAINING"

if [[ "$INPUT" =~ ^[A-Z]+-[0-9]+$ ]]; then
    MODE_INPUT="linear"
    ISSUE_ID="$INPUT"
elif echo "$INPUT" | grep -q ','; then
    MODE_INPUT="spec"
    TYPE=$(echo "$INPUT" | cut -d',' -f1 | xargs)
    TITLE=$(echo "$INPUT" | cut -d',' -f2- | xargs)
    [ -z "$TYPE" ] && TYPE="feature"
else
    echo "Error: Provide either a Linear issue ID (TEAM-XXX) or a task spec: type, title (optionally prefixed with --flow)"
    exit 1
fi
```

(`MODE_INPUT` is the task-shape discriminator, independent from `$MODE` = strict|flow.)

## Step 3: Create Branch (Requires Approval)

**Linear Mode:**
1. Fetch issue title, set status to "In Progress"
2. Detect type from title prefix (fix/bug/hotfix → fix, refactor → refactor, test → test)
3. Ask: "Create branch for CURB-XXX: {title}?"
4. If approved: `/new-branch $TYPE, $TITLE, $ISSUE_ID`

```bash
ISSUE_JSON=$(linear issue view "$ISSUE_ID" --json 2>/dev/null)
TITLE=$(echo "$ISSUE_JSON" | jq -r '.title' 2>/dev/null)
linear issue update "$ISSUE_ID" -s "In Progress"

TYPE="feature"
echo "$TITLE" | grep -qiE "^(fix|bug|hotfix)" && TYPE="fix"
echo "$TITLE" | grep -qiE "^(refactor)" && TYPE="refactor"
echo "$TITLE" | grep -qiE "^(test)" && TYPE="test"
```

**Spec Mode:**
1. Ask: "Create branch for {type}: {title}?"
2. If approved: `/new-branch $TYPE, $TITLE`
3. Capture issue ID from output if Linear enabled.

## Step 4: Delegate

Pass `--flow` through when `$MODE=flow`:

```
if MODE=flow:
    if ISSUE_ID is set:
        /do-development --flow linear, $ISSUE_ID
    else:
        /do-development --flow $TYPE, $TITLE
else:
    if ISSUE_ID is set:
        /do-development linear, $ISSUE_ID
    else:
        /do-development $TYPE, $TITLE
```

## Exit Criteria

- [ ] `MODE` resolved (strict|flow)
- [ ] Project rules read (if exists)
- [ ] Input parsed (issue ID OR spec) with `--flow` consumed (if present)
- [ ] User approved branch creation
- [ ] Branch created via `new-branch`
- [ ] Linear issue set to "In Progress" (if applicable)
- [ ] Issue ID captured
- [ ] do-development completed in the resolved mode
- [ ] No steps silently skipped

## Summary

Print on success:

```
Task Complete: {title}

| Step                          | Result                    |
|-------------------------------|---------------------------|
| Mode                          | {strict|flow}             |
| Branch                        | {branch-name}             |
| Linear                        | {TEAM-XXX} in progress    |
| Development                   | TDD cycle complete        |
```

Include Linear row only if applicable. Development row label becomes "Development (metric-gated)" when `MODE=flow`. If flow do-development ended `INCOMPLETE`, replace Development row result with `metrics failing — see $DEV_DIR/flow/report.md`.
