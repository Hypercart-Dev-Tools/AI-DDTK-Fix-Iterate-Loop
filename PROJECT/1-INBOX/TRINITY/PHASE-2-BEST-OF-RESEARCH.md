# Trinity Phase 2 — Best Of Research

**Date:** 2026-06-14  
**Purpose:** capture the strongest Phase 2 ideas surfaced by external research without importing their full complexity.

## Bottom line

Keep `tick` as the minimal coordination core. Do **not** replace it wholesale with `claudectl`, `mcp_agent_mail`, or `mcp_agent_mail_rust`.

The best Phase 2 move is to **steal narrow patterns**, not platforms:

1. **Durable async handoff / mailbox**
2. **Lease TTL + heartbeat + auto-reap**
3. **Path enforcement at write/commit time**
4. **Work-bounded metrics and operator visibility**
5. **Transport abstraction only after the metric is trustworthy**

Assumption: Run 3 still exists to answer the narrow question "can two agents sustain real parallel work in one session?" If that assumption changes, the priority order below changes too.

Reversibility: **Easy**. This file is a planning memo only.

## What the research actually suggests

### 1. Mailbox beats raw claims for async coordination

**Steal from:** `Dicklesworthstone/mcp_agent_mail`, `mcp_agent_mail_rust`

The strongest idea in that family is **not** the lease model. It is the **mailbox / thread / directory** model:

- agent identity that survives a session
- directed messages
- threaded handoff context
- searchable history
- human-overseer messages when needed

Why it matters for Trinity:

- `tick` currently coordinates **reservation**, not **understanding**
- same-session runs can survive without messaging; real async work cannot
- a handoff with no attached context is just a renamed release

What to build, minimally:

- `tick send --from <agent> --to <agent> --task <id> --subject "..." --body "..."`
- `tick inbox --agent <agent>`
- `tick ack <message-id>`
- optional `tick thread <task-id>`

What **not** to copy:

- full product surface
- web app first
- "agent ecosystem" framing

Verdict: this is the best external idea for actual Phase 2 value.

### 2. TTL + heartbeat + auto-reap are mandatory if Trinity wants async realism

**Steal from:** the lease thinking in `mcp_agent_mail*`, the health/liveness posture in `claudectl`

Run 2 and Run 3 already surfaced the real issue: a claim can stay open long after useful work stops. Manual `tick reap` is enough for a controlled experiment, not for a reusable coordination layer.

What to build:

- claim lease with expiry time
- explicit heartbeat renewals while work is active
- automatic stale-claim reap after TTL
- visible reason trail in the event log

Why this is load-bearing:

- it closes the gap between "reservation overlap" and "real work overlap"
- it makes same-session and async workflows comparable
- it reduces coordinator babysitting

Risk:

- too-short TTL causes false reaps
- too-long TTL recreates parked-claim inflation

Verdict: do this before any serious async or multi-day Phase 2 use.

### 3. Advisory scopes are not enough; Phase 2 needs an enforcement edge

**Steal from:** `mcp_agent_mail`'s pre-commit guard idea

The current `tick` model depends on honest path declarations. That was acceptable for the spike. It is not acceptable for a stronger claim about collision prevention.

What to build:

- pre-commit or pre-write guard that rejects edits outside the active claim scope
- clear escape hatch for override with an explicit event
- collision report tied to actual touched files, not just declared paths

Why this matters:

- broad scopes can look clean while hiding drift
- "no collision" is weak if it means "we never checked actual writes"

What **not** to do:

- pretend advisory leases are enforcement
- introduce a heavy daemon before proving a simple guard works

Verdict: this is the clearest hardening step after Run 3.

### 4. Operator visibility matters, but `claudectl` is mostly too big to steal directly

**Steal from:** `mercurialsolo/claudectl`

The best thing in `claudectl` is not the local-LLM brain. It is the operator stance:

- who is blocked
- who is waiting for input
- who is burning time or budget
- which sessions are stale

What to build, minimally:

- `tick status` summary by agent and task
- stalled-claim report
- work-bounded overlap report
- heartbeat age report

What **not** to build:

- local-LLM auto-approval
- session auto-kill logic as a core protocol dependency
- a TUI before the metrics are credible

Verdict: copy the observability instinct, not the orchestration product.

### 5. Transport abstraction is Phase 2 only if the protocol survives stricter semantics

**Steal from:** none directly; this is the synthesis

Right now `tick take` is strong because the deployment is simple: one shared event directory, one shared lock. That is fine for the experiment. It is not a portable guarantee.

Phase 2 should separate two questions:

1. **Core protocol:** what counts as claim / heartbeat / handoff / done?
2. **Transport:** shared FS, HTTP/MCP server, daemon, or branch/ref sync?

Why this matters:

- if you conflate local shared-FS behavior with protocol correctness, you will fool yourself again
- a future MCP wrapper should adapt the core, not redefine it

Verdict: only abstract transport after metrics, TTL, and enforcement are in place.

## Recommended Phase 2 order

1. **Metric hardening**
   → expect: overlap metric reflects real work, not parked claims
   - work-bounded window as the default analyzer output
   - heartbeat-aware parked-claim disqualifier
   - same-half double-claim refusal covered by tests

2. **Enforcement**
   → expect: actual writes outside claim scope are rejected or explicitly escalated
   - pre-commit or pre-write scope guard
   - collision audit against touched files

3. **Async coordination**
   → expect: agents can hand off work with context, not just release it
   - minimal mailbox/thread verbs
   - task-linked handoff messages

4. **Lease durability**
   → expect: async workflows no longer require coordinator babysitting
   - TTL renewal
   - auto-reap
   - reap audit trail

5. **Transport wrapper**
   → expect: the same semantics work over more than one deployment model
   - MCP/HTTP wrapper around existing verbs
   - keep the event log as source of truth if possible

6. **Operator UX**
   → expect: faster diagnosis, not new protocol semantics
   - `tick status`
   - optional dashboard later

Nothing actionable should happen ahead of step 1. If the metric is still gameable, Phase 2 platform work just scales ambiguity.

## What to explicitly avoid

- **Do not replace Trinity with `claudectl`.** It is an orchestration console, not a minimal falsifiable protocol.
- **Do not replace Trinity with `mcp_agent_mail` as-is.** Its mailbox ideas are strong; its advisory lease model is still soft power.
- **Do not make a local model "brain" part of protocol correctness.** That adds judgment noise where Trinity needs mechanical signal.
- **Do not build the UI first.** A pretty dashboard over a misleading metric is regression disguised as progress.
- **Do not claim production readiness from a green same-session run.** Same-session parallelism and durable async coordination are different problems.

## Single best bet

If Phase 2 gets only one feature, it should be:

**Minimal mailbox + handoff context attached to tasks, backed by the existing event log.**

Why this beats the alternatives:

- it solves the biggest gap external tools handle better than `tick`
- it improves real collaboration without forcing a platform rewrite
- it composes cleanly with later TTL, enforcement, and MCP wrapping

## Sources reviewed

- `mercurialsolo/claudectl`
- `Dicklesworthstone/mcp_agent_mail`
- `Dicklesworthstone/mcp_agent_mail_rust`

Use them as pattern libraries, not as adoption targets.
