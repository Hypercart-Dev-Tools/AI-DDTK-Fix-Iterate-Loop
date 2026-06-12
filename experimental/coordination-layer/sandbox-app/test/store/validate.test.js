const test = require('node:test');
const assert = require('node:assert/strict');

const { validateTodo } = require('../../src/store/validate');

test('validateTodo rejects missing or empty titles', () => {
  assert.throws(() => validateTodo({}), /title is required/);
  assert.throws(() => validateTodo({ title: '' }), /title is required/);
  assert.throws(() => validateTodo({ title: '   ' }), /title is required/);
});

test('validateTodo rejects non-boolean done values', () => {
  assert.throws(
    () => validateTodo({ title: 'Write tests', done: 'yes' }),
    /done must be a boolean/,
  );
});

test('validateTodo accepts valid todo input', () => {
  assert.deepEqual(validateTodo({ title: 'Write tests' }), {
    title: 'Write tests',
  });

  assert.deepEqual(validateTodo({ title: 'Ship code', done: false }), {
    title: 'Ship code',
    done: false,
  });
});
