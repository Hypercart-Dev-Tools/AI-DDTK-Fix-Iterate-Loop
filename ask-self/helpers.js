// Pure-function helpers for the RAG module. No I/O, no global state — safe to
// import from either the CJS query module (src/rag/index.js) or the ESM ingest
// script (src/rag/ingest.mjs). Every function here is designed to be unit-tested
// without mocks, network access, or a filesystem.

const CHUNK_TARGET_CHARS = 4800;  // ~1200 tokens
const CHUNK_OVERLAP_CHARS = 600;  // ~150 tokens

// Priority boosts applied during retrieval re-rank. Higher priority wins at
// near-equal distance. See the spike learning in PROJECT/2-WORKING/P1-CODE-RAG.md
// for why strategy/changelog beat regular docs.
const PRIORITY = {
  feature_map: 10,
  strategy: 5,
  changelog_entry: 5,
  doc: 1,
  pr: 1,
};

/**
 * Split text into overlapping chunks sized for embedding. Returns the original
 * text as a single-element array if it's already short enough.
 *
 * @param {string} text
 * @param {{targetChars?: number, overlap?: number}} [options]
 * @returns {string[]}
 */
function chunkText(text, { targetChars = CHUNK_TARGET_CHARS, overlap = CHUNK_OVERLAP_CHARS } = {}) {
  if (typeof text !== 'string') throw new TypeError('chunkText: text must be a string');
  if (targetChars <= 0) throw new RangeError('chunkText: targetChars must be > 0');
  if (overlap < 0 || overlap >= targetChars) throw new RangeError('chunkText: overlap must be >= 0 and < targetChars');
  if (text.length === 0) return [];
  if (text.length <= targetChars) return [text];
  const chunks = [];
  let i = 0;
  while (i < text.length) {
    const end = Math.min(i + targetChars, text.length);
    chunks.push(text.slice(i, end));
    if (end >= text.length) break;
    i = end - overlap;
  }
  return chunks;
}

/**
 * Split a CHANGELOG.md into one chunk per version entry. Version headers are
 * expected to match `## 1.2.3` at the start of a line. The returned version
 * string is the `1.2.3` capture from the header, or null if the chunk didn't
 * start with a version header (e.g., a preamble paragraph).
 *
 * @param {string} text
 * @returns {Array<{version: string|null, content: string}>}
 */
function chunkChangelog(text) {
  if (typeof text !== 'string') throw new TypeError('chunkChangelog: text must be a string');
  const parts = text.split(/(?=^##\s+\d+\.\d+\.\d+)/m).map((s) => s.trim()).filter(Boolean);
  return parts.map((entry) => {
    const versionMatch = entry.match(/^##\s+(\d+\.\d+\.\d+)/);
    return { version: versionMatch ? versionMatch[1] : null, content: entry };
  });
}

/**
 * Classify a doc by its repo-relative path. Strategy/PMF/positioning docs and
 * the CHANGELOG get a priority boost so retrieval surfaces them for marketing
 * questions even when semantic distance is close.
 *
 * @param {string} relPath - repo-relative path (forward slashes)
 * @returns {{source: 'changelog'|'strategy'|'doc', priority: number}}
 */
function classifyDoc(relPath) {
  if (typeof relPath !== 'string' || relPath.length === 0) {
    throw new TypeError('classifyDoc: relPath must be a non-empty string');
  }
  if (/changelog\.md$/i.test(relPath)) {
    return { source: 'changelog', priority: PRIORITY.changelog_entry };
  }
  if (/strategy|product.*brief|moat|pmf|positioning/i.test(relPath)) {
    return { source: 'strategy', priority: PRIORITY.strategy };
  }
  return { source: 'doc', priority: PRIORITY.doc };
}

/**
 * Format retrieved chunks into a single context string for the synthesis model,
 * budget-capped by total character count. Each chunk gets a source-aware header
 * so the model can cite it correctly. Oldest-first order is preserved.
 *
 * @param {Array<{source: string, path?: string, pr_number?: number|null, version?: string|null, content: string}>} hits
 * @param {number} [maxContextChars=80000]
 * @returns {string}
 */
function formatContext(hits, maxContextChars = 80000) {
  if (!Array.isArray(hits)) throw new TypeError('formatContext: hits must be an array');
  const parts = [];
  let totalChars = 0;
  for (const h of hits) {
    if (!h || typeof h.content !== 'string') continue;
    const header = h.source === 'pr'
      ? `[PR #${h.pr_number}]`
      : h.source === 'changelog'
        ? `[changelog.md${h.version ? ` — ${h.version}` : ''}]`
        : `[${h.path ?? h.source}]`;
    const block = `=== ${header} ===\n${h.content}\n`;
    if (totalChars + block.length > maxContextChars) break;
    parts.push(block);
    totalChars += block.length;
  }
  return parts.join('\n');
}

module.exports = {
  CHUNK_TARGET_CHARS,
  CHUNK_OVERLAP_CHARS,
  PRIORITY,
  chunkText,
  chunkChangelog,
  classifyDoc,
  formatContext,
};
