#!/usr/bin/env node
'use strict';

// tick-mcp — an MCP server exposing the Trinity coordination verbs as typed
// tools, so an agent (or Claude Code) can coordinate via MCP instead of shelling
// out to `bin/tick`. Behaviour is identical to the CLI because both call the
// same `src/` modules — this is a thin protocol adapter, not a reimplementation.
//
// Zero dependencies on purpose (the spike's "no new deps" rule): a minimal
// JSON-RPC 2.0 over newline-delimited stdio, which is the MCP stdio transport.
// Implements initialize / tools/list / tools/call / ping.
//
// Wiring (Claude Code / any MCP client), in .mcp.json:
//   { "mcpServers": { "tick": {
//       "command": "node",
//       "args": ["experiments/coordination-layer/mcp/tick-mcp.js"],
//       "env": { "TICK_REPO_ROOT": "/abs/path/to/coordination/workspace" } } } }

const path = require('path');
const readline = require('readline');
const { execFileSync } = require('child_process');

const { appendEvent, ensureEventsDir, EVENT_TYPES } = require('../src/events');
const { project } = require('../src/project');
const { claim } = require('../src/claim');
const { take } = require('../src/take');
const { next } = require('../src/next');
const { scope, release, circuitBreak, done, reap } = require('../src/scope');
const { analyze, renderHuman, renderMd } = require('../src/analyze');

const SERVER = { name: 'tick-mcp', version: '0.1.0' };
const DEFAULT_PROTOCOL = '2024-11-05';

// Resolve the coordination repo root the same way bin/tick does: explicit arg,
// then TICK_REPO_ROOT, then the enclosing git toplevel, then cwd.
function resolveRoot(args) {
  if (args && args.repo_root) return path.resolve(args.repo_root);
  if (process.env.TICK_REPO_ROOT) return path.resolve(process.env.TICK_REPO_ROOT);
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
  } catch {
    return process.cwd();
  }
}

function asPaths(v) {
  if (Array.isArray(v)) return v.map(String).map(s => s.trim()).filter(Boolean);
  if (typeof v === 'string') return v.split(',').map(s => s.trim()).filter(Boolean);
  return undefined;
}

// --- tool registry: name -> { description, inputSchema, run(args)->string } ---
const TOOLS = {
  tick_init: {
    description: 'Create the .tick/events coordination directory (idempotent).',
    inputSchema: { type: 'object', properties: { repo_root: { type: 'string' } } },
    run(args) {
      const root = resolveRoot(args);
      ensureEventsDir(root);
      return `initialized .tick/events at ${root}`;
    },
  },

  tick_log: {
    description: 'Append a raw coordination event. type is one of the seven event types.',
    inputSchema: {
      type: 'object',
      required: ['type', 'task'],
      properties: {
        type: { type: 'string', enum: Array.from(EVENT_TYPES) },
        task: { type: 'string' },
        agent: { type: 'string' },
        note: { type: 'string' },
        paths: { type: ['array', 'string'], items: { type: 'string' } },
        to_agent: { type: 'string' },
        reason: { type: 'string' },
        priority: { type: 'number' },
        repo_root: { type: 'string' },
      },
    },
    run(args) {
      const root = resolveRoot(args);
      const { path: p } = appendEvent(root, {
        type: args.type,
        task: args.task,
        agent: args.agent || 'unknown',
        note: args.note,
        paths: asPaths(args.paths),
        to_agent: args.to_agent,
        reason: args.reason,
        priority: args.priority,
      });
      return path.relative(root, p);
    },
  },

  tick_project: {
    description: 'Rebuild STATE.md from the event log and return its contents.',
    inputSchema: { type: 'object', properties: { repo_root: { type: 'string' } } },
    run(args) {
      const root = resolveRoot(args);
      const { stateFile } = project(root);
      return require('fs').readFileSync(stateFile, 'utf8');
    },
  },

  tick_take: {
    description: 'Atomically claim the next available, non-overlapping task for an agent (next+claim under one lock).',
    inputSchema: {
      type: 'object', required: ['agent'],
      properties: { agent: { type: 'string' }, repo_root: { type: 'string' } },
    },
    run(args) {
      const root = resolveRoot(args);
      const tr = take(root, { agent: args.agent });
      if (tr.limitReached) return `claim limit reached — holding ${tr.holding.join(', ')}`;
      if (!tr.won) return '(no available task)';
      return `won: ${tr.task} (priority: ${tr.priority})${tr.handoff ? ' [handoff]' : ''}`;
    },
  },

  tick_next: {
    description: 'Read-only: return the next available task for an agent without claiming it.',
    inputSchema: {
      type: 'object', required: ['agent'],
      properties: { agent: { type: 'string' }, repo_root: { type: 'string' } },
    },
    run(args) {
      const root = resolveRoot(args);
      const t = next(root, { agent: args.agent });
      if (t && t.limitReached) return `claim limit reached — holding ${t.holding.join(', ')}`;
      if (!t) return '(no available task)';
      return `${t.id} (priority: ${t.priority})${t.handoff_to === args.agent ? ' [handoff]' : ''}`;
    },
  },

  tick_claim: {
    description: 'Claim a specific task with declared path globs.',
    inputSchema: {
      type: 'object', required: ['task', 'agent', 'paths'],
      properties: {
        task: { type: 'string' }, agent: { type: 'string' },
        paths: { type: ['array', 'string'], items: { type: 'string' } },
        repo_root: { type: 'string' },
      },
    },
    run(args) {
      const root = resolveRoot(args);
      const r = claim(root, { task: args.task, agent: args.agent, paths: asPaths(args.paths) });
      if (r.limitReached) return `lost: claim limit reached (holding ${r.holding.join(', ')})`;
      if (r.won) return `won: ${args.task} claimed by ${args.agent}`;
      if (r.unavailable) return `lost: ${args.task} is ${r.unavailable}`;
      return `lost: ${args.task} already claimed by ${r.winner || 'unknown'}`;
    },
  },

  tick_scope: {
    description: 'Change the declared paths of an agent\'s active claim (expand or narrow).',
    inputSchema: {
      type: 'object', required: ['task', 'agent', 'paths'],
      properties: {
        task: { type: 'string' }, agent: { type: 'string' },
        paths: { type: ['array', 'string'], items: { type: 'string' } },
        repo_root: { type: 'string' },
      },
    },
    run(args) {
      const root = resolveRoot(args);
      scope(root, { task: args.task, agent: args.agent, paths: asPaths(args.paths) });
      return `scoped: ${args.task}`;
    },
  },

  tick_release: {
    description: 'Release a claim, optionally handing it off to a named agent.',
    inputSchema: {
      type: 'object', required: ['task', 'agent'],
      properties: {
        task: { type: 'string' }, agent: { type: 'string' },
        to: { type: 'string' }, repo_root: { type: 'string' },
      },
    },
    run(args) {
      const root = resolveRoot(args);
      release(root, { task: args.task, agent: args.agent, to_agent: args.to });
      return `released: ${args.task}`;
    },
  },

  tick_break: {
    description: 'Circuit-break a task so no agent is routed to it (use after bounded failed attempts).',
    inputSchema: {
      type: 'object', required: ['task', 'agent'],
      properties: {
        task: { type: 'string' }, agent: { type: 'string' },
        reason: { type: 'string' }, repo_root: { type: 'string' },
      },
    },
    run(args) {
      const root = resolveRoot(args);
      circuitBreak(root, { task: args.task, agent: args.agent, reason: args.reason || '' });
      return `broken: ${args.task}`;
    },
  },

  tick_done: {
    description: 'Mark an agent\'s claimed task complete.',
    inputSchema: {
      type: 'object', required: ['task', 'agent'],
      properties: {
        task: { type: 'string' }, agent: { type: 'string' },
        note: { type: 'string' }, repo_root: { type: 'string' },
      },
    },
    run(args) {
      const root = resolveRoot(args);
      done(root, { task: args.task, agent: args.agent, note: args.note });
      return `done: ${args.task}`;
    },
  },

  tick_reap: {
    description: 'Coordinator-only: release all active claims held by an agent (liveness recovery).',
    inputSchema: {
      type: 'object', required: ['agent'],
      properties: { agent: { type: 'string' }, by: { type: 'string' }, repo_root: { type: 'string' } },
    },
    run(args) {
      const root = resolveRoot(args);
      const r = reap(root, { agent: args.agent, by: args.by || 'coordinator' });
      return r.reaped.length ? `reaped ${r.reaped.length}: ${r.reaped.join(', ')}` : `(no active claims held by ${args.agent})`;
    },
  },

  tick_info: {
    description: 'Print status/priority/paths/claimer for a task.',
    inputSchema: {
      type: 'object', required: ['task'],
      properties: { task: { type: 'string' }, repo_root: { type: 'string' } },
    },
    run(args) {
      const root = resolveRoot(args);
      const { tasks } = project(root);
      const t = tasks.get(args.task);
      if (!t) return `(task ${args.task} not found)`;
      const paths = t.status === 'claimed' ? t.claim.paths : t.paths;
      const lines = [`id: ${t.id}`, `status: ${t.status}`, `priority: ${t.priority}`, `paths: ${paths.join(', ') || '(none)'}`];
      if (t.status === 'claimed') lines.push(`claimer: ${t.claim.agent}`);
      if (t.status === 'circuit_broken') lines.push(`broken-by: ${t.break.agent} — ${t.break.reason}`);
      if (t.handoff_to) lines.push(`handoff-to: ${t.handoff_to}`);
      return lines.join('\n');
    },
  },

  tick_analyze: {
    description: 'Analyze the coordination event log. format: human | md | json.',
    inputSchema: {
      type: 'object',
      properties: { format: { type: 'string', enum: ['human', 'md', 'json'] }, repo_root: { type: 'string' } },
    },
    run(args) {
      const root = resolveRoot(args);
      const report = analyze(root);
      if (args.format === 'json') return JSON.stringify(report, null, 2);
      if (args.format === 'md') return renderMd(report);
      return renderHuman(report);
    },
  },
};

// --- JSON-RPC plumbing ------------------------------------------------------
function send(msg) {
  process.stdout.write(JSON.stringify(msg) + '\n');
}

function reply(id, result) { send({ jsonrpc: '2.0', id, result }); }
function fail(id, code, message) { send({ jsonrpc: '2.0', id, error: { code, message } }); }

function handle(msg) {
  const { id, method, params } = msg;
  // Notifications (no id) get no response.
  const isNotification = id === undefined || id === null;

  switch (method) {
    case 'initialize':
      return reply(id, {
        protocolVersion: (params && params.protocolVersion) || DEFAULT_PROTOCOL,
        capabilities: { tools: {} },
        serverInfo: SERVER,
      });
    case 'notifications/initialized':
    case 'initialized':
      return; // notification
    case 'ping':
      return reply(id, {});
    case 'tools/list':
      return reply(id, {
        tools: Object.entries(TOOLS).map(([name, t]) => ({
          name, description: t.description, inputSchema: t.inputSchema,
        })),
      });
    case 'tools/call': {
      const name = params && params.name;
      const tool = TOOLS[name];
      if (!tool) return fail(id, -32602, `unknown tool: ${name}`);
      try {
        const text = tool.run((params && params.arguments) || {});
        return reply(id, { content: [{ type: 'text', text: String(text) }] });
      } catch (err) {
        // Tool-level errors are reported via isError, not JSON-RPC error, so the
        // model sees the message and can react (per MCP guidance).
        return reply(id, { content: [{ type: 'text', text: `error: ${err.message}` }], isError: true });
      }
    }
    default:
      if (!isNotification) fail(id, -32601, `method not found: ${method}`);
  }
}

const rl = readline.createInterface({ input: process.stdin });
rl.on('line', (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  let msg;
  try { msg = JSON.parse(trimmed); } catch { return; }
  try { handle(msg); }
  catch (err) { if (msg && msg.id != null) fail(msg.id, -32603, err.message); }
});

module.exports = { TOOLS, resolveRoot };
