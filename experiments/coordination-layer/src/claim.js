'use strict';

const path = require('path');
const { appendEvent, readAllEvents } = require('./events');
const { project, fold, activeClaimsForAgent, MAX_ACTIVE_CLAIMS_PER_AGENT } = require('./project');
const { withClaimLock } = require('./lock');
const sync = require('./sync');

// Load-bearing contract:
//   fetch -> rebase -> cap-check -> write event -> add+commit+push (one retry
//   on rejection) -> project -> verify deterministic tie-breaker -> if lost,
//   auto-emit task.released
//
// The whole cycle runs under a per-clone claim lock (P2) so this agent's own
// concurrent claim calls can't both pass the cap check before either writes.

function claim(repoRoot, { task, agent, paths }) {
  if (!paths || !paths.length) {
    throw new Error('claim requires --paths (declare every glob you intend to touch)');
  }

  return withClaimLock(repoRoot, () => {
    sync.fetch(repoRoot);
    sync.rebase(repoRoot);

    // Per-agent claim cap (P1). Checked after fetch+rebase so the count
    // reflects current peer/own state; the surrounding lock closes the
    // check-then-write TOCTOU window. Refusal writes ZERO events.
    const preTasks = fold(readAllEvents(repoRoot));
    const held = activeClaimsForAgent(preTasks, agent);
    if (held.length >= MAX_ACTIVE_CLAIMS_PER_AGENT) {
      return { won: false, limitReached: true, holding: held, task };
    }

    const { path: eventPath } = appendEvent(repoRoot, {
      type: 'task.claimed',
      task,
      agent,
      paths,
    });

    const rel = path.relative(repoRoot, eventPath);
    sync.commitAndPush(repoRoot, rel, `tick: claim ${task} by ${agent}`);

    // Re-fetch and re-project so any concurrent peer claim is visible.
    sync.fetch(repoRoot);
    sync.rebase(repoRoot);
    const { tasks } = project(repoRoot);

    const t = tasks.get(task);
    if (t && t.status === 'claimed' && t.claim.agent === agent) {
      return { won: true, task };
    }

    // Lost the tie-breaker. Auto-emit task.released so peers see we yielded.
    const { path: relEventPath } = appendEvent(repoRoot, {
      type: 'task.released',
      task,
      agent,
      note: 'auto-released: lost deterministic tie-breaker',
    });
    const relRel = path.relative(repoRoot, relEventPath);
    sync.commitAndPush(repoRoot, relRel, `tick: auto-release ${task} by ${agent} (lost tie-breaker)`);

    return { won: false, task, winner: t && t.claim ? t.claim.agent : null };
  });
}

module.exports = { claim };
