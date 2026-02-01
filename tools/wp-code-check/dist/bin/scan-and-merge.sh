#!/usr/bin/env bash
#
# Scan multiple directories individually and merge JSON results
# Usage: bash scan-and-merge.sh <base_dir> <output_file>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${1:-.}"
OUTPUT_FILE="${2:-merged-scan.json}"

echo "🔍 Scanning subdirectories in: $BASE_DIR"
echo "📄 Output file: $OUTPUT_FILE"
echo ""

# Find all subdirectories with PHP files
SCAN_DIRS=()
while IFS= read -r dir; do
  php_count=$(find "$dir" -name "*.php" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$php_count" -gt 0 ]; then
    SCAN_DIRS+=("$dir")
    echo "  Found: $dir ($php_count PHP files)"
  fi
done < <(find "$BASE_DIR" -maxdepth 1 -type d | grep -v "^${BASE_DIR}$" | sort)

# Also scan root PHP files
root_php_count=$(find "$BASE_DIR" -maxdepth 1 -name "*.php" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$root_php_count" -gt 0 ]; then
  echo "  Found: $BASE_DIR (root) ($root_php_count PHP files)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Array to store JSON log files
JSON_LOGS=()

# Scan root PHP files first
if [ "$root_php_count" -gt 0 ]; then
  echo "📊 Scanning root directory..."
  for php_file in "$BASE_DIR"/*.php; do
    [ -f "$php_file" ] || continue
    echo "  Scanning: $(basename "$php_file")"
    bash "$SCRIPT_DIR/check-performance.sh" --paths "$php_file" --format json > /dev/null 2>&1 || true
  done
  
  # Find the latest log file
  latest_log=$(ls -t "$SCRIPT_DIR/../logs"/*.json 2>/dev/null | head -1)
  if [ -n "$latest_log" ] && [ -s "$latest_log" ]; then
    JSON_LOGS+=("$latest_log")
    echo "  ✅ Scan complete: $(basename "$latest_log")"
  fi
  echo ""
fi

# Scan each subdirectory
for dir in "${SCAN_DIRS[@]}"; do
  dir_name=$(basename "$dir")
  echo "📊 Scanning: $dir_name/"
  
  bash "$SCRIPT_DIR/check-performance.sh" --paths "$dir" --format json > /dev/null 2>&1 || true
  
  # Find the latest log file
  latest_log=$(ls -t "$SCRIPT_DIR/../logs"/*.json 2>/dev/null | head -1)
  if [ -n "$latest_log" ] && [ -s "$latest_log" ]; then
    JSON_LOGS+=("$latest_log")
    echo "  ✅ Scan complete: $(basename "$latest_log")"
  else
    echo "  ⚠️  Scan failed or produced no output"
  fi
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 Merging ${#JSON_LOGS[@]} scan results..."
echo ""

# Check if we have any logs to merge
if [ "${#JSON_LOGS[@]}" -eq 0 ]; then
  echo "❌ No scan results to merge!"
  exit 1
fi

# If only one log, just copy it
if [ "${#JSON_LOGS[@]}" -eq 1 ]; then
  cp "${JSON_LOGS[0]}" "$OUTPUT_FILE"
  echo "✅ Single scan result copied to: $OUTPUT_FILE"
  exit 0
fi

# Merge multiple JSON files using Python
python3 "$SCRIPT_DIR/merge-json-scans.py" "${JSON_LOGS[@]}" > "$OUTPUT_FILE"

if [ -s "$OUTPUT_FILE" ]; then
  echo "✅ Merged scan results written to: $OUTPUT_FILE"
  echo ""
  
  # Show summary
  if command -v jq &> /dev/null; then
    echo "📊 Summary:"
    jq -r '  "  Files analyzed: \(.summary.files_analyzed)",
             "  Total errors: \(.summary.total_errors)",
             "  Total warnings: \(.summary.total_warnings)",
             "  Total findings: \(.findings | length)"' "$OUTPUT_FILE"
  fi
else
  echo "❌ Merge failed!"
  exit 1
fi

