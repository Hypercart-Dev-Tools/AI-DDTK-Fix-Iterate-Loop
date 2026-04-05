const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

// Load .env from script directory (see .env.example)
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.+?)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}

const base = process.env.WP_URL;
const storageState = process.env.AUTH_STATE_PATH || path.join(__dirname, 'playwright/.auth/admin.json');
const productId = process.env.PRODUCT_ID;
const coupon = process.env.COUPON;

async function summarize(page, label) {
  await page.waitForTimeout(2500);
  const body = (await page.textContent('body')) || '';
  console.log(`=== ${label} ===`);
  console.log('URL', page.url());
  console.log('HAS_PRODUCT', body.includes('Delta 9 THC Marshmellow'));
  console.log('HAS_EMPTY', body.includes('Your cart is currently empty'));
  console.log('HAS_COUPON', body.toLowerCase().includes(coupon.toLowerCase()));
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
    const result = await page.evaluate(async ({ currentBase, pid }) => {
      const body = new URLSearchParams({ product_id: pid, quantity: '1' });
      const response = await fetch(`${currentBase}/?wc-ajax=add_to_cart`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
        body: body.toString(),
        credentials: 'same-origin',
      });
      return { status: response.status, text: await response.text() };
    }, { currentBase: base, pid: productId });

    console.log('AJAX_STATUS', result.status);
    console.log('AJAX_HAS_FRAGMENTS', result.text.includes('widget_shopping_cart_content'));

    console.log('STEP', 'goto-cart');
    await page.goto(`${base}/cart`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await summarize(page, 'cart-after-ajax');

    console.log('STEP', 'goto-coupon-url');
    await page.goto(`${base}/?coupon-code=${encodeURIComponent(coupon)}&sc-page=cart`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await summarize(page, 'coupon-url-after-ajax');
  } catch (error) {
    console.log('ERROR', error.stack || String(error));
  } finally {
    console.log('STEP', 'closing-browser');
    await browser.close();
  }
})();

