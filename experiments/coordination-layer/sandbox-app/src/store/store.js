const { validateTodo } = require('./validate');

function cloneTodo(todo) {
  return { ...todo };
}

function createStore() {
  const todos = new Map();
  let nextId = 1;

  function create(input) {
    const validated = validateTodo(input);
    const todo = {
      id: String(nextId++),
      title: validated.title,
      done: validated.done === true,
      createdAt: new Date().toISOString(),
    };

    todos.set(todo.id, todo);

    return cloneTodo(todo);
  }

  function get(id) {
    const todo = todos.get(id);

    return todo ? cloneTodo(todo) : null;
  }

  function list() {
    return Array.from(todos.values(), cloneTodo);
  }

  function update(id, patch) {
    const current = todos.get(id);

    if (!current) {
      return null;
    }

    const validated = validateTodo({
      title: Object.prototype.hasOwnProperty.call(patch, 'title') ? patch.title : current.title,
      done: Object.prototype.hasOwnProperty.call(patch, 'done') ? patch.done : current.done,
    });

    const updated = {
      ...current,
      ...validated,
      id: current.id,
      createdAt: current.createdAt,
    };

    todos.set(id, updated);

    return cloneTodo(updated);
  }

  function remove(id) {
    return todos.delete(id);
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
