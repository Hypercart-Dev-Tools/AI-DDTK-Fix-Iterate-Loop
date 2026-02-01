#!/usr/bin/env bash
#
# WP Code Check by Hypercart - Magic String Detector ("DRY")
# Version: 1.0.0
#
# Detects magic strings (hardcoded string literals) in WordPress codebases
# by finding strings (option names, transient keys, etc.) that appear in
# multiple files, violating the DRY (Don't Repeat Yourself) principle.
#
# Usage:
#   ./dist/bin/find-dry.sh --paths /path/to/plugin
#   ./dist/bin/find-dry.sh --paths . --format json
#   ./dist/bin/find-dry.sh --paths . --top 5
#
# Options:
#   --paths "dir1 dir2"      Paths to scan (default: current directory)
#   --format text|json       Output format (default: text)
#   --top N                  Show only top N violations (default: all)
#   --min-files N            Minimum files for violation (default: from pattern)
#   --min-matches N          Minimum total matches (default: from pattern)
#   --verbose                Show all file locations, not just count
#   --help                   Show this help message
#

set -eo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source shared libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common-helpers.sh"

# Default options
PATHS="."
OUTPUT_FORMAT="text"
TOP_K=""
MIN_FILES_OVERRIDE=""
MIN_MATCHES_OVERRIDE=""
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --paths)
      PATHS="$2"
      shift 2
      ;;
    --format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    --top)
      TOP_K="$2"
      shift 2
      ;;
    --min-files)
      MIN_FILES_OVERRIDE="$2"
      shift 2
      ;;
    --min-matches)
      MIN_MATCHES_OVERRIDE="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Text output helper (only for text format)
text_echo() {
  if [ "$OUTPUT_FORMAT" = "text" ]; then
    echo -e "$1"
  fi
}

# Patterns directory
PATTERNS_DIR="$PLUGIN_DIR/dist/patterns/dry"

# Check if patterns directory exists
if [ ! -d "$PATTERNS_DIR" ]; then
  echo "ERROR: Patterns directory not found: $PATTERNS_DIR" >&2
  exit 1
fi

# Find all enabled patterns
PATTERN_FILES=$(find "$PATTERNS_DIR" -name "*.json" -type f | sort)

if [ -z "$PATTERN_FILES" ]; then
  echo "ERROR: No pattern files found in $PATTERNS_DIR" >&2
  exit 1
fi

# Initialize results
# Use temp file instead of associative arrays (bash 3.2 compatible)
VIOLATIONS_FILE=$(mktemp)
trap "rm -f '$VIOLATIONS_FILE'" EXIT
TOTAL_VIOLATIONS=0

text_echo "${BOLD}WP Code Check - Magic String Detector (\"DRY\")${NC}"
text_echo "Scanning: $PATHS"
text_echo ""

# Process each pattern
while IFS= read -r pattern_file; do
  [ -z "$pattern_file" ] && continue
  pattern_name=$(basename "$pattern_file" .json)
  
  # Extract pattern fields using grep/sed (no jq dependency)
  enabled=$(grep '"enabled"' "$pattern_file" | head -1 | sed 's/.*"enabled"[[:space:]]*:[[:space:]]*\([^,]*\).*/\1/' | tr -d ' ')
  
  if [ "$enabled" != "true" ]; then
    continue
  fi
  
  title=$(grep '"title"' "$pattern_file" | head -1 | sed 's/.*"title"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  severity=$(grep '"severity"' "$pattern_file" | head -1 | sed 's/.*"severity"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  # Extract search pattern - match everything between quotes, handling escaped quotes
  # Use awk to properly extract the JSON string value
  search_pattern=$(grep '"search_pattern"' "$pattern_file" | head -1 | awk -F'"search_pattern"[[:space:]]*:[[:space:]]*"' '{print $2}' | sed 's/"[[:space:]]*,*$//' | sed 's/\\\\/\\/g')
  
  # Extract aggregation settings
  min_files=$(grep '"min_distinct_files"' "$pattern_file" | head -1 | sed 's/.*"min_distinct_files"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/')
  min_matches=$(grep '"min_total_matches"' "$pattern_file" | head -1 | sed 's/.*"min_total_matches"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/')
  
  # Apply overrides if provided
  [ -n "$MIN_FILES_OVERRIDE" ] && min_files="$MIN_FILES_OVERRIDE"
  [ -n "$MIN_MATCHES_OVERRIDE" ] && min_matches="$MIN_MATCHES_OVERRIDE"
  
  text_echo "${BLUE}▸ Checking: $title${NC}"

  # Run grep and capture matches
  # We need to extract the capture group (the duplicated string)
  matches=$(grep -rHn --include="*.php" -E "$search_pattern" "$PATHS" 2>&1 || true)

  # Check for grep errors
  if echo "$matches" | grep -q "No such file or directory"; then
    text_echo "${RED}  ✗ Error running grep: $matches${NC}"
    text_echo "${RED}  Pattern: $search_pattern${NC}"
    text_echo "${RED}  Paths: $PATHS${NC}"
    continue
  fi

  if [ -z "$matches" ]; then
    text_echo "${GREEN}  ✓ No matches found${NC}"
    text_echo ""
    continue
  fi

  # Parse matches and extract duplicated strings
  # This is the aggregation logic - group by the captured string
  # Use temp files instead of associative arrays (bash 3.2 compatible)
  temp_matches=$(mktemp)
  temp_aggregated=$(mktemp)
  trap "rm -f '$temp_matches' '$temp_aggregated'" EXIT

  while IFS= read -r match; do
    [ -z "$match" ] && continue

    file=$(echo "$match" | cut -d: -f1)
    line=$(echo "$match" | cut -d: -f2)
    code=$(echo "$match" | cut -d: -f3-)

    # Extract the duplicated string from the match
    # For option names: get_option('my_plugin_api_key') -> my_plugin_api_key
    # For transient keys: get_transient('user_cache') -> user_cache
    # For capabilities: current_user_can('manage_options') -> manage_options

    # Use sed to extract the FIRST string between quotes after the opening paren
    # Match: ( followed by optional spaces, then quote, then capture group, then quote
    duplicated_string=$(echo "$code" | sed -n "s/.*( *['\"]\\([a-z0-9_]*\\)['\"].*/\\1/p" | head -1)

    if [ -z "$duplicated_string" ]; then
      continue
    fi

    # Store: duplicated_string|file|line
    echo "$duplicated_string|$file|$line" >> "$temp_matches"
  done <<< "$matches"

  # Aggregate by duplicated string
  if [ -f "$temp_matches" ] && [ -s "$temp_matches" ]; then
    # Sort and count unique strings
    # Note: uniq -c outputs "   COUNT STRING" with leading spaces
    sort "$temp_matches" | cut -d'|' -f1 | uniq -c | while read -r line; do
      count=$(echo "$line" | awk '{print $1}')
      string=$(echo "$line" | awk '{print $2}')
      # Count distinct files for this string
      file_count=$(grep "^$string|" "$temp_matches" | cut -d'|' -f2 | sort -u | wc -l | tr -d ' ')
      total_count=$(grep "^$string|" "$temp_matches" | wc -l | tr -d ' ')

      # Apply thresholds
      if [ "$file_count" -lt "$min_files" ]; then
        continue
      fi

      if [ "$total_count" -lt "$min_matches" ]; then
        continue
      fi

      # Get all locations for this string
      # Format: file1:line1|file2:line2|...
      locations=$(grep "^$string|" "$temp_matches" | cut -d'|' -f2,3 | sed 's/|/:/' | tr '\n' '|' | sed 's/|$//')

      # Store aggregated result: string|file_count|total_count|locations
      echo "$string|$file_count|$total_count|$locations" >> "$temp_aggregated"
    done
  fi

  # Count violations for this pattern
  pattern_violations=0
  if [ -f "$temp_aggregated" ] && [ -s "$temp_aggregated" ]; then
    pattern_violations=$(wc -l < "$temp_aggregated" | tr -d ' ')
    TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + pattern_violations))

    # Store violations for final reporting
    while IFS='|' read -r duplicated_string file_count total_count locations; do
      violation_key="${pattern_name}:${duplicated_string}"
      echo "$violation_key|$title|$severity|$duplicated_string|$file_count|$total_count|$locations" >> "$VIOLATIONS_FILE"
    done < "$temp_aggregated"
  fi

  if [ "$pattern_violations" -eq 0 ]; then
    text_echo "${GREEN}  ✓ No violations above threshold${NC}"
  else
    text_echo "${RED}  ✗ Found $pattern_violations violation(s)${NC}"
  fi
  text_echo ""

  # Clean up temp files for next pattern
  rm -f "$temp_matches" "$temp_aggregated"
done <<< "$PATTERN_FILES"

# Output results
if [ "$OUTPUT_FORMAT" = "json" ]; then
  # JSON output
  echo "{"
  echo "  \"scan_timestamp\": \"$(timestamp_iso8601)\","
  echo "  \"paths\": \"$PATHS\","
  echo "  \"total_violations\": $TOTAL_VIOLATIONS,"
  echo "  \"violations\": ["

  if [ -f "$VIOLATIONS_FILE" ] && [ -s "$VIOLATIONS_FILE" ]; then
    first=true
    while IFS='|' read -r violation_key title severity duplicated_string file_count total_count locations; do
      if [ "$first" = true ]; then
        first=false
      else
        echo ","
      fi

      echo "    {"
      echo "      \"pattern\": \"$title\","
      echo "      \"severity\": \"$severity\","
      echo "      \"duplicated_string\": \"$duplicated_string\","
      echo "      \"file_count\": $file_count,"
      echo "      \"total_count\": $total_count,"
      echo "      \"locations\": ["

      location_first=true
      echo "$locations" | tr '|' '\n' | while IFS=':' read -r loc_file loc_line; do
        if [ "$location_first" = true ]; then
          location_first=false
        else
          echo ","
        fi

        echo -n "        {\"file\": \"$loc_file\", \"line\": $loc_line}"
      done

      echo ""
      echo "      ]"
      echo -n "    }"
    done < "$VIOLATIONS_FILE"
  fi

  echo ""
  echo "  ]"
  echo "}"
else
  # Text output
  if [ "$TOTAL_VIOLATIONS" -eq 0 ]; then
    text_echo "${GREEN}${BOLD}━━━ NO MAGIC STRINGS FOUND ━━━${NC}"
    text_echo ""
    text_echo "All scanned code follows DRY principles - no magic strings detected. Great work! 🎉"
    exit 0
  fi

  text_echo "${RED}${BOLD}━━━ MAGIC STRINGS FOUND ━━━${NC}"
  text_echo ""

  # Sort violations by file count (descending)
  if [ -f "$VIOLATIONS_FILE" ] && [ -s "$VIOLATIONS_FILE" ]; then
    sorted_violations=$(sort -t'|' -k5 -rn "$VIOLATIONS_FILE")

    violation_num=0
    echo "$sorted_violations" | while IFS='|' read -r violation_key title severity duplicated_string file_count total_count locations; do
      [ -z "$violation_key" ] && continue

      violation_num=$((violation_num + 1))

      # Apply top-K limit if specified
      if [ -n "$TOP_K" ] && [ "$violation_num" -gt "$TOP_K" ]; then
        break
      fi

      # Color by severity
      severity_color="$YELLOW"
      [ "$severity" = "HIGH" ] && severity_color="$RED"
      [ "$severity" = "CRITICAL" ] && severity_color="$RED"
      [ "$severity" = "LOW" ] && severity_color="$BLUE"

      text_echo "${severity_color}[$severity]${NC} ${BOLD}$title${NC}"
      text_echo "  String: ${BOLD}'$duplicated_string'${NC}"
      text_echo "  Appears in: ${BOLD}$file_count files${NC} (${BOLD}$total_count occurrences${NC})"

      if [ "$VERBOSE" = true ]; then
        text_echo "  Locations:"
        echo "$locations" | tr '|' '\n' | while IFS=':' read -r loc_file loc_line; do
          text_echo "    - $loc_file:$loc_line"
        done
      else
        # Show first 3 locations
        text_echo "  Sample locations:"
        count=0
        total_locs=$(echo "$locations" | tr '|' '\n' | wc -l | tr -d ' ')
        echo "$locations" | tr '|' '\n' | while IFS=':' read -r loc_file loc_line; do
          text_echo "    - $loc_file:$loc_line"
          count=$((count + 1))
          [ "$count" -ge 3 ] && break
        done

        remaining=$((total_locs - 3))
        if [ "$remaining" -gt 0 ]; then
          text_echo "    ${BLUE}... and $remaining more (use --verbose to see all)${NC}"
        fi
      fi

      text_echo ""
    done
  fi

  text_echo "${BOLD}━━━ SUMMARY ━━━${NC}"
  text_echo "Total magic strings: ${RED}$TOTAL_VIOLATIONS${NC}"
  text_echo ""
  text_echo "${YELLOW}Recommendation:${NC} Extract magic strings to constants or helper methods."
  text_echo "See: dist/patterns/dry/README.md for refactoring guidance."
fi

exit 0


