/**
 * WooCommerce Storefront Load Test
 * Part of AI-DDTK - AI Driven Development ToolKit
 *
 * Simulates a realistic customer journey through a WooCommerce store:
 *   1. Browse shop page (product listing)
 *   2. View product detail page
 *   3. Add product to cart (via WooCommerce AJAX endpoint)
 *   4. View cart page
 *   5. Load checkout page (guest checkout)
 *   6. Visit My Account page (login form)
 *
 * Usage:
 *   k6-harness http://mysite.local woo-storefront.js
 *   k6-harness http://mysite.local woo-storefront.js --vus 15 --duration 60s
 *
 * Environment variables (injected by k6-harness):
 *   BASE_URL       — Target site URL (required)
 *   PRODUCT_SLUG   — Specific product slug to test (optional, auto-discovered)
 *   PRODUCT_ID     — Specific product ID for add-to-cart (optional, auto-discovered)
 *
 * Notes:
 *   - This script uses HTTP requests, not a real browser. JavaScript-rendered
 *     elements (e.g., Stripe payment forms) are not tested.
 *   - Checkout submission is NOT performed — only the checkout page load.
 *     This avoids creating test orders on your site.
 *   - The add-to-cart step uses WooCommerce's native ?add-to-cart=ID query param.
 */

import http from 'k6/http';
import { check, group, sleep, fail } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// ============================================================
// CONFIGURATION
// ============================================================

const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const PRODUCT_SLUG = __ENV.PRODUCT_SLUG || '';
const PRODUCT_ID = __ENV.PRODUCT_ID || '';

// Custom metrics
const errorRate = new Rate('woo_errors');
const shopDuration = new Trend('woo_shop_duration', true);
const productDuration = new Trend('woo_product_duration', true);
const cartDuration = new Trend('woo_cart_duration', true);
const checkoutDuration = new Trend('woo_checkout_duration', true);
const addToCartOps = new Counter('woo_add_to_cart_total');

// Default options (overridden by k6-harness flags)
export const options = {
  thresholds: {
    http_req_duration: ['p(95)<3000'],  // WooCommerce pages are heavier — 3s p95
    woo_errors: ['rate<0.15'],           // Allow slightly higher error rate for complex flows
  },
};

// ============================================================
// HELPERS
// ============================================================

const defaultHeaders = {
  'User-Agent': 'AI-DDTK-k6/1.0 (woo-load-test; +https://github.com/user/AI-DDTK)',
  'Accept': 'text/html,application/xhtml+xml,application/json',
};

function wooGet(path, name) {
  const url = `${BASE_URL}${path}`;
  return http.get(url, {
    headers: defaultHeaders,
    tags: { name: name || path },
    redirects: 5,
  });
}

/**
 * Discover a product from the WooCommerce REST API or shop page.
 * Returns { id, slug, link } or null.
 */
function discoverProduct() {
  // If product details were provided via env vars, use those
  if (PRODUCT_ID && PRODUCT_SLUG) {
    return {
      id: parseInt(PRODUCT_ID, 10),
      slug: PRODUCT_SLUG,
      link: `${BASE_URL}/product/${PRODUCT_SLUG}/`,
    };
  }

  // Try WooCommerce REST API (v3 — public product listing)
  const apiRes = http.get(`${BASE_URL}/wp-json/wc/store/v1/products?per_page=5`, {
    headers: { ...defaultHeaders, 'Accept': 'application/json' },
    tags: { name: 'Product Discovery (Store API)' },
  });

  if (apiRes.status === 200) {
    try {
      const products = JSON.parse(apiRes.body);
      if (Array.isArray(products) && products.length > 0) {
        // Pick a random simple product (avoid variable products for add-to-cart simplicity)
        const simpleProducts = products.filter(
          (p) => p.type === 'simple' || !p.type
        );
        const product = simpleProducts.length > 0
          ? simpleProducts[Math.floor(Math.random() * simpleProducts.length)]
          : products[0];

        return {
          id: product.id,
          slug: product.slug,
          link: product.permalink || `${BASE_URL}/product/${product.slug}/`,
        };
      }
    } catch (_) {
      // Fall through to HTML scraping
    }
  }

  // Fallback: scrape the shop page for a product link
  const shopRes = wooGet('/shop/', 'Shop Page (discovery)');
  if (shopRes.status === 200 && shopRes.body) {
    // Look for add-to-cart links: ?add-to-cart=123 or data-product_id="123"
    const idMatch = shopRes.body.match(/data-product_id="(\d+)"/);
    const linkMatch = shopRes.body.match(/href="([^"]*\/product\/[^"]+)"/);

    if (idMatch) {
      const slug = linkMatch
        ? linkMatch[1].match(/\/product\/([^/"]+)/)?.[1] || 'sample-product'
        : 'sample-product';

      return {
        id: parseInt(idMatch[1], 10),
        slug: slug,
        link: linkMatch ? linkMatch[1] : `${BASE_URL}/product/${slug}/`,
      };
    }
  }

  return null;
}

// ============================================================
// SETUP — Run once to discover product data
// ============================================================

export function setup() {
  const product = discoverProduct();

  if (!product) {
    console.warn(
      'Could not discover any WooCommerce products. ' +
      'The shop may be empty or the Store API may be disabled. ' +
      'Add-to-cart and product detail tests will be skipped.'
    );
  } else {
    console.log(
      `Discovered product: "${product.slug}" (ID: ${product.id})`
    );
  }

  return { product };
}

// ============================================================
// TEST SCENARIOS
// ============================================================

export default function (data) {
  const product = data.product;

  // --- 1. Shop Page (Product Listing) ---
  group('Shop Page', () => {
    const res = wooGet('/shop/', 'Shop Page');
    shopDuration.add(res.timings.duration);

    const ok = check(res, {
      'shop page returns 200': (r) => r.status === 200,
      'shop page has products': (r) =>
        r.body && (r.body.includes('product') || r.body.includes('woocommerce')),
      'shop page no fatal error': (r) => !r.body.includes('Fatal error'),
    });
    errorRate.add(!ok);
  });

  sleep(1 + Math.random());

  // --- 2. Product Detail Page ---
  group('Product Detail', () => {
    if (!product) {
      return; // Skip if no product discovered
    }

    const productPath = new URL(product.link).pathname;
    const res = wooGet(productPath, 'Product Detail');
    productDuration.add(res.timings.duration);

    const ok = check(res, {
      'product page returns 200': (r) => r.status === 200,
      'product page has add-to-cart': (r) =>
        r.body && (r.body.includes('add-to-cart') || r.body.includes('add_to_cart')),
      'product page has price': (r) =>
        r.body && (r.body.includes('woocommerce-Price-amount') || r.body.includes('price')),
    });
    errorRate.add(!ok);
  });

  sleep(0.5 + Math.random());

  // --- 3. Add to Cart ---
  group('Add to Cart', () => {
    if (!product || !product.id) {
      return; // Skip if no product discovered
    }

    // WooCommerce supports add-to-cart via GET query parameter
    const res = wooGet(`/?add-to-cart=${product.id}`, 'Add to Cart');
    addToCartOps.add(1);

    const ok = check(res, {
      'add-to-cart accepted': (r) =>
        r.status === 200 || r.status === 302 || r.status === 301,
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // --- 4. Cart Page ---
  group('Cart Page', () => {
    const res = wooGet('/cart/', 'Cart Page');
    cartDuration.add(res.timings.duration);

    const ok = check(res, {
      'cart page returns 200': (r) => r.status === 200,
      'cart page has WooCommerce content': (r) =>
        r.body && (r.body.includes('woocommerce-cart') || r.body.includes('cart')),
    });
    errorRate.add(!ok);
  });

  sleep(0.5 + Math.random());

  // --- 5. Checkout Page (load only — no order submission) ---
  group('Checkout Page', () => {
    const res = wooGet('/checkout/', 'Checkout Page');
    checkoutDuration.add(res.timings.duration);

    const ok = check(res, {
      'checkout page returns 200': (r) => r.status === 200,
      'checkout page has form': (r) =>
        r.body && (r.body.includes('checkout') || r.body.includes('woocommerce-checkout')),
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // --- 6. My Account Page (login form) ---
  group('My Account', () => {
    const res = wooGet('/my-account/', 'My Account');

    const ok = check(res, {
      'my-account returns 200': (r) => r.status === 200,
      'my-account has login form': (r) =>
        r.body && (r.body.includes('login') || r.body.includes('woocommerce-form-login')),
    });
    errorRate.add(!ok);
  });

  // Pace between iterations (1-3s to simulate browsing)
  sleep(1 + Math.random() * 2);
}

// ============================================================
// SUMMARY
// ============================================================

export function handleSummary(data) {
  const summary = {
    tool: 'AI-DDTK k6 harness',
    script: 'woo-storefront.js',
    target: BASE_URL,
    timestamp: new Date().toISOString(),
    metrics: {
      http_reqs: data.metrics.http_reqs ? data.metrics.http_reqs.values.count : 0,
      http_req_duration_p95: data.metrics.http_req_duration
        ? data.metrics.http_req_duration.values['p(95)']
        : null,
      error_rate: data.metrics.woo_errors
        ? data.metrics.woo_errors.values.rate
        : null,
      add_to_cart_total: data.metrics.woo_add_to_cart_total
        ? data.metrics.woo_add_to_cart_total.values.count
        : 0,
      shop_p95: data.metrics.woo_shop_duration
        ? data.metrics.woo_shop_duration.values['p(95)']
        : null,
      product_p95: data.metrics.woo_product_duration
        ? data.metrics.woo_product_duration.values['p(95)']
        : null,
      cart_p95: data.metrics.woo_cart_duration
        ? data.metrics.woo_cart_duration.values['p(95)']
        : null,
      checkout_p95: data.metrics.woo_checkout_duration
        ? data.metrics.woo_checkout_duration.values['p(95)']
        : null,
    },
  };

  return {
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
    'woo-storefront-summary.json': JSON.stringify(summary, null, 2),
  };
}

// k6 built-in text summary helper
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.1.0/index.js';
