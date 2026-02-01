#!/usr/bin/env bash
#
# Neochrome WP Toolkit - Baseline Functionality Test
# Version: 1.0.0
#
# Tests baseline generation, suppression, new issue detection, and stale baseline detection
# Can be run against any WordPress plugin/theme to validate baseline features work correctly.
#
# Usage:
#   ./test-baseline-functionality.sh                           # Test with Save Cart Later (default)
#   ./test-baseline-functionality.sh --project shoptimizer     # Test with template
#   ./test-baseline-functionality.sh --paths /path/to/plugin   # Test with custom path
#

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(dirname "$SCRIPT_DIR")/bin"
CHECK_SCRIPT="$BIN_DIR/check-performance.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$BIN_DIR/lib"

# shellcheck source=dist/bin/lib/colors.sh
source "$LIB_DIR/colors.sh"

# Default test target (Save Cart Later has known issues)
DEFAULT_PROJECT="save-cart-later"
TEST_PROJECT=""
TEST_PATHS=""

# Test state
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================
# Helper Functions
# ============================================================

print_header() {
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  Neochrome WP Toolkit - Baseline Functionality Test${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

print_test_header() {
  local test_name="$1"
  echo -e "${BOLD}▸ Test: $test_name${NC}"
}

pass_test() {
  local message="$1"
  echo -e "  ${GREEN}✓ PASSED${NC}: $message"
  ((TESTS_PASSED++))
  ((TESTS_RUN++))
}

fail_test() {
  local message="$1"
  echo -e "  ${RED}✗ FAILED${NC}: $message"
  ((TESTS_FAILED++))
  ((TESTS_RUN++))
}

print_summary() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  Test Summary${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  Tests Run:    $TESTS_RUN"
  echo "  Passed:       ${GREEN}$TESTS_PASSED${NC}"
  echo "  Failed:       ${RED}$TESTS_FAILED${NC}"
  echo ""
  
  if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All baseline tests passed!${NC}"
    return 0
  else
    echo -e "${RED}✗ Some baseline tests failed${NC}"
    return 1
  fi
}

# ============================================================
# Parse Arguments
# ============================================================

while [[ $# -gt 0 ]]; do
  case $1 in
    --project)
      TEST_PROJECT="$2"
      shift 2
      ;;
    --paths)
      TEST_PATHS="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --project <name>    Test with template (e.g., save-cart-later)"
      echo "  --paths <path>      Test with custom path"
      echo "  --help              Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                           # Test with Save Cart Later (default)"
      echo "  $0 --project shoptimizer     # Test with Shoptimizer template"
      echo "  $0 --paths /path/to/plugin   # Test with custom path"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set default if no project/path specified
if [ -z "$TEST_PROJECT" ] && [ -z "$TEST_PATHS" ]; then
  TEST_PROJECT="$DEFAULT_PROJECT"
fi

# ============================================================
# Determine Test Target
# ============================================================

if [ -n "$TEST_PROJECT" ]; then
  # Using template
  TEMPLATE_FILE="$REPO_ROOT/TEMPLATES/${TEST_PROJECT}.txt"
  
  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}Error: Template '$TEST_PROJECT' not found at $TEMPLATE_FILE${NC}"
    exit 1
  fi
  
  # Source template to get PROJECT_PATH
  # shellcheck disable=SC1090
  source "$TEMPLATE_FILE"
  
  if [ -z "${PROJECT_PATH:-}" ]; then
    echo -e "${RED}Error: PROJECT_PATH not set in template${NC}"
    exit 1
  fi
  
  TEST_PATHS="$PROJECT_PATH"
  TEST_NAME="${NAME:-$TEST_PROJECT}"
fi

# Validate test path exists
if [ ! -d "$TEST_PATHS" ]; then
  echo -e "${RED}Error: Test path does not exist: $TEST_PATHS${NC}"
  exit 1
fi

# ============================================================
# Main Test Execution
# ============================================================

print_header

echo -e "${BOLD}Test Target:${NC} $TEST_PATHS"
if [ -n "$TEST_NAME" ]; then
  echo -e "${BOLD}Project:${NC} $TEST_NAME"
fi
echo ""

# Change to test directory for baseline file operations
cd "$TEST_PATHS"

# Backup existing baseline if present
BASELINE_BACKUP=""
if [ -f ".hcc-baseline" ]; then
  BASELINE_BACKUP=".hcc-baseline.backup.$$"
  cp ".hcc-baseline" "$BASELINE_BACKUP"
  echo -e "${YELLOW}→ Backed up existing baseline to $BASELINE_BACKUP${NC}"
  echo ""
fi

# ============================================================================
# Test 1: Generate Baseline
# ============================================================================

print_test_header "Baseline Generation"

# Remove any existing baseline
rm -f ".hcc-baseline"

# Generate baseline
# Disable set -e temporarily to capture exit code without terminating
set +e
OUTPUT=$("$CHECK_SCRIPT" --paths "$TEST_PATHS" --generate-baseline --no-log 2>&1)
EXIT_CODE=$?
set -e

# Check if baseline file was created
if [ -f ".hcc-baseline" ]; then
  BASELINE_COUNT=$(grep -v "^#" ".hcc-baseline" | grep -v "^$" | wc -l | tr -d '[:space:]')
  pass_test "Baseline file created with $BASELINE_COUNT entries"
else
  fail_test "Baseline file was not created"
fi

echo ""

# ============================================================================
# Test 2: Baseline Suppression
# ============================================================================

print_test_header "Baseline Suppression"

# Run check with baseline (should suppress all issues)
# Disable set -e temporarily to capture exit code without terminating
set +e
OUTPUT=$("$CHECK_SCRIPT" --paths "$TEST_PATHS" --format json --no-log 2>&1)
EXIT_CODE=$?
set -e

# Parse JSON output
TOTAL_ERRORS=$(echo "$OUTPUT" | grep -o '"total_errors": [0-9]*' | head -1 | cut -d':' -f2 | tr -d '[:space:]')
TOTAL_WARNINGS=$(echo "$OUTPUT" | grep -o '"total_warnings": [0-9]*' | head -1 | cut -d':' -f2 | tr -d '[:space:]')
BASELINED=$(echo "$OUTPUT" | grep -o '"baselined": [0-9]*' | head -1 | cut -d':' -f2 | tr -d '[:space:]')

# Validate suppression
if [ "$BASELINED" -gt 0 ]; then
  pass_test "Baseline suppressed $BASELINED findings"
else
  fail_test "Baseline did not suppress any findings (expected > 0)"
fi

# Check if new errors/warnings are 0 (all suppressed)
if [ "$TOTAL_ERRORS" -eq 0 ] && [ "$TOTAL_WARNINGS" -eq 0 ]; then
  pass_test "All issues successfully suppressed (0 errors, 0 warnings)"
else
  fail_test "Found unsuppressed issues: $TOTAL_ERRORS errors, $TOTAL_WARNINGS warnings"
fi

# Check exit code (should be 0 when all issues are baselined)
if [ "$EXIT_CODE" -eq 0 ]; then
  pass_test "Exit code is 0 (success) when all issues are baselined"
else
  fail_test "Exit code is $EXIT_CODE (expected 0)"
fi

echo ""

# ============================================================================
# Test 3: New Issue Detection
# ============================================================================

print_test_header "New Issue Detection"

# Create a temporary PHP file with a known issue
TEST_FILE="$TEST_PATHS/hcc-baseline-test-temp.php"
cat > "$TEST_FILE" << 'EOF'
<?php
// Temporary test file for baseline testing
// This file intentionally contains a performance issue

function test_unbounded_query() {
    $posts = get_posts(array(
        'posts_per_page' => -1  // Intentional unbounded query
    ));
    return $posts;
}
EOF

# Run check again (should detect new issue)
# Disable set -e temporarily to capture exit code without terminating
set +e
OUTPUT=$("$CHECK_SCRIPT" --paths "$TEST_PATHS" --format json --no-log 2>&1)
EXIT_CODE=$?
set -e

# Parse JSON output
TOTAL_ERRORS=$(echo "$OUTPUT" | grep -o '"total_errors": [0-9]*' | head -1 | cut -d':' -f2 | tr -d '[:space:]')
BASELINED=$(echo "$OUTPUT" | grep -o '"baselined": [0-9]*' | head -1 | cut -d':' -f2 | tr -d '[:space:]')

# Validate new issue detection
if [ "$TOTAL_ERRORS" -gt 0 ]; then
  pass_test "Detected new issue above baseline ($TOTAL_ERRORS new errors)"
else
  fail_test "Did not detect new issue (expected > 0 errors)"
fi

# Baseline should still suppress original issues
if [ "$BASELINED" -gt 0 ]; then
  pass_test "Baseline still suppressing original issues ($BASELINED suppressed)"
else
  fail_test "Baseline not suppressing original issues"
fi

# Exit code should be 1 (failure due to new issue)
if [ "$EXIT_CODE" -ne 0 ]; then
  pass_test "Exit code is non-zero ($EXIT_CODE) for new issues"
else
  fail_test "Exit code is 0 (expected non-zero for new issues)"
fi

# Clean up test file
rm -f "$TEST_FILE"

echo ""

# ============================================================================
# Test 4: Stale Baseline Detection
# ============================================================================

print_test_header "Stale Baseline Detection"

# Modify baseline to have higher counts than actual findings
# This simulates fixing issues after baseline was generated
if [ -f ".hcc-baseline" ]; then
  # Add a fake entry with high count
  echo "unbounded-posts-per-page|fake-file.php|0|999|*" >> ".hcc-baseline"
  
  # Run check (should detect stale entry)
  OUTPUT=$("$CHECK_SCRIPT" --paths "$TEST_PATHS" --format json --no-log 2>&1)
  
  # Parse stale baseline count
  STALE_BASELINE=$(echo "$OUTPUT" | grep -o '"stale_baseline": [0-9]*' | head -1 | cut -d':' -f2 | tr -d '[:space:]')
  
  if [ "$STALE_BASELINE" -gt 0 ]; then
    pass_test "Detected stale baseline entries ($STALE_BASELINE stale)"
  else
    fail_test "Did not detect stale baseline entries (expected > 0)"
  fi
else
  fail_test "Baseline file missing for stale detection test"
fi

echo ""

# ============================================================================
# Test 5: Baseline Ignore Flag
# ============================================================================

print_test_header "Baseline Ignore Flag"

# Run with --ignore-baseline (should show all issues)
# Disable set -e temporarily to capture exit code without terminating
set +e
OUTPUT=$("$CHECK_SCRIPT" --paths "$TEST_PATHS" --ignore-baseline --format json --no-log 2>&1)
EXIT_CODE=$?
set -e

# Parse JSON output
TOTAL_ERRORS=$(echo "$OUTPUT" | grep -o '"total_errors": [0-9]*' | head -1 | cut -d':' -f2 | tr -d '[:space:]')
BASELINED=$(echo "$OUTPUT" | grep -o '"baselined": [0-9]*' | head -1 | cut -d':' -f2 | tr -d '[:space:]')

# Validate baseline was ignored
if [ "$BASELINED" -eq 0 ]; then
  pass_test "Baseline correctly ignored (0 suppressed)"
else
  fail_test "Baseline was not ignored ($BASELINED suppressed)"
fi

# Should find original issues
if [ "$TOTAL_ERRORS" -gt 0 ]; then
  pass_test "Found original issues when baseline ignored ($TOTAL_ERRORS errors)"
else
  fail_test "Did not find original issues (expected > 0 errors)"
fi

echo ""

# ============================================================================
# Cleanup
# ============================================================================

echo -e "${BOLD}Cleanup${NC}"

# Remove test baseline
if [ -f ".hcc-baseline" ]; then
  rm -f ".hcc-baseline"
  echo -e "  ${GREEN}✓${NC} Removed test baseline"
fi

# Restore original baseline if it existed
if [ -n "$BASELINE_BACKUP" ] && [ -f "$BASELINE_BACKUP" ]; then
  mv "$BASELINE_BACKUP" ".hcc-baseline"
  echo -e "  ${GREEN}✓${NC} Restored original baseline"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

if print_summary; then
  exit 0
else
  exit 1
fi
