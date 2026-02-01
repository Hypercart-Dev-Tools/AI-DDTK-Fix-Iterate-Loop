# WP Code Check - Executables and Tools

This directory contains all executable scripts and supporting files for WP Code Check.

---

## 📁 Directory Structure

```
dist/bin/
├── Main Tools (Executables)
│   ├── check-performance.sh          # Core scanner (30+ WordPress checks)
│   ├── run                            # Template runner (simplified workflow)
│   ├── create-github-issue.sh         # GitHub issue creator
│   ├── json-to-html.py                # Standalone JSON to HTML converter
│   └── json-to-html.sh                # Legacy HTML converter (deprecated)
│
├── AI Integration
│   ├── ai-triage.py                   # AI-assisted triage tool
│   └── mcp-server.js                  # Model Context Protocol server
│
├── Pattern Management
│   ├── pattern-library-manager.sh     # Pattern library manager
│   └── PATTERN-LIBRARY-MANAGER-README.md
│
├── Experimental Tools 🧪
│   └── experimental/
│       ├── README.md
│       └── golden-rules-analyzer.php  # Semantic analysis (beta)
│
├── Supporting Files
│   ├── lib/                           # Shared helper functions
│   │   ├── colors.sh                  # Terminal color utilities
│   │   ├── common-helpers.sh          # Common bash functions
│   │   ├── false-positive-filters.sh  # False positive detection
│   │   └── json-helpers.sh            # JSON processing utilities
│   │
│   ├── templates/                     # HTML report templates
│   │   └── report-template.html       # Main report template
│   │
│   └── fixtures/                      # Test fixtures
│       └── wp-json-html-escape.php    # Test data
│
└── Utility Scripts
    ├── detect-wc-coupon-in-thankyou.sh
    ├── detect-wc-smart-coupons-perf.sh
    ├── find-dry.sh
    ├── format-slack-message.sh
    ├── post-to-slack.sh
    ├── pre-commit-credential-check.sh
    ├── test-slack-integration.sh
    └── wc-coupon-thankyou-snippet.sh
```

---

## 🎯 Main Tools

### check-performance.sh
**The core scanner** - Detects 30+ WordPress performance antipatterns.

```bash
./dist/bin/check-performance.sh --paths /path/to/plugin
./dist/bin/check-performance.sh --paths . --format json
./dist/bin/check-performance.sh --paths . --generate-baseline
```

See [dist/README.md](../README.md) for complete usage.

### run
**Template runner** - Simplified workflow for frequently-scanned projects.

```bash
./dist/bin/run my-plugin
./dist/bin/run my-plugin --format json
```

See [dist/HOWTO-TEMPLATES.md](../HOWTO-TEMPLATES.md) for template creation.

### create-github-issue.sh
**GitHub issue creator** - Converts scan results into GitHub issues.

```bash
./dist/bin/create-github-issue.sh --scan-id 2026-01-13-031719-UTC --repo owner/repo
./dist/bin/create-github-issue.sh --scan-id 2026-01-13-031719-UTC  # Saves to dist/issues/
```

### json-to-html.py
**Standalone HTML converter** - Converts JSON scan logs to beautiful HTML reports.

```bash
python3 ./dist/bin/json-to-html.py dist/logs/[TIMESTAMP].json dist/reports/[TIMESTAMP].html
```

**Features:**
- Fast & reliable (Python-based)
- Auto-opens in browser
- No dependencies (Python 3 standard library only)

---

## 🤖 AI Integration

### ai-triage.py
**AI-assisted triage** - Analyzes scan results to identify false positives.

Used internally by AI agents during Phase 2 of the end-to-end workflow.

### mcp-server.js
**Model Context Protocol server** - Exposes scan results to AI assistants (Claude Desktop, Cline, etc.).

```bash
node dist/bin/mcp-server.js
```

See [MCP-README.md](MCP-README.md) for setup and configuration.

---

## 🧪 Experimental Tools

### experimental/golden-rules-analyzer.php
**Semantic analysis** - 6 architectural rules for deep code review.

```bash
php ./dist/bin/experimental/golden-rules-analyzer.php /path/to/plugin
```

⚠️ **Experimental:** May have false positives. See [experimental/README.md](experimental/README.md).

---

## 📚 Supporting Files

### lib/
Shared bash functions used by multiple scripts. **Do not execute directly.**

- `colors.sh` - Terminal color codes
- `common-helpers.sh` - File handling, path utilities
- `false-positive-filters.sh` - False positive detection logic
- `json-helpers.sh` - JSON parsing and generation

### templates/
HTML templates for report generation. Used by `json-to-html.py`.

### fixtures/
Test data for validation. Used by CI/CD tests.

---

## ❓ Why is everything in /bin?

Following Unix convention, `/bin` contains executables. We also include supporting files (`lib/`, `templates/`) here for **co-location** with the scripts that use them.

**This is common in development tools:**
- **npm:** `node_modules/.bin/` (executables + support files)
- **Composer:** `vendor/bin/` (executables + support files)
- **PHPCS:** `bin/` (executables + libraries)
- **ESLint:** `bin/` (executables + support files)

**Benefits:**
- ✅ All tools in one place
- ✅ Easier to find related files
- ✅ Simpler path management
- ✅ Industry-standard pattern

---

## 🔗 Related Documentation

- [Main README](../../README.md) - User-facing documentation
- [User Guide](../README.md) - Complete command reference
- [Template Guide](../HOWTO-TEMPLATES.md) - Project template system
- [AI Instructions](../TEMPLATES/_AI_INSTRUCTIONS.md) - AI agent workflow
- [MCP Documentation](MCP-README.md) - AI integration via MCP

---

**Questions?** See [GitHub Issues](https://github.com/Hypercart-Dev-Tools/WP-Code-Check/issues)

