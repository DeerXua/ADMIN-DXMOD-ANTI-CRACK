@echo off
title DXMOD - iOS Live Log Monitor
color 0A
echo ========================================================
echo   KHOI DONG HE THONG DOC LOG REALTIME CHO IPHONE / IPAD
echo ========================================================
echo   Dang kich hoat Apple USB Service (usbmuxd)...
start /B "" "C:\ExtractedPak\TOOL PAK DX\Tools\libimobiledevice\usbmuxd.exe" -t >nul 2>&1
timeout /t 2 /nobreak >nul
echo   Dang ket noi toi thiet bi iOS qua USB...
echo   (Luu y: Vui long mo khoa iPhone va chon "Tin cay may tinh nay")
echo --------------------------------------------------------
echo.
"C:\ExtractedPak\TOOL PAK DX\Tools\libimobiledevice\idevicesyslog.exe" | findstr /i "AddOutfit DXMOD EQUIP_WEAPON PUTON_CLOTH HEARTBEAT"
pause
