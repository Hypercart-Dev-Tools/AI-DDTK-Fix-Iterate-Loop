#!/usr/bin/env bash
#
# Loop Context Validator
#
# Checks if a matched line is inside a loop context by looking for
# loop keywords (foreach, for, while) within a specified number of lines before.
#
# Exit codes:
#   0 - Loop keyword found (confirmed issue - inside loop)
#   1 - No loop keyword found (false positive - not in loop)
#

set -euo pipefail

# ============================================================================
# Input Validation
# ============================================================================

if [ $# -lt 3 ]; then
  echo "ERROR: Missing required arguments" >&2
  echo "Usage: $0 <file> <line_number> <matched_code> [context_lines]" >&2
  exit 1
fi

FILE="$1"
LINE_NUMBER="$2"
MATCHED_CODE="$3"
CONTEXT_LINES="${4:-15}"  # Default to 15 lines of context

# Validate file exists and is readable
if [ ! -f "$FILE" ]; then
  echo "ERROR: File not found: $FILE" >&2
  exit 1
fi

if [ ! -r "$FILE" ]; then
  echo "ERROR: File not readable: $FILE" >&2
  exit 1
fi

# Validate line number is numeric
if ! [[ "$LINE_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Invalid line number: $LINE_NUMBER" >&2
  exit 1
fi

# ============================================================================
# Validation Logic
# ============================================================================

# Calculate context range (look back N lines, plus 2 lines forward)
start_line=$((LINE_NUMBER - CONTEXT_LINES))
[ "$start_line" -lt 1 ] && start_line=1
end_line=$((LINE_NUMBER + 2))

# Read the context
context=$(sed -n "${start_line},${end_line}p" "$FILE" 2>/dev/null || true)

# Debug output
if [ "${NEOCHROME_DEBUG:-}" = "1" ]; then
  echo "[DEBUG] loop-context-check: Checking $FILE:$LINE_NUMBER" >&2
  echo "[DEBUG] Context range: lines $start_line-$end_line" >&2
  echo "[DEBUG] Context:" >&2
  echo "$context" | sed 's/^/[DEBUG]   /' >&2
fi

# Check for loop keywords (foreach, for, while)
if echo "$context" | grep -q -E "\b(foreach|for|while)\b"; then
  # Found loop keyword - this is inside a loop (confirmed issue)
  [ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] Found loop keyword - confirmed issue" >&2
  exit 0
fi

# No loop keyword found - not in a loop (false positive)
[ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] No loop keyword found - false positive" >&2
exit 1

