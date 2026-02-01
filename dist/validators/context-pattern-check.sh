#!/usr/bin/env bash
#
# Context Pattern Checker Validator
# Version: 1.0.0
#
# Validates that a pattern appears within N lines after a match
# Used for detecting code patterns within specific contexts (e.g., DB queries in constructors)
#
# Usage: context-pattern-check.sh <file> <line_number> <pattern> <context_lines> <direction>
#   pattern: Extended regex pattern to search for
#   context_lines: Number of lines to check (default: 50)
#   direction: "after" (default) or "before" or "both"
#
# Exit codes:
#   0 = Pattern found in context (confirmed issue)
#   1 = Pattern NOT found in context (false positive)
#   2 = Needs manual review

set -euo pipefail

# Input parameters
FILE="$1"
LINE_NUMBER="$2"
PATTERN="${3:-}"
CONTEXT_LINES="${4:-50}"
DIRECTION="${5:-after}"

# Validation
if [ -z "$PATTERN" ]; then
  echo "ERROR: Pattern parameter required" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "ERROR: File not found: $FILE" >&2
  exit 1
fi

# Get total lines in file
TOTAL_LINES=$(wc -l < "$FILE" | tr -d ' ')

# Calculate line range based on direction
case "$DIRECTION" in
  after)
    START_LINE=$LINE_NUMBER
    END_LINE=$((LINE_NUMBER + CONTEXT_LINES))
    ;;
  before)
    START_LINE=$((LINE_NUMBER - CONTEXT_LINES))
    END_LINE=$LINE_NUMBER
    ;;
  both)
    START_LINE=$((LINE_NUMBER - CONTEXT_LINES))
    END_LINE=$((LINE_NUMBER + CONTEXT_LINES))
    ;;
  *)
    echo "ERROR: Invalid direction: $DIRECTION (must be 'after', 'before', or 'both')" >&2
    exit 1
    ;;
esac

# Clamp to file boundaries
[ "$START_LINE" -lt 1 ] && START_LINE=1
[ "$END_LINE" -gt "$TOTAL_LINES" ] && END_LINE=$TOTAL_LINES

# Extract context lines and search for pattern
# Use sed to extract line range, then grep for pattern
CONTEXT=$(sed -n "${START_LINE},${END_LINE}p" "$FILE" 2>/dev/null || true)

if [ -z "$CONTEXT" ]; then
  # No context found (shouldn't happen, but handle gracefully)
  exit 1
fi

# Search for pattern in context using extended regex
if echo "$CONTEXT" | grep -qE "$PATTERN" 2>/dev/null; then
  # Pattern found in context - confirmed issue
  exit 0
else
  # Pattern NOT found in context - false positive
  exit 1
fi

