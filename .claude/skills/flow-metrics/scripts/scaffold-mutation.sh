#!/bin/bash
# scaffold-mutation.sh — write a minimal mutation-testing config for any
# language whose toolchain needs one and which the host project hasn't
# scaffolded yet. Idempotent: no-ops when config already exists.
#
# Used by lang-*.sh under FLOW_RUN_MUTATION=1, and runnable directly:
#   bash scaffold-mutation.sh [--target <dir>] [--lang ts|py|all]
#
# Languages:
#   ts  → writes stryker.config.json (testRunner auto-picked: vitest|jest)
#   py  → appends [tool.mutmut] block to pyproject.toml
#   go  → no scaffold (go-mutesting reads source directly)
#   rust → no scaffold (cargo-mutants reads Cargo.toml)

set -u

TARGET="."
LANG="all"
while [ $# -gt 0 ]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --lang)   LANG="$2"; shift 2 ;;
        *) shift ;;
    esac
done

cd "$TARGET" 2>/dev/null || { echo "scaffold-mutation: bad target $TARGET" >&2; exit 0; }

scaffold_ts() {
    [ -f "package.json" ] || return 0
    if ls stryker.config.* .stryker.conf.* stryker.conf.* 2>/dev/null | head -1 | grep -q .; then
        return 0  # already configured
    fi
    local runner="jest"
    if grep -q '"vitest"' package.json 2>/dev/null; then
        runner="vitest"
    fi
    local pm="npm"
    if [ -f "pnpm-lock.yaml" ] || [ -f "pnpm-workspace.yaml" ]; then
        pm="pnpm"
    elif [ -f "yarn.lock" ]; then
        pm="yarn"
    fi
    cat > stryker.config.json <<JSON
{
  "\$schema": "https://unpkg.com/@stryker-mutator/core/schema/stryker-schema.json",
  "packageManager": "$pm",
  "testRunner": "$runner",
  "reporters": ["json", "clear-text"],
  "coverageAnalysis": "perTest",
  "mutate": [
    "src/**/*.{ts,tsx}",
    "!src/**/*.{test,spec}.{ts,tsx}",
    "!src/**/*.d.ts",
    "!**/node_modules/**",
    "!**/dist/**",
    "!**/build/**",
    "!**/.next/**",
    "!**/.stryker-tmp/**",
    "!.claude/**",
    "!.kimi/**",
    "!.claude/**"
  ]
}
JSON
    echo "scaffold-mutation: wrote stryker.config.json (testRunner=$runner, packageManager=$pm)"
}

scaffold_py() {
    [ -f "pyproject.toml" ] || return 0
    if grep -q '\[tool\.mutmut\]' pyproject.toml 2>/dev/null; then
        return 0
    fi
    # Best-effort default: target src/ if present, else first top-level package.
    local paths="src/"
    [ -d "src" ] || paths=$(find . -maxdepth 2 -mindepth 1 -type d \
        ! -name '.*' ! -name 'tests' ! -name 'test' ! -name 'docs' \
        ! -name 'build' ! -name 'dist' ! -name '__pycache__' \
        2>/dev/null | head -1 | sed 's|^\./||')
    [ -n "$paths" ] || paths="."
    {
        echo ""
        echo "[tool.mutmut]"
        echo "paths_to_mutate = \"$paths\""
        echo "tests_dir = \"tests/\""
    } >> pyproject.toml
    echo "scaffold-mutation: appended [tool.mutmut] to pyproject.toml (paths=$paths)"
}

case "$LANG" in
    ts)  scaffold_ts ;;
    py)  scaffold_py ;;
    all) scaffold_ts; scaffold_py ;;
    go|rust) ;;  # no-op; tools work without config
    *) echo "scaffold-mutation: unknown --lang $LANG" >&2; exit 0 ;;
esac

exit 0
