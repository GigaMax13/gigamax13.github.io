---
name: verify-rules
description: Grep-based gate: file size, forbidden tokens, dead exports.
model: haiku
---


# verify-rules

Deterministic mechanical rule verification. Complements (not replaces) `/review-code` and `/validate`. Shell-only via `scripts/verify.py` — works in hooks, outside any venv, on Claude and Kimi harnesses.

**Called by:** `do-development` (pre-COMPLETE gate), `new-review` (pre-`review-code` gate), `fix-review` (post-fix re-check), `run-task` (terminal gate), plus `PostToolUse` + `Stop` hooks.

## What it checks

Rules are declared in `verify-rules:start … verify-rules:end` HTML comment blocks inside `_rules/*.md`. Directives + syntax + rule-file discovery: see `scripts/RULES-DSL.md`.

## Input

```bash
/verify-rules                          # default: all uncommitted changed files
/verify-rules --diff                   # explicit (same as default)
/verify-rules --touched                # files from last hook step (CLAUDE_TOOL_FILE or last git diff)
/verify-rules file1.ts file2.py ...    # explicit list
echo "file1.ts file2.py" | /verify-rules
```

## Workflow

**Step 1 — Target files:** explicit args if given; `--touched` reads `$CLAUDE_TOOL_FILE` or falls back to last git diff; default collects all uncommitted code files.

**Step 2 — Run:**

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/verify-rules/scripts/verify.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/verify-rules/scripts/verify.sh" <files...>
```

`verify.sh` resolves SKILLS_HOME + PROJECT_ROOT (via `resolve-paths.sh`), walks rule files for blocks, runs directives against every target file.

**Step 3 — Output:** `DEV_DIR` exported by `resolve-paths.sh`.

- Violations: prints `==== VERIFY-RULES VIOLATIONS ====` + `file:line  rule  message`, writes `$DEV_DIR/verify-rules.md`, prints `VERIFY-RULES FAILED: N violation(s)`, exits **2** (blocking).
- Clean: prints `VERIFY-RULES PASSED`, removes `$DEV_DIR/verify-rules.md`, exits **0**.

## Exit Criteria

- [ ] Target files resolved (args, --touched, or default diff)
- [ ] All `verify-rules` blocks parsed from rule files
- [ ] Every applicable directive executed against every target file
- [ ] Violations written to `$DEV_DIR/verify-rules.md` OR file removed if clean
- [ ] Exit code 0 on success, 2 on violations (blocking for hooks)
- [ ] Printed `VERIFY-RULES PASSED` or `VERIFY-RULES FAILED: N violation(s)`
