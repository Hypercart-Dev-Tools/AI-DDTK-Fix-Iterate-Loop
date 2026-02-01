#!/usr/bin/env node
/**
 * WP Code Check MCP Server (Tier 1)
 * 
 * Model Context Protocol server that exposes WP Code Check scan results
 * as resources for AI assistants (Claude Desktop, Cline, etc.)
 * 
 * @version 1.0.0
 * @license Apache-2.0
 * @see https://modelcontextprotocol.io
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Resolve paths relative to the script location
const LOGS_DIR = path.resolve(__dirname, "../logs");
const REPORTS_DIR = path.resolve(__dirname, "../reports");

/**
 * Find the most recent JSON scan log
 */
async function findLatestScanJson() {
  try {
    const files = await fs.readdir(LOGS_DIR);
    const jsonFiles = files
      .filter(f => f.endsWith('.json'))
      .sort()
      .reverse();
    
    if (jsonFiles.length === 0) {
      return null;
    }
    
    return path.join(LOGS_DIR, jsonFiles[0]);
  } catch (error) {
    console.error(`Error reading logs directory: ${error.message}`);
    return null;
  }
}

/**
 * Find the most recent HTML report
 */
async function findLatestHtmlReport() {
  try {
    const files = await fs.readdir(REPORTS_DIR);
    const htmlFiles = files
      .filter(f => f.endsWith('.html'))
      .sort()
      .reverse();

    if (htmlFiles.length === 0) {
      return null;
    }

    return path.join(REPORTS_DIR, htmlFiles[0]);
  } catch (error) {
    console.error(`Error reading reports directory: ${error.message}`);
    return null;
  }
}

/**
 * List all available scan logs
 */
async function listAllScans() {
  try {
    const files = await fs.readdir(LOGS_DIR);
    return files
      .filter(f => f.endsWith('.json'))
      .sort()
      .reverse()
      .slice(0, 10); // Return last 10 scans
  } catch (error) {
    console.error(`Error listing scans: ${error.message}`);
    return [];
  }
}

// Create MCP server instance
const server = new Server(
  {
    name: "wp-code-check",
    version: "1.0.0",
  },
  {
    capabilities: {
      resources: {},
    },
  }
);

/**
 * Handler: List available resources
 * Exposes scan results as MCP resources
 */
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  const scans = await listAllScans();
  
  const resources = [
    {
      uri: "wpcc://latest-scan",
      name: "Latest WP Code Check Scan",
      description: "Most recent WordPress code scan results (JSON)",
      mimeType: "application/json",
    },
    {
      uri: "wpcc://latest-report",
      name: "Latest HTML Report",
      description: "Most recent scan report (HTML)",
      mimeType: "text/html",
    },
  ];
  
  // Add individual scan resources
  scans.forEach((scanFile, index) => {
    const scanId = scanFile.replace('.json', '');
    resources.push({
      uri: `wpcc://scan/${scanId}`,
      name: `Scan: ${scanId}`,
      description: `WordPress code scan from ${scanId}`,
      mimeType: "application/json",
    });
  });
  
  return { resources };
});

/**
 * Handler: Read resource content
 * Returns the actual scan data
 */
server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const uri = request.params.uri;
  
  if (uri === "wpcc://latest-scan") {
    const latestJson = await findLatestScanJson();
    if (!latestJson) {
      throw new Error("No scan results found. Run a scan first with: ./dist/bin/check-performance.sh --paths <path>");
    }
    
    const content = await fs.readFile(latestJson, "utf-8");

    return {
      contents: [
        {
          uri: request.params.uri,
          mimeType: "application/json",
          text: content,
        },
      ],
    };
  }

  if (uri === "wpcc://latest-report") {
    const latestHtml = await findLatestHtmlReport();
    if (!latestHtml) {
      throw new Error("No HTML reports found. Generate one with: ./dist/bin/json-to-html.py <scan.json> <output.html>");
    }

    const content = await fs.readFile(latestHtml, "utf-8");

    return {
      contents: [
        {
          uri: request.params.uri,
          mimeType: "text/html",
          text: content,
        },
      ],
    };
  }

  // Handle individual scan URIs
  const scanMatch = uri.match(/^wpcc:\/\/scan\/(.+)$/);
  if (scanMatch) {
    const scanId = scanMatch[1];
    const scanPath = path.join(LOGS_DIR, `${scanId}.json`);

    try {
      const content = await fs.readFile(scanPath, "utf-8");
      return {
        contents: [
          {
            uri: request.params.uri,
            mimeType: "application/json",
            text: content,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Scan not found: ${scanId}`);
    }
  }

  throw new Error(`Unknown resource URI: ${uri}`);
});

/**
 * Start the MCP server
 */
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error("WP Code Check MCP Server running on stdio");
  console.error(`Logs directory: ${LOGS_DIR}`);
  console.error(`Reports directory: ${REPORTS_DIR}`);
}

main().catch((error) => {
  console.error("Fatal error in main():", error);
  process.exit(1);
});

