#!/usr/bin/env bash
#
# Golden Rules Analyzer - Integration Tests
#
# Tests the Golden Rules Analyzer functionality to ensure it correctly
# detects architectural antipatterns.
#
# © Copyright 2025 Hypercart (a DBA of Neochrome, Inc.)
# License: Apache-2.0

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYZER="${SCRIPT_DIR}/../bin/experimental/golden-rules-analyzer.php"
TEMP_DIR="${SCRIPT_DIR}/temp-golden-rules-test"

# Check if PHP is available
if ! command -v php &> /dev/null; then
    echo -e "${RED}Error: PHP is required to run Golden Rules Analyzer tests${NC}"
    exit 1
fi

# Check if analyzer exists
if [[ ! -f "$ANALYZER" ]]; then
    echo -e "${RED}Error: Golden Rules Analyzer not found at: $ANALYZER${NC}"
    exit 1
fi

# Setup
setup() {
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
}

# Teardown
teardown() {
    rm -rf "$TEMP_DIR"
}

# Test helper
run_test() {
    local test_name="$1"
    local expected_result="$2"  # "pass" or "fail"
    local test_file="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -e "${CYAN}▸ Test: ${test_name}${NC}"
    
    # Run analyzer
    if php "$ANALYZER" "$test_file" --format=json > /dev/null 2>&1; then
        actual_result="pass"
    else
        actual_result="fail"
    fi
    
    if [[ "$actual_result" == "$expected_result" ]]; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAILED${NC} (expected: $expected_result, got: $actual_result)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test helper with violation count
run_test_with_count() {
    local test_name="$1"
    local expected_violations="$2"
    local test_file="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -e "${CYAN}▸ Test: ${test_name}${NC}"
    
    # Run analyzer and count violations
    local output
    output=$(php "$ANALYZER" "$test_file" --format=json 2>/dev/null || true)
    local actual_violations
    actual_violations=$(echo "$output" | grep -o '"severity"' | wc -l | tr -d ' ')
    
    if [[ "$actual_violations" -ge "$expected_violations" ]]; then
        echo -e "  ${GREEN}✓ PASSED${NC} (found $actual_violations violations, expected >= $expected_violations)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAILED${NC} (found $actual_violations violations, expected >= $expected_violations)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Print header
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Golden Rules Analyzer - Integration Tests${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

setup

# Test 1: Unbounded WP_Query
cat > "$TEMP_DIR/test-unbounded-query.php" << 'EOF'
<?php
$query = new WP_Query( array(
    'post_type' => 'post',
    // Missing posts_per_page - should trigger error
) );
EOF

run_test_with_count "Unbounded WP_Query detection" 1 "$TEMP_DIR/test-unbounded-query.php"

# Test 2: Direct state mutation
cat > "$TEMP_DIR/test-state-mutation.php" << 'EOF'
<?php
class MyClass {
    private $state;
    
    public function bad_method() {
        $this->state = 'new_value'; // Direct mutation - should trigger error
    }
}
EOF

run_test_with_count "Direct state mutation detection" 1 "$TEMP_DIR/test-state-mutation.php"

# Test 3: Debug code
cat > "$TEMP_DIR/test-debug-code.php" << 'EOF'
<?php
function my_function() {
    var_dump( $data ); // Debug code - should trigger error
    print_r( $array ); // Debug code - should trigger error
}
EOF

run_test_with_count "Debug code detection" 2 "$TEMP_DIR/test-debug-code.php"

# Test 4: Missing error handling
cat > "$TEMP_DIR/test-error-handling.php" << 'EOF'
<?php
$response = wp_remote_get( 'https://api.example.com/data' );
// Missing is_wp_error check - should trigger warning
$data = wp_remote_retrieve_body( $response );
EOF

run_test_with_count "Missing error handling detection" 1 "$TEMP_DIR/test-error-handling.php"

# Test 5: Clean code (should pass)
cat > "$TEMP_DIR/test-clean-code.php" << 'EOF'
<?php
function get_posts_safely() {
    $query = new WP_Query( array(
        'post_type' => 'post',
        'posts_per_page' => 10, // Bounded query
    ) );
    return $query->posts;
}
EOF

run_test_with_count "Clean code (no violations)" 0 "$TEMP_DIR/test-clean-code.php"

teardown

# Print summary
echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Test Summary${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Tests Run:    ${TESTS_RUN}"
echo -e "  Passed:       ${GREEN}${TESTS_PASSED}${NC}"
echo -e "  Failed:       ${RED}${TESTS_FAILED}${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi

