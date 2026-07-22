# =============================================================
#  CORE-PAYLOAD-SERVER VPS Deploy via SSH
#  Chạy script PowerShell này sau khi bật terminal SSH
# =============================================================
#
#  CÁCH DÙNG:
#  1. Mở terminal và chạy: ssh root@103.77.243.123
#  2. Nhập password khi được hỏi
#  3. Sau khi vào VPS, paste lệnh bên dưới:

$DEPLOY_CMD = @"
# ---- CORE-PAYLOAD-SERVER One-Line Deploy ----
# ⚠️ CHỈ CẦN NHẬP MẬT KHẨU DUY NHẤT LẦN NÀY!
# Lần sau chỉ cần: cd /opt/core-payload-server && git pull && pm2 restart core-payload-server
ADMIN_PASSWORD='matkhau_cua_ban' bash -c "$(curl -fsSL https://raw.githubusercontent.com/DeerXua/ADMIN-DXMOD-ANTI-CRACK/main/deploy.sh)"
"@

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  CORE-PAYLOAD-SERVER VPS Deploy Instructions" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  CHỈ CẦN NHẬP MẬT KHẨU DUY NHẤT LẦN NÀY!" -ForegroundColor Red
Write-Host "     Sau đó restart không cần password nữa!" -ForegroundColor Red
Write-Host ""
Write-Host "Bước 1: SSH vào VPS" -ForegroundColor Yellow
Write-Host "  ssh root@103.77.243.123" -ForegroundColor White
Write-Host ""
Write-Host "Bước 2: Sau khi vào VPS, chạy lệnh này (sửa mật khẩu trước):" -ForegroundColor Yellow
Write-Host "  ADMIN_PASSWORD='matkhau_cua_ban' bash -c '$(curl -fsSL https://raw.githubusercontent.com/DeerXua/ADMIN-DXMOD-ANTI-CRACK/main/deploy.sh)'" -ForegroundColor Green
Write-Host ""
Write-Host "Lệnh này sẽ tự động:" -ForegroundColor Yellow
Write-Host "  ✅ Cài Node.js + PM2 (nếu chưa có)"
Write-Host "  ✅ Clone/pull code từ GitHub repo mới"
Write-Host "  ✅ Tạo ecosystem.config.cjs (lưu mật khẩu vĩnh viễn)"
Write-Host "  ✅ npm install"
Write-Host "  ✅ Chạy server bảo mật với PM2 trên port 5002"
Write-Host ""
Write-Host "CÁC LẦN SAU CHỈ CẦN:" -ForegroundColor Green
Write-Host "  cd /opt/core-payload-server && git pull && pm2 restart core-payload-server" -ForegroundColor White
Write-Host ""
Write-Host "Kết quả:" -ForegroundColor Yellow
Write-Host "  https://lethiennhan.id.vn/health  (Health Check)"
Write-Host "  https://lethiennhan.id.vn/api/payload  (Endpoint lấy code)"
Write-Host ""

# Tự động copy lệnh vào clipboard
$DEPLOY_CMD | Set-Clipboard
Write-Host "✅ Lệnh deploy đã được copy vào clipboard!" -ForegroundColor Green
Write-Host "   Nhớ sửa 'matkhau_cua_ban' thành mật khẩu thật trước khi paste!" -ForegroundColor Yellow
