/**
 * Reusable Playwright runner for request-scoped profiling and redirect tracing.
 *
 * Configure with environment variables instead of editing the file directly.
 * Useful for WooCommerce / WordPress investigations where you need to:
 * - prepare a session,
 * - hit a coupon/share URL,
 * - isolate one target request,
 * - or trigger Xdebug cookies before the run.
 *
 * Common env vars:
 * - BASE_URL, AUTH_STATE, OUTPUT_STATE, TARGET_URL
 * - MODE=full|prepare-cart|profile-coupon-url|profile-home|custom
 * - STEP_SEQUENCE=home,add-to-cart-ajax,coupon-url,target
 * - PRODUCT_ID, QUANTITY, ADD_TO_CART_URL, ADD_TO_CART_AJAX_PATH
 * - COUPON_CODE or COUPON_URL
 * - HOME_PATH, CART_PATH, WAIT_UNTIL, TIMEOUT_MS, HEADLESS
 * - XDEBUG=1, XDEBUG_COOKIE_NAMES, XDEBUG_COOKIE_VALUE
 * - BODY_MARKERS=product::My Product,coupon::binoid15
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

function boolEnv(value, fallback = true) {
  if (value == null || value === '') return fallback;
  return !['0', 'false', 'no'].includes(String(value).toLowerCase());
}

function trimSlash(value) {
  return String(value || '').replace(/\/+$/, '');
}

function abs(baseUrl, pathOrUrl) {
  if (!pathOrUrl) return '';
  if (/^https?:\/\//.test(pathOrUrl)) return pathOrUrl;
  return `${trimSlash(baseUrl)}${pathOrUrl.startsWith('/') ? '' : '/'}${pathOrUrl}`;
}

function parseMarkers(raw) {
  return String(raw || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item) => {
      const [label, ...rest] = item.split('::');
      return { label: label.trim(), needle: (rest.join('::') || label).trim() };
    });
}

function defaultSequence(mode) {
  switch (mode) {
    case 'prepare-cart':
      return ['home', 'add-to-cart-ajax'];
    case 'profile-coupon-url':
      return ['coupon-url'];
    case 'profile-home':
      return ['target'];
    case 'custom':
      return [];
    default:
      return ['home', 'add-to-cart-ajax', 'coupon-url', 'target'];
  }
}

const BASE_URL = trimSlash(process.env.BASE_URL || 'http://localhost');
const MODE = process.env.MODE || 'full';
const AUTH_STATE = process.env.AUTH_STATE ? path.resolve(process.env.AUTH_STATE) : '';
const OUTPUT_STATE = process.env.OUTPUT_STATE ? path.resolve(process.env.OUTPUT_STATE) : '';
const HOME_URL = abs(BASE_URL, process.env.HOME_PATH || '/');
const CART_URL = abs(BASE_URL, process.env.CART_PATH || '/cart');
const TARGET_URL = abs(BASE_URL, process.env.TARGET_URL || process.env.HOME_PATH || '/');
const COUPON_URL = abs(
  BASE_URL,
  process.env.COUPON_URL ||
    (process.env.COUPON_CODE ? `/?coupon-code=${encodeURIComponent(process.env.COUPON_CODE)}&sc-page=cart` : '')
);
const ADD_TO_CART_URL = abs(
  BASE_URL,
  process.env.ADD_TO_CART_URL || (process.env.PRODUCT_ID ? `/?add-to-cart=${encodeURIComponent(process.env.PRODUCT_ID)}` : '')
);
const STEP_SEQUENCE = (process.env.STEP_SEQUENCE || defaultSequence(MODE).join(','))
  .split(',')
  .map((step) => step.trim())
  .filter(Boolean);

async function addToCartAjax(page) {
  if (!process.env.PRODUCT_ID) {
    throw new Error('PRODUCT_ID is required for the add-to-cart-ajax step.');
  }

  return page.evaluate(
    async ({ baseUrl, ajaxPath, productId, quantity }) => {
      const body = new URLSearchParams({ product_id: productId, quantity });
      const response = await fetch(`${baseUrl}${ajaxPath}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
        body: body.toString(),
        credentials: 'same-origin',
      });
      return { status: response.status, text: await response.text() };
    },
    {
      baseUrl: BASE_URL,
      ajaxPath: process.env.ADD_TO_CART_AJAX_PATH || '/?wc-ajax=add_to_cart',
      productId: String(process.env.PRODUCT_ID),
      quantity: String(process.env.QUANTITY || '1'),
    }
  );
}

(async () => {
  const browser = await chromium.launch({ headless: boolEnv(process.env.HEADLESS, true) });
  const contextOptions = { ignoreHTTPSErrors: true };
  if (AUTH_STATE && fs.existsSync(AUTH_STATE)) {
    contextOptions.storageState = AUTH_STATE;
  }

  const context = await browser.newContext(contextOptions);
  const host = new URL(BASE_URL).hostname;

  if (boolEnv(process.env.XDEBUG, false)) {
    const cookieNames = String(process.env.XDEBUG_COOKIE_NAMES || 'XDEBUG_PROFILE,XDEBUG_TRIGGER,XDEBUG_SESSION')
      .split(',')
      .map((name) => name.trim())
      .filter(Boolean);
    await context.addCookies(
      cookieNames.map((name) => ({
        name,
        value: process.env.XDEBUG_COOKIE_VALUE || '1',
        domain: host,
        path: '/',
      }))
    );
  }

  const page = await context.newPage();
  const waitUntil = process.env.WAIT_UNTIL || 'networkidle';
  const timeoutMs = Number(process.env.TIMEOUT_MS || 60000);
  const markers = parseMarkers(process.env.BODY_MARKERS || '');
  page.setDefaultTimeout(timeoutMs);
  page.setDefaultNavigationTimeout(timeoutMs);

  const result = {
    mode: MODE,
    stepSequence: STEP_SEQUENCE,
    authState: AUTH_STATE || null,
    outputState: OUTPUT_STATE || null,
    targetUrl: TARGET_URL,
    xdebug: boolEnv(process.env.XDEBUG, false),
    steps: [],
    documents: [],
    finalUrl: '',
    finalTitle: '',
    bodyMarkers: {},
  };

  page.on('response', async (response) => {
    const request = response.request();
    if (request.resourceType() !== 'document') return;
    result.documents.push({
      requestUrl: request.url(),
      responseUrl: response.url(),
      status: response.status(),
      location: response.headers().location || '',
    });
  });

  async function gotoStep(label, url) {
    if (!url) throw new Error(`Missing URL for step: ${label}`);
    await page.goto(url, { waitUntil });
    result.steps.push({ step: label, url: page.url(), status: 'navigated' });
  }

  try {
    for (const step of STEP_SEQUENCE) {
      switch (step) {
        case 'home':
          await gotoStep('home', HOME_URL);
          break;
        case 'cart':
          await gotoStep('cart', CART_URL);
          break;
        case 'coupon-url':
          await gotoStep('coupon-url', COUPON_URL);
          break;
        case 'target':
          await gotoStep('target', TARGET_URL);
          break;
        case 'add-to-cart-get':
          await gotoStep('add-to-cart-get', ADD_TO_CART_URL);
          break;
        case 'add-to-cart-ajax': {
          const add = await addToCartAjax(page);
          result.steps.push({
            step: 'add-to-cart-ajax',
            status: add.status,
            hasFragments: add.text.includes('widget_shopping_cart_content'),
          });
          break;
        }
        case 'wait':
          await page.waitForTimeout(Number(process.env.WAIT_MS || 1500));
          result.steps.push({ step: 'wait', ms: Number(process.env.WAIT_MS || 1500) });
          break;
        default:
          throw new Error(`Unknown STEP_SEQUENCE step: ${step}`);
      }
    }

    if (OUTPUT_STATE) {
      await context.storageState({ path: OUTPUT_STATE });
    }

    const body = (await page.textContent('body').catch(() => '')) || '';
    result.finalUrl = page.url();
    result.finalTitle = await page.title();
    for (const marker of markers) {
      result.bodyMarkers[marker.label] = body.toLowerCase().includes(marker.needle.toLowerCase());
    }

    console.log(JSON.stringify(result, null, 2));
  } finally {
    await browser.close();
  }
})();

