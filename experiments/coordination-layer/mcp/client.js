'use strict';

// Tiny MCP stdio client: spawn an MCP server and drive it over newline-delimited
// JSON-RPC. Shared by mcp-doctor (the `trial` preflight ping) and mcp-smoke.js.
// Zero dependencies.

const { spawn } = require('child_process');
const readline = require('readline');

function makeClient({ command, args, env }) {
  const child = spawn(command, args, { env: env || process.env, stdio: ['pipe', 'pipe', 'inherit'] });
  const rl = readline.createInterface({ input: child.stdout });
  const pending = new Map();
  rl.on('line', (line) => {
    const t = line.trim();
    if (!t) return;
    let msg;
    try { msg = JSON.parse(t); } catch { return; }
    if (msg.id != null && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  });
  child.on('error', (err) => {
    for (const resolve of pending.values()) resolve({ error: { message: err.message } });
    pending.clear();
  });

  let nextId = 1;
  function call(method, params, timeoutMs = 10000) {
    const id = nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { pending.delete(id); reject(new Error(`timeout waiting for ${method}`)); }, timeoutMs);
      pending.set(id, (msg) => { clearTimeout(timer); resolve(msg); });
      child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
    });
  }
  function notify(method, params) {
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n');
  }
  return { call, notify, close: () => child.kill() };
}

module.exports = { makeClient };
