
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const path = require('path');

const app = express();
const port = 8080;
const apiPort = 3000;

// Proxy API requests to the backend server
app.use('/api', createProxyMiddleware({
  target: `http://localhost:${apiPort}`,
  changeOrigin: true,
}));

// Serve static files from the 'dist' directory
app.use(express.static(path.join(__dirname, 'dist')));

// For all other GET requests, send back index.html to support SPA routing
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'dist/index.html'));
});

app.listen(port, () => {
  console.log(`
[INFO] Frontend server with API proxy is running.
[INFO] Please access the application at: http://localhost:${port}
  `);
});
