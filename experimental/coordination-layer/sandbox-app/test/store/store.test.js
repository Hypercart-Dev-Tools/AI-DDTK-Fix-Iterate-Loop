const test = require('node:test');
const assert = require('node:assert/strict');

const { createStore } = require('../../src/store/store');

test('createStore supports CRUD round-trips for todos', () => {
  const store = createStore();

  const created = store.create({ title: 'Write tests' });

  assert.equal(typeof created.id, 'string');
  assert.equal(created.title, 'Write tests');
  assert.equal(created.done, false);
  assert.match(created.createdAt, /^\d{4}-\d{2}-\d{2}T/);

  const fetched = store.get(created.id);
  assert.deepEqual(fetched, created);

  const listed = store.list();
  assert.deepEqual(listed, [created]);

  const updated = store.update(created.id, { done: true, title: 'Ship B1' });
  assert.deepEqual(updated, {
    ...created,
    title: 'Ship B1',
    done: true,
  });

  assert.deepEqual(store.get(created.id), updated);
  assert.equal(store.remove(created.id), true);
  assert.equal(store.get(created.id), null);
  assert.deepEqual(store.list(), []);
  assert.equal(store.remove(created.id), false);
});

test('get returns null for a missing id', () => {
  const store = createStore();

  assert.equal(store.get('missing-id'), null);
});
