'use strict';

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

module.exports = {
  applyQuery,
};
