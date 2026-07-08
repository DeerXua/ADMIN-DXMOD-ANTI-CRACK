#!/bin/bash
# =============================================================
#  DXMOD CORE-PAYLOAD-SERVER VPS Deploy Script — SAFE MODE
#  - Chỉ cài vào /opt/core-payload-server (thư mục riêng biệt)
#  - KHÔNG đụng tới bất kỳ project/process nào đang chạy
#  - KHÔNG dùng pm2 delete/stop/kill trên process khác
#  - Chạy CORE-PAYLOAD-SERVER trên port 5002
# =============================================================

set -e

VPS_DIR="/opt/core-payload-server"
REPO="https://github.com/DeerXua/ADMIN-DXMOD-ANTI-CRACK.git"
SERVICE="core-payload-server"
PORT_NUMBER=5002

# ── BẮT BUỘC: Set mật khẩu admin ──────────────────────────────────
if [ -z "$ADMIN_PASSWORD" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  ❌ CHƯA SET MẬT KHẨU ADMIN!                           ║"
    echo "║                                                         ║"
    echo "║  Chạy lệnh sau trước khi deploy:                        ║"
    echo "║    export ADMIN_PASSWORD='matkhau_cua_ban'              ║"
    echo "║                                                         ║"
    echo "║  Hoặc chạy lại với:                                     ║"
    echo "║    ADMIN_PASSWORD='matkhau_cua_ban' bash deploy.sh      ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# SERVER_PUBLIC_URL (mặc định tự động lấy từ IP VPS nếu để trống)
if [ -z "$SERVER_PUBLIC_URL" ]; then
    SERVER_PUBLIC_URL="http://$(curl -s http://checkip.amazonaws.com 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}'):$PORT_NUMBER"
fi

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║      CORE PAYLOAD SERVER VPS Deploy       ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "⚠️  Cài đặt vào: $VPS_DIR"
echo "⚠️  Port sử dụng: $PORT_NUMBER"
echo ""

# 1. Cài Node.js (nếu chưa có)
echo "[1/4] Checking Node.js..."
if ! command -v node &>/dev/null; then
    echo "  → Cài Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
    apt-get install -y nodejs >/dev/null 2>&1
else
    echo "  ✓ Node.js $(node --version) already installed"
fi

# 2. Cài PM2 (nếu chưa có)
echo "[2/4] Checking PM2..."
if ! command -v pm2 &>/dev/null; then
    echo "  → Cài PM2..."
    npm install -g pm2 >/dev/null 2>&1
else
    echo "  ✓ PM2 $(pm2 --version) already installed"
fi

# 3. Pull/Clone code
echo "[3/4] Fetching latest files..."
if [ -d "$VPS_DIR/.git" ]; then
    cd "$VPS_DIR"
    git pull origin main || git pull origin master
else
    mkdir -p "$VPS_DIR"
    git clone "$REPO" "$VPS_DIR"
fi

cd "$VPS_DIR"

# Cài đặt dependencies
npm install --omit=dev --silent

# 4. Quản lý tiến trình PM2
echo "[4/4] Starting core-payload-server under PM2..."
if pm2 describe "$SERVICE" &>/dev/null 2>&1; then
    echo "  → Restarting existing '$SERVICE'..."
    PORT=$PORT_NUMBER ADMIN_PASSWORD="$ADMIN_PASSWORD" SERVER_PUBLIC_URL="$SERVER_PUBLIC_URL" \
        pm2 restart "$SERVICE" --update-env
else
    echo "  → Starting new '$SERVICE'..."
    PORT=$PORT_NUMBER ADMIN_PASSWORD="$ADMIN_PASSWORD" SERVER_PUBLIC_URL="$SERVER_PUBLIC_URL" \
        pm2 start server.js \
        --name "$SERVICE" \
        --cwd "$VPS_DIR"
fi

pm2 save

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║                  DEPLOY COMPLETE!                    ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  URL Endpoint:  POST http://160.250.246.119:5002/api/payload ║"
echo "║  Health check:  GET  http://160.250.246.119:5002/health      ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Xem log:       pm2 logs $SERVICE                    ║"
echo "║  Trạng thái:    pm2 status                           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
pm2 list
