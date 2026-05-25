# new-commit playbook


# new-commit

Routes to sub-skill based on input. Invoke sub-skills via `/skill-name` (Skill tool).

## Workflow

1. Resolve rules dir (first match: `.claude/skills/_rules/`, `.claude/skills/_rules/`, `~/.claude/skills/_rules/`); read `$RULES_DIR/commit.md`.
2. Read project rules (`CLAUDE.md` or `CLAUDE.md`, first found).
3. Run `git status --porcelain` and `git ls-files --others --exclude-standard` to capture full change set.
4. Parse input per Input Format table.
5. Route via Orchestration Logic.

## Usage

```
/new-commit                                    # Interactive (default)
/new-commit workflow                           # Automatic
/new-commit workflow: make a single commit     # Automatic + instructions
/new-commit workflow no-linear: squash all     # Automatic, no Linear
/new-commit workflow linear:CURB-10: only tests # Automatic + issue
/new-commit make a single commit               # Interactive + instructions
/new-commit linear:CURB-10: auth changes only  # Interactive + issue
/new-commit --help
```

## Input Format

Input parsed as: `[mode:][instructions]`

| Pattern | Mode | Routes To | Instructions Passed |
|---------|------|-----------|---------------------|
| *(empty)* | Interactive | `commit-interactive` | *(none)* |
| `workflow` or `workflow:*` | Automatic | `commit-workflow` | Content after `workflow:` or none |
| `workflow no-linear` or `workflow no-linear:*` | Automatic | `commit-workflow < no-linear` | Content after `:` if present |
| `workflow linear:XXX` or `workflow linear:XXX:*` | Automatic | `commit-workflow` | Content after third `:` if present |
| `linear:XXX` or `linear:XXX:*` | Interactive | `commit-interactive < linear:XXX` | Content after second `:` if present |
| `find/create...`, `use...` | Interactive | `commit-interactive` | Full input |
| `*` | Interactive | `commit-interactive` | Full input as instructions |

## Orchestration Logic

```
Parse INPUT from invocation.

Match INPUT:
  --help|-h|help:
    Show help output
  workflow|workflow:*:
    Extract INSTRUCTIONS after "workflow:"
    /commit-workflow $INSTRUCTIONS (or no input if empty)
  workflow no-linear|workflow no-linear:*:
    Extract INSTRUCTIONS after "workflow no-linear:"
    /commit-workflow no-linear:$INSTRUCTIONS (or no-linear if empty)
  workflow linear:*:
    Extract ISSUE and INSTRUCTIONS from "workflow linear:ISSUE:INSTRUCTIONS"
    /commit-workflow linear:$ISSUE:$INSTRUCTIONS (or linear:$ISSUE if no instructions)
  find/create*|use*:
    /commit-interactive $INPUT
  linear:*:
    Extract ISSUE and INSTRUCTIONS from "linear:ISSUE:INSTRUCTIONS"
    /commit-interactive linear:$ISSUE:$INSTRUCTIONS (or linear:$ISSUE if no instructions)
  *:
    /commit-interactive $INPUT
```

## Sub-Skills

| Skill | Mode | Confirmation | Receives Instructions |
|-------|------|--------------|----------------------|
| `commit-interactive` | Interactive | Yes | Yes |
| `commit-workflow` | Automatic | No | Yes |

## Help Output

```
new-commit - Create conventional commits

USAGE:
  /new-commit [mode[:instructions]]

MODES:
  (no input)                      Interactive mode [DEFAULT]
  workflow[:instructions]         Automatic workflow mode
  workflow no-linear[:instr]      Workflow, no Linear refs
  workflow linear:XXX[:instr]     Workflow with specific issue
  linear:XXX[:instructions]       Interactive with issue ref

INSTRUCTIONS (examples):
  make a single commit            Squash all changes into one
  group by component              Group files by module/component
  focus on auth                   Only auth-related changes
  skip tests                      Exclude test files
  find/create issues ...          Auto-find Linear issues
  use XXX for commit N ...        Use specific issue IDs

RULES:
  * Default: ALWAYS asks for approval
  * Workflow: NO confirmation (unless instructed otherwise)
  * Instructions: Forwarded to sub-skill for interpretation
  * Issue refs: Only when explicitly requested
```

## Summary

Print after successful commit (omit Issue row if no Linear ref):

```
Commit Created

| Detail     | Value                 |
|------------|-----------------------|
| Hash       | {short-hash}          |
| Message    | {type}: {description} |
| Files      | {N} files changed     |
| Issue      | {TEAM-XXX}            |
```

## Exit Criteria

- [ ] Commit rules loaded (`$RULES_DIR/commit.md`)
- [ ] Project rules read (if exists)
- [ ] Input parsed, mode detected, instructions extracted
- [ ] Appropriate sub-skill invoked with instructions
- [ ] Sub-skill completed (orchestrators: this skill completes only THIS step — continue to the next)

## Completion

After commit created, print: `NEW-COMMIT COMPLETE`
