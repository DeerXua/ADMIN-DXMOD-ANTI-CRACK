#!/data/data/com.termux/files/usr/bin/bash
echo "=== KHOI DONG TOAN BO HE THONG (SERVER + LOCALTUNNEL) ==="

echo "Dang tat cac tien trinh cu..."
pkill -f node
pkill -f lt

echo "Dang sao chep cac tep tin vao Termux..."
cp /sdcard/Android/media/com.termux/server.js ~/server.js
cp /sdcard/Android/media/com.termux/protected_script.lua ~/protected_script.lua

# Cai dat localtunnel de tranh loi phan cung 32-bit/64-bit cua Ngrok
cd ~
if [ ! -d ~/node_modules/localtunnel ]; then
    echo "Dang cai dat localtunnel phien ban Node.js (Tuong thich 100% voi Samsung A13)..."
    npm install localtunnel
fi

echo "Dang khoi chay Node.js Server (Background)..."
node ~/server.js > ~/server.log 2>&1 &

echo "Dang khoi chay Localtunnel voi Subdomain co dinh (Background)..."
npx lt --port 3000 --subdomain deerxua-dx-pak > ~/tunnel.log 2>&1 &

echo "Cho he thong khoi dong (8 giay)..."
sleep 8

echo "=== KET QUA KHOI DONG ==="
echo "Node.js Server: http://localhost:3000"
echo "Duong link public co dinh vinh vien cua ban:"
echo "https://deerxua-dx-pak.localtunnel.me"
