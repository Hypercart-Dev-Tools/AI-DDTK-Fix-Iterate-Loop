import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";
import type { createServersHandlers } from "../handlers/servers.js";
import { errorResult, successResult } from "./shared.js";

type ServersHandlers = ReturnType<typeof createServersHandlers>;

const registryEntrySchema = z.object({
  port: z.number(),
  service: z.string(),
  owner: z.string(),
  hostname: z.string(),
  notes: z.string(),
});

export function registerServersTools(server: McpServer, handlers: ServersHandlers): void {
  server.registerTool(
    "servers_check_port",
    {
      description:
        "Check whether a port is free, allocated, or a mutex port in the local development server registry (tools/servers.md). Use this before assigning a port to a new service.",
      inputSchema: {
        port: z.number().int().min(1).max(65535).describe("Port number to check, e.g. 8025"),
      },
      outputSchema: {
        port: z.number(),
        status: z.enum(["free", "allocated", "mutex"]),
        entry: registryEntrySchema.nullable(),
        registryPath: z.string(),
      },
    },
    async ({ port }) => {
      try {
        return successResult(await handlers.checkPort(port));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "servers_list_registry",
    {
      description:
        "List all entries in the local development server port registry (tools/servers.md). Returns the full allocation table as structured JSON so agents can find free ports without parsing markdown.",
      outputSchema: {
        entries: z.array(registryEntrySchema),
        allocatedPorts: z.array(z.number()),
        mutexPorts: z.array(z.number()),
        registryPath: z.string(),
      },
    },
    async () => {
      try {
        return successResult(await handlers.listRegistry());
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "servers_add_entry",
    {
      description:
        "Add a new service entry to the local development server port registry (tools/servers.md). Validates that the port is not already allocated and is not a mutex port (80/443) before writing. Returns a conflict object if the port is taken.",
      inputSchema: {
        port: z.number().int().min(1).max(65535).describe("Port number to assign, e.g. 8025"),
        service: z.string().min(1).describe("Service name, e.g. 'Mailpit web UI'"),
        owner: z.string().min(1).describe("Who manages this service, e.g. 'Homebrew', 'Docker', 'Node'"),
        hostname: z.string().min(1).describe("Hostname or bind address, e.g. 'localhost' or 'mailpit.test'"),
        notes: z.string().default("").describe("Optional notes, e.g. 'SMTP on 1025'"),
      },
      outputSchema: {
        added: z.boolean(),
        entry: registryEntrySchema,
        conflict: registryEntrySchema.nullable(),
        registryPath: z.string(),
        message: z.string(),
      },
    },
    async ({ port, service, owner, hostname, notes = "" }) => {
      try {
        return successResult(await handlers.addEntry({ port, service, owner, hostname, notes }));
      } catch (error) {
        return errorResult(error);
      }
    },
  );
}
