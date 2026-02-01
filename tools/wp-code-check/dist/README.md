# WP Code Check by Hypercart - Performance & Security Analyzer

> **Versioning:** The canonical version is defined in `dist/bin/check-performance.sh` (see `SCRIPT_VERSION` in the script header). This README reflects that version but should not be treated as the primary source of truth.

© Copyright 2025 Hypercart (a DBA of Neochrome, Inc.)

---

## 🎯 For Developers: Why This Matters

### The Problem

You're building a WordPress plugin or theme. Everything works great in development. Then production hits:

- 💥 **Site crashes** under load because someone used `posts_per_page => -1`
- 🐌 **Admin dashboard freezes** from N+1 queries in a loop
- 🔥 **Server melts down** from unbounded AJAX polling every 100ms
- 💸 **Database explodes** from REST endpoints with no pagination
- 🕳️ **Security holes** from AJAX handlers missing nonce validation
- ⏱️ **Entire site hangs** from `file_get_contents()` on an unresponsive API

**These aren't edge cases. They're production killers that slip through code review every day.**

### The Solution

This toolkit **automatically detects 30+ critical WordPress performance and security antipatterns** before they reach production.

**Think of it as:**
- 🛡️ **ESLint/PHPStan for WordPress performance** - catches issues static analysis misses
- 🔍 **Automated code review** - finds patterns that crash sites under load
- 🚨 **Pre-deployment safety net** - fails CI/CD before bad code ships
- 📊 **Technical debt tracker** - baseline existing issues, prevent new ones

### What Makes This Different

**WordPress-specific intelligence:**
- Understands `WP_Query`, `get_posts()`, `wp_ajax_*`, `register_rest_route()`, WooCommerce patterns
- Knows the difference between safe and dangerous WordPress APIs
- Catches issues that generic linters can't see

**Zero dependencies:**
- Pure bash + grep - runs anywhere (local, CI/CD, Docker, GitHub Actions)
- No PHP extensions, no Composer dependencies, no Node.js required
- Works on macOS, Linux, Windows (WSL)

**Production-tested:**
- Detects real issues that have crashed real WordPress sites
- Used in CI/CD pipelines processing millions of requests/day
- Battle-tested patterns from 10+ years of WordPress performance consulting

---

## 🚀 Quick Start: Run From Anywhere

**Key Feature:** You don't need to copy this tool into every project. Keep it in one location and point it at any codebase.

---

### 🎯 **New to WP Code Check? Start Here!**

👉 **[Shell Quick Start Guide](../SHELL-QUICKSTART.md)** - Complete guide for terminal users

**The fastest way to get started:**

```bash
# 1. Clone the repository
git clone https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git
cd WP-Code-Check

# 2. Run the installer (30 seconds)
./install.sh

# 3. Scan your plugin
wp-check ~/my-plugin
```

**What the installer does:**
- ✅ Makes scripts executable
- ✅ Adds `wp-check` alias to your shell
- ✅ Enables tab completion
- ✅ Runs a test scan
- ✅ Shows quick start examples

**Time to first scan: 30 seconds** (vs. 5 minutes manual setup)

---

### 📖 Manual Installation (Advanced Users)

If you prefer manual setup or need custom configuration:

#### Installation (One-Time Setup)

```bash
# Clone to a central location (anywhere on your machine)
git clone https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git ~/dev/wp-analyzer

# Or download and extract to any directory
cd ~/dev/wp-analyzer
```

#### Usage: Analyze Any Project

```bash
# Analyze any WordPress project from anywhere
~/dev/wp-analyzer/dist/bin/check-performance.sh --paths /path/to/your/plugin

# Examples:
~/dev/wp-analyzer/dist/bin/check-performance.sh --paths ~/Sites/my-plugin
~/dev/wp-analyzer/dist/bin/check-performance.sh --paths /var/www/client-site/wp-content/themes/custom
~/dev/wp-analyzer/dist/bin/check-performance.sh --paths ~/projects/woocommerce-extension

# Analyze multiple projects at once
~/dev/wp-analyzer/dist/bin/check-performance.sh --paths "~/plugin1 ~/plugin2 ~/theme"

# Analyze current directory
cd ~/Sites/my-plugin
~/dev/wp-analyzer/dist/bin/check-performance.sh --paths .
```

#### Create an Alias (Recommended)

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# One-line analyzer - use from anywhere
alias wp-check='~/dev/wp-analyzer/dist/bin/check-performance.sh --paths'

# Then use it anywhere:
wp-check ~/Sites/my-plugin
wp-check .
wp-check ~/client-work/custom-theme --strict
wp-check ~/projects/plugin --format json > report.json
```

**💡 Tip:** The `install.sh` script does this automatically! See the [Shell Quick Start Guide](../SHELL-QUICKSTART.md).

### Alternative: Per-Project Installation

If you prefer to include it in each project (e.g., for CI/CD):

```bash
# Add as Composer dev dependency
composer require --dev neochrome/wp-toolkit

# Or copy dist/ folder into your project
cp -r ~/dev/wp-analyzer/dist ./vendor/neochrome/

# Then run from project root
./dist/bin/check-performance.sh --paths .
```

---

## 💡 What It Detects

### 🚨 Critical Errors (Build Fails)

These patterns **will crash your site** under production load:

| Pattern | Why It's Dangerous | Real-World Impact |
|---------|-------------------|-------------------|
| **`$wpdb->query`** without `prepare()` | SQL injection vulnerability | Attacker can delete database, steal data, or execute arbitrary SQL |
| **AJAX polling** via `setInterval` + fetch/ajax | Creates request storms that hammer backend | 1000 users = 60,000 requests/min → server meltdown |
| **`register_rest_route`** without pagination | Unbounded REST data fetch | API returns 50,000 posts → 500MB response → timeout |
| **`wp_ajax_*`** handlers missing nonce | Unlimited AJAX flood, no CSRF protection | Bots flood endpoint → database locks → site down |
| **`posts_per_page => -1`** | Loads ALL posts into memory | 10,000 posts × 2KB = 20MB per request → OOM crash |
| **`numberposts => -1`** | Same as above for `get_posts()` | Memory exhaustion on high-traffic pages |
| **`nopaging => true`** | Disables all pagination limits | Silent killer - bypasses safety checks |
| **`wc_get_orders(['limit' => -1])`** | WooCommerce unbounded query | 50,000 orders → 100MB+ → PHP fatal error |
| **`get_terms()`** without `number` | Loads entire taxonomy into memory | 100,000 tags → memory exhaustion |
| **`pre_get_posts`** forcing unbounded | Modifies queries globally | Breaks pagination site-wide |
| **Unbounded SQL** on `wp_terms` | Full table scans without limits | Locks database on large sites |
| **`file_get_contents()`** with URLs | No timeout, no SSL verification, blocks PHP | External API down → entire site hangs for 30+ seconds |

### ⚠️ High Priority Warnings

These patterns **create security vulnerabilities or severe performance issues** and should be fixed immediately:

| Pattern | Why It Matters | Impact |
|---------|---------------|--------|
| **Unsanitized `$_GET`/`$_POST`** read | XSS and parameter tampering | Attacker can inject malicious scripts or manipulate application logic |
| **Direct superglobal manipulation** | Bypasses WordPress security | Modifying `$_GET`/`$_POST` directly breaks sanitization |
| **Admin functions without capability checks** | Privilege escalation vulnerability | Subscribers can access admin functions, modify settings, or delete data |
| **WooCommerce N+1 patterns** | Query multiplication in WC loops | 100 orders × 3 meta queries = 300 queries → 5-10 second page loads |

### ⚠️ Medium Priority Warnings

These patterns **degrade performance** and should be fixed:

| Pattern | Why It Matters | Impact |
|---------|---------------|--------|
| **`ORDER BY RAND()`** | Full table scan on every query | 100,000 rows → 2-5 second queries |
| **`set_transient()`** without expiration | Stale data accumulates forever | Database bloat, cache pollution |
| **N+1 patterns** (meta in loops) | Query multiplication | 100 posts × 3 meta queries = 300 queries per page |
| **`current_time('timestamp')`** | Deprecated, timezone issues | Use `current_datetime()` instead |
| **HTTP requests** without timeout | External API hangs → site hangs | 5-30 second page loads if API is slow |
| **PHP short tags** (`<?=` or `<? `) | Not guaranteed to work on all servers | Code fails to parse if `short_open_tag` is disabled |
| **WooCommerce Subscriptions queries without limits** | Performance degradation with large subscription counts | 10,000 subscriptions → memory exhaustion |

---

## 🔧 How Rules Are Defined

**All detection rules are defined as JSON patterns** in `dist/patterns/`. This makes rules:
- ✅ **Data-driven** – Easy to add, modify, and version control
- ✅ **Self-documenting** – Each rule includes description, rationale, and remediation
- ✅ **Testable** – Rules can be validated independently
- ✅ **Extensible** – New detection types can be added without changing core logic

### Rule Structure

Each JSON rule file contains:

```json
{
  "id": "unbounded-posts-per-page",
  "version": "1.0.0",
  "enabled": true,
  "category": "performance",
  "severity": "CRITICAL",
  "title": "Unbounded posts_per_page",
  "description": "Detects WordPress queries that disable pagination",
  "rationale": "Unbounded queries can fetch all posts at once, leading to timeouts",

  "detection": {
    "type": "simple",
    "file_patterns": ["*.php"],
    "grep": {
      "include": ["-E posts_per_page[[:space:]]*=>[[:space:]]*-1"]
    }
  },

  "remediation": {
    "summary": "Add pagination or a reasonable LIMIT",
    "examples": [
      {
        "bad": "WP_Query(['posts_per_page' => -1])",
        "good": "WP_Query(['posts_per_page' => 50, 'paged' => $paged])"
      }
    ]
  }
}
```

### Pattern Categories

Rules are organized by domain:

| Directory | Purpose | Examples |
|-----------|---------|----------|
| `dist/patterns/core/` | Core performance/security rules | Unbounded queries, missing nonces, N+1 patterns |
| `dist/patterns/dry/` | DRY/duplication detection | Duplicate option names, transient keys, capabilities |
| `dist/patterns/headless/` | Headless WordPress patterns | API key exposure, missing auth headers |
| `dist/patterns/js/` | JavaScript-specific patterns | Duplicate storage keys, polling antipatterns |
| `dist/patterns/nodejs/` | Node.js-specific patterns | Command injection, path traversal |

### Detection Types

- **`simple`** – Basic grep pattern matching (most rules)
- **`aggregated`** – DRY/clone detection with grouping and thresholds
- **`contextual`** – Context-aware rules (e.g., nonce + capability in same function)
- **`scripted`** – Complex rules requiring custom validator scripts

### Adding New Rules

**For contributors:** See [CONTRIBUTING.md](../CONTRIBUTING.md) for detailed instructions on adding new JSON-based rules.

**Note:** Inline rules in `check-performance.sh` are legacy and will be migrated to JSON. All new rules MUST be defined as JSON patterns.

---

## 📊 Command Reference

### Basic Usage

```bash
# Analyze current directory
wp-analyze .

# Analyze specific project
wp-analyze ~/Sites/my-plugin

# Analyze multiple paths
wp-analyze "~/plugin ~/theme ~/custom-code"

# Verbose output (show all matches, not just first)
wp-analyze ~/Sites/my-plugin --verbose

# Strict mode (fail on warnings too - for CI/CD)
wp-analyze ~/Sites/my-plugin --strict

# JSON output (for tooling/CI)
wp-analyze ~/Sites/my-plugin --format json

# Disable log file
wp-analyze ~/Sites/my-plugin --no-log

# Custom context lines (default: 3)
wp-analyze ~/Sites/my-plugin --context-lines 5

# No context (just show the line)
wp-analyze ~/Sites/my-plugin --no-context
```

### Advanced: Baseline Management

**Baseline files** let you "grandfather in" existing issues while preventing new ones:

```bash
# Generate baseline from current state
wp-analyze ~/Sites/my-plugin --format json --generate-baseline

# This creates .hcc-baseline in the scanned directory
# Commit this file to version control

# Future runs will only fail on NEW or INCREASED issues
wp-analyze ~/Sites/my-plugin --format json

# Ignore baseline temporarily (see all issues)
wp-analyze ~/Sites/my-plugin --format json --ignore-baseline

# Use custom baseline file
wp-analyze ~/Sites/my-plugin --format json --baseline /path/to/custom-baseline
```

**Use case:** Legacy codebase with 50 existing issues. Generate baseline, commit it. Now CI only fails on new issues while you fix old ones incrementally.

### Testing Baseline Functionality

Validate that baseline features work correctly on any project:

```bash
# Test baseline with default project (Save Cart Later)
./dist/tests/test-baseline-functionality.sh

# Test baseline with any template
./dist/tests/test-baseline-functionality.sh --project shoptimizer

# Test baseline with custom path
./dist/tests/test-baseline-functionality.sh --paths /path/to/your/plugin
```

**What it tests:**
- ✅ **Baseline generation**: Creates `.hcc-baseline` file correctly
- ✅ **Issue suppression**: Baselined issues don't cause failures
- ✅ **New issue detection**: Issues above baseline are caught
- ✅ **Stale baseline detection**: Reduced issues are flagged
- ✅ **Ignore flag**: `--ignore-baseline` works correctly

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Neochrome WP Toolkit - Baseline Functionality Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▸ Test: Baseline Generation
  ✓ PASSED: Baseline file created with 7 entries

▸ Test: Baseline Suppression
  ✓ PASSED: Baseline suppressed 7 findings
  ✓ PASSED: All issues successfully suppressed

▸ Test: New Issue Detection
  ✓ PASSED: Detected new issue above baseline

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Test Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Tests Run:    10
  Passed:       10
  Failed:       0

✓ All baseline tests passed!
```

**Use cases:**
- **Development**: Validate baseline works before committing changes
- **CI/CD**: Add to test suite for regression protection
- **Troubleshooting**: Diagnose baseline issues on user projects
- **Documentation**: Show users how baseline should behave

---

## 🔧 CI/CD Integration

### GitHub Actions

**Option 1: Standalone analyzer (recommended)**

```yaml
# .github/workflows/performance-audit.yml
name: Performance Audit

on: [push, pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Clone analyzer
        run: git clone https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git /tmp/analyzer

      - name: Run audit
        run: /tmp/analyzer/dist/bin/check-performance.sh --paths . --strict --format json
```

**Option 2: Include in project**

```yaml
# .github/workflows/performance-audit.yml
name: Performance Audit

on: [push, pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run audit
        run: ./dist/bin/check-performance.sh --paths . --strict
```

### GitLab CI

```yaml
# .gitlab-ci.yml
performance-audit:
  stage: test
  script:
    - git clone https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git /tmp/analyzer
    - /tmp/analyzer/dist/bin/check-performance.sh --paths . --strict
  only:
    - merge_requests
    - main
```

### Composer Integration (Optional)

If you prefer Composer-based workflows, add to your `composer.json`:

```json
{
  "scripts": {
    "audit": "./dist/bin/check-performance.sh --paths .",
    "audit:strict": "./dist/bin/check-performance.sh --paths . --strict",
    "audit:verbose": "./dist/bin/check-performance.sh --paths . --verbose",
    "ci": "@audit:strict"
  }
}
```

Then use:
```bash
composer audit
composer audit:strict
composer ci
```

---

## 📈 Understanding Results

### Exit Codes

| Code | Meaning | When It Happens |
|------|---------|-----------------|
| `0` | ✅ All checks passed | No errors found (warnings OK in normal mode) |
| `1` | ❌ Issues found | Errors found, OR warnings found in `--strict` mode |

### Output Formats

**Text (default)** - Human-readable, colored output:
```bash
wp-analyze ~/Sites/my-plugin
```

**JSON** - Machine-readable for CI/tooling:
```bash
wp-analyze ~/Sites/my-plugin --format json > results.json
```

JSON structure:
```json
{
  "version": "<SCRIPT_VERSION>",
  "timestamp": "2025-12-29T10:30:00Z",
  "paths_scanned": ["~/Sites/my-plugin"],
  "strict_mode": false,
  "summary": {
    "total_errors": 2,
    "total_warnings": 1,
    "baselined": 0,
    "stale_baseline": 0,
    "exit_code": 1
  },
  "findings": [
    {
      "id": "unbounded-posts-per-page",
      "severity": "error",
      "impact": "CRITICAL",
      "file": "./includes/query.php",
      "line": 42,
      "code": "'posts_per_page' => -1,",
      "message": "Unbounded posts_per_page can cause memory exhaustion"
    }
  ]
}
```

---

## 🧪 Experimental: Golden Rules Analyzer

**Status:** Experimental | **Location:** `dist/bin/experimental/` | **Requires:** PHP 7.4+

For projects that need **semantic analysis beyond pattern matching**, WP Code Check includes the Golden Rules Analyzer — an experimental PHP-based static analysis tool that catches architectural antipatterns.

> ⚠️ **Experimental Status:** This tool is functional but may have false positives and breaking changes in future releases. Use for code reviews and learning, not production CI/CD pipelines yet. [See experimental README](bin/experimental/README.md) for details.

### What It Catches

The Golden Rules Analyzer enforces **6 core architectural principles** that prevent "vibe coding drift":

| Rule | What It Detects | Why It Matters |
|------|----------------|----------------|
| **1. Search before you create** | Duplicate function implementations across files | Prevents code bloat and maintenance nightmares |
| **2. State flows through gates** | Direct state property mutations bypassing handlers | Ensures state changes are validated and auditable |
| **3. One truth, one place** | Hardcoded option names, duplicated capability checks | Eliminates magic strings and centralized configuration |
| **4. Queries have boundaries** | Unbounded queries, N+1 patterns in loops | Catches context-aware performance issues |
| **5. Fail gracefully** | Missing error handling for HTTP requests, file operations | Prevents silent failures and site hangs |
| **6. Ship clean** | Debug code, TODO/FIXME comments in production | Ensures production-ready code quality |

### Quick Start

```bash
# Basic analysis
php dist/bin/experimental/golden-rules-analyzer.php /path/to/plugin

# Analyze specific rule
php dist/bin/experimental/golden-rules-analyzer.php /path/to/plugin --rule=query-boundaries

# JSON output for CI/CD
php dist/bin/experimental/golden-rules-analyzer.php /path/to/plugin --format=json

# GitHub Actions format
php dist/bin/experimental/golden-rules-analyzer.php /path/to/plugin --format=github

# Fail on specific severity
php dist/bin/experimental/golden-rules-analyzer.php /path/to/plugin --fail-on=error
```

### Configuration

Create `.golden-rules.json` in your project root to customize detection:

```json
{
  "state_handlers": ["set_state", "transition_to", "update_status"],
  "state_properties": ["$this->state", "$this->status", "$this->current_state"],
  "helper_classes": ["Helper", "Utils", "Utilities"],
  "ignore_paths": ["vendor/", "node_modules/", "tests/"],
  "severity_threshold": "warning"
}
```

### Available Rules

Run specific rules with `--rule=<name>`:

- `duplication` - Detect duplicate function implementations
- `state-gates` - Catch direct state mutations
- `single-truth` - Find magic strings and duplicated configuration
- `query-boundaries` - Detect unbounded queries and N+1 patterns
- `graceful-failure` - Find missing error handling
- `ship-clean` - Catch debug code and TODO comments

### Example Output

```
/path/to/plugin/includes/query-helpers.php

  ERROR Line 45: WP_Query without posts_per_page — will load ALL posts
    → Add "posts_per_page" => 100 (or appropriate limit)

  WARNING Line 78: Function "get_user_display_name" may duplicate existing functionality
    → Check these similar functions: get_display_name (helpers.php)

Summary: 2 errors, 1 warning, 0 info
```

### When to Use Each Tool

| Scenario | Use This Tool |
|----------|---------------|
| **Quick CI/CD checks** | `check-performance.sh` (bash scanner) |
| **Pre-commit hooks** | `check-performance.sh` (fast, zero dependencies) |
| **Deep code review** | `experimental/golden-rules-analyzer.php` (semantic analysis) |
| **Refactoring audit** | `experimental/golden-rules-analyzer.php` (finds duplication) |
| **Combined workflow** | Run both for complete coverage |

### Combined Workflow Example

```bash
# 1. Quick scan (30+ checks in <5s)
./dist/bin/check-performance.sh --paths ~/my-plugin --format json > quick-scan.json

# 2. Deep analysis (6 architectural rules - experimental)
php ./dist/bin/experimental/golden-rules-analyzer.php ~/my-plugin --format json > deep-analysis.json

# 3. Review both reports
cat quick-scan.json deep-analysis.json
```

### CI/CD Integration

**GitHub Actions:**
```yaml
- name: Quick Scan
  run: ./dist/bin/check-performance.sh --paths . --strict

- name: Deep Analysis (Experimental)
  run: php ./dist/bin/experimental/golden-rules-analyzer.php . --fail-on=error
```

**Pre-commit Hook (Experimental):**
```bash
#!/bin/bash
# .git/hooks/pre-commit
php ./dist/bin/experimental/golden-rules-analyzer.php . --fail-on=error
```

---

## 🛠️ Suppressing False Positives

Sometimes a pattern is intentional (e.g., admin-only query, cached result). Suppress with `phpcs:ignore`:

```php
// Suppress specific check
// phpcs:ignore WordPress.WP.PostsPerPage.posts_per_page_posts_per_page
$posts = get_posts( array( 'posts_per_page' => -1 ) );

// Suppress with explanation (recommended)
// phpcs:ignore WordPress.DateTime.CurrentTimeTimestamp.Requested -- Intentional for display formatting
$timestamp = current_time( 'timestamp' );

// Suppress entire line (any check)
// phpcs:ignore
$data = file_get_contents( 'https://api.example.com/data' );
```

**Best practice:** Always add `-- Explanation` to document WHY it's safe.

---

## 📦 What's Included

### Core Tools

| File | Purpose |
|------|---------|
| `dist/bin/check-performance.sh` | **Quick Scanner** - Bash-based, detects 30+ antipatterns in <5s |
| `dist/bin/json-to-html.py` | Convert JSON scan results to beautiful HTML reports |
| `dist/bin/wp-audit` | **Unified CLI** - Orchestrates quick scan, deep analysis, and reporting |
| `dist/tests/fixtures/*.php` | Test fixtures (antipatterns + clean code) |
| `dist/tests/run-fixture-tests.sh` | Validation test suite (number of tests may grow over time) |

### Experimental Tools

| File | Purpose | Status |
|------|---------|--------|
| `dist/bin/experimental/golden-rules-analyzer.php` | **Deep Analyzer** - PHP-based semantic analysis, 6 architectural rules | 🧪 Experimental |

> See [experimental/README.md](bin/experimental/README.md) for detailed usage guide and end-to-end workflow examples.

### Integration Tools

| File | Purpose |
|------|---------|
| `dist/bin/post-to-slack.sh` | Post results to Slack webhook |
| `dist/bin/format-slack-message.sh` | Format JSON as Slack Block Kit |
| `dist/bin/test-slack-integration.sh` | Test Slack integration |
| `setup-integration-security.sh` | Setup credential protection |

See the `PROJECT/` directory for detailed integration and architectural docs.

---

## 🔔 Slack/Discord Notifications

Get real-time alerts when performance checks fail in CI:

```bash
# 1. Setup credential protection (prevents accidental commits)
./setup-integration-security.sh

# 2. Test integration (no credentials needed)
./dist/bin/test-slack-integration.sh

# 3. Configure webhook
cp .env.example .env
nano .env  # Add SLACK_WEBHOOK_URL

# 4. Test with real webhook
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK"
./dist/bin/test-slack-integration.sh

# 5. Use in CI/CD
./dist/bin/check-performance.sh --format json > results.json
./dist/bin/post-to-slack.sh results.json
```

**GitHub Actions example:**
```yaml
- name: Notify Slack on failure
  if: failure()
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  run: |
    ./dist/bin/check-performance.sh --format json > results.json
    ./dist/bin/post-to-slack.sh results.json
```

---

## 📝 Logging

Logs are written to `dist/logs/` by default:
- **Format:** `YYYY-MM-DD-HHMMSS-UTC.log`
- **Disable:** Use `--no-log` flag
- **Location:** Relative to script location (not scanned directory)

Add to `.gitignore`:
```bash
echo "dist/logs/" >> .gitignore
```

---

## 🤖 For AI Assistants

**Recommended workflow:**

1. **Run audit:**
   ```bash
   ./dist/bin/check-performance.sh --paths "." --verbose
   ```

2. **If errors found:** Fix them before proceeding (these will crash production)

3. **If warnings found:** Evaluate if intentional or need fixing

4. **Document findings:** Create audit report in `AUDITS/` folder

5. **Generate baseline** (if legacy codebase):
   ```bash
   ./dist/bin/check-performance.sh --paths "." --format json --generate-baseline
   ```

---

## 🔗 Links & Support

- **Repository:** https://github.com/Hypercart-Dev-Tools/WP-Code-Check
- **Issues:** https://github.com/Hypercart-Dev-Tools/WP-Code-Check/issues
- **Documentation:** See `PROJECT/` directory for detailed guides
- **Disclosure Policy:** See `../DISCLOSURE-POLICY.md`
- **Contact:** noel@hypercart.io

---

## 📄 License

© Copyright 2025 Neochrome, Inc. All rights reserved.
