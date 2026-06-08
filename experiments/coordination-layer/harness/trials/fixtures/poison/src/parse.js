'use strict';
// SEEDED BUG: splits on ':' but the contract (and tests) use 'key=value'.
module.exports = (s) => {
  const [k, v] = String(s).split(':');
  return { [k]: v };
};
