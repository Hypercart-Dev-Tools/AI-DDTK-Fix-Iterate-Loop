# AI-DDTK Project Setup

This file was placed here by the project owner to connect this workspace to
AI-DDTK, a WordPress development toolkit installed locally on this machine.

AI-DDTK is an open-source toolkit (https://github.com/Hypercart-Dev-Tools/AI-DDTK)
that provides static analysis, browser automation, runtime profiling, and other
WordPress development tools. It is already cloned to ~/bin/ai-ddtk.

## Setup instructions (for AI agents)

Please complete these steps in order:

### 1. Verify AI-DDTK is installed

```bash
ls -d ~/bin/ai-ddtk/AGENTS.md 2>/dev/null && echo "installed" || echo "not found"
```

If not found, let the user know and stop here — the rest of the setup depends on it.

### 2. Create .mcp.local.json

Create a file called `.mcp.local.json` in this project's root directory with the
following content. Replace `HOME_DIR` with the actual home directory path for this
machine (run `echo $HOME` to get it).

```json
{
  "mcpServers": {
    "ai-ddtk": {
      "command": "node",
      "args": ["HOME_DIR/bin/ai-ddtk/tools/mcp-server/dist/src/index.js"],
      "cwd": "HOME_DIR/bin/ai-ddtk"
    }
  }
}
```

### 3. Add to .gitignore

If `.mcp.local.json` is not already in this project's `.gitignore`, add it:

```
# AI-DDTK local MCP config (contains local paths, do not commit)
.mcp.local.json
```

### 4. Add CLAUDE.md reference (Claude Code users only)

If this project has a `CLAUDE.md` file, add the following line to it. If there is
no `CLAUDE.md`, create one with just this line:

```
AI-DDTK is installed at ~/bin/ai-ddtk — see ~/bin/ai-ddtk/AGENTS.md for available tools and workflows.
```

### 5. Clean up

Once the above steps are complete, this setup file has served its purpose.
Let the user know setup is done and that they can delete this file — the
`.mcp.local.json` and `CLAUDE.md` entry handle tool discovery from here.

---

## What this enables

After setup, your editor will automatically discover AI-DDTK's MCP tools:

- **WPCC** — WordPress static analysis (security, performance, WooCommerce)
- **LocalWP** — WP-CLI commands routed through Local by Flywheel
- **Playwright Auth** — Passwordless wp-admin login and DOM inspection
- **Query Monitor** — Headless page profiling and slow query detection
- **AJAX Testing** — Structured admin-ajax.php testing
- **Tmux** — Resilient terminal sessions for long-running jobs

For full tool reference, see ~/bin/ai-ddtk/AGENTS.md.
