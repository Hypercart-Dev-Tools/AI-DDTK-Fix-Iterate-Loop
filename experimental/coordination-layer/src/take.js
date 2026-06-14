'use strict';

const { appendEvent, readAllEvents } = require('./events');
const { project, fold, activeClaimsForAgent, MAX_ACTIVE_CLAIMS_PER_AGENT } = require('./project');
const { setsOverlap } = require('./paths');
const { withClaimLock } = require('./lock');

// Atomic next+claim under one lock. Eliminates the TOCTOU gap between
// `tick next` and `tick claim` where another agent can snatch the task
// between the two calls.
//
// Uses the task's own declared paths as the claim paths (the agent can call
// `tick scope` afterward if they need to narrow or expand). Returns:
//   { won: true, task, priority }          — task claimed
//   { won: false, noTask: true }           — no available task
//   { limitReached: true, holding: [...] } — agent is at the claim cap
function take(repoRoot, { agent }) {
  return withClaimLock(repoRoot, () => {
    const tasks = fold(readAllEvents(repoRoot));

    const held = activeClaimsForAgent(tasks, agent);
    if (held.length >= MAX_ACTIVE_CLAIMS_PER_AGENT) {
      return { limitReached: true, holding: held };
    }

    // Exclude paths held by ANY active claim — other agents (lane separation)
    // *and* this agent's own (anti-gaming: stops one agent reserving two
    // overlapping tasks in the same half and working them serially, which
    // would inflate the concurrent-claim metric without real parallel work).
    const claimedPaths = [];
    for (const t of tasks.values()) {
      if (t.status === 'claimed') {
        for (const p of t.claim.paths) claimedPaths.push(p);
      }
    }

    const candidates = [];
    for (const t of tasks.values()) {
      if (t.status !== 'open') continue;
      if (setsOverlap(t.paths, claimedPaths)) continue;
      candidates.push(t);
    }

    const handoffs = candidates.filter(t => t.handoff_to === agent);
    let chosen;
    if (handoffs.length) {
      handoffs.sort((a, b) => b.priority - a.priority || a.id.localeCompare(b.id));
      chosen = handoffs[0];
    } else {
      candidates.sort((a, b) => b.priority - a.priority || a.id.localeCompare(b.id));
      chosen = candidates[0] || null;
    }

    if (!chosen) return { won: false, noTask: true };

    appendEvent(repoRoot, { type: 'task.claimed', task: chosen.id, agent, paths: chosen.paths });
    project(repoRoot);
    return { won: true, task: chosen.id, priority: chosen.priority, handoff: chosen.handoff_to === agent };
  });
}

module.exports = { take };
