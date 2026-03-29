# AI-DDTK Preflight Checklist

A diagnostic checklist for AI agents working in **any WordPress project** where AI-DDTK has been installed locally. This is not specific to the AI-DDTK repo itself — it's designed for agents operating in theme, plugin, or site workspaces where the user has AI-DDTK available as an external toolkit.

AI-DDTK is typically installed at `~/bin/ai-ddtk`. If the user has it, the MCP server may already be wired into their editor, giving you access to tools like `wpcc_*`, `local_wp_*`, `pw_auth_*`, `qm_*`, and `tmux_*` without any shell commands.

---

## When to use this

Run through this checklist at the start of a session when:
- You're in a WordPress project and want to know what toolkit support is available
- The user mentions AI-DDTK, WPCC, or scanning/profiling tools
- You see MCP tools with `ai-ddtk` prefixes in your tool list and want to confirm they work

If none of the above apply, skip this entirely.

> **If you're working inside the AI-DDTK repo itself** (`~/bin/ai-ddtk` or a clone), skip this checklist — the toolkit _is_ the project. Read `AGENTS.md` directly for workflow guidance.

---

## Steps

### 1. Check if AI-DDTK is installed

```bash
ls -d ~/bin/ai-ddtk 2>/dev/null && echo "installed" || echo "not installed"
```

If installed, the user has access to WPCC (static analysis), LocalWP helpers, Playwright auth, Query Monitor profiling, and more. Reference docs are at `~/bin/ai-ddtk/AGENTS.md`.

If not installed, none of the below applies — proceed with standard tools.

### 2. Check for MCP tools in the current session

Look at your available tool list. If you see tools prefixed with `ai-ddtk` (e.g., `wpcc_list_features`, `local_wp_list_sites`), the MCP server is connected and you can use them directly.

If MCP tools are not visible:
- The user may need to run `~/bin/ai-ddtk/install.sh setup-mcp` to build the server
- Or the editor may need a `.mcp.json` pointing to the server — check `~/bin/ai-ddtk/AGENTS.md` for setup instructions
- This is not a blocker — you can still use the shell CLI tools (`wpcc`, `pw-auth`, `local-wp`, `aiddtk-tmux`) if they're in PATH

### 3. Check shell tools

```bash
command -v wpcc pw-auth local-wp aiddtk-tmux rg php node python3 git tmux
```

AI-DDTK CLI tools (`wpcc`, `pw-auth`, `local-wp`, `aiddtk-tmux`) are added to PATH by the installer. The rest (`rg`, `php`, `node`, etc.) are general dependencies — optional but recommended.

Report what's available. Missing items are worth noting to the user but are not blockers for most tasks.

### 4. Establish WordPress site context (if relevant)

If the current task involves a WordPress site:
- MCP available: call `local_wp_list_sites` then `local_wp_get_site_info` for the target site
- Shell only: `local-wp --list` or `wp option get siteurl`
- Optionally check Playwright auth: `pw_auth_status` (MCP) or `pw-auth status` (shell)

Skip this step if the task doesn't involve a live WordPress site.

### 5. Summarise what's available

Give the user a brief summary of what you found. Example:

```
AI-DDTK: installed at ~/bin/ai-ddtk
MCP tools: 21 tools connected (wpcc, local_wp, pw_auth, qm, tmux)
WPCC: available, 54 patterns
Site: my-site.local (WP 6.7, PHP 8.2)
Auth: admin session valid
Shell: rg, php, node, python3, git, tmux — all available
```

Only include sections for things that are actually present. If MCP isn't connected, just say so and list the shell tools that are available instead.

---

## Notes

- This checklist helps you discover what's available — it does not change how you should behave. Tool usage guidance is in `~/bin/ai-ddtk/AGENTS.md`, which the user can add to their project's `CLAUDE.md` (Claude Code) or `AGENTS.md` (Augment Code, OpenAI Agents) if they want it applied.
- If AI-DDTK is not installed, disregard this checklist entirely and work with whatever tools are available in the current environment.

---

<!-- TODO: Multi-client MCP genericisation — delete this section when complete -->
## TODO: Multi-client MCP generics

Tracked here for visibility. Reference: VS Code full MCP spec blog post (June 2025) + analysis in chat.

> **Context:** The MCP server itself is generic. The wiring/onboarding layer is Claude Code-first.
> Goal: support VS Code Copilot, Augment Code, and Cursor without breaking Claude Code.

### Phase 1 — Config portability ✅

- [x] Add `tools/mcp-server/mcp-configs/vscode.json` template using VS Code Copilot schema (`"servers"` root key, `"type": "stdio"`)
- [x] Add `tools/mcp-server/mcp-configs/cursor.json` template (uses same `"mcpServers"` schema as Claude Code)
- [x] Retitle `.mcp.README.md` from "for Claude Code" to client-agnostic — now includes client config reference table
- [x] VS Code extension now auto-registers via `contributes.mcpServerDefinitionProviders` — Copilot/Cline see it with no config files needed
- [x] Add VS Code Copilot + Cursor setup instructions to `AGENTS.md` (alongside Claude Code / Augment Code sections; includes workspace-vs-home config rationale)
- [x] Document the two config schemas side-by-side in `.mcp.README.md` client table

### Phase 2 — `wire-project` multi-client

- [x] Detect VS Code and write `.vscode/mcp.json` (VS Code Copilot format) in addition to `.mcp.local.json`
- [x] Detect Augment Code (`~/.augment/`) and merge entry into `~/.augment/settings.json`
- [x] Detect Cursor (`~/.cursor/`) and write `~/.cursor/mcp.json`
- [x] Write `AGENTS.md` reference in addition to `CLAUDE.md` (Augment Code and OpenAI agents read `AGENTS.md`, not `CLAUDE.md`)
- [x] Add `--client` flag (`--client=claude-code|vscode|augment|cursor|all`) for non-interactive use
- [x] `.mcp.local.json` and `.vscode/mcp.json` are both gitignored in generated projects
- [x] Add `tools/mcp-server/mcp-configs/cursor.json` template

### Phase 3 — MCP server full-spec primitives (stretch) ✅

- [x] Add MCP **Prompts** for common AI-DDTK workflows — registered `preflight`, `scan`, `profile-page`, `triage-scan`, `wire-project` via `server.registerPrompt()`; surface as slash commands in VS Code Copilot (`/mcp.ai-ddtk.<name>`)
- [x] Verify MCP **Resources** (`wpcc://latest-scan`, `wpcc://latest-report`, `wpcc://scan/{id}`, `auth://status/{user}`) — confirmed registered with correct MIME types and URI templates
- [x] Evaluate MCP **Sampling** — `server.createMessage()` available in SDK; **decision: wait for client adoption**. Rationale: as of 2026-03, GitHub Copilot and Augment Code do not yet expose Sampling to MCP servers; Claude Code supports it but requires explicit user opt-in per the MCP spec. Implementing it now would be Claude Code-only, contradicting the genericisation goal. Revisit when ≥2 major clients ship stable Sampling support. Candidates when that threshold is reached: on-server WPCC triage summarisation, automated fix suggestions.
<!-- END TODO -->
