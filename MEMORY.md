## Lessons Learned (from 4X4.md, 2026-04-05)

### No [Unreleased] section in CHANGELOG
**Type:** feedback

Use versioned blocks on commit instead of batching changes in an [Unreleased] bucket. At solo/small-team velocity, every commit gets a version block immediately, so the unreleased bucket just accumulated stale entries nobody reviewed.

**How to apply:** Always create a new `## [X.Y.Z] - YYYY-MM-DD` block. Never add `[Unreleased]`. The CHANGELOG maintainer rules in the file header enforce this.

---

### Promote experimental scripts after 4+ hardening commits
**Type:** feedback

Scripts with 4+ consecutive hardening releases should move out of `experimental/` to reduce confusion about maturity. Leaving hardened scripts in `experimental/` signals instability that no longer exists.

**How to apply:** When a script in `experimental/` accumulates 4+ commits focused on fixes, edge cases, or robustness, recommend promotion to `tools/` or the appropriate mainline directory.

---

### VS Code extension value is zero-config MCP onboarding
**Type:** project

The extension's real value is zero-config workspace onboarding (MCP server auto-discovery), not wrapping terminal commands with UI chrome. Users already have CLI and MCP tools — the extension eliminates the manual wiring step.

**How to apply:** Prioritize features that reduce setup friction (file watchers, config merging, provider auto-registration). Avoid duplicating functionality already available via MCP tools or CLI.

---

### Wire placeholder features immediately
**Type:** feedback

Don't create a file and leave it disconnected. `.wpcignore` existed as a placeholder but was never wired into WPCC, leaving repo-wide scans broken by false positives. Placeholder files create a false sense of completeness.

**How to apply:** Wire config files, templates, or feature stubs into the consuming code in the same PR. If the integration isn't ready, document the gap in a TODO or issue instead of creating a disconnected file.
