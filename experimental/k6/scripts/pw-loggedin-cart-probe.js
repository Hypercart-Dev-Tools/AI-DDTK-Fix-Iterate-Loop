const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const base = 'http://binoid-production-2026-03-31.local';
const storageState = path.join(__dirname, 'playwright/.auth/binoidcbd.json');

async function summarize(page, label) {
  await page.waitForTimeout(2500);
  const body = (await page.textContent('body')) || '';
  console.log(`=== ${label} ===`);
  console.log('URL', page.url());
  console.log('HAS_PRODUCT', body.includes('Delta 9 THC Marshmellow'));
  console.log('HAS_EMPTY', body.includes('Your cart is currently empty'));
  console.log('HAS_BINOID15', body.toLowerCase().includes('binoid15'));
}

(async () => {
  console.log('STEP', 'start');
  console.log('STORAGE_STATE', storageState);
  console.log('STORAGE_EXISTS', fs.existsSync(storageState));
  const browser = await chromium.launch({ headless: true });
  console.log('STEP', 'browser-launched');
  const context = await browser.newContext({ storageState });
  console.log('STEP', 'context-created');
  const page = await context.newPage();
  console.log('STEP', 'page-created');
  page.setDefaultTimeout(60000);
  page.setDefaultNavigationTimeout(30000);

  try {
    console.log('STEP', 'goto-home');
    await page.goto(base, { waitUntil: 'domcontentloaded', timeout: 30000 });
    console.log('STEP', 'home-loaded');

    console.log('STEP', 'ajax-add');
    const result = await page.evaluate(async currentBase => {
      const body = new URLSearchParams({ product_id: '13444430', quantity: '1' });
      const response = await fetch(`${currentBase}/?wc-ajax=add_to_cart`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
        body: body.toString(),
        credentials: 'same-origin',
      });
      return { status: response.status, text: await response.text() };
    }, base);

    console.log('AJAX_STATUS', result.status);
    console.log('AJAX_HAS_FRAGMENTS', result.text.includes('widget_shopping_cart_content'));

    console.log('STEP', 'goto-cart');
    await page.goto(`${base}/cart`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await summarize(page, 'cart-after-ajax');

    console.log('STEP', 'goto-coupon-url');
    await page.goto(`${base}/?coupon-code=binoid15&sc-page=cart`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await summarize(page, 'coupon-url-after-ajax');
  } catch (error) {
    console.log('ERROR', error.stack || String(error));
  } finally {
    console.log('STEP', 'closing-browser');
    await browser.close();
  }
})();

