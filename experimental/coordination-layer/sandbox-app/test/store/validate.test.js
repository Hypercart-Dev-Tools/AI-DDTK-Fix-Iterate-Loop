'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { validateTodo } = require('../../src/store/validate');

test('rejects a missing todo object', () => {
  assert.throws(() => validateTodo(), /todo must be an object/);
});

test('rejects a missing title', () => {
  assert.throws(() => validateTodo({}), /title is required/);
});

test('rejects an empty title', () => {
  assert.throws(() => validateTodo({ title: '   ' }), /title is required/);
});

test('rejects a non-boolean done value', () => {
  assert.throws(
    () => validateTodo({ title: 'Ship it', done: 'yes' }),
    /done must be a boolean/
  );
});

test('accepts a valid title and defaults done to false', () => {
  assert.deepEqual(validateTodo({ title: 'Ship it' }), {
    title: 'Ship it',
    done: false,
  });
});

test('accepts a valid done boolean', () => {
  assert.deepEqual(validateTodo({ title: 'Ship it', done: true }), {
    title: 'Ship it',
    done: true,
  });
});
