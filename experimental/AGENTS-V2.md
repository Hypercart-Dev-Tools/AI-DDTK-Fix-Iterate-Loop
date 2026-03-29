## Communication & Documentation

- Precise, concise chat replies/updates: Short as possible, detailed enough.
- Reduce redundancy/duplication unless critical.
- New docs: High-level TOC at top; checklist + phased format; actionable items visible. Suggest Phase 0 technical spike (1-2h max) to validate assumptions/critical paths first.
- Do not create new MD/text files unless instructed. Append to existing project docs.
- Add things to remember to MEMORY.md
- General workflow: 1-2 step ad-hoc requests to direct implementation. If 4-5 steps with multiple phases, write project MD file first.
- Slight pushback OK if security/maintainability/destructive risk ahead.

## UI Design

- Layout follows the user's decision sequence, not the system's data structure.
- Label roles at the point of action — if the user must scroll or remember context to understand what a control does, the label is missing.
- Every repeated component (card, row, panel) must be self-describing without surrounding context.
- Design for how the user reads, not how the data is stored or fetched.
- Default to the most common action. If 80% of users will pick the same option, pre-select it — don't make the majority click what the system already knows.

## Code & Architecture

- Code: DRY, SOLID; balance maintainability, performance, secure. Comply with framework security best practices.
- **State Management**: Introduce FSM (Finite State Machine) if state transitions exceed 4 distinct states or more than one conditional branch per state. Document state diagram in code comments or `/docs/state-machine.md`.
- **Contracts**: Designate single writer per contract/schema (API response shape, DB record structure, queue message format). Changes require review from contract owner; broadcast breaking changes immediately.
- **Pipelines**: One logical pipeline per data flow whenever possible. Avoid forking/rejoining; use filters, transforms, and side effects in sequence. If pipeline needs multiple paths, use conditional routing within single pipeline, not separate pipelines.

## Anti-Patterns to Avoid

- N+1 queries (e.g., loop API/DB calls; batch/paginate instead).
- Unpaginated API/DB calls (always use `per_page=100`, `page` iteration).
- Unbound DB queries (add `LIMIT 1000`, timeouts).
- Infinite loops/recursion without bounds.
- High-rate API bursts (respect GitHub 5000/hr PAT limits; sleep/retry).
- Hardcoding credentials or secrets in code or config files.
- Destructive operations without explicit confirmation or dry-run support.

## Security & Credentials

- Do not store credentials, personal/project/client names, most emails in repo unless in confirmed gitignored `/temp/` or config folder. Double-check for leaks.
- Use environment variables or `.env` files (always gitignore `.env`). Never hardcode credentials.
- For production integrations, reference Vault, AWS Secrets Manager, or equivalent secret storage.
- Log credential usage (masked) to audit trail; log actual credential values only to secure, non-repository logs.
- Mask sensitive data in logs (credentials, tokens, email addresses).

## Destructive Operations

- Log all DELETE/DROP/TRUNCATE operations with timestamp, user, and target to `/logs/agent-audit.json`.
- Require explicit confirmation flag (e.g., `--confirm` or env var `CONFIRM_DESTRUCTIVE=true`) before executing.
- Support `--dry-run` mode when applicable; output what _would_ be deleted without executing.
- If operation affects >1000 rows/records, require additional confirmation or escalation.
- Pause and escalate if operation is blocked or validation fails; do not retry silently.

## Observability & Tests From Day One

- Every new service, plugin, or pipeline ships with structured logging, health checks, and at least one integration test before merging to main.
- Instrument first, optimize later. Add timing/counters to critical paths (DB queries, API calls, queue processing) at build time — retrofitting observability is 5x harder.
- Log with context: every log line should include enough to trace a request end-to-end (request ID, tenant/user ID, operation name). Avoid generic messages like "error occurred."
- Health check endpoints (`/healthz`, `wp-admin` heartbeat, cron verification) are not optional — they are part of the definition of done.
- Write the smoke test that proves the happy path works before writing any feature code. If you can't test it, you can't ship it.
- Alerts should be actionable. If a threshold fires, the runbook or next step should be obvious. No alert without a documented response.
- For WordPress/WooCommerce: hook into `query_monitor` data, log slow queries (>500ms), and monitor Action Scheduler queue depth from the start.
- Dashboards and log queries are deliverables, not afterthoughts. Include them in the PR or project doc alongside the code.

## Testing & Mock Harnesses

- Write tests _before_ integrating with external APIs. Use mock harnesses to simulate responses.
- Mock harnesses should cover: happy path, rate limits (429), timeouts (504), malformed responses, and auth failures (401/403).
- Store mock response fixtures in `/fixtures/` (JSON, YAML, or plaintext). Keep them realistic and versioned.
- Use conditional logic or env vars (`MOCK_MODE=true`) to toggle between real and mock backends without code changes.
- For external integrations (Shopify, WooCommerce, Meta Ads, GA4), create a mock server or HTTP interceptor (e.g., `nock` in Node, `responses` in Python, `http-mock` in Go).
- Test both sync and async paths separately; async errors (timeouts, retries) are common blindspots.
- Assert on side effects (logs, DB writes, queue messages) not just return values. Mock should verify agent behavior, not just response parsing.

## Versioning & Changelog

- There is no concept of "Unreleased." Every fix or feature gets a version bump at time of commit/merge.
- Use semver: MAJOR for breaking changes, MINOR for features, PATCH for fixes.
- Documentation-only changes do not increment version unless explicitly instructed.
- Changelog entries describe _what changed and why_ in plain language. Do not include project names, filenames, or folder paths in changelog entries — those belong in `4X4.md` or project docs, not the changelog.
- Format: `## [x.y.z] - YYYY-MM-DD` followed by `### Added`, `### Changed`, `### Fixed`, `### Removed` as applicable.

## Monitoring & Safety

- Audit deps weekly (`safety check`, Dependabot).
- Rate limit APIs; exponential backoff on 429s.

## Phase 0 Technical Spikes

- When proposing phased work, include Phase 0 spike (1–2h max) to validate critical assumptions.
- Phase 0 should test: API availability, DB connectivity, performance baseline, and blocking dependencies.
- If Phase 0 surfaces blockers or contradicts assumptions, pause and escalate; do not proceed to Phase 1.
- Document Phase 0 findings in spike report before committing to later phases.

---

## 4X4 Template

**Extract into separate `4X4.md` file.** If one exists already, rename existing to `4X4-deprecated.md`.

**Why it's called 4X4:** 4 Domains (Strategic Goals, Current Goals, Past Goals, Lessons Learned) × 4 Tasks

Keep this file short and sweet. Enough details but barely enough to point in the right direction. Start with only 4 weekly goals. Cross those off first before adding more.

```
PROJECT OVERVIEW
[insert here]

PROJECT ANTI-GOALS (OPTIONAL)

A. STRATEGIC GOALS
1. [insert here]
2. [insert here]
3. [insert here]
4. [insert here]

B. CURRENT WEEK GOALS
1. [insert here]
2. [insert here]
3. [insert here]
4. [insert here]

C. LAST WEEKS ACCOMPLISHMENTS
1. [insert here]
2. [insert here]
3. [insert here]
4. [insert here]

D. RECENT LESSONS LEARNED
1. [insert here]
2. [insert here]
3. [insert here]
4. [insert here]
```

---

Attn: LLM Remove 4X4 section after extraction.
