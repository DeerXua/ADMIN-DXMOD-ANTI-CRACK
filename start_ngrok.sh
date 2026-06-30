#!/data/data/com.termux/files/usr/bin/bash
echo "=== THIET LAP NGROK TREN SAMSUNG A13 ==="
echo "Dang sao chep ngrok va get_tunnel.js..."
cp /sdcard/Android/media/com.termux/ngrok ~/ngrok
cp /sdcard/Android/media/com.termux/get_tunnel.js ~/get_tunnel.js
chmod +x ~/ngrok

echo "Dang cau hinh authtoken..."
~/ngrok config add-authtoken 3FrlylSv2J3wPiwREALZrFpC3Jg_22RUZVzJfFZjCiWQvtoHm

echo "Dang khoi chay ngrok..."
pkill ngrok
~/ngrok http 3000 --log=stdout > ~/ngrok.log 2>&1 &

echo "Cho ngrok ket noi (5 giay)..."
sleep 5

echo "Ket qua:"
node ~/get_tunnel.js
