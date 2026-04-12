import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";
import type { createEnvProbesHandlers } from "../handlers/env-probes.js";
import { errorResult, successResult } from "./shared.js";

type EnvProbesHandlers = ReturnType<typeof createEnvProbesHandlers>;

const monitorIssueSchema = z.object({
  severity: z.string(),
  key: z.string(),
  message: z.string(),
});

const monitorCountsSchema = z.object({
  critical: z.number(),
  high: z.number(),
  medium: z.number(),
  low: z.number(),
  fyi: z.number(),
  total: z.number(),
});

const port80ListenerSchema = z.object({
  command: z.string(),
  pid: z.string(),
  address: z.string(),
});

const valetProxySchema = z.object({
  site: z.string(),
  ssl: z.boolean(),
  url: z.string(),
  host: z.string(),
});

export function registerEnvProbeTools(server: McpServer, handlers: EnvProbesHandlers): void {
  server.registerTool(
    "servers_monitor_check",
    {
      description:
        "Run experimental/servers-monitor.sh --json to detect live port conflicts, stale /etc/hosts entries, missing services, and wildcard port 80 binds on the local machine. Read-only (no email sent, no baseline modified). Returns structured issue list grouped by severity. Safe to call at session start as a preflight check. Gracefully returns status='not_installed' or 'not_configured' if the monitor isn't set up.",
      outputSchema: {
        status: z.enum(["ok", "issues", "not_configured", "not_installed", "error"]),
        message: z.string().optional(),
        scriptPath: z.string().optional(),
        timestamp: z.string().optional(),
        device: z.string().optional(),
        counts: monitorCountsSchema.optional(),
        issues: z.array(monitorIssueSchema).optional(),
      },
    },
    async () => {
      try {
        return successResult(await handlers.monitorCheck());
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "dev_context_status",
    {
      description:
        "Run experimental/dev-context.sh status --json to report the current development mode (valet | localwp | conflict | none), which local services are running (Valet nginx, dnsmasq, Local WP router, Docker Dify), and who owns port 80. Use this when diagnosing site reachability issues or before suggesting a context switch. Gracefully returns mode='not_installed' if the script is missing.",
      outputSchema: {
        mode: z.enum(["valet", "localwp", "conflict", "none", "not_installed"]),
        message: z.string().optional(),
        scriptPath: z.string().optional(),
        services: z
          .object({
            valet_nginx: z.boolean(),
            dnsmasq: z.boolean(),
            localwp_router: z.boolean(),
            dify_docker: z.boolean(),
          })
          .optional(),
        port80Listeners: z.array(port80ListenerSchema).optional(),
        valetProxies: z.array(valetProxySchema).optional(),
      },
    },
    async () => {
      try {
        return successResult(await handlers.devContextStatus());
      } catch (error) {
        return errorResult(error);
      }
    },
  );
}
