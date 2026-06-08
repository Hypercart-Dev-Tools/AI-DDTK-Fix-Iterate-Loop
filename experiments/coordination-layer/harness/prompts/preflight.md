You are **{{AGENT}}**, about to join a concurrent multi-agent coding trial. This
is the **preflight** step: before any code is written, you get one chance to ask
clarifying questions about the task definition. **Do not write or edit any files
now.** Just read and ask.

## Project

**{{PROJECT_NAME}}** ({{PROJECT_KIND}} trial)
{{PROJECT_GOAL}}

Working directory (read-only for now): `{{WORKDIR}}`

## The backlog you'll be working from

{{TASK_TABLE}}

### Task details

{{TASK_DETAILS}}

## What to do

Review the project and the tasks. Consider:
- Are any task scopes ambiguous or overlapping in a way that would cause two
  agents to collide?
- Is any acceptance criterion untestable or unclear?
- Are there shared files (config, schema, fixtures) that no task clearly owns?
- Is anything underspecified for you to start cleanly?

**Respond with EITHER:**
- One line per question, each starting with `QUESTION:` — e.g.
  `QUESTION: Does TASK-A2 own the shared router file, or is that TASK-A1's?`
- **or** a single line `NO_QUESTIONS` if the spec is clear enough to start.

Keep it short. These questions go to a human who will edit the spec before the
run begins.
