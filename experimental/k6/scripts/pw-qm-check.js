/**
 * Reusable Query Monitor scraper for WordPress frontend pages.
 *
 * Environment variables:
 * - AUTH_STATE: optional Playwright storage-state file.
 * - TARGET_URL: page to load before scraping Query Monitor.
 * - SEARCH_TERMS: comma-separated terms to search for across page HTML, QM text, and DB panel output.
 * - QM_PANEL_SELECTOR: DB panel selector (default: #qm-db_queries).
 * - WAIT_UNTIL: Playwright waitUntil mode (default: networkidle).
 * - TIMEOUT_MS: navigation/action timeout in ms (default: 60000).
 * - HEADLESS: set to 0/false/no to show the browser.
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const AUTH_STATE = process.env.AUTH_STATE ? path.resolve(process.env.AUTH_STATE) : '';
const TARGET_URL = process.env.TARGET_URL || 'http://localhost/';
const QM_ROOT_SELECTOR = process.env.QM_ROOT_SELECTOR || '#query-monitor-main';
const QM_PANEL_SELECTOR = process.env.QM_PANEL_SELECTOR || '#qm-db_queries';
const WAIT_UNTIL = process.env.WAIT_UNTIL || 'networkidle';
const TIMEOUT_MS = Number(process.env.TIMEOUT_MS || 60000);
const SEARCH_TERMS = (process.env.SEARCH_TERMS || 'binoid15,shop_coupon,SELECT wp_posts.ID FROM wp_posts')
  .split(',')
  .map((term) => term.trim())
  .filter(Boolean);

function boolEnv(value, fallback = true) {
  if (value == null || value === '') return fallback;
  return !['0', 'false', 'no'].includes(String(value).toLowerCase());
}

function snippet(text, term, radius = 180) {
  const haystack = String(text || '');
  const index = haystack.toLowerCase().indexOf(term.toLowerCase());
  if (index < 0) return '';
  return haystack.slice(Math.max(0, index - radius), index + term.length + radius);
}

async function safeText(page, selector) {
  return (await page.locator(selector).innerText().catch(() => '')) || '';
}

async function safeHtml(page, selector) {
  return (await page.locator(selector).innerHTML().catch(() => '')) || '';
}

async function clickFirst(page, selectors) {
  for (const selector of selectors) {
    const locator = page.locator(selector).first();
    if (await locator.count()) {
      await locator.click().catch(() => {});
      return selector;
    }
  }
  return '';
}

(async () => {
  const browser = await chromium.launch({ headless: boolEnv(process.env.HEADLESS, true) });
  const contextOptions = { ignoreHTTPSErrors: true };

  if (AUTH_STATE && fs.existsSync(AUTH_STATE)) {
    contextOptions.storageState = AUTH_STATE;
  }

  const context = await browser.newContext(contextOptions);
  const page = await context.newPage();
  page.setDefaultTimeout(TIMEOUT_MS);
  page.setDefaultNavigationTimeout(TIMEOUT_MS);

  try {
    await page.goto(TARGET_URL, { waitUntil: WAIT_UNTIL });

    const pageHtml = await page.content();
    const qmLinks = await page.evaluate(() =>
      Array.from(document.querySelectorAll('a[href*="#qm"]'))
        .map((link) => link.getAttribute('href'))
        .filter(Boolean)
        .slice(0, 25)
    );

    const openedWith = await clickFirst(page, [
      '#wp-admin-bar-query-monitor a',
      'a[href="#query-monitor-main"]',
      'a[href*="#qm-overview"]',
    ]);
    if (openedWith) {
      await page.waitForTimeout(1000);
    }

    const dbPanelOpenedWith = await clickFirst(page, ['a[href="#qm-db_queries"]', 'a[href*="#qm-db_queries"]']);
    if (dbPanelOpenedWith) {
      await page.waitForTimeout(1000);
    }

    const qmText = await safeText(page, QM_ROOT_SELECTOR);
    const qmDbText = await safeText(page, QM_PANEL_SELECTOR);
    const qmDbHtml = await safeHtml(page, QM_PANEL_SELECTOR);

    const search = {};
    for (const term of SEARCH_TERMS) {
      search[term] = {
        pageHtmlHasTerm: pageHtml.toLowerCase().includes(term.toLowerCase()),
        qmTextHasTerm: qmText.toLowerCase().includes(term.toLowerCase()),
        qmDbTextHasTerm: qmDbText.toLowerCase().includes(term.toLowerCase()),
        qmDbHtmlHasTerm: qmDbHtml.toLowerCase().includes(term.toLowerCase()),
        pageHtmlSnippet: snippet(pageHtml, term),
        qmTextSnippet: snippet(qmText, term),
        qmDbTextSnippet: snippet(qmDbText, term),
        qmDbHtmlSnippet: snippet(qmDbHtml, term),
      };
    }

    console.log(
      JSON.stringify(
        {
          authState: AUTH_STATE || null,
          targetUrl: TARGET_URL,
          url: page.url(),
          title: await page.title(),
          openedWith,
          dbPanelOpenedWith,
          qmRootSelector: QM_ROOT_SELECTOR,
          qmPanelSelector: QM_PANEL_SELECTOR,
          hasQMAdminBar: pageHtml.includes('query-monitor') || pageHtml.includes('wp-admin-bar-query-monitor'),
          hasQMPanel: pageHtml.includes('id="query-monitor-main"') || pageHtml.includes('qm-panel'),
          qmLinks,
          search,
        },
        null,
        2
      )
    );
  } finally {
    await browser.close();
  }
})();

