'use strict';

// Deterministic project-spec parser — this is "stage 1" of the ingestion
// pipeline scaffolded in ../../ingestion/README.md, finally implemented.
//
// Input:  a human-authored PROJECT-SPEC markdown file (see PROJECT-SPEC.template.md).
// Output: a structured { project, tasks[] } object, validated.
//
// Pure and deterministic: the same markdown always yields the same structure.
// No LLM, no network. Hard-fails (throws) on structural problems so a bad spec
// never silently becomes a malformed task list.

const fs = require('fs');

// Parse top-level `**Key:** value` metadata lines that appear before the first
// `## ` heading. Keys are lowercased and spaces collapsed to underscores.
function parseProjectMeta(lines) {
  const meta = {};
  for (const line of lines) {
    if (/^##+\s/.test(line)) break; // stop at the first `##` section (Constraints, Sub-tasks, …)
    const m = line.match(/^\s*[-*]?\s*\*\*([^:*]+):\*\*\s*(.*)$/);
    if (m) {
      const key = m[1].trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
      meta[key] = m[2].trim();
    }
  }
  return meta;
}

// Split the document into the preamble (everything before the first
// `### TASK-` block) and the task blocks themselves.
function splitTaskBlocks(text) {
  const lines = text.split(/\r?\n/);
  const blocks = [];
  let current = null;
  const preamble = [];
  const headerRe = /^###\s+(TASK-[A-Za-z0-9_-]+)\b\s*(?:[—\-:]\s*(.*))?$/;

  for (const line of lines) {
    const m = line.match(headerRe);
    if (m) {
      if (current) blocks.push(current);
      current = { id: m[1], title: (m[2] || '').trim(), body: [] };
    } else if (current) {
      current.body.push(line);
    } else {
      preamble.push(line);
    }
  }
  if (current) blocks.push(current);
  return { preamble, blocks };
}

// Parse `- **Key:** value` bullets inside a task block into a flat map.
function parseTaskBullets(bodyLines) {
  const fields = {};
  for (const line of bodyLines) {
    const m = line.match(/^\s*[-*]\s*\*\*([^:*]+):\*\*\s*(.*)$/);
    if (m) {
      const key = m[1].trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
      fields[key] = m[2].trim();
    }
  }
  return fields;
}

function parseGlobList(v) {
  if (!v) return [];
  return String(v)
    .replace(/`/g, '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean)
    .filter(s => s.toLowerCase() !== 'none');
}

function parseDeps(v) {
  if (!v) return [];
  return String(v)
    .replace(/`/g, '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean)
    .filter(s => s.toLowerCase() !== 'none');
}

function parseSpec(markdownText) {
  const { preamble, blocks } = splitTaskBlocks(markdownText);

  // Project title = first `# ` heading.
  const titleLine = preamble.find(l => /^#\s+/.test(l));
  const title = titleLine ? titleLine.replace(/^#\s+/, '').replace(/^Project:\s*/i, '').trim() : 'untitled';

  const meta = parseProjectMeta(preamble);

  const project = {
    name: title,
    goal: meta.goal || '',
    branch: meta.branch || '',
    path_scoping_strategy: meta.path_scoping_strategy || meta.path_scoping || 'unspecified',
    max_active_claims_per_agent: meta.max_active_claims_per_agent
      ? Number(meta.max_active_claims_per_agent)
      : 2,
    agents: (meta.agents || '')
      .split(',')
      .map(s => s.trim().toLowerCase())
      .filter(Boolean),
    fixture: meta.fixture || null,
    verify: meta.verify || null,
    kind: (meta.kind || (meta.fixture ? 'debug' : 'build')).toLowerCase(),
  };

  const tasks = blocks.map(b => {
    const f = parseTaskBullets(b.body);
    return {
      id: b.id,
      title: b.title,
      paths: parseGlobList(f.declared_scope || f.scope || f.paths),
      files: parseGlobList(f.files),
      priority: f.priority !== undefined && f.priority !== '' ? Number(f.priority) : 5,
      depends_on: parseDeps(f.depends_on_contract_only || f.depends_on || f.depends),
      description: f.description || '',
      acceptance: f.acceptance || '',
      verify: f.verify || null,
      // Mock-only: a path (relative to the fixture/workspace) whose contents the
      // mock driver copies in to "solve" the task so debug scenarios go red→green
      // without a real agent. Real drivers ignore this field entirely.
      mock_solution: f.mock_solution || null,
    };
  });

  validate(project, tasks);
  return { project, tasks };
}

function validate(project, tasks) {
  const errors = [];

  if (!tasks.length) errors.push('no `### TASK-` blocks found');

  const seen = new Set();
  for (const t of tasks) {
    if (seen.has(t.id)) errors.push(`duplicate task id: ${t.id}`);
    seen.add(t.id);
    if (!t.paths.length) errors.push(`${t.id}: empty declared scope (every task needs at least one path glob)`);
    if (!Number.isFinite(t.priority)) errors.push(`${t.id}: non-numeric priority`);
    if (!t.description) errors.push(`${t.id}: missing description`);
    if (!t.acceptance) errors.push(`${t.id}: missing acceptance criteria`);
  }

  // Dependency edges must reference real task ids, and must be acyclic.
  for (const t of tasks) {
    for (const dep of t.depends_on) {
      if (!seen.has(dep)) errors.push(`${t.id}: depends on unknown task ${dep}`);
    }
  }
  const cycle = findCycle(tasks);
  if (cycle) errors.push(`dependency cycle: ${cycle.join(' → ')}`);

  if (errors.length) {
    throw new Error('spec validation failed:\n  - ' + errors.join('\n  - '));
  }
}

function findCycle(tasks) {
  const graph = new Map(tasks.map(t => [t.id, t.depends_on]));
  const WHITE = 0, GRAY = 1, BLACK = 2;
  const color = new Map(tasks.map(t => [t.id, WHITE]));
  const stack = [];

  function dfs(id) {
    color.set(id, GRAY);
    stack.push(id);
    for (const dep of graph.get(id) || []) {
      if (!color.has(dep)) continue; // unknown dep already reported
      if (color.get(dep) === GRAY) return stack.slice(stack.indexOf(dep)).concat(dep);
      if (color.get(dep) === WHITE) {
        const c = dfs(dep);
        if (c) return c;
      }
    }
    stack.pop();
    color.set(id, BLACK);
    return null;
  }

  for (const t of tasks) {
    if (color.get(t.id) === WHITE) {
      const c = dfs(t.id);
      if (c) return c;
    }
  }
  return null;
}

function parseSpecFile(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  return parseSpec(text);
}

module.exports = { parseSpec, parseSpecFile, validate, findCycle };
