---
alwaysApply: false
description: "TDD workflow and testing standards"
---

# TDD Rules

## CRITICAL: ALL TESTS MUST USE MOCKS

- [ ] ALL external dependencies mocked — NO real API calls, DB ops, file system ops, or network requests

## TDD Cycle

1. **Red** - Write failing test, run ALL, verify ONLY new test fails
2. **Green** - Minimal impl, run ALL, ALL must pass
3. **Refactor** - Remove duplication, run ALL after each change; repeat for edge cases, errors, integration
4. **Full Validation** - ALL tests + type checks + lint; fix ALL errors; repeat until ZERO errors

## Mocking Patterns

### TypeScript/Vitest

```typescript
vi.mock("@/lib/prisma", () => ({ prisma: mockPrisma }));
vi.mock("@/lib/api", () => ({ fetchExternal: vi.fn() }));
```

### Python/pytest

```python
from unittest.mock import Mock, patch

@patch("mymodule.external_api.fetch")
def test_something(mock_fetch):
    mock_fetch.return_value = {"data": "mocked"}
```

### Go

```go
type DB interface { GetUser(id int) (*User, error) }
type MockDB struct { GetUserFunc func(int) (*User, error) }
func (m *MockDB) GetUser(id int) (*User, error) { return m.GetUserFunc(id) }
```

## Exit Criteria

- [ ] All criteria have tests
- [ ] Run ALL tests (unit, integration, e2e); never skip suites
- [ ] Fix ALL test failures (even unrelated)
- [ ] ALL type checking and lint checks pass
- [ ] No TODOs left in code
- [ ] ZERO errors across codebase
