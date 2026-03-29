# AI-DDTK MCP Server

> Version: 0.7.0

Unified MCP server for AI-DDTK. Exposes LocalWP, WPCC, `pw-auth`, `wp-ajax-test`, tmux, and Query Monitor workflows as typed **Tools**, **Resources**, and **Prompts** — compatible with Claude Code, GitHub Copilot, Cline, Augment Code, Cursor, Claude Desktop, and any MCP-capable client.

## Quick Start

From the AI-DDTK repo root:

```bash
./install.sh setup-mcp
./install.sh status
```

This builds `tools/mcp-server/dist/`, installs Node.js dependencies, and prints client configuration guidance.

## Client Config

| Client | Discovery method | Template |
|--------|-----------------|----------|
| **Claude Code** | Auto-discovers `.mcp.json` in repo root | `.mcp.json` |
| **GitHub Copilot / Cline / Continue** | VS Code extension auto-registers via `mcpServerDefinitionProviders`; or manual `.vscode/mcp.json` | `mcp-configs/vscode.json` |
| **Augment Code** | Manual `~/.augment/settings.json` entry (or run `wire-project`) | See `AGENTS.md` |
| **Cursor** | Manual `~/.cursor/mcp.json` entry (or run `wire-project`) | `mcp-configs/cursor.json` |
| **Claude Desktop** | Manual config file | `mcp-configs/claude-desktop.json` |

Run `wire-project [--client=auto|claude-code|vscode|augment|cursor|all]` to write all applicable config files automatically.

All configs launch the stdio server with:

```bash
node tools/mcp-server/dist/src/index.js
```

## Manual Run

```bash
cd tools/mcp-server
npm run build
npm run mcp
npm run mcp:http
```

- **stdio** is the default for editor integrations.
- **HTTP mode** binds to `127.0.0.1` only and requires the bearer token stored at `~/.ai-ddtk/mcp-token`.

## Tool Catalog

| Area | MCP Tools | Purpose |
|------|-----------|---------|
| LocalWP | `local_wp_list_sites`, `local_wp_select_site`, `local_wp_get_active_site`, `local_wp_test_connectivity`, `local_wp_get_site_info`, `local_wp_run` | Discover/select Local sites and run allowlisted WP-CLI workflows |
| WPCC | `wpcc_run_scan`, `wpcc_list_features` | Run scans and inspect WPCC capabilities |
| Playwright auth | `pw_auth_login`, `pw_auth_status`, `pw_auth_clear` | Create, inspect, and clear cached wp-admin auth state |
| AJAX | `wp_ajax_test` | Test `admin-ajax.php` endpoints with structured inputs |
| tmux | `tmux_start`, `tmux_send`, `tmux_capture`, `tmux_stop`, `tmux_list`, `tmux_status` | Run resilient long-lived commands and inspect output |
| Query Monitor | `qm_profile_page`, `qm_slow_queries`, `qm_duplicate_queries` | Profile pages, find slow queries, detect N+1 patterns |

## Resources

| URI | MIME type | Description |
|-----|-----------|-------------|
| `wpcc://latest-scan` | `application/json` | Most recent WPCC JSON scan artifact |
| `wpcc://latest-report` | `text/html` | Most recent WPCC HTML report |
| `wpcc://scan/{id}` | `application/json` | Specific WPCC scan by timestamp id |
| `auth://status/{user}` | `application/json` | Playwright auth cache metadata by WordPress user (no raw cookies) |

## Prompts

Prompts surface as **slash commands** in VS Code Copilot (`/mcp.ai-ddtk.<name>`) and as selectable prompts in Cline, Claude Desktop, and other MCP clients.

| Prompt | Args | Description |
|--------|------|-------------|
| `preflight` | — | Run a session preflight check across all toolkit components |
| `scan` | `path` | Run a WPCC scan on a plugin/theme path and triage findings |
| `profile-page` | `siteUrl`, `path` | Profile a WordPress page with Query Monitor |
| `triage-scan` | — | Load `wpcc://latest-scan` and triage for false positives |
| `wire-project` | `projectPath?`, `client?` | Wire a project for AI-DDTK MCP integration |

## Sampling

MCP Sampling (`server.createMessage()`) is available in the SDK and allows the server to request LLM calls via the connected client's model subscription. It is not currently used by this server — client support varies and requires explicit user opt-in per the MCP spec. Candidates for future use: on-server WPCC triage summarisation, automated fix suggestions.

## Recommended Usage Pattern

1. List/select a Local site before site-specific commands.
2. Prefer MCP tools over raw shell when the tool already exists.
3. Use tmux tools for long-running scans or flaky terminals.
4. Use `pw_auth_login` before Playwright admin automation.
5. Read WPCC resources after scans instead of reparsing raw files manually.

## Database Queries

For WordPress database queries beyond direct MySQL access, use the external **WP-DB-Toolkit** and its MCP server:

- https://github.com/Hypercart-Dev-Tools/WP-DB-Toolkit

## Troubleshooting

- **Build missing / command fails**: rerun `./install.sh setup-mcp`.
- **HTTP returns 401**: use the token from `~/.ai-ddtk/mcp-token`.
- **No active site context**: call `local_wp_list_sites` then `local_wp_select_site`, or pass `site` explicitly.
- **Playwright auth is stale**: rerun login with `--force`.