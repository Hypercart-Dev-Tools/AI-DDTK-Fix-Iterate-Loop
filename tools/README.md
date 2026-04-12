# tools/

This directory holds maintained repository tooling and operational support files.

## Purpose

- Put reusable repo-level scripts and tool subprojects here.
- Keep each substantial tool self-describing through its own README when it has a dedicated subdirectory.
- Treat top-level files here as operator utilities, shared maintenance scripts, or machine-readable support data.

## Quick Map

- `cleanup.sh` — repo metadata catalog builder used by the cleanup workflow
- `dev-context.sh` — Local WP / Valet port-80 context switcher with JSON status mode
- `servers-monitor.sh` and `servers-monitor.conf.example` — local machine conflict monitor plus config template
- `local-nginx-shim` and `local-nginx-shim-install.sh` — Local WP coexistence shim and installer
- `SERVERS.md` and `servers.registry.json` — server/port registry source material
- `servers-audit.sh` and `servers-preflight.sh` — local server diagnostics
- `mcp-server/` — AI-DDTK MCP server implementation and docs
- `wp-code-check/` — WPCC subproject with its own documentation and distribution assets
- `wp-ajax-test/` — AJAX testing utility with its own README
- `qm-bridge/` — Query Monitor bridge helpers
- `ux-audit.sh` and `valet-site-copy.sh` — narrower operator utilities

## Reading Order

- Start here only to orient yourself.
- If a tool has its own README, treat that tool-level README as the canonical usage guide.
- For server/port coordination, use `SERVERS.md` before running related scripts.

## Conventions

- Add a dedicated README when a tool grows into a subdirectory or has non-trivial setup.
- Keep generated runtime outputs out of `tools/` unless they are intentional checked-in distribution assets.
- Prefer explicit filenames for single-purpose scripts so operators can understand them from `ls` output alone.