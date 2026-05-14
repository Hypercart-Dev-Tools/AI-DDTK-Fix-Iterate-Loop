'use strict';

const path = require('path');
const { appendEvent } = require('./events');
const { project } = require('./project');
const sync = require('./sync');

function emitCriticalEvent(repoRoot, type, payload, message) {
  sync.fetch(repoRoot);
  sync.rebase(repoRoot);
  const { path: p } = appendEvent(repoRoot, { type, ...payload });
  const rel = path.relative(repoRoot, p);
  sync.commitAndPush(repoRoot, rel, message);
  return p;
}

function scope(repoRoot, { task, agent, paths }) {
  if (!paths || !paths.length) throw new Error('scope requires --paths');
  emitCriticalEvent(
    repoRoot,
    'task.scope_changed',
    { task, agent, paths },
    `tick: scope ${task} by ${agent}`
  );
  project(repoRoot);
  return { ok: true };
}

function release(repoRoot, { task, agent, to_agent }) {
  emitCriticalEvent(
    repoRoot,
    'task.released',
    { task, agent, to_agent },
    to_agent
      ? `tick: release ${task} by ${agent} (handoff -> ${to_agent})`
      : `tick: release ${task} by ${agent}`
  );
  project(repoRoot);
  return { ok: true };
}

function circuitBreak(repoRoot, { task, agent, reason }) {
  emitCriticalEvent(
    repoRoot,
    'task.circuit_break',
    { task, agent, reason: reason || '' },
    `tick: break ${task} by ${agent}`
  );
  project(repoRoot);
  return { ok: true };
}

function done(repoRoot, { task, agent, note }) {
  emitCriticalEvent(
    repoRoot,
    'task.done',
    { task, agent, note },
    `tick: done ${task} by ${agent}`
  );
  project(repoRoot);
  return { ok: true };
}

// Manual liveness lever (Run 2, P5). Release every active claim held by a
// (presumed crashed) agent so peers can pick the work back up. Each emitted
// task.released carries `agent = <crashed agent>` — that is what the projection
// needs to treat the claim as released — and a note recording the reap.
// Coordinator-only, manual, logged: not auto-recovery.
function reap(repoRoot, { agent, by }) {
  sync.fetch(repoRoot);
  sync.rebase(repoRoot);
  const { tasks } = project(repoRoot);

  const held = [];
  for (const t of tasks.values()) {
    if (t.status === 'claimed' && t.claim && t.claim.agent === agent) {
      held.push(t.id);
    }
  }
  held.sort();

  const reapedBy = by || 'coordinator';
  for (const task of held) {
    const { path: p } = appendEvent(repoRoot, {
      type: 'task.released',
      task,
      agent,
      note: `reaped by ${reapedBy}: agent presumed crashed`,
    });
    const rel = path.relative(repoRoot, p);
    sync.commitAndPush(repoRoot, rel, `tick: reap ${task} (${agent}) by ${reapedBy}`);
  }

  project(repoRoot);
  return { reaped: held };
}

module.exports = { scope, release, circuitBreak, done, reap };
