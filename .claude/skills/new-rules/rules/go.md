# {PROJECT_ID}

`PROJECT_ID="{PROJECT_ID}"`

## Stack

Go, {FRAMEWORK}

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
| Run `go vet` + `golangci-lint` + tests before commit | New dependencies | Commit AI as author / co-author |
| TDD, wrap errors with `%w`, pass `context.Context` | Auth or CI changes | DB migrations (codegen only) |
| Load conventions via `/load-rules` | Changes spanning > 3 files | `panic` / `os.Exit` outside `main` |
