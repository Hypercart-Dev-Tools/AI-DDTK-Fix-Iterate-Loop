class Router {
  constructor() {
    this.routes = [];
  }

  add(method, path, handler) {
    // Convert path with :id to regex
    // e.g. /todos/:id -> /^\/todos\/([^/]+)$/
    const paramNames = [];
    const regexPath = path.replace(/:([^/]+)/g, (match, paramName) => {
      paramNames.push(paramName);
      return '([^/]+)';
    });

    this.routes.push({
      method: method.toUpperCase(),
      regex: new RegExp(`^${regexPath}$`),
      paramNames,
      handler
    });
  }

  get(path, handler) { this.add('GET', path, handler); }
  post(path, handler) { this.add('POST', path, handler); }
  put(path, handler) { this.add('PUT', path, handler); }
  delete(path, handler) { this.add('DELETE', path, handler); }

  handle(req, res) {
    // Need to parse URL to ignore query string
    const url = new URL(req.url, `http://${req.headers?.host || 'localhost'}`);
    const pathname = url.pathname;
    
    for (const route of this.routes) {
      if (req.method.toUpperCase() === route.method) {
        const match = pathname.match(route.regex);
        if (match) {
          req.params = {};
          for (let i = 0; i < route.paramNames.length; i++) {
            req.params[route.paramNames[i]] = match[i + 1];
          }
          return route.handler(req, res);
        }
      }
    }

    // 404 for unmatched routes
    res.statusCode = 404;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ error: 'Not Found' }));
  }
}

module.exports = { Router };
