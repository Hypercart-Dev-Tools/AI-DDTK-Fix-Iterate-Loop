#!/bin/bash
# AI-DDTK Preflight Check
# Run this from any project to verify AI-DDTK toolkit readiness.
# Can be invoked as: ~/bin/ai-ddtk/preflight.sh
# Exit code = number of critical failures (0 = all clear)

FAIL=0
DDTK_HOME="${DDTK_HOME:-$HOME/bin/ai-ddtk}"

echo ""
echo "======================================================="
echo "AI-DDTK PREFLIGHT CHECK"
echo "======================================================="
echo ""

# 1. AI-DDTK Installation
echo "1. AI-DDTK Installation"
if [ -d "$DDTK_HOME" ]; then
    echo "   [ok] Found at $DDTK_HOME"
    if [ -f "$DDTK_HOME/AGENTS.md" ]; then
        echo "   [ok] AGENTS.md present"
    else
        echo "   [FAIL] AGENTS.md missing"
        FAIL=$((FAIL + 1))
    fi
else
    echo "   [FAIL] Not found at $DDTK_HOME"
    echo "   -> Clone: git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git $DDTK_HOME"
    FAIL=$((FAIL + 1))
fi
echo ""

# 2. AI-DDTK CLI Tools
echo "2. AI-DDTK CLI Tools"
for tool in wpcc pw-auth local-wp aiddtk-tmux wp-ajax-test; do
    if command -v "$tool" &> /dev/null; then
        echo "   [ok] $tool"
    else
        echo "   [FAIL] $tool not in PATH"
        FAIL=$((FAIL + 1))
    fi
done
echo ""

# 3. WPCC Features
echo "3. WPCC Features"
if command -v wpcc &> /dev/null; then
    pattern_count=$(wpcc --features 2>/dev/null | grep -c "pattern\|rule\|check" || true)
    if [ "$pattern_count" -gt 0 ]; then
        echo "   [ok] $pattern_count feature lines detected"
    else
        echo "   [warn] wpcc found but --features returned no recognisable output"
    fi
else
    echo "   [--] skipped (wpcc not available)"
fi
echo ""

# 4. Shell Tools
echo "4. Shell Tools"
for tool in rg php node python3 git tmux; do
    if command -v "$tool" &> /dev/null; then
        echo "   [ok] $tool"
    else
        echo "   [--] $tool (optional but recommended)"
    fi
done
echo ""

# 5. MCP Server
echo "5. MCP Server"
if [ -f "$DDTK_HOME/tools/mcp-server/dist/src/index.js" ]; then
    echo "   [ok] MCP server built"
    if [ -f .mcp.json ] || [ -f ~/.augment/settings.json ] || [ -f ~/.config/Claude/claude_desktop_config.json ]; then
        echo "   [ok] MCP config detected"
    else
        echo "   [warn] No MCP config found in current directory or editor settings"
        echo "   -> Setup: $DDTK_HOME/install.sh setup-mcp"
    fi
else
    echo "   [warn] MCP server not built yet"
    echo "   -> Build: $DDTK_HOME/install.sh setup-mcp"
fi
echo ""

# 6. WordPress Site Context
echo "6. WordPress Site Context"
if command -v local-wp &> /dev/null; then
    site_count=$(local-wp --list 2>/dev/null | grep -c . || true)
    if [ "$site_count" -gt 0 ]; then
        echo "   [ok] Local WP sites available ($site_count found)"
    else
        echo "   [warn] No Local WP sites found"
    fi
elif command -v wp &> /dev/null; then
    echo "   [ok] WP-CLI available"
else
    echo "   [--] Neither local-wp nor wp-cli found"
fi
echo ""

# 7. Summary
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
echo "  1. Run the suggested fix command"
echo "  2. Re-run preflight: $DDTK_HOME/preflight.sh"
echo ""
echo "Reference: $DDTK_HOME/AGENTS.md"
echo ""

exit "$FAIL"
