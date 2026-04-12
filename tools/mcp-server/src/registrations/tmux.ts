import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";
import type { createTmuxHandlers } from "../handlers/tmux.js";
import { errorResult, successResult } from "./shared.js";

type TmuxHandlers = ReturnType<typeof createTmuxHandlers>;

const tmuxSessionSummarySchema = z.object({
  session: z.string(),
  windows: z.number(),
  attached: z.boolean(),
  state: z.enum(["attached", "detached"]),
});

export function registerTmuxTools(server: McpServer, handlers: TmuxHandlers): void {
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
        return successResult(await handlers.start(cwd, session));
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
        return successResult(await handlers.send(command, session));
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
        return successResult(await handlers.capture(tail ?? 200, session));
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
        return successResult(await handlers.stop(session));
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
        return successResult(await handlers.list());
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
        return successResult(await handlers.status(session));
      } catch (error) {
        return errorResult(error);
      }
    },
  );
}
