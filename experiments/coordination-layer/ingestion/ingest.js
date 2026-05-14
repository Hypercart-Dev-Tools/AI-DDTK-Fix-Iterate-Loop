#!/usr/bin/env node
'use strict';

/**
 * Task ingestion layer — STUB / SCAFFOLD.
 *
 * Status: not implemented. Scaffolded 2026-05-14 to preserve the design.
 * NOT wired into Trinity Run 2. See ./README.md for the full design rationale.
 *
 * Pipeline:  project spec (.md) -> [parse] -> [LLM review] -> [human gate] -> .tick/events/
 *
 * Usage (once implemented):
 *   node ingest.js <path-to-project-spec.md> [--emit <dir>] [--dry-run]
 */

// ---------------------------------------------------------------------------
// Stage 1 — deterministic parse
// Pure, no LLM. Same .md in -> same structure out. Extract project metadata
// and each `### TASK-*` block into structured objects. Hard-fail on: missing
// required fields, duplicate task IDs, empty path scopes, non-numeric
// priority, dependency cycles.
// ---------------------------------------------------------------------------
function parseSpec(markdownText) {
  // TODO: implement deterministic markdown -> { project, tasks[] } parse + validation.
  throw new Error('ingest.js: parseSpec not implemented (scaffold)');
}

// ---------------------------------------------------------------------------
// Stage 2 — LLM review + orchestrate
// Send the parsed structure to an LLM with a review prompt. It judges what a
// parser can't: scope overlaps, task sizing, testable acceptance, coverage
// gaps. May also suggest ordering / half-assignment. Returns
// { approved, issues[], suggestions[] }. The LLM advises; it does not decide.
// ---------------------------------------------------------------------------
async function llmReview(parsed) {
  // TODO: call the Anthropic SDK (with prompt caching) with a review prompt.
  throw new Error('ingest.js: llmReview not implemented (scaffold)');
}

// ---------------------------------------------------------------------------
// Stage 3 — human gate
// If parse or review flagged anything, surface it and stop. The human edits
// the .md and re-runs. Only a clean, human-approved pass proceeds to emit.
// ---------------------------------------------------------------------------
function humanGate(parsed, review) {
  // TODO: print issues/suggestions; exit non-zero unless clean + confirmed.
  throw new Error('ingest.js: humanGate not implemented (scaffold)');
}

// ---------------------------------------------------------------------------
// Emit — write task.created JSONL events into .tick/events/
// Open question: emit directly, or an intermediate reviewable tasks.json
// plus a `tick log` script? Decide at implementation time. See README.md.
// ---------------------------------------------------------------------------
function emitEvents(parsed, outDir) {
  // TODO: serialize tasks to task.created events matching the tick event schema.
  throw new Error('ingest.js: emitEvents not implemented (scaffold)');
}

async function main(argv) {
  // TODO: wire the stages — parse -> llmReview -> humanGate -> emitEvents.
  throw new Error('ingest.js is a scaffold — pipeline not implemented. See README.md');
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}

module.exports = { parseSpec, llmReview, humanGate, emitEvents };
