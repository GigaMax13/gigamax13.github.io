# load-rules playbook


# load-rules

Load project rules once and output a structured envelope for downstream skills (review-code, do-development, validate).

## Input

```bash
/load-rules ts,tsx,prisma   # targeted
/load-rules py
/load-rules                 # all detected rules
echo "ts,tsx" | /load-rules
```

Comma-separated file extensions. Empty = load all detected rules.

## Path Resolution

Resolve `RULES_DIR` (first match wins):

```bash
for d in .claude/skills/_rules .claude/skills/_rules "$HOME/.claude/skills/_rules" "$HOME/.kimi/skills/_rules"; do [ -d "$d" ] && echo "RULES_DIR=$d" && break; done
```

Use resolved `RULES_DIR` for all rule reads.

## Workflow

**Step 1 — Read Project Config.** Read `CLAUDE.md` (fall back to `CLAUDE.md`). Extract `PROJECT_ID` from `PROJECT_ID="..."` and validation commands (TypeCheck, Lint, Test rows).

**Step 2 — Detect Stack**

- `package.json` → typescript; `"react"` in deps → also react
- `go.mod` → go
- `pyproject.toml` or `requirements.txt` → python
- `Cargo.toml` → rust
- `prisma/schema.prisma` or `"@prisma/client"` → prisma
- `drizzle.config.ts` or `"drizzle-orm"` → drizzle

**Step 3 — Select Rules**

If extensions provided, use targeted matrix (merge across extensions; each rule loaded at most once):

| Extension | Rules |
|---|---|
| `test.ts`, `test.tsx`, `spec.*` | tdd.md + typescript.md + project-{ID}.md |
| `prisma` | database.md |
| `tsx` (non-test) | code-quality.md + guard-clauses.md + typescript.md + react.md + project-{ID}.md |
| `ts` (non-test) | code-quality.md + guard-clauses.md + typescript.md + project-{ID}.md |
| `py` | code-quality.md + guard-clauses.md + python.md + project-{ID}.md |
| `go` | code-quality.md + guard-clauses.md + go.md + project-{ID}.md |
| `rs` | code-quality.md + guard-clauses.md + rust.md + project-{ID}.md |

`typescript.md` always loaded for `.ts`/`.tsx`; `react.md` is additive, never a replacement.

If no extensions, load all detected: `guard-clauses.md`, `tdd.md`, `code-quality.md`, `project-{PROJECT_ID}.md` (if exists), language rules, database rules (if ORM detected).

**Step 4 — Read Rule Files** via Read tool from `$RULES_DIR/`.

**Step 5 — Output Envelope**

```
==== RULES ENVELOPE ====
PROJECT_ID: {id}
STACK: {language}[, {orm}]
RULES_LOADED: {comma-separated filenames}

VALIDATION:
  typecheck: {command}
  lint: {command}
  test: {command}

RULES_CONTENT:
--- guard-clauses.md ---
{content}
--- end ---

--- code-quality.md ---
{content}
--- end ---

... (one block per loaded rule)

==== END RULES ====
```

Then print: `LOAD-RULES COMPLETE`

## Exit Criteria

- [ ] PROJECT_ID extracted from CLAUDE.md
- [ ] Language stack detected
- [ ] Rules selected based on extensions (targeted) or all (default)
- [ ] Rule files read via Read tool
- [ ] Envelope output with PROJECT_ID, validation commands, and rule content
