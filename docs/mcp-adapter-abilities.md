# MCP Adapter Abilities — Schema Contract Reference

> **AI-DDTK Phase 1 & 2 — Content Scaffolding, Migration & Introspection**

This document is the schema contract reference for all abilities registered by `templates/ai-ddtk-abilities.php`.

These abilities are exposed by the [WordPress MCP Adapter](https://github.com/WordPress/mcp-adapter) and can be called by AI agents (Claude Code, Augment, Cline, etc.) without browser automation. Install the mu-plugin on any WordPress 6.9+ site that has the MCP Adapter installed, then call abilities via the `mcp-adapter-execute-ability` MCP tool.

**Quick reference:**

| Ability | Phase | Description |
|---------|-------|-------------|
| `ai-ddtk/create-post` | 1 | Create posts, pages, or CPTs |
| `ai-ddtk/update-post` | 1 | Update an existing post |
| `ai-ddtk/list-posts` | 1 | List/filter posts |
| `ai-ddtk/delete-post` | 1 | Trash a post (never permanent) |
| `ai-ddtk/manage-taxonomy` | 1 | Create terms, assign terms, list terms |
| `ai-ddtk/batch-create-posts` | 1 | Bulk-create up to 100 posts |
| `ai-ddtk/batch-update-posts` | 1 | Bulk-update up to 100 posts |
| `ai-ddtk/get-options` | 2 | Read WordPress options by key or prefix |
| `ai-ddtk/list-post-types` | 2 | List registered post types |
| `ai-ddtk/list-registered-blocks` | 2 | List Gutenberg blocks |
| `ai-ddtk/get-active-theme` | 2 | Get active theme info |
| `ai-ddtk/list-plugins` | 2 | List active/inactive plugins |

---

## Phase 1 — Content Abilities

### `ai-ddtk/create-post`

Create a post, page, or custom post type entry with optional meta and taxonomy terms.

**Permission required:** `edit_posts` (and `publish_posts` when `status` is `publish`)

#### Input Schema

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `title` | string | ✅ | — | Post title |
| `post_type` | string | — | `post` | Post type slug (e.g. `post`, `page`, `product`) |
| `content` | string | — | `""` | Post body content (HTML allowed, sanitized via `wp_kses_post`) |
| `status` | string | — | `draft` | Post status: `draft`, `publish`, `pending`, `private` |
| `meta` | object | — | — | Key/value pairs for post meta |
| `terms` | object | — | — | Taxonomy → term slug/ID array mapping, e.g. `{"category": ["news", 5]}` |

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` on success |
| `id` | integer | New post ID |
| `title` | string | Saved post title |
| `status` | string | Saved post status |
| `edit_url` | string | WordPress admin edit URL |
| `error` | string | Error message (only present on failure) |

#### Example MCP Call

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/create-post",
    "params": {
      "post_type": "post",
      "title": "Hello from AI-DDTK",
      "content": "<p>This post was created by an AI agent via the MCP Adapter.</p>",
      "status": "draft",
      "meta": { "source": "ai-ddtk" },
      "terms": { "category": ["news"] }
    }
  }
}
```

**Example response:**

```json
{
  "success": true,
  "id": 42,
  "title": "Hello from AI-DDTK",
  "status": "draft",
  "edit_url": "https://example.local/wp-admin/post.php?post=42&action=edit"
}
```

---

### `ai-ddtk/update-post`

Update title, content, status, meta, or taxonomy terms on an existing post.

**Permission required:** `edit_post` (per post)

#### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | integer | ✅ | Post ID to update |
| `title` | string | — | New title |
| `content` | string | — | New content |
| `status` | string | — | New status: `draft`, `publish`, `pending`, `private`, `trash` |
| `meta` | object | — | Meta key/value pairs to update |
| `terms` | object | — | Taxonomy → term slug/ID array (replaces existing terms) |

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` on success |
| `id` | integer | Post ID |
| `title` | string | Updated title |
| `status` | string | Updated status |
| `updated_fields` | string[] | List of fields that were changed |
| `error` | string | Error message on failure |

#### Example MCP Call

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/update-post",
    "params": {
      "id": 42,
      "status": "publish",
      "meta": { "reviewed": "true" }
    }
  }
}
```

---

### `ai-ddtk/list-posts`

List posts/pages/CPTs with optional filters.

**Permission required:** `read`

#### Input Schema

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `post_type` | string | — | `post` | Post type slug |
| `status` | string | — | `any` | Post status filter |
| `taxonomy` | string | — | — | Taxonomy slug for term filtering |
| `term` | string | — | — | Term slug or ID (requires `taxonomy`) |
| `date_after` | string | — | — | ISO 8601 date — posts published after this date |
| `date_before` | string | — | — | ISO 8601 date — posts published before this date |
| `per_page` | integer | — | `20` | Results per page (max 100) |
| `page` | integer | — | `1` | Page number |

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` on success |
| `posts` | array | Array of post objects (see below) |
| `total` | integer | Total matching posts |
| `pages` | integer | Total pages |

Each post object: `{ id, title, status, post_type, date, link }`

#### Example MCP Call

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/list-posts",
    "params": {
      "post_type": "product",
      "status": "publish",
      "per_page": 10,
      "page": 1
    }
  }
}
```

---

### `ai-ddtk/delete-post`

Move a post to the trash. **Never permanently deletes** — uses `wp_trash_post()`.

**Permission required:** `delete_post` (per post)

#### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | integer | ✅ | Post ID to trash |

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` on success |
| `id` | integer | Post ID |
| `trashed` | boolean | `true` |
| `error` | string | Error message on failure |

#### Example MCP Call

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/delete-post",
    "params": { "id": 42 }
  }
}
```

---

### `ai-ddtk/manage-taxonomy`

Create terms, assign terms to posts, or list terms for a taxonomy.

**Permission required:** `manage_categories` (for `create-term`); `edit_posts` (for `assign-terms`, `list-terms`)

#### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `action` | string | ✅ | One of: `create-term`, `assign-terms`, `list-terms` |
| `taxonomy` | string | ✅ | Taxonomy slug |
| `name` | string | ✅ for `create-term` | Term name |
| `slug` | string | — | Term slug (create-term only) |
| `parent` | integer | — | Parent term ID (create-term only) |
| `post_id` | integer | ✅ for `assign-terms` | Post to assign terms to |
| `terms` | array | ✅ for `assign-terms` | Array of term IDs or slugs |
| `append` | boolean | — | Append to existing terms? Default `true` (assign-terms only) |
| `hide_empty` | boolean | — | Exclude empty terms? Default `false` (list-terms only) |
| `per_page` | integer | — | Max terms to return, default 50 (list-terms only) |

#### Output (varies by action)

**`create-term`:** `{ success, term_id, name, taxonomy }`

**`assign-terms`:** `{ success, post_id, taxonomy, assigned_term_ids[] }`

**`list-terms`:** `{ success, taxonomy, terms: [{ term_id, name, slug, count, parent }], count }`

---

### `ai-ddtk/batch-create-posts`

Create multiple posts in one call. Capped at 100 items.

**Permission required:** `edit_posts`

#### Input Schema

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `posts` | array | ✅ | — | Array of post objects (same fields as `create-post`) |
| `post_type` | string | — | `post` | Default post type applied to items that don't specify one |

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` always (per-item errors in `results`) |
| `created` | integer | Count of successfully created posts |
| `failed` | integer | Count of failed posts |
| `results` | array | Per-item results: `{ index, id?, title, status, error? }` |

#### Example MCP Call

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/batch-create-posts",
    "params": {
      "post_type": "post",
      "posts": [
        { "title": "Test Post 1", "status": "draft" },
        { "title": "Test Post 2", "content": "<p>Body text</p>", "status": "draft" }
      ]
    }
  }
}
```

**Example response:**

```json
{
  "success": true,
  "created": 2,
  "failed": 0,
  "results": [
    { "index": 0, "id": 101, "title": "Test Post 1", "status": "draft" },
    { "index": 1, "id": 102, "title": "Test Post 2", "status": "draft" }
  ]
}
```

---

### `ai-ddtk/batch-update-posts`

Update multiple existing posts in one call. Each item must include `id`. Capped at 100 items. Permission is validated per post.

**Permission required:** `edit_posts` (globally) + `edit_post` per item

#### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `updates` | array | ✅ | Array of update objects — same fields as `update-post`, each must include `id` |

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` always (per-item errors in `results`) |
| `updated` | integer | Count of successfully updated posts |
| `failed` | integer | Count of failed updates |
| `results` | array | Per-item results: `{ id, status, updated_fields[]?, error? }` |

---

## Phase 2 — Introspection Abilities

### `ai-ddtk/get-options`

Read WordPress options by exact key array or prefix match.

**Permission required:** `manage_options`

#### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `keys` | string[] | — | Array of exact option names |
| `prefix` | string | — | Return all options with names starting with this prefix |
| `include_autoload` | boolean | — | Include non-autoloaded options in prefix query (default `true`) |

At least one of `keys` or `prefix` is required.

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` on success |
| `options` | object | Key/value map of option name → value |
| `count` | integer | Number of options returned |

#### Example MCP Call

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/get-options",
    "params": {
      "keys": ["blogname", "blogdescription", "siteurl"],
      "prefix": "woocommerce_"
    }
  }
}
```

---

### `ai-ddtk/list-post-types`

Return all registered post types with labels, supports, and capabilities.

**Permission required:** `read`

#### Input Schema

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `public_only` | boolean | — | `false` | Return only publicly queryable post types |

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` on success |
| `post_types` | array | Array of post type objects |
| `count` | integer | Total count |

Each post type object:

```json
{
  "name": "post",
  "label": "Posts",
  "singular_label": "Post",
  "public": true,
  "has_archive": false,
  "supports": ["title", "editor", "author", "thumbnail", "excerpt", "comments", "revisions"],
  "capabilities": { "edit_post": "edit_post", "read_post": "read_post", ... }
}
```

---

### `ai-ddtk/list-registered-blocks`

Return all registered Gutenberg blocks, optionally filtered by namespace.

**Permission required:** `read`

#### Input Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `namespace` | string | — | Filter by block namespace (e.g. `core`, `my-plugin`) |

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` on success |
| `blocks` | array | Array of block objects |
| `count` | integer | Total count |

Each block object: `{ name, title, category, is_dynamic }`

#### Example MCP Call

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/list-registered-blocks",
    "params": { "namespace": "woocommerce" }
  }
}
```

---

### `ai-ddtk/get-active-theme`

Return active theme information. Full details require `switch_themes` capability; gracefully degrades to name + version for read-only users.

**Permission required:** `read` (full details require `switch_themes`)

#### Input Schema

No input parameters.

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` on success |
| `name` | string | Theme name |
| `version` | string | Theme version |
| `template` | string | Template directory (parent theme name if child) — requires `switch_themes` |
| `stylesheet` | string | Stylesheet directory — requires `switch_themes` |
| `author` | string | Theme author — requires `switch_themes` |
| `theme_uri` | string | Theme URI — requires `switch_themes` |
| `is_child_theme` | boolean | `true` if active theme is a child theme — requires `switch_themes` |
| `parent_theme` | string\|null | Parent theme name (if child theme) — requires `switch_themes` |

#### Example MCP Call

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/get-active-theme",
    "params": {}
  }
}
```

**Example response (admin user):**

```json
{
  "success": true,
  "name": "Storefront",
  "version": "4.5.0",
  "template": "storefront",
  "stylesheet": "storefront",
  "author": "WooCommerce",
  "theme_uri": "https://woocommerce.com/storefront/",
  "is_child_theme": false,
  "parent_theme": null
}
```

---

### `ai-ddtk/list-plugins`

Return active and/or inactive plugins with version, author, and status.

**Permission required:** `activate_plugins`

#### Input Schema

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `status` | string | — | `all` | Filter: `active`, `inactive`, or `all` |

#### Output Schema

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` on success |
| `plugins` | array | Array of plugin objects |
| `active_count` | integer | Total active plugins |
| `inactive_count` | integer | Total inactive plugins |

Each plugin object: `{ file, name, version, status, author, plugin_uri }`

#### Example MCP Call

```json
{
  "tool": "mcp-adapter-execute-ability",
  "arguments": {
    "ability_name": "ai-ddtk/list-plugins",
    "params": { "status": "active" }
  }
}
```

---

## Decision Tree — When to Use MCP Adapter vs. pw-auth

Use this decision tree when choosing between the MCP Adapter and pw-auth (Playwright) for a verification or operation task.

```
Is the task about visual appearance, DOM layout, or UI state?
├── YES → Use pw-auth (Playwright)
│         Examples: Screenshot comparisons, CSS debugging,
│         form interaction, wizard flows, visual regression
│
└── NO → Is the task reading or writing WordPress data?
         ├── YES → Is the data accessible via a registered ability?
         │         ├── YES → Use MCP Adapter ✅ (faster, schema-validated)
         │         │         Examples: reading options, listing posts,
         │         │         creating content, checking plugin status
         │         └── NO  → Does it require a custom WP-CLI command?
         │                   ├── YES → Use local_wp_run (AI-DDTK MCP Server)
         │                   └── NO  → Use pw-auth for wp-admin UI
         │
         └── NO → Is it an AJAX endpoint test?
                  ├── YES → Use wp-ajax-test (AI-DDTK MCP Server)
                  └── NO  → Use local_wp_run for arbitrary WP-CLI commands
```

### Rule of Thumb

| Use | When |
|-----|------|
| **MCP Adapter abilities** | Data reads/writes with known schema: options, posts, plugins, blocks, themes, taxonomies |
| **pw-auth + Playwright** | Visual verification, DOM inspection, UI workflows, anything that requires "seeing the page" |
| **local_wp_run** | Arbitrary WP-CLI commands, database queries, file operations |
| **wp-ajax-test** | Testing `admin-ajax.php` or REST API endpoints directly |

### Phase 2 `verify-via-mcp` Strategy

In fix-iterate loops, use MCP Adapter abilities as the **verify step** instead of Playwright for data checks:

```
Fix → Execute → Verify via MCP Adapter → Pass/Fail → Iterate
```

Preferred verify abilities for common plugin fix-iterate scenarios:

| Scenario | Use Ability |
|----------|-------------|
| Did the plugin save its settings? | `ai-ddtk/get-options` with the plugin's option prefix |
| Is the plugin active after activation? | `ai-ddtk/list-plugins` with `status: active` |
| Did the block register successfully? | `ai-ddtk/list-registered-blocks` with the plugin's namespace |
| Did a post import complete? | `ai-ddtk/list-posts` with `post_type` and `status` filters |
| Is the correct theme active? | `ai-ddtk/get-active-theme` |

This replaces slow Playwright page loads with direct PHP execution via WP-CLI — typically 10–50× faster per verify cycle.

---

## Related

- [templates/ai-ddtk-abilities.php](../templates/ai-ddtk-abilities.php) — The mu-plugin source
- [recipes/seed-test-content.md](../recipes/seed-test-content.md) — Seeding test content recipe
- [WordPress MCP Adapter](https://github.com/WordPress/mcp-adapter) — Upstream package
- [fix-iterate-loop.md](../fix-iterate-loop.md) — Fix-Iterate Loop pattern
