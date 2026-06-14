const test = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const { startServer, stopServer } = require('../../src/http/server.js');

test('GET /health returns 200 {"status":"ok"}', async (t) => {
  const port = await startServer(0); // 0 lets OS pick available port
  
  const res = await new Promise((resolve) => {
    http.get(`http://localhost:${port}/health`, resolve);
  });
  
  assert.strictEqual(res.statusCode, 200);
  
  let data = '';
  for await (const chunk of res) {
    data += chunk;
  }
  
  assert.strictEqual(data, '{"status":"ok"}');
  
  await stopServer();
});
