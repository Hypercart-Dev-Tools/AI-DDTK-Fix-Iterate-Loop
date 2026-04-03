# k6 Scripts Utilities

## TOC

- Overview
- Utilities added for profiling and diagnostics
- Quick start
- Checklist
- Phased reuse workflow

## Overview

This folder contains reusable `k6`, Playwright, PHP, and Python helpers for WordPress / WooCommerce performance investigations.

The most reusable diagnostics from the Smart Coupons investigation are:

- `pw-xdebug-profile-run.js`
- `pw-qm-check.js`
- `profile-callers.py`
- `compare-cachegrind.py`

These are designed to help with three jobs:

1. reproduce one request or flow consistently
2. inspect Query Monitor / frontend behavior
3. analyze Xdebug cachegrind output before and after a fix

## Utilities added for profiling and diagnostics

### `pw-xdebug-profile-run.js`

- Reusable Playwright runner for request tracing and Xdebug-triggered flows
- Supports configurable step sequences like `home,add-to-cart-ajax,coupon-url,target`
- Good for isolating the exact request you want profiled

### `pw-qm-check.js`

- Reusable frontend Query Monitor scraper
- Searches page HTML, QM text, and the DB Queries panel for one or more terms
- Good for checking whether the current rendered request contains a target SQL/query signature

### `profile-callers.py`

- Prints upstream call sites for one or more symbols in a cachegrind file
- Supports plain-text or gzipped Xdebug output
- Good for turning a hotspot into a concrete caller chain

### `compare-cachegrind.py`

- Compares selected symbols between two cachegrind files
- Supports default symbols or custom symbol input
- Good for before/after mitigation measurement

## Quick start

### Playwright request profiling

```bash
BASE_URL=http://mysite.local \
AUTH_STATE=/path/to/state.json \
PRODUCT_ID=12345 \
COUPON_CODE=mycoupon \
XDEBUG=1 \
node experimental/k6/scripts/pw-xdebug-profile-run.js
```

### Query Monitor scrape

```bash
TARGET_URL='http://mysite.local/cart' \
AUTH_STATE=/path/to/state.json \
SEARCH_TERMS='mycoupon,shop_coupon,SELECT wp_posts.ID FROM wp_posts' \
node experimental/k6/scripts/pw-qm-check.js
```

### Caller chain lookup

```bash
python3 experimental/k6/scripts/profile-callers.py \
  /var/tmp/cachegrind.out.1234.gz \
  'WC_Coupon->__construct'
```

### Before / after comparison

```bash
python3 experimental/k6/scripts/compare-cachegrind.py \
  /var/tmp/cachegrind.before.gz \
  /var/tmp/cachegrind.after.gz
```

## Checklist

- [ ] Confirm the target site is local or non-production
- [ ] Confirm auth state exists if the flow requires login
- [ ] Confirm Query Monitor is active before using `pw-qm-check.js`
- [ ] Confirm Xdebug profile output is being written before using the Python helpers
- [ ] Keep symbol lists and search terms specific to the issue under investigation

## Phased reuse workflow

### Phase 0 — Reproducer spike

- Confirm the smallest reproducible request or redirect chain
- Capture the exact URL(s), auth state, and session requirements

### Phase 1 — Request diagnostics

- Use `pw-xdebug-profile-run.js` to replay the flow
- Use `pw-qm-check.js` to inspect the rendered request when needed

### Phase 2 — Profile analysis

- Use `profile-callers.py` to resolve caller chains for hotspot symbols
- Use `compare-cachegrind.py` to compare before / after runs

### Phase 3 — Mitigation verification

- Re-run the same flow with the same inputs
- Compare hotspot costs and request behavior before changing conclusions