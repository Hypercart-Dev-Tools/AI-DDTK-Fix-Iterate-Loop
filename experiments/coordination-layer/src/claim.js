'use strict';

const { appendEvent, readAllEvents } = require('./events');
const { project, fold, activeClaimsForAgent, MAX_ACTIVE_CLAIMS_PER_AGENT } = require('./project');
const { withClaimLock } = require('./lock');

// Local-transport claim (Run 2: git transport removed).
//
// `.tick/events/` is a shared local directory; the per-clone lock serialises
// claim calls. Together that makes `tick claim` a real mutex: read current
// state, decide, append — atomically. No git, no deterministic tie-breaker,
// no auto-release. Those existed only to reconcile the old distributed
// fetch/rebase/push transport's races, which no longer exist.
function claim(repoRoot, { task, agent, paths }) {
  if (!paths || !paths.length) {
    throw new Error('claim requires --paths (declare every glob you intend to touch)');
  }

  return withClaimLock(repoRoot, () => {
    const tasks = fold(readAllEvents(repoRoot));
    const t = tasks.get(task);

    // Already terminal — not claimable.
    if (t && (t.status === 'done' || t.status === 'circuit_broken')) {
      return { won: false, task, winner: null, unavailable: t.status };
    }

    // Already claimed.
    if (t && t.status === 'claimed') {
      if (t.claim.agent === agent) {
        return { won: true, task }; // idempotent — you already hold it
      }
      return { won: false, task, winner: t.claim.agent };
    }

    // Per-agent claim cap.
    const held = activeClaimsForAgent(tasks, agent);
    if (held.length >= MAX_ACTIVE_CLAIMS_PER_AGENT) {
      return { won: false, limitReached: true, holding: held, task };
    }

    appendEvent(repoRoot, { type: 'task.claimed', task, agent, paths });
    project(repoRoot);
    return { won: true, task };
  });
}

module.exports = { claim };
