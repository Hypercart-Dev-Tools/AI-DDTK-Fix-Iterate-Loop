'use strict';

// Build the prompts handed to each agent CLI. Templates live in ../prompts/
// and use {{PLACEHOLDER}} markers. Keeping the prose in markdown files (not
// string literals) means a human can tune the integration prompt without
// touching code — the single biggest lever on real-agent compliance per the
// Run 1/2 retros.

const fs = require('fs');
const path = require('path');

const PROMPT_DIR = path.join(__dirname, '..', 'prompts');

function render(template, vars) {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) =>
    key in vars ? String(vars[key]) : `{{${key}}}`
  );
}

function taskTable(tasks) {
  const rows = tasks.map(t =>
    `| ${t.id} | ${t.priority} | \`${t.paths.join('`, `')}\` | ${t.title || t.description.slice(0, 60)} |`
  );
  return [
    '| Task | Priority | Declared scope | Summary |',
    '| --- | --- | --- | --- |',
    ...rows,
  ].join('\n');
}

function taskDetails(tasks) {
  return tasks.map(t => {
    const lines = [`### ${t.id} — ${t.title}`.trim()];
    lines.push(`- Scope: \`${t.paths.join('`, `')}\``);
    if (t.files.length) lines.push(`- Files: \`${t.files.join('`, `')}\``);
    if (t.depends_on.length) lines.push(`- Depends on (contract only): ${t.depends_on.join(', ')}`);
    lines.push(`- Description: ${t.description}`);
    lines.push(`- Acceptance: ${t.acceptance}`);
    if (t.verify) lines.push(`- Verify: \`${t.verify}\``);
    return lines.join('\n');
  }).join('\n\n');
}

function buildAgentPrompt({ agent, project, tasks, tickCmd, workdir, maxAttempts, transport }) {
  const file = transport === 'mcp' ? 'agent-loop-mcp.md' : 'agent-loop.md';
  const template = fs.readFileSync(path.join(PROMPT_DIR, file), 'utf8');
  return render(template, {
    AGENT: agent,
    PROJECT_NAME: project.name,
    PROJECT_GOAL: project.goal,
    PROJECT_KIND: project.kind,
    MAX_CLAIMS: project.max_active_claims_per_agent,
    MAX_ATTEMPTS: maxAttempts,
    TICK: tickCmd,
    WORKDIR: workdir,
    TASK_TABLE: taskTable(tasks),
    TASK_DETAILS: taskDetails(tasks),
    PROJECT_VERIFY: project.verify || '(none — rely on per-task verify / acceptance)',
  });
}

function buildPreflightPrompt({ agent, project, tasks, workdir }) {
  const template = fs.readFileSync(path.join(PROMPT_DIR, 'preflight.md'), 'utf8');
  return render(template, {
    AGENT: agent,
    PROJECT_NAME: project.name,
    PROJECT_GOAL: project.goal,
    PROJECT_KIND: project.kind,
    WORKDIR: workdir,
    TASK_TABLE: taskTable(tasks),
    TASK_DETAILS: taskDetails(tasks),
  });
}

module.exports = { buildAgentPrompt, buildPreflightPrompt, render, taskTable, taskDetails };
