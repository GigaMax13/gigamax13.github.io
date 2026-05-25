---
alwaysApply: false
description: "Relaxed, metric-driven philosophy and thresholds for the flow-* skill family"
---

# Flow Rules (Metrics-Driven, TDD-Required)

> Active only when `--flow` mode is in effect. Adds metric thresholds and a metric-driven gate philosophy on top of the standard rule context (`guard-clauses`, `tdd`, `code-quality`, `security`, `project-{ID}`, language, database).

## Philosophy

Same rule context in both modes; mode picks the _gate_, not the rules. Strict gates with grep + self-verification; flow gates with measurable signals.

- **TDD is mandatory** — follow `tdd.md`: Red → Green → Refactor. All tests mocked (no real API / DB / FS / network). Every behavior change lands behind a failing test.
- **Coverage is a hard gate** — review fails if line < 80% or branch < 60% (overridable via `flow.config.yaml`).
- **Measure:** coverage, cyclomatic/cognitive complexity, module sizes, duplication, dependency structure, mutation score.
- Per-file line limits, `any` / `@ts-ignore` bans, TODO markers, security / project-rule evidence are **gated mechanically via `verify.sh --json`** (same grep engine as strict). Each violation counts as one `fail` in the merged Step 5 result. Metric thresholds (coverage, complexity, duplication) are added on top, not in place of, the deterministic gate.
- Failing metrics and `verify.sh` violations are **both reported**; agent iterates within the same max-2 revision cap.

## Thresholds (opinionated defaults)

Overridable per project via `$DEV_DIR/flow.config.yaml` (missing keys fall back to defaults).

| Metric                               | Threshold      | Severity |
| ------------------------------------ | -------------- | -------- |
| Line coverage                        | ≥ 80%          | **fail** |
| Branch coverage                      | ≥ 60%          | **fail** |
| Cyclomatic complexity (per function) | ≤ 10           | warn     |
| Cyclomatic complexity (per function) | ≤ 15           | fail     |
| Cognitive complexity (per function)  | ≤ 15           | warn     |
| File size                            | ≤ 399 lines    | **fail** |
| Duplication                          | ≤ 5% of tokens | warn     |
| Mutation score (opt-in: `--include-mutation`) | ≥ 60%          | warn     |
| Dependency cycles                    | 0 allowed      | warn     |

Severity:

- **info** — reported, not counted against pass/fail.
- **warn** — counts against aggregate; run still completes.
- **fail** — counts against aggregate; flow-mode review marks report FAILED.

## Per-project override

`flow-metrics` reads `$DEV_DIR/flow.config.yaml` on every run via `load-config.sh` and uses any keys present to override the defaults below. Missing file → defaults. Missing keys → defaults. Malformed file → defaults (silent).

Create `$DEV_DIR/flow.config.yaml`:

```yaml
# Any key omitted falls back to defaults above.
# Example shows a legacy project relaxing the strict defaults.
coverage:
  line: 70       # relax from default 80
  branch: 50     # relax from default 60
complexity:
  cyclomatic:
    warn: 8
    fail: 12
  cognitive:
    warn: 12
files:
  lines:
    fail: 500    # relax from default 399
duplication:
  tokens: 3
mutation:
  minScore: 70
dependencies:
  cyclesAllowed: 0
# Optional: skip specific metrics entirely
skip:
  - mutation
  - duplication
```

## Tools (per language)

Each metric uses a language-native tool. **Missing tool → `SKIPPED: <tool>`.** Never hard-fails.

**Coverage exception:** outside `--quick` mode, missing or failing coverage tooling (e.g., no `vitest` installed, `pytest` crashes) is recorded as a `fail` instead of `skipped`, since unmeasured coverage cannot be distinguished from 0% coverage. `--quick` mode and explicit `skip:` entries in `flow.config.yaml` still record as `skipped`. When `$DEV_DIR/.test-map.md` is present, the collector runs the `Coverage Command` it documents (preferred) and reports a fail with the underlying error if that command produces no parseable output.

**Mutation exception:** mutation testing is **opt-in only** via `flow-metrics --include-mutation` (slow — typically minutes to tens of minutes). Without that flag, mutation always records as `skipped` regardless of whether the tool/config is present. With the flag, missing config for TS/Python is auto-scaffolded by `scripts/scaffold-mutation.sh`; Go and Rust tools work without config but must be installed manually.

| Language           | Coverage                                    | Complexity                                     | Duplication                      | Deps                   | Mutation                          |
| ------------------ | ------------------------------------------- | ---------------------------------------------- | -------------------------------- | ---------------------- | --------------------------------- |
| TypeScript / React | `vitest run --coverage` / `jest --coverage` | `complexity-report` / ESLint `complexity`      | `jscpd`                          | `madge --circular`     | `stryker` _(opt-in; auto-scaffolded)_ |
| Python             | `pytest --cov`                              | `radon cc -a` + `radon mi`                     | `pylint --enable=duplicate-code` | `pydeps --show-cycles` | `mutmut` _(opt-in; auto-scaffolded)_  |
| Go                 | `go test -cover`                            | `gocyclo`                                      | `dupl`                           | `go mod graph`         | `go-mutesting` _(opt-in)_             |
| Rust               | `cargo tarpaulin`                           | `cargo clippy -W clippy::cognitive_complexity` | —                                | `cargo modules`        | `cargo mutants` _(opt-in)_            |
