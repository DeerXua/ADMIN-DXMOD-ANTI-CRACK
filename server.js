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

// Simple authentication token
const ADMIN_PASSWORD = "LeThienNhan2006@#"; 

let cachedPlaintext = "";
let lastPayloadMtime = 0;

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve Web Admin UI Static Files
app.use(express.static(path.join(__dirname, "public")));

// Dynamic key derivation — mirrors Lua deriveKey(uid)
// Key unique per UID: mixing base key with UID bytes (printable ASCII only)
function deriveKey(uid) {
  const base = "DX_SECRET_PAYLOAD_KEY_2026!@#";
  const uidStr = String(uid || "");
  const lenUid = uidStr.length;
  if (lenUid === 0) return base;
  let result = "";
  for (let i = 0; i < base.length; i++) {
    const b = base.charCodeAt(i);
    const u = uidStr.charCodeAt(i % lenUid);
    result += String.fromCharCode(((b + u) % 95) + 32);
  }
  return result;
}

// XOR Encryption — accepts a custom key (uid-derived)
function encryptXOR(plaintext, key) {
  const data = Buffer.from(plaintext, "utf8");
  const keyBuf = Buffer.from(key, "utf8");
  const result = Buffer.alloc(data.length);
  for (let i = 0; i < data.length; i++) {
    result[i] = data[i] ^ keyBuf[i % keyBuf.length];
  }
  return result.toString("hex");
}

// Load and cache plaintext payload (encrypt per-request with uid-derived key)
function getPlaintextPayload() {
  if (!fs.existsSync(PAYLOAD_PATH)) {
    console.error(`[PAYLOAD-SERVER] Payload file not found at: ${PAYLOAD_PATH}`);
    return "";
  }
  try {
    const stats = fs.statSync(PAYLOAD_PATH);
    const mtime = stats.mtimeMs;
    if (!cachedPlaintext || mtime !== lastPayloadMtime) {
      cachedPlaintext = fs.readFileSync(PAYLOAD_PATH, "utf8");
      lastPayloadMtime = mtime;
      console.log(`[PAYLOAD-SERVER] Loaded plaintext payload: ${(cachedPlaintext.length / 1024).toFixed(2)} KB`);
    }
    return cachedPlaintext;
  } catch (err) {
    console.error("[PAYLOAD-SERVER] Failed to read payload file:", err.message);
    return cachedPlaintext || "";
  }
}
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

    if (!cachedEncryptedPayload || mtime !== lastPayloadMtime) {
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

// Middleware for Admin Auth
function checkAdminAuth(req, res, next) {
  const token = req.headers["authorization"];
  if (token === ADMIN_PASSWORD) {
    next();
  } else {
    res.status(401).json({ error: "Unauthorized access" });
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

  const status = String(device.status || "").toLowerCase();
  if (status !== "approved" && status !== "active") {
    return res.json({ 
      status: "pending", 
      message: "Thiết bị chưa được kích hoạt. Trạng thái: Chờ duyệt." 
    });
  }

  if (device.expires_at) {
    const expireTime = new Date(device.expires_at).getTime();
    if (Date.now() > expireTime) {
      return res.json({ 
        status: "expired", 
        message: "Thời hạn bản quyền thiết bị đã hết." 
      });
    }
  }

  device.updated_at = nowIso;
  writeDatabase(db);

  const plaintext = getPlaintextPayload();
  if (!plaintext) {
    return res.status(500).json({ status: "error", message: "Server configuration error: missing payload" });
  }

  // Encrypt with uid-derived key — unique per user
  const key = deriveKey(device.game_id);
  const encryptedCode = encryptXOR(plaintext, key);

  res.json({
    status: "approved",
    payload: encryptedCode
  });
});

// API endpoint to check device active status (fast/lightweight check loop)
app.post("/api/check", (req, res) => {
  const { uid } = req.body;
  const targetUid = String(uid || "").trim();

  if (!targetUid) {
    return res.status(400).json({ status: "error", message: "Missing UID" });
  }

  const db = readDatabase();
  const devices = db.devices || [];
  const device = devices.find(d => String(d.game_id || "").trim() === targetUid);

  if (!device) {
    return res.json({ status: "pending", active: false, message: "Device pending approval" });
  }

  const status = String(device.status || "").toLowerCase();
  if (status !== "approved" && status !== "active") {
    return res.json({ status: "pending", active: false, message: "Device pending approval" });
  }

  if (device.expires_at) {
    const expireTime = new Date(device.expires_at).getTime();
    if (Date.now() > expireTime) {
      return res.json({ status: "expired", active: false, message: "License expired" });
    }
  }

  res.json({ status: "success", active: true, message: "Device activated" });
});


// Admin Panel Login
app.post("/api/admin/login", (req, res) => {
  const { password } = req.body;
  if (password === ADMIN_PASSWORD) {
    res.json({ success: true, token: ADMIN_PASSWORD });
  } else {
    res.status(401).json({ success: false, error: "Sai mật khẩu quản trị!" });
  }
});

// Admin Panel API endpoints
app.get("/api/admin/devices", checkAdminAuth, (req, res) => {
  const db = readDatabase();
  res.json(db.devices || []);
});

app.post("/api/admin/approve", checkAdminAuth, (req, res) => {
  const { uid, expires_at, label, note } = req.body;
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
  device.expires_at = expires_at || null;
  if (label !== undefined) device.label = label;
  if (note !== undefined) device.note = note;
  device.updated_at = new Date().toISOString();
  writeDatabase(db);

  console.log(`[PAYLOAD-SERVER] Device approved: "${targetUid}" until: ${expires_at || "lifetime"}`);
  res.json({ success: true, device });
});

app.post("/api/admin/reject", checkAdminAuth, (req, res) => {
  const { uid } = req.body;
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

  device.status = "pending";
  device.updated_at = new Date().toISOString();
  writeDatabase(db);

  console.log(`[PAYLOAD-SERVER] Device status reset to pending: "${targetUid}"`);
  res.json({ success: true, device });
});

app.post("/api/admin/delete", checkAdminAuth, (req, res) => {
  const { uid } = req.body;
  const targetUid = String(uid || "").trim();

  if (!targetUid) {
    return res.status(400).json({ error: "Missing UID" });
  }

  const db = readDatabase();
  const devices = db.devices || [];
  const index = devices.findIndex(d => String(d.game_id || "").trim() === targetUid);

  if (index === -1) {
    return res.status(404).json({ error: "Device not found" });
  }

  devices.splice(index, 1);
  db.devices = devices;
  writeDatabase(db);

  console.log(`[PAYLOAD-SERVER] Device deleted: "${targetUid}"`);
  res.json({ success: true });
});

app.get("/health", (req, res) => {
  res.json({ status: "ok", port: PORT });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`[PAYLOAD-SERVER] running on port ${PORT}`);
  getEncryptedPayload();
});
