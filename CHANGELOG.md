# Changelog

All notable changes to AI-DDTK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **OPINIONATED Section in AGENTS.md** (v2.5.0)
  - Restructured architecture guidance into clearly marked "OPINIONATED: Architecture & Best Practices" section
  - Added "Why these opinions?" explanations for SOLID, DRY, FSM, scope control, documentation, and testing patterns
  - Added "When to customize" guidance for different team types (startup, enterprise, open source, agency, maintenance)
  - New Customization Guide with team-specific examples and common customization points
  - Philosophy statement: "Works great by default, customizable for experts"
  - Beginners get WordPress community best practices out-of-the-box
  - Senior developers can fork AGENTS.md and adjust to team standards
  - AI Agent Note: Follow custom AGENTS file if user references team standards
- **Apache 2.0 License** - Added root `LICENSE` and `NOTICE` files
  - NOTICE clarifies licensing split: Apache 2.0 (software), CC BY 4.0 (Fix-Iterate Loop), Dual (WPCC)
  - License section added to README.md
- **Fix-Iterate Loop — refined and wired into all docs**
  - Rewrote `fix-iterate-loop.md`: 541 → 226 lines, removed wrapping code fence, added flow diagram
  - Added "Why This Exists" intro, Meta-Reflection section (promoted from roadmap), Guardrails
  - Trimmed CSS-in-JSON example (125 → 12 lines), collapsed roadmap into Extensions table
  - Removed ecosystem-specific references (Neochrome, Beaver Builder) for portability
  - Added CC BY 4.0 license and Hypercart/Neochrome attribution footer
  - Referenced in: README.md (Tools table + repo structure), AGENTS.md (Testing & Validation),
    SYSTEM-INSTRUCTIONS.md (Available Tools + Workflow Triggers), `recipes/fix-iterate-loop.md` (pointer)
  - Fixed hardcoded absolute path in Tools.md (`/Users/.../bin/` → `~/bin/ai-ddtk/`)
- **Prerequisites section** in README.md — consolidated table of all dependencies (Git, Node.js, Python 3, Composer, GitHub CLI, Playwright) with install commands
- **Troubleshooting section** in README.md — `wpcc: command not found` and `WPCC not found` fixes
- **WP AJAX Test** added to README.md Tools table and repo structure

### Changed
- **WordPress Development Guidelines section** added to README.md
  - New section highlighting AGENTS.md opinionated architecture guidance
  - Philosophy statement: "Works great by default, customizable for experts"
  - Table showing Required vs. Opinionated sections
  - Team-specific customization examples (startup, enterprise, open source, agency, maintenance)
  - Links to full AGENTS.md guide
- **README.md documentation audit improvements** addressing 6 concerns from prior review:
  1. Installation steps now appear before tools (Quick Start section)
  2. All docs consolidated in repo (no longer in external theme folder)
  3. Correct paths (`wpcc` command, not raw script paths)
  4. Logical section ordering (install → usage → tools → advanced)
  5. Version numbers clarified (toolkit v1.0.5, AGENTS.md guide v2.4.0)
  6. Prerequisites documented
- **WPCC Project Templates** elevated from table row to dedicated showcase section with
  before/after example and inline pipeline visualization
- **Repository structure** in README.md updated to match actual layout (removed nonexistent
  `agents/`, `mcp/` dirs; added `wp-ajax-test`, `recipes/`, `templates/`, `fix-iterate-loop.md`)
- Removed duplicate "WPCC AI Instructions" link from README.md Links section
- Updated AGENTS.md version to v2.5.0 (OPINIONATED section restructure)
- **PHPStan WordPress/WooCommerce Setup** (v2.4.0)
  - New recipe: `recipes/phpstan-wordpress-setup.md` - Step-by-step guide for plugins and themes
  - New template: `templates/phpstan.neon.template` - Ready-to-copy configuration with comments
  - Added PHPStan section to AGENTS.md with workflow decision tree
  - Covers levels 3/5/8, troubleshooting, legacy baseline strategy
  - Documents WordPress, WooCommerce, and WP-CLI stubs setup
  - **Baseline & History Tracking** - Added comprehensive section covering:
    - Baseline generation workflow (`phpstan analyse --generate-baseline`)
    - What files to commit vs gitignore
    - Progress tracking table format for CHANGELOG/PROJECT-AUDIT
    - GitHub Actions CI workflow for automated PR checks
- **WP AJAX Test Tool v1.1.0** - Plugin-specific nonce support
  - `--nonce-url` flag to fetch nonces from custom admin pages
  - `--nonce-field` flag to specify custom nonce field names
  - Enhanced nonce detection with multiple pattern matching
  - Support for plugin-specific admin pages (e.g., `?page=my-plugin-settings`)
  - Verbose logging shows nonce source and field name
- **WP AJAX Test Tool - Phase 1 Implementation** (`tools/wp-ajax-test/`)
  - Core tool implementation (index.js, 320 lines)
  - CLI interface with commander.js
  - WordPress authentication (login, cookie handling)
  - Nonce extraction from wp-admin pages
  - AJAX endpoint testing (admin and nopriv)
  - JSON and human-readable output formats
  - Error handling with suggestions
  - Installation script (install.sh)
  - README.md with usage examples

### Fixed
- **WP AJAX Test Tool v1.0.1** - Authentication improvements
  - Fixed authentication failure by fetching initial cookies before login POST
  - Improved cookie handling across redirects
  - Enhanced success detection (checks for auth cookies, not just error strings)
  - Added verbose debugging output (shows cookies, redirects, auth status)
  - Added `--insecure` flag for SSL certificate verification bypass (.local sites)
  - Saves login response to `temp/login-debug.html` when verbose mode enabled
  - Better error messages with specific failure reasons
- **WP AJAX Test Tool Specification** (`tools/wp-ajax-test/SPEC.md`)
  - Lightweight WordPress AJAX endpoint testing without browser automation
  - Centralized-by-default design (call from AI-DDTK, local wrapper when needed)
  - Auto-authentication with nonce/cookie handling
  - JSON I/O for AI agent parsing
  - Batch testing support
  - AI agent instructions for centralized vs. local copy decision tree
- **ROADMAP.md**: Added AJAX Endpoint Testing as opportunity #9
- **SOLID Principles Guidance** in AGENTS.md (v2.3.1)
  - Added to Core Requirements section with full acronym breakdown
  - Integrated into "Building from the Ground Up" checklist
  - Mapped SOLID principles to WordPress patterns (hooks, interfaces, FSM)
- **System Instructions for AI Agents** (`SYSTEM-INSTRUCTIONS.md`)
  - Copy-paste instructions for Augment/Claude Code settings
  - AI-DDTK toolkit integration guidance across all projects
  - Available tools reference (WPCC, Performance Timer)
  - Workflow triggers (when to use each tool)
  - Security best practices for sensitive data
  - Task management and scope control guidelines
- **Sensitive Data Handling** in AGENTS.md (v2.3.1)
  - `/temp` folder requirement for all projects
  - `.gitignore` patterns for credentials, PII, auth files
  - When user provides credentials workflow (5-step process)
  - Code examples (wrong vs. correct patterns)
  - Playwright authentication state file handling
- **Resource Limits & Dependencies** in AGENTS.md (v2.3.1)
  - WP-CLI memory limit mitigation (134MB → 512M)
  - Playwright setup guidance (global install, avoid per-project)
  - Added to SYSTEM-INSTRUCTIONS.md for AI agent awareness

### Changed
- Updated AGENTS.md version to v2.3.1
- Enhanced Security section with Sensitive Data Handling subsection
- Updated README.md version to 1.0.5
- Playwright guidance: Recommend global install over per-project to avoid git commits

## [1.0.4] - 2026-02-02

### Added
- **Performance Profiling Integration** (WP Performance Timer)
  - Added Performance Profiling section to AGENTS.md (v2.3.0)
  - Workflow decision tree for runtime analysis
  - WPCC → Performance Timer pipeline documentation
  - Metrics reference table (time_ms, queries, memory_kb, depth)
  - Configuration reference (wp-config.php constants)
- **Workflow Recipes** (`recipes/` folder)
  - Created `recipes/performance-audit.md` - Complete WPCC → Timer workflow
  - 5-phase audit process: Scan → Triage → Profile → Measure → Report
  - Report template for documenting findings
  - AI agent instructions for performance audits
- **ROADMAP.md Updates**
  - Added Performance Profiling as opportunity #8
  - Marked completed items (feature discovery, orchestration, recipes)

### Changed
- Updated AGENTS.md version to v2.3.0

## [1.0.3] - 2026-02-02

### Added
- **WPCC Feature Discovery** (`wpcc --features`)
  - Lists all available WPCC capabilities with descriptions
  - Shows saved templates and their locations
  - Provides usage examples for AI agents
  - Documents end-to-end workflow phases
- **WPCC Orchestration in AGENTS.md**
  - Workflow decision tree for AI agents
  - End-to-end workflow documentation (Phases 1-4)
  - AI triage JSON structure reference
  - Common false positive patterns table
  - Links to WPCC AI instructions and guides
- **WPCC Advanced Features in README.md**
  - Project Templates documentation
  - AI-Assisted Triage workflow
  - GitHub Issue Creation (multi-platform)
  - End-to-End Workflow overview
  - IRL Audit Mode description
  - Quick examples and AI agent workflows

### Changed
- Updated version to 1.0.3 in README.md
- Updated AGENTS.md version to v2.2.0
- Enhanced `wpcc` wrapper with feature discovery system

## [1.0.2] - 2026-02-01

### Added
- GitHub Action for automated weekly WPCC sync (`.github/workflows/sync-wpcc.yml`)
  - Runs every Sunday at 00:00 UTC
  - Creates PR for review when updates are available
  - Manual trigger option with auto-merge capability
- User configuration file (`.ai-ddtk.config`)
  - `WPCC_UPDATE_MODE`: auto/manual/prompt
  - `WPCC_REPO`: Source repository for WPCC
  - `WPCC_BRANCH`: Branch to track

### Changed
- Updated all repository URLs to `Hypercart-Dev-Tools/AI-DDTK`

## [1.0.1] - 2026-02-01

### Added
- WP Code Check (WPCC) embedded via git subtree at `tools/wp-code-check/`
- Docker-based test suite for installation validation
  - `test/Dockerfile` - Ubuntu 22.04 test container
  - `test/test-install.sh` - 8 automated tests for install script

### Fixed
- Test script bash compatibility issues with `((PASSED++))` and `grep -c`

## [1.0.0] - 2025-02-01

### Added
- Initial release of AI-DDTK (AI Driven Development ToolKit)
- `install.sh` - Main installation and maintenance script
  - PATH configuration for shell (zsh/bash)
  - Git subtree management for embedded dependencies
  - Subcommands: `update`, `update-wpcc`, `setup-wpcc`, `status`, `uninstall`
  - Extensive LLM agent guidance in comments
  - GitHub CLI command reference for maintenance
- `bin/wpcc` - WP Code Check wrapper script
  - Resolves WPCC path from any directory
  - Auto-detects WPCC entry point
  - Helpful error messages for missing dependencies
- `tools/` directory structure for embedded dependencies
- `AGENTS.md` - WordPress development guidelines for AI agents
- Documentation files:
  - `README.md` - Project overview and quick start
  - `Tools.md` - Tool documentation
  - `fix-iterate-loop.md` - Testing workflow documentation

### Architecture
- Central toolkit design: install once, use from any project
- Git subtree approach for WP Code Check embedding
  - Allows upstream updates via `git subtree pull`
  - Supports future merge into main codebase
  - Enables contributing back via `git subtree push`
- PATH-based tool access for cross-project usage

### Tools Included
- `local-wp` - WP-CLI wrapper for Local by Flywheel
- `wpcc` - WP Code Check wrapper (requires setup-wpcc)
- Playwright integration (documentation)
- PixelMatch visual regression (documentation)

---

## Version History

| Version | Date | Summary |
|---------|------|---------|
| 1.0.4 | 2026-02-02 | Performance Profiling integration, `recipes/` folder, WPCC→Timer pipeline |
| 1.0.3 | 2026-02-02 | WPCC feature discovery, AGENTS.md orchestration, README advanced features |
| 1.0.2 | 2026-02-01 | GitHub Action for weekly WPCC auto-sync, user config file |
| 1.0.1 | 2026-02-01 | WPCC embedded via git subtree, Docker test suite |
| 1.0.0 | 2025-02-01 | Initial release with install script and WPCC integration |

---

## Upgrade Notes

### To 1.0.0
First release - no upgrade path needed.

**Fresh install:**
```bash
git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git ~/bin/ai-ddtk
cd ~/bin/ai-ddtk
./install.sh
./install.sh setup-wpcc
source ~/.zshrc
```


### Fixed
- **WP AJAX Test Tool - Authentication & SSL Improvements**
  - Added `--insecure` flag to skip SSL certificate verification (for Local by Flywheel)
  - Added verbose authentication logging (shows login URL, username, response status, cookies)
  - Fixed authentication with special characters in passwords (e.g., `#` symbol)
  - Added success/failure messages in verbose mode
  - Improved error debugging with detailed HTTP response information
