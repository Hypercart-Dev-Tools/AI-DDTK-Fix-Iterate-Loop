const test = require('node:test');
const assert = require('node:assert');
const { applyQuery } = require('../../src/store/query.js');

test('Query helpers', async (t) => {
  const todos = [
    { id: '1', title: 'Task 1', done: false, createdAt: '2023-01-01T10:00:00.000Z' },
    { id: '2', title: 'Task 2', done: true, createdAt: '2023-01-01T11:00:00.000Z' },
    { id: '3', title: 'Task 3', done: true, createdAt: '2023-01-01T09:00:00.000Z' }
  ];

  await t.test('No query returns all', () => {
    const result = applyQuery(todos);
    assert.strictEqual(result.length, 3);
  });

  await t.test('Filter by done=true', () => {
    const result = applyQuery(todos, { done: true });
    assert.strictEqual(result.length, 2);
    assert.strictEqual(result[0].id, '2');
    assert.strictEqual(result[1].id, '3');
  });

  await t.test('Filter by done=false', () => {
    const result = applyQuery(todos, { done: false });
    assert.strictEqual(result.length, 1);
    assert.strictEqual(result[0].id, '1');
  });

  await t.test('Sort by createdAt asc', () => {
    const result = applyQuery(todos, { sort: 'asc' });
    assert.strictEqual(result.length, 3);
    assert.strictEqual(result[0].id, '3'); // 09:00
    assert.strictEqual(result[1].id, '1'); // 10:00
    assert.strictEqual(result[2].id, '2'); // 11:00
  });

  await t.test('Sort by createdAt desc', () => {
    const result = applyQuery(todos, { sort: 'desc' });
    assert.strictEqual(result.length, 3);
    assert.strictEqual(result[0].id, '2'); // 11:00
    assert.strictEqual(result[1].id, '1'); // 10:00
    assert.strictEqual(result[2].id, '3'); // 09:00
  });

  await t.test('Filter and sort together', () => {
    const result = applyQuery(todos, { done: true, sort: 'desc' });
    assert.strictEqual(result.length, 2);
    assert.strictEqual(result[0].id, '2'); // 11:00
    assert.strictEqual(result[1].id, '3'); // 09:00
  });
});
