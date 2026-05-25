# flow-init playbook

Execute these steps in order. The host project is the **target**; the framework lives at `_sh` (resolved below). All file edits and installs run against the target, never against the framework.

## 0. Resolve paths and args

Parse the user's args:
- `--target PATH` → `TARGET=PATH`; default: cwd.
- `--force` → `FORCE=1`; default: `0`.

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/flow-init/scripts/playbook.sh" ] || _sh="$HOME/.claude"
TARGET="${TARGET:-$(pwd)}"
```

Verify target has `package.json`:

```bash
[ -f "$TARGET/package.json" ] || { echo "flow-init: $TARGET has no package.json (TS/JS only for v1)"; exit 0; }
```

If missing, stop and tell the user.

## 1. Audit (read-only)

Call flow-doctor in JSON mode:

```bash
bash "$_sh/skills/flow-doctor/scripts/run.sh" --json --target="$TARGET"
```

Parse the JSON. Locate the entry in `languages[]` with `name == "ts"`. Read:

- `installs[]` — devDeps to add
- `configNotes[]` — manual ESLint / config edits (surfaced in final summary, NOT auto-applied)
- `packageManager` — pm (`npm` / `yarn` / `pnpm` / `bun`)
- `testRunner` — `vitest` | `jest` | `none`
- `existing.stryker` — bool
- `existing.scripts[]` — current package.json script names
- `existing.gitignoreManaged` — bool (sentinel block present)

Render a one-screen plan to the user:

```
flow-init audit — <TARGET>

  package manager : <pm>
  test runner     : <runner>
  missing deps    : <count>   (will run in phase 1 if approved)
  stryker config  : <present | absent>   (phase 2)
  package scripts : <added/already-present per script>   (phase 3)
  gitignore block : <present | absent>   (phase 4)

Walking 4 phases. Each phase asks before doing anything.
```

## 2. Phase 1 — Install missing devDependencies

If `installs[]` is empty: print `[phase 1/4] nothing to install — skipping` and go to phase 2.

Otherwise present:

```
[phase 1/4] Install missing devDependencies

Package manager: <pm>
Command:         <installCmd> <installs joined by space>

Packages:
  - <pkg1>
  - <pkg2>
  ...

Proceed? (yes / no)
```

Wait for user reply.

- On `yes`: run

  ```bash
  bash "$_sh/skills/flow-init/scripts/install-deps.sh" --target "$TARGET" --pm "<pm>" -- <installs...>
  ```

  Stream stdout/stderr to chat. If non-zero exit, surface the error and ask whether to continue to phase 2 anyway.

- On `no`: record `skipped` and continue. Remember this for the phase-3 warning if user later accepts phase 3.

## 3. Phase 2 — Scaffold stryker.config.json

If `existing.stryker` is `true`: print `[phase 2/4] stryker config present — skipping` and go to phase 3.

Otherwise present:

```
[phase 2/4] Scaffold stryker.config.json

Path:        <TARGET>/stryker.config.json
Test runner: <vitest | jest>  (from audit)
Package mgr: <pm>
Mutate glob: src/**/*.{ts,tsx}  (excludes tests, dist, build, node_modules, .stryker-tmp, .claude, .kimi, .claude)

Proceed? (yes / no)
```

On `yes`:

```bash
bash "$_sh/skills/flow-init/scripts/scaffold-stryker.sh" --target "$TARGET"
```

On `no`: record `skipped` and continue.

## 4. Phase 3 — Update package.json scripts

Compute the runner-aware coverage body: `vitest run --coverage` if `testRunner == "vitest"` (or `none`), else `jest --coverage`.

Three scripts are proposed:

| Name | Body |
|---|---|
| `test:coverage` | `vitest run --coverage` *or* `jest --coverage` |
| `mutate` | `stryker run` |
| `flow:metrics` | `bash .claude/skills/flow-metrics/scripts/collect.sh` |

Determine conflicts: for each proposed name, check `existing.scripts[]`. List which would be `added`, which `already-present` (skipped), which `overwrote` (only when `--force`).

If phase 1 was skipped AND `installs[]` was non-empty, prepend a warning:

```
WARNING: phase 1 was skipped, so the scripts below will reference packages that are not yet installed (vitest, stryker, etc.).
```

Present:

```
[phase 3/4] Add npm scripts to package.json

Plan:
  + test:coverage  -> <body>      (<status>)
  + mutate         -> stryker run (<status>)
  + flow:metrics   -> bash ...    (<status>)

Force-overwrite: <on | off>

Proceed? (yes / no)
```

On `yes`:

```bash
bash "$_sh/skills/flow-init/scripts/update-package-json.sh" \
    --target "$TARGET" \
    --runner "<testRunner>" \
    $( [ "$FORCE" = 1 ] && echo --force )
```

The script prints `added: [...] skipped: [...] overwrote: [...]` — show it to the user.

On `no`: record `skipped` and continue.

## 5. Phase 4 — Append managed block to .gitignore

Dry-run first to show the block:

```bash
bash "$_sh/skills/flow-init/scripts/update-gitignore.sh" --target "$TARGET" --dry-run
```

Present:

```
[phase 4/4] Update .gitignore

Status: <will create | will append | will replace existing managed block | no-op (block matches)>

Block:
<dry-run output>

Proceed? (yes / no)
```

If status is `no-op`, print `[phase 4/4] gitignore already up-to-date — skipping` and go to summary.

On `yes`:

```bash
bash "$_sh/skills/flow-init/scripts/update-gitignore.sh" --target "$TARGET"
```

On `no`: record `skipped`.

## 6. Final summary

Print:

```
FLOW-INIT COMPLETE

Phase 1 install-deps        : <done | skipped | no-op>
Phase 2 scaffold-stryker    : <done | skipped | no-op>
Phase 3 update-package-json : <done | skipped | no-op>
Phase 4 update-gitignore    : <done | skipped | no-op>

Manual follow-ups (from flow-doctor configNotes):
  - <each note verbatim, or "(none)">

Verify with:
  bash .claude/skills/flow-doctor/scripts/run.sh --target "<TARGET>"
```

## Edge cases

- **No `package.json` at target** → step 0 aborts.
- **No lockfile** → flow-doctor reports `packageManager: "npm"`. Tell the user before phase 1 in case they intended a different PM.
- **Malformed package.json** → phase 3 script exits non-zero with explicit error. Phases 1/2/4 remain safe; offer to skip phase 3.
- **Existing same-named scripts** → phase 3 skips them by default; only `--force` overwrites.
- **No ESLint config at all** → flow-doctor returns `configNotes` mentioning eslint; flow-init does NOT auto-write eslint config (flat-config vs `.eslintrc` variance is too lossy). Surface as manual follow-up.
- **`.gitignore` missing trailing newline** → `update-gitignore.sh` handles it (prepends `\n` before block).
- **Partial / re-run** → each script is idempotent; the user can safely re-run `/flow-init` at any time.
