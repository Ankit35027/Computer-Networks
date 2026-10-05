/**
 * COMPUTER NETWORKS COURSE PROJECT - PHASE 1
 * MACHINE ROLE: Mac 4 (Backend Server B + Test Client)
 * SERVICE: Backend Server B
 * PORT: 3002 (Listens on 0.0.0.0 for LAN access)
 */

const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 3002;
const HOST = '0.0.0.0'; // MUST bind to 0.0.0.0 so Mac 2 (nginx) can reach it across the LAN
const BACKEND_ID = 'B';
const CACHE_ETAG = '"backend-b-v1.0"';
const CACHE_MAX_AGE = 60; // 60 seconds for Task F

const startTime = new Date();

function getLanIp() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return '127.0.0.1';
}

const server = http.createServer((req, res) => {
  const remoteIp = req.socket.remoteAddress;
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] [Backend B] ${req.method} ${req.url} from ${remoteIp}`);

  // Mandatory Header across all endpoints for Task C & Task D
  res.setHeader('X-Backend', BACKEND_ID);
  res.setHeader('Server', 'NodeJS-Backend-B/Mac4');

  // URL routing
  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = parsedUrl.pathname;

  // 1. GET / - Basic confirmation service is running (Task C)
  if (pathname === '/' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      message: 'Backend Server B is running and accessible',
      backend: BACKEND_ID,
      role: 'Application Server Instance B (Mac 4)',
      host_ip: getLanIp(),
      port: Number(PORT),
      timestamp: timestamp
    }, null, 2));
  }

  // 2. GET /api/status - Status endpoint with backend identifier (Task C)
  if (pathname === '/api/status' && req.method === 'GET') {
    const uptimeSeconds = Math.floor((new Date() - startTime) / 1000);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      backend: BACKEND_ID,
      status: 'ok',
      uptime_seconds: uptimeSeconds,
      client_ip: remoteIp,
      hostname: os.hostname(),
      timestamp: timestamp
    }, null, 2));
  }

  // 3. GET /api/cached - Demonstrating HTTP Caching, Cache-Control & 304 Not Modified (Task F)
  if (pathname === '/api/cached' && req.method === 'GET') {
    res.setHeader('Cache-Control', `public, max-age=${CACHE_MAX_AGE}`);
    res.setHeader('ETag', CACHE_ETAG);

    // Conditional GET handling via If-None-Match header
    const ifNoneMatch = req.headers['if-none-match'];
    if (ifNoneMatch && (ifNoneMatch === CACHE_ETAG || ifNoneMatch === '*')) {
      console.log(`[${timestamp}] [Backend B] Cache hit! Client sent ETag ${ifNoneMatch} -> Returning 304 Not Modified`);
      res.writeHead(304); // 304 Not Modified has no body
      return res.end();
    }

    // Full fresh response if no cache match
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      backend: BACKEND_ID,
      status: 'cached_resource',
      etag: CACHE_ETAG,
      max_age_seconds: CACHE_MAX_AGE,
      content: 'This response demonstrates HTTP caching headers (Cache-Control & ETag).',
      fetched_at: timestamp
    }, null, 2));
  }

  // 4. GET /health - Simple healthcheck for load balancer monitoring
  if (pathname === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      status: 'healthy',
      backend: BACKEND_ID
    }));
  }

  // Default: 404 Not Found
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    error: 'Not Found',
    backend: BACKEND_ID,
    requested_path: pathname
  }, null, 2));
});

server.listen(PORT, HOST, () => {
  console.log('====================================================');
  console.log(`  BACKEND SERVER B (Mac 4) RUNNING`);
  console.log(`  Listening on: http://${HOST}:${PORT}`);
  console.log(`  LAN Access  : http://${getLanIp()}:${PORT}`);
  console.log(`  Identifier  : Backend ${BACKEND_ID} (X-Backend: ${BACKEND_ID})`);
  console.log('====================================================');
  console.log('Available Endpoints:');
  console.log('  GET /           - Basic confirmation');
  console.log('  GET /api/status - Status JSON with { backend: "B", status: "ok" }');
  console.log('  GET /api/cached - HTTP Caching demo (Cache-Control + ETag + 304)');
  console.log('  GET /health     - Health check');
  console.log('====================================================');
});
