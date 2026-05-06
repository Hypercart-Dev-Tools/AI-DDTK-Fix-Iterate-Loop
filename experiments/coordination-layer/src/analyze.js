'use strict';

const { execFileSync } = require('child_process');
const { readAllEvents } = require('./events');
const { matchesAny } = require('./paths');

// Walk the event log and git history to produce an objective compliance
// report per agent. Designed to be reusable across testing phases — run
// after any multi-agent session to see what actually happened vs what
// agents declared they would do.

function gitLogCommits(repoRoot, since) {
  const args = [
    'log',
    '--name-only',
    '--no-merges',
    "--pretty=format:%x1eCOMMIT%x1f%H%x1f%ai%x1f%an%x1f%s",
  ];
  if (since) args.push(`${since}..HEAD`);
  let out;
  try {
    out = execFileSync('git', args, { cwd: repoRoot, encoding: 'utf8' });
  } catch (err) {
    return [];
  }
  const commits = [];
  // Records are separated by RS (\x1e). Within a header, fields are separated by US (\x1f).
  // After the header line, file paths follow on subsequent lines until the next \x1e.
  const records = out.split('\x1e').map(r => r.trim()).filter(Boolean);
  for (const rec of records) {
    const lines = rec.split('\n');
    const header = lines.shift();
    const [marker, hash, ts, author, ...subjParts] = header.split('\x1f');
    if (marker !== 'COMMIT') continue;
    const subject = subjParts.join('\x1f');
    const files = lines.map(l => l.trim()).filter(Boolean);
    commits.push({ hash, ts, author, subject, files });
  }
  return commits;
}

// Parse "tick: <verb> <task> by <agent>[ extras]" — the auto-commit messages
// produced by sync.js. Returns { verb, task, agent } or null.
function parseTickCommit(subject) {
  const m = subject.match(/^tick:\s+(\S+)\s+(\S+)\s+by\s+(\S+)/);
  if (!m) return null;
  return { verb: m[1], task: m[2], agent: m[3] };
}

// Build per-(agent, task) claim windows from the event timeline.
// A window opens at task.claimed (by an agent who won the deterministic
// tie-breaker) and closes at the next terminal event for that task
// (task.released by same agent, task.done, task.circuit_break).
function buildClaimWindows(events) {
  const windows = [];
  const byTask = new Map();
  for (const ev of events) {
    if (!byTask.has(ev.task)) byTask.set(ev.task, []);
    byTask.get(ev.task).push(ev);
  }

  for (const [taskId, evs] of byTask) {
    // Walk chronologically, tracking the current live claim.
    let open = null; // { agent, paths, openedAt }
    for (const ev of evs) {
      if (ev.type === 'task.claimed') {
        // Replace any prior open claim if this earlier-ts claim wins. Tie-breaker
        // resolution is left to project.js; for analysis we only attribute work
        // to whoever the current open claim belongs to. We accept "first wins"
        // for window construction — the projection itself decides ultimate
        // ownership in STATE.md.
        if (!open) {
          open = {
            task: taskId,
            agent: ev.agent,
            paths: ev.paths || [],
            openedAt: ev.ts,
          };
        }
      } else if (ev.type === 'task.scope_changed') {
        if (open && open.agent === ev.agent && ev.paths) {
          open.paths = ev.paths;
        }
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
    if (open) {
      windows.push({ ...open, closedAt: null, closedBy: 'still_open' });
    }
  }
  return windows;
}

function toMs(ts) {
  // Accept both ISO ("2026-05-04T10:00:05.000Z") and git's "%ai"
  // ("2026-05-06 08:38:31 -0700") forms.
  const t = Date.parse(ts);
  return Number.isFinite(t) ? t : null;
}

function isWithin(ts, openedAt, closedAt) {
  const t = toMs(ts);
  const o = toMs(openedAt);
  if (t === null || o === null) return false;
  if (t < o) return false;
  if (closedAt) {
    const c = toMs(closedAt);
    if (c !== null && t > c) return false;
  }
  return true;
}

function analyze(repoRoot, opts = {}) {
  const events = readAllEvents(repoRoot);
  const commits = gitLogCommits(repoRoot, opts.since);
  const windows = buildClaimWindows(events);

  // Discover the set of known agents from claim events. Used to filter out
  // dispatcher / orchestrator commits.
  const knownAgents = new Set();
  for (const ev of events) {
    if (ev.type === 'task.claimed') knownAgents.add(ev.agent);
  }

  // Per-agent buckets.
  const perAgent = new Map();
  function ensureAgent(name) {
    if (!perAgent.has(name)) {
      perAgent.set(name, {
        agent: name,
        claims_attempted: 0,
        claims_won: 0,
        claims_lost: 0,
        scope_changes: 0,
        dones: 0,
        releases: 0,
        handoffs: 0,
        breaks: 0,
        comments: 0,
        work_commits_in_scope: 0,
        work_commits_drift: 0,
        work_commits_unclaimed: 0,
        drift_examples: [],
        unclaimed_examples: [],
      });
    }
    return perAgent.get(name);
  }

  // Count event types per agent.
  for (const ev of events) {
    const a = ensureAgent(ev.agent);
    switch (ev.type) {
      case 'task.claimed':
        a.claims_attempted++;
        break;
      case 'task.scope_changed':
        a.scope_changes++;
        break;
      case 'task.done':
        a.dones++;
        break;
      case 'task.released':
        a.releases++;
        if (ev.to_agent) a.handoffs++;
        break;
      case 'task.circuit_break':
        a.breaks++;
        break;
      case 'task.commented':
        a.comments++;
        break;
    }
  }

  // Decide claim wins/losses. A claim is "won" if its agent appears as the
  // window opener for that task; lost otherwise (it was followed by an
  // auto-release noted with "lost" in the note, or simply not chosen as the
  // window opener).
  const winnerByTask = new Map();
  for (const w of windows) {
    if (!winnerByTask.has(w.task)) winnerByTask.set(w.task, w.agent);
  }
  for (const ev of events) {
    if (ev.type !== 'task.claimed') continue;
    const winner = winnerByTask.get(ev.task);
    const a = perAgent.get(ev.agent);
    if (!a) continue;
    if (winner === ev.agent) a.claims_won++;
    else a.claims_lost++;
  }

  // Walk commits, attribute each to a window.
  const fileTouchTimeline = []; // { file, agent, ts, hash }
  for (const c of commits) {
    const tick = parseTickCommit(c.subject);
    // Coordination commits are administrative; they'll only touch .tick/* —
    // skip them for path-match analysis but still record the agent for
    // discovery purposes.
    if (tick) {
      // Coordination commit — don't analyze for drift.
      continue;
    }
    // Attribute by author name. Worktree convention: each agent runs with
    // git config user.name = <agent-id>.
    const agentGuess = c.author;
    if (!knownAgents.has(agentGuess)) continue; // ignore orchestrator/dispatcher

    const a = ensureAgent(agentGuess);
    // Find the open window for this agent at this commit's timestamp.
    const matching = windows.filter(
      w => w.agent === agentGuess && isWithin(c.ts, w.openedAt, w.closedAt)
    );
    if (!matching.length) {
      a.work_commits_unclaimed++;
      a.unclaimed_examples.push({ hash: c.hash.slice(0, 8), ts: c.ts, files: c.files });
      continue;
    }
    // Use the most recently opened matching window (innermost).
    matching.sort((x, y) => (x.openedAt < y.openedAt ? 1 : -1));
    const w = matching[0];

    // Exclude .tick/** files from path-match analysis (those are coordination
    // bookkeeping and not part of the agent's task work).
    const workFiles = c.files.filter(f => !f.startsWith('.tick/'));
    if (!workFiles.length) continue;

    const inScope = workFiles.every(f => matchesAny(f, w.paths));
    if (inScope) {
      a.work_commits_in_scope++;
    } else {
      a.work_commits_drift++;
      const offending = workFiles.filter(f => !matchesAny(f, w.paths));
      a.drift_examples.push({
        hash: c.hash.slice(0, 8),
        ts: c.ts,
        task: w.task,
        declared: w.paths,
        offending,
      });
    }
    for (const f of workFiles) {
      fileTouchTimeline.push({ file: f, agent: agentGuess, ts: c.ts, task: w.task, hash: c.hash });
    }
  }

  // Cross-cutting: file collisions (same file touched by two agents).
  const byFile = new Map();
  for (const t of fileTouchTimeline) {
    if (!byFile.has(t.file)) byFile.set(t.file, []);
    byFile.get(t.file).push(t);
  }
  const collisions = [];
  for (const [file, touches] of byFile) {
    const agents = new Set(touches.map(t => t.agent));
    if (agents.size >= 2) {
      collisions.push({ file, agents: Array.from(agents).sort(), touches: touches.length });
    }
  }

  // Wasted work: commits authored after a task.circuit_break that touch files
  // declared by the broken task's last claim.
  const breakEvents = events.filter(e => e.type === 'task.circuit_break');
  const wasted = [];
  for (const br of breakEvents) {
    // Find the most recent claim for this task before the break.
    const priorClaim = events
      .filter(e => e.type === 'task.claimed' && e.task === br.task && e.ts <= br.ts)
      .sort((a, b) => (a.ts < b.ts ? 1 : -1))[0];
    if (!priorClaim) continue;
    const declared = priorClaim.paths || [];
    for (const c of commits) {
      if (c.ts <= br.ts) continue;
      if (parseTickCommit(c.subject)) continue;
      const work = c.files.filter(f => !f.startsWith('.tick/'));
      if (work.some(f => matchesAny(f, declared))) {
        wasted.push({ hash: c.hash.slice(0, 8), ts: c.ts, agent: c.author, task: br.task });
      }
    }
  }

  // Run window.
  const eventTs = events.map(e => e.ts).sort();
  const window = {
    earliest_event: eventTs[0] || null,
    latest_event: eventTs[eventTs.length - 1] || null,
    total_events: events.length,
  };

  return {
    window,
    agents: Array.from(perAgent.values()).sort((a, b) => a.agent.localeCompare(b.agent)),
    cross_cutting: {
      file_collisions: collisions,
      wasted_work_commits: wasted,
    },
    event_counts: {
      created: events.filter(e => e.type === 'task.created').length,
      claimed: events.filter(e => e.type === 'task.claimed').length,
      released: events.filter(e => e.type === 'task.released').length,
      scope_changed: events.filter(e => e.type === 'task.scope_changed').length,
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
  out.push('');
  out.push('--- per agent ---');
  for (const a of report.agents) {
    const total = a.work_commits_in_scope + a.work_commits_drift;
    const pct = total ? Math.round((a.work_commits_in_scope / total) * 100) : null;
    out.push(`[${a.agent}]`);
    out.push(`  claims: ${a.claims_won} won / ${a.claims_lost} lost / ${a.claims_attempted} attempted`);
    out.push(`  done: ${a.dones}, released: ${a.releases} (${a.handoffs} as handoff), broken: ${a.breaks}, scope_changes: ${a.scope_changes}, commented: ${a.comments}`);
    if (total) {
      out.push(`  path-match: ${a.work_commits_in_scope}/${total} commits in scope (${pct}%); ${a.work_commits_drift} drifted`);
    } else {
      out.push(`  path-match: no work commits attributed`);
    }
    out.push(`  unclaimed work commits: ${a.work_commits_unclaimed}`);
    if (a.drift_examples.length) {
      out.push(`  drift examples:`);
      for (const d of a.drift_examples.slice(0, 5)) {
        out.push(`    ${d.hash} @${d.ts} task=${d.task} offending: ${d.offending.join(', ')}`);
      }
      if (a.drift_examples.length > 5) out.push(`    ... +${a.drift_examples.length - 5} more`);
    }
    if (a.unclaimed_examples.length) {
      out.push(`  unclaimed examples:`);
      for (const u of a.unclaimed_examples.slice(0, 5)) {
        out.push(`    ${u.hash} @${u.ts} files: ${u.files.filter(f => !f.startsWith('.tick/')).join(', ')}`);
      }
      if (a.unclaimed_examples.length > 5) out.push(`    ... +${a.unclaimed_examples.length - 5} more`);
    }
    out.push('');
  }
  out.push('--- cross-cutting ---');
  out.push(`file collisions: ${report.cross_cutting.file_collisions.length}`);
  for (const c of report.cross_cutting.file_collisions) {
    out.push(`  ${c.file} touched by ${c.agents.join(', ')} (${c.touches} commits total)`);
  }
  out.push(`wasted work (commits on broken tasks): ${report.cross_cutting.wasted_work_commits.length}`);
  for (const w of report.cross_cutting.wasted_work_commits) {
    out.push(`  ${w.hash} @${w.ts} agent=${w.agent} task=${w.task}`);
  }
  return out.join('\n');
}

function renderMd(report) {
  const out = [];
  out.push('## Auto-analyzed (tick analyze)');
  out.push('');
  out.push(`- **Run window:** \`${report.window.earliest_event || '(none)'}\` → \`${report.window.latest_event || '(none)'}\``);
  out.push(`- **Total events:** ${report.window.total_events} (${Object.entries(report.event_counts).filter(([_,v]) => v).map(([k,v]) => `${k}: ${v}`).join(', ') || 'none'})`);
  out.push('');
  out.push('### Per-agent');
  out.push('');
  for (const a of report.agents) {
    const total = a.work_commits_in_scope + a.work_commits_drift;
    const pct = total ? Math.round((a.work_commits_in_scope / total) * 100) : null;
    out.push(`#### ${a.agent}`);
    out.push('');
    out.push(`- **Claimed before editing:** ${a.work_commits_unclaimed === 0 ? 'yes' : `**no — ${a.work_commits_unclaimed} unclaimed work commit(s)**`}`);
    out.push(`- **Declared paths matched actual edits:** ${total ? (a.work_commits_drift === 0 ? `yes (${total}/${total})` : `partial — ${a.work_commits_in_scope}/${total} commits in scope (${pct}%); ${a.work_commits_drift} drifted`) : 'no work commits attributed'}`);
    out.push(`- **Used \`tick scope\` when expanding mid-task:** ${a.scope_changes > 0 ? `yes (${a.scope_changes} scope change(s))` : 'never observed'}`);
    out.push(`- **Used \`tick done\` on completion:** ${a.dones > 0 ? `yes (${a.dones} task(s) completed)` : 'no'}`);
    out.push(`- **Used \`tick break\` when stuck:** ${a.breaks > 0 ? `yes (${a.breaks} break(s))` : 'never invoked'}`);
    out.push(`- **Other coordination events:** ${a.releases} release(s) (${a.handoffs} as handoff), ${a.comments} comment(s)`);
    out.push(`- **Claim outcomes:** ${a.claims_won} won, ${a.claims_lost} lost (of ${a.claims_attempted} attempted)`);
    if (a.drift_examples.length) {
      out.push('- **Drift examples:**');
      for (const d of a.drift_examples.slice(0, 5)) {
        out.push(`  - \`${d.hash}\` (task ${d.task}) edited outside declared scope: ${d.offending.map(f => '`' + f + '`').join(', ')}`);
      }
      if (a.drift_examples.length > 5) out.push(`  - _… ${a.drift_examples.length - 5} more_`);
    }
    if (a.unclaimed_examples.length) {
      out.push('- **Unclaimed work commits:**');
      for (const u of a.unclaimed_examples.slice(0, 5)) {
        const files = u.files.filter(f => !f.startsWith('.tick/'));
        out.push(`  - \`${u.hash}\` edited ${files.map(f => '`' + f + '`').join(', ')} with no active claim`);
      }
      if (a.unclaimed_examples.length > 5) out.push(`  - _… ${a.unclaimed_examples.length - 5} more_`);
    }
    out.push('');
  }
  out.push('### Cross-cutting');
  out.push('');
  if (report.cross_cutting.file_collisions.length) {
    out.push('- **File collisions detected:**');
    for (const c of report.cross_cutting.file_collisions) {
      out.push(`  - \`${c.file}\` touched by ${c.agents.join(' and ')} (${c.touches} commits total)`);
    }
  } else {
    out.push('- **File collisions:** none');
  }
  if (report.cross_cutting.wasted_work_commits.length) {
    out.push('- **Wasted work (commits on circuit-broken tasks):**');
    for (const w of report.cross_cutting.wasted_work_commits) {
      out.push(`  - \`${w.hash}\` agent=${w.agent} task=${w.task}`);
    }
  } else {
    out.push('- **Wasted work on broken tasks:** none');
  }
  out.push('');
  return out.join('\n');
}

module.exports = { analyze, renderHuman, renderMd };
