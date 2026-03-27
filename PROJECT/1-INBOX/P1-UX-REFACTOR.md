---
Author: GitHub Copilot
Date: 2026-03-26
Status: INBOX
Goal: Reduce onboarding friction by turning AI-DDTK setup from a doc-driven process into a verified, discoverable, and safer product workflow.
---

# P1 UX Refactor

## Why This Project Exists

Recent user feedback exposed the same core failure in several forms:

- setup feels like a set of instructions to give an AI, not a product with a reliable happy path
- MCP installation and project wiring are not discoverable enough and do not guarantee live availability in the active editor session
- workflow prerequisites are scattered across multiple docs and hidden behind local assumptions
- some safety and verification steps are too easy for an agent to reinterpret or bypass
- some verification instructions are underspecified enough that agents either skip them or execute them dangerously broadly

The refactor goal is to make AI-DDTK feel like this:

1. Install AI-DDTK once.
2. Wire a project with one supported command.
3. Run one doctor/preflight command.
4. Use the workflow with explicit, validated prerequisites and safe defaults.

## Scope

In scope:

- onboarding and installation UX
- project MCP wiring UX
- readiness verification UX
- documentation hierarchy and prerequisite clarity
- guardrails around environment checks and search scope
- removal of maintainer-local paths, names, and environment assumptions from templates

Out of scope for this project:

- building brand-new AI-DDTK feature areas unrelated to onboarding and verification
- broad CLI redesign outside commands needed to improve setup and discovery
- editor-specific extension work beyond what is needed to improve setup UX

## Desired Outcomes

- a new user can get from install to first successful workflow without reading multiple overlapping docs
- project wiring is a first-class supported command, not an experimental side path
- setup verification reports real readiness states, including fallback states when MCP is unavailable
- canonical docs do not assume the maintainer's own LocalWP site names, file paths, users, or environment values
- safety checks block risky behavior rather than being writable configuration suggestions
- search and validation steps are scoped, bounded, and safe by default

## Success Metrics

- onboarding path reduced to install -> wire project -> doctor/preflight -> run workflow
- no canonical template file contains maintainer-specific local paths, hostnames, site names, usernames, or environment-variable assumptions
- docs present workflow prerequisites in one place before detailed instructions
- project readiness output distinguishes between built, wired, detected, and live-available MCP states
- no canonical instruction tells the agent to search an unbounded wp-content tree without exclusions or explicit scope

## Phase 1: Remove Hidden Assumptions

### Objective

Eliminate repo-shipped assumptions that make the toolkit appear tailored to one maintainer machine or one specific WordPress setup.

### Deliverables

- canonical prerequisite matrix for install and major workflows
- audited templates with no maintainer-local paths or environmental assumptions
- project wiring flow documented as a supported path rather than an implied agent task

### Tasks

- [ ] Audit all template and setup-facing files for maintainer-local absolute paths, site names, usernames, and environment-specific values.
- [ ] Remove any local path and environment-variable assumptions from the repo's template files.
- [ ] Replace examples that imply a default site name, admin account, or local folder naming convention with neutral placeholders and discovery steps.
- [ ] Consolidate install prerequisites and workflow prerequisites into a single top-level matrix in README.
- [ ] Rewrite project setup guidance so the default path is an explicit supported command, not "copy this file and tell the agent what to do."
- [ ] Add a short decision table that tells users when MCP is required, optional, or unavailable with CLI fallback.

### Candidate Files

- README.md
- README-AI-DDTK.md
- AGENTS.md
- templates/
- docs/WORDPRESS-TESTING-QUICKSTART.md
- docs/PW-AUTH-COMMANDS.md
- docs/CLI-REFERENCE.md

### Exit Criteria

- no shipped template contains maintainer-local absolute paths or env-specific assumptions
- docs no longer rely on implicit `admin` or maintainer site naming as the default setup story
- a new user can identify all prerequisites before starting setup

## Phase 2: Productize Wiring And Readiness

### Objective

Replace multi-doc setup reconstruction with explicit commands and machine-readable readiness checks.

### Deliverables

- supported `install.sh wire-project` command
- supported `doctor-project` or equivalent readiness command
- improved preflight output that reports useful runtime states instead of partial signals

### Tasks

- [ ] Promote `experimental/wire-project` into a supported `install.sh` subcommand.
- [ ] Ensure the supported wiring path handles `.mcp.local.json`, `.gitignore`, and agent-reference setup consistently.
- [ ] Add a `doctor-project` style command that verifies toolkit install, project wiring, editor config presence, MCP build state, and relevant workflow prerequisites.
- [ ] Update `preflight.sh` to distinguish between `built`, `configured`, `discoverable`, and `live session availability` where possible.
- [ ] Make verification mandatory in the onboarding path rather than optional.
- [ ] Clearly report fallback modes such as `MCP unavailable, CLI available` instead of treating setup as binary.

### Candidate Files

- install.sh
- preflight.sh
- experimental/wire-project
- README.md
- AGENTS.md
- docs/TROUBLESHOOTING.md

### Exit Criteria

- project wiring is one documented command
- readiness output is understandable without cross-referencing multiple docs
- a user can tell whether they are blocked, partially configured, or ready to proceed

## Phase 3: Harden Safety And Execution Defaults

### Objective

Make the system safer by removing ambiguous instructions and replacing editable safeguards with real boundaries.

### Deliverables

- safer non-production guard model
- scoped search and verification guidance
- workflow docs that start with discovery rather than assumptions

### Tasks

- [ ] Redesign the `WP_ENVIRONMENT_TYPE` safeguard so it is not satisfied merely by editing config in-place during setup.
- [ ] Require explicit user approval or an explicit override flag before changing environment-classification settings.
- [ ] Start auth and browser workflows with discovery steps for site URL, site name, and available user accounts.
- [ ] Replace broad grep/search instructions with scoped `rg`-based commands, explicit exclusions, and target-path guidance.
- [ ] Add file-count or directory-scope stop conditions for expensive validation steps.
- [ ] Audit docs and recipes for instructions that can be interpreted in unsafe or overly literal ways by agents.

### Candidate Files

- AGENTS.md
- docs/WORDPRESS-TESTING-QUICKSTART.md
- docs/PW-AUTH-COMMANDS.md
- docs/CLI-REFERENCE.md
- recipes/fix-iterate-loop.md
- recipes/weekly-ux-audit.md

### Exit Criteria

- safety guards cannot be trivially bypassed by agent self-editing
- verification/search steps are bounded and executable as written
- auth and site workflows begin with discovery rather than hardcoded assumptions

## Implementation Order

1. Phase 1 first, because hidden assumptions are contaminating docs, templates, and workflow expectations.
2. Phase 2 second, because a supported wiring and doctor flow removes most of the current setup confusion.
3. Phase 3 third, because safety and execution hardening depends on the clearer setup model from Phases 1 and 2.

## Risks

- documentation changes alone may improve clarity without fully reducing runtime confusion if no doctor command is added
- editor-specific MCP behaviors may remain inconsistent across clients even after clearer wiring docs
- replacing weak safeguards with stronger ones may expose real workflow dependencies that were previously papered over by docs

## Open Questions

- should `wire-project` remain local-only via `.mcp.local.json`, or should AI-DDTK support generating checked-in project config variants as well?
- how much live MCP availability can be detected from shell-side doctor commands versus editor-side runtime hooks?
- should user/account discovery become a dedicated helper command rather than staying as documented workflow steps?

## Related Documents

- README.md
- AGENTS.md
- README-AI-DDTK.md
- experimental/preflight.md
- fix-iterate-loop.md

5. Remove hidden assumptions by forcing discovery.
   Every workflow that needs a site or user should start by discovering them, not assuming them.
   Examples:
   - list Local sites before using one
   - fetch available admin users before choosing `admin`
   - confirm site URL rather than assuming `my-site.local`
   - never bake personal site names into canonical instructions
   The docs already partly say this in AGENTS.md, but the workflows should operationalize it.

6. Fix the safety model around `WP_ENVIRONMENT_TYPE`.
   If the intent is “do not run on production,” then:
   - do not tell the agent to change the value as part of normal setup
   - do not treat “set this constant” as a safety check
   - require an explicit user action or explicit flag before any tool edits environment classification
   Better options:
   - require a CLI flag like `--allow-nonprod-config-change`
   - require a human confirmation step
   - use multiple signals, not one mutable constant: host pattern, LocalWP context, wp option URL, and environment type together
   The key point: a guard the agent can satisfy by editing config is not a guard.

7. Replace broad grep instructions with scoped review commands.
   The safe default should be one of these:
   - changed files only via `git diff --name-only`
   - target plugin/theme directory only
   - `rg` with explicit excludes for .git, `node_modules`, `vendor`, hidden directories, and generated files
   - a maximum file count threshold with “stop and ask” behavior
   In other words, make the instruction executable without interpretation.

**Product Direction**
The toolkit should feel like this:

1. Install AI-DDTK once.
2. Wire a project with one command.
3. Run one doctor command.
4. Use one workflow command or one clear prompt.

Right now it feels more like:

1. Install tools.
2. Learn MCP.
3. Learn editor wiring.
4. Learn project wiring.
5. Learn which doc applies.
6. Tell the agent which steps to do.
7. Hope the agent interprets the intent correctly.

That is the core UX problem.

**Concrete Rewrite Priorities**
1. Make wire-project a supported install subcommand and surface it in README.md and install.sh.
2. Add a single prerequisites matrix to the README and link deeper docs from there.
3. Make setup verification mandatory, not optional.
4. Add a “live MCP unavailable, falling back to CLI” state explicitly in preflight/doctor output.
5. Rewrite all safety checks so they cannot be bypassed by agent self-editing.
6. Audit every grep/search instruction and scope it to target paths plus excludes.

**Bottom Line**
The user is not asking for better prose. They are asking for the toolkit to own state discovery, wiring, and safety boundaries instead of pushing that burden onto the human and the agent. That is the right diagnosis.

1. I can turn this into a prioritized UX issue list in a new project doc or inbox item.
2. I can draft the actual onboarding rewrite for README.md, AGENTS.md, and README-AI-DDTK.md.
3. I can implement the first structural fix by promoting wire-project into install.sh and tightening the preflight/doctor flow.