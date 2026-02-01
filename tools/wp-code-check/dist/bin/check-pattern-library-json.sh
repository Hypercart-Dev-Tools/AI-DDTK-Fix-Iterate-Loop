#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_FILE="$SCRIPT_DIR/../PATTERN-LIBRARY.json"

if [ ! -f "$JSON_FILE" ]; then
  echo "[ERROR] Missing $JSON_FILE" >&2
  exit 1
fi

if python3 -S -m json.tool "$JSON_FILE" >/dev/null 2>&1; then
  echo "[OK] PATTERN-LIBRARY.json is valid JSON"
  exit 0
else
  echo "[ERROR] PATTERN-LIBRARY.json is invalid JSON" >&2
  exit 1
fi
