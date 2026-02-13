# WP AJAX Test - Roadmap & Technical Reference

**Version**: 1.1.0
**Status**: Phase 1 Complete
**Location**: `~/bin/ai-ddtk/tools/wp-ajax-test/`

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
6. **Minimal dependencies** - Uses Node.js built-ins + axios, cheerio, commander

---

## Current Implementation (v1.1.0)

### CLI Options

| Flag | Description | Default |
|------|-------------|---------|
| `-u, --url <url>` | WordPress site URL | **Required** |
| `-a, --action <action>` | AJAX action name | **Required** |
| `-d, --data <json>` | JSON data payload | `{}` |
| `--auth <file>` | Auth file path (JSON) | `null` |
| `-f, --format <format>` | Output format (`human` or `json`) | `human` |
| `--admin` | Use admin AJAX endpoint | `true` |
| `--nopriv` | Use nopriv AJAX endpoint | `false` |
| `-m, --method <method>` | HTTP method | `POST` |
| `-t, --timeout <ms>` | Request timeout in ms | `30000` |
| `-v, --verbose` | Verbose output (debug auth, nonce extraction) | `false` |
| `--insecure` | Skip SSL certificate verification (for `.local` sites) | `false` |
| `--nonce-url <url>` | Custom URL to fetch nonce from (relative to site URL) | `null` (defaults to `/wp-admin/`) |
| `--nonce-field <name>` | Nonce field name to look for | `_wpnonce` |

### Authentication Flow

1. Load credentials from auth file (JSON with `username` and `password`)
2. GET login page to collect initial cookies
3. POST `wp-login.php` with credentials and cookies
4. Store session cookies from response
5. Validate login via auth cookie presence or redirect status

### Auth File Format

```json
{
  "username": "admin",
  "password": "your-password"
}
```

### Nonce Extraction

Nonces are extracted automatically from WordPress pages in priority order:

1. Custom nonce field name on custom nonce URL (if `--nonce-url` and `--nonce-field` provided)
2. `input[name="_wpnonce"]` in forms
3. `input[name="_ajax_nonce"]` in forms
4. Custom field name fallback (if `--nonce-field` differs from `_wpnonce`)
5. Inline `<script>` tags via regex patterns (e.g., `wpApiSettings.nonce`)

### Output Formats

**Human-readable** (default):
```
✓ AJAX Test: my_ajax_action
  URL: https://site.local/wp-admin/admin-ajax.php
  Status: 200 OK
  Response Time: 234ms

  Response:
  {
    "success": true,
    "data": { "message": "Operation completed" }
  }
```

**JSON** (`--format json`):
```json
{
  "success": true,
  "action": "my_ajax_action",
  "url": "https://site.local/wp-admin/admin-ajax.php",
  "status_code": 200,
  "response_time_ms": 234,
  "response": { "success": true, "data": { "message": "Operation completed" } },
  "headers": { "content-type": "application/json" }
}
```

### Error Handling

Errors return structured output with error code and suggestions:

| Error Code | Trigger | Suggestions |
|------------|---------|-------------|
| `AUTH_REQUIRED` | Auth file not found | Create `temp/auth.json`, use `--auth` flag |
| `AUTH_FAILED` | Login failed | Check credentials, verify site URL |
| `CONNECTION_ERROR` | `ENOTFOUND` / `ECONNREFUSED` | Check if site is running, verify URL |
| `TIMEOUT` | Request exceeded timeout | Increase with `--timeout`, check server |

### Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `axios` | ^0.27.2 | HTTP requests with cookie/redirect control |
| `cheerio` | 1.0.0-rc.10 | HTML parsing for nonce extraction |
| `commander` | ^9.5.0 | CLI argument parsing |

---

## Implementation Checklist

### Phase 1: Core Tool — COMPLETE

- [x] Create `index.js` executable with shebang
- [x] CLI parsing via `commander` with all options
- [x] Basic AJAX request (action, data, URL)
- [x] Authentication (login flow, cookie storage)
- [x] Nonce extraction (forms, inline scripts, custom fields)
- [x] JSON and human-readable output formats
- [x] Error handling with codes and suggestions
- [x] `--insecure` flag for local dev SSL bypass
- [x] `--nonce-url` and `--nonce-field` for plugin-specific nonces
- [x] `--verbose` flag for debugging auth/nonce flow
- [x] `install.sh` script with Node.js version check and symlink setup
- [x] Add to AI-DDTK bin via symlink

### Phase 2: AI Orchestration — PARTIAL

- [x] AI-INSTRUCTIONS.md created with decision tree and examples
- [x] README.md with full usage documentation
- [ ] Add "AJAX Endpoint Testing" section to root AGENTS.md
- [ ] Create `recipes/ajax-testing.md` workflow
- [ ] Add to AGENTS.md (Workflow Triggers table)

### Phase 3: Advanced Features — NOT STARTED

- [ ] Batch testing (`--batch` flag with JSON test file)
- [ ] Assertion support (expect conditions in batch tests)
- [ ] REST API endpoint support (`--rest` mode)
- [ ] Request/response logging to file
- [ ] Integration with WPCC (test flagged endpoints automatically)

### Phase 4: MCP Integration — NOT STARTED

- [ ] Expose as MCP tool: `wp_ajax_test`
- [ ] Structured input/output via MCP protocol
- [ ] Auto-discovery by AI agents

---

## Security Considerations

1. **Never commit auth files** - Always use `/temp` folder
2. **Validate SSL certificates** - Use `--insecure` flag only for local dev
3. **Rate limiting** - Add delay between batch requests (Phase 3)
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
