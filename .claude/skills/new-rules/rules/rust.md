# {PROJECT_ID}

`PROJECT_ID="{PROJECT_ID}"`

## Stack

Rust, {FRAMEWORK}

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
| Run `cargo check` + `clippy` + tests before commit | New dependencies | Commit AI as author / co-author |
| TDD, prefer `Result` over `unwrap` | Auth or CI changes | DB migrations (codegen only) |
| Load conventions via `/load-rules` | Changes spanning > 3 files | `unsafe` blocks without review |
