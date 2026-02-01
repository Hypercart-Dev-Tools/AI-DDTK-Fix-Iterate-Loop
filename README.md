# AI-DDTK - AI Driven Development ToolKit

> Version: 1.0.0

Testing + Automation → Bugs → Fixes → Testing → Deploy

## Overview

A central toolkit for AI-driven WordPress development, designed to be called from any project.

**At the center:**
- VS Code AI Agents (Claude Code, Augment, Codex, etc.) with tuned system instructions
- MCP server integration for tool orchestration

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
| **local-wp** | WP-CLI wrapper for Local by Flywheel |
| **Playwright** | Headless browser automation |
| **PixelMatch** | Visual regression testing |

## Repository Structure

```
AI-DDTK/
├── install.sh           # Install & maintenance script
├── bin/                  # Executable wrappers (added to PATH)
│   └── wpcc              # WP Code Check wrapper
├── tools/                # Embedded dependencies (git subtree)
│   └── wp-code-check/    # WPCC source
├── agents/               # AI agent instructions
├── mcp/                  # MCP server configurations
├── local-wp              # Local WP-CLI wrapper
└── AGENTS.md             # AI agent guidelines
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

## Links

- [WP Code Check](https://github.com/Hypercart-Dev-Tools/WP-Code-Check)
