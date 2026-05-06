'use strict';

const path = require('path');
const { appendEvent } = require('./events');
const { project } = require('./project');
const sync = require('./sync');

// Load-bearing contract:
//   fetch -> rebase -> write event -> add+commit+push (one retry on rejection)
//   -> project -> verify deterministic tie-breaker -> if lost, auto-emit task.released

function claim(repoRoot, { task, agent, paths }) {
  if (!paths || !paths.length) {
    throw new Error('claim requires --paths (declare every glob you intend to touch)');
  }

  sync.fetch(repoRoot);
  sync.rebase(repoRoot);

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
}

module.exports = { claim };
