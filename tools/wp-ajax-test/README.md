# WP AJAX Test

Lightweight WordPress AJAX endpoint testing without browser automation.

Part of [AI-DDTK](../../README.md) (AI Driven Development ToolKit).

---

## Installation

### Centralized (Recommended)

```bash
# Install dependencies
cd ~/bin/ai-ddtk/tools/wp-ajax-test
npm install

# Link to AI-DDTK bin
ln -sf ~/bin/ai-ddtk/tools/wp-ajax-test/index.js ~/bin/ai-ddtk/bin/wp-ajax-test
chmod +x ~/bin/ai-ddtk/bin/wp-ajax-test

# Verify installation
wp-ajax-test --version
```

---

## Quick Start

### 1. Create Auth File

```bash
# In your project
mkdir -p temp
cat > temp/auth.json <<'EOF'
{
  "username": "admin",
  "password": "your-password"
}
EOF

# Add to .gitignore
echo "temp/auth.json" >> .gitignore
```

### 2. Test an Endpoint

```bash
# Basic test
wp-ajax-test --url https://yoursite.local --action my_ajax_action

# With data payload
wp-ajax-test \
  --url https://yoursite.local \
  --action my_ajax_action \
  --data '{"user_id": 1, "action_type": "update"}'

# With authentication
wp-ajax-test \
  --url https://yoursite.local \
  --action my_ajax_action \
  --auth temp/auth.json

# JSON output (for AI parsing)
wp-ajax-test \
  --url https://yoursite.local \
  --action my_ajax_action \
  --auth temp/auth.json \
  --format json
```

---

## Usage

```
Usage: wp-ajax-test [options]

Options:
  -V, --version          output the version number
  -u, --url <url>        WordPress site URL (required)
  -a, --action <action>  AJAX action name (required)
  -d, --data <json>      JSON data payload (default: "{}")
  --auth <file>          Auth file path (JSON)
  -f, --format <format>  Output format (human|json) (default: "human")
  --admin                Use admin AJAX endpoint (default: true)
  --nopriv               Use nopriv AJAX endpoint
  -m, --method <method>  HTTP method (default: "POST")
  -t, --timeout <ms>     Request timeout in ms (default: "30000")
  -v, --verbose          Verbose output
  -h, --help             display help for command
```

---

## Examples

### Test Admin AJAX Endpoint

```bash
wp-ajax-test \
  --url https://site.local \
  --action get_user_data \
  --data '{"user_id": 1}' \
  --auth temp/auth.json
```

### Test Frontend (nopriv) Endpoint

```bash
wp-ajax-test \
  --url https://site.local \
  --action public_search \
  --data '{"query": "test"}' \
  --nopriv
```

### Get JSON Output for AI Parsing

```bash
wp-ajax-test \
  --url https://site.local \
  --action my_ajax_action \
  --auth temp/auth.json \
  --format json | jq '.response.success'
```

---

## Auth File Format

```json
{
  "username": "admin",
  "password": "your-password"
}
```

**Security**:
- Always store in `/temp` folder
- Add to `.gitignore`
- Never commit to git

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
  }
}
```

---

## Error Handling

Common errors and solutions:

| Error | Solution |
|-------|----------|
| `AUTH_REQUIRED` | Create `temp/auth.json` with credentials |
| `AUTH_FAILED` | Check username/password in auth file |
| `CONNECTION_ERROR` | Verify site URL and that WordPress is running |
| `TIMEOUT` | Increase timeout with `--timeout 60000` |

---

## See Also

- [SPEC.md](SPEC.md) - Complete tool specification
- [AI-INSTRUCTIONS.md](AI-INSTRUCTIONS.md) - AI agent guidance
- [../../AGENTS.md](../../AGENTS.md) - WordPress development guidelines

---

**Version**: 1.0.0  
**License**: MIT

