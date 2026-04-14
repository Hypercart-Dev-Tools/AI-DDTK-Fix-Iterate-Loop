# Changelog

All notable changes to the AI-DDTK VS Code Extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-04-13

### Changed

- **Local MCP precedence** — `.mcp.local.json` is now the preferred repo-local override and wins over any legacy `temp/mcp/local-snippets/*.json` fragments when both are present.
- **Legacy fragment compatibility** — the extension still watches `temp/mcp/local-snippets/*.json` to avoid breaking older local setups, but now treats that path as deprecated compatibility rather than the primary workflow.

## [0.2.0] - 2026-04-05

### Added

- **Dynamic MCP server discovery** — the MCP server definition provider now merges configs from 5 layers: static AI-DDTK server (fallback), workspace `.mcp.json`, `.vscode/mcp.json`, `.mcp.local.json`, and `temp/mcp/local-snippets/*.json`. Later layers override earlier ones by server name. This means site-specific WP MCP Adapter servers and local configs are automatically provided to all VS Code MCP clients (Copilot, Cline, Continue) without manual wiring.
- **Live config file watchers** — file system watchers on all 4 config paths trigger automatic re-discovery when configs are added, changed, or deleted. No extension reload or VS Code restart needed.
- **`src/mcpConfig.ts`** — new module containing `McpConfigProvider` class with discovery, merge, snippet normalization, and file watcher lifecycle. Mirrors the merge logic from `bin/mcp-local-config`.

### Changed

- **`src/extension.ts`** — MCP provider now delegates to `McpConfigProvider` instead of hardcoding a single static server definition.

## [0.1.0] - 2026-03-26

### Added

- Initial experimental release of AI-DDTK VS Code Extension
- **Status Bar Integration** — Real-time AI-DDTK readiness indicator with contextual icons
- **Project Wiring** — One-click MCP configuration setup via `wire-project` script
- **Preflight Checks** — Verify AI-DDTK installation and dependencies
- **WPCC Scanning** — Run WordPress code security/performance scans from the editor
  - Scan current file
  - Scan entire project
  - Scan custom path
- **Documentation Access** — Quick links to AI-DDTK docs and GitHub repository
- **Auto-Detection** — Automatically detects WordPress projects and offers setup
- **Configuration** — Customizable settings for paths, auto-wire, status bar, and MCP server
- **Command Palette Integration** — All features accessible via VS Code command palette
- **TypeScript Support** — Full TypeScript implementation with strict mode
- **ESLint Configuration** — Code quality checks and linting

### Features

#### Commands

- `ai-ddtk.wireProject` — Set up MCP configuration for current workspace
- `ai-ddtk.runPreflight` — Verify AI-DDTK installation and dependencies
- `ai-ddtk.runWpcc` — Run WordPress code security/performance scan
- `ai-ddtk.openDocs` — Access AI-DDTK docs and GitHub repo
- `ai-ddtk.checkStatus` — Display AI-DDTK installation status

#### Status Bar States

- 🔴 **Error** — AI-DDTK not installed
- 🟡 **Setup** — WordPress project detected, not yet wired
- 🟢 **Ready** — MCP configured and ready to use
- 🔵 **Info** — AI-DDTK installed, non-WordPress workspace

#### Configuration Options

- `ai-ddtk.aiDdtkPath` — Path to AI-DDTK installation (default: `~/bin/ai-ddtk`)
- `ai-ddtk.autoWireOnOpen` — Auto-wire WordPress projects on open (default: `false`)
- `ai-ddtk.showStatusBar` — Show status bar indicator (default: `true`)
- `ai-ddtk.enableMcpServer` — Enable MCP server integration (default: `true`)

### Technical Details

- **Activation Events** — `onStartupFinished`, WordPress project detection, command triggers
- **Build System** — esbuild for fast bundling and minification
- **Target** — VS Code 1.85.0+, Node.js 18+
- **Language** — TypeScript with strict mode

### Known Limitations

- Extension is experimental and subject to change
- Requires AI-DDTK to be installed at `~/bin/ai-ddtk`
- MCP server integration requires `wire-project` script from experimental folder
- Status detection relies on file system checks (wp-config.php, wp-content/, etc.)

### Future Enhancements

- [ ] Marketplace publication
- [ ] Settings UI for easier configuration
- [ ] Integration with VS Code's built-in terminal
- [ ] Real-time WPCC scan results in editor
- [ ] Query Monitor profiling integration
- [ ] Playwright auth integration
- [ ] Project templates and scaffolding
- [ ] Multi-workspace support
- [ ] Custom keybindings

---

## Development

See [README.md](./README.md) for development setup and contribution guidelines.
