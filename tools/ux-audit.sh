#!/usr/bin/env bash
# ============================================================
# AI-DDTK UX Audit — Automated Checks
# Runs Steps 1-3 of the Weekly UX Audit recipe.
# See: recipes/weekly-ux-audit.md
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAIL_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; }

# ============================================================
# Step 1: Version Consistency
# ============================================================
echo ""
echo "=== Step 1: Version Consistency ==="

INSTALL_VER=$(grep -m1 '^# Version:' "$SCRIPT_DIR/install.sh" | sed 's/# Version: *//')
CHANGELOG_VER=$(grep -m1 '^## \[' "$SCRIPT_DIR/CHANGELOG.md" | sed 's/## \[\(.*\)\].*/\1/')

if [ "$INSTALL_VER" = "$CHANGELOG_VER" ]; then
    pass "install.sh ($INSTALL_VER) matches CHANGELOG.md ($CHANGELOG_VER)"
else
    fail "install.sh ($INSTALL_VER) != CHANGELOG.md ($CHANGELOG_VER)"
fi

# ============================================================
# Step 2: Command-Doc Parity
# ============================================================
echo ""
echo "=== Step 2: Command-Doc Parity ==="

# 2a: Check bin/ tools are documented
for tool in "$BIN_DIR"/*; do
    [ -d "$tool" ] && continue  # skip directories like pw-auth-helpers
    name=$(basename "$tool")
    # Check AGENTS.md
    if grep -qi "$name" "$SCRIPT_DIR/AGENTS.md"; then
        pass "bin/$name found in AGENTS.md"
    else
        fail "bin/$name NOT mentioned in AGENTS.md"
    fi
    # Check CLI-REFERENCE.md
    if grep -qi "$name" "$SCRIPT_DIR/docs/CLI-REFERENCE.md"; then
        pass "bin/$name found in CLI-REFERENCE.md"
    else
        fail "bin/$name NOT mentioned in CLI-REFERENCE.md"
    fi
done

# 2b: Check install.sh subcommands appear in help text
# Only match the main case block (4-space indent), not inner case patterns (8-space)
SUBCOMMANDS=$(grep -oP '^    \K[a-z][-a-z]+(?=\))' "$SCRIPT_DIR/install.sh" || true)
HELP_TEXT=$(sed -n '/^show_usage/,/^}/p' "$SCRIPT_DIR/install.sh")

for cmd in $SUBCOMMANDS; do
    if echo "$HELP_TEXT" | grep -q "$cmd"; then
        pass "install.sh subcommand '$cmd' found in show_usage()"
    else
        fail "install.sh subcommand '$cmd' NOT in show_usage()"
    fi
done

# ============================================================
# Step 3: Internal Link Validation
# ============================================================
echo ""
echo "=== Step 3: Internal Link Validation ==="

check_links_in_file() {
    local file="$1"
    local dir
    dir=$(dirname "$file")
    # Extract relative markdown links — skip http/https, anchors-only, and images
    grep -oP '\[.*?\]\(\K(?!https?://|#)[^)]+' "$file" 2>/dev/null | while read -r link; do
        # Strip anchor
        target="${link%%#*}"
        [ -z "$target" ] && continue
        # Resolve relative to file's directory
        if [ -f "$dir/$target" ]; then
            pass "$file -> $target"
        else
            fail "$file -> $target (file not found)"
        fi
    done
}

# Check key onboarding docs
for mdfile in \
    "$SCRIPT_DIR/README.md" \
    "$SCRIPT_DIR/AGENTS.md" \
    "$SCRIPT_DIR/docs"/*.md \
    "$SCRIPT_DIR/recipes"/*.md; do
    [ -f "$mdfile" ] && check_links_in_file "$mdfile"
done

# ============================================================
# Summary
# ============================================================
echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}All checks passed.${NC}"
    exit 0
else
    echo -e "${RED}${FAIL_COUNT} check(s) failed.${NC} See details above."
    exit 1
fi
