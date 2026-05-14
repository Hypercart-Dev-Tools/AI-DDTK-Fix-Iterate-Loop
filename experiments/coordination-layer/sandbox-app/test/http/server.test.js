const { test } = require('node:test');
const assert = require('node:assert');
const { server } = require('../../src/http/server.js');
const http = require('node:http');

test('GET /health returns 200 {status: "ok"}', (t, done) => {
  server.listen(0, () => {
    const port = server.address().port;
    http.get(`http://localhost:${port}/health`, (res) => {
      assert.strictEqual(res.statusCode, 200);
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        assert.deepStrictEqual(JSON.parse(data), { status: 'ok' });
        server.close(done);
      });
    });
  });
});

test('Other routes return 404', (t, done) => {
  server.listen(0, () => {
    const port = server.address().port;
    http.get(`http://localhost:${port}/unknown`, (res) => {
      assert.strictEqual(res.statusCode, 404);
      server.close(done);
    });
  });
});