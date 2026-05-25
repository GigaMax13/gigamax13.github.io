#!/bin/bash
# flow-doctor — audit host project for flow-metrics tooling.
# Read-only. Never modifies host project. Always exits 0.

set -u

TARGET="."
JSON=0
ARGS_RAW="${1:-}"
IFS=',' read -ra _PARTS <<< "$ARGS_RAW"
for p in "${_PARTS[@]}"; do
    p="${p# }"; p="${p% }"
    case "$p" in
        --target) ;;  # legacy positional, no-op
        --target=*) TARGET="${p#--target=}" ;;
        --json) JSON=1 ;;
        /*|.*|*) [ -d "$p" ] && TARGET="$p" ;;
    esac
done

cd "$TARGET" 2>/dev/null || { echo "flow-doctor: bad target '$TARGET'"; exit 0; }
ROOT="$(pwd)"

LANG_BLOBS=()

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- package manager (Node) ----------
node_pm() {
    if [ -f "$ROOT/pnpm-lock.yaml" ]; then echo "pnpm"
    elif [ -f "$ROOT/yarn.lock" ];     then echo "yarn"
    elif [ -f "$ROOT/bun.lockb" ];     then echo "bun"
    else echo "npm"
    fi
}

pm_install_cmd() {
    case "$1" in
        pnpm) echo "pnpm add -D" ;;
        yarn) echo "yarn add -D" ;;
        bun)  echo "bun add -d" ;;
        *)    echo "npm install -D" ;;
    esac
}

# ---------- detection helpers ----------
node_dep_present() {
    # arg1: dep name; checks dependencies + devDependencies in package.json
    python3 - "$1" "$ROOT/package.json" <<'PY' 2>/dev/null
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
}

node_bin_present() { [ -x "$ROOT/node_modules/.bin/$1" ]; }

eslint_rule_configured() {
    # arg1: rule name. Greps every eslint config-ish file at root.
    local rule="$1"
    local files=()
    for f in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts \
             .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yaml .eslintrc.yml; do
        [ -f "$ROOT/$f" ] && files+=("$ROOT/$f")
    done
    [ ${#files[@]} -gt 0 ] || return 1
    grep -q "$rule" "${files[@]}" 2>/dev/null
}

stryker_config_present() {
    ls "$ROOT"/stryker.config.* "$ROOT"/.stryker.conf.* "$ROOT"/stryker.conf.* 2>/dev/null | head -1 | grep -q .
}

py_pkg_present() {
    have python3 || return 1
    python3 -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('$1') else 1)" 2>/dev/null
}

# ---------- output helpers ----------
status_ok()   {
    OK_LIST+=("$1|$2")
    [ "$JSON" = 1 ] || printf 'OK    %-15s %s\n' "$1" "$2"
}
status_miss() {
    MISSING+=("$1|$2|$3|$4")
    [ "$JSON" = 1 ] || printf 'MISS  %-15s %s\n' "$1" "$2"
}
section() { [ "$JSON" = 1 ] || printf '\n# %s\n\n' "$1"; }

INSTALLS=()
CONFIG_NOTES=()

add_install() {
    local pkg
    for pkg in "$@"; do
        local seen=0
        for ex in "${INSTALLS[@]:-}"; do
            [ "$ex" = "$pkg" ] && seen=1 && break
        done
        [ $seen -eq 0 ] && INSTALLS+=("$pkg")
    done
}
add_note() { CONFIG_NOTES+=("$1"); }

# ---------- TypeScript / JavaScript ----------
audit_ts() {
    section "Flow tooling check — TypeScript / JavaScript"
    MISSING=()
    INSTALLS=()
    CONFIG_NOTES=()
    OK_LIST=()

    # detect test runner (for downstream consumers — flow-init etc.)
    local runner="none"
    if node_dep_present "vitest"; then
        runner="vitest"
    elif node_dep_present "jest"; then
        runner="jest"
    fi

    # coverage
    if node_dep_present "@vitest/coverage-v8" || node_dep_present "@vitest/coverage-istanbul"; then
        status_ok coverage "@vitest/coverage-v8 (devDep)"
    elif node_dep_present "jest"; then
        status_ok coverage "jest (built-in coverage)"
    else
        status_miss coverage "no @vitest/coverage-v8 or jest" coverage v8
        if node_dep_present "vitest"; then
            add_install "@vitest/coverage-v8"
        else
            add_install "vitest" "@vitest/coverage-v8"
            [ "$runner" = "none" ] && runner="vitest"
        fi
    fi

    # cyclomatic via eslint rule
    if eslint_rule_configured '"complexity"' || eslint_rule_configured "'complexity'" || eslint_rule_configured 'complexity'; then
        status_ok cyclomatic "ESLint \`complexity\` rule configured"
    elif node_dep_present "eslint"; then
        status_miss cyclomatic "ESLint \`complexity\` rule not configured" cyclomatic eslint
        add_note "eslint config — add to rules: complexity: [\"warn\", 10]"
    else
        status_miss cyclomatic "eslint not installed" cyclomatic eslint
        add_install "eslint"
        add_note "eslint config — add to rules: complexity: [\"warn\", 10]"
    fi

    # cognitive
    if node_dep_present "eslint-plugin-sonarjs"; then
        status_ok cognitive "eslint-plugin-sonarjs (devDep)"
        if ! eslint_rule_configured "cognitive-complexity"; then
            add_note "eslint config — add to rules: \"sonarjs/cognitive-complexity\": [\"warn\", 15]"
        fi
    else
        status_miss cognitive "eslint-plugin-sonarjs" cognitive sonarjs
        add_install "eslint-plugin-sonarjs"
        add_note "eslint config — add plugin sonarjs and rule: \"sonarjs/cognitive-complexity\": [\"warn\", 15]"
    fi

    # duplication
    if node_dep_present "jscpd" || node_bin_present "jscpd"; then
        status_ok duplication "jscpd (devDep)"
    else
        status_miss duplication "jscpd (currently fetched via npx)" duplication jscpd
        add_install "jscpd"
    fi

    # dep cycles
    if node_dep_present "madge" || node_bin_present "madge"; then
        status_ok dep-cycles "madge (devDep)"
    else
        status_miss dep-cycles "madge (currently fetched via npx)" dep-cycles madge
        add_install "madge"
    fi

    # mutation (opt-in)
    if node_dep_present "@stryker-mutator/core" || node_bin_present "stryker"; then
        if stryker_config_present; then
            status_ok mutation "@stryker-mutator/core + config"
        else
            status_ok mutation "@stryker-mutator/core (config will be auto-scaffolded)"
        fi
    else
        status_miss mutation "@stryker-mutator/core (opt-in via flow-metrics --include-mutation)" mutation stryker
        add_install "@stryker-mutator/core"
        if node_dep_present "vitest"; then
            add_install "@stryker-mutator/vitest-runner"
        elif node_dep_present "jest"; then
            add_install "@stryker-mutator/jest-runner"
        fi
        add_install "@stryker-mutator/typescript-checker"
    fi

    # file size — wc -l, always available
    status_ok file-size "wc -l (built-in)"

    local pm; pm="$(node_pm)"
    local cmd; cmd="$(pm_install_cmd "$pm")"

    # render install + config sections (human mode only)
    if [ "$JSON" = 0 ]; then
        if [ ${#INSTALLS[@]} -gt 0 ]; then
            section "To complete the kit"
            printf '%s %s\n' "$cmd" "${INSTALLS[*]}"
        fi
        if [ ${#CONFIG_NOTES[@]} -gt 0 ]; then
            section "Config init"
            local n
            for n in "${CONFIG_NOTES[@]}"; do
                printf -- '- %s\n' "$n"
            done
        fi
    else
        emit_lang_json_ts "$pm" "$cmd" "$runner"
    fi
}

# ---------- Python ----------
audit_py() {
    section "Flow tooling check — Python"
    MISSING=()
    OK_LIST=()
    local missing_pkgs=()
    if py_pkg_present "pytest" && py_pkg_present "pytest_cov"; then
        status_ok coverage "pytest + pytest-cov"
    else
        status_miss coverage "pytest / pytest-cov" coverage pytest
        py_pkg_present "pytest"     || missing_pkgs+=("pytest")
        py_pkg_present "pytest_cov" || missing_pkgs+=("pytest-cov")
    fi
    if py_pkg_present "radon"; then
        status_ok cyclomatic "radon (cyclomatic + maintainability)"
    else
        status_miss cyclomatic "radon" cyclomatic radon
        missing_pkgs+=("radon")
    fi
    status_ok cognitive "radon mi (proxy)"
    if py_pkg_present "pylint"; then
        status_ok duplication "pylint (--enable=duplicate-code)"
    else
        status_miss duplication "pylint" duplication pylint
        missing_pkgs+=("pylint")
    fi
    if py_pkg_present "pydeps"; then
        status_ok dep-cycles "pydeps"
    else
        status_miss dep-cycles "pydeps" dep-cycles pydeps
        missing_pkgs+=("pydeps")
    fi
    if py_pkg_present "mutmut"; then
        status_ok mutation "mutmut"
    else
        status_miss mutation "mutmut (opt-in)" mutation mutmut
        missing_pkgs+=("mutmut")
    fi
    status_ok file-size "wc -l (built-in)"

    local installer="pip install"
    [ -f "$ROOT/pyproject.toml" ] && grep -q '\[tool.poetry\]' "$ROOT/pyproject.toml" 2>/dev/null && installer="poetry add --group dev"
    [ -f "$ROOT/uv.lock" ] && installer="uv add --dev"

    if [ "$JSON" = 0 ]; then
        if [ ${#missing_pkgs[@]} -gt 0 ]; then
            section "To complete the kit"
            printf '%s %s\n' "$installer" "${missing_pkgs[*]}"
        fi
    else
        emit_lang_json_generic "py" "$installer" "${missing_pkgs[@]+"${missing_pkgs[@]}"}"
    fi
}

# ---------- Go ----------
audit_go() {
    section "Flow tooling check — Go"
    OK_LIST=()
    MISSING=()
    local missing=()
    status_ok coverage "go test -cover (built-in)"
    if have gocyclo; then status_ok cyclomatic "gocyclo (PATH)"
    else status_miss cyclomatic "gocyclo not on PATH" cyclomatic gocyclo; missing+=("github.com/fzipp/gocyclo/cmd/gocyclo@latest"); fi
    if have dupl; then status_ok duplication "dupl (PATH)"
    else status_miss duplication "dupl not on PATH" duplication dupl; missing+=("github.com/mibk/dupl@latest"); fi
    status_ok dep-cycles "go mod graph (built-in)"
    if have go-mutesting; then status_ok mutation "go-mutesting (PATH)"
    else status_miss mutation "go-mutesting (opt-in)" mutation go-mutesting; missing+=("github.com/zimmski/go-mutesting/cmd/go-mutesting@latest"); fi
    status_ok file-size "wc -l (built-in)"

    if [ "$JSON" = 0 ]; then
        if [ ${#missing[@]} -gt 0 ]; then
            section "To complete the kit"
            local m
            for m in "${missing[@]}"; do
                printf 'go install %s\n' "$m"
            done
        fi
    else
        emit_lang_json_generic "go" "go install" "${missing[@]+"${missing[@]}"}"
    fi
}

# ---------- Rust ----------
audit_rust() {
    section "Flow tooling check — Rust"
    OK_LIST=()
    MISSING=()
    local missing_subs=()
    if cargo --list 2>/dev/null | grep -q tarpaulin; then status_ok coverage "cargo-tarpaulin"
    else status_miss coverage "cargo-tarpaulin" coverage tarpaulin; missing_subs+=("cargo-tarpaulin"); fi
    status_ok cognitive "cargo clippy (cognitive_complexity lint)"
    if cargo --list 2>/dev/null | grep -q "^    modules"; then status_ok dep-cycles "cargo-modules"
    else status_miss dep-cycles "cargo-modules" dep-cycles modules; missing_subs+=("cargo-modules"); fi
    if cargo --list 2>/dev/null | grep -q "^    mutants"; then status_ok mutation "cargo-mutants"
    else status_miss mutation "cargo-mutants (opt-in)" mutation mutants; missing_subs+=("cargo-mutants"); fi
    status_ok file-size "wc -l (built-in)"

    if [ "$JSON" = 0 ]; then
        if [ ${#missing_subs[@]} -gt 0 ]; then
            section "To complete the kit"
            printf 'cargo install %s\n' "${missing_subs[*]}"
        fi
    else
        emit_lang_json_generic "rust" "cargo install" "${missing_subs[@]+"${missing_subs[@]}"}"
    fi
}

# ---------- JSON emitters ----------
# Records use \x1F (Unit Separator) between entries — present in neither
# field values nor JSON output. Within a record, fields are pipe-separated.

_join_us() {
    # Print "$@" joined with \x1F as a single string. Empty when no args.
    [ "$#" -gt 0 ] && printf '%s\x1f' "$@"
}

emit_lang_json_ts() {
    # args: pm install_cmd runner
    local pm="$1" cmd="$2" runner="$3"
    local stryker_present=false scripts_json="[]" gi_managed=false
    stryker_config_present && stryker_present=true
    if [ -f "$ROOT/.gitignore" ] && grep -qF '# >>> flow-init managed >>>' "$ROOT/.gitignore"; then
        gi_managed=true
    fi
    scripts_json="$(python3 - "$ROOT/package.json" <<'PY'
import json, sys
try:
    pkg = json.load(open(sys.argv[1]))
    print(json.dumps(sorted((pkg.get("scripts") or {}).keys())))
except Exception:
    print("[]")
PY
)"
    local miss_raw ok_raw inst_raw notes_raw
    miss_raw="$(_join_us "${MISSING[@]:-}")"
    ok_raw="$(_join_us "${OK_LIST[@]:-}")"
    inst_raw="$(_join_us "${INSTALLS[@]:-}")"
    notes_raw="$(_join_us "${CONFIG_NOTES[@]:-}")"
    local blob
    blob="$(MISSING_RAW="$miss_raw" OK_RAW="$ok_raw" INSTALLS_RAW="$inst_raw" NOTES_RAW="$notes_raw" \
            python3 - "ts" "$pm" "$cmd" "$runner" "$stryker_present" "$scripts_json" "$gi_managed" <<'PY'
import json, os, sys
name, pm, cmd, runner, stryker, scripts_json, gi_managed = sys.argv[1:8]
def split_us(raw):
    return [r for r in raw.split("\x1f") if r]
def parse_pipe(raw, min_fields):
    out = []
    for r in split_us(raw):
        parts = r.split("|")
        while len(parts) < min_fields: parts.append("")
        out.append(parts)
    return out
missing = [{"id": p[0], "detail": p[1]} for p in parse_pipe(os.environ.get("MISSING_RAW", ""), 4)]
ok      = [{"id": p[0], "detail": p[1]} for p in parse_pipe(os.environ.get("OK_RAW", ""), 2)]
installs     = split_us(os.environ.get("INSTALLS_RAW", ""))
config_notes = split_us(os.environ.get("NOTES_RAW", ""))
print(json.dumps({
    "name": name,
    "packageManager": pm,
    "installCmd": cmd,
    "testRunner": runner,
    "installs": installs,
    "configNotes": config_notes,
    "missing": missing,
    "ok": ok,
    "existing": {
        "stryker": stryker == "true",
        "scripts": json.loads(scripts_json),
        "gitignoreManaged": gi_managed == "true",
    },
}))
PY
)"
    LANG_BLOBS+=("$blob")
}

emit_lang_json_generic() {
    # args: name install_cmd [missing_pkgs...]
    local name="$1" cmd="$2"
    shift 2
    local miss_raw ok_raw inst_raw
    miss_raw="$(_join_us "${MISSING[@]:-}")"
    ok_raw="$(_join_us "${OK_LIST[@]:-}")"
    inst_raw="$(_join_us "$@")"
    local blob
    blob="$(MISSING_RAW="$miss_raw" OK_RAW="$ok_raw" INSTALLS_RAW="$inst_raw" \
            python3 - "$name" "$cmd" <<'PY'
import json, os, sys
name, cmd = sys.argv[1:3]
def split_us(raw):
    return [r for r in raw.split("\x1f") if r]
def parse_pipe(raw, min_fields):
    out = []
    for r in split_us(raw):
        parts = r.split("|")
        while len(parts) < min_fields: parts.append("")
        out.append(parts)
    return out
missing = [{"id": p[0], "detail": p[1]} for p in parse_pipe(os.environ.get("MISSING_RAW", ""), 4)]
ok      = [{"id": p[0], "detail": p[1]} for p in parse_pipe(os.environ.get("OK_RAW", ""), 2)]
installs = split_us(os.environ.get("INSTALLS_RAW", ""))
print(json.dumps({
    "name": name,
    "installCmd": cmd,
    "installs": installs,
    "configNotes": [],
    "missing": missing,
    "ok": ok,
}))
PY
)"
    LANG_BLOBS+=("$blob")
}

# ---------- main ----------
DETECTED=0
[ -f "$ROOT/package.json" ]    && audit_ts   && DETECTED=$((DETECTED+1))
{ [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/requirements.txt" ] || [ -f "$ROOT/setup.py" ]; } \
    && audit_py && DETECTED=$((DETECTED+1))
[ -f "$ROOT/go.mod" ]          && audit_go   && DETECTED=$((DETECTED+1))
[ -f "$ROOT/Cargo.toml" ]      && audit_rust && DETECTED=$((DETECTED+1))

if [ "$DETECTED" -eq 0 ] && [ "$JSON" = 0 ]; then
    echo "flow-doctor: no supported language detected at $ROOT"
    echo "  (looked for package.json, pyproject.toml, requirements.txt, setup.py, go.mod, Cargo.toml)"
fi

if [ "$JSON" = 1 ]; then
    ROOT="$ROOT" LANGS_JOINED="$(IFS=$'\x1F'; printf '%s' "${LANG_BLOBS[*]:-}")" \
    python3 - <<'PY'
import json, os
blobs = [b for b in os.environ.get("LANGS_JOINED", "").split("\x1f") if b.strip()]
langs = [json.loads(b) for b in blobs]
print(json.dumps({"root": os.environ["ROOT"], "languages": langs}, indent=2))
PY
fi

exit 0
