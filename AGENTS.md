# WordPress Development and Architecture Guidelines for AI Agents

_Last updated: v2.1.0 — 2026-01-28_

## Purpose

Defines principles, constraints, and best practices for AI agents and Humans  working with WordPress code to ensure safe, consistent, and maintainable contributions.

## Roadmap

- [ ] Add orchesration pointer here

---

## 🔐 Security

- **Sanitize inputs**: `sanitize_text_field()`, `sanitize_email()`, `absint()`, etc.
- **Escape outputs**: `esc_html()`, `esc_attr()`, `esc_url()`, `wp_kses_post()`
- **Verify nonces** for all forms and AJAX; **check capabilities** with `current_user_can()`
- **Use `$wpdb->prepare()`** for all database queries
- **Never expose sensitive data** in logs, comments, or commits
- **Use WordPress native APIs** over custom security logic

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
- Follow [WordPress Coding Standards](https://developer.wordpress.org/coding-standards/) and DRY principles
- Respect plugin/theme hierarchy; treat as self-contained unless cross-dependencies requested

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

When creating new features (either at start of project or in the middle of a project):
1. **Start with DRY helpers** — reusable utilities before feature code
2. **Design single contract writers** — identify state ownership upfront
3. **Separate concerns** — data access, business logic, presentation layers
4. **Add observability from start** — logging for key operations
5. **Implement defensive error handling** — validate, check errors, provide fallbacks
6. **Plan for extensibility** — add hooks/filters for customization
7. **Document as you build** — PHPDoc comments immediately
8. **Consider FSM early** — if 3+ states, design state machine from start

---

## 🔧 Scope & Change Control

- **Stay within task scope** — only perform explicitly requested tasks
- **No refactoring/renaming/label changes** unless explicitly requested
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