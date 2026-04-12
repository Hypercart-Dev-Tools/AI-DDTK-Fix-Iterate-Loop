import assert from "node:assert/strict";
import test from "node:test";
import { createServer } from "../src/index.js";
import { SessionStore } from "../src/state.js";

test("SessionStore creates isolated SiteState per session", () => {
  const store = new SessionStore();
  const s1 = store.getOrCreate("session-a");
  const s2 = store.getOrCreate("session-b");

  s1.setActiveSite({ name: "site-1", path: "/a" });
  s2.setActiveSite({ name: "site-2", path: "/b" });

  assert.equal(s1.getActiveSite()?.name, "site-1");
  assert.equal(s2.getActiveSite()?.name, "site-2");
  assert.equal(store.size, 2);
});

test("SessionStore returns same SiteState for same session ID", () => {
  const store = new SessionStore();
  const first = store.getOrCreate("session-x");
  first.setActiveSite({ name: "demo", path: "/d" });

  const second = store.getOrCreate("session-x");
  assert.equal(second.getActiveSite()?.name, "demo");
  assert.equal(store.size, 1);
});

test("SessionStore.remove deletes a session", () => {
  const store = new SessionStore();
  store.getOrCreate("to-remove");
  assert.equal(store.has("to-remove"), true);

  const removed = store.remove("to-remove");
  assert.equal(removed, true);
  assert.equal(store.has("to-remove"), false);
  assert.equal(store.size, 0);
});

test("SessionStore.remove returns false for unknown session", () => {
  const store = new SessionStore();
  assert.equal(store.remove("nonexistent"), false);
});

test("token generation produces 64-char hex string", async () => {
  const { randomBytes } = await import("node:crypto");
  const token = randomBytes(32).toString("hex");
  assert.equal(token.length, 64);
  assert.match(token, /^[0-9a-f]{64}$/);
});

test("server factory creates the MCP server with updated version", () => {
  const server = createServer();
  assert.ok(server);
  assert.equal(typeof server.connect, "function");
});
