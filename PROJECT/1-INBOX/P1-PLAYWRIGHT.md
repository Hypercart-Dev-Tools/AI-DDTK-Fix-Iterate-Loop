---
title: "P1: Robust Playwright Support"
status: in_progress
author: noelsaw
created: 2026-03-10
updated: 2026-03-10
project: AI-DDTK
category: feature
priority: P1
parent: P1-MCP-SERVER.md (follow-up to Phase 3: pw-auth & Playwright tools)
---

## TOC

- [Phased Checklist (High-Level Progress)](#phased-checklist-high-level-progress)
- [Overview](#overview)
- [Current State](#current-state)
- [Goals & Non-Goals](#goals--non-goals)
- [Recommended Architecture](#recommended-architecture)
- [Phased Plan](#phased-plan)
- [Success Criteria](#success-criteria)
- [Open Questions](#open-questions)

---

## Phased Checklist (High-Level Progress)

> **Note for LLM agents:** Continuously update this checklist as work progresses. Keep this section as the single source of truth for phase completion and decision status.

- [x] **Phase 1 — Readiness & Auth Foundation** · Effort: Med · Risk: Low
  - [x] Add a reliable Playwright runtime check (Node.js, module resolution, browser binaries, browser launch)
  - [x] Add `pw-auth doctor` as the canonical doctor command; `install.sh` may delegate to it as a convenience wrapper
  - [x] Validate `pw-auth` prerequisites, login reuse, and common failure modes (`NODE_PATH`, Chromium install, certs)
  - [x] Return machine-readable and human-readable `ready` / `partial` / `blocked` results
  - [x] **Stop and check**: confirm dependable login/readiness on 2–3 realistic environments before moving on
    - [x] Validated end-to-end on `https://macnerd-xyz-09-10.local` using a real admin user, Local HTTPS, global npm-root / `NODE_PATH` Playwright resolution, and a verified cached auth file that reaches `/wp-admin/`
    - [x] Validated end-to-end on `https://site-uclasacto.local` using the real `neochrome_jose` administrator account, a direct Local WP-CLI wrapper, and a verified cached auth file at `temp/playwright/.auth/neochrome_jose.json`

- [ ] **Phase 2 — Authenticated DOM/HTML Inspection MVP** · Effort: Med · Risk: Low–Med
  - [ ] Add a DOM inspection subcommand under `pw-auth` instead of introducing a new top-level binary in the MVP
  - [ ] Support selector existence, text extraction, and `innerHTML` extraction
  - [ ] Infer auth origin from `--url` by default, with override only for edge cases
  - [ ] Save structured JSON results under `temp/playwright/checks/<run-id>/`
  - [ ] Keep screenshots/traces optional later; they are not required for the first useful release
  - [ ] **Pause/review**: confirm widget-area HTML inspection solves a real project need before starting Phases 3–5

- [ ] **Phase 3 — MCP Agent Access to Browser Checks** · Effort: Med · Risk: Med
  - [ ] Add typed MCP tools for doctor and DOM/HTML inspection while reusing existing `pw_auth_status` for auth status
  - [ ] Return structured pass/fail results, extracted content, and artifact metadata instead of raw console output
  - [ ] Keep custom script execution out of the first MCP pass

- [ ] **Phase 4 — WordPress Presets & Safe Admin Actions** · Effort: Med · Risk: Med
  - [ ] Add widget-area inspection presets for front-end and relevant wp-admin/editor screens
  - [ ] Add category list/create/delete/verify presets for wp-admin
  - [ ] Define a declarative YAML/JSON preset format instead of requiring custom Node.js scripts for initial presets
  - [ ] Add explicit guardrails for write operations: confirmation, dry-run where possible, and post-action verification
  - [ ] Where useful, pair Playwright UI actions with AI-DDTK verification via WP-CLI or related tools
  - [ ] Add recipes for LocalWP + `pw-auth` + Playwright workflows

- [ ] **Phase 5 — Guarded Custom Flows** · Effort: High · Risk: Med–High
  - [ ] Only start this phase if Phases 1–4 still leave important gaps
  - [ ] Decide between preset-only, config-driven, or allowlisted-file execution
  - [ ] Add stronger sandboxing/guardrails before exposing richer custom script execution

---

## Overview

AI-DDTK already has a strong starting point for Playwright authentication via `pw-auth`, but it does not yet provide a clean, dependable workflow for agents to log into wp-admin, inspect HTML/DOM, and safely perform narrow WordPress admin actions.

This plan rewrites the roadmap around the most practical sequence:

1. make login/readiness dependable,
2. make authenticated DOM/HTML inspection useful,
3. expose that workflow through MCP for VS Code agents,
4. add narrow WordPress presets such as category actions,
5. only then consider guarded custom flows.

For the first useful release, screenshots are optional and can stay in the wishlist.

---

## Current State

### Current Playwright vs planned extension

- **Current Playwright support** in AI-DDTK is mainly about **authentication bootstrap and session reuse**:
  - `pw-auth` can log into wp-admin and cache `storageState`
  - MCP can help with auth status/login flows
  - this is good for reachability, login validation, and lightweight smoke checks

- **The planned extension** is a broader **browser-check layer** on top of that foundation:
  - verify that Playwright is actually installed and runnable
  - run typed browser checks with predictable inputs/outputs
  - inspect selector state, extracted text, and HTML contents from front-end or admin screens
  - expose safe browser-check tools through MCP
  - add WordPress-specific presets for real tasks before allowing richer programmable checks

In short: **today AI-DDTK helps you get an authenticated browser session**; **the planned extension helps agents and developers use that session reliably to inspect HTML/DOM and perform repeatable WordPress browser tasks**.

### Working well today

- `pw-auth` login/bootstrap into wp-admin
- cached Playwright `storageState`
- Local/dev HTTPS tolerance for self-signed certificates
- MCP tools for `pw_auth_login`, `pw_auth_status`, and `pw_auth_clear`
- enough support for reachability/smoke verification in many cases

### Current gap

- runtime/module availability can still be inconsistent
- there is not yet a first-class wrapper for authenticated DOM/HTML inspection
- there is not yet a clean MCP path for VS Code agents to run those checks
- there are no narrow WordPress UI presets yet for things like widget inspection or category actions

---

## Goals & Non-Goals

### Goals

- **Make login readiness dependable** — a developer or agent should be able to tell quickly whether this machine has fully working Playwright support and reusable wp-admin auth.
- **Make HTML/DOM inspection useful early** — the first meaningful milestone should let an agent log into wp-admin, target a widget area or similar surface, and read text/HTML reliably.
- **Expose those checks cleanly to agents** — VS Code agents should be able to use AI-DDTK/MCP tools for browser inspection without inventing ad hoc shell scripts.
- **Add safe WordPress admin presets before open-ended scripting** — start with narrow, high-value actions like category create/delete/verify and widget-area inspection.
- **Defer wishlist features until the core loop works** — screenshots, traces, and richer artifacts can come later unless they become necessary for real debugging.

### Non-Goals

- Do not expose arbitrary browser scripting through MCP in the first pass
- Do not hardcode site credentials or store auth data outside the project `/temp` area
- Do not reimplement `pw-auth`; build on top of it
- Do not make screenshots a blocker for the first useful release

---

## Recommended Architecture

### Capability tiers

1. **Tier 1 — Readiness & auth foundation**
   - `pw-auth`
   - cached `storageState`
   - browser/runtime doctor checks
   - wp-admin auth validation

2. **Tier 2 — Inspection runner**
   - page open with or without auth
   - selector existence/text assertions
   - `innerHTML` / text extraction
   - structured JSON outputs under `temp/playwright/`

3. **Tier 3 — MCP agent layer**
   - typed MCP tools for auth validation and DOM/HTML inspection
   - structured pass/fail and extracted-content responses
   - safe inputs instead of arbitrary JS

4. **Tier 4 — WordPress presets & safe admin actions**
   - widget-area inspection presets
   - category create/delete/list/verify presets
   - optional verification through WP-CLI or other AI-DDTK helpers

5. **Tier 5 — Guarded custom flows**
   - reusable scripted flows only if still needed
   - allowlisted or config-driven execution
   - stronger execution controls

### Preferred implementation order

- **First**: Phase 1 readiness/auth foundation
- **Second**: Phase 2 authenticated DOM/HTML inspection MVP
- **Pause/Review**: confirm that MVP solves real project work before expanding
- **Third**: Phase 3 MCP agent access
- **Fourth**: Phase 4 WordPress presets and safe admin actions
- **Fifth**: Phase 5 only if important gaps remain

### Concurrency & browser lifecycle

- **Default for Phases 2–3:** each check should launch a fresh browser/context and shut it down when done.
- **Why:** this is simpler, safer, easier to reason about, and reduces cross-check state leakage when agents run multiple checks in sequence.
- **Design constraint:** the wrapper API should not assume that fresh launch is the only possible implementation forever.
- **Future optimization path:** a shared browser or pooled-context mode can be explored later if startup cost becomes a real bottleneck.
- **MVP rule:** optimize for correctness and isolation first; only optimize lifecycle reuse after real usage data shows it is worth the added complexity.

### Interface decision

- **Decision:** support both CLI and MCP.
- **CLI is the canonical implementation surface for Phases 1–2**, with MCP wrapping the same behavior for agent use.
- **Canonical Phase 1 doctor command:** `pw-auth doctor`
- **Canonical Phase 2 inspection command family:** `pw-auth check ...`
- `install.sh` may expose convenience setup/delegation commands, but should not become the primary home for Playwright inspection logic.

---

## Phased Plan

### Phase 1 — Readiness & Auth Foundation

Goal: make it easy to answer, "Can this machine log into wp-admin with Playwright reliably, or am I only partway set up?"

Suggested deliverables:

- `./install.sh doctor-playwright` or equivalent convenience wrapper
- `pw-auth doctor`
- checks for Node.js, Playwright resolution, Chromium availability, `NODE_PATH`, and browser launch success
- validation that cached auth can still reach `/wp-admin/` without dropping back to login
- clear `ready` / `partial` / `blocked` output with remediation guidance

#### Exact MVP command/tool spec

- **Convenience delegation entry point:** `./install.sh doctor-playwright --site-url <url> [...]`
  - Purpose: provide a familiar install-script entry point without duplicating doctor logic
  - MVP behavior: delegate directly to `pw-auth doctor`
  - Note: `install.sh` is a convenience layer; `pw-auth doctor` remains canonical

- **Doctor entry point:** `pw-auth doctor --site-url <url> [--wp-cli "<cmd>"] [--user <user>] [--format text|json]`
  - Purpose: answer whether the environment is ready for authenticated wp-admin browser work
  - Required input: `--site-url`
  - Optional input: `--wp-cli`, `--user` (default `admin`), `--format` (default `text`)
  - Checks performed:
    - Node.js present
    - Playwright module resolvable
    - Chromium/browser binary available
    - browser launch succeeds
    - cached auth file exists for requested user, if expected
    - `/wp-admin/` reachable with cached auth if auth is present
  - Exit codes:
    - `0` = `ready`
    - `1` = `partial`
    - `2` = `blocked`
  - JSON output contract:
    - top-level keys: `status`, `site_url`, `user`, `checks`, `auth`, `remediations`
    - `checks[]` item keys: `name`, `status`, `summary`, `detail`
    - `check.status` values: `pass`, `warn`, `fail`, `skip`
    - `auth` keys: `exists`, `file_path`, `status`
  - Implementation note: reuse the existing path/module resolution helpers already in `pw-auth`

- **Existing auth commands kept as-is in MVP:**
  - `pw-auth login --site-url <url> [--wp-cli "<cmd>"] [--user <user>]`
  - `pw-auth status`
  - `pw-auth clear`
  - MVP rule: Phase 1 should build on `pw-auth`, not duplicate login behavior or doctor logic in a second command family

**Stop/check gate after Phase 1:** pause here and verify this works on 2–3 realistic environments before building more.

Current validation status (2026-03-10):

- confirmed end-to-end on `https://macnerd-xyz-09-10.local`
- site required `WP_ENVIRONMENT_TYPE = development` because the dev-login mu-plugin correctly refuses `production`
- `local-wp` site discovery was unreliable for this environment, but `pw-auth` succeeded with a direct Local WP-CLI wrapper pointed at the correct socket and site path
- Playwright succeeded through the global npm-root / `NODE_PATH` fallback path, Chromium launched, auth state was written to `temp/playwright/.auth/noelsaw.json`, and post-login `pw-auth doctor` reported `ready`
- confirmed end-to-end on `https://site-uclasacto.local`
- site required installing the dev-login mu-plugin and setting `WP_ENVIRONMENT_TYPE = development` before the one-time login flow would be allowed
- this site emitted a `learndash-certificate-builder` early-translation notice during WP-CLI calls, but `pw-auth login` still succeeded and wrote `temp/playwright/.auth/neochrome_jose.json`
- flaky IDE terminal capture was worked around successfully by using the `aiddtk-tmux` wrapper to run the login flow and inspect the resulting auth artifacts
- minimum Phase 1 stop/check gate is now met on two realistic Local HTTPS environments; a third environment remains optional extra confidence, not a blocker for Phase 2 planning

### Phase 2 — Authenticated DOM/HTML Inspection MVP

Goal: let an agent log into wp-admin or the front end, target a selector, and read text/HTML in a repeatable way.

Suggested deliverables:

- a standard `pw-auth check` wrapper that loads `storageState` when needed and applies consistent browser options
- support for page open, selector existence, text extraction, and `innerHTML` extraction
- structured JSON results saved under `temp/playwright/checks/<run-id>/`
- support for both front-end and wp-admin checks
- screenshots/traces kept optional for later unless they become necessary

#### Exact MVP command/tool spec

- **Primary runner:** `pw-auth check dom --url <url> --selector <selector> --extract exists|text|html [--user <user>] [--auth-state <path>] [--auth-origin <origin>] [--timeout-ms <ms>] [--format json|text] [--output-dir <dir>]`
  - Purpose: open a page, optionally reuse cached auth, and inspect a specific DOM target
  - Required input: `--url`, `--selector`, `--extract`
  - Optional auth input:
    - `--auth-state <path>` to use an explicit state file, or
    - `--user <user>` to resolve the default cached auth file under `temp/playwright/.auth/<user>.json` using the origin inferred from `--url`, or
    - `--auth-origin <origin>` only when auth resolution must differ from the origin inferred from `--url`
  - MVP rule: if auth is required and missing/invalid, return `AUTH_REQUIRED` with remediation instead of inventing a new login flow
  - Browser lifecycle rule for MVP: each command invocation launches a fresh browser/context and closes it before exit
  - Naming decision: Phase 2 uses a `pw-auth check` subcommand so the inspection flow stays visibly tied to auth/session reuse and does not add a new top-level binary in the MVP

- **MVP supported extract modes:**
  - `exists` → return whether the selector matched at least one element
  - `text` → return normalized text content
  - `html` → return `innerHTML`

- **MVP exit codes:**
  - `0` = success
  - `3` = assertion/selector failure
  - `4` = auth required or auth invalid
  - `5` = runtime/navigation failure

- **MVP output contract:**
  - top-level keys: `status`, `url`, `selector`, `extract`, `auth_used`, `value`, `artifacts`, `errors`
  - `status` values: `ok`, `not_found`, `auth_required`, `error`
  - `artifacts.output_dir` defaults to `temp/playwright/checks/<run-id>/`
  - `artifacts.result_json` is always written
  - `artifacts.extract_file` is written for `text` or `html` extracts

- **Exact first-use examples:**
  - front-end widget HTML:
    - `pw-auth check dom --url http://my-site.local/ --selector ".widget-area" --extract html --format json`
  - wp-admin widget/editor area HTML using cached auth:
    - `pw-auth check dom --url http://my-site.local/wp-admin/widgets.php --selector "#widgets-right" --extract html --user admin --format json`
  - existence check without HTML extraction:
    - `pw-auth check dom --url http://my-site.local/ --selector ".widget-area .widget" --extract exists --format json`

**Primary MVP use cases:**

- inspect the HTML contents of a widget area
- verify a wp-admin widget/editor surface loaded and contains expected content
- inspect front-end markup after login or without login

**Pause/review gate after Phase 2:** if this already solves the real project need, review before starting Phases 3–5.

### Phase 3 — MCP Agent Access to Browser Checks

Goal: expose the Phase 1–2 workflow as first-class AI-DDTK tools for VS Code agents.

Suggested initial MCP tool surface:

- `playwright_doctor`
- `playwright_check_dom`

Related notes:

- auth status remains covered by the existing `pw_auth_status` tool plus the doctor check
- `playwright_check_dom` handles all Phase 2 extract modes, including HTML
- `playwright_run_preset` is added later with Phase 4, not in the initial Phase 3 surface

Each tool should return structured results, extracted content where appropriate, and normalized failure reasons.

### Phase 4 — WordPress Presets & Safe Admin Actions

Goal: add narrow, high-value WordPress flows before supporting more open-ended automation.

Suggested presets/actions:

- widget-area inspection for front-end and relevant wp-admin/editor screens
- category list/create/delete/verify flows in wp-admin
- plugin settings page load/health checks
- optional verification through AI-DDTK helpers such as `local-wp` / WP-CLI when useful

#### Preset format direction (draft)

- Initial presets should be **declarative YAML or JSON**, not ad hoc Node.js scripts.
- Proposed location in the target project: `.aiddtk/playwright-presets/<name>.yml` (or `.json`)
- Proposed minimum fields:
  - `name`
  - `kind` (`inspect`, `create`, `delete`, `verify`)
  - `url`
  - `requires_auth`
  - `selector` or `steps`
  - `extract` / `assert`
  - `writes_state` (`true` for create/delete presets)
  - `verify_via` (`ui`, `wp_cli`, or both)
  - `confirm_required` (`true` for destructive actions)

#### Write-operation guardrails

- Phase 4 is the first point where the plan moves from read-only browser checks into **state-changing WordPress actions**.
- Category create/delete presets should require explicit confirmation before execution.
- Where possible, presets should support a dry-run/planned-actions mode before clicking or submitting.
- After a write action, success should be verified through the UI and optionally through WP-CLI when available.
- Destructive actions should record enough metadata for follow-up cleanup or manual undo when possible.

This phase is where "log in and add/remove categories" should become a supported, repeatable workflow.

### Phase 5 — Guarded Custom Flows

Only after Phases 1–4 are proven should AI-DDTK support richer custom Playwright logic.

Possible approaches:

- allowlisted script directory under the target project
- config-driven presets with constrained actions/assertions
- no arbitrary free-form JS passed through MCP

---

## Success Criteria

- A WP developer or agent can reliably tell whether Playwright is actually ready on this machine
- An agent can log into wp-admin and inspect the HTML/text contents of a widget area or similar surface
- VS Code agents can run those checks through AI-DDTK/MCP without inventing one-off shell scripts
- Narrow WordPress admin actions like category create/delete/verify are easier to run safely than hand-rolled browser scripts
- Screenshots and richer artifacts can remain later enhancements without blocking the first useful release

---

## Open Questions

- Which widget surfaces matter most first: classic widgets, block widgets, or Site Editor/widget-like areas?
- Should category presets verify success through UI only, or UI plus WP-CLI verification?
- When should screenshots/traces move from wishlist to default behavior?
- When, if ever, should AI-DDTK add a shared-browser or pooled-context mode for multi-check runs?