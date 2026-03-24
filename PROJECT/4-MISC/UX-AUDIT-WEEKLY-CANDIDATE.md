# Weekly UX Audit Checklist

Purpose: A lightweight, repeatable weekly UX audit to catch friction early and improve first-time and recurring user workflows.

## Problem Statement
AI-DDTK has strong technical capabilities, but user-facing workflows can drift toward complexity over time. Without a recurring UX review, onboarding friction, confusing docs, and inconsistent command outcomes can accumulate and reduce adoption.

## Goal Statement
Run one focused UX audit each week to identify the top usability gaps, prioritize fixes, and keep the toolkit approachable for new and returning users.

## Anti-Goals
- Do not redesign core architecture during this audit.
- Do not convert this into a full QA or security audit.
- Do not expand scope beyond 3 high-impact UX improvements per week.
- Do not promote optional/experimental workflows as default paths.

## Weekly Reset Rules
- At the start of each week, update `Week Of` and uncheck all checklist items.
- Keep prior weeks as short summaries in `Weekly Outcomes`.
- Carry forward unfinished items only if still high impact.

## Weekly Audit Header
- Week Of: YYYY-MM-DD
- Audit Owner:
- Target Persona: New user | Returning user | Maintainer
- Primary Journey: Install | First command | Auth flow | Scan flow | MCP setup | Other

## Weekly Checklist
- [ ] Confirm the problem and target user journey for this week.
- [ ] Run the journey from a clean shell/session and note friction points.
- [ ] Verify command discoverability (`--help`, docs links, obvious next steps).
- [ ] Verify error messages are actionable (clear cause + fix command).
- [ ] Verify defaults are safe and non-destructive.
- [ ] Verify optional workflows are clearly labeled as optional/experimental.
- [ ] Identify and rank top 3 UX issues by user impact.
- [ ] Define fix scope for each issue (small, medium, large).
- [ ] Link fixes to owners/issues/PRs.
- [ ] Record outcomes in `Weekly Outcomes` and update [4X4.md](../4X4.md).

## Weekly Outcomes
Use one block per week:

### YYYY-MM-DD
- Top UX Issues:
  - [ ] Issue 1:
  - [ ] Issue 2:
  - [ ] Issue 3:
- Actions Created:
  - [ ] Action 1 (owner/link):
  - [ ] Action 2 (owner/link):
  - [ ] Action 3 (owner/link):
- Notes:
