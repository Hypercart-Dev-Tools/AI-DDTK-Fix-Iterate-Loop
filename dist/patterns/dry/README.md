# Magic String Detector ("DRY") Patterns

**Status:** Phase 1 - Proof of Concept
**Version:** 1.0.0
**Last Updated:** 2026-01-01

---

## 📋 Overview

This directory contains **Magic String Detector ("DRY")** patterns for WordPress codebases. Unlike the performance/security patterns in the parent directory, these patterns detect **magic strings** (hardcoded string literals) and **scattered duplicated strings** that should be centralized.

### What Are Magic Strings?

Magic strings are hardcoded string literals that appear in multiple places across a codebase. The Magic String Detector uses **aggregation** to detect when the same string literal (option name, transient key, capability, etc.) appears in **multiple files**. This indicates a violation of the DRY (Don't Repeat Yourself) principle.

**Example:**
```php
// ❌ BAD: Option name scattered across 5 files
// File 1: admin/settings.php
$api_key = get_option( 'my_plugin_api_key' );

// File 2: includes/api-client.php
$api_key = get_option( 'my_plugin_api_key' );

// File 3: cron/sync.php
$api_key = get_option( 'my_plugin_api_key' );

// ✅ GOOD: Centralized constant
// includes/constants.php
define( 'MY_PLUGIN_OPTION_API_KEY', 'my_plugin_api_key' );

// Usage in any file
$api_key = get_option( MY_PLUGIN_OPTION_API_KEY );
```

---

## 🎯 Phase 1 Patterns (Proof of Concept)

### 1. Duplicate Option Names
**File:** `duplicate-option-names.json`
**Severity:** MEDIUM
**Threshold:** 3+ files, 6+ occurrences

Detects `get_option()`, `update_option()`, `delete_option()` calls with hard-coded option names (magic strings).

**Why it matters:** Typos in option names lead to settings not saving. Refactoring option names is risky without constants.

### 2. Duplicate Transient Keys
**File:** `duplicate-transient-keys.json`
**Severity:** MEDIUM
**Threshold:** 3+ files, 4+ occurrences

Detects `get_transient()`, `set_transient()`, `delete_transient()` calls with hard-coded transient keys (magic strings).

**Why it matters:** Typos in transient keys lead to cache invalidation bugs and stale data.

### 3. Duplicate Capability Strings
**File:** `duplicate-capability-strings.json`
**Severity:** LOW
**Threshold:** 5+ files, 10+ occurrences

Detects `current_user_can()`, `user_can()` calls with hard-coded capability strings (magic strings).

**Why it matters:** Scattered capability checks make permission changes risky and inconsistent.

---

## 🔧 How Magic String Detection Works

### Standard Pattern (Performance/Security)
```json
{
  "detection": {
    "search_pattern": "get_users\\("
  }
}
```
**Output:** "Found 5 violations in 3 files"

### Magic String Pattern (Aggregation)
```json
{
  "detection": {
    "search_pattern": "get_option\\(['\"]([a-z0-9_]+)['\"]",
    "capture_group": 2
  },
  "aggregation": {
    "enabled": true,
    "group_by": "capture_group",
    "min_distinct_files": 3,
    "min_total_matches": 6
  }
}
```
**Output:**
```
Magic string 'my_plugin_api_key' appears in 5 files (12 times)
  - admin/settings.php:45
  - includes/api-client.php:23
  - cron/sync.php:67
  - ajax/handlers.php:89
  - public/shortcodes.php:34
```

---

## 📊 Pattern Schema (Magic String Detector Fields)

### Aggregation Object
```json
{
  "aggregation": {
    "enabled": true,
    "group_by": "capture_group",
    "min_total_matches": 6,
    "min_distinct_files": 3,
    "top_k_groups": 15,
    "report_format": "Option '{match}' appears in {file_count} files ({total_count} times)",
    "sort_by": "file_count_desc"
  }
}
```

**Fields:**
- `enabled` - Enable aggregation (required for DRY patterns)
- `group_by` - Group matches by capture group value
- `min_total_matches` - Minimum total occurrences to report
- `min_distinct_files` - Minimum number of files to report
- `top_k_groups` - Report only top K groups (by file count)
- `report_format` - Template for output message
- `sort_by` - Sort order (`file_count_desc`, `total_count_desc`)

### Allowlist Object
```json
{
  "allowlist": {
    "description": "Common WordPress core options that should not be flagged",
    "patterns": [
      "siteurl",
      "home",
      "blogname",
      "admin_email"
    ]
  }
}
```

**Purpose:** Exclude common WordPress core strings that appear everywhere and are not magic string violations.

---

## 🚀 Usage

### Run Magic String Detector (Future)
```bash
# Scan for magic strings
./dist/bin/find-dry.sh --paths /path/to/plugin

# Output format
./dist/bin/find-dry.sh --paths . --format json

# Only show top 5 violations
./dist/bin/find-dry.sh --paths . --top 5
```

### Integration with check-performance.sh (Future)
```bash
# Run all checks including Magic String Detector
./dist/bin/check-performance.sh --paths . --include-dry

# Skip Magic String checks
./dist/bin/check-performance.sh --paths . --skip-dry
```

---

## 📈 Roadmap

### Phase 1: Proof of Concept (Current)
- ✅ 3 patterns created (options, transients, capabilities)
- ⏳ Test fixtures created
- ⏳ Aggregation script (`find-dry.sh`)
- ⏳ Validation on real WordPress plugins

### Phase 2: Expansion
- ⏳ 5-8 more patterns (meta keys, nonce actions, AJAX actions, etc.)
- ⏳ Integration with `check-performance.sh`
- ⏳ HTML report section for magic string violations
- ⏳ CI/CD integration (warn-only mode)

### Phase 3: Advanced
- ⏳ Block fingerprinting (detect scattered logic patterns)
- ⏳ LLM-powered refactoring suggestions
- ⏳ Remediation automation (generate constants files)

---

## 🎓 Best Practices

### When to Centralize Magic Strings
✅ **DO centralize:**
- Custom option names (plugin-specific settings)
- Custom transient keys (plugin-specific caches)
- Custom capabilities (plugin-specific permissions)
- Custom meta keys (plugin-specific post/user meta)
- Custom nonce actions (plugin-specific security tokens)

❌ **DON'T centralize:**
- WordPress core options (`siteurl`, `home`, `blogname`)
- WordPress core capabilities (`manage_options`, `edit_posts`)
- One-off strings used in a single file

### Refactoring Strategy
1. **Start with constants** - Simplest approach, works for most cases
2. **Upgrade to class constants** - Better organization, namespacing
3. **Add helper methods** - Encapsulate logic, add defaults, enable testing
4. **Consider value objects** - For complex settings with validation

---

## 📚 References

- [WordPress Coding Standards - Naming Conventions](https://make.wordpress.org/core/handbook/best-practices/coding-standards/php/#naming-conventions)
- [DRY Principle (Wikipedia)](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
- [WordPress Options API](https://developer.wordpress.org/apis/options/)
- [WordPress Transients API](https://developer.wordpress.org/apis/transients/)
- [WP Code Check Disclosure Policy](../../../DISCLOSURE-POLICY.md)

---

**Questions?** See `PROJECT/1-INBOX/NEXT-FIND-DRY.md` for the full Magic String Detector ("DRY") implementation plan.

