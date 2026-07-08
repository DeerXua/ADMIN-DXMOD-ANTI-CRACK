const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;

const server = http.createServer((req, res) => {
    // Enable CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }

    if ((req.url === '/' || req.url === '/index.html') && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>Android Web Server</title>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body {
                        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                        background: radial-gradient(circle, #1a1a2e 0%, #16213e 100%);
                        color: #fff;
                        margin: 0;
                        padding: 0;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        height: 100vh;
                    }
                    .card {
                        background: rgba(255, 255, 255, 0.05);
                        backdrop-filter: blur(10px);
                        border-radius: 15px;
                        padding: 30px;
                        box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
                        border: 1px solid rgba(255, 255, 255, 0.1);
                        text-align: center;
                        max-width: 400px;
                        width: 90%;
                    }
                    h1 {
                        color: #00f2fe;
                        margin-bottom: 10px;
                        font-size: 2rem;
                    }
                    p {
                        color: #e0e0e0;
                        font-size: 1rem;
                        line-height: 1.5;
                    }
                    .status {
                        display: inline-block;
                        background: #00ff87;
                        color: #000;
                        padding: 5px 15px;
                        border-radius: 20px;
                        font-weight: bold;
                        font-size: 0.85rem;
                        margin-top: 15px;
                        box-shadow: 0 0 15px #00ff87;
                    }
                    .info {
                        margin-top: 20px;
                        font-size: 0.8rem;
                        color: #888;
                        border-top: 1px solid rgba(255, 255, 255, 0.1);
                        padding-top: 15px;
                    }
                </style>
            </head>
            <body>
                <div class="card">
                    <h1>Android Server</h1>
                    <p>Chúc mừng! Server Node.js của bạn đang chạy cực kỳ mượt mà trên chiếc <strong>Samsung A13</strong>.</p>
                    <div class="status">ACTIVE</div>
                    <div class="info">
                        Chạy bằng: Node.js \${process.version}<br>
                        Thời gian hoạt động: \${parseInt(process.uptime())} giây<br>
                        Nền tảng: \${process.platform} (\${process.arch})
                    </div>
                </div>
            </body>
            </html>
        `);
    } else if (req.url === '/api/info' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: "running",
            device: "Samsung Galaxy A13",
            uptime: process.uptime(),
            platform: process.platform,
            arch: process.arch,
            memory: process.memoryUsage(),
            nodeVersion: process.version
        }));
    } else if (req.url === '/api/load-script' && req.method === 'POST') {
        const filePath = path.join(__dirname, 'protected_payload.lua');
        fs.readFile(filePath, 'utf8', (err, data) => {
            if (err) {
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: "Failed to read script file" }));
                return;
            }
            res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
            res.end(data);
        });
    } else if (req.url === '/api/load-payload' && req.method === 'GET') {
        const filePath = path.join(__dirname, 'protected_payload.lua');
        fs.readFile(filePath, 'utf8', (err, data) => {
            if (err) {
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: "Failed to read payload" }));
                return;
            }
            res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
            res.end(data);
        });
    } else if (req.url === '/api/payload/status' && req.method === 'GET') {
        const filePath = path.join(__dirname, 'protected_payload.lua');
        fs.access(filePath, fs.constants.F_OK, (err) => {
            if (err) {
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    available: false,
                    file: 'protected_payload.lua',
                    error: 'File not found'
                }));
                return;
            }
            fs.stat(filePath, (statErr, stats) => {
                if (statErr) {
                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ available: false, file: 'protected_payload.lua', error: 'Stat failed' }));
                    return;
                }
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    available: true,
                    file: 'protected_payload.lua',
                    size: stats.size,
                    modified: stats.mtime
                }));
            });
        });
    } else if (req.url === '/api/plannt/features' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            features: [
                "StrongestSquadFeature",
                "FlyingThunderGodFeature",
                "NineTailsFormFeature",
                "NinjutsuManager",
                "WaterMoveOnSurfaceFeature",
                "NTSpaceCheckInFeature",
                "PVESpawnFeature"
            ],
            class: "PlanNTPlayerCharacter",
            parent: "BRPlayerCharacterBase"
        }));
    } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
    }
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT}`);
});
