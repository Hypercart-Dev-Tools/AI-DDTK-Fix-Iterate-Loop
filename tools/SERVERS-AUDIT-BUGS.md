# servers-audit.sh — Bug Report

**Script:** `~/bin/ai-ddtk/tools/servers-audit.sh`
**Version:** as of 2026-04-10
**Reported:** 2026-04-11
**Severity:** Crash — script aborts before completing audit

---

## Bug 1: `local` keyword used outside a function (lines 1225, 1229, 1250)

**Error message:**
```
/Users/noelsaw/bin/ai-ddtk/tools/servers-audit.sh: line 1225: local: can only be used in a function
```

**Root cause:** Three `local` variable declarations at top-level scope (not inside any function). Bash requires `local` to be inside a function body.

**Affected lines:**
- Line 1225: `local autostart_services`
- Line 1229: `local web_services`
- Line 1250: `local keepalive_services`

**Context:** These are inside `if` blocks (lines 1222-1245 and 1247-1265) that detect Homebrew auto-start and KeepAlive conflicts, but the `if` blocks are at top-level, not wrapped in a function.

**Fix:** Either:
- (a) Remove the `local` keyword (just use bare variable names — acceptable at top level), or
- (b) Wrap the conflict-detection block in a function and call it

**Minimal fix (option a):**
```bash
# Line 1225: change
local autostart_services
# to
autostart_services=""

# Line 1229: change
local web_services
# to
web_services=""

# Line 1250: change
local keepalive_services
# to
keepalive_services=""
```

---

## Bug 2: `grep -Eq` with unescaped regex metacharacters from process names (line 361)

**Error message:**
```
grep: parentheses not balanced
```

**Root cause:** Line 361 interpolates `$lower_name` directly into a grep extended regex pattern:
```bash
printf '%s\n' "$BREW_RUNNING_NAMES" | grep -Eq "^${lower_name}$"
```

When a process name contains regex metacharacters (e.g., `GitHub Desktop Helper (Renderer`), the unescaped `(` creates an invalid ERE pattern.

**Triggered by:** Any process name in the `lsof` output that contains `(`, `)`, `[`, `]`, `+`, `*`, `?`, `{`, `}`, `|`, or `.`.

On this machine, `GitHub Desktop Helper (Renderer` and multiple `Code Helper (Plugin)` entries trigger it.

**Fix:** Use `grep -Fxq` (fixed-string, whole-line match) instead of `grep -Eq` with anchors:
```bash
# Line 361: change
printf '%s\n' "$BREW_RUNNING_NAMES" | grep -Eq "^${lower_name}$"
# to
printf '%s\n' "$BREW_RUNNING_NAMES" | grep -Fxq "$lower_name"
```

`-F` treats the pattern as a fixed string (no regex), `-x` matches the whole line (equivalent to `^...$` anchors).

---

## Bug 3: Broken symlink at ~/bin/servers-audit.sh

**Not a script bug**, but a deployment issue:
```
~/bin/servers-audit.sh -> ~/Documents/GH Repos/AI-DDTK/experimental/servers-audit.sh
```
The symlink target doesn't exist. The working copy is at `~/bin/ai-ddtk/tools/servers-audit.sh`.

**Fix:** Update the symlink:
```bash
ln -sf ~/bin/ai-ddtk/tools/servers-audit.sh ~/bin/servers-audit.sh
```

---

## Reproduction

```bash
bash ~/bin/ai-ddtk/tools/servers-audit.sh --output /tmp/test-audit.md --focus full
# Exits with code 1, incomplete output
```

## Environment

- macOS 15.6.1 (arm64)
- bash 3.2.57 (Apple default)
- Process list includes names with parentheses: `GitHub Desktop Helper (Renderer`, `Code Helper (Plugin)`
