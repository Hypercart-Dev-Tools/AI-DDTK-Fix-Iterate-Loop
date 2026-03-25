#!/bin/bash
# AI-DDTK Preflight Check
# Run this once at the start of each work session to verify toolkit readiness
# Exit code = number of critical failures (0 = all clear)

FAIL=0

echo ""
echo "======================================================="
echo "AI-DDTK PREFLIGHT CHECK"
echo "======================================================="
echo ""

# 1. AI-DDTK Installation
echo "1. AI-DDTK Installation"
if [ -d ~/bin/ai-ddtk ]; then
    echo "   [ok] Found at ~/bin/ai-ddtk"
    if [ -f ~/bin/ai-ddtk/AGENTS.md ]; then
        echo "   [ok] AGENTS.md present"
    else
        echo "   [FAIL] AGENTS.md missing"
        FAIL=$((FAIL + 1))
    fi
else
    echo "   [FAIL] Not found at ~/bin/ai-ddtk"
    echo "   -> Clone: git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git ~/bin/ai-ddtk"
    FAIL=$((FAIL + 1))
fi
echo ""

# 2. Shell Tools
echo "2. Shell Tools"
for tool in rg php node python3 git tmux; do
    if command -v "$tool" &> /dev/null; then
        echo "   [ok] $tool"
    else
        echo "   [--] $tool (optional but recommended)"
    fi
done
echo ""

# 3. WPCC
echo "3. WPCC (WP Code Check)"
if command -v wpcc &> /dev/null; then
    echo "   [ok] wpcc available"
    pattern_count=$(wpcc --features 2>/dev/null | grep -c "pattern\|rule\|check" || true)
    if [ "$pattern_count" -gt 0 ]; then
        echo "   [ok] $pattern_count feature lines detected"
    else
        echo "   [warn] wpcc found but --features returned no recognisable output"
    fi
else
    echo "   [FAIL] wpcc not in PATH"
    if [ -d ~/bin/ai-ddtk ]; then
        echo "   -> Run: ~/bin/ai-ddtk/install.sh setup-wpcc"
    else
        echo "   -> First install AI-DDTK: git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git ~/bin/ai-ddtk"
    fi
    FAIL=$((FAIL + 1))
fi
echo ""

# 4. MCP Server (if available)
echo "4. MCP Server"
if [ -f ~/bin/ai-ddtk/tools/mcp-server/dist/src/index.js ]; then
    echo "   [ok] MCP server built"
    if [ -f .mcp.json ] || [ -f ~/.augment/settings.json ] || [ -f ~/.config/Claude/claude_desktop_config.json ]; then
        echo "   [ok] MCP config found"
        echo "   -> MCP tools should be available in your editor"
    else
        echo "   [warn] MCP config not detected in editor"
        echo "   -> Setup: ~/bin/ai-ddtk/install.sh setup-mcp (shows config snippets)"
    fi
else
    echo "   [warn] MCP server not built yet"
    echo "   -> Build: ~/bin/ai-ddtk/install.sh setup-mcp"
fi
echo ""

# 5. WordPress Site Context
echo "5. WordPress Site Context"
if command -v local-wp &> /dev/null; then
    site_count=$(local-wp --list 2>/dev/null | grep -c . || true)
    if [ "$site_count" -gt 0 ]; then
        echo "   [ok] Local WP sites available ($site_count found)"
        echo "   -> Select a site before starting work"
    else
        echo "   [warn] No Local WP sites found"
    fi
elif command -v wp &> /dev/null; then
    echo "   [ok] WP-CLI available"
    echo "   -> Verify WordPress is running and accessible"
else
    echo "   [--] Neither local-wp nor wp-cli found"
fi
echo ""

# 6. Summary
echo "======================================================="
echo "PREFLIGHT SUMMARY"
echo "======================================================="
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "[ok] All critical checks passed."
else
    echo "[!!] $FAIL critical issue(s) found — see above."
fi
echo ""
echo "If you see any [FAIL] or [warn] items above:"
echo "  1. Run the suggested command (e.g., install.sh setup-mcp)"
echo "  2. Re-run this preflight: ./preflight.sh"
echo ""
echo "Before starting work:"
echo "  1. Select your WordPress site (Local WP or wp-cli)"
echo "  2. Verify Playwright auth: pw-auth status"
echo "  3. Start your task!"
echo ""
echo "For full details, see:"
echo "  - ~/bin/ai-ddtk/AGENTS.md (agent guidelines)"
echo "  - ~/bin/ai-ddtk/install.sh status (detailed status)"
echo ""

exit "$FAIL"
