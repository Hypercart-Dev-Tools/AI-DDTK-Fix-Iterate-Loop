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

module.exports = { scope, release, circuitBreak, done };
