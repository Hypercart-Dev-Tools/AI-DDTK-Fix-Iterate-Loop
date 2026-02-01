#!/usr/bin/env node
/**
 * WP Code Check MCP Test Suite
 * 
 * Comprehensive automated test suite for the MCP server.
 * Generates a test report with pass/fail results.
 * 
 * @version 1.0.0
 * @license Apache-2.0
 * @usage node dist/bin/mcp-test-suite.js [--json]
 */

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const JSON_OUTPUT = process.argv.includes("--json");

let testsPassed = 0;
let testsFailed = 0;
const results = [];

/**
 * Log test result
 */
function logTest(name, passed, message = "") {
  const status = passed ? "✅ PASS" : "❌ FAIL";
  console.log(`${status}: ${name}`);
  if (message) console.log(`       ${message}`);
  
  results.push({ name, passed, message });
  if (passed) testsPassed++;
  else testsFailed++;
}

/**
 * Run the test suite
 */
async function runTestSuite() {
  console.log("\n🧪 WP Code Check MCP Test Suite v1.0.0\n");
  console.log("=" .repeat(60));

  const client = new Client(
    { name: "wp-code-check-test-suite", version: "1.0.0" },
    { capabilities: {} }
  );

  const transport = new StdioClientTransport({
    command: "node",
    args: [path.join(__dirname, "mcp-server.js")],
  });

  try {
    // Test 1: Connection
    console.log("\n📡 Connection Tests\n");
    try {
      await client.connect(transport);
      logTest("Server connection", true);
    } catch (error) {
      logTest("Server connection", false, error.message);
      throw error;
    }

    // Test 2: List Resources
    console.log("\n📋 Resource Discovery Tests\n");
    let resources = [];
    try {
      const response = await client.listResources();
      resources = response.resources;
      logTest("List resources", resources.length > 0, `Found ${resources.length} resources`);
    } catch (error) {
      logTest("List resources", false, error.message);
    }

    // Test 3: Required Resources
    console.log("\n🔍 Required Resources Tests\n");
    const requiredUris = ["wpcc://latest-scan", "wpcc://latest-report"];
    requiredUris.forEach((uri) => {
      const exists = resources.some((r) => r.uri === uri);
      logTest(`Resource exists: ${uri}`, exists);
    });

    // Test 4: Read Resources
    console.log("\n📖 Resource Reading Tests\n");
    
    // Test latest-scan
    try {
      const response = await client.readResource({ uri: "wpcc://latest-scan" });
      const content = response.contents[0].text;
      const data = JSON.parse(content);
      
      logTest("Read wpcc://latest-scan", true, `${content.length} bytes`);
      logTest("Latest scan is valid JSON", true);
      logTest("Latest scan has timestamp", !!data.timestamp);
      logTest("Latest scan has summary", !!data.summary);
    } catch (error) {
      logTest("Read wpcc://latest-scan", false, error.message);
    }

    // Test latest-report
    try {
      const response = await client.readResource({ uri: "wpcc://latest-report" });
      const content = response.contents[0].text;
      
      logTest("Read wpcc://latest-report", true, `${content.length} bytes`);
      logTest("Latest report is HTML", content.includes("<html") || content.includes("<HTML"));
    } catch (error) {
      logTest("Read wpcc://latest-report", false, error.message);
    }

    // Test 5: Individual Scans
    console.log("\n🔎 Individual Scan Tests\n");
    const scanResources = resources.filter((r) => r.uri.startsWith("wpcc://scan/"));
    logTest(`Individual scans available`, scanResources.length > 0, `Found ${scanResources.length}`);

    if (scanResources.length > 0) {
      try {
        const firstScan = scanResources[0];
        const response = await client.readResource({ uri: firstScan.uri });
        const content = JSON.parse(response.contents[0].text);
        
        logTest(`Read first scan: ${firstScan.uri}`, true);
        logTest("Scan data is valid JSON", true);
      } catch (error) {
        logTest("Read individual scan", false, error.message);
      }
    }

    // Test 6: Error Handling
    console.log("\n⚠️  Error Handling Tests\n");
    try {
      await client.readResource({ uri: "wpcc://nonexistent" });
      logTest("Invalid resource error handling", false, "Should have thrown error");
    } catch (error) {
      logTest("Invalid resource error handling", true, "Correctly rejected invalid URI");
    }

    // Summary
    console.log("\n" + "=".repeat(60));
    console.log(`\n📊 Test Summary\n`);
    console.log(`  ✅ Passed: ${testsPassed}`);
    console.log(`  ❌ Failed: ${testsFailed}`);
    console.log(`  📈 Total:  ${testsPassed + testsFailed}`);
    console.log(`  📊 Rate:   ${((testsPassed / (testsPassed + testsFailed)) * 100).toFixed(1)}%\n`);

    if (JSON_OUTPUT) {
      console.log("\n📋 JSON Report:\n");
      console.log(JSON.stringify({
        timestamp: new Date().toISOString(),
        passed: testsPassed,
        failed: testsFailed,
        total: testsPassed + testsFailed,
        passRate: (testsPassed / (testsPassed + testsFailed)) * 100,
        results,
      }, null, 2));
    }

    process.exit(testsFailed > 0 ? 1 : 0);
  } catch (error) {
    console.error(`\n❌ Fatal error: ${error.message}\n`);
    process.exit(1);
  } finally {
    await client.close();
  }
}

// Run tests
runTestSuite();

