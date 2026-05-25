---
alwaysApply: false
description: "Rust TDD rules and coding standards"
---

# Rust TDD Rules

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** `.unwrap()` / `.expect(` in production code (tests exempt)
- [ ] **NEVER** `todo!()` / `unimplemented!()` in committed code
- [ ] **NEVER** `println!` debugging in libraries

<!-- verify-rules:start
forbid:\.unwrap\(\) ext:rs exclude:tests/,_test,#\[test\] message:no unwrap in prod
forbid:\.expect\( ext:rs exclude:tests/,_test,#\[test\] message:no expect in prod
forbid:\btodo!\( ext:rs message:no todo!() in committed code
forbid:\bunimplemented!\( ext:rs message:no unimplemented!() in committed code
verify-rules:end -->

## Stack

Rust 1.75+, Edition 2021, Cargo, Clippy, `cargo test`, rustfmt

## Validation

| Type   | Command                       |
| ------ | ----------------------------- |
| Check  | `cargo check`                 |
| Lint   | `cargo clippy -- -D warnings` |
| Test   | `cargo test`                  |
| Format | `cargo fmt -- --check`        |
| Build  | `cargo build --release`       |

## Code Standards

- Max 300 lines/file; tests: `#[cfg(test)]` modules or `tests/` dir; source: `src/`, `src/bin/`
- `?` for error propagation; `thiserror` (libs), `anyhow` (apps)
- Composition over inheritance (traits), ownership/borrowing over cloning, iterators over loops
- No `unsafe` without justification, no `let _ =` to ignore `Result`, no `static mut`

### Error Handling

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("parse error: {0}")]
    Parse(String),
}

pub type Result<T> = std::result::Result<T, AppError>;

pub fn read_config(path: &Path) -> Result<Config> {
    let content = std::fs::read_to_string(path)?;
    let config: Config = serde_json::from_str(&content)
        .map_err(|e| AppError::Parse(e.to_string()))?;
    Ok(config)
}
```

## Testing

`cargo test` — ALL tests must pass (unit + integration + doc); never run partial suites.

| Type        | Location            |
| ----------- | ------------------- |
| Unit        | `src/*.rs` (inline) |
| Integration | `tests/*.rs`        |
| Doc         | `///` comments      |

```rust
pub fn add(a: i32, b: i32) -> i32 { a + b }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_add() {
        assert_eq!(add(1, 2), 3);
        assert_eq!(add(-1, -2), -3);
    }
}
```

## TDD Workflow

1. **Red**: Write test -> Run ALL (new fails, others pass)
2. **Green**: Minimal impl -> Run ALL (ALL pass)
3. **Refactor**: Clean up -> Run ALL (ALL pass)
4. **Validate**: `cargo clippy` + `cargo fmt` + ALL tests pass

## Boundaries

| Always                          | Ask First         | Never                |
| ------------------------------- | ----------------- | -------------------- |
| Run `cargo clippy`, `cargo fmt` | New deps          | DB migrations        |
| TDD, error handling             | Unsafe code       | `.gitignore` changes |
| Use `?` for errors              | Skip/remove tests | Delete issue items   |
| Static builds                   | CI changes        | AI as commit author  |

## Tools

Cargo, Clippy, rustfmt, rust-analyzer, thiserror, anyhow, tokio
