#!/usr/bin/env bash
#
# WP Code Check - CI Environment Emulator for Tests
#
# Purpose: Run tests in a CI-emulated environment (no TTY, Linux-like behavior)
# Usage:   ./tests/run-tests-ci-mode.sh [--trace]
#
# This script emulates GitHub Actions CI environment by:
# - Removing TTY access (no /dev/tty)
# - Setting CI environment variables
# - Redirecting stdin from /dev/null
# - Using dumb terminal mode
#

set -euo pipefail

# Colors for output (even in CI mode, we want readable local output)
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  WP Code Check - CI Environment Emulator${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Unset terminal-related vars to emulate CI
echo -e "${YELLOW}[CI EMULATOR] Setting up CI-like environment...${NC}"
unset TTY 2>/dev/null || true
export TERM=dumb
export CI=true
export GITHUB_ACTIONS=true
export DEBIAN_FRONTEND=noninteractive

echo -e "${GREEN}✓${NC} Environment variables set:"
echo "  - TERM=dumb"
echo "  - CI=true"
echo "  - GITHUB_ACTIONS=true"
echo "  - TTY unset"
echo ""

# Check for required dependencies
echo -e "${YELLOW}[CI EMULATOR] Checking dependencies...${NC}"
missing_deps=()

if ! command -v jq >/dev/null 2>&1; then
  missing_deps+=("jq")
fi

if ! command -v perl >/dev/null 2>&1; then
  missing_deps+=("perl")
fi

if [ ${#missing_deps[@]} -gt 0 ]; then
  echo -e "${RED}✗ Missing dependencies: ${missing_deps[*]}${NC}"
  echo ""
  echo "Install with:"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  brew install ${missing_deps[*]}"
  else
    echo "  sudo apt-get install -y ${missing_deps[*]}"
  fi
  exit 1
fi

echo -e "${GREEN}✓${NC} All dependencies present (jq, perl)"
echo ""

# Detect TTY detachment method
echo -e "${YELLOW}[CI EMULATOR] Detecting TTY detachment method...${NC}"

if command -v setsid >/dev/null 2>&1; then
  TTY_METHOD="setsid"
  echo -e "${GREEN}✓${NC} Using setsid (Linux-style TTY detachment)"
elif command -v script >/dev/null 2>&1; then
  TTY_METHOD="script"
  echo -e "${GREEN}✓${NC} Using script (macOS fallback)"
else
  echo -e "${RED}✗ No TTY detachment method available${NC}"
  echo "  Neither 'setsid' nor 'script' command found"
  echo "  Falling back to direct execution (may not fully emulate CI)"
  TTY_METHOD="direct"
fi
echo ""

# Show TTY status before detachment
echo -e "${YELLOW}[CI EMULATOR] Current TTY status:${NC}"
if [ -t 0 ]; then
  echo -e "  stdin:  ${GREEN}TTY${NC}"
else
  echo -e "  stdin:  ${BLUE}not a TTY${NC}"
fi

if [ -t 1 ]; then
  echo -e "  stdout: ${GREEN}TTY${NC}"
else
  echo -e "  stdout: ${BLUE}not a TTY${NC}"
fi

if [ -w /dev/tty ] 2>/dev/null; then
  echo -e "  /dev/tty: ${GREEN}writable${NC} (will be unavailable after detachment)"
else
  echo -e "  /dev/tty: ${BLUE}not writable${NC}"
fi
echo ""

# Run tests with TTY detachment
echo -e "${YELLOW}[CI EMULATOR] Running tests in detached mode...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pass through any arguments (like --trace)
TEST_ARGS="$@"

case "$TTY_METHOD" in
  setsid)
    # Linux: setsid detaches from controlling terminal
    setsid --wait bash "$SCRIPT_DIR/run-fixture-tests.sh" $TEST_ARGS </dev/null
    EXIT_CODE=$?
    ;;
  
  script)
    # macOS: script command can detach TTY
    # -q = quiet (no "Script started" messages)
    script -q /dev/null bash "$SCRIPT_DIR/run-fixture-tests.sh" $TEST_ARGS </dev/null
    EXIT_CODE=$?
    ;;
  
  direct)
    # Fallback: direct execution with stdin from /dev/null
    bash "$SCRIPT_DIR/run-fixture-tests.sh" $TEST_ARGS </dev/null
    EXIT_CODE=$?
    ;;
esac

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CI Emulation Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}✓ Tests passed in CI-emulated environment${NC}"
else
  echo -e "${RED}✗ Tests failed with exit code: $EXIT_CODE${NC}"
fi

exit $EXIT_CODE

