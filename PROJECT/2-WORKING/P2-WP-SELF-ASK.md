# PHP-Aware Chunker for Sleuth RAG — Claude Code Spec

## Context

This spec extends the Sleuth Code RAG ingest pipeline (`src/rag/ingest.mjs` +
`src/rag/helpers.js`) to handle PHP source files with structural awareness.
The existing flat `chunkText()` works for prose docs. PHP needs boundary-aware
chunking so each retrieval unit is a coherent, citable code artifact.

**Do not break existing behaviour.** All current exports from `helpers.js` must
remain API-compatible. PHP chunking is additive.

---

## Goals

1. Split PHP files on class/function/hook boundaries — not character count alone.
2. Elevate `add_action` / `add_filter` declarations as high-priority standalone chunks.
3. Keep chunk size within the existing `CHUNK_TARGET_CHARS` (4800) budget; fall
   back to `chunkText()` for oversized blocks.
4. Attach structured metadata (`hook_name`, `callback`, `priority_arg`) to hook
   chunks so `formatContext()` can emit useful headers.
5. Skip minified, vendor, and generated files before any chunking occurs.

---

## Deliverables

### 1. `helpers.js` additions (CJS, appended to existing file)

Add the following exports. **Do not remove or modify existing exports.**

#### `chunkPhp(text, filePath, options)`

```js
/**
 * Split a PHP source file into structured chunks at class/function/hook
 * boundaries. Falls back to chunkText() for blocks that exceed targetChars.
 *
 * @param {string} text           - Raw PHP file contents
 * @param {string} filePath       - Repo-relative path (used for metadata only)
 * @param {{targetChars?: number, overlap?: number}} [options]
 * @returns {Array<PhpChunk>}
 *
 * @typedef {Object} PhpChunk
 * @property {'class'|'function'|'hook'|'preamble'} kind
 * @property {string}      content       - The chunk text (may include leading docblock)
 * @property {string|null} name          - Class or function name; null for preamble
 * @property {string|null} hook_name     - WP hook name for kind==='hook'; else null
 * @property {string|null} hook_callback - Callback string for kind==='hook'; else null
 * @property {number}      priority      - PRIORITY value to use in the index
 */
function chunkPhp(text, filePath, options = {}) { ... }
```

**Implementation notes for Claude:**

- Split on these boundary patterns (multiline regex, `m` flag):
  - Class: `/^(abstract\s+|final\s+)?class\s+\w+/m`
  - Function: `/^(public\s+|protected\s+|private\s+|static\s+|function\s+){1,3}function\s+\w+/m`
    — but **only** top-level functions and class methods that open at column 0
    or 1 tab. Inner closures should stay attached to their parent block.
  - Hook: `/add_(action|filter)\s*\(/` — extract via the helper below.
- Capture the docblock (`/** ... */`) immediately preceding each boundary and
  prepend it to the chunk.
- After splitting, if any chunk exceeds `targetChars`, pass it through
  `chunkText(chunk, options)` and tag all sub-chunks with the parent's `kind`
  and `name`.
- Assign `priority` from `PRIORITY.wp_hook` (8) for hook chunks,
  `PRIORITY.wp_php` (3) for class/function, `PRIORITY.doc` (1) for preamble.

---

#### `extractHooks(text)`

```js
/**
 * Find all add_action / add_filter calls in a PHP string and return structured
 * records. Handles single-line calls only — multiline calls are skipped silently
 * (they're uncommon and error-prone to regex-parse without an AST).
 *
 * @param {string} text
 * @returns {Array<{kind: 'hook', hook_name: string, hook_callback: string, content: string, priority: number}>}
 */
function extractHooks(text) { ... }
```

**Implementation notes for Claude:**

- Regex: `/add_(action|filter)\s*\(\s*['"]([^'"]+)['"]\s*,\s*([^,\)]+)/g`
  - Group 1: `action|filter`
  - Group 2: hook name string
  - Group 3: callback expression (trim whitespace)
- `content` should be the full matched line (use `text.split('\n')` to find it).
- Return empty array on no matches — never throw.

---

#### `shouldSkipFile(relPath)`

```js
/**
 * Returns true if a file should be excluded from ingest entirely.
 * Call this in ingest.mjs before reading file contents.
 *
 * @param {string} relPath - repo-relative path, forward slashes
 * @returns {boolean}
 */
function shouldSkipFile(relPath) { ... }
```

**Skip patterns:**

```js
const SKIP_PATTERNS = [
  /\.min\.(js|css)$/i,
  /\/vendor\//i,
  /\/node_modules\//i,
  /\/dist\//i,
  /\/\.git\//,
  /\/build\//i,
  /\.map$/,
];
```

---

#### `PRIORITY` additions

Merge into the existing `PRIORITY` object (do not replace it — spread or assign):

```js
PRIORITY.wp_php  = 3;   // PHP class/function chunks
PRIORITY.wp_hook = 8;   // add_action / add_filter declarations — highest signal
PRIORITY.style   = 1;   // CSS/SCSS (same as doc — flat chunking is fine)
PRIORITY.js_module = 2; // JS module chunks
```

---

### 2. `classifyDoc()` extension

Extend the existing `classifyDoc(relPath)` function to recognise PHP and CSS
before falling through to the default `doc` case:

```
PHP file  → { source: 'wp_php',   priority: PRIORITY.wp_php }
CSS/SCSS  → { source: 'style',    priority: PRIORITY.style }
JS module → { source: 'js_module',priority: PRIORITY.js_module }
```

Pattern additions (insert before the final `return { source: 'doc', ... }` line):

```js
if (/\.php$/i.test(relPath))             return { source: 'wp_php',    priority: PRIORITY.wp_php };
if (/\.(css|scss|less)$/i.test(relPath)) return { source: 'style',     priority: PRIORITY.style };
if (/\.(js|mjs|cjs|ts)$/i.test(relPath)) return { source: 'js_module', priority: PRIORITY.js_module };
```

---

### 3. `formatContext()` extension

`formatContext()` already handles `pr`, `changelog`, and generic `doc` headers.
Add PHP hook header support:

```js
// Inside the header-building block, add before the final `else`:
: h.source === 'wp_php' && h.kind === 'hook'
  ? `[${h.path} — hook:${h.hook_name}]`
  : h.source === 'wp_php'
  ? `[${h.path}${h.name ? ` — ${h.name}` : ''}]`
```

---

### 4. `ingest.mjs` integration

Locate the file-walking loop (the section that reads each file and calls
`chunkText()`). Make the following changes:

1. Import the new helpers at the top:
   ```js
   import { chunkPhp, shouldSkipFile, classifyDoc, PRIORITY } from './helpers.js';
   ```

2. Before reading file contents, add the skip guard:
   ```js
   if (shouldSkipFile(relPath)) continue;
   ```

3. Route PHP files through `chunkPhp()`:
   ```js
   const chunks = relPath.endsWith('.php')
     ? chunkPhp(fileText, relPath)
     : chunkText(fileText);           // existing path for all other types
   ```

4. When inserting rows, spread PhpChunk metadata into the `chunks` table row:
   ```js
   insertChunk.run({
     source:        classified.source,
     path:          relPath,
     kind:          chunk.kind   ?? null,
     name:          chunk.name   ?? null,
     hook_name:     chunk.hook_name ?? null,
     hook_callback: chunk.hook_callback ?? null,
     priority:      chunk.priority ?? classified.priority,
     content:       chunk.content,
   });
   ```

   > **Schema note:** If `chunks` table does not have `kind`, `name`,
   > `hook_name`, `hook_callback` columns, add a migration in `ingest.mjs`
   > (run-once `ALTER TABLE` guarded by `PRAGMA table_info`).

---

## Tests to write (`src/rag/__tests__/helpers.php.test.js`)

Use the existing test runner (assume Jest or Node test runner — check
`package.json` before choosing).

| Test | Input | Expected |
|------|-------|----------|
| `chunkPhp` — single function | `<?php\nfunction foo() { return 1; }` | 1 chunk, kind=`function`, name=`foo` |
| `chunkPhp` — class with methods | Full class string | 1 chunk per method + 1 class-preamble chunk |
| `chunkPhp` — oversized method | Method body > 4800 chars | Sub-chunks all carry parent name |
| `extractHooks` — action | `add_action( 'init', 'my_cb' );` | `{hook_name:'init', hook_callback:'my_cb'}` |
| `extractHooks` — no hooks | Plain PHP, no hooks | Empty array |
| `shouldSkipFile` — vendor | `wp-content/plugins/x/vendor/foo.php` | `true` |
| `shouldSkipFile` — plugin file | `wp-content/plugins/x/class-x.php` | `false` |
| `classifyDoc` — PHP | `src/class-order.php` | `source:'wp_php'` |
| `classifyDoc` — strategy (existing) | `docs/strategy.md` | `source:'strategy'` (unchanged) |

---

## Constraints & guardrails

- **No new runtime dependencies** for `helpers.js`. Pure string/regex only.
  `ingest.mjs` may add dev dependencies if needed (e.g., a PHP CLI wrapper)
  but do not add an AST parser in this iteration — regex is the deliberate
  scope limit.
- `helpers.js` must remain importable from both CJS (`require`) and ESM
  (`import`) contexts. The existing dual-compat pattern (CJS `module.exports`)
  is fine; do not convert to ESM.
- Do not alter `askSelf()` in `index.js` — retrieval is already source-agnostic.
- Keep `chunkText()`, `chunkChangelog()`, `classifyDoc()`, `formatContext()`
  signatures backward-compatible. Existing callers must not break.
- All new functions must have JSDoc headers matching the style in `helpers.js`.

---

## Out of scope (future iterations)

- PHP AST parsing via `nikic/php-parser` — flag with a `// TODO: AST` comment
  anywhere the regex approach has a known gap (e.g., multiline hook calls).
- SCSS variable/mixin-aware chunking.
- JS/TS import graph–aware chunking.
- Incremental ingest (only re-chunk changed files).