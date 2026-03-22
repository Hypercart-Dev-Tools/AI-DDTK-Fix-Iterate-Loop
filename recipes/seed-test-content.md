# Recipe: Seed Test Content for Plugin Development

> Use AI agents to rapidly seed, verify, and tear down WordPress test content via the MCP Adapter — no browser required.

## When to Use

- Seeding WooCommerce test products before a fix-iterate loop
- Populating a staging/dev site with representative blog posts for testing themes or plugins
- Creating structured test data (posts + meta + taxonomy terms) in a single agent call
- Tearing down test content cleanly after a session without going through wp-admin

---

## Prerequisites

1. **WordPress 6.9+** — The Abilities API (`wp_register_ability()`) is a WordPress 6.9 core feature
2. **MCP Adapter installed** — `wordpress/mcp-adapter` via Composer on the target site
3. **Abilities mu-plugin in place** — Copy `templates/ai-ddtk-abilities.php` to `wp-content/mu-plugins/ai-ddtk-abilities.php` on the target site
4. **MCP Adapter added to `.mcp.json`** — See the dual-server config in `PROJECT/2-WORKING/P1-WP-MCP-ADAPTER.md`

### Quick install check

```bash
# Verify the MCP Adapter is available and abilities are registered
./bin/local-wp <site-name> mcp-adapter list
```

Expected output includes `ai-ddtk/batch-create-posts`, `ai-ddtk/list-posts`, and `ai-ddtk/delete-post`.

---

## Step-by-Step Workflow

### Step 1 — Seed posts with `ai-ddtk/batch-create-posts`

Call the ability with an array of post objects. The agent can generate these from a specification, a JSON fixture file, or dynamically based on the task.

**MCP request:**

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/batch-create-posts",
    "params": {
      "post_type": "post",
      "posts": [
        {
          "title": "Test Post: Feature Alpha",
          "content": "<p>Testing the Alpha feature integration.</p>",
          "status": "publish",
          "meta": { "test_run": "session-001", "test_type": "integration" },
          "terms": { "category": ["testing"] }
        },
        {
          "title": "Test Post: Feature Beta",
          "content": "<p>Testing the Beta feature integration.</p>",
          "status": "publish",
          "meta": { "test_run": "session-001", "test_type": "integration" },
          "terms": { "category": ["testing"] }
        },
        {
          "title": "Test Post: Edge Case Empty Content",
          "status": "draft"
        }
      ]
    }
  }
}
```

**Expected response:**

```json
{
  "success": true,
  "created": 3,
  "failed": 0,
  "results": [
    { "index": 0, "id": 101, "title": "Test Post: Feature Alpha", "status": "publish" },
    { "index": 1, "id": 102, "title": "Test Post: Feature Beta", "status": "publish" },
    { "index": 2, "id": 103, "title": "Test Post: Edge Case Empty Content", "status": "draft" }
  ]
}
```

**Agent note:** Save the returned IDs (e.g. `[101, 102, 103]`) for use in the verify and teardown steps.

---

### Step 2 — Verify with `ai-ddtk/list-posts`

Confirm the seeded posts are present and have the expected status.

**MCP request:**

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/list-posts",
    "params": {
      "post_type": "post",
      "status": "publish",
      "taxonomy": "category",
      "term": "testing",
      "per_page": 20
    }
  }
}
```

**Expected response:**

```json
{
  "success": true,
  "posts": [
    { "id": 101, "title": "Test Post: Feature Alpha", "status": "publish", "post_type": "post", "date": "2026-03-22 20:00:00", "link": "https://example.local/test-post-feature-alpha/" },
    { "id": 102, "title": "Test Post: Feature Beta", "status": "publish", "post_type": "post", "date": "2026-03-22 20:00:01", "link": "https://example.local/test-post-feature-beta/" }
  ],
  "total": 2,
  "pages": 1
}
```

**Fix-Iterate Loop verify pattern:**

```
ITERATION 1:
1. What I'm testing: Seeded posts are published with correct taxonomy term
2. Expected: 2 posts in "testing" category with status=publish
3. Actual: 2 posts returned ✅
4. Status: ✅ PASS
```

---

### Step 3 — Run your fix-iterate loop

With test content in place, execute your plugin fix or feature and iterate. Use the verify step from Step 2 to confirm state after each change.

For plugin settings verification, combine with introspection abilities:

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/get-options",
    "params": { "prefix": "my_plugin_" }
  }
}
```

---

### Step 4 — Tear down with `ai-ddtk/delete-post`

Trash each test post by ID when the session is complete. Note that `delete-post` **trashes only** — it never permanently deletes.

**Option A — Trash posts one at a time:**

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/delete-post",
    "params": { "id": 101 }
  }
}
```

**Option B — Bulk trash via `batch-update-posts` (set status to trash):**

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/batch-update-posts",
    "params": {
      "updates": [
        { "id": 101, "status": "trash" },
        { "id": 102, "status": "trash" },
        { "id": 103, "status": "trash" }
      ]
    }
  }
}
```

**Expected response:**

```json
{
  "success": true,
  "updated": 3,
  "failed": 0,
  "results": [
    { "id": 101, "status": "trash", "updated_fields": ["status"] },
    { "id": 102, "status": "trash", "updated_fields": ["status"] },
    { "id": 103, "status": "trash", "updated_fields": ["status"] }
  ]
}
```

**Verify teardown:**

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/list-posts",
    "params": {
      "post_type": "post",
      "status": "publish",
      "taxonomy": "category",
      "term": "testing"
    }
  }
}
```

Expected: `{ "total": 0, "posts": [] }`

---

## WooCommerce Product Variant

For WooCommerce test products, change `post_type` to `product`:

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/batch-create-posts",
    "params": {
      "post_type": "product",
      "posts": [
        {
          "title": "Test Widget A",
          "status": "publish",
          "meta": {
            "_price": "19.99",
            "_regular_price": "19.99",
            "_stock_status": "instock",
            "_manage_stock": "no"
          },
          "terms": { "product_cat": ["test-products"] }
        },
        {
          "title": "Test Widget B",
          "status": "publish",
          "meta": {
            "_price": "29.99",
            "_regular_price": "29.99",
            "_stock_status": "instock",
            "_manage_stock": "no"
          },
          "terms": { "product_cat": ["test-products"] }
        }
      ]
    }
  }
}
```

**Note:** WooCommerce product meta keys (`_price`, `_regular_price`, etc.) are managed by WooCommerce hooks. Setting them via `update_post_meta` directly works for basic products but may not trigger stock/pricing caches. For full WooCommerce product creation with proper indexing, consider using the WooCommerce REST API or `wc_create_product()` via WP-CLI eval.

---

## Full Session Example

Here is a condensed fix-iterate session using this recipe:

```
AGENT SESSION — Plugin fix: Verify post meta saves correctly

1. Seed 5 test posts (batch-create-posts) → IDs [201-205]
2. Execute: Activate/update the plugin
3. Verify: list-posts to confirm posts exist, get-options to check plugin settings
4. FAIL: _my_meta key missing → check plugin code
5. Fix: Update meta key name in plugin
6. Verify: Trigger post update via update-post, then list-posts + get-options
7. PASS: Meta key present
8. Teardown: batch-update-posts with status=trash for IDs [201-205]
9. Verify teardown: list-posts returns total=0
```

Guardrails: Stop after 5 failed iterations. See [fix-iterate-loop.md](../fix-iterate-loop.md).

---

## Tips

- **Tag your test content** — use a consistent `meta` key (e.g. `"test_run": "session-id"`) so you can identify and tear down test posts reliably
- **Use draft status for non-public tests** — `"status": "draft"` keeps test content out of the public feed
- **Batch size limit** — `batch-create-posts` and `batch-update-posts` are capped at 100 items per call; split larger seeds into multiple calls
- **Category pre-creation** — if the `testing` category doesn't exist, create it first with `ai-ddtk/manage-taxonomy` (`action: create-term`)

---

## Related

- [docs/mcp-adapter-abilities.md](../docs/mcp-adapter-abilities.md) — Full schema reference for all abilities
- [fix-iterate-loop.md](../fix-iterate-loop.md) — The Fix-Iterate Loop pattern
- [PROJECT/2-WORKING/P1-WP-MCP-ADAPTER.md](../PROJECT/2-WORKING/P1-WP-MCP-ADAPTER.md) — MCP Adapter integration plan
