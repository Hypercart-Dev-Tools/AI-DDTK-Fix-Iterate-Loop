'use strict';

function normalizeTodo(input) {
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

function applyQuery(todos, query) {
  let items = todos.slice();

  if (query && typeof query.done === 'boolean') {
    items = items.filter((todo) => todo.done === query.done);
  }

  if (query && (query.sort === 'asc' || query.sort === 'desc')) {
    items.sort((left, right) => {
      if (left.createdAt === right.createdAt) {
        return 0;
      }

      return query.sort === 'asc'
        ? left.createdAt.localeCompare(right.createdAt)
        : right.createdAt.localeCompare(left.createdAt);
    });
  }

  return items;
}

function cloneTodo(todo) {
  return { ...todo };
}

function createStore() {
  const todos = new Map();
  let nextId = 1;

  function create(todo) {
    const normalized = normalizeTodo(todo);
    const record = {
      id: String(nextId++),
      title: normalized.title,
      done: normalized.done,
      createdAt: new Date().toISOString(),
    };

    todos.set(record.id, record);

    return cloneTodo(record);
  }

  function get(id) {
    const todo = todos.get(String(id));
    return todo ? cloneTodo(todo) : null;
  }

  function list(query) {
    return applyQuery(Array.from(todos.values()), query).map(cloneTodo);
  }

  function update(id, patch) {
    const key = String(id);
    const existing = todos.get(key);

    if (!existing) {
      return null;
    }

    const normalized = normalizeTodo({
      title: patch && patch.title !== undefined ? patch.title : existing.title,
      done: patch && patch.done !== undefined ? patch.done : existing.done,
    });

    const updated = {
      id: existing.id,
      createdAt: existing.createdAt,
      title: normalized.title,
      done: normalized.done,
    };

    todos.set(key, updated);

    return cloneTodo(updated);
  }

  function remove(id) {
    return todos.delete(String(id));
  }

  return {
    create,
    get,
    list,
    update,
    remove,
  };
}

module.exports = {
  createStore,
};
