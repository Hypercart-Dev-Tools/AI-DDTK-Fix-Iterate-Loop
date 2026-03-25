# Recipe: Weekly UX Audit

> Catch doc rot, version drift, and onboarding regressions before users hit them.

## Who's this doc is for

For maintainers and contributors of AI-DDTK OSS Project. And if you are keeping a local copy of the repo and updating the docs for yourself.

## How to Use This Document

**Users:** Ask your AI coding agent to "run the weekly UX audit" or "run the UX audit recipe." The agent will execute the automated script (Steps 1-3), then perform the AI-assisted review steps (Steps 4-5) by scanning the relevant files for the issues described below.

**AI agents:** Run `bash tools/ux-audit.sh` for automated checks first. Then perform Steps 4-5 by reading the referenced files and applying the checklists below. Use probabilistic scanning — you don't need to verify every line, but sample enough to catch patterns (e.g., spot-check 5-10 error paths in `install.sh`, compare 3-4 key facts between README and AGENTS). Report findings in the output format at the bottom of this doc.

## When to Run

- Weekly (Monday recommended — matches the CI cron)
- After any release that touches `install.sh`, `AGENTS.md`, `README.md`, or `bin/`

## How It Works

Steps 1-3 are **fully automated** via `tools/ux-audit.sh` and run weekly in CI (`.github/workflows/weekly-ux-audit.yml`). On failure, a GitHub issue is created automatically. Steps 4-5 are **AI-assisted** — designed to be run by an LLM agent on request.

```bash
# Run locally anytime (Steps 1-3)
bash tools/ux-audit.sh
```

| Check | What It Verifies | Type |
|---|---|---|
| Version consistency | `install.sh` header matches latest `CHANGELOG.md` entry | Automated |
| Command-doc parity | Every `bin/*` tool appears in `AGENTS.md` + `CLI-REFERENCE.md`; every `install.sh` subcommand appears in `show_usage()` | Automated |
| Internal link check | All relative markdown links in onboarding docs resolve to existing files | Automated |
| Error message quality | Every failure path in `install.sh` gives a clear next action | AI review |
| Doc hierarchy consistency | README is a hub (no duplicated detail), AGENTS.md is the SSOT, no orphaned root docs | AI review |

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

## Step 5: Doc Hierarchy Consistency (AI Review)

**Goal:** The three documentation levels stay clean — README as hub, AGENTS.md as SSOT, detailed docs as reference. No duplicated or conflicting information across levels.

The doc hierarchy is:

```
README.md (hub — brief, links out)
  -> AGENTS.md (SSOT — operational detail for agents and humans)
       -> docs/*.md, recipes/*.md (deep reference)
```

### 5a: README stays a hub

- [ ] README should **not** contain detailed usage instructions, full command examples, or implementation details — those belong in AGENTS.md or docs/
- [ ] Feature descriptions in README should be 1-2 sentences max with a link to the detailed doc
- [ ] Any table in README that duplicates an AGENTS.md table is a drift risk — README should link, not copy

### 5b: No conflicting facts between levels

Spot-check these high-drift items — compare the value in README, AGENTS.md, and the source of truth:

- [ ] **MCP tool count**: compare README's "What's Inside" table, AGENTS.md's "Available MCP Tools" table, and the actual tool list in `tools/mcp-server/src/`
- [ ] **MCP Adapter ability count**: compare README and `docs/mcp-adapter-abilities.md`
- [ ] **Fix-Iterate Loop guardrails** (5 fail / 10 total): compare README, AGENTS.md, and `fix-iterate-loop.md`
- [ ] **pw-auth cache duration** (12h default): compare AGENTS.md and `docs/PW-AUTH-COMMANDS.md`

### 5c: No orphaned root-level docs

- [ ] List all `*.md` files in the repo root. Each should have a clear purpose:
  - `README.md`, `AGENTS.md`, `CHANGELOG.md`, `CLAUDE.md`, `4X4.md`, `fix-iterate-loop.md` — expected
  - Any other `.md` file in the root is suspect — check if it's referenced anywhere and whether its content is covered by an existing doc
- [ ] No scratch notes, dump files, or one-off docs should live in the root

---

## Output Format

Summarize findings as:

```
PASS  [check description]
FAIL  [check description] — [specific issue and fix]
```

If fixes are applied, update `CHANGELOG.md` with a new patch version entry.

## CI Integration

Steps 1-3 run automatically every Monday via `.github/workflows/weekly-ux-audit.yml`. Failures create a GitHub issue automatically. Steps 4-5 are designed to be triggered by a user asking their AI agent to run this recipe.
