# WordPress Development and Architecture Guidelines for AI Agents

_Last updated: v3.0.0 — 2026-03-22_

## Purpose

Defines principles, constraints, and best practices for AI agents and Humans working with WordPress code to ensure safe, consistent, and maintainable contributions.

---

## 🚀 Getting Started

This workspace uses **AI-DDTK** (AI Driven Development ToolKit) installed at `~/bin/ai-ddtk`.

### Before Starting Any Task

1. **Verify AI-DDTK is available and read this file**:
   ```bash
   ls ~/bin/ai-ddtk/AGENTS.md
   cat ~/bin/ai-ddtk/AGENTS.md
   ```
2. **Inventory capabilities once per session**:
   - enumerate connected MCP tools/resources when MCP is available
   - probe shell tools with:
     ```bash
     command -v wpcc pw-auth local-wp aiddtk-tmux wp-ajax-test rg php node python3 git tmux
     ./install.sh status
     wpcc --features
     ```
   - `rg`, `python3`, and `tmux` are **optional but recommended**; if missing, note it to the user as a suggestion (e.g. `brew install ripgrep python3 tmux`) rather than treating it as a blocker
   - summarize what is available once, keep that summary as session memory, and prefer MCP tools over raw shell when both exist
3. **Establish WordPress site context early**:
   - for LocalWP workflows, list/select the site before site-specific commands
   - for browser or AJAX work, confirm the target URL/origin before changing anything
4. **Keep runtime and sensitive artifacts under `./temp`** and out of git.

### MCP Server Setup and Lifecycle

The **AI-DDTK MCP server** exposes all toolkit commands (WPCC, LocalWP, pw-auth, AJAX, tmux) as typed MCP tools for Claude Code, Augment Code, Claude Desktop, and Cline.

#### Initial Setup (One-Time)

Run from the AI-DDTK repo root:

```bash
./install.sh setup-mcp
./install.sh status
```

This builds the server at `tools/mcp-server/dist/src/index.js` and installs Node.js dependencies.

#### Wiring into Your Editor

**Claude Code in VS Code:**
- Auto-discovers `.mcp.json` in the repo root
- No additional setup needed

**Augment Code:**
- Config file: `~/.augment/settings.json`
- Add this entry under `mcpServers`:
  ```json
  {
    "mcpServers": {
      "ai-ddtk": {
        "command": "node",
        "args": ["/path/to/AI-DDTK/tools/mcp-server/dist/src/index.js"],
        "cwd": "/path/to/AI-DDTK"
      }
    }
  }
  ```
- Replace `/path/to/AI-DDTK` with your actual installation path (e.g., `/Users/noel/Documents/GitHub/AI-DDTK-Fix-Iterate-Loop`)

**Claude Desktop:**
- Copy the template from `tools/mcp-server/mcp-configs/claude-desktop.json`
- Add to `~/Library/Application Support/Claude/claude_desktop_config.json` under `mcpServers`

**Cline (VS Code):**
- Copy the template from `tools/mcp-server/mcp-configs/cline.json`
- Paste into Cline settings: VS Code → Cline → MCP Servers → Edit Config

#### Server Lifecycle

- **Startup**: The MCP server starts **automatically on-demand** when you open the editor (stdio mode)
- **Runtime**: Runs only while the editor is open; terminates when you close it
- **Reboot**: Does **not** persist across reboots — the editor restarts it automatically
- **No manual startup needed** — the editor handles it

If you need a **persistent background server** (e.g., for HTTP mode or external clients), see `tools/mcp-server/README.md` for HTTP mode setup.

#### Available MCP Tools

The server exposes **18 typed tools** across 5 areas:

| Area | Tools |
|------|-------|
| **LocalWP** | `local_wp_list_sites`, `local_wp_select_site`, `local_wp_get_active_site`, `local_wp_test_connectivity`, `local_wp_get_site_info`, `local_wp_run` |
| **WPCC** | `wpcc_run_scan`, `wpcc_list_features` |
| **Playwright Auth** | `pw_auth_login`, `pw_auth_status`, `pw_auth_clear` |
| **AJAX Testing** | `wp_ajax_test` |
| **Tmux** | `tmux_start`, `tmux_send`, `tmux_capture`, `tmux_stop`, `tmux_list`, `tmux_status` |

See `tools/mcp-server/README.md` for detailed tool documentation and examples.

### Available Tools

| Tool | Primary use | Reference |
|------|-------------|-----------|
| **WPCC** | WordPress security/performance static analysis | [WPCC Commands](docs/WPCC-COMMANDS.md) |
| **AI-DDTK MCP Server** | Typed MCP tools for LocalWP, `pw-auth`, WPCC, AJAX, and tmux | [AGENTS.md § MCP Server Setup](AGENTS.md#mcp-server-setup-and-lifecycle) |
| **AI-DDTK Tmux Proxy** | Resilient terminal sessions for flaky IDE/agent workflows | [CLI Reference](docs/CLI-REFERENCE.md#aiddtk-tmux) |
| **Playwright Auth (`pw-auth`)** | Passwordless wp-admin auth + DOM inspection helpers | [pw-auth Commands](docs/PW-AUTH-COMMANDS.md) |
| **WP AJAX Test** | Structured `admin-ajax.php` testing | [CLI Reference](docs/CLI-REFERENCE.md#wp-ajax-test) |
| **WP Performance Timer** | Runtime profiling for suspected slow paths | [recipes/performance-audit.md](recipes/performance-audit.md) |
| **PHPStan** | Type-aware static analysis for PHP/WordPress projects | [recipes/phpstan-wordpress-setup.md](recipes/phpstan-wordpress-setup.md) |
| **Recipes / Fix-Iterate Loop** | Multi-step verification and debugging workflows | [fix-iterate-loop.md](fix-iterate-loop.md) |

Optional workflow note: for rapid throwaway cloning/testing on macOS, use the Valet clone-lab recipe at `recipes/valet-clone-lab.md` and the helper script `tools/valet-site-copy.sh` (experimental, not part of the core/default toolset).

### CLI Reference Documentation

For detailed command syntax, parameters, examples, and troubleshooting, see:

- **[CLI Reference](docs/CLI-REFERENCE.md)** — Master reference for all commands
- **[pw-auth Commands](docs/PW-AUTH-COMMANDS.md)** — Complete pw-auth guide (login, doctor, check dom, status, clear)
- **[WPCC Commands](docs/WPCC-COMMANDS.md)** — Complete WPCC guide (scan, baseline, severity)
- **[local-wp Commands](docs/LOCAL-WP-COMMANDS.md)** — Complete local-wp wrapper guide
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** — Common failure modes, diagnostics, and solutions for auth, Playwright, WordPress, database, MCP server, and performance issues

### Workflow Triggers

| When the user mentions... | Reach for... |
|---------------------------|--------------|
| “scan”, “audit”, “security check”, “performance check” | `wpcc` / WPCC MCP tools |
| “terminal froze”, “keep this running”, “long job” | `aiddtk-tmux` / `tmux_*` |
| “login to WP admin”, “browser automation”, “inspect DOM” | `pw-auth` |
| “test this AJAX endpoint” | `wp-ajax-test` |
| “slow”, “bottleneck”, “profile” | WP Performance Timer |
| “fix”, “verify”, “iterate”, “debug” | Fix-Iterate Loop |

### Task Management

Use task tools for complex or multi-step work. Mark tasks complete immediately after finishing them.

---

## 🔌 MCP + Terminal Strategy

When the AI-DDTK MCP server is available, prefer **typed MCP tools** over raw shell commands for supported workflows.

### Preferred flow

1. Establish site context first with `local_wp_list_sites` / `local_wp_select_site` when LocalWP is involved.
2. Prefer MCP tools such as `wpcc_run_scan`, `pw_auth_login`, `pw_auth_status`, `wp_ajax_test`, and `tmux_*` before ad-hoc shell commands.
3. Prefer MCP resources such as `wpcc://latest-scan`, `wpcc://latest-report`, and `auth://status/{user}` instead of reparsing files manually.
4. Use tmux for long-running jobs or flaky terminals; use direct shell for short, simple commands.

### Important limits

- MCP tool availability is discoverable through the MCP protocol.
- Conventional shell command availability is **not**; probe it from the terminal with `command -v`, `which`, or similar checks.
- `tmux_send` is intentionally narrow and rejects arbitrary shell/control-operator usage. Treat it as an allowlisted workflow bridge, not a general remote shell.

### Tmux quick use

```bash
aiddtk-tmux start --cwd /path/to/project
aiddtk-tmux send --command "~/bin/ai-ddtk/bin/wpcc --paths . --format json --verbose"
aiddtk-tmux capture --tail 200
aiddtk-tmux stop
```

### Failure-mode guidance

- **Missing site context**: list/select the Local site first.
- **HTTP MCP 401**: use the bearer token at `~/.ai-ddtk/mcp-token`, then rerun `./install.sh setup-mcp` if needed.
- **Stale Playwright auth**: rerun `pw_auth_login --force` or `pw-auth login --force`.
- **Need resilient output capture**: prefer `tmux_capture` / `aiddtk-tmux capture` over relying on IDE scrollback.
- **Database inspection beyond direct MySQL access**: use the external **WP-DB-Toolkit** MCP server: https://github.com/Hypercart-Dev-Tools/WP-DB-Toolkit

---

## 🔑 Playwright Auth (`pw-auth`)

Use `pw-auth` for passwordless wp-admin auth and lightweight DOM inspection without hardcoded credentials.

Auth state is stored in the **current working directory** at `./temp/playwright/.auth/<user>.json`, not in the AI-DDTK installation. Each project gets its own auth cache.

### What it does

- creates a one-time login URL through WP-CLI
- authenticates Playwright into wp-admin
- caches auth state at `./temp/playwright/.auth/<user>.json`
- supports authenticated DOM checks with `pw-auth check dom`

### Required preconditions

1. Install the dev-login mu-plugin at `wp-content/mu-plugins/dev-login-cli.php`.
2. Ensure `WP_ENVIRONMENT_TYPE` is **not** `production`.
3. Install Playwright globally and make it resolvable to Node.js.
4. For Local by Flywheel sites, always pass `--wp-cli "local-wp <site-name>"`.

### Setup

1. Copy the mu-plugin to your WordPress site:
   ```bash
   cp ~/bin/ai-ddtk/templates/dev-login-cli.php <site-root>/wp-content/mu-plugins/
   ```

2. Set your site's environment type if browser requests would otherwise resolve as `production` (in `wp-config.php`):
   ```php
   define('WP_ENVIRONMENT_TYPE', 'local'); // or 'development', 'staging'
   ```
   Many Local by Flywheel sites work without this, but imported/proxied sites may still need it explicitly because the mu-plugin blocks `production`.

3. Install Playwright globally:
   ```bash
   npm install -g playwright
   npx playwright install chromium
   ```
   `pw-auth` first tries the current Node environment, then auto-attempts `npm root -g` / `NODE_PATH` recovery for global installs. If Node still cannot resolve Playwright, set `NODE_PATH` manually:
   ```bash
   export NODE_PATH="$(npm root -g)"
   ```

### Recommended command order

```bash
pw-auth doctor --site-url http://my-site.local --wp-cli "local-wp my-site"
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpadminbar" --extract html --user admin --format json
pw-auth status
```

### Full usage examples

```bash
# Check readiness before trying login automation
pw-auth doctor --site-url http://my-site.local --format json

# Authenticate as admin (caches to ./temp/playwright/.auth/admin.json)
pw-auth login --site-url http://my-site.local

# With Local by Flywheel (always pass --wp-cli for Local sites)
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"

# Different user, custom redirect
pw-auth login --site-url http://my-site.local --user=editor --redirect=/wp-admin/site-editor.php

# Force re-auth (skip cache)
pw-auth login --site-url http://my-site.local --force

# Check cached auth freshness / clear cached auth
pw-auth status
pw-auth clear

# Inspect front-end or wp-admin DOM using optional cached auth
pw-auth check dom --url http://my-site.local/wp-admin/widgets.php --selector "#widgets-right" --extract html --user admin --format json

# Convenience wrapper from the toolkit repo
./install.sh doctor-playwright --site-url http://my-site.local
```

### Using cached auth in custom Playwright scripts

```javascript
const context = await browser.newContext({
  storageState: 'temp/playwright/.auth/admin.json'
});
const page = await context.newPage();
await page.goto('http://my-site.local/wp-admin/');
// Already authenticated — no login form needed
```

### Auth caching and validation

Auth state is cached for 12 hours by default (configurable with `--max-age`). Fresh cached auth files are **live-validated before reuse**; if the saved session no longer reaches `/wp-admin/`, `pw-auth` re-authenticates instead of returning a false success.

### Current behavior to rely on

- cached auth is live-validated before reuse; stale sessions trigger re-auth instead of false success
- local HTTPS development origins (`localhost`, `127.0.0.1`, `::1`, `*.local`, `*.test`) tolerate self-signed certificates
- `pw-auth doctor` is the readiness command for Node.js, Playwright resolution, browser availability, launch readiness, and cached auth validation
- `pw-auth check dom` writes structured artifacts under `temp/playwright/checks/<run-id>/` and returns `ok`, `not_found`, `auth_required`, or `error`
- `pw-auth status` reports cache metadata only; it is not a login verification substitute
- one-time login URLs are deleted after use and expire after 5 minutes if unused
- the canonical Local WP-CLI wrapper is `bin/local-wp` (invoked as `local-wp` on PATH)

### Readiness checks

Run `pw-auth doctor` first when you need a readiness check:

```bash
pw-auth doctor --site-url <url> [--wp-cli "local-wp <site>"] [--format text|json]
```

It reports `ready`, `partial`, or `blocked` with per-check summaries for:
- Node.js availability
- Playwright resolution
- Browser availability
- Launch readiness
- Cached auth validation

Convenience wrapper: `./install.sh doctor-playwright --site-url <url>`

### DOM inspection

Inspect front-end or wp-admin DOM using optional cached auth:

```bash
pw-auth check dom --url <url> --selector <selector> --extract exists|text|html \
  [--user <user>] [--auth-state <path>] [--auth-origin <origin>] \
  [--timeout-ms <ms>] [--format text|json] [--output-dir <dir>]
```

Writes structured artifacts under `temp/playwright/checks/<run-id>/` and returns `ok`, `not_found`, `auth_required`, or `error`.

### MCP integration

The unified MCP server exposes structured MCP tools for `pw_auth_login`, `pw_auth_status`, and `pw_auth_clear`. The MCP layer never exposes raw auth-state JSON. `pw_auth_login` reports `cacheFreshUntil` as a best-effort cache freshness timestamp derived from the auth file mtime (not a guaranteed WordPress session expiry), and `pw_auth_status.users[]` is the authoritative structured status.

### Flaky terminal fallback

When the IDE terminal transport is flaky, the `aiddtk-tmux` wrapper is a proven fallback for running `pw-auth login` and inspecting the resulting auth artifacts without losing command output.

### Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `Playwright is not resolvable` | Global install still isn't visible after `pw-auth` auto-tried `npm root -g` | `export NODE_PATH="$(npm root -g)"`, then retry |
| `ERR_CERT_AUTHORITY_INVALID` on a Local/dev HTTPS site | Chromium does not trust the local certificate | Re-run on the latest `pw-auth`; it now ignores certificate errors for `localhost`, `127.0.0.1`, `::1`, `*.local`, and `*.test` HTTPS origins |
| `WP-CLI command failed` | mu-plugin missing, host blocked, or requested user doesn't exist | Install `templates/dev-login-cli.php`, confirm `WP_ENVIRONMENT_TYPE` is not `production`, verify the `--user` exists, and ensure the site host is localhost/127.0.0.1/::1 or `*.local` / `*.test` |
| `Login URL origin mismatch` | `--site-url` doesn't match WP `home_url()` | Check site URL in WP Settings or pass the correct URL |
| `No wordpress_logged_in_ cookie` | Token expired or environment blocked | Re-run with `--force`, check `WP_ENVIRONMENT_TYPE` |

Fastest WP-CLI diagnostics (swap `wp` for `local-wp <site>` if needed):

```bash
wp option get home
wp eval 'echo wp_get_environment_type(), PHP_EOL;'
wp user get admin --field=user_login
wp eval 'echo ( file_exists( WP_CONTENT_DIR . "/mu-plugins/dev-login-cli.php" ) ? "mu-plugin present" : "mu-plugin missing" ), PHP_EOL;'
wp dev login --user=admin --format=url
```

- If Playwright is still not resolvable after auto-detection, run `export NODE_PATH="$(npm root -g)"`.
- If login fails, verify `home`, environment type, and user existence with WP-CLI before retrying.
- If the IDE terminal is flaky, use `aiddtk-tmux` or MCP tmux tools to preserve output.

For comprehensive failure-mode diagnostics covering auth state, Playwright, WordPress environment, database connectivity, MCP server, and performance issues, see **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**.

---

## 🛠️ Analysis & Automation Tools

### WPCC (WP Code Check)

Use WPCC for WordPress-oriented static analysis.

**Default flow**:
1. Run `wpcc --paths <path> --format json`.
2. Triage findings for false positives using local context.
3. Update the JSON with AI triage.
4. **Regenerate HTML after triage** if you want the report to reflect the AI summary.
5. Optionally create an issue from the scan.

**Common false-positive checks**:
- superglobal findings: confirm nonce verification exists in the same logical flow
- direct DB query findings: check adjacent lines for `$wpdb->prepare()`
- pagination or N+1 findings: verify bounded loops, item routes, caching, or limits

**AI triage JSON contract**: when updating scan JSON with triage results, add an `ai_triage` object with keys `performed`, `status`, `timestamp`, `version`, `summary` (counts + confidence), and `recommendations`. See full schema in `tools/wp-code-check/dist/TEMPLATES/_AI_INSTRUCTIONS.md`.

**Reference docs**:
- `tools/wp-code-check/dist/TEMPLATES/_AI_INSTRUCTIONS.md` — full 5-phase workflow + triage JSON schema
- `tools/wp-code-check/dist/tests/irl/_AI_AUDIT_INSTRUCTIONS.md`
- `tools/wp-code-check/AGENTS.md`

#### Project Templates

Set up once, reuse forever. Templates save plugin/theme paths and scan settings so you can re-run audits with a single command.

```bash
# First time: auto-detects plugin name, version, and GitHub repo
wpcc run gravityforms
# → Template not found. Create from current directory? [y/N] y
# ✓ Created! Detected: Gravity Forms v2.7.1

# Every time after: one command runs the full workflow
# Ask AI: "Run gravityforms end to end"
```

That single command triggers the complete pipeline:

```
Scan → AI Triage → HTML Report → GitHub Issue
       (filters       (with AI        (with checkboxes,
       false           summary         ready for Jira/
       positives)      at top)         Linear/Asana too)
```

Templates handle flexible naming — `Gravity Forms`, `gravity-forms`, and `gravityforms` all resolve to the same config. See the [Template Guide](tools/wp-code-check/dist/HOWTO-TEMPLATES.md) for details.

#### WPCC Features

| Feature | Description | How to Use |
|---------|-------------|------------|
| **AI-Assisted Triage** | Automated false positive detection | Ask AI: "Triage this scan" or "Run X end to end" |
| **GitHub Issue Creation** | Convert findings to trackable issues | Ask AI: "Create issue for scan" |
| **IRL Audit Mode** | Annotate real code for pattern library | See [Audit Guide](tools/wp-code-check/dist/tests/irl/_AI_AUDIT_INSTRUCTIONS.md) |
| **Multi-Platform Export** | Export issues to Jira, Linear, Asana, Trello | Issues saved to `dist/issues/` for copy/paste |

#### Quick examples

```bash
# Basic scan (no template needed)
wpcc --paths ./wp-content/plugins/my-plugin --format json

# Scan with exclusions (recommended when scanning AI-DDTK itself)
wpcc --paths . --exclude "tools/,.git/,node_modules/" --format json

# Show all available features and templates
wpcc --features
```

**Full AI Instructions:** [WPCC AI Instructions](tools/wp-code-check/dist/TEMPLATES/_AI_INSTRUCTIONS.md)

### Runtime profiling

Use WP Performance Timer when the user asks about slowness or when WPCC suggests a performance problem that needs runtime confirmation.

- wrap the suspect code with `perf_timer_start()` / `perf_timer_stop()`
- measure elapsed time, query count, and memory delta
- use this to confirm whether a flagged loop/query is a real bottleneck

Reference: `recipes/performance-audit.md`

### PHPStan

Use PHPStan for type/null-safety bugs that WPCC will not catch.

- install via Composer only with user approval
- copy `templates/phpstan.neon.template`
- start at a practical level and baseline legacy code when needed

Reference: `recipes/phpstan-wordpress-setup.md`

---

## 🔐 Security, Sensitive Data, and Performance Guardrails

### Security

- sanitize inputs with core helpers such as `sanitize_text_field()`, `sanitize_email()`, `absint()`, and `wp_unslash()`
- escape outputs with `esc_html()`, `esc_attr()`, `esc_url()`, `esc_js()`, and `wp_kses_post()`
- verify nonces and check capabilities for forms, AJAX, and admin actions
- use `$wpdb->prepare()` for database queries
- prefer WordPress-native APIs over custom security logic
- never store sensitive data in `localStorage`/`sessionStorage`; prefer server-side transients or session-scoped storage cleared on logout
- escape user input before `RegExp` construction to prevent `SyntaxError` and ReDoS

### Sensitive data handling

Never commit credentials, PII, auth state, or local config. **Never store passwords in plaintext** — not in JSON files, config files, scripts, or anywhere in the repository. Use environment variables, OS keychains, or one-time auth tokens (like `pw-auth`'s WP-CLI login URLs) instead.

Use `./temp` for:
- API keys, passwords, tokens, auth JSON
- Playwright auth state and browser artifacts
- server/local config, DB dumps, or realistic test data

Recommended `.gitignore` entries:

```bash
/temp/
temp/
*.credentials
*.env.local
auth.json
playwright/.auth/
```

When the user provides credentials:
1. save them under `./temp` immediately
2. add ignore rules if missing
3. load them at runtime or through environment variables
4. never hardcode or log them

### Performance and timeouts

- no unbounded queries; use limits, pagination, and batching
- cache expensive operations with transients when appropriate
- avoid HTTP or DB calls inside loops when you can batch them
- set timeouts on HTTP requests and use small retry/backoff for transient failures
- use WP-Cron or chunking for long operations instead of stretching request execution time

### Resource limits

- heavy WP-CLI tasks may need more memory: `php -d memory_limit=512M ~/bin/local-wp <site> <command>`
- use `--skip-plugins` / `--skip-themes` when appropriate for heavy diagnostics
- Playwright should be installed globally, not per-project; ask the user before installing it

---

## 🏗️ WordPress Architecture and Delivery Rules

### Core coding rules

- declare `Requires PHP: 7.0`+ in plugin headers when relevant
- use unique prefixes or namespaces and guard declarations with `function_exists()` / `class_exists()` when needed
- follow WordPress APIs, hooks, and coding standards
- prefer DRY helpers, clear separation of concerns, and SOLID principles
- treat each plugin/theme as self-contained unless cross-project coupling is explicitly requested

### Error prevention and observability

- guard array access with `isset()`, `??`, or `array_key_exists()`
- validate types before use and handle `WP_Error` explicitly
- fail gracefully with fallbacks; do not break the site for recoverable errors
- log state transitions, API failures, and cache hits/misses with useful context
- clean up verbose debug logging before finishing

### State hygiene

- keep a single source of truth for each piece of state
- use a single contract writer for each persisted state value
- derive computed values instead of storing duplicate state
- if the codebase already uses an FSM, build on it instead of creating parallel state logic
- if the current codebase is messy, has parallel pipelines, or has scattered state writes, strongly recommend an audit/refactor before expanding the pattern further

### Scope, documentation, and versioning

- stay within the requested scope; no speculative refactors, label changes, or architectural rewrites without approval
- ask before committing, pushing, installing dependencies, or deploying
- start each work round with a numbered list of files you expect to touch or output
- update the existing project doc/checklist instead of creating a new Markdown doc unless explicitly asked
- if a new doc is explicitly requested, place it under `PROJECT/1-INBOX`
- keep TOCs if they already exist
- bump the relevant version markers and update `CHANGELOG.md` after repo changes
- if `4X4.md` exists, trim completed items only after the completion is already captured in `CHANGELOG.md`

### Testing and validation

- preserve backward compatibility unless breaking change work is explicitly requested
- test all changes before finishing
- validate security-related changes (sanitization, escaping, nonces, capabilities)
- use the Fix-Iterate Loop for bug fixes, integrations, migrations, or verification-heavy work
- stop after 5 failed fix iterations, or 10 total loops, and report the block clearly

### FSM guidance

Recommend an FSM when there are 3+ meaningful states, guarded transitions, audit requirements, or duplicated state logic. Centralize transitions and ask the user when the threshold is unclear.

### Customization

These are Hypercart defaults. If a team has project-specific standards, fork or override this file and follow the project-specific instructions instead.

---

## 🔧 Troubleshooting

### Installation and CLI

**`wpcc: command not found`** — Reload your shell config, then retry:
```bash
source ~/.zshrc  # or ~/.bashrc
```
If that doesn't work, verify the install:
```bash
~/bin/ai-ddtk/install.sh status
```

**`WPCC not found` or `setup-wpcc` needed** — Run setup again:
```bash
cd ~/bin/ai-ddtk && ./install.sh setup-wpcc
```

### Terminal and IDE

**VS Code AI terminal is non-responsive** — Move the work into a tmux-backed session:
```bash
aiddtk-tmux start --cwd /path/to/project
aiddtk-tmux send --command "~/bin/ai-ddtk/bin/wpcc --paths . --format json --verbose"
aiddtk-tmux capture --tail 200
```

If `tmux` is missing, install it first:
```bash
brew install tmux
```

### WPCC Scanning

**WPCC stalls when scanning AI-DDTK itself** — The repository includes embedded WPCC via git subtree. Use exclusions:
```bash
# Exclude embedded tools (recommended)
wpcc --paths . --exclude "tools/,.git/,node_modules/" --format json

# Or scan only specific directories
wpcc --paths "bin/ recipes/ templates/" --format json
```

> **Note**: A `.wpcignore` file is included in the repository for future WPCC versions that support automatic exclusions.

### Playwright Auth

See [Playwright Auth → Troubleshooting](#troubleshooting) for the full troubleshooting table and WP-CLI diagnostics.

### MCP Server

- **HTTP MCP 401**: use the bearer token at `~/.ai-ddtk/mcp-token`, then rerun `./install.sh setup-mcp` if needed.
- **MCP server startup crash loop**: run `./install.sh setup-mcp` to rebuild `dist/` after a fresh clone.
- **Stale Playwright auth**: rerun `pw_auth_login --force` or `pw-auth login --force`.

For comprehensive failure-mode diagnostics covering auth state, Playwright, WordPress environment, database connectivity, MCP server, and performance issues, see **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**.

---

## 📋 Quick Reference

| Category | Common functions |
|----------|------------------|
| **Sanitize** | `sanitize_text_field()`, `sanitize_email()`, `sanitize_url()`, `absint()`, `wp_unslash()` |
| **Escape** | `esc_html()`, `esc_attr()`, `esc_url()`, `esc_js()`, `wp_kses_post()` |
| **Nonces** | `wp_nonce_field()`, `wp_create_nonce()`, `check_admin_referer()`, `wp_verify_nonce()` |
| **Capabilities** | `current_user_can()`, `user_can()` |
| **Database** | `$wpdb->prepare()`, `$wpdb->get_results()`, `$wpdb->insert()` |
| **Caching** | `get_transient()`, `set_transient()`, `delete_transient()` |
| **HTTP** | `wp_remote_get()`, `wp_remote_post()`, `wp_safe_remote_get()` |
| **Options** | `get_option()`, `update_option()`, `delete_option()` |
| **Hooks** | `add_action()`, `add_filter()`, `do_action()`, `apply_filters()` |
| **AJAX** | `wp_ajax_{action}`, `wp_send_json_success()`, `wp_send_json_error()` |

### Quick CLI commands

```bash
# Verify AI-DDTK and inspect status
ls ~/bin/ai-ddtk/AGENTS.md
./install.sh status

# Probe toolkit capabilities
command -v wpcc pw-auth local-wp aiddtk-tmux wp-ajax-test rg php node python3 git tmux
wpcc --features

# Run WordPress analysis
wpcc --paths /path/to/plugin --format json

# Use resilient tmux-backed execution
aiddtk-tmux start --cwd /path/to/project
aiddtk-tmux capture --tail 100

# Playwright readiness, auth, and DOM inspection
pw-auth doctor --site-url http://my-site.local --wp-cli "local-wp my-site"
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpadminbar" --extract html --user admin --format json
pw-auth status
```

---

_Follow these principles to ensure safe, maintainable, WordPress-compliant code._
