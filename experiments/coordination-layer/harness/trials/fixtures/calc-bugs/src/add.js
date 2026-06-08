'use strict';
// SEEDED BUG: subtracts instead of adding. The agent's task is to fix this so
// test/add.test.js passes.
module.exports = (a, b) => a - b;
