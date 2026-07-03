import express from "express";
import cors from "cors";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = process.env.PORT || 5002;
const XOR_KEY = "DX_SECRET_PAYLOAD_KEY_2026!@#";
const DB_PATH = path.join(__dirname, "data.json");
const PAYLOAD_PATH = path.join(__dirname, "protected_payload.lua");

// Cache for the encrypted payload
let cachedEncryptedPayload = "";
let lastPayloadMtime = 0;

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// XOR Encryption Helper
function encryptXOR(plaintext) {
  const data = Buffer.from(plaintext, "utf8");
  const key = Buffer.from(XOR_KEY, "utf8");
  const result = Buffer.alloc(data.length);
  for (let i = 0; i < data.length; i++) {
    result[i] = data[i] ^ key[i % key.length];
  }
  return result.toString("hex");
}

// Read database
function readDatabase() {
  if (!fs.existsSync(DB_PATH)) {
    return { nextId: 1, devices: [] };
  }
  try {
    const raw = fs.readFileSync(DB_PATH, "utf8").trim();
    if (!raw) return { nextId: 1, devices: [] };
    return JSON.parse(raw);
  } catch (err) {
    console.error("[PAYLOAD-SERVER] Failed to read database:", err.message);
    return { nextId: 1, devices: [] };
  }
}

// Write database atomically
function writeDatabase(db) {
  try {
    const tempPath = `${DB_PATH}.tmp`;
    fs.writeFileSync(tempPath, JSON.stringify(db, null, 2), "utf8");
    fs.renameSync(tempPath, DB_PATH);
  } catch (err) {
    console.error("[PAYLOAD-SERVER] Failed to write database:", err.message);
  }
}

// Load and encrypt payload
function getEncryptedPayload() {
  if (!fs.existsSync(PAYLOAD_PATH)) {
    console.error(`[PAYLOAD-SERVER] Payload file not found at: ${PAYLOAD_PATH}`);
    return "";
  }

  try {
    const stats = fs.statSync(PAYLOAD_PATH);
    const mtime = stats.mtimeMs;

    // Reload if file changed or cache empty
    if (!cachedEncryptedPayload || mtime !== lastPayloadMtime) {
      console.log("[PAYLOAD-SERVER] Reading and encrypting payload...");
      const code = fs.readFileSync(PAYLOAD_PATH, "utf8");
      cachedEncryptedPayload = encryptXOR(code);
      lastPayloadMtime = mtime;
      console.log(`[PAYLOAD-SERVER] Encrypted payload size: ${(cachedEncryptedPayload.length / 2 / 1024).toFixed(2)} KB`);
    }
    return cachedEncryptedPayload;
  } catch (err) {
    console.error("[PAYLOAD-SERVER] Failed to process payload file:", err.message);
    return cachedEncryptedPayload || "";
  }
}

// API endpoint to serve protected payload
app.post("/api/payload", (req, res) => {
  const { uid } = req.body;
  const targetUid = String(uid || "").trim();

  if (!targetUid) {
    return res.status(400).json({ status: "error", message: "Missing UID" });
  }

  const db = readDatabase();
  const devices = db.devices || [];
  let device = devices.find(d => String(d.game_id || "").trim() === targetUid);

  const nowIso = new Date().toISOString();

  if (!device) {
    // Auto register new device as pending
    const nextId = db.nextId || (devices.length > 0 ? Math.max(...devices.map(d => d.id || 0)) + 1 : 1);
    device = {
      id: nextId,
      game_id: targetUid,
      label: `Device ${targetUid}`,
      status: "pending",
      expires_at: null,
      note: "Auto registered from Client Loader",
      first_seen_at: nowIso,
      updated_at: nowIso
    };
    devices.push(device);
    db.nextId = nextId + 1;
    db.devices = devices;
    writeDatabase(db);
    console.log(`[PAYLOAD-SERVER] Registered new UID: "${targetUid}" (status: pending)`);
  }

  // Check license status
  const status = String(device.status || "").toLowerCase();
  if (status !== "approved" && status !== "active") {
    return res.json({ 
      status: "pending", 
      message: "Thiết bị chưa được kích hoạt. Trạng thái: Chờ duyệt." 
    });
  }

  // Check expiration
  if (device.expires_at) {
    const expireTime = new Date(device.expires_at).getTime();
    if (Date.now() > expireTime) {
      return res.json({ 
        status: "expired", 
        message: "Thời hạn bản quyền thiết bị đã hết." 
      });
    }
  }

  // Update last seen
  device.updated_at = nowIso;
  writeDatabase(db);

  const encryptedCode = getEncryptedPayload();
  if (!encryptedCode) {
    return res.status(500).json({ status: "error", message: "Server configuration error: missing payload" });
  }

  res.json({
    status: "approved",
    payload: encryptedCode
  });
});

// Admin Panel API endpoints for easy license management via simple commands
app.get("/api/admin/devices", (req, res) => {
  const db = readDatabase();
  res.json(db.devices || []);
});

app.post("/api/admin/approve", (req, res) => {
  const { uid, expires_at } = req.body;
  const targetUid = String(uid || "").trim();

  if (!targetUid) {
    return res.status(400).json({ error: "Missing UID" });
  }

  const db = readDatabase();
  const devices = db.devices || [];
  let device = devices.find(d => String(d.game_id || "").trim() === targetUid);

  if (!device) {
    return res.status(404).json({ error: "Device not found" });
  }

  device.status = "approved";
  device.expires_at = expires_at || null; // ISO string or null for lifetime
  device.updated_at = new Date().toISOString();
  writeDatabase(db);

  console.log(`[PAYLOAD-SERVER] Device approved: "${targetUid}" until: ${expires_at || "lifetime"}`);
  res.json({ success: true, device });
});

app.get("/health", (req, res) => {
  res.json({ status: "ok", port: PORT });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`[PAYLOAD-SERVER] running on port ${PORT}`);
  // Pre-load payload on start
  getEncryptedPayload();
});
