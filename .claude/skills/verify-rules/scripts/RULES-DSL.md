# verify-rules DSL

`scripts/verify.py` parses machine-readable directives embedded in rule `.md` files. The directives live inside HTML comment blocks delimited by `verify-rules:start` / `verify-rules:end`.

## Block syntax

```
<!-- verify-rules:start
max-lines:399 ext:ts,tsx,py,go,rs
forbid:\bany\b ext:ts,tsx exclude:test,spec,.d.ts message:no any type
forbid:@ts-ignore ext:ts,tsx
forbid:@ts-expect-error ext:ts,tsx
forbid:eslint-disable ext:ts,tsx
forbid:console\.log ext:ts,tsx exclude:test,spec message:no console.log in prod
verify-rules:end -->
```

## Directives

| Directive | Syntax | Meaning |
|---|---|---|
| `max-lines` | `max-lines:N ext:a,b,c` | Fail if matching file has `>N` lines |
| `forbid` | `forbid:REGEX ext:a,b,c [exclude:s1,s2] [message:TEXT]` | Fail if regex found; `exclude` matches path substrings |

## Common modifiers

- `ext:` — comma-separated extensions, no dot (e.g. `ext:ts,tsx,py`).
- `exclude:` — comma-separated path substrings; matching paths are skipped (e.g. `exclude:test,spec`).
- `message:` — optional human-readable label appended to the violation line.

## Rule file discovery

Rule files are auto-discovered from the first existing directory:

1. `.claude/skills/_rules/`
2. `.claude/skills/_rules/`
3. `~/.claude/skills/_rules/`
4. `~/.kimi/skills/_rules/`

Every `*.md` file in the chosen directory is scanned for `verify-rules` blocks.
