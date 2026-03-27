---
Author: AI Agent (Augment)
Date: 2026-03-22
Status: INBOX
Goal: Address 10 critical documentation and feature gaps identified in real-world AI-DDTK usage feedback
Priority: P1 (High Impact)
---

# AI-DDTK Documentation & Feature Improvement Plan

## Executive Summary

Real-world feedback from production WordPress development identified **10 critical gaps** in AI-DDTK documentation and tooling. This plan phases improvements across 6 phases with clear risk/effort ratings, enabling teams to adopt AI-DDTK faster and reduce debugging friction.

---

## Table of Contents

1. [High-Level Progress Checklist](#high-level-progress-checklist)
2. [Feedback Summary](#feedback-summary)
3. [Phase Breakdown](#phase-breakdown)
4. [Risk & Effort Matrix](#risk--effort-matrix)
5. [Implementation Details](#implementation-details)

---

## High-Level Progress Checklist

**NOTE FOR LLM: Mark items below as completed as work progresses. Update this section first in each work session.**

- [x] **Phase 1**: CLI Reference Documentation (pw-auth, wpcc, local-wp) ✅ COMPLETE
- [x] **Phase 2**: Troubleshooting Guide & Common Errors ✅ COMPLETE
- [x] **Phase 2.5**: README Consolidation & AGENTS.md Expansion (NEW)
- [x] **Phase 3**: WordPress Testing Quick Start (5-min setup)
- [x] **Phase 4**: CI/CD Integration Examples (GitHub Actions, GitLab CI) ✅ COMPLETE
- [x] **Phase 5**: Expand `pw-auth check dom` capabilities (multi-selector, assertions, screenshots) ✅ COMPLETE
- [ ] **Phase 6**: Feature Enhancements (env vars, multi-auth, logging)

**Overall Progress**: 6/7 phases complete (85.7%)

---

## Phase 1 Completion Status (2026-03-22)

✅ **Phase 1: COMPLETE** — CLI Reference Documentation

**Deliverables Completed**:
- ✅ `docs/CLI-REFERENCE.md` — Master reference for all commands (500+ lines)
- ✅ `docs/PW-AUTH-COMMANDS.md` — Detailed pw-auth guide (600+ lines)
- ✅ `docs/WPCC-COMMANDS.md` — Detailed wpcc guide (400+ lines)
- ✅ `docs/LOCAL-WP-COMMANDS.md` — Detailed local-wp guide (500+ lines)
- ✅ `README.md` — Added CLI Reference section with links
- ✅ `README.md` — Updated Tools table with reference links

**Content Coverage**:
- ✅ All command syntax and options documented
- ✅ Parameter descriptions and defaults
- ✅ Real-world examples for each command
- ✅ Output format examples (text, JSON, HTML)
- ✅ Exit codes and error handling
- ✅ Troubleshooting sections in each guide
- ✅ Common patterns and workflows
- ✅ Environment variable documentation

**Commit**: `338a773` — "docs: Phase 1 - Complete CLI Reference Documentation"
**Duration**: ~2 days
**Risk**: LOW ✅ | **Effort**: MEDIUM ✅

---

## Phase 4 Completion Status (2026-03-22)

✅ **Phase 4: COMPLETE** — CI/CD Integration Examples

**Deliverables Completed**:
- ✅ `examples/ci-cd/github-actions.yml` — Full GitHub Actions E2E workflow with parallel execution
- ✅ `examples/ci-cd/gitlab-ci.yml` — Full GitLab CI pipeline with artifacts and parallel matrix
- ✅ `docs/CI-CD-INTEGRATION.md` — Comprehensive CI/CD integration guide

**Content Coverage**:
- ✅ GitHub Actions workflow (service containers, secrets, artifacts)
- ✅ GitLab CI pipeline (cache, artifacts, variables)
- ✅ Ephemeral environment auth handling (re-login every run)
- ✅ Parallel test execution (matrix strategy for both platforms)
- ✅ Common CI issues and fixes documented
- ✅ Security best practices included

**Commit**: Phase 4 — CI/CD Integration Examples
**Duration**: ~3-4 days (estimated)
**Risk**: MEDIUM ✅ | **Effort**: MEDIUM ✅

**Deviations from plan**: No deviations from plan.

---

## Setup Status (2026-03-22)

✅ **Step 1**: Document moved to `2-WORKING`
✅ **Step 2**: Subtasks created (6 phases tracked in task list)
✅ **Step 3**: Progress checklist initialized
✅ **Step 4**: Ready for Phase 1 implementation
✅ **Step 5**: Commit & push (COMPLETE)
✅ **Phase 1**: CLI Reference Documentation (COMPLETE)

---

## Feedback Summary

### Feedback Items Addressed

| # | Issue | Category | Impact |
|---|-------|----------|--------|
| 1 | Missing `pw-auth` CLI reference | Documentation | HIGH |
| 2 | No WordPress testing quick start | Documentation | HIGH |
| 3 | No environment variable support | Feature | MEDIUM |
| 4 | Missing troubleshooting guide | Documentation | HIGH |
| 5 | No CI/CD integration examples | Documentation | MEDIUM |
| 6 | Auth cache metadata unclear | Feature | LOW |
| 7 | No dev-login-cli.php logging | Feature | LOW |
| 8 | 12-hour cache not explained | Documentation | MEDIUM |
| 9 | No Playwright test runner examples | Documentation | MEDIUM |
| 10 | No multi-auth state support | Feature | MEDIUM |

---

## Phase Breakdown

### Phase 1: CLI Reference Documentation
**Risk: LOW | Effort: MEDIUM | Duration: 2-3 days**

Create comprehensive CLI reference for all tools:
- `pw-auth` command reference (all subcommands, parameters, examples)
- `wpcc` command reference with output format examples
- `local-wp` wrapper documentation
- Exit codes and error handling

**Deliverables**:
- `docs/CLI-REFERENCE.md` (main reference)
- `docs/pw-auth-commands.md` (detailed pw-auth guide)
- Update README.md with link to CLI reference

---

### Phase 2: Troubleshooting Guide
**Risk: LOW | Effort: MEDIUM | Duration: 2-3 days**

Document common failure modes and solutions:
- Auth state expiration detection and recovery
- Playwright timeout debugging
- WP_ENVIRONMENT_TYPE production blocking
- DOM selector not found debugging
- Database connectivity issues

**Deliverables**:
- `docs/TROUBLESHOOTING.md` (comprehensive guide)
- Update AGENTS.md with troubleshooting section

---

### Phase 2.5: README Consolidation & AGENTS.md Expansion
**Risk: LOW | Effort: MEDIUM | Duration: 2-3 days**

Consolidate documentation to reduce drift and establish AGENTS.md as single source of truth:

**Rationale**:
- README.md (461 lines) and AGENTS.md (432 lines) have significant duplication
- Detailed sections appear in both files (pw-auth, WPCC, MCP setup, troubleshooting)
- High maintenance burden: changes must be mirrored in both files
- Solution: README becomes lightweight hub, AGENTS.md becomes comprehensive SOT

**Changes**:
- Move detailed pw-auth section from README → AGENTS.md
- Move detailed WPCC section from README → AGENTS.md
- Move MCP Server details from README → AGENTS.md
- Move troubleshooting section from README → AGENTS.md (consolidate with Phase 2)
- Simplify README to ~150 lines (Overview, Quick Start, Links, Structure, License)
- Add navigation table in README pointing to AGENTS.md sections
- Update all cross-references in both files

**Deliverables**:
- Simplified `README.md` (lightweight hub, ~150 lines)
- Expanded `AGENTS.md` (comprehensive SOT, ~600 lines)
- Updated cross-references in both files
- Clear navigation from README → AGENTS.md sections

**Benefits**:
- Single source of truth reduces drift risk
- Easier maintenance (one file to update)
- Clearer navigation (README for quick start, AGENTS.md for details)
- Scalable (adding new tools = 1 file to update)

---

### Phase 3: WordPress Testing Quick Start
**Risk: LOW | Effort: MEDIUM | Duration: 2-3 days**

Create beginner-friendly 5-minute setup guide:
- Fresh WordPress install setup
- dev-login-cli.php installation
- Simple Playwright example (form submission, menu check, DB query)
- Common use cases with working code

**Deliverables**:
- `docs/WORDPRESS-TESTING-QUICKSTART.md`
- Example scripts in `examples/playwright-basics/`

---

### Phase 4: CI/CD Integration Examples
**Risk: MEDIUM | Effort: MEDIUM | Duration: 3-4 days**

Provide production-ready CI/CD workflows:
- GitHub Actions workflow (pw-auth login → run tests)
- GitLab CI example
- Handling auth state in ephemeral environments
- Parallel test execution with multiple clones

**Deliverables**:
- `examples/ci-cd/github-actions.yml`
- `examples/ci-cd/gitlab-ci.yml`
- `docs/CI-CD-INTEGRATION.md`

---

### Phase 5: Expand `pw-auth check dom` Capabilities
**Risk: LOW | Effort: MEDIUM | Duration: 2-3 days**

Make `check dom` powerful enough that agents don't need a separate test runner for verification steps:
- Multi-selector checks in a single call (check 3 elements, get one result)
- Built-in assertions (element visible, text contains, attribute equals)
- Screenshot capture on failure (artifact under `temp/playwright/checks/`)
- Wait-for-condition support (element appears within timeout, useful for AJAX-rendered content)

**Benefits**:
- Agents can verify complex page state without writing throwaway test files
- Fix-iterate loops get richer pass/fail signals (not just "selector found or not")
- Screenshots give humans visual proof when reviewing agent work
- Stays within AI-DDTK's scope (tool for agents, not a test framework)

**Deliverables**:
- Updated `pw-auth check dom` with multi-selector, assertions, and screenshot support
- Updated `docs/PW-AUTH-COMMANDS.md` with new options and examples

---

### Phase 6: Feature Enhancements
**Risk: MEDIUM | Effort: HIGH | Duration: 5-7 days**

Implement requested features:
- Environment variable support (.env loading, auto-detection)
- Multi-auth state support (multiple sites/users)
- Auth cache metadata enrichment
- dev-login-cli.php logging
- 12-hour cache documentation

**Deliverables**:
- Updated `pw-auth` with env var support
- Updated `dev-login-cli.php` with logging
- Updated `pw-auth status` with metadata
- Feature documentation

---

## Risk & Effort Matrix

```
        LOW EFFORT          MEDIUM EFFORT       HIGH EFFORT
LOW     Phase 1, 2, 3       Phase 4, 5          —
RISK    (Quick wins)        (Moderate scope)

MED     —                   Phase 6             —
RISK                        (Feature work)

HIGH    —                   —                   —
RISK
```

**Recommended Execution Order**:
1. Phase 1 (foundation for all others)
2. Phase 2 (high impact, low effort)
3. Phase 3 (enables adoption)
4. Phase 4 (production readiness)
5. Phase 5 (advanced usage)
6. Phase 6 (polish & features)

---

## Implementation Details

### Phase 1: CLI Reference Documentation

**Files to Create**:
- `docs/CLI-REFERENCE.md` — Master reference
- `docs/pw-auth-commands.md` — Detailed pw-auth guide
- `docs/wpcc-commands.md` — WPCC reference
- `docs/local-wp-commands.md` — local-wp wrapper guide

**Content Structure**:
```
- Command overview
- Syntax and parameters
- Examples (text and JSON output)
- Exit codes
- Common errors and fixes
- Related commands
```

**Update Existing Files**:
- README.md: Add "CLI Reference" section
- AGENTS.md: Link to CLI reference

---

### Phase 2: Troubleshooting Guide

**File to Create**:
- `docs/TROUBLESHOOTING.md`

**Sections**:
1. Auth state issues (expiration, validation, re-auth)
2. Playwright issues (timeouts, browser launch, DOM selectors)
3. WordPress environment issues (WP_ENVIRONMENT_TYPE, permissions)
4. Database connectivity (MySQL, WP-CLI)
5. MCP server issues (startup, connectivity)
6. Performance issues (slow tests, timeouts)

**Each Section**:
- Problem description
- Root cause
- Diagnostic steps
- Solution
- Prevention tips

---

### Phase 3: WordPress Testing Quick Start

**File to Create**:
- `docs/WORDPRESS-TESTING-QUICKSTART.md`

**Example Scripts**:
- `examples/playwright-basics/form-submission.js`
- `examples/playwright-basics/menu-verification.js`
- `examples/playwright-basics/database-query.js`

**Content**:
1. Prerequisites (5 min)
2. Install dev-login-cli.php (2 min)
3. First test (3 min)
4. Common patterns (forms, menus, DB)
5. Debugging tips

---

### Phase 4: CI/CD Integration Examples

**Files to Create**:
- `examples/ci-cd/github-actions.yml`
- `examples/ci-cd/gitlab-ci.yml`
- `docs/CI-CD-INTEGRATION.md`

**GitHub Actions Workflow**:
```yaml
- Checkout code
- Install AI-DDTK
- Setup WordPress (LocalWP or Docker)
- pw-auth login
- Run Playwright tests
- Upload artifacts
```

**GitLab CI Workflow**:
```yaml
- Similar structure
- Use GitLab-specific features (artifacts, cache)
```

---

### Phase 5: Expand `pw-auth check dom` Capabilities

**New `check dom` options**:
- `--selectors "#el1, .el2, [data-id]"` — check multiple selectors, report each
- `--assert visible|hidden|text-contains|attr-equals` — built-in assertions
- `--screenshot on-failure|always|never` — capture page state as PNG
- `--wait-for <selector>` + `--timeout <ms>` — wait for AJAX-rendered content

**Example**:
```bash
pw-auth check dom \
  --url http://site.local/wp-admin/ \
  --selectors "#wpadminbar, .wrap h1" \
  --assert visible \
  --screenshot on-failure \
  --user admin --format json
```

**Output contract**: returns array of check results, each with `selector`, `status` (`ok|not_found|assertion_failed`), and optional `screenshot_path`

---

### Phase 6: Feature Enhancements

**Enhancement 1: Environment Variable Support**
- Load `.env` file in pw-auth
- Auto-detect `$VALET_SITES`, `$WP_PATH`
- Support `--site-url` with auto-discovery

**Enhancement 2: Multi-Auth State Support**
- `pw-auth login --name site1` (named sessions)
- `pw-auth list` (show all cached states)
- `pw-auth use site1` (switch sessions)

**Enhancement 3: Auth Cache Metadata**
- `pw-auth status` shows: path, size, last-used, expiry countdown
- JSON output for scripting

**Enhancement 4: dev-login-cli.php Logging**
- Log token generation (timestamp, user, expiry)
- Log token consumption (success/failure)
- Log token expiration
- Write to `wp-content/debug.log`

**Enhancement 5: 12-Hour Cache Documentation**
- Explain why 12 hours
- Document validation mechanism
- Explain behavior during site downtime
- Document manual invalidation

---

## Next Steps

1. **Confirm Scope**: Review this plan with stakeholders
2. **Assign Resources**: Allocate team members to phases
3. **Create Tracking**: Move to `2-WORKING` and create subtasks
4. **Begin Phase 1**: Start with CLI reference documentation
5. **Iterate**: Complete phases in recommended order, updating checklist

---

## Questions & Pushback

**Q: Should we prioritize features (Phase 6) before documentation?**
A: No. Documentation (Phases 1-5) enables adoption and reduces support burden. Features should follow once docs are solid.

**Q: Can phases run in parallel?**
A: Yes, but Phase 1 should complete first (it's the foundation). Phases 2-3 can run in parallel. Phases 4-5 depend on Phase 3.

**Q: What about backward compatibility?**
A: All features in Phase 6 are additive (no breaking changes). Existing workflows continue to work.

**Q: How do we measure success?**
A: Track: (1) Documentation completeness, (2) User feedback on clarity, (3) Adoption metrics, (4) Support ticket reduction.

---

## Approval & Sign-Off

- [ ] Scope approved
- [ ] Risk/effort ratings accepted
- [ ] Execution order confirmed
- [ ] Resources allocated
- [ ] Ready to move to `2-WORKING`

