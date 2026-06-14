const test = require('node:test');
const assert = require('node:assert');
const { createRouter } = require('../../src/http/router.js');

test('matches GET /todos', (t) => {
  const router = createRouter();
  let handled = false;
  
  router.addRoute('GET', '/todos', (req, res) => {
    handled = true;
    res.writeHead(200);
    res.end();
  });

  const req = { method: 'GET', url: '/todos' };
  const res = { 
    writeHead: (code) => { assert.strictEqual(code, 200); },
    end: () => {} 
  };

  router.dispatch(req, res);
  assert.strictEqual(handled, true);
});

test('matches GET /todos/:id', (t) => {
  const router = createRouter();
  let handledId = null;
  
  router.addRoute('GET', '/todos/:id', (req, res) => {
    handledId = req.params.id;
    res.writeHead(200);
    res.end();
  });

  const req = { method: 'GET', url: '/todos/123' };
  const res = { 
    writeHead: (code) => { assert.strictEqual(code, 200); },
    end: () => {} 
  };

  router.dispatch(req, res);
  assert.strictEqual(handledId, '123');
});

test('404 otherwise', (t) => {
  const router = createRouter();
  
  router.addRoute('GET', '/todos', (req, res) => {
    assert.fail('Should not match');
  });

  const req = { method: 'POST', url: '/todos' };
  let status = null;
  const res = { 
    writeHead: (code) => { status = code; },
    end: () => {} 
  };

  router.dispatch(req, res);
  assert.strictEqual(status, 404);
});
