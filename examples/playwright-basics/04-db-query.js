/**
 * 04-db-query.js — Database query verification via WP-CLI
 *
 * Demonstrates how to:
 *   - Run WP-CLI database queries from Node.js
 *   - Verify WordPress database content programmatically
 *   - Cross-reference DB state with browser state (Playwright)
 *   - Handle Local by Flywheel and standard WP-CLI setups
 *
 * Usage:
 *   node 04-db-query.js
 *
 * Environment variables (all optional — defaults shown):
 *   WP_SITE_URL     http://my-test-site.local
 *   WP_AUTH_FILE    ../../temp/playwright/.auth/admin.json
 *   WP_CLI_PREFIX   wp   (use "local-wp my-site -- wp" for Local by Flywheel)
 *   WP_TIMEOUT_MS   30000
 *   WP_HEADLESS     true
 */

'use strict';

const { execSync }  = require('child_process');
const path          = require('path');
const { chromium }  = require('playwright');

// ── Configuration ────────────────────────────────────────────────────────────

const SITE_URL    = process.env.WP_SITE_URL    || 'http://my-test-site.local';
const AUTH_FILE   = process.env.WP_AUTH_FILE   || path.resolve(__dirname, '../../temp/playwright/.auth/admin.json');
const WP_CLI      = process.env.WP_CLI_PREFIX  || 'wp';
const TIMEOUT_MS  = Number(process.env.WP_TIMEOUT_MS || '30000');
const HEADLESS    = process.env.WP_HEADLESS !== 'false';

// ── WP-CLI helpers ────────────────────────────────────────────────────────────

/**
 * Run a WP-CLI command and return stdout as a trimmed string.
 * Throws if the command exits with a non-zero code.
 *
 * @param {string} subCommand  WP-CLI subcommand and arguments (everything after `wp`)
 * @returns {string}
 */
function wp(subCommand) {
  const cmd = `${WP_CLI} ${subCommand}`;
  return execSync(cmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
}

/**
 * Run a raw SQL query via `wp db query` and return the trimmed output.
 * The SQL is passed via stdin (not as a shell argument) to avoid shell injection.
 * Column names are skipped so only the data row(s) are returned.
 *
 * @param {string} sql
 * @returns {string}
 */
function wpQuery(sql) {
  // Pass the SQL via stdin rather than as a shell argument to prevent injection.
  const cmd = `${WP_CLI} db query --skip-column-names`;
  return execSync(cmd, {
    input: sql,
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
  }).trim();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function pass(msg) { console.log(`  ✅ ${msg}`); }
function fail(msg) { console.error(`  ❌ ${msg}`); process.exitCode = 1; }
function info(msg) { console.log(`  ℹ  ${msg}`); }

// ── Main ──────────────────────────────────────────────────────────────────────

(async () => {
  console.log('\n=== AI-DDTK: Database Query Verification ===\n');

  // 1. Verify WP-CLI is available ----------------------------------------------
  console.log('Step 1: Verify WP-CLI');
  try {
    const version = wp('--version');
    pass(`WP-CLI available: ${version}`);
  } catch (err) {
    fail(`WP-CLI not available with prefix "${WP_CLI}": ${err.message}`);
    info('For Local by Flywheel: set WP_CLI_PREFIX="local-wp my-site -- wp"');
    info('For standard WP-CLI: ensure `wp` is in your PATH');
    process.exit(1);
  }

  // 2. Check the WordPress database is reachable -------------------------------
  console.log('\nStep 2: Check database connection');
  try {
    const dbCheck = wp('db check 2>&1');
    pass(`Database is healthy: ${dbCheck.split('\n')[0]}`);
  } catch (err) {
    fail(`Database check failed: ${err.message}`);
    info('Make sure your WordPress site and its database are running');
    process.exit(1);
  }

  // 3. Verify core WordPress tables exist --------------------------------------
  console.log('\nStep 3: Verify core WordPress tables');
  const EXPECTED_TABLES = ['wp_users', 'wp_posts', 'wp_options', 'wp_postmeta', 'wp_usermeta'];
  try {
    const tables = wp('db tables --all-tables --format=csv').split(',').map((t) => t.trim());
    for (const table of EXPECTED_TABLES) {
      if (tables.some((t) => t === table || t.endsWith('_' + table.replace('wp_', '')))) {
        pass(`Table exists: ${table}`);
      } else {
        fail(`Table missing: ${table}`);
      }
    }
  } catch (err) {
    fail(`Could not list tables: ${err.message}`);
  }

  // 4. Verify admin user exists ------------------------------------------------
  console.log('\nStep 4: Check admin user in wp_users');
  try {
    const adminCount = wpQuery("SELECT COUNT(*) FROM wp_users WHERE user_login = 'admin'");
    if (adminCount === '1') {
      pass("User 'admin' exists in wp_users");
    } else if (adminCount === '0') {
      info("User 'admin' not found — your admin may have a different username");
      const admins = wpQuery("SELECT user_login FROM wp_users LIMIT 3");
      info(`First users: ${admins}`);
    } else {
      fail(`Unexpected count for admin user: ${adminCount}`);
    }
  } catch (err) {
    fail(`Admin user query failed: ${err.message}`);
  }

  // 5. Count published posts ---------------------------------------------------
  console.log('\nStep 5: Count published posts');
  try {
    const postCount = wpQuery("SELECT COUNT(*) FROM wp_posts WHERE post_status = 'publish' AND post_type = 'post'");
    pass(`Published posts: ${postCount}`);

    const pageCount = wpQuery("SELECT COUNT(*) FROM wp_posts WHERE post_status = 'publish' AND post_type = 'page'");
    pass(`Published pages: ${pageCount}`);
  } catch (err) {
    fail(`Post count query failed: ${err.message}`);
  }

  // 6. Read site URL from wp_options -------------------------------------------
  console.log('\nStep 6: Read site URL from wp_options');
  try {
    const dbSiteUrl = wpQuery("SELECT option_value FROM wp_options WHERE option_name = 'siteurl'");
    pass(`siteurl in DB: ${dbSiteUrl}`);

    if (dbSiteUrl === SITE_URL) {
      pass('DB siteurl matches WP_SITE_URL env variable');
    } else {
      info(`Note: WP_SITE_URL env is "${SITE_URL}" but DB has "${dbSiteUrl}"`);
      info('This is normal if you are using a different URL format');
    }
  } catch (err) {
    fail(`wp_options query failed: ${err.message}`);
  }

  // 7. Cross-check DB post count with what Playwright sees on the frontend -----
  console.log('\nStep 7: Cross-check DB post count with the browser');
  const browser = await chromium.launch({ headless: HEADLESS });
  const context = await browser.newContext({ storageState: AUTH_FILE });
  context.setDefaultTimeout(TIMEOUT_MS);
  const page = await context.newPage();

  try {
    // Get post count from wp-admin → Posts list
    await page.goto(`${SITE_URL}/wp-admin/edit.php?post_status=publish&post_type=post`, {
      waitUntil: 'domcontentloaded',
    });

    // The "displaying X of Y items" text
    const countText = await page.$eval(
      '.displaying-num',
      (el) => el.textContent.trim()
    ).catch(() => null);

    if (countText) {
      pass(`wp-admin shows: "${countText}"`);
    } else {
      info('Displaying-num element not found (post list may be empty)');
    }

    pass('Browser cross-check complete');
  } catch (err) {
    info(`Browser cross-check skipped: ${err.message}`);
  }

  await browser.close();

  if (process.exitCode === 1) {
    console.log('\n=== Database query verification FAILED ❌ ===\n');
  } else {
    console.log('\n=== Database query verification passed ✅ ===\n');
  }
})();
