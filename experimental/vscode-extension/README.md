# AI-DDTK VS Code Extension

Integrate AI-DDTK tools (WPCC, pw-auth, Query Monitor) directly into VS Code for seamless WordPress development.

## Features

- **Status Bar Integration** — Real-time AI-DDTK readiness indicator
- **Project Wiring** — One-click MCP configuration setup via `wire-project`
- **Preflight Checks** — Verify AI-DDTK installation and dependencies
- **WPCC Scanning** — Run WordPress security/performance scans from the editor
- **Documentation Access** — Quick links to AI-DDTK docs and GitHub
- **Auto-Detection** — Automatically detects WordPress projects and offers setup

## Requirements

- **VS Code** 1.85.0 or later
- **AI-DDTK** installed at `~/bin/ai-ddtk` (see [AI-DDTK Installation](../../README-AI-DDTK.md))
- **Node.js** 18+ (for building the extension)

## Installation

### From Source (Development)

```bash
cd experimental/vscode-extension

# Install dependencies
npm install

# Build the extension
npm run esbuild

# Package for distribution (optional)
npm run vscode:prepublish
```

### Load in VS Code

1. Open VS Code
2. Press `Ctrl+Shift+D` (or `Cmd+Shift+D` on macOS) to open Run and Debug
3. Select "Run Extension" to launch the extension in a new VS Code window
4. Or manually load: Extensions → Install from VSIX → select the packaged `.vsix` file

## Usage

### Commands

Access all commands via Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`):

| Command | Description |
|---------|-------------|
| **AI-DDTK: Wire Project** | Set up MCP configuration for current workspace |
| **AI-DDTK: Run Preflight Check** | Verify AI-DDTK installation and dependencies |
| **AI-DDTK: Scan with WPCC** | Run WordPress code security/performance scan |
| **AI-DDTK: Open Documentation** | Access AI-DDTK docs and GitHub repo |
| **AI-DDTK: Check Status** | Display AI-DDTK installation status |

### Status Bar

The status bar (bottom right) shows AI-DDTK readiness:

- 🔴 **Error** — AI-DDTK not installed
- 🟡 **Setup** — WordPress project detected, not yet wired
- 🟢 **Ready** — MCP configured and ready to use
- 🔵 **Info** — AI-DDTK installed, non-WordPress workspace

Click the status bar item to check detailed status.

### Configuration

Configure the extension via VS Code settings (`Cmd+,` / `Ctrl+,`):

```json
{
  "ai-ddtk.aiDdtkPath": "~/bin/ai-ddtk",
  "ai-ddtk.autoWireOnOpen": false,
  "ai-ddtk.showStatusBar": true,
  "ai-ddtk.enableMcpServer": true
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `aiDdtkPath` | string | `~/bin/ai-ddtk` | Path to AI-DDTK installation |
| `autoWireOnOpen` | boolean | `false` | Auto-wire WordPress projects on open |
| `showStatusBar` | boolean | `true` | Show status bar indicator |
| `enableMcpServer` | boolean | `true` | Enable MCP server integration |

## Development

### Project Structure

```
experimental/vscode-extension/
├── src/
│   ├── extension.ts      # Main activation and lifecycle
│   ├── manager.ts        # AI-DDTK status and detection
│   ├── statusBar.ts      # Status bar UI integration
│   └── commands.ts       # Command handlers
├── package.json          # Extension manifest
├── tsconfig.json         # TypeScript configuration
└── README.md             # This file
```

### Build Scripts

```bash
# Development build with source maps
npm run esbuild

# Watch mode (auto-rebuild on changes)
npm run esbuild-watch

# Production build (minified)
npm run vscode:prepublish

# Lint code
npm run lint

# Run tests
npm run test
```

### Debugging

1. Open the extension folder in VS Code
2. Press `F5` to start debugging
3. A new VS Code window opens with the extension loaded
4. Set breakpoints and use the Debug Console

### Code Style

- TypeScript with strict mode enabled
- ESLint for code quality
- Follow VS Code extension best practices

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Extension not activating | Check VS Code version (1.85.0+), reload window |
| Commands not appearing | Run `Developer: Reload Window` command |
| Status bar not showing | Check `ai-ddtk.showStatusBar` setting |
| Wire project fails | Ensure AI-DDTK is installed at `~/bin/ai-ddtk` |
| WPCC not found | Run "AI-DDTK: Run Preflight Check" to diagnose |

## Contributing

This is an experimental feature. Feedback and contributions are welcome!

See [AGENTS.md](../../AGENTS.md) for AI-DDTK development guidelines.

## License

MIT — See [LICENSE](../../LICENSE) in the main AI-DDTK repository.

## Related Documentation

- [AI-DDTK README](../../README.md) — Main toolkit documentation
- [AI-DDTK Setup Guide](../../README-AI-DDTK.md) — Installation and configuration
- [AGENTS.md](../../AGENTS.md) — Development guidelines and tool reference
- [wire-project](../wire-project) — MCP configuration automation script

