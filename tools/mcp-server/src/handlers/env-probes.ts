/**
 * env-probes.ts — Live environment probes for the local dev machine.
 *
 * Unlike handlers/servers.ts (which reads/writes the static registry in
 * tools/servers.md), this module shells out to experimental scripts that
 * inspect the running machine state: port 80 ownership, port conflicts,
 * service health, etc.
 *
 * Each probe gracefully degrades when its backing script is missing or
 * unconfigured — safe to ship in the public MCP server without breaking
 * machines that haven't set up the monitoring stack.
 */

import { access, constants } from "node:fs/promises";
import path from "node:path";
import { homedir } from "node:os";
import * as z from "zod/v4";
import { execFileText, ExecFileTextError, type ExecFileText } from "../utils/exec.js";
import { parseJsonWithSchema } from "../utils/json-schema.js";

// --- Types ---

export type MonitorStatus = "ok" | "issues" | "not_configured" | "not_installed" | "error";

export interface MonitorIssue {
  severity: "CRITICAL" | "HIGH" | "MEDIUM" | "LOW" | "FYI" | string;
  key: string;
  message: string;
}

export interface MonitorCounts {
  critical: number;
  high: number;
  medium: number;
  low: number;
  fyi: number;
  total: number;
}

export type ServersMonitorCheckResult = Record<string, unknown> & {
  status: MonitorStatus;
  message?: string;
  scriptPath?: string;
  timestamp?: string;
  device?: string;
  counts?: MonitorCounts;
  issues?: MonitorIssue[];
};

export type DevContextMode = "valet" | "localwp" | "conflict" | "none" | "not_installed";

export interface DevContextServices {
  valet_nginx: boolean;
  dnsmasq: boolean;
  localwp_router: boolean;
  dify_docker: boolean;
}

export interface Port80Listener {
  command: string;
  pid: string;
  address: string;
}

export interface ValetProxy {
  site: string;
  ssl: boolean;
  url: string;
  host: string;
}

export type DevContextStatusResult = Record<string, unknown> & {
  mode: DevContextMode;
  message?: string;
  scriptPath?: string;
  services?: DevContextServices;
  port80Listeners?: Port80Listener[];
  valetProxies?: ValetProxy[];
};

// --- Deps ---

export interface EnvProbesDeps {
  repoRoot: string;
  /** Override for the servers-monitor.sh path. Defaults to `<repo>/experimental/servers-monitor.sh`. */
  monitorScriptPath?: string;
  /** Override for the dev-context.sh path. Defaults to `<repo>/experimental/dev-context.sh`. */
  devContextScriptPath?: string;
  /** Exec implementation (injectable for tests). */
  exec?: ExecFileText;
}

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

const serversMonitorCheckSchema = z.object({
  status: z.enum(["ok", "issues", "not_configured", "not_installed", "error"]),
  message: z.string().optional(),
  timestamp: z.string().optional(),
  device: z.string().optional(),
  counts: monitorCountsSchema.optional(),
  issues: z.array(monitorIssueSchema).optional(),
}).passthrough();

const devContextStatusSchema = z.object({
  mode: z.enum(["valet", "localwp", "conflict", "none", "not_installed"]),
  message: z.string().optional(),
  services: z.object({
    valet_nginx: z.boolean(),
    dnsmasq: z.boolean(),
    localwp_router: z.boolean(),
    dify_docker: z.boolean(),
  }).optional(),
  port80Listeners: z.array(z.object({
    command: z.string(),
    pid: z.string(),
    address: z.string(),
  })).optional(),
  valetProxies: z.array(z.object({
    site: z.string(),
    ssl: z.boolean(),
    url: z.string(),
    host: z.string(),
  })).optional(),
}).passthrough();

function resolvePath(repoRoot: string, override: string | undefined, defaultRelative: string): string {
  if (override) {
    return override.startsWith("~")
      ? path.join(homedir(), override.slice(1).replace(/^\/+/, ""))
      : override;
  }
  return path.join(repoRoot, defaultRelative);
}

async function fileExecutable(filePath: string): Promise<boolean> {
  try {
    await access(filePath, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

// --- Handlers ---

export function createEnvProbesHandlers(deps: EnvProbesDeps) {
  const { repoRoot } = deps;
  const exec = deps.exec ?? execFileText;
  const monitorScriptPath = resolvePath(repoRoot, deps.monitorScriptPath, "experimental/servers-monitor.sh");
  const devContextScriptPath = resolvePath(repoRoot, deps.devContextScriptPath, "experimental/dev-context.sh");

  /**
   * Run servers-monitor.sh --json and return the parsed result.
   * Gracefully returns `not_installed` if the script is missing or
   * `not_configured` if the user's config file (~/secrets/servers-monitor.conf)
   * doesn't exist. Never throws for expected "not set up" states.
   */
  async function monitorCheck(): Promise<ServersMonitorCheckResult> {
    if (!(await fileExecutable(monitorScriptPath))) {
      return {
        status: "not_installed",
        message: `servers-monitor.sh not found or not executable at ${monitorScriptPath}. See experimental/servers-monitor.conf.example to set up.`,
        scriptPath: monitorScriptPath,
      };
    }

    try {
      const { stdout } = await exec(monitorScriptPath, ["--json"], { timeoutMs: 30_000 });
      const parsed = parseJsonWithSchema(stdout, serversMonitorCheckSchema, "servers-monitor.sh");
      return { ...parsed, scriptPath: monitorScriptPath };
    } catch (error) {
      if (error instanceof ExecFileTextError) {
        return {
          status: "error",
          message: `servers-monitor.sh failed (exit ${error.exitCode}): ${error.stderr.trim() || error.message}`,
          scriptPath: monitorScriptPath,
        };
      }
      if (error instanceof SyntaxError) {
        return {
          status: "error",
          message: `servers-monitor.sh emitted invalid JSON: ${error.message}`,
          scriptPath: monitorScriptPath,
        };
      }
      if (error instanceof Error) {
        return {
          status: "error",
          message: error.message,
          scriptPath: monitorScriptPath,
        };
      }
      throw error;
    }
  }

  /**
   * Run dev-context.sh status --json and return the parsed result.
   * Gracefully returns `not_installed` if the script is missing.
   */
  async function devContextStatus(): Promise<DevContextStatusResult> {
    if (!(await fileExecutable(devContextScriptPath))) {
      return {
        mode: "not_installed",
        message: `dev-context.sh not found or not executable at ${devContextScriptPath}.`,
        scriptPath: devContextScriptPath,
      };
    }

    try {
      const { stdout } = await exec(devContextScriptPath, ["status", "--json"], { timeoutMs: 10_000 });
      const parsed = parseJsonWithSchema(stdout, devContextStatusSchema, "dev-context.sh");
      return { ...parsed, scriptPath: devContextScriptPath };
    } catch (error) {
      if (error instanceof ExecFileTextError) {
        return {
          mode: "none",
          message: `dev-context.sh failed (exit ${error.exitCode}): ${error.stderr.trim() || error.message}`,
          scriptPath: devContextScriptPath,
        };
      }
      if (error instanceof SyntaxError) {
        return {
          mode: "none",
          message: `dev-context.sh emitted invalid JSON: ${error.message}`,
          scriptPath: devContextScriptPath,
        };
      }
      if (error instanceof Error) {
        return {
          mode: "none",
          message: error.message,
          scriptPath: devContextScriptPath,
        };
      }
      throw error;
    }
  }

  return { monitorCheck, devContextStatus };
}
