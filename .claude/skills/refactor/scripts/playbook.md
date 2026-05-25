# refactor playbook


# refactor

Analyze against CLAUDE.md and refactor.

## Load Rules

Read project rules (`CLAUDE.md`, first found in project root). Extract `PROJECT_ID`.

**Resolve rules directory** (first match wins):
```bash
for d in .claude/skills/_rules .claude/skills/_rules "$HOME/.claude/skills/_rules" "$HOME/.kimi/skills/_rules"; do [ -d "$d" ] && echo "RULES_DIR=$d" && break; done
```

Read from `$RULES_DIR/`:
1. `guard-clauses.md`
2. `tdd.md`
3. `code-quality.md`
4. `project-{PROJECT_ID}.md` (if exists)
5. Language rules from project files:
   - `package.json` -> `react.md` (if `"react"` in deps) else `typescript.md`
   - `go.mod` -> `go.md`
   - `pyproject.toml` or `requirements.txt` -> `python.md`
   - `Cargo.toml` -> `rust.md`

**Report before proceeding:**
```
Rules loaded: guard-clauses.md, tdd.md, code-quality.md, project-{PROJECT_ID}.md, {language}.md
```
Note skipped files. Do NOT proceed until report is printed.

## Loop

```
/validate → refactor changes → /validate → [repeat max 3x]
```

## Steps

1. **Find ALL violations**
   - Changed files: `git diff --name-only HEAD`
   - Run full validation
   - `MaxLines`: `wc -l <file>` for all files
   - `Forbidden`: grep forbidden patterns everywhere
   - `Patterns`: verify required patterns everywhere
   - `SourceDirs`: check file locations

2. **Fix ALL violations** — entire codebase (unchanged files, unrelated test failures, type/lint errors). Minimal changes, preserve logic.

3. **Re-run validate**
   ```
   /validate  # repeat max 3x; if issues remain after 3, report and ask user
   ```
   Must pass with ZERO errors.

4. **Mark Stop-hook opt-in** — refactor mutates code, so request the post-Stop verify-rules + validate-fast safety net:

   ```bash
   _sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"; [ -f "$_sh/skills/verify-rules/scripts/resolve-dev.sh" ] || _sh="$HOME/.claude"
   DEV_DIR="$(bash "$_sh/skills/verify-rules/scripts/resolve-dev.sh")"
   mkdir -p "$DEV_DIR" 2>/dev/null && touch "$DEV_DIR/.validate-fast-required" "$DEV_DIR/.verify-rules-required"
   ```

## Exit

- [ ] ALL violations fixed — all files, not just changed ones
- [ ] ALL test failures fixed — even unrelated
- [ ] ALL type/lint errors fixed — entire codebase
- [ ] Validate passes with ZERO errors
- [ ] Stop-hook opt-in markers written
