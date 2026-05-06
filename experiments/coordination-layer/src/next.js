'use strict';

const { project } = require('./project');
const { setsOverlap } = require('./paths');
const sync = require('./sync');

// Returns the next available task for `agent`:
//   1. Targeted handoff to this agent wins immediately.
//   2. Otherwise, highest-priority open task whose paths don't overlap any
//      currently-claimed paths held by *other* agents.
function next(repoRoot, { agent }) {
  sync.fetch(repoRoot);
  sync.rebase(repoRoot);
  const { tasks } = project(repoRoot);

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
