# WP Code Check MCP Test Client

**Node.js client for testing the WP Code Check MCP server**

This tool allows you to test the MCP (Model Context Protocol) server implementation without needing Claude Desktop or Cline. It connects to the server, lists available resources, and reads their contents.

---

## 🚀 Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Generate Test Data

```bash
# Run a scan to create test data
./dist/bin/check-performance.sh --paths ./dist/tests/fixtures
```

### 3. Run the Test Client

```bash
# Run standard tests
node dist/bin/mcp-test-client.js

# Run with verbose output
node dist/bin/mcp-test-client.js --verbose

# Read a specific resource
node dist/bin/mcp-test-client.js --resource wpcc://latest-scan
```

---

## 📖 Usage

### Basic Test Suite

```bash
node dist/bin/mcp-test-client.js
```

This runs 4 tests:
1. **List Resources** - Shows all available MCP resources
2. **Read Latest Scan** - Fetches the most recent JSON scan results
3. **Read Latest Report** - Fetches the most recent HTML report
4. **Read Individual Scan** - Tests reading a specific scan by ID

### Read Specific Resource

```bash
# Read latest scan results
node dist/bin/mcp-test-client.js --resource wpcc://latest-scan

# Read latest HTML report
node dist/bin/mcp-test-client.js --resource wpcc://latest-report

# Read a specific scan by timestamp
node dist/bin/mcp-test-client.js --resource "wpcc://scan/2026-01-13-031719-UTC"
```

### Verbose Output

```bash
node dist/bin/mcp-test-client.js --verbose
```

Shows detailed logging for debugging.

### Help

```bash
node dist/bin/mcp-test-client.js --help
```

---

## 📊 Available Resources

| Resource URI | Description | Type |
|--------------|-------------|------|
| `wpcc://latest-scan` | Most recent JSON scan results | JSON |
| `wpcc://latest-report` | Most recent HTML report | HTML |
| `wpcc://scan/{scan-id}` | Specific scan by timestamp | JSON |

**Example Scan IDs:**
- `2026-01-13-031719-UTC`
- `2026-01-12-155649-UTC`

---

## 🧪 Test Output Example

```
🚀 Starting WP Code Check MCP Test Client...

📡 Connecting to MCP server...
✅ Connected to MCP server

📋 Test 1: Listing available resources...
✅ Found 12 resources:

  • wpcc://latest-scan
    Name: Latest WP Code Check Scan
    Type: application/json
    Desc: Most recent WordPress code scan results (JSON)

📖 Test 2: Reading wpcc://latest-scan...
✅ Successfully read latest scan

  Timestamp: 2026-01-13T03:17:28Z
  Total Issues: 2
  Errors: 2
  Warnings: 0

✅ All tests completed!
```

---

## 🔧 Troubleshooting

### "No scan results found"

**Solution:** Run a scan first:
```bash
./dist/bin/check-performance.sh --paths ./dist/tests/fixtures
```

### "Cannot find module '@modelcontextprotocol/sdk'"

**Solution:** Install dependencies:
```bash
npm install
```

### "Connection refused"

**Solution:** The test client starts its own server. If you see this error, check that:
- Node.js is installed: `node --version`
- The mcp-server.js file exists: `ls -la dist/bin/mcp-server.js`

### Resource not found

**Solution:** List available resources first:
```bash
node dist/bin/mcp-test-client.js
```

Then use a valid resource URI from the list.

---

## 🔗 Integration with AI Assistants

Once you've verified the MCP server works with this test client, you can configure it in:

- **Claude Desktop** - See `dist/bin/MCP-README.md`
- **Cline (VS Code)** - See `dist/bin/MCP-README.md`

---

## 📝 Version History

- **v1.1.0** (2026-01-14) - Added `--resource` flag for reading specific resources
- **v1.0.0** (2026-01-13) - Initial release with basic test suite

---

## 📚 Related Documentation

- [MCP Server README](./MCP-README.md) - Server configuration and usage
- [MCP Implementation Details](../../PROJECT/2-WORKING/PROJECT-MCP.md) - Technical architecture
- [WP Code Check README](../README.md) - Main project documentation

