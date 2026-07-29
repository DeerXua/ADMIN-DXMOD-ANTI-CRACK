local OriginalClass = ...
local BRPlayerCharacterBase = OriginalClass or {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local KismetMathLibrary = import("KismetMathLibrary")
local GameplayStatics = import("GameplayStatics")
local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")

local bWriteLog = false
local printf = function(...)
    if bWriteLog then
        print(...)
    end
end

local DX_API_BASE = "__API_BASE__"
local DX_TELE_GROUP = "https://telegram.me/HakuxDX"
local DX_TELE_ADMIN = "https://t.me/DeerXua"

local _cachedHWID = nil
local function GetHardwareDeviceID()
    if _cachedHWID then return _cachedHWID end
    local hwid = "UNKNOWN"
    pcall(function()
        local S = import("KismetSystemLibrary")
        if S and S.GetDeviceId then
            hwid = tostring(S.GetDeviceId())
        end
    end)
    if hwid ~= "UNKNOWN" and hwid ~= "" then
        _cachedHWID = hwid
    end
    return hwid
end

local function GetPackageName()
    if _G.DX_PackageName then return _G.DX_PackageName end
    local packages = {
        "com.tencent.ig",
        "com.vng.pubgmobile",
        "com.pubg.krmobile",
        "com.pubg.imobile",
        "com.rekoo.pubgm",
        "com.tencent.tmgp.pubgm",
        "com.tencent.iglite"
    }
    for _, pkg in ipairs(packages) do
        local temp_file_path = string.format("/sdcard/Android/data/%s/files/.dx_temp", pkg)
        local f = io.open(temp_file_path, "w")
        if f then
            f:close()
            os.remove(temp_file_path)
            _G.DX_PackageName = pkg
            return pkg
        end
    end
    _G.DX_PackageName = "com.tencent.ig"
    return "com.tencent.ig"
end

local function GetDeviceUID()
    local uid = "UNKNOWN"
    -- 1. Try reading the cached game UID from dx_last_uid.txt
    pcall(function()
        local platform = "Android"
        pcall(function()
            local S = import("KismetSystemLibrary")
            if S and S.GetPlatformName then
                platform = tostring(S.GetPlatformName()):upper()
            end
        end)

        local f = nil
        if platform == "IOS" then
            local ios_paths = {
                "dx_last_uid.txt",
                "Documents/dx_last_uid.txt",
                "ShadowTrackerExtra/Saved/dx_last_uid.txt"
            }
            for _, path in ipairs(ios_paths) do
                f = io.open(path, "r")
                if f then break end
            end
        else
            local pkg = GetPackageName()
            local path = string.format("/sdcard/Android/data/%s/files/dx_last_uid.txt", pkg)
            f = io.open(path, "r")
        end

        if f then
            local cached_uid = f:read("*a")
            f:close()
            if cached_uid then
                cached_uid = string.gsub(cached_uid, "%s+", "")
                if cached_uid ~= "" and cached_uid ~= "0" then
                    uid = cached_uid
                end
            end
        end
    end)
    -- 2. If not found, try getting it via DataCache, ProfileController, or GameplayData (if already initialized)
    if uid == "UNKNOWN" then
        pcall(function()
            local DataCache = package.loaded["DataCache"] or _G.DataCache
            if DataCache and DataCache.GetMyUID then
                local u = tostring(DataCache.GetMyUID())
                if u and u ~= "" and u ~= "0" then uid = u end
            end
        end)
    end
    if uid == "UNKNOWN" then
        pcall(function()
            local ProfileController = package.loaded["ProfileController"] or _G.ProfileController
            if ProfileController and ProfileController.GetMyUID then
                local u = tostring(ProfileController.GetMyUID())
                if u and u ~= "" and u ~= "0" then uid = u end
            end
        end)
    end
    if uid == "UNKNOWN" then
        pcall(function()
            local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
            local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
            if LocalPlayer then
                local u = tostring(LocalPlayer.PlayerUID or LocalPlayer.UID or LocalPlayer.uID or "")
                if u and u ~= "" and u ~= "0" then uid = u end
            end
        end)
    end
    -- 3. If still unknown, fall back to hardware Device ID
    if uid == "UNKNOWN" then
        pcall(function()
            local S = import("KismetSystemLibrary")
            if S and S.GetDeviceId then
                uid = tostring(S.GetDeviceId())
            end
        end)
    end
    return uid
end

-- Vòng lặp kiểm tra bản quyền định kỳ
local function DX_CheckUIDWithAdminVPS()
    local uid = _G.DX_CachedUID or GetHardwareDeviceID() or GetDeviceUID()
    if not uid or uid == "UNKNOWN" or uid == "" then return end

    local ModuleManager = package.loaded["client.module_framework.ModuleManager"] or require("client.module_framework.ModuleManager")
    if not ModuleManager then return end

    local http_manager = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
    if not http_manager then return end

    local url = DX_API_BASE .. "/api/check"
    local post_header = { ["Content-Type"] = "application/json" }
    local post_content = string.format('{"uid":"%s"}', uid)

    http_manager:Post(url, post_header, post_content, "", function(success, data)
        if success and data and #data > 0 then
            local resLower = string.lower(data)
            
            -- Kiểm tra xem phản hồi có phải là JSON hợp lệ từ server hay không
            local isResponseValid = (resLower:match('"active"%s*:') ~= nil or resLower:match('"status"%s*:') ~= nil)
            if not isResponseValid then
                -- Nếu không phải JSON hợp lệ (ví dụ: Nginx 502/504 HTML), bỏ qua để tránh khóa nhầm khi mạng lag/server restart
                return
            end

            local active = (resLower:match('"active"%s*:%s*true') ~= nil)
            local expires_at = data:match('"expires_at"%s*:%s*"([^"]+)"') or data:match('"expiresAt"%s*:%s*"([^"]+)"')
            if expires_at then
                _G.DX_ExpiresAt = expires_at
            elseif data:match('"expires_at"%s*:%s*null') then
                _G.DX_ExpiresAt = nil
            end
            
            if not active then
                _G.DX_PayloadExpired = true
                _G.DX_GetVal = function(id) return 0 end
                
                if not _G.DX_HasShownExpiredNotice then
                    _G.DX_HasShownExpiredNotice = true
                    pcall(function()
                        local msgBox = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
                        if msgBox and msgBox.Show then
                            msgBox.Show(1, "BẢN QUYỀN HẾT HẠN", "Bản quyền Mod Menu đã hết hạn hoặc bị thu hồi.\nVui lòng gia hạn hoặc liên hệ Admin.", function() end, function() end, "ĐÓNG", "ĐÓNG")
                        end
                    end)
                end
            else
                _G.DX_PayloadExpired = false
                _G.DX_GetVal = function(id) return _G.DX_Settings[id] or 0 end
            end
        end
    end)
end

local function StartDXCheckLoop()
    local function CheckLoop()
        pcall(DX_CheckUIDWithAdminVPS)
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(60.0, CheckLoop)
        end
    end
    CheckLoop()
end





-- ==============================================================================
-- PHẦN CRASH & ERROR LOGGER TỰ ĐỘNG LƯU FILE VÀ NẠP VỀ SERVER DÀNH CHO DEBUGS
-- ==============================================================================
_G.DX_CrashLogPath = nil

-- ── Log Buffer: gom log, gửi HTTP batch mỗi 60 giây thay vì mỗi lần ──────────
local _logBuffer        = {}        -- hàng đợi các message chờ gửi
local _logBufferSize    = 0         -- đếm số ký tự tránh quá lớn
local _LOG_FLUSH_SEC    = 60        -- gửi batch mỗi 60 giây
local _LOG_MAX_CHARS    = 8000      -- giới hạn payload tối đa/batch
local _logFlushRunning  = false

local function _FlushLogBuffer()
    if _logBufferSize == 0 then return end

    local batch = table.concat(_logBuffer, "")
    _logBuffer     = {}
    _logBufferSize = 0

    pcall(function()
        local uid = _G.DX_CachedUID or GetHardwareDeviceID() or "UNKNOWN"
        local ModuleManager = package.loaded["client.module_framework.ModuleManager"]
                           or (type(require) == "function" and require("client.module_framework.ModuleManager"))
        if ModuleManager and ModuleManager.GetModule then
            local http_manager = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
            if http_manager and http_manager.Post then
                local url = DX_API_BASE .. "/api/report_log"
                local post_header = { ["Content-Type"] = "application/json" }
                -- Escape batch string để đặt vào JSON
                local escaped = tostring(batch):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '')
                local post_content = string.format('{"uid":"%s","message":"%s"}', uid, escaped)
                http_manager:Post(url, post_header, post_content, "", function() end)
            end
        end
    end)
end

local function _StartLogFlushLoop()
    if _logFlushRunning then return end
    _logFlushRunning = true
    local function FlushTick()
        pcall(_FlushLogBuffer)
        pcall(function()
            local okTicker, ticker = pcall(require, "common.time_ticker")
            if okTicker and ticker and ticker.AddTimerOnce then
                ticker.AddTimerOnce(_LOG_FLUSH_SEC, FlushTick)
            end
        end)
    end
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(_LOG_FLUSH_SEC, FlushTick)
        end
    end)
end

_G.DX_WriteLogMessage = function(msg)
    pcall(function()
        local timeStr = os.date("%Y-%m-%d %H:%M:%S") or tostring(os.clock())
        local formatted = string.format("[%s] %s\n", timeStr, tostring(msg))
        print(formatted)

        -- Ghi file local trên điện thoại (không ảnh hưởng VPS)
        local targetFiles = {"dx_crashlog.txt"}
        for _, fileName in ipairs(targetFiles) do
            local candidate_paths = GetConfigPaths and GetConfigPaths(fileName) or {}

            pcall(function()
                local SystemLib = import("KismetSystemLibrary")
                if SystemLib and SystemLib.GetProjectSavedDirectory then
                    local savedDir = tostring(SystemLib.GetProjectSavedDirectory())
                    if savedDir and savedDir ~= "" then
                        table.insert(candidate_paths, 1, savedDir .. "Paks/" .. fileName)
                        table.insert(candidate_paths, 2, savedDir .. fileName)
                    end
                end
            end)

            table.insert(candidate_paths, "ShadowTrackerExtra/Saved/Paks/" .. fileName)
            table.insert(candidate_paths, "Saved/Paks/" .. fileName)
            table.insert(candidate_paths, "Paks/" .. fileName)
            table.insert(candidate_paths, fileName)

            for _, p in ipairs(candidate_paths) do
                local f = io.open(p, "a+")
                if f then
                    f:write(formatted)
                    f:close()
                    _G.DX_CrashLogPath = p
                    break
                end
            end
        end

        -- ── Gửi về VPS: gom vào buffer, KHÔNG gửi ngay ──────────────
        -- Nếu là CRASH hoặc ERROR → gửi ngay lập tức (không buffer)
        local isCritical = tostring(msg):find("%[CRASH") or tostring(msg):find("%[ERROR")
        if isCritical then
            pcall(function()
                local uid = _G.DX_CachedUID or GetHardwareDeviceID() or "UNKNOWN"
                local ModuleManager = package.loaded["client.module_framework.ModuleManager"]
                               or (type(require) == "function" and require("client.module_framework.ModuleManager"))
                if ModuleManager and ModuleManager.GetModule then
                    local http_manager = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
                    if http_manager and http_manager.Post then
                        local url = DX_API_BASE .. "/api/report_log"
                        local post_header = { ["Content-Type"] = "application/json" }
                        local post_content = string.format('{"uid":"%s","message":%q}', uid, tostring(msg))
                        http_manager:Post(url, post_header, post_content, "", function() end)
                    end
                end
            end)
        else
            -- Gom vào buffer, trim nếu quá lớn
            if _logBufferSize < _LOG_MAX_CHARS then
                table.insert(_logBuffer, formatted)
                _logBufferSize = _logBufferSize + #formatted
            end
            -- Đảm bảo flush loop đang chạy
            _StartLogFlushLoop()
        end
    end)
end


_G.DX_LogCrash = function(err)
    local trace = debug.traceback("", 2) or ""
    local logMsg = string.format("[CRASH/ERROR] %s\nTraceback:\n%s\n----------------------------------------", tostring(err), tostring(trace))
    _G.DX_WriteLogMessage(logMsg)
    return err
end

-- Đo thời gian thực thi của các hàm chính để phát hiện phần gây lag (Performance Profiler)
_G.DX_MeasurePerf = function(funcName, fn)
    local startTime = os.clock()
    local ok, res = pcall(fn)
    local elapsedMs = (os.clock() - startTime) * 1000
    if elapsedMs > 33.0 then -- Cảnh báo nếu hàm chạy quá 33ms (gây tụt FPS dưới 30fps)
        _G.DX_WriteLogMessage(string.format("[PERF SPIKE WARN] %s took %.2f ms (Potential Lag Source)", funcName, elapsedMs))
    end
    return ok, res
end

_G.DX_SafeRun = function(fn, ...)
    local args = {...}
    local ok, res = xpcall(function() return fn(table.unpack(args)) end, _G.DX_LogCrash)
    if ok then return res end
    return nil
end

local TssSdk_LastScanTime = 0
local function TssSdk_RecordScan()
    TssSdk_LastScanTime = os.clock()
end

-- =========================== PHẦN 1: UGC MOD VALIDATOR BYPASS ===========================
local function InitializeUGCModValidatorBypass()
    pcall(function()
        local UGCModValidator = package.loaded["client.slua.logic.ugc.UGCModValidator"]
        if UGCModValidator then
            if UGCModValidator.ValidateMod then UGCModValidator.ValidateMod = function() return true end end
            if UGCModValidator.CheckModSafety then UGCModValidator.CheckModSafety = function() return true end end
            if UGCModValidator.ReportInvalid then UGCModValidator.ReportInvalid = function() end end
        end
    end)
end

-- =========================== PHẦN 2: PAK FILE MANAGER BYPASS ===========================
local function InitializePakFileManagerBypass()
    pcall(function()
        local PakFileMgr = package.loaded["PakFileManager"] or _G.PakFileManager
        if PakFileMgr then
            if PakFileMgr.VerifySignature then PakFileMgr.VerifySignature = function() return true end end
            if PakFileMgr.CheckFileIntegrity then PakFileMgr.CheckFileIntegrity = function() return true end end
        end
    end)
end

-- =========================== PHẦN 3: HAWKEYE ANTI-CHEAT BYPASS ===========================
local function InitializeHawkEyeBypass()
    pcall(function()
        local HawkEye = package.loaded["GameLua.Mod.BaseMod.Common.Security.HawkEye"] or
                        package.loaded["GameLua.Mod.BaseMod.Client.Security.HawkEye"]
        if HawkEye then
            if HawkEye.Report then HawkEye.Report = function() end end
            if HawkEye.ReportCheat then HawkEye.ReportCheat = function() end end
            if HawkEye.OnDetected then HawkEye.OnDetected = function() end end
            if HawkEye.StartPatrol then HawkEye.StartPatrol = function() end end
            if HawkEye.SendPatrolLog then HawkEye.SendPatrolLog = function() end end
        end
        
        local AntiCheatReporter = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientAntiCheatReporter"]
        if AntiCheatReporter then
            if AntiCheatReporter.Report then AntiCheatReporter.Report = function() end end
            if AntiCheatReporter.ReportDetection then AntiCheatReporter.ReportDetection = function() end end
            if AntiCheatReporter.SendReport then AntiCheatReporter.SendReport = function() end end
        end
    end)
end

-- =========================== PHẦN 4: SECURITY SUBSYSTEM BYPASS (VIP DYNAMIC SCAN) ===========================
local function InitializeSecuritySubsystemBypass()
    pcall(function()
        local subs = {
            "GameLua.Mod.BaseMod.Common.Security.SecuritySubsystem",
            "GameLua.Mod.BaseMod.Client.Security.ClientSecuritySubsystem",
            "GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem",
            "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"
        }
        for _, path in ipairs(subs) do
            local sub = package.loaded[path] or _G[path]
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" then
                        local lk = string.lower(k)
                        if lk:find("report") or lk:find("scan") or lk:find("detect") or lk:find("check") or 
                           lk:find("verify") or lk:find("ban") or lk:find("kick") or lk:find("collect") or 
                           lk:find("upload") or lk:find("event") or lk:find("action") then
                            pcall(function() sub[k] = function() return false end end)
                        end
                    end
                end
            end
        end
    end)
end
-- =========================== PHẦN 5: SKIN BYPASS ===========================
local function InitializeSkinBypass()
    pcall(function()
        local puffer_tlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if puffer_tlog then
            if puffer_tlog.ReportEvent then puffer_tlog.ReportEvent = function() end end
            if puffer_tlog.ReportDownloadResult then puffer_tlog.ReportDownloadResult = function() end end
            if puffer_tlog.ReportODPTDError then puffer_tlog.ReportODPTDError = function() end end
        end
        
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            if AvatarUtils.CheckIsWeaponInBlackList then AvatarUtils.CheckIsWeaponInBlackList = function() return false end end
            if AvatarUtils.IsValidAvatar then AvatarUtils.IsValidAvatar = function() return true end end
        end
        
        local equipmentException = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if equipmentException then
            if equipmentException.Report then equipmentException.Report = function() end end
        end
    end)
end

-- [XÓA BỎ PHẦN 6 AUTO HEAD HOOKS THEO YÊU CẦU]
-- =========================== PHẦN 7: CLIENT TLOG UTIL BYPASS ===========================
local function InitializeClientTLogUtilBypass()
    pcall(function()
        local ClientTLogUtil = package.loaded["GameLua.Mod.BaseMod.Client.ClientTLog.ClientTLogUtil"]
        if ClientTLogUtil then
            if ClientTLogUtil.ReportGeneralCountByBRPhase then ClientTLogUtil.ReportGeneralCountByBRPhase = function() end end
            if ClientTLogUtil.ReportCommonTLogDataByBRPhase then ClientTLogUtil.ReportCommonTLogDataByBRPhase = function() end end
            if ClientTLogUtil.ReportBattleResult then ClientTLogUtil.ReportBattleResult = function() end end
            if ClientTLogUtil.ReportBRGamePhaseChange then ClientTLogUtil.ReportBRGamePhaseChange = function() end end
        end
    end)
end

-- =========================== PHẦN 8: STEXTRA BLUEPRINT FUNCTION LIBRARY BYPASS ===========================
local function InitializeSTExtraBPLibraryBypass()
    pcall(function()
        local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
        if STExtraBlueprintFunctionLibrary then
            if STExtraBlueprintFunctionLibrary.CheckSHA1 then 
                STExtraBlueprintFunctionLibrary.CheckSHA1 = function() return true end 
            end
            if STExtraBlueprintFunctionLibrary.VerifyAssetIntegrity then 
                STExtraBlueprintFunctionLibrary.VerifyAssetIntegrity = function() return true end 
            end
            if STExtraBlueprintFunctionLibrary.CheckMD5 then 
                STExtraBlueprintFunctionLibrary.CheckMD5 = function() return true end 
            end
            if STExtraBlueprintFunctionLibrary.GetMD5 then 
                STExtraBlueprintFunctionLibrary.GetMD5 = function() return "BYPASS" end 
            end
            STExtraBlueprintFunctionLibrary.IsDevelopment = function() return false end
        end
    end)
end

-- =========================== PHẦN 9: SHA256 HASH BYPASS ===========================
local function InitializeSHA256Bypass()
    pcall(function()
        if _G.SHA256Hash then 
            _G.SHA256Hash = function() return "0000000000000000000000000000000000000000000000000000000000000000" end 
        end
        if _G.SHA1Hash then 
            _G.SHA1Hash = function() return "0000000000000000000000000000000000000000" end 
        end
    end)
end

-- =========================== PHẦN 10: TSSSDK NÂNG CAO BYPASS (VIP DYNAMIC SCAN) ===========================
local function InitializeTssSdkAdvancedBypass()
    pcall(function()
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local tss_funcs = {
                "ReportCheatData", "ReportInfo", "ReportHackAttack", "ReportEnvironment",
                "SendCmd", "SendCmdEx", "SetValue", "GetValue", "TuringGetFeature",
                "AntiSpeedHack", "VerifyFile", "QueryUserRisk", "GetDeviceRisk",
                "ScanProcess", "CheckGameIntegrity", "ScanMemory", "VerifyProcess",
                "CheckEnvironment", "GetTssSdkReportInfo", "SetCmdEx", "SetKeyValue",
                "GetDeviceRiskEx", "ReportCheatDataEx", "ReportEvent"
            }
            for _, f in ipairs(tss_funcs) do
                if TssSdk[f] then
                    local t = type(TssSdk[f])
                    if t == "function" then
                        pcall(function()
                            if f:find("Risk") or f:find("GetValue") then
                                TssSdk[f] = function() TssSdk_RecordScan(); return 0 end
                            elseif f:find("Check") or f:find("Verify") or f:find("Scan") or f:find("AntiSpeed") or f:find("Process") then
                                TssSdk[f] = function() TssSdk_RecordScan(); return true end
                            elseif f:find("Feature") or f:find("Info") then
                                TssSdk[f] = function() TssSdk_RecordScan(); return "" end
                            else
                                TssSdk[f] = function() TssSdk_RecordScan() end
                            end
                        end)
                    end
                end
            end
            
            -- Hook OnRecvData
            if not TssSdk._OnRecvDataHooked then
                local originalOnRecvData = TssSdk.OnRecvData
                TssSdk.OnRecvData = function(data)
                    if type(data) == "string" and (string.find(data, "report", 1, true) or string.find(data, "exception", 1, true) or string.find(data, "cheat", 1, true) or string.find(data, "violation", 1, true) or string.find(data, "hack", 1, true) or string.find(data, "verify", 1, true)) then
                        return
                    end
                    if originalOnRecvData then originalOnRecvData(data) end
                end
                TssSdk._OnRecvDataHooked = true
            end
        end
    end)
end
-- =========================== PHẦN 11: CONNECTION GUARD MỞ RỘNG ===========================
local function InitializeConnectionGuardExtended()
    pcall(function()
        if not _G.GameplayCallbacks then return end
        local GC = _G.GameplayCallbacks
        
        local EXTENDED_BLOCKED_STATES = {
            ["cheatdetected"] = true, ["cheat_detected"] = true,
            ["connectionlost"] = true, ["connection_lost"] = true,
            ["connectiontimeout"] = true, ["connection_timeout"] = true,
            ["connectionexception"] = true, ["connection_exception"] = true,
            ["netdrivererror"] = true, ["net_driver_error"] = true,
            ["banned"] = true, ["account_banned"] = true,
            ["kicked"] = true, ["player_kicked"] = true,
            ["suspended"] = true, ["account_suspended"] = true,
            ["violationdetected"] = true, ["violation_detected"] = true,
            ["integrityfailure"] = true, ["integrity_failure"] = true,
            ["hackdetected"] = true, ["hack_detected"] = true,
            ["moddingdetected"] = true, ["modding_detected"] = true,
            ["memoryhack"] = true, ["speedhack"] = true,
            ["wallhack"] = true, ["aimbot"] = true,
            ["abnormalbehavior"] = true, ["anticheat"] = true,
        }
        
        if GC.OnDSPlayerStateChanged and not GC._ExtendedHooked then
            local originalDSPlayerState = GC.OnDSPlayerStateChanged
            GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
                local stateStr = InPlayerState and string.lower(tostring(InPlayerState)) or ""
                if EXTENDED_BLOCKED_STATES[stateStr] then return end
                if string.find(stateStr, "cheat", 1, true) or string.find(stateStr, "hack", 1, true) or
                   string.find(stateStr, "ban", 1, true) or string.find(stateStr, "kick", 1, true) or
                   string.find(stateStr, "violation", 1, true) or string.find(stateStr, "detect", 1, true) then
                    return
                end
                if originalDSPlayerState then
                    pcall(originalDSPlayerState, UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
                end
            end
            GC._ExtendedHooked = true
        end
        
        if GC.OnPlayerViolationDetected then GC.OnPlayerViolationDetected = function() end end
        if GC.OnPlayerBanned then GC.OnPlayerBanned = function() end end
        if GC.OnPlayerKicked then GC.OnPlayerKicked = function() end end
        if GC.OnAntiCheatTriggered then GC.OnAntiCheatTriggered = function() end end
        if GC.OnForceDisconnect then GC.OnForceDisconnect = function() end end
        if GC.OnServerKickPlayer then GC.OnServerKickPlayer = function() end end
        if GC.OnPlayerReportConfirmed then GC.OnPlayerReportConfirmed = function() end end
        if GC.OnPlayerNetConnectionClosed then GC.OnPlayerNetConnectionClosed = function() end end
        if GC.OnPlayerActorChannelError then GC.OnPlayerActorChannelError = function() end end
        if GC.OnPlayerRPCValidateFailed then GC.OnPlayerRPCValidateFailed = function() end end
        if GC.OnPlayerSpectateException then GC.OnPlayerSpectateException = function() end end
        if GC.OnShutdownAfterError then GC.OnShutdownAfterError = function() end end
    end)
end

-- =========================== PHẦN 12: BỔ SUNG SUBSYSTEM CÒN THIẾU ===========================
local function InitializeMissingSubsystems()
    pcall(function()
        local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubsystemMgr then
            local missingSubsystems = {
                "FileCheckSubsystem",
                "IntegrityCheckSubsystem",
                "AntiCheatSubsystem",
                "CheatDetectSubsystem",
                "SecurityScanSubsystem",
                "TSSAntiCheatSubsystem",
                "HawkEyeSubsystem",
                "GameSafeSubsystem",
                "SecTgameSubsystem",
                "AFKReportorSubsystem",
                "ClientDataStatistcsSubsystem",
                "AvatarExceptionSubsystem",
                "ShootVerifySubSystemClient",
                "MemoryCheckSubsystem",
                "SpeedCheckSubsystem",
                "WallCheckSubsystem",
                "BehaviorScoreSubsystem",
                "CoronaLabSubsystem",
                "PlayerSecurityInfoSubsystem",
                "ClientCircleFlowSubsystem",
                "ModifierExceptionSubsystem",
                "SimulateCharacterSubsystem",
                "GameReportSubsystem",
                "ClientSecMrpcsFlowSubsystem",
                "SwiftHawkSubsystem",
                "MD5CheckSubsystem",
                "PakVerifySubsystem"
            }
            
            for _, name in ipairs(missingSubsystems) do
                local sub = SubsystemMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" then
                            local lk = string.lower(k)
                            if string.find(lk, "report", 1, true) or string.find(lk, "check", 1, true) or
                               string.find(lk, "scan", 1, true) or string.find(lk, "detect", 1, true) or
                               string.find(lk, "verify", 1, true) or string.find(lk, "exception", 1, true) or
                               string.find(lk, "collect", 1, true) or string.find(lk, "flow", 1, true) or
                               string.find(lk, "hack", 1, true) then
                                sub[k] = function() end
                            end
                        end
                    end
                    if sub.StartCheck then sub.StartCheck = function() end end
                    if sub.StopCheck then sub.StopCheck = function() end end
                    if sub.ReportViolation then sub.ReportViolation = function() end end
                end
            end
        end
        
        -- Hook require để triệt tiêu các module bảo mật
        local origReq = require
        if origReq and not _G.RequireHooked then
            _G.require = function(m)
                local blocked = {
                    -- AntiCheat core modules
                    ["HiggsBosonComponent"] = true,
                    ["PlayerSecurityInfoSubsystem"] = true,
                    ["CoronaLabSubsystem"] = true,
                    ["ClientCircleFlowSubsystem"] = true,
                    ["ModifierExceptionSubsystem"] = true,
                    ["ShootVerifySubSystemClient"] = true,
                    ["ShootVerifySubSystemDS"] = true,
                    ["ClientReportPlayerSubsystem"] = true,
                    ["DSReportPlayerSubsystem"] = true,
                    ["ClientHawkEyePatrolSubsystem"] = true,
                    ["DSHawkEyePatrolSubsystem"] = true,
                    ["BehaviorScoreSubsystem"] = true,
                    ["SwiftHawkSubsystem"] = true,
                    ["ClientSwiftHawk"] = true,
                    ["ClientSecMrpcsFlowSubsystem"] = true,
                    ["SimulateCharacterSubsystem"] = true,
                    ["MD5CheckSubsystem"] = true,
                    ["PakVerifySubsystem"] = true,
                    -- Ban / punishment modules
                    ["IDIPBanSubsystem"] = true,
                    ["ClientBanSubsystem"] = true,
                    ["DSBanSubsystem"] = true,
                    ["BanCheckSubsystem"] = true,
                    ["PunishmentSubsystem"] = true,
                    ["AntiCheatPunishSubsystem"] = true,
                    ["ClientPunishSubsystem"] = true,
                    ["ReportPlayerPunishSubsystem"] = true,
                    ["GameSafePunishSubsystem"] = true,
                    ["AbnormalBehaviorSubsystem"] = true,
                    ["ClientKickSubsystem"] = true,
                    ["DSKickSubsystem"] = true,
                }
                for b in pairs(blocked) do
                    if string.find(m, b, 1, true) then
                        return {}
                    end
                end
                
                local res = origReq(m)
                
                if m == "client.slua.logic.ugc.UGCModValidator" then
                    pcall(function()
                        res.ValidateMod = function() return true end
                        res.CheckModSafety = function() return true end
                        res.ReportInvalid = function() end
                    end)
                elseif m == "PakFileManager" then
                    pcall(function()
                        res.VerifySignature = function() return true end
                        res.CheckFileIntegrity = function() return true end
                    end)
                elseif m:find("Security.HawkEye", 1, true) or m:find("ClientAntiCheatReporter", 1, true) then
                    pcall(function()
                        res.Report = function() end
                        res.ReportCheat = function() end
                        res.OnDetected = function() end
                        res.StartPatrol = function() end
                        res.SendPatrolLog = function() end
                        res.ReportDetection = function() end
                        res.SendReport = function() end
                    end)
                elseif m:find("Ban", 1, true) or m:find("Punish", 1, true) or m:find("IDIP", 1, true) then
                    -- Patch bất kỳ module nào liên quan đến ban/punishment
                    pcall(function()
                        if type(res) == "table" then
                            for k, v in pairs(res) do
                                if type(v) == "function" then
                                    local lk = string.lower(k)
                                    if string.find(lk,"ban",1,true) or string.find(lk,"punish",1,true)
                                    or string.find(lk,"kick",1,true) or string.find(lk,"report",1,true)
                                    or string.find(lk,"check",1,true) or string.find(lk,"notify",1,true) then
                                        res[k] = function() return false end
                                    end
                                end
                            end
                        end
                    end)
                end
                
                return res
            end
            _G.RequireHooked = true
        end
    end)
end

-- =========================== PHẦN 13: FPS UNLOCK ===========================
local function InitializeFPSUnlock()
    pcall(function()
        local logic_setting_graphics = package.loaded["client.slua.logic.setting.logic_setting_graphics"] or require("client.slua.logic.setting.logic_setting_graphics")
        local GSC_FPS = package.loaded["client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS"] or require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local GSC_FPSFT = package.loaded["client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT"] or require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        local GraphicSettingDB = package.loaded["client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB"] or require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")

        if logic_setting_graphics then
            local originalSetFPS = logic_setting_graphics.SetFPS
            function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
                if FPSLevel == 8 and GraphicSettingDB then
                    local fpsSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                    if not fpsSwitch then 
                        GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneSwitch, true) 
                    end
                end
                if originalSetFPS then 
                    originalSetFPS(gameInstance, FPSLevel) 
                end
                if FPSLevel == 8 and GraphicSettingDB then
                    GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, 165)
                    gameInstance:ExecuteCMD("t.MaxFPS", "165")
                    gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end

        if GSC_FPS and GSC_FPS.__inner_impl then
            local fpsImpl = GSC_FPS.__inner_impl
            function fpsImpl:GetMaxFPSLevel() return 8, 8 end
            function fpsImpl:CanChangeQualityAndFPSPreCheck() return true end
            function fpsImpl:InitRealSupportFPS()
                local supportFPS = {}
                for i = 1, 8 do supportFPS[i] = {true, true} end
                if GraphicSettingDB then GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, supportFPS, false) end
                return supportFPS
            end
            function fpsImpl:SetFPSAndQualityEnable(bEnable)
                if self.UIRoot and self.UIRoot.Image_Mask then self:SetWidgetVisible(self.UIRoot.Image_Mask, false) end
            end
            function fpsImpl:UpdateSelectedFPSState(selectedLevel)
                local fpsNodes = { [2]="NodeFps20", [3]="NodeFps25", [4]="NodeFps30", [5]="NodeFps40", [6]="NodeFps60", [7]="NodeFps90", [8]="NodeFps120" }
                if not self.UIRoot then return end
                for level, name in pairs(fpsNodes) do
                    if self.UIRoot[name] then
                        self:WidgetSelfHit(self.UIRoot[name])
                        self.UIRoot[name]:SetIsEnabled(true)
                        local widgetSwitcher = self.UIRoot["WidgetSwitcher_" .. level]
                        if widgetSwitcher then widgetSwitcher:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) end
                    end
                end
            end
            local originalUpdateUI = fpsImpl.UpdateUI
            function fpsImpl:UpdateUI()
                if originalUpdateUI then pcall(originalUpdateUI, self) end
                self:SelfHitTestInvisible()
                self:InitRealSupportFPS()
                self:SetFPSAndQualityEnable(true)
                local currentFPSLevel = 8
                if GraphicSettingDB then
                    if GraphicSettingDB:GetUIData(GraphicSettingDB.CustomTab) == 2 then
                        currentFPSLevel = GraphicSettingDB:GetUIData(GraphicSettingDB.LobbyFPS) or 8
                    else
                        currentFPSLevel = GraphicSettingDB:GetUIData(GraphicSettingDB.SelectedFPS) or 8
                    end
                end
                self:UpdateSelectedFPSState(currentFPSLevel)
            end
            function fpsImpl:DoClickFPS(FPSLevel)
                if slua.isValid(self.UIRoot) then
                    if GraphicSettingDB:GetUIData(GraphicSettingDB.CustomTab) == 2 then
                        GraphicSettingDB:UpdateUIData(GraphicSettingDB.LobbyFPS, FPSLevel)
                    else
                        GraphicSettingDB:UpdateSelectedFPS(FPSLevel)
                    end
                    self:UpdateSelectedFPSState(FPSLevel)
                    if self:GetParentUI() then 
                        self:GetParentUI():SaveQualityAndFPS()
                        self:GetParentUI():SetDirty(true) 
                    end
                end
            end
        end

        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            local fpsftImpl = GSC_FPSFT.__inner_impl
            local minFPS, fpsStep = 90, 5
            local function clampFPS(val, min, max) return val < min and min or (val > max and max or val) end
            function fpsftImpl:ShowOrHide() 
                self:SelfHitTestInvisible() 
                if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end 
            end
            function fpsftImpl:InitFPSFTSwitch()
                local sw = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(sw, true) end
                if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, sw) end
                if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
            end
            function fpsftImpl:InitFPSFTValue165()
                local uiRoot = self.UIRoot
                local sw = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                local currentFPS = sw and GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
                uiRoot.Slider_screen3:SetLocked(not sw)
                uiRoot.ProgressBar_screen3:SetFillColorAndOpacity(sw and FLinearColor(1,1,1,1) or FLinearColor(1,0.625,0.6,1))
                local percent = (currentFPS - minFPS) / (165 - minFPS)
                uiRoot.Veihclescreen3:SetText(LocUtil.LocalizeResFormat(10567, currentFPS))
                uiRoot.Slider_screen3:SetValue(percent)
                uiRoot.ProgressBar_screen3:SetPercent(percent)
            end
            function fpsftImpl:OnFPSFTValueChange3(currentFPS)
                GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, currentFPS)
                self:InitFPSFTValue165()
                if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
                local gameInstance = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
                if gameInstance then 
                    gameInstance:ExecuteCMD("t.MaxFPS", tostring(currentFPS))
                    gameInstance:ExecuteCMD("r.FrameRateLimit", tostring(currentFPS)) 
                end
            end
            function fpsftImpl:OnFPSFTSliderValueChange3(sliderVal)
                if GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) then
                    local currentFPS = KismetMathLibrary.FCeil(sliderVal * (165 - minFPS) / fpsStep) * fpsStep + minFPS
                    self:OnFPSFTValueChange3(clampFPS(currentFPS, minFPS, 165))
                end
            end
            function fpsftImpl:OnFPSFTAdd3()
                local currentFPS = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum)
                if currentFPS then self:OnFPSFTValueChange3(math.min(165, currentFPS + fpsStep)) end
            end
            function fpsftImpl:OnFPSFTMinus3()
                local currentFPS = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum)
                if currentFPS then self:OnFPSFTValueChange3(math.max(minFPS, currentFPS - fpsStep)) end
            end
            fpsftImpl.OnFPSFTAdd = fpsftImpl.OnFPSFTAdd3 
            fpsftImpl.OnFPSFTMinus = fpsftImpl.OnFPSFTMinus3
            fpsftImpl.OnFPSFTSliderValueChange = fpsftImpl.OnFPSFTSliderValueChange3
        end
    end)
end

local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

-- =========================== PHẦN 14: SLUA & JIT BYPASS NÂNG CẤP ===========================
local function InitializeSLUABypass()
    pcall(function()
        if slua then
            if slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
            if slua.checkSignature then slua.checkSignature = function() return true end end
            if slua.verifySignature then slua.verifySignature = function() return true end end
            if slua.isProtected then slua.isProtected = function() return false end end
            if slua.isHooked then slua.isHooked = function() return false end end
        end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            if loader.verifyBytecode then loader.verifyBytecode = function() return true end end
            if loader.checkIntegrity then loader.checkIntegrity = function() return true end end
            if loader.verifyHash then loader.verifyHash = function() return true end end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then
            if slua_serialize.check then slua_serialize.check = function() return true end end
            if slua_serialize.verify then slua_serialize.verify = function() return true end end
        end
        if jit then
            if jit.attach then jit.attach(function() end, "bc") end
            if jit.off then pcall(jit.off) end
        end
        local STExtraLua = package.loaded["STExtraLua"] or _G.STExtraLua
        if STExtraLua then
            if STExtraLua.CheckProtection then STExtraLua.CheckProtection = function() return true end end
            if STExtraLua.VerifyEnvironment then STExtraLua.VerifyEnvironment = function() return true end end
            if STExtraLua.ReportAnomaly then STExtraLua.ReportAnomaly = function() end end
        end
    end)
end

-- =========================== PHẦN 15: MD5 & PAK SIGNATURE BYPASS NÂNG CẤP ===========================
local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "pak.RequireSignedPakFiles 0")
            console.ExecuteConsoleCommand(nil, "AllowEncryptedPakFiles 0")
        end
        local CreativeModeBlueprintLibrary = import("CreativeModeBlueprintLibrary")
        if CreativeModeBlueprintLibrary then
            CreativeModeBlueprintLibrary.MD5HashByteArray = function() return "BYPASSED_MD5_HASH" end
            CreativeModeBlueprintLibrary.MD5HashFile = function() return "BYPASSED_MD5_HASH" end
            CreativeModeBlueprintLibrary.GetContentDiffData = function() return true, "BYPASSED" end
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.SHA1Hash then _G.SHA1Hash = function() return "0000000000000000000000000000000000000000" end end
        if _G.SHA256Hash then _G.SHA256Hash = function() return "0000000000000000000000000000000000000000000000000000000000000000" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = function() return true end
            FileHashChecker.VerifyAll = function() return true end
            FileHashChecker.CheckFileIntegrity = function() return true end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            TssSdk.GetFileMD5 = function() return "BYPASS" end
            TssSdk.GetFileSHA1 = function() return "BYPASS" end
            TssSdk.ReportData = function() TssSdk_RecordScan() end
            TssSdk.ReportCheat = function() TssSdk_RecordScan() end
            TssSdk.SendCmd = function() TssSdk_RecordScan() end
            TssSdk.ScanMemory = function() TssSdk_RecordScan() return true end
            TssSdk.IsEmulator = function() return false end
            TssSdk.IsRooted = function() return false end
            TssSdk.IsDebugged = function() return false end
            TssSdk.CheckEnvironment = function() TssSdk_RecordScan() return true end
            TssSdk.VerifyFile = function() TssSdk_RecordScan() return true end
        end
        local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
        if STExtraBlueprintFunctionLibrary then
            if STExtraBlueprintFunctionLibrary.CheckMD5 then STExtraBlueprintFunctionLibrary.CheckMD5 = function() return true end end
            if STExtraBlueprintFunctionLibrary.GetMD5 then STExtraBlueprintFunctionLibrary.GetMD5 = function() return "BYPASS" end end
            if STExtraBlueprintFunctionLibrary.CheckSHA1 then STExtraBlueprintFunctionLibrary.CheckSHA1 = function() return true end end
            STExtraBlueprintFunctionLibrary.IsDevelopment = function() return false end
            if STExtraBlueprintFunctionLibrary.VerifyAssetIntegrity then
                STExtraBlueprintFunctionLibrary.VerifyAssetIntegrity = function() return true end
            end
        end
    end)
end

-- =========================== PHẦN 16: LOG & CRASH BLOCKER NÂNG CẤP ===========================
local function InitializeLogBlocker()
    pcall(function()
        local ScreenshotMTDer = import("ScreenshotMTDer")
        if ScreenshotMTDer then
            ScreenshotMTDer.MTDePicture = function() return "" end
            ScreenshotMTDer.ReMTDePicture = function() return "" end
            ScreenshotMTDer.HasCaptured = function() return true end
            ScreenshotMTDer.TakeScreenshot = function() end
            ScreenshotMTDer.SendScreenshot = function() end
        end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then
            TLog.Info = function() end; TLog.Warning = function() end
            TLog.Error = function() end; TLog.Debug = function() end; TLog.Report = function() end
            TLog.Send = function() end; TLog.Flush = function() end
        end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then
            CrashSight.ReportException = function() end
            CrashSight.ReportExceptionWithData = function() end
            CrashSight.ReportNativeException = function() end
            CrashSight.SetCustomData = function() end
            CrashSight.SetCustomKeyValue = function() end
            CrashSight.Log = function() end
            CrashSight.LogInfo = function() end
            CrashSight.LogError = function() end
            CrashSight.ReportError = function() end
            CrashSight.ReportEvent = function() end
            CrashSight.SetUserId = function() end
            CrashSight.SetTag = function() end
            CrashSight.SetDeviceId = function() end
            CrashSight.AppExit = function() end
            CrashSight.Abort = function() end
            CrashSight.ForceExit = function() end
            CrashSight.TriggerAbort = function() end
            CrashSight.SendCrashLog = function() end
            CrashSight.UploadCrashLog = function() end
            CrashSight.OnCrashDetected = function() end
        end
        local GameReportUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GameReportUtils then
            GameReportUtils.BugglyPostExceptionFull = function() return false end
            GameReportUtils.CheckCanBugglyPostException = function() return false end
            GameReportUtils.ReplayReportData = function() end
            GameReportUtils.ReportGameException = function() end
            GameReportUtils.SendExceptionReport = function() end
            GameReportUtils.BuildExceptionPacket = function() return nil end
        end
        local ClientToolsReport = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if ClientToolsReport then
            ClientToolsReport.SendReport = function() end
            ClientToolsReport.SendException = function() end
            ClientToolsReport.PushReport = function() end
        end
        local TLogReportUtils = package.loaded["client.slua.config.tlog.tlog_report_utils"]
        if TLogReportUtils then
            TLogReportUtils.ReportTLogEvent = function() end
            TLogReportUtils.SendTLogData = function() end
        end
        local UGCReport = package.loaded["client.slua.logic.ugc.UGCNewTLogReport"] or package.loaded["client.slua.data.BasicData.BasicDataTLogReport"]
        if UGCReport then
            UGCReport.SendExposeReq = function() end
            UGCReport.SendInteractionReq = function() end
            UGCReport.TLogReport = function() end
        end
        local logic_ugc_tlog = package.loaded["client.slua.logic.ugc.logic_ugc_tlog"]
        if logic_ugc_tlog then
            logic_ugc_tlog.SendModTLog = function() end
            logic_ugc_tlog.ReportStay = function() end
        end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "Amplitude", "Mixpanel", "Segment"}) do
            local s = _G[sdk]
            if s then
                s.logEvent = function() end
                s.trackEvent = function() end
                s.setEnabled = function() return false end
                s.flush = function() end
                s.identify = function() end
            end
        end
        if os then
            if os.abort then os.abort = function() end end
            if os.exit then
                local _orig_exit = os.exit
                os.exit = function(code, ...)
                    if code ~= 0 and code ~= nil and code ~= true then return end
                    _orig_exit(code, ...)
                end
            end
        end
        local CSOpMgr = package.loaded["GameLua.Mod.BaseMod.Common.Security.CSOperationManager"]
        if CSOpMgr then
            CSOpMgr.ReportOperation = function() end
            CSOpMgr.ReportException = function() end
            CSOpMgr.TriggerAbort = function() end
            CSOpMgr.Shutdown = function() end
            CSOpMgr.ForceCrash = function() end
        end
        local ACE = package.loaded["ACE"] or _G.ACE
        if ACE then
            ACE.Report = function() end
            ACE.ReportCheat = function() end
            ACE.Terminate = function() end
            ACE.GetStatus = function() return 0 end
            ACE.CheckEnvironment = function() return true end
        end
        local Bugly = package.loaded["Bugly"] or _G.Bugly
        if Bugly then
            Bugly.report = function() end
            Bugly.postException = function() end
            Bugly.putUserData = function() end
        end
    end)
end

-- =========================== PHẦN 17: SCANNER BLOCKER NÂNG CẤP ===========================
local function InitializeScannerBlocker()
    pcall(function()
        local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubsystemMgr then
            local subsystemsToDisable = {
                "AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem",
                "ShootVerifySubSystemClient", "ShootVerifySubSystemDS", "MemoryCheckSubsystem", "SpeedCheckSubsystem",
                "WallCheckSubsystem", "FileCheckSubsystem", "IntegrityCheckSubsystem",
                "AntiCheatSubsystem", "CheatDetectSubsystem", "SecurityScanSubsystem",
                "TSSAntiCheatSubsystem", "HawkEyeSubsystem", "GameSafeSubsystem", "SecTgameSubsystem",
                "SwiftHawkSubsystem", "CoronaLabSubsystem", "ClientSecMrpcsFlowSubsystem",
                "SimulateCharacterSubsystem", "MD5CheckSubsystem", "PakVerifySubsystem",
                "ClientCircleFlowSubsystem", "PlayerSecurityInfoSubsystem", "BehaviorScoreSubsystem"
            }
            for _, name in ipairs(subsystemsToDisable) do
                local sub = SubsystemMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" then
                            local lk = string.lower(k)
                            if string.find(lk, "report") or string.find(lk, "check") or
                               string.find(lk, "scan") or string.find(lk, "detect") or
                               string.find(lk, "hack") or string.find(lk, "verify") or
                               string.find(lk, "exception") or string.find(lk, "abort") then
                                sub[k] = function() end
                            end
                        end
                    end
                    if sub.ReportPingDelayTimer then
                        pcall(function() sub:RemoveGameTimer(sub.ReportPingDelayTimer) end)
                        sub.ReportPingDelayTimer = nil
                    end
                    if sub.ScanTimer then
                        pcall(function() sub:RemoveGameTimer(sub.ScanTimer) end)
                        sub.ScanTimer = nil
                    end
                    if sub.StartCheck then sub.StartCheck = function() end end
                    if sub.StopCheck then sub.StopCheck = function() end end
                    if sub.TickCheck then sub.TickCheck = function() end end
                end
            end
        end
        local AvatarExceptionPlayerInst = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvatarExceptionPlayerInst then
            AvatarExceptionPlayerInst.CheckAvatarException = function() end
            AvatarExceptionPlayerInst.CheckAvatarExceptionOnce = function() end
            AvatarExceptionPlayerInst.ReportAvatarException = function() end
            AvatarExceptionPlayerInst.CheckSlotMeshVisible = function() return false end
            AvatarExceptionPlayerInst.CheckPawnVisible = function() return false end
            AvatarExceptionPlayerInst.CheckCanBugglyPostException = function() return false end
            AvatarExceptionPlayerInst.OnAvatarExceptionDetected = function() end
        end
        local AvatarCheckerModule = package.loaded["blacklist.slua.logic.lobby_gm.AvatarCheckerModule"]
        if AvatarCheckerModule then
            AvatarCheckerModule.CheckAvatar = function() return true end
            AvatarCheckerModule.ReportException = function() end
        end
        local logic_memory_warning = package.loaded["client.slua.logic.memory_warning.logic_memory_warning"]
        if logic_memory_warning then
            logic_memory_warning.OnMemoryWarning = function() end
            logic_memory_warning.ReportMemoryWarning = function() end
        end
        local logic_store_game_interface = package.loaded["client.slua.logic.store.logic_store_game_interface"]
        if logic_store_game_interface then
            logic_store_game_interface.IsStoreGameSupported = function() return true end 
            logic_store_game_interface.NotifyGetPGSLoginInfo = function() end 
        end
        local VoiceChatSubsystem = package.loaded["GameLua.Mod.BaseMod.Client.Voice.VoiceChatSubsystem"]
        if VoiceChatSubsystem then
            VoiceChatSubsystem.OnPlayerSubmitComplaint = function() end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local originalOnRecvData = TssSdk.OnRecvData
            TssSdk.OnRecvData = function(data)
                if type(data) == "string" and (string.find(data, "report") or string.find(data, "exception")) then
                    return
                end
                if originalOnRecvData then originalOnRecvData(data) end
            end
            TssSdk.SendReportInfo = function() TssSdk_RecordScan() end
            TssSdk.ScanMemory = function() TssSdk_RecordScan() return true end
            TssSdk.IsEmulator = function() return false end
            TssSdk.IsRooted = function() return false end
            TssSdk.IsDebugged = function() return false end
            TssSdk.GetTssSdkReportInfo = function() return "" end
            TssSdk.GetDeviceRisk = function() return 0 end
            TssSdk.ScanProcess = function() TssSdk_RecordScan() return true end
            TssSdk.CheckGameIntegrity = function() TssSdk_RecordScan() return true end
        end
        local CreativeModeBlueprintLibrary = import("CreativeModeBlueprintLibrary")
        if CreativeModeBlueprintLibrary then
            CreativeModeBlueprintLibrary.MD5HashByteArray = function() return "BYPASSED_MD5_HASH" end
            CreativeModeBlueprintLibrary.GetContentDiffData = function() return true, "BYPASSED" end
            CreativeModeBlueprintLibrary.VerifyFileSignature = function() return true end
        end
    end)
end

-- =========================== PHẦN 18: REPLAY TELEMETRY BLOCKER ===========================
local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        local RescueBtnReplayTraceSubsystem = SubsystemMgr and SubsystemMgr:Get("RescueBtnReplayTraceSubsystem")
        if RescueBtnReplayTraceSubsystem then
            RescueBtnReplayTraceSubsystem.ReportTrace = function() end
            RescueBtnReplayTraceSubsystem.StartTickMonitor = function() end
            RescueBtnReplayTraceSubsystem.TickMonitorCheck = function() end
            RescueBtnReplayTraceSubsystem.ReportTickMonitorHeartbeat = function() end
        end
        local GameReportSubsystem = SubsystemMgr and SubsystemMgr:Get("GameReportSubsystem")
        if GameReportSubsystem then
            GameReportSubsystem.ReplayReportData = function() return false end
            GameReportSubsystem.CheckCanBugglyPostException = function() return false end
            GameReportSubsystem.BugglyPostExceptionFull = function() return false end
            GameReportSubsystem.GetClientReplayDataReporter = function() return nil end
            if GameReportSubsystem.Reporter then
                GameReportSubsystem.Reporter.ReportIntArrayData = function() end
                GameReportSubsystem.Reporter.ReportUInt8ArrayData = function() end
                GameReportSubsystem.Reporter.ReportFloatArrayData = function() end
            end
        end
        local logic_report_replay = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logic_report_replay then
            logic_report_replay.ReportReplay = function() end
            logic_report_replay.SendReportReq = function() end
        end
        local logic_home_report = package.loaded["client.slua.logic.home.logic_home_report"]
        if logic_home_report then
            logic_home_report.ShowInGameReportUI = function() end
            logic_home_report.SendReport = function() end
        end
    end)
end

-- Phần 19 đã được gộp vào InitializeConnectionGuardExtended (Phần 11)

-- =========================== PHẦN 19A: SWIFTHAWK DEEP BYPASS ===========================
local function InitializeSwiftHawkBypass()
    pcall(function()
        -- Block SwiftHawk module hoàn toàn
        local swPaths = {
            "GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.SwiftHawkSubsystem",
            "GameLua.Mod.BaseMod.Common.Security.SwiftHawk",
            "GameLua.Mod.BaseMod.Client.Security.ClientSwiftHawk",
        }
        for _, path in ipairs(swPaths) do
            local mod = package.loaded[path]
            if mod then
                for k, v in pairs(mod) do
                    if type(v) == "function" then
                        local lk = string.lower(k)
                        if string.find(lk,"report",1,true) or string.find(lk,"send",1,true)
                        or string.find(lk,"forward",1,true) or string.find(lk,"detect",1,true)
                        or string.find(lk,"collect",1,true) or string.find(lk,"check",1,true)
                        or string.find(lk,"scan",1,true) or string.find(lk,"upload",1,true) then
                            mod[k] = function() end
                        end
                    end
                end
                if mod.StartCheck then mod.StartCheck = function() end end
                if mod.StopCheck  then mod.StopCheck  = function() end end
                if mod.OnInit     then mod.OnInit     = function() end end
                if mod.OnTick     then mod.OnTick     = function() end end
            end
        end
        -- Hook SubsystemMgr để vô hiệu hóa ngay khi Get
        local ok, SubsystemMgr = pcall(require, "GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if ok and SubsystemMgr then
            local sw = SubsystemMgr:Get("SwiftHawkSubsystem")
            if sw then
                for k, v in pairs(sw) do
                    if type(v) == "function" then sw[k] = function() end end
                end
            end
        end
    end)
end

-- =========================== PHẦN 19B: SHOOT VERIFY DS-SIDE BYPASS ===========================
local function InitializeShootVerifyDSBypass()
    pcall(function()
        -- Tắt toàn bộ kết quả xác minh đạn từ phía DS
        local vPaths = {
            "GameLua.Mod.BaseMod.DS.Security.ShootVerifySubSystemDS",
            "GameLua.Mod.BaseMod.Client.Security.ShootVerifySubSystemClient",
        }
        for _, path in ipairs(vPaths) do
            local mod = package.loaded[path]
            if mod then
                if mod.VerifyShoot           then mod.VerifyShoot           = function() return true end end
                if mod.OnShootVerifyResult   then mod.OnShootVerifyResult   = function() end end
                if mod.ReportVerifyFailed    then mod.ReportVerifyFailed    = function() end end
                if mod.SendVerifyResult      then mod.SendVerifyResult      = function() end end
                if mod.RequestVerify         then mod.RequestVerify         = function() return true end end
                if mod.StartVerify           then mod.StartVerify           = function() end end
                if mod.StopVerify            then mod.StopVerify            = function() end end
            end
        end
        -- Block RPC kết quả xác minh đạn
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            if GC.RPC_Client_ShootVertifyRes   then GC.RPC_Client_ShootVertifyRes   = function() end end
            if GC.RPC_Server_ShootVertifyRes   then GC.RPC_Server_ShootVertifyRes   = function() end end
            if GC.OnShootVerifyFailed          then GC.OnShootVerifyFailed          = function() end end
        end
    end)
end

-- =========================== PHẦN 19C: CORONALAB DEEP BYPASS ===========================
local function InitializeCoronaLabDeepBypass()
    pcall(function()
        -- Block module chính
        local clPaths = {
            "GameLua.Mod.BaseMod.Client.Security.CoronaLabSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.CoronaLabSubsystem",
            "GameLua.Mod.BaseMod.Common.Security.CoronaLab",
        }
        for _, path in ipairs(clPaths) do
            local mod = package.loaded[path]
            if mod then
                for k, v in pairs(mod) do
                    if type(v) == "function" then mod[k] = function() end end
                end
            end
        end
        -- Fake dữ liệu CoronaLab toàn cục
        _G.GlobalPlayerCoronaData = _G.GlobalPlayerCoronaData or {}
        local mt_cl = getmetatable(_G.GlobalPlayerCoronaData) or {}
        mt_cl.__newindex = function() end
        mt_cl.__index    = function() return 0 end
        setmetatable(_G.GlobalPlayerCoronaData, mt_cl)
        -- Block callback trên GameplayCallbacks
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            if GC.RPC_ClientCoronaLab        then GC.RPC_ClientCoronaLab        = function() end end
            if GC.CoronaLabReport            then GC.CoronaLabReport            = function() end end
            if GC.OnCoronaLabDataCollected   then GC.OnCoronaLabDataCollected   = function() end end
            if GC.SendCoronaLabData          then GC.SendCoronaLabData          = function() end end
        end
    end)
end

-- =========================== PHẦN 19D: CLIENT SEC MRPCS FLOW DS BYPASS ===========================
local function InitializeClientSecMrpcsDSBypass()
    pcall(function()
        local mPaths = {
            "GameLua.Mod.BaseMod.DS.Security.ClientSecMrpcsFlowSubsystem",
            "GameLua.Mod.BaseMod.Client.Security.ClientSecMrpcsFlowSubsystem",
        }
        for _, path in ipairs(mPaths) do
            local mod = package.loaded[path]
            if mod then
                for k, v in pairs(mod) do
                    if type(v) == "function" then mod[k] = function() end end
                end
            end
        end
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            if GC.ClientSecMrpcsFlow                           then GC.ClientSecMrpcsFlow                           = function() end end
            if GC.RPC_Server_ClientSecMrpcsFlow                then GC.RPC_Server_ClientSecMrpcsFlow                = function() end end
            if GC.IsEnableReportMrpcsInCircleFlow              then GC.IsEnableReportMrpcsInCircleFlow              = function() return false end end
            if GC.IsEnableReportMrpcsInPartCircleFlow          then GC.IsEnableReportMrpcsInPartCircleFlow          = function() return false end end
        end
    end)
end

-- =========================== PHẦN 19E: NET DRIVER ERROR GUARD ===========================
local function InitializeNetDriverErrorGuard()
    pcall(function()
        -- Ngăn game tự tắt vì lỗi net driver
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            if GC.OnNetDriverError        then GC.OnNetDriverError        = function() end end
            if GC.OnNetConnectionError    then GC.OnNetConnectionError    = function() end end
            if GC.OnSessionError          then GC.OnSessionError          = function() end end
            if GC.OnNetworkFailure        then GC.OnNetworkFailure        = function() end end
            if GC.OnTravelError           then GC.OnTravelError           = function() end end
        end
        -- Hook UEngine level error handler nếu có
        if _G.OnNetworkFailure then
            local orig = _G.OnNetworkFailure
            _G.OnNetworkFailure = function(FailureType, ErrorStr)
                if FailureType and (string.find(tostring(FailureType),"CheatDetect",1,true)
                    or string.find(tostring(ErrorStr or ""),"cheat",1,true)
                    or string.find(tostring(ErrorStr or ""),"ban",1,true)) then
                    return
                end
                pcall(orig, FailureType, ErrorStr)
            end
        end
    end)
end

-- =========================== PHẦN 19F: GAMESAFE & ACE DEEP HOOK ===========================
local function InitializeGameSafeACEDeepHook()
    pcall(function()
        -- GameSafe callbacks deep null
        if _G.GameSafeCallbacks then
            local GSC = _G.GameSafeCallbacks
            local gscNullKeys = {
                "DoAttackFlowStrategy","RecordStrategyTimestampInReplay",
                "GetScriptReportContent","ReportCheatBehavior",
                "DoCircleFlowStrategy","DoVerifyInfoFlowStrategy",
                "DoHurtFlowStrategy","DoFireArmsStrategy",
                "OnRecvSecAntiData","OnRecvTssSdkData",
                "OnCollectGameSafeFeature","GetGameSafeCheckList",
            }
            for _, key in ipairs(gscNullKeys) do
                if GSC[key] then GSC[key] = function() return "" end end
            end
        end
        -- ACE SDK deep
        local ACE = package.loaded["ACE"] or _G.ACE
        if ACE then
            for k, v in pairs(ACE) do
                if type(v) == "function" then
                    local lk = string.lower(k)
                    if string.find(lk,"report",1,true) or string.find(lk,"detect",1,true)
                    or string.find(lk,"check",1,true)  or string.find(lk,"scan",1,true)
                    or string.find(lk,"terminate",1,true) then
                        ACE[k] = function() return true end
                    end
                end
            end
        end
        -- SecTgame module
        local SecTgame = package.loaded["SecTgame"] or _G.SecTgame
        if SecTgame then
            for k, v in pairs(SecTgame) do
                if type(v) == "function" then SecTgame[k] = function() return true end end
            end
        end
    end)
end

-- =========================== PHẦN 19G: PAK SIGNATURE WATCHER BYPASS ===========================
local function InitializePakSignatureWatcherBypass()
    pcall(function()
        -- Block Pak file signature check watcher runtime
        local PakWatcher = package.loaded["PakSignatureWatcher"] or _G.PakSignatureWatcher
        if PakWatcher then
            if PakWatcher.Start        then PakWatcher.Start        = function() end end
            if PakWatcher.Stop         then PakWatcher.Stop         = function() end end
            if PakWatcher.OnViolation  then PakWatcher.OnViolation  = function() end end
            if PakWatcher.CheckFile    then PakWatcher.CheckFile    = function() return true end end
        end
        -- Console commands disable signature
        local KSL = import("KismetSystemLibrary")
        if KSL and KSL.ExecuteConsoleCommand then
            pcall(function()
                local PC = _G.GameplayCallbacks and _G.GameplayCallbacks.GetPlayerController and _G.GameplayCallbacks:GetPlayerController()
                KSL.ExecuteConsoleCommand(PC, "pak.AsyncLoadingThreadEnabled 0")
                KSL.ExecuteConsoleCommand(PC, "pak.EnableSignatureChecks 0")
                KSL.ExecuteConsoleCommand(PC, "PakSigning.Enabled 0")
            end)
        end
    end)
end

-- =========================== PHẦN 19H: RPC SERVER VALIDATE HOOK ===========================
local function InitializeRPCValidateHook()
    pcall(function()
        -- Hook BRPlayerCharacterBase RPC validate functions để chúng luôn return true
        local rpcModules = {
            BRPlayerCharacterBase,
            package.loaded["GameLua.Mod.BaseMod.Common.Character.BRPlayerCharacterBase"],
        }
        for _, mod in ipairs(rpcModules) do
            if mod and type(mod) == "table" then
                for k, v in pairs(mod) do
                    if type(v) == "function" and string.find(tostring(k), "Validate", 1, true) then
                        mod[k] = function() return true end
                    end
                end
            end
        end
        -- Block DS-side RPC rejection
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            if GC.OnPlayerRPCValidateFailed then GC.OnPlayerRPCValidateFailed = function() end end
            if GC.OnRPCBlocked             then GC.OnRPCBlocked             = function() end end
        end
    end)
end

-- =========================== PHẦN 20: NETWORK PACKET BLOCKER ===========================
local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket and not NetUtil.IsBypassed then
            local originalSendPacket = NetUtil.SendPacket
            local blockedPackets = {
                -- ✅ CHỈ CHẶN: Packet anti-cheat
                ["report_speed_hack"]=1,
                ["report_wall_hack"]=1,
                ["report_aim_bot"]=1,
                ["detect_cheat"]=1,
                ["ban_player"]=1,
                ["report_memory_hack"]=1,
                ["report_cheat_engine"]=1,
                ["client_anti_cheat_report"]=1,
                ["report_esp_usage"]=1,
                ["report_modded_files"]=1,
                ["report_malicious_behavior"]=1,
                
                -- ✅ CÁC PACKET GÂY MẤT KẾT NỐI / KICK KHI DÙNG CÁC TÍNH NĂNG MOD
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1, ["ReportSecVehicleMoveFlow"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, 
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1, ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1, ["bReportedModifierException"]=1,
                ["ReportModifierException"]=1, ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1, ["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1, ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1, ["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(firstArg, secondArg, ...)
                local packetName
                -- Kiểm tra kiểu dữ liệu thay vì so sánh bảng trực tiếp:
                -- Nếu firstArg là string → đây là tên packet (gọi tĩnh: NetUtil.SendPacket("name", ...))
                -- Nếu firstArg là table/userdata → đây là self/instance (gọi OOP: obj:SendPacket("name", ...))
                if type(firstArg) == "string" then
                    packetName = firstArg
                    if blockedPackets[packetName] then return end
                    return originalSendPacket(firstArg, secondArg, ...)
                else
                    packetName = secondArg
                    if blockedPackets[packetName] then return end
                    return originalSendPacket(firstArg, secondArg, ...)
                end
            end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC and not _G.SendRPCHooked then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ReportPlayerKillFlow", "RPC_Server_ClientSecMrpcsFlow",
                "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams",
                "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab", "RPC_Server_ReportSimulateCharacterLocation"}
            _G.SendRPC = function(rpcName, ...)
                for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end
                return origRPC(rpcName, ...)
            end
            _G.SendRPCHooked = true
        end
    end)
end

-- =========================== PHẦN 21: HIGGS BOSON DISABLE ===========================
local function DisableHiggsBoson()
    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not PlayerController or not slua.isValid(PlayerController) then return end
    if PlayerController.HiggsBoson then
        PlayerController.HiggsBoson.bMHActive = false
        PlayerController.HiggsBoson.bCallPreReplication = false
    end
    if PlayerController.HiggsBosonComponent then
        PlayerController.HiggsBosonComponent.bMHActive = false
        PlayerController.HiggsBosonComponent:ControlMHActive(0)
    end
    pcall(function()
        local HiggsBosonComponent = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HiggsBosonComponent and HiggsBosonComponent.BlackList then
            local keys = {}
            for k in pairs(HiggsBosonComponent.BlackList) do keys[#keys+1] = k end
            for _, k in ipairs(keys) do HiggsBosonComponent.BlackList[k] = nil end
        end
        if HiggsBosonComponent and HiggsBosonComponent.StaticShowSecurityAlertInDev then
            HiggsBosonComponent.StaticShowSecurityAlertInDev = function() end
        end
    end)
    _G.BlackList = {}
    local blacklistMt = {}
    blacklistMt.__newindex = function() end
    setmetatable(_G.BlackList, blacklistMt)
end

-- =========================== PHẦN 22: ANTI CHEAT HOOKS ===========================
local function InitializeAntiCheatHooks()
    pcall(function()
        if _G.AvatarCheckCallback then
            _G.AvatarCheckCallback.StartAvatarCheck = function(obj) end
            _G.AvatarCheckCallback.OnReportItemID = function(obj) end
            _G.AvatarCheckCallback.OnDetectCheat = function(obj) end
            _G.AvatarCheckCallback.OnTriggerBan = function(obj) end
            _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
                if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then
                    PlayerController.HiggsBosonComponent:ControlMHActive(0)
                    PlayerController.HiggsBosonComponent.bMHActive = false
                end
            end
        end
        pcall(function()
            _G.GlobalPlayerCoronaData = _G.GlobalPlayerCoronaData or {}
            _G.GlobalPlayerCheatTimes = _G.GlobalPlayerCheatTimes or {}
            local mt = getmetatable(_G.GlobalPlayerCoronaData) or {}
            mt.__newindex = function(t, k, v) end
            setmetatable(_G.GlobalPlayerCoronaData, mt)
        end)
        pcall(function()
            if _G.GameSafeCallbacks then
                if _G.GameSafeCallbacks.RecordStrategyTimestampInReplay then
                    _G.GameSafeCallbacks.RecordStrategyTimestampInReplay = function(...) end
                end
                if _G.GameSafeCallbacks.DoAttackFlowStrategy then
                    _G.GameSafeCallbacks.DoAttackFlowStrategy = function() end
                end
                if _G.GameSafeCallbacks.GetScriptReportContent then
                    _G.GameSafeCallbacks.GetScriptReportContent = function() return "" end
                end
                if _G.GameSafeCallbacks.ReportCheatBehavior then
                    _G.GameSafeCallbacks.ReportCheatBehavior = function() end
                end
            end
        end)
    end)
end

-- =========================== PHẦN 23: ANTI REPORT ===========================
local function InitializeAntiReport()
    pcall(function()
        local paths = { "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem" }
        local ClientReportPlayerSubsystem = nil
        for _, path in ipairs(paths) do
            if package.loaded[path] then ClientReportPlayerSubsystem = package.loaded[path] break end
            local success, reqModule = pcall(require, path)
            if success and reqModule then ClientReportPlayerSubsystem = reqModule break end
        end
        if ClientReportPlayerSubsystem then
            ClientReportPlayerSubsystem.OnInit = function(self) return end
            ClientReportPlayerSubsystem._OnPlayerKilledOtherPlayer = function() return end
            ClientReportPlayerSubsystem._RecordFatalDamager = function() return end
            ClientReportPlayerSubsystem._OnDeathReplayDataWhenFatalDamaged = function() return end
            ClientReportPlayerSubsystem._RecordMurdererFromDeathReplayData = function() return end
            ClientReportPlayerSubsystem._RecordTeammatePlayerInfo = function() return end
            ClientReportPlayerSubsystem._OnBattleResult = function() return end
            ClientReportPlayerSubsystem._OnShowQuickReportMutualExclusiveUI = function() return end
            ClientReportPlayerSubsystem.GetFatalDamagerMap = function() return {} end
            ClientReportPlayerSubsystem.GetCachedTeammateName2InfoMap = function() return {} end
            ClientReportPlayerSubsystem.GetTeammateName2InfoMapDuringBattle = function() return {} end
            ClientReportPlayerSubsystem.GetCurrentNotInTeamHistoricalTeammateMap = function() return {} end
            ClientReportPlayerSubsystem.GetInTeamIndexFromHistoricalTeammateInfo = function() return -1 end
        end
    end)
    pcall(function()
        local dsPaths = { "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem", "GameLua.Mod.BaseMod.Client.Security.DSReportPlayerSubsystem" }
        local DSReportPlayerSubsystem = nil
        for _, path in ipairs(dsPaths) do
            if package.loaded[path] then DSReportPlayerSubsystem = package.loaded[path] break end
            local success, reqModule = pcall(require, path)
            if success and reqModule then DSReportPlayerSubsystem = reqModule break end
        end
        if DSReportPlayerSubsystem then
            DSReportPlayerSubsystem.OnInit = function(self) return end
            DSReportPlayerSubsystem._OnNearDeathOrRescued = function() return end
            DSReportPlayerSubsystem._OnCharacterDied = function() return end
            DSReportPlayerSubsystem._OnTeammateDamage = function() return end
            DSReportPlayerSubsystem._OnPlayerSettlementStart = function() return end
            DSReportPlayerSubsystem._AddKnockDownerToBattleResult = function() return end
            DSReportPlayerSubsystem._AddKillerToBattleResult = function() return end
            DSReportPlayerSubsystem._AddTeammateMurderToBattleResult = function() return end
            DSReportPlayerSubsystem._AddFatalDamagerMapToBattleResult = function() return end
            DSReportPlayerSubsystem._AddMLKillerUIDToBattleResult = function() return end
            DSReportPlayerSubsystem._SaveHistoricalTeammateInfo = function() return end
            DSReportPlayerSubsystem._RecordFatalDamager = function() return end
            DSReportPlayerSubsystem._RecordTeammateMurderer = function() return end
        end
    end)
    pcall(function()
        local ReportPlayerUtils = require("GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils")
        if ReportPlayerUtils then
            ReportPlayerUtils.RecordFatalDamager = function() return end
            ReportPlayerUtils.IsUsingHistoricalTeammateInfo = function() return false end
            ReportPlayerUtils.IsCharacterDeliverAI = function() return false end
        end
    end)
    pcall(function()
        local SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
        if SecurityCommonUtils then
            SecurityCommonUtils.ExtractPlayerBasicInfo = function() return {} end
            SecurityCommonUtils.LogIf = function() return false end
        end
    end)
    pcall(function()
        local ClientQuickReportMaliciousTeammate = require("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
        if ClientQuickReportMaliciousTeammate then
            ClientQuickReportMaliciousTeammate.OnShowMutualExclusiveUI = function() return end
            ClientQuickReportMaliciousTeammate.OnHideMutualExclusiveUI = function() return end
        end
    end)
end

-- =========================== PHẦN 24: GAMEPLAY CALLBACKS BYPASS ===========================
local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks or _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        if not GC._GameplayBypassHooked then
            local originalDSPlayerState = GC.OnDSPlayerStateChanged
            GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
                if InPlayerState and string.lower(tostring(InPlayerState)) == "cheatdetected" then return end
                if originalDSPlayerState then return originalDSPlayerState(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason) end
            end
            GC._GameplayBypassHooked = true
        end
        local function NoOpVoid() return end
        local function NoOpTable() return {} end
        local function NoOpNil() return nil end
        
        GC.ReportAttackFlow = NoOpVoid; GC.ReportSecAttackFlow = NoOpVoid
        GC.ReportHurtFlow = NoOpVoid; GC.ReportFireArms = NoOpVoid
        GC.ReportVerifyInfoFlow = NoOpVoid; GC.ReportMrpcsFlow = NoOpVoid
        GC.ReportPlayerBehavior = NoOpVoid; GC.ReportTeammatHurt = NoOpVoid
        GC.ReportMisKillByTeammate = NoOpVoid; GC.ReportForbitPick = NoOpVoid
        GC.ReportPlayerMoveRoute = NoOpVoid; GC.ReportPlayerPosition = NoOpVoid
        GC.ReportVehicleMoveFlow = NoOpVoid; GC.ReportSecTgameMovingFlow = NoOpVoid
        GC.ReportParachuteData = NoOpVoid; GC.SendTssSdkAntiDataToLobby = NoOpVoid
        GC.SendDSErrorLogToLobby = NoOpVoid; GC.SendDSErrorLogToLobbyOnece = NoOpVoid
        GC.SendDSHawkEyePatrolLogToLobby = NoOpVoid; GC.ReportEquipmentFlow = NoOpVoid
        GC.ReportAimFlow = NoOpVoid; GC.GetWeaponReport = NoOpTable
        GC.GetOneWeaponReport = NoOpTable; GC.ReportHeavyWeaponBoxSpawnFlow = NoOpVoid
        GC.ReportHeavyWeaponBoxActivationFlow = NoOpVoid; GC.ReportHeavyWeaponBoxOpenPlayerFlow = NoOpVoid
        GC.ReportHeavyWeaponBoxItemFlow = NoOpVoid; GC.ReportPlayersPing = NoOpVoid
        GC.ReportPlayerIP = NoOpVoid; GC.ReportPlayerFramePingRecord = NoOpVoid
        GC.OnDSConnectionSaturated = NoOpVoid; GC.ReportDSNetSaturation = NoOpVoid
        GC.ReportNetContinuousSaturate = NoOpVoid; GC.ReportDSNetRate = NoOpVoid
        GC.SendClientStats = NoOpVoid; GC.SendServerAvgTickDelta = NoOpVoid
        GC.ReportCircleFlow = NoOpVoid; GC.ReportJumpFlow = NoOpVoid
        GC.ReportAIStrategyInfo = NoOpVoid; GC.SendAIDeliveryInfo = NoOpVoid
        GC.ReportDailyTaskInfo = NoOpVoid; GC.ReportMatchRoomData = NoOpVoid
        GC.SendPlayerSpectatingLog = NoOpVoid; GC.ReportIDCardProduceFlow = NoOpVoid
        GC.ReportIDCardPickUpFlow = NoOpVoid; GC.ReportIDCardDestroyFlow = NoOpVoid
        GC.ReportRevivalFlow = NoOpVoid; GC.ReportGameSetting = NoOpVoid
        GC.ReportGameSettingNew = NoOpVoid; GC.ReportAntsVoiceTeamCreate = NoOpVoid
        GC.ReportAntsVoiceTeamQuit = NoOpVoid; GC.ReportCommonInfo = NoOpVoid
        GC.ReportLightweightStat = NoOpVoid; GC.SendSecTLog = NoOpVoid
        GC.SendDataMiningTLog = NoOpVoid; GC.SendActivityTLog = NoOpVoid
        GC.GetGeneralTLogData = NoOpNil
        GC.IsBypassed = true
    end)
end

-- =========================== PHẦN 24B: ULTIMATE FAKE HWID + IP + FIREBASE + XID (DX) ===========================
_G.DXConfig = _G.DXConfig or {}
_G.DX_OriginalInfo = _G.DX_OriginalInfo or {}
_G.DX_FakeData = _G.DX_FakeData or {}

-- [POPUP] Hiển thị thông báo chi tiết
local function DX_ShowPopup(msg)
    pcall(function()
        local Msg = require("client.slua.logic.Common.logic_common_msg_box") 
                 or require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(1, "[DX] Identity Spoofer", tostring(msg), 
                function() end, function() end, "OK", "ĐÓNG")
        end
    end)
end

-- [GENERATOR] Tạo dữ liệu giả thông minh (chuẩn format thật)
local function DX_GenerateFakeIP()
    local prefixes = {"192.168", "10.0", "172.16", "100.64"}
    local prefix = prefixes[math.random(1, #prefixes)]
    return string.format("%s.%d.%d", prefix, math.random(1, 254), math.random(1, 254))
end

local function DX_GenerateFirebaseID()
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
    local id = ""
    for i = 1, 22 do id = id .. chars:sub(math.random(1, #chars), math.random(1, #chars)) end
    return id
end

local function DX_GenerateXID()
    local hex = "0123456789abcdef"
    local function part(n) 
        local s = "" 
        for i=1,n do s = s .. hex:sub(math.random(1,16), math.random(1,16)) end 
        return s 
    end
    return string.format("%s-%s-%s-%s-%s", part(8), part(4), part(4), part(4), part(12))
end

local function DX_GenerateHWID()
    local chars = "0123456789abcdef"
    local hwid = "DX"
    for i = 1, 26 do hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) end
    return hwid
end

-- [LOGGING] Ghi log kiểm tra cho Spoofer
local function DX_WriteDebugLog(msg)
    pcall(function()
        local f = io.open("/sdcard/Android/data/com.vng.pubgmobile/files/loader_debug.txt", "a")
        if f then
            f:write(os.date("%Y-%m-%d %H:%M:%S") .. " [DXMOD-IDENTITY] " .. tostring(msg) .. "\n")
            f:close()
        end
    end)
end

local function DX_RegenerateAllFakeData()
    _G.DX_FakeData = {
        HWID = DX_GenerateHWID(),
        IP = DX_GenerateFakeIP(),
        Firebase = DX_GenerateFirebaseID(),
        XID = DX_GenerateXID(),
        Model = ({"iPad14,2","iPad13,1","iPhone15,3","SM-S928B","ASUS_AI701","2304FPN6DG"})[math.random(1, 6)],
        Name = "DX-Pro-Device",
        MAC = string.format("%02X:%02X:%02X:%02X:%02X:%02X", 
            math.random(0,255), math.random(0,255), math.random(0,255),
            math.random(0,255), math.random(0,255), math.random(0,255)),
        OS = ({"14.0","13.1.1","17.4.1","12.0"})[math.random(1, 4)]
    }
    
    pcall(DX_CaptureOriginalInfo)
    local f = _G.DX_FakeData
    local origHWID = tostring(_G.DX_OriginalInfo.HWID or "UNKNOWN")
    local fakeHWID = tostring(f.HWID or "UNKNOWN")
    
    local logStr = string.format("[HWID CHECK] ORIGINAL HWID: %s ===> FAKE HWID: %s | Model: %s | IP: %s | MAC: %s", 
        origHWID, fakeHWID, f.Model, f.IP, f.MAC)
        
    print(logStr)
    DX_WriteDebugLog(logStr)
    if type(_G.DX_WriteLogMessage) == "function" then
        _G.DX_WriteLogMessage(logStr)
    end
        
    return _G.DX_FakeData
end

-- [CAPTURE] Lưu thông tin thật trước khi fake
local function DX_CaptureOriginalInfo()
    pcall(function()
        if _G.DX_OriginalInfo.Captured then return end
        local S = import("KismetSystemLibrary")
        local T = import("STExtraBlueprintFunctionLibrary")
        local P = import("PlatformWrapper")
        local DataOS = package.loaded["client.logic.data.data_device_os"]
        
        if S and S.GetDeviceId then 
            pcall(function() _G.DX_OriginalInfo.HWID = S.GetDeviceId() end) 
        end
        if T and T.GetDeviceModel then 
            pcall(function() _G.DX_OriginalInfo.Model = T.GetDeviceModel() end) 
        end
        if T and T.GetDeviceName then 
            pcall(function() _G.DX_OriginalInfo.Name = T.GetDeviceName() end) 
        end
        if P and P.GetMacAddress then 
            pcall(function() _G.DX_OriginalInfo.MAC = P.GetMacAddress() end) 
        end
        if T and T.GetOSVersion then 
            pcall(function() _G.DX_OriginalInfo.OS = T.GetOSVersion() end) 
        end
        if DataOS then
            _G.DX_OriginalInfo.IP = DataOS.vClientIP
            _G.DX_OriginalInfo.Firebase = DataOS.FirebaseInstanceID
            _G.DX_OriginalInfo.XID = DataOS.AdvertisingID or DataOS.OAID
        end
        _G.DX_OriginalInfo.Captured = true
    end)
end

-- [HOOK ENGINE] Override hàm Native + Metatable data_device_os
function _G.DX_InitializeHWIDHook()
    DX_CaptureOriginalInfo()
    pcall(function()
        local S = import("KismetSystemLibrary")
        local T = import("STExtraBlueprintFunctionLibrary")
        local P = import("PlatformWrapper")
        
        if S and not _G.DX_HWID_Hooked then
            -- Hook HWID
            _G.DX_Orig_GetDeviceId = S.GetDeviceId
            function S.GetDeviceId(...)
                -- ✅ ĐỒNG BỘ: Đọc từ DX_Settings (menu Code 1)
                if _G.DX_Settings and _G.DX_Settings.FAKE_HWID == 1 then
                    if not _G.DX_FakeData.HWID then DX_RegenerateAllFakeData() end
                    return _G.DX_FakeData.HWID
                end
                return _G.DX_Orig_GetDeviceId and _G.DX_Orig_GetDeviceId(...) or "UNKNOWN"
            end
            
            -- Hook Model
            if T and T.GetDeviceModel then
                _G.DX_Orig_GetDeviceModel = T.GetDeviceModel
                function T.GetDeviceModel(...)
                    if _G.DX_Settings and _G.DX_Settings.FAKE_HWID == 1 then 
                        if not _G.DX_FakeData.Model then DX_RegenerateAllFakeData() end
                        return _G.DX_FakeData.Model 
                    end
                    return _G.DX_Orig_GetDeviceModel(...)
                end
            end
            
            -- Hook Name
            if T and T.GetDeviceName then
                _G.DX_Orig_GetDeviceName = T.GetDeviceName
                function T.GetDeviceName(...)
                    if _G.DX_Settings and _G.DX_Settings.FAKE_HWID == 1 then 
                        if not _G.DX_FakeData.Name then DX_RegenerateAllFakeData() end
                        return _G.DX_FakeData.Name 
                    end
                    return _G.DX_Orig_GetDeviceName(...)
                end
            end
            
            -- Hook OS Version
            if T and T.GetOSVersion then
                _G.DX_Orig_GetOSVersion = T.GetOSVersion
                function T.GetOSVersion(...)
                    if _G.DX_Settings and _G.DX_Settings.FAKE_HWID == 1 then 
                        if not _G.DX_FakeData.OS then DX_RegenerateAllFakeData() end
                        return _G.DX_FakeData.OS 
                    end
                    return _G.DX_Orig_GetOSVersion(...)
                end
            end
            
            -- Hook MAC
            if P and P.GetMacAddress then
                _G.DX_Orig_GetMac = P.GetMacAddress
                function P.GetMacAddress(...)
                    if _G.DX_Settings and _G.DX_Settings.FAKE_HWID == 1 then 
                        if not _G.DX_FakeData.MAC then DX_RegenerateAllFakeData() end
                        return _G.DX_FakeData.MAC 
                    end
                    return _G.DX_Orig_GetMac(...)
                end
            end
            _G.DX_HWID_Hooked = true
        end
        
        -- Hook data_device_os (IP, Firebase, XID) qua Metatable __index
        local DataOS = package.loaded["client.logic.data.data_device_os"]
        if DataOS and not _G.DX_DataOS_Hooked then
            local mt = getmetatable(DataOS) or {}
            local origIndex = mt.__index
            mt.__index = function(t, k)
                if _G.DX_Settings and _G.DX_Settings.FAKE_HWID == 1 then
                    if not _G.DX_FakeData.IP then DX_RegenerateAllFakeData() end
                    if k == "vClientIP" then return _G.DX_FakeData.IP end
                    if k == "FirebaseInstanceID" then return _G.DX_FakeData.Firebase end
                    if k == "AdvertisingID" or k == "OAID" then return _G.DX_FakeData.XID end
                end
                if type(origIndex) == "function" then return origIndex(t, k)
                elseif type(origIndex) == "table" then return origIndex[k]
                else return rawget(t, k) end
            end
            setmetatable(DataOS, mt)
            _G.DX_DataOS_Hooked = true
        end
    end)
end

-- [POPUP BUILDER] Format popup so sánh Thật > Giả
local function DX_BuildPopupON()
    local o = _G.DX_OriginalInfo
    local f = _G.DX_FakeData
    local function Safe(val) return (val and val ~= "") and tostring(val) or "[Not Found]" end
    return string.format(
        "[FAKE IDENTITY ĐÃ KÍCH HOẠT]\n\n" ..
        "DeviceID ASLI: %s\n > FAKE DeviceID: %s\n\n" ..
        "IP ASLI: %s\n > FAKE IP: %s\n\n" ..
        "Firebase ASLI: %s\n > FAKE Firebase: %s\n\n" ..
        "XID ASLI: %s\n > FAKE XID: %s\n\n" ..
        "Model ASLI: %s\n > FAKE Model: %s\n\n" ..
        "MAC ASLI: %s\n > FAKE MAC: %s",
        Safe(o.HWID), Safe(f.HWID),
        Safe(o.IP), Safe(f.IP),
        Safe(o.Firebase), Safe(f.Firebase),
        Safe(o.XID), Safe(f.XID),
        Safe(o.Model), Safe(f.Model),
        Safe(o.MAC), Safe(f.MAC)
    )
end

local function DX_BuildPopupOFF()
    return "[ĐÃ KHÔI PHỤC IDENTITAS GỐC]\n\n" ..
        "HWID, IP Address, Firebase ID,\n" ..
        "XID (AdID/OAID), Device Model,\n" ..
        "MAC Address, và OS Version\n" ..
        "đã được trả về giá trị thật của thiết bị."
end

-- [MENU UI] Đã xóa khỏi menu — FakeHWID luôn chạy nền tự động

-- Tự động khởi tạo hook và LUÔN BẬT FAKE_HWID khi script load (không cần menu)
pcall(function()
    _G.DX_Settings = _G.DX_Settings or {}
    _G.DX_Settings.FAKE_HWID = 1  -- Luôn bật, không phụ thuộc menu
    DX_RegenerateAllFakeData()     -- Sinh dữ liệu giả mới ngay khi load
    _G.DX_InitializeHWIDHook()     -- Cài hook lên tất cả các hàm Native
end)



-- =========================== PHẦN 24C: STRONG BYPASS PAKS ===========================
local function InitializeStrongBypassPaks()
    pcall(function()
        local a = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.AvatarExceptionReport"] or require("GameLua.Mod.Library.GamePlay.Avatar.AvatarExceptionReport")
        if a and a.__inner_impl then
            a.__inner_impl.OnRecordAvatarException = function() end
            a.__inner_impl.OnPreBattleResult = function() end
        end
    end)
    pcall(function()
        local h = package.loaded["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"] or require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if h and h.__inner_impl then
            h.__inner_impl.SendAntiDataFlow = function() end
            h.__inner_impl.SendHitFireBtnFlow = function() end
        end
    end)
    pcall(function()
        local cr = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem"] or require("GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem")
        if cr and cr.__inner_impl then
            cr.__inner_impl._OnSyncFatalDamage = function() end
            cr.__inner_impl._OnPlayerKilledOtherPlayer = function() end
        end
    end)
    pcall(function()
        if UnrealNet and UnrealNet.FilterNetworkException then
            local of = UnrealNet.FilterNetworkException
            UnrealNet.FilterNetworkException = function(t, m)
                if m and (string.find(m, "CheatDetected") or string.find(m, "IdipBan")) then return false end
                return of(t, m)
            end
        end
    end)
    pcall(function()
        if NetUtil and NetUtil.SendPkg and not NetUtil._bp then
            local old = NetUtil.SendPkg
            local blocked = {
                ["on_crow_update_ntf"]=1, ["hisar"]=1, ["ReportAttackFlow"]=1,
                ["ReportHurtFlow"]=1, ["ReportFireArms"]=1, ["ReportPlayerBehavior"]=1,
                ["report_tss_sdk_anti_data"]=1,
            }
            NetUtil.SendPkg = function(firstArg, secondArg, ...)
                local n
                -- Kiểm tra kiểu dữ liệu thay vì so sánh bảng trực tiếp:
                -- Nếu firstArg là string → tên packet (gọi tĩnh)
                -- Nếu firstArg là table/userdata → self/instance (gọi OOP), tên packet ở secondArg
                if type(firstArg) == "string" then
                    n = firstArg
                    if blocked[n] then return end
                    return old(firstArg, secondArg, ...)
                else
                    n = secondArg
                    if blocked[n] then return end
                    return old(firstArg, secondArg, ...)
                end
            end
            NetUtil._bp = true
        end
    end)
end

-- =========================== PHẦN 24D: GOKUBA SECURITY BYPASS ===========================
local function InitializeGokubaBypass()
    pcall(function()
        local Gokuba = package.loaded["GameLua.Mod.BaseMod.Client.Security.Gokuba"]
        if Gokuba then
            if Gokuba.OnControllerBeginPlay then Gokuba.OnControllerBeginPlay = function() end end
            if Gokuba.ForwardFeature       then Gokuba.ForwardFeature       = function() end end
            if Gokuba.InitGokubaLogic      then Gokuba.InitGokubaLogic      = function() end end
            -- Null out any remaining function fields dynamically
            for k, v in pairs(Gokuba) do
                if type(v) == "function" then
                    local lk = string.lower(k)
                    if string.find(lk, "report",1,true) or string.find(lk, "forward",1,true)
                    or string.find(lk, "detect",1,true) or string.find(lk, "check",1,true)
                    or string.find(lk, "scan",1,true)   or string.find(lk, "init",1,true) then
                        Gokuba[k] = function() end
                    end
                end
            end
        end
        -- Block future require of this module
        if not _G._GokubaBlocked then
            local _oldReq = _G.require or require
            _G.require = function(m)
                if string.find(tostring(m), "Gokuba", 1, true) then return {} end
                return _oldReq(m)
            end
            _G._GokubaBlocked = true
        end
    end)
end

-- =========================== PHẦN 25: PERIODIC RE-HOOK ===========================
local bypassRehookTimerActive = false

local function RunAllBypasses()
    pcall(InitializeSLUABypass)
    pcall(InitializeMD5Bypass)
    pcall(InitializeLogBlocker)
    pcall(InitializeScannerBlocker)
    pcall(InitializeReplayTelemetryBlocker)
    pcall(InitializeNetworkPacketBlock)
    pcall(DisableHiggsBoson)
    pcall(InitializeGameplayBypass)
    pcall(InitializeAntiReport)
    pcall(InitializeAntiCheatHooks)
    pcall(InitializeFPSUnlock)
    pcall(InitializeUGCModValidatorBypass)
    pcall(InitializePakFileManagerBypass)
    pcall(InitializeHawkEyeBypass)
    pcall(InitializeSecuritySubsystemBypass)
    pcall(InitializeSkinBypass)
    -- pcall(InitializeAutoHeadHooks) -- Xóa bỏ theo yêu cầu
    pcall(InitializeClientTLogUtilBypass)
    pcall(InitializeSTExtraBPLibraryBypass)
    pcall(InitializeSHA256Bypass)
    pcall(InitializeTssSdkAdvancedBypass)
    pcall(InitializeConnectionGuardExtended)
    pcall(InitializeMissingSubsystems)
    pcall(InitializeStrongBypassPaks)
    pcall(InitializeGokubaBypass)
    pcall(_G.DX_InitializeHWIDHook)
    -- === PHẦN MỚI BỔ SUNG ===
    pcall(InitializeSwiftHawkBypass)
    pcall(InitializeShootVerifyDSBypass)
    pcall(InitializeCoronaLabDeepBypass)
    pcall(InitializeClientSecMrpcsDSBypass)
    pcall(InitializeNetDriverErrorGuard)
    pcall(InitializeGameSafeACEDeepHook)
    pcall(InitializePakSignatureWatcherBypass)
    pcall(InitializeRPCValidateHook)
    if _G.DX_MaxLevelHookTry then pcall(_G.DX_MaxLevelHookTry) end
    if _G.DX_UAOwnershipHookTry then pcall(_G.DX_UAOwnershipHookTry) end
    -- ========================
    pcall(function()
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then
            CrashSight.Abort = function() end
            CrashSight.AppExit = function() end
            CrashSight.ForceExit = function() end
        end
    end)
    pcall(function()
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            TssSdk.ReportCheat = function() end
            TssSdk.ReportData = function() end
            TssSdk.SendCmd = function() end
            TssSdk.ScanMemory = function() return true end
            TssSdk.IsEmulator = function() return false end
            TssSdk.IsRooted   = function() return false end
            TssSdk.IsDebugged = function() return false end
        end
    end)
end

local function StartPeriodicRehook()
    if bypassRehookTimerActive then return end
    bypassRehookTimerActive = true
    local function ReHookLoop()
        pcall(RunAllBypasses)
        pcall(function()
            require("common.time_ticker").AddTimerOnce(90.0, ReHookLoop)
        end)
    end
    pcall(function()
        require("common.time_ticker").AddTimerOnce(90.0, ReHookLoop)
    end)
end

-- =========================== PHẦN: ĐỒNG BỘ CÀI ĐẶT NỀN TỰ ĐỘNG (SKIN ALWAYS ACTIVE) ===========================
_G.DX_Settings = _G.DX_Settings or {
    FAKE_HWID = 1, MASTER_SKIN = 1, ModSkin = 1, UNLOCK_SKIN = 1, UnlockWardrobe = 1,
    SkinOpenLink = 1, SkinDeadBox = 1, SkinAttachment = 1, ModEmote = 1, LOBBY_SKIN = 1,
    KillMessage = 1, KillCountUI = 1
}

function _G.DX_GetVal(id)
    return (_G.DX_Settings and _G.DX_Settings[id]) or 1
end

-- =========================== PHẦN: UNLOCK ALL SKIN & WARDROBE CORE (FROM BRPlayerCharacterBase) ===========================
function _G.DX_MaxLevelHookTry()
    if _G.DX_MaxLvlHooked then return end
    pcall(function()
        local M = require("client.slua.logic.wardrobe.LogicMultiItemModule")
        if type(M) ~= "table" then return end
        if type(M.GetDisPlayItemByGroup) == "function" and not M.__x3ml then
            M.__x3ml = true
            local orig = M.GetDisPlayItemByGroup
            M.GetDisPlayItemByGroup = function(self, GroupID, DataSource, ItemSubType)
                local okR, r = pcall(function()
                    local List = CDataTable.GetTableByFilter("MultiLevelItem", "GroupID", GroupID)
                    local maxLv, maxID = 0, nil
                    for _, v in pairs(List) do
                        local lv = tonumber(v.Level) or 0
                        if lv > maxLv then maxLv = lv maxID = v.ItemID end
                    end
                    return maxID
                end)
                if okR and r then return r end
                return orig(self, GroupID, DataSource, ItemSubType)
            end
        end
        if type(M.SetIsWardrobeMultiShapeTabUnlock) == "function" then
            pcall(M.SetIsWardrobeMultiShapeTabUnlock, M, true)
        end
        _G.DX_MaxLvlHooked = true
    end)
    pcall(function()
        if _G.DX_PlanBTHooked then return end
        local ok, F = pcall(require, "GameLua.Mod.PlanBTShooting.Gameplay.Feature.PlanBTWeaponFeature")
        if ok and type(F) == "table" and type(F.GetWeaponLevel) == "function" then
            F.GetWeaponLevel = function(self, WeaponID) return 7 end
            F.IsWeaponMaxLevel = function(self, WeaponID) return true end
            _G.DX_PlanBTHooked = true
        end
    end)
end

function _G.DX_UAOwnershipHookTry()
    if _G.DX_UAOwnHooked then return end
    pcall(function()
        local WD = require("client.slua.logic.wardrobe.wardrobe_data")
        if type(WD) ~= "table" then return end
        local function alwaysTrue() return true end
        if type(WD.HasValidItem) == "function" then WD.HasValidItem = alwaysTrue end
        if type(WD.HasItem) == "function" then WD.HasItem = alwaysTrue end
        if type(WD.CheckHasPermanentItem) == "function" then WD.CheckHasPermanentItem = alwaysTrue end
        _G.DX_UAOwnHooked = true
    end)
end

-- Tự động chạy Unlock Skin ngay khi script được nạp
pcall(_G.DX_MaxLevelHookTry)
pcall(_G.DX_UAOwnershipHookTry)


_G.X3 = _G.X3 or {}
_G.X3.LexusConfig = _G.X3.LexusConfig or {}
_G.X3.LexusState = _G.X3.LexusState or {}
_G.X3.LexusConfig.ModSkin = true

-- === BEGIN INTEGRATED NEW SKIN BLOCKS ===
_G.X3.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0}
}

_G.X3.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2,
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4,
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6,
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13,
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19,
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22
}

_G.X3.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.X3.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.X3.VipAttachToIndex[attachId] = index
        end
    end
end

_G.X3.WeaponSkinMap = _G.X3.WeaponSkinMap or {}
_G.X3.VehicleSkinMap = _G.X3.VehicleSkinMap or {}
_G.X3.OutfitMap = _G.X3.OutfitMap or {}
_G.X3.skinIdCache = _G.X3.skinIdCache or {}
_G.X3.skinIdCache2 = _G.X3.skinIdCache2 or {}

_G.X3.OutfitSkins = {
    Suit = { 1407961, 1407962, 1407963, 1407964, 1407965, 1407966, 1407967, 1407968, 1407969, 1407970, 1407971, 403003,1407916,1406469,1405870,1407140,1407141,1407142,1407550,1406638,1406872,1406971,1407103,1407512,1407391,1407366,1407330,1407329,1407286,1407285,1407277,1407276,1407275,1407225,1407224,1407259,1407161,1407160,1407107,1407106,1407079,1407048,1406977,1406976,1406898,1400569,1404000,1404049,1400119,1400117,1406060,1406891,1400687,1405160,1405145,1405436,1405435,1405434,1405064,1405207,1406895,1400333,1400377,1405092,1405121,1406889,1407278,1407279,1407381,1407380,1407385,1406389,1406388,1406387,1406386,1406385,1406140,1400782,1407392,1407318,1407317,1407404,1407402,1407401,1407387,1404434,1404437,1404440,1404448,1400324,1400708,1404043,1404048,1405953,1400101,1404153,1407440,1407441},
    Bag = {
        {501001, 501002, 501003}, {1501001174, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
        {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
        {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
        {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
        {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
        {1501001346, 1501002346, 1501003346}
    },
    Helmet = {
        {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
        {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
        {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
        {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342}
    },
    Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
}

_G.X3.skinIdMappings = {
    [101004]={101004, 1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218},
    [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},
    [102002]={102002,1102002136,1102002043,1102002061,1102002424},
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
    [102001]={102001, 1102001120},
    [101005]={101005, 1101005098},
    [104003]={104003, 1104003037},
    [104004]={104004, 1104004035, 1104004041}
}

_G.X3.VehicleSkins = {
    [1961001] = { 1961007, 1961010, 1961012, 1961013, 1961014, 1961015, 1961016, 1961017, 1961018, 1961020, 1961021, 1961024, 1961025, 1961029, 1961030, 1961031, 1961032, 1961033, 1961034, 1961035, 1961036, 1961037, 1961038, 1961039, 1961040, 1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047, 1961048, 1961049, 1961050, 1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057, 1961058, 1961059, 1961060, 1961061, 1961062, 1961063, 1961064, 1961065, 1961066, 1961067, 1961068, 1961069, 1961136, 1961137, 1961138, 1961139, 1961140, 1961141, 1961142, 1961143, 1961144, 1961145, 1961147, 1961148, 1961149, 1961150, 1961151, 1961152, 1961153 },
    [1903001] = { 1903005, 1903006, 1903007, 1903008, 1903011, 1903012, 1903013, 1903014, 1903015, 1903016, 1903017, 1903018, 1903019, 1903020, 1903021, 1903022, 1903023, 1903024, 1903029, 1903030, 1903031, 1903032, 1903033, 1903034, 1903035, 1903036, 1903037, 1903039, 1903040, 1903041, 1903042, 1903043, 1903044, 1903045, 1903046, 1903051, 1903052, 1903053, 1903054, 1903055, 1903056, 1903057, 1903058, 1903059, 1903060, 1903061, 1903062, 1903063, 1903066, 1903067, 1903068, 1903069, 1903070, 1903071, 1903072, 1903073, 1903074, 1903075, 1903076, 1903079, 1903080, 1903081, 1903082, 1903084, 1903085, 1903086, 1903087, 1903088, 1903089, 1903090, 1903189, 1903190, 1903191, 1903192, 1903193, 1903194, 1903195, 1903196, 1903197, 1903198, 1903199, 1903200, 1903201, 1903202, 1903203, 1903204, 1903205, 1903206, 1903207, 1903208, 1903209, 1903210, 1903211, 1903212, 1903213, 1903214, 1903215, 1903216, 1903217, 1903218, 1903219, 1903220, 1903221, 1903222, 1903223, 1903225, 1903226, 1903227, 1903228 },
    [1915001] = { 1915002, 1915003, 1915004, 1915005, 1915006, 1915007, 1915008, 1915009, 1915010, 1915011, 1915012, 1915013, 1915014, 1915015, 1915016, 1915017, 1915018, 1915019, 1915020, 1915021, 1915022, 1915023, 1915024, 1915025, 1915026, 1915027, 1915099 },
    [1908001] = { 1908002, 1908003, 1908005, 1908006, 1908007, 1908008, 1908009, 1908010, 1908011, 1908012, 1908013, 1908015, 1908016, 1908017, 1908018, 1908019, 1908021, 1908023, 1908030, 1908031, 1908032, 1908033, 1908034, 1908035, 1908036, 1908037, 1908039, 1908040, 1908041, 1908043, 1908047, 1908049, 1908050, 1908051, 1908052, 1908053, 1908054, 1908055, 1908056, 1908057, 1908059, 1908060, 1908061, 1908062, 1908063, 1908064, 1908066, 1908067, 1908068, 1908069, 1908070, 1908075, 1908076, 1908077, 1908078, 1908080, 1908081, 1908082, 1908083, 1908084, 1908085, 1908086, 1908087, 1908088, 1908089, 1908091, 1908094, 1908095, 1908096, 1908097, 1908098, 1908099, 1908100, 1908101, 1908102, 1908104, 1908105, 1908106, 1908107, 1908108, 1908109, 1908110, 1908111, 1908112, 1908188, 1908189 },
    [1907001] = { 1907007, 1907008, 1907010, 1907011, 1907012, 1907013, 1907014, 1907016, 1907018, 1907019, 1907021, 1907022, 1907023, 1907025, 1907026, 1907027, 1907028, 1907029, 1907030, 1907032, 1907033, 1907034, 1907035, 1907036, 1907037, 1907038, 1907040, 1907041, 1907043, 1907044, 1907045, 1907046, 1907047, 1907048, 1907049, 1907050, 1907051, 1907052, 1907053, 1907054, 1907055, 1907056, 1907058, 1907059, 1907060, 1907061, 1907062, 1907063, 1907064, 1907065, 1907066, 1907067, 1907068, 1907069, 1907070, 1907071, 1907072, 1907073, 1907074 }
}
_G.X3.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

-- DOWNLOAD GAME ITEM --
local function DownloadGameItem(id)
    local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
    local puffer_const = require('client.slua.logic.download.puffer_const')
    if puffer_manager and puffer_const and puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
        puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
    end
end
_G.X3.download_item = DownloadGameItem

-- GET SKIN ID --
_G.X3.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.X3.WeaponSkinMap and _G.X3.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.X3.skinIdCache2[targetSkinId] then
            if _G.X3.download_item then pcall(_G.X3.download_item, targetSkinId) end
            _G.X3.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

-- EQUIP CHARACTER AVATAR --
_G.X3.equip_character_avatar = function(Character)
    if not Character or not slua.isValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = import("BackpackUtils")
    local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
    if not SlotSyncData or not slua.isValid(SlotSyncData) or not BackpackUtils then return end

    local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return end
        local slotData = SlotSyncData:Get(ApplyDataIdx)
        if slotData and slotData.SlotID == ApplyEquipSlot then
            local applyItemId = mappedSkin
            if isLevelDependent and type(mappedSkin) == "table" then
                local level = levelFunc(slotData.AdditionalItemID) or 1
                if level < 1 then level = 1 end
                if level > 3 then level = 3 end
                applyItemId = mappedSkin[level] or mappedSkin[1]
            end

            if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end

            if not _G.X3.skinIdCache[applyItemId] then
                if _G.X3.download_item then pcall(_G.X3.download_item, applyItemId) end
                _G.X3.skinIdCache[applyItemId] = true
            end

            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end

    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.X3.CustSlotType.GlideEquipemtSlot then
            hasGliderSlot = true
            break
        end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.X3.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end

    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.X3.OutfitMap.Suit or 0, _G.X3.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.X3.OutfitMap.Bag, _G.X3.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.X3.OutfitMap.Helmet, _G.X3.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.X3.OutfitMap.Parachute or 0, _G.X3.CustSlotType.ParachuteEquipemtSlot, false)
        EquipAvatar(i, _G.X3.OutfitMap.Pants or 0, 6, false)
        EquipAvatar(i, _G.X3.OutfitMap.Shoes or 0, 7, false)
    end
end

-- APPLY WEAPON SKINS --
_G.X3.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end

        for slot = 1, 4 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.X3.get_skin_id(WeaponID) or WeaponID
                if _G.X3.LexusConfig.X3SkinNewRandom then
                    local rs = _G.X3._SkinRandPick and _G.X3._SkinRandPick(WeaponID)
                    if rs then SkinID = rs end
                end
                local isModified = false

                local SkinData = Weapon.synData:Get(7)
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.X3.skinIdCache[SkinID] then
                        _G.X3.download_item(SkinID)
                        _G.X3.skinIdCache[SkinID] = true
                    end
                    isModified = true
                end

                if SkinID >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.X3.BaseAttachToIndex[attachmentId] or _G.X3.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.X3.VIP_Attachments[SkinID][mapIndex] and _G.X3.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.X3.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.X3.skinIdCache2[targetAttachId] then
                                                if _G.X3.download_item then pcall(_G.X3.download_item, targetAttachId) end
                                                _G.X3.skinIdCache2[targetAttachId] = true
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

-- APPLY VEHICLE SKINS --
_G.X3.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = nil
        pcall(function() Vehicle = PlayerCharacter.CurrentVehicle end)
        if not slua.isValid(Vehicle) then Vehicle = PlayerCharacter:GetCurrentVehicle() end
        if not slua.isValid(Vehicle) then
            _G.X3.LastVehicleEntity = nil
            return
        end

        if _G.X3.LastVehicleEntity == Vehicle and _G.X3.CurrentEquipVehicleID ~= nil then
            return
        end

        local VehicleAvatar = nil
        pcall(function() VehicleAvatar = Vehicle.VehicleAvatar end)
        if not slua.isValid(VehicleAvatar) then
            pcall(function() if Vehicle.GetVehicleAvatar then VehicleAvatar = Vehicle:GetVehicleAvatar() end end)
        end
        if not slua.isValid(VehicleAvatar) then
            pcall(function() VehicleAvatar = Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent() end)
        end
        if not slua.isValid(VehicleAvatar) then
            if type(_G.X3.Trace) == "function" and _G.X3.VehNoAvtrV ~= Vehicle then
                _G.X3.VehNoAvtrV = Vehicle
                _G.X3.Trace("VEH: VehicleAvatarComponent TIDAK valid (semua jalur gagal)")
            end
            return
        end

        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = ""
        pcall(function()
            if VehicleAvatar.GetCurrentAvatarID then currentId = tostring(VehicleAvatar:GetCurrentAvatarID() or "")
            else currentId = tostring(Vehicle:GetAvatarId() or "") end
        end)
        local applySkinId = 0

        for baseMapId, targetSkin in pairs(_G.X3.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then
                applySkinId = targetSkin
                break
            end
        end

        if type(_G.X3.Trace) == "function" and _G.X3.VehTracedV ~= Vehicle then
            _G.X3.VehTracedV = Vehicle
            local nMap = 0
            for _ in pairs(_G.X3.VehicleSkinMap or {}) do nMap = nMap + 1 end
            _G.X3.Trace("VEH: kendaraan baru | defId=" .. defId .. " curId=" .. currentId ..
                " | petaSkin=" .. tostring(nMap) .. " | cocok=" .. tostring(applySkinId) ..
                " | PreChange=" .. tostring(VehicleAvatar.PreChangeVehicleAvatar ~= nil) ..
                " ChangeItemAvatar=" .. tostring(VehicleAvatar.ChangeItemAvatar ~= nil) ..
                " BP_Change=" .. tostring(VehicleAvatar.BP_ChangeItemAvatar ~= nil) ..
                " SetNetData=" .. tostring(VehicleAvatar.SetVehicleNetAvatarData ~= nil))
        end

        if applySkinId and applySkinId > 0 and tostring(applySkinId) ~= currentId then
            _G.X3.skinIdCache = _G.X3.skinIdCache or {}
            if not _G.X3.skinIdCache[applySkinId] then
                if _G.X3.download_item then pcall(_G.X3.download_item, applySkinId) end
                _G.X3.skinIdCache[applySkinId] = true
            end

            VehicleAvatar.curSwitchEffectId = 7303001
            pcall(function()
                if VehicleAvatar.PreChangeVehicleAvatar then VehicleAvatar:PreChangeVehicleAvatar(applySkinId) end
            end)
            local vehChangeFn = VehicleAvatar.ChangeItemAvatar or VehicleAvatar.BP_ChangeItemAvatar
            local okC, errC = true, nil
            if vehChangeFn then okC, errC = pcall(vehChangeFn, VehicleAvatar, applySkinId, true) end
            local netOK = false
            pcall(function()
                if VehicleAvatar.SetVehicleNetAvatarData then
                    local ctrl = nil
                    pcall(function() ctrl = PlayerCharacter.Controller end)
                    if not slua.isValid(ctrl) then pcall(function() ctrl = PlayerCharacter:GetController() end) end
                    if slua.isValid(ctrl) then
                        VehicleAvatar:SetVehicleNetAvatarData(ctrl)
                        netOK = true
                    end
                end
            end)
            pcall(function()
                if VehicleAvatar.ShowVehicleSwitchEffect then VehicleAvatar:ShowVehicleSwitchEffect(7303001)
                elseif VehicleAvatar.CheckAndShowVehicleSwitchEffect then VehicleAvatar:CheckAndShowVehicleSwitchEffect() end
            end)
            if type(_G.X3.Trace) == "function" then
                if not vehChangeFn then
                    _G.X3.Trace("VEH: GAGAL — tidak ada fungsi ChangeItemAvatar/BP_ChangeItemAvatar")
                else
                    _G.X3.Trace("VEH: apply skin " .. tostring(applySkinId) .. " change=" .. tostring(okC) ..
                        (okC and "" or (" err=" .. tostring(errC))) .. " netSync=" .. tostring(netOK))
                end
            end

            _G.X3.CurrentEquipVehicleID = applySkinId
            _G.X3.LastVehicleEntity = Vehicle
        end
    end)
end

-- HANDLE PET LOGIC --
_G.X3.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.X3.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.X3.LastAppliedPet then return end

        _G.X3.skinIdCache = _G.X3.skinIdCache or {}
        if not _G.X3.skinIdCache[petSkin] then
            if _G.X3.download_item then pcall(_G.X3.download_item, petSkin) end
            _G.X3.skinIdCache[petSkin] = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.X3.LastAppliedPet = petSkin
    end)
end

-- APPLY AVATAR BORDER --
_G.X3.ApplyAvatarBorder = function()
    pcall(function()
        if not (_G.X3.LexusConfig and _G.X3.LexusConfig.ModSkin) then return end
        local M = package.loaded["client.slua.logic.roleInfo.logic_RoleInfoAvatarFrame"]
        if not M then return end
        if not M._X3BorderHooked then
            if type(rawget(M, "HasAvatarFrame")) == "function" then
                M._X3OrigHasAvatarFrame = rawget(M, "HasAvatarFrame")
                M.HasAvatarFrame = function(self, fid, ...)
                    if _G.X3.LexusConfig and _G.X3.LexusConfig.ModSkin then return true end
                    return M._X3OrigHasAvatarFrame(self, fid, ...)
                end
            end
            M._X3BorderHooked = true
        end
        local fid = _G.X3._BorderID or 2003014 -- ID frame dari dump AvatarFrameList
        if _G.X3._BorderAppliedID ~= fid and type(M.UpdateCurAvatarBoxID) == "function" then
            pcall(function() M:UpdateCurAvatarBoxID(fid) end)
            _G.X3._BorderAppliedID = fid
        end
    end)
end

-- FORCE REFRESH SKIN MAPS --
_G.X3.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.X3.LexusState or not _G.X3.LexusState.CustomTextData then return end
        local cData = _G.X3.LexusState.CustomTextData

        if _G.X3.OutfitSkins then
            if cData.SkinSuit and _G.X3.OutfitSkins.Suit[cData.SkinSuit] then _G.X3.OutfitMap.Suit = _G.X3.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.X3.OutfitSkins.Bag[cData.SkinBag] then _G.X3.OutfitMap.Bag = _G.X3.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.X3.OutfitSkins.Helmet[cData.SkinHelmet] then _G.X3.OutfitMap.Helmet = _G.X3.OutfitSkins.Helmet[cData.SkinHelmet] end
        end

        if _G.X3.skinIdMappings then
            if cData.SkinM416 and _G.X3.skinIdMappings[101004] and _G.X3.skinIdMappings[101004][cData.SkinM416] then _G.X3.WeaponSkinMap[101004] = _G.X3.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.X3.skinIdMappings[101001] and _G.X3.skinIdMappings[101001][cData.SkinAKM] then _G.X3.WeaponSkinMap[101001] = _G.X3.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.X3.skinIdMappings[101003] and _G.X3.skinIdMappings[101003][cData.SkinSCAR] then _G.X3.WeaponSkinMap[101003] = _G.X3.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.X3.skinIdMappings[101008] and _G.X3.skinIdMappings[101008][cData.SkinM762] then _G.X3.WeaponSkinMap[101008] = _G.X3.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.X3.skinIdMappings[101006] and _G.X3.skinIdMappings[101006][cData.SkinAUG] then _G.X3.WeaponSkinMap[101006] = _G.X3.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.X3.skinIdMappings[102002] and _G.X3.skinIdMappings[102002][cData.SkinUMP] then _G.X3.WeaponSkinMap[102002] = _G.X3.skinIdMappings[102002][cData.SkinUMP] end

            if cData.SkinUZI and _G.X3.skinIdMappings[102001] and _G.X3.skinIdMappings[102001][cData.SkinUZI] then _G.X3.WeaponSkinMap[102001] = _G.X3.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.X3.skinIdMappings[101005] and _G.X3.skinIdMappings[101005][cData.SkinGroza] then _G.X3.WeaponSkinMap[101005] = _G.X3.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.X3.skinIdMappings[104003] and _G.X3.skinIdMappings[104003][cData.SkinS12K] then _G.X3.WeaponSkinMap[104003] = _G.X3.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.X3.skinIdMappings[104004] and _G.X3.skinIdMappings[104004][cData.SkinDBS] then _G.X3.WeaponSkinMap[104004] = _G.X3.skinIdMappings[104004][cData.SkinDBS] end
        end

        if _G.X3.VehicleSkins then
            if cData.SkinDacia and _G.X3.VehicleSkins[1903001] and _G.X3.VehicleSkins[1903001][cData.SkinDacia] then _G.X3.VehicleSkinMap[1903001] = _G.X3.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.X3.VehicleSkins[1908001] and _G.X3.VehicleSkins[1908001][cData.SkinUAZ] then _G.X3.VehicleSkinMap[1908001] = _G.X3.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.X3.VehicleSkins[1961001] and _G.X3.VehicleSkins[1961001][cData.SkinCoupe] then _G.X3.VehicleSkinMap[1961001] = _G.X3.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.X3.VehicleSkins[1907001] and _G.X3.VehicleSkins[1907001][cData.SkinBuggy] then _G.X3.VehicleSkinMap[1907001] = _G.X3.VehicleSkins[1907001][cData.SkinBuggy] end
            if cData.SkinMirado and _G.X3.VehicleSkins[1915001] and _G.X3.VehicleSkins[1915001][cData.SkinMirado] then _G.X3.VehicleSkinMap[1915001] = _G.X3.VehicleSkins[1915001][cData.SkinMirado] end
        end

        if _G.X3.ApplyLobbyPickedSkins then pcall(_G.X3.ApplyLobbyPickedSkins) end
    end)
end

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.X3.NeedCheckDeadBoxTimer = 0

-- DEAD BOX TEMPER REQUEST --
_G.X3.DeadBox_TemperRequest = function(PlayerController)
    if _G.X3.NeedCheckDeadBoxTimer <= 0 then return end

    local curTime = os.clock()
    if _G.X3.LastCheckDeadBoxTime and (curTime - _G.X3.LastCheckDeadBoxTime) < 3.0 then return end
    _G.X3.LastCheckDeadBoxTime = curTime

    _G.X3.NeedCheckDeadBoxTimer = _G.X3.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end

    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end

    if not _G.X3.CachedActorArray then
        _G.X3.CachedActorArray = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end

    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.X3.CachedActorArray)

    for _, deadBoxActor in pairs(deadBoxes) do
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    local currentBoxSkinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.X3.CurrentEquipVehicleID and _G.X3.CurrentEquipVehicleID ~= 0 then
                        currentBoxSkinId = tonumber(tostring(_G.X3.CurrentEquipVehicleID) .. "1") or 0
                    else
                        local currentWeapon = PlayerCharacter:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) and currentWeapon.synData then
                            local weaponSkinData = currentWeapon.synData:Get(7)
                            if weaponSkinData and weaponSkinData.defineID then
                                currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                            end
                        end
                    end

                    if currentBoxSkinId ~= 0 then
                        pcall(function()
                            DeadBoxAvatarComponent:ResetItemAvatar()
                            DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                            DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                        end)
                    end
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

-- MOD SKIN / SKIN MOD --
function _G.X3.InitializeSkinModSystem()
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.X3.LobbyBypassHacked then
            local originalPutonEquipment = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local attachIndex = _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[itemID]
                if attachIndex then
                    local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[holdingWeaponSkinID] then
                        local vipAttachID = _G.X3.VIP_Attachments[holdingWeaponSkinID][attachIndex]
                        if vipAttachID and vipAttachID > 0 then
                            if self.HandleDownload then self:HandleDownload(vipAttachID, nil, nil, false) end
                            itemID = vipAttachID
                        end
                    end
                end
                if originalPutonEquipment then return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData) end
            end

            local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return retValue
            end
            _G.X3.LobbyBypassHacked = true
        end
    end)

    pcall(function()
        local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if Common_Items_UIBP and not _G.X3.IconBaloHacked then
        local originalInitView = Common_Items_UIBP.InitView
            Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displayResId = nil

                if _G.X3.get_skin_id then
                    local skinID = _G.X3.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then displayResId = skinID end
                end

                local attachIndex = _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[nItemId]
                if not displayResId and attachIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) then
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local finalSkinID = _G.X3.get_skin_id(weaponID) or weaponID
                            if finalSkinID >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[finalSkinID] then
                                local vipAttachID = _G.X3.VIP_Attachments[finalSkinID][attachIndex]
                                if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                            end
                        end
                    end
                end

                if displayResId then
                    tExtraData.displayResId = displayResId
                    if not _G.X3.skinIdCache2[displayResId] then
                        if _G.X3.download_item then pcall(_G.X3.download_item, displayResId) end
                        _G.X3.skinIdCache2[displayResId] = true
                    end
                end
                if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
            end
            _G.X3.IconBaloHacked = true
        end
    end)
end

-- Cara kerja:

_G.X3.SkinUnlockState = _G.X3.SkinUnlockState or {
    HookedCount = 0,
    ScanCount = 0,
    LastScan = 0,
}

_G.X3.SkinUnlock_ModulePatterns = { "backpack", "wardrobe", "warehouse", "depot", "item", "skin", "avatar", "dress", "outfit", "garage", "theme", "border", "frame", "pet", "buddy", "collect", "hall" }
_G.X3.SkinUnlock_OwnershipFns = {
    "IsOwnItem", "HasItem", "IsHaveItem", "CheckOwnItem", "OwnItem",
    "IsItemOwned", "CheckItemOwned", "IsUnlock", "CheckUnlock",
    "IsItemUnlock", "CheckItemUnlock", "IsOwned", "CheckOwned",
    "IsHave", "CheckHave", "HasOwned", "GetItemOwned",
    "IsSkinOwn", "HasSkin", "IsSkinOwned", "CheckSkinOwn",
    "IsPossess", "CheckPossess", "IsUnlocked", "CheckHasItem",
    "IsItemHas", "HasItemById", "IsHasItem",
}

-- SKIN UNLOCK LOG --
_G.X3.SkinUnlock_Log = function(msg)
    print("[X3Team][SkinUnlock] " .. tostring(msg))
    if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] " .. tostring(msg)) end
end

-- SKIN UNLOCK HOOK ONE --
_G.X3.SkinUnlock_HookOne = function(tbl, fnName, tag)
    local old = rawget(tbl, fnName)
    if type(old) ~= "function" then return end
    if rawget(tbl, "__x3su_" .. fnName) then return end
    rawset(tbl, "__x3su_" .. fnName, old)
    rawset(tbl, fnName, function(...)
        if _G.X3.LexusConfig and _G.X3.LexusConfig.SkinUnlockAll then return true end
        return old(...)
    end)
    _G.X3.SkinUnlockState.HookedCount = _G.X3.SkinUnlockState.HookedCount + 1
    SkinUnlock_Log("HOOK " .. tostring(tag) .. "." .. fnName)
end

-- SKIN UNLOCK HOOK TABLE --
_G.X3.SkinUnlock_HookTable = function(tbl, tag)
    if type(tbl) ~= "table" then return end
    for _, fnName in ipairs(SkinUnlock_OwnershipFns) do
        SkinUnlock_HookOne(tbl, fnName, tag)
    end
    local impl = rawget(tbl, "__inner_impl")
    if type(impl) == "table" then
        for _, fnName in ipairs(SkinUnlock_OwnershipFns) do
            SkinUnlock_HookOne(impl, fnName, tag .. ".__inner_impl")
        end
    end
end

-- SKIN UNLOCK SCAN --
_G.X3.SkinUnlockScan = function(force)
    if true then return end
    if not _G.X3.LexusConfig or not _G.X3.LexusConfig.SkinUnlockAll then return end
    local st = _G.X3.SkinUnlockState
    local now = os.clock()
    if not force and (now - (st.LastScan or 0)) < 5.0 then return end
    st.LastScan = now
    st.ScanCount = st.ScanCount + 1

    pcall(function()
        local ModuleManager = require("client.module_framework.ModuleManager")
        local cfg = ModuleManager and ModuleManager.CommonModuleConfig
        if type(cfg) == "table" then
            for name, modId in pairs(cfg) do
                local lname = tostring(name):lower()
                for _, pat in ipairs(SkinUnlock_ModulePatterns) do
                    if lname:find(pat) then
                        local ok, mod = pcall(ModuleManager.GetModule, modId)
                        if ok and type(mod) == "table" then
                            SkinUnlock_HookTable(mod, "MM:" .. tostring(name))
                        end
                        break
                    end
                end
            end
        end
    end)

    pcall(function()
        for modName, mod in pairs(package.loaded) do
            if type(mod) == "table" then
                local lname = tostring(modName):lower()
                for _, pat in ipairs(SkinUnlock_ModulePatterns) do
                    if lname:find(pat) then
                        SkinUnlock_HookTable(mod, tostring(modName))
                        break
                    end
                end
            end
        end
    end)

    if st.ScanCount == 1 then
        SkinUnlock_Log("scan pertama selesai, hook aktif: " .. st.HookedCount)
    end
end


-- SKIN UNLOCK TICK --
-- SKIN UNLOCK TICK (MAINLOOP 5 dtk: self-gate + anti reset default sehabis match) --
_G.X3.SkinUnlockTick = function()
    pcall(function()
        if not (_G.X3.LexusConfig and _G.X3.LexusConfig.SkinUnlockAll) then return end
        -- server me-reset wardrobe ke default saat match selesai -> injeksi ulang
        local stt = nil
        local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
        if gs and slua.isValid(gs) then pcall(function() stt = gs:GetGameModeState() end) end
        local inMatch = _G.X3._InCombatGS and _G.X3._InCombatGS(gs, stt) or (stt == "FightingState")
        if _G.X3._SkinWasInMatch == true and not inMatch and stt ~= nil and stt ~= "" then
            local lpAlive = false
            pcall(function()
                local lp = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
                if lp and slua.isValid(lp) and (lp.Health == nil or lp.Health > 0) then lpAlive = true end
            end)
            _G.X3._SkinNonFightN = (_G.X3._SkinNonFightN or 0) + 1
            if _G.X3._CrashLog then pcall(_G.X3._CrashLog, "SKIN RESET GATE > state '" .. tostring(stt) .. "' konfirmasi " .. tostring(_G.X3._SkinNonFightN) .. "/2 (charAktif=" .. tostring(lpAlive) .. ")") end
            if _G.X3._SkinNonFightN >= 2 and not lpAlive then
                _G.X3._SkinNonFightN = 0
                _G.X3._SkinWasInMatch = false
                local ij = _G.X3.Inj
                if ij then
                    ij.allDone = false
                    ij.injectDone = false
                    ij.phase = 1
                    ij.injectIdx = 1
                    ij.injectRunning = false
                end
                _G.X3.EnumDone = false
                if _G.X3._CrashLogUrgent then pcall(_G.X3._CrashLogUrgent, "SKIN RESET TERDETEKSI (match end TERKONFIRMASI 2x) > RE-INJECT") end
            end
        else
            _G.X3._SkinNonFightN = 0
            _G.X3._SkinWasInMatch = inMatch
        end
        if _G.X3.InjEnsure then pcall(_G.X3.InjEnsure) end
    end)
end


-- SKIN UNLOCK IN LOBBY --
_G.X3.SkinUnlock_InLobby = function()
    local inBattle = false
    pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
        if gs and slua.isValid(gs) then
            local st = gs:GetGameModeState() or ""
            inBattle = (st == "FightingState")
        end
    end)
    return not inBattle
end


-- APPLY LOBBY PICKED SKINS --
_G.X3.ApplyLobbyPickedSkins = function()
    local cData = _G.X3.LexusState and _G.X3.LexusState.CustomTextData
    if not cData then return end
    for k, v in pairs(cData) do
        local base = tostring(k):match("^LobbyGun_(%d+)$")
        if base and tonumber(v) then
            _G.X3.WeaponSkinMap[tonumber(base)] = tonumber(v)
        end
    end
    if tonumber(cData.LobbySuit) then _G.X3.OutfitMap.Suit = tonumber(cData.LobbySuit) end
    if tonumber(cData.LobbyBag) then local n = tonumber(cData.LobbyBag) _G.X3.OutfitMap.Bag = { n, n, n } end
    if tonumber(cData.LobbyHelmet) then local n = tonumber(cData.LobbyHelmet) _G.X3.OutfitMap.Helmet = { n, n, n } end
    if tonumber(cData.LobbyPants) then _G.X3.OutfitMap.Pants = tonumber(cData.LobbyPants) end
    if tonumber(cData.LobbyShoes) then _G.X3.OutfitMap.Shoes = tonumber(cData.LobbyShoes) end
    for k, v in pairs(cData) do
        local vb = tostring(k):match("^LobbyVeh_(%d+)$")
        if vb and tonumber(v) then
            _G.X3.VehicleSkinMap[tonumber(vb)] = tonumber(v)
        end
    end
end

_G.X3.VIPWeaponSkins = {
1101001001,1101001002,1101001003,1101001004,1101001005,1101001006,1101001007,1101001009,1101001019,1101001020,1101001022,1101001023,1101001024,1101001025,1101001027,1101001028,
1101001029,1101001030,1101001031,1101001033,1101001035,1101001036,1101001042,1101001044,1101001045,1101001046,1101001047,1101001048,1101001050,1101001051,1101001052,1101001053,
1101001054,1101001055,1101001056,1101001063,1101001068,1101001071,1101001079,1101001081,1101001089,1101001091,1101001092,1101001093,1101001094,1101001095,1101001103,1101001104,
1101001105,1101001107,1101001108,1101001109,1101001116,1101001117,1101001118,1101001121,1101001128,1101001129,1101001130,1101001131,1101001132,1101001135,1101001136,1101001139,
1101001143,1101001144,1101001145,1101001146,1101001154,1101001155,1101001156,1101001157,1101001158,1101001160,1101001161,1101001164,1101001173,1101001174,1101001177,1101001178,
1101001179,1101001181,1101001184,1101001193,1101001199,1101001213,1101001221,1101001231,1101001232,1101001233,1101001242,1101001249,1101001256,1101001257,1101001265,1101001266,
1101001267,1101001268,1101001276,1101002001,1101002002,1101002003,1101002004,1101002005,1101002006,1101002007,1101002008,1101002009,1101002019,1101002020,1101002029,1101002030,
1101002038,1101002039,1101002040,1101002041,1101002042,1101002043,1101002044,1101002045,1101002046,1101002047,1101002048,1101002049,1101002056,1101002057,1101002058,1101002060,
1101002061,1101002062,1101002063,1101002068,1101002070,1101002071,1101002073,1101002074,1101002081,1101002083,1101002084,1101002085,1101002086,1101002087,1101002089,1101002090,
1101002091,1101002092,1101002093,1101002095,1101002097,1101002098,1101002103,1101002104,1101002105,1101002110,1101002111,1101002112,1101002117,1101002118,1101002119,1101002120,
1101002125,1101002128,1101002133,1101002134,1101002135,1101002136,1101002137,1101002142,1101002143,1101002144,1101002149,1101002156,1101002157,1101002158,1101003001,1101003002,
1101003003,1101003004,1101003005,1101003006,1101003007,1101003008,1101003009,1101003010,1101003011,1101003012,1101003013,1101003014,1101003015,1101003016,1101003017,1101003018,
1101003019,1101003020,1101003021,1101003022,1101003032,1101003033,1101003034,1101003035,1101003036,1101003037,1101003038,1101003039,1101003040,1101003041,1101003042,1101003043,
1101003044,1101003045,1101003046,1101003048,1101003049,1101003050,1101003057,1101003058,1101003059,1101003060,1101003061,1101003062,1101003063,1101003070,1101003071,1101003073,
1101003080,1101003082,1101003083,1101003084,1101003085,1101003087,1101003088,1101003089,1101003090,1101003099,1101003100,1101003101,1101003103,1101003112,1101003119,1101003120,
1101003121,1101003125,1101003130,1101003131,1101003132,1101003133,1101003134,1101003135,1101003136,1101003138,1101003140,1101003141,1101003146,1101003147,1101003148,1101003150,
1101003157,1101003158,1101003167,1101003168,1101003173,1101003174,1101003188,1101003195,1101003196,1101003199,1101003200,1101003201,1101003208,1101003209,1101003212,1101003219,
1101003227,1101003228,1101004001,1101004002,1101004003,1101004004,1101004005,1101004006,1101004007,1101004008,1101004009,1101004010,1101004011,1101004013,1101004014,1101004015,
1101004016,1101004017,1101004018,1101004019,1101004030,1101004031,1101004032,1101004033,1101004034,1101004035,1101004036,1101004039,1101004046,1101004049,1101004051,1101004053,
1101004054,1101004055,1101004062,1101004067,1101004069,1101004070,1101004071,1101004078,1101004079,1101004086,1101004087,1101004088,1101004089,1101004090,1101004091,1101004098,
1101004099,1101004107,1101004110,1101004117,1101004118,1101004119,1101004120,1101004122,1101004123,1101004124,1101004125,1101004133,1101004138,1101004145,1101004146,1101004148,
1101004149,1101004150,1101004151,1101004154,1101004160,1101004163,1101004164,1101004179,1101004201,1101004209,1101004210,1101004218,1101004226,1101004227,1101004228,1101004236,
1101004237,1101004238,1101004246,1101005001,1101005002,1101005012,1101005013,1101005014,1101005019,1101005025,1101005027,1101005028,1101005029,1101005030,1101005031,1101005038,
1101005043,1101005044,1101005045,1101005052,1101005055,1101005066,1101005072,1101005082,1101005083,1101005084,1101005085,1101005090,1101005091,1101005098,1101005099,1101005100,
1101005105,1101005106,1101006001,1101006002,1101006003,1101006004,1101006005,1101006006,1101006007,1101006017,1101006018,1101006019,1101006020,1101006021,1101006023,1101006027,
1101006028,1101006033,1101006036,1101006037,1101006038,1101006039,1101006044,1101006045,1101006051,1101006052,1101006053,1101006054,1101006062,1101006067,1101006068,1101006075,
1101006076,1101006077,1101006085,1101006086,1101006087,1101006088,1101006089,1101006090,1101006098,1101006106,1101007001,1101007002,1101007003,1101007004,1101007005,1101007006,
1101007007,1101007008,1101007009,1101007010,1101007011,1101007012,1101007013,1101007014,1101007017,1101007018,1101007019,1101007020,1101007025,1101007033,1101007034,1101007036,
1101007037,1101007038,1101007039,1101007046,1101007047,1101007048,1101007054,1101007055,1101007062,1101007063,1101007064,1101007071,1101007072,1101007073,1101007078,1101007079,
1101007084,1101008010,1101008011,1101008012,1101008013,1101008014,1101008015,1101008016,1101008017,1101008018,1101008019,1101008020,1101008021,1101008026,1101008029,1101008030,
1101008031,1101008036,1101008039,1101008051,1101008052,1101008053,1101008054,1101008061,1101008062,1101008063,1101008070,1101008071,1101008072,1101008080,1101008081,1101008082,
1101008083,1101008084,1101008087,1101008088,1101008092,1101008104,1101008106,1101008116,1101008117,1101008118,1101008126,1101008127,1101008128,1101008129,1101008136,1101008137,
1101008138,1101008146,1101008154,1101008155,1101008156,1101008163,1101008170,1101009001,1101009002,1101009003,1101009004,1101009005,1101009006,1101009007,1101009008,1101009009,
1101009010,1101009011,1101009012,1101009013,1101009014,1101009015,1101009016,1101009019,1101009020,1101009021,1101009022,1101009023,1101009024,1101009099,1101010010,1101010011,
1101010012,1101010013,1101010016,1101010018,1101010019,1101010020,1101010021,1101010022,1101010023,1101010024,1101010029,1101010030,1101012001,1101012004,1101012009,1101012010,
1101012011,1101012012,1101012013,1101012018,1101012019,1101012020,1101012021,1101012022,1101012023,1101012024,1101012025,1101012026,1101012033,1101100003,1101100004,1101100012,
1101100013,1101100018,1101100019,1101100020,1101100021,1101101007,1101102007,1101102017,1101102025,1101102026,1101102027,1101102032,1101102033,1101102041,1101102049,1101102056
}

_G.X3.DumpSkins = nil

_G.X3.NonMaxLevels = {
[501001]=true, [501002]=true, [501003]=true, [501004]=true, [501005]=true, [501006]=true, [501007]=true, [501008]=true,
[501009]=true, [501010]=true, [501011]=true, [501012]=true, [501015]=true, [501101]=true, [501102]=true, [501103]=true,
[501104]=true, [501105]=true, [502001]=true, [502002]=true, [502003]=true, [502004]=true, [502005]=true, [502101]=true,
[502102]=true, [502103]=true, [502104]=true, [502105]=true, [502107]=true, [502108]=true, [502110]=true, [502111]=true,
[503001]=true, [503101]=true, [503102]=true, [503103]=true, [503104]=true, [503105]=true, [503107]=true, [503108]=true,
[503110]=true, [503111]=true, [503113]=true, [503114]=true, [1000052]=true, [1000053]=true, [1000055]=true, [1000056]=true,
[1406904]=true, [1406905]=true, [1406983]=true, [1407019]=true, [1407053]=true, [1407054]=true, [1407055]=true, [1407109]=true,
[1407110]=true, [1407111]=true, [1407163]=true, [1407164]=true, [1407227]=true, [1407228]=true, [1407288]=true, [1407289]=true,
[1407332]=true, [1407333]=true, [1407394]=true, [1407395]=true, [1407443]=true, [1407444]=true, [1407473]=true, [1407474]=true,
[1407525]=true, [1407526]=true, [1407527]=true, [1407575]=true, [1407576]=true, [1407634]=true, [1407635]=true, [1407698]=true,
[1407699]=true, [1407761]=true, [1407762]=true, [1407814]=true, [1407815]=true, [1407873]=true, [1407874]=true, [1407924]=true,
[1407925]=true, [1407998]=true, [1407999]=true, [1410428]=true, [1410429]=true, [1410528]=true, [1410529]=true, [1410559]=true,
[1410562]=true, [1410563]=true, [1410843]=true, [1410844]=true, [1410989]=true, [1410990]=true, [1410996]=true, [1410997]=true,
[1410999]=true, [1411000]=true, [1501079]=true, [1501080]=true, [1501081]=true, [1501082]=true, [1519003]=true, [1519302]=true,
[1519304]=true, [1519308]=true, [1733000]=true, [1901016]=true, [1901017]=true, [1901025]=true, [1901026]=true, [1901041]=true,
[1901042]=true, [1901043]=true, [1901044]=true, [1901045]=true, [1901046]=true, [1901082]=true, [1901083]=true, [1901084]=true,
[1901086]=true, [1901087]=true, [1901088]=true, [1901099]=true, [1901100]=true, [1901101]=true, [1902027]=true, [1902028]=true,
[1902029]=true, [1902031]=true, [1902032]=true, [1902033]=true, [1903012]=true, [1903013]=true, [1903015]=true, [1903016]=true,
[1903032]=true, [1903034]=true, [1903084]=true, [1903085]=true, [1903086]=true, [1903194]=true, [1903195]=true, [1903196]=true,
[1903206]=true, [1907044]=true, [1907045]=true, [1907046]=true, [1907060]=true, [1907061]=true, [1907062]=true, [1907069]=true,
[1907070]=true, [1907071]=true, [1908030]=true, [1908031]=true, [1908033]=true, [1908035]=true, [1908049]=true, [1908050]=true,
[1908051]=true, [1908052]=true, [1908053]=true, [1908054]=true, [1908055]=true, [1908096]=true, [1908097]=true, [1908098]=true,
[1908106]=true, [1908113]=true, [1908114]=true, [1908115]=true, [1911016]=true, [1911017]=true, [1911018]=true, [1915013]=true,
[1915014]=true, [1915015]=true, [1915023]=true, [1915024]=true, [1915025]=true, [1953005]=true, [1953006]=true, [1953007]=true,
[1953013]=true, [1953014]=true, [1953015]=true, [1988002]=true, [1988003]=true, [1988004]=true, [4301603]=true, [4301604]=true,
[4301605]=true, [4301606]=true, [4301607]=true, [4301608]=true, [4301609]=true, [4301610]=true, [4301613]=true, [4301614]=true,
[4301615]=true, [7101001]=true, [7101002]=true, [7101003]=true, [7101005]=true, [7101006]=true, [7101007]=true, [7101009]=true,
[7101010]=true, [7101011]=true, [7101013]=true, [7101014]=true, [7101015]=true, [7101017]=true, [7101018]=true, [7101019]=true,
[7101021]=true, [7101022]=true, [7101023]=true, [7101025]=true, [7101026]=true, [7101027]=true, [7101029]=true, [7101030]=true,
[7101031]=true, [7101033]=true, [7101034]=true, [7101035]=true, [7101037]=true, [7101038]=true, [7101039]=true, [7101041]=true,
[7101042]=true, [7101043]=true, [7101045]=true, [7101046]=true, [7101047]=true, [7101049]=true, [7101050]=true, [7101051]=true,
[7101053]=true, [7101054]=true, [7101055]=true, [7101057]=true, [7101058]=true, [7101059]=true, [7101061]=true, [7101062]=true,
[7101063]=true, [7101065]=true, [7101066]=true, [7101067]=true, [7101069]=true, [7101070]=true, [7101071]=true, [12220411]=true,
[61010062]=true, [61010066]=true, [61010068]=true, [61100073]=true, [61100074]=true, [61100081]=true, [61100082]=true, [61100090]=true,
[61100091]=true, [61100099]=true, [61100100]=true, [61100108]=true, [61100109]=true, [61100116]=true, [61100117]=true, [61100126]=true,
[61100127]=true, [61100136]=true, [61100137]=true, [61200075]=true, [61200076]=true, [61200085]=true, [61200086]=true, [61200094]=true,
[61200095]=true, [61200101]=true, [61200102]=true, [61200111]=true, [61200112]=true, [61200117]=true, [61200118]=true, [61200128]=true,
[61200129]=true, [61200136]=true, [61200137]=true, [61300067]=true, [61300073]=true, [61300076]=true, [61400070]=true, [61400079]=true,
[61400081]=true, [61510010]=true, [61510012]=true, [61510014]=true, [61510016]=true, [61510018]=true, [61510020]=true, [61510022]=true,
[61510024]=true, [62110024]=true, [62110027]=true, [62110031]=true, [444001005]=true, [444002005]=true, [444003005]=true, [844001001]=true,
[844001003]=true, [844001011]=true, [844001012]=true, [844001013]=true, [844002001]=true, [844002003]=true, [844002011]=true, [844002012]=true,
[844002013]=true, [844002018]=true, [844003001]=true, [844003003]=true, [844003011]=true, [844003012]=true, [844003013]=true, [844003018]=true,
[844004018]=true, [845001001]=true, [845002001]=true, [845003001]=true, [911001007]=true, [911001013]=true, [911001033]=true, [911002002]=true,
[911002007]=true, [911002009]=true, [911002013]=true, [911002033]=true, [911003002]=true, [911003007]=true, [911003009]=true, [911003013]=true,
[911003033]=true, [911004002]=true, [911005009]=true, [912001001]=true, [912001025]=true, [912001051]=true, [912002001]=true, [912002025]=true,
[912002051]=true, [912003001]=true, [912003025]=true, [912003051]=true, [914001003]=true, [914001004]=true, [914001005]=true, [914001006]=true,
[914001011]=true, [914001012]=true, [914001014]=true, [914001016]=true, [914002003]=true, [914002004]=true, [914002005]=true, [914002006]=true,
[914002011]=true, [914002012]=true, [914002014]=true, [914002016]=true, [914002017]=true, [914002018]=true, [914003003]=true, [914003004]=true,
[914003005]=true, [914003006]=true, [914003011]=true, [914003012]=true, [914003014]=true, [914003016]=true, [914003017]=true, [914003018]=true,
[914004017]=true, [914004018]=true, [915001003]=true, [915001005]=true, [915001019]=true, [915001021]=true, [915002003]=true, [915002005]=true,
[915002019]=true, [915002021]=true, [915003003]=true, [915003005]=true, [915003019]=true, [915003021]=true, [931001033]=true, [931002033]=true,
[931003033]=true, [932001025]=true, [932002025]=true, [932003025]=true, [934001002]=true, [934001009]=true, [934001012]=true, [934001016]=true,
[934001017]=true, [934001018]=true, [934002002]=true, [934002009]=true, [934002012]=true, [934002016]=true, [934002017]=true, [934002018]=true,
[934003002]=true, [934003009]=true, [934003012]=true, [934003016]=true, [934003017]=true, [934003018]=true, [935001012]=true, [935001017]=true,
[935002012]=true, [935002017]=true, [935003012]=true, [935003017]=true, [1030010961]=true, [1101001037]=true, [1101001038]=true, [1101001039]=true,
[1101001040]=true, [1101001041]=true, [1101001057]=true, [1101001058]=true, [1101001059]=true, [1101001060]=true, [1101001061]=true, [1101001062]=true,
[1101001064]=true, [1101001065]=true, [1101001066]=true, [1101001067]=true, [1101001083]=true, [1101001084]=true, [1101001085]=true, [1101001086]=true,
[1101001087]=true, [1101001088]=true, [1101001097]=true, [1101001098]=true, [1101001099]=true, [1101001100]=true, [1101001101]=true, [1101001102]=true,
[1101001110]=true, [1101001111]=true, [1101001112]=true, [1101001113]=true, [1101001114]=true, [1101001115]=true, [1101001122]=true, [1101001123]=true,
[1101001124]=true, [1101001125]=true, [1101001126]=true, [1101001127]=true, [1101001133]=true, [1101001134]=true, [1101001137]=true, [1101001140]=true,
[1101001141]=true, [1101001142]=true, [1101001148]=true, [1101001149]=true, [1101001150]=true, [1101001151]=true, [1101001152]=true, [1101001153]=true,
[1101001166]=true, [1101001167]=true, [1101001168]=true, [1101001169]=true, [1101001170]=true, [1101001171]=true, [1101001172]=true, [1101001206]=true,
[1101001207]=true, [1101001208]=true, [1101001209]=true, [1101001210]=true, [1101001211]=true, [1101001212]=true, [1101001225]=true, [1101001226]=true,
[1101001227]=true, [1101001228]=true, [1101001229]=true, [1101001230]=true, [1101001235]=true, [1101001236]=true, [1101001237]=true, [1101001238]=true,
[1101001239]=true, [1101001240]=true, [1101001241]=true, [1101001243]=true, [1101001244]=true, [1101001245]=true, [1101001246]=true, [1101001247]=true,
[1101001248]=true, [1101001250]=true, [1101001251]=true, [1101001252]=true, [1101001253]=true, [1101001254]=true, [1101001255]=true, [1101001258]=true,
[1101001259]=true, [1101001260]=true, [1101001261]=true, [1101001262]=true, [1101001263]=true, [1101001264]=true, [1101001269]=true, [1101001270]=true,
[1101001271]=true, [1101001272]=true, [1101001273]=true, [1101001274]=true, [1101001275]=true, [1101002023]=true, [1101002024]=true, [1101002025]=true,
[1101002026]=true, [1101002027]=true, [1101002028]=true, [1101002050]=true, [1101002051]=true, [1101002052]=true, [1101002053]=true, [1101002054]=true,
[1101002055]=true, [1101002064]=true, [1101002065]=true, [1101002066]=true, [1101002067]=true, [1101002075]=true, [1101002076]=true, [1101002077]=true,
[1101002078]=true, [1101002079]=true, [1101002080]=true, [1101002099]=true, [1101002100]=true, [1101002101]=true, [1101002102]=true, [1101002106]=true,
[1101002107]=true, [1101002108]=true, [1101002109]=true, [1101002113]=true, [1101002114]=true, [1101002115]=true, [1101002116]=true, [1101002121]=true,
[1101002122]=true, [1101002123]=true, [1101002124]=true, [1101002126]=true, [1101002127]=true, [1101002129]=true, [1101002130]=true, [1101002131]=true,
[1101002132]=true, [1101002138]=true, [1101002139]=true, [1101002140]=true, [1101002141]=true, [1101002145]=true, [1101002146]=true, [1101002147]=true,
[1101002148]=true, [1101002150]=true, [1101002151]=true, [1101002152]=true, [1101002153]=true, [1101002154]=true, [1101002155]=true, [1101003051]=true,
[1101003052]=true, [1101003053]=true, [1101003054]=true, [1101003055]=true, [1101003056]=true, [1101003064]=true, [1101003065]=true, [1101003066]=true,
[1101003067]=true, [1101003068]=true, [1101003069]=true, [1101003074]=true, [1101003075]=true, [1101003076]=true, [1101003077]=true, [1101003078]=true,
[1101003079]=true, [1101003093]=true, [1101003094]=true, [1101003095]=true, [1101003096]=true, [1101003097]=true, [1101003098]=true, [1101003113]=true,
[1101003114]=true, [1101003115]=true, [1101003116]=true, [1101003117]=true, [1101003118]=true, [1101003122]=true, [1101003123]=true, [1101003124]=true,
[1101003142]=true, [1101003143]=true, [1101003144]=true, [1101003145]=true, [1101003160]=true, [1101003161]=true, [1101003162]=true, [1101003163]=true,
[1101003164]=true, [1101003165]=true, [1101003166]=true, [1101003169]=true, [1101003170]=true, [1101003171]=true, [1101003172]=true, [1101003175]=true,
[1101003176]=true, [1101003177]=true, [1101003178]=true, [1101003179]=true, [1101003180]=true, [1101003181]=true, [1101003182]=true, [1101003183]=true,
[1101003184]=true, [1101003185]=true, [1101003186]=true, [1101003187]=true, [1101003189]=true, [1101003190]=true, [1101003191]=true, [1101003192]=true,
[1101003193]=true, [1101003194]=true, [1101003202]=true, [1101003203]=true, [1101003204]=true, [1101003205]=true, [1101003206]=true, [1101003207]=true,
[1101003210]=true, [1101003211]=true, [1101003213]=true, [1101003214]=true, [1101003215]=true, [1101003216]=true, [1101003217]=true, [1101003218]=true,
[1101003220]=true, [1101003221]=true, [1101003222]=true, [1101003223]=true, [1101003224]=true, [1101003225]=true, [1101003226]=true, [1101004040]=true,
[1101004041]=true, [1101004042]=true, [1101004043]=true, [1101004044]=true, [1101004045]=true, [1101004056]=true, [1101004057]=true, [1101004058]=true,
[1101004059]=true, [1101004060]=true, [1101004061]=true, [1101004072]=true, [1101004073]=true, [1101004074]=true, [1101004075]=true, [1101004076]=true,
[1101004077]=true, [1101004080]=true, [1101004081]=true, [1101004082]=true, [1101004083]=true, [1101004084]=true, [1101004085]=true, [1101004092]=true,
[1101004093]=true, [1101004094]=true, [1101004095]=true, [1101004096]=true, [1101004097]=true, [1101004112]=true, [1101004113]=true, [1101004114]=true,
[1101004135]=true, [1101004136]=true, [1101004137]=true, [1101004155]=true, [1101004156]=true, [1101004157]=true, [1101004158]=true, [1101004159]=true,
[1101004161]=true, [1101004162]=true, [1101004194]=true, [1101004195]=true, [1101004196]=true, [1101004197]=true, [1101004198]=true, [1101004199]=true,
[1101004200]=true, [1101004202]=true, [1101004203]=true, [1101004204]=true, [1101004205]=true, [1101004206]=true, [1101004207]=true, [1101004208]=true,
[1101004211]=true, [1101004212]=true, [1101004213]=true, [1101004214]=true, [1101004215]=true, [1101004216]=true, [1101004217]=true, [1101004219]=true,
[1101004220]=true, [1101004221]=true, [1101004222]=true, [1101004223]=true, [1101004224]=true, [1101004225]=true, [1101004229]=true, [1101004230]=true,
[1101004231]=true, [1101004232]=true, [1101004233]=true, [1101004234]=true, [1101004235]=true, [1101004239]=true, [1101004240]=true, [1101004241]=true,
[1101004242]=true, [1101004243]=true, [1101004244]=true, [1101004245]=true, [1101005015]=true, [1101005016]=true, [1101005017]=true, [1101005018]=true,
[1101005021]=true, [1101005022]=true, [1101005023]=true, [1101005024]=true, [1101005032]=true, [1101005033]=true, [1101005034]=true, [1101005035]=true,
[1101005036]=true, [1101005037]=true, [1101005039]=true, [1101005040]=true, [1101005041]=true, [1101005042]=true, [1101005046]=true, [1101005047]=true,
[1101005048]=true, [1101005049]=true, [1101005050]=true, [1101005051]=true, [1101005078]=true, [1101005079]=true, [1101005080]=true, [1101005081]=true,
[1101005086]=true, [1101005087]=true, [1101005088]=true, [1101005089]=true, [1101005092]=true, [1101005093]=true, [1101005094]=true, [1101005095]=true,
[1101005096]=true, [1101005097]=true, [1101005101]=true, [1101005102]=true, [1101005103]=true, [1101005104]=true, [1101006029]=true, [1101006030]=true,
[1101006031]=true, [1101006032]=true, [1101006040]=true, [1101006041]=true, [1101006042]=true, [1101006043]=true, [1101006055]=true, [1101006056]=true,
[1101006057]=true, [1101006058]=true, [1101006059]=true, [1101006060]=true, [1101006061]=true, [1101006063]=true, [1101006064]=true, [1101006065]=true,
[1101006066]=true, [1101006069]=true, [1101006070]=true, [1101006071]=true, [1101006072]=true, [1101006073]=true, [1101006074]=true, [1101006078]=true,
[1101006079]=true, [1101006080]=true, [1101006081]=true, [1101006082]=true, [1101006083]=true, [1101006084]=true, [1101006091]=true, [1101006092]=true,
[1101006093]=true, [1101006094]=true, [1101006095]=true, [1101006096]=true, [1101006097]=true, [1101006099]=true, [1101006100]=true, [1101006101]=true,
[1101006102]=true, [1101006103]=true, [1101006104]=true, [1101006105]=true, [1101007021]=true, [1101007022]=true, [1101007023]=true, [1101007024]=true,
[1101007030]=true, [1101007031]=true, [1101007032]=true, [1101007035]=true, [1101007040]=true, [1101007041]=true, [1101007042]=true, [1101007043]=true,
[1101007044]=true, [1101007045]=true, [1101007056]=true, [1101007057]=true, [1101007058]=true, [1101007059]=true, [1101007060]=true, [1101007061]=true,
[1101007065]=true, [1101007066]=true, [1101007067]=true, [1101007068]=true, [1101007069]=true, [1101007070]=true, [1101007074]=true, [1101007075]=true,
[1101007076]=true, [1101007077]=true, [1101007080]=true, [1101007081]=true, [1101007082]=true, [1101007083]=true, [1101008022]=true, [1101008023]=true,
[1101008024]=true, [1101008025]=true, [1101008032]=true, [1101008033]=true, [1101008034]=true, [1101008035]=true, [1101008045]=true, [1101008046]=true,
[1101008047]=true, [1101008048]=true, [1101008049]=true, [1101008050]=true, [1101008055]=true, [1101008056]=true, [1101008057]=true, [1101008058]=true,
[1101008059]=true, [1101008060]=true, [1101008064]=true, [1101008065]=true, [1101008066]=true, [1101008067]=true, [1101008068]=true, [1101008069]=true,
[1101008073]=true, [1101008074]=true, [1101008075]=true, [1101008076]=true, [1101008077]=true, [1101008078]=true, [1101008079]=true, [1101008097]=true,
[1101008098]=true, [1101008099]=true, [1101008100]=true, [1101008101]=true, [1101008102]=true, [1101008103]=true, [1101008110]=true, [1101008111]=true,
[1101008112]=true, [1101008113]=true, [1101008114]=true, [1101008115]=true, [1101008120]=true, [1101008121]=true, [1101008122]=true, [1101008123]=true,
[1101008124]=true, [1101008125]=true, [1101008130]=true, [1101008131]=true, [1101008132]=true, [1101008133]=true, [1101008134]=true, [1101008135]=true,
[1101008139]=true, [1101008140]=true, [1101008141]=true, [1101008142]=true, [1101008143]=true, [1101008144]=true, [1101008145]=true, [1101008147]=true,
[1101008148]=true, [1101008149]=true, [1101008150]=true, [1101008151]=true, [1101008152]=true, [1101008153]=true, [1101008157]=true, [1101008158]=true,
[1101008159]=true, [1101008160]=true, [1101008161]=true, [1101008162]=true, [1101008164]=true, [1101008165]=true, [1101008166]=true, [1101008167]=true,
[1101008168]=true, [1101008169]=true, [1101009017]=true, [1101009018]=true, [1101010025]=true, [1101010026]=true, [1101010027]=true, [1101010028]=true,
[1101012005]=true, [1101012006]=true, [1101012007]=true, [1101012008]=true, [1101012014]=true, [1101012015]=true, [1101012016]=true, [1101012017]=true,
[1101012027]=true, [1101012028]=true, [1101012029]=true, [1101012030]=true, [1101012031]=true, [1101012032]=true, [1101100005]=true, [1101100006]=true,
[1101100007]=true, [1101100008]=true, [1101100009]=true, [1101100010]=true, [1101100011]=true, [1101100014]=true, [1101100015]=true, [1101100016]=true,
[1101100017]=true, [1101101001]=true, [1101101002]=true, [1101101003]=true, [1101101004]=true, [1101101005]=true, [1101101006]=true, [1101102001]=true,
[1101102002]=true, [1101102003]=true, [1101102004]=true, [1101102005]=true, [1101102006]=true, [1101102011]=true, [1101102012]=true, [1101102013]=true,
[1101102014]=true, [1101102015]=true, [1101102016]=true, [1101102018]=true, [1101102019]=true, [1101102020]=true, [1101102021]=true, [1101102022]=true,
[1101102023]=true, [1101102024]=true, [1101102028]=true, [1101102029]=true, [1101102030]=true, [1101102031]=true, [1101102034]=true, [1101102035]=true,
[1101102036]=true, [1101102037]=true, [1101102038]=true, [1101102039]=true, [1101102040]=true, [1101102042]=true, [1101102043]=true, [1101102044]=true,
[1101102045]=true, [1101102046]=true, [1101102047]=true, [1101102048]=true, [1101102050]=true, [1101102051]=true, [1101102052]=true, [1101102053]=true,
[1101102054]=true, [1101102055]=true, [1102001019]=true, [1102001020]=true, [1102001021]=true, [1102001022]=true, [1102001023]=true, [1102001032]=true,
[1102001033]=true, [1102001034]=true, [1102001035]=true, [1102001054]=true, [1102001055]=true, [1102001056]=true, [1102001057]=true, [1102001065]=true,
[1102001066]=true, [1102001067]=true, [1102001068]=true, [1102001083]=true, [1102001086]=true, [1102001087]=true, [1102001088]=true, [1102001092]=true,
[1102001093]=true, [1102001094]=true, [1102001096]=true, [1102001098]=true, [1102001099]=true, [1102001100]=true, [1102001101]=true, [1102001110]=true,
[1102001111]=true, [1102001113]=true, [1102001114]=true, [1102001115]=true, [1102001116]=true, [1102001117]=true, [1102001118]=true, [1102001119]=true,
[1102001124]=true, [1102001125]=true, [1102001126]=true, [1102001127]=true, [1102001128]=true, [1102001129]=true, [1102001998]=true, [1102001999]=true,
[1102002037]=true, [1102002038]=true, [1102002039]=true, [1102002040]=true, [1102002041]=true, [1102002042]=true, [1102002049]=true, [1102002050]=true,
[1102002051]=true, [1102002052]=true, [1102002055]=true, [1102002056]=true, [1102002057]=true, [1102002058]=true, [1102002059]=true, [1102002060]=true,
[1102002064]=true, [1102002065]=true, [1102002066]=true, [1102002069]=true, [1102002086]=true, [1102002087]=true, [1102002088]=true, [1102002089]=true,
[1102002099]=true, [1102002100]=true, [1102002101]=true, [1102002111]=true, [1102002113]=true, [1102002114]=true, [1102002115]=true, [1102002116]=true,
[1102002122]=true, [1102002123]=true, [1102002125]=true, [1102002126]=true, [1102002127]=true, [1102002128]=true, [1102002130]=true, [1102002131]=true,
[1102002132]=true, [1102002133]=true, [1102002134]=true, [1102002135]=true, [1102002139]=true, [1102002140]=true, [1102002141]=true, [1102002142]=true,
[1102002418]=true, [1102002419]=true, [1102002420]=true, [1102002421]=true, [1102002422]=true, [1102002423]=true, [1102002431]=true, [1102002432]=true,
[1102002433]=true, [1102002434]=true, [1102002435]=true, [1102002436]=true, [1102002437]=true, [1102002439]=true, [1102002440]=true, [1102002441]=true,
[1102002442]=true, [1102002443]=true, [1102002444]=true, [1102002445]=true, [1102003016]=true, [1102003017]=true, [1102003018]=true, [1102003019]=true,
[1102003027]=true, [1102003028]=true, [1102003029]=true, [1102003030]=true, [1102003035]=true, [1102003036]=true, [1102003037]=true, [1102003038]=true,
[1102003046]=true, [1102003047]=true, [1102003048]=true, [1102003051]=true, [1102003060]=true, [1102003061]=true, [1102003062]=true, [1102003064]=true,
[1102003066]=true, [1102003067]=true, [1102003068]=true, [1102003071]=true, [1102003074]=true, [1102003075]=true, [1102003076]=true, [1102003077]=true,
[1102003078]=true, [1102003079]=true, [1102003094]=true, [1102003095]=true, [1102003096]=true, [1102003097]=true, [1102003098]=true, [1102003099]=true,
[1102004014]=true, [1102004015]=true, [1102004016]=true, [1102004017]=true, [1102004030]=true, [1102004031]=true, [1102004032]=true, [1102004033]=true,
[1102004046]=true, [1102004047]=true, [1102005003]=true, [1102005004]=true, [1102005005]=true, [1102005006]=true, [1102005016]=true, [1102005017]=true,
[1102005018]=true, [1102005019]=true, [1102005037]=true, [1102005038]=true, [1102005039]=true, [1102005040]=true, [1102005043]=true, [1102005044]=true,
[1102005053]=true, [1102005054]=true, [1102005055]=true, [1102005056]=true, [1102005058]=true, [1102005059]=true, [1102005060]=true, [1102005061]=true,
[1102005062]=true, [1102005063]=true, [1102005068]=true, [1102005069]=true, [1102005070]=true, [1102005071]=true, [1102005074]=true, [1102005075]=true,
[1102005076]=true, [1102005077]=true, [1102007015]=true, [1102007016]=true, [1102007017]=true, [1102007018]=true, [1102007020]=true, [1102007021]=true,
[1102105006]=true, [1102105007]=true, [1102105008]=true, [1102105009]=true, [1102105010]=true, [1102105011]=true, [1102105014]=true, [1102105015]=true,
[1102105016]=true, [1102105017]=true, [1102105022]=true, [1102105023]=true, [1102105024]=true, [1102105025]=true, [1102105026]=true, [1102105027]=true,
[1103001047]=true, [1103001048]=true, [1103001049]=true, [1103001057]=true, [1103001058]=true, [1103001059]=true, [1103001073]=true, [1103001074]=true,
[1103001075]=true, [1103001076]=true, [1103001077]=true, [1103001078]=true, [1103001081]=true, [1103001082]=true, [1103001083]=true, [1103001084]=true,
[1103001095]=true, [1103001096]=true, [1103001097]=true, [1103001098]=true, [1103001099]=true, [1103001100]=true, [1103001123]=true, [1103001124]=true,
[1103001125]=true, [1103001126]=true, [1103001127]=true, [1103001128]=true, [1103001134]=true, [1103001135]=true, [1103001136]=true, [1103001143]=true,
[1103001144]=true, [1103001145]=true, [1103001148]=true, [1103001149]=true, [1103001150]=true, [1103001151]=true, [1103001152]=true, [1103001153]=true,
[1103001156]=true, [1103001157]=true, [1103001158]=true, [1103001159]=true, [1103001173]=true, [1103001174]=true, [1103001175]=true, [1103001176]=true,
[1103001177]=true, [1103001178]=true, [1103001181]=true, [1103001182]=true, [1103001185]=true, [1103001186]=true, [1103001187]=true, [1103001188]=true,
[1103001189]=true, [1103001190]=true, [1103001194]=true, [1103001195]=true, [1103001196]=true, [1103001197]=true, [1103001198]=true, [1103001200]=true,
[1103001201]=true, [1103001204]=true, [1103001205]=true, [1103002014]=true, [1103002015]=true, [1103002016]=true, [1103002017]=true, [1103002024]=true,
[1103002025]=true, [1103002026]=true, [1103002027]=true, [1103002028]=true, [1103002029]=true, [1103002038]=true, [1103002039]=true, [1103002040]=true,
[1103002043]=true, [1103002044]=true, [1103002045]=true, [1103002046]=true, [1103002048]=true, [1103002053]=true, [1103002054]=true, [1103002055]=true,
[1103002056]=true, [1103002057]=true, [1103002058]=true, [1103002081]=true, [1103002082]=true, [1103002083]=true, [1103002084]=true, [1103002085]=true,
[1103002086]=true, [1103002090]=true, [1103002091]=true, [1103002092]=true, [1103002093]=true, [1103002100]=true, [1103002101]=true, [1103002102]=true,
[1103002103]=true, [1103002104]=true, [1103002105]=true, [1103002106]=true, [1103002107]=true, [1103002108]=true, [1103002109]=true, [1103002110]=true,
[1103002111]=true, [1103002112]=true, [1103002113]=true, [1103002120]=true, [1103002121]=true, [1103002122]=true, [1103002123]=true, [1103002124]=true,
[1103002125]=true, [1103002126]=true, [1103002130]=true, [1103002131]=true, [1103002132]=true, [1103002133]=true, [1103002134]=true, [1103002135]=true,
[1103002140]=true, [1103002141]=true, [1103002142]=true, [1103002143]=true, [1103002144]=true, [1103002145]=true, [1103002146]=true, [1103002150]=true,
[1103002151]=true, [1103002152]=true, [1103002153]=true, [1103002154]=true, [1103002155]=true, [1103003016]=true, [1103003017]=true, [1103003018]=true,
[1103003019]=true, [1103003020]=true, [1103003021]=true, [1103003024]=true, [1103003025]=true, [1103003026]=true, [1103003027]=true, [1103003028]=true,
[1103003029]=true, [1103003036]=true, [1103003037]=true, [1103003038]=true, [1103003039]=true, [1103003040]=true, [1103003041]=true, [1103003045]=true,
[1103003046]=true, [1103003047]=true, [1103003048]=true, [1103003049]=true, [1103003050]=true, [1103003056]=true, [1103003057]=true, [1103003058]=true,
[1103003059]=true, [1103003060]=true, [1103003061]=true, [1103003073]=true, [1103003074]=true, [1103003075]=true, [1103003076]=true, [1103003077]=true,
[1103003078]=true, [1103003081]=true, [1103003082]=true, [1103003083]=true, [1103003084]=true, [1103003085]=true, [1103003086]=true, [1103003088]=true,
[1103003089]=true, [1103003090]=true, [1103003091]=true, [1103003093]=true, [1103003094]=true, [1103003095]=true, [1103003096]=true, [1103003097]=true,
[1103003098]=true, [1103004031]=true, [1103004032]=true, [1103004033]=true, [1103004034]=true, [1103004035]=true, [1103004036]=true, [1103004042]=true,
[1103004043]=true, [1103004044]=true, [1103004045]=true, [1103004054]=true, [1103004055]=true, [1103004056]=true, [1103004057]=true, [1103004076]=true,
[1103004077]=true, [1103004078]=true, [1103004079]=true, [1103004083]=true, [1103004084]=true, [1103004085]=true, [1103004086]=true, [1103005020]=true,
[1103005021]=true, [1103005022]=true, [1103005023]=true, [1103005046]=true, [1103005047]=true, [1103006024]=true, [1103006025]=true, [1103006026]=true,
[1103006027]=true, [1103006028]=true, [1103006029]=true, [1103006042]=true, [1103006043]=true, [1103006044]=true, [1103006045]=true, [1103006054]=true,
[1103006055]=true, [1103006056]=true, [1103006057]=true, [1103006059]=true, [1103006060]=true, [1103006061]=true, [1103006062]=true, [1103006071]=true,
[1103006072]=true, [1103006073]=true, [1103006074]=true, [1103007016]=true, [1103007017]=true, [1103007018]=true, [1103007019]=true, [1103007021]=true,
[1103007022]=true, [1103007023]=true, [1103007024]=true, [1103007025]=true, [1103007026]=true, [1103007027]=true, [1103007034]=true, [1103007035]=true,
[1103007036]=true, [1103007037]=true, [1103007039]=true, [1103007040]=true, [1103007041]=true, [1103007042]=true, [1103009018]=true, [1103009019]=true,
[1103009020]=true, [1103009021]=true, [1103009033]=true, [1103009034]=true, [1103009035]=true, [1103009036]=true, [1103009040]=true, [1103009041]=true,
[1103009047]=true, [1103009048]=true, [1103009049]=true, [1103009050]=true, [1103009053]=true, [1103009054]=true, [1103012003]=true, [1103012004]=true,
[1103012005]=true, [1103012006]=true, [1103012007]=true, [1103012008]=true, [1103012009]=true, [1103012013]=true, [1103012014]=true, [1103012015]=true,
[1103012016]=true, [1103012017]=true, [1103012018]=true, [1103012020]=true, [1103012021]=true, [1103012022]=true, [1103012023]=true, [1103012025]=true,
[1103012026]=true, [1103012027]=true, [1103012028]=true, [1103012029]=true, [1103012030]=true, [1103012033]=true, [1103012034]=true, [1103012035]=true,
[1103012036]=true, [1103012037]=true, [1103012038]=true, [1103100003]=true, [1103100004]=true, [1103100005]=true, [1103100006]=true, [1103102001]=true,
[1103102002]=true, [1103102003]=true, [1103102004]=true, [1103102005]=true, [1103102006]=true, [1103103001]=true, [1103103002]=true, [1103103003]=true,
[1103103004]=true, [1103103005]=true, [1103103006]=true, [1104001031]=true, [1104001032]=true, [1104001033]=true, [1104001034]=true, [1104002018]=true,
[1104002019]=true, [1104002020]=true, [1104002021]=true, [1104002047]=true, [1104002048]=true, [1104002051]=true, [1104002052]=true, [1104002053]=true,
[1104002054]=true, [1104003033]=true, [1104003034]=true, [1104003035]=true, [1104003036]=true, [1104003042]=true, [1104003043]=true, [1104003044]=true,
[1104003045]=true, [1104004022]=true, [1104004023]=true, [1104004031]=true, [1104004032]=true, [1104004033]=true, [1104004034]=true, [1104004037]=true,
[1104004038]=true, [1104004039]=true, [1104004040]=true, [1104004047]=true, [1104004048]=true, [1104004049]=true, [1104004050]=true, [1104102002]=true,
[1104102003]=true, [1105001028]=true, [1105001029]=true, [1105001030]=true, [1105001031]=true, [1105001032]=true, [1105001033]=true, [1105001042]=true,
[1105001043]=true, [1105001044]=true, [1105001045]=true, [1105001046]=true, [1105001047]=true, [1105001050]=true, [1105001051]=true, [1105001052]=true,
[1105001053]=true, [1105001058]=true, [1105001059]=true, [1105001060]=true, [1105001061]=true, [1105001063]=true, [1105001064]=true, [1105001065]=true,
[1105001066]=true, [1105001067]=true, [1105001068]=true, [1105001071]=true, [1105001072]=true, [1105001073]=true, [1105001074]=true, [1105002014]=true,
[1105002015]=true, [1105002016]=true, [1105002017]=true, [1105002032]=true, [1105002033]=true, [1105002034]=true, [1105002037]=true, [1105002054]=true,
[1105002055]=true, [1105002056]=true, [1105002057]=true, [1105002059]=true, [1105002060]=true, [1105002061]=true, [1105002062]=true, [1105002067]=true,
[1105002068]=true, [1105002069]=true, [1105002070]=true, [1105002072]=true, [1105002073]=true, [1105002074]=true, [1105002075]=true, [1105002079]=true,
[1105002080]=true, [1105002081]=true, [1105002082]=true, [1105002084]=true, [1105002085]=true, [1105002086]=true, [1105002087]=true, [1105002088]=true,
[1105002089]=true, [1105002090]=true, [1105002094]=true, [1105002095]=true, [1105010004]=true, [1105010005]=true, [1105010006]=true, [1105010007]=true,
[1105010013]=true, [1105010014]=true, [1105010015]=true, [1105010016]=true, [1105010017]=true, [1105010018]=true, [1105010022]=true, [1105010023]=true,
[1105010024]=true, [1105010025]=true, [1106008009]=true, [1106008010]=true, [1106008011]=true, [1106008012]=true, [1106008020]=true, [1106008021]=true,
[1106011001]=true, [1106011002]=true, [1106011004]=true, [1106011005]=true, [1106011006]=true, [1106011007]=true, [1107001016]=true, [1107001017]=true,
[1107098001]=true, [1107098002]=true, [1108001054]=true, [1108001056]=true, [1108001062]=true, [1108001063]=true, [1108001067]=true, [1108001068]=true,
[1108001072]=true, [1108001079]=true, [1108001080]=true, [1108001083]=true, [1108001084]=true, [1108001096]=true, [1108001097]=true, [1108001101]=true,
[1108001102]=true, [1108001105]=true, [1108001106]=true, [1108002054]=true, [1108002056]=true, [1108002057]=true, [1108002058]=true, [1108004128]=true,
[1108004129]=true, [1108004140]=true, [1108004146]=true, [1108004165]=true, [1108004166]=true, [1108004185]=true, [1108004186]=true, [1108004187]=true,
[1108004188]=true, [1108004193]=true, [1108004194]=true, [1108004278]=true, [1108004279]=true, [1108004280]=true, [1108004281]=true, [1108004282]=true,
[1108004328]=true, [1108004329]=true, [1108004330]=true, [1108004331]=true, [1108004332]=true, [1108004354]=true, [1108004355]=true, [1108004363]=true,
[1108004364]=true, [1108004373]=true, [1108004374]=true, [1108004375]=true, [1108004376]=true, [1108004414]=true, [1108004415]=true, [1108005048]=true,
[1108005049]=true, [1501001001]=true, [1501001002]=true, [1501001003]=true, [1501001004]=true, [1501001005]=true, [1501001006]=true, [1501001007]=true,
[1501001008]=true, [1501001009]=true, [1501001011]=true, [1501001012]=true, [1501001013]=true, [1501001014]=true, [1501001015]=true, [1501001016]=true,
[1501001017]=true, [1501001018]=true, [1501001019]=true, [1501001020]=true, [1501001021]=true, [1501001022]=true, [1501001023]=true, [1501001024]=true,
[1501001025]=true, [1501001026]=true, [1501001027]=true, [1501001028]=true, [1501001029]=true, [1501001030]=true, [1501001031]=true, [1501001032]=true,
[1501001033]=true, [1501001034]=true, [1501001035]=true, [1501001036]=true, [1501001037]=true, [1501001038]=true, [1501001039]=true, [1501001041]=true,
[1501001042]=true, [1501001043]=true, [1501001044]=true, [1501001045]=true, [1501001046]=true, [1501001047]=true, [1501001048]=true, [1501001051]=true,
[1501001052]=true, [1501001053]=true, [1501001054]=true, [1501001055]=true, [1501001056]=true, [1501001057]=true, [1501001058]=true, [1501001059]=true,
[1501001060]=true, [1501001061]=true, [1501001062]=true, [1501001063]=true, [1501001064]=true, [1501001065]=true, [1501001066]=true, [1501001067]=true,
[1501001068]=true, [1501001069]=true, [1501001070]=true, [1501001071]=true, [1501001072]=true, [1501001073]=true, [1501001074]=true, [1501001075]=true,
[1501001076]=true, [1501001077]=true, [1501001078]=true, [1501001079]=true, [1501001081]=true, [1501001082]=true, [1501001083]=true, [1501001084]=true,
[1501001085]=true, [1501001086]=true, [1501001087]=true, [1501001088]=true, [1501001089]=true, [1501001090]=true, [1501001091]=true, [1501001092]=true,
[1501001093]=true, [1501001094]=true, [1501001095]=true, [1501001097]=true, [1501001098]=true, [1501001099]=true, [1501001100]=true, [1501001101]=true,
[1501001102]=true, [1501001103]=true, [1501001104]=true, [1501001105]=true, [1501001107]=true, [1501001108]=true, [1501001109]=true, [1501001110]=true,
[1501001112]=true, [1501001114]=true, [1501001115]=true, [1501001116]=true, [1501001118]=true, [1501001120]=true, [1501001122]=true, [1501001123]=true,
[1501001125]=true, [1501001126]=true, [1501001127]=true, [1501001128]=true, [1501001129]=true, [1501001130]=true, [1501001131]=true, [1501001132]=true,
[1501001133]=true, [1501001134]=true, [1501001135]=true, [1501001136]=true, [1501001137]=true, [1501001140]=true, [1501001141]=true, [1501001142]=true,
[1501001143]=true, [1501001144]=true, [1501001145]=true, [1501001146]=true, [1501001147]=true, [1501001149]=true, [1501001150]=true, [1501001151]=true,
[1501001153]=true, [1501001154]=true, [1501001155]=true, [1501001156]=true, [1501001157]=true, [1501001158]=true, [1501001160]=true, [1501001161]=true,
[1501001162]=true, [1501001163]=true, [1501001164]=true, [1501001165]=true, [1501001166]=true, [1501001168]=true, [1501001169]=true, [1501001170]=true,
[1501001171]=true, [1501001172]=true, [1501001173]=true, [1501001174]=true, [1501001175]=true, [1501001176]=true, [1501001177]=true, [1501001178]=true,
[1501001179]=true, [1501001180]=true, [1501001182]=true, [1501001183]=true, [1501001185]=true, [1501001187]=true, [1501001188]=true, [1501001189]=true,
[1501001190]=true, [1501001191]=true, [1501001193]=true, [1501001194]=true, [1501001195]=true, [1501001196]=true, [1501001197]=true, [1501001198]=true,
[1501001199]=true, [1501001200]=true, [1501001201]=true, [1501001202]=true, [1501001204]=true, [1501001205]=true, [1501001206]=true, [1501001207]=true,
[1501001209]=true, [1501001210]=true, [1501001211]=true, [1501001212]=true, [1501001213]=true, [1501001215]=true, [1501001216]=true, [1501001217]=true,
[1501001220]=true, [1501001221]=true, [1501001222]=true, [1501001224]=true, [1501001225]=true, [1501001226]=true, [1501001227]=true, [1501001229]=true,
[1501001231]=true, [1501001233]=true, [1501001236]=true, [1501001237]=true, [1501001238]=true, [1501001239]=true, [1501001240]=true, [1501001241]=true,
[1501001242]=true, [1501001243]=true, [1501001244]=true, [1501001245]=true, [1501001246]=true, [1501001247]=true, [1501001248]=true, [1501001249]=true,
[1501001250]=true, [1501001251]=true, [1501001252]=true, [1501001253]=true, [1501001258]=true, [1501001259]=true, [1501001260]=true, [1501001261]=true,
[1501001262]=true, [1501001263]=true, [1501001265]=true, [1501001266]=true, [1501001267]=true, [1501001268]=true, [1501001269]=true, [1501001270]=true,
[1501001271]=true, [1501001273]=true, [1501001274]=true, [1501001275]=true, [1501001276]=true, [1501001277]=true, [1501001279]=true, [1501001280]=true,
[1501001281]=true, [1501001282]=true, [1501001283]=true, [1501001286]=true, [1501001287]=true, [1501001288]=true, [1501001291]=true, [1501001292]=true,
[1501001293]=true, [1501001294]=true, [1501001295]=true, [1501001296]=true, [1501001297]=true, [1501001298]=true, [1501001300]=true, [1501001301]=true,
[1501001302]=true, [1501001304]=true, [1501001305]=true, [1501001306]=true, [1501001307]=true, [1501001308]=true, [1501001309]=true, [1501001310]=true,
[1501001311]=true, [1501001312]=true, [1501001314]=true, [1501001316]=true, [1501001317]=true, [1501001318]=true, [1501001320]=true, [1501001321]=true,
[1501001323]=true, [1501001324]=true, [1501001325]=true, [1501001326]=true, [1501001330]=true, [1501001331]=true, [1501001332]=true, [1501001333]=true,
[1501001336]=true, [1501001337]=true, [1501001338]=true, [1501001339]=true, [1501001340]=true, [1501001341]=true, [1501001342]=true, [1501001343]=true,
[1501001344]=true, [1501001345]=true, [1501001346]=true, [1501001348]=true, [1501001349]=true, [1501001350]=true, [1501001351]=true, [1501001352]=true,
[1501001354]=true, [1501001355]=true, [1501001356]=true, [1501001357]=true, [1501001359]=true, [1501001361]=true, [1501001362]=true, [1501001363]=true,
[1501001364]=true, [1501001366]=true, [1501001367]=true, [1501001368]=true, [1501001369]=true, [1501001370]=true, [1501001371]=true, [1501001372]=true,
[1501001373]=true, [1501001374]=true, [1501001375]=true, [1501001376]=true, [1501001377]=true, [1501001378]=true, [1501001380]=true, [1501001381]=true,
[1501001383]=true, [1501001384]=true, [1501001385]=true, [1501001386]=true, [1501001387]=true, [1501001388]=true, [1501001389]=true, [1501001390]=true,
[1501001391]=true, [1501001392]=true, [1501001393]=true, [1501001394]=true, [1501001395]=true, [1501001396]=true, [1501001397]=true, [1501001398]=true,
[1501001399]=true, [1501001400]=true, [1501001401]=true, [1501001402]=true, [1501001408]=true, [1501001409]=true, [1501001410]=true, [1501001411]=true,
[1501001412]=true, [1501001414]=true, [1501001415]=true, [1501001416]=true, [1501001417]=true, [1501001418]=true, [1501001419]=true, [1501001420]=true,
[1501001421]=true, [1501001422]=true, [1501001423]=true, [1501001424]=true, [1501001425]=true, [1501001426]=true, [1501001430]=true, [1501001433]=true,
[1501001437]=true, [1501001441]=true, [1501001443]=true, [1501001444]=true, [1501001446]=true, [1501001448]=true, [1501001451]=true, [1501001452]=true,
[1501001453]=true, [1501001454]=true, [1501001457]=true, [1501001458]=true, [1501001459]=true, [1501001462]=true, [1501001463]=true, [1501001466]=true,
[1501001467]=true, [1501001468]=true, [1501001469]=true, [1501001471]=true, [1501001474]=true, [1501001475]=true, [1501001476]=true, [1501001478]=true,
[1501001479]=true, [1501001480]=true, [1501001481]=true, [1501001482]=true, [1501001483]=true, [1501001484]=true, [1501001485]=true, [1501001486]=true,
[1501001487]=true, [1501001489]=true, [1501001490]=true, [1501001492]=true, [1501001494]=true, [1501001495]=true, [1501001496]=true, [1501001497]=true,
[1501001500]=true, [1501001501]=true, [1501001502]=true, [1501001503]=true, [1501001506]=true, [1501001507]=true, [1501001509]=true, [1501001510]=true,
[1501001511]=true, [1501001512]=true, [1501001513]=true, [1501001514]=true, [1501001515]=true, [1501001516]=true, [1501001517]=true, [1501001519]=true,
[1501001520]=true, [1501001521]=true, [1501001522]=true, [1501001523]=true, [1501001524]=true, [1501001525]=true, [1501001526]=true, [1501001527]=true,
[1501001528]=true, [1501001529]=true, [1501001530]=true, [1501001531]=true, [1501001532]=true, [1501001533]=true, [1501001534]=true, [1501001535]=true,
[1501001536]=true, [1501001537]=true, [1501001538]=true, [1501001539]=true, [1501001540]=true, [1501001541]=true, [1501001542]=true, [1501001543]=true,
[1501001544]=true, [1501001545]=true, [1501001546]=true, [1501001547]=true, [1501001548]=true, [1501001549]=true, [1501001550]=true, [1501001551]=true,
[1501001552]=true, [1501001553]=true, [1501001554]=true, [1501001555]=true, [1501001556]=true, [1501001557]=true, [1501001558]=true, [1501001559]=true,
[1501001560]=true, [1501001561]=true, [1501001562]=true, [1501001563]=true, [1501001564]=true, [1501001565]=true, [1501001566]=true, [1501001567]=true,
[1501001568]=true, [1501001569]=true, [1501001570]=true, [1501001571]=true, [1501001572]=true, [1501001573]=true, [1501001574]=true, [1501001575]=true,
[1501001576]=true, [1501001577]=true, [1501001578]=true, [1501001579]=true, [1501001581]=true, [1501001582]=true, [1501001583]=true, [1501001584]=true,
[1501001585]=true, [1501001586]=true, [1501001587]=true, [1501001588]=true, [1501001589]=true, [1501001590]=true, [1501001591]=true, [1501001592]=true,
[1501001593]=true, [1501001594]=true, [1501001595]=true, [1501001596]=true, [1501001597]=true, [1501001598]=true, [1501001599]=true, [1501001600]=true,
[1501001601]=true, [1501001602]=true, [1501001603]=true, [1501001604]=true, [1501001605]=true, [1501001606]=true, [1501001607]=true, [1501001608]=true,
[1501001609]=true, [1501001610]=true, [1501001611]=true, [1501001612]=true, [1501001613]=true, [1501001614]=true, [1501001615]=true, [1501001616]=true,
[1501001617]=true, [1501001618]=true, [1501001619]=true, [1501001620]=true, [1501001621]=true, [1501001622]=true, [1501001623]=true, [1501001624]=true,
[1501001625]=true, [1501001626]=true, [1501001627]=true, [1501001628]=true, [1501001629]=true, [1501001630]=true, [1501001631]=true, [1501001632]=true,
[1501001633]=true, [1501001634]=true, [1501001635]=true, [1501001636]=true, [1501001637]=true, [1501001638]=true, [1501001639]=true, [1501001640]=true,
[1501001641]=true, [1501001642]=true, [1501001643]=true, [1501001644]=true, [1501001645]=true, [1501001646]=true, [1501001647]=true, [1501001648]=true,
[1501001649]=true, [1501001650]=true, [1501001651]=true, [1501001652]=true, [1501001653]=true, [1501001654]=true, [1501001655]=true, [1501001656]=true,
[1501001657]=true, [1501001658]=true, [1501001659]=true, [1501001660]=true, [1501001661]=true, [1501001662]=true, [1501001663]=true, [1501001664]=true,
[1501001665]=true, [1501001666]=true, [1501001667]=true, [1501001668]=true, [1501001669]=true, [1501001670]=true, [1501001671]=true, [1501001672]=true,
[1501001673]=true, [1501001674]=true, [1501001675]=true, [1501001676]=true, [1501001677]=true, [1501001678]=true, [1501001679]=true, [1501001680]=true,
[1501001681]=true, [1501001682]=true, [1501001683]=true, [1501001684]=true, [1501001685]=true, [1501001686]=true, [1501001687]=true, [1501001688]=true,
[1501001689]=true, [1501001690]=true, [1501001691]=true, [1501001692]=true, [1501001693]=true, [1501001694]=true, [1501001695]=true, [1501001696]=true,
[1501001697]=true, [1501001698]=true, [1501001699]=true, [1501001700]=true, [1501001701]=true, [1501001702]=true, [1501001703]=true, [1501001704]=true,
[1501001705]=true, [1501001706]=true, [1501001707]=true, [1501001708]=true, [1501001709]=true, [1501001710]=true, [1501001711]=true, [1501001712]=true,
[1501001713]=true, [1501001714]=true, [1501001715]=true, [1501001716]=true, [1501001717]=true, [1501001718]=true, [1501001719]=true, [1501001720]=true,
[1501001721]=true, [1501001722]=true, [1501001723]=true, [1501001724]=true, [1501001725]=true, [1501001726]=true, [1501001727]=true, [1501001728]=true,
[1501001729]=true, [1501001730]=true, [1501001731]=true, [1501001732]=true, [1501001733]=true, [1501001734]=true, [1501001735]=true, [1501001736]=true,
[1501001737]=true, [1501001738]=true, [1501001739]=true, [1501001740]=true, [1501001741]=true, [1501001742]=true, [1501001743]=true, [1501001744]=true,
[1501001745]=true, [1501001749]=true, [1501002001]=true, [1501002002]=true, [1501002003]=true, [1501002004]=true, [1501002005]=true, [1501002006]=true,
[1501002007]=true, [1501002008]=true, [1501002009]=true, [1501002011]=true, [1501002012]=true, [1501002013]=true, [1501002014]=true, [1501002015]=true,
[1501002016]=true, [1501002017]=true, [1501002018]=true, [1501002019]=true, [1501002020]=true, [1501002021]=true, [1501002022]=true, [1501002023]=true,
[1501002024]=true, [1501002025]=true, [1501002026]=true, [1501002027]=true, [1501002028]=true, [1501002029]=true, [1501002030]=true, [1501002031]=true,
[1501002032]=true, [1501002033]=true, [1501002034]=true, [1501002035]=true, [1501002036]=true, [1501002037]=true, [1501002038]=true, [1501002039]=true,
[1501002041]=true, [1501002042]=true, [1501002043]=true, [1501002044]=true, [1501002045]=true, [1501002046]=true, [1501002047]=true, [1501002048]=true,
[1501002051]=true, [1501002052]=true, [1501002053]=true, [1501002054]=true, [1501002055]=true, [1501002056]=true, [1501002057]=true, [1501002058]=true,
[1501002059]=true, [1501002060]=true, [1501002061]=true, [1501002062]=true, [1501002063]=true, [1501002064]=true, [1501002065]=true, [1501002066]=true,
[1501002067]=true, [1501002068]=true, [1501002069]=true, [1501002070]=true, [1501002071]=true, [1501002072]=true, [1501002073]=true, [1501002074]=true,
[1501002075]=true, [1501002076]=true, [1501002077]=true, [1501002078]=true, [1501002079]=true, [1501002081]=true, [1501002082]=true, [1501002083]=true,
[1501002084]=true, [1501002085]=true, [1501002086]=true, [1501002087]=true, [1501002088]=true, [1501002089]=true, [1501002090]=true, [1501002091]=true,
[1501002092]=true, [1501002093]=true, [1501002094]=true, [1501002095]=true, [1501002097]=true, [1501002098]=true, [1501002099]=true, [1501002100]=true,
[1501002101]=true, [1501002102]=true, [1501002103]=true, [1501002104]=true, [1501002105]=true, [1501002107]=true, [1501002108]=true, [1501002109]=true,
[1501002110]=true, [1501002114]=true, [1501002115]=true, [1501002116]=true, [1501002118]=true, [1501002120]=true, [1501002122]=true, [1501002123]=true,
[1501002125]=true, [1501002126]=true, [1501002127]=true, [1501002128]=true, [1501002129]=true, [1501002130]=true, [1501002131]=true, [1501002132]=true,
[1501002133]=true, [1501002134]=true, [1501002135]=true, [1501002136]=true, [1501002137]=true, [1501002140]=true, [1501002141]=true, [1501002142]=true,
[1501002143]=true, [1501002144]=true, [1501002145]=true, [1501002146]=true, [1501002149]=true, [1501002150]=true, [1501002151]=true, [1501002153]=true,
[1501002154]=true, [1501002155]=true, [1501002156]=true, [1501002157]=true, [1501002158]=true, [1501002160]=true, [1501002161]=true, [1501002162]=true,
[1501002163]=true, [1501002164]=true, [1501002165]=true, [1501002166]=true, [1501002168]=true, [1501002169]=true, [1501002170]=true, [1501002171]=true,
[1501002172]=true, [1501002173]=true, [1501002174]=true, [1501002175]=true, [1501002176]=true, [1501002177]=true, [1501002178]=true, [1501002179]=true,
[1501002180]=true, [1501002182]=true, [1501002183]=true, [1501002185]=true, [1501002187]=true, [1501002188]=true, [1501002189]=true, [1501002190]=true,
[1501002191]=true, [1501002193]=true, [1501002194]=true, [1501002195]=true, [1501002196]=true, [1501002197]=true, [1501002198]=true, [1501002199]=true,
[1501002200]=true, [1501002201]=true, [1501002202]=true, [1501002204]=true, [1501002205]=true, [1501002206]=true, [1501002207]=true, [1501002209]=true,
[1501002210]=true, [1501002211]=true, [1501002212]=true, [1501002213]=true, [1501002215]=true, [1501002216]=true, [1501002217]=true, [1501002220]=true,
[1501002221]=true, [1501002222]=true, [1501002224]=true, [1501002225]=true, [1501002226]=true, [1501002227]=true, [1501002229]=true, [1501002231]=true,
[1501002233]=true, [1501002236]=true, [1501002237]=true, [1501002238]=true, [1501002239]=true, [1501002240]=true, [1501002241]=true, [1501002242]=true,
[1501002243]=true, [1501002244]=true, [1501002245]=true, [1501002246]=true, [1501002247]=true, [1501002248]=true, [1501002249]=true, [1501002250]=true,
[1501002251]=true, [1501002252]=true, [1501002253]=true, [1501002258]=true, [1501002259]=true, [1501002260]=true, [1501002261]=true, [1501002262]=true,
[1501002263]=true, [1501002265]=true, [1501002266]=true, [1501002267]=true, [1501002268]=true, [1501002269]=true, [1501002270]=true, [1501002271]=true,
[1501002273]=true, [1501002274]=true, [1501002275]=true, [1501002276]=true, [1501002277]=true, [1501002279]=true, [1501002280]=true, [1501002281]=true,
[1501002282]=true, [1501002283]=true, [1501002286]=true, [1501002287]=true, [1501002288]=true, [1501002291]=true, [1501002292]=true, [1501002293]=true,
[1501002294]=true, [1501002295]=true, [1501002296]=true, [1501002297]=true, [1501002298]=true, [1501002300]=true, [1501002301]=true, [1501002302]=true,
[1501002304]=true, [1501002305]=true, [1501002306]=true, [1501002307]=true, [1501002308]=true, [1501002309]=true, [1501002310]=true, [1501002311]=true,
[1501002312]=true, [1501002314]=true, [1501002316]=true, [1501002317]=true, [1501002318]=true, [1501002320]=true, [1501002321]=true, [1501002323]=true,
[1501002324]=true, [1501002325]=true, [1501002326]=true, [1501002330]=true, [1501002331]=true, [1501002332]=true, [1501002333]=true, [1501002336]=true,
[1501002337]=true, [1501002338]=true, [1501002339]=true, [1501002340]=true, [1501002341]=true, [1501002342]=true, [1501002343]=true, [1501002344]=true,
[1501002345]=true, [1501002346]=true, [1501002348]=true, [1501002349]=true, [1501002350]=true, [1501002351]=true, [1501002352]=true, [1501002354]=true,
[1501002355]=true, [1501002356]=true, [1501002357]=true, [1501002359]=true, [1501002361]=true, [1501002362]=true, [1501002363]=true, [1501002364]=true,
[1501002366]=true, [1501002367]=true, [1501002368]=true, [1501002369]=true, [1501002370]=true, [1501002371]=true, [1501002372]=true, [1501002373]=true,
[1501002374]=true, [1501002375]=true, [1501002376]=true, [1501002377]=true, [1501002378]=true, [1501002380]=true, [1501002381]=true, [1501002383]=true,
[1501002384]=true, [1501002385]=true, [1501002386]=true, [1501002387]=true, [1501002388]=true, [1501002389]=true, [1501002390]=true, [1501002391]=true,
[1501002392]=true, [1501002393]=true, [1501002394]=true, [1501002395]=true, [1501002396]=true, [1501002397]=true, [1501002398]=true, [1501002399]=true,
[1501002400]=true, [1501002401]=true, [1501002402]=true, [1501002408]=true, [1501002409]=true, [1501002410]=true, [1501002411]=true, [1501002412]=true,
[1501002414]=true, [1501002415]=true, [1501002416]=true, [1501002417]=true, [1501002418]=true, [1501002419]=true, [1501002420]=true, [1501002421]=true,
[1501002422]=true, [1501002423]=true, [1501002424]=true, [1501002425]=true, [1501002426]=true, [1501002430]=true, [1501002433]=true, [1501002437]=true,
[1501002441]=true, [1501002443]=true, [1501002444]=true, [1501002446]=true, [1501002448]=true, [1501002451]=true, [1501002452]=true, [1501002453]=true,
[1501002454]=true, [1501002457]=true, [1501002458]=true, [1501002459]=true, [1501002462]=true, [1501002463]=true, [1501002466]=true, [1501002467]=true,
[1501002468]=true, [1501002469]=true, [1501002471]=true, [1501002474]=true, [1501002475]=true, [1501002476]=true, [1501002478]=true, [1501002479]=true,
[1501002480]=true, [1501002481]=true, [1501002482]=true, [1501002483]=true, [1501002484]=true, [1501002485]=true, [1501002486]=true, [1501002487]=true,
[1501002489]=true, [1501002490]=true, [1501002492]=true, [1501002494]=true, [1501002495]=true, [1501002496]=true, [1501002497]=true, [1501002500]=true,
[1501002501]=true, [1501002502]=true, [1501002503]=true, [1501002506]=true, [1501002507]=true, [1501002509]=true, [1501002510]=true, [1501002511]=true,
[1501002512]=true, [1501002513]=true, [1501002514]=true, [1501002515]=true, [1501002516]=true, [1501002517]=true, [1501002519]=true, [1501002520]=true,
[1501002521]=true, [1501002522]=true, [1501002523]=true, [1501002524]=true, [1501002525]=true, [1501002526]=true, [1501002527]=true, [1501002528]=true,
[1501002529]=true, [1501002530]=true, [1501002531]=true, [1501002532]=true, [1501002533]=true, [1501002534]=true, [1501002535]=true, [1501002536]=true,
[1501002537]=true, [1501002538]=true, [1501002539]=true, [1501002540]=true, [1501002541]=true, [1501002542]=true, [1501002543]=true, [1501002544]=true,
[1501002545]=true, [1501002546]=true, [1501002547]=true, [1501002548]=true, [1501002549]=true, [1501002550]=true, [1501002551]=true, [1501002552]=true,
[1501002553]=true, [1501002554]=true, [1501002555]=true, [1501002556]=true, [1501002557]=true, [1501002558]=true, [1501002559]=true, [1501002562]=true,
[1501002563]=true, [1501002564]=true, [1501002565]=true, [1501002566]=true, [1501002567]=true, [1501002568]=true, [1501002569]=true, [1501002570]=true,
[1501002571]=true, [1501002572]=true, [1501002573]=true, [1501002574]=true, [1501002575]=true, [1501002576]=true, [1501002577]=true, [1501002578]=true,
[1501002579]=true, [1501002581]=true, [1501002582]=true, [1501002583]=true, [1501002584]=true, [1501002585]=true, [1501002586]=true, [1501002587]=true,
[1501002588]=true, [1501002589]=true, [1501002590]=true, [1501002591]=true, [1501002592]=true, [1501002593]=true, [1501002594]=true, [1501002595]=true,
[1501002596]=true, [1501002597]=true, [1501002598]=true, [1501002599]=true, [1501002600]=true, [1501002601]=true, [1501002602]=true, [1501002603]=true,
[1501002604]=true, [1501002605]=true, [1501002606]=true, [1501002607]=true, [1501002608]=true, [1501002609]=true, [1501002610]=true, [1501002611]=true,
[1501002612]=true, [1501002613]=true, [1501002614]=true, [1501002615]=true, [1501002616]=true, [1501002617]=true, [1501002618]=true, [1501002619]=true,
[1501002620]=true, [1501002621]=true, [1501002622]=true, [1501002623]=true, [1501002624]=true, [1501002625]=true, [1501002626]=true, [1501002627]=true,
[1501002628]=true, [1501002629]=true, [1501002630]=true, [1501002631]=true, [1501002632]=true, [1501002633]=true, [1501002634]=true, [1501002635]=true,
[1501002636]=true, [1501002637]=true, [1501002638]=true, [1501002639]=true, [1501002640]=true, [1501002641]=true, [1501002642]=true, [1501002643]=true,
[1501002644]=true, [1501002645]=true, [1501002646]=true, [1501002647]=true, [1501002648]=true, [1501002649]=true, [1501002650]=true, [1501002651]=true,
[1501002652]=true, [1501002653]=true, [1501002654]=true, [1501002655]=true, [1501002656]=true, [1501002657]=true, [1501002658]=true, [1501002659]=true,
[1501002660]=true, [1501002661]=true, [1501002662]=true, [1501002663]=true, [1501002664]=true, [1501002665]=true, [1501002666]=true, [1501002667]=true,
[1501002668]=true, [1501002669]=true, [1501002670]=true, [1501002671]=true, [1501002672]=true, [1501002673]=true, [1501002674]=true, [1501002675]=true,
[1501002676]=true, [1501002677]=true, [1501002678]=true, [1501002679]=true, [1501002680]=true, [1501002681]=true, [1501002682]=true, [1501002683]=true,
[1501002684]=true, [1501002685]=true, [1501002686]=true, [1501002687]=true, [1501002688]=true, [1501002689]=true, [1501002690]=true, [1501002691]=true,
[1501002692]=true, [1501002693]=true, [1501002694]=true, [1501002695]=true, [1501002696]=true, [1501002697]=true, [1501002698]=true, [1501002699]=true,
[1501002700]=true, [1501002701]=true, [1501002702]=true, [1501002703]=true, [1501002704]=true, [1501002705]=true, [1501002706]=true, [1501002707]=true,
[1501002708]=true, [1501002709]=true, [1501002710]=true, [1501002711]=true, [1501002712]=true, [1501002713]=true, [1501002714]=true, [1501002715]=true,
[1501002716]=true, [1501002717]=true, [1501002718]=true, [1501002719]=true, [1501002720]=true, [1501002721]=true, [1501002722]=true, [1501002723]=true,
[1501002724]=true, [1501002725]=true, [1501002726]=true, [1501002727]=true, [1501002728]=true, [1501002729]=true, [1501002731]=true, [1501002732]=true,
[1501002733]=true, [1501002734]=true, [1501002735]=true, [1501002736]=true, [1501002737]=true, [1501002738]=true, [1501002739]=true, [1501002740]=true,
[1501002741]=true, [1501002742]=true, [1501002743]=true, [1501002744]=true, [1501002745]=true, [1501002749]=true, [1501003061]=true, [1501003164]=true,
[1501003243]=true, [1501003385]=true, [1501003536]=true, [1501003640]=true, [1502000100]=true, [1502001001]=true, [1502001002]=true, [1502001003]=true,
[1502001004]=true, [1502001005]=true, [1502001006]=true, [1502001008]=true, [1502001009]=true, [1502001012]=true, [1502001013]=true, [1502001014]=true,
[1502001015]=true, [1502001016]=true, [1502001017]=true, [1502001018]=true, [1502001019]=true, [1502001020]=true, [1502001021]=true, [1502001022]=true,
[1502001023]=true, [1502001025]=true, [1502001026]=true, [1502001027]=true, [1502001028]=true, [1502001029]=true, [1502001030]=true, [1502001031]=true,
[1502001032]=true, [1502001033]=true, [1502001034]=true, [1502001035]=true, [1502001036]=true, [1502001037]=true, [1502001038]=true, [1502001039]=true,
[1502001040]=true, [1502001041]=true, [1502001042]=true, [1502001043]=true, [1502001044]=true, [1502001045]=true, [1502001046]=true, [1502001047]=true,
[1502001048]=true, [1502001049]=true, [1502001050]=true, [1502001051]=true, [1502001052]=true, [1502001053]=true, [1502001054]=true, [1502001055]=true,
[1502001058]=true, [1502001060]=true, [1502001062]=true, [1502001063]=true, [1502001064]=true, [1502001065]=true, [1502001069]=true, [1502001070]=true,
[1502001071]=true, [1502001072]=true, [1502001073]=true, [1502001074]=true, [1502001075]=true, [1502001076]=true, [1502001077]=true, [1502001078]=true,
[1502001079]=true, [1502001080]=true, [1502001081]=true, [1502001082]=true, [1502001084]=true, [1502001085]=true, [1502001086]=true, [1502001087]=true,
[1502001088]=true, [1502001089]=true, [1502001090]=true, [1502001091]=true, [1502001092]=true, [1502001093]=true, [1502001094]=true, [1502001096]=true,
[1502001097]=true, [1502001098]=true, [1502001099]=true, [1502001100]=true, [1502001101]=true, [1502001102]=true, [1502001103]=true, [1502001104]=true,
[1502001105]=true, [1502001106]=true, [1502001107]=true, [1502001108]=true, [1502001109]=true, [1502001110]=true, [1502001111]=true, [1502001113]=true,
[1502001114]=true, [1502001115]=true, [1502001116]=true, [1502001119]=true, [1502001121]=true, [1502001123]=true, [1502001124]=true, [1502001125]=true,
[1502001126]=true, [1502001127]=true, [1502001128]=true, [1502001129]=true, [1502001130]=true, [1502001132]=true, [1502001133]=true, [1502001134]=true,
[1502001135]=true, [1502001136]=true, [1502001137]=true, [1502001138]=true, [1502001141]=true, [1502001143]=true, [1502001145]=true, [1502001146]=true,
[1502001149]=true, [1502001150]=true, [1502001151]=true, [1502001154]=true, [1502001155]=true, [1502001156]=true, [1502001157]=true, [1502001159]=true,
[1502001160]=true, [1502001163]=true, [1502001164]=true, [1502001165]=true, [1502001167]=true, [1502001169]=true, [1502001170]=true, [1502001171]=true,
[1502001172]=true, [1502001173]=true, [1502001174]=true, [1502001175]=true, [1502001177]=true, [1502001179]=true, [1502001180]=true, [1502001181]=true,
[1502001182]=true, [1502001183]=true, [1502001184]=true, [1502001185]=true, [1502001186]=true, [1502001187]=true, [1502001189]=true, [1502001190]=true,
[1502001191]=true, [1502001192]=true, [1502001193]=true, [1502001194]=true, [1502001195]=true, [1502001196]=true, [1502001197]=true, [1502001198]=true,
[1502001199]=true, [1502001200]=true, [1502001201]=true, [1502001202]=true, [1502001203]=true, [1502001204]=true, [1502001205]=true, [1502001207]=true,
[1502001209]=true, [1502001210]=true, [1502001211]=true, [1502001214]=true, [1502001217]=true, [1502001219]=true, [1502001220]=true, [1502001221]=true,
[1502001222]=true, [1502001223]=true, [1502001224]=true, [1502001225]=true, [1502001227]=true, [1502001228]=true, [1502001229]=true, [1502001230]=true,
[1502001231]=true, [1502001232]=true, [1502001233]=true, [1502001234]=true, [1502001235]=true, [1502001236]=true, [1502001237]=true, [1502001238]=true,
[1502001239]=true, [1502001241]=true, [1502001242]=true, [1502001243]=true, [1502001244]=true, [1502001246]=true, [1502001247]=true, [1502001248]=true,
[1502001249]=true, [1502001252]=true, [1502001253]=true, [1502001254]=true, [1502001255]=true, [1502001256]=true, [1502001257]=true, [1502001258]=true,
[1502001259]=true, [1502001260]=true, [1502001261]=true, [1502001263]=true, [1502001264]=true, [1502001265]=true, [1502001267]=true, [1502001268]=true,
[1502001269]=true, [1502001270]=true, [1502001271]=true, [1502001272]=true, [1502001273]=true, [1502001274]=true, [1502001275]=true, [1502001276]=true,
[1502001277]=true, [1502001278]=true, [1502001279]=true, [1502001280]=true, [1502001284]=true, [1502001285]=true, [1502001286]=true, [1502001287]=true,
[1502001288]=true, [1502001289]=true, [1502001290]=true, [1502001292]=true, [1502001293]=true, [1502001294]=true, [1502001295]=true, [1502001297]=true,
[1502001298]=true, [1502001299]=true, [1502001300]=true, [1502001301]=true, [1502001302]=true, [1502001305]=true, [1502001306]=true, [1502001307]=true,
[1502001309]=true, [1502001311]=true, [1502001314]=true, [1502001315]=true, [1502001317]=true, [1502001320]=true, [1502001322]=true, [1502001323]=true,
[1502001325]=true, [1502001327]=true, [1502001328]=true, [1502001330]=true, [1502001332]=true, [1502001333]=true, [1502001335]=true, [1502001336]=true,
[1502001337]=true, [1502001338]=true, [1502001339]=true, [1502001341]=true, [1502001342]=true, [1502001343]=true, [1502001344]=true, [1502001345]=true,
[1502001346]=true, [1502001347]=true, [1502001348]=true, [1502001349]=true, [1502001350]=true, [1502001351]=true, [1502001352]=true, [1502001353]=true,
[1502001354]=true, [1502001355]=true, [1502001357]=true, [1502001358]=true, [1502001359]=true, [1502001360]=true, [1502001361]=true, [1502001362]=true,
[1502001363]=true, [1502001364]=true, [1502001365]=true, [1502001366]=true, [1502001367]=true, [1502001368]=true, [1502001369]=true, [1502001370]=true,
[1502001371]=true, [1502001372]=true, [1502001373]=true, [1502001374]=true, [1502001375]=true, [1502001376]=true, [1502001377]=true, [1502001378]=true,
[1502001379]=true, [1502001381]=true, [1502001382]=true, [1502001383]=true, [1502001384]=true, [1502001385]=true, [1502001386]=true, [1502001387]=true,
[1502001388]=true, [1502001389]=true, [1502001390]=true, [1502001391]=true, [1502001392]=true, [1502001393]=true, [1502001394]=true, [1502001395]=true,
[1502001396]=true, [1502001397]=true, [1502001398]=true, [1502001399]=true, [1502001400]=true, [1502001401]=true, [1502001402]=true, [1502001403]=true,
[1502001404]=true, [1502001405]=true, [1502001406]=true, [1502001407]=true, [1502001408]=true, [1502001409]=true, [1502001410]=true, [1502001411]=true,
[1502001412]=true, [1502001413]=true, [1502001414]=true, [1502001415]=true, [1502001416]=true, [1502001417]=true, [1502001418]=true, [1502001419]=true,
[1502001420]=true, [1502001421]=true, [1502001422]=true, [1502001423]=true, [1502001424]=true, [1502001425]=true, [1502001426]=true, [1502001427]=true,
[1502001428]=true, [1502001429]=true, [1502001430]=true, [1502001431]=true, [1502001432]=true, [1502001433]=true, [1502001434]=true, [1502001435]=true,
[1502001436]=true, [1502001437]=true, [1502001438]=true, [1502001439]=true, [1502001440]=true, [1502001441]=true, [1502001442]=true, [1502001443]=true,
[1502001444]=true, [1502001445]=true, [1502001446]=true, [1502001447]=true, [1502001448]=true, [1502001449]=true, [1502001450]=true, [1502001451]=true,
[1502001452]=true, [1502001453]=true, [1502001454]=true, [1502001455]=true, [1502001456]=true, [1502001457]=true, [1502001458]=true, [1502001459]=true,
[1502001460]=true, [1502001461]=true, [1502001462]=true, [1502001463]=true, [1502001464]=true, [1502001465]=true, [1502001466]=true, [1502001467]=true,
[1502001468]=true, [1502001469]=true, [1502001470]=true, [1502001471]=true, [1502001472]=true, [1502001473]=true, [1502001474]=true, [1502001475]=true,
[1502001476]=true, [1502001477]=true, [1502001478]=true, [1502001479]=true, [1502001480]=true, [1502001481]=true, [1502001482]=true, [1502001483]=true,
[1502001484]=true, [1502001485]=true, [1502001486]=true, [1502001487]=true, [1502001488]=true, [1502001489]=true, [1502001490]=true, [1502001491]=true,
[1502001492]=true, [1502001493]=true, [1502001494]=true, [1502001495]=true, [1502001496]=true, [1502001497]=true, [1502001498]=true, [1502001499]=true,
[1502001500]=true, [1502001501]=true, [1502001502]=true, [1502001503]=true, [1502001504]=true, [1502001505]=true, [1502001506]=true, [1502001507]=true,
[1502001508]=true, [1502001509]=true, [1502001510]=true, [1502001511]=true, [1502001512]=true, [1502001515]=true, [1502002001]=true, [1502002002]=true,
[1502002003]=true, [1502002004]=true, [1502002005]=true, [1502002006]=true, [1502002008]=true, [1502002009]=true, [1502002012]=true, [1502002013]=true,
[1502002014]=true, [1502002015]=true, [1502002016]=true, [1502002017]=true, [1502002018]=true, [1502002019]=true, [1502002020]=true, [1502002021]=true,
[1502002022]=true, [1502002023]=true, [1502002025]=true, [1502002026]=true, [1502002027]=true, [1502002028]=true, [1502002029]=true, [1502002030]=true,
[1502002031]=true, [1502002032]=true, [1502002033]=true, [1502002034]=true, [1502002035]=true, [1502002036]=true, [1502002037]=true, [1502002038]=true,
[1502002039]=true, [1502002040]=true, [1502002041]=true, [1502002042]=true, [1502002043]=true, [1502002044]=true, [1502002045]=true, [1502002046]=true,
[1502002047]=true, [1502002048]=true, [1502002049]=true, [1502002050]=true, [1502002051]=true, [1502002052]=true, [1502002053]=true, [1502002054]=true,
[1502002055]=true, [1502002058]=true, [1502002060]=true, [1502002062]=true, [1502002063]=true, [1502002064]=true, [1502002065]=true, [1502002069]=true,
[1502002070]=true, [1502002071]=true, [1502002072]=true, [1502002073]=true, [1502002074]=true, [1502002075]=true, [1502002076]=true, [1502002077]=true,
[1502002078]=true, [1502002079]=true, [1502002080]=true, [1502002081]=true, [1502002082]=true, [1502002084]=true, [1502002085]=true, [1502002086]=true,
[1502002087]=true, [1502002088]=true, [1502002089]=true, [1502002090]=true, [1502002091]=true, [1502002092]=true, [1502002093]=true, [1502002094]=true,
[1502002096]=true, [1502002097]=true, [1502002098]=true, [1502002099]=true, [1502002100]=true, [1502002101]=true, [1502002102]=true, [1502002103]=true,
[1502002104]=true, [1502002105]=true, [1502002106]=true, [1502002107]=true, [1502002108]=true, [1502002109]=true, [1502002110]=true, [1502002111]=true,
[1502002113]=true, [1502002114]=true, [1502002115]=true, [1502002116]=true, [1502002119]=true, [1502002121]=true, [1502002123]=true, [1502002124]=true,
[1502002125]=true, [1502002126]=true, [1502002127]=true, [1502002128]=true, [1502002129]=true, [1502002130]=true, [1502002132]=true, [1502002133]=true,
[1502002134]=true, [1502002135]=true, [1502002136]=true, [1502002137]=true, [1502002138]=true, [1502002141]=true, [1502002143]=true, [1502002145]=true,
[1502002146]=true, [1502002149]=true, [1502002150]=true, [1502002151]=true, [1502002154]=true, [1502002155]=true, [1502002156]=true, [1502002157]=true,
[1502002159]=true, [1502002160]=true, [1502002163]=true, [1502002164]=true, [1502002165]=true, [1502002167]=true, [1502002169]=true, [1502002170]=true,
[1502002171]=true, [1502002172]=true, [1502002173]=true, [1502002174]=true, [1502002175]=true, [1502002177]=true, [1502002179]=true, [1502002180]=true,
[1502002181]=true, [1502002182]=true, [1502002183]=true, [1502002184]=true, [1502002185]=true, [1502002186]=true, [1502002187]=true, [1502002189]=true,
[1502002190]=true, [1502002191]=true, [1502002192]=true, [1502002193]=true, [1502002194]=true, [1502002195]=true, [1502002196]=true, [1502002197]=true,
[1502002198]=true, [1502002199]=true, [1502002200]=true, [1502002201]=true, [1502002202]=true, [1502002203]=true, [1502002204]=true, [1502002205]=true,
[1502002207]=true, [1502002209]=true, [1502002210]=true, [1502002211]=true, [1502002214]=true, [1502002217]=true, [1502002219]=true, [1502002220]=true,
[1502002221]=true, [1502002222]=true, [1502002223]=true, [1502002224]=true, [1502002225]=true, [1502002227]=true, [1502002228]=true, [1502002229]=true,
[1502002230]=true, [1502002231]=true, [1502002232]=true, [1502002233]=true, [1502002234]=true, [1502002235]=true, [1502002236]=true, [1502002237]=true,
[1502002238]=true, [1502002239]=true, [1502002241]=true, [1502002242]=true, [1502002243]=true, [1502002244]=true, [1502002246]=true, [1502002247]=true,
[1502002248]=true, [1502002249]=true, [1502002252]=true, [1502002253]=true, [1502002254]=true, [1502002255]=true, [1502002256]=true, [1502002257]=true,
[1502002258]=true, [1502002259]=true, [1502002260]=true, [1502002261]=true, [1502002263]=true, [1502002264]=true, [1502002265]=true, [1502002267]=true,
[1502002268]=true, [1502002269]=true, [1502002270]=true, [1502002271]=true, [1502002272]=true, [1502002273]=true, [1502002274]=true, [1502002275]=true,
[1502002276]=true, [1502002277]=true, [1502002278]=true, [1502002279]=true, [1502002280]=true, [1502002284]=true, [1502002285]=true, [1502002286]=true,
[1502002287]=true, [1502002288]=true, [1502002289]=true, [1502002290]=true, [1502002292]=true, [1502002293]=true, [1502002294]=true, [1502002295]=true,
[1502002297]=true, [1502002298]=true, [1502002299]=true, [1502002300]=true, [1502002301]=true, [1502002302]=true, [1502002305]=true, [1502002306]=true,
[1502002307]=true, [1502002309]=true, [1502002311]=true, [1502002314]=true, [1502002315]=true, [1502002317]=true, [1502002320]=true, [1502002322]=true,
[1502002323]=true, [1502002325]=true, [1502002327]=true, [1502002328]=true, [1502002330]=true, [1502002332]=true, [1502002333]=true, [1502002335]=true,
[1502002336]=true, [1502002337]=true, [1502002338]=true, [1502002339]=true, [1502002341]=true, [1502002342]=true, [1502002343]=true, [1502002344]=true,
[1502002345]=true, [1502002346]=true, [1502002347]=true, [1502002348]=true, [1502002349]=true, [1502002350]=true, [1502002351]=true, [1502002352]=true,
[1502002353]=true, [1502002354]=true, [1502002355]=true, [1502002357]=true, [1502002358]=true, [1502002359]=true, [1502002360]=true, [1502002361]=true,
[1502002362]=true, [1502002363]=true, [1502002364]=true, [1502002365]=true, [1502002366]=true, [1502002367]=true, [1502002368]=true, [1502002369]=true,
[1502002370]=true, [1502002371]=true, [1502002372]=true, [1502002373]=true, [1502002374]=true, [1502002375]=true, [1502002376]=true, [1502002377]=true,
[1502002378]=true, [1502002379]=true, [1502002381]=true, [1502002382]=true, [1502002383]=true, [1502002384]=true, [1502002385]=true, [1502002386]=true,
[1502002387]=true, [1502002388]=true, [1502002389]=true, [1502002390]=true, [1502002391]=true, [1502002392]=true, [1502002393]=true, [1502002394]=true,
[1502002395]=true, [1502002396]=true, [1502002397]=true, [1502002398]=true, [1502002399]=true, [1502002400]=true, [1502002401]=true, [1502002402]=true,
[1502002403]=true, [1502002404]=true, [1502002405]=true, [1502002406]=true, [1502002407]=true, [1502002408]=true, [1502002409]=true, [1502002410]=true,
[1502002411]=true, [1502002412]=true, [1502002413]=true, [1502002414]=true, [1502002415]=true, [1502002416]=true, [1502002417]=true, [1502002418]=true,
[1502002419]=true, [1502002420]=true, [1502002421]=true, [1502002422]=true, [1502002423]=true, [1502002424]=true, [1502002425]=true, [1502002426]=true,
[1502002427]=true, [1502002428]=true, [1502002429]=true, [1502002430]=true, [1502002431]=true, [1502002432]=true, [1502002433]=true, [1502002434]=true,
[1502002435]=true, [1502002436]=true, [1502002437]=true, [1502002438]=true, [1502002439]=true, [1502002440]=true, [1502002441]=true, [1502002442]=true,
[1502002443]=true, [1502002444]=true, [1502002445]=true, [1502002446]=true, [1502002447]=true, [1502002448]=true, [1502002449]=true, [1502002450]=true,
[1502002451]=true, [1502002453]=true, [1502002454]=true, [1502002455]=true, [1502002456]=true, [1502002457]=true, [1502002458]=true, [1502002459]=true,
[1502002460]=true, [1502002461]=true, [1502002462]=true, [1502002463]=true, [1502002464]=true, [1502002465]=true, [1502002466]=true, [1502002467]=true,
[1502002468]=true, [1502002469]=true, [1502002470]=true, [1502002471]=true, [1502002472]=true, [1502002473]=true, [1502002474]=true, [1502002475]=true,
[1502002476]=true, [1502002477]=true, [1502002478]=true, [1502002479]=true, [1502002480]=true, [1502002481]=true, [1502002482]=true, [1502002483]=true,
[1502002484]=true, [1502002485]=true, [1502002486]=true, [1502002487]=true, [1502002488]=true, [1502002489]=true, [1502002490]=true, [1502002491]=true,
[1502002492]=true, [1502002493]=true, [1502002494]=true, [1502002495]=true, [1502002496]=true, [1502002497]=true, [1502002498]=true, [1502002499]=true,
[1502002500]=true, [1502002501]=true, [1502002502]=true, [1502002503]=true, [1502002504]=true, [1502002505]=true, [1502002506]=true, [1502002507]=true,
[1502002508]=true, [1502002509]=true, [1502002510]=true, [1502002511]=true, [1502002512]=true, [1502002515]=true, [1502003309]=true
}

_G.X3.Inj = _G.X3.Inj or {
    resToIns = {}, insToRes = {},
    cache = { outfitRes = nil, outfitIns = nil, weapons = {} },
    hooksInstalled = false, itemsBuilt = false,
    injectDone = false, injectRunning = false, injectIdx = 1,
    items = {},
}

-- konstanta subtype item (dari referensi)
_G.X3.InjGunSub = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
_G.X3.InjST = { TOP=403, PANTS=404, SHOES=405, UNDER_T=450, UNDER_P=451, MELEE=108 }

-- INJ CFG --
_G.X3.InjCfg = function(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    local ok, r = pcall(CDataTable.GetTableData, "Item", resID)
    return ok and r or nil
end

-- INJ SUB TYPE --
_G.X3.InjSubType = function(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

-- INJ WARDROBE TAB --
_G.X3.InjWardrobeTab = function(resID, depotData)
    if depotData and depotData.subTabType then return tonumber(depotData.subTabType) end
    local c = _G.X3.InjCfg(resID)
    return c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
end

-- INJ IS FULL SUIT --
_G.X3.InjIsFullSuit = function(resID, depotData)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    local ok, xs = pcall(function()
        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
        return LogicXSuit.IsXSuit(resID)
    end)
    if ok and xs then return true end
    local tab = _G.X3.InjWardrobeTab(resID, depotData)
    if tab == 10 then return true end
    if tab == 3 then return false end
    return _G.X3.InjSubType(_G.X3.InjCfg(resID)) == _G.X3.InjST.TOP
end

-- INJ CLOTH KIND --
_G.X3.InjClothKind = function(resID, depotData)
    resID = tonumber(resID)
    if not resID then return nil end
    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
    if st == _G.X3.InjST.TOP then return _G.X3.InjIsFullSuit(resID, depotData) and "full_suit" or "top" end
    if st == _G.X3.InjST.PANTS then return "pants" end
    if st == _G.X3.InjST.SHOES then return "shoes" end
    if st == _G.X3.InjST.UNDER_T then return "under_top" end
    if st == _G.X3.InjST.UNDER_P then return "under_pants" end
    return nil
end

-- INJ CLEAR MAP FOR KIND --
_G.X3.InjClearMapForKind = function(kind)
    local ST = _G.X3.InjST
    if kind == "full_suit" then return { [ST.TOP]=true, [ST.PANTS]=true, [ST.SHOES]=true, [ST.UNDER_T]=true, [ST.UNDER_P]=true } end
    if kind == "top" then return { [ST.TOP]=true } end
    if kind == "pants" then return { [ST.PANTS]=true } end
    if kind == "shoes" then return { [ST.SHOES]=true } end
    if kind == "under_top" then return { [ST.UNDER_T]=true } end
    if kind == "under_pants" then return { [ST.UNDER_P]=true } end
    return nil
end

-- INJ WEAPON ID FROM SKIN --
_G.X3.InjWeaponIdFromSkin = function(resID)
    local ok, m = pcall(function()
        if CDataTable and CDataTable.GetTableData then
            return CDataTable.GetTableData("WeaponSkinMapping", resID)
        end
        return nil
    end)
    if ok and m then return m.WeaponID or m.WeaponId end
    local s = tostring(tonumber(resID))
    if #s == 10 and s:sub(1, 2) == "11" then
        return tonumber("1" .. s:sub(3, 7))
    end
    return nil
end

-- INJ CLASSIFY --
_G.X3.InjClassify = function(resID)
    local n = tonumber(resID) or 0
    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
    if st then
        if _G.X3.InjGunSub[st] then return "Gun" end
        if st == _G.X3.InjST.TOP then return "Top" end
        if st == _G.X3.InjST.PANTS then return "Pants" end
        if st == _G.X3.InjST.SHOES then return "Shoes" end
    end
    if n >= 1501000000 and n < 1502000000 then return "Bag" end
    if n >= 1502000000 and n < 1503000000 then return "Helmet" end
    if n >= 501000 and n <= 501999 then return "Bag" end
    if n >= 502000 and n <= 502999 then return "Helmet" end
    if n >= 404000 and n <= 404999 then return "Pants" end
    if n >= 405000 and n <= 405999 then return "Shoes" end
    if n >= 1900000 and n < 2000000 then return "Vehicle" end
    if n >= 1400000 and n < 1500000 then return "Suit" end
    if n >= 400000 and n < 410000 then return "Suit" end
    return nil
end

-- INJ IS INJECTED INS --
_G.X3.InjIsInjectedIns = function(ins) return ins and _G.X3.Inj.insToRes[tonumber(ins)] ~= nil end
-- INJ IS INJECTED RES --
_G.X3.InjIsInjectedRes = function(res) return res and _G.X3.Inj.resToIns[tonumber(res)] ~= nil end

-- INJ GET ENTITY --
_G.X3.InjGetEntity = function()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

-- INJ ALREADY HAVE --
_G.X3.InjAlreadyHave = function(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if arr then
        for _, idx in pairs(arr) do
            local d = entity._data and entity._data[idx]
            if d and (d.count or 0) > 0 then return true end
        end
    end
    local ok, d = pcall(function() return entity:GetDataByResID(resID) end)
    if ok and type(d) == "table" then
        if d.res_id or d.resID then return true end
        if #d > 0 then return true end
    end
    return false
end

-- INJ INJECT ONE --
_G.X3.InjInjectOne = function(entity, resID, insID)
    local st = _G.X3.Inj
    if st.injectedEntity ~= entity then
        st.injectedEntity = entity
        st.injectedRes = {}
    end
    st.injectedRes = st.injectedRes or {}
    if st.injectedRes[resID] then return true end
    if _G.X3.InjAlreadyHave(entity, resID) then
        st.injectedRes[resID] = true
        _G.X3.Inj.resToIns[resID] = _G.X3.Inj.resToIns[resID] or insID
        _G.X3.Inj.insToRes[insID] = resID
        return true
    end
    local row = { instid = insID, res_id = resID, count = 1, lock_cnt = 0, isnew = 0, valid_hours = 0, expire_ts = 0 }
    if _G.X3._LTry then _G.X3._LTry("SKIN Wardrobe AddData") end
    if _G.X3._LCall then _G.X3._LCall("SKIN entity:AddData", function() entity:AddData(row) end) else entity:AddData(row) end
    if (_G.X3.Inj.phase or 1) == 1 then
        pcall(function()
            local data = entity.GetDataByInsID and entity:GetDataByInsID(insID)
            if data and entity.LoadConfigForData and CDataTable and CDataTable.GetTableData then
                entity:LoadConfigForData(data, CDataTable.GetTableData)
            end
        end)
    end
    st.injectedRes[resID] = true
    _G.X3.Inj.insToRes[insID] = resID
    _G.X3.Inj.resToIns[resID] = insID
    return true
end

-- INJ INJECT ARMORY --
_G.X3.InjInjectArmory = function(resID, insID)
    local wid = _G.X3.InjWeaponIdFromSkin(resID)
    if not wid then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
    Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
    Arm.WardrobeInsList = Arm.WardrobeInsList or {}
    Arm.WardrobeInsList[resID] = insID
end

-- INJ REFRESH WARDROBE --
_G.X3.InjRefreshWardrobe = function()
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_GUN_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
            end
        end
    end)
end

-- INJ REMOVE ROLE WEAR BY SUB TYPES --
_G.X3.InjRemoveRoleWearBySubTypes = function(stMap)
    if not stMap then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, insRaw in pairs(AvatarData.GetRoleWear()) do
        local ins = tonumber(insRaw)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and stMap[tonumber(d.itemSubType)] then
                AvatarData.RemoveRoleWearDataByValue(ins)
            end
        end
    end
end

-- INJ CLEAR FASHION BAG SLOTS --
_G.X3.InjClearFashionBagSlots = function(stMap)
    if not stMap then return end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if not bag or not bag.rolewear_list then return end
        for st, _ in pairs(stMap) do
            local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
            if idx then bag.rolewear_list[idx] = 0 end
        end
    end)
end

-- INJ SYNC FASHION BAG ROLEWEAR --
_G.X3.InjSyncFashionBagRolewear = function()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

-- INJ FIND WORN INS BY SUB TYPE --
_G.X3.InjFindWornInsBySubType = function(st)
    st = tonumber(st)
    if not st then return nil end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, insRaw in pairs(AvatarData.GetRoleWear()) do
        local ins = tonumber(insRaw)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then return ins, d.resID end
        end
    end
    return nil
end

-- INJ SAVE EQUIP --
_G.X3.InjSaveEquip = function(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local cch = _G.X3.Inj.cache
    local cData = _G.X3.LexusState and _G.X3.LexusState.CustomTextData
    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
    local kind = _G.X3.InjClassify(resID)
    if _G.X3.InjClothKind(resID) == "full_suit" or kind == "Suit" or kind == "Top" then
        cch.outfitRes, cch.outfitIns = resID, insID
        _G.X3.OutfitMap.Suit = resID
        if cData then cData.LobbySuit = resID end
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE suit " .. tostring(resID)) end
    elseif st and _G.X3.InjGunSub[st] then
        local wid = _G.X3.InjWeaponIdFromSkin(resID)
        if wid then
            cch.weapons[wid] = { resID = resID, insID = insID }
            _G.X3.WeaponSkinMap[wid] = resID
            if cData then cData["LobbyGun_" .. tostring(wid)] = resID end
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE gun " .. tostring(wid) .. "=" .. tostring(resID)) end
        end
    elseif st == _G.X3.InjST.MELEE then
        cch.weapons[_G.X3.InjST.MELEE] = { resID = resID, insID = insID }
    elseif kind == "Bag" then
        _G.X3.OutfitMap.Bag = { resID, resID, resID }
        if cData then cData.LobbyBag = resID end
        cch.bag = { resID = resID, insID = insID }
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE bag " .. tostring(resID)) end
    elseif kind == "Helmet" then
        _G.X3.OutfitMap.Helmet = { resID, resID, resID }
        if cData then cData.LobbyHelmet = resID end
        cch.helmet = { resID = resID, insID = insID }
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE helm " .. tostring(resID)) end
    elseif kind == "Pants" then
        _G.X3.OutfitMap.Pants = resID
        if cData then cData.LobbyPants = resID end
        cch.pants = { resID = resID, insID = insID }
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE celana " .. tostring(resID)) end
    elseif kind == "Shoes" then
        _G.X3.OutfitMap.Shoes = resID
        if cData then cData.LobbyShoes = resID end
        cch.shoes = { resID = resID, insID = insID }
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE sepatu " .. tostring(resID)) end
    elseif kind == "Vehicle" then
        local base = _G.X3.VehSkinToBase and _G.X3.VehSkinToBase[resID]
        if base then
            _G.X3.VehicleSkinMap[base] = resID
            if cData then cData["LobbyVeh_" .. tostring(base)] = resID end
        end
        cch.vehicles = cch.vehicles or {}
        cch.vehicles[resID] = insID
        _G.X3.LastVehicleEntity = nil
        if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] CAPTURE kendaraan " .. tostring(resID) .. " base=" .. tostring(base)) end
    end
    local nowS = os.clock()
    if _G.X3.SaveModSettings and (not _G.X3.LastCapSave or (nowS - _G.X3.LastCapSave) > 1.0) then
        _G.X3.LastCapSave = nowS
        pcall(_G.X3.SaveModSettings)
    end
end

-- CAPTURE FROM ARGS --
_G.X3.CaptureFromArgs = function(src, ...)
    local args = { ... }
    for _, a in ipairs(args) do
        local ta = type(a)
        if ta == "number" then
            if _G.X3.InjIsInjectedIns and _G.X3.InjIsInjectedIns(a) then
                local resID = _G.X3.Inj.insToRes[a]
                if resID then
                    pcall(_G.X3.InjSaveEquip, resID, a)
                    if type(_G.X3.Trace) == "function" then
                        _G.X3.Trace("CAPTURE-GEN " .. tostring(src) .. " ins=" .. tostring(a) .. " res=" .. tostring(resID))
                    end
                end
                return
            end
        elseif ta == "table" then
            local ins = tonumber(a.instid or a.insID or a.ins_id or a.InsID)
            if ins and _G.X3.InjIsInjectedIns and _G.X3.InjIsInjectedIns(ins) then
                local resID = _G.X3.Inj.insToRes[ins] or tonumber(a.res_id or a.resID or a.ResID)
                if resID then
                    pcall(_G.X3.InjSaveEquip, resID, ins)
                    if type(_G.X3.Trace) == "function" then
                        _G.X3.Trace("CAPTURE-GEN " .. tostring(src) .. " ins=" .. tostring(ins) .. " res=" .. tostring(resID))
                    end
                end
                return
            end
        end
    end
end

-- INJ PUT ON CLOTH --
_G.X3.InjPutOnCloth = function(insID)
    insID = tonumber(insID)
    local resID = _G.X3.Inj.insToRes[insID]
    if not resID then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local kind = _G.X3.InjClothKind(resID, d)
    if not kind then return end
    local clearMap = _G.X3.InjClearMapForKind(kind)
    if not clearMap then return end
    local itemSt = _G.X3.InjSubType(_G.X3.InjCfg(resID)) or _G.X3.InjST.TOP
    local oldIns, oldRes = _G.X3.InjFindWornInsBySubType(itemSt)
    pcall(_G.X3.InjRemoveRoleWearBySubTypes, clearMap)
    pcall(_G.X3.InjClearFashionBagSlots, clearMap)
    _G.X3.InjSaveEquip(resID, insID)
    local slot = 3
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(itemSt)
        if idx then slot = idx end
    end)
    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or _G.X3.Inj.insToRes[oldIns], count = 1, instid = oldIns }
    end
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local item = { res_id = resID, count = 1, instid = insID }
        WRH.on_depot_put_on_rsp(NetErrorCode_NONE or "ok", item, olditem, slot, insID, oldIns or 0)
    end)
    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(itemSt, insID, resID, 0, 0)
        local displayResID = resID
        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
        if LogicXSuit.IsXSuit(displayResID) then
            displayResID = LogicXSuit.GetItemShowID(insID) or displayResID
        end
        av:AvatarChange(displayResID, true, 0, 0)
        av:ProcessTakeOff()
        _G.X3.InjSyncFashionBagRolewear()
    end)
end

-- INJ EQUIP WEAPON SKIN --
_G.X3.InjEquipWeaponSkin = function(wid, insID)
    wid, insID = tonumber(wid), tonumber(insID)
    if not wid or not insID or not _G.X3.InjIsInjectedIns(insID) then return end
    local resID = _G.X3.Inj.insToRes[insID]
    if not resID then return end
    _G.X3.InjSaveEquip(resID, insID)
    pcall(_G.X3.InjInjectArmory, resID, insID)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        Arm.rsp_list.install_list[wid] = { skin_id = insID }
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateCurrentFashionBagWeaponSkin then
            fbd:UpdateCurrentFashionBagWeaponSkin(wid, insID)
        end
        local bagIdx = fbd:GetFashionBagUseIndex()
        local HT = require("client.logic.lobby.hall_theme_utils")
        HT.proc_skin_list_chg("weapon_skin", wid, insID, bagIdx, {})
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        wgl:SetGunID(wid)
        wgl:UpdateCurrentGunAvatar(wid, insID)
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
            EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
        end
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
        end
    end)
end

-- INJ BUILD ITEMS --
_G.X3.InjBuildItems = function()
    local seen, items = {}, {}
    local function add(id)
        id = tonumber(id)
        if id and id > 0 and not seen[id] and not (_G.X3.NonMaxLevels and _G.X3.NonMaxLevels[id]) then
            seen[id] = true table.insert(items, id)
        end
    end
    if _G.X3.VIPWeaponSkins then
        for _, id in ipairs(_G.X3.VIPWeaponSkins) do add(id) end
    end
    if _G.X3.OutfitSkins then
        for _, id in ipairs(_G.X3.OutfitSkins.Suit or {}) do add(id) end
        for _, t in ipairs(_G.X3.OutfitSkins.Bag or {}) do for _, id in ipairs(t) do add(id) end end
        for _, t in ipairs(_G.X3.OutfitSkins.Helmet or {}) do for _, id in ipairs(t) do add(id) end end
        for _, id in ipairs(_G.X3.OutfitSkins.Pet or {}) do add(id) end
    end
    if _G.X3.skinIdMappings then
        for _, skins in pairs(_G.X3.skinIdMappings) do
            for i = 2, #skins do add(skins[i]) end
        end
    end
    if _G.X3.VIP_Attachments then
        for skinID in pairs(_G.X3.VIP_Attachments) do add(skinID) end
    end
    if _G.X3.VehicleSkins then
        for _, skins in pairs(_G.X3.VehicleSkins) do
            for i = 2, #skins do add(skins[i]) end
        end
    end
    _G.X3.Inj.items = items

    _G.X3.VehSkinToBase = {}
    if _G.X3.VehicleSkins then
        for base, skins in pairs(_G.X3.VehicleSkins) do
            for i = 2, #skins do _G.X3.VehSkinToBase[skins[i]] = base end
        end
    end

    local items2 = {}
    if _G.X3.DumpSkins then
        for _, id in ipairs(_G.X3.DumpSkins) do
            if not seen[id] and not (_G.X3.NonMaxLevels and _G.X3.NonMaxLevels[id]) then
                seen[id] = true
                table.insert(items2, id)
            end
        end
    end
    _G.X3.Inj.items2 = items2
end

_G.X3.EnumDone = false
_G.X3.EnumIDs = nil
_G.X3.EnumState = nil

-- ENUM ACCEPT --
_G.X3.EnumAccept = function(id, st)
    id = tonumber(id)
    if not id or id <= 0 or st.seen[id] then return end
    if id < 300000 and not (id >= 150000 and id <= 159999) then return end
    if _G.X3.NonMaxLevels and _G.X3.NonMaxLevels[id] then return end
    local c = _G.X3.InjCfg(id)
    if not c then return end
    local hasField = false
    pcall(function() for _ in pairs(c) do hasField = true break end end)
    local kind = _G.X3.InjClassify(id)
    if not kind then
        if (id >= 300000 and id <= 399999) or           -- BORDER / bingkai avatar
           (id >= 150000 and id <= 159999) or            -- companion
           (id >= 1510000 and id <= 1519999) or          -- crate/lootbox
           (id >= 1503000 and id <= 1504999) or          -- aksesori kecil
           (id >= 1704000 and id <= 1704999) or          -- emote
           (id >= 1100000000 and id <= 1199999999) or    -- semua skin senjata
           (id >= 1503000000 and id <= 1504999999) then  -- hair color/set kecil
            kind = "Extra"
        end
    end
    if kind then
        st.seen[id] = true
        st.ids[#st.ids + 1] = id
    end
end

_G.X3.EnumTableNames = {
    "AvatarBPTable","WeaponBPTable","VehicleBPTable","EmoteBPTable","PlaneBPTable",
    "ConsumableBPTable","EffectItemBPTable","InFillingBPTable","3DIconBPTable","DecalBPTable",
    "SkillPropsBPTable","VehiclePropsBPTable","VehicleRefitBPTable","VehicleRefitColorTable",
    "VehicleRefitPatternTable","VehicleRefitParticleTable","GameModeBPTable","SeasonMissionBPTable",
    "DiySuitPatternConfig","DiySuitColorConfig","PetDressBlueprintTable","PetDressBPTable",
    "Item","ItemBPTable","WeaponSkinMapping","VehiclePlaneSkinMapping","AvatarSkinMapping",
    "ParachuteBPTable","BackpackBPTable","HelmetBPTable","FrameBPTable","CompanionBPTable",
}

-- ENUM GET AEM --
_G.X3.EnumGetAEM = function()
    if _G.X3.EnumAEM ~= nil then return _G.X3.EnumAEM end
    local mgr = false
    for _, cls in ipairs({"AETableManager", "UAETableManager"}) do
        local ok, r = pcall(import, cls)
        if ok and r then mgr = r break end
    end
    if not mgr then
        pcall(function()
            local ok2, r2 = pcall(import, "AETableManager")
            if ok2 and r2 then mgr = r2 end
        end)
    end
    _G.X3.EnumAEM = mgr
    return mgr
end

-- ENUM RESOLVE TABLE --
_G.X3.EnumResolveTable = function(entry)
    -- entry = { name=..., src="dt"|"aem" }
    if entry.src == "dt" then
        local t = nil
        pcall(function() t = _G.__DataTable and _G.__DataTable[entry.name] end)
        return t
    end
    local mgr = _G.X3.EnumGetAEM()
    if not mgr then return nil end
    local t = nil
    pcall(function()
        if mgr.GetDataTableStatic then t = mgr.GetDataTableStatic(entry.name) end
        if not t and mgr.GetDataTableStatic_Mod then t = mgr.GetDataTableStatic_Mod(entry.name) end
    end)
    if not t then
        pcall(function()
            if mgr.GetInstance and mgr.GetTablePtr then
                local inst = mgr.GetInstance()
                if inst then t = inst:GetTablePtr(entry.name, true) end
            end
        end)
    end
    return t
end

-- ENUM START --
_G.X3.EnumStart = function()
    if _G.X3.EnumDone or _G.X3.EnumState then return end
    _G.X3.EnumState = { ids = {}, seen = {}, tIdx = 1, tables = {}, names = nil, nCnt = 0, nIdx = 0 }
    local st = _G.X3.EnumState
    pcall(function()
        if _G.__DataTable then
            for tn, _ in pairs(_G.__DataTable) do st.tables[#st.tables + 1] = { name = tostring(tn), src = "dt" } end
        end
    end)
    if _G.X3.EnumGetAEM() then
        local have = {}
        for _, e in ipairs(st.tables) do have[e.name] = true end
        for _, tn in ipairs(_G.X3.EnumTableNames) do
            if not have[tn] then st.tables[#st.tables + 1] = { name = tn, src = "aem" } end
        end
    end
    table.sort(st.tables, function(a, b) return a.name < b.name end)
    if type(_G.X3.Trace) == "function" then
        _G.X3.Trace("ENUM: mulai enumerasi " .. tostring(#st.tables) .. " DataTable (tanpa daftar ID)")
    end
    _G.X3.EnumStep()
end

-- ENUM STEP --
_G.X3.EnumStep = function()
    local st = _G.X3.EnumState
    if not st then return end
    local okS, errS = pcall(function()
        -- [PERF-F11] budget adaptif + gate: saat frame berat, kurangi iter / tunda enumerasi
-- (anti memperparah stutter). Saat santai (dt<=12ms) budget tetap 800 = identik asli.
local _dtEnum = tonumber(_G.X3.FrameDT) or 0
if _dtEnum > 0.050 then return end  -- frame sangat berat: tunda 1 tick (EnumState tetap -> lanjut nanti)
local budget = (_dtEnum > 0.020) and 200 or ((_dtEnum > 0.012) and 400 or 800)
        local DTL = nil
        pcall(function() DTL = import("DataTableFunctionLibrary") end)
        while budget > 0 do
            if st.tIdx > #st.tables then
                _G.X3.EnumIDs = st.ids
                _G.X3.EnumDone = true
                _G.X3.EnumState = nil
                if type(_G.X3.Trace) == "function" then
                    _G.X3.Trace("ENUM: SELESAI " .. tostring(#_G.X3.EnumIDs) .. " ID terbaca dari DataTable game")
                end
                return
            end
            if not st.names then
                local entry = st.tables[st.tIdx]
                local tbl = nil
                if type(entry) == "table" then
                    tbl = _G.X3.EnumResolveTable(entry)
                else
                    pcall(function() tbl = _G.__DataTable and _G.__DataTable[entry] end)
                end
                if tbl and DTL then
                    pcall(function() st.names = DTL.GetDataTableRowNames(tbl) end)
                    if not st.names then
                        pcall(function()
                            local arr = slua.Array(UEnums.EPropertyClass.NameProperty)
                            DTL.GetDataTableRowNames(tbl, arr)
                            st.names = arr
                        end)
                    end
                end
                st.nCnt = 0
                pcall(function() if st.names then st.nCnt = st.names:Num() end end)
                st.nIdx = 0
            end
-- [PERF-F08] named-fetcher 1x/tick (BUKAN per iter) -> pcall tetap jadi jaring,
-- tapi alokasi closure per-iter = 0 (enumerasi TIDAK regresi).

local _nmBuf = nil

local function _fetchName()
    _nmBuf = st.names:Get(st.nIdx)
end

while st.nIdx < st.nCnt and budget > 0 do
    budget = budget - 1

    _nmBuf = nil
    pcall(_fetchName)

    local nm = _nmBuf

    st.nIdx = st.nIdx + 1

    local id = tonumber(nm)

    if id then
        _G.X3.EnumAccept(id, st)
    end
end
            if st.nIdx >= st.nCnt then
                st.names = nil
                st.tIdx = st.tIdx + 1
            end
        end
        -- langkah berikutnya digas dari MAINLOOP (selama EnumState ada)
    end)
    if not okS then
        if type(_G.X3.Trace) == "function" then _G.X3.Trace("ENUM: error -> " .. tostring(errS)) end
        _G.X3.EnumIDs = st.ids
        _G.X3.EnumDone = true
        _G.X3.EnumState = nil
    end
end

-- INJ INJECT BATCH --
_G.X3.InjInjectBatch = function()
    local st = _G.X3.Inj
    if st.allDone then return end
    local entity = _G.X3.InjGetEntity()
    if not entity or not entity.bInit then st.injectRunning = false return end
    st.injectRunning = true
    local phase = st.phase or 1
    if phase == 2 and not _G.X3.EnumDone then
        if _G.X3.EnumStart then pcall(_G.X3.EnumStart) end
        return -- dipanggil ulang dari MAINLOOP
    end
    local items
    if phase == 1 then
        items = st.items
    else
        items = (_G.X3.EnumIDs and #_G.X3.EnumIDs > 0) and _G.X3.EnumIDs or (st.items2 or {})
    end
    local batchSize = (phase == 1) and 40 or 50
    local delay = (phase == 1) and 0.05 or 0.05
    local insBase = (phase == 1) and 2000000000 or 2001000000
    local i = st.injectIdx or 1
    local n = 0
    while i <= #items and n < batchSize do
        local resID = items[i]
        local insID = insBase + i
        if _G.X3.InjInjectOne(entity, resID, insID) then
            local sub = _G.X3.InjSubType(_G.X3.InjCfg(resID))
            if (sub and _G.X3.InjGunSub[sub]) or sub == _G.X3.InjST.MELEE then
                pcall(_G.X3.InjInjectArmory, resID, insID)
            end
            n = n + 1
        end
        i = i + 1
    end
    st.injectIdx = i
    if i > #items then
        if phase == 1 then
            st.injectDone = true
            st.phase = 2
            st.injectIdx = 1
            pcall(_G.X3.InjRestoreFromSave)
            pcall(_G.X3.InjRefreshWardrobe)
            _G.X3._InjReapplyAt = os.clock() + 1.0 -- dieksekusi MAINLOOP
            print("[X3Team] SkinUnlock: fase-1 selesai " .. tostring(#items) .. " item, lanjut fase-2 ...")
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] fase-1 selesai total=" .. tostring(#items)) end
        else
            st.allDone = true
            st.injectRunning = false
            pcall(_G.X3.InjRestoreFromSave)
            pcall(_G.X3.InjRefreshWardrobe)
            _G.X3._InjReapplyAt = os.clock() + 1.0 -- dieksekusi MAINLOOP
            print("[X3Team] SkinUnlock: SEMUA skin terinjeksi (" .. tostring(#items) .. " fase-2)")
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] fase-2 selesai total=" .. tostring(#items)) end
        end
    end
    -- batch lanjut digas dari MAINLOOP selama injectRunning
end

-- INJ PUT ON GENERIC --
_G.X3.InjPutOnGeneric = function(insID)
    insID = tonumber(insID)
    local resID = _G.X3.Inj.insToRes[insID]
    if not resID then return end
    pcall(_G.X3.InjSaveEquip, resID, insID)
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NetErrorCode_NONE or "ok", { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0)
    end)
end

-- INJ RESTORE FROM SAVE --
_G.X3.InjRestoreFromSave = function()
    local cData = _G.X3.LexusState and _G.X3.LexusState.CustomTextData
    if not cData then return end
    local cch = _G.X3.Inj.cache
    if tonumber(cData.LobbySuit) then
        local r = tonumber(cData.LobbySuit)
        cch.outfitRes = r
        cch.outfitIns = _G.X3.Inj.resToIns[r]
    end
    if tonumber(cData.LobbyBag) then
        local r = tonumber(cData.LobbyBag)
        cch.bag = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    if tonumber(cData.LobbyHelmet) then
        local r = tonumber(cData.LobbyHelmet)
        cch.helmet = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    if tonumber(cData.LobbyPants) then
        local r = tonumber(cData.LobbyPants)
        cch.pants = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    if tonumber(cData.LobbyShoes) then
        local r = tonumber(cData.LobbyShoes)
        cch.shoes = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    cch.vehicles = cch.vehicles or {}
    for k, v in pairs(cData) do
        local wid = tostring(k):match("^LobbyGun_(%d+)$")
        if wid and tonumber(v) then
            local r = tonumber(v)
            cch.weapons[tonumber(wid)] = { resID = r, insID = _G.X3.Inj.resToIns[r] }
        end
        local vb = tostring(k):match("^LobbyVeh_(%d+)$")
        if vb and tonumber(v) then
            local r = tonumber(v)
            cch.vehicles[r] = _G.X3.Inj.resToIns[r]
        end
    end
end

-- INJ REAPPLY LOBBY --
_G.X3.InjReapplyLobby = function()
    local inLobby = true
    pcall(function()
        if GameStatus and GameStatus.IsInLobbyOrMainCity then
            inLobby = GameStatus.IsInLobbyOrMainCity()
        end
    end)
    if not inLobby then return end
    local cch = _G.X3.Inj.cache
    if cch.outfitIns and _G.X3.InjIsInjectedIns(cch.outfitIns) then
        pcall(_G.X3.InjPutOnCloth, cch.outfitIns)
    end
    if cch.pants and cch.pants.insID and _G.X3.InjIsInjectedIns(cch.pants.insID) then
        pcall(_G.X3.InjPutOnCloth, cch.pants.insID)
    end
    if cch.shoes and cch.shoes.insID and _G.X3.InjIsInjectedIns(cch.shoes.insID) then
        pcall(_G.X3.InjPutOnCloth, cch.shoes.insID)
    end
    if cch.bag and cch.bag.insID and _G.X3.InjIsInjectedIns(cch.bag.insID) then
        pcall(_G.X3.InjPutOnGeneric, cch.bag.insID)
    end
    if cch.helmet and cch.helmet.insID and _G.X3.InjIsInjectedIns(cch.helmet.insID) then
        pcall(_G.X3.InjPutOnGeneric, cch.helmet.insID)
    end
    if cch.vehicles then
        for vres, vins in pairs(cch.vehicles) do
            if _G.X3.InjIsInjectedIns(vins) then pcall(_G.X3.InjPutOnGeneric, vins) end
        end
    end
    for widRaw, w in pairs(cch.weapons) do
        local wid = tonumber(widRaw)
        if wid and w and w.insID and _G.X3.InjIsInjectedIns(w.insID) then
            pcall(_G.X3.InjEquipWeaponSkin, wid, w.insID)
        end
    end
    pcall(_G.X3.InjRefreshWardrobe)
end

-- INJ INSTALL HOOKS --
_G.X3.InjInstallHooks = function()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        if not WDE or WDE.__x3inj_init then return end
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            local st = _G.X3.Inj
            st.injectDone = false
            st.allDone = false
            st.phase = 1
            st.injectIdx = 1
            pcall(_G.X3.InjInjectBatch)
            pcall(_G.X3.InjRefreshWardrobe)
        end
        WDE.__x3inj_init = true
    end)

    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        if not wd or wd.__x3inj_data then return end
        local function wrapGet(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, insID, ...)
                insID = tonumber(insID)
                if _G.X3.InjIsInjectedIns(insID) then
                    local e = _G.X3.InjGetEntity()
                    if e then return e:GetDataByInsID(insID) end
                end
                return o(self, insID, ...)
            end
        end
        wrapGet("GetHallDepotItemDataByInsID")
        wrapGet("GetValidHallDepotItemDataByInsID")
        local function wrapBool(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, id, ...)
                if _G.X3.InjIsInjectedRes(tonumber(id)) or _G.X3.InjIsInjectedIns(tonumber(id)) then return true end
                return o(self, id, ...)
            end
        end
        wrapBool("HasItem")
        wrapBool("HasValidItem")
        wrapBool("CheckHasPermanentItem")
        wd.__x3inj_data = true
    end)

    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if not wl or wl.__x3inj_page then return end
        local o2 = wl.IsCanUse
        if o2 then
            wl.IsCanUse = function(self, resId)
                if _G.X3.InjIsInjectedRes(resId) then return true end
                return o2(self, resId)
            end
        end
        local o3 = wl.IsCharacterUse
        if o3 then
            wl.IsCharacterUse = function(self, resId)
                if _G.X3.InjIsInjectedRes(resId) then return true end
                return o3(self, resId)
            end
        end
        local o4 = wl.GetWardrobeInsIdByResId
        if o4 then
            wl.GetWardrobeInsIdByResId = function(self, resid)
                resid = tonumber(resid)
                if _G.X3.InjIsInjectedRes(resid) then return _G.X3.Inj.resToIns[resid] end
                return o4(self, resid)
            end
        end
        wl.__x3inj_page = true
    end)

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm and not Arm.__x3inj_arm then
            local og = Arm.GetSkinListByWeaponID
            if og then
                Arm.GetSkinListByWeaponID = function(wid)
                    local t = og(wid) or {}
                    local present = {}
                    for k, v in pairs(t) do
                        if type(v) == "table" then
                            local rid = tonumber(v.resID or v.res_id or v.skinID or v.skin_id or v.ResID)
                            if rid then present[rid] = true end
                        end
                        local kn = tonumber(k)
                        if kn and kn > 1000000 then present[kn] = true end
                    end
                    for resID, _ in pairs(_G.X3.Inj.resToIns) do
                        if not present[resID] and tonumber(_G.X3.InjWeaponIdFromSkin(resID)) == tonumber(wid) then
                            t[resID] = t[resID] or { is_open = 1 }
                        end
                    end
                    return t
                end
            end
            local oi = Arm.install_weapon_skin
            if oi then
                Arm.install_weapon_skin = function(cd, wid, ins)
                    ins = tonumber(ins)
                    if _G.X3.InjIsInjectedIns(ins) then
                        wid = tonumber(_G.X3.InjWeaponIdFromSkin(_G.X3.Inj.insToRes[ins]) or wid)
                        _G.X3.InjEquipWeaponSkin(wid, ins)
                        return
                    end
                    return oi(cd, wid, ins)
                end
            end
            Arm.__x3inj_arm = true
        end
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        if AH and not AH.__x3inj_armh then
            local o = AH.send_install_weapon_skin
            if o then
                AH.send_install_weapon_skin = function(cd, wid, ins)
                    ins = tonumber(ins)
                    if _G.X3.InjIsInjectedIns(ins) then
                        wid = tonumber(_G.X3.InjWeaponIdFromSkin(_G.X3.Inj.insToRes[ins]) or wid)
                        _G.X3.InjEquipWeaponSkin(wid, ins)
                        return
                    end
                    return o(cd, wid, ins)
                end
            end
            AH.__x3inj_armh = true
        end
    end)

    -- 5) skin id senjata terpasang
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if not wgl or wgl.__x3inj_gun then return end
        local o = wgl.GetSkinIdByWeaponID
        if o then
            wgl.GetSkinIdByWeaponID = function(self, wid)
                local w = _G.X3.Inj.cache.weapons[wid]
                if w and _G.X3.InjIsInjectedIns(w.insID) then return w.insID end
                local Arm = require("client.logic.armory.logic_armory")
                if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                    local sid = Arm.rsp_list.install_list[wid].skin_id
                    if sid and _G.X3.InjIsInjectedIns(sid) then return sid end
                end
                return o(self, wid)
            end
        end
        wgl.__x3inj_gun = true
    end)

    -- 6) permintaan pakai item dari UI gudang
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if not WRH or WRH.__x3inj_put then return end
        local o = WRH.send_depot_put_on_req
        if o then
            WRH.send_depot_put_on_req = function(insID, extra)
                insID = tonumber(insID)
                if _G.X3.InjIsInjectedIns(insID) then
                    local resID = _G.X3.Inj.insToRes[insID]
                    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
                    if _G.X3.InjClothKind(resID) then
                        pcall(_G.X3.InjPutOnCloth, insID)
                        return
                    end
                    if st and _G.X3.InjGunSub[st] then
                        local wid = _G.X3.InjWeaponIdFromSkin(resID)
                        if wid then pcall(_G.X3.InjEquipWeaponSkin, wid, insID) end
                        return
                    end
                    if st == _G.X3.InjST.MELEE then
                        pcall(_G.X3.InjEquipWeaponSkin, _G.X3.InjST.MELEE, insID)
                        return
                    end
                    pcall(_G.X3.InjSaveEquip, resID, insID)
                    pcall(function()
                        local wd2 = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d2 = wd2:GetHallDepotItemDataByInsID(insID)
                        if d2 then
                            WRH.on_depot_put_on_rsp(NetErrorCode_NONE or "ok", { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0, extra)
                        end
                    end)
                    return
                end
                return o(insID, extra)
            end
        end
        WRH.__x3inj_put = true
    end)
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if not wl or wl.__x3inj_req then return end
        local o = wl.wardrobe_puton_req
        if o then
            wl.wardrobe_puton_req = function(self, insID, extra)
                insID = tonumber(insID)
                if _G.X3.InjIsInjectedIns(insID) and _G.X3.InjClothKind(_G.X3.Inj.insToRes[insID]) then
                    pcall(_G.X3.InjPutOnCloth, insID)
                    return
                end
                return o(self, insID, extra)
            end
        end
        wl.__x3inj_req = true
    end)

    pcall(function()
        local nGen = 0
        local function tryHookModule(modName, patterns)
            local md = package.loaded[modName]
            if type(md) ~= "table" then
                local okR, mr = pcall(require, modName)
                if okR and type(mr) == "table" then md = mr end
            end
            if type(md) ~= "table" then return end
            for fname, fval in pairs(md) do
                if type(fval) == "function" and type(fname) == "string" then
                    local fl = string.lower(fname)
                    local match = false
                    for _, pat in ipairs(patterns) do
                        if string.find(fl, pat, 1, true) then match = true break end
                    end
                    if match and not rawget(md, "__x3cap_" .. fname) then
                        rawset(md, "__x3cap_" .. fname, true)
                        local o = fval
                        rawset(md, fname, function(...)
                            pcall(_G.X3.CaptureFromArgs, modName .. "." .. fname, ...)
                            return o(...)
                        end)
                        nGen = nGen + 1
                    end
                end
            end
        end
        tryHookModule("client.network.Protocol.WardRobeHandler", { "put_on", "puton", "wear" })
        tryHookModule("client.slua.logic.wardrobe.logic_wardrobe_new", { "put_on", "puton", "wear" })
        tryHookModule("client.slua.logic.wardrobe.wardrobe_data", { "put_on", "puton", "wear" })
        tryHookModule("client.network.Protocol.ArmoryHandler", { "install_weapon", "weapon_skin" })
        tryHookModule("client.logic.armory.logic_armory", { "install_weapon_skin" })
        if type(_G.X3.Trace) == "function" then
            _G.X3.Trace("SKIN: capture generik terpasang di " .. tostring(nGen) .. " fungsi")
        end
    end)

    if _G.X3.L_Log then pcall(_G.X3.L_Log, "[SkinUnlock] hook v18 terpasang") end
end

-- INJ ENSURE --
_G.X3.InjEnsure = function()
    if not _G.X3.LexusConfig or not (_G.X3.LexusConfig.SkinUnlockAll or _G.X3.LexusConfig.ModSkin) then return end
    local st = _G.X3.Inj
    if not st.hooksInstalled then
        st.hooksInstalled = true
        local okH, errH = pcall(_G.X3.InjInstallHooks)
        if type(_G.X3.Trace) == "function" then
            _G.X3.Trace("SKIN: InstallHooks ok=" .. tostring(okH) .. (okH and "" or (" err=" .. tostring(errH))))
        end
    end
    if not st.itemsBuilt then
        st.itemsBuilt = true
        local okB, errB = pcall(_G.X3.InjBuildItems)
        if type(_G.X3.Trace) == "function" then
            local n1 = (st.items and #st.items) or 0
            local n2 = (st.items2 and #st.items2) or 0
            _G.X3.Trace("SKIN: BuildItems ok=" .. tostring(okB) .. " fase1=" .. tostring(n1) .. " fase2=" .. tostring(n2) .. (okB and "" or (" err=" .. tostring(errB))))
        end
    end
    if _G.X3.EnumStart then pcall(_G.X3.EnumStart) end
    if not st.allDone and not st.injectRunning then
        pcall(_G.X3.InjInjectBatch)
    end
    if _G.X3.HookEmoteDepot then pcall(_G.X3.HookEmoteDepot) end
end

-- BP GET VIP ATTACH --
_G.X3.BpGetVipAttach = function(attachId)
    local mapIndex = _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[attachId]
    if not mapIndex then return nil end
    local ok, res = pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local lp = GameplayData and GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if not slua.isValid(lp) then return nil end
        local w = lp:GetCurrentWeapon()
        if not slua.isValid(w) then return nil end
        local skin = _G.X3.get_skin_id and _G.X3.get_skin_id(w:GetWeaponID()) or w:GetWeaponID()
        if skin and skin >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[skin] then
            local v = _G.X3.VIP_Attachments[skin][mapIndex]
            if v and v > 0 then return v end
        end
        return nil
    end)
    return ok and res or nil
end

-- BP COPY WITH SKIN --
_G.X3.BpCopyWithSkin = function(item)
    if type(item) ~= "table" then return item end
    local did = item.defineID or item.ItemDefineID or item.DefineID
    if type(did) ~= "table" then return item end
    local tid = tonumber(did.TypeSpecificID) or 0
    local newId = nil
    if tid >= 100000 and tid <= 199999 then
        local skin = _G.X3.get_skin_id and _G.X3.get_skin_id(tid)
        if skin and skin ~= tid then newId = skin end
    elseif tid >= 200000 and tid <= 299999 then
        newId = _G.X3.BpGetVipAttach(tid)
    end
    if not newId then return item end
    local shown = {}
    for k, v in pairs(item) do shown[k] = v end
    local ndid = {}
    for k, v in pairs(did) do ndid[k] = v end
    ndid.TypeSpecificID = newId
    if item.defineID then shown.defineID = ndid end
    if item.ItemDefineID then shown.ItemDefineID = ndid end
    if item.DefineID then shown.DefineID = ndid end
    if _G.X3.download_item then pcall(_G.X3.download_item, newId) end
    return shown
end

-- BP SUBSTITUTE ARRAY --
_G.X3.BpSubstituteArray = function(arr)
    if type(arr) ~= "table" then return arr end
    local out = {}
    for k, v in pairs(arr) do out[k] = _G.X3.BpCopyWithSkin(v) end
    return out
end

-- BP INSTALL HOOKS --
_G.X3.BpInstallHooks = function()
    -- panel senjata utama Ransel
    pcall(function()
        local mw = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI"] or require("GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI")
        if type(mw) == "table" and not rawget(mw, "__x3bp") then
            rawset(mw, "__x3bp", true)
            local o = rawget(mw, "GetCurrentWeaponItemArray")
            if type(o) == "function" then
                rawset(mw, "GetCurrentWeaponItemArray", function(...)
                    local r = o(...)
                    pcall(function() r = _G.X3.BpSubstituteArray(r) end)
                    return r
                end)
            end
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[X3Bp] hook MainWeaponInfoItemUI") end
        end
    end)
    -- slot attachment
    pcall(function()
        local fs = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.FittingSlotItemUI"] or require("GameLua.Mod.BaseMod.Client.Backpack.FittingSlotItemUI")
        if type(fs) == "table" and not rawget(fs, "__x3bp") then
            rawset(fs, "__x3bp", true)
            local o = rawget(fs, "GetGunBattleData")
            if type(o) == "function" then
                rawset(fs, "GetGunBattleData", function(...)
                    local r = o(...)
                    pcall(function() r = _G.X3.BpCopyWithSkin(r) end)
                    return r
                end)
            end
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[X3Bp] hook FittingSlotItemUI") end
        end
    end)
    pcall(function()
        local lb = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.ListItemUIBase"] or require("GameLua.Mod.BaseMod.Client.Backpack.ListItemUIBase")
        if type(lb) == "table" and not rawget(lb, "__x3bp") then
            rawset(lb, "__x3bp", true)
            for _, fn in ipairs({"UpdateItemDataNew", "UpdateItemDataMod"}) do
                local o = rawget(lb, fn)
                if type(o) == "function" then
                    rawset(lb, fn, function(self, item, ...)
                        local shown = item
                        pcall(function() shown = _G.X3.BpCopyWithSkin(item) end)
                        return o(self, shown, ...)
                    end)
                end
            end
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[X3Bp] hook ListItemUIBase") end
        end
    end)
    pcall(function()
        local bi = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.BackPackItemUI"] or require("GameLua.Mod.BaseMod.Client.Backpack.BackPackItemUI")
        if type(bi) == "table" and not rawget(bi, "__x3bp") then
            rawset(bi, "__x3bp", true)
            local o = rawget(bi, "UpdateSingleItem")
            if type(o) == "function" then
                rawset(bi, "UpdateSingleItem", function(self, item, ...)
                    local shown = item
                    pcall(function() shown = _G.X3.BpCopyWithSkin(item) end)
                    return o(self, shown, ...)
                end)
            end
            if _G.X3.L_Log then pcall(_G.X3.L_Log, "[X3Bp] hook BackPackItemUI") end
        end
    end)
    if type(_G.X3.Trace) == "function" then
        local parts = {}
        for _, mn in ipairs({
            "GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI",
            "GameLua.Mod.BaseMod.Client.Backpack.FittingSlotItemUI",
            "GameLua.Mod.BaseMod.Client.Backpack.ListItemUIBase",
            "GameLua.Mod.BaseMod.Client.Backpack.BackPackItemUI",
        }) do
            local m = package.loaded[mn]
            local short = string.match(mn, "([^%.]+)$") or mn
            if type(m) == "table" then
                parts[#parts + 1] = short .. (rawget(m, "__x3bp") and "=HOOKED" or "=ADA")
            else
                parts[#parts + 1] = short .. "=TIDAK"
            end
        end
        local sig = table.concat(parts, " ")
        if sig ~= _G.X3.BpDiagSig then
            _G.X3.BpDiagSig = sig
            _G.X3.Trace("BP: " .. sig)
        end
    end
end

-- BP ENSURE --
_G.X3.BpEnsure = function()
    if not _G.X3.LexusConfig or not _G.X3.LexusConfig.ModSkin then return end
    if _G.X3.SkinUnlock_InLobby and _G.X3.SkinUnlock_InLobby() then return end
    local now = os.clock()
    if _G.X3.BpLastTry and (now - _G.X3.BpLastTry) < 3.0 then return end
    _G.X3.BpLastTry = now
    pcall(_G.X3.BpInstallHooks)
end

-- APPLY BACKPACK SKIN DISPLAY --
_G.X3.ApplyBackpackSkinDisplay = function(PlayerCharacter)
    pcall(function()
        if not slua.isValid(PlayerCharacter) then return end
        local bc = PlayerCharacter.BackpackComponent
        if not slua.isValid(bc) then
            if type(_G.X3.Trace) == "function" and not _G.X3.BpNoBcTraced then
                _G.X3.BpNoBcTraced = true
                _G.X3.Trace("BP-DATA: PlayerCharacter.BackpackComponent TIDAK valid (nama field berubah di 4.5?)")
            end
            return
        end
        local now = os.clock()
        if _G.X3.BpSkinDataLast and (now - _G.X3.BpSkinDataLast) < 2.0 then return end
        _G.X3.BpSkinDataLast = now
        local items = {}
        local ok1, r1 = pcall(function() return bc:GetAllBattleItemClient() end)
        if ok1 and r1 then
            if type(r1) == "table" then
                for _, it in pairs(r1) do table.insert(items, it) end
            elseif type(r1) == "userdata" and r1.Num then
                for i = 0, r1:Num() - 1 do table.insert(items, r1:Get(i)) end
            end
        end
        if #items == 0 and bc.GetItemListByItemType then
            for _, t in ipairs({ 1, 2, 3, 4, 5, 6 }) do
                pcall(function()
                    local lst = bc:GetItemListByItemType(t)
                    if lst then
                        if type(lst) == "table" then
                            for _, it in pairs(lst) do table.insert(items, it) end
                        elseif type(lst) == "userdata" and lst.Num then
                            for i = 0, lst:Num() - 1 do table.insert(items, lst:Get(i)) end
                        end
                    end
                end)
            end
        end
        local nPatched = 0
        for _, it in pairs(items) do
            pcall(function()
                local did = it.ItemDefineID or it.defineID
                if did and did.TypeSpecificID then
                    local tid = tonumber(did.TypeSpecificID) or 0
                    if tid >= 100000 and tid <= 199999 then
                        local skin = _G.X3.get_skin_id and _G.X3.get_skin_id(tid)
                        if skin and skin ~= tid then
                            did.TypeSpecificID = skin
                            nPatched = nPatched + 1
                            if _G.X3.download_item then pcall(_G.X3.download_item, skin) end
                        end
                    end
                end
            end)
        end
        if type(_G.X3.Trace) == "function" then
            local sigB = "items=" .. tostring(#items) .. " patched=" .. tostring(nPatched) .. " getAll=" .. tostring(ok1)
            if sigB ~= _G.X3.BpDataSig and (_G.X3.BpDataN or 0) < 40 then
                _G.X3.BpDataSig = sigB
                _G.X3.BpDataN = (_G.X3.BpDataN or 0) + 1
                _G.X3.Trace("BP-DATA: " .. sigB)
            end
        end
    end)
end

-- Resolver skin ID (tanpa daftar ID manual):
_G.X3.SkinUnlock = _G.X3.SkinUnlock or {}
_G.X3.SkinUnlock._WeaponAvatarType = nil
_G.X3.SkinUnlock._SkinCache = _G.X3.SkinUnlock._SkinCache or {}
_G.X3.SkinUnlock._Backup = _G.X3.SkinUnlock._Backup or {}
_G.X3.SkinUnlock._CustomSkins = _G.X3.SkinUnlock._CustomSkins or {}
_G.X3.SkinUnlock._LastApplyTime = 0
_G.X3.SkinUnlock._Hooked = false
_G.X3.SkinUnlock._Applying = false

-- GET WEAPON AVATAR TYPE --
_G.X3.SkinUnlock.GetWeaponAvatarType = function()
    if _G.X3.SkinUnlock._WeaponAvatarType then return _G.X3.SkinUnlock._WeaponAvatarType end
    local ok, EBattleItemAdditionalDataType = pcall(import, "EBattleItemAdditionalDataType")
    local val = (ok and EBattleItemAdditionalDataType and EBattleItemAdditionalDataType.WeaponAvatar) or 7
    _G.X3.SkinUnlock._WeaponAvatarType = val
    return val
end

-- RESOLVE SKIN ID --
_G.X3.SkinUnlock.ResolveSkinID = function(WeaponID)
    local custom = _G.X3.SkinUnlock._CustomSkins[WeaponID]
    if custom and custom > 0 then return custom end
    local cached = _G.X3.SkinUnlock._SkinCache[WeaponID]
    if cached then return cached end
    local okM, mapSkin = pcall(function()
        local m = _G.X3.WeaponSkinMap
        return m and m[WeaponID] or nil
    end)
    if okM and tonumber(mapSkin) and tonumber(mapSkin) > 0 then
        local sidNum = tonumber(mapSkin)
        _G.X3.SkinUnlock._SkinCache[WeaponID] = sidNum
        return sidNum
    end
    local resolvers = { _G.getCachedWeaponSkin, rawget(_G, "getCachedWeaponSkin") }
    for _, fn in ipairs(resolvers) do
        if type(fn) == "function" then
            local ok, sid = pcall(fn, WeaponID)
            if ok then
                local sidNum = tonumber(sid) or 0
                if sidNum > 0 and sidNum < 99999999 then
                    _G.X3.SkinUnlock._SkinCache[WeaponID] = sidNum
                    return sidNum
                end
            end
        end
    end
    return 0
end

-- APPLY --
function _G.X3.SkinUnlock.Apply(Backpack)
    local now = os.clock()
    if now - _G.X3.SkinUnlock._LastApplyTime < 0.5 then return 0 end
    _G.X3.SkinUnlock._LastApplyTime = now
    if not (_G.X3.LexusConfig and _G.X3.LexusConfig.SkinIngame == true) then return 0 end
    if not (Backpack and slua.isValid(Backpack)) then return 0 end
    if not (Backpack.ItemListNet and Backpack.ItemListNet.IncArray) then return 0 end

    local applied = 0
    pcall(function()
        local BagArray = Backpack.ItemListNet.IncArray
        local ItemCount = BagArray:Num()
        if ItemCount <= 0 or ItemCount > 500 then return end
        local bNeedRefreshBag = false
        local EDataType_WeaponAvatar = _G.X3.SkinUnlock.GetWeaponAvatarType()

        for j = 0, ItemCount - 1 do
            local Item = BagArray:Get(j)
            if Item and Item.Unit and Item.Unit.DefineID then
                local CurrentID = Item.Unit.DefineID.TypeSpecificID
                if CurrentID then
                    local NewSkinID = _G.X3.SkinUnlock.ResolveSkinID(CurrentID)
                    if NewSkinID and NewSkinID > 0 then
                        local AdditionalData = Item.Unit.AdditionalData
                        if AdditionalData then
                            local bFoundAvatar = false
                            local dataCount = AdditionalData:Num()
                            for k = 0, dataCount - 1 do
                                local Data = AdditionalData:Get(k)
                                if Data and Data.EDataType == EDataType_WeaponAvatar then
                                    if not _G.X3.SkinUnlock._Backup[CurrentID] then
                                        _G.X3.SkinUnlock._Backup[CurrentID] = Data.IntData or 0
                                    end
                                    if Data.IntData ~= NewSkinID then
                                        Data.IntData = NewSkinID
                                        AdditionalData:Set(k, Data)
                                        bNeedRefreshBag = true
                                        applied = applied + 1
                                    end
                                    bFoundAvatar = true
                                    break
                                end
                            end
                            if not bFoundAvatar then
                                if not _G.X3.SkinUnlock._Backup[CurrentID] then
                                    _G.X3.SkinUnlock._Backup[CurrentID] = 0
                                end
                                if dataCount > 0 then
                                    local TD = AdditionalData:Get(0)
                                    if TD then
                                        TD.EDataType = EDataType_WeaponAvatar
                                        TD.IntData = NewSkinID
                                        TD.StringData = ""
                                        AdditionalData:Add(TD)
                                        bNeedRefreshBag = true
                                        applied = applied + 1
                                    end
                                else
                                    AdditionalData:Add({ EDataType = EDataType_WeaponAvatar, IntData = NewSkinID, StringData = "" })
                                    bNeedRefreshBag = true
                                    applied = applied + 1
                                end
                            end
                        end
                        BagArray:Set(j, Item)
                    end
                end
            end
        end

        if bNeedRefreshBag then
            pcall(function()
                if type(Backpack.OnRep_ItemListNet) == "function" then
                    Backpack:OnRep_ItemListNet()
                end
            end)
        end
    end)
    return applied
end

-- RESTORE --
_G.X3.SkinUnlock.Restore = function(Backpack)
    if not (Backpack and slua.isValid(Backpack)) then return 0 end
    if not (Backpack.ItemListNet and Backpack.ItemListNet.IncArray) then return 0 end
    local restored = 0
    pcall(function()
        local BagArray = Backpack.ItemListNet.IncArray
        local ItemCount = BagArray:Num()
        local EDataType_WeaponAvatar = _G.X3.SkinUnlock.GetWeaponAvatarType()
        for j = 0, ItemCount - 1 do
            local Item = BagArray:Get(j)
            if Item and Item.Unit and Item.Unit.DefineID then
                local CurrentID = Item.Unit.DefineID.TypeSpecificID
                local orig = CurrentID and _G.X3.SkinUnlock._Backup[CurrentID] or nil
                if orig then
                    local AdditionalData = Item.Unit.AdditionalData
                    if AdditionalData then
                        local dataCount = AdditionalData:Num()
                        for k = 0, dataCount - 1 do
                            local Data = AdditionalData:Get(k)
                            if Data and Data.EDataType == EDataType_WeaponAvatar then
                                Data.IntData = orig
                                AdditionalData:Set(k, Data)
                                restored = restored + 1
                                break
                            end
                        end
                    end
                    BagArray:Set(j, Item)
                end
            end
        end
        if restored > 0 then
            pcall(function()
                if type(Backpack.OnRep_ItemListNet) == "function" then Backpack:OnRep_ItemListNet() end
            end)
        end
    end)
    return restored
end

-- INIT --
function _G.X3.SkinUnlock.Init()
    if not (_G.X3.LexusConfig and _G.X3.LexusConfig.SkinIngame == true) then return false end
    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not (PlayerController and slua.isValid(PlayerController)) then return false end
    local BC = nil
    pcall(function()
        if PlayerController.GetBackpackComponent then BC = PlayerController:GetBackpackComponent() end
        if not BC and PlayerController.GetBackPackComponent then BC = PlayerController:GetBackPackComponent() end
    end)
    if BC and slua.isValid(BC) then
        if not _G.X3.SkinUnlock._Hooked then
            pcall(function()
                local orig = BC.OnRep_ItemListNet
                if orig then
                    BC.OnRep_ItemListNet = function(self, ...)
                        if type(orig) == "function" then orig(self, ...) end
                        if not _G.X3.SkinUnlock._Applying then
                            _G.X3.SkinUnlock._Applying = true
                            _G.X3.SkinUnlock.Apply(self)
                            _G.X3.SkinUnlock._Applying = false
                        end
                    end
                    _G.X3.SkinUnlock._Hooked = true
                end
            end)
        end
        _G.X3.SkinUnlock.Apply(BC)
        return true
    end
    return false
end

-- GET CONFIG PATHS --
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
                table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
            end
        end
    end)
    return paths
end

local ConfigFileName = "X3Team.txt"
_G.X3.LastConfigSaveStr = ""

-- CFG SER --
_G.X3.CfgSer = function(v)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    return "nil"
end

-- SAVE MOD SETTINGS --
_G.X3.SaveModSettings = function()
pcall(function()
-- [PERF-F05] HOLY-GRAIL: pairs() acak -> urutan baris berubah tiap call ->
-- perbandingan dgn LastConfigSaveStr selalu gagal -> io.write jalan tiap 1,5 dtk = hitch.
-- FIX: kumpul key + sort -> string DETERMINISTIK -> saat idle data identik -> return sebelum io.open.
local function skeys(t)
local ks = {}
for k in pairs(t) do ks[#ks + 1] = k end
table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
return ks
end
local data = "return {\nLexusConfig = {\n"
for _, k in ipairs(skeys(_G.X3.LexusConfig or {})) do
data = data .. "  [\"" .. tostring(k) .. "\"] = " .. _G.X3.CfgSer(_G.X3.LexusConfig[k]) .. ",\n"
end
data = data .. "},\nCustomTextData = {\n"
if _G.X3.LexusState and _G.X3.LexusState.CustomTextData then
for _, k in ipairs(skeys(_G.X3.LexusState.CustomTextData)) do
data = data .. "  [\"" .. tostring(k) .. "\"] = " .. _G.X3.CfgSer(_G.X3.LexusState.CustomTextData[k]) .. ",\n"
end
end
data = data .. "}\n}"
if data == _G.X3.LastConfigSaveStr then return end   -- idle: identik -> TIDAK tulis file (hitch hilang)
_G.X3.LastConfigSaveStr = data
local paths = GetConfigPaths(ConfigFileName)
for _, path in ipairs(paths) do
local file = io.open(path, "w")
if file then
file:write(data)
file:close()
break
end
end
end)
end

-- LOAD MOD SETTINGS --
_G.X3.LoadModSettings = function()
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                content = file:read("*a")
                file:close()
                break
            end
        end
        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.LexusConfig then
                        for k, v in pairs(savedData.LexusConfig) do
                            _G.X3.LexusConfig[k] = v
                        end
                    end
                    if savedData.CustomTextData then
                        _G.X3.LexusState.CustomTextData = _G.X3.LexusState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do
                            _G.X3.LexusState.CustomTextData[k] = v
                        end
                    end
                 end
            end
        end
        _G.X3.SaveModSettings()
    end)
end

-- AUTO SAVE LOOP (dijalankan dari MAINLOOP tiap 1.5 dtk) --
function _G.X3._AutoSaveTick()
    pcall(function() if _G.X3.SaveModSettings then _G.X3.SaveModSettings() end end)
end

if not _G.X3.ModConfigLoaded then
    _G.X3.LoadModSettings()
    _G.X3._AutoSaveTick()
    _G.X3.ModConfigLoaded = true
end

-- READ LIVE CONFIG --
_G.X3.ReadLiveConfig = function()
    if _G.X3.SaveModSettings then _G.X3.SaveModSettings() end
end

-- BUKA LEVEL MAKS SKIN / UNLOCK MAX SKIN LEVEL (jalur "Unlock Skin")
-- Mekanisme asli: grup MultiLevelItem punya ItemID per level. Karena
-- UnlockAll membuat HasValidItem=true utk SEMUA level, game otomatis
-- membuka aksesoris + efek tiap level TANPA input ID satu per satu.
-- Hook ini memaksa pilihan display SELALU level maksimum grup.
function _G.X3._MaxLevelHookTry()
    if _G.X3._MaxLvlHooked then return end
    if not (_G.X3.LexusConfig and _G.X3.LexusConfig.X3UnlockAll) then return end
    pcall(function()
        local M = require("client.slua.logic.wardrobe.LogicMultiItemModule")
        if type(M) ~= "table" then return end
        if type(M.GetDisPlayItemByGroup) == "function" and not M.__x3ml then
            M.__x3ml = true
            local orig = M.GetDisPlayItemByGroup
            M.GetDisPlayItemByGroup = function(self, GroupID, DataSource, ItemSubType)
                local okR, r = pcall(function()
                    local List = CDataTable.GetTableByFilter("MultiLevelItem", "GroupID", GroupID)
                    local maxLv, maxID = 0, nil
                    for _, v in pairs(List) do
                        local lv = tonumber(v.Level) or 0
                        if lv > maxLv then maxLv = lv maxID = v.ItemID end
                    end
                    return maxID
                end)
                if okR and r then return r end
                return orig(self, GroupID, DataSource, ItemSubType)
            end
        end
        if type(M.SetIsWardrobeMultiShapeTabUnlock) == "function" then
            pcall(M.SetIsWardrobeMultiShapeTabUnlock, M, true)
        end
        _G.X3._MaxLvlHooked = true
        if type(_G.X3.Trace) == "function" then _G.X3.Trace("UNLOCK MAX LEVEL: hook MultiLevelItem terpasang") end
    end)
    -- level senjata in-match (mode PlanBT): selalu maks (7)
    pcall(function()
        if _G.X3._PlanBTHooked then return end
        local ok, F = pcall(require, "GameLua.Mod.PlanBTShooting.Gameplay.Feature.PlanBTWeaponFeature")
        if ok and type(F) == "table" and type(F.GetWeaponLevel) == "function" then
            F.GetWeaponLevel = function(self, WeaponID) return 7 end
            F.IsWeaponMaxLevel = function(self, WeaponID) return true end
            _G.X3._PlanBTHooked = true
        end
    end)
end

function _G.X3._UAOwnershipHookTry()
    if _G.X3._UAOwnHooked then return end
    if not (_G.X3.LexusConfig and _G.X3.LexusConfig.X3UnlockAll) then return end
    pcall(function()
        local WD = require("client.slua.logic.wardrobe.wardrobe_data")
        if type(WD) ~= "table" then return end
        local function alwaysTrue() return true end
        if type(WD.HasValidItem) == "function" then WD.HasValidItem = alwaysTrue end
        if type(WD.HasItem) == "function" then WD.HasItem = alwaysTrue end
        if type(WD.CheckHasPermanentItem) == "function" then WD.CheckHasPermanentItem = alwaysTrue end
        _G.X3._UAOwnHooked = true
        if type(_G.X3.Trace) == "function" then _G.X3.Trace("UNLOCK ALL: ownership hook (HasValidItem=true) terpasang") end
    end)
end

-- DIAGNOSTIK TERLIHAT / VISIBLE DIAGNOSTICS — laporan stage via Notify
function _G.X3._UADiagnose()
    local parts = {}
    local ttype, iterN = "NIL", 0
    pcall(function()
        local t = CDataTable.GetTable("Item")
        ttype = type(t)
        if ttype == "table" then
            for _ in pairs(t) do iterN = iterN + 1 if iterN >= 3 then break end end
        end
    end)
    parts[#parts + 1] = "ItemTable:" .. ttype .. (iterN > 0 and "+iter" or "-iter")
    local entOK, addOK, readOK = "X", "X", "X"
    pcall(function()
        local c = require("client.slua.logic.wardrobe.logic_wardrobe_data_center")
        local ent = c.GetWardrobeData()
        if ent then
            entOK = "OK"
            local it = ent:AddData({ instid = 599999999, res_id = 101001, count = 1 })
            if it then addOK = "OK" end
            local r = ent:GetDataByInsID(599999999)
            if r and r.resID == 101001 then readOK = "OK" end
        end
    end)
    parts[#parts + 1] = "Entity:" .. entOK .. " Add:" .. addOK .. " Read:" .. readOK
    local st = _G.X3._UnlockAllState
    if st then
        parts[#parts + 1] = "List:" .. (st.built and tostring(#st.allIDs) or (st.mode == "scan" and "SCAN" or "?"))
    end
    parts[#parts + 1] = "Own:" .. (_G.X3._UAOwnHooked and "OK" or "X")
    parts[#parts + 1] = "ML:" .. (_G.X3._MaxLvlHooked and "OK" or "X")
    local msg = table.concat(parts, " | ")
    Notify("🔍 UNLOCK ALL: " .. msg)
    if type(_G.X3.Trace) == "function" then _G.X3.Trace("UA DIAG: " .. msg) end
end

-- SKIN ACAK TERBARU / RANDOM NEW SKIN --
    function _G.X3._SkinRandPick(weaponID)
        if _G.X3._SkinRandBySub == nil then
            _G.X3._SkinRandBySub = false
            pcall(function()
                local raw = _G.X3._UAWpnSkinRaw
                if not (raw and #raw > 0) then return end
                local bySub = {}
                for _, e in ipairs(raw) do
                    local id = tonumber(type(e) == "table" and e.ItemTableID or e)
                    if id then
                        local ok, cfg = pcall(function() return CDataTable.GetTableData("Item", id) end)
                        if ok and type(cfg) == "table" then
                            local st = tonumber(cfg.ItemSubType) or 0
                            if st >= 101 and st <= 108 then
                                bySub[st] = bySub[st] or {}
                                local L = bySub[st]
                                if #L < 400 then L[#L + 1] = id end
                            end
                        end
                    end
                end
                _G.X3._SkinRandBySub = bySub
            end)
        end
        local bySub = _G.X3._SkinRandBySub
        if not bySub then return nil end
        weaponID = tonumber(weaponID)
        if not weaponID then return nil end
        _G.X3._SkinRandCache = _G.X3._SkinRandCache or {}
        local cached = _G.X3._SkinRandCache[weaponID]
        if cached ~= nil then
            if cached then return cached end
            return nil
        end
        local st = nil
        pcall(function()
            local cfg = CDataTable.GetTableData("Item", weaponID)
            if type(cfg) == "table" then st = tonumber(cfg.ItemSubType) end
        end)
        local L = st and bySub[st]
        if not (L and #L > 0) then
            _G.X3._SkinRandCache[weaponID] = false
            return nil
        end
        local pick = L[math.random(1, #L)]
        _G.X3._SkinRandCache[weaponID] = pick
        return pick
    end

-- ANTI SPAM TIP / ANTI-SPAM TIPS --
    function _G.X3._XFTipThrottleTry()
        if _G.X3._XFTipThrottled then return end
        pcall(function()
            local ok, T = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameTipsTools")
            if not (ok and type(T) == "table") then return end
            local function wrap(fnName, idIdx)
                local orig = T[fnName]
                if type(orig) ~= "function" then return end
                T[fnName] = function(...)
                    local id = select(idIdx, ...)
                    local now = os.clock()
                    _G.X3._XFTipSeen = _G.X3._XFTipSeen or {}
                    local key = fnName .. "_" .. tostring(id)
                    if _G.X3._XFTipSeen[key] and (now - _G.X3._XFTipSeen[key]) < 12.0 then
                        return
                    end
                    _G.X3._XFTipSeen[key] = now
                    return orig(...)
                end
            end
            wrap("BattleGeneralTip", 1)
            wrap("BattleGeneralTipWithTranslation", 1)
            wrap("BattleGeneralTipWithExternTable", 1)
            _G.X3._XFTipThrottled = true
        end)
    end

do
  if not _G.X3._LogEnriched then
    _G.X3._LogEnriched = true
    local _LEseq = 0
    local _LEctx, _LEctxT = "", -1
    local _inLE = false
    local function _LEstaticCtx()
      local n = os.clock()
      if (n - _LEctxT) < 0.5 and _LEctx ~= "" then return _LEctx end
      _LEctxT = n
      local gs, pf, sp, wh, mem, fps = "?", "-", "-", "-", "?", "?"
      pcall(function()
        local cl = _G.X3 and _G.X3._CL
        if cl and cl.gs then gs = tostring(cl.gs) end
      end)
      pcall(function()
        local GD = package.loaded["GameLua.GameCore.Data.GameplayData"]
        local lp = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
        pf = (lp and slua.isValid(lp)) and "P" or "-"
      end)
      pcall(function() sp = (_G.X3._Spectating == true) and "S" or "-" end)
      pcall(function() wh = (_G.X3.LexusConfig and _G.X3.LexusConfig.WallhackVis == true) and "W" or "-" end)
      pcall(function() mem = tostring(math.floor(collectgarbage("count") / 1024 + 0.5)) end)  -- count TIDAK memicu koleksi (hanya baca KB)
      pcall(function()
        local dt = tonumber(_G.X3.FrameDT)
        if dt and dt > 0 then fps = tostring(math.floor(1 / dt)) end
      end)
      _LEctx = string.format("GS=%s %s%s%s M=%sMB FPS=%s", gs, pf, sp, wh, mem, fps)
      return _LEctx
    end
    local function _LEwrap(orig)
      return function(msg, ...)
        if _inLE or type(orig) ~= "function" then return orig and orig(msg, ...) end
        _inLE = true
        _LEseq = _LEseq + 1
        local enriched = string.format("#%d +%.1fs %s | %s", _LEseq, os.clock(), _LEstaticCtx(), tostring(msg))
        local ok = pcall(orig, enriched, ...)
        _inLE = false
        if not ok then pcall(orig, msg, ...) end   -- fallback tanpa enrich bila orig menolak format
      end
    end
    if type(_G.X3._CrashLog) == "function" then _G.X3._CrashLog = _LEwrap(_G.X3._CrashLog) end
    if type(_G.X3._CrashLogUrgent) == "function" then _G.X3._CrashLogUrgent = _LEwrap(_G.X3._CrashLogUrgent) end
    -- [LOG-UPGRADE-1b] FIREWALL: sisip 1 baris konteks HANYA pada banner bermakna (tanpa spam)
    if type(_G.X3._FWLogWrite) == "function" then
      local _origFW = _G.X3._FWLogWrite
      _G.X3._FWLogWrite = function(lines)
        if type(lines) == "table" and #lines > 0 and not _inLE then
          local first = tostring(lines[1] or "")
          if first:find("LAPORAN STATUS", 1, true) or first:find("FIREWALL PROFILE INSTALLED", 1, true)
             or first:find("PLAYER MATCH", 1, true) or first:find("AKHIR LAPORAN", 1, true)
             or first:find("========", 1, true) then
            _LEseq = _LEseq + 1
            local ctxLine = string.format("#%d +%.1fs %s | [FW-CTX]", _LEseq, os.clock(), _LEstaticCtx())
            local copy = { ctxLine }                       -- shallow copy (jangan mutasi tabel pemanggil)
            for i = 1, #lines do copy[i + 1] = lines[i] end
            return _origFW(copy)
          end
        end
        return _origFW(lines)
      end
    end
  end
end

do
  if not _G.X3._MemWatchdog then
    _G.X3._MemWatchdog = true
    local CEIL  = 110          -- TARGET MAKSIMAL MB (permintaan Anda)
    local EMER  = 132          -- darurat: full-collect terkontrol (jaring anti-OOM crash)
    local _mwLast, _mwStepT, _mwEmerT = -1, -1, -1
    local _mwPersist, _mwPersistLog = 0, false
    local function _mwMB() return collectgarbage("count") / 1024 end   -- count TIDAK memicu collect
    local function _mwRun()
      local n = os.clock()
      if (n - _mwLast) < 1.0 then return end                            -- 1x/dtk
      _mwLast = n
      local mb = _mwMB()
      _G.X3._MemMB = mb                                                 -- telemetri: MB saat ini
      if mb > (_G.X3._MemPeak or 0) then _G.X3._MemPeak = mb end        -- telemetri: puncak sesi
      if mb > EMER then
        if (n - _mwEmerT) > 15 then                                     -- darurat max 1x/15 dtk
          _mwEmerT = n
          pcall(function() collectgarbage("collect") end)               -- jaring anti-OOM (hitch diterima)
          if _G.X3._CrashLogUrgent then pcall(_G.X3._CrashLogUrgent, "MEMWATCH: DARURAT >" .. EMER .. "MB -> full-collect 1x (jaring anti-OOM); peak=" .. string.format("%.0f", _G.X3._MemPeak or 0) .. "MB -> potong sumber leak (F-06/cache)") end
        end
        _mwPersist = 0
      elseif mb > CEIL then
        _G.X3._MemCeilHits = (_G.X3._MemCeilHits or 0) + 1              -- telemetri: berapa kali ceiling tertembus
        if (n - _mwStepT) > 2 then _mwStepT = n; pcall(function() collectgarbage("step", 4000) end) end
        _mwPersist = _mwPersist + 1
        if _mwPersist >= 3 and not _mwPersistLog then                   -- ceiling tertembus persisten = objek HIDUP, bukan sampah
          _mwPersistLog = true
          if _G.X3._CrashLogUrgent then pcall(_G.X3._CrashLogUrgent, "MEMWATCH: ceiling " .. CEIL .. "MB tertembus persisten -> ini OBJEK HIDUP (bukan sampah); wajib potong sumber (F-06 print + cap cache + spectator cap), bukan sekadar sapu") end
        end
      elseif mb > (CEIL - 10) then
        if (n - _mwStepT) > 2 then _mwStepT = n; pcall(function() collectgarbage("step", 1500) end) end
        _mwPersist = 0
      elseif mb > (CEIL - 20) then
        if (n - _mwStepT) > 3 then _mwStepT = n; pcall(function() collectgarbage("step", 600) end) end
        _mwPersist = 0; _mwPersistLog = false
      else
        _mwPersist = 0; _mwPersistLog = false                            -- sehat: reset flag
      end
    end
    if type(_G.X3._CrashLogFlush) == "function" then
      local _origFlush = _G.X3._CrashLogFlush
      _G.X3._CrashLogFlush = function()
        pcall(_mwRun)                                                    -- watchdog dulu (telemetri+enforce)
        return _origFlush()                                              -- lalu flush log asli
      end
    end
  end
end


-- === END INTEGRATED NEW SKIN BLOCKS ===

-- ==============================================================================
-- RUN TIME TICKER FOR NEW SKIN SYSTEM (LOBBY + GAMEPLAY)
-- ==============================================================================
local _ticker = require("common.time_ticker")
local _timeCount = 0

-- Force Lexus Config Defaults
_G.X3 = _G.X3 or {}
_G.X3.LexusConfig = _G.X3.LexusConfig or {}
_G.X3.LexusConfig.ModSkin = true
_G.X3.LexusConfig.X3UnlockAll = true
_G.X3.LexusState = _G.X3.LexusState or {}

local function getLocalChar()
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    return GameplayData and GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
end

local function isInGamePlay()
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    return GameplayData and GameplayData.IsGamePlayState and GameplayData.IsGamePlayState()
end

-- Initialize systems immediately on load
pcall(function()
    if _G.X3.InitializeSkinModSystem then _G.X3.InitializeSkinModSystem() end
    if _G.X3.ForceRefreshSkinMaps then _G.X3.ForceRefreshSkinMaps() end
    if _G.X3._MaxLevelHookTry then pcall(_G.X3._MaxLevelHookTry) end
    if _G.X3.SkinUnlockScan then pcall(_G.X3.SkinUnlockScan, true) end
end)

local function fastApplyLoop()
    pcall(function()
        if isInGamePlay() then
            local localPlayer = getLocalChar()
            if localPlayer and slua.isValid(localPlayer) then
                if not _G.X3.TDSkinLoopStarted then
                    if _G.X3.InitializeSkinModSystem then _G.X3.InitializeSkinModSystem() end
                    if _G.X3.ForceRefreshSkinMaps then _G.X3.ForceRefreshSkinMaps() end
                    if _G.X3.SkinUnlockScan then pcall(_G.X3.SkinUnlockScan, true) end
                    _G.X3.TDSkinLoopStarted = true
                end
                _G.X3.LexusState.SkinWasApplied = true
                
                local curTime = os.clock()
                local _skinSig = nil
                pcall(function()
                    local wm = localPlayer.GetWeaponManager and localPlayer:GetWeaponManager() or localPlayer.WeaponManagerComponent
                    local s = ""
                    if wm then
                        for slot = 1, 4 do
                            local w = wm.GetInventoryWeaponByPropSlot and wm:GetInventoryWeaponByPropSlot(slot)
                            local wid = 0
                            if w and slua.isValid(w) then
                                pcall(function() wid = w:GetWeaponID() or 0 end)
                            end
                            s = s .. wid .. ","
                        end
                    end
                    local v = localPlayer.CurrentVehicle
                    s = s .. "V" .. tostring((v and slua.isValid(v)) and 1 or 0)
                    local om = _G.X3.OutfitMap or {}
                    s = s .. "|S" .. tostring(om.Suit or 0)
                        .. "|B" .. tostring(type(om.Bag) == "table" and (om.Bag[1] or 0) or (om.Bag or 0))
                        .. "|H" .. tostring(type(om.Helmet) == "table" and (om.Helmet[1] or 0) or (om.Helmet or 0))
                    _skinSig = s
                end)
                
                local _heavyNeeded = (_skinSig ~= (_G.X3._SkinLoadoutSig or "")) or (curTime - (_G.X3._SkinHeavyAt or 0)) > 20.0
                if _heavyNeeded then
                    _G.X3._SkinLoadoutSig = _skinSig
                    _G.X3._SkinHeavyAt = curTime
                end
                
                local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
                if _heavyNeeded then
                    pcall(function()
                        if isAlive then
                            if _G.X3.ReadLiveConfig then _G.X3.ReadLiveConfig() end
                            if _G.X3.equip_character_avatar then _G.X3.equip_character_avatar(localPlayer) end
                            if _G.X3.ApplyWeaponSkins then _G.X3.ApplyWeaponSkins(localPlayer) end
                            if _G.X3.ApplyVehicleSkins then _G.X3.ApplyVehicleSkins(localPlayer) end
                        end
                    end)
                end
                
                pcall(function()
                    if isAlive then
                        if _G.X3.BpEnsure then pcall(_G.X3.BpEnsure) end
                        if _G.X3.SkinUnlock and _G.X3.SkinUnlock.Init then pcall(_G.X3.SkinUnlock.Init) end
                        if _G.X3.ApplyBackpackSkinDisplay then pcall(_G.X3.ApplyBackpackSkinDisplay, localPlayer) end
                        if _G.X3.HandlePetLogic then _G.X3.HandlePetLogic() end
                        if _G.X3.ApplyAvatarBorder then _G.X3.ApplyAvatarBorder() end
                    end
                end)
            end
        else
            -- LOBBY UPDATE LOOP
            pcall(function()
                if _G.X3.SkinUnlock and _G.X3.SkinUnlock.Init then pcall(_G.X3.SkinUnlock.Init) end
                if _G.X3.SkinUnlockScan then pcall(_G.X3.SkinUnlockScan, false) end
            end)
        end
    end)
    _timeCount = _timeCount + 1
    if _ticker and _ticker.AddTimerOnce then
        _ticker.AddTimerOnce(1.5, fastApplyLoop)
    end
end

if _ticker and _ticker.AddTimerOnce then
    _ticker.AddTimerOnce(1.5, fastApplyLoop)
end
-- Ghi log vào file dx_crashlog.txt nằm cùng thư mục với Menu_Settings.txt
local function LogToCrashlog(msg)
    pcall(function()
        local timeStr = ""
        pcall(function()
            if os and os.date then
                timeStr = "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] "
            end
        end)
        local formattedMsg = timeStr .. tostring(msg) .. "\n"
        local paths = GetConfigPaths("dx_crashlog.txt")
        for _, path in ipairs(paths) do
            local file = io.open(path, "a")
            if file then
                file:write(formattedMsg)
                file:close()
                break
            end
        end
    end)
end

-- Hàm dọn RAM định kỳ tổng quát
local function StartRAMCleaner()
    if _G._RAMCleanerRunning then return end
    _G._RAMCleanerRunning = true

    local function RunRAMCleanerCycle()
        pcall(function()
            local before = collectgarbage("count")
            collectgarbage("step", 200)
            local after = collectgarbage("count")
            local freed = before - after
            if freed > 0.1 then
                local logMsg = string.format("[RAM Cleaner] Truoc: %.2f KB | Sau: %.2f KB | Giai phong: %.2f KB", before, after, freed)
                print(logMsg)
                LogToCrashlog(logMsg)
            end
        end)
        
        -- Tự gọi lại sau mỗi 25 giây qua bộ đếm thời gian (nếu có)
        local ok, ticker = pcall(require, "common.time_ticker")
        if ok and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(25.0, RunRAMCleanerCycle)
        else
            _G._RAMCleanerRunning = false
            pcall(function()
                LogToCrashlog("[RAM Cleaner] Khong tim thay ticker hoac khong ho tro AddTimerOnce")
            end)
        end
    end

    RunRAMCleanerCycle()
end

return true