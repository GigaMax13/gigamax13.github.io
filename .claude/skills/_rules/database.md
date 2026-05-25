---
alwaysApply: false
description: "Rules for database"
---

# Database & ORM Rules

> Loaded when: `prisma/schema.prisma`, `drizzle.config.ts`, or ORM deps in `package.json` detected.
> SQL injection prevention: see `security.md`.

## Schema Design

- [ ] PascalCase model names (singular), camelCase fields
- [ ] Both sides of relations explicitly defined
- [ ] `@map`/`@@map` for legacy naming conventions
- [ ] NOT NULL by default — nullable only when justified
- [ ] UNIQUE on business-unique columns, CHECK for business rules
- [ ] Every table has a primary key

## Prisma

**Type Safety:** Import types from generated client — never re-declare; no `any`; no duplicated declarations mirroring models.

### Query Optimization

- [ ] `select` to whitelist fields — no implicit SELECT \*
- [ ] `include` only for needed relations
- [ ] Cursor-based pagination for large datasets
- [ ] N+1 prevention: `include` or `findMany` with `where`, not loops

```typescript
// ❌ N+1
const posts = await prisma.post.findMany();
for (const post of posts) {
  const user = await prisma.user.findUnique({ where: { id: post.userId } });
}
// ✅
const posts = await prisma.post.findMany({ include: { user: true } });
```

### Error Handling

- [ ] Use `PrismaClientKnownRequestError` with `error.code` — not string matching
- [ ] Handle: P2002 (unique), P2025 (not found), P2003 (foreign key)

```typescript
// ❌
if (error.message.includes('Unique constraint failed')) { ... }
// ✅
if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') { ... }
```

### Transactions & Raw Queries

- [ ] Interactive transactions for multi-step operations
- [ ] No `$queryRaw`/`$executeRaw` with string interpolation — use `Prisma.sql`

```typescript
// ❌
await prisma.$queryRaw(`SELECT * FROM users WHERE id = ${userId}`);
// ✅
await prisma.$queryRaw(Prisma.sql`SELECT * FROM users WHERE id = ${userId}`);
```

## Drizzle

- [ ] Type-safe query builder — no raw SQL for standard operations
- [ ] Compile-time type inference; explicit relation definitions
- [ ] `.select()` to limit columns, prepared statements for frequent queries
- [ ] All `delete()` include `where` — never unconditional

```typescript
// ❌
const users = await db.select().from(usersTable);
// ✅
const users = await db
  .select({ id: usersTable.id, name: usersTable.name })
  .from(usersTable);
```

## SQL & PostgreSQL

- [ ] Parameterized queries only — never string concatenation
- [ ] Foreign key columns indexed; indexes on frequently filtered/sorted columns; no unused indexes
- [ ] Verify with `EXPLAIN ANALYZE` on staging
- [ ] Foreign keys enforce referential integrity with explicit cascade/restrict
- [ ] Isolation level chosen per use case, retry logic for serialization failures

## Migration Safety

- [ ] **Expand-contract** for breaking changes: Expand (add schema) → Migrate (deploy + backfill) → Contract (remove old)
- [ ] Never drop columns in same release as code removal
- [ ] Test on staging with production-like data, rollback plan documented
- [ ] Small additive migrations; failed: `prisma migrate resolve --rolled-back`
- [ ] **Migrations are human-only — never auto-run by agent**

## Soft Delete

- [ ] Two-check pattern: existence first, then `deletedAt`
- [ ] Test both: non-existent AND soft-deleted records
- [ ] Never `?.deletedAt !== null` — `undefined !== null` is `true`
- [ ] `permanentlyDelete*` MUST verify `deletedAt !== null` before hard delete
- [ ] Preserve original `createdBy` on derived records

```typescript
// ❌ BUG: undefined !== null === true
const item = await db.item.findUnique({ where: { id: input.itemId } });
if (item?.deletedAt !== null) return [];

// ✅
if (!item) throw new TRPCError({ code: "NOT_FOUND" });
if (item.deletedAt !== null) return [];
```

## Boundaries

| Always                             | Ask First               | Never                        |
| ---------------------------------- | ----------------------- | ---------------------------- |
| Parameterized queries              | Schema changes          | Run migrations               |
| `select`/`include` to limit fields | New indexes             | DROP TABLE/DATABASE          |
| Handle ORM errors by code          | Seed data changes       | DELETE FROM without WHERE    |
| Explicit transactions              | Isolation level changes | Raw queries with user input  |
| Test with mocks                    | New foreign keys        | Force-push migration history |
