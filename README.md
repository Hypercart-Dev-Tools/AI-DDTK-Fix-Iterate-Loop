# AI-DDTK - AI Driven Development ToolKit

> Version: 1.0.44

Testing + Automation → Bugs → Fixes → Testing → Deploy

## Overview

An early work in progress centralized toolkit for AI-driven WordPress development, designed to be called from any project.

**At the center:**
- VS Code AI Agents (Claude Code, Augment, Codex, etc.) with tuned system instructions
- MCP server integration for tool orchestration

## Prerequisites

| Requirement | Used By | Install |
|-------------|---------|---------|
| **Git** | Cloning AI-DDTK & WPCC updates | `brew install git` |
| **Node.js** | WP Code Check scanner | `brew install node` |
| **Python 3** | AI triage, HTML reports | `brew install python3` |
| **Composer** | PHPStan (optional) | `brew install composer` |
| **GitHub CLI** | Issue creation (optional) | `brew install gh` |
| **tmux** | Resilient agent terminal sessions (optional) | `brew install tmux` |
| **Playwright** | Browser automation (optional) | `npm install -g playwright` |
| **WP-CLI** | Playwright auth helper (`pw-auth`) requires WP-CLI | [wp-cli.org](https://wp-cli.org/) |

## Quick Start

```bash
# Clone to your bin directory
git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git ~/bin/ai-ddtk
cd ~/bin/ai-ddtk

# Install (adds to PATH)
./install.sh

# Set up WP Code Check
./install.sh setup-wpcc

# Activate in current shell
source ~/.zshrc  # or ~/.bashrc

# Verify installation
wpcc --help
local-wp --help
```

**Note**: The `/temp` folder is for storing sensitive data (credentials, API keys, reports) that should never be committed to git. See [`temp/README.md`](temp/README.md) for complete usage guidelines.

## Navigation

| Topic | Location |
|-------|----------|
| CLI Commands Reference | [AGENTS.md — Quick Reference](AGENTS.md#-quick-reference) |
| MCP Server Setup | [AGENTS.md — MCP Server Setup](AGENTS.md#mcp-server-setup-and-lifecycle) |
| Playwright Auth (`pw-auth`) | [AGENTS.md — Playwright Auth](AGENTS.md#-playwright-auth-pw-auth) |
| WPCC Orchestration & Templates | [AGENTS.md — WPCC](AGENTS.md#wpcc-wp-code-check) |
| WordPress Dev Guidelines | [AGENTS.md — Architecture](AGENTS.md#️-wordpress-architecture-and-delivery-rules) |
| Troubleshooting | [AGENTS.md — Troubleshooting](AGENTS.md#-troubleshooting) |
| Full Tool Documentation | [docs/](docs/) |

## Tools

| Tool | Description | Reference |
|------|-------------|-----------|
| **AI-DDTK MCP Server** | Unified stdio MCP package for LocalWP, pw-auth, wp-ajax-test, tmux, and WPCC | [AGENTS.md](AGENTS.md#mcp-server-setup-and-lifecycle) |
| **WP Code Check** | Code review + AI triage with MCP server | [WPCC Commands](docs/WPCC-COMMANDS.md) |
| **WP AJAX Test** | AJAX endpoint testing and validation | [CLI Reference](docs/CLI-REFERENCE.md#wp-ajax-test) |
| **AI-DDTK Tmux Proxy** | Persistent tmux-backed sessions for flaky IDE terminals | [CLI Reference](docs/CLI-REFERENCE.md#aiddtk-tmux) |
| **Playwright Auth** | One-time WP admin login + Playwright storageState caching | [AGENTS.md](AGENTS.md#-playwright-auth-pw-auth) |
| **[Fix-Iterate Loop](fix-iterate-loop.md)** | Autonomous test-verify-fix workflow for AI agents | [fix-iterate-loop.md](fix-iterate-loop.md) |
| **local-wp** | WP-CLI wrapper for Local by Flywheel | [local-wp Commands](docs/LOCAL-WP-COMMANDS.md) |
| **PixelMatch** | Visual regression testing | [CLI Reference](docs/CLI-REFERENCE.md) |

## MCP Server Quick Start

```bash
./install.sh setup-mcp
./install.sh status
```

For complete MCP setup (Augment Code, Claude Desktop, Cline wiring, all 18 tools), see [AGENTS.md — MCP Server Setup](AGENTS.md#mcp-server-setup-and-lifecycle).

## Repository Structure

```
AI-DDTK/
├── install.sh           # Install & maintenance script
├── bin/                  # Executable wrappers (added to PATH)
│   ├── aiddtk-tmux      # Optional resilient tmux wrapper
│   ├── local-wp         # Local WP-CLI wrapper (canonical)
│   ├── pw-auth          # Playwright WP admin auth helper
│   ├── wpcc             # WP Code Check wrapper
│   └── wp-ajax-test     # AJAX endpoint tester
├── tools/               # Embedded tool packages and dependencies
│   ├── mcp-server/      # AI-DDTK MCP server package (stdio + LocalWP + pw-auth + wp-ajax-test + tmux + WPCC)
│   ├── wp-code-check/   # WPCC source
│   └── wp-ajax-test/    # AJAX test tool source
├── recipes/             # Workflow guides (PHPStan, audits, etc.)
├── experimental/        # Promising workflows that are not yet stable core tools
│   └── theme-crash-loop.sh
├── templates/           # Configuration templates (PHPStan, dev-login-cli mu-plugin)
├── temp/                # Sensitive data storage (credentials, reports, logs)
├── local-wp             # Temporary compatibility shim to bin/local-wp
├── fix-iterate-loop.md  # Autonomous test-verify-fix pattern
├── AGENTS.md            # AI agent guidelines (single source of truth)
└── CHANGELOG.md         # Version history
```

## Maintenance Commands

```bash
./install.sh              # First-time setup
./install.sh update       # Pull latest AI-DDTK
./install.sh update-wpcc  # Pull latest WP Code Check
./install.sh status       # Show versions and status
./install.sh uninstall    # Remove PATH entries
```

## Optional Workflows

- **Valet Clone Lab (macOS, optional)**: Rapid throwaway WordPress cloning/testing workflow for copy detection and regression drills.
  - Recipe: [recipes/valet-clone-lab.md](recipes/valet-clone-lab.md)
  - Positioning: optional and experimental, not a Local WP replacement

## For AI Agents

See [`AGENTS.md`](AGENTS.md) — the single source of truth for all AI development guidelines including security, performance, WordPress patterns, MCP setup, pw-auth workflows, troubleshooting, and tool references.

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.

The [Fix-Iterate Loop](fix-iterate-loop.md) methodology is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## Links

- [WP Code Check](https://github.com/Hypercart-Dev-Tools/WP-Code-Check)
- [IRL Audit Guide](tools/wp-code-check/dist/tests/irl/_AI_AUDIT_INSTRUCTIONS.md)
