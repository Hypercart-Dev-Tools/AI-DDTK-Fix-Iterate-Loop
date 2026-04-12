#!/usr/bin/env bash
# ============================================================
# AI-DDTK wire-project Regression Tests
# ============================================================

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASSED=0
FAILED=0

run_test() {
    local test_name="$1"
    local test_func="$2"
    local log_file=""

    echo -e "${BLUE}Testing:${NC} $test_name"

    log_file="$(mktemp "${TMPDIR:-/tmp}/aiddtk-wire-project-log-XXXXXX")" || return 1

    if "$test_func" >"$log_file" 2>&1; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        if [ -s "$log_file" ]; then
            cat "$log_file"
        fi
        FAILED=$((FAILED + 1))
    fi

    rm -f "$log_file"
}

make_temp_dir() {
    local temp_root="/tmp"

    if [ ! -d "$temp_root" ] || [ ! -w "$temp_root" ]; then
        temp_root="${TMPDIR:-/tmp}"
    fi

    mktemp -d "$temp_root/aiddtk-wire-project-test-XXXXXX"
}

cleanup_test_root() {
    local test_root="$1"
    rm -rf "$test_root"
}

test_gitignore_append_without_trailing_newline() {
    local test_root=""
    local test_home=""
    local project_dir=""
    local ref_line="AI-DDTK is installed at ~/bin/ai-ddtk — see ~/bin/ai-ddtk/AGENTS.md for available tools and workflows."
    local first_run_status=0
    local second_run_status=0
    local mcp_line_count=0
    local ref_count=0

    test_root="$(make_temp_dir)" || return 1
    test_home="$test_root/home"
    project_dir="$test_root/project"

    mkdir -p "$test_home/bin" "$project_dir"
    ln -s "$TOOLKIT_DIR" "$test_home/bin/ai-ddtk"

    printf 'existing-entry' > "$project_dir/.gitignore"

    HOME="$test_home" "$TOOLKIT_DIR/bin/wire-project" --client=claude-code "$project_dir" >/dev/null 2>&1
    first_run_status=$?

    HOME="$test_home" "$TOOLKIT_DIR/bin/wire-project" --client=claude-code "$project_dir" >/dev/null 2>&1
    second_run_status=$?

    if [ "$first_run_status" -ne 0 ] || [ "$second_run_status" -ne 0 ]; then
        cleanup_test_root "$test_root"
        return 1
    fi

    if grep -q 'existing-entry.mcp.local.json' "$project_dir/.gitignore"; then
        cleanup_test_root "$test_root"
        return 1
    fi

    if ! grep -Fxq 'existing-entry' "$project_dir/.gitignore"; then
        cleanup_test_root "$test_root"
        return 1
    fi

    mcp_line_count=$(grep -Fxc '.mcp.local.json' "$project_dir/.gitignore")
    if [ "$mcp_line_count" -ne 1 ]; then
        cleanup_test_root "$test_root"
        return 1
    fi

    if [ ! -f "$project_dir/.mcp.local.json" ] || [ ! -f "$project_dir/CLAUDE.md" ] || [ ! -f "$project_dir/AGENTS.md" ]; then
        cleanup_test_root "$test_root"
        return 1
    fi

    ref_count=$(grep -Fxc "$ref_line" "$project_dir/AGENTS.md")
    if [ "$ref_count" -ne 1 ]; then
        cleanup_test_root "$test_root"
        return 1
    fi

    if ! grep -Fq '"ai-ddtk"' "$project_dir/.mcp.local.json"; then
        cleanup_test_root "$test_root"
        return 1
    fi

    cleanup_test_root "$test_root"
    return 0
}

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      AI-DDTK wire-project Regression Tests           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

run_test "wire-project handles newline-less gitignore idempotently" test_gitignore_append_without_trailing_newline

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