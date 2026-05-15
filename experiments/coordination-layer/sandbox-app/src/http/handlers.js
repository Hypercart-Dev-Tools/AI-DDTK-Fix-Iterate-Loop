function createHandlers(store) {
  return {
    async listTodos(req, res) {
      try {
        const url = new URL(req.url, `http://${req.headers?.host || 'localhost'}`);
        const query = {};
        if (url.searchParams.has('done')) {
          query.done = url.searchParams.get('done') === 'true';
        }
        if (url.searchParams.has('sort')) {
          query.sort = url.searchParams.get('sort');
        }
        
        const todos = await store.list(query);
        res.statusCode = 200;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(todos));
      } catch (err) {
        res.statusCode = 500;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ error: err.message }));
      }
    },

    async getTodo(req, res) {
      try {
        const id = req.params.id;
        const todo = await store.get(id);
        if (!todo) {
          res.statusCode = 404;
          res.setHeader('Content-Type', 'application/json');
          return res.end(JSON.stringify({ error: 'Not Found' }));
        }
        
        res.statusCode = 200;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(todo));
      } catch (err) {
        res.statusCode = 500;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ error: err.message }));
      }
    },

    async createTodo(req, res) {
      let body = '';
      req.on('data', chunk => { body += chunk.toString(); });
      req.on('end', async () => {
        try {
          const data = JSON.parse(body);
          const todo = await store.create(data);
          res.statusCode = 201;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify(todo));
        } catch (err) {
          res.statusCode = 400;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ error: err.message }));
        }
      });
    },

    async updateTodo(req, res) {
      let body = '';
      req.on('data', chunk => { body += chunk.toString(); });
      req.on('end', async () => {
        try {
          const id = req.params.id;
          const data = JSON.parse(body);
          const todo = await store.update(id, data);
          if (!todo) {
            res.statusCode = 404;
            res.setHeader('Content-Type', 'application/json');
            return res.end(JSON.stringify({ error: 'Not Found' }));
          }
          res.statusCode = 200;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify(todo));
        } catch (err) {
          res.statusCode = 400;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ error: err.message }));
        }
      });
    },

    async deleteTodo(req, res) {
      try {
        const id = req.params.id;
        const removed = await store.remove(id);
        if (!removed) {
          res.statusCode = 404;
          res.setHeader('Content-Type', 'application/json');
          return res.end(JSON.stringify({ error: 'Not Found' }));
        }
        res.statusCode = 204;
        res.end();
      } catch (err) {
        res.statusCode = 500;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ error: err.message }));
      }
    }
  };
}

function registerHandlers(router, store) {
  const handlers = createHandlers(store);
  router.get('/todos', handlers.listTodos);
  router.get('/todos/:id', handlers.getTodo);
  router.post('/todos', handlers.createTodo);
  router.put('/todos/:id', handlers.updateTodo);
  router.delete('/todos/:id', handlers.deleteTodo);
}

module.exports = { createHandlers, registerHandlers };
