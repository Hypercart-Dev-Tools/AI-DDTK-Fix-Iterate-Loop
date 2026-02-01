#!/usr/bin/env bash
#
# WP Code Check - Test Reporter Library
# Version: 2.0.0
#
# Formats test results for human and machine consumption.
# Designed for cross-platform compatibility (macOS, Ubuntu).
#

# ============================================================
# Output Formatting
# ============================================================

# Print a header banner
# Usage: print_header "Title"
print_header() {
  local title="$1"
  local line="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  echo ""
  echo "$line"
  echo "  $title"
  echo "$line"
}

# Print environment snapshot
# Usage: print_environment
print_environment() {
  print_header "Environment Snapshot"
  
  echo "  OS:         $(uname -s) $(uname -r)"
  echo "  Shell:      $SHELL (Bash $BASH_VERSION)"
  echo "  jq:         $(jq --version 2>&1)"
  echo "  perl:       $(perl -v 2>&1 | grep 'This is perl' | head -1 | sed 's/^[[:space:]]*//')"
  echo "  grep:       $(grep --version 2>&1 | head -1)"
  echo "  CI:         ${CI:-false}"
  echo "  Log Level:  $LOG_LEVEL"
  echo ""
}

# Print test summary
# Usage: print_summary "total" "passed" "failed"
print_summary() {
  local total="$1"
  local passed="$2"
  local failed="$3"
  
  print_header "Test Summary"
  
  echo ""
  echo "  Tests Run:    $total"
  echo "  Passed:       $passed"
  echo "  Failed:       $failed"
  echo ""
  
  if [ "$failed" -eq 0 ]; then
    log INFO "✓ All fixture tests passed!"
  else
    log ERROR "✗ $failed test(s) failed"
  fi
  
  echo ""
}

# Print JSON summary (for CI integration)
# Usage: print_json_summary "total" "passed" "failed"
print_json_summary() {
  local total="$1"
  local passed="$2"
  local failed="$3"
  
  cat <<EOF
{
  "test_run": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "total": $total,
    "passed": $passed,
    "failed": $failed,
    "success": $([ "$failed" -eq 0 ] && echo "true" || echo "false")
  }
}
EOF
}

# Print usage help
# Usage: print_help "script_name"
print_help() {
  local script_name="$1"
  
  cat <<EOF
WP Code Check - Fixture Validation Tests v2.0.0

Cross-platform test runner for macOS and GitHub Actions Ubuntu.
Designed for observability, explicit contracts, and zero silent failures.

Usage:
  $script_name [OPTIONS]

Options:
  --ci          Force CI mode (no colors, structured logging)
  --verbose     Show DEBUG level logs
  --trace       Show TRACE level logs (very verbose)
  --json        Output results as JSON
  --help        Show this help

Environment Variables:
  CI=true           Auto-detected in GitHub Actions
  LOG_LEVEL=DEBUG   Set logging verbosity (ERROR|WARN|INFO|DEBUG|TRACE)
  NO_COLOR=1        Disable colored output

Examples:
  # Standard local test
  $script_name

  # CI emulation mode
  $script_name --ci --verbose

  # Verbose debugging
  $script_name --trace

  # JSON output for parsing
  $script_name --json

Exit Codes:
  0 = All tests passed
  1 = One or more tests failed

EOF
}

