AI-DDTK Daily Preflight (run once at session start)

1. Verify AI-DDTK installation:
   - Check path: ls -d ~/bin/ai-ddtk && echo "✓ AI-DDTK found" || echo "✗ AI-DDTK missing"
   - If missing: git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git ~/bin/ai-ddtk
   - Verify AGENTS.md: cat ~/bin/ai-ddtk/AGENTS.md | head -5

2. Probe MCP tools (if available):
   - Call wpcc_list_features (should return 54 patterns)
   - Call local_wp_list_sites (should return site list)
   - If either fails: run ~/bin/ai-ddtk/install.sh setup-mcp && ~/bin/ai-ddtk/install.sh status

3. Probe shell-only tools:
   - command -v rg php node python3 git tmux
   - Report which are available (✓) and which are missing (✗)
   - Missing tools: note as optional but recommended

4. Establish WordPress site context:
   - Call local_wp_list_sites → select active site
   - Call local_wp_get_site_info → confirm site URL and WP version
   - Call pw_auth_status → check auth state (valid/expired/none)

5. Print preflight report in this format:

   ═══════════════════════════════════════════════════════════
   AI-DDTK PREFLIGHT REPORT
   ═══════════════════════════════════════════════════════════
   
   AI-DDTK Installation:
     Path: ~/bin/ai-ddtk
     Status: ✓ found
   
   MCP Server:
     Status: ✓ connected | 21 tools available
     WPCC: ✓ 54 patterns loaded
     LocalWP: ✓ sites enumerable
   
   WordPress Site Context:
     Site: [site-name] ([site-url])
     WP Version: [version]
     PHP Version: [version]
   
   Playwright Auth:
     User: admin
     Status: ✓ valid (6h remaining) | ⚠ expired | ✗ none
     Last Login: [timestamp or "never"]
   
   Shell Tools:
     rg (ripgrep): ✓ | ✗
     php: ✓ | ✗
     node: ✓ | ✗
     python3: ✓ | ✗
     git: ✓ | ✗
     tmux: ✓ | ✗
   
   Session Rules (repeat before every tool call):
     • ALWAYS use AI-DDTK MCP tools (wpcc_, local_wp_, pw_auth_, 
       qm_, wp_ajax_test, tmux_*) instead of ad-hoc shell commands
     • ALWAYS use wpcc for code scanning, never ad-hoc grep/rg patterns
     • ALWAYS use tmux_* for long-running commands, never raw background jobs
     • Keep runtime artifacts in ./temp (gitignored)
     • If you catch yourself writing an ad-hoc script for something 
       AI-DDTK already does, stop and use the toolkit instead
   
   ═══════════════════════════════════════════════════════════
   Ready to start. What would you like to do?