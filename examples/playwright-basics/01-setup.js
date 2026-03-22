/**
 * 01-setup.js — Basic environment setup and WordPress connection check
 *
 * This script verifies that:
 *   1. The Playwright auth state file exists (you have run `pw-auth login`)
 *   2. The WordPress site is reachable
 *   3. The saved session lets us access the wp-admin dashboard
 *
 * Usage:
 *   node 01-setup.js
 *
 * Environment variables (all optional — defaults shown):
 *   WP_SITE_URL     http://my-test-site.local
 *   WP_AUTH_FILE    ../../temp/playwright/.auth/admin.json
 *   WP_TIMEOUT_MS   30000
 *   WP_HEADLESS     true
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

// ── Configuration ────────────────────────────────────────────────────────────

const SITE_URL    = process.env.WP_SITE_URL    || 'http://my-test-site.local';
const AUTH_FILE   = process.env.WP_AUTH_FILE   || path.resolve(__dirname, '../../temp/playwright/.auth/admin.json');
const TIMEOUT_MS  = Number(process.env.WP_TIMEOUT_MS || '30000');
const HEADLESS    = process.env.WP_HEADLESS !== 'false';

// ── Helpers ───────────────────────────────────────────────────────────────────

function pass(msg) { console.log(`  ✅ ${msg}`); }
function fail(msg) { console.error(`  ❌ ${msg}`); }
function info(msg) { console.log(`  ℹ  ${msg}`); }

// ── Main ──────────────────────────────────────────────────────────────────────

(async () => {
  console.log('\n=== AI-DDTK: Setup Check ===\n');

  // 1. Verify auth file exists ------------------------------------------------
  console.log('Step 1: Check auth state file');
  if (fs.existsSync(AUTH_FILE)) {
    pass(`Auth file found: ${AUTH_FILE}`);
  } else {
    fail(`Auth file not found: ${AUTH_FILE}`);
    info('Run: pw-auth login --site-url ' + SITE_URL);
    info('See: docs/WORDPRESS-TESTING-QUICKSTART.md → Section 5');
    process.exit(1);
  }

  // 2. Launch browser and load session ----------------------------------------
  console.log('\nStep 2: Launch browser with saved session');
  const browser = await chromium.launch({ headless: HEADLESS });
  const context = await browser.newContext({
    storageState: AUTH_FILE,
  });
  context.setDefaultTimeout(TIMEOUT_MS);
  const page = await context.newPage();
  pass('Browser launched successfully');

  // 3. Navigate to the WordPress dashboard -------------------------------------
  console.log('\nStep 3: Load the WordPress dashboard');
  try {
    await page.goto(`${SITE_URL}/wp-admin/`, { waitUntil: 'domcontentloaded' });
    const title = await page.title();
    info(`Page title: "${title}"`);

    if (title.toLowerCase().includes('dashboard')) {
      pass('WordPress dashboard loaded — session is valid');
    } else if (title.toLowerCase().includes('log in') || page.url().includes('wp-login.php')) {
      fail('Redirected to login page — session has expired');
      info('Run: pw-auth login --site-url ' + SITE_URL + ' --force');
      await browser.close();
      process.exit(1);
    } else {
      pass(`Connected to WordPress (title: "${title}")`);
    }
  } catch (err) {
    fail(`Could not load WordPress: ${err.message}`);
    info(`Check that ${SITE_URL} is running`);
    await browser.close();
    process.exit(1);
  }

  // 4. Verify wp-admin elements ------------------------------------------------
  console.log('\nStep 4: Verify admin bar is present');
  try {
    await page.waitForSelector('#wpadminbar', { timeout: TIMEOUT_MS });
    pass('Admin bar (#wpadminbar) found');
  } catch {
    fail('Admin bar not found — session may be invalid');
  }

  // 5. Print WordPress version (optional but helpful) --------------------------
  console.log('\nStep 5: Read WordPress version from dashboard');
  try {
    await page.goto(`${SITE_URL}/wp-admin/about.php`, { waitUntil: 'domcontentloaded' });
    const versionEl = await page.$('.wp-badge');
    if (versionEl) {
      const versionText = await versionEl.textContent();
      pass(`WordPress version: ${versionText.trim()}`);
    } else {
      info('Version badge not found (non-critical)');
    }
  } catch {
    info('Could not read WordPress version (non-critical)');
  }

  await browser.close();

  console.log('\n=== Setup check passed ✅ ===\n');
  console.log('You are ready to run the other example scripts:');
  console.log('  node 02-form-submission.js');
  console.log('  node 03-menu-check.js');
  console.log('  node 04-db-query.js');
  console.log('  node 05-common-patterns.js\n');
})();
