# wpcc Command Reference

Detailed guide to WordPress Code Check (WPCC) for security, performance, and best practices analysis.

**Last Updated:** 2026-03-22  
**Version:** 1.0.0

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Basic Usage](#basic-usage)
4. [Commands](#commands)
5. [Output Formats](#output-formats)
6. [Exit Codes](#exit-codes)
7. [Detection Rules](#detection-rules)
8. [Examples](#examples)

---

## Overview

WPCC is a fast, zero-dependency WordPress code analyzer that detects critical security issues, performance problems, and best practice violations before they reach production.

**Key Features:**
- ✅ Fast scanning (no external dependencies)
- ✅ Security checks (SQL injection, sanitization, nonces)
- ✅ Performance analysis (N+1 queries, unbounded loops)
- ✅ Best practices (coding standards, patterns)
- ✅ Baseline support (ignore known issues)
- ✅ CI/CD integration (JSON output, strict mode)
- ✅ HTML reports (visual analysis)

---

## Installation

WPCC is included with AI-DDTK. Verify installation:

```bash
wpcc --help
wpcc --features
```

---

## Basic Usage

### Syntax

```bash
wpcc [options] [paths...]
```

### Quick Examples

```bash
# Scan current directory
wpcc

# Scan specific plugin
wpcc --paths ~/wp-content/plugins/my-plugin

# Scan multiple paths
wpcc --paths "~/plugin1 ~/plugin2"

# JSON output for CI/CD
wpcc --format json

# Strict mode (fail on warnings)
wpcc --strict
```

---

## Commands

### Default: Scan Code

Analyze WordPress code for issues.

#### Syntax

```bash
wpcc [options] [paths...]
```

#### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--paths` | `.` (current dir) | Paths to scan (space-separated) |
| `--format` | `json` | Output format: `text`, `json`, or `html` |
| `--strict` | — | Fail on warnings (exit code 1) |
| `--verbose` | — | Show all matches, not just first per rule |
| `--no-log` | — | Disable logging to file |
| `--no-context` | — | Disable context lines around findings |
| `--context-lines` | `3` | Number of context lines to show |
| `--project` | — | Load config from `TEMPLATES/<name>.txt` |
| `--severity-config` | — | Custom severity levels from JSON file |
| `--generate-baseline` | — | Generate `.hcc-baseline` from findings |
| `--baseline` | `.hcc-baseline` | Custom baseline file path |
| `--ignore-baseline` | — | Ignore baseline file even if present |
| `--enable-clone-detection` | — | Enable function clone detection |
| `--help` | — | Show help message |

#### Examples

**Scan current directory:**
```bash
wpcc
```

**Scan specific plugin:**
```bash
wpcc --paths ~/wp-content/plugins/my-plugin
```

**Scan multiple paths:**
```bash
wpcc --paths "~/plugin1 ~/plugin2 ~/theme"
```

**JSON output (for CI/CD):**
```bash
wpcc --format json
```

**Text output (human-readable):**
```bash
wpcc --format text
```

**HTML report:**
```bash
wpcc --format html
```

**Strict mode (fail on warnings):**
```bash
wpcc --strict
```

**Verbose output (all matches):**
```bash
wpcc --verbose
```

**Custom context lines:**
```bash
wpcc --context-lines 5
```

**Disable logging:**
```bash
wpcc --no-log
```

**Disable context:**
```bash
wpcc --no-context
```

---

### `wpcc --features`

List all available detection rules and features.

#### Syntax

```bash
wpcc --features
```

#### Output

```
Available Detection Rules:

CRITICAL (Errors):
  • unbound-db-query — Unbound database queries (no LIMIT)
  • direct-superglobal — Direct $_GET/$_POST access
  • missing-nonce — Missing nonce verification
  • sql-injection — SQL injection vulnerabilities
  • unsafe-file-ops — Unsafe file operations

WARNING (Performance):
  • n-plus-one — N+1 query patterns
  • missing-transient — Missing transient caching
  • inefficient-query — Inefficient WP_Query usage
  • large-loop-ops — Large array operations in loops

INFO (Best Practices):
  • magic-strings — Hardcoded values
  • function-clones — Duplicate code
  • missing-error-handling — Missing error handling
```

---

### Baseline Management

#### Generate Baseline

Create a baseline file to ignore known issues in legacy code:

```bash
wpcc --paths ~/wp-content/plugins/my-plugin --generate-baseline
```

**Output:**
```
✓ Generated baseline: .hcc-baseline
  Contains 15 known issues
  Run 'wpcc' again to scan for new issues only
```

#### Use Custom Baseline

```bash
wpcc --paths ~/wp-content/plugins/my-plugin --baseline ./custom-baseline.json
```

#### Ignore Baseline

```bash
wpcc --paths ~/wp-content/plugins/my-plugin --ignore-baseline
```

---

### Severity Configuration

#### Custom Severity Levels

Create a JSON file to customize severity levels:

```json
{
  "rules": {
    "unbound-db-query": "critical",
    "n-plus-one": "warning",
    "magic-strings": "info"
  }
}
```

**Usage:**
```bash
wpcc --severity-config ./custom-severity.json
```

---

### Project Configuration

#### Load Configuration Template

```bash
wpcc --project my-plugin-name
```

Loads configuration from `TEMPLATES/my-plugin-name.txt`.

---

## Output Formats

### Text Format

Human-readable output with color coding:

```
WordPress Code Check Report
============================

CRITICAL (1 issue):
  ✗ Unbound database query
    File: plugins/my-plugin/admin.php:42
    Code: $wpdb->get_results("SELECT * FROM wp_posts")
    Fix: Add LIMIT clause

WARNING (3 issues):
  ⚠ N+1 query pattern
    File: plugins/my-plugin/admin.php:50
    Code: foreach ($posts as $post) { $wpdb->get_results(...) }
    Fix: Use WP_Query with posts_per_page

INFO (2 issues):
  ℹ Magic string
    File: plugins/my-plugin/admin.php:10
    Code: define('MY_CONSTANT', 'hardcoded_value');
```

### JSON Format

Structured output for scripting and CI/CD:

```json
{
  "summary": {
    "total_issues": 6,
    "critical": 1,
    "warning": 3,
    "info": 2,
    "files_scanned": 5
  },
  "issues": [
    {
      "severity": "critical",
      "rule": "unbound-db-query",
      "file": "plugins/my-plugin/admin.php",
      "line": 42,
      "code": "$wpdb->get_results(\"SELECT * FROM wp_posts\")",
      "message": "Unbound database query (no LIMIT clause)",
      "context": [
        "40: function get_all_posts() {",
        "41:   global $wpdb;",
        "42:   $wpdb->get_results(\"SELECT * FROM wp_posts\")",
        "43: }"
      ]
    }
  ]
}
```

### HTML Format

Visual report with interactive filtering:

```html
<!-- Generated HTML report with:
  - Summary statistics
  - Issue breakdown by severity
  - Code snippets with context
  - Filtering and search
  - Export options
-->
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success (no issues or only info-level) |
| `1` | Issues found (or `--strict` mode with warnings) |
| `2` | Configuration or runtime error |
| `127` | Command not found |

---

## Detection Rules

### CRITICAL (Errors)

| Rule | Description | Example |
|------|-------------|---------|
| `unbound-db-query` | Database query without LIMIT | `$wpdb->get_results("SELECT * FROM wp_posts")` |
| `direct-superglobal` | Direct `$_GET`/`$_POST` access | `$_GET['id']` without sanitization |
| `missing-nonce` | Form without nonce verification | `<form>` without `wp_nonce_field()` |
| `sql-injection` | SQL injection vulnerability | `$wpdb->query("WHERE id = " . $_GET['id'])` |
| `unsafe-file-ops` | Unsafe file operations | `file_get_contents($_GET['file'])` |

### WARNING (Performance)

| Rule | Description | Example |
|------|-------------|---------|
| `n-plus-one` | N+1 query pattern | Loop with DB query inside |
| `missing-transient` | Missing transient caching | Expensive operation without cache |
| `inefficient-query` | Inefficient WP_Query | Missing `posts_per_page` or `fields` |
| `large-loop-ops` | Large array operations in loop | `array_merge()` in loop |

### INFO (Best Practices)

| Rule | Description | Example |
|------|-------------|---------|
| `magic-strings` | Hardcoded values | String literals instead of constants |
| `function-clones` | Duplicate code | Same function defined twice |
| `missing-error-handling` | Missing error handling | No check for `WP_Error` |

---

## Examples

### Basic Scan

```bash
# Scan current directory
wpcc

# Output: JSON report + HTML file
# Files: wpcc-report.html, wpcc-report.json
```

### CI/CD Integration

```bash
# Scan with strict mode (fail on warnings)
wpcc --paths ./wp-content/plugins/my-plugin --format json --strict --no-log

# Exit code 0 = no issues
# Exit code 1 = issues found
```

### Legacy Code Baseline

```bash
# 1. Generate baseline for existing issues
wpcc --paths ./wp-content/plugins/legacy-plugin --generate-baseline

# 2. Scan for new issues only
wpcc --paths ./wp-content/plugins/legacy-plugin

# 3. Update baseline after fixes
wpcc --paths ./wp-content/plugins/legacy-plugin --generate-baseline
```

### Multiple Paths

```bash
# Scan plugin and theme
wpcc --paths "~/wp-content/plugins/my-plugin ~/wp-content/themes/my-theme"

# Output: Combined report
```

### Custom Severity

```bash
# Create custom severity config
cat > severity.json <<EOF
{
  "rules": {
    "unbound-db-query": "critical",
    "n-plus-one": "warning",
    "magic-strings": "info"
  }
}
EOF

# Scan with custom severity
wpcc --severity-config ./severity.json
```

### Verbose Output

```bash
# Show all matches (not just first per rule)
wpcc --verbose

# Show more context lines
wpcc --context-lines 10
```

### Disable Logging

```bash
# Scan without writing to log file
wpcc --no-log

# Scan without context lines
wpcc --no-context
```

---

## Troubleshooting

### "No issues found" but expecting issues

**Solution:**
```bash
# Check if baseline is hiding issues
wpcc --ignore-baseline

# Enable verbose mode
wpcc --verbose
```

### "Too many false positives"

**Solution:**
```bash
# Generate baseline to ignore known issues
wpcc --generate-baseline

# Use custom severity config
wpcc --severity-config ./custom-severity.json
```

### "Scan is slow"

**Solution:**
```bash
# Disable clone detection
wpcc --paths ./my-plugin

# Scan specific directory
wpcc --paths ./my-plugin/includes
```

### "HTML report not generated"

**Solution:**
```bash
# Ensure format is json (default)
wpcc --format json

# Check for write permissions
ls -la wpcc-report.html
```

---

## See Also

- [CLI-REFERENCE.md](./CLI-REFERENCE.md) — All AI-DDTK commands
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — Common errors and solutions
- [AGENTS.md](../AGENTS.md) — AI agent guidelines

