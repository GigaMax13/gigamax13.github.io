---
alwaysApply: false
description: "Go TDD rules and coding standards"
---

# Go TDD Rules

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** `panic(` in production code (tests exempt)
- [ ] **NEVER** `fmt.Print*` in library code — use structured logging

<!-- verify-rules:start
forbid:\bpanic\( ext:go exclude:_test.go message:no panic in prod
forbid:fmt\.Print ext:go exclude:_test.go,main.go message:no fmt.Print in libs
verify-rules:end -->

## Stack

Go 1.21+, go.mod, golangci-lint, go test, gofmt, testify, cobra, viper, zap/slog

## Validation

| Type   | Command                |
| ------ | ---------------------- |
| Vet    | `go vet ./...`         |
| Lint   | `golangci-lint run`    |
| Test   | `go test ./...`        |
| Format | `gofmt -l .`           |
| Build  | `go build -o {BINARY}` |

## Code Standards

- Max 300 lines/file
- Layout: `cmd/` (binaries), `internal/` (private), `pkg/` (public), `api/` (definitions)
- Tests: `*_test.go` | Source: `cmd/`, `internal/`, `pkg/`

### Forbidden

- `os.Exit` outside `main()`, `panic()` in production
- `fmt.Print*`, `log.Print*` (use structured logging)
- Hardcoded paths (use `path/filepath`), `interface{}` without need (use generics)
- Global variables, `init()` functions, circular imports, ignored errors with `_`

### Patterns

- Check errors immediately, wrap with context:
  ```go
  if err := doSomething(); err != nil {
      return fmt.Errorf("doing something: %w", err)
  }
  ```
- Pass `context.Context` through call chain; define interfaces at consumer side, keep small
- Dependency injection over globals:
  ```go
  type Server struct { db Database; logger Logger }
  func NewServer(db Database, log Logger) *Server {
      return &Server{db: db, logger: log}
  }
  ```

## Testing

`go test ./...` — ALL tests must pass; never run partial suites.

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive", 1, 2, 3},
        {"negative", -1, -2, -3},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            assert.Equal(t, tt.expected, Add(tt.a, tt.b))
        })
    }
}
```

## TDD Workflow

1. **Red**: Write test -> Run ALL (new fails, others pass)
2. **Green**: Minimal impl -> Run ALL (ALL pass)
3. **Refactor**: Clean up -> Run ALL (ALL pass)
4. **Validate**: `go vet` + `golangci-lint` + ALL tests pass

## Boundaries

| Always                          | Ask First         | Never                                 |
| ------------------------------- | ----------------- | ------------------------------------- |
| Run `go vet`, `golangci-lint`   | New deps          | DB migrations                         |
| TDD, handle all errors          | Skip/remove tests | `.gitignore` changes                  |
| Use `context.Context`           | Auth/security     | Delete issue items                    |
| Static builds (`CGO_ENABLED=0`) | CI changes        | AI as commit author                   |
|                                 |                   | Access production, modify `CLAUDE.md` |
