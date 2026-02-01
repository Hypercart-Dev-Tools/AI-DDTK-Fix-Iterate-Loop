#!/usr/bin/env bash
#
# WP Code Check - Installation Script
# Version: 1.0.0
#
# Quick install for shell users
# Usage: ./install.sh

set -e

# Check if running in interactive mode (TTY available)
# If not interactive, use sensible defaults without prompting
INTERACTIVE=true
if [ ! -t 0 ] || [ ! -t 1 ]; then
  INTERACTIVE=false
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get installation directory (where this script is located)
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║           WP Code Check - Installation Wizard             ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${BLUE}Installation directory:${NC} $INSTALL_DIR"
echo ""

# Detect shell
SHELL_RC=""
SHELL_NAME=""
if [ -n "$ZSH_VERSION" ]; then
  SHELL_RC="$HOME/.zshrc"
  SHELL_NAME="zsh"
elif [ -n "$BASH_VERSION" ]; then
  if [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
  elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_RC="$HOME/.bash_profile"
  fi
  SHELL_NAME="bash"
else
  # Try to detect from SHELL environment variable
  case "$SHELL" in
    */zsh)
      SHELL_RC="$HOME/.zshrc"
      SHELL_NAME="zsh"
      ;;
    */bash)
      if [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
      elif [ -f "$HOME/.bash_profile" ]; then
        SHELL_RC="$HOME/.bash_profile"
      fi
      SHELL_NAME="bash"
      ;;
  esac
fi

if [ -z "$SHELL_RC" ]; then
  echo -e "${YELLOW}⚠ Could not detect shell configuration file${NC}"
  echo "Please manually add the alias to your shell configuration."
  SHELL_RC="$HOME/.bashrc"  # Default fallback
else
  echo -e "${GREEN}✓ Detected shell:${NC} $SHELL_NAME ($SHELL_RC)"
fi

echo ""

# Make scripts executable
echo -e "${BLUE}[1/4]${NC} Making scripts executable..."
chmod +x "$INSTALL_DIR/dist/bin/check-performance.sh"
chmod +x "$INSTALL_DIR/dist/bin/json-to-html.py"
chmod +x "$INSTALL_DIR/dist/bin/run"
if [ -f "$INSTALL_DIR/dist/bin/ai-triage.py" ]; then
  chmod +x "$INSTALL_DIR/dist/bin/ai-triage.py"
fi
echo -e "${GREEN}✓ Scripts are now executable${NC}"
echo ""

# Offer to add alias
echo -e "${BLUE}[2/5]${NC} Shell alias configuration"
echo ""

ALIAS_ADDED=false
if [ "$INTERACTIVE" = true ]; then
  # Interactive mode - ask user
  echo "Would you like to add a 'wp-check' alias to your shell?"
  echo "This will add the following line to $SHELL_RC:"
  echo ""
  echo -e "${YELLOW}  alias wp-check='$INSTALL_DIR/dist/bin/check-performance.sh --paths'${NC}"
  echo ""
  read -p "Add alias? (y/n) " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check if alias already exists
    if grep -q "alias wp-check=" "$SHELL_RC" 2>/dev/null; then
      echo -e "${YELLOW}⚠ Alias 'wp-check' already exists in $SHELL_RC${NC}"
      echo "Skipping alias creation."
    else
      echo "" >> "$SHELL_RC"
      echo "# WP Code Check alias (added by install.sh on $(date +%Y-%m-%d))" >> "$SHELL_RC"
      echo "alias wp-check='$INSTALL_DIR/dist/bin/check-performance.sh --paths'" >> "$SHELL_RC"
      echo -e "${GREEN}✓ Alias added to $SHELL_RC${NC}"
      ALIAS_ADDED=true
    fi
  else
    echo "Skipping alias creation."
    echo ""
    echo "To use WP Code Check, run:"
    echo -e "${YELLOW}  $INSTALL_DIR/dist/bin/check-performance.sh --paths <directory>${NC}"
  fi
else
  # Non-interactive mode - auto-add alias
  echo "Non-interactive mode detected. Auto-configuring alias..."
  if grep -q "alias wp-check=" "$SHELL_RC" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Alias 'wp-check' already exists in $SHELL_RC${NC}"
  else
    echo "" >> "$SHELL_RC"
    echo "# WP Code Check alias (added by install.sh on $(date +%Y-%m-%d))" >> "$SHELL_RC"
    echo "alias wp-check='$INSTALL_DIR/dist/bin/check-performance.sh --paths'" >> "$SHELL_RC"
    echo -e "${GREEN}✓ Alias added to $SHELL_RC${NC}"
    ALIAS_ADDED=true
  fi
fi

echo ""

# Offer to add shell completion
echo -e "${BLUE}[3/5]${NC} Shell completion (tab completion)"
echo ""

if [ "$INTERACTIVE" = true ]; then
  # Interactive mode - ask user
  echo "Would you like to enable tab completion for wp-check?"
  echo "This allows you to press TAB to complete options like --format, --paths, etc."
  echo ""
  read -p "Enable tab completion? (y/n) " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if grep -q "wp-check-completion.bash" "$SHELL_RC" 2>/dev/null; then
      echo -e "${YELLOW}⚠ Completion already configured in $SHELL_RC${NC}"
    else
      echo "" >> "$SHELL_RC"
      echo "# WP Code Check tab completion (added by install.sh on $(date +%Y-%m-%d))" >> "$SHELL_RC"
      echo "source '$INSTALL_DIR/dist/bin/wp-check-completion.bash'" >> "$SHELL_RC"
      echo -e "${GREEN}✓ Tab completion added to $SHELL_RC${NC}"

      if [ "$ALIAS_ADDED" = true ]; then
        echo -e "${YELLOW}Note: Run 'source $SHELL_RC' to enable alias and completion${NC}"
      fi
    fi
  else
    echo "Skipping tab completion."
    if [ "$ALIAS_ADDED" = true ]; then
      echo -e "${YELLOW}Note: Run 'source $SHELL_RC' to enable the alias${NC}"
    fi
  fi
else
  # Non-interactive mode - auto-add completion
  echo "Auto-configuring tab completion..."
  if grep -q "wp-check-completion.bash" "$SHELL_RC" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Completion already configured in $SHELL_RC${NC}"
  else
    echo "" >> "$SHELL_RC"
    echo "# WP Code Check tab completion (added by install.sh on $(date +%Y-%m-%d))" >> "$SHELL_RC"
    echo "source '$INSTALL_DIR/dist/bin/wp-check-completion.bash'" >> "$SHELL_RC"
    echo -e "${GREEN}✓ Tab completion added to $SHELL_RC${NC}"
  fi
fi

echo ""

# Test installation
echo -e "${BLUE}[4/5]${NC} Testing installation..."
if [ -d "$INSTALL_DIR/dist/tests/fixtures" ]; then
  TEST_OUTPUT=$("$INSTALL_DIR/dist/bin/check-performance.sh" --paths "$INSTALL_DIR/dist/tests/fixtures" --format json --no-log 2>&1)
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Installation test passed${NC}"
  else
    echo -e "${RED}✗ Installation test failed${NC}"
    echo "Output: $TEST_OUTPUT"
  fi
else
  echo -e "${YELLOW}⚠ Test fixtures not found, skipping test${NC}"
fi

echo ""

# Show quick start
echo -e "${BLUE}[5/5]${NC} Quick Start Guide"
echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Quick start examples:"
echo ""
echo -e "  ${YELLOW}# Scan a WordPress plugin${NC}"
echo "  wp-check ~/path/to/plugin"
echo ""
echo -e "  ${YELLOW}# Scan current directory${NC}"
echo "  wp-check ."
echo ""
echo -e "  ${YELLOW}# Scan with strict mode (fail on warnings)${NC}"
echo "  wp-check ~/plugin --strict"
echo ""
echo -e "  ${YELLOW}# Generate baseline for legacy code${NC}"
echo "  wp-check ~/plugin --generate-baseline"
echo ""
echo "Documentation:"
echo "  • User Guide:    $INSTALL_DIR/dist/README.md"
echo "  • Quick Start:   $INSTALL_DIR/SHELL-QUICKSTART.md"
echo "  • Templates:     $INSTALL_DIR/dist/HOWTO-TEMPLATES.md"
echo "  • Changelog:     $INSTALL_DIR/CHANGELOG.md"
echo ""
echo "For help:"
echo "  wp-check --help"
echo ""
echo -e "${GREEN}Happy scanning! 🚀${NC}"
echo ""

