#!/usr/bin/env bash
# ============================================================
# AI-DDTK Install & Maintenance Script
# Version: 1.2.1
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
#   ./install.sh setup-mcp    # Build MCP server + show launcher-based client config
#   ./install.sh status       # Show versions and status
#   ./install.sh uninstall    # Remove PATH entries
#
# USAGE FROM ANY PROJECT:
#   wpcc analyze ./wp-content/plugins/my-plugin
#   local-wp my-site plugin list
#
# For AI agent maintenance notes and subtree/GitHub command references, see:
#   docs/INSTALL-AGENT-NOTES.md
#
# ============================================================
#
# ┌─────────────────────────────────────────────────────────┐
# │  SECTION 3: EXECUTABLE SCRIPT                           │
# └─────────────────────────────────────────────────────────┘

set -euo pipefail

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
if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
else
    SHELL_CONFIG="$HOME/.bashrc"
fi

PATH_ENTRY="export PATH=\"$BIN_DIR:\$PATH\""
PATH_BEGIN_MARKER="# >>> AI-DDTK >>>"
PATH_END_MARKER="# <<< AI-DDTK <<<"
NODE_MIN_MAJOR=18

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
    echo "  setup-mcp     Build MCP server + show launcher-based client config"
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

ensure_shell_config_exists() {
    if [ ! -f "$SHELL_CONFIG" ]; then
        touch "$SHELL_CONFIG"
    fi
}

node_major_version() {
    local version_string
    version_string="$(node -v 2>/dev/null || true)"
    echo "${version_string#v}" | cut -d. -f1
}

node_version_status() {
    if ! command -v node >/dev/null 2>&1; then
        echo "missing"
        return 0
    fi

    local major
    major="$(node_major_version)"
    if [ -z "$major" ]; then
        echo "unknown"
        return 0
    fi

    if [ "$major" -ge "$NODE_MIN_MAJOR" ]; then
        echo "ok"
    else
        echo "too_old"
    fi
}

check_node_requirement() {
    local status
    status="$(node_version_status)"

    case "$status" in
        ok)
            echo -e "  Node.js: ${GREEN}✓${NC} $(node -v)"
            ;;
        too_old)
            echo -e "${RED}Node.js $(node -v) detected, but setup-mcp requires >= v${NODE_MIN_MAJOR}.x${NC}"
            echo "Install/upgrade Node via: brew install node"
            return 1
            ;;
        missing)
            echo -e "${RED}Node.js is required but not installed.${NC}"
            echo "Install via: brew install node"
            return 1
            ;;
        *)
            echo -e "${RED}Unable to determine Node.js version.${NC}"
            return 1
            ;;
    esac
}

print_next_steps_block() {
    echo ""
    echo -e "${CYAN}Next steps (copy/paste):${NC}"
    cat <<EOF
source "$SHELL_CONFIG"
./install.sh status
wpcc --help
aiddtk-tmux --help
EOF
}

run_npm_step() {
    local title="$1"
    shift
    local log_file
    log_file="$(mktemp)"

    echo -e "${CYAN}${title}...${NC}"
    if "$@" >"$log_file" 2>&1; then
        tail -n 3 "$log_file"
        rm -f "$log_file"
        return 0
    fi

    echo -e "${RED}${title} failed.${NC}"
    tail -n 40 "$log_file"
    rm -f "$log_file"
    return 1
}

preflight_summary() {
    echo -e "${CYAN}Preflight summary:${NC}"
    echo "  OS: $(uname -s)"
    echo "  Shell config target: $SHELL_CONFIG"

    if command -v git >/dev/null 2>&1; then
        echo -e "  git: ${GREEN}✓${NC} $(git --version | awk '{print $3}')"
    else
        echo -e "  git: ${RED}✗ Missing${NC}"
    fi

    local node_status
    node_status="$(node_version_status)"
    case "$node_status" in
        ok)
            echo -e "  Node: ${GREEN}✓${NC} $(node -v) (meets >= v${NODE_MIN_MAJOR})"
            ;;
        too_old)
            echo -e "  Node: ${YELLOW}○${NC} $(node -v) (below >= v${NODE_MIN_MAJOR})"
            ;;
        missing)
            echo -e "  Node: ${YELLOW}○ Missing${NC}"
            ;;
        *)
            echo -e "  Node: ${YELLOW}○ Unknown${NC}"
            ;;
    esac

    ensure_shell_config_exists
    if grep -Fq "$PATH_BEGIN_MARKER" "$SHELL_CONFIG" && grep -Fq "$PATH_END_MARKER" "$SHELL_CONFIG"; then
        echo -e "  PATH block: ${GREEN}✓ Configured${NC}"
    elif grep -Fq "$BIN_DIR" "$SHELL_CONFIG"; then
        echo -e "  PATH block: ${YELLOW}○ Legacy entry detected${NC}"
    else
        echo -e "  PATH block: ${YELLOW}○ Not configured${NC}"
    fi

    if command -v wpcc >/dev/null 2>&1; then
        echo -e "  wpcc in PATH: ${GREEN}✓ Yes${NC}"
    else
        echo -e "  wpcc in PATH: ${YELLOW}○ No${NC}"
    fi

    local MCP_ENTRY="$TOOLS_DIR/mcp-server/dist/src/index.js"
    if [ -f "$MCP_ENTRY" ]; then
        echo -e "  MCP build: ${GREEN}✓ Present${NC}"
    else
        echo -e "  MCP build: ${YELLOW}○ Not built yet${NC}"
    fi
}

remove_path_block_and_legacy() {
    ensure_shell_config_exists
    local tmp_file
    tmp_file="$(mktemp)"

    awk -v start="$PATH_BEGIN_MARKER" -v end="$PATH_END_MARKER" '
    $0 == start { in_block=1; next }
    $0 == end { in_block=0; next }
    !in_block { print }
    ' "$SHELL_CONFIG" > "$tmp_file"

    awk '!/AI-DDTK - AI Driven Development ToolKit/ && !/ai-ddtk\/bin/' "$tmp_file" > "${tmp_file}.clean"
    mv "${tmp_file}.clean" "$SHELL_CONFIG"
    rm -f "$tmp_file"
}

install_path() {
    echo -e "${CYAN}Setting up PATH...${NC}"

    ensure_shell_config_exists

    if grep -Fq "$PATH_BEGIN_MARKER" "$SHELL_CONFIG" && grep -Fq "$PATH_END_MARKER" "$SHELL_CONFIG"; then
        echo -e "${GREEN}✓ PATH already configured in $SHELL_CONFIG${NC}"
    else
        remove_path_block_and_legacy
        echo "" >> "$SHELL_CONFIG"
        echo "$PATH_BEGIN_MARKER" >> "$SHELL_CONFIG"
        echo "# AI-DDTK - AI Driven Development ToolKit" >> "$SHELL_CONFIG"
        echo "$PATH_ENTRY" >> "$SHELL_CONFIG"
        echo "$PATH_END_MARKER" >> "$SHELL_CONFIG"
        echo -e "${GREEN}✓ Added to $SHELL_CONFIG${NC}"
    fi

    # Make scripts executable
    chmod +x "$BIN_DIR"/* 2>/dev/null || true
    chmod +x "$TOOLS_DIR/mcp-server/start.sh" 2>/dev/null || true

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
    local CURRENT_BRANCH
    local UPSTREAM_REF

    CURRENT_BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [ -z "$CURRENT_BRANCH" ]; then
        echo -e "${RED}Cannot update from a detached HEAD.${NC}"
        echo "Checkout a branch first, then rerun './install.sh update'."
        return 1
    fi

    UPSTREAM_REF="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

    echo "  Branch: $CURRENT_BRANCH"
    if [ -n "$UPSTREAM_REF" ]; then
        echo "  Upstream: $UPSTREAM_REF"
        git pull --ff-only
    else
        echo "  Upstream: not configured, falling back to origin/$CURRENT_BRANCH"
        git pull --ff-only origin "$CURRENT_BRANCH"
    fi

    echo -e "${GREEN}✓ AI-DDTK updated${NC}"
}

show_status() {
    show_banner

    echo -e "${CYAN}Installation Status:${NC}"
    echo "  Toolkit Root: $SCRIPT_DIR"
    echo "  Bin Directory: $BIN_DIR"
    echo "  Shell Config: $SHELL_CONFIG"
    echo ""

    ensure_shell_config_exists
    if grep -Fq "$PATH_BEGIN_MARKER" "$SHELL_CONFIG" && grep -Fq "$PATH_END_MARKER" "$SHELL_CONFIG"; then
        echo -e "  PATH block: ${GREEN}✓ Configured${NC}"
    elif grep -Fq "$BIN_DIR" "$SHELL_CONFIG"; then
        echo -e "  PATH block: ${YELLOW}○ Legacy entry detected${NC}"
    else
        echo -e "  PATH block: ${RED}✗ Not configured${NC}"
    fi

    if command -v wpcc >/dev/null 2>&1; then
        echo -e "  wpcc in PATH: ${GREEN}✓ Yes${NC} ($(command -v wpcc))"
    else
        echo -e "  wpcc in PATH: ${YELLOW}○ No${NC} (run 'source $SHELL_CONFIG')"
    fi

    local node_status
    node_status="$(node_version_status)"
    case "$node_status" in
        ok)
            echo -e "  Node.js floor: ${GREEN}✓ Meets >= v${NODE_MIN_MAJOR}${NC} ($(node -v))"
            ;;
        too_old)
            echo -e "  Node.js floor: ${RED}✗ Below >= v${NODE_MIN_MAJOR}${NC} ($(node -v))"
            ;;
        missing)
            echo -e "  Node.js floor: ${RED}✗ Missing${NC}"
            ;;
        *)
            echo -e "  Node.js floor: ${YELLOW}○ Unknown${NC}"
            ;;
    esac

    # Check WPCC
    if [ -d "$WPCC_DIR" ] && [ "$(ls -A "$WPCC_DIR" 2>/dev/null)" ]; then
        WPCC_COMMIT=$(git log -1 --format="%h %s" -- tools/wp-code-check 2>/dev/null || echo "unknown")
        echo -e "  WPCC: ${GREEN}✓ Installed${NC} ($WPCC_COMMIT)"
    else
        echo -e "  WPCC: ${YELLOW}✗ Not installed${NC} (run './install.sh setup-wpcc')"
    fi

    # Check MCP server
    local MCP_ENTRY="$TOOLS_DIR/mcp-server/dist/src/index.js"
    local MCP_STARTER="$TOOLS_DIR/mcp-server/start.sh"
    if [ -f "$MCP_ENTRY" ]; then
        echo -e "  MCP Server: ${GREEN}✓ Built${NC} ($TOOLS_DIR/mcp-server)"
    elif [ -x "$MCP_STARTER" ]; then
        echo -e "  MCP Server: ${GREEN}✓ Launcher ready${NC} ($MCP_STARTER auto-builds dist on first run)"
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

    check_node_requirement

    # Install dependencies
    cd "$MCP_DIR"
    run_npm_step "Installing dependencies" npm install --ignore-scripts

    # Build
    run_npm_step "Building MCP server" npm run build

    echo -e "${GREEN}✓ MCP server built successfully${NC}"
    echo ""

    # Show config snippets
    local MCP_ENTRY="$MCP_DIR/dist/src/index.js"
    local MCP_STARTER="$MCP_DIR/start.sh"

    echo -e "${CYAN}Client Configuration:${NC}"
    echo ""
    echo -e "${YELLOW}Claude Code (.mcp.json — already in repo root):${NC}"
    echo "  Auto-detected when you open the project."
    echo ""
    echo -e "${YELLOW}Claude Desktop (add to ~/Library/Application Support/Claude/claude_desktop_config.json):${NC}"
    echo "  \"ai-ddtk\": {"
    echo "    \"command\": \"bash\","
    echo "    \"args\": [\"$MCP_STARTER\"],"
    echo "    \"cwd\": \"$SCRIPT_DIR\""
    echo "  }"
    echo ""
    echo -e "${YELLOW}Cline (VS Code > Cline > MCP Servers > Edit Config):${NC}"
    echo "  \"ai-ddtk\": {"
    echo "    \"command\": \"bash\","
    echo "    \"args\": [\"$MCP_STARTER\"],"
    echo "    \"cwd\": \"$SCRIPT_DIR\""
    echo "  }"
    echo ""
    echo -e "${YELLOW}HTTP/SSE mode (for remote or multi-client use):${NC}"
    echo "  bash $MCP_STARTER --http"
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
        remove_path_block_and_legacy
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
        echo -e "${CYAN}Running full safe setup...${NC}"
        echo ""

        preflight_summary
        echo ""

        install_path
        setup_wpcc
        setup_mcp

        echo ""
        echo -e "${GREEN}Setup complete!${NC}"
        print_next_steps_block
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
