Out-of-the-box suggestions
1. MCP tool descriptions as the preflight itself

Instead of a separate preflight doc, enrich each MCP tool's description field with trigger context. When the MCP server registers wpcc_run_scan, its description could say: "Static analysis for WordPress code. Use when the user mentions scan, audit, security check, or performance review." The agent never needs to read AGENTS.md to know when to use it — the tool catalog is the routing table. You could generate these descriptions from the Workflow Triggers table at build time so they stay in sync.

2. A ddtk-context MCP tool that agents call instead of reading docs

Add a single meta-tool like ddtk_get_context that returns a compact JSON payload: installed tools, active site, auth status, available features. An agent that sees this tool in its list can call it on demand rather than running a shell script or parsing markdown. This is essentially the MCP-aware preflight but as a tool call, not a prompt.

3. .mcp.json generator for consuming projects

The gap right now is: someone clones AI-DDTK to ~/bin/ai-ddtk, but their WordPress project at ~/sites/my-theme/ doesn't have a .mcp.json pointing to the server. You could add an install.sh wire-project command that drops a .mcp.json into the current directory. Now every project the user works in automatically gets MCP tool discovery without any manual configuration or preflight prompts.

4. Hook into Claude Code's user-prompt-submit hook

Claude Code supports hooks that run on events. A user-prompt-submit hook could run a lightweight version of preflight.sh and inject the result as context — "AI-DDTK is installed, 21 MCP tools connected, active site: my-site.local." This is the "capability routing by the runtime" pattern: the harness tells the model what's available before it even starts reasoning.

Option 3 is probably the highest-leverage, lowest-effort move — it solves the core "agent in another project doesn't know AI-DDTK exists" problem at the infrastructure layer. Option 2 is the most elegant long-term. Thoughts on any of these?