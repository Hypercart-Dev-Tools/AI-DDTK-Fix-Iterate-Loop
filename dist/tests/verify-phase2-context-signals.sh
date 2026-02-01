#!/usr/bin/env bash
#
# Phase 2 Verification Script: Context Signals (Guards + Sanitizers)
# 
# This script verifies that Phase 2 enhancements are working correctly:
# 1. Guard detection (nonce checks, capability checks)
# 2. Sanitizer detection (sanitize_*, esc_*, absint, etc.)
# 3. SQL safety detection (literal vs concatenated)
# 4. Severity downgrading based on context
# 5. JSON output includes guards and sanitizers arrays
#
# Usage: ./dist/tests/verify-phase2-context-signals.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCANNER="$REPO_ROOT/dist/bin/check-performance.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "=========================================="
echo "Phase 2 Verification: Context Signals"
echo "=========================================="
echo ""

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local fixture="$2"
    local expected_pattern="$3"
    local description="$4"
    
    ((TESTS_RUN++))
    
    echo -e "${BLUE}Test $TESTS_RUN: $test_name${NC}"
    echo "  Description: $description"
    
    # Run scanner on fixture
    local output
    output=$("$SCANNER" --paths "$fixture" --format json 2>/dev/null || true)
    
    # Check if expected pattern is found
    if echo "$output" | grep -q "$expected_pattern"; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        echo "  Expected pattern: $expected_pattern"
        echo "  Output snippet:"
        echo "$output" | head -20 | sed 's/^/    /'
        ((TESTS_FAILED++))
    fi
    echo ""
}

# ============================================================
# Test 1: Guard Detection
# ============================================================

echo -e "${YELLOW}=== Guard Detection Tests ===${NC}"
echo ""

run_test \
    "Guards array in JSON output" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-guards-detection.php" \
    '"guards":\[' \
    "JSON output should include guards array"

run_test \
    "wp_verify_nonce detection" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-guards-detection.php" \
    '"wp_verify_nonce"' \
    "Should detect wp_verify_nonce in guards array"

run_test \
    "check_ajax_referer detection" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-guards-detection.php" \
    '"check_ajax_referer"' \
    "Should detect check_ajax_referer in guards array"

run_test \
    "current_user_can detection" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-guards-detection.php" \
    '"current_user_can"' \
    "Should detect current_user_can in guards array"

# ============================================================
# Test 2: Sanitizer Detection
# ============================================================

echo -e "${YELLOW}=== Sanitizer Detection Tests ===${NC}"
echo ""

run_test \
    "Sanitizers array in JSON output" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-sanitizers-detection.php" \
    '"sanitizers":\[' \
    "JSON output should include sanitizers array"

run_test \
    "sanitize_text_field detection" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-sanitizers-detection.php" \
    '"sanitize_text_field"' \
    "Should detect sanitize_text_field in sanitizers array"

run_test \
    "sanitize_email detection" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-sanitizers-detection.php" \
    '"sanitize_email"' \
    "Should detect sanitize_email in sanitizers array"

run_test \
    "absint detection" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-sanitizers-detection.php" \
    '"absint"' \
    "Should detect absint in sanitizers array"

run_test \
    "esc_url_raw detection" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-sanitizers-detection.php" \
    '"esc_url_raw"' \
    "Should detect esc_url_raw in sanitizers array"

# ============================================================
# Test 3: SQL Safety Detection
# ============================================================

echo -e "${YELLOW}=== SQL Safety Detection Tests ===${NC}"
echo ""

run_test \
    "Safe literal SQL detected" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-wpdb-safety.php" \
    'literal SQL - best practice' \
    "Safe literal SQL should be marked as best-practice"

run_test \
    "Unsafe concatenated SQL detected" \
    "$REPO_ROOT/dist/tests/fixtures/phase2-wpdb-safety.php" \
    'wpdb-query-no-prepare' \
    "Unsafe SQL should still be flagged"

# ============================================================
# Summary
# ============================================================

echo ""
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo -e "Tests run:    ${BLUE}$TESTS_RUN${NC}"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All Phase 2 tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some Phase 2 tests failed${NC}"
    exit 1
fi

