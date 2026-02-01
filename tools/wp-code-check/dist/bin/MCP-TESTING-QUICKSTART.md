# MCP Testing Quick Start

**Get started testing the WP Code Check MCP server in 5 minutes**

---

## ⚡ 5-Minute Setup

### Step 1: Install Dependencies (1 min)

```bash
npm install
```

### Step 2: Generate Test Data (2 min)

```bash
./dist/bin/check-performance.sh --paths ./dist/tests/fixtures
```

### Step 3: Run Tests (2 min)

```bash
# Option A: Automated test suite (recommended)
node dist/bin/mcp-test-suite.js

# Option B: Interactive test client
node dist/bin/mcp-test-client.js

# Option C: Test specific resource
node dist/bin/mcp-test-client.js --resource wpcc://latest-scan
```

---

## ✅ Expected Results

```
✅ Passed: 14/14 (100%)
✅ Server connection
✅ Resource discovery
✅ Latest scan readable
✅ Latest report readable
✅ Error handling works
```

---

## 🎯 Common Commands

### Run All Tests
```bash
node dist/bin/mcp-test-suite.js
```

### Get JSON Report
```bash
node dist/bin/mcp-test-suite.js --json
```

### Read Latest Scan
```bash
node dist/bin/mcp-test-client.js --resource wpcc://latest-scan
```

### Read Latest Report
```bash
node dist/bin/mcp-test-client.js --resource wpcc://latest-report
```

### Read Specific Scan
```bash
node dist/bin/mcp-test-client.js --resource "wpcc://scan/2026-01-13-031719-UTC"
```

### Show Help
```bash
node dist/bin/mcp-test-client.js --help
```

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [MCP-TESTING-GUIDE.md](./MCP-TESTING-GUIDE.md) | Complete testing guide with scenarios |
| [MCP-TEST-CLIENT-README.md](./MCP-TEST-CLIENT-README.md) | Test client documentation |
| [MCP-README.md](./MCP-README.md) | Server configuration & usage |

---

## 🔧 Troubleshooting

### No scan results found
```bash
./dist/bin/check-performance.sh --paths ./dist/tests/fixtures
```

### Dependencies missing
```bash
npm install
```

### Tests fail
```bash
# Check Node.js version (need v18+)
node --version

# Verify files exist
ls -la dist/bin/mcp-*.js
```

---

## 🚀 Next Steps

1. ✅ Run the test suite
2. ✅ Verify all tests pass
3. ✅ Configure Claude Desktop or Cline (see MCP-README.md)
4. ✅ Test with your AI assistant

---

## 📊 Test Coverage

- ✅ Server connection
- ✅ Resource discovery
- ✅ Required resources
- ✅ JSON validation
- ✅ HTML reports
- ✅ Individual scans
- ✅ Error handling

**Total: 14 tests, 100% pass rate**

---

**Ready to test? Run:** `node dist/bin/mcp-test-suite.js`

