'use strict';

const { applyQuery } = require('./query');
const { validateTodo } = require('./validate');

function cloneTodo(todo) {
  return { ...todo };
}

function createStore() {
  const todos = new Map();
  let nextId = 1;

  function create(todo) {
    const normalized = validateTodo(todo);
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

    const normalized = validateTodo({
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
