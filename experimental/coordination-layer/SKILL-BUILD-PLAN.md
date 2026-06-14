# Build plan — `tick` multi-agent coordination Skill

**Status:** awaiting approval (no skill generated yet)
**Decisions locked:** self-extracting SKILL.md (embedded JS + extract step) · recon = workflow + prompts on existing `tick` (no new engine code) · plan-first

---

## 1. Proposed skill identity

- **Name (proposal):** `swarm` — short, memorable, generic. (Alternatives: `tick-coordination`, `parallel-agents`, `agent-swarm`. "Trinity" stays the *experiment* name, not the skill name.)
- **One-line description:** Coordinate two (or more) AI coding agents working concurrently on **non-overlapping, path-scoped lanes** of one repo, via the `tick` CLI — for parallel builds and parallel codebase recon.
- **`when-to-use` triggers:** "run two agents in parallel", "split this build across agents", "have agents recon/profile the codebase concurrently", "coordinate Codex + Gemini on the same repo", "claim/lane/no-collision multi-agent work".

## 2. SKILL.md section outline

1. **What this is** — the `tick` event-log coordination layer; claim→work→done with a per-agent cap, atomic `tick take`, liveness `tick ping`, and `tick analyze` for parked-claim detection.
2. **Scope — what it IS for** (hard requirements):
   - Work that **partitions into non-overlapping path globs** (lanes), one agent per lane.
   - **Shared working tree, single session**, shared `.tick/events/`.
   - **Balanced** lanes (Run 3 lesson: imbalance → the fast agent idles → sustained-parallelism metric misses).
   - Independent tasks with their own acceptance check; stdlib-style, no shared mutable files (e.g. `package.json`).
3. **Scope — what it is NOT for** (anti-patterns):
   - Tasks that touch the same files / a shared lockfile (collisions).
   - Distributed/separate clones or async/overnight work (atomicity is shared-lock-specific; same-session only).
   - Tightly-coupled work needing constant cross-agent handoff.
   - >2 agents is untested (cap + tie-breaks exist but unvalidated at scale).
4. **Anti-assumption guardrails** (adapted from `debug-mantra`) — see §4 below.
5. **Install / self-extract** — one `install.sh` block that materializes `bin/` + `src/` (+ tests) via heredocs; run once, then `validate.sh` to confirm 12/12. See §3.
6. **Use-case A — Parallel build** — coordinator setup (seed tasks per lane) → agents run `take`/`ping`/`done` → wrap-up metric. (The Run 3 flow, generalized.)
7. **Use-case B — Research & recon** — see §5 below.
8. **Coordinator workflow** — setup, monitor (`tick project` / `tick analyze`, don't intervene unless collision/drift/silence), wrap-up (work-bounded metric + parked-claim check + synthesis).
9. **Success metric definition** — work-bounded window (first `claimed` → last `done`), ≥50% concurrent-claim, parked-claim + serial-double-claim disqualifiers, heartbeat operational contract. Honest caveats (manual %, deployment-specific atomicity).
10. **Embedded source** — the heredoc install block (or appendix of fenced files).

## 3. Self-extract mechanism

- A single fenced ```bash block labelled **`install.sh`** containing one heredoc per file:
  ```
  mkdir -p bin src test
  cat > bin/tick <<'TICK_EOF'
  …full file…
  TICK_EOF
  chmod +x bin/tick
  cat > src/events.js <<'EOF'
  …
  EOF
  … (repeat for every file) …
  ```
- **Why heredocs, not MD-parsing:** robust, zero-dependency, no fragile fenced-block extraction. The operator/agent copies the one block to `install.sh` and runs it (or pipes it).
- **Files embedded:**
  - Runtime (required): `bin/tick`, `src/{events,project,claim,scope,next,take,analyze,lock,paths,identity}.js`
  - Tests (recommended for self-verification): `test/_setup.sh` + the 12 `*.sh` + `validate.sh`
- **Size note:** embedding runtime+tests makes a large SKILL.md (~1.5–2k lines). **Sub-decision for you:** embed (a) runtime+tests [self-verifying, big], or (b) runtime-only [smaller; `validate` not bundled].

## 4. Anti-assumption guardrails (borrowed from `debug-mantra`)

Recast the four mantras as a **coordination/recon discipline** the agents must follow:
- **Reproduce / verify, don't assume** — before claiming a task, run `tick info <ID>` to confirm scope; never infer paths from memory.
- **Trace the real path** — for recon, every claim about the code must cite `file:line` evidence; no inference from filenames.
- **Falsify the hypothesis** — state assumptions explicitly and try to disprove them against the source before recording them as findings.
- **Cross-reference** — do not read the *other* agent's source to guess an interface; code against the declared contract (`STORE-CONTRACT.md` pattern). Conflicting evidence → flag, don't paper over.
- A literal **mantra block** quoted at the top of each agent prompt (like debug-mantra does), so agents recite it before acting.

## 5. Use-case B — Research & recon (workflow + prompts only)

- **Shape:** one `tick` task per code area (e.g. `src/auth/**`, `src/api/**`, `src/db/**`), each its own lane. Agents `take` an area, **read-only profile** it, write a structured profile file *into their own lane* (e.g. `recon/<area>.md`), `ping` while working, `done`.
- **No new engine code** — reuses `take`/`ping`/`analyze`. The only additions are (a) a recon **prompt template** (with the anti-assumption mantra), (b) a **profile output template** (purpose, key files, entry points, deps, risks, open questions — each with `file:line` citations), (c) a coordinator **merge step** that stitches per-area profiles into one codebase map.
- **Why recon fits better than build:** profiling N areas is naturally **balanced** and embarrassingly parallel → should clear the ≥50% bar that the unbalanced build run missed.
- **Anti-assumption is load-bearing here** — recon is exactly where LLMs hallucinate; the guardrails force `file:line` evidence and falsification.

## 6. Limits & honesty (carried from Runs 1–3)

- Sustained parallelism needs **balanced lanes** (40% miss in Run 3 = imbalance).
- Parked-claim detection is an **operational contract** (agents must `ping`; missing heartbeat → fail/retry, never silent pass).
- `tick take` atomicity is **shared-lock/shared-tree specific** — do not generalize to separate clones.
- Coarse path scopes only (per-file drift untested).
- ≤2 agents validated.

## 7. Out of scope for this build (future, will plan separately)

- **Run 4 meta-exercise:** two LLMs build *this skill system* concurrently (the skill's own recon + build use-cases applied reflexively). Natural next fixture.
- **Fork** into a standalone repo.

---

## Open sub-decisions for you
1. **Skill name** — `swarm` (proposed) or your pick?
2. **Embed scope** — runtime+tests (self-verifying, ~2k lines) or runtime-only (smaller)?
3. **Skill location** — generate under `experimental/coordination-layer/skill/` in this repo now (you move it on fork), or somewhere else?
