# Things deferred during the spike

Per the spike's hard non-goals fence: anything tempting that fell outside scope went here instead of getting built.

- **`micromatch` glob library** — wrote a conservative literal-prefix overlap test in [src/paths.js](src/paths.js) instead of pulling in the dep. False-positive bias is acceptable for the spike (over-reports overlap, never under-reports). Revisit if real-agent runs show the conservatism causes excessive task starvation.
- **Push retry beyond N=1** — spec says one retry then abort. We did not add exponential backoff or a configurable retry count. If it shows up as flaky in practice, revisit.
- **`tick init --remote <url>`** — `tick init` only does `mkdir -p`. Remote setup is the user's job (via normal `git clone` / `git remote add`).
- **Filename collision under sub-millisecond bursts** — events use ms-precision timestamps. If two `tick log` calls land in the same ms with the same agent and action and task, the second overwrites the first. Not observed in any test; would need a per-event nonce to fix.
- **Worktree friction** — `git worktree add` on the same branch fails. README documents the workaround (per-agent child branches, push to coordination ref). A clean fix (separate ref for `.tick/`, or a daemon) is Phase 2.
- **Compaction / archival of old events** — `.tick/events/` grows without bound. No compaction strategy yet.
- **Cross-branch coordination** — explicitly Phase 2.
- **Pre-commit hook to enforce declared paths** — listed in P1-TRINITY.md open questions, not built.
- **MCP wrapper for `tick`** — agents call the CLI directly during the spike per the non-goals fence.
- **WPCC findings adapter, Git Pulse extension, ask-self ingest** — Phase 2.
