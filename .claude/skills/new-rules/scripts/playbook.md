# new-rules playbook


# new-rules

Emit a minimal **`CLAUDE.md`** (open-standard, loaded by Claude Code, Kimi CLI, Codex, Cursor, …) plus a 1-line **`CLAUDE.md`** that imports it via `@CLAUDE.md`. One source of truth, zero duplication.

## Why lean

`CLAUDE.md` loads into context every session BEFORE the user types. Every line is a per-turn tax. Include **only** what the LLM cannot reliably derive by reading the code:

- project identity (`PROJECT_ID`), validation commands, boundaries (Always/Ask/Never)
- rule-loading mechanism pointer, project-specific safety notes

Cut everything else:
- Stack/framework conventions → `_rules/{lang}.md` (loaded on demand via `/load-rules`)
- Forbidden-pattern lists → lint config + `_rules/code-quality.md`
- Commit type table → `_rules/commit.md`
- Skill/agent frontmatter templates → visible in any `SKILL.md`
- Project structure tree → `ls` derives it

Target: `CLAUDE.md` ≤ 60 lines, `CLAUDE.md` = 1 line.

## Input

```bash
/new-rules $MY_PROJECT_ID
echo "$MY_PROJECT_ID" | /new-rules
```

**Parse:**
```bash
INPUT=$(cat)
PROJECT_ID=$(echo "$INPUT" | cut -d',' -f1 | xargs)
[ -z "$PROJECT_ID" ] && { echo "Usage: /new-rules <PROJECT_ID>"; exit 1; }
```

## Steps

### 1. Detect Project Structure

```bash
if [ -f "go.mod" ]; then
  LANG="Go"; FRAMEWORK=$(grep -oE 'cobra|gin|echo|chi|fiber' go.mod | head -1); [ -z "$FRAMEWORK" ] && FRAMEWORK="stdlib"; BINARY=$(basename "$(pwd)")
  PKG="go"; TYPECHECK="go vet ./..."; LINT="golangci-lint run"; TEST="go test ./..."; BUILD="go build -o $BINARY"
elif [ -f "package.json" ]; then
  LANG="TypeScript"
  if grep -q '"next"' package.json; then FRAMEWORK="Next.js"
  elif grep -q '"react"' package.json; then FRAMEWORK="React"
  elif grep -q '"@nestjs/core"' package.json; then FRAMEWORK="NestJS"
  elif grep -q '"express"' package.json; then FRAMEWORK="Express"
  else FRAMEWORK="Node.js"; fi
  [ -f "pnpm-lock.yaml" ] && PKG="pnpm" || { [ -f "yarn.lock" ] && PKG="yarn" || PKG="npm"; }
  TYPECHECK="tsc --noEmit"; LINT="eslint ."; TEST="$PKG test"; BUILD="$PKG build"
elif [ -f "Cargo.toml" ]; then
  LANG="Rust"; FRAMEWORK=$(grep -oE 'axum|actix|rocket|warp' Cargo.toml | head -1); [ -z "$FRAMEWORK" ] && FRAMEWORK="stdlib"
  PKG="cargo"; TYPECHECK="cargo check"; LINT="cargo clippy"; TEST="cargo test"; BUILD="cargo build --release"
elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
  LANG="Python"
  if grep -q 'fastapi' pyproject.toml requirements.txt 2>/dev/null; then FRAMEWORK="FastAPI"
  elif grep -q 'django' pyproject.toml requirements.txt 2>/dev/null; then FRAMEWORK="Django"
  elif grep -q 'flask' pyproject.toml requirements.txt 2>/dev/null; then FRAMEWORK="Flask"
  else FRAMEWORK="stdlib"; fi
  command -v uv >/dev/null && PKG="uv" || { command -v poetry >/dev/null && PKG="poetry" || PKG="pip"; }
  TYPECHECK="source .venv/bin/activate && mypy ."; LINT="source .venv/bin/activate && ruff check ."; TEST="source .venv/bin/activate && pytest"; BUILD="source .venv/bin/activate && python -m build"
else
  LANG="Unknown"; FRAMEWORK="Unknown"; PKG="?"; TYPECHECK="?"; LINT="?"; TEST="?"; BUILD="?"
fi
```

### 2. Load Template

Read `.claude/skills/new-rules/rules/{lang}.md` (lowercase) — it holds the placeholder skeleton for the language's Validation + Boundaries tables only.

### 3. Replace Placeholders

`{PROJECT_ID}`, `{FRAMEWORK}`, `{PKG}`, `{BINARY}`, `{TYPECHECK}`, `{LINT}`, `{TEST}`, `{BUILD}`

### 4. Write CLAUDE.md

Compose the final file in this order (≤ 60 lines total):

1. Language template (with placeholders replaced) — supplies `# Title`, `## Project ID`, `## Stack`, `## Validation`, `## Boundaries`
2. Optional `## Commits` block — one-line cross-reference to `_rules/commit.md`
3. Optional `## Safety` block — only project-specific notes; skip entirely if nothing to add

Generic safety (`rm -rf`, `--force`, etc.) and commit-type tables MUST NOT be embedded — Claude Code and Kimi CLI already know them.

Write via:
```bash
cat > CLAUDE.md << EOF
$BODY
EOF
```

### 5. Write CLAUDE.md

```bash
cat > CLAUDE.md << 'EOF'
@CLAUDE.md
EOF
```

Claude Code recursively expands `@CLAUDE.md` at session start (max 5 hops). Kimi CLI auto-loads `CLAUDE.md` directly at priority 1. Add a `## Claude Code` block below the import ONLY if a Claude-specific rule is actually needed.

### 6. Report Line Counts

```bash
echo "CLAUDE.md: $(wc -l < CLAUDE.md) lines"
echo "CLAUDE.md: $(wc -l < CLAUDE.md) lines"
```

Fail loudly if `CLAUDE.md > 60` lines — prompt the user to move content into `_rules/` instead.

## Exit Criteria

- [ ] Project analyzed (language, framework, package manager)
- [ ] Language template loaded from `rules/{lang}.md`
- [ ] Placeholders replaced
- [ ] `CLAUDE.md` written at project root, ≤ 60 lines
- [ ] `CLAUDE.md` written at project root, starts with `@CLAUDE.md`
- [ ] Line counts reported
- [ ] No embedded commit-type table, skill-frontmatter template, or generic safety list

## Modular Rule Files

In `.claude/skills/new-rules/rules/`:

| File | Role | Inclusion |
|------|------|-----------|
| `typescript.md` / `go.md` / `python.md` / `rust.md` | Skeleton with Validation + Boundaries tables | One per detected language |

Rule templates are intentionally ≤ 40 lines each — they inject **no** content beyond the minimum-viable table structure. Deep language conventions live in `.claude/skills/_rules/{lang}.md` and load on demand via `/load-rules`.
