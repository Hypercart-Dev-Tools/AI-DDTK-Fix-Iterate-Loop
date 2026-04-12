import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";
import type { createPostFlightHandlers } from "../handlers/post-flight.js";
import { errorResult, successResult } from "./shared.js";

type PostFlightHandlers = ReturnType<typeof createPostFlightHandlers>;

const postFlightCheckSchema = z.object({
  check: z.string(),
  status: z.enum(["ok", "missing", "stale", "dirty", "error"]),
  message: z.string(),
});

export function registerPostFlightTools(server: McpServer, handlers: PostFlightHandlers): void {
  server.registerTool(
    "post_flight_session_cleanup",
    {
      description:
        "Solo developer post-flight session cleanup — checks 4X4.md and CHANGELOG.md freshness, scans Claude Code memory for conflicted duplicates (orphans, broken links, duplicate topics). Optionally commits and pushes with confirmation. Runs build validation.",
      inputSchema: {
        mode: z.enum(["report", "commit", "push"]).default("report").describe("report (default, no git actions), commit (with confirmation), or push (commit + push with confirmations)"),
        dryRun: z.boolean().default(false).describe("Show what would happen without executing"),
        force: z.boolean().default(false).describe("Skip all confirmation prompts (use with --push for automation)"),
        skipValidation: z.boolean().default(false).describe("Skip build validation checks"),
      },
      outputSchema: {
        mode: z.string(),
        dryRun: z.boolean(),
        force: z.boolean(),
        checks: z.array(postFlightCheckSchema),
        gitBranch: z.string(),
        gitState: z.enum(["clean", "dirty"]),
        modifiedFiles: z.number(),
        untrackedFiles: z.number(),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async ({ mode = "report", dryRun = false, force = false, skipValidation = false }) => {
      try {
        return successResult(
          await handlers.runPostFlight({
            mode: mode as "report" | "commit" | "push",
            dryRun,
            force,
            skipValidation,
          }),
        );
      } catch (error) {
        return errorResult(error);
      }
    },
  );
}
