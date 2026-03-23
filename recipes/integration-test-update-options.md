# Integration Test: ai-ddtk/update-options

Manual integration test steps for verifying `update-options` on a live LocalWP site.

## Prerequisites

- LocalWP site with `ai-ddtk-abilities.php` installed as an mu-plugin
- MCP Adapter enabled (`wordpress/mcp-adapter`)
- Site selected via `local_wp_select_site`

## Test 1 — Safe key round-trip

Write a WooCommerce option and verify it persists:

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/update-options",
    "params": { "updates": { "woocommerce_default_country": "US:CA" } }
  }
}
```

Then read it back:

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/get-options",
    "params": { "keys": ["woocommerce_default_country"] }
  }
}
```

**Expected:** `success: true`, value matches `"US:CA"`.

## Test 2 — Always-refused key (hard stop)

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/update-options",
    "params": { "updates": { "active_plugins": [] } }
  }
}
```

**Expected:** `success: false`, `blocked_keys: ["active_plugins"]`, error mentions WP-CLI.

## Test 3 — Dangerous key without confirm (soft stop)

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/update-options",
    "params": { "updates": { "siteurl": "https://example.local" } }
  }
}
```

**Expected:** `success: false`, `blocked_keys: ["siteurl"]`.

## Test 4 — Dangerous key with confirm + valid URL

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/update-options",
    "params": {
      "updates": { "admin_email": "test@example.com" },
      "confirm_dangerous": true
    }
  }
}
```

**Expected:** `success: true`, `dangerous_keys_present: true`.

Check PHP error log for `[AI-DDTK]` audit entry:

```bash
# Via WP-CLI:
wp eval 'echo ini_get("error_log");'
tail -5 "$(wp eval 'echo ini_get("error_log");')"
```

## Test 5 — URL validation for siteurl

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/update-options",
    "params": {
      "updates": { "siteurl": "not-a-url" },
      "confirm_dangerous": true
    }
  }
}
```

**Expected:** `success: false`, error mentions "not a valid URL".

## Test 6 — Theme validation for template

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/update-options",
    "params": {
      "updates": { "template": "nonexistent-theme-slug" },
      "confirm_dangerous": true
    }
  }
}
```

**Expected:** `success: false`, error mentions "does not match any installed theme" and lists valid slugs.

## Test 7 — Autoload hint

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/update-options",
    "params": {
      "updates": { "my_custom_option": "test_value" },
      "autoload": "no"
    }
  }
}
```

Verify autoload column via WP-CLI:

```bash
wp db query "SELECT option_name, autoload FROM wp_options WHERE option_name = 'my_custom_option';"
```

**Expected:** autoload = `no`.
