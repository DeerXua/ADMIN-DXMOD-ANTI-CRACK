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
const SESSIONS_PATH = path.join(__dirname, "sessions.json");
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

// Sessions DB helpers
function readSessions() {
  if (!fs.existsSync(SESSIONS_PATH)) return { sessions: [] };
  try {
    const raw = fs.readFileSync(SESSIONS_PATH, "utf8").trim();
    if (!raw) return { sessions: [] };
    return JSON.parse(raw);
  } catch { return { sessions: [] }; }
}

function writeSessions(data) {
  try {
    const tmp = `${SESSIONS_PATH}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(data, null, 2), "utf8");
    fs.renameSync(tmp, SESSIONS_PATH);
  } catch (err) {
    console.error("[PAYLOAD-SERVER] Failed to write sessions:", err.message);
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

// ── MATCH TRACKING ──────────────────────────────────────────────────────────

// Hàm dọn dẹp các session bị treo (không gửi ping trong 45s)
function cleanupSessions(sessData) {
  const now = Date.now();
  const TIMEOUT_MS = 45 * 1000; // 45 giây không có heartbeat
  let changed = false;

  (sessData.sessions || []).forEach(s => {
    if (s.status === "in_match") {
      const lastSeen = s.last_seen_at ? new Date(s.last_seen_at).getTime() : new Date(s.started_at).getTime();
      if (now - lastSeen > TIMEOUT_MS) {
        s.ended_at = new Date(lastSeen).toISOString();
        s.status = "ended";
        s.duration_sec = Math.max(0, Math.round((lastSeen - new Date(s.started_at).getTime()) / 1000));
        changed = true;
      }
    }
  });

  return changed;
}

// Client báo bắt đầu trận
app.post("/api/match/start", (req, res) => {
  const { uid, player_name, match_id } = req.body;
  const targetUid = String(uid || "").trim();
  if (!targetUid) return res.status(400).json({ error: "Missing UID" });

  // Chỉ cho phép UID đã approved
  const db = readDatabase();
  const device = (db.devices || []).find(d => String(d.game_id || "").trim() === targetUid);
  if (!device) return res.status(403).json({ error: "Device not found" });
  const st = String(device.status || "").toLowerCase();
  if (st !== "approved" && st !== "active") return res.status(403).json({ error: "Device not approved" });

  const nowIso = new Date().toISOString();
  const sessData = readSessions();
  const sessionId = `${targetUid}_${Date.now()}`;

  // 1. Tự động đóng bất kỳ session cũ nào của UID này vẫn đang "in_match"
  (sessData.sessions || []).forEach(s => {
    if (s.uid === targetUid && s.status === "in_match") {
      const lastSeen = s.last_seen_at ? new Date(s.last_seen_at).getTime() : new Date(s.started_at).getTime();
      s.ended_at = new Date(lastSeen).toISOString();
      s.status = "ended";
      s.duration_sec = Math.max(0, Math.round((lastSeen - new Date(s.started_at).getTime()) / 1000));
    }
  });

  // 2. Dọn dẹp chung các session quá hạn của người chơi khác
  cleanupSessions(sessData);

  // Cập nhật tên player vào device record
  if (player_name && player_name !== "UNKNOWN") {
    device.player_name = String(player_name).trim();
    device.updated_at = nowIso;
    writeDatabase(db);
  }

  sessData.sessions.push({
    id: sessionId,
    uid: targetUid,
    player_name: player_name || device.player_name || "Unknown",
    match_id: match_id || null,
    started_at: nowIso,
    last_seen_at: nowIso, // Khởi tạo mốc thấy lần cuối
    ended_at: null,
    duration_sec: null,
    status: "in_match"
  });

  // Giữ tối đa 500 sessions gần nhất
  if (sessData.sessions.length > 500) {
    sessData.sessions = sessData.sessions.slice(-500);
  }
  writeSessions(sessData);

  console.log(`[MATCH] START  uid="${targetUid}" name="${player_name}" match="${match_id}"`);
  res.json({ success: true, session_id: sessionId });
});

// Client gửi ping duy trì trận (heartbeat)
app.post("/api/match/ping", (req, res) => {
  const { uid, session_id } = req.body;
  const targetUid = String(uid || "").trim();
  if (!targetUid) return res.status(400).json({ error: "Missing UID" });

  const sessData = readSessions();
  let session;
  if (session_id) {
    session = sessData.sessions.find(s => s.id === session_id && s.uid === targetUid);
  }
  if (!session) {
    const matches = sessData.sessions.filter(s => s.uid === targetUid && s.status === "in_match");
    session = matches[matches.length - 1];
  }

  if (session) {
    session.last_seen_at = new Date().toISOString();
    writeSessions(sessData);
    res.json({ success: true });
  } else {
    res.status(404).json({ error: "Session not found" });
  }
});

// Client báo kết thúc trận
app.post("/api/match/end", (req, res) => {
  const { uid, session_id } = req.body;
  const targetUid = String(uid || "").trim();
  if (!targetUid) return res.status(400).json({ error: "Missing UID" });

  const nowIso = new Date().toISOString();
  const sessData = readSessions();

  // Tìm session đang mở của UID này
  let session;
  if (session_id) {
    session = sessData.sessions.find(s => s.id === session_id && s.uid === targetUid);
  }
  if (!session) {
    // Fallback: lấy session in_match gần nhất của UID
    const matches = sessData.sessions.filter(s => s.uid === targetUid && s.status === "in_match");
    session = matches[matches.length - 1];
  }

  if (session) {
    session.ended_at = nowIso;
    session.last_seen_at = nowIso;
    session.status = "ended";
    if (session.started_at) {
      session.duration_sec = Math.max(0, Math.round((new Date(nowIso) - new Date(session.started_at)) / 1000));
    }
    cleanupSessions(sessData);
    writeSessions(sessData);
    console.log(`[MATCH] END    uid="${targetUid}" duration=${session.duration_sec}s`);
    res.json({ success: true, duration_sec: session.duration_sec });
  } else {
    res.json({ success: true, note: "No open session found" });
  }
});

// ── ADMIN SESSIONS ───────────────────────────────────────────────────────────

// Xem tất cả sessions (admin)
app.get("/api/admin/sessions", checkAdminAuth, (req, res) => {
  const sessData = readSessions();
  const changed = cleanupSessions(sessData);
  if (changed) {
    writeSessions(sessData);
  }
  const all = sessData.sessions || [];
  // Sort mới nhất trước
  const sorted = [...all].reverse();
  res.json(sorted);
});

// Xem sessions của 1 UID cụ thể
app.get("/api/admin/sessions/:uid", checkAdminAuth, (req, res) => {
  const targetUid = String(req.params.uid || "").trim();
  const sessData = readSessions();
  const changed = cleanupSessions(sessData);
  if (changed) {
    writeSessions(sessData);
  }
  const filtered = (sessData.sessions || [])
    .filter(s => s.uid === targetUid)
    .reverse();
  res.json(filtered);
});

// ── ONLINE STATUS ────────────────────────────────────────────────────────────
// Trả về map {uid -> "in_match" | "online" | "offline"} cho admin panel
app.get("/api/admin/online-status", checkAdminAuth, (req, res) => {
  const sessData = readSessions();
  const changed = cleanupSessions(sessData);
  if (changed) writeSessions(sessData);

  const now = Date.now();
  const ONLINE_WINDOW_MS = 90 * 1000; // seen in last 90s = "online"
  const statusMap = {};

  (sessData.sessions || []).forEach(s => {
    const lastSeen = s.last_seen_at ? new Date(s.last_seen_at).getTime() : 0;
    const wasRecentlySeen = (now - lastSeen) < ONLINE_WINDOW_MS;

    if (s.status === "in_match") {
      statusMap[s.uid] = "in_match";
    } else if (!statusMap[s.uid] && wasRecentlySeen) {
      statusMap[s.uid] = "online";
    }
  });

  res.json(statusMap);
});

// Periodic session cleanup every 30s
setInterval(() => {
  const sessData = readSessions();
  const changed = cleanupSessions(sessData);
  if (changed) {
    writeSessions(sessData);
    console.log("[PAYLOAD-SERVER] Cleaned up stale sessions.");
  }
}, 30 * 1000);

// ── HEALTH ───────────────────────────────────────────────────────────────────
app.get("/health", (req, res) => {
  res.json({ status: "ok", port: PORT });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`[PAYLOAD-SERVER] running on port ${PORT}`);
  getPlaintextPayload();
});
