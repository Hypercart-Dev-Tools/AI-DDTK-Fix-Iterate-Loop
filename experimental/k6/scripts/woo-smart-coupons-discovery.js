/**
 * WooCommerce Smart Coupons Playwright Discovery Helper
 * Part of AI-DDTK - AI Driven Development ToolKit
 *
 * This script mirrors the Smart Coupons k6 scenario names so you can discover
 * the real storefront flow before translating it into the HTTP-only load test.
 *
 * Usage:
 *   node experimental/k6/scripts/woo-smart-coupons-discovery.js
 *
 * Environment variables:
 *   BASE_URL or WP_SITE_URL  - Target site URL
 *   SCENARIO                 - homepage-empty-cart | homepage-prepared-session |
 *                              coupon-url-homepage | checkout-classic
 *   HOME_PATH                - Default /
 *   CART_PATH                - Default /cart/
 *   CHECKOUT_PATH            - Default /checkout/
 *   PREP_URL                 - Exact prep URL/path
 *   ADD_TO_CART_URL          - Exact add-to-cart URL/path if no PREP_URL exists
 *   PRODUCT_ID               - Used to derive /?add-to-cart=<PRODUCT_ID> if needed
 *   COUPON_CODE              - Default binoid15
 *   COUPON_URL               - Exact coupon/share URL/path if known
 *   INTERMEDIATE_PATH        - Optional extra path between prep and final step
 *   EXPECTED_PREP_TEXT       - Optional expected marker(s), separated by |
 *   EXPECTED_INTERMEDIATE_TEXT - Optional expected marker(s), separated by |
 *   EXPECTED_FINAL_TEXT      - Optional expected marker(s), separated by |
 *   UNEXPECTED_FINAL_TEXT    - Optional forbidden marker(s), separated by |
 *   USE_AUTH_STATE           - true to load a Playwright storage state file
 *   WP_AUTH_FILE             - Auth state file path if USE_AUTH_STATE=true
 *   WP_HEADLESS              - false to run headed
 *   WP_TIMEOUT_MS            - Default 30000
 *   WAIT_AFTER_NAV_MS        - Extra wait after each navigation, default 1000
 *   TAKE_SCREENSHOT          - false to skip screenshots
 *   REPORT_DIR               - Output directory for JSON + screenshots
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { chromium } = require('../../../bin/pw-auth-helpers/require-playwright');

const BASE_URL = process.env.BASE_URL || process.env.WP_SITE_URL || 'http://my-test-site.local';
const SCENARIO = process.env.SCENARIO || 'homepage-empty-cart';
const HOME_PATH = process.env.HOME_PATH || '/';
const CART_PATH = process.env.CART_PATH || '/cart/';
const CHECKOUT_PATH = process.env.CHECKOUT_PATH || '/checkout/';
const PREP_URL = process.env.PREP_URL || '';
const ADD_TO_CART_URL = process.env.ADD_TO_CART_URL || '';
const PRODUCT_ID = process.env.PRODUCT_ID || '';
const COUPON_CODE = process.env.COUPON_CODE || 'binoid15';
const COUPON_URL = process.env.COUPON_URL || '';
const INTERMEDIATE_PATH = process.env.INTERMEDIATE_PATH || '';
const EXPECTED_PREP_TEXT = parseList(process.env.EXPECTED_PREP_TEXT || '');
const EXPECTED_INTERMEDIATE_TEXT = parseList(process.env.EXPECTED_INTERMEDIATE_TEXT || '');
const EXPECTED_FINAL_TEXT = parseList(process.env.EXPECTED_FINAL_TEXT || '');
const UNEXPECTED_FINAL_TEXT = parseList(process.env.UNEXPECTED_FINAL_TEXT || '');
const USE_AUTH_STATE = process.env.USE_AUTH_STATE === 'true';
const AUTH_FILE = process.env.WP_AUTH_FILE || path.resolve(__dirname, '../../../temp/playwright/.auth/admin.json');
const HEADLESS = process.env.WP_HEADLESS !== 'false';
const TIMEOUT_MS = Number(process.env.WP_TIMEOUT_MS || '30000');
const WAIT_AFTER_NAV_MS = Number(process.env.WAIT_AFTER_NAV_MS || '1000');
const TAKE_SCREENSHOT = process.env.TAKE_SCREENSHOT !== 'false';
const REPORT_DIR = process.env.REPORT_DIR || path.resolve(__dirname, '../../../temp/playwright/smart-coupons');

let currentStep = 'bootstrap';
const activity = [];

function parseList(value) {
  return String(value)
    .split('|')
    .map((item) => item.trim())
    .filter(Boolean);
}

function abs(pathOrUrl) {
  return new URL(pathOrUrl, BASE_URL).toString();
}

function safeName(value) {
  return String(value).replace(/[^a-zA-Z0-9-_]+/g, '-').replace(/^-+|-+$/g, '') || 'step';
}

function resolvePrepTarget() {
  if (PREP_URL) {
    return PREP_URL;
  }

  if (ADD_TO_CART_URL) {
    return ADD_TO_CART_URL;
  }

  if (PRODUCT_ID) {
    return `/?add-to-cart=${encodeURIComponent(PRODUCT_ID)}`;
  }

  return '';
}

function resolveCouponTarget() {
  if (COUPON_URL) {
    return COUPON_URL;
  }

  if (COUPON_CODE) {
    return `/?coupon-code=${encodeURIComponent(COUPON_CODE)}&sc-page=cart`;
  }

  return '';
}

function defaultCartMarkers() {
  return ['woocommerce-cart', 'cart'];
}

function defaultFinalMarkers() {
  switch (SCENARIO) {
    case 'checkout-classic':
      return ['woocommerce-checkout', 'checkout', 'billing_email'];
    default:
      return [];
  }
}

function buildMarkerResult(html, expectedMarkers, unexpectedMarkers) {
  const body = String(html || '');
  return {
    expected: expectedMarkers.map((marker) => ({
      marker,
      found: body.includes(marker),
    })),
    unexpected: unexpectedMarkers.map((marker) => ({
      marker,
      found: body.includes(marker),
    })),
  };
}

function requestChain(response) {
  if (!response) {
    return [];
  }

  const chain = [];
  let request = response.request();

  while (request) {
    chain.unshift({
      method: request.method(),
      url: request.url(),
    });
    request = request.redirectedFrom();
  }

  return chain;
}

function summarizeCookies(cookies) {
  return cookies.map((cookie) => ({
    name: cookie.name,
    domain: cookie.domain,
    path: cookie.path,
    expires: cookie.expires,
    httpOnly: cookie.httpOnly,
    secure: cookie.secure,
    sameSite: cookie.sameSite || null,
  }));
}

function attachActivityListener(page) {
  page.on('response', (response) => {
    try {
      const request = response.request();
      const resourceType = request.resourceType();
      if (resourceType !== 'document' && resourceType !== 'xhr' && resourceType !== 'fetch') {
        return;
      }

      activity.push({
        step: currentStep,
        url: response.url(),
        status: response.status(),
        method: request.method(),
        resourceType,
        navigation: request.isNavigationRequest(),
      });
    } catch (_) {
      // Ignore instrumentation failures and continue the scenario.
    }
  });
}

async function captureStep(page, context, label, target, expectedMarkers, unexpectedMarkers, runId) {
  currentStep = label;

  const resolvedUrl = abs(target);
  const startedAt = Date.now();
  const response = await page.goto(resolvedUrl, {
    waitUntil: 'networkidle',
    timeout: TIMEOUT_MS,
  });
  await page.waitForTimeout(WAIT_AFTER_NAV_MS);

  const html = await page.content();
  const title = await page.title();
  const cookies = summarizeCookies(await context.cookies(BASE_URL));
  const requests = activity.filter((entry) => entry.step === label);

  const step = {
    label,
    target,
    resolvedUrl,
    initialResponseUrl: response ? response.url() : null,
    initialStatus: response ? response.status() : null,
    finalUrl: page.url(),
    title,
    durationMs: Date.now() - startedAt,
    redirectChain: requestChain(response),
    markers: buildMarkerResult(html, expectedMarkers, unexpectedMarkers),
    cookies,
    requests,
  };

  if (TAKE_SCREENSHOT) {
    fs.mkdirSync(REPORT_DIR, { recursive: true });
    const screenshotPath = path.join(
      REPORT_DIR,
      `${runId}-${safeName(label)}.png`
    );
    await page.screenshot({ path: screenshotPath, fullPage: true });
    step.screenshotPath = screenshotPath;
  }

  return step;
}

async function runScenario(page, context, runId) {
  const prepTarget = resolvePrepTarget();
  const couponTarget = resolveCouponTarget();
  const steps = [];

  if ((SCENARIO === 'homepage-prepared-session' || SCENARIO === 'checkout-classic') && !prepTarget) {
    throw new Error(`Scenario "${SCENARIO}" requires PREP_URL, ADD_TO_CART_URL, or PRODUCT_ID`);
  }

  if (SCENARIO === 'coupon-url-homepage' && !couponTarget) {
    throw new Error('Scenario "coupon-url-homepage" requires COUPON_URL or COUPON_CODE');
  }

  switch (SCENARIO) {
    case 'homepage-empty-cart':
      steps.push(
        await captureStep(
          page,
          context,
          'homepage',
          HOME_PATH,
          EXPECTED_FINAL_TEXT,
          UNEXPECTED_FINAL_TEXT,
          runId
        )
      );
      break;

    case 'homepage-prepared-session':
      steps.push(
        await captureStep(page, context, 'prep', prepTarget, EXPECTED_PREP_TEXT, [], runId)
      );

      if (INTERMEDIATE_PATH) {
        steps.push(
          await captureStep(
            page,
            context,
            'intermediate',
            INTERMEDIATE_PATH,
            EXPECTED_INTERMEDIATE_TEXT,
            [],
            runId
          )
        );
      }

      steps.push(
        await captureStep(
          page,
          context,
          'homepage_after_prep',
          HOME_PATH,
          EXPECTED_FINAL_TEXT,
          UNEXPECTED_FINAL_TEXT,
          runId
        )
      );
      break;

    case 'coupon-url-homepage':
      steps.push(
        await captureStep(page, context, 'coupon_url', couponTarget, EXPECTED_PREP_TEXT, [], runId)
      );

      if (INTERMEDIATE_PATH) {
        steps.push(
          await captureStep(
            page,
            context,
            'intermediate',
            INTERMEDIATE_PATH,
            EXPECTED_INTERMEDIATE_TEXT,
            [],
            runId
          )
        );
      } else {
        steps.push(
          await captureStep(
            page,
            context,
            'cart',
            CART_PATH,
            EXPECTED_INTERMEDIATE_TEXT.length ? EXPECTED_INTERMEDIATE_TEXT : defaultCartMarkers(),
            [],
            runId
          )
        );
      }

      steps.push(
        await captureStep(
          page,
          context,
          'homepage_after_coupon',
          HOME_PATH,
          EXPECTED_FINAL_TEXT,
          UNEXPECTED_FINAL_TEXT,
          runId
        )
      );
      break;

    case 'checkout-classic':
      steps.push(
        await captureStep(page, context, 'prep', prepTarget, EXPECTED_PREP_TEXT, [], runId)
      );

      if (INTERMEDIATE_PATH) {
        steps.push(
          await captureStep(
            page,
            context,
            'intermediate',
            INTERMEDIATE_PATH,
            EXPECTED_INTERMEDIATE_TEXT,
            [],
            runId
          )
        );
      } else {
        steps.push(
          await captureStep(
            page,
            context,
            'cart',
            CART_PATH,
            EXPECTED_INTERMEDIATE_TEXT.length ? EXPECTED_INTERMEDIATE_TEXT : defaultCartMarkers(),
            [],
            runId
          )
        );
      }

      steps.push(
        await captureStep(
          page,
          context,
          'checkout',
          CHECKOUT_PATH,
          EXPECTED_FINAL_TEXT.length ? EXPECTED_FINAL_TEXT : defaultFinalMarkers(),
          UNEXPECTED_FINAL_TEXT,
          runId
        )
      );
      break;

    default:
      throw new Error(`Unknown SCENARIO: ${SCENARIO}`);
  }

  return {
    prepTarget: prepTarget || null,
    couponTarget: couponTarget || null,
    steps,
  };
}

(async () => {
  const runId = `${Date.now()}-${safeName(SCENARIO)}`;
  const browser = await chromium.launch({ headless: HEADLESS });
  const contextOptions = {
    ignoreHTTPSErrors: true,
  };

  if (USE_AUTH_STATE) {
    if (!fs.existsSync(AUTH_FILE)) {
      throw new Error(`Auth state file not found: ${AUTH_FILE}`);
    }
    contextOptions.storageState = AUTH_FILE;
  }

  const context = await browser.newContext(contextOptions);
  context.setDefaultTimeout(TIMEOUT_MS);
  const page = await context.newPage();
  page.setDefaultTimeout(TIMEOUT_MS);
  attachActivityListener(page);

  try {
    const scenarioResult = await runScenario(page, context, runId);
    const report = {
      tool: 'AI-DDTK Playwright discovery helper',
      script: 'woo-smart-coupons-discovery.js',
      timestamp: new Date().toISOString(),
      runId,
      scenario: SCENARIO,
      baseUrl: BASE_URL,
      useAuthState: USE_AUTH_STATE,
      authFile: USE_AUTH_STATE ? AUTH_FILE : null,
      config: {
        homePath: HOME_PATH,
        cartPath: CART_PATH,
        checkoutPath: CHECKOUT_PATH,
        prepUrl: PREP_URL || null,
        addToCartUrl: ADD_TO_CART_URL || null,
        productId: PRODUCT_ID || null,
        couponCode: COUPON_CODE || null,
        couponUrl: COUPON_URL || null,
        intermediatePath: INTERMEDIATE_PATH || null,
      },
      prepTarget: scenarioResult.prepTarget,
      couponTarget: scenarioResult.couponTarget,
      steps: scenarioResult.steps,
      finalCookies: summarizeCookies(await context.cookies(BASE_URL)),
    };

    fs.mkdirSync(REPORT_DIR, { recursive: true });
    const reportPath = path.join(REPORT_DIR, `${runId}.json`);
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    report.reportPath = reportPath;

    console.log(JSON.stringify(report, null, 2));
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(`\n[woo-smart-coupons-discovery] ${error.message}\n`);
  process.exit(1);
});
