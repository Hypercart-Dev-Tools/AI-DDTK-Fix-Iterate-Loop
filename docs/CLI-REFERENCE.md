# AI-DDTK CLI Reference

Complete command reference for all AI-DDTK tools: `pw-auth`, `wpcc`, `local-wp`, `wp-ajax-test`, `aiddtk-tmux`.

**Last Updated:** 2026-03-22  
**Version:** 1.0.0

---

## Table of Contents

1. [pw-auth](#pw-auth) — Playwright authentication helper
2. [wpcc](#wpcc) — WordPress code analyzer
3. [local-wp](#local-wp) — Local by Flywheel WP-CLI wrapper
4. [wp-ajax-test](#wp-ajax-test) — AJAX endpoint testing
5. [aiddtk-tmux](#aiddtk-tmux) — Resilient terminal sessions
6. [Exit Codes](#exit-codes)
7. [Common Patterns](#common-patterns)

---

## pw-auth

**Purpose:** Generate one-time WordPress admin login URLs and cache authenticated Playwright sessions.

**Location:** `~/bin/ai-ddtk/bin/pw-auth`

### Commands

#### `pw-auth login`
Authenticate to WordPress and save Playwright storageState.

```bash
pw-auth login --site-url <url> [options]
```

**Options:**
- `--site-url <url>` — WordPress site URL (required)
- `--user <login>` — WordPress username (default: `admin`)
- `--wp-cli <cmd>` — WP-CLI command prefix (default: `wp`)
  - Example: `"local-wp my-site"` for Local by Flywheel
- `--redirect <path>` — WP admin path to land on after login (default: `/wp-admin/`)
- `--max-age <hours>` — Reuse cached auth if younger than this (default: `12`)
- `--force` — Skip cache age check, always re-authenticate
- `--auth-file <path>` — Custom path for auth state file
- `--headed` — Run Playwright in headed mode (visible browser)
- `--format <text|json>` — Output format (default: `text`)

**Examples:**
```bash
# Basic authentication
pw-auth login --site-url http://my-site.local

# Local by Flywheel site
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"

# Authenticate as editor user
pw-auth login --site-url http://my-site.local --user=editor

# Force re-authentication
pw-auth login --site-url http://my-site.local --force

# Land on specific admin page
pw-auth login --site-url http://my-site.local --redirect /wp-admin/plugins.php
```

**Output:**
- **Success:** Auth state saved to `./temp/playwright/.auth/<user>.json`
- **Failure:** Error message with diagnostic hints

---

#### `pw-auth doctor`
Check Playwright and pw-auth readiness for a site.

```bash
pw-auth doctor --site-url <url> [options]
```

**Options:**
- `--site-url <url>` — WordPress site URL (required)
- `--user <login>` — WordPress username (default: `admin`)
- `--wp-cli <cmd>` — WP-CLI command prefix (default: `wp`)
- `--format <text|json>` — Output format (default: `text`)

**Examples:**
```bash
# Text report
pw-auth doctor --site-url http://my-site.local

# JSON report for scripting
pw-auth doctor --site-url http://my-site.local --format json

# Check Local site readiness
pw-auth doctor --site-url http://my-site.local --wp-cli "local-wp my-site"
```

**Output (text):**
```
✓ Playwright installed
✓ WP-CLI available
✓ dev-login-cli.php installed
✓ WP_ENVIRONMENT_TYPE not production
✓ Site is reachable
```

---

#### `pw-auth check dom`
Inspect a page element using optional cached authentication.

```bash
pw-auth check dom --url <url> --selector <css> --extract <mode> [options]
```

**Options:**
- `--url <url>` — Page URL to inspect (required)
- `--selector <css>` — CSS selector to find (required)
- `--extract <mode>` — One of: `exists`, `text`, `html` (required)
- `--user <login>` — Resolve auth from `./temp/playwright/.auth/<user>.json`
- `--auth-state <path>` — Explicit Playwright storageState file
- `--auth-origin <origin>` — Cookie origin for auth reuse (default: inferred from `--url`)
- `--timeout-ms <ms>` — Navigation/selector timeout (default: `15000`)
- `--format <text|json>` — Output format (default: `text`)
- `--output-dir <dir>` — Directory for artifacts (default: `temp/playwright/checks/<run-id>/`)

**Examples:**
```bash
# Check if element exists
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpbody" --extract exists

# Extract element text
pw-auth check dom --url http://my-site.local/wp-admin/ --selector ".wp-heading-inline" --extract text --user admin

# Extract element HTML
pw-auth check dom --url http://my-site.local/wp-admin/plugins.php --selector "#the-list" --extract html --user admin --format json

# With custom timeout
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpbody" --extract exists --timeout-ms 30000
```

**Output:**
- **exists:** `ok`, `not_found`, `auth_required`, or `error`
- **text/html:** Extracted content or error message
- **JSON:** Structured result with metadata

---

#### `pw-auth status`
Show cached authentication files and their freshness.

```bash
pw-auth status [options]
```

**Options:**
- `--format <text|json>` — Output format (default: `text`)

**Examples:**
```bash
# Text report
pw-auth status

# JSON report
pw-auth status --format json
```

**Output (text):**
```
Cached auth files:
  admin.json     (8.2 KB, 2 hours old, fresh)
  editor.json    (8.1 KB, 14 hours old, expired)
```

---

#### `pw-auth clear`
Remove all cached authentication state files.

```bash
pw-auth clear [options]
```

**Options:**
- `--user <login>` — Clear only this user's auth (default: clear all)
- `--force` — Skip confirmation prompt

**Examples:**
```bash
# Clear all auth
pw-auth clear

# Clear only admin auth
pw-auth clear --user admin

# Clear without confirmation
pw-auth clear --force
```

---

## wpcc

**Purpose:** Fast WordPress code analyzer for performance, security, and best practices.

**Location:** `~/bin/ai-ddtk/bin/wpcc`

### Commands

#### `wpcc` (default: scan)
Analyze WordPress code for issues.

```bash
wpcc [options] [paths...]
```

**Options:**
- `--paths <paths>` — Paths to scan (default: current directory)
- `--format <text|json>` — Output format (default: `json`)
- `--strict` — Fail on warnings (exit code 1)
- `--verbose` — Show all matches, not just first occurrence
- `--no-log` — Disable logging to file
- `--no-context` — Disable context lines around findings
- `--context-lines <n>` — Number of context lines (default: `3`)
- `--project <name>` — Load configuration from `TEMPLATES/<name>.txt`
- `--severity-config <path>` — Use custom severity levels from JSON
- `--generate-baseline` — Generate `.hcc-baseline` from current findings
- `--baseline <path>` — Use custom baseline file (default: `.hcc-baseline`)
- `--ignore-baseline` — Ignore baseline file even if present
- `--enable-clone-detection` — Enable function clone detection
- `--help` — Show help message

**Examples:**
```bash
# Scan current directory
wpcc

# Scan specific plugin
wpcc --paths ~/wp-content/plugins/my-plugin

# Scan multiple paths
wpcc --paths "~/plugin1 ~/plugin2"

# JSON output for CI/CD
wpcc --format json --strict

# Generate baseline for legacy code
wpcc --generate-baseline

# Scan with custom severity config
wpcc --severity-config ./custom-severity.json

# Verbose output with all matches
wpcc --verbose --context-lines 5
```

**Output:**
- **JSON:** Structured findings with severity, line numbers, and context
- **Text:** Human-readable report with color coding
- **HTML:** Generated report (when format is json)

**Exit Codes:**
- `0` — No issues found
- `1` — Issues found (or `--strict` mode with warnings)
- `2` — Configuration or runtime error

---

#### `wpcc --features`
List available detection rules and features.

```bash
wpcc --features
```

---

## local-wp

**Purpose:** WP-CLI wrapper for Local by Flywheel sites.

**Location:** `~/bin/ai-ddtk/bin/local-wp`

### Syntax

```bash
local-wp <site-name> <wp-cli-command> [args...]
```

### Common Commands

#### Site Information
```bash
# List available sites
local-wp --list

# Get WordPress version
local-wp my-site core version

# Get site URL
local-wp my-site option get siteurl

# Get site info
local-wp my-site core version --extra
```

#### Plugin Management
```bash
# List all plugins
local-wp my-site plugin list

# List active plugins
local-wp my-site plugin list --status=active

# Activate plugin
local-wp my-site plugin activate my-plugin

# Deactivate plugin
local-wp my-site plugin deactivate my-plugin

# Get plugin info
local-wp my-site plugin get my-plugin
```

#### Theme Management
```bash
# List themes
local-wp my-site theme list

# Activate theme
local-wp my-site theme activate my-theme

# Get active theme
local-wp my-site theme list --status=active
```

#### Database Operations
```bash
# Run SQL query
local-wp my-site db query "SELECT * FROM wp_options LIMIT 5"

# Export database
local-wp my-site db export backup.sql

# Search and replace
local-wp my-site search-replace 'old-url.com' 'new-url.com'

# Optimize database
local-wp my-site db optimize
```

#### Post/Page Management
```bash
# List posts
local-wp my-site post list

# Create post
local-wp my-site post create --post_title="Title" --post_content="Content" --post_status=publish

# Delete post
local-wp my-site post delete <post-id>
```

#### User Management
```bash
# List users
local-wp my-site user list

# Create user
local-wp my-site user create testuser test@example.com --role=editor

# Delete user
local-wp my-site user delete <user-id>
```

### Environment Variables

Override auto-detection with environment variables:

```bash
export LOCAL_SITES_DIR="$HOME/Local Sites"
export LOCAL_RUN_DIR="$HOME/Library/Application Support/Local/run"
export WP_CLI_PHAR="/Applications/Local.app/Contents/Resources/extraResources/bin/wp-cli/wp-cli.phar"
export PHP_BIN="/path/to/php"
export LOCAL_WP_MEMORY_LIMIT="512M"  # PHP memory_limit for WP-CLI
```

### Exit Codes

- `0` — Command succeeded
- `1` — WP-CLI error
- `2` — Site not found
- `3` — Configuration error

---

## wp-ajax-test

**Purpose:** Test WordPress AJAX endpoints with structured requests and responses.

**Location:** `~/bin/ai-ddtk/bin/wp-ajax-test`

### Syntax

```bash
wp-ajax-test [options]
```

### Options

- `--action <action>` — AJAX action name (required)
- `--url <url>` — Site URL (required)
- `--method <GET|POST>` — HTTP method (default: `POST`)
- `--data <json>` — Request data as JSON
- `--user <login>` — Authenticate as user
- `--nonce <nonce>` — WordPress nonce for verification
- `--format <text|json>` — Output format (default: `text`)
- `--timeout <ms>` — Request timeout in milliseconds (default: `30000`)

### Examples

```bash
# Test AJAX action
wp-ajax-test --action my_action --url http://my-site.local

# POST with data
wp-ajax-test --action my_action --url http://my-site.local --data '{"key":"value"}'

# Authenticated request
wp-ajax-test --action my_action --url http://my-site.local --user admin

# With nonce
wp-ajax-test --action my_action --url http://my-site.local --nonce abc123

# JSON output
wp-ajax-test --action my_action --url http://my-site.local --format json
```

---

## aiddtk-tmux

**Purpose:** Resilient terminal sessions for long-running commands.

**Location:** `~/bin/ai-ddtk/bin/aiddtk-tmux`

### Commands

#### `aiddtk-tmux start`
Start a new tmux session.

```bash
aiddtk-tmux start [options]
```

**Options:**
- `--cwd <path>` — Working directory (default: current directory)
- `--name <name>` — Session name (default: auto-generated)

#### `aiddtk-tmux send`
Send a command to the session.

```bash
aiddtk-tmux send --command "<command>"
```

#### `aiddtk-tmux capture`
Capture session output.

```bash
aiddtk-tmux capture [options]
```

**Options:**
- `--tail <lines>` — Show last N lines (default: all)

#### `aiddtk-tmux stop`
Stop the session.

```bash
aiddtk-tmux stop
```

#### `aiddtk-tmux list`
List all active sessions.

```bash
aiddtk-tmux list
```

#### `aiddtk-tmux status`
Show session status.

```bash
aiddtk-tmux status
```

### Examples

```bash
# Start session
aiddtk-tmux start --cwd /path/to/project

# Send command
aiddtk-tmux send --command "npm run build"

# Capture output
aiddtk-tmux capture --tail 100

# Stop session
aiddtk-tmux stop
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error |
| `2` | Configuration error |
| `3` | Not found (site, file, etc.) |
| `4` | Permission denied |
| `5` | Timeout |
| `127` | Command not found |

---

## Common Patterns

### Authenticate and Test

```bash
# 1. Authenticate
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"

# 2. Check admin access
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpbody" --extract exists --user admin

# 3. Run AJAX test
wp-ajax-test --action my_action --url http://my-site.local --user admin
```

### Scan and Analyze

```bash
# 1. Scan plugin
wpcc --paths ~/wp-content/plugins/my-plugin --format json

# 2. Generate baseline
wpcc --paths ~/wp-content/plugins/my-plugin --generate-baseline

# 3. Scan with baseline
wpcc --paths ~/wp-content/plugins/my-plugin --baseline .hcc-baseline
```

### Local Site Workflow

```bash
# 1. List sites
local-wp --list

# 2. Get site info
local-wp my-site core version

# 3. Manage plugins
local-wp my-site plugin list
local-wp my-site plugin activate my-plugin

# 4. Database operations
local-wp my-site db export backup.sql
```

---

## See Also

- [AGENTS.md](../AGENTS.md) — AI agent guidelines and tool integration
- [README.md](../README.md) — Installation and quick start
- [Troubleshooting Guide](./TROUBLESHOOTING.md) — Common errors and solutions

