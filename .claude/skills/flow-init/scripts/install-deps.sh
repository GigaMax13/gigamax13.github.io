#!/bin/bash
# install-deps.sh — install missing dev dependencies for flow-metrics tooling.
# Idempotent: filters out packages already present in package.json.
#
# Usage:
#   install-deps.sh --target DIR --pm <npm|pnpm|yarn|bun> -- pkg1 pkg2 ...

set -eu

TARGET="."
PM="npm"
while [ $# -gt 0 ]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --pm)     PM="$2"; shift 2 ;;
        --)       shift; break ;;
        *) echo "install-deps: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

PKGS=("$@")
if [ "${#PKGS[@]}" -eq 0 ]; then
    echo "install-deps: no packages requested — nothing to do"
    exit 0
fi

[ -f "$TARGET/package.json" ] || {
    echo "install-deps: no package.json at $TARGET" >&2
    exit 1
}

# Filter to only packages not already in any dependency block.
MISSING=()
for pkg in "${PKGS[@]}"; do
    if python3 - "$pkg" "$TARGET/package.json" <<'PY'
import json, sys
name, path = sys.argv[1], sys.argv[2]
try:
    pkg = json.load(open(path))
except Exception:
    sys.exit(1)
for k in ("dependencies", "devDependencies", "peerDependencies", "optionalDependencies"):
    if name in (pkg.get(k) or {}):
        sys.exit(0)
sys.exit(1)
PY
    then
        :  # already present, skip
    else
        MISSING+=("$pkg")
    fi
done

if [ "${#MISSING[@]}" -eq 0 ]; then
    echo "install-deps: all requested packages already present in $TARGET/package.json"
    exit 0
fi

echo "install-deps: installing ${#MISSING[@]} package(s) via $PM in $TARGET"
echo "  packages: ${MISSING[*]}"

cd "$TARGET"
case "$PM" in
    pnpm) pnpm add -D "${MISSING[@]}" ;;
    yarn) yarn add -D "${MISSING[@]}" ;;
    bun)  bun add -d "${MISSING[@]}" ;;
    npm)  npm install -D "${MISSING[@]}" ;;
    *)    echo "install-deps: unknown package manager '$PM'" >&2; exit 2 ;;
esac
