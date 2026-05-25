#!/usr/bin/env python3
"""Deterministic rule verification gate.

Parses <!-- verify-rules:start ... verify-rules:end --> blocks from rule
files and checks target source files against declared directives.

Stdlib only. Works outside any venv. Invoked by:
  - /verify-rules slash command (via verify.sh wrapper)
  - PostToolUse / Stop hooks on Claude and Kimi
  - do-development / new-review / fix-review / run-task skills

Exit codes:  0 = passed, 2 = violations found, 1 = internal error
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

CODE_EXTS = {
    "py", "js", "ts", "jsx", "tsx", "go", "rs", "java", "rb", "php",
    "c", "cpp", "h", "hpp", "swift", "kt", "scala", "sh", "bash",
    "zsh", "sql", "prisma",
}
EXCLUDE_DIRS = {
    "node_modules", "vendor", ".venv", "venv", "__pycache__",
    ".pytest_cache", "target", "dist", "build", ".git", ".idea",
    ".vscode", ".next", ".turbo", "out", ".stryker-tmp",
    ".sync-manifest.json",
}
BLOCK_RE = re.compile(
    r"<!--\s*verify-rules:start\s*(.*?)\s*verify-rules:end\s*-->",
    re.DOTALL,
)


@dataclass
class Directive:
    kind: str
    value: str
    exts: set[str] = field(default_factory=set)
    excludes: list[str] = field(default_factory=list)
    message: str = ""
    source: str = ""


@dataclass
class Violation:
    file: str
    line: int
    rule: str
    message: str

    def render(self) -> str:
        loc = f"{self.file}:{self.line}" if self.line > 0 else self.file
        return f"{loc}  [{self.rule}]  {self.message}"


# -- Path Resolution --

def _resolve_project_root() -> Path:
    """Resolve PROJECT_ROOT — where the host project lives."""
    for var in ("AGENTS_PROJECT_ROOT", "CLAUDE_PROJECT_DIR"):
        env = os.environ.get(var)
        if env:
            return Path(env).resolve()
    cwd = Path.cwd().resolve()
    for p in [cwd, *cwd.parents]:
        if (p / "CLAUDE.md").is_file() or (p / "CLAUDE.md").is_file():
            return p
        if (p / ".git").is_dir():
            return p
    return cwd


def _resolve_skills_home(project_root: Path) -> Path:
    """Resolve SKILLS_HOME — where skills/rules/scripts live.
    Priority: env var > local project dir > script location > global ~/.claude"""
    env = os.environ.get("AGENTS_SKILLS_HOME")
    if env:
        return Path(env).resolve()
    for candidate in (".agents", ".claude", ".kimi"):  # sync:keep
        if (project_root / candidate / "skills" / "_rules").is_dir():
            return project_root / candidate
    script_dir = Path(__file__).resolve().parent
    for p in [script_dir, *script_dir.parents]:
        if p.name in (".claude", ".kimi", ".agents"):  # sync:keep
            return p
    home = Path.home()
    for candidate in (".claude", ".kimi"):
        if (home / candidate / "skills" / "_rules").is_dir():
            return home / candidate
    return project_root / ".claude"


def _resolve_dev_dir(project_root: Path, skills_home: Path) -> Path:
    """Resolve DEV_DIR — where .dev/ artifacts live.
    Priority: env var > existing project .dev/ > skills_home/.dev"""
    env = os.environ.get("AGENTS_DEV_DIR")
    if env:
        return Path(env).resolve()
    project_dev = project_root / ".dev"
    if project_dev.is_dir():
        return project_dev
    return skills_home / ".dev"


def _rule_dirs(skills_home: Path, project_root: Path) -> list[Path]:
    """Build ordered rule directory candidates. Local dirs first."""
    seen: list[Path] = []
    for name in (".agents", ".claude", ".kimi"):  # sync:keep
        p = (project_root / name / "skills" / "_rules").resolve()
        if p not in seen:
            seen.append(p)
    p = (skills_home / "skills" / "_rules").resolve()
    if p not in seen:
        seen.append(p)
    home = Path.home()
    for name in (".claude", ".kimi"):
        p = (home / name / "skills" / "_rules").resolve()
        if p not in seen:
            seen.append(p)
    return seen


# -- Parsing --

def _parse_kv_tail(tail: str) -> dict[str, str]:
    out: dict[str, str] = {}
    msg_match = re.search(r"\bmessage:(.*)$", tail)
    if msg_match:
        out["message"] = msg_match.group(1).strip()
        tail = tail[: msg_match.start()].strip()
    for tok in tail.split():
        if ":" in tok:
            k, v = tok.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def _parse_exts_and_excludes(kv: dict[str, str]) -> tuple[set[str], list[str]]:
    exts = {e.strip() for e in kv.get("ext", "").split(",") if e.strip()}
    excludes = [e.strip() for e in kv.get("exclude", "").split(",") if e.strip()]
    return exts, excludes


def parse_directive(line: str, source: str) -> Directive | None:
    line = line.strip()
    if not line or line.startswith("#"):
        return None
    for prefix in ("max-lines:", "forbid:"):
        if not line.startswith(prefix):
            continue
        rest = line[len(prefix):].strip()
        parts = rest.split(None, 1)
        if not parts:
            return None
        value = parts[0]
        kv = _parse_kv_tail(parts[1] if len(parts) > 1 else "")
        exts, excludes = _parse_exts_and_excludes(kv)
        kind = prefix.rstrip(":")
        default_msg = f"file exceeds {value} lines" if kind == "max-lines" else f"forbidden pattern: {value}"
        return Directive(
            kind=kind, value=value, exts=exts, excludes=excludes,
            message=kv.get("message", default_msg), source=source,
        )
    return None


def _read_project_id(root: Path) -> str | None:
    for name in ("CLAUDE.md", "CLAUDE.md"):
        p = root / name
        if not p.is_file():
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        m = re.search(r'PROJECT_ID\s*=\s*"?([A-Za-z0-9_\-]+)"?', text)
        if m:
            return m.group(1)
    return None


def load_directives(skills_home: Path, project_root: Path) -> list[Directive]:
    directives: list[Directive] = []
    rule_dir: Path | None = None
    for candidate in _rule_dirs(skills_home, project_root):
        if candidate.is_dir():
            rule_dir = candidate
            break
    if rule_dir is None:
        return directives
    project_id = _read_project_id(project_root)
    active_project_rule = f"project-{project_id}.md" if project_id else None
    for md in sorted(rule_dir.glob("*.md")):
        if md.name.startswith("project-") and md.name != active_project_rule:
            continue
        try:
            text = md.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for block in BLOCK_RE.finditer(text):
            for raw in block.group(1).splitlines():
                d = parse_directive(raw, str(md.name))
                if d:
                    directives.append(d)
    return directives


# -- File collection --

def _is_excluded(path: str) -> bool:
    return any(p in EXCLUDE_DIRS for p in Path(path).parts)


def _ext_of(path: str) -> str:
    return Path(path).suffix.lstrip(".")


def collect_default_files(root: Path) -> list[str]:
    """Return uncommitted code files relative to root."""
    try:
        diff = subprocess.run(
            ["git", "diff", "--name-only", "HEAD"],
            cwd=root, capture_output=True, text=True, check=False,
        ).stdout.splitlines()
        cached = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "HEAD"],
            cwd=root, capture_output=True, text=True, check=False,
        ).stdout.splitlines()
        untracked = subprocess.run(
            ["git", "ls-files", "--others", "--exclude-standard"],
            cwd=root, capture_output=True, text=True, check=False,
        ).stdout.splitlines()
    except FileNotFoundError:
        return []
    merged = sorted(set(diff + cached + untracked))
    return [f for f in merged if f and _ext_of(f) in CODE_EXTS and not _is_excluded(f)]


def collect_touched_files(root: Path) -> list[str]:
    env = os.environ.get("CLAUDE_TOOL_FILE") or os.environ.get("KIMI_TOOL_FILE")
    if env:
        return [f for f in env.split(os.pathsep) if f]
    return collect_default_files(root)


# -- Checks --

def check_file(path: Path, rel: str, directives: list[Directive]) -> list[Violation]:
    violations: list[Violation] = []
    ext = _ext_of(rel)
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return violations
    lines = content.splitlines()
    for d in directives:
        if d.exts and ext not in d.exts:
            continue
        if any(ex in rel for ex in d.excludes):
            continue
        if d.kind == "max-lines":
            try:
                limit = int(d.value)
            except ValueError:
                continue
            if len(lines) > limit:
                violations.append(Violation(
                    file=rel, line=len(lines), rule=f"max-lines:{limit}",
                    message=f"{d.message} (actual: {len(lines)} lines) — {d.source}",
                ))
        elif d.kind == "forbid":
            try:
                rx = re.compile(d.value)
            except re.error:
                continue
            for idx, line in enumerate(lines, start=1):
                if "verify-rules:" in line:
                    continue
                if rx.search(line):
                    violations.append(Violation(
                        file=rel, line=idx, rule=f"forbid:{d.value}",
                        message=f"{d.message} — {d.source}",
                    ))
                    break
    return violations


# -- Main --

def _write_output(output_file: Path, violations: list[Violation]) -> None:
    output_file.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# verify-rules violations", ""]
    for v in violations:
        lines.append(f"- {v.render()}")
    output_file.write_text("\n".join(lines) + "\n")


def _emit_json(violations: list[Violation]) -> None:
    payload = {"violations": [
        {"file": v.file, "line": v.line, "rule": v.rule, "message": v.message}
        for v in violations
    ]}
    print(json.dumps(payload))


def _exit_clean(output_file: Path, json_out: bool, msg: str) -> int:
    if output_file.exists():
        output_file.unlink()
    if json_out:
        _emit_json([])
    else:
        print(msg)
    return 0


def main(argv: list[str]) -> int:
    project_root = _resolve_project_root()
    skills_home = _resolve_skills_home(project_root)
    os.chdir(project_root)
    dev_dir = _resolve_dev_dir(project_root, skills_home)
    output_file = dev_dir / "verify-rules.md"

    flags = {"--diff", "--touched", "--json"}
    selected = {a for a in argv[1:] if a in flags}
    args = [a for a in argv[1:] if a not in flags]
    json_out = "--json" in selected
    mode = "diff" if "--diff" in selected else ("touched" if "--touched" in selected else "default")

    if args:
        files = list(args)
    elif mode == "touched":
        files = collect_touched_files(project_root)
    else:
        files = collect_default_files(project_root)

    resolved: list[tuple[Path, str]] = []
    for f in files:
        p = (project_root / f).resolve()
        if not p.exists() or not p.is_file():
            continue
        try:
            rel = str(p.relative_to(project_root))
        except ValueError:
            continue
        if _ext_of(rel) not in CODE_EXTS or _is_excluded(rel):
            continue
        resolved.append((p, rel))

    if not resolved:
        return _exit_clean(output_file, json_out, "VERIFY-RULES PASSED (no target files)")

    directives = load_directives(skills_home, project_root)
    if not directives:
        return _exit_clean(output_file, json_out, "VERIFY-RULES PASSED (no directives declared)")

    violations: list[Violation] = []
    for p, rel in resolved:
        violations.extend(check_file(p, rel, directives))

    if not violations:
        return _exit_clean(
            output_file, json_out,
            f"VERIFY-RULES PASSED ({len(resolved)} file(s), {len(directives)} directive(s))",
        )

    if json_out:
        _emit_json(violations)
    else:
        print("==== VERIFY-RULES VIOLATIONS ====")
        for v in violations:
            print(v.render())
        print("==== END VIOLATIONS ====")
        print(f"VERIFY-RULES FAILED: {len(violations)} violation(s)")
    _write_output(output_file, violations)
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except KeyboardInterrupt:
        raise SystemExit(130)
    except Exception as e:  # pragma: no cover
        print(f"verify-rules: internal error: {e}", file=sys.stderr)
        raise SystemExit(1)
