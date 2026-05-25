---
alwaysApply: false
description: "Commit message rules and conventions"
---

# Commit Rules

**NEVER add `Co-Authored-By` trailers.**

## Format

```
<type>[optional scope]: <description>
```

Single line only — no body/footer (exception: issue refs when explicitly requested).

| Type       | When                            |
| ---------- | ------------------------------- |
| `feat`     | New feature (MINOR)             |
| `fix`      | Bug fix (PATCH)                 |
| `refactor` | Restructure, no behavior change |
| `test`     | Adding/updating tests           |
| `docs`     | Documentation only              |
| `style`    | Formatting, no logic change     |
| `chore`    | Maintenance, deps, config       |
| `perf`     | Performance improvement         |
| `ci`       | CI/CD changes                   |
| `build`    | Build system changes            |

### Description

- Imperative mood, lowercase first letter, no trailing period, max 72 chars
- Scope: lowercase noun in parens — `feat(auth): ...`
- Breaking: `!` before colon or `BREAKING CHANGE:` footer (`BREAKING-CHANGE` synonymous)
- Non-`feat`/`fix` types have no SemVer effect unless `!` present

## Examples

```
feat: add OAuth2 login
fix: handle null pointer in session check
refactor(db): extract query builder
docs: update API usage examples
chore: bump dependencies
feat!: remove legacy v1 endpoints
```
