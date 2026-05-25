# optimize playbook


# optimize

Condense without losing information.

**CRITICAL: NEVER touch git. Just read, optimize, write back.**

**ONLY OPTIMIZE CURRENT FILE CONTENTS — NEVER revert to a previous version, use memory, or reconstruct from scratch.**

## Preserve

Behavior, interfaces, decision trees, examples, exit criteria. ALL current content — only remove redundancy within it.

## Remove

Fluff ("It is important to note", "Please make sure"), redundant explanations, decorative formatting, self-evident statements.

## Compress

| Pattern | Action |
|---------|--------|
| Verbose phrases | Concise terms |
| "You should..." | Imperative: "Do..." |
| Bullets with 1 item | Inline |
| Short sections (<3 lines) | Merge into parent |
| Duplicate examples | Keep one |

## Process

1. **READ the file** from disk
2. **WORK from what you read** — never use memory of previous versions
3. **Identify core** — behavior, constraints, examples
4. **Strip noise** — fluff, redundancy, decorative formatting
5. **Restructure** — reformat for clarity, merge short sections
6. **Verify** — behavior preserved, interfaces unchanged
7. **Write back**

## Constraints

- **ONLY** edit the file you just read
- **NEVER** change: names, paths, command syntax, tool calling patterns
- **NEVER** change: sub-skill invocation format (always `/$SKILL_NAME` or `/$SKILL_NAME $INPUT`)
- **NEVER** remove: error handling, preconditions, concrete examples
- **ALWAYS** keep: exit checklists, decision trees, actual constraints
- **NEVER** run git commands

## Example

Before:
````markdown
## Installation Process

To install dependencies, run this command. It installs packages.

```bash
npm install
```
````

After:
```markdown
## Install

```bash
npm install  # requires Node.js
```
```

## Verify

- [ ] Optimized ONLY the current file contents
- [ ] No changes reverted or reconstructed from memory
- [ ] Behavior preserved
- [ ] No interface changes
- [ ] Fewer tokens
