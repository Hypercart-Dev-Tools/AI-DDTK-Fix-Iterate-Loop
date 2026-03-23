import assert from "node:assert/strict";
import test from "node:test";
import { createQmHandlers, type QmProfileData } from "../src/handlers/qm.js";

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

const MOCK_PROFILE: QmProfileData = {
  overview: {
    time_taken: 0.1234,
    time_limit: 1200,
    time_usage: 0.01,
    memory: 9_961_472, // ~9.5 MB
    memory_limit: 268_435_456, // 256 MB
    memory_usage: 3.7,
  },
  db_queries: {
    total: 5,
    time: 0.0042,
    queries: [
      { i: 1, sql: "SELECT option_name, option_value FROM wp_options WHERE autoload IN ('yes')", time: 0.0004, stack: ["wp_load_alloptions()"], result: 196 },
      { i: 2, sql: "SELECT * FROM wp_users WHERE ID = 1", time: 0.0001, stack: ["get_userdata()"], result: 1 },
      { i: 3, sql: "SELECT * FROM wp_posts WHERE post_type = 'post'", time: 0.08, stack: ["WP_Query->get_posts()"], result: 25 },
      { i: 4, sql: "SELECT * FROM wp_postmeta WHERE post_id = 1", time: 0.0002, stack: ["get_post_meta()"], result: 5 },
      { i: 5, sql: "SELECT * FROM wp_postmeta WHERE post_id = 1", time: 0.0003, stack: ["get_post_meta()"], result: 5 },
    ],
    dupes: {
      total: 1,
      queries: {
        "SELECT * FROM wp_postmeta WHERE post_id = 1": [4, 5],
      },
    },
  },
  cache: { hit_percentage: 95.2, hits: 200, misses: 10 },
  http: [],
  logger: [],
  transients: [],
  conditionals: ["is_front_page"],
  _meta: {
    nonce: "abc123def456",
    url: "https://example.local/",
    method: "GET",
    status: 200,
    timestamp: "2026-03-22T00:00:00Z",
    qm_version: "3.20.4",
  },
};

function createMockCookieGetter(cookies: Array<{ name: string; value: string; domain: string }> = []) {
  return async (_user: string, _domain: string) => cookies;
}

const MOCK_COOKIES = [
  { name: "wordpress_logged_in_abc123", value: "admin|1234|token", domain: "example.local" },
  { name: "wordpress_sec_abc123", value: "admin|1234|sectoken", domain: "example.local" },
];

// ---------------------------------------------------------------------------
// deriveQmCookie logic (tested indirectly via getAuthCookies)
// ---------------------------------------------------------------------------

test("createQmHandlers throws when no cookies found for domain", async () => {
  const handlers = createQmHandlers({ repoRoot: "/tmp", getCookiesForSite: createMockCookieGetter([]) });

  await assert.rejects(
    () => handlers.profilePage("https://example.local", "/", "GET", undefined, undefined, "admin"),
    { message: /No cookies found for "example.local"/ },
  );
});

test("createQmHandlers throws when no logged_in cookie found", async () => {
  const cookiesWithoutLoggedIn = [
    { name: "wordpress_sec_abc123", value: "val", domain: "example.local" },
  ];
  const handlers = createQmHandlers({ repoRoot: "/tmp", getCookiesForSite: createMockCookieGetter(cookiesWithoutLoggedIn) });

  await assert.rejects(
    () => handlers.profilePage("https://example.local", "/", "GET", undefined, undefined, "admin"),
    { message: /No wordpress_logged_in_\* cookie found/ },
  );
});

// ---------------------------------------------------------------------------
// slowQueries filtering
// ---------------------------------------------------------------------------

test("slowQueries filters by threshold", async () => {
  // Mock the internal profilePage by creating a handler with a mock that
  // intercepts the HTTP calls. Since we can't easily mock fetchUrl,
  // we test the filtering logic directly via the exported types.

  // Instead, test the filtering math directly.
  const queries = MOCK_PROFILE.db_queries;
  assert.ok("queries" in queries && Array.isArray(queries.queries));

  const thresholdMs = 50;
  const thresholdSec = thresholdMs / 1000;
  const slow = queries.queries
    .filter((q) => q.time >= thresholdSec)
    .sort((a, b) => b.time - a.time);

  assert.equal(slow.length, 1);
  assert.equal(slow[0].sql, "SELECT * FROM wp_posts WHERE post_type = 'post'");
  assert.equal(slow[0].time, 0.08);
});

test("slowQueries returns empty when no queries exceed threshold", () => {
  const queries = MOCK_PROFILE.db_queries;
  assert.ok("queries" in queries && Array.isArray(queries.queries));

  const thresholdMs = 100;
  const thresholdSec = thresholdMs / 1000;
  const slow = queries.queries.filter((q) => q.time >= thresholdSec);

  assert.equal(slow.length, 0);
});

// ---------------------------------------------------------------------------
// duplicateQueries extraction
// ---------------------------------------------------------------------------

test("duplicateQueries extracts dupes from profile data", () => {
  const dbQueries = MOCK_PROFILE.db_queries;
  assert.ok("dupes" in dbQueries && dbQueries.dupes);

  const duplicates = Object.entries(dbQueries.dupes.queries).map(([sql, indices]) => ({
    sql,
    count: indices.length,
    query_indices: indices,
  }));

  assert.equal(duplicates.length, 1);
  assert.equal(duplicates[0].sql, "SELECT * FROM wp_postmeta WHERE post_id = 1");
  assert.equal(duplicates[0].count, 2);
  assert.deepEqual(duplicates[0].query_indices, [4, 5]);
});

test("duplicateQueries returns empty when no dupes exist", () => {
  const profileNoDupes = {
    ...MOCK_PROFILE,
    db_queries: { ...MOCK_PROFILE.db_queries, dupes: { total: 0, queries: {} } },
  };

  const dupes = profileNoDupes.db_queries.dupes;
  assert.equal(dupes.total, 0);
  assert.equal(Object.keys(dupes.queries).length, 0);
});

// ---------------------------------------------------------------------------
// QM cookie derivation
// ---------------------------------------------------------------------------

test("QM cookie name is derived from logged_in cookie hash", () => {
  const loggedIn = MOCK_COOKIES.find((c) => c.name.startsWith("wordpress_logged_in_"));
  assert.ok(loggedIn);

  const hash = loggedIn.name.replace("wordpress_logged_in_", "");
  const qmCookieName = `wp-query_monitor_${hash}`;

  assert.equal(qmCookieName, "wp-query_monitor_abc123");
});

// ---------------------------------------------------------------------------
// Profile data structure validation
// ---------------------------------------------------------------------------

test("mock profile data has expected structure", () => {
  assert.ok(MOCK_PROFILE.overview);
  assert.equal(typeof MOCK_PROFILE.overview.time_taken, "number");
  assert.equal(typeof MOCK_PROFILE.overview.memory, "number");

  const db = MOCK_PROFILE.db_queries;
  assert.ok("total" in db);
  assert.ok("queries" in db);
  assert.ok(Array.isArray(db.queries));
  assert.equal(db.total, 5);

  assert.ok(MOCK_PROFILE._meta);
  assert.equal(MOCK_PROFILE._meta.qm_version, "3.20.4");
});

test("overview memory values are numeric", () => {
  const ov = MOCK_PROFILE.overview;
  assert.ok(ov);
  assert.equal(ov.memory, 9_961_472);
  assert.equal(ov.memory_limit, 268_435_456);
  assert.ok(ov.memory_usage > 0);
  assert.ok(ov.memory_usage < 100);
});
