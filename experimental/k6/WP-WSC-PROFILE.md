# WooCommerce Smart Coupons Profiling Plan

Concrete, scenario-driven profiling and load testing plan for WooCommerce Smart Coupons on a Local WP site.

This version is designed to live inside another repo that is already part of a Local WP install. The repo can be the plugin repo itself or a sibling harness repo. All paths below assume a Local WP site root like `.../app/public`.

If an AI-DDTK library is available to the VS Code agent and it includes Playwright, use that as the preferred discovery layer before locking scenarios into local scripts.

---

## Goal

Reproduce the Smart Coupons slow query behavior locally, identify which code path is responsible, and then verify fixes with repeatable profiling and load tests.

The main production symptom we are trying to confirm is repeated coupon lookups like:

```sql
SELECT wp_posts.ID FROM wp_posts
WHERE wp_posts.post_title = 'binoid15'
AND wp_posts.post_type = 'shop_coupon'
AND wp_posts.post_status = 'publish'
ORDER BY wp_posts.post_date DESC
LIMIT 0, 1
```

---

## Hypothesis / Theory

### Primary theory

The `binoid15` query is coming from Smart Coupons' coupon-actions / cart-session path, not necessarily only from "auto-apply."

In the Smart Coupons plugin code, the SQL shape above matches:

- `WC_SC_Coupon_Actions::get_coupon_actions()`
- which looks up a coupon with `get_posts( [ 'post_type' => 'shop_coupon', 'title' => $coupon_code, ... ] )`
- and is reachable from cart/session hooks such as:
  `woocommerce_get_cart_item_from_session -> modify_cart_item_in_session() -> modify_cart_item_data() -> get_coupon_actions()`

Implication: once a cart/session contains an item marked with `wc_sc_product_source`, the homepage and other frontend pages can keep re-running the same coupon lookup as the cart is rehydrated.

### Secondary theory

`flash20` is a separate WooCommerce core issue. That query uses:

```sql
LOWER(post_title) = LOWER('flash20')
```

which defeats normal index use on `wp_posts.post_title`.

### Additional theory

There may still be a real Smart Coupons auto-apply or URL-coupon trigger in play. We should not assume only one mechanism until we test:

1. Empty cart homepage
2. Homepage after a Smart Coupons-prepared cart/session
3. URL/share coupon flow
4. Classic checkout coupon flow
5. Optional blocks checkout flow

### Working expectation

If the primary theory is correct:

1. Empty-cart homepage should be clean or much cleaner.
2. Homepage with a prepared Smart Coupons cart/session should reproduce the `binoid15` lookup.
3. Repeating that scenario under k6 should amplify the same query shape.

---

## What Are We Testing And How?

| Scenario | Question | Tool | Pass / Fail Signal |
|---|---|---|---|
| `homepage-empty-cart` | Does homepage alone trigger the Smart Coupons lookup? | AI-DDTK Playwright or local Playwright + Xdebug + Query Monitor/manual SQL inspection | If query appears here, behavior is truly site-wide |
| `homepage-prepared-session` | Does a Smart Coupons-influenced cart/session cause homepage lookups? | AI-DDTK Playwright or local Playwright + Xdebug + Query Monitor/manual SQL inspection | If query appears only here, session/cart rehydration is the likely driver |
| `coupon-url-homepage` | Does a URL/share coupon create the session state that causes later homepage queries? | AI-DDTK Playwright or local Playwright + Xdebug | Confirms URL/share coupon path involvement |
| `checkout-classic` | Are classic cart/checkout AJAX hooks a major contributor? | AI-DDTK Playwright or local Playwright + Xdebug + manual Query Monitor | Confirms available-coupons / receiver-details activity |
| `load-homepage-prepared-session` | Does concurrency magnify the same DB hotspot? | k6 | Same query signature repeats under load |
| `post-fix-repeat` | Did the code or index change materially improve the hotspot? | AI-DDTK Playwright or local Playwright + Xdebug + k6 | Lower query count, lower query time, lower p95 |

---

## Methodology

1. Start from a Local WP clone that contains the Bloomz coupon and cart behavior if possible.
2. Verify the known coupons exist locally: `binoid15`, `flash20`, `flash25`.
3. Inspect the coupon meta before testing. We want to know whether `binoid15` is:
   - auto-apply
   - used in Smart Coupons coupon actions
   - used in a URL/share link
   - storewide / visible in cart / checkout
4. Run a single-request profile for `homepage-empty-cart`.
5. Run a single-request profile for `homepage-prepared-session`.
6. Compare query traces between the two.
7. Only after single-request reproduction is confirmed, run k6 to amplify the exact scenario.
8. Apply a fix.
9. Re-run the same scenario matrix.
10. Compare before and after using the same inputs.

---

## AI-DDTK Library With Playwright

If the VS Code agent has access to an AI-DDTK library that includes Playwright, use it first for discovery.

### Why it helps

- It can drive the real Local WP site interactively without guessing selectors or flows.
- It is useful for discovering the exact reproducer for `PREP_URL` or `ADD_TO_CART_URL`.
- It can show the real redirect chain, cookies, AJAX calls, and checkout requests created by Smart Coupons.
- It reduces the amount of one-off manual clicking needed in wp-admin and the storefront.

### What to use it for

Use AI-DDTK Playwright to answer these questions before writing or changing harness scripts:

1. Does visiting a coupon/share URL create the session state?
2. Does adding a specific product create cart items influenced by Smart Coupons?
3. Does the site require guest state or logged-in customer state?
4. Does the site use classic checkout, blocks checkout, or both?
5. What exact request sequence should be translated into `run-scenario.js` and later into `k6/load.js`?

### What it does not replace

- It does not replace `k6` for concurrency or p95 testing.
- It does not replace Xdebug for PHP hotspot attribution.
- It does not replace SQL inspection or `EXPLAIN`.

### Preferred workflow

1. Use AI-DDTK Playwright to discover the real storefront flow.
2. Record:
   - prep URL
   - add-to-cart URL
   - final URL after redirects
   - whether cookies/session state are required
   - whether classic or blocks checkout is in play
   - any AJAX endpoints or request payloads worth translating to k6 later
3. Encode the confirmed flow into `playwright/run-scenario.js`.
4. Use Xdebug and DB inspection on that confirmed flow.
5. Translate the minimal reproducer into `k6/load.js`.

### Suggested AI-DDTK discovery tasks

Ask the VS Code agent to do tasks like:

- "Using AI-DDTK Playwright against this Local WP site, determine whether `binoid15` can be reproduced from an empty session, a coupon URL, or a prepared cart session."
- "Using AI-DDTK Playwright, find the exact URL or click path that causes a homepage request to retain Smart Coupons session state."
- "Capture the redirect chain, cookies, and AJAX requests for the Smart Coupons coupon URL flow."
- "Confirm whether checkout is classic or blocks and whether Smart Coupons behavior differs between them."

---

## Did I Miss Anything?

Use this checklist before trusting any result:

- Test guest and logged-in customer sessions separately.
- Test classic cart/checkout and blocks checkout separately if the site uses both.
- Disable or bypass full-page cache while profiling.
- Keep Action Scheduler / cron noise low during local profiling.
- Confirm whether the local DB actually contains the Bloomz coupon metadata you are blaming.
- Inspect `binoid15` coupon meta, not just the coupon code row.
- Check whether a Smart Coupons-added cart item carries `wc_sc_product_source`.
- If AI-DDTK Playwright is available, capture the real storefront flow before freezing the scenario in code.
- Run `EXPLAIN` on the slow SQL before and after index changes.
- Do not rely on one synthetic WP-CLI hook call to represent a real frontend request.
- Keep backups, imports, and unrelated admin browsing out of the test window.

---

## Architecture

```text
wp-perf-harness/
├── AGENTS.md
├── harness.sh
├── config.env
├── seeds/
│   └── seed.sh
├── playwright/
│   ├── auth.js
│   └── run-scenario.js
├── k6/
│   └── load.js
├── profiler/
│   └── parse-xdebug.php
└── reports/
    └── .gitkeep
```

Why this layout:

- `AI-DDTK Playwright`, when available in the VS Code agent, is the preferred discovery layer before editing scripts.
- `Playwright` gives us deterministic single-request browser flows and session setup.
- `k6` lets us amplify one proven scenario instead of guessing.
- `Xdebug` gives the PHP call path.
- `WP-CLI` is used for fixture inspection and optional seeding.

---

## Step-By-Step Testing

### Step 1 — Prerequisites

```bash
# Install k6 (macOS)
brew install k6

# Install JS dependencies
npm init -y
npm install playwright dotenv
npx playwright install chromium

# Verify WP-CLI works against the Local site
wp --path=/absolute/path/to/app/public core version
```

If the VS Code agent already has an AI-DDTK library with Playwright, you can use that immediately for discovery even before building the local script scaffold.

### Step 2 — Confirm local fixtures before writing code

Run these by hand first. They answer whether the local site is actually suitable for reproducing the production issue.

```bash
WP_PATH="/absolute/path/to/app/public"

wp --path="$WP_PATH" db query "
SELECT ID, post_title, post_status, post_date
FROM wp_posts
WHERE post_type = 'shop_coupon'
  AND post_title IN ('binoid15', 'flash20', 'flash25')
ORDER BY post_date DESC;
"
```

For each coupon you care about, inspect the meta:

```bash
wp --path="$WP_PATH" post meta list <COUPON_ID> --format=table
```

Look especially for Smart Coupons fields such as:

- `wc_sc_add_product_details`
- `wc_sc_auto_apply_coupon`
- `sc_is_visible_storewide`
- `auto_generate_coupon`
- any store credit / gift certificate related fields

If `binoid15` does not exist locally, or the relevant Smart Coupons meta is missing, the harness can still be used, but you need to recreate equivalent fixtures first.

### Step 3 — Manual scenario prep in wp-admin

Before automating anything, determine at least one reliable prep flow that creates the suspected Smart Coupons cart/session state.

You want one of these to be true:

1. Visiting a coupon/share URL prepares the session.
2. Applying a Smart Coupons coupon adds a product to cart.
3. Adding a specific product results in cart items marked by Smart Coupons.

If you can reproduce the issue manually, note:

- exact prep URL, if any
- exact product URL or `?add-to-cart=` URL
- whether guest or logged-in customer is required
- whether cart or checkout must be visited before the homepage

This becomes the `PREP_URL` or `ADD_TO_CART_URL` in the harness config.

### Step 3A — AI-DDTK Playwright discovery

If AI-DDTK Playwright is available to the VS Code agent, do this before writing `run-scenario.js`.

Discovery goals:

1. Start from a fresh guest session and visit the homepage.
2. Visit the suspected Smart Coupons coupon/share URL, if one exists.
3. Add the suspected product to cart, if that is the likely trigger.
4. Return to the homepage.
5. Note:
   - the exact URLs used
   - the final URL after redirects
   - whether the cart badge or cart page indicates Smart Coupons state
   - whether cookies or local session state changed
   - whether classic or blocks checkout is active
   - which requests are the best candidates for later `k6/http`

Expected output from this discovery step:

- a confirmed `PREP_URL` or `ADD_TO_CART_URL`
- a chosen `SCENARIO`
- a short note on guest vs logged-in behavior
- a short note on classic vs blocks checkout

Only after that should you lock the flow into `playwright/run-scenario.js`.

### Step 4 — Create the scaffold

Create `config.env`:

```bash
WP_PATH=/absolute/path/to/app/public
PLUGIN_PATH=/absolute/path/to/app/public/wp-content/plugins/woocommerce-smart-coupons
WP_URL=https://yoursite.local

HOME_PATH=/
SHOP_PATH=/shop/
CART_PATH=/cart/
CHECKOUT_PATH=/checkout/

REPORT_DIR=./reports
XDEBUG_OUTPUT_DIR=/tmp/xdebug-profiles

ADMIN_USER=admin
ADMIN_PASS=password

SC_PRIMARY_COUPON=binoid15
SC_SECONDARY_COUPON=flash25
WC_CORE_COUPON=flash20

SCENARIO=homepage-empty-cart
PREP_URL=
ADD_TO_CART_URL=
TEST_PRODUCT_ID=
GIFT_PRODUCT_ID=
TEST_EMAIL=test@example.local

K6_VUS=20
K6_DURATION=30s
```

Notes:

- `PREP_URL` is the most important variable for reproducing query `#1`.
- Leave `PREP_URL` empty for the baseline empty-cart homepage test.
- Set `PREP_URL` to the exact URL that creates the Smart Coupons session state if you have one.
- If there is no prep URL, use `ADD_TO_CART_URL` to add the relevant product first.

---

Create `seeds/seed.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../config.env"

echo "→ Seeding generic users/products for local testing"

wp --path="$WP_PATH" user get perfcustomer >/dev/null 2>&1 || \
  wp --path="$WP_PATH" user create perfcustomer perfcustomer@example.local \
  --role=customer \
  --user_pass=testpass123

if [[ -z "${TEST_PRODUCT_ID:-}" ]]; then
  PRODUCT_ID=$(wp --path="$WP_PATH" post create \
    --post_type=product \
    --post_status=publish \
    --post_title="Perf Harness Product" \
    --porcelain)
  echo "Created product: $PRODUCT_ID"
else
  echo "Using existing TEST_PRODUCT_ID=$TEST_PRODUCT_ID"
fi

echo ""
echo "Now confirm Smart Coupons fixtures manually in wp-admin:"
echo "  - coupon codes exist"
echo "  - coupon meta is what you expect"
echo "  - PREP_URL or ADD_TO_CART_URL is known"
```

---

Create `playwright/auth.js`:

```javascript
const { chromium } = require('playwright');

async function getContext({ admin = false, xdebugProfile = false } = {}) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
  });

  if (xdebugProfile) {
    await context.addCookies([
      {
        name: process.env.XDEBUG_TRIGGER_NAME || 'XDEBUG_PROFILE',
        value: process.env.XDEBUG_TRIGGER_VALUE || '1',
        domain: new URL(process.env.WP_URL).hostname,
        path: '/',
      },
    ]);
  }

  const page = await context.newPage();

  if (admin) {
    await page.goto(`${process.env.WP_URL}/wp-login.php`, { waitUntil: 'networkidle' });
    await page.fill('#user_login', process.env.ADMIN_USER);
    await page.fill('#user_pass', process.env.ADMIN_PASS);
    await page.click('#wp-submit');
    await page.waitForURL('**/wp-admin/**');
  }

  return { browser, context, page };
}

module.exports = { getContext };
```

---

Create `playwright/run-scenario.js`:

```javascript
require('dotenv').config({ path: '../config.env' });
const { getContext } = require('./auth');

function abs(pathOrUrl) {
  if (!pathOrUrl) return '';
  if (/^https?:\/\//.test(pathOrUrl)) return pathOrUrl;
  return `${process.env.WP_URL}${pathOrUrl}`;
}

async function gotoAndMeasure(page, label, url) {
  const start = Date.now();
  await page.goto(url, { waitUntil: 'networkidle' });
  return { step: label, ms: Date.now() - start, url };
}

async function maybePrepareSession(page, timings) {
  if (process.env.PREP_URL) {
    timings.push(await gotoAndMeasure(page, 'prep_url', abs(process.env.PREP_URL)));
  } else if (process.env.ADD_TO_CART_URL) {
    timings.push(await gotoAndMeasure(page, 'add_to_cart_url', abs(process.env.ADD_TO_CART_URL)));
  }
}

(async () => {
  const scenario = process.env.SCENARIO || 'homepage-empty-cart';
  const profile = process.argv.includes('--profile');
  const { browser, page } = await getContext({ xdebugProfile: profile });
  const timings = [];

  try {
    switch (scenario) {
      case 'homepage-empty-cart':
        timings.push(await gotoAndMeasure(page, 'homepage', abs(process.env.HOME_PATH || '/')));
        break;

      case 'homepage-prepared-session':
        await maybePrepareSession(page, timings);
        timings.push(await gotoAndMeasure(page, 'homepage_after_prep', abs(process.env.HOME_PATH || '/')));
        break;

      case 'coupon-url-homepage':
        timings.push(
          await gotoAndMeasure(
            page,
            'coupon_url',
            abs(`/?coupon-code=${encodeURIComponent(process.env.SC_PRIMARY_COUPON)}&sc-page=cart`)
          )
        );
        timings.push(await gotoAndMeasure(page, 'homepage_after_coupon_url', abs(process.env.HOME_PATH || '/')));
        break;

      case 'checkout-classic':
        await maybePrepareSession(page, timings);
        timings.push(await gotoAndMeasure(page, 'checkout', abs(process.env.CHECKOUT_PATH || '/checkout/')));
        if (await page.locator('input[name="billing_email"]').count()) {
          await page.fill('input[name="billing_email"]', process.env.TEST_EMAIL || 'test@example.local');
          await page.waitForTimeout(1500);
        }
        break;

      default:
        throw new Error(`Unknown SCENARIO: ${scenario}`);
    }

    console.log(
      JSON.stringify(
        {
          scenario,
          profile,
          finalUrl: page.url(),
          title: await page.title(),
          timings,
        },
        null,
        2
      )
    );
  } finally {
    await browser.close();
  }
})();
```

This script is intentionally simple. Its job is not to test every Smart Coupons feature. Its job is to let you prove or disprove the homepage/cart-session hypothesis with controlled requests.

---

Create `k6/load.js`:

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.WP_URL;
const SCENARIO = __ENV.SCENARIO || 'homepage-empty-cart';
const PREP_URL = __ENV.PREP_URL || '';
const ADD_TO_CART_URL = __ENV.ADD_TO_CART_URL || '';
const HOME_PATH = __ENV.HOME_PATH || '/';

function abs(pathOrUrl) {
  if (!pathOrUrl) return '';
  if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) return pathOrUrl;
  return `${BASE_URL}${pathOrUrl}`;
}

export const options = {
  scenarios: {
    main: {
      executor: 'constant-vus',
      vus: Number(__ENV.K6_VUS || 20),
      duration: __ENV.K6_DURATION || '30s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<2000'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  if (SCENARIO === 'homepage-prepared-session') {
    if (PREP_URL) {
      http.get(abs(PREP_URL), { tags: { name: 'prep_url' } });
    } else if (ADD_TO_CART_URL) {
      http.get(abs(ADD_TO_CART_URL), { tags: { name: 'add_to_cart_url' } });
    }
  } else if (SCENARIO === 'coupon-url-homepage') {
    http.get(abs(`/?coupon-code=${encodeURIComponent(__ENV.SC_PRIMARY_COUPON)}&sc-page=cart`), {
      tags: { name: 'coupon_url' },
    });
  }

  const res = http.get(abs(HOME_PATH), { tags: { name: 'homepage' } });

  check(res, {
    'status 200': (r) => r.status === 200,
    'no fatal error': (r) => !r.body.includes('Fatal error'),
  });

  sleep(1);
}
```

Why this matters:

- For query `#1`, the prepared-session path is the main load case to test.
- We do not want a generic `/shop/` load test before we have confirmed the reproducing scenario.

---

Create `profiler/parse-xdebug.php`:

```php
<?php

$file = $argv[1] ?? null;
if (!$file || !file_exists($file)) {
    die("Usage: php parse-xdebug.php <cachegrind-file>\n");
}

$lines = file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$functions = [];
$current = null;

foreach ($lines as $line) {
    if (str_starts_with($line, 'fn=')) {
        $current = substr($line, 3);
        if (!isset($functions[$current])) {
            $functions[$current] = ['calls' => 0, 'cost' => 0];
        }
    } elseif ($current && preg_match('/^\d+ (\d+)$/', $line, $m)) {
        $functions[$current]['cost'] += (int) $m[1];
        $functions[$current]['calls']++;
    }
}

uasort($functions, fn($a, $b) => $b['cost'] <=> $a['cost']);
$top = array_slice($functions, 0, 25, true);

echo "\n=== TOP 25 HOTSPOTS ===\n";
printf("%-60s %10s %8s\n", 'Function', 'Cost (μs)', 'Calls');
echo str_repeat('-', 82) . "\n";

foreach ($top as $fn => $data) {
    printf(
        "%-60s %10d %8d\n",
        substr($fn, 0, 59),
        $data['cost'],
        $data['calls']
    );
}
```

---

Create `harness.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.env"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="$REPORT_DIR/$TIMESTAMP"
mkdir -p "$RUN_DIR" "$XDEBUG_OUTPUT_DIR"

MODE=${1:-profile}   # inspect | seed | profile | load | analyze | full

banner() { echo -e "\n\033[1;36m=== $1 ===\033[0m"; }

run_inspect() {
  banner "INSPECT COUPON FIXTURES"

  wp --path="$WP_PATH" db query "
  SELECT ID, post_title, post_status, post_date
  FROM wp_posts
  WHERE post_type = 'shop_coupon'
    AND post_title IN ('$SC_PRIMARY_COUPON', '$SC_SECONDARY_COUPON', '$WC_CORE_COUPON')
  ORDER BY post_date DESC;
  " | tee "$RUN_DIR/coupon-rows.txt"

  for CODE in "$SC_PRIMARY_COUPON" "$SC_SECONDARY_COUPON" "$WC_CORE_COUPON"; do
    ID=$(wp --path="$WP_PATH" db query "
    SELECT ID
    FROM wp_posts
    WHERE post_type = 'shop_coupon'
      AND post_title = '$CODE'
      AND post_status = 'publish'
    ORDER BY post_date DESC
    LIMIT 1;
    " --skip-column-names 2>/dev/null | tr -d '[:space:]' || true)

    if [[ -n "${ID:-}" ]]; then
      echo "" | tee -a "$RUN_DIR/coupon-meta.txt"
      echo "### $CODE ($ID)" | tee -a "$RUN_DIR/coupon-meta.txt"
      wp --path="$WP_PATH" post meta list "$ID" --format=table | tee -a "$RUN_DIR/coupon-meta.txt"
    fi
  done
}

run_seed() {
  banner "SEEDING GENERIC FIXTURES"
  bash seeds/seed.sh | tee "$RUN_DIR/seed.txt"
}

run_profile() {
  banner "PROFILING SCENARIO: $SCENARIO"

  rm -f "$XDEBUG_OUTPUT_DIR"/cachegrind.out.* || true

  node playwright/run-scenario.js --profile | tee "$RUN_DIR/timings.json"

  sleep 2

  LATEST=$(ls -t "$XDEBUG_OUTPUT_DIR"/cachegrind.out.* 2>/dev/null | head -1 || true)
  if [[ -n "${LATEST:-}" ]]; then
    php profiler/parse-xdebug.php "$LATEST" | tee "$RUN_DIR/xdebug-hotspots.txt"
  else
    echo "No Xdebug profile found. Check Local WP Xdebug output path." | tee "$RUN_DIR/xdebug-hotspots.txt"
  fi
}

run_load() {
  banner "LOAD TEST SCENARIO: $SCENARIO"
  k6 run \
    --env WP_URL="$WP_URL" \
    --env SCENARIO="$SCENARIO" \
    --env PREP_URL="$PREP_URL" \
    --env ADD_TO_CART_URL="$ADD_TO_CART_URL" \
    --env HOME_PATH="$HOME_PATH" \
    --env SC_PRIMARY_COUPON="$SC_PRIMARY_COUPON" \
    --env K6_VUS="$K6_VUS" \
    --env K6_DURATION="$K6_DURATION" \
    --out json="$RUN_DIR/k6-raw.json" \
    k6/load.js | tee "$RUN_DIR/k6-summary.txt"
}

run_analyze() {
  banner "ANALYZE"
  echo "Run directory: $RUN_DIR"
  echo "Scenario: $SCENARIO"

  if [[ -f "$RUN_DIR/xdebug-hotspots.txt" ]]; then
    echo ""
    echo "Top hotspots:"
    head -20 "$RUN_DIR/xdebug-hotspots.txt"
  fi

  if [[ -f "$RUN_DIR/k6-summary.txt" ]]; then
    echo ""
    echo "k6 summary:"
    cat "$RUN_DIR/k6-summary.txt"
  fi
}

case "$MODE" in
  inspect) run_inspect ;;
  seed) run_seed ;;
  profile) run_profile ;;
  load) run_load ;;
  analyze) run_analyze ;;
  full)
    run_inspect
    run_profile
    run_load
    run_analyze
    ;;
  *)
    echo "Usage: ./harness.sh [inspect|seed|profile|load|analyze|full]"
    exit 1
    ;;
esac

banner "DONE → $RUN_DIR"
```

---

Finally, create `AGENTS.md`:

```markdown
# WP Perf Harness Instructions

## Purpose
Reproduce and confirm WooCommerce Smart Coupons query hotspots on a Local WP site before changing production code.

## Main Hypothesis
The worst Smart Coupons query is likely coming from the coupon-actions / cart-session path, not only from dedicated auto-apply logic.

## Preferred Discovery Tool
If available, use AI-DDTK with Playwright first to discover the real reproducer and request sequence, then encode that into the local harness scripts.

## Priority Scenario Order
1. `homepage-empty-cart`
2. `homepage-prepared-session`
3. `coupon-url-homepage`
4. `checkout-classic`
5. `load` only after single-request reproduction is confirmed

## Entry Point
```bash
./harness.sh [inspect|seed|profile|load|analyze|full]
```

## Required Config
Everything lives in `config.env`. Use absolute paths. Do not hardcode site-specific values in scripts.

## Interpret Results Carefully
- If the slow query appears on `homepage-empty-cart`, the problem is site-wide.
- If it appears only on `homepage-prepared-session`, the likely driver is Smart Coupons cart/session rehydration.
- If it appears after `coupon-url-homepage`, URL/share coupon behavior is part of the chain.
- If `flash20` dominates, remember that is a separate WooCommerce core lookup problem.
- Use AI-DDTK Playwright for discovery, but use the local harness for repeatable before/after measurement.

## Do Not
- Run the harness against production
- Mix unrelated admin browsing into the same test window
- Assume `auto-apply` is the only Smart Coupons mechanism until the scenario matrix proves it
```

---

## Concrete Test Runs

These are the first runs to perform.

### Run 1 — Baseline empty cart homepage

```bash
SCENARIO=homepage-empty-cart ./harness.sh inspect
SCENARIO=homepage-empty-cart ./harness.sh profile
```

What you are looking for:

- Does `binoid15` appear at all?
- Does Xdebug show `WC_SC_Coupon_Actions::get_coupon_actions()`?

If AI-DDTK Playwright is available, do one interactive run first and record the observed homepage behavior before running the scripted profile.

### Run 2 — Homepage after Smart Coupons prep

Use either a known Smart Coupons URL or a product/cart action that creates the suspect cart/session state.

```bash
SCENARIO=homepage-prepared-session \
PREP_URL='/?coupon-code=binoid15&sc-page=cart' \
./harness.sh profile
```

Or:

```bash
SCENARIO=homepage-prepared-session \
ADD_TO_CART_URL='/?add-to-cart=12345' \
./harness.sh profile
```

What you are looking for:

- Does the homepage request now show the `binoid15` lookup?
- Is the call path now clearly inside Smart Coupons cart/session handling?
- Did AI-DDTK discovery confirm the same prep flow and redirect chain you encoded into the script?

### Run 3 — Classic checkout

```bash
SCENARIO=checkout-classic \
ADD_TO_CART_URL='/?add-to-cart=12345' \
./harness.sh profile
```

What you are looking for:

- Are checkout AJAX and Smart Coupons checkout hooks contributing significantly?
- Is this secondary to the homepage/session issue, or the main source?

### Run 4 — Load the confirmed reproducer

Only do this after one of the profile runs clearly reproduces the problem.

```bash
SCENARIO=homepage-prepared-session \
PREP_URL='/?coupon-code=binoid15&sc-page=cart' \
K6_VUS=20 \
K6_DURATION=30s \
./harness.sh load
```

### Run 5 — Re-test after fix

Repeat the exact same scenario after:

- a plugin code patch
- a coupon config change
- or a DB index change

Do not change the scenario and the code at the same time if you want a clean comparison.

---

## Recommended Fix / Iterate Loop

1. Run `inspect` and confirm the local fixture really matches the production theory.
2. Run `profile` for `homepage-empty-cart`.
3. If available, use AI-DDTK Playwright to confirm the real prep flow.
4. Run `profile` for `homepage-prepared-session`.
5. If `homepage-prepared-session` is the reproducer, patch that path first.
6. Re-run the same profile.
7. Only then run `load`.
8. Compare query count, hotspot path, and p95.

---

## Likely Missing Pieces To Check In The Target Repo

When you bring this doc into another repo, confirm these items there:

- the site actually has classic WooCommerce cart/checkout pages enabled
- the repo under test is the plugin/theme that owns the hot path
- the Local WP clone includes the real Bloomz coupon rows and Smart Coupons meta
- Query Monitor is installed if you want manual call stack confirmation
- Xdebug output path matches `config.env`
- the site is not silently redirecting or caching away the scenario you think you are profiling
- AI-DDTK Playwright is available to the VS Code agent if you want interactive discovery before freezing the scripted scenario

---

## Step-By-Step Setup

```bash
# 1. Create project or use existing repo
mkdir wp-perf-harness && cd wp-perf-harness
git init

# 2. Create the files above
chmod +x harness.sh seeds/seed.sh

# 3. Install JS dependencies
npm init -y
npm install playwright dotenv
npx playwright install chromium

# 4. Install k6
brew install k6

# 5. Enable Xdebug in Local WP
# Local UI -> your site -> PHP -> toggle Xdebug on

# 6. Update config.env with real values

# 7. First concrete runs
SCENARIO=homepage-empty-cart ./harness.sh inspect
SCENARIO=homepage-empty-cart ./harness.sh profile

SCENARIO=homepage-prepared-session \
PREP_URL='/?coupon-code=binoid15&sc-page=cart' \
./harness.sh profile

SCENARIO=homepage-prepared-session \
PREP_URL='/?coupon-code=binoid15&sc-page=cart' \
./harness.sh load
```

---

## What This Harness Should Tell You

At the end of the first pass, you should be able to answer:

1. Does the Smart Coupons query happen on the homepage with an empty cart?
2. Does it only happen after Smart Coupons has prepared cart/session state?
3. Is `auto-apply` really the root cause, or only one trigger?
4. Does k6 amplify the exact same query path you saw in single-request profiling?
5. Did the fix reduce both PHP hotspot cost and load-test latency?

---

## Appendix — WP Code Check Findings vs Slow Query Logs

WP Code Check flagged two coupon-related findings:

1. add an index to speed up `wc_get_coupon_id_by_code()`
2. cache `wc_get_coupon_id_by_code()` results more aggressively

These findings are relevant, but they do not map equally to the slow queries in the Bloomz logs.

### Finding 1 — Index for `wc_get_coupon_id_by_code()`

This is related to the WooCommerce core coupon lookup path, which is the same family as the logged `flash20` query:

```sql
SELECT ID FROM wp_posts
WHERE LOWER(post_title) = LOWER('flash20')
AND post_type = 'shop_coupon'
AND post_status = 'publish'
ORDER BY post_date DESC
```

That lookup is performed by WooCommerce core `wc_get_coupon_id_by_code()` through the coupon data store. Smart Coupons also calls `wc_get_coupon_id_by_code()` from several places in frontend, checkout, order-processing, admin, and REST code.

What this means for the log analysis:

- this finding is meaningfully related to query `#2` in the slow log analysis
- it may also help some secondary Smart Coupons call sites that use `wc_get_coupon_id_by_code()`
- it is **not** the direct explanation for query `#1` (`binoid15`)

Why it does not explain query `#1`:

- query `#1` matches Smart Coupons `WC_SC_Coupon_Actions::get_coupon_actions()`
- that code uses `get_posts()` with `post_type = shop_coupon`, `title = $coupon_code`, and `post_status = publish`
- that path is tied to coupon-actions/cart-session rehydration, not WooCommerce core `wc_get_coupon_id_by_code()`

Important nuance:

- a plain or composite index on `wp_posts.post_title` is directionally useful
- but the WooCommerce core query uses `LOWER(post_title) = LOWER(%s)`, which still limits normal index use
- so this finding is valid, but it is not a complete fix by itself unless the query shape or index strategy also changes

### Finding 2 — Cache `wc_get_coupon_id_by_code()` More Aggressively

This is only weakly related to the worst slow-query pattern.

WooCommerce already caches `wc_get_coupon_id_by_code()` lookups in the object cache. That means:

- within a request, repeated lookups may already be reduced
- cross-request benefit depends on whether the site has a persistent object cache

What this means for the log analysis:

- this may help under concurrent admin or REST activity
- it may reduce some repeated secondary coupon lookups
- it does **not** explain the main sitewide frontend/homepage `binoid15` pattern by itself

So treat this as:

- a reasonable secondary optimization
- not the primary root-cause fix for the continuous frontend Smart Coupons hotspot

### Practical Mapping

Use the findings this way when prioritizing fixes:

1. map the index finding primarily to WooCommerce core coupon lookup pressure like `flash20`
2. map the caching finding to secondary admin/REST or cross-request coupon lookup reduction
3. keep the main focus on the Smart Coupons `get_coupon_actions()` cart-session path for query `#1`

### Bottom Line

The static analyzer findings are relevant to the coupon problem space, especially the WooCommerce core lookup path, but they do not replace the main theory in this document:

- query `#1` is still best explained by Smart Coupons coupon-actions/cart-session rehydration
- query `#2` is the stronger match for `wc_get_coupon_id_by_code()`
- the highest-value profiling work remains `homepage-empty-cart` versus `homepage-prepared-session`
