---
name: discover-tests
description: Scan tests, generate .dev/.test-map.md.
model: haiku
---


# discover-tests

Generate `$DEV_DIR/.test-map.md` — a source-file-to-test-command map used by `do-development`, `validate scoped`, and `fix-review` for scoped test runs. Generated once; regenerate when test structure changes.

## Execution

```bash
_sh="${AGENTS_SKILLS_HOME:-"${CLAUDE_PROJECT_DIR:-.}"/.claude}"
[ -f "$_sh/skills/discover-tests/scripts/playbook.sh" ] || _sh="$HOME/.claude"
bash "$_sh/skills/discover-tests/scripts/playbook.sh"
```

Read the playbook output and execute every numbered step in order. End by printing `DISCOVER-TESTS COMPLETE`.
