#!/usr/bin/env bash
#
# WP Code Check - Docker Installation Helper
#
# This script checks if Docker is installed and provides installation instructions.
# It cannot install Docker automatically (requires user interaction), but guides you through it.
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Docker Installation Helper${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Detect OS
OS_TYPE="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS_TYPE="macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS_TYPE="Linux"
fi

echo -e "${BLUE}Detected OS:${NC} $OS_TYPE"
echo ""

# Check if Docker is installed
echo -e "${YELLOW}[1/3] Checking if Docker is installed...${NC}"
if command -v docker >/dev/null 2>&1; then
  DOCKER_VERSION=$(docker --version)
  echo -e "${GREEN}✓ Docker is installed:${NC} $DOCKER_VERSION"
else
  echo -e "${RED}✗ Docker is not installed${NC}"
  echo ""
  
  if [ "$OS_TYPE" = "macOS" ]; then
    echo -e "${YELLOW}Installation Instructions for macOS:${NC}"
    echo ""
    echo "Option 1: Download Docker Desktop (Recommended)"
    echo "  1. Visit: https://docs.docker.com/desktop/install/mac-install/"
    echo "  2. Download Docker Desktop for Mac (Intel or Apple Silicon)"
    echo "  3. Open the .dmg file and drag Docker to Applications"
    echo "  4. Launch Docker Desktop from Applications"
    echo "  5. Wait for Docker to start (whale icon in menu bar)"
    echo ""
    echo "Option 2: Install via Homebrew"
    echo "  brew install --cask docker"
    echo "  open /Applications/Docker.app"
    echo ""
    echo -e "${BLUE}After installation, run this script again to verify.${NC}"
    
  elif [ "$OS_TYPE" = "Linux" ]; then
    echo -e "${YELLOW}Installation Instructions for Linux:${NC}"
    echo ""
    
    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      DISTRO=$ID
      
      case $DISTRO in
        ubuntu|debian)
          echo "For Ubuntu/Debian:"
          echo "  sudo apt-get update"
          echo "  sudo apt-get install -y ca-certificates curl gnupg"
          echo "  sudo install -m 0755 -d /etc/apt/keyrings"
          echo "  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
          echo "  sudo chmod a+r /etc/apt/keyrings/docker.gpg"
          echo "  echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo \"\$VERSION_CODENAME\") stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
          echo "  sudo apt-get update"
          echo "  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
          echo "  sudo systemctl start docker"
          echo "  sudo systemctl enable docker"
          echo "  sudo usermod -aG docker \$USER"
          echo "  newgrp docker  # Or log out and back in"
          ;;
        fedora|rhel|centos)
          echo "For Fedora/RHEL/CentOS:"
          echo "  sudo dnf -y install dnf-plugins-core"
          echo "  sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo"
          echo "  sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
          echo "  sudo systemctl start docker"
          echo "  sudo systemctl enable docker"
          echo "  sudo usermod -aG docker \$USER"
          echo "  newgrp docker  # Or log out and back in"
          ;;
        *)
          echo "For other distributions, see: https://docs.docker.com/engine/install/"
          ;;
      esac
    else
      echo "See: https://docs.docker.com/engine/install/"
    fi
    
    echo ""
    echo -e "${BLUE}After installation, run this script again to verify.${NC}"
  else
    echo "Visit: https://docs.docker.com/get-docker/"
  fi
  
  exit 1
fi

echo ""

# Check if Docker daemon is running
echo -e "${YELLOW}[2/3] Checking if Docker daemon is running...${NC}"
if docker info >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Docker daemon is running${NC}"
else
  echo -e "${RED}✗ Docker daemon is not running${NC}"
  echo ""
  
  if [ "$OS_TYPE" = "macOS" ]; then
    echo "Start Docker Desktop:"
    echo "  1. Open Applications folder"
    echo "  2. Double-click Docker.app"
    echo "  3. Wait for whale icon to appear in menu bar"
    echo "  4. Run this script again"
  elif [ "$OS_TYPE" = "Linux" ]; then
    echo "Start Docker daemon:"
    echo "  sudo systemctl start docker"
    echo "  sudo systemctl enable docker  # Start on boot"
  fi
  
  exit 1
fi

echo ""

# Test Docker with hello-world
echo -e "${YELLOW}[3/3] Testing Docker with hello-world container...${NC}"
if docker run --rm hello-world >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Docker is working correctly${NC}"
else
  echo -e "${RED}✗ Docker test failed${NC}"
  echo ""
  echo "Try running manually:"
  echo "  docker run --rm hello-world"
  exit 1
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Docker is fully installed and working!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "You can now run Docker-based tests:"
echo "  ./tests/run-tests-docker.sh"
echo "  ./tests/run-tests-docker.sh --trace"
echo "  ./tests/run-tests-docker.sh --shell"
echo ""

