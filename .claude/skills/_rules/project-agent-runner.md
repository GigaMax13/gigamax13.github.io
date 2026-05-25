---
alwaysApply: false
description: "Rules for project-agent-runner"
---

# Project Rules: agent-runner

> Extends: code-quality.md, react.md

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** import `@anthropic-ai/claude-agent-sdk` or call the Anthropic HTTP API — `child_process.spawn` of the local CLI only
- [ ] **NEVER** bind to `0.0.0.0` — localhost only
- [ ] **NEVER** exceed 300 lines per file

## Symlink Injection — The Correctness Property

The target project's working tree is **never** written to.

- [ ] All injected agents/skills/rules/shared files go through `os.tmpdir()/agent-runner/{runId}/` symlinks, passed via `--add-dir`
- [ ] Build via `src/server/runner/inject.ts` `buildInjectionDir(runId, refs)`; tear down via `teardownInjectionDir(runId)`
- [ ] Mirror the source layout inside the temp dir so `SKILL.md` sibling scripts resolve at relative paths (`skills/X/SKILL.md` stays at `skills/X/SKILL.md`)
- [ ] Teardown on **every** run-end path: success, abort (SIGKILL), error, exception. `fs.rm({ recursive: true, force: true })`
- [ ] `fs.rm` must be symlink-aware — do not follow into source (`data/`)
- [ ] No code path outside `inject.ts` may write into a project's `path` directory

## UI / Styling — shadcn/ui + Tailwind 4.x

The UI is **Tailwind CSS 4.x** + **shadcn/ui** (style `new-york`, base `neutral`). Anything else is a regression.

### Tokens

- [ ] Canonical shadcn tokens live in `:root` of `src/app/globals.css`: `--background`, `--foreground`, `--card`, `--card-foreground`, `--popover`, `--popover-foreground`, `--primary`, `--primary-foreground`, `--secondary`, `--secondary-foreground`, `--muted`, `--muted-foreground`, `--accent`, `--accent-foreground`, `--destructive`, `--destructive-foreground`, `--border`, `--input`, `--ring`, `--chart-1..5`, `--radius`.
- [ ] Each token is bridged via `@theme inline` so `bg-background`, `text-foreground`, `border-border`, etc. are canonical.
- [ ] `@custom-variant dark (&:is(.dark *));` keys `dark:` variants off the `.dark` class, permanently applied to `<html>` (project is dark-only). Do not remove the variant or html class.
- [ ] **NEVER** introduce ad-hoc tokens (`--bg`, `--text`, `--accent-dim`) — map onto the canonical set.
- [ ] **NEVER** use arbitrary-value utilities (`bg-[var(--primary)]`) to read a theme token — use the generated utility (`bg-primary`). Arbitrary values are reserved for one-off pixel values not belonging in the theme.

### Components

- [ ] Pull shadcn primitives on demand: `pnpm dlx shadcn@latest add <name>`. Never scaffold the full registry upfront — pull in the same task that needs it.
- [ ] Before creating a component, check `src/components/ui/` (shadcn) and `src/components/`. Compose with `variant`/`size`/`asChild`; never copy-paste a primitive's CSS.
- [ ] Server Components by default; `'use client'` only for interactivity.
- [ ] shadcn registry imports radix from the umbrella `radix-ui` package (`import { Slot } from "radix-ui"`), not `@radix-ui/react-slot`. Do not re-add legacy single-package imports.

### Class merging

- [ ] Compose dynamic/conditional/overrideable className via `cn(...)` from `@/lib/utils` (wraps `clsx` + `tailwind-merge`).
- [ ] **NEVER** concatenate utility classes with `+` or template literals.
- [ ] Variants go through `cva` (class-variance-authority); declare the variants object **outside** the component body to avoid recreating per render.

### Forbidden styling layers

- [ ] **NEVER** create `*.module.css` — CSS Modules unused.
- [ ] **NEVER** use inline `style={{}}` props. (Exception: computed pixel values for canvas-based components like Monaco that can't read CSS classes — Monaco's `options.fontFamily` is config, not `style`, and is allowed.)
- [ ] **NEVER** add styled-components, Emotion, or any CSS-in-JS lib.
- [ ] **NEVER** add `tailwind.config.{js,ts}` — Tailwind v4 is configured via `@theme` in `globals.css`.

### Icons

- [ ] `lucide-react` only (configured in `components.json`). No SVG copy-paste, no other icon sets.

## Forms — react-hook-form + Zod

UI forms use **react-hook-form** (state) + **Zod** (schema), surfaced through shadcn's form primitives. The same Zod schemas validate frontmatter on disk (PRD §5.3) — one source of truth.

### Library

- [ ] Canonical stack: `react-hook-form`, `zod`, `@hookform/resolvers`. **NEVER** add Formik, react-final-form, or hand-rolled `useState` + `safeParse`.
- [ ] Use `zodResolver` from `@hookform/resolvers/zod` — never `schema.safeParse(values)` inside a component.

### Schema location

- [ ] Domain Zod schemas in `src/types/` next to the TS type (e.g. `agent.schema.ts` ↔ `agent.ts`). Frontmatter readers in `src/server/crud/*` and the UI form import the **same** `agentSchema`. **NEVER** inline a Zod schema in a component.
- [ ] Derive TS types via `z.infer<typeof agentSchema>` — **NEVER** maintain a parallel interface.

### useForm configuration

- [ ] `useForm<z.infer<typeof schema>>({ resolver: zodResolver(schema), defaultValues, mode: "onChange" })`
- [ ] **Always pass `defaultValues`** — RHF treats fields without one as uncontrolled and silently drops them from `getValues()`.
- [ ] `mode: "onChange"` for editor forms so the live validity badge (PRD §6.2) updates as user types. Use `"onBlur"` only when validation is expensive.

### Composition

- [ ] Use shadcn form primitives from `@/components/ui/form` (`Form`, `FormField`, `FormItem`, `FormLabel`, `FormControl`, `FormMessage`, `FormDescription`) — install via `pnpm dlx shadcn@latest add form`.
- [ ] Spread the full `field` onto the input (`<Input {...field} />`). **NEVER** wire `value`/`onChange` individually — breaks RHF ref binding and re-render optimization.
- [ ] Render errors with `<FormMessage />`. **NEVER** pull from `formState` by hand — breaks `aria-invalid`/`aria-describedby`.

### Performance

- [ ] RHF inputs are **uncontrolled by design**. **NEVER** wrap an RHF input in a `useState` mirror — re-introduces the per-keystroke re-render RHF avoids.
- [ ] **NEVER** subscribe to the entire `form.watch()` for derived values — use `form.watch("field")` or `useWatch({ name, control })`.

### Submission

- [ ] Submit via `form.handleSubmit(serverAction)` where `serverAction` is a Next.js Server Action. **NEVER** `fetch()` or hit a route handler from a client form (PRD §7.1, "no tRPC, no REST").
- [ ] Server Action **re-validates** with the same Zod schema before writing. Client validation is UX only, never trusted server-side.

### Refinements

- [ ] Cross-field validation (e.g. "endDate after startDate") uses `z.refine` / `z.superRefine`. **NEVER** validate via `useEffect`.

### Testing

- [ ] Form tests: `@testing-library/react` + `userEvent`. **NEVER** test the Zod schema through the form — unit-test the schema directly (`schema.safeParse`) and the form wiring (renders, submits, surfaces errors) separately.

## Runner Registry — globalThis Singleton

Long-lived child processes attach to `globalThis.__agentRunner` to survive Next.js dev HMR.

- [ ] Access via a `getOrCreate()`-style helper; never reassign `globalThis.__agentRunner` directly
- [ ] Singleton holds the session store + active runners — do not duplicate state across modules
- [ ] `next start` is the production target (single Node process); document the HMR caveat in code, do not add runtime guards

## NDJSON Line-Buffering — #1 Bug Class

stdout chunks straddle line boundaries. Always reassemble complete lines before `JSON.parse`.

- [ ] All NDJSON parsing flows through `src/server/runner/parse-stdout.ts`
- [ ] Never call `JSON.parse` directly on a `data` event payload — buffer until `\n`
- [ ] Unit-test with artificial chunk boundaries: split mid-token, mid-line, multiple events per chunk
- [ ] Both `ClaudeRunner` and `KimiRunner` share the same line-buffer; only the per-event adapter differs (claude event-shape vs kimi role-shape)
- [ ] Both runners emit a unified `TranscriptEntry` via `EventEmitter` so the UI stays CLI-agnostic

## Session Store — cwd-aware

State at `state/sessions.json`, keyed `{projectId}:{agentId}` → `{ sessionId, cwd, updatedAt }`.

- [ ] `getSession(projectId, agentId, cwd)` returns sessionId only when stored cwd matches; otherwise delete the entry and return undefined
- [ ] On "unknown session" error from the CLI, retry once with a fresh session
- [ ] Per-run "Fresh session" toggle bypasses resume regardless of stored state
- [ ] Kimi: default to `--continue` (cwd-scoped); only pass `--session ID` when the user explicitly pins one

## Atomic JSON Writes

- [ ] `state/sessions.json`, `state/schedules.json`, `data/projects.json`, `runs/{id}/meta.json`, `transcript.json`: write to a sibling temp file, then `fs.rename` into place
- [ ] Never truncate-and-rewrite directly — interrupted writes corrupt state
- [ ] `runs/{id}/stream.ndjson` is append-only — exempt

## CLI Flag Matrix is Locked

Do not invent new CLI flags. Check the matrix before adding any `claude` or `kimi` argument.

- [ ] claude: `--print --output-format stream-json --verbose --model X --resume ID --add-dir PATH [--max-turns N] [--dangerously-skip-permissions]`
- [ ] kimi: `--print --output-format stream-json --model X --session ID|--continue --add-dir PATH --work-dir PATH [--max-steps-per-turn N]`
- [ ] `--dangerously-skip-permissions` is passed iff `project.skipPermissions === true`
- [ ] Scheduled and file-watch runs require `skipPermissions: true`; surface a banner explaining why
- [ ] Env-check warns for buggy claude versions in the 2.1.78–2.1.92 range

## Triggers — Coalescing & Lazy Start

- [ ] Scheduler: `node-cron` for cron, `setInterval` for fixed-interval heartbeats; rehydrate from `state/schedules.json` on boot
- [ ] Watchers: `chokidar` per project, **lazy-started** — instantiate only when ≥1 watcher is enabled
- [ ] Coalescing: if a run is already active for `(projectId, agentId)`, skip the new fire (schedules AND watchers)
- [ ] Watcher: debounce per project (default 5s); inject `{{changedFiles}}` into the prompt template
- [ ] Bench coalescing under bursty changes — 200 file events in 200ms must collapse to 1 run, not 200

## Persistence Layout (Protected)

- [ ] `data/` (CRUD store), `state/` (sessions, schedules), `runs/` (per-run NDJSON archive) — never auto-delete or overwrite
- [ ] No DB/migrations; SQLite is the post-MVP upgrade path when run history exceeds ~10k entries
- [ ] Frontmatter shapes for agent / skill / rule / task / workflow are locked — validate with Zod on read AND write
- [ ] Every run archives `meta.json` (params), `stream.ndjson` (raw), `transcript.json` (parsed) under `runs/{projectId}/{runId}/`
- [ ] Replay reads `stream.ndjson` through the same parser path — no separate replay format

## Server Actions & WebSocket — No tRPC, No REST

- [ ] Data flow: Server Actions or App Router Route Handlers — **no tRPC**, **no REST**
- [ ] Live run stream: `ws` library upgrade inside a Route Handler running on Node runtime; SSE is the one-way fallback
- [ ] Run console controls: Pause = SIGTERM with 15s grace; Abort = SIGKILL
- [ ] Kimi `exit code 75` flips `retryable: true` on the result event — surface a one-click retry badge

## Required Unit Tests

- [ ] NDJSON line-buffering across artificial chunk boundaries
- [ ] Session invalidation when stored cwd ≠ current project path
- [ ] Kimi exit-code-75 → `retryable: true`
- [ ] Symlink injector preserves nested paths (`skills/X/SKILL.md` stays at `skills/X/SKILL.md` inside tmp)

## Before Submitting PR

- [ ] All JSON writes to `state/` and `data/` are atomic (temp + rename)
- [ ] Any new CLI flag is already in the locked matrix; if not, the matrix is updated and the PR description explains why
- [ ] No write paths into project `path` directories — verified by grep
- [ ] Symlink injector teardown runs on success, abort, AND error paths
- [ ] If touching trigger code: coalescing + debounce verified under load
- [ ] No DB libs added; no Anthropic SDK / HTTP API added
- [ ] Required unit tests above remain green
