#!/usr/bin/env bash
#
# json-to-html.sh - Convert WP Code Check JSON logs to HTML reports
#
# Usage: ./json-to-html.sh <input.json> <output.html>
# Example: ./json-to-html.sh dist/logs/2026-01-05-032317-UTC.json dist/reports/report.html
#
# This standalone script converts JSON scan logs to beautiful HTML reports.
# It's optimized for performance using single-pass jq processing.
#
# Requirements:
#   - jq (JSON processor)
#   - bash 4.0+
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments or file not found
#   2 - jq not available
#   3 - Template file not found
#   4 - JSON parsing error

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers for file link creation
if [ -f "$SCRIPT_DIR/common-helpers.sh" ]; then
  source "$SCRIPT_DIR/common-helpers.sh"
fi

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage message
usage() {
  cat << EOF
${BLUE}WP Code Check - JSON to HTML Converter${NC}

${GREEN}Usage:${NC}
  $0 <input.json> <output.html>

${GREEN}Arguments:${NC}
  input.json   - Path to JSON scan log file
  output.html  - Path to output HTML report file

${GREEN}Example:${NC}
  $0 dist/logs/2026-01-05-032317-UTC.json dist/reports/report.html

${GREEN}Description:${NC}
  Converts WP Code Check JSON scan logs into beautiful, interactive HTML reports.
  Uses optimized single-pass jq processing for fast conversion of large scan results.

${GREEN}Requirements:${NC}
  - jq (install via: brew install jq)

EOF
  exit 1
}

# Check arguments
if [ $# -ne 2 ]; then
  echo -e "${RED}Error: Missing required arguments${NC}" >&2
  echo "" >&2
  usage
fi

INPUT_JSON="$1"
OUTPUT_HTML="$2"

# Validate input file exists
if [ ! -f "$INPUT_JSON" ]; then
  echo -e "${RED}Error: Input file not found: $INPUT_JSON${NC}" >&2
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required but not installed${NC}" >&2
  echo -e "${YELLOW}Install with: brew install jq${NC}" >&2
  exit 2
fi

# Template file location
TEMPLATE_FILE="$SCRIPT_DIR/templates/report-template.html"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo -e "${RED}Error: HTML template not found at $TEMPLATE_FILE${NC}" >&2
  exit 3
fi

echo -e "${BLUE}Converting JSON to HTML...${NC}"
echo -e "  Input:  ${GREEN}$INPUT_JSON${NC}"
echo -e "  Output: ${GREEN}$OUTPUT_HTML${NC}"

# Validate JSON
echo -e "${BLUE}Validating JSON...${NC}" >&2
if ! jq empty "$INPUT_JSON" 2>/dev/null; then
  echo -e "${RED}Error: Invalid JSON in input file${NC}" >&2
  exit 4
fi

# Extract basic metadata using jq (read file directly, not via variable)
echo -e "${BLUE}Extracting metadata...${NC}" >&2
version=$(jq -r '.version // "Unknown"' "$INPUT_JSON")
timestamp=$(jq -r '.timestamp // "Unknown"' "$INPUT_JSON")
paths=$(jq -r '.paths_scanned // "."' "$INPUT_JSON")
total_errors=$(jq -r '.summary.total_errors // 0' "$INPUT_JSON")
total_warnings=$(jq -r '.summary.total_warnings // 0' "$INPUT_JSON")
baselined=$(jq -r '.summary.baselined // 0' "$INPUT_JSON")
stale_baseline=$(jq -r '.summary.stale_baseline // 0' "$INPUT_JSON")
exit_code=$(jq -r '.summary.exit_code // 0' "$INPUT_JSON")
strict_mode=$(jq -r '(.strict_mode // false | tostring)' "$INPUT_JSON")
findings_count=$(jq -r '(.findings | length)' "$INPUT_JSON")
dry_violations_count=$(jq -r '(.magic_string_violations | length)' "$INPUT_JSON")

# Extract fixture validation info
fixture_status=$(jq -r '.fixture_validation.status // "not_run"' "$INPUT_JSON")
fixture_passed=$(jq -r '.fixture_validation.passed // 0' "$INPUT_JSON")
fixture_failed=$(jq -r '.fixture_validation.failed // 0' "$INPUT_JSON")

# Set fixture status for HTML
fixture_status_class="skipped"
fixture_status_text="Fixtures: N/A"
if [ "$fixture_status" = "passed" ]; then
  fixture_status_class="passed"
  fixture_status_text="✓ Detection Verified (${fixture_passed} fixtures)"
elif [ "$fixture_status" = "failed" ]; then
  fixture_status_class="failed"
  fixture_status_text="⚠ Detection Warning (${fixture_failed}/${fixture_passed} failed)"
elif [ "$fixture_status" = "skipped" ]; then
  fixture_status_class="skipped"
  fixture_status_text="○ Fixtures Skipped"
fi

# Extract project information
project_type=$(jq -r '.project.type // "unknown"' "$INPUT_JSON")
project_name=$(jq -r '.project.name // ""' "$INPUT_JSON")
project_version=$(jq -r '.project.version // ""' "$INPUT_JSON")
project_author=$(jq -r '.project.author // ""' "$INPUT_JSON")
files_analyzed=$(jq -r '.project.files_analyzed // 0' "$INPUT_JSON")
lines_of_code=$(jq -r '.project.lines_of_code // 0' "$INPUT_JSON")

# Build project info HTML
project_info_html=""
if [ -n "$project_name" ] && [ "$project_name" != "Unknown" ]; then
  # Map project type to display label
  type_display="$project_type"
  case "$project_type" in
    plugin) type_display="WordPress Plugin" ;;
    theme) type_display="WordPress Theme" ;;
    fixture) type_display="Fixture Test" ;;
    unknown) type_display="Unknown" ;;
  esac

  project_info_html="<div style='font-size: 1.1em; font-weight: 600; margin-bottom: 5px;'>PROJECT INFORMATION</div>"
  project_info_html+="<div>Name: $project_name</div>"
  if [ -n "$project_version" ]; then
    project_info_html+="<div>Version: $project_version</div>"
  fi
  project_info_html+="<div>Type: $type_display</div>"
  if [ -n "$project_author" ]; then
    project_info_html+="<div>Author: $project_author</div>"
  fi
  if [ "$files_analyzed" != "0" ]; then
    formatted_files=$(printf "%'d" "$files_analyzed" 2>/dev/null || echo "$files_analyzed")
    project_info_html+="<div>Files Analyzed: $formatted_files PHP files</div>"
  fi
  if [ "$lines_of_code" != "0" ]; then
    # Format with commas for readability
    formatted_loc=$(printf "%'d" "$lines_of_code" 2>/dev/null || echo "$lines_of_code")
    project_info_html+="<div>Lines Reviewed: $formatted_loc lines of code</div>"
  fi
fi

# Create clickable links for scanned paths
abs_path="$paths"
if [[ "$paths" != /* ]]; then
  abs_path=$(realpath "$paths" 2>/dev/null || echo "$paths")
fi

# Use helper function if available, otherwise create simple link
if type create_directory_link &>/dev/null; then
  paths_link=$(create_directory_link "$abs_path")
else
  paths_link="<a href=\"file://$abs_path\" style=\"color: #667eea;\">$paths</a>"
fi

# Create clickable link for JSON log file
json_log_link=""
if [ -f "$INPUT_JSON" ]; then
  if type create_file_link &>/dev/null; then
    log_link=$(create_file_link "$INPUT_JSON")
  else
    log_link="<a href=\"file://$INPUT_JSON\" style=\"color: #667eea;\">$INPUT_JSON</a>"
  fi
  json_log_link="<div style=\"margin-top: 8px;\">JSON Log: $log_link <button class=\"copy-btn\" onclick=\"copyLogPath()\" title=\"Copy JSON log path to clipboard\">📋 Copy Path</button></div>"
fi

# Determine status
status_class="pass"
status_message="✓ All critical checks passed!"
if [ "$exit_code" -ne 0 ]; then
  status_class="fail"
  if [ "$total_errors" -gt 0 ]; then
    status_message="✗ Check failed with $total_errors error type(s)"
  elif [ "$strict_mode" = "true" ] && [ "$total_warnings" -gt 0 ]; then
    status_message="✗ Check failed in strict mode with $total_warnings warning type(s)"
  fi
fi

echo -e "${BLUE}Processing findings (${findings_count} total)...${NC}"

# Generate findings HTML using optimized single-pass jq
# This is the key optimization - process ALL findings in one jq call
# Note: We skip URL encoding for performance - file:// links work fine without it
findings_html=""
if [ "$findings_count" -gt 0 ]; then
  findings_html=$(jq -r --arg base_path "$abs_path" '
    .findings[] |
    # Build absolute file path (simple concatenation)
    (if (.file | startswith("/")) then .file else ($base_path + "/" + .file) end) as $abs_file |
    # Generate HTML for this finding (no URL encoding for speed)
    "<div class=\"finding \(.impact // "MEDIUM" | ascii_downcase)\">
      <div class=\"finding-header\">
        <div class=\"finding-title\">\(.message // .id)</div>
        <span class=\"badge \(.impact // "MEDIUM" | ascii_downcase)\">\(.impact // "MEDIUM")</span>
      </div>
      <div class=\"finding-details\">
        <div class=\"file-path\"><a href=\"file://\($abs_file)\" style=\"color: #667eea; text-decoration: none;\" title=\"Click to open file\">\(.file // "")</a>:\(.line // "")</div>
        <div class=\"code-snippet\">\(.code // "" | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;"))</div>
      </div>
    </div>"
  ' "$INPUT_JSON")
else
  findings_html="<p style='text-align: center; color: #6c757d; padding: 20px;'>No findings detected. Great job! 🎉</p>"
fi

echo -e "${BLUE}Processing checks...${NC}"

# Generate checks HTML (single-pass jq)
checks_html=$(jq -r '
  .checks[] |
  "<div class=\"finding \(if .status == "passed" then "low" else (.impact | ascii_downcase) end)\">
    <div class=\"finding-header\">
      <div class=\"finding-title\">\(.name)</div>
      <span class=\"badge \(if .status == "passed" then "low" else (.impact | ascii_downcase) end)\">\(.status | ascii_upcase)</span>
    </div>
    <div class=\"finding-details\">Findings: \(.findings_count)</div>
  </div>"
' "$INPUT_JSON")

echo -e "${BLUE}Processing DRY violations (${dry_violations_count} total)...${NC}"

# Generate Magic String violations HTML (single-pass jq)
dry_violations_html=""
if [ "$dry_violations_count" -gt 0 ]; then
  dry_violations_html=$(jq -r '
    .magic_string_violations[] |
    "<div class=\"finding medium\">
      <div class=\"finding-header\">
        <div class=\"finding-title\">🔄 \(.duplicated_string)</div>
        <span class=\"badge medium\">MEDIUM</span>
      </div>
      <div class=\"finding-details\">
        <div style=\"margin-bottom: 10px;\">
          <strong>Pattern:</strong> \(.pattern)<br>
          <strong>Duplicated String:</strong> <code>\(.duplicated_string)</code><br>
          <strong>Files:</strong> \(.file_count) files | <strong>Total Occurrences:</strong> \(.total_count)
        </div>
        <div style=\"margin-top: 10px;\">
          <strong>Locations:</strong>
          <ul style=\"margin: 5px 0 0 20px; padding: 0;\">
            \(.locations | map("<li style=\"font-family: monospace; font-size: 0.9em;\">\(.file):\(.line)</li>") | join(""))
          </ul>
        </div>
      </div>
    </div>"
  ' "$INPUT_JSON")
else
  dry_violations_html="<p style='text-align: center; color: #6c757d; padding: 20px;'>No magic strings detected. Great job! 🎉</p>"
fi

echo -e "${BLUE}Generating HTML report...${NC}"

# Read template
html_content=$(cat "$TEMPLATE_FILE")

# Escape paths for JavaScript (escape backslashes, quotes, and newlines)
js_abs_path=$(echo "$abs_path" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\'/g; s/\"/\\\\\"/g")
js_log_path=""
if [ -f "$INPUT_JSON" ]; then
  js_log_path=$(echo "$INPUT_JSON" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\'/g; s/\"/\\\\\"/g")
fi

# Replace all placeholders in template
# Using sed for simple string replacement (faster than multiple bash substitutions)
html_content="${html_content//\{\{PROJECT_INFO\}\}/$project_info_html}"
html_content="${html_content//\{\{VERSION\}\}/$version}"
html_content="${html_content//\{\{TIMESTAMP\}\}/$timestamp}"
html_content="${html_content//\{\{PATHS_SCANNED\}\}/$paths_link}"
html_content="${html_content//\{\{JSON_LOG_LINK\}\}/$json_log_link}"
html_content="${html_content//\{\{JS_FOLDER_PATH\}\}/$js_abs_path}"
html_content="${html_content//\{\{JS_LOG_PATH\}\}/$js_log_path}"
html_content="${html_content//\{\{TOTAL_ERRORS\}\}/$total_errors}"
html_content="${html_content//\{\{TOTAL_WARNINGS\}\}/$total_warnings}"
html_content="${html_content//\{\{MAGIC_STRING_VIOLATIONS_COUNT\}\}/$dry_violations_count}"
html_content="${html_content//\{\{BASELINED\}\}/$baselined}"
html_content="${html_content//\{\{STALE_BASELINE\}\}/$stale_baseline}"
html_content="${html_content//\{\{EXIT_CODE\}\}/$exit_code}"
html_content="${html_content//\{\{STRICT_MODE\}\}/$strict_mode}"
html_content="${html_content//\{\{STATUS_CLASS\}\}/$status_class}"
html_content="${html_content//\{\{STATUS_MESSAGE\}\}/$status_message}"
html_content="${html_content//\{\{FINDINGS_COUNT\}\}/$findings_count}"
html_content="${html_content//\{\{FINDINGS_HTML\}\}/$findings_html}"
html_content="${html_content//\{\{MAGIC_STRING_VIOLATIONS_HTML\}\}/$dry_violations_html}"
html_content="${html_content//\{\{CHECKS_HTML\}\}/$checks_html}"
html_content="${html_content//\{\{FIXTURE_STATUS_CLASS\}\}/$fixture_status_class}"
html_content="${html_content//\{\{FIXTURE_STATUS_TEXT\}\}/$fixture_status_text}"

# Create output directory if it doesn't exist
output_dir=$(dirname "$OUTPUT_HTML")
mkdir -p "$output_dir"

# Write HTML file
echo "$html_content" > "$OUTPUT_HTML"

# Success message
echo ""
echo -e "${GREEN}✓ HTML report generated successfully!${NC}"
echo -e "  ${BLUE}Report:${NC} $OUTPUT_HTML"
echo -e "  ${BLUE}Size:${NC} $(du -h "$OUTPUT_HTML" | cut -f1)"
echo ""

# Auto-open in browser if available (optional)
if command -v open &> /dev/null; then
  echo -e "${YELLOW}Opening report in browser...${NC}"
  open "$OUTPUT_HTML" 2>/dev/null || true
elif command -v xdg-open &> /dev/null; then
  echo -e "${YELLOW}Opening report in browser...${NC}"
  xdg-open "$OUTPUT_HTML" 2>/dev/null || true
fi

exit 0
