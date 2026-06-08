#!/usr/bin/env node
'use strict';

// Smoke test for tick-mcp: spawns the server and drives it over real JSON-RPC
// stdio (initialize → tools/list → tools/call ...) against a throwaway repo
// root, asserting the coordination protocol works through the MCP surface.
// Zero dependencies, runnable anywhere.

const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');
const { makeClient } = require('../client');

const SERVER = path.join(__dirname, '..', 'tick-mcp.js');

function textOf(res) {
  assert(res.result, `expected result, got ${JSON.stringify(res)}`);
  return res.result.content.map(c => c.text).join('');
}

async function main() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'tick-mcp-'));
  const env = { ...process.env, TICK_REPO_ROOT: root };
  const c = makeClient({ command: process.execPath, args: [SERVER], env });
  let pass = 0; const ok = (m) => { console.log(`  ✓ ${m}`); pass++; };

  // Handshake
  const init = await c.call('initialize', { protocolVersion: '2024-11-05', capabilities: {} });
  assert.strictEqual(init.result.serverInfo.name, 'tick-mcp');
  ok('initialize → serverInfo tick-mcp');
  c.notify('notifications/initialized');

  // tools/list
  const list = await c.call('tools/list', {});
  const names = list.result.tools.map(t => t.name);
  for (const v of ['tick_init', 'tick_take', 'tick_done', 'tick_analyze', 'tick_break']) {
    assert(names.includes(v), `missing tool ${v}`);
  }
  ok(`tools/list → ${names.length} tools incl. all verbs`);

  // init + seed two non-overlapping tasks
  await c.call('tools/call', { name: 'tick_init', arguments: {} });
  await c.call('tools/call', { name: 'tick_log', arguments: { type: 'task.created', task: 'TASK-A', agent: 'dispatcher', priority: 10, paths: 'src/a/**' } });
  await c.call('tools/call', { name: 'tick_log', arguments: { type: 'task.created', task: 'TASK-B', agent: 'dispatcher', priority: 8, paths: ['src/b/**'] } });
  ok('init + seeded TASK-A, TASK-B (array + string paths both accepted)');

  // two agents take concurrently → each gets a different task
  const ta = textOf(await c.call('tools/call', { name: 'tick_take', arguments: { agent: 'gemini' } }));
  const tb = textOf(await c.call('tools/call', { name: 'tick_take', arguments: { agent: 'codex' } }));
  assert(/won: TASK-A/.test(ta), `gemini take: ${ta}`);
  assert(/won: TASK-B/.test(tb), `codex take: ${tb}`);
  ok('tick_take routed gemini→TASK-A, codex→TASK-B (no overlap)');

  // ownership enforcement: codex cannot done gemini's task
  const bad = await c.call('tools/call', { name: 'tick_done', arguments: { task: 'TASK-A', agent: 'codex' } });
  assert(bad.result.isError, 'expected ownership error');
  ok('ownership enforced: codex cannot complete gemini\'s task (isError)');

  // proper completion + a circuit break
  await c.call('tools/call', { name: 'tick_done', arguments: { task: 'TASK-A', agent: 'gemini', note: 'via mcp' } });
  await c.call('tools/call', { name: 'tick_break', arguments: { task: 'TASK-B', agent: 'codex', reason: 'stuck' } });
  ok('tick_done + tick_break succeeded');

  // info + analyze
  const info = textOf(await c.call('tools/call', { name: 'tick_info', arguments: { task: 'TASK-B' } }));
  assert(/circuit_broken/.test(info), `info: ${info}`);
  const report = JSON.parse(textOf(await c.call('tools/call', { name: 'tick_analyze', arguments: { format: 'json' } })));
  assert.strictEqual(report.event_counts.done, 1, 'expected 1 done');
  assert.strictEqual(report.event_counts.circuit_break, 1, 'expected 1 break');
  ok(`tick_analyze → done:1 break:1; tick_info shows circuit_broken`);

  // ping
  const ping = await c.call('ping', {});
  assert.deepStrictEqual(ping.result, {});
  ok('ping → {}');

  c.close();
  fs.rmSync(root, { recursive: true, force: true });
  console.log(`\n--- mcp-smoke: ${pass} passed ---`);
}

main().catch((e) => { console.error('FAIL:', e.message); process.exit(1); });
