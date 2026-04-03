import http from 'k6/http';
import { check } from 'k6';

export const options = {
  vus: 1,
  iterations: 1,
  thresholds: {
    http_req_failed: ['rate<0.01'],
  },
};

const BASE = __ENV.WP_URL || 'http://binoid-production-2026-03-31.local';
const AUTH_STATE_PATH = __ENV.AUTH_STATE_PATH || './temp/playwright/.auth/binoidcbd.json';
const PRODUCT_ID = __ENV.PRODUCT_ID || '13444430';
const COUPON = __ENV.COUPON || 'binoid15';
const authState = JSON.parse(open(AUTH_STATE_PATH));

function getHost(url) {
  return String(url || '')
    .replace(/^https?:\/\//, '')
    .split('/')[0];
}

function seedCookies(jar) {
  const host = getHost(BASE);
  for (const cookie of authState.cookies || []) {
    if (cookie.domain === host && cookie.path === '/') {
      jar.set(BASE, cookie.name, cookie.value, {
        domain: cookie.domain,
        path: cookie.path,
        secure: !!cookie.secure,
        http_only: !!cookie.httpOnly,
      });
    }
  }
}

function flags(body) {
  const text = String(body || '');
  return {
    hasProduct: text.includes('Delta 9 THC Marshmellow'),
    hasEmpty: text.includes('Your cart is currently empty'),
    hasCoupon: text.toLowerCase().includes(COUPON.toLowerCase()),
  };
}

export default function () {
  const jar = http.cookieJar();
  seedCookies(jar);

  const home = http.get(`${BASE}/`, { redirects: 5, tags: { step: 'home' } });
  const add = http.post(
    `${BASE}/?wc-ajax=add_to_cart`,
    `product_id=${encodeURIComponent(PRODUCT_ID)}&quantity=1`,
    {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
      redirects: 0,
      tags: { step: 'add_to_cart' },
    }
  );
  const cart = http.get(`${BASE}/cart`, { redirects: 5, tags: { step: 'cart' } });
  const coupon = http.get(`${BASE}/?coupon-code=${encodeURIComponent(COUPON)}&sc-page=cart`, {
    redirects: 5,
    tags: { step: 'coupon_url' },
  });
  const homeAfterCoupon = http.get(`${BASE}/`, { redirects: 5, tags: { step: 'home_after_coupon' } });

  let addJson = {};
  try {
    addJson = JSON.parse(add.body || '{}');
  } catch (_) {}

  const result = {
    statuses: {
      home: home.status,
      add: add.status,
      cart: cart.status,
      coupon: coupon.status,
      homeAfterCoupon: homeAfterCoupon.status,
    },
    addHasFragments: String(add.body || '').includes('widget_shopping_cart_content'),
    cart: flags(cart.body),
    coupon: flags(coupon.body),
    homeAfterCoupon: flags(homeAfterCoupon.body),
  };

  console.log(JSON.stringify(result, null, 2));

  check(result, {
    'home 200': (r) => r.statuses.home === 200,
    'add 200': (r) => r.statuses.add === 200,
    'add has fragments': (r) => r.addHasFragments === true,
    'cart keeps product': (r) => r.cart.hasProduct === true && r.cart.hasEmpty === false,
    'homepage after coupon 200': (r) => r.statuses.homeAfterCoupon === 200,
  });
}

