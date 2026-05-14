function createRouter() {
  const routes = [];

  function add(method, path, handler) {
    const isParamRoute = path.includes(':id');
    let regex;
    if (isParamRoute) {
      regex = new RegExp('^' + path.replace(':id', '([^/]+)') + '$');
    } else {
      regex = new RegExp('^' + path + '$');
    }
    routes.push({ method, path, regex, handler, isParamRoute });
  }

  function handle(req, res) {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const pathname = url.pathname;
    
    for (const route of routes) {
      if (route.method === req.method) {
        const match = pathname.match(route.regex);
        if (match) {
          req.params = {};
          if (route.isParamRoute) {
            req.params.id = match[1];
          }
          return route.handler(req, res);
        }
      }
    }
    
    // Unmatched
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }

  return {
    get: (path, handler) => add('GET', path, handler),
    post: (path, handler) => add('POST', path, handler),
    put: (path, handler) => add('PUT', path, handler),
    delete: (path, handler) => add('DELETE', path, handler),
    handle
  };
}

module.exports = { createRouter };