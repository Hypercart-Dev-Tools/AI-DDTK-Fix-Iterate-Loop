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

## Quick Start

```bash
# WordPress baseline — homepage, archives, REST API
k6-harness http://mysite.local experimental/k6/scripts/wp-baseline.js

# WooCommerce storefront — product browsing, cart, checkout
k6-harness http://mysite.local experimental/k6/scripts/woo-storefront.js

# Custom VU count and duration (overrides defaults)
k6-harness http://mysite.local experimental/k6/scripts/wp-baseline.js --vus 20 --duration 60s
```

## Included Scripts

| Script | What it tests |
|--------|---------------|
| `scripts/wp-baseline.js` | Homepage, category/tag archives, REST API (`/wp-json/wp/v2/posts`), static assets |
| `scripts/woo-storefront.js` | Shop page, product detail, add-to-cart, cart page, checkout (guest), and My Account |

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

## Limitations

- k6 does **not** execute browser JavaScript — it tests HTTP endpoints, not rendered UIs
- WooCommerce checkout flow uses simplified POST requests, not full browser interaction
- For browser-level load testing, consider k6 browser module (not yet supported by this harness)
- Local by Flywheel sites may have lower throughput ceilings than production — interpret results accordingly
