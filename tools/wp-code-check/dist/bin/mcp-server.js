#!/usr/bin/env node
/**
 * WP Code Check MCP compatibility shim.
 *
 * The unified AI-DDTK MCP server now owns the WPCC resources.
 * This legacy entrypoint remains only to preserve existing configs
 * while directing callers to tools/mcp-server.
 */

import { access } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

async function main() {
  const currentDir = path.dirname(fileURLToPath(import.meta.url));
  const unifiedEntry = path.resolve(currentDir, "../../../mcp-server/dist/src/index.js");

  try {
    await access(unifiedEntry);
  } catch {
    throw new Error(
      `Unified AI-DDTK MCP server build not found at ${unifiedEntry}. Run \`cd tools/mcp-server && npm run build\` first.`
    );
  }

  console.error(
    "[DEPRECATED] tools/wp-code-check/dist/bin/mcp-server.js now forwards to tools/mcp-server/dist/src/index.js. Update MCP client configs to use the unified server directly."
  );

  const unifiedModule = await import(pathToFileURL(unifiedEntry).href);

  if (typeof unifiedModule.main !== "function") {
    throw new Error(`Unified AI-DDTK MCP entrypoint does not export main(): ${unifiedEntry}`);
  }

  await unifiedModule.main();
}

main().catch((error) => {
  console.error("Fatal error in WPCC MCP compatibility shim:", error);
  process.exit(1);
});

