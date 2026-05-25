---
alwaysApply: false
description: "Rules for project-manhattan"
---

# Project Rules: manhattan

> Extends: code-quality.md, react.md

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** hand-edit `site.schema.json` — generated from Zod via `pnpm schema:generate`; regeneration needs owner approval
- [ ] **NEVER** introduce a new token name in `site.yaml` — `theme.overrides` and `themeOverrides` may only redeclare existing `TOKEN_REGISTRY` tokens
- [ ] **NEVER** put a raw CSS length inside `layout.padding` / `margin` / `gap` — use the `spacing.<name>` shorthand
- [ ] **NEVER** hardcode colors or lengths in components — use Tamagui token names or `--mh-<category>-<name>` aliases
- [ ] **NEVER** dynamic `await import()` in generated code — static imports only
- [ ] **NEVER** add `'use client'` outside a component spec declaring `clientOnly: true`

<!-- verify-rules:start
forbid:#[0-9a-fA-F]{3,8}\b ext:tsx,ts exclude:.test.,.spec.,test-utils/,__fixtures__/,packages/types/ message:no hardcoded hex colors in components — use token names
forbid:\b\d+(px|rem|em)\b ext:tsx,ts exclude:.test.,.spec.,test-utils/,__fixtures__/,packages/types/ message:no hardcoded CSS lengths in components — use spacing tokens
forbid:#[0-9a-fA-F]{3,8}\b ext:css exclude:tamagui.css message:no hardcoded hex colors in site.css — use --mh-* aliases
forbid:await\s+import\( ext:ts,tsx exclude:.test.,.spec. message:no dynamic import
forbid:'use client' ext:tsx exclude:.test.,.spec.,providers,clientOnly message:'use client' boundary requires a clientOnly: true component spec
forbid:^theme:\s*\n\s+(colors|spacing|radii|typography): ext:yaml exclude:__fixtures__/ message:site.yaml theme block must use { base?, overrides } shape
verify-rules:end -->

## Three-layer theme system

Layers (low → high):

1. **Tamagui base config** — `@tamagui/config/v3`. Opaque to authors.
2. **`TOKEN_REGISTRY`** (`packages/types/src/default-theme.ts`) — canonical token names per category (`colors`, `spacing`, `radii`, `typography`).
3. **`NAMED_THEMES`** (`packages/types/src/named-themes.ts`) — `{ name, values }` entries; each supplies a value for every `TOKEN_REGISTRY` token.

Sites declare `theme.base` (optional; defaults to `manhattan-default`) and `theme.overrides` (per-category subset). Per-node `themeOverrides` scopes overrides to a subtree via `<ScopedTheme>`.

- [ ] Add a token = extend `TOKEN_REGISTRY` AND add a value in every `NAMED_THEMES` entry; `Required<…>` on `NamedTheme.values` enforces both halves
- [ ] Add a named theme = extend `THEME_NAME_VALUES` in `site-definition.ts` AND append a `NamedTheme` entry in `named-themes.ts`
- [ ] Sites NEVER introduce token names — typos fail Zod with a path-pinpointed error

```yaml
# ✅ allowed
theme:
  base: manhattan-noir
  overrides:
    colors:
      primary: '#fff200'

# ❌ rejected: bespoke key
theme:
  overrides:
    colors:
      fancyBlue: '#abcdef'

# ❌ rejected: raw length in layout
layout:
  padding: '12px 0'
```

## Static export only (Next.js)

- [ ] `output: 'export'` in `apps/web-engine/next.config.js`
- [ ] No API routes (`app/api/`), no `getServerSideProps`, no `revalidate`
- [ ] `generateStaticParams()` enumerates every page; `dynamicParams = false` so unknown URLs 404 at the CDN
- [ ] All data baked at build time. `clientOnly: true` is the only audited runtime-fetch escape hatch — every use needs a justification comment in the spec

## YAML authoring

- [ ] YAML 1.2 `core` schema only — no anchors (`&`), aliases (`*`), merge keys (`<<:`), or custom tags (PRD §15)
- [ ] 2 MiB cap per `site.yaml`; loader rejects oversized files with `LOADER_FILE_TOO_LARGE` pre-parse
- [ ] Every `site.yaml` carries `# yaml-language-server: $schema=…/site.schema.json`
- [ ] `theme:` uses the `{ base?, overrides? }` shape — flat `theme: { colors, spacing }` is rejected

## Component contract

- [ ] Each component exports a Zod props schema, a `ComponentSpec` (`{ name, props, clientOnly }`), and the implementation
- [ ] Variants read token NAMES (`colors.primary` vs `colors.accent`); never literal values
- [ ] Per-instance variance lives in YAML via `themeOverrides` (token values) + `layout` (flat layout props), NOT component props
- [ ] Pool index (`packages/components/src/index.ts`) statically imports every component — no `await import()`

## Validation

| Type        | Command             |
| ----------- | ------------------- |
| TypeCheck   | `pnpm typecheck`    |
| Lint        | `pnpm lint`         |
| Test        | `pnpm test`         |
| Build       | `pnpm build`        |
| Schema gate | `pnpm schema:check` |

## Build & site fixtures

- [ ] `sites/<id>/` is a build-input directory — `out/` is gitignored, moved to client infra post-build
- [ ] `t<N>-<slug>` = test sites; `NN-<slug>` = real client builds
- [ ] One fixture exercises `theme.base: manhattan-noir` to keep named-themes plumbing covered E2E

## Before submitting PR

- [ ] `pnpm typecheck && pnpm lint && pnpm test` clean
- [ ] `pnpm schema:check` clean (after owner-approved regen if Zod source changed)
- [ ] No fixture site introduces unknown tokens; no component hardcodes colors / lengths
- [ ] Fixture builds end-to-end (`pnpm --filter @manhattan/web-engine build --site sites/<id>`) for at least one site
