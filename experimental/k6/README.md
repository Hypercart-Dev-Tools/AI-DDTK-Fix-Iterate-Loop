# k6 Load Testing Harness

**Status:** Experimental
**Purpose:** Lightweight load testing for WordPress / WooCommerce sites via [k6](https://k6.io/open-source/)

## Why k6?

AI-DDTK already profiles single requests (Query Monitor) and flags performance anti-patterns (WPCC). k6 fills the gap: **what happens under concurrent load?**

- QM tells you a query takes 200ms — k6 tells you it falls over at 50 users
- WPCC flags an N+1 pattern — k6 confirms real-world impact with response times
- k6 scripts are JavaScript — AI agents can generate and iterate on them

## Prerequisites

Install k6 (not bundled with AI-DDTK):

```bash
# macOS
brew install k6

# Verify
k6 version
```

Your target site must be reachable over HTTP. For Local by Flywheel sites, use the
`*.local` domain (e.g., `http://mysite.local`).

If you want to use `scripts/woo-smart-coupons-discovery.js`, make sure Playwright
is installed and Chromium is available. In AI-DDTK environments, the shared
`pw-auth` Playwright resolver is used, so the usual setup is:

```bash
npm install -g playwright
npx playwright install chromium
```

## Quick Start

```bash
# Unified Smart Coupons helper — discovery + matching load with one interface
bin/k6-smart-coupons --site-url http://mysite.local \
  --scenario homepage-prepared-session \
  --prep-url '/?coupon-code=binoid15&sc-page=cart'

# WordPress baseline — homepage, archives, REST API
k6-harness http://mysite.local experimental/k6/scripts/wp-baseline.js

# WooCommerce storefront — product browsing, cart, checkout
k6-harness http://mysite.local experimental/k6/scripts/woo-storefront.js

# Smart Coupons targeted load — use after you have confirmed the real prep flow
k6-harness http://mysite.local experimental/k6/scripts/woo-smart-coupons.js \
  --env SCENARIO=homepage-prepared-session \
  --env PREP_URL='/?coupon-code=binoid15&sc-page=cart'

# Smart Coupons discovery — Playwright helper for finding PREP_URL / flow details
node experimental/k6/scripts/woo-smart-coupons-discovery.js

# Custom VU count and duration (overrides defaults)
k6-harness http://mysite.local experimental/k6/scripts/wp-baseline.js --vus 20 --duration 60s
```

## Included Scripts

| Script | What it tests |
|--------|---------------|
| `scripts/wp-baseline.js` | Homepage, category/tag archives, REST API (`/wp-json/wp/v2/posts`), static assets |
| `scripts/woo-storefront.js` | Shop page, product detail, add-to-cart, cart page, checkout (guest), and My Account |
| `scripts/woo-smart-coupons.js` | Targeted Smart Coupons scenarios: `homepage-empty-cart`, `homepage-prepared-session`, `coupon-url-homepage`, `checkout-classic` |
| `scripts/woo-smart-coupons-discovery.js` | Playwright discovery helper that mirrors the same Smart Coupons scenario names and captures redirects, cookies, and AJAX for translation into the k6 script |

## Unified Helper

Use `bin/k6-smart-coupons` when you want discovery and the matching k6 scenario to share one interface.

What it does:

1. Accepts one set of Smart Coupons scenario inputs such as `--scenario`, `--prep-url`, `--coupon-url`, and `--intermediate-path`.
2. Runs the Playwright discovery helper, the matching k6 scenario, or both.
3. Reuses the same scenario names as `WP-WSC-PROFILE.md`.

Examples:

```bash
# Discovery only
bin/k6-smart-coupons --site-url http://mysite.local \
  --scenario coupon-url-homepage \
  --coupon-url '/?coupon-code=binoid15&sc-page=cart' \
  --mode discover --headed

# k6 only
bin/k6-smart-coupons --site-url http://mysite.local \
  --scenario homepage-prepared-session \
  --prep-url '/?coupon-code=binoid15&sc-page=cart' \
  --mode load --vus 20 --duration 30s

# Both, with one consistent interface
bin/k6-smart-coupons --site-url http://mysite.local \
  --scenario checkout-classic \
  --add-to-cart-url '/?add-to-cart=12345' \
  --mode both
```

## Smart Coupons Flow

`scripts/woo-smart-coupons.js` is intentionally narrower than `woo-storefront.js`.
Use it when you are investigating a Smart Coupons hotspot like repeated coupon
lookups on homepage requests.

Supported scenario names:

| Scenario | Purpose |
|----------|---------|
| `homepage-empty-cart` | Control case: does homepage alone trigger the coupon lookup? |
| `homepage-prepared-session` | Reproduce homepage behavior after a Smart Coupons prep flow |
| `coupon-url-homepage` | Confirm whether a coupon/share URL creates the persistent session state |
| `checkout-classic` | Check whether classic cart/checkout behavior is a major contributor |

Recommended workflow:

1. Run the Playwright discovery helper with one of the scenario names above.
2. Confirm the real `PREP_URL`, redirect chain, cookies, and any `INTERMEDIATE_PATH`.
3. Run `scripts/woo-smart-coupons.js` with the same scenario and confirmed env vars.
4. Pair the k6 run with Query Monitor or Xdebug, using [WP-WSC-PROFILE.md](WP-WSC-PROFILE.md) as the scenario guide.

Example:

```bash
# Discovery first
BASE_URL=http://mysite.local \
SCENARIO=homepage-prepared-session \
PREP_URL='/?coupon-code=binoid15&sc-page=cart' \
node experimental/k6/scripts/woo-smart-coupons-discovery.js

# Then load the exact confirmed flow
k6-harness http://mysite.local experimental/k6/scripts/woo-smart-coupons.js \
  --env SCENARIO=homepage-prepared-session \
  --env PREP_URL='/?coupon-code=binoid15&sc-page=cart'
```

Notes:

- The discovery helper is a Node + Playwright script, not a k6 script.
- `USE_AUTH_STATE=true` can be used with AI-DDTK `pw-auth` storage state when you need an authenticated browser session.
- For guest storefront reproduction, leave auth-state loading off unless you specifically need it.

## Harness Guardrails

The `k6-harness` wrapper enforces safe defaults for local development:

| Guard | Default | Override |
|-------|---------|----------|
| Max VUs | 25 | `--vus N` (hard cap: 100) |
| Max duration | 30s | `--duration Ns` (hard cap: 300s) |
| Target validation | Must be localhost, `.local`, or `.test` | `--allow-remote` (requires confirmation) |

These exist to prevent accidentally load-testing a production site or saturating your local machine.

## Writing Custom Scripts

k6 scripts are standard ES6 modules. The harness injects `BASE_URL` as an environment variable:

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost';

export default function () {
  const res = http.get(`${BASE_URL}/my-custom-endpoint`);
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1);
}
```

Run it:
```bash
k6-harness http://mysite.local ./my-script.js
```

## Pairing with Query Monitor

For deeper insight, combine k6 with QM profiling:

1. Run `qm_profile_page` on a suspect endpoint to get baseline metrics
2. Run k6 to stress that endpoint under load
3. Re-run `qm_profile_page` during the k6 run to see how query times degrade

For the Smart Coupons investigation specifically, use the scenario matrix in
[WP-WSC-PROFILE.md](WP-WSC-PROFILE.md) so the Playwright discovery step and k6
load step are using the same scenario names and assumptions.

## Limitations

- k6 does **not** execute browser JavaScript — it tests HTTP endpoints, not rendered UIs
- WooCommerce checkout flow uses simplified POST requests, not full browser interaction
- For browser-level load testing, consider k6 browser module (not yet supported by this harness)
- Local by Flywheel sites may have lower throughput ceilings than production — interpret results accordingly
