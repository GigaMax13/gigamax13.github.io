# {PROJECT_ID}

`PROJECT_ID="{PROJECT_ID}"`

## Stack

Python, {FRAMEWORK} — venv required

## Validation

| Type | Command |
|------|---------|
| TypeCheck | `{TYPECHECK}` |
| Lint | `{LINT}` |
| Test | `{TEST}` |
| Build | `{BUILD}` |

## Boundaries

| Always | Ask First | Never |
|--------|-----------|-------|
| Activate `.venv` before any python/pip command | New dependencies (in `pyproject.toml`) | Commit AI as author / co-author |
| Run mypy + ruff + pytest before commit | Auth or CI changes | `sudo pip install`, bare `python`/`pip` |
| Load conventions via `/load-rules` | Changes spanning > 3 files | DB migrations (codegen only) |
