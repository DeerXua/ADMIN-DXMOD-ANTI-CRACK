#!/data/data/com.termux/files/usr/bin/bash
echo "=== KHOI DONG TOAN BO HE THONG (SERVER + NGROK 32-BIT) ==="

echo "Dang tat cac tien trinh cu..."
pkill -f node
pkill ngrok

echo "Dang sao chep cac tep tin vao Termux..."
cp /sdcard/Android/media/com.termux/server.js ~/server.js
cp /sdcard/Android/media/com.termux/protected_script.lua ~/protected_script.lua
cp /sdcard/Android/media/com.termux/ngrok ~/ngrok
chmod +x ~/ngrok

# Tu dong kiem tra va tai Ngrok arm (32-bit) phu hop
if ! ~/ngrok --version >/dev/null 2>&1; then
    echo "============================================="
    echo "Phat hien loi e_type hoac kien truc CPU!"
    echo "Dang tai phien ban Ngrok ARM 32-bit hop le..."
    echo "============================================="
    pkg install wget tar -y
    wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.tgz -O ~/ngrok.tgz
    tar -xvzf ~/ngrok.tgz -C ~/
    rm ~/ngrok.tgz
    chmod +x ~/ngrok
fi

echo "Dang cau hinh ngrok authtoken..."
~/ngrok config add-authtoken 3FrlylSv2J3wPiwREALZrFpC3Jg_22RUZVzJfFZjCiWQvtoHm

echo "Dang khoi chay Node.js Server (Background)..."
node ~/server.js > ~/server.log 2>&1 &

echo "Dang khoi chay Ngrok Static Domain (Background)..."
~/ngrok http 3000 --domain=amiss-uncouth-junkman.ngrok-free.dev --log=stdout > ~/ngrok.log 2>&1 &

echo "Cho he thong khoi dong (8 giay)..."
sleep 8

echo "=== KET QUA KHOI DONG ==="
echo "Node.js Server: http://localhost:3000"
echo "Duong link public co dinh vinh vien cua ban:"
echo "https://amiss-uncouth-junkman.ngrok-free.dev"
