#!/usr/bin/env node

import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createEnvProbesHandlers } from "./handlers/env-probes.js";
import { createLocalWpHandlers } from "./handlers/local-wp.js";
import { createPostFlightHandlers } from "./handlers/post-flight.js";
import { createPwAuthHandlers } from "./handlers/pw-auth.js";
import { createQmHandlers } from "./handlers/qm.js";
import { createServersHandlers } from "./handlers/servers.js";
import { createTmuxHandlers } from "./handlers/tmux.js";
import { createWpAjaxTestHandlers } from "./handlers/wp-ajax-test.js";
import { createWpccHandlers } from "./handlers/wpcc.js";
import { registerEnvProbeTools } from "./registrations/env-probes.js";
import { registerLocalWpTools } from "./registrations/local-wp.js";
import { registerPostFlightTools } from "./registrations/post-flight.js";
import { registerPrompts } from "./registrations/prompts.js";
import { registerPwAuthTools } from "./registrations/pw-auth.js";
import { registerQmTools } from "./registrations/qm.js";
import { registerServersTools } from "./registrations/servers.js";
import { registerTmuxTools } from "./registrations/tmux.js";
import { registerWpAjaxTestTools } from "./registrations/wp-ajax-test.js";
import { registerWpccTools } from "./registrations/wpcc.js";
import { SessionStore, SiteState } from "./state.js";
import { getTokenFilePath, loadOrGenerateToken } from "./utils/token.js";

const MCP_SERVER_VERSION = "0.11.1";
const DEFAULT_HTTP_PORT = 3100;
const MCP_HTTP_PATH = "/mcp";
const MAX_REQUEST_BODY_BYTES = 1024 * 1024; // 1 MB

// This entrypoint is expected to run either from tools/mcp-server/src/ during local
// TypeScript execution/tests or from tools/mcp-server/dist/src/ after build. The
// repoRoot calculation in createServer() depends on that fixed package layout.
function getPackageRoot(moduleUrl: string): string {
  const currentDir = path.dirname(fileURLToPath(moduleUrl));
  const parentDir = path.dirname(currentDir);

  return path.basename(parentDir) === "dist" ? path.resolve(currentDir, "../..") : path.resolve(currentDir, "..");
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
  const qmHandlers = createQmHandlers({
    getCookiesForSite: (user, domain) => pwAuthHandlers.getCookiesForSite(user, domain),
    repoRoot,
  });
  const postFlightHandlers = createPostFlightHandlers({ repoRoot });
  const serversHandlers = createServersHandlers({ repoRoot });
  const envProbesHandlers = createEnvProbesHandlers({ repoRoot });

  const server = new McpServer({
    name: "ai-ddtk-mcp",
    version: MCP_SERVER_VERSION,
  });

  registerLocalWpTools(server, localWpHandlers);
  registerPwAuthTools(server, pwAuthHandlers);
  registerWpAjaxTestTools(server, wpAjaxTestHandlers);
  registerTmuxTools(server, tmuxHandlers);
  registerWpccTools(server, wpccHandlers);
  registerQmTools(server, qmHandlers);
  registerPostFlightTools(server, postFlightHandlers);
  registerServersTools(server, serversHandlers);
  registerEnvProbeTools(server, envProbesHandlers);
  registerPrompts(server);

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

    // Reject oversized request bodies before processing.
    const contentLength = parseInt(req.headers["content-length"] ?? "0", 10);

    if (contentLength > MAX_REQUEST_BODY_BYTES) {
      res.writeHead(413, { "Content-Type": "text/plain" });
      res.end("Payload Too Large\n");
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
