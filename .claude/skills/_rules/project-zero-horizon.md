---
alwaysApply: false
description: "Rules for zero-horizon project"
---

# Project Rules: zero-horizon

> Extends: code-quality.md, react.md

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** use `../` relative imports — use workspace package aliases
- [ ] **NEVER** dynamic `await import()` — static imports only
- [ ] **NEVER** use `/tmp/` in tests — use `./.tmp/` in project root
- [ ] **NEVER** runtime data fetching — all data baked at build time

<!-- verify-rules:start
forbid:from\s+['"]\.\./ ext:ts,tsx exclude:.test.,.spec. message:no ../ relative imports
forbid:await\s+import\( ext:ts,tsx exclude:.test.,.spec. message:no dynamic import
forbid:['"]/tmp/ ext:ts,tsx message:use ./.tmp/ not /tmp/
forbid:getServerSideProps ext:ts,tsx message:static export only
verify-rules:end -->

## Project Structure

pnpm monorepo: `apps/web/` (Next.js static), `apps/scraper/`, `packages/shared/`

## Static Export (Next.js)

- [ ] `output: 'export'` in next.config.js — no server runtime
- [ ] No API routes (`app/api/` or `pages/api/`), no `getServerSideProps`, `getStaticProps` with revalidate, or `getInitialProps`
- [ ] All data from JSON files in `public/data/` or imported at build time
- [ ] `generateStaticParams()` for dynamic routes

## Data Flow

```text
scraper -> ./data/ -> Next.js build (static) -> Static HTML
```

- [ ] Scraper outputs to `./data/`; `@zero-horizon/web` consumes from `./data/`
- [ ] Components read JSON via `import` or `fs.readFile` in Server Components — no runtime fetching

```typescript
// ✅ build time
import data from "@/data/items.json";
const data = JSON.parse(await readFile("./public/data/items.json", "utf-8"));

// ❌ runtime
const data = await fetch("/api/items");
const { data } = useQuery({ queryKey: ["items"] });
```

## Data Sources — NO MAGIC DATA

- [ ] No hardcoded data — not in static JSON or `.env`
- [ ] Only scraped or ETL-transformed data; all JSON at `./data/` (monorepo root)
- [ ] Deck name → archetype mappings only from scraper-created JSON
- [ ] Handle errors gracefully, respect rate limits/robots.txt
- [ ] Cache intermediate results, version JSON on schema changes

## JSON Types & Imports

- [ ] TypeScript types in `packages/shared/src/types/` or `apps/web/src/types/`; import in both scraper and web
- [ ] Validate JSON with Zod or similar before writing
- [ ] No `../` imports — use `@zero-horizon/shared` or `@scraper/something`
- [ ] 3+ shared imports → move to shared package or `src/lib/utils.ts`; keep scraper utils separate from web utils

## Testing

- [ ] No `/tmp/` — use `./.tmp/` in project root; clean up temp files after tests

```typescript
// ❌
const tmpDir = "/tmp/my-test";
// ✅
const tmpDir = path.join(process.cwd(), ".tmp", `test-${Date.now()}`);
```

## Singleton Classes (ETL & Fetchers)

- [ ] All ETL pipeline classes (`packages/scraper/src/etl/pipeline/*.ts`) and fetcher classes (`packages/scraper/src/scraper/fetchers/*.ts`) MUST be singletons (test files exempt)

```typescript
export class DataPipeline {
  private static instance: DataPipeline;
  private constructor() {}
  static getInstance(): DataPipeline {
    if (!DataPipeline.instance) DataPipeline.instance = new DataPipeline();
    return DataPipeline.instance;
  }
  async process(data: RawData): Promise<TransformedData> { ... }
}
```

## Error Handling & Styling & Build

- [ ] Scraper: log errors, continue with remaining items
- [ ] Build: fail fast on invalid JSON or missing data
- [ ] Tailwind classes only — no arbitrary values without justification
- [ ] External links: `target="_blank" rel="noopener noreferrer"`; Suspense boundaries for loading states
- [ ] Build: `pnpm install` → `pnpm scraper` → `pnpm build` (outputs to `dist/` or `out/`) — deploy to CDN, no runtime server

## Before Submitting PR

- [ ] Scraper runs and outputs valid JSON
- [ ] Build completes without errors; no `any` types, no console errors
- [ ] All links work in static output, responsive design verified

## Migration Checklist Template

```md
- [ ] Create abstraction (component/util/hook)
- [ ] Count total callsites (grep)
- [ ] Migrate: all pages, components, layouts
- [ ] Verify no old patterns remain (grep)
- [ ] Test in browser
- [ ] Verify scraper outputs correct JSON
- [ ] Verify build succeeds
```
