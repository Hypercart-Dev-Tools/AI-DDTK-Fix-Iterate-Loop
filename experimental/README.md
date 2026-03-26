# Experimental Features

This folder contains experimental features and tools for AI-DDTK that are under development and testing.

## Contents

### `vscode-extension/` — VS Code Extension (NEW)

**Status:** Experimental
**Purpose:** Integrate AI-DDTK tools directly into VS Code

A complete VS Code extension that brings AI-DDTK capabilities into the editor:
- **Status Bar Integration** — Real-time AI-DDTK readiness indicator
- **Project Wiring** — One-click MCP configuration setup
- **Preflight Checks** — Verify AI-DDTK installation
- **WPCC Scanning** — Run WordPress code scans from the editor
- **Documentation Access** — Quick links to docs and GitHub

**Files:**
- `package.json` — Extension manifest with full configuration
- `src/extension.ts` — Main activation and lifecycle
- `src/manager.ts` — AI-DDTK status detection and management
- `src/statusBar.ts` — Status bar UI integration
- `src/commands.ts` — Command handlers for all features
- `tsconfig.json` — TypeScript configuration
- `README.md` — Complete extension documentation
- `CHANGELOG.md` — Version history and features
- `.gitignore` — Build artifacts and dependencies
- `.eslintrc.json` — Code quality configuration

**Build & Test:**
```bash
cd vscode-extension
npm install
npm run esbuild          # Development build
npm run esbuild-watch   # Watch mode
npm run vscode:prepublish  # Production build
```

**Load in VS Code:**
- Press `F5` to debug in a new VS Code window
- Or: Extensions → Install from VSIX

**Status:** ✅ Portable and public-ready
- All source files included
- No hardcoded paths or personal data
- Comprehensive documentation
- Git hygiene enforced (.gitignore)
- Standard npm workflow

---

### `wire-project`

**Status:** Experimental
**Purpose:** Automate per-project MCP configuration for AI-DDTK

A CLI script that wires a WordPress project for AI-DDTK MCP integration by:
- Auto-detecting home directory (no manual path substitution)
- Generating `.mcp.local.json` with correct paths
- Updating `.gitignore` to exclude local config
- Creating `CLAUDE.md` reference for AI agents
- Providing clear next steps

**Usage:**
```bash
# From project root
./experimental/wire-project

# Or from anywhere
./experimental/wire-project /path/to/project
```

**Output:**
```
Wiring project for AI-DDTK...
Project path: /path/to/project

Checking AI-DDTK installation... ✓
Detecting home directory... ✓ (/Users/noel)
Creating .mcp.local.json... ✓
Updating .gitignore... ✓
Creating CLAUDE.md reference... ✓

✓ Project wired! Ready to use AI-DDTK.

Next steps:
  1. Restart your editor/agent session
  2. Run: ~/bin/ai-ddtk/preflight.sh
  3. Start coding!
```

**Files created/updated:**
- `.mcp.local.json` — Local MCP server configuration (not version-controlled)
- `.gitignore` — Adds `.mcp.local.json` entry
- `CLAUDE.md` — Reference guide for AI agents

**Design notes:**
- Idempotent: Safe to run multiple times
- Works in CI/CD pipelines
- No external dependencies beyond bash
- Provides clear error messages if AI-DDTK not installed

---

### `P1-ONBOARDING.md`

**Status:** Planning document
**Purpose:** Design notes for onboarding automation

Documents the problem, two proposed solutions (setup script vs. MCP server), and rationale for choosing the `wire-project` approach.

---

## Testing

To test `wire-project`:

```bash
# Create a test project
mkdir -p /tmp/test-wp-site
cd /tmp/test-wp-site

# Run wire-project
/path/to/AI-DDTK/experimental/wire-project

# Verify files were created
ls -la .mcp.local.json CLAUDE.md
cat .gitignore | grep mcp.local.json
```

---

## Future Enhancements

- [ ] Add `--dry-run` flag to preview changes
- [ ] Add `--force` flag to overwrite existing config
- [ ] Support for multiple MCP servers in `.mcp.local.json`
- [ ] Integration with `install.sh` to make globally available
- [ ] Support for detecting WordPress site type (plugin, theme, site)
- [ ] Auto-generate project-specific WPCC templates

---

## Feedback

These experimental features are subject to change. Please test and provide feedback before they move to production.

