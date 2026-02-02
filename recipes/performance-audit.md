# Performance Audit Recipe

**WPCC → WP Performance Timer Pipeline**

> **Note**: WP Performance Timer will be renamed to **Hypercart WP Performance Timer** in a future release.

This recipe combines static analysis (WPCC) with runtime profiling (WP Performance Timer) to identify and confirm performance bottlenecks.

---

## When to Use

- Pre-deploy performance audit
- Investigating slow page loads
- Confirming WPCC performance warnings
- Before/after optimization comparison

---

## Prerequisites

1. **WPCC** available via `wpcc` command (part of AI-DDTK)
2. **WP Performance Timer** plugin installed and activated in WordPress
3. Access to WordPress debug.log or NeoLog session data

---

## Workflow

### Phase 1: Static Analysis (WPCC)

Scan the target code for potential performance issues:

```bash
wpcc --paths /path/to/plugin --format json
```

**What to look for:**
- `n-plus-1-pattern` - Queries inside loops
- `unbounded-query` - Missing LIMIT clauses
- `expensive-operation` - Heavy computations

**Output**: JSON file in `tools/wp-code-check/dist/logs/[TIMESTAMP].json`

### Phase 2: AI Triage

Review findings and prioritize:

```
Ask AI: "Triage this scan"
```

Focus on:
- High-severity performance warnings
- Code that runs on every page load
- Database queries in loops

### Phase 3: Runtime Profiling

For each confirmed issue, add performance timers:

```php
// Before the suspected slow code
if (function_exists('perf_timer_start')) {
    $timer = perf_timer_start('suspect-operation', [
        'file' => __FILE__,
        'line' => __LINE__,
        'wpcc_finding' => 'n-plus-1-pattern'
    ]);
}

// The code WPCC flagged
foreach ($items as $item) {
    $result = get_post_meta($item->ID, 'some_meta', true);
}

// After the suspected slow code
if (isset($timer) && function_exists('perf_timer_stop')) {
    perf_timer_stop($timer);
}
```

### Phase 4: Trigger and Measure

1. **Enable verbose logging** (optional):
   ```php
   // In wp-config.php
   define('PERF_LOG_ALL', true);
   ```

2. **Trigger the operation**:
   - Load the page
   - Trigger the AJAX call
   - Run the cron job

3. **Collect metrics** from:
   - `wp-content/debug.log`
   - NeoLog session files
   - Admin → Tools → Performance Logs

### Phase 5: Report

Document findings in this format:

```markdown
## Performance Audit Report

### Summary
| Metric | Value |
|--------|-------|
| Target | checkout-page |
| Date | 2026-02-02 |
| WPCC Findings | 3 potential issues |
| Confirmed Bottlenecks | 1 |

### Confirmed Issues

#### Issue 1: Loop at line 234
- **WPCC Finding**: n-plus-1-pattern
- **Runtime Impact**: 1,847ms, 156 queries
- **Recommendation**: Batch query with single get_posts() call

### False Positives

#### WPCC Finding: unbounded-query (line 89)
- **Runtime Measurement**: 12ms, 1 query
- **Reason**: Result set is naturally small (max 5 items)
- **Action**: No change needed
```

---

## Quick Commands

```bash
# Phase 1: Scan
wpcc --paths <path> --format json

# Check if Performance Timer is enabled
wp eval "var_dump(defined('PERF_TIMING_ENABLED') && PERF_TIMING_ENABLED);"

# View recent performance logs
tail -100 /path/to/wordpress/wp-content/debug.log | grep PERF
```

---

## Tips

1. **Profile the hot path first** - Focus on code that runs on every request
2. **Use hierarchy** - Wrap large operations, then add child timers for sub-operations
3. **Compare before/after** - Always measure before optimizing, then measure again
4. **Watch query counts** - High query counts in loops are the #1 WordPress performance killer
5. **Check memory too** - Memory leaks cause issues on long-running operations

---

## Related

- [WPCC Features](../bin/wpcc) - Run `wpcc --features` for all options
- [AGENTS.md](../AGENTS.md) - Performance Profiling section
- [WP Performance Timer](https://github.com/yourusername/wp-performance-timer) - Plugin documentation

---

## AI Agent Instructions

When user asks for a performance audit:

1. Run WPCC scan on the target path
2. Triage findings for performance-related issues
3. Guide user to add timers around flagged code
4. Help interpret the runtime metrics
5. Provide optimization recommendations based on confirmed bottlenecks

