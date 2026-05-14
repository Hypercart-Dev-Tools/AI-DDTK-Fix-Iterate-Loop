const { test } = require('node:test');
const assert = require('node:assert');
const { createRouter } = require('../../src/http/router.js');

test('Router dispatches simple routes and parameterized routes', () => {
  const router = createRouter();
  
  let handled = null;
  
  router.get('/todos', (req, res) => {
    handled = { route: '/todos', params: req.params };
    res.end();
  });
  
  router.get('/todos/:id', (req, res) => {
    handled = { route: '/todos/:id', params: req.params };
    res.end();
  });

  // Mock req and res
  function mockRes() {
    return {
      writeHead: () => {},
      end: () => {}
    };
  }

  // match GET /todos
  router.handle({ method: 'GET', url: '/todos', headers: { host: 'localhost' } }, mockRes());
  assert.deepStrictEqual(handled, { route: '/todos', params: {} });
  
  // match GET /todos/123
  handled = null;
  router.handle({ method: 'GET', url: '/todos/123', headers: { host: 'localhost' } }, mockRes());
  assert.deepStrictEqual(handled, { route: '/todos/:id', params: { id: '123' } });
});

test('Router returns 404 for unmatched routes', () => {
  const router = createRouter();
  let status = null;
  let body = null;
  
  const res = {
    writeHead: (s) => status = s,
    end: (b) => body = b
  };
  
  router.handle({ method: 'GET', url: '/unknown', headers: { host: 'localhost' } }, res);
  assert.strictEqual(status, 404);
  assert.deepStrictEqual(JSON.parse(body), { error: 'Not found' });
});