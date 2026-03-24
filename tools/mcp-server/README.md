# AI-DDTK MCP Server

> Version: 0.6.3

Unified MCP server for AI-DDTK. It exposes LocalWP, WPCC, `pw-auth`, `wp-ajax-test`, and tmux workflows through one MCP endpoint for Claude Code, Claude Desktop, Cline, and other MCP-compatible clients.

## Quick Start

From the AI-DDTK repo root:

```bash
./install.sh setup-mcp
./install.sh status
```

This builds `tools/mcp-server/dist/`, installs Node.js dependencies, and prints client configuration guidance.

## Client Config

- **Claude Code**: auto-discovers `.mcp.json` in this repo.
- **Claude Desktop**: copy `tools/mcp-server/mcp-configs/claude-desktop.json` into your desktop config.
- **Cline**: copy `tools/mcp-server/mcp-configs/cline.json` into MCP settings.

All tracked configs launch the stdio server with:

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

## Resources

- `wpcc://latest-scan`
- `wpcc://latest-report`
- `wpcc://scan/{id}`
- `auth://status/{user}`

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