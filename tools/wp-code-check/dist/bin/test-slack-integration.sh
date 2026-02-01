#!/usr/bin/env bash
#
# Neochrome WP Toolkit - Slack Integration Test
#
# Tests the Slack integration with mock data (no real webhook needed).
# Useful for:
#   - Verifying message formatting
#   - Testing before setting up real webhooks
#   - CI/CD pipeline validation
#
# Usage:
#   ./test-slack-integration.sh [--format compact|detailed]
#
# What it does:
#   1. Creates sample JSON results
#   2. Formats the Slack message
#   3. Shows the formatted output
#   4. Optionally sends to a test webhook if SLACK_WEBHOOK_URL is set

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=dist/bin/lib/colors.sh
source "$LIB_DIR/colors.sh"

FORMAT="${1:---format}"
if [ "$FORMAT" = "--format" ]; then
  FORMAT="${2:-compact}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Neochrome Slack Integration Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create sample JSON with errors
echo -e "${BLUE}[1/3]${NC} Creating sample audit results..."

SAMPLE_JSON="/tmp/neochrome-test-results.json"
cat > "$SAMPLE_JSON" <<'EOF'
{
  "version": "1.0.43",
  "timestamp": "2025-12-29T12:00:00Z",
  "paths_scanned": "src/",
  "strict_mode": false,
  "summary": {
    "total_errors": 2,
    "total_warnings": 3,
    "baselined": 1,
    "stale_baseline": 0,
    "exit_code": 1
  },
  "findings": [
    {
      "id": "rest-endpoint-unbounded",
      "severity": "error",
      "impact": "CRITICAL",
      "file": "src/api/products.php",
      "line": 42,
      "message": "register_rest_route without per_page/limit pagination guard",
      "code": "register_rest_route('api/v1', '/products', array("
    },
    {
      "id": "unbounded-posts-per-page",
      "severity": "error",
      "impact": "CRITICAL",
      "file": "src/queries/posts.php",
      "line": 15,
      "message": "Unbounded posts_per_page",
      "code": "'posts_per_page' => -1"
    },
    {
      "id": "order-by-rand",
      "severity": "warning",
      "impact": "HIGH",
      "file": "src/widgets/featured.php",
      "line": 28,
      "message": "Randomized ordering (ORDER BY RAND)",
      "code": "'orderby' => 'rand'"
    }
  ],
  "checks": [
    {
      "name": "REST endpoints without pagination/limits",
      "impact": "CRITICAL",
      "status": "failed",
      "findings_count": 1
    },
    {
      "name": "Unbounded posts_per_page",
      "impact": "CRITICAL",
      "status": "failed",
      "findings_count": 1
    },
    {
      "name": "Randomized ordering (ORDER BY RAND)",
      "impact": "HIGH",
      "status": "failed",
      "findings_count": 1
    }
  ]
}
EOF

echo -e "${GREEN}✓${NC} Created sample results with 2 errors, 3 warnings"
echo ""

# Format the message
echo -e "${BLUE}[2/3]${NC} Formatting Slack message (format: $FORMAT)..."
echo ""

FORMATTED_MESSAGE=$("$SCRIPT_DIR/format-slack-message.sh" "$SAMPLE_JSON" --format "$FORMAT")

echo -e "${GREEN}✓${NC} Message formatted successfully"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Formatted Slack Payload Preview:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$FORMATTED_MESSAGE" | head -30
echo ""
echo "  ... (truncated for display)"
echo ""

# Test sending if webhook is configured
echo -e "${BLUE}[3/3]${NC} Checking for test webhook..."

if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  echo -e "${YELLOW}→${NC} SLACK_WEBHOOK_URL is set, sending test message..."
  
  if "$SCRIPT_DIR/post-to-slack.sh" "$SAMPLE_JSON" --format "$FORMAT"; then
    echo -e "${GREEN}✓${NC} Test message sent successfully!"
  else
    echo -e "${YELLOW}⚠${NC}  Failed to send (check your webhook URL)"
  fi
else
  echo -e "${YELLOW}ℹ${NC}  SLACK_WEBHOOK_URL not set (skipping actual send)"
  echo ""
  echo "  To test with a real webhook:"
  echo "    export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/YOUR/WEBHOOK'"
  echo "    ./test-slack-integration.sh"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ Test complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup
rm -f "$SAMPLE_JSON"
