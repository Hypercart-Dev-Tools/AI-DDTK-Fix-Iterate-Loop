#!/usr/bin/env node

import path from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import * as z from "zod/v4";
import { createLocalWpHandlers } from "./handlers/local-wp.js";
import { AUTH_STATUS_URI_TEMPLATE, createPwAuthHandlers } from "./handlers/pw-auth.js";
import { WPCC_LATEST_REPORT_URI, WPCC_LATEST_SCAN_URI, WPCC_SCAN_URI_TEMPLATE, createWpccHandlers } from "./handlers/wpcc.js";
import { SiteState } from "./state.js";

const MCP_SERVER_VERSION = "0.4.1";

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

const wpccFeatureSectionSchema = z.object({
  title: z.string(),
  lines: z.array(z.string()),
});

const authStatusEntrySchema = z.object({
  user: z.string(),
  exists: z.boolean(),
  lastUpdated: z.string().nullable(),
  age: z.string().nullable(),
  ageHours: z.number().nullable(),
  fresh: z.boolean(),
  validationStatus: z.enum(["fresh", "stale", "missing"]),
  filePath: z.string().nullable(),
  sizeBytes: z.number().nullable(),
});

// This entrypoint is expected to run either from tools/mcp-server/src/ during local
// TypeScript execution/tests or from tools/mcp-server/dist/src/ after build. The
// repoRoot calculation in createServer() depends on that fixed package layout.
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

async function withResourceError<T>(callback: () => Promise<T>): Promise<T> {
  try {
    return await callback();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(message);
  }
}

function getWpccScanId(uri: URL): string {
  const match = uri.href.match(/^wpcc:\/\/scan\/(.+)$/);
  const scanId = match?.[1];

  if (!scanId) {
    throw new Error(`Invalid WPCC scan resource URI: ${uri.href}`);
  }

  return scanId;
}

function getAuthStatusUser(uri: URL): string {
  const match = uri.href.match(/^auth:\/\/status\/(.+)$/);
  const user = match?.[1];

  if (!user) {
    throw new Error(`Invalid auth status resource URI: ${uri.href}`);
  }

  return decodeURIComponent(user);
}

export function createServer() {
  const packageRoot = getPackageRoot(import.meta.url);
  const repoRoot = path.resolve(packageRoot, "../..");
  const state = new SiteState();
  const localWpHandlers = createLocalWpHandlers({ state, repoRoot });
  const pwAuthHandlers = createPwAuthHandlers({ repoRoot });
  const wpccHandlers = createWpccHandlers({ repoRoot });

  const server = new McpServer({
    name: "ai-ddtk-mcp",
    version: MCP_SERVER_VERSION,
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
    async () => successResult(await localWpHandlers.listSites()),
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
        return successResult(await localWpHandlers.selectSite(site));
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
    async () => successResult(await localWpHandlers.getActiveSite()),
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
        return successResult(await localWpHandlers.testConnectivity(site));
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
        return successResult(await localWpHandlers.getSiteInfo(site));
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
        return successResult(await localWpHandlers.runCommand(site, command, args ?? []));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "pw_auth_login",
    {
      description:
        "Authenticate Playwright against WordPress admin using bin/pw-auth with structured Local site input and metadata-only output.",
      inputSchema: {
        siteUrl: z.string().url().describe("Full WordPress site URL, for example http://my-site.local"),
        site: z.string().min(1).describe("Local site name used to construct the internal local-wp command prefix"),
        user: z.string().min(1).default("admin").describe("WordPress username/login to authenticate"),
        redirect: z.string().min(1).optional().describe("Optional wp-admin-relative redirect path after login"),
        force: z.boolean().default(false).describe("Force re-auth even if cached auth is still fresh"),
      },
      outputSchema: {
        site: z.string(),
        user: z.string(),
        siteUrl: z.string(),
        authFile: z.string(),
        cacheFreshUntil: z.string().nullable().describe("Best-effort cache freshness window derived from the auth file mtime, not the actual WordPress session expiry."),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
        retried: z.boolean(),
      },
    },
    async ({ siteUrl, site, user, redirect, force }) => {
      try {
        return successResult(await pwAuthHandlers.login(siteUrl, site, user ?? "admin", redirect, force ?? false));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "pw_auth_status",
    {
      description: "Return Playwright auth cache metadata from bin/pw-auth status without exposing raw storageState contents. Use users[] as the authoritative structured data; rawText/stdout are informational passthrough only.",
      outputSchema: {
        authDir: z.string(),
        users: z.array(authStatusEntrySchema).describe("Authoritative structured auth metadata derived from the auth directory."),
        rawText: z.string().describe("Informational plain-text passthrough from bin/pw-auth status; do not rely on this for program logic."),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async () => {
      try {
        return successResult(await pwAuthHandlers.status());
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "pw_auth_clear",
    {
      description: "Clear cached Playwright auth for one explicit user only. Does not expose pw-auth clear-all semantics over MCP.",
      inputSchema: {
        user: z.string().min(1).describe("Explicit WordPress username/login whose cached auth file should be deleted"),
      },
      outputSchema: {
        user: z.string(),
        filePath: z.string(),
        existed: z.boolean(),
        cleared: z.boolean(),
      },
    },
    async ({ user }) => {
      try {
        return successResult(await pwAuthHandlers.clear(user));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "wpcc_list_features",
    {
      description: "List WP Code Check capabilities and workflows from the bin/wpcc wrapper.",
      outputSchema: {
        rawText: z.string(),
        sections: z.array(wpccFeatureSectionSchema),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async () => {
      try {
        return successResult(await wpccHandlers.listFeatures());
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "wpcc_run_scan",
    {
      description:
        "Run bin/wpcc against the requested path. JSON mode reads the authoritative dist/logs JSON file instead of trusting mixed stdout.",
      inputSchema: {
        paths: z.string().min(1).describe("Path or paths string to pass to --paths"),
        format: z.enum(["json", "text"]).default("json"),
        verbose: z.boolean().default(false),
      },
      outputSchema: {
        paths: z.string(),
        format: z.enum(["json", "text"]),
        verbose: z.boolean(),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
        logPath: z.string().nullable(),
        reportPath: z.string().nullable(),
        scan: z.record(z.string(), z.unknown()).nullable(),
      },
    },
    async ({ paths, format, verbose }) => {
      try {
        return successResult(await wpccHandlers.runScan(paths, format, verbose));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerResource(
    "auth_status_by_user",
    new ResourceTemplate(AUTH_STATUS_URI_TEMPLATE, {
      list: async () =>
        withResourceError(async () => ({
          resources: await pwAuthHandlers.listStatusResources(),
        })),
    }),
    {
      description: "Metadata-only Playwright auth status by user. Never exposes raw storageState, cookies, or tokens, and avoids synthesizing missing-user file paths.",
      mimeType: "application/json",
    },
    async (uri) => withResourceError(() => pwAuthHandlers.readStatusResource(getAuthStatusUser(uri))),
  );

  server.registerResource(
    "wpcc_latest_scan",
    WPCC_LATEST_SCAN_URI,
    {
      description: "Most recent WP Code Check JSON scan artifact.",
      mimeType: "application/json",
    },
    async () => withResourceError(() => wpccHandlers.readLatestScanResource()),
  );

  server.registerResource(
    "wpcc_latest_report",
    WPCC_LATEST_REPORT_URI,
    {
      description: "Most recent WP Code Check HTML report artifact.",
      mimeType: "text/html",
    },
    async () => withResourceError(() => wpccHandlers.readLatestReportResource()),
  );

  server.registerResource(
    "wpcc_scan_by_id",
    new ResourceTemplate(WPCC_SCAN_URI_TEMPLATE, {
      list: async () =>
        withResourceError(async () => ({
          resources: await wpccHandlers.listScanResources(),
        })),
    }),
    {
      description: "Specific WP Code Check JSON scan artifact by timestamp id.",
      mimeType: "application/json",
    },
    async (uri) => withResourceError(() => wpccHandlers.readScanResource(getWpccScanId(uri))),
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