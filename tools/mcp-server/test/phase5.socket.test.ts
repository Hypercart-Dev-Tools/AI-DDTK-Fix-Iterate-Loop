import assert from "node:assert/strict";
import http from "node:http";
import test from "node:test";
import { createHttpHandler } from "../src/index.js";

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

function parseSseMessages(text: string): unknown[] {
  const messages: unknown[] = [];

  for (const block of text.split("\n\n")) {
    const dataLine = block.split("\n").find((line) => line.startsWith("data: "));

    if (!dataLine) {
      continue;
    }

    try {
      messages.push(JSON.parse(dataLine.slice(6)));
    } catch {
      // Skip non-JSON data lines.
    }
  }

  return messages;
}

test("createHttpHandler rejects requests without bearer token (real handler)", async () => {
  const { port, close } = await startTestServer("secret-test-token");

  try {
    const res1 = await fetch(`http://127.0.0.1:${port}/mcp`, { method: "POST" });
    assert.equal(res1.status, 401);
    assert.match(await res1.text(), /Unauthorized/);

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

test("createHttpHandler accepts POST to /mcp and creates a session (MCP initialize)", async () => {
  const token = "test-token-session";
  const { port, close } = await startTestServer(token);

  try {
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
    const sessionId = res.headers.get("mcp-session-id");
    assert.ok(sessionId);
    assert.ok(sessionId.length > 0);

    const messages = parseSseMessages(await res.text());
    assert.ok(messages.length > 0);

    const body = messages[0] as { jsonrpc: string; id: number; result: { serverInfo: { name: string } } };
    assert.equal(body.jsonrpc, "2.0");
    assert.equal(body.id, 1);
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
    assert.equal(sessionStore.size, 0);

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
    await res.text();

    const sessionId = res.headers.get("mcp-session-id");
    assert.ok(sessionId);
    assert.equal(sessionStore.size, 1);
    assert.equal(sessionStore.has(sessionId), true);
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
