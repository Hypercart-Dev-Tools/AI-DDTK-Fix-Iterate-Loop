# AI-DDTK Integration for Universal Child Theme

**Target Repo:** `https://github.com/BinoidCBD/universal-child-theme-oct-2024/`  
**Local Path:** `/Users/noelsaw/Local Sites/1-bloomzhemp-production-sync-07-24/app/public/wp-content/themes/universal-child-theme-oct-2024/`

This theme can use two complementary tools from AI-DDTK for code quality:

1. **WPCC (WP Code Check)** — Security and performance pattern scanning
2. **PHPStan** — Type-aware static analysis (null safety, array shapes)

---

## WPCC Scanning (No Setup Required)

WPCC is available system-wide. Run from the theme directory:

```bash
cd "/Users/noelsaw/Local Sites/1-bloomzhemp-production-sync-07-24/app/public/wp-content/themes/universal-child-theme-oct-2024"

# Basic scan
wpcc --paths . --format json

# Full workflow with HTML report
wpcc --paths . --format json && \
  python3 ~/bin/ai-ddtk/tools/wp-code-check/dist/bin/json-to-html.py \
    ~/bin/ai-ddtk/tools/wp-code-check/dist/logs/*.json \
    ./wpcc-report.html
```

**What WPCC catches:** SQL injection patterns, XSS, unescaped output, unbounded queries, N+1 patterns.

---

## PHPStan Setup (One-Time)

PHPStan requires per-project Composer setup. This theme is a good candidate because:
- Heavy WooCommerce customizations (`inc/woo-functions.php` is 125KB)
- Checkout overrides (`inc/checkout-func.php`, `woocommerce/checkout/`)
- Cart/product template overrides

### Step 1: Install Dependencies

```bash
cd "/Users/noelsaw/Local Sites/1-bloomzhemp-production-sync-07-24/app/public/wp-content/themes/universal-child-theme-oct-2024"

composer require --dev \
  phpstan/phpstan \
  phpstan/extension-installer \
  szepeviktor/phpstan-wordpress \
  php-stubs/wordpress-stubs \
  php-stubs/woocommerce-stubs \
  --no-interaction
```

### Step 2: Create Configuration

```bash
cp ~/bin/ai-ddtk/templates/phpstan.neon.template phpstan.neon
```

Edit `phpstan.neon` for this theme:

```neon
parameters:
    level: 3
    paths:
        - functions.php
        - inc
        - woocommerce
        - lib
    excludePaths:
        - vendor
        - node_modules
    tmpDir: build/phpstan
    bootstrapFiles:
        - vendor/php-stubs/wordpress-stubs/wordpress-stubs.php
        - vendor/php-stubs/woocommerce-stubs/woocommerce-stubs.php
    ignoreErrors:
        - '#Constant THEME_\w+ not found#'

includes:
    - phpstan-baseline.neon
```

### Step 3: Update .gitignore

```
/vendor/
/build/
composer.lock
```

### Step 4: Run First Scan & Generate Baseline

```bash
# First scan (expect many errors)
phpstan analyse --configuration=phpstan.neon --memory-limit=1G

# Generate baseline (accept current errors as legacy)
phpstan analyse --generate-baseline --memory-limit=1G

# Verify baseline works
phpstan analyse --memory-limit=1G
# Output: Found 0 errors
```

### Step 5: Commit to Repo

```bash
git add composer.json phpstan.neon phpstan-baseline.neon .gitignore
git commit -m "Add PHPStan with baseline (X legacy errors accepted)"
git push
```

---

## What to Commit vs Gitignore

| File | Commit? | Purpose |
|------|---------|---------|
| `composer.json` | ✅ Yes | Declares dev dependencies |
| `phpstan.neon` | ✅ Yes | Project configuration |
| `phpstan-baseline.neon` | ✅ Yes | Accepted legacy errors |
| `.gitignore` | ✅ Yes | Updated exclusions |
| `vendor/` | ❌ No | Installed packages |
| `build/` | ❌ No | PHPStan cache |

---

## Ongoing Workflow

```bash
# Daily: Only NEW errors are flagged
phpstan analyse --memory-limit=1G

# After fixing legacy issues: Regenerate baseline
phpstan analyse --generate-baseline --memory-limit=1G
git commit -m "PHPStan: fixed N issues, M remaining"

# Bump level when ready (edit phpstan.neon: level: 5)
phpstan analyse --memory-limit=1G
```

---

## Progress Tracking

Add to `CHANGELOG.md` or `PROJECT-AUDIT.md`:

```markdown
## PHPStan Analysis History

| Date | Level | Baseline Errors | New Errors | Notes |
|------|-------|-----------------|------------|-------|
| 2026-02-04 | 3 | 127 | 0 | Initial baseline |
| 2026-02-10 | 3 | 115 | 0 | Fixed 12 null checks |
| 2026-02-15 | 5 | 115 | 23 | Bumped to level 5 |
```

---

## Expected Findings

| Area | Likely Issues |
|------|---------------|
| `inc/woo-functions.php` | Null checks on `wc_get_order()`, `wc_get_product()` |
| `inc/checkout-func.php` | Cart/session object null safety |
| `woocommerce/checkout/` | Template globals needing `@var` annotations |

---

## GitHub Actions CI (Optional)

Add `.github/workflows/phpstan.yml` to run analysis on PRs:

```yaml
name: PHPStan

on:
  pull_request:
    paths:
      - '**.php'
      - 'phpstan.neon'
      - 'phpstan-baseline.neon'

jobs:
  phpstan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.1'
          tools: composer

      - name: Install dependencies
        run: composer install --no-interaction --prefer-dist

      - name: Run PHPStan
        run: vendor/bin/phpstan analyse --configuration=phpstan.neon --memory-limit=1G --error-format=github
```

---

## Decision: When to Use Which Tool

| Question | Tool |
|----------|------|
| "Is this code secure?" | WPCC |
| "Why does checkout crash sometimes?" | PHPStan (null safety) |
| "Find SQL injection risks" | WPCC |
| "Find type bugs before deploy" | PHPStan |
| "Full pre-release audit" | Both |

---

## Reference Documentation

- **WPCC features:** `wpcc --features`
- **PHPStan recipe:** `~/bin/ai-ddtk/recipes/phpstan-wordpress-setup.md`
- **PHPStan template:** `~/bin/ai-ddtk/templates/phpstan.neon.template`
- **AI-DDTK AGENTS.md:** `~/bin/ai-ddtk/AGENTS.md` (PHPStan section)
