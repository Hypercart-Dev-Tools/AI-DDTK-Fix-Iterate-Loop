'use strict';
const test = require('node:test');
const assert = require('node:assert');
const mul = require('../src/mul');

test('mul multiplies its arguments', () => {
  assert.strictEqual(mul(2, 3), 6);
  assert.strictEqual(mul(4, 0), 0);
});
