'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { createStore } = require('../../src/store/store');

test('create, get, list, update, and remove round-trip a todo', () => {
  const store = createStore();
  const created = store.create({ title: 'Write tests' });

  assert.equal(typeof created.id, 'string');
  assert.equal(created.title, 'Write tests');
  assert.equal(created.done, false);
  assert.equal(created.createdAt, new Date(created.createdAt).toISOString());

  const fetched = store.get(created.id);
  assert.deepEqual(fetched, created);

  assert.deepEqual(store.list(), [created]);

  const updated = store.update(created.id, { title: 'Ship tests', done: true });
  assert.deepEqual(updated, {
    ...created,
    title: 'Ship tests',
    done: true,
  });

  assert.deepEqual(store.get(created.id), updated);
  assert.equal(store.remove(created.id), true);
  assert.equal(store.get(created.id), null);
  assert.deepEqual(store.list(), []);
  assert.equal(store.remove(created.id), false);
});

test('get returns null for a missing todo id', () => {
  const store = createStore();

  assert.equal(store.get('missing-id'), null);
});

test('create assigns unique string ids', () => {
  const store = createStore();
  const first = store.create({ title: 'First' });
  const second = store.create({ title: 'Second', done: true });

  assert.notEqual(first.id, second.id);
  assert.equal(typeof first.id, 'string');
  assert.equal(typeof second.id, 'string');
  assert.equal(second.done, true);
});
