#!/usr/bin/env bash
#
# Parameter Presence Validator
# Checks if a specific parameter exists in the context window around a match
#
# Usage: parameter-presence-check.sh <file> <line_number> <parameter_name> [context_lines]
#
# Exit codes:
#   0 = Parameter NOT found (issue - missing parameter)
#   1 = Parameter found (false positive - parameter exists)
#   2 = Error (invalid input)
#
# Example:
#   parameter-presence-check.sh file.php 42 "number" 10
#   Checks if 'number' or "number" appears within ±10 lines of line 42

FILE="$1"
LINE_NUMBER="$2"
PARAMETER_NAME="$3"
CONTEXT_LINES="${4:-10}"  # Default to 10 lines if not specified

# Validate inputs
if [ -z "$FILE" ] || [ -z "$LINE_NUMBER" ] || [ -z "$PARAMETER_NAME" ]; then
    echo "Error: Missing required arguments" >&2
    echo "Usage: $0 <file> <line_number> <parameter_name> [context_lines]" >&2
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

# Check if parameter exists in context (both single and double quotes)
if echo "$context" | grep -q -e "'${PARAMETER_NAME}'" -e "\"${PARAMETER_NAME}\""; then
    # Parameter found - this is a false positive
    exit 1
else
    # Parameter NOT found - this is an issue
    exit 0
fi

