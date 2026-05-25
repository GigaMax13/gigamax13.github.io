---
alwaysApply: false
description: "TypeScript TDD rules and coding standards"
---

# TypeScript TDD Rules

> For React projects, also load `react.md` (both apply).

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** use `any`, `@ts-ignore`, `@ts-expect-error`, `eslint-disable`
- [ ] **NEVER** `as any` casts
- [ ] **NEVER** commit `console.log` in non-test files
- [ ] `unknown` over `any`; explicit types for public APIs

<!-- verify-rules:start
forbid::\s*any(?![A-Za-z_0-9]) ext:ts,tsx exclude:.test.,.spec.,.d.ts message:no any type (use unknown)
forbid:\bas\s+any\b ext:ts,tsx exclude:.test.,.spec.,.d.ts message:no as any cast
forbid:@ts-ignore ext:ts,tsx message:no @ts-ignore
forbid:@ts-expect-error ext:ts,tsx message:no @ts-expect-error
forbid:eslint-disable ext:ts,tsx message:no eslint-disable
verify-rules:end -->

## Stack

TypeScript 5.x+, ES2022, NodeNext, ESLint, Vitest/Jest, Prettier. Tools: Vite/Webpack.

## Validation

| Type   | Command                   |
| ------ | ------------------------- |
| Type   | `tsc --noEmit`            |
| Lint   | `eslint . --ext .ts,.tsx` |
| Test   | `vitest` or `npm test`    |
| Format | `prettier --check .`      |
| Build  | `npm run build`           |

## tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "outDir": "./dist"
  }
}
```

## Code Standards

- Max 300 lines/file
- Tests: `*.test.ts`, `*.test.tsx` | Source: `src/`, `lib/`, `app/`, `components/`
- `unknown` over `any`; `const` for immutable values; shared types in `src/types/`
- No hardcoded paths (use aliases), no mixed client/server logic, no secrets in commits

## Testing

`npx vitest` or `npm test` — ALL tests must pass; never run partial suites.

```typescript
vi.mock("@/lib/prisma", () => ({ prisma: mockPrisma }));
vi.mock("@/lib/api", () => ({ fetchExternal: vi.fn() }));
vi.mock("@/lib/auth", () => ({ getSession: vi.fn() }));
```

## TDD Workflow

1. **Red**: Write test -> Run ALL (new fails, others pass)
2. **Green**: Minimal impl -> Run ALL (ALL pass)
3. **Refactor**: Clean up -> Run ALL (ALL pass)
4. **Validate**: Type + Lint + ALL tests pass

## Boundaries

| Always              | Ask First         | Never                                 |
| ------------------- | ----------------- | ------------------------------------- |
| Run typecheck, lint | New env vars      | DB migrations                         |
| TDD, strict mode    | New deps          | `.gitignore` changes                  |
| Handle errors       | Skip/remove tests | Delete issue items                    |
| Mock external deps  | Auth changes      | AI as commit author                   |
|                     | CI changes        | Access production, modify `CLAUDE.md` |
