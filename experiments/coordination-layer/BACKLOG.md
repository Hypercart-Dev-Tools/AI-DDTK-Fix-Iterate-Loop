# Trinity hand-test backlog

Tasks seeded for the Day 5 real-agent run. After `tick next --agent <YOUR-ID>` returns a task ID, look it up here for the description and acceptance criteria.

---

## TASK-A — Fix `local` outside function in `tools/servers-audit.sh`

**Scope:** `tools/servers-audit.sh`

**Priority:** 10

**Problem:** Lines 1225, 1229, 1250 use the `local` keyword at top-level scope (outside any function). Bash refuses with `local: can only be used in a function` and the script crashes before completing the audit.

**Fix:** Replace `local <var>` with `<var>=""` on those three lines (or wrap the surrounding `if` blocks in a function and call it). The minimal fix is dropping `local` and initializing bare — see the prescribed fix in the reference doc.

**Reference:** `tools/SERVERS-AUDIT-BUGS.md` (Bug 1).

**Acceptance:**
- `bash tools/servers-audit.sh --output /tmp/audit-test.md --focus full` runs without the `local: can only be used in a function` error. (It may still hit Bug 2 on line 361 — that's TASK-C's responsibility.)

---

## TASK-B — Add `--help` to `bin/wire-project`

**Scope:** `bin/wire-project`

**Priority:** 10

**Problem:** The script has no `--help` / `-h` flag. Sibling scripts in `bin/` (`pw-auth`, `mcp-local-config`, `wpcc`) all have help text. Inconsistent UX makes the script harder to discover and use.

**Fix:** Add a `show_help()` function (or equivalent) with usage info, supported flags, and a one-line description. Wire `--help` and `-h` into the existing argument parser so they call it and exit 0.

**Acceptance:**
- `bin/wire-project --help` prints usage and exits 0.
- `bin/wire-project -h` does the same.
- Help text includes a one-line description, the synopsis, and at least the existing flags (read the script to enumerate them).

---

## TASK-C — Fix `grep -Eq` regex injection in `tools/servers-audit.sh`

**Scope:** `tools/servers-audit.sh`

**Priority:** 5

**Problem:** Line 361 interpolates `$lower_name` (a process name from `lsof`) directly into a `grep -Eq` extended-regex pattern. Process names containing regex metacharacters — `(`, `)`, `[`, `]`, `+`, `*`, `?`, `{`, `}`, `|`, `.` — cause `grep: parentheses not balanced` and crash the audit. On a typical macOS dev machine this triggers from `GitHub Desktop Helper (Renderer`, `Code Helper (Plugin)`, etc.

**Fix:** Replace `grep -Eq "^${lower_name}$"` with `grep -Fxq "$lower_name"`. The `-F` flag treats the pattern as a fixed string (no regex), `-x` matches whole-line — equivalent semantics, no injection.

**Reference:** `tools/SERVERS-AUDIT-BUGS.md` (Bug 2).

**Acceptance:**
- `bash tools/servers-audit.sh ...` does not produce `grep: parentheses not balanced` even when `lsof` output contains process names with parentheses.
- The match semantics are unchanged for normal process names.

**⚠️ Path overlap with TASK-A.** Both tasks edit `tools/servers-audit.sh`. The Trinity protocol's path-scoping should serialize them — only one agent can claim `tools/servers-audit.sh` at a time. If `tick claim TASK-C` returns `lost:` (or `tick next` doesn't return TASK-C), wait for TASK-A's owner to run `tick done`, then call `tick next` again.
