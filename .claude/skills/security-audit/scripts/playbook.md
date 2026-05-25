
# security-audit playbook

## Original heading: security-audit

**Called by:** `incremental-security`

## Input

Internal: `$PROJECT_ID, $files`

## Output

````
==== SECURITY FINDINGS ====
#### File: `path/to/file` (Line X)

- **Severity:** critical|error|warning
- **Category:** Injection|Cross-Site|Authentication|Access Control|Server-Side|Deserialization|Configuration|Cryptographic|Upload|API|Other
- **Attack:** SQL Injection|XSS|CSRF|SSRF|IDOR|etc.
- **Issue:** specific vulnerability
- **Fix:**
  ```language
  fixed code
````

...
==== END FINDINGS ====
````

No issues: `==== NO ISSUES ====`

**Severity:** `critical` = directly exploitable (breach/RCE) | `error` = must fix before production | `warning` = context-dependent weakness

## Workflow

### 1. Load Rules

Resolve rules dir (first match: `.claude/skills/_rules/`, `.claude/skills/_rules/`, `~/.claude/skills/_rules/`). Read `$RULES_DIR/security.md`.

### 2. Parse Input

No files → output `==== NO FILES ====` and exit.

### 3. Audit Files

- **Flag only:** concrete, exploitable vulnerabilities with code evidence
- **Never flag:** theoretical risks, missing features, style, docs gaps
- **Fix:** concrete code, not vague advice
- **Skip:** `*.test.*`, `*.spec.*`, `__tests__/`, `tests/`, `test/`, `.vscode/`, `.idea/`, non-code files

### 4. Output

```bash
if [ -z "$FINDINGS" ] || [ "$FINDING_COUNT" -eq 0 ]; then
    echo "==== NO ISSUES ===="
    exit 0
fi

echo "==== SECURITY FINDINGS ===="
echo "$FINDINGS"
echo "==== END FINDINGS ===="
echo ""
echo "Found $FINDING_COUNT security issue(s)" >&2
```

## Exit

- [ ] Security rules loaded (`$RULES_DIR/security.md`)
- [ ] PROJECT_ID received as first argument
- [ ] Files received as remaining arguments
- [ ] Test files skipped
- [ ] Only concrete, exploitable vulnerabilities flagged
- [ ] Each finding has severity, category, attack, issue, fix
- [ ] Findings in standard format (or `==== NO ISSUES ====`)
- [ ] Print `SECURITY-AUDIT COMPLETE` after output
