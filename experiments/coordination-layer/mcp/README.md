# tick MCP server — coordination as MCP tools (alternative to the CLI)

`tick-mcp.js` exposes the Trinity coordination verbs as typed MCP tools, so an
agent (or Claude Code) can coordinate over MCP instead of shelling out to
`../bin/tick`. It's a thin adapter — every tool calls the same `../src/` modules
the CLI does, so behaviour is identical. **CLI and MCP are interchangeable
fronts on one engine; mix freely on the same `.tick/` state.**

Zero dependencies: a minimal JSON-RPC 2.0 over newline-delimited stdio (the MCP
stdio transport). Implements `initialize`, `tools/list`, `tools/call`, `ping`.

## Tools

| Tool | CLI equivalent | Notes |
|---|---|---|
| `tick_init` | `tick init` | create `.tick/events` |
| `tick_log` | `tick log <type> <task>` | append a raw event |
| `tick_project` | `tick project` | returns STATE.md contents |
| `tick_take` | `tick take` | atomic next+claim (recommended) |
| `tick_next` | `tick next` | read-only peek |
| `tick_claim` | `tick claim` | claim a specific task |
| `tick_scope` | `tick scope` | change a claim's paths |
| `tick_release` | `tick release` | release / handoff (`to`) |
| `tick_break` | `tick break` | circuit-break |
| `tick_done` | `tick done` | complete |
| `tick_reap` | `tick reap` | coordinator liveness recovery |
| `tick_info` | `tick info` | task status/scope |
| `tick_analyze` | `tick analyze` | `format`: human \| md \| json |

Every tool accepts an optional `repo_root`. If omitted it falls back to
`TICK_REPO_ROOT`, then the enclosing git toplevel — same resolution as the CLI.
`paths` accepts an array **or** a comma string.

## Wiring into Claude Code (or any MCP client)

Add to `.mcp.json` (repo root) — see `tick.mcp.example.json` here:

```json
{
  "mcpServers": {
    "tick": {
      "command": "node",
      "args": ["experiments/coordination-layer/mcp/tick-mcp.js"],
      "env": { "TICK_REPO_ROOT": "/abs/path/to/the/coordination/workspace" }
    }
  }
}
```

Then the verbs surface as `tick_*` tools. For **Gemini CLI** and **Codex CLI**,
add the same server block to their MCP config (`~/.gemini/settings.json` /
the Codex MCP config) so peer agents coordinate over MCP too.

## When to use MCP vs CLI

- **CLI** (`bin/tick`, the harness default): simplest for headless agents that
  already run shell commands; no client wiring needed. This is what
  `harness/prompts/agent-loop.md` tells agents to use.
- **MCP**: better when the agent is an MCP client (Claude Code, or Gemini/Codex
  with MCP enabled) and you want typed tool calls, argument validation, and the
  coordination verbs to appear alongside the agent's other tools. Use the
  MCP-flavored prompt at `harness/prompts/agent-loop-mcp.md`.

## Test

```bash
node test/mcp-smoke.js     # spawns the server, drives it over JSON-RPC, asserts
```
