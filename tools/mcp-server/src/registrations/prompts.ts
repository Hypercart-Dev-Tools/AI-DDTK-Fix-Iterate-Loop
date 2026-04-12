import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";

export function registerPrompts(server: McpServer): void {
  server.registerPrompt(
    "preflight",
    {
      title: "AI-DDTK Preflight Check",
      description: "Run a session preflight — verifies AI-DDTK installation, MCP server, Playwright auth, and WordPress site context.",
    },
    () => ({
      messages: [
        {
          role: "user",
          content: {
            type: "text",
            text: "Please run an AI-DDTK session preflight check. Use the available MCP tools to verify:\n1. AI-DDTK installation and toolkit status\n2. LocalWP site context (list available sites)\n3. Playwright auth status\n4. WPCC availability\n\nSummarise what is ready and flag anything that needs attention before starting work.",
          },
        },
      ],
    }),
  );

  server.registerPrompt(
    "scan",
    {
      title: "WPCC Security/Performance Scan",
      description: "Run a WP Code Check scan on a plugin or theme path and triage the findings.",
      argsSchema: {
        path: z.string().min(1).describe("Path to scan, e.g. ./wp-content/plugins/my-plugin"),
      },
    },
    ({ path }) => ({
      messages: [
        {
          role: "user",
          content: {
            type: "text",
            text: `Please run a WPCC security and performance scan on: ${path}\n\nUse wpcc_run_scan with format=json, then:\n1. Summarise findings by severity (critical, high, medium, low)\n2. Flag likely false positives (check for nonce verification, wpdb->prepare usage, bounded loops)\n3. Recommend the top 3 fixes to prioritise`,
          },
        },
      ],
    }),
  );

  server.registerPrompt(
    "profile-page",
    {
      title: "Query Monitor Page Profile",
      description: "Profile a WordPress page with Query Monitor — DB queries, slow queries, N+1 patterns, and cache stats.",
      argsSchema: {
        siteUrl: z.string().url().describe("Full WordPress site URL, e.g. http://my-site.local"),
        path: z.string().min(1).describe("Page path to profile, e.g. /checkout/ or /wp-admin/edit.php"),
      },
    },
    ({ siteUrl, path }) => ({
      messages: [
        {
          role: "user",
          content: {
            type: "text",
            text: `Please profile the WordPress page at ${siteUrl}${path} using Query Monitor.\n\nRun qm_profile_page, then:\n1. Report total query count and total query time\n2. List slow queries (>50ms) using qm_slow_queries\n3. Identify N+1 patterns using qm_duplicate_queries\n4. Summarise cache stats\n5. Recommend the highest-impact optimisation`,
          },
        },
      ],
    }),
  );

  server.registerPrompt(
    "triage-scan",
    {
      title: "Triage Latest WPCC Scan",
      description: "Load the most recent WPCC scan and triage findings for false positives.",
    },
    () => ({
      messages: [
        {
          role: "user",
          content: {
            type: "text",
            text: "Please load the latest WPCC scan using the wpcc://latest-scan resource and triage the findings.\n\nFor each finding:\n1. Check if it is a likely false positive (nonce present, wpdb->prepare used, loop is bounded)\n2. Mark confirmed issues vs false positives\n3. Produce a triage summary with counts and your top 3 actionable recommendations",
          },
        },
      ],
    }),
  );

  server.registerPrompt(
    "wire-project",
    {
      title: "Wire Project for AI-DDTK",
      description: "Wire the current project for AI-DDTK MCP integration — creates config files for all detected AI editors.",
      argsSchema: {
        projectPath: z.string().min(1).optional().describe("Absolute path to the project; defaults to current directory"),
        client: z.enum(["auto", "claude-code", "vscode", "augment", "cursor", "all"]).default("auto").describe("Which AI editor(s) to configure"),
      },
    },
    ({ projectPath, client }) => ({
      messages: [
        {
          role: "user",
          content: {
            type: "text",
            text: `Please wire the project${projectPath ? ` at ${projectPath}` : " at the current directory"} for AI-DDTK MCP integration.\n\nRun: ~/bin/ai-ddtk/install.sh wire-project${client && client !== "auto" ? ` --client=${client}` : ""}${projectPath ? ` ${projectPath}` : ""}\n\nThen confirm which config files were created and which editors are now configured.`,
          },
        },
      ],
    }),
  );
}
