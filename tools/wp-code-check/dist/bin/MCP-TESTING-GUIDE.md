# WP Code Check MCP Testing Guide

**Complete guide to testing the MCP server implementation**

This guide covers all available testing tools and methods for validating the WP Code Check MCP server.

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Testing Tools](#testing-tools)
3. [Test Scenarios](#test-scenarios)
4. [Troubleshooting](#troubleshooting)
5. [Integration Testing](#integration-testing)

---

## 🚀 Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Generate Test Data

```bash
./dist/bin/check-performance.sh --paths ./dist/tests/fixtures
```

### 3. Run Tests

```bash
# Option A: Basic test client
node dist/bin/mcp-test-client.js

# Option B: Automated test suite
node dist/bin/mcp-test-suite.js

# Option C: Test specific resource
node dist/bin/mcp-test-client.js --resource wpcc://latest-scan
```

---

## 🧪 Testing Tools

### 1. MCP Test Client (`mcp-test-client.js`)

**Interactive client for manual testing**

```bash
# Run standard tests
node dist/bin/mcp-test-client.js

# Read specific resource
node dist/bin/mcp-test-client.js --resource wpcc://latest-scan

# Verbose output
node dist/bin/mcp-test-client.js --verbose

# Show help
node dist/bin/mcp-test-client.js --help
```

**Features:**
- ✅ Lists all available resources
- ✅ Reads and displays resource contents
- ✅ Validates JSON parsing
- ✅ Shows scan metadata and statistics

**Documentation:** [MCP-TEST-CLIENT-README.md](./MCP-TEST-CLIENT-README.md)

### 2. MCP Test Suite (`mcp-test-suite.js`)

**Automated test suite with pass/fail reporting**

```bash
# Run all tests
node dist/bin/mcp-test-suite.js

# Generate JSON report
node dist/bin/mcp-test-suite.js --json
```

**Tests Included:**
- ✅ Server connection
- ✅ Resource discovery
- ✅ Required resources exist
- ✅ Resource reading
- ✅ JSON validation
- ✅ Individual scan access
- ✅ Error handling

**Output:**
```
📊 Test Summary

  ✅ Passed: 14
  ❌ Failed: 0
  📈 Total:  14
  📊 Rate:   100.0%
```

### 3. MCP Server (`mcp-server.js`)

**The server itself**

```bash
# Start server manually (for debugging)
node dist/bin/mcp-server.js

# Should output:
# WP Code Check MCP Server running on stdio
# Logs directory: ...
# Reports directory: ...
```

---

## 🎯 Test Scenarios

### Scenario 1: Verify Server Starts

```bash
node dist/bin/mcp-test-suite.js
```

**Expected:** All connection tests pass

### Scenario 2: Verify Resources Available

```bash
node dist/bin/mcp-test-client.js
```

**Expected:** Lists 12+ resources including:
- `wpcc://latest-scan`
- `wpcc://latest-report`
- `wpcc://scan/{scan-id}` (multiple)

### Scenario 3: Read Latest Scan

```bash
node dist/bin/mcp-test-client.js --resource wpcc://latest-scan
```

**Expected:** JSON output with:
- `version` field
- `timestamp` field
- `summary` object with error/warning counts
- `findings` array

### Scenario 4: Read Latest Report

```bash
node dist/bin/mcp-test-client.js --resource wpcc://latest-report
```

**Expected:** HTML content (503KB+)

### Scenario 5: Read Specific Scan

```bash
node dist/bin/mcp-test-client.js --resource "wpcc://scan/2026-01-13-031719-UTC"
```

**Expected:** JSON scan data for that specific timestamp

### Scenario 6: Error Handling

```bash
node dist/bin/mcp-test-client.js --resource "wpcc://nonexistent"
```

**Expected:** Error message about unknown resource

---

## 🔧 Troubleshooting

### Issue: "No scan results found"

**Cause:** No scan data exists yet

**Solution:**
```bash
./dist/bin/check-performance.sh --paths ./dist/tests/fixtures
```

### Issue: "Cannot find module '@modelcontextprotocol/sdk'"

**Cause:** Dependencies not installed

**Solution:**
```bash
npm install
```

### Issue: "Connection refused"

**Cause:** Node.js or file path issue

**Solution:**
```bash
# Verify Node.js
node --version  # Should be v18+

# Verify files exist
ls -la dist/bin/mcp-server.js
ls -la dist/bin/mcp-test-client.js
```

### Issue: Tests fail with "Resource not found"

**Cause:** Scan data is missing or corrupted

**Solution:**
```bash
# Remove old logs and regenerate
rm -rf dist/logs/*.json
./dist/bin/check-performance.sh --paths ./dist/tests/fixtures
```

---

## 🔗 Integration Testing

### Test with Claude Desktop

1. **Configure Claude Desktop:**
   ```json
   {
     "mcpServers": {
       "wp-code-check": {
         "command": "node",
         "args": ["/absolute/path/to/wp-code-check/dist/bin/mcp-server.js"]
       }
     }
   }
   ```

2. **Restart Claude Desktop**

3. **Test in Claude:**
   - "Show me the latest WP Code Check scan results"
   - "What are the critical issues in wpcc://latest-scan?"
   - "Summarize the findings from the latest scan"

### Test with Cline (VS Code)

1. **Add to Cline MCP settings:**
   ```json
   {
     "mcpServers": {
       "wp-code-check": {
         "command": "node",
         "args": ["/absolute/path/to/wp-code-check/dist/bin/mcp-server.js"]
       }
     }
   }
   ```

2. **Restart VS Code**

3. **Test in Cline chat**

---

## 📊 Test Results

### Latest Test Run

```
✅ Passed: 14/14 (100%)
✅ Server connection
✅ Resource discovery (12 resources)
✅ Required resources exist
✅ Latest scan readable
✅ Latest report readable
✅ Individual scans readable
✅ Error handling works
```

---

## 📚 Related Documentation

- [MCP Server README](./MCP-README.md)
- [MCP Test Client README](./MCP-TEST-CLIENT-README.md)
- [MCP Implementation Details](../../PROJECT/2-WORKING/PROJECT-MCP.md)
- [Main README](../README.md)

