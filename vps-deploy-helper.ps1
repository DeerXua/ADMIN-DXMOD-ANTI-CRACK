# =============================================================
#  CORE-PAYLOAD-SERVER VPS Deploy via SSH
#  Chạy script PowerShell này sau khi bật terminal SSH
# =============================================================
#
#  CÁCH DÙNG:
#  1. Mở terminal và chạy: ssh root@160.250.246.119
#  2. Nhập password khi được hỏi
#  3. Sau khi vào VPS, paste lệnh bên dưới:

$DEPLOY_CMD = @"
# ---- CORE-PAYLOAD-SERVER One-Line Deploy ----
curl -fsSL https://raw.githubusercontent.com/DeerXua/ADMIN-DXMOD-ANTI-CRACK/main/deploy.sh -o /tmp/deploy_payload.sh && chmod +x /tmp/deploy_payload.sh && bash /tmp/deploy_payload.sh
"@

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  CORE-PAYLOAD-SERVER VPS Deploy Instructions" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Bước 1: SSH vào VPS" -ForegroundColor Yellow
Write-Host "  ssh root@160.250.246.119" -ForegroundColor White
Write-Host ""
Write-Host "Bước 2: Sau khi vào VPS, chạy lệnh này:" -ForegroundColor Yellow
Write-Host $DEPLOY_CMD -ForegroundColor Green
Write-Host ""
Write-Host "Lệnh này sẽ tự động:" -ForegroundColor Yellow
Write-Host "  ✅ Cài Node.js + PM2 (nếu chưa có)"
Write-Host "  ✅ Clone/pull code từ GitHub repo mới"
Write-Host "  ✅ npm install"
Write-Host "  ✅ Chạy server bảo mật với PM2 trên port 5002"
Write-Host ""
Write-Host "Kết quả:" -ForegroundColor Yellow
Write-Host "  🌐 http://160.250.246.119:5002/health  (Health Check)"
Write-Host "  🔗 http://160.250.246.119:5002/api/payload  (Endpoint lấy code)"
Write-Host ""

# Tự động copy lệnh vào clipboard
$DEPLOY_CMD | Set-Clipboard
Write-Host "✅ Lệnh deploy đã được copy vào clipboard!" -ForegroundColor Green
Write-Host "   Chỉ cần SSH vào VPS và Ctrl+V để paste." -ForegroundColor Green
