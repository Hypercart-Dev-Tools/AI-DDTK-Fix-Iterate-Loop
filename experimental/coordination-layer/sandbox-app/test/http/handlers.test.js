const test = require('node:test');
const assert = require('node:assert');
const { createHandlers } = require('../../src/http/handlers.js');

test('handlers - list', (t) => {
  const store = { list: () => [{ id: '1', title: 'test', done: false }] };
  const handlers = createHandlers(store);
  
  const req = { url: '/todos' };
  let status, data;
  const res = {
    writeHead: (code) => { status = code; },
    end: (str) => { data = str; }
  };
  
  handlers.list(req, res);
  assert.strictEqual(status, 200);
  assert.strictEqual(data, JSON.stringify([{ id: '1', title: 'test', done: false }]));
});

test('handlers - get (found)', (t) => {
  const store = { get: (id) => id === '1' ? { id: '1', title: 'test', done: false } : null };
  const handlers = createHandlers(store);
  
  const req = { params: { id: '1' } };
  let status, data;
  const res = {
    writeHead: (code) => { status = code; },
    end: (str) => { data = str; }
  };
  
  handlers.get(req, res);
  assert.strictEqual(status, 200);
  assert.strictEqual(data, JSON.stringify({ id: '1', title: 'test', done: false }));
});

test('handlers - get (not found)', (t) => {
  const store = { get: (id) => null };
  const handlers = createHandlers(store);
  
  const req = { params: { id: '2' } };
  let status;
  const res = {
    writeHead: (code) => { status = code; },
    end: () => {}
  };
  
  handlers.get(req, res);
  assert.strictEqual(status, 404);
});

// Helper for simulating async req body
function createReqWithBody(bodyObj) {
  let listeners = {};
  return {
    on: (evt, cb) => { listeners[evt] = cb; },
    emit: function() {
      if (listeners['data']) {
        listeners['data'](JSON.stringify(bodyObj));
      }
      if (listeners['end']) {
        listeners['end']();
      }
    }
  };
}

test('handlers - create (valid)', async (t) => {
  const store = { 
    create: (todo) => ({ id: 'new', ...todo, done: false }) 
  };
  const handlers = createHandlers(store);
  
  const req = createReqWithBody({ title: 'new todo' });
  let status, data;
  const res = {
    writeHead: (code) => { status = code; },
    end: (str) => { data = str; }
  };
  
  const promise = handlers.create(req, res);
  req.emit();
  await promise;
  
  assert.strictEqual(status, 201);
  assert.strictEqual(data, JSON.stringify({ id: 'new', title: 'new todo', done: false }));
});

test('handlers - create (invalid)', async (t) => {
  const store = { 
    create: (todo) => { throw new Error('Bad input'); } 
  };
  const handlers = createHandlers(store);
  
  const req = createReqWithBody({});
  let status;
  const res = {
    writeHead: (code) => { status = code; },
    end: () => {}
  };
  
  const promise = handlers.create(req, res);
  req.emit();
  await promise;
  
  assert.strictEqual(status, 400);
});

test('handlers - update', async (t) => {
  const store = { 
    update: (id, patch) => id === '1' ? { id: '1', title: patch.title || 'old', done: patch.done || false } : null
  };
  const handlers = createHandlers(store);
  
  const req = createReqWithBody({ done: true });
  req.params = { id: '1' };
  let status, data;
  const res = {
    writeHead: (code) => { status = code; },
    end: (str) => { data = str; }
  };
  
  const promise = handlers.update(req, res);
  req.emit();
  await promise;
  
  assert.strictEqual(status, 200);
  assert.strictEqual(data, JSON.stringify({ id: '1', title: 'old', done: true }));
});

test('handlers - remove (found)', (t) => {
  const store = { remove: (id) => id === '1' };
  const handlers = createHandlers(store);
  
  const req = { params: { id: '1' } };
  let status;
  const res = {
    writeHead: (code) => { status = code; },
    end: () => {}
  };
  
  handlers.remove(req, res);
  assert.strictEqual(status, 200);
});

test('handlers - remove (not found)', (t) => {
  const store = { remove: (id) => false };
  const handlers = createHandlers(store);
  
  const req = { params: { id: '2' } };
  let status;
  const res = {
    writeHead: (code) => { status = code; },
    end: () => {}
  };
  
  handlers.remove(req, res);
  assert.strictEqual(status, 404);
});
