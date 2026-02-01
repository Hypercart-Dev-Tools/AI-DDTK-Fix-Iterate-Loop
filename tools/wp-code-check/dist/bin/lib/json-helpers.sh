# shellcheck shell=bash
#!/usr/bin/env bash
#
# Neochrome WP Toolkit - JSON Helper Functions
#
# Utilities for validating JSON files and ensuring jq availability.

# Validate JSON file with jq
# Usage: validate_json_file "file.json"
# Returns: 0 if valid, 1 if invalid or file missing
validate_json_file() {
  local json_file="$1"

  if [ ! -f "$json_file" ]; then
    echo "Error: JSON file not found: $json_file" >&2
    return 1
  fi

  if ! command -v jq &> /dev/null; then
    echo "Warning: jq not installed, skipping JSON validation" >&2
    return 0
  fi

  if ! jq empty "$json_file" 2>/dev/null; then
    echo "Error: Invalid JSON in $json_file" >&2
    return 1
  fi

  return 0
}

# Require jq to be installed (used when jq is mandatory)
# Usage: require_jq
require_jq() {
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for this operation" >&2
    echo "Install: brew install jq (macOS) or apt-get install jq (Linux)" >&2
    exit 1
  fi
}
