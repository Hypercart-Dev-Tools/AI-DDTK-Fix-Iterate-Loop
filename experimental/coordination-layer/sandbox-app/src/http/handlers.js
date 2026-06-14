function createHandlers(store) {
  return {
    list: (req, res) => {
      try {
        let query = {};
        if (req.url && req.url.includes('?')) {
          const qs = req.url.split('?')[1];
          const params = new URLSearchParams(qs);
          if (params.has('done')) query.done = params.get('done') === 'true';
          if (params.has('sort')) query.sort = params.get('sort');
        }
        
        const todos = store.list(query);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(todos));
      } catch (e) {
        res.writeHead(500);
        res.end();
      }
    },
    
    get: (req, res) => {
      const id = req.params.id;
      const todo = store.get(id);
      if (todo) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(todo));
      } else {
        res.writeHead(404);
        res.end();
      }
    },
    
    create: async (req, res) => {
      try {
        const body = await readJson(req);
        const todo = store.create(body);
        res.writeHead(201, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(todo));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message || 'Invalid input' }));
      }
    },
    
    update: async (req, res) => {
      try {
        const id = req.params.id;
        const body = await readJson(req);
        const todo = store.update(id, body);
        
        if (todo) {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(todo));
        } else {
          res.writeHead(404);
          res.end();
        }
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message || 'Invalid input' }));
      }
    },
    
    remove: (req, res) => {
      const id = req.params.id;
      const success = store.remove(id);
      if (success) {
        res.writeHead(200);
        res.end();
      } else {
        res.writeHead(404);
        res.end();
      }
    }
  };
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      if (!body) {
         resolve({});
         return;
      }
      try {
        resolve(JSON.parse(body));
      } catch (e) {
        reject(new Error('Invalid JSON'));
      }
    });
    req.on('error', reject);
  });
}

module.exports = { createHandlers };
