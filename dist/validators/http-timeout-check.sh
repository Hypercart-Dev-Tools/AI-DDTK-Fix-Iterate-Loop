#!/usr/bin/env bash
#
# HTTP Timeout Validator
# Checks if an HTTP request has a timeout parameter
#
# Usage: http-timeout-check.sh <file> <line_number> [context_lines]
#
# Exit codes:
#   0 = Timeout NOT found (issue - no timeout specified)
#   1 = Timeout found (false positive - timeout exists)
#   2 = Error (invalid input)
#
# Checks for:
#   - 'timeout' => N in inline args
#   - 'timeout' => N in variable definition before the call
#
# Example:
#   http-timeout-check.sh file.php 42 20
#   Checks if timeout exists within ±20 lines of line 42

FILE="$1"
LINE_NUMBER="$2"
CONTEXT_LINES="${3:-20}"

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

# Calculate context window (check before and after)
start_line=$((LINE_NUMBER - CONTEXT_LINES))
[ "$start_line" -lt 1 ] && start_line=1
end_line=$((LINE_NUMBER + CONTEXT_LINES))

# Extract context
context=$(sed -n "${start_line},${end_line}p" "$FILE" 2>/dev/null || true)

if [ -z "$context" ]; then
    echo "Error: Could not extract context from file" >&2
    exit 2
fi

# Check for timeout in context (case-insensitive)
# Look for: 'timeout' => N or "timeout" => N or 'timeout' : N
if echo "$context" | grep -qiE "'timeout'[[:space:]]*=>|\"timeout\"[[:space:]]*=>|'timeout'[[:space:]]*:"; then
    # Timeout FOUND - but check if it's being filtered away
    # If the options/args array is passed through apply_filters(), the timeout can be removed
    # This is a real vulnerability because a filter could strip the timeout

    # Check if apply_filters is used with the options/args variable
    # Pattern: apply_filters(..., $options) or apply_filters(..., $args)
    # This catches cases like: $options = apply_filters(..., $options)
    if echo "$context" | grep -qiE "apply_filters.*\\\$.*options|apply_filters.*\\\$.*args"; then
        # Timeout is set BUT then filtered - a filter could remove it
        # This is a CONFIRMED ISSUE (exit 0)
        exit 0
    else
        # Timeout is set and NOT filtered - this is a false positive
        exit 1
    fi
else
    # Timeout NOT found - this is an issue (no timeout)
    exit 0
fi

