---
alwaysApply: false
description: "Shared code quality: file size, components, dead code, styling, UI patterns"
---

# Code Quality Rules

## CRITICAL — ENFORCED BY verify-rules

- [ ] **NEVER** exceed 399 lines per file (any code file)
- [ ] **NEVER** use `any` type in TypeScript/TSX
- [ ] **NEVER** add suppression comments: `// @ts-ignore`, `// @ts-expect-error`, `// eslint-disable`
- [ ] **NEVER** leave `TODO`, `FIXME`, or `XXX` markers in committed code
- [ ] **NEVER** leave `console.log` in non-test `.ts`/`.tsx` files
- [ ] **NEVER** leave `print(` debug calls in non-test Python source

<!-- verify-rules:start
max-lines:399 ext:ts,tsx,js,jsx,py,go,rs,java,rb,php,c,cpp,swift,kt,scala exclude:tools/
forbid:@ts-ignore ext:ts,tsx message:no @ts-ignore allowed
forbid:@ts-expect-error ext:ts,tsx message:no @ts-expect-error allowed
forbid:eslint-disable ext:ts,tsx,js,jsx message:no eslint-disable allowed
forbid::\s*any(?![A-Za-z_0-9]) ext:ts,tsx exclude:.test.,.spec.,.d.ts message:no any type
forbid:<any> ext:ts,tsx exclude:.test.,.spec.,.d.ts message:no any generic
forbid:\bas\s+any\b ext:ts,tsx exclude:.test.,.spec.,.d.ts message:no as any cast
forbid:\bTODO\b ext:ts,tsx,js,jsx,py,go,rs message:no TODO markers
forbid:\bFIXME\b ext:ts,tsx,js,jsx,py,go,rs message:no FIXME markers
forbid:\bXXX\b ext:ts,tsx,js,jsx,py,go,rs message:no XXX markers
forbid:console\.log ext:ts,tsx,js,jsx exclude:.test.,.spec.,scripts/ message:no console.log in prod code
verify-rules:end -->

## Components

- [ ] Server Components by default; `'use client'` only for interactivity
- [ ] Stable unique `key` prop for list items (not index)
- [ ] Check `components/ui/` (shadcn) before creating new components
- [ ] No page-level logic/styling — use reusable components
- [ ] Composition over prop bloat
- [ ] Controlled mode works without visible trigger
- [ ] Use project's Link component — never raw `<a>` tags (except external)
- [ ] Props pass through correctly — preserve refs and handlers
- [ ] Compose with shadcn components using variant/size props — never copy-paste Button CSS

## Function Reuse & Utils

- [ ] Search before creating — verify no similar functions exist
- [ ] Never duplicate — import existing functions
- [ ] 3+ imports = move to shared utils (e.g., `src/lib/utils.ts`)

## Dead Code Removal

- [ ] Every function/component must be imported by production (non-test) code
- [ ] Test-only imports: remove function AND update/remove tests
- [ ] Non-exported functions MUST be used locally — delete if unused

```bash
# Find imports of named export
rg "import.*\{[^}]*MyComponent[^}]*\}" --type ts --type tsx

# Check if ONLY imported by test files
rg "import.*MyComponent" --type ts --type tsx | grep -v '\.test\.' | grep -v '\.spec\.'

# Scan file for dead exports
cat src/lib/utils.ts | grep -E "^export (function|const|class|interface|type)" | awk '{print $3}' | sed 's/[:<(].*//' | while read name; do
  echo "=== $name ==="
  rg "import.*$name" --type ts --type tsx | grep -v '\.test\.' | grep -v '\.spec\.'
done

# Find unused LOCAL functions
find src -name "*.ts" -o -name "*.tsx" | while read file; do
  grep -E "^(function |const |async function )" "$file" 2>/dev/null | grep -v "^export" | while read line; do
    name=$(echo "$line" | sed 's/function //;s/const //;s/async //' | awk '{print $1}' | sed 's/(.*//;s/:.*//')
    calls=$(grep -E "\b$name\(" "$file" 2>/dev/null | wc -l | tr -d ' ')
    defs=$(grep -E "\b$name\s*[=:]" "$file" 2>/dev/null | wc -l | tr -d ' ')
    [ "$calls" -le "$defs" ] && [ -n "$name" ] && echo "$file: UNUSED LOCAL: $name"
  done
done
```

## UI/UX Patterns

- [ ] Consistent empty/error/loading states (shared components)
- [ ] No card-in-card anti-pattern
- [ ] Entire row clickable for list items

## Migration Checklist Template

```md
- [ ] Create abstraction (component/util/hook)
- [ ] Count total callsites (grep)
- [ ] Migrate: all pages, components, layouts
- [ ] Verify no old patterns remain (grep)
- [ ] Test in browser
- [ ] Verify build succeeds
```
