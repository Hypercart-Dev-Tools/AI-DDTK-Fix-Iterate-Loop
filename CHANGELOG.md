# Changelog

All notable changes to AI-DDTK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
| 1.0.0 | 2025-02-01 | Initial release with install script and WPCC integration |

---

## Upgrade Notes

### To 1.0.0
First release - no upgrade path needed.

**Fresh install:**
```bash
git clone https://github.com/YOUR-ORG/AI-DDTK.git ~/bin/ai-ddtk
cd ~/bin/ai-ddtk
./install.sh
./install.sh setup-wpcc
source ~/.zshrc
```

