#!/bin/bash

# WP AJAX Test - Installation Script
# Part of AI-DDTK

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DDTK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BIN_DIR="$AI_DDTK_ROOT/bin"

echo ""
echo "Installing WP AJAX Test..."
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js 14+ first."
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 14 ]; then
    echo "❌ Node.js 14+ required. Current version: $(node -v)"
    exit 1
fi

echo "✓ Node.js $(node -v) found"

# Install dependencies
echo ""
echo "Installing dependencies..."
cd "$SCRIPT_DIR"

if [ -f "package.json" ]; then
    npm install --production
    echo "✓ Dependencies installed"
else
    echo "❌ package.json not found"
    exit 1
fi

# Create bin directory if it doesn't exist
mkdir -p "$BIN_DIR"

# Create symlink
echo ""
echo "Creating symlink..."
ln -sf "$SCRIPT_DIR/index.js" "$BIN_DIR/wp-ajax-test"
chmod +x "$SCRIPT_DIR/index.js"
chmod +x "$BIN_DIR/wp-ajax-test"

echo "✓ Symlink created: $BIN_DIR/wp-ajax-test"

# Verify installation
echo ""
echo "Verifying installation..."
if "$BIN_DIR/wp-ajax-test" --version &> /dev/null; then
    VERSION=$("$BIN_DIR/wp-ajax-test" --version)
    echo "✓ wp-ajax-test $VERSION installed successfully"
else
    echo "❌ Installation verification failed"
    exit 1
fi

echo ""
echo "Installation complete!"
echo ""
echo "Usage:"
echo "  wp-ajax-test --url https://site.local --action my_ajax_action"
echo ""
echo "See README.md for more examples."
echo ""

