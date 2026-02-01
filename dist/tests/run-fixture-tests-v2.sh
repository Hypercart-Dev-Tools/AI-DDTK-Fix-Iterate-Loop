#!/usr/bin/env bash
#
# WP Code Check - Fixture Validation Tests v2.0
# Version: 2.0.0
#
# Cross-platform test runner for macOS and GitHub Actions Ubuntu.
# Designed for observability, explicit contracts, and zero silent failures.
#
# Usage:
#   ./tests/run-fixture-tests-v2.sh [OPTIONS]
#
# Options:
#   --ci          Force CI mode (no colors, structured logging)
#   --verbose     Show DEBUG level logs
#   --trace       Show TRACE level logs (very verbose)
#   --json        Output results as JSON
#   --help        Show this help
#
# Environment Variables:
#   CI=true           Auto-detected in GitHub Actions
#   LOG_LEVEL=DEBUG   Set logging verbosity
#   NO_COLOR=1        Disable colored output
#

set -o pipefail

# ============================================================
# Script Setup
# ============================================================

# Script directory resolution (works with symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$(dirname "$SCRIPT_DIR")"

# Source libraries
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/precheck.sh"
source "$SCRIPT_DIR/lib/runner.sh"
source "$SCRIPT_DIR/lib/reporter.sh"

# Configuration
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
EXPECTATIONS_FILE="$SCRIPT_DIR/expected/fixture-expectations.json"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-human}"

# ============================================================
# Argument Parsing
# ============================================================

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --ci)
        export CI=true
        export NO_COLOR=1
        export LOG_FORMAT=json
        ;;
      --verbose)
        export LOG_LEVEL=DEBUG
        ;;
      --trace)
        export LOG_LEVEL=TRACE
        ;;
      --json)
        export OUTPUT_FORMAT=json
        ;;
      --help)
        print_help "$(basename "$0")"
        exit 0
        ;;
      *)
        log WARN "Unknown argument: $1"
        ;;
    esac
    shift
  done
}

# ============================================================
# Main Entry Point
# ============================================================

main() {
  parse_args "$@"

  # Print header
  print_header "WP Code Check - Fixture Validation Tests v2.0.0"
  echo "Testing detection patterns against known fixtures..."
  echo ""

  # Change to dist directory
  cd "$DIST_DIR" || {
    log ERROR "Failed to change to dist directory: $DIST_DIR"
    exit 1
  }
  log DEBUG "Working directory: $(pwd)"

  # Print environment snapshot (unless in JSON mode)
  if [ "$OUTPUT_FORMAT" != "json" ]; then
    print_environment
  fi

  # Pre-flight checks
  log INFO "Running pre-flight checks..."

  if ! precheck_dependencies; then
    log ERROR "Dependency check failed"
    exit 1
  fi

  if ! precheck_environment; then
    log ERROR "Environment check failed"
    exit 1
  fi

  if ! precheck_working_directory; then
    log ERROR "Working directory check failed"
    exit 1
  fi

  if ! precheck_fixtures "$FIXTURES_DIR" "$EXPECTATIONS_FILE"; then
    log ERROR "Fixture check failed"
    exit 1
  fi

  log INFO "✓ Pre-flight checks passed"
  log INFO ""

  # Run tests
  log INFO "Running fixture tests..."
  log INFO ""
  
  local results
  results=$(run_all_tests "$FIXTURES_DIR" "$EXPECTATIONS_FILE")
  local test_exit=$?

  # Parse results
  local total passed failed
  total=$(echo "$results" | jq -r '.total')
  passed=$(echo "$results" | jq -r '.passed')
  failed=$(echo "$results" | jq -r '.failed')

  # Output summary
  if [ "$OUTPUT_FORMAT" = "json" ]; then
    print_json_summary "$total" "$passed" "$failed"
  else
    print_summary "$total" "$passed" "$failed"
  fi

  # Exit with appropriate code
  if [ "$test_exit" -eq 0 ]; then
    exit 0
  else
    log ERROR "If you intentionally added/removed patterns, update:"
    log ERROR "  $EXPECTATIONS_FILE"
    exit 1
  fi
}

main "$@"

