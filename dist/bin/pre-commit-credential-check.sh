#!/usr/bin/env bash
#
# Neochrome WP Toolkit - Pre-Commit Hook for Credential Protection
#
# This hook prevents commits that contain webhook URLs, API keys, or other
# sensitive credentials.
#
# Installation:
#   cp pre-commit-credential-check.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# To bypass (NOT RECOMMENDED):
#   git commit --no-verify
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=dist/bin/lib/colors.sh
source "$LIB_DIR/colors.sh"

# Patterns that should NEVER be committed
FORBIDDEN_PATTERNS=(
  # Webhook URLs
  "hooks.slack.com/services"
  "discord.com/api/webhooks"
  "discordapp.com/api/webhooks"
  
  # API endpoints with secrets
  "api.slack.com.*token="
  "github.com.*token="
  
  # Environment variable assignments with URLs
  "SLACK_WEBHOOK_URL=http"
  "DISCORD_WEBHOOK_URL=http"
  "WEBHOOK_URL=http"
  
  # Common secret variable patterns
  "API_KEY=\"[A-Za-z0-9]"
  "API_SECRET=\"[A-Za-z0-9]"
  "API_TOKEN=\"[A-Za-z0-9]"
  "GITHUB_TOKEN=\"[A-Za-z0-9]"
  
  # Base64 encoded secrets (common in configs)
  "api_key.*base64"
  "apiKey.*[A-Za-z0-9]{32,}"
  
  # AWS credentials
  "aws_access_key_id"
  "aws_secret_access_key"
  
  # Private keys
  "BEGIN PRIVATE KEY"
  "BEGIN RSA PRIVATE KEY"
)

# Check if this is a merge commit
if git rev-parse -q --verify MERGE_HEAD >/dev/null; then
  echo "Merge commit detected, skipping credential check"
  exit 0
fi

# Get list of files being committed
FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$FILES" ]; then
  exit 0
fi

echo "🔍 Checking for credentials in staged files..."

VIOLATIONS_FOUND=false

# Check each pattern
for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
  # Check staged content for pattern
  if git diff --cached | grep -iE "$pattern" > /dev/null 2>&1; then
    if [ "$VIOLATIONS_FOUND" = false ]; then
      echo ""
      echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "${RED}🚨 CREDENTIAL DETECTED IN STAGED CHANGES!${NC}"
      echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo ""
      VIOLATIONS_FOUND=true
    fi
    
    echo -e "${YELLOW}⚠️  Forbidden pattern found:${NC} $pattern"
    
    # Show which files contain the pattern
    for file in $FILES; do
      if git diff --cached "$file" | grep -iE "$pattern" > /dev/null 2>&1; then
        echo "   → In file: $file"
      fi
    done
    echo ""
  fi
done

# Check for suspicious file names being added
# Note: .env.example and .env.sample are excluded as they are template files
SUSPICIOUS_FILES=(
  "*-webhook-url.txt"
  "*-api-key.txt"
  "*-token.txt"
  "*-secret.txt"
  "*.env"
  ".env"
  ".env.local"
  ".env.production"
  ".env.development"
  "credentials.json"
  "secrets.json"
  "webhooks.json"
)

for file in $FILES; do
  for suspicious in "${SUSPICIOUS_FILES[@]}"; do
    if [[ "$file" == $suspicious ]]; then
      if [ "$VIOLATIONS_FOUND" = false ]; then
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}🚨 SUSPICIOUS FILE DETECTED IN STAGED CHANGES!${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        VIOLATIONS_FOUND=true
      fi
      
      echo -e "${YELLOW}⚠️  Suspicious file:${NC} $file"
      echo "   This file pattern typically contains credentials"
      echo ""
    fi
  done
done

if [ "$VIOLATIONS_FOUND" = true ]; then
  echo -e "${RED}COMMIT REJECTED - Potential credentials detected${NC}"
  echo ""
  echo "To fix this:"
  echo ""
  echo "1. Remove the credential from your code"
  echo "   git reset HEAD <file>"
  echo "   # Edit the file to remove credentials"
  echo ""
  echo "2. Store credentials in GitHub Secrets instead:"
  echo "   Repository → Settings → Secrets → New secret"
  echo ""
  echo "3. Reference secrets via environment variables:"
  echo "   WEBHOOK_URL=\"\${SLACK_WEBHOOK_URL:-}\""
  echo ""
  echo "4. Re-stage your changes:"
  echo "   git add <file>"
  echo "   git commit"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "To bypass this check (NOT RECOMMENDED):"
  echo "  git commit --no-verify"
  echo ""
  exit 1
fi

echo "✓ No credentials detected in staged changes"
exit 0
