const http = require('node:http');

function createServer() {
  const server = http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/health') {
      res.statusCode = 200;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ status: 'ok' }));
      return;
    }
    
    res.statusCode = 404;
    res.end();
  });

  return server;
}

module.exports = { createServer };
