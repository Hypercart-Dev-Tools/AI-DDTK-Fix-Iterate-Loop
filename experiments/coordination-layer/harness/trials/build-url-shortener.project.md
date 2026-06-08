# Project: URL shortener (build)

**Goal:** Build a small URL-shortener library with three non-overlapping concerns — a base62 codec, a persistence layer, and an HTTP facade — to test path-routing on a different shape than the Todo API (three thin halves instead of two).
**Branch:** experiment/coordination-layer
**Kind:** build
**Agents:** gemini, codex
**Path-scoping strategy:** per-concern (codec / store / http)
**Max active claims per agent:** 2

## Constraints

- Standard library only.
- Each concern lives entirely under its own directory; no cross-directory edits.

## Sub-tasks

### TASK-CODEC1 — base62 encode/decode

- **Declared scope:** `src/codec/**`
- **Files:** `src/codec/base62.js`
- **Priority:** 10
- **Depends on (contract only):** none
- **Description:** Encode an integer id to a base62 short code and decode it back.
- **Acceptance:** decode(encode(n)) === n for a range of n.

### TASK-STORE1 — link store

- **Declared scope:** `src/store/**`
- **Files:** `src/store/links.js`
- **Priority:** 9
- **Depends on (contract only):** none
- **Description:** In-memory map from short code to long URL with put/get.
- **Acceptance:** put then get round-trips a URL; missing code returns null.

### TASK-HTTP1 — shorten endpoint

- **Declared scope:** `src/http/**`
- **Files:** `src/http/shorten.js`
- **Priority:** 7
- **Depends on (contract only):** TASK-CODEC1, TASK-STORE1
- **Description:** POST handler that stores a URL and returns its short code.
- **Acceptance:** Returns 201 with a code that resolves back to the URL.

### TASK-HTTP2 — redirect endpoint

- **Declared scope:** `src/http/**`
- **Files:** `src/http/redirect.js`
- **Priority:** 6
- **Depends on (contract only):** TASK-STORE1
- **Description:** GET handler that 302-redirects a short code to its long URL.
- **Acceptance:** Known code → 302 with Location; unknown code → 404.
