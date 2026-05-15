const test = require('node:test');
const assert = require('node:assert');
const { createHandlers } = require('../../src/http/handlers.js');

class StubStore {
  constructor() {
    this.todos = new Map();
  }
  
  create(todo) {
    if (!todo.title) throw new Error('title required');
    const newTodo = { id: '1', title: todo.title, done: !!todo.done, createdAt: new Date().toISOString() };
    this.todos.set('1', newTodo);
    return newTodo;
  }
  get(id) {
    return this.todos.get(id) || null;
  }
  list(query) {
    let arr = Array.from(this.todos.values());
    if (query && query.done !== undefined) {
      arr = arr.filter(t => t.done === query.done);
    }
    return arr;
  }
  update(id, patch) {
    if (!this.todos.has(id)) return null;
    if (patch.title === '') throw new Error('title cannot be empty');
    const existing = this.todos.get(id);
    const updated = { ...existing, ...patch };
    this.todos.set(id, updated);
    return updated;
  }
  remove(id) {
    return this.todos.delete(id);
  }
}

function mockReq(options, body) {
  let callbacks = {};
  return {
    ...options,
    on(event, cb) { callbacks[event] = cb; },
    emit(event, data) { if (callbacks[event]) callbacks[event](data); },
    sendBody() {
      if (body) {
        this.emit('data', Buffer.from(body));
      }
      this.emit('end');
    }
  };
}

function mockRes() {
  const res = {
    statusCode: 200,
    headers: {},
    body: '',
    setHeader(k, v) { this.headers[k] = v; },
    end(data) { if (data) this.body = data; },
    json() { return JSON.parse(this.body); }
  };
  return res;
}

test('Handlers', async (t) => {
  const store = new StubStore();
  const handlers = createHandlers(store);

  await t.test('POST /todos - success', async () => {
    const req = mockReq({ method: 'POST', url: '/todos' }, JSON.stringify({ title: 'test' }));
    const res = mockRes();
    
    handlers.createTodo(req, res);
    req.sendBody();
    
    await new Promise(setImmediate);
    
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.json().title, 'test');
  });

  await t.test('POST /todos - error', async () => {
    const req = mockReq({ method: 'POST', url: '/todos' }, JSON.stringify({ title: '' }));
    const res = mockRes();
    
    handlers.createTodo(req, res);
    req.sendBody();
    
    await new Promise(setImmediate);
    
    assert.strictEqual(res.statusCode, 400);
  });

  await t.test('GET /todos - lists todos', async () => {
    const req = mockReq({ method: 'GET', url: '/todos' });
    const res = mockRes();
    
    await handlers.listTodos(req, res);
    
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(Array.isArray(res.json()), true);
  });

  await t.test('GET /todos/:id - found', async () => {
    const req = mockReq({ method: 'GET', url: '/todos/1', params: { id: '1' } });
    const res = mockRes();
    
    await handlers.getTodo(req, res);
    
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.json().id, '1');
  });

  await t.test('GET /todos/:id - not found', async () => {
    const req = mockReq({ method: 'GET', url: '/todos/999', params: { id: '999' } });
    const res = mockRes();
    
    await handlers.getTodo(req, res);
    
    assert.strictEqual(res.statusCode, 404);
  });
  
  await t.test('PUT /todos/:id - success', async () => {
    const req = mockReq({ method: 'PUT', url: '/todos/1', params: { id: '1' } }, JSON.stringify({ done: true }));
    const res = mockRes();
    
    handlers.updateTodo(req, res);
    req.sendBody();
    
    await new Promise(setImmediate);
    
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.json().done, true);
  });

  await t.test('DELETE /todos/:id - success', async () => {
    const req = mockReq({ method: 'DELETE', url: '/todos/1', params: { id: '1' } });
    const res = mockRes();
    
    await handlers.deleteTodo(req, res);
    
    assert.strictEqual(res.statusCode, 204);
  });
});