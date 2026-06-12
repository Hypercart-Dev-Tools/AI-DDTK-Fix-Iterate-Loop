function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key);
}

function validateTodo(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new TypeError('todo input must be an object');
  }

  if (typeof input.title !== 'string' || input.title.trim() === '') {
    throw new TypeError('title is required');
  }

  if (hasOwn(input, 'done') && typeof input.done !== 'boolean') {
    throw new TypeError('done must be a boolean when provided');
  }

  const normalized = {
    title: input.title,
  };

  if (hasOwn(input, 'done')) {
    normalized.done = input.done;
  }

  return normalized;
}

module.exports = {
  validateTodo,
};
