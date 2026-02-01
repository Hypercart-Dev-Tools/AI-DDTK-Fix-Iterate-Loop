# WP Code Check - Calibration Plan
**Created:** 2026-01-02
**Status:** In Progress
**Priority:** HIGH
**Estimated Effort:** 2-3 weeks

---

## 📋 Table of Contents - Priority Checklist

### Phase 1: Quick Wins (Week 1-2)
- [x] **Priority 1:** Superglobal Access - Context-Aware Nonce Detection (36 FP → 0 FP) ✅ COMPLETED
- [x] **Priority 2:** Nonce Verification Pattern (9 FP → 0 FP) ✅ COMPLETED (auto-resolved)
- [x] **Priority 3:** Capability Check in Callbacks (15 FP → 3 FP) ✅ COMPLETED
- [x] **Priority 3.5:** Increase Fixture Coverage (4 → 8 fixtures) ✅ COMPLETED
- [ ] **Priority 4:** N+1 Context Detection (4 FP)
- [ ] **Priority 5:** Admin Notice Capability Checks (2 real issues - keep detection)

### Phase 2: Advanced Context (Week 3-4)
- [ ] Testing and refinement
- [ ] Documentation and examples

### Phase 3: AST Integration (Future - Month 2-3)
- [ ] Research PHP AST parsers
- [ ] Implement AST-based cross-file analysis
- [ ] Hybrid mode (regex for speed, AST for accuracy)

**Progress:** 4/6 priorities completed (67%) | **FP Reduction:** 57 false positives eliminated

---

## Executive Summary

Based on real-world testing with the PTT-MKII plugin (30 files, 8,736 LOC), our tool is **too strict and lacks context awareness**, resulting in ~60 false positives out of 69 total findings.

**Actual Issues:** 4-5 legitimate problems  
**False Positives:** ~60 findings (~87% false positive rate)

This calibration plan addresses the need for **context-aware pattern detection** to reduce false positives while maintaining security rigor.

---

## Problem Analysis

### Current Detection Method: Regex-Based Pattern Matching

**Strengths:**
- ✅ Fast and lightweight
- ✅ No dependencies
- ✅ Works on any codebase instantly
- ✅ Easy to understand and maintain

**Limitations:**
- ❌ No understanding of code flow
- ❌ Cannot detect nonce checks before `$_POST` access
- ❌ Cannot distinguish metabox (single post) from list table (loop)
- ❌ Cannot follow function calls to find capability checks in callbacks
- ❌ Cannot understand sanitization context

---

## AST Parser: Do We Need It?

### Short Answer: **Not Yet, But Eventually Yes**

### Current Approach (Regex + Context Window)
**Capabilities:**
- ✅ Look ahead/behind N lines for patterns
- ✅ Detect sanitization wrappers on same line
- ✅ Count pattern occurrences in proximity
- ✅ File-level heuristics (filename patterns)

**Limitations:**
- ❌ Cannot follow function definitions across files
- ❌ Cannot understand variable scope
- ❌ Cannot trace data flow through multiple statements

### AST Parser Approach
**Capabilities:**
- ✅ Full code structure understanding
- ✅ Cross-file function call tracing
- ✅ Variable scope and data flow analysis
- ✅ Precise loop detection (not just `foreach` keyword)

**Drawbacks:**
- ❌ Requires PHP parser (nikic/php-parser or similar)
- ❌ Slower performance (must parse all files)
- ❌ More complex to maintain
- ❌ Dependency on external library

### Recommendation: **Hybrid Approach**

**Phase 1 (Now - 2 weeks):** Improve regex with better context awareness  
**Phase 2 (Future - 4-6 weeks):** Add optional AST mode for deep analysis

---

## Calibration Tasks

### Priority 1: Superglobal Access (HIGH Impact - 36 False Positives)

**Current Issue:**
```php
check_ajax_referer( 'ptt_timer_nonce', 'nonce' );  // Line 54
$task_id = isset( $_POST['task_id'] ) ? absint( $_POST['task_id'] ) : 0;  // Line 56 - FLAGGED
```

**Solution: Context-Aware Nonce Detection**

**Implementation:**
1. When `$_POST` is detected, scan **previous 10 lines** for:
   - `check_ajax_referer()`
   - `wp_verify_nonce()` with `$_POST` or `$_REQUEST`
   - `check_admin_referer()`

2. If nonce check found AND `$_POST` is wrapped in sanitization → **SAFE**

3. ~~Create new severity level: `INFO` for "technically correct but could use wp_unslash()"~~ (Not needed - skipping safe patterns entirely)

**Files Modified:**
- ✅ `dist/bin/check-performance.sh` (lines 1794-1828)
- ✅ Created pattern: `dist/patterns/superglobal-with-nonce-context.json`

**Results:**
- **Before:** 36 false positives
- **After:** 0 false positives ✓
- **Impact:** 100% reduction in false positives for properly secured WordPress code

**Changes Made:**
1. Added context-aware detection that scans 10 lines before `$_POST` access
2. Detects nonce verification functions: `check_ajax_referer()`, `wp_verify_nonce()`, `check_admin_referer()`
3. Skips findings when nonce + sanitization pattern detected
4. Special case: `$_POST` used inside nonce verification function is automatically safe
5. Added `floatval()` to list of recognized sanitization functions

**Estimated Effort:** 3-4 days
**Actual Effort:** 2 hours

STATUS: ✅ COMPLETED (2026-01-02)

---

### Priority 2: Nonce Verification Pattern (MEDIUM Impact - 9 False Positives)

**Current Issue:**
```php
if ( ! isset( $_POST['nonce'] ) || ! wp_verify_nonce( $_POST['nonce'], 'action' ) ) {
    // FLAGGED as "unsanitized"
}
```

**Solution: Recognize Nonce Verification Exception**

**Implementation:**
1. Detect pattern: `$_POST` inside `wp_verify_nonce()` or `check_ajax_referer()`
2. Mark as **SAFE** (this is WordPress core pattern)
3. ~~Optional: Add INFO-level suggestion to use `wp_unslash()` for best practice~~ (Not needed)

**Files Modified:**
- ✅ `dist/bin/check-performance.sh` (lines 1797-1803)

**Results:**
- **Before:** 9 false positives
- **After:** 0 false positives ✓
- **Impact:** Handled as part of Priority 1 implementation

**Note:** This was automatically resolved by the Priority 1 implementation. The special case detection for `$_POST` used inside nonce verification functions covers this scenario.

**Estimated Effort:** 1-2 days
**Actual Effort:** Included in Priority 1

STATUS: ✅ COMPLETED (2026-01-02)

---

### Priority 3: Capability Check in Callbacks (HIGH Impact - 15 False Positives)

**Current Issue:**
```php
add_action( 'admin_menu', 'my_admin_menu_callback' );  // Line 50 - FLAGGED

function my_admin_menu_callback() {  // Line 100
    if ( ! current_user_can( 'manage_options' ) ) {  // Capability check HERE
        return;
    }
    // ... admin menu code
}
```

**Solution: Function Definition Lookup**

**Implementation: Same-File Function Lookup (Regex - 80% coverage)**
1. When `add_action('admin_*', 'callback')` is found
2. Extract callback function name from multiple patterns:
   - String callbacks: `add_action('hook', 'callback')`
   - Array callbacks: `add_action('hook', [$this, 'callback'])`
   - Class callbacks: `add_action('hook', [__CLASS__, 'callback'])`
3. Search same file for function definition (handles static methods)
4. Scan function body (next 50 lines) for capability checks:
   - Direct checks: `current_user_can()`, `user_can()`, `is_super_admin()`
   - WordPress menu functions with capability parameter
5. If found → **SAFE**

**Files Modified:**
- ✅ `dist/bin/check-performance.sh` (lines 1048-1099, 2041-2072)
- ✅ Created helper function: `find_callback_capability_check()`

**Results:**
- **Before:** 15 false positives
- **After:** 3 findings (12 false positives eliminated - 80% reduction)
- **Impact:** Dramatically reduced false positives for properly secured admin callbacks
- **Remaining:** 3 findings appear to be legitimate issues (admin enqueue scripts without capability checks)

**Changes Made:**
1. Created `find_callback_capability_check()` helper function
2. Handles multiple callback patterns (string, array, class array)
3. Supports static method definitions (`public static function`)
4. Recognizes WordPress menu functions with capability parameters
5. Enhanced immediate context check to detect menu functions with capabilities

**Estimated Effort:** 4-5 days (Option A) or 2-3 weeks (Option B with AST)
**Actual Effort:** 3 hours

STATUS: ✅ COMPLETED (2026-01-02)

---

### Priority 3.5: Increase Fixture Coverage (LOW Impact - Better Validation)

**Current Issue:**
- Only 4 fixtures validated by default
- 8 total fixtures available but not all used
- Limited coverage of edge cases (AJAX, REST, security patterns)

**Solution: Increase Default Fixture Count**

**Implementation:**
1. **Increase default from 4 to 8 fixtures** in `run_fixture_validation()`
2. **Add template configuration** option: `FIXTURE_COUNT=8`
3. **Add environment variable** support: `FIXTURE_VALIDATION_COUNT=8`

**Benefits:**
- ✅ Better validation by default
- ✅ More comprehensive coverage (AJAX, REST, HTTP, timezone)
- ✅ Flexibility when needed (can override per project)
- ✅ Minimal performance impact (~40-80ms total)

**Files Modified:**
- ✅ `dist/bin/check-performance.sh` (lines 64, 1016-1060)
- ✅ `dist/TEMPLATES/_TEMPLATE.txt` (lines 76-78)
- ✅ `CHANGELOG.md` (version 1.0.76)

**Results:**
- **Before:** 4 fixtures validated by default
- **After:** 8 fixtures validated by default
- **Coverage Increase:** 100% (4 → 8 fixtures)
- **New Coverage:** AJAX, REST, admin capabilities, direct database access
- **Performance Impact:** ~40-80ms (negligible)
- **Configuration:** Template option + environment variable support

**Fixtures Added:**
5. `ajax-antipatterns.php` - REST routes without pagination
6. `ajax-antipatterns.php` - AJAX handlers without nonce
7. `admin-no-capability.php` - Admin menus without capability checks
8. `wpdb-no-prepare.php` - Direct database queries without prepare()

**Estimated Effort:** 2-3 hours
**Actual Effort:** ~2 hours

STATUS: ✅ COMPLETED (2026-01-02)

---

### Priority 4: N+1 Context Detection (MEDIUM Impact - 4 False Positives)

**Current Issue:**
```php
// File: class-ptt-client-metabox.php
public function save_metabox( $post_id ) {  // Single post context
    $value = get_post_meta( $post_id, '_key', true );  // FLAGGED as N+1
}
```

**Solution: File-Based Heuristics + Loop Detection**

**Implementation:**
1. **Filename Heuristics:**
   - Files matching `*metabox*.php` → Likely single-post context
   - Files matching `*list-table*.php` → Likely loop context
   - Files matching `*columns*.php` → Likely loop context

2. **Function Context Detection:**
   - If `get_post_meta()` is inside `save_*()` or `render_*()` function → Single post
   - If inside `foreach` or `while` → Loop context

3. **Severity Adjustment:**
   - Metabox context: Downgrade to `INFO` or skip
   - List table context: Keep as `CRITICAL`

**Files to Modify:**
- `dist/bin/check-performance.sh` (lines 2824-2864)
- Create pattern: `dist/patterns/n-plus-1-context-aware.json`

**Estimated Effort:** 3-4 days

---

### Priority 5: Admin Notice Capability Checks (LOW Impact - 2 Real Issues)

**Current Issue:**
```php
add_action( 'admin_notices', 'my_notice' );  // FLAGGED

function my_notice() {
    // No capability check - anyone can see this notice
    echo '<div class="notice">...</div>';
}
```

**Solution: This is a LEGITIMATE issue - Keep detection**

**Enhancement:**
- Add documentation explaining why this matters
- Suggest fix: Add `if ( ! current_user_can( 'manage_options' ) ) return;`

**Files to Modify:**
- `dist/patterns/admin-notices-no-cap.json` (create with explanation)

**Estimated Effort:** 1 day

---

## Implementation Roadmap

### Phase 1: Quick Wins (Week 1-2) - 57 FP Eliminated ✅
- [x] ✅ **Priority 1:** Context-aware nonce detection (36 FP eliminated)
- [x] ✅ **Priority 2:** Nonce verification exception (9 FP eliminated - auto-resolved)
- [x] ✅ **Priority 3:** Capability check in callbacks (12 FP eliminated)
- [x] ✅ **Priority 3.5:** Increase fixture count (4 → 8 fixtures - better validation)
- [ ] **Priority 4:** N+1 file heuristics (4 FP)
- [ ] **Priority 5:** Admin notice documentation (2 real issues)

**Expected Reduction:** ~50 false positives (87% → 30% FP rate)
**Actual Progress:** 57/50 FP eliminated (114% of Phase 1 goal - EXCEEDED!)
**Fixture Coverage:** 8 fixtures (100% increase from 4)

### Phase 2: Advanced Context (Week 3-4)
- [ ] Testing and refinement against real-world plugins
- [ ] Documentation and examples
- [ ] Performance benchmarking

**Expected Reduction:** ~15 more false positives (30% → 7% FP rate)

### Phase 3: AST Integration (Future - Month 2-3)
- [ ] Research PHP AST parsers (nikic/php-parser)
- [ ] Implement AST-based cross-file analysis
- [ ] Hybrid mode (regex for speed, AST for accuracy)
- [ ] Performance optimization and caching

**Expected Reduction:** Near-zero false positives (<5% FP rate)

---

## Technical Approach: Context-Aware Detection

### Current Architecture
```
┌─────────────────┐
│  Scan Files     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Regex Match    │  ← Single-line pattern matching
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Report Finding │
└─────────────────┘
```

### Enhanced Architecture (Phase 1-2)
```
┌─────────────────┐
│  Scan Files     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Regex Match    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│  Context Analysis           │
│  - Look back N lines        │
│  - Check function scope     │
│  - File naming heuristics   │
│  - Sanitization wrappers    │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────┐
│  Severity       │  ← Adjust based on context
│  Adjustment     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Report Finding │
└─────────────────┘
```

### Future Architecture (Phase 3 - AST)
```
┌─────────────────┐
│  Parse PHP      │  ← Build AST
│  Files          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Build Symbol   │  ← Function registry
│  Table          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Data Flow      │  ← Trace variables
│  Analysis       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Report Finding │
└─────────────────┘
```

---

## Code Examples

### Example 1: Context-Aware Nonce Detection

**Before (Current):**
```bash
# Simple regex - flags everything
grep -E '\$_(GET|POST|REQUEST)\[' file.php
```

**After (Phase 1):**
```bash
# Context-aware detection
detect_superglobal_with_context() {
  local file="$1"
  local line_num="$2"

  # Get 10 lines before the match
  local context=$(sed -n "$((line_num - 10)),$((line_num))p" "$file")

  # Check for nonce verification
  if echo "$context" | grep -qE "check_ajax_referer|wp_verify_nonce|check_admin_referer"; then
    # Check if sanitized
    local current_line=$(sed -n "${line_num}p" "$file")
    if echo "$current_line" | grep -qE "sanitize_|esc_|absint|intval"; then
      return 0  # SAFE
    fi
  fi

  return 1  # UNSAFE
}
```

### Example 2: Callback Function Lookup

**Implementation:**
```bash
# Find callback function in same file
find_callback_capability_check() {
  local file="$1"
  local callback_name="$2"

  # Find function definition
  local func_line=$(grep -n "function[[:space:]]\+${callback_name}[[:space:]]*(" "$file" | cut -d: -f1)

  if [ -n "$func_line" ]; then
    # Check next 50 lines for capability check
    local func_body=$(sed -n "${func_line},$((func_line + 50))p" "$file")
    if echo "$func_body" | grep -qE "current_user_can|user_can"; then
      return 0  # Has capability check
    fi
  fi

  return 1  # No capability check found
}
```

---

## Success Metrics

### Before Calibration (Current State)
- **Total Findings:** 69
- **False Positives:** ~60 (87%)
- **True Positives:** ~9 (13%)
- **Developer Trust:** Low (too many false alarms)

### After Phase 1 (Target)
- **Total Findings:** ~20
- **False Positives:** ~6 (30%)
- **True Positives:** ~14 (70%)
- **Developer Trust:** Medium

### After Phase 2 (Target)
- **Total Findings:** ~10
- **False Positives:** ~1 (10%)
- **True Positives:** ~9 (90%)
- **Developer Trust:** High

### After Phase 3 - AST (Target)
- **Total Findings:** ~5-7
- **False Positives:** 0-1 (<5%)
- **True Positives:** ~5-6 (95%+)
- **Developer Trust:** Very High

---

## Risk Assessment

### Low Risk Changes
- ✅ Nonce verification exception (well-defined pattern)
- ✅ File naming heuristics (conservative approach)
- ✅ Documentation improvements

### Medium Risk Changes
- ⚠️ Context-aware nonce detection (could miss edge cases)
- ⚠️ Same-file callback lookup (limited to single file)

### High Risk Changes
- 🔴 AST integration (major architectural change)
- 🔴 Cross-file analysis (performance impact)

**Mitigation Strategy:**
1. Maintain baseline mode for all changes
2. Test against 10+ real-world plugins before release
3. Add `--strict-mode` flag to disable context awareness
4. Comprehensive test fixtures for each pattern

---

## Testing Strategy

### Test Fixtures Needed

**1. Superglobal with Nonce (Should PASS)**
```php
check_ajax_referer( 'my_nonce', 'nonce' );
$value = isset( $_POST['key'] ) ? sanitize_text_field( $_POST['key'] ) : '';
```

**2. Superglobal without Nonce (Should FAIL)**
```php
$value = isset( $_POST['key'] ) ? sanitize_text_field( $_POST['key'] ) : '';
```

**3. Callback with Capability Check (Should PASS)**
```php
add_action( 'admin_menu', 'my_callback' );
function my_callback() {
    if ( ! current_user_can( 'manage_options' ) ) return;
    // ...
}
```

**4. Metabox Meta Access (Should PASS)**
```php
// File: class-client-metabox.php
public function save( $post_id ) {
    $value = get_post_meta( $post_id, '_key', true );
}
```

**5. List Table N+1 (Should FAIL)**
```php
// File: class-list-table-columns.php
foreach ( $posts as $post ) {
    $meta = get_post_meta( $post->ID, '_key', true );  // N+1!
}
```

---

## Questions for Decision

### 1. AST Parser Timeline
**Question:** Should we invest in AST now or wait until Phase 1-2 results?

**Recommendation:** Wait. Regex improvements will get us to 90% accuracy. AST is a 3-month project for the last 10%.

### 2. Performance vs Accuracy Trade-off
**Question:** Is it acceptable to scan 10 lines of context (slower) for better accuracy?

**Recommendation:** Yes. Context window of 10-20 lines is negligible performance impact.

### 3. Backward Compatibility
**Question:** Should we maintain old behavior with a flag?

**Recommendation:** Yes. Add `--legacy-mode` flag to disable context awareness.

### 4. Severity Levels
**Question:** Should we add `INFO` severity for "technically correct but could be better"?

**Recommendation:** Yes. Four levels: `CRITICAL`, `HIGH`, `MEDIUM`, `INFO`

---

## Next Steps

1. **Review this plan** with team/stakeholders
2. **Prioritize** which phases to implement
3. **Create test fixtures** for each pattern
4. **Implement Phase 1** (Quick Wins)
5. **Measure results** against PTT-MKII plugin
6. **Iterate** based on real-world feedback

---

## References

- **Test Results:** `temp/test-results-feedback.md`
- **PTT-MKII Scan:** `/tmp/ptt-mkii-scan.json`
- **Current Patterns:** `dist/bin/check-performance.sh` (lines 1714-2990)
- **WordPress Coding Standards:** https://developer.wordpress.org/coding-standards/

---

**Document Version:** 1.0
**Last Updated:** 2026-01-02
**Author:** AI Analysis based on PTT-MKII real-world testing

