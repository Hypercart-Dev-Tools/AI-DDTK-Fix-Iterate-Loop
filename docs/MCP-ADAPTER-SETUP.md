# MCP Adapter Setup Guide — Local by Flywheel

> Practical step-by-step guide for provisioning the WordPress MCP Adapter + AI-DDTK abilities on a Local by Flywheel dev site. Covers everything you need to get from zero to all 12 abilities live, including every gotcha discovered during real-world validation.
>
> For Valet clone-lab setup, see the comparison table in [P1-WP-MCP-ADAPTER.md](../PROJECT/2-WORKING/P1-WP-MCP-ADAPTER.md#phase-0--technical-spike). Steps 2–5 are identical; only the WP-CLI invocation style differs.

> **Public repo hygiene:** Treat real site names, internal domains, local filesystem paths, user IDs, and auth details as environment-specific data. Keep the checked-in `.mcp.json` generic and store local-only MCP variants or working snippets under `temp/` rather than committing them.

> **Local helper option:** This repo ships with `.mcp.local.example.json` as a tracked placeholder and `./bin/mcp-local-config` to merge the generic checked-in `.mcp.json` with local-only snippets from `temp/mcp/local-snippets/`.

---

## Prerequisites

| Requirement | Minimum | Notes |
|---|---|---|
| **WordPress** | **6.9+** | Abilities API ships in WP 6.9 core. Run `./bin/local-wp <site> core version` to check. |
| **WP-CLI** | **2.9+** | Required for the `mcp-adapter serve` STDIO subcommand. Already bundled in Local's PHP environment. |
| **Composer** | **2.x** | System Composer (Homebrew) works fine — no need to route through Local's PHP for the install step. |
| **Site running** | — | The Local site must be started in the Local app before any `bin/local-wp` commands will connect. |

---

## Setup Steps

### Step 1 — Verify WP version

```bash
./bin/local-wp <site-name> core version
# Expected: 6.9.x or higher
```

If the site is on WP < 6.9, update it in the Local app before proceeding.

---

### Step 2 — Install the MCP Adapter package via Composer

Run this from inside the site's WordPress root (where `wp-config.php` lives):

```bash
cd "/Users/<you>/Local Sites/<site-name>/app/public"
composer require wordpress/mcp-adapter
```

This creates `composer.json` + `composer.lock` and installs the package into `vendor/wordpress/mcp-adapter/`.

> **Why system Composer is fine here:** Composer is only downloading and organizing PHP files. The actual PHP execution happens via Local's bundled PHP binary when WP-CLI runs — the two don't need to match for the install step.

---

### Step 3 — Generate the adapter's own autoloader (critical workaround)

The MCP Adapter has no runtime Composer dependencies, so its own `vendor/autoload.php` is **not** auto-generated during Step 2. Without it, the `WP\MCP\Plugin` class never loads and the `mcp-adapter` WP-CLI command is never registered.

```bash
cd "/Users/<you>/Local Sites/<site-name>/app/public/vendor/wordpress/mcp-adapter"
composer install --no-interaction
```

This generates `vendor/wordpress/mcp-adapter/vendor/autoload.php`. You only need to do this once per site.

> **Verify it worked:**
> ```bash
> cd "/Users/<you>/Documents/GH Repos/AI-DDTK"
> ./bin/local-wp <site-name> mcp-adapter list
> ```
> Expected output: one row showing `mcp-adapter-default-server` with 3 tools. If the command is not found, the autoloader is missing or the mu-plugin loader (Step 4) hasn't been deployed.

---

### Step 4 — Deploy the mu-plugin loader

The MCP Adapter package needs to be explicitly bootstrapped because WordPress doesn't autoload Composer packages. Create this file:

**`wp-content/mu-plugins/load-mcp-adapter.php`:**

```php
<?php
/**
 * MU-Plugin: Load WordPress MCP Adapter
 * Bootstraps the MCP Adapter from the Composer vendor directory.
 */
$_ai_ddtk_adapter = ABSPATH . 'vendor/wordpress/mcp-adapter/mcp-adapter.php';
if ( file_exists( $_ai_ddtk_adapter ) ) {
    require_once $_ai_ddtk_adapter;
}
unset( $_ai_ddtk_adapter );
```

---

### Step 5 — Deploy the AI-DDTK abilities mu-plugin

Copy `templates/ai-ddtk-abilities.php` from the AI-DDTK repo into the site's mu-plugins:

```bash
cp "/Users/<you>/Documents/GH Repos/AI-DDTK/templates/ai-ddtk-abilities.php" \
   "/Users/<you>/Local Sites/<site-name>/app/public/wp-content/mu-plugins/ai-ddtk-abilities.php"
```

This registers all 12 Phase 1 + Phase 2 abilities (`ai-ddtk/create-post`, `ai-ddtk/get-options`, etc.).

---

### Step 6 — Add to `.mcp.json`

Add the site's adapter server alongside the existing `ai-ddtk` server in `.mcp.json` at the root of the AI-DDTK repo:

```json
{
  "mcpServers": {
    "ai-ddtk": {
      "command": "bash",
      "args": ["tools/mcp-server/start.sh"]
    },
    "wordpress-<site-name>": {
      "command": "./bin/local-wp",
      "args": ["<site-name>", "mcp-adapter", "serve",
               "--server=mcp-adapter-default-server", "--user=1"]
    }
  }
}
```

**Important:** Use `--user=1` (numeric user ID), not `--user=admin`. Admin usernames vary per site (e.g. an email address on some imports); the user ID `1` is always the first admin.

**Commit hygiene:** This adapter entry is meant for your local machine. Do not commit a real `<site-name>`, internal hostname, or user mapping into the public repo's checked-in `.mcp.json`.

If you want to keep your real adapter entries out of the tracked `.mcp.json`, store them as JSON snippets under `temp/mcp/local-snippets/` and generate a local merged config with:

```bash
./bin/mcp-local-config --write .mcp.local.json
```

See `examples/mcp/local-snippet.example.json` for the exact snippet format.

If you deliberately want to write the merged local config back into the repo-root `.mcp.json`, use the helper's guarded mode and acknowledge the warning prompt:

```bash
printf 'OVERWRITE\n' | ./bin/mcp-local-config --write-root
```

---

### Step 7 — Restart Claude Code

Claude Code reads `.mcp.json` at startup. After saving the file, **restart Claude Code** (or reload the window) to connect the new MCP server. Once connected, you'll have three new tools available:

- `mcp-adapter-discover-abilities` — list all registered abilities
- `mcp-adapter-get-ability-info` — inspect a specific ability's schema
- `mcp-adapter-execute-ability` — call any ability

---

## Verification Checklist

```bash
# 1. Adapter command registered
./bin/local-wp <site-name> mcp-adapter list
# → One row: mcp-adapter-default-server | 3 tools

# 2. All 12 AI-DDTK abilities discoverable (run after Claude Code restart)
# In Claude: use mcp-adapter-discover-abilities → should list all 12 ai-ddtk/* abilities

# 3. Quick smoke test via raw JSON-RPC (without restarting Claude Code)
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-discover-abilities","arguments":{}}}' \
  | ./bin/local-wp <site-name> mcp-adapter serve --server=mcp-adapter-default-server --user=1 2>/dev/null
```

---

## Calling Abilities

Use `mcp-adapter-execute-ability` with these two fields:

| Field | Type | Description |
|---|---|---|
| `ability_name` | string | Full ability name, e.g. `ai-ddtk/create-post` |
| `parameters` | object | Input parameters matching the ability's schema |

> **Note:** The key is `parameters`, not `params`. The MCP Adapter's input schema requires this exact key name.

**Example — create a draft post:**

```json
{
  "ability_name": "ai-ddtk/create-post",
  "parameters": {
    "title": "My Test Post",
    "post_type": "post",
    "status": "draft",
    "content": "<p>Hello from AI-DDTK.</p>",
    "meta": { "source": "ai-ddtk" }
  }
}
```

**Example — list active plugins:**

```json
{
  "ability_name": "ai-ddtk/list-plugins",
  "parameters": { "status": "active" }
}
```

For the full ability schema reference, see [docs/mcp-adapter-abilities.md](mcp-adapter-abilities.md).

---

## Known Issues & Gotchas

### Abilities with no parameters must omit `input_schema`

**Affected ability:** `ai-ddtk/get-active-theme`

**Symptom:** Calling with `"parameters": {}` returns `"input is not of type object"`.

**Root cause:** `ExecuteAbilityAbility.php` uses `empty($input['parameters'])` to normalize the input, and in PHP, `empty([])` is `true` — so the empty object `{}` (JSON-decoded to `[]`) becomes `null`. WordPress's `rest_validate_value_from_schema(null, {type: object}, ...)` then correctly rejects `null`.

**Fix (already applied):** Abilities that take no parameters must omit the `input_schema` key entirely from their `wp_register_ability()` call. WordPress core correctly handles `null` input when no schema is defined. Do **not** use `'input_schema' => ['type' => 'object', 'properties' => new stdClass()]` for no-param abilities — this pattern triggers both this bug and a secondary `"Cannot use object of type stdClass as array"` error.

**Workaround for custom abilities:** If you're writing your own no-parameter ability, omit `input_schema`:

```php
// ✅ Correct — no input_schema for abilities that take no parameters
wp_register_ability( 'my-plugin/my-ability', [
    'label'               => 'My Ability',
    'category'            => 'site',
    'meta'                => ['mcp' => ['public' => true]],
    'execute_callback'    => function () { return ['result' => 'value']; },
    'permission_callback' => function () { return current_user_can('read'); },
]);

// ❌ Broken — stdClass triggers validator bug in ExecuteAbilityAbility v0.4.1
wp_register_ability( 'my-plugin/my-ability', [
    ...
    'input_schema' => ['type' => 'object', 'properties' => new stdClass()],
    ...
]);
```

---

### The `mcp-adapter` WP-CLI command is not found

This means the autoloader from Step 3 is missing. Re-run:

```bash
cd "/Users/<you>/Local Sites/<site-name>/app/public/vendor/wordpress/mcp-adapter"
composer install --no-interaction
```

---

### Abilities register but don't appear in `discover-abilities`

Check that the mu-plugin sets all three required fields:

1. **Hook:** `add_action('wp_abilities_api_init', function() { ... });`
2. **Category:** `'category' => 'site'` (or `'user'`, `'mcp-adapter'`)
3. **MCP flag:** `'meta' => ['mcp' => ['public' => true]]`

Without `meta.mcp.public === true`, the MCP Adapter's default server hides the ability.

---

### `--user=admin` fails to find the user

Use `--user=1` instead. The numeric user ID is portable across all sites; the username varies.

---

## File Layout After Setup

```
wp-content/
  mu-plugins/
    load-mcp-adapter.php          ← Step 4 — bootstraps MCP Adapter
    ai-ddtk-abilities.php         ← Step 5 — registers Phase 1+2 abilities

vendor/
  wordpress/
    mcp-adapter/
      vendor/autoload.php         ← Generated by Step 3 (nested composer install)
      mcp-adapter.php             ← Main entry point loaded by load-mcp-adapter.php
      ...
  autoload.php                    ← Generated by Step 2 (standard site-level autoload)

composer.json                     ← Created by Step 2
composer.lock                     ← Created by Step 2
```

---

## Related

- [docs/mcp-adapter-abilities.md](mcp-adapter-abilities.md) — Full ability schema contract reference
- [.mcp.README.md](../.mcp.README.md) — `.mcp.json` dual-server config reference
- [templates/ai-ddtk-abilities.php](../templates/ai-ddtk-abilities.php) — The mu-plugin source
- [recipes/seed-test-content.md](../recipes/seed-test-content.md) — Content seeding recipe using these abilities
- [PROJECT/2-WORKING/P1-WP-MCP-ADAPTER.md](../PROJECT/2-WORKING/P1-WP-MCP-ADAPTER.md) — Full implementation spec and phase history
