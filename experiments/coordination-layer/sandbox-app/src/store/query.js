function applyQuery(todos, query) {
  if (!query) return todos;

  let result = [...todos];

  if (typeof query.done === 'boolean') {
    result = result.filter(todo => todo.done === query.done);
  }

  if (query.sort === 'asc' || query.sort === 'desc') {
    result.sort((a, b) => {
      const timeA = new Date(a.createdAt).getTime();
      const timeB = new Date(b.createdAt).getTime();
      if (query.sort === 'asc') {
        return timeA - timeB;
      } else {
        return timeB - timeA;
      }
    });
  }

  return result;
}

module.exports = { applyQuery };
