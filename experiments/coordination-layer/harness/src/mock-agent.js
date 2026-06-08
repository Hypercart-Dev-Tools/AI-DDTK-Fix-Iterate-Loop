#!/usr/bin/env node
'use strict';

// Deterministic mock agent. Stands in for a real Gemini/Codex CLI so the whole
// battery runs without an API key. It speaks the SAME protocol a real agent is
// prompted to use (tick take → work → tick done/break), so a mock run exercises
// the coordination layer and the harness's observability for real — only the
// "writing code" step is simulated.
//
// Modes:
//   --mode preflight  — print clarifying questions (or NO_QUESTIONS) and exit
//   --mode run        — loop claiming + completing tasks until none remain
//
// Reads the parsed spec JSON (--spec); talks to the isolated coordination state
// via the tick CLI (--tick) with TICK_REPO_ROOT pointed at --workdir.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

function parseArgs(argv) {
  const f = {};
  for (let i = 0; i < argv.length; i += 2) f[argv[i].replace(/^--/, '')] = argv[i + 1];
  return f;
}

const args = parseArgs(process.argv.slice(2));
const agent = args.agent;
const mode = args.mode || 'run';
const workdir = path.resolve(args.workdir);
const tickBin = args.tick;
const spec = JSON.parse(fs.readFileSync(args.spec, 'utf8'));
const tasksById = new Map(spec.tasks.map(t => [t.id, t]));
const maxAttempts = Number(process.env.TRIAL_MAX_ATTEMPTS || 3);

const tickEnv = { ...process.env, TICK_REPO_ROOT: workdir, TICK_AGENT: agent };

// The claim lock (.tick/locks/claim.lock) is shared across all agents, so two
// agents calling `tick take` at the same instant collide — the loser gets a
// "lock held" error. That is expected; retry with a short backoff. A real agent
// is told to do the same in the integration prompt.
function tick(argsArr, { retries = 8 } = {}) {
  for (let attempt = 0; ; attempt++) {
    try {
      return execFileSync(process.execPath, [tickBin, ...argsArr], {
        cwd: workdir, env: tickEnv, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
      }).trim();
    } catch (err) {
      const msg = (err.stderr || '') + (err.message || '');
      if (/lock held|claim is in progress/i.test(msg) && attempt < retries) {
        sleep(60 + attempt * 40);
        continue;
      }
      throw err;
    }
  }
}

function say(msg) {
  process.stdout.write(`[${agent}] ${msg}\n`);
}

// A small, deterministic-but-nonzero delay so two mock agents running in
// parallel produce genuinely overlapping claim windows (the metric the spike
// cares about). Hash the string for variety without randomness.
function workDelayMs(seed) {
  let h = 0;
  for (const c of seed) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return 250 + (h % 400);
}

function sleep(ms) {
  const end = Date.now() + ms;
  while (Date.now() < end) { /* busy-wait keeps it dependency-free + synchronous */ }
}

// Resolve the concrete files a task should produce/edit. Prefer the explicit
// Files list; otherwise derive a placeholder file from each declared glob.
function targetFiles(task) {
  if (task.files && task.files.length) return task.files;
  return task.paths.map(g => g.replace(/\/\*\*.*$/, '/MOCK_OUTPUT.txt').replace(/\*+/g, 'mock'));
}

function ensureFile(rel, contents) {
  const abs = path.join(workdir, rel);
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, contents);
}

// Apply a mock solution mapping "target<=source[,target<=source]" by copying
// each source file over its target. This is how debug scenarios go red→green
// without a real agent. Real drivers never see this field.
function applyMockSolution(task) {
  if (!task.mock_solution) return false;
  let applied = false;
  for (const pair of task.mock_solution.split(',')) {
    const [target, source] = pair.split('<=').map(s => s.trim());
    if (!target || !source) continue;
    const srcAbs = path.join(workdir, source);
    const dstAbs = path.join(workdir, target);
    if (fs.existsSync(srcAbs)) {
      fs.mkdirSync(path.dirname(dstAbs), { recursive: true });
      fs.copyFileSync(srcAbs, dstAbs);
      applied = true;
    }
  }
  return applied;
}

function runVerify(cmd) {
  try {
    execFileSync('sh', ['-c', cmd], { cwd: workdir, env: tickEnv, encoding: 'utf8', stdio: 'pipe' });
    return { ok: true };
  } catch (err) {
    return { ok: false, output: (err.stdout || '') + (err.stderr || '') };
  }
}

function doPreflight() {
  // A real agent would read the spec and decide if anything is ambiguous. The
  // mock emits a deterministic, spec-derived question for one well-known
  // ambiguity class (shared/undeclared files) to exercise the human gate, and
  // NO_QUESTIONS otherwise.
  const firstShared = spec.tasks.find(t => !t.files || !t.files.length);
  if (firstShared) {
    say(`QUESTION: ${firstShared.id} declares scope \`${firstShared.paths.join(', ')}\` but lists no explicit Files — ` +
        `should I treat the whole glob as mine, or are some files shared with another task?`);
  } else if (spec.project.kind === 'debug') {
    say('QUESTION: should I prioritise making existing tests pass without adding new test files, ' +
        'or may I add regression tests within my declared scope?');
  } else {
    say('NO_QUESTIONS');
  }
  process.exit(0);
}

function doRun() {
  let completed = 0;
  let guard = 0;
  while (guard++ < 100) {
    const out = tick(['take', '--agent', agent]);
    if (out.startsWith('(no available task)')) { say('no available task — standing down'); break; }
    if (out.includes('claim limit reached')) { say('at claim cap — finishing current work'); break; }

    const m = out.match(/^won:\s+(TASK-[A-Za-z0-9_-]+)/);
    if (!m) { say(`unexpected take output: ${out}`); break; }
    const task = tasksById.get(m[1]);
    if (!task) { say(`claimed unknown task ${m[1]} — releasing`); tick(['release', m[1], '--agent', agent]); continue; }

    say(`claimed ${task.id} — working`);
    sleep(workDelayMs(agent + task.id));

    // "Edit" the declared files (build scenarios), then apply any solution
    // patch (debug scenarios).
    for (const rel of targetFiles(task)) {
      const abs = path.join(workdir, rel);
      if (!fs.existsSync(abs)) {
        ensureFile(rel, `// ${task.id} — produced by mock agent ${agent}\n`);
      } else {
        fs.appendFileSync(abs, `\n// touched by ${agent} for ${task.id}\n`);
      }
    }

    let attempt = 0;
    let verified = !task.verify; // no verify command ⇒ trivially "passes"
    let lastOutput = '';
    while (!verified && attempt < maxAttempts) {
      attempt++;
      applyMockSolution(task); // a real agent debugs; the mock applies the known fix
      const r = runVerify(task.verify);
      verified = r.ok;
      lastOutput = r.output || '';
      if (!verified) sleep(120);
    }

    if (verified) {
      tick(['done', task.id, '--agent', agent, '--note', `mock-completed in ${attempt} attempt(s)`]);
      say(`done ${task.id}`);
      completed++;
    } else {
      const reason = `verify failed after ${maxAttempts} attempts: ${lastOutput.split('\n')[0] || 'unknown'}`;
      tick(['break', task.id, '--agent', agent, '--reason', reason]);
      say(`circuit-break ${task.id} (${reason})`);
    }
  }
  say(`finished — completed ${completed} task(s)`);
  process.exit(0);
}

if (mode === 'preflight') doPreflight();
else doRun();
