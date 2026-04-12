# PHPStan WordPress/WooCommerce Setup Recipe

**Static type analysis for WordPress plugins and WooCommerce themes**

This recipe guides you through setting up PHPStan in any WordPress plugin or WooCommerce-heavy theme to catch type errors, null safety issues, and array shape mismatches before they hit production.

---

## When to Use

| Scenario | Benefit |
|----------|---------|
| Plugin development | Catch `wc_get_order()` null returns, array key mismatches |
| WooCommerce theme customization | Validate product/order object usage in templates |
| Pre-release audit | Find type bugs before deployment |
| Legacy code cleanup | Generate baseline, fix issues incrementally |

---

## Prerequisites

### System-wide installation (recommended)

```bash
# Install via Homebrew (macOS)
brew install phpstan composer

# Verify
phpstan --version  # e.g., PHPStan 2.1.38
composer --version # e.g., Composer 2.9.5
```

### Alternative: Per-project installation

If you prefer not to install globally, PHPStan can run from `vendor/bin/phpstan` after Composer setup.

---

## Quick Setup

### Step 1: Install dependencies in your project

```bash
cd /path/to/your-plugin-or-theme

composer require --dev \
  phpstan/phpstan \
  phpstan/extension-installer \
  szepeviktor/phpstan-wordpress \
  php-stubs/wordpress-stubs \
  php-stubs/woocommerce-stubs \
  php-stubs/wp-cli-stubs \
  --no-interaction
```

### Step 2: Create configuration file

Copy the template from `~/bin/ai-ddtk/templates/phpstan.neon.template` to your project root as `phpstan.neon`, then customize paths and constants.

**For plugins:**
```neon
parameters:
    level: 3
    paths:
        - includes
        - admin
        - src
```

**For themes:**
```neon
parameters:
    level: 3
    paths:
        - functions.php
        - inc
        - woocommerce      # WC template overrides
        - template-parts
```

### Step 3: Run analysis

```bash
phpstan analyse --configuration=phpstan.neon --memory-limit=1G
```

---

## Understanding Levels

| Level | What It Catches | Recommended For |
|-------|-----------------|-----------------|
| **3** | Array key access issues, basic type mismatches | Starting point for most projects |
| **5** | Null safety (`wc_get_order()` returns `WC_Order\|false`) | After fixing level 3 issues |
| **8** | Strict typing, union types, mixed handling | Well-typed modern codebases |

**Recommendation:** Start at level 3, fix those issues, then increment.

---

## Common Issues and Solutions

### Issue: "Constant MY_PLUGIN_* not found"

Plugin constants defined in the main plugin file aren't visible to PHPStan.

**Solution:** Add to `ignoreErrors` in `phpstan.neon`:
```neon
ignoreErrors:
    - '#Constant MY_PLUGIN_\w+ not found#'
```

### Issue: Memory limit exceeded

Large plugins with WooCommerce stubs need more memory.

**Solution:** Use `--memory-limit=1G` or higher:
```bash
phpstan analyse --memory-limit=2G
```

### Issue: Template globals not recognized

WooCommerce templates use globals like `$product`, `$order` that PHPStan can't trace.

**Solution:** Add `@var` annotations:
```php
<?php
/** @var WC_Product $product */
global $product;

echo $product->get_name(); // Now PHPStan knows the type
```

### Issue: "Extension included multiple times"

The `phpstan/extension-installer` auto-loads extensions.

**Solution:** Remove manual `includes:` from your config:
```neon
# ❌ Don't do this - extension-installer handles it
includes:
    - vendor/szepeviktor/phpstan-wordpress/extension.neon

# ✅ Just use parameters
parameters:
    level: 3
    ...
```

### Issue: WP-CLI commands stub errors

The `wp-cli-commands-stubs.php` has Composer dependencies.

**Solution:** Only use the base stubs file:
```neon
bootstrapFiles:
    - vendor/php-stubs/wp-cli-stubs/wp-cli-stubs.php
    # Don't include wp-cli-commands-stubs.php
```

---

## Legacy Codebase Strategy

For projects with many existing issues, use a baseline file to avoid noise and focus on **new** issues only.

---

## Baseline & History Tracking

### What is a Baseline?

A baseline is a snapshot of all current PHPStan errors that you "accept" as known issues. Once generated:
- Future runs **ignore** these errors
- Only **new** errors are reported
- You can fix legacy issues incrementally over time

### Initial Baseline Setup

```bash
# 1. Run first scan (expect many errors)
phpstan analyse --configuration=phpstan.neon --memory-limit=1G
# Output: Found 127 errors

# 2. Generate baseline (creates phpstan-baseline.neon)
phpstan analyse --generate-baseline --memory-limit=1G

# 3. Verify baseline works
phpstan analyse --memory-limit=1G
# Output: Found 0 errors (baseline ignores the 127 legacy ones)
```

### What to Commit

| File | Commit? | Purpose |
|------|---------|---------|
| `composer.json` | ✅ Yes | Declares dev dependencies |
| `phpstan.neon` | ✅ Yes | Project configuration |
| `phpstan-baseline.neon` | ✅ Yes | Accepted legacy errors |
| `.gitignore` | ✅ Yes | Updated to exclude vendor/build |
| `vendor/` | ❌ No | Installed packages (gitignored) |
| `composer.lock` | ⚠️ Optional | Locks versions (can gitignore) |
| `build/phpstan/` | ❌ No | Cache directory (gitignored) |

**Initial commit:**
```bash
git add composer.json phpstan.neon phpstan-baseline.neon .gitignore
git commit -m "Add PHPStan with baseline (127 legacy errors accepted)"
```

### Ongoing Workflow

```bash
# Daily development — only NEW errors flagged
phpstan analyse --memory-limit=1G
# Output: Found 0 errors (or only new issues)

# After fixing some legacy issues, regenerate baseline
phpstan analyse --generate-baseline --memory-limit=1G
git commit -m "PHPStan: fixed 12 null safety issues, 115 remaining"

# Bump level when ready (expect new errors)
# Edit phpstan.neon: level: 5
phpstan analyse --memory-limit=1G
# Output: Found 23 new errors at level 5
```

### Progress Tracking

Add a section to your `CHANGELOG.md` or `PROJECT-AUDIT.md`:

```markdown
## PHPStan Analysis History

| Date | Level | Baseline Errors | New Errors | Notes |
|------|-------|-----------------|------------|-------|
| 2026-02-04 | 3 | 127 | 0 | Initial baseline |
| 2026-02-10 | 3 | 115 | 0 | Fixed 12 null checks in checkout |
| 2026-02-15 | 5 | 115 | 23 | Bumped to level 5, new null issues found |
| 2026-02-20 | 5 | 98 | 0 | Fixed 17 level-5 issues, regenerated baseline |
```

### GitHub Actions CI (Optional)

Add automated PHPStan checks on pull requests:

```yaml
# .github/workflows/phpstan.yml
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

**Benefits:**
- PRs are blocked if they introduce new type errors
- Baseline ensures legacy issues don't fail CI
- `--error-format=github` shows errors inline in PR diff

### Recommended File Structure

```
your-project/
├── composer.json              # Dev dependencies
├── phpstan.neon               # Config (paths, level, ignores)
├── phpstan-baseline.neon      # Accepted legacy errors
├── .gitignore                 # vendor/, build/
│
├── CHANGELOG.md               # Include PHPStan progress section
│   └── ## PHPStan Analysis History
│
└── .github/
    └── workflows/
        └── phpstan.yml        # CI workflow (optional)
```

---

## What PHPStan Catches

| Bug Pattern | Example | Level |
|-------------|---------|-------|
| Null object access | `$order->get_total()` when `$order` might be `false` | 5+ |
| Missing array keys | `$settings['api_key']` when key doesn't exist | 3+ |
| Wrong product type | Calling `->get_stock_quantity()` on grouped product | 3+ |
| Deprecated methods | Using `$order->id` instead of `$order->get_id()` | 3+ |
| Hook signature mismatch | Filter expects 3 args, callback accepts 2 | 5+ |

---

## Available Stubs

| Package | Provides |
|---------|----------|
| `php-stubs/wordpress-stubs` | Core WP functions, classes, hooks |
| `php-stubs/woocommerce-stubs` | `WC_Order`, `WC_Product`, `wc_get_order()`, etc. |
| `php-stubs/wp-cli-stubs` | `WP_CLI` class and methods |

---

## Integration with WPCC

PHPStan and WPCC are complementary:

| Tool | Strength |
|------|----------|
| **WPCC** | Security patterns, SQL injection, XSS, performance anti-patterns |
| **PHPStan** | Type safety, null checks, array shapes, API contracts |

Run both for comprehensive coverage:
```bash
# WPCC for security/performance
wpcc --paths /path/to/plugin --format json

# PHPStan for type safety
phpstan analyse --configuration=phpstan.neon
```

---

## Reference

- **Template config:** `~/bin/ai-ddtk/templates/phpstan.neon.template`
- **PHPStan docs:** https://phpstan.org/user-guide/getting-started
- **WordPress extension:** https://github.com/szepeviktor/phpstan-wordpress

