# IRL (In Real Life) Examples

This directory contains **real-world code examples** from actual WordPress plugins and themes that demonstrate anti-patterns detected by the scanner.

## Purpose

1. **Validation** - Prove that patterns exist in production code
2. **Pattern Discovery** - Find new anti-patterns the scanner doesn't catch yet
3. **Documentation** - Show developers real examples of what to avoid
4. **Testing** - Verify scanner accuracy against real code

## Structure

```
irl/
├── README.md                          # This file
├── _AI_AUDIT_INSTRUCTIONS.md          # Instructions for AI agents
├── plugin-name/                       # One folder per plugin/theme
│   ├── filename-irl.php               # Real code with audit annotations
│   └── another-file-irl.php
└── another-plugin/
    └── file-irl.php
```

## Filename Convention

**Always add `-irl` suffix before the file extension:**

- ✅ `class-wcs-att-admin-irl.php` - Audited and documented
- ✅ `checkout-irl.js` - Audited and documented
- ✅ `payment-gateway-inbox.php` - Needs pattern library integration later
- ❌ `class-wcs-att-admin.php` (missing -irl suffix)
- ❌ `class-wcs-att-admin.php.md` (confusing extension)

**Suffix Meanings:**

| Suffix | Meaning | Use Case |
|--------|---------|----------|
| `-irl.php` | Audited IRL example | Fully documented, pattern library updated |
| `-inbox.php` | Inbox (needs processing) | Example saved for later pattern library integration |

**Why `-irl` suffix?**
- Still syntax-highlighted in editors
- Clear it's an IRL example (not production code)
- Can still run through linters/scanners
- Easy to find: `find . -name "*-irl.php"`

**Why `-inbox` suffix?**
- Quick capture of examples when you don't have time to audit
- Reminder to process later (add annotations, update pattern library)
- Still scannable by the tool
- Easy to find pending work: `find . -name "*-inbox.php"`

## How to Add IRL Examples

### Manual Process

1. **Find a real plugin/theme** with issues
2. **Copy the problematic file** to `dist/tests/irl/plugin-name/`
3. **Rename with `-irl` suffix**: `filename.php` → `filename-irl.php`
4. **Ask AI to audit**: "Audit the IRL file I just added"
5. **AI adds annotations** to the file (see format below)
6. **AI updates pattern library** if new patterns found

### AI-Assisted Process

Just say:
> "I found issues in WooCommerce plugin X, file Y. Can you audit it?"

AI will:
1. Ask you to copy the file to IRL folder
2. Audit the code and add inline annotations
3. Update the pattern JSON file with the example
4. Suggest scanner improvements if needed

### Quick Capture (Inbox)

Don't have time to audit right now? Use the `-inbox` suffix:

1. **Copy file** to `dist/tests/irl/plugin-name/filename-inbox.php`
2. **Process later** by saying: "Process inbox files"

AI will batch-process all `-inbox` files, add annotations, and rename to `-irl`.

### Your Own Code

You can also analyze code from **your own projects**:

1. **Copy your PHP/JS file** to `dist/tests/irl/my-project/`
2. **Use `-irl` or `-inbox` suffix** depending on urgency
3. **Ask AI to audit**: "Analyze this code I'm working on"

AI will treat it like any other IRL example and help you find issues.

## Annotation Format

IRL files should have **two types of annotations**:

### 1. File Header (Top of File)

```php
<?php
/**
 * IRL AUDIT: Plugin Name v1.2.3
 * File: path/to/original/file.php
 * Audit Date: 2026-01-01
 * Scanner Version: 1.0.67
 * 
 * ANTI-PATTERNS FOUND:
 * 1. [Line 451] unsanitized-superglobal-isset-bypass (HIGH) ✅ Detected
 * 2. [Line 523] missing-nonce-check (HIGH) ❌ NOT detected - NEW PATTERN
 * 3. [Line 678] n-plus-one-meta-query (MEDIUM) ✅ Detected
 * 
 * SUMMARY:
 * - Total anti-patterns: 3
 * - Currently detected: 2/3 (67%)
 * - New patterns needed: 1
 */
```

### 2. Inline Annotations (At Each Issue)

```php
// Line 451
// ANTI-PATTERN: unsanitized-superglobal-isset-bypass
// SEVERITY: HIGH
// DETECTED: ✅ Yes (v1.0.67)
// WHY: isset() only checks existence, doesn't sanitize
// FIX: Use sanitize_text_field( wp_unslash( $_GET['tab'] ) )
// PATTERN_ID: unsanitized-superglobal-isset-bypass
} elseif ( isset( $_GET['tab'] ) && $_GET['tab'] === 'subscriptions' ) {
    // ... vulnerable code ...
}
```

## Benefits

### For Users
- **Learn from real examples** - See actual vulnerable code
- **Understand context** - Why the pattern is dangerous
- **Copy-paste fixes** - Get working solutions

### For AI Agents
- **Pattern discovery** - Find gaps in detection
- **Test validation** - Verify scanner accuracy
- **Pattern library growth** - Auto-extract new patterns

### For Developers
- **Code review training** - Learn what to look for
- **Security awareness** - Understand common mistakes
- **Best practices** - See correct implementations

## Privacy & Attribution

**IMPORTANT:** Only include code from:
- ✅ Open-source plugins/themes (GPL-licensed)
- ✅ Publicly available code repositories
- ✅ Code you have permission to share

**Always include:**
- Plugin/theme name and version
- Original file path
- License information (if not GPL)

**Never include:**
- ❌ Proprietary/closed-source code
- ❌ Client-specific customizations
- ❌ Code under NDA

## Maintenance

- **Review quarterly** - Check if patterns are still relevant
- **Update annotations** - When scanner improves detection
- **Remove duplicates** - Keep only unique examples
- **Archive old examples** - Move to `irl/archive/` if pattern is well-covered

## See Also

- `dist/tests/fixtures/` - Synthetic test cases
- `dist/patterns/` - Pattern definitions (JSON)
- `SAFEGUARDS.md` - Critical implementation safeguards
- `../../../DISCLOSURE-POLICY.md` - Responsible disclosure and public report publication policy

