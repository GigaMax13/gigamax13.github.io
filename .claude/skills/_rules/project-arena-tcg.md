---
alwaysApply: false
description: "Rules for project-arena-tcg"
---

# Project Rules: Arena Heroes TCG

> Extends: code-quality.md, react.md

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** use Prisma `delete()` on soft-deletable models — use `update({ is_active: false })`
- [ ] **NEVER** store signed S3 URLs in DB — store the key, generate URL at read time
- [ ] **NEVER** instantiate `new PrismaClient()` — import `db` from `~/server/db`

<!-- verify-rules:start
forbid:new\s+PrismaClient\( ext:ts,tsx exclude:server/db,.test.,.spec. message:use db singleton from ~/server/db
forbid:\.card\.delete\( ext:ts,tsx exclude:.test.,.spec. message:use soft-delete (is_active false)
verify-rules:end -->

## tRPC Architecture

- [ ] Endpoints in `src/server/api/routers/` (card.ts, deck.ts); Zod schemas in `src/server/api/schemas/`
- [ ] No REST endpoints, no direct DB/Prisma from pages/components
- [ ] Server: `await api.resource.action()` | Client: `.useQuery()` / `.useMutation()`

## Prisma & Imports

> Generic patterns: see `database.md`

- [ ] Import Prisma types from `@prisma/client` (no `~/prisma` re-export in this project)
- [ ] Enum constants for UI in `~/server/api/schemas/cards.ts`
- [ ] Prisma singleton at `~/server/db` — never instantiate `PrismaClient` elsewhere

## Soft-Delete (`is_active` boolean, NOT `deletedAt`)

- [ ] Filter active: `where: { is_active: true }`
- [ ] Soft-delete: `update({ data: { is_active: false } })` — never `delete()`
- [ ] Hard delete only via explicit `hardDelete` procedure
- [ ] Test both: non-existent records AND `is_active: false` records

```typescript
// ✅
await ctx.db.card.update({
  where: { id: input.id },
  data: { is_active: false },
});
await ctx.db.card.findMany({ where: { is_active: true } });
// ❌
await ctx.db.card.delete({ where: { id: input.id } });
```

## Clerk Authentication

- [ ] Auth via `ctx.auth.userId`; protected: `protectedProcedure`; public: `publicProcedure`
- [ ] User-scoped queries filter by `user_id: ctx.auth.userId`
- [ ] Middleware at `src/middleware.ts` using `clerkMiddleware()`

## S3 / Image Storage

- [ ] Local: MinIO (`localhost:9000`); Prod: Supabase Storage
- [ ] Signed URLs via `~/server/s3.ts` (`getSignedGetUrl`, `getSignedPutUrl`); expiry: 3600s
- [ ] Upload: client gets signed PUT URL via `card.getUploadUrl`, uploads directly
- [ ] Store S3 key in DB as `image_url` — never the signed URL; generate at read time
- [ ] Env vars: `S3_ENDPOINT_URL`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`

```typescript
// ✅ store key, generate URL at read time
data: {
  image_url: "cards/1234-hero.png";
}
const signedUrl = await getSignedGetUrl(card.image_url);
// ❌ never store signed URL
data: {
  image_url: "https://s3.../cards/1234-hero.png?X-Amz-Signature=...";
}
```

## Soft-Delete Cascade — Sets & Cards

- [ ] `Set.is_active = false` does NOT cascade to `Card.is_active`
- [ ] Card queries (`card.getAll`, `card.getById`, `card.getManyByIds`) filter only on `Card.is_active` — no join-filter by `Set.is_active`
- [ ] Soft-deleting a set leaves its cards visible by design: sets are display/grouping metadata, not a visibility gate
- [ ] To hide a soft-deleted set's cards, soft-delete each card explicitly; any future change joining `Set.is_active` into card queries must be called out as a behavior change

## Set Mutation Access

Set mutations (`create`, `update`, `softDelete`, `hardDelete` on `setRouter`) are gated only by `protectedProcedure` — any authenticated Clerk user may run them.

- [ ] No per-row ownership check on `Set` (no `user_id` column)
- [ ] No admin role / Clerk metadata check — every signed-in user is trusted
- [ ] Rationale: private design/admin tool; sets are shared game data. `adminProcedure` would require Clerk publicMetadata config, intentionally out of scope
- [ ] If trust model changes (public signups, multi-tenant), introduce `adminProcedure` middleware (Clerk `publicMetadata.role === 'admin'`) and gate all four set mutations
- [ ] Reviewers: do not flag set mutations as missing access control unless the trust model has actually changed

## Game Design Constraints

- [ ] Card types: EQUIPMENT, FORM, HERO, ITEM, SKILL, SUMMON, TACTICS, TOTEM
- [ ] Classes: ALL, DRUID, CLERIC, PALADIN, RANGER, ROGUE, SHAMAN, WARRIOR, WIZARD
- [ ] Resources: ENERGY, MANA, RAGE | Rarities: COMMON, MAGIC, RARE, EPIC, LEGENDARY
- [ ] Max 4 copies per card per deck — enforced in `deck.addCard`
- [ ] Cards have multiple classes (array); card skills link via `CardSkill` join table

## Sync & Docker (Local Dev)

- [ ] `yarn sync:pull` — Supabase → local Docker | `yarn sync:push` — local → Supabase (confirm first)
- [ ] Credentials: `.env.supabase` (gitignored), `.env` (local) | Scripts in `scripts/`
- [ ] `yarn docker:up` — postgres:16 + minio + minio-init | `yarn docker:reset` — wipe volumes
- [ ] MinIO console: `localhost:9001` (minioadmin/minioadmin) | Postgres: `localhost:5432` (postgres/postgres/tcg_web)

## File Size Exception

`src/app/_components/card-form.tsx` exceeds 399 lines — do NOT refactor without explicit request. If touched, extract sub-section components (e.g., ResourceFields, SkillFields).

## Environment Validation

- [ ] All env vars validated via `@t3-oss/env-nextjs` in `src/env.js`
- [ ] New env var: update BOTH `src/env.js` AND `.env.example` | `SKIP_ENV_VALIDATION=1` for Docker builds

## Before Submitting PR

- [ ] `yarn check` (lint + typecheck) and `yarn build` pass
- [ ] Soft-delete queries filter `is_active: true`
- [ ] New S3 keys follow `cards/{timestamp}-{filename}` pattern
- [ ] User-scoped data filtered by `ctx.auth.userId`
