# {PROJECT_ID}

`PROJECT_ID="{PROJECT_ID}"`

## Stack

TypeScript, {FRAMEWORK}

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
| Run typecheck + lint + tests before commit | New env vars / dependencies | Commit AI as author / co-author |
| TDD (failing test → min impl → refactor) | Auth or CI changes | DB migrations (generation only) |
| Load conventions via `/load-rules` | Changes spanning > 3 files | Edit generated code or `.gitignore` silently |
