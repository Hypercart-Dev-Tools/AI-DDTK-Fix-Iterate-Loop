---
name: xyz
description: >-
  Coordinate two (or more) AI coding agents working CONCURRENTLY on
  non-overlapping, path-scoped lanes of ONE shared repo, via the `tick` CLI —
  for parallel builds and parallel codebase recon, with collision-free claims,
  liveness heartbeats, and an honest concurrency metric. Use when the user wants
  to "run two agents in parallel", "split this build across agents", "have
  agents recon/profile the codebase concurrently", or "coordinate Codex +
  Gemini on the same repo". NOT for work that touches shared files, needs
  constant cross-agent handoff, or runs across separate clones / async sessions.
---

# xyz — multi-agent coordination via `tick`

> **Working name `xyz`** — rename freely; nothing depends on the name.
> Distilled from the "Trinity" experiment (Runs 1–3). This skill packages the
> `tick` event-log coordination CLI plus two operating modes and the
> anti-assumption discipline that keeps parallel agents from corrupting each
> other's work or hallucinating about the code.

## 1. What this is

`tick` is a tiny, dependency-free Node CLI backed by an append-only event log in
`.tick/events/` (one JSON object per `.jsonl` file). Agents coordinate by
**claiming** path-scoped lanes before they edit, working, **heartbeating** while
they work, and marking **done** — so two agents build different halves of one
repo at once without colliding. A coordinator (you) seeds tasks, observes, and
scores the run. There is **no server and no git transport** — just a shared
local directory both agents can read and append.

Core verbs: `take` (atomic claim of the next available lane), `ping` (liveness
heartbeat), `done` / `release` / `break` / `scope`, `analyze` (metrics +
parked-claim detection), `project` / `info` (read state).

## 2. Scope — what this IS for

Use `xyz` only when ALL of these hold:

- **Partitionable into non-overlapping path globs.** Each task owns a lane
  (e.g. `src/http/**` vs `src/store/**`). Agents never touch each other's lane.
- **Shared working tree, single session.** Both agents operate on ONE checkout
  with ONE `.tick/` directory, at the same time. (The atomic-claim guarantee is
  specific to a shared lock + shared event dir — see Limits.)
- **Balanced lanes.** Lanes should take comparable effort. (Run 3 lesson: an
  imbalanced split lets the faster agent finish and idle, which sinks the
  sustained-concurrency metric even on a flawless run.)
- **Independent tasks with their own acceptance check** (a test, a build, a
  lint). No shared mutable files (e.g. a single `package.json`/lockfile).

## 2a. Scope — what this is NOT for

- Tasks that edit the **same files** or a shared lockfile → guaranteed collisions.
- **Separate clones / distributed / async or overnight** work → the soft-mutex
  reopens; the metric becomes uninterpretable. Same-session, shared-tree only.
- **Tightly-coupled** work needing constant back-and-forth handoff.
- **>2 agents** — the cap and tie-breaks exist but are unvalidated at scale.
- Anything where you can't write a per-task acceptance check.

If the work doesn't partition into clean lanes, stop — this is the wrong tool.

## 3. Anti-assumption discipline (the xyz mantra)

Parallel agents fail in two ways: they **collide** (edit outside their lane) or
they **hallucinate** (assert things about code they didn't verify). Both are
assumption failures. Adapted from the `debug-mantra` skill, every agent prompt
opens with this block, recited verbatim before acting:

```
XYZ MANTRA — recite before every action
1. VERIFY, DON'T ASSUME.  Run `tick info <TASK-ID>` to confirm your lane's
   exact paths. Never infer paths, file locations, or task scope from memory.
2. TRACE THE REAL PATH.  Every claim about the code cites file:line you have
   actually read. Filenames and intuition are not evidence.
3. FALSIFY YOUR HYPOTHESIS.  State each assumption and try to DISPROVE it
   against the source before recording it as fact. Default to "unverified".
4. STAY IN YOUR LANE / CODE TO THE CONTRACT.  Never read the other agent's
   source to guess an interface — code against the declared contract. If
   evidence conflicts, FLAG it; do not paper over it.
```

The coordinator enforces it: any finding without a `file:line` citation, or any
edit outside a claimed lane, is rejected in the wrap-up.

## 4. Install (self-extracting)

Copy the block below into `install.sh` and run `bash install.sh [DIR]`
(default `DIR=xyz-tick`). It materializes the `tick` runtime. Then point
`tick` at the repo you're coordinating via `TICK_REPO_ROOT` (or run it from
inside that repo — it uses `git rev-parse --show-toplevel`).

> This checkpoint embeds the **runtime** (CLI + engine). The **test suite**
> (`validate.sh` + `test/`) is embedded in the companion section "Install —
> tests" (added in the next build step); run it to confirm the extract is exact.

```bash
#!/usr/bin/env bash
# xyz / tick — self-extracting runtime installer
set -euo pipefail
DIR="${1:-xyz-tick}"
mkdir -p "$DIR/bin" "$DIR/src"

cat > "$DIR/bin/tick" <<'===XYZ_FILE==='
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const { appendEvent, ensureEventsDir, EVENT_TYPES } = require('../src/events');
const { project, fold } = require('../src/project');
const { claim } = require('../src/claim');
const { scope, release, circuitBreak, done, reap, heartbeat } = require('../src/scope');
const { next } = require('../src/next');
const { take } = require('../src/take');
const { analyze, renderHuman, renderMd } = require('../src/analyze');
const { gitUserName } = require('../src/identity');

function repoRoot() {
  if (process.env.TICK_REPO_ROOT) return path.resolve(process.env.TICK_REPO_ROOT);
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
  } catch {
    return process.cwd();
  }
}

function parseArgs(argv) {
  const positional = [];
  const flags = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith('--')) {
        flags[key] = true;
      } else {
        flags[key] = next;
        i++;
      }
    } else {
      positional.push(a);
    }
  }
  return { positional, flags };
}

function parsePathsFlag(v) {
  if (!v || v === true) return [];
  return String(v).split(',').map(s => s.trim()).filter(Boolean);
}

function usage() {
  process.stderr.write(`tick — coordination layer CLI

Usage:
  tick init
  tick log <type> <task> [--agent <id>] [--note "..."] [--paths a,b] [--priority N]
  tick project
  tick claim <task> --agent <id> --paths <globs>
  tick take --agent <id>                           (atomic next+claim)
  tick next --agent <id>                           (read-only, no STATE.md write)
  tick scope <task> --agent <id> --paths <globs>
  tick release <task> --agent <id> [--to <agent>]
  tick break <task> --agent <id> --reason "..."
  tick done <task> --agent <id> [--note "..."]
  tick ping <task> --agent <id> [--note "..."]      (liveness heartbeat)
  tick reap <agent> [--by <id>]
  tick info <task>
  tick analyze [--format human|md|json] [--write <file>]

Event types: ${Array.from(EVENT_TYPES).join(', ')}
`);
}

function main(argv) {
  const verb = argv[0];
  const rest = argv.slice(1);
  const { positional, flags } = parseArgs(rest);
  const root = repoRoot();

  switch (verb) {
    case 'init': {
      ensureEventsDir(root);
      process.stdout.write(`initialized .tick/events at ${root}\n`);
      return 0;
    }

    case 'log': {
      const [type, task] = positional;
      if (!type || !task) { usage(); return 2; }
      const { path: p } = appendEvent(root, {
        type,
        task,
        agent: flags.agent || process.env.TICK_AGENT || 'unknown',
        note: typeof flags.note === 'string' ? flags.note : undefined,
        paths: flags.paths ? parsePathsFlag(flags.paths) : undefined,
        to_agent: typeof flags.to === 'string' ? flags.to : undefined,
        reason: typeof flags.reason === 'string' ? flags.reason : undefined,
        priority: flags.priority !== undefined ? Number(flags.priority) : undefined,
      });
      process.stdout.write(`${path.relative(root, p)}\n`);
      return 0;
    }

    case 'project': {
      const { stateFile } = project(root);
      process.stdout.write(`${path.relative(root, stateFile)}\n`);
      return 0;
    }

    case 'claim': {
      const [task] = positional;
      if (!task || !flags.agent || !flags.paths) { usage(); return 2; }
      const result = claim(root, {
        task,
        agent: flags.agent,
        paths: parsePathsFlag(flags.paths),
      });
      if (result.limitReached) {
        process.stdout.write(`lost: claim limit reached (holding ${result.holding.join(', ')}) — finish or release first\n`);
        return 0;
      }
      if (result.won) {
        process.stdout.write(`won: ${task} claimed by ${flags.agent}\n`);
        return 0;
      }
      if (result.unavailable) {
        process.stdout.write(`lost: ${task} is ${result.unavailable} — not claimable\n`);
        return 0;
      }
      process.stdout.write(`lost: ${task} already claimed by ${result.winner || 'unknown'}\n`);
      return 0;
    }

    case 'take': {
      if (!flags.agent) { usage(); return 2; }
      const tr = take(root, { agent: flags.agent });
      if (tr.limitReached) {
        process.stdout.write(`(claim limit reached — holding ${tr.holding.join(', ')} — finish or release a task first)\n`);
        return 0;
      }
      if (!tr.won) { process.stdout.write('(no available task)\n'); return 0; }
      const handoffMark = tr.handoff ? ' [handoff]' : '';
      process.stdout.write(`won: ${tr.task} (priority: ${tr.priority})${handoffMark}\n`);
      return 0;
    }

    case 'next': {
      if (!flags.agent) { usage(); return 2; }
      const t = next(root, { agent: flags.agent });
      if (t && t.limitReached) {
        process.stdout.write(`(claim limit reached — holding ${t.holding.join(', ')} — finish or release a task first)\n`);
        return 0;
      }
      if (!t) { process.stdout.write('(no available task)\n'); return 0; }
      const handoff = t.handoff_to === flags.agent ? ' [handoff]' : '';
      process.stdout.write(`${t.id} (priority: ${t.priority})${handoff}\n`);
      return 0;
    }

    case 'scope': {
      const [task] = positional;
      if (!task || !flags.agent || !flags.paths) { usage(); return 2; }
      scope(root, { task, agent: flags.agent, paths: parsePathsFlag(flags.paths) });
      process.stdout.write(`scoped: ${task}\n`);
      return 0;
    }

    case 'release': {
      const [task] = positional;
      if (!task || !flags.agent) { usage(); return 2; }
      release(root, { task, agent: flags.agent, to_agent: typeof flags.to === 'string' ? flags.to : undefined });
      process.stdout.write(`released: ${task}\n`);
      return 0;
    }

    case 'break': {
      const [task] = positional;
      if (!task || !flags.agent) { usage(); return 2; }
      circuitBreak(root, { task, agent: flags.agent, reason: typeof flags.reason === 'string' ? flags.reason : '' });
      process.stdout.write(`broken: ${task}\n`);
      return 0;
    }

    case 'done': {
      const [task] = positional;
      if (!task || !flags.agent) { usage(); return 2; }
      done(root, { task, agent: flags.agent, note: typeof flags.note === 'string' ? flags.note : undefined });
      process.stdout.write(`done: ${task}\n`);
      return 0;
    }

    case 'ping': {
      const [task] = positional;
      if (!task || !flags.agent) { usage(); return 2; }
      heartbeat(root, { task, agent: flags.agent, note: typeof flags.note === 'string' ? flags.note : undefined });
      process.stdout.write(`heartbeat: ${task} by ${flags.agent}\n`);
      return 0;
    }

    case 'reap': {
      const [agent] = positional;
      if (!agent) { usage(); return 2; }
      const by = typeof flags.by === 'string' ? flags.by : (gitUserName(root) || 'coordinator');
      const result = reap(root, { agent, by });
      if (!result.reaped.length) {
        process.stdout.write(`(no active claims held by ${agent})\n`);
      } else {
        process.stdout.write(`reaped ${result.reaped.length} claim(s) from ${agent}: ${result.reaped.join(', ')}\n`);
      }
      return 0;
    }

    case 'info': {
      const [task] = positional;
      if (!task) { usage(); return 2; }
      const { tasks: infoTasks } = project(root);
      const t = infoTasks.get(task);
      if (!t) { process.stdout.write(`(task ${task} not found)\n`); return 1; }
      const lines = [
        `id:       ${t.id}`,
        `status:   ${t.status}`,
        `priority: ${t.priority}`,
      ];
      const paths = t.status === 'claimed' ? t.claim.paths : t.paths;
      lines.push(`paths:    ${paths.join(', ') || '(none)'}`);
      if (t.status === 'claimed') lines.push(`claimer:  ${t.claim.agent}`);
      if (t.status === 'circuit_broken') lines.push(`broken-by: ${t.break.agent} — ${t.break.reason}`);
      if (t.handoff_to) lines.push(`handoff-to: ${t.handoff_to}`);
      process.stdout.write(lines.join('\n') + '\n');
      return 0;
    }

    case 'analyze': {
      const format = (typeof flags.format === 'string' && flags.format) || 'human';
      const report = analyze(root);
      let body;
      if (format === 'json') body = JSON.stringify(report, null, 2);
      else if (format === 'md') body = renderMd(report);
      else body = renderHuman(report);

      if (typeof flags.write === 'string') {
        const target = path.resolve(root, flags.write);
        const md = format === 'md' ? body : renderMd(report);
        let existing = '';
        if (fs.existsSync(target)) existing = fs.readFileSync(target, 'utf8');
        const marker = '## Auto-analyzed (tick analyze)';
        const idx = existing.indexOf(marker);
        let next;
        if (idx >= 0) {
          next = existing.slice(0, idx).replace(/\s+$/, '') + '\n\n' + md;
        } else {
          next = (existing.replace(/\s+$/, '') + '\n\n' + md).replace(/^\n+/, '');
        }
        fs.writeFileSync(target, next.endsWith('\n') ? next : next + '\n');
        process.stdout.write(`wrote analysis to ${path.relative(root, target)}\n`);
      } else {
        process.stdout.write(body + '\n');
      }
      return 0;
    }

    case '-h':
    case '--help':
    case 'help':
    case undefined:
      usage();
      return 0;

    default:
      process.stderr.write(`unknown verb: ${verb}\n`);
      usage();
      return 2;
  }
}

try {
  process.exit(main(process.argv.slice(2)) || 0);
} catch (err) {
  process.stderr.write(`tick: error: ${err.message}\n`);
  process.exit(1);
}
===XYZ_FILE===
chmod +x "$DIR/bin/tick"

cat > "$DIR/src/events.js" <<'===XYZ_FILE==='
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
===XYZ_FILE===

cat > "$DIR/src/project.js" <<'===XYZ_FILE==='
'use strict';

const fs = require('fs');
const path = require('path');
const { readAllEvents } = require('./events');

// Build deterministic state from all events.
// Tie-breaker for concurrent claims on the same task: earliest event ts wins;
// on identical ts, lexicographically smallest agent id wins. The loser is
// expected to have a corresponding task.released event (auto-emitted by the
// claim verb after re-projection).

function fold(events) {
  const byTask = new Map();
  for (const ev of events) {
    if (!byTask.has(ev.task)) byTask.set(ev.task, []);
    byTask.get(ev.task).push(ev);
  }

  const tasks = new Map();

  for (const [taskId, evs] of byTask) {
    const t = {
      id: taskId,
      priority: 0,
      paths: [],
      status: 'open',
      claim: null,
      break: null,
      handoff_to: null,
    };

    let terminal = null;
    for (const ev of evs) {
      if (ev.type === 'task.done' || ev.type === 'task.circuit_break') terminal = ev;
    }

    const claims = evs.filter(e => e.type === 'task.claimed');
    const releases = evs.filter(e => e.type === 'task.released');
    const liveClaims = claims.filter(c =>
      !releases.some(r => r.agent === c.agent && r.ts >= c.ts)
    );
    liveClaims.sort((a, b) => {
      if (a.ts !== b.ts) return a.ts < b.ts ? -1 : 1;
      return a.agent < b.agent ? -1 : a.agent > b.agent ? 1 : 0;
    });
    const winner = liveClaims[0] || null;

    for (const ev of evs) {
      switch (ev.type) {
        case 'task.created':
          if (ev.priority !== undefined) t.priority = ev.priority;
          if (ev.paths) t.paths = ev.paths;
          break;
        case 'task.released':
          if (ev.to_agent) t.handoff_to = ev.to_agent;
          break;
        case 'task.scope_changed':
          if (winner && ev.agent === winner.agent && ev.ts >= winner.ts && ev.paths) {
            t._scopedPaths = ev.paths;
          }
          break;
      }
    }

    if (terminal) {
      if (terminal.type === 'task.done') {
        t.status = 'done';
      } else {
        t.status = 'circuit_broken';
        t.break = { agent: terminal.agent, reason: terminal.reason || '' };
      }
    } else if (winner) {
      t.status = 'claimed';
      t.claim = {
        agent: winner.agent,
        paths: t._scopedPaths || winner.paths || [],
        ts: winner.ts,
      };
      let lateHandoff = null;
      for (const ev of evs) {
        if (ev.type === 'task.released' && ev.to_agent && ev.ts > winner.ts) {
          lateHandoff = ev.to_agent;
        }
      }
      t.handoff_to = lateHandoff;
    }

    delete t._scopedPaths;
    tasks.set(taskId, t);
  }

  return tasks;
}

function renderState(tasks) {
  const lines = [];
  lines.push('<!-- AUTO-GENERATED by `tick project` from .tick/events/. Do not edit by hand. -->');
  lines.push('');
  lines.push('# Coordination State');
  lines.push('');

  const all = Array.from(tasks.values()).sort((a, b) => a.id.localeCompare(b.id));
  const open = all.filter(t => t.status === 'open');
  const claimed = all.filter(t => t.status === 'claimed');
  const done = all.filter(t => t.status === 'done');
  const broken = all.filter(t => t.status === 'circuit_broken');

  lines.push('## Open');
  if (!open.length) lines.push('_(none)_');
  for (const t of open) {
    const handoff = t.handoff_to ? ` [handoff_to: ${t.handoff_to}]` : '';
    const paths = t.paths.length ? ` paths: ${JSON.stringify(t.paths)}` : '';
    lines.push(`- ${t.id} (priority: ${t.priority})${paths}${handoff}`);
  }
  lines.push('');

  lines.push('## Claimed');
  if (!claimed.length) lines.push('_(none)_');
  for (const t of claimed) {
    const paths = t.claim.paths.length ? ` paths: ${JSON.stringify(t.claim.paths)}` : '';
    lines.push(`- ${t.id} by ${t.claim.agent}${paths}`);
  }
  lines.push('');

  lines.push('## Done');
  if (!done.length) lines.push('_(none)_');
  for (const t of done) lines.push(`- ${t.id}`);
  lines.push('');

  lines.push('## Circuit-Broken');
  if (!broken.length) lines.push('_(none)_');
  for (const t of broken) {
    lines.push(`- ${t.id} by ${t.break.agent} — reason: ${JSON.stringify(t.break.reason)}`);
  }
  lines.push('');

  return lines.join('\n');
}

function project(repoRoot) {
  const events = readAllEvents(repoRoot);
  const tasks = fold(events);
  const body = renderState(tasks);
  const stateFile = path.join(repoRoot, '.tick', 'STATE.md');
  fs.writeFileSync(stateFile, body);
  return { tasks, stateFile };
}

const MAX_ACTIVE_CLAIMS_PER_AGENT = 2;

function activeClaimsForAgent(tasks, agent) {
  const held = [];
  for (const t of tasks.values()) {
    if (t.status === 'claimed' && t.claim && t.claim.agent === agent) {
      held.push(t.id);
    }
  }
  return held.sort();
}

module.exports = {
  project,
  fold,
  renderState,
  activeClaimsForAgent,
  MAX_ACTIVE_CLAIMS_PER_AGENT,
};
===XYZ_FILE===

cat > "$DIR/src/lock.js" <<'===XYZ_FILE==='
'use strict';

const fs = require('fs');
const path = require('path');

// Claim-cycle atomicity. `tick claim`/`take` does read -> cap-check -> write.
// A per-clone O_EXCL lock under .tick/locks/ serialises one agent's claim calls
// so two concurrent processes can't both pass the cap check before writing.
// Stale lock after a hard kill: rm <repo>/.tick/locks/claim.lock.

function lockPath(repoRoot) {
  const locksDir = path.join(repoRoot, '.tick', 'locks');
  fs.mkdirSync(locksDir, { recursive: true });
  return path.join(locksDir, 'claim.lock');
}

function withClaimLock(repoRoot, fn) {
  const lp = lockPath(repoRoot);
  let fd;
  try {
    fd = fs.openSync(lp, 'wx');
  } catch (err) {
    if (err.code === 'EEXIST') {
      throw new Error(
        'another tick claim is in progress for this clone (lock held) — retry shortly, ' +
        `or remove ${path.relative(repoRoot, lp)} if a prior claim was killed`
      );
    }
    throw err;
  }
  try {
    fs.writeSync(fd, String(process.pid));
    return fn();
  } finally {
    fs.closeSync(fd);
    try { fs.unlinkSync(lp); } catch { /* best-effort */ }
  }
}

module.exports = { withClaimLock, lockPath };
===XYZ_FILE===

cat > "$DIR/src/paths.js" <<'===XYZ_FILE==='
'use strict';

// Conservative path-overlap detection. Two globs "overlap" if some path matches
// both. We use a sound but conservative test: literal prefix (text up to the
// first wildcard); overlap iff one prefix is a prefix of the other. May report
// a false positive (safer) but never misses a real overlap.

function literalPrefix(glob) {
  const m = glob.match(/^([^*?[{]*)/);
  return m ? m[1] : '';
}

function patternsOverlap(a, b) {
  const pa = literalPrefix(a);
  const pb = literalPrefix(b);
  return pa.startsWith(pb) || pb.startsWith(pa);
}

function setsOverlap(setA, setB) {
  if (!setA || !setB || !setA.length || !setB.length) return false;
  for (const a of setA) {
    for (const b of setB) {
      if (patternsOverlap(a, b)) return true;
    }
  }
  return false;
}

function globToRegex(glob) {
  let re = '';
  for (let i = 0; i < glob.length; i++) {
    const ch = glob[i];
    if (ch === '*') {
      if (glob[i + 1] === '*') {
        re += '.*';
        i++;
        if (glob[i + 1] === '/') i++;
      } else {
        re += '[^/]*';
      }
    } else if (ch === '?') {
      re += '[^/]';
    } else if ('.+^$()[]{}|\\'.includes(ch)) {
      re += '\\' + ch;
    } else {
      re += ch;
    }
  }
  return new RegExp('^' + re + '$');
}

function matchesAny(file, globs) {
  if (!globs || !globs.length) return false;
  return globs.some(g => globToRegex(g).test(file));
}

module.exports = { patternsOverlap, setsOverlap, literalPrefix, globToRegex, matchesAny };
===XYZ_FILE===

cat > "$DIR/src/identity.js" <<'===XYZ_FILE==='
'use strict';

const { execFileSync } = require('child_process');

// The only remaining git touch-point: read the clone's configured identity,
// used by `reap` as a default `--by`. NOT used to gate agent identity (the
// --agent flag is authoritative).
function gitUserName(repoRoot) {
  try {
    const out = execFileSync('git', ['config', 'user.name'], {
      cwd: repoRoot,
      encoding: 'utf8',
    }).trim();
    return out || null;
  } catch {
    return null;
  }
}

module.exports = { gitUserName };
===XYZ_FILE===

cat > "$DIR/src/claim.js" <<'===XYZ_FILE==='
'use strict';

const { appendEvent, readAllEvents } = require('./events');
const { project, fold, activeClaimsForAgent, MAX_ACTIVE_CLAIMS_PER_AGENT } = require('./project');
const { withClaimLock } = require('./lock');

// Local-transport claim. `.tick/events/` is a shared local dir; the per-clone
// lock serialises claim calls. Together that makes `tick claim` a real mutex:
// read state, decide, append — atomically.
function claim(repoRoot, { task, agent, paths }) {
  if (!paths || !paths.length) {
    throw new Error('claim requires --paths (declare every glob you intend to touch)');
  }

  return withClaimLock(repoRoot, () => {
    const tasks = fold(readAllEvents(repoRoot));
    const t = tasks.get(task);

    if (t && (t.status === 'done' || t.status === 'circuit_broken')) {
      return { won: false, task, winner: null, unavailable: t.status };
    }

    if (t && t.status === 'claimed') {
      if (t.claim.agent === agent) {
        return { won: true, task };
      }
      return { won: false, task, winner: t.claim.agent };
    }

    const held = activeClaimsForAgent(tasks, agent);
    if (held.length >= MAX_ACTIVE_CLAIMS_PER_AGENT) {
      return { won: false, limitReached: true, holding: held, task };
    }

    appendEvent(repoRoot, { type: 'task.claimed', task, agent, paths });
    project(repoRoot);
    return { won: true, task };
  });
}

module.exports = { claim };
===XYZ_FILE===

cat > "$DIR/src/next.js" <<'===XYZ_FILE==='
'use strict';

const { fold, activeClaimsForAgent, MAX_ACTIVE_CLAIMS_PER_AGENT } = require('./project');
const { readAllEvents } = require('./events');
const { setsOverlap } = require('./paths');

// Next available task for `agent`: respect the cap, prefer a targeted handoff,
// else highest-priority open task whose paths don't overlap any claim held by
// OTHER agents. Read-only: folds in memory, no STATE.md write.
function next(repoRoot, { agent }) {
  const tasks = fold(readAllEvents(repoRoot));

  const held = activeClaimsForAgent(tasks, agent);
  if (held.length >= MAX_ACTIVE_CLAIMS_PER_AGENT) {
    return { limitReached: true, holding: held };
  }

  const claimedByOthers = [];
  for (const t of tasks.values()) {
    if (t.status === 'claimed' && t.claim.agent !== agent) {
      for (const p of t.claim.paths) claimedByOthers.push(p);
    }
  }

  const candidates = [];
  for (const t of tasks.values()) {
    if (t.status !== 'open') continue;
    if (setsOverlap(t.paths, claimedByOthers)) continue;
    candidates.push(t);
  }

  const handoffs = candidates.filter(t => t.handoff_to === agent);
  if (handoffs.length) {
    handoffs.sort((a, b) => b.priority - a.priority || a.id.localeCompare(b.id));
    return handoffs[0];
  }

  candidates.sort((a, b) => b.priority - a.priority || a.id.localeCompare(b.id));
  return candidates[0] || null;
}

module.exports = { next };
===XYZ_FILE===

cat > "$DIR/src/take.js" <<'===XYZ_FILE==='
'use strict';

const { appendEvent, readAllEvents } = require('./events');
const { project, fold, activeClaimsForAgent, MAX_ACTIVE_CLAIMS_PER_AGENT } = require('./project');
const { setsOverlap } = require('./paths');
const { withClaimLock } = require('./lock');

// Atomic next+claim under one lock. Eliminates the TOCTOU gap between
// `tick next` and `tick claim` where another agent can snatch the task
// between the two calls.
function take(repoRoot, { agent }) {
  return withClaimLock(repoRoot, () => {
    const tasks = fold(readAllEvents(repoRoot));

    const held = activeClaimsForAgent(tasks, agent);
    if (held.length >= MAX_ACTIVE_CLAIMS_PER_AGENT) {
      return { limitReached: true, holding: held };
    }

    // Exclude paths held by ANY active claim — other agents (lane separation)
    // *and* this agent's own (anti-gaming: stops one agent reserving two
    // overlapping tasks in the same half and working them serially, which
    // would inflate the concurrent-claim metric without real parallel work).
    const claimedPaths = [];
    for (const t of tasks.values()) {
      if (t.status === 'claimed') {
        for (const p of t.claim.paths) claimedPaths.push(p);
      }
    }

    const candidates = [];
    for (const t of tasks.values()) {
      if (t.status !== 'open') continue;
      if (setsOverlap(t.paths, claimedPaths)) continue;
      candidates.push(t);
    }

    const handoffs = candidates.filter(t => t.handoff_to === agent);
    let chosen;
    if (handoffs.length) {
      handoffs.sort((a, b) => b.priority - a.priority || a.id.localeCompare(b.id));
      chosen = handoffs[0];
    } else {
      candidates.sort((a, b) => b.priority - a.priority || a.id.localeCompare(b.id));
      chosen = candidates[0] || null;
    }

    if (!chosen) return { won: false, noTask: true };

    appendEvent(repoRoot, { type: 'task.claimed', task: chosen.id, agent, paths: chosen.paths });
    project(repoRoot);
    return { won: true, task: chosen.id, priority: chosen.priority, handoff: chosen.handoff_to === agent };
  });
}

module.exports = { take };
===XYZ_FILE===

cat > "$DIR/src/scope.js" <<'===XYZ_FILE==='
'use strict';

const { appendEvent, readAllEvents } = require('./events');
const { project, fold } = require('./project');

// Every verb is a pure local event append to the shared .tick/events/ dir,
// followed by a re-projection of STATE.md.

function emitEvent(repoRoot, type, payload) {
  appendEvent(repoRoot, { type, ...payload });
  project(repoRoot);
}

// Ownership guard for mutating verbs. Throws if the task doesn't exist, isn't
// claimed, or the claimer doesn't match `agent`. Only `reap` bypasses this.
function assertOwnership(repoRoot, task, agent) {
  const tasks = fold(readAllEvents(repoRoot));
  const t = tasks.get(task);
  if (!t) throw new Error(`task ${task} not found`);
  if (t.status !== 'claimed') throw new Error(`task ${task} is ${t.status} — only the claiming agent can mutate it`);
  if (t.claim.agent !== agent) throw new Error(`task ${task} is claimed by ${t.claim.agent}, not ${agent}`);
}

function scope(repoRoot, { task, agent, paths }) {
  if (!paths || !paths.length) throw new Error('scope requires --paths');
  assertOwnership(repoRoot, task, agent);
  emitEvent(repoRoot, 'task.scope_changed', { task, agent, paths });
  return { ok: true };
}

function release(repoRoot, { task, agent, to_agent }) {
  assertOwnership(repoRoot, task, agent);
  emitEvent(repoRoot, 'task.released', { task, agent, to_agent });
  return { ok: true };
}

function circuitBreak(repoRoot, { task, agent, reason }) {
  assertOwnership(repoRoot, task, agent);
  emitEvent(repoRoot, 'task.circuit_break', { task, agent, reason: reason || '' });
  return { ok: true };
}

function done(repoRoot, { task, agent, note }) {
  assertOwnership(repoRoot, task, agent);
  emitEvent(repoRoot, 'task.done', { task, agent, note });
  return { ok: true };
}

// Liveness heartbeat. The claiming agent emits one while actively working a
// task so the post-run parked-claim check has a work-activity signal that does
// NOT depend on git author identity. Ownership-guarded.
function heartbeat(repoRoot, { task, agent, note }) {
  assertOwnership(repoRoot, task, agent);
  emitEvent(repoRoot, 'task.heartbeat', { task, agent, note });
  return { ok: true };
}

// Manual liveness lever. Release every active claim held by a (presumed
// crashed) agent so peers can pick the work back up. Coordinator-only.
function reap(repoRoot, { agent, by }) {
  const tasks = fold(readAllEvents(repoRoot));

  const held = [];
  for (const t of tasks.values()) {
    if (t.status === 'claimed' && t.claim && t.claim.agent === agent) {
      held.push(t.id);
    }
  }
  held.sort();

  const reapedBy = by || 'coordinator';
  for (const task of held) {
    appendEvent(repoRoot, {
      type: 'task.released',
      task,
      agent,
      note: `reaped by ${reapedBy}: agent presumed crashed`,
    });
  }

  project(repoRoot);
  return { reaped: held };
}

module.exports = { scope, release, circuitBreak, done, reap, heartbeat };
===XYZ_FILE===

cat > "$DIR/src/analyze.js" <<'===XYZ_FILE==='
'use strict';

const { readAllEvents } = require('./events');

// Event-log-only analyzer. Derived purely from .tick/events/. Primary metric:
// concurrent-claim time. Run 3 added parked-claim detection from heartbeats.
// NOTE: the printed concurrent-claim % uses the earliest-event -> latest-event
// window; the redefined Run 3 metric uses a WORK-BOUNDED window (first claimed
// -> last done) computed by the coordinator (call computeParallelism with those
// timestamps). parked_suspects IS authoritative as printed.

function toMs(ts) {
  const t = Date.parse(ts);
  return Number.isFinite(t) ? t : null;
}

function humanDuration(ms) {
  if (!ms || ms < 0) return '0s';
  const totalS = Math.round(ms / 1000);
  const h = Math.floor(totalS / 3600);
  const m = Math.floor((totalS % 3600) / 60);
  const s = totalS % 60;
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

function buildClaimWindows(events) {
  const windows = [];
  const byTask = new Map();
  for (const ev of events) {
    if (!byTask.has(ev.task)) byTask.set(ev.task, []);
    byTask.get(ev.task).push(ev);
  }

  for (const [taskId, evs] of byTask) {
    let open = null;
    for (const ev of evs) {
      if (ev.type === 'task.claimed') {
        if (!open) {
          open = { task: taskId, agent: ev.agent, paths: ev.paths || [], openedAt: ev.ts };
        }
      } else if (ev.type === 'task.scope_changed') {
        if (open && open.agent === ev.agent && ev.paths) open.paths = ev.paths;
      } else if (
        ev.type === 'task.released' ||
        ev.type === 'task.done' ||
        ev.type === 'task.circuit_break'
      ) {
        if (open) {
          windows.push({ ...open, closedAt: ev.ts, closedBy: ev.type });
          open = null;
        }
      }
    }
    if (open) windows.push({ ...open, closedAt: null, closedBy: 'still_open' });
  }
  return windows;
}

// How much of [runStart, runEnd] had >= 2 distinct agents holding a claim.
// Pass a WORK-BOUNDED window (first claimed -> last done) for the Run 3 metric.
function computeParallelism(windows, runStart, runEnd) {
  const startMs = toMs(runStart);
  const endMs = toMs(runEnd);
  if (startMs === null || endMs === null || endMs <= startMs) {
    return { concurrent_ms: 0, run_window_ms: 0, concurrent_pct: null };
  }

  const intervals = [];
  for (const w of windows) {
    const o = toMs(w.openedAt);
    if (o === null) continue;
    let c = w.closedAt ? toMs(w.closedAt) : endMs;
    if (c === null) c = endMs;
    const start = Math.max(o, startMs);
    const end = Math.min(c, endMs);
    if (end > start) intervals.push({ agent: w.agent, start, end });
  }

  const points = new Set([startMs, endMs]);
  for (const iv of intervals) { points.add(iv.start); points.add(iv.end); }
  const sorted = Array.from(points).sort((a, b) => a - b);

  let concurrentMs = 0;
  for (let i = 0; i < sorted.length - 1; i++) {
    const segStart = sorted[i];
    const segEnd = sorted[i + 1];
    if (segEnd <= segStart) continue;
    const agents = new Set();
    for (const iv of intervals) {
      if (iv.start <= segStart && iv.end >= segEnd) agents.add(iv.agent);
    }
    if (agents.size >= 2) concurrentMs += segEnd - segStart;
  }

  const runMs = endMs - startMs;
  return {
    concurrent_ms: concurrentMs,
    run_window_ms: runMs,
    concurrent_pct: runMs > 0 ? Math.round((concurrentMs / runMs) * 100) : null,
  };
}

// Parked-claim detection. A claim window is a suspect if the holding agent
// showed no heartbeat for longer than the threshold at any point in the window.
// Reads only .tick/events/ — no git dependency.
const PARKED_THRESHOLD_MS = 10 * 60 * 1000; // 10 minutes

function findParkedClaims(windows, events, runEnd, thresholdMs = PARKED_THRESHOLD_MS) {
  const endMs = toMs(runEnd);
  const suspects = [];
  for (const w of windows) {
    const openMs = toMs(w.openedAt);
    if (openMs === null) continue;
    const closeMs = w.closedAt ? toMs(w.closedAt) : endMs;
    if (closeMs === null || closeMs <= openMs) continue;

    const beats = events
      .filter(e => e.type === 'task.heartbeat' && e.task === w.task && e.agent === w.agent)
      .map(e => toMs(e.ts))
      .filter(t => t !== null && t >= openMs && t <= closeMs);

    const points = [openMs, ...beats, closeMs].sort((a, b) => a - b);
    let maxGap = 0;
    for (let i = 0; i < points.length - 1; i++) {
      maxGap = Math.max(maxGap, points[i + 1] - points[i]);
    }
    if (maxGap > thresholdMs) {
      suspects.push({
        task: w.task,
        agent: w.agent,
        max_gap_ms: maxGap,
        heartbeats: beats.length,
        opened_at: w.openedAt,
        closed_at: w.closedAt || null,
      });
    }
  }
  return suspects;
}

function analyze(repoRoot) {
  const events = readAllEvents(repoRoot);
  const windows = buildClaimWindows(events);

  const perAgent = new Map();
  function ensureAgent(name) {
    if (!perAgent.has(name)) {
      perAgent.set(name, {
        agent: name,
        claims: 0,
        scope_changes: 0,
        dones: 0,
        releases: 0,
        handoffs: 0,
        breaks: 0,
        comments: 0,
        heartbeats: 0,
      });
    }
    return perAgent.get(name);
  }

  for (const ev of events) {
    const a = ensureAgent(ev.agent);
    switch (ev.type) {
      case 'task.claimed': a.claims++; break;
      case 'task.scope_changed': a.scope_changes++; break;
      case 'task.done': a.dones++; break;
      case 'task.released': a.releases++; if (ev.to_agent) a.handoffs++; break;
      case 'task.circuit_break': a.breaks++; break;
      case 'task.commented': a.comments++; break;
      case 'task.heartbeat': a.heartbeats++; break;
    }
  }
  perAgent.delete('dispatcher');

  const eventTs = events.map(e => e.ts).sort();
  const window = {
    earliest_event: eventTs[0] || null,
    latest_event: eventTs[eventTs.length - 1] || null,
    total_events: events.length,
  };

  const parallelism = computeParallelism(windows, window.earliest_event, window.latest_event);
  const parked_suspects = findParkedClaims(windows, events, window.latest_event);

  return {
    window,
    parallelism,
    parked_suspects,
    agents: Array.from(perAgent.values()).sort((a, b) => a.agent.localeCompare(b.agent)),
    event_counts: {
      created: events.filter(e => e.type === 'task.created').length,
      claimed: events.filter(e => e.type === 'task.claimed').length,
      released: events.filter(e => e.type === 'task.released').length,
      scope_changed: events.filter(e => e.type === 'task.scope_changed').length,
      heartbeat: events.filter(e => e.type === 'task.heartbeat').length,
      done: events.filter(e => e.type === 'task.done').length,
      circuit_break: events.filter(e => e.type === 'task.circuit_break').length,
      commented: events.filter(e => e.type === 'task.commented').length,
    },
  };
}

function renderHuman(report) {
  const out = [];
  out.push('=== tick analyze ===');
  out.push(`window: ${report.window.earliest_event || '(none)'} → ${report.window.latest_event || '(none)'}`);
  out.push(`events: ${report.window.total_events} (` +
    Object.entries(report.event_counts).map(([k, v]) => `${k}:${v}`).join(', ') + ')');
  const p = report.parallelism;
  if (p && p.concurrent_pct !== null) {
    out.push(`concurrent-claim time: ${humanDuration(p.concurrent_ms)} of ${humanDuration(p.run_window_ms)} run window (${p.concurrent_pct}%)`);
  } else {
    out.push('concurrent-claim time: not computable (run window too short)');
  }
  const ps = report.parked_suspects || [];
  if (ps.length) {
    out.push(`parked-claim suspects: ${ps.length} (DISQUALIFIES run)`);
    for (const s of ps) {
      out.push(`  ${s.task} (${s.agent}): max ${humanDuration(s.max_gap_ms)} with no heartbeat, ${s.heartbeats} beat(s)`);
    }
  } else {
    out.push('parked-claim suspects: none');
  }
  out.push('');
  out.push('--- per agent ---');
  for (const a of report.agents) {
    out.push(`[${a.agent}]`);
    out.push(`  claims: ${a.claims}, done: ${a.dones}, heartbeats: ${a.heartbeats}`);
    out.push(`  released: ${a.releases} (${a.handoffs} as handoff), broken: ${a.breaks}, scope_changes: ${a.scope_changes}, commented: ${a.comments}`);
    out.push('');
  }
  return out.join('\n');
}

function renderMd(report) {
  const out = [];
  out.push('## Auto-analyzed (tick analyze)');
  out.push('');
  out.push(`- **Run window:** \`${report.window.earliest_event || '(none)'}\` → \`${report.window.latest_event || '(none)'}\``);
  out.push(`- **Total events:** ${report.window.total_events} (${Object.entries(report.event_counts).filter(([_, v]) => v).map(([k, v]) => `${k}: ${v}`).join(', ') || 'none'})`);
  const p = report.parallelism;
  if (p && p.concurrent_pct !== null) {
    out.push(`- **Concurrent-claim time (printed window):** ${humanDuration(p.concurrent_ms)} of ${humanDuration(p.run_window_ms)} (**${p.concurrent_pct}%**)`);
  } else {
    out.push('- **Concurrent-claim time:** not computable (run window too short)');
  }
  const ps = report.parked_suspects || [];
  if (ps.length) {
    out.push(`- **Parked-claim suspects (DISQUALIFIES run):** ${ps.length} — ` +
      ps.map(s => `${s.task}/${s.agent} (${humanDuration(s.max_gap_ms)} gap, ${s.heartbeats} beat(s))`).join('; '));
  } else {
    out.push('- **Parked-claim suspects:** none');
  }
  out.push('');
  out.push('### Per-agent');
  out.push('');
  for (const a of report.agents) {
    out.push(`#### ${a.agent}`);
    out.push('');
    out.push(`- **Tasks claimed:** ${a.claims}`);
    out.push(`- **Tasks completed (\`tick done\`):** ${a.dones}`);
    out.push(`- **Used \`tick scope\`:** ${a.scope_changes > 0 ? `yes (${a.scope_changes})` : 'no'}`);
    out.push(`- **Used \`tick break\`:** ${a.breaks > 0 ? `yes (${a.breaks})` : 'no'}`);
    out.push(`- **Releases:** ${a.releases} (${a.handoffs} as handoff), comments: ${a.comments}`);
    out.push(`- **Heartbeats (\`tick ping\`):** ${a.heartbeats}`);
    out.push('');
  }
  return out.join('\n');
}

module.exports = { analyze, renderHuman, renderMd, buildClaimWindows, computeParallelism, findParkedClaims, PARKED_THRESHOLD_MS };
===XYZ_FILE===

echo "xyz/tick runtime installed in $DIR/ — run: TICK_REPO_ROOT=<repo> $DIR/bin/tick --help"
```

## 5. Use-case A — Parallel build

**Coordinator setup (before agents start):**
1. `tick init` in the target repo (creates `.tick/events/`). Add **`.tick/`** to `.gitignore` — locks are ephemeral, and events/`STATE.md` coordinate via the shared working tree on disk (not git), so agents never need to commit them. (If you specifically want the coordination log preserved in history — as the Trinity experiment did — track `.tick/events/` instead, but never the lock dir.)
2. Seed one task per lane with `tick log task.created <ID> --agent dispatcher --priority N --paths "<glob>,<glob>"`. Keep lanes **non-overlapping and balanced**.
3. Clear/prepare the fixture as needed.
4. Confirm prerequisites green, then paste the agent prompt (below) into each agent's window — same session, shared tree.

**Agent loop (in each agent's prompt, after the mantra):**
```
1. tick take --agent <you>        # atomic claim; note the TASK-ID it prints ("won: <TASK-ID> ...")
2. work ONLY inside the claimed paths; write code + its test
3. tick ping <TASK-ID> --agent <you>   # heartbeat every few min / after each edit
4. run the task's acceptance check — must pass
5. git status --short ; git add <your exact files> ; git commit -m "[<you>] <TASK-ID> <summary>"
6. tick done <TASK-ID> --agent <you> ; go to 1
```

**Wrap-up:** see §7.

## 6. Use-case B — Research & recon (workflow + prompts; no new code)

Profile a codebase in parallel: each agent owns a different area, reads it
**read-only**, and writes a structured profile **into its own lane**. Naturally
balanced and embarrassingly parallel — a better fit for the ≥50% bar than build.

**Coordinator setup:** one task per code area, lane = that area's source PLUS its
own output file, so two agents never write the same profile:
```
tick log task.created RECON-AUTH --agent dispatcher --priority 5 \
  --paths "src/auth/**,recon/auth.md"
tick log task.created RECON-API  --agent dispatcher --priority 5 \
  --paths "src/api/**,recon/api.md"
# ...one per area...
```

**Recon agent prompt (after the mantra):**
```
You are <you>, profiling one area of this codebase concurrently with another
agent. Recite the XYZ MANTRA. Then loop:
1. tick take --agent <you>             # note the TASK-ID it prints ("won: <TASK-ID> ...")
2. tick info <TASK-ID>                  # confirm your exact area + output path (no --agent flag)
3. READ-ONLY profile your area. Do NOT modify source. Write findings to your
   lane's output file (e.g. recon/<area>.md) using the PROFILE TEMPLATE below.
   EVERY claim cites file:line you actually read. Mark anything you could not
   verify as "UNVERIFIED" — do not guess. Do not read another area to infer an
   interface; code/claim against the contract and FLAG conflicts.
4. tick ping <TASK-ID> --agent <you>   # heartbeat as you work
5. git add recon/<area>.md ; git commit -m "[<you>] <TASK-ID> recon <area>"
6. tick done <TASK-ID> --agent <you> ; go to 1
```

**Profile template** (`recon/<area>.md`):
```
# <area> — profile by <agent>
- Purpose: <1-2 lines>  (evidence: file:line)
- Entry points: <fn/route/export>  (file:line)
- Key files: <file — role>  (file:line)
- Dependencies (in/out): <module → module>  (file:line)
- Data/state touched: <store/table/global>  (file:line)
- Risks / smells: <...>  (file:line)
- UNVERIFIED / open questions: <...>
```

**Coordinator merge (wrap-up):** stitch the per-area `recon/*.md` into one
codebase map; reject any claim lacking a `file:line` citation; collect the
UNVERIFIED items as the next round's targeted questions.

## 7. Coordinator workflow

**Monitor (don't micromanage):** `tick project` / `tick analyze`. Default to NOT
intervening. Intervene only on: a file collision (inspect `git diff` by hand —
`tick analyze` does NOT detect collisions), an agent silent >15 min while
holding a claim (`tick reap <agent> --by coordinator`), or drift outside a lane.

**Wrap-up:**
1. **Parked-claim check:** `tick analyze` → the `parked-claim suspects` line is
   authoritative. Any suspect **disqualifies** the run.
2. **Concurrent-claim metric (work-bounded):** the printed % uses the wrong
   (seeding→latest) window — recompute over **first `task.claimed` → last
   `task.done`**. (Read `.tick/events/*.jsonl`; or call `computeParallelism`
   with those two timestamps.) **Pass = ≥50%**, AND each agent ≥2 done.
3. **Serial double-claim check:** no agent held two overlapping-path claims at
   once (`take` prevents it; verify the log anyway).
4. **Cross-check:** confirm by `git diff` / passing tests that overlapping claim
   windows = overlapping REAL edits. The metric is necessary, not sufficient.
5. Record results + an honest **graduate / iterate / abandon** call.

## 8. Success metric & honest caveats

- **Pass:** work-bounded concurrent-claim ≥50%, both agents ≥2 done, zero parked
  suspects, zero serial double-claims, cross-check confirms real overlap.
- **50% is a stress bar, not a proof bar** — clearing it shows the protocol *can*
  sustain parallelism in this setup, not that it's production-ready.
- **Parked-claim is an OPERATIONAL CONTRACT, not inference.** It relies on agents
  calling `tick ping`. A missing heartbeat is indistinguishable from a parked
  claim → **fail/retry the run, never silently treat it as a pass.**
- **`take` atomicity is shared-lock/shared-tree specific** — do not generalize to
  separate clones or non-shared transports.

## 9. Limits (carried from Runs 1–3)

- Sustained parallelism needs **balanced lanes** (Run 3 missed 50%→hit 40% purely
  from imbalance: the fast agent idled once its lane drained; there is no
  work-stealing across lanes).
- Coarse, path-scoped lanes only — per-file drift within a lane is not detected.
- ≤2 agents validated; same-session, shared tree only.
- No drift/collision auto-detection — coordinator inspects `git diff` by hand.

## 10. Provenance

Built from the Trinity experiment in `experimental/coordination-layer/`
(`P1-TRINITY-ROUND2.md`, `REAL-AGENT-OBSERVATIONS.md`, `RECAP.md`). Runtime here
is embedded verbatim from that source. **Next build step:** embed the test suite
(`validate.sh` + `test/`) below a companion "Install — tests" section so an
operator can run `validate.sh` and confirm the extract is byte-exact (the source
suite is 12/12 green).
