#!/usr/bin/env bash
#
# Neochrome WP Toolkit - Slack Integration
#
# Posts performance audit results to Slack using webhooks.
#
# Usage:
#   ./post-to-slack.sh <results.json>
#   ./post-to-slack.sh <results.json> --webhook-url "https://..."
#
# Environment Variables:
#   SLACK_WEBHOOK_URL     - Slack webhook URL (required if not passed via --webhook-url)
#   SLACK_CHANNEL         - Override channel (optional, if webhook supports it)
#   SLACK_USERNAME        - Bot username (default: "Neochrome Performance Bot")
#   SLACK_ICON_EMOJI      - Bot icon (default: ":rocket:")
#   NOTIFICATION_FORMAT   - Message format: compact|detailed (default: compact)
#   GITHUB_REPOSITORY     - Auto-set by GitHub Actions
#   GITHUB_REF            - Auto-set by GitHub Actions
#   GITHUB_RUN_ID         - Auto-set by GitHub Actions
#   GITHUB_SERVER_URL     - Auto-set by GitHub Actions
#   GITHUB_SHA            - Auto-set by GitHub Actions
#
# Exit Codes:
#   0 - Success
#   1 - Missing required parameters
#   2 - Invalid JSON file
#   3 - Slack API error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=dist/bin/lib/colors.sh
source "$LIB_DIR/colors.sh"
# shellcheck source=dist/bin/lib/json-helpers.sh
source "$LIB_DIR/json-helpers.sh"

# Defaults
WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
CHANNEL="${SLACK_CHANNEL:-}"
USERNAME="${SLACK_USERNAME:-Neochrome Performance Bot}"
ICON_EMOJI="${SLACK_ICON_EMOJI:-:rocket:}"
FORMAT="${NOTIFICATION_FORMAT:-compact}"

# Parse arguments
JSON_FILE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --webhook-url)
      WEBHOOK_URL="$2"
      shift 2
      ;;
    --channel)
      CHANNEL="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    *)
      if [ -z "$JSON_FILE" ]; then
        JSON_FILE="$1"
      else
        echo -e "${RED}Error: Unknown argument '$1'${NC}"
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate inputs
if [ -z "$JSON_FILE" ]; then
  echo -e "${RED}Error: No JSON file specified${NC}"
  echo "Usage: $0 <results.json> [--webhook-url URL] [--channel CHANNEL] [--format compact|detailed]"
  exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
  echo -e "${RED}Error: File not found: $JSON_FILE${NC}"
  exit 2
fi

if [ -z "$WEBHOOK_URL" ]; then
  echo -e "${RED}Error: SLACK_WEBHOOK_URL environment variable not set${NC}"
  echo "Set it in your environment or pass --webhook-url"
  exit 1
fi

require_jq

# Validate JSON
if ! validate_json_file "$JSON_FILE"; then
  exit 2
fi

echo -e "${BLUE}Posting results to Slack...${NC}"

# Call the message formatter
SLACK_MESSAGE=$("$SCRIPT_DIR/format-slack-message.sh" "$JSON_FILE" --format "$FORMAT")

# Build the payload
PAYLOAD=$(cat <<EOF
{
  "username": "$USERNAME",
  "icon_emoji": "$ICON_EMOJI"
EOF
)

# Add channel if specified
if [ -n "$CHANNEL" ]; then
  PAYLOAD="$PAYLOAD,\"channel\": \"$CHANNEL\""
fi

# Add the formatted message blocks
PAYLOAD="$PAYLOAD,$SLACK_MESSAGE}"

# Post to Slack
HTTP_CODE=$(curl -s -o /tmp/slack-response.json -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$WEBHOOK_URL")

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✓ Successfully posted to Slack${NC}"
  exit 0
else
  echo -e "${RED}✗ Failed to post to Slack (HTTP $HTTP_CODE)${NC}"
  if [ -f /tmp/slack-response.json ]; then
    cat /tmp/slack-response.json
  fi
  exit 3
fi
