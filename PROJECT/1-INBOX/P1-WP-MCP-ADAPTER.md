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
- [Prerequisites](#prerequisites)
- [Goals & Non-Goals](#goals--non-goals)
- [How It Complements AI-DDTK](#how-it-complements-ai-ddtk)
- [Phase 0 — Technical Spike](#phase-0--technical-spike)
- [Phase 1 — Content Scaffolding & Migration](#phase-1--content-scaffolding--migration)
- [Phase 2 — Plugin/Theme Config Verification in Fix-Iterate Loops](#phase-2--plugintheme-config-verification-in-fix-iterate-loops)
- [Phase 3 — Editorial Workflow Automation](#phase-3--editorial-workflow-automation)
- [Phase 4 — Live Site Diagnostics Without Browser Overhead](#phase-4--live-site-diagnostics-without-browser-overhead)
- [Valet Clone-Lab Integration](#valet-clone-lab-integration)
- [Open Questions](#open-questions)
- [FAQ — Relationship to the Existing AI-DDTK MCP Server](#faq--relationship-to-the-existing-ai-ddtk-mcp-server)

<!-- /TOC -->

---

## Phased Checklist (High-Level Progress)

> **Note for LLM agents:** Continuously mark items off this checklist as progress is made during implementation. This section is the single source of truth for phase completion status. Update it **immediately** after completing any item — do not batch updates.

- [ ] **Phase 0 — Technical Spike** · Effort: Low · Risk: Low
  - [ ] Install Abilities API + MCP Adapter on a Local site
  - [ ] Verify STDIO transport via `local-wp <site> mcp-adapter serve`
  - [ ] Register a test ability and confirm MCP tool discovery
  - [ ] Test `.mcp.json` dual-server config (AI-DDTK + WP MCP Adapter side-by-side)
  - [ ] Validate on a Valet clone-lab site (Composer install + STDIO via system WP-CLI)
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

- [ ] **Valet Clone-Lab Integration** · Effort: Low · Risk: Low
  - [ ] Auto-provision MCP Adapter + abilities mu-plugin during Valet clone creation
  - [ ] Update seed site pattern with Composer dependencies
  - [ ] Validate STDIO transport via system WP-CLI (no Local wrapper needed)
  - [ ] Update Valet clone-lab recipe with MCP Adapter provisioning steps

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

## Prerequisites

> **The Abilities API is a WordPress 6.9 core feature.** It shipped in the WordPress 6.9 release (December 2025) — the first WordPress version to include `wp_register_ability()` and the `WP_Abilities_Registry` in core. Sites running WordPress 6.8 or earlier **cannot use the MCP Adapter.**

| Requirement | Minimum Version | Notes |
|---|---|---|
| **WordPress** | **6.9+** | Abilities API (`wp_register_ability()`) merged into core in 6.9. Not available as a backport for 6.8. |
| **PHP** | **7.4+** | Per `wordpress/mcp-adapter` Composer constraint (`^7.4 \|\| ^8.0`). PHP 8.1+ recommended for Local by Flywheel compatibility. |
| **WP-CLI** | **2.9+** | Required for the `mcp-adapter serve` STDIO subcommand. |
| **Composer** | **2.x** | For installing `wordpress/mcp-adapter` and `wordpress/abilities-api` (on pre-7.0 sites where the Abilities API is core but the Adapter is not). |
| **AI-DDTK MCP Server** | **0.6.x+** (existing) | Not a hard dependency, but dual-server `.mcp.json` config and `local_wp_run` bootstrapping assume the existing server is operational. |

### Version timeline

- **WordPress 6.9** (Dec 2025) — Abilities API PHP layer merged into core. MCP Adapter available as a separate Composer package (`wordpress/mcp-adapter`).
- **WordPress 7.0** (planned Apr 2026) — Expected to bundle the MCP Adapter and deeper Abilities API integration directly in core, removing the need for a separate Composer install.

### What this means for AI-DDTK

All Local by Flywheel and Valet dev sites used with this project **must run WordPress 6.9 or later**. Phase 0's spike should verify the exact WP version on each test site before proceeding. The Valet clone-lab seed site should be provisioned with WP 6.9+ from the start so that every clone inherits Abilities API support automatically.

> **If upgrading to WP 7.0 before starting implementation:** The Composer install steps for `wordpress/abilities-api` may become unnecessary (already in core). Phase 0 should note whether 7.0 bundles the MCP Adapter itself or still requires `composer require wordpress/mcp-adapter`.

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
          (stdio · 18 tools)              (stdio via WP-CLI)
          ┌──────────────┐                ┌──────────────────┐
          │ local_wp_*   │                │ Content CRUD     │
          │ wpcc_*       │                │ Config reads     │
          │ pw_auth_*    │                │ Diagnostics      │
          │ wp_ajax_test │                │ Editorial flows  │
          │ tmux_*       │                │ Custom abilities │
          └──────┬───────┘                └────────┬─────────┘
                 │                                  │
                 ▼                                  ▼
          ┌─────────────────────────────── WP-CLI ──► WordPress
          │
          ├── Local WP: bin/local-wp <site> mcp-adapter serve ...
          │   (routed through Local's PHP + MySQL socket)
          │
          └── Valet:    wp --path=<site> mcp-adapter serve ...
              (system PHP + Homebrew MySQL, no wrapper needed)

          bin/pw-auth ──► Playwright ──► Browser ──► WordPress
          (complementary — visual/UI verification layer)
```

---

## Phase 0 — Technical Spike

**Effort: Low** · **Risk: Low**

> Purpose: Validate that the WordPress MCP Adapter works with AI-DDTK's Local-by-Flywheel setup, confirm dual-server MCP configuration, and surface any blockers before committing to implementation phases. **Results from this spike should be used to update Phases 1–4 with concrete scope adjustments.**

### Real-World Justification

**Scenario A — "We don't know what we don't know":** A developer is evaluating whether to adopt the MCP Adapter for a client's WooCommerce build. Before investing in custom abilities, they need to know: Does Composer install cleanly on Local's bundled PHP 8.2? Does the STDIO server coexist with AI-DDTK's existing MCP server without stdout conflicts? The spike answers these in 1–2 hours instead of discovering blockers mid-sprint.

**Scenario B — "Valet vs. Local cost comparison":** A macOS developer uses both Local (primary) and Valet clone-lab (throwaway testing). They want to know which environment has the smoother MCP Adapter setup path before deciding where to invest provisioning automation. The spike tests both side-by-side and produces a concrete comparison — potentially revealing that Valet's system Composer makes it the faster path, saving repeated setup friction across dozens of clone-lab cycles.

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

### 0.4 — Valet Clone-Lab Validation

- [ ] Install MCP Adapter on a Valet clone-lab site via Composer:
  ```bash
  cd ~/Valet-Sites/clone-source
  composer require wordpress/abilities-api wordpress/mcp-adapter
  ```
- [ ] Confirm STDIO transport works via system WP-CLI (no `local-wp` wrapper needed):
  ```bash
  wp --path=~/Valet-Sites/clone-source mcp-adapter serve \
    --server=mcp-adapter-default-server --user=admin
  ```
- [ ] Copy the test ability mu-plugin into the seed site and verify discovery
- [ ] Clone the seed site using the clone-lab workflow and confirm MCP Adapter carries over
- [ ] Document any differences between Local and Valet provisioning (Composer path, PHP version, autoloader)

### 0.5 — Document Findings

- [ ] Record any Local-by-Flywheel quirks (PHP version, Composer path, MySQL socket)
- [ ] Record any Valet-specific quirks (system PHP version, Composer global vs. local)
- [ ] Note Composer autoloader compatibility with both Local's PHP binary and Valet's system PHP
- [ ] Confirm minimum PHP/WP version requirements vs. what Local and Valet provide
- [ ] **Update Phases 1–4 and Valet section** in this document based on spike findings
- [ ] Decide: mu-plugin approach vs. Composer-installed plugin for ability registration

---

## Phase 1 — Content Scaffolding & Migration

**Effort: Med** · **Risk: Low**

> Use case: AI agents create, restructure, or migrate WordPress content (posts, pages, CPTs, taxonomies) through typed MCP tools instead of browser automation or raw WP-CLI.

### Real-World Justification

**Scenario A — WooCommerce plugin test data seeding:** A developer is building a custom WooCommerce shipping plugin and needs 50 products across 5 categories with varied weights, dimensions, and shipping classes to test rate calculations. Today this means either writing a custom WP-CLI script, importing a CSV through wp-admin (slow, manual), or hand-creating products. With MCP Adapter content abilities, the AI agent seeds the exact product matrix needed via `ai-ddtk/create-post` with structured meta — and can tear it down and re-seed with different data each fix-iterate cycle without browser overhead.

**Scenario B — Content migration dry-run for a redesign:** A content editor is planning a site restructure: 200 blog posts need to move from flat categories into a hierarchical taxonomy (e.g., "Recipes > Breakfast > Quick Meals"). Before touching production, they clone the site to Valet, then ask the agent to "reclassify all posts matching these rules." The agent uses `ai-ddtk/list-posts` to audit current state, `ai-ddtk/manage-taxonomy` to build the new hierarchy, and `ai-ddtk/update-post` to reassign — all via MCP. The editor reviews the result in the browser (pw-auth), iterates on the rules, and has a validated migration plan before touching the real site.

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

### Real-World Justification

**Scenario A — Custom Gutenberg block registration debugging:** A developer's plugin registers 3 custom blocks (`my-plugin/hero`, `my-plugin/pricing-table`, `my-plugin/testimonial`). After a refactor, one block silently fails to register — no PHP error, it just doesn't appear in the inserter. Today the agent would need to launch Playwright, navigate to the block editor, open the inserter, and search — a 10+ second round trip that's fragile to Gutenberg UI changes between WP versions. With `ai-ddtk/list-registered-blocks`, the verify step takes <100ms and returns a definitive JSON list. The agent immediately identifies the missing block and traces it to a typo in `register_block_type()`.

**Scenario B — WooCommerce settings verification after plugin update:** After updating a WooCommerce extension, the agent needs to verify that 12 plugin options survived the migration (tax settings, shipping zones, payment gateway configs). Scraping 4 different wp-admin settings tabs with Playwright takes ~30 seconds and breaks whenever WooCommerce redesigns a settings panel. With `ai-ddtk/get-options`, the agent reads all 12 option values in a single MCP call, compares against expected values, and flags any that changed — completing the verify step of the fix-iterate loop in under a second.

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

### Real-World Justification

**Scenario A — Weekly content pipeline for a multi-author blog:** A managing editor oversees 8 freelance writers submitting 15–20 draft posts per week. Every Friday they spend 2+ hours: checking each draft has a featured image, verifying SEO metadata is filled in (Yoast/RankMath), assigning the correct category, and scheduling posts across the following week to avoid same-day clustering. With editorial abilities, the agent runs the full pipeline: `ai-ddtk/get-drafts` pulls the week's submissions, flags posts missing metadata via `ai-ddtk/update-seo-metadata`, assigns categories with `ai-ddtk/assign-taxonomy-terms`, and distributes publish dates with `ai-ddtk/schedule-post` — all while respecting the editor's role permissions. The editor reviews the agent's proposed schedule and approves. A Friday afternoon task becomes a 10-minute review.

**Scenario B — Testing a custom editorial workflow plugin:** A developer is building a plugin that adds a "Legal Review" step between draft and publish for a compliance-heavy client (finance, healthcare). Contributors submit drafts, editors assign a legal reviewer, the reviewer approves or rejects with notes, then the editor publishes. Testing this flow manually means creating test users for each role, logging in as each one, and clicking through the full workflow — 15+ minutes per test run. With MCP Adapter abilities + pw-auth multi-user sessions, the agent exercises the entire workflow programmatically: create draft as contributor, assign reviewer as editor, approve as custom "legal_reviewer" role, publish as editor — and verifies each step's permission boundary holds. Each fix-iterate cycle tests the full 4-role workflow in seconds.

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

### Real-World Justification

**Scenario A — WPCC flags an N+1 query, agent confirms at runtime:** WPCC's static scan flags a `get_post_meta()` call inside a `foreach` loop in a WooCommerce order listing plugin — a classic N+1 pattern. But is it actually a problem, or does WordPress's object cache absorb it? Today the developer has to manually add `SAVEQUERIES`, load the page, and inspect `$wpdb->queries`. With `ai-ddtk/get-query-log`, the agent loads the order listing page (via pw-auth Playwright), then immediately calls the diagnostic ability to pull actual query counts and timing. If the page fires 150 queries in 800ms, the N+1 is confirmed and worth fixing. If the cache reduces it to 3 queries, the WPCC flag is triaged as a false positive. Static analysis + runtime data in one automated loop.

**Scenario B — Debugging a stuck WooCommerce scheduled action:** A developer's background order processing (via Action Scheduler) silently stopped running. Orders are stuck in "processing" status. Diagnosing this normally means: SSH in, check `wp cron event list`, inspect the `wp_actionscheduler_actions` table, check PHP error logs — across 3 different tools. With `ai-ddtk/get-cron-events` + `ai-ddtk/get-error-log`, the agent pulls both in parallel via MCP. It finds that a fatal error in a hooked callback killed the scheduler 3 days ago, and the cron event is still registered but the callback is erroring. The agent surfaces the root cause (a missing dependency after a plugin update) without the developer leaving their editor.

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

## Valet Clone-Lab Integration

**Effort: Low** · **Risk: Low**

> The Valet clone-lab (`recipes/valet-clone-lab.md`) is AI-DDTK's rapid provisioning system for disposable WordPress sites on macOS. Because Valet sites use system PHP + Composer + WP-CLI directly (no Local wrapper), they're the **simplest path** to MCP Adapter integration — and the natural place to bake it into the provisioning pipeline.

### Real-World Justification

**Scenario A — Rapid regression testing across WordPress versions:** A plugin developer needs to verify their plugin works on WP 6.4, 6.5, and 6.6 before a release. With the Valet clone-lab, they spin up 3 clones from the seed site, each pinned to a different WP version via `wp core update --version=X.Y`. Because the MCP Adapter is baked into the seed, all 3 clones immediately have MCP ability access — the agent runs the same fix-iterate verification loop across all 3 in parallel, comparing option values and block registrations via MCP instead of manually clicking through each site's admin. Clone, test, teardown — 3 versions validated in the time it used to take for one.

**Scenario B — Isolated plugin conflict testing:** A client reports that "Plugin X breaks when Plugin Y is active." The developer clones the seed site twice: Clone A has both plugins active, Clone B has only Plugin X. The agent uses `ai-ddtk/list-plugins` and `ai-ddtk/get-options` on both clones via MCP to compare registered settings, post types, and option values side-by-side. It identifies that Plugin Y overwrites an option key that Plugin X depends on. The disposable clones mean there's zero risk to the developer's primary Local environment, and the MCP Adapter abilities make the comparison programmatic rather than a tedious manual admin-panel diff.

### Why Valet is a natural fit

| Factor | Local by Flywheel | Valet Clone-Lab |
|---|---|---|
| **Composer** | Requires Local's bundled PHP; may need path gymnastics | System Composer, already a prerequisite |
| **WP-CLI** | Needs `local-wp` wrapper for socket/path routing | System `wp` binary, direct access |
| **MCP STDIO** | `local-wp <site> mcp-adapter serve` | `wp --path=<site> mcp-adapter serve` |
| **Site lifecycle** | Persistent, manually managed | Disposable, scripted clone + teardown |
| **Provisioning hook** | Manual or per-site | Seed site pattern — install once, clone many |

The key advantage: install the MCP Adapter **once in the seed site**, and every clone inherits it automatically — including the abilities mu-plugin, Composer dependencies, and autoloader.

### Updated Seed Site Pattern

Extend the existing seed site creation from `recipes/valet-clone-lab.md`:

```bash
# After standard seed site creation...
cd "$HOME/Valet-Sites/clone-source"

# Install MCP Adapter + Abilities API
composer require wordpress/abilities-api wordpress/mcp-adapter

# Recommended: Jetpack Autoloader for multi-plugin compatibility
composer require automattic/jetpack-autoloader

# Copy AI-DDTK abilities mu-plugin (registered abilities for agent workflows)
cp "$HOME/bin/ai-ddtk/templates/ai-ddtk-abilities.php" \
  "$HOME/Valet-Sites/clone-source/wp-content/mu-plugins/ai-ddtk-abilities.php"
```

After this, every `clone-lab` clone carries the full MCP Adapter stack.

### Dual-Server `.mcp.json` for Valet

When an agent is working in Valet clone-lab mode, the MCP config uses system `wp` instead of `local-wp`:

```json
{
  "mcpServers": {
    "ai-ddtk": { "...existing config..." },
    "wordpress": {
      "command": "wp",
      "args": [
        "--path=/Users/<you>/Valet-Sites/<clone-name>",
        "mcp-adapter", "serve",
        "--server=mcp-adapter-default-server",
        "--user=admin"
      ]
    }
  }
}
```

### Clone Lifecycle with MCP Adapter

```
Seed Site (with MCP Adapter + abilities mu-plugin)
     │
     ├─► Clone A ──► Agent runs fix-iterate loop with MCP verify ──► Teardown
     ├─► Clone B ──► Agent tests editorial workflows via abilities ──► Teardown
     └─► Clone C ──► Agent runs WPCC + runtime diagnostics bridge ──► Teardown
```

Each clone is disposable. The agent can freely create/modify content, test role-based permissions, and run diagnostics without affecting any persistent environment.

### Integration Tasks

- [ ] Create `templates/ai-ddtk-abilities.php` mu-plugin (bundles all AI-DDTK registered abilities from Phases 1–4)
- [ ] Update `recipes/valet-clone-lab.md` seed site pattern with MCP Adapter Composer install steps
- [ ] Add Valet-specific `.mcp.json` example to the recipe
- [ ] Update `recipes/valet-clone-lab.md` "AI Agent Usage Hint" section with MCP Adapter guidance
- [ ] Verify cloned sites inherit Composer `vendor/` and `autoload.php` correctly after filesystem copy
- [ ] Test teardown — confirm `wp db drop --yes && rm -rf <clone>` cleanly removes MCP Adapter artifacts
- [ ] Add a "Valet + MCP Adapter" verification check to `pw-auth doctor` or a new `mcp-adapter doctor` helper

### Coexistence with Local WP

Both environments are supported in parallel:

- **Local sites:** Use `local-wp <site> mcp-adapter serve` (Phase 0 validates this)
- **Valet sites:** Use `wp --path=<site> mcp-adapter serve` (simpler, no wrapper)
- **Agent decision:** Check the "AI Agent Usage Hint" — if target environment is Valet clone-lab, use system `wp`; if Local WP, use `local-wp` wrapper

No code changes needed in the AI-DDTK MCP server itself — the WordPress MCP Adapter runs as a separate STDIO server. The agent simply has access to both tool surfaces.

---

## Open Questions

1. **Composer on Local by Flywheel** — Does Local's bundled PHP include Composer, or do we need to install it separately? Phase 0 spike will answer this.
2. **Ability registration location** — mu-plugin (simpler, per-site) vs. a dedicated Composer-installed plugin (cleaner, version-controlled)? Spike will inform.
3. **Dual-server MCP stability** — Are there known issues with Claude Code consuming two MCP servers simultaneously? Need to test in Phase 0.
4. **WordPress Abilities API maturity** — The Abilities API is relatively new. Monitor for breaking changes and pin versions accordingly.
5. **Scope of built-in abilities** — Does the MCP Adapter ship with any content/settings abilities out of the box, or is everything custom-registered? Phase 0 spike will clarify.
6. **HTTP transport** — Out of scope for now, but may be relevant if AI-DDTK ever supports remote dev environments (e.g., Codespaces, GitPod). Revisit after Phase 4.
7. **Valet seed site Composer `vendor/` in clones** — Does a filesystem copy of `vendor/` work reliably, or do clones need `composer install` post-copy? Phase 0 spike will test this.
8. **Valet clone-lab promotion** — If MCP Adapter integration proves smoother on Valet than Local, should Valet clone-lab be promoted from "experimental optional" to a recommended workflow for MCP Adapter testing?

---

## FAQ — Relationship to the Existing AI-DDTK MCP Server

> The AI-DDTK MCP server (`P1-MCP-SERVER.md`) is **complete** — all 6 phases shipped, 18 tools + 4 resources, version 0.6.3. This section clarifies how the WordPress MCP Adapter project relates to it.

### Q: Is this replacing the existing MCP server?

**No.** The WP MCP Adapter runs as a **second, independent STDIO server** alongside the existing one. The agent gets both tool surfaces simultaneously via `.mcp.json`. No code changes are needed in the existing AI-DDTK MCP server.

```
.mcp.json
├── "ai-ddtk":    → tools/mcp-server/start.sh     (existing, 18 tools)
└── "wordpress":  → wp mcp-adapter serve           (new, Abilities API tools)
```

### Q: Does the existing MCP server make this project easier or faster?

**Yes — significantly for infrastructure, less so for WordPress-side work.**

What's already done and reusable:
- **Dual-server MCP config** — `.mcp.json`, `start.sh`, STDIO transport, and Claude Code auto-discovery are proven. Phase 0 just adds a second server entry.
- **`local_wp_run` bootstraps the Adapter** — Composer install, `mcp-adapter serve` verification, and ability listing are all doable through existing allowlisted WP-CLI commands without leaving MCP.
- **`pw_auth_*` is the visual complement** — Every phase references "use MCP for data, pw-auth for visual." That visual layer is built and tested.
- **WPCC bridge is plug-and-play** — `wpcc_run_scan` already produces structured JSON with typed issue categories. Phase 4 maps those types to diagnostic abilities — no WPCC changes needed.
- **Security patterns are established** — Allowlist conventions, localhost-only binding, explicit-site-required rules are documented and can be referenced, not reinvented.

What's genuinely new work (not helped by the existing server):
- **PHP ability registration** — Writing the `wp_register_ability()` calls, permission callbacks, input/output schemas. This is WordPress PHP code; the existing server is Node.js.
- **mu-plugin design** — Deciding ability scope, structuring the abilities file, handling Composer autoloading.
- **Role-based permission testing** — Exercising WordPress's `current_user_can()` across roles is domain-specific testing that has no analog in the existing server.

**Estimated impact:** Infrastructure work (Phase 0, dual-server config, `.mcp.json` wiring, Valet integration) is ~50% faster because the patterns exist. WordPress-side work (Phases 1–4 ability registration and testing) is net-new effort.

### Q: Why not just expand `local_wp_run`'s allowlist instead?

Three reasons:

1. **No schema validation.** `local_wp_run` returns raw stdout text. MCP Adapter abilities return typed JSON with input/output schemas the agent can reason about.
2. **No permission model.** `local_wp_run` runs as whatever `--user` WP-CLI uses. Abilities have `permission_callback` functions that enforce WordPress role capabilities per-action.
3. **No discoverability.** The agent can't call `DiscoverAbilities` on `local_wp_run` to learn what's available. With the Adapter, the agent discovers, introspects, and chains abilities dynamically.

Expanding the allowlist would give raw CLI access to more commands, but it wouldn't give structured, permission-checked, discoverable operations.

### Q: What's the overlap between the two servers?

Minimal, and intentionally so:

| Capability | AI-DDTK MCP Server | WP MCP Adapter |
|---|---|---|
| List plugins/themes | `local_wp_run` (raw text) | `ai-ddtk/list-plugins` (typed JSON + capabilities) |
| Read options | `local_wp_run option get` (single key, raw) | `ai-ddtk/get-options` (prefix/batch, typed) |
| Content CRUD | Not supported | Full create/update/list/delete with schema |
| Visual verification | `pw_auth_login` → Playwright | Not applicable (data only) |
| Static analysis | `wpcc_run_scan` | Not applicable |
| Runtime diagnostics | Not supported | `ai-ddtk/site-health`, `get-query-log`, etc. |
| Tmux sessions | `tmux_*` (6 tools) | Not applicable |

The Adapter fills the **WordPress data operations** gap. The existing server handles **dev tooling orchestration**. They overlap slightly on read-only introspection (plugin list, option get), but the Adapter's typed schemas and permission model make it the better choice for those operations once available.

### Q: Can Phase 0 be done entirely through existing MCP tools?

Almost. The spike's install-and-verify steps can use `local_wp_run` to run Composer and test the Adapter's STDIO server. The one exception: verifying that Claude Code discovers tools from **both** servers requires restarting the MCP client with the updated `.mcp.json` — that's a manual step outside any tool's control.
