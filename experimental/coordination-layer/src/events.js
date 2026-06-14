'use strict';

const fs = require('fs');
const path = require('path');

const SCHEMA_VERSION = '0.1.0';

const EVENT_TYPES = new Set([
  'task.created',
  'task.claimed',
  'task.released',
  'task.scope_changed',
  'task.commented',
  'task.heartbeat',
  'task.done',
  'task.circuit_break',
]);

const CRITICAL_EVENTS = new Set([
  'task.claimed',
  'task.scope_changed',
  'task.released',
  'task.circuit_break',
  'task.done',
]);

function eventsDir(repoRoot) {
  return path.join(repoRoot, '.tick', 'events');
}

function ensureEventsDir(repoRoot) {
  fs.mkdirSync(eventsDir(repoRoot), { recursive: true });
}

function isoNow() {
  if (process.env.TICK_TS) return process.env.TICK_TS;
  return new Date().toISOString();
}

function tsForFilename(iso) {
  return iso.replace(/:/g, '-');
}

function safeSegment(s) {
  return String(s).replace(/[^A-Za-z0-9._-]/g, '_');
}

function appendEvent(repoRoot, { type, task, agent, note, paths, to_agent, reason, priority }) {
  if (!EVENT_TYPES.has(type)) {
    throw new Error(`unknown event type: ${type}`);
  }
  if (!task) throw new Error('task is required');
  if (!agent) throw new Error('agent is required');

  ensureEventsDir(repoRoot);

  const ts = isoNow();
  const action = type.replace(/^task\./, '');
  const fname = `${tsForFilename(ts)}-${safeSegment(agent)}-${safeSegment(action)}-${safeSegment(task)}.jsonl`;
  const fpath = path.join(eventsDir(repoRoot), fname);

  const event = {
    schema_version: SCHEMA_VERSION,
    ts,
    type,
    task,
    agent,
  };
  if (paths) event.paths = paths;
  if (note !== undefined) event.note = note;
  if (to_agent) event.to_agent = to_agent;
  if (reason !== undefined) event.reason = reason;
  if (priority !== undefined) event.priority = priority;

  fs.writeFileSync(fpath, JSON.stringify(event) + '\n');
  return { path: fpath, event };
}

function readAllEvents(repoRoot) {
  const dir = eventsDir(repoRoot);
  if (!fs.existsSync(dir)) return [];
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.jsonl')).sort();
  return files.map(f => {
    const raw = fs.readFileSync(path.join(dir, f), 'utf8').trim();
    const ev = JSON.parse(raw);
    ev._file = f;
    return ev;
  });
}

module.exports = {
  SCHEMA_VERSION,
  EVENT_TYPES,
  CRITICAL_EVENTS,
  appendEvent,
  readAllEvents,
  eventsDir,
  ensureEventsDir,
  isoNow,
};
