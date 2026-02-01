#!/usr/bin/env bash
#
# WP Code Check - Docker-based CI Test Runner
#
# Purpose: Run tests in a true Ubuntu container (identical to GitHub Actions)
# Usage:   ./tests/run-tests-docker.sh [--trace] [--build] [--shell]
#
# Options:
#   --trace   Enable trace mode for detailed debugging
#   --build   Force rebuild of Docker image
#   --shell   Drop into interactive shell instead of running tests
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
TRACE_MODE=""
FORCE_BUILD=false
INTERACTIVE_SHELL=false

for arg in "$@"; do
  case $arg in
    --trace)
      TRACE_MODE="--trace"
      shift
      ;;
    --build)
      FORCE_BUILD=true
      shift
      ;;
    --shell)
      INTERACTIVE_SHELL=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $arg${NC}"
      echo "Usage: $0 [--trace] [--build] [--shell]"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  WP Code Check - Docker CI Test Runner${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}✗ Docker is not installed${NC}"
  echo ""
  echo "Install Docker:"
  echo "  macOS: https://docs.docker.com/desktop/install/mac-install/"
  echo "  Linux: https://docs.docker.com/engine/install/"
  exit 1
fi

echo -e "${GREEN}✓${NC} Docker is installed: $(docker --version)"
echo ""

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}✗ Docker daemon is not running${NC}"
  echo ""
  echo "Start Docker Desktop (macOS) or Docker daemon (Linux)"
  exit 1
fi

echo -e "${GREEN}✓${NC} Docker daemon is running"
echo ""

# Image name
IMAGE_NAME="wp-code-check-test"

# Check if image exists
IMAGE_EXISTS=$(docker images -q "$IMAGE_NAME" 2>/dev/null)

if [ -z "$IMAGE_EXISTS" ] || [ "$FORCE_BUILD" = true ]; then
  if [ "$FORCE_BUILD" = true ]; then
    echo -e "${YELLOW}[DOCKER] Force rebuilding image...${NC}"
  else
    echo -e "${YELLOW}[DOCKER] Image not found, building...${NC}"
  fi
  
  echo -e "${BLUE}Building Docker image: $IMAGE_NAME${NC}"
  echo ""
  
  # Build from dist directory (parent of tests/)
  if docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$DIST_DIR"; then
    echo ""
    echo -e "${GREEN}✓${NC} Docker image built successfully"
  else
    echo ""
    echo -e "${RED}✗ Docker build failed${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}✓${NC} Docker image exists: $IMAGE_NAME"
  echo "  (Use --build to force rebuild)"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$INTERACTIVE_SHELL" = true ]; then
  echo -e "${YELLOW}[DOCKER] Starting interactive shell...${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "You are now in the Ubuntu container. Try:"
  echo "  ./tests/run-fixture-tests.sh"
  echo "  ./tests/run-fixture-tests.sh --trace"
  echo "  exit  (to leave the container)"
  echo ""
  docker run --rm -it "$IMAGE_NAME" /bin/bash
else
  echo -e "${YELLOW}[DOCKER] Running tests in Ubuntu container...${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Run tests with optional trace mode
  if [ -n "$TRACE_MODE" ]; then
    docker run --rm "$IMAGE_NAME" bash -c "cd /workspace && ./tests/run-fixture-tests.sh --trace"
  else
    docker run --rm "$IMAGE_NAME" bash -c "cd /workspace && ./tests/run-fixture-tests.sh"
  fi
  
  EXIT_CODE=$?
  
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  Docker Test Complete${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Tests passed in Ubuntu Docker container${NC}"
  else
    echo -e "${RED}✗ Tests failed with exit code: $EXIT_CODE${NC}"
  fi
  
  exit $EXIT_CODE
fi

