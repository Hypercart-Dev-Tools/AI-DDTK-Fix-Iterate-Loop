# WP AJAX Test - Tool Specification

**Version**: 1.0.0  
**Status**: Draft  
**Location**: `~/bin/ai-ddtk/bin/wp-ajax-test` (centralized)

---

## Purpose

Lightweight WordPress AJAX endpoint testing without browser automation. Handles WordPress-specific authentication (nonces, cookies) and provides JSON output for AI agent parsing.

---

## Design Principles

1. **Centralized by default** - Install once in AI-DDTK, call from anywhere
2. **Local copy when needed** - AI agents can create project-specific wrapper if customization required
3. **WordPress-aware** - Auto-handles nonces, cookies, wp_ajax_* actions
4. **JSON I/O** - Structured input/output for AI parsing
5. **Credential-safe** - Loads auth from `/temp`, never commits
6. **Zero dependencies** - Uses Node.js built-ins + axios (already in AI-DDTK)

---

## Installation

### Centralized (Recommended)

```bash
# Already available if AI-DDTK installed
which wp-ajax-test
# ~/bin/ai-ddtk/bin/wp-ajax-test
```

### Local Copy (When Customization Needed)

```bash
# AI agent creates project-specific wrapper
cat > test-ajax.sh <<'EOF'
#!/bin/bash
# Project-specific AJAX test wrapper
# Calls centralized tool with project defaults

~/bin/ai-ddtk/bin/wp-ajax-test \
  --url "https://mysite.local" \
  --auth "temp/auth.json" \
  "$@"
EOF
chmod +x test-ajax.sh

# Add to .gitignore
echo "test-ajax.sh" >> .gitignore
```

**When to use local copy**:
- Project has unique auth requirements
- Need to set default URL/credentials
- Custom pre/post-processing needed
- Batch testing with project-specific config

**When to call centrally**:
- One-off endpoint tests
- Quick debugging
- Following AI-DDTK recipes
- No project-specific requirements

---

## CLI Interface

### Basic Usage

```bash
# Test single endpoint
wp-ajax-test --url https://site.local --action my_ajax_action

# With data payload
wp-ajax-test --url https://site.local --action my_ajax_action --data '{"key":"value"}'

# With authentication
wp-ajax-test --url https://site.local --action my_ajax_action --auth temp/auth.json

# JSON output (for AI parsing)
wp-ajax-test --url https://site.local --action my_ajax_action --format json
```

### Advanced Usage

```bash
# Admin AJAX (default)
wp-ajax-test --url https://site.local --action my_ajax_action --admin

# Frontend AJAX (nopriv)
wp-ajax-test --url https://site.local --action my_ajax_action --nopriv

# Custom endpoint (REST API)
wp-ajax-test --url https://site.local/wp-json/myplugin/v1/endpoint --method POST

# Batch testing
wp-ajax-test --batch tests/ajax-endpoints.json

# Verbose output (debugging)
wp-ajax-test --url https://site.local --action my_ajax_action --verbose
```

---

## Authentication

### Auth File Format (`temp/auth.json`)

```json
{
  "username": "admin",
  "password": "password123",
  "cookies": {
    "wordpress_logged_in": "...",
    "wordpress_sec": "..."
  },
  "nonce": "abc123def456"
}
```

### Auto-Authentication Flow

1. **Check for existing auth**: Read `temp/auth.json`
2. **If missing**: Prompt user or attempt login
3. **Extract nonce**: Scrape wp-admin page for nonce
4. **Store cookies**: Save session cookies for reuse
5. **Validate**: Test with simple AJAX call

---

## Output Formats

### Human-Readable (Default)

```
✓ AJAX Test: my_ajax_action
  URL: https://site.local/wp-admin/admin-ajax.php
  Status: 200 OK
  Response Time: 234ms
  
  Response:
  {
    "success": true,
    "data": {
      "message": "Operation completed"
    }
  }
```

### JSON (for AI Agents)

```json
{
  "success": true,
  "action": "my_ajax_action",
  "url": "https://site.local/wp-admin/admin-ajax.php",
  "status_code": 200,
  "response_time_ms": 234,
  "response": {
    "success": true,
    "data": {
      "message": "Operation completed"
    }
  },
  "headers": {
    "content-type": "application/json"
  }
}
```

---

## Batch Testing

### Batch File Format (`tests/ajax-endpoints.json`)

```json
{
  "config": {
    "url": "https://site.local",
    "auth": "temp/auth.json"
  },
  "tests": [
    {
      "name": "Get user data",
      "action": "get_user_data",
      "data": {"user_id": 1},
      "expect": {
        "success": true,
        "data.user.ID": 1
      }
    },
    {
      "name": "Update settings",
      "action": "update_settings",
      "data": {"setting": "value"},
      "expect": {
        "success": true
      }
    }
  ]
}
```

### Batch Output

```json
{
  "summary": {
    "total": 2,
    "passed": 2,
    "failed": 0,
    "duration_ms": 456
  },
  "results": [
    {
      "name": "Get user data",
      "passed": true,
      "response_time_ms": 123
    }
  ]
}
```

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `AUTH_REQUIRED` | No auth file found | Create `temp/auth.json` or use `--auth` flag |
| `NONCE_INVALID` | Nonce expired/missing | Re-authenticate to get fresh nonce |
| `ENDPOINT_NOT_FOUND` | Action not registered | Check action name, verify plugin loaded |
| `PERMISSION_DENIED` | User lacks capability | Use admin account or check capability requirements |
| `TIMEOUT` | Request took >30s | Increase timeout with `--timeout 60` |

### Error Output (JSON)

```json
{
  "success": false,
  "error": {
    "code": "NONCE_INVALID",
    "message": "Nonce verification failed",
    "details": {
      "action": "my_ajax_action",
      "nonce_used": "abc123"
    }
  },
  "suggestions": [
    "Re-authenticate to get fresh nonce",
    "Check if user is logged in",
    "Verify nonce field name matches server expectation"
  ]
}
```

---

## AI Agent Instructions

### When to Use wp-ajax-test

**Triggers**:
- User says: "test this AJAX endpoint", "debug AJAX", "check if AJAX works"
- After WPCC flags AJAX security issues
- Before deploying AJAX changes
- Debugging AJAX failures in logs

**Don't use when**:
- Full browser interaction needed → Use Playwright
- Testing frontend UI behavior → Use Playwright
- Load testing → Use Apache Bench, k6

### Workflow

```
1. Identify endpoint details from code
   ├─ Action name (e.g., 'my_ajax_action')
   ├─ Expected data payload
   └─ Admin vs. nopriv

2. Check for auth file
   ├─ If exists: Use temp/auth.json
   └─ If missing: Ask user for credentials, save to temp/

3. Run test (call centrally)
   └─ wp-ajax-test --url <site> --action <action> --format json

4. Analyze response
   ├─ If success: Report results
   ├─ If error: Check error code, suggest fixes
   └─ If auth issue: Re-authenticate

5. Optional: Create local wrapper if repeated testing needed
```

### Centralized vs. Local Copy Decision Tree

```
User Request
    │
    ├─ One-off test ──────────────────► Call centrally
    │
    ├─ Debugging single endpoint ─────► Call centrally
    │
    ├─ Multiple endpoints to test ────► Ask: "Create local wrapper for batch testing?"
    │
    ├─ Project-specific auth ─────────► Create local wrapper with defaults
    │
    └─ Repeated testing needed ───────► Create local wrapper + batch file
```

### Creating Local Wrapper (When Needed)

**AI agent should**:
1. ✅ Create wrapper script in project root
2. ✅ Add to `.gitignore` immediately
3. ✅ Document in project README or `/temp/README.md`
4. ✅ Use `/temp` for auth files
5. ❌ Never commit wrapper with hardcoded credentials
6. ❌ Never install wp-ajax-test per-project (call centrally)

**Example AI response**:
> "I'll create a local wrapper for easier testing. This calls the centralized tool with your project defaults."

```bash
# AI creates this
cat > test-ajax.sh <<'EOF'
#!/bin/bash
# Wrapper for wp-ajax-test with project defaults
~/bin/ai-ddtk/bin/wp-ajax-test \
  --url "https://yoursite.local" \
  --auth "temp/auth.json" \
  "$@"
EOF
chmod +x test-ajax.sh
echo "test-ajax.sh" >> .gitignore
```

---

## Implementation Checklist

### Phase 1: Core Tool
- [ ] Create `~/bin/ai-ddtk/bin/wp-ajax-test` executable
- [ ] Implement basic AJAX request (action, data, URL)
- [ ] Add authentication (login, nonce extraction, cookie storage)
- [ ] JSON output format
- [ ] Error handling with suggestions
- [ ] Add to AI-DDTK PATH

### Phase 2: AI Orchestration
- [ ] Add "AJAX Endpoint Testing" section to AGENTS.md
- [ ] Create `recipes/ajax-testing.md` workflow
- [ ] Add to SYSTEM-INSTRUCTIONS.md
- [ ] Document centralized vs. local copy decision tree
- [ ] Add examples to README.md

### Phase 3: Advanced Features
- [ ] Batch testing (`--batch` flag)
- [ ] Assertion support (expect conditions)
- [ ] REST API endpoint support
- [ ] Request/response logging
- [ ] Integration with WPCC (test flagged endpoints)

### Phase 4: MCP Integration (Future)
- [ ] Expose as MCP tool: `wp_ajax_test`
- [ ] Structured input/output via MCP protocol
- [ ] Auto-discovery by AI agents

---

## Dependencies

**Required**:
- Node.js 14+ (already required by AI-DDTK)
- `axios` for HTTP requests (add to AI-DDTK package.json)

**Optional**:
- `cheerio` for HTML parsing (nonce extraction)
- `tough-cookie` for cookie management

**Installation**:
```bash
cd ~/bin/ai-ddtk
npm install axios cheerio tough-cookie
```

---

## Security Considerations

1. **Never commit auth files** - Always use `/temp` folder
2. **Validate SSL certificates** - Use `--insecure` flag only for local dev
3. **Rate limiting** - Add delay between batch requests
4. **Credential exposure** - Never log passwords/cookies in verbose mode
5. **Nonce rotation** - Auto-refresh nonces when expired

---

## Future Enhancements

1. **GraphQL support** - Test WPGraphQL endpoints
2. **WebSocket testing** - For real-time features
3. **Performance profiling** - Integration with WP Performance Timer
4. **Visual diff** - Compare responses before/after changes
5. **Mock server** - Test without live WordPress instance
6. **CI/CD integration** - GitHub Actions workflow for AJAX regression tests

---

## Related Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **WPCC** | Static analysis | Find potential AJAX security issues |
| **wp-ajax-test** | Integration testing | Verify AJAX endpoints work |
| **Performance Timer** | Runtime profiling | Measure AJAX handler performance |
| **Playwright** | E2E testing | Test full user flows with AJAX |

---

**Next Steps**: Implement Phase 1 core tool, then add AI orchestration to AGENTS.md.

