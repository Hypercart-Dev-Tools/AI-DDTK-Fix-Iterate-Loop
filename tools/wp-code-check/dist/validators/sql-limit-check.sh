#!/usr/bin/env bash
#
# SQL LIMIT Validator
# Checks if a SQL query contains a LIMIT clause
#
# Usage: sql-limit-check.sh <file> <line_number> [context_lines]
#
# Exit codes:
#   0 = LIMIT NOT found (issue - unbounded query)
#   1 = LIMIT found (false positive - query has limit)
#   2 = Error (invalid input)
#
# Example:
#   sql-limit-check.sh file.php 42 5
#   Checks if LIMIT appears within ±5 lines of line 42

FILE="$1"
LINE_NUMBER="$2"
CONTEXT_LINES="${3:-5}"  # Default to 5 lines if not specified

# Validate inputs
if [ -z "$FILE" ] || [ -z "$LINE_NUMBER" ]; then
    echo "Error: Missing required arguments" >&2
    echo "Usage: $0 <file> <line_number> [context_lines]" >&2
    exit 2
fi

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE" >&2
    exit 2
fi

if ! [[ "$LINE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid line number: $LINE_NUMBER" >&2
    exit 2
fi

# Calculate context window
start_line=$((LINE_NUMBER - CONTEXT_LINES))
[ "$start_line" -lt 1 ] && start_line=1
end_line=$((LINE_NUMBER + CONTEXT_LINES))

# Extract context
context=$(sed -n "${start_line},${end_line}p" "$FILE" 2>/dev/null || true)

if [ -z "$context" ]; then
    echo "Error: Could not extract context from file" >&2
    exit 2
fi

# Check if LIMIT exists in context (case-insensitive)
if echo "$context" | grep -qi "LIMIT"; then
    # LIMIT found - this is a false positive (query has limit)
    exit 1
else
    # LIMIT NOT found - this is an issue (unbounded query)
    exit 0
fi

