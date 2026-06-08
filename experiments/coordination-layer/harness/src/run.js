'use strict';

// Trial orchestrator. Given a parsed spec and a set of {id, driver} agents:
//
//   1. build an isolated workspace (its own throwaway git repo + .tick/ state)
//   2. copy any fixture in, drop a `./tick` shim, init + seed the task backlog
//   3. spawn every agent CLI concurrently in run mode, capturing transcripts
//   4. run the project verify command (if any)
//   5. run `tick analyze` and write a human SUMMARY.md
//
// The real repo's `.tick/` is never touched — TICK_REPO_ROOT points at the
// per-run workspace. That isolation is what makes the battery safe to run
// repeatedly and in parallel.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { getDriver } = require('./drivers');
const { buildAgentPrompt } = require('./prompts');
const { runProc } = require('./proc');

const TICK_BIN = path.join(__dirname, '..', '..', 'bin', 'tick');

function tick(workspace, argsArr) {
  return execFileSync(process.execPath, [TICK_BIN, ...argsArr], {
    cwd: workspace,
    env: { ...process.env, TICK_REPO_ROOT: workspace },
    encoding: 'utf8',
  }).trim();
}

function copyDir(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dst, entry.name);
    if (entry.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
}

function prepareWorkspace({ rec, spec, specDir }) {
  const workspace = path.join(rec.runDir, 'workspace');
  fs.mkdirSync(workspace, { recursive: true });

  // Throwaway git repo so any git-touching tick path is harmless (no remote ⇒
  // nothing is pushed) and so a real agent has a clean repo to work in.
  const gitEnv = {
    ...process.env,
    GIT_AUTHOR_NAME: 'trial', GIT_AUTHOR_EMAIL: 'trial@local',
    GIT_COMMITTER_NAME: 'trial', GIT_COMMITTER_EMAIL: 'trial@local',
  };
  execFileSync('git', ['init', '-q'], { cwd: workspace, env: gitEnv });
  execFileSync('git', ['config', 'user.name', 'trial'], { cwd: workspace });
  execFileSync('git', ['config', 'user.email', 'trial@local'], { cwd: workspace });

  // Copy fixture (seeded-bug code for debug scenarios), if declared.
  if (spec.project.fixture) {
    const fixtureSrc = path.resolve(specDir, spec.project.fixture);
    if (!fs.existsSync(fixtureSrc)) throw new Error(`fixture not found: ${fixtureSrc}`);
    copyDir(fixtureSrc, workspace);
    rec.event('workspace.fixture', { from: path.relative(process.cwd(), fixtureSrc) });
  }

  // `./tick` shim so agent prompts can call the CLI without an absolute path.
  const shim = workspace + '/tick';
  fs.writeFileSync(shim, `#!/bin/sh\nexec "${process.execPath}" "${TICK_BIN}" "$@"\n`);
  fs.chmodSync(shim, 0o755);

  // Initialise coordination state and seed the backlog from the spec.
  tick(workspace, ['init']);
  for (const t of spec.tasks) {
    tick(workspace, [
      'log', 'task.created', t.id,
      '--agent', 'dispatcher',
      '--priority', String(t.priority),
      '--paths', t.paths.join(','),
    ]);
    rec.event('seed.task', { task: t.id, priority: t.priority, paths: t.paths.join(',') });
  }

  // Commit the seeded workspace so the agent starts from a clean tree.
  execFileSync('git', ['add', '-A'], { cwd: workspace, env: gitEnv });
  execFileSync('git', ['commit', '-q', '-m', 'trial: seed workspace'], { cwd: workspace, env: gitEnv });

  return workspace;
}

async function runTrial({ rec, spec, specPath, agents, workspace, timeoutMs, maxAttempts }) {
  rec.event('trial.start', {
    project: spec.project.name, kind: spec.project.kind,
    tasks: spec.tasks.length, agents: agents.map(a => `${a.id}:${a.driver}`).join(','),
  });

  // Spawn every agent concurrently. Each runs the integration prompt in its
  // driver's headless mode; the mock driver ignores the prose and reads the
  // spec JSON, but every driver gets the same env + cwd.
  const agentRuns = agents.map(async (agentSpec) => {
    const driver = getDriver(agentSpec.driver);
    const prompt = buildAgentPrompt({
      agent: agentSpec.id,
      project: spec.project,
      tasks: spec.tasks,
      tickCmd: './tick',
      workdir: workspace,
      maxAttempts,
    });
    fs.writeFileSync(path.join(rec.runDir, `prompt-${agentSpec.id}.md`), prompt);

    const ss = driver.spawnSpec({
      mode: 'run', agent: agentSpec.id, prompt, workdir: workspace, specPath, tickBin: TICK_BIN,
    });
    const logStream = rec.logStreamFor(agentSpec.id);
    rec.event('agent.spawn', { agent: agentSpec.id, driver: driver.name, cmd: `${ss.cmd} ${ss.args.join(' ')}` });

    const result = await runProc({
      cmd: ss.cmd, args: ss.args, input: ss.input,
      cwd: workspace,
      env: { ...process.env, TICK_REPO_ROOT: workspace, TICK_AGENT: agentSpec.id, TRIAL_MAX_ATTEMPTS: String(maxAttempts) },
      logStream, timeoutMs,
    });
    logStream.end();
    rec.event('agent.exit', {
      agent: agentSpec.id, code: result.code, ms: result.ms,
      timedOut: !!result.timedOut, spawnError: result.spawnError || null,
    });
    return { agent: agentSpec.id, ...result };
  });

  const agentResults = await Promise.all(agentRuns);

  // Project verify (does the integrated result actually build/pass?).
  let verify = null;
  if (spec.project.verify) {
    try {
      const out = execFileSync('sh', ['-c', spec.project.verify], { cwd: workspace, encoding: 'utf8', stdio: 'pipe' });
      verify = { ok: true, output: out };
    } catch (err) {
      verify = { ok: false, output: (err.stdout || '') + (err.stderr || '') };
    }
    rec.event('verify.result', { ok: verify.ok });
  }

  // Analyze the coordination event log.
  const analyzeJson = JSON.parse(tick(workspace, ['analyze', '--format', 'json']));
  const analyzeMd = tick(workspace, ['analyze', '--format', 'md']);
  rec.writeReportFile('analyze.json', JSON.stringify(analyzeJson, null, 2));
  rec.writeReportFile('analyze.md', analyzeMd + '\n');

  const summary = renderSummary({ spec, agents, agentResults, analyzeJson, verify, workspace });
  rec.writeReportFile('SUMMARY.md', summary);
  rec.event('trial.end', {
    completed: analyzeJson.event_counts.done,
    broken: analyzeJson.event_counts.circuit_break,
    concurrent_pct: analyzeJson.parallelism.concurrent_pct,
    verify: verify ? verify.ok : 'n/a',
  });

  return { workspace, analyzeJson, verify, agentResults, summary };
}

function renderSummary({ spec, agents, agentResults, analyzeJson, verify }) {
  const p = analyzeJson.parallelism;
  const out = [];
  out.push(`# Trial summary — ${spec.project.name}`);
  out.push('');
  out.push(`- **Kind:** ${spec.project.kind}`);
  out.push(`- **Agents:** ${agents.map(a => `${a.id} (${a.driver})`).join(', ')}`);
  out.push(`- **Tasks seeded:** ${spec.tasks.length}`);
  out.push(`- **Completed (\`tick done\`):** ${analyzeJson.event_counts.done}`);
  out.push(`- **Circuit-broken:** ${analyzeJson.event_counts.circuit_break}`);
  out.push(`- **Concurrent-claim time:** ${p.concurrent_pct == null ? 'n/a' : p.concurrent_pct + '%'} ` +
    `(target ≥ 50%)`);
  if (verify) out.push(`- **Project verify:** ${verify.ok ? '✅ pass' : '❌ fail'}`);
  out.push('');
  out.push('## Per-agent process result');
  out.push('');
  out.push('| Agent | Driver | Exit | Wall ms | Notes |');
  out.push('| --- | --- | --- | --- | --- |');
  for (const r of agentResults) {
    const a = agents.find(x => x.id === r.agent);
    const notes = r.spawnError ? `spawn error: ${r.spawnError}` : (r.timedOut ? 'timed out' : 'ok');
    out.push(`| ${r.agent} | ${a.driver} | ${r.code} | ${r.ms} | ${notes} |`);
  }
  out.push('');
  out.push('## Coordination analysis');
  out.push('');
  out.push('See `report/analyze.md` for the full `tick analyze` output. Per-agent claim/done counts:');
  out.push('');
  for (const ag of analyzeJson.agents) {
    out.push(`- **${ag.agent}** — claimed ${ag.claims}, done ${ag.dones}, broken ${ag.breaks}, released ${ag.releases}`);
  }
  out.push('');
  out.push('## Verdict');
  out.push('');
  const ok = (!verify || verify.ok) && analyzeJson.event_counts.done > 0;
  out.push(ok
    ? '✅ Tasks completed through the coordination protocol with no protocol errors.'
    : '⚠️ Review needed — see broken tasks and/or failed verify above.');
  out.push('');
  return out.join('\n');
}

module.exports = { runTrial, prepareWorkspace, TICK_BIN };
