#!/bin/bash
# Emit TSV of applicable rules for a project, given its PROJECT_ID, the
# resolved RULES_DIR, and an optional list of changed files.
#
# Usage: applicable-rules.sh <PROJECT_ID> <RULES_DIR> [files...]
# Output (TSV): category<TAB>rule<TAB>trigger<TAB>existence
#   category:  shared | project | language | database
#   rule:      filename in RULES_DIR (e.g. "guard-clauses.md")
#   trigger:   human-readable reason the rule applies
#   existence: "ok" if RULES_DIR/<rule> exists, else "missing"
#
# When no files are passed, language detection falls back to root-level repo
# markers (package.json, pyproject.toml, go.mod, Cargo.toml) so the table
# still prints something meaningful on a clean tree.

set -e

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <PROJECT_ID> <RULES_DIR> [files...]" >&2
  exit 1
fi

PROJECT_ID="$1"
RULES_DIR="$2"
shift 2
FILES=("$@")

emit() {
  local category="$1" rule="$2" trigger="$3"
  local existence="missing"
  [ -f "$RULES_DIR/$rule" ] && existence="ok"
  printf '%s\t%s\t%s\t%s\n' "$category" "$rule" "$trigger" "$existence"
}

has_ext() {
  local ext="$1" f
  for f in "${FILES[@]}"; do
    case "$f" in *."$ext") return 0 ;; esac
  done
  return 1
}

# Shared rules — always loaded.
emit shared guard-clauses.md always
emit shared code-quality.md always
emit shared tdd.md always
emit shared security.md always

# Project rule — only emit if the file exists, else the (missing) marker
# would be misleading (project without a dedicated rule file is normal).
if [ -f "$RULES_DIR/project-${PROJECT_ID}.md" ]; then
  emit project "project-${PROJECT_ID}.md" "PROJECT_ID=${PROJECT_ID}"
fi

# Repo markers.
HAS_PACKAGE_JSON=0
HAS_REACT_DEP=0
HAS_PRISMA_DEP=0
HAS_DRIZZLE_DEP=0
if [ -f package.json ]; then
  HAS_PACKAGE_JSON=1
  grep -q '"react"' package.json 2>/dev/null && HAS_REACT_DEP=1
  grep -q '"@prisma/client"' package.json 2>/dev/null && HAS_PRISMA_DEP=1
  grep -q '"drizzle-orm"' package.json 2>/dev/null && HAS_DRIZZLE_DEP=1
fi

HAS_PRISMA_SCHEMA=0;   [ -f prisma/schema.prisma ] && HAS_PRISMA_SCHEMA=1
HAS_DRIZZLE_CONFIG=0;  [ -f drizzle.config.ts ]    && HAS_DRIZZLE_CONFIG=1
HAS_PYPROJECT=0;       { [ -f pyproject.toml ] || [ -f requirements.txt ]; } && HAS_PYPROJECT=1
HAS_GOMOD=0;           [ -f go.mod ]                && HAS_GOMOD=1
HAS_CARGO=0;           [ -f Cargo.toml ]            && HAS_CARGO=1

NO_FILES=0; [ "${#FILES[@]}" -eq 0 ] && NO_FILES=1

# Language rules.
if [ "$NO_FILES" -eq 1 ]; then
  # Repo-wide fallback: key off root markers only.
  [ "$HAS_PACKAGE_JSON" -eq 1 ] && emit language typescript.md 'package.json present (repo-wide)'
  [ "$HAS_REACT_DEP"   -eq 1 ] && emit language react.md      '"react" in package.json'
  [ "$HAS_PYPROJECT"   -eq 1 ] && emit language python.md     'pyproject.toml / requirements.txt present'
  [ "$HAS_GOMOD"       -eq 1 ] && emit language go.md         'go.mod present'
  [ "$HAS_CARGO"       -eq 1 ] && emit language rust.md       'Cargo.toml present'
else
  # File-driven selection.
  if has_ext ts || has_ext tsx; then
    emit language typescript.md '*.ts/*.tsx in changed files'
  fi
  if has_ext tsx; then
    emit language react.md '*.tsx in changed files'
  elif [ "$HAS_REACT_DEP" -eq 1 ] && { has_ext ts || has_ext jsx || has_ext js; }; then
    emit language react.md '"react" in package.json'
  fi
  has_ext py && emit language python.md '*.py in changed files'
  has_ext go && emit language go.md     '*.go in changed files'
  has_ext rs && emit language rust.md   '*.rs in changed files'
fi

# Database rule.
DB_TRIGGER=""
[ "$HAS_PRISMA_SCHEMA"  -eq 1 ] && DB_TRIGGER="prisma/schema.prisma present"
[ -z "$DB_TRIGGER" ] && [ "$HAS_PRISMA_DEP"    -eq 1 ] && DB_TRIGGER='"@prisma/client" in package.json'
[ -z "$DB_TRIGGER" ] && [ "$HAS_DRIZZLE_CONFIG" -eq 1 ] && DB_TRIGGER="drizzle.config.ts present"
[ -z "$DB_TRIGGER" ] && [ "$HAS_DRIZZLE_DEP"    -eq 1 ] && DB_TRIGGER='"drizzle-orm" in package.json'

if [ -z "$DB_TRIGGER" ] && [ "$NO_FILES" -eq 0 ]; then
  for f in "${FILES[@]}"; do
    base=$(basename "$f")
    case "$base" in
      *router*|*trpc*|*api*|*.prisma)
        DB_TRIGGER="filename hint ($base)"
        break ;;
    esac
  done
fi

[ -n "$DB_TRIGGER" ] && emit database database.md "$DB_TRIGGER"
