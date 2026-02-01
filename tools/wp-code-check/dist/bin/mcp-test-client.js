#!/usr/bin/env node
/**
 * WP Code Check MCP Test Client
 *
 * Node.js client for testing the WP Code Check MCP server.
 * Connects to the server, lists resources, and reads their contents.
 *
 * @version 1.1.0
 * @license Apache-2.0
 * @usage node dist/bin/mcp-test-client.js [--verbose] [--resource <uri>]
 */

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const VERBOSE = process.argv.includes("--verbose");
const RESOURCE_ARG = process.argv.find((arg, i) => process.argv[i - 1] === "--resource");

/**
 * Log helper with optional verbose mode
 */
function log(message, isVerbose = false) {
  if (!isVerbose || VERBOSE) {
    console.log(message);
  }
}

/**
 * Format JSON for display
 */
function formatJson(obj, indent = 2) {
  return JSON.stringify(obj, null, indent);
}

/**
 * Test the MCP server
 */
async function testMcpServer() {
  log("\n🚀 Starting WP Code Check MCP Test Client...\n");

  // Create MCP client
  const client = new Client(
    {
      name: "wp-code-check-test-client",
      version: "1.1.0",
    },
    {
      capabilities: {},
    }
  );

  // Create transport
  const transport = new StdioClientTransport({
    command: "node",
    args: [path.join(__dirname, "mcp-server.js")],
  });

  try {
    log("📡 Connecting to MCP server...");
    await client.connect(transport);
    log("✅ Connected to MCP server\n");

    // Test 1: List resources
    log("📋 Test 1: Listing available resources...");
    const resourcesResponse = await client.listResources();
    const resources = resourcesResponse.resources;

    log(`✅ Found ${resources.length} resources:\n`);
    resources.forEach((resource) => {
      log(`  • ${resource.uri}`);
      log(`    Name: ${resource.name}`);
      log(`    Type: ${resource.mimeType}`);
      log(`    Desc: ${resource.description}\n`);
    });

    // If specific resource requested, read it
    if (RESOURCE_ARG) {
      log(`📖 Reading specific resource: ${RESOURCE_ARG}...`);
      try {
        const response = await client.readResource({ uri: RESOURCE_ARG });
        const content = response.contents[0].text;

        if (response.contents[0].mimeType === "application/json") {
          const data = JSON.parse(content);
          log(`✅ Successfully read ${RESOURCE_ARG}\n`);
          log(formatJson(data));
        } else {
          log(`✅ Successfully read ${RESOURCE_ARG}\n`);
          log(`Content (${content.length} bytes):\n`);
          log(content.substring(0, 500) + (content.length > 500 ? "..." : ""));
        }
      } catch (error) {
        log(`❌ Error reading ${RESOURCE_ARG}: ${error.message}\n`);
        process.exit(1);
      }
    } else {
      // Run standard tests
      await runStandardTests(client, resources);
    }

    log("✅ All tests completed!\n");
  } catch (error) {
    log(`❌ Error: ${error.message}\n`);
    process.exit(1);
  } finally {
    await client.close();
  }
}

/**
 * Run standard test suite
 */
async function runStandardTests(client, resources) {
  // Test 2: Read latest scan
  log("📖 Test 2: Reading wpcc://latest-scan...");
  try {
    const scanResponse = await client.readResource({
      uri: "wpcc://latest-scan",
    });

    const scanContent = scanResponse.contents[0].text;
    const scanData = JSON.parse(scanContent);

    log("✅ Successfully read latest scan\n");
    log(`  Timestamp: ${scanData.timestamp || "N/A"}`);
    log(`  Total Issues: ${scanData.findings?.length || 0}`);
    log(`  Errors: ${scanData.summary?.total_errors || 0}`);
    log(`  Warnings: ${scanData.summary?.total_warnings || 0}\n`);
  } catch (error) {
    log(`⚠️  Could not read latest scan: ${error.message}\n`);
  }

  // Test 3: Read latest report
  log("📖 Test 3: Reading wpcc://latest-report...");
  try {
    const reportResponse = await client.readResource({
      uri: "wpcc://latest-report",
    });

    const reportContent = reportResponse.contents[0].text;
    log(`✅ Successfully read latest report (${reportContent.length} bytes)\n`);
  } catch (error) {
    log(`⚠️  Could not read latest report: ${error.message}\n`);
  }

  // Test 4: Read individual scans
  const scanResources = resources.filter((r) => r.uri.startsWith("wpcc://scan/"));
  if (scanResources.length > 0) {
    log(`📖 Test 4: Reading individual scans (${scanResources.length} available)...`);

    // Test the first scan
    const firstScan = scanResources[0];
    try {
      const response = await client.readResource({ uri: firstScan.uri });
      const content = JSON.parse(response.contents[0].text);
      log(`✅ Successfully read ${firstScan.uri}`);
      log(`  Issues found: ${content.findings?.length || 0}\n`);
    } catch (error) {
      log(`⚠️  Error reading ${firstScan.uri}: ${error.message}\n`);
    }
  } else {
    log("ℹ️  No individual scan resources available\n");
  }
}

/**
 * Print usage information
 */
function printUsage() {
  console.log(`
WP Code Check MCP Test Client v1.1.0

Usage:
  node dist/bin/mcp-test-client.js [options]

Options:
  --verbose              Show detailed output
  --resource <uri>       Read a specific resource (e.g., wpcc://latest-scan)

Examples:
  # Run standard tests
  node dist/bin/mcp-test-client.js

  # Run with verbose output
  node dist/bin/mcp-test-client.js --verbose

  # Read a specific resource
  node dist/bin/mcp-test-client.js --resource wpcc://latest-scan
  node dist/bin/mcp-test-client.js --resource wpcc://latest-report
  node dist/bin/mcp-test-client.js --resource "wpcc://scan/2026-01-13-031719-UTC"

Available Resources:
  wpcc://latest-scan     - Most recent JSON scan results
  wpcc://latest-report   - Most recent HTML report
  wpcc://scan/{scan-id}  - Specific scan by timestamp

For more info, see: dist/bin/MCP-README.md
  `);
}

// Show usage if --help requested
if (process.argv.includes("--help") || process.argv.includes("-h")) {
  printUsage();
  process.exit(0);
}

// Run tests
testMcpServer().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});

