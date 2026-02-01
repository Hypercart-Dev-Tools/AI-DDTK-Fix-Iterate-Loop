# Pattern Library Manager

**Version:** 1.0.0  
**Auto-generates canonical pattern registry and marketing stats**

---

## 📋 Overview

The Pattern Library Manager is a standalone script that scans all pattern JSON files and generates:

1. **`dist/PATTERN-LIBRARY.json`** - Canonical JSON registry with full metadata
2. **`dist/PATTERN-LIBRARY.md`** - Human-readable documentation with marketing stats

This ensures that documentation stays in sync with implementation and provides automated marketing metrics.

---

## 🚀 Usage

### Automatic (Recommended)

The Pattern Library Manager runs automatically after every scan:

```bash
bash bin/check-performance.sh --project my-plugin --format json
# Pattern library registry is auto-updated at the end
```

### Manual

Run the script independently:

```bash
# Generate both JSON and Markdown
bash bin/pattern-library-manager.sh both

# Generate only JSON
bash bin/pattern-library-manager.sh json

# Generate only Markdown
bash bin/pattern-library-manager.sh markdown
```

---

## 📊 Generated Files

### `dist/PATTERN-LIBRARY.json`

Canonical JSON registry with:

- **Summary Statistics:**
  - Total patterns, enabled/disabled counts
  - Breakdown by severity (CRITICAL, HIGH, MEDIUM, LOW)
  - Breakdown by category (performance, security, duplication)
  - Mitigation detection count
  - Heuristic vs definitive pattern counts

- **Pattern Details:**
  - Full metadata for each pattern (ID, version, severity, category)
  - Mitigation detection status
  - Heuristic classification
  - Source file reference
  - Detection & mitigation fields for advanced loaders:
    - `search_pattern`
    - `file_patterns`
    - `validator_script`, `validator_args`
    - `mitigation_details` (enabled, script, args, severity_downgrade)

**Example:**
```json
{
  "version": "1.0.0",
  "generated": "2026-01-07T02:55:02Z",
  "summary": {
    "total_patterns": 15,
    "enabled": 15,
    "by_severity": {
      "CRITICAL": 6,
      "HIGH": 3,
      "MEDIUM": 4,
      "LOW": 2
    },
    "mitigation_detection_enabled": 4,
    "heuristic_patterns": 6
  },
  "patterns": [...]
}
```

### `dist/PATTERN-LIBRARY.md`

Human-readable documentation with:

- **Summary Statistics:** Tables showing pattern distribution
- **Pattern Details:** Organized by severity with badges:
  - 🛡️ = Mitigation Detection Enabled
  - 🔍 = Heuristic Pattern
- **Marketing Stats:**
  - Key selling points
  - One-liner stats for landing pages
  - Feature highlights for product descriptions

**Example Output:**
```markdown
### CRITICAL Severity Patterns
- **wp-query-unbounded** 🛡️ - Unbounded WP_Query/get_posts
- **unbounded-wc-get-orders** 🛡️ - Unbounded wc_get_orders()
- **wpdb-query-no-prepare** - Direct database queries without $wpdb->prepare()

### Marketing Stats
> **15 detection patterns** | **4 with AI mitigation** | **60-70% fewer false positives** | **15 active checks**
```

---

## 🔍 How It Works

### Pattern Detection

1. **Scans** `dist/patterns/*.json` files (excluding subdirectories)
2. **Extracts** metadata from each JSON file (ID, severity, category, etc.)
3. **Checks** main scanner script for mitigation detection integration
4. **Classifies** patterns as heuristic or definitive based on severity and description

### Mitigation Detection Check

The script searches `check-performance.sh` for:
- `get_adjusted_severity` calls with the pattern ID
- `add_json_finding` calls with `$adjusted_severity` variable

If found, the pattern is marked as having mitigation detection enabled.

### Heuristic Classification

Patterns are classified as heuristic if:
- Severity is MEDIUM or LOW, OR
- Description contains the word "heuristic"

---

## 📈 Marketing Use Cases

### Landing Page Stats

Use the one-liner from `PATTERN-LIBRARY.md`:

> **15 detection patterns** | **4 with AI mitigation** | **60-70% fewer false positives** | **15 active checks**

### Product Descriptions

Use the feature highlights:

- ✅ **6 CRITICAL** OOM and security patterns
- ✅ **3 HIGH** performance and security patterns
- ✅ **4 patterns** with context-aware severity adjustment
- ✅ **6 heuristic** patterns for code quality insights

### Technical Documentation

Use the JSON registry for:
- API documentation
- Integration guides
- Pattern coverage reports
- Compliance documentation

---

## 🛠️ Compatibility

- **Bash Version:** 3.2+ (macOS default bash compatible)
- **Dependencies:** None (uses only bash built-ins and standard Unix tools)
- **Fallback Mode:** Automatically detects bash version and uses compatible syntax

---

## 🔧 Customization

### Adding New Patterns

1. Create pattern JSON file in `dist/patterns/`
2. Run the scanner (or manually run pattern-library-manager.sh)
3. Registry is automatically updated

### Modifying Output Format

Edit `dist/bin/pattern-library-manager.sh`:

- **JSON Output:** Lines 175-210 (modify JSON structure)
- **Markdown Output:** Lines 227-422 (modify markdown sections)

---

## 📝 Output Examples

### Console Output

```
🔍 Scanning pattern library...
✓ Found 15 patterns
📝 Generating JSON registry...
✓ JSON registry saved to: dist/PATTERN-LIBRARY.json
📝 Generating Markdown documentation...
✓ Markdown documentation saved to: dist/PATTERN-LIBRARY.md

✅ Pattern Library Manager Complete

📊 Summary:
  Total Patterns: 15
  Enabled: 15
  With Mitigation Detection: 4
  Heuristic: 6
```

---

## ✅ Verification

To validate the registry JSON, run `dist/bin/check-pattern-library-json.sh` to ensure `dist/PATTERN-LIBRARY.json` is valid JSON.

---

## 🚨 Troubleshooting

### Script Fails Silently

The Pattern Library Manager is designed to fail gracefully. If it fails during a scan, the scan will still complete successfully. Check the console output for error messages.

### Bash Version Warning

If you see:
```
⚠️  Warning: Bash 4+ required for full functionality. Using fallback mode.
```

This is normal on macOS (default bash 3.2). The script will still work correctly in fallback mode.

### Missing Patterns

If patterns are missing from the registry:
1. Ensure JSON files are in `dist/patterns/` (not subdirectories)
2. Verify JSON files have required fields (`id`, `version`, `severity`, etc.)
3. Run the script manually to see detailed error messages

---

**Last Updated:** 2026-01-16  
**Version:** 1.0.0  
**Author:** Pattern Library Manager

