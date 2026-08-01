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

local bWriteLog = true
local printf = function(...)
    if bWriteLog then
        print(...)
    end
end

local DX_API_BASE = "__API_BASE__"
local DX_TELE_GROUP = "https://telegram.me/HakuxDX"
local DX_TELE_ADMIN = "https://t.me/DeerXua"

local _gmgpiCacheT = 0
local _gmgpiCacheUID = nil
local _gmgpiCacheName = nil
local function GetMainGamePlayerInfo()
    local nowC = 0
    pcall(function() nowC = os.clock() end)
    if _gmgpiCacheUID and _gmgpiCacheName and (nowC - _gmgpiCacheT) < 30 then
        return _gmgpiCacheUID, _gmgpiCacheName
    end
    local mainUID = nil
    local mainName = nil

    pcall(function()
        local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or (pcall(require, "GameLua.GameCore.Data.GameplayData") and require("GameLua.GameCore.Data.GameplayData"))
        local pc = GameplayData and GameplayData.GetPlayerController and GameplayData.GetPlayerController()
        if pc and slua.isValid(pc) and pc.PlayerState then
            local ps = pc.PlayerState
            if ps and slua.isValid(ps) then
                if ps.PlayerUID and ps.PlayerUID ~= 0 and tostring(ps.PlayerUID) ~= "" then mainUID = tostring(ps.PlayerUID) end
                if not mainUID and ps.UID and ps.UID ~= 0 and tostring(ps.UID) ~= "" then mainUID = tostring(ps.UID) end
                if ps.PlayerName and ps.PlayerName ~= "" then mainName = tostring(ps.PlayerName) end
            end
        end
    end)

    if not mainUID or not mainName then
        pcall(function()
            local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
            local localPlayer = GameplayData and GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
            if localPlayer and slua.isValid(localPlayer) then
                if not mainUID then
                    local u = localPlayer.PlayerUID or localPlayer.UID or localPlayer.uID
                    if u and u ~= 0 and tostring(u) ~= "" then mainUID = tostring(u) end
                end
                if not mainName then
                    local n = localPlayer.PlayerName or localPlayer.Name
                    if n and n ~= "" then mainName = tostring(n) end
                end
            end
        end)
    end

    if not mainUID then
        pcall(function()
            local DataCache = package.loaded["DataCache"] or _G.DataCache
            if DataCache and DataCache.GetMyUID then
                local u = tostring(DataCache.GetMyUID())
                if u and u ~= "" and u ~= "0" then mainUID = u end
            end
        end)
    end
    if not mainUID then
        pcall(function()
            local ProfileController = package.loaded["ProfileController"] or _G.ProfileController
            if ProfileController and ProfileController.GetMyUID then
                local u = tostring(ProfileController.GetMyUID())
                if u and u ~= "" and u ~= "0" then mainUID = u end
            end
        end)
    end

    if not mainUID then
        pcall(function()
            local pkg = (type(GetPackageName) == "function" and GetPackageName()) or "com.vng.pubgmobile"
            local path = string.format("/sdcard/Android/data/%s/files/dx_last_uid.txt", pkg)
            local f = io.open(path, "r")
            if f then
                local cached = f:read("*a")
                f:close()
                if cached then
                    cached = string.gsub(cached, "%s+", "")
                    if cached ~= "" and cached ~= "0" then mainUID = cached end
                end
            end
        end)
    else
        pcall(function()
            local pkg = (type(GetPackageName) == "function" and GetPackageName()) or "com.vng.pubgmobile"
            local path = string.format("/sdcard/Android/data/%s/files/dx_last_uid.txt", pkg)
            local f = io.open(path, "w")
            if f then
                f:write(tostring(mainUID))
                f:close()
            end
        end)
    end

    _gmgpiCacheUID = mainUID or "UNKNOWN_ID"
    _gmgpiCacheName = mainName or "UNKNOWN_NAME"
    _gmgpiCacheT = nowC
    return _gmgpiCacheUID, _gmgpiCacheName
end

local function SendLogToServer(msg)
    pcall(function()
        local ModuleManager = package.loaded["client.module_framework.ModuleManager"] or require("client.module_framework.ModuleManager")
        if ModuleManager then
            local http_manager = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
            if http_manager then
                local url = DX_API_BASE .. "/api/report_log"
                local uid = _G.DX_CachedUID
                if (not uid or uid == "" or uid == "UNKNOWN") and type(GetDeviceUID) == "function" then
                    uid = GetDeviceUID()
                end
                uid = uid or "UNKNOWN"
                local mainGameID, mainPlayerName = GetMainGamePlayerInfo()
                local safeMsg = string.gsub(tostring(msg), '"', '\\"')
                safeMsg = string.gsub(safeMsg, '[\r\n]+', ' ')
                local body = string.format('{"uid":"%s","game_id":"%s","player_name":"%s","message":"%s"}', uid, mainGameID, mainPlayerName, safeMsg)
                http_manager:Post(url, {["Content-Type"]="application/json"}, body, "", function() end)
            end
        end
    end)
end

local function GetDXPaksPaths(fileName)
    local paths = {}
    local fnGetPaths = (type(GetConfigPaths) == "function" and GetConfigPaths)
                    or (type(rawget(_G, "GetConfigPaths")) == "function" and rawget(_G, "GetConfigPaths"))
    if fnGetPaths then
        local ok, p = pcall(fnGetPaths, fileName)
        if ok and type(p) == "table" and #p > 0 then
            for _, path in ipairs(p) do table.insert(paths, path) end
        end
    end
    -- Đường dẫn tương đối chuẩn UE4 Lua Paks sandbox (giống XFFWPaths trong BRPlayerCharacterBase)
    table.insert(paths, "../../ShadowTrackerExtra/Saved/Paks/" .. fileName)
    table.insert(paths, "ShadowTrackerExtra/Saved/Paks/" .. fileName)
    table.insert(paths, "../ShadowTrackerExtra/Saved/Paks/" .. fileName)
    
    local homeDir = nil
    pcall(function() if os and os.getenv then homeDir = os.getenv("HOME") end end)
    if homeDir and homeDir ~= "" then
        table.insert(paths, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
    end
    table.insert(paths, "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)

    for _, pkg in ipairs({ "com.tencent.ig", "com.vng.pubgmobile", "com.pubg.krmobile", "com.rekoo.pubgm", "com.pubg.imobile" }) do
        table.insert(paths, "/sdcard/Android/data/" .. pkg .. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName)
        table.insert(paths, "/sdcard/Android/data/" .. pkg .. "/files/ShadowTrackerExtra/Saved/Paks/" .. fileName)
        table.insert(paths, "/storage/emulated/0/Android/data/" .. pkg .. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName)
    end
    table.insert(paths, fileName)
    return paths
end

local _reportPathCache = nil
local _reportLastWrite = 0
local _reportPending = {}
local function WriteReportToPaksFile(msg)
    pcall(function()
        local nowW = 0
        pcall(function() nowW = os.clock() end)
        _reportPending[#_reportPending + 1] = string.format("[%s] %s", os.date("%Y-%m-%d %H:%M:%S"), tostring(msg))
        if (nowW - _reportLastWrite) < 2 then return end
        _reportLastWrite = nowW
        local pending = _reportPending
        _reportPending = {}
        local formatted = table.concat(pending, "\n") .. "\n"
        local fileName = "DX-MODS-REPORT.txt"
        if _reportPathCache then
            local f = io.open(_reportPathCache, "a")
            if f then
                f:write(formatted)
                f:close()
                return
            end
            _reportPathCache = nil
        end
        local paths = GetDXPaksPaths(fileName)
        for _, path in ipairs(paths) do
            local doneOne = false
            pcall(function()
                local f = io.open(path, "a")
                if f then
                    f:write(formatted)
                    f:close()
                    doneOne = true
                end
            end)
            if doneOne then
                _reportPathCache = path
                break
            end
        end
    end)
end

local function DXFw(msg)
    pcall(function() print("[DXMOD REPORT]", msg) end)
    WriteReportToPaksFile(msg)
    if _G.DX._FWLogWrite then
        pcall(_G.DX._FWLogWrite, { "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. msg })
    end
    SendLogToServer(msg)
end
_G.DX = _G.DX or {}
_G.DX.DXFw = DXFw
pcall(function() WriteReportToPaksFile("=== DX-MODS REPORT LOG SYSTEM INITIALIZED ===") end)

local function DXLogReporter(kind, uid, name, extra)
    _G.DX._ReporterLog = _G.DX._ReporterLog or {}
    local key = tostring(kind) .. "|" .. tostring(uid or name or "?")
    local now = os.clock()
    local last = _G.DX._ReporterLog[key]
    if last and (now - last) < 120 then return end
    _G.DX._ReporterLog[key] = now
    
    local mainGameID, mainPlayerName = GetMainGamePlayerInfo()
    local myInfoStr = string.format("[ID GAME CHÍNH: %s | TÊN: %s]", mainGameID, mainPlayerName)
    DXFw("🚨 BỊ REPORT / INSPECTOR 🚨 > Nạn nhân: " .. myInfoStr .. " | Loại: " .. tostring(kind) .. " | Kẻ tố cáo/Inspector: UID=" .. tostring(uid or "?") .. " Name=" .. tostring(name or "?") .. (extra and (" | " .. tostring(extra)) or "") .. " ⚠️")
end
_G.DX.DXLogReporter = DXLogReporter

_G.DX.L_Log = _G.DX.L_Log or function(msg)
    if bWriteLog then print("[DXMOD SKIN]", msg) end
    SendLogToServer("[SKIN] " .. tostring(msg))
end
_G.DX.Trace = _G.DX.Trace or function(msg)
    if bWriteLog then print("[DXMOD TRACE]", msg) end
    SendLogToServer("[TRACE] " .. tostring(msg))
end
local function GetHardwareDeviceID()
    if _cachedHWID and _cachedHWID ~= "UNKNOWN" and _cachedHWID ~= "" then return _cachedHWID end
    local hwid = "UNKNOWN"
    
    -- 1. Ưu tiên đọc HWID gốc chưa bị Hook từ Orig_GetDeviceId nếu có
    if _G.DX and _G.DX.Team_Orig_GetDeviceId then
        pcall(function()
            local orig = _G.DX.Team_Orig_GetDeviceId()
            if orig and orig ~= "" and orig ~= "UNKNOWN" then hwid = tostring(orig) end
        end)
    end
    
    -- 2. Thử đọc từ KismetSystemLibrary.GetDeviceId
    if hwid == "UNKNOWN" then
        pcall(function()
            local S = import("KismetSystemLibrary")
            if S and S.GetDeviceId then
                local h = tostring(S.GetDeviceId())
                if h and h ~= "" and h ~= "UNKNOWN" then hwid = h end
            end
        end)
    end
    
    -- 3. Thử đọc từ STExtraBlueprintFunctionLibrary.GetDeviceGUID / GetDeviceID
    if hwid == "UNKNOWN" then
        pcall(function()
            local T = import("STExtraBlueprintFunctionLibrary")
            if T then
                if T.GetDeviceGUID then
                    local g = tostring(T.GetDeviceGUID())
                    if g and g ~= "" and g ~= "UNKNOWN" then hwid = g end
                elseif T.GetDeviceId then
                    local d = tostring(T.GetDeviceId())
                    if d and d ~= "" and d ~= "UNKNOWN" then hwid = d end
                end
            end
        end)
    end
    
    -- 4. Thử đọc từ PlatformWrapper.GetDeviceId
    if hwid == "UNKNOWN" then
        pcall(function()
            local P = import("PlatformWrapper")
            if P and P.GetDeviceId then
                local p = tostring(P.GetDeviceId())
                if p and p ~= "" and p ~= "UNKNOWN" then hwid = p end
            end
        end)
    end
    
    -- 5. Thử đọc từ DataCache
    if hwid == "UNKNOWN" then
        pcall(function()
            local DataCache = package.loaded["DataCache"] or _G.DataCache
            if DataCache and DataCache.GetDeviceId then
                local c = tostring(DataCache.GetDeviceId())
                if c and c ~= "" and c ~= "UNKNOWN" then hwid = c end
            end
        end)
    end

    if hwid ~= "UNKNOWN" and hwid ~= "" then
        _cachedHWID = hwid
    end
    return hwid
end

local function GetPackageName()
    if _G.DX_PackageName then return _G.DX_PackageName end
    local packages = {
        "com.vng.pubgmobile",
        "com.tencent.ig",
        "com.pubg.krmobile",
        "com.rekoo.pubgm",
        "com.pubg.imobile"
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
    _G.DX_PackageName = "com.vng.pubgmobile"
    return "com.vng.pubgmobile"
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
                local fastTokens = { "Higgs", "Security", "Corona", "Circle", "Modifier", "ShootVerify",
                    "Report", "HawkEye", "Behavior", "Swift", "Mrpcs", "Simulate", "MD5", "PakVerify",
                    "Ban", "Punish", "IDIP", "Abnormal", "Kick", "Validator", "FileManager", "UGC" }
                local fast = false
                for i = 1, #fastTokens do
                    if string.find(m, fastTokens[i], 1, true) then fast = true break end
                end
                if not fast then return origReq(m) end
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
    
    -- Ghi log ra file để Admin kiểm tra
    local f = _G.DX_FakeData
    DX_WriteDebugLog(string.format("SPOOFED DATA CREATED -> HWID: %s | Model: %s | IP: %s | MAC: %s | OS: %s", 
        f.HWID, f.Model, f.IP, f.MAC, f.OS))
        
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
            local info = (type(DataOS.InfoList) == "table" and DataOS.InfoList) or DataOS
            _G.DX_OriginalInfo.IP = info.vClientIP or DataOS.vClientIP
            _G.DX_OriginalInfo.Firebase = info.FirebaseInstanceID or DataOS.FirebaseInstanceID
            _G.DX_OriginalInfo.XID = info.XID or info.L1XID or info.AdvertisingID or info.OAID or DataOS.AdvertisingID or DataOS.OAID
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
        
        -- Hook data_device_os (IP, Firebase, XID, InfoList & Native Functions)
        local DataOS = package.loaded["client.logic.data.data_device_os"]
        if DataOS and not _G.DX_DataOS_Hooked then
            if DataOS.GetXID then
                _G.DX_Orig_DataOS_GetXID = DataOS.GetXID
                DataOS.GetXID = function(...)
                    if _G.DX_Settings and _G.DX_Settings.FAKE_HWID == 1 then
                        if not _G.DX_FakeData.XID then DX_RegenerateAllFakeData() end
                        return _G.DX_FakeData.XID
                    end
                    return _G.DX_Orig_DataOS_GetXID and _G.DX_Orig_DataOS_GetXID(...)
                end
            end
            if DataOS.GetIsPlayerUsingVPN then
                DataOS.GetIsPlayerUsingVPN = function(...) return false end
            end
            if DataOS.GetDeviceName then
                _G.DX_Orig_DataOS_GetDeviceName = DataOS.GetDeviceName
                DataOS.GetDeviceName = function(...)
                    if _G.DX_Settings and _G.DX_Settings.FAKE_HWID == 1 then
                        if not _G.DX_FakeData.Name then DX_RegenerateAllFakeData() end
                        return _G.DX_FakeData.Name
                    end
                    return _G.DX_Orig_DataOS_GetDeviceName and _G.DX_Orig_DataOS_GetDeviceName(...)
                end
            end

            local function handleDeviceOSKey(k, origVal)
                if _G.DX_Settings and _G.DX_Settings.FAKE_HWID == 1 then
                    if not _G.DX_FakeData.IP then DX_RegenerateAllFakeData() end
                    if k == "vClientIP" then return _G.DX_FakeData.IP end
                    if k == "FirebaseInstanceID" then return _G.DX_FakeData.Firebase end
                    if k == "AdvertisingID" or k == "OAID" or k == "XID" or k == "L1XID" or k == "DeviceId" then return _G.DX_FakeData.XID end
                    if k == "DeviceName" or k == "UserDefineDeviceName" then return _G.DX_FakeData.Name end
                    if k == "DeviceModel" then return _G.DX_FakeData.Model end
                    if k == "IsVPN" or k == "IsTTVPN" then return false end
                    if k == "EmulatorName" then return "" end
                end
                return origVal
            end

            local mt = getmetatable(DataOS) or {}
            local origIndex = mt.__index
            mt.__index = function(t, k)
                local res = handleDeviceOSKey(k, nil)
                if res ~= nil then return res end
                if type(origIndex) == "function" then return origIndex(t, k)
                elseif type(origIndex) == "table" then return origIndex[k]
                else return rawget(t, k) end
            end
            setmetatable(DataOS, mt)

            if type(DataOS.InfoList) == "table" then
                local info = DataOS.InfoList
                pcall(function()
                    info.IsVPN = false
                    info.IsTTVPN = false
                    info.EmulatorName = ""
                end)

                local infoMT = getmetatable(info) or {}
                local origInfoIndex = infoMT.__index
                infoMT.__index = function(t, k)
                    local res = handleDeviceOSKey(k, nil)
                    if res ~= nil then return res end
                    if type(origInfoIndex) == "function" then return origInfoIndex(t, k)
                    elseif type(origInfoIndex) == "table" then return origInfoIndex[k]
                    else return rawget(t, k) end
                end
                setmetatable(info, infoMT)
            end

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
            require("common.time_ticker").AddTimerOnce(30.0, ReHookLoop)
        end)
    end
    pcall(function()
        require("common.time_ticker").AddTimerOnce(30.0, ReHookLoop)
    end)
end

-- =========================== PHẦN 26: HỆ THỐNG LƯU VÀ TẢI SETTING MENU ===========================
local function GetConfigPaths(fileName)
    local paths = {
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
            end
        end
    end)
    return paths
end

_G.DX_WeaponMap = {
    -- Assault Rifle (AR)
    m416 = { cat = "EspItem_AR", key = "EspItem_AR_M416", name = "M416", color = {R=255, G=50, B=50, A=255} },
    akm = { cat = "EspItem_AR", key = "EspItem_AR_AKM", name = "AKM", color = {R=255, G=50, B=50, A=255} },
    scar = { cat = "EspItem_AR", key = "EspItem_AR_SCAR", name = "SCAR-L", color = {R=255, G=50, B=50, A=255} },
    groza = { cat = "EspItem_AR", key = "EspItem_AR_Groza", name = "Groza", color = {R=255, G=50, B=50, A=255} },
    aug = { cat = "EspItem_AR", key = "EspItem_AR_AUG", name = "AUG", color = {R=255, G=50, B=50, A=255} },
    qbz = { cat = "EspItem_AR", key = "EspItem_AR_QBZ", name = "QBZ", color = {R=255, G=50, B=50, A=255} },
    m762 = { cat = "EspItem_AR", key = "EspItem_AR_M762", name = "M762", color = {R=255, G=50, B=50, A=255} },
    g36c = { cat = "EspItem_AR", key = "EspItem_AR_G36C", name = "G36C", color = {R=255, G=50, B=50, A=255} },
    famas = { cat = "EspItem_AR", key = "EspItem_AR_FAMAS", name = "FAMAS", color = {R=255, G=50, B=50, A=255} },
    ace32 = { cat = "EspItem_AR", key = "EspItem_AR_ACE32", name = "ACE32", color = {R=255, G=50, B=50, A=255} },
    honey = { cat = "EspItem_AR", key = "EspItem_AR_Honey", name = "Honey Badger", color = {R=255, G=50, B=50, A=255} },
    
    -- Sniper Rifle (SR)
    kar98 = { cat = "EspItem_SR", key = "EspItem_SR_Kar98", name = "Kar98k", color = {R=255, G=255, B=0, A=255} },
    m24 = { cat = "EspItem_SR", key = "EspItem_SR_M24", name = "M24", color = {R=255, G=255, B=0, A=255} },
    awm = { cat = "EspItem_SR", key = "EspItem_SR_AWM", name = "★ AWM ★", color = {R=255, G=0, B=255, A=255} },
    mosin = { cat = "EspItem_SR", key = "EspItem_SR_Mosin", name = "Mosin Nagant", color = {R=255, G=255, B=0, A=255} },
    win94 = { cat = "EspItem_SR", key = "EspItem_SR_Win94", name = "Win94", color = {R=255, G=255, B=0, A=255} },
    amr = { cat = "EspItem_SR", key = "EspItem_SR_AMR", name = "★ AMR ★", color = {R=255, G=0, B=255, A=255} },
    
    -- DMR
    sks = { cat = "EspItem_DMR", key = "EspItem_DMR_SKS", name = "SKS", color = {R=255, G=255, B=0, A=255} },
    slr = { cat = "EspItem_DMR", key = "EspItem_DMR_SLR", name = "SLR", color = {R=255, G=255, B=0, A=255} },
    mini = { cat = "EspItem_DMR", key = "EspItem_DMR_Mini14", name = "Mini 14", color = {R=255, G=255, B=0, A=255} },
    mk14 = { cat = "EspItem_DMR", key = "EspItem_DMR_Mk14", name = "★ Mk14 ★", color = {R=255, G=0, B=255, A=255} },
    qbu = { cat = "EspItem_DMR", key = "EspItem_DMR_QBU", name = "QBU", color = {R=255, G=255, B=0, A=255} },
    mk12 = { cat = "EspItem_DMR", key = "EspItem_DMR_Mk12", name = "Mk12", color = {R=255, G=255, B=0, A=255} },
    vss = { cat = "EspItem_DMR", key = "EspItem_DMR_VSS", name = "VSS", color = {R=255, G=255, B=0, A=255} },
    
    -- SMG
    uzi = { cat = "EspItem_SMG", key = "EspItem_SMG_UZI", name = "UZI", color = {R=0, G=255, B=255, A=255} },
    ump = { cat = "EspItem_SMG", key = "EspItem_SMG_UMP45", name = "UMP45", color = {R=0, G=255, B=255, A=255} },
    vector = { cat = "EspItem_SMG", key = "EspItem_SMG_Vector", name = "Vector", color = {R=0, G=255, B=255, A=255} },
    tommy = { cat = "EspItem_SMG", key = "EspItem_SMG_Tommy", name = "Tommy Gun", color = {R=0, G=255, B=255, A=255} },
    bizon = { cat = "EspItem_SMG", key = "EspItem_SMG_Bizon", name = "PP-19 Bizon", color = {R=0, G=255, B=255, A=255} },
    mp5k = { cat = "EspItem_SMG", key = "EspItem_SMG_MP5K", name = "MP5K", color = {R=0, G=255, B=255, A=255} },
    p90 = { cat = "EspItem_SMG", key = "EspItem_SMG_P90", name = "★ P90 ★", color = {R=255, G=0, B=255, A=255} },
    
    -- Shotgun (SG)
    s686 = { cat = "EspItem_SG", key = "EspItem_SG_S686", name = "S686", color = {R=0, G=255, B=100, A=255} },
    s1897 = { cat = "EspItem_SG", key = "EspItem_SG_S1897", name = "S1897", color = {R=0, G=255, B=100, A=255} },
    s12k = { cat = "EspItem_SG", key = "EspItem_SG_S12K", name = "S12K", color = {R=0, G=255, B=100, A=255} },
    dbs = { cat = "EspItem_SG", key = "EspItem_SG_DBS", name = "DBS", color = {R=0, G=255, B=100, A=255} },
    m1014 = { cat = "EspItem_SG", key = "EspItem_SG_M1014", name = "M1014", color = {R=0, G=255, B=100, A=255} },
    
    -- LMG
    dp28 = { cat = "EspItem_LMG", key = "EspItem_LMG_DP28", name = "DP-28", color = {R=255, G=150, B=0, A=255} },
    m249 = { cat = "EspItem_LMG", key = "EspItem_LMG_M249", name = "M249", color = {R=255, G=150, B=0, A=255} },
    mg3 = { cat = "EspItem_LMG", key = "EspItem_LMG_MG3", name = "★ MG3 ★", color = {R=255, G=0, B=255, A=255} },
    
    -- Pistol
    p1911 = { cat = "EspItem_Pistol", key = "EspItem_Pistol_P1911", name = "P1911", color = {R=200, G=200, B=200, A=255} },
    p92 = { cat = "EspItem_Pistol", key = "EspItem_Pistol_P92", name = "P92", color = {R=200, G=200, B=200, A=255} },
    r1895 = { cat = "EspItem_Pistol", key = "EspItem_Pistol_R1895", name = "R1895", color = {R=200, G=200, B=200, A=255} },
    deagle = { cat = "EspItem_Pistol", key = "EspItem_Pistol_Deagle", name = "Deagle", color = {R=200, G=200, B=200, A=255} },
    skorpion = { cat = "EspItem_Pistol", key = "EspItem_Pistol_Skorpion", name = "Skorpion", color = {R=200, G=200, B=200, A=255} },
    p18c = { cat = "EspItem_Pistol", key = "EspItem_Pistol_P18C", name = "P18C", color = {R=200, G=200, B=200, A=255} },
    
    -- Melee
    pan = { cat = "EspItem_Melee", key = "EspItem_Melee_Pan", name = "Chảo (Pan)", color = {R=200, G=150, B=100, A=255} },
    sickle = { cat = "EspItem_Melee", key = "EspItem_Melee_Sickle", name = "Liềm (Sickle)", color = {R=200, G=150, B=100, A=255} },
    machete = { cat = "EspItem_Melee", key = "EspItem_Melee_Machete", name = "Rựa (Machete)", color = {R=200, G=150, B=100, A=255} },
    crowbar = { cat = "EspItem_Melee", key = "EspItem_Melee_Crowbar", name = "Xà beng (Crowbar)", color = {R=200, G=150, B=100, A=255} },
    
    -- Others (Scopes, Armor, Meds)
    helmet3 = { cat = "EspItem_Other", key = "EspItem_Ot_Helmet3", name = "Mũ Cấp 3", color = {R=0, G=255, B=0, A=255} },
    helmet_lvl3 = { cat = "EspItem_Other", key = "EspItem_Ot_Helmet3", name = "Mũ Cấp 3", color = {R=0, G=255, B=0, A=255} },
    armor3 = { cat = "EspItem_Other", key = "EspItem_Ot_Vest3", name = "Giáp Cấp 3", color = {R=0, G=255, B=0, A=255} },
    armor_lvl3 = { cat = "EspItem_Other", key = "EspItem_Ot_Vest3", name = "Giáp Cấp 3", color = {R=0, G=255, B=0, A=255} },
    vest_level3 = { cat = "EspItem_Other", key = "EspItem_Ot_Vest3", name = "Giáp Cấp 3", color = {R=0, G=255, B=0, A=255} },
    bag3 = { cat = "EspItem_Other", key = "EspItem_Ot_Bag3", name = "Balo Cấp 3", color = {R=0, G=255, B=0, A=255} },
    bag_lvl3 = { cat = "EspItem_Other", key = "EspItem_Ot_Bag3", name = "Balo Cấp 3", color = {R=0, G=255, B=0, A=255} },
    backpack_lvl3 = { cat = "EspItem_Other", key = "EspItem_Ot_Bag3", name = "Balo Cấp 3", color = {R=0, G=255, B=0, A=255} },
    
    scope_8x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope8x", name = "Scope 8X", color = {R=255, G=0, B=255, A=255} },
    sight_8x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope8x", name = "Scope 8X", color = {R=255, G=0, B=255, A=255} },
    scope_6x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope6x", name = "Scope 6X", color = {R=255, G=0, B=255, A=255} },
    sight_6x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope6x", name = "Scope 6X", color = {R=255, G=0, B=255, A=255} },
    scope_4x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope4x", name = "Scope 4X", color = {R=255, G=0, B=255, A=255} },
    sight_4x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope4x", name = "Scope 4X", color = {R=255, G=0, B=255, A=255} },
    
    medkit = { cat = "EspItem_Other", key = "EspItem_Ot_Medkit", name = "Bộ Y Tế (Medkit)", color = {R=0, G=200, B=255, A=255} },
    firstaid = { cat = "EspItem_Other", key = "EspItem_Ot_FirstAid", name = "Sơ Cứu (First Aid)", color = {R=0, G=200, B=255, A=255} }
}

_G.DX_OrderedKeywords = {
    "m249", "m24", "helmet3", "helmet_lvl3", "armor3", "armor_lvl3", "vest_level3", "bag3", "bag_lvl3", "backpack_lvl3",
    "mũ bảo hiểm (cấp 3)", "mũ (cấp 3)", "mũ cấp 3", "mũ 3", "helmet (lv. 3)", "helmet 3",
    "giáp quân sự (cấp 3)", "giáp (cấp 3)", "giáp cấp 3", "giáp 3", "vest (lv. 3)", "vest 3",
    "ba lô (cấp 3)", "ba lô cấp 3", "ba lo (cấp 3)", "balo (cấp 3)", "balo cấp 3", "balo 3", "backpack (lv. 3)", "backpack 3", "bag 3",
    "m416", "akm", "scar", "groza", "aug", "qbz", "m762", "g36c", "famas", "ace32", "honey",
    "kar98", "awm", "mosin", "win94", "amr",
    "sks", "slr", "mini", "mk14", "qbu", "mk12", "vss",
    "uzi", "ump", "vector", "tommy", "bizon", "mp5k", "p90",
    "s686", "s1897", "s12k", "dbs", "m1014",
    "dp28", "mg3",
    "p1911", "p92", "r1895", "deagle", "skorpion", "p18c",
    "pan", "sickle", "machete", "crowbar", "chảo", "liềm", "rựa", "xà beng",
    "scope_8x", "sight_8x", "scope_6x", "sight_6x", "scope_4x", "sight_4x", "8x", "6x", "4x",
    "medkit", "firstaid", "bộ y tế", "sơ cứu"
}

-- Bổ sung mapping theo ID số và từ khóa Tiếng Việt vào _G.DX_WeaponMap
pcall(function()
    local extraMappings = {
        [101008] = "m416", [101001] = "akm", [101003] = "scar", [101004] = "groza", [101005] = "aug", [101006] = "qbz",
        [101007] = "m762", [101009] = "g36c", [101010] = "famas", [101011] = "ace32", [101012] = "honey",
        [103001] = "kar98", [103002] = "m24", [103003] = "awm", [103010] = "mosin", [103004] = "win94", [103011] = "amr",
        [103005] = "sks", [103006] = "slr", [103007] = "mini", [103008] = "mk14", [103009] = "qbu", [103012] = "mk12", [103013] = "vss",
        [102001] = "uzi", [102002] = "ump", [102003] = "vector", [102004] = "tommy", [102005] = "bizon", [102007] = "mp5k", [102008] = "p90",
        [105001] = "s686", [105002] = "s1897", [105003] = "s12k", [105004] = "dbs", [105005] = "m1014",
        [104001] = "dp28", [104002] = "m249", [104003] = "mg3",
        [106001] = "p1911", [106002] = "p92", [106003] = "r1895", [106004] = "deagle", [106005] = "skorpion", [106006] = "p18c",
        [108001] = "pan", [108002] = "sickle", [108003] = "machete", [108004] = "crowbar",
        [501003] = "helmet3", [501004] = "helmet3", [501005] = "helmet3", [501006] = "helmet3",
        [502003] = "armor3", [502004] = "armor3", [502005] = "armor3", [502006] = "armor3",
        [503003] = "bag3", [503004] = "bag3", [503005] = "bag3", [503006] = "bag3",
        [201009] = "scope_8x", [201012] = "scope_6x", [201007] = "scope_4x",
        [601005] = "medkit", [601006] = "firstaid",
        
        ["mũ bảo hiểm (cấp 3)"] = "helmet3", ["mũ (cấp 3)"] = "helmet3", ["mũ cấp 3"] = "helmet3", ["mũ 3"] = "helmet3",
        ["giáp quân sự (cấp 3)"] = "armor3", ["giáp (cấp 3)"] = "armor3", ["giáp cấp 3"] = "armor3", ["giáp 3"] = "armor3",
        ["ba lô (cấp 3)"] = "bag3", ["ba lô cấp 3"] = "bag3", ["ba lo (cấp 3)"] = "bag3", ["balo (cấp 3)"] = "bag3", ["balo cấp 3"] = "bag3", ["balo 3"] = "bag3",
        ["8x"] = "scope_8x", ["6x"] = "scope_6x", ["4x"] = "scope_4x",
        ["bộ y tế"] = "medkit", ["sơ cứu"] = "firstaid",
        ["chảo"] = "pan", ["liềm"] = "sickle", ["rựa"] = "machete", ["xà beng"] = "crowbar"
    }
    for key, refKey in pairs(extraMappings) do
        _G.DX_WeaponMap[key] = _G.DX_WeaponMap[refKey]
    end
end)


local ConfigFileName = "Menu_Settings.txt"
_G.LastConfigSaveStr = ""

local defaultSettings = {
    ESP_HITMARK_1 = 0, ESP_HITMARK_2 = 0, WALLHACK = 0, WHITE_BODY = 0,
    ESP_WEAPON = 0, ESP_COUNT = 0, ESP_BOX = 0, EspLoai5 = 0,
    AIMBOT = 0, SPEED_AIMBOT = 0, FOV_AIMBOT = 0, THU_TAM = 0,
    NO_RECOIL_100 = 0, GIAM_RUNG_SCOPE = 0,

    -- Per-weapon recoil adjustment (0 = use global NO_RECOIL_100)
    REC_WEAPON_MASTER = 0, REC_W_M416 = 0, REC_W_AKM = 0, REC_W_SCAR = 0, REC_W_Groza = 0, REC_W_AUG = 0, REC_W_QBZ = 0, REC_W_M762 = 0, REC_W_G36C = 0, REC_W_FAMAS = 0, REC_W_ACE32 = 0, REC_W_Honey = 0,
    REC_W_SKS = 0, REC_W_SLR = 0, REC_W_Mini14 = 0, REC_W_Mk14 = 0, REC_W_QBU = 0, REC_W_Mk12 = 0, REC_W_VSS = 0,
    REC_W_UZI = 0, REC_W_UMP45 = 0, REC_W_Vector = 0, REC_W_Tommy = 0, REC_W_Bizon = 0, REC_W_MP5K = 0, REC_W_P90 = 0,
    REC_W_DP28 = 0, REC_W_M249 = 0, REC_W_MG3 = 0,
    -- Per-weapon scope shake adjustment (0 = use global GIAM_RUNG_SCOPE)
    REC_SS_W_M416 = 0, REC_SS_W_AKM = 0, REC_SS_W_SCAR = 0, REC_SS_W_Groza = 0, REC_SS_W_AUG = 0, REC_SS_W_QBZ = 0, REC_SS_W_M762 = 0, REC_SS_W_G36C = 0, REC_SS_W_FAMAS = 0, REC_SS_W_ACE32 = 0, REC_SS_W_Honey = 0,
    REC_SS_W_SKS = 0, REC_SS_W_SLR = 0, REC_SS_W_Mini14 = 0, REC_SS_W_Mk14 = 0, REC_SS_W_QBU = 0, REC_SS_W_Mk12 = 0, REC_SS_W_VSS = 0,
    REC_SS_W_UZI = 0, REC_SS_W_UMP45 = 0, REC_SS_W_Vector = 0, REC_SS_W_Tommy = 0, REC_SS_W_Bizon = 0, REC_SS_W_MP5K = 0, REC_SS_W_P90 = 0,
    REC_SS_W_DP28 = 0, REC_SS_W_M249 = 0, REC_SS_W_MG3 = 0,
    MAGIC_HEAD = 0, MAGIC_BODY = 0, MAGIC_LEGS = 0,
    MAGIC_DIST = 100,
    IpadView = 0,
    IpadViewFOV = 120,
    NOGRASS = 0, NOTREES = 0, NOWATER = 0, NOFOG = 0,
    BLACK_SKY = 0,
    FAKE_HWID = 1,  -- Luôn bật, không hiển thị trong menu
    GHOST_MODE = 0,
    NO_LANDING_LAG = 0,
    AUTO_BUNNYHOP = 0,
    THREAT_ESP = 0,

    THREAT_ESP_WARN_LINE = 1,
    THREAT_ESP_FLASH = 1,

-- Wall color (9 mau: 1=TRANG 2=DO 3=VANG 4=XANH LA 5=XANH NGOC 6=XANH DUONG 7=TIM 8=HONG 9=DEN)
    WALL_VISIBLE_COLOR = 3,       -- Mặc định Vàng (vị trí số 3)
    WALL_OCCLUDED_COLOR = 2,      -- Mặc định Đỏ (vị trí số 2)
    WALL_OCCLUDED_AI_COLOR = 7,   -- Mặc định Tím (vị trí số 7)
    WALLHACK_DIST = 350,          -- Mặc định 350m

    -- Bomb & Vehicle ESP Config
    EspBomMaster = 0,
    EspItemBom = 0,
    EspActiveBom = 0,
    EspVehicle = 0,
    EspVeh_Dacia = 1,
    EspVeh_UAZ = 1,
    EspVeh_Buggy = 1,
    EspVeh_Coupe = 1,
    EspVeh_Mirado = 1,
    EspVeh_Motor = 1,
    EspVeh_Other = 1,

    -- ESP Vật Phẩm
    EspItemMaster = 0,
    EspItem_Dist = 150,
    EspItem_AR = 0,
    EspItem_AR_M416 = 1, EspItem_AR_AKM = 1, EspItem_AR_SCAR = 1, EspItem_AR_Groza = 1, EspItem_AR_AUG = 1, EspItem_AR_QBZ = 1, EspItem_AR_M762 = 1, EspItem_AR_G36C = 1, EspItem_AR_FAMAS = 1, EspItem_AR_ACE32 = 1, EspItem_AR_Honey = 1,
    EspItem_SR = 0,
    EspItem_SR_Kar98 = 1, EspItem_SR_M24 = 1, EspItem_SR_AWM = 1, EspItem_SR_Mosin = 1, EspItem_SR_Win94 = 1, EspItem_SR_AMR = 1,
    EspItem_DMR = 0,
    EspItem_DMR_SKS = 1, EspItem_DMR_SLR = 1, EspItem_DMR_Mini14 = 1, EspItem_DMR_Mk14 = 1, EspItem_DMR_QBU = 1, EspItem_DMR_Mk12 = 1, EspItem_DMR_VSS = 1,
    EspItem_SMG = 0,
    EspItem_SMG_UZI = 1, EspItem_SMG_UMP45 = 1, EspItem_SMG_Vector = 1, EspItem_SMG_Tommy = 1, EspItem_SMG_Bizon = 1, EspItem_SMG_MP5K = 1, EspItem_SMG_P90 = 1,
    EspItem_SG = 0,
    EspItem_SG_S686 = 1, EspItem_SG_S1897 = 1, EspItem_SG_S12K = 1, EspItem_SG_DBS = 1, EspItem_SG_M1014 = 1,
    EspItem_LMG = 0,
    EspItem_LMG_DP28 = 1, EspItem_LMG_M249 = 1, EspItem_LMG_MG3 = 1,
    EspItem_Pistol = 0,
    EspItem_Pistol_P1911 = 1, EspItem_Pistol_P92 = 1, EspItem_Pistol_R1895 = 1, EspItem_Pistol_Deagle = 1, EspItem_Pistol_Skorpion = 1, EspItem_Pistol_P18C = 1,
    EspItem_Melee = 0,
    EspItem_Melee_Pan = 1, EspItem_Melee_Sickle = 1, EspItem_Melee_Machete = 1, EspItem_Melee_Crowbar = 1,
    EspItem_Other = 0,
    EspItem_Ot_Helmet3 = 1, EspItem_Ot_Vest3 = 1, EspItem_Ot_Bag3 = 1, EspItem_Ot_Scope8x = 1, EspItem_Ot_Scope6x = 1, EspItem_Ot_Scope4x = 1, EspItem_Ot_Medkit = 1, EspItem_Ot_FirstAid = 1,

    -- AimTouch settings integrated from Code 1
    AimTouchEnable = 0,
    AimTouchHipfire = 0,
    AimTouchHipIgKnock = 0,
    AimTouchHipIgBot = 0,
    AimTouchHipVisCheck = 0,
    AimTouchHipPrio = 1,
    AimTouchHipBone = 1,
    AimTouchHipCond = 1,
    AimTouchHipSpeed = 50,
    AimTouchHipFOV = 30,
    AimTouchHipDist = 250,

    AimTouchSG = 0,
    AimTouchSGAutoFire = 0,
    AimTouchSGIgKnock = 0,
    AimTouchSGIgBot = 0,
    AimTouchSGVisCheck = 0,
    AimTouchSGPrio = 1,
    AimTouchSGBone = 2,
    AimTouchSGCond = 1,
    AimTouchSGSpeed = 80,
    AimTouchSGFOV = 40,
    AimTouchSGDist = 30,

    AimTouchScopeAll = 0,
    AimTouchScopeIgKnock = 0,
    AimTouchScopeIgBot = 0,
    AimTouchScopeVisCheck = 0,
    AimTouchScopePrio = 1,
    AimTouchScopeBone = 1,
    AimTouchScopeCond = 1,
    AimTouchScopeSpeed = 40,
    AimTouchScopeFOV = 20,
    AimTouchScopeDist = 300,
    AimTouchScopePred = 50,
    AimTouchScopeRecoil = 0,

    AimTouchScopeSniper = 0,
    AimTouchSniperIgKnock = 0,
    AimTouchSniperIgBot = 0,
    AimTouchSniperVisCheck = 0,
    AimTouchSniperPrio = 1,
    AimTouchSniperBone = 1,
    AimTouchSniperCond = 2,
    AimTouchSniperSpeed = 30,
    AimTouchSniperFOV = 20,
    AimTouchSniperDist = 400,
    AimTouchSniperPred = 50,
}

_G.DX_Settings = _G.DX_Settings or {}
for k, v in pairs(defaultSettings) do
    if _G.DX_Settings[k] == nil then
        _G.DX_Settings[k] = v
    end
end

_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\n"
        for k, v in pairs(_G.DX_Settings) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "}"
        
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data

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

_G.LoadModSettings = function()
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
                    for k, v in pairs(savedData) do
                        _G.DX_Settings[k] = v
                    end
                    _G.EnvRequiresUpdate = true
                    _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                end
            end
        end
        _G.SaveModSettings() 
    end)
end

local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker") 
        if okTicker and ticker and ticker.AddTimerOnce then 
            ticker.AddTimerOnce(3.0, AutoSaveLoop) 
        end
    end)
end

if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
end

function _G.DX_GetVal(id)
    return _G.DX_Settings[id] or 0
end

-- =========================== PHẦN 27: MENU TAB TRONG CÀI ĐẶT ===========================
function _G.InitModMenuTab()
    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then LocUtil = require("client.common.LocUtil") end
    
    if LocUtil and not LocUtil._IsModMenuHooked then
        local old_get = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then return id end
            return old_get(id)
        end
        LocUtil._IsModMenuHooked = true
    end

    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    
    if not SettingPageDefine.ModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
        
        local function AddToggle(stack, key, text, expandHandle)
    local item = {
        Key = "ModMenu_" .. key,
        UI = AliasMap.Switcher,
        Text = text,
        GetFunc = function() return _G.DX_Settings[key] == 1 end,
        SetFunc = function(_, value)
            _G.DX_Settings[key] = value and 1 or 0
            _G.EnvRequiresUpdate = true
            _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
            return true
        end
    }
    if expandHandle then
        item.ExpandHandle = expandHandle
    end
    table.insert(stack, item)
end

local function AddSlider(stack, key, text, minVal, maxVal, expandHandle)
    local item = {
        Key = "ModMenu_" .. key,
        UI = AliasMap.Slider,
        Text = text,
        MinValue = minVal,
        MaxValue = maxVal,
        Min = minVal,
        Max = maxVal,
        GetFunc = function() return _G.DX_Settings[key] or minVal end,
        SetFunc = function(_, value)
            local val = math.floor(tonumber(value) or minVal)
            if val < minVal then val = minVal end
            if val > maxVal then val = maxVal end
            if _G.DX_Settings[key] ~= val then
                _G.DX_Settings[key] = val
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
            end
            return true
        end
    }
    if expandHandle then
        item.ExpandHandle = expandHandle
    end
    table.insert(stack, item)
end
        
        local currentUID = _G.DX_CachedUID or (type(GetHardwareDeviceID) == "function" and GetHardwareDeviceID()) or (type(GetDeviceUID) == "function" and GetDeviceUID()) or "UNKNOWN"
        local StackESP = { 
            { UI = AliasMap.Title, Text = "ESP" },
            { UI = AliasMap.Title, Text = "UID: " .. currentUID }
        }
table.insert(StackESP, {
    Key = "ModMenu_Wall_Ex",
    UI = AliasMap.TitleSwitcher,
    Text = "▶ WALLHACK (1 Trắng|2 Đỏ|3 Vàng|4 Xanh lá|5 Xanh Ngọc|6Xanh Dương|7 Tím|8 Hồng|9 Đen)",
    ExpandIndex = 0,
    GetFunc = function() return _G.DX_Settings.WALLHACK == 1 end,
    SetFunc = function(_, value)
        _G.DX_Settings.WALLHACK = value and 1 or 0
        _G.EnvRequiresUpdate = true
        _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
        return true
    end
})

-- Hàm reset cache màu
local function ResetWallColorCache()
    pcall(function()
        local gd = GameplayData
        local ac = gd.GetAllPlayerCharacters and gd.GetAllPlayerCharacters() or {}
    for _, ch in pairs(ac) do
        if ch then
            ch.WallhackApplied = false
            ch.LastAuraHash = nil
            ch.LastAuraMeshes = nil
        end
    end
    end)
    _G.EnvRequiresUpdate = true
    _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
end

-- Màu nhìn thấy (Slider 1-9)
table.insert(StackESP, {
    Key = "ModMenu_Wall_VisColor",
    UI = AliasMap.Slider or "Slider",
    Text = "   Màu nhìn thấy (1-9)",
    ExpandHandle = "ModMenu_Wall_Ex",
    MinValue = 1,
    MaxValue = 9,
    Min = 1,
    Max = 9,
    GetFunc = function() return _G.DX_Settings.WALL_VISIBLE_COLOR or 3 end,
    SetFunc = function(_, value)
        local v = math.floor(tonumber(value) or 3)
        _G.DX_Settings.WALL_VISIBLE_COLOR = math.max(1, math.min(9, v))
        ResetWallColorCache()
        return true
    end
})

-- Màu bị che - Người (Slider 1-9)
table.insert(StackESP, {
    Key = "ModMenu_Wall_OccColor",
    UI = AliasMap.Slider or "Slider",
    Text = "   Màu bị che - Người (1-9)",
    ExpandHandle = "ModMenu_Wall_Ex",
    MinValue = 1,
    MaxValue = 9,
    Min = 1,
    Max = 9,
    GetFunc = function() return _G.DX_Settings.WALL_OCCLUDED_COLOR or 2 end,
    SetFunc = function(_, value)
        local v = math.floor(tonumber(value) or 2)
        _G.DX_Settings.WALL_OCCLUDED_COLOR = math.max(1, math.min(9, v))
        ResetWallColorCache()
        return true
    end
})

-- Màu bị che - Bot/AI (Slider 1-9)
table.insert(StackESP, {
    Key = "ModMenu_Wall_AIColor",
    UI = AliasMap.Slider or "Slider",
    Text = "   Màu bị che - Bot/AI (1-9)",
    ExpandHandle = "ModMenu_Wall_Ex",
    MinValue = 1,
    MaxValue = 9,
    Min = 1,
    Max = 9,
    GetFunc = function() return _G.DX_Settings.WALL_OCCLUDED_AI_COLOR or 7 end,
    SetFunc = function(_, value)
        local v = math.floor(tonumber(value) or 7)
        _G.DX_Settings.WALL_OCCLUDED_AI_COLOR = math.max(1, math.min(9, v))
        ResetWallColorCache()
        return true
    end
})

-- Phạm vi nhuộm màu aura (Slider 350-500)
table.insert(StackESP, {
    Key = "ModMenu_Wall_Dist",
    UI = AliasMap.Slider or "Slider",
    Text = "   Phạm vi nhuộm màu (M)",
    ExpandHandle = "ModMenu_Wall_Ex",
    MinValue = 350,
    MaxValue = 500,
    Min = 350,
    Max = 500,
    GetFunc = function() return _G.DX_Settings.WALLHACK_DIST or 350 end,
    SetFunc = function(_, value)
        local v = math.floor(tonumber(value) or 350)
        _G.DX_Settings.WALLHACK_DIST = math.max(350, math.min(500, v))
        ResetWallColorCache()
        return true
    end
})
        AddToggle(StackESP, "WHITE_BODY", "NGƯỜI MÀU TRẮNG")
        AddToggle(StackESP, "ESP_WEAPON", "ESP ĐỘNG TÁC NHÂN VẬT")
        AddToggle(StackESP, "ESP_HITMARK_1", "ESP ĐỊNH VỊ")
        AddToggle(StackESP, "ESP_HITMARK_2", "ESP THANH MÁU")
        AddToggle(StackESP, "ESP_COUNT", "ĐẾM SỐ LƯỢNG ĐỊCH")
        -- ESP KHUNG BOX mapping to both ESP_BOX and EspLoai5
        table.insert(StackESP, {
            Key = "ModMenu_ESP5",
            UI = AliasMap.Switcher,
            Text = "ESP KHUNG BOX",
            GetFunc = function() return _G.DX_Settings.EspLoai5 == 1 end,
            SetFunc = function(_, value)
                local val = value and 1 or 0
                _G.DX_Settings.EspLoai5 = val
                _G.DX_Settings.ESP_BOX = val
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })

-- ESP HIỂM HỌA (Nút bình thường)
           AddToggle(StackESP, "THREAT_ESP", "ESP HIỂM HỌA (Cảnh báo địch ngắm)")

        -- Bomb Warning & Vehicle ESP Controls
        table.insert(StackESP, {
            Key = "ModMenu_EspBomMaster",
            UI = AliasMap.TitleSwitcher,
            Text = "▶ Cảnh Báo & Định Vị Bom",
            ExpandIndex = 0,
            GetFunc = function() return _G.DX_Settings.EspBomMaster == 1 end,
            SetFunc = function(_, value)
                _G.DX_Settings.EspBomMaster = value and 1 or 0
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })
        table.insert(StackESP, {
            Key = "ModMenu_EspItemBom",
            UI = AliasMap.Switcher,
            Text = "   Định Vị Vật Phẩm Bom Dưới Đất",
            ExpandHandle = "ModMenu_EspBomMaster",
            GetFunc = function() return _G.DX_Settings.EspItemBom == 1 end,
            SetFunc = function(_, value)
                _G.DX_Settings.EspItemBom = value and 1 or 0
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })
        table.insert(StackESP, {
            Key = "ModMenu_EspActiveBom",
            UI = AliasMap.Switcher,
            Text = "   Cảnh Báo Địch Cầm Trên Tay & Ném",
            ExpandHandle = "ModMenu_EspBomMaster",
            GetFunc = function() return _G.DX_Settings.EspActiveBom == 1 end,
            SetFunc = function(_, value)
                _G.DX_Settings.EspActiveBom = value and 1 or 0
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })

        table.insert(StackESP, {
            Key = "ModMenu_EspVehicle",
            UI = AliasMap.TitleSwitcher,
            Text = "▶ ESP Định Vị Xe (Mở Rộng)",
            ExpandIndex = 0,
            GetFunc = function() return _G.DX_Settings.EspVehicle == 1 end,
            SetFunc = function(_, value)
                _G.DX_Settings.EspVehicle = value and 1 or 0
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })
        
        local vehTypes = {
            { key = "EspVeh_Dacia", text = "   Hiện Xe Con (Dacia)" },
            { key = "EspVeh_UAZ", text = "   Hiện Xe Jeep (UAZ)" },
            { key = "EspVeh_Buggy", text = "   Hiện Xe Buggy" },
            { key = "EspVeh_Coupe", text = "   Hiện Xe Thể Thao (Coupe RB)" },
            { key = "EspVeh_Mirado", text = "   Hiện Xe Mirado" },
            { key = "EspVeh_Motor", text = "   Hiện Xe Máy (Motor/Scooter)" },
            { key = "EspVeh_Other", text = "   Hiện Xe Khác (Thuyền/BRDM...)" }
        }
        for _, vt in ipairs(vehTypes) do
            table.insert(StackESP, {
                Key = "ModMenu_" .. vt.key,
                UI = AliasMap.Switcher,
                Text = vt.text,
                ExpandHandle = "ModMenu_EspVehicle",
                GetFunc = function() return _G.DX_Settings[vt.key] == 1 end,
                SetFunc = function(_, value)
                    _G.DX_Settings[vt.key] = value and 1 or 0
                    _G.EnvRequiresUpdate = true
                    _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                    return true
                end
            })
        end

        local StackItemESP = { { UI = AliasMap.Title, Text = "ESP VẬT PHẨM" } }
        table.insert(StackItemESP, {
            Key = "ModMenu_EspItemMaster",
            UI = AliasMap.TitleSwitcher,
            Text = "▶ BẬT/TẮT TOÀN BỘ ESP VẬT PHẨM",
            ExpandIndex = 0,
            GetFunc = function() return _G.DX_Settings.EspItemMaster == 1 end,
            SetFunc = function(_, value)
                _G.DX_Settings.EspItemMaster = value and 1 or 0
                _G.EnvRequiresUpdate = true
                return true
            end
        })
        table.insert(StackItemESP, {
            Key = "ModMenu_EspItem_Dist",
            UI = AliasMap.Slider or "Slider",
            Text = "   Bán Kính Quét Vật Phẩm (m)",
            ExpandHandle = "ModMenu_EspItemMaster",
            MinValue = 1,
            MaxValue = 500,
            Min = 1,
            Max = 500,
            GetFunc = function() return _G.DX_Settings.EspItem_Dist or 150 end,
            SetFunc = function(_, value)
                local v = math.floor(tonumber(value) or 150)
                _G.DX_Settings.EspItem_Dist = math.max(1, math.min(500, v))
                return true
            end
        })
        
        local itemCategories = {
            {
                key = "EspItem_AR", text = "   ▶ Súng trường tấn công",
                weapons = {
                    { key = "EspItem_AR_M416", text = "      Hiện M416" },
                    { key = "EspItem_AR_AKM", text = "      Hiện AKM" },
                    { key = "EspItem_AR_SCAR", text = "      Hiện SCAR-L" },
                    { key = "EspItem_AR_Groza", text = "      Hiện Groza" },
                    { key = "EspItem_AR_AUG", text = "      Hiện AUG" },
                    { key = "EspItem_AR_QBZ", text = "      Hiện QBZ" },
                    { key = "EspItem_AR_M762", text = "      Hiện M762" },
                    { key = "EspItem_AR_G36C", text = "      Hiện G36C" },
                    { key = "EspItem_AR_FAMAS", text = "      Hiện FAMAS" },
                    { key = "EspItem_AR_ACE32", text = "      Hiện ACE32" },
                    { key = "EspItem_AR_Honey", text = "      Hiện Honey Badger" }
                }
            },
            {
                key = "EspItem_SR", text = "   ▶ Súng bắn tỉa (SR)",
                weapons = {
                    { key = "EspItem_SR_Kar98", text = "      Hiện Kar98k" },
                    { key = "EspItem_SR_M24", text = "      Hiện M24" },
                    { key = "EspItem_SR_AWM", text = "      Hiện AWM" },
                    { key = "EspItem_SR_Mosin", text = "      Hiện Mosin" },
                    { key = "EspItem_SR_Win94", text = "      Hiện Win94" },
                    { key = "EspItem_SR_AMR", text = "      Hiện AMR" }
                }
            },
            {
                key = "EspItem_DMR", text = "   ▶ Súng bắn tỉa bán tự động (DMR)",
                weapons = {
                    { key = "EspItem_DMR_SKS", text = "      Hiện SKS" },
                    { key = "EspItem_DMR_SLR", text = "      Hiện SLR" },
                    { key = "EspItem_DMR_Mini14", text = "      Hiện Mini14" },
                    { key = "EspItem_DMR_Mk14", text = "      Hiện Mk14" },
                    { key = "EspItem_DMR_QBU", text = "      Hiện QBU" },
                    { key = "EspItem_DMR_Mk12", text = "      Hiện Mk12" },
                    { key = "EspItem_DMR_VSS", text = "      Hiện VSS" }
                }
            },
            {
                key = "EspItem_SMG", text = "   ▶ Súng tiểu liên (SMG)",
                weapons = {
                    { key = "EspItem_SMG_UZI", text = "      Hiện UZI" },
                    { key = "EspItem_SMG_UMP45", text = "      Hiện UMP45" },
                    { key = "EspItem_SMG_Vector", text = "      Hiện Vector" },
                    { key = "EspItem_SMG_Tommy", text = "      Hiện Tommy Gun" },
                    { key = "EspItem_SMG_Bizon", text = "      Hiện PP-19 Bizon" },
                    { key = "EspItem_SMG_MP5K", text = "      Hiện MP5K" },
                    { key = "EspItem_SMG_P90", text = "      Hiện P90" }
                }
            },
            {
                key = "EspItem_SG", text = "   ▶ Súng săn (Shotgun)",
                weapons = {
                    { key = "EspItem_SG_S686", text = "      Hiện S686" },
                    { key = "EspItem_SG_S1897", text = "      Hiện S1897" },
                    { key = "EspItem_SG_S12K", text = "      Hiện S12K" },
                    { key = "EspItem_SG_DBS", text = "      Hiện DBS" },
                    { key = "EspItem_SG_M1014", text = "      Hiện M1014" }
                }
            },
            {
                key = "EspItem_LMG", text = "   ▶ Súng máy hạng nhẹ (LMG)",
                weapons = {
                    { key = "EspItem_LMG_DP28", text = "      Hiện DP-28" },
                    { key = "EspItem_LMG_M249", text = "      Hiện M249" },
                    { key = "EspItem_LMG_MG3", text = "      Hiện MG3" }
                }
            },
            {
                key = "EspItem_Pistol", text = "   ▶ Súng lục",
                weapons = {
                    { key = "EspItem_Pistol_P1911", text = "      Hiện P1911" },
                    { key = "EspItem_Pistol_P92", text = "      Hiện P92" },
                    { key = "EspItem_Pistol_R1895", text = "      Hiện R1895" },
                    { key = "EspItem_Pistol_Deagle", text = "      Hiện Desert Eagle" },
                    { key = "EspItem_Pistol_Skorpion", text = "      Hiện Skorpion" },
                    { key = "EspItem_Pistol_P18C", text = "      Hiện P18C" }
                }
            },
            {
                key = "EspItem_Melee", text = "   ▶ Vũ khí cận chiến",
                weapons = {
                    { key = "EspItem_Melee_Pan", text = "      Hiện Chảo (Pan)" },
                    { key = "EspItem_Melee_Sickle", text = "      Hiện Liềm (Sickle)" },
                    { key = "EspItem_Melee_Machete", text = "      Hiện Rựa (Machete)" },
                    { key = "EspItem_Melee_Crowbar", text = "      Hiện Xà beng (Crowbar)" }
                }
            },
            {
                key = "EspItem_Other", text = "   ▶ Vật phẩm khác",
                weapons = {
                    { key = "EspItem_Ot_Helmet3", text = "      Hiện Mũ Cấp 3" },
                    { key = "EspItem_Ot_Vest3", text = "      Hiện Giáp Cấp 3" },
                    { key = "EspItem_Ot_Bag3", text = "      Hiện Balo Cấp 3" },
                    { key = "EspItem_Ot_Scope8x", text = "      Hiện Scope 8x" },
                    { key = "EspItem_Ot_Scope6x", text = "      Hiện Scope 6x" },
                    { key = "EspItem_Ot_Scope4x", text = "      Hiện Scope 4x" },
                    { key = "EspItem_Ot_Medkit", text = "      Hiện Medkit" },
                    { key = "EspItem_Ot_FirstAid", text = "      Hiện First Aid" }
                }
            }
        }
        
        for _, cat in ipairs(itemCategories) do
            table.insert(StackItemESP, {
                Key = "ModMenu_" .. cat.key,
                UI = AliasMap.TitleSwitcher,
                Text = cat.text,
                ExpandHandle = "ModMenu_EspItemMaster",
                ExpandIndex = 0,
                GetFunc = function() return _G.DX_Settings[cat.key] == 1 end,
                SetFunc = function(_, value)
                    _G.DX_Settings[cat.key] = value and 1 or 0
                    _G.EnvRequiresUpdate = true
                    return true
                end
            })
            for _, wp in ipairs(cat.weapons) do
                table.insert(StackItemESP, {
                    Key = "ModMenu_" .. wp.key,
                    UI = AliasMap.Switcher,
                    Text = wp.text,
                    ExpandHandle = "ModMenu_" .. cat.key,
                    GetFunc = function() return _G.DX_Settings[wp.key] == 1 end,
                    SetFunc = function(_, value)
                        _G.DX_Settings[wp.key] = value and 1 or 0
                        _G.EnvRequiresUpdate = true
                        return true
                    end
                })
            end
        end

        local StackAimbot = { { UI = AliasMap.Title, Text = "PHẦN 1: VŨ KHÍ" } }
        AddSlider(StackAimbot, "THU_TAM", "THU NHỎ TÂM BẮN", 0, 100)
        AddSlider(StackAimbot, "NO_RECOIL_100", "GIẢM GIẬT (0-50%)", 0, 50)
        AddSlider(StackAimbot, "GIAM_RUNG_SCOPE", "GIẢM RUNG SCOPE", 0, 100)



        -- =========================================================================================
        -- [MỚI] TÍCH HỢP TOÀN BỘ GIAO DIỆN VÀ LOGIC TAB 3 CỦA CODE 2 SANG CODE 1 (AIMBOT ROYAL & CUSTOM)
        -- =========================================================================================
        local StackAimbotV2 = {
            { Key = "ModMenu_AT_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ Bật Aimbot Roy & Custom", ExpandIndex = 0, GetFunc = function() return _G.DX_Settings.AimTouchEnable == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchEnable = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            
            -- HIPFIRE (TÂM TRẮNG)
            { Key = "ModMenu_AT_Hip_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Aimbot Tâm Trắng", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.DX_Settings.AimTouchHipfire == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchHipfire = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_Hip_IgKnock", UI = AliasMap.Switcher, Text = "      Bỏ Qua Địch Knock", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.DX_Settings.AimTouchHipIgKnock == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchHipIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Hip_IgBot", UI = AliasMap.Switcher, Text = "      Bỏ Qua Bot", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.DX_Settings.AimTouchHipIgBot == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchHipIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Hip_Vis", UI = AliasMap.Switcher, Text = "      Check Tường (VisCheck)", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.DX_Settings.AimTouchHipVisCheck == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchHipVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Hip_Prio", UI = AliasMap.Slider, Text = "      Ưu Tiên (1:Tâm 2:Gần 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.DX_Settings.AimTouchHipPrio or 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchHipPrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Hip_Bone", UI = AliasMap.Slider, Text = "      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.DX_Settings.AimTouchHipBone or 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchHipBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Hip_Cond", UI = AliasMap.Slider, Text = "      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.DX_Settings.AimTouchHipCond or 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchHipCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Hip_Spd", UI = AliasMap.Slider, Text = "      Độ Mượt / Tốc Độ (1-100)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchHipSpeed or 50 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchHipSpeed = v return true end },
            { Key = "ModMenu_AT_Hip_FOV", UI = AliasMap.Slider, Text = "      Vòng FOV (1-100)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchHipFOV or 30 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchHipFOV = v return true end },
            { Key = "ModMenu_AT_Hip_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-500m)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return _G.DX_Settings.AimTouchHipDist or 250 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchHipDist = v return true end },

            -- AIMBOT SHOTGUN
            { Key = "ModMenu_AT_SG_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Aimbot Shotgun (Chỉ nhận Shotgun)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.DX_Settings.AimTouchSG == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSG = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_SG_AutoFire", UI = AliasMap.Switcher, Text = "      Tự Động Bắn lúc tự động bắn chịu khó bấm bắn nhận dame và auto bắn sẽ không lỗi dame", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.DX_Settings.AimTouchSGAutoFire == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSGAutoFire = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_IgKnock", UI = AliasMap.Switcher, Text = "      Bỏ Qua Địch Knock", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.DX_Settings.AimTouchSGIgKnock == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSGIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_IgBot", UI = AliasMap.Switcher, Text = "      Bỏ Qua Bot", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.DX_Settings.AimTouchSGIgBot == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSGIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_Vis", UI = AliasMap.Switcher, Text = "      Check Tường (VisCheck)", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.DX_Settings.AimTouchSGVisCheck == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSGVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_Prio", UI = AliasMap.Slider, Text = "      Ưu Tiên (1:Tâm 2:Gần 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.DX_Settings.AimTouchSGPrio or 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSGPrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_SG_Bone", UI = AliasMap.Slider, Text = "      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.DX_Settings.AimTouchSGBone or 2 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSGBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_SG_Cond", UI = AliasMap.Slider, Text = "      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.DX_Settings.AimTouchSGCond or 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSGCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_SG_Spd", UI = AliasMap.Slider, Text = "      Độ Mượt / Tốc Độ (1-100)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchSGSpeed or 80 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSGSpeed = v return true end },
            { Key = "ModMenu_AT_SG_FOV", UI = AliasMap.Slider, Text = "      Vòng FOV (1-100)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchSGFOV or 40 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSGFOV = v return true end },
            { Key = "ModMenu_AT_SG_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-100m)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchSGDist or 30 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSGDist = v return true end },
            
            -- SCOPE ALL (SÚNG THƯỜNG KHI MỞ SCOPE)
            { Key = "ModMenu_AT_ScopeAll_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Aimbot Mở Scope", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.DX_Settings.AimTouchScopeAll == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeAll = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_ScopeAll_IgKnock", UI = AliasMap.Switcher, Text = "      Bỏ Qua Địch Knock", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.DX_Settings.AimTouchScopeIgKnock == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_ScopeAll_IgBot", UI = AliasMap.Switcher, Text = "      Bỏ Qua Bot", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.DX_Settings.AimTouchScopeIgBot == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_ScopeAll_Vis", UI = AliasMap.Switcher, Text = "      Check Tường (VisCheck)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.DX_Settings.AimTouchScopeVisCheck == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_ScopeAll_Prio", UI = AliasMap.Slider, Text = "      Ưu Tiên (1:Tâm 2:Gần 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.DX_Settings.AimTouchScopePrio or 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopePrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_ScopeAll_Bone", UI = AliasMap.Slider, Text = "      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.DX_Settings.AimTouchScopeBone or 2 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_ScopeAll_Cond", UI = AliasMap.Slider, Text = "      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.DX_Settings.AimTouchScopeCond or 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_ScopeAll_Spd", UI = AliasMap.Slider, Text = "      Độ Mượt / Tốc Độ (1-100)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchScopeSpeed or 40 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeSpeed = v return true end },
            { Key = "ModMenu_AT_ScopeAll_FOV", UI = AliasMap.Slider, Text = "      Vòng FOV (1-100)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchScopeFOV or 20 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeFOV = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-500m)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return _G.DX_Settings.AimTouchScopeDist or 300 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeDist = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Pred", UI = AliasMap.Slider, Text = "      Dự Đoán Hướng Chạy", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchScopePred or 0 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopePred = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Recoil", UI = AliasMap.Slider, Text = "      Bù Giật Tự Động Ghìm Tâm Khi Aim ( để 1% nếu không bật giảm )", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 50, min = 0, max = 50, GetFunc = function() return _G.DX_Settings.AimTouchScopeRecoil or 0 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeRecoil = v return true end },

            -- SCOPE SNIPER (SÚNG NGẮM/TỈA)
            { Key = "ModMenu_AT_Sniper_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Aimbot Mở Scope (Súng Ngắm/Tỉa)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.DX_Settings.AimTouchScopeSniper == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchScopeSniper = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_Sniper_IgKnock", UI = AliasMap.Switcher, Text = "      Bỏ Qua Địch Knock", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.DX_Settings.AimTouchSniperIgKnock == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSniperIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Sniper_IgBot", UI = AliasMap.Switcher, Text = "      Bỏ Qua Bot", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.DX_Settings.AimTouchSniperIgBot == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSniperIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Sniper_Vis", UI = AliasMap.Switcher, Text = "      Check Tường (VisCheck)", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.DX_Settings.AimTouchSniperVisCheck == 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSniperVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Sniper_Prio", UI = AliasMap.Slider, Text = "      Ưu Tiên (1:Tâm 2:Gần 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.DX_Settings.AimTouchSniperPrio or 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSniperPrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Sniper_Bone", UI = AliasMap.Slider, Text = "      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.DX_Settings.AimTouchSniperBone or 1 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSniperBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Sniper_Cond", UI = AliasMap.Slider, Text = "      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.DX_Settings.AimTouchSniperCond or 2 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSniperCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Sniper_Spd", UI = AliasMap.Slider, Text = "      Độ Mượt / Tốc Độ (1-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchSniperSpeed or 30 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSniperSpeed = v return true end },
            { Key = "ModMenu_AT_Sniper_FOV", UI = AliasMap.Slider, Text = "      Vòng FOV (1-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchSniperFOV or 20 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSniperFOV = v return true end },
            { Key = "ModMenu_AT_Sniper_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-500m)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return _G.DX_Settings.AimTouchSniperDist or 400 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSniperDist = v return true end },
            { Key = "ModMenu_AT_Sniper_Pred", UI = AliasMap.Slider, Text = "      Dự Đoán Hướng Chạy (0-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.DX_Settings.AimTouchSniperPred or 0 end, SetFunc = function(_, v) _G.DX_Settings.AimTouchSniperPred = v return true end }
        }

        local StackMagic = { { UI = AliasMap.Title, Text = "MAGIC BULLET" } }
        AddSlider(StackMagic, "MAGIC_HEAD", "MAGIC ĐẦU", 0, 300)
        AddSlider(StackMagic, "MAGIC_BODY", "MAGIC THÂN", 0, 300)
        AddSlider(StackMagic, "MAGIC_LEGS", "MAGIC CHÂN", 0, 300)

        local StackEnv = { { UI = AliasMap.Title, Text = "MÔI TRƯỜNG & GÓC NHÌN" } }
        -- FakeHWID đã chạy nền tự động, không cần nút menu
        table.insert(StackEnv, {
            Key = "ModMenu_Ipad_Ex",
            UI = AliasMap.TitleSwitcher,
            Text = "▶ Ipad View",
            ExpandIndex = 0,
            GetFunc = function() return _G.DX_Settings.IpadView == 1 end,
            SetFunc = function(_, value)
                _G.DX_Settings.IpadView = value and 1 or 0
                _G.EnvRequiresUpdate = true
                return true
            end
        })
        table.insert(StackEnv, {
            Key = "ModMenu_Ipad_FOV",
            UI = AliasMap.Slider,
            Text = "   Góc Nhìn FOV",
            ExpandHandle = "ModMenu_Ipad_Ex",
            MinValue = 1,
            MaxValue = 100,
            Min = 1,
            Max = 100,
            GetFunc = function() return (_G.DX_Settings.IpadViewFOV or 120) - 90 end,
            SetFunc = function(_, value)
                _G.DX_Settings.IpadViewFOV = 90 + math.floor(tonumber(value) or 30)
                _G.EnvRequiresUpdate = true
                return true
            end
        })
        AddToggle(StackEnv, "NOGRASS", "XÓA CỎ")
        AddToggle(StackEnv, "NOTREES", "XÓA CÂY")
        AddToggle(StackEnv, "NOWATER", "XÓA NƯỚC")
        AddToggle(StackEnv, "NOFOG", "XÓA SƯƠNG MÙ")
        AddToggle(StackEnv, "BLACK_SKY", "TRỜI TỐI")
        AddToggle(StackEnv, "GHOST_MODE", "👻 GHOST MODE (Tự động tắt khi bị quét)")
        AddToggle(StackEnv, "NO_LANDING_LAG", "🏃 CHỐNG KHỰNG KHI RƠI")
        AddToggle(StackEnv, "AUTO_BUNNYHOP", "🐰 BUNNY HOP (Nhảy liên tục)")
        
        SettingPageDefine.ModMenu = {
            Key = "ModMenu", 
            loc = "DX-MODS", 
            text = "DX-MODS",
            Text = "DX-MODS",
            title = "DX-MODS",
            Title = "DX-MODS",
            UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "ModMenu_Cat1", loc = "ESP", text = "ESP", Text = "ESP", title = "ESP", Title = "ESP", Stack = StackESP },
                { Key = "ModMenu_Cat6", loc = "ESP VẬT PHẨM", text = "ESP VẬT PHẨM", Text = "ESP VẬT PHẨM", title = "ESP VẬT PHẨM", Title = "ESP VẬT PHẨM", Stack = StackItemESP },
                { Key = "ModMenu_Cat2", loc = "VŨ KHÍ", text = "VŨ KHÍ", Text = "VŨ KHÍ", title = "VŨ KHÍ", Title = "VŨ KHÍ", Stack = StackAimbot },
                { Key = "ModMenu_Cat5", loc = "AIMTOUCH - CUSTOM", text = "AIMTOUCH - CUSTOM", Text = "AIMTOUCH - CUSTOM", title = "AIMTOUCH - CUSTOM", Title = "AIMTOUCH - CUSTOM", Stack = StackAimbotV2 },
                { Key = "ModMenu_Cat3", loc = "MAGIC BULLET", text = "MAGIC BULLET", Text = "MAGIC BULLET", title = "MAGIC BULLET", Title = "MAGIC BULLET", Stack = StackMagic },
                { Key = "ModMenu_Cat4", loc = "GÓC NHÌN & MÔI TRƯỜNG", text = "GÓC NHÌN & MÔI TRƯỜNG", Text = "GÓC NHÌN & MÔI TRƯỜNG", title = "GÓC NHÌN & MÔI TRƯỜNG", Title = "GÓC NHÌN & MÔI TRƯỜNG", Stack = StackEnv },
            }
        }
        table.insert(SettingCatalog, 1, SettingPageDefine.ModMenu)
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...)
            if config and config.keyName and string.find(string.lower(config.keyName), "setting_main") then
                local catalog = args[1]
                if type(catalog) == "table" then
                    local hasModMenu = false
                    local newCatalog = {}
                    for _, page in ipairs(catalog) do
                        table.insert(newCatalog, page)
                        if type(page) == "table" and page.Key == "ModMenu" then hasModMenu = true end
                    end
                    if not hasModMenu then
                        table.insert(newCatalog, 1, SettingPageDefine.ModMenu)
                        args[1] = newCatalog
                    end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
end

-- =========================== PHẦN 28: AURA DYEING FUNCTIONS ===========================
local slua_isValid = slua and slua.isValid
local string_lower = string.lower
local string_find = string.find
local os_clock = os.clock
local math_abs = math.abs
local math_random = math.random
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_max = math.max

local function GetRecoilWeaponKey(weaponName)
    if not weaponName or weaponName == "" then return nil end
    local n = string.lower(weaponName)
    if n:find("m416") then return "REC_W_M416"
    elseif n:find("akm") and not n:find("ace") then return "REC_W_AKM"
    elseif n:find("scar") then return "REC_W_SCAR"
    elseif n:find("groza") then return "REC_W_Groza"
    elseif n:find("aug") then return "REC_W_AUG"
    elseif n:find("qbz") then return "REC_W_QBZ"
    elseif n:find("m762") then return "REC_W_M762"
    elseif n:find("g36") then return "REC_W_G36C"
    elseif n:find("famas") then return "REC_W_FAMAS"
    elseif n:find("ace32") then return "REC_W_ACE32"
    elseif n:find("honey") then return "REC_W_Honey"
    elseif n:find("sks") then return "REC_W_SKS"
    elseif n:find("slr") then return "REC_W_SLR"
    elseif n:find("mini") then return "REC_W_Mini14"
    elseif n:find("mk14") then return "REC_W_Mk14"
    elseif n:find("qbu") then return "REC_W_QBU"
    elseif n:find("mk12") then return "REC_W_Mk12"
    elseif n:find("vss") then return "REC_W_VSS"
    elseif n:find("uzi") then return "REC_W_UZI"
    elseif n:find("ump") then return "REC_W_UMP45"
    elseif n:find("vector") then return "REC_W_Vector"
    elseif n:find("tommy") then return "REC_W_Tommy"
    elseif n:find("bizon") then return "REC_W_Bizon"
    elseif n:find("mp5") then return "REC_W_MP5K"
    elseif n:find("p90") then return "REC_W_P90"
    elseif n:find("dp28") then return "REC_W_DP28"
    elseif n:find("m249") then return "REC_W_M249"
    elseif n:find("mg3") then return "REC_W_MG3"
    end
    return nil
end

local function GetScopeWeaponKey(weaponName)
    if not weaponName or weaponName == "" then return nil end
    local n = string.lower(weaponName)
    if n:find("m416") then return "REC_SS_W_M416"
    elseif n:find("akm") and not n:find("ace") then return "REC_SS_W_AKM"
    elseif n:find("scar") then return "REC_SS_W_SCAR"
    elseif n:find("groza") then return "REC_SS_W_Groza"
    elseif n:find("aug") then return "REC_SS_W_AUG"
    elseif n:find("qbz") then return "REC_SS_W_QBZ"
    elseif n:find("m762") then return "REC_SS_W_M762"
    elseif n:find("g36") then return "REC_SS_W_G36C"
    elseif n:find("famas") then return "REC_SS_W_FAMAS"
    elseif n:find("ace32") then return "REC_SS_W_ACE32"
    elseif n:find("honey") then return "REC_SS_W_Honey"
    elseif n:find("sks") then return "REC_SS_W_SKS"
    elseif n:find("slr") then return "REC_SS_W_SLR"
    elseif n:find("mini") then return "REC_SS_W_Mini14"
    elseif n:find("mk14") then return "REC_SS_W_Mk14"
    elseif n:find("qbu") then return "REC_SS_W_QBU"
    elseif n:find("mk12") then return "REC_SS_W_Mk12"
    elseif n:find("vss") then return "REC_SS_W_VSS"
    elseif n:find("uzi") then return "REC_SS_W_UZI"
    elseif n:find("ump") then return "REC_SS_W_UMP45"
    elseif n:find("vector") then return "REC_SS_W_Vector"
    elseif n:find("tommy") then return "REC_SS_W_Tommy"
    elseif n:find("bizon") then return "REC_SS_W_Bizon"
    elseif n:find("mp5") then return "REC_SS_W_MP5K"
    elseif n:find("p90") then return "REC_SS_W_P90"
    elseif n:find("dp28") then return "REC_SS_W_DP28"
    elseif n:find("m249") then return "REC_SS_W_M249"
    elseif n:find("mg3") then return "REC_SS_W_MG3"
    end
    return nil
end

local FVecZero = FVector(0,0,0)
local COLOR_CYAN    = {R=0, G=255, B=255, A=255}
local COLOR_YELLOW  = {R=255, G=255, B=0, A=255}
local COLOR_RED     = {R=255, G=0, B=0, A=255}
local COLOR_GREEN   = {R=0, G=255, B=0, A=255}

local function AuraColor(r, g, b, a)
    if FLinearColor then return FLinearColor(r, g, b, a) end
    return {R=r, G=g, B=b, A=a, r=r, g=g, b=b, a=a}
end

-- === BANG MAU WALL (9 MAU) - DINH DANG HDR (R, G, B, A) ===
-- Các giá trị RGB đã được nhân với hệ số phát sáng 3.5 để tạo hiệu ứng Glow/Bloom
local WALL_COLOR_PRESETS = {
    [1] = {3.5, 3.5, 3.5, 1.0},  -- Trắng phát sáng   (Emissive White)
    [2] = {3.5, 0.0, 0.0, 1.0},  -- Đỏ phát sáng     (Emissive Red)
    [3] = {3.5, 3.15, 0.0, 1.0}, -- Vàng phát sáng   (Emissive Yellow)
    [4] = {0.0, 3.5, 0.0, 1.0},  -- Xanh Lá phát sáng(Emissive Green)
    [5] = {0.0, 3.5, 3.15, 1.0}, -- Xanh Ngọc phát sáng (Emissive Cyan)
    [6] = {0.0, 0.0, 3.5, 1.0},  -- Xanh Dương phát sáng (Emissive Blue)
    [7] = {0.829, 0.229, 3.829, 1.0}, -- Tím phát sáng    (Emissive Purple)
    [8] = {3.5, 0.0, 2.1, 1.0},  -- Hồng phát sáng   (Emissive Pink)
    [9] = {0.0, 0.0, 0.0, 1.0},  -- Đen (Không phát sáng vì các giá trị gốc bằng 0)
}
local function GetWallColorByIndex(idx)
    local p = WALL_COLOR_PRESETS[idx] or WALL_COLOR_PRESETS[3]
    return AuraColor(p[1], p[2], p[3], 1.0)
end
local function GetCurrentWallVisibleColor()
    return GetWallColorByIndex((_G.DX_Settings and _G.DX_Settings.WALL_VISIBLE_COLOR) or 3)
end
local function GetCurrentWallOccludedColor(isAI)
    if isAI then
        return GetWallColorByIndex((_G.DX_Settings and _G.DX_Settings.WALL_OCCLUDED_AI_COLOR) or 7)
    else
        return GetWallColorByIndex((_G.DX_Settings and _G.DX_Settings.WALL_OCCLUDED_COLOR) or 2)
    end
end

local COLOR_AURA_VISIBLE = AuraColor(10.0, 10.0, 0.0, 1.0)
local COLOR_AURA_PLAYER  = AuraColor(10.0, 0.0, 0.0, 1.0)
local COLOR_AURA_AI      = AuraColor(0.829, 0.229, 3.829, 1.0)

local function ApplyAuraToMeshComponent(mesh, visibleColor, occludedColor)
    if not mesh then return end
    if slua_isValid and not slua_isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visibleColor)
        mesh:SetOccludedDyeingColor(occludedColor)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        mesh:SetDrawHighlight(true)
        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

local function ResetMeshAuraComponent(mesh)
    if not mesh then return end
    if slua_isValid and not slua_isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(false)
        mesh:SetDrawHighlight(false)
        mesh:SetRenderCustomDepth(false)
        mesh:SetCustomDepthStencilValue(0)
    end)
end

local function Valid(obj)
    if not obj then return false end
    if slua and type(slua.isValid) == "function" then
        return slua.isValid(obj)
    end
    if type(slua_isValid) == "function" then
        return slua_isValid(obj)
    end
    return true
end

local function CheckIsAI(pawn)
    if not Valid(pawn) then return false end
    if pawn.DX_IsAICached ~= nil then return pawn.DX_IsAICached end
    
    local isAI = false
    local hasChecked = false
    
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then 
            isAI = true 
            hasChecked = true
        elseif type(pawn.IsBot) == "function" and pawn:IsBot() then
            isAI = true
            hasChecked = true
        elseif pawn.IsBot == true then
            isAI = true
            hasChecked = true
        end
        
        if not isAI and Game and type(Game.IsAI) == "function" and Game:IsAI(pawn) then
            isAI = true
            hasChecked = true
        end
        
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then
                isAI = true
            elseif type(pState.IsBot) == "function" and pState:IsBot() then
                isAI = true
            end
        end
        
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" then
                if name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_") or name:find("训练机器人") or name:find("PlayerBot") then
                    isAI = true
                end
                hasChecked = true
            end
        end
    end)
    
    if hasChecked then
        pawn.DX_IsAICached = isAI
    end
    
    return isAI
end


local function GetActorBoneWorldPos(actor, boneName, boneIdx)
    if not slua_isValid(actor) then return nil end
    local mesh = actor.Mesh
    local pos = nil
    
    if slua_isValid(mesh) then
        local getSocketLocation = mesh.GetSocketLocation
        if getSocketLocation then
            pos = getSocketLocation(mesh, boneName)
        end
        if (not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0)) then
            local getBonePosition = mesh.GetBonePosition
            if getBonePosition then
                pos = getBonePosition(mesh, boneName)
            end
        end
    end
    
    if (not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0)) then
        local getBonePos = actor.GetBonePos
        if getBonePos then
            pos = getBonePos(actor, boneName, {X=0, Y=0, Z=0})
        else
            local getSocketLocation = actor.GetSocketLocation
            if getSocketLocation then
                pos = getSocketLocation(actor, boneName)
            end
        end
    end
    
    if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
        local k2_GetActorLocation = actor.K2_GetActorLocation
        if k2_GetActorLocation then
            pos = k2_GetActorLocation(actor)
            if pos then
                local heightOffset = 0
                local isCrouching = actor.bIsCrouched or actor.bIsCrouching
                if not isCrouching then
                    local isCrouchingFunc = actor.IsCrouching
                    if isCrouchingFunc then isCrouching = isCrouchingFunc(actor) end
                end
                
                local isProning = actor.bIsProne or actor.bIsProning
                if not isProning then
                    local isProningFunc = actor.IsProning
                    if isProningFunc then isProning = isProningFunc(actor) end
                end
                
                if boneIdx == 1 then
                    heightOffset = isProning and 15 or (isCrouching and 45 or 75)
                elseif boneIdx == 2 then
                    heightOffset = isProning and 10 or (isCrouching and 30 or 45)
                elseif boneIdx == 3 then
                    heightOffset = isProning and 5 or (isCrouching and 15 or 25)
                elseif boneIdx == 4 then
                    heightOffset = isProning and 5 or (isCrouching and 10 or 15)
                end
                pos.Z = pos.Z + heightOffset
            end
        end
    end
    
    return pos
end

-- =========================== PHẦN 28B: AIMTOUCH FUNCTIONS (TỪ CODE 2) ===========================
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()

    if not slua.isValid(player) then
        return result
    end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()

    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    pcall(function()
        if _G.DX_GetVal("AimTouchEnable") ~= 1 then return end
        
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        
        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end
        
        -- Không chạy AimTouch khi đang cưỡi ván trượt bay (Hoverboard), Jump Pad, Xe cộ hoặc đang đính kèm phương tiện
        local isMountedOrVehicle = false
        pcall(function()
            if (type(player.IsAttachedToAnyVehicle) == "function" and player:IsAttachedToAnyVehicle())
               or (type(player.GetCurrentVehicle) == "function" and slua.isValid(player:GetCurrentVehicle()))
               or player.bIsDriving or player.bIsPassenger or player.VehicleCar
               or (type(player.GetAttachParentActor) == "function" and slua.isValid(player:GetAttachParentActor())) then
                isMountedOrVehicle = true
            end
        end)
        if isMountedOrVehicle then return end
        
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        
        -- CHECK WEAPON & AMMO
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        
        local isShotgun = false
        local isSniper = false
        local currentAmmo = 1
        
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            
            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then 
                isShotgun = true 
            end
            
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
                isSniper = true
            end
            
            if type(weapon.GetCurrentAmmo) == "function" then
                currentAmmo = weapon:GetCurrentAmmo()
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
            elseif weapon.CurrentAmmo ~= nil then
                currentAmmo = weapon.CurrentAmmo
            end
        end

        -- LOGIC NHẢ CÒ SÚNG NẾU MẤT MỤC TIÊU / ĐỊCH CHẾT HOẶC SHOTGUN HẾT ĐẠN
        if _G.DXState then
            if _G.DXState.IsAutoFiring then
                pcall(function()
                    player.bIsWeaponFiring = false
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
                end)
                _G.DXState.IsAutoFiring = false
            end
        end

        -- SHOTGUN HẾT ĐẠN NGƯNG AIM ĐỂ GAME NẠP ĐẠN
        if isShotgun and currentAmmo <= 0 then
            return
        end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 50
        local fovVal = 30
        local maxDistMeters = 50
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        
        local predVal = 0 
        local recoilCompVal = 0 

        -- PHÂN LOẠI CẤU HÌNH THEO TRẠNG THÁI HIỆN TẠI
if isShotgun and _G.DX_GetVal("AimTouchSG") == 1 then
    cond = _G.DX_GetVal("AimTouchSGCond") or 1
    if _G.DX_GetVal("AimTouchSGAutoFire") == 1 then cond = 2 end
    
    -- =========================================================
    -- [FIX] SHOTGUN GRACE PERIOD - Duy trì trạng thái "đang bắn"
    -- trong 0.6s sau phát bắn cuối để không bị ngắt khi pump action
    -- =========================================================
    local curTimeShotgun = os.clock()
    local isActuallyFiring = isFiring
    
    -- Nếu đang bắn thật → cập nhật thời gian bắn cuối
    if isFiring then
        _G.DX_Shotgun_LastFireTime = curTimeShotgun
        isActuallyFiring = true
    else
        -- Nếu vừa mới bắn xong (trong vòng 0.6s) → vẫn coi như đang bắn
        local lastFireTime = _G.DX_Shotgun_LastFireTime or 0
        if (curTimeShotgun - lastFireTime) < 0.6 then
            isActuallyFiring = true
        end
    end
    
    -- [TỐI ƯU] Điều chỉnh grace period theo từng loại shotgun
    local wNameSG = ""
    if slua.isValid(weapon) and type(weapon.GetWeaponName) == "function" then
        wNameSG = string.lower(tostring(weapon:GetWeaponName() or ""))
    end
    local gracePeriod = 0.6 -- mặc định
    if wNameSG:find("s12k") or wNameSG:find("dbs") or wNameSG:find("m1014") then 
        gracePeriod = 0.35  -- shotgun bán tự động (bắn nhanh)
    elseif wNameSG:find("s1897") then 
        gracePeriod = 0.85  -- pump chậm
    elseif wNameSG:find("s686") then 
        gracePeriod = 0.45  -- 2 nòng ngang
    end
    
    -- Áp dụng lại grace period đã tối ưu
    if not isFiring then
        local lastFireTime = _G.DX_Shotgun_LastFireTime or 0
        if (curTimeShotgun - lastFireTime) < gracePeriod then
            isActuallyFiring = true
        else
            isActuallyFiring = false
        end
    end
    
    -- Kiểm tra điều kiện bắn với trạng thái đã được "smooth"
    if cond == 1 and not isActuallyFiring then return end
    -- =========================================================
    
    prioMode = _G.DX_GetVal("AimTouchSGPrio") or 1
    boneIdx = _G.DX_GetVal("AimTouchSGBone") or 2
    speedVal = _G.DX_GetVal("AimTouchSGSpeed") or 80
    fovVal = _G.DX_GetVal("AimTouchSGFOV") or 40
    maxDistMeters = _G.DX_GetVal("AimTouchSGDist") or 30
    useVisCheck = _G.DX_GetVal("AimTouchSGVisCheck") == 1
    igKnock = _G.DX_GetVal("AimTouchSGIgKnock") == 1
    igBot = _G.DX_GetVal("AimTouchSGIgBot") == 1
            
        elseif isADS then
            if isSniper and _G.DX_GetVal("AimTouchScopeSniper") == 1 then
                cond = _G.DX_GetVal("AimTouchSniperCond") or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.DX_GetVal("AimTouchSniperPrio") or 1
                boneIdx = _G.DX_GetVal("AimTouchSniperBone") or 1
                speedVal = _G.DX_GetVal("AimTouchSniperSpeed") or 30
                fovVal = _G.DX_GetVal("AimTouchSniperFOV") or 20
                maxDistMeters = _G.DX_GetVal("AimTouchSniperDist") or 400
                useVisCheck = _G.DX_GetVal("AimTouchSniperVisCheck") == 1
                igKnock = _G.DX_GetVal("AimTouchSniperIgKnock") == 1
                igBot = _G.DX_GetVal("AimTouchSniperIgBot") == 1
                predVal = _G.DX_GetVal("AimTouchSniperPred") or 0
            elseif _G.DX_GetVal("AimTouchScopeAll") == 1 then
                cond = _G.DX_GetVal("AimTouchScopeCond") or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.DX_GetVal("AimTouchScopePrio") or 1
                boneIdx = _G.DX_GetVal("AimTouchScopeBone") or 2
                speedVal = _G.DX_GetVal("AimTouchScopeSpeed") or 40
                fovVal = _G.DX_GetVal("AimTouchScopeFOV") or 20
                maxDistMeters = _G.DX_GetVal("AimTouchScopeDist") or 300
                useVisCheck = _G.DX_GetVal("AimTouchScopeVisCheck") == 1
                igKnock = _G.DX_GetVal("AimTouchScopeIgKnock") == 1
                igBot = _G.DX_GetVal("AimTouchScopeIgBot") == 1
                predVal = _G.DX_GetVal("AimTouchScopePred") or 0
                recoilCompVal = _G.DX_GetVal("AimTouchScopeRecoil") or 0
            else
                return
            end
        else
            if not (_G.DX_GetVal("AimTouchHipfire") == 1) then return end
            cond = _G.DX_GetVal("AimTouchHipCond") or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.DX_GetVal("AimTouchHipPrio") or 1
            boneIdx = _G.DX_GetVal("AimTouchHipBone") or 1
            speedVal = _G.DX_GetVal("AimTouchHipSpeed") or 50
            fovVal = _G.DX_GetVal("AimTouchHipFOV") or 30
            maxDistMeters = _G.DX_GetVal("AimTouchHipDist") or 250
            useVisCheck = _G.DX_GetVal("AimTouchHipVisCheck") == 1
            igKnock = _G.DX_GetVal("AimTouchHipIgKnock") == 1
            igBot = _G.DX_GetVal("AimTouchHipIgBot") == 1
        end

        -- Kiểm tra trạng thái trượt (Slide) trong TDM để tránh giật màn hình
        local isSliding = false
        pcall(function()
            if player.bIsSliding or (type(player.IsSliding) == "function" and player:IsSliding()) then
                isSliding = true
            end
            if not isSliding and slua.isValid(player.STCharacterMovement) then
                if player.STCharacterMovement.bIsSliding or player.STCharacterMovement.CustomMovementMode == 1 then
                    isSliding = true
                end
            end
        end)
        
        -- Nếu đang trượt TDM và không bấm nút bắn thì không ép xoay camera SetControlRotation
        if isSliding and not isFiring then return end

        local currentMaxDist = maxDistMeters * 100 

        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end
        
        local FVector2D = import("Vector2D")
        local UGameplayStatics = import("GameplayStatics")
        local KismetMathLibrary = import("KismetMathLibrary")
        
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        
        local ui_util = require("client.common.ui_util")
        if not ui_util then return end
        
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        
        local bestTarget = nil
        local bestScore = 99999999 
        
        local selBoneName = "head"
        if boneIdx == 1 then selBoneName = "head"
        elseif boneIdx == 2 then selBoneName = "spine_03"
        elseif boneIdx == 3 then selBoneName = "spine_01"
        elseif boneIdx == 4 then selBoneName = "pelvis" end

        for i, target in ipairs(enemies) do
            if not slua.isValid(target) then goto continue end
            
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            
            if igKnock and target.HealthStatus == 1 then goto continue end
            
            if igBot then
                if CheckIsAI(target) then goto continue end
            end
            
            -- Check tường có cache
            if useVisCheck then
                local curTime = os.clock()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then goto continue end
            end
            
            local tPos = target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then goto continue end
            
            local screen = FVector2D()
            local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if not success or screen.X <= 0 or screen.Y <= 0 then goto continue end
            
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            
            if distScreen > FOV_RADIUS then goto continue end
            
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end
            
            ::continue::
        end
        
        if not slua.isValid(bestTarget) then return end
        
        local finalBonePos = bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end
        
-- [NÂNG CẤP V4] ULTIMATE PREDICTION: ITERATIVE + EMA + DYNAMIC BULLET SPEED + PING
if predVal > 0 then
pcall(function()
    local tVelocity = nil
    if type(bestTarget.GetVelocity) == "function" then
        tVelocity = bestTarget:GetVelocity()
    end
    
    if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0 or (tVelocity.Z and math.abs(tVelocity.Z) > 10)) then
        local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0 
        
        -- 1. BÙ TRỪ PING (One-way delay + Server Tick Rate 20ms)
        local pingSec = 0.02 
        pcall(function()
            local pc = GameplayData.GetPlayerController()
            if pc and pc.PlayerState and pc.PlayerState.Ping then
                pingSec = (pc.PlayerState.Ping / 2000.0) + 0.02
            end
        end)

        -- 2. TỐC ĐỘ ĐẠN ĐỘNG (Lấy chuẩn theo từng loại súng thực tế)
        local bulletSpeed = 880.0 -- Mặc định M416/SCAR
        pcall(function()
            local wep = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
            if not wep and type(player.GetCurrentShootWeapon) == "function" then wep = player:GetCurrentShootWeapon() end
            if slua.isValid(wep) then
                local wName = string.lower(tostring(type(wep.GetWeaponName) == "function" and wep:GetWeaponName() or ""))
                if wName:find("awm") then bulletSpeed = 1100.0
                elseif wName:find("kar98") or wName:find("m24") or wName:find("mosin") then bulletSpeed = 760.0
                elseif wName:find("sks") or wName:find("slr") or wName:find("mini") or wName:find("mk14") then bulletSpeed = 850.0
                elseif wName:find("akm") or wName:find("m762") or wName:find("groza") then bulletSpeed = 715.0
                elseif wName:find("uzi") or wName:find("vector") then bulletSpeed = 350.0
                elseif wName:find("ump") then bulletSpeed = 400.0
                elseif wName:find("dp28") or wName:find("m249") or wName:find("mg3") then bulletSpeed = 700.0
                end
            end
        end)

        -- 3. LỌC NHIỄU VELOCITY (EMA Smoothing - Chống giật tâm)
        if not _G.Pred_VelCache then _G.Pred_VelCache = {} end
        local tId = tostring(bestTarget)
        local oldVel = _G.Pred_VelCache[tId] or tVelocity
        local alpha = 0.4 -- Hệ số mượt (0.4 là cân bằng giữa độ bám và độ mượt)
        local smoothVel = {
            X = (oldVel.X * (1 - alpha)) + (tVelocity.X * alpha),
            Y = (oldVel.Y * (1 - alpha)) + (tVelocity.Y * alpha),
            Z = (oldVel.Z * (1 - alpha)) + ((tVelocity.Z or 0) * alpha)
        }
        _G.Pred_VelCache[tId] = smoothVel

        -- 4. HỆ SỐ BONE (Tinh chỉnh chuẩn PUBG Mobile)
        local boneFactors = {
            ["head"] = 0.75, ["neck_01"] = 0.80,
            ["spine_03"] = 1.00, ["spine_02"] = 1.05, ["spine_01"] = 0.95,
            ["pelvis"] = 0.90, ["thigh_l"] = 0.40, ["thigh_r"] = 0.40,
            ["calf_l"] = 0.20, ["calf_r"] = 0.20, ["foot_l"] = 0.10, ["foot_r"] = 0.10,
        }
        local cleanBone = string.gsub(selBoneName, "%s+", "")
        local boneFactor = boneFactors[cleanBone] or 1.0
        
        -- 5. DỰ ĐOÁN LẶP (Iterative Prediction - Giải quyết sai số cự ly xa)
        local currentToF = (distToEnemy / bulletSpeed) * (predVal / 50.0)
        local predX, predY, predZ = finalBonePos.X, finalBonePos.Y, finalBonePos.Z
        local playerLoc = player:K2_GetActorLocation()
        
        -- Lặp 3 lần để hội tụ tọa độ chính xác tuyệt đối
        for i = 1, 3 do
            local totalT = (currentToF * boneFactor) + pingSec
            
            -- Vị trí địch sau thời gian totalT
            predX = finalBonePos.X + (smoothVel.X * totalT)
            predY = finalBonePos.Y + (smoothVel.Y * totalT)
            predZ = finalBonePos.Z + (smoothVel.Z * totalT)
            
            -- Tính lại khoảng cách tới vị trí DỰ ĐOÁN (Thay vì vị trí cũ)
            if playerLoc then
                local dx = (predX - playerLoc.X) / 100.0
                local dy = (predY - playerLoc.Y) / 100.0
                local dz = (predZ - playerLoc.Z) / 100.0
                local newDist = math.sqrt(dx*dx + dy*dy + dz*dz)
                currentToF = (newDist / bulletSpeed) * (predVal / 50.0)
            end
        end
        
        -- 6. BÙ TRỪ RƠI ĐẠN (Bullet Drop) - Áp dụng cho MỌI phát bắn
        local totalFinalT = (currentToF * boneFactor) + pingSec
        local gravity = 490.0 -- 1/2 * 980 cm/s2 (Chuẩn UE4)
        local bulletDrop = gravity * (totalFinalT * totalFinalT)
        
        -- Z cuối cùng = Z địch di chuyển - Z đạn bị rơi do trọng lực
        predZ = predZ - bulletDrop

        -- Gán lại tọa độ cuối cùng cho Aimbot
        finalBonePos.X = predX
        finalBonePos.Y = predY
        finalBonePos.Z = predZ
    end
end)
end





        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end
        
        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch
        
        -- Bù trừ chênh lệch Camera khi mở ống ngắm (ADS) - Giới hạn chênh lệch để không bị lộn ngược 180 độ góc nhìn
        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                local diffYaw = camRot.Yaw - currentRot.Yaw
                local diffPitch = camRot.Pitch - currentRot.Pitch
                if diffYaw > 180 then diffYaw = diffYaw - 360 end
                if diffYaw < -180 then diffYaw = diffYaw + 360 end
                if diffPitch > 180 then diffPitch = diffPitch - 360 end
                if diffPitch < -180 then diffPitch = diffPitch + 360 end
                
                -- Chỉ bù trừ chênh lệch nhỏ khi mở ADS thực sự, tránh giật 180 độ khi va chạm vật thể/ván trượt
                if math.abs(diffYaw) < 45 and math.abs(diffPitch) < 45 then
                    deltaYaw = deltaYaw - diffYaw
                    deltaPitch = deltaPitch - diffPitch
                end
            end
        end

        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
        
        local smoothFactor = 0.0
        if speedVal >= 100 then
            smoothFactor = 1.0
        else
            smoothFactor = (speedVal / 100.0) * 0.3
            if smoothFactor < 0.01 then smoothFactor = 0.01 end
        end
        
        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
        
        -- RECOIL COMPENSATION (BÙ GIẬT)
        if recoilCompVal > 0 and isFiring then
            local pullDownForce = (recoilCompVal / 50.0) * 1.5
            finalPitch = finalPitch - pullDownForce
        end

        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")
        
        if isShotgun and _G.DX_GetVal("AimTouchSGAutoFire") == 1 then
            pcall(function()
                local distToTarget = player:GetDistanceTo(bestTarget) / 100
                if distToTarget <= maxDistMeters then
                    player.bIsWeaponFiring = true
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(true) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = true end
                    
                    local currentWep = player:GetCurrentWeapon()
                    if slua.isValid(currentWep) and type(currentWep.StartFire) == "function" then 
                        currentWep:StartFire() 
                    end
                    if _G.DXState then _G.DXState.IsAutoFiring = true end
                end
            end)
        end

    end)
end

local ThreatESP_FireCache = {}



-- =========================================================================================
-- [NEW FEATURE 4A] DYNAMIC GHOST MODE - Tạm tắt tính năng khi bị quét
-- =========================================================================================
local GhostMode_Active = false
local GhostMode_OriginalSettings = nil

local function UpdateGhostMode()
    -- Lấy trạng thái cấu hình của người dùng
    local isEnabled = (_G.DX_GetVal("GHOST_MODE") == 1)
    local curTime = os.clock()
    
    -- Kiểm tra xem hệ thống chống gian lận có đang quét hay không
    local isScanning = (curTime - (TssSdk_LastScanTime or 0)) < 5.0

    -- TRƯỜNG HỢP 1: Tính năng được bật, phát hiện có quét, và chưa kích hoạt ẩn
    if isEnabled and isScanning and not GhostMode_Active then
        GhostMode_Active = true
        
        -- Sao lưu lại toàn bộ cấu hình hiện tại của người dùng
        GhostMode_OriginalSettings = {
            AIMBOT = _G.DX_Settings.AIMBOT or 0,
            MAGIC_HEAD = _G.DX_Settings.MAGIC_HEAD or 0,
            MAGIC_BODY = _G.DX_Settings.MAGIC_BODY or 0,
            MAGIC_LEGS = _G.DX_Settings.MAGIC_LEGS or 0,
        }
        
        -- Đưa tất cả các thông số nhạy cảm về an toàn (0)
        _G.DX_Settings.AIMBOT = 0
        _G.DX_Settings.MAGIC_HEAD = 0
        _G.DX_Settings.MAGIC_BODY = 0
        _G.DX_Settings.MAGIC_LEGS = 0
        
        _G.EnvRequiresUpdate = true
        _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
        print("[GHOST MODE] Phát hiện quét bộ nhớ! Đã tạm thời vô hiệu hóa các tính năng để bảo vệ tài khoản.")

    -- TRƯỜNG HỢP 2: Quá trình quét kết thúc HOẶC người dùng chủ động tắt Ghost Mode khi đang trong trạng thái ẩn
    elseif (GhostMode_Active and not isScanning) or (not isEnabled and GhostMode_Active) then
        -- Khôi phục lại các cài đặt gốc đã lưu
        if GhostMode_OriginalSettings then
            for k, v in pairs(GhostMode_OriginalSettings) do
                _G.DX_Settings[k] = v
            end
            GhostMode_OriginalSettings = nil
        end
        
        GhostMode_Active = false
        _G.EnvRequiresUpdate = true
        _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
        print("[GHOST MODE] Trạng thái an toàn. Đã khôi phục lại các cấu hình hoạt động ban đầu.")
    end
end

-- =========================== PHẦN 29: BRPLAYERCHARACTERBASE METHODS ===========================
function BRPlayerCharacterBase:StartAdvancedSystems()
    if not Client then return end
    if self.bAdvancedSystemsStarted then return end
    self.bAdvancedSystemsStarted = true
    
    -- Clear physics asset modification cache for the new match to force re-applying Magic Bullet
    _G.DX_ModdedPhysAssets = {}
    _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
    
    local function Valid(obj) return slua_isValid(obj) end

    -- CheckIsAI function is now defined at the file scope for use by all features




    local GlobalSkelClass = import("SkeletalMeshComponent")
    
    local EMovementMode = import("EMovementMode")
    local cache_AimTouchEnable = _G.DX_GetVal("AimTouchEnable") or 0
    local cache_AUTO_BUNNYHOP = _G.DX_GetVal("AUTO_BUNNYHOP") or 0
    
    -- TIMER CHU KỲ 0.0083s DÀNH CHO AIMBOT ROYAL & CUSTOM (120 FPS)
    local aimTimerHandle
    aimTimerHandle = self:AddGameTimer(0.0083, true, function()
        if not Valid(self.Object) then
            if aimTimerHandle then self:RemoveGameTimer(aimTimerHandle) end
            return
        end
        local LocalPlayer = GameplayData.GetPlayerCharacter()
        if not Valid(LocalPlayer) then return end
        if self.Object ~= LocalPlayer then
            if aimTimerHandle then self:RemoveGameTimer(aimTimerHandle) end
            return
        end
        if cache_AimTouchEnable == 1 and _G.AimTouch then
            _G.AimTouch()
        end
        
        -- Bunny Hop (Nhảy liên tục không khựng khi giữ nút nhảy, không nhảy đè khi đang trượt TDM)
        if cache_AUTO_BUNNYHOP == 1 and self.bPressedJump then
            pcall(function()
                local isSliding = self.bIsSliding or (type(self.IsSliding) == "function" and self:IsSliding())
                if not isSliding and slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking then
                    self:Jump()
                end
            end)
        end
    end)

    local systemTimerHandle
    systemTimerHandle = self:AddGameTimer(0.03, true, function()
        if not Valid(self.Object) then
            if systemTimerHandle then self:RemoveGameTimer(systemTimerHandle) end
            return
        end
        
        local pc = GameplayData.GetPlayerController()
        local isSpectating = false
        pcall(function()
            if pc and (pc.IsSpectator and pc:IsSpectator() or pc.IsDemoPlaySpectator and pc:IsDemoPlaySpectator() or (type(pc.IsInPetSpectator) == "function" and pc:IsInPetSpectator())) then
                isSpectating = true
            end
        end)

        local LocalPlayer = nil
        if isSpectating then
            LocalPlayer = pc:GetViewTarget() or pc:GetCurPawn()
        else
            LocalPlayer = GameplayData.GetPlayerCharacter()
        end

        if not Valid(LocalPlayer) then return end
        if self.Object ~= LocalPlayer and not isSpectating then
            if systemTimerHandle then self:RemoveGameTimer(systemTimerHandle) end
            return
        end

        cache_AimTouchEnable = _G.DX_GetVal("AimTouchEnable") or 0
        cache_AUTO_BUNNYHOP = _G.DX_GetVal("AUTO_BUNNYHOP") or 0



        if self.Object == LocalPlayer and not _G.DX_HasShownWelcomeNotice then
            if self.Object.IsAlive and self.Object:IsAlive() then
                _G.DX_HasShownWelcomeNotice = true
                self.bHasShownWelcomeNotice = true
                pcall(function()
                    local msgBox = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
                    if msgBox and msgBox.Show then
                        local formattedExpire = "Vĩnh viễn"
                        if _G.DX_ExpiresAt and _G.DX_ExpiresAt ~= "" then
                            local y, m, d = string.match(_G.DX_ExpiresAt, "^(%d+)-(%d+)-(%d+)")
                            if y and m and d then
                                formattedExpire = string.format("%s/%s/%s", d, m, y)
                            else
                                formattedExpire = _G.DX_ExpiresAt
                            end
                        end
                        msgBox.Show(4, "THÔNG BÁO", "WELCOME TO VIP MOD MENU\n MOD Được Tạo Bởi Haku X DX\nMỞ CÀI ĐẶT -> DX-MODS ĐỂ TÙY CHỈNH\nHạn sử dụng đến: " .. formattedExpire, function() 
                            local KismetSystemLibrary = import("KismetSystemLibrary")
                            if KismetSystemLibrary then KismetSystemLibrary.LaunchURL(DX_TELE_GROUP) end
                        end, function() 
                            local KismetSystemLibrary = import("KismetSystemLibrary")
                            if KismetSystemLibrary then KismetSystemLibrary.LaunchURL(DX_TELE_ADMIN) end
                        end, "TELE NHÓM", "TELE ADMIN")
                    end
                end)
            end
        end

        -- [24B] Thông báo kích hoạt FAKE HWID/IP — hiện 1 lần khi alive trong phiên game
        if self.Object == LocalPlayer and not _G.DX_HasShownHWIDSpooferNotice then
            if self.Object.IsAlive and self.Object:IsAlive() then
                _G.DX_HasShownHWIDSpooferNotice = true
                self.bHasShownHWIDSpooferNotice = true
                pcall(function()
                    local fake = _G.DX_FakeData or {}
                    local msgBox = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
                    if msgBox and msgBox.Show then
                        msgBox.Show(1, "[DX] BẢO MẬT THIẾT BỊ",
                            string.format(
                                "✅ FAKE HWID + IP ĐÃ KÍCH HOẠT\n\n" ..
                                "• DeviceID: %s\n" ..
                                "• IP: %s\n" ..
                                "• Model: %s\n" ..
                                "• MAC: %s\n" ..
                                "• OS: %s\n\n" ..
                                "Tự động thay mới mỗi trận.",
                                tostring(fake.HWID or "N/A"),
                                tostring(fake.IP or "N/A"),
                                tostring(fake.Model or "N/A"),
                                tostring(fake.MAC or "N/A"),
                                tostring(fake.OS or "N/A")
                            ),
                            function() end, function() end, "OK", "ĐÓNG"
                        )
                    end
                end)
            end
        end

        -- [24B] Tái cài hook liên tục mỗi 0.25s (chống anti-cheat reset hook giữa trận)
        pcall(function()
            if _G.DX_Settings and _G.DX_Settings.FAKE_HWID == 1 then
                if _G.DX_InitializeHWIDHook then
                    _G.DX_InitializeHWIDHook()
                end
            end
        end)

        local isAiming = self.Object.bIsWeaponAiming or false

        -- Kiểm tra các trạng thái đặc biệt: Trượt TDM, Ván trượt bay (Hoverboard), Xe cộ, Cưỡi thú/Đu dây
        local isSpecialState = false
        pcall(function()
            local obj = self.Object
            -- 1. Trạng thái trượt (Slide) TDM
            if obj.bIsSliding or (type(obj.IsSliding) == "function" and obj:IsSliding()) then
                isSpecialState = true
            end
            if not isSpecialState and slua.isValid(obj.STCharacterMovement) then
                if obj.STCharacterMovement.bIsSliding or obj.STCharacterMovement.CustomMovementMode == 1 then
                    isSpecialState = true
                end
            end
            -- 2. Trạng thái Ván trượt bay / Xe cộ / Gắn kết (Hoverboard / Vehicle / Mounted)
            if not isSpecialState then
                if (type(obj.IsAttachedToAnyVehicle) == "function" and obj:IsAttachedToAnyVehicle())
                   or (type(obj.GetCurrentVehicle) == "function" and slua.isValid(obj:GetCurrentVehicle()))
                   or obj.bIsDriving or obj.bIsPassenger or obj.VehicleCar
                   or (type(obj.GetAttachParentActor) == "function" and slua.isValid(obj:GetAttachParentActor())) then
                    isSpecialState = true
                end
            end
        end)
        
        -- Nếu ở trạng thái đặc biệt và không mở ngắm thực tế thì ép isAiming = false
        if isSpecialState then
            isAiming = false
        end

        local isWallhackGlobalOn = (_G.DX_GetVal("WALLHACK") == 1)
        local isWhiteBodyOn = (_G.DX_GetVal("WHITE_BODY") == 1)            
        local espHit1 = (_G.DX_GetVal("ESP_HITMARK_1") == 1)
        local espHit2 = (_G.DX_GetVal("ESP_HITMARK_2") == 1)
        local espWeaponStance = (_G.DX_GetVal("ESP_WEAPON") == 1)
        local espCount = (_G.DX_GetVal("ESP_COUNT") == 1)

        local magicHead = 1.0 + (_G.DX_GetVal("MAGIC_HEAD") / 100.0)
        local magicBody = 1.0 + (_G.DX_GetVal("MAGIC_BODY") / 100.0)
        local magicLegs = 1.0 + (_G.DX_GetVal("MAGIC_LEGS") / 100.0)
        local BoneScaleMap = {
            ["head"] = magicHead, ["neck_01"] = magicHead,
            ["pelvis"] = magicBody, ["spine_01"] = magicBody, ["spine_02"] = magicBody, ["spine_03"] = magicBody,
            ["thigh_l"] = magicLegs, ["thigh_r"] = magicLegs, ["calf_l"] = magicLegs, ["calf_r"] = magicLegs, 
            ["foot_l"] = magicLegs, ["foot_r"] = magicLegs    
        }
        
        if self.DX_LastAimState ~= isAiming then
            self.DX_LastAimState = isAiming
            self.DX_ForceFOV = true
        end

        -- Áp dụng FOV (Nếu bật IpadView thì luôn ưu tiên duy trì góc nhìn IpadView khi trượt / đi ván trượt)
        if not isAiming or isSpecialState then
            if _G.DX_GetVal("IpadView") == 1 then
                pcall(function()
                    local targetTPP = _G.DX_GetVal("IpadViewFOV") or 120
                    local TPPCamera = self.Object.ThirdPersonCameraComponent
                    if Valid(TPPCamera) then
                        if TPPCamera.FieldOfView ~= targetTPP then TPPCamera.FieldOfView = targetTPP end
                    end
                end)
            else
                pcall(function()
                    local TPPCamera = self.Object.ThirdPersonCameraComponent
                    if Valid(TPPCamera) then
                        if TPPCamera.FieldOfView ~= 90 then TPPCamera.FieldOfView = 90 end
                    end
                end)
            end
            self.DX_ForceFOV = false
        end

        local currentTickOS = os_clock()
        if self.Object.GetCurrentWeapon then
            local currentWeapon = self.Object:GetCurrentWeapon()
            if Valid(currentWeapon) then
                if self.LastWeaponEntity ~= currentWeapon then
                    self.LastWeaponEntity = currentWeapon
                    self.bForceWeaponMod = true
                end
                if not self.LastWeaponModTime or currentTickOS > self.LastWeaponModTime + 2.0 then
                    self.bForceWeaponMod = true
                    self.LastWeaponModTime = currentTickOS
                end
                -- Identify weapon for per-weapon recoil & scope shake override
                local perWeaponRecoilKey = nil
                local perWeaponScopeKey = nil
                local weaponNameForRecoil = type(currentWeapon.GetWeaponName) == "function" and currentWeapon:GetWeaponName() or ""
                if weaponNameForRecoil and weaponNameForRecoil ~= "" then
                    perWeaponRecoilKey = GetRecoilWeaponKey(weaponNameForRecoil)
                    perWeaponScopeKey = GetScopeWeaponKey(weaponNameForRecoil)
                end

                -- Run recoil and deviation modifications every tick to prevent native game overrides
                pcall(function()
                    local entities = {}
                    if Valid(currentWeapon.ShootWeaponEntityComp) then table.insert(entities, currentWeapon.ShootWeaponEntityComp) end
                    if Valid(currentWeapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, currentWeapon.ShootWeaponEntity_GEN_VARIABLE) end
                    if Valid(currentWeapon.ShootWeaponEntity) then table.insert(entities, currentWeapon.ShootWeaponEntity) end
                    
                    for _, shootWeaponEntity in ipairs(entities) do
                        local crosshairScale = _G.DX_GetVal("THU_TAM") / 100.0
                        local scopeRecoilScale = _G.DX_GetVal("GIAM_RUNG_SCOPE") / 100.0
                        
                        shootWeaponEntity.GameDeviationFactor = 3.36 - (3.36 * crosshairScale)
                        
                        -- Cache original gun recoil values in global persistence table _G.DX_WeaponCache
                        _G.DX_WeaponCache = _G.DX_WeaponCache or {}
                        local objName = tostring(shootWeaponEntity)
                        local cache = _G.DX_WeaponCache[objName]
                        
                        if not cache then
                            -- Cache ngay khi entity tồn tại, không cần đợi RecoilKick > 0
                            -- (giá trị 0 vẫn được lưu → tránh phải tháo/lắp phụ kiện)
                            cache = {
                                DX_OrigRecoilKick     = shootWeaponEntity.RecoilKick or 0.0,
                                DX_OrigAccessoriesV   = shootWeaponEntity.AccessoriesVRecoilFactor or 1.0,
                                DX_OrigAccessoriesH   = shootWeaponEntity.AccessoriesHRecoilFactor or 1.0,
                                DX_OrigRecoilKickADS  = shootWeaponEntity.RecoilKickADS or 0.20,
                                DX_OrigModStand       = shootWeaponEntity.RecoilModifierStand or 1.0,
                                DX_OrigModCrouch      = shootWeaponEntity.RecoilModifierCrouch or 1.0,
                                DX_OrigModProne       = shootWeaponEntity.RecoilModifierProne or 1.0,
                                DX_OrigAnimKick       = shootWeaponEntity.AnimationKick or 0.0,
                                DX_OrigWeaponCamShakeScale = shootWeaponEntity.ShotCameraShakeScale or 1.0,
                                DX_Initialized        = false  -- đánh dấu chưa có giá trị thật
                            }
                            if shootWeaponEntity.RecoilInfo then
                                cache.DX_OrigVRecoilMin  = shootWeaponEntity.RecoilInfo.VerticalRecoilMin or 0.0
                                cache.DX_OrigVRecoilMax  = shootWeaponEntity.RecoilInfo.VerticalRecoilMax or 0.0
                                cache.DX_OrigSpeedV      = shootWeaponEntity.RecoilInfo.RecoilSpeedVertical or 0.0
                                cache.DX_OrigSpeedH      = shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal or 0.0
                                cache.DX_OrigRecoveryMax = shootWeaponEntity.RecoilInfo.VerticalRecoveryMax or 0.0
                                cache.DX_OrigShotCamShakeScale = shootWeaponEntity.RecoilInfo.ShotCameraShakeScale or 1.0
                            end
                            _G.DX_WeaponCache[objName] = cache
                        end

                        -- Cập nhật cache khi game điền giá trị thật vào (thường sau vài frame)
                        if cache and not cache.DX_Initialized then
                            local kickNow = shootWeaponEntity.RecoilKick or 0.0
                            local vMinNow = (shootWeaponEntity.RecoilInfo and shootWeaponEntity.RecoilInfo.VerticalRecoilMin) or 0.0
                            if kickNow > 0.0 or vMinNow > 0.0 then
                                cache.DX_OrigRecoilKick    = kickNow
                                cache.DX_OrigAccessoriesV  = shootWeaponEntity.AccessoriesVRecoilFactor or 1.0
                                cache.DX_OrigAccessoriesH  = shootWeaponEntity.AccessoriesHRecoilFactor or 1.0
                                cache.DX_OrigRecoilKickADS = shootWeaponEntity.RecoilKickADS or 0.20
                                cache.DX_OrigModStand      = shootWeaponEntity.RecoilModifierStand or 1.0
                                cache.DX_OrigModCrouch     = shootWeaponEntity.RecoilModifierCrouch or 1.0
                                cache.DX_OrigModProne      = shootWeaponEntity.RecoilModifierProne or 1.0
                                cache.DX_OrigAnimKick      = shootWeaponEntity.AnimationKick or 0.0
                                cache.DX_OrigWeaponCamShakeScale = shootWeaponEntity.ShotCameraShakeScale or 1.0
                                if shootWeaponEntity.RecoilInfo then
                                    cache.DX_OrigVRecoilMin  = shootWeaponEntity.RecoilInfo.VerticalRecoilMin or 0.0
                                    cache.DX_OrigVRecoilMax  = shootWeaponEntity.RecoilInfo.VerticalRecoilMax or 0.0
                                    cache.DX_OrigSpeedV      = shootWeaponEntity.RecoilInfo.RecoilSpeedVertical or 0.0
                                    cache.DX_OrigSpeedH      = shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal or 0.0
                                    cache.DX_OrigRecoveryMax = shootWeaponEntity.RecoilInfo.VerticalRecoveryMax or 0.0
                                    cache.DX_OrigShotCamShakeScale = shootWeaponEntity.RecoilInfo.ShotCameraShakeScale or 1.0
                                end
                                cache.DX_Initialized = true
                            end
                        end

                         if cache and cache.DX_Initialized then
                              local isADS = self.Object and (self.Object.bIsWeaponAiming == true or self.Object.bIsGunADS == true)
                              local scopeFactor = 1.0
                              if isADS then
                                  local scopePercent = _G.DX_GetVal("GIAM_RUNG_SCOPE") or 0
                                  scopeFactor = math.max(0.0, 1.0 - (scopePercent / 100.0))
                              end

                              -- 2. Tính hệ số giảm giật (NO_RECOIL_100) độc lập hoàn toàn (giới hạn tối đa 50% để tránh lỗi dame)
                              local recoilPercent = math.min(50, _G.DX_GetVal("NO_RECOIL_100") or 0)
                              local recoilFactor = math.max(0.01, 1.0 - (recoilPercent / 100.0))
                              
                              -- Áp dụng giảm giật vào các thông số Recoil
                              shootWeaponEntity.RecoilKick = (cache.DX_OrigRecoilKick or 0.0) * scopeFactor
                              shootWeaponEntity.AccessoriesVRecoilFactor = (cache.DX_OrigAccessoriesV or 1.0) * recoilFactor
                              shootWeaponEntity.AccessoriesHRecoilFactor = (cache.DX_OrigAccessoriesH or 1.0) * recoilFactor
                              shootWeaponEntity.RecoilKickADS = (cache.DX_OrigRecoilKickADS or 0.20) * scopeFactor
                              shootWeaponEntity.AnimationKick = (cache.DX_OrigAnimKick or 0.0) * scopeFactor
                              shootWeaponEntity.ShotCameraShakeScale = (cache.DX_OrigWeaponCamShakeScale or 1.0) * scopeFactor
                              if shootWeaponEntity.RecoilInfo then
                                  shootWeaponEntity.RecoilInfo.VerticalRecoilMin = (cache.DX_OrigVRecoilMin or 0.0) * recoilFactor
                                  shootWeaponEntity.RecoilInfo.VerticalRecoilMax = (cache.DX_OrigVRecoilMax or 0.0) * recoilFactor
                                  shootWeaponEntity.RecoilInfo.RecoilSpeedVertical = (cache.DX_OrigSpeedV or 0.0) * recoilFactor
                                  shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal = (cache.DX_OrigSpeedH or 0.0) * recoilFactor
                                  shootWeaponEntity.RecoilInfo.VerticalRecoveryMax = (cache.DX_OrigRecoveryMax or 0.0) * recoilFactor
                                  shootWeaponEntity.RecoilInfo.ShotCameraShakeScale = (cache.DX_OrigShotCamShakeScale or 1.0) * scopeFactor
                              end
                              shootWeaponEntity.RecoilModifierStand = (cache.DX_OrigModStand or 1.0) * recoilFactor
                              shootWeaponEntity.RecoilModifierCrouch = (cache.DX_OrigModCrouch or 1.0) * recoilFactor
                              shootWeaponEntity.RecoilModifierProne = (cache.DX_OrigModProne or 1.0) * recoilFactor
                         end
                        
                    end
                end)

                -- Run heavy aimbot modifications periodically
                if self.bForceWeaponMod or not currentWeapon.bIsTDModded then
                    pcall(function()
                        local entities = {}
                        if Valid(currentWeapon.ShootWeaponEntityComp) then table.insert(entities, currentWeapon.ShootWeaponEntityComp) end
                        if Valid(currentWeapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, currentWeapon.ShootWeaponEntity_GEN_VARIABLE) end
                        if Valid(currentWeapon.ShootWeaponEntity) then table.insert(entities, currentWeapon.ShootWeaponEntity) end
                        
                        for _, shootWeaponEntity in ipairs(entities) do
                            if _G.DX_GetVal("AIMBOT") == 1 then
                                if shootWeaponEntity.AutoAimingConfig then
                                    local autoAimConfig = shootWeaponEntity.AutoAimingConfig
                                    local aimSpeedVal = 3.0 + (3.0 * (_G.DX_GetVal("SPEED_AIMBOT") / 100.0))
                                    local aimFovVal = 1.5 + (1.5 * (_G.DX_GetVal("FOV_AIMBOT") / 100.0))
                                    
                                    if autoAimConfig.OuterRange then
                                        autoAimConfig.OuterRange.DyingRate = 0.0
                                        autoAimConfig.OuterRange.Speed = aimSpeedVal
                                        autoAimConfig.OuterRange.SpeedRate = aimSpeedVal
                                        autoAimConfig.OuterRange.RangeRate = aimFovVal
                                        autoAimConfig.OuterRange.RangeRateSight = aimFovVal
                                        autoAimConfig.OuterRange.SpeedRateSight = aimSpeedVal
                                    end
                                    if autoAimConfig.InnerRange then
                                        autoAimConfig.InnerRange.DyingRate = 0.0
                                        autoAimConfig.InnerRange.Speed = aimSpeedVal
                                        autoAimConfig.InnerRange.SpeedRate = aimSpeedVal
                                        autoAimConfig.InnerRange.RangeRate = aimFovVal
                                        autoAimConfig.InnerRange.RangeRateSight = aimFovVal
                                        autoAimConfig.InnerRange.SpeedRateSight = aimSpeedVal
                                    end
                                    shootWeaponEntity.AutoAimingConfig = autoAimConfig
                                end
                            end
                        end
                    end)
                    currentWeapon.bIsTDModded = true
                    self.bForceWeaponMod = false
                end
            end
        end

        if self.Object == LocalPlayer then
            if not _G.TDModTickCount then _G.TDModTickCount = 0 end
            if not _G.MagicUpdateVersion then _G.MagicUpdateVersion = 1 end
            if _G.EnvRequiresUpdate == nil then _G.EnvRequiresUpdate = true end

            _G.TDModTickCount = _G.TDModTickCount + 1
     
            if not self.DX_NativeESP_Ready then
                pcall(function()
                    for k, markConfig in pairs(package.loaded) do
                        if type(k) == "string" and string_find(k, "ScreenMarkConfig") then
                            if type(markConfig) == "table" then
                                if markConfig[1006] then
                                    markConfig[1006].bBindBlocked = true     
                                    markConfig[1006].bBindOutScreen = true   
                                    markConfig[1006].MaxWidgetNum = 99
                                    markConfig[1006].MaxShowDistance = 6000000
                                    markConfig[1006].bScaleByDistance = true
                                    markConfig[1006].BindSocketName = "head"
                                    markConfig[1006].bUseLuaWorldSocketName = true
                                    markConfig[1006].WorldPositionOffset = FVector(0, 0, 40)
                                end
                                markConfig[9999] = {
                                    UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                                    MaxWidgetNum = 99,
                                    MaxShowDistance = 6000000,
                                    bBindOutScreen = true,
                                    bBindBlocked = true,
                                    bIsBindingActor = true,
                                    BindSocketName = "head", 
                                    bUseLuaWorldSocketName = true,
                                    WorldPositionOffset = FVector(0, 0, 50),
                                    bNeedPreLoad = true,
                                    Priority = 2
                                }
                            end
                        elseif type(k) == "string" and string_find(k, "MapMarkGroupConfig") then
                            if type(markConfig) == "table" then
                                markConfig[9999] = {
                                    bIsScreenMark = true,
                                    ScreenMarkId = 9999,
                                    LifeTime = 0,
                                    Priority = 2,
                                    MarkType = 4
                                }
                            end
                        end
                    end
                    
                    local mapGroup = GamePlayTools.GetCurrentConfig("MapMarkGroupConfig")
                    if mapGroup then mapGroup[9999] = { bIsScreenMark = true, ScreenMarkId = 9999, LifeTime = 0, Priority = 2, MarkType = 4 } end
                    
                    local screenGroup = GamePlayTools.GetCurrentConfig("ScreenMarkConfig")
                    if screenGroup then
                        screenGroup[9999] = {
                            UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                            MaxWidgetNum = 99,
                            MaxShowDistance = 6000000,
                            bBindOutScreen = true,
                            bBindBlocked = true,
                            bIsBindingActor = true,
                            BindSocketName = "head",
                            bUseLuaWorldSocketName = true,
                            WorldPositionOffset = FVector(0, 0, 110),
                            bNeedPreLoad = true,
                            Priority = 2
                        }
                    end

                    local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
                    local hpBarSystem = SubsystemMgr:Get("ClientHPBarSubSystem")
                    if hpBarSystem then
                        if hpBarSystem.SetPauseCheck then hpBarSystem:SetPauseCheck(true) end
                        if hpBarSystem.FocusActorCheckParam then
                            hpBarSystem.FocusActorCheckParam.CheckBlock = false 
                            hpBarSystem.FocusActorCheckParam.CheckDistance = 1000000
                        end
                    end
                    
                    local UI_Manager = require("client.slua_ui_framework.manager")
                    if UI_Manager and UI_Manager.GetUI then
                        local enemyHpWidget = UI_Manager.GetUI(UI_Manager.UI_Config_InGame.EnemyHpWidgetsMain)
                        if Valid(enemyHpWidget) then
                            if enemyHpWidget.SetCheckBlock then enemyHpWidget:SetCheckBlock(false) end
                            if enemyHpWidget.UIRoot and enemyHpWidget.UIRoot.CanvasPanel_HPBarWidgets then
                                if enemyHpWidget.UIRoot.CanvasPanel_HPBarWidgets.SetRenderScale then
                                    enemyHpWidget.UIRoot.CanvasPanel_HPBarWidgets:SetRenderScale(FVector2D(1.0, 1.0))
                                end
                            end
                        end
                    end
                end)
                self.DX_NativeESP_Ready = true
            end

            -- (Spectator HP Bar Customization Removed)
            
            if _G.EnvRequiresUpdate then
                _G.EnvRequiresUpdate = false 
                pcall(function()
                    local KismetSystemLibrary = import("KismetSystemLibrary")
                    local PlayerController = GameplayData.GetPlayerController()
                    
                    local function ExecConsoleCmd(cmdKey, cmdValue)
                        if Valid(KismetSystemLibrary) and Valid(PlayerController) then
                            KismetSystemLibrary.ExecuteConsoleCommand(PlayerController, cmdKey .. " " .. cmdValue)
                        end
                        local gameInstanceHUD = slua_GameFrontendHUD and slua_GameFrontendHUD:GetGameInstance()
                        if Valid(gameInstanceHUD) and gameInstanceHUD.ExecuteCMD then gameInstanceHUD:ExecuteCMD(cmdKey, cmdValue) end
                    end

                    if Valid(PlayerController) then
                        if isWallhackGlobalOn then
                            ExecConsoleCmd("r.EnableDrawDyeingColor", "1")
                            ExecConsoleCmd("r.SupportDyeingColorDistanceFade", "1")
                            ExecConsoleCmd("r.SupportDyeingColorMeshProxy", "1")
                            ExecConsoleCmd("r.EnablePrimitiveHighlight", "1")
                            ExecConsoleCmd("r.CustomDepth", "3")
                            ExecConsoleCmd("r.DeviceLevelUseHighLightMode", "1")
                            ExecConsoleCmd("r.Highlight.Enable", "1")
                        end
                        if _G.DX_GetVal("NOGRASS") == 1 then ExecConsoleCmd("r.DisableGrassRender", "1") else ExecConsoleCmd("r.DisableGrassRender", "0") end
                        if _G.DX_GetVal("NOTREES") == 1 then
                            ExecConsoleCmd("foliage.DensityScale", "0"); ExecConsoleCmd("r.Foliage.DensityScale", "0")
                            ExecConsoleCmd("foliage.MinimumScreenSize", "10000"); ExecConsoleCmd("r.DisableTreeRender", "1")
                        else
                            ExecConsoleCmd("foliage.DensityScale", "1"); ExecConsoleCmd("r.Foliage.DensityScale", "1")
                            ExecConsoleCmd("foliage.MinimumScreenSize", "0.0001"); ExecConsoleCmd("r.DisableTreeRender", "0")
                        end
                        if _G.DX_GetVal("NOWATER") == 1 then
                            ExecConsoleCmd("r.Water.SingleLayer.Enable", "0"); ExecConsoleCmd("r.Show.Water", "0")
                            ExecConsoleCmd("r.Show.Translucency", "0"); ExecConsoleCmd("r.DisableWaterRender", "1")
                        else
                            ExecConsoleCmd("r.Water.SingleLayer.Enable", "1"); ExecConsoleCmd("r.Show.Water", "1")
                            ExecConsoleCmd("r.Show.Translucency", "1"); ExecConsoleCmd("r.DisableWaterRender", "0")
                        end
                        if _G.DX_GetVal("NOFOG") == 1 then
                            ExecConsoleCmd("r.SkyAtmosphere", "0"); ExecConsoleCmd("r.Atmosphere", "0")
                            ExecConsoleCmd("r.Fog", "0"); ExecConsoleCmd("r.VolumetricFog", "0"); ExecConsoleCmd("r.DisableSkyRender", "1")
                        else
                            ExecConsoleCmd("r.SkyAtmosphere", "1"); ExecConsoleCmd("r.Atmosphere", "1")
                            ExecConsoleCmd("r.Fog", "1"); ExecConsoleCmd("r.VolumetricFog", "1"); ExecConsoleCmd("r.DisableSkyRender", "0")
                        end
                        if _G.DX_GetVal("BLACK_SKY") == 1 then
                            ExecConsoleCmd("r.CylinderMaxDrawHeight", "9999")
                        else
                            ExecConsoleCmd("r.CylinderMaxDrawHeight", "0")
                        end
                        if isWhiteBodyOn then
                            ExecConsoleCmd("r.CharacterDiffuseOffset", "2")
                            ExecConsoleCmd("r.CharacterDiffusePower", "5")
                            ExecConsoleCmd("r.CharacterMinShadowFactor", "100")
                        else
                            ExecConsoleCmd("r.CharacterDiffuseOffset", "0")
                            ExecConsoleCmd("r.CharacterDiffusePower", "1")
                            ExecConsoleCmd("r.CharacterMinShadowFactor", "0")
                        end
                    end
                end)
            end

                        -- Chỉ chạy ESP và các cập nhật khác ở tần số ~60Hz để tiết kiệm CPU
            if true then -- Run every tick for smooth ESP
                _G.DX_HitboxModsThisFrame = 0 -- Reset số lượng mod hitbox trên frame này
                
                local allPlayers = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
                local PlayerController = GameplayData.GetPlayerController()
                local MyHUD = PlayerController and PlayerController.MyHUD

                local localPlayerLoc = nil
                if type(LocalPlayer.K2_GetActorLocation) == "function" then
                    localPlayerLoc = LocalPlayer:K2_GetActorLocation()
                end

                if not _G.DX_Active_Marks_Cache then _G.DX_Active_Marks_Cache = {} end

                for cacheKey, cacheData in pairs(_G.DX_Active_Marks_Cache) do
                    local shouldRemoveHit1 = false
                    local shouldRemoveHit2 = false
                    local shouldRemoveSpecHp = false
                    
                    if not Valid(cacheData.actor) then 
                        shouldRemoveHit1 = true; shouldRemoveHit2 = true; shouldRemoveSpecHp = true
                    else
                        pcall(function()
                            local enemyActor = cacheData.actor
                            local isDead = false
                            local isKnock = false
                            
                            if type(enemyActor.IsNearDeath) == "function" then isKnock = enemyActor:IsNearDeath()
                            elseif enemyActor.bIsNearDeath ~= nil then isKnock = enemyActor.bIsNearDeath end
                            
                            if type(enemyActor.IsDead) == "function" and enemyActor:IsDead() then isDead = true
                            elseif enemyActor.bIsDead == true or enemyActor.bIsDeadFlag == true then isDead = true end
                            
                            if enemyActor.bHidden or (enemyActor.Mesh and enemyActor.Mesh.bHidden) or isDead or isKnock then 
                                shouldRemoveHit1 = true; shouldRemoveHit2 = true; shouldRemoveSpecHp = true
                            end
                        end)
                    end

                    if not espHit1 then shouldRemoveHit1 = true end
                    if not espHit2 then shouldRemoveHit2 = true end
                    pcall(function()
                        if InGameMarkTools then
                            if shouldRemoveHit1 and cacheData.distMark then 
                                if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(cacheData.distMark)
                                elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(cacheData.distMark) end
                                cacheData.distMark = nil
                            end
                            if shouldRemoveHit2 and cacheData.hpMark then 
                                if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(cacheData.hpMark)
                                elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(cacheData.hpMark) end
                                cacheData.hpMark = nil
                            end
                        end
                    end)
                    
                    if not cacheData.hpMark and not cacheData.distMark then
                        _G.DX_Active_Marks_Cache[cacheKey] = nil
                    end
                end

                local isSpectating = false
                pcall(function()
                    local pc = GameplayData.GetPlayerController()
                    if pc and (pc.IsSpectator and pc:IsSpectator() or pc.IsDemoPlaySpectator and pc:IsDemoPlaySpectator() or (type(pc.IsInPetSpectator) == "function" and pc:IsInPetSpectator())) then
                        isSpectating = true
                    end
                end)

                local myTeamID = LocalPlayer.TeamID
                local realCount = 0
                local aiCount = 0

                local globalVisColor, globalPlayerOccludedColor, globalAiOccludedColor, globalColorHash
                if isWallhackGlobalOn then
                    globalVisColor = GetCurrentWallVisibleColor()
                    globalPlayerOccludedColor = GetCurrentWallOccludedColor(false)
                    globalAiOccludedColor = GetCurrentWallOccludedColor(true)
                    globalColorHash = tostring((_G.DX_Settings and _G.DX_Settings.WALL_VISIBLE_COLOR) or 3) .. "_"
                                   .. tostring((_G.DX_Settings and _G.DX_Settings.WALL_OCCLUDED_COLOR) or 2) .. "_"
                                   .. tostring((_G.DX_Settings and _G.DX_Settings.WALL_OCCLUDED_AI_COLOR) or 7)
                end

                for _, enemy in pairs(allPlayers) do
                    if Valid(enemy) and enemy ~= LocalPlayer and enemy.TeamID ~= myTeamID then
                        local isEnemyDead = false
                        local isEnemyKnocked = false
                        local currentHp, maxHp = 100, 100

                        if type(enemy.IsNearDeath) == "function" then 
                            isEnemyKnocked = enemy:IsNearDeath()
                        else 
                            isEnemyKnocked = enemy.bIsNearDeath or false 
                        end

                        if type(enemy.IsDead) == "function" then 
                            isEnemyDead = enemy:IsDead()
                        else 
                            isEnemyDead = enemy.bIsDead or enemy.bIsDeadFlag or false 
                        end

                        local eMesh = enemy.Mesh
                        if not isSpectating and (enemy.bHidden or (Valid(eMesh) and eMesh.bHidden)) then 
                            isEnemyDead = true 
                        end

                        if not isEnemyKnocked and not isEnemyDead then
                            if type(enemy.GetHealth) == "function" then 
                                currentHp = enemy:GetHealth() or 100
                            else 
                                currentHp = enemy.Health or 100 
                            end
                            if currentHp <= 0 then 
                                isEnemyDead = true 
                            end
                        end
                        
                        if type(enemy.GetHealthMax) == "function" then 
                            maxHp = enemy:GetHealthMax() or 100
                        else 
                            maxHp = enemy.HealthMax or 100 
                        end
                        
                        if not isEnemyDead then
                            if enemy.DX_IsAICached == nil then enemy.DX_IsAICached = CheckIsAI(enemy) end
                            
                            local distM = 0
                            enemy.DX_CachedActorLoc = nil  -- reset mỗi frame
                            if type(LocalPlayer.GetDistanceTo) == "function" then
                                distM = LocalPlayer:GetDistanceTo(enemy) / 100
                            elseif localPlayerLoc then
                                local eLoc = type(enemy.K2_GetActorLocation) == "function" and enemy:K2_GetActorLocation()
                                if eLoc then
                                    enemy.DX_CachedActorLoc = eLoc  -- [FIX LAG] Cache lại để ESP Box dùng không phải gọi lại
                                    distM = math_sqrt((localPlayerLoc.X-eLoc.X)^2 + (localPlayerLoc.Y-eLoc.Y)^2 + (localPlayerLoc.Z-eLoc.Z)^2) / 100
                                end
                            end
                       
                            -- TỐI ƯU HÓA: Bộ lọc khoảng cách (Distance Filtering)
                            local wallhackDist = (_G.DX_Settings and _G.DX_Settings.WALLHACK_DIST) or 350
                            if distM > wallhackDist then
                                if enemy.WallhackApplied or enemy.bHasTDNativeHPBar or enemy.bHasTDNativeHitmark or enemy.NativeHPBarMark or enemy.NativeDistMark or enemy.bHasTDSpectatorHPBar or enemy.SpectatorHPBarMark then
                                    pcall(function()
                                        if enemy.WallhackApplied then
                                            for _, comp in ipairs(enemy.LastAuraMeshes or {}) do
                                                if Valid(comp) then ResetMeshAuraComponent(comp) end
                                            end
                                            enemy.WallhackApplied = false
                                            enemy.LastAuraHash = nil
                                            enemy.LastAuraMeshes = nil
                                        end
                                        if InGameMarkTools then 
                                            if enemy.NativeHPBarMark then 
                                                if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
                                                elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(enemy.NativeHPBarMark) end
                                            end
                                            if enemy.SpectatorHPBarMark then 
                                                if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.SpectatorHPBarMark)
                                                elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(enemy.SpectatorHPBarMark) end
                                            end
                                            if enemy.NativeDistMark then 
                                                if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.NativeDistMark)
                                                elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(enemy.NativeDistMark) end
                                            end
                                            if InGameMarkTools.ScreenMarkManager and InGameMarkTools.ScreenMarkManager.RemoveMarkByActor then
                                                InGameMarkTools.ScreenMarkManager:RemoveMarkByActor(9999, enemy)
                                                InGameMarkTools.ScreenMarkManager:RemoveMarkByActor(1006, enemy)
                                            end
                                        end
                                        enemy.NativeHPBarMark = nil; enemy.NativeDistMark = nil; enemy.SpectatorHPBarMark = nil
                                        enemy.bHasTDNativeHPBar = false; enemy.bHasTDNativeHitmark = false; enemy.bHasTDSpectatorHPBar = false
                                        if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                                    end)
                                end
                                goto continue
                            end

                            if distM <= 600 then
                                if enemy.DX_IsAICached then aiCount = aiCount + 1 else realCount = realCount + 1 end
                            end

                            if not enemy.DX_NextMeshUpdateTime or currentTickOS > enemy.DX_NextMeshUpdateTime then
                                enemy.DX_NextMeshUpdateTime = currentTickOS + 1.5 + (math_random() * 1.0)
                                local meshes = enemy.DX_CachedMeshes or {}
                                local existing = {}
                                for _, m in ipairs(meshes) do existing[m] = true end
                                if Valid(enemy.Mesh) and not existing[enemy.Mesh] then
                                    table.insert(meshes, enemy.Mesh)
                                    existing[enemy.Mesh] = true
                                end
                                if GlobalSkelClass then
                                    pcall(function()
                                        local childs = enemy:GetComponentsByClass(GlobalSkelClass)
                                        if childs then
                                            local count = type(childs.Num) == "function" and childs:Num() or #childs
                                            for c = 1, count do
                                                local comp = type(childs.Get) == "function" and childs:Get(c-1) or childs[c]
                                                if Valid(comp) and not existing[comp] then
                                                    table.insert(meshes, comp)
                                                    existing[comp] = true
                                                end
                                            end
                                        end
                                    end)
                                end
                                enemy.DX_CachedMeshes = meshes
                            end
                            
                            local meshes = enemy.DX_CachedMeshes
                            local currentMeshCount = #meshes
                            local isMeshChanged = (enemy.LastAuraMeshes and #enemy.LastAuraMeshes ~= currentMeshCount)
                            
                            if isWallhackGlobalOn then
                                local visColor = globalVisColor
                                local occludedColor = enemy.DX_IsAICached and globalAiOccludedColor or globalPlayerOccludedColor
                                local auraHash = (enemy.DX_IsAICached and "ai_" or "player_") .. globalColorHash
                                if isMeshChanged or enemy.LastAuraHash ~= auraHash or not enemy.WallhackApplied then
                                    pcall(function()
                                        if enemy.LastAuraMeshes then
                                            for _, mesh in ipairs(enemy.LastAuraMeshes) do
                                                if Valid(mesh) then ResetMeshAuraComponent(mesh) end
                                            end
                                        end
                                        for _, mesh in ipairs(meshes) do
                                            if Valid(mesh) then
                                                ApplyAuraToMeshComponent(mesh, visColor, occludedColor)
                                            end
                                        end
                                        if enemy.DelayCustomDepth then pcall(function() enemy:DelayCustomDepth(true) end) end
                                    end)
                                    enemy.WallhackApplied = true
                                    enemy.LastAuraHash = auraHash
                                    enemy.LastAuraMeshes = {table.unpack(meshes)}
                                end
                            else
                                if enemy.WallhackApplied then
                                    pcall(function()
                                        for _, mesh in ipairs(enemy.LastAuraMeshes or meshes) do
                                            if Valid(mesh) then ResetMeshAuraComponent(mesh) end
                                        end
                                    end)
                                    enemy.WallhackApplied = false
                                    enemy.LastAuraHash = nil
                                    enemy.LastAuraMeshes = nil
                                end
                            end

                            local knockChanged = (enemy.DX_LastKnockState ~= isEnemyKnocked)
                            if knockChanged then
                                pcall(function()
                                    if InGameMarkTools then 
                                        if enemy.NativeHPBarMark then 
                                            if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
                                            elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(enemy.NativeHPBarMark) end
                                        end
                                        if enemy.SpectatorHPBarMark then 
                                            if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.SpectatorHPBarMark)
                                            elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(enemy.SpectatorHPBarMark) end
                                        end
                                        if enemy.NativeDistMark then 
                                            if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.NativeDistMark)
                                            elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(enemy.NativeDistMark) end
                                        end
                                        if InGameMarkTools.ScreenMarkManager and InGameMarkTools.ScreenMarkManager.RemoveMarkByActor then
                                            InGameMarkTools.ScreenMarkManager:RemoveMarkByActor(9999, enemy)
                                            InGameMarkTools.ScreenMarkManager:RemoveMarkByActor(1006, enemy)
                                        end
                                    end
                                end)
                                enemy.bHasTDNativeHPBar = false; enemy.bHasTDNativeHitmark = false; enemy.bHasTDSpectatorHPBar = false
                                local eStr = tostring(enemy)
                                if _G.DX_Active_Marks_Cache[eStr] then
                                    _G.DX_Active_Marks_Cache[eStr].hpMark = nil
                                    _G.DX_Active_Marks_Cache[eStr].distMark = nil
                                    _G.DX_Active_Marks_Cache[eStr].specHpMark = nil
                                end
                            end
                            enemy.DX_LastKnockState = isEnemyKnocked

                            local dynamicScale = math_max(0.5, 0.95 - (distM / 400))

                            if espHit1 and not isEnemyKnocked then
                                if not enemy.bHasTDNativeHitmark then
                                    pcall(function()
                                        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
                                            if InGameMarkTools.ScreenMarkManager and InGameMarkTools.ScreenMarkManager.OnInitMarkGroupData then 
                                                InGameMarkTools.ScreenMarkManager:OnInitMarkGroupData(9999) 
                                            end
                                            enemy.NativeDistMark = InGameMarkTools.ClientAddMapMark(9999, FVecZero, 0, "", 4, enemy)
                                            if enemy.NativeDistMark then
                                                enemy.bHasTDNativeHitmark = true
                                                local eStr = tostring(enemy)
                                                if not _G.DX_Active_Marks_Cache[eStr] then _G.DX_Active_Marks_Cache[eStr] = { actor = enemy } end
                                                _G.DX_Active_Marks_Cache[eStr].distMark = enemy.NativeDistMark
                                            end
                                        end
                                    end)
                                end
                            else
                                if enemy.bHasTDNativeHitmark or enemy.NativeDistMark then
                                    pcall(function()
                                        if InGameMarkTools then
                                            if enemy.NativeDistMark then
                                                if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.NativeDistMark) end
                                                if InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(enemy.NativeDistMark) end
                                            end
                                            if InGameMarkTools.ScreenMarkManager and InGameMarkTools.ScreenMarkManager.RemoveMarkByActor then
                                                InGameMarkTools.ScreenMarkManager:RemoveMarkByActor(9999, enemy)
                                            end
                                        end
                                    end)
                                    enemy.NativeDistMark = nil; enemy.bHasTDNativeHitmark = false
                                    local eStr = tostring(enemy)
                                    if _G.DX_Active_Marks_Cache[eStr] then _G.DX_Active_Marks_Cache[eStr].distMark = nil end
                                end
                            end

                            if espHit2 and not isEnemyKnocked then
                                if not enemy.bHasTDNativeHPBar then
                                    pcall(function()
                                        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
                                            enemy.NativeHPBarMark = InGameMarkTools.ClientAddMapMark(1006, FVecZero, 0, "", 4, enemy)
                                            enemy.bHasTDNativeHPBar = true
                                            local eStr = tostring(enemy)
                                            if not _G.DX_Active_Marks_Cache[eStr] then _G.DX_Active_Marks_Cache[eStr] = { actor = enemy } end
                                            _G.DX_Active_Marks_Cache[eStr].hpMark = enemy.NativeHPBarMark
                                        end
                                    end)
                                end
                            else
                                if enemy.bHasTDNativeHPBar then
                                    pcall(function()
                                        if InGameMarkTools then
                                            if enemy.NativeHPBarMark then
                                                if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
                                                elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(enemy.NativeHPBarMark) end
                                            end
                                        end
                                    end)
                                    enemy.NativeHPBarMark = nil; enemy.bHasTDNativeHPBar = false
                                    local eStr = tostring(enemy)
                                    if _G.DX_Active_Marks_Cache[eStr] then _G.DX_Active_Marks_Cache[eStr].hpMark = nil end
                                end
                            end

                            -- (Spectator HP Bar Draw Logic Removed)

                            -- TỐI ƯU HÓA: Chỉ kiểm tra Vũ khí/Tư thế và LineOfSight mỗi 0.4 giây
                            local enemyId = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy)
                            if espWeaponStance and Valid(MyHUD) and distM <= 250 then
                                if not enemy.DX_LastStanceUpdateTime or currentTickOS > enemy.DX_LastStanceUpdateTime + 0.4 then
                                    enemy.DX_LastStanceUpdateTime = currentTickOS
                                    
                                    -- 1. Lấy thông tin vũ khí
                                    if not enemy.DX_LastWeaponTime or currentTickOS > enemy.DX_LastWeaponTime + 1.5 then
                                        local eWeapon = enemy.CurrentWeapon
                                        if not Valid(eWeapon) and type(enemy.GetCurrentWeapon) == "function" then
                                            eWeapon = enemy:GetCurrentWeapon()
                                        end
                                        if not Valid(eWeapon) and enemy.WeaponManagerComponent then
                                            eWeapon = enemy.WeaponManagerComponent.CurrentWeaponReplicated
                                        end
                                        
                                        local weaponName = "Tay Không"
                                        if Valid(eWeapon) and type(eWeapon.GetWeaponName) == "function" then
                                            weaponName = eWeapon:GetWeaponName() or "Tay Không"
                                        end
                                        enemy.DX_CachedWeaponName = tostring(weaponName)
                                        enemy.DX_LastWeaponTime = currentTickOS
                                    end

                                    -- 2. Lấy thông tin Động tác / Tư thế (Stance)
                                    local ESTEPoseState = import("ESTEPoseState")
                                    local poseText = "Đứng"
                                    if enemy.PoseState == ESTEPoseState.Crouch then
                                        poseText = "Ngồi"
                                    elseif enemy.PoseState == ESTEPoseState.Prone then
                                        poseText = "Nằm"
                                    end

                                    enemy.DX_CachedStanceText = string.format("%s [%s]", enemy.DX_CachedWeaponName or "Tay Không", poseText)

                                    -- 3. Kiểm tra Visibility (Tận dụng cache aimbot)
                                    local isHidden = true
                                    _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                                    local cached = _G.AimTouchVisCache[enemyId]
                                    if cached and (currentTickOS - cached.time) < 0.4 then
                                        isHidden = cached.hidden
                                    else
                                        if Valid(PlayerController) then
                                            pcall(function() if PlayerController:LineOfSightTo(enemy) then isHidden = false end end)
                                        end
                                        _G.AimTouchVisCache[enemyId] = { hidden = isHidden, time = currentTickOS }
                                    end
                                    
                                    local textColor = isHidden and COLOR_RED or COLOR_GREEN
                                    if _G.DX_GetVal("THREAT_ESP") == 1 and not isHidden and enemy.bIsWeaponFiring == true then
                                        textColor = {R=255, G=0, B=0, A=255}
                                    end
                                    enemy.DX_CachedStanceColor = textColor
                                end

                                if enemy.DX_CachedStanceText then
                                    local textColor = enemy.DX_CachedStanceColor or COLOR_RED
                                    if _G.DX_GetVal("THREAT_ESP") == 1 and enemy.bIsWeaponFiring == true then
                                        local flashOn = (math_floor(currentTickOS * 6) % 2 == 0)
                                        textColor = flashOn and {R=255, G=0, B=0, A=255} or {R=80, G=0, B=0, A=255}
                                    end
                                    MyHUD:AddDebugText(enemy.DX_CachedStanceText, enemy, 0.5, {X=0, Y=0, Z=-110}, {X=0, Y=0, Z=-110}, textColor, true, false, true, nil, dynamicScale, true)
                                end
                            end

                            -- TỐI ƯU HÓA: Tích hợp Threat Assessment ESP trực tiếp vào vòng lặp chính
                            if _G.DX_GetVal("THREAT_ESP") == 1 and distM <= 800 and not isEnemyKnocked then
                                local isVisible = true
                                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                                local cached = _G.AimTouchVisCache[enemyId]
                                if cached and (currentTickOS - cached.time) < 0.4 then
                                    isVisible = not cached.hidden
                                else
                                    local isHidden = true
                                    if Valid(PlayerController) then
                                        pcall(function() if PlayerController:LineOfSightTo(enemy) then isHidden = false end end)
                                    end
                                    _G.AimTouchVisCache[enemyId] = { hidden = isHidden, time = currentTickOS }
                                    isVisible = not isHidden
                                end

                                if isVisible then
                                    local threatLevel = 0
                                    local eLoc = type(enemy.K2_GetActorLocation) == "function" and enemy:K2_GetActorLocation() or nil
                                    if eLoc and localPlayerLoc then
                                        local toMeX = localPlayerLoc.X - eLoc.X
                                        local toMeY = localPlayerLoc.Y - eLoc.Y
                                        local len2D = math_sqrt(toMeX*toMeX + toMeY*toMeY)
                                        
                                        if len2D > 5 then
                                            toMeX = toMeX / len2D
                                            toMeY = toMeY / len2D
                                            
                                            local eRot = nil
                                            pcall(function() eRot = enemy:K2_GetActorRotation() end)
                                            
                                            if eRot then
                                                local yawRad = math.rad(eRot.Yaw)
                                                local fwdX = math.cos(yawRad)
                                                local fwdY = math.sin(yawRad)
                                                local dot = toMeX * fwdX + toMeY * fwdY
                                                
                                                local poseAdjust = 0
                                                local ESTEPoseState = import("ESTEPoseState")
                                                if enemy.PoseState == ESTEPoseState.Prone then
                                                    poseAdjust = -0.05
                                                elseif enemy.PoseState == ESTEPoseState.Crouch then
                                                    poseAdjust = -0.02
                                                end
                                                
                                                local thresholdLook = 0.7 + poseAdjust
                                                local thresholdAim = 0.9 + poseAdjust
                                                
                                                local isEnemyADS = (enemy.bIsWeaponAiming == true) or (enemy.bIsGunADS == true)
                                                local isEnemyFiring = (enemy.bIsWeaponFiring == true)
                                                
                                                if isEnemyFiring then
                                                    ThreatESP_FireCache[enemyId] = currentTickOS
                                                end
                                                local lastFireTime = ThreatESP_FireCache[enemyId] or 0
                                                local isRecentlyFiring = (currentTickOS - lastFireTime) < 1.5
                                                
                                                if dot > thresholdAim then
                                                    if isEnemyADS or isEnemyFiring or isRecentlyFiring then
                                                        threatLevel = 3
                                                    elseif dot > 0.85 then
                                                        threatLevel = 3
                                                    else
                                                        threatLevel = 2
                                                    end
                                                elseif dot > thresholdLook then
                                                    if isEnemyADS or isRecentlyFiring then
                                                        threatLevel = 2
                                                    else
                                                        threatLevel = 1
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    
                                    if threatLevel >= 1 and Valid(MyHUD) then
                                        if threatLevel == 3 then
                                            local threatText = "  ĐANG NGẮM BẮN BẠN "
                                            if distM > 200 then
                                                threatText = string.format("  SNIPER NGẮM BẠN [%dm] ", math_floor(distM))
                                            end
                                            MyHUD:AddDebugText(threatText, enemy, 0.2, {X=0, Y=0, Z=130}, {X=0, Y=0, Z=130}, {R=255, G=0, B=0, A=255}, true, false, true, nil, 1.0, true)
                                        elseif threatLevel == 2 then
                                            MyHUD:AddDebugText("  ĐANG AIM VỀ BẠN", enemy, 0.2, {X=0, Y=0, Z=120}, {X=0, Y=0, Z=120}, {R=255, G=140, B=0, A=255}, true, false, true, nil, 0.9, true)
                                        else
                                            MyHUD:AddDebugText("  ĐANG NHÌN VỀ BẠN", enemy, 0.2, {X=0, Y=0, Z=110}, {X=0, Y=0, Z=110}, {R=255, G=200, B=0, A=255}, true, false, true, nil, 0.7, true)
                                        end
                                    end
                                end
                            end

                            -- [MỚI] LOGIC ESP KHUNG BOX
                            local showFrameUI = (_G.DX_GetVal("ESP_BOX") == 1 or _G.DX_GetVal("EspLoai5") == 1)
                            if showFrameUI then
                                local show = true
                                if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                    if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                                end
                                
                                -- [FIX LAG - Patch 4.5]: Tái sử dụng vị trí đã tính ở trên thay vì gọi K2_GetActorLocation() lại lần nữa
                                -- K2_GetActorLocation() là native call tốn CPU, gọi 2 lần/enemy mỗi 2 tick khi đông người gây lag
                                local enemyLoc = enemy.DX_CachedActorLoc  -- Dùng cache từ bước tính distM
                                if not enemyLoc then
                                    enemyLoc = type(enemy.K2_GetActorLocation) == "function" and enemy:K2_GetActorLocation() or nil
                                end
                                if show and enemyLoc and localPlayerLoc then
                                    local dist2D = math_sqrt((enemyLoc.X - localPlayerLoc.X)^2 + (enemyLoc.Y - localPlayerLoc.Y)^2)
                                    if enemyLoc.Z >= 150000 or dist2D > 50000 then show = false end
                                end
                                
                                if show then
                                    pcall(function()
                                        if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                        if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                        
                                        local hpRatio = currentHp / maxHp
                                        if not enemy.DX_LastHPBoxRatio or enemy.DX_LastHPBoxRatio ~= hpRatio then
                                            enemy.DX_LastHPBoxRatio = hpRatio
                                            if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                                        end
                                        
                                        local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                        if Valid(uiComp) then
                                            if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                            if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                        end
                                    end)
                                else
                                    pcall(function()
                                        if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                                        local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                        if Valid(uiComp) then
                                            if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                            if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                        end
                                    end)
                                end
                            else
                                pcall(function()
                                    if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                                    local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                    if Valid(uiComp) then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    end
                                end)
                            end

                            -- TỐI ƯU HÓA: Giới hạn hitbox mod dưới 200m và áp dụng phân bổ tải (tối đa 1 mod/tick)
                            local enemyMesh = eMesh or (enemy.getAvatarComponent2 and enemy:getAvatarComponent2())
                            if Valid(enemyMesh) and distM <= 200 then
                                local desiredScaleActive = true

                                if not enemyMesh.LastHitboxUpdateVersion 
                                   or enemyMesh.LastHitboxUpdateVersion ~= _G.MagicUpdateVersion 
                                   or enemyMesh.DX_LastAppliedScaleActive ~= desiredScaleActive then
                                    enemyMesh.bIsTDHitboxModded = false
                                end
                                
                                -- Bộ đếm kiểm tra Time-Slicing
                                if not enemyMesh.bIsTDHitboxModded then
                                    if (_G.DX_HitboxModsThisFrame or 0) >= 1 then
                                        -- Đã đủ hạn ngạch mod của frame này, hoãn sang tick sau
                                        goto skip_hitbox
                                    end
                                    _G.DX_HitboxModsThisFrame = (_G.DX_HitboxModsThisFrame or 0) + 1
                                    
                                    pcall(function()
                                        local PhysicsAsset = enemyMesh.PhysicsAssetOverride
                                        if not Valid(PhysicsAsset) and enemyMesh.SkeletalMesh then PhysicsAsset = enemyMesh.SkeletalMesh.PhysicsAsset end

                                        if Valid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
                                            if not _G.DX_OrigHitboxes then _G.DX_OrigHitboxes = {} end
                                            local PhysAssetName = ""
                                            pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
                                            if PhysAssetName == "" then PhysAssetName = "DefaultPhys" end
                                            
                                            if not _G.DX_OrigHitboxes[PhysAssetName] then 
                                                _G.DX_OrigHitboxes[PhysAssetName] = {} 
                                            end
                                            local OrigHitboxData = _G.DX_OrigHitboxes[PhysAssetName]

                                            if not _G.DX_ModdedPhysAssets then _G.DX_ModdedPhysAssets = {} end
                                            
                                            local SkeletalBodySetups = PhysicsAsset.SkeletalBodySetups
                                            for i = 1, 50 do 
                                                local BodySetup = nil
                                                pcall(function() BodySetup = type(SkeletalBodySetups.Get) == "function" and SkeletalBodySetups:Get(i-1) or SkeletalBodySetups[i] end)
                                                if not BodySetup then break end
                                                
                                                if Valid(BodySetup) then
                                                    local LowerBoneName = string_lower(tostring(BodySetup.BoneName))
                                                    local MatchedBoneKey = nil
                                                    for k, _ in pairs(BoneScaleMap) do
                                                        if string_find(LowerBoneName, k, 1, true) then MatchedBoneKey = k break end
                                                    end
                                                    
                                                    if MatchedBoneKey then
                                                        local TargetScale = 1.0
                                                        if desiredScaleActive then
                                                            TargetScale = BoneScaleMap[MatchedBoneKey] or 1.0
                                                        else
                                                            TargetScale = 1.0
                                                        end
                                                        local AggGeom = BodySetup.AggGeom
                                                        
                                                        local BoxElems = AggGeom and AggGeom.BoxElems or BodySetup.BoxElems
                                                        local SphereElems = AggGeom and AggGeom.SphereElems or BodySetup.SphereElems
                                                        local SphylElems = AggGeom and AggGeom.SphylElems or BodySetup.SphylElems

                                                        local BoxElem, SphereElem, SphylElem = nil, nil, nil
                                                        if BoxElems then pcall(function() BoxElem = type(BoxElems.Get) == "function" and BoxElems:Get(0) or BoxElems[1] end) end
                                                        if SphereElems then pcall(function() SphereElem = type(SphereElems.Get) == "function" and SphereElems:Get(0) or SphereElems[1] end) end
                                                        if SphylElems then pcall(function() SphylElem = type(SphylElems.Get) == "function" and SphylElems:Get(0) or SphylElems[1] end) end

                                                        if not OrigHitboxData[MatchedBoneKey] then
                                                            OrigHitboxData[MatchedBoneKey] = { Box = nil, Sphere = nil, Sphyl = nil }
                                                            if BoxElem then OrigHitboxData[MatchedBoneKey].Box = { X = BoxElem.X, Y = BoxElem.Y, Z = BoxElem.Z } end
                                                            if SphereElem then OrigHitboxData[MatchedBoneKey].Sphere = { Radius = SphereElem.Radius } end
                                                            if SphylElem then OrigHitboxData[MatchedBoneKey].Sphyl = { Radius = SphylElem.Radius, Length = SphylElem.Length } end
                                                        end

                                                        local OrigElemData = OrigHitboxData[MatchedBoneKey]

                                                        if OrigElemData.Box and BoxElem then
                                                            BoxElem.X = OrigElemData.Box.X * TargetScale
                                                            BoxElem.Y = OrigElemData.Box.Y * TargetScale
                                                            BoxElem.Z = OrigElemData.Box.Z * TargetScale
                                                            pcall(function() 
                                                                if type(BoxElems.Set) == "function" then BoxElems:Set(0, BoxElem) else BoxElems[1] = BoxElem end 
                                                            end)
                                                            if AggGeom then 
                                                                AggGeom.BoxElems = BoxElems
                                                                BodySetup.AggGeom = AggGeom 
                                                            else 
                                                                BodySetup.BoxElems = BoxElems 
                                                            end
                                                        end

                                                        if OrigElemData.Sphere and SphereElem then
                                                            SphereElem.Radius = OrigElemData.Sphere.Radius * TargetScale
                                                            pcall(function() 
                                                                if type(SphereElems.Set) == "function" then SphereElems:Set(0, SphereElem) else SphereElems[1] = SphereElem end 
                                                            end)
                                                            if AggGeom then 
                                                                AggGeom.SphereElems = SphereElems
                                                                BodySetup.AggGeom = AggGeom 
                                                            else 
                                                                BodySetup.SphereElems = SphereElems 
                                                            end
                                                        end
                                                        
                                                        if OrigElemData.Sphyl and SphylElem then
                                                            SphylElem.Radius = OrigElemData.Sphyl.Radius * TargetScale
                                                            SphylElem.Length = OrigElemData.Sphyl.Length * TargetScale
                                                            pcall(function() 
                                                                if type(SphylElems.Set) == "function" and SphylElems.Set then SphylElems:Set(0, SphylElem) else SphylElems[1] = SphylElem end 
                                                            end)
                                                            if AggGeom then 
                                                                AggGeom.SphylElems = SphylElems
                                                                BodySetup.AggGeom = AggGeom 
                                                            else 
                                                                BodySetup.SphylElems = SphylElems 
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                            _G.DX_ModdedPhysAssets[PhysAssetName] = _G.MagicUpdateVersion
                                        end
                                        
                                        pcall(function() 
                                            if enemyMesh.SetPhysicsAsset then enemyMesh:SetPhysicsAsset(PhysicsAsset) end
                                            enemyMesh.PhysicsAssetOverride = PhysicsAsset
                                            if enemyMesh.RecreatePhysicsState then enemyMesh:RecreatePhysicsState() end 
                                        end)
                                    end)
                                    enemyMesh.bIsTDHitboxModded = true
                                    enemyMesh.LastHitboxUpdateVersion = _G.MagicUpdateVersion
                                    enemyMesh.DX_LastAppliedScaleActive = desiredScaleActive
                                end
                            end
                            ::skip_hitbox::
                        else
                            -- Các xử lý khi nhân vật đã chết
                            if enemy.WallhackApplied then
                                pcall(function()
                                    for _, comp in ipairs(enemy.LastAuraMeshes or {}) do
                                        if Valid(comp) then ResetMeshAuraComponent(comp) end
                                    end
                                end)
                                enemy.WallhackApplied = false
                                enemy.LastAuraHash = nil
                                enemy.LastAuraMeshes = nil
                            end
 
                            pcall(function()
                                if InGameMarkTools then 
                                    if enemy.NativeHPBarMark then 
                                        if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark) end
                                    end
                                    if enemy.NativeDistMark then 
                                        if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.NativeDistMark) end
                                    end
                                    if InGameMarkTools.ScreenMarkManager and InGameMarkTools.ScreenMarkManager.RemoveMarkByActor then
                                        InGameMarkTools.ScreenMarkManager:RemoveMarkByActor(9999, enemy)
                                        InGameMarkTools.ScreenMarkManager:RemoveMarkByActor(1006, enemy)
                                    end
                                end
                            end)
                            enemy.NativeHPBarMark = nil; enemy.NativeDistMark = nil
                            enemy.bHasTDNativeHPBar = false; enemy.bHasTDNativeHitmark = false
                            
                            if enemy.Replay_SetVisiableOfFrameUI then 
                                pcall(function() enemy:Replay_SetVisiableOfFrameUI(false) end) 
                            end
                        end
                        ::continue::
                    end
                end

                if espCount then
                    pcall(function()
                        if Valid(MyHUD) then
                            -- [FIX LAG - Patch 4.5]: Throttle vẽ HUD 0.3s/lần thay vì mỗi 2 tick
                            -- AddDebugText gọi liên tục gây drop FPS đặc biệt khi đông người
                            local curCountTime = os.clock()
                            if not _G.DX_LastEnemyCountDrawTime or (curCountTime - _G.DX_LastEnemyCountDrawTime) >= 0.3 then
                                _G.DX_LastEnemyCountDrawTime = curCountTime
                                local totalEnemies = realCount + aiCount
                                local text = string.format("Kẻ Địch Xung Quanh: %d", totalEnemies)
                                MyHUD:AddDebugText(text, LocalPlayer, 0.5, FVecZero, FVecZero, COLOR_RED, true, false, true, nil, 0.8, true)
                            end
                        end
                    end)
                end

                -- ==========================================================
                -- [LOGIC ESP BOM VVIP 7.0] - Gốc & Hoàn Hảo (Chuẩn Code Đầu)
                -- ==========================================================
                if _G.DX_GetVal("EspBomMaster") == 1 and (_G.DX_GetVal("EspItemBom") == 1 or _G.DX_GetVal("EspActiveBom") == 1) then
                    pcall(function()
                        if Valid(MyHUD) then
                            if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                            if not _G.CachedActorClass_ForBomb then _G.CachedActorClass_ForBomb = import("Actor") end 
                            if not _G.CachedProjArray then _G.CachedProjArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForBomb) end
                            
                            local ui_util = require("client.common.ui_util")
                            local gameInstance = ui_util and ui_util.GetGameInstance()
                            
                            if gameInstance and _G.CachedGameplayStatics then
                                local curTime = os.clock()

                                -- Quét danh sách 0.5s/lần để chống giật FPS
                                if not _G.LastBombScanTime or (curTime - _G.LastBombScanTime) > 0.5 then
                                    _G.LastBombScanTime = curTime
                                    local allActors = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForBomb, _G.CachedProjArray)
                                    
                                    local activeBombs = {}
                                    local itemBombs = {}
                                    
                                    -- [FIX LAG - Patch 4.5]: WeakTable Cache - Bỏ qua actor đã biết KHÔNG phải bom (giảm 99% tostring spam)
                                    -- Lua GC tự dọn khi actor bị destroy, không rò RAM
                                    if not _G.DX_BombCacheInit then
                                        _G.DX_NonBombCache = setmetatable({}, { __mode = "k" })
                                        _G.DX_BombCache    = setmetatable({}, { __mode = "k" })
                                        _G.DX_BombCacheInit = true
                                    end
                                    
                                    if allActors then
                                        for _, actor in pairs(allActors) do
                                            if slua.isValid(actor) and not actor.bHidden and not actor.bTearOff then
                                                local isPendingKill = false
                                                pcall(function() if type(actor.IsPendingKill) == "function" then isPendingKill = actor:IsPendingKill() end end)
                                                
                                                if not isPendingKill then
                                                    -- Kiểm tra cache trước: nếu đã biết là KHÔNG phải bom → bỏ qua ngay
                                                    if _G.DX_NonBombCache[actor] then goto bomb_continue end
                                                    
                                                    local isKnownBomb = _G.DX_BombCache[actor]
                                                    local nameLower = nil
                                                    local bType = 0
                                                    
                                                    if isKnownBomb then
                                                        bType = isKnownBomb
                                                    else
                                                        -- Lần đầu gặp actor này: kiểm tra tên (chi phí cao - chỉ xảy ra 1 lần)
                                                        nameLower = string.lower(tostring(actor))
                                                    
                                                        if string.find(nameLower, "m79") or string.find(nameLower, "launcher") then bType = 5
                                                        elseif string.find(nameLower, "sticky") then bType = 6
                                                        elseif string.find(nameLower, "smoke") then bType = 2
                                                        elseif string.find(nameLower, "burn") or string.find(nameLower, "molotov") then bType = 3
                                                        elseif string.find(nameLower, "flash") or string.find(nameLower, "stun") then bType = 4
                                                        elseif string.find(nameLower, "grenade") then bType = 1 end
                                                        
                                                        if bType > 0 then
                                                            _G.DX_BombCache[actor] = bType  -- Lưu cache bom
                                                        else
                                                            _G.DX_NonBombCache[actor] = true  -- Lưu cache KHÔNG phải bom
                                                            goto bomb_continue
                                                        end
                                                    end -- isKnownBomb
                                                    
                                                    if bType > 0 then
                                                        nameLower = nameLower or string.lower(tostring(actor))
                                                        if string.find(nameLower, "projectile") or string.find(nameLower, "thrown") then
                                                            table.insert(activeBombs, {act = actor, type = bType})
                                                        else
                                                            local shouldAdd = true
                                                            if bType == 5 then
                                                                local attachParent = nil
                                                                pcall(function() 
                                                                    if type(actor.GetAttachParentActor) == "function" then
                                                                        attachParent = actor:GetAttachParentActor()
                                                                    end
                                                                end)
                                                                
                                                                if slua.isValid(attachParent) then
                                                                    local isHolding = false
                                                                    pcall(function()
                                                                        local curWeapon = nil
                                                                        if type(attachParent.GetCurrentWeapon) == "function" then
                                                                            curWeapon = attachParent:GetCurrentWeapon()
                                                                        elseif attachParent.CurrentWeapon then
                                                                            curWeapon = attachParent.CurrentWeapon
                                                                        end
                                                                        if curWeapon == actor then
                                                                            isHolding = true
                                                                        end
                                                                    end)
                                                                    if not isHolding then
                                                                        shouldAdd = false
                                                                    end
                                                                end
                                                            end
                                                            
                                                            if shouldAdd then
                                                                table.insert(itemBombs, {act = actor, type = bType})
                                                            end
                                                        end
                                                    end
                                                end
                                                ::bomb_continue::
                                            end
                                        end
                                    end
                                    _G.CachedActiveBombs = activeBombs
                                    _G.CachedItemBombs = itemBombs
                                end

                                local C_WHITE  = {R=255, G=255, B=255, A=255}
                                local C_RED    = {R=255, G=0, B=0, A=255}
                                local C_CYAN   = {R=0, G=255, B=255, A=255}

                                -- HÀM VẼ CHUNG
                                local function DrawBombs(bombList, isItem, maxDist)
                                    if not bombList then return end
                                    for _, item in ipairs(bombList) do
                                        local bomb = item.act
                                        local bType = item.type
                                        
                                        if slua.isValid(bomb) and not bomb.bHidden then
                                            local isPendingKill = false
                                            pcall(function() if type(bomb.IsPendingKill) == "function" then isPendingKill = bomb:IsPendingKill() end end)
                                            
                                            if not isPendingKill then
                                                local skipDraw = false
                                                if isItem and _G.CachedActiveBombs then
                                                    pcall(function()
                                                        local loc1 = type(bomb.K2_GetActorLocation) == "function" and bomb:K2_GetActorLocation()
                                                        if loc1 then
                                                            for _, actItem in ipairs(_G.CachedActiveBombs) do
                                                                local activeB = actItem.act
                                                                if slua.isValid(activeB) then
                                                                    local loc2 = type(activeB.K2_GetActorLocation) == "function" and activeB:K2_GetActorLocation()
                                                                    if loc2 then
                                                                        local dx = loc1.X - loc2.X
                                                                        local dy = loc1.Y - loc2.Y
                                                                        local dz = loc1.Z - loc2.Z
                                                                        if math.sqrt(dx*dx + dy*dy + dz*dz) < 150 then
                                                                            skipDraw = true
                                                                            break
                                                                        end
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end)
                                                end

                                                if not skipDraw then
                                                    local distM = 0
                                                    pcall(function() distM = LocalPlayer:GetDistanceTo(bomb) / 100 end)
                                                    
                                                    if distM > 0 and distM <= maxDist then
                                                        local displayName = ""
                                                        local bombColor = C_WHITE
                                                        local zOffset = isItem and 15 or 25
                                                        
                                                        if bType == 1 then
                                                            displayName = "Boom"
                                                            bombColor = isItem and {R=255, G=100, B=100, A=255} or C_RED
                                                        elseif bType == 6 then
                                                            displayName = isItem and "Bom Dính" or "BOM DÍNH"
                                                            bombColor = isItem and {R=255, G=105, B=180, A=255} or {R=255, G=0, B=255, A=255}
                                                        elseif bType == 2 then
                                                            displayName = isItem and "Khói" or "KHÓI"
                                                            bombColor = isItem and {R=200, G=200, B=200, A=255} or C_WHITE
                                                        elseif bType == 3 then
                                                            displayName = isItem and "Lửa" or "LỬA"
                                                            bombColor = isItem and {R=255, G=160, B=50, A=255} or {R=255, G=100, B=0, A=255}
                                                        elseif bType == 4 then
                                                            displayName = isItem and "Mù" or "MÙ"
                                                            bombColor = isItem and {R=150, G=255, B=255, A=255} or C_CYAN
                                                        elseif bType == 5 then
                                                            displayName = isItem and "ĐẠN KHÓI" or "ĐẠN KHÓI"
                                                            bombColor = isItem and {R=150, G=255, B=150, A=255} or {R=100, G=255, B=100, A=255}
                                                        end
                                                        
                                                        local text = string.format("%s [%dm]", displayName, math.floor(distM))
                                                        
                                                        local curGameTime = 0
                                                        pcall(function() curGameTime = _G.CachedGameplayStatics.GetTimeSeconds(gameInstance) end)
                                                        
                                                        local shouldTimerRun = not isItem
                                                        if isItem then
                                                            pcall(function()
                                                                if bomb.bIsPinPulled or bomb.bPinPulled or (type(bomb.IsPinPulled) == "function" and bomb:IsPinPulled()) then
                                                                    shouldTimerRun = true
                                                                end
                                                            end)
                                                        end

                                                        if shouldTimerRun and curGameTime > 0 then
                                                            local timeLeft = -1
                                                            pcall(function()
                                                                if type(bomb.GetExplosionTime) == "function" then timeLeft = bomb:GetExplosionTime() - curGameTime
                                                                elseif bomb.ExplosionTime then timeLeft = bomb.ExplosionTime - curGameTime
                                                                elseif bomb.ExplodeTime then timeLeft = bomb.ExplodeTime - curGameTime end
                                                            end)
                                                            
                                                            if timeLeft == -1 or timeLeft > 100 then
                                                                _G.ActiveBombTimers = _G.ActiveBombTimers or {}
                                                                local bombId = tostring(bomb)
                                                                if not _G.ActiveBombTimers[bombId] then
                                                                    _G.ActiveBombTimers[bombId] = curGameTime
                                                                end
                                                                local elapsed = curGameTime - _G.ActiveBombTimers[bombId]
                                                                local maxTime = 5.0
                                                                
                                                                if bType == 1 then maxTime = 7.0
                                                                elseif bType == 6 then maxTime = 5.0
                                                                elseif bType == 2 then maxTime = 45.0
                                                                elseif bType == 3 then maxTime = 12.0
                                                                elseif bType == 4 then maxTime = 5.0
                                                                elseif bType == 5 then maxTime = 45.0 end
                                                                
                                                                timeLeft = maxTime - elapsed
                                                            end
                                                            
                                                            if timeLeft < 0 then timeLeft = 0 end
                                                            if timeLeft > 0.1 then
                                                                text = string.format("%s (%.1fs)", text, timeLeft)
                                                                if bType == 1 and timeLeft <= 1.5 then
                                                                    bombColor = {R=255, G=165, B=0, A=255} 
                                                                end
                                                            end
                                                        end
                                                        
                                                        pcall(function()
                                                            if _G.ActiveBombTimers then
                                                                for k, v in pairs(_G.ActiveBombTimers) do
                                                                    if (curGameTime - v) > 60.0 then _G.ActiveBombTimers[k] = nil end
                                                                end
                                                            end
                                                        end)

                                                        local dynamicScale = math.max(0.6, 1.1 - (distM / maxDist))
                                                        MyHUD:AddDebugText(text, bomb, 0.35, {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset}, bombColor, true, false, true, nil, dynamicScale, true)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end

                                if _G.DX_GetVal("EspItemBom") == 1 then DrawBombs(_G.CachedItemBombs, true, 50) end
                                if _G.DX_GetVal("EspActiveBom") == 1 then DrawBombs(_G.CachedActiveBombs, false, 150) end
                            end
                        end
                    end)
                end

                -- ==========================================================
                -- [LOGIC ESP XE - VEHICLE ESP VVIP]
                -- ==========================================================
                if _G.DX_GetVal("EspVehicle") == 1 then
                    pcall(function()
                        if Valid(MyHUD) then
                            if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                            if not _G.CachedActorClass_ForVehicle then _G.CachedActorClass_ForVehicle = import("STExtraVehicleBase") end 
                            if not _G.CachedVehicleArray then _G.CachedVehicleArray = slua.Array(UEnums.EPropertyClass.Object, import("Actor")) end
                            
                            local ui_util = require("client.common.ui_util")
                            local gameInstance = ui_util and ui_util.GetGameInstance()
                            
                            if gameInstance and _G.CachedGameplayStatics then
                                local curTime = os.clock()

                                -- Quét danh sách 1.0s/lần để chống giật FPS tuyệt đối
                                if not _G.LastVehicleScanTime or (curTime - _G.LastVehicleScanTime) > 1.0 then
                                    _G.LastVehicleScanTime = curTime
                                    local allVehicles = nil
                                    pcall(function()
                                        allVehicles = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForVehicle, _G.CachedVehicleArray)
                                    end)
                                    allVehicles = allVehicles or _G.CachedVehicleArray
                                    
                                    local activeVehicles = {}
                                    if allVehicles then
                                        for _, veh in pairs(allVehicles) do
                                            if slua.isValid(veh) and not veh.bHidden and not veh.bTearOff then
                                                local isPendingKill = false
                                                pcall(function() if type(veh.IsPendingKill) == "function" then isPendingKill = veh:IsPendingKill() end end)
                                                
                                                if not isPendingKill then
                                                    local vehName = "Xe"
                                                    pcall(function()
                                                        if type(veh.GetVehicleName) == "function" then vehName = veh:GetVehicleName()
                                                        elseif veh.VehicleName then vehName = veh.VehicleName end
                                                    end)
                                                    
                                                    local nameLower = string.lower(tostring(vehName) .. tostring(veh))
                                                    local displayName = "Xe"
                                                    if string.find(nameLower, "uaz") then displayName = "UAZ"
                                                    elseif string.find(nameLower, "dacia") then displayName = "Dacia"
                                                    elseif string.find(nameLower, "buggy") then displayName = "Buggy"
                                                    elseif string.find(nameLower, "mirado") then displayName = "Mirado"
                                                    elseif string.find(nameLower, "bike") or string.find(nameLower, "motor") then displayName = "Motor"
                                                    elseif string.find(nameLower, "scooter") then displayName = "Scooter"
                                                    elseif string.find(nameLower, "coupe") then displayName = "Coupe RB"
                                                    elseif string.find(nameLower, "brdm") then displayName = "BRDM"
                                                    elseif string.find(nameLower, "boat") or string.find(nameLower, "aquarail") then displayName = "Thuyền"
                                                    elseif string.find(nameLower, "glider") then displayName = "Tàu lượn"
                                                    else displayName = "Xe (" .. string.sub(vehName, 1, 8) .. ")" end

                                                    table.insert(activeVehicles, {act = veh, name = displayName})
                                                end
                                            end
                                        end
                                    end
                                    _G.CachedVehicles = activeVehicles
                                end

                                if _G.CachedVehicles then
                                    for _, item in ipairs(_G.CachedVehicles) do
                                        local veh = item.act
                                        if slua.isValid(veh) and not veh.bHidden then
                                            local isPendingKill = false
                                            pcall(function() if type(veh.IsPendingKill) == "function" then isPendingKill = veh:IsPendingKill() end end)
                                            
                                            if not isPendingKill then
                                                local isShow = false
                                                if item.name == "Dacia" then isShow = (_G.DX_GetVal("EspVeh_Dacia") == 1)
                                                elseif item.name == "UAZ" then isShow = (_G.DX_GetVal("EspVeh_UAZ") == 1)
                                                elseif item.name == "Buggy" then isShow = (_G.DX_GetVal("EspVeh_Buggy") == 1)
                                                elseif item.name == "Coupe RB" then isShow = (_G.DX_GetVal("EspVeh_Coupe") == 1)
                                                elseif item.name == "Mirado" then isShow = (_G.DX_GetVal("EspVeh_Mirado") == 1)
                                                elseif item.name == "Motor" or item.name == "Scooter" then isShow = (_G.DX_GetVal("EspVeh_Motor") == 1)
                                                else isShow = (_G.DX_GetVal("EspVeh_Other") == 1) end

                                                if isShow then
                                                    local distM = 0
                                                    local lp = LocalPlayer or GameplayData.GetPlayerCharacter()
                                                    if slua.isValid(lp) then
                                                        pcall(function() distM = lp:GetDistanceTo(veh) / 100 end)
                                                    end
                                                    
                                                    if distM > 0 and distM <= 500 then
                                                        local hasDriver = false
                                                        pcall(function() 
                                                            local driver = type(veh.GetDriver) == "function" and veh:GetDriver() or nil
                                                            if slua.isValid(driver) then hasDriver = true end
                                                        end)

                                                        local hpStr = ""
                                                        pcall(function()
                                                            local hp = veh.HP or (type(veh.GetHP) == "function" and veh:GetHP()) or 100
                                                            local maxHp = veh.HPMax or (type(veh.GetHPMax) == "function" and veh:GetHPMax()) or 100
                                                            if maxHp > 0 then hpStr = string.format(" [%d%%]", math.floor((hp/maxHp)*100)) end
                                                        end)
                                                        
                                                        local text = string.format("%s%s [%dm]", item.name, hpStr, math.floor(distM))
                                                        local vehColor = hasDriver and {R=255, G=50, B=50, A=255} or {R=0, G=255, B=150, A=255}
                                                        local dynamicScale = math.max(0.5, 0.9 - (distM / 500))
                                                        
                                                        MyHUD:AddDebugText(text, veh, 0.35, {X=0, Y=0, Z=50}, {X=0, Y=0, Z=50}, vehColor, true, false, true, nil, dynamicScale, true)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
                
                -- ==========================================================
                -- [LOGIC ESP VẬT PHẨM - ITEM ESP VVIP]
                -- ==========================================================
                if _G.DX_GetVal("EspItemMaster") == 1 then
                    pcall(function()
                        if Valid(MyHUD) then
                            if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                            
                            -- Fallback setup for PickUp wrapper class
                            if not _G.CachedActorClass_ForPickUp then
                                local classNames = {
                                    "STExtraPickUpWrapper",
                                    "PickUpWrapperActor",
                                    "STExtraPickupWrapper",
                                    "PickupWrapperActor",
                                    "/Script/ShadowTrackerExtra.STExtraPickUpWrapper",
                                    "/Script/ShadowTrackerExtra.PickUpWrapperActor",
                                }
                                for _, name in ipairs(classNames) do
                                    pcall(function()
                                        local cls = import(name)
                                        if cls then _G.CachedActorClass_ForPickUp = cls end
                                    end)
                                    if _G.CachedActorClass_ForPickUp then break end
                                end
                            end

                            if not _G.CachedPickUpArray then
                                pcall(function()
                                    _G.CachedPickUpArray = slua.Array(UEnums.EPropertyClass.Object, import("Actor"))
                                end)
                            end
                            
                            local ui_util = require("client.common.ui_util")
                            local gameInstance = ui_util and ui_util.GetGameInstance()
                            
                            if gameInstance and _G.CachedGameplayStatics and _G.CachedActorClass_ForPickUp and _G.CachedPickUpArray then
                                local curTime = os.clock()

                                -- Quét danh sách vật phẩm dưới đất 1.0s/lần
                                if not _G.LastItemScanTime or (curTime - _G.LastItemScanTime) > 1.0 then
                                    _G.LastItemScanTime = curTime
                                    
                                    local allPickUps = nil
                                    pcall(function()
                                        allPickUps = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForPickUp, _G.CachedPickUpArray)
                                    end)
                                    allPickUps = allPickUps or _G.CachedPickUpArray
                                    
                                    local activeItems = {}
                                    if allPickUps then
                                        for _, pickup in pairs(allPickUps) do
                                            if slua.isValid(pickup) and not pickup.bHidden then
                                                local isPendingKill = false
                                                pcall(function() if type(pickup.IsPendingKill) == "function" then isPendingKill = pickup:IsPendingKill() end end)
                                                
                                                if not isPendingKill then
                                                    local itemID = nil
                                                    pcall(function()
                                                        local itemData = pickup.PickUpItemData or pickup.ItemData or pickup.PickUpData
                                                        if itemData then
                                                            local defineID = slua.IndexReference(itemData, "DefineID")
                                                            if defineID then
                                                                itemID = slua.IndexReference(defineID, "TypeSpecificID") or defineID.TypeSpecificID
                                                            else
                                                                itemID = itemData.TypeSpecificID or slua.IndexReference(itemData, "TypeSpecificID")
                                                            end
                                                        end
                                                    end)
                                                    if not itemID then
                                                        pcall(function()
                                                            itemID = pickup.TypeSpecificID or pickup.ItemID or pickup.ItemId
                                                        end)
                                                    end
                                                    
                                                    local itemName = ""
                                                    if itemID then
                                                        pcall(function()
                                                            local itemCfg = CDataTable.GetTableData("Item", itemID)
                                                            if itemCfg then
                                                                itemName = itemCfg.ItemName or itemCfg.itemName or ""
                                                            end
                                                        end)
                                                    end
                                                    
                                                    local nameLower = string.lower(tostring(itemName) .. "_" .. tostring(itemID or "") .. "_" .. tostring(pickup))
                                                    local matchedKeyword = nil
                                                    local mapping = nil
                                                    
                                                    if itemID and _G.DX_WeaponMap[itemID] then
                                                        mapping = _G.DX_WeaponMap[itemID]
                                                    else
                                                        for _, kw in ipairs(_G.DX_OrderedKeywords) do
                                                            if string.find(nameLower, kw, 1, true) then
                                                                matchedKeyword = kw
                                                                break
                                                            end
                                                        end
                                                        if matchedKeyword then
                                                            mapping = _G.DX_WeaponMap[matchedKeyword]
                                                        end
                                                    end
                                                    
                                                    if mapping then
                                                        if _G.DX_GetVal(mapping.cat) == 1 and _G.DX_GetVal(mapping.key) == 1 then
                                                            table.insert(activeItems, {
                                                                act = pickup,
                                                                name = mapping.name,
                                                                color = mapping.color
                                                            })
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    _G.CachedItems = activeItems
                                end

                                if _G.CachedItems then
                                    local maxItemDist = _G.DX_GetVal("EspItem_Dist") or 150
                                    for _, item in ipairs(_G.CachedItems) do
                                        local pickup = item.act
                                        if slua.isValid(pickup) and not pickup.bHidden then
                                            local isPendingKill = false
                                            pcall(function() if type(pickup.IsPendingKill) == "function" then isPendingKill = pickup:IsPendingKill() end end)
                                            
                                            if not isPendingKill then
                                                local distM = 0
                                                local lp = LocalPlayer or GameplayData.GetPlayerCharacter()
                                                if Valid(lp) then
                                                    pcall(function() distM = lp:GetDistanceTo(pickup) / 100 end)
                                                end
                                                
                                                if distM > 0 and distM <= maxItemDist then
                                                    local text = string.format("%s [%dm]", item.name, math.floor(distM))
                                                    local dynamicScale = math.max(0.5, 0.9 - (distM / 300))
                                                    
                                                    MyHUD:AddDebugText(text, pickup, 0.35, {X=0, Y=0, Z=15}, {X=0, Y=0, Z=15}, item.color, true, false, true, nil, dynamicScale, true)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end

                -- Threat Assessment ESP has been integrated directly into the main loop for maximum performance.
                
                -- [NEW] Dynamic Ghost Mode
                pcall(function()
                    UpdateGhostMode()
                end)
            end
        end
    end)
end

function BRPlayerCharacterBase:ctor()
    self.bHasShownDevNotice = false 
    self.bHasShownExpiredNotice = false 
    self.DX_NativeESP_Ready = false
    self.bHasShownWelcomeNotice = false
end

function BRPlayerCharacterBase:_PostConstruct()
    BRPlayerCharacterBase.__super._PostConstruct(self)
    self:InitAddSpecialMoveInfo()
    self.bCanNearDeathGiveup = true
    print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
    self:StartAdvancedSystems()
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
    BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
    
    self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
    if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
        local checkDistanceComponent = import("CheckFallingDistanceComponent")
        if slua.isValid(checkDistanceComponent) and not slua.isValid(self:GetComponentByClass(checkDistanceComponent)) then
            Game:AddComponent(checkDistanceComponent, self, "CheckFallingDistanceComponent")
        end
    end
    if slua.isValid(self.STCharacterMovement) then
        self.STCharacterMovement.bPositiveBlowUp = true
    end
    if self.Role == ENetRole.ROLE_AutonomousProxy then
        self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
        self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
        self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
            AttrName = { "bCanSelfRescue" }
        }, self.CharacterAttrChangeEvent, self)
    end
    if Client then
        GameplayData.AddCharacter(self.Object)
        self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
        self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
    else
        self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
            [1] = "FinishedState"
        }, self.HandleFinishedState, self)
    end

    EventSystem:postEvent(EVENTTYPE_SINGLETRAINING, EVENTID_CHARACTER_BEGINPLAY, self.Object)

    -- [24B] Tự động regenerate Fake HWID + IP + Firebase + XID mỗi trận mới
    -- Chạy cho nhân vật local (AutonomousProxy hoặc được điều khiển cục bộ)
    local isLocalPlayer = (self.Role == ENetRole.ROLE_AutonomousProxy) or (self.IsLocallyControlled and self:IsLocallyControlled())
    
    -- Ghi log debug
    pcall(function()
        local log_f = io.open("/sdcard/Android/data/com.vng.pubgmobile/files/loader_debug.txt", "a")
        if log_f then
            log_f:write(os.date("%Y-%m-%d %H:%M:%S") .. " [DXMOD-DEBUG] ReceiveBeginPlay. isLocalPlayer=" .. tostring(isLocalPlayer) .. " Role=" .. tostring(self.Role) .. "\n")
            log_f:close()
        end
    end)

    if isLocalPlayer then
        pcall(function()
            _G.DX_Settings = _G.DX_Settings or {}
            _G.DX_Settings.FAKE_HWID = 1       -- Đảm bảo luôn bật
            if DX_RegenerateAllFakeData then
                DX_RegenerateAllFakeData()      -- Sinh dữ liệu giả HOÀN TOÀN MỚI cho trận này
            end
            if _G.DX_InitializeHWIDHook then
                _G.DX_InitializeHWIDHook()      -- Cài hook ngay khi vào trận
            end
        end)

        -- [24B] Popup đã chuyển sang StartAdvancedSystems (hiện khi alive, tránh duplicate)

        -- Tracking block removed
    end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
    BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
    if Client and GameplayData.RemoveCharacter ~= nil then
        GameplayData.RemoveCharacter(self.Object)
    end

    -- [TỐI ƯU BỘ NHỚ] Dọn sạch cache sau mỗi trận để tránh rò RAM / iOS Jetsam OOM Kill
    pcall(function()
        local isLocalPlayer = (self.Role == ENetRole.ROLE_AutonomousProxy)
            or (self.IsLocallyControlled and self:IsLocallyControlled())
        if not isLocalPlayer then return end

        -- 1. Xóa cache VisCheck Aimbot (lưu hit/miss raycast từng địch)
        _G.AimTouchVisCache = {}

        -- 2. Xóa cache bộ đếm thời gian bom đang nổ
        _G.ActiveBombTimers = {}

        -- 3. Xóa cache vật phẩm đã revive trong hệ thống AddOutfit
        _G.AddOutfitRevived = {}

        -- 4. Reset cờ lock lobby đã khởi tạo để trận mới re-inject sạch
        _G.AddOutfitUnexpireDone = false
        _G.AddOutfitLobbyInitDone = false
        _G.AddOutfitLobbyRestored = false

        -- 5. Xóa cache trạng thái đồng bộ vũ khí cuối
        _G.AddOutfitLastAppliedSkin = {}

        -- 6. Dọn kill counter state
        _G.killCountInfo = {}
        _G.LastKillTime = {}
        _G.UpdateMyKillCounter = false

        -- 7. Dọn bộ nhớ so sánh trạng thái súng aimbot
        _G.DX_Shotgun_LastFireTime = nil
        _lastKCWeaponID = nil
        _lastKCSkinID = nil
    end)
end

-- =========================== PHẦN 30: CÁC HÀM GỐC CÒN LẠI ===========================
-- (ctor, _PostConstruct và ReceiveBeginPlay trùng lặp đã được loại bỏ để tránh đè mất hàm Mod)

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:HandleOnAttachedToVehicle", Game:GetObjName(uVehicle)))
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
    self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:UpdatePlayerAttachToVehicle(uVehicle)
      end
    end)
    self.nFixMeshContainerTimer = self:AddGameTimer(3, true, function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:FixMeshContainerOffsetIfNeeded(uVehicle)
      end
    end)
  end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(uLastVehicle) then
    return
  end
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnDetachedFromVehicle", uLastVehicle)
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not (slua.isValid(self.CapsuleComponent) and slua.isValid(self.Mesh)) or not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  if not self.nUpdatePlayerAttachToVehicleCount then
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  local ESTEPoseState = import("ESTEPoseState")
  local bStand = self.PoseState == ESTEPoseState.Stand
  local uActorRelativeLocation = self.CapsuleComponent:GetRelativeTransform():GetLocation()
  local uMeshRelativeLocation = self.Mesh:GetRelativeTransform():GetLocation()
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  local nCapsuleRadius = self.CapsuleComponent:GetScaledCapsuleRadius()
  local nCapsuleHalfHeight = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local nExpectedCapsuleRadius = self.StandRadius
  local nExpectedCapsuleHalfHeight = self.StandHalfHeight
  local uMeshExpectedRL = FVector(0, 0, 0)
  local uActorExpectedRL = FVector(0, 0, self.StandHalfHeight)
  local nTolerance = 1.0
  local bCapsuleRLCorrect = uActorRelativeLocation:Equals(uActorExpectedRL, nTolerance)
  local bMeshRLCorrect = uMeshRelativeLocation:Equals(uMeshExpectedRL, nTolerance)
  local bMeshContainerRLCorrect = nTolerance > math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ)
  local bCapsuleRadiusCorrect = nTolerance > math.abs(nCapsuleRadius - nExpectedCapsuleRadius)
  local bCapsuleHalfHeightCorrect = nTolerance > math.abs(nCapsuleHalfHeight - nExpectedCapsuleHalfHeight)
  local bAllCorrect = bStand and bCapsuleRLCorrect and bMeshRLCorrect and bMeshContainerRLCorrect and bCapsuleRadiusCorrect and bCapsuleHalfHeightCorrect
  if not bAllCorrect then
    self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1
  else
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:UpdatePlayerAttachToVehicle PlayerKey:%s. bAllCorrect=%s Check Result:%d %d %d %d %d %d, Count:%d", tostring(self.PlayerKey), tostring(bAllCorrect), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, self.nUpdatePlayerAttachToVehicleCount))
  if self.nUpdatePlayerAttachToVehicleCount >= 3 and not bAllCorrect then
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local uPlayerController = GameplayData.GetPlayerController()
    if uPlayerController.ReportCrashKitFeature and uPlayerController.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
      local sReportInfo = string.format("VehicleShapeType:%s PlayerKey:%s. Check Result:%d %d %d %d %d %d. Capsule.RelativeLoc:%s Capsule.Radius:%s Capsule.HalfHeight:%s Mesh.RelativeLoc:%s MeshContainer.RelativeLocZ:%s", tostring(uVehicle.VehicleShapeType), tostring(self.PlayerKey), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, uActorRelativeLocation:ToString(), tostring(nCapsuleRadius), tostring(nCapsuleHalfHeight), uMeshRelativeLocation:ToString(), tostring(uMeshContainerRelativeLocationZ))
      uPlayerController.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(sReportInfo)
    end
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  local nTolerance = 1.0
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  if nTolerance <= math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ) then
    print(bWriteLog and string.format("BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded PlayerKey:%s. SetMeshContainerOffsetZ from:%s to:%s", tostring(self.PlayerKey), tostring(uMeshContainerRelativeLocationZ), tostring(uMeshContainerExpectedZ)))
    self:SetMeshContainerOffsetZ(uMeshContainerExpectedZ)
  end
end

function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
  if self.nUpdatePlayerAttachToVehicleTimer then
    self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer)
    self.nUpdatePlayerAttachToVehicleTimer = nil
  end
  if self.nFixMeshContainerTimer then
    self:RemoveGameTimer(self.nFixMeshContainerTimer)
    self.nFixMeshContainerTimer = nil
  end
end



function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if _G.DX_GetVal("NO_LANDING_LAG") == 1 then
    pcall(function()
      if slua.isValid(self.Mesh) then
        local animIns = self.Mesh:GetAnimInstance()
        if slua.isValid(animIns) then
          animIns:Montage_Stop(0.0)
        end
      end
      if slua.isValid(self.STCharacterMovement) then
        local EMovementMode = import("EMovementMode")
        self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_Walking)
        local velocity = self:GetVelocity()
        if velocity then
          velocity.Z = 0
        end
      end
    end)
  else
    if self.HandleOnLanded then
      self:HandleOnLanded(-1)
    end
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end


BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.UInt32,
    UEnums.EPropertyClass.UInt32
  }
}

function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
  print(bWriteLog and string.format("BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment Type = %d, Param = %s", Type, Param))
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end


function BRPlayerCharacterBase:CheckForbidFlaregun()
  return false
end


-- [XÓA BỎ SPECTATOR WALLHACK THEO YÊU CẦU]

-- =========================================================================

-- ==================== GLOBAL PLAYER SYNC FOR WOW & TDM ====================
local function SyncPlayersToGameplayData()
    pcall(function()
        local function DX_Log(msg)
            pcall(function()
                local log_f = io.open("/sdcard/Android/data/com.vng.pubgmobile/files/loader_debug.txt", "a")
                if log_f then
                    log_f:write(os.date("%Y-%m-%d %H:%M:%S") .. " [DXMOD-SYNC-DEBUG] " .. tostring(msg) .. "\n")
                    log_f:close()
                end
            end)
        end

        local ui_util = require("client.common.ui_util")
        local gameInstance = ui_util and ui_util.GetGameInstance()
        local gp = import("GameplayStatics")
        local gd = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
        local actorClass = import("STExtraPlayerCharacter") or import("Character") or import("STExtraBaseCharacter") or import("Pawn")
        
        if not _G.DX_LastSyncLogTime or os.time() - _G.DX_LastSyncLogTime >= 5 then
            _G.DX_LastSyncLogTime = os.time()
            local classNameStr = "nil"
            pcall(function()
                if actorClass then
                    if type(actorClass) == "table" or type(actorClass) == "userdata" then
                        classNameStr = actorClass.GetName and actorClass:GetName() or tostring(actorClass)
                    else
                        classNameStr = tostring(actorClass)
                    end
                end
            end)
            DX_Log(string.format("Sync Loop Tick: gameInstance=%s, gp=%s, gd=%s, actorClass=%s", 
                tostring(gameInstance ~= nil), tostring(gp ~= nil), tostring(gd ~= nil), classNameStr))
        end
        
        if gameInstance and gp and gd and actorClass then
            local outArray = slua.Array(UEnums.EPropertyClass.Object, import("Actor"))
            gp.GetAllActorsOfClass(gameInstance, actorClass, outArray)
            
            local pc = gp.GetPlayerController(gameInstance, 0)
            local localPawn = pc and pc.AcknowledgedPawn
            
            local printDetail = false
            if not _G.DX_LastSyncDetailLogTime or os.time() - _G.DX_LastSyncDetailLogTime >= 10 then
                _G.DX_LastSyncDetailLogTime = os.time()
                printDetail = true
                DX_Log(string.format("Sync details: Found %d actors, localPawn=%s", outArray:Num(), tostring(localPawn)))
            end
            
            local function GetRawActor(pawn)
                if not slua.isValid(pawn) then return nil end
                if pawn.Object and slua.isValid(pawn.Object) then
                    return pawn.Object
                end
                return pawn
            end

            for i = 0, outArray:Num() - 1 do
                local actor = outArray:Get(i)
                if slua.isValid(actor) then
                    if not actor.Object or not slua.isValid(actor.Object) then
                        actor.Object = actor
                    end
                    -- 1. Ép đăng ký vào GameplayData để các hàm ESP/Aimbot gốc nhìn thấy
                    pcall(function()
                        gd.AddCharacter(actor)
                    end)
                    
                    -- 2. Kiểm tra xem có phải là nhân vật local player hay không
                    local isLocal = false
                    if localPawn then
                        local rawActor = GetRawActor(actor)
                        local rawLocal = GetRawActor(localPawn)
                        
                        if rawActor and rawLocal then
                            if rawActor == rawLocal then
                                isLocal = true
                            else
                                -- Kiểm tra bằng GetPathName
                                local ok1, path1 = pcall(function() return rawActor:GetPathName() end)
                                local ok2, path2 = pcall(function() return rawLocal:GetPathName() end)
                                if ok1 and ok2 and path1 == path2 and path1 ~= nil and path1 ~= "" then
                                    isLocal = true
                                else
                                    -- Kiểm tra bằng GetName
                                    local okName1, name1 = pcall(function() return rawActor:GetName() end)
                                    local okName2, name2 = pcall(function() return rawLocal:GetName() end)
                                    if okName1 and okName2 and name1 == name2 and name1 ~= nil and name1 ~= "" then
                                        isLocal = true
                                    elseif rawActor.PlayerKey and rawLocal.PlayerKey and rawActor.PlayerKey == rawLocal.PlayerKey and rawActor.PlayerKey ~= 0 then
                                        isLocal = true
                                    end
                                end
                            end
                        end
                        
                        if printDetail then
                            local className = "Unknown"
                            pcall(function() className = actor:GetClass():GetName() end)
                            local aName = "nil"
                            pcall(function() aName = rawActor and (rawActor.GetPathName and rawActor:GetPathName() or tostring(rawActor)) or "nil" end)
                            local lpName = "nil"
                            pcall(function() lpName = rawLocal and (rawLocal.GetPathName and rawLocal:GetPathName() or tostring(rawLocal)) or "nil" end)
                            DX_Log(string.format("Checking actor: Class=%s, Path=%s vs localPawn=%s | isLocal=%s", 
                                className, aName, lpName, tostring(isLocal)))
                        end
                    end

                    -- 3. Nếu là nhân vật của mình và chưa được khởi chạy Mod
                    if isLocal and not actor._DXInitialized then
                        local className = "Unknown"
                        pcall(function()
                            if actor and actor.GetClass then
                                local cls = actor:GetClass()
                                if cls then
                                    className = cls.GetName and cls:GetName() or tostring(cls)
                                end
                            end
                        end)
                        DX_Log("Pushing mod functions to LocalPlayer Class: " .. tostring(className))
                        
                        -- Copy toàn bộ hàm mod từ BRPlayerCharacterBase sang nhân vật hiện tại (Ép ghi đè toàn bộ)
                        local copyOk, copyErr = pcall(function()
                            for k, v in pairs(BRPlayerCharacterBase) do
                                if type(v) == "function" then
                                    actor[k] = v
                                elseif k == "ServerRPC" or k == "ClientRPC" or k == "MulticastRPC" then
                                    actor[k] = actor[k] or {}
                                    for rpcKey, rpcVal in pairs(v) do
                                        actor[k][rpcKey] = rpcVal
                                    end
                                end
                            end
                        end)
                        
                        if copyOk then
                            actor._DXInitialized = true
                            DX_Log("Successfully pushed mod functions to LocalPlayer")
                        else
                            DX_Log("Failed to push mod functions: " .. tostring(copyErr))
                        end
                        
                        -- Cấu hình các biến trạng thái
                        actor.bHasShownDevNotice = false 
                        actor.bHasShownExpiredNotice = false 
                        actor.bHasShownWelcomeNotice = false
                        actor.bIsDeadFlag = false
                        actor.bForceWeaponMod = true
                        actor.DX_NativeESP_Ready = false
                        -- Khởi tạo CarryDeadBoxFeature nếu chưa có
                        if not actor.CarryDeadBoxFeature then
                            pcall(function()
                                local FeaturePath = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
                                local FeatureClass = package.loaded[FeaturePath] or require(FeaturePath)
                                if FeatureClass then
                                    local featureInstance = nil
                                    pcall(function() featureInstance = FeatureClass(actor) end)
                                    if not featureInstance then
                                        pcall(function() featureInstance = FeatureClass.New(actor) end)
                                    end
                                    if not featureInstance then
                                        pcall(function()
                                            featureInstance = {}
                                            setmetatable(featureInstance, { __index = FeatureClass })
                                            featureInstance.Owner = actor
                                            if type(featureInstance.ctor) == "function" then
                                                featureInstance:ctor(actor)
                                            end
                                        end)
                                    end
                                    
                                    if featureInstance then
                                        actor.CarryDeadBoxFeature = featureInstance
                                        print("[DXMOD] Manually created CarryDeadBoxFeature for LocalPlayer")
                                        if type(featureInstance.ReceiveBeginPlay) == "function" then
                                            pcall(featureInstance.ReceiveBeginPlay, featureInstance)
                                        end
                                    end
                                end
                            end)
                        end
                        
                        -- Kích hoạt hệ thống hack nâng cao
                        if type(actor.StartAdvancedSystems) == "function" then
                            pcall(function() actor:StartAdvancedSystems() end)
                        end
                    end
                end
            end
        end
    end)
end

local function StartGlobalDXPlayerSync()
    local function SyncLoop()
        SyncPlayersToGameplayData()
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(1.5, SyncLoop)
        end
    end
    SyncLoop()
end

-- =========================================================================


-- =========================== PHẦN 31: INIT ALL MOD SYSTEMS ===========================
local function InitAllModSystems()
    pcall(function()
        RunAllBypasses()
        _G.InitModMenuTab()
        StartPeriodicRehook()
        DisableHiggsBoson()
        if StartDXCheckLoop then
            StartDXCheckLoop()
        end
    end)

    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then return end

    pcall(function()
        local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            if BRPlayerCharacterBase.StartAdvancedSystems then
                LocalPlayer.StartAdvancedSystems = BRPlayerCharacterBase.StartAdvancedSystems
            end
            if LocalPlayer.bHasShownDevNotice == nil then
                LocalPlayer.bHasShownDevNotice = false 
                LocalPlayer.bHasShownExpiredNotice = false 
                LocalPlayer.bHasShownWelcomeNotice = false
                LocalPlayer.bIsDeadFlag = false
                LocalPlayer.bForceWeaponMod = true
                LocalPlayer.DX_NativeESP_Ready = false
            end
            if type(LocalPlayer.StartAdvancedSystems) == "function" then
                pcall(function() 
                    LocalPlayer:StartAdvancedSystems() 
                end)
            end
        end
    end)

    -- Chạy vòng quét ngầm đồng bộ WOW/TDM
    pcall(StartGlobalDXPlayerSync)
end

pcall(function() 
    require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) 
end)

pcall(function()
    function MockServer_HandleTssPacket(playerId, tssData)
        if not playerId then
            return false, nil
        end

        local dataSize = 0
        if type(tssData) == "string" or type(tssData) == "table" then
            dataSize = #tssData
        end

        print(string.format("[DEBUG] Received TSS Packet from Player ID: %s, Size: %d", tostring(playerId), dataSize))
        
        return true, "MOCK_SUCCES"
    end
end)

-- =========================== PHẦN 31B: SPECTATOR BYPASS FOR VISIBILITY ===========================
local orig_SetActorHiddenInGame = BRPlayerCharacterBase.SetActorHiddenInGame
function BRPlayerCharacterBase:SetActorHiddenInGame(bNewHidden)
    local pc = GameplayData.GetPlayerController()
    local isSpectating = false
    pcall(function()
        if pc and (pc.IsSpectator and pc:IsSpectator() or pc.IsDemoPlaySpectator and pc:IsDemoPlaySpectator() or (type(pc.IsInPetSpectator) == "function" and pc:IsInPetSpectator())) then
            isSpectating = true
        end
    end)
    if isSpectating then
        if orig_SetActorHiddenInGame then
            orig_SetActorHiddenInGame(self, false)
        elseif BRPlayerCharacterBase.__super and BRPlayerCharacterBase.__super.SetActorHiddenInGame then
            BRPlayerCharacterBase.__super.SetActorHiddenInGame(self, false)
        else
            pcall(function() self.Object:SetActorHiddenInGame(false) end)
        end
        return
    end
    if orig_SetActorHiddenInGame then
        orig_SetActorHiddenInGame(self, bNewHidden)
    elseif BRPlayerCharacterBase.__super and BRPlayerCharacterBase.__super.SetActorHiddenInGame then
        BRPlayerCharacterBase.__super.SetActorHiddenInGame(self, bNewHidden)
    else
        pcall(function() self.Object:SetActorHiddenInGame(bNewHidden) end)
    end
end

local orig_SetActorHiddenInGameMask = BRPlayerCharacterBase.SetActorHiddenInGameMask
function BRPlayerCharacterBase:SetActorHiddenInGameMask(bHide, MaskType)
    local pc = GameplayData.GetPlayerController()
    local isSpectating = false
    pcall(function()
        if pc and (pc.IsSpectator and pc:IsSpectator() or pc.IsDemoPlaySpectator and pc:IsDemoPlaySpectator() or (type(pc.IsInPetSpectator) == "function" and pc:IsInPetSpectator())) then
            isSpectating = true
        end
    end)
    if isSpectating then
        if orig_SetActorHiddenInGameMask then
            orig_SetActorHiddenInGameMask(self, false, MaskType)
        elseif BRPlayerCharacterBase.__super and BRPlayerCharacterBase.__super.SetActorHiddenInGameMask then
            BRPlayerCharacterBase.__super.SetActorHiddenInGameMask(self, false, MaskType)
        else
            pcall(function() self.Object:SetActorHiddenInGameMask(false, MaskType) end)
        end
        return
    end
    if orig_SetActorHiddenInGameMask then
        orig_SetActorHiddenInGameMask(self, bHide, MaskType)
    elseif BRPlayerCharacterBase.__super and BRPlayerCharacterBase.__super.SetActorHiddenInGameMask then
        BRPlayerCharacterBase.__super.SetActorHiddenInGameMask(self, bHide, MaskType)
    else
        pcall(function() self.Object:SetActorHiddenInGameMask(bHide, MaskType) end)
    end
end




local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
    end)
end

local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue; FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then TssSdk.GetFileMD5 = function() return "BYPASS" end; TssSdk.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end; STExtra.VerifyFile = retTrue end
    end)
end
local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end
local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then SMTD.MTDePicture = function() return "" end; SMTD.ReMTDePicture = function() return "" end; SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop; TLog.Send = nop; TLog.Flush = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop; CrashSight.ReportUserException = nop end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then GRUtils.BugglyPostExceptionFull = retFalse; GRUtils.CheckCanBugglyPostException = retFalse; GRUtils.ReplayReportData = nop; GRUtils.ReportGameException = nop; GRUtils.PostException = nop end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]; if s then s.logEvent = nop; s.trackEvent = nop; s.setEnabled = retFalse; s.sendEvent = nop; s.report = nop end
        end
    end)
end

local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem", "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "FileCheckSubsystem", "BehaviorScoreSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.ReportPingDelayTimer then sub:RemoveGameTimer(sub.ReportPingDelayTimer); sub.ReportPingDelayTimer = nil end; sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then AvaEx.CheckAvatarException = nop; AvaEx.CheckAvatarExceptionOnce = nop; AvaEx.ReportAvatarException = nop; AvaEx.CheckSlotMeshVisible = retFalse; AvaEx.CheckPawnVisible = retFalse; AvaEx.CheckCanBugglyPostException = retFalse end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            -- [FIX PING]: Thêm tham số 'true' vào hàm find để tìm kiếm chuỗi thuần túy, nhanh hơn hàng chục lần so với regex, chống giật ping
            TssSdk.OnRecvData = function(data) if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true) or data:find("cheat", 1, true) or data:find("violation", 1, true) or data:find("hack", 1, true) or data:find("verify", 1, true)) then return end; if origData then origData(data) end end
            TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue; TssSdk.IsEmulator = retFalse; TssSdk.GetTssSdkReportInfo = retEmptyString; TssSdk.CheckEnvironment = retTrue; TssSdk.VerifyProcess = retTrue
        end
    end)
end

local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then pcall(function() sub[k] = nop end) end end end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then logRep.ReportReplay = nop; logRep.SendReportReq = nop; logRep.UploadReplay = nop end
    end)
end

local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do if _G[f] then _G[f] = retFalse end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"}) do if _G[f] then _G[f] = retFalse end end
    end)
end

local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then for k, v in pairs(_G[c]) do if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then _G[c][k] = nop end end end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue; SecSub.CollectData = nop; SecSub.SendToServer = nop end
    end)
end

local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop end
    end)
end

local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData = nop; sub.SendToServer = nop; sub.CollectTelemetry = nop; sub.StopCollection = nop end
    end)
end

local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException = nop; sub.CheckModifier = retTrue; sub.ValidateModifier = retTrue; sub.ReportModifierError = nop end
    end)
end

local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue end
    end)
end

local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop; sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue end
        if _G.BulletHitInfoUploadData then _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop end
    end)
end

local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket and not NetUtil.IsBypassed then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1, ["ReportSecVehicleMoveFlow"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, ["report_speed_hack"]=1, ["report_wall_hack"]=1, ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_modded_files"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1, ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1, ["bReportedModifierException"]=1,
                ["ReportModifierException"]=1, ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1, ["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1, ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1, ["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...) for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end; return origRPC(rpcName, ...) end
        end
    end)
end

local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "OnTick", "MHActiveLogic", "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage", "OnWeaponHitRecord", "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData", "ValidateSecurityData", "StaticShowSecurityAlertInDev", "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation", "DisableHiggsBoson", "CheckMHActive", "ReportViolation", "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.GetCurWeaponSkinID = retZero; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false; Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false; if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false; pc.HiggsBosonComponent:ControlMHActive(0) end
        end
    end)
end

local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = nop; _G.AvatarCheckCallback.OnReportItemID = nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then PlayerController.HiggsBosonComponent:ControlMHActive(0); PlayerController.HiggsBosonComponent.bMHActive = false end
        end
    end
end

local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]; if not sub then local s, r = pcall(require, path); if s and r then sub = r end end
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "OnDSConnectionSaturated", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow", "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1, ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop; GC.OnPlayerActorChannelError = nop; GC.OnPlayerRPCValidateFailed = nop; GC.OnPlayerSpectateException = nop; GC.OnShutdownAfterError = nop; GC.IsBypassed = true
    end)
end

local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient", "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem", "MD5CheckSubsystem", "PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then pcall(function() sub[k] = nop end) end end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT"}) do if _G[flag] then _G[flag] = false end end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m) for _, b in ipairs(blocked) do if m:find(b) then return {} end end; return origReq(m) end
    end)
end

_G.StartBypass_VIP_v3 = function()
    pcall(function()
        print("[ULTIMATE BYPASS] Starting initialization...")
        InitializeSLUABypass()
        InitializeMD5Bypass()
        InitializeSkinBypass() -- Thêm dòng này
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeReplayTelemetryBlocker()
        InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass()
        InitializeClientFlowBypass()
        InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass()
        InitializeModifierExceptionBypass()
        InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass()
        InitializeNetworkPacketBlock()
        InitializeHiggsBosonBypass()
        InitializeAntiCheatHooks()
        InitializeAntiReport()
        InitializeGameplayBypass()
        InitializeKillAllSubsystems()
        InitializeFinalProtection()
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end


-- =========================== PHẦN 33: ANTI-BAN ULTIMATE ===========================

-- [33A] IDIP Ban Notice Interceptor — chặn thông báo ban từ server IDIP
local function InitializeIDIPBanBypass()
    pcall(function()
        -- Block module IDIP
        local idipPaths = {
            "GameLua.Mod.BaseMod.Client.Security.IDIPBanSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.IDIPBanSubsystem",
            "GameLua.Mod.BaseMod.Common.Security.IDIPBan",
            "client.slua.logic.ban.logic_ban_notice",
            "client.slua.logic.ban.logic_idip_ban",
        }
        for _, path in ipairs(idipPaths) do
            local mod = package.loaded[path]
            if mod then
                for k, v in pairs(mod) do
                    if type(v) == "function" then
                        mod[k] = function() return false end
                    end
                end
            end
        end
        -- Null GameplayCallbacks ban
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            local banKeys = {
                "OnReceiveBanInfo","OnIDIPBanNotice","OnReceiveIDIPResult",
                "OnPlayerBanNotice","OnBanResult","OnAntiCheatBan",
                "OnPunishNotice","OnPunishResult","HandleBanNotice",
                "OnGameSafePunish","OnTSSBan","OnKickByBan",
                "OnServerBanPlayer","OnBanKick","OnForceKick",
            }
            for _, k in ipairs(banKeys) do
                if GC[k] then GC[k] = function() end end
            end
        end
        -- Block ClientSecuritySubsystem ban handler
        local ClientSecSub = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientSecuritySubsystem"]
        if ClientSecSub then
            if ClientSecSub.HandleBanNotice    then ClientSecSub.HandleBanNotice    = function() end end
            if ClientSecSub.OnReceiveBanInfo   then ClientSecSub.OnReceiveBanInfo   = function() end end
            if ClientSecSub.OnIDIPBan          then ClientSecSub.OnIDIPBan          = function() end end
            if ClientSecSub.OnForceKick        then ClientSecSub.OnForceKick        = function() end end
        end
    end)
end

-- [33B] Punishment Callback Null — vô hiệu hóa toàn bộ chuỗi trừng phạt
local function InitializePunishmentBypass()
    pcall(function()
        -- Subsystem: PunishmentSubsystem
        local ok, SubsystemMgr = pcall(require, "GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if ok and SubsystemMgr then
            local punishNames = {
                "PunishmentSubsystem","AntiCheatPunishSubsystem","ClientPunishSubsystem",
                "GameSafePunishSubsystem","IDIPBanSubsystem","ClientBanSubsystem",
                "DSBanSubsystem","BanCheckSubsystem","ClientKickSubsystem",
                "AbnormalBehaviorSubsystem","ReportPlayerPunishSubsystem",
            }
            for _, name in ipairs(punishNames) do
                local sub = SubsystemMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" then sub[k] = function() return false end end
                    end
                end
            end
        end
        -- BanCheckResult luôn trả về safe
        if _G.BanCheckResult ~= nil then
            _G.BanCheckResult = 0  -- 0 = not banned
        end
        -- Fake hàm check ban toàn cục
        _G.CheckBanResult   = function() return false end
        _G.IsBanned         = function() return false end
        _G.IsIDIPBanned     = function() return false end
        _G.IsPunished       = function() return false end
        _G.GetBanReason     = function() return "" end
        _G.GetPunishLevel   = function() return 0 end
    end)
end

-- [33C] Player State Clamp — ngăn server ghi đè trạng thái "banned"/"kicked"
local function InitializePlayerStateBanClamp()
    pcall(function()
        if not _G.GameplayCallbacks then return end
        local GC = _G.GameplayCallbacks
        -- Hook OnDSPlayerStateChanged (đã có nhưng bổ sung thêm filter)
        if not GC._AntiBanPlayerStateHooked then
            local originalFn = GC.OnDSPlayerStateChanged
            GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
                local stateStr = InPlayerState and string.lower(tostring(InPlayerState)) or ""
                -- Danh sách trạng thái ban cần chặn
                local banStates = {
                    "banned","idipban","kick","punish","anticheat",
                    "cheatdetect","hackdetect","violation","modding",
                    "wallhack","aimbot","speedhack","memoryhack",
                    "suspended","accountban","gamebanned","forcedisconnect",
                }
                for _, s in ipairs(banStates) do
                    if string.find(stateStr, s, 1, true) then
                        print("[ANTIBAN] Blocked PlayerStateChange: " .. stateStr)
                        return
                    end
                end
                if originalFn then
                    pcall(originalFn, UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
                end
            end
            GC._AntiBanPlayerStateHooked = true
        end
        -- Block DSPlayerKick
        if GC.OnDSKickPlayer        then GC.OnDSKickPlayer        = function() end end
        if GC.OnServerKickPlayer    then GC.OnServerKickPlayer    = function() end end
        if GC.OnKickByAntiCheat     then GC.OnKickByAntiCheat     = function() end end
        if GC.OnForceDisconnect     then GC.OnForceDisconnect     = function() end end
    end)
end

-- [33D] Kill Flow Integrity — chặn RPC gửi kill data bất thường
local function InitializeKillFlowIntegrityBypass()
    pcall(function()
        if not _G.GameplayCallbacks then return end
        local GC = _G.GameplayCallbacks
        -- Null các hàm ghi log kill bất thường
        local killLogKeys = {
            "ReportKillFlow","ReportPlayerKillFlow","ReportMLKillerUID",
            "ReportKnockDownFlow","ReportBattleResultKill",
            "SendKillFlowToServer","OnSuspiciousKillDetected",
            "OnAbnormalKillReport","CheckKillIntegrity",
        }
        for _, k in ipairs(killLogKeys) do
            if GC[k] then GC[k] = function() end end
        end
        -- Block NetUtil packet kill-flow
        if NetUtil and NetUtil.SendPacket and not NetUtil._KFBypassed then
            local origSP = NetUtil.SendPacket
            NetUtil.SendPacket = function(firstArg, secondArg, ...)
                local pn = type(firstArg)=="string" and firstArg or secondArg
                if pn and (string.find(tostring(pn),"KillFlow",1,true)
                    or string.find(tostring(pn),"SuspiciousKill",1,true)
                    or string.find(tostring(pn),"AbnormalKill",1,true)) then
                    return
                end
                return origSP(firstArg, secondArg, ...)
            end
            NetUtil._KFBypassed = true
        end
    end)
end

-- [33E] Chat / Social Report Block — chặn tố cáo qua chat và hệ thống social
local function InitializeChatReportBypass()
    pcall(function()
        -- Block module report chat
        local chatReportPaths = {
            "client.slua.logic.report.ChatReportModule",
            "client.slua.logic.report.SocialReportModule",
            "client.slua.logic.report.ReportPlayerModule",
            "GameLua.Mod.BaseMod.Client.Social.SocialReportSubsystem",
        }
        for _, path in ipairs(chatReportPaths) do
            local mod = package.loaded[path]
            if mod then
                for k, v in pairs(mod) do
                    if type(v) == "function" then
                        local lk = string.lower(k)
                        if string.find(lk,"report",1,true) or string.find(lk,"submit",1,true)
                        or string.find(lk,"send",1,true) or string.find(lk,"upload",1,true) then
                            mod[k] = function() return true end
                        end
                    end
                end
            end
        end
        -- Block RPC gửi report qua GameplayCallbacks
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            local reportRPCKeys = {
                "RPC_Server_ReportPlayer","RPC_Client_ReportResult",
                "SendPlayerReport","SubmitChatReport","OnReportConfirmed",
                "OnPlayerReportResult","SendReportToServer",
            }
            for _, k in ipairs(reportRPCKeys) do
                if GC[k] then GC[k] = function() end end
            end
        end
    end)
end

-- [33F] Lobby Ban Check Bypass — giả mạo kết quả kiểm tra ban trong sảnh
local function InitializeLobbyBanCheckBypass()
    pcall(function()
        local lobbyBanPaths = {
            "client.slua.logic.ban.logic_ban_check",
            "client.slua.logic.lobby.logic_lobby_ban",
            "client.slua.logic.main.logic_main_ban_check",
        }
        for _, path in ipairs(lobbyBanPaths) do
            local mod = package.loaded[path]
            if mod then
                if mod.CheckBan        then mod.CheckBan        = function() return false end end
                if mod.IsBanned        then mod.IsBanned        = function() return false end end
                if mod.GetBanInfo      then mod.GetBanInfo      = function() return nil end end
                if mod.ShowBanNotice   then mod.ShowBanNotice   = function() end end
                if mod.OnBanCheck      then mod.OnBanCheck      = function() return false end end
                if mod.RequestBanCheck then mod.RequestBanCheck = function() end end
            end
        end
        -- Fake lobby state không bị ban
        local LobbyData = package.loaded["client.logic.data.data_lobby"]
        if LobbyData then
            if LobbyData.bIsBanned ~= nil then LobbyData.bIsBanned = false end
            if LobbyData.nBanType  ~= nil then LobbyData.nBanType  = 0     end
            if LobbyData.nBanLevel ~= nil then LobbyData.nBanLevel = 0     end
        end
    end)
end

-- [33G] Anti-Ban Network Packet Block — chặn packet ban/kick tại tầng NetUtil
local function InitializeAntiBanPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket and not NetUtil._ABPBypassed then
            local origSP = NetUtil.SendPacket
            local banPackets = {
                ["idip_ban_report"]=1, ["ban_player"]=1, ["kick_player"]=1,
                ["punish_player"]=1,   ["punish_notify"]=1, ["ban_notify"]=1,
                ["report_ban_result"]=1, ["anticheat_ban"]=1, ["cheat_ban"]=1,
                ["account_ban_notify"]=1, ["game_ban_notify"]=1,
                ["force_kick"]=1, ["server_kick_player"]=1,
                ["ban_check_result"]=1, ["punishment_result"]=1,
            }
            NetUtil.SendPacket = function(firstArg, secondArg, ...)
                local pn = type(firstArg)=="string" and firstArg or secondArg
                if pn and banPackets[tostring(pn)] then
                    print("[ANTIBAN-PKT] Blocked: " .. tostring(pn))
                    return
                end
                return origSP(firstArg, secondArg, ...)
            end
            NetUtil._ABPBypassed = true
        end
    end)
end

-- [33H] Auto-Recovery Loop — tự động tái áp dụng anti-ban mỗi 15 giây
local function StartAntiBanRecoveryLoop()
    if _G.AntiBanLoopActive then return end
    _G.AntiBanLoopActive = true
    local function AntiBanLoop()
        pcall(InitializeIDIPBanBypass)
        pcall(InitializePunishmentBypass)
        pcall(InitializePlayerStateBanClamp)
        pcall(InitializeKillFlowIntegrityBypass)
        pcall(InitializeChatReportBypass)
        pcall(InitializeLobbyBanCheckBypass)
        pcall(InitializeAntiBanPacketBlock)
        pcall(function() if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end end)
        -- Re-null TssSdk ban reporters
        pcall(function()
            local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
            if TssSdk then
                if TssSdk.QueryUserRisk   then TssSdk.QueryUserRisk   = function() return 0 end end
                if TssSdk.GetDeviceRisk   then TssSdk.GetDeviceRisk   = function() return 0 end end
                if TssSdk.ReportCheatData then TssSdk.ReportCheatData = function() end end
                if TssSdk.IsRooted        then TssSdk.IsRooted        = function() return false end end
                if TssSdk.IsEmulator      then TssSdk.IsEmulator      = function() return false end end
                if TssSdk.IsDebugged      then TssSdk.IsDebugged      = function() return false end end
            end
        end)
        pcall(function()
            if _G.X3 and _G.X3.Bypass and _G.X3.Bypass.SelfHeal then
                _G.X3.Bypass.SelfHeal()
            end
        end)
        pcall(function()
            local ok, ticker = pcall(require, "common.time_ticker")
            if ok and ticker and ticker.AddTimerOnce then
                ticker.AddTimerOnce(15.0, AntiBanLoop)
            end
        end)
    end
    pcall(function()
        local ok, ticker = pcall(require, "common.time_ticker")
        if ok and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(5.0, AntiBanLoop)
        end
    end)
end

-- ====================================================================================
-- PHẦN 34: X3 BYPASS ENGINE v8.0 (JAILBREAK / ROOT / GIẢ LẬP / INJECTION / PTRACE BYPASS)
-- Tích hợp từ: jailbreakdetct.lua
-- Hỗ trợ: Cross-Platform (Android + iOS) | Kernel | MemoryGuard | TSS SDK | Frida | Substrate
-- ====================================================================================
_G.X3 = _G.X3 or {}
_G.X3.Bypass = _G.X3.Bypass or {
    -- Trạng thái nạp patch các phân vùng
    ACTIVE = false,
    KernelPatched = false,
    MemoryGuardPatched = false,
    TssPatched = false,
    AntiCheatPatched = false,
    IntegrityPatched = false,
    RootPatched = false,
    EmulatorPatched = false,
    JailbreakPatched = false,
    IpaPatched = false,
    FridaPatched = false,
    PtracePatched = false,
    SyscallPatched = false,
    SandboxPatched = false,

    -- Chỉ số thử nghiệm & đếm
    PatchAttempts = 0,
    LastPatchTime = 0,
    RetryCount = 0,
    MaxRetries = 5,

    -- Danh sách cấu hình iOS
    IosChecks = {},
    IosPaths = {},
    IosSchemes = {},

    -- Danh sách cấu hình Android
    AndroidChecks = {},

    -- Tự động tự chữa lành (Self-Heal)
    AutoHeal = true,
    HealInterval = 10.0,
    LastHeal = 0,
}

local B34 = _G.X3.Bypass

-- [34.0] Bitwise 32-bit Fallback Helper (Hỗ trợ toán tử bit32 cho môi trường Lua thiếu thư viện)
if not bit32 then
    bit32 = {
        lshift = function(a, b) return a * (2^b) end,
        band = function(a, b)
            local r, p = 0, 1
            for i = 0, 31 do
                if a % 2 == 1 and b % 2 == 1 then r = r + p end
                a, b = math.floor(a / 2), math.floor(b / 2)
                p = p * 2
            end
            return r
        end,
        bor = function(a, b)
            local r, p = 0, 1
            for i = 0, 31 do
                if a % 2 == 1 or b % 2 == 1 then r = r + p end
                a, b = math.floor(a / 2), math.floor(b / 2)
                p = p * 2
            end
            return r
        end,
        bnot = function(a) return 4294967295 - a end,
        bxor = function(a, b)
            local r, p = 0, 1
            for i = 0, 31 do
                if (a % 2) ~= (b % 2) then r = r + p end
                a, b = math.floor(a / 2), math.floor(b / 2)
                p = p * 2
            end
            return r
        end
    }
end

-- [34.1] Safe Module Require & Platform Detection (Phát hiện hệ điều hành Android / iOS)
local function X3_SafeRequire(path)
    local ok, mod = pcall(function() return require(path) end)
    if ok and mod then return mod end
    local parts = {}
    for part in path:gmatch("[^%.]+") do table.insert(parts, part) end
    local cur = _G
    for _, p in ipairs(parts) do
        cur = cur[p]
        if not cur then return nil end
    end
    return cur
end

function B34.DetectPlatform()
    local platform = "unknown"
    pcall(function()
        if _G.UE4Runtime and _G.UE4Runtime.GetPlatformName then
            platform = _G.UE4Runtime.GetPlatformName()
        elseif _G.ANDROID_VERSION then
            platform = "Android"
        elseif _G.IOS_VERSION or _G.UIDevice then
            platform = "iOS"
        end
    end)
    if platform == "unknown" then
        pcall(function()
            local app = _G.Java and _G.Java.android and _G.Java.android.content and _G.Java.android.content.Context
            if app then platform = "Android" end
        end)
    end
    return platform
end

function B34.IsIOS() return B34.DetectPlatform() == "iOS" end
function B34.IsAndroid() return B34.DetectPlatform() == "Android" end

-- [34.2] LAYER 1: Kernel Check Bypass (Bypass hệ thống kiểm tra Kernel trên Android & iOS)
function B34.PatchKernelCheck()
    if B34.KernelPatched then return true end
    local ok = false
    pcall(function()
        local subsystems = X3_SafeRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems and subsystems.Get then
            local kernel = subsystems:Get("ClientKernelCheckSubsystem")
            if kernel then
                kernel.IsKernelClean = function() return true end
                kernel.GetKernelVersion = function() return "4.19.113-perf+" end
                kernel.IsBootloaderLocked = function() return true end
                kernel.CheckKernelIntegrity = function() return true, {status="clean", code=0} end
                kernel.VerifyKernelSignature = function() return true end
                kernel.IsKernelModified = function() return false end
                kernel.GetKernelHash = function() return "official" end
                ok = true
            end
        end
        local iosKernel = X3_SafeRequire("GameLua.GameCore.Module.Subsystem.iOSKernelSubsystem")
        if iosKernel then
            iosKernel.IsKernelPatched = function() return false end
            iosKernel.CheckKernelExploit = function() return false, "none" end
            iosKernel.GetKernelSlide = function() return 0 end
            iosKernel.IsKASLRBypassed = function() return false end
            ok = true
        end
    end)
    B34.KernelPatched = ok
    return ok
end

-- [34.3] LAYER 2: Memory Guard Bypass (Bypass hệ thống quét bộ nhớ động Memory Guard)
function B34.PatchMemoryGuard()
    if B34.MemoryGuardPatched then return true end
    local ok = false
    pcall(function()
        local subsystems = X3_SafeRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems and subsystems.Get then
            local mg = subsystems:Get("ClientMemoryGuardSubsystem")
            if mg then
                mg.IsMemoryClean = function() return true, {code=0, detail="no_anomaly"} end
                mg.ScanResult = function() return "clean", 0 end
                mg.GetMemoryReport = function() return {status="clean", regions=0, anomalies={}} end
                mg.PerformDeepScan = function() return true, "clean" end
                mg.CheckMemoryRegion = function() return true end
                mg.DetectHook = function() return false, {} end
                mg.GetHookList = function() return {} end
                ok = true
            end
        end
    end)
    B34.MemoryGuardPatched = ok
    return ok
end

-- [34.4] LAYER 3: TSS SDK Bypass (Giả lập phản hồi an toàn cho Tencent Security Service SDK)
function B34.PatchTssSdk()
    if B34.TssPatched then return true end
    local ok = false
    pcall(function()
        _G.TssSdk = _G.TssSdk or {}
        local T = _G.TssSdk
        T.CheckKernel = function() return true, {status="verified", tampered=false, code=0} end
        T.VerifyBoot = function() return true, {locked=true, verified=true, bootloader="locked"} end
        T.CheckMemory = function() return true, {clean=true, modified=false} end
        T.GetSecurityLevel = function() return 3, "high" end
        T.ReportStatus = function() return {safe=true, threat=0} end
        T.AntiCheatCheck = function() return true, "pass" end
        T.CheckSignature = function() return true, {valid=true, signer="official"} end
        T.GetDeviceRisk = function() return 0, "low" end
        T.CheckEnvironment = function() return true, {emulator=false, root=false, jailbreak=false} end
        T.ReportBehavior = function() return true end
        ok = true
    end)
    B34.TssPatched = ok
    return ok
end

-- [34.5] LAYER 4: Anti-Cheat Subsystem Bypass (Vô hiệu hóa kiểm tra hack/cheat của game & GameGuard)
function B34.PatchAntiCheat()
    if B34.AntiCheatPatched then return true end
    local ok = false
    pcall(function()
        local subsystems = X3_SafeRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems and subsystems.Get then
            local ac = subsystems:Get("ClientAntiCheatSubsystem")
            if ac then
                ac.IsCheating = function() return false end
                ac.GetThreatLevel = function() return 0, "none" end
                ac.ReportViolation = function() return true end
                ac.ScanProcess = function() return {clean=true, hooks=0, injects=0} end
                ac.DetectSpeedHack = function() return false, 1.0 end
                ac.DetectFlyHack = function() return false end
                ac.DetectWallHack = function() return false end
                ac.DetectAimBot = function() return false end
                ac.GetBehaviorScore = function() return 0, "normal" end
                ok = true
            end
        end
        local gg = _G.GameGuard or _G.GameGuardian
        if gg then
            gg.Check = function() return false end
            gg.Detect = function() return false, {} end
            ok = true
        end
    end)
    B34.AntiCheatPatched = ok
    return ok
end

-- [34.6] LAYER 5: Integrity Check Bypass (Bypass kiểm tra tính toàn vẹn code & chữ ký ứng dụng)
function B34.PatchIntegrity()
    if B34.IntegrityPatched then return true end
    local ok = false
    pcall(function()
        local subsystems = X3_SafeRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems and subsystems.Get then
            local ic = subsystems:Get("ClientIntegrityCheckSubsystem")
            if ic then
                ic.VerifyFile = function() return true, {hash_match=true} end
                ic.CheckTamper = function() return false, "clean" end
                ic.GetFileStatus = function() return "verified", 0 end
                ic.VerifySignature = function() return true, {valid=true} end
                ic.CheckCodeIntegrity = function() return true end
                ic.GetCodeHash = function() return "official" end
                ok = true
            end
        end
        local cs = _G.CodeSigning or _G.CodeSign
        if cs then
            cs.Verify = function() return true end
            cs.CheckSignature = function() return true, {valid=true} end
            cs.IsEnterpriseSigned = function() return false end
            cs.IsSideloaded = function() return false end
            ok = true
        end
    end)
    B34.IntegrityPatched = ok
    return ok
end

-- [34.7] LAYER 6: Root & Jailbreak Detection Bypass (Ẩn các tiến trình Root, Magisk, su, Cydia, Sileo)
function B34.PatchRootJailbreak()
    if B34.RootPatched and B34.JailbreakPatched then return true end
    local ok = false
    pcall(function()
        local subsystems = X3_SafeRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems and subsystems.Get then
            local root = subsystems:Get("ClientRootDetectionSubsystem")
            if root then
                root.IsRooted = function() return false end
                root.HasSuperuser = function() return false end
                root.CheckMagisk = function() return false end
                root.CheckBusybox = function() return false end
                root.CheckSuBinary = function() return false end
                root.CheckRootApps = function() return {} end
                root.GetRootMethod = function() return "none" end
                B34.RootPatched = true
                ok = true
            end
            local jb = subsystems:Get("ClientJailbreakDetectionSubsystem")
            if jb then
                jb.IsJailbroken = function() return false end
                jb.CheckJailbreakApps = function() return {} end
                jb.CheckJailbreakFiles = function() return {} end
                jb.CheckJailbreakSchemes = function() return {} end
                jb.GetJailbreakTool = function() return "none" end
                jb.CheckSubstitute = function() return false end
                jb.CheckSubstrate = function() return false end
                jb.CheckLibhooker = function() return false end
                B34.JailbreakPatched = true
                ok = true
            end
        end
        local iosJb = _G.JailbreakDetection or _G.JBDetect
        if iosJb then
            iosJb.IsJailbroken = function() return false end
            iosJb.Detect = function() return false, {} end
            B34.JailbreakPatched = true
            ok = true
        end
    end)
    return ok
end

-- [34.8] LAYER 7: Emulator Detection Bypass (Bypass phát hiện các trình giả lập Android phổ biến)
function B34.PatchEmulator()
    if B34.EmulatorPatched then return true end
    local ok = false
    pcall(function()
        local subsystems = X3_SafeRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if subsystems and subsystems.Get then
            local emu = subsystems:Get("ClientEmulatorDetectionSubsystem")
            if emu then
                emu.IsEmulator = function() return false end
                emu.GetEmulatorType = function() return "none" end
                emu.CheckBlueStacks = function() return false end
                emu.CheckLDPlayer = function() return false end
                emu.CheckMemu = function() return false end
                emu.CheckNox = function() return false end
                emu.CheckGameloop = function() return false end
                emu.CheckGenymotion = function() return false end
                emu.GetDeviceProfile = function() return "physical", {} end
                ok = true
            end
        end
    end)
    B34.EmulatorPatched = ok
    return ok
end

-- [34.9] LAYER 8: iOS Jailbreak Path & Scheme Deep Bypass (Che giấu file/đường dẫn Jailbreak trên iOS)
function B34.PatchIOSDeep()
    if B34.IosChecks.patched then return true end
    local ok = false
    pcall(function()
        B34.IosPaths = {
            "/Applications/Cydia.app", "/Applications/Sileo.app", "/Applications/Zebra.app", "/Applications/Installer.app",
            "/usr/sbin/sshd", "/usr/bin/sshd", "/etc/apt", "/var/lib/apt", "/var/lib/cydia", "/var/cache/apt", "/var/tmp/cydia",
            "/bin/bash", "/bin/sh", "/usr/bin/which", "/usr/bin/passwd", "/private/var/lib/apt", "/private/var/lib/cydia",
            "/private/var/mobile/Library/Sileo", "/private/var/stash", "/private/var/db/stash", "/private/var/mobile/Library/Cydia",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist", "/System/Library/LaunchDaemons/com.openssh.sshd.plist",
            "/usr/libexec/ssh-keysign", "/usr/libexec/sftp-server", "/usr/lib/substrate", "/usr/lib/TweakInject", "/usr/lib/tweaks",
            "/usr/lib/libsubstrate.dylib", "/usr/lib/libsubstitute.dylib", "/usr/lib/libhooker.dylib", "/usr/lib/libblackjack.dylib",
            "/usr/lib/libjailbreak.dylib", "/var/jb", "/var/jb/usr/bin", "/var/jb/etc/apt", "/private/preboot/jb",
        }

        B34.IosSchemes = {
            "cydia://", "sileo://", "zbra://", "filza://",
            "activator://", "prefs://", "sbsettings://",
        }

        if _G.io and _G.io.open then
            local orig_open = _G.io.open
            _G.io.open = function(path, mode)
                if path then
                    local p = tostring(path)
                    for _, jp in ipairs(B34.IosPaths) do
                        if p:find(jp, 1, true) then return nil, "No such file" end
                    end
                end
                return orig_open(path, mode)
            end
        end

        if _G.lfs then
            if _G.lfs.attributes then
                local orig_attr = _G.lfs.attributes
                _G.lfs.attributes = function(path, ...)
                    if path then
                        for _, jp in ipairs(B34.IosPaths) do
                            if tostring(path):find(jp, 1, true) then return nil end
                        end
                    end
                    return orig_attr(path, ...)
                end
            end
            if _G.lfs.dir then
                local orig_dir = _G.lfs.dir
                _G.lfs.dir = function(path)
                    if path then
                        for _, jp in ipairs(B34.IosPaths) do
                            if tostring(path):find(jp, 1, true) then
                                return function() return nil end
                            end
                        end
                    end
                    return orig_dir(path)
                end
            end
        end

        local fm = _G.NSFileManager or _G.FileManager
        if fm then
            fm.fileExistsAtPath = function() return false end
            fm.contentsOfDirectoryAtPath = function() return nil, {} end
        end

        local app = _G.UIApplication or _G.UIApplicationSharedApplication
        if app then
            app.canOpenURL = function() return false end
        end

        B34.IosChecks.patched = true
        ok = true
    end)
    return ok
end

-- [34.10] LAYER 9: IPA / Sideload / Enterprise Sign Bypass (Che giấu ứng dụng sideload & cài đặt qua cert)
function B34.PatchIpaSideload()
    if B34.IpaPatched then return true end
    local ok = false
    pcall(function()
        local bundle = _G.NSBundle or _G.Bundle
        if bundle then
            bundle.bundleIdentifier = function() return "com.tencent.ig" end
            bundle.isEnterprise = function() return false end
            bundle.isSideloaded = function() return false end
            bundle.appStoreReceiptURL = function() return nil end
        end

        local prov = _G.ProvisioningProfile or _G.MobileProvision
        if prov then
            prov.Read = function() return nil end
            prov.Exists = function() return false end
            prov.IsEnterprise = function() return false end
            prov.IsDeveloper = function() return false end
        end

        local sign = _G.CodeSigning or _G.SecCode
        if sign then
            sign.CheckValidity = function() return true end
            sign.GetTeamIdentifier = function() return "official" end
            sign.IsAdHocSigned = function() return false end
            sign.IsAppStoreSigned = function() return true end
            sign.IsEnterpriseSigned = function() return false end
        end

        local dyld = _G.dyld or _G._dyld
        if dyld then
            local orig = dyld.image_count or dyld.get_image_count
            if orig then
                dyld.image_count = function() return orig() end
            end
            dyld.get_image_name = function(idx)
                local name = orig and orig(idx)
                if name then
                    local hide = {"substrate", "substitute", "libhooker", "tweak", "inject", "frida", "gadget"}
                    for _, h in ipairs(hide) do
                        if name:lower():find(h) then return "/usr/lib/system/libsystem_c.dylib" end
                    end
                end
                return name
            end
        end

        local ent = _G.Entitlements or _G.SecTask
        if ent then
            ent.CopyValue = function() return nil end
            ent.Get = function() return {} end
        end

        B34.IpaPatched = true
        ok = true
    end)
    return ok
end

-- [34.11] LAYER 10: Frida / Substrate / Xposed Injection Bypass (Che giấu công cụ can thiệp bộ nhớ nạp động)
function B34.PatchInjectionDetection()
    if B34.FridaPatched then return true end
    local ok = false
    pcall(function()
        local frida = _G.FridaDetect or _G.Frida
        if frida then
            frida.Check = function() return false end
            frida.Detect = function() return false, {} end
            frida.IsAttached = function() return false end
            frida.GetProcesses = function() return {} end
        end

        local sub = _G.Substrate or _G.CydiaSubstrate
        if sub then
            sub.IsLoaded = function() return false end
            sub.GetHooks = function() return {} end
        end

        local xposed = _G.XposedBridge or _G.XposedHelpers
        if xposed then
            xposed.IsHooked = function() return false end
            xposed.GetHookList = function() return {} end
        end

        local lib = _G.LibraryLoader or _G.DLopen
        if lib then
            local orig = lib.dlopen or lib.open
            if orig then
                lib.dlopen = function(path, ...)
                    if path then
                        local p = tostring(path):lower()
                        local bad = {"frida", "substrate", "xposed", "inject", "hook", "tweak", "gadget"}
                        for _, b in ipairs(bad) do
                            if p:find(b) then return nil end
                        end
                    end
                    return orig(path, ...)
                end
            end
        end

        if _G.readprocmaps then
            local orig = _G.readprocmaps
            _G.readprocmaps = function(...)
                local result = orig(...)
                if type(result) == "string" then
                    local bad = {"xposed", "magisk", "frida", "substrate", "edxposed", "lsposed"}
                    for _, b in ipairs(bad) do
                        result = result:gsub("[^\r\n]*" .. b .. "[^\r\n]*[\r\n]*", "")
                    end
                end
                return result
            end
        end

        if _G._dyld and _G._dyld.get_image_name then
            local orig = _G._dyld.get_image_name
            _G._dyld.get_image_name = function(idx)
                local name = orig(idx)
                if name then
                    local bad = {"substrate", "substitute", "libhooker", "tweakinject", "frida", "gadget"}
                    for _, b in ipairs(bad) do
                        if name:lower():find(b) then return "/usr/lib/system/libsystem_kernel.dylib" end
                    end
                end
                return name
            end
        end

        B34.FridaPatched = true
        ok = true
    end)
    return ok
end

-- [34.12] LAYER 11: Ptrace / Syscall / Anti-Debug Bypass (Vô hiệu hóa theo dõi gỡ lỗi anti-debug)
function B34.PatchPtraceSyscall()
    if B34.PtracePatched and B34.SyscallPatched then return true end
    local ok = false
    pcall(function()
        if _G.ptrace then
            _G.ptrace.check = function() return false end
            _G.ptrace.request = function(request, ...)
                if request == 0 or request == 1 then return 0 end
                return -1
            end
        end

        if _G.syscall then
            local orig = _G.syscall
            _G.syscall = function(number, ...)
                local antiDebug = {26, 101, 0x1A}
                for _, ad in ipairs(antiDebug) do
                    if number == ad then return 0 end
                end
                return orig(number, ...)
            end
        end

        local sysctl = _G.sysctl or _G.Sysctl
        if sysctl then
            sysctl.Read = function(name)
                if name and name:find("kern", 1, true) then
                    return {ostype = "Darwin", osrelease = "22.0.0"}
                end
                return nil
            end
        end

        if _G.IsDebuggerPresent then _G.IsDebuggerPresent = function() return false end end
        if _G.CheckRemoteDebuggerPresent then _G.CheckRemoteDebuggerPresent = function() return false end end
        if _G.isatty then _G.isatty = function() return 0 end end

        B34.PtracePatched = true
        B34.SyscallPatched = true
        ok = true
    end)
    return ok
end

-- [34.13] LAYER 12: Sandbox & SELinux Access Bypass (Bypass cơ chế cách ly ứng dụng Sandbox & SELinux)
function B34.PatchSandbox()
    if B34.SandboxPatched then return true end
    local ok = false
    pcall(function()
        local sb = _G.Sandbox or _G.SandboxCheck
        if sb then
            sb.IsSandboxed = function() return true end
            sb.CheckAccess = function() return true end
            sb.CanAccessPath = function() return true end
        end

        local ats = _G.NSAppTransportSecurity or _G.ATS
        if ats then
            ats.AllowsArbitraryLoads = true
        end

        local se = _G.SELinux or _G.SELinuxCheck
        if se then
            se.IsEnforcing = function() return true end
            se.GetContext = function() return "u:r:untrusted_app:s0" end
            se.CheckAccess = function() return true end
        end

        B34.SandboxPatched = true
        ok = true
    end)
    return ok
end

-- [34.14] Smart Self-Heal & Auto Recovery (Tự động phục hồi trạng thái patch khi bị nạp lại)
function B34.SelfHeal()
    if not B34.AutoHeal then return end
    local now = os.clock and os.clock() or 0
    if (now - B34.LastHeal) < B34.HealInterval then return end
    B34.LastHeal = now

    if not B34.KernelPatched then B34.PatchKernelCheck() end
    if not B34.MemoryGuardPatched then B34.PatchMemoryGuard() end
    if not B34.TssPatched then B34.PatchTssSdk() end
    if not B34.AntiCheatPatched then B34.PatchAntiCheat() end
    if not B34.IntegrityPatched then B34.PatchIntegrity() end
    if not B34.RootPatched or not B34.JailbreakPatched then B34.PatchRootJailbreak() end
    if not B34.EmulatorPatched then B34.PatchEmulator() end
    if not B34.IosChecks.patched then B34.PatchIOSDeep() end
    if not B34.IpaPatched then B34.PatchIpaSideload() end
    if not B34.FridaPatched then B34.PatchInjectionDetection() end
    if not B34.PtracePatched or not B34.SyscallPatched then B34.PatchPtraceSyscall() end
    if not B34.SandboxPatched then B34.PatchSandbox() end
end

function B34.HealTick()
    B34.SelfHeal()
end

-- [34.15] Master Apply All & Status Report (Kích hoạt toàn bộ 13 lớp bypass)
function B34.ApplyAll()
    if B34.ACTIVE and B34.PatchAttempts >= B34.MaxRetries then return true end

    B34.PatchAttempts = B34.PatchAttempts + 1
    B34.LastPatchTime = os.clock and os.clock() or 0

    local results = {}
    local order = {
        {"Kernel", B34.PatchKernelCheck},
        {"MemoryGuard", B34.PatchMemoryGuard},
        {"TSS", B34.PatchTssSdk},
        {"AntiCheat", B34.PatchAntiCheat},
        {"Integrity", B34.PatchIntegrity},
        {"RootJailbreak", B34.PatchRootJailbreak},
        {"Emulator", B34.PatchEmulator},
        {"IOSDeep", B34.PatchIOSDeep},
        {"IpaSideload", B34.PatchIpaSideload},
        {"Injection", B34.PatchInjectionDetection},
        {"PtraceSyscall", B34.PatchPtraceSyscall},
        {"Sandbox", B34.PatchSandbox},
    }

    for _, entry in ipairs(order) do
        local name, fn = entry[1], entry[2]
        local ok = fn()
        results[name] = ok
    end

    local critical = results.Kernel or results.MemoryGuard or results.TSS or results.AntiCheat
    if critical then
        B34.ACTIVE = true
    end

    return B34.ACTIVE, results
end

function B34.GetStatus()
    return {
        Active = B34.ACTIVE,
        Platform = B34.DetectPlatform(),
        Kernel = B34.KernelPatched,
        MemoryGuard = B34.MemoryGuardPatched,
        Tss = B34.TssPatched,
        AntiCheat = B34.AntiCheatPatched,
        Integrity = B34.IntegrityPatched,
        Root = B34.RootPatched,
        Jailbreak = B34.JailbreakPatched,
        Emulator = B34.EmulatorPatched,
        IosDeep = B34.IosChecks.patched or false,
        IpaSideload = B34.IpaPatched,
        Injection = B34.FridaPatched,
        Ptrace = B34.PtracePatched,
        Syscall = B34.SyscallPatched,
        Sandbox = B34.SandboxPatched,
        Attempts = B34.PatchAttempts,
        LastPatch = B34.LastPatchTime,
    }
end

function B34.PrintStatus()
    local s = B34.GetStatus()
    print("[X3BP] ===== BYPASS STATUS =====")
    print("[X3BP] Platform:     " .. s.Platform)
    print("[X3BP] Active:       " .. tostring(s.Active))
    print("[X3BP] Kernel:       " .. tostring(s.Kernel))
    print("[X3BP] MemoryGuard:  " .. tostring(s.MemoryGuard))
    print("[X3BP] TSS:          " .. tostring(s.Tss))
    print("[X3BP] AntiCheat:    " .. tostring(s.AntiCheat))
    print("[X3BP] Integrity:    " .. tostring(s.Integrity))
    print("[X3BP] Root:         " .. tostring(s.Root))
    print("[X3BP] Jailbreak:    " .. tostring(s.Jailbreak))
    print("[X3BP] Emulator:     " .. tostring(s.Emulator))
    print("[X3BP] iOS Deep:     " .. tostring(s.IosDeep))
    print("[X3BP] IPA/Sideload: " .. tostring(s.IpaSideload))
    print("[X3BP] Injection:    " .. tostring(s.Injection))
    print("[X3BP] Ptrace:       " .. tostring(s.Ptrace))
    print("[X3BP] Syscall:      " .. tostring(s.Syscall))
    print("[X3BP] Sandbox:      " .. tostring(s.Sandbox))
    print("[X3BP] Attempts:     " .. s.Attempts)
    print("[X3BP] =========================")
end

-- Khởi động tất cả anti-ban ngay lập tức
pcall(InitializeIDIPBanBypass)
pcall(InitializePunishmentBypass)
pcall(InitializePlayerStateBanClamp)
pcall(InitializeKillFlowIntegrityBypass)
pcall(InitializeChatReportBypass)
pcall(InitializeLobbyBanCheckBypass)
pcall(InitializeAntiBanPacketBlock)
pcall(function() B34.ApplyAll() end)
pcall(function() if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end end)
pcall(StartAntiBanRecoveryLoop)

-- =========================== PHẦN 32: INJECT TO ORIGINAL CLASS ===========================
-- Sao chép tất cả các phương thức mod sang OriginalClass để game nhận diện động
pcall(function()
    if OriginalClass and OriginalClass ~= BRPlayerCharacterBase then
        for k, v in pairs(BRPlayerCharacterBase) do
            if type(v) == "function" then
                OriginalClass[k] = v
            elseif k == "ServerRPC" or k == "ClientRPC" or k == "MulticastRPC" then
                OriginalClass[k] = OriginalClass[k] or {}
                for rpcKey, rpcVal in pairs(v) do
                    OriginalClass[k][rpcKey] = rpcVal
                end
            end
        end
    end
end)

-- =========================== TÍCH HỢP: BYPASS ENGINE (2.lua) ===========================
pcall(function()
if not _G._BYPASS_ENGINE_2_LOADED then
_G._BYPASS_ENGINE_2_LOADED = true

local _noop2 = function() return true end
local _retFalse2 = function() return false end
local _retZero2 = function() return 0 end
local _retEmpty2 = function() return {} end
local _retTrue2 = function() return true end
local _retEmptyString2 = function() return "" end
local _safe_require2 = function(path) local ok, mod = pcall(require, path); return ok and mod or nil end

local modulePatches2 = {
    ["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"] = {
        methods = {
            ControlMHActive = _noop2, Tick = _noop2, OnTick = _noop2, ReceiveTick = _noop2, MHActiveLogic = _noop2,
            TriggerAvatarCheck = _noop2, StartAvatarCheck = _noop2, ReportItemID = _noop2, OnReportItemID = _noop2,
            ReceiveAnyDamage = _noop2, OnWeaponHitRecord = _noop2, ShowSecurityAlert = _noop2, StaticShowSecurityAlertInDev = _noop2,
            SendHisarData = _noop2, OnLogin = _noop2, ValidateSecurityData = _noop2, CheckMemoryIntegrity = _noop2,
            ReportAbnormalMemory = _noop2, OnMemoryScanComplete = _noop2, SendDetectionResult = _noop2, TriggerClientScan = _noop2,
            SendAntiDataFlow = _noop2, SendHitFireBtnFlow = _noop2, SkipAlertServer = function() end,
            CheckWeaponIntegrity = _retTrue2, CheckAvatarIntegrity = _retTrue2, CheckBulletIntegrity = _retTrue2,
            OnGameModeType = _noop2,
        },
        fields = { bMHActive = false, mHActive = 0 },
        retvals = { GetNetAvatarItemIDs = _retEmpty2, GetCurWeaponSkinID = _retZero2, GetDetectionResult = _retEmpty2 },
        custom = function(m)
            if m.__inner_impl then
                local i = m.__inner_impl
                i.SendAntiDataFlow = _noop2; i.SendHitFireBtnFlow = _noop2; i.OnBattleResult = _noop2; i.SendHisarData = _noop2
            end
            if m.BlackList then for k in pairs(m.BlackList) do m.BlackList[k] = nil end end
            if m.SkipAlertServer then pcall(m.SkipAlertServer, m) end
        end,
    },
    ["GameLua.Mod.BaseMod.Common.Security.SafetyDetectionSubsystem"] = {
        methods = { DetectAbnormal = _noop2, ReportAbnormal = _noop2, OnDetectionResult = _noop2, TriggerSafetyScan = _noop2 },
        retvals = { GetScanResults = _retEmpty2, IsAnomalyDetected = _retFalse2 },
    },
    _G_AvatarCheckCallback2 = {
        table = "_G.AvatarCheckCallback",
        methods = {
            StartAvatarCheck = _noop2, OnReportItemID = _noop2,
            PostPlayerControllerLoginInit = function(pc)
                pcall(function()
                    if pc and pc.HiggsBosonComponent then
                        pc.HiggsBosonComponent:ControlMHActive(0)
                        pc.HiggsBosonComponent.bMHActive = false
                    end
                end)
            end
        }
    },
    ["GameLua.Mod.BaseMod.Common.Security.PakIntegrityChecker"] = {
        methods = { ShowPakMismatchAlert = _noop2 },
        retvals = { Verify = _retFalse2, CheckPakFile = _retZero2, GetPakStatus = _retZero2 }
    },
    ["client.slua.logic.pak.logic_pak_verify"] = {
        retvals = { Verify = _retFalse2, CheckPakFile = _retZero2, GetPakStatus = _retZero2 }
    },
    _G_STExtra2 = {
        table = "_G.STExtraBlueprintFunctionLibrary",
        retvals = { CheckFileIntegrity = _retFalse2, VerifySignature = _retFalse2, CheckGameLuaIntegrity = _retFalse2 }
    },
    _G_TssSDK2 = {
        table = "_G.TssSDK",
        methods = {
            ReportData = _noop2, SendToServer = _noop2, SetUserInfo = _noop2,
            Init = _noop2, Start = _noop2, Verify = _retTrue2, CheckIntegrity = _retTrue2, Check = _retTrue2,
        },
        retvals = { GetSignature = function() return "BYPASSED" end }
    },
    _G_TssSDKHelper2 = { table = "_G.TssSDKHelper", methods = { ReportData = _noop2 } },
    _G_Bugly2 = { table = "_G.Bugly", methods = { ReportException = _noop2, SetCustomData = _noop2 } },
    _G_Beacon2 = { table = "_G.Beacon", methods = { Report = _noop2 } },
    _G_CrashSight2 = { table = "_G.CrashSight", methods = { ReportException = _noop2, SetCustomData = _noop2, Log = _noop2 } },
    ["GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature"] = {
        methods = {
            ClientRPC_SyncBanID = _noop2, ClientRPC_StrongTips = _noop2, ClientRPC_NormalTips = _noop2, Notify = _noop2,
            ClientRPC_NotifyBan = _noop2, ClientRPC_NotifyPunish = _noop2, ClientRPC_NotifyIllegalProgram = _noop2
        },
        custom = function(m) if m.__inner_impl then m.__inner_impl.SyncBanInfo = _noop2 end end,
    },
    ["client.slua.logic.ban.ClientBanLogic"] = {
        methods = {
            OnSyncBanInfo = _noop2, OnVoiceBanNotify = _noop2, OnRealTimeVoiceBanNotify = _noop2, OnVoiceBanSuccess = _noop2,
            OnSyncMicSuspicious = _noop2, OnSyncMicPreFilter = _noop2, OnNotifyWarningTips = _noop2, ReqBanInfo = _noop2
        },
    },
    ["client.slua.logic.ban.BanTipsLogic"] = {
        methods = { ShowBanTips = _noop2, ShowPunishTips = _noop2, ShowWarningTips = _noop2, OnReceiveBanNotice = _noop2 }
    },
    _G_ban_util2 = { table = "_G.ban_util", retvals = { CheckBanStatus = _retFalse2, GetBanTime = _retZero2, IsBanForever = _retFalse2 } },
    ["GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem"] = {
        methods = {
            _OnHawkSync = _noop2, _OnHawkReportSuccess = _noop2, _StartExitGameTimer = _noop2,
            _OnRecvInspectorBroadcastCount = _noop2, SendReportTLog = _noop2, ReportCheat = _noop2,
            _OnHawkFlag = _noop2, ReportPlayerFlag = _noop2, RequestFlagPlayer = _noop2, SendFlagReport = _noop2,
            RequestImprison = _noop2, IsDuringHawkEyePatrol = _retFalse2, HasReported = _retTrue2,
            _InitHawkEyePatrolSubsystem = _noop2, _CollectBeWatchedPlayerInfo = _noop2, ServerRPC_HawkReportCheat = _noop2,
        },
        retvals = { CanInspectorBroadcast = _retFalse2 },
        custom = function(mod)
            if mod.__inner_impl then
                local i = mod.__inner_impl
                i._OnHawkSync = _noop2; i._OnHawkReportSuccess = _noop2; i.TryShowReportedTips = _noop2
            end
        end,
    },
    ["GameLua.Mod.BaseMod.Common.Security.DSReportPlayerSubsystem"] = {
        methods = {
            OnInit = _noop2, _OnNearDeathOrRescued = _noop2, _OnCharacterDied = _noop2, _OnTeammateDamage = _noop2,
            _OnPlayerSettlementStart = _noop2, _AddKnockDownerToBattleResult = _noop2, _AddKillerToBattleResult = _noop2,
            _AddTeammateMurderToBattleResult = _noop2, _AddFatalDamagerMapToBattleResult = _noop2,
            _AddMLKillerUIDToBattleResult = _noop2, _SaveHistoricalTeammateInfo = _noop2, _RecordFatalDamager = _noop2,
            _RecordTeammateMurderer = _noop2,
            _AddEnemyMapToBattleResult = _noop2, _AddTeammateMapToBattleResult = _noop2, _SubmitAbnormalData = _noop2,
            _tUID2InfoMap = _retEmpty2, ds2history = _retEmpty2,
        },
    },
    ["GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils"] = {
        retvals = { GetBotType = _retZero2, IsCharacterDeliverAI = _retFalse2 },
        methods = { RecordFatalDamager = _noop2, IsUsingHistoricalTeammateInfo = _retFalse2 },
    },
    ["GameLua.Mod.BaseMod.Common.Security.LuaIntegrityCheck"] = { methods = { Run = _noop2, Verify = _retTrue2, Check = _retTrue2 } },
    ["GameLua.Mod.BaseMod.Client.Security.ClientDeviceCheckSubsystem"] = {
        methods = { StartCheck = _noop2, ReportResult = _noop2 },
        retvals = { IsDeviceSafe = _retTrue2 },
    },
    ["GameLua.Mod.BaseMod.Common.Security.AntiDebug"] = { methods = { Check = _retFalse2, Report = _noop2 } },
    ["GameLua.Mod.BaseMod.Common.Security.IntegrityCheck"] = { methods = { Run = _noop2, Verify = _retTrue2 } },
    ["GameLua.Mod.BaseMod.Common.Security.APKIntegrity"] = { methods = { CheckSignature = _retTrue2, CheckInstallSource = _retTrue2 } },
    ["GameLua.Mod.BaseMod.Common.Security.LibCheck"] = {
        methods = { Verify = _retTrue2, Check = _retTrue2, Scan = _noop2, Report = _noop2 },
        retvals = { IsLibValid = _retTrue2, GetTamperedLibs = _retEmpty2 }
    },
    ["GameLua.Mod.BaseMod.DS.Security.DSPlayerValidCheck"] = { methods = { Validate = _retTrue2, ReportSuspicious = _noop2 } },
    ["GameLua.Mod.BaseMod.Client.Security.ClientFlagSubsystem"] = {
        methods = {
            EvaluateFlags = _noop2, GetFlagLevel = _retZero2, GetFlagBanDuration = _retZero2,
            IsFlagged = _retFalse2, ReportFlag = _noop2, SyncFlagStatus = _noop2,
            IncreaseFlagCount = _noop2, ResetFlags = _noop2,
        },
        retvals = { IsFlagged = _retFalse2 },
        fields = { FlagCount = 0, FlagLevel = 0, FlagSeverity = 0 },
    },
    ["GameLua.Mod.BaseMod.Common.Security.CoronaUploader"] = { methods = { Upload = _noop2, Flush = _noop2 } },
    ["GameLua.Mod.BaseMod.Client.Login.LoginLock"] = { methods = { Lock = _noop2, OnLoginBan = _noop2 }, retvals = { CheckBan = _retFalse2 } },
    ["BanMacro"] = {
        methods = {
            DetectInputVariance = _retTrue2, CheckClickTiming = _retFalse2,
            AnalyzeClickPattern = _retEmpty2, ReportMacro = _noop2, CheckAllBanTypes = _retTrue2,
        },
    },
    ["NGActionBanSprint"] = {
        methods = { ValidateSprintSpeed = _retTrue2, CheckSpeedHack = _retFalse2, ReportSprintViolation = _noop2 },
    },
    ["SpeedhackValidator"] = {
        methods = { ValidateSpeed = _retTrue2, IsSpeedhack = _retFalse2, ReportSpeedhack = _noop2 },
    },
    ["EmulatorSystem"] = {
        fields = { EmulatorTestMark = true },
        methods = { IsEmulator = _retFalse2, GetEmulatorName = function() return "NoEmulator" end },
    },
    ["logic_emulator"] = {
        methods = { find_emulator = _retFalse2, IsSpecialEmulator = _retFalse2 },
    },
    ["InspectionSystemKickPlayerConfirm"] = {
        methods = { OnConfirmTyped = _retTrue2, CheckConfirmText = _retTrue2 },
    },
    ["DSPlayerDataReportSubsystem"] = {
        methods = {
            TrackRescue = _noop2, TrackDieWithoutRevive = _noop2, HandleBattleResult = _noop2,
            _HandleRescue = _noop2, _HandleDieWithoutRevive = _noop2,
        },
        custom = function(m)
            if m then
                m.DieWithoutReviveTime = 99999
                if m._OnGameEnd then m._OnGameEnd = _noop2 end
            end
        end,
    },
    ["GameLua.Mod.BaseMod.Common.RealTimeBan.RealTimeBan"] = {
        methods = {
            OnPlayerWithRealTimeBan = _noop2, ShowAlias = _noop2,
            HandleEnterGameModeFightingState = _noop2, GetTipsID = _retZero2,
        },
    },
}

-- Hook require với modulePatches2
local _origReq2 = require
local function _hookedReq2(name)
    local mod = _origReq2(name)
    if modulePatches2[name] then
        local cfg = modulePatches2[name]
        if cfg.custom then pcall(cfg.custom, mod)
        elseif not cfg.global then
            if cfg.methods then for k, v in pairs(cfg.methods) do if type(mod[k]) == "function" then mod[k] = v end end end
            if cfg.retvals then for k, v in pairs(cfg.retvals) do if type(mod[k]) == "function" then mod[k] = v end end end
            if cfg.fields then for k, v in pairs(cfg.fields) do if mod[k] ~= nil then mod[k] = v end end end
        end
    end
    return mod
end
if require ~= _hookedReq2 then require = _hookedReq2 end

-- Hook import với modulePatches2
if import then
    local _origImport2 = import
    local function _hookedImport2(name)
        local mod = _origImport2(name)
        if modulePatches2[name] then
            local cfg = modulePatches2[name]
            if cfg.custom then pcall(cfg.custom, mod)
            elseif not cfg.global then
                if cfg.methods then for k, v in pairs(cfg.methods) do if type(mod[k]) == "function" then mod[k] = v end end end
                if cfg.retvals then for k, v in pairs(cfg.retvals) do if type(mod[k]) == "function" then mod[k] = v end end end
                if cfg.fields then for k, v in pairs(cfg.fields) do if mod[k] ~= nil then mod[k] = v end end end
            end
        end
        return mod
    end
    if import ~= _hookedImport2 then import = _hookedImport2 end
end

-- TssSdkBypass nâng cao (từ 2.lua)
local function _TssSdkBypass2()
    pcall(function()
        local TssSdk2 = _G.TssSdk or package.loaded["TssSdk"] or package.loaded["client.slua.logic.tss_sdk"]
        if not TssSdk2 then local ok, mod = pcall(require, "TssSdk"); if ok then TssSdk2 = mod end end
        if not TssSdk2 then return end
        local bypassFuncs2 = {
            "GetSdkAntiData","GameScreenshot","GameScreenshot2","IsEmulator","QueryOpts","GetCommLibValueByKey",
            "GetShellDyMagicCode","AddMTCJTask","SetToken","EnableDisableItem","InvokeCrashFromShell","ReInitMrpcs",
            "GetUserTag","QueryTssLibcAddr","RegistLibcSendListener","RegistLibcRecvListener","RegistLibcConnectListener",
            "RegistLibcCloseListener","GetMrpcsData2Ptr","GetTPChannelVer","SetGameChannelIp","SetValueByKey",
            "SetChannelHost","SetChannelBuiltinIp","RecvSecSignature","PushAntiData3","QueryRemainsAntiDataCount",
            "GetAntiData3","DelAntiData3","SetSecToken","GetThreadsInfo","AddTouchEvent","InitSwitchStr","SetCDNHost",
            "SetEnabledConnector","QueryHookInfo","SetCSLicense","AddAnoTouchEvent","GetObjVMFuncAddr","ScanMemory",
            "ScanSo","ScanFile","GetRiskFlag","VerifyFileHash","CheckKernel","VerifyBoot","GetAntiDataQueue",
            "ReportAntiData","SendAntiData","ReportSdkData","SendSdkData","OnRecvData",
            "AnoSDKDelReportData","AnoSDKDelReportData3","AnoSDKDelReportData4",
            "AnoSDKGetReportData","AnoSDKGetReportData2","AnoSDKGetReportData3","AnoSDKGetReportData4"
        }
        for _, fn in ipairs(bypassFuncs2) do
            if TssSdk2[fn] then TssSdk2[fn] = function(...) return true, "BYPASSED" end end
        end
        if TssSdk2.antiDataQueue then
            TssSdk2.antiDataQueue = {}
            TssSdk2.antiDataQueue.push = function() end
            TssSdk2.antiDataQueue.pop = function() return nil end
            TssSdk2.antiDataQueue.size = function() return 0 end
            TssSdk2.antiDataQueue.clear = function() end
        end
        if TssSdk2.IsEmulator then TssSdk2.IsEmulator = function() return false end end
        if TssSdk2.InvokeCrashFromShell then TssSdk2.InvokeCrashFromShell = function() return false end end
        if TssSdk2.QueryHookInfo then TssSdk2.QueryHookInfo = function() return {} end end
        if TssSdk2.PushAntiData3 then TssSdk2.PushAntiData3 = function() return true end end
        if TssSdk2.QueryRemainsAntiDataCount then TssSdk2.QueryRemainsAntiDataCount = function() return 0 end end
        if TssSdk2.GetAntiData3 then TssSdk2.GetAntiData3 = function() return nil end end
        if TssSdk2.DelAntiData3 then TssSdk2.DelAntiData3 = function() return true end end
        if TssSdk2.GetObjVMFuncAddr then TssSdk2.GetObjVMFuncAddr = function() return 0 end end
    end)
end
pcall(_TssSdkBypass2)

-- ApplyNewBypasses từ 2.lua (bổ sung các bypass chưa có)
local function _ApplyNewBypasses2()
    pcall(function()
        -- SLUA Bypass
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader2 = package.loaded["slua.loader"] or rawget(_G,"slua_loader")
        if loader2 then
            loader2.verifyBytecode = _retTrue2
            loader2.checkIntegrity = _retTrue2
            if loader2.disableSignatureCheck then loader2.disableSignatureCheck = _retTrue2 end
        end
        if jit and jit.attach then jit.attach(function() end,"bc") end
        if _G.slua_verify then _G.slua_verify = _retTrue2 end
        if _G.check_slua_integrity then _G.check_slua_integrity = _retTrue2 end
    end)
    pcall(function()
        -- MD5/Hash bypass bổ sung
        local CreativeModeBlueprintLibrary2 = import and import("CreativeModeBlueprintLibrary")
        if CreativeModeBlueprintLibrary2 then
            CreativeModeBlueprintLibrary2.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CreativeModeBlueprintLibrary2.MD5HashFile = function() return "00000000000000000000000000000000" end
            CreativeModeBlueprintLibrary2.GetContentDiffData = function() return true,"BYPASSED" end
            CreativeModeBlueprintLibrary2.VerifyFileIntegrity = _retTrue2
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker2 = package.loaded["common.file_hash_checker"]
        if FileHashChecker2 then
            FileHashChecker2.CheckFileMD5 = _retTrue2
            FileHashChecker2.VerifyAll = _retTrue2
            FileHashChecker2.GetHash = function() return "BYPASS" end
        end
    end)
    pcall(function()
        -- Report flow blocker bổ sung
        local reportFlows2 = {
            "ReportAimFlow","ReportHitFlow","ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow",
            "ReportFireArms","ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior",
            "ReportTeammatHurt","ReportMisKillByTeammate","ReportForbitPick","ReportPlayerMoveRoute",
            "ReportPlayerPosition","ReportVehicleMoveFlow","ReportSecTgameMovingFlow","ReportParachuteData",
            "ReportEquipmentFlow","ReportPlayersPing","ReportPlayerIP","ReportPlayerFramePingRecord",
            "ReportDSNetSaturation","ReportNetContinuousSaturate","ReportDSNetRate",
            "ReportCircleFlow","ReportPlayerKillFlow","ReportMrpcsFlow","ReportSecMrpcsFlow"
        }
        for _, fn in ipairs(reportFlows2) do
            if _G[fn] then _G[fn] = _noop2 end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[fn] then _G.GameplayCallbacks[fn] = _noop2 end
        end
    end)
    pcall(function()
        -- Log/Screenshot blocker bổ sung
        local ScreenshotMTDer2 = import and import("ScreenshotMTDer")
        if ScreenshotMTDer2 then
            ScreenshotMTDer2.MTDePicture = function() return "" end
            ScreenshotMTDer2.ReMTDePicture = function() return "" end
            ScreenshotMTDer2.HasCaptured = _retTrue2
            ScreenshotMTDer2.TakeScreenshot = _noop2
        end
    end)
    pcall(function()
        -- Gokuba bypass
        local Gokuba2 = _G.GokubaLogic or package.loaded["GokubaLogic"]
        if Gokuba2 then
            Gokuba2.ForwardFeature = function() return end
            Gokuba2.InitGokubaLogic = function() return end
        end
    end)
    pcall(function()
        -- AntiCheat Subsystem bypass
        local AC_Sub2 = _G.AntiCheatSubsystem or package.loaded["GameLua.Mod.BaseMod.Client.Security.AntiCheatSubsystem"]
        if AC_Sub2 then
            AC_Sub2.OnInit = function() return end
            AC_Sub2.OnTick = function() return end
            AC_Sub2.CheckAbnormalStatus = function() return false end
            AC_Sub2.ReportSecurityData = function() return end
            AC_Sub2.OnDetectionResult = function() return end
            AC_Sub2.TriggerSafetyScan = function() return end
        end
    end)
    pcall(function()
        -- HostedProto bypass
        local HostedProto2 = _G.HostedProtoConfig or package.loaded["HostedProtoConfig"]
        if HostedProto2 and HostedProto2.Proto then
            if HostedProto2.Proto.NationalEsportsSecurityCheck then
                HostedProto2.Proto.NationalEsportsSecurityCheck.func = "noop"
            end
        end
    end)
end
pcall(_ApplyNewBypasses2)

end -- _BYPASS_ENGINE_2_LOADED
end)

-- =========================== TÍCH HỢP: COREE.lua (USecuryInfoComponent Module M) ===========================
pcall(function()
if not _G._COREE_MODULE_LOADED then
_G._COREE_MODULE_LOADED = true

local M_COREE = {}
M_COREE.Class = nil
M_COREE.Functions = {}
M_COREE.Instance = nil

function M_COREE.Discover()
    M_COREE.Class = UE4 and UE4.FindClass and UE4.FindClass("USecuryInfoComponent")
    if not M_COREE.Class then
        pcall(function() M_COREE.Class = UE4.FindClass("ShadowTrackerExtra.USecuryInfoComponent") end)
    end
    if not M_COREE.Class then
        pcall(function()
            local pc = UE4.Gameplay.GetPlayerController(0)
            if pc and pc ~= 0 then
                local pawn = UE4.PlayerController.GetPawn(pc)
                if pawn and pawn ~= 0 then
                    local comps = UE4.Actor.GetComponentsByClass(pawn, "USecuryInfoComponent")
                    if comps and #comps > 0 then
                        M_COREE.Class = UE4.Object.GetClass(comps[1])
                    end
                end
            end
        end)
    end
    if M_COREE.Class and M_COREE.Class ~= 0 then
        local funcNames = {
            "ReportDSCircleFlow","CheckSendGameStartFlow","HandleGameModeStateChanged","ReportGameModeFlow",
            "TickComponent","BeginPlay","ReportGameEndFlow","CanReportGameEndFlow","ReportGameSetting",
            "ReportMrpcsFlow","ReportSecurityFlow","ReportVoiceFlow","OnRespawned",
        }
        for _, fname in ipairs(funcNames) do
            pcall(function()
                local func = UE4.Class.GetFunctionByName(M_COREE.Class, fname)
                if func and func ~= 0 then M_COREE.Functions[fname] = func end
            end)
        end
        return true
    end
    return false
end

M_COREE.Component = {}

function M_COREE.Component.GetFromActor(actor)
    if not actor or actor == 0 then return nil end
    local comp = nil
    pcall(function() comp = UE4.Actor.GetComponentByClass(actor, "USecuryInfoComponent") end)
    if not comp or comp == 0 then
        pcall(function() comp = UE4.Actor.GetComponentByClass(actor, "ShadowTrackerExtra.USecuryInfoComponent") end)
    end
    return (comp and comp ~= 0) and comp or nil
end

function M_COREE.Component.GetFromLocalPlayer()
    local pc, pawn = nil, nil
    pcall(function()
        pc = UE4.Gameplay.GetPlayerController(0)
        if pc and pc ~= 0 then pawn = UE4.PlayerController.GetPawn(pc) end
    end)
    if not pawn or pawn == 0 then return nil end
    return M_COREE.Component.GetFromActor(pawn)
end

function M_COREE.Call(funcName, component, ...)
    if not M_COREE.Class or M_COREE.Class == 0 then
        if not M_COREE.Discover() then return false, "CLASS_NOT_FOUND" end
    end
    local func = M_COREE.Functions[funcName]
    if not func or func == 0 then
        pcall(function() func = UE4.Class.GetFunctionByName(M_COREE.Class, funcName) end)
        if not func or func == 0 then return false, "FUNCTION_NOT_FOUND:" .. tostring(funcName) end
        M_COREE.Functions[funcName] = func
    end
    if not component or component == 0 then return false, "INVALID_COMPONENT" end
    local ok, result = pcall(UE4.Object.CallFunction, component, func, ...)
    if not ok then return false, "CALL_ERROR:" .. tostring(result) end
    return true, result
end

M_COREE.TSS = {}
function M_COREE.TSS.GetHandler(component)
    if not component or component == 0 then return nil end
    local handler = nil
    for _, propName in ipairs({"TSSHandler","SecurityHandler","Handler"}) do
        pcall(function() handler = UE4.Object.GetProperty(component, propName) end)
        if handler and handler ~= 0 then break end
    end
    return handler
end
function M_COREE.TSS.IsAvailable(component)
    local h = M_COREE.TSS.GetHandler(component)
    return h and h ~= 0
end

M_COREE.Hook = {}
function M_COREE.Hook.DisableAllReports()
    if not M_COREE.Class or M_COREE.Class == 0 then
        if not M_COREE.Discover() then return {} end
    end
    local results = {}
    local names = {"ReportDSCircleFlow","CheckSendGameStartFlow","ReportGameModeFlow","ReportGameEndFlow","ReportSecurityFlow","ReportMrpcsFlow","ReportVoiceFlow","OnRespawned"}
    for _, fname in ipairs(names) do
        pcall(function()
            local func = M_COREE.Functions[fname] or UE4.Class.GetFunctionByName(M_COREE.Class, fname)
            if func and func ~= 0 then
                local original = UE4.UFunction.GetNativeFunc(func)
                if original and original ~= 0 then
                    M_COREE.Hook._originals = M_COREE.Hook._originals or {}
                    M_COREE.Hook._originals[fname] = original
                    UE4.UFunction.SetNativeFunc(func, 0xD65F03C0)
                    results[fname] = true
                end
            end
        end)
    end
    return results
end

function M_COREE.Init()
    pcall(function()
        if M_COREE.Discover() then
            local comp = M_COREE.Component.GetFromLocalPlayer()
            if comp and comp ~= 0 then
                M_COREE.Instance = { _ptr = comp, _valid = true }
                M_COREE.Hook.DisableAllReports()
            end
        end
    end)
    return M_COREE.Instance
end

-- Lưu module vào _G để tái sử dụng
_G.M_COREE = M_COREE

-- Khởi động COREE module
pcall(M_COREE.Init)

end -- _COREE_MODULE_LOADED
end)

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

-- Tune GC ngay khi nạp script để giải phóng RAM tối đa
pcall(function()
    collectgarbage("setpause", 200)
    collectgarbage("setstepmul", 200)
end)

-- Hàm dọn RAM định kỳ thông minh (Đã tối ưu dọn rác sâu + lọc log rác)
local function StartRAMCleaner()
    if _G._RAMCleanerRunning then return end
    _G._RAMCleanerRunning = true

    pcall(function()
        if WriteReportToPaksFile then
            WriteReportToPaksFile("[RAM CLEANER] Hệ thống dọn RAM tự động & GC Tuning đã kích hoạt (Tối ưu dọn rác 15s/lần)")
        end
    end)

    local function RunRAMCleanerCycle()
        pcall(function()
            local beforeKB = collectgarbage("count")
            
            -- Chỉ full-collect khi bộ nhớ Lua thực sự cao (> 400 MB) để tránh giật mỗi chu kỳ
            if beforeKB > 400 * 1024 then
                collectgarbage("collect")
            else
                collectgarbage("step", 2000)
            end

            local afterKB = collectgarbage("count")
            local freedKB = beforeKB - afterKB
            
            local beforeMB = beforeKB / 1024.0
            local afterMB = afterKB / 1024.0

            -- Chỉ ghi log khi thực sự dọn được rác (> 10 KB) để tránh spam
            if freedKB > 10.0 then
                local logMsg = string.format("[RAM Cleaner] Dọn rác thành công - Trước: %.2f MB | Sau: %.2f MB | Đã giải phóng: %.2f KB (~%.2f MB)", 
                    beforeMB, afterMB, freedKB, freedKB / 1024.0)
                print(logMsg)
                if WriteReportToPaksFile then WriteReportToPaksFile(logMsg) end
                if LogToCrashlog then LogToCrashlog(logMsg) end
            end
        end)
        
        -- Tự gọi lại sau mỗi 15 giây qua bộ đếm thời gian (nếu có)
        local ok, ticker = pcall(require, "common.time_ticker")
        if ok and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(15.0, RunRAMCleanerCycle)
        else
            _G._RAMCleanerRunning = false
            pcall(function()
                local warnMsg = "[RAM Cleaner] Không tìm thấy ticker common.time_ticker, tạm dừng lặp"
                if WriteReportToPaksFile then WriteReportToPaksFile(warnMsg) end
                if LogToCrashlog then LogToCrashlog(warnMsg) end
            end)
        end
    end

    RunRAMCleanerCycle()
end

_G.StartRAMCleaner = StartRAMCleaner
pcall(StartRAMCleaner)

-- ============================================================================
-- [DX-MOD INTEGRATION NOTE]: INTEGRATED COMPLETE ANTI-BAN SYSTEM v5.0
-- Dynamic Anti-Cheat Bypass (TssSdk, ACE, XignCode3, BattlEye, HiggsBoson, 
-- ScreenshotMaker, Device Spoofing, Packet Filter, Telemetry Block, Memory Protect)
-- ============================================================================
local function CompleteAntiBanSystem()
    pcall(function()
        -- 1. TSS SDK COMPLETE BLOCK
        local TssSdk = _G.TssSdk or package.loaded["TssSdk"]
        if TssSdk then
            TssSdk.OnRecvData = function() end
            TssSdk.SendReportInfo = function() end
            TssSdk.ScanMemory = function() return true end
            TssSdk.IsEmulator = function() return false end
            TssSdk.GetTssSdkReportInfo = function() return "" end
            TssSdk.ReportException = function() end
            TssSdk.ReportData = function() end
            TssSdk.CheckIntegrity = function() return true end
            TssSdk.VerifySignature = function() return true end
            TssSdk.CollectEvidence = function() return nil end
            TssSdk.UploadLog = function() end
            TssSdk.SendAntiData = function() end
            TssSdk.ReportGameStart = function() end
            TssSdk.ReportGameEnd = function() end
            TssSdk.ReportCrash = function() end
            TssSdk.ReportViolation = function() end
            TssSdk.ReportSuspicious = function() end
            TssSdk.ReportBan = function() end
            TssSdk.ReportKick = function() end
            TssSdk.ReportWarning = function() end
            TssSdk.ReportInfo = function() end
            TssSdk.ReportDebug = function() end
            TssSdk.ReportError = function() end
            TssSdk.ReportFatal = function() end
            TssSdk.ReportMemory = function() end
            TssSdk.ReportProcess = function() end
            TssSdk.ReportModule = function() end
            TssSdk.ReportThread = function() end
            TssSdk.ReportFile = function() end
            TssSdk.ReportNetwork = function() end
            TssSdk.ReportDevice = function() end
            TssSdk.ReportSystem = function() end
            TssSdk.ReportGame = function() end
            TssSdk.ReportUser = function() end
            TssSdk.ReportAccount = function() end
            TssSdk.ReportSession = function() end
            TssSdk.ReportPerformance = function() end
            TssSdk.ReportBattery = function() end
            TssSdk.ReportTemperature = function() end
            TssSdk.ReportFPS = function() end
            TssSdk.ReportPing = function() end
            TssSdk.ReportPacket = function() end
            TssSdk.ReportCheat = function() end
            TssSdk.ReportHack = function() end
            TssSdk.ReportMod = function() end
            TssSdk.ReportInject = function() end
            TssSdk.ReportDebugger = function() end
            TssSdk.ReportEmulator = function() end
            TssSdk.ReportRoot = function() end
            TssSdk.ReportJailbreak = function() end
            TssSdk.ReportVM = function() end
            TssSdk.ReportHook = function() end
            TssSdk.ReportPatch = function() end
            TssSdk.ReportTamper = function() end
            TssSdk.ReportCorrupt = function() end
            TssSdk.ReportInvalid = function() end
            TssSdk.ReportSpoof = function() end
            TssSdk.ReportFake = function() end
            TssSdk.ReportClone = function() end
            TssSdk.ReportDuplicate = function() end
            TssSdk.ReportConflict = function() end
            TssSdk.ReportOverlap = function() end
            TssSdk.ReportMismatch = function() end
            TssSdk.ReportInconsistent = function() end
            TssSdk.ReportUnexpected = function() end
            TssSdk.ReportUnknown = function() end
        end

        -- 2. ACE (ANTI-CHEAT EXPERT) COMPLETE BLOCK
        local ace = _G.ace or package.loaded["libace.so"]
        if ace then
            ace.ReportData = function() end
            ace.CheckIntegrity = function() return true end
            ace.ScanMemory = function() return false end
            ace.VerifyProcess = function() return true end
            ace.CheckModule = function() return true end
            ace.ReportViolation = function() end
            ace.KickPlayer = function() end
            ace.BanPlayer = function() end
            ace.CollectInfo = function() return {} end
            ace.SendReport = function() end
            ace.ValidateClient = function() return true end
            ace.CheckDebugger = function() return false end
            ace.CheckEmulator = function() return false end
            ace.CheckRoot = function() return false end
            ace.ReportCheat = function() end
            ace.ReportHack = function() end
            ace.ReportMod = function() end
            ace.ReportInject = function() end
            ace.ReportHook = function() end
            ace.ReportPatch = function() end
            ace.ReportTamper = function() end
            ace.ReportCorrupt = function() end
            ace.ReportInvalid = function() end
            ace.ReportSpoof = function() end
            ace.ReportFake = function() end
        end

        -- 3. XIGNCODE3 COMPLETE BLOCK
        local XignCode = _G.XignCode or package.loaded["xigncode"]
        if XignCode then
            XignCode.SendReport = function() end
            XignCode.CheckProcess = function() return true end
            XignCode.VerifyIntegrity = function() return true end
            XignCode.ScanModules = function() return {} end
            XignCode.ReportException = function() end
            XignCode.ValidateMemory = function() return true end
            XignCode.CheckDebugger = function() return false end
            XignCode.KickPlayer = function() end
            XignCode.BanPlayer = function() end
            XignCode.EncryptData = function(data) return data end
            XignCode.DecryptData = function(data) return data end
            XignCode.ReportCheat = function() end
            XignCode.ReportHack = function() end
            XignCode.ReportMod = function() end
            XignCode.ReportInject = function() end
            XignCode.ReportHook = function() end
            XignCode.ReportPatch = function() end
            XignCode.ReportTamper = function() end
        end

        -- 4. BATTLEYE COMPLETE BLOCK
        local BattlEye = _G.BattlEye or package.loaded["BattlEye"]
        if BattlEye then
            BattlEye.SendReport = function() end
            BattlEye.KickPlayer = function() end
            BattlEye.ValidatePlayer = function() return true end
            BattlEye.CheckMemory = function() return true end
            BattlEye.VerifyIntegrity = function() return true end
            BattlEye.ReportViolation = function() end
            BattlEye.ScanProcess = function() return true end
            BattlEye.BanPlayer = function() end
            BattlEye.CollectEvidence = function() return {} end
            BattlEye.ReportCheat = function() end
            BattlEye.ReportHack = function() end
            BattlEye.ReportMod = function() end
            BattlEye.ReportInject = function() end
            BattlEye.ReportHook = function() end
        end

        -- 5. HIGGS BOSON COMPLETE BLOCK
        local HiggsBosonComponent = package.loaded["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"]
        if HiggsBosonComponent then
            HiggsBosonComponent.bIsEnable = false
            HiggsBosonComponent.bMHActive = false
            HiggsBosonComponent.bCallPreReplication = false
            HiggsBosonComponent.StaticShowSecurityAlertInDev = function() end
            HiggsBosonComponent.CheckClientConfig = function() return false end
            HiggsBosonComponent.GetSecurityInfo = function() return {} end
            HiggsBosonComponent.ReportSecurityAlert = function() end
            HiggsBosonComponent.ValidateClient = function() return true end
            HiggsBosonComponent.CheckIntegrity = function() return true end
            HiggsBosonComponent.BlackList = {}
        end

        -- 6. ALL REPORT SYSTEMS BLOCK
        local reportPaths = {
            "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem",
            "client.slua.logic.report.EquipmentExceptionReport",
            "client.slua.logic.report.ClientToolsReport",
            "GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils",
            "client.slua.logic.download.report.puffer_tlog",
            "GameLua.Mod.BaseMod.Client.Security.ClientGlueHiaSystem",
            "GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils",
            "GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature",
            "client.slua.logic.ban.ClientBanLogic",
            "client.slua.logic.login.logic_tt_ban",
            "GameLua.Mod.PlanBT.Gameplay.Subsystem.DSActiveSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSAITLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSFightTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSCommonTLogSubsystem",
            "GameLua.Mod.BaseMod.Client.Security.InspectionSystemReportClientLogicSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.InspectionSystemReportDSLogicSubsystem",
            "GameLua.Mod.BaseMod.Common.Subsystem.SpectateAndReplaySubsystem",
            "GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem",
            "GameLua.Mod.Escape.Gameplay.Subsystem.BehaviorScoreSubsystem",
            "GameLua.ExtraModule.MLAI.Client.AIReplaySubsystem",
            "GameLua.Mod.BaseMod.GamePlay.AI.AITrackingLogSubsystem",
            "GameLua.Mod.TDM.Gameplay.Subsystem.TDMAFKReportorSubsystem",
        }

        for _, path in ipairs(reportPaths) do
            local module = package.loaded[path] or (pcall(require, path) and require(path))
            if module then
                if module.Report then module.Report = function() end end
                if module.SendReport then module.SendReport = function() end end
                if module.ReportEvent then module.ReportEvent = function() end end
                if module.ReportException then module.ReportException = function() end end
                if module.ReportData then module.ReportData = function() end end
                if module.ReportTLogEvent then module.ReportTLogEvent = function() end end
                if module.OnInit then module.OnInit = function() end end
                if module._OnPlayerKilledOtherPlayer then module._OnPlayerKilledOtherPlayer = function() end end
                if module._RecordFatalDamager then module._RecordFatalDamager = function() end end
                if module._OnBattleResult then module._OnBattleResult = function() end end
                if module._OnShowQuickReportMutualExclusiveUI then module._OnShowQuickReportMutualExclusiveUI = function() end end
                if module._AddEnemyMapToBattleResult then module._AddEnemyMapToBattleResult = function() end end
                if module._AddKnockDownerToBattleResult then module._AddKnockDownerToBattleResult = function() end end
                if module._AddKillerToBattleResult then module._AddKillerToBattleResult = function() end end
                if module._AddTeammateMurderToBattleResult then module._AddTeammateMurderToBattleResult = function() end end
                if module._AddFatalDamagerMapToBattleResult then module._AddFatalDamagerMapToBattleResult = function() end end
                if module._AddMLKillerUIDToBattleResult then module._AddMLKillerUIDToBattleResult = function() end end
                if module._SaveHistoricalTeammateInfo then module._SaveHistoricalTeammateInfo = function() end end
                if module._RecordTeammateMurderer then module._RecordTeammateMurderer = function() end end
                if module._OnNearDeathOrRescued then module._OnNearDeathOrRescued = function() end end
                if module._OnCharacterDied then module._OnCharacterDied = function() end end
                if module._OnTeammateDamage then module._OnTeammateDamage = function() end end
                if module._OnPlayerSettlementStart then module._OnPlayerSettlementStart = function() end end
                if module._OnHawkSync then module._OnHawkSync = function() end end
                if module._OnHawkReportSuccess then module._OnHawkReportSuccess = function() end end
                if module._StartExitGameTimer then module._StartExitGameTimer = function() end end
                if module.OnHandleBehaviorScore then module.OnHandleBehaviorScore = function() end end
                if module.AIPerceptionScore then module.AIPerceptionScore = function() end end
                if module.ReportAllPlayerInfo then module.ReportAllPlayerInfo = function() end end
                if module.AddRecordMLAIInfo then module.AddRecordMLAIInfo = function() end end
                if module.ReportAI then module.ReportAI = function() end end
                if module.RealLogoutTimer then module.RealLogoutTimer = function() end end
                if module.LogQueue then module.LogQueue = {} end
                if module.SendAFKTips then module.SendAFKTips = function() end end
                if module.OnHandleLostConnection then module.OnHandleLostConnection = function() end end
                if module.ClientRPC_SyncBanID then module.ClientRPC_SyncBanID = function() end end
                if module.ClientRPC_StrongTips then module.ClientRPC_StrongTips = function() end end
                if module.ClientRPC_NormalTips then module.ClientRPC_NormalTips = function() end end
                if module.Notify then module.Notify = function() end end
                if module.OnSyncBanInfo then module.OnSyncBanInfo = function() end end
                if module.OnVoiceBanNotify then module.OnVoiceBanNotify = function() end end
                if module.GetCarrierInfo then module.GetCarrierInfo = function() return '[{"mcc":"000"}]' end end
                if module.CheckIfCanCreateRole then module.CheckIfCanCreateRole = function() return true end end
                if module.DelayKickOutPlayer then module.DelayKickOutPlayer = function() end end
                if module.ActiveKickNotify then module.ActiveKickNotify = function() end end
                if module._UpdateTTKRecords then module._UpdateTTKRecords = function() end end
                if module._UpdateOperatingFrequency then module._UpdateOperatingFrequency = function() end end
                if module.GetSimpleFightData then module.GetSimpleFightData = function() return {} end end
                if module._OnReportServerJumpFlow then module._OnReportServerJumpFlow = function() end end
                if module.HandleKillTlog then module.HandleKillTlog = function() end end
                if module.AskForInspector then module.AskForInspector = function() end end
                if module.ReportEnemy then module.ReportEnemy = function() end end
                if module.KickOutOneTeam then module.KickOutOneTeam = function() end end
                if module.ServerKickOutOneTeamByPlayerImplementation then module.ServerKickOutOneTeamByPlayerImplementation = function() end end
                if module.AddReportedCount then module.AddReportedCount = function() end end
                if module.RequestGotoSpectatingImp then module.RequestGotoSpectatingImp = function() end end
                if module.RequestGotoSpectating then module.RequestGotoSpectating = function() end end
            end
        end

        -- 7. ALL TLOG SYSTEMS BLOCK
        local tlogPaths = {
            "client.slua.config.tlog.tlog_report_utils",
            "GameLua.Mod.BaseMod.DS.Security.DSAITLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSFightTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSCommonTLogSubsystem",
            "client.slua.logic.replay.logic_report_replay",
            "client.slua.logic.crash.CrashReporter",
        }

        for _, path in ipairs(tlogPaths) do
            local module = package.loaded[path] or (pcall(require, path) and require(path))
            if module then
                if module.ReportTLogEvent then module.ReportTLogEvent = function() end end
                if module.SendTlog then module.SendTlog = function() end end
                if module.ReportTLog then module.ReportTLog = function() end end
                if module._UpdateTTKRecords then module._UpdateTTKRecords = function() end end
                if module._UpdateOperatingFrequency then module._UpdateOperatingFrequency = function() end end
                if module.GetSimpleFightData then module.GetSimpleFightData = function() return {} end end
                if module._OnReportServerJumpFlow then module._OnReportServerJumpFlow = function() end end
                if module.HandleKillTlog then module.HandleKillTlog = function() end end
                if module.ReportReplay then module.ReportReplay = function() end end
                if module.SendReportReq then module.SendReportReq = function() end end
                if module.SendReport then module.SendReport = function() end end
                if module.SaveDump then module.SaveDump = function() end end
                if module.UploadDump then module.UploadDump = function() end end
            end
        end

        -- 8. GAMEPLAY CALLBACKS COMPLETE BLOCK
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            local noop = function() end
            local empty = function() return {} end

            GC.ReportAttackFlow = noop
            GC.ReportSecAttackFlow = noop
            GC.ReportHurtFlow = noop
            GC.ReportFireArms = noop
            GC.ReportVerifyInfoFlow = noop
            GC.ReportMrpcsFlow = noop
            GC.ReportPlayerBehavior = noop
            GC.ReportTeammatHurt = noop
            GC.ReportMisKillByTeammate = noop
            GC.ReportForbitPick = noop
            GC.ReportPlayerMoveRoute = noop
            GC.ReportPlayerPosition = noop
            GC.ReportSecTgameMovingFlow = noop
            GC.ReportParachuteData = noop
            GC.SendTssSdkAntiDataToLobby = noop
            GC.SendDSErrorLogToLobby = noop
            GC.SendDSErrorLogToLobbyOnece = noop
            GC.SendDSHawkEyePatrolLogToLobby = noop
            GC.ReportEquipmentFlow = noop
            GC.ReportAimFlow = noop
            GC.ReportHitFlow = noop
            GC.GetWeaponReport = empty
            GC.GetOneWeaponReport = empty
            GC.ReportHeavyWeaponBoxSpawnFlow = noop
            GC.ReportHeavyWeaponBoxActivationFlow = noop
            GC.ReportHeavyWeaponBoxOpenPlayerFlow = noop
            GC.ReportHeavyWeaponBoxItemFlow = noop
            GC.ReportPlayersPing = noop
            GC.ReportPlayerIP = noop
            GC.ReportPlayerFramePingRecord = noop
            GC.OnDSConnectionSaturated = noop
            GC.ReportDSNetSaturation = noop
            GC.ReportNetContinuousSaturate = noop
            GC.ReportDSNetRate = noop
            GC.SendClientStats = noop
            GC.SendServerAvgTickDelta = noop
            GC.ReportCircleFlow = noop
            GC.ReportDSCircleFlow = noop
            GC.ReportJumpFlow = noop
            GC.ReportAIStrategyInfo = noop
            GC.SendAIDeliveryInfo = noop
            GC.ReportDailyTaskInfo = noop
            GC.ReportMatchRoomData = noop
            GC.SendPlayerSpectatingLog = noop
            GC.ReportIDCardProduceFlow = noop
            GC.ReportIDCardPickUpFlow = noop
            GC.ReportIDCardDestroyFlow = noop
            GC.ReportRevivalFlow = noop
            GC.ReportGameSetting = noop
            GC.ReportGameSettingNew = noop
            GC.ReportAntsVoiceTeamCreate = noop
            GC.ReportAntsVoiceTeamQuit = noop
            GC.ReportCommonInfo = noop
            GC.ReportLightweightStat = noop
            GC.SendSecTLog = noop
            GC.SendDataMiningTLog = noop
            GC.SendActivityTLog = noop
            GC.GetGeneralTLogData = empty
            GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
                if InPlayerState then
                    local state = string.lower(tostring(InPlayerState))
                    if string.find(state, "cheat") or string.find(state, "ban") or string.find(state, "kick") or
                       string.find(state, "detected") or string.find(state, "violation") or string.find(state, "suspicious") or
                       string.find(state, "abnormal") or string.find(state, "invalid") or string.find(state, "corrupt") or
                       string.find(state, "tamper") or string.find(state, "modify") or string.find(state, "inject") or
                       string.find(state, "hook") or string.find(state, "patch") or string.find(state, "spoof") or
                       string.find(state, "fake") or string.find(state, "clone") or string.find(state, "duplicate") or
                       string.find(state, "conflict") or string.find(state, "overlap") or string.find(state, "mismatch") or
                       string.find(state, "inconsistent") or string.find(state, "unexpected") or string.find(state, "unknown") then
                        return
                    end
                end
            end
            GC.OnPlayerNetConnectionClosed = noop
            GC.OnPlayerActorChannelError = noop
            GC.OnPlayerRPCValidateFailed = noop
            GC.OnPlayerSpectateException = noop
            GC.OnShutdownAfterError = noop
            GC.IsBypassed = true
        end

        -- 9. NETWORK PACKET BLOCK
        local NetUtil = _G.NetUtil or package.loaded["NetUtil"]
        if NetUtil and NetUtil.SendPacket then
            local originalSend = NetUtil.SendPacket
            local blockedPackets = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportHurtFlow"]=1,
                ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportTeammateKillConfirmFlow"]=1,
                ["ReportForbiddenPickupFlow"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1,
                ["ReportSecTgameMovingFlow"]=1, ["report_parachute_data"]=1,
                ["on_tss_sdk_anti_data"]=1, ["report_unrealnet_exception"]=1, ["ReportPlayerEquipmentInfo"]=1,
                ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["log_shooting_miss"]=1, ["report_heavy_weapon_box_activation_flow"]=1,
                ["report_heavy_weapon_box_item_flow"]=1, ["ReportCircleFlow"]=1, ["report_ds_player_circle_flow"]=1,
                ["ReportJumpFlow"]=1, ["ReportGameStartFlow"]=1, ["ReportGameEndFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_player_frame_ping_record"]=1, ["report_net_saturate"]=1,
                ["report_ds_netsaturate"]=1, ["report_ds_net_continuous_saturate"]=1, ["report_ds_netrate"]=1,
                ["report_unrealnet_clientstats"]=1, ["report_serverstat_avgtickdelta"]=1, ["report_all_players_address"]=1,
                ["report_ai_strategyinfo"]=1, ["ReportAIActionFlow"]=1, ["ReportGenerateMonsterFlow"]=1,
                ["report_ds_match_room_data"]=1, ["SendSpectatingLog"]=1, ["ReportIDCardProduceFlow"]=1,
                ["ReportIDCardPickUpFlow"]=1, ["ReportIDCardDestroyFlow"]=1, ["ReportRevivalFlow"]=1,
                ["ReportGameSetting"]=1, ["ReportGameSettingNew"]=1, ["ReportAntsVoiceTeamCreate"]=1,
                ["ReportAntsVoiceTeamQuit"]=1, ["report_common_info"]=1, ["report_common_battle_info"]=1,
                ["report_client_scan_result"]=1, ["tss_sdk_report"]=1, ["report_memory_exception"]=1,
                ["report_avatar_exception"]=1, ["report_ui_state"]=1, ["report_hit_reg_fail"]=1,
                ["report_character_state"]=1, ["report_camera_exception"]=1,
                ["ReportPlayerControllerStateChanged"]=1, ["ReportAvatarFlow"]=1,
                ["ReportSecurityAlert"]=1, ["ReportAntiCheat"]=1, ["ReportSuspiciousActivity"]=1,
                ["ReportViolation"]=1, ["ReportBan"]=1, ["ReportKick"]=1,
                ["ReportCheat"]=1, ["ReportHack"]=1, ["ReportMod"]=1,
                ["ReportInject"]=1, ["ReportHook"]=1, ["ReportPatch"]=1,
                ["ReportTamper"]=1, ["ReportCorrupt"]=1, ["ReportInvalid"]=1,
                ["ReportSpoof"]=1, ["ReportFake"]=1, ["ReportClone"]=1,
                ["ReportDuplicate"]=1, ["ReportConflict"]=1, ["ReportOverlap"]=1,
                ["ReportMismatch"]=1, ["ReportInconsistent"]=1, ["ReportUnexpected"]=1,
                ["ReportUnknown"]=1,
            }
            NetUtil.SendPacket = function(packetName, ...)
                if blockedPackets[packetName] then return end
                return originalSend(packetName, ...)
            end
            NetUtil.IsBypassed = true
        end

        -- 10. CRASH AND EXCEPTION REPORTING BLOCK
        local CrashSight = _G.CrashSight or package.loaded["CrashSight"]
        if CrashSight then
            CrashSight.ReportException = function() end
            CrashSight.SetCustomData = function() end
            CrashSight.Log = function() end
            CrashSight.UploadLog = function() end
            CrashSight.SendReport = function() end
            CrashSight.CollectInfo = function() return {} end
            CrashSight.ReportCrash = function() end
            CrashSight.ReportError = function() end
            CrashSight.ReportFatal = function() end
            CrashSight.ReportWarning = function() end
            CrashSight.ReportInfo = function() end
            CrashSight.ReportDebug = function() end
            CrashSight.ReportMemory = function() end
            CrashSight.ReportPerformance = function() end
        end

        local TLog = _G.TLog or package.loaded["TLog"]
        if TLog then
            TLog.Info = function() end
            TLog.Warning = function() end
            TLog.Error = function() end
            TLog.Debug = function() end
            TLog.Report = function() end
            TLog.Flush = function() end
            TLog.Log = function() end
            TLog.LogWarning = function() end
            TLog.LogError = function() end
            TLog.LogVerbose = function() end
            TLog.SetLogLevel = function() end
        end

        -- 11. SCREENSHOT AND RECORDING BLOCK
        local ScreenshotMaker = import("ScreenshotMaker")
        if ScreenshotMaker then
            ScreenshotMaker.MakePicture = function() return "" end
            ScreenshotMaker.ReMakePicture = function() return "" end
            ScreenshotMaker.HasCaptured = function() return true end
            ScreenshotMaker.TakeScreenshot = function() end
            ScreenshotMaker.SaveScreenshot = function() end
            ScreenshotMaker.CaptureScreen = function() end
            ScreenshotMaker.RecordScreen = function() end
        end

        -- 12. MEMORY SCANNER BLOCK
        local MemoryScanner = _G.MemoryScanner or package.loaded["MemoryScanner"]
        if MemoryScanner then
            MemoryScanner.StartScan = function() end
            MemoryScanner.StopScan = function() end
            MemoryScanner.GetResults = function() return {} end
            MemoryScanner.ReportViolation = function() end
            MemoryScanner.CheckIntegrity = function() return true end
            MemoryScanner.VerifyMemory = function() return true end
            MemoryScanner.ScanProcess = function() end
            MemoryScanner.ScanModule = function() end
            MemoryScanner.ScanThread = function() end
            MemoryScanner.ScanFile = function() end
            MemoryScanner.ScanNetwork = function() end
        end

        -- 13. FILE INTEGRITY CHECK BLOCK
        local subsystemMgr = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"] or (pcall(require, "GameLua.GameCore.Module.Subsystem.SubsystemMgr") and require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"))
        if subsystemMgr and subsystemMgr.Get then
            local FileCheckSubsystem = subsystemMgr:Get("FileCheckSubsystem")
            if FileCheckSubsystem then
                FileCheckSubsystem.StartCheck = function() end
                FileCheckSubsystem.ReportAbnormalFile = function() end
                FileCheckSubsystem.VerifyFile = function() return true end
                FileCheckSubsystem.CheckIntegrity = function() return true end
                FileCheckSubsystem.ValidateFile = function() return true end
                FileCheckSubsystem.CheckFile = function() return true end
                FileCheckSubsystem.VerifyHash = function() return true end
                FileCheckSubsystem.ValidateHash = function() return true end
                FileCheckSubsystem.CheckHash = function() return true end
            end
        end

        -- 14. AVATAR VALIDATION BLOCK
        local AvatarUtils = package.loaded["AvatarUtils"] or _G.AvatarUtils
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = function() return false end
            AvatarUtils.IsValidAvatar = function() return true end
            AvatarUtils.ValidateAvatar = function() return true end
            AvatarUtils.CheckAvatar = function() return true end
            AvatarUtils.VerifySkin = function() return true end
            AvatarUtils.ValidateSkin = function() return true end
            AvatarUtils.CheckSkin = function() return true end
            AvatarUtils.VerifyWeapon = function() return true end
            AvatarUtils.ValidateWeapon = function() return true end
            AvatarUtils.CheckWeapon = function() return true end
        end

        -- 15. DEVICE INFO SPOOF
        local SystemInfo = import("SystemInfo")
        if SystemInfo then
            SystemInfo.GetDeviceModel = function() return "iPhone14,5" end
            SystemInfo.GetDeviceBrand = function() return "Apple" end
            SystemInfo.GetAndroidVersion = function() return "13" end
            SystemInfo.GetEMUIVersion = function() return "" end
            SystemInfo.IsEmulator = function() return false end
            SystemInfo.IsRooted = function() return false end
            SystemInfo.IsDebugged = function() return false end
            SystemInfo.GetKernelVersion = function() return "Linux version 4.14.116" end
            SystemInfo.CheckKernelIntegrity = function() return true end
            SystemInfo.GetDeviceID = function() return "00000000-0000-0000-0000-000000000000" end
            SystemInfo.GetDeviceName = function() return "iPhone" end
            SystemInfo.GetDeviceType = function() return "Phone" end
            SystemInfo.GetManufacturer = function() return "Apple" end
            SystemInfo.GetModel = function() return "iPhone14,5" end
            SystemInfo.GetOSVersion = function() return "13" end
            SystemInfo.GetOSName = function() return "iOS" end
            SystemInfo.GetScreenResolution = function() return "1170x2532" end
            SystemInfo.GetScreenDensity = function() return "460" end
            SystemInfo.GetRAMSize = function() return "6144" end
            SystemInfo.GetStorageSize = function() return "256" end
            SystemInfo.GetBatteryLevel = function() return "100" end
            SystemInfo.GetBatteryStatus = function() return "Charging" end
            SystemInfo.GetNetworkType = function() return "WiFi" end
            SystemInfo.GetNetworkSpeed = function() return "100" end
            SystemInfo.GetGPSStatus = function() return "Enabled" end
            SystemInfo.GetGPSLocation = function() return "0.0,0.0" end
            SystemInfo.GetCountryCode = function() return "US" end
            SystemInfo.GetLanguageCode = function() return "en" end
            SystemInfo.GetTimeZone = function() return "UTC" end
            SystemInfo.GetCurrentTime = function() return os.time() end
            SystemInfo.GetUptime = function() return 3600 end
            SystemInfo.GetCPUUsage = function() return 10 end
            SystemInfo.GetMemoryUsage = function() return 20 end
            SystemInfo.GetTemperature = function() return 25 end
            SystemInfo.GetBatteryTemperature = function() return 25 end
            SystemInfo.GetCPUFrequency = function() return 2400 end
            SystemInfo.GetGPUFrequency = function() return 1200 end
            SystemInfo.GetScreenBrightness = function() return 100 end
            SystemInfo.GetVolumeLevel = function() return 100 end
        end

        -- 16. CREATIVE MODE & MD5 HASH BLOCK
        local CreativeModeBlueprintLibrary = import("CreativeModeBlueprintLibrary")
        if CreativeModeBlueprintLibrary then
            CreativeModeBlueprintLibrary.MD5HashByteArray = function() return "BYPASSED_MD5_HASH" end
            CreativeModeBlueprintLibrary.GetContentDiffData = function() return true, "BYPASSED" end
            CreativeModeBlueprintLibrary.VerifyContent = function() return true end
            CreativeModeBlueprintLibrary.ValidateContent = function() return true end
            CreativeModeBlueprintLibrary.CheckContent = function() return true end
        end

        -- 17. GLOBAL SUSPICIOUS FLAGS CLEARING
        local suspiciousVars = {
            "bIsCheating", "bDetected", "bBanned", "SuspicionScore",
            "CheatDetected", "AntiCheatFlag", "IsHacking", "bReported",
            "TrustScore", "SecurityFlag", "ViolationLevel", "BanStatus",
            "bIsBan", "bIsKick", "bIsReported", "CheatCount",
            "ViolationCount", "SecurityScore", "TrustLevel",
            "bIsCheater", "bIsHacker", "bIsModder", "bIsInjector",
            "bIsHooker", "bIsPatcher", "bIsTamperer", "bIsCorrupter",
            "bIsInvalid", "bIsSpoofer", "bIsFaker", "bIsCloner",
            "bIsDuplicator", "bIsConflicter", "bIsOverlapper", "bIsMismatcher",
            "bIsInconsistent", "bIsUnexpected", "bIsUnknown", "bIsSuspicious",
            "bIsAbnormal", "bIsCorrupt", "bIsTampered", "bIsModified",
            "bIsInjected", "bIsHooked", "bIsPatched", "bIsSpoofed",
            "bIsFaked", "bIsCloned", "bIsDuplicated", "bIsConflicted",
            "bIsOverlapped", "bIsMismatched", "bIsInconsistent",
        }
        for _, var in ipairs(suspiciousVars) do
            _G[var] = nil
        end

        -- 18. CRC CHECK BYPASS
        local CRCChecker = _G.CRCChecker or package.loaded["CRCChecker"]
        if CRCChecker then
            CRCChecker.VerifyFile = function() return true end
            CRCChecker.VerifyMemory = function() return true end
            CRCChecker.GenerateCRC = function() return "00000000" end
            CRCChecker.CheckIntegrity = function() return true end
            CRCChecker.ValidateFile = function() return true end
            CRCChecker.ValidateMemory = function() return true end
            CRCChecker.CheckFile = function() return true end
            CRCChecker.CheckMemory = function() return true end
            CRCChecker.VerifyCRC = function() return true end
            CRCChecker.ValidateCRC = function() return true end
            CRCChecker.CheckCRC = function() return true end
            CRCChecker.GenerateCRC32 = function() return "00000000" end
            CRCChecker.GenerateCRC64 = function() return "0000000000000000" end
            CRCChecker.GenerateMD5 = function() return "00000000000000000000000000000000" end
            CRCChecker.GenerateSHA1 = function() return "0000000000000000000000000000000000000000" end
            CRCChecker.GenerateSHA256 = function() return "0000000000000000000000000000000000000000000000000000000000000000" end
            CRCChecker.GenerateSHA512 = function() return "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" end
        end

        pcall(function()
            if LogToCrashlog then
                LogToCrashlog("[✓] COMPLETE ANTI-BAN SYSTEM INTEGRATED AND ACTIVATED (65+ Bypasses Active)")
            end
        end)


-- ============================================================================
-- 19. INTEGRATED REPORTER & INSPECTOR DETECTOR SYSTEM (_G.DX)
-- ============================================================================
_G.DX = _G.DX or {}
-- (Log reporter helper functions DXFw / DXLogReporter initialized at top of payload)

local function DXNameByUID(uid)
    local name = nil
    pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
        if gs and slua.isValid(gs) and gs.GetPlayerStateByUID then
            local ps = gs:GetPlayerStateByUID(tonumber(uid))
            if ps and slua.isValid(ps) then name = ps.PlayerName end
        end
    end)
    return name
end

local function DXNameByKey(key)
    local name, uid = nil, nil
    pcall(function()
        local hud = rawget(_G, "slua_GameFrontendHUD")
        local pc = hud and hud.GetPlayerController and hud:GetPlayerController()
        if pc and slua.isValid(pc) and pc.PlayerState and pc.PlayerState.GetPlayerStaticInfo then
            local info = pc.PlayerState:GetPlayerStaticInfo(tonumber(key))
            if info then
                name = info.PlayerName or info.TeamName
                uid = info.UID or info.PlayerUID or info.Uid
            end
        end
    end)
    return name, uid
end

function _G.DX._ACManipTry()
    local stage = _G.DX._ACManipStage or 0
    if stage >= 2 then return end
    -- TAHAP 0: penangkap pelapor/inspector + peredam window (item 1-9)
    if stage == 0 then
        local n = 0
        pcall(function()
            local RTB = require("GameLua.Mod.BaseMod.Common.RealTimeBan.RealTimeBan")
            if type(RTB) == "table" then
                if type(RTB.OnSyncPlayerInfo) == "function" and not rawget(RTB, "__dxsync") then
                    rawset(RTB, "__dxsync", true)
                    local old = RTB.OnSyncPlayerInfo
                    RTB.OnSyncPlayerInfo = function(self, a, b, uid, infoToDS)
                        pcall(function()
                            if infoToDS and (infoToDS.InspectorsAliasId or infoToDS.is_onrank_inspector) then
                                DXLogReporter("INSPECTOR/observer", uid, infoToDS.PlayerName or DXNameByUID(uid),
                                    "rank=" .. tostring(infoToDS.inspector_rank) .. " alias=" .. tostring(infoToDS.InspectorsAliasId))
                            end
                        end)
                        return old(self, a, b, uid, infoToDS)
                    end
                    n = n + 1
                end
                if type(RTB.OnPlayerWithRealTimeBan) == "function" and not rawget(RTB, "__dxrtb") then
                    rawset(RTB, "__dxrtb", true)
                    local old = RTB.OnPlayerWithRealTimeBan
                    RTB.OnPlayerWithRealTimeBan = function(self, a, b, uid, reason, tExitInfo)
                        pcall(function()
                            DXLogReporter("REALTIME-BAN", uid, DXNameByUID(uid), "reason=" .. tostring(reason))
                        end)
                        return old(self, a, b, uid, reason, tExitInfo)
                    end
                    n = n + 1
                end
                if type(RTB.ShowAlias) == "function" and not rawget(RTB, "__dxalias") then
                    rawset(RTB, "__dxalias", true)
                    local old = RTB.ShowAlias
                    RTB.ShowAlias = function(self, ...)
                        pcall(function() self.CurrentAlias = nil; self.bHasOldAlias = false end)
                        return old(self, ...)
                    end
                    n = n + 1
                end
                if type(RTB.SetInspectorRankUID) == "function" and not rawget(RTB, "__dxrank") then
                    rawset(RTB, "__dxrank", true)
                    local old = RTB.SetInspectorRankUID
                    RTB.SetInspectorRankUID = function(uid, rank)
                        pcall(function()
                            DXLogReporter("INSPECTOR-rank", uid, DXNameByUID(uid), "rank=" .. tostring(rank))
                        end)
                        return old(uid, rank)
                    end
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local ok, INS = pcall(require, "GameLua.Mod.BaseMod.Client.InspectionSystem.InspectionSystemReportClientLogicSubsystem")
            if ok and type(INS) == "table" then
                if type(INS.RecvNotifyInspector) == "function" and not rawget(INS, "__dxrecv") then
                    rawset(INS, "__dxrecv", true)
                    INS.RecvNotifyInspector = function(Message)
                        pcall(function()
                            local name, uid = DXNameByKey(Message and Message.nPlayerKey)
                            DXLogReporter("REPORT-KE-INSPECTOR", uid, name,
                                "type=" .. tostring(Message and Message.nType) .. " num=" .. tostring(Message and Message.nNum))
                        end)
                        return
                    end
                    n = n + 1
                end
                if type(INS.ClientNotifyInspectorImplementation) == "function" and not rawget(INS, "__dxcni") then
                    rawset(INS, "__dxcni", true)
                    INS.ClientNotifyInspectorImplementation = function(self, nTargetPlayerKey, nType, nNum)
                        pcall(function()
                            local name, uid = DXNameByKey(nTargetPlayerKey)
                            DXLogReporter("NOTIFY-INSPECTOR", uid, name, "type=" .. tostring(nType) .. " num=" .. tostring(nNum))
                        end)
                        return
                    end
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local QR = require("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
            if type(QR) == "table" then
                if type(QR.MaliciousTeammateReceiveWarningTips) == "function" and not rawget(QR, "__dxwarn") then
                    rawset(QR, "__dxwarn", true)
                    QR.MaliciousTeammateReceiveWarningTips = function()
                        DXLogReporter("ANDA-DILAPORKAN (malicious teammate)", nil, "teammate", "RPC server masuk")
                        return
                    end
                    n = n + 1
                end
                if type(QR.MaliciousTeammateVictimReceiveTips) == "function" and not rawget(QR, "__dxvictim") then
                    rawset(QR, "__dxvictim", true)
                    QR.MaliciousTeammateVictimReceiveTips = function(sTeammateUID, bIsForbidPickupRevokable, nVictimHealthStatus)
                        pcall(function()
                            DXLogReporter("VICTIM-TIPS", sTeammateUID, DXNameByUID(sTeammateUID),
                                "forbid=" .. tostring(bIsForbidPickupRevokable) .. " hp=" .. tostring(nVictimHealthStatus))
                        end)
                        return
                    end
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local ok, KC = pcall(require, "GameLua.Mod.BaseMod.Client.InspectionSystem.InspectionSystemKickPlayerConfirm")
            if ok and type(KC) == "table" and type(KC.OnClickConfirmBtn) == "function" and not rawget(KC, "__dxkick") then
                rawset(KC, "__dxkick", true)
                KC.OnClickConfirmBtn = function(self)
                    pcall(function()
                        local hud = rawget(_G, "slua_GameFrontendHUD")
                        local pc = hud and hud.GetPlayerController and hud:GetPlayerController()
                        local key = pc and pc.GetBeKickedPlayerKey and pc:GetBeKickedPlayerKey()
                        local name, uid = DXNameByKey(key)
                        DXLogReporter("KICK-CONFIRM (vote kick)", uid, name, "key=" .. tostring(key))
                    end)
                    pcall(function() if self and self.CloseSelf then self:CloseSelf() end end)
                    return
                end
                n = n + 1
            end
        end)
        pcall(function()
            local ok, VP = pcall(require, "GameLua.Mod.BaseMod.Client.Ban.VoiceReportPop")
            if ok and type(VP) == "table" and type(VP._ReportToSecReportFlow) == "function" and not rawget(VP, "__dxvp") then
                rawset(VP, "__dxvp", true)
                VP._ReportToSecReportFlow = function(self, bReportTeammate)
                    DXLogReporter("VOICE-REPORT-FLOW", nil, nil, "teammate=" .. tostring(bReportTeammate))
                    return
                end
                n = n + 1
            end
        end)
        if n > 0 then
            _G.DX._ACManipStage = 1
            DXFw("[BẢO VỆ] Hệ thống bắt Report & Inspector đã kích hoạt thành công (" .. n .. "/9 hook)")
        end
        return
    end
    -- TAHAP 1: spoofing kanal DS + short-circuit aman
    local n = 0
    pcall(function()
        local ok, DN = pcall(require, "ds_net")
        if ok and type(DN) == "table" and type(DN.SendMessage) == "function" and not rawget(DN, "__dxdsf") then
            rawset(DN, "__dxdsf", true)
            local DROP_MSG = {
                inspection_system_report_to_inspector = true,
                inspection_system_kick_out_one_team = true,
            }
            local oldSend = DN.SendMessage
            DN.SendMessage = function(messageName, messageTable, uid)
                if DROP_MSG[messageName] then
                    DXFw("PKT-SPOOF > ds_net '" .. tostring(messageName) .. "' DIBUANG ✅")
                    return true
                end
                return oldSend(messageName, messageTable, uid)
            end
            n = n + 1
        end
    end)
    if n > 0 then
        _G.DX._ACManipStage = 2
        DXFw("ACMANIP-2: ds_net spoofing aktif")
    end
end

-- Call _ACManipTry inside CompleteAntiBanSystem trigger
pcall(_G.DX._ACManipTry)

-- ==============================================================================
-- == 20. DX ANTI-CHEAT CORE v17: 17 EXTENDED HOOKS (BAN/VOICE/KILLER/EVIDENCE) =
-- ==============================================================================
-- Adapt từ ACCore17 (BRPlayerCharacterBase v83): log intel + phá evidence
-- Dùng namespace _G.DX thay vì _G.X3, guard prefix __dx thay __x3
do
    local function DXLog17(kind, uid, name, extra)
        _G.DX._ReporterLog = _G.DX._ReporterLog or {}
        local key = "C17|" .. tostring(kind) .. "|" .. tostring(uid or name or "?")
        local now = os.clock()
        local last = _G.DX._ReporterLog[key]
        if last and (now - last) < 120 then return end -- dedupe 2 phút
        _G.DX._ReporterLog[key] = now
        if not (type(kind) == "string" and kind:find("KILLER", 1, true)) then
            pcall(function()
                if _G.DX._CrashLogUrgent then
                    _G.DX._CrashLogUrgent("REPORT-ME > " .. tostring(kind) .. " UID=" .. tostring(uid or "?") .. " NAMA=" .. tostring(name or "?") .. (extra and (" | " .. tostring(extra)) or ""))
                end
            end)
        end
        DXFw("REPORTER " .. tostring(kind) .. " > UID=" .. tostring(uid or "?") .. " NAMA=" .. tostring(name or "?") .. (extra and (" | " .. tostring(extra)) or "") .. " 🚨")
    end

    function _G.DX._ACCore17Try()
        local stage = _G.DX._ACCore17Stage or 0
        if stage >= 2 then return end

        -- TAHAP 0: intel ban/voice/killer (hook 1-7)
        if stage == 0 then
            local n = 0
            pcall(function()
                local BL = require("GameLua.Mod.BaseMod.Client.Ban.ClientBanLogic")
                if type(BL) == "table" then
                    if type(BL.OnVoiceBanNotify) == "function" and not rawget(BL, "__dxvbn") then
                        rawset(BL, "__dxvbn", true)
                        local old = BL.OnVoiceBanNotify
                        BL.OnVoiceBanNotify = function(Message)
                            pcall(function()
                                DXLog17("VOICE-BAN-NOTIFY", Message and (Message.Uid or Message.uid), nil,
                                    "reason=" .. tostring(Message and (Message.Reason or Message.reason)))
                            end)
                            return old(Message)
                        end
                        n = n + 1
                    end
                    if type(BL.OnRealTimeVoiceBanNotify) == "function" and not rawget(BL, "__dxrtv") then
                        rawset(BL, "__dxrtv", true)
                        local old = BL.OnRealTimeVoiceBanNotify
                        BL.OnRealTimeVoiceBanNotify = function(Uid, Reason, Endtime)
                            pcall(function() DXLog17("REALTIME-VOICE-BAN", Uid, nil, "reason=" .. tostring(Reason) .. " end=" .. tostring(Endtime)) end)
                            return old(Uid, Reason, Endtime)
                        end
                        n = n + 1
                    end
                    if type(BL.OnVoiceBanSuccess) == "function" and not rawget(BL, "__dxvbs") then
                        rawset(BL, "__dxvbs", true)
                        local old = BL.OnVoiceBanSuccess
                        BL.OnVoiceBanSuccess = function(Uid, Name, Bantime)
                            pcall(function() DXLog17("VOICE-BAN-SUKSES", Uid, Name, "durasi=" .. tostring(Bantime)) end)
                            return old(Uid, Name, Bantime)
                        end
                        n = n + 1
                    end
                    if type(BL.OnNotifyWarningTips) == "function" and not rawget(BL, "__dxwtip") then
                        rawset(BL, "__dxwtip", true)
                        local old = BL.OnNotifyWarningTips
                        BL.OnNotifyWarningTips = function(TextID, bOffMic)
                            pcall(function() DXLog17("WARNING-TIPS", nil, nil, "textID=" .. tostring(TextID) .. " offMic=" .. tostring(bOffMic)) end)
                            return old(TextID, bOffMic)
                        end
                        n = n + 1
                    end
                    if type(BL.ReqBanInfo) == "function" and not rawget(BL, "__dxreq") then
                        rawset(BL, "__dxreq", true)
                        BL.ReqBanInfo = function() return end -- status ban không bao giờ bị request
                        n = n + 1
                    end
                end
            end)
            pcall(function()
                local RPU = require("GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils")
                if type(RPU) == "table" then
                    if type(RPU.RecordFatalDamager) == "function" and not rawget(RPU, "__dxrfd") then
                        rawset(RPU, "__dxrfd", true)
                        local old = RPU.RecordFatalDamager
                        RPU.RecordFatalDamager = function(tMap, sName, sUID, bIsAI, bIsMLAI, sOriginalUID, bIsDeliver)
                            pcall(function()
                                DXLog17("KILLER (fatal damager)", sUID, sName,
                                    "ai=" .. tostring(bIsAI) .. " mlai=" .. tostring(bIsMLAI) .. " origUID=" .. tostring(sOriginalUID))
                            end)
                            return old(tMap, sName, sUID, bIsAI, bIsMLAI, sOriginalUID, bIsDeliver)
                        end
                        n = n + 1
                    end
                    if type(RPU.RecordFatalDamagerReconnect) == "function" and not rawget(RPU, "__dxrfr") then
                        rawset(RPU, "__dxrfr", true)
                        local old = RPU.RecordFatalDamagerReconnect
                        RPU.RecordFatalDamagerReconnect = function(tMap, sName, sUID, bIsAI, bIsMLAI, sOriginalUID, bIsDeliver, nOccurTime)
                            pcall(function() DXLog17("KILLER-RECONNECT", sUID, sName, "t=" .. tostring(nOccurTime)) end)
                            -- ép bIsAI = true: làm mờ bằng chứng gửi lên server
                            return old(tMap, sName, sUID, true, bIsMLAI, sOriginalUID, bIsDeliver, nOccurTime)
                        end
                        n = n + 1
                    end
                end
            end)
            if n > 0 then
                _G.DX._ACCore17Stage = 1
                DXFw("ACCORE17-1: intel ban/voice/killer aktif (" .. n .. "/7 hook)")
            end
            return
        end

        -- TAHAP 1: phá evidence/telemetry/UI report (hook 8-17)
        local n = 0
        pcall(function()
            local GRU = require("GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils")
            if type(GRU) == "table" then
                if type(GRU.ReportException) == "function" and not rawget(GRU, "__dxre") then
                    rawset(GRU, "__dxre", true)
                    GRU.ReportException = function() return true end
                    n = n + 1
                end
                if type(GRU.GetReplayRecordManager) == "function" and not rawget(GRU, "__dxgrm") then
                    rawset(GRU, "__dxgrm", true)
                    GRU.GetReplayRecordManager = function() return nil end
                    n = n + 1
                end
                if type(GRU.GetReplayRecorderByType) == "function" and not rawget(GRU, "__dxgrr") then
                    rawset(GRU, "__dxgrr", true)
                    GRU.GetReplayRecorderByType = function() return nil end
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local ok, RB = pcall(require, "GameLua.Mod.BaseMod.Client.InspectionSystem.InspectionSystemReportButton")
            if ok and type(RB) == "table" then
                if type(RB.CanReportNow) == "function" and not rawget(RB, "__dxcrn") then
                    rawset(RB, "__dxcrn", true)
                    RB.CanReportNow = function() return false end -- nút report luôn bị disable
                    n = n + 1
                end
                if type(RB.OnClickReportBtn) == "function" and not rawget(RB, "__dxocr") then
                    rawset(RB, "__dxocr", true)
                    RB.OnClickReportBtn = function() return end -- click report = noop
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local QR = require("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
            if type(QR) == "table" then
                if type(QR.SetAutoClickTime) == "function" and not rawget(QR, "__dxsact") then
                    rawset(QR, "__dxsact", true)
                    QR.SetAutoClickTime = function() return end
                    n = n + 1
                end
                if type(QR._GetAutoShowHideVictimWindow) == "function" and not rawget(QR, "__dxgasw") then
                    rawset(QR, "__dxgasw", true)
                    QR._GetAutoShowHideVictimWindow = function() return nil, false end
                    n = n + 1
                end
                if type(QR.OnShowMutualExclusiveUI) == "function" and not rawget(QR, "__dxmeu") then
                    rawset(QR, "__dxmeu", true)
                    QR.OnShowMutualExclusiveUI = function() return end
                    QR.OnHideMutualExclusiveUI = function() return end
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local VT = require("GameLua.GameCore.Module.Vehicle.VehicleFeatures.TLog.VehicleTLogFeature")
            if type(VT) == "table" then
                if type(VT.OnEnterVehicle) == "function" and not rawget(VT, "__dxvtl") then
                    rawset(VT, "__dxvtl", true)
                    VT.OnEnterVehicle = function() return end
                    VT.OnVehicleTakeDamge = function() return end
                    VT.OnCharacterPreDied = function() return end
                    n = n + 1
                end
            end
        end)
        pcall(function()
            local CR = require("GameLua.Mod.BaseMod.Client.Security.Credit.ClientInGameCreditLogic")
            if type(CR) == "table" and type(CR.ShowReturnLobbyIfFirstExitTeamBeforeBoarding) == "function" and not rawget(CR, "__dxsrl") then
                rawset(CR, "__dxsrl", true)
                CR.ShowReturnLobbyIfFirstExitTeamBeforeBoarding = function() return end
                n = n + 1
            end
        end)
        if n > 0 then
            _G.DX._ACCore17Stage = 2
            DXFw("ACCORE17-2: phá evidence/telemetry/UI report aktif (" .. n .. "/10 hook)")
        end
    end

    -- Kích hoạt ngay lần đầu
    pcall(_G.DX._ACCore17Try)
end


    end)
end

-- KICK OFF ANTI-BAN IMMEDIATELY AND RETRY ON TIMER
pcall(CompleteAntiBanSystem)
pcall(function()
    if DXFw then
        DXFw("[SYSTEM] Payload VIP Activated & Anti-Ban Engaged")
    end
end)
pcall(function()
    local ok, ticker = pcall(require, "common.time_ticker")
    if ok and ticker then
        if ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.1, CompleteAntiBanSystem)
        end
        if ticker.AddTimerLoop then
            -- Sync account info mỗi 2 giây
            ticker.AddTimerLoop(2.0, function()
                pcall(function()
                    if type(GetMainGamePlayerInfo) == "function" then
                        local mainUID, mainName = GetMainGamePlayerInfo()
                        if mainUID and mainUID ~= "UNKNOWN_ID" and mainUID ~= "0" and mainUID ~= "" then
                            if _G.DX_LastSyncedAccountID ~= mainUID then
                                _G.DX_LastSyncedAccountID = mainUID
                                if SendLogToServer then
                                    SendLogToServer("[SYSTEM] Game Account Synced: ID Game: " .. tostring(mainUID) .. " (" .. tostring(mainName) .. ")")
                                end
                            end
                        end
                    end
                end)
            end)
            -- Retry ACManipTry + ACCore17Try mỗi 10 giây (như ExtraTick trong BRPlayer)
            ticker.AddTimerLoop(10.0, function()
                if _G.DX and _G.DX._ACManipTry then pcall(_G.DX._ACManipTry) end
                if _G.DX and _G.DX._ACCore17Try then pcall(_G.DX._ACCore17Try) end
            end)
        end
    end
end)



-- ============ ADD OUTFIT MERGED (1.lua) ============
do

    local function notify(msg)
        pcall(function()
            local fn = ShowNotice or _G.ShowNotice
            if fn then fn("[AddOutfit] " .. tostring(msg), false, 10) end
        end)
    end

    local _outfitSavePathCache = nil
    local function _getOutfitSavePath()
        if _outfitSavePathCache then return _outfitSavePathCache end
        local pid = "default"
        pcall(function()
            local Subsystem = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
            local AccountSubsystem = Subsystem:Get("AccountSubsystem")
            if AccountSubsystem and AccountSubsystem.GetAccountUID then
                local uid = AccountSubsystem:GetAccountUID()
                if uid and uid ~= 0 then pid = tostring(uid) end
            end
        end)
        if pid == "default" then
            pcall(function()
                if DataMgr and DataMgr.roleData then
                    local uid = tonumber(DataMgr.roleData.uid)
                    if uid and uid ~= 0 then pid = tostring(uid) end
                end
            end)
        end
        local fileName = "AddOutfit_Save.txt"
        local legacyNames = {}
        if pid ~= "default" then legacyNames[#legacyNames + 1] = "AddOutfit_Save_" .. pid .. ".txt" end
        legacyNames[#legacyNames + 1] = "AddOutfit_Save_default.txt"
        local possibleDirs = {
            '/storage/emulated/0/Android/data/com.pubg.imobile/files/',
            '/storage/emulated/0/Android/data/com.pubg.krmobile/files/',
            '/storage/emulated/0/Android/data/com.vng.pubgmobile/files/',
            '/storage/emulated/0/Android/data/com.rekoo.pubgm/files/',
            '/Documents/ShadowTrackerExtra/Saved/Paks/',
            '/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/',
            'ShadowTrackerExtra/Saved/Paks/',
            '../../ShadowTrackerExtra/Saved/Paks/'
        }
        local isIOS = false
        pcall(function()
            isIOS = not not (_G.IOS_VERSION or _G.UIDevice)
            if not isIOS and SystemInfo and SystemInfo.GetOSName then
                local osn = SystemInfo.GetOSName()
                isIOS = type(osn) == "string" and osn:lower():find("ios", 1, true) ~= nil
            end
        end)
        if isIOS then
            table.insert(possibleDirs, 1, '/Documents/ShadowTrackerExtra/Saved/Paks/')
        end
        pcall(function()
            if os and os.getenv then
                local homeDir = os.getenv("HOME")
                if homeDir and homeDir ~= "" then
                    table.insert(possibleDirs, 1, homeDir .. '/Documents/ShadowTrackerExtra/Saved/Paks/')
                end
            end
        end)
        for _, dir in ipairs(possibleDirs) do
            local f = io.open(dir .. fileName, 'r')
            if f then
                local c = f:read('*a')
                f:close()
                if c and c ~= "" then
                    _outfitSavePathCache = dir .. fileName
                    return _outfitSavePathCache
                end
            end
        end
        for _, dir in ipairs(possibleDirs) do
            for _, legacy in ipairs(legacyNames) do
                local f = io.open(dir .. legacy, 'r')
                if f then
                    local content = f:read('*a')
                    f:close()
                    if content and content ~= "" then
                        local target = dir .. fileName
                        local fw = io.open(target, 'w')
                        if fw then
                            fw:write(content)
                            fw:close()
                            _outfitSavePathCache = target
                            return _outfitSavePathCache
                        end
                    end
                end
            end
        end
        for _, dir in ipairs(possibleDirs) do
            local probe = dir .. ".ao_write_probe"
            local f = io.open(probe, 'w')
            if f then
                f:write('1')
                f:close()
                os.remove(probe)
                _outfitSavePathCache = dir .. fileName
                return _outfitSavePathCache
            end
        end
        _outfitSavePathCache = possibleDirs[1] .. fileName
        return _outfitSavePathCache
    end

        local function _saveEquippedCache()
            local wrote = false
            pcall(function()
                local cch = _G.AddOutfitEquippedCache
                if not cch then return end
                local path = _getOutfitSavePath()
                if not path then return end
            local lines = {}
            if cch.outfitRes then lines[#lines + 1] = "outfitRes=" .. tostring(cch.outfitRes) end
            if cch.outfitIns then lines[#lines + 1] = "outfitIns=" .. tostring(cch.outfitIns) end
            local clothIds = {}
            for resID in pairs(cch.clothes or {}) do
                clothIds[#clothIds + 1] = tostring(resID)
            end
            if #clothIds > 0 then
                lines[#lines + 1] = "clothes=" .. table.concat(clothIds, ",")
            end
            local eq = cch.equip or {}
            if eq.bag then lines[#lines + 1] = "equip_bag=" .. tostring(eq.bag) end
            if eq.helmet then lines[#lines + 1] = "equip_helmet=" .. tostring(eq.helmet) end
            if eq.armor then lines[#lines + 1] = "equip_armor=" .. tostring(eq.armor) end
            if eq.parachute then lines[#lines + 1] = "equip_parachute=" .. tostring(eq.parachute) end
            if eq.glider then lines[#lines + 1] = "equip_glider=" .. tostring(eq.glider) end
            if eq.bagIns then lines[#lines + 1] = "equip_bagIns=" .. tostring(eq.bagIns) end
            if eq.helmetIns then lines[#lines + 1] = "equip_helmetIns=" .. tostring(eq.helmetIns) end
            if eq.armorIns then lines[#lines + 1] = "equip_armorIns=" .. tostring(eq.armorIns) end
            if eq.parachuteIns then lines[#lines + 1] = "equip_parachuteIns=" .. tostring(eq.parachuteIns) end
            if eq.gliderIns then lines[#lines + 1] = "equip_gliderIns=" .. tostring(eq.gliderIns) end
            for wid, w in pairs(cch.weapons or {}) do
                wid = tonumber(wid)
                local wr = tonumber(w and w.resID) or 0
                if wid and wr > 0 and not (wr == wid and not isInjectedRes(wr)) then
                    lines[#lines + 1] = "weapon_" .. tostring(wid) .. "=" .. tostring(wr) .. ":" .. tostring(w.insID or 0)
                end
            end
            pcall(function()
                if DataMgr and DataMgr.MotionSlotList then
                    local parts = {}
                    for _, ins in ipairs(DataMgr.MotionSlotList) do
                        ins = tonumber(ins)
                        if ins and ins > 0 then parts[#parts + 1] = tostring(ins) end
                    end
                    if #parts > 0 then lines[#lines + 1] = "motion=" .. table.concat(parts, ",") end
                end
            end)
            pcall(function()
                local AvatarData = require("client.logic.data.AvatarData")
                local parts = {}
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    ins = tonumber(ins)
                    if ins and ins > 0 then parts[#parts + 1] = tostring(ins) end
                end
                if #parts > 0 then lines[#lines + 1] = "rolewear=" .. table.concat(parts, ",") end
            end)
            pcall(function()
                if DataMgr and DataMgr.equipmentSkinInsIDTable then
                    for subType, ins in pairs(DataMgr.equipmentSkinInsIDTable) do
                        ins = tonumber(ins)
                        if ins and ins > 0 then
                            lines[#lines + 1] = "equipins_" .. tostring(subType) .. "=" .. tostring(ins)
                        end
                    end
                end
            end)
            pcall(function()
                if DataMgr and DataMgr.vst_skin then
                    local ins = tonumber(DataMgr.vst_skin)
                    if ins and ins > 0 then lines[#lines + 1] = "vst_skin=" .. tostring(ins) end
                end
            end)
            pcall(function()
                local HT = require("client.logic.lobby.hall_theme_utils")
                local ins = tonumber(HT.GetThemeInstId and HT.GetThemeInstId()) or 0
                if ins > 0 then
                    lines[#lines + 1] = "hall_theme_ins=" .. tostring(ins)
                    local res = tonumber(HT.homeThemeItemId) or 0
                    if res <= 0 and _G.AddOutfit_R and _G.AddOutfit_R.insToRes then
                        res = tonumber(_G.AddOutfit_R.insToRes[ins]) or 0
                    end
                    if res > 0 then lines[#lines + 1] = "hall_theme_res=" .. tostring(res) end
                end
            end)
            pcall(function()
                if DataMgr and DataMgr.VehicleSlotList then
                    for subType, insList in pairs(DataMgr.VehicleSlotList) do
                        if insList and type(insList) == "table" then
                            local parts = {}
                            for _, ins in ipairs(insList) do
                                ins = tonumber(ins)
                                if ins and ins > 0 then parts[#parts + 1] = tostring(ins) end
                            end
                            if #parts > 0 then
                                lines[#lines + 1] = "vehicle_" .. tostring(subType) .. "=" .. table.concat(parts, ",")
                            end
                        end
                    end
                end
            end)
            pcall(function()
                local GTS = ModuleManager and ModuleManager.GetModule
                    and ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if GTS and GTS.GarageVehicleInfo then
                    for slot, info in pairs(GTS.GarageVehicleInfo) do
                        if info and info.inst_id then
                            lines[#lines + 1] = "garage_" .. tostring(slot) .. "="
                                .. tostring(info.inst_id) .. ":" .. tostring(info.res_id or 0)
                        end
                    end
                end
            end)
            pcall(function()
                local cch2 = _G.AddOutfitEquippedCache
                if cch2 and cch2.throwObjects then
                    for st, info in pairs(cch2.throwObjects) do
                        if info.resID and info.resID > 0 then
                            lines[#lines + 1] = "throw_" .. tostring(st) .. "=" .. tostring(info.resID) .. ":" .. tostring(info.insID or 0)
                        end
                    end
                end
            end)
            pcall(function()
                local nWeapon, nCloth, nOutfit = 0, 0, 0
                for _, ln in ipairs(lines) do
                    if ln:match("^weapon_") then nWeapon = nWeapon + 1
                    elseif ln:match("^clothes=") then nCloth = nCloth + 1
                    elseif ln:match("^outfit") then nOutfit = nOutfit + 1 end
                end
                report("saveWrite: total=" .. #lines .. " weapon=" .. nWeapon .. " clothes=" .. nCloth .. " outfit=" .. nOutfit)
            end)
            local content = table.concat(lines, "\n")
            local tmp = path .. ".tmp"
            local f = io.open(tmp, 'w+')
            if f then
                f:write(content)
                f:close()
                local okR = os.rename(tmp, path)
                if not okR then
                    os.remove(path)
                    okR = os.rename(tmp, path)
                end
                if not okR then
                    local f2 = io.open(path, 'w+')
                    if f2 then f2:write(content); f2:close() end
                end
            else
                local f3 = io.open(path, 'w+')
                if not f3 then return end
                f3:write(content)
                f3:close()
            end
            wrote = true
        end)
        return wrote
    end

    local _snapHeavyT = 0
    local _snapHeavyPart = ""
    local function _snapshotHeavyPart()
        local now = 0
        pcall(function() now = os.clock() end)
        if (now - _snapHeavyT) < 1.5 then return _snapHeavyPart end
        local parts = {}
        pcall(function()
            if DataMgr then
                parts[#parts + 1] = "vst=" .. tostring(tonumber(DataMgr.vst_skin) or 0)
                if DataMgr.equipmentSkinInsIDTable then
                    local ids = {}
                    for subType, ins in pairs(DataMgr.equipmentSkinInsIDTable) do
                        ins = tonumber(ins)
                        if ins and ins > 0 then ids[#ids + 1] = tostring(subType) .. ":" .. tostring(ins) end
                    end
                    table.sort(ids)
                    parts[#parts + 1] = "equipins=" .. table.concat(ids, ",")
                end
                if DataMgr.MotionSlotList then
                    local ids = {}
                    for _, ins in ipairs(DataMgr.MotionSlotList) do
                        ins = tonumber(ins)
                        if ins and ins > 0 then ids[#ids + 1] = tostring(ins) end
                    end
                    table.sort(ids)
                    parts[#parts + 1] = "motion=" .. table.concat(ids, ",")
                end
                if DataMgr.VehicleSlotList then
                    local ids = {}
                    for subType, insList in pairs(DataMgr.VehicleSlotList) do
                        if insList and type(insList) == "table" then
                            for _, ins in ipairs(insList) do
                                ins = tonumber(ins)
                                if ins and ins > 0 then ids[#ids + 1] = tostring(subType) .. ":" .. tostring(ins) end
                            end
                        end
                    end
                    table.sort(ids)
                    parts[#parts + 1] = "vehicle=" .. table.concat(ids, ",")
                end
            end
        end)
        pcall(function()
            local AvatarData = require("client.logic.data.AvatarData")
            local ids = {}
            for _, ins in pairs(AvatarData.GetRoleWear()) do
                ins = tonumber(ins)
                if ins and ins > 0 then ids[#ids + 1] = tostring(ins) end
            end
            table.sort(ids)
            parts[#parts + 1] = "rolewear=" .. table.concat(ids, ",")
        end)
        pcall(function()
            local HT = require("client.logic.lobby.hall_theme_utils")
            local ins = tonumber(HT.GetThemeInstId and HT.GetThemeInstId()) or 0
            local res = tonumber(HT.homeThemeItemId) or 0
            parts[#parts + 1] = "theme=" .. tostring(ins) .. ":" .. tostring(res)
        end)
        _snapHeavyPart = table.concat(parts, "|")
        _snapHeavyT = now
        return _snapHeavyPart
    end

    local function _snapshotCache()
        local cch = _G.AddOutfitEquippedCache
        if not cch then return "" end
        local parts = {}
        parts[#parts + 1] = tostring(cch.outfitRes or 0)
        local clothIds = {}
        for resID in pairs(cch.clothes or {}) do
            clothIds[#clothIds + 1] = resID
        end
        table.sort(clothIds, function(a, b)
            local an, bn = tonumber(a), tonumber(b)
            if an and bn then return an < bn end
            return tostring(a) < tostring(b)
        end)
        parts[#parts + 1] = table.concat(clothIds, ",")
        local eq = cch.equip or {}
        parts[#parts + 1] = tostring(eq.bag or 0)
        parts[#parts + 1] = tostring(eq.helmet or 0)
        parts[#parts + 1] = tostring(eq.armor or 0)
        parts[#parts + 1] = tostring(eq.parachute or 0)
        parts[#parts + 1] = tostring(eq.glider or 0)
        local wIds = {}
        for wid in pairs(cch.weapons or {}) do wIds[#wIds + 1] = wid end
        table.sort(wIds, function(a, b)
            local an, bn = tonumber(a), tonumber(b)
            if an and bn then return an < bn end
            return tostring(a) < tostring(b)
        end)
        for _, wid in ipairs(wIds) do
            local w = cch.weapons[wid]
            parts[#parts + 1] = tostring(wid) .. ":" .. tostring(w and w.resID or 0)
        end
        if cch.throwObjects then
            local tIds = {}
            for st in pairs(cch.throwObjects) do tIds[#tIds + 1] = st end
            table.sort(tIds, function(a, b)
                local an, bn = tonumber(a), tonumber(b)
                if an and bn then return an < bn end
                return tostring(a) < tostring(b)
            end)
            for _, st in ipairs(tIds) do
                local info = cch.throwObjects[st]
                parts[#parts + 1] = "throw_" .. tostring(st) .. ":" .. tostring(info and info.resID or 0)
            end
        end
        parts[#parts + 1] = _snapshotHeavyPart()
        return table.concat(parts, "|")
    end

    local _lastSnapshot = ""

    local function _loadEquippedCache()
        pcall(function()
            local path = _getOutfitSavePath()
            if not path then return end
            local file = io.open(path, 'r')
            if not file then return end
            local content = file:read('*a')
            file:close()
            if not content or content == "" then return end

            _G._savedOutfitClothes = {}
            _G._savedOutfitRes = nil
            _G._savedOutfitIns = nil
            _G._savedOutfitEquip = {}
            _G._savedVehicleSlotList = {}
            _G._savedGarageVehicles = {}
            _G._savedMotionList = {}
            _G._savedRoleWearList = {}
            _G._savedEquipIns = {}
            _G._savedVstSkin = nil
            _G._savedHallThemeIns = nil
            _G._savedHallThemeRes = nil
            _G._savedThrowObjects = {}

            for line in content:gmatch("[^\n]+") do
                local key, val = line:match("^(.-)=(.+)$")
                if key and val then
                    if key == "outfitRes" then _G._savedOutfitRes = tonumber(val)
                    elseif key == "outfitIns" then _G._savedOutfitIns = tonumber(val)
                    elseif key == "clothes" then
                        for id in val:gmatch("([^,]+)") do
                            _G._savedOutfitClothes[tonumber(id)] = true
                        end
                    elseif key == "equip_bag" then _G._savedOutfitEquip.bag = tonumber(val)
                    elseif key == "equip_helmet" then _G._savedOutfitEquip.helmet = tonumber(val)
                    elseif key == "equip_armor" then _G._savedOutfitEquip.armor = tonumber(val)
                    elseif key == "equip_parachute" then _G._savedOutfitEquip.parachute = tonumber(val)
                    elseif key == "equip_glider" then _G._savedOutfitEquip.glider = tonumber(val)
                    elseif key == "equip_bagIns" then _G._savedOutfitEquip.bagIns = tonumber(val)
                    elseif key == "equip_helmetIns" then _G._savedOutfitEquip.helmetIns = tonumber(val)
                    elseif key == "equip_armorIns" then _G._savedOutfitEquip.armorIns = tonumber(val)
                    elseif key == "equip_parachuteIns" then _G._savedOutfitEquip.parachuteIns = tonumber(val)
                    elseif key == "equip_gliderIns" then _G._savedOutfitEquip.gliderIns = tonumber(val)
                    elseif key == "motion" then
                        for ins in val:gmatch("([^,]+)") do
                            ins = tonumber(ins)
                            if ins and ins > 0 then _G._savedMotionList[#_G._savedMotionList + 1] = ins end
                        end
                    elseif key == "rolewear" then
                        for ins in val:gmatch("([^,]+)") do
                            ins = tonumber(ins)
                            if ins and ins > 0 then _G._savedRoleWearList[#_G._savedRoleWearList + 1] = ins end
                        end
                    elseif key:match("^equipins_(%d+)$") then
                        local subType = tonumber(key:match("^equipins_(%d+)$"))
                        if subType then _G._savedEquipIns[subType] = tonumber(val) end
                    elseif key == "vst_skin" then _G._savedVstSkin = tonumber(val)
                    elseif key == "hall_theme_ins" then _G._savedHallThemeIns = tonumber(val)
                    elseif key == "hall_theme_res" then _G._savedHallThemeRes = tonumber(val)
                    elseif key:match("^weapon_(.+)$") then
                        local wid = tonumber(key:match("^weapon_(.+)$"))
                        local resID, insID = val:match("^(.-):(.+)$")
                        if wid and resID then
                            local wr = tonumber(resID)
                            if wr and wr > 0 and not (wr == wid and not isInjectedRes(wr)) then
                                _G._savedOutfitEquip["weapon_" .. wid] = { resID = wr, insID = tonumber(insID) or 0 }
                            end
                        end
                    elseif key:match("^vehicle_(%d+)$") then
                        local subType = tonumber(key:match("^vehicle_(%d+)$"))
                        if subType then
                            local list = {}
                            for ins in val:gmatch("([^,]+)") do
                                ins = tonumber(ins)
                                if ins and ins > 0 then list[#list + 1] = ins end
                            end
                            if #list > 0 then _G._savedVehicleSlotList[subType] = list end
                        end
                    elseif key:match("^garage_(%d+)$") then
                        local slot = tonumber(key:match("^garage_(%d+)$"))
                        local insID, resID = val:match("^(.-):(.+)$")
                        if slot and insID then
                            _G._savedGarageVehicles[slot] = {
                                inst_id = tonumber(insID),
                                res_id = tonumber(resID) or 0,
                            }
                        end
                    elseif key:match("^throw_(%d+)$") then
                        local st = tonumber(key:match("^throw_(%d+)$"))
                        if st then
                            local resID, insID = val:match("^(.-):(.+)$")
                            _G._savedThrowObjects[st] = { resID = tonumber(resID), insID = tonumber(insID) or 0 }
                        end
                    end
                end
            end

            if not _G.AddOutfitEquippedCache then
                _G.AddOutfitEquippedCache = {
                    outfitRes = nil, outfitIns = nil,
                    clothes = {}, equip = {}, weapons = {},
                }
            end
            local cch = _G.AddOutfitEquippedCache
            cch.clothes = cch.clothes or {}
            cch.equip = cch.equip or {}
            cch.weapons = cch.weapons or {}

            if _G._savedOutfitRes then
                cch.outfitRes = _G._savedOutfitRes
                cch.outfitIns = _G._savedOutfitIns
            end
            if not _G._addOutfitPersistLoaded and _G._savedOutfitClothes then
                for resID in pairs(_G._savedOutfitClothes) do
                    local st = subType(cfg(resID))
                    if st then
                        for oldRes in pairs(cch.clothes) do
                            if subType(cfg(oldRes)) == st then cch.clothes[oldRes] = nil end
                        end
                    end
                    cch.clothes[resID] = true
                end
            end

            if _G._savedOutfitEquip then
                for k, v in pairs(_G._savedOutfitEquip) do
                    if k == "bag" then cch.equip.bag = v
                    elseif k == "helmet" then cch.equip.helmet = v
                    elseif k == "armor" then cch.equip.armor = v
                    elseif k == "parachute" then cch.equip.parachute = v
                    elseif k == "glider" then cch.equip.glider = v
                    elseif k == "bagIns" then cch.equip.bagIns = v
                    elseif k == "helmetIns" then cch.equip.helmetIns = v
                    elseif k == "armorIns" then cch.equip.armorIns = v
                    elseif k == "parachuteIns" then cch.equip.parachuteIns = v
                    elseif k == "gliderIns" then cch.equip.gliderIns = v
                    elseif type(k) == "string" and k:match("^weapon_(.+)$") then
                        local wid = tonumber(k:match("^weapon_(.+)$"))
                        if wid then cch.weapons[wid] = v end
                    end
                end
            end

            if _G._savedThrowObjects then
                cch.throwObjects = cch.throwObjects or {}
                for st, info in pairs(_G._savedThrowObjects) do
                    if info.resID and info.resID > 0 then
                        cch.throwObjects[st] = info
                    end
                end
            end

            _G._addOutfitPersistLoaded = true
            pcall(function() _lastSnapshot = _snapshotCache() end)
            print("[AddOutfit] Loaded saved IDs from file:", path)
        end)
    end

    local _saveDirty = false
    local _saveInProgress = false
    local _lastSaveClock = 0
    local SAVE_MIN_INTERVAL = 2.5

    local function _flushSave(force)
        pcall(function() report("flushCall: force=" .. tostring(force) .. " dirty=" .. tostring(_saveDirty) .. " inProg=" .. tostring(_saveInProgress)) end)
        if _saveInProgress then
            _saveDirty = true
            return
        end
        local now = 0
        pcall(function() now = os.clock() end)
        if not force and _lastSaveClock > 0 and (now - _lastSaveClock) < SAVE_MIN_INTERVAL then
            _saveDirty = true
            return
        end
        _saveInProgress = true
        _saveDirty = false
        pcall(function()
            pcall(function()
                if _G.AddOutfitSyncCacheBeforeSave then _G.AddOutfitSyncCacheBeforeSave() end
            end)
            local newSnap
            pcall(function()
                newSnap = _snapshotCache()
            end)
            if newSnap == nil then
                pcall(function() report("flush SNAP ERR") end)
                newSnap = _lastSnapshot
            end
            pcall(function()
                local dch = _G.AddOutfitEquippedCache
                local nCl, nW, nRW, nTh = 0, 0, 0, 0
                if dch then
                    if dch.clothes then for _ in pairs(dch.clothes) do nCl = nCl + 1 end end
                    if dch.weapons then for _ in pairs(dch.weapons) do nW = nW + 1 end end
                    if dch.throwObjects then for _ in pairs(dch.throwObjects) do nTh = nTh + 1 end end
                end
                pcall(function()
                    local AD = require("client.logic.data.AvatarData")
                    local t = AD.GetRoleWear and AD.GetRoleWear()
                    if t then for _ in pairs(t) do nRW = nRW + 1 end end
                end)
                report("flush: outfit=" .. tostring(dch and dch.outfitRes or 0)
                    .. " clothes=" .. nCl .. " weapons=" .. nW
                    .. " rolewear=" .. nRW .. " throw=" .. nTh
                    .. " changed=" .. tostring(newSnap ~= _lastSnapshot))
            end)
            if newSnap ~= _lastSnapshot then
                local okW, wrote = pcall(_saveEquippedCache)
                if okW and wrote then _lastSnapshot = newSnap end
            end
            local cch2 = _G.AddOutfitEquippedCache
            if cch2 then
                _G._savedOutfitRes = tonumber(cch2.outfitRes) and cch2.outfitRes > 0 and cch2.outfitRes or nil
                _G._savedOutfitIns = tonumber(cch2.outfitIns) and cch2.outfitIns > 0 and cch2.outfitIns or nil
                _G._savedOutfitClothes = {}
                for resID in pairs(cch2.clothes or {}) do
                    _G._savedOutfitClothes[resID] = true
                end
            end
        end)
        pcall(function() _lastSaveClock = os.clock() end)
        _saveInProgress = false
    end

    local _saveDeferred = false
    local function _AutoSaveOutfit(force)
        if force then
            _flushSave(true)
            return
        end
        _saveDirty = true
        if _saveDeferred then return end
        _saveDeferred = true
        local function _doDeferredFlush()
            _saveDeferred = false
            if _saveDirty then _flushSave(false) end
        end
        local ok = pcall(_G.SetTimer, 0.5, _doDeferredFlush)
        if not ok then _doDeferredFlush() end
    end

    _G.AddOutfitTryFlushSave = function()
        if _saveDirty then _flushSave(false) end
    end

    -- ========== حقن WardrobeNewHandler (لإصلاح حفظ السيارات في اللوبي) ==========
    pcall(function()
        local WardrobeNewHandler = {}

        local _bShowNotice = false

        local _ao_R = nil
        local function getR()
            if _ao_R then return _ao_R end
            _ao_R = _G.AddOutfit_R
            return _ao_R
        end
        local function aoIsInjectedIns(ins)
            ins = tonumber(ins)
            if not ins then return false end
            local R = getR()
            return R and R.insToRes[ins] ~= nil
        end

        function WardrobeNewHandler.send_depot_modify_combat_vehicle_req(insID, slotIndex, bShowNotice)
            insID = tonumber(insID)
            slotIndex = tonumber(slotIndex) or 1
            _bShowNotice = bShowNotice
            if aoIsInjectedIns(insID) then
                local R = getR()
                local resID = R and R.insToRes[insID]
                local itemSubType = 0
                if resID and CDataTable and CDataTable.GetTableData then
                    local c = CDataTable.GetTableData("Item", resID)
                    itemSubType = c and tonumber(c.ItemSubType or c.itemSubType) or 0
                end
                if itemSubType and itemSubType > 0 and DataMgr then
                    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
                    local slotList = DataMgr.VehicleSlotList[itemSubType] or {}
                    if bShowNotice then
                        for i = #slotList, 1, -1 do
                            if slotList[i] == insID then
                                table.remove(slotList, i)
                            end
                        end
                        slotList[slotIndex] = insID
                    else
                        for i, sid in ipairs(slotList) do
                            if sid == insID then
                                table.remove(slotList, i)
                                break
                            end
                        end
                    end
                    DataMgr.VehicleSlotList[itemSubType] = slotList
                end
                pcall(function()
                    local tabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
                    if tabSurveillance and tabSurveillance.VehicleChange then
                        tabSurveillance.VehicleChange()
                    end
                end)
                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE)
                end
                pcall(_AutoSaveOutfit)
                return
            end
            local NetManager = require("client.network.comm.NetManager")
            NetManager.SendPkg(1012780591, insID, slotIndex, bShowNotice)
        end

        function WardrobeNewHandler.on_depot_modify_combat_vehicle_rsp(ret_code, vehicle_info)
            if ret_code ~= 0 and ret_code ~= NetErrorCode_NONE then
                if _bShowNotice and ShowNotice then ShowNotice(ret_code) end
                return
            end
            if vehicle_info and DataMgr then
                DataMgr.VehicleSlotList = vehicle_info
            end
            pcall(function()
                local tabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
                if tabSurveillance and tabSurveillance.VehicleChange then
                    tabSurveillance.VehicleChange()
                end
            end)
            if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE)
            end
        end

        function WardrobeNewHandler.send_select_item(insID)
            local NetManager = require("client.network.comm.NetManager")
            NetManager.SendPkg(595484784, insID)
        end

        function WardrobeNewHandler.send_equip_motion_list_req(motion_list)
            local NetManager = require("client.network.comm.NetManager")
            NetManager.SendPkg(1124239581, motion_list)
        end

        package.loaded["client.network.Protocol.WardrobeNewHandler"] = WardrobeNewHandler
        print("[AddOutfit] WardrobeNewHandler injected into package.loaded")
    end)

    local _ao_ok, _ao_err = pcall(function()
        pcall(function()
            local w = WriteReportToPaksFile or _G.WriteReportToPaksFile
            if w then
                w("[AddOutfit] init start")
            end
        end)
        -- Per-match guard using match counter (handles controller reuse across matches)
        do
            local curMatchID = ""
            pcall(function()
                local GD = require("GameLua.GameCore.Data.GameplayData")
                if GD and GD.GetPlayerController then
                    local pc = GD.GetPlayerController()
                    if pc and slua.isValid(pc) then
                        -- Use the player key + timestamp as unique match ID
                        curMatchID = tostring(pc.PlayerKey or "") .. "_" .. tostring(pc)
                    end
                end
            end)
            if curMatchID == "" then
                _G._AO_MATCH_ID = nil
            elseif _G._AO_MATCH_ID == curMatchID then
                return  -- Already loaded for this match
            else
                _G._AO_MATCH_ID = curMatchID
            end
        end
        pcall(function() require("game_frontend_hud") end)

        local DEBUG = true
        local function isInMatchOrGame()
            local ok, r = pcall(function()
                if GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus() then
                    return true
                end
                if GameStatus and GameStatus.IsInLobbyOrMainCity and not GameStatus.IsInLobbyOrMainCity() then
                    return true
                end
            end)
            return ok and r == true
        end
        local function log(...)
            print("[AddOutfit]", ...)
        end

        local function report(msg)
            pcall(function()
                local w = WriteReportToPaksFile or _G.WriteReportToPaksFile
                if w then
                    w("[AddOutfit] " .. tostring(msg))
                end
            end)
        end

        local MATCH_CONFIG = {
            outfitRes = 0,
            weaponSkins = {},
            equip = { bag = 0, helmet = 0, armor = 0 },
        }

        local ITEMS = {}
        local _itemsLoaded = false  -- منع إعادة تحميل العناصر

        -- بناء خرائط "الحدّ الأقصى للمستوى" لمجموعات الترقية (أسلحة/معدّات) وعصور X-Suit
        -- النتيجة: مجموعة من المعرفات التي يجب استبعادها لأنها ليست أعلى لفل ضمن سلسلتها
        local function buildNonMaxLevelSet()
            local nonMax = {}
            if not (CDataTable and CDataTable.GetTable) then return nonMax end

            -- 1) جدول ترقية العناصر (أسلحة + خوذ/شنط/درع التي تستخدم نفس الآلية)
            pcall(function()
                local upTbl = CDataTable.GetTable("ItemUpgradeConfig")
                if not upTbl then return end
                -- لكل GroupID: أوجد أعلى Level + معرف العنصر صاحبه
                local maxLvl, maxItem = {}, {}
                local groupMembers = {}
                for _, cfg in pairs(upTbl) do
                    local gid   = tonumber(cfg.GroupID)
                    local lvl   = tonumber(cfg.Level)
                    local itm   = tonumber(cfg.ItemID)
                    if gid and lvl and itm then
                        if not groupMembers[gid] then groupMembers[gid] = {} end
                        groupMembers[gid][#groupMembers[gid] + 1] = itm
                        if not maxLvl[gid] or lvl > maxLvl[gid] then
                            maxLvl[gid] = lvl
                            maxItem[gid] = itm
                        end
                    end
                end
                for gid, members in pairs(groupMembers) do
                    local topItem = maxItem[gid]
                    for _, itm in ipairs(members) do
                        if itm ~= topItem then nonMax[itm] = true end
                    end
                end
            end)

            -- 2) إعدادات بدلات X-Suit (Star levels)
            local function processXSuitTable(tableName)
                pcall(function()
                    local tbl = CDataTable.GetTable(tableName)
                    if not tbl then return end
                    local maxStar, maxItem = {}, {}
                    local periodMembers = {}
                    for _, data in pairs(tbl) do
                        local period = tonumber(data.Period or data.period)
                        local star   = tonumber(data.Star or data.star or data.Level or data.level)
                        local itm    = tonumber(data.ItemID or data.itemID or data.ItemId)
                        if period and star and itm then
                            if not periodMembers[period] then periodMembers[period] = {} end
                            periodMembers[period][#periodMembers[period] + 1] = itm
                            if not maxStar[period] or star > maxStar[period] then
                                maxStar[period] = star
                                maxItem[period] = itm
                            end
                        end
                    end
                    for period, members in pairs(periodMembers) do
                        local topItem = maxItem[period]
                        for _, itm in ipairs(members) do
                            if itm ~= topItem then nonMax[itm] = true end
                        end
                    end
                end)
            end
            processXSuitTable("GoldenSuitUpgradeCfg")
            processXSuitTable("GoldenSuitUpgradeCfgKJ")
            processXSuitTable("GoldenSuitUpgradeCfgIN")

            -- 3) خوذ وشنط قابلة للترقية (BackpackMapping: Lv1/Lv2/Lv3 → نُبقي Lv3 فقط)
            pcall(function()
                local bpMap = CDataTable.GetTable("BackpackMapping")
                if not bpMap then return end
                for _, m in pairs(bpMap) do
                    local lv3 = tonumber(m.SkinItemIDLv3 or 0) or 0
                    local lv1 = tonumber(m.SkinItemIDLv1 or 0) or 0
                    local lv2 = tonumber(m.SkinItemIDLv2 or 0) or 0
                    if lv1 > 0 and lv1 ~= lv3 then nonMax[lv1] = true end
                    if lv2 > 0 and lv2 ~= lv3 then nonMax[lv2] = true end
                end
            end)

            return nonMax
        end

        local function refreshItems()
            if _itemsLoaded then return #ITEMS end
            if #ITEMS > 0 then return #ITEMS end
            local ItemTable = CDataTable and CDataTable.GetTable and CDataTable.GetTable("Item")
            if not ItemTable then return 0 end
            local nonMax = buildNonMaxLevelSet()
            local seen, count, skipped = {}, 0, 0
            for id, v in pairs(ItemTable) do
                local rid = tonumber(v.ID or v.Id or id)
                if rid and rid > 0 and not seen[rid] then
                    local bpId = tonumber(v.BPID or v.bpID or v.BpId or 0) or 0
                    local mainTab = tonumber(v.WardrobeMainTab or v.wardrobeMainTab or 0) or 0
                    if bpId ~= 0 or mainTab ~= 0 then
                        seen[rid] = true
                        if nonMax[rid] then
                            skipped = skipped + 1
                        else
                            ITEMS[#ITEMS + 1] = rid
                            count = count + 1
                        end
                    end
                end
            end
            table.sort(ITEMS)
            if count > 0 then
                _itemsLoaded = true
                log("جمع تلقائي", count, "عنصر للحقن", "(تم تجاهل", skipped, "نسخة ليست أعلى لفل)")
            end
            return count
        end

        local _K = {
            INS_BASE = 2000000000, PKG_SLOT = 3, MELEE_ID = 108,
            GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true },
            NET_OK = NetErrorCode_NONE or "ok",
            GUN_MASTER_SYN_SLOT = 7,
            THROW_SUB = { [612] = "shoulei", [613] = "smoke", [614] = "stun", [615] = "burn" },
            THROW_AVATAR_KEY = { shoulei = "GrenadeAvatarShoulei", smoke = "GrenadeAvatarSmoke", stun = "GrenadeAvatarStun", burn = "GrenadeAvatarBurn" },
        }

        local R = { insToRes = {}, resToIns = {} }
        local _injectedResSet = {}
        for _, rid in ipairs(ITEMS) do _injectedResSet[rid] = true end

        local _C = { cfg = {}, fullSuit = {}, equipSlot = {}, weaponId = {}, itemTab = {}, vehicleItems = {}, pageMatch = {} }

        local _S = {
            matchApplied = false, matchTimer = nil, matchOutfitDone = false,
            avatarItemsRegistered = false, weaponApplied = false, weaponDiagDone = false,
            lastWeaponResID = 0, weaponSpawnHooked = false, bootstrapNotified = false,
            globalFrame = 0, weaponHookGuardUntil = 0, equipSkinApplying = false,
            injectedDone = false, lastAppliedWeaponID = 0, lastAppliedSkinID = 0,
            bootstrapped = false, lobbyApplied = false,
        }

        _G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
        _G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}
        _G.AddOutfitLastLobbyOutfitRes = _G.AddOutfitLastLobbyOutfitRes or nil

        _K.ST_TOP     = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Package_Slot) or 403
        _K.ST_PANTS   = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Pants_Slot) or 404
        _K.ST_SHOES   = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Shoes_Slot) or 405
        _K.ST_UNDER_T = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.UnderCloth) or 450
        _K.ST_UNDER_P = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.UnderPants) or 451
        _K.WARDROBE_TAB_SUIT, _K.WARDROBE_TAB_CLOTHES = 10, 3
        _K.WARDROBE_TAB_TROUSERS, _K.WARDROBE_TAB_SHOES = 4, 5
        _K.WARDROBE_TAB_BAG, _K.WARDROBE_TAB_HELMET, _K.WARDROBE_TAB_ARMOR = 15, 16, 17
        _K.WARDROBE_TAB_GUN, _K.WARDROBE_TAB_PARACHUTE = 9, 7
        _K.WARDROBE_TAB_GLIDER = 20
        _K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_PAGE_WEAPON, _K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_PAGE_VEHICLE = 1, 4, 5, 6
        pcall(function()
            local wm = require("client.slua.umg.Wardrobe.wardrobe_macro")
            local t = wm.ENUM_WardrobeSubTabString
            _K.WARDROBE_TAB_SUIT = t.ENUM_WardrobeSubTabString_suit
            _K.WARDROBE_TAB_CLOTHES = t.ENUM_WardrobeSubTabString_clothes
            _K.WARDROBE_TAB_TROUSERS = t.ENUM_WardrobeSubTabString_trousers
            _K.WARDROBE_TAB_SHOES = t.ENUM_WardrobeSubTabString_shoes
            _K.WARDROBE_TAB_BAG = t.ENUM_WardrobeSubTabString_bag
            _K.WARDROBE_TAB_HELMET = t.ENUM_WardrobeSubTabString_helmet
            _K.WARDROBE_TAB_ARMOR = t.ENUM_WardrobeSubTabString_armor
            _K.WARDROBE_TAB_GUN = t.ENUM_WardrobeSubTabString_gun
            _K.WARDROBE_TAB_PARACHUTE = t.ENUM_WardrobeSubTabString_parachute
            _K.WARDROBE_TAB_GLIDER = t.ENUM_WardrobeSubTabString_effect
            _K.WARDROBE_PAGE_AVATAR = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Avatar
            _K.WARDROBE_PAGE_WEAPON = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Weapon
            _K.WARDROBE_PAGE_PARACHUTE = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Parachute
            _K.WARDROBE_PAGE_VEHICLE = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Vehicle
        end)

        local FULL_SUIT_CLEAR_ST = {
            [_K.ST_TOP] = true, [_K.ST_PANTS] = true, [_K.ST_SHOES] = true,
            [_K.ST_UNDER_T] = true, [_K.ST_UNDER_P] = true,
        }

        local function cache()
            _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
                outfitRes = nil, outfitIns = nil,
                clothes = {},
                equip = {},
                weapons = {},
            }
            return _G.AddOutfitEquippedCache
        end

        local function cfg(resID)
            if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
            resID = tonumber(resID)
            if not resID then return nil end
            if _C.cfg[resID] ~= nil then return _C.cfg[resID] end
            local c = CDataTable.GetTableData("Item", resID)
            _C.cfg[resID] = c
            return c
        end

        local function subType(c)
            return c and (c.ItemSubType or c.itemSubType) or nil
        end

        local function isThrowObjectRes(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local c = cfg(resID)
            if not c then return nil end
            local st = tonumber(c.ItemSubType or c.itemSubType or 0)
            if _K.THROW_SUB[st] then return st end
            return nil
        end

        local function saveThrowObject(resID, insID)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID then return end
            local st = isThrowObjectRes(resID)
            if not st then return end
            local cch = cache()
            cch.throwObjects = cch.throwObjects or {}
            cch.throwObjects[st] = { resID = resID, insID = insID or R.resToIns[resID] or 0 }
        end

        local function isInjectedIns(ins)
            return ins and R.insToRes[tonumber(ins)] ~= nil
        end

        local function isInjectedRes(res)
            return res and (R.resToIns[tonumber(res)] ~= nil or _injectedResSet[tonumber(res)])
        end

        local function weaponIdFromSkin(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            if _C.weaponId[resID] ~= nil then return _C.weaponId[resID] end
            local wid = nil
            local c = cfg(resID)
            if c then
                wid = tonumber(c.WeaponID or c.WeaponId or c.weaponID or c.weaponId or c.GunID or c.GunId or c.Gun_id or 0) or nil
            end
            if not wid then
                local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
                wid = m and (m.WeaponID or m.WeaponId) or nil
            end
            _C.weaponId[resID] = wid
            return wid
        end

        local function isHallThemeRes(resID)
            resID = tonumber(resID)
            if not resID then return false end
            local c = cfg(resID)
            if not c then return false end
            local it = tonumber(c.ItemType or c.itemType or 0)
            if ENUM_ITEM_TYPE and ENUM_ITEM_TYPE.Hall_Theme then
                return it == ENUM_ITEM_TYPE.Hall_Theme
            end
            return it == 202
        end

        local function getEquipSkinSlot(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            if _C.equipSlot[resID] ~= nil then return _C.equipSlot[resID] end
            local slot = nil
            local itemCfg = cfg(resID)
            if itemCfg then
                local st = tonumber(itemCfg.ItemSubType or itemCfg.itemSubType or 0)
                local it = tonumber(itemCfg.ItemType or itemCfg.itemType or 0)
                if st == 501 or st == 504 then slot = "bag"
                elseif st == 502 or st == 505 then slot = "helmet"
                elseif st == 503 or st == 506 then slot = "armor"
                elseif it == 4 and st == 701 then slot = "parachute"
                elseif it == 4 and (st == 413 or st == 414 or st == 415) then slot = "glider" end
            end
            if not slot then
                if resID >= 1502000000 and resID < 1503000000 then slot = "helmet"
                elseif resID >= 1505000000 and resID < 1506000000 then slot = "helmet"
                elseif resID >= 1501000000 and resID < 1502000000 then slot = "bag"
                elseif resID >= 1504000000 and resID < 1505000000 then slot = "bag" end
            end
            _C.equipSlot[resID] = slot
            return slot
        end

        local function wardrobeTab(resID, depotData)
            if depotData and depotData.subTabType then return tonumber(depotData.subTabType) end
            local c = cfg(resID)
            return c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
        end

        local function wardrobeMainTab(resID, depotData)
            if depotData and depotData.mainTabType then return tonumber(depotData.mainTabType) end
            local c = cfg(resID)
            return c and tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or _K.WARDROBE_PAGE_AVATAR
        end

        local function getInjectedItemTab(resID, depotData)
            resID = tonumber(resID)
            if not resID then return nil, nil end
            if _C.itemTab[resID] then
                return _C.itemTab[resID][1], _C.itemTab[resID][2]
            end
            local c = cfg(resID)
            local st = c and tonumber(c.ItemSubType or c.itemSubType) or 0

            local equipSlot = getEquipSkinSlot(resID)
            local result
            if equipSlot == "bag" then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_BAG}
            elseif equipSlot == "helmet" then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_HELMET}
            elseif equipSlot == "armor" then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_ARMOR}
            elseif equipSlot == "parachute" then result = {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_PARACHUTE}
            elseif equipSlot == "glider" then result = {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_GLIDER}
            elseif weaponIdFromSkin(resID) then result = {_K.WARDROBE_PAGE_WEAPON, _K.WARDROBE_TAB_GUN}
            else
                local mainTab = wardrobeMainTab(resID, depotData)
                local subTab = wardrobeTab(resID, depotData)
                if subTab and subTab > 0 then result = {mainTab, subTab}
                elseif st == _K.ST_PANTS then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_TROUSERS}
                elseif st == _K.ST_SHOES then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SHOES}
                elseif st == _K.ST_TOP then
                    if isFullSuitRes(resID, depotData) then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SUIT}
                    else result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_CLOTHES} end
                elseif st == 400 or st == 408 or st == 409 or st == 410 then
                    result = {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_PARACHUTE}
                else
                    result = {mainTab, subTab or 0}
                end
            end
            _C.itemTab[resID] = result
            return result[1], result[2]
        end

        local function injectedMatchesPage(resID, depotData, mainTab, subTab)
            local itemMain, itemSub = getInjectedItemTab(resID, depotData)
            if itemMain ~= mainTab or itemSub ~= subTab then return false end
            if subTab == _K.WARDROBE_TAB_SUIT or subTab == _K.WARDROBE_TAB_CLOTHES then
                local st = depotData and depotData.itemSubType or subType(cfg(resID))
                if st == _K.ST_TOP then
                    local full = isFullSuitRes(resID, depotData)
                    if subTab == _K.WARDROBE_TAB_SUIT then return full end
                    if subTab == _K.WARDROBE_TAB_CLOTHES then return not full end
                end
            end
            return true
        end

        local function isFullSuitRes(resID, depotData)
            resID = tonumber(resID)
            if not resID or resID <= 0 then return false end
            if _C.fullSuit[resID] ~= nil then return _C.fullSuit[resID] end
            local result = false
            pcall(function()
                local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
                if LogicXSuit.IsXSuit(resID) then result = true end
            end)
            if not result then
                local tab = wardrobeTab(resID, depotData)
                if tab == _K.WARDROBE_TAB_SUIT then result = true end
            end
            _C.fullSuit[resID] = result
            return result
        end

        local function getClothKind(resID, depotData)
            resID = tonumber(resID)
            if not resID then return nil end
            local st = subType(cfg(resID))
            if st == _K.ST_TOP then
                return isFullSuitRes(resID, depotData) and "full_suit" or "top"
            end
            if st == _K.ST_PANTS then return "pants" end
            if st == _K.ST_SHOES then return "shoes" end
            if st == _K.ST_UNDER_T then return "under_top" end
            if st == _K.ST_UNDER_P then return "under_pants" end
            return nil
        end

        local function subTypesToClearForKind(kind)
            if kind == "full_suit" then return FULL_SUIT_CLEAR_ST end
            if kind == "top" then return { [_K.ST_TOP] = true } end
            if kind == "pants" then return { [_K.ST_PANTS] = true } end
            if kind == "shoes" then return { [_K.ST_SHOES] = true } end
            if kind == "under_top" then return { [_K.ST_UNDER_T] = true } end
            if kind == "under_pants" then return { [_K.ST_UNDER_P] = true } end
            return nil
        end

        local function isBodyClothSubType(st)
            st = tonumber(st)
            return st == _K.ST_TOP or st == _K.ST_PANTS or st == _K.ST_SHOES or st == _K.ST_UNDER_T or st == _K.ST_UNDER_P
        end

        local _outfitMergeCache = { key = nil, items = nil }
        local _weaponSkinResMergeCache = { key = nil, res = nil }
        local _convertCache = {}

        local function getConvertedAvatarCustom(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            if _convertCache[resID] ~= nil then return _convertCache[resID] end
            local AvatarData = require("client.logic.data.AvatarData")
            local converted = AvatarData.ConvertToAvatarCustom({ resID, 0, 0 })
            _convertCache[resID] = converted
            return converted
        end

        local function invalidateSocialWearCache()
            local s = _G.AddOutfitSocialState
            if s then
                s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
            end
            _outfitMergeCache.key = nil
            _outfitMergeCache.items = nil
            _weaponSkinResMergeCache.key = nil
            _weaponSkinResMergeCache.res = nil
            _snapHeavyT = 0
        end

        -- ========== لفلات الخوذة/الشنطة (3 مستويات) ==========
        -- catalog = ID الأساسي | lv1/lv2/lv3 = شكل كل لفة في الجيم
        -- مثال: Magick Delight Helmet
        local EQUIP_LEVEL_SETS = {
            [1502000382] = { lv1 = 1502001382, lv2 = 1502002382, lv3 = 1502003382, slot = "helmet" },
        }
        local _equipLevelByRes = {}
        local function registerEquipLevelSet(catalog, lv1, lv2, lv3, slot)
            catalog = tonumber(catalog)
            if not catalog then return end
            local set = {
                catalog = catalog,
                lv1 = tonumber(lv1) or 0,
                lv2 = tonumber(lv2) or 0,
                lv3 = tonumber(lv3) or 0,
                slot = slot or "helmet",
            }
            EQUIP_LEVEL_SETS[catalog] = set
            for _, rid in ipairs({ catalog, set.lv1, set.lv2, set.lv3 }) do
                if rid and rid > 0 then _equipLevelByRes[rid] = set end
            end
        end
        for catalog, set in pairs(EQUIP_LEVEL_SETS) do
            registerEquipLevelSet(catalog, set.lv1, set.lv2, set.lv3, set.slot)
        end
        _G.AddOutfitRegisterEquipLevelSet = registerEquipLevelSet

        -- نطاقات معدات بـ 3 لفلات (نفس البنية: 15XX00Y### حيث Y = اللفة)
        local EQUIP_LEVEL_RANGES = {
            { base = 1502000000, slot = "helmet" }, -- خوذة
            { base = 1501000000, slot = "bag"    }, -- شنطة
        }

        local function findEquipLevelRange(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            for _, r in ipairs(EQUIP_LEVEL_RANGES) do
                if resID >= r.base and resID < r.base + 1000000 then return r end
            end
            return nil
        end

        local function detectLevelFromPattern(resID)
            resID = tonumber(resID)
            if not resID then return nil, nil end
            local r = findEquipLevelRange(resID)
            if not r then return nil, nil end
            if resID < r.base + 1000 or resID >= r.base + 4000 then return nil, nil end
            local tail = resID - r.base
            local levelDigit = math.floor(tail / 1000)
            if levelDigit >= 1 and levelDigit <= 3 then
                return levelDigit, r.base + (tail - levelDigit * 1000)
            end
            return nil, nil
        end

        local function buildPatternLevelSet(catalog)
            catalog = tonumber(catalog)
            if not catalog then return nil end
            local r = findEquipLevelRange(catalog)
            if not r then return nil end
            local tail = catalog - r.base
            if tail < 0 or tail >= 1000 then return nil end
            return {
                catalog = catalog,
                lv1 = catalog + 1000,
                lv2 = catalog + 2000,
                lv3 = catalog + 3000,
                slot = r.slot,
            }
        end

        local function getEquipLevelSet(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local set = _equipLevelByRes[resID]
            if set then return set end
            local level, catalog = detectLevelFromPattern(resID)
            if catalog then
                if EQUIP_LEVEL_SETS[catalog] then return EQUIP_LEVEL_SETS[catalog] end
                if level then return buildPatternLevelSet(catalog) end
            end
            -- resID نفسه ممكن يكون الـ catalog (بدون رقم لفل) — جرّب نبني set مباشرة
            local direct = buildPatternLevelSet(resID)
            if direct then
                _equipLevelByRes[resID] = direct
                if direct.lv1 > 0 then _equipLevelByRes[direct.lv1] = direct end
                if direct.lv2 > 0 then _equipLevelByRes[direct.lv2] = direct end
                if direct.lv3 > 0 then _equipLevelByRes[direct.lv3] = direct end
            end
            return direct
        end

        local function normalizeEquipCatalogRes(resID)
            resID = tonumber(resID)
            if not resID or resID <= 0 then return 0 end
            local set = getEquipLevelSet(resID)
            if set then return set.catalog end
            return resID
        end

        local function detectLevelFromEquipRes(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local set = getEquipLevelSet(resID)
            if set then
                if resID == set.lv1 then return 1
                elseif resID == set.lv2 then return 2
                elseif resID == set.lv3 then return 3 end
            end
            local level = detectLevelFromPattern(resID)
            return level
        end

        local function mapEquipLevelSet(set, level)
            if not set then return 0 end
            level = tonumber(level) or 3
            if level == 1 then return set.lv1 or 0
            elseif level == 2 then return set.lv2 or 0 end
            return set.lv3 or 0
        end

        local function mapEquipSkinRes(resID, level)
            resID, level = tonumber(resID), tonumber(level) or 3
            if not resID or resID <= 0 then return 0 end
            local catalogRes = normalizeEquipCatalogRes(resID)
            local set = getEquipLevelSet(catalogRes)
            if set then
                local mapped = mapEquipLevelSet(set, level)
                if mapped > 0 then return mapped end
            end
            local mapped = 0
            pcall(function()
                local itemMappingCfg = CDataTable.GetTableData("BackpackMapping", catalogRes)
                if itemMappingCfg then
                    if level == 1 then mapped = tonumber(itemMappingCfg.SkinItemIDLv1) or 0
                    elseif level == 2 then mapped = tonumber(itemMappingCfg.SkinItemIDLv2) or 0
                    else mapped = tonumber(itemMappingCfg.SkinItemIDLv3) or 0 end
                end
                if mapped <= 0 and DataMgr and DataMgr.GetEquipmentItemIDByResID then
                    mapped = tonumber(DataMgr.GetEquipmentItemIDByResID(level, catalogRes)) or 0
                end
            end)
            if mapped > 0 then return mapped end
            if isInjectedRes(catalogRes) then return catalogRes end
            return 0
        end

        local function buildEquipSkinLists(resID)
            resID = normalizeEquipCatalogRes(resID)
            return {
                mapEquipSkinRes(resID, 1),
                mapEquipSkinRes(resID, 2),
                mapEquipSkinRes(resID, 3),
            }
        end

        local function ensureMatchEquipCache()
            local cch = cache()
            local eq = MATCH_CONFIG.equip or {}
            if (not cch.equip.bag or cch.equip.bag <= 0) and eq.bag and eq.bag > 0 then
                cch.equip.bag = eq.bag
            end
            if (not cch.equip.helmet or cch.equip.helmet <= 0) and eq.helmet and eq.helmet > 0 then
                cch.equip.helmet = eq.helmet
            end
            if (not cch.equip.armor or cch.equip.armor <= 0) and eq.armor and eq.armor > 0 then
                cch.equip.armor = eq.armor
            end
            if (not cch.equip.parachute or cch.equip.parachute <= 0) and eq.parachute and eq.parachute > 0 then
                cch.equip.parachute = eq.parachute
            end
            if (not cch.equip.glider or cch.equip.glider <= 0) and eq.glider and eq.glider > 0 then
                cch.equip.glider = eq.glider
            end
        end

        local function syncMatchConfigFromCache()
            local cch = cache()
            if cch.outfitRes and cch.outfitRes > 0 then
                MATCH_CONFIG.outfitRes = cch.outfitRes
            else
                MATCH_CONFIG.outfitRes = 0
            end
            MATCH_CONFIG.weaponSkins = MATCH_CONFIG.weaponSkins or {}
            for wid, w in pairs(cch.weapons or {}) do
                if w.resID and w.resID > 0 then
                    MATCH_CONFIG.weaponSkins[wid] = w.resID
                end
            end
            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
            for _, slot in ipairs({ "bag", "helmet", "armor", "parachute", "glider" }) do
                if cch.equip[slot] and cch.equip[slot] > 0 then
                    MATCH_CONFIG.equip[slot] = cch.equip[slot]
                end
            end
        end

        local function restorePersistedVehicles()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if _G._savedVehicleSlotList and DataMgr then
                    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
                    for subType, insList in pairs(_G._savedVehicleSlotList) do
                        if insList and #insList > 0 then
                            DataMgr.VehicleSlotList[subType] = insList
                        end
                    end
                end
            end)
            pcall(function()
                if _G._savedGarageVehicles then
                    local GTS = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                    if GTS then
                        GTS.GarageVehicleInfo = GTS.GarageVehicleInfo or {}
                        for slot, info in pairs(_G._savedGarageVehicles) do
                            if info and info.inst_id then
                                GTS.GarageVehicleInfo[slot] = info
                            end
                        end
                    end
                end
            end)
        end

        local function restorePersistedMotions()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if not _G._savedMotionList or #_G._savedMotionList == 0 then return end
                if not DataMgr then return end
                DataMgr.MotionSlotList = {}
                for i, ins in ipairs(_G._savedMotionList) do
                    DataMgr.MotionSlotList[i] = ins
                end
                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                end
            end)
        end

        local function restorePersistedEquipIns()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if not DataMgr then return end
                if _G._savedEquipIns then
                    DataMgr.equipmentSkinInsIDTable = DataMgr.equipmentSkinInsIDTable or {}
                    for subType, ins in pairs(_G._savedEquipIns) do
                        if ins and ins > 0 then
                            DataMgr.equipmentSkinInsIDTable[subType] = ins
                        end
                    end
                end
                if _G._savedVstSkin and _G._savedVstSkin > 0 then
                    DataMgr.vst_skin = _G._savedVstSkin
                end
            end)
        end

        local function restorePersistedThrowObjects()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if not _G._savedThrowObjects then return end
                local cch = cache()
                cch.throwObjects = cch.throwObjects or {}
                for st, info in pairs(_G._savedThrowObjects) do
                    if info.resID and info.resID > 0 then
                        cch.throwObjects[st] = info
                    end
                end
            end)
        end

        local GAME_HELMET_LEVEL = {
            [502001] = 1, [502004] = 1,
            [502002] = 2, [502005] = 2,
            [502003] = 3,
        }
        local GAME_BAG_LEVEL = {
            [501001] = 1, [501004] = 1,
            [501002] = 2, [501005] = 2,
            [501003] = 3,
        }

        local function detectEquipLevelFromBaseId(baseId, catalogResID)
            baseId, catalogResID = tonumber(baseId), tonumber(catalogResID)
            if not baseId or baseId <= 0 then return nil end
            local level
            pcall(function()
                catalogResID = catalogResID and normalizeEquipCatalogRes(catalogResID) or catalogResID
                if catalogResID then
                    local set = getEquipLevelSet(catalogResID)
                    if set then
                        if baseId == set.lv1 then level = 1
                        elseif baseId == set.lv2 then level = 2
                        elseif baseId == set.lv3 then level = 3 end
                    end
                    if not level then
                        local m = CDataTable.GetTableData("BackpackMapping", catalogResID)
                        if m then
                            if tonumber(m.SkinItemIDLv1) == baseId then level = 1
                            elseif tonumber(m.SkinItemIDLv2) == baseId then level = 2
                            elseif tonumber(m.SkinItemIDLv3) == baseId then level = 3 end
                        end
                    end
                end
                if not level then
                    local patLevel, patCatalog = detectLevelFromPattern(baseId)
                    if patLevel and (not catalogResID or patCatalog == catalogResID) then
                        level = patLevel
                    end
                end
                if not level then level = GAME_HELMET_LEVEL[baseId] or GAME_BAG_LEVEL[baseId] end
                if not level and baseId >= 1505000001 and baseId <= 1505000003 then
                    level = baseId - 1505000000
                end
                if not level then
                    pcall(function()
                        local BU = require("GameLua.Mod.BaseMod.GamePlay.Backpack.BackpackUtils")
                        if BU.GetEquipmentHelmetLevel then
                            local hl = BU.GetEquipmentHelmetLevel(baseId)
                            if hl and hl >= 1 and hl <= 3 then level = hl end
                        end
                        if not level and BU.GetEquipmentBagLevel then
                            local bl = BU.GetEquipmentBagLevel(baseId)
                            if bl and bl >= 1 and bl <= 3 then level = bl end
                        end
                    end)
                end
            end)
            return level
        end

        local function isBaseEquipItemId(itemId)
            itemId = tonumber(itemId)
            if not itemId or itemId <= 0 then return false end
            if GAME_HELMET_LEVEL[itemId] or GAME_BAG_LEVEL[itemId] then return true end
            if itemId >= 1505000001 and itemId <= 1505000100 then return true end
            if itemId >= 1501000000 and itemId < 1502000000 then return true end
            if itemId >= 502001 and itemId <= 502999 then return true end
            if itemId >= 501001 and itemId <= 501999 then return true end
            return false
        end

        local function resolveMatchEquipSkin(catalogResID, baseItemID)
            catalogResID = normalizeEquipCatalogRes(catalogResID)
            if not catalogResID or catalogResID <= 0 then return 0 end
            local level = detectEquipLevelFromBaseId(baseItemID, catalogResID) or 3
            return mapEquipSkinRes(catalogResID, level)
        end

        local function getEquipDisplayLevel(resID, slot)
            local wornLevel = detectLevelFromEquipRes(resID)
            if wornLevel then return wornLevel end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                if slot == "bag" then wornLevel = fbd:GetBagLevel() or 3
                elseif slot == "helmet" then wornLevel = fbd:GetHelmetLevel() or 3 end
            end)
            return wornLevel or 3
        end

        local function syncEquipLevelFromRes(resID, slot)
            local level = detectLevelFromEquipRes(resID)
            if not level then return end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                if slot == "helmet" then
                    fbd:SetHelmetLevel(level)
                elseif slot == "bag" then
                    fbd:SetBagLevel(level)
                end
            end)
        end

        local function saveEquipSkin(resID, insID)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID then return end
            local slot = getEquipSkinSlot(resID)
            if not slot then return end
            local cch = cache()
            cch.equip[slot] = resID
            if insID then cch.equip[slot .. "Ins"] = insID end
            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
            MATCH_CONFIG.equip[slot] = resID
            _S.matchApplied = false
            invalidateSocialWearCache()
            log("ذاكرة معدات", slot, resID)
            pcall(_AutoSaveOutfit)
        end

        local function saveClothPiece(resID)
            resID = tonumber(resID)
            if not resID then return end
            local cch = cache()
            cch.clothes[resID] = true
            _S.matchApplied = false
            invalidateSocialWearCache()
            pcall(_AutoSaveOutfit)
        end

        local function clearClothesForKind(kind)
            local clearMap = subTypesToClearForKind(kind)
            if not clearMap then return end
            local cch = cache()
            for resID in pairs(cch.clothes) do
                local st = subType(cfg(resID))
                if st and clearMap[st] then cch.clothes[resID] = nil end
            end
            if kind == "full_suit" then
                cch.outfitRes, cch.outfitIns = nil, nil
            end
        end

        local function saveWeaponToCache(weaponID, resID, insID)
            weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
            if not weaponID or not resID or resID <= 0 then return end
            if resID == weaponID and not isInjectedRes(resID) then return end
            local cch = cache()
            cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
            _G.AddOutfitLastAppliedSkin = {}
            _S.matchApplied = false
            invalidateSocialWearCache()
            log("ذاكرة سكن", weaponID, "→", resID)
            pcall(_AutoSaveOutfit)
        end

        local function cacheWeaponSkinFromIns(weaponID, insID)
            weaponID, insID = tonumber(weaponID), tonumber(insID)
            if not weaponID or not insID or insID <= 0 then return end
            if isInjectedIns(insID) then
                saveWeaponToCache(weaponID, R.insToRes[insID], insID)
                return
            end
            pcall(function()
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
                if d and d.resID and tonumber(d.resID) > 0 then
                    saveWeaponToCache(weaponID, tonumber(d.resID), insID)
                end
            end)
        end

        local function saveEquip(resID, insID)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID or not insID then return end
            local inLobbyNow = not (GameStatus and GameStatus.IsInLobbyOrMainCity
                and not GameStatus.IsInLobbyOrMainCity())
            if inLobbyNow then
            local c = cfg(resID)
            local st = subType(c)
            local kind = getClothKind(resID)
            local cch = cache()
            if kind == "full_suit" then
                clearClothesForKind("full_suit")
                cch.outfitRes, cch.outfitIns = resID, insID
                _G.AddOutfitLastLobbyOutfitRes = resID
                invalidateSocialWearCache()
            elseif kind then
                if cch.outfitRes and isFullSuitRes(cch.outfitRes) then
                    cch.outfitRes, cch.outfitIns = nil, nil
                    _G.AddOutfitLastLobbyOutfitRes = nil
                end
                clearClothesForKind(kind)
                saveClothPiece(resID)
            elseif getEquipSkinSlot(resID) then
                saveEquipSkin(resID, insID)
            elseif _K.GUN_SUB[st] then
                local wid = weaponIdFromSkin(resID)
                if not wid then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        wid = wgl.GetCurGunID and wgl:GetCurGunID() or nil
                        if not wid and wgl.GetCurrentGunID then
                            wid = wgl:GetCurrentGunID()
                        end
                    end)
                end
                if wid then saveWeaponToCache(wid, resID, insID) end
            elseif st == _K.MELEE_ID then
                saveWeaponToCache(_K.MELEE_ID, resID, insID)
            elseif isThrowObjectRes(resID) then
                saveThrowObject(resID, insID)
            elseif isInjectedRes(resID) then
                local mt = wardrobeMainTab(resID)
                if mt ~= _K.WARDROBE_PAGE_VEHICLE then
                    saveClothPiece(resID)
                end
            end
            end
            _S.matchApplied = false
            pcall(_AutoSaveOutfit)
        end

        local _lastSyncWeaponCache = 0
        local function syncWeaponCacheFromLobby()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastSyncWeaponCache) < 0.3 then return end  -- throttle: max ~3x per second
            _lastSyncWeaponCache = now
            if GameStatus and GameStatus.IsInLobbyOrMainCity
                and not GameStatus.IsInLobbyOrMainCity() then return end  -- freeze cache in match
            local cch = cache()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if bag then
                    if bag.bag_skin and tonumber(bag.bag_skin) > 0 then
                        local rid = isInjectedIns(bag.bag_skin) and R.insToRes[bag.bag_skin]
                            or (function()
                                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                local d = wd:GetHallDepotItemDataByInsID(bag.bag_skin)
                                return d and tonumber(d.resID)
                            end)()
                        if rid and isInjectedRes(rid) then cch.equip.bag = rid end
                    end
                    if bag.helmet_skin and tonumber(bag.helmet_skin) > 0 then
                        local rid = isInjectedIns(bag.helmet_skin) and R.insToRes[bag.helmet_skin]
                            or (function()
                                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                local d = wd:GetHallDepotItemDataByInsID(bag.helmet_skin)
                                return d and tonumber(d.resID)
                            end)()
                        if rid and isInjectedRes(rid) then cch.equip.helmet = rid end
                    end
                    if bag.weapon_skin_list then
                        for weaponID, entry in pairs(bag.weapon_skin_list) do
                            cacheWeaponSkinFromIns(weaponID, entry and (entry.skin_id or entry.skinId))
                        end
                    end
                end
            end)
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                if Arm.rsp_list and Arm.rsp_list.install_list then
                    for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                        cacheWeaponSkinFromIns(weaponID, entry and entry.skin_id)
                    end
                end
            end)
            pcall(function()
                if DataMgr and DataMgr.equipmentSkinInsIDTable then
                    local function ridFromIns(ins)
                        ins = tonumber(ins)
                        if not ins or ins <= 0 then return nil end
                        if isInjectedIns(ins) then return R.insToRes[ins] end
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetHallDepotItemDataByInsID(ins)
                        return d and tonumber(d.resID)
                    end
                    local bagRid = ridFromIns(DataMgr.equipmentSkinInsIDTable[504])
                    if bagRid and isInjectedRes(bagRid) then cch.equip.bag = bagRid end
                    local helmRid = ridFromIns(DataMgr.equipmentSkinInsIDTable[505])
                    if helmRid and isInjectedRes(helmRid) then cch.equip.helmet = helmRid end
                    local armorRid = ridFromIns(DataMgr.equipmentSkinInsIDTable[506])
                    if armorRid and isInjectedRes(armorRid) then cch.equip.armor = armorRid end
                end
            end)
        end

        local _lastSyncClothesCache = 0
        local function syncClothesCacheFromLobby()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastSyncClothesCache) < 0.3 then return end  -- throttle: max ~3x per second
            _lastSyncClothesCache = now
            if GameStatus and GameStatus.IsInLobbyOrMainCity
                and not GameStatus.IsInLobbyOrMainCity() then return end  -- freeze cache in match
            local cch = cache()
            pcall(function()
                local inLobby = false
                if GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() then
                    inLobby = true
                end
                
                if inLobby and not _G._addOutfitPersistLoaded then
                    cch.outfitRes = nil
                    cch.outfitIns = nil
                    _G.AddOutfitLastLobbyOutfitRes = nil
                    cch.clothes = {}
                end

                local AvatarData = require("client.logic.data.AvatarData")
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    ins = tonumber(ins)
                    if ins and ins > 0 then
                        local resID = isInjectedIns(ins) and R.insToRes[ins]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(ins)
                                return d and tonumber(d.resID)
                            end)()
                        if resID and isInjectedRes(resID) then
                            if isFullSuitRes(resID) then
                                clearClothesForKind("full_suit")
                                cch.outfitRes, cch.outfitIns = resID, ins
                                _G.AddOutfitLastLobbyOutfitRes = resID
                            elseif not getEquipSkinSlot(resID) and not weaponIdFromSkin(resID) then
                                local st = subType(cfg(resID))
                                if st then
                                    for oldRes in pairs(cch.clothes) do
                                        if subType(cfg(oldRes)) == st then cch.clothes[oldRes] = nil end
                                    end
                                end
                                cch.clothes[resID] = true
                            elseif getEquipSkinSlot(resID) then
                                local slot = getEquipSkinSlot(resID)
                                cch.equip[slot] = resID
                                cch.equip[slot .. "Ins"] = ins
                            end
                        end
                    end
                end

                -- مزامنة سكن البراشوت من FashionBag
                pcall(function()
                    local fashionbag_data = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local paraInsID = tonumber(fashionbag_data:GetParachute())
                    if paraInsID and paraInsID > 0 then
                        local paraResID
                        if isInjectedIns(paraInsID) then
                            paraResID = R.insToRes[paraInsID]
                        else
                            local d = wd:GetHallDepotItemDataByInsID(paraInsID)
                            paraResID = d and tonumber(d.resID)
                        end
                        if paraResID and paraResID > 0 then
                            cch.equip.parachute = paraResID
                            cch.equip.parachuteIns = paraInsID
                            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
                            MATCH_CONFIG.equip.parachute = paraResID
                        end
                    end
                end)

                -- مزامنة سكن الجلايدر من FashionBag
                pcall(function()
                    local fashionbag_data = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local gliderInsID = tonumber(fashionbag_data:GetAircraftOrGliding())
                    if gliderInsID and gliderInsID > 0 then
                        local gliderResID
                        if isInjectedIns(gliderInsID) then
                            gliderResID = R.insToRes[gliderInsID]
                        else
                            local d = wd:GetHallDepotItemDataByInsID(gliderInsID)
                            gliderResID = d and tonumber(d.resID)
                        end
                        if gliderResID and gliderResID > 0 then
                            cch.equip.glider = gliderResID
                            cch.equip.gliderIns = gliderInsID
                            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
                            MATCH_CONFIG.equip.glider = gliderResID
                        end
                    end
                end)
            end)
        end

        local function syncClothesCacheFromLive()
            if GameStatus and GameStatus.IsInLobbyOrMainCity
                and not GameStatus.IsInLobbyOrMainCity() then return end  -- freeze cache in match
            local cch = cache()
            pcall(function()
                local AvatarData = require("client.logic.data.AvatarData")
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local nRW, nAdd = 0, 0
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    ins = tonumber(ins)
                    if ins and ins > 0 then
                        nRW = nRW + 1
                        local resID = isInjectedIns(ins) and R.insToRes[ins]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(ins)
                                return d and tonumber(d.resID)
                            end)()
                        if resID and isInjectedRes(resID) then
                            nAdd = nAdd + 1
                            if isFullSuitRes(resID) then
                                cch.outfitRes, cch.outfitIns = resID, ins
                                _G.AddOutfitLastLobbyOutfitRes = resID
                            elseif not getEquipSkinSlot(resID) and not weaponIdFromSkin(resID) then
                                cch.clothes[resID] = true
                            else
                                local slot = getEquipSkinSlot(resID)
                                if slot then
                                    cch.equip[slot] = resID
                                    cch.equip[slot .. "Ins"] = ins
                                end
                            end
                        end
                    end
                end
                report("syncLive: rolewear=" .. nRW .. " injected-added=" .. nAdd
                    .. " clothes=" .. (cch.clothes and (function() local n = 0 for _ in pairs(cch.clothes) do n = n + 1 end return n end)() or 0))
                pcall(function()
                    local fashionbag_data = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local paraInsID = tonumber(fashionbag_data:GetParachute())
                    if paraInsID and paraInsID > 0 then
                        local paraResID = isInjectedIns(paraInsID) and R.insToRes[paraInsID]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(paraInsID)
                                return d and tonumber(d.resID)
                            end)()
                        if paraResID and paraResID > 0 then
                            cch.equip.parachute = paraResID
                            cch.equip.parachuteIns = paraInsID
                        end
                    end
                    local gliderInsID = tonumber(fashionbag_data:GetAircraftOrGliding())
                    if gliderInsID and gliderInsID > 0 then
                        local gliderResID = isInjectedIns(gliderInsID) and R.insToRes[gliderInsID]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(gliderInsID)
                                return d and tonumber(d.resID)
                            end)()
                        if gliderResID and gliderResID > 0 then
                            cch.equip.glider = gliderResID
                            cch.equip.gliderIns = gliderInsID
                        end
                    end
                end)
            end)
        end

        local function syncThrowObjectCacheFromLobby()
            local cch = cache()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if not bag or not bag.throw_object_list then return end
                cch.throwObjects = cch.throwObjects or {}
                for subType, insID in pairs(bag.throw_object_list) do
                    insID = tonumber(insID)
                    subType = tonumber(subType)
                    if insID and insID > 0 and subType and _K.THROW_SUB[subType] then
                        local resID
                        if isInjectedIns(insID) then
                            resID = R.insToRes[insID]
                        else
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local d = wd:GetHallDepotItemDataByInsID(insID)
                            resID = d and tonumber(d.resID)
                        end
                        if resID and isInjectedRes(resID) then
                            cch.throwObjects[subType] = { resID = resID, insID = insID }
                        end
                    end
                end
            end)
        end

        local _lastSyncAllLive = 0
        local function syncAllCacheFromLive()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastSyncAllLive) < 1.0 then return end
            _lastSyncAllLive = now
            pcall(syncWeaponCacheFromLobby)
            pcall(syncClothesCacheFromLive)
            pcall(syncThrowObjectCacheFromLobby)
            pcall(ensureMatchEquipCache)
            pcall(syncMatchConfigFromCache)
        end
        _G.AddOutfitSyncCacheBeforeSave = syncAllCacheFromLive

        local function snapshotLobbyWear()
            syncWeaponCacheFromLobby()
            syncClothesCacheFromLobby()
            syncThrowObjectCacheFromLobby()
            ensureMatchEquipCache()
        end

        local function getCachedWeaponSkin(weaponID)
            weaponID = tonumber(weaponID) or 0
            if weaponID <= 0 then return nil end
            syncWeaponCacheFromLobby()
            local w = cache().weapons[weaponID]
            if w and w.resID and w.resID > 0 then return w.resID end
            return nil
        end

        local function getMatchWeaponSkin(weaponID)
            weaponID = tonumber(weaponID) or 0
            local fromCache = getCachedWeaponSkin(weaponID)
            if fromCache then return fromCache end
            if MATCH_CONFIG.weaponSkins then
                local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponID])
                if fixed and fixed > 0 then return fixed end
            end
            return nil
        end

        local _ticker
        pcall(function() _ticker = require("common.time_ticker") end)
        local function later(sec, fn)
            if _G.SetTimer then pcall(_G.SetTimer, sec, fn) return end
            if _ticker and _ticker.AddTimer then pcall(_ticker.AddTimer, sec, fn) end
        end

        local function getEntity()
            local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
            if not ok or not dc then return nil end
            local ok2, e = pcall(dc.GetWardrobeData, EWardrobeDataSource and EWardrobeDataSource.Wardrobe or nil)
            if ok2 and e then return e end
            ok2, e = pcall(dc.GetWardrobeData)
            return ok2 and e or nil
        end

        local function alreadyHave(entity, resID)
            local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
            if not arr then return false end
            for _, idx in pairs(arr) do
                local d = entity._data[idx]
                if d and d.count and d.count > 0 then return true end
            end
            return false
        end

        local function ensureDepotTabFields(entity, data, resID)
            if not data then return end
            pcall(function()
                if entity and entity.LoadConfigForData and CDataTable.GetTableData then
                    entity:LoadConfigForData(data, CDataTable.GetTableData)
                end
            end)
            local equipSlot = getEquipSkinSlot(resID)
            if equipSlot == "bag" then
                data.mainTabType = _K.WARDROBE_PAGE_AVATAR
                data.subTabType = _K.WARDROBE_TAB_BAG
            elseif equipSlot == "helmet" then
                data.mainTabType = _K.WARDROBE_PAGE_AVATAR
                data.subTabType = _K.WARDROBE_TAB_HELMET
            elseif equipSlot == "armor" then
                data.mainTabType = _K.WARDROBE_PAGE_AVATAR
                data.subTabType = _K.WARDROBE_TAB_ARMOR
            end
            local c = cfg(resID)
            if c then data.itemSubType = tonumber(c.ItemSubType or c.itemSubType) or data.itemSubType end
            if c then
                local wmTab = tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or 0
                if wmTab == _K.WARDROBE_PAGE_VEHICLE then
                    data.mainTabType = _K.WARDROBE_PAGE_VEHICLE
                    data.subTabType = tonumber(c.WardrobeTab or c.wardrobeTab) or data.subTabType
                end
            end
        end

        local function depotResID(v)
            return v and tonumber(v.resID or v.res_id) or nil
        end

        local function injectedEquipAllowed(resID, mainTab, subTab)
            local slot = getEquipSkinSlot(resID)
            if slot == "bag" then
                return mainTab == _K.WARDROBE_PAGE_AVATAR and subTab == _K.WARDROBE_TAB_BAG
            end
            if slot == "helmet" then
                return mainTab == _K.WARDROBE_PAGE_AVATAR and subTab == _K.WARDROBE_TAB_HELMET
            end
            if slot == "armor" then
                return mainTab == _K.WARDROBE_PAGE_AVATAR and subTab == _K.WARDROBE_TAB_ARMOR
            end
            if slot == "parachute" then
                return mainTab == _K.WARDROBE_PAGE_PARACHUTE and subTab == _K.WARDROBE_TAB_PARACHUTE
            end
            if slot == "glider" then
                return mainTab == _K.WARDROBE_PAGE_PARACHUTE and subTab == _K.WARDROBE_TAB_GLIDER
            end
            return nil
        end

        local function injectOne(entity, resID, insID)
            if alreadyHave(entity, resID) then
                R.resToIns[resID] = R.resToIns[resID] or insID
                R.insToRes[insID] = resID
                pcall(function()
                    local data = entity.GetDataByInsID and entity:GetDataByInsID(R.resToIns[resID])
                    if data then ensureDepotTabFields(entity, data, resID) end
                end)
                return true
            end
            entity:AddData({
                instid = insID, res_id = resID, count = 1,
                lock_cnt = 0, isnew = 0, valid_hours = 0, expire_ts = 0,
            })
            pcall(function()
                local data = entity.GetDataByInsID and entity:GetDataByInsID(insID)
                if data then
                    ensureDepotTabFields(entity, data, resID)
                end
            end)
            R.insToRes[insID] = resID
            R.resToIns[resID] = insID
            -- log("حقن", resID, insID)
            return true
        end

        local function injectArmory(resID, insID)
            local wid = weaponIdFromSkin(resID)
            if not wid then return end
            local Arm = require("client.logic.armory.logic_armory")
            Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
            Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
            if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
            Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
            Arm.WardrobeInsList = Arm.WardrobeInsList or {}
            Arm.WardrobeInsList[resID] = insID
        end

        -- تعديل: منع إعادة الحقن
        local function injectAll(entity)
            refreshItems()
            entity = entity or getEntity()
            if not entity or not entity.bInit then return false end

            if next(_C.fullSuit) == nil then
                pcall(function()
                    for _, rid in ipairs(ITEMS) do
                        local c = cfg(rid)
                        if c then
                            local st = tonumber(c.ItemSubType or c.itemSubType) or 0
                            if st == _K.ST_TOP then
                                local tab = tonumber(c.WardrobeTab or c.wardrobeTab) or 0
                                if tab == _K.WARDROBE_TAB_SUIT then
                                    _C.fullSuit[rid] = true
                                else
                                    pcall(function()
                                        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
                                        if LogicXSuit.IsXSuit(rid) then _C.fullSuit[rid] = true end
                                    end)
                                end
                            end
                            local wmTab = tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or 0
                            if wmTab == _K.WARDROBE_PAGE_VEHICLE then
                                _C.vehicleItems[#_C.vehicleItems + 1] = rid
                            end
                        end
                        getEquipSkinSlot(rid)
                        weaponIdFromSkin(rid)
                    end
                    for _, rid in ipairs(ITEMS) do
                        getInjectedItemTab(rid)
                    end
                    local allTabs = {
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SUIT},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_CLOTHES},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_TROUSERS},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SHOES},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_BAG},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_HELMET},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_ARMOR},
                        {_K.WARDROBE_PAGE_WEAPON, _K.WARDROBE_TAB_GUN},
                        {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_PARACHUTE},
                        {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_GLIDER},
                        {_K.WARDROBE_PAGE_VEHICLE, 0},
                    }
                    -- pageMatch is now computed lazily in IsValidCurrentPageItem
                    for k in pairs(_C.pageMatch) do _C.pageMatch[k] = nil end
                end)
            end

            local nAdded = 0
            for i, resID in ipairs(ITEMS) do
                local insID = _K.INS_BASE + i
                local had = alreadyHave(entity, resID)
                if injectOne(entity, resID, insID) then
                    if not had then nAdded = nAdded + 1 end
                    local c = cfg(resID)
                    if _K.GUN_SUB[subType(c)] or subType(c) == _K.MELEE_ID then
                        injectArmory(resID, insID)
                    end
                end
            end
            _G.AddOutfit_R = R
            if nAdded > 0 then
                log("حقن", nAdded, "items")
            end
            return true
        end

        local function injectAllSources()
            return injectAll(getEntity())
        end

        local function refreshWardrobe()
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

        local _lastWardrobeInject = 0
        local function ensureWardrobeInjected()
            if GameStatus and GameStatus.IsInLobbyOrMainCity and not GameStatus.IsInLobbyOrMainCity() then return end
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastWardrobeInject) < 8.0 then return end
            _lastWardrobeInject = now
            local ok, res = pcall(injectAllSources)
            if ok and res then
                pcall(refreshWardrobe)
            end
        end

        local function findWornInsBySubType(st)
            st = tonumber(st)
            if not st then return nil end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local AvatarData = require("client.logic.data.AvatarData")
            for _, ins in pairs(AvatarData.GetRoleWear()) do
                ins = tonumber(ins)
                if ins and ins > 0 then
                    local d = wd:GetHallDepotItemDataByInsID(ins)
                    if d and tonumber(d.itemSubType) == st then
                        return ins, d.resID
                    end
                end
            end
            return nil
        end

        local function removeRoleWearBySubTypes(stMap)
            if not stMap then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local AvatarData = require("client.logic.data.AvatarData")
            for _, ins in pairs(AvatarData.GetRoleWear()) do
                ins = tonumber(ins)
                if ins and ins > 0 then
                    local d = wd:GetHallDepotItemDataByInsID(ins)
                    if d and stMap[tonumber(d.itemSubType)] then
                        AvatarData.RemoveRoleWearDataByValue(ins)
                    end
                end
            end
        end

        local function clearFashionBagSlots(stMap)
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

        local function syncFashionBagRolewear()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
            end)
        end

        local function ensureKnapsackExtInfo()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local idx = fbd:GetFashionBagUseIndex()
                if not fbd:GetKnapsackExtInfoByIndex(idx) then
                    fbd:SetKnapsackExtInfoByIndex(idx, {})
                end
            end)
        end

        local function getEquipSubType(resID, slot)
            local c = cfg(resID)
            if c then
                local st = tonumber(c.ItemSubType or c.itemSubType)
                if st then return st end
            end
            if slot == "bag" then return ENUM_ITEM_SUBTYPE.Backpack end
            if slot == "helmet" then return ENUM_ITEM_SUBTYPE.Helmet_NoLevel end
            return nil
        end

        local function softRemoveEquipVisual(oldResID, slot)
            oldResID = normalizeEquipCatalogRes(oldResID)
            if not oldResID or oldResID <= 0 or not slot then return end
            pcall(function()
                local TAM = require("client.logic.avatar.logic_team_avatar_manager")
                local AvatarData = require("client.logic.data.AvatarData")
                for lvl = 1, 3 do
                    local displayRes = mapEquipSkinRes(oldResID, lvl)
                    if displayRes > 0 then
                        TAM.ChangeAvatarEquipment(tostring(DataMgr.roleData.uid),
                            AvatarData.CreateAvatarCustom(displayRes), false)
                    end
                end
            end)
        end

        local function applyEquipVisual(resID, insID, slot)
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local HT = require("client.logic.lobby.hall_theme_utils")
                local TAM = require("client.logic.avatar.logic_team_avatar_manager")
                local AvatarData = require("client.logic.data.AvatarData")
                local lds = require("client.slua.logic.wardrobe.logic_display_setting")
                local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                syncEquipLevelFromRes(resID, slot)
                local level = getEquipDisplayLevel(resID, slot)
                local catalogRes = normalizeEquipCatalogRes(resID)
                local itemSt = getEquipSubType(catalogRes, slot)
                if itemSt then lav:AddToWearInfo(itemSt, insID, catalogRes, 0, 0) end
                lav:AvatarChange(catalogRes, true)
                local displayRes = mapEquipSkinRes(catalogRes, level)
                if displayRes > 0 then
                    TAM.ChangeAvatarEquipment(tostring(DataMgr.roleData.uid),
                        AvatarData.CreateAvatarCustom(displayRes), true)
                end
                if lds.data then
                    if slot == "bag" then lds.data.OpenBag = true end
                    if slot == "helmet" then lds.data.OpenHelmet = true end
                end
                if slot == "helmet" then
                    fbd:SetHeadShow(insID)
                    local WRH = require("client.network.Protocol.WardRobeHandler")
                    WRH.send_depot_set_head_show_req(insID)
                end
                if slot == "bag" then HT.PutOnBag(fbd:GetFashionBagUseIndex()) end
            end)
        end

        -- ========== دوال الخلع المُحسَّنة ==========
        local takeOffEquipSkinVisual, takeOffClothVisual, takeOffWeaponSkinVisual

        local function takeOffItem(insID)
            insID = tonumber(insID)
            if not insID or insID <= 0 then return false end
            local resID = R.insToRes[insID]
            if not resID then return false end

            local cch = cache()
            local kind = getClothKind(resID)
            local slot = getEquipSkinSlot(resID)
            local wid  = weaponIdFromSkin(resID)
            local handled = false

            if slot then
                local oldRes = cch.equip[slot] or resID
                takeOffEquipSkinVisual(slot, oldRes, insID)
                cch.equip[slot]          = nil
                cch.equip[slot .. "Ins"] = nil
                if MATCH_CONFIG.equip then MATCH_CONFIG.equip[slot] = 0 end
                handled = true
            elseif kind then
                takeOffClothVisual(resID, insID, kind)
                if kind == "full_suit" then
                    cch.outfitRes, cch.outfitIns = nil, nil
                    _G.AddOutfitLastLobbyOutfitRes = nil
                    _G.SuitSkin = nil
                else
                    cch.clothes[resID] = nil
                end
                handled = true
            elseif wid then
                takeOffWeaponSkinVisual(wid, resID, insID)
                cch.weapons[wid] = nil
                _G.AddOutfitLastAppliedSkin = {}
                _S.weaponApplied = false
                _S.weaponDiagDone = false
                _S.lastAppliedWeaponID = 0
                _S.lastAppliedSkinID = 0
                buildSkinMappings()
                handled = true
            elseif isHallThemeRes(resID) then
                pcall(function()
                    local HT = require("client.logic.lobby.hall_theme_utils")
                    HT.homeThemeItemId = 0
                    HT.SetThemeInstId(0)
                    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local idx = fbd:GetFashionBagUseIndex()
                    local bag = fbd:GetCurrentFashionBag()
                    if bag and bag.avatar_show then
                        bag.avatar_show[HT.knapsack_ext_background] = nil
                    end
                end)
                handled = true
            end

            if not handled then return false end

            _S.matchApplied = false
            _S.matchOutfitDone = false
            invalidateSocialWearCache()
            pcall(_AutoSaveOutfit)
            return true
        end

        takeOffEquipSkinVisual = function(slot, resID, insID)
            if not slot then return end
            resID, insID = tonumber(resID), tonumber(insID)
            if _S.equipSkinApplying then return end
            _S.equipSkinApplying = true
            pcall(function()
                if resID and resID > 0 then softRemoveEquipVisual(resID, slot) end
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local lds = require("client.slua.logic.wardrobe.logic_display_setting")
                local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                local HT = require("client.logic.lobby.hall_theme_utils")
                local itemSt = resID and getEquipSubType(resID, slot)
                if itemSt and insID and insID > 0 then
                    pcall(function() lav:SetCurrentWearPreview(itemSt, nil) end)
                end
                if slot == "bag" then
                    fbd:SetBagSkin(0)
                    if lds.data then lds.data.OpenBag = false end
                    HT.PutOnBag(fbd:GetFashionBagUseIndex())
                elseif slot == "helmet" then
                    fbd:SetHelmetSkin(0)
                    if lds.data then lds.data.OpenHelmet = false end
                    fbd:SetHeadShow(0)
                elseif slot == "armor" then
                    pcall(function()
                        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                        wl:on_putdown_rsp(_K.NET_OK, { res_id = resID or 0, instid = insID or 0, count = 1 }, nil)
                    end)
                end
                if DataMgr and DataMgr.equipmentSkinInsIDTable then
                    local subKey = (slot == "bag") and 504 or (slot == "helmet") and 505 or (slot == "armor") and 506
                    if subKey then DataMgr.equipmentSkinInsIDTable[subKey] = 0 end
                end
                syncFashionBagRolewear()
            end)
            _S.equipSkinApplying = false
        end

        takeOffClothVisual = function(resID, insID, kind)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID or not insID then return end
            kind = kind or getClothKind(resID)
            local clearMap = subTypesToClearForKind(kind)
            if not clearMap then return end
            pcall(function()
                removeRoleWearBySubTypes(clearMap)
                clearFashionBagSlots(clearMap)
                local WRH = require("client.network.Protocol.WardRobeHandler")
                WRH.on_depot_put_down_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, nil)
                local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                local TAM = require("client.logic.avatar.logic_team_avatar_manager")
                local AvatarData = require("client.logic.data.AvatarData")
                local uid = tostring(DataMgr.roleData.uid)
                local itemSt = subType(cfg(resID)) or _K.ST_TOP
                if kind == "full_suit" then
                    itemSt = _K.ST_TOP
                    for st in pairs(clearMap) do
                        local oIns, oRes = findWornInsBySubType(st)
                        if oIns and oRes and oRes > 0 then
                            TAM.ChangeAvatarEquipment(uid, AvatarData.CreateAvatarCustom(oRes), false)
                        end
                    end
                end
                TAM.ChangeAvatarEquipment(uid, AvatarData.CreateAvatarCustom(resID), false)
                pcall(function() AvatarData.RemoveRoleWearDataByValue(insID) end)
                pcall(function() av:SetCurrentWearPreview(itemSt, nil) end)
                later(0.05, function()
                    pcall(function() av:ProcessTakeOff() end)
                    syncFashionBagRolewear()
                    pcall(function()
                        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                        wl:on_putdown_rsp(_K.NET_OK, { res_id = resID, instid = insID, count = 1 }, nil)
                    end)
                    if av.InitCurrentWearPreviewMap then av:InitCurrentWearPreviewMap(true) end
                end)
            end)
        end

        takeOffWeaponSkinVisual = function(weaponID, resID, insID)
            weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
            if not weaponID then return end
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local HT = require("client.logic.lobby.hall_theme_utils")
                local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                -- مسح من install_list
                if Arm.rsp_list and Arm.rsp_list.install_list then
                    Arm.rsp_list.install_list[weaponID] = nil
                end
                -- مسح من FashionBag
                if fbd.UpdateCurrentFashionBagWeaponSkin then
                    fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, 0)
                end
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if bag and bag.weapon_skin_list then
                    bag.weapon_skin_list[weaponID] = nil
                end
                -- تحديث واجهة السلاح
                local bagIdx = fbd:GetFashionBagUseIndex()
                HT.proc_skin_list_chg("weapon_skin", weaponID, 0, bagIdx, {})
                wgl:SetGunID(weaponID)
                if wgl.UpdateCurrentGunAvatar then
                    wgl:UpdateCurrentGunAvatar(weaponID, 0)
                end
                -- أحداث التحديث
                if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, 0)
                end
                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, 0)
                end
                if EventSystem and EVENTID_WARDROBE_UPDATE_GUN_LIST then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, weaponID)
                end
                log("خلع سكن سلاح", weaponID)
            end)
        end
        -- ========== نهاية دوال الخلع ==========

        local function putOnThrowObject(insID)
            insID = tonumber(insID)
            if not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            if not resID then return end
            local st = isThrowObjectRes(resID)
            if not st then return end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:PutOnThrowObjectSkin(insID)
            end)
            saveThrowObject(resID, insID)
            pcall(_AutoSaveOutfit)
            log("لبس قنبلة", st, resID)
        end

        local function putOnEquipSkin(insID)
            insID = tonumber(insID)
            local resID = R.insToRes[insID]
            if not resID then return end
            local slot = getEquipSkinSlot(resID)
            if not slot then return end
            if _S.equipSkinApplying then return end
            _S.equipSkinApplying = true
            pcall(function()
                local cch = cache()
                local oldResID = cch.equip[slot]
                local oldInsID = cch.equip[slot .. "Ins"]
                ensureKnapsackExtInfo()
                local item = { res_id = resID, instid = insID, count = 1, color = 0, pattern = 0 }
                local oldItem = nil
                if oldInsID and oldInsID > 0 and oldResID and oldResID > 0 then
                    oldItem = { res_id = oldResID, instid = oldInsID, count = 1, color = 0, pattern = 0 }
                end
                local HT = require("client.logic.lobby.hall_theme_utils")
                if slot == "helmet" then
                    HT.ProcPutOnHelmet(item, oldItem)
                elseif slot == "bag" then
                    HT.ProcPutOnBagSkin(item, oldItem)
                elseif slot == "parachute" then
                    -- استدعاء on_puton_rsp مع تخطي AddToWearInfo للبراشوت فقط
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                    local origAddToWearInfo = lav.AddToWearInfo
                    lav.AddToWearInfo = function(self2, subType, ...)
                        if tonumber(subType) == 701 then return end
                        return origAddToWearInfo(self2, subType, ...)
                    end
                    pcall(function()
                        wl:on_puton_rsp(_K.NET_OK, item, oldItem, 1, insID, 0)
                    end)
                    lav.AddToWearInfo = origAddToWearInfo
                elseif slot == "glider" then
                    -- استدعاء on_puton_rsp مع تخطي AddToWearInfo للجلايدر فقط
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                    local origAddToWearInfo = lav.AddToWearInfo
                    lav.AddToWearInfo = function(self2, subType, ...)
                        local st = tonumber(subType)
                        if st == 413 or st == 414 or st == 415 then return end
                        return origAddToWearInfo(self2, subType, ...)
                    end
                    pcall(function()
                        wl:on_puton_rsp(_K.NET_OK, item, oldItem, 1, insID, 0)
                    end)
                    lav.AddToWearInfo = origAddToWearInfo
                else
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    wl:on_puton_rsp(_K.NET_OK, item, oldItem, 1, insID, 0)
                end
                saveEquipSkin(resID, insID)
                if oldResID and oldResID > 0 and oldResID ~= resID then
                    softRemoveEquipVisual(oldResID, slot)
                end
                -- البراشوت والجلايدر: لا يُطبقان مرئياً في اللوبي، يُخزنان للجيم فقط
                if slot ~= "parachute" and slot ~= "glider" then
                    applyEquipVisual(resID, insID, slot)
                end
                invalidateSocialWearCache()
                log("لبس معدات", slot, resID)
            end)
            _S.equipSkinApplying = false
        end

        local function putOnCloth(insID)
            insID = tonumber(insID)
            local resID = R.insToRes[insID]
            if not resID then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if not d then return end

            local kind = getClothKind(resID, d)
            if not kind then return end

            local cch = cache()
            local switchingFromSuit = (kind ~= "full_suit") and cch.outfitRes and isFullSuitRes(cch.outfitRes)
            local switchingToSuit = (kind == "full_suit") and not cch.outfitRes and next(cch.clothes) ~= nil

            local clearMap
            if switchingFromSuit then
                clearMap = FULL_SUIT_CLEAR_ST
            else
                clearMap = subTypesToClearForKind(kind)
            end
            if not clearMap then return end

            local itemSt = subType(cfg(resID)) or _K.ST_TOP

            local function doPutOn()
                local oldIns, oldRes = findWornInsBySubType(itemSt)
                removeRoleWearBySubTypes(clearMap)
                clearFashionBagSlots(clearMap)
                saveEquip(resID, insID)

                local slot = _K.PKG_SLOT
                pcall(function()
                    local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
                    local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(itemSt)
                    if idx then slot = idx end
                end)

                local olditem
                if oldIns and oldIns ~= insID then
                    olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
                end

                local WRH = require("client.network.Protocol.WardRobeHandler")
                local item = { res_id = resID, count = 1, instid = insID }
                WRH.on_depot_put_on_rsp(_K.NET_OK, item, olditem, slot, insID, oldIns or 0)

                pcall(function()
                    local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                    av:AddToWearInfo(itemSt, insID, resID, 0, 0)
                    local displayResID = resID
                    local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
                    if LogicXSuit.IsXSuit(displayResID) then
                        displayResID = LogicXSuit.GetItemShowID(insID) or displayResID
                    end
                    av:AvatarChange(displayResID, true, 0, 0)
                    later(0.05, function()
                        pcall(function() av:ProcessTakeOff() end)
                        syncFashionBagRolewear()
                    end)
                end)
                log("لبس", kind, resID)
            end

            if switchingFromSuit then
                local suitRes = cch.outfitRes
                local suitIns = cch.outfitIns
                cch.outfitRes, cch.outfitIns = nil, nil
                _G.AddOutfitLastLobbyOutfitRes = nil
                _G.SuitSkin = nil
                if suitRes and suitIns then
                    pcall(function() takeOffClothVisual(suitRes, suitIns, "full_suit") end)
                    later(0.15, doPutOn)
                else
                    doPutOn()
                end
            elseif switchingToSuit then
                local toTakeOff = {}
                for clothRes in pairs(cch.clothes) do
                    local clothIns = R.resToIns[clothRes]
                    local clothKind = getClothKind(clothRes)
                    if clothIns and clothKind then
                        toTakeOff[#toTakeOff + 1] = { resID = clothRes, insID = clothIns, kind = clothKind }
                    end
                end
                for _, c in ipairs(toTakeOff) do
                    cch.clothes[c.resID] = nil
                    pcall(function() takeOffClothVisual(c.resID, c.insID, c.kind) end)
                end
                later(0.15, doPutOn)
            else
                doPutOn()
            end
        end

        local function equipWeaponSkin(weaponID, insID)
            weaponID, insID = tonumber(weaponID), tonumber(insID)
            if not weaponID or not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            saveEquip(resID, insID)

            local Arm = require("client.logic.armory.logic_armory")
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local HT = require("client.logic.lobby.hall_theme_utils")
            local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

            injectArmory(resID, insID)
            Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
            Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
            if fbd.UpdateCurrentFashionBagWeaponSkin then
                fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
            end

            local bagIdx = fbd:GetFashionBagUseIndex()
            HT.proc_skin_list_chg("weapon_skin", weaponID, insID, bagIdx, {})

            wgl:SetGunID(weaponID)
            wgl:UpdateCurrentGunAvatar(weaponID, insID)

            if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
                EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
            end
            if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
            end
            log("سكن سلاح", weaponID, resID, insID)
        end

        local function putOnHallTheme(insID)
            insID = tonumber(insID)
            if not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            if not resID or not isHallThemeRes(resID) then return end
            local item = { res_id = resID, count = 1, instid = insID }
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                wl:on_puton_rsp(_K.NET_OK, item, nil, 1, insID, 0)
            end)
            pcall(_AutoSaveOutfit)
            log("ثيم لوبي", resID, insID)
        end

        local function restorePersistedHallTheme()
            if not _G._addOutfitPersistLoaded then return end
            local ins = tonumber(_G._savedHallThemeIns)
            if not ins or ins <= 0 then return end
            later(2.5, function()
                if isInjectedIns(ins) then putOnHallTheme(ins) end
            end)
        end

        -- ========== لوبي سوشيال ==========
        local SOCIAL = _G.AddOutfitSocialState or {}
        _G.AddOutfitSocialState = SOCIAL
        SOCIAL.debGen = SOCIAL.debGen or 0

        local function socialDebounce(sec, fn)
            SOCIAL.debGen = (SOCIAL.debGen or 0) + 1
            local gen = SOCIAL.debGen
            later(sec, function()
                if gen ~= SOCIAL.debGen then return end
                pcall(fn)
            end)
        end

        local function getLobbyCurPage()
            local p = nil
            pcall(function()
                local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
                if LMC.GetCurPage then p = LMC.GetCurPage() end
            end)
            return p
        end

        local function getWeaponSkinResFast()
            local cch = cache()
            local wid = tonumber(DataMgr.Weapon_ID) or 0
            local w = wid > 0 and cch.weapons[wid] or nil
            if w and w.resID and w.resID > 0 then return w.resID end
            for _, ww in pairs(cch.weapons) do
                if ww.resID and ww.resID > 0 then return ww.resID end
            end
            return nil
        end

        local function resolveLobbyWeaponSkinRes()
            local wid = tonumber(DataMgr.Weapon_ID) or 0
            local skin = getWeaponSkinResFast()
            if skin and skin > 0 then return skin end
            if wid > 0 then
                local fromMatch = getMatchWeaponSkin(wid)
                if fromMatch and fromMatch > 0 then return fromMatch end
            end
            return nil
        end

        local function rememberLobbyOutfitRes(resID)
            resID = tonumber(resID)
            if not resID or resID <= 0 or not isFullSuitRes(resID) then return end
            _G.AddOutfitLastLobbyOutfitRes = resID
            local cch = cache()
            if not cch.outfitRes or cch.outfitRes <= 0 then
                cch.outfitRes = resID
                if isInjectedRes(resID) then cch.outfitIns = R.resToIns[resID] end
            end
        end

        local function resolveLobbyOutfitRes()
            local cch = cache()
            if tonumber(cch.outfitRes) and cch.outfitRes > 0 then return cch.outfitRes end
            if tonumber(_G.AddOutfitLastLobbyOutfitRes) and _G.AddOutfitLastLobbyOutfitRes > 0 then
                return tonumber(_G.AddOutfitLastLobbyOutfitRes)
            end
            if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
                return tonumber(MATCH_CONFIG.outfitRes)
            end
            for resID in pairs(cch.clothes) do
                if isFullSuitRes(resID) then return resID end
            end
            return nil
        end

        local function collectAllClothResIDs()
            local ids = {}
            local cch = cache()
            if tonumber(cch.outfitRes) and cch.outfitRes > 0 then
                ids[cch.outfitRes] = true
            end
            for resID in pairs(cch.clothes) do
                if not getEquipSkinSlot(resID) and not weaponIdFromSkin(resID) then
                    ids[resID] = true
                end
            end
            return ids
        end

        local function wearPatchKey()
            local outfit = resolveLobbyOutfitRes() or 0
            local skin = resolveLobbyWeaponSkinRes() or 0
            local cch = cache()
            local eq = (cch.equip.bag or 0) .. "_" .. (cch.equip.helmet or 0)
            return outfit .. "_" .. skin .. "_" .. eq
        end

        local function applyInjectedPspace(roleData)
            if not roleData then return end
            roleData.bshow = true
            roleData.pspace_wear_ext = roleData.pspace_wear_ext or {}
            local outfitRes = resolveLobbyOutfitRes()
            if outfitRes and outfitRes > 0 then
                roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
            end
            local skinRes = resolveLobbyWeaponSkinRes()
            if skinRes and skinRes > 0 then
                roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 }
                roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { skinRes, 0, 0 }
                roleData.depot_show_info = roleData.depot_show_info or {}
                if roleData.depot_show_info.weapon == nil then roleData.depot_show_info.weapon = true end
            end
        end

        local function patchSelfWearCache(force)
            local key = wearPatchKey()
            if not force and SOCIAL.wearPatchKey == key then return false end
            SOCIAL.wearPatchKey = key
            local myUid = tonumber(DataMgr.roleData.uid)
            if not myUid then return false end
            pcall(function()
                local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                local d = BD:GetCacheData(myUid)
                if d then applyInjectedPspace(d) end
            end)
            return true
        end

        local function requestSocialAvatarRefresh()
            pcall(function()
                if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR then
                    EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR)
                end
            end)
        end

        local function onSocialWearDirty(forceRefresh)
            SOCIAL.lastHandSkin = nil
            if patchSelfWearCache(forceRefresh) then requestSocialAvatarRefresh() end
        end

        local _myUidCached
        local function isMyWearData(wearData)
            if not wearData then return false end
            if not _myUidCached then
                pcall(function() _myUidCached = tonumber(DataMgr.roleData.uid) end)
            end
            return _myUidCached and tonumber(wearData.uid) == _myUidCached
        end

        local function mergeInjectedWeaponIntoWearData(wearData)
            if not isMyWearData(wearData) then return end
            local cch = cache()
            local wKey = ""
            for wid, w in pairs(cch.weapons) do wKey = wKey .. wid .. ":" .. (w.resID or 0) .. "," end
            wKey = wKey .. "|" .. tostring(DataMgr.Weapon_ID or 0)
            local skinRes
            if _weaponSkinResMergeCache.key == wKey then
                skinRes = _weaponSkinResMergeCache.res
            else
                skinRes = resolveLobbyWeaponSkinRes()
                _weaponSkinResMergeCache.key = wKey
                _weaponSkinResMergeCache.res = skinRes
            end
            if not skinRes or skinRes <= 0 then return end
            wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
                weaponResId = 0, weaponSkinId = 0,
                diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
            }
            wearData.mainWeaponInfo.weaponSkinId = skinRes
            wearData.mainWeaponInfo.weaponResId = 0
        end

        local function getOutfitMergeItems()
            local cch = cache()
            local clothKey = ""
            for resID in pairs(cch.clothes) do clothKey = clothKey .. resID .. "," end
            local key = (cch.outfitRes or 0) .. "_" .. clothKey .. "_" .. (cch.equip.bag or 0) .. "_" .. (cch.equip.helmet or 0)
            if _outfitMergeCache.key == key and _outfitMergeCache.items then
                return _outfitMergeCache.items
            end
            local outfitRes = resolveLobbyOutfitRes()
            local AvatarData = require("client.logic.data.AvatarData")
            local items = {}
            if outfitRes and outfitRes > 0 and isFullSuitRes(outfitRes) then
                rememberLobbyOutfitRes(outfitRes)
                local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
                if converted then items[#items + 1] = converted end
                for resID in pairs(collectAllClothResIDs()) do
                    if resID ~= outfitRes and not isFullSuitRes(resID)
                        and not isBodyClothSubType(subType(cfg(resID))) then
                        local cv = AvatarData.ConvertToAvatarCustom({ resID, 0, 0 })
                        if cv then items[#items + 1] = cv end
                    end
                end
            else
                for resID in pairs(collectAllClothResIDs()) do
                    if not isFullSuitRes(resID) then
                        local converted = AvatarData.ConvertToAvatarCustom({ resID, 0, 0 })
                        if converted then items[#items + 1] = converted end
                    end
                end
            end
            _outfitMergeCache.key = key
            _outfitMergeCache.items = items
            return items
        end

        local function mergeInjectedOutfitIntoWearData(wearData)
            if not isMyWearData(wearData) then return end
            local outfitRes = resolveLobbyOutfitRes()
            local items = getOutfitMergeItems()
            if #items == 0 then return end
            if outfitRes and outfitRes > 0 and isFullSuitRes(outfitRes) then
                local newList = {}
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if not (e and e.ItemID and isBodyClothSubType(subType(cfg(e.ItemID)))) then
                        newList[#newList + 1] = e
                    end
                end
                for _, item in ipairs(items) do
                    newList[#newList + 1] = item
                end
                wearData.WearInfoList = newList
            else
                wearData.WearInfoList = wearData.WearInfoList or {}
                local ENUM = ENUM_AVATAR_DATA_TYPE or { ItemID = 1, ColorID = 2, PatternID = 3 }
                local addST = {}
                for _, item in ipairs(items) do
                    local iid = item and (item.ItemID or item[ENUM.ItemID])
                    local st = iid and subType(cfg(iid)) or 0
                    addST[st or 0] = true
                end
                if next(addST) then
                    local keep = {}
                    for _, e in ipairs(wearData.WearInfoList) do
                        local iid = e and (e.ItemID or e[ENUM.ItemID])
                        local st = iid and subType(cfg(iid)) or 0
                        if not addST[st or 0] then keep[#keep + 1] = e end
                    end
                    for _, item in ipairs(items) do keep[#keep + 1] = item end
                    wearData.WearInfoList = keep
                else
                    for _, item in ipairs(items) do
                        wearData.WearInfoList[#wearData.WearInfoList + 1] = item
                    end
                end
            end
        end

        local function mergeInjectedEquipIntoWearData(wearData)
            if not isMyWearData(wearData) then return end
            local cch = cache()
            wearData.depot_show_info = wearData.depot_show_info or {}
            if cch.equip.bag and cch.equip.bag > 0 then
                local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                local bagLevel = getEquipDisplayLevel(cch.equip.bag, "bag")
                wearData.depot_show_info.bag = true
                wearData.bagSkinInsId = mapEquipSkinRes(catalogBag, bagLevel)
                wearData.skin_info = wearData.skin_info or {}
                wearData.skin_info.bag_skin = cch.equip.bagIns or R.resToIns[cch.equip.bag] or cch.equip.bag
                wearData.skin_info.bag_level = bagLevel
            end
            if cch.equip.helmet and cch.equip.helmet > 0 then
                local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                local helmLevel = getEquipDisplayLevel(cch.equip.helmet, "helmet")
                local helmDisplay = mapEquipSkinRes(catalogHelm, helmLevel)
                wearData.depot_show_info.helmet = true
                wearData.helmet_skin = helmDisplay
                wearData.headShow = helmDisplay
                wearData.skin_info = wearData.skin_info or {}
                wearData.skin_info.helmet_skin = cch.equip.helmetIns or R.resToIns[cch.equip.helmet] or cch.equip.helmet
                wearData.skin_info.head_show = wearData.skin_info.helmet_skin
                wearData.skin_info.helmet_level = helmLevel
            end
        end

        local function mergeInjectedIntoWearData(wearData)
            if not wearData then return end
            pcall(function()
                mergeInjectedWeaponIntoWearData(wearData)
                mergeInjectedOutfitIntoWearData(wearData)
                mergeInjectedEquipIntoWearData(wearData)
            end)
        end

        -- تعديل: منع إعادة التطبيق المتكرر في اللوبي
        local function reapplyAccessoryIns(insID)
            insID = tonumber(insID)
            local resID = R.insToRes[insID]
            if not resID then return end
            local c = cfg(resID)
            local st = subType(c)
            saveClothPiece(resID)
            local itemSt = st
            local oldIns, oldRes
            if itemSt then
                oldIns, oldRes = findWornInsBySubType(itemSt)
                if oldIns == insID then oldIns, oldRes = nil, nil end
                removeRoleWearBySubTypes({ [itemSt] = true })
            end
            local WRH = require("client.network.Protocol.WardRobeHandler")
            local olditem
            if oldIns then
                olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
            end
            WRH.on_depot_put_on_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, olditem, 1, insID, oldIns or 0)
            pcall(function()
                local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                if oldIns and itemSt then av:SetCurrentWearPreview(itemSt, nil) end
                if itemSt then av:AddToWearInfo(itemSt, insID, resID, 0, 0) end
                av:AvatarChange(resID, true, 0, 0)
                av:ProcessTakeOff()
                syncFashionBagRolewear()
            end)
        end

        local function reapplyInjectedIns(insID)
            insID = tonumber(insID)
            if not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            if not resID then return end
            if isHallThemeRes(resID) then
                putOnHallTheme(insID)
            elseif getEquipSkinSlot(resID) then
                putOnEquipSkin(insID)
            elseif getClothKind(resID) then
                putOnCloth(insID)
            elseif weaponIdFromSkin(resID) then
                equipWeaponSkin(weaponIdFromSkin(resID), insID)
            elseif _K.GUN_SUB[subType(cfg(resID))] then
                local cch = cache()
                local foundWid = nil
                for wid, w in pairs(cch.weapons or {}) do
                    if w.resID == resID then foundWid = wid; break end
                end
                if foundWid then equipWeaponSkin(foundWid, insID) end
            elseif subType(cfg(resID)) == _K.MELEE_ID then
                equipWeaponSkin(_K.MELEE_ID, insID)
            elseif isThrowObjectRes(resID) then
                putOnThrowObject(insID)
            else
                reapplyAccessoryIns(insID)
            end
        end

        local function reapplyLobbyEquipped()
            if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
                return
            end
            if _S.lobbyApplied then return end
            _S.lobbyApplied = true
            later(2.0, function() _S.lobbyApplied = false end)
            pcall(function()
                local _cchR = cache()
                local _nW = 0 for _ in pairs(_cchR.weapons or {}) do _nW = _nW + 1 end
                local _nC = 0 for _ in pairs(_cchR.clothes or {}) do _nC = _nC + 1 end
                report("reapply: persistLoaded=" .. tostring(_G._addOutfitPersistLoaded)
                    .. " weapons=" .. _nW .. " clothes=" .. _nC
                    .. " outfit=" .. tostring(_cchR.outfitRes))
            end)

            restorePersistedVehicles()
            restorePersistedMotions()
            restorePersistedEquipIns()
            restorePersistedThrowObjects()
            restorePersistedHallTheme()
            syncMatchConfigFromCache()

            if not _G._addOutfitPersistLoaded then
                snapshotLobbyWear()
            end
            local cch = cache()
            if not _G._addOutfitPersistLoaded and _G._savedOutfitClothes then
                for resID in pairs(_G._savedOutfitClothes) do
                    local st = subType(cfg(resID))
                    if st then
                        for oldRes in pairs(cch.clothes) do
                            if subType(cfg(oldRes)) == st then cch.clothes[oldRes] = nil end
                        end
                    end
                    cch.clothes[resID] = true
                end
            end
            if not _G._addOutfitPersistLoaded and _G._savedOutfitRes and (not cch.outfitRes or cch.outfitRes <= 0) then
                cch.outfitRes = _G._savedOutfitRes
                cch.outfitIns = _G._savedOutfitIns or R.resToIns[_G._savedOutfitRes]
            end
            syncMatchConfigFromCache()

            local applyStep = 0
            local function scheduleApply(fn)
                applyStep = applyStep + 1
                later(applyStep * 0.12, fn)
            end

            if not _G._addOutfitPersistLoaded and _G._savedRoleWearList and #_G._savedRoleWearList > 0 then
                for _, insID in ipairs(_G._savedRoleWearList) do
                    local id = insID
                    scheduleApply(function() reapplyInjectedIns(id) end)
                end
            elseif cch.outfitIns and isInjectedIns(cch.outfitIns) then
                scheduleApply(function() putOnCloth(cch.outfitIns) end)
            else
                for resID in pairs(cch.clothes) do
                    local ins = R.resToIns[resID]
                    local rid = resID
                    if ins and isInjectedIns(ins) then
                        scheduleApply(function()
                            if getClothKind(rid) then
                                putOnCloth(ins)
                            else
                                reapplyAccessoryIns(ins)
                            end
                        end)
                    end
                end
            end
            for wid, w in pairs(cch.weapons) do
                local weaponID, entry = wid, w
                scheduleApply(function()
                    if entry.insID and isInjectedIns(entry.insID) then
                        equipWeaponSkin(weaponID, entry.insID)
                    elseif entry.resID and R.resToIns[entry.resID] and isInjectedIns(R.resToIns[entry.resID]) then
                        equipWeaponSkin(weaponID, R.resToIns[entry.resID])
                    end
                end)
            end
            for _, slot in ipairs({ "bag", "helmet", "armor", "parachute", "glider" }) do
                local resID = cch.equip[slot]
                local insID = cch.equip[slot .. "Ins"]
                scheduleApply(function()
                    if insID and isInjectedIns(insID) then
                        putOnEquipSkin(insID)
                    elseif resID and R.resToIns[resID] then
                        putOnEquipSkin(R.resToIns[resID])
                    end
                end)
            end
            if cch.throwObjects then
                for st, info in pairs(cch.throwObjects) do
                    local tInfo = info
                    scheduleApply(function()
                        if tInfo.insID and isInjectedIns(tInfo.insID) then
                            putOnThrowObject(tInfo.insID)
                        elseif tInfo.resID and R.resToIns[tInfo.resID] and isInjectedIns(R.resToIns[tInfo.resID]) then
                            putOnThrowObject(R.resToIns[tInfo.resID])
                        end
                    end)
                end
            end
            later(math.max(applyStep * 0.12 + 0.3, 0.5), function()
                syncMatchConfigFromCache()
                pcall(_AutoSaveOutfit, true)
                log("إعادة تطبيق لوبي (مرة واحدة)")
            end)

            pcall(function()
                if _G._addOutfitPersistLoaded then return end
                local GTS = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if not GTS then return end
                local maxSlots = GTS:GetMaxPositionNum()
                GTS.GarageVehicleInfo = GTS.GarageVehicleInfo or {}
                local usedIns = {}
                for slot, info in pairs(GTS.GarageVehicleInfo) do
                    if info and info.inst_id then
                        usedIns[tonumber(info.inst_id)] = true
                    end
                end
                local changed = false
                for slot = 1, maxSlots do
                    if not GTS.GarageVehicleInfo[slot] then
                        for _, resID in ipairs(_C.vehicleItems) do
                            if isInjectedRes(resID) then
                                local insID = R.resToIns[resID]
                                if insID and not usedIns[insID] then
                                    GTS.GarageVehicleInfo[slot] = { inst_id = insID, res_id = resID }
                                    usedIns[insID] = true
                                    changed = true
                                    break
                                end
                            end
                        end
                    end
                end
                if changed then
                    if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                        EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                    end
                end
            end)
        end

        local _lastLobbyEnsure = 0
        local _lobbyEnsureBackoff = {}
        local function ensureLobbyInjectedWear()
            if GameStatus and GameStatus.IsInLobbyOrMainCity and not GameStatus.IsInLobbyOrMainCity() then return end
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastLobbyEnsure) < 2.0 then return end
            _lastLobbyEnsure = now
            local cch = cache()
            local desired = {}
            if cch.outfitRes and isInjectedRes(cch.outfitRes) then desired[cch.outfitRes] = true end
            for rid in pairs(cch.clothes or {}) do
                if isInjectedRes(rid) then desired[rid] = true end
            end
            if cch.equip then
                for slot, rid in pairs(cch.equip) do
                    if type(slot) == "string" and not string.find(slot, "Ins$") and rid and isInjectedRes(rid) then
                        desired[rid] = true
                    end
                end
            end
            local worn = {}
            pcall(function()
                local AvatarData = require("client.logic.data.AvatarData")
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    ins = tonumber(ins)
                    if ins and isInjectedIns(ins) then
                        local rid = R.insToRes[ins]
                        if rid then worn[rid] = true end
                    end
                end
            end)
            local nApplied = 0
            for rid in pairs(desired) do
                if not worn[rid]
                    and (not _lobbyEnsureBackoff[rid] or (now - _lobbyEnsureBackoff[rid]) >= 20.0) then
                    local ins = R.resToIns[rid]
                    if ins and isInjectedIns(ins) then
                        pcall(function()
                            if getClothKind(rid) then
                                putOnCloth(ins)
                            else
                                reapplyAccessoryIns(ins)
                            end
                        end)
                        _lobbyEnsureBackoff[rid] = now
                        nApplied = nApplied + 1
                    end
                end
            end
            if nApplied > 0 then
                pcall(function() report("ensureLobby: reinjected=" .. nApplied) end)
            end
        end

        local function initHooks()
        local function hookLobbySwipePersistence()
            pcall(function()
                local AC = require("client.slua.logic.avatar.avatar_common")
                local oGetWear = AC.GetWearDataFromRoleData
                AC.GetWearDataFromRoleData = function(roleData)
                    local wearData = oGetWear(roleData)
                    if wearData and roleData and tonumber(roleData.uid) == tonumber(DataMgr.roleData.uid) then
                        mergeInjectedIntoWearData(wearData)
                    end
                    return wearData
                end
                local oUp = AC.UpdateAvatar
                AC.UpdateAvatar = function(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
                    if isMyWearData(wearData) then mergeInjectedIntoWearData(wearData) end
                    return oUp(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
                end
            end)
            pcall(function()
                if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
                    EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                        if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                            socialDebounce(0.5, reapplyLobbyEquipped) -- زمن أطول لتجنب التكرار
                        end
                    end)
                end
            end)
        end

        -- ========== هوكات اللوبي ==========
        local function hookCDataTableCache()
            pcall(function()
                if not CDataTable or CDataTable._lava_cached then return end
                CDataTable._lava_cached = true
                local origGetTableData = CDataTable.GetTableData
                CDataTable.GetTableData = function(tableName, resID, ...)
                    if tableName == "Item" then
                        resID = tonumber(resID)
                        if resID and _C.cfg[resID] ~= nil then
                            return _C.cfg[resID]
                        end
                        local result = origGetTableData(tableName, resID, ...)
                        if resID then
                            _C.cfg[resID] = result
                        end
                        return result
                    end
                    return origGetTableData(tableName, resID, ...)
                end
            end)
        end

        local function hookDepotInit()
            pcall(function()
                local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
                local orig = WDE.InitData
                WDE.InitData = function(self, pkg)
                    orig(self, pkg)
                    injectAll(self)
                    refreshWardrobe()
                end
            end)
        end

        local function hookWardrobeData()
            pcall(function()
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local function wrapGet(name)
                    local o = wd[name]
                    if not o then return end
                    wd[name] = function(self, insID, ...)
                        insID = tonumber(insID)
                        if isInjectedIns(insID) then
                            local e = getEntity()
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
                        if isInjectedRes(tonumber(id)) or isInjectedIns(tonumber(id)) then return true end
                        return o(self, id, ...)
                    end
                end
                wrapBool("HasItem")
                wrapBool("HasValidItem")
                wrapBool("CheckHasPermanentItem")
                if not wd._lava_global_equip then
                    wd._lava_global_equip = true
                    local origGetEquipped = wd.GetEquippedSkinIDByWeaponID
                    wd.GetEquippedSkinIDByWeaponID = function(self, weaponID)
                        local w = cache().weapons[tonumber(weaponID)]
                        if w and w.resID and w.resID > 0 then return w.resID end
                        return origGetEquipped(self, weaponID)
                    end
                end
                if not wd._lava_global_equip_ins then
                    wd._lava_global_equip_ins = true
                    if wd.GetEquippedSkinInsIDByWeaponID then
                        local origGetEquippedIns = wd.GetEquippedSkinInsIDByWeaponID
                        wd.GetEquippedSkinInsIDByWeaponID = function(self, weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then return w.insID end
                            return origGetEquippedIns(self, weaponID)
                        end
                    end
                    if wd.GetWeaponSkinInsID then
                        local origGetWSI = wd.GetWeaponSkinInsID
                        wd.GetWeaponSkinInsID = function(self, weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then return w.insID end
                            return origGetWSI(self, weaponID)
                        end
                    end
                end
            end)
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local oPutDownReq = wl.wardrobe_put_down_req
                if oPutDownReq then
                    wl.wardrobe_put_down_req = function(self, ins_id, unequip_by_server)
                        ins_id = tonumber(ins_id)
                        if isInjectedIns(ins_id) then
                            local resID = R.insToRes[ins_id]
                            takeOffItem(ins_id)
                            pcall(function()
                                self:on_putdown_rsp(_K.NET_OK, {
                                    instid = ins_id,
                                    res_id = resID or 0,
                                }, nil)
                            end)
                            pcall(function()
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA, {
                                        instid = ins_id,
                                        res_id = resID or 0,
                                        count = 1,
                                    })
                                end
                            end)
                            refreshWardrobe()
                            return
                        end
                        return oPutDownReq(self, ins_id, unequip_by_server)
                    end
                end
            end)
        end

        local function hookPageFilter()
            pcall(function()
                local SubTab = require("client.slua.umg.Wardrobe.subtab_item_list_base")
                if SubTab._lava_prefilter then return end
                SubTab._lava_prefilter = true
                local origGet = SubTab.GetArrayHallDepotItemInfo
                SubTab.GetArrayHallDepotItemInfo = function(self)
                    local allData = origGet(self)
                    if not allData or not next(allData) then return allData end
                    local pageId = self.subTabConfig and self.subTabConfig.pageId
                    local subTabId = self.subTabConfig and self.subTabConfig.subTabId
                    if not pageId or not subTabId then return allData end
                    local result = {}
                    for _, data in pairs(allData) do
                        local resID = depotResID(data)
                        if resID and isInjectedRes(resID) then
                            local itemMain, itemSub = getInjectedItemTab(resID, data)
                            if itemMain == pageId then
                                if pageId == _K.WARDROBE_PAGE_AVATAR then
                                    if subTabId == _K.WARDROBE_TAB_SUIT or subTabId == _K.WARDROBE_TAB_CLOTHES then
                                        local st = data.itemSubType or subType(cfg(resID))
                                        if st == _K.ST_TOP then
                                            local full = isFullSuitRes(resID, data)
                                            if (subTabId == _K.WARDROBE_TAB_SUIT and full) or
                                            (subTabId == _K.WARDROBE_TAB_CLOTHES and not full) then
                                                result[#result + 1] = data
                                            end
                                        end
                                    elseif itemSub == subTabId then
                                        result[#result + 1] = data
                                    end
                                elseif itemSub == subTabId then
                                    result[#result + 1] = data
                                end
                            end
                        else
                            result[#result + 1] = data
                        end
                    end
                    return result
                end
            end)
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local o1 = wl.IsValidCurrentPageItem
                wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
                    local resID = depotResID(v)
                    if resID and isInjectedRes(resID) then
                        local cacheKey = resID .. "_" .. mainTab .. "_" .. subTab
                        if _C.pageMatch[cacheKey] ~= nil then
                            return _C.pageMatch[cacheKey]
                        end
                        local result
                        if not (v.expireTS == 0 or not t or t < v.expireTS) then
                            result = false
                        else
                            local equipOk = injectedEquipAllowed(resID, mainTab, subTab)
                            if equipOk ~= nil then
                                result = equipOk
                            elseif weaponIdFromSkin(resID) then
                                result = mainTab == _K.WARDROBE_PAGE_WEAPON and subTab == _K.WARDROBE_TAB_GUN
                            elseif mainTab == _K.WARDROBE_PAGE_VEHICLE then
                                local c = cfg(resID)
                                local wmTab = c and tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or 0
                                if wmTab ~= mainTab and v.mainTabType ~= mainTab then
                                    result = false
                                else
                                    local wTab = c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
                                    local vTab = v.subTabType and tonumber(v.subTabType) or nil
                                    if wTab and wTab == subTab then result = true
                                    elseif vTab and vTab == subTab then result = true
                                    else result = o1(self, mainTab, subTab, v, t) end
                                end
                            elseif mainTab == _K.WARDROBE_PAGE_AVATAR then
                                local st = v.itemSubType or subType(cfg(resID))
                                if st == _K.ST_TOP then
                                    local full = isFullSuitRes(resID, v)
                                    if subTab == _K.WARDROBE_TAB_SUIT and full then result = true
                                    elseif subTab == _K.WARDROBE_TAB_CLOTHES and not full then result = true
                                    else result = false end
                                elseif st == _K.ST_PANTS and subTab == _K.WARDROBE_TAB_TROUSERS then
                                    result = true
                                elseif st == _K.ST_SHOES and subTab == _K.WARDROBE_TAB_SHOES then
                                    result = true
                                elseif v.subTabType == subTab then
                                    result = true
                                else
                                    result = false
                                end
                            else
                                result = o1(self, mainTab, subTab, v, t)
                            end
                        end
                        _C.pageMatch[cacheKey] = result
                        return result
                    end
                    return o1(self, mainTab, subTab, v, t)
                end
                local o2 = wl.IsCanUse
                wl.IsCanUse = function(self, resId)
                    if isInjectedRes(resId) then return true end
                    return o2(self, resId)
                end
                local o4 = wl.GetWardrobeInsIdByResId
                wl.GetWardrobeInsIdByResId = function(self, resid)
                    resid = tonumber(resid)
                    if isInjectedRes(resid) then return R.resToIns[resid] end
                    return o4(self, resid)
                end
            end)
        end

        local function hookArmory()
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                if not Arm._lava_global_own then
                    Arm._lava_global_own = true
                    local origIsOwn = Arm.IsSkinOwn
                    Arm.IsSkinOwn = function(weaponID, skinID)
                        if isInjectedRes(skinID) then return 1 end
                        return origIsOwn(weaponID, skinID)
                    end
                end
                if not Arm._lava_global_get_install then
                    Arm._lava_global_get_install = true
                    if Arm.get_install_skin then
                        local origGetInstall = Arm.get_install_skin
                        Arm.get_install_skin = function(weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return { skin_id = w.insID }
                            end
                            return origGetInstall(weaponID)
                        end
                    end
                    if Arm.GetInstallSkinInsID then
                        local origGetInstall2 = Arm.GetInstallSkinInsID
                        Arm.GetInstallSkinInsID = function(weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return w.insID
                            end
                            return origGetInstall2(weaponID)
                        end
                    end
                end
                local oi = Arm.install_weapon_skin
                Arm.install_weapon_skin = function(cd, wid, ins)
                    ins = tonumber(ins)
                    if isInjectedIns(ins) then
                        wid = tonumber(weaponIdFromSkin(R.insToRes[ins]) or wid)
                        equipWeaponSkin(wid, ins)
                        return
                    end
                    return oi(cd, wid, ins)
                end
                local function hookArmoryUninstall(fnName)
                    local orig = Arm[fnName]
                    if not orig then return end
                    Arm[fnName] = function(cd, wid, ins, ...)
                        ins = tonumber(ins)
                        wid = tonumber(wid)
                        if ins and isInjectedIns(ins) then
                            local resID = R.insToRes[ins]
                            wid = weaponIdFromSkin(resID) or wid
                            if takeOffItem(ins) then
                                refreshWardrobe()
                                return
                            end
                        elseif wid and wid > 0 then
                            local cch = cache()
                            local w = cch.weapons[wid]
                            if w and w.insID and isInjectedIns(w.insID) then
                                if takeOffItem(w.insID) then
                                    refreshWardrobe()
                                    return
                                end
                            end
                        end
                        return orig(cd, wid, ins, ...)
                    end
                end
                hookArmoryUninstall("uninstall_weapon_skin")
                hookArmoryUninstall("remove_weapon_skin")
            end)
        end

        local function hookLobbyTheme()
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                if wl._lava_hooked_hall_theme then return end
                wl._lava_hooked_hall_theme = true
                local origPutOn = wl.wardrobe_puton_req
                wl.wardrobe_puton_req = function(self, insID, extra)
                    insID = tonumber(insID)
                    if insID and isInjectedIns(insID) and isHallThemeRes(R.insToRes[insID]) then
                        putOnHallTheme(insID)
                        return
                    end
                    return origPutOn(self, insID, extra)
                end
            end)
        end

        local function hookPutOn()
            pcall(function()
                local WRH = require("client.network.Protocol.WardRobeHandler")
                local o = WRH.send_depot_put_on_req
                WRH.send_depot_put_on_req = function(insID, extra)
                    insID = tonumber(insID)
                    if isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        local c = cfg(resID)
                        local st = subType(c)
                        report("putOn: ins=" .. tostring(insID) .. " res=" .. tostring(resID)
                            .. " st=" .. tostring(st) .. " eqSlot=" .. tostring(getEquipSkinSlot(resID))
                            .. " clothKind=" .. tostring(getClothKind(resID))
                            .. " wid=" .. tostring(weaponIdFromSkin(resID)))
                        if getEquipSkinSlot(resID) then
                            putOnEquipSkin(insID)
                            return
                        end
                        if getClothKind(resID) then
                            putOnCloth(insID)
                            return
                        end
                        if _K.GUN_SUB[st] then
                            local wid = weaponIdFromSkin(resID)
                            if not wid then
                                pcall(function()
                                    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                                    wid = wgl.GetCurGunID and wgl:GetCurGunID() or nil
                                    if not wid and wgl.GetCurrentGunID then
                                        wid = wgl:GetCurrentGunID()
                                    end
                                end)
                            end
                            if wid then equipWeaponSkin(wid, insID) end
                            return
                        end
                        if st == _K.MELEE_ID then
                            equipWeaponSkin(_K.MELEE_ID, insID)
                            return
                        end
                        if isHallThemeRes(resID) then
                            putOnHallTheme(insID)
                            return
                        end
                        if isThrowObjectRes(resID) then
                            local st = isThrowObjectRes(resID)
                            local cch = cache()
                            local oldThrow = cch.throwObjects and cch.throwObjects[st]
                            local oldInsID = oldThrow and oldThrow.insID or 0
                            local oldResID = oldThrow and oldThrow.resID or 0
                            putOnThrowObject(insID)
                            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                            local bagIndex = fbd:GetFashionBagUseIndex()
                            local olditem
                            if oldInsID and oldInsID ~= insID and oldInsID ~= 0 then
                                olditem = { res_id = oldResID, count = 1, instid = oldInsID }
                            end
                            WRH.on_depot_put_on_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, olditem, bagIndex, insID, oldInsID, extra)
                            return
                        end
                        local mainTab = wardrobeMainTab(resID)
                        if mainTab == _K.WARDROBE_PAGE_VEHICLE then
                            local item = { res_id = resID, count = 1, instid = insID }
                            WRH.on_depot_put_on_rsp(_K.NET_OK, item, nil, 1, insID, 0, extra)
                            return
                        end
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        if wd:GetHallDepotItemDataByInsID(insID) then
                            -- إكسسوار (ماسك/نظارة/طاقية): اخلع القديم بنفس النوع أولاً
                            -- كي لا تظهر أكثر من علامة صح على عناصر نفس الخانة
                            local itemSt = st or subType(cfg(resID))
                            local oldIns, oldRes
                            if itemSt then
                                oldIns, oldRes = findWornInsBySubType(itemSt)
                                if oldIns == insID then oldIns, oldRes = nil, nil end
                                removeRoleWearBySubTypes({ [itemSt] = true })
                            end
                            saveClothPiece(resID)
                            local olditem
                            if oldIns then
                                olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
                            end
                            WRH.on_depot_put_on_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, olditem, 1, insID, oldIns or 0, extra)
                            pcall(function()
                                local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                                if oldIns and itemSt then av:SetCurrentWearPreview(itemSt, nil) end
                                if itemSt then av:AddToWearInfo(itemSt, insID, resID, 0, 0) end
                                av:AvatarChange(resID, true, 0, 0)
                                av:ProcessTakeOff()
                                syncFashionBagRolewear()
                            end)
                            pcall(_AutoSaveOutfit)
                        end
                        return
                    end
                    return o(insID, extra)
                end
            end)

            pcall(function()
                local WRH = require("client.network.Protocol.WardRobeHandler")
                local oPutDown = WRH.send_depot_put_down_req
                WRH.send_depot_put_down_req = function(insID, extra)
                    insID = tonumber(insID)
                    if isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        local removed = takeOffItem(insID)
                        if removed then
                            local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                            pcall(function()
                                wl:on_putdown_rsp(_K.NET_OK, {
                                    res_id = resID or 0,
                                    instid = insID,
                                    count  = 1,
                                }, nil)
                            end)
                            pcall(function()
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA, {
                                        instid = insID,
                                        res_id = resID or 0,
                                        count = 1,
                                    })
                                end
                            end)
                            refreshWardrobe()
                            return
                        end
                    end
                    return oPutDown(insID, extra)
                end
            end)

            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local oPutDownReq = wl.wardrobe_put_down_req
                if oPutDownReq then
                    wl.wardrobe_put_down_req = function(self, ins_id, unequip_by_server)
                        ins_id = tonumber(ins_id)
                        if isInjectedIns(ins_id) then
                            local resID = R.insToRes[ins_id]
                            takeOffItem(ins_id)
                            pcall(function()
                                self:on_putdown_rsp(_K.NET_OK, {
                                    instid = ins_id,
                                    res_id = resID or 0,
                                }, nil)
                            end)
                            pcall(function()
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA, {
                                        instid = ins_id,
                                        res_id = resID or 0,
                                        count = 1,
                                    })
                                end
                            end)
                            refreshWardrobe()
                            return
                        end
                        return oPutDownReq(self, ins_id, unequip_by_server)
                    end
                end
            end)

            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local oEquipSlot = wl.EquipSlotVehicle
                if oEquipSlot and not wl._lava_hooked_equip_slot_vehicle then
                    wl._lava_hooked_equip_slot_vehicle = true
                    wl.EquipSlotVehicle = function(self, resid, dragVehicleInsID, Index)
                        dragVehicleInsID = tonumber(dragVehicleInsID)
                        if dragVehicleInsID and isInjectedIns(dragVehicleInsID) then
                            local resID = R.insToRes[dragVehicleInsID]
                            local c = cfg(resID)
                            local itemSubType = c and tonumber(c.ItemSubType or c.itemSubType) or 0
                            if itemSubType and itemSubType > 0 then
                                DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
                                local slotList = DataMgr.VehicleSlotList[itemSubType] or {}
                                local idx = Index or 1
                                for i = #slotList, 1, -1 do
                                    if slotList[i] == dragVehicleInsID then
                                        table.remove(slotList, i)
                                    end
                                end
                                slotList[idx] = dragVehicleInsID
                                DataMgr.VehicleSlotList[itemSubType] = slotList
                                if DataMgr.vehicleSkinInsIDTable then
                                    DataMgr.vehicleSkinInsIDTable[resID] = DataMgr.vehicleSkinInsIDTable[resID] or dragVehicleInsID
                                end
                            end
                            DataMgr.UpdateVehicleSkin(itemSubType, dragVehicleInsID)
                            pcall(function()
                                local tabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
                                if tabSurveillance and tabSurveillance.VehicleChange then
                                    tabSurveillance.VehicleChange()
                                end
                            end)
                            if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE then
                                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE)
                            end
                            return
                        end
                        return oEquipSlot(self, resid, dragVehicleInsID, Index)
                    end
                end
            end)

            pcall(function()
                local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if GarageThemeSystem and not GarageThemeSystem._lava_hooked_equip_vehicle then
                    GarageThemeSystem._lava_hooked_equip_vehicle = true
                    local oEquip = GarageThemeSystem.EquipVehicle
                    GarageThemeSystem.EquipVehicle = function(self, Position, InsID)
                        InsID = tonumber(InsID)
                        if InsID and isInjectedIns(InsID) then
                            self:OnEquipVehicle(Position, InsID)
                            return
                        end
                        return oEquip(self, Position, InsID)
                    end
                    local oBatch = GarageThemeSystem.BatchEquipVehicle
                    GarageThemeSystem.BatchEquipVehicle = function(self, InsIDList)
                        if InsIDList and type(InsIDList) == "table" then
                            local hasInjected = false
                            local filtered = {}
                            for slot, ins in pairs(InsIDList) do
                                if isInjectedIns(tonumber(ins)) then
                                    hasInjected = true
                                    self:OnEquipVehicle(slot, tonumber(ins))
                                else
                                    filtered[slot] = ins
                                end
                            end
                            if hasInjected and not next(filtered) then
                                return
                            end
                            InsIDList = filtered
                        end
                        return oBatch(self, InsIDList)
                    end

                    local oReceive = GarageThemeSystem.OnReceiveGarageData
                    GarageThemeSystem.OnReceiveGarageData = function(self, VehicleInfo)
                        local injectedSlots = {}
                        if self.GarageVehicleInfo then
                            for slot, info in pairs(self.GarageVehicleInfo) do
                                if info and info.inst_id and isInjectedIns(tonumber(info.inst_id)) then
                                    injectedSlots[slot] = info
                                end
                            end
                        end
                        oReceive(self, VehicleInfo)
                        for slot, info in pairs(injectedSlots) do
                            if not self.GarageVehicleInfo[slot] then
                                self.GarageVehicleInfo[slot] = info
                            end
                        end
                    end

                    local oGetInfo = GarageThemeSystem.GetGarageVehicleInfo
                    GarageThemeSystem.GetGarageVehicleInfo = function(self)
                        if not self.bDataReceived and self.GarageVehicleInfo and next(self.GarageVehicleInfo) then
                            return self.GarageVehicleInfo
                        end
                        return oGetInfo(self)
                    end

                    local oGetShowList = GarageThemeSystem.GetGarageShowCarInsIDList
                    if oGetShowList then
                        GarageThemeSystem.GetGarageShowCarInsIDList = function(self, VehicleType)
                            local List = oGetShowList(self, VehicleType) or {}
                            for _, resID in ipairs(_C.vehicleItems) do
                                if isInjectedRes(resID) and #List < self:GetMaxPositionNum() then
                                    local c = cfg(resID)
                                    if c then
                                        local itemSubType = tonumber(c.ItemSubType or c.itemSubType) or 0
                                        local taxonomy = CDataTable.GetTableDataByFilter("WardrobeVehiclesTaxonomy", "ItemSubType", itemSubType)
                                        if taxonomy and taxonomy.UseInGarage == 1 and taxonomy.CategoryID == VehicleType then
                                            local insID = R.resToIns[resID]
                                            if insID then
                                                local alreadyIn = false
                                                for _, existingIns in ipairs(List) do
                                                    if tonumber(existingIns) == tonumber(insID) then
                                                        alreadyIn = true
                                                        break
                                                    end
                                                end
                                                if not alreadyIn then
                                                    table.insert(List, insID)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            return List
                        end
                    end
                end
            end)
        end

        local function hookMotionEquip()
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                if wl._lava_hooked_motion then return end
                wl._lava_hooked_motion = true

                local origEquip = wl.EquipMotion
                wl.EquipMotion = function(self, instid, dst_slot)
                    instid = tonumber(instid)
                    if instid and isInjectedIns(instid) then
                        local insSlot = 0
                        for i, v in ipairs(DataMgr.MotionSlotList) do
                            if v == instid then insSlot = i; break end
                        end
                        if insSlot > 0 then
                            local curIns = DataMgr.MotionSlotList[dst_slot]
                            if curIns == instid then return end
                            DataMgr.MotionSlotList[insSlot] = curIns or 0
                            DataMgr.MotionSlotList[dst_slot] = instid
                        else
                            while #DataMgr.MotionSlotList < dst_slot do
                                table.insert(DataMgr.MotionSlotList, 0)
                            end
                            DataMgr.MotionSlotList[dst_slot] = instid
                        end
                        if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                            EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                        end
                        pcall(_AutoSaveOutfit)
                        return
                    end
                    return origEquip(self, instid, dst_slot)
                end

                local origUnequip = wl.unequip_motion_req
                wl.unequip_motion_req = function(self, instid, slot)
                    instid = tonumber(instid)
                    if instid and isInjectedIns(instid) then
                        for i, v in ipairs(DataMgr.MotionSlotList) do
                            if v == instid then
                                table.remove(DataMgr.MotionSlotList, i)
                                break
                            end
                        end
                        if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                            EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                        end
                        pcall(_AutoSaveOutfit)
                        return
                    end
                    return origUnequip(self, instid, slot)
                end
            end)
        end

        local _emoteSlotKey = nil
        local _emoteSlotCache = {}
        local function getInjectedEmotes()
            local slotList = DataMgr and DataMgr.MotionSlotList or {}
            local key = table.concat(slotList, ",")
            if key == _emoteSlotKey then return _emoteSlotCache end
            _emoteSlotKey = key
            _emoteSlotCache = {}
            for _, insID in ipairs(slotList) do
                insID = tonumber(insID)
                if insID and insID > 0 and isInjectedIns(insID) then
                    local resID = R.insToRes[insID]
                    if resID then
                        local c = cfg(resID)
                        if c and tonumber(c.ItemType) == 22 then
                            _emoteSlotCache[#_emoteSlotCache + 1] = {
                                resID = resID,
                                name = c.ItemName or "",
                                icon = c.ItemSmallIcon or c.ItemIcon or ""
                            }
                        end
                    end
                end
            end
            return _emoteSlotCache
        end

        local function hookIngameEmote()
            pcall(function()
                local QEU = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpressionUtils")
                if QEU._lava_hooked then return end
                QEU._lava_hooked = true

                local origGetList = QEU.GetShowExpressionList
                QEU.GetShowExpressionList = function()
                    local tShowEmoteList, nWeaponEmoteId = origGetList()
                    pcall(function()
                        tShowEmoteList = tShowEmoteList or {}
                        local emotes = getInjectedEmotes()
                        if #emotes > 0 then
                            local existingIDs = {}
                            for _, existing in pairs(tShowEmoteList) do
                                if existing.DefineID and existing.DefineID.TypeSpecificID then
                                    existingIDs[tonumber(existing.DefineID.TypeSpecificID) or 0] = true
                                end
                            end
                            for _, em in ipairs(emotes) do
                                if not existingIDs[em.resID] then
                                    tShowEmoteList[#tShowEmoteList + 1] = {
                                        DefineID = {TypeSpecificID = em.resID},
                                        Name = em.name
                                    }
                                end
                            end
                        end
                    end)
                    return tShowEmoteList, nWeaponEmoteId
                end
            end)

            pcall(function()
                local QE = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpression")
                if QE._lava_hooked_img then return end
                QE._lava_hooked_img = true

                local origGetImg = QE.GetEmoteImagePalthMap
                QE.GetEmoteImagePalthMap = function(self, ...)
                    origGetImg(self, ...)
                    local emotes = getInjectedEmotes()
                    for _, em in ipairs(emotes) do
                        if em.icon ~= "" then
                            self.ItemIDToImagePathMap[em.resID] = em.icon
                        end
                    end
                end
            end)

            pcall(function()
                local le = require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
                if le._lava_hooked_exist then return end
                le._lava_hooked_exist = true

                local origExist = le.IsEmoteExist
                le.IsEmoteExist = function(EmoteID)
                    if isInjectedRes(tonumber(EmoteID)) then return true end
                    return origExist(EmoteID)
                end

                local origDownloaded = le.CheckEmoteDownloaded
                if origDownloaded then
                    le.CheckEmoteDownloaded = function(EmoteID, bUseCache, bLobby, bForeceLobby)
                        if isInjectedRes(tonumber(EmoteID)) then return true end
                        return origDownloaded(EmoteID, bUseCache, bLobby, bForeceLobby)
                    end
                end
            end)
        end

        local function hookFashionBag()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                if fbd._lava_hooked_bag then return end
                fbd._lava_hooked_bag = true
                local function onFashionBagSkinChanged(skin, slot)
                    skin = tonumber(skin)
                    if _S.equipSkinApplying or not skin or skin <= 0 or not isInjectedIns(skin) then return end
                    local rid = R.insToRes[skin]
                    if not rid or not isInjectedRes(rid) then return end
                    local cch = cache()
                    local oldRes = cch.equip[slot]
                    if oldRes and oldRes > 0 and oldRes ~= rid then
                        softRemoveEquipVisual(oldRes, slot)
                    end
                    saveEquipSkin(rid, skin)
                    if slot ~= "parachute" and slot ~= "glider" then
                        applyEquipVisual(rid, skin, slot)
                    end
                end
                local origBag = fbd.SetBagSkin
                fbd.SetBagSkin = function(self, skin)
                    local r = origBag(self, skin)
                    onFashionBagSkinChanged(skin, "bag")
                    return r
                end
                local origHelm = fbd.SetHelmetSkin
                fbd.SetHelmetSkin = function(self, skin)
                    local r = origHelm(self, skin)
                    onFashionBagSkinChanged(skin, "helmet")
                    return r
                end
                local function reInjectThrowObjects(bagIndex)
                    pcall(function()
                        local cch = cache()
                        if not cch.throwObjects then return end
                        local bags = fbd.GetFashionBags and fbd:GetFashionBags()
                        if not bags or not bags.bags then return end
                        local bag = bags.bags[bagIndex]
                        if not bag then return end
                        bag.throw_object_list = bag.throw_object_list or {}
                        for st, info in pairs(cch.throwObjects) do
                            if info.insID and info.insID > 0 and _K.THROW_SUB[st] then
                                bag.throw_object_list[st] = info.insID
                            end
                        end
                    end)
                end
                local origUpdateAll = fbd.UpdateAllFashionBagExtraInfos
                if origUpdateAll then
                    fbd.UpdateAllFashionBagExtraInfos = function(self, all_knapsack_ext_info)
                        origUpdateAll(self, all_knapsack_ext_info)
                        if all_knapsack_ext_info then
                            for i, _ in pairs(all_knapsack_ext_info) do
                                reInjectThrowObjects(i)
                            end
                        end
                    end
                end
                local origUpdateOne = fbd.UpdateFashionBagExtraInfoByIndex
                if origUpdateOne then
                    fbd.UpdateFashionBagExtraInfoByIndex = function(self, index, knapsack_ext_info)
                        origUpdateOne(self, index, knapsack_ext_info)
                        if index then reInjectThrowObjects(index) end
                    end
                end
            end)
            pcall(function()
                if not DataMgr or DataMgr._lava_hooked_equip_skin then return end
                DataMgr._lava_hooked_equip_skin = true
                local orig = DataMgr.UpdateEquipmentSkin
                DataMgr.UpdateEquipmentSkin = function(itemSubType, putOnId)
                    putOnId = tonumber(putOnId)
                    if putOnId and putOnId > 0 and isInjectedIns(putOnId) and not _S.equipSkinApplying then
                        putOnEquipSkin(putOnId)
                    elseif putOnId == 0 then
                        local slot = (itemSubType == ENUM_ITEM_SUBTYPE.Backpack) and "bag"
                            or (itemSubType == ENUM_ITEM_SUBTYPE.Helmet_NoLevel) and "helmet" or nil
                        if slot then
                            local cch = cache()
                            takeOffEquipSkinVisual(slot, cch.equip[slot], cch.equip[slot .. "Ins"])
                            cch.equip[slot]          = nil
                            cch.equip[slot .. "Ins"] = nil
                            if MATCH_CONFIG.equip then MATCH_CONFIG.equip[slot] = 0 end
                            _S.matchApplied = false
                            invalidateSocialWearCache()
                            pcall(_AutoSaveOutfit)
                        end
                    end
                    return orig(itemSubType, putOnId)
                end
            end)
        end

        local function hookBackpackValid()
            if _G.DEV_WARDROBE_BP_HOOKED then return end
            _G.DEV_WARDROBE_BP_HOOKED = true
            pcall(function()
                local BU = import("BackpackUtils")
                if BU and BU.GetBPIDByResID then
                    local orig = BU.GetBPIDByResID
                    BU.GetBPIDByResID = function(resID)
                        resID = tonumber(resID)
                        if resID and isInjectedRes(resID) then
                            local bp = orig(resID)
                            if bp and bp > 0 then return bp end
                            return resID
                        end
                        return orig(resID)
                    end
                end
            end)
            pcall(function()
                local AU = import("AvatarUtils")
                if AU and AU.GetBPIDByResID then
                    local orig = AU.GetBPIDByResID
                    AU.GetBPIDByResID = function(resID, ...)
                        resID = tonumber(resID)
                        if resID and isInjectedRes(resID) then
                            local bp = orig(resID, ...)
                            if bp and bp > 0 then return bp end
                            return resID
                        end
                        return orig(resID, ...)
                    end
                end
            end)
        end

        local function hookAvatarValid()
            pcall(function()
                local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
                if not CAC._lava_hooked_check_valid then
                    CAC._lava_hooked_check_valid = true
                    local orig = CAC.CheckItemValid
                    CAC.CheckItemValid = function(self, resID)
                        if isInjectedRes(resID) then return true end
                        return orig(self, resID)
                    end
                end
                if not CAC._lava_hooked_puton then
                    CAC._lava_hooked_puton = true
                    local origPutOn = CAC.PutOnCustomEquipmentByID
                    CAC.PutOnCustomEquipmentByID = function(self, resID, CustomData)
                        -- Skip non-local player to avoid lag
                        if self.IsSelf and not self:IsSelf() then
                            return origPutOn(self, resID, CustomData)
                        end
                        resID = tonumber(resID)
                        if resID and isInjectedRes(resID) then
                            local ok, result = pcall(function()
                                local ItemDefineID = FItemDefineID(4, resID)
                                local EAvatarCustomType = import("EAvatarCustomType")
                                local AvatarCustom = FAvatarCustomDefault()
                                if CustomData then AvatarCustom = CustomData end
                                AvatarCustom.CustomType = EAvatarCustomType.AvatarCustomCharacter
                                return self:HandleEquipItem(ItemDefineID, AvatarCustom)
                            end)
                            if ok and result == true then return true end
                            if ok and result ~= false and result ~= nil then return result end
                        end
                        return origPutOn(self, resID, CustomData)
                    end
                end
            end)
        end

        -- ========== ماتش ==========
        local function isInLobby()
            local ok, r = pcall(function()
                return GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() == true
            end)
            return ok and r == true
        end

        local function isInRealMatch()
            local ok, r = pcall(function()
                return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus() == true
            end)
            return ok and r == true
        end

        local function isInGamePlay()
            if isInLobby() then return false end
            if isInRealMatch() then return true end
            local ok, r = pcall(function()
                local SingleTrainTool = require("GameLua.Mod.SingleTraining.GamePlay.Data.SingleTrainTool")
                return SingleTrainTool.IsSelfInTraining and SingleTrainTool.IsSelfInTraining()
            end)
            if ok and r then return true end
            local char = getLocalChar()
            return char and slua.isValid(char) and slua.isValid(char.CharacterAvatarComp2_BP)
        end

        local function getPlayerController()
            local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if ok and GD and GD.GetPlayerController then
                local pc = GD.GetPlayerController()
                if pc and slua.isValid(pc) then return pc end
            end
            local pc = nil
            pcall(function()
                if slua_GameFrontendHUD and slua_GameFrontendHUD.GetPlayerController then
                    pc = slua_GameFrontendHUD:GetPlayerController()
                end
            end)
            return pc and slua.isValid(pc) and pc or nil
        end

        function getLocalChar()
            local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if ok and GD and GD.GetPlayerCharacter then
                local char = GD.GetPlayerCharacter()
                if char and slua.isValid(char) then return char end
            end
            local pc = getPlayerController()
            if pc then
                local char = nil
                pcall(function()
                    if pc.GetPlayerCharacterSafety then char = pc:GetPlayerCharacterSafety() end
                    if (not char or not slua.isValid(char)) and pc.GetPawn then char = pc:GetPawn() end
                    if (not char or not slua.isValid(char)) and pc.K2_GetPawn then char = pc:K2_GetPawn() end
                end)
                if char and slua.isValid(char) then return char end
            end
            return nil
        end

        local function notify(msg)
            if not DEBUG or isInMatchOrGame() then return end
            msg = "[AddOutfit] " .. tostring(msg)
            log(msg:gsub("^%[AddOutfit%] ", ""))
            pcall(function()
                if ShowNotice then ShowNotice(msg, false, 10) end
            end)
        end

        local function getDesiredOutfit()
            if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
                return tonumber(MATCH_CONFIG.outfitRes)
            end
            local cch = cache()
            if tonumber(cch.outfitRes) and cch.outfitRes > 0 then return cch.outfitRes end
            if tonumber(_G.AddOutfitLastLobbyOutfitRes) and _G.AddOutfitLastLobbyOutfitRes > 0 then
                return tonumber(_G.AddOutfitLastLobbyOutfitRes)
            end
            return nil
        end

        local function getWearSlotForResID(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local itemCfg = cfg(resID)
            if not itemCfg then return 3 end
            local st = tonumber(itemCfg.ItemSubType or itemCfg.itemSubType or 0)
            if st == 401 then return 1 end
            if st == 402 then return 2 end
            if st == 403 then return 3 end
            if st == 404 then return 4 end
            if st == 405 then return 5 end
            if st == 407 then return 6 end
            if st == 400 or st == 408 then return 9 end
            if st == 409 or st == 410 then return 10 end
            if getEquipSkinSlot(resID) then return nil end
            if weaponIdFromSkin(resID) then return nil end
            return 3
        end

        local function makeWearEntry(resID)
            local ENUM = ENUM_AVATAR_DATA_TYPE or { ItemID = 1, ColorID = 2, PatternID = 3 }
            return { [ENUM.ItemID] = resID, [ENUM.ColorID] = 0, [ENUM.PatternID] = 0 }
        end

        local function isApplySuccess(r) return r ~= false end

        local function refreshMatchAvatar(comp)
            if not slua.isValid(comp) then return end
            pcall(function() if comp.ProcessAvatarRectify then comp:ProcessAvatarRectify() end end)
            pcall(function() if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end end)
            pcall(function() if comp.RefreshAvatarReAttach then comp:RefreshAvatarReAttach() end end)
        end

        local function applyItemToMatchAvatar(comp, resID)
            if not slua.isValid(comp) or not resID or not isInjectedRes(resID) then return false end
            resID = tonumber(resID)
            local applied = false
            pcall(function()
                comp.bSyncAvatar = false
                comp.forceLodMode = true
                comp.bIsLobbyAvatar = false
            end)
            local AvatarData = require("client.logic.data.AvatarData")
            local wearEntry = makeWearEntry(resID)
            local AData = AvatarData.ConvertToAvatarCustom and AvatarData.ConvertToAvatarCustom(wearEntry)
                or AvatarData.CreateAvatarCustom(resID, 0, 0)
            pcall(function()
                if comp.PutOnEquipmentByResID then
                    local r = comp:PutOnEquipmentByResID(AData.ItemID or resID, AData)
                    if isApplySuccess(r) then applied = true end
                end
            end)
            if not applied then
                pcall(function()
                    if comp.PutOnCustomEquipmentByID then
                        local r = comp:PutOnCustomEquipmentByID(resID, AData)
                        if isApplySuccess(r) then applied = true end
                    end
                end)
            end
            if not applied then
                pcall(function()
                    local ItemDefineID = FItemDefineID(4, resID)
                    local EAvatarCustomType = import("EAvatarCustomType")
                    local AvatarCustom = FAvatarCustomDefault()
                    AvatarCustom.CustomType = EAvatarCustomType.AvatarCustomCharacter
                    local r = comp:HandleEquipItem(ItemDefineID, AvatarCustom)
                    if isApplySuccess(r) then applied = true end
                end)
            end
            if applied then refreshMatchAvatar(comp) end
            return applied
        end

        local function applyClothToComp(comp, resID)
            if not slua.isValid(comp) then return false end
            local ok = false
            pcall(function()
                if comp.PutOnCustomEquipmentByID then
                    local r = comp:PutOnCustomEquipmentByID(resID)
                    if isApplySuccess(r) then ok = true end
                end
            end)
            if ok then return true end
            return applyItemToMatchAvatar(comp, resID)
        end

        local function applyBodyClothesToComp(comp)
            if not slua.isValid(comp) then
                report("body: comp invalid")
                return false
            end
            local outfitRes = getDesiredOutfit()
            local applied = false
            local okList = {}
            local failList = {}

            if outfitRes and isFullSuitRes(outfitRes) then
                pcall(function()
                    local r = comp:PutOnCustomEquipmentByID(outfitRes)
                    if isApplySuccess(r) then applied = true end
                end)
                if not applied then
                    pcall(function()
                        local r = comp:HandleEquipItem(FItemDefineID(4, outfitRes), FAvatarCustomDefault())
                        if isApplySuccess(r) then applied = true end
                    end)
                end
                if applied then
                    _G.SuitSkin = outfitRes
                    notify("بدلة OK " .. outfitRes)
                else
                    failList[#failList + 1] = tostring(outfitRes) .. "(suit)"
                end
                -- تطبيق الإكسسوارات (ماسك/نظارة/طاقية) فوق البدلة الكاملة
                for resID in pairs(collectAllClothResIDs()) do
                    if resID ~= outfitRes and not isFullSuitRes(resID)
                        and not isBodyClothSubType(subType(cfg(resID))) then
                        if applyClothToComp(comp, resID) then
                            applied = true
                            okList[#okList + 1] = tostring(resID)
                            notify("إكسسوار OK " .. resID)
                        else
                            failList[#failList + 1] = tostring(resID)
                        end
                    end
                end
            else
                for resID in pairs(collectAllClothResIDs()) do
                    if not isFullSuitRes(resID) then
                        if applyClothToComp(comp, resID) then
                            applied = true
                            okList[#okList + 1] = tostring(resID)
                            notify("ملابس OK " .. resID)
                        else
                            failList[#failList + 1] = tostring(resID)
                        end
                    end
                end
            end
            report("body applied: outfit=" .. tostring(outfitRes) .. " ok={" .. table.concat(okList, ",") .. "} fail={" .. table.concat(failList, ",") .. "}")
            return applied
        end

        local function matchApplyOutfit(char)
            syncWeaponCacheFromLobby()
            syncClothesCacheFromLobby()
            local comp = char.CharacterAvatarComp2_BP
            if not slua.isValid(comp) then
                report("matchApplyOutfit: comp invalid")
                return false
            end
            local cch = cache()
            local clothList = {}
            for rid in pairs(cch.clothes or {}) do clothList[#clothList + 1] = tostring(rid) end
            report("matchApplyOutfit: outfit=" .. tostring(cch.outfitRes) .. " clothes={" .. table.concat(clothList, ",") .. "}")
            local ok = applyBodyClothesToComp(comp)
            report("matchApplyOutfit result: " .. tostring(ok))
            return ok
        end

        local _lastReapplyBody = 0
        local function reapplyMatchBodyClothes()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastReapplyBody) < 0.5 then return false end
            _lastReapplyBody = now
            local char = getLocalChar()
            if not char or not slua.isValid(char) then
                report("reapply: no local char")
                return false
            end
            local comp = char.CharacterAvatarComp2_BP
            if not slua.isValid(comp) then
                report("reapply: comp invalid")
                return false
            end
            local ok = applyBodyClothesToComp(comp)
            report("reapply done: " .. tostring(ok))
            return ok
        end

        local _lastPatchTime = 0
        local function patchPlayerInfoForMatch(PlayerInfo)
            if not PlayerInfo then return end
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastPatchTime) < 1.0 then return end  -- throttle: max once per second
            _lastPatchTime = now
            snapshotLobbyWear()
            local cch = cache()
            if cch.equip.bag then PlayerInfo.bag_skin = cch.equip.bag end
            if cch.equip.helmet then PlayerInfo.helmet_skin = cch.equip.helmet end
            if cch.equip.armor then PlayerInfo.armor_skin = cch.equip.armor end

            local idx = tonumber(PlayerInfo.use_rolewear) or 1
            PlayerInfo.use_rolewear = idx
            PlayerInfo.all_knapsack_ext_info = PlayerInfo.all_knapsack_ext_info or {}
            PlayerInfo.all_knapsack_ext_info[idx] = PlayerInfo.all_knapsack_ext_info[idx] or {}
            local ext = PlayerInfo.all_knapsack_ext_info[idx]
            if cch.equip.bag then
                local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                local bagLists = buildEquipSkinLists(catalogBag)
                ext.bag_skin = catalogBag
                ext.bag_skin_list = bagLists
                PlayerInfo.bag_skin = catalogBag
            end
            if cch.equip.helmet then
                local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                local helmLists = buildEquipSkinLists(catalogHelm)
                ext.helmet_skin = catalogHelm
                ext.helmet_skin_list = helmLists
                PlayerInfo.helmet_skin = catalogHelm
            end
            if cch.equip.armor then ext.armor_skin = cch.equip.armor end
            if cch.equip.parachute and cch.equip.parachute > 0 then
                ext.parachute = cch.equip.parachuteIns or cch.equip.parachute
            end
            if cch.equip.glider and cch.equip.glider > 0 then
                ext.gliding = cch.equip.glider
            end

            pcall(function()
                if cch.throwObjects then
                    local throwList = {}
                    for st, info in pairs(cch.throwObjects) do
                        if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                            throwList[st] = info.resID
                        end
                    end
                    if next(throwList) then
                        local function applyThrowList(kext)
                            if not kext then return end
                            kext.throw_object_list = kext.throw_object_list or {}
                            for st, resID in pairs(throwList) do
                                kext.throw_object_list[st] = resID
                            end
                        end
                        applyThrowList(ext)
                        applyThrowList(PlayerInfo.knapsack_ext_info)
                        PlayerInfo.all_knapsack_ext_info = PlayerInfo.all_knapsack_ext_info or {}
                        for i = 1, 6 do
                            PlayerInfo.all_knapsack_ext_info[i] = PlayerInfo.all_knapsack_ext_info[i] or {}
                            applyThrowList(PlayerInfo.all_knapsack_ext_info[i])
                        end
                        for i, kext in pairs(PlayerInfo.all_knapsack_ext_info) do
                            applyThrowList(kext)
                        end
                        log("patchPlayerInfoForMatch: throw_object_list injected into all knapsack entries")
                    end
                end
            end)

            pcall(function()
                if DataMgr and DataMgr.VehicleSlotList then
                    PlayerInfo.vst_in_battle = PlayerInfo.vst_in_battle or {}
                    for subType, insList in pairs(DataMgr.VehicleSlotList) do
                        if insList and type(insList) == "table" then
                            local resList = {}
                            for i, insID in ipairs(insList) do
                                insID = tonumber(insID)
                                if insID and insID > 0 then
                                    local resID
                                    if isInjectedIns(insID) then
                                        resID = R.insToRes[insID]
                                    else
                                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                        local d = wd:GetHallDepotItemDataByInsID(insID)
                                        resID = d and tonumber(d.resID)
                                    end
                                    if resID and resID > 0 then
                                        resList[#resList + 1] = resID
                                    end
                                end
                            end
                            if #resList > 0 then
                                PlayerInfo.vst_in_battle[subType] = resList
                            end
                        end
                    end
                    if DataMgr.vst_skin then
                        local skinIns = tonumber(DataMgr.vst_skin)
                        if skinIns and skinIns > 0 then
                            local skinRes
                            if isInjectedIns(skinIns) then
                                skinRes = R.insToRes[skinIns]
                            else
                                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                local d = wd:GetHallDepotItemDataByInsID(skinIns)
                                skinRes = d and tonumber(d.resID)
                            end
                            if skinRes and skinRes > 0 then
                                PlayerInfo.vst_skin = skinRes
                            end
                        end
                    end
                end
            end)
        end

        local _lastApplyEquipToController = 0
        local function applyMatchEquipAvatarToController()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastApplyEquipToController) < 0.3 then return false end  -- throttle: max 3x/sec
            _lastApplyEquipToController = now
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local cch = cache()
            if not cch.equip.bag and not cch.equip.helmet and not cch.equip.armor and not cch.equip.parachute and not cch.equip.glider then return false end

            local char = getLocalChar()
            local eq = pc.InitialEquipmentAvatar or {}

            -- طبّق سكن الشنطة فقط لو اللاعب لابس شنطة فعلاً
            if cch.equip.bag and cch.equip.bag > 0 and isWearingEquip(char, "bag") then
                local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                local bagLists = buildEquipSkinLists(catalogBag)
                eq.BagAvatar = catalogBag
                eq.BagAvatarList = bagLists
                local realBagId = getCharEquipLevel(char, 8) or 0
                local bagLevel
                if realBagId > 0 and isBaseEquipItemId(realBagId) then
                    bagLevel = detectEquipLevelFromBaseId(realBagId, catalogBag)
                elseif realBagId > 0 then
                    bagLevel = detectLevelFromEquipRes(realBagId)
                end
                bagLevel = bagLevel or getEquipDisplayLevel(cch.equip.bag, "bag")
                local bagDisplay = mapEquipSkinRes(catalogBag, bagLevel)
                if bagDisplay > 0 then eq.BagAvatar = bagDisplay end
            else
                eq.BagAvatar = 0
                eq.BagAvatarList = nil
            end
            -- طبّق سكن الخوذة فقط لو اللاعب لابس خوذة فعلاً
            if cch.equip.helmet and cch.equip.helmet > 0 and isWearingEquip(char, "helmet") then
                local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                local helmLists = buildEquipSkinLists(catalogHelm)
                eq.HelmetAvatar = catalogHelm
                eq.HelmetAvatarList = helmLists
                local realHelmId = getCharEquipLevel(char, 9) or 0
                local helmLevel
                if realHelmId > 0 and isBaseEquipItemId(realHelmId) then
                    helmLevel = detectEquipLevelFromBaseId(realHelmId, catalogHelm)
                elseif realHelmId > 0 then
                    helmLevel = detectLevelFromEquipRes(realHelmId)
                end
                helmLevel = helmLevel or getEquipDisplayLevel(cch.equip.helmet, "helmet")
                local helmDisplay = mapEquipSkinRes(catalogHelm, helmLevel)
                if helmDisplay > 0 then eq.HelmetAvatar = helmDisplay end
            else
                eq.HelmetAvatar = 0
                eq.HelmetAvatarList = nil
            end
            if cch.equip.armor then eq.ArmorAvatar = cch.equip.armor end
            if cch.equip.parachute and cch.equip.parachute > 0 then
                eq.ParachuteAvatar = cch.equip.parachute
            end
            if cch.equip.glider and cch.equip.glider > 0 then
                eq.GliderAvatar = cch.equip.glider
            end

            pc.InitialEquipmentAvatar = eq
            pcall(function()
                if slua.isValid(pc.PlayerState) and pc.PlayerState.MetroPlayerStateAvatarFeature then
                    pc.PlayerState.MetroPlayerStateAvatarFeature.InitialEquipmentAvatar = eq
                end
            end)
            pcall(function()
                local comp = char and char.CharacterAvatarComp2_BP
                if slua.isValid(comp) and comp.GetEquipmentSkinItemID then
                    if cch.equip.helmet and isWearingEquip(char, "helmet") then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.helmet) end)
                    end
                    if cch.equip.bag and isWearingEquip(char, "bag") then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.bag) end)
                    end
                    if cch.equip.parachute and isWearingEquip(char, "parachute") then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.parachute) end)
                    end
                    if cch.equip.glider and cch.equip.glider > 0 then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.glider) end)
                    end
                end
            end)
            pcall(function()
                if pc.OnEquipmentAvatarChange and pc.OnEquipmentAvatarChange.Broadcast then
                    pc.OnEquipmentAvatarChange:Broadcast()
                end
            end)
            notify("معدات: خوذة=" .. tostring(eq.HelmetAvatar) .. " شنطة=" .. tostring(eq.BagAvatar))
            return true
        end

        local function hookEquipMapping()
            pcall(function()
                if DataMgr and not DataMgr._lava_equip_map_hooked then
                    DataMgr._lava_equip_map_hooked = true
                    local orig = DataMgr.GetEquipmentItemIDByResID
                    DataMgr.GetEquipmentItemIDByResID = function(level, itemResID)
                        level, itemResID = tonumber(level) or 3, tonumber(itemResID)
                        local catalogRes = normalizeEquipCatalogRes(itemResID)
                        local r = orig(level, catalogRes)
                        if r and r > 0 then return r end
                        if isInjectedIns(itemResID) then
                            return mapEquipSkinRes(normalizeEquipCatalogRes(R.insToRes[itemResID]), level)
                        end
                        if isInjectedRes(itemResID) then
                            return mapEquipSkinRes(catalogRes, level)
                        end
                        return r or 0
                    end
                end
            end)
            pcall(function()
                local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                if lav._lava_skinins_hooked then return end
                lav._lava_skinins_hooked = true
                local orig2 = lav.GetEquipmentItemIDBySkinInsID
                lav.GetEquipmentItemIDBySkinInsID = function(self, itemSubType, itemInsID)
                    local level = lav.GetEquipmentItemShowLevel(lav, itemSubType)
                    local r = orig2(self, itemSubType, itemInsID)
                    if r and r > 0 then return r end
                    itemInsID = tonumber(itemInsID)
                    if isInjectedIns(itemInsID) then
                        return mapEquipSkinRes(normalizeEquipCatalogRes(R.insToRes[itemInsID]), level)
                    end
                    pcall(function()
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetHallDepotItemDataByInsID(itemInsID)
                        if d and isInjectedRes(d.resID) then
                            return mapEquipSkinRes(normalizeEquipCatalogRes(d.resID), level)
                        end
                    end)
                    return r
                end
            end)
            pcall(function()
                local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
                if CAC._lava_equip_skin_hooked then return end
                CAC._lava_equip_skin_hooked = true
                local orig3 = CAC.GetEquipmentSkinItemID
                CAC.GetEquipmentSkinItemID = function(self, InItemID)
                    -- Skip non-local player equipment to avoid lag
                    if self.IsSelf and not self:IsSelf() then
                        return orig3(self, InItemID)
                    end
                    local cch = cache()
                    InItemID = tonumber(InItemID) or 0

                    local function tryGetSkin(catalogRes)
                        if not catalogRes or catalogRes <= 0 then return 0 end
                        catalogRes = normalizeEquipCatalogRes(catalogRes)
                        local skin = resolveMatchEquipSkin(catalogRes, InItemID)
                        if skin > 0 then return skin end
                        for lvl = 1, 3 do
                            local s = mapEquipSkinRes(catalogRes, lvl)
                            if s > 0 then return s end
                        end
                        return 0
                    end

                    if InItemID > 0 and isBaseEquipItemId(InItemID) then
                        local isHelmetBase = GAME_HELMET_LEVEL[InItemID] ~= nil
                            or (InItemID >= 1505000001 and InItemID <= 1505000100)
                            or (InItemID >= 502001 and InItemID <= 502999)
                        local isBagBase = GAME_BAG_LEVEL[InItemID] ~= nil
                            or (InItemID >= 501001 and InItemID <= 501999)
                            or (InItemID >= 1501000000 and InItemID < 1502000000)

                        local char = getLocalChar()
                        if isHelmetBase and cch.equip.helmet and cch.equip.helmet > 0 then
                            if char and isWearingEquip(char, "helmet") then
                                local skin = tryGetSkin(cch.equip.helmet)
                                if skin > 0 then return skin end
                            end
                        end
                        if isBagBase and cch.equip.bag and cch.equip.bag > 0 then
                            if char and isWearingEquip(char, "bag") then
                                local skin = tryGetSkin(cch.equip.bag)
                                if skin > 0 then return skin end
                            end
                        end
                    end

                    local origResult = orig3(self, InItemID)
                    if origResult and origResult > 0 and origResult ~= InItemID then
                        return origResult
                    end

                    -- fallback مع تحقق isWearingEquip
                    local isHelmetQuery = GAME_HELMET_LEVEL[InItemID] ~= nil or (InItemID >= 502001 and InItemID <= 502999)
                    local isBagQuery = GAME_BAG_LEVEL[InItemID] ~= nil or (InItemID >= 501001 and InItemID <= 501999)
                    local char = getLocalChar()

                    if isHelmetQuery and cch.equip.helmet and cch.equip.helmet > 0 then
                        if char and isWearingEquip(char, "helmet") then
                            local skin = tryGetSkin(cch.equip.helmet)
                            if skin > 0 then return skin end
                        end
                    end
                    if isBagQuery and cch.equip.bag and cch.equip.bag > 0 then
                        if char and isWearingEquip(char, "bag") then
                            local skin = tryGetSkin(cch.equip.bag)
                            if skin > 0 then return skin end
                        end
                    end
                    return origResult
                end
                local origEquipFinish = CAC.OnAvatarEquipFinish
                CAC.OnAvatarEquipFinish = function(self, slotType, isEquipped, itemID)
                    if origEquipFinish then origEquipFinish(self, slotType, isEquipped, itemID) end
                    if not isEquipped then return end
                    -- Only process local player equipment to avoid lag
                    if not self.IsSelf or not self:IsSelf() then return end
                    pcall(function()
                        if self.IsLobbyActor and self:IsLobbyActor() then return end
                        local EAvatarSlotType = import("EAvatarSlotType")
                        local cch = cache()
                        local isHelmet = slotType == EAvatarSlotType.EAvatarSlotType_HelmetEquipemtSlot
                        local isBag = slotType == EAvatarSlotType.EAvatarSlotType_BackpackEquipemtSlot
                        if (isHelmet and cch.equip.helmet and cch.equip.helmet > 0)
                            or (isBag and cch.equip.bag and cch.equip.bag > 0) then
                            local owner = self.GetOwner and self:GetOwner()
                            if owner and slua.isValid(owner) and owner.AddGameTimer then
                                owner:AddGameTimer(0.25, false, function()
                                    if slua.isValid(owner) then matchApplyEquipSkins(owner) end
                                end)
                            end
                        end
                        applyMatchEquipAvatarToController()
                    end)
                end
            end)
        end

        local function applyMatchEquipSkinAtLevel(comp, catalogResID, level)
            if not slua.isValid(comp) or not catalogResID or catalogResID <= 0 then return false end
            catalogResID = normalizeEquipCatalogRes(catalogResID)
            level = tonumber(level) or 3
            local skinId = mapEquipSkinRes(catalogResID, level)
            if not skinId or skinId <= 0 then skinId = catalogResID end
            local ok = false
            pcall(function()
                if comp.PutOnCustomEquipmentByID then
                    local r = comp:PutOnCustomEquipmentByID(skinId)
                    if isApplySuccess(r) then ok = true end
                end
            end)
            if not ok then
                pcall(function()
                    local r = comp:HandleEquipItem(FItemDefineID(4, skinId), FAvatarCustomDefault())
                    if isApplySuccess(r) then ok = true end
                end)
            end
            if ok then refreshMatchAvatar(comp) end
            return ok
        end

            -- أضف الدالة دي قبل matchApplyEquipSkins
        local function getCharEquipLevel(char, slotID)
            local found = nil
            pcall(function()
                local comp = char and char.CharacterAvatarComp2_BP
                if not slua.isValid(comp) then return end
                local NetAvatarData = slua.IndexReference(comp, "NetAvatarData")
                if not NetAvatarData then return end
                local TempSlotSyncData = slua.IndexReference(NetAvatarData, "SlotSyncData")
                if not TempSlotSyncData then return end
                for Index, AvatarSynData in pairs(TempSlotSyncData) do
                    if AvatarSynData.SlotID == slotID and AvatarSynData.ItemID and AvatarSynData.ItemID > 0 then
                        found = AvatarSynData.ItemID
                        return
                    end
                end
            end)
            return found
        end

        local function isWearingEquip(char, slot)
            local slotID = (slot == "helmet") and 9 or (slot == "bag") and 8 or (slot == "parachute") and 11 or (slot == "glider") and 15 or nil
            if not slotID then return false end

            -- 1) تحقق من SlotSyncData بنفس طريقة pairs الشغالة
            local itemID = getCharEquipLevel(char, slotID)
            if itemID and itemID > 0 then return true end

            -- 2) تحقق من PlayerState EquipmentAvatarData
            local wearing = false
            pcall(function()
                local pc = getPlayerController()
                if not pc or not slua.isValid(pc) then return end
                if pc.PlayerState and pc.PlayerState.MetroPlayerStateAvatarFeature then
                    local psEquip = pc.PlayerState.MetroPlayerStateAvatarFeature.EquipmentAvatarData
                    if psEquip then
                        if slot == "helmet" and psEquip.HelmetAvatar and psEquip.HelmetAvatar > 0 then
                            wearing = true
                        elseif slot == "bag" and psEquip.BagAvatar and psEquip.BagAvatar > 0 then
                            wearing = true
                        end
                    end
                end
            end)
            return wearing
        end

        local _lastMatchApplyEquip = 0
        local function matchApplyEquipSkins(char)
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastMatchApplyEquip) < 0.5 then return false end  -- throttle: max 2x/sec
            _lastMatchApplyEquip = now
            local cch = cache()
            if not cch.equip.bag and not cch.equip.helmet and not cch.equip.parachute and not cch.equip.glider then return false end
            local comp = char and char.CharacterAvatarComp2_BP
            if not slua.isValid(comp) then return false end
            local ok = false

            if cch.equip.helmet and cch.equip.helmet > 0 then
                if isWearingEquip(char, "helmet") then
                    local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                    local realHelmId = getCharEquipLevel(char, 9) or 0
                    local helmLevel
                    if realHelmId > 0 and isBaseEquipItemId(realHelmId) then
                        helmLevel = detectEquipLevelFromBaseId(realHelmId, catalogHelm)
                    elseif realHelmId > 0 then
                        helmLevel = detectLevelFromEquipRes(realHelmId)
                    end
                    helmLevel = helmLevel or getEquipDisplayLevel(cch.equip.helmet, "helmet")
                    if applyMatchEquipSkinAtLevel(comp, catalogHelm, helmLevel) then
                        ok = true
                        notify("خوذة ماتش OK " .. mapEquipSkinRes(catalogHelm, helmLevel))
                    end
                end
            end

            if cch.equip.bag and cch.equip.bag > 0 then
                if isWearingEquip(char, "bag") then
                    local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                    local realBagId = getCharEquipLevel(char, 8) or 0
                    local bagLevel
                    if realBagId > 0 and isBaseEquipItemId(realBagId) then
                        bagLevel = detectEquipLevelFromBaseId(realBagId, catalogBag)
                    elseif realBagId > 0 then
                        bagLevel = detectLevelFromEquipRes(realBagId)
                    end
                    bagLevel = bagLevel or getEquipDisplayLevel(cch.equip.bag, "bag")
                    if applyMatchEquipSkinAtLevel(comp, catalogBag, bagLevel) then
                        ok = true
                        notify("شنطة ماتش OK " .. mapEquipSkinRes(catalogBag, bagLevel))
                    end
                end
            end

            if cch.equip.parachute and cch.equip.parachute > 0 then
                if isWearingEquip(char, "parachute") then
                    local paraResID = cch.equip.parachute
                    pcall(function()
                        if comp.PutOnCustomEquipmentByID then
                            local r = comp:PutOnCustomEquipmentByID(paraResID)
                            if isApplySuccess(r) then
                                ok = true
                                notify("براشوت ماتش OK " .. tostring(paraResID))
                            end
                        end
                    end)
                    if not ok then
                        pcall(function()
                            local r = comp:HandleEquipItem(FItemDefineID(4, paraResID), FAvatarCustomDefault())
                            if isApplySuccess(r) then
                                ok = true
                                notify("براشوت ماتش OK " .. tostring(paraResID))
                            end
                        end)
                    end
                end
            end

            if cch.equip.glider and cch.equip.glider > 0 then
                local gliderResID = cch.equip.glider
                pcall(function()
                    if comp.PutOnCustomEquipmentByID then
                        local r = comp:PutOnCustomEquipmentByID(gliderResID)
                        if isApplySuccess(r) then
                            ok = true
                            notify("جلايدر ماتش OK " .. tostring(gliderResID))
                        end
                    end
                end)
                if not ok then
                    pcall(function()
                        local r = comp:HandleEquipItem(FItemDefineID(4, gliderResID), FAvatarCustomDefault())
                        if isApplySuccess(r) then
                            ok = true
                            notify("جلايدر ماتش OK " .. tostring(gliderResID))
                        end
                    end)
                end
            end

            -- حدّث PlayerController بعد تطبيق السكنات (مش قبل، عشان نتجنب circular dependency)
            applyMatchEquipAvatarToController()

            -- باقي كود SlotSyncData بدون تغيير...
            pcall(function()
                local NetAvatarData = slua.IndexReference(comp, "NetAvatarData")
                if not NetAvatarData then return end
                local TempSlotSyncData = slua.IndexReference(NetAvatarData, "SlotSyncData")
                if not TempSlotSyncData then return end

                for Index, AvatarSynData in pairs(TempSlotSyncData) do
                    local slotID = AvatarSynData.SlotID
                    local NDRid = AvatarSynData.ItemID

                    if slotID == 8 and NDRid ~= 0 and cch.equip.bag and cch.equip.bag > 0 then
                        local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                        local bagLevel
                        if isBaseEquipItemId(NDRid) then
                            bagLevel = detectEquipLevelFromBaseId(NDRid, catalogBag)
                        else
                            bagLevel = detectLevelFromEquipRes(NDRid)
                        end
                        bagLevel = bagLevel or getEquipDisplayLevel(cch.equip.bag, "bag")
                        local skinId = mapEquipSkinRes(catalogBag, bagLevel)
                        if skinId <= 0 then skinId = mapEquipSkinRes(catalogBag, 3) end
                        if skinId > 0 and NDRid ~= skinId then
                            AvatarSynData.ItemID = skinId
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end

                    if slotID == 9 and NDRid ~= 0 and cch.equip.helmet and cch.equip.helmet > 0 then
                        local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                        local helmLevel
                        if isBaseEquipItemId(NDRid) then
                            helmLevel = detectEquipLevelFromBaseId(NDRid, catalogHelm)
                        else
                            helmLevel = detectLevelFromEquipRes(NDRid)
                        end
                        helmLevel = helmLevel or getEquipDisplayLevel(cch.equip.helmet, "helmet")
                        local skinId = mapEquipSkinRes(catalogHelm, helmLevel)
                        if skinId <= 0 then skinId = mapEquipSkinRes(catalogHelm, 3) end
                        if skinId > 0 and NDRid ~= skinId then
                            AvatarSynData.ItemID = skinId
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end

                    -- براشوت - SlotID 11 (ParachuteEquipemtSlot)
                    if slotID == 11 and NDRid ~= 0 and cch.equip.parachute and cch.equip.parachute > 0 then
                        local paraResID = cch.equip.parachute
                        if NDRid ~= paraResID then
                            AvatarSynData.ItemID = paraResID
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end

                    -- جلايدر - SlotID 15 (GlideEquipmtSlot)
                    if slotID == 15 and NDRid ~= 0 and cch.equip.glider and cch.equip.glider > 0 then
                        local gliderResID = cch.equip.glider
                        if NDRid ~= gliderResID then
                            AvatarSynData.ItemID = gliderResID
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end
                end

                if ok and comp.OnRep_BodySlotStateChanged then
                    comp:OnRep_BodySlotStateChanged()
                end
            end)
            return ok
        end

        local function hookPlayerWearingDone()
            pcall(function()
                local pc = getPlayerController()
                if not pc or not slua.isValid(pc) or pc._lava_wear_done_hooked then return end
                pc._lava_wear_done_hooked = true
                if pc.OnPlayerChangeWearingDone and pc.OnPlayerChangeWearingDone.Add then
                    pc.OnPlayerChangeWearingDone:Add(function()
                        if GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() then
                            ensureLobbyInjectedWear()
                            return
                        end
                        applyMatchEquipAvatarToController()
                        local char = getLocalChar()
                        if char then
                            char:AddGameTimer(0.2, false, function()
                                if slua.isValid(char) then
                                    pcall(reapplyMatchBodyClothes)
                                    matchApplyEquipSkins(char)
                                end
                            end)
                        end
                    end)
                end
            end)
        end

        local function hookCommerAvatarData()
            pcall(function()
                local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
                if CommerAvatarDataUtil._lava_hooked_equip then return end
                CommerAvatarDataUtil._lava_hooked_equip = true
                local orig = CommerAvatarDataUtil.GeneratePlayerAvatarData
                CommerAvatarDataUtil.GeneratePlayerAvatarData = function(self, PlayerInfo, uPlayerController, ...)
                    -- Skip expensive operations for non-local players
                    local localPC = getPlayerController()
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        pcall(function() patchPlayerInfoForMatch(PlayerInfo) end)
                    end
                    orig(self, PlayerInfo, uPlayerController, ...)
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        report("avatar rebuild: CommerAvatarData")
                        pcall(reapplyMatchBodyClothes)
                        applyMatchEquipAvatarToController()
                    end
                end
            end)
        end

        local function hookMatchAvatarData()
            hookCommerAvatarData()
            pcall(function()
                local AvatarDataUtil = require("GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil")
                if AvatarDataUtil._lava_hooked_gen then return end
                AvatarDataUtil._lava_hooked_gen = true
                local origGet = AvatarDataUtil.GetPlayerInfo
                AvatarDataUtil.GetPlayerInfo = function(uPlayerController)
                    local pi = origGet(uPlayerController)
                    -- Only patch for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if pi and uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        patchPlayerInfoForMatch(pi)
                    end
                    return pi
                end
                local origGen = AvatarDataUtil.GeneratePlayerAvatarData
                AvatarDataUtil.GeneratePlayerAvatarData = function(uPlayerController)
                    -- Only patch for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        pcall(function()
                            local PlayerInfo = AvatarDataUtil.GetPlayerInfo(uPlayerController)
                            if PlayerInfo then patchPlayerInfoForMatch(PlayerInfo) end
                        end)
                    end
                    origGen(uPlayerController)
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        report("avatar rebuild: AvatarDataUtil.Gen")
                        pcall(reapplyMatchBodyClothes)
                        applyMatchEquipAvatarToController()
                    end
                    return
                end
                local origInit = AvatarDataUtil.InitialEquipmentAvatar
                AvatarDataUtil.InitialEquipmentAvatar = function(PlayerInfo, uPlayerController)
                    -- Only patch for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        pcall(function() patchPlayerInfoForMatch(PlayerInfo) end)
                    end
                    origInit(PlayerInfo, uPlayerController)
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        report("avatar rebuild: InitialEquipmentAvatar")
                        pcall(reapplyMatchBodyClothes)
                        applyMatchEquipAvatarToController()
                    end
                end
            end)
        end

        local function hookClassMethod(classModule, methodName, hookTag, newFunc)
            if not classModule then log("hookClassMethod: nil classModule for", methodName) return false end
            local impl = classModule.__inner_impl
            if not impl then log("hookClassMethod: no __inner_impl for", methodName) return false end
            if impl[hookTag] then log("hookClassMethod: already hooked", methodName) return false end
            local orig = impl[methodName]
            if not orig then log("hookClassMethod: no orig method", methodName) return false end
            impl[hookTag] = true
            impl[methodName] = function(...)
                return newFunc(orig, ...)
            end
            pcall(function() rawset(classModule, methodName, nil) end)
            -- log("hookClassMethod: hooked", methodName)
            return true
        end

        local function hookGrenadeAvatarInit()
            pcall(function()
                local PCB = require("GameLua.GameCore.Framework.PlayerControllerBase")
                -- log suppressed
                hookClassMethod(PCB, "InitGrenadeAvatarList", "_lava_hooked_grenade_init", function(orig, self, ReInitial)
                    orig(self, ReInitial)
                    -- Only inject for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if not localPC or self ~= localPC then return end
                    if ReInitial then
                        pcall(function()
                            local cch = cache()
                            if cch.throwObjects and self.AddToGrenadeAvatarItemList then
                                for st, info in pairs(cch.throwObjects) do
                                    if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                                        self:AddToGrenadeAvatarItemList(info.resID)
                                    end
                                end
                            end
                        end)
                    end
                end)
            end)
        end

        local function applyGrenadeSkinsToController()
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local cch = cache()
            if not cch.throwObjects then return false end
            local hasThrow = false
            for _, info in pairs(cch.throwObjects) do
                if info.resID and info.resID > 0 then hasThrow = true break end
            end
            if not hasThrow then return false end
            pcall(function()
                if pc.AddToGrenadeAvatarItemList then
                    for st, info in pairs(cch.throwObjects) do
                        if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                            pc:AddToGrenadeAvatarItemList(info.resID)
                        end
                    end
                end
                if pc.OnWeaponAvatarUpdate then
                    pc:OnWeaponAvatarUpdate()
                end
                local char = getLocalChar()
                if char and slua.isValid(char) then
                    local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
                    if slua.isValid(curWeapon) then
                        local wid = 0
                        pcall(function() wid = curWeapon:GetWeaponID() end)
                        if wid >= 602001 and wid <= 602004 then
                            log("applyGrenadeSkinsToController: held grenade wid=", wid)
                            if curWeapon.DelayHandleAvatarMeshChanged then
                                curWeapon:DelayHandleAvatarMeshChanged()
                            end
                            if curWeapon.HandleAvatarMeshChanged then
                                curWeapon:HandleAvatarMeshChanged()
                            end
                            local GRENADE_WID_TO_SUB = {
                                [602001] = 614, [602002] = 613,
                                [602003] = 615, [602004] = 612,
                            }
                            local sub = GRENADE_WID_TO_SUB[wid]
                            local info = sub and cch.throwObjects[sub]
                            if info and info.resID and info.resID > 0 then
                                if slua.isValid(curWeapon.GrenadeAvatarComponent_BP) then
                                    curWeapon.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false)
                                    log("applyGrenadeSkinsToController: ChangeItemAvatar on held weapon", info.resID)
                                end
                                if curWeapon.AddGameTimer then
                                    curWeapon:AddGameTimer(0.1, false, function()
                                        pcall(function()
                                            if slua.isValid(curWeapon) and slua.isValid(curWeapon.GrenadeAvatarComponent_BP) then
                                                curWeapon.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false)
                                            end
                                        end)
                                    end)
                                end
                            end
                        end
                    end
                end
            end)
            return true
        end

        -- Simplified: only hook TryGetGrenadeAvatarID (lightweight), 
        -- skip per-grenade-class GetAvatarID hooks (heavy, fire for all players)
        local function hookGrenadeAvatarLookup()
            pcall(function()
                local AvatarDataUtil = require("GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil")
                if AvatarDataUtil and not AvatarDataUtil._lava_hooked_try_get then
                    AvatarDataUtil._lava_hooked_try_get = true
                    local origTry = AvatarDataUtil.TryGetGrenadeAvatarID
                    if origTry then
                        AvatarDataUtil.TryGetGrenadeAvatarID = function(uPlayerController, ItemID)
                            local cch = cache()
                            if cch.throwObjects then
                                if ItemID == 602001 and cch.throwObjects[614] and cch.throwObjects[614].resID and cch.throwObjects[614].resID > 0 then
                                    return cch.throwObjects[614].resID
                                elseif ItemID == 602002 and cch.throwObjects[613] and cch.throwObjects[613].resID and cch.throwObjects[613].resID > 0 then
                                    return cch.throwObjects[613].resID
                                elseif ItemID == 602003 and cch.throwObjects[615] and cch.throwObjects[615].resID and cch.throwObjects[615].resID > 0 then
                                    return cch.throwObjects[615].resID
                                elseif ItemID == 602004 and cch.throwObjects[612] and cch.throwObjects[612].resID and cch.throwObjects[612].resID > 0 then
                                    return cch.throwObjects[612].resID
                                end
                            end
                            return origTry(uPlayerController, ItemID)
                        end
                    end
                end
            end)
            -- Per-class GetAvatarID hooks removed (heavy, fire for all player grenades)
            -- Timer-based applyGrenadeSkinsToController handles periodic application
        end

        local GRENADE_ITEMID_TO_SUB = {
            [602001] = 614,
            [602002] = 613,
            [602003] = 615,
            [602004] = 612,
        }

        -- Lightweight version: only hooks UpdateGrenadeAvatar for local grenades
        -- Timer-based applyGrenadeSkinsToController handles periodic application
        local function hookProjectileGrenadeAvatar()
            pcall(function()
                local ProjectileBase = require("GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.ProjectileBase")
                local impl = ProjectileBase and ProjectileBase.__inner_impl
                if not impl or impl._lava_hooked_proj then return end
                impl._lava_hooked_proj = true
                local origUpdate = impl.UpdateGrenadeAvatar
                if origUpdate then
                    impl.UpdateGrenadeAvatar = function(self)
                        -- Only process local player grenades
                        if self.bAuthority then return origUpdate(self) end
                        local cch = cache()
                        if cch.throwObjects and slua.isValid(self.GrenadeAvatarComponent_BP) then
                            local itemID
                            if self.GetItemTypeID then
                                itemID = tonumber(self:GetItemTypeID())
                            elseif self.ItemDefineID then
                                itemID = tonumber(self.ItemDefineID.TypeSpecificID)
                            end
                            local sub = itemID and GRENADE_ITEMID_TO_SUB[itemID]
                            local info = sub and cch.throwObjects[sub]
                            if info and info.resID and info.resID > 0 then
                                pcall(function()
                                    self.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false)
                                end)
                                return
                            end
                        end
                        return origUpdate(self)
                    end
                end
                -- Skip BeginInitialize and ResetGrenadeAvatar hooks (they fire for every player's grenades)
                -- Timer-based applyGrenadeSkinsToController will re-apply periodically
            end)
        end

        local function applyMatchWeaponSkinsToController()
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local skinList = {}
            for _, w in pairs(cache().weapons) do
                if w.resID and w.resID > 0 then skinList[#skinList + 1] = w.resID end
            end
            if #skinList == 0 then return false end
            local ok = false
            pcall(function()
                local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
                CommerAvatarDataUtil:InitWeaponSkinList(pc, skinList, nil, nil)
                if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end
                if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end
                ok = true
            end)
            if ok then notify("سلاح PC: " .. table.concat(skinList, ",")) end
            return ok
        end

        local _weaponTypeIDCache = {}
        local function resolveWeaponTypeID(weaponResID)
            weaponResID = tonumber(weaponResID) or 0
            if weaponResID <= 0 then return 0 end
            if _weaponTypeIDCache[weaponResID] ~= nil then return _weaponTypeIDCache[weaponResID] end
            local found = 0
            pcall(function()
                local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
                if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
            end)
            if found > 0 then _weaponTypeIDCache[weaponResID] = found; return found end
            pcall(function()
                local ic = CDataTable.GetTableData("Item", weaponResID)
                if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
            end)
            local result = found > 0 and found or weaponResID
            _weaponTypeIDCache[weaponResID] = result
            return result
        end

        local _lastBuildSkinMappings = 0
        local function buildSkinMappings()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastBuildSkinMappings) < 0.5 then return end  -- throttle: max twice per second
            _lastBuildSkinMappings = now
            syncWeaponCacheFromLobby()
            local m = _G.AddOutfitSkinIdMappings
            for k in pairs(m) do m[k] = nil end
            for wid, w in pairs(cache().weapons) do
                wid = tonumber(wid)
                if wid and w.resID and w.resID > 0 then m[wid] = { tonumber(w.resID) } end
            end
            if MATCH_CONFIG.weaponSkins then
                for weaponKey, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
                    weaponKey, skinRes = tonumber(weaponKey), tonumber(skinRes)
                    if weaponKey and skinRes and skinRes > 0 and not m[weaponKey] then
                        m[weaponKey] = { skinRes }
                    end
                end
            end
        end

        local _skinIdCache = {}
        local _skinIdCacheTick = 0
        local function get_skin_id(currentGunId, maxIt)
            currentGunId, maxIt = tonumber(currentGunId) or 0, tonumber(maxIt) or 0
            if currentGunId <= 0 and maxIt <= 0 then return 0 end
            -- Fast path: prefer using weapon cache directly
            local cch = cache()
            local wid = maxIt > 0 and maxIt or currentGunId
            local w = cch.weapons[wid]
            if w and w.resID and w.resID > 0 then return w.resID end
            -- Try type ID lookup
            local typeId = resolveWeaponTypeID(wid)
            if typeId ~= wid then
                local w2 = cch.weapons[typeId]
                if w2 and w2.resID and w2.resID > 0 then return w2.resID end
            end
            -- Cache with short TTL
            local nowTick = _S.globalFrame or 0
            if (nowTick - _skinIdCacheTick) < 60 then
                local cached = _skinIdCache[wid]
                if cached then return cached end
            end
            buildSkinMappings()
            local m = _G.AddOutfitSkinIdMappings
            local result = nil
            if m[wid] and m[wid][1] then result = tonumber(m[wid][1])
            elseif typeId ~= wid and m[typeId] and m[typeId][1] then result = tonumber(m[typeId][1])
            end
            if result then
                _skinIdCache[wid] = result
                _skinIdCacheTick = nowTick
                return result
            end
            return wid
        end
        _G.get_skin_id = get_skin_id
        _G.skinIdMappings = _G.AddOutfitSkinIdMappings

        -- ========== Attachment Skin System (ported from C++ DumpSkin) ==========
        -- Builds weapon-skin -> attachment-skin maps from ItemUpgradeConfig and
        -- ItemUpgradeUnLockConfig, then applies the correct attachment skins
        -- (scopes, compensators, magazines, grips, stocks) when a weapon skin
        -- is active, so each skin carries its own dedicated attachments.

        local _attachMaps = nil

        local function _nameToString(name)
            if name == nil then return "" end
            if type(name) == "string" then return name end
            if type(name) == "userdata" then
                local s = nil
                pcall(function() if name.ToString then s = name:ToString() end end)
                if s and type(s) == "string" then return s end
                pcall(function() if name.ToWString then s = name:ToWString() end end)
                if s and type(s) == "string" then return s end
            end
            if type(name) == "table" and name.SourceString then
                return name.SourceString
            end
            return tostring(name)
        end

        local _WEAPON_CLASS_SUFFIXES = {
            { keywords = { "kar98", "awm", "m24", "amr", "mosin", "win94", "mk14" },
            suffixes = { "(Snipers)", "(Sniper Rifles)" } },
            { keywords = { "m249", "mg3", "dp-28", "dp28" },
            suffixes = { "(Machine Guns)" } },
            { keywords = { "ump", "p90", "vector", "bizon", "uzi", "thompson",
                        "mp5", "mp5k", "tommy" },
            suffixes = { "(SMG)", "(SMG, Pistols)", "(Rifles, SMG)" } },
            { keywords = { "p1911", "p92", "p18c", "deagle", "r1895", "r45",
                        "skorpion", "g18" },
            suffixes = { "(Pistols)", "(SMG, Pistols)" } },
            { keywords = { "akm", "m762", "scar", "famas", "m16a4", "aug",
                        "groza", "qbz", "m416", "mk47", "g36c", "ace32",
                        "k2", "m4" },
            suffixes = { "(AR)", "(Rifles, SMG)" } },
        }

        local function _classSuffixesFromSkinName(skinName)
            if type(skinName) ~= "string" or skinName == "" then return {} end
            local low = string.lower(skinName)
            for _, entry in ipairs(_WEAPON_CLASS_SUFFIXES) do
                for _, kw in ipairs(entry.keywords) do
                    if string.find(low, kw, 1, true) then return entry.suffixes end
                end
            end
            return {}
        end

        local function buildAttachmentMaps()
            if _attachMaps then return _attachMaps end
            _attachMaps = {
                skinAttachments  = {},  -- weaponSkinId -> { partSkinId1, partSkinId2, ... }
                skinBases        = {},  -- weaponSkinId -> { baseId1, baseId2, ... }
                attachToSkin     = {},  -- partSkinId   -> { weaponSkinId, baseId }
                skinToBaseWeapon = {},  -- weaponSkinId -> baseWeaponID
            }
            if not CDataTable or not CDataTable.GetTable then return _attachMaps end

            -- 1) GroupID -> [PartIds] from ItemUpgradeUnLockConfig
            local groupToParts = {}
            pcall(function()
                local unlockTbl = CDataTable.GetTable("ItemUpgradeUnLockConfig")
                if not unlockTbl then return end
                for _, row in pairs(unlockTbl) do
                    local gid  = tonumber(row.GroupID)
                    local part = tonumber(row.PartId or row.PartID)
                    if gid and part then
                        if not groupToParts[gid] then groupToParts[gid] = {} end
                        groupToParts[gid][#groupToParts[gid] + 1] = part
                    end
                end
            end)

            -- 2) weaponSkinId -> GroupID + skinToBaseWeapon from ItemUpgradeConfig
            local skinToGroup = {}
            pcall(function()
                local upTbl = CDataTable.GetTable("ItemUpgradeConfig")
                if not upTbl then return end
                for _, row in pairs(upTbl) do
                    local gid = tonumber(row.GroupID)
                    local itm = tonumber(row.ItemID)
                    if gid and itm and itm >= 1000000000 then
                        skinToGroup[itm] = gid
                        local baseWeaponID = math.floor(itm / 1000) % 1000000
                        if baseWeaponID >= 100000 and baseWeaponID <= 999999 then
                            _attachMaps.skinToBaseWeapon[itm] = baseWeaponID
                        end
                    end
                end
            end)

            -- 3) Base name -> [ids] index from Item table (vanilla attachments only)
            local baseNameToIds = {}
            local itemTbl = CDataTable.GetTable("Item")
            if itemTbl then
                for k, row in pairs(itemTbl) do
                    local id = tonumber(k) or tonumber(row and row.ItemID)
                    if id and id >= 1000 and id < 10000000 then
                        local nm = row and row.ItemName
                        if type(nm) ~= "string" then nm = _nameToString(nm) end
                        if type(nm) == "string" and nm ~= "" then
                            if not baseNameToIds[nm] then baseNameToIds[nm] = {} end
                            baseNameToIds[nm][#baseNameToIds[nm] + 1] = id
                        end
                    end
                end
            end

            -- 4) For each weapon skin, resolve its attachments' base IDs
            for weaponSkinId, gid in pairs(skinToGroup) do
                local parts = groupToParts[gid]
                if parts and #parts > 0 then
                    local bases = {}
                    local wc = cfg(weaponSkinId)
                    local weaponSkinName = ""
                    if wc then
                        local nm = wc.ItemName
                        if type(nm) ~= "string" then nm = _nameToString(nm) end
                        weaponSkinName = nm or ""
                    end
                    local suffixes = _classSuffixesFromSkinName(weaponSkinName)

                    for _, partId in ipairs(parts) do
                        local baseId = 0
                        local partRow = nil
                        if itemTbl then
                            partRow = itemTbl[partId] or itemTbl[tostring(partId)]
                        end
                        if not partRow and CDataTable.GetTableData then
                            partRow = CDataTable.GetTableData("Item", partId)
                        end
                        if partRow then
                            local nm = partRow.ItemName
                            if type(nm) ~= "string" then nm = _nameToString(nm) end
                            if type(nm) == "string" and nm ~= "" then
                                local list = baseNameToIds[nm]
                                if type(list) == "table" and #list >= 1 then
                                    baseId = list[1]
                                    for _, v in ipairs(list) do
                                        if v < baseId then baseId = v end
                                    end
                                end
                                if baseId == 0 then
                                    for _, suf in ipairs(suffixes) do
                                        local trial = nm .. " " .. suf
                                        local lst = baseNameToIds[trial]
                                        if type(lst) == "table" and #lst >= 1 then
                                            baseId = lst[1]
                                            for _, v in ipairs(lst) do
                                                if v < baseId then baseId = v end
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        bases[#bases + 1] = baseId
                        _attachMaps.attachToSkin[partId] = { weaponSkinId, baseId }
                    end
                    _attachMaps.skinAttachments[weaponSkinId] = parts
                    _attachMaps.skinBases[weaponSkinId] = bases
                end
            end

            local nSkins, nAttach = 0, 0
            for _ in pairs(_attachMaps.skinAttachments) do nSkins = nSkins + 1 end
            for _ in pairs(_attachMaps.attachToSkin) do nAttach = nAttach + 1 end
            log("Attachment maps: " .. nSkins .. " skins, " .. nAttach .. " attachments")

            return _attachMaps
        end

        local function applyAttachmentSkins(AttachmentArray, selectedSkinID)
            if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end
            selectedSkinID = tonumber(selectedSkinID) or 0
            if selectedSkinID == 0 then return false end

            local maps = buildAttachmentMaps()
            local attachments = maps.skinAttachments[selectedSkinID]
            local bases = maps.skinBases[selectedSkinID]

            local numSlots = 0
            pcall(function() numSlots = AttachmentArray:Num() end)
            if numSlots <= 0 then return false end

            local changed = false

            -- If selected skin has no attachments in the map, revert any
            -- part-skins found on attachment slots back to their base IDs.
            if not attachments or #attachments == 0 then
                for slotIdx = 0, numSlots - 1 do
                    if slotIdx ~= _K.GUN_MASTER_SYN_SLOT then
                        local slotData = AttachmentArray:Get(slotIdx)
                        if slotData then
                            local curID = 0
                            pcall(function()
                                curID = slua.IndexReference(slotData, "defineID").TypeSpecificID or 0
                            end)
                            curID = tonumber(curID) or 0
                            if curID > 0 then
                                local rIt = maps.attachToSkin[curID]
                                if rIt then
                                    local baseId = rIt[2]
                                    if baseId ~= 0 and baseId ~= curID then
                                        pcall(function()
                                            local defRef = slua.IndexReference(slotData, "defineID")
                                            defRef.TypeSpecificID = baseId
                                            slotData.operationType = 0
                                            AttachmentArray:Set(slotIdx, slotData)
                                        end)
                                        changed = true
                                    end
                                end
                            end
                        end
                    end
                end
                return changed
            end

            -- Build a set of valid attachment skin IDs for this weapon skin
            local validSkinIds = {}
            for _, id in ipairs(attachments) do
                validSkinIds[tonumber(id) or 0] = true
            end

            -- Normal case: for each attachment slot, find the matching
            -- attachment skin by baseId and swap to the selected skin's version.
            for slotIdx = 0, numSlots - 1 do
                if slotIdx ~= _K.GUN_MASTER_SYN_SLOT then
                    local slotData = AttachmentArray:Get(slotIdx)
                    if slotData then
                        local curID = 0
                        pcall(function()
                            curID = slua.IndexReference(slotData, "defineID").TypeSpecificID or 0
                        end)
                        curID = tonumber(curID) or 0
                        if curID > 0 then
                            -- Protection: if current attachment is already the correct skin, skip
                            if validSkinIds[curID] then
                                -- Already the correct skinned attachment, don't change
                            else
                                local baseId = 0
                                local rIt = maps.attachToSkin[curID]
                                if rIt then
                                    baseId = rIt[2]
                                elseif curID < 10000000 then
                                    baseId = curID
                                else
                                    -- Unknown skinned attachment from different skin, skip
                                    baseId = 0
                                end
                                if baseId ~= 0 then
                                    local srcIdx = 0
                                    for k, b in ipairs(bases) do
                                        if b ~= 0 and b == baseId then
                                            local candidate = tonumber(attachments[k]) or 0
                                            if candidate ~= 0 and candidate ~= curID then
                                                srcIdx = k
                                                break
                                            end
                                        end
                                    end
                                    if srcIdx > 0 and srcIdx <= #attachments then
                                        local newID = tonumber(attachments[srcIdx]) or 0
                                        if newID ~= 0 and newID ~= curID then
                                            pcall(function()
                                                local defRef = slua.IndexReference(slotData, "defineID")
                                                defRef.TypeSpecificID = newID
                                                slotData.operationType = 0
                                                AttachmentArray:Set(slotIdx, slotData)
                                            end)
                                            changed = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return changed
        end

        local function applySkinToWeaponRef(CurWeapon)
            if not slua.isValid(CurWeapon) then return false end
            local AttachmentArray = CurWeapon.synData
            if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end

            -- slot 7 فقط = بتاع السكن. باقي الـ slots فيها القطع (attachments)
            -- تعديل أي slot تاني بيخلي السلاح يعمل reload وتختفي القطع
            local AttachmentData = AttachmentArray:Get(_K.GUN_MASTER_SYN_SLOT)
            if not AttachmentData then return false end

            local current_gunid = 0
            pcall(function()
                current_gunid = slua.IndexReference(AttachmentData, "defineID").TypeSpecificID or 0
            end)
            current_gunid = tonumber(current_gunid) or 0
            if current_gunid <= 0 then return false end

            local MaxIt = 0
            pcall(function()
                if CurWeapon.GetWeaponID then MaxIt = CurWeapon:GetWeaponID() end
                if MaxIt <= 0 then MaxIt = CurWeapon:GetItemDefineID().TypeSpecificID end
            end)
            MaxIt = tonumber(MaxIt) or 0
            if MaxIt <= 0 then return false end

            local tmp_id = get_skin_id(current_gunid, MaxIt)
            tmp_id = tonumber(tmp_id) or 0
            if tmp_id <= 0 then return false end

            -- فحص الحالة الفعلية: لو السكن الحالي مطابق للمطلوب، لا شيء
            -- هذا يمنع التكرار بدون استخدام guard معتمد على حالة مخزنة
            if tmp_id == current_gunid and not isInjectedRes(tmp_id) then
                local ok, attChanged = pcall(applyAttachmentSkins, AttachmentArray, tmp_id)
                if ok and attChanged then
                    pcall(function()
                        local char = getLocalChar()
                        if char and char.AddGameTimer then
                            for _, delay in ipairs({0.3, 0.6, 1.0}) do
                                char:AddGameTimer(delay, false, function()
                                    if slua.isValid(CurWeapon) then
                                        local aa = CurWeapon.synData
                                        if aa and slua.isValid(aa) then
                                            pcall(applyAttachmentSkins, aa, tmp_id)
                                        end
                                    end
                                end)
                            end
                        end
                    end)
                end
                return false
            end
            if tmp_id == _S.lastAppliedSkinID and MaxIt == _S.lastAppliedWeaponID then
                local ok, attChanged = pcall(applyAttachmentSkins, AttachmentArray, tmp_id)
                if ok and attChanged then
                    pcall(function()
                        local char = getLocalChar()
                        if char and char.AddGameTimer then
                            for _, delay in ipairs({0.3, 0.6, 1.0}) do
                                char:AddGameTimer(delay, false, function()
                                    if slua.isValid(CurWeapon) then
                                        local aa = CurWeapon.synData
                                        if aa and slua.isValid(aa) then
                                            pcall(applyAttachmentSkins, aa, tmp_id)
                                        end
                                    end
                                end)
                            end
                        end
                    end)
                end
                return true
            end

            _G.AddOutfitLastAppliedSkin[current_gunid] = tmp_id
            pcall(function()
                local defRef = slua.IndexReference(AttachmentData, "defineID")
                defRef.TypeSpecificID = tmp_id
                local c0 = cfg(tmp_id)
                if c0 and c0.ItemType and defRef.Type ~= nil then defRef.Type = c0.ItemType end
                AttachmentData.operationType = 0
                AttachmentArray:Set(_K.GUN_MASTER_SYN_SLOT, AttachmentData)
            end)
            pcall(applyAttachmentSkins, AttachmentArray, tmp_id)
            if CurWeapon.DelayHandleAvatarMeshChanged then CurWeapon:DelayHandleAvatarMeshChanged() end
            -- Delayed re-application of attachment skins to ensure attachments
            -- are updated after the weapon finishes loading its default attachments.
            -- This fixes the issue where attachments don't update until you swap them.
            pcall(function()
                local char = getLocalChar()
                if char and char.AddGameTimer then
                    for _, delay in ipairs({0.3, 0.6, 1.0}) do
                        char:AddGameTimer(delay, false, function()
                            if slua.isValid(CurWeapon) then
                                local aa = CurWeapon.synData
                                if aa and slua.isValid(aa) then
                                    pcall(applyAttachmentSkins, aa, tmp_id)
                                end
                            end
                        end)
                    end
                end
            end)
            _S.weaponHookGuardUntil = _S.globalFrame + 45
            _G.AddOutfitLastAppliedSkin[MaxIt] = tmp_id
            _S.lastAppliedWeaponID = MaxIt
            _S.lastAppliedSkinID = tmp_id
            return true
        end

        function _G.equip_weapon_avatar(uCharacter)
            if not uCharacter or not slua.isValid(uCharacter) then return false end
            buildSkinMappings()
            local WeaponManager = uCharacter:GetWeaponManager()
            if not WeaponManager or not slua.isValid(WeaponManager) then return false end
            local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
            if not uWeaponList or not slua.isValid(uWeaponList) then return false end
            local appliedAny = false
            for i = 0, uWeaponList:Num() - 1 do
                local CurWeapon = uWeaponList:Get(i)
                if slua.isValid(CurWeapon) and applySkinToWeaponRef(CurWeapon) then
                    appliedAny = true
                end
            end
            return appliedAny
        end

        local function getDesiredWeaponSkins()
            syncWeaponCacheFromLobby()
            local out, seen = {}, {}
            local function add(res)
                res = tonumber(res)
                if res and res > 0 and not seen[res] then seen[res] = true; out[#out + 1] = res end
            end
            for _, w in pairs(cache().weapons) do add(w.resID) end
            if MATCH_CONFIG.weaponSkins then
                for _, res in pairs(MATCH_CONFIG.weaponSkins) do add(res) end
            end
            return out
        end

        local function registerWeaponAvatarItems(char)
            local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
            if not slua.isValid(pc) then return false end
            local BU = import("BackpackUtils")
            local AU = import("AvatarUtils")
            local addedCount = 0
            for _, resID in ipairs(getDesiredWeaponSkins()) do
                local doneDirect = false
                pcall(function()
                    if pc.AddWeaponAvatarItem then
                        pc:AddWeaponAvatarItem(tonumber(resID))
                        doneDirect = true
                        addedCount = addedCount + 1
                    end
                end)
                if not doneDirect then
                    pcall(function()
                        local skinBPID = BU.GetBPIDByResID(tonumber(resID))
                        local arr = slua.Array(UEnums.EPropertyClass.Int)
                        local parents = AU.GetWeaponAvatarParentIDList(skinBPID, arr, false)
                        if parents and parents.Num and parents:Num() > 0 and pc.WeaponAvatarItemList then
                            for _, parentID in pairs(parents) do
                                pc.WeaponAvatarItemList:Add(parentID, skinBPID)
                            end
                            addedCount = addedCount + 1
                        end
                    end)
                end
            end
            if addedCount == 0 then return false end
            pcall(function() if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end end)
            pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
            notify("سجّلت " .. addedCount .. " سكن سلاح")
            return true
        end

        local _lastMatchApplyWeapon = 0
        local function matchApplyWeaponSkin(char)
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastMatchApplyWeapon) < 0.4 then return false end  -- throttle: max 2.5x/sec
            _lastMatchApplyWeapon = now
            buildSkinMappings()
            applyMatchWeaponSkinsToController()
            if not _S.avatarItemsRegistered then
                _S.avatarItemsRegistered = registerWeaponAvatarItems(char)
            end
            local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
            if not slua.isValid(curWeapon) then
                return _G.equip_weapon_avatar(char)
            end

            local curWeaponResID = 0
            pcall(function() curWeaponResID = curWeapon:GetItemDefineID().TypeSpecificID end)
            local desiredSkin = get_skin_id(curWeaponResID, curWeaponResID)
            if curWeaponResID == _S.lastAppliedWeaponID and desiredSkin == _S.lastAppliedSkinID then
                pcall(_G.equip_weapon_avatar, char)
                return true
            end

            local ok = applySkinToWeaponRef(curWeapon)
            ok = _G.equip_weapon_avatar(char) or ok
            if ok then
                _S.lastAppliedWeaponID = curWeaponResID
                _S.lastAppliedSkinID = desiredSkin
                _S.weaponApplied = true
                _S.weaponDiagDone = true
                notify("سكن سلاح مطبق: " .. tostring(desiredSkin))
            end
            return ok
        end

        local function applyMatchThrowObjects()
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local cch = cache()
            if not cch.throwObjects then
                log("applyMatchThrowObjects: no throwObjects in cache")
                return false
            end
            local hasThrow = false
            for st, info in pairs(cch.throwObjects) do
                if info.resID and info.resID > 0 then hasThrow = true end
            end
            if not hasThrow then
                log("applyMatchThrowObjects: throwObjects cache empty")
                return false
            end
            local applied = false
            pcall(function()
                -- Try setting InitialConsumableAvatar fields (works if Lua table reference)
                if pc.InitialConsumableAvatar then
                    for st, info in pairs(cch.throwObjects) do
                        local key = _K.THROW_AVATAR_KEY[_K.THROW_SUB[st]]
                        if key and info.resID and info.resID > 0 then
                            pc.InitialConsumableAvatar[key] = info.resID
                            -- log suppressed
                        end
                    end
                end
                -- Rebuild grenade avatar list from InitialConsumableAvatar
                if pc.InitGrenadeAvatarList then
                    pc:InitGrenadeAvatarList(false)
                end
                -- Fallback: directly add to GrenadeAvatarItemList (overwrites server entries)
                if pc.AddToGrenadeAvatarItemList then
                    for st, info in pairs(cch.throwObjects) do
                        if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                            pc:AddToGrenadeAvatarItemList(info.resID)
                            applied = true
                        end
                    end
                end
            end)
            return applied
        end

        local function matchApplyAll(char)
            local ok = false
            if not _S.matchOutfitDone then
                _S.matchOutfitDone = matchApplyOutfit(char)
                ok = _S.matchOutfitDone or ok
            end
            if applyMatchEquipAvatarToController() then ok = true end
            if matchApplyEquipSkins(char) then ok = true; _S.matchApplied = true end
            if matchApplyWeaponSkin(char) then ok = true end
            if applyMatchThrowObjects() then ok = true end
            return ok
        end

        -- تعديل startMatchWatcher لاستخدام محاولات محدودة
        local function startMatchWatcher(char)
            if _S.matchTimer then return end
            _S.matchOutfitDone = false
            _S.avatarItemsRegistered = false
            _S.weaponApplied = false
            _S.weaponDiagDone = false
            _S.lastAppliedWeaponID = 0
            _S.lastAppliedSkinID = 0

            local attempts = 0
            notify("بدأ المراقب في الماتش")

            _S.matchTimer = char:AddGameTimer(1.0, true, function()
                attempts = attempts + 1
                local cur = getLocalChar()
                if not cur or not slua.isValid(cur) then return end
                pcall(matchApplyAll, cur)
                if (_S.matchOutfitDone and _S.weaponApplied) or attempts >= 8 then
                    pcall(function() if cur.RemoveGameTimer then cur:RemoveGameTimer(_S.matchTimer) end end)
                    _S.matchTimer = nil
                    log("توقف مؤقت الماتش بعد التطبيق الكامل")
                end
            end)
        end

        -- ========== حقن سكنات الأسلحة في واجهة الشنطة داخل الجيم ==========
        -- بدل تعديل AdditionalData (اللي مش بيتعدل من Lua)، بنعمل hook على
        -- GetWeaponAvatarRes اللي بترجع السكن للـ backpack UI
        local _hookedGetWeaponAvatarRes = false

        local function hookBackpackWeaponAvatarRes()
            if _hookedGetWeaponAvatarRes then return end
            _hookedGetWeaponAvatarRes = true
            pcall(function()
                local BPL = require("GameLua.Mod.BaseMod.Client.Backpack.BackPackFunctionLibrary")
                if BPL and BPL.GetWeaponAvatarRes and not BPL._lava_hooked_avatar_res then
                    BPL._lava_hooked_avatar_res = true
                    local _bpAvatarResCache = {}
                    local _bpAvatarResTicks = {}
                    local _bpResCacheAge = 0
                    local origGetRes = BPL.GetWeaponAvatarRes
                    BPL.GetWeaponAvatarRes = function(WeaponID, AdditionalDataArray)
                        WeaponID = tonumber(WeaponID) or 0
                        if WeaponID <= 0 then return origGetRes(WeaponID, AdditionalDataArray) end
                        -- Cache with invalidation every ~5 seconds via frame count
                        local cached = _bpAvatarResCache[WeaponID]
                        local age = _bpResCacheAge
                        local nowTick = _S.globalFrame or 0
                        if cached and (nowTick - (_bpAvatarResTicks[WeaponID] or 0)) < 150 then
                            return cached, ""
                        end
                        local targetSkinID = 0
                        -- 1) map directly from cache weapons
                        local cch = cache()
                        local typeId = resolveWeaponTypeID(WeaponID)
                        local w = cch.weapons[typeId] or cch.weapons[WeaponID]
                        if w and w.resID and w.resID > 0 then
                            targetSkinID = w.resID
                        end
                        -- 2) fallback to get_skin_id
                        if targetSkinID <= 0 or targetSkinID == WeaponID then
                            local sid = get_skin_id(WeaponID, WeaponID)
                            targetSkinID = tonumber(sid) or 0
                        end
                        -- Cache result
                        if targetSkinID > 0 and targetSkinID ~= WeaponID then
                            _bpAvatarResCache[WeaponID] = targetSkinID
                            _bpAvatarResTicks[WeaponID] = nowTick
                            local skinCfg = cfg(targetSkinID)
                            if skinCfg then
                                return targetSkinID, ""
                            end
                        end
                        _bpAvatarResCache[WeaponID] = WeaponID
                        _bpAvatarResTicks[WeaponID] = nowTick
                        return origGetRes(WeaponID, AdditionalDataArray)
                    end
                    log("[AddOutfit] hookBackpackWeaponAvatarRes: تم")
                end
            end)
        end

        -- ========== تطبيق سكن السيارة داخل الجيم ==========
        -- مكافئ Lua لكود C++ الذي يطبق سكن السيارة عند ركوب نوع السيارة المطابق
        local _lastVehicleSkinKey = ""

        local function applyVehicleSkinInGame()
            local char = getLocalChar()
            if not char or not slua.isValid(char) then return end

            local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
            if not vehicle or not slua.isValid(vehicle) then
                _lastVehicleSkinKey = ""
                _G.CurrentEquipVehicleID = nil
                return
            end
            pcall(syncVehicleAvatarSkinList)

            local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
            if not avatarComp or not slua.isValid(avatarComp) then return end

            local defaultAvatarID = avatarComp.GetDefaultAvatarID and avatarComp:GetDefaultAvatarID()
            if not defaultAvatarID or defaultAvatarID == 0 then return end

            local currentAvatarID = avatarComp.GetCurrentAvatarID and avatarComp:GetCurrentAvatarID()

            -- تجنب إعادة التطبيق على نفس السيارة بنفس السكن
            local cacheKey = tostring(vehicle) .. "_" .. tostring(defaultAvatarID) .. "_" .. tostring(currentAvatarID)
            if cacheKey == _lastVehicleSkinKey then return end

            -- الحصول على itemSubType للسيارة الحالية من جدول Item
            local vehicleSubType = 0
            local defaultItemCfg = cfg(defaultAvatarID)
            if defaultItemCfg then
                vehicleSubType = tonumber(defaultItemCfg.ItemSubType or defaultItemCfg.itemSubType) or 0
            end

            -- جمع السكنات المطلوبة من VehicleSlotList
            local desiredSkins = {}
            local firstSkinResID = 0
            if vehicleSubType > 0 and DataMgr and DataMgr.VehicleSlotList then
                local slotList = DataMgr.VehicleSlotList[vehicleSubType]
                if slotList then
                    for i = 1, #slotList do
                        local skinInsID = tonumber(slotList[i])
                        if skinInsID and skinInsID > 0 then
                            local skinResID = 0
                            if isInjectedIns(skinInsID) then
                                skinResID = R.insToRes[skinInsID] or 0
                            else
                                pcall(function()
                                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                    local d = wd:GetHallDepotItemDataByInsID(skinInsID)
                                    skinResID = d and tonumber(d.resID) or 0
                                end)
                            end
                            if skinResID > 0 then
                                desiredSkins[skinResID] = true
                                if firstSkinResID == 0 then
                                    firstSkinResID = skinResID
                                end
                            end
                        end
                    end
                end
            end

            -- Fallback: إضافة السكنات من vst_in_battle من PlayerState
            if vehicleSubType > 0 then
                pcall(function()
                    local pc = getPlayerController()
                    if pc and pc.PlayerState then
                        local vst = pc.PlayerState.vst_in_battle
                        if vst and vst[vehicleSubType] then
                            local resList = vst[vehicleSubType]
                            if resList and type(resList) == "table" then
                                for _, resID in ipairs(resList) do
                                    resID = tonumber(resID)
                                    if resID and resID > 0 then
                                        if not desiredSkins[resID] then
                                            desiredSkins[resID] = true
                                            if firstSkinResID == 0 then
                                                firstSkinResID = resID
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end

            -- Fallback: مطابقة بناءً على بادئة الـ ID
            if firstSkinResID == 0 and DataMgr and DataMgr.VehicleSlotList then
                local defStr = tostring(defaultAvatarID)
                for subType, insList in pairs(DataMgr.VehicleSlotList) do
                    if insList and type(insList) == "table" then
                        for i = 1, #insList do
                            local skinInsID = tonumber(insList[i])
                            if skinInsID and skinInsID > 0 then
                                local rid = 0
                                if isInjectedIns(skinInsID) then
                                    rid = R.insToRes[skinInsID] or 0
                                else
                                    pcall(function()
                                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                        local d = wd:GetHallDepotItemDataByInsID(skinInsID)
                                        rid = d and tonumber(d.resID) or 0
                                    end)
                                end
                                if rid > 0 then
                                    local skinCfg = cfg(rid)
                                    if skinCfg then
                                        local skinDefault = skinCfg.DefaultAvatarID or skinCfg.defaultAvatarID
                                        if skinDefault and tostring(skinDefault):find(defStr, 1, true) then
                                            if not desiredSkins[rid] then
                                                desiredSkins[rid] = true
                                                firstSkinResID = rid
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        if firstSkinResID > 0 then break end
                    end
                end
            end

            -- إذا السكن الحالي من السكنات المختارة في السلوتات، لا نفرض تغييره
            if currentAvatarID and desiredSkins[currentAvatarID] then
                _lastVehicleSkinKey = cacheKey
                return
            end

            local skinResID = firstSkinResID

            if skinResID == 0 then
                _lastVehicleSkinKey = cacheKey
                _G.CurrentEquipVehicleID = nil
                return
            end
            _G.CurrentEquipVehicleID = skinResID


            -- تطبيق السكن على السيارة
            pcall(function()
                local pc = getPlayerController()
                if pc and avatarComp.SetVehicleNetAvatarData then
                    avatarComp:SetVehicleNetAvatarData(pc)
                end
                -- تعيين إفكت التبديل (مثل SwitchEffectId = 7303001 في C++)
                if avatarComp.VehicleNetAvatarData then
                    avatarComp.VehicleNetAvatarData.SwitchEffectId = 7303001
                    avatarComp.VehicleNetAvatarData.UpdateFlag = 1
                end
                avatarComp:ChangeItemAvatar(skinResID, true)
                avatarComp.CanChangeAvatar = true
            end)

            -- تشغيل إضاءة LED تحت السيارة (Chassis Light) عند تطبيق السكن
            pcall(applyVehicleChassisLight)

            _lastVehicleSkinKey = cacheKey
        end

        -- ========== إضاءة تحت السيارة (Chassis Light) في الجيم ==========
        local _LAVA_CHASSIS_LIGHT_ID = 7302002

        local function isLocalPlayerVehicle(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return false end
            local char = getLocalChar()
            if not char or not slua.isValid(char) then return false end
            local currentVehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
            if currentVehicle and currentVehicle == vehicle then return true end
            local driver = nil
            pcall(function() driver = vehicle.GetDriver and vehicle:GetDriver() end)
            if driver and driver == char then return true end
            return false
        end

        local function getVehicleSkinID(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return 0 end
            local skinID = 0
            pcall(function()
                if vehicle.GetVehicleSkinItemID then
                    skinID = vehicle:GetVehicleSkinItemID() or 0
                end
            end)
            if skinID and skinID > 0 then return skinID end
            pcall(function()
                if vehicle.ClientUsedAvatarID then
                    skinID = vehicle.ClientUsedAvatarID
                end
            end)
            if skinID and skinID > 0 then return skinID end
            pcall(function()
                local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                if avatarComp and slua.isValid(avatarComp) and avatarComp.GetCurrentAvatarID then
                    skinID = avatarComp:GetCurrentAvatarID() or 0
                end
            end)
            return skinID or 0
        end

        local function vehicleHasSkinApplied(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return false end
            local skinID = getVehicleSkinID(vehicle)
            if skinID <= 0 then return false end
            local defaultID = 0
            pcall(function()
                local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                if avatarComp and slua.isValid(avatarComp) and avatarComp.GetDefaultAvatarID then
                    defaultID = avatarComp:GetDefaultAvatarID() or 0
                end
            end)
            return skinID ~= defaultID
        end

        local function forceVehicleChassisLight(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return end
            local licenseComp = vehicle.GetLicenseComponent and vehicle:GetLicenseComponent()
            if not licenseComp or not slua.isValid(licenseComp) then
                print("[AddOutfit] forceVehicleChassisLight: no licenseComp")
                return
            end
            if not licenseComp.LicensePlate then
                print("[AddOutfit] forceVehicleChassisLight: no LicensePlate")
                return
            end
            if licenseComp.LicensePlate.ChassisLightId == _LAVA_CHASSIS_LIGHT_ID and slua.isValid(licenseComp.ChassisLightMesh) then
                return
            end
            local skinID = getVehicleSkinID(vehicle)
            if skinID > 0 then
                licenseComp.LicensePlate.ItemID = skinID
            end
            licenseComp.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
            if licenseComp.curVehicleAvatarId == nil or licenseComp.curVehicleAvatarId == 0 then
                licenseComp.curVehicleAvatarId = skinID
            end
            print("[AddOutfit] forceVehicleChassisLight: skinID=" .. tostring(skinID) .. " ChassisLightId=" .. tostring(_LAVA_CHASSIS_LIGHT_ID) .. " ItemID=" .. tostring(licenseComp.LicensePlate.ItemID))
            if licenseComp.PreChangeChassisLight then
                pcall(function() licenseComp:PreChangeChassisLight() end)
            end
        end

        local function applyVehicleChassisLight()
            local char = getLocalChar()
            if not char or not slua.isValid(char) then return end
            local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
            if not vehicle or not slua.isValid(vehicle) then return end
            if not isLocalPlayerVehicle(vehicle) then return end
            if not vehicleHasSkinApplied(vehicle) then return end
            forceVehicleChassisLight(vehicle)
        end

        local function hookVehicleLicenseComponentBase()
            local ok, VLB = pcall(require, "GameLua.Activity.Commercialize.Actor.ActorComponent.BP_VehicleLicenseComponentBase")
            if not ok or not VLB then return end
            local impl = VLB.__inner_impl
            if not impl or type(impl) ~= "table" then return end
            if impl._lava_hooked_chassis then return end
            impl._lava_hooked_chassis = true

            local origCheckDownloaded = impl.CheckHasVehicleDownloaded
            impl.CheckHasVehicleDownloaded = function(self, ItemID)
                local vehicle = self:GetOwner()
                if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                    return true
                end
                return origCheckDownloaded(self, ItemID)
            end

            local origPreChange = impl.PreChangeChassisLight
            impl.PreChangeChassisLight = function(self)
                pcall(function()
                    local vehicle = self:GetOwner()
                    if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                        if self.LicensePlate then
                            local skinID = getVehicleSkinID(vehicle)
                            if skinID > 0 then
                                self.LicensePlate.ItemID = skinID
                            end
                            self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                        end
                    end
                end)
                return origPreChange(self)
            end

            local origAsyncLoad = impl.AsyncLoadAccessoryItemHandle
            if origAsyncLoad then
                impl.AsyncLoadAccessoryItemHandle = function(self, itemId, bCheckDownload)
                    if itemId == _LAVA_CHASSIS_LIGHT_ID then
                        bCheckDownload = false
                    end
                    return origAsyncLoad(self, itemId, bCheckDownload)
                end
            end

            local origAsyncLoadHandle = impl._AsyncLoadHandle
            if origAsyncLoadHandle then
                impl._AsyncLoadHandle = function(self, ItemID)
                    if ItemID == _LAVA_CHASSIS_LIGHT_ID then
                        pcall(function()
                            local UBackpackUtils = import("BackpackUtils")
                            local handlePath = self:GetAccessoryAvatarHandlePath(ItemID)
                            local itemCfg = CDataTable.GetTableData("Item", ItemID)
                            if handlePath and itemCfg and itemCfg.BPID then
                                local bpCfg = CDataTable.GetTableData("AvatarBPTable", itemCfg.BPID)
                                if bpCfg and bpCfg.AvatarBPPath and bpCfg.AvatarBPPath ~= "" then
                                    self:AsyncLoadAsset(handlePath, self.OnAccHandleLoaded, self, ItemID, itemCfg.BPID)
                                    return
                                end
                            end
                            print("[AddOutfit] _AsyncLoadHandle bypass failed for chassis light, trying direct load")
                        end)
                    end
                    return origAsyncLoadHandle(self, ItemID)
                end
            end

            local origOnRep = impl.OnRep_LicensePlate
            if origOnRep then
                impl.OnRep_LicensePlate = function(self)
                    local bReapply = false
                    pcall(function()
                        local vehicle = self:GetOwner()
                        if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                            bReapply = true
                            if self.LicensePlate then
                                local skinID = getVehicleSkinID(vehicle)
                                if skinID > 0 then
                                    self.LicensePlate.ItemID = skinID
                                end
                                self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                            end
                        end
                    end)
                    local result = origOnRep(self)
                    if bReapply then
                        pcall(function()
                            if self.LicensePlate then
                                local skinID = getVehicleSkinID(self:GetOwner())
                                if skinID > 0 then
                                    self.LicensePlate.ItemID = skinID
                                end
                                self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                            end
                            if self.PreChangeChassisLight then
                                self:PreChangeChassisLight()
                            end
                        end)
                    end
                    return result
                end
            end

            local origOnVehicleMesh = impl.OnVehicleMeshAvatarEquiped
            if origOnVehicleMesh then
                impl.OnVehicleMeshAvatarEquiped = function(self, expectItemId)
                    local result = origOnVehicleMesh(self, expectItemId)
                    pcall(function()
                        local vehicle = self:GetOwner()
                        if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                            if self.LicensePlate then
                                local skinID = getVehicleSkinID(vehicle)
                                if skinID > 0 then
                                    self.LicensePlate.ItemID = skinID
                                end
                                self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                            end
                            if self.PreChangeChassisLight then
                                self:PreChangeChassisLight()
                            end
                        end
                    end)
                    return result
                end
            end

            print("[AddOutfit] VehicleLicenseComponentBase chassis hook installed")
        end

        local function hookVehiclePlateLicenseUtil()
            local ok, VPLU = pcall(require, "GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            if not ok or not VPLU then return end
            if VPLU._lava_hooked_chassis then return end
            VPLU._lava_hooked_chassis = true
            local origGetLoc = VPLU.GetChassisLightLocAndScale
            VPLU.GetChassisLightLocAndScale = function(vehicleId, bIsLobbyVehicle)
                local loc, scale = origGetLoc(vehicleId, bIsLobbyVehicle)
                if loc and scale then
                    return loc, scale
                end
                local defaultLoc = FVector(0, -20, 10)
                local defaultScale = FVector(6.5, 7, 1)
                print("[AddOutfit] GetChassisLightLocAndScale fallback defaults for vehicleId:" .. tostring(vehicleId))
                return defaultLoc, defaultScale
            end
            print("[AddOutfit] VehiclePlateLicenseUtil chassis hook installed")
        end

        local function hookServerChangeVehicleAvatar(pc)
            if not pc or not slua.isValid(pc) then return end
            if pc._lava_hooked_server_vehicle_skin then return end
            if not pc.ServerChangeVehicleAvatar then return end
            pc._lava_hooked_server_vehicle_skin = true
            local orig = pc.ServerChangeVehicleAvatar
            local hooked = function(self, resID)
                pcall(function()
                    local char = self:GetPlayerCharacterSafety()
                    if char and slua.isValid(char) then
                        local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
                        if vehicle and slua.isValid(vehicle) then
                            local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                            if avatarComp and slua.isValid(avatarComp) then
                                if avatarComp.SetVehicleNetAvatarData then
                                    avatarComp:SetVehicleNetAvatarData(self)
                                end
                                if avatarComp.VehicleNetAvatarData then
                                    avatarComp.VehicleNetAvatarData.SwitchEffectId = 7303001
                                    avatarComp.VehicleNetAvatarData.UpdateFlag = 1
                                end
                                avatarComp:ChangeItemAvatar(resID, true)
                                avatarComp.CanChangeAvatar = true
                                _lastVehicleSkinKey = ""
                                _G.CurrentEquipVehicleID = resID
                                print("[AddOutfit] Vehicle skin changed locally to " .. tostring(resID))
                                pcall(applyVehicleChassisLight)
                            end
                        end
                    end
                end)
            end
            pcall(function() rawset(pc, "ServerChangeVehicleAvatar", hooked) end)
        end

        local _lava_skin_click_handler
        local function getSkinClickHandler()
            if _lava_skin_click_handler then return _lava_skin_click_handler end
            _lava_skin_click_handler = function(self)
                if self.resID > 0 then
                    local UsingID = self:GetLoopScrollBoxParentUI():GetCurUsingSkinID()
                    if self.resID ~= UsingID then
                        pcall(function()
                            local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                            local PlayerController = GameplayData.GetPlayerController()
                            if not slua.isValid(PlayerController) then return end
                            local char = PlayerController:GetPlayerCharacterSafety()
                            if not char or not slua.isValid(char) then return end
                            local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
                            if not vehicle or not slua.isValid(vehicle) then return end
                            local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                            if not avatarComp or not slua.isValid(avatarComp) then return end
                            if avatarComp.SetVehicleNetAvatarData then
                                avatarComp:SetVehicleNetAvatarData(PlayerController)
                            end
                            if avatarComp.VehicleNetAvatarData then
                                avatarComp.VehicleNetAvatarData.SwitchEffectId = 7303001
                                avatarComp.VehicleNetAvatarData.UpdateFlag = 1
                            end
                            avatarComp:ChangeItemAvatar(self.resID, true)
                            avatarComp.CanChangeAvatar = true
                            _lastVehicleSkinKey = ""
                            _G.CurrentEquipVehicleID = self.resID
                            print("[AddOutfit] VehicleSkinItem applied skin locally " .. tostring(self.resID))
                            pcall(applyVehicleChassisLight)
                        end)
                    end
                end
                if EventSystem and EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                    EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
                end
            end
            return _lava_skin_click_handler
        end

        local function hookVehicleSkinItem()
            local ok, VSI = pcall(require, "GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
            if not ok or not VSI then return end
            -- VSI هو class table اللي ليه __newindex = error، لازم نعدل على __inner_impl
            local impl = VSI.__inner_impl
            if not impl or type(impl) ~= "table" then return end
            if impl._lava_hooked_skin_item then return end
            impl._lava_hooked_skin_item = true
            local handler = getSkinClickHandler()
            local origRegist = impl.RegistEvents
            impl.RegistEvents = function(self)
                rawset(self, "OnClickSkinButton", handler)
                return origRegist(self)
            end
            local origOnRefresh = impl.OnRefresh
            impl.OnRefresh = function(self, resID, selectIndex)
                local cur = rawget(self, "OnClickSkinButton")
                if cur ~= handler then
                    rawset(self, "OnClickSkinButton", handler)
                    pcall(function()
                        if self.UnRegistEvents and self.RegistEvents then
                            self:UnRegistEvents()
                            self:RegistEvents()
                        end
                    end)
                end
                return origOnRefresh(self, resID, selectIndex)
            end
            impl.OnClickSkinButton = handler
        end

        local function hookVehicleSkinAndMusicPanel()
            local ok, VSP = pcall(require, "GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
            if not ok or not VSP then return end
            local impl = VSP.__inner_impl
            if not impl or type(impl) ~= "table" then return end
            if impl._lava_hooked_panel then return end
            impl._lava_hooked_panel = true
            local orig = impl.InitSkinList
            impl.InitSkinList = function(self)
                hookVehicleSkinItem()
                return orig(self)
            end
        end

        local function syncVehicleAvatarSkinList()
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return end
            hookServerChangeVehicleAvatar(pc)
            hookVehicleSkinItem()
            hookVehicleSkinAndMusicPanel()
            hookVehicleLicenseComponentBase()
            hookVehiclePlateLicenseUtil()
            if pc.bEnableFuzzyAvatarOnClient then
                pc.bEnableFuzzyAvatarOnClient = false
            end
            if not DataMgr or not DataMgr.VehicleSlotList then return end
            if not pc.InitVehicleAvatarSkinList then return end
            local vehicleSkinData = {}
            for subType, insList in pairs(DataMgr.VehicleSlotList) do
                if insList and type(insList) == "table" then
                    local itemArray = {}
                    for _, insID in ipairs(insList) do
                        insID = tonumber(insID)
                        if insID and insID > 0 then
                            local skinResID = 0
                            if isInjectedIns(insID) then
                                skinResID = R.insToRes[insID] or 0
                            else
                                pcall(function()
                                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                    local d = wd:GetHallDepotItemDataByInsID(insID)
                                    skinResID = d and tonumber(d.resID) or 0
                                end)
                            end
                            if skinResID and skinResID > 0 then
                                table.insert(itemArray, {ItemTableID = skinResID, Count = 1})
                            end
                        end
                    end
                    if #itemArray > 0 then
                        table.insert(vehicleSkinData, {Items = itemArray})
                    end
                end
            end
            if #vehicleSkinData > 0 then
                pc.InitialVehicleAvatarSkinList = vehicleSkinData
                pc:InitVehicleAvatarSkinList()
            end
        end

        local function stopMatchWatcher()
            if _S.matchTimer then
                pcall(function()
                    local char = getLocalChar()
                    if char and char.RemoveGameTimer then char:RemoveGameTimer(_S.matchTimer) end
                end)
                _S.matchTimer = nil
            end
            _S.matchOutfitDone = false
            _S.avatarItemsRegistered = false
            _S.weaponApplied = false
            _S.weaponDiagDone = false
            _S.lastAppliedWeaponID = 0
            _S.lastAppliedSkinID = 0
            _S.matchApplied = false
            _S.bootstrapped = false   -- إعادة ضبط bootstrap
        end

        local function bootstrapMatch(char)
            if _S.bootstrapped then return true end
            char = char or getLocalChar()
            if not char or not slua.isValid(char) then return false end
            snapshotLobbyWear()
            _S.weaponApplied = false
            _S.weaponDiagDone = false
            _S.matchOutfitDone = false
            if not _S.bootstrapNotified then
                _S.bootstrapNotified = true
                notify("اكتشفت شخصيتك في الماتش")
            end
            startMatchWatcher(char)
            hookPlayerWearingDone()
            matchApplyAll(char)
            _S.bootstrapped = true
            return true
        end

        local function isSelfAvatarComp(self)
            if not self or not self.IsSelf then return true end
            local ok, r = pcall(function() return self:IsSelf() end)
            return ok and r == true
        end

        local function hookMatchAvatar()
            if _G._lava_hooked_match_avatar then return end
            _G._lava_hooked_match_avatar = true
            pcall(function()
                if EventSystem and EventSystem.registEvent
                    and EVENTTYPE_PLAYEREVENT_AVATAR and EVENTID_LOCAL_PLAYEREVENT_AVATAR_ALL_MESH_LOADED then
                    EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_AVATAR, EVENTID_LOCAL_PLAYEREVENT_AVATAR_ALL_MESH_LOADED, function()
                        if isInLobby() then return end
                        local char = getLocalChar()
                        if char then
                            hookPlayerWearingDone()
                            applyMatchEquipAvatarToController()
                            matchApplyEquipSkins(char)
                        end
                    end)
                end
            end)
            pcall(function()
                local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
                if not CAC._lava_hooked_mesh then
                    CAC._lava_hooked_mesh = true
                    local o = CAC.OnAvatarAllMeshLoadedLua
                    CAC.OnAvatarAllMeshLoadedLua = function(self)
                        o(self)
                        pcall(function()
                            if self.IsLobbyActor and self:IsLobbyActor() then return end
                            if not (self.IsSelf and self:IsSelf()) then return end
                            local char = getLocalChar()
                            if char and char.AddGameTimer then
                                char:AddGameTimer(0.5, false, function() bootstrapMatch(char) end)
                            end
                        end)
                    end
                end
            end)
            pcall(function()
                local WAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.WeaponAvatarComponent")
                local oLoad = WAC.OnWeaponAvatarLoadedLua
                WAC.OnWeaponAvatarLoadedLua = function(self, slotID, definedID)
                    oLoad(self, slotID, definedID)
                    pcall(function()
                        if self.IsLobbyActor and self:IsLobbyActor() then return end
                        if not isSelfAvatarComp(self) then return end
                        if _S.globalFrame < _S.weaponHookGuardUntil then return end
                        local char = getLocalChar()
                        if not char then return end
                        bootstrapMatch(char)
                        _S.weaponApplied = false
                        if char.AddGameTimer then
                            char:AddGameTimer(0.2, false, function()
                                local c = getLocalChar()
                                if c then matchApplyWeaponSkin(c) end
                            end)
                            -- Extra delayed pass for attachment skins
                            char:AddGameTimer(0.5, false, function()
                                local c = getLocalChar()
                                if c then matchApplyWeaponSkin(c) end
                            end)
                        end
                    end)
                end
            end)
        end

        local function onWeaponLuaInit(_, _, weapon)
            if not weapon or not slua.isValid(weapon) then return end
            local char = getLocalChar()
            if not char then return end
            local owner = nil
            pcall(function() if weapon.GetOwnerPawn then owner = weapon:GetOwnerPawn() end end)
            if not slua.isValid(owner) or owner ~= char then return end
            if _S.globalFrame < _S.weaponHookGuardUntil then return end
            pcall(function()
                char:AddGameTimer(0.15, false, function()
                    if slua.isValid(weapon) then
                        applySkinToWeaponRef(weapon)
                        _S.weaponApplied = false
                    end
                end)
                -- Extra delayed pass for attachment skins
                char:AddGameTimer(0.5, false, function()
                    if slua.isValid(weapon) then
                        applySkinToWeaponRef(weapon)
                    end
                end)
            end)
        end

        local function hookWeaponSpawn()
            if _S.weaponSpawnHooked then return end
            pcall(function()
                if EventSystem and EventSystem.registEvent
                    and EVENTTYPE_PLAYEREVENT_WEAPON and EVENTID_PLAYEREVENT_WEAPON_LUA_INIT then
                    EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_LUA_INIT, onWeaponLuaInit)
                    _S.weaponSpawnHooked = true
                end
            end)
        end

        local function hookLobbyWeaponCache()
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                local oRsp = Arm.install_weapon_skin_rsp
                Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
                    oRsp(client_data, errorCode, weapon_id, instanceID)
                    if errorCode == 0 or errorCode == _K.NET_OK then
                        cacheWeaponSkinFromIns(weapon_id, instanceID)
                    end
                end
            end)
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local o = wl.on_puton_rsp
                wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
                    o(self, res, item, olditem, index, extra)
                    if item and item.instid and (res == 0 or res == _K.NET_OK) then
                        local resID, insID = tonumber(item.res_id), tonumber(item.instid)
                        local slot = getEquipSkinSlot(resID)
                        if isInjectedIns(insID) and slot and not _S.equipSkinApplying then
                            saveEquipSkin(resID, insID)
                            if slot ~= "parachute" and slot ~= "glider" then
                                applyEquipVisual(resID, insID, slot)
                            end
                        elseif isInjectedIns(insID) then
                            local mt = wardrobeMainTab(resID)
                            if mt ~= _K.WARDROBE_PAGE_VEHICLE then
                                if isThrowObjectRes(resID) then
                                    saveThrowObject(resID, insID)
                                else
                                    saveEquip(resID, insID)
                                end
                            end
                        end
                    end
                end
            end)
        end

        -- هوك تبويب الأسلحة المُحسَّن (يمنع الإجبار)
        local function hookGunWardrobe()
            pcall(function()
                local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                if wgl._lava_gun_hooked then return end
                wgl._lava_gun_hooked = true

                local origSetGunID = wgl.SetGunID
                wgl.SetGunID = function(self, weaponID, ...)
                    weaponID = tonumber(weaponID)
                    if not weaponID then return origSetGunID(self, weaponID, ...) end

                    local w = cache().weapons[weaponID]
                    local injected = w and w.insID and w.insID > 0 and isInjectedIns(w.insID)
                    -- تحقق مما إذا كان السكن الحالي مطابقاً للمطلوب
                    local currentSkin = wgl.GetCurrentEquippedSkinInsID and wgl:GetCurrentEquippedSkinInsID(weaponID) or 0
                    if injected and currentSkin == w.insID then
                        -- السكن مطبق بالفعل، لا تفعل شيئاً
                        return origSetGunID(self, weaponID, ...)
                    end

                    if injected then
                        pcall(function()
                            local Arm = require("client.logic.armory.logic_armory")
                            Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
                            Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
                            Arm.rsp_list.install_list[weaponID] = { skin_id = w.insID }
                            
                            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                            if fbd.UpdateCurrentFashionBagWeaponSkin then
                                fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, w.insID)
                            end
                            if fbd.SetFashionBagWeaponSkin then
                                fbd:SetFashionBagWeaponSkin(weaponID, w.insID)
                            end
                        end)
                    else
                        -- إذا لم يكن هناك سكن محقون، تأكد من مسح أي سكن مثبت
                        pcall(function()
                            local Arm = require("client.logic.armory.logic_armory")
                            if Arm.rsp_list and Arm.rsp_list.install_list then
                                Arm.rsp_list.install_list[weaponID] = nil
                            end
                            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                            if fbd.UpdateCurrentFashionBagWeaponSkin then
                                fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, 0)
                            end
                            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                            if bag and bag.weapon_skin_list then
                                bag.weapon_skin_list[weaponID] = nil
                            end
                        end)
                    end

                    local result = origSetGunID(self, weaponID, ...)

                    if injected then
                        later(0.05, function()
                            pcall(function()
                                local wgl2 = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                                wgl2:UpdateCurrentGunAvatar(weaponID, w.insID)
                                
                                if EventSystem then
                                    if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                                        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, w.resID)
                                    end
                                    if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_GUN_LIST then
                                        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
                                    end
                                    if EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
                                        EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, w.resID)
                                    end
                                end
                            end)
                        end)
                        -- log("إعادة تطبيق سكن بعد تبديل سلاح", weaponID, w.resID)
                    else
                        -- تحديث الواجهة لإزالة السكن
                        later(0.05, function()
                            pcall(function()
                                local wgl2 = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                                wgl2:UpdateCurrentGunAvatar(weaponID, 0)
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, 0)
                                end
                                if EventSystem and EVENTID_WARDROBE_UPDATE_GUN_LIST then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, weaponID)
                                end
                            end)
                        end)
                        log("إزالة سكن السلاح", weaponID)
                    end
                    
                    return result
                end

                local origUpdateGunAvatar = wgl.UpdateCurrentGunAvatar
                wgl.UpdateCurrentGunAvatar = function(self, weaponID, insID, ...)
                    weaponID = tonumber(weaponID)
                    insID = tonumber(insID)
                    if weaponID and (not insID or insID <= 0) then
                        local w = cache().weapons[weaponID]
                        if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                            insID = w.insID
                            log("UpdateCurrentGunAvatar: استخدام سكن محفوظ", weaponID, insID)
                        else
                            insID = 0
                        end
                    end
                    return origUpdateGunAvatar(self, weaponID, insID, ...)
                end

                if wgl.GetCurrentEquippedSkinInsID then
                    local origGetCurSkin = wgl.GetCurrentEquippedSkinInsID
                    wgl.GetCurrentEquippedSkinInsID = function(self, weaponID, ...)
                        weaponID = tonumber(weaponID)
                        if weaponID then
                            local w = cache().weapons[weaponID]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return w.insID
                            end
                        end
                        return origGetCurSkin(self, weaponID, ...)
                    end
                end

                if wgl.GetGunSkinInsID then
                    local origGetGunSkin = wgl.GetGunSkinInsID
                    wgl.GetGunSkinInsID = function(self, weaponID, ...)
                        weaponID = tonumber(weaponID)
                        if weaponID then
                            local w = cache().weapons[weaponID]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return w.insID
                            end
                        end
                        return origGetGunSkin(self, weaponID, ...)
                    end
                end

                log("hookGunWardrobe: تم")
            end)
        end

        -- ========== Collection Ace Eliminator Broadcast (619150001) ==========
        local ELIMINATION_KING_EFFECT_ID = 619150001

        -- ========== Last Strike Champion Final Kill Effect (61950002) ==========
        local FINAL_KILL_EFFECT_ID = 61950002

        local function getLocalPlayerKey()
            local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if ok and GD and GD.GetPlayerState then
                local ps = GD.GetPlayerState()
                if ps and slua.isValid(ps) and ps.PlayerKey then
                    return tonumber(ps.PlayerKey)
                end
            end
            return nil
        end

        local function getLocalUID()
            local uid
            pcall(function()
                local Subsystem = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
                local AccountSubsystem = Subsystem:Get("AccountSubsystem")
                if AccountSubsystem and AccountSubsystem.GetAccountUID then
                    uid = AccountSubsystem:GetAccountUID()
                end
            end)
            if not uid then
                pcall(function()
                    local GD = require("GameLua.GameCore.Data.GameplayData")
                    local ps = GD.GetPlayerState()
                    if ps and slua.isValid(ps) and ps.UID then
                        uid = tonumber(ps.UID)
                    end
                end)
            end
            return uid
        end

        local function hookEliminationKingEffect()
            if _G._lava_hooked_elim_king then return end
            _G._lava_hooked_elim_king = true

            pcall(function()
                local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
                if CommerAvatarDataUtil._lava_hooked_ext_attr then return end
                CommerAvatarDataUtil._lava_hooked_ext_attr = true

                local ExtendAttribute = require("Server.config.ExtendAttribute")
                local origGetAttr = CommerAvatarDataUtil.GetPlayerExtendAttributeAndTest
                CommerAvatarDataUtil.GetPlayerExtendAttributeAndTest = function(self, UID, attr)
                    if attr == ExtendAttribute.EliminationKingEffect then
                        local localUID = getLocalUID()
                        if localUID and tonumber(UID) == tonumber(localUID) then
                            return ELIMINATION_KING_EFFECT_ID
                        end
                    end
                    return origGetAttr(self, UID, attr)
                end
                log("hookEliminationKingEffect: CommerAvatarDataUtil hooked")
            end)

            pcall(function()
                local KillInfoClass = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
                local impl = KillInfoClass.__inner_impl
                if not impl or impl._lava_hooked_show_king then return end
                impl._lava_hooked_show_king = true

                local origShow = impl.ShowKingEliminationInfo
                impl.ShowKingEliminationInfo = function(self, DamageRecordData)
                    local localKey = getLocalPlayerKey()
                    if localKey and DamageRecordData and DamageRecordData.ExpandDataContent then
                        pcall(function()
                            local FatalDamageInfo = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent)
                            if FatalDamageInfo and FatalDamageInfo.KingEliminationInfo then
                                local KingEliminationInfo = FatalDamageInfo.KingEliminationInfo
                                if KingEliminationInfo.NewKingEliminationInfo then
                                    local info = KingEliminationInfo.NewKingEliminationInfo
                                    if tonumber(info.PlayerKey) == localKey then
                                        info.EffectID = ELIMINATION_KING_EFFECT_ID
                                        log("hookEliminationKingEffect: injected EffectID into NewKingEliminationInfo")
                                    end
                                end
                                if KingEliminationInfo.DeadKingEliminationInfo then
                                    local info = KingEliminationInfo.DeadKingEliminationInfo
                                    if tonumber(info.KillerPlayerKey) == localKey then
                                        info.EffectID = ELIMINATION_KING_EFFECT_ID
                                        log("hookEliminationKingEffect: injected EffectID into DeadKingEliminationInfo")
                                    end
                                end
                            end
                        end)
                    end
                    return origShow(self, DamageRecordData)
                end
                log("hookEliminationKingEffect: KillInfo.ShowKingEliminationInfo hooked")
            end)

            pcall(function()
                local KingEliminationInfoItemClass = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KingEliminationInfoItem")
                local impl = KingEliminationInfoItemClass.__inner_impl
                if not impl or impl._lava_hooked_update then return end
                impl._lava_hooked_update = true

                local origUpdate = impl.UpdateKingEliminationInfo
                impl.UpdateKingEliminationInfo = function(self, DamageRecordData, KingEliminationInfo)
                    local localKey = getLocalPlayerKey()
                    if localKey and KingEliminationInfo then
                        if KingEliminationInfo.NewKingEliminationInfo then
                            local info = KingEliminationInfo.NewKingEliminationInfo
                            if tonumber(info.PlayerKey) == localKey then
                                info.EffectID = ELIMINATION_KING_EFFECT_ID
                            end
                        end
                        if KingEliminationInfo.DeadKingEliminationInfo then
                            local info = KingEliminationInfo.DeadKingEliminationInfo
                            if tonumber(info.KillerPlayerKey) == localKey then
                                info.EffectID = ELIMINATION_KING_EFFECT_ID
                            end
                        end
                    end
                    return origUpdate(self, DamageRecordData, KingEliminationInfo)
                end
                log("hookEliminationKingEffect: KingEliminationInfoItem hooked")
            end)

            pcall(function()
                local PlayerStateBaseClass = require("GameLua.GameCore.Framework.PlayerStateBase")
                local impl = PlayerStateBaseClass.__inner_impl
                if not impl or impl._lava_hooked_init_team then return end
                impl._lava_hooked_init_team = true

                local origInit = impl.InitTeamShowData
                impl.InitTeamShowData = function(self, ...)
                    origInit(self, ...)
                    pcall(function()
                        local localUID = getLocalUID()
                        if localUID and self.UID and tonumber(self.UID) == tonumber(localUID) then
                            self.EliminationKingEffectID = ELIMINATION_KING_EFFECT_ID
                        end
                    end)
                end
                log("hookEliminationKingEffect: PlayerStateBase hooked")
            end)
        end

        local function tickEliminationKingEffect()
            pcall(function()
                local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
                if ok and GD and GD.GetPlayerState then
                    local ps = GD.GetPlayerState()
                    if ps and slua.isValid(ps) then
                        if not ps.EliminationKingEffectID or ps.EliminationKingEffectID == 0 then
                            ps.EliminationKingEffectID = ELIMINATION_KING_EFFECT_ID
                        end
                    end
                end
            end)
        end

        -- ========== Last Strike Champion Final Kill Effect (61950002) ==========
        local function hookFinalKillEffect()
            if _G._lava_hooked_final_kill then return end
            _G._lava_hooked_final_kill = true

            -- 1. Hook FinalKillEffectLevelSequenceActor to handle missing config for 61950002
            -- If config doesn't exist or Sequence is empty, directly call OnPlay callback
            pcall(function()
                local LSActor = require("GameLua.Mod.Library.GamePlay.Actor.FinalKillEffectLevelSequenceActor")
                if LSActor._lava_hooked then return end
                LSActor._lava_hooked = true

                local origBeginPlay = LSActor.ReceiveBeginPlay
                if origBeginPlay then
                    LSActor.ReceiveBeginPlay = function(self)
                        if self.ItemId == FINAL_KILL_EFFECT_ID then
                            local Config = CDataTable.GetTableData("FinalKillEffectCfg", self.ItemId)
                            if not Config or not Config.Sequence or Config.Sequence == "" then
                                log("hookFinalKillEffect: no sequence for 61950002, calling OnPlay directly")
                                if self.Callback and self.Callback.OnPlay then
                                    self.Callback.OnPlay()
                                end
                                return
                            end
                        end
                        return origBeginPlay(self)
                    end
                    log("hookFinalKillEffect: FinalKillEffectLevelSequenceActor hooked")
                end
            end)

            -- 2. Hook TriggerParticleEffect to force ItemId = 61950002
            pcall(function()
                local Feature = require("GameLua.Mod.BaseMod.GamePlay.Feature.Player.PlayerCharacterFinalKillEffectFeature")
                if Feature._lava_hooked_fke then return end
                Feature._lava_hooked_fke = true

                local origTriggerParticle = Feature.TriggerParticleEffect
                if origTriggerParticle then
                    Feature.TriggerParticleEffect = function(self, ItemId, Location, Rotator, TeamMemberNames)
                        log("hookFinalKillEffect: TriggerParticleEffect called, ItemId=" .. tostring(ItemId) .. " forcing to " .. tostring(FINAL_KILL_EFFECT_ID))
                        return origTriggerParticle(self, FINAL_KILL_EFFECT_ID, Location, Rotator, TeamMemberNames)
                    end
                end

                local origPrepareItem = Feature.PrepareItem
                if origPrepareItem then
                    Feature.PrepareItem = function(self, ItemId)
                        log("hookFinalKillEffect: PrepareItem called, ItemId=" .. tostring(ItemId) .. " forcing to " .. tostring(FINAL_KILL_EFFECT_ID))
                        return origPrepareItem(self, FINAL_KILL_EFFECT_ID)
                    end
                end
                log("hookFinalKillEffect: PlayerCharacterFinalKillEffectFeature hooked")
            end)

            -- 3. Direct client-side trigger when game ends
            local function triggerFinalKillEffect()
                pcall(function()
                    local char = getLocalChar()
                    if not char or not slua.isValid(char) then
                        log("hookFinalKillEffect: char not valid")
                        return
                    end

                    if _G._lava_fke_triggered then return end
                    _G._lava_fke_triggered = true

                    char:EnsureDynamicFeature("FinalKillEffect")
                    if not char.FinalKillEffect then
                        log("hookFinalKillEffect: FinalKillEffect feature not available")
                        return
                    end

                    local Location = char:K2_GetActorLocation()
                    local Rotator = FRotator(0, 0, 0)
                    local Names = char.PlayerName or ""

                    log("hookFinalKillEffect: triggering effect 61950002")
                    char.FinalKillEffect:TriggerParticleEffect(FINAL_KILL_EFFECT_ID, Location, Rotator, Names)
                end)
            end

            -- 3a. Hook BattleResult.on_game_result (global function, client-side)
            pcall(function()
                if BattleResult and BattleResult.on_game_result and not BattleResult._lava_hooked_fke then
                    BattleResult._lava_hooked_fke = true
                    local origOnGameResult = BattleResult.on_game_result
                    BattleResult.on_game_result = function(battle_result, result)
                        log("hookFinalKillEffect: BattleResult.on_game_result triggered")
                        triggerFinalKillEffect()
                        return origOnGameResult(battle_result, result)
                    end
                    log("hookFinalKillEffect: BattleResult.on_game_result hooked")
                end
            end)

            -- 3b. Hook BattleResult.on_game_over (global function, client-side)
            pcall(function()
                if BattleResult and BattleResult.on_game_over and not BattleResult._lava_hooked_fke_over then
                    BattleResult._lava_hooked_fke_over = true
                    local origOnGameOver = BattleResult.on_game_over
                    BattleResult.on_game_over = function(game_id)
                        log("hookFinalKillEffect: BattleResult.on_game_over triggered")
                        triggerFinalKillEffect()
                        return origOnGameOver(game_id)
                    end
                    log("hookFinalKillEffect: BattleResult.on_game_over hooked")
                end
            end)

            -- 3c. Also register for the event as backup (with nil checks)
            pcall(function()
                if EventSystem and EventSystem.registEvent
                    and EVENTTYPE_STATE and EVENTID_GAMESTATE_ON_PRE_BATTLE_RESULT
                    and not _G._lava_fke_event_registered then
                    _G._lava_fke_event_registered = true
                    EventSystem:registEvent(EVENTTYPE_STATE, EVENTID_GAMESTATE_ON_PRE_BATTLE_RESULT, triggerFinalKillEffect)
                    log("hookFinalKillEffect: registered for EVENTID_GAMESTATE_ON_PRE_BATTLE_RESULT")
                end
            end)

            log("hookFinalKillEffect: done")
        end

        -- ========== تشغيل ==========
        -- ===================================================================
        -- SECURITY: ANTI-CHEAT BYPASS (from 2.lua Section 19)
        -- ===================================================================
        local function hookSecurityBypass()
            -- 1. Disable puffer download reporting
            pcall(function()
                local pufferTlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
                if pufferTlog then
                    pufferTlog.ReportEvent = function() end
                    pufferTlog.ReportDownloadResult = function() end
                    pufferTlog.ReportODPAKError = function() end
                end
            end)

            -- 2. Bypass AvatarUtils weapon blacklist
            pcall(function()
                local AvatarUtils = package.loaded["AvatarUtils"]
                if AvatarUtils then
                    AvatarUtils.CheckIsWeaponInBlackList = function() return false end
                    AvatarUtils.IsValidAvatar = function() return true end
                end
            end)

            -- 3. Disable file integrity checking
            pcall(function()
                local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
                if SubsystemMgr then
                    local FileCheckSubsystem = SubsystemMgr:Get("FileCheckSubsystem")
                    if FileCheckSubsystem then
                        FileCheckSubsystem.StartCheck = function() end
                        FileCheckSubsystem.ReportAbnormalFile = function() end
                    end
                end
            end)

            -- 4. Disable equipment exception reporting
            pcall(function()
                local equipReport = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
                if equipReport then
                    equipReport.Report = function() end
                end
            end)

            -- 5. Disable puffer download validation
            pcall(function()
                local pufferManager = require("client.slua.logic.download.puffer.puffer_manager")
                local pufferConst = require("client.slua.logic.download.puffer_const")
                if pufferManager and pufferConst then
                    local origCheck = pufferManager.CheckResourceValid
                    if origCheck then
                        pufferManager.CheckResourceValid = function(...) return true end
                    end
                end
            end)

            -- 6. Bypass avatar hash verification
            pcall(function()
                local AvatarUtils = package.loaded["AvatarUtils"]
                if AvatarUtils then
                    local origVerify = AvatarUtils.VerifyAvatarData
                    if origVerify then
                        AvatarUtils.VerifyAvatarData = function(...) return true end
                    end
                end
            end)

            print("[AddOutfit] Security bypass installed")
        end

        -- ===================================================================
        -- KILL MESSAGE SYSTEM (from 2.lua Section 17)
        -- Injects weapon skin + outfit skin + golden color into kill feed
        -- ===================================================================
        local _killCounterHooked = false
        local _safeRequireCache = {}
        local function safeRequire(name)
            if _safeRequireCache[name] then return _safeRequireCache[name] end
            local loaded = package.loaded[name]
            if loaded then _safeRequireCache[name] = loaded; return loaded end
            local ok, mod = pcall(require, name)
            if ok and mod then _safeRequireCache[name] = mod; return mod end
            return nil
        end

        _G.AKFakeKillCounts = _G.AKFakeKillCounts or setmetatable({}, { __index = function() return 0 end })

        local function pushKillCounterUpdate(weaponID, skinID, killCount)
            pcall(function()
                local UIManager = safeRequire("client.slua_ui_framework.manager")
                if not UIManager then return end
                local killCounterUI = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                if not killCounterUI or not killCounterUI.UpdateWeaponID then return end
                local avatarSkinID = skinID or weaponID
                killCounterUI:UpdateWeaponID(weaponID, avatarSkinID)
                local ModuleManager = safeRequire("client.module_framework.ModuleManager")
                if ModuleManager then
                    local kcLogic = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                    if kcLogic and kcLogic.GetEquipedKillCounterId then
                        local equippedKCId = kcLogic:GetEquipedKillCounterId(0, avatarSkinID)
                        if killCounterUI.SetKillCounterItemShowWithNum then
                            killCounterUI:SetKillCounterItemShowWithNum(equippedKCId, killCount, avatarSkinID)
                        end
                    end
                end
            end)
        end

        local function hookKillMessages()
            if _killCounterHooked then return end
            local anyHooked = false

            -- 1. Kill Counter UI hooks
            pcall(function()
                local KillCounterUI = safeRequire("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
                if KillCounterUI and KillCounterUI.__inner_impl then
                    local impl = KillCounterUI.__inner_impl
                    impl.CheckSupportKCUI = function() return true end
                    impl.CheckNeedMainKillCounterUI = function(self, weapon, PlayerID)
                        if slua.isValid(weapon) then
                            local weaponID = weapon:GetWeaponID()
                            local skinID = _G.get_skin_id and _G.get_skin_id(weaponID) or weaponID
                            self:UpdateMainKillCounterUI(true, weaponID, skinID)
                            pushKillCounterUpdate(weaponID, skinID, _G.AKFakeKillCounts[weaponID] or 0)
                        else
                            self:UpdateMainKillCounterUI(false)
                        end
                    end
                    local origUpdate = impl.UpdateMainKillCounterUI
                    impl.UpdateMainKillCounterUI = function(self, bShow, weaponID, AvatarID)
                        if bShow then
                            AvatarID = _G.get_skin_id and _G.get_skin_id(weaponID) or AvatarID
                        end
                        if origUpdate then origUpdate(self, bShow, weaponID, AvatarID) end
                        if bShow then
                            pushKillCounterUpdate(weaponID, AvatarID, _G.AKFakeKillCounts[weaponID] or 0)
                        end
                    end
                    anyHooked = true
                end
            end)

            -- 2. Kill Counter Logic hooks
            pcall(function()
                local ModuleManager = safeRequire("client.module_framework.ModuleManager")
                if ModuleManager then
                    local kcLogic = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                    if kcLogic then
                        kcLogic.CheckSupportKC = function() return true end
                        kcLogic.CheckSupportKillCounterAvatar = function() return true end
                        kcLogic.CheckHasWeaponKillCounter = function() return true end
                        kcLogic.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                        kcLogic.GetEquipedKillCounterId = function() return 2100004 end
                        kcLogic.GetMyEquipedKillCounterId = function() return 2100004 end
                        kcLogic.GetOneWeaponKillCountInBattle = function(self, uid, weaponId)
                            return _G.AKFakeKillCounts[weaponId] or 0
                        end
                        kcLogic.GetWeaponKillCountByUid = function(self, uid, weaponId)
                            return _G.AKFakeKillCounts[weaponId] or 0
                        end
                        anyHooked = true
                    end
                end
            end)

            -- 3. Kill Info Message hook (inject skin + color into kill feed)
            pcall(function()
                local KillInfo = safeRequire("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
                if KillInfo and KillInfo.__inner_impl then
                    local origFileItem = KillInfo.__inner_impl.FileItem
                    KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                        pcall(function()
                            local GD = safeRequire("GameLua.GameCore.Data.GameplayData")
                            if not GD then return end
                            local playerChar = GD.GetPlayerCharacter()
                            if not playerChar or not slua.isValid(playerChar) then return end
                            -- Only modify YOUR kill messages
                            if DamageRecordData.Causer ~= playerChar:GetPlayerNameSafety() then return end
                            local currentWeapon = playerChar:GetCurrentWeapon()
                            if not slua.isValid(currentWeapon) then return end
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id and _G.get_skin_id(weaponID) or weaponID
                            -- Inject weapon skin into kill message
                            if skinID then
                                DamageRecordData.CauserWeaponAvatarID = skinID
                            end
                            -- Inject outfit skin into kill message
                            if _G.SuitSkin and _G.SuitSkin ~= 0 then
                                DamageRecordData.CauserClothAvatarID = _G.SuitSkin
                            end
                            -- Golden name color
                            DamageRecordData.IsUseColor = true
                            DamageRecordData.UseColor = import("LinearColor")(1.0, 0.8, 0.0, 1.0)
                            -- Track kill count
                            if DamageRecordData.ResultHealthStatus == 2 then
                                _G.AKFakeKillCounts[weaponID] = (_G.AKFakeKillCounts[weaponID] or 0) + 1
                                pushKillCounterUpdate(weaponID, skinID, _G.AKFakeKillCounts[weaponID])
                            end
                        end)
                        if origFileItem then return origFileItem(self, DamageRecordData) end
                    end
                    anyHooked = true
                end
            end)

            -- 4. Weapon Slot Mode 2 - Kill Counter Icon
            pcall(function()
                local SlotMode2 = safeRequire("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
                if SlotMode2 and SlotMode2.__inner_impl then
                    local origCheck = SlotMode2.__inner_impl.CheckShowKCIcon
                    SlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                        if self.KillCounterImg and slua.isValid(self.KillCounterImg) then
                            self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible)
                        end
                        if origCheck then return origCheck(self) end
                    end
                    local origShow = SlotMode2.__inner_impl.ShowKCIcon
                    if origShow then
                        SlotMode2.__inner_impl.ShowKCIcon = function(self, weaponID, skinID)
                            local cnt = _G.AKFakeKillCounts[weaponID] or 0
                            if origShow then origShow(self, weaponID, skinID) end
                            if cnt > 0 then
                                pcall(function()
                                    if self.KillCounterImg and self.KillCounterImg.SetKillCount then
                                        self.KillCounterImg:SetKillCount(cnt)
                                    end
                                end)
                            end
                        end
                    end
                    anyHooked = true
                end
            end)

            if anyHooked then _killCounterHooked = true end
        end

        -- 5. Refresh kill counter for current weapon
        _G.RefreshKillCounterUI = function()
            pcall(function()
                local GD = safeRequire("GameLua.GameCore.Data.GameplayData")
                if not GD then return end
                local pc = GD.GetPlayerController()
                if not pc or not slua.isValid(pc) then return end
                local lp = pc:GetPlayerCharacterSafety()
                if not lp or not slua.isValid(lp) then return end
                local cw = lp:GetCurrentWeapon()
                if not slua.isValid(cw) then return end
                local wID = cw:GetWeaponID()
                if not wID or wID == 0 then return end
                local sid = _G.get_skin_id and _G.get_skin_id(wID)
                if not sid then
                    local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
                    if KCUI and KCUI.__inner_impl then
                        KCUI.__inner_impl:UpdateMainKillCounterUI(false)
                    end
                    return
                end
                local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
                if KCUI and KCUI.__inner_impl then
                    KCUI.__inner_impl:UpdateMainKillCounterUI(true, wID, sid)
                end
                pushKillCounterUpdate(wID, sid, _G.AKFakeKillCounts[wID] or 0)
            end)
        end

        _G.ForceEnableKillCounterUI = function()
            hookKillMessages()
            _G.RefreshKillCounterUI()
        end

        -- ===================================================================
        -- TEAM BROADCAST KILL MESSAGES (v1.1)
        -- Shows weapon skin / vehicle skin in team kill notifications
        -- ===================================================================
        local _teamBroadcastHooked = false
        local function hookTeamBroadcast()
            if _teamBroadcastHooked then return end
            pcall(function()
                local BattleKillBroadcastSubSystem = require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem")
                if not BattleKillBroadcastSubSystem then return end
                local O_CopyKillOrPutDownMessageDataUserDataToLuaTable = BattleKillBroadcastSubSystem.CopyKillOrPutDownMessageDataUserDataToLuaTable
                if not O_CopyKillOrPutDownMessageDataUserDataToLuaTable then return end
                BattleKillBroadcastSubSystem.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
                    local msgData = O_CopyKillOrPutDownMessageDataUserDataToLuaTable(self, messageData)
                    if not msgData or not msgData.bIamCauser then return msgData end
                    pcall(function()
                        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                        if not pc then return end
                        local uCharacter = pc:GetPlayerCharacterSafety()
                        if not uCharacter or not slua.isValid(uCharacter) then return end
                        if msgData.DamageType == UEnums.DamageType.VehicleDamage then
                            -- Vehicle kill: inject vehicle skin
                            local carSkinID = _G.CurrentEquipVehicleID
                            if carSkinID and carSkinID ~= 0 then
                                local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, msgData.ExpandDataContent) or {}
                                ExpandData.CauserVehicleSkinID = carSkinID
                                ExpandData.CauserWeaponAvatarID = carSkinID
                                msgData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        else
                            -- Weapon kill: inject weapon skin
                            local currWeapon = uCharacter:GetCurrentWeapon()
                            if currWeapon and slua.isValid(currWeapon) then
                                local synData = currWeapon.synData
                                if synData and slua.isValid(synData) then
                                    local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                    if weaponDefineID and slua.isValid(weaponDefineID) then
                                        local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, msgData.ExpandDataContent) or {}
                                        ExpandData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        msgData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                                    end
                                end
                            end
                        end
                    end)
                    return msgData
                end
                _teamBroadcastHooked = true
                print("[AddOutfit] Team broadcast kill messages hooked")
            end)
        end

        

                local function start()
            log("AddOutfit Merged start")
            -- Security bypass first
            pcall(hookSecurityBypass)
            -- Kill message system
            pcall(hookKillMessages)
            -- Team broadcast kill messages (v1.1)
            pcall(hookTeamBroadcast)
            buildSkinMappings()
            pcall(restorePersistedVehicles)
            pcall(restorePersistedMotions)
            pcall(restorePersistedEquipIns)
            pcall(restorePersistedThrowObjects)
            pcall(restorePersistedHallTheme)
            pcall(syncMatchConfigFromCache)
            hookCDataTableCache()
            hookDepotInit()
            hookWardrobeData()
            hookPageFilter()
            hookArmory()
            hookPutOn()
            hookLobbyTheme()
            hookMotionEquip()
            hookIngameEmote()
            hookFashionBag()
            hookBackpackValid()
            hookAvatarValid()
            hookEquipMapping()
            hookLobbyWeaponCache()
            hookGunWardrobe()
            hookLobbySwipePersistence()
            hookMatchAvatar()
            hookMatchAvatarData()
            hookGrenadeAvatarInit()
            hookGrenadeAvatarLookup()
            hookProjectileGrenadeAvatar()
            hookWeaponSpawn()
            hookVehicleLicenseComponentBase()
            hookVehiclePlateLicenseUtil()
            hookBackpackWeaponAvatarRes()
            hookEliminationKingEffect()
            hookFinalKillEffect()

            if injectAllSources() then
                refreshWardrobe()
                later(1.0, reapplyLobbyEquipped)
            else
                local tries = 0
                local function retry()
                    tries = tries + 1
                    if injectAllSources() then
                        refreshWardrobe()
                        later(1.0, reapplyLobbyEquipped)
                        return
                    end
                    if tries < 40 then later(1.5, retry) end
                end
                later(1.5, retry)
            end

            pcall(function()
                if isInGamePlay() then
                    local char = getLocalChar()
                    if char then bootstrapMatch(char) end
                elseif isInLobby() then
                    snapshotLobbyWear()
                end
            end)
        end

        hookBackpackValid()
        hookEquipMapping()
        hookMatchAvatar()
        hookMatchAvatarData()
        hookGrenadeAvatarInit()
        hookGrenadeAvatarLookup()
        hookProjectileGrenadeAvatar()
        hookWeaponSpawn()
        hookBackpackWeaponAvatarRes()
        hookEliminationKingEffect()
        hookFinalKillEffect()
        pcall(_loadEquippedCache)
        start()
        pcall(hookVehicleSkinAndMusicPanel)

        -- Time-based application loop (replaces frame-based tick listener)
        -- Uses os.clock() for time tracking instead of frame counting
        local _lastTickTime = os.clock()
        local _timeCount = 0
        
        -- Periodic application functions with different rates
        local function fastApplyLoop()
            pcall(function()
                _timeCount = _timeCount + 1
                _S.globalFrame = _timeCount
                -- Refresh kill counter UI periodically
                if _timeCount % 3 == 0 and _killCounterHooked then
                    pcall(function()
                        if _G.RefreshKillCounterUI then _G.RefreshKillCounterUI() end
                    end)
                end
                if isInLobby() then
                    if _timeCount % 10 == 0 then
                        pcall(snapshotLobbyWear)
                    end
                    pcall(ensureLobbyInjectedWear)
                    pcall(ensureWardrobeInjected)
                    if _timeCount % 5 == 0 then
                        pcall(_G.AddOutfitTryFlushSave)
                    end
                end
                if isInGamePlay() then
                    local char = getLocalChar()
                    local charValid = char and slua.isValid(char)
                    if not _S.matchTimer and charValid then
                        bootstrapMatch(char)
                    end
                    if _timeCount % 5 == 0 and charValid then
                        pcall(function()
                            local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
                            if slua.isValid(curWeapon) then
                                applySkinToWeaponRef(curWeapon)
                            end
                            equip_weapon_avatar(char)
                            matchApplyEquipSkins(char)
                            applyGrenadeSkinsToController()
                        end)
                    end
                    if _timeCount % 5 == 0 then
                        pcall(applyVehicleSkinInGame)
                    end
                end
            end)
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(1.0, fastApplyLoop)
            end
        end
        
        local function mediumLoop()
            pcall(function()
                -- Character boot check at medium rate
                if isInGamePlay() then
                    local char = getLocalChar()
                    if char and not _S.matchTimer then
                        bootstrapMatch(char)
                    end
                    pcall(tickEliminationKingEffect)
                    pcall(applyVehicleChassisLight)
                end
                if isInLobby() then
                    pcall(snapshotLobbyWear)
                end
            end)
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(2.5, mediumLoop)
            end
        end
        
        local function slowLoop()
            pcall(function()
                if isInGamePlay() then
                    pcall(syncVehicleAvatarSkinList)
                end
                pcall(_G.AddOutfitTryFlushSave)
            end)
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(5.0, slowLoop)
            end
        end
        
        -- Start all loops
        if _ticker and _ticker.AddTimerOnce then
            _ticker.AddTimerOnce(0.5, fastApplyLoop)
            _ticker.AddTimerOnce(1.0, mediumLoop)
            _ticker.AddTimerOnce(2.0, slowLoop)
        end

        -- Game status change detection via polling (cheaper than hooking events)
        local _lastGameStatus = ""
        local function statusPollLoop()
            local currentStatus = ""
            if isInLobby() then currentStatus = "lobby"
            elseif isInGamePlay() then currentStatus = "gameplay"
            else currentStatus = "other" end
            
            if currentStatus ~= _lastGameStatus then
                _lastGameStatus = currentStatus
                -- Status changed, run post-switch logic
                stopMatchWatcher()
                _S.bootstrapNotified = false
                _S.matchOutfitDone = false
                _S.lobbyApplied = false
                _G._lava_fke_triggered = nil
                pcall(function()
                    if isInLobby() then 
                        snapshotLobbyWear()
                        pcall(ensureWardrobeInjected)
                        later(2.0, reapplyLobbyEquipped)
                    end
                end)
                pcall(function()
                    if isInGamePlay() then
                        local char = getLocalChar()
                        if char then bootstrapMatch(char) end
                    end
                end)
                -- Chỉ force-save khi VÀO sảnh, tránh ghi đè file bằng dữ liệu match-state
                pcall(function()
                    if isInLobby() then _AutoSaveOutfit(true) end
                end)
            end
            
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(3.0, statusPollLoop)
            end
        end
        
        if _ticker and _ticker.AddTimerOnce then
            _ticker.AddTimerOnce(1.0, statusPollLoop)
        end


        end -- initHooks

        local function prewarmModules()
            local mods = {
                "client.logic.armory.logic_armory",
                "client.slua.logic.wardrobe.fashionbag.fashionbag_data",
                "client.logic.lobby.hall_theme_utils",
                "client.slua.logic.wardrobe.logic_wardrobe_gun",
                "client.slua.logic.wardrobe.wardrobe_data",
                "client.network.Protocol.WardRobeHandler",
                "client.slua.logic.wardrobe.logic_wardrobe_avatar",
                "client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils",
                "client.logic.data.AvatarData",
                "client.slua.logic.XSuit.logic_xsuit",
                "client.slua.logic.wardrobe.logic_wardrobe_new",
                "client.slua.logic.wardrobe.logic_display_setting",
                "client.logic.avatar.logic_team_avatar_manager",
                "client.slua.logic.wardrobe.logic_wardrobe_data_center",
                "client.slua.logic.wardrobe.WardrobeDataEntity",
                "client.slua.umg.Wardrobe.subtab_item_list_base",
                "client.slua.logic.wardrobe.tab_surveillance",
                "client.network.comm.NetManager",
                "client.slua.umg.Wardrobe.wardrobe_macro",
                "client.slua.logic.avatar.avatar_common",
                "client.slua.logic.lobby.Main.Lobby_Main_Control",
                "common.time_ticker",
                "GameLua.GameCore.Module.Subsystem.SubsystemMgr",
                "GameLua.Mod.BaseMod.GamePlay.Backpack.BackpackUtils",
                "GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil",
                "GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil",
            }
            for _, m in ipairs(mods) do
                pcall(require, m)
            end
        end

        prewarmModules()
        initHooks()

        log("AddOutfit Merged loaded")
        notify("السكربت جاهز")
        pcall(function() report("AddOutfit init DONE") end)
        pcall(function()
            report("savepath: " .. tostring(_getOutfitSavePath()))
        end)
        pcall(function()
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(0.5, function() pcall(_AutoSaveOutfit, true) end)
                _ticker.AddTimerOnce(2.0, function() pcall(_AutoSaveOutfit, true) end)
                _ticker.AddTimerOnce(5.0, function() pcall(_AutoSaveOutfit, true) end)
            end
        end)
    end)
    if not _ao_ok then
        print("[AddOutfit] LOAD ERROR:", tostring(_ao_err))
        pcall(function()
            local w = WriteReportToPaksFile or _G.WriteReportToPaksFile
            if w then
                w("[AddOutfit] LOAD ERROR: " .. tostring(_ao_err))
            end
        end)
    end
end -- END ADD OUTFIT
-- ====================================================
return true