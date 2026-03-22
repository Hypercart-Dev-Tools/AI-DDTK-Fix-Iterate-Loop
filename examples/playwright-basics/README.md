# Playwright Basics — Example Scripts

_Last updated: v3.0.0 — 2026-03-22_

A collection of beginner-friendly Playwright scripts for testing WordPress sites with AI-DDTK.

---

## Prerequisites

Before running any script, complete the [Quick Start guide](../../docs/WORDPRESS-TESTING-QUICKSTART.md):

1. WordPress site running locally (Local by Flywheel or any local install)
2. `dev-login-cli.php` mu-plugin installed
3. `WP_ENVIRONMENT_TYPE` set to `development` in `wp-config.php`
4. `pw-auth` authenticated (see step 5 of the Quick Start guide)

---

## Setup

```bash
# 1. Install dependencies
npm install

# 2. Install Playwright's Chromium browser
npx playwright install chromium

# 3. Set your site URL (edit the value to match your local site)
export WP_SITE_URL=http://my-test-site.local

# 4. (Local by Flywheel only) Set your site name
export WP_CLI_PREFIX="local-wp my-test-site -- wp"

# 5. Authenticate with pw-auth
pw-auth login --site-url $WP_SITE_URL
# or for Local by Flywheel:
pw-auth login --site-url $WP_SITE_URL --wp-cli "local-wp my-test-site"
```

---

## Scripts

| File | What it tests |
|------|---------------|
| `01-setup.js` | Basic environment check and WordPress dashboard access |
| `02-form-submission.js` | WordPress comment form submission end-to-end |
| `03-menu-check.js` | Navigation menu links verification |
| `04-db-query.js` | Database content verification via WP-CLI |
| `05-common-patterns.js` | Reusable helper patterns for real-world tests |

---

## Running scripts

### Run one script at a time

```bash
node 01-setup.js
node 02-form-submission.js
node 03-menu-check.js
node 04-db-query.js
node 05-common-patterns.js
```

### Run all scripts

```bash
npm test
```

### Run a specific npm script

```bash
npm run test:form
npm run test:menu
npm run test:db
```

---

## Configuration

All scripts read their configuration from environment variables with sensible defaults. You can set them in your shell or in a `.env` file (not committed to git).

| Variable | Default | Description |
|----------|---------|-------------|
| `WP_SITE_URL` | `http://my-test-site.local` | Your WordPress site URL |
| `WP_CLI_PREFIX` | `wp` | WP-CLI command (use `local-wp <name> -- wp` for Local) |
| `WP_AUTH_FILE` | `../../temp/playwright/.auth/admin.json` | Playwright auth state file |
| `WP_TIMEOUT_MS` | `30000` | Default navigation/selector timeout in ms |
| `WP_HEADLESS` | `true` | Set to `false` to see the browser window |

**Example `.env` (do not commit this file):**

```bash
WP_SITE_URL=http://my-site.local
WP_CLI_PREFIX=local-wp my-site -- wp
WP_HEADLESS=false
```

---

## Troubleshooting

**"Cannot find module 'playwright'"**
```bash
npm install
npx playwright install chromium
```

**"Auth file not found" or login redirects to wp-login.php**
```bash
# Re-authenticate
pw-auth login --site-url http://my-test-site.local --force
```

**"Dev login is disabled in production environments"**
```php
// Add to wp-config.php
define( 'WP_ENVIRONMENT_TYPE', 'development' );
```

**Timeout errors**
```bash
# Set a longer timeout
WP_TIMEOUT_MS=60000 node 01-setup.js
```

---

## See Also

- [WORDPRESS-TESTING-QUICKSTART.md](../../docs/WORDPRESS-TESTING-QUICKSTART.md) — Full setup guide
- [PW-AUTH-COMMANDS.md](../../docs/PW-AUTH-COMMANDS.md) — pw-auth command reference
- [TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md) — Detailed troubleshooting
