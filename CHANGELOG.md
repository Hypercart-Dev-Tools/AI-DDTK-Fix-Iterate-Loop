# Changelog

All notable changes to AI-DDTK will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- CHANGELOG MAINTAINER RULES
- No [Unreleased]. Every entry belongs to a dated version block: ## [X.Y.Z] - YYYY-MM-DD
- PATCH for fixes/docs · MINOR for new tools or capabilities · MAJOR for breaking changes
- Batch same-session changes into one block rather than one block per commit
- Entry format: - **`tool-or-file`** or **Feature** — outcome-focused description (what changed and why it matters)
- No real site names, hostnames, local paths, user IDs, tokens, or credentials
- Do not edit a version block that has already been committed and pushed
-->

## [1.5.0] - 2026-03-29

### Added
- **VS Code extension — `contributes.mcpServerDefinitionProviders`** — the extension now registers the AI-DDTK MCP server directly with VS Code's agent runtime via `vscode.lm.registerMcpServerDefinitionProvider`. GitHub Copilot, Cline, Continue, and any future VS Code MCP client auto-discover the server the moment the extension is installed — no manual config files required.
- **`tools/mcp-server/mcp-configs/vscode.json`** — template for users who prefer manual `.vscode/mcp.json` setup (VS Code Copilot workspace config format; uses `"servers"` root key and `"type": "stdio"`).

### Changed
- **VS Code extension `engines.vscode`** — bumped from `^1.85.0` to `^1.100.0` (MCP provider API requires VS Code 1.100+, May 2025).
- **VS Code extension `isMcpConfigured()`** — now also recognises `.vscode/mcp.json` alongside `.mcp.json` / `.mcp.local.json` when checking project wiring state.
- **`.mcp.README.md`** — retitled from "for Claude Code" to client-agnostic; added a client config reference table covering Claude Code, VS Code Copilot, Augment Code, Cursor, and Claude Desktop.

## [1.4.2] - 2026-03-26

### Added
- **`PROJECT/1-INBOX/P1-UX-REFACTOR.md`** — replaced a transient UX feedback transcript with a structured three-phase remediation plan covering assumption cleanup, supported project wiring and readiness checks, and safety hardening. The plan explicitly includes removing maintainer-local paths and environmental assumptions from shipped template files.

## [1.4.1] - 2026-03-26

### Fixed
- **`tools/qm-bridge/ai-ddtk-test-delays.php`** — added `current_user_can('manage_options')` auth gate to both the `template_redirect` action and the shortcode handler; previously any anonymous visitor could trigger slow queries, external HTTP calls, and CPU-bound loops via `?aiddtk_test_delays=1`.

### Changed
- **`recipes/performance-audit.md`** — added explicit mu-plugins path confirmation step before writing any instrumentation files; added Phase 5 Cleanup (with security warning about the test-delays fixture); renumbered old Phase 5 Report to Phase 6; updated WP Performance Timer link to the Hypercart-Dev-Tools org; revised agent workflow summary to prefer the `wpcc_run_scan` MCP tool and include a mandatory cleanup step.

## [1.4.0] - 2026-03-26

### Added
- **`experimental/vscode-extension`** — new VS Code extension providing a status bar indicator and command palette integration for AI-DDTK; includes 5 commands (`Wire Project for MCP`, `Run Preflight Check`, `Scan with WPCC`, `Open Docs`, `Check Status`), TypeScript source (`extension.ts`, `manager.ts`, `statusBar.ts`, `commands.ts`), esbuild bundle pipeline, ESLint config, and `.vscode/launch.json` + `.vscode/tasks.json` for one-click F5 debugging by contributors.
- **`experimental/wire-project`** — CLI script that automates per-project MCP configuration by generating `.mcp.local.json`, updating `.gitignore`, and creating a `CLAUDE.md` agent reference in any WordPress project directory.
- **`experimental/README.md`** — documents the purpose, usage, and future roadmap for all experimental features.

### Changed
- **`experimental/P1-ONBOARDING.md`** — moved from `PROJECT/2-WORKING/` into `experimental/` alongside the tools it describes.
- **`PROJECT/3-DONE/P1-AUDIT-MATT.md`** — moved from `PROJECT/2-WORKING/` to mark the audit as complete.
- **`README-AI-DDTK.md`** — minor update.

## [1.3.1] - 2026-03-25

### Added
- **`pw-auth check dom` assertion workflow** — added multi-selector checks via `--selectors`, built-in assertions (`visible`, `hidden`, `text-contains`, `attr-equals`), optional `--wait-for` gating for AJAX-rendered content, and screenshot capture policies (`never`, `on-failure`, `always`) so agents can verify richer page state without writing throwaway Playwright scripts.

### Changed
- **`pw-auth check dom` result contract** — JSON output now includes a per-selector `results` array, aggregate `assertion_failed` status, selector-level screenshot paths, and multi-selector extract aggregation, while preserving the existing top-level result artifact flow under `temp/playwright/checks/<run-id>/`.
- **`pw-auth login` noisy-WP-CLI hardening** — login failure reporting now suppresses PHP `Deprecated` / `Notice` stderr noise and keeps actionable WP-CLI errors visible, while login URL extraction is more defensive when stdout contains extra lines.
- **Documentation and project tracking** — updated `docs/PW-AUTH-COMMANDS.md`, `docs/CLI-REFERENCE.md`, `README.md`, `AGENTS.md`, `docs/TROUBLESHOOTING.md`, and `PROJECT/2-WORKING/P1-SCD-FEEDBACK.md` to document the new `pw-auth check dom` capabilities, exit semantics, and Phase 5 completion status.
- **Real-environment validation** — verified the new multi-selector `visible` flow and a second `--wait-for` + `text-contains` assertion flow against a live LocalWP admin surface using cached auth, confirming the expanded `check dom` contract works outside the fake-runtime harness.

## [1.3.0] - 2026-03-25

### Changed
- **`preflight.sh` reliability overhaul** — removed `set -e` (failures are expected in a diagnostic script), fixed macOS `wc -l` whitespace issue, added exit-code tracking (exits with count of critical failures), improved WPCC feature detection, and switched to ASCII markers for terminal compatibility.
- **`experimental/preflight.md` rewrite for consuming projects** — rewrote from the perspective of agents working in external WordPress projects where AI-DDTK is installed as a toolkit, not agents inside the AI-DDTK repo itself. Removed "Session Rules" directive block that other agents flagged as prompt-injection-like. All MCP and WordPress steps are now conditional with skip guidance.
- **`AGENTS.md` preflight section** — replaced dead link to `temp/PREFLIGHT-INSTALL-INTEGRATION.md` with a table distinguishing shell preflight (`./preflight.sh`) from MCP-aware preflight (`experimental/preflight.md`), clarifying when to use each.

### Removed
- **`temp/ai-ddtk-preflight-complete.md`** — deleted redundant copy of the preflight checklist (content already lives in `experimental/preflight.md`).

## [1.2.9] - 2026-03-25

### Changed
- **`README.md` optional preflight discoverability** — added a short documentation-table entry pointing to `experimental/preflight.md` so users can adopt the session-start preflight workflow without repeated manual reminders.

## [1.2.8] - 2026-03-25

### Changed
- **`experimental/servers.md` troubleshooting hardening** — updated T-2 and T-3 with safer, execution-ready workflows: `local-wp`-scoped commands, DB backup before URL rewrites, `search-replace --dry-run` before apply, and `/etc/hosts` backup before sudo edits.

## [1.2.7] - 2026-03-25

### Added
- **`experimental/servers-audit.sh` baseline report generator** — added a new hostname/port audit helper that captures listening services, DNS and hosts state, Local WP site metadata, service-manager status, and auto-detected conflict sections into a populated Markdown snapshot. The script mirrors the resilient orchestration patterns used in other experimental tooling and also writes machine-readable artifacts under `temp/servers-audit/<run-id>/`.

### Changed
- **`experimental/servers.md` usage alignment** — expanded the template’s run instructions to include the new `--focus` and `--previous-snapshot` options plus the artifact-output note so developers can run targeted hostname audits and maintain diff-friendly baselines.
- **Active-fix guidance for server audits** — expanded the `## AI Agent Instructions` flow in both `experimental/servers.md` and generated audit output to require detect → concrete fix commands → permission-gated execution for privileged actions → post-fix re-audit verification → snapshot diff validation, with explicit iteration stop conditions.

## [1.2.6] - 2026-03-24

### Fixed
- **`bin/local-wp` help/list startup path** — deferred PHP auto-detection until after argument parsing so `local-wp --help` and `local-wp --list` no longer silently exit on Linux, WSL, or other environments without Local’s macOS directory layout.

## [1.2.5] - 2026-03-24

### Changed
- **`README.md` platform framing** — replaced the confusing "macOS required" quick-start note with clearer "macOS-centric, Linux-friendly" messaging so Linux and WSL users understand that core scanning still works.
- **`README.md` install wording** — clarified that `~/bin/ai-ddtk` is a chosen target path, not a required match to the GitHub repo’s uppercase name, reducing clone-path confusion for first-time users.
- **`README.md` MCP onboarding** — added a one-sentence explanation of Model Context Protocol near the top of the overview so WordPress developers unfamiliar with MCP are not forced to infer the term from context.
- **Feature discoverability** — promoted `mcp-local-config` and `install.sh` maintenance/doctor commands from "Hidden Gems" into first-pass discovery areas (`README.md` and `install.sh --help`) so valuable capabilities are visible earlier.

## [1.2.4] - 2026-03-24

### Fixed
- **`README.md` pw-auth examples** — updated the quick example commands to use the supported `--wp-cli` flag and a valid `check dom` invocation with required `--selector` and `--extract` arguments.
- **`README.md` install flow docs** — removed the stale post-install `setup-wpcc` step and clarified that `./install.sh` now performs PATH setup, WPCC setup, and conditional MCP setup by default.

### Changed
- **`AGENTS.md` positioning** — clarified that `README.md` is the high-level overview while `AGENTS.md` is the detailed operational source of truth for agent workflow guidance.
- **Documentation index** — added the weekly UX audit checklist to the `README.md` documentation table so the overview page points to the current recurring UX review workflow.

## [1.2.3] - 2026-03-24

### Changed
- **`bin/pw-auth` internal refactor** — Externalized all embedded Node.js/Playwright helper scripts into a dedicated `bin/pw-auth-helpers/` directory. The main script's logic is unchanged, but it now delegates to these external scripts, improving maintainability and code separation.

## [1.2.2] - 2026-03-24

### Fixed
- **`install.sh` default flow resilience** — `./install.sh` now gracefully continues when MCP setup fails (for example, missing/old Node.js), prints an explicit "MCP setup skipped" message, and gives a direct re-run command for `setup-mcp` instead of aborting midway under strict shell mode.
- **`install.sh` shell-config rewrite safety** — PATH block cleanup now writes back to the existing shell config file in place instead of replacing it via `mv`, preserving inode-level metadata such as ownership/permissions behavior.

### Changed
- **`install.sh` preflight messaging** — Node.js preflight output now includes explicit advisory text that MCP will be skipped in default setup when Node is missing or below the required floor.
- **`install.sh` UX copy updates** — help text for default command now reflects full setup behavior, next-step block removes redundant status rerun guidance, and top script header no longer references a non-existent section number.

## [1.2.1] - 2026-03-24

### Changed
- **`install.sh` default flow** — running `./install.sh` now executes a full safe setup sequence (`install_path`, `setup-wpcc`, `setup-mcp`) with idempotent step behavior and a preflight summary before mutations.
- **`install.sh` shell config writing** — PATH management now uses explicit begin/end markers (`# >>> AI-DDTK >>>` / `# <<< AI-DDTK <<<`) and block replacement instead of fragile line-by-line grep/sed insertion.
- **`install.sh status` diagnostics** — status now includes doctor-style checks for `wpcc` PATH resolvability and Node.js version-floor compliance (`>= 18`) in addition to existing installation checks.
- **Install script maintainability** — moved long agent-oriented notes out of script comments into `docs/INSTALL-AGENT-NOTES.md` and left a short pointer in `install.sh`.

### Fixed
- **`install.sh setup-mcp` correctness** — enforces Node.js `>= 18` before MCP setup and now surfaces npm install/build failures directly instead of potentially reporting false success on piped output.
- **`install.sh` next-step output** — completion guidance now prints as a copy/paste-ready command block.

## [1.2.0] - 2026-03-23

### Added
- **`ai-ddtk/update-options` MCP ability (Phase 3)** — writes WordPress options via `update_option()` (sanitization callbacks fire) with a two-tier safety model: `active_plugins` and `active_sitewide_plugins` are always refused; `siteurl`, `home`, `template`, `stylesheet`, and `admin_email` require `confirm_dangerous: true`. Dangerous-key overrides are written to PHP `error_log` with user ID and timestamp for audit. Returns per-key results with `previous_value`, `new_value`, and `changed` flag. Supports `redact_values: true` to prevent secrets from leaking into MCP transcripts or agent context. Blocklist is filterable via `ai_ddtk_options_blocklist`.

## [1.1.0] - 2026-03-23

### Added
- **Repo-level PHPStan setup** — added a root `composer.json` for PHP static-analysis dependencies and a focused `phpstan.neon` that targets AI-DDTK's first-party WordPress PHP files under `templates/` and `tools/qm-bridge/` while excluding vendored/generated subtrees.
- **Local MCP workflow helpers** — added `.mcp.local.example.json`, `examples/mcp/local-snippet.example.json`, and a new `bin/mcp-local-config` helper for merging the checked-in generic `.mcp.json` with local-only snippets from `temp/mcp/local-snippets/`. The helper now supports guarded root writes, dry-run previews, and tracked `temp/mcp/local-snippets/` plus `temp/mcp/notes/` scaffolds for fresh clones.
- **Valet clone helper script** — added `tools/valet-site-copy.sh` as a canonical optional helper for Valet clone-lab workflows with `clone` and `teardown` commands, `~/Valet-Sites` defaults, `valet_` database naming, and explicit `--dbhost=127.0.0.1`-aligned behavior for local MySQL operations.

### Fixed
- **`wp-ajax-test` authenticated nonce fetch hardening** — custom `--nonce-url` values now must resolve to the same origin as `--url`, and nonce fetch redirects are followed manually only when they stay on the same origin. This prevents authenticated WordPress cookies from being forwarded to arbitrary external hosts during nonce discovery.
- **`wp-ajax-test` nonce field parsing hardening** — custom `--nonce-field` values no longer flow unescaped into Cheerio selectors or dynamically constructed regular expressions. The tool now compares input names directly and escapes the regex variant before matching inline script content.
- **`wp-ajax-test` cookie and `--nopriv` handling** — cookie values from `Set-Cookie` headers are now preserved intact even when they contain `=` characters, and `--nopriv` now means an actual unauthenticated request flow by skipping auth loading and nonce discovery instead of acting as a no-op flag.
- **`bin/mcp-local-config` snippet validation** — local MCP snippets are now validated per server entry so malformed values fail fast with a direct error when a server entry is not an object or is missing the required `command` field.
- **Query Monitor MCP TLS verification scope** — the QM handler now disables HTTPS certificate verification only for explicit local-development hosts (`localhost`, `127.0.0.1`, `::1`, `*.local`, `*.test`) instead of all HTTPS targets.

### Changed
- **Valet clone-lab documentation now points to helper script** — updated `recipes/valet-clone-lab.md`, `README.md`, `AGENTS.md`, and `docs/CLI-REFERENCE.md` to treat `tools/valet-site-copy.sh` as the canonical optional entry point for Valet clone creation/teardown.

## [1.1.0-rc.1] - 2026-03-22

### Added
- **Phase 7 — Query Monitor frontend page profiling** — 3 new MCP tools (`qm_profile_page`, `qm_slow_queries`, `qm_duplicate_queries`) that profile any WordPress page via a QM bridge mu-plugin. The bridge captures QM's 6 raw JSON collectors (db_queries, cache, http, logger, conditionals, transients) plus overview timing/memory at shutdown, stores in a transient, and exposes a REST retrieval endpoint. Profiles are persisted to `temp/qm-profiles/<domain>_<timestamp>.json`.
- **Hypercart Performance Timer integration** — the QM bridge automatically detects the [Hypercart Performance Timer plugin](https://github.com/Hypercart-Dev-Tools/hypercart-wp-performance-timer-plugin) (currently private, planned for public OSS release) and includes its hierarchical timer stats, hierarchy tree, and environment data in profile output as `perf_timers`. This gives a single profile result with both QM's automatic discovery (queries, cache, HTTP calls) and targeted instrumentation (per-callback timing, parent/child hierarchy). No changes required to the performance timer plugin.
- **QM bridge mu-plugin** (`tools/qm-bridge/ai-ddtk-qm-bridge.php`) — thin WordPress mu-plugin for QM data capture. Uses QM's own cookie verification for REST auth, supports profile nonce headers for on-demand capture.
- **Test delays fixture plugin** (`tools/qm-bridge/ai-ddtk-test-delays.php`) — mu-plugin with 4 simulated delay types (SELECT SLEEP, external HTTP via httpbin, CPU-bound md5 loop, N+1 get_post_meta pattern) for validating QM profiling. Triggered via `?aiddtk_test_delays=1` query param or `[aiddtk_test_delays]` shortcode.
- **pw-auth cookie extraction** — `getCookiesForSite(user, domain)` method on the pw-auth handler, enabling cross-handler cookie sharing without exposing storageState internals.
- **GitHub Actions CI for MCP server** (`.github/workflows/ci-mcp-server.yml`) — runs build + tests on Node 18/20/22 for pushes and PRs touching `tools/mcp-server/`.
- **MCP Adapter Phase 1 & 2 — 12 abilities implemented and validated** — all content CRUD and introspection abilities are live in `templates/ai-ddtk-abilities.php` and validated end-to-end on a WP 6.9.4 Local test site. Phase 1 abilities: `create-post`, `update-post`, `list-posts`, `delete-post`, `manage-taxonomy` (create/assign/list), `batch-create-posts`, `batch-update-posts`. Phase 2 abilities: `get-options`, `list-post-types`, `list-registered-blocks`, `get-active-theme`, `list-plugins`.
- **`docs/MCP-ADAPTER-SETUP.md`** — new step-by-step setup guide covering Composer install, nested autoloader workaround, mu-plugin deployment, `.mcp.json` dual-server config, known bugs, and verification checklist. Based on a real LocalWP provisioning session.
- **MCP Adapter local provisioning pattern documented** — `wordpress/mcp-adapter` v0.4.1 setup, abilities mu-plugin deployment, and the site-specific `.mcp.json` server entry pattern were validated and documented for LocalWP use. Requires Claude Code restart to activate after adding a local adapter server.
- **Optional Valet clone-lab recipe** — added `recipes/valet-clone-lab.md` as a macOS-focused, experimental workflow for rapid throwaway WordPress cloning/testing with explicit scope and safety guardrails. This path is documented as optional and not part of the core AI-DDTK toolset.
- **Phase 2.5: README Consolidation & AGENTS.md Expansion** — established `AGENTS.md` as the single source of truth for AI development guidelines; moved detailed pw-auth, WPCC, and troubleshooting content from `README.md` into `AGENTS.md`. Added new Navigation table to `README.md` with direct section links into `AGENTS.md`.
- **P1-WP-MCP-ADAPTER.md project specification** — added comprehensive 6-phase implementation plan for integrating the official WordPress MCP Adapter with AI-DDTK. Includes Phase 0 technical spike results, real-world scenarios, prerequisites, and integration patterns for Local by Flywheel and Valet clone-lab environments.

### Changed
- **Public-safe MCP defaults** — the checked-in `.mcp.json` now ships with the generic single-server AI-DDTK configuration, and the companion MCP docs replace the previously committed LocalWP site-specific adapter example with generic wording and placeholder guidance.
- **MCP repo-hygiene guidance** — added explicit reminders in the MCP companion/setup docs to avoid committing real site names, internal domains, local paths, user IDs, tokens, or auth artifacts, and documented `temp/mcp/` as the place for local-only MCP snippets and notes.
- **Phase 0 Technical Spike (WP MCP Adapter) — COMPLETE** — all 5 sub-phases validated. Dual-server `.mcp.json` config works (AI-DDTK 18 tools + WP MCP Adapter 3 tools, zero collisions). Valet clone-lab validated with system Composer/WP-CLI. Discovered three mu-plugin registration requirements: correct hook (`wp_abilities_api_init`), required `category` field, and `meta.mcp.public` flag. Custom ability end-to-end verified on both Local and Valet. Added `.mcp.README.md` companion doc for dual-server config reference.
- **MCP server TypeScript comment quality** — added focused TSDoc to the LocalWP, pw-auth, and WPCC handler layers so exported factories and non-obvious helper behavior are documented consistently with the stronger JSDoc/PHPDoc style already present in the JS and PHP tooling.
- **README simplified to lightweight hub (~150 lines)** — removed verbose pw-auth, troubleshooting, and WPCC-templates sections; replaced with a Navigation table pointing into `AGENTS.md` for all detailed guidance. All content moved, not deleted.
- **AGENTS.md expanded to comprehensive SOT (~600 lines)** — added full pw-auth prerequisites/setup/usage/troubleshooting, WPCC project templates and features table, and a new `🔧 Troubleshooting` section covering CLI, IDE, WPCC scanning, pw-auth, and MCP issues.
- **README optional workflows section** — added an "Optional Workflows" section in `README.md` linking to the Valet clone-lab recipe and clarifying that it complements, not replaces, Local WP.
- **Planning dashboard tracking** — added a current-week checklist item in `4X4.md` to track Valet clone-lab formalization as an optional path without promoting it to core.
- **AGENTS optional recipe cross-link** — added a short optional-workflow note in `AGENTS.md` pointing agents to `recipes/valet-clone-lab.md` for macOS throwaway clone/testing scenarios.
- **`install.sh` MCP/bootstrap refresh** — `setup-mcp` now prints launcher-based config that uses `tools/mcp-server/start.sh`, `status` reports launcher readiness when `dist/` is missing, `update` now follows the current branch/upstream with `--ff-only` instead of hardcoding `main`, and first-run next steps now surface `setup-mcp`.
- **Experimental `theme-crash-loop.sh` evidence upgrade** — the crash-loop helper now defaults to the canonical `bin/local-wp` wrapper, supports repeatable extra probe URLs and configurable curl timeouts, writes machine-readable probe artifacts (`probes.tsv`, `probes.jsonl`, `run.json`), snapshots theme state per phase, and classifies probes using multiple signals (HTTP status, redirects, login gates, fatal/WP-die/db-error pages) instead of raw `curl` metrics alone.
- **Experimental `theme-crash-loop.sh` segmentation fault detection** — added segmentation fault detection patterns (`segmentation fault`, `segfault`, `core dumped`) to the log scanning logic in `scan_log_delta()` so PHP-FPM segfaults that leave log trails are now caught and counted as alert events.
- **Version updates** — README.md and AGENTS.md updated to `1.0.44`.

### Fixed
- **`get-active-theme` ability with empty parameters** — no-parameter abilities must omit `input_schema` from `wp_register_ability()`. The previous `'properties' => new stdClass()` pattern caused two bugs in MCP Adapter v0.4.1: (1) `ExecuteAbilityAbility` uses `empty($input['parameters'])` which coerces `{}` (decoded as `[]`) to `null`, then `rest_validate_value_from_schema(null, type:object)` fails; (2) when any parameter is passed, `$schema['properties'][$key]` on a `stdClass` throws `"Cannot use object of type stdClass as array"`. Fixed by removing `input_schema` from `get-active-theme` — WP core correctly handles `null` input when no schema is defined.
- **MCP server startup crash loop** — `dist/` is gitignored so the MCP server failed to start after a fresh clone or checkout, causing VS Code to restart it in a loop. Added `tools/mcp-server/start.sh` launcher that auto-builds TypeScript when `dist/` is missing, and updated `.mcp.json` to use it.

## [1.0.43] - 2026-03-13

### Added
- **`LOCAL_WP_MEMORY_LIMIT` env var** — `bin/local-wp` now writes `memory_limit` into the temp PHP ini it creates, defaulting to `512M`. Set `LOCAL_WP_MEMORY_LIMIT` to override. Fixes OOM failures on heavy sites (e.g. MacNerd Production) that hit the 128M default when the system `php.ini` is bypassed by `-c`.

### Changed
- **Version updates**
  - README.md updated to `1.0.43`
  - install.sh updated to `1.0.43`

### Fixed
- **`local-wp` modern Local run discovery** — updated the shell wrapper to resolve current Local runtime layouts by matching nested `conf/**` content such as site root paths and `*.local` hostnames, added `--debug` discovery tracing, and preferred active MySQL sockets when stale run directories also match.
- **LocalWP MCP parity** — updated `tools/mcp-server/src/handlers/local-wp.ts` to use the same modern nested-config discovery signals and active-socket preference so MCP-backed LocalWP workflows stay aligned with the shell wrapper.
- **Regression coverage** — extended shell and MCP LocalWP tests to cover modern `conf/nginx/site.conf` layouts and stale-versus-active run selection.

## [1.0.40] - 2026-03-11

### Changed
- **AGENTS.md concise refresh** — shortened and reorganized `AGENTS.md` to reduce duplication across MCP, tmux, Playwright, WPCC, performance, PHPStan, and architecture guidance while keeping the existing AI-DDTK availability check intact.
- **Capability-discovery guidance** — added a concise startup workflow for agents to inventory MCP tools/resources plus shell-based AI-DDTK commands once per session and prefer MCP tools when both surfaces exist.
- **Playwright / MCP guidance refresh** — updated `AGENTS.md` to reflect current `pw-auth doctor`, `pw-auth check dom`, LocalWP wrapper usage, auth artifact paths, and the fact that `tmux_send` is intentionally allowlisted rather than a general shell bridge.
- **Version updates**
  - README.md updated to `1.0.40`
  - install.sh updated to `1.0.40`

## [1.0.39] - 2026-03-10

### Changed
- **Phase 2 real-environment validation** — ran `pw-auth check dom` successfully against `https://site-uclasacto.local/wp-admin/` using cached auth for `neochrome_jose`, extracted `#wpadminbar` HTML, and confirmed structured artifacts under `temp/playwright/checks/20260310T035036Z-5586/` with exit code `0`.
- **Playwright project tracking** — updated `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` to record the successful real-world Phase 2 admin-surface validation while intentionally leaving the broader Phase 2 pause/review gate open for a widget-area-specific need check.
- **Playwright README note** — updated `README.md` to note the successful real-environment `pw-auth check dom` validation against `site-uclasacto.local`.
- **Version updates**
  - README.md updated to `1.0.39`
  - install.sh updated to `1.0.39`

## [1.0.38] - 2026-03-10

### Added
- **Phase 2 DOM inspection MVP (`pw-auth check dom`)** — added the first authenticated inspection slice to `bin/pw-auth`, including `exists` / `text` / `html` extraction, inferred auth origin from `--url`, structured artifact output under `temp/playwright/checks/<run-id>/`, JSON/text output modes, and exit semantics for success, selector failure, auth-required, and runtime failure paths.
- **Phase 2 regression coverage** — extended `test/test-wrapper-cleanup.sh` with focused shell tests for successful DOM extraction artifact writing and selector-failure exit handling using lightweight fake `node` stubs.

### Changed
- **Transcript artifact hygiene** — removed the stray root-level `typescript` transcript artifact and added conservative `.gitignore` protection for root-level `script(1)` transcript files (`/typescript` and `/typescript.[0-9]*`).
- **Playwright project tracking** — updated `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` to mark the implemented Phase 2 MVP checklist items complete and record the current state of the first CLI inspection slice.
- **Playwright README note** — updated `README.md` usage/docs to include the new `pw-auth check dom` command and its default artifact behavior.
- **Version updates**
  - README.md updated to `1.0.38`
  - install.sh updated to `1.0.38`

## [1.0.37] - 2026-03-10

### Changed
- **Playwright Phase 1 validation gate completed** — updated `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` to record the second successful real-environment validation on `site-uclasacto.local`, mark the Phase 1 stop/check gate complete at the 2-environment minimum, and note the `aiddtk-tmux` fallback used to work around flaky IDE terminal capture.
- **Playwright README note** — updated `README.md` to note that `aiddtk-tmux` is a proven fallback when `pw-auth` needs to run through unreliable IDE terminal transports.
- **Version updates**
  - README.md updated to `1.0.37`
  - install.sh updated to `1.0.37`

## [1.0.36] - 2026-03-10

### Changed
- **Playwright Phase 1 validation tracking** — updated `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` to record a successful real-environment end-to-end validation on `macnerd-xyz-09-10.local`, including the production-environment guard, Local wrapper workaround, cached auth path, and the remaining 1–2 environment gate before Phase 2.
- **Playwright README note** — updated `README.md` to note that the global npm-root / `NODE_PATH` Playwright resolution fallback has now been validated on a real Local HTTPS workflow.
- **Version updates**
  - README.md updated to `1.0.36`
  - install.sh updated to `1.0.36`

## [1.0.35] - 2026-03-10

### Added
- **`pw-auth doctor` readiness checks** — added a new `doctor` command to `bin/pw-auth` with human-readable and JSON output, `ready` / `partial` / `blocked` exit semantics, Node/Playwright/browser/WP-CLI/auth checks, and remediation guidance.
- **Playwright doctor regression coverage** — extended `test/test-wrapper-cleanup.sh` with a focused shell regression test for `pw-auth doctor` JSON output using lightweight fake `node` / `wp` stubs.

### Changed
- **Playwright install convenience wrapper** — added `./install.sh doctor-playwright` as a thin delegation layer to the canonical `pw-auth doctor` command.
- **Playwright docs and checklist** — updated `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` and `README.md` to reflect the implemented Phase 1 contract, including the actual JSON shape and convenience wrapper.
- **Version updates**
  - README.md updated to `1.0.35`
  - install.sh updated to `1.0.35`

## [1.0.34] - 2026-03-10

### Changed
- **Playwright plan surface cleanup** — updated `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` to make `pw-auth doctor` the canonical Phase 1 doctor command, move Phase 2 inspection under `pw-auth check`, infer auth origin from `--url` by default, consolidate the planned MCP tool surface, define a declarative preset direction, add write-operation guardrails for category actions, and turn the CLI+MCP split into an explicit architectural decision instead of an open question.
- **Version updates**
  - README.md updated to `1.0.34`
  - install.sh updated to `1.0.34`

## [1.0.33] - 2026-03-10

### Changed
- **Playwright lifecycle guidance** — updated `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` to document Phase 2–3 browser lifecycle strategy: fresh browser/context per check by default for safety and simplicity, with shared-context optimization noted as a future possibility so the wrapper API does not block it.
- **Version updates**
  - README.md updated to `1.0.33`
  - install.sh updated to `1.0.33`

## [1.0.32] - 2026-03-10

### Changed
- **Playwright MVP spec** — updated `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` with exact MVP command/tool specs for Phases 1–2, including proposed command names, arguments, exit codes, JSON output contracts, and first-use examples for authenticated DOM/HTML inspection.
- **Version updates**
  - README.md updated to `1.0.32`
  - install.sh updated to `1.0.32`

## [1.0.31] - 2026-03-10

### Changed
- **Playwright plan rewrite** — rewrote `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` around a more practical delivery sequence: Phase 1 readiness/auth foundation, Phase 2 authenticated DOM/HTML inspection MVP, Phase 3 MCP agent access, Phase 4 WordPress presets and safe admin actions (including categories), and Phase 5 optional guarded custom flows. The plan now treats screenshots as a later enhancement rather than an MVP requirement.
- **Version updates**
  - README.md updated to `1.0.31`
  - install.sh updated to `1.0.31`

## [1.0.30] - 2026-03-10

### Changed
- **Playwright plan refinement** — updated `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` to clarify the difference between current `pw-auth`-centered Playwright support and the planned robust browser-check layer, and tightened the Goals section to be more concise while staying implementation-oriented.
- **Version updates**
  - README.md updated to `1.0.30`
  - install.sh updated to `1.0.30`

## [1.0.29] - 2026-03-10

### Added
- **Playwright planning doc** — added `PROJECT/1-INBOX/P1-PLAYWRIGHT.md` with a phased plan for more robust Playwright support/integration covering runtime doctor/setup, structured browser checks, MCP browser tools, WordPress-specific presets, and guarded programmable checks.

### Changed
- **Version updates**
  - README.md updated to `1.0.29`
  - install.sh updated to `1.0.29`

## [1.0.28] - 2026-03-09

### Changed
- **MCP README wording polish** — refined `tools/mcp-server/README.md` phrasing for clarity and consistency around Node.js dependencies, stdio launch wording, WP-DB-Toolkit wording, and `--force` usage.
- **Version updates**
  - README.md updated to `1.0.28`
  - install.sh updated to `1.0.28`
  - `tools/mcp-server/src/index.ts` updated to `0.6.2`
  - `tools/mcp-server/package.json` updated to `0.6.2`

## [1.0.27] - 2026-03-09

### Added
- **Phase 6 MCP documentation** — added `tools/mcp-server/README.md` with concise setup, client config, tool/resource catalog, usage pattern, and troubleshooting guidance.

### Changed
- **Root onboarding docs** — `README.md` now includes a short MCP server quick-start section and a reference to the external WP-DB-Toolkit MCP server for database-query workflows outside direct MySQL access.
- **Agent guidance** — `AGENTS.md` now includes concise MCP usage patterns, example prompts, and failure-mode guidance.
- **Project tracking** — `PROJECT/1-INBOX/P1-MCP-SERVER.md` now marks Phase 6 complete and `PROJECT/1-INBOX/ROADMAP-PERPLEXITY.md` now marks roadmap item #6 complete.
- **Version updates**
  - README.md updated to `1.0.27`
  - install.sh updated to `1.0.27`
  - `tools/mcp-server/src/index.ts` updated to `0.6.1`
  - `tools/mcp-server/package.json` updated to `0.6.1`

## [1.0.26] - 2026-03-09

### Added
- **Phase 5 VS Code integration & HTTP/SSE transport** — MCP server now supports secure localhost-only HTTP transport via `--http` flag with bearer token authentication (token stored in `~/.ai-ddtk/mcp-token`), using the MCP SDK's `StreamableHTTPServerTransport` with per-session state isolation.
- **Per-session active-site context** — added `SessionStore` class in `tools/mcp-server/src/state.ts` so HTTP/SSE sessions each get isolated `SiteState` with no cross-client contamination.
- **Bearer token management** — added `tools/mcp-server/src/utils/token.ts` for automatic token generation and persistence in `~/.ai-ddtk/mcp-token`.
- **Repo-tracked VS Code integration** — added `.vscode/tasks.json` (MCP build/test/start, WPCC scan, pw-auth login, AJAX test) and `.vscode/launch.json` (stdio debug, HTTP debug, test debug) with `.gitignore` updated to whitelist these files.
- **MCP client config files** — added `.mcp.json` for Claude Code auto-discovery, plus reference configs for Claude Desktop and Cline in `tools/mcp-server/mcp-configs/`.
- **`install.sh setup-mcp` command** — builds the MCP server, installs dependencies, and prints client configuration snippets for Claude Code, Claude Desktop, Cline, and HTTP mode.
- **Phase 5 regression tests** — added `tools/mcp-server/test/phase5.test.ts` covering `SessionStore` isolation, bearer token auth rejection, localhost-only binding, and server factory validation.

### Changed
- **MCP server HTTP mode** — `tools/mcp-server/src/index.ts` now accepts `--http` and `--port=N` CLI flags (default port 3100) to start a Streamable HTTP server bound to `127.0.0.1` with mandatory bearer token auth on every request.
- **Version updates**
  - README.md updated to `1.0.26`
  - install.sh updated to `1.0.26`
  - `tools/mcp-server/src/index.ts` updated to `0.6.0`
  - `tools/mcp-server/package.json` updated to `0.6.0`

## [1.0.25] - 2026-03-09

### Changed
- **Phase 4 pre-merge tmux hardening** — `tools/mcp-server/src/security/allowlist.ts` now narrows `tmux_send` to validated repo-relative `wpcc` invocations only, removes direct read-command passthrough, rejects `${...}` shell expansion syntax, and blocks unsafe `wpcc --paths` values such as absolute or out-of-workspace paths.
- **AJAX URL scheme hardening** — `tools/mcp-server/src/index.ts` and `tools/mcp-server/src/handlers/wp-ajax-test.ts` now reject non-HTTP(S) URLs so `wp_ajax_test` cannot be used with `file://`, `ftp://`, or similar schemes.
- **tmux parsing safety** — `tools/mcp-server/src/handlers/tmux.ts` now escapes `extractField()` labels before building a `RegExp`.
- **Regression coverage** — `tools/mcp-server/test/tmux.test.ts` and `tools/mcp-server/test/wp-ajax-test.test.ts` now cover repo-relative `wpcc --paths` validation, blocked read commands, blocked `${...}` expansion, non-HTTP(S) AJAX URLs, and exit-0 non-JSON wrapper output.
- **Version updates**
  - README.md updated to `1.0.25`
  - install.sh updated to `1.0.25`
  - `tools/mcp-server/src/index.ts` updated to `0.5.1`
  - `tools/mcp-server/package.json` updated to `0.5.1`

## [1.0.24] - 2026-03-09

### Added
- **AI-DDTK MCP server Phase 4 tools** — added `wp_ajax_test`, `tmux_start`, `tmux_send`, `tmux_capture`, `tmux_stop`, `tmux_list`, and `tmux_status` to `tools/mcp-server/src/index.ts` with dedicated handlers in `src/handlers/wp-ajax-test.ts` and `src/handlers/tmux.ts`.
- **Phase 4 regression coverage** — added `tools/mcp-server/test/wp-ajax-test.test.ts` and `tools/mcp-server/test/tmux.test.ts` for JSON parsing, tmux session normalization, allowlist enforcement, wrapper output parsing, and non-zero exit preservation.

### Changed
- **tmux command hardening** — `tools/mcp-server/src/security/allowlist.ts` now enforces a Phase 4 tmux command allowlist for `wpcc`, `pw-auth`, `local-wp`, `wp-ajax-test`, and safe read commands while rejecting blocked executables and shell control operators.
- **Phase 4 project tracking** — `PROJECT/1-INBOX/P1-MCP-SERVER.md` now marks Phase 4 complete, fixes the earlier `wp_ajax_test` checklist wording from explicit `site` to explicit `url`, and documents the concrete implementation files.
- **Version updates**
  - README.md updated to `1.0.24`
  - install.sh updated to `1.0.24`
  - `tools/mcp-server/src/index.ts` updated to `0.5.0`
  - `tools/mcp-server/package.json` updated to `0.5.0`

## [1.0.23] - 2026-03-09

### Changed
- **Phase 3 auth contract clarity** — `tools/mcp-server/src/handlers/pw-auth.ts` now returns `cacheFreshUntil` from `pw_auth_login` instead of `expiresAt` so MCP callers do not confuse cache freshness with the real WordPress session lifetime.
- **Reduced missing-user auth resource disclosure** — `auth://status/{user}` still returns a stable `missing` payload, but missing-user reads no longer expose synthesized auth file paths.
- **Documented authoritative pw-auth status fields** — `tools/mcp-server/src/handlers/pw-auth.ts`, `tools/mcp-server/src/index.ts`, and `PROJECT/1-INBOX/P1-MCP-SERVER.md` now clarify that structured `users[]` metadata is authoritative while `rawText` remains informational/debug passthrough from `bin/pw-auth status`.
- **Version updates**
  - README.md updated to `1.0.23`
  - install.sh updated to `1.0.23`
  - `tools/mcp-server/src/index.ts` updated to `0.4.1`
  - `tools/mcp-server/package.json` updated to `0.4.1`

## [1.0.22] - 2026-03-09

### Added
- **AI-DDTK MCP server Phase 3 pw-auth support** — added `pw_auth_login`, `pw_auth_status`, and `pw_auth_clear` to `tools/mcp-server/` so MCP clients can authenticate Playwright sessions, inspect auth-cache metadata, and clear one explicit user's cached auth safely.
- **Auth metadata MCP resource** — added `auth://status/{user}` with metadata-only responses from `tools/mcp-server/src/handlers/pw-auth.ts`, intentionally excluding raw Playwright `storageState`, cookies, and tokens.
- **Phase 3 regression coverage** — added `tools/mcp-server/test/pw-auth.test.ts` for retry-on-timeout login behavior, safe `--wp-cli` prefix construction, explicit-user clear semantics, and metadata-only auth resource reads.

### Changed
- **MCP server registration** — `tools/mcp-server/src/index.ts` now registers the Phase 3 `pw-auth` tools/resource and bumps the MCP server version to `0.4.0`.
- **Phase 3 project tracking** — `PROJECT/1-INBOX/P1-MCP-SERVER.md` now marks all Phase 3 checklist items complete and updates the `pw_auth_clear` contract to explicit-user-only deletion.
- **Version updates**
  - README.md updated to `1.0.22`
  - install.sh updated to `1.0.22`
  - `tools/mcp-server/package.json` updated to `0.4.0`

## [1.0.21] - 2026-03-09

### Fixed
- **MCP allowlisted `db query` hardening** — `tools/mcp-server/src/security/allowlist.ts` now rejects semicolon-delimited SQL so Phase 1/2 `db query` calls stay limited to single `SELECT` statements.
- **`wpcc_run_scan` path validation** — `tools/mcp-server/src/handlers/wpcc.ts` now rejects empty path entries and any comma-separated `--paths` entry that begins with `-`, preventing flag-shaped argument injection into `bin/wpcc`.

### Changed
- **MCP resource error handling** — `tools/mcp-server/src/index.ts` now normalizes WPCC resource/list callback failures through a small wrapper so resource errors are surfaced consistently with sanitized messages.
- **Package-root assumption documentation** — added an inline note in `tools/mcp-server/src/index.ts` clarifying the expected `src/` vs `dist/src/` layout used to derive `packageRoot` and `repoRoot`.
- **Hardening regression coverage** — extended `tools/mcp-server/test/local-wp.test.ts` and `tools/mcp-server/test/wpcc.test.ts` for semicolon-rejected SQL and flag-shaped WPCC path input.
- **Version updates**
  - README.md updated to `1.0.21`
  - install.sh updated to `1.0.21`
  - `tools/mcp-server/package.json` updated to `0.3.1`

## [1.0.20] - 2026-03-08

### Added
- **AI-DDTK MCP server Phase 2 WPCC resources** — added `wpcc://latest-scan`, `wpcc://latest-report`, and templated `wpcc://scan/{id}` resources to the unified `tools/mcp-server/` package so MCP clients can list and read WP Code Check artifacts directly
- **WPCC resource regression coverage** — added targeted tests for latest scan/report resolution, specific scan reads, missing-artifact handling, and recent-scan listing limits in `tools/mcp-server/test/wpcc.test.ts`

### Changed
- **WPCC legacy MCP entrypoint** — `tools/wp-code-check/dist/bin/mcp-server.js` now acts as a compatibility shim that forwards to `tools/mcp-server/dist/src/index.js` and emits a deprecation warning
- **Phase 2 MCP validation** — verified the unified server with `npm test` in `tools/mcp-server` plus a live stdio MCP smoke check covering `listResources` and real `readResource(...)` calls for latest scan/report and a specific scan artifact
- **Backlog cleanup** — removed the completed WPCC MCP server follow-up item from `tools/wp-code-check/PROJECT/2-WORKING/BACKLOG.md`
- **Version updates**
  - README.md updated to `1.0.20`
  - install.sh updated to `1.0.20`
  - `tools/mcp-server/package.json` updated to `0.3.0`

## [1.0.19] - 2026-03-08

### Added
- **AI-DDTK MCP server Phase 2 WPCC tool slice** — added `wpcc_list_features` and `wpcc_run_scan` to `tools/mcp-server/` so the unified MCP server can expose WP Code Check capabilities and invoke scans through `bin/wpcc`
- **WPCC MCP regression coverage** — added targeted tests for feature parsing, JSON log-file parsing, text-mode passthrough, and non-zero exit handling in `tools/mcp-server/test/wpcc.test.ts`

### Changed
- **WPCC JSON scan handling** — `wpcc_run_scan` now treats the JSON log written to `tools/wp-code-check/dist/logs/` as the authoritative scan artifact instead of trusting mixed stdout from `bin/wpcc`
- **Version updates**
  - README.md updated to `1.0.19`
  - install.sh updated to `1.0.19`
  - `tools/mcp-server/package.json` updated to `0.2.0`

## [1.0.18] - 2026-03-08

### Added
- **AI-DDTK MCP server Phase 1 scaffold** — added `tools/mcp-server/` as a standalone TypeScript MCP package with stdio transport, MCP SDK tool registration, in-memory active-site state, WP-CLI allowlist enforcement, and a safe `execFile` wrapper
- **LocalWP MCP tool suite** — added `local_wp_list_sites`, `local_wp_select_site`, `local_wp_get_active_site`, `local_wp_test_connectivity`, `local_wp_get_site_info`, and allowlisted `local_wp_run`
- **Targeted MCP validation** — added `tools/mcp-server/test/local-wp.test.ts` coverage for allowlist enforcement, active-site read-only fallback, site-info parsing, wrapper error handling, and server creation

### Changed
- **Version updates**
  - README.md updated to `1.0.18`
  - install.sh updated to `1.0.18`
- **MCP package metadata** — `tools/mcp-server/package.json` now declares a direct `zod` dependency and the npm lockfile metadata has been refreshed for `ai-ddtk-mcp`

## [1.0.17] - 2026-03-08

### Changed
- **Version updates**
  - README.md updated to `1.0.17`
  - install.sh updated to `1.0.17`

### Fixed
- **Dev Login mu-plugin request host validation** — `templates/dev-login-cli.php` now normalizes and validates the incoming request host (`HTTP_HOST` / `SERVER_NAME`) during one-time login redemption instead of trusting only the configured `home_url()` host
- **`bin/local-wp` Local run resolution** — the wrapper now exact-matches Local site names across run config files and fails clearly if multiple exact matches exist instead of taking the first substring match
- **`bin/local-wp` temporary PHP ini handling** — the wrapper now creates a unique `mktemp`-based PHP ini file with restrictive permissions instead of reusing a predictable shared path in `/tmp`
- **Regression coverage** — `test/test-wrapper-cleanup.sh` now covers request-host normalization for the dev-login template plus the real `site` vs `site-old` Local config collision case and unique temp-ini cleanup

## [1.0.16] - 2026-03-07

### Added
- **Wrapper cleanup regression harness** — added `test/test-wrapper-cleanup.sh` to exercise `bin/local-wp` fixed-string lookup/temp-ini cleanup and `bin/pw-auth` temp-file cleanup on failure paths using lightweight shell stubs

### Changed
- **Installation test coverage** — `test/test-install.sh` now runs the wrapper cleanup harness as part of the existing test suite
- **Docker test image** — `test/Dockerfile` now installs `python3` so the wrapper cleanup harness can create temporary UNIX sockets during test runs
- **Version updates**
  - README.md updated to `1.0.16`
  - install.sh updated to `1.0.16`
  - AGENTS.md updated to `v2.7.8`

## [1.0.15] - 2026-03-07

### Changed
- **Version updates**
  - README.md updated to `1.0.15`
  - install.sh updated to `1.0.15`
  - AGENTS.md updated to `v2.7.7`
- **`bin/local-wp` cleanup behavior** now removes its temporary PHP ini file even when the wrapped WP-CLI command exits with an error
- **`bin/local-wp` Local config lookup** now uses fixed-string matching for site names when resolving the Local run directory
- **`bin/pw-auth` temp file handling** now tracks temporary files with cleanup traps, preserves cleanup on Playwright failure/interruption paths, and avoids empty-array cleanup errors on macOS Bash

## [1.0.14] - 2026-03-07

### Changed
- **Version updates**
  - README.md updated to `1.0.14`
  - install.sh updated to `1.0.14`
  - AGENTS.md updated to `v2.7.6`
- **Repo-root `./local-wp` shim** now emits a deprecation notice directing callers to `local-wp` on `PATH` or `bin/local-wp`

## [1.0.13] - 2026-03-07

### Changed
- **Version updates**
  - README.md updated to `1.0.13`
  - install.sh updated to `1.0.13`
  - AGENTS.md updated to `v2.7.5`
- **`local-wp` installation layout** now makes `bin/local-wp` the canonical installed wrapper while preserving the repo-root `./local-wp` as a temporary compatibility shim during migration
- **Install and usage docs** now describe `local-wp` as a `bin/` command exposed on `PATH`

### Added
- **`bin/local-wp`** as the canonical Local by Flywheel WP-CLI wrapper entry point

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
