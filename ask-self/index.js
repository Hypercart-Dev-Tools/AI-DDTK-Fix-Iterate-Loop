// Sleuth Code RAG — query module.
// Exports askSelf(query, teamId) used by chat-module for the `ask-self` command.
// Tenancy gate is layer 2 (module-level) per PROJECT/2-WORKING/P1-CODE-RAG.md.

const path = require('node:path');
const fs = require('node:fs');
const { formatContext } = require('./helpers.js');

const MODULE_DIR = __dirname;
const REPO_ROOT = path.join(MODULE_DIR, '..', '..');
const DB_PATH = path.join(REPO_ROOT, 'data', 'rag', 'sleuth-rag.sqlite');
const PROMPTS_PATH = path.join(MODULE_DIR, 'prompts.json');

const EMBED_MODEL = 'gemini-embedding-001';
const EMBED_DIM = 768;
const SYNTHESIS_MODEL = 'gemini-pro-latest'; // rolling alias — always newest Gemini Pro
const TOP_K = 20;                 // retrieve generously, trust Gemini to sort
const PRIORITY_BOOST = 0.02;      // small nudge — doesn't override clear semantic wins
const MAX_CONTEXT_CHARS = 80000;  // ~20k tokens — spike showed 18k works well

class TenancyError extends Error {
  constructor(message) {
    super(message);
    this.name = 'TenancyError';
  }
}

// Lazy-loaded singletons so a missing env var at boot doesn't kill the process.
// They throw on first askSelf() call instead, which chat-module catches silently.
let _db = null;
let _prompts = null;

function getDb() {
  if (_db) return _db;
  if (!fs.existsSync(DB_PATH)) {
    throw new Error(`RAG index missing at ${DB_PATH}. Run: npm run rag:ingest`);
  }
  // Lazy-require native modules so a broken install doesn't poison Sleuth startup
  // for workspaces that never touch ask-self.
  const Database = require('better-sqlite3');
  const sqliteVec = require('sqlite-vec');
  _db = new Database(DB_PATH, { readonly: true });
  sqliteVec.load(_db);
  return _db;
}

function getPrompts() {
  if (_prompts) return _prompts;
  _prompts = JSON.parse(fs.readFileSync(PROMPTS_PATH, 'utf8'));
  return _prompts;
}

function assertTenancy(teamId) {
  const allowed = process.env.NEOCHROME_TEAM_ID;
  if (typeof allowed !== 'string' || allowed.length === 0) {
    throw new TenancyError('NEOCHROME_TEAM_ID not configured');
  }
  if (typeof teamId !== 'string' || teamId.length === 0) {
    throw new TenancyError('teamId argument required');
  }
  if (teamId !== allowed) {
    throw new TenancyError('teamId does not match allowlist');
  }
}

async function embedQuery(query) {
  const apiKey = process.env.GOOGLE_API_KEY;
  if (!apiKey) throw new Error('GOOGLE_API_KEY not set');
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${EMBED_MODEL}:embedContent?key=${apiKey}`;
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: `models/${EMBED_MODEL}`,
      content: { parts: [{ text: query }] },
      taskType: 'RETRIEVAL_QUERY',
      outputDimensionality: EMBED_DIM,
    }),
  });
  if (!res.ok) throw new Error(`Gemini embed ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
  const values = data?.embedding?.values;
  if (!Array.isArray(values) || values.length !== EMBED_DIM) {
    throw new Error(`Gemini embed: unexpected shape, got ${values?.length} dims`);
  }
  return new Uint8Array(new Float32Array(values).buffer);
}

function knnSearch(db, queryVec, k = TOP_K) {
  const hits = db.prepare(
    'SELECT rowid, distance FROM chunks_vec WHERE embedding MATCH ? ORDER BY distance LIMIT ?'
  ).all(queryVec, k);
  if (hits.length === 0) return [];
  const ids = hits.map((h) => Number(h.rowid));
  const placeholders = ids.map(() => '?').join(',');
  const rows = db.prepare(
    `SELECT id, source, path, pr_number, version, priority, content FROM chunks WHERE id IN (${placeholders})`
  ).all(...ids);
  const byId = new Map(rows.map((r) => [Number(r.id), r]));
  // Re-rank with priority boost: lower score is better.
  // Drop hits whose metadata row is missing (e.g., partial/corrupt index) rather
  // than spreading undefined into the result and throwing. Missing rows are logged
  // once so an operator notices the drift instead of debugging silent gaps.
  const dropped = [];
  const ranked = [];
  for (const h of hits) {
    const row = byId.get(Number(h.rowid));
    if (!row) {
      dropped.push(h.rowid);
      continue;
    }
    const score = h.distance - (row.priority ?? 1) * PRIORITY_BOOST;
    ranked.push({ ...row, distance: h.distance, score });
  }
  if (dropped.length > 0) {
    console.warn(`[rag] knnSearch: dropped ${dropped.length} hit(s) with missing metadata rows (rowids: ${dropped.join(', ')}). Rebuild the index with: npm run rag:ingest`);
  }
  return ranked.sort((a, b) => a.score - b.score);
}

async function synthesize(query, context, systemPrompt) {
  const apiKey = process.env.GOOGLE_API_KEY;
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${SYNTHESIS_MODEL}:generateContent?key=${apiKey}`;
  const userMessage = `CONTEXT (retrieved from Sleuth's own corpus):\n\n${context}\n\n---\n\nQUESTION: ${query}`;
  const body = {
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents: [{ role: 'user', parts: [{ text: userMessage }] }],
    generationConfig: { temperature: 0.3, maxOutputTokens: 1500 },
  };
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Gemini synthesis ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('Gemini synthesis: empty response');
  return text;
}

/**
 * Answer a question about Sleuth itself, grounded in the local RAG index.
 * Strictly gated to the Neochrome workspace via NEOCHROME_TEAM_ID.
 *
 * @param {string} query - The question from the user.
 * @param {string} teamId - The Slack team ID of the workspace the question came from.
 * @returns {Promise<string>} - Formatted answer text to post back in Slack.
 * @throws {TenancyError} - If teamId does not match NEOCHROME_TEAM_ID.
 */
async function askSelf(query, teamId) {
  assertTenancy(teamId);
  if (typeof query !== 'string' || query.trim().length === 0) {
    throw new Error('query must be a non-empty string');
  }
  const prompts = getPrompts();
  const db = getDb();
  const queryVec = await embedQuery(query);
  const hits = knnSearch(db, queryVec, TOP_K);
  if (hits.length === 0) {
    return "I couldn't find anything in my index for that question. Try `npm run rag:ingest` or rephrase.";
  }
  const context = formatContext(hits, MAX_CONTEXT_CHARS);
  const answer = await synthesize(query, context, prompts.orchestrator_system);
  const sourcesList = [...new Set(hits.slice(0, 8).map((h) =>
    h.source === 'pr' ? `PR #${h.pr_number}` : h.path
  ))];
  return `${answer}\n\n_Sources consulted: ${sourcesList.join(', ')}_`;
}

module.exports = { askSelf, TenancyError };
