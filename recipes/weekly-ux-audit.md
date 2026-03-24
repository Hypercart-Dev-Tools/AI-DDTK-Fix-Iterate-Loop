# Recipe: Weekly UX Audit

> Catch doc rot, version drift, and onboarding regressions before users hit them.

## When to Run

- Weekly (Monday recommended — matches the CI cron)
- After any release that touches `install.sh`, `AGENTS.md`, `README.md`, or `bin/`

## How It Works

Steps 1-3 are **fully automated** via `tools/ux-audit.sh` and run weekly in CI (`.github/workflows/weekly-ux-audit.yml`). On failure, a GitHub issue is created automatically.

```bash
# Run locally anytime
bash tools/ux-audit.sh
```

| Check | What It Verifies |
|---|---|
| Version consistency | `install.sh` header matches latest `CHANGELOG.md` entry |
| Command-doc parity | Every `bin/*` tool appears in `AGENTS.md` + `CLI-REFERENCE.md`; every `install.sh` subcommand appears in `show_usage()` |
| Internal link check | All relative markdown links in onboarding docs resolve to existing files |

## Version Policy

The toolkit version appears in exactly **two places**:

1. **`CHANGELOG.md`** — canonical source of truth (includes date and description)
2. **`install.sh` line 4** — `# Version: X.Y.Z` (synced to CHANGELOG by this audit)

No other file should hardcode a version number.

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
