import { ResourceTemplate, type McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";
import {
  WPCC_LATEST_REPORT_URI,
  WPCC_LATEST_SCAN_URI,
  WPCC_SCAN_URI_TEMPLATE,
  type createWpccHandlers,
} from "../handlers/wpcc.js";
import { errorResult, successResult } from "./shared.js";

type WpccHandlers = ReturnType<typeof createWpccHandlers>;

const wpccFeatureSectionSchema = z.object({
  title: z.string(),
  lines: z.array(z.string()),
});

function getWpccScanId(uri: URL): string {
  const match = uri.href.match(/^wpcc:\/\/scan\/(.+)$/);
  const scanId = match?.[1];

  if (!scanId) {
    throw new Error(`Invalid WPCC scan resource URI: ${uri.href}`);
  }

  return scanId;
}

export function registerWpccTools(server: McpServer, handlers: WpccHandlers): void {
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
        return successResult(await handlers.listFeatures());
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
        return successResult(await handlers.runScan(paths, format, verbose));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerResource(
    "wpcc_latest_scan",
    WPCC_LATEST_SCAN_URI,
    {
      description: "Most recent WP Code Check JSON scan artifact.",
      mimeType: "application/json",
    },
    async () => handlers.readLatestScanResource(),
  );

  server.registerResource(
    "wpcc_latest_report",
    WPCC_LATEST_REPORT_URI,
    {
      description: "Most recent WP Code Check HTML report artifact.",
      mimeType: "text/html",
    },
    async () => handlers.readLatestReportResource(),
  );

  server.registerResource(
    "wpcc_scan_by_id",
    new ResourceTemplate(WPCC_SCAN_URI_TEMPLATE, {
      list: async () => ({
        resources: await handlers.listScanResources(),
      }),
    }),
    {
      description: "Specific WP Code Check JSON scan artifact by timestamp id.",
      mimeType: "application/json",
    },
    async (uri) => handlers.readScanResource(getWpccScanId(uri)),
  );
}
