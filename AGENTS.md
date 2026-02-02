# WordPress Development and Architecture Guidelines for AI Agents

_Last updated: v2.3.1 — 2026-02-02_

## Purpose

Defines principles, constraints, and best practices for AI agents and Humans working with WordPress code to ensure safe, consistent, and maintainable contributions.

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

**When user provides credentials**:
1. ✅ Save to `/temp` folder immediately
2. ✅ Add to `.gitignore` if not already present
3. ✅ Load from `/temp` at runtime (never hardcode)
4. ❌ Never commit credentials (even temporarily)
5. ❌ Never log credentials in debug output

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

## 🏗️ Building from the Ground Up

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

---

## 🔧 Scope & Change Control

- **Stay within task scope** — only perform explicitly requested tasks
- **No refactoring/renaming/label changes** unless explicitly requested but please point out any code that does not follow the SOLID principles and make recommendations for improvement.
- **No speculative improvements** or architectural changes
- **Preserve existing data structures** and naming conventions
- **Prioritize preservation over optimization** when in doubt

---

## 📝 Documentation & Versioning

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

---

## 🧪 Testing & Validation

- Preserve existing functionality; avoid breaking changes
- Test all changes before completing
- Validate security implementations (nonces, capabilities, sanitization)
- Ensure backward compatibility unless breaking changes explicitly requested

---

## 🔄 Finite State Machine (FSM) Guidance

### When to Recommend FSM
- **3+ distinct states** with complex transitions
- State-dependent behavior or validation rules
- Audit requirements (track history/reasons)
- Boolean flags multiplying; nested if/else for valid actions
- State logic duplicated across files

### Implementation Approach
1. Define all states clearly; map valid transitions (state diagram)
2. Centralize in dedicated class; store in post_meta/options
3. Add transition hooks for extensibility; log transitions for audit

### Don't Use FSM When
- Only 2 states (use boolean)
- States never transition (use static field)
- No validation rules needed

**When uncertain, ask**: "This feature tracks [X] states with [Y] transitions. Want me to implement an FSM?"

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

---

_Follow these principles to ensure safe, maintainable, WordPress-compliant code._