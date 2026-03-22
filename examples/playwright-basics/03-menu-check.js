/**
 * 03-menu-check.js — WordPress navigation menu verification
 *
 * Demonstrates how to:
 *   - Load a WordPress site's frontend
 *   - Extract all navigation links from the primary menu
 *   - Verify specific links are present
 *   - Check that each link returns a 200 status
 *
 * Usage:
 *   node 03-menu-check.js
 *
 * Environment variables (all optional — defaults shown):
 *   WP_SITE_URL     http://my-test-site.local
 *   WP_AUTH_FILE    ../../temp/playwright/.auth/admin.json
 *   WP_TIMEOUT_MS   30000
 *   WP_HEADLESS     true
 */

'use strict';

const path = require('path');
const { chromium, request } = require('playwright');

// ── Configuration ────────────────────────────────────────────────────────────

const SITE_URL    = process.env.WP_SITE_URL    || 'http://my-test-site.local';
const AUTH_FILE   = process.env.WP_AUTH_FILE   || path.resolve(__dirname, '../../temp/playwright/.auth/admin.json');
const TIMEOUT_MS  = Number(process.env.WP_TIMEOUT_MS || '30000');
const HEADLESS    = process.env.WP_HEADLESS !== 'false';

// CSS selectors to try for navigation menus (theme-dependent)
// The script tries each one in order and uses the first that matches.
const MENU_SELECTORS = [
  'nav[id*="navigation"] a',
  'nav[class*="navigation"] a',
  '#site-navigation a',
  '#primary-menu a',
  '.nav-menu a',
  'nav ul li a',
  'header nav a',
];

// ── Helpers ───────────────────────────────────────────────────────────────────

function pass(msg)  { console.log(`  ✅ ${msg}`); }
function fail(msg)  { console.error(`  ❌ ${msg}`); process.exitCode = 1; }
function info(msg)  { console.log(`  ℹ  ${msg}`); }
function warn(msg)  { console.log(`  ⚠  ${msg}`); }

// ── Main ──────────────────────────────────────────────────────────────────────

(async () => {
  console.log('\n=== AI-DDTK: Navigation Menu Check ===\n');

  const browser = await chromium.launch({ headless: HEADLESS });
  const context = await browser.newContext({ storageState: AUTH_FILE });
  context.setDefaultTimeout(TIMEOUT_MS);
  const page = await context.newPage();

  // 1. Load the homepage -------------------------------------------------------
  console.log('Step 1: Load the WordPress homepage');
  await page.goto(SITE_URL, { waitUntil: 'domcontentloaded' });
  const pageTitle = await page.title();
  pass(`Loaded homepage: "${pageTitle}"`);

  // 2. Find a navigation menu using known selectors ----------------------------
  console.log('\nStep 2: Locate navigation links');
  let navLinks = [];
  let usedSelector = null;

  for (const selector of MENU_SELECTORS) {
    const count = await page.$$eval(selector, (els) => els.length).catch(() => 0);
    if (count > 0) {
      navLinks = await page.$$eval(selector, (anchors) =>
        anchors.map((a) => ({
          text: a.textContent.trim().replace(/\s+/g, ' '),
          href: a.href,
        }))
      );
      usedSelector = selector;
      break;
    }
  }

  if (navLinks.length === 0) {
    warn('No navigation links found with standard selectors');
    info('Your theme may use a non-standard navigation structure');
    info('Try inspecting the page HTML and adding your selector to MENU_SELECTORS');

    // Fallback: collect ALL links from the page as informational output
    const allLinks = await page.$$eval('a[href]', (anchors) =>
      anchors
        .map((a) => ({ text: a.textContent.trim(), href: a.href }))
        .filter((l) => l.text.length > 0)
        .slice(0, 20)
    );
    info(`First 20 links on the page:`);
    allLinks.forEach((l) => info(`  "${l.text}" → ${l.href}`));
  } else {
    pass(`Found ${navLinks.length} navigation link(s) using selector: ${usedSelector}`);

    console.log('\n  Navigation links:');
    navLinks.forEach((link, i) => {
      console.log(`    ${i + 1}. "${link.text}" → ${link.href}`);
    });
  }

  // 3. Verify expected links are present ---------------------------------------
  console.log('\nStep 3: Check for expected menu items');

  // Default WordPress Twenty-series themes ship with these items.
  // Adjust this array to match your site's menu.
  const EXPECTED_ITEMS = [
    // text fragment (case-insensitive, partial match)
  ];

  if (EXPECTED_ITEMS.length === 0) {
    info('No expected items configured — skipping assertion');
    info('Add items to EXPECTED_ITEMS in the script to enable this check');
  } else {
    for (const expected of EXPECTED_ITEMS) {
      const found = navLinks.some((l) =>
        l.text.toLowerCase().includes(expected.toLowerCase())
      );
      if (found) {
        pass(`Menu item found: "${expected}"`);
      } else {
        fail(`Menu item NOT found: "${expected}"`);
      }
    }
  }

  // 4. Verify that each navigation link returns HTTP 200 -----------------------
  console.log('\nStep 4: Check HTTP status for each navigation link');

  // Only check internal links (same origin) to avoid external request issues.
  // Compare origins via the URL constructor to prevent partial-match false positives
  // (e.g. http://my-site.local.evil.com would not pass an origin equality check).
  let siteOrigin;
  try {
    siteOrigin = new URL(SITE_URL).origin;
  } catch {
    siteOrigin = SITE_URL;
  }

  const internalLinks = navLinks.filter((l) => {
    try {
      return new URL(l.href).origin === siteOrigin;
    } catch {
      return false;
    }
  });
  info(`Checking ${internalLinks.length} internal link(s)…`);

  const apiContext = await request.newContext();

  for (const link of internalLinks) {
    try {
      const response = await apiContext.get(link.href, { timeout: TIMEOUT_MS });
      const status = response.status();
      if (status === 200) {
        pass(`HTTP ${status} — "${link.text}" (${link.href})`);
      } else {
        fail(`HTTP ${status} — "${link.text}" (${link.href})`);
      }
    } catch (err) {
      fail(`Request failed — "${link.text}" (${link.href}): ${err.message}`);
    }
  }

  await apiContext.dispose();

  // 5. Verify admin menu is accessible (logged-in check) -----------------------
  console.log('\nStep 5: Verify wp-admin navigation sidebar');
  try {
    await page.goto(`${SITE_URL}/wp-admin/`, { waitUntil: 'domcontentloaded' });
    const adminMenuItems = await page.$$eval(
      '#adminmenu li a .wp-menu-name',
      (els) => els.map((el) => el.textContent.trim())
    );
    if (adminMenuItems.length > 0) {
      pass(`wp-admin sidebar has ${adminMenuItems.length} menu item(s)`);
      info('Items: ' + adminMenuItems.slice(0, 6).join(', ') + (adminMenuItems.length > 6 ? '…' : ''));
    } else {
      info('wp-admin sidebar items not found with standard selector (non-critical)');
    }
  } catch (err) {
    info(`wp-admin menu check skipped: ${err.message}`);
  }

  await browser.close();

  if (process.exitCode === 1) {
    console.log('\n=== Menu check FAILED ❌ ===\n');
  } else {
    console.log('\n=== Menu check passed ✅ ===\n');
  }
})();
