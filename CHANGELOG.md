# Changelog

All notable changes to AI-DDTK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.12] - 2026-03-07

### Changed
- **Version updates**
  - README.md updated to `1.0.12`
  - install.sh updated to `1.0.12`
  - AGENTS.md updated to `v2.7.4`
- **Playwright Auth docs** now note that Local/dev HTTPS origins with self-signed certificates are handled automatically for supported local hosts

### Fixed
- **`pw-auth` Local HTTPS auth capture** — Playwright now ignores certificate errors for `https://localhost`, `https://127.0.0.1`, `https://[::1]`, `https://*.local`, and `https://*.test` so self-signed Local-style certificates do not break one-time login capture
- **`pw-auth` temp file creation on macOS** — temporary Playwright script and log files now use a suffix-safe helper instead of relying on BSD `mktemp` templates like `XXXXXX.js`

## [1.0.11] - 2026-03-07

### Changed
- **Version updates**
  - README.md updated to `1.0.11`
  - install.sh updated to `1.0.11`
  - AGENTS.md updated to `v2.7.3`
- **Playwright Auth troubleshooting** now includes exact WP-CLI diagnostic commands in both the CLI output and the docs

### Fixed
- **`pw-auth` cache reuse** now live-validates fresh cached auth against `/wp-admin/` before reuse and falls back to re-authentication when the saved session is no longer valid
- **`pw-auth` login URL validation** now compares exact parsed origins instead of using a prefix match
- **`pw-auth --wp-cli` parsing** now safely handles quoted command prefixes without using brittle space splitting

## [1.0.10] - 2026-03-07

### Changed
- **Version updates**
  - README.md updated to `1.0.10`
  - install.sh updated to `1.0.10`
  - AGENTS.md updated to `v2.7.2`
- **Playwright Auth instructions** now explicitly tell agents to run `pw-auth login` immediately before browser automation and rerun with `--force` if the one-time login URL expires or auth is stale

## [1.0.9] - 2026-03-07

### Changed
- **Version updates**
  - README.md updated to `1.0.9`
  - install.sh updated to `1.0.9`
- **Playwright Auth docs** now clarify that some imported/proxied Local sites still need `WP_ENVIRONMENT_TYPE` defined for browser requests, even if WP-CLI is already running in `local`

### Fixed
- **`pw-auth` false-positive error detection** — the Playwright login flow now detects real WordPress `wp_die()` / fatal pages using error-page markers and specific fatal messages instead of matching generic `not allowed` text from normal admin markup
- **Dev Login mu-plugin template host allowlist** — `templates/dev-login-cli.php` now accepts `*.test` hosts in addition to localhost and `*.local`
- **Dev Login mu-plugin template user resolution** — the WP-CLI command now falls back to `WP_CLI::get_runner()->config['user']` so wrappers that pass `--user` as a global WP-CLI flag still resolve the requested user correctly

## [1.0.8] - 2026-03-07

### Added
- **Playwright Auth helper (`pw-auth`)** for passwordless WP admin login in Playwright sessions
  - New `bin/pw-auth` CLI with `login`, `status`, and `clear` commands
  - Generates one-time login URLs via WP-CLI, captures auth state via Playwright
  - Caches `storageState` to `./temp/playwright/.auth/<user>.json` relative to CWD (12h default, configurable)
  - Supports Local by Flywheel via `--wp-cli "local-wp <site>"`, custom `--redirect` paths, `--force` re-auth
  - Per-user auth files (e.g., `admin.json`, `editor.json`)
  - `--site-url` validated against WP-CLI login URL origin to catch mismatches
  - Auth verification: checks `wordpress_logged_in_` cookie, `/wp-admin/` accessibility, error page detection
  - Playwright module resolution: pre-check with fallback to `playwright-core`, temp script file (avoids `node -e` resolution issues), and automatic `npm root -g` / `NODE_PATH` recovery before failing
- **Dev Login CLI mu-plugin template** (`templates/dev-login-cli.php`)
  - One-time, short-lived login tokens via WP-CLI (`wp dev login`)
  - Host allowlist (localhost, 127.0.0.1, ::1, *.local) with `dev_login_allowed_hosts` filter
  - `--format=url` for clean scripting output, `--redirect` for custom landing pages
  - Disabled in production environments, limited to users with `edit_posts` capability
  - PHP 7.0+ compatible (no `str_ends_with()` dependency)
- **Playwright Auth documentation across the toolkit**
  - AGENTS.md: Dedicated Playwright Auth section, Available Tools table, Workflow Triggers, Quick CLI Commands
  - README.md: Playwright Auth section with setup, usage, prerequisites, and troubleshooting table
  - `temp/README.md`: Updated Playwright section with `pw-auth` workflow, CWD storage note, and Playwright auto-resolution guidance

### Changed
- **Version updates**
  - README.md updated to `1.0.8`
  - install.sh updated to `1.0.8`
  - AGENTS.md updated to `v2.7.1`
- **Playwright Auth guidance** now explains that `pw-auth` auto-attempts global npm-root / `NODE_PATH` recovery before falling back to manual export instructions
- **4X4.md** trimmed completed Playwright-auth sprint checklist items after they were captured in this changelog

### Fixed
- **`pw-auth` command injection** — replaced `eval` with bash array invocation for WP-CLI command execution; `--wp-cli`, `--user`, and `--redirect` values no longer pass through a shell parser
- **`.mjs` + `require()` incompatibility** — temp Playwright script now uses `.js` extension (CJS) so `require()` works correctly
- **Subdirectory WordPress installs** — Playwright verification now uses the full `--site-url` base path (not just origin) for `/wp-admin/` reachability check
- **`--redirect` double-encoding** — removed `rawurlencode()` from CLI side; `add_query_arg()` handles encoding, PHP `$_GET` auto-decodes on the receiving end
- **PHP 7 compatibility** — replaced `str_ends_with()` with `substr()` in mu-plugin host check
- **Auth file stored in toolkit root** — default path changed from AI-DDTK's `temp/` to CWD `./temp/playwright/.auth/` so each project gets its own cache
- **`--site-url` was unused** — now validated against the login URL origin returned by WP-CLI; mismatches fail immediately with a clear error
- **Weak auth verification** — Playwright script now checks 4 conditions: not on `wp-login.php`, no WP error page, `wordpress_logged_in_` cookie present, `/wp-admin/` accessible without redirect
- **Global Playwright installs not resolvable by Node** — `pw-auth` now auto-discovers `npm root -g`, appends it to `NODE_PATH` without duplication, re-checks `playwright` / `playwright-core`, and logs the auto-configured path before failing

## [1.0.7] - 2026-03-06

### Added
- **Experimental `theme-crash-loop.sh` workflow** under `experimental/`
  - Moves the proven crash-loop prototype out of the repo root and into an explicit incubation area
  - Accepts reusable parameters for Local site name, target project root, fallback/target theme slugs, and log overrides
  - Stores run artifacts under the target project's `temp/theme-crash-loop/<run-id>/`
  - Can launch itself via `aiddtk-tmux` for unattended repro/debug loops

### Changed
- **Version updates**
  - README.md updated to `1.0.7`
  - install.sh updated to `1.0.7`
- **README.md** now documents the new `experimental/` folder and the initial crash-loop helper
- **4X4.md** trimmed completed tmux-only checklist items and added an experimental crash-loop promotion backlog item
- **Tmux validation status** recorded for release hygiene; the previously-open dashboard item is now complete

### Fixed
- **Crash-loop workflow portability** no longer depends on the script living inside a specific theme repository or on one hardcoded Local site/theme combination
- **Experimental crash-loop verification fixes**
  - `experimental/theme-crash-loop.sh` now supports `--dry-run` even when the inferred Local site path does not exist yet
  - The experimental helper was marked executable so it can be invoked directly as documented

## [1.0.6] - 2026-03-06

### Added
- **Optional `aiddtk-tmux` wrapper** for resilient AI-agent terminal sessions
  - New `bin/aiddtk-tmux` helper with `start`, `status`, `list`, `send`, `capture`, `attach`, and `stop`
  - Deterministic AI-DDTK session naming based on workspace folders
  - Session output logging to `temp/logs/tmux/`
  - Friendly fallback messaging when `tmux` is not installed
- **Tmux proxy documentation across the toolkit**
  - README quick-start, usage, dedicated tmux section, and troubleshooting updates
  - AGENTS.md guidance for when agents should switch to tmux-backed workflows
  - `temp/README.md` updates for tmux log storage and commands

### Changed
- **`install.sh` updated to v1.0.6**
  - Status output now reports optional `tmux` availability
  - Usage and first-run next steps now advertise `aiddtk-tmux`
  - Internal repository structure comments updated to reflect current toolkit layout
- **Version updates**
  - README.md updated to `1.0.6`
  - AGENTS.md updated to `v2.7.0`

### Fixed
- **Agent terminal recovery guidance** now points to a persistent tmux-backed workflow instead of relying solely on IDE terminal state

## [1.0.5] - 2026-02-07

### Added
- **Root `.gitignore` file** for repository-wide exclusions
  - Excludes `/temp` folder contents (preserves structure with `.gitkeep`)
  - Excludes credentials, environment files, authentication data
  - Excludes IDE files, logs, OS files, build artifacts
  - Allows `temp/README.md` and `.gitkeep` files to be tracked
- **`/temp` folder structure** for sensitive data and temporary files
  - `temp/credentials/` - API keys, passwords, tokens
  - `temp/reports/` - WPCC, PHPStan, performance reports
  - `temp/data/` - Exports, imports, backups
  - `temp/playwright/` - Playwright authentication state
  - `temp/logs/` - Debug logs
  - `temp/analysis/` - AI agent working files (notes, drafts)
  - Complete folder structure created with `.gitkeep` files
- **`temp/README.md`** - Comprehensive guide for `/temp` folder usage
  - Recommended folder structure with examples
  - "What Goes Where" guide for each subfolder
  - AI agent guidelines with path recommendations
  - Security best practices
  - Quick commands for setup and maintenance
  - Links to AGENTS.md for complete security guidelines
- **README.md updates** for `/temp` folder
  - Added note in Quick Start about temp folder availability
  - Added `/temp` structure to Repository Structure section
  - Link to `temp/README.md` for complete usage guidelines
- **.wpcignore file** for WPCC scan exclusions
  - Excludes embedded tools (`tools/wp-code-check/`, `tools/wp-ajax-test/`)
  - Excludes version control (`.git/`), dependencies (`node_modules/`, `vendor/`)
  - Excludes build artifacts, WPCC output, temporary files
  - Prevents recursive scanning when WPCC scans AI-DDTK itself
  - Template for future WPCC `.wpcignore` support (planned feature)
- **WPCC scanning workaround** in README.md Troubleshooting
  - Documents how to exclude embedded tools when scanning AI-DDTK
  - Provides alternative: scan only specific directories
  - Notes `.wpcignore` file for future WPCC versions
- **BACKLOG.md item #2**: WPCC Performance improvements
  - `.wpcignore` support implementation plan
  - Progress indicators and timeout handling
  - Performance optimization strategies
  - Success criteria and workarounds
  - GitHub issues created: AI-DDTK [#5](https://github.com/Hypercart-Dev-Tools/AI-DDTK-Fix-Iterate-Loop/issues/5), WPCC [#112](https://github.com/Hypercart-Dev-Tools/WP-Code-Check/issues/112)
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
    AGENTS.md (Available Tools + Workflow Triggers), `recipes/fix-iterate-loop.md` (pointer)
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
- Updated AGENTS.md version to v2.3.1
- Enhanced Security section with Sensitive Data Handling subsection
- Updated README.md version to 1.0.5
- Playwright guidance: Recommend global install over per-project to avoid git commits

### Fixed
- **WP AJAX Test Tool v1.0.1** - Authentication improvements
  - Fixed authentication failure by fetching initial cookies before login POST
  - Improved cookie handling across redirects
  - Enhanced success detection (checks for auth cookies, not just error strings)
  - Added verbose debugging output (shows cookies, redirects, auth status)
  - Added `--insecure` flag for SSL certificate verification bypass (.local sites)
  - Fixed authentication with special characters in passwords (e.g., `#` symbol)
  - Added success/failure messages in verbose mode
  - Saves login response to `temp/login-debug.html` when verbose mode enabled
  - Better error messages with specific failure reasons
  - Improved error debugging with detailed HTTP response information
- **WP AJAX Test Tool** (`tools/wp-ajax-test/ROADMAP.md`)
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
- **System Instructions for AI Agents** (merged into `AGENTS.md`)
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
  - Added to AGENTS.md for AI agent awareness

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
| 1.0.6 | 2026-03-06 | Optional tmux proxy wrapper, install/status detection, resilient agent-session documentation |
| 1.0.5 | 2026-02-07 | Docs consolidation, `/temp` structure, licensing, Fix-Iterate Loop refinements |
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
