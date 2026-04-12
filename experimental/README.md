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

**Status:** Promoted to supported command
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
~/bin/ai-ddtk/install.sh wire-project

# Or from anywhere
wire-project /path/to/project
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

### Promoted Out of `experimental/`

These assets were useful enough to graduate into the maintained [tools/](../tools/README.md) surface and should now be treated as supported operator utilities rather than experimental prototypes:

- [tools/dev-context.sh](../tools/dev-context.sh) — Local WP / Valet context switcher with JSON status output
- [tools/servers-monitor.sh](../tools/servers-monitor.sh) plus [tools/servers-monitor.conf.example](../tools/servers-monitor.conf.example) — live machine conflict monitor and config template
- [tools/local-nginx-shim](../tools/local-nginx-shim) and [tools/local-nginx-shim-install.sh](../tools/local-nginx-shim-install.sh) — Local WP coexistence shim and installer

---

### `k6/` — Load Testing Harness (NEW)

**Status:** Experimental
**Purpose:** Lightweight load testing for WordPress / WooCommerce via [k6](https://k6.io/open-source/)

Fills the gap between single-request profiling (Query Monitor) and static analysis (WPCC) — answers "what happens under concurrent load?"

**Components:**
- `bin/k6-harness` — Safe wrapper with guardrails (max VUs, duration caps, local-only targeting)
- `k6/scripts/wp-baseline.js` — WordPress baseline (homepage, archives, REST API, static assets)
- `k6/scripts/woo-storefront.js` — WooCommerce customer journey (shop, product detail, add-to-cart, cart, checkout, My Account)

**Quick start:**
```bash
brew install k6
k6-harness http://mysite.local wp-baseline.js
k6-harness http://mysite.local woo-storefront.js --vus 15 --duration 60s
```

**Guardrails:** Max 25 VUs (hard cap 100), max 30s duration (hard cap 300s), remote targets blocked by default.

See `k6/README.md` for full documentation.

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
/path/to/AI-DDTK/bin/wire-project

# Verify files were created
ls -la .mcp.local.json CLAUDE.md
cat .gitignore | grep mcp.local.json
```

---

## Future Enhancements

- [ ] Add `--dry-run` flag to preview changes
- [ ] Add `--force` flag to overwrite existing config
- [ ] Support for multiple MCP servers in `.mcp.local.json`
- [ ] Support for detecting WordPress site type (plugin, theme, site)
- [ ] Auto-generate project-specific WPCC templates

---

## Feedback

These experimental features are subject to change. Please test and provide feedback before they move to production.

