'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { applyQuery } = require('../../src/store/query');

function buildTodo(id, done, createdAt) {
  return {
    id,
    title: `Todo ${id}`,
    done,
    createdAt,
  };
}

test('returns all todos when no query is provided', () => {
  const todos = [
    buildTodo('1', false, '2026-01-01T00:00:00.000Z'),
    buildTodo('2', true, '2026-01-02T00:00:00.000Z'),
  ];

  assert.deepEqual(applyQuery(todos), todos);
});

test('filters todos by done status', () => {
  const todos = [
    buildTodo('1', false, '2026-01-01T00:00:00.000Z'),
    buildTodo('2', true, '2026-01-02T00:00:00.000Z'),
    buildTodo('3', false, '2026-01-03T00:00:00.000Z'),
  ];

  assert.deepEqual(applyQuery(todos, { done: false }), [todos[0], todos[2]]);
  assert.deepEqual(applyQuery(todos, { done: true }), [todos[1]]);
});

test('sorts todos by createdAt ascending', () => {
  const todos = [
    buildTodo('3', false, '2026-01-03T00:00:00.000Z'),
    buildTodo('1', false, '2026-01-01T00:00:00.000Z'),
    buildTodo('2', true, '2026-01-02T00:00:00.000Z'),
  ];

  assert.deepEqual(applyQuery(todos, { sort: 'asc' }).map((todo) => todo.id), [
    '1',
    '2',
    '3',
  ]);
});

test('sorts todos by createdAt descending', () => {
  const todos = [
    buildTodo('1', false, '2026-01-01T00:00:00.000Z'),
    buildTodo('2', true, '2026-01-02T00:00:00.000Z'),
    buildTodo('3', false, '2026-01-03T00:00:00.000Z'),
  ];

  assert.deepEqual(applyQuery(todos, { sort: 'desc' }).map((todo) => todo.id), [
    '3',
    '2',
    '1',
  ]);
});

test('can combine done filtering and ascending sort', () => {
  const todos = [
    buildTodo('3', false, '2026-01-03T00:00:00.000Z'),
    buildTodo('1', false, '2026-01-01T00:00:00.000Z'),
    buildTodo('2', true, '2026-01-02T00:00:00.000Z'),
  ];

  assert.deepEqual(
    applyQuery(todos, { done: false, sort: 'asc' }).map((todo) => todo.id),
    ['1', '3']
  );
});
