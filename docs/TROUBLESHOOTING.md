# AI-DDTK Troubleshooting Guide

_Last updated: 2026-03-22 · Toolkit version: see [CHANGELOG.md](../CHANGELOG.md)_

A comprehensive reference for diagnosing and resolving common failures when using AI-DDTK tools including `pw-auth`, `wpcc`, `local-wp`, the MCP server, and associated Playwright workflows.

---

## Table of Contents

1. [Auth State Issues](#1-auth-state-issues)
   - [1.1 Cached Auth Expired or Invalid](#11-cached-auth-expired-or-invalid)
   - [1.2 Re-authentication Loop](#12-re-authentication-loop)
   - [1.3 Auth State Missing After Login](#13-auth-state-missing-after-login)
2. [Playwright Issues](#2-playwright-issues)
   - [2.1 Browser Launch Failure](#21-browser-launch-failure)
   - [2.2 Navigation or Action Timeout](#22-navigation-or-action-timeout)
   - [2.3 DOM Selector Not Found](#23-dom-selector-not-found)
3. [WordPress Environment Issues](#3-wordpress-environment-issues)
   - [3.1 Production Environment Block](#31-production-environment-block)
   - [3.2 WP-CLI Permission Denied](#32-wp-cli-permission-denied)
   - [3.3 dev-login-cli.php Not Installed](#33-dev-login-cliphp-not-installed)
4. [Database Connectivity Issues](#4-database-connectivity-issues)
   - [4.1 MySQL Connection Refused](#41-mysql-connection-refused)
   - [4.2 WP-CLI Database Command Fails](#42-wp-cli-database-command-fails)
   - [4.3 Slow Queries Causing Timeouts](#43-slow-queries-causing-timeouts)
5. [MCP Server Issues](#5-mcp-server-issues)
   - [5.1 MCP Server Fails to Start](#51-mcp-server-fails-to-start)
   - [5.2 MCP Tool Calls Return Errors](#52-mcp-tool-calls-return-errors)
   - [5.3 MCP Server Not Discovered by Editor](#53-mcp-server-not-discovered-by-editor)
6. [Performance Issues](#6-performance-issues)
   - [6.1 Slow Test Execution](#61-slow-test-execution)
   - [6.2 pw-auth Login Takes Too Long](#62-pw-auth-login-takes-too-long)
   - [6.3 WPCC Scan Timeout](#63-wpcc-scan-timeout)
7. [Quick Reference: Exit Codes](#7-quick-reference-exit-codes)
8. [Quick Reference: Diagnostic Commands](#8-quick-reference-diagnostic-commands)

---

## 1. Auth State Issues

Auth state is cached by `pw-auth` at `temp/playwright/.auth/<user>.json`. A valid session is required before any Playwright DOM inspection or browser automation can run.

---

### 1.1 Cached Auth Expired or Invalid

**Problem**

`pw-auth` reports the session as expired or `pw-auth check dom` returns `auth_required` even though you logged in recently.

```
Error: Cached auth state is stale. Re-authentication required.
```

or

```json
{ "status": "auth_required", "message": "Session expired or invalid" }
```

**Root Cause**

WordPress sessions expire based on the `auth_cookie_expiration` filter (default 48 hours for "remember me", 2 days for standard login). `pw-auth` validates the cached state by making a lightweight authenticated request before each use. If the cookie has expired or the WordPress database has cleared the session, the cached file is considered stale.

The auth file at `temp/playwright/.auth/<user>.json` stores cookies and localStorage, but the cookies have an expiry time set by WordPress at login time. After that time, or after a `wp auth session destroy` call, the stored state is no longer valid.

**Diagnostic Steps**

1. Check the current auth status:
   ```bash
   pw-auth status
   ```
   Look for `expires` or `valid: false` in the output.

2. Inspect the raw auth file to see cookie expiry timestamps:
   ```bash
   cat temp/playwright/.auth/admin.json | python3 -m json.tool | grep -i expir
   ```

3. Test whether the site is actually reachable:
   ```bash
   curl -I http://my-site.local/wp-admin/
   ```
   A `302` redirect to `wp-login.php` confirms the session is expired.

4. Check WordPress session lifetime:
   ```bash
   local-wp my-site wp eval "echo wp_login_url();"
   ```

**Solution**

Force a fresh login to regenerate the auth state:

```bash
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site" --force
```

The `--force` flag skips the cached-state validation check and always creates a new session.

After re-authentication, verify the new state is valid:

```bash
pw-auth status
pw-auth check dom --url http://my-site.local/wp-admin/ --selector "#wpadminbar"
```

**Prevention**

- For long-running test sessions, add `--force` to your login step in CI pipelines so each run starts with a fresh session.
- Use `pw-auth doctor` before starting any test session to catch stale auth early:
  ```bash
  pw-auth doctor --site-url http://my-site.local --wp-cli "local-wp my-site"
  ```
- Schedule fresh logins at the start of each work session rather than relying on cached state from the day before.

---

### 1.2 Re-authentication Loop

**Problem**

`pw-auth login` completes but immediately reports the session as invalid on the next command. Running login again has no effect.

```
✓ Login successful — session cached
✗ Error: auth_required (on next command)
```

**Root Cause**

Three common causes:

1. **Cookie domain mismatch** — the site URL used during login does not match the URL used for DOM checks (e.g., `http://my-site.local` vs `https://my-site.local` or `my-site.local:8080`).
2. **WordPress `FORCE_SSL_ADMIN` is `true`** — login succeeds over HTTP but subsequent requests are redirected to HTTPS, which the cached cookies do not cover.
3. **Conflicting `COOKIE_DOMAIN` constant** — a hardcoded `define('COOKIE_DOMAIN', '...')` in `wp-config.php` does not match the domain being tested.

**Diagnostic Steps**

1. Verify the site URL used at login exactly matches the URL in subsequent commands:
   ```bash
   # These must be identical
   pw-auth login --site-url http://my-site.local ...
   pw-auth check dom --url http://my-site.local/wp-admin/ ...
   ```

2. Check for SSL admin enforcement:
   ```bash
   local-wp my-site wp eval "echo defined('FORCE_SSL_ADMIN') && FORCE_SSL_ADMIN ? 'SSL enforced' : 'no SSL';"
   ```

3. Check `COOKIE_DOMAIN`:
   ```bash
   local-wp my-site wp eval "echo defined('COOKIE_DOMAIN') ? COOKIE_DOMAIN : '(not set)';"
   ```

4. Inspect the cookies in the auth file:
   ```bash
   cat temp/playwright/.auth/admin.json | python3 -m json.tool | grep -A5 '"domain"'
   ```
   Verify all cookie domains match the URL you are using.

**Solution**

Use the exact URL that WordPress expects for admin access:

```bash
# If FORCE_SSL_ADMIN is true, use https://
pw-auth login --site-url https://my-site.local --wp-cli "local-wp my-site" --force

# If COOKIE_DOMAIN is set to a different value, match it exactly
pw-auth login --site-url http://www.my-site.local --wp-cli "local-wp my-site"
```

To disable `FORCE_SSL_ADMIN` in a local dev environment, add to `wp-config.php`:

```php
define( 'FORCE_SSL_ADMIN', false );
```

**Prevention**

- Standardize on one URL scheme (HTTP or HTTPS) for all local dev work and never mix them in the same session.
- Use `pw-auth doctor` to detect domain mismatches before running tests.
- If using `COOKIE_DOMAIN`, ensure it is set to `''` (empty string) in local development to avoid restrictions.

---

### 1.3 Auth State Missing After Login

**Problem**

`pw-auth login` reports success but no file appears at `temp/playwright/.auth/admin.json`.

```
✓ Login successful
$ ls temp/playwright/.auth/
ls: cannot access 'temp/playwright/.auth/': No such file or directory
```

**Root Cause**

The `temp/` directory does not exist or is not writable. `pw-auth` writes the auth state only if it can create the target directory. On first use, the directory tree `temp/playwright/.auth/` must be created.

A secondary cause is a race condition when multiple `pw-auth` processes run simultaneously and each tries to create the directory at the same time.

**Diagnostic Steps**

1. Check whether the `temp/` directory exists and is writable:
   ```bash
   ls -la temp/ 2>&1 || echo "temp/ does not exist"
   ```

2. Check the process has write access:
   ```bash
   touch temp/test-write && echo "writable" && rm temp/test-write
   ```

3. Look for error output from the login command with verbose mode:
   ```bash
   pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site" --format json 2>&1
   ```

**Solution**

Create the directory manually and retry:

```bash
mkdir -p temp/playwright/.auth
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"
```

If you are running in CI, add the directory creation step before login:

```yaml
- name: Prepare auth directory
  run: mkdir -p temp/playwright/.auth

- name: Login to WordPress
  run: pw-auth login --site-url $WP_URL --wp-cli "local-wp $WP_SITE"
```

**Prevention**

- Add `temp/playwright/.auth/` to your repository `.gitkeep` pattern so the directory always exists.
- Add `temp/playwright/.auth/*.json` (but not the directory itself) to `.gitignore` to prevent committing auth state.
- The recommended `.gitignore` entries:
  ```
  temp/playwright/.auth/
  ```

---

## 2. Playwright Issues

`pw-auth` uses Playwright under the hood. All Playwright diagnostics apply.

---

### 2.1 Browser Launch Failure

**Problem**

`pw-auth login` or `pw-auth doctor` fails with a browser launch error:

```
Error: Failed to launch chromium because executable doesn't exist at ...
browserType.launch: Executable doesn't exist at /path/to/chromium
```

or

```
Error: Cannot find module 'playwright-core'
```

**Root Cause**

Playwright browsers are installed separately from the Playwright npm package. The `playwright install` command must be run to download browser binaries. If Playwright itself is missing, the npm package was not installed globally or is not on `NODE_PATH`.

**Diagnostic Steps**

1. Run the readiness check:
   ```bash
   pw-auth doctor --site-url http://my-site.local --wp-cli "local-wp my-site"
   ```
   The doctor command checks Node.js, Playwright resolution, browser availability, and launch readiness in sequence.

2. Check if Playwright is installed globally:
   ```bash
   command -v playwright
   npx playwright --version 2>/dev/null || echo "not found via npx"
   node -e "require('playwright')" 2>&1
   ```

3. Check installed browsers:
   ```bash
   playwright install --dry-run 2>/dev/null || npx playwright install --dry-run
   ```

4. Check `NODE_PATH`:
   ```bash
   echo $NODE_PATH
   node -e "console.log(require.resolve.paths('playwright'))"
   ```

**Solution**

Install Playwright and its browsers:

```bash
# If Playwright is installed globally
playwright install chromium

# If using npx
npx playwright install chromium

# If NODE_PATH is not set
export NODE_PATH="$(npm root -g)"
playwright install chromium
```

To install all browsers:

```bash
playwright install
```

For CI environments, install only the required browser to save time:

```bash
playwright install --with-deps chromium
```

**Prevention**

- Run `pw-auth doctor` as the first step of any testing workflow.
- In CI, pin Playwright version and run `playwright install --with-deps chromium` in the setup job.
- Set `NODE_PATH` permanently in your shell profile:
  ```bash
  echo 'export NODE_PATH="$(npm root -g)"' >> ~/.zshrc
  ```

---

### 2.2 Navigation or Action Timeout

**Problem**

A Playwright navigation or action times out:

```
TimeoutError: page.goto: Timeout 30000ms exceeded.
TimeoutError: locator.click: Timeout 30000ms exceeded waiting for selector '#save-button'
```

**Root Cause**

Common causes:

1. **Site is not running** — LocalWP site is stopped or its web server has crashed.
2. **Network routing issue** — the `.local` domain is not resolving, or the host entry is missing.
3. **Slow server** — WordPress is loading many plugins or executing slow database queries.
4. **JavaScript errors blocking navigation** — a JS error prevents the DOM from loading fully.
5. **Selector is correct but element loads asynchronously** — the element appears after the default timeout.

**Diagnostic Steps**

1. Verify the site is reachable from the terminal:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://my-site.local/
   # Should return 200
   ```

2. Check DNS resolution:
   ```bash
   nslookup my-site.local 2>/dev/null || ping -c1 my-site.local
   ```

3. Check LocalWP site status:
   ```bash
   local-wp my-site wp option get siteurl
   ```

4. Test with a longer timeout using the Playwright CLI directly:
   ```bash
   node -e "
   const { chromium } = require('playwright');
   (async () => {
     const b = await chromium.launch();
     const p = await b.newPage();
     await p.goto('http://my-site.local/', { timeout: 60000 });
     console.log(await p.title());
     await b.close();
   })();
   "
   ```

5. Check WordPress error log for server-side errors:
   ```bash
   local-wp my-site wp eval "echo WP_CONTENT_DIR . '/debug.log';" | xargs tail -50
   ```

**Solution**

For a stopped site, start it via LocalWP.

For timeout issues, increase the timeout by passing a custom timeout to the underlying command. For `pw-auth check dom`:

```bash
pw-auth check dom \
  --url http://my-site.local/wp-admin/ \
  --selector "#wpadminbar" \
  --timeout 60000
```

For DNS issues on macOS:

```bash
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
```

For slow WordPress environments, disable unnecessary plugins for testing:

```bash
local-wp my-site wp plugin deactivate --all --skip-plugins woocommerce jetpack
```

**Prevention**

- Always run `curl -I http://my-site.local/` before starting a Playwright session.
- Keep test WordPress installations lean (minimal plugins).
- Use `pw-auth doctor` which validates site reachability before attempting login.
- For CI, add a health check step:
  ```bash
  timeout 30 bash -c 'until curl -sf http://my-site.local/; do sleep 1; done'
  ```

---

### 2.3 DOM Selector Not Found

**Problem**

`pw-auth check dom` returns `not_found`:

```json
{ "status": "not_found", "selector": "#my-custom-element", "url": "http://my-site.local/my-page" }
```

or a Playwright script throws:

```
Error: strict mode violation: locator('#my-element') resolved to 2 elements
```

**Root Cause**

1. **Wrong page** — the selector exists on a different page than the one navigated to.
2. **Selector is inside an iframe** — Playwright does not pierce iframes by default.
3. **Element loads asynchronously** — the DOM check runs before JavaScript has injected the element.
4. **Theme or plugin conflict** — the element is present in one theme but not another.
5. **Strict mode violation** — the selector matches more than one element.

**Diagnostic Steps**

1. Verify the selector against the live page using browser DevTools (open the page in Chrome, press F12, use `document.querySelector('#my-element')`).

2. Check whether the element is inside an iframe:
   ```bash
   # Use pw-auth check dom to extract the outer HTML
   pw-auth check dom \
     --url http://my-site.local/my-page \
     --selector "iframe" \
     --extract html
   ```

3. Check whether the element requires JavaScript to render. Navigate to the page with JS disabled and see if the element is present in the initial HTML:
   ```bash
   curl -s http://my-site.local/my-page | grep -c 'my-custom-element'
   ```

4. Dump all matching elements to check for duplicates:
   ```bash
   node -e "
   const { chromium } = require('playwright');
   (async () => {
     const b = await chromium.launch();
     const ctx = await b.newContext({ storageState: 'temp/playwright/.auth/admin.json' });
     const p = await ctx.newPage();
     await p.goto('http://my-site.local/my-page');
     const count = await p.locator('#my-element').count();
     console.log('count:', count);
     await b.close();
   })();
   "
   ```

**Solution**

For async elements, use `waitForSelector`:

```javascript
await page.waitForSelector('#my-element', { timeout: 10000 });
```

For iframes, scope the locator to the frame:

```javascript
const frame = page.frameLocator('iframe#my-frame');
await frame.locator('#my-element').waitFor();
```

For strict mode violations (multiple elements), use `.first()` or a more specific selector:

```javascript
await page.locator('#my-element').first().click();
// Or use a more specific selector:
await page.locator('.container #my-element').click();
```

For `pw-auth check dom`, combine with `--extract` to get diagnostics:

```bash
pw-auth check dom \
  --url http://my-site.local/my-page \
  --selector ".entry-content" \
  --extract html \
  --user admin
```

**Prevention**

- Prefer stable selectors: `data-testid`, `aria-label`, or `id` over fragile CSS class selectors.
- Document which selectors are used in tests and verify them after theme/plugin updates.
- Use `pw-auth doctor` to validate the full workflow before relying on selectors in automated tests.

---

## 3. WordPress Environment Issues

---

### 3.1 Production Environment Block

**Problem**

`pw-auth login` fails with:

```
Error: This tool is disabled on production environments.
WP_ENVIRONMENT_TYPE is set to 'production'. pw-auth requires a development, staging, or local environment.
```

**Root Cause**

`pw-auth` checks `WP_ENVIRONMENT_TYPE` (set in `wp-config.php` or via an environment variable) before generating a one-time login URL. This is a safety guard: generating passwordless login links on production is a security risk.

**Diagnostic Steps**

1. Check the current environment type:
   ```bash
   local-wp my-site wp eval "echo wp_get_environment_type();"
   ```

2. Check `wp-config.php` for the constant:
   ```bash
   local-wp my-site wp eval "echo defined('WP_ENVIRONMENT_TYPE') ? WP_ENVIRONMENT_TYPE : '(not set)';"
   ```

3. Check if the environment variable is set at the shell level:
   ```bash
   echo $WP_ENVIRONMENT_TYPE
   ```

**Solution**

Set `WP_ENVIRONMENT_TYPE` to `local` or `development` in `wp-config.php`:

```php
define( 'WP_ENVIRONMENT_TYPE', 'local' );
```

Or use the WP-CLI config approach:

```bash
local-wp my-site wp config set WP_ENVIRONMENT_TYPE local
```

For a Local by Flywheel site, you can also set it in the site's PHP configuration. Once set, verify:

```bash
local-wp my-site wp eval "echo wp_get_environment_type();"
# Should output: local
```

Then retry the login:

```bash
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"
```

> **Important**: Never set `WP_ENVIRONMENT_TYPE` to `local` or `development` on a real production server. This constant is a security guard that prevents `dev-login-cli.php` from operating in production.

**Prevention**

- Always set `WP_ENVIRONMENT_TYPE` when configuring a new local development site.
- Add a `pw-auth doctor` step early in your workflow — it checks `WP_ENVIRONMENT_TYPE` and reports a clear error before any login is attempted.
- Use different `wp-config.php` files for different environments (`wp-config-local.php`, `wp-config-staging.php`) and never deploy the dev config to production.

---

### 3.2 WP-CLI Permission Denied

**Problem**

WP-CLI commands fail with permission errors:

```
Error: This script must not be run as root.
```

or

```
Error: PCLZIP_ERR_BAD_FORMAT (-10): Unable to open archive '...' in reading
PHP Fatal error: Uncaught Error: Call to a member function get_results() on null
```

**Root Cause**

WP-CLI requires the same file owner as the WordPress installation. Running `wp` as `root` when WordPress files are owned by a different user (e.g., `www-data` or the Local by Flywheel user) causes WordPress's file system operations to fail. Similarly, running as a non-root user without read/write access to the WordPress directory causes failures.

**Diagnostic Steps**

1. Check the owner of the WordPress installation:
   ```bash
   local-wp my-site wp eval "echo get_home_path();" | xargs ls -la
   ```

2. Check the current user:
   ```bash
   whoami
   id
   ```

3. Test WP-CLI with the `--allow-root` flag (only for debugging, never for production):
   ```bash
   local-wp my-site wp option get siteurl --allow-root
   ```

4. For Local by Flywheel, check the configured PHP version and its process owner:
   ```bash
   local-wp my-site wp eval "echo PHP_SAPI . ' / ' . get_current_user();"
   ```

**Solution**

Run WP-CLI as the file owner. For Local by Flywheel, the `local-wp` wrapper handles this automatically through the LocalWP PHP binary. If you are running `wp` directly:

```bash
# Run as the WordPress file owner
sudo -u www-data wp option get siteurl --path=/path/to/wordpress

# Or switch user
su - www-data -c "wp option get siteurl --path=/path/to/wordpress"
```

For Local by Flywheel sites, always use the `local-wp` wrapper instead of calling `wp` directly:

```bash
# Correct: uses LocalWP's PHP and proper permissions
local-wp my-site wp option get siteurl

# Incorrect: uses system PHP and may have permission issues
wp option get siteurl --path=/path/to/local/site
```

**Prevention**

- Always use `local-wp <site-name> wp ...` for Local by Flywheel sites instead of calling `wp` directly.
- Add your user to the `www-data` group (Linux) to avoid permission issues in non-Local environments.
- For shared team environments, ensure consistent file ownership conventions are documented.

---

### 3.3 dev-login-cli.php Not Installed

**Problem**

`pw-auth login` fails with:

```
Error: WP-CLI command 'dev-login create' not found.
Error: The 'dev-login' command is not registered.
```

**Root Cause**

`pw-auth` relies on a custom WP-CLI command registered by `dev-login-cli.php` (a mu-plugin). If the mu-plugin is not installed, the `dev-login create` WP-CLI command does not exist and `pw-auth` cannot generate a one-time login URL.

**Diagnostic Steps**

1. Check if the mu-plugin exists:
   ```bash
   local-wp my-site wp eval "echo WPMU_PLUGIN_DIR;" | xargs ls -la | grep dev-login
   ```

2. Check if the command is registered:
   ```bash
   local-wp my-site wp help dev-login
   ```
   If this returns an error, the mu-plugin is not installed.

3. List all mu-plugins:
   ```bash
   local-wp my-site wp plugin list --mu
   ```

**Solution**

Install the `dev-login-cli.php` mu-plugin:

1. Locate the plugin in the AI-DDTK repo:
   ```bash
   find ~/bin/ai-ddtk -name "dev-login-cli.php" 2>/dev/null
   ```

2. Copy it to the mu-plugins directory:
   ```bash
   MU_PLUGIN_DIR=$(local-wp my-site wp eval "echo WPMU_PLUGIN_DIR;")
   cp ~/bin/ai-ddtk/templates/dev-login-cli.php "$MU_PLUGIN_DIR/"
   ```

3. Verify the command is now available:
   ```bash
   local-wp my-site wp dev-login create admin --porcelain
   ```

4. Retry login:
   ```bash
   pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"
   ```

> **Security note**: `dev-login-cli.php` includes a guard that checks `WP_ENVIRONMENT_TYPE`. It will refuse to operate on production environments regardless of how it is called.

**Prevention**

- Add `dev-login-cli.php` installation to your site setup checklist.
- Use `pw-auth doctor` as part of site setup — it validates mu-plugin presence and reports a clear error if it is missing.
- For team environments, automate mu-plugin installation in your site provisioning script.

---

## 4. Database Connectivity Issues

---

### 4.1 MySQL Connection Refused

**Problem**

WP-CLI database commands fail:

```
Error: Error establishing a database connection.
Error: Connection refused (ECONNREFUSED 127.0.0.1:3306)
```

or WordPress shows "Error Establishing a Database Connection" in the browser.

**Root Cause**

The MySQL or MariaDB server is not running, or the socket/port the server is listening on does not match what WordPress is configured to use. For Local by Flywheel sites, each site has its own MySQL instance that must be started via LocalWP.

**Diagnostic Steps**

1. Check if MySQL is running:
   ```bash
   # macOS (Homebrew)
   brew services list | grep mysql
   # Linux
   systemctl status mysql 2>/dev/null || service mysql status
   # Local by Flywheel (check site-specific MySQL)
   local-wp my-site wp db check
   ```

2. Test the database connection directly:
   ```bash
   local-wp my-site wp db query "SELECT 1;"
   ```

3. Check the WordPress database credentials:
   ```bash
   local-wp my-site wp eval "
   global \$wpdb;
   echo 'Host: ' . DB_HOST . PHP_EOL;
   echo 'User: ' . DB_USER . PHP_EOL;
   echo 'DB: ' . DB_NAME . PHP_EOL;
   "
   ```

4. For Local by Flywheel, verify the site's MySQL socket:
   ```bash
   local-wp my-site wp eval "echo DB_HOST;"
   # Often something like: localhost:/path/to/mysql.sock
   ```

**Solution**

Start the MySQL server:

```bash
# macOS (Homebrew)
brew services start mysql@8.0

# Linux
sudo systemctl start mysql

# Local by Flywheel (start via the LocalWP app or CLI)
# Open LocalWP and start the site, then retry
```

For Local by Flywheel with a socket mismatch, ensure you are using the `local-wp` wrapper which sets the correct socket path automatically.

For a connection issue caused by incorrect credentials, reset the WordPress DB credentials:

```bash
local-wp my-site wp config set DB_PASSWORD 'new-password'
local-wp my-site wp db check
```

**Prevention**

- Always start LocalWP sites through the LocalWP app before running WP-CLI commands.
- Add a DB connectivity check at the start of automation scripts:
  ```bash
  local-wp my-site wp db check || { echo "DB not available"; exit 1; }
  ```
- For CI, use a health check that waits for MySQL to be ready before running tests.

---

### 4.2 WP-CLI Database Command Fails

**Problem**

WP-CLI runs but specific database operations fail:

```
Error: Table 'wp_options' doesn't exist
Error: Access denied for user 'wp_user'@'localhost' to database 'my_db'
```

**Root Cause**

1. **Missing tables** — WordPress database was not installed or the table prefix is wrong.
2. **Insufficient privileges** — the MySQL user does not have `SELECT`, `INSERT`, `UPDATE`, or `DELETE` privileges on the WordPress database.
3. **Wrong table prefix** — `$table_prefix` in `wp-config.php` does not match the actual table names.

**Diagnostic Steps**

1. Check the table prefix:
   ```bash
   local-wp my-site wp eval "global \$wpdb; echo \$wpdb->prefix;"
   ```

2. List existing tables:
   ```bash
   local-wp my-site wp db tables
   ```

3. Check MySQL user privileges:
   ```bash
   local-wp my-site wp db query "SHOW GRANTS FOR CURRENT_USER();"
   ```

4. Attempt a WordPress install/reinstall if tables are missing:
   ```bash
   local-wp my-site wp core is-installed && echo "installed" || echo "not installed"
   ```

**Solution**

For missing tables, run the WordPress install:

```bash
local-wp my-site wp core install \
  --url=http://my-site.local \
  --title="My Site" \
  --admin_user=admin \
  --admin_password=password \
  --admin_email=admin@example.com
```

For privilege issues, grant the correct privileges (requires MySQL root access):

```bash
local-wp my-site wp db query \
  "GRANT ALL PRIVILEGES ON my_db.* TO 'wp_user'@'localhost'; FLUSH PRIVILEGES;"
```

For a wrong table prefix, update `wp-config.php`:

```bash
local-wp my-site wp config set table_prefix wp_
```

**Prevention**

- Verify `wp core is-installed` returns true before running any WP-CLI automation.
- Document the table prefix in site setup notes to avoid prefix mismatches.

---

### 4.3 Slow Queries Causing Timeouts

**Problem**

WP-CLI commands or Playwright tests that make database queries take longer than expected or time out.

```
Error: Request timed out after 30000ms
```

Or WPCC flags N+1 query patterns.

**Root Cause**

1. **Missing indexes** — queries are doing full table scans.
2. **N+1 queries inside loops** — a loop that queries the database once per iteration is a common WordPress performance issue.
3. **Slow transients or options table** — the `wp_options` table can become a bottleneck with many autoloaded options.
4. **WP_DEBUG causing overhead** — debug logging adds significant overhead.

**Diagnostic Steps**

1. Enable query logging temporarily:
   ```bash
   local-wp my-site wp eval "
   define('SAVEQUERIES', true);
   // Trigger the slow operation
   global \$wpdb;
   \$wpdb->show_errors();
   do_action('init');
   echo count(\$wpdb->queries) . ' queries';
   "
   ```

2. Check the size of the `wp_options` table:
   ```bash
   local-wp my-site wp db query \
     "SELECT COUNT(*) FROM wp_options WHERE autoload='yes';"
   ```

3. Run WPCC to identify N+1 patterns in your code:
   ```bash
   wpcc --paths /path/to/plugin --format json | python3 -m json.tool | grep -i "n+1\|loop.*query"
   ```

4. Use WP Performance Timer for specific code paths (see `recipes/performance-audit.md`).

**Solution**

For autoload bloat in `wp_options`:

```bash
local-wp my-site wp option list --autoload=yes --format=csv | \
  awk -F',' '{print length($2), $1}' | sort -rn | head -20
```

Then deactivate or fix plugins that are autoloading large values.

For N+1 queries, cache results outside the loop:

```php
// Before: N+1 queries
foreach ( $post_ids as $id ) {
    $meta = get_post_meta( $id, 'my_key', true ); // 1 query per iteration
}

// After: single query
$posts = get_posts( [ 'post__in' => $post_ids, 'update_post_meta_cache' => true ] );
foreach ( $posts as $post ) {
    $meta = get_post_meta( $post->ID, 'my_key', true ); // uses cache
}
```

**Prevention**

- Run WPCC as part of code review to catch N+1 patterns before they reach production.
- Monitor autoloaded options count after major plugin updates.
- Keep `WP_DEBUG_LOG` disabled in testing environments unless actively debugging.

---

## 5. MCP Server Issues

---

### 5.1 MCP Server Fails to Start

**Problem**

The MCP server does not start or the editor cannot connect to it:

```
Error: spawn node ENOENT
Error: MCP server process exited with code 1
Error: Cannot find module '/path/to/ai-ddtk/tools/mcp-server/dist/src/index.js'
```

**Root Cause**

1. **Server not built** — the TypeScript source has not been compiled to JavaScript. The `dist/` directory is missing or out of date.
2. **Node.js not found** — the `node` binary is not on the system PATH used by the editor.
3. **Dependencies not installed** — `node_modules` in `tools/mcp-server/` is missing.

**Diagnostic Steps**

1. Check the install status:
   ```bash
   cd ~/bin/ai-ddtk && ./install.sh status
   ```

2. Verify the built server file exists:
   ```bash
   ls -la ~/bin/ai-ddtk/tools/mcp-server/dist/src/index.js
   ```

3. Check Node.js availability:
   ```bash
   node --version
   which node
   ```

4. Check for build errors in the MCP server:
   ```bash
   cd ~/bin/ai-ddtk/tools/mcp-server && npm install && npm run build 2>&1
   ```

5. Test the server manually:
   ```bash
   node ~/bin/ai-ddtk/tools/mcp-server/dist/src/index.js 2>&1 | head -5
   ```

**Solution**

Run the full MCP setup:

```bash
cd ~/bin/ai-ddtk
./install.sh setup-mcp
./install.sh status
```

If the build fails, run it manually with verbose output:

```bash
cd ~/bin/ai-ddtk/tools/mcp-server
npm install
npm run build
```

If Node.js is not on PATH when launched from the editor, use the full path in the MCP configuration:

```json
{
  "mcpServers": {
    "ai-ddtk": {
      "command": "/usr/local/bin/node",
      "args": ["/Users/you/bin/ai-ddtk/tools/mcp-server/dist/src/index.js"]
    }
  }
}
```

Find the correct Node.js path with:

```bash
which node
# or for nvm users:
nvm which current
```

**Prevention**

- Run `./install.sh status` at the start of each work session.
- After updating AI-DDTK, always run `./install.sh setup-mcp` to rebuild the server.
- Use the full absolute path to `node` in your MCP configuration to avoid PATH issues.

---

### 5.2 MCP Tool Calls Return Errors

**Problem**

MCP tool calls succeed (the editor communicates with the server) but the tool itself returns an error:

```json
{ "error": "Site not selected. Call local_wp_select_site first." }
{ "error": "WPCC binary not found at ~/bin/ai-ddtk/bin/wpcc" }
{ "error": "Auth state not found for user 'admin'" }
```

**Root Cause**

MCP tools have prerequisites that must be satisfied before they are called:

1. `local_wp_*` tools require a site to be selected first with `local_wp_select_site`.
2. `wpcc_*` tools require the `wpcc` binary to be installed and on PATH.
3. `pw_auth_*` tools require that `pw-auth login` has been called first to cache the auth state.

**Diagnostic Steps**

1. For LocalWP errors, list sites and select one:
   ```
   MCP tool: local_wp_list_sites
   MCP tool: local_wp_select_site { "siteName": "my-site" }
   ```

2. For WPCC errors, verify the binary:
   ```bash
   command -v wpcc
   wpcc --version
   ```

3. For pw-auth errors, check auth status:
   ```bash
   pw-auth status
   ```

4. Enable MCP server logging if available (see `tools/mcp-server/README.md`).

**Solution**

Follow the prerequisite order for each tool group:

**LocalWP tools:**
```
1. local_wp_list_sites
2. local_wp_select_site { "siteName": "my-site" }
3. local_wp_run { "command": "wp option get siteurl" }
```

**WPCC tools:**
```bash
# Ensure wpcc is installed
cd ~/bin/ai-ddtk && ./install.sh setup-wpcc
# Then:
wpcc_run_scan { "paths": ["/path/to/plugin"] }
```

**pw-auth tools:**
```bash
# Login first via shell
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"
# Then MCP tools will use the cached state
pw_auth_status {}
```

**Prevention**

- Establish site context at the beginning of each AI agent session by calling `local_wp_list_sites` and `local_wp_select_site`.
- Include an auth step in your AI agent system prompt or task instructions.
- Use `local_wp_test_connectivity` to verify a site is reachable before running tools against it.

---

### 5.3 MCP Server Not Discovered by Editor

**Problem**

The editor (Claude Code, Augment Code, Claude Desktop, Cline) does not show AI-DDTK tools in the MCP tools list.

**Root Cause**

1. **`.mcp.json` not found** — the configuration file is missing or in the wrong directory.
2. **Configuration syntax error** — invalid JSON in the MCP configuration file.
3. **Editor needs restart** — MCP discovery happens at editor startup; changes to configuration require a restart.
4. **Wrong configuration path** — each editor reads MCP configuration from a different location.

**Diagnostic Steps**

1. Check whether `.mcp.json` exists in the project root:
   ```bash
   cat .mcp.json
   ```

2. Validate the JSON syntax:
   ```bash
   python3 -m json.tool .mcp.json && echo "valid JSON"
   ```

3. Check editor-specific configuration paths:

   | Editor | Config location |
   |--------|-----------------|
   | Claude Code (VS Code) | `.mcp.json` in project root (auto-discovered) |
   | Augment Code | `~/.augment/settings.json` under `mcpServers` |
   | Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` |
   | Cline (VS Code) | VS Code settings: Cline → MCP Servers → Edit Config |

4. Check for errors in the editor's developer console (Help → Developer Tools in VS Code).

**Solution**

Verify your `.mcp.json` structure matches the required format:

```json
{
  "mcpServers": {
    "ai-ddtk": {
      "command": "node",
      "args": ["tools/mcp-server/dist/src/index.js"],
      "cwd": "/Users/you/bin/ai-ddtk"
    }
  }
}
```

For Augment Code, add to `~/.augment/settings.json`:

```json
{
  "mcpServers": {
    "ai-ddtk": {
      "command": "node",
      "args": ["/Users/you/bin/ai-ddtk/tools/mcp-server/dist/src/index.js"],
      "cwd": "/Users/you/bin/ai-ddtk"
    }
  }
}
```

After updating any MCP configuration, restart the editor completely (not just reload the window).

**Prevention**

- Run `./install.sh setup-mcp` after cloning AI-DDTK; it writes the correct `.mcp.json` for Claude Code automatically.
- Copy the appropriate template from `tools/mcp-server/mcp-configs/` for your editor rather than writing the configuration from scratch.
- After any AI-DDTK update, run `./install.sh status` to verify the MCP server configuration is current.

---

## 6. Performance Issues

---

### 6.1 Slow Test Execution

**Problem**

Playwright tests or `pw-auth` commands take significantly longer than expected (30+ seconds for simple operations).

**Root Cause**

1. **WordPress loads many plugins** — each HTTP request triggers all plugin initialization code.
2. **Playwright launches a new browser for each test** — browser launch takes 2–5 seconds per test.
3. **No caching** — running without persistent Playwright browser context means cookies and session storage are reset each time.
4. **Site is on an HDD** — local WordPress sites on spinning disks load noticeably slower than SSDs.
5. **Too many autoloaded options** — see [4.3 Slow Queries Causing Timeouts](#43-slow-queries-causing-timeouts).

**Diagnostic Steps**

1. Time a simple HTTP request to the site:
   ```bash
   time curl -s -o /dev/null http://my-site.local/
   ```
   If this takes more than 2 seconds, the problem is WordPress-side, not Playwright.

2. Check how many plugins are active:
   ```bash
   local-wp my-site wp plugin list --status=active --format=count
   ```

3. Test with a minimal plugin set:
   ```bash
   local-wp my-site wp plugin deactivate --all --skip-plugins my-plugin-under-test
   time curl -s -o /dev/null http://my-site.local/
   ```

4. Profile WordPress startup time with Query Monitor or WP Performance Timer (see `recipes/performance-audit.md`).

**Solution**

Reuse the Playwright browser context across tests using the cached auth state:

```javascript
const { chromium } = require('playwright');

// Launch once, reuse the context
const browser = await chromium.launch();
const context = await browser.newContext({
  storageState: 'temp/playwright/.auth/admin.json' // reuse auth
});

// Run multiple page operations
const page1 = await context.newPage();
await page1.goto('http://my-site.local/wp-admin/');

const page2 = await context.newPage();
await page2.goto('http://my-site.local/wp-admin/plugins.php');

await browser.close();
```

Deactivate unnecessary plugins for the test environment:

```bash
local-wp my-site wp plugin deactivate \
  jetpack woocommerce wordfence \
  --skip-plugins my-plugin-under-test
```

**Prevention**

- Maintain a minimal "test" plugin set and a separate "full" plugin set. Run tests against the minimal set.
- Use `pw-auth login` once at the start of a test session; do not re-authenticate for each test.
- Consider using a dedicated test WordPress installation with only the plugins required for the test.

---

### 6.2 pw-auth Login Takes Too Long

**Problem**

`pw-auth login` takes more than 10 seconds, or times out:

```
Waiting for login to complete...
Error: Timeout: login page did not redirect within 30000ms
```

**Root Cause**

1. **WordPress login page is slow** — heavy plugins, slow database, or large uploads during login.
2. **One-time URL expires** — the one-time login URL has a 5-minute TTL. If the network or Playwright is slow, the URL may be consumed too slowly.
3. **WordPress admin redirect chain** — some security plugins add redirect chains that slow down login.
4. **Node.js or Playwright startup overhead** — first run is slower due to JIT compilation.

**Diagnostic Steps**

1. Time the WordPress login page directly:
   ```bash
   time curl -s -o /dev/null -c /tmp/cookies.txt \
     -d "log=admin&pwd=password&wp-submit=Log+In&redirect_to=/wp-admin/" \
     http://my-site.local/wp-login.php
   ```

2. Check if security plugins are adding redirects:
   ```bash
   curl -I http://my-site.local/wp-login.php 2>&1 | grep -i location
   ```

3. Time the one-time URL generation:
   ```bash
   time local-wp my-site wp dev-login create admin --porcelain
   ```

**Solution**

Increase the login timeout:

```bash
pw-auth login \
  --site-url http://my-site.local \
  --wp-cli "local-wp my-site" \
  --timeout 60000
```

Disable security plugins that add redirect chains for local dev:

```bash
local-wp my-site wp plugin deactivate wordfence sucuri-scanner all-in-one-wp-security
```

If the WordPress login page itself is slow, profile it:

```bash
local-wp my-site wp eval "
\$start = microtime(true);
require_once ABSPATH . 'wp-login.php';
echo 'Time: ' . round((microtime(true) - \$start) * 1000) . 'ms';
" 2>/dev/null
```

**Prevention**

- Keep security plugins deactivated in the local development environment.
- Warm up the WordPress site with a curl request before running `pw-auth login` in CI:
  ```bash
  curl -s -o /dev/null http://my-site.local/ && pw-auth login ...
  ```
- Use the cached auth state instead of logging in for every test run.

---

### 6.3 WPCC Scan Timeout

**Problem**

`wpcc` scans a large codebase and either times out or uses excessive memory:

```
Error: WPCC scan exceeded time limit
Error: JavaScript heap out of memory
```

**Root Cause**

1. **Scanning too many files** — pointing `--paths` at the entire WordPress installation includes core files, all plugins, and all themes.
2. **Recursive scanning of `node_modules` or `vendor`** — these directories contain thousands of files.
3. **Memory limit** — the default Node.js memory limit (512MB) is exceeded on very large codebases.

**Diagnostic Steps**

1. Count the files that will be scanned:
   ```bash
   find /path/to/scan -name "*.php" -not -path "*/node_modules/*" -not -path "*/vendor/*" | wc -l
   ```

2. Check whether a `.wpcignore` file exists:
   ```bash
   cat .wpcignore 2>/dev/null || echo "no .wpcignore"
   ```

3. Run with `--verbose` to see per-file timing:
   ```bash
   wpcc --paths /path/to/plugin --format json --verbose 2>&1 | head -50
   ```

**Solution**

Scope the scan to only the code you own:

```bash
# Scan a specific plugin only
wpcc --paths ~/wp-content/plugins/my-plugin --format json

# Exclude vendor and build directories
wpcc --paths ~/wp-content/plugins/my-plugin --exclude vendor,node_modules,dist
```

Use `.wpcignore` to permanently exclude directories:

```
node_modules/
vendor/
dist/
*.min.js
*.min.css
tests/
```

Increase Node.js memory for very large scans:

```bash
NODE_OPTIONS="--max-old-space-size=2048" wpcc --paths /path/to/large-plugin
```

**Prevention**

- Always scope `--paths` to the specific plugin or theme you are working on, not the entire WordPress installation.
- Add a `.wpcignore` file to your project to permanently exclude generated/vendor directories.
- Run WPCC incrementally on changed files in CI rather than scanning the entire codebase on every commit.

---

## 7. Quick Reference: Exit Codes

| Exit Code | Tool | Meaning |
|-----------|------|---------|
| `0` | All | Success |
| `1` | `pw-auth login` | Login failed (check `--format json` for details) |
| `1` | `pw-auth doctor` | One or more readiness checks failed |
| `2` | `pw-auth check dom` | Invalid command configuration |
| `3` | `pw-auth check dom` | Element not found (`not_found` status) |
| `4` | `pw-auth check dom` | Authentication required (`auth_required` status) |
| `5` | `pw-auth check dom` | General error (`error` status) |
| `6` | `pw-auth check dom` | Assertion failure (`assertion_failed` status) |
| `1` | `wpcc` | Scan completed with findings |
| `2` | `wpcc` | Scan error (configuration or file access issue) |
| `1` | `local-wp` | WP-CLI command failed |
| `127` | Any | Command not found (check PATH and installation) |

---

## 8. Quick Reference: Diagnostic Commands

Run these commands to quickly assess the state of the AI-DDTK environment:

```bash
# --- AI-DDTK status ---
cd ~/bin/ai-ddtk && ./install.sh status
command -v wpcc pw-auth local-wp aiddtk-tmux node

# --- Site connectivity ---
local-wp my-site wp db check
local-wp my-site wp eval "echo wp_get_environment_type();"
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://my-site.local/

# --- Auth state ---
pw-auth status
pw-auth doctor --site-url http://my-site.local --wp-cli "local-wp my-site"
ls -la temp/playwright/.auth/ 2>/dev/null || echo "no auth cache"

# --- Playwright ---
node --version
playwright --version 2>/dev/null || echo "playwright not on PATH"
node -e "require('playwright'); console.log('playwright module OK')"

# --- MCP server ---
ls ~/bin/ai-ddtk/tools/mcp-server/dist/src/index.js
node ~/bin/ai-ddtk/tools/mcp-server/dist/src/index.js --version 2>&1 | head -3

# --- WordPress environment ---
local-wp my-site wp option get siteurl
local-wp my-site wp plugin list --status=active --format=count
local-wp my-site wp eval "echo defined('WP_ENVIRONMENT_TYPE') ? WP_ENVIRONMENT_TYPE : '(not set)';"
```

---

## Related Documentation

- **[CLI Reference](CLI-REFERENCE.md)** — Complete command syntax and parameters for all tools
- **[pw-auth Commands](PW-AUTH-COMMANDS.md)** — Detailed pw-auth guide
- **[WPCC Commands](WPCC-COMMANDS.md)** — Detailed WPCC guide
- **[local-wp Commands](LOCAL-WP-COMMANDS.md)** — Local by Flywheel WP-CLI wrapper guide
- **[AGENTS.md](../AGENTS.md)** — AI agent guidelines and tool overview
- **[fix-iterate-loop.md](../fix-iterate-loop.md)** — Multi-step verification and debugging workflow
- **[recipes/performance-audit.md](../recipes/performance-audit.md)** — Runtime profiling guide

---

_For issues not covered here, open a GitHub issue at [Hypercart-Dev-Tools/AI-DDTK-Fix-Iterate-Loop](https://github.com/Hypercart-Dev-Tools/AI-DDTK-Fix-Iterate-Loop/issues)._
