'use strict';

function validateTodo(input) {
  if (!input || typeof input !== 'object') {
    throw new TypeError('todo must be an object');
  }

  if (typeof input.title !== 'string' || input.title.trim() === '') {
    throw new TypeError('title is required');
  }

  if (input.done !== undefined && typeof input.done !== 'boolean') {
    throw new TypeError('done must be a boolean');
  }

  return {
    title: input.title,
    done: input.done ?? false,
  };
}

module.exports = {
  validateTodo,
};
