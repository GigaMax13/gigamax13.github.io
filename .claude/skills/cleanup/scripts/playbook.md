# cleanup playbook


# cleanup

Remove development artifacts from changed files. Run after development, before review.

## Input

```
/cleanup                   # Clean all uncommitted changes
/cleanup <files>           # Clean specific files
```

## Workflow

### 1. Determine Files

```bash
if [ -n "$1" ]; then
    FILES="$1"
else
    FILES=$(git diff --name-only HEAD 2>/dev/null)
    [ -z "$FILES" ] && FILES=$(git diff --name-only)
fi
```

Skip non-code: `*.md`, `*.json`, `*.yml`, `*.yaml`, `*.toml`, `*.lock`, images, binaries.

### 2. Scan for Artifacts

**JS/TS** (`*.ts`, `*.tsx`, `*.js`, `*.jsx`):
```
console.log(    console.debug(    console.warn(    debugger;
// TODO         // FIXME          // HACK           // XXX
```

**Python** (`*.py`):
```
print(          breakpoint()      import pdb
# TODO          # FIXME
```

**Go** (`*.go`):
```
fmt.Println(    fmt.Printf(       log.Println(
// TODO         // FIXME
```

**Rust** (`*.rs`):
```
println!(       dbg!(             todo!(
// TODO         // FIXME
```

**All:** Commented-out code (3+ consecutive commented lines resembling code), unused imports.

### 3. Report Findings

```
==== CLEANUP REPORT ====

Found 7 artifacts in 3 files:

src/api/handler.ts:
  L15: console.log("user data:", data)     [debug-log]
  L42: // TODO: fix this later             [todo]
  L88-92: commented-out code block         [dead-code]

src/lib/utils.ts:
  L3: import { unused } from './old'       [unused-import]
  L67: console.debug("cache hit")          [debug-log]

src/auth/session.py:
  L12: breakpoint()                        [debugger]
  L45: # FIXME: race condition             [fixme]

==== END REPORT ====
```

### 4. Auto-Fix

- **debug-log/debugger**: Remove line (or full multiline statement)
- **todo/fixme**: Remove if trivial; flag substantive ones
- **dead-code**: Remove commented-out blocks
- **unused-import**: Remove import (adjust remaining on same line)

Re-scan after fixes to confirm clean.

### 5. Summary

```
Cleaned 7 artifacts from 3 files:
  - 3 debug logs removed
  - 1 debugger removed
  - 1 commented-out block removed (5 lines)
  - 1 unused import removed
  - 1 FIXME kept (substantive: "race condition" — needs resolution)
```

### 6. Mark Stop-hook opt-in

Cleanup edits real code (e.g. removes an unused import that turns out to be needed), so request the post-Stop verify-rules + validate-fast safety net:

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"
DEV_DIR="$(bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh")"
mkdir -p "$DEV_DIR" 2>/dev/null && touch "$DEV_DIR/.validate-fast-required" "$DEV_DIR/.verify-rules-required"
```

## Exit Criteria

- [ ] Files determined (from args or git diff)
- [ ] Non-code files skipped
- [ ] All artifact types scanned (per language)
- [ ] Findings reported with file, line, type
- [ ] Artifacts auto-fixed (or flagged if substantive)
- [ ] Re-scan confirms clean
- [ ] Stop-hook opt-in markers written
