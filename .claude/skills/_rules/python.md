---
alwaysApply: false
description: "Python TDD rules and coding standards"
---

# Python TDD Rules

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** use bare `except:` — catch specific exceptions
- [ ] **NEVER** use `print(` for debugging in source files (tests exempt)
- [ ] **NEVER** use `eval(` or `exec(`
- [ ] **NEVER** mutable defaults: `def f(x=[])` / `def f(x={})`

<!-- verify-rules:start
forbid:^\s*except\s*: ext:py exclude:.test.,test_,_test message:no bare except
forbid:^\s*print\( ext:py exclude:.test.,test_,_test,conftest,tools/,skills/ message:no print debug in source
forbid:\beval\( ext:py exclude:.test.,test_,_test message:no eval()
forbid:\bexec\( ext:py exclude:.test.,test_,_test message:no exec()
forbid:def\s+\w+\([^)]*=\s*\[\] ext:py message:no mutable default list
forbid:def\s+\w+\([^)]*=\s*\{\} ext:py message:no mutable default dict
verify-rules:end -->

## Stack

Python 3.11+, pip, mypy (strict), ruff, pytest

## Dependency policy for skill scripts (`.claude/skills/*/scripts/*.py`)

Skill scripts run inside Claude Code, Kimi, and hooks — all of which may lack a project venv. Apply this decision rule:

1. **Default: stdlib-only.** Use `re`, `json`, `pathlib`, `subprocess`, `tomllib` (3.11+), `argparse`, `urllib`. Mirrors `.claude/skills/verify-rules/scripts/verify.py` — no install step, runs anywhere.
2. **Escape hatch: skill-local venv with fail-soft dispatch.** Mirrors `.claude/skills/flow-metrics/.venv/`. Bootstrap via a `setup.sh` next to the script; missing tools degrade to `SKIPPED`, never `FAIL`. Use only when third-party deps are genuinely required.
3. **Power-user: PEP 723 + `uv run`.** Inline `# /// script` headers. Requires `uv` on host — document at top of SKILL.md when used.

**Never** `pip install` into the user's site-packages or `~/.local/`. **Never** assume a project `.venv` exists.

## Virtual Environment (CRITICAL)

**Always use venv. Never use system Python.**

| Action   | Command                     |
| -------- | --------------------------- |
| Create   | `python -m venv .venv`      |
| Activate | `source .venv/bin/activate` |
| Install  | `pip install -e ".[dev]"`   |

- Deps, tests, app ONLY in venv; new deps ONLY in `pyproject.toml`
- NEVER bare `python`, `pip`, `pytest`; NEVER `sudo pip install`

### Justfile (REQUIRED)

```makefile
test:
    #!/bin/bash
    source .venv/bin/activate && pytest

test-unit:
    #!/bin/bash
    source .venv/bin/activate && pytest tests/unit -v

test-integration:
    #!/bin/bash
    source .venv/bin/activate && pytest tests/integration -v

test-e2e:
    #!/bin/bash
    source .venv/bin/activate && pytest tests/e2e -v

typecheck:
    #!/bin/bash
    source .venv/bin/activate && mypy --strict src/

lint:
    #!/bin/bash
    source .venv/bin/activate && ruff check src/ tests/

check: typecheck lint test
    @echo "All checks passed!"
```

## Validation

| Check     | Command                   |
| --------- | ------------------------- |
| Type      | `mypy --strict src/`      |
| Lint      | `ruff check src/ tests/`  |
| ALL Tests | `just test`               |
| Format    | `ruff format src/ tests/` |
| All       | `just check`              |

## TDD Workflow

1. **Red**: Write test -> Run ALL (new fails, others pass)
2. **Green**: Minimal impl -> Run ALL (ALL pass)
3. **Refactor**: Clean up -> Run ALL (ALL pass)
4. **Validate**: Type + Lint + ALL tests pass

## Code Standards

- Max 300 lines/file, full type annotations (mypy strict)
- Type hints on all signatures; Pydantic for validation, dataclasses for models
- `pathlib.Path` for paths, specific exceptions only
- Context managers for resources, dependency injection over globals
- `async/await` for I/O bound; no `isinstance()` for type dispatch
- No circular imports, no hardcoded paths, no `*args/**kwargs` without docs

### Import Order

```python
import os
from pathlib import Path

import httpx
from pydantic import BaseModel

from mypackage.models import User
```

## Testing

`just test` — ALL tests (unit + integration + e2e); never run partial suites.

| Category    | Location                           |
| ----------- | ---------------------------------- |
| Unit        | `tests/unit/` or `tests/test_*.py` |
| Integration | `tests/integration/`               |
| E2E         | `tests/e2e/`                       |

## Boundaries

| Always                 | Ask First         | Never                |
| ---------------------- | ----------------- | -------------------- |
| Run mypy, ruff in venv | New env vars      | DB migrations        |
| TDD with venv          | New deps          | `.gitignore` changes |
| Specific exceptions    | Skip/remove tests | Delete issue items   |
| Close resources        | Auth/security     | AI as commit author  |
| Activate venv first    | CI changes        | Access production    |
| Use `pyproject.toml`   |                   | Modify `CLAUDE.md`   |

## Tools

mypy, ruff, pytest, Pydantic, uv, httpx
