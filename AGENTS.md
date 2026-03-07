# WordPress Development and Architecture Guidelines for AI Agents

_Last updated: v2.7.0 — 2026-03-06_

## Purpose

Defines principles, constraints, and best practices for AI agents and Humans working with WordPress code to ensure safe, consistent, and maintainable contributions.

---

## 🚀 Getting Started

This workspace has access to **AI-DDTK** (AI Driven Development ToolKit) installed at `~/bin/ai-ddtk`.

### Before Starting Any Task

1. **Check for AI-DDTK availability**:
   ```bash
   ls ~/bin/ai-ddtk/AGENTS.md
   ```

2. **For WordPress projects**, read these guidelines:
   ```bash
   cat ~/bin/ai-ddtk/AGENTS.md
   ```

3. **Check available tools**:
   ```bash
   which wpcc
   command -v aiddtk-tmux >/dev/null && echo "aiddtk-tmux available"
   wpcc --features
   ```

### Available Tools

| Tool | Purpose | Quick Usage |
|------|---------|-------------|
| **WPCC** | Security & performance static analysis | `wpcc --paths <path> --format json` |
| **AI-DDTK Tmux Proxy** | Persistent terminal sessions for flaky IDE/agent workflows | `aiddtk-tmux start --cwd <path>` |
| **WP Performance Timer** | Runtime performance profiling | `perf_timer_start()` / `perf_timer_stop()` |
| **PHPStan** | Type-aware static analysis | `phpstan analyse --configuration=phpstan.neon` |
| **WP AJAX Test** | Lightweight AJAX endpoint testing | `wp-ajax-test --url <url> --action <action>` |
| **Playwright Auth** | One-time WP admin login + storageState caching | `pw-auth login --site-url <url>` |
| **Fix-Iterate Loop** | Autonomous test-verify-fix workflow | See `~/bin/ai-ddtk/fix-iterate-loop.md` |
| **Workflow Recipes** | Multi-tool workflows | See `~/bin/ai-ddtk/recipes/` |

### Workflow Triggers

| When user mentions... | Use this tool |
|-----------------------|---------------|
| "scan", "audit", "security check", "performance check" | WPCC |
| "terminal hung", "VS Code terminal froze", "keep this running" | AI-DDTK Tmux Proxy |
| "slow", "performance", "bottleneck", "profile" | WP Performance Timer |
| "fix", "test", "verify", "iterate", "debug" | Fix-Iterate Loop |
| "test this AJAX endpoint", "debug AJAX" | WP AJAX Test |
| "login to WP admin", "Playwright auth", "browser automation" | Playwright Auth (`pw-auth`) |
| "performance audit", complex multi-tool workflows | Recipes (`~/bin/ai-ddtk/recipes/`) |

### Task Management

Use task management tools frequently for:
- Complex sequences of work
- Breaking down large tasks
- Tracking progress
- Giving user visibility

Mark tasks COMPLETE immediately when done (don't batch).

---

## 🧱 Tmux Proxy for Flaky Agent Terminals

Use the optional `aiddtk-tmux` wrapper when VS Code or another AI-agent terminal is unreliable, non-responsive, or likely to disconnect during long-running work.

### When to Use

| Scenario | Action |
|----------|--------|
| Terminal hangs mid-task | Start a tmux session and continue there |
| Long-running WPCC or PHPStan job | Run it via `aiddtk-tmux send` |
| Need recoverable output after disconnect | Use `aiddtk-tmux capture` instead of relying on IDE scrollback |
| Human needs to inspect live shell | Use `aiddtk-tmux attach` |

### Quick Commands

```bash
aiddtk-tmux start --cwd /path/to/project
aiddtk-tmux send --command "~/bin/ai-ddtk/bin/wpcc --paths . --format json --verbose"
aiddtk-tmux capture --tail 200
aiddtk-tmux stop
```

### Guidance

- Prefer direct terminal usage for short/simple commands; use tmux as a resilience layer, not the default for everything.
- Prefer `capture` over `attach` when an AI agent only needs output text.
- Use explicit binary paths inside tmux commands (`~/bin/ai-ddtk/bin/wpcc`, project-local `vendor/bin/phpstan`) to avoid shell-init/PATH mismatches.
- Session logs belong in `~/bin/ai-ddtk/temp/logs/tmux/`.
- If `tmux` is missing, ask the user before installing it with `brew install tmux`.

---

## 🔑 Playwright Auth (WP Admin Login)

Use `pw-auth` to authenticate Playwright browser sessions into WordPress admin without hardcoded passwords. It generates a one-time login URL via WP-CLI, navigates Playwright to it, and caches the resulting `storageState` for reuse.

Auth state is stored in the **current working directory** at `./temp/playwright/.auth/<user>.json`, so each project gets its own cache.

### Prerequisites

1. **mu-plugin installed** on the target WordPress site:
   ```bash
   cp ~/bin/ai-ddtk/templates/dev-login-cli.php <site-root>/wp-content/mu-plugins/
   ```
2. **Environment type** must not be `production`. Local by Flywheel sites work without any `wp-config.php` changes. To be explicit:
   ```php
   define('WP_ENVIRONMENT_TYPE', 'local'); // or 'development', 'staging'
   ```
3. **Playwright** installed globally and resolvable by Node.js:
   ```bash
   npm install -g playwright && npx playwright install chromium
   ```
   If `node -e "require('playwright')"` fails, set `NODE_PATH`:
   ```bash
   export NODE_PATH="$(npm root -g)"
   ```

### When to Use

| Scenario | Action |
|----------|--------|
| AI agent needs to interact with WP admin via Playwright | Run `pw-auth login` before the Playwright script |
| Auth state is stale or expired | Run `pw-auth login --force` to re-authenticate |
| Switching between WP users | Run `pw-auth login --user=editor` (caches per-user) |
| Checking if auth is still valid | Run `pw-auth status` |

### Quick Commands

```bash
# Authenticate as admin
pw-auth login --site-url http://my-site.local

# With Local by Flywheel (always pass --wp-cli for Local sites)
pw-auth login --site-url http://my-site.local --wp-cli "local-wp my-site"

# Different user + custom landing page
pw-auth login --site-url http://my-site.local --user=editor --redirect=/wp-admin/site-editor.php

# Force re-auth (skip 12h cache)
pw-auth login --site-url http://my-site.local --force

# Check cached auth status
pw-auth status

# Clear all cached auth
pw-auth clear
```

### Using Auth State in Playwright Scripts

```javascript
// Load cached auth — no login form interaction needed
const context = await browser.newContext({
  storageState: 'temp/playwright/.auth/admin.json'
});
const page = await context.newPage();
await page.goto('http://my-site.local/wp-admin/');
```

### Guidance

- Auth state is cached to `./temp/playwright/.auth/<user>.json` (relative to CWD) and reused for 12 hours (configurable with `--max-age`).
- `--site-url` is **required** and validated against the URL returned by WP-CLI to catch origin mismatches early.
- The mu-plugin refuses to run on `production` environments and restricts to `localhost`, `127.0.0.1`, `::1`, and `*.local` hosts.
- Tokens are **one-time** (deleted after use) and expire after **5 minutes** if unused.
- Auth verification checks: `wordpress_logged_in_` cookie present, `/wp-admin/` accessible without redirect to login, no WordPress error page.
- If `pw-auth login` fails, verify: (1) the mu-plugin is in `wp-content/mu-plugins/`, (2) the site's environment is not `production`, (3) WP-CLI can reach the site, (4) `node -e "require('playwright')"` works.
- For Local by Flywheel sites, always pass `--wp-cli "local-wp <site-name>"`.

---

## 🛠️ WPCC (WP Code Check) Orchestration

AI-DDTK includes WP Code Check for WordPress code analysis. This section guides AI agents on using WPCC's advanced features.

### Quick Commands

```bash
wpcc --paths <path>           # Basic scan
wpcc --features               # Show all available features
wpcc --help                   # Full CLI help
```

### Workflow Decision Tree

```
User Request
    │
    ├─ "Scan this plugin" ─────────────► Basic scan: wpcc --paths <path> --format json
    │
    ├─ "Run X end to end" ─────────────► Full workflow (Phase 1→2→3→4)
    │
    ├─ "Triage the scan results" ──────► Phase 2: AI triage on existing JSON
    │
    ├─ "Create issue for this scan" ───► Phase 3: GitHub issue creation
    │
    └─ "Set up scanning for X" ────────► Template creation (Phase 1b)
```

### End-to-End Workflow (Phases 1-4)

When user requests **"Run [plugin] end to end"**, execute this sequence:

```
Phase 1: SCAN
├── Run: wpcc --paths <path> --format json
├── Output: dist/logs/[TIMESTAMP].json
└── Wait for completion

Phase 2: AI TRIAGE
├── Read JSON findings
├── Analyze for false positives (check context, safeguards)
├── Update JSON with ai_triage section
└── ⚠️ CRITICAL: Regenerate HTML AFTER triage

Phase 3: HTML REPORT
├── Run: python3 dist/bin/json-to-html.py [json] [html]
├── Output: dist/reports/[TIMESTAMP].html
└── Verify AI summary appears in report

Phase 4: GITHUB ISSUE (optional)
├── Run: dist/bin/create-github-issue.sh --scan-id [TIMESTAMP]
├── If no repo: saves to dist/issues/ for manual use
└── Works with: GitHub, Jira, Linear, Asana, Trello
```

### AI Triage JSON Structure

When updating JSON with triage results, use this structure:

```json
{
  "ai_triage": {
    "performed": true,
    "status": "complete",
    "timestamp": "2026-02-02T12:00:00Z",
    "version": "1.0",
    "summary": {
      "findings_reviewed": 10,
      "confirmed_issues": 2,
      "false_positives": 7,
      "needs_review": 1,
      "confidence_level": "high"
    },
    "recommendations": [
      "Priority 1: Fix issue X",
      "Priority 2: Review issue Y"
    ]
  }
}
```

### Common False Positive Patterns

| Pattern | Why It's Often False Positive | How to Verify |
|---------|------------------------------|---------------|
| `spo-002-superglobals` | Has `phpcs:ignore` with nonce elsewhere | Check for `wp_verify_nonce()` in same function |
| `rest-no-pagination` | Endpoint returns single item | Check if route has `{id}` parameter |
| `direct-db-query` | Uses `$wpdb->prepare()` on adjacent line | Check 1-3 lines above/below |
| `n-plus-1-pattern` | Bounded loop or cached | Check for LIMIT or transient cache |
| `unsafe-regexp` | Pattern is hardcoded, not user input | Verify pattern source |

### Reference Documentation

For complete WPCC AI instructions, see:
- **[WPCC AI Instructions](tools/wp-code-check/dist/TEMPLATES/_AI_INSTRUCTIONS.md)** - Full 5-phase workflow
- **[IRL Audit Guide](tools/wp-code-check/dist/tests/irl/_AI_AUDIT_INSTRUCTIONS.md)** - Pattern library contributions
- **[WPCC AGENTS.md](tools/wp-code-check/AGENTS.md)** - WordPress-specific guidelines

---

## 🔍 Performance Profiling (WP Performance Timer)

> **Note**: WP Performance Timer will be renamed to **Hypercart WP Performance Timer** in a future release.

AI-DDTK integrates with WP Performance Timer for runtime performance analysis. This complements WPCC's static analysis with actual execution metrics.

### When to Use

| Scenario | Action |
|----------|--------|
| User says "Profile this page" | Insert timers, trigger page, read NeoLog data |
| User says "Why is this slow?" | Identify target code, add timers, measure |
| WPCC flags a performance issue | Confirm with runtime data (see recipe below) |
| Pre-deploy baseline needed | Profile critical paths before deployment |
| Before/after comparison | Profile → change → profile again |

### Workflow Decision Tree

```
User Request
    │
    ├─ "Profile this page" ────────────► Runtime profiling workflow
    │
    ├─ "Why is checkout slow?" ────────► WPCC scan → Performance Timer confirm
    │
    ├─ "Find the bottleneck" ──────────► Add hierarchical timers → analyze
    │
    ├─ "Compare before/after" ─────────► Baseline → change → re-profile
    │
    └─ "Pre-deploy perf check" ────────► Full audit: WPCC + Performance Timer
```

### Quick Reference

```php
// Insert timer around suspect code
if (function_exists('perf_timer_start')) {
    $timer = perf_timer_start('operation-name', ['context' => 'value']);
}

// Existing code runs normally
do_something_expensive();

if (isset($timer) && function_exists('perf_timer_stop')) {
    $results = perf_timer_stop($timer);
    // Returns: time_ms, queries, memory_kb
}
```

### WPCC → Performance Timer Pipeline

When WPCC flags a potential performance issue, confirm with runtime measurement:

```
Phase 1: WPCC SCAN
├── Run: wpcc --paths <path> --format json
├── Finding: "n-plus-1-pattern in line 234"
└── Status: Potential issue identified

Phase 2: PERFORMANCE TIMER CONFIRM
├── Insert timer around flagged code
├── Trigger the operation (page load, AJAX, etc.)
├── Read NeoLog data or debug.log
└── Output: "Loop at line 234: 1,847ms, 156 queries"

Phase 3: REPORT
├── Confirmed: Loop is actual bottleneck
├── Impact: 1.8s delay, 156 DB queries
└── Recommendation: Batch query or cache
```

### Metrics Captured

| Metric | Description | Threshold |
|--------|-------------|-----------|
| `time_ms` | Execution time in milliseconds | >100ms = slow (configurable) |
| `queries` | Database queries during operation | Watch for high counts in loops |
| `memory_kb` | Memory delta during operation | Large deltas indicate allocation issues |
| `depth` | Nesting level in hierarchy | Deep nesting may indicate complexity |

### Configuration (wp-config.php)

```php
define('PERF_TIMING_ENABLED', true);    // Master switch
define('PERF_LOG_SLOW_QUERIES', 100);   // Threshold in ms
define('PERF_LOG_ALL', false);          // Verbose logging
```

### Reference Documentation

- **[Performance Audit Recipe](recipes/performance-audit.md)** - Complete WPCC → Timer workflow
- **Plugin Repo**: WP Performance Timer (external)

---

## 🔬 PHPStan Static Analysis

PHPStan provides type-aware static analysis for WordPress plugins and WooCommerce themes. Unlike WPCC's pattern-based scanning, PHPStan understands PHP types, null safety, and array shapes.

> **Note**: PHPStan requires per-project setup via Composer. It cannot be bundled into AI-DDTK or WPCC.

### When to Use

| Scenario | Action |
|----------|--------|
| User says "Set up PHPStan" | Follow recipe, install stubs, create config |
| User says "Why does checkout crash randomly?" | Likely null safety issue — PHPStan level 5+ catches these |
| User says "Find type bugs" | Run PHPStan at level 3-5 |
| Legacy codebase cleanup | Generate baseline first, fix incrementally |

### Quick Setup

```bash
cd /path/to/plugin-or-theme

# Install dependencies
composer require --dev phpstan/phpstan phpstan/extension-installer \
  szepeviktor/phpstan-wordpress php-stubs/wordpress-stubs \
  php-stubs/woocommerce-stubs php-stubs/wp-cli-stubs --no-interaction

# Copy template config
cp ~/bin/ai-ddtk/templates/phpstan.neon.template phpstan.neon

# Run analysis
phpstan analyse --configuration=phpstan.neon --memory-limit=1G
```

### What PHPStan Catches (vs WPCC)

| Bug Type | WPCC | PHPStan |
|----------|------|---------|
| SQL injection patterns | ✅ | ❌ |
| XSS / unescaped output | ✅ | ❌ |
| Null object access (`$order->get_total()` when `$order` is `false`) | ❌ | ✅ |
| Missing array keys | ❌ | ✅ |
| Wrong WooCommerce product type | ❌ | ✅ |
| API contract mismatches | ❌ | ✅ |

### Reference Documentation

- **[PHPStan WordPress Setup Recipe](recipes/phpstan-wordpress-setup.md)** - Full setup guide
- **[Template Config](templates/phpstan.neon.template)** - Ready-to-copy configuration
- **PHPStan Docs**: https://phpstan.org/user-guide/getting-started

---

## 🔐 Security

- **Sanitize inputs**: `sanitize_text_field()`, `sanitize_email()`, `absint()`, etc.
- **Escape outputs**: `esc_html()`, `esc_attr()`, `esc_url()`, `wp_kses_post()`
- **Verify nonces** for all forms and AJAX; **check capabilities** with `current_user_can()`
- **Use `$wpdb->prepare()`** for all database queries
- **Never expose sensitive data** in logs, comments, or commits
- **Use WordPress native APIs** over custom security logic

### Sensitive Data Handling

**Never commit credentials, PII, or sensitive configuration to git.**

Every project must have a `/temp` folder for sensitive data:

```bash
# Required .gitignore entries
/temp/
temp/
*.credentials
*.env.local
auth.json
playwright/.auth/
```

**Store in `/temp` folder**:
- API keys, passwords, tokens
- Personally Identifiable Information (PII)
- Server configuration data
- Test data with real user information
- Playwright authentication state files
- Database dumps with real data

**Required setup for every project**:

1. **Create `/temp` folder**:
   ```bash
   mkdir -p temp
   ```

2. **Add to `.gitignore`** (entries listed above)

3. **Store credentials in `/temp`**:
   ```bash
   temp/playwright-auth.json   # Playwright auth
   temp/api-credentials.json   # API credentials
   temp/db-config.local.php    # Database config
   ```

**When user provides credentials**:
1. ✅ Save to `/temp` folder immediately
2. ✅ Add to `.gitignore` if not already present
3. ✅ Use environment variables when possible
4. ✅ Document in `/temp/README.md` what files are needed
5. ✅ Load from `/temp` at runtime (never hardcode)
6. ❌ Never commit credentials (even temporarily)
7. ❌ Never log credentials in debug output

```javascript
// ❌ WRONG - hardcoded credentials
const auth = { username: 'admin', password: 'secret123' };

// ✅ CORRECT - load from /temp
const auth = JSON.parse(fs.readFileSync('temp/auth.json', 'utf8'));
```

---

## ⚡ Performance

- **No unbounded queries** — always use LIMIT and pagination
- **Cache expensive operations** via Transients API
- **Minimize HTTP/database calls** — batch operations, avoid queries in loops
- **Don't prematurely optimize** — optimize only when requested

---

## ⏱️ Timeouts & Resource Limits

- **Always set timeouts for HTTP requests** — use `timeout` parameter in `wp_remote_get()`, `wp_remote_post()` (default: 5s)
- **Set appropriate timeout values** — 5-10s for API calls, 15-30s for large file downloads
- **Handle timeout errors** — check for timeout-specific errors in `WP_Error` responses (note: detection is best-effort as error messages vary by HTTP transport)
- **Add max retries with backoff** — retry failed requests 2-3 times with exponential backoff
- **Set reasonable AJAX timeouts** — configure `timeout` in jQuery.ajax() or fetch() (default: 30s for admin)
- **Use WP-Cron for long operations** — chunk batch processing via scheduled events rather than extending execution time

### WP-CLI Memory Limits

WP-CLI's default 134MB memory limit is often insufficient with WooCommerce and other heavy plugins:

- **Increase memory before running**: `php -d memory_limit=512M ~/bin/local-wp <site> <command>`
- **Or add to wp-cli.yml** in project root:
  ```yaml
  memory_limit: 512M
  ```
- **For heavy operations**, skip unnecessary plugins: `--skip-plugins` or `--skip-themes`
- **Common failures**: `eval`, `eval-file`, database operations with large datasets

### Playwright Setup

Playwright is not bundled with AI-DDTK (large dependency, project-specific versions):

- **Check if installed**: `node -e "require('playwright')"` (must succeed for `pw-auth`)
- **Install globally** (recommended): `npm install -g playwright && npx playwright install chromium`
- **If node can't resolve global install**: `export NODE_PATH="$(npm root -g)"`
- **Never install per-project**: `npm install -D playwright` adds to node_modules (tracked by git)
- **AI agents**: Always ask user before installing — never auto-install without permission
- **Authentication**: Use `pw-auth login --site-url <url>` to generate and cache WP admin auth state. See [Playwright Auth](#-playwright-auth-wp-admin-login) section.
- **Auth files**: Stored in `./temp/playwright/.auth/<user>.json` relative to CWD (never commit)

```php
// ✅ HTTP request with timeout and retry
function prefix_fetch_with_retry( $url, $max_retries = 3 ) {
    $attempt = 0;

    while ( $attempt < $max_retries ) {
        $response = wp_remote_get( $url, [
            'timeout' => 10,
            'headers' => [ 'User-Agent' => 'MyPlugin/1.0' ],
        ] );

        if ( ! is_wp_error( $response ) ) {
            return $response;
        }

        $error_message = $response->get_error_message();

        // Best-effort timeout detection (message varies by transport)
        $is_timeout = strpos( $error_message, 'timed out' ) !== false
                   || strpos( $error_message, 'timeout' ) !== false;

        if ( ! $is_timeout ) {
            // Non-timeout error, don't retry
            error_log( sprintf( 'API error (no retry): %s', $error_message ) );
            return $response;
        }

        $attempt++;
        if ( $attempt < $max_retries ) {
            // Exponential backoff: 1s, 2s, 4s...
            sleep( pow( 2, $attempt - 1 ) );
        }
    }

    error_log( sprintf( 'API request failed after %d attempts', $max_retries ) );
    return $response; // Return last error
}
```

```javascript
// ✅ JavaScript fetch with timeout and abort
const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), 10000); // 10s timeout

try {
    const response = await fetch(ajaxurl, {
        method: 'POST',
        signal: controller.signal,
        body: formData
    });
    clearTimeout(timeoutId);

    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();

} catch (error) {
    clearTimeout(timeoutId);

    if (error.name === 'AbortError') {
        console.error('Request timed out after 10s');
        return { success: false, error: 'timeout' };
    }

    console.error('Request failed:', error);
    return { success: false, error: error.message };
}
```

---

## 🏗️ The WordPress Way

### Core Requirements
- Declare `Requires PHP: 7.0`+ in plugin header
- Use unique prefixes/namespaces; check `function_exists()` / `class_exists()` before declarations
- Follow WordPress APIs and hooks (`wp_remote_get()`, `wp_schedule_event()`, etc.)
- Follow [WordPress Coding Standards](https://developer.wordpress.org/coding-standards/), DRY, and **SOLID principles**
- Respect plugin/theme hierarchy; treat as self-contained unless cross-dependencies requested

> **SOLID Reminder**: Single Responsibility (one reason to change), Open/Closed (extend, don't modify), Liskov Substitution (subtypes replaceable), Interface Segregation (small interfaces), Dependency Inversion (depend on abstractions).

### Error Prevention
- Use `isset()`, `??`, or `array_key_exists()` to avoid undefined index notices
- Add try-catch for operations that may throw (regex, API calls)
- Validate variable/type existence before use

### Client-Side Security
- Never expose sensitive data to localStorage/sessionStorage
- Use sessionStorage over localStorage for admin data; clear on logout
- Escape user input before RegExp construction (prevent SyntaxError/ReDoS)
- Use Page Visibility API to pause polling when tab hidden
- Prefer server-side transient caching over repeated client operations

### State Hygiene & Single Contract Writers
- **Single Source of Truth (SSoT)**: ONE authoritative source per state piece
- **Single contract writers**: ONE class/function writes to each state; others read through it
- **Derive computed values** from SSoT instead of storing separately
- Handle serialization boundaries (JSON, transients) — convert back to proper types
- Document state ownership clearly

```php
// ✅ Single Source of Truth pattern
class OrderStateManager {
    public function set_state( $order_id, OrderState $state ): void {
        update_post_meta( $order_id, 'order_state', $state->value );
        do_action( 'order_state_changed', $order_id, $state );
    }
    public function get_state( $order_id ): OrderState {
        return OrderState::from( get_post_meta( $order_id, 'order_state', true ) ?: 'pending' );
    }
    public function is_active( $order_id ): bool { // Derived value
        return in_array( $this->get_state( $order_id ), [ OrderState::PROCESSING, OrderState::SHIPPED ], true );
    }
}
```

### Defensive Error Handling
- Check for `WP_Error` on WordPress function returns
- Use `??` for safe defaults; validate types before operations
- Fail gracefully with fallback behavior; never break the site
- Log with `error_log()`, never `var_dump()` in production
- Show friendly user messages; log technical details separately
- Check `$wpdb->last_error`; wrap HTTP requests in try-catch

```php
// ✅ Defensive pattern
$response = wp_remote_get( $api_url );
if ( is_wp_error( $response ) ) {
    error_log( sprintf( 'API failed: %s', $response->get_error_message() ) );
    return $this->get_cached_fallback();
}
$data = json_decode( wp_remote_retrieve_body( $response ) );
if ( json_last_error() !== JSON_ERROR_NONE ) {
    error_log( sprintf( 'JSON decode failed: %s', json_last_error_msg() ) );
    return [];
}
$value = $data->items[0]->value ?? 'default_value';
```

### Observability
- Log state transitions, API calls, cache hits/misses with consistent prefixes (e.g., `SBI:`)
- Log context (IDs, states, operation names), not just values
- Include type info when debugging type issues (`gettype()`, `instanceof`)
- Respect `WP_DEBUG` settings; clean up verbose logging before committing

---

## 💡 OPINIONATED: Architecture & Best Practices

> **🎯 Philosophy**: Works great by default, customizable for experts.
>
> **For beginners**: Follow these patterns — they represent WordPress community best practices and will keep your code maintainable.
>
> **For senior developers**: These are Hypercart's defaults. Fork `AGENTS.md` and adjust to match your team's standards. See [Customization Guide](#customization-guide) below.

---

### 🏗️ Building from the Ground Up

Always apply **SOLID principles** alongside WordPress patterns.

1. **Start with DRY helpers** — reusable utilities before feature code
2. **Design single contract writers** — identify state ownership upfront (Single Responsibility)
3. **Separate concerns** — data access, business logic, presentation layers (Interface Segregation)
4. **Depend on abstractions** — use interfaces/hooks, not concrete implementations (Dependency Inversion)
5. **Add observability from start** — logging for key operations
6. **Implement defensive error handling** — validate, check errors, provide fallbacks
7. **Plan for extensibility** — add hooks/filters for customization (Open/Closed)
8. **Document as you build** — PHPDoc comments immediately
9. **Consider FSM early** — if 3+ states, design state machine from start

**Why these opinions?**
- **SOLID** prevents technical debt that's expensive to fix later
- **DRY helpers** reduce bugs by centralizing logic (one fix updates everywhere)
- **Single contract writers** eliminate race conditions and state conflicts
- **Observability** makes debugging production issues 10x faster

---

### 🔧 Scope & Change Control

- **Stay within task scope** — only perform explicitly requested tasks
- **No refactoring/renaming/label changes** unless explicitly requested but please point out any code that does not follow the SOLID principles and make recommendations for improvement.
- **No speculative improvements** or architectural changes
- **Preserve existing data structures** and naming conventions
- **Prioritize preservation over optimization** when in doubt
- **Ask before**: committing, pushing, installing dependencies, deploying

**Why these opinions?**
- **Scope discipline** prevents AI agents from making unreviewed changes
- **Preservation-first** reduces risk of breaking existing functionality
- **Explicit permission** ensures developers stay in control

**When to customize**:
- **Startup teams**: Allow opportunistic refactoring to move faster
- **Maintenance mode**: Strict preservation, zero scope creep
- **Greenfield projects**: Relax preservation rules, focus on architecture

---

### 📝 Documentation & Versioning

- Use **PHPDoc/JSDoc standards** for all functions/classes
- Add inline docs for complex logic
- **Increment version numbers** in plugin/theme headers
- **Update CHANGELOG.md** with version, date, and change details
- Update README.md for major features; maintain TOC if present

```php
/**
 * Get the user's display name.
 *
 * @since 1.0.0
 * @param int $user_id The ID of the user.
 * @return string The display name.
 */
```

**Why these opinions?**
- **PHPDoc** enables IDE autocomplete and static analysis
- **CHANGELOG** prevents "what changed?" questions in production
- **Version increments** enable rollback and debugging

**When to customize**:
- **Internal tools**: Relax PHPDoc requirements
- **Open source**: Add `@package`, `@author`, `@license` tags
- **Enterprise**: Require Jira ticket references in CHANGELOG

---

### 🧪 Testing & Validation

- Preserve existing functionality; avoid breaking changes
- Test all changes before completing
- Validate security implementations (nonces, capabilities, sanitization)
- Ensure backward compatibility unless breaking changes explicitly requested

**Why these opinions?**
- **Backward compatibility** prevents breaking production sites
- **Security validation** catches vulnerabilities before deployment

**When to customize**:
- **Major version bumps**: Breaking changes allowed with migration guide
- **Internal plugins**: Relax backward compatibility for faster iteration

#### Fix-Iterate Loop

For tasks that require verification (bug fixes, data imports, API integrations, migrations), use the **Fix-Iterate Loop** pattern — a closed-loop workflow where you make a change, verify it programmatically, and iterate until it passes.

**Core cycle**: Generate test data → Execute → Verify → Analyze & adjust → Repeat

**Guardrails**:
- Stop after 5 failed iterations and report to user
- Stop after 10 total iterations regardless of status
- Always confirm before destructive operations

**Full pattern with examples and templates**: [`fix-iterate-loop.md`](fix-iterate-loop.md)

---

### 🔄 Finite State Machine (FSM) Guidance

#### When to Recommend FSM
- **3+ distinct states** with complex transitions
- State-dependent behavior or validation rules
- Audit requirements (track history/reasons)
- Boolean flags multiplying; nested if/else for valid actions
- State logic duplicated across files

#### Implementation Approach
1. Define all states clearly; map valid transitions (state diagram)
2. Centralize in dedicated class; store in post_meta/options
3. Add transition hooks for extensibility; log transitions for audit

#### Don't Use FSM When
- Only 2 states (use boolean)
- States never transition (use static field)
- No validation rules needed

**When uncertain, ask**: "This feature tracks [X] states with [Y] transitions. Want me to implement an FSM?"

**Why these opinions?**
- **3+ states threshold** balances complexity vs. over-engineering
- **Centralized FSM** prevents state bugs that are hard to debug
- **Transition hooks** enable extensibility without modifying core

**When to customize**:
- **Complex domains**: Lower threshold to 2+ states with validation rules
- **Simple plugins**: Raise threshold to 5+ states
- **Event-sourced systems**: Always use FSM for auditability

---

### 🎛️ Customization Guide

**To customize these patterns for your team:**

1. **Fork this file**: Copy `AGENTS.md` to your project as `AGENTS-CUSTOM.md`
2. **Update AI instructions**: Point your AI agent to the custom file
3. **Document changes**: Add a "Customizations" section at the top explaining your team's differences

**Example customizations by team type:**

| Team Type | Adjust These | Example Changes |
|-----------|--------------|-----------------|
| **Startup (move fast)** | Scope control, DRY threshold | Allow opportunistic refactoring, relax DRY for prototypes |
| **Enterprise (stability)** | Documentation, FSM threshold | Require Jira refs, lower FSM threshold to 2+ states |
| **Open Source (community)** | Documentation, testing | Add `@package` tags, require unit tests for all PRs |
| **Agency (client work)** | Scope control, versioning | Strict scope discipline, detailed CHANGELOG for client review |
| **Maintenance (legacy)** | Scope control, refactoring | Zero scope creep, no refactoring without explicit approval |

**Common customization points:**

```markdown
<!-- Example: Relaxed DRY for startup -->
1. **Start with working code** — optimize for shipping, refactor later
2. **DRY when you see it 3+ times** — not prematurely

<!-- Example: Stricter docs for open source -->
- **Require @package, @author, @license** in all file headers
- **Add usage examples** to all public functions
- **Maintain CONTRIBUTORS.md** with attribution

<!-- Example: FSM threshold for complex domains -->
- **2+ states with validation rules** — use FSM
- **Any state with audit requirements** — use FSM
```

**AI Agent Note**: If user says "use our team standards" or references a custom AGENTS file, follow that instead of these defaults.

---

## 📋 Quick Reference

| Category | Functions |
|----------|-----------|
| **Sanitize** | `sanitize_text_field()`, `sanitize_email()`, `sanitize_url()`, `absint()`, `wp_unslash()` |
| **Escape** | `esc_html()`, `esc_attr()`, `esc_url()`, `esc_js()`, `wp_kses_post()` |
| **Nonces** | `wp_nonce_field()`, `wp_create_nonce()`, `check_admin_referer()`, `wp_verify_nonce()` |
| **Capabilities** | `current_user_can()`, `user_can()` |
| **Database** | `$wpdb->prepare()`, `$wpdb->get_results()`, `$wpdb->insert()` |
| **Caching** | `get_transient()`, `set_transient()`, `delete_transient()` |
| **HTTP** | `wp_remote_get()`, `wp_remote_post()`, `wp_safe_remote_get()` |
| **Options** | `get_option()`, `update_option()`, `delete_option()` |
| **Hooks** | `add_action()`, `add_filter()`, `do_action()`, `apply_filters()` |
| **AJAX** | `wp_ajax_{action}`, `wp_send_json_success()`, `wp_send_json_error()` |
| **Scheduling** | `wp_schedule_event()`, `wp_schedule_single_event()`, `wp_clear_scheduled_hook()` |

### Quick CLI Commands

```bash
# Check AI-DDTK is available
ls ~/bin/ai-ddtk/

# Scan WordPress code
wpcc --paths /path/to/plugin --format json

# Show all WPCC features
wpcc --features

# Start a resilient tmux-backed session for long-running agent work
aiddtk-tmux start --cwd /path/to/project

# Capture recent output from that session
aiddtk-tmux capture --tail 100

# Authenticate Playwright into WP admin
pw-auth login --site-url http://my-site.local

# Check Playwright auth status
pw-auth status

# View workflow recipes
ls ~/bin/ai-ddtk/recipes/
```

---

_Follow these principles to ensure safe, maintainable, WordPress-compliant code._
