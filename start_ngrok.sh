#!/data/data/com.termux/files/usr/bin/bash
echo "=== THIET LAP NGROK TREN SAMSUNG A13 ==="
echo "Dang sao chep ngrok va protected files..."
cp /sdcard/Android/media/com.termux/ngrok ~/ngrok
chmod +x ~/ngrok

echo "Dang cau hinh authtoken..."
~/ngrok config add-authtoken 3FrlylSv2J3wPiwREALZrFpC3Jg_22RUZVzJfFZjCiWQvtoHm

echo "Dang khoi chay ngrok voi ten mien co dinh..."
pkill ngrok
~/ngrok http 3000 --domain=amiss-uncouth-junkman.ngrok-free.dev --log=stdout > ~/ngrok.log 2>&1 &

echo "Cho ngrok ket noi (5 giay)..."
sleep 5

echo "=== DUONG LINK CO DINH CUA BAN ==="
echo "https://amiss-uncouth-junkman.ngrok-free.dev"
