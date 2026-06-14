function createRouter() {
  const routes = [];

  return {
    addRoute: (method, pathPattern, handler) => {
      routes.push({ method, pathPattern, handler });
    },
    dispatch: (req, res) => {
      const urlParts = req.url.split('?')[0].split('/');

      for (const route of routes) {
        if (req.method !== route.method) continue;
        
        const patternParts = route.pathPattern.split('/');

        if (patternParts.length === urlParts.length) {
          let match = true;
          const params = {};
          
          for (let i = 0; i < patternParts.length; i++) {
            if (patternParts[i].startsWith(':')) {
              const paramName = patternParts[i].slice(1);
              params[paramName] = urlParts[i];
            } else if (patternParts[i] !== urlParts[i]) {
              match = false;
              break;
            }
          }

          if (match) {
            req.params = params;
            return route.handler(req, res);
          }
        }
      }

      // 404 otherwise
      res.writeHead(404);
      res.end();
    }
  };
}

module.exports = { createRouter };
