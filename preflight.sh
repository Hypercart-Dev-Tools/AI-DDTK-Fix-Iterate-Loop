#!/bin/bash
# AI-DDTK Preflight Check
# Run this once at the start of each work session to verify toolkit readiness

set -e

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "AI-DDTK PREFLIGHT CHECK"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. AI-DDTK Installation
echo "1️⃣  AI-DDTK Installation"
if [ -d ~/bin/ai-ddtk ]; then
    echo "   ✓ Found at ~/bin/ai-ddtk"
    if [ -f ~/bin/ai-ddtk/AGENTS.md ]; then
        echo "   ✓ AGENTS.md present"
    else
        echo "   ✗ AGENTS.md missing"
    fi
else
    echo "   ✗ Not found at ~/bin/ai-ddtk"
    echo "   → Clone: git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git ~/bin/ai-ddtk"
fi
echo ""

# 2. Shell Tools
echo "2️⃣  Shell Tools"
for tool in rg php node python3 git tmux; do
    if command -v "$tool" &> /dev/null; then
        echo "   ✓ $tool"
    else
        echo "   ✗ $tool (optional but recommended)"
    fi
done
echo ""

# 3. WPCC
echo "3️⃣  WPCC (WP Code Check)"
if command -v wpcc &> /dev/null; then
    echo "   ✓ wpcc available"
    wpcc --features 2>/dev/null | head -1 || echo "   ⚠ wpcc found but --features failed"
else
    echo "   ✗ wpcc not in PATH"
    if [ -d ~/bin/ai-ddtk ]; then
        echo "   → Run: ~/bin/ai-ddtk/install.sh setup-wpcc"
    else
        echo "   → First install AI-DDTK: git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git ~/bin/ai-ddtk"
    fi
fi
echo ""

# 4. MCP Server (if available)
echo "4️⃣  MCP Server"
if [ -f ~/bin/ai-ddtk/tools/mcp-server/dist/src/index.js ]; then
    echo "   ✓ MCP server built"
    if [ -f ~/.augment/settings.json ] || [ -f ~/.config/Claude/claude_desktop_config.json ]; then
        echo "   ✓ MCP config found"
        echo "   → MCP tools should be available in your editor"
    else
        echo "   ⚠ MCP config not detected in editor"
        echo "   → Setup: ~/bin/ai-ddtk/install.sh setup-mcp (shows config snippets)"
    fi
else
    echo "   ⚠ MCP server not built yet"
    echo "   → Build: ~/bin/ai-ddtk/install.sh setup-mcp"
fi
echo ""

# 5. WordPress Site Context
echo "5️⃣  WordPress Site Context"
if command -v local-wp &> /dev/null; then
    site_count=$(local-wp --list 2>/dev/null | wc -l)
    if [ "$site_count" -gt 0 ]; then
        echo "   ✓ Local WP sites available"
        echo "   → Select a site before starting work"
    else
        echo "   ⚠ No Local WP sites found"
    fi
elif command -v wp &> /dev/null; then
    echo "   ✓ WP-CLI available"
    echo "   → Verify WordPress is running and accessible"
else
    echo "   ✗ WP-CLI not found"
fi
echo ""

# 6. Summary
echo "═══════════════════════════════════════════════════════════"
echo "PREFLIGHT SUMMARY"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "✓ Preflight check complete!"
echo ""
echo "If you see any ✗ or ⚠ items above:"
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

