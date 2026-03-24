#!/usr/bin/env bash
# MCP server launcher — builds TypeScript on first run or when dist is missing.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$DIR/dist/src/index.js" ]; then
  npm --prefix "$DIR" install --ignore-scripts 2>/dev/null
  npm --prefix "$DIR" run build 2>/dev/null
fi

exec node "$DIR/dist/src/index.js" "$@"
