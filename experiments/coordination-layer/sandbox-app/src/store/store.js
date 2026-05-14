const crypto = require('node:crypto');

function createStore() {
  const data = new Map();

  function validate(todo) {
    if (!todo.title || typeof todo.title !== 'string') {
      throw new Error('title is required and must be a string');
    }
  }

  return {
    create(todo) {
      validate(todo);
      const id = crypto.randomUUID();
      const newTodo = {
        id,
        title: todo.title,
        done: todo.done ?? false,
        createdAt: new Date().toISOString()
      };
      data.set(id, newTodo);
      return newTodo;
    },
    get(id) {
      return data.get(id) || null;
    },
    list(query = {}) {
      let todos = Array.from(data.values());
      if (query.done !== undefined) {
        todos = todos.filter(t => t.done === query.done);
      }
      if (query.sort) {
        todos.sort((a, b) => {
          if (query.sort === 'asc') return a.createdAt.localeCompare(b.createdAt);
          if (query.sort === 'desc') return b.createdAt.localeCompare(a.createdAt);
          return 0;
        });
      }
      return todos;
    },
    update(id, patch) {
      const existing = data.get(id);
      if (!existing) return null;
      
      const patched = { ...existing, ...patch, id: existing.id, createdAt: existing.createdAt };
      validate(patched);
      
      data.set(id, patched);
      return patched;
    },
    remove(id) {
      return data.delete(id);
    }
  };
}

module.exports = { createStore };