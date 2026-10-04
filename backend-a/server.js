const express = require("express");
const crypto = require("crypto");
const os = require("os");

const app = express();
const PORT = 3001;
const HOST = "0.0.0.0";
const BACKEND_ID = "A";

// ─── Middleware: add X-Backend to every response ─────────────────────────────
app.use((req, res, next) => {
    res.set("X-Backend", BACKEND_ID);
    res.set("X-Powered-By", "Backend-A/1.0");
    next();
});

// ─── GET / ────────────────────────────────────────────────────────────────────
// Static-ish response → demonstrate Cache-Control max-age + ETag (304 demo)
app.get("/", (req, res) => {
    const body = {
        backend: BACKEND_ID,
        message: "Backend A is running",
        status: "ok",
        host: os.hostname(),
        port: PORT
    };

    // ETag based on content — used for conditional-request (304 Not Modified) demo
    const etag = `"${crypto.createHash("md5").update(JSON.stringify(body)).digest("hex")}"`;

    res.set("Cache-Control", "max-age=60");
    res.set("ETag", etag);

    // If client sends If-None-Match matching the ETag → 304 Not Modified
    if (req.headers["if-none-match"] === etag) {
        return res.status(304).end();
    }

    res.json(body);
});

// ─── GET /api/status ──────────────────────────────────────────────────────────
// Dynamic (timestamp changes each call) → demonstrate no-store / always fresh
app.get("/api/status", (req, res) => {
    res.set("Cache-Control", "no-store");

    res.json({
        status: "ok",
        backend: BACKEND_ID,
        server_port: PORT,
        uptime_seconds: Math.floor(process.uptime()),
        timestamp: new Date().toISOString(),
        host: os.hostname(),
        port: PORT,
        pid: process.pid
    });
});

// ─── GET /api/info ────────────────────────────────────────────────────────────
// Machine/network info useful during the viva demo
app.get("/api/info", (req, res) => {
    res.set("Cache-Control", "max-age=120");

    // Collect non-loopback IPv4 addresses
    const interfaces = os.networkInterfaces();
    const addresses = [];
    for (const [iface, addrs] of Object.entries(interfaces)) {
        for (const addr of addrs) {
            if (addr.family === "IPv4" && !addr.internal) {
                addresses.push({ interface: iface, address: addr.address });
            }
        }
    }

    res.json({
        backend: BACKEND_ID,
        hostname: os.hostname(),
        platform: os.platform(),
        node_version: process.version,
        lan_addresses: addresses,
        listen_port: PORT
    });
});

// ─── GET /health ──────────────────────────────────────────────────────────────
// Lightweight health-check for nginx upstream probes
app.get("/health", (req, res) => {
    res.set("Cache-Control", "no-store");
    res.status(200).json({ status: "healthy", backend: BACKEND_ID });
});

// ─── Start ────────────────────────────────────────────────────────────────────
app.listen(PORT, HOST, () => {
    console.log(`✅  Backend ${BACKEND_ID} listening on http://${HOST}:${PORT}`);
    console.log(`   Endpoints:`);
    console.log(`     GET /            → JSON + Cache-Control: max-age=60 + ETag`);
    console.log(`     GET /api/status  → JSON + Cache-Control: no-store (dynamic)`);
    console.log(`     GET /api/info    → LAN addresses and machine info`);
    console.log(`     GET /health      → nginx upstream health check`);
});
