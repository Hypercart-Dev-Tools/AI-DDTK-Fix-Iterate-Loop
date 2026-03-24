# AI-DDTK — AI-Driven Development Toolkit for WordPress

> **Ship safer, faster WordPress code — with AI agents doing the heavy lifting.**

AI-DDTK is a unified toolkit that gives AI coding agents (Claude Code, Augment, Cline, Cursor, Codex) deep WordPress superpowers: static analysis, browser automation, runtime profiling, content scaffolding, and autonomous fix-iterate workflows — all orchestrated through a single MCP server.

```
Scan → Triage → Fix → Verify → Ship
```

---

## Core Features

### WP Code Check (WPCC) — 54-Pattern Static Scanner

Catch security holes and performance killers before they reach production.

```bash
wpcc --paths ./my-plugin --format json
```

- **Security**: eval injection, hardcoded credentials, missing nonce checks, shell exec, SQL injection vectors
- **Performance**: N+1 queries in loops, unbounded `posts_per_page`, `ORDER BY RAND()`, missing HTTP timeouts
- **WooCommerce**: coupon logic in thank-you pages, smart coupon performance traps
- **Headless/GraphQL**: missing error handling, Next.js revalidation gaps, API key exposure
- **Node.js**: command injection, path traversal, eval patterns
- **AI triage**: Agent reviews findings, filters false positives, outputs structured JSON with confidence scores

### Playwright Auth (pw-auth) — Passwordless WordPress Login

Authenticate headless browsers against wp-admin in one command. No stored passwords.

```bash
pw-auth login --site-url http://my-site.local --site my-site
pw-auth status
pw-auth check dom --url http://my-site.local/wp-admin/
```

- One-time login URLs via WP-CLI (expire in 5 minutes, deleted after use)
- 12-hour session caching with live validation before reuse
- Blocks production-detected sites (`WP_ENVIRONMENT_TYPE`)
- DOM inspection writes structured artifacts for AI agents to analyze

### Query Monitor Profiling — Headless Performance Analysis

Profile any WordPress page without opening a browser. Get database queries, cache stats, HTTP calls, and timing data through MCP.

- **`qm_profile_page`** — Full page profile with all QM collectors
- **`qm_slow_queries`** — Filter queries above a threshold (default 50ms)
- **`qm_duplicate_queries`** — Detect N+1 patterns automatically
- Auto-integrates with Hypercart Performance Timer for hierarchical callback timing
- Profiles saved to `temp/qm-profiles/` for historical analysis

### WordPress MCP Adapter — API-Level CRUD Without a Browser

12 WordPress Abilities exposed via the official [WordPress MCP Adapter](https://github.com/WordPress/mcp-adapter) (requires WP 6.9+). Fast, typed, schema-validated.

**Content CRUD (Phase 1):**
`create-post` · `update-post` · `list-posts` · `delete-post` · `manage-taxonomy` · `batch-create-posts` · `batch-update-posts`

**Introspection (Phase 2):**
`get-options` · `list-post-types` · `list-registered-blocks` · `get-active-theme` · `list-plugins`

> **When to use which?** Need to *see* the page → pw-auth + Playwright. Need to *read/write data* → MCP Adapter.

### Fix-Iterate Loop — Guardrailed Autonomous Workflows

A formal pattern for AI agents that scan, fix, verify, and iterate — with hard stops to prevent runaway loops.

- **5 failed iterations = mandatory stop**
- **10 total iterations max**
- Confidence tracking between iterations detects wrong-direction drift early
- Meta-reflection checkpoints force agents to verify assumptions before continuing

---

## MCP Server — 18 Tools, One Install

The AI-DDTK MCP server auto-discovers via `.mcp.json` and exposes all tools to your AI agent:

| Group | Tools | What They Do |
|-------|:-----:|---|
| **LocalWP** | 6 | List/select/inspect Local by Flywheel sites, run allowlisted WP-CLI |
| **WPCC** | 2 | Scan code, list features |
| **Playwright Auth** | 3 | Login, check status, clear cache |
| **Query Monitor** | 3 | Profile pages, find slow queries, detect N+1 |
| **AJAX Testing** | 1 | Test `admin-ajax.php` endpoints with structured results |
| **Tmux** | 3 | Persistent terminal sessions for long-running tasks |

Plus **4 MCP resources**: auth status, latest scan, latest report, scan-by-ID.

```bash
# One-time setup
./install.sh setup-mcp
./install.sh status

# That's it — Claude Code auto-discovers the server
```

---

## Quick Start

```bash
# Clone
git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git ~/bin/ai-ddtk
cd ~/bin/ai-ddtk

# Install (adds tools to PATH)
./install.sh
./install.sh setup-wpcc
source ~/.zshrc  # or ~/.bashrc

# Verify
wpcc --help
local-wp --help
./install.sh status
```

**Prerequisites:**

| Requirement | Used By | Install |
|---|---|---|
| **Git** | Core | `brew install git` |
| **Node.js** | WPCC, MCP server | `brew install node` |
| **Python 3** | AI triage, HTML reports | `brew install python3` |
| **WP-CLI** | pw-auth, local-wp, MCP Adapter | [wp-cli.org](https://wp-cli.org/) |
| **Composer** | PHPStan (optional) | `brew install composer` |
| **Playwright** | Browser automation (optional) | `npm install -g playwright` |
| **tmux** | Resilient sessions (optional) | `brew install tmux` |
| **GitHub CLI** | Issue creation (optional) | `brew install gh` |

---

## Everyday Workflows

### Pre-Deploy Code Review
```
wpcc scan → AI triage filters false positives → fix flagged issues → re-scan to confirm
```

### Debug a Slow Page
```
qm_profile_page → identify N+1 queries → fix query → qm_slow_queries to verify
```

### Seed Test Data Fast
```
MCP Adapter batch-create-posts → 100 products in seconds → test → batch-update to trash
```

### Automated Fix Loop
```
WPCC scan → fix finding → verify with pw-auth → iterate (max 5 failures, then stop)
```

### E2E Testing in CI/CD
```
pw-auth login (one-time URL, no secrets) → run Playwright tests → auth state as CI artifact
```

---

## Security Model

AI-DDTK is security-conscious by default:

- **WP-CLI allowlist** — Only read-safe commands through MCP (list, get, SELECT queries). Blocks `eval`, `shell`, `db drop`, `plugin install`, `user delete`
- **SQL guard** — `db query` enforces single SELECT statements; semicolons blocked
- **Tmux allowlist** — Only `wpcc` allowed; all shell operators rejected (`&&`, `|`, `;`, `>`, backticks)
- **No credentials in git** — `temp/` folder for auth, reports, logs (gitignored). `.mcp.json` stays generic
- **Production block** — pw-auth refuses to authenticate against production-detected sites
- **One-time login URLs** — Expire in 5 minutes, deleted after use. No stored passwords

---

## Hidden Gems

Features that aren't obvious on first look — but deliver outsized value once you find them.

### Headless Query Monitor
Most devs think QM is a browser toolbar. AI-DDTK's QM bridge captures profiling data at PHP shutdown and exposes it via REST, so AI agents can profile any page (frontend, admin, POST requests) without opening a browser. Pairs automatically with Hypercart Performance Timer for per-callback hierarchical timing.

### AI Triage Contract
Hidden in `tools/wp-code-check/dist/TEMPLATES/_AI_INSTRUCTIONS.md` — a formal JSON schema that defines how agents must triage scan results. After triage, HTML reports can be regenerated with AI summaries injected at the top, and findings map directly to GitHub issues with checkboxes ready for Jira/Linear export.

### Domain-Specific Pattern Library
The 54 WPCC patterns go far beyond generic linting. WooCommerce coupon performance traps, Next.js revalidation gaps, GraphQL error handling, `localStorage` duplicate key detection, `LIKE` queries with leading wildcards, transients without expiration — patterns that generic linters don't know exist.

### Theme Crash Loop (Experimental)
`experimental/theme-crash-loop.sh` automates crash reproduction by switching between fallback and target themes, probing multiple URLs, detecting PHP-FPM segfaults in logs, and classifying failures by HTTP status, redirects, login gates, and fatal error pages. Outputs machine-readable `probes.tsv`, `probes.jsonl`, and `run.json`.

### Performance Audit Pipeline
The `recipes/performance-audit.md` recipe chains WPCC static analysis with WP Performance Timer runtime profiling. WPCC flags *hypotheses* ("this query might be slow"); runtime profiling *confirms* them. Two-tool pipeline, one workflow.

### PHPStan Baseline Strategy
`recipes/phpstan-wordpress-setup.md` includes an incremental improvement pattern: generate a baseline file to accept all legacy errors, focus only on new issues, fix gradually, regenerate baseline, track progress. Includes a GitHub Actions template with inline PR diff annotations.

### CI/CD Without Secrets
`docs/CI-CD-INTEGRATION.md` shows complete E2E testing in GitHub Actions/GitLab CI using one-time WP-CLI login URLs — no stored WordPress passwords, no credential management. Auth state files become CI artifacts for debugging.

### MCP Config Safety Pattern
`bin/mcp-local-config` merges the generic `.mcp.json` with local-only snippets from `temp/mcp/local-snippets/` (gitignored). Prevents accidental commits of real site names, tokens, and paths. Supports `--dry-run` preview and guarded `--write-root` with explicit confirmation.

### `LOCAL_WP_MEMORY_LIMIT`
Set this env var to override the default 512M PHP memory limit for heavy Local sites. Not in `--help` — documented in the CHANGELOG.

### install.sh Maintenance Commands
Beyond initial setup: `doctor-playwright` (diagnose Playwright issues), `setup-wpcc` / `update-wpcc` (git subtree management), `status` (versions + MCP build status + PATH config).

---

## Documentation

| Topic | Location |
|---|---|
| **AI Agent Guidelines (Source of Truth)** | [AGENTS.md](AGENTS.md) |
| **CLI Commands Reference** | [docs/CLI-REFERENCE.md](docs/CLI-REFERENCE.md) |
| **MCP Server Setup** | [AGENTS.md — MCP Setup](AGENTS.md#mcp-server-setup-and-lifecycle) |
| **WordPress MCP Adapter Setup** | [docs/MCP-ADAPTER-SETUP.md](docs/MCP-ADAPTER-SETUP.md) |
| **MCP Adapter Ability Schemas** | [docs/mcp-adapter-abilities.md](docs/mcp-adapter-abilities.md) |
| **Playwright Auth** | [docs/PW-AUTH-COMMANDS.md](docs/PW-AUTH-COMMANDS.md) |
| **WPCC Commands** | [docs/WPCC-COMMANDS.md](docs/WPCC-COMMANDS.md) |
| **Local WP Commands** | [docs/LOCAL-WP-COMMANDS.md](docs/LOCAL-WP-COMMANDS.md) |
| **Troubleshooting** | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| **CI/CD Integration** | [docs/CI-CD-INTEGRATION.md](docs/CI-CD-INTEGRATION.md) |
| **Fix-Iterate Loop Pattern** | [fix-iterate-loop.md](fix-iterate-loop.md) |

### Recipes

| Recipe | What It Does |
|---|---|
| [Performance Audit](recipes/performance-audit.md) | WPCC scan + WP Performance Timer runtime confirmation |
| [PHPStan Setup](recipes/phpstan-wordpress-setup.md) | Type-checking with baseline strategy for WordPress |
| [Seed Test Content](recipes/seed-test-content.md) | Batch content creation via MCP Adapter for fix-iterate loops |
| [Valet Clone Lab](recipes/valet-clone-lab.md) | Rapid throwaway WP cloning on macOS with `tools/valet-site-copy.sh` (optional, experimental) |

---

## Repository Structure

```
AI-DDTK/
├── bin/                  # CLI tools (added to PATH)
│   ├── wpcc              # WP Code Check scanner
│   ├── pw-auth           # Playwright WP admin auth
│   ├── local-wp          # WP-CLI wrapper for Local by Flywheel
│   ├── wp-ajax-test      # AJAX endpoint tester
│   ├── aiddtk-tmux       # Resilient tmux session manager
│   └── mcp-local-config  # Local MCP config merger
├── tools/
│   ├── mcp-server/       # Unified MCP server (18 tools, 4 resources)
│   ├── wp-code-check/    # WPCC source + 54 pattern files
│   ├── wp-ajax-test/     # AJAX test tool source
│   └── qm-bridge/       # Query Monitor bridge mu-plugin
├── templates/            # Mu-plugins (MCP Adapter abilities, dev-login)
├── recipes/              # Workflow guides
├── experimental/         # Promising but unstable tools
├── docs/                 # Full documentation
├── temp/                 # Sensitive data, reports, logs (gitignored)
├── AGENTS.md             # AI agent guidelines (single source of truth)
├── fix-iterate-loop.md   # Autonomous workflow pattern
└── CHANGELOG.md          # Version history
```

---

## Maintenance

```bash
./install.sh                  # First-time setup
./install.sh update           # Pull latest AI-DDTK
./install.sh update-wpcc      # Pull latest WP Code Check
./install.sh setup-mcp        # Build MCP server
./install.sh doctor-playwright # Diagnose Playwright issues
./install.sh status           # Show versions and status
./install.sh uninstall        # Remove PATH entries
```

---

## Recommended Companion Tools

For runtime observability alongside WPCC's static analysis:

- **[Query Monitor](https://github.com/johnbillion/query-monitor)** — The essential WordPress dev dashboard for database queries, HTTP requests, hooks, and more
- **[HookTrace](https://wordpress.org/plugins/hooktrace/)** — Per-callback execution order, timing, and source file for every hook fired during a page request

---

## Links

- [WP Code Check](https://github.com/Hypercart-Dev-Tools/WP-Code-Check)
- [IRL Audit Guide](tools/wp-code-check/dist/tests/irl/_AI_AUDIT_INSTRUCTIONS.md)
- [WordPress MCP Adapter](https://github.com/WordPress/mcp-adapter)

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.

The [Fix-Iterate Loop](fix-iterate-loop.md) methodology is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
