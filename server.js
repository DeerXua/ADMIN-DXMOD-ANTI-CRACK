import express from "express";
import cors from "cors";
import compression from "compression";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import crypto from "node:crypto";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = process.env.PORT || 5002;
const DB_PATH = path.join(__dirname, "data.json");
const SESSIONS_PATH = path.join(__dirname, "sessions.json");
const PAYLOAD_PATH = path.join(__dirname, "protected_payload.lua");
const PAYLOAD_PATHS = {
  free: path.join(__dirname, "payload_free.lua"),
  vip: path.join(__dirname, "payload_vip.lua"),
  test: path.join(__dirname, "payload_test.lua"),
  onlywall: path.join(__dirname, "payload_onlywall.lua")
};

// Authentication — MUST be set via environment variable
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;
if (!ADMIN_PASSWORD) {
  console.error("[PAYLOAD-SERVER] FATAL: ADMIN_PASSWORD environment variable is required. Set ADMIN_PASSWORD before starting.");
  process.exit(1);
}
const CORS_ORIGIN = process.env.CORS_ORIGIN || "*";
const SERVER_PUBLIC_URL = (process.env.SERVER_PUBLIC_URL || `http://localhost:${PORT}`).replace(/\/+$/, "");
const MAX_SCREENSHOT_HEX_LENGTH = Number(process.env.MAX_SCREENSHOT_HEX_LENGTH || 2 * 1024 * 1024);

// Caching cache keys: 'default', 'free', 'vip', 'test'
let cachedPayloads = {};
let lastPayloadMtimes = {};

// Helper function to send Telegram Bot notification
async function sendTelegramNotification(text) {
  try {
    const db = readDatabase();
    const settings = db.settings || {};
    const token = settings.telegram_bot_token || process.env.TELEGRAM_BOT_TOKEN;
    const chatId = settings.telegram_chat_id || process.env.TELEGRAM_CHAT_ID;
    if (!token || !chatId) return;

    const url = `https://api.telegram.org/bot${token}/sendMessage`;
    const payload = JSON.stringify({
      chat_id: chatId,
      text: text,
      parse_mode: "Markdown"
    });

    await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: payload
    });
  } catch (err) {
    console.error("[PAYLOAD-SERVER] Telegram notification error:", err.message);
  }
}

const app = express();
app.use(compression());
app.use(cors({ origin: CORS_ORIGIN }));
app.use(express.json({ limit: "3mb" }));
app.use(express.urlencoded({ extended: true, limit: "3mb" }));

// Serve Web Admin UI Static Files (caching enabled for instant load)
app.use(express.static(path.join(__dirname, "public"), {
  maxAge: "1d",
  etag: true
}));

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

// DJB2 hash function — mirrors Lua djb2_hash
function djb2(str) {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash * 33) + str.charCodeAt(i)) >>> 0;
  }
  return hash.toString(16).padStart(8, "0");
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

// Minify Lua script helper
function minifyLua(code) {
  let minified = code.replace(/--\[\[[\s\S]*?\]\]/g, "");
  let lines = minified.split(/\r?\n/);
  let resultLines = [];
  
  for (let line of lines) {
    let trimmed = line.trim();
    if (!trimmed) continue;
    if (trimmed.startsWith("--")) continue;
    
    let inString = false;
    let stringChar = null;
    let commentIdx = -1;
    
    for (let i = 0; i < line.length; i++) {
      let char = line[i];
      if (!inString) {
        if (char === '"' || char === "'") {
          inString = true;
          stringChar = char;
        } else if (char === '-' && i + 1 < line.length && line[i+1] === '-') {
          commentIdx = i;
          break;
        }
      } else {
        if (char === stringChar) {
          let escaped = false;
          let j = i - 1;
          while (j >= 0 && line[j] === '\\') {
            escaped = !escaped;
            j--;
          }
          if (!escaped) {
            inString = false;
            stringChar = null;
          }
        }
      }
    }
    
    if (commentIdx !== -1) {
      line = line.substring(0, commentIdx);
      trimmed = line.trim();
      if (!trimmed) continue;
    }
    
    resultLines.push(trimmed);
  }
  
  return resultLines.join("\n");
}

// Load and cache plaintext payload (encrypt per-request with uid-derived key)
function getPlaintextPayload(payloadType = "free") {
  const type = String(payloadType || "free").toLowerCase();
  let targetPath = PAYLOAD_PATHS[type];
  
  // Fallback to default payload if custom payload file doesn't exist
  if (!targetPath || !fs.existsSync(targetPath)) {
    targetPath = PAYLOAD_PATH;
  }

  if (!fs.existsSync(targetPath)) {
    console.error(`[PAYLOAD-SERVER] Payload file not found at: ${targetPath}`);
    return "";
  }
  
  try {
    const stats = fs.statSync(targetPath);
    const mtime = stats.mtimeMs;
    if (!cachedPayloads[type] || mtime !== lastPayloadMtimes[type]) {
      let content = fs.readFileSync(targetPath, "utf8");
      content = content.replace(/__API_BASE__/g, SERVER_PUBLIC_URL);
      content = minifyLua(content);
      cachedPayloads[type] = content;
      lastPayloadMtimes[type] = mtime;
      console.log(`[PAYLOAD-SERVER] Loaded ${type} plaintext payload: ${(cachedPayloads[type].length / 1024).toFixed(2)} KB`);
    }
    return cachedPayloads[type];
  } catch (err) {
    console.error(`[PAYLOAD-SERVER] Failed to read ${type} payload file:`, err.message);
    return cachedPayloads[type] || "";
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
  const token = String(req.headers["authorization"] || "").replace(/^Bearer\s+/i, "");
  if (token === ADMIN_PASSWORD) {
    next();
  } else {
    res.status(401).json({ error: "Unauthorized access" });
  }
}

// API endpoint to serve protected payload
app.post("/api/payload", (req, res) => {
  res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate");
  res.setHeader("Pragma", "no-cache");
  res.setHeader("Expires", "0");
  res.setHeader("Surrogate-Control", "no-store");

  const { uid, timestamp, sign } = req.body;
  const targetUid = String(uid || "").trim();

  if (!targetUid) {
    return res.status(400).json({ status: "error", message: "Missing UID" });
  }

  // Xác thực chữ ký số (Request Signature)
  const secret = "DX_SECURE_TOKEN_2026_#$@";
  if (!timestamp || !sign) {
    return res.status(403).json({ status: "error", message: "Yêu cầu bị từ chối: Thiếu chữ ký số." });
  }

  // 1. Kiểm tra độ lệch thời gian (cho phép lệch tối đa 30 phút)
  const serverTime = Math.floor(Date.now() / 1000);
  const clientTime = Number(timestamp);
  // clientTime < 1701000000: là timestamp fallback (thiết bị không đọc được giờ hệ thống) - chỉ kiểm tra sign
  const isFallbackTimestamp = clientTime > 0 && clientTime < 1701000000;
  if (isNaN(clientTime) || clientTime <= 0) {
    return res.status(403).json({ status: "error", message: "Timestamp không hợp lệ." });
  }
  if (!isFallbackTimestamp && Math.abs(serverTime - clientTime) > 1800) {
    return res.status(403).json({ status: "error", message: "Yêu cầu hết hạn hoặc thời gian thiết bị không chính xác." });
  }

  // 2. Kiểm tra mã băm DJB2 từ client (độc lập, không phụ thuộc MD5 của client game)
  const calculatedSign = djb2(targetUid + timestamp + secret);
  if (calculatedSign.toLowerCase() !== String(sign).toLowerCase()) {
    return res.status(403).json({ status: "error", message: "Yêu cầu bị từ chối: Chữ ký số không hợp lệ." });
  }

  const db = readDatabase();
  const devices = db.devices || [];
  let device = devices.find(d => String(d.game_id || "").trim() === targetUid);

  const nowIso = new Date().toISOString();

  if (!device) {
    const nextId = db.nextId ?? (devices.length > 0 ? Math.max(...devices.map(d => d.id || 0)) + 1 : 1);
    // Auto-approve: status = "approved", payload_type = "free", expires_at = 7 days from now
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    device = {
      id: nextId,
      game_id: targetUid,
      label: `Device ${targetUid}`,
      status: "approved",
      payload_type: "free",
      expires_at: expiresAt,
      note: "Tự động đăng ký - FREE 7 ngày",
      first_seen_at: nowIso,
      updated_at: nowIso,
      last_seen_at: nowIso
    };
    devices.push(device);
    db.nextId = nextId + 1;
    db.devices = devices;
    writeDatabase(db);
    console.log(`[PAYLOAD-SERVER] Auto-registered and approved new UID: "${targetUid}" (free, 7 days)`);

    // Gửi thông báo Telegram khi có thiết bị mới đăng ký
    sendTelegramNotification(
      `📱 *THIẾT BỊ MỚI ĐĂNG KÝ*\n` +
      `• *Tên/Label:* \`${device.label}\`\n` +
      `• *Game ID:* \`${targetUid}\`\n` +
      `• *Gói:* FREE (7 ngày)\n` +
      `• *Thời gian:* ${new Date().toLocaleString("vi-VN")}`
    );
  }

  device.last_seen_at = nowIso;
  device.updated_at = nowIso;
  writeDatabase(db);

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

  const payloadType = device.payload_type || "free";
  const plaintext = getPlaintextPayload(payloadType);
  if (!plaintext) {
    return res.status(500).json({ status: "error", message: "Server configuration error: missing payload" });
  }

  // Encrypt with uid-derived key — unique per user
  const key = deriveKey(device.game_id);
  const encryptedCode = encryptXOR(plaintext, key);

  res.json({
    status: "approved",
    payload: encryptedCode,
    expires_at: device.expires_at,
    payload_type: payloadType,
    payload_mtime: lastPayloadMtimes[payloadType] || 0
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
      return res.json({ status: "expired", active: false, message: "License expired", expires_at: device.expires_at });
    }
  }

  const nowIso = new Date().toISOString();
  device.last_seen_at = nowIso;
  device.updated_at = nowIso;
  writeDatabase(db);

  res.json({ status: "success", active: true, message: "Device activated", expires_at: device.expires_at });
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
  const { uid, expires_at, label, note, payload_type } = req.body;
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
  if (payload_type !== undefined) device.payload_type = payload_type || "free";
  device.updated_at = new Date().toISOString();
  writeDatabase(db);

  console.log(`[PAYLOAD-SERVER] Device approved: "${targetUid}" (${device.payload_type}) until: ${expires_at || "lifetime"}`);

  // Gửi thông báo Telegram khi nâng cấp / duyệt thiết bị
  const typeUpper = (device.payload_type || "free").toUpperCase();
  const expireText = expires_at ? new Date(expires_at).toLocaleDateString("vi-VN") : "Vĩnh viễn (1 mùa)";
  sendTelegramNotification(
    `👑 *CẬP NHẬT TRẠNG THÁI THIẾT BỊ*\n` +
    `• *Tên/Label:* ${device.label || targetUid}\n` +
    `• *Game ID:* \`${targetUid}\`\n` +
    `• *Gói cước:* *${typeUpper}*\n` +
    `• *Hạn dùng:* ${expireText}\n` +
    `• *Ghi chú:* ${note || "Không có"}`
  );

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

// ── REALTIME ANALYTICS & STATS ────────────────────────────────────────────────
app.get("/api/admin/stats", checkAdminAuth, (req, res) => {
  const db = readDatabase();
  const devices = db.devices || [];
  const now = Date.now();
  const ONLINE_WINDOW_MS = 90 * 1000; // 1.5 phút (90 giây) tính Online

  let onlineCount = 0;
  let vipCount = 0;
  let freeCount = 0;
  let testCount = 0;
  let pendingCount = 0;
  let expiredCount = 0;

  devices.forEach(d => {
    const lastSeen = d.last_seen_at ? new Date(d.last_seen_at).getTime() : (d.updated_at ? new Date(d.updated_at).getTime() : 0);
    if (now - lastSeen <= ONLINE_WINDOW_MS) {
      onlineCount++;
    }

    const type = (d.payload_type || "free").toLowerCase();
    const status = (d.status || "").toLowerCase();

    const isExpired = d.expires_at && new Date(d.expires_at).getTime() < now;

    if (status === "pending") {
      pendingCount++;
    } else if (isExpired) {
      expiredCount++;
    } else if (type === "vip") {
      vipCount++;
    } else if (type === "test") {
      testCount++;
    } else {
      freeCount++;
    }
  });

  const total = devices.length;

  res.json({
    success: true,
    totalDevices: total,
    onlineCount: onlineCount,
    counts: {
      vip: vipCount,
      free: freeCount,
      test: testCount,
      pending: pendingCount,
      expired: expiredCount
    },
    percentages: {
      vip: total > 0 ? Number(((vipCount / total) * 100).toFixed(1)) : 0,
      free: total > 0 ? Number(((freeCount / total) * 100).toFixed(1)) : 0,
      test: total > 0 ? Number(((testCount / total) * 100).toFixed(1)) : 0,
      pending: total > 0 ? Number(((pendingCount / total) * 100).toFixed(1)) : 0,
      expired: total > 0 ? Number(((expiredCount / total) * 100).toFixed(1)) : 0
    }
  });
});

// Endpoint trả về danh sách chi tiết tất cả thiết bị đang ONLINE
app.get("/api/admin/online-list", checkAdminAuth, (req, res) => {
  const db = readDatabase();
  const devices = db.devices || [];
  const sessions = readSessions();
  const now = Date.now();
  const ONLINE_WINDOW_MS = 90 * 1000; // 1.5 phút (90 giây)

  const onlineDevices = devices
    .filter(d => {
      const lastSeen = d.last_seen_at ? new Date(d.last_seen_at).getTime() : (d.updated_at ? new Date(d.updated_at).getTime() : 0);
      return (now - lastSeen <= ONLINE_WINDOW_MS);
    })
    .map(d => {
      const targetUid = String(d.game_id || "").trim();
      const activeSession = sessions.find(s => String(s.uid || "").trim() === targetUid && s.status === "in_match");
      const userSessions = sessions.filter(s => String(s.uid || "").trim() === targetUid);
      const lastSession = userSessions.length > 0 ? userSessions[userSessions.length - 1] : null;
      const playerName = activeSession ? activeSession.player_name : (lastSession ? lastSession.player_name : (d.last_player_name || "Chưa ghi nhận"));

      return {
        game_id: d.game_id,
        label: d.label || d.game_id,
        player_name: playerName,
        payload_type: d.payload_type || "free",
        status: d.status,
        last_seen_at: d.last_seen_at || d.updated_at,
        in_match: !!activeSession,
        match_id: activeSession ? activeSession.match_id : null,
        kills: activeSession ? (activeSession.kills || 0) : 0,
        note: d.note || ""
      };
    });

  res.json({ success: true, count: onlineDevices.length, devices: onlineDevices });
});

// ── TELEGRAM BOT SETTINGS ────────────────────────────────────────────────────
app.get("/api/admin/settings/telegram", checkAdminAuth, (req, res) => {
  const db = readDatabase();
  const settings = db.settings || {};
  res.json({
    telegram_bot_token: settings.telegram_bot_token || process.env.TELEGRAM_BOT_TOKEN || "",
    telegram_chat_id: settings.telegram_chat_id || process.env.TELEGRAM_CHAT_ID || ""
  });
});

app.post("/api/admin/settings/telegram", checkAdminAuth, (req, res) => {
  const { telegram_bot_token, telegram_chat_id } = req.body;
  const db = readDatabase();
  db.settings = db.settings || {};
  db.settings.telegram_bot_token = String(telegram_bot_token || "").trim();
  db.settings.telegram_chat_id = String(telegram_chat_id || "").trim();
  writeDatabase(db);
  console.log("[PAYLOAD-SERVER] Updated Telegram settings.");
  res.json({ success: true, message: "Đã lưu cấu hình Telegram Bot!" });
});

app.post("/api/admin/test-telegram", checkAdminAuth, async (req, res) => {
  const db = readDatabase();
  const settings = db.settings || {};
  const token = settings.telegram_bot_token || process.env.TELEGRAM_BOT_TOKEN;
  const chatId = settings.telegram_chat_id || process.env.TELEGRAM_CHAT_ID;

  if (!token || !chatId) {
    return res.status(400).json({ error: "Chưa cấu hình Telegram Bot Token hoặc Chat ID!" });
  }

  try {
    const url = `https://api.telegram.org/bot${token}/sendMessage`;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text: `🤖 *KẾT NỐI THÀNH CÔNG!*\n\nHệ thống thông báo Telegram Bot của *DXMOD Server* đã hoạt động mượt mà!\nThời gian: ${new Date().toLocaleString("vi-VN")}`,
        parse_mode: "Markdown"
      })
    });
    const data = await response.json();
    if (data.ok) {
      res.json({ success: true, message: "Gửi tin nhắn thử nghiệm thành công! Kiểm tra Telegram của bạn." });
    } else {
      res.status(400).json({ error: `Lỗi Telegram API: ${data.description || "Không thể gửi tin nhắn"}` });
    }
  } catch (err) {
    res.status(500).json({ error: `Lỗi kết nối Telegram: ${err.message}` });
  }
});

// ── ADMIN BULK & UTILITY ─────────────────────────────────────────────────────

// Manually create a device (admin)
app.post("/api/admin/create", checkAdminAuth, (req, res) => {
  const { uid, label, expires_at, note, payload_type } = req.body;
  const targetUid = String(uid || "").trim();
  if (!targetUid) {
    return res.status(400).json({ error: "Missing UID" });
  }

  const db = readDatabase();
  if ((db.devices || []).find(d => String(d.game_id || "").trim() === targetUid)) {
    return res.status(409).json({ error: "UID đã tồn tại trong hệ thống" });
  }

  const nextId = db.nextId ?? (db.devices.length > 0 ? Math.max(...db.devices.map(d => d.id || 0)) + 1 : 1);
  const nowIso = new Date().toISOString();
  const device = {
    id: nextId,
    game_id: targetUid,
    label: label || `Device ${targetUid}`,
    status: "approved",
    payload_type: payload_type || "free",
    expires_at: expires_at || null,
    note: note || "Created by admin",
    first_seen_at: nowIso,
    updated_at: nowIso
  };
  db.devices.push(device);
  db.nextId = nextId + 1;
  writeDatabase(db);

  console.log(`[PAYLOAD-SERVER] Admin created device: "${targetUid}" (${device.payload_type})`);
  res.json({ success: true, device });
});

// Bulk approve devices
app.post("/api/admin/bulk-approve", checkAdminAuth, (req, res) => {
  const { uids, expires_at } = req.body;
  if (!Array.isArray(uids) || uids.length === 0) {
    return res.status(400).json({ error: "Missing UID list" });
  }

  const db = readDatabase();
  const nowIso = new Date().toISOString();
  let count = 0;

  uids.forEach(uid => {
    const targetUid = String(uid || "").trim();
    if (!targetUid) return;
    const device = db.devices.find(d => String(d.game_id || "").trim() === targetUid);
    if (device) {
      device.status = "approved";
      if (expires_at !== undefined) device.expires_at = expires_at;
      device.updated_at = nowIso;
      count++;
    }
  });

  if (count > 0) {
    writeDatabase(db);
    console.log(`[PAYLOAD-SERVER] Bulk approved ${count} devices`);
  }
  res.json({ success: true, count });
});

// Bulk delete devices
app.post("/api/admin/bulk-delete", checkAdminAuth, (req, res) => {
  const { uids } = req.body;
  if (!Array.isArray(uids) || uids.length === 0) {
    return res.status(400).json({ error: "Missing UID list" });
  }

  const db = readDatabase();
  const before = db.devices.length;
  db.devices = db.devices.filter(d => !uids.includes(String(d.game_id || "").trim()));
  const count = before - db.devices.length;

  if (count > 0) {
    writeDatabase(db);
    console.log(`[PAYLOAD-SERVER] Bulk deleted ${count} devices`);
  }
  res.json({ success: true, count });
});

// Export devices as CSV
app.get("/api/admin/export/devices", checkAdminAuth, (req, res) => {
  const db = readDatabase();
  const devices = db.devices || [];

  const headers = ["ID", "UID", "Label", "Status", "Expires At", "Note", "First Seen", "Updated At", "Player Name"];
  const rows = devices.map(d => [
    d.id,
    d.game_id,
    d.label,
    d.status,
    d.expires_at || "lifetime",
    d.note || "",
    d.first_seen_at || "",
    d.updated_at || "",
    d.player_name || ""
  ].map(v => `"${String(v).replace(/"/g, '""')}"`).join(","));

  const csv = [headers.join(","), ...rows].join("\n");
  res.setHeader("Content-Type", "text/csv; charset=utf-8");
  res.setHeader("Content-Disposition", `attachment; filename="devices_${new Date().toISOString().slice(0,10)}.csv"`);
  res.send("\uFEFF" + csv); // BOM for Excel UTF-8
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

  // Cập nhật tên player vào device record và nhãn hiển thị ở Admin
  if (player_name && player_name !== "UNKNOWN") {
    const trimmedName = String(player_name).trim();
    device.player_name = trimmedName;
    device.label = trimmedName; // Đồng bộ tên thiết bị thành tên người chơi
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
    kill_num: 0,
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
  const { uid, session_id, kill_num } = req.body;
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
    const kills = Number(kill_num);
    if (Number.isFinite(kills) && kills >= 0) {
      session.kill_num = Math.max(Number(session.kill_num) || 0, Math.floor(kills));
    }
    writeSessions(sessData);
    res.json({ success: true });
  } else {
    res.status(404).json({ error: "Session not found" });
  }
});

// Client báo kết thúc trận
app.post("/api/match/end", (req, res) => {
  const { uid, session_id, kill_num } = req.body;
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
    const kills = Number(kill_num);
    if (Number.isFinite(kills) && kills >= 0) {
      session.kill_num = Math.max(Number(session.kill_num) || 0, Math.floor(kills));
    }
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

// Client báo đạt Top 1 (Victory Chicken Dinner)
app.post("/api/match/top1", (req, res) => {
  const { uid, session_id, player_name, kill_num, match_id, screenshot_hex } = req.body;
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
    const matches = sessData.sessions.filter(s => s.uid === targetUid && s.status === "in_match");
    session = matches[matches.length - 1];
  }

  // Lưu ảnh chụp màn hình nếu có gửi kèm hex data
  let screenshot_url = null;
  if (screenshot_hex && screenshot_hex.length > 0) {
    try {
      const screenshotHex = String(screenshot_hex);
      if (screenshotHex.length > MAX_SCREENSHOT_HEX_LENGTH) {
        throw new Error("Screenshot payload is too large");
      }
      if (screenshotHex.length % 2 !== 0 || !/^[0-9a-fA-F]+$/.test(screenshotHex)) {
        throw new Error("Screenshot payload is not valid hex");
      }
      const screenshotsDir = path.join(__dirname, "public", "screenshots");
      if (!fs.existsSync(screenshotsDir)) {
        fs.mkdirSync(screenshotsDir, { recursive: true });
      }
      const filename = `top1_${targetUid}_${Date.now()}.png`;
      const filepath = path.join(screenshotsDir, filename);
      fs.writeFileSync(filepath, Buffer.from(screenshotHex, "hex"));
      screenshot_url = `/screenshots/${filename}`;
    } catch (err) {
      console.error("[MATCH] Failed to save top1 screenshot:", err.message);
    }
  }

  if (session) {
    session.top1 = true;
    session.kill_num = Number(kill_num) || 0;
    session.player_name = player_name || session.player_name;
    session.match_id = match_id || session.match_id;
    session.victory_time = nowIso;
    session.victory_screenshot = screenshot_url;
    session.last_seen_at = nowIso;
    writeSessions(sessData);
    console.log(`[MATCH] TOP-1  uid="${targetUid}" name="${player_name || session.player_name}" kills=${kill_num} screenshot="${screenshot_url || "none"}"`);
  } else {
    // Dự phòng tạo session Top 1 tự do nếu không có session trước đó
    sessData.sessions.push({
      id: "victory_" + Date.now(),
      uid: targetUid,
      player_name: player_name || "UNKNOWN",
      match_id: match_id || "UNKNOWN",
      status: "victory",
      top1: true,
      kill_num: Number(kill_num) || 0,
      started_at: nowIso,
      victory_time: nowIso,
      victory_screenshot: screenshot_url,
      last_seen_at: nowIso
    });
    writeSessions(sessData);
    console.log(`[MATCH] TOP-1 (standalone) uid="${targetUid}" name="${player_name}" kills=${kill_num} screenshot="${screenshot_url || "none"}"`);
  }
  res.json({ success: true, message: "Victory feedback recorded" });
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

// Xóa tất cả sessions (admin)
app.post("/api/admin/sessions/clear", checkAdminAuth, (req, res) => {
  writeSessions({ sessions: [] });
  res.json({ success: true, message: "Đã xóa toàn bộ lịch sử phiên đấu." });
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
