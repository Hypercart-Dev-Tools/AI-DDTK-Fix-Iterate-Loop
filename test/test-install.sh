#!/usr/bin/env bash
# ============================================================
# AI-DDTK Installation Test Suite
# ============================================================
#
# PURPOSE:
#   Validates the install.sh script works correctly.
#   Run inside Docker container for clean environment testing.
#
# FOR LLM AGENTS:
#   - Each test function returns 0 (pass) or 1 (fail)
#   - Add new tests by creating test_* functions
#   - Tests run in order defined
#   - Script exits with count of failed tests
#
# ============================================================

# Note: Do NOT use set -e as it breaks ((PASSED++)) when PASSED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOOLKIT_DIR="$HOME/bin/ai-ddtk"
PASSED=0
FAILED=0

# ============================================================
# TEST HELPERS
# ============================================================

run_test() {
    local test_name="$1"
    local test_func="$2"

    echo -e "${BLUE}Testing:${NC} $test_name"

    if $test_func; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        FAILED=$((FAILED + 1))
    fi
}

# ============================================================
# TESTS
# ============================================================

test_files_exist() {
    [ -f "$TOOLKIT_DIR/install.sh" ] && \
    [ -f "$TOOLKIT_DIR/bin/wpcc" ] && \
    [ -d "$TOOLKIT_DIR/tools" ] && \
    [ -f "$TOOLKIT_DIR/README.md" ]
}

test_scripts_executable() {
    [ -x "$TOOLKIT_DIR/install.sh" ] && \
    [ -x "$TOOLKIT_DIR/bin/wpcc" ]
}

test_status_command() {
    cd "$TOOLKIT_DIR"
    ./install.sh status 2>&1 | grep -q "Installation Status"
}

test_help_command() {
    cd "$TOOLKIT_DIR"
    ./install.sh --help 2>&1 | grep -q "Usage:"
}

test_install_adds_path() {
    cd "$TOOLKIT_DIR"
    ./install.sh
    
    # Check if PATH entry was added to shell config
    grep -q "ai-ddtk/bin" "$HOME/.bashrc" || grep -q "ai-ddtk/bin" "$HOME/.zshrc"
}

test_install_idempotent() {
    cd "$TOOLKIT_DIR"

    # Run install twice
    ./install.sh
    ./install.sh

    # Should only have one PATH entry (check both bashrc and zshrc)
    local count_bash
    local count_zsh
    count_bash=$(grep -c "ai-ddtk/bin" "$HOME/.bashrc" 2>/dev/null) || count_bash=0
    count_zsh=$(grep -c "ai-ddtk/bin" "$HOME/.zshrc" 2>/dev/null) || count_zsh=0

    # Each file should have at most 1 entry
    [ "$count_bash" -le 1 ] && [ "$count_zsh" -le 1 ]
}

test_wpcc_wrapper_error() {
    cd "$TOOLKIT_DIR"
    
    # Should fail gracefully when WPCC not installed
    if ./bin/wpcc 2>&1 | grep -q "WP Code Check not found"; then
        return 0
    fi
    return 1
}

test_uninstall() {
    cd "$TOOLKIT_DIR"
    
    # First install
    ./install.sh
    
    # Then uninstall
    ./install.sh uninstall
    
    # PATH entry should be removed
    ! grep -q "ai-ddtk/bin" "$HOME/.bashrc" 2>/dev/null
}

# ============================================================
# MAIN
# ============================================================

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     AI-DDTK Installation Test Suite                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

run_test "Required files exist" test_files_exist
run_test "Scripts are executable" test_scripts_executable
run_test "Status command works" test_status_command
run_test "Help command works" test_help_command
run_test "Install adds PATH entry" test_install_adds_path
run_test "Install is idempotent" test_install_idempotent
run_test "WPCC wrapper shows helpful error" test_wpcc_wrapper_error
run_test "Uninstall removes PATH entry" test_uninstall

echo ""
echo "============================================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "============================================================"

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi

