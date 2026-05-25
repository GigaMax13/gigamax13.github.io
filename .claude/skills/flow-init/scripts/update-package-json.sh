#!/bin/bash
# update-package-json.sh — add flow-metrics scripts to package.json.
# Atomic write via tempfile + os.replace. Preserves 2-space indent.
# Idempotent: skips existing keys unless --force.
#
# Usage:
#   update-package-json.sh --target DIR [--runner vitest|jest|none] [--force]

set -eu

TARGET="."
RUNNER="vitest"
FORCE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --runner) RUNNER="$2"; shift 2 ;;
        --force)  FORCE=1; shift ;;
        *) echo "update-package-json: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

[ -f "$TARGET/package.json" ] || {
    echo "update-package-json: no package.json at $TARGET" >&2
    exit 1
}

# Normalize runner: "none" / empty → default vitest body (matches flow-doctor's
# install-vitest path when no runner is detected).
[ "$RUNNER" = "none" ] || [ -z "$RUNNER" ] && RUNNER="vitest"

TARGET="$TARGET" RUNNER="$RUNNER" FORCE="$FORCE" python3 - <<'PY'
import json, os, sys, tempfile

target = os.environ["TARGET"]
runner = os.environ["RUNNER"]
force  = os.environ["FORCE"] == "1"
path   = os.path.join(target, "package.json")

try:
    with open(path) as f:
        pkg = json.load(f)
except json.JSONDecodeError as e:
    sys.stderr.write(f"update-package-json: malformed JSON in {path}: {e}\n")
    sys.exit(1)

if runner == "jest":
    coverage_body = "jest --coverage"
else:
    coverage_body = "vitest run --coverage"

proposed = {
    "test:coverage": coverage_body,
    "mutate":        "stryker run",
    "flow:metrics":  "bash .claude/skills/flow-metrics/scripts/collect.sh",
}

scripts = pkg.setdefault("scripts", {})
added, skipped, overwrote = [], [], []
for k, v in proposed.items():
    if k in scripts:
        if force and scripts[k] != v:
            scripts[k] = v
            overwrote.append(k)
        else:
            skipped.append(k)
    else:
        scripts[k] = v
        added.append(k)

if not (added or overwrote):
    print(f"update-package-json: no changes (skipped: {skipped})")
    sys.exit(0)

# Atomic write: tempfile in same dir, fsync, os.replace.
fd, tmp = tempfile.mkstemp(prefix=".pkg-flow-", suffix=".json", dir=target)
try:
    with os.fdopen(fd, "w") as f:
        json.dump(pkg, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
except Exception:
    try: os.unlink(tmp)
    except FileNotFoundError: pass
    raise

print(f"update-package-json: added={added} skipped={skipped} overwrote={overwrote}")
PY
