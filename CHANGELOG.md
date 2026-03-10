# Changelog

All notable changes to AI-DDTK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
