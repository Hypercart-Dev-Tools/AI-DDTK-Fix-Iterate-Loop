#!/usr/bin/env bash
#
# Superglobal Manipulation Validator
# Version: 1.0.0
#
# Validates findings from spo-002-superglobal-manipulation pattern
# Filters false positives and adjusts severity based on security guards
#
# Usage: superglobal-manipulation-validator.sh <file> <line_number> <code> <severity>
# Returns: JSON object with validation result

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Source required libraries
# shellcheck source=dist/bin/lib/false-positive-filters.sh
source "$LIB_DIR/false-positive-filters.sh"

# Input parameters
FILE="$1"
LINE_NUMBER="$2"
CODE="$3"
SEVERITY="$4"

# Validation result (default: valid finding)
VALID=true
ADJUSTED_SEVERITY="$SEVERITY"
GUARDS=""
REASON=""

# Check if line is in comment/docblock
if is_line_in_comment "$FILE" "$LINE_NUMBER"; then
  VALID=false
  REASON="Line is inside a comment or docblock"
fi

# Check if it's HTML form or REST config (false positive)
if [ "$VALID" = true ] && is_html_or_rest_config "$CODE"; then
  VALID=false
  REASON="HTML form or REST route configuration (not executable code)"
fi

# Detect security guards (nonce, capability checks)
if [ "$VALID" = true ]; then
  GUARDS=$(detect_guards "$FILE" "$LINE_NUMBER" 20)
  
  # If guards are present, downgrade severity
  if [ -n "$GUARDS" ]; then
    case "$SEVERITY" in
      CRITICAL) ADJUSTED_SEVERITY="HIGH" ;;
      HIGH)     ADJUSTED_SEVERITY="MEDIUM" ;;
      MEDIUM)   ADJUSTED_SEVERITY="LOW" ;;
    esac
    REASON="Security guards detected: $GUARDS"
  fi
fi

# Output JSON result
cat <<EOF
{
  "valid": $VALID,
  "severity": "$ADJUSTED_SEVERITY",
  "guards": "$GUARDS",
  "reason": "$REASON"
}
EOF

