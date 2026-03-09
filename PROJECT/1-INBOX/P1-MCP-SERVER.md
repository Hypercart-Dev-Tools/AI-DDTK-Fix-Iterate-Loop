---
title: "P1: AI-DDTK MCP Server"
status: in_progress
author: noelsaw
created: 2026-03-07
updated: 2026-03-09
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
- [Phase 5 — VS Code Integration & SSE Transport](#phase-5--vs-code-integration--sse-transport)
- [Phase 6 — Documentation & Onboarding](#phase-6--documentation--onboarding)
- [Tool Reference](#tool-reference)
- [Resource Reference](#resource-reference)
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

- [ ] **Phase 4 — wp-ajax-test & Tmux Tools** · Effort: Low · Risk: Low–Med
  - [ ] `wp_ajax_test` tool (explicit `site` required)
  - [ ] `tmux_start` / `tmux_capture` / `tmux_stop` tools
  - [ ] `tmux_list` / `tmux_status` tools
  - [ ] `tmux_send` — allowlisted commands only (no arbitrary shell execution)

- [ ] **Phase 5 — VS Code Integration & SSE Transport** · Effort: Low–Med · Risk: Med
  - [ ] SSE transport (localhost-only bind, bearer token auth required)
  - [ ] `.vscode/tasks.json` with common commands
  - [ ] `.vscode/launch.json` for MCP server debugging
  - [ ] `mcp.json` / Claude Desktop config snippet
  - [ ] Cline MCP config snippet

- [ ] **Phase 6 — Documentation & Onboarding** · Effort: Low · Risk: Low
  - [ ] README for MCP server (setup, config, tool catalog)
  - [ ] Update AGENTS.md with MCP tool usage patterns
  - [ ] Update ROADMAP-PERPLEXITY.md — mark #6 complete
  - [ ] Short screencast or GIF demo

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
   - Returns: parsed JSON response

2. **`tmux_start`** — `aiddtk-tmux start --cwd <path>`
3. **`tmux_send`** — **Allowlisted commands only** (see Security Model §1). Only AI-DDTK bin/ commands and safe reads (`cat`, `ls`, `head`, `tail`) are permitted. Arbitrary shell commands are rejected before dispatch.
   - Inputs: `command` (string, required), `session` (string, optional)
   - Validates command prefix against allowlist before calling `aiddtk-tmux send`
4. **`tmux_capture`** — `aiddtk-tmux capture --tail <lines>`
5. **`tmux_stop`** — `aiddtk-tmux stop`
6. **`tmux_list`** — `aiddtk-tmux list`
7. **`tmux_status`** — `aiddtk-tmux status`

All tmux tools are thin wrappers with short timeouts (10s).

---

## Phase 5 — VS Code Integration & SSE Transport

> Effort: **Low–Med** · Risk: **Med** (SSE introduces network attack surface)

Ship config files and SSE transport with mandatory security controls.

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

4. **Demo** — Short screencast or GIF showing: open project → Claude discovers tools → run scan → view results

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

## Open Questions

> Items 2 and 3 from the original list are now resolved in the Security Model section.

1. **Should tmux tools be optional?** Not all users have tmux installed. Could gate behind a `--enable-tmux` flag.
2. **Config file location?** Use `.ai-ddtk.config` for MCP settings or a separate `mcp.config.json`?
3. **Monorepo bin entry?** Should `install.sh` add `ai-ddtk-mcp` to PATH, or is `npx` sufficient?
4. **Existing WPCC MCP server migration timeline?** Deprecate immediately or run both in parallel for one release?
5. **Allowlist extensibility model?** Should users extend the WP-CLI allowlist via config file, env var, or CLI flag? Need to balance flexibility with not accidentally opening RCE.
