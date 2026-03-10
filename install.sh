#!/usr/bin/env bash
# ============================================================
# AI-DDTK Install & Maintenance Script
# Version: 1.0.39
# ============================================================
#
# ┌─────────────────────────────────────────────────────────┐
# │  SECTION 1: FOR HUMANS - Quick Start                    │
# └─────────────────────────────────────────────────────────┘
#
# INSTALLATION:
#   git clone https://github.com/Hypercart-Dev-Tools/AI-DDTK.git ~/bin/ai-ddtk
#   cd ~/bin/ai-ddtk
#   ./install.sh
#
# COMMANDS:
#   ./install.sh              # First-time setup (adds to PATH)
#   ./install.sh update       # Pull latest AI-DDTK
#   ./install.sh update-wpcc  # Pull latest WP Code Check
#   ./install.sh setup-wpcc   # Initial WPCC subtree setup
#   ./install.sh setup-mcp    # Build MCP server + show client config
#   ./install.sh status       # Show versions and status
#   ./install.sh uninstall    # Remove PATH entries
#
# USAGE FROM ANY PROJECT:
#   wpcc analyze ./wp-content/plugins/my-plugin
#   local-wp my-site plugin list
#
# ============================================================
#
# ┌─────────────────────────────────────────────────────────┐
# │  SECTION 2: FOR LLM AGENTS - Architecture & Maintenance │
# └─────────────────────────────────────────────────────────┘
#
# REPOSITORY STRUCTURE:
#   AI-DDTK/
#   ├── install.sh           # This file - install & maintenance
#   ├── bin/                  # Executable wrappers (added to PATH)
#   │   ├── wpcc              # WP Code Check wrapper
#   │   ├── wp-ajax-test      # AJAX endpoint tester
#   │   ├── pw-auth           # Playwright WP admin auth helper
#   │   ├── local-wp          # Local WP-CLI wrapper (canonical)
#   │   └── aiddtk-tmux       # Optional resilient tmux wrapper
#   ├── tools/                # Embedded tool packages and dependencies
#   │   ├── mcp-server/       # AI-DDTK MCP server package (LocalWP + pw-auth + WPCC)
#   │   └── wp-code-check/    # WPCC subtree
#   ├── temp/                 # Sensitive data, logs, analysis files
#   ├── recipes/              # Workflow recipes
#   └── AGENTS.md             # AI agent guidelines
#
# ============================================================
# LLM AGENT GUIDANCE: GIT SUBTREE OPERATIONS
# ============================================================
#
# WPCC is embedded via git subtree at: tools/wp-code-check/
# Remote: https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git
#
# --- INITIAL SETUP (run once) ---
# git subtree add --prefix=tools/wp-code-check \
#   https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git main --squash
#
# --- PULL LATEST WPCC UPDATES ---
# git subtree pull --prefix=tools/wp-code-check \
#   https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git main --squash
#
# --- PULL SPECIFIC WPCC VERSION/TAG ---
# git subtree pull --prefix=tools/wp-code-check \
#   https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git v1.2.0 --squash
#
# --- PUSH CHANGES BACK TO WPCC (if contributing) ---
# git subtree push --prefix=tools/wp-code-check \
#   https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git feature-branch
#
# ============================================================
# LLM AGENT GUIDANCE: GITHUB CLI COMMANDS
# ============================================================
#
# --- CHECK WPCC LATEST COMMIT ---
# gh api repos/Hypercart-Dev-Tools/WP-Code-Check/commits/main --jq '.sha'
#
# --- VIEW WPCC RECENT COMMITS ---
# gh api repos/Hypercart-Dev-Tools/WP-Code-Check/commits --jq '.[0:5] | .[] | "\(.sha[0:7]) \(.commit.message | split("\n")[0])"'
#
# --- LIST WPCC RELEASES ---
# gh release list --repo Hypercart-Dev-Tools/WP-Code-Check
#
# --- VIEW WPCC ISSUES ---
# gh issue list --repo Hypercart-Dev-Tools/WP-Code-Check
#
# --- CREATE PR TO WPCC ---
# gh pr create --repo Hypercart-Dev-Tools/WP-Code-Check --title "..." --body "..."
#
# --- COMPARE LOCAL VS REMOTE WPCC ---
# LOCAL_SHA=$(git log -1 --format="%H" -- tools/wp-code-check)
# REMOTE_SHA=$(gh api repos/Hypercart-Dev-Tools/WP-Code-Check/commits/main --jq '.sha')
# [ "$LOCAL_SHA" = "$REMOTE_SHA" ] && echo "Up to date" || echo "Updates available"
#
# ============================================================
# LLM AGENT GUIDANCE: MAINTENANCE NOTES
# ============================================================
#
# - This script is IDEMPOTENT (safe to run multiple times)
# - It modifies shell config (~/.zshrc or ~/.bashrc)
# - It does NOT require sudo
# - PATH entry format: export PATH="$HOME/bin/ai-ddtk/bin:$PATH"
# - If WPCC is later merged into AI-DDTK, update bin/wpcc wrapper
# - All tools should be callable from any directory
#
# FUTURE TOOLS TO ADD:
# - Remove the repo-root local-wp compatibility shim after deprecation
# - Add playwright wrapper if needed
# - Add pixelmatch wrapper if needed
#
# ============================================================
#
# ┌─────────────────────────────────────────────────────────┐
# │  SECTION 3: EXECUTABLE SCRIPT                           │
# └─────────────────────────────────────────────────────────┘

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
TOOLS_DIR="$SCRIPT_DIR/tools"
WPCC_DIR="$TOOLS_DIR/wp-code-check"
WPCC_REMOTE="https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git"

# Detect shell config file
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
else
    SHELL_CONFIG="$HOME/.bashrc"
fi

PATH_ENTRY="export PATH=\"$BIN_DIR:\$PATH\""

# ============================================================
# FUNCTIONS
# ============================================================

show_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     AI-DDTK - AI Driven Development ToolKit           ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_usage() {
    show_banner
    echo "Usage: ./install.sh [command]"
    echo ""
    echo "Commands:"
    echo "  (none)        First-time installation"
    echo "  update        Pull latest AI-DDTK changes"
    echo "  update-wpcc   Pull latest WP Code Check"
    echo "  setup-wpcc    Initial WPCC subtree setup"
    echo "  setup-mcp     Build MCP server + show client config"
    echo "  doctor-playwright  Run pw-auth doctor via install.sh convenience wrapper"
    echo "  status        Show versions and status"
    echo "  uninstall     Remove PATH entries"
    echo ""
    echo "Optional tools after install:"
    echo "  aiddtk-tmux --help   Resilient tmux-backed sessions for AI agents"
    echo "  local-wp --help      Local by Flywheel WP-CLI wrapper"
    echo ""
}

show_tmux_status() {
    if command -v tmux >/dev/null 2>&1; then
        TMUX_VERSION="$(tmux -V 2>/dev/null || echo installed)"
        echo -e "  tmux: ${GREEN}✓ Available${NC} ($TMUX_VERSION)"
    else
        echo -e "  tmux: ${YELLOW}○ Optional / not installed${NC} (brew install tmux)"
    fi
}

install_path() {
    echo -e "${CYAN}Setting up PATH...${NC}"

    # Check if already in PATH (use BIN_DIR to match actual path)
    if grep -q "$BIN_DIR" "$SHELL_CONFIG" 2>/dev/null; then
        echo -e "${GREEN}✓ PATH already configured in $SHELL_CONFIG${NC}"
    else
        echo "" >> "$SHELL_CONFIG"
        echo "# AI-DDTK - AI Driven Development ToolKit" >> "$SHELL_CONFIG"
        echo "$PATH_ENTRY" >> "$SHELL_CONFIG"
        echo -e "${GREEN}✓ Added to $SHELL_CONFIG${NC}"
    fi

    # Make scripts executable
    chmod +x "$BIN_DIR"/* 2>/dev/null || true

    echo ""
    echo -e "${YELLOW}Run this to activate now:${NC}"
    echo "  source $SHELL_CONFIG"
}

setup_wpcc() {
    echo -e "${CYAN}Setting up WP Code Check via git subtree...${NC}"

    if [ -d "$WPCC_DIR" ] && [ "$(ls -A "$WPCC_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}WPCC already exists at $WPCC_DIR${NC}"
        echo "Use './install.sh update-wpcc' to pull updates"
        return 0
    fi

    cd "$SCRIPT_DIR"
    git subtree add --prefix=tools/wp-code-check "$WPCC_REMOTE" main --squash

    echo -e "${GREEN}✓ WP Code Check installed${NC}"
}

update_wpcc() {
    echo -e "${CYAN}Updating WP Code Check...${NC}"

    if [ ! -d "$WPCC_DIR" ]; then
        echo -e "${RED}WPCC not found. Run './install.sh setup-wpcc' first${NC}"
        return 1
    fi

    cd "$SCRIPT_DIR"
    git subtree pull --prefix=tools/wp-code-check "$WPCC_REMOTE" main --squash

    echo -e "${GREEN}✓ WP Code Check updated${NC}"
}

update_toolkit() {
    echo -e "${CYAN}Updating AI-DDTK...${NC}"
    cd "$SCRIPT_DIR"
    git pull origin main
    echo -e "${GREEN}✓ AI-DDTK updated${NC}"
}

show_status() {
    show_banner

    echo -e "${CYAN}Installation Status:${NC}"
    echo "  Toolkit Root: $SCRIPT_DIR"
    echo "  Bin Directory: $BIN_DIR"
    echo "  Shell Config: $SHELL_CONFIG"
    echo ""

    # Check PATH (use BIN_DIR to match actual path)
    if grep -q "$BIN_DIR" "$SHELL_CONFIG" 2>/dev/null; then
        echo -e "  PATH: ${GREEN}✓ Configured${NC}"
    else
        echo -e "  PATH: ${RED}✗ Not configured${NC}"
    fi

    # Check WPCC
    if [ -d "$WPCC_DIR" ] && [ "$(ls -A "$WPCC_DIR" 2>/dev/null)" ]; then
        WPCC_COMMIT=$(git log -1 --format="%h %s" -- tools/wp-code-check 2>/dev/null || echo "unknown")
        echo -e "  WPCC: ${GREEN}✓ Installed${NC} ($WPCC_COMMIT)"
    else
        echo -e "  WPCC: ${YELLOW}✗ Not installed${NC} (run './install.sh setup-wpcc')"
    fi

    # Check MCP server
    local MCP_ENTRY="$TOOLS_DIR/mcp-server/dist/src/index.js"
    if [ -f "$MCP_ENTRY" ]; then
        MCP_VER=$(node -e "import('$MCP_ENTRY').then(m => {})" 2>&1 | head -1 || echo "built")
        echo -e "  MCP Server: ${GREEN}✓ Built${NC} ($TOOLS_DIR/mcp-server)"
    elif [ -d "$TOOLS_DIR/mcp-server" ]; then
        echo -e "  MCP Server: ${YELLOW}○ Not built${NC} (run './install.sh setup-mcp')"
    else
        echo -e "  MCP Server: ${YELLOW}✗ Not found${NC}"
    fi

    show_tmux_status

    echo ""
    echo -e "${CYAN}Available Tools:${NC}"
    for tool in "$BIN_DIR"/*; do
        if [ -f "$tool" ] && [ -x "$tool" ]; then
            echo "  - $(basename "$tool")"
        fi
    done
}

setup_mcp() {
    local MCP_DIR="$TOOLS_DIR/mcp-server"

    echo -e "${CYAN}Setting up AI-DDTK MCP Server...${NC}"

    if [ ! -d "$MCP_DIR" ]; then
        echo -e "${RED}MCP server not found at $MCP_DIR${NC}"
        return 1
    fi

    # Check Node.js
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}Node.js is required but not installed.${NC}"
        echo "Install via: brew install node"
        return 1
    fi

    NODE_VERSION="$(node -v)"
    echo -e "  Node.js: ${GREEN}✓${NC} $NODE_VERSION"

    # Install dependencies
    echo -e "${CYAN}Installing dependencies...${NC}"
    cd "$MCP_DIR"
    npm install --ignore-scripts 2>&1 | tail -1

    # Build
    echo -e "${CYAN}Building MCP server...${NC}"
    npm run build 2>&1 | tail -3

    echo -e "${GREEN}✓ MCP server built successfully${NC}"
    echo ""

    # Show config snippets
    local MCP_ENTRY="$MCP_DIR/dist/src/index.js"

    echo -e "${CYAN}Client Configuration:${NC}"
    echo ""
    echo -e "${YELLOW}Claude Code (.mcp.json — already in repo root):${NC}"
    echo "  Auto-detected when you open the project."
    echo ""
    echo -e "${YELLOW}Claude Desktop (add to ~/Library/Application Support/Claude/claude_desktop_config.json):${NC}"
    echo "  \"ai-ddtk\": {"
    echo "    \"command\": \"node\","
    echo "    \"args\": [\"$MCP_ENTRY\"],"
    echo "    \"cwd\": \"$SCRIPT_DIR\""
    echo "  }"
    echo ""
    echo -e "${YELLOW}Cline (VS Code > Cline > MCP Servers > Edit Config):${NC}"
    echo "  \"ai-ddtk\": {"
    echo "    \"command\": \"node\","
    echo "    \"args\": [\"$MCP_ENTRY\"],"
    echo "    \"cwd\": \"$SCRIPT_DIR\""
    echo "  }"
    echo ""
    echo -e "${YELLOW}HTTP/SSE mode (for remote or multi-client use):${NC}"
    echo "  node $MCP_ENTRY --http"
    echo "  Bearer token stored in: ~/.ai-ddtk/mcp-token"
    echo ""
    echo "Reference configs available in: $MCP_DIR/mcp-configs/"
}

doctor_playwright() {
    echo -e "${CYAN}Running Playwright readiness doctor...${NC}"
    echo ""

    if [ ! -x "$BIN_DIR/pw-auth" ]; then
        echo -e "${RED}pw-auth not found or not executable at: $BIN_DIR/pw-auth${NC}"
        return 1
    fi

    "$BIN_DIR/pw-auth" doctor "$@"
}

uninstall() {
    echo -e "${CYAN}Removing AI-DDTK from PATH...${NC}"

    if [ -f "$SHELL_CONFIG" ]; then
        # Remove the PATH entry and comment
        sed -i.bak '/AI-DDTK/d' "$SHELL_CONFIG"
        sed -i.bak '/ai-ddtk\/bin/d' "$SHELL_CONFIG"
        rm -f "${SHELL_CONFIG}.bak"
        echo -e "${GREEN}✓ Removed from $SHELL_CONFIG${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Note: This only removes PATH entries.${NC}"
    echo "To fully remove, delete: $SCRIPT_DIR"
}

# ============================================================
# MAIN
# ============================================================

case "${1:-}" in
    "")
        show_banner
        echo -e "${CYAN}Installing AI-DDTK...${NC}"
        echo ""
        install_path
        echo ""
        echo -e "${GREEN}Installation complete!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Run: source $SHELL_CONFIG"
        echo "  2. Run: ./install.sh setup-wpcc"
        echo "  3. Test: wpcc --help"
        echo "  4. Optional: aiddtk-tmux --help"
        ;;
    update)
        update_toolkit
        ;;
    update-wpcc)
        update_wpcc
        ;;
    setup-wpcc)
        setup_wpcc
        ;;
    setup-mcp)
        setup_mcp
        ;;
    doctor-playwright)
        shift
        doctor_playwright "$@"
        ;;
    status)
        show_status
        ;;
    uninstall)
        uninstall
        ;;
    -h|--help|help)
        show_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_usage
        exit 1
        ;;
esac

