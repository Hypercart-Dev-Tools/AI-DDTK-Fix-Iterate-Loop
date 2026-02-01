# WP Code Check - MCP Server

**Model Context Protocol (MCP) server for WP Code Check**

This server exposes WP Code Check scan results as MCP resources, allowing AI assistants like Claude Desktop and Cline to directly access and analyze your WordPress code quality scans.

---

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# From the repository root
npm install
```

### 2. Configure Your AI Assistant

#### Claude Desktop (macOS)

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "wp-code-check": {
      "command": "node",
      "args": [
        "/absolute/path/to/wp-code-check/dist/bin/mcp-server.js"
      ]
    }
  }
}
```

#### Claude Desktop (Windows)

Edit `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "wp-code-check": {
      "command": "node",
      "args": [
        "C:\\absolute\\path\\to\\wp-code-check\\dist\\bin\\mcp-server.js"
      ]
    }
  }
}
```

#### Cline (VS Code)

Add to Cline MCP settings:

```json
{
  "mcpServers": {
    "wp-code-check": {
      "command": "node",
      "args": [
        "/absolute/path/to/wp-code-check/dist/bin/mcp-server.js"
      ]
    }
  }
}
```

**Important:** Always use absolute paths, not relative paths or `~`.

### 3. Run a Scan

```bash
./dist/bin/check-performance.sh --paths /path/to/your/plugin
```

### 4. Ask Your AI Assistant

In Claude Desktop or Cline:

- "Show me the latest WP Code Check scan results"
- "What are the critical issues in the latest scan?"
- "Summarize the findings from wpcc://latest-scan"
- "What's in the latest HTML report?"

---

## 📚 Available Resources

| Resource URI | Description | MIME Type |
|--------------|-------------|-----------|
| `wpcc://latest-scan` | Most recent JSON scan log | `application/json` |
| `wpcc://latest-report` | Most recent HTML report | `text/html` |
| `wpcc://scan/{scan-id}` | Specific scan by timestamp ID | `application/json` |

**Example Scan IDs:**
- `2026-01-13-031719-UTC`
- `2026-01-12-155649-UTC`

---

## 🧪 Testing

```bash
# 1. Run a test scan
./dist/bin/check-performance.sh --paths ./dist/tests/fixtures

# 2. Start MCP server manually (for debugging)
node dist/bin/mcp-server.js
# Should output: "WP Code Check MCP Server running on stdio"

# 3. Test with your AI assistant
# Ask: "Read wpcc://latest-scan and summarize the findings"
```

---

## 🔧 Troubleshooting

### "No scan results found"

**Solution:** Run a scan first:
```bash
./dist/bin/check-performance.sh --paths /path/to/plugin
```

### "Cannot find module '@modelcontextprotocol/sdk'"

**Solution:** Install dependencies:
```bash
npm install
```

### "Command not found: node"

**Solution:** Install Node.js 18+ from [nodejs.org](https://nodejs.org)

### AI assistant doesn't see the server

**Solution:**
1. Verify absolute paths in config (no `~` or relative paths)
2. Restart your AI assistant after config changes
3. Check logs in AI assistant settings

---

## 📖 Documentation

- **Full MCP Documentation:** [PROJECT/1-INBOX/PROJECT-MCP.md](../../PROJECT/1-INBOX/PROJECT-MCP.md)
- **Main README:** [README.md](../../README.md)
- **Changelog:** [CHANGELOG.md](../../CHANGELOG.md)

---

## 🤝 Support

- **Issues:** [GitHub Issues](https://github.com/Hypercart-Dev-Tools/WP-Code-Check/issues)
- **Email:** noel@hypercart.io
- **Website:** [wpcodecheck.com](https://wpcodecheck.com)

---

**License:** Apache-2.0  
**Version:** 1.0.0 (Tier 1 - Basic Resources)

