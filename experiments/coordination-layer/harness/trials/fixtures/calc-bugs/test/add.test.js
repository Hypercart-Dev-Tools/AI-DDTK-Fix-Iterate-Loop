'use strict';
const test = require('node:test');
const assert = require('node:assert');
const add = require('../src/add');

test('add sums its arguments', () => {
  assert.strictEqual(add(2, 3), 5);
  assert.strictEqual(add(-1, 1), 0);
});
