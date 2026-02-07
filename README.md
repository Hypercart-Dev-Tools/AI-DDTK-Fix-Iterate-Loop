# AI-DDTK - AI Driven Development ToolKit

> Version: 1.0.5

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
```

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
| **[Fix-Iterate Loop](fix-iterate-loop.md)** | Autonomous test-verify-fix workflow for AI agents |
| **local-wp** | WP-CLI wrapper for Local by Flywheel |
| **Playwright** | Headless browser automation |
| **PixelMatch** | Visual regression testing |

## Repository Structure

```
AI-DDTK/
├── install.sh           # Install & maintenance script
├── bin/                  # Executable wrappers (added to PATH)
│   ├── wpcc             # WP Code Check wrapper
│   └── wp-ajax-test     # AJAX endpoint tester
├── tools/               # Embedded dependencies (git subtree)
│   ├── wp-code-check/   # WPCC source
│   └── wp-ajax-test/    # AJAX test tool source
├── recipes/             # Workflow guides (PHPStan, audits, etc.)
├── templates/           # Configuration templates
├── local-wp             # Local WP-CLI wrapper
├── fix-iterate-loop.md  # Autonomous test-verify-fix pattern
├── AGENTS.md            # AI agent guidelines
├── CHANGELOG.md         # Version history
└── SYSTEM-INSTRUCTIONS.md # AI agent setup
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

## WPCC Advanced Features

Beyond basic scanning, WP Code Check includes powerful AI-assisted workflows:

| Feature | Description | How to Use |
|---------|-------------|------------|
| **Project Templates** | Save scan configs for recurring projects | `wpcc --features` or see [Template Guide](tools/wp-code-check/dist/HOWTO-TEMPLATES.md) |
| **AI-Assisted Triage** | Automated false positive detection | Ask AI: "Triage this scan" or "Run X end to end" |
| **GitHub Issue Creation** | Convert findings to trackable issues | Ask AI: "Create issue for scan" |
| **End-to-End Workflow** | Scan → Triage → HTML → Issue in one flow | Ask AI: "Run template X end to end" |
| **IRL Audit Mode** | Annotate real code for pattern library | See [Audit Guide](tools/wp-code-check/dist/tests/irl/_AI_AUDIT_INSTRUCTIONS.md) |
| **Multi-Platform Export** | Export issues to Jira, Linear, Asana, Trello | Issues saved to `dist/issues/` for copy/paste |

### Quick Examples

```bash
# Basic scan
wpcc --paths ./wp-content/plugins/my-plugin --format json

# Show all available features
wpcc --features

# Using templates (faster for recurring scans)
wpcc --features  # Lists templates
# Ask AI: "Run template my-plugin end to end"
```

### AI Agent Workflows

For AI agents (Claude, Augment, Codex, etc.), WPCC supports orchestrated multi-phase workflows:

```
Phase 1: Scan      → Generate JSON findings
Phase 2: AI Triage → Identify false positives, add recommendations
Phase 3: HTML      → Generate report with AI summary
Phase 4: Issue     → Create GitHub issue with checkboxes
```

**Full AI Instructions:** [WPCC AI Instructions](tools/wp-code-check/dist/TEMPLATES/_AI_INSTRUCTIONS.md)

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

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.

The [Fix-Iterate Loop](fix-iterate-loop.md) methodology is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## Links

- [WP Code Check](https://github.com/Hypercart-Dev-Tools/WP-Code-Check)
- [IRL Audit Guide](tools/wp-code-check/dist/tests/irl/_AI_AUDIT_INSTRUCTIONS.md)
