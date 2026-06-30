#!/data/data/com.termux/files/usr/bin/bash
echo "=== KHOI DONG SERVER NODE.JS TREN SAMSUNG A13 ==="
echo "Dang kiem tra va cap nhat Node.js..."
pkg install nodejs -y
echo "Dang sao chep file server.js..."
cp /sdcard/Android/media/com.termux/server.js ~/server.js
echo "Dang sao chep file protected_script.lua..."
cp /sdcard/Android/media/com.termux/protected_script.lua ~/protected_script.lua
echo "Dang khoi chay server..."
node ~/server.js
