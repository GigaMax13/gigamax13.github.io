#!/bin/bash
# update-gitignore.sh — manage a sentinel-delimited block in .gitignore for
# flow-metrics generated artifacts. Idempotent: creates, appends, or replaces.
#
# Usage:
#   update-gitignore.sh --target DIR [--dry-run]

set -eu

TARGET="."
DRY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --target)  TARGET="$2"; shift 2 ;;
        --dry-run) DRY=1; shift ;;
        *) echo "update-gitignore: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

GI="$TARGET/.gitignore"
BEGIN="# >>> flow-init managed >>>"
END="# <<< flow-init managed <<<"

read -r -d '' BLOCK <<BLOCK || true
$BEGIN
.dev/
.stryker-tmp/
coverage/
.nyc_output/
reports/mutation/
$END
BLOCK

if [ "$DRY" = 1 ]; then
    printf '%s\n' "$BLOCK"
    if [ -f "$GI" ] && grep -qF "$BEGIN" "$GI"; then
        # Compare existing block to proposed.
        existing="$(awk -v b="$BEGIN" -v e="$END" '
            $0==b {flag=1}
            flag {print}
            $0==e {flag=0}
        ' "$GI")"
        if [ "$existing" = "$BLOCK" ]; then
            echo "status: no-op (block already up to date)"
        else
            echo "status: will replace existing managed block"
        fi
    elif [ -f "$GI" ]; then
        echo "status: will append"
    else
        echo "status: will create .gitignore with managed block"
    fi
    exit 0
fi

# Create file with block if .gitignore is absent.
if [ ! -f "$GI" ]; then
    printf '%s\n' "$BLOCK" > "$GI"
    echo "update-gitignore: created $GI with managed block"
    exit 0
fi

# Replace existing block if sentinel present.
if grep -qF "$BEGIN" "$GI"; then
    GI="$GI" BEGIN="$BEGIN" END="$END" BLOCK="$BLOCK" python3 - <<'PY'
import os, re, sys, tempfile
gi, begin, end, block = os.environ["GI"], os.environ["BEGIN"], os.environ["END"], os.environ["BLOCK"]
with open(gi) as f:
    txt = f.read()
pat = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.DOTALL)
new = pat.sub(lambda _: block, txt, count=1)
if new == txt:
    print("update-gitignore: managed block already up-to-date")
    sys.exit(0)
fd, tmp = tempfile.mkstemp(prefix=".gi-flow-", dir=os.path.dirname(gi) or ".")
try:
    with os.fdopen(fd, "w") as f:
        f.write(new)
    os.replace(tmp, gi)
except Exception:
    try: os.unlink(tmp)
    except FileNotFoundError: pass
    raise
print(f"update-gitignore: replaced managed block in {gi}")
PY
    exit 0
fi

# Append. Ensure file ends with a newline first.
if [ -s "$GI" ] && [ "$(tail -c1 "$GI" | wc -l | tr -d ' ')" -eq 0 ]; then
    printf '\n' >> "$GI"
fi
printf '\n%s\n' "$BLOCK" >> "$GI"
echo "update-gitignore: appended managed block to $GI"
