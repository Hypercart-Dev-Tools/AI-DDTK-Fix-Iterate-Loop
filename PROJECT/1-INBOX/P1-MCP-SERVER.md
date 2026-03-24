---
title: "P1: AI-DDTK MCP Server"
status: active
author: noelsaw
created: 2026-03-07
updated: 2026-03-22
project: AI-DDTK
category: feature
priority: P1
parent: ROADMAP-PERPLEXITY.md (#6 — VS Code & MCP Integration)
---

<!-- TOC -->

- [Phased Checklist (High-Level Progress)](#phased-checklist-high-level-progress)
- [Overview](#overview)
- [Goals & Non-Goals](#goals--non-goals)
- [Architecture](#architecture)
- [Security Model](#security-model)
- [Phase 1 — Scaffold & Local-WP Tool](#phase-1--scaffold--local-wp-tool)
- [Phase 2 — WPCC Scan Tools & Resources](#phase-2--wpcc-scan-tools--resources)
- [Phase 3 — pw-auth & Playwright Tools](#phase-3--pw-auth--playwright-tools)
- [Phase 4 — wp-ajax-test & Tmux Tools](#phase-4--wp-ajax-test--tmux-tools)
- [Phase 5 — VS Code Integration & Secure HTTP and SSE Transport](#phase-5--vs-code-integration--secure-http-and-sse-transport)
- [Phase 6 — Documentation & Onboarding](#phase-6--documentation--onboarding)
- [Tool Reference](#tool-reference)
- [Resource Reference](#resource-reference)
- [Phase 7 — Query Monitor Frontend Page Profiling](#phase-7--query-monitor-frontend-page-profiling)
- [Open Questions](#open-questions)

<!-- /TOC -->

---

## Phased Checklist (High-Level Progress)

> **Note for LLM agents:** Continuously mark items off this checklist as progress is made during implementation. This section is the single source of truth for phase completion status. Update it **immediately** after completing any item — do not batch updates.

- [x] **Phase 1 — Scaffold & Local-WP Tool** · Effort: Low · Risk: Low
  - [x] Project scaffold (package.json, tsconfig, MCP SDK wiring)
  - [x] stdio transport (SSE deferred to Phase 5 with auth)
  - [x] Module-per-domain file structure (`src/handlers/<domain>.ts`)
  - [x] WP-CLI subcommand allowlist (`src/security/allowlist.ts`)
  - [x] `local_wp_list_sites` tool
  - [x] `local_wp_select_site` / `local_wp_get_active_site` tools (convenience only, not primary)
  - [x] `local_wp_test_connectivity` tool
  - [x] `local_wp_get_site_info` tool
  - [x] `local_wp_run` tool (allowlisted subcommands only)
  - [x] Basic error handling & timeout patterns
  - [x] Smoke tests (including allowlist enforcement)

- [x] **Phase 2 — WPCC Scan Tools & Resources** · Effort: Med · Risk: Low
  - [x] `wpcc_run_scan` tool
  - [x] `wpcc_list_features` tool
  - [x] `wpcc://latest-scan` resource
  - [x] `wpcc://latest-report` resource
  - [x] `wpcc://scan/{id}` resource
  - [x] Migrate/replace existing `mcp-server.js` in WPCC subtree

- [x] **Phase 3 — pw-auth & Playwright Tools** · Effort: Med · Risk: Med
  - [x] `pw_auth_login` tool (structured args, no free-form wpCli string)
  - [x] `pw_auth_status` tool
  - [x] `pw_auth_clear` tool
  - [x] Auth metadata resource (`auth://status/{user}`) — no raw credentials
  - [x] Timeout & retry handling for browser automation

- [x] **Phase 4 — wp-ajax-test & Tmux Tools** · Effort: Low · Risk: Low–Med
  - [x] `wp_ajax_test` tool (explicit `url` required)
  - [x] `tmux_start` / `tmux_capture` / `tmux_stop` tools
  - [x] `tmux_list` / `tmux_status` tools
  - [x] `tmux_send` — allowlisted commands only (no arbitrary shell execution)

- [x] **Phase 5 — VS Code Integration & Secure HTTP and SSE Transport** · Effort: Med · Risk: Med
  - [x] Per-session active-site context/state handling
  - [x] Secure localhost-only HTTP/SSE transport with bearer token auth
  - [x] Repo-tracked `.vscode/tasks.json` with common commands
  - [x] Repo-tracked `.vscode/launch.json` for MCP server debugging
  - [x] `mcp.json` / Claude Desktop config snippet
  - [x] Cline MCP config snippet
  - [x] Installer wiring for MCP setup/config generation
  - [x] Targeted tests + smoke validation
  - [x] Update changelog, version, and project tracking

- [x] **Phase 6 — Documentation & Onboarding** · Effort: Low · Risk: Low
  - [x] README for MCP server (setup, config, tool catalog)
  - [x] Update AGENTS.md with MCP tool usage patterns
  - [x] Update ROADMAP-PERPLEXITY.md — mark #6 complete
  - [x] Add reference to external WP DB Toolkit and it's MCP server that can be used for database queries outside of MySQL server. https://github.com/Hypercart-Dev-Tools/WP-DB-Toolkit

- [ ] **Phase 7 — Query Monitor Frontend Page Profiling** · Effort: Med · Risk: Med
  - [x] Spike: validate QM envelope dispatcher on Local site (2026-03-22)
  - [x] Spike: confirm pw-auth storageState contains `wordpress_logged_in_*` cookies (2026-03-22)
  - [ ] Add `getCookiesForSite(user, domain)` to pw-auth handler (cookie extraction owned by pw-auth, not qm.ts)
  - [ ] Thin mu-plugin: hook `shutdown`, serialize QM collectors to transient, expose REST retrieval endpoint
  - [ ] `qm_profile_page` tool (hit any URL with method/body/header controls, read QM data from transient)
  - [ ] `qm_slow_queries` tool (threshold-filtered query report)
  - [ ] `qm_duplicate_queries` tool (N+1 detection from dupes collector)
  - [ ] Unit tests with mocked responses
  - [ ] Tool registration in index.ts + tool/resource reference update

- [ ] **Phase 7b — Query Monitor REST Route Profiling (envelope mode)** · Effort: Low · Risk: Low
  - [ ] `qm_profile_rest` tool (use `?_envelope=1` for lighter-weight REST-only profiling without mu-plugin)
  - [ ] Unit tests with mocked QM envelope responses

Key Discoveries from Spike:
QM envelope works — ?_envelope=1 on REST routes returns a qm property with all 6 raw collectors (db_queries, cache, http, logger, conditionals, transients)

App passwords don't work — QM's Dispatcher::init() fires at WordPress init hook, before rest_api_init where app passwords authenticate. By the time the user is recognized, QM has already called qm/cease and stopped collecting.

Session cookies work — WordPress logged_in cookie + QM auth cookie authenticate at init time via $_COOKIE, so QM collects data normally.

Frontend URLs are REST-only — _envelope=1 is a REST-layer filter, so frontend pages return HTML. REST-only profiling is the right scope for Phase 7; a mu-plugin companion for frontend profiling can follow later.

The data is rich — Each query includes SQL, timing (seconds), full call stack, and row count. The dupes collector gives N+1 detection for free.

---

## Overview

Build a unified MCP server for AI-DDTK that exposes all core CLI tools (`local-wp`, `wpcc`, `pw-auth`, `wp-ajax-test`, `aiddtk-tmux`) as MCP tools and resources. This lets AI agents (Claude Desktop, Cline, Claude Code, etc.) drive the full toolkit without knowing shell syntax.

### Why roll our own (vs. `jpollock/wordpress-mcp`)

| Concern | wordpress-mcp | AI-DDTK MCP |
|---------|--------------|--------------|
| Connection | REST API over HTTP | Local shell (WP-CLI, Playwright, bash) |
| Focus | Content/admin CRUD | Code quality, testing, fix-iterate |
| Auth model | Application Passwords | `pw-auth` + Local site shell access |
| Overlap with AI-DDTK | None | 1:1 — thin wrappers around existing bin/ scripts |
| Maturity | 7 stars, dormant since May 2025 | We control the roadmap |

The two projects solve different problems. `wordpress-mcp` is a content management bridge; ours is a developer tooling bridge.

---

## Goals & Non-Goals

### Goals

- Expose every `bin/` tool as an MCP tool with typed inputs and structured outputs
- Expose WPCC scan results and Playwright auth metadata/status as MCP resources
- Support stdio transport (Claude Desktop, Cline) and SSE transport (remote/VS Code)
- Keep it thin — each tool handler shells out to the existing script, no reimplementation
- Structured JSON output where possible (fall back to text for human-readable output)

### Non-Goals

- Reimplementing tool logic in TypeScript (wrappers only)
- WordPress REST API integration (that's a different project)
- Multi-site remote management
- Plugin/theme marketplace features

---

## Architecture

```
┌─────────────────────────────────────────────┐
│              MCP Client                      │
│  (Claude Desktop / Cline / Claude Code)      │
└──────────────┬──────────────────────────────┘
               │ stdio or SSE
┌──────────────▼──────────────────────────────┐
│         ai-ddtk-mcp-server                   │
│  ┌──────────┬──────────┬──────────┬────────┐ │
│  │ local-wp │  wpcc    │ pw-auth  │ ajax   │ │
│  │ handler  │ handler  │ handler  │ handler│ │
│  └────┬─────┴────┬─────┴────┬─────┴───┬────┘ │
│       │          │          │         │      │
│  ┌────▼─────┬────▼─────┬────▼────┬────▼────┐ │
│  │ bin/     │ bin/     │ bin/   │ bin/    │ │
│  │ local-wp │ wpcc     │pw-auth │wp-ajax  │ │
│  └──────────┴──────────┴────────┴─────────┘ │
└─────────────────────────────────────────────┘
```

### File structure (module-per-domain)

Borrowed from `wordpress-mcp`'s module pattern, adapted with namespace prefixes for clarity:

```
tools/mcp-server/
├── src/
│   ├── index.ts              # Server entry, transport setup, handler registration
│   ├── state.ts              # Active site context (select/get)
│   ├── handlers/
│   │   ├── local-wp.ts       # local_wp_* tools
│   │   ├── wpcc.ts           # wpcc_* tools
│   │   ├── pw-auth.ts        # pw_auth_* tools
│   │   ├── wp-ajax-test.ts   # wp_ajax_test tool
│   │   └── tmux.ts           # tmux_* tools
│   ├── resources/
│   │   ├── wpcc.ts           # wpcc:// resources
│   │   └── auth.ts           # auth:// resources
│   ├── security/
│   │   └── allowlist.ts      # WP-CLI + tmux command allowlists
│   └── utils/
│       └── exec.ts           # Safe shell-out helper
├── test/
│   └── *.test.ts
├── package.json
└── tsconfig.json
```

Each handler file owns tool registration + execution for its domain. The server entry point imports and registers all handlers.

### Key decisions

- **Language:** Node.js (TypeScript). Matches existing JS tooling (`wp-ajax-test`, WPCC MCP server). Uses `@modelcontextprotocol/sdk`.
- **Transport:** stdio only in Phase 1. SSE deferred to Phase 5 with mandatory localhost bind + bearer token auth (see Security Model).
- **Site context:** `local_wp_select_site` is a **convenience helper**, not the primary execution model. All stateful and destructive tools **require explicit `site`**. Active site is used only for read-only tools when `site` is omitted. Every response echoes the resolved site name so wrong-site execution is immediately visible.
- **Shell-out pattern:** Each tool handler calls the corresponding `bin/` script via `child_process.execFile` with structured argument passing. No `eval`, no shell interpolation. Passthrough tools (`local_wp_run`, `tmux_send`) enforce a subcommand allowlist — not arbitrary execution.
- **Output parsing:** Tools return JSON when the underlying script supports `--format json`; otherwise return raw text in a `content` block.
- **Timeout:** Default 60s per tool call, configurable. WPCC scans get 300s.
- **Location:** `tools/mcp-server/` (alongside existing embedded tools).

---

## Security Model

> This section addresses three design-level risks identified during review. All three are **must-fix before implementation**, not open questions.

### 1. No accidental RCE surface (Red Flag #1)

The combination of free-form command tools (`local_wp_run`, `tmux_send`) with network transport (SSE) creates a local command-execution bridge. Left unchecked, this is effectively a remote shell.

**Mitigations — all mandatory:**

- **SSE is localhost-only.** Bind to `127.0.0.1`, never `0.0.0.0`. Enforced at transport init, not configurable.
- **SSE requires bearer token auth.** Token generated on first run, stored in `~/.ai-ddtk/mcp-token`. No token = no connection.
- **SSE deferred to Phase 5.** Phase 1–4 are stdio-only, which is inherently local and single-client.
- **`local_wp_run` uses a subcommand allowlist.** Only safe, read-heavy WP-CLI subcommands are permitted by default:
  ```
  ALLOWED: cli info, core version, plugin list, theme list, option get,
           post list, user list, db query (SELECT only), cache flush,
           cron event list, rewrite flush, transient list
  BLOCKED: eval, shell, db export, db import, db reset, db drop,
           config set, config delete, core update, plugin install,
           plugin delete, theme install, theme delete, user create,
           user delete, package install
  ```
  Allowlist lives in `src/security/allowlist.ts`. Can be extended via config, but defaults are restrictive.
- **`tmux_send` uses a command allowlist.** Only AI-DDTK bin/ commands and safe reads are allowed — no arbitrary shell dispatch:
  ```
  ALLOWED: wpcc, pw-auth, local-wp, wp-ajax-test, cat, ls, head, tail
  BLOCKED: rm, sudo, curl, wget, eval, sh, bash, node, python, pip, npm
  ```
- **`pw_auth_login` uses structured args, not a free-form `wpCli` string.** Instead of accepting `wpCli: "local-wp my-site"`, accept `site: "my-site"` and construct the `--wp-cli` flag internally. The agent never controls the command shape.

### 2. No credential exposure via MCP resources (Red Flag #2)

The `auth://state/{user}` resource as originally designed would expose raw Playwright `storageState` JSON containing session cookies, auth tokens, and reusable admin login state. This directly conflicts with the repo's rules about sensitive data in `temp/`.

**Mitigations — all mandatory:**

- **`auth://status/{user}` replaces `auth://state/{user}`.** Returns metadata only:
  ```json
  {
    "user": "admin",
    "exists": true,
    "lastUpdated": "2026-03-07T10:30:00Z",
    "age": "2h 15m",
    "fresh": true,
    "validationStatus": "ok",
    "filePath": "temp/playwright/.auth/admin.json"
  }
  ```
- **Raw storageState is never exposed over MCP.** If ever needed for debugging, gate behind `--unsafe-expose-auth` flag and redact cookie values by default.
- **`pw_auth_login` returns auth file path and metadata, never file contents.**

### 3. Explicit site on all destructive/stateful tools (Red Flag #3)

In-memory active-site state is convenient but dangerous. With SSE or reconnecting clients, "per-session" is hard to define. Wrong-site execution on destructive tooling is unacceptable.

**Mitigations — all mandatory:**

- **Explicit `site` required on all stateful/destructive tools:**
  - `local_wp_run` — always requires `site`
  - `pw_auth_login` — always requires `site` (via `siteUrl`)
  - `wp_ajax_test` — always requires `site` (via `url`)
  - `pw_auth_clear` — clears for explicit user only, no "clear all" from MCP
- **Active site context is convenience-only for read-only tools:**
  - `local_wp_test_connectivity` — can fall back to active site
  - `local_wp_get_site_info` — can fall back to active site
- **Every response echoes the resolved site.** Agents (and humans reviewing transcripts) always see which site was acted upon.
- **If SSE is enabled (Phase 5+), active site is scoped to client session ID.** No shared mutable state across clients.

---

## Phase 1 — Scaffold & Local-WP Tool

> Effort: **Low** · Risk: **Low**

Get the MCP server running with the simplest tool first.

> Status update (2026-03-08): Implemented in `tools/mcp-server/` and validated with `npm test`.

### Deliverables

1. **Project scaffold**
   - `tools/mcp-server/package.json` with `@modelcontextprotocol/sdk`, `typescript`
   - `tools/mcp-server/tsconfig.json`
   - `tools/mcp-server/src/index.ts` — server entry point, stdio transport, handler registration
   - `tools/mcp-server/src/state.ts` — active site context (in-memory, convenience-only for read tools)
   - `tools/mcp-server/src/security/allowlist.ts` — WP-CLI subcommand allowlist (see Security Model)
   - `tools/mcp-server/src/handlers/local-wp.ts` — all `local_wp_*` tools
   - `tools/mcp-server/src/utils/exec.ts` — safe shell-out helper (execFile, timeout, error normalization)

2. **`local_wp_list_sites`** tool
   - Scans `~/Local Sites/` for directories containing `app/public/wp-config.php`
   - Returns: `{ sites: [{ name, path, hasWordPress }] }`
   - No shell-out needed — pure filesystem read

3. **`local_wp_select_site` / `local_wp_get_active_site`** tools (borrowed from `wordpress-mcp`)
   - **Convenience only.** Active site is used as a fallback for read-only tools (`test_connectivity`, `get_site_info`). Stateful/destructive tools always require explicit `site`.
   - `select_site`: Sets the active site context for the session.
     - Inputs: `site` (string, required)
     - Validates site exists in `~/Local Sites/` before accepting
     - Returns: `{ activeSite, path }`
   - `get_active_site`: Returns the currently selected site (or null if none set).
     - Returns: `{ activeSite, path } | null`

4. **`local_wp_test_connectivity`** tool (borrowed from `wordpress-mcp`)
   - Preflight check before running scans or auth
   - Validates: site directory exists, `wp-config.php` present, MySQL socket alive, WP responds to `wp cli info`
   - Inputs: `site` (string, optional — uses active site if omitted)
   - Shells out to: `bin/local-wp <site> cli info`
   - Returns: `{ site, status: "ok" | "error", checks: { dir, wpConfig, mysql, wpCli } }`

5. **`local_wp_get_site_info`** tool (borrowed from `wordpress-mcp`)
   - Rich site summary in one call — gives agents context before deciding what to run
   - Shells out to: `bin/local-wp <site> cli info` + `bin/local-wp <site> core version` + `bin/local-wp <site> theme list --format=json` + `bin/local-wp <site> plugin list --format=json --fields=name,status,version`
   - Inputs: `site` (string, optional — uses active site if omitted)
   - Returns: `{ site, wpVersion, phpVersion, activeTheme, plugins: [{ name, status, version }], siteUrl }`

6. **`local_wp_run`** tool
   - WP-CLI passthrough for commands not covered by specialized tools
   - **Requires explicit `site`** — does not fall back to active site (see Security Model §3)
   - **Subcommand allowlist enforced** — rejects commands not in `allowlist.ts` (see Security Model §1)
   - Inputs: `site` (string, **required**), `command` (string, required), `args` (string[], optional)
   - Shells out to: `bin/local-wp <site> <command> [args...]`
   - Returns: `{ site, stdout, stderr, exitCode }` — always echoes resolved site
   - Timeout: 60s default

7. **Smoke tests**
   - `tools/mcp-server/test/local-wp.test.ts`
   - Mock `execFile` to verify argument construction and output parsing
   - Test site context: select → read-only fallback works, destructive tools reject missing site
   - Test allowlist: blocked subcommands are rejected before shell-out
   - Test response shape: every response includes resolved `site` field

### Acceptance criteria

- `npx ai-ddtk-mcp` starts and registers tools via stdio
- Claude Desktop can discover and call `local_wp_list_sites`
- `local_wp_select_site` sets context; read-only tools use it, `local_wp_run` rejects without explicit `site`
- `local_wp_run` rejects disallowed subcommands (e.g. `eval`, `db drop`)
- `local_wp_test_connectivity` returns structured health check
- `local_wp_get_site_info` returns WP version, plugins, theme in one call
- All tool responses include the resolved `site` name
- Targeted package validation passes via `npm test` in `tools/mcp-server/`

---

## Phase 2 — WPCC Scan Tools & Resources

> Effort: **Med** · Risk: **Low**

Expose WPCC scanning and replace the existing standalone `mcp-server.js`.

### Tools

1. **`wpcc_run_scan`**
   - Inputs: `paths` (string, required), `format` ("json" | "text", default "json"), `verbose` (boolean)
   - Shells out to: `bin/wpcc --paths <paths> [--format json] [--verbose]`
   - Timeout: 300s (scans can be slow on large repos)
   - Returns: parsed JSON scan results or raw text
   - Status: ✅ Initial implementation complete in unified `tools/mcp-server/`; JSON mode reads the authoritative `dist/logs/*.json` artifact instead of mixed stdout

2. **`wpcc_list_features`**
   - Shells out to: `bin/wpcc --features`
   - Returns: feature list as structured data
   - Status: ✅ Initial implementation complete in unified `tools/mcp-server/`

### Resources

3. **`wpcc://latest-scan`** — Latest JSON scan from `tools/wp-code-check/dist/logs/`
   - Status: ✅ Implemented in unified `tools/mcp-server/`
4. **`wpcc://latest-report`** — Latest HTML report from `tools/wp-code-check/dist/reports/`
   - Status: ✅ Implemented in unified `tools/mcp-server/`
5. **`wpcc://scan/{id}`** — Specific scan by timestamp ID
   - Status: ✅ Implemented with templated MCP resource listing and read support

### Migration

- ✅ Deprecated `tools/wp-code-check/dist/bin/mcp-server.js` into a compatibility shim that forwards to the unified server
- ✅ Ported the WPCC resource logic into the unified server
- ✅ Claude Desktop / Cline docs now point to `tools/mcp-server/dist/src/index.js`

---

## Phase 3 — pw-auth & Playwright Tools

> Effort: **Med** · Risk: **Med** (browser automation has inherent flakiness)

> Status update (2026-03-09): Implemented in `tools/mcp-server/` with a dedicated `pw-auth` handler, explicit-user-only clear semantics, metadata-only auth resources, targeted `npm test` coverage, and a follow-up contract clarification pass that renamed login freshness output to `cacheFreshUntil`, reduced missing-user resource disclosure, and documented `users[]` as authoritative over raw status text.

### Tools

1. **`pw_auth_login`**
   - Inputs: `siteUrl` (string, required), `site` (string, required — Local site name), `user` (string, default "admin"), `redirect` (string), `force` (boolean)
   - **No free-form `wpCli` string.** The handler constructs `--wp-cli "local-wp <site>"` internally from the `site` param. The agent never controls the command shape (see Security Model §1).
   - Shells out to: `bin/pw-auth login --site-url <url> --wp-cli "local-wp <site>" [--user <user>] [--redirect <path>] [--force]`
   - Timeout: 120s (browser launch + navigation)
   - Returns: `{ site, authFile, user, siteUrl, cacheFreshUntil }` — echoes resolved site
   - `cacheFreshUntil` is derived from the auth file mtime plus the default cache window; it is **not** a guaranteed WordPress session expiry

2. **`pw_auth_status`**
   - Shells out to: `bin/pw-auth status`
   - Returns: cached auth info (users, freshness, file paths)
   - `users[]` is authoritative structured metadata; `rawText` is informational passthrough/debug output only

3. **`pw_auth_clear`**
   - Deletes only the explicit user's cached auth file under `temp/playwright/.auth/`
   - Returns: `{ user, filePath, existed, cleared }`

### Resources

4. **`auth://status/{user}`** — Auth metadata only (see Security Model §2)
   - Returns: `{ user, exists, lastUpdated, age, fresh, validationStatus, filePath }`
   - Missing users return `validationStatus: "missing"`, but omit synthesized file paths to reduce username-probing disclosure
   - **Never exposes raw storageState**, cookies, or tokens
   - Raw state available only via `--unsafe-expose-auth` debug flag (redacts cookie values by default)

### Risk mitigations

- Headless mode only from MCP (no `--headed` flag exposed)
- Retry once on timeout before returning error
- Clear error messages when dev-login-cli.php mu-plugin is missing
- `pw_auth_clear` requires explicit `user` param — no "clear all" from MCP

---

## Phase 4 — wp-ajax-test & Tmux Tools

> Effort: **Low** · Risk: **Low**

### Tools

1. **`wp_ajax_test`**
   - Inputs: `url` (string, **required**), `action` (string, **required**), `data` (object), `auth` (string), `method` (string), `nopriv` (boolean), `insecure` (boolean)
   - **Explicit `url` required** — does not infer from active site (see Security Model §3)
   - Shells out to: `bin/wp-ajax-test --url <url> --action <action> --format json [...]`
   - Returns: structured parsed success/error metadata plus raw stdout/stderr passthrough

2. **`tmux_start`** — `aiddtk-tmux start --cwd <path>`
3. **`tmux_send`** — **Allowlisted commands only** (see Security Model §1). After the pre-merge hardening pass, MCP only permits validated repo-relative `wpcc` invocations (for example `wpcc --features` or `wpcc --paths tools/mcp-server --format json`). Direct file reads should use `tmux_capture`, and LocalWP / pw-auth / AJAX flows should use their dedicated MCP tools.
   - Inputs: `command` (string, required), `session` (string, optional)
   - Validates command prefix against allowlist before calling `aiddtk-tmux send`
4. **`tmux_capture`** — `aiddtk-tmux capture --tail <lines>`
5. **`tmux_stop`** — `aiddtk-tmux stop`
6. **`tmux_list`** — `aiddtk-tmux list`
7. **`tmux_status`** — `aiddtk-tmux status`

All tmux tools are thin wrappers with short timeouts (10s).

Phase 4 is now implemented in `tools/mcp-server/src/handlers/wp-ajax-test.ts` and `tools/mcp-server/src/handlers/tmux.ts`, with `tmux_send` prefix validation in `src/security/allowlist.ts`.

---

## Phase 5 — VS Code Integration & Secure HTTP and SSE Transport

> Effort: **Med** · Risk: **Med** (SSE introduces network attack surface)

Ship repo-tracked integration files plus secure localhost-only HTTP/SSE transport with mandatory security controls.

> Status update (2026-03-09): Phase 5 is **complete**. Implemented secure localhost-only HTTP transport via `StreamableHTTPServerTransport` with bearer token auth (`~/.ai-ddtk/mcp-token`), per-session `SessionStore` for isolated active-site context, repo-tracked `.vscode/tasks.json` and `.vscode/launch.json`, `.mcp.json` for Claude Code auto-discovery, reference configs for Claude Desktop and Cline in `tools/mcp-server/mcp-configs/`, `install.sh setup-mcp` command, and 7 new regression tests in `test/phase5.test.ts`. MCP server version bumped to `0.6.0`, toolkit version to `1.0.26`.

### SSE Transport (deferred from Phase 1)

- **Bind to `127.0.0.1` only** — never `0.0.0.0`, not configurable
- **Bearer token required** — generated on first run, stored in `~/.ai-ddtk/mcp-token`
- **Client session ID tracking** — active site state scoped per session, no cross-client contamination
- Port 3100 (configurable)

### Deliverables

1. **`.vscode/tasks.json`**
   ```json
   {
     "tasks": [
       { "label": "WPCC: Run Scan", "type": "shell", "command": "wpcc --paths ${workspaceFolder} --format json" },
       { "label": "pw-auth: Login", "type": "shell", "command": "pw-auth login --site-url ${input:siteUrl} --wp-cli 'local-wp ${input:siteName}'" },
       { "label": "AJAX Test", "type": "shell", "command": "wp-ajax-test --url ${input:ajaxUrl} --action ${input:ajaxAction} --format json" }
     ]
   }
   ```

2. **`.vscode/launch.json`** — Debug config for the MCP server itself
   - Root `.gitignore` currently ignores `.vscode/`; Phase 5 must explicitly decide and implement how these files are tracked in-repo.

3. **MCP client configs**
   - `mcp.json` for Claude Code
   - Claude Desktop `claude_desktop_config.json` snippet
   - Cline MCP settings snippet

4. **`install.sh` update** — Add `setup-mcp` command to wire MCP server into common clients

---

## Phase 6 — Documentation & Onboarding

> Effort: **Low** · Risk: **Low**

### Deliverables

1. **`tools/mcp-server/README.md`**
   - Quick start (install, configure, verify)
   - Full tool catalog with input/output schemas
   - Resource catalog
   - Troubleshooting

2. **AGENTS.md update** — Add MCP tool usage patterns, example prompts, and failure-mode guidance

3. **ROADMAP-PERPLEXITY.md update** — Mark item #6 as complete

4. **Optional follow-up demo** — Short screencast or GIF showing: open project → Claude discovers tools → run scan → view results

> Status update (2026-03-09): Phase 6 is **complete**. Added concise MCP onboarding in `tools/mcp-server/README.md`, root `README.md`, and `AGENTS.md`; marked roadmap item #6 complete; and added a WP-DB-Toolkit MCP reference for database-query workflows outside direct MySQL access. MCP server version bumped to `0.6.1`, toolkit version to `1.0.27`.

---

## Tool Reference

| Tool | Wraps | Inputs | Output |
|------|-------|--------|--------|
| `local_wp_list_sites` | filesystem scan | — | `{ sites: Site[] }` |
| `local_wp_select_site` | in-memory state | `site` | `{ activeSite, path }` |
| `local_wp_get_active_site` | in-memory state | — | `{ activeSite, path } \| null` |
| `local_wp_test_connectivity` | `bin/local-wp` + fs | `site?` | `{ status, checks }` |
| `local_wp_get_site_info` | `bin/local-wp` (multiple) | `site?` | `{ wpVersion, phpVersion, activeTheme, plugins, siteUrl }` |
| `local_wp_run` | `bin/local-wp` | `site` (required), `command` (allowlisted), `args` | `{ site, stdout, stderr, exitCode }` |
| `wpcc_run_scan` | `bin/wpcc` | `paths`, `format`, `verbose` | scan JSON or text |
| `wpcc_list_features` | `bin/wpcc --features` | — | feature list |
| `pw_auth_login` | `bin/pw-auth login` | `siteUrl`, `site` (required), `user`, `redirect`, `force` | `{ site, authFile, user, cacheFreshUntil }` |
| `pw_auth_status` | `bin/pw-auth status` | — | auth cache info |
| `pw_auth_clear` | handler-scoped file delete | `user` (required) | `{ user, filePath, existed, cleared }` |
| `wp_ajax_test` | `bin/wp-ajax-test` | `url`, `action`, `data`, `auth`, `method`, `nopriv` | JSON response |
| `tmux_start` | `aiddtk-tmux start` | `cwd`, `session` | session info |
| `tmux_send` | `aiddtk-tmux send` | `command` (allowlisted), `session` | confirmation |
| `tmux_capture` | `aiddtk-tmux capture` | `tail`, `session` | captured output |
| `tmux_stop` | `aiddtk-tmux stop` | `session` | confirmation |
| `tmux_list` | `aiddtk-tmux list` | — | session list |
| `tmux_status` | `aiddtk-tmux status` | `session` | session info |

## Resource Reference

| URI | Description | MIME |
|-----|-------------|------|
| `wpcc://latest-scan` | Most recent WPCC scan (JSON) | `application/json` |
| `wpcc://latest-report` | Most recent WPCC report (HTML) | `text/html` |
| `wpcc://scan/{id}` | Specific scan by timestamp | `application/json` |
| `auth://status/{user}` | Auth metadata only (no credentials) | `application/json` |

---

## Phase 7 — Query Monitor Frontend Page Profiling

> Effort: **Med** · Risk: **Med** · Status: **Spike complete, not started**

Expose Query Monitor profiling data through the existing MCP server, enabling agents to profile any WordPress page (frontend or admin) and query: "why is the WooCommerce checkout taking so long after payment submission?"

### Spike Findings (2026-03-22)

Validated on a Local test site running QM 3.20.4 and WordPress 6.9.4.

#### Finding 1: QM has no REST API — use the envelope dispatcher instead

QM does not register `/wp-json/query-monitor/v1/` endpoints. Instead, it injects a `qm` property into REST envelope responses when `?_envelope=1` is appended to any `/wp-json/` route. This is actually **better** than a standalone API — you get QM profiling data for the request you're making in a single HTTP call.

**Confirmed working:**
```
GET /?rest_route=/wp/v2/posts&per_page=5&_envelope=1
→ { body: [...], status: 200, headers: {...}, qm: { db_queries, cache, http, ... } }
```

#### Finding 2: Only 6 of 27 collectors expose raw JSON

The envelope dispatcher loads outputters from `output/raw/`. Only these 6 collectors are available:

| Collector | Data | Value |
|-----------|------|-------|
| `db_queries` | All SQL queries with timing, stack traces, duplicate detection | **High** |
| `cache` | Object cache hit/miss ratios | **High** |
| `http` | External HTTP API requests with timing | **High** |
| `logger` | Logged messages (`error_log`, etc.) | Medium |
| `conditionals` | WordPress conditional tag results | Low |
| `transients` | Transients usage | Medium |

The top 3 (db_queries, cache, http) cover the most valuable profiling use cases.

#### Finding 3: `db_queries` structure is rich and well-typed

```json
{
  "total": 49,
  "time": 0.0032,
  "queries": [
    {
      "i": 1,
      "sql": "SELECT option_name, option_value FROM wp_options WHERE autoload IN (...)",
      "time": 0.0004,
      "stack": ["wp_load_alloptions()", "is_blog_installed()", "wp_not_installed()"],
      "result": 196
    }
  ],
  "dupes": { ... }
}
```

Fields per query: `i` (index), `sql`, `time` (seconds), `stack` (call trace array), `result` (row count or error).

#### Finding 4: Application passwords DO NOT work — session cookies required

**Root cause:** QM's `Dispatcher::init()` runs at WordPress's `init` hook, which fires **before** `rest_api_init`. Application passwords authenticate at `rest_api_init`, so `user_can_view()` returns false at init time and QM fires `qm/cease`, stopping all data collection for the entire request.

**What works:** WordPress session cookies (`wordpress_logged_in_*`) + QM auth cookie (`wp-query_monitor_*`). These are validated at `init` time via `$_COOKIE` and `wp_validate_auth_cookie()`.

**Implication:** The handler must obtain valid WordPress session cookies. pw-auth's storageState files may contain these cookies (needs verification), or a thin mu-plugin can generate them on demand.

#### Finding 5: `_envelope=1` only works on REST routes, not frontend URLs

Frontend URLs (`/`, `/product/some-slug/`) return HTML with QM's full HTML debug panel embedded (~937KB). The envelope dispatcher hooks into `rest_envelope_response`, which is a REST-layer-only filter.

**Implication for frontend profiling:** Two options:

- **Option A (REST-only):** Profile REST endpoints like `/wp/v2/posts?per_page=10` — captures the same core queries (WP_Query, options, cron) but misses theme template queries and frontend-specific hooks. Good enough for API-layer profiling.
- **Option B (mu-plugin companion):** A thin mu-plugin (~50 lines) that hooks `shutdown`, serializes QM collector data to a transient, and exposes a REST endpoint to retrieve it. Enables true frontend page profiling. More stable long-term than parsing HTML output.

### Architecture Decision

**Phase 7 is frontend page profiling via mu-plugin companion.** This is the primary use case — profiling real page loads including checkout flows, admin pages, and WooCommerce operations. Phase 7b adds lighter-weight REST-only profiling via `?_envelope=1` (no mu-plugin required) as a convenience for API-layer analysis.

The mu-plugin approach:
1. Hooks `shutdown` to capture QM collector data after the full page lifecycle completes
2. Serializes the 6 raw JSON collectors to a transient keyed by a request nonce
3. Exposes a REST endpoint (`/ai-ddtk-qm/v1/profile/{nonce}`) to retrieve the data
4. The MCP handler hits the target page with cookies, then reads the profile data via REST

### Auth Strategy

**Spike confirmed:** pw-auth storageState files contain `wordpress_logged_in_*` cookies (verified 2026-03-22). The QM auth cookie (`wp-query_monitor_*`) uses the same `COOKIEHASH` suffix and accepts the `logged_in` cookie value.

**Cookie extraction is owned by pw-auth, not qm.ts.** The pw-auth handler will expose a new method:

```typescript
getCookiesForSite(user: string, domain: string): Promise<{ name: string; value: string }[]>
```

This keeps storageState parsing inside pw-auth's domain boundary. The QM handler calls this method and constructs the QM auth cookie from the returned `logged_in` cookie.

Flow:
1. QM handler calls `pwAuthHandlers.getCookiesForSite(user, siteDomain)` to get WordPress session cookies
2. Finds the `wordpress_logged_in_*` cookie, derives the QM cookie name by replacing the prefix
3. Passes `wordpress_logged_in_*` + `wp-query_monitor_*` cookies in the REST request
4. If no fresh cookies exist, returns an error directing the agent to run `pw_auth_login` first

### Proposed Tools

1. **`qm_profile_page`**
   - Profile any WordPress URL (frontend, admin, or checkout flow) with QM data collection
   - Inputs:
   - `siteUrl` (string, required) — e.g. `https://local-test-site.local`
     - `path` (string, required) — e.g. `/checkout/`, `/wp-admin/edit.php`, `/product/hoodie/`
     - `method` (string, default "GET") — HTTP method (GET, POST)
     - `body` (object, optional) — form data or JSON body for POST requests
     - `headers` (object, optional) — additional request headers
     - `user` (string, default "admin")
   - Returns: `{ site, path, method, statusCode, overview: { time, memory }, db_queries: { total, time, queries, dupes }, cache, http, logger, transients, conditionals }`
   - Auth: Uses pw-auth session cookies + QM cookie via `getCookiesForSite()`
   - Flow: hits page with cookies + profile nonce header → mu-plugin captures QM data to transient → handler reads profile via REST

2. **`qm_slow_queries`**
   - Convenience tool: profile a page and filter to queries above a threshold
   - Inputs: `siteUrl`, `path`, `method`, `body`, `threshold_ms` (number, default 50), `user`
   - Returns: `{ site, path, total_queries, slow_queries: [...], total_time }`

3. **`qm_duplicate_queries`**
   - Convenience tool: profile and return only duplicate queries (N+1 detection)
   - Inputs: `siteUrl`, `path`, `method`, `body`, `user`
   - Returns: `{ site, path, duplicates: [{ sql, count, total_time, callers }] }`

### Deliverables

1. `mu-plugins/ai-ddtk-qm-bridge.php` — Thin mu-plugin (~80 lines): capture QM data at shutdown, store in transient, expose REST retrieval endpoint
2. `tools/mcp-server/src/handlers/pw-auth.ts` — Add `getCookiesForSite(user, domain)` method (~30-40 lines)
3. `tools/mcp-server/src/handlers/qm.ts` — QM handler (~250-300 lines, calls pw-auth for cookies, hits page, reads profile via REST)
4. `tools/mcp-server/test/qm.test.ts` — Unit tests with mocked responses
5. `tools/mcp-server/src/index.ts` — Register 3 new tools (~60 lines)
6. Update tool reference table and changelog

### Risks & Mitigations

| Risk | Level | Mitigation |
|------|-------|------------|
| mu-plugin must be installed on target site | Medium | Auto-detect via REST endpoint probe; clear error message if missing |
| QM collector data format is not a stable API | Medium | Pin QM version in docs, add integration test that validates structure |
| pw-auth storageState cookies may be stale | Low | Check cookie expiry; direct agent to `pw_auth_login` if stale |
| QM data collection stopped by `qm/cease` race | Low | Session cookies authenticate at `init` time, avoiding the app-password timing issue |
| Transient storage size for large profiles | Low | Cap serialized data size; exclude low-value collectors if oversized |

### Acceptance Criteria

- mu-plugin installed on target site captures QM data for any page load (frontend, admin, POST)
- `qm_profile_page` returns structured QM data (db_queries, cache, http) for a frontend page on a Local site
- `qm_profile_page` supports GET and POST with optional body and headers
- `qm_slow_queries` correctly filters queries by threshold
- `qm_duplicate_queries` identifies N+1 patterns from the `dupes` collector
- Cookie extraction is handled by pw-auth's `getCookiesForSite()`, not by qm.ts directly
- All tools require auth and fail cleanly when pw-auth state is missing or stale
- `npm test` passes with mocked responses

---

## Open Questions

> Items 2 and 3 from the original list are now resolved in the Security Model section.

1. **Should tmux tools be optional?** Not all users have tmux installed. Could gate behind a `--enable-tmux` flag.
2. **Config file location?** Use `.ai-ddtk.config` for MCP settings or a separate `mcp.config.json`?
3. **Monorepo bin entry?** Should `install.sh` add `ai-ddtk-mcp` to PATH, or is `npx` sufficient?
4. **Existing WPCC MCP server migration timeline?** Deprecate immediately or run both in parallel for one release?
5. **Allowlist extensibility model?** Should users extend the WP-CLI allowlist via config file, env var, or CLI flag? Need to balance flexibility with not accidentally opening RCE.
