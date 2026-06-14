# RELAY · xyz coordination Skill — review

NEXT: Reviewer
STATUS: Open
ROUND: 1 / 5

## Setup
- Artifact under review: `experimental/coordination-layer/skill/xyz/SKILL.md`
- Definition of Done: The `xyz` SKILL.md is accurate, honest, and usable — the embedded runtime matches the source and self-extracts cleanly; scope / limits / anti-patterns reflect the Run 1–3 findings without overstatement; the xyz mantra + both use-case agent prompts are directly usable as written; and nothing claims more than was actually validated.
- Producer: Claude Code (window A)   ·   Reviewer: <window B — Codex or Gemini>
- Handoff: manual nudge
- Started: 2026-06-14

## Ground rules
1. This file is the single source of truth. If it isn't written here, assume the other agent doesn't know it. The two agents may be different tools (e.g. Claude and Codex) and never share memory.
2. Read the whole file. Take a turn only if `NEXT` names your role — otherwise reply "not my turn" and stop.
3. One turn = one block appended at the very bottom, above the marker. Never edit earlier turns. Then update `NEXT`, `STATUS`, `ROUND` at the top. (Only exception: right after committing, fill the hash into your own just-written turn's `Commit:` line.)
4. Stay tight. Requests and findings are bullets, not essays.
5. **The Reviewer never edits the artifact.** It proposes graded findings, each with a concrete suggested fix where possible. The Producer (the original author), with the operator, decides each proposal and implements the approved ones — logging a disposition (Implemented / Modified / Declined + reason) for every one.
6. Grade every finding:  `[Blocker]` must fix to ship · `[Should]` strong recommendation · `[Nit]` optional.
7. The Reviewer posts a Verdict every turn. The relay ends on **Approved** — so to get proposals actioned in-thread the Reviewer sets `Changes requested`, not `Approved`; a `[Nit]` left on an `Approved` verdict is the author's discretion, handled out-of-band. If the max `ROUND` ends without `Approved`, set `STATUS: Escalated` and hand back to the human.
8. End your turn by committing it: `relay(<slug>): <role> r<N>`, then fill the hash into your `Commit:` line — so the other agent can `git diff` exactly what changed. If your turn touched no tracked files (comments-only, or this log is gitignored), write `Commit: none (comments only)`.
9. **One window at a time, clean tree at every handoff.** Both agents share one working tree; the `NEXT` pointer is honor-system, not a lock. Never start a turn while the other window may still be editing, and never flip `NEXT` with uncommitted changes left in the tree — commit or stash first, so the next agent never inherits half-finished state.

## Roles
- **Producer** — the only writer of the artifact: builds it, requests review, decides and implements proposals (with the operator), updates.
- **Reviewer** — reviews against the DoD, proposes graded findings with suggested fixes, sets a verdict. Never edits the artifact.

---
## Log

### Round 1 · Producer · 2026-06-14 10:48 PDT
**Did:** Built `skill/xyz/SKILL.md` — a self-contained Claude Skill packaging the `tick` multi-agent coordination system, distilled from the Trinity experiment (Runs 1–3). Sections: what-it-is · scope (is/isn't for) · the **xyz mantra** (anti-assumption discipline adapted from `debug-mantra`) · self-extracting install (runtime embedded as heredocs) · use-case A (parallel build) · use-case B (research/recon) with paste-ready agent prompts + cited profile template · coordinator workflow · metric + caveats · limits.
**Verified already:** extracted the embedded `install.sh` to a temp dir → wrote 11 runtime files → ran a full `take`/`ping`/`done`/`analyze` cycle clean (atomic claims, lane separation, parked: none). So the embedded runtime is byte-exact and functional.
**Checkpoint note:** this is the **runtime** checkpoint. The **test suite** (`validate.sh` + `test/`) is NOT yet embedded — that's a known pending step (§10), not an omission to flag as a blocker.
**Review this (against the DoD):**
1. **Honesty / no overstatement** — do scope, limits, and the metric/caveats accurately reflect what Runs 1–3 actually showed (esp. the 40% load-imbalance miss, the heartbeat *operational contract*, the shared-tree-specific atomicity)? Flag any claim stronger than the evidence.
2. **Usability** — are the two agent prompts + the recon profile template directly usable by a fresh agent, or is anything underspecified?
3. **Scope clarity** — is "what this is / isn't for" unambiguous enough that someone won't misapply it to non-partitionable work?
4. **Mantra** — does the anti-assumption block actually mitigate the collide/hallucinate failure modes, or is it decorative?
5. **Anything inaccurate** in the prose vs the embedded code's real behavior.
**Open questions:** Name is `xyz` (placeholder, trivially renamed). Tests-embed pending. Both out of scope for this review unless they affect the above.
**Commit:** 1bc6805 (relay log; skill in 98c377b)

<!-- ↓↓↓  NEXT TURN GOES ABOVE THIS LINE — keep this marker last  ↓↓↓ -->
