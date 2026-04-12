import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";
import type { createWpAjaxTestHandlers } from "../handlers/wp-ajax-test.js";
import { errorResult, successResult } from "./shared.js";

type WpAjaxTestHandlers = ReturnType<typeof createWpAjaxTestHandlers>;

export function registerWpAjaxTestTools(server: McpServer, handlers: WpAjaxTestHandlers): void {
  server.registerTool(
    "wp_ajax_test",
    {
      description: "Test a WordPress AJAX endpoint through bin/wp-ajax-test using explicit URL/action input and structured JSON results.",
      inputSchema: {
        url: z.string().url().refine((value) => /^https?:\/\//i.test(value), "Only http:// and https:// URLs are allowed").describe("Full WordPress site URL, for example http://my-site.local"),
        action: z.string().min(1).describe("AJAX action name"),
        data: z.record(z.string(), z.unknown()).default({}).describe("JSON object payload passed to --data"),
        authState: z.string().min(1).optional().describe("Playwright auth state file from pw-auth (preferred — no plaintext passwords)"),
        auth: z.string().min(1).optional().describe("Legacy auth JSON file with username/password (prefer authState)"),
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
    async ({ url, action, data, authState, auth, method, nopriv, insecure }) => {
      try {
        return successResult(await handlers.runTest(url, action, data ?? {}, auth, method ?? "POST", nopriv ?? false, insecure ?? false, authState));
      } catch (error) {
        return errorResult(error);
      }
    },
  );
}
