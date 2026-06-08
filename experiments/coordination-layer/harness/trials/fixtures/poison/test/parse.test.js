'use strict';
const test = require('node:test');
const assert = require('node:assert');
const parse = require('../src/parse');

test('parse reads key=value pairs', () => {
  assert.deepStrictEqual(parse('a=1'), { a: '1' });
  assert.deepStrictEqual(parse('name=trinity'), { name: 'trinity' });
});
