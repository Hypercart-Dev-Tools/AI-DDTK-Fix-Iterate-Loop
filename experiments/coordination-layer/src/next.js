'use strict';

const { fold, activeClaimsForAgent, MAX_ACTIVE_CLAIMS_PER_AGENT } = require('./project');
const { readAllEvents } = require('./events');
const { setsOverlap } = require('./paths');

// Returns the next available task for `agent`:
//   0. If the agent is already at the claim cap, return { limitReached } —
//      don't route new work until a slot is freed.
//   1. Targeted handoff to this agent wins immediately.
//   2. Otherwise, highest-priority open task whose paths don't overlap any
//      currently-claimed paths held by *other* agents.
//
// Run 2: no git transport — reads the shared local .tick/events/ directly.
// Read-only: folds events in memory without writing STATE.md.
function next(repoRoot, { agent }) {
  const tasks = fold(readAllEvents(repoRoot));

  // Per-agent claim cap: an agent at the cap is not routed new work.
  const held = activeClaimsForAgent(tasks, agent);
  if (held.length >= MAX_ACTIVE_CLAIMS_PER_AGENT) {
    return { limitReached: true, holding: held };
  }

  const claimedByOthers = [];
  for (const t of tasks.values()) {
    if (t.status === 'claimed' && t.claim.agent !== agent) {
      for (const p of t.claim.paths) claimedByOthers.push(p);
    }
  }

  const candidates = [];
  for (const t of tasks.values()) {
    if (t.status !== 'open') continue;
    if (setsOverlap(t.paths, claimedByOthers)) continue;
    candidates.push(t);
  }

  // Prioritize targeted handoffs to this agent.
  const handoffs = candidates.filter(t => t.handoff_to === agent);
  if (handoffs.length) {
    handoffs.sort((a, b) => b.priority - a.priority || a.id.localeCompare(b.id));
    return handoffs[0];
  }

  candidates.sort((a, b) => b.priority - a.priority || a.id.localeCompare(b.id));
  return candidates[0] || null;
}

module.exports = { next };
