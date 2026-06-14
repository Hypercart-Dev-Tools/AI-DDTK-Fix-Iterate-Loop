const http = require('node:http');

let server;

function startServer(port = 3000) {
  return new Promise((resolve) => {
    server = http.createServer((req, res) => {
      if (req.method === 'GET' && req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok' }));
      } else {
        res.writeHead(404);
        res.end();
      }
    });

    server.listen(port, () => {
      resolve(server.address().port);
    });
  });
}

function stopServer() {
  return new Promise((resolve) => {
    if (server) {
      server.close(() => resolve());
    } else {
      resolve();
    }
  });
}

module.exports = { startServer, stopServer };
