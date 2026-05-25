---
alwaysApply: false
description: "PR description guidelines and forbidden patterns"
---

# PR Description Rules

Load once. **NEVER add attribution lines or test plan sections.**

## Required Format

```markdown
## Summary

[2-3 sentences on purpose/impact]

## Key Changes

- **[Category]**: [Brief description]

## Issue References

Refs: TEAM-XXX, TEAM-YYY
```

## Forbidden

| Pattern                                   | Why                  |
| ----------------------------------------- | -------------------- |
| `Generated with [Claude Code]` or similar | Noise                |
| `## Test plan` / `## Test Plan` sections  | CI handles this      |
| Pasted terminal output                    | Stale immediately    |
| Emoji-heavy formatting                    | Reduces scannability |
| `Co-Authored-By` trailers                 | Never add these      |

## Example

```markdown
## Summary

Add OAuth2 login flow with session management. Replaces the legacy cookie-based auth
that was flagged for compliance issues.

## Key Changes

- **Auth**: OAuth2 provider integration with PKCE
- **Session**: Server-side session store with Redis TTL
- **Migration**: Drop legacy `sessions` table, add `oauth_tokens`

## Issue References

Refs: AUTH-142, AUTH-155
```

## Rules

- Summary explains **why**, not just **what**
- Key Changes grouped by category, not per-file
- Issue References only if commits contain issue IDs
- No sections beyond Summary, Key Changes, Issue References unless requested
- Max 30 lines
