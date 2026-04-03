const { chromium } = require('playwright');
const path = require('path');

const AUTH_STATE = path.resolve(process.env.AUTH_STATE || 'temp/playwright/.auth/binoidcbd.json');
const TARGET_URL = process.env.TARGET_URL || 'http://binoid-production-2026-03-31.local/';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    storageState: AUTH_STATE,
    ignoreHTTPSErrors: true,
  });

  const page = await context.newPage();
  page.setDefaultTimeout(60000);
  page.setDefaultNavigationTimeout(60000);

  await page.goto(TARGET_URL, { waitUntil: 'networkidle' });

  const html = await page.content();
  const qmLinks = await page.evaluate(() =>
    Array.from(document.querySelectorAll('a[href*="#qm"]'))
      .map((a) => a.getAttribute('href'))
      .filter(Boolean)
      .slice(0, 20)
  );
  const qmToggle = page.locator('#wp-admin-bar-query-monitor a').first();
  if (await qmToggle.count()) {
    await qmToggle.click().catch(() => {});
    await page.waitForTimeout(1000);
  }

  const qmText = (await page.locator('#query-monitor-main').innerText().catch(() => '')) || '';
  const qmDbLink = page.locator('a[href="#qm-db_queries"]').first();
  if (await qmDbLink.count()) {
    await qmDbLink.click().catch(() => {});
    await page.waitForTimeout(1000);
  }
  const qmDbText = (await page.locator('#qm-db_queries').innerText().catch(() => '')) || '';
  const qmDbHtml = (await page.locator('#qm-db_queries').innerHTML().catch(() => '')) || '';
  const shopCouponIndex = qmText.toLowerCase().indexOf('shop_coupon');
  const dbBinoidIndex = qmDbText.toLowerCase().indexOf('binoid15');
  const dbWpPostsIndex = qmDbHtml.toLowerCase().indexOf('wp_posts');
  const result = {
    authState: AUTH_STATE,
    targetUrl: TARGET_URL,
    url: page.url(),
    title: await page.title(),
    hasQMAdminBar: html.includes('query-monitor') || html.includes('wp-admin-bar-query-monitor'),
    hasQMPanel: html.includes('id="query-monitor-main"') || html.includes('qm-panel'),
    hasCouponQueryText: html.toLowerCase().includes('binoid15') && html.toLowerCase().includes('shop_coupon'),
    hasSelectSnippet: html.includes('SELECT wp_posts.ID FROM wp_posts'),
    qmTextHasBinoid15: qmText.toLowerCase().includes('binoid15'),
    qmTextHasShopCoupon: qmText.toLowerCase().includes('shop_coupon'),
    qmTextHasSelectSnippet: qmText.includes('SELECT wp_posts.ID FROM wp_posts'),
    qmShopCouponSnippet:
      shopCouponIndex >= 0 ? qmText.slice(Math.max(0, shopCouponIndex - 120), shopCouponIndex + 240) : '',
    qmDbTextHasBinoid15: qmDbText.toLowerCase().includes('binoid15'),
    qmDbTextHasShopCoupon: qmDbText.toLowerCase().includes('shop_coupon'),
    qmDbTextHasSelectSnippet: qmDbText.includes('SELECT wp_posts.ID FROM wp_posts'),
    qmDbHtmlHasBinoid15: qmDbHtml.toLowerCase().includes('binoid15'),
    qmDbHtmlHasShopCoupon: qmDbHtml.toLowerCase().includes('shop_coupon'),
    qmDbHtmlHasWpPosts: qmDbHtml.toLowerCase().includes('wp_posts'),
    qmDbHtmlHasSelect: qmDbHtml.includes('SELECT'),
    qmDbSnippet:
      dbBinoidIndex >= 0 ? qmDbText.slice(Math.max(0, dbBinoidIndex - 120), dbBinoidIndex + 300) : '',
    qmDbWpPostsSnippet:
      dbWpPostsIndex >= 0 ? qmDbHtml.slice(Math.max(0, dbWpPostsIndex - 180), dbWpPostsIndex + 360) : '',
    qmLinks,
  };

  console.log(JSON.stringify(result, null, 2));
  await browser.close();
})();

