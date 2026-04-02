/**
 * WooCommerce Smart Coupons Targeted Load Test
 * Part of AI-DDTK - AI Driven Development ToolKit
 *
 * This script is intentionally narrower than woo-storefront.js. It targets the
 * scenario model from WP-WSC-PROFILE.md:
 *   1. homepage-empty-cart
 *   2. homepage-prepared-session
 *   3. coupon-url-homepage
 *   4. checkout-classic
 *
 * The goal is to amplify one known Smart Coupons reproducer under load after
 * Playwright or manual testing has already identified the real prep flow.
 *
 * Usage:
 *   k6-harness https://yoursite.local woo-smart-coupons.js
 *   k6-harness https://yoursite.local woo-smart-coupons.js --vus 20 --duration 30s
 *
 * Environment variables (injected by k6-harness or set manually):
 *   BASE_URL                 - Target site URL (required)
 *   SCENARIO                 - homepage-empty-cart | homepage-prepared-session |
 *                              coupon-url-homepage | checkout-classic
 *   HOME_PATH                - Default /
 *   CART_PATH                - Default /cart/
 *   CHECKOUT_PATH            - Default /checkout/
 *   PREP_URL                 - Exact prep URL/path for prepared-session scenarios
 *   ADD_TO_CART_URL          - Exact add-to-cart URL/path if no PREP_URL exists
 *   PRODUCT_ID               - Used to derive /?add-to-cart=<PRODUCT_ID> if needed
 *   COUPON_CODE              - Default binoid15
 *   COUPON_URL               - Exact coupon/share URL/path if known
 *   INTERMEDIATE_PATH        - Optional extra page hit between prep and final step
 *   EXPECTED_PREP_TEXT       - Optional marker expected on the prep response
 *   EXPECTED_INTERMEDIATE_TEXT - Optional marker expected on intermediate response
 *   EXPECTED_FINAL_TEXT      - Optional marker expected on the final response
 *   UNEXPECTED_FINAL_TEXT    - Optional marker that must NOT appear on final response
 *   THINK_TIME               - Default 1 second
 */

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const SCENARIO = __ENV.SCENARIO || 'homepage-empty-cart';
const HOME_PATH = __ENV.HOME_PATH || '/';
const CART_PATH = __ENV.CART_PATH || '/cart/';
const CHECKOUT_PATH = __ENV.CHECKOUT_PATH || '/checkout/';
const PREP_URL = __ENV.PREP_URL || '';
const ADD_TO_CART_URL = __ENV.ADD_TO_CART_URL || '';
const PRODUCT_ID = __ENV.PRODUCT_ID || '';
const COUPON_CODE = __ENV.COUPON_CODE || 'binoid15';
const COUPON_URL = __ENV.COUPON_URL || '';
const INTERMEDIATE_PATH = __ENV.INTERMEDIATE_PATH || '';
const EXPECTED_PREP_TEXT = parseList(__ENV.EXPECTED_PREP_TEXT || '');
const EXPECTED_INTERMEDIATE_TEXT = parseList(__ENV.EXPECTED_INTERMEDIATE_TEXT || '');
const EXPECTED_FINAL_TEXT = parseList(__ENV.EXPECTED_FINAL_TEXT || '');
const UNEXPECTED_FINAL_TEXT = parseList(__ENV.UNEXPECTED_FINAL_TEXT || '');
const THINK_TIME = Number(__ENV.THINK_TIME || 1);

const errorRate = new Rate('smart_coupons_errors');
const prepDuration = new Trend('smart_coupons_prep_duration', true);
const intermediateDuration = new Trend('smart_coupons_intermediate_duration', true);
const finalDuration = new Trend('smart_coupons_final_duration', true);
const scenarioDuration = new Trend('smart_coupons_scenario_duration', true);
const prepRequests = new Counter('smart_coupons_prep_requests_total');

export const options = {
  maxRedirects: 10,
  thresholds: {
    http_req_duration: ['p(95)<2000'],
    smart_coupons_errors: ['rate<0.05'],
  },
};

const defaultHeaders = {
  'User-Agent': 'AI-DDTK-k6/1.0 (smart-coupons-targeted-load-test)',
  'Accept': 'text/html,application/xhtml+xml,application/json',
};

function parseList(value) {
  return String(value)
    .split('|')
    .map((item) => item.trim())
    .filter(Boolean);
}

function abs(pathOrUrl) {
  return new URL(pathOrUrl, BASE_URL).toString();
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

function requestWithJar(jar, pathOrUrl, name) {
  return http.get(abs(pathOrUrl), {
    headers: defaultHeaders,
    jar: jar,
    redirects: 10,
    tags: {
      name: name,
      scenario: SCENARIO,
    },
  });
}

function containsAny(body, markers) {
  if (!markers.length) {
    return true;
  }

  const text = String(body || '');
  return markers.some((marker) => text.includes(marker));
}

function noFatalError(body) {
  const text = String(body || '');
  return !text.includes('Fatal error') && !text.includes('There has been a critical error');
}

function evaluateResponse(res, label, trend, expectedMarkers = [], unexpectedMarkers = []) {
  if (trend) {
    trend.add(res.timings.duration);
  }

  const assertions = {
    [`${label} returns < 400`]: (r) => r.status >= 200 && r.status < 400,
    [`${label} has body`]: (r) => typeof r.body === 'string' && r.body.length > 0,
    [`${label} has no fatal error`]: (r) => noFatalError(r.body),
  };

  if (expectedMarkers.length > 0) {
    assertions[`${label} has expected marker`] = (r) => containsAny(r.body, expectedMarkers);
  }

  if (unexpectedMarkers.length > 0) {
    assertions[`${label} omits unexpected marker`] = (r) => !containsAny(r.body, unexpectedMarkers);
  }

  const ok = check(res, assertions);
  errorRate.add(!ok);
  return ok;
}

function defaultFinalMarkers() {
  switch (SCENARIO) {
    case 'checkout-classic':
      return ['woocommerce-checkout', 'checkout', 'billing_email'];
    default:
      return [];
  }
}

function defaultCartMarkers() {
  return ['woocommerce-cart', 'cart'];
}

export function setup() {
  const prepTarget = resolvePrepTarget();
  const couponTarget = resolveCouponTarget();

  if (SCENARIO === 'homepage-prepared-session' || SCENARIO === 'checkout-classic') {
    if (!prepTarget) {
      throw new Error(
        `Scenario "${SCENARIO}" requires PREP_URL, ADD_TO_CART_URL, or PRODUCT_ID`
      );
    }
  }

  if (SCENARIO === 'coupon-url-homepage' && !couponTarget) {
    throw new Error('Scenario "coupon-url-homepage" requires COUPON_URL or COUPON_CODE');
  }

  console.log(
    JSON.stringify(
      {
        script: 'woo-smart-coupons.js',
        scenario: SCENARIO,
        baseUrl: BASE_URL,
        prepTarget: prepTarget || null,
        couponTarget: couponTarget || null,
        intermediatePath: INTERMEDIATE_PATH || null,
      },
      null,
      2
    )
  );

  return {
    prepTarget: prepTarget,
    couponTarget: couponTarget,
  };
}

export default function (data) {
  const jar = new http.CookieJar();
  const start = Date.now();

  group(`Smart Coupons: ${SCENARIO}`, () => {
    switch (SCENARIO) {
      case 'homepage-empty-cart': {
        const res = requestWithJar(jar, HOME_PATH, 'SC Homepage');
        evaluateResponse(
          res,
          'homepage',
          finalDuration,
          EXPECTED_FINAL_TEXT,
          UNEXPECTED_FINAL_TEXT
        );
        break;
      }

      case 'homepage-prepared-session': {
        const prepRes = requestWithJar(jar, data.prepTarget, 'SC Prep');
        prepRequests.add(1);
        evaluateResponse(prepRes, 'prep', prepDuration, EXPECTED_PREP_TEXT);

        if (INTERMEDIATE_PATH) {
          const intermediateRes = requestWithJar(jar, INTERMEDIATE_PATH, 'SC Intermediate');
          evaluateResponse(
            intermediateRes,
            'intermediate',
            intermediateDuration,
            EXPECTED_INTERMEDIATE_TEXT
          );
        }

        const homeRes = requestWithJar(jar, HOME_PATH, 'SC Homepage After Prep');
        evaluateResponse(
          homeRes,
          'homepage after prep',
          finalDuration,
          EXPECTED_FINAL_TEXT,
          UNEXPECTED_FINAL_TEXT
        );
        break;
      }

      case 'coupon-url-homepage': {
        const couponRes = requestWithJar(jar, data.couponTarget, 'SC Coupon URL');
        prepRequests.add(1);
        evaluateResponse(couponRes, 'coupon URL', prepDuration, EXPECTED_PREP_TEXT);

        if (INTERMEDIATE_PATH) {
          const intermediateRes = requestWithJar(jar, INTERMEDIATE_PATH, 'SC Intermediate');
          evaluateResponse(
            intermediateRes,
            'intermediate',
            intermediateDuration,
            EXPECTED_INTERMEDIATE_TEXT
          );
        } else {
          const cartRes = requestWithJar(jar, CART_PATH, 'SC Cart');
          evaluateResponse(
            cartRes,
            'cart',
            intermediateDuration,
            EXPECTED_INTERMEDIATE_TEXT.length ? EXPECTED_INTERMEDIATE_TEXT : defaultCartMarkers()
          );
        }

        const homeRes = requestWithJar(jar, HOME_PATH, 'SC Homepage After Coupon');
        evaluateResponse(
          homeRes,
          'homepage after coupon',
          finalDuration,
          EXPECTED_FINAL_TEXT,
          UNEXPECTED_FINAL_TEXT
        );
        break;
      }

      case 'checkout-classic': {
        const prepRes = requestWithJar(jar, data.prepTarget, 'SC Prep');
        prepRequests.add(1);
        evaluateResponse(prepRes, 'prep', prepDuration, EXPECTED_PREP_TEXT);

        if (INTERMEDIATE_PATH) {
          const intermediateRes = requestWithJar(jar, INTERMEDIATE_PATH, 'SC Intermediate');
          evaluateResponse(
            intermediateRes,
            'intermediate',
            intermediateDuration,
            EXPECTED_INTERMEDIATE_TEXT
          );
        } else {
          const cartRes = requestWithJar(jar, CART_PATH, 'SC Cart');
          evaluateResponse(
            cartRes,
            'cart',
            intermediateDuration,
            EXPECTED_INTERMEDIATE_TEXT.length ? EXPECTED_INTERMEDIATE_TEXT : defaultCartMarkers()
          );
        }

        const checkoutRes = requestWithJar(jar, CHECKOUT_PATH, 'SC Checkout');
        evaluateResponse(
          checkoutRes,
          'checkout',
          finalDuration,
          EXPECTED_FINAL_TEXT.length ? EXPECTED_FINAL_TEXT : defaultFinalMarkers(),
          UNEXPECTED_FINAL_TEXT
        );
        break;
      }

      default:
        throw new Error(`Unknown SCENARIO: ${SCENARIO}`);
    }
  });

  scenarioDuration.add(Date.now() - start);
  sleep(THINK_TIME);
}

function metricValue(data, name, key) {
  const metric = data.metrics[name];
  if (!metric || !metric.values || metric.values[key] === undefined) {
    return null;
  }

  return metric.values[key];
}

function formatValue(value, suffix = '') {
  return value === null ? 'n/a' : `${value}${suffix}`;
}

export function handleSummary(data) {
  const summary = {
    tool: 'AI-DDTK k6 harness',
    script: 'woo-smart-coupons.js',
    target: BASE_URL,
    scenario: SCENARIO,
    timestamp: new Date().toISOString(),
    config: {
      home_path: HOME_PATH,
      cart_path: CART_PATH,
      checkout_path: CHECKOUT_PATH,
      prep_url: PREP_URL || null,
      add_to_cart_url: ADD_TO_CART_URL || null,
      product_id: PRODUCT_ID || null,
      coupon_code: COUPON_CODE || null,
      coupon_url: COUPON_URL || null,
      intermediate_path: INTERMEDIATE_PATH || null,
    },
    metrics: {
      http_reqs: metricValue(data, 'http_reqs', 'count'),
      http_req_duration_p95: metricValue(data, 'http_req_duration', 'p(95)'),
      error_rate: metricValue(data, 'smart_coupons_errors', 'rate'),
      prep_requests_total: metricValue(data, 'smart_coupons_prep_requests_total', 'count'),
      prep_p95: metricValue(data, 'smart_coupons_prep_duration', 'p(95)'),
      intermediate_p95: metricValue(data, 'smart_coupons_intermediate_duration', 'p(95)'),
      final_p95: metricValue(data, 'smart_coupons_final_duration', 'p(95)'),
      scenario_p95: metricValue(data, 'smart_coupons_scenario_duration', 'p(95)'),
    },
  };

  const stdout = [
    'Smart Coupons targeted summary',
    `scenario: ${SCENARIO}`,
    `target: ${BASE_URL}`,
    `http_reqs: ${formatValue(summary.metrics.http_reqs)}`,
    `http_req_duration p95: ${formatValue(summary.metrics.http_req_duration_p95, 'ms')}`,
    `error_rate: ${formatValue(summary.metrics.error_rate)}`,
    `prep_requests_total: ${formatValue(summary.metrics.prep_requests_total)}`,
    `prep p95: ${formatValue(summary.metrics.prep_p95, 'ms')}`,
    `intermediate p95: ${formatValue(summary.metrics.intermediate_p95, 'ms')}`,
    `final p95: ${formatValue(summary.metrics.final_p95, 'ms')}`,
    `scenario p95: ${formatValue(summary.metrics.scenario_p95, 'ms')}`,
    '',
  ].join('\n');

  return {
    stdout: stdout,
    'woo-smart-coupons-summary.json': JSON.stringify(summary, null, 2),
  };
}
