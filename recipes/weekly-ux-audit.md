# Recipe: Weekly UX Audit

> Catch doc rot, version drift, and onboarding regressions before users hit them.

## When to Run

- Weekly (Monday recommended — matches the CI cron)
- After any release that touches `install.sh`, `AGENTS.md`, `README.md`, or `bin/`

## Quick Reference

```
1. Version consistency   (install.sh vs CHANGELOG.md)
2. Command-doc parity    (bin/* vs AGENTS.md + CLI-REFERENCE.md)
3. Internal link check   (all .md cross-references resolve)
4. Error message review  (AI reads install.sh error paths)
```

## Automated Pre-Check

Run the script first to get machine-checked results for Steps 1-3:

```bash
bash tools/ux-audit.sh
```

Then proceed with Step 4 below (requires AI judgment).

---

## Version Policy

The toolkit version appears in exactly **two places**:

1. **`CHANGELOG.md`** — canonical source of truth (includes date and description)
2. **`install.sh` line 4** — `# Version: X.Y.Z` (synced to CHANGELOG by this audit)

No other file should hardcode a version number. Docs like `AGENTS.md` and `TROUBLESHOOTING.md` carry a "Last updated" date only and link to CHANGELOG.md for version history.

---

## Step 1: Version Consistency

**Goal:** `install.sh` header version matches the latest `CHANGELOG.md` entry.

- [ ] Run: `grep "^# Version:" install.sh`
- [ ] Run: `head -20 CHANGELOG.md | grep "^## \["`
- [ ] Compare — they must match
- [ ] If mismatch: update `install.sh` line 4 to match CHANGELOG

---

## Step 2: Command-Doc Parity

**Goal:** Every CLI tool that exists is documented; every documented tool exists.

- [ ] List tools: `ls -1 bin/` (skip directories like `pw-auth-helpers/`)
- [ ] For each tool, verify it appears in:
  - `AGENTS.md` "Available Tools" table
  - `docs/CLI-REFERENCE.md`
- [ ] List install.sh subcommands (from the `case` statement): `update`, `update-wpcc`, `setup-wpcc`, `setup-mcp`, `doctor-playwright`, `status`, `uninstall`
- [ ] Verify each subcommand appears in:
  - `install.sh` `show_usage()` help text
  - `README.md` maintenance/commands section
- [ ] Flag any undocumented tools or phantom references to removed tools

---

## Step 3: Internal Link Validation

**Goal:** No broken cross-references in onboarding docs.

- [ ] Extract all relative markdown links from: `README.md`, `AGENTS.md`, `docs/*.md`, `recipes/*.md`
- [ ] For each link target, verify the file exists on disk
- [ ] For anchor links (`#section-name`), verify the heading exists in the target file
- [ ] Flag broken links with `file → target` location

---

## Step 4: Error Message Quality (AI Review)

**Goal:** Every failure path in `install.sh` gives the user a clear next action.

- [ ] Read all `RED`-colored echo lines in `install.sh` (`echo -e "${RED}..."`)
- [ ] For each error path, verify:
  - It names what specifically failed
  - It provides a concrete fix command (not just "something went wrong")
  - It uses plain language (no unexplained jargon)
- [ ] Review `show_usage()` — is it clear for a first-time user?
- [ ] Review `print_next_steps_block()` — are next steps complete and correct?
- [ ] Spot-check: would a developer unfamiliar with AI-DDTK know what to do after each error?

---

## Output Format

Summarize findings as:

```
PASS  [check description]
FAIL  [check description] — [specific issue and fix]
```

If fixes are applied, update `CHANGELOG.md` with a new patch version entry.

## CI Integration

This audit runs automatically every Monday via `.github/workflows/weekly-ux-audit.yml`. Failures create a GitHub issue automatically.
