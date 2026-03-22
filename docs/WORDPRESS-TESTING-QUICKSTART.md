# WordPress Testing Quick Start

_Last updated: v3.0.0 — 2026-03-22_

Get from zero to a working Playwright test against a local WordPress site in about 5 minutes.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [WordPress Setup](#2-wordpress-setup)
3. [Install dev-login-cli.php](#3-install-dev-login-cliphp)
4. [Install Playwright](#4-install-playwright)
5. [Authenticate with pw-auth](#5-authenticate-with-pw-auth)
6. [Your First Test](#6-your-first-test)
7. [Common Use Cases](#7-common-use-cases)
   - [Form Submission](#71-form-submission)
   - [Navigation / Menu Check](#72-navigation--menu-check)
   - [Database Query Verification](#73-database-query-verification)
8. [Running the Example Scripts](#8-running-the-example-scripts)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites

You need the following tools installed before starting. Each install takes under a minute.

| Tool | Version | Install |
|------|---------|---------|
| **Node.js** | 18 or later | `brew install node` / [nodejs.org](https://nodejs.org) |
| **WP-CLI** | 2.x | See below |
| **Local by Flywheel** | Any | [localwp.com](https://localwp.com) — *optional, but recommended for beginners* |

**Install WP-CLI** (if not already installed):

```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
wp --info
```

---

## 2. WordPress Setup

### Option A — Local by Flywheel (recommended for beginners)

1. Download and install [Local by Flywheel](https://localwp.com).
2. Click **+ Create a new site** → name it `my-test-site`.
3. Choose any PHP/MySQL version and click **Finish Setup**.
4. Click **Start Site**. Your site URL will be something like `http://my-test-site.local`.

### Option B — Existing local install

If you already have a WordPress site running locally, note its URL (e.g. `http://localhost:8080`). Make sure it is accessible from your terminal.

### Verify your site is running

```bash
curl -s -o /dev/null -w "%{http_code}" http://my-test-site.local/
# Expected output: 200
```

### Set the environment type

`dev-login-cli.php` refuses to run in `production` mode. Add this line to `wp-config.php`:

```php
define( 'WP_ENVIRONMENT_TYPE', 'development' );
```

For Local by Flywheel you can also set it via WP-CLI:

```bash
# Local by Flywheel
local-wp my-test-site -- wp config set WP_ENVIRONMENT_TYPE development

# Standard WP-CLI (run from the WordPress root directory)
wp config set WP_ENVIRONMENT_TYPE development
```

---

## 3. Install dev-login-cli.php

`dev-login-cli.php` is a must-use plugin that lets WP-CLI generate one-time login URLs so Playwright can log in without storing a password anywhere.

```bash
# Copy the mu-plugin from AI-DDTK templates
cp ~/bin/ai-ddtk/templates/dev-login-cli.php /path/to/wordpress/wp-content/mu-plugins/

# For Local by Flywheel — use the local-wp wrapper to find the path
local-wp my-test-site -- wp eval 'echo WPMU_PLUGIN_DIR;'
# Then copy to that directory
```

### Verify it loaded

```bash
# Standard WP-CLI
wp plugin list --status=mustuse

# Local by Flywheel
local-wp my-test-site -- wp plugin list --status=mustuse
```

Expected output includes `dev-login-cli`.

### Generate a test login URL

```bash
# Standard
wp dev login --format=url

# Local by Flywheel
local-wp my-test-site -- wp dev login --format=url
```

You should see a URL like:

```
http://my-test-site.local/?dev_login=1&u=1&t=abc123...
```

Opening that URL in a browser should log you in as admin. ✅

---

## 4. Install Playwright

```bash
# Install the Playwright npm package
npm install playwright

# Install the Chromium browser (fast, ~170 MB)
npx playwright install chromium
```

> **Tip:** You can also install `@playwright/test` if you want the full test-runner experience. The examples in this guide use the core `playwright` package directly to stay beginner-friendly.

---

## 5. Authenticate with pw-auth

`pw-auth` combines steps 3 and 4: it calls WP-CLI to get a one-time login URL, navigates Playwright to that URL, and saves the resulting browser session to disk. All subsequent scripts reuse that cached session — no repeated logins.

```bash
# Standard WordPress install
pw-auth login --site-url http://my-test-site.local

# Local by Flywheel
pw-auth login --site-url http://my-test-site.local --wp-cli "local-wp my-test-site"
```

Expected output:

```
✓ Generated one-time login URL
✓ Authenticated via Playwright
✓ Saved storageState to ./temp/playwright/.auth/admin.json
```

### Check authentication status

```bash
pw-auth status
# admin.json  (8.2 KB, 0 hours old, fresh)
```

### Verify readiness before running tests

```bash
pw-auth doctor --site-url http://my-test-site.local
```

All checkmarks means you are ready to run tests.

---

## 6. Your First Test

Save this as `my-first-test.js` (anywhere in your project):

```javascript
const { chromium } = require('playwright');

(async () => {
  // 1. Launch browser
  const browser = await chromium.launch();

  // 2. Load the saved authenticated session
  const context = await browser.newContext({
    storageState: './temp/playwright/.auth/admin.json',
  });

  // 3. Open a new page and go to the WordPress dashboard
  const page = await context.newPage();
  await page.goto('http://my-test-site.local/wp-admin/');

  // 4. Verify we are logged in
  const title = await page.title();
  console.log('Page title:', title);

  if (title.includes('Dashboard')) {
    console.log('✅ Login successful — we are in the WordPress dashboard!');
  } else {
    console.error('❌ Something went wrong. Title was:', title);
    process.exit(1);
  }

  await browser.close();
})();
```

Run it:

```bash
node my-first-test.js
# Page title: Dashboard ‹ My Test Site — WordPress
# ✅ Login successful — we are in the WordPress dashboard!
```

---

## 7. Common Use Cases

### 7.1 Form Submission

Test that the WordPress comment form works end-to-end.

```javascript
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    storageState: './temp/playwright/.auth/admin.json',
  });
  const page = await context.newPage();

  // Navigate to the first post (WordPress default "Hello World")
  await page.goto('http://my-test-site.local/?p=1');

  // Fill and submit the comment form
  await page.fill('#comment', 'Test comment from Playwright');
  await page.click('#submit');

  // Wait for the comment to appear on the page
  await page.waitForSelector('.comment-body');
  const commentText = await page.textContent('.comment-body p');

  if (commentText && commentText.includes('Test comment from Playwright')) {
    console.log('✅ Comment submitted successfully');
  } else {
    console.error('❌ Comment not found');
    process.exit(1);
  }

  await browser.close();
})();
```

### 7.2 Navigation / Menu Check

Verify your WordPress navigation menu contains the expected links.

```javascript
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    storageState: './temp/playwright/.auth/admin.json',
  });
  const page = await context.newPage();

  // Go to the homepage
  await page.goto('http://my-test-site.local/');

  // Collect all navigation links
  const navLinks = await page.$$eval(
    'nav a, #site-navigation a, .nav-menu a',
    (anchors) => anchors.map((a) => ({ text: a.textContent.trim(), href: a.href }))
  );

  console.log('Navigation links found:');
  navLinks.forEach((link) => console.log(`  ${link.text} → ${link.href}`));

  if (navLinks.length > 0) {
    console.log(`✅ Found ${navLinks.length} navigation link(s)`);
  } else {
    console.warn('⚠ No navigation links found — check your theme selector');
  }

  await browser.close();
})();
```

### 7.3 Database Query Verification

Use WP-CLI to run a database query and verify the result programmatically.

**Important:** always pass SQL via `stdin` (the `input` option in `execSync`), never by interpolating it into the shell command string. This prevents shell injection when the SQL contains special characters.

```javascript
const { execSync } = require('child_process');

// Run a WP-CLI database query and capture the output.
// SQL is passed via stdin — NOT interpolated into the shell command string.
function wpQuery(sql, wpCliPrefix = 'wp') {
  try {
    const output = execSync(
      `${wpCliPrefix} db query --skip-column-names`,
      { input: sql, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
    );
    return output.trim();
  } catch (err) {
    console.error('WP-CLI query failed:', err.message);
    process.exit(1);
  }
}

// Example: verify the admin user exists
const adminExists = wpQuery("SELECT COUNT(*) FROM wp_users WHERE user_login = 'admin'");
if (adminExists === '1') {
  console.log('✅ Admin user exists in the database');
} else {
  console.error('❌ Admin user not found');
}

// Example: count published posts
const postCount = wpQuery("SELECT COUNT(*) FROM wp_posts WHERE post_status = 'publish' AND post_type = 'post'");
console.log(`✅ Published posts: ${postCount}`);

// Example: read a specific option (prefer wp option get for scalar values)
const siteUrl = execSync('wp option get siteurl', { encoding: 'utf8' }).trim();
console.log(`✅ Site URL from DB: ${siteUrl}`);
```

For **Local by Flywheel**, prefix all `wp` calls with `local-wp my-test-site --`:

```javascript
const result = wpQuery("SELECT COUNT(*) FROM wp_users", "local-wp my-test-site -- wp");
```

> **Note:** The example scripts in `examples/playwright-basics/` read `WP_CLI_PREFIX` from the environment so you can set it once rather than passing it on every call:
> ```bash
> export WP_CLI_PREFIX="local-wp my-test-site -- wp"
> ```

---

## 8. Running the Example Scripts

The `examples/playwright-basics/` directory contains ready-to-run scripts for each use case.

```bash
cd examples/playwright-basics
npm install

# Configure your site URL (edit examples/.env or pass directly)
export WP_SITE_URL=http://my-test-site.local
export WP_CLI_PREFIX=wp   # or: "local-wp my-test-site -- wp"

# Authenticate first
pw-auth login --site-url $WP_SITE_URL

# Run individual examples
node 01-setup.js
node 02-form-submission.js
node 03-menu-check.js
node 04-db-query.js
node 05-common-patterns.js

# Or run all examples at once
npm test
```

See [`examples/playwright-basics/README.md`](../examples/playwright-basics/README.md) for detailed instructions.

---

## 9. Troubleshooting

### "Dev login is disabled in production environments"

`WP_ENVIRONMENT_TYPE` is set to `production` (or missing) in `wp-config.php`.

```php
// Add this line to wp-config.php
define( 'WP_ENVIRONMENT_TYPE', 'development' );
```

---

### "dev-login-cli.php not installed"

The mu-plugin is not present. Copy it:

```bash
cp ~/bin/ai-ddtk/templates/dev-login-cli.php /path/to/wp-content/mu-plugins/
```

Then re-run `pw-auth doctor` to confirm.

---

### "User 'admin' not found"

Your WordPress install might use a different admin username. Check with WP-CLI:

```bash
wp user list --role=administrator --fields=user_login
```

Then pass the correct username:

```bash
pw-auth login --site-url http://my-test-site.local --user your-admin-username
```

---

### "Playwright not installed" / "Cannot find module 'playwright'"

```bash
# In your project directory
npm install playwright
npx playwright install chromium
```

---

### "Auth state expired" / Tests fail after idle time

The cached session in `./temp/playwright/.auth/admin.json` is 12 hours old by default. Re-authenticate:

```bash
pw-auth login --site-url http://my-test-site.local --force
```

---

### Navigation timeout or selector not found

The default timeout is 30 seconds. If your local site is slow to start:

```javascript
// Increase timeout in your script
await page.goto('http://my-test-site.local/wp-admin/', { timeout: 60000 });
await page.waitForSelector('#wpadminbar', { timeout: 60000 });
```

Or increase the Playwright default globally:

```javascript
const context = await browser.newContext({
  storageState: './temp/playwright/.auth/admin.json',
});
context.setDefaultTimeout(60000);
```

---

### Local by Flywheel — "wp: command not found"

When using Local by Flywheel, always prefix `wp` commands with `local-wp <site-name> --`:

```bash
# Wrong
wp dev login

# Correct for Local by Flywheel
local-wp my-test-site -- wp dev login
```

And when calling `pw-auth`:

```bash
pw-auth login --site-url http://my-test-site.local --wp-cli "local-wp my-test-site"
```

---

## See Also

- [PW-AUTH-COMMANDS.md](./PW-AUTH-COMMANDS.md) — Full `pw-auth` command reference
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — Advanced troubleshooting guide
- [CLI-REFERENCE.md](./CLI-REFERENCE.md) — All AI-DDTK CLI commands
- [examples/playwright-basics/README.md](../examples/playwright-basics/README.md) — Example scripts guide
