#!/usr/bin/env node

import path from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import * as z from "zod/v4";
import { createLocalWpHandlers } from "./handlers/local-wp.js";
import { SiteState } from "./state.js";

const siteSummarySchema = z.object({
  name: z.string(),
  path: z.string(),
  hasWordPress: z.boolean(),
});

const pluginSchema = z.object({
  name: z.string(),
  status: z.string(),
  version: z.string().nullable(),
});

function getPackageRoot(moduleUrl: string): string {
  const currentDir = path.dirname(fileURLToPath(moduleUrl));
  const parentDir = path.dirname(currentDir);

  return path.basename(parentDir) === "dist" ? path.resolve(currentDir, "../..") : path.resolve(currentDir, "..");
}

function jsonText(data: unknown): string {
  return JSON.stringify(data, null, 2);
}

function successResult<T extends object>(structuredContent: T) {
  return {
    content: [{ type: "text" as const, text: jsonText(structuredContent) }],
    structuredContent: structuredContent as T & Record<string, unknown>,
  };
}

function errorResult(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);

  return {
    isError: true,
    content: [{ type: "text" as const, text: message }],
  };
}

export function createServer() {
  const packageRoot = getPackageRoot(import.meta.url);
  const repoRoot = path.resolve(packageRoot, "../..");
  const state = new SiteState();
  const handlers = createLocalWpHandlers({ state, repoRoot });

  const server = new McpServer({
    name: "ai-ddtk-mcp",
    version: "0.1.0",
  });

  server.registerTool(
    "local_wp_list_sites",
    {
      description: "List LocalWP sites that contain a WordPress installation.",
      outputSchema: {
        site: z.null(),
        sites: z.array(siteSummarySchema),
      },
    },
    async () => successResult(await handlers.listSites()),
  );

  server.registerTool(
    "local_wp_select_site",
    {
      description: "Select the active LocalWP site for read-only convenience tools.",
      inputSchema: {
        site: z.string().min(1).describe("Local site name"),
      },
      outputSchema: {
        site: z.string(),
        activeSite: z.string(),
        path: z.string(),
      },
    },
    async ({ site }) => {
      try {
        return successResult(await handlers.selectSite(site));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "local_wp_get_active_site",
    {
      description: "Get the currently selected LocalWP site, if one has been set.",
      outputSchema: {
        site: z.string().nullable(),
        activeSite: z.string().nullable(),
        path: z.string().nullable(),
      },
    },
    async () => successResult(await handlers.getActiveSite()),
  );

  server.registerTool(
    "local_wp_test_connectivity",
    {
      description: "Check LocalWP directory, wp-config.php, MySQL socket, and wp cli info availability.",
      inputSchema: {
        site: z.string().min(1).optional().describe("Local site name; falls back to the active site if omitted"),
      },
      outputSchema: {
        site: z.string(),
        status: z.enum(["ok", "error"]),
        checks: z.object({
          dir: z.boolean(),
          wpConfig: z.boolean(),
          mysql: z.boolean(),
          wpCli: z.boolean(),
        }),
      },
    },
    async ({ site }) => {
      try {
        return successResult(await handlers.testConnectivity(site));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "local_wp_get_site_info",
    {
      description: "Get core version, PHP version, active theme, plugins, and site URL for a LocalWP site.",
      inputSchema: {
        site: z.string().min(1).optional().describe("Local site name; falls back to the active site if omitted"),
      },
      outputSchema: {
        site: z.string(),
        wpVersion: z.string().nullable(),
        phpVersion: z.string().nullable(),
        activeTheme: z.string().nullable(),
        plugins: z.array(pluginSchema),
        siteUrl: z.string().nullable(),
      },
    },
    async ({ site }) => {
      try {
        return successResult(await handlers.getSiteInfo(site));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "local_wp_run",
    {
      description:
        "Run a restricted allowlisted WP-CLI command through bin/local-wp. Explicit site is always required.",
      inputSchema: {
        site: z.string().min(1).describe("Local site name"),
        command: z.string().min(1).describe("WP-CLI command/subcommand words, for example 'plugin list' or 'db query'"),
        args: z.array(z.string()).optional().describe("Structured command arguments passed without shell interpolation"),
      },
      outputSchema: {
        site: z.string(),
        command: z.string(),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async ({ site, command, args }) => {
      try {
        return successResult(await handlers.runCommand(site, command, args ?? []));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  return server;
}

export async function main(): Promise<void> {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("AI-DDTK MCP Server running on stdio");
}

const entryPath = process.argv[1] ? path.resolve(process.argv[1]) : "";

if (entryPath && fileURLToPath(import.meta.url) === entryPath) {
  main().catch((error) => {
    console.error("Fatal MCP server error:", error);
    process.exit(1);
  });
}