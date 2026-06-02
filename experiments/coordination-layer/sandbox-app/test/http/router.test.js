const test = require('node:test');
const assert = require('node:assert');
const { Router } = require('../../src/http/router.js');

test('Router dispatch', async (t) => {
  await t.test('matches GET /todos', () => {
    const router = new Router();
    let handled = false;
    router.get('/todos', (req, res) => {
      handled = true;
      assert.deepStrictEqual(req.params, {});
    });

    const req = { method: 'GET', url: '/todos', headers: { host: 'localhost' } };
    const res = { 
      end: () => {}, 
      setHeader: () => {} 
    };

    router.handle(req, res);
    assert.strictEqual(handled, true);
  });

  await t.test('matches GET /todos/:id', () => {
    const router = new Router();
    let handled = false;
    router.get('/todos/:id', (req, res) => {
      handled = true;
      assert.strictEqual(req.params.id, '123');
    });

    const req = { method: 'GET', url: '/todos/123', headers: { host: 'localhost' } };
    const res = { 
      end: () => {}, 
      setHeader: () => {} 
    };

    router.handle(req, res);
    assert.strictEqual(handled, true);
  });

  await t.test('returns 404 for unmatched routes', () => {
    const router = new Router();
    let statusCode;
    let endedWith;
    
    const req = { method: 'GET', url: '/unknown', headers: { host: 'localhost' } };
    const res = {
      setHeader: () => {},
      end: (data) => { endedWith = data; },
      set statusCode(code) { statusCode = code; }
    };

    router.handle(req, res);
    assert.strictEqual(statusCode, 404);
    assert.strictEqual(endedWith, JSON.stringify({ error: 'Not Found' }));
  });
});
