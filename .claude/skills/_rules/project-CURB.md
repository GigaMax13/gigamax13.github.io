---
alwaysApply: false
description: "Rules for CURB curriculum project"
---

# Project Rules: curriculum

> Extends: code-quality.md, react.md

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** use `as` assertions — use generics, type guards, or schema validation
- [ ] **NEVER** import Prisma types from `@prisma/client` — use `~/prisma` alias
- [ ] **NEVER** dead props prefixed with `_` — remove entirely
- [ ] No unnecessary `async` — only if function contains `await`

<!-- verify-rules:start
forbid:from\s+['"]@prisma/client['"] ext:ts,tsx exclude:.test.,.spec. message:import from ~/prisma not @prisma/client
forbid:\bas\s+unknown\s+as\b ext:ts,tsx exclude:.test.,.spec. message:no double-as assertions
verify-rules:end -->

## tRPC Architecture

- [ ] All endpoints in `src/server/api/routers/`
- [ ] No REST endpoints, no direct DB/Prisma from pages/components
- [ ] Server: `await api.resource.getAll()` | Client: `api.resource.getAll.useQuery()` / `.useMutation()`

## Prisma Imports

> Generic patterns: see `database.md` (auto-loaded when ORM detected)

- [ ] Import from `'~/prisma'` (not `../../../generated/prisma` or `@prisma/client`)
- [ ] `~/types` only for enums, overwritten types, or custom types
- [ ] NO barrel files for `~/prisma` — import directly
- [ ] Soft-delete: test both non-existent AND soft-deleted records (see `database.md`)
- [ ] Error handling: see `database.md` for Prisma error patterns

## Dead Code

- [ ] No dead props — remove entirely, never `_prop` prefix
- [ ] No orphaned exports — every `export` must have non-test import
- [ ] 3+ imports = move to `src/lib/utils.ts` or `src/lib/[feature]Utils.ts`

## Test Quality

- [ ] Every `it()`/`test()` must have meaningful `expect()` — no empty bodies
- [ ] No hidden DOM elements for testing — test only visible content
- [ ] No duplicate test blocks across files
- [ ] No `as any` in mocks — use typed factories
- [ ] Verify mocks called: `expect(mock).toHaveBeenCalled()`

## Migration Completeness

- [ ] Count callsites BEFORE creating abstractions
- [ ] Check ALL surfaces: lists, tables, grids, detail, sidebars, trash/recovery, admin
- [ ] Migrate ALL callsites; verify with grep

## UI Wiring & Functionality

- [ ] Dropdowns/selectors trigger actual data fetching
- [ ] "Browse without search" path works
- [ ] New server procedures called from UI (not orphaned)
- [ ] Controlled state flows: props update, callbacks fire
- [ ] Test complete user flow end-to-end
- [ ] Cascading dropdowns re-fetch child data on parent change

## Server Component Data Fetching

- [ ] Never call with empty/invalid parameters
- [ ] **CRITICAL:** Analyze complete data flow before "fixing" with empty arrays
- [ ] Fetch scope first if data depends on configuration
- [ ] Use `{ enabled: !!id }` to prevent invalid calls
- [ ] Role-gated queries: `{ enabled: hasRole }`

```typescript
// ❌ Empty param returns nothing
const items = await api.resource.getItems({ parentId: "" });

// ✅ Fetch scope first
const scope = await api.resource.getScope({ entityId });
const [items, subItems] = await Promise.all([
  scope.parentId
    ? api.resource.getItems({ parentId: scope.parentId })
    : Promise.resolve([]),
  scope.childId
    ? api.resource.getSubItems({ childId: scope.childId })
    : Promise.resolve([]),
]);

// ✅ Client: enabled guard
const { data } = api.resource.getItems.useQuery(
  { parentId: selectedId },
  { enabled: !!selectedId },
);
```

### When Data Fetch Fails

**STOP.** Do NOT default to `[]`. Trace: Page/Route -> Layout -> Component -> Sub-component (fetch fails).

**Decision tree:**

```
Param missing/invalid
  -> Should param exist at this route level?
    YES -> Lift fetch or pass it down from where data IS available
    NO  -> Optional feature? YES -> Empty array, document WHY | NO -> Fix routing
```

## API & UI

- [ ] Single pattern per component — don't mix `actions` AND `renderActions`
- [ ] Permanent delete requires confirmation dialog explaining consequence
- [ ] Entire row clickable for coverage links
- [ ] Status display uses StatusBadge — never raw `{entity.status}`

## Before Submitting PR

- [ ] Migration checklist completed
- [ ] No regression from main
- [ ] Grep confirms zero old pattern callsites
- [ ] Browser verification complete
- [ ] All trash sections have confirmation dialogs
- [ ] All status displays use StatusBadge
- [ ] PR scope is single concern; description explains what/why
- [ ] Verify claimed implementations exist via grep

## Migration Checklist Template

```md
- [ ] Create abstraction (component/util/hook)
- [ ] Count total callsites (grep)
- [ ] Migrate: lists/tables, trash/recovery, admin, detail, sidebars
- [ ] Verify no old patterns remain (grep)
- [ ] Test in browser + "browse without search"
- [ ] Verify no orphaned buttons
- [ ] Check trash sections have confirmation dialogs
```
