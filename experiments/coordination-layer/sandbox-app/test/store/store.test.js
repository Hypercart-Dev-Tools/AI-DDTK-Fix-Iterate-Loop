const { test } = require('node:test');
const assert = require('node:assert');
const { createStore } = require('../../src/store/store.js');

test('Store CRUD operations', () => {
  const store = createStore();
  
  // get missing
  assert.strictEqual(store.get('missing-id'), null);
  
  // create
  const todo = store.create({ title: 'Buy milk' });
  assert.strictEqual(typeof todo.id, 'string');
  assert.strictEqual(todo.title, 'Buy milk');
  assert.strictEqual(todo.done, false);
  assert.strictEqual(typeof todo.createdAt, 'string');
  
  // get
  const fetched = store.get(todo.id);
  assert.deepStrictEqual(fetched, todo);
  
  // list
  const list = store.list();
  assert.strictEqual(list.length, 1);
  assert.deepStrictEqual(list[0], todo);
  
  // update
  const updated = store.update(todo.id, { done: true });
  assert.strictEqual(updated.done, true);
  assert.strictEqual(store.get(todo.id).done, true);
  
  // update missing
  assert.strictEqual(store.update('missing-id', { done: true }), null);
  
  // remove
  assert.strictEqual(store.remove(todo.id), true);
  assert.strictEqual(store.remove(todo.id), false); // already removed
  assert.strictEqual(store.get(todo.id), null);
});