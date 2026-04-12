#!/usr/bin/env bash

set -euo pipefail

# ─── repo-hygiene.sh ─────────────────────────────────────────────────────────
# Maintainer script for AI-DDTK repository organization and hygiene.
# Phase 0: Builds the repository metadata catalog.
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/..")"
CATALOG_PATH="$REPO_ROOT/tools/mcp-server/repo-catalog.json"
OVERRIDES_PATH="$REPO_ROOT/tools/repo-catalog.overrides.json"

echo "🔍 Phase 0: Building repository metadata catalog..."

cd "$REPO_ROOT"

# Use Python to cleanly generate JSON from git ls-files
python3 -c '
import json
import os
import subprocess
import sys


REPO_ROOT = os.getcwd()
CATALOG_PATH = sys.argv[1]
OVERRIDES_PATH = sys.argv[2]


def git_output(args):
    return subprocess.check_output(args, cwd=REPO_ROOT).decode("utf-8").strip()


def load_overrides(path):
    if not os.path.exists(path):
        with open(path, "w", encoding="utf-8") as handle:
            json.dump({
                "_README": "Path-keyed overrides for repo-hygiene.sh. Each key is a tracked repo path. Values may override lifecycle_class, owner_tool, canonical, generated, status, notes, and tags.",
                "overrides": {}
            }, handle, indent=2)
        return {}

    with open(path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)

    if isinstance(payload, dict) and "overrides" in payload and isinstance(payload["overrides"], dict):
        return payload["overrides"]
    if isinstance(payload, dict):
        return payload
    return {}


def get_area(path):
    parts = path.split("/")
    return parts[0] if len(parts) > 1 else "root"


def get_file_type(path):
    basename = os.path.basename(path)
    if basename in {"Dockerfile", "LICENSE", "NOTICE", "local-wp"}:
        return "config"

    ext = os.path.splitext(path)[1].lower()
    mapping = {
        ".md": "markdown",
        ".sh": "shell",
        ".json": "json",
        ".yml": "yaml",
        ".yaml": "yaml",
        ".ts": "typescript",
        ".js": "javascript",
        ".php": "php",
        ".py": "python",
        ".neon": "config",
        ".lock": "lockfile",
        ".txt": "text",
        ".conf": "config",
        ".example": "template",
        ".png": "image",
        ".jpg": "image",
        ".jpeg": "image",
        ".gif": "image",
        ".webp": "image",
    }
    return mapping.get(ext, "config" if basename.startswith(".") else "unknown")


def get_lifecycle(path):
    basename = os.path.basename(path)

    if path.startswith("temp/"):
        if basename == ".gitkeep":
            return "temporary"
        if basename.endswith(".md"):
            return "archive-candidate"
        return "temporary"

    if path.startswith("PROJECT/3-DONE/") or path.startswith("PROJECT/4-MISC/"):
        return "archive-candidate"
    if path.startswith("PROJECT/") or basename == "4X4.md":
        return "project-tracking"
    if path.startswith("experimental/"):
        return "experimental"

    if any(part == "dist" for part in path.split("/")) or basename.endswith(".log"):
        return "generated-artifact"

    if path.startswith("docs/") or path.startswith("recipes/") or basename in {"README.md", "README-AI-DDTK.md", "AGENTS.md", "CHANGELOG.md", "MEMORY.md", ".mcp.README.md", "CLAUDE.md"}:
        return "documentation"

    if path.startswith("tools/") or path.startswith("bin/") or path.startswith("templates/") or path.startswith("test/") or path.startswith("examples/") or path.startswith(".github/") or path.startswith(".vscode/"):
        return "canonical-source"

    if basename in {".gitignore", ".wpcignore", ".mcp.json", ".mcp.local.example.json", ".ai-ddtk.config", "composer.json", "composer.lock", "package-lock.json", "phpstan.neon", "install.sh", "preflight.sh", "fix-iterate-loop.md", "local-wp"}:
        return "canonical-source" if not basename.endswith(".md") else "documentation"

    return "canonical-source"


def get_owner_tool(path):
    checks = [
        ("tools/mcp-server/", "mcp-server"),
        ("experimental/vscode-extension/", "vscode-extension"),
        ("tools/wp-code-check/", "wpcc"),
        ("bin/wpcc", "wpcc"),
        ("docs/WPCC", "wpcc"),
        ("bin/pw-auth", "pw-auth"),
        ("bin/pw-auth-helpers/", "pw-auth"),
        ("docs/PW-AUTH", "pw-auth"),
        ("bin/local-wp", "local-wp"),
        ("docs/LOCAL-WP", "local-wp"),
        ("bin/wp-ajax-test", "wp-ajax-test"),
        ("tools/wp-ajax-test/", "wp-ajax-test"),
        ("tools/qm-bridge/", "qm-bridge"),
        ("tools/servers", "servers"),
        ("tools/servers-", "servers"),
        ("experimental/servers", "servers"),
        ("tools/dev-context.sh", "servers"),
        ("tools/servers-monitor", "servers"),
        ("tools/local-nginx-shim", "servers"),
        ("PROJECT/project.sh", "project-hygiene"),
        ("tools/repo-hygiene.sh", "repo-hygiene"),
        ("PROJECT/", "project-docs"),
    ]

    for prefix, owner in checks:
        if path.startswith(prefix) or prefix in path:
            return owner

    if path.startswith("docs/") or path.startswith("recipes/"):
        return "documentation"
    if path.startswith("templates/"):
        return "templates"
    if path.startswith("examples/"):
        return "examples"
    if path.startswith("test/"):
        return "test"
    if path.startswith("temp/"):
        return "runtime-artifacts"
    return "repo"


def is_canonical(path, lifecycle_class):
    if lifecycle_class in {"canonical-source", "documentation"}:
        return True
    if path in {"4X4.md", "CHANGELOG.md", "AGENTS.md", "README.md", "README-AI-DDTK.md"}:
        return True
    return False


def is_generated(path, lifecycle_class, file_type):
    if lifecycle_class == "generated-artifact":
        return True
    if file_type == "lockfile":
        return False
    return path.endswith(".map")


def get_tags(path, area, lifecycle_class, owner_tool):
    tags = set([area, lifecycle_class, owner_tool])
    lower = path.lower()
    for tag in ["mcp", "wpcc", "playwright", "local-wp", "query-monitor", "servers", "project-doc", "docs", "recipes", "experimental"]:
        if tag in lower:
            tags.add(tag)
    if path.startswith("PROJECT/") or path == "4X4.md":
        tags.add("project-doc")
    if path.startswith("temp/"):
        tags.add("runtime")
    return sorted(tag for tag in tags if tag and tag != "repo")


def get_last_modified(path):
    try:
        return git_output(["git", "log", "-1", "--format=%cs", "--", path])
    except subprocess.CalledProcessError:
        return ""


def get_status(path, lifecycle_class):
    if path.startswith("PROJECT/"):
        try:
            with open(path, "r", encoding="utf-8") as handle:
                lines = handle.readlines()[:20]
        except OSError:
            return "tracked"

        in_frontmatter = False
        for line in lines:
            if line.strip() == "---":
                if not in_frontmatter:
                    in_frontmatter = True
                    continue
                break
            if in_frontmatter and line.lower().startswith("status:"):
                return line.split(":", 1)[1].strip().strip(chr(34)).lower()

    if lifecycle_class == "archive-candidate":
        return "review"
    return "tracked"


def get_notes(path, lifecycle_class, owner_tool):
    notes = []
    if path.startswith("temp/") and path.endswith(".md"):
        notes.append("Tracked markdown under temp should be reviewed for relocation or archival.")
    if lifecycle_class == "experimental":
        notes.append("Experimental surface; promotion requires real workflow proof and doc updates.")
    if lifecycle_class == "archive-candidate":
        notes.append("Candidate for archival or review rather than active source-of-truth use.")
    if owner_tool == "repo-hygiene":
        notes.append("Source of truth for generating the repo metadata catalog.")
    return " ".join(notes)


files = git_output(["git", "ls-files"]).splitlines()
overrides = load_overrides(OVERRIDES_PATH)
catalog = []

for path in files:
    if not os.path.exists(path):
        continue

    area = get_area(path)
    file_type = get_file_type(path)
    lifecycle_class = get_lifecycle(path)
    owner_tool = get_owner_tool(path)

    entry = {
        "path": path,
        "area": area,
        "file_type": file_type,
        "lifecycle_class": lifecycle_class,
        "owner_tool": owner_tool,
        "canonical": is_canonical(path, lifecycle_class),
        "generated": is_generated(path, lifecycle_class, file_type),
        "last_modified": get_last_modified(path),
        "status": get_status(path, lifecycle_class),
        "tags": get_tags(path, area, lifecycle_class, owner_tool),
        "notes": get_notes(path, lifecycle_class, owner_tool),
    }

    override = overrides.get(path, {})
    if isinstance(override, dict):
        for key, value in override.items():
            if key == "tags" and isinstance(value, list):
                entry["tags"] = sorted(set(entry.get("tags", [])) | set(value))
            else:
                entry[key] = value

    catalog.append(entry)

catalog.sort(key=lambda item: item["path"])

with open(CATALOG_PATH, "w", encoding="utf-8") as handle:
    json.dump(catalog, handle, indent=2)
    handle.write("\n")

print(f"✓ Catalog built with {len(catalog)} tracked files.")
' "$CATALOG_PATH" "$OVERRIDES_PATH"

echo "📂 Saved to: $CATALOG_PATH"
echo "🛠️ Overrides : $OVERRIDES_PATH"