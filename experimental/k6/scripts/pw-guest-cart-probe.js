const { chromium } = require('playwright');

const base = 'http://binoid-production-2026-03-31.local';
const productUrl = `${base}/collections/gummies/products/delta-9-thc-marshmallows?convert_to_sub_13444430=0`;

async function summarize(page, label) {
  await page.waitForTimeout(2500);
  const body = (await page.textContent('body')) || '';
  const totals = await page.evaluate(() => {
    try {
      return globalThis.dataLayer_content?.cartContent?.totals || null;
    } catch {
      return null;
    }
  });
  console.log(`=== ${label} ===`);
  console.log('URL', page.url());
  console.log('HAS_PRODUCT', body.includes('Delta 9 THC Marshmellow'));
  console.log('HAS_EMPTY', body.includes('Your cart is currently empty'));
  console.log('HAS_BINOID15', body.toLowerCase().includes('binoid15'));
  console.log('TOTALS', JSON.stringify(totals));
  console.log('BODY_SNIP', body.replace(/\s+/g, ' ').slice(0, 500));
}

async function runClickScenario() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();
  page.setDefaultTimeout(60000);
  try {
    await page.goto(productUrl, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(3000);
    const button = page.locator('button.single_add_to_cart_button, .single_add_to_cart_button, button[name="add-to-cart"], form.cart button[type="submit"]').first();
    console.log('CLICK_BUTTON_COUNT', await button.count());
    await button.click();
    await page.waitForTimeout(5000);
    await summarize(page, 'after-click-product-page');
    const cookies = await context.cookies();
    console.log('COOKIES', cookies.map(c => c.name).sort().join(','));
    await page.goto(`${base}/cart`, { waitUntil: 'domcontentloaded' });
    await summarize(page, 'cart-after-click');
    await page.goto(`${base}/?coupon-code=binoid15&sc-page=cart`, { waitUntil: 'domcontentloaded' });
    await summarize(page, 'coupon-url-after-click');
  } catch (error) {
    console.log('CLICK_SCENARIO_ERROR', error.stack || String(error));
  } finally {
    await browser.close();
  }
}

async function runAjaxScenario() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();
  page.setDefaultTimeout(60000);
  try {
    await page.goto(base, { waitUntil: 'domcontentloaded' });
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
    console.log('AJAX_SNIP', result.text.slice(0, 300));
    const cookies = await context.cookies();
    console.log('COOKIES', cookies.map(c => c.name).sort().join(','));
    await page.goto(`${base}/cart`, { waitUntil: 'domcontentloaded' });
    await summarize(page, 'cart-after-ajax');
    await page.goto(`${base}/?coupon-code=binoid15&sc-page=cart`, { waitUntil: 'domcontentloaded' });
    await summarize(page, 'coupon-url-after-ajax');
  } catch (error) {
    console.log('AJAX_SCENARIO_ERROR', error.stack || String(error));
  } finally {
    await browser.close();
  }
}

(async () => {
  await runClickScenario();
  await runAjaxScenario();
})();

