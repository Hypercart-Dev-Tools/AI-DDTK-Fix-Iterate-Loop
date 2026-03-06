# AI-DDTK - AI Driven Development ToolKit

> Version: 1.0.7

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

# (Optional) Set up temp folder structure for credentials, reports, etc.
# The folder structure is already created; this just shows what's available
ls temp/
```

**Note**: The `/temp` folder is for storing sensitive data (credentials, API keys, reports) that should never be committed to git. See [`temp/README.md`](temp/README.md) for complete usage guidelines.

## Usage from Any Project

```bash
# Run WPCC against a plugin
wpcc analyze ./wp-content/plugins/my-plugin

# Run WP-CLI via Local
local-wp my-site plugin list
```

## Tools

| Tool | Description |
|------|-------------|
| **WP Code Check** | Code review + AI triage with MCP server |
| **WP AJAX Test** | AJAX endpoint testing and validation |
| **AI-DDTK Tmux Proxy** | Persistent tmux-backed sessions for flaky IDE terminals |
| **[Fix-Iterate Loop](fix-iterate-loop.md)** | Autonomous test-verify-fix workflow for AI agents |
| **local-wp** | WP-CLI wrapper for Local by Flywheel |
| **Playwright** | Headless browser automation |
| **PixelMatch** | Visual regression testing |

## Repository Structure

```
AI-DDTK/
├── install.sh           # Install & maintenance script
├── bin/                  # Executable wrappers (added to PATH)
│   ├── aiddtk-tmux      # Optional resilient tmux wrapper
│   ├── wpcc             # WP Code Check wrapper
│   └── wp-ajax-test     # AJAX endpoint tester
├── tools/               # Embedded dependencies (git subtree)
│   ├── wp-code-check/   # WPCC source
│   └── wp-ajax-test/    # AJAX test tool source
├── recipes/             # Workflow guides (PHPStan, audits, etc.)
├── experimental/        # Promising workflows that are not yet stable core tools
│   └── theme-crash-loop.sh
├── templates/           # Configuration templates
├── temp/                # Sensitive data storage (credentials, reports, logs)
│   ├── credentials/     # API keys, passwords, tokens
│   ├── reports/         # WPCC, PHPStan, performance reports
│   ├── data/            # Exports, imports, backups
│   ├── playwright/      # Playwright auth state
│   ├── logs/            # Debug logs and tmux session captures
│   └── analysis/        # AI agent working files
├── local-wp             # Local WP-CLI wrapper
├── fix-iterate-loop.md  # Autonomous test-verify-fix pattern
├── AGENTS.md            # AI agent guidelines
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

## For AI Agents

See `install.sh` for detailed guidance on:
- Git subtree operations for updating WPCC
- GitHub CLI commands for checking updates
- Architecture and maintenance notes

## WPCC: Project Templates

Set up once, reuse forever. Templates save plugin/theme paths and scan settings so you can re-run audits with a single command.

```bash
# First time: auto-detects plugin name, version, and GitHub repo
wpcc run gravityforms
# → Template not found. Create from current directory? [y/N] y
# ✓ Created! Detected: Gravity Forms v2.7.1

# Every time after: one command runs the full workflow
# Ask AI: "Run gravityforms end to end"
```

That single command triggers the complete pipeline:

```
Scan → AI Triage → HTML Report → GitHub Issue
       (filters       (with AI        (with checkboxes,
       false           summary         ready for Jira/
       positives)      at top)         Linear/Asana too)
```

Templates handle flexible naming — `Gravity Forms`, `gravity-forms`, and `gravityforms` all resolve to the same config. See the [Template Guide](tools/wp-code-check/dist/HOWTO-TEMPLATES.md) for details.

### More WPCC Features

| Feature | Description | How to Use |
|---------|-------------|------------|
| **AI-Assisted Triage** | Automated false positive detection | Ask AI: "Triage this scan" or "Run X end to end" |
| **GitHub Issue Creation** | Convert findings to trackable issues | Ask AI: "Create issue for scan" |
| **IRL Audit Mode** | Annotate real code for pattern library | See [Audit Guide](tools/wp-code-check/dist/tests/irl/_AI_AUDIT_INSTRUCTIONS.md) |
| **Multi-Platform Export** | Export issues to Jira, Linear, Asana, Trello | Issues saved to `dist/issues/` for copy/paste |

### Quick Examples

```bash
# Basic scan (no template needed)
wpcc --paths ./wp-content/plugins/my-plugin --format json

# Show all available features and templates
wpcc --features
```

**Full AI Instructions:** [WPCC AI Instructions](tools/wp-code-check/dist/TEMPLATES/_AI_INSTRUCTIONS.md)

## WordPress Development Guidelines

AI-DDTK includes comprehensive WordPress development guidelines in [`AGENTS.md`](AGENTS.md) for AI coding assistants.

### 🎯 Philosophy: Works Great by Default, Customizable for Experts

**For beginners**: Follow the patterns in AGENTS.md — they represent WordPress community best practices and will keep your code maintainable from day one.

**For senior developers**: The guidelines are Hypercart's opinionated defaults. Fork `AGENTS.md` and customize to match your team's standards.

### What's Covered

| Section | Type | Description |
|---------|------|-------------|
| **Security** | Required | Nonces, sanitization, escaping, sensitive data handling |
| **Performance** | Required | Caching, query optimization, resource limits |
| **WordPress APIs** | Required | Hooks, filters, database access, WP-CLI |
| **SOLID Principles** | Opinionated | Architecture patterns with rationale and customization guidance |
| **DRY & State Management** | Opinionated | Helper patterns, single contract writers, FSM guidance |
| **Scope Control** | Opinionated | When to refactor, preservation vs. optimization trade-offs |
| **Documentation** | Opinionated | PHPDoc standards, versioning, CHANGELOG requirements |
| **Testing** | Opinionated | Backward compatibility, Fix-Iterate Loop pattern |

### Customization Examples

The guide includes team-specific customization examples for:
- **Startups** - Move fast, relax DRY requirements
- **Enterprise** - Strict documentation, lower FSM thresholds
- **Open Source** - Package tags, unit test requirements
- **Agencies** - Strict scope control, detailed changelogs
- **Maintenance** - Zero scope creep, preservation-first

**See the full guide**: [`AGENTS.md`](AGENTS.md)

## Troubleshooting

**`wpcc: command not found`** — Reload your shell config, then retry:
```bash
source ~/.zshrc  # or ~/.bashrc
```
If that doesn't work, verify the install:
```bash
~/bin/ai-ddtk/install.sh status
```

**`WPCC not found` or `setup-wpcc` needed** — Run setup again:
```bash
cd ~/bin/ai-ddtk && ./install.sh setup-wpcc
```

**VS Code AI terminal is non-responsive** — Move the work into a tmux-backed session:
```bash
aiddtk-tmux start --cwd /path/to/project
aiddtk-tmux send --command "~/bin/ai-ddtk/bin/wpcc --paths . --format json --verbose"
aiddtk-tmux capture --tail 200
```

If `tmux` is missing, install it first:
```bash
brew install tmux
```

**WPCC stalls when scanning AI-DDTK itself** — The repository includes embedded WPCC via git subtree. Use exclusions:
```bash
# Exclude embedded tools (recommended)
wpcc --paths . --exclude "tools/,.git/,node_modules/" --format json

# Or scan only specific directories
wpcc --paths "bin/ recipes/ templates/" --format json
```

> **Note**: A `.wpcignore` file is included in the repository for future WPCC versions that support automatic exclusions.

## Experimental Workflows

Promising but not-yet-core helpers live in `experimental/`. Requires [Local by Flywheel](https://localwp.com/).

- **`theme-crash-loop.sh`** — Toggles between a fallback and target theme on a Local site, probes key URLs, and captures log deltas. Useful for reproducing theme activation crashes. The same pattern works for plugin debugging (activate/deactivate instead of theme switch). Run `experimental/theme-crash-loop.sh --help` for usage.

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.

The [Fix-Iterate Loop](fix-iterate-loop.md) methodology is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## Links

- [WP Code Check](https://github.com/Hypercart-Dev-Tools/WP-Code-Check)
- [IRL Audit Guide](tools/wp-code-check/dist/tests/irl/_AI_AUDIT_INSTRUCTIONS.md)
