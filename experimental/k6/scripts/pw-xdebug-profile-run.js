const { chromium } = require('playwright');
const path = require('path');

const BASE = 'http://binoid-production-2026-03-31.local';
const HOST = 'binoid-production-2026-03-31.local';
const MODE = process.env.MODE || 'full';
const AUTH_STATE = path.resolve(process.env.AUTH_STATE || 'temp/playwright/.auth/binoidcbd.json');
const OUTPUT_STATE = process.env.OUTPUT_STATE ? path.resolve(process.env.OUTPUT_STATE) : '';
const TARGET_URL = process.env.TARGET_URL || `${BASE}/`;
const ENABLE_XDEBUG = process.env.XDEBUG === '1';

async function addToCart(page) {
  return page.evaluate(async currentBase => {
    const body = new URLSearchParams({ product_id: '13444430', quantity: '1' });
    const response = await fetch(`${currentBase}/?wc-ajax=add_to_cart`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
      body: body.toString(),
      credentials: 'same-origin',
    });
    return { status: response.status, text: await response.text() };
  }, BASE);
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    storageState: AUTH_STATE,
    ignoreHTTPSErrors: true,
  });

  if (ENABLE_XDEBUG) {
    await context.addCookies([
      { name: 'XDEBUG_PROFILE', value: '1', domain: HOST, path: '/' },
      { name: 'XDEBUG_TRIGGER', value: '1', domain: HOST, path: '/' },
      { name: 'XDEBUG_SESSION', value: '1', domain: HOST, path: '/' },
    ]);
  }

  const page = await context.newPage();
  page.setDefaultTimeout(60000);
  page.setDefaultNavigationTimeout(60000);

  const result = {
    mode: MODE,
    authState: AUTH_STATE,
    outputState: OUTPUT_STATE,
    targetUrl: TARGET_URL,
    xdebug: ENABLE_XDEBUG,
    steps: [],
    documents: [],
    finalUrl: '',
    finalTitle: '',
    bodyHasProduct: false,
    bodyHasBinoid15: false,
  };

  page.on('response', async response => {
    const request = response.request();
    if (request.resourceType() !== 'document') return;
    result.documents.push({
      requestUrl: request.url(),
      responseUrl: response.url(),
      status: response.status(),
      location: response.headers()['location'] || '',
    });
  });

  try {
    if (MODE === 'prepare-cart') {
      await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' });
      result.steps.push('home');
      const add = await addToCart(page);
      result.steps.push(`add:${add.status}`);
      result.addHasFragments = add.text.includes('widget_shopping_cart_content');
    } else if (MODE === 'profile-coupon-url') {
      await page.goto(TARGET_URL, { waitUntil: 'networkidle' });
      result.steps.push('coupon-url');
    } else if (MODE === 'profile-home') {
      await page.goto(TARGET_URL, { waitUntil: 'networkidle' });
      result.steps.push('home-after-coupon');
    } else {
      await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' });
      result.steps.push('home');
      const add = await addToCart(page);
      result.steps.push(`add:${add.status}`);
      result.addHasFragments = add.text.includes('widget_shopping_cart_content');
      await page.goto(`${BASE}/?coupon-code=binoid15&sc-page=cart`, { waitUntil: 'networkidle' });
      result.steps.push('coupon-url');
      await page.goto(`${BASE}/`, { waitUntil: 'networkidle' });
      result.steps.push('home-after-coupon');
    }

    if (OUTPUT_STATE) {
      await context.storageState({ path: OUTPUT_STATE });
    }

    const body = (await page.textContent('body').catch(() => '')) || '';
    result.finalUrl = page.url();
    result.finalTitle = await page.title();
    result.bodyHasProduct = body.includes('Delta 9 THC Marshmellow');
    result.bodyHasBinoid15 = body.toLowerCase().includes('binoid15');

    console.log(JSON.stringify(result, null, 2));
  } finally {
    await browser.close();
  }
})();

