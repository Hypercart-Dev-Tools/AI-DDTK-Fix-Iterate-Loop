/**
 * 05-common-patterns.js — Common testing patterns and reusable utilities
 *
 * This file is both a learning resource and a utility library. It shows:
 *
 *   Pattern 1: createAuthContext()  — Create a reusable browser context with saved auth
 *   Pattern 2: waitForAdminBar()    — Confirm wp-admin is loaded and authenticated
 *   Pattern 3: navigateAdmin()      — Go to any wp-admin sub-page reliably
 *   Pattern 4: getOption()          — Read a WordPress option via WP-CLI
 *   Pattern 5: screenshotStep()     — Capture a screenshot at any test step
 *   Pattern 6: retryGoto()          — Navigate with automatic retries for flaky sites
 *   Pattern 7: assertText()         — Soft assertion helper with clear error messages
 *   Pattern 8: Full example         — Putting it all together
 *
 * Usage:
 *   node 05-common-patterns.js
 *
 * Environment variables (all optional — defaults shown):
 *   WP_SITE_URL     http://my-test-site.local
 *   WP_AUTH_FILE    ../../temp/playwright/.auth/admin.json
 *   WP_CLI_PREFIX   wp
 *   WP_TIMEOUT_MS   30000
 *   WP_HEADLESS     true
 */

'use strict';

const { execSync }  = require('child_process');
const fs            = require('fs');
const path          = require('path');
const { chromium }  = require('playwright');

// ── Configuration ────────────────────────────────────────────────────────────

const SITE_URL    = process.env.WP_SITE_URL    || 'http://my-test-site.local';
const AUTH_FILE   = process.env.WP_AUTH_FILE   || path.resolve(__dirname, '../../temp/playwright/.auth/admin.json');
const WP_CLI      = process.env.WP_CLI_PREFIX  || 'wp';
const TIMEOUT_MS  = Number(process.env.WP_TIMEOUT_MS || '30000');
const HEADLESS    = process.env.WP_HEADLESS !== 'false';

// Directory for screenshots captured during tests
const SCREENSHOTS_DIR = path.resolve(__dirname, '../../temp/playwright/screenshots');

// ── Logging helpers ───────────────────────────────────────────────────────────

function pass(msg) { console.log(`  ✅ ${msg}`); }
function fail(msg) { console.error(`  ❌ ${msg}`); process.exitCode = 1; }
function info(msg) { console.log(`  ℹ  ${msg}`); }
function step(msg) { console.log(`\n--- ${msg}`); }

// ═══════════════════════════════════════════════════════════════════════════════
// Pattern 1 — createAuthContext
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Create a Playwright browser context pre-loaded with the saved auth session.
 *
 * Usage:
 *   const { browser, context, page } = await createAuthContext();
 *   // ... run your test ...
 *   await browser.close();
 *
 * @param {import('playwright').BrowserType} [browserType]  Defaults to chromium
 * @returns {Promise<{browser: import('playwright').Browser, context: import('playwright').BrowserContext, page: import('playwright').Page}>}
 */
async function createAuthContext(browserType = chromium) {
  const browser = await browserType.launch({ headless: HEADLESS });
  const context = await browser.newContext({ storageState: AUTH_FILE });
  context.setDefaultTimeout(TIMEOUT_MS);
  const page = await context.newPage();
  return { browser, context, page };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pattern 2 — waitForAdminBar
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Wait for the WordPress admin bar (#wpadminbar) to confirm the session is valid.
 * Throws if the admin bar is not found or if we were redirected to the login page.
 *
 * @param {import('playwright').Page} page
 */
async function waitForAdminBar(page) {
  const currentUrl = page.url();

  if (currentUrl.includes('wp-login.php')) {
    throw new Error('Redirected to login page — session has expired. Run: pw-auth login --force');
  }

  await page.waitForSelector('#wpadminbar', { timeout: TIMEOUT_MS });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pattern 3 — navigateAdmin
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Navigate to a wp-admin sub-page and verify the admin bar is present.
 *
 * @param {import('playwright').Page} page
 * @param {string} adminPath  Path relative to wp-admin (e.g. 'plugins.php', 'options-general.php')
 */
async function navigateAdmin(page, adminPath) {
  const url = `${SITE_URL}/wp-admin/${adminPath.replace(/^\//, '')}`;
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await waitForAdminBar(page);
  return url;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pattern 4 — getOption
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Read a WordPress option value via WP-CLI (`wp option get`).
 *
 * @param {string} optionName  WordPress option name (e.g. 'blogname', 'siteurl')
 * @returns {string}
 */
function getOption(optionName) {
  return execSync(`${WP_CLI} option get ${optionName}`, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
  }).trim();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pattern 5 — screenshotStep
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Save a screenshot with a descriptive name into the temp/playwright/screenshots dir.
 * Useful for debugging failed tests.
 *
 * @param {import('playwright').Page} page
 * @param {string} name  Short descriptive label, e.g. "after-login" or "error-state"
 * @returns {Promise<string>}  Absolute path to the saved file
 */
async function screenshotStep(page, name) {
  fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });
  // Use path.basename() after sanitizing to guarantee no path traversal.
  const safeName = path.basename(name.replace(/[^a-zA-Z0-9-_]/g, '-'));
  const filePath = path.join(SCREENSHOTS_DIR, `${Date.now()}-${safeName}.png`);
  await page.screenshot({ path: filePath, fullPage: true });
  info(`Screenshot saved: ${filePath}`);
  return filePath;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pattern 6 — retryGoto
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Navigate to a URL with automatic retries.
 * Useful for local sites that can be slow to start or respond intermittently.
 *
 * @param {import('playwright').Page} page
 * @param {string} url
 * @param {object} [options]
 * @param {number} [options.maxRetries=3]
 * @param {number} [options.retryDelayMs=2000]
 * @param {string} [options.waitUntil='domcontentloaded']
 */
async function retryGoto(page, url, { maxRetries = 3, retryDelayMs = 2000, waitUntil = 'domcontentloaded' } = {}) {
  let lastError;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await page.goto(url, { waitUntil, timeout: TIMEOUT_MS });
      return; // success
    } catch (err) {
      lastError = err;
      if (attempt < maxRetries) {
        info(`Navigation attempt ${attempt} failed, retrying in ${retryDelayMs}ms…`);
        await new Promise((resolve) => setTimeout(resolve, retryDelayMs));
      }
    }
  }
  throw new Error(`Failed to load ${url} after ${maxRetries} attempts: ${lastError.message}`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pattern 7 — assertText
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Soft assertion: check that a CSS selector contains expected text.
 * Logs pass/fail instead of throwing, so subsequent checks still run.
 *
 * @param {import('playwright').Page} page
 * @param {string} selector    CSS selector
 * @param {string} expected    Text the element should contain (case-insensitive, partial match)
 * @param {string} [label]     Human-readable label for the log output
 */
async function assertText(page, selector, expected, label = selector) {
  try {
    const el = await page.$(selector);
    if (!el) {
      fail(`assertText: element not found — "${label}" (${selector})`);
      return;
    }
    const actual = await el.textContent();
    if (actual && actual.toLowerCase().includes(expected.toLowerCase())) {
      pass(`assertText: "${label}" contains "${expected}"`);
    } else {
      fail(`assertText: "${label}" expected to contain "${expected}" but got "${actual}"`);
    }
  } catch (err) {
    fail(`assertText: error checking "${label}": ${err.message}`);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pattern 8 — Full example using all patterns
// ═══════════════════════════════════════════════════════════════════════════════

(async () => {
  console.log('\n=== AI-DDTK: Common Patterns Demo ===\n');

  // — Pattern 1: Create auth context —
  step('Pattern 1: createAuthContext()');
  const { browser, page } = await createAuthContext();
  pass('Auth context created');

  // — Pattern 3: Navigate to a wp-admin page —
  step('Pattern 3: navigateAdmin()');
  try {
    const url = await navigateAdmin(page, 'index.php');
    pass(`Navigated to wp-admin: ${url}`);
  } catch (err) {
    fail(`navigateAdmin failed: ${err.message}`);
    await browser.close();
    process.exit(1);
  }

  // — Pattern 2: Verify admin bar —
  step('Pattern 2: waitForAdminBar()');
  try {
    await waitForAdminBar(page);
    pass('Admin bar present — session is valid');
  } catch (err) {
    fail(`waitForAdminBar: ${err.message}`);
  }

  // — Pattern 5: Screenshot —
  step('Pattern 5: screenshotStep()');
  await screenshotStep(page, 'dashboard-loaded');

  // — Pattern 7: Text assertions on the dashboard —
  step('Pattern 7: assertText()');
  await assertText(page, '#wpadminbar', 'wp', 'admin bar');
  await assertText(page, '#adminmenu', 'Posts', 'admin sidebar Posts link');
  await assertText(page, '#adminmenu', 'Settings', 'admin sidebar Settings link');

  // — Pattern 4: Read a WordPress option —
  step('Pattern 4: getOption()');
  try {
    const blogName = getOption('blogname');
    pass(`blogname: "${blogName}"`);

    const siteUrl = getOption('siteurl');
    pass(`siteurl: "${siteUrl}"`);
  } catch (err) {
    info(`getOption skipped (WP-CLI may not be configured): ${err.message}`);
  }

  // — Pattern 6: retryGoto() —
  step('Pattern 6: retryGoto()');
  try {
    await retryGoto(page, `${SITE_URL}/wp-admin/plugins.php`, { maxRetries: 2 });
    pass('Plugins page loaded (with retry support)');
    await assertText(page, '.wrap h1', 'Plugins', 'plugins page heading');
  } catch (err) {
    fail(`retryGoto failed: ${err.message}`);
  }

  await browser.close();

  if (process.exitCode === 1) {
    console.log('\n=== Common patterns demo FAILED ❌ ===\n');
  } else {
    console.log('\n=== Common patterns demo passed ✅ ===\n');
    console.log('These utilities are ready to copy into your own test scripts.');
    console.log('See the comments in 05-common-patterns.js for usage details.\n');
  }
})();

// ── Exports (so other scripts can require() these utilities) ─────────────────
module.exports = {
  createAuthContext,
  waitForAdminBar,
  navigateAdmin,
  getOption,
  screenshotStep,
  retryGoto,
  assertText,
};
