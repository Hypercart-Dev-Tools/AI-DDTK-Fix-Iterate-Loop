#!/usr/bin/env node

import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import * as z from "zod/v4";
import { createLocalWpHandlers } from "./handlers/local-wp.js";
import { AUTH_STATUS_URI_TEMPLATE, createPwAuthHandlers } from "./handlers/pw-auth.js";
import { createTmuxHandlers } from "./handlers/tmux.js";
import { createWpAjaxTestHandlers } from "./handlers/wp-ajax-test.js";
import { createQmHandlers } from "./handlers/qm.js";
import { WPCC_LATEST_REPORT_URI, WPCC_LATEST_SCAN_URI, WPCC_SCAN_URI_TEMPLATE, createWpccHandlers } from "./handlers/wpcc.js";
import { SessionStore, SiteState } from "./state.js";
import { loadOrGenerateToken, getTokenFilePath } from "./utils/token.js";

const MCP_SERVER_VERSION = "0.6.3";
const DEFAULT_HTTP_PORT = 3100;
const MCP_HTTP_PATH = "/mcp";

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

const tmuxSessionSummarySchema = z.object({
  session: z.string(),
  windows: z.number(),
  attached: z.boolean(),
  state: z.enum(["attached", "detached"]),
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
  const tmuxHandlers = createTmuxHandlers({ repoRoot });
  const wpAjaxTestHandlers = createWpAjaxTestHandlers({ repoRoot });
  const wpccHandlers = createWpccHandlers({ repoRoot });
  const qmHandlers = createQmHandlers({ getCookiesForSite: (user, domain) => pwAuthHandlers.getCookiesForSite(user, domain), repoRoot });

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
    "wp_ajax_test",
    {
      description: "Test a WordPress AJAX endpoint through bin/wp-ajax-test using explicit URL/action input and structured JSON results.",
      inputSchema: {
        url: z.string().url().refine((value) => /^https?:\/\//i.test(value), "Only http:// and https:// URLs are allowed").describe("Full WordPress site URL, for example http://my-site.local"),
        action: z.string().min(1).describe("AJAX action name"),
        data: z.record(z.string(), z.unknown()).default({}).describe("JSON object payload passed to --data"),
        auth: z.string().min(1).optional().describe("Optional auth JSON file path for authenticated AJAX requests"),
        method: z.enum(["GET", "POST"]).default("POST"),
        nopriv: z.boolean().default(false).describe("Use the nopriv AJAX endpoint"),
        insecure: z.boolean().default(false).describe("Skip SSL certificate verification for local/self-signed dev environments"),
      },
      outputSchema: {
        url: z.string(),
        action: z.string(),
        method: z.enum(["GET", "POST"]),
        nopriv: z.boolean(),
        insecure: z.boolean(),
        authProvided: z.boolean(),
        success: z.boolean(),
        statusCode: z.number().nullable(),
        responseTimeMs: z.number().nullable(),
        response: z.unknown().nullable(),
        headers: z.record(z.string(), z.unknown()).nullable(),
        error: z.object({ code: z.string(), message: z.string() }).nullable(),
        suggestions: z.array(z.string()).nullable(),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async ({ url, action, data, auth, method, nopriv, insecure }) => {
      try {
        return successResult(await wpAjaxTestHandlers.runTest(url, action, data ?? {}, auth, method ?? "POST", nopriv ?? false, insecure ?? false));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "tmux_start",
    {
      description: "Start or reuse an AI-DDTK tmux workspace session with an optional cwd and session name.",
      inputSchema: {
        cwd: z.string().min(1).optional().describe("Optional working directory to start the session in; defaults to the MCP process cwd"),
        session: z.string().min(1).optional().describe("Optional tmux session name; normalized to the aiddtk-* convention"),
      },
      outputSchema: {
        session: z.string(),
        cwd: z.string(),
        logFile: z.string().nullable(),
        reused: z.boolean(),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async ({ cwd, session }) => {
      try {
        return successResult(await tmuxHandlers.start(cwd, session));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "tmux_send",
    {
      description: "Send one allowlisted command into an AI-DDTK tmux session. Rejects arbitrary shell execution and shell control operators.",
      inputSchema: {
        command: z.string().min(1).describe("Allowlisted command to send, for example 'wpcc --features' or 'tail temp/mcp-server.log'"),
        session: z.string().min(1).optional().describe("Optional tmux session name; normalized to the aiddtk-* convention"),
      },
      outputSchema: {
        session: z.string(),
        command: z.string(),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async ({ command, session }) => {
      try {
        return successResult(await tmuxHandlers.send(command, session));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "tmux_capture",
    {
      description: "Capture recent output from an AI-DDTK tmux session.",
      inputSchema: {
        tail: z.number().int().min(1).max(5000).default(200).describe("Number of trailing pane lines to capture"),
        session: z.string().min(1).optional().describe("Optional tmux session name; normalized to the aiddtk-* convention"),
      },
      outputSchema: {
        session: z.string(),
        tail: z.number(),
        output: z.string(),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async ({ tail, session }) => {
      try {
        return successResult(await tmuxHandlers.capture(tail ?? 200, session));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "tmux_stop",
    {
      description: "Stop an AI-DDTK tmux session.",
      inputSchema: {
        session: z.string().min(1).optional().describe("Optional tmux session name; normalized to the aiddtk-* convention"),
      },
      outputSchema: {
        session: z.string(),
        stopped: z.boolean(),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async ({ session }) => {
      try {
        return successResult(await tmuxHandlers.stop(session));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "tmux_list",
    {
      description: "List AI-DDTK tmux sessions.",
      outputSchema: {
        sessions: z.array(tmuxSessionSummarySchema),
        rawText: z.string(),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async () => {
      try {
        return successResult(await tmuxHandlers.list());
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "tmux_status",
    {
      description: "Show status for one AI-DDTK tmux session.",
      inputSchema: {
        session: z.string().min(1).optional().describe("Optional tmux session name; normalized to the aiddtk-* convention"),
      },
      outputSchema: {
        session: z.string(),
        exists: z.boolean(),
        path: z.string().nullable(),
        windows: z.number().nullable(),
        logFile: z.string().nullable(),
        tmuxVersion: z.string().nullable(),
        rawText: z.string(),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async ({ session }) => {
      try {
        return successResult(await tmuxHandlers.status(session));
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

  const qmQuerySchema = z.object({
    i: z.number(),
    sql: z.string(),
    time: z.number(),
    time_ms: z.number().optional(),
    stack: z.array(z.string()),
    result: z.union([z.number(), z.string()]),
  });

  server.registerTool(
    "qm_profile_page",
    {
      description:
        "Profile any WordPress page (frontend, admin, checkout) with Query Monitor. Returns db queries, cache stats, HTTP API calls, and timing data. Requires the ai-ddtk-qm-bridge mu-plugin and Query Monitor plugin on the target site.",
      inputSchema: {
        siteUrl: z.string().url().describe("Full WordPress site URL, e.g. https://myfriendcom-09-30.local"),
        path: z.string().min(1).describe("Page path to profile, e.g. /checkout/, /wp-admin/edit.php"),
        method: z.enum(["GET", "POST"]).default("GET"),
        body: z.record(z.string(), z.unknown()).optional().describe("Request body for POST requests"),
        headers: z.record(z.string(), z.string()).optional().describe("Additional request headers"),
        user: z.string().min(1).default("admin").describe("WordPress user whose pw-auth cookies to use"),
      },
      outputSchema: {
        site: z.string(),
        path: z.string(),
        method: z.string(),
        statusCode: z.number(),
        overview: z.record(z.string(), z.unknown()).nullable(),
        db_queries: z.record(z.string(), z.unknown()),
        cache: z.record(z.string(), z.unknown()),
        http: z.unknown(),
        logger: z.unknown(),
        transients: z.unknown(),
        conditionals: z.unknown(),
      },
    },
    async ({ siteUrl, path: pagePath, method, body, headers, user }) => {
      try {
        return successResult(await qmHandlers.profilePage(siteUrl, pagePath, method, body, headers, user));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "qm_slow_queries",
    {
      description:
        "Profile a WordPress page and return only database queries slower than the threshold. Useful for finding performance bottlenecks.",
      inputSchema: {
        siteUrl: z.string().url().describe("Full WordPress site URL"),
        path: z.string().min(1).describe("Page path to profile"),
        threshold_ms: z.number().min(0).default(50).describe("Minimum query time in milliseconds to include"),
        method: z.enum(["GET", "POST"]).default("GET"),
        body: z.record(z.string(), z.unknown()).optional(),
        user: z.string().min(1).default("admin"),
      },
      outputSchema: {
        site: z.string(),
        path: z.string(),
        total_queries: z.number(),
        total_time: z.number(),
        threshold_ms: z.number(),
        slow_queries: z.array(qmQuerySchema),
      },
    },
    async ({ siteUrl, path: pagePath, threshold_ms, method, body, user }) => {
      try {
        return successResult(await qmHandlers.slowQueries(siteUrl, pagePath, threshold_ms, method, body, user));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "qm_duplicate_queries",
    {
      description:
        "Profile a WordPress page and return duplicate database queries (N+1 detection). Identifies queries that run multiple times with the same SQL.",
      inputSchema: {
        siteUrl: z.string().url().describe("Full WordPress site URL"),
        path: z.string().min(1).describe("Page path to profile"),
        method: z.enum(["GET", "POST"]).default("GET"),
        body: z.record(z.string(), z.unknown()).optional(),
        user: z.string().min(1).default("admin"),
      },
      outputSchema: {
        site: z.string(),
        path: z.string(),
        total_duplicates: z.number(),
        duplicates: z.array(z.object({
          sql: z.string(),
          count: z.number(),
          query_indices: z.array(z.number()),
        })),
      },
    },
    async ({ siteUrl, path: pagePath, method, body, user }) => {
      try {
        return successResult(await qmHandlers.duplicateQueries(siteUrl, pagePath, method, body, user));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  return server;
}

export async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const httpFlag = args.includes("--http");
  const portArg = args.find((a) => a.startsWith("--port="));
  const port = portArg ? Number.parseInt(portArg.split("=")[1] ?? "", 10) || DEFAULT_HTTP_PORT : DEFAULT_HTTP_PORT;

  if (httpFlag) {
    await startHttpTransport(port);
  } else {
    const server = createServer();
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("AI-DDTK MCP Server running on stdio");
  }
}

export interface HttpTransportOptions {
  port: number;
  token: string;
}

/**
 * Create the HTTP request handler with bearer token auth, localhost enforcement,
 * and per-session MCP server isolation via SessionStore.
 * Exported for testing — `startHttpTransport` wraps this in a listening server.
 */
export function createHttpHandler(options: HttpTransportOptions) {
  const { port, token } = options;
  const sessionStore = new SessionStore();
  const transports = new Map<string, { transport: StreamableHTTPServerTransport; server: McpServer }>();

  const handler = async (req: http.IncomingMessage, res: http.ServerResponse) => {
    // Enforce localhost-only at the request level (belt-and-suspenders with bind).
    const remoteAddr = req.socket.remoteAddress;

    if (remoteAddr && !["127.0.0.1", "::1", "::ffff:127.0.0.1"].includes(remoteAddr)) {
      res.writeHead(403, { "Content-Type": "text/plain" });
      res.end("Forbidden: localhost only\n");
      return;
    }

    // Bearer token auth — required on every request.
    const authHeader = req.headers.authorization ?? "";

    if (authHeader !== `Bearer ${token}`) {
      res.writeHead(401, { "Content-Type": "text/plain" });
      res.end("Unauthorized: invalid or missing bearer token\n");
      return;
    }

    const url = new URL(req.url ?? "/", `http://localhost:${port}`);

    if (url.pathname !== MCP_HTTP_PATH) {
      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end("Not Found\n");
      return;
    }

    // Route by session ID header.
    const sessionId = req.headers["mcp-session-id"] as string | undefined;

    if (sessionId && transports.has(sessionId)) {
      // Existing session — delegate to its transport.
      const session = transports.get(sessionId)!;
      await session.transport.handleRequest(req, res);
      return;
    }

    if (req.method === "POST" && !sessionId) {
      // New session initialization — create a fresh transport + server pair.
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => crypto.randomUUID(),
      });
      const server = createServer();
      await server.connect(transport);

      // handleRequest triggers session ID generation for the initialize request.
      await transport.handleRequest(req, res);

      // Register the session after handleRequest so the session ID is available.
      const newSessionId = transport.sessionId;

      if (newSessionId) {
        sessionStore.getOrCreate(newSessionId);
        transports.set(newSessionId, { transport, server });

        transport.onclose = () => {
          transports.delete(newSessionId);
          sessionStore.remove(newSessionId);
        };
      }

      return;
    }

    // Invalid request (e.g. GET without session, or unknown session).
    res.writeHead(400, { "Content-Type": "text/plain" });
    res.end("Bad Request: missing or invalid session\n");
  };

  return { handler, sessionStore, transports };
}

async function startHttpTransport(port: number): Promise<void> {
  const token = await loadOrGenerateToken();
  const { handler } = createHttpHandler({ port, token });
  const httpServer = http.createServer(handler);

  // Bind exclusively to localhost — never 0.0.0.0.
  httpServer.listen(port, "127.0.0.1", () => {
    console.error(`AI-DDTK MCP Server running on http://127.0.0.1:${port}${MCP_HTTP_PATH}`);
    console.error(`Bearer token file: ${getTokenFilePath()}`);
  });
}

const entryPath = process.argv[1] ? path.resolve(process.argv[1]) : "";

if (entryPath && fileURLToPath(import.meta.url) === entryPath) {
  main().catch((error) => {
    console.error("Fatal MCP server error:", error);
    process.exit(1);
  });
}