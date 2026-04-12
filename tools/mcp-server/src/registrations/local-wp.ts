import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";
import type { createLocalWpHandlers } from "../handlers/local-wp.js";
import { errorResult, successResult } from "./shared.js";

type LocalWpHandlers = ReturnType<typeof createLocalWpHandlers>;

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

export function registerLocalWpTools(server: McpServer, handlers: LocalWpHandlers): void {
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
}
