# AI Agent Instructions: WP AJAX Test

**For AI agents using wp-ajax-test tool**

---

## Quick Reference

```bash
# Call centrally (recommended)
~/bin/ai-ddtk/bin/wp-ajax-test --url https://site.local --action my_ajax_action --format json

# Create local wrapper (when needed)
cat > test-ajax.sh <<'EOF'
#!/bin/bash
~/bin/ai-ddtk/bin/wp-ajax-test --url "https://site.local" --auth "temp/auth.json" "$@"
EOF
chmod +x test-ajax.sh
echo "test-ajax.sh" >> .gitignore
```

---

## Decision Tree: Centralized vs. Local Copy

```
User Request
    │
    ├─ "Test this AJAX endpoint" ──────────────► Call centrally
    │
    ├─ "Debug AJAX error" ─────────────────────► Call centrally
    │
    ├─ "Test multiple endpoints" ──────────────► Ask: "Create local wrapper + batch file?"
    │
    ├─ "Set up AJAX testing for this project" ─► Create local wrapper
    │
    └─ Repeated testing needed ────────────────► Create local wrapper
```

---

## When to Call Centrally

**Always prefer centralized calls unless**:
- User explicitly asks for project-specific setup
- Multiple endpoints need testing (batch mode)
- Project has unique auth requirements
- Repeated testing will be needed

**Example**:
```bash
# User: "Test the get_user_data AJAX endpoint"
# AI: Calls centrally
~/bin/ai-ddtk/bin/wp-ajax-test \
  --url "https://site.local" \
  --action "get_user_data" \
  --data '{"user_id": 1}' \
  --auth "temp/auth.json" \
  --format json
```

---

## When to Create Local Wrapper

**Create wrapper when**:
- User says "set up testing", "create test script", "automate testing"
- Multiple endpoints to test (batch mode)
- Project-specific defaults needed (URL, auth path)
- Repeated testing expected

**Steps**:
1. ✅ Create wrapper script in project root
2. ✅ Add to `.gitignore` immediately
3. ✅ Document in `/temp/README.md` or project README
4. ✅ Use `/temp` for auth files
5. ❌ Never commit wrapper with credentials
6. ❌ Never install wp-ajax-test per-project

**Example**:
```bash
# User: "Set up AJAX testing for this project"
# AI: Creates local wrapper

cat > test-ajax.sh <<'EOF'
#!/bin/bash
# Project-specific AJAX test wrapper
# Calls centralized AI-DDTK tool with defaults

~/bin/ai-ddtk/bin/wp-ajax-test \
  --url "https://myproject.local" \
  --auth "temp/auth.json" \
  "$@"
EOF

chmod +x test-ajax.sh
echo "test-ajax.sh" >> .gitignore

# Document usage
cat >> temp/README.md <<'EOF'

## AJAX Testing

Test endpoints with: ./test-ajax.sh --action <action> --data <json>

Auth file: temp/auth.json (create if missing)
EOF
```

---

## Authentication Handling

### Check for Auth File

```bash
# AI should check first
if [ -f temp/auth.json ]; then
    # Use existing auth
    ~/bin/ai-ddtk/bin/wp-ajax-test --auth temp/auth.json ...
else
    # Ask user for credentials
    echo "Auth file not found. Need credentials for testing."
fi
```

### Create Auth File (When User Provides Credentials)

```bash
# User provides: username=admin, password=secret123
# AI creates auth file in /temp

cat > temp/auth.json <<'EOF'
{
  "username": "admin",
  "password": "secret123"
}
EOF

# Add to .gitignore if not already present
grep -q "temp/auth.json" .gitignore || echo "temp/auth.json" >> .gitignore
```

**Never**:
- ❌ Commit auth files
- ❌ Log credentials in verbose output
- ❌ Hardcode credentials in wrapper scripts

---

## Batch Testing

### When to Use Batch Mode

- User wants to test multiple endpoints
- Regression testing before deployment
- Setting up CI/CD tests

### Create Batch File

```bash
# User: "Test all AJAX endpoints in this plugin"
# AI: Creates batch test file

cat > tests/ajax-endpoints.json <<'EOF'
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
      "expect": {"success": true}
    },
    {
      "name": "Update settings",
      "action": "update_settings",
      "data": {"setting": "value"},
      "expect": {"success": true}
    }
  ]
}
EOF

# Run batch test
~/bin/ai-ddtk/bin/wp-ajax-test --batch tests/ajax-endpoints.json --format json
```

---

## Error Handling

### Common Errors and Responses

| Error Code | AI Response |
|------------|-------------|
| `AUTH_REQUIRED` | "Auth file not found. I'll create temp/auth.json. Please provide credentials." |
| `NONCE_INVALID` | "Nonce expired. Re-authenticating..." (then retry) |
| `ENDPOINT_NOT_FOUND` | "Action 'X' not registered. Check plugin is active and action name is correct." |
| `PERMISSION_DENIED` | "User lacks capability. Try with admin account or check required capability." |
| `TIMEOUT` | "Request timed out. Increase timeout with --timeout 60 or check server performance." |

### Example Error Response

```json
{
  "success": false,
  "error": {
    "code": "NONCE_INVALID",
    "message": "Nonce verification failed"
  },
  "suggestions": [
    "Re-authenticate to get fresh nonce",
    "Check if user is logged in"
  ]
}
```

**AI should**:
1. Parse error code
2. Check suggestions array
3. Attempt automatic fix (e.g., re-auth for NONCE_INVALID)
4. Report to user if can't auto-fix

---

## Integration with Other Tools

### WPCC → wp-ajax-test Pipeline

```bash
# 1. WPCC finds AJAX security issue
wpcc --paths plugin/ --format json | grep "ajax"

# 2. AI identifies flagged endpoint
# Finding: "Nonce not verified in my_ajax_action"

# 3. Test endpoint to confirm
~/bin/ai-ddtk/bin/wp-ajax-test \
  --url https://site.local \
  --action my_ajax_action \
  --format json

# 4. Report: "Confirmed: endpoint accepts requests without nonce"
```

---

## Best Practices

1. **Always call centrally first** - Only create local wrapper if needed
2. **Use /temp for auth** - Never commit credentials
3. **JSON output for parsing** - Use `--format json` when AI needs to analyze
4. **Document local wrappers** - Add usage to temp/README.md
5. **Add to .gitignore** - Immediately after creating wrapper
6. **Auto-retry on nonce errors** - Re-authenticate and retry once
7. **Validate before batch** - Test one endpoint before running full batch

---

**See**: `tools/wp-ajax-test/SPEC.md` for complete specification

