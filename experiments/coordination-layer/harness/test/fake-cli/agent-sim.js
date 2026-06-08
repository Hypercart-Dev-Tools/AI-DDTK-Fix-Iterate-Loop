#!/usr/bin/env node
'use strict';

// Stand-in for a real Gemini/Codex CLI, used to CONFIRM the harness can execute
// and monitor those CLIs end-to-end without the real binaries installed.
//
// It honors the real headless contract exactly:
//   - the prompt arrives on STDIN (the harness pipes it),
//   - driver flags (--yolo, exec, --full-auto, -) arrive as argv and are ignored,
//   - it learns its own identity from the prompt ("You are **<name>**"),
//   - it coordinates only through the `./tick` shim in the cwd.
//
// The ONLY thing this lacks vs. a real agent is the model writing real code; it
// creates a placeholder file in each task's declared scope so the protocol and
// the harness's spawn/monitor/observe path are exercised for real.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

function readStdin() {
  try { return fs.readFileSync(0, 'utf8'); } catch { return ''; }
}

function sleep(ms) { const end = Date.now() + ms; while (Date.now() < end) {} }

const prompt = readStdin();
const idMatch = prompt.match(/You are \*\*([A-Za-z0-9_-]+)\*\*/);
const agent = idMatch ? idMatch[1] : (process.env.TICK_AGENT || 'unknown');

// Print to stdout so the harness transcript (logs/<agent>.log) captures progress
// — this is the "monitor" half of execute-and-monitor.
function say(m) { process.stdout.write(`[${agent}] ${m}\n`); }

// Preflight prompts are read-only: just answer and exit. (The word "preflight"
// appears only in the preflight prompt, never in the run prompt.)
if (/preflight/i.test(prompt)) {
  say('NO_QUESTIONS');
  process.exit(0);
}

function tick(args, { retries = 8 } = {}) {
  for (let attempt = 0; ; attempt++) {
    try {
      return execFileSync('./tick', args, { cwd: process.cwd(), encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
    } catch (err) {
      const msg = (err.stderr || '') + (err.message || '');
      if (/lock held|claim is in progress/i.test(msg) && attempt < retries) { sleep(60 + attempt * 40); continue; }
      throw err;
    }
  }
}

say(`started (driver argv: ${process.argv.slice(2).join(' ') || 'none'}; prompt ${prompt.length} bytes on stdin)`);

let completed = 0;
for (let guard = 0; guard < 100; guard++) {
  const out = tick(['take', '--agent', agent]);
  if (out.startsWith('(no available task)')) { say('no available task — standing down'); break; }
  if (out.includes('claim limit reached')) { say('at claim cap — wrapping up'); break; }
  const m = out.match(/^won:\s+(TASK-[A-Za-z0-9_-]+)/);
  if (!m) { say(`unexpected take output: ${out}`); break; }
  const task = m[1];

  // Discover scope via the protocol (no copy-paste from the prompt).
  const info = tick(['info', task]);
  const pathsLine = (info.split('\n').find(l => l.startsWith('paths:')) || 'paths:').replace('paths:', '').trim();
  const firstGlob = (pathsLine.split(',')[0] || '').trim();
  const rel = firstGlob.replace(/\/\*\*.*$/, '/AGENT_OUTPUT.txt').replace(/\*+/g, 'x') || `${task}.txt`;

  say(`claimed ${task} (scope: ${pathsLine}) — writing ${rel}`);
  sleep(200 + (task.charCodeAt(task.length - 1) % 5) * 90); // create real overlap
  const abs = path.join(process.cwd(), rel);
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, `// ${task} produced by ${agent}\n`);

  tick(['done', task, '--agent', agent, '--note', 'fake-cli run']);
  say(`done ${task}`);
  completed++;
}
say(`finished — completed ${completed} task(s)`);
process.exit(0);
