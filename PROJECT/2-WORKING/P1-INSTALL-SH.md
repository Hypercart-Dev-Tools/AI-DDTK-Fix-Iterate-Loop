# P1: install.sh UX Overhaul

## Correctness (do first)
- [x] The Quick Start now leads with a macOS callout, shows required prerequisites (Git, Node ≥ 18) before the install commands, and separates optional tools into their own table with "Unlocks" instead of "Used By" to make the distinction clearer.
- [ ] `set -o pipefail` + check npm exit codes — silent npm build failure prints success message
- [ ] Node version check — `setup_mcp` checks presence but doesn't enforce `>= 18` (README promises it)

## High-value UX

- [ ] Preflight summary before mutating anything — show OS, shell config target, Node present/version, git present, PATH already configured, WPCC exists, MCP built
- [ ] Default `./install.sh` runs full safe setup — PATH + setup-wpcc + setup-mcp idempotently (skip quick/full split; each step already guards re-runs)
- [ ] Begin/end markers in shell config — replace fragile grep/sed with `# >>> AI-DDTK >>>` / `# <<< AI-DDTK <<<` (conda convention)

## Lower priority

- [ ] Enhance `status` with doctor-style health checks — is `wpcc` resolvable from PATH? does `node` meet version floor? (no new subcommand needed)
- [ ] Copy-pasteable next-step block — fenced block instead of numbered prose
- [ ] Move agent comments (Sections 2+) to `docs/INSTALL-AGENT-NOTES.md` — leave one-line pointer in install.sh (120 lines of comments burying 120 lines of code)
