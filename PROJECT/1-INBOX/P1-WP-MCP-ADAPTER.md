---
title: "P1: WordPress MCP Adapter Integration"
status: INBOX
author: noelsaw
created: 2026-03-22
updated: 2026-03-22
project: AI-DDTK
category: feature
priority: P1
parent: null
---

<!-- TOC -->

- [Phased Checklist (High-Level Progress)](#phased-checklist-high-level-progress)
- [Overview](#overview)
- [Goals & Non-Goals](#goals--non-goals)
- [How It Complements AI-DDTK](#how-it-complements-ai-ddtk)
- [Phase 0 — Technical Spike](#phase-0--technical-spike)
- [Phase 1 — Content Scaffolding & Migration](#phase-1--content-scaffolding--migration)
- [Phase 2 — Plugin/Theme Config Verification in Fix-Iterate Loops](#phase-2--plugintheme-config-verification-in-fix-iterate-loops)
- [Phase 3 — Editorial Workflow Automation](#phase-3--editorial-workflow-automation)
- [Phase 4 — Live Site Diagnostics Without Browser Overhead](#phase-4--live-site-diagnostics-without-browser-overhead)
- [Open Questions](#open-questions)

<!-- /TOC -->

---

## Phased Checklist (High-Level Progress)

> **Note for LLM agents:** Continuously mark items off this checklist as progress is made during implementation. This section is the single source of truth for phase completion status. Update it **immediately** after completing any item — do not batch updates.

- [ ] **Phase 0 — Technical Spike** · Effort: Low · Risk: Low
  - [ ] Install Abilities API + MCP Adapter on a Local site
  - [ ] Verify STDIO transport via `local-wp <site> mcp-adapter serve`
  - [ ] Register a test ability and confirm MCP tool discovery
  - [ ] Test `.mcp.json` dual-server config (AI-DDTK + WP MCP Adapter side-by-side)
  - [ ] Document findings — update this plan with any blockers or scope changes

- [ ] **Phase 1 — Content Scaffolding & Migration** · Effort: Med · Risk: Low
  - [ ] Register content CRUD abilities (posts, pages, CPTs, taxonomies)
  - [ ] Wire abilities into AI-DDTK agent workflows
  - [ ] Validate bulk operations with permission callbacks
  - [ ] Add recipe/guide to docs

- [ ] **Phase 2 — Plugin/Theme Config Verification** · Effort: Med · Risk: Med
  - [ ] Define introspection ability patterns (get-settings, list-blocks, check-status)
  - [ ] Integrate MCP Adapter verify step into fix-iterate loop
  - [ ] Test against 2-3 real plugins on Local sites
  - [ ] Document when to use MCP Adapter vs. pw-auth for verification

- [ ] **Phase 3 — Editorial Workflow Automation** · Effort: Med-High · Risk: Med
  - [ ] Register editorial abilities (approve, assign-reviewer, schedule, SEO metadata)
  - [ ] Map ability permissions to WordPress roles (editor, author, contributor)
  - [ ] Build agent-chainable workflow sequences
  - [ ] Validate role-based access control end-to-end

- [ ] **Phase 4 — Live Site Diagnostics** · Effort: Low-Med · Risk: Low
  - [ ] Register diagnostic abilities (health checks, query stats, cron status, error log)
  - [ ] Bridge WPCC static analysis with MCP Adapter runtime checks
  - [ ] Add diagnostic abilities to AGENTS.md workflow triggers
  - [ ] Validate performance overhead is negligible

---

## Overview

[WordPress MCP Adapter](https://github.com/WordPress/mcp-adapter) is an official WordPress package that bridges the WordPress Abilities API with the Model Context Protocol (MCP). It converts WordPress abilities — standardized, reusable functions registered via `wp_register_ability()` — into MCP-compliant tools, resources, and prompts that AI agents can consume.

**Why this matters for AI-DDTK:** The toolkit currently accesses WP admin exclusively through browser automation (pw-auth + Playwright). The MCP Adapter provides a complementary **API-level** channel — faster, more reliable, and schema-validated — for data and configuration operations that don't require visual verification.

| Layer | pw-auth (Current) | MCP Adapter (Proposed) |
|---|---|---|
| **Transport** | Headless browser (Playwright) | Structured API (STDIO / HTTP) |
| **Best for** | UI testing, visual verification, DOM inspection | Data operations, content CRUD, configuration reads |
| **Speed** | Slower (browser lifecycle) | Fast (direct PHP execution via WP-CLI) |
| **Reliability** | Fragile to DOM/UI changes | Stable typed JSON schemas |
| **Auth model** | One-time login URL + session cookies | WP Application Passwords / WP-CLI `--user` |

These are complementary, not competing. The decision of which to use is clear-cut: **if you need to see the page, use pw-auth; if you need to read/write data, use MCP Adapter.**

---

## Goals & Non-Goals

### Goals

1. Enable AI-DDTK agents to perform WordPress data operations (content CRUD, settings reads, diagnostics) without browser overhead
2. Provide a second MCP server alongside the existing AI-DDTK MCP server — agents get both tool surfaces
3. Integrate MCP Adapter abilities into the fix-iterate loop as a faster verification channel
4. Support WordPress role-based permissions natively through ability permission callbacks
5. Keep the integration local-dev only, consistent with AI-DDTK's security posture

### Non-Goals

- Replacing pw-auth — browser automation remains essential for UI/visual testing
- Production deployment of MCP Adapter via HTTP transport (out of scope for AI-DDTK)
- Building a universal WordPress MCP ability library — focus on abilities that serve AI-DDTK workflows
- Modifying the MCP Adapter package itself — consume it as-is

---

## How It Complements AI-DDTK

```
                    AI Agent (Claude Code / Augment / etc.)
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                             ▼
          AI-DDTK MCP Server              WP MCP Adapter Server
          (stdio · 18 tools)              (stdio via local-wp)
          ┌──────────────┐                ┌──────────────────┐
          │ local_wp_*   │                │ Content CRUD     │
          │ wpcc_*       │                │ Config reads     │
          │ pw_auth_*    │                │ Diagnostics      │
          │ wp_ajax_test │                │ Editorial flows  │
          │ tmux_*       │                │ Custom abilities │
          └──────┬───────┘                └────────┬─────────┘
                 │                                  │
                 ▼                                  ▼
          bin/local-wp ─────────────────► WP-CLI ──► WordPress
          bin/pw-auth ──► Playwright ──► Browser ──► WordPress
```

---

## Phase 0 — Technical Spike

**Effort: Low** · **Risk: Low**

> Purpose: Validate that the WordPress MCP Adapter works with AI-DDTK's Local-by-Flywheel setup, confirm dual-server MCP configuration, and surface any blockers before committing to implementation phases. **Results from this spike should be used to update Phases 1–4 with concrete scope adjustments.**

### 0.1 — Install & Verify

- [ ] Install `wordpress/abilities-api` and `wordpress/mcp-adapter` on a test Local site via Composer
- [ ] Confirm the default MCP server starts via STDIO:
  ```bash
  local-wp <site> mcp-adapter serve --server=mcp-adapter-default-server --user=admin
  ```
- [ ] Verify the 3 built-in abilities respond (`DiscoverAbilities`, `ExecuteAbility`, `GetAbilityInfo`)
- [ ] Test the WP-CLI `mcp-adapter list` command through `local-wp`

### 0.2 — Register a Test Ability

- [ ] Create a minimal mu-plugin that registers one ability via `wp_register_ability()`:
  ```php
  wp_register_ability( 'ai-ddtk-spike/get-post-count', [
      'label'               => 'Get Post Count',
      'description'         => 'Returns total published post count',
      'input_schema'        => [ 'type' => 'object', 'properties' => new stdClass() ],
      'output_schema'       => [ 'type' => 'object', 'properties' => [
          'count' => [ 'type' => 'integer' ]
      ]],
      'execute_callback'    => function() {
          return [ 'count' => (int) wp_count_posts()->publish ];
      },
      'permission_callback' => function() {
          return current_user_can( 'read' );
      },
  ]);
  ```
- [ ] Confirm the test ability appears in `tools/list` MCP response
- [ ] Invoke the ability via MCP `tools/call` and verify the JSON response

### 0.3 — Dual-Server MCP Configuration

- [ ] Add the WP MCP Adapter as a second server in `.mcp.json` alongside AI-DDTK:
  ```json
  {
    "mcpServers": {
      "ai-ddtk": { "...existing config..." },
      "wordpress": {
        "command": "local-wp",
        "args": ["<site>", "mcp-adapter", "serve",
                 "--server=mcp-adapter-default-server", "--user=admin"]
      }
    }
  }
  ```
- [ ] Verify Claude Code discovers tools from **both** servers simultaneously
- [ ] Test for conflicts: tool name collisions, startup race conditions, stdout interleaving

### 0.4 — Document Findings

- [ ] Record any Local-by-Flywheel quirks (PHP version, Composer path, MySQL socket)
- [ ] Note Composer autoloader compatibility with Local's PHP binary
- [ ] Confirm minimum PHP/WP version requirements vs. what Local provides
- [ ] **Update Phases 1–4** in this document based on spike findings
- [ ] Decide: mu-plugin approach vs. Composer-installed plugin for ability registration

---

## Phase 1 — Content Scaffolding & Migration

**Effort: Med** · **Risk: Low**

> Use case: AI agents create, restructure, or migrate WordPress content (posts, pages, CPTs, taxonomies) through typed MCP tools instead of browser automation or raw WP-CLI.

### Who benefits

- **Content editors/writers:** "Restructure my 200 blog posts into a new taxonomy" or "Generate draft landing pages from this data" — executed programmatically with permission checks, no wp-admin clicking
- **Developers:** Seed realistic test content during plugin/theme dev as part of fix-iterate loops; schema-validated, agent-friendly alternative to manual WP-CLI

### 1.1 — Core Content Abilities

- [ ] Register `ai-ddtk/create-post` ability (supports posts, pages, custom post types)
- [ ] Register `ai-ddtk/update-post` ability (title, content, status, meta, taxonomies)
- [ ] Register `ai-ddtk/list-posts` ability (filterable by type, status, taxonomy, date range)
- [ ] Register `ai-ddtk/delete-post` ability (trash, not permanent delete)
- [ ] Register `ai-ddtk/manage-taxonomy` ability (create/assign terms, categories, tags)

### 1.2 — Bulk Operations

- [ ] Implement batch variants for create/update (accept arrays, return per-item results)
- [ ] Add progress reporting for large operations (return count/total in response)
- [ ] Validate permission callbacks enforce `edit_posts`, `publish_posts`, `delete_posts` per action

### 1.3 — Integration & Documentation

- [ ] Add content abilities to AGENTS.md workflow triggers section
- [ ] Create a recipe: "Seed test content for plugin development"
- [ ] Document schema contracts in docs/ for each ability

---

## Phase 2 — Plugin/Theme Config Verification in Fix-Iterate Loops

**Effort: Med** · **Risk: Med**

> Use case: The fix-iterate loop's "verify" step checks WordPress state (options, registered types, blocks, menus) via fast MCP calls instead of slow Playwright DOM scraping.

### Who benefits

- **Developers:** Faster iteration cycles. After a code change, call `my-plugin/get-configuration` via MCP instead of scraping a settings page. Fewer false failures from DOM selector breakage.

### 2.1 — Introspection Ability Patterns

- [ ] Register `ai-ddtk/get-options` ability (read WordPress options by key/prefix)
- [ ] Register `ai-ddtk/list-post-types` ability (registered CPTs with labels and capabilities)
- [ ] Register `ai-ddtk/list-registered-blocks` ability (Gutenberg block registry)
- [ ] Register `ai-ddtk/get-active-theme` ability (theme name, version, template hierarchy)
- [ ] Register `ai-ddtk/list-plugins` ability (active/inactive, versions)

### 2.2 — Fix-Iterate Loop Integration

- [ ] Define a `verify-via-mcp` strategy in fix-iterate-loop methodology
- [ ] Add decision logic: use MCP Adapter for data verification, pw-auth for visual verification
- [ ] Test the integrated flow on 2–3 real plugins on Local sites:
  - Plugin A: Settings page with custom options
  - Plugin B: Custom post type with meta boxes
  - Plugin C: Block-based plugin with registered blocks
- [ ] Measure speed improvement vs. equivalent Playwright verification

### 2.3 — Documentation

- [ ] Update fix-iterate-loop.md with MCP Adapter verify examples
- [ ] Add decision tree to AGENTS.md: "When to use MCP Adapter vs. pw-auth"

---

## Phase 3 — Editorial Workflow Automation

**Effort: Med-High** · **Risk: Med**

> Use case: AI agents orchestrate multi-step editorial workflows — draft review, category assignment, SEO metadata, scheduled publishing — respecting the site's WordPress role model.

### Who benefits

- **Content editors/writers:** "Review all drafts from this week, add missing meta descriptions, schedule for Tuesday" — the agent discovers abilities, checks what the user role permits, executes only allowed actions
- **Developers:** Build and test custom editorial workflow abilities that AI agents can discover and chain

### 3.1 — Editorial Abilities

- [ ] Register `ai-ddtk/get-drafts` ability (list pending/draft posts with author/date filters)
- [ ] Register `ai-ddtk/update-post-status` ability (draft → pending → publish, with role checks)
- [ ] Register `ai-ddtk/schedule-post` ability (set future publish date)
- [ ] Register `ai-ddtk/update-seo-metadata` ability (title, description, OG tags — if Yoast/RankMath/SEO plugin active)
- [ ] Register `ai-ddtk/assign-taxonomy-terms` ability (categories, tags, custom taxonomies)

### 3.2 — Role-Based Access Control Validation

- [ ] Test each ability with different WordPress roles (admin, editor, author, contributor)
- [ ] Verify `permission_callback` correctly blocks unauthorized actions:
  - Contributors cannot publish
  - Authors cannot edit others' posts
  - Editors can manage all posts but not plugin settings
- [ ] Test pw-auth multi-user sessions feeding into MCP Adapter role context
- [ ] Document role → ability permission matrix

### 3.3 — Workflow Chaining

- [ ] Build example agent workflow: "Review → Categorize → Add metadata → Schedule"
- [ ] Validate the agent can discover the full workflow via `DiscoverAbilities`
- [ ] Test error handling when a mid-chain ability is denied by permissions
- [ ] Add workflow examples to AGENTS.md

---

## Phase 4 — Live Site Diagnostics Without Browser Overhead

**Effort: Low-Med** · **Risk: Low**

> Use case: Plugins expose diagnostic abilities (health checks, query stats, cron status, error logs) as lightweight MCP tools. Closes the loop between WPCC static analysis and runtime verification.

### Who benefits

- **Developers:** After WPCC flags an unbound query, call `get-query-stats` to see actual runtime query counts on the live dev site. Static analysis + runtime verification in one MCP-native workflow.

### 4.1 — Diagnostic Abilities

- [ ] Register `ai-ddtk/site-health` ability (mirrors WP Site Health data)
- [ ] Register `ai-ddtk/get-query-log` ability (recent DB queries with timing, requires `SAVEQUERIES`)
- [ ] Register `ai-ddtk/get-cron-events` ability (scheduled WP-Cron events with next run times)
- [ ] Register `ai-ddtk/get-error-log` ability (tail PHP error log, sanitized output)
- [ ] Register `ai-ddtk/get-transients` ability (list/inspect transient cache entries)

### 4.2 — WPCC Bridge

- [ ] Define workflow: WPCC scan flags issue → agent calls diagnostic ability for runtime data
- [ ] Map WPCC issue types to relevant diagnostic abilities:
  - `unbound-query` → `get-query-log`
  - `missing-nonce` → (no runtime equivalent, stays static-only)
  - `n-plus-one` → `get-query-log` (count queries per request)
- [ ] Add "runtime verify" suggestions to WPCC JSON triage output

### 4.3 — Integration & Documentation

- [ ] Add diagnostic abilities to AGENTS.md workflow triggers
- [ ] Measure performance overhead of diagnostic abilities (must be <100ms per call)
- [ ] Create recipe: "Post-scan runtime verification workflow"

---

## Open Questions

1. **Composer on Local by Flywheel** — Does Local's bundled PHP include Composer, or do we need to install it separately? Phase 0 spike will answer this.
2. **Ability registration location** — mu-plugin (simpler, per-site) vs. a dedicated Composer-installed plugin (cleaner, version-controlled)? Spike will inform.
3. **Dual-server MCP stability** — Are there known issues with Claude Code consuming two MCP servers simultaneously? Need to test in Phase 0.
4. **WordPress Abilities API maturity** — The Abilities API is relatively new. Monitor for breaking changes and pin versions accordingly.
5. **Scope of built-in abilities** — Does the MCP Adapter ship with any content/settings abilities out of the box, or is everything custom-registered? Phase 0 spike will clarify.
6. **HTTP transport** — Out of scope for now, but may be relevant if AI-DDTK ever supports remote dev environments (e.g., Codespaces, GitPod). Revisit after Phase 4.
