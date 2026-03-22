/**
 * 02-form-submission.js — WordPress comment form submission test
 *
 * Demonstrates how to:
 *   - Navigate to a WordPress post
 *   - Fill in and submit a form (the built-in comment form)
 *   - Verify the submitted data appears on the page
 *   - Handle form validation errors gracefully
 *
 * Usage:
 *   node 02-form-submission.js
 *
 * Environment variables (all optional — defaults shown):
 *   WP_SITE_URL     http://my-test-site.local
 *   WP_AUTH_FILE    ../../temp/playwright/.auth/admin.json
 *   WP_TIMEOUT_MS   30000
 *   WP_HEADLESS     true
 *   WP_POST_ID      1   (WordPress post ID to comment on)
 */

'use strict';

const path = require('path');
const { chromium } = require('playwright');

// ── Configuration ────────────────────────────────────────────────────────────

const SITE_URL    = process.env.WP_SITE_URL    || 'http://my-test-site.local';
const AUTH_FILE   = process.env.WP_AUTH_FILE   || path.resolve(__dirname, '../../temp/playwright/.auth/admin.json');
const TIMEOUT_MS  = Number(process.env.WP_TIMEOUT_MS || '30000');
const HEADLESS    = process.env.WP_HEADLESS !== 'false';
const POST_ID     = process.env.WP_POST_ID     || '1';

// Unique comment text so we can verify it was saved
const TEST_COMMENT = `Test comment from Playwright — ${Date.now()}`;

// ── Helpers ───────────────────────────────────────────────────────────────────

function pass(msg) { console.log(`  ✅ ${msg}`); }
function fail(msg) { console.error(`  ❌ ${msg}`); process.exitCode = 1; }
function info(msg) { console.log(`  ℹ  ${msg}`); }

// ── Main ──────────────────────────────────────────────────────────────────────

(async () => {
  console.log('\n=== AI-DDTK: Form Submission Test ===\n');

  const browser = await chromium.launch({ headless: HEADLESS });
  const context = await browser.newContext({ storageState: AUTH_FILE });
  context.setDefaultTimeout(TIMEOUT_MS);
  const page = await context.newPage();

  // 1. Navigate to a post that has comments enabled ----------------------------
  console.log('Step 1: Load a WordPress post');
  const postUrl = `${SITE_URL}/?p=${POST_ID}`;
  await page.goto(postUrl, { waitUntil: 'domcontentloaded' });
  info(`Navigated to: ${postUrl}`);

  const postTitle = await page.title();
  info(`Post title: "${postTitle}"`);

  // 2. Check that the comment form exists --------------------------------------
  console.log('\nStep 2: Locate the comment form');
  const commentForm = await page.$('#commentform, form.comment-form');
  if (!commentForm) {
    fail('Comment form not found on this post');
    info('Make sure the post has comments open (Settings → Discussion)');
    await browser.close();
    process.exit(1);
  }
  pass('Comment form found');

  // 3. Fill in the comment text ------------------------------------------------
  console.log('\nStep 3: Fill in the comment');
  const commentInput = await page.$('#comment');
  if (!commentInput) {
    fail('Comment textarea (#comment) not found');
    await browser.close();
    process.exit(1);
  }
  await commentInput.fill(TEST_COMMENT);
  pass(`Filled comment: "${TEST_COMMENT}"`);

  // 4. Submit the form ---------------------------------------------------------
  console.log('\nStep 4: Submit the comment form');
  await page.click('#submit');

  // WordPress may redirect to the same post with the new comment anchored,
  // or it may reload the page. Wait for either.
  await page.waitForLoadState('domcontentloaded');
  info(`Current URL after submit: ${page.url()}`);

  // 5. Verify the comment appears on the page ----------------------------------
  console.log('\nStep 5: Verify comment was saved');
  try {
    // WordPress shows comments in .comment-body or .comment-content
    await page.waitForSelector('.comment-body, .comment-content', { timeout: TIMEOUT_MS });
    const commentBodies = await page.$$eval(
      '.comment-body p, .comment-content p',
      (els) => els.map((el) => el.textContent.trim())
    );

    const found = commentBodies.some((text) => text.includes('Test comment from Playwright'));
    if (found) {
      pass('Comment appears on the page after submission');
    } else {
      fail('Comment text not found in the page after submission');
      info('Comments may require moderation — check wp-admin → Comments');
      info('Submitted text: ' + TEST_COMMENT);
    }
  } catch (err) {
    fail(`Could not find comment list: ${err.message}`);
    info('The post may require comment moderation or comments may be closed');
  }

  // 6. Additional: verify comment count in admin -------------------------------
  console.log('\nStep 6: Verify comment count in wp-admin');
  try {
    await page.goto(`${SITE_URL}/wp-admin/edit-comments.php`, { waitUntil: 'domcontentloaded' });
    const pendingBadge = await page.$('#awaiting-mod .awaiting-mod-count, .approved .count');
    if (pendingBadge) {
      const countText = await pendingBadge.textContent();
      info(`Comment count from wp-admin: ${countText.trim()}`);
    }
    pass('wp-admin comments page accessible');
  } catch (err) {
    info(`Admin comment check skipped: ${err.message}`);
  }

  await browser.close();

  if (process.exitCode === 1) {
    console.log('\n=== Form submission test FAILED ❌ ===\n');
  } else {
    console.log('\n=== Form submission test passed ✅ ===\n');
  }
})();
