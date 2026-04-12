#!/usr/bin/env bash

set -euo pipefail

# ─── repo-hygiene.sh ─────────────────────────────────────────────────────────
# Maintainer script for AI-DDTK repository organization and hygiene.
# Phase 0: Builds the repository metadata catalog.
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/..")"
CATALOG_PATH="$REPO_ROOT/tools/mcp-server/repo-catalog.json"

echo "🔍 Phase 0: Building repository metadata catalog..."

cd "$REPO_ROOT"

# Use Python to cleanly generate JSON from git ls-files
python3 -c '
import sys, json, os, subprocess

def get_lifecycle(path):
    if path.startswith("PROJECT/3-DONE/") or path.startswith("PROJECT/4-MISC/"):
        return "archive-candidate"
    if path.startswith("PROJECT/"):
        return "project-tracking"
    if path.startswith("experimental/"):
        return "experimental"
    if path.startswith("temp/"):
        return "temporary"
    if path.endswith(".log") or path.endswith(".lock") or "/dist/" in path:
        return "generated-artifact"
    if path.startswith("docs/") or path.startswith("recipes/") or path.endswith(".md"):
        return "documentation"
    if path.startswith("tools/") or path.startswith("bin/") or path.startswith("templates/") or path.startswith("test/"):
        return "canonical-source"
    return "uncategorized"

def get_area(path):
    parts = path.split("/")
    return parts[0] if len(parts) > 1 else "root"

files = subprocess.check_output(["git", "ls-files"]).decode("utf-8").splitlines()
catalog = []

for f in files:
    if not os.path.exists(f): continue
    
    catalog.append({
        "path": f,
        "area": get_area(f),
        "lifecycle_class": get_lifecycle(f),
        "status": "tracked"
    })

with open(sys.argv[1], "w") as out:
    json.dump(catalog, out, indent=2)

print(f"✓ Catalog built with {len(catalog)} tracked files.")
' "$CATALOG_PATH"

echo "📂 Saved to: $CATALOG_PATH"