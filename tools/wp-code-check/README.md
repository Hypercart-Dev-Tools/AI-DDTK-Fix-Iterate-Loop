# WP Code Check by Hypercart

**Fast, zero-dependency WordPress performance analyzer that catches critical issues before they crash your site.**

[![CI](https://github.com/Hypercart-Dev-Tools/WP-Code-Check/actions/workflows/ci.yml/badge.svg)](https://github.com/Hypercart-Dev-Tools/WP-Code-Check/actions)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

> **Versioning:** See `dist/README.md` for the current released version. The version in the dist README (and the main bash script header) is the canonical source of truth.

---

## Why WP Code Check?

WordPress sites fail in production because of **performance antipatterns** that slip through code review:

- 🔥 **Unbounded queries** (`posts_per_page => -1`) that fetch 50,000 posts and crash the server
- 🐌 **N+1 query patterns** that turn 1 request into 1,000 database calls
- 💥 **Missing capability checks** that let subscribers delete your entire site
- 🔐 **Insecure deserialization** that opens remote code execution vulnerabilities
- 🧲 **Debug code in production** (`var_dump`, `console.log`) that exposes sensitive data

**WP Code Check catches these issues in seconds** — before they reach production.

---

## 🚀 Quick Start (Choose Your Path)

### 🖥️ **Shell/Terminal Users** (Fastest Setup)

**Prefer working directly in the terminal?** We've got you covered with a streamlined shell experience:

👉 **[Shell Quick Start Guide](SHELL-QUICKSTART.md)** - One-command installation, tab completion, and shell-first workflows

```bash
# One-command install
git clone https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git
cd WP-Code-Check
./install.sh

# Then just:
wp-check ~/my-plugin
```

**Features for shell users:**
- ✅ Automated installation with `install.sh`
- ✅ Tab completion for all options
- ✅ `wp-check init` - Interactive setup wizard
- ✅ `wp-check update` - Easy updates
- ✅ Enhanced `--help` with examples

**Time to first scan: 30 seconds** (vs. 5 minutes manual setup)

---

### 🤖 **AI Agent Users** (Automated Workflows)

If you're using an AI coding assistant (Cursor, GitHub Copilot, Augment, etc.):

1. Open `dist/TEMPLATES/_AI_INSTRUCTIONS.md` in your editor
2. Ask your AI: **"Please review this document and what can I do with this tool?"**
3. For automated workflows, ask: **"Run template [name] end to end"**

Your AI agent will guide you through:
- **Phase 1**: Scanning WordPress plugins/themes (with template auto-completion)
- **Phase 2**: AI-assisted triage to identify false positives
- **Phase 3**: Automated GitHub issue creation

See [AI Instructions](dist/TEMPLATES/_AI_INSTRUCTIONS.md) for the complete end-to-end workflow.

---

## What Makes WP Code Check Better?

| Feature | WP Code Check | WPCS | PHPStan-WP |
|---------|---------------|------|------------|
| **Zero dependencies** | ✅ Bash + grep only | ❌ Requires PHP, Composer | ❌ Requires PHP, Composer |
| **Runs anywhere** | ✅ Local, CI/CD, any OS | ⚠️ PHP environment needed | ⚠️ PHP environment needed |
| **WordPress-specific** | ✅ WP performance focus | ⚠️ Generic PHP standards | ⚠️ Type safety focus |
| **Speed** | ✅ Scans 10K files in <5s | ⚠️ Slower on large codebases | ⚠️ Slower on large codebases |
| **Production-tested** | ✅ Real-world patterns | ✅ Industry standard | ✅ Type-focused |
| **AI Supercharged** | ✅ Built-in AI-assisted triage | ❌ No AI support | ❌ No AI support |

---

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git
cd WP-Code-Check

# Run against your WordPress plugin/theme
./dist/bin/check-performance.sh --paths /path/to/your/plugin
```

### Example Output

```
━━━ CRITICAL CHECKS (will fail build) ━━━

▸ Unbounded posts_per_page [CRITICAL]
  ✗ FAILED
  ./includes/query-helpers.php:45: 'posts_per_page' => -1

▸ Debug code in production [CRITICAL]
  ✗ FAILED
  ./admin/js/admin.js:293: debugger;

━━━ SUMMARY ━━━
  Errors:   2
  Warnings: 0

✗ Check failed with 2 error(s)
```

---

## Features

### 🔍 **Multi-Layered Code Quality Analysis**

WP Code Check provides **two complementary analysis tools** for complete coverage:

#### **Quick Scanner** (Bash - Zero Dependencies)
- **30+ WordPress-specific checks** in under 5 seconds
- **Critical**: Unbounded queries, insecure deserialization, localStorage sensitive data, client-side serialization, **direct database queries without $wpdb->prepare()**
- **High**: Direct superglobal manipulation, **unsanitized superglobal read**, **admin functions without capability checks**, **WooCommerce N+1 patterns**, AJAX without nonce validation, unbounded SQL, expensive WP functions in polling
- **Medium**: N+1 patterns, transients without expiration, HTTP requests without timeout, unsafe RegExp construction, PHP short tags, **WooCommerce Subscriptions queries without limits**
- **Low**: Timezone-sensitive patterns

See [full check list](dist/README.md#what-it-detects).

#### **Golden Rules Analyzer** (PHP - Semantic Analysis) 🧪 **Experimental**
- **6 architectural rules** that catch design-level antipatterns
- **Duplication detection**: Find duplicate functions across files
- **State management**: Catch direct state mutations bypassing handlers
- **Configuration centralization**: Eliminate magic strings and hardcoded values
- **Query optimization**: Context-aware N+1 detection in loops
- **Error handling**: Ensure graceful failure for HTTP/file operations
- **Production readiness**: Flag debug code and TODO comments

> ⚠️ **Experimental:** Functional but may have false positives. Best for code reviews and learning. [See experimental README](dist/bin/experimental/README.md) for complete usage guide.

See [Golden Rules documentation](dist/README.md#experimental-golden-rules-analyzer).

### 📊 **Multiple Output Formats**

```bash
# Human-readable text (default)
./dist/bin/check-performance.sh --paths .

# JSON for CI/CD integration
./dist/bin/check-performance.sh --paths . --format json

# Auto-generated HTML reports
# Opens in browser automatically (local development)
```

#### JSON Logs

- When you run with `--format json` **and logging enabled** (i.e., without
  `--no-log`), WP Code Check writes a JSON log file to
  `dist/logs/YYYY-MM-DD-HHMMSS-UTC.json`.
- As of version **1.3.36**, these log files contain a single valid JSON document
  suitable for direct consumption by tools like the HTML report generator and AI
  agents.
- Logs generated by versions **before 1.3.36** may include non-JSON lines (for
  example Python tracebacks or `/dev/tty` errors) before the JSON payload. If you
  must parse an older log, strip all lines before the first `{` or re-run the scan
  with a newer version of WP Code Check.

### 🎯 **Baseline Support**

Manage technical debt in legacy codebases:

```bash
# Generate baseline from current state
./dist/bin/check-performance.sh --paths . --generate-baseline

# Future scans only report NEW issues
./dist/bin/check-performance.sh --paths .
```

### 📝 **Project Templates**

Save scan configurations for frequently-checked projects:

```bash
# Create template (AI agents can auto-complete metadata)
./dist/bin/run my-plugin

# Reuse template
./dist/bin/run my-plugin
```

**AI Agent Features:**
- ✅ **Auto-completion** - AI extracts plugin name, version, and GitHub repo from headers
- ✅ **Template Variations** - Handles hyphens, underscores, spaces in filenames
- ✅ **GitHub Integration** - Optional `GITHUB_REPO` field for automated issue creation

See [HOWTO-TEMPLATES.md](dist/HOWTO-TEMPLATES.md) for manual usage or [AI Instructions - Phase 1b](dist/TEMPLATES/_AI_INSTRUCTIONS.md#phase-1b-template-completion-if-needed) for AI-assisted template creation.

### 🤖 **Phase 2: AI-Assisted Triage (v1.1 POC)**

Validate findings and identify false positives with AI assistance:

```bash
# After running a scan, use AI to triage the results
# AI analyzes the JSON log and provides:
# - Summary stats (reviewed, confirmed, false positives)
# - Overall narrative assessment
# - Recommendations for next steps
```

**Features:**
- ✅ **False Positive Detection** - Identifies common false positives (e.g., `phpcs:ignore` comments, adjacent sanitization)
- ✅ **Confidence Scoring** - Rates overall assessment confidence (high/medium/low)
- ✅ **Actionable Recommendations** - Prioritized list of issues to fix
- ✅ **Executive Summary** - 3-5 paragraph narrative for stakeholders
- ✅ **TL;DR Format** - Summary appears at top of HTML report for quick review

**Workflow:**
1. Run scan with template: `./dist/bin/run [template-name]`
2. AI agent analyzes findings and updates JSON with `ai_triage` section
3. HTML report regenerated with AI summary at top
4. Optionally create GitHub issue with confirmed findings

See [AI Instructions - Phase 2](dist/TEMPLATES/_AI_INSTRUCTIONS.md#phase-2-ai-assisted-triage) for detailed triage workflow and common false positive patterns.

### 🎫 **GitHub Issue Creation**

Automatically create GitHub issues from scan results with AI triage data:

```bash
# Create issue from latest scan (specify repo)
./dist/bin/create-github-issue.sh \
  --scan-id 2026-01-12-155649-UTC \
  --repo owner/repo

# Or use template's GitHub repo (if GITHUB_REPO is set in template)
./dist/bin/create-github-issue.sh --scan-id 2026-01-12-155649-UTC

# Generate issue body without creating (no repo needed)
# Useful for manual issue creation or when repo is not specified
./dist/bin/create-github-issue.sh --scan-id 2026-01-12-155649-UTC
# → Saves to dist/issues/GH-issue-2026-01-12-155649-UTC.md
```

**Features:**
- ✅ **Auto-formatted Issues** - Clean, actionable GitHub issues with checkboxes
- ✅ **AI Triage Integration** - Shows confirmed issues vs. needs review
- ✅ **Template Integration** - Reads GitHub repo from project templates (optional)
- ✅ **Interactive Preview** - Review before creating the issue
- ✅ **Graceful Degradation** - Works without GitHub repo (generates issue body only)
- ✅ **Persistent Issue Files** - Saves to `dist/issues/` with matching filename pattern for easy manual copy/paste
- ✅ **Multi-Platform Support** - Use issue bodies in Jira, Linear, Asana, Trello, etc.

**Requirements:**
- GitHub CLI (`gh`) installed and authenticated (only for automated creation)
- Scan with AI triage data (recommended for best results)

See [AI Instructions - Phase 3](dist/TEMPLATES/_AI_INSTRUCTIONS.md#phase-3-github-issue-creation) for complete workflow and error handling.

### 🔌 **MCP Protocol Support (AI Integration)**

WP Code Check supports the Model Context Protocol (MCP), allowing AI assistants like Claude Desktop and Cline to directly access scan results.

**Quick Start:**

```bash
# 1. Install Node.js dependencies
npm install

# 2. Configure Claude Desktop (macOS)
# Add to ~/Library/Application Support/Claude/claude_desktop_config.json:
{
  "mcpServers": {
    "wp-code-check": {
      "command": "node",
      "args": ["/absolute/path/to/wp-code-check/dist/bin/mcp-server.js"]
    }
  }
}

# 3. Run a scan
./dist/bin/check-performance.sh --paths /path/to/plugin

# 4. Ask Claude: "Show me the latest WP Code Check scan results"
```

**Features:**
- ✅ **Direct AI Access** - AI assistants can read scan results without copy/paste
- ✅ **Latest Scan Resource** - `wpcc://latest-scan` returns most recent JSON
- ✅ **Historical Scans** - `wpcc://scan/{id}` accesses specific scans
- ✅ **HTML Reports** - `wpcc://latest-report` returns formatted reports
- ✅ **Zero Config** - Works with existing JSON output

**Supported AI Tools:**
- Claude Desktop (macOS, Windows)
- Cline (VS Code extension)
- Any MCP-compatible AI assistant

**Developer Guide:**

For AI agents using MCP:

```javascript
// Read latest scan
const scan = await readResource("wpcc://latest-scan");

// Parse findings
const findings = JSON.parse(scan.text).findings;

// Analyze critical issues
const critical = findings.filter(f => f.severity === "CRITICAL");
```

See [PROJECT/1-INBOX/PROJECT-MCP.md](PROJECT/1-INBOX/PROJECT-MCP.md) for complete MCP documentation.

**AI Agent Instructions:**

When analyzing WP Code Check results via MCP:
1. Read `wpcc://latest-scan` for JSON data
2. Check `ai_triage` field for confirmed vs. false positives
3. Prioritize CRITICAL and HIGH severity findings
4. Suggest fixes with code examples
5. Reference specific file paths and line numbers

For complete AI triage workflow and false positive detection patterns, see [AI Instructions](dist/TEMPLATES/_AI_INSTRUCTIONS.md).

---

## 🛠️ Tools Included

WP Code Check is a **complete code quality suite** with multiple specialized tools:

### Core Tools (Stable)

| Tool | Type | Purpose | Speed |
|------|------|---------|-------|
| **Quick Scanner** | Bash | 30+ WordPress antipatterns | <5s |
| **JSON to HTML Converter** | Python | Beautiful HTML reports from scan logs | <1s |
| **GitHub Issue Creator** | Bash | Auto-create GitHub issues from scan results | <2s |
| **Slack Integration** | Bash | CI/CD notifications | Instant |
| **Baseline Manager** | Built-in | Track technical debt over time | N/A |
| **Project Templates** | Built-in | Save scan configurations | N/A |

### Experimental Tools 🧪

| Tool | Type | Purpose | Speed | Status |
|------|------|---------|-------|--------|
| **Golden Rules Analyzer** | PHP | 6 architectural rules with semantic analysis | ~10-30s | Experimental - may have false positives |

**Choose your workflow:**
- **Fast CI/CD**: Quick Scanner only (zero dependencies, stable)
- **Deep Review**: Quick Scanner + Golden Rules (experimental)
- **Legacy Audit**: Quick Scanner + Baseline + Golden Rules (experimental)

### Output Directories

All scan outputs are organized in the `dist/` directory:

| Directory | Contents | Git Tracked | Purpose |
|-----------|----------|-------------|---------|
| `dist/logs/` | JSON scan results (`*.json`) | ❌ No | Machine-readable scan data |
| `dist/reports/` | HTML reports (`*.html`) | ❌ No | Human-readable scan reports |
| `dist/issues/` | GitHub issue bodies (`GH-issue-*.md`) | ❌ No | Manual copy/paste to GitHub or project management apps |
| `dist/TEMPLATES/` | Project templates (`*.txt`) | ✅ Yes | Reusable scan configurations |

**Filename Pattern:** All outputs use matching UTC timestamps for easy correlation:
```
dist/logs/2026-01-13-031719-UTC.json
dist/reports/2026-01-13-031719-UTC.html
dist/issues/GH-issue-2026-01-13-031719-UTC.md
```

---

## CI/CD Integration

### GitHub Actions

```yaml
name: WP Code Check
on: [push, pull_request]

jobs:
  quick-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Quick Scan
        run: |
          git clone https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git
          ./WP-Code-Check/dist/bin/check-performance.sh --paths . --format json --strict

  deep-analysis:
    runs-on: ubuntu-latest
    needs: quick-scan
    steps:
      - uses: actions/checkout@v3

      - name: Golden Rules Analysis (Experimental)
        run: |
          git clone https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git
          php ./WP-Code-Check/dist/bin/experimental/golden-rules-analyzer.php . --fail-on=error
```

### GitLab CI

```yaml
wp-code-check:
  script:
    - git clone https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git
    - ./WP-Code-Check/dist/bin/check-performance.sh --paths . --format json
```

---

## Documentation

- **[User Guide](dist/README.md)** - Complete command reference and examples (includes canonical version number)
- **[Template Guide](dist/HOWTO-TEMPLATES.md)** - Project template system
- **[Changelog](CHANGELOG.md)** - Version history and development progress
- **[AI Agent Guide](AGENTS.md)** - WordPress development guidelines for AI assistants
- **[Disclosure Policy](DISCLOSURE-POLICY.md)** - Responsible disclosure and public report publication policy

---

## Command Reference

```bash
# Basic scan
./dist/bin/check-performance.sh --paths /path/to/plugin

# JSON output for CI/CD
./dist/bin/check-performance.sh --paths . --format json

# Strict mode (warnings fail the build)
./dist/bin/check-performance.sh --paths . --strict

# Generate baseline for legacy code
./dist/bin/check-performance.sh --paths . --generate-baseline

# Verbose output (show all findings)
./dist/bin/check-performance.sh --paths . --verbose

# Disable logging
./dist/bin/check-performance.sh --paths . --no-log
```

---

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Note:** Contributors must sign a [Contributor License Agreement (CLA)](CLA.md) before their first pull request can be merged. This is a one-time process that ensures legal clarity for the dual-license model.

---

## 📄 License

WP Code Check is **dual-licensed**:

### Open Source License (Apache 2.0)

The core tool is licensed under the **Apache License 2.0**, which means:

- ✅ **Free for everyone** - Use for personal or commercial projects
- ✅ **Modify and distribute** - Fork, customize, and share
- ✅ **Patent protection** - Includes explicit patent grant
- ✅ **No restrictions** - Use in proprietary software

See [LICENSE](LICENSE) for full terms.

### Commercial License (Optional)

For organizations that need **priority support, advanced features, or SLA guarantees**, we offer commercial licenses:

- 🎯 **Priority Support** - Guaranteed response times, dedicated channels
- 🚀 **Advanced Features** - Custom rules, white-label reports, team collaboration
- 🏢 **Enterprise Features** - SSO, audit logs, on-premise deployment
- 📊 **Service Level Agreements** - Uptime guarantees and compliance support

See [LICENSE-COMMERCIAL.md](LICENSE-COMMERCIAL.md) for details and pricing.

**Contact:** noel@hypercart.io

---

## About

**WP Code Check** is developed by [Hypercart](https://hypercart.com), a DBA of Neochrome, Inc.

- 🌐 Website: [WPCodeCheck.com](https://wpcodecheck.com)
- 📧 Support: noel@hypercart.io
- 🐛 Issues: [GitHub Issues](https://github.com/Hypercart-Dev-Tools/WP-Code-Check/issues)

---

**Made with ❤️ for the WordPress community**

