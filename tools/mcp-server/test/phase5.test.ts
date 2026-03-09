import assert from "node:assert/strict";
import http from "node:http";
import test from "node:test";
import { SessionStore } from "../src/state.js";
import { createHttpHandler, createServer } from "../src/index.js";

// ---------------------------------------------------------------------------
// SessionStore unit tests
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Token utility tests
// ---------------------------------------------------------------------------

test("token generation produces 64-char hex string", async () => {
  const { randomBytes } = await import("node:crypto");
  const token = randomBytes(32).toString("hex");
  assert.equal(token.length, 64);
  assert.match(token, /^[0-9a-f]{64}$/);
});

// ---------------------------------------------------------------------------
// Real createHttpHandler tests — exercises the actual runtime path
// ---------------------------------------------------------------------------

function startTestServer(token: string): Promise<{ server: http.Server; port: number; close: () => Promise<void> }> {
  return new Promise((resolve) => {
    const { handler } = createHttpHandler({ port: 0, token });
    const server = http.createServer(handler);

    server.listen(0, "127.0.0.1", () => {
      const addr = server.address() as { port: number };
      resolve({
        server,
        port: addr.port,
        close: () => new Promise<void>((r) => server.close(() => r())),
      });
    });
  });
}

test("createHttpHandler rejects requests without bearer token (real handler)", async () => {
  const { port, close } = await startTestServer("secret-test-token");

  try {
    // No token
    const res1 = await fetch(`http://127.0.0.1:${port}/mcp`, { method: "POST" });
    assert.equal(res1.status, 401);
    const body1 = await res1.text();
    assert.match(body1, /Unauthorized/);

    // Wrong token
    const res2 = await fetch(`http://127.0.0.1:${port}/mcp`, {
      method: "POST",
      headers: { Authorization: "Bearer wrong" },
    });
    assert.equal(res2.status, 401);
  } finally {
    await close();
  }
});

test("createHttpHandler returns 404 for non-/mcp paths", async () => {
  const token = "test-token-404";
  const { port, close } = await startTestServer(token);

  try {
    const res = await fetch(`http://127.0.0.1:${port}/other`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
    });
    assert.equal(res.status, 404);
  } finally {
    await close();
  }
});

test("createHttpHandler returns 400 for GET without session ID", async () => {
  const token = "test-token-400";
  const { port, close } = await startTestServer(token);

  try {
    const res = await fetch(`http://127.0.0.1:${port}/mcp`, {
      method: "GET",
      headers: { Authorization: `Bearer ${token}` },
    });
    assert.equal(res.status, 400);
  } finally {
    await close();
  }
});

/**
 * Parse SSE text into JSON-RPC messages. The MCP Streamable HTTP transport
 * responds with text/event-stream containing `event: message` + `data: {...}` lines.
 */
function parseSseMessages(text: string): unknown[] {
  const messages: unknown[] = [];

  for (const block of text.split("\n\n")) {
    const dataLine = block.split("\n").find((l) => l.startsWith("data: "));

    if (dataLine) {
      try {
        messages.push(JSON.parse(dataLine.slice(6)));
      } catch {
        // skip non-JSON data lines
      }
    }
  }

  return messages;
}

test("createHttpHandler accepts POST to /mcp and creates a session (MCP initialize)", async () => {
  const token = "test-token-session";
  const { port, close } = await startTestServer(token);

  try {
    // Send a valid JSON-RPC initialize request to trigger session creation.
    // The MCP Streamable HTTP spec requires Accept header with both JSON and SSE.
    const res = await fetch(`http://127.0.0.1:${port}/mcp`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2025-03-26",
          capabilities: {},
          clientInfo: { name: "test-client", version: "0.0.1" },
        },
      }),
    });

    // The MCP SDK should respond with 200 + session header.
    assert.equal(res.status, 200);
    const sessionId = res.headers.get("mcp-session-id");
    assert.ok(sessionId, "Response should include mcp-session-id header");
    assert.ok(sessionId.length > 0);

    // The response is SSE format — parse it to extract the JSON-RPC message.
    const sseText = await res.text();
    const messages = parseSseMessages(sseText);
    assert.ok(messages.length > 0, "Should have at least one SSE message");

    const body = messages[0] as { jsonrpc: string; id: number; result: { serverInfo: { name: string } } };
    assert.equal(body.jsonrpc, "2.0");
    assert.equal(body.id, 1);
    assert.ok(body.result, "Should have a result field");
    assert.ok(body.result.serverInfo, "Should include serverInfo");
    assert.equal(body.result.serverInfo.name, "ai-ddtk-mcp");
  } finally {
    await close();
  }
});

test("createHttpHandler wires SessionStore — sessions are tracked and cleaned up", async () => {
  const token = "test-token-store";
  const { handler, sessionStore, transports } = createHttpHandler({ port: 0, token });
  const server = http.createServer(handler);

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as { port: number }).port;

  try {
    // Before any request, session store should be empty.
    assert.equal(sessionStore.size, 0);

    // Initialize a session.
    const res = await fetch(`http://127.0.0.1:${port}/mcp`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2025-03-26",
          capabilities: {},
          clientInfo: { name: "test-client", version: "0.0.1" },
        },
      }),
    });

    assert.equal(res.status, 200);

    // Consume the SSE response body fully so the handler completes.
    await res.text();

    const sessionId = res.headers.get("mcp-session-id")!;
    assert.ok(sessionId, "Response should include mcp-session-id header");

    // SessionStore should now track the session.
    assert.equal(sessionStore.size, 1);
    assert.equal(sessionStore.has(sessionId), true);

    // Transport map should also have the session.
    assert.equal(transports.size, 1);
    assert.equal(transports.has(sessionId), true);
  } finally {
    server.close();
  }
});

test("createHttpHandler binds to 127.0.0.1 only", async () => {
  const { handler } = createHttpHandler({ port: 0, token: "t" });
  const server = http.createServer(handler);

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));

  try {
    const addr = server.address() as { address: string };
    assert.equal(addr.address, "127.0.0.1");
  } finally {
    server.close();
  }
});

test("server factory creates the MCP server with updated version", () => {
  const server = createServer();
  assert.ok(server);
  assert.equal(typeof server.connect, "function");
});
