---
title: "P1: AI-DDTK MCP Server"
status: planned
author: noelsaw
created: 2026-03-07
updated: 2026-03-07
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
- [Phase 1 — Scaffold & Local-WP Tool](#phase-1--scaffold--local-wp-tool)
- [Phase 2 — WPCC Scan Tools & Resources](#phase-2--wpcc-scan-tools--resources)
- [Phase 3 — pw-auth & Playwright Tools](#phase-3--pw-auth--playwright-tools)
- [Phase 4 — wp-ajax-test & Tmux Tools](#phase-4--wp-ajax-test--tmux-tools)
- [Phase 5 — VS Code Integration](#phase-5--vs-code-integration)
- [Phase 6 — Documentation & Onboarding](#phase-6--documentation--onboarding)
- [Tool Reference](#tool-reference)
- [Resource Reference](#resource-reference)
- [Open Questions](#open-questions)

<!-- /TOC -->

---

## Phased Checklist (High-Level Progress)

> **Note for LLM agents:** Continuously mark items off this checklist as progress is made during implementation. This section is the single source of truth for phase completion status. Update it **immediately** after completing any item — do not batch updates.

- [ ] **Phase 1 — Scaffold & Local-WP Tool** · Effort: Low · Risk: Low
  - [ ] Project scaffold (package.json, tsconfig, MCP SDK wiring)
  - [ ] stdio + SSE transport
  - [ ] Module-per-domain file structure (`src/handlers/<domain>.ts`)
  - [ ] `local_wp_list_sites` tool
  - [ ] `local_wp_select_site` / `local_wp_get_active_site` tools (site context)
  - [ ] `local_wp_test_connectivity` tool
  - [ ] `local_wp_get_site_info` tool
  - [ ] `local_wp_run` tool
  - [ ] Basic error handling & timeout patterns
  - [ ] Smoke tests

- [ ] **Phase 2 — WPCC Scan Tools & Resources** · Effort: Med · Risk: Low
  - [ ] `wpcc_run_scan` tool
  - [ ] `wpcc_list_features` tool
  - [ ] `wpcc://latest-scan` resource
  - [ ] `wpcc://latest-report` resource
  - [ ] `wpcc://scan/{id}` resource
  - [ ] Migrate/replace existing `mcp-server.js` in WPCC subtree

- [ ] **Phase 3 — pw-auth & Playwright Tools** · Effort: Med · Risk: Med
  - [ ] `pw_auth_login` tool
  - [ ] `pw_auth_status` tool
  - [ ] `pw_auth_clear` tool
  - [ ] Auth state resource (`auth://state/{user}`)
  - [ ] Timeout & retry handling for browser automation

- [ ] **Phase 4 — wp-ajax-test & Tmux Tools** · Effort: Low · Risk: Low
  - [ ] `wp_ajax_test` tool
  - [ ] `tmux_start` / `tmux_send` / `tmux_capture` / `tmux_stop` tools
  - [ ] `tmux_list` / `tmux_status` tools

- [ ] **Phase 5 — VS Code Integration** · Effort: Low · Risk: Low
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
- Expose WPCC scan results and Playwright auth state as MCP resources
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
- **Transport:** stdio (default) + SSE (opt-in via `--sse` flag, port 3100).
- **Site context:** Agents call `local_wp_select_site` once; subsequent tools that need a site use the active context automatically (inspired by `wordpress-mcp`'s `select_site` / `get_active_site` pattern). Tools still accept an explicit `site` param to override.
- **Shell-out pattern:** Each tool handler calls the corresponding `bin/` script via `child_process.execFile` with structured argument passing. No `eval`, no shell interpolation.
- **Output parsing:** Tools return JSON when the underlying script supports `--format json`; otherwise return raw text in a `content` block.
- **Timeout:** Default 60s per tool call, configurable. WPCC scans get 300s.
- **Location:** `tools/mcp-server/` (alongside existing embedded tools).

---

## Phase 1 — Scaffold & Local-WP Tool

> Effort: **Low** · Risk: **Low**

Get the MCP server running with the simplest tool first.

### Deliverables

1. **Project scaffold**
   - `tools/mcp-server/package.json` with `@modelcontextprotocol/sdk`, `typescript`
   - `tools/mcp-server/tsconfig.json`
   - `tools/mcp-server/src/index.ts` — server entry point, transport setup, handler registration
   - `tools/mcp-server/src/state.ts` — active site context (in-memory, per-session)
   - `tools/mcp-server/src/handlers/local-wp.ts` — all `local_wp_*` tools
   - `tools/mcp-server/src/utils/exec.ts` — safe shell-out helper (execFile, timeout, error normalization)

2. **`local_wp_list_sites`** tool
   - Scans `~/Local Sites/` for directories containing `app/public/wp-config.php`
   - Returns: `{ sites: [{ name, path, hasWordPress }] }`
   - No shell-out needed — pure filesystem read

3. **`local_wp_select_site` / `local_wp_get_active_site`** tools (borrowed from `wordpress-mcp`)
   - `select_site`: Sets the active site context for the session. Agent calls this once, then subsequent tools use it implicitly.
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
   - General-purpose WP-CLI passthrough for anything the specialized tools don't cover
   - Inputs: `site` (string, optional — uses active site if omitted), `command` (string, required), `args` (string[], optional)
   - Shells out to: `bin/local-wp <site> <command> [args...]`
   - Returns: `{ stdout, stderr, exitCode }`
   - Timeout: 60s default

7. **Smoke tests**
   - `tools/mcp-server/test/local-wp.test.ts`
   - Mock `execFile` to verify argument construction and output parsing
   - Test site context: select → implicit use → explicit override

### Acceptance criteria

- `npx ai-ddtk-mcp` starts and registers tools via stdio
- Claude Desktop can discover and call `local_wp_list_sites`
- `local_wp_select_site` sets context; `local_wp_run` uses it without explicit `site` param
- `local_wp_test_connectivity` returns structured health check
- `local_wp_get_site_info` returns WP version, plugins, theme in one call
- `local_wp_run` correctly passes arguments to `bin/local-wp`

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

2. **`wpcc_list_features`**
   - Shells out to: `bin/wpcc --features`
   - Returns: feature list as structured data

### Resources

3. **`wpcc://latest-scan`** — Latest JSON scan from `tools/wp-code-check/dist/logs/`
4. **`wpcc://latest-report`** — Latest HTML report from `tools/wp-code-check/dist/reports/`
5. **`wpcc://scan/{id}`** — Specific scan by timestamp ID

### Migration

- Deprecate `tools/wp-code-check/dist/bin/mcp-server.js`
- Port its resource logic into the unified server
- Update any Claude Desktop / Cline configs that reference the old server

---

## Phase 3 — pw-auth & Playwright Tools

> Effort: **Med** · Risk: **Med** (browser automation has inherent flakiness)

### Tools

1. **`pw_auth_login`**
   - Inputs: `siteUrl` (string, required), `wpCli` (string, e.g. `"local-wp my-site"`), `user` (string, default "admin"), `redirect` (string), `force` (boolean)
   - Shells out to: `bin/pw-auth login --site-url <url> [--wp-cli "<cmd>"] [--user <user>] [--redirect <path>] [--force]`
   - Timeout: 120s (browser launch + navigation)
   - Returns: `{ authFile, user, siteUrl, expiresAt }`

2. **`pw_auth_status`**
   - Shells out to: `bin/pw-auth status`
   - Returns: cached auth info (users, freshness, file paths)

3. **`pw_auth_clear`**
   - Shells out to: `bin/pw-auth clear`
   - Returns: confirmation

### Resources

4. **`auth://state/{user}`** — Read cached Playwright auth JSON for a given user

### Risk mitigations

- Headless mode only from MCP (no `--headed` flag exposed)
- Retry once on timeout before returning error
- Clear error messages when dev-login-cli.php mu-plugin is missing

---

## Phase 4 — wp-ajax-test & Tmux Tools

> Effort: **Low** · Risk: **Low**

### Tools

1. **`wp_ajax_test`**
   - Inputs: `url` (string), `action` (string), `data` (object), `auth` (string), `method` (string), `nopriv` (boolean), `insecure` (boolean)
   - Shells out to: `bin/wp-ajax-test --url <url> --action <action> --format json [...]`
   - Returns: parsed JSON response

2. **`tmux_start`** — `aiddtk-tmux start --cwd <path>`
3. **`tmux_send`** — `aiddtk-tmux send --command <cmd>`
4. **`tmux_capture`** — `aiddtk-tmux capture --tail <lines>`
5. **`tmux_stop`** — `aiddtk-tmux stop`
6. **`tmux_list`** — `aiddtk-tmux list`
7. **`tmux_status`** — `aiddtk-tmux status`

All tmux tools are thin wrappers with short timeouts (10s).

---

## Phase 5 — VS Code Integration

> Effort: **Low** · Risk: **Low**

Ship config files that make the toolkit immediately usable from VS Code.

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
| `local_wp_run` | `bin/local-wp` | `site?`, `command`, `args` | `{ stdout, stderr, exitCode }` |
| `wpcc_run_scan` | `bin/wpcc` | `paths`, `format`, `verbose` | scan JSON or text |
| `wpcc_list_features` | `bin/wpcc --features` | — | feature list |
| `pw_auth_login` | `bin/pw-auth login` | `siteUrl`, `wpCli`, `user`, `redirect`, `force` | `{ authFile, user, expiresAt }` |
| `pw_auth_status` | `bin/pw-auth status` | — | auth cache info |
| `pw_auth_clear` | `bin/pw-auth clear` | — | confirmation |
| `wp_ajax_test` | `bin/wp-ajax-test` | `url`, `action`, `data`, `auth`, `method`, `nopriv` | JSON response |
| `tmux_start` | `aiddtk-tmux start` | `cwd`, `session` | session info |
| `tmux_send` | `aiddtk-tmux send` | `command`, `session` | confirmation |
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
| `auth://state/{user}` | Playwright auth state for user | `application/json` |

---

## Open Questions

1. **Should tmux tools be optional?** Not all users have tmux installed. Could gate behind a `--enable-tmux` flag.
2. **SSE transport auth?** If exposing over HTTP, should we require a bearer token? Probably yes for anything beyond localhost.
3. **Config file location?** Use `.ai-ddtk.config` for MCP settings or a separate `mcp.config.json`?
4. **Monorepo bin entry?** Should `install.sh` add `ai-ddtk-mcp` to PATH, or is `npx` sufficient?
5. **Existing WPCC MCP server migration timeline?** Deprecate immediately or run both in parallel for one release?
