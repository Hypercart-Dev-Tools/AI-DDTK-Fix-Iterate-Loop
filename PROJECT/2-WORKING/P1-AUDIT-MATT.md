# Code Review Feedback — 2026-03-23

Reviewed branch: `development` (e2019e0)
Reviewer: @mrtwebdesign

**Rating key:**
- **Effort**: S (< 15 min), M (15–60 min), L (1–4 hrs), XL (4+ hrs)
- **Risk**: Low (safe/isolated change), Med (could break workflows), High (data loss / security / broad impact)

---

## High

- [x] **Committed `node_modules` in repo** — `tools/mcp-server/node_modules/` is tracked in git. Should be in `.gitignore` and installed via `npm ci`. Bloats repo size and risks dependency drift.
  - **Effort: M** | **Risk: Med** — Requires `git rm -r --cached`, `.gitignore` update, and verifying CI/docs tell users to run `npm ci`. Anyone on a stale clone needs `npm ci` after pulling.
  - **Note**: Not tracked on current branch (`main`). Verify on `development` — may be a false positive.

- [x] **Symlinks to local system binaries committed** — `npx` and `playwright` in the repo root are symlinks to `/opt/homebrew/bin/`. These are machine-specific and will break for any other developer cloning the repo.
  - **Effort: S** | **Risk: Low** — `git rm npx playwright`, add to `.gitignore`. No code depends on these.
  - **Fixed**: Removed from git, added `/npx` and `/playwright` to `.gitignore`.

- [x] **`temp/auth.json` may be tracked in git** — Auth state file exists in the repo. The `temp/` directory is gitignored but this file may have been committed before the ignore rule was added. Could be leaking session tokens.
  - **Effort: S** | **Risk: High** — `git rm --cached temp/auth.json`. If it contains real session tokens, rotate credentials and consider `git filter-repo` to scrub history.
  - **Fixed**: Removed from git index. **ACTION REQUIRED**: File contained plaintext credentials — rotate password and scrub git history before pushing.

- [x] **No request size limits on MCP HTTP transport** — `tools/mcp-server/src/index.ts`. The HTTP handler has no Content-Length validation or request body size limits. A large payload could exhaust server memory.
  - **Effort: S** | **Risk: Low** — Add Express body size limit (e.g. `express.json({ limit: '1mb' })`). Server is localhost-only so real-world exploit risk is minimal.
  - **Fixed**: Added 1 MB `Content-Length` check in HTTP handler, returns 413 for oversized requests.

---

## Medium

- [x] **Stack trace loss in `withResourceError()`** — `tools/mcp-server/src/index.ts` (line 89–96). Re-throwing errors drops the original stack trace and error context. Should use `new Error(message, { cause: error })` to preserve the chain.
  - **Effort: S** | **Risk: Low** — One-line fix. No behavior change for callers.
  - **Fixed**: Added `{ cause: error }` to preserve error chain.

- [x] **Unstructured error for missing binaries in WPCC handler** — `tools/mcp-server/src/handlers/wpcc.ts` (line 176–180). Non-`ExecFileTextError` exceptions (e.g. binary not found, permission denied) bubble up as unstructured crashes instead of returning a structured error result.
  - **Effort: S** | **Risk: Low** — Catch all errors in `executeWpcc`, return structured `errorResult`. Isolated to one function.
  - **Fixed**: Non-`ExecFileTextError` exceptions now return `{ stdout: "", stderr: message, exitCode: 1 }`.

- [x] **No timeout on WP-CLI call in theme-crash-loop** — `experimental/theme-crash-loop.sh` (line 181). `$LOCAL_WP ... option get home` has no timeout protection. If the site is unresponsive, the script hangs indefinitely. Wrap with `timeout 10`.
  - **Effort: S** | **Risk: Low** — One-line wrap. Script is experimental, low blast radius.
  - **Fixed**: Wrapped with `timeout 10`.

- [ ] **`sed -i.bak` not POSIX-portable** — `install.sh` (line 394). This syntax works on macOS and GNU/Linux but is not POSIX-compliant. Could break on other systems or in Docker containers with minimal base images.
  - **Effort: S** | **Risk: Low** — Already works on the two primary targets. Only matters for exotic environments. Low priority.

- [ ] **Scattered timeout configuration across MCP handlers** — Timeout values are hardcoded in each handler with no central config or env var overrides: local-wp 60s, pw-auth 120s, wpcc 300s, tmux 10s, qm 30s. Should be centralized in a config module.
  - **Effort: M** | **Risk: Med** — New config module, update 5+ handler files, add env var overrides. Wrong default or missed handler could change behavior.

- [ ] **`pw-auth` is 1000+ lines of bash** — `bin/pw-auth`. At this size, the script is approaching the maintainability limit for shell. Cookie handling, redirect following, and session management would benefit from being split into sourced helper files or rewritten in a more maintainable language.
  - **Effort: XL** | **Risk: High** — 1,567 lines. Rewrite/split is a major undertaking with high regression risk. Currently works and is well-tested. Acknowledge as tech debt, don't rush.

- [x] **Stale/deprecated files still in repo** — `BACKLOG-DEPRECATED.md` and `ROADMAP-DEPRECATED.md` are still tracked. If they're deprecated, they should be removed to reduce confusion.
  - **Effort: S** | **Risk: Low** — `git rm` both files. No code references them.
  - **Fixed**: Both files removed from git.

---

## Low

- [x] **Unquoted `$log_file` in pipe-pane command** — `bin/aiddtk-tmux` (line 101). Variable should be quoted to prevent word splitting if the path contains spaces.
  - **Effort: S** | **Risk: Low**
  - **Fixed**: Changed single quotes to escaped double quotes so the variable is expanded by the current shell but properly quoted for tmux's `sh -c`.

- [x] **Unquoted glob pattern in test expression** — `bin/wpcc` (line 128–129). Pattern `_*` in a conditional test should be properly quoted to prevent unexpected glob expansion.
  - **Effort: S** | **Risk: Low** — Was safe inside `[[ ]]` but quoting `"_"*` is clearer.
  - **Fixed**: Quoted the underscore prefix for clarity.

- [x] **`&> /dev/null` not POSIX-compliant** — `tools/wp-ajax-test/install.sh` (line 17). Should be `>/dev/null 2>&1` for portability.
  - **Effort: S** | **Risk: Low** — One-line change. Script already assumes bash.
  - **Fixed**: Changed to `>/dev/null 2>&1`.

- [ ] **Brittle Node.js version extraction** — `tools/wp-ajax-test/install.sh` (line 22). `cut -d'v' -f2` assumes `node --version` always outputs a `v` prefix. Could fail with non-standard Node distributions.
  - **Effort: S** | **Risk: Low** — Cosmetic. Every mainstream Node distribution outputs `v`-prefixed versions.

- [x] **README version behind package.json** — `tools/mcp-server/README.md` says 0.6.2 but `package.json` says 0.6.3.
  - **Effort: S** | **Risk: Low** — Update version string in README.
  - **Fixed**: Updated to 0.6.3.

- [x] **Complex regex patterns lack documentation** — `tools/mcp-server/src/security/allowlist.ts` (line 16), `handlers/tmux.ts` (line 95), `handlers/wpcc.ts` (line 62). Shell operator blocking, field extraction, and ANSI stripping patterns have no inline comments explaining intent.
  - **Effort: S** | **Risk: Low** — Add 3–4 inline comments. No code change.
  - **Fixed**: Added JSDoc/inline comments to all three patterns.

- [x] **Missing site parameter gives unclear error** — `tools/mcp-server/src/index.ts` (~line 188). When no `site` is passed and no active site is set, the error message is `"Could not resolve Local run configuration for site: undefined"` instead of telling the user to run `local_wp_select_site` first.
  - **Effort: S** | **Risk: Low** — Add a guard with a helpful error message before resolution logic.
  - **Fixed**: Added guard in `resolveSite()` that catches empty/undefined site names with actionable message.

- [x] **Curl timeout handling gap in theme-crash-loop** — `experimental/theme-crash-loop.sh` (line 413). If curl times out, the headers file may not be written but subsequent code still tries to read it.
  - **Effort: S** | **Risk: Low** — Add file-existence check. Script is experimental.
  - **Fixed**: Added `[ ! -f "$metrics_file" ]` guard with fallback defaults.

- [ ] **Documentation bloat** — 84 markdown files totaling 24,358 lines. Only ~30% are written for human developers. The rest are AI agent context, internal project management, or boilerplate. Consider consolidating or archiving non-essential docs.
  - **Effort: L** | **Risk: Med** — Audit and consolidation touches many files. Risk of removing something still referenced. Better as a dedicated cleanup pass.

---

## Informational (Not Bugs)

- [ ] **`tools/wp-code-check/` is a git subtree** — Maintained as a separate upstream project. Changes in this directory should flow through the upstream repo, not be made directly here.

- [ ] **No rate limiting on MCP HTTP transport** — Not an issue for local development (localhost-only binding), but would need to be addressed if HTTP mode is ever exposed beyond localhost.

- [ ] **WPCC is regex-based, not AST-based** — By design. Heuristic patterns have ~5-10% false positive rate. Mitigated by baselines and comment suppression. Not a bug, just a known trade-off.

---

## Triage Summary

| Priority | Items | Fixed | Remaining |
|----------|------:|------:|------:|
| High | 4 | 3 | 1 (node_modules — verify on `development`) |
| Medium | 7 | 4 | 3 (sed portability, timeout config, pw-auth size) |
| Low | 9 | 7 | 2 (node version, doc bloat) |
| **Total actionable** | **20** | **14** | **6** |

### Remaining items by effort:
| Item | Effort | Risk |
|------|--------|------|
| Committed `node_modules` (verify) | M | Med |
| `sed -i.bak` portability | S | Low |
| Scattered timeout config | M | Med |
| `pw-auth` bash size | XL | High |
| Node.js version extraction | S | Low |
| Documentation bloat | L | Med |
