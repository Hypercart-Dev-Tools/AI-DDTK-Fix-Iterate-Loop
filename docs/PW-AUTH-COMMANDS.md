# pw-auth Command Reference

Detailed guide to all `pw-auth` subcommands for WordPress authentication and Playwright session management.

**Last Updated:** 2026-03-22  
**Version:** 1.0.0

---

## Table of Contents

1. [Overview](#overview)
2. [Installation & Prerequisites](#installation--prerequisites)
3. [Commands](#commands)
4. [Output Formats](#output-formats)
5. [Exit Codes](#exit-codes)
6. [Troubleshooting](#troubleshooting)
7. [Examples](#examples)

---

## Overview

`pw-auth` generates one-time WordPress admin login URLs via WP-CLI and captures the authenticated session as Playwright `storageState` for reuse in automated tests and scripts.

**Key Features:**
- ✅ Passwordless authentication (uses WP-CLI)
- ✅ Playwright session caching (12-hour default)
- ✅ Multi-user support (admin, editor, contributor, etc.)
- ✅ Local by Flywheel integration
- ✅ DOM inspection with cached auth
- ✅ Readiness diagnostics

**Auth State Location:**
```
./temp/playwright/.auth/<user>.json
```

---

## Installation & Prerequisites

### Requirements

1. **WP-CLI** — WordPress command-line interface
   ```bash
   # Install globally
   curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
   chmod +x wp-cli.phar
   sudo mv wp-cli.phar /usr/local/bin/wp
   ```

2. **Node.js** — JavaScript runtime
   ```bash
   brew install node
   ```

3. **Playwright** — Browser automation library
   ```bash
   npm install -g playwright
   ```

4. **dev-login-cli.php** — WordPress mu-plugin for one-time login URLs
   - Copy from `~/bin/ai-ddtk/templates/dev-login-cli.php`
   - Install to `wp-content/mu-plugins/dev-login-cli.php`
   - Requires `WP_ENVIRONMENT_TYPE` ≠ `production`

### Verify Installation

```bash
pw-auth doctor --site-url http://my-site.local
```

---

## Commands

### `pw-auth login`

Generate a one-time login URL and save authenticated Playwright session.

#### Syntax

```bash
pw-auth login --site-url <url> [options]
```

#### Required Options

| Option | Description | Example |
|--------|-------------|---------|
| `--site-url` | WordPress site URL | `http://my-site.local` |

#### Optional Options

| Option | Default | Description |
|--------|---------|-------------|
| `--user` | `admin` | WordPress username to authenticate as |
| `--wp-cli` | `wp` | WP-CLI command prefix (e.g., `local-wp my-site`) |
| `--redirect` | `/wp-admin/` | WP admin path to land on after login |
| `--max-age` | `12` | Reuse cached auth if younger than N hours |
| `--force` | — | Skip cache age check, always re-authenticate |
| `--auth-file` | `./temp/playwright/.auth/<user>.json` | Custom auth state file path |
| `--headed` | — | Run Playwright in headed mode (visible browser) |
| `--format` | `text` | Output format: `text` or `json` |

#### Examples

**Basic authentication (admin user):**
```bash
pw-auth login --site-url http://my-site.local
```

**Local by Flywheel site:**
```bash
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"
```

**Authenticate as editor:**
```bash
pw-auth login --site-url http://my-site.local --user=editor
```

**Force re-authentication (skip cache):**
```bash
pw-auth login --site-url http://my-site.local --force
```

**Land on specific admin page:**
```bash
pw-auth login --site-url http://my-site.local --redirect /wp-admin/plugins.php
```

**Visible browser (debugging):**
```bash
pw-auth login --site-url http://my-site.local --headed
```

**Custom auth file location:**
```bash
pw-auth login --site-url http://my-site.local --auth-file /tmp/my-auth.json
```

**JSON output:**
```bash
pw-auth login --site-url http://my-site.local --format json
```

#### Output

**Success (text):**
```
✓ Generated one-time login URL
✓ Authenticated via Playwright
✓ Saved storageState to ./temp/playwright/.auth/admin.json
```

**Success (JSON):**
```json
{
  "status": "success",
  "user": "admin",
  "auth_file": "./temp/playwright/.auth/admin.json",
  "cache_age_hours": 0,
  "message": "Authenticated successfully"
}
```

**Failure:**
```
✗ Error: dev-login-cli.php not installed
  Install from: ~/bin/ai-ddtk/templates/dev-login-cli.php
  Location: wp-content/mu-plugins/dev-login-cli.php
```

---

### `pw-auth doctor`

Check Playwright and pw-auth readiness for a WordPress site.

#### Syntax

```bash
pw-auth doctor --site-url <url> [options]
```

#### Required Options

| Option | Description |
|--------|-------------|
| `--site-url` | WordPress site URL |

#### Optional Options

| Option | Default | Description |
|--------|---------|-------------|
| `--user` | `admin` | WordPress username to check |
| `--wp-cli` | `wp` | WP-CLI command prefix |
| `--format` | `text` | Output format: `text` or `json` |

#### Examples

**Text report:**
```bash
pw-auth doctor --site-url http://my-site.local
```

**JSON report (for scripting):**
```bash
pw-auth doctor --site-url http://my-site.local --format json
```

**Check Local site:**
```bash
pw-auth doctor --site-url http://my-site.local --wp-cli "local-wp my-site"
```

#### Output

**Success (text):**
```
✓ Playwright installed (v1.40.0)
✓ WP-CLI available (wp-cli.phar)
✓ dev-login-cli.php installed
✓ WP_ENVIRONMENT_TYPE not production
✓ Site is reachable (HTTP 200)
✓ User 'admin' exists
✓ Ready for authentication
```

**Success (JSON):**
```json
{
  "status": "ready",
  "checks": {
    "playwright": { "ok": true, "version": "1.40.0" },
    "wp_cli": { "ok": true, "path": "/usr/local/bin/wp" },
    "dev_login_plugin": { "ok": true },
    "environment_type": { "ok": true, "value": "development" },
    "site_reachable": { "ok": true, "status_code": 200 },
    "user_exists": { "ok": true, "user": "admin" }
  }
}
```

**Failure (text):**
```
✗ Playwright not installed
  Install with: npm install -g playwright
```

---

### `pw-auth check dom`

Inspect one or more page elements using optional cached authentication.

#### Syntax

```bash
pw-auth check dom --url <url> (--selector <css> | --selectors <list>) [options]
```

#### Required Options

| Option | Description | Example |
|--------|-------------|---------|
| `--url` | Page URL to inspect | `http://my-site.local/wp-admin/` |
| `--selector` or `--selectors` | Single selector or comma-separated selector list | `#wpbody` or `#wpadminbar, .wrap h1` |

#### Optional Options

| Option | Default | Description |
|--------|---------|-------------|
| `--extract` | `exists` | Extraction mode: `exists`, `text`, or `html` |
| `--assert` | — | Built-in assertion: `visible`, `hidden`, `text-contains`, or `attr-equals` |
| `--assert-value` | — | Expected text/attribute value for assertion modes that require one |
| `--assert-attr` | — | Attribute name for `--assert attr-equals` |
| `--screenshot` | `never` | Screenshot policy: `never`, `on-failure`, or `always` |
| `--wait-for` | — | Wait for a selector before evaluating checks |
| `--user` | — | Resolve auth from `./temp/playwright/.auth/<user>.json` |
| `--auth-state` | — | Explicit Playwright storageState file path |
| `--auth-origin` | inferred | Cookie origin for auth reuse |
| `--timeout` | `15000` | Alias for `--timeout-ms` |
| `--timeout-ms` | `15000` | Navigation/selector timeout in milliseconds |
| `--format` | `text` | Output format: `text` or `json` |
| `--output-dir` | `temp/playwright/checks/<run-id>/` | Directory for artifacts |

#### Examples

**Check if element exists:**
```bash
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpbody" --extract exists
```

**Check multiple selectors in one call:**
```bash
pw-auth check dom \
  --url http://my-site.local/wp-admin/ \
  --selectors "#wpadminbar, .wrap h1"
```

**Extract element text:**
```bash
pw-auth check dom --url http://my-site.local/wp-admin/ --selector ".wp-heading-inline" --extract text --user admin
```

**Extract element HTML:**
```bash
pw-auth check dom --url http://my-site.local/wp-admin/plugins.php --selector "#the-list" --extract html --user admin
```

**With custom timeout:**
```bash
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpbody" --extract exists --timeout 30000
```

**JSON output:**
```bash
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpbody" --extract exists --format json
```

**Wait for AJAX content, assert visibility, and capture failure screenshots:**
```bash
pw-auth check dom \
  --url http://my-site.local/wp-admin/ \
  --selectors "#wpadminbar, .wrap h1" \
  --wait-for ".ajax-ready" \
  --assert visible \
  --screenshot on-failure \
  --user admin \
  --format json
```

**Assert text content:**
```bash
pw-auth check dom \
  --url http://my-site.local/wp-admin/plugins.php \
  --selector ".notice-success" \
  --assert text-contains \
  --assert-value "Settings saved" \
  --user admin
```

**Assert an attribute value:**
```bash
pw-auth check dom \
  --url http://my-site.local/wp-admin/ \
  --selector "body" \
  --assert attr-equals \
  --assert-attr data-theme \
  --assert-value classic \
  --user admin
```

#### Output

The command returns an aggregate result plus a per-selector `results` array.

Aggregate `status` is one of:
- `ok` — all selectors were found and all assertions passed
- `not_found` — at least one selector was missing
- `assertion_failed` — selectors were found but at least one assertion failed
- `auth_required` — the page redirected to login
- `error` — navigation/runtime failure

**Single-selector `exists` output (JSON):**
```json
{
  "status": "ok",
  "selector": "#wpbody",
  "selectors": ["#wpbody"],
  "extract": "exists",
  "auth_used": false,
  "value": true,
  "results": [
    {
      "selector": "#wpbody",
      "status": "ok",
      "match_count": 1,
      "value": true,
      "assertion": null,
      "screenshot_path": null,
      "errors": []
    }
  ],
  "artifacts": {
    "output_dir": "temp/playwright/checks/<run-id>",
    "result_json": "temp/playwright/checks/<run-id>/result.json",
    "extract_file": null,
    "failure_screenshot": null
  },
  "errors": []
}
```

**Multi-selector assertion failure (JSON):**
```
{
  "status": "assertion_failed",
  "selector": null,
  "selectors": ["#wpadminbar", ".wrap h1"],
  "extract": "exists",
  "wait_for": ".ajax-ready",
  "assertion": {
    "type": "visible",
    "value": null,
    "attribute": null
  },
  "auth_used": true,
  "value": false,
  "results": [
    {
      "selector": "#wpadminbar",
      "status": "ok",
      "match_count": 1,
      "value": true,
      "assertion": {
        "type": "visible",
        "passed": true,
        "expected": true,
        "actual": true,
        "message": null
      },
      "screenshot_path": null,
      "errors": []
    },
    {
      "selector": ".wrap h1",
      "status": "assertion_failed",
      "match_count": 1,
      "value": true,
      "assertion": {
        "type": "visible",
        "passed": false,
        "expected": true,
        "actual": false,
        "message": "Assertion failed for .wrap h1: expected element to be visible."
      },
      "screenshot_path": "temp/playwright/checks/<run-id>/selector-02-wrap-h1-failure.png",
      "errors": ["Assertion failed for .wrap h1: expected element to be visible."]
    }
  ],
  "artifacts": {
    "output_dir": "temp/playwright/checks/<run-id>",
    "result_json": "temp/playwright/checks/<run-id>/result.json",
    "extract_file": null,
    "failure_screenshot": null
  },
  "errors": ["Assertion failed for .wrap h1: expected element to be visible."]
}
```

**Text output:**
```
[pw-auth] DOM check status: ok
[pw-auth] URL: http://my-site.local/wp-admin/
[pw-auth] Selectors: #wpbody
[pw-auth] Extract: exists
[pw-auth] Auth used: yes
[pw-auth] Result JSON: temp/playwright/checks/<run-id>/result.json
[pw-auth] Results:
[pw-auth]   - ok: #wpbody (matches: 1)
[pw-auth]     value: true
```

---

### `pw-auth status`

Show cached authentication files and their freshness.

#### Syntax

```bash
pw-auth status [options]
```

#### Optional Options

| Option | Default | Description |
|--------|---------|-------------|
| `--format` | `text` | Output format: `text` or `json` |

#### Examples

**Text report:**
```bash
pw-auth status
```

**JSON report:**
```bash
pw-auth status --format json
```

#### Output

**Text:**
```
Cached auth files:
  admin.json     (8.2 KB, 2 hours old, fresh)
  editor.json    (8.1 KB, 14 hours old, expired)
  contributor.json (7.9 KB, 25 hours old, expired)
```

**JSON:**
```json
{
  "auth_dir": "./temp/playwright/.auth",
  "files": [
    {
      "user": "admin",
      "file": "admin.json",
      "size_bytes": 8192,
      "age_hours": 2,
      "status": "fresh",
      "created_at": "2026-03-22T10:30:00Z"
    },
    {
      "user": "editor",
      "file": "editor.json",
      "size_bytes": 8100,
      "age_hours": 14,
      "status": "expired",
      "created_at": "2026-03-21T20:30:00Z"
    }
  ]
}
```

---

### `pw-auth clear`

Remove cached authentication state files.

#### Syntax

```bash
pw-auth clear [options]
```

#### Optional Options

| Option | Default | Description |
|--------|---------|-------------|
| `--user` | — | Clear only this user's auth (default: clear all) |
| `--force` | — | Skip confirmation prompt |

#### Examples

**Clear all auth:**
```bash
pw-auth clear
```

**Clear only admin auth:**
```bash
pw-auth clear --user admin
```

**Clear without confirmation:**
```bash
pw-auth clear --force
```

#### Output

**Success:**
```
✓ Cleared 3 auth files
```

**Confirmation prompt:**
```
Clear all cached auth files? (y/n)
```

---

## Output Formats

### Text Format

Human-readable output with status indicators:
- `✓` — Success
- `✗` — Error
- `⚠` — Warning

### JSON Format

Structured output for scripting and CI/CD:
```json
{
  "status": "success|error|warning",
  "message": "Human-readable message",
  "data": { /* command-specific data */ }
}
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | `pw-auth login` general failure |
| `2` | Configuration error (missing option, invalid path, invalid assertion config) |
| `3` | `pw-auth check dom` selector failure (`not_found`) |
| `4` | `pw-auth check dom` authentication required (`auth_required`) |
| `5` | Runtime or prerequisite failure |
| `6` | `pw-auth check dom` assertion failure (`assertion_failed`) |
| `127` | Command not found |

---

## Troubleshooting

### "dev-login-cli.php not installed"

**Solution:**
```bash
# Copy mu-plugin
cp ~/bin/ai-ddtk/templates/dev-login-cli.php wp-content/mu-plugins/

# Verify installation
pw-auth doctor --site-url http://my-site.local
```

### "WP_ENVIRONMENT_TYPE is production"

**Solution:**
```bash
# Add to wp-config.php
define('WP_ENVIRONMENT_TYPE', 'development');
```

### "Playwright not installed"

**Solution:**
```bash
npm install -g playwright
```

### "Auth state expired"

**Solution:**
```bash
# Re-authenticate
pw-auth login --site-url http://my-site.local --force
```

### "Timeout waiting for selector"

**Solution:**
```bash
# Increase timeout
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpbody" --extract exists --timeout-ms 30000
```

---

## Examples

### Complete Authentication Workflow

```bash
# 1. Check readiness
pw-auth doctor --site-url http://my-site.local --wp-cli "local-wp my-site"

# 2. Authenticate
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"

# 3. Verify auth
pw-auth status

# 4. Test authenticated access
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpbody" --extract exists --user admin
```

### Using Auth in Playwright Script

```javascript
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    storageState: './temp/playwright/.auth/admin.json'
  });
  const page = await context.newPage();
  await page.goto('http://my-site.local/wp-admin/');
  console.log(await page.title());
  await browser.close();
})();
```

### CI/CD Integration

```bash
#!/bin/bash
set -e

# Authenticate
pw-auth login --site-url http://my-site.local --force

# Run tests
npm test

# Cleanup
pw-auth clear --user admin --force
```

---

## See Also

- [CLI-REFERENCE.md](./CLI-REFERENCE.md) — All AI-DDTK commands
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — Common errors and solutions
- [AGENTS.md](../AGENTS.md) — AI agent guidelines

