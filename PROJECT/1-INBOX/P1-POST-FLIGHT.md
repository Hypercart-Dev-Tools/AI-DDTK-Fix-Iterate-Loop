---
title: "Post-Flight Session Cleanup Script"
status: inbox
priority: P1
created: 2026-04-11
updated: 2026-04-11
author: noelsaw
goal: 
---

# Post-Flight Session Cleanup Script

## Overview

**Status**: ✅ DRAFT COMPLETE
**Location**: `experimental/post-flight.sh`
**Purpose**: Solo developer post-flight session cleanup — ensures 4X4.md, CHANGELOG.md, MEMORY.md are synced, optionally commits and pushes.

---

## Design Decision: Solo Developer Context

The original analysis included pushback on auto-commit/push risks. However, for solo developers on personal projects, the risk profile changes:

- No surprise team impacts
- No mid-branch conflicts from others
- Friction of "lazy closes" is real (forgotten commits, stale docs)

**Decision**: Make commit/push opt-in with `--commit` / `--push` flags, but allow fully automated mode with `--force` for trusted contexts.

---

## Analysis & Feedback on "post-flight" Script

**Good idea.** This addresses a real friction point. But let me push back on scope and add some nuances based on what `servers-preflight.sh` and `servers-audit.sh` do well.

### ✅ What You've Got Right

1. **The Problem**: Lazy commits are real. Docs get stale. Developers close laptops without pushing.
2. **Two Invocation Paths**: Terminal + VS Code agent orchestration is the right pattern.
3. **Three Core Checks**: 4X4.md, CHANGELOG.md, MEMORY.md—smart choices for project health.

### 🤔 What I'd Reconsider

#### **1. Scope Creep: Commit + Push Behavior is Dangerous**

`servers-audit.sh` and `servers-preflight.sh` follow a **read-only or gated** model:
- They **report**, **detect conflicts**, **emit events**—but don't auto-execute risky operations
- They let *humans or agents* decide on commits/pushes

**Your script should:**
- **Report what's dirty** (unstaged changes, uncommitted files)
- **Check doc freshness** (4X4.md vs git log, CHANGELOG vs last commit date)
- **Suggest remedies**, but **NOT auto-commit/push** unless explicitly opted in with a flag like `--force` or `--auto-commit`

**Why?**
- Developers should **see what they're committing**
- Auto-push can surprise teams (what if someone's mid-branch?)
- Staged changes might be intentionally held back

#### **2. Missing: Pre-Commit Validation Gates**

Before committing, check:
- **Staged but incomplete**: e.g., CHANGELOG.md added but version bump in main file not done
- **Sensitive data leaks**: Check for `.env`, credentials, auth tokens (gitignored files accidentally staged?)
- **Broken builds**: Quick syntax check (PHP `php -l`, Python `-m py_compile`, JS `node --check`) 
- **Test failures**: If test suite is fast, run it

`servers-audit.sh` does this with **event hooks**—your script could emit events at each stage so an agent can gate it.

#### **3. Missing: MEMORY.md Context**

MEMORY.md is special—it's *session-scoped documentation*. The script should:
- Check if MEMORY.md exists and is recent
- **Archive it** (move to `PROJECT/1-INBOX/MEMORY-<timestamp>.md`) on commit, so the next session starts fresh
- Preserve context trails without bloat

#### **4. Missing: Diff Summary for Commit Message**

Your script should:
- Auto-generate a **summary of changes** from git diff
- Suggest a commit message (e.g., "docs: Updated 4X4.md, CHANGELOG.md for session ending 2026-04-05")
- Let human/agent review before committing

#### **5. Branch Safety**

Check:
- Are we on the right branch? (e.g., `development` vs `main`—don't accidentally push to `main`)
- Is the upstream tracking set correctly?
- Do we have uncommitted changes that would be lost?

### 🎯 Revised Proposal

```bash
#!/usr/bin/env bash
# post-flight.sh — Session cleanup & doc synchronization
#
# Ensures 4X4.md, CHANGELOG.md, MEMORY.md are synced after session.
# Reports findings, suggests fixes, but does NOT auto-commit/push unless --auto-commit.
#
# Usage:
#   post-flight.sh [--auto-commit] [--push] [--no-validate] [--hook <script>]
#
# Exit codes:
#   0 = OK, all docs fresh, working tree clean
#   1 = WARN, docs stale or unstaged changes (remediation suggested)
#   2 = ERROR, missing files or config issues
#
# With --auto-commit:
#   - Commits staged changes with auto-generated message
#   - Archives MEMORY.md if present
#   - With --push, pushes to upstream
#
# With --hook:
#   - Calls hook at each stage (like servers-audit.sh)
#   - Hook can gate, log, or react to findings

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

AUTO_COMMIT=0
PUSH_AFTER=0
SKIP_VALIDATION=0
HOOK_SCRIPT=""
JSON_EVENTS=0
DRY_RUN=0

# ─── Checks ───────────────────────────────────────────────────────────────────

check_4x4() {
    # 4X4.md exists, is recent (within last session), checked against CHANGELOG
    # Return: "ok" | "missing" | "stale" | "mismatch"
}

check_changelog() {
    # CHANGELOG.md has an entry for today's date
    # Return: "ok" | "missing" | "stale"
}

check_memory() {
    # MEMORY.md exists, should be archived at post-flight if present
    # Return: "fresh" | "missing" | "should_archive"
}

check_git_state() {
    # Unstaged changes? Untracked files? On right branch?
    # Return: "clean" | "dirty" | "needs_push"
}

validate_build() {
    # Quick syntax checks if not --no-validate
    # Return: "ok" | "error:<message>"
}

emit_event() {
    # Like servers-audit.sh
}

suggest_commit_message() {
    # Auto-generate from git diff
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    # 1. Report findings
    # 2. Suggest remedies
    # 3. If --auto-commit, commit & optionally push
    # 4. Archive MEMORY.md if present
    # 5. Return exit code
}
```

### 🎬 Integration with VS Code Agent

The agent could call it like:
```bash
post-flight.sh --hook ./agent-hook.sh --json-events \
  && git log -1 --oneline \
  || echo "Session cleanup needed"
```

The hook receives events like:
- `check:4x4` — 4X4.md state
- `check:changelog` — CHANGELOG.md state
- `check:memory-duplicates` — Claude Code memory duplicate scan results
- `check:git` — git working tree state
- `validate:build` — syntax check results
- `suggest:commit` — proposed commit message
- `action:commit` — actually committing (agent can gate this)

### 🤔 Still Dumb?

Not dumb—it's **solving a real problem**. But I'd recommend:

1. **Don't auto-commit by default**—make it opt-in with `--auto-commit`
2. **Use the event/hook pattern** from `servers-audit.sh`—lets agents orchestrate without you baking in every decision
3. **Validate before committing**—quick syntax check + git state sanity
4. **Archive MEMORY.md at post-flight**—keeps it from growing and cluttering the repo
5. **Generate commit messages from diffs**—human-friendly, not "Lazy commit"

**Thoughts? Should I sketch out a full draft?**

---

## ✅ Implementation Complete

The script has been drafted and placed at `experimental/post-flight.sh`.

### Key Features

#### **Default Behavior (No Flags)**
```bash
post-flight.sh
```
- ✓ Checks 4X4.md, CHANGELOG.md, MEMORY.md freshness
- ✓ Scans Claude Code memory for conflicted duplicates (orphans, broken links, duplicate topics)
- ✓ Reports git state (dirty, untracked, branch info)
- ✓ Runs quick build validation (PHP syntax check, etc.)
- ✓ **NO commit, NO push** — just reporting
- Exit: 0 (clean) or 1 (issues found)

#### **Commit Mode**
```bash
post-flight.sh --commit
```
- Runs all checks (as above)
- Prompts: "Continue with commit?" `[y/N]`
- If yes: stages all changes, commits with auto-generated message
- Exit: 0 (success) or 1 (user cancelled)

#### **Push Mode**
```bash
post-flight.sh --push
```
- Implies `--commit`
- After commit, prompts: "Push to remote?" `[y/N]`
- If yes: pushes to origin
- Exit: 0 (success) or 1 (user cancelled at either prompt)

#### **Force Mode (Automation)**
```bash
post-flight.sh --push --force
```
- Skips ALL confirmation prompts
- Archives MEMORY.md, commits, pushes automatically
- Exit: 0 (success) or 2 (error)
- **Use case**: cron jobs, CI/CD, agent automation

#### **Dry-Run Mode**
```bash
post-flight.sh --push --dry-run
```
- Shows what WOULD happen, but doesn't execute
- Useful for testing, previewing before automation

### Behavior Details

#### **Checks Performed**

1. **4X4.md** — Exists and accessible
2. **CHANGELOG.md** — Exists and accessible
3. **Memory Duplicates** — Scans Claude Code auto-memory directory for orphans, broken links, duplicate topics, and missing frontmatter
4. **Git State** — Current branch, modified files, untracked files
5. **Build Validation** — PHP syntax check (if available)

#### **Commit Message**
Auto-generated:
```
docs: Session cleanup — updated docs and archived MEMORY.md
```

#### **Memory Duplicate Detection**
Scans `~/.claude/projects/<project-hash>/memory/` for:
- Orphaned `.md` files not linked from `MEMORY.md` index
- Broken links in `MEMORY.md` pointing to missing files
- Duplicate topics (3+ files with the same `type` frontmatter)
- Missing frontmatter (`name`, `description`, `type`)

Reports findings only — does not auto-fix or archive.

### Integration with Agents

The script emits **structured events** that agents can hook into:

```bash
post-flight.sh --push --hook ./agent-hook.sh
```

**Agent Hook Protocol**: Hook receives `<script> <event-name> '<json-payload>'`

**Example events:**
```json
{ "event": "check:4x4", "status": "ok" }
{ "event": "check:git", "status": "dirty", "branch": "development", "modified": 5 }
{ "event": "action:commit", "message": "docs: Session cleanup...", "sha": "72c6768" }
{ "event": "complete", "status": "success" }
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success — all checks passed |
| 1 | Warning — docs stale, git dirty, or user cancelled |
| 2 | Error — missing files, git failed, validation error |

### TODOs / Future Enhancements

- [ ] Stale doc detection (compare timestamps vs git log)
- [ ] Editable commit message (allow user review/edit)
- [ ] Pre-commit validation (run tests, linters if configured)
- [ ] Selective archiving (different locations by file type)
- [ ] Rollback support (easy undo if push fails)
- [ ] Config file support (`.post-flight.toml` per-repo settings)
