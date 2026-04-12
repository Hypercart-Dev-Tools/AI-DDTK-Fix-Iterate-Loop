import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";
import type { createQmHandlers } from "../handlers/qm.js";
import { errorResult, successResult } from "./shared.js";

type QmHandlers = ReturnType<typeof createQmHandlers>;

const qmQuerySchema = z.object({
  i: z.number(),
  sql: z.string(),
  time: z.number(),
  time_ms: z.number().optional(),
  stack: z.array(z.string()),
  result: z.union([z.number(), z.string()]),
});

const duplicateQuerySchema = z.object({
  sql: z.string(),
  count: z.number(),
  query_indices: z.array(z.number()),
});

export function registerQmTools(server: McpServer, handlers: QmHandlers): void {
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
        return successResult(await handlers.profilePage(siteUrl, pagePath, method, body, headers, user));
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
        return successResult(await handlers.slowQueries(siteUrl, pagePath, threshold_ms, method, body, user));
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
        duplicates: z.array(duplicateQuerySchema),
      },
    },
    async ({ siteUrl, path: pagePath, method, body, user }) => {
      try {
        return successResult(await handlers.duplicateQueries(siteUrl, pagePath, method, body, user));
      } catch (error) {
        return errorResult(error);
      }
    },
  );
}
