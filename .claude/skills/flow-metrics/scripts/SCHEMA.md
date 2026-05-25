# flow-metrics output schema

All flow artifacts live in `$DEV_DIR/flow/` (resolved via `resolve-dev.sh`, never hardcoded).

## `$DEV_DIR/flow/data.json`

Single canonical structured artifact. Consumed by `review-code --flow`, `fix-review --flow`, `flow-dashboard`, `flow-review-loop`.

```jsonc
{
  "summary":     { /* aggregate counts: pass / warn / fail / skipped */ },
  "metrics":     [ /* per-tool entries: { tool, language, status, value, threshold, files? } */ ],
  "skipped":     [ /* { tool, reason } when a tool is missing */ ],
  "baseline":    null /* or the prior data.json contents when --base set */,
  "languages":   [ /* detected languages, e.g. ["ts","py"] */ ],
  "generatedAt": "ISO-8601 UTC"
}
```

## `$DEV_DIR/flow/report.md`

Single unified human view. Summary line + conditional sections:
- **Fails** — tools that crossed the fail threshold.
- **Warnings** — tools that crossed the warn threshold.
- **Info** — informational metrics (e.g. line counts).
- **Skipped tools** — missing tools, with install hints.
- **How to fix** — actionable next steps.
- **Trend vs base** — only when `--base` produced a baseline.

## Retired output paths

The following older paths are no longer written:

- `$DEV_DIR/flow-metrics.{json,md}`
- `$DEV_DIR/flow-review.md`
- `$DEV_DIR/flow-dashboard.md`
- `$DEV_DIR/flow-metrics.{head,base}.json`
