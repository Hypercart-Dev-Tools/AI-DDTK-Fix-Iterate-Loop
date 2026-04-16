#!/usr/bin/env node
// Sleuth Code RAG — corpus ingest.
// Walks docs + changelog + GitHub PRs, chunks, embeds via Gemini, writes sqlite-vec.
// Run: npm run rag:ingest
// Env: GOOGLE_API_KEY (required), SLEUTH_RAG_GITHUB_PAT (optional — skips PR fetch if unset)

import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync, readdirSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative, extname } from 'node:path';
import Database from 'better-sqlite3';
import * as sqliteVec from 'sqlite-vec';
import { Octokit } from '@octokit/rest';
import { createRequire } from 'node:module';

// Bridge CJS helpers into this ESM module so the pure functions have a single
// source of truth and can be unit-tested in isolation.
const require = createRequire(import.meta.url);
const { PRIORITY, CHUNK_TARGET_CHARS, chunkText, chunkChangelog, classifyDoc } = require('./helpers.js');

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..', '..');
const DATA_DIR = join(REPO_ROOT, 'data', 'rag');
const DB_PATH = join(DATA_DIR, 'sleuth-rag.sqlite');

const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY;
if (!GOOGLE_API_KEY) {
  console.error('FATAL: GOOGLE_API_KEY not set. Run: source ~/secrets/binoid-rag.env');
  process.exit(1);
}

const GITHUB_PAT = process.env.SLEUTH_RAG_GITHUB_PAT;
const GITHUB_OWNER = 'NeochromeTeam';
const GITHUB_REPO = 'sleuth-app';
const PR_FETCH_LIMIT = 200;

const EMBED_MODEL = 'gemini-embedding-001';
const EMBED_DIM = 768;
const EMBED_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${EMBED_MODEL}:embedContent?key=${GOOGLE_API_KEY}`;

const INCLUDE_DOCS = [
  /^[^/]+\.md$/,                // root-level .md files (AGENTS, CLAUDE, README, changelog, etc.)
  /^PROJECT\/.+\.md$/,          // strategy / working / archive docs
];
const EXCLUDE_PATHS = [
  /^node_modules\//,
  /^\.git\//,
  /^data\//,
  /^tests\//,
  /^src\/rag\//,                // don't ingest ourselves
  /^scratch\//,
];

// ---------- file walker ----------

function walkRepoFiles() {
  const out = [];
  function walk(absDir) {
    for (const entry of readdirSync(absDir, { withFileTypes: true })) {
      const abs = join(absDir, entry.name);
      const rel = relative(REPO_ROOT, abs);
      if (EXCLUDE_PATHS.some((re) => re.test(rel))) continue;
      if (entry.isDirectory()) {
        walk(abs);
      } else if (entry.isFile()) {
        if (INCLUDE_DOCS.some((re) => re.test(rel))) {
          out.push({ abs, rel });
        }
      }
    }
  }
  walk(REPO_ROOT);
  return out.sort((a, b) => a.rel.localeCompare(b.rel));
}

// ---------- embeddings ----------

async function embedOne(text, taskType = 'RETRIEVAL_DOCUMENT') {
  const body = {
    model: `models/${EMBED_MODEL}`,
    content: { parts: [{ text }] },
    taskType,
    outputDimensionality: EMBED_DIM,
  };
  const res = await fetch(EMBED_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Gemini embed ${res.status}: ${t.slice(0, 400)}`);
  }
  const data = await res.json();
  const values = data?.embedding?.values;
  if (!Array.isArray(values) || values.length !== EMBED_DIM) {
    throw new Error(`Gemini embed: unexpected shape, got ${values?.length} dims`);
  }
  return values;
}

async function embedBatch(chunks, taskType = 'RETRIEVAL_DOCUMENT') {
  // Gemini REST doesn't accept free-form batching for outputDimensionality on embedContent in v1beta reliably,
  // so we parallelize with a concurrency cap — simple and fast for our corpus size.
  const CONCURRENCY = 4;
  const results = new Array(chunks.length);
  let nextIdx = 0;
  async function worker() {
    while (nextIdx < chunks.length) {
      const idx = nextIdx++;
      let attempt = 0;
      while (true) {
        try {
          results[idx] = await embedOne(chunks[idx], taskType);
          break;
        } catch (err) {
          attempt++;
          if (attempt >= 3) throw err;
          await new Promise((r) => setTimeout(r, 500 * attempt));
        }
      }
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, () => worker()));
  return results;
}

// ---------- sqlite ----------

function openDb() {
  mkdirSync(DATA_DIR, { recursive: true });
  if (existsSync(DB_PATH)) {
    // fresh rebuild each run — we're indexing a small corpus and want deterministic state
    unlinkSync(DB_PATH);
  }
  const db = new Database(DB_PATH);
  sqliteVec.load(db);
  db.exec(`
    CREATE TABLE chunks (
      id INTEGER PRIMARY KEY,
      source TEXT NOT NULL,
      path TEXT,
      pr_number INTEGER,
      version TEXT,
      priority INTEGER NOT NULL DEFAULT 1,
      content TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
    CREATE VIRTUAL TABLE chunks_vec USING vec0(embedding float[${EMBED_DIM}]);
  `);
  return db;
}

function insertChunk(db, row, embedding) {
  const res = db.prepare(`
    INSERT INTO chunks (source, path, pr_number, version, priority, content)
    VALUES (@source, @path, @pr_number, @version, @priority, @content)
  `).run({
    source: row.source,
    path: row.path ?? null,
    pr_number: row.pr_number ?? null,
    version: row.version ?? null,
    priority: row.priority ?? 1,
    content: row.content,
  });
  const id = res.lastInsertRowid; // already a BigInt under better-sqlite3 default when large
  db.prepare('INSERT INTO chunks_vec(rowid, embedding) VALUES (?, ?)').run(
    typeof id === 'bigint' ? id : BigInt(id),
    new Uint8Array(new Float32Array(embedding).buffer)
  );
}

// ---------- PR fetch ----------

async function fetchMergedPRs() {
  if (!GITHUB_PAT) {
    console.log('  [skip] SLEUTH_RAG_GITHUB_PAT not set — skipping PR fetch');
    return [];
  }
  const octokit = new Octokit({ auth: GITHUB_PAT });
  // Track cumulative count across pages — the previous version compared per-page
  // length (<=100) against PR_FETCH_LIMIT (200) and therefore never stopped early,
  // paginating through all closed PRs before slicing.
  let cumulative = 0;
  const pulls = await octokit.paginate(octokit.pulls.list, {
    owner: GITHUB_OWNER,
    repo: GITHUB_REPO,
    state: 'closed',
    sort: 'updated',
    direction: 'desc',
    per_page: 100,
  }, (res, done) => {
    cumulative += res.data.length;
    if (cumulative >= PR_FETCH_LIMIT) done();
    return res.data;
  });
  const merged = pulls.filter((p) => p.merged_at).slice(0, PR_FETCH_LIMIT);
  return merged.map((p) => ({
    number: p.number,
    title: p.title,
    body: p.body ?? '',
    merged_at: p.merged_at,
    author: p.user?.login ?? 'unknown',
  }));
}

// ---------- main ----------

async function main() {
  console.log(`\n=== Sleuth RAG ingest ===\n`);
  const t0 = Date.now();

  // 1) walk docs
  const files = walkRepoFiles();
  console.log(`[1/4] Walking docs: found ${files.length} markdown files`);
  const docRows = [];
  for (const f of files) {
    const text = readFileSync(f.abs, 'utf8');
    const cls = classifyDoc(f.rel);
    if (cls.source === 'changelog') {
      const entries = chunkChangelog(text);
      for (const e of entries) {
        docRows.push({
          source: 'changelog',
          path: f.rel,
          version: e.version,
          priority: cls.priority,
          content: e.content,
        });
      }
    } else {
      const chunks = chunkText(text);
      for (let i = 0; i < chunks.length; i++) {
        docRows.push({
          source: cls.source,
          path: f.rel,
          priority: cls.priority,
          content: chunks[i],
        });
      }
    }
  }
  console.log(`  → ${docRows.length} doc chunks`);

  // 2) fetch PRs
  console.log(`[2/4] Fetching GitHub PRs (limit ${PR_FETCH_LIMIT})`);
  const prs = await fetchMergedPRs();
  const prRows = prs.map((p) => ({
    source: 'pr',
    path: `PR #${p.number}`,
    pr_number: p.number,
    priority: PRIORITY.pr,
    content: `PR #${p.number}: ${p.title}\nMerged: ${p.merged_at} by ${p.author}\n\n${p.body}`.slice(0, CHUNK_TARGET_CHARS * 2),
  }));
  console.log(`  → ${prRows.length} PR chunks`);

  // 3) embed
  const allRows = [...docRows, ...prRows];
  console.log(`[3/4] Embedding ${allRows.length} chunks via ${EMBED_MODEL} (dim=${EMBED_DIM})`);
  const tEmbed = Date.now();
  const embeddings = await embedBatch(allRows.map((r) => r.content));
  console.log(`  → done in ${((Date.now() - tEmbed) / 1000).toFixed(1)}s`);

  // 4) write sqlite
  console.log(`[4/4] Writing ${DB_PATH}`);
  const db = openDb();
  const txn = db.transaction(() => {
    for (let i = 0; i < allRows.length; i++) {
      insertChunk(db, allRows[i], embeddings[i]);
    }
  });
  txn();
  const total = db.prepare('SELECT COUNT(*) as c FROM chunks').get().c;
  const byTable = db.prepare("SELECT source, COUNT(*) as c FROM chunks GROUP BY source ORDER BY c DESC").all();
  db.close();

  console.log(`\n=== Ingest complete in ${((Date.now() - t0) / 1000).toFixed(1)}s ===`);
  console.log(`Total chunks: ${total}`);
  console.log('By source:');
  for (const row of byTable) console.log(`  ${row.source.padEnd(12)} ${row.c}`);
  console.log(`\nDB: ${DB_PATH}`);
}

main().catch((err) => {
  console.error('\nFATAL:', err);
  process.exit(1);
});
