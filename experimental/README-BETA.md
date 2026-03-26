# AI-DDTK — AI-Driven Development Toolkit for WordPress

> **Ship safer, faster WordPress code — with AI agents doing the heavy lifting.**

AI-DDTK is a unified toolkit that gives AI coding agents (Claude Code, Augment, Cline, Cursor, Codex) deep WordPress superpowers: static analysis, browser automation, runtime profiling, content scaffolding, and autonomous fix-iterate workflows.

MCP stands for Model Context Protocol: a standard way for editors and AI tools to discover and call local tools through a structured server instead of ad hoc shell glue.

```
Scan → Triage → Fix → Verify → Ship
```

**For detailed agent guidelines, tool usage, and WordPress development rules, see [AGENTS.md](AGENTS.md) — the single source of truth.**

---

## What's Inside

| Capability | What It Does | Details |
|---|---|---|
| **WPCC** — 54-Pattern Static Scanner | Security, performance, WooCommerce, headless/GraphQL, and Node.js analysis with AI triage | [AGENTS.md § WPCC](AGENTS.md#wpcc-wp-code-check) · [WPCC Commands](docs/WPCC-COMMANDS.md) |
| **Playwright Auth (`pw-auth`)** | Passwordless wp-admin login via one-time URLs, 12h session caching, DOM inspection | [AGENTS.md § pw-auth](AGENTS.md#-playwright-auth-pw-auth) · [pw-auth Commands](docs/PW-AUTH-COMMANDS.md) |
| **Query Monitor Profiling** | Headless page profiling — slow queries, N+1 detection, cache stats | [AGENTS.md § Available Tools](AGENTS.md#available-tools) |
| **WordPress MCP Adapter** | 13 abilities for API-level CRUD without a browser (WP 6.9+) | [MCP Adapter Setup](docs/MCP-ADAPTER-SETUP.md) · [Ability Schemas](docs/mcp-adapter-abilities.md) |
| **Fix-Iterate Loop** | Guardrailed autonomous scan→fix→verify workflows (5 fail / 10 total max) | [fix-iterate-loop.md](fix-iterate-loop.md) |
| **MCP Server** | 21 typed tools across 6 areas, auto-discovered via `.mcp.json` for supported editors | [AGENTS.md § MCP Setup](AGENTS.md#mcp-server-setup-and-lifecycle) |
| **Local MCP Config Merge (`mcp-local-config`)** | Safely merge checked-in `.mcp.json` with gitignored local snippets for real site names, paths, and tokens | [docs/CLI-REFERENCE.md](docs/CLI-REFERENCE.md) |
| **Install + Doctor Commands** | Full setup, PATH management, Playwright diagnostics, version/status checks | [install.sh](install.sh) |

> **When to use which?** Need to *see* the page → pw-auth + Playwright. Need to *read/write data* → MCP Adapter. Need to *analyze code* → WPCC. See the [decision tree](docs/mcp-adapter-abilities.md#decision-tree--when-to-use-mcp-adapter-vs-pw-auth) for the full guide.

---

## Quick Start

> **macOS-centric, Linux-friendly.**
> Full toolkit coverage is best on macOS because Local by Flywheel and the default install examples assume it, but core scanning with `wpcc` works on Linux, WSL, and other Unix-like environments with Node.js.

### Prerequisites

**Required:**

| Requirement | Used By | Install |
|---|---|---|
| **Git** | Core | `brew install git` |
| **Node.js ≥ 18** | WPCC, MCP server | `brew install node` |

**Optional (unlocks specific features):**

| Requirement | Unlocks | Install |
|---|---|---|
| **Python 3** | AI triage, HTML reports | `brew install python3` |
| **WP-CLI** | pw-auth, local-wp, MCP Adapter | [wp-cli.org](https://wp-cli.org/) |
| **Composer** | PHPStan | `brew install composer` |
| **Playwright** | Browser automation | `npm install -g playwright` |
| **tmux** | Resilient sessions | `brew install tmux` |
| **GitHub CLI** | Issue creation | `brew install gh` |

### Step 1: Install AI-DDTK

```bash
# Clone to ~/bin/ai-ddtk (the target folder name is your choice)
git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git ~/bin/ai-ddtk
cd ~/bin/ai-ddtk

# Install (adds tools to PATH, sets up WPCC, attempts MCP setup when Node >= 18)
./install.sh
source ~/.zshrc  # or ~/.bashrc

# Verify
wpcc --help
./install.sh status
```

### Step 2: Wire AI-DDTK into your projects

AI-DDTK is installed once but used from your WordPress project workspaces. To connect a project:

**Copy the setup file into your project root:**

```bash
cp ~/bin/ai-ddtk/templates/ai-ddtk-setup.md /path/to/your-project/
```

**Then tell your AI agent:**

> I've added ai-ddtk-setup.md to this project. Please follow the setup instructions in it.

The agent will:
1. Verify AI-DDTK is installed locally
2. Create `.mcp.local.json` (so your editor auto-discovers the MCP tools)
3. Add `.mcp.local.json` to `.gitignore` (local paths stay local)
4. Add a reference line to `CLAUDE.md` (Claude Code users)
5. Let you know setup is done — you can delete the setup file after

**That's it.** Your AI agent now has access to all 21 MCP tools — WPCC scanning, Playwright auth, Query Monitor profiling, and more — directly from your project workspace.

**Manual setup alternative:** If you prefer not to use the agent-assisted setup, see [AGENTS.md § Wiring into Your Editor](AGENTS.md#wiring-into-your-editor) for manual `.mcp.json` configuration.

### Step 3: Verify (optional)

Run the preflight check from any directory to confirm everything is ready:

```bash
~/bin/ai-ddtk/preflight.sh
```

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
| **Preflight Checklist** | [experimental/preflight.md](experimental/preflight.md) |
| **Weekly UX Audit** | [recipes/weekly-ux-audit.md](recipes/weekly-ux-audit.md) |
| **Fix-Iterate Loop Pattern** | [fix-iterate-loop.md](fix-iterate-loop.md) |
| **Security & Performance Rules** | [AGENTS.md — Security](AGENTS.md#-security-sensitive-data-and-performance-guardrails) |

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
│   ├── mcp-server/       # Unified MCP server (21 tools, 4 resources)
│   ├── wp-code-check/    # WPCC source + 54 pattern files
│   ├── wp-ajax-test/     # AJAX test tool source
│   └── qm-bridge/       # Query Monitor bridge mu-plugin
├── templates/            # Setup files, mu-plugins (MCP Adapter, dev-login)
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
