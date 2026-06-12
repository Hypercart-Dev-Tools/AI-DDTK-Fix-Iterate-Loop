const test = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const { createServer } = require('../../src/http/server.js');

test('Server bootstrap', async (t) => {
  const server = createServer();
  
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;

  await t.test('GET /health returns 200 {status: "ok"}', async () => {
    const res = await new Promise((resolve) => {
      http.get(`http://localhost:${port}/health`, resolve);
    });
    
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.headers['content-type'], 'application/json');
    
    let body = '';
    for await (const chunk of res) {
      body += chunk;
    }
    
    assert.deepStrictEqual(JSON.parse(body), { status: 'ok' });
  });

  server.close();
});
