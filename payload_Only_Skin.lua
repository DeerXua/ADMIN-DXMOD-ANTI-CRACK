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
    -- ÄÆ°á»ng dáº«n tÆ°Æ¡ng Ä‘á»‘i chuáº©n UE4 Lua Paks sandbox (giá»‘ng XFFWPaths trong BRPlayerCharacterBase)
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
    local myInfoStr = string.format("[ID GAME CHÃNH: %s | TÃŠN: %s]", mainGameID, mainPlayerName)
    DXFw("ðŸš¨ Bá»Š REPORT / INSPECTOR ðŸš¨ > Náº¡n nhÃ¢n: " .. myInfoStr .. " | Loáº¡i: " .. tostring(kind) .. " | Káº» tá»‘ cÃ¡o/Inspector: UID=" .. tostring(uid or "?") .. " Name=" .. tostring(name or "?") .. (extra and (" | " .. tostring(extra)) or "") .. " âš ï¸")
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
    
    -- 1. Æ¯u tiÃªn Ä‘á»c HWID gá»‘c chÆ°a bá»‹ Hook tá»« Orig_GetDeviceId náº¿u cÃ³
    if _G.DX and _G.DX.Team_Orig_GetDeviceId then
        pcall(function()
            local orig = _G.DX.Team_Orig_GetDeviceId()
            if orig and orig ~= "" and orig ~= "UNKNOWN" then hwid = tostring(orig) end
        end)
    end
    
    -- 2. Thá»­ Ä‘á»c tá»« KismetSystemLibrary.GetDeviceId
    if hwid == "UNKNOWN" then
        pcall(function()
            local S = import("KismetSystemLibrary")
            if S and S.GetDeviceId then
                local h = tostring(S.GetDeviceId())
                if h and h ~= "" and h ~= "UNKNOWN" then hwid = h end
            end
        end)
    end
    
    -- 3. Thá»­ Ä‘á»c tá»« STExtraBlueprintFunctionLibrary.GetDeviceGUID / GetDeviceID
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
    
    -- 4. Thá»­ Ä‘á»c tá»« PlatformWrapper.GetDeviceId
    if hwid == "UNKNOWN" then
        pcall(function()
            local P = import("PlatformWrapper")
            if P and P.GetDeviceId then
                local p = tostring(P.GetDeviceId())
                if p and p ~= "" and p ~= "UNKNOWN" then hwid = p end
            end
        end)
    end
    
    -- 5. Thá»­ Ä‘á»c tá»« DataCache
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

-- VÃ²ng láº·p kiá»ƒm tra báº£n quyá»n Ä‘á»‹nh ká»³
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
            
            -- Kiá»ƒm tra xem pháº£n há»“i cÃ³ pháº£i lÃ  JSON há»£p lá»‡ tá»« server hay khÃ´ng
            local isResponseValid = (resLower:match('"active"%s*:') ~= nil or resLower:match('"status"%s*:') ~= nil)
            if not isResponseValid then
                -- Náº¿u khÃ´ng pháº£i JSON há»£p lá»‡ (vÃ­ dá»¥: Nginx 502/504 HTML), bá» qua Ä‘á»ƒ trÃ¡nh khÃ³a nháº§m khi máº¡ng lag/server restart
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
                            msgBox.Show(1, "Báº¢N QUYá»€N Háº¾T Háº N", "Báº£n quyá»n Mod Menu Ä‘Ã£ háº¿t háº¡n hoáº·c bá»‹ thu há»“i.\nVui lÃ²ng gia háº¡n hoáº·c liÃªn há»‡ Admin.", function() end, function() end, "ÄÃ“NG", "ÄÃ“NG")
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
    _G.DX_TimerGuards = _G.DX_TimerGuards or {}
    if _G.DX_TimerGuards.CheckLoop then return end
    _G.DX_TimerGuards.CheckLoop = true
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

-- =========================== PHáº¦N 1: UGC MOD VALIDATOR BYPASS ===========================
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

-- =========================== PHáº¦N 2: PAK FILE MANAGER BYPASS ===========================
local function InitializePakFileManagerBypass()
    pcall(function()
        local PakFileMgr = package.loaded["PakFileManager"] or _G.PakFileManager
        if PakFileMgr then
            if PakFileMgr.VerifySignature then PakFileMgr.VerifySignature = function() return true end end
            if PakFileMgr.CheckFileIntegrity then PakFileMgr.CheckFileIntegrity = function() return true end end
        end
    end)
end

-- =========================== PHáº¦N 3: HAWKEYE ANTI-CHEAT BYPASS ===========================
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

-- =========================== PHáº¦N 4: SECURITY SUBSYSTEM BYPASS (VIP DYNAMIC SCAN) ===========================
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
-- =========================== PHáº¦N 5: SKIN BYPASS ===========================
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

-- [XÃ“A Bá»Ž PHáº¦N 6 AUTO HEAD HOOKS THEO YÃŠU Cáº¦U]
-- =========================== PHáº¦N 7: CLIENT TLOG UTIL BYPASS ===========================
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

-- =========================== PHáº¦N 8: STEXTRA BLUEPRINT FUNCTION LIBRARY BYPASS ===========================
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

-- =========================== PHáº¦N 9: SHA256 HASH BYPASS ===========================
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

-- =========================== PHáº¦N 10: TSSSDK NÃ‚NG CAO BYPASS (VIP DYNAMIC SCAN) ===========================
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
-- =========================== PHáº¦N 11: CONNECTION GUARD Má»ž Rá»˜NG ===========================
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

-- =========================== PHáº¦N 12: Bá»” SUNG SUBSYSTEM CÃ’N THIáº¾U ===========================
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
        
        -- Hook require Ä‘á»ƒ triá»‡t tiÃªu cÃ¡c module báº£o máº­t
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
                    -- Patch báº¥t ká»³ module nÃ o liÃªn quan Ä‘áº¿n ban/punishment
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

-- =========================== PHáº¦N 13: FPS UNLOCK ===========================
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

-- =========================== PHáº¦N 14: SLUA & JIT BYPASS NÃ‚NG Cáº¤P ===========================
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

-- =========================== PHáº¦N 15: MD5 & PAK SIGNATURE BYPASS NÃ‚NG Cáº¤P ===========================
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

-- =========================== PHáº¦N 16: LOG & CRASH BLOCKER NÃ‚NG Cáº¤P ===========================
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

-- =========================== PHáº¦N 17: SCANNER BLOCKER NÃ‚NG Cáº¤P ===========================
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

-- =========================== PHáº¦N 18: REPLAY TELEMETRY BLOCKER ===========================
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

-- Pháº§n 19 Ä‘Ã£ Ä‘Æ°á»£c gá»™p vÃ o InitializeConnectionGuardExtended (Pháº§n 11)

-- =========================== PHáº¦N 19A: SWIFTHAWK DEEP BYPASS ===========================
local function InitializeSwiftHawkBypass()
    pcall(function()
        -- Block SwiftHawk module hoÃ n toÃ n
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
        -- Hook SubsystemMgr Ä‘á»ƒ vÃ´ hiá»‡u hÃ³a ngay khi Get
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

-- =========================== PHáº¦N 19B: SHOOT VERIFY DS-SIDE BYPASS ===========================
local function InitializeShootVerifyDSBypass()
    pcall(function()
        -- Táº¯t toÃ n bá»™ káº¿t quáº£ xÃ¡c minh Ä‘áº¡n tá»« phÃ­a DS
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
        -- Block RPC káº¿t quáº£ xÃ¡c minh Ä‘áº¡n
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            if GC.RPC_Client_ShootVertifyRes   then GC.RPC_Client_ShootVertifyRes   = function() end end
            if GC.RPC_Server_ShootVertifyRes   then GC.RPC_Server_ShootVertifyRes   = function() end end
            if GC.OnShootVerifyFailed          then GC.OnShootVerifyFailed          = function() end end
        end
    end)
end

-- =========================== PHáº¦N 19C: CORONALAB DEEP BYPASS ===========================
local function InitializeCoronaLabDeepBypass()
    pcall(function()
        -- Block module chÃ­nh
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
        -- Fake dá»¯ liá»‡u CoronaLab toÃ n cá»¥c
        _G.GlobalPlayerCoronaData = _G.GlobalPlayerCoronaData or {}
        local mt_cl = getmetatable(_G.GlobalPlayerCoronaData) or {}
        mt_cl.__newindex = function() end
        mt_cl.__index    = function() return 0 end
        setmetatable(_G.GlobalPlayerCoronaData, mt_cl)
        -- Block callback trÃªn GameplayCallbacks
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            if GC.RPC_ClientCoronaLab        then GC.RPC_ClientCoronaLab        = function() end end
            if GC.CoronaLabReport            then GC.CoronaLabReport            = function() end end
            if GC.OnCoronaLabDataCollected   then GC.OnCoronaLabDataCollected   = function() end end
            if GC.SendCoronaLabData          then GC.SendCoronaLabData          = function() end end
        end
    end)
end

-- =========================== PHáº¦N 19D: CLIENT SEC MRPCS FLOW DS BYPASS ===========================
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

-- =========================== PHáº¦N 19E: NET DRIVER ERROR GUARD ===========================
local function InitializeNetDriverErrorGuard()
    pcall(function()
        -- NgÄƒn game tá»± táº¯t vÃ¬ lá»—i net driver
        if _G.GameplayCallbacks then
            local GC = _G.GameplayCallbacks
            if GC.OnNetDriverError        then GC.OnNetDriverError        = function() end end
            if GC.OnNetConnectionError    then GC.OnNetConnectionError    = function() end end
            if GC.OnSessionError          then GC.OnSessionError          = function() end end
            if GC.OnNetworkFailure        then GC.OnNetworkFailure        = function() end end
            if GC.OnTravelError           then GC.OnTravelError           = function() end end
        end
        -- Hook UEngine level error handler náº¿u cÃ³
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

-- =========================== PHáº¦N 19F: GAMESAFE & ACE DEEP HOOK ===========================
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

-- =========================== PHáº¦N 19G: PAK SIGNATURE WATCHER BYPASS ===========================
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

-- =========================== PHáº¦N 19H: RPC SERVER VALIDATE HOOK ===========================
local function InitializeRPCValidateHook()
    pcall(function()
        -- Hook BRPlayerCharacterBase RPC validate functions Ä‘á»ƒ chÃºng luÃ´n return true
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

-- =========================== PHáº¦N 20: NETWORK PACKET BLOCKER ===========================
local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket and not NetUtil.IsBypassed then
            local originalSendPacket = NetUtil.SendPacket
            local blockedPackets = {
                -- âœ… CHá»ˆ CHáº¶N: Packet anti-cheat
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
                
                -- âœ… CÃC PACKET GÃ‚Y Máº¤T Káº¾T Ná»I / KICK KHI DÃ™NG CÃC TÃNH NÄ‚NG MOD
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
                -- Kiá»ƒm tra kiá»ƒu dá»¯ liá»‡u thay vÃ¬ so sÃ¡nh báº£ng trá»±c tiáº¿p:
                -- Náº¿u firstArg lÃ  string â†’ Ä‘Ã¢y lÃ  tÃªn packet (gá»i tÄ©nh: NetUtil.SendPacket("name", ...))
                -- Náº¿u firstArg lÃ  table/userdata â†’ Ä‘Ã¢y lÃ  self/instance (gá»i OOP: obj:SendPacket("name", ...))
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

-- =========================== PHáº¦N 21: HIGGS BOSON DISABLE ===========================
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

-- =========================== PHáº¦N 22: ANTI CHEAT HOOKS ===========================
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

-- =========================== PHáº¦N 23: ANTI REPORT ===========================
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

-- =========================== PHáº¦N 24: GAMEPLAY CALLBACKS BYPASS ===========================
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

-- =========================== PHáº¦N 24B: ULTIMATE FAKE HWID + IP + FIREBASE + XID (DX) ===========================
_G.DXConfig = _G.DXConfig or {}
_G.DX_OriginalInfo = _G.DX_OriginalInfo or {}
_G.DX_FakeData = _G.DX_FakeData or {}

-- [POPUP] Hiá»ƒn thá»‹ thÃ´ng bÃ¡o chi tiáº¿t
local function DX_ShowPopup(msg)
    pcall(function()
        local Msg = require("client.slua.logic.Common.logic_common_msg_box") 
                 or require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(1, "[DX] Identity Spoofer", tostring(msg), 
                function() end, function() end, "OK", "ÄÃ“NG")
        end
    end)
end

-- [GENERATOR] Táº¡o dá»¯ liá»‡u giáº£ thÃ´ng minh (chuáº©n format tháº­t)
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

-- [LOGGING] Ghi log kiá»ƒm tra cho Spoofer
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
    
    -- Ghi log ra file Ä‘á»ƒ Admin kiá»ƒm tra
    local f = _G.DX_FakeData
    DX_WriteDebugLog(string.format("SPOOFED DATA CREATED -> HWID: %s | Model: %s | IP: %s | MAC: %s | OS: %s", 
        f.HWID, f.Model, f.IP, f.MAC, f.OS))
        
    return _G.DX_FakeData
end

-- [CAPTURE] LÆ°u thÃ´ng tin tháº­t trÆ°á»›c khi fake
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

-- [HOOK ENGINE] Override hÃ m Native + Metatable data_device_os
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
                -- âœ… Äá»’NG Bá»˜: Äá»c tá»« DX_Settings (menu Code 1)
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

-- [POPUP BUILDER] Format popup so sÃ¡nh Tháº­t > Giáº£
local function DX_BuildPopupON()
    local o = _G.DX_OriginalInfo
    local f = _G.DX_FakeData
    local function Safe(val) return (val and val ~= "") and tostring(val) or "[Not Found]" end
    return string.format(
        "[FAKE IDENTITY ÄÃƒ KÃCH HOáº T]\n\n" ..
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
    return "[ÄÃƒ KHÃ”I PHá»¤C IDENTITAS Gá»C]\n\n" ..
        "HWID, IP Address, Firebase ID,\n" ..
        "XID (AdID/OAID), Device Model,\n" ..
        "MAC Address, vÃ  OS Version\n" ..
        "Ä‘Ã£ Ä‘Æ°á»£c tráº£ vá» giÃ¡ trá»‹ tháº­t cá»§a thiáº¿t bá»‹."
end

-- [MENU UI] ÄÃ£ xÃ³a khá»i menu â€” FakeHWID luÃ´n cháº¡y ná»n tá»± Ä‘á»™ng

-- Tá»± Ä‘á»™ng khá»Ÿi táº¡o hook vÃ  LUÃ”N Báº¬T FAKE_HWID khi script load (khÃ´ng cáº§n menu)
pcall(function()
    _G.DX_Settings = _G.DX_Settings or {}
    _G.DX_Settings.FAKE_HWID = 1  -- LuÃ´n báº­t, khÃ´ng phá»¥ thuá»™c menu
    DX_RegenerateAllFakeData()     -- Sinh dá»¯ liá»‡u giáº£ má»›i ngay khi load
    _G.DX_InitializeHWIDHook()     -- CÃ i hook lÃªn táº¥t cáº£ cÃ¡c hÃ m Native
end)



-- =========================== PHáº¦N 24C: STRONG BYPASS PAKS ===========================
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
                -- Kiá»ƒm tra kiá»ƒu dá»¯ liá»‡u thay vÃ¬ so sÃ¡nh báº£ng trá»±c tiáº¿p:
                -- Náº¿u firstArg lÃ  string â†’ tÃªn packet (gá»i tÄ©nh)
                -- Náº¿u firstArg lÃ  table/userdata â†’ self/instance (gá»i OOP), tÃªn packet á»Ÿ secondArg
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

-- =========================== PHáº¦N 24D: GOKUBA SECURITY BYPASS ===========================
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

-- =========================== PHáº¦N 25: PERIODIC RE-HOOK ===========================
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
    -- pcall(InitializeAutoHeadHooks) -- XÃ³a bá» theo yÃªu cáº§u
    pcall(InitializeClientTLogUtilBypass)
    pcall(InitializeSTExtraBPLibraryBypass)
    pcall(InitializeSHA256Bypass)
    pcall(InitializeTssSdkAdvancedBypass)
    pcall(InitializeConnectionGuardExtended)
    pcall(InitializeMissingSubsystems)
    pcall(InitializeStrongBypassPaks)
    pcall(InitializeGokubaBypass)
    pcall(_G.DX_InitializeHWIDHook)
    -- === PHáº¦N Má»šI Bá»” SUNG ===
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
    _G.DX_TimerGuards = _G.DX_TimerGuards or {}
    if _G.DX_TimerGuards.ReHookLoop then return end
    _G.DX_TimerGuards.ReHookLoop = true
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

-- =========================== KHá»žI Táº O ANTI-CHEAT BYPASS & UNLOCK SKIN ===========================
pcall(RunAllBypasses)
pcall(StartPeriodicRehook)
if StartDXCheckLoop then
    pcall(StartDXCheckLoop)
end

_G.DX_Settings = _G.DX_Settings or {}
_G.DX_Settings.UNLOCK_SKIN_ALL = 1
_G.DX_GetVal = function(id) return 1 end
-- ============ ADD OUTFIT MERGED (1.lua) ============
do

    -- =========================== KHá»žI Táº O Cáº¤U HÃŒNH TAB UNLOCK SKIN ===========================
    pcall(function()
        _G.DX_Settings = _G.DX_Settings or {}
        _G.DX_Settings.UNLOCK_SKIN_ALL = 1  -- Auto-ON: AddOutfit luÃ´n hoáº¡t Ä‘á»™ng, táº¯t thá»§ cÃ´ng qua menu náº¿u muá»‘n

        local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
        if SettingPageDefine and SettingPageDefine.ModMenu and SettingPageDefine.ModMenu.Category then
            local found = false
            for _, cat in ipairs(SettingPageDefine.ModMenu.Category) do
                if cat.Key == "ModMenu_CatUnlockSkin" then
                    found = true
                    break
                end
            end
            if not found and _G.StackUnlockSkin then
                table.insert(SettingPageDefine.ModMenu.Category, {
                    Key = "ModMenu_CatUnlockSkin", loc = "UNLOCK SKIN", text = "UNLOCK SKIN", Text = "UNLOCK SKIN", title = "UNLOCK SKIN", Title = "UNLOCK SKIN", Stack = _G.StackUnlockSkin
                })
            end
        end
    end)
    -- ========================================================================================

    local function notify(msg)
        pcall(function()
            local fn = ShowNotice or _G.ShowNotice
            if fn then fn("[AddOutfit] " .. tostring(msg), false, 10) end
        end)
    end

    local function _aoReport(msg)
        pcall(function()
            local w = WriteReportToPaksFile or _G.WriteReportToPaksFile
            if w then w("[AddOutfit] " .. tostring(msg)) end
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
            '../../ShadowTrackerExtra/Saved/Paks/',
            'ShadowTrackerExtra/Saved/Paks/',
            '../ShadowTrackerExtra/Saved/Paks/',
            '/Documents/ShadowTrackerExtra/Saved/Paks/',
            '/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/',
            '/sdcard/Android/data/com.pubg.imobile/files/ShadowTrackerExtra/Saved/Paks/',
            '/sdcard/Android/data/com.pubg.imobile/files/',
            '/sdcard/Android/data/com.pubg.krmobile/files/',
            '/sdcard/Android/data/com.vng.pubgmobile/files/',
            '/sdcard/Android/data/com.rekoo.pubgm/files/',
            '/sdcard/Android/data/com.tencent.ig/files/',
            '/storage/emulated/0/Android/data/com.pubg.imobile/files/',
            '/storage/emulated/0/Android/data/com.pubg.krmobile/files/',
            '/storage/emulated/0/Android/data/com.vng.pubgmobile/files/',
            '/storage/emulated/0/Android/data/com.rekoo.pubgm/files/',
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
                    _aoReport("savepath FOUND existing: " .. tostring(_outfitSavePathCache))
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
                            _aoReport("savepath MIGRATED legacy: " .. tostring(_outfitSavePathCache))
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
                _aoReport("savepath PROBE ok: " .. tostring(_outfitSavePathCache))
                return _outfitSavePathCache
            end
        end
        _outfitSavePathCache = possibleDirs[1] .. fileName
        _aoReport("savepath FALLBACK (no dir writable): " .. tostring(_outfitSavePathCache))
        return _outfitSavePathCache
    end

        local _AO_INS_BASE = 2000000000
        local function _aoIsInjIns(ins)
            ins = tonumber(ins)
            if not ins or ins <= 0 then return false end
            local r = _G.AddOutfit_R
            if r and r.insToRes[ins] then return true end
            return ins >= _AO_INS_BASE
        end
        local function _aoIsInjRes(res)
            res = tonumber(res)
            if not res or res <= 0 then return false end
            local r = _G.AddOutfit_R
            if r and r.resToIns and r.resToIns[res] then return true end
            local s = _G.AddOutfit_injectedResSet
            if s and s[res] then return true end
            return res > 1000
        end
        local function _aoKeepList(parts)
            local kept = {}
            for _, v in ipairs(parts) do
                local n = tonumber(v)
                if n and _aoIsInjIns(n) then kept[#kept + 1] = tostring(n) end
            end
            return kept
        end

        local function _saveEquippedCache()
            if _G.DX_GetVal("UNLOCK_SKIN_ALL") ~= 1 then return false end
            local wrote = false
            local okS, errS = pcall(function()
                local cch = _G.AddOutfitEquippedCache
                if not cch then return end
                local path = _getOutfitSavePath()
                if not path then return end
            local lines = {}
            if cch.outfitRes and _aoIsInjRes(cch.outfitRes) then lines[#lines + 1] = "outfitRes=" .. tostring(cch.outfitRes) end
            if cch.outfitIns and _aoIsInjIns(cch.outfitIns) then lines[#lines + 1] = "outfitIns=" .. tostring(cch.outfitIns) end
            local clothIds = {}
            for resID in pairs(cch.clothes or {}) do
                if _aoIsInjRes(resID) then clothIds[#clothIds + 1] = tostring(resID) end
            end
            if #clothIds > 0 then
                lines[#lines + 1] = "clothes=" .. table.concat(clothIds, ",")
            end
            local eq = cch.equip or {}
            if eq.bag and _aoIsInjRes(eq.bag) then lines[#lines + 1] = "equip_bag=" .. tostring(eq.bag) end
            if eq.helmet and _aoIsInjRes(eq.helmet) then lines[#lines + 1] = "equip_helmet=" .. tostring(eq.helmet) end
            if eq.armor and _aoIsInjRes(eq.armor) then lines[#lines + 1] = "equip_armor=" .. tostring(eq.armor) end
            if eq.parachute and _aoIsInjRes(eq.parachute) then lines[#lines + 1] = "equip_parachute=" .. tostring(eq.parachute) end
            if eq.glider and _aoIsInjRes(eq.glider) then lines[#lines + 1] = "equip_glider=" .. tostring(eq.glider) end
            if eq.bagIns and _aoIsInjIns(eq.bagIns) then lines[#lines + 1] = "equip_bagIns=" .. tostring(eq.bagIns) end
            if eq.helmetIns and _aoIsInjIns(eq.helmetIns) then lines[#lines + 1] = "equip_helmetIns=" .. tostring(eq.helmetIns) end
            if eq.armorIns and _aoIsInjIns(eq.armorIns) then lines[#lines + 1] = "equip_armorIns=" .. tostring(eq.armorIns) end
            if eq.parachuteIns and _aoIsInjIns(eq.parachuteIns) then lines[#lines + 1] = "equip_parachuteIns=" .. tostring(eq.parachuteIns) end
            if eq.gliderIns and _aoIsInjIns(eq.gliderIns) then lines[#lines + 1] = "equip_gliderIns=" .. tostring(eq.gliderIns) end
            for wid, w in pairs(cch.weapons or {}) do
                wid = tonumber(wid)
                local wr = tonumber(w and w.resID) or 0
                if wid and wr > 0 and wr ~= wid and _aoIsInjIns(w and w.insID) then
                    lines[#lines + 1] = "weapon_" .. tostring(wid) .. "=" .. tostring(wr) .. ":" .. tostring(w.insID or 0)
                end
            end
            pcall(function()
                if DataMgr and DataMgr.MotionSlotList then
                    local kept = _aoKeepList(DataMgr.MotionSlotList)
                    if #kept > 0 then lines[#lines + 1] = "motion=" .. table.concat(kept, ",") end
                end
            end)
            pcall(function()
                local AvatarData = require("client.logic.data.AvatarData")
                local kept = _aoKeepList(AvatarData.GetRoleWear())
                if #kept > 0 then lines[#lines + 1] = "rolewear=" .. table.concat(kept, ",") end
            end)
            pcall(function()
                if DataMgr and DataMgr.equipmentSkinInsIDTable then
                    for subType, ins in pairs(DataMgr.equipmentSkinInsIDTable) do
                        ins = tonumber(ins)
                        if ins and _aoIsInjIns(ins) then
                            lines[#lines + 1] = "equipins_" .. tostring(subType) .. "=" .. tostring(ins)
                        end
                    end
                end
            end)
            pcall(function()
                if DataMgr and DataMgr.vst_skin then
                    local ins = tonumber(DataMgr.vst_skin)
                    if ins and _aoIsInjIns(ins) then lines[#lines + 1] = "vst_skin=" .. tostring(ins) end
                end
            end)
            pcall(function()
                local HT = require("client.logic.lobby.hall_theme_utils")
                local ins = tonumber(HT.GetThemeInstId and HT.GetThemeInstId()) or 0
                if ins > 0 and _aoIsInjIns(ins) then
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
                            local kept = _aoKeepList(insList)
                            if #kept > 0 then
                                lines[#lines + 1] = "vehicle_" .. tostring(subType) .. "=" .. table.concat(kept, ",")
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
                        if info and info.inst_id and _aoIsInjIns(info.inst_id) then
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
                        if info.resID and info.resID > 0 and _aoIsInjIns(info.insID) then
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
                _aoReport("saveWrite: total=" .. #lines .. " weapon=" .. nWeapon .. " clothes=" .. nCloth .. " outfit=" .. nOutfit)
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
        if wrote then
            _aoReport("saveWrite OK: path=" .. tostring(_getOutfitSavePath()))
        elseif okS then
            _aoReport("saveWrite FAILED: path=" .. tostring(_getOutfitSavePath()))
        else
            _aoReport("saveWrite ERROR: " .. tostring(errS))
        end
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
                            if wr and wr > 0 and wr ~= wid then
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

            if _G._savedOutfitRes and _aoIsInjRes(_G._savedOutfitRes) then
                cch.outfitRes = _G._savedOutfitRes
                if _G._savedOutfitIns and _aoIsInjIns(_G._savedOutfitIns) then
                    cch.outfitIns = _G._savedOutfitIns
                end
            end
            if not _G._addOutfitPersistLoaded and _G._savedOutfitClothes then
                for resID in pairs(_G._savedOutfitClothes) do
                    if _aoIsInjRes(resID) then cch.clothes[resID] = true end
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
            if _G.AddOutfitSyncCacheBeforeSave then _G.AddOutfitSyncCacheBeforeSave() end
            local newSnap = _snapshotCache()
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
                _aoReport("flush: outfit=" .. tostring(dch and dch.outfitRes or 0)
                    .. " clothes=" .. nCl .. " weapons=" .. nW
                    .. " rolewear=" .. nRW .. " throw=" .. nTh
                    .. " changed=" .. tostring(newSnap ~= _lastSnapshot))
            end)
            local _aoChanged = (newSnap ~= _lastSnapshot)
            if _aoChanged then
                local okW, wrote = pcall(_saveEquippedCache)
                if okW and wrote then _lastSnapshot = newSnap end
                _aoReport("flushSave: changed=" .. tostring(_aoChanged) .. " ok=" .. tostring(okW) .. " wrote=" .. tostring(wrote))
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

    -- ========== Ø­Ù‚Ù† WardrobeNewHandler (Ù„Ø¥ØµÙ„Ø§Ø­ Ø­ÙØ¸ Ø§Ù„Ø³ÙŠØ§Ø±Ø§Øª ÙÙŠ Ø§Ù„Ù„ÙˆØ¨ÙŠ) ==========
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
        local _itemsLoaded = false  -- Ù…Ù†Ø¹ Ø¥Ø¹Ø§Ø¯Ø© ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø¹Ù†Ø§ØµØ±

        -- Ø¨Ù†Ø§Ø¡ Ø®Ø±Ø§Ø¦Ø· "Ø§Ù„Ø­Ø¯Ù‘ Ø§Ù„Ø£Ù‚ØµÙ‰ Ù„Ù„Ù…Ø³ØªÙˆÙ‰" Ù„Ù…Ø¬Ù…ÙˆØ¹Ø§Øª Ø§Ù„ØªØ±Ù‚ÙŠØ© (Ø£Ø³Ù„Ø­Ø©/Ù…Ø¹Ø¯Ù‘Ø§Øª) ÙˆØ¹ØµÙˆØ± X-Suit
        -- Ø§Ù„Ù†ØªÙŠØ¬Ø©: Ù…Ø¬Ù…ÙˆØ¹Ø© Ù…Ù† Ø§Ù„Ù…Ø¹Ø±ÙØ§Øª Ø§Ù„ØªÙŠ ÙŠØ¬Ø¨ Ø§Ø³ØªØ¨Ø¹Ø§Ø¯Ù‡Ø§ Ù„Ø£Ù†Ù‡Ø§ Ù„ÙŠØ³Øª Ø£Ø¹Ù„Ù‰ Ù„ÙÙ„ Ø¶Ù…Ù† Ø³Ù„Ø³Ù„ØªÙ‡Ø§
        local function buildNonMaxLevelSet()
            local nonMax = {}
            if not (CDataTable and CDataTable.GetTable) then return nonMax end

            -- 1) Ø¬Ø¯ÙˆÙ„ ØªØ±Ù‚ÙŠØ© Ø§Ù„Ø¹Ù†Ø§ØµØ± (Ø£Ø³Ù„Ø­Ø© + Ø®ÙˆØ°/Ø´Ù†Ø·/Ø¯Ø±Ø¹ Ø§Ù„ØªÙŠ ØªØ³ØªØ®Ø¯Ù… Ù†ÙØ³ Ø§Ù„Ø¢Ù„ÙŠØ©)
            pcall(function()
                local upTbl = CDataTable.GetTable("ItemUpgradeConfig")
                if not upTbl then return end
                -- Ù„ÙƒÙ„ GroupID: Ø£ÙˆØ¬Ø¯ Ø£Ø¹Ù„Ù‰ Level + Ù…Ø¹Ø±Ù Ø§Ù„Ø¹Ù†ØµØ± ØµØ§Ø­Ø¨Ù‡
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

            -- 2) Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø¨Ø¯Ù„Ø§Øª X-Suit (Star levels)
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

            -- 3) Ø®ÙˆØ° ÙˆØ´Ù†Ø· Ù‚Ø§Ø¨Ù„Ø© Ù„Ù„ØªØ±Ù‚ÙŠØ© (BackpackMapping: Lv1/Lv2/Lv3 â†’ Ù†ÙØ¨Ù‚ÙŠ Lv3 ÙÙ‚Ø·)
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
                log("Ø¬Ù…Ø¹ ØªÙ„Ù‚Ø§Ø¦ÙŠ", count, "Ø¹Ù†ØµØ± Ù„Ù„Ø­Ù‚Ù†", "(ØªÙ… ØªØ¬Ø§Ù‡Ù„", skipped, "Ù†Ø³Ø®Ø© Ù„ÙŠØ³Øª Ø£Ø¹Ù„Ù‰ Ù„ÙÙ„)")
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
            weaponDiagReason = nil,
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
            if _G.DX_GetVal("UNLOCK_SKIN_ALL") ~= 1 then return false end
            return ins and R.insToRes[tonumber(ins)] ~= nil
        end

        local function isInjectedRes(res)
            if _G.DX_GetVal("UNLOCK_SKIN_ALL") ~= 1 then return false end
            return res and (R.resToIns[tonumber(res)] ~= nil or _injectedResSet[tonumber(res)])
        end

        local function weaponIdFromSkin(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            if _C.weaponId[resID] ~= nil then return _C.weaponId[resID] end
            local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
            local wid = m and (m.WeaponID or m.WeaponId) or nil
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

        -- ========== Ù„ÙÙ„Ø§Øª Ø§Ù„Ø®ÙˆØ°Ø©/Ø§Ù„Ø´Ù†Ø·Ø© (3 Ù…Ø³ØªÙˆÙŠØ§Øª) ==========
        -- catalog = ID Ø§Ù„Ø£Ø³Ø§Ø³ÙŠ | lv1/lv2/lv3 = Ø´ÙƒÙ„ ÙƒÙ„ Ù„ÙØ© ÙÙŠ Ø§Ù„Ø¬ÙŠÙ…
        -- Ù…Ø«Ø§Ù„: Magick Delight Helmet
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

        -- Ù†Ø·Ø§Ù‚Ø§Øª Ù…Ø¹Ø¯Ø§Øª Ø¨Ù€ 3 Ù„ÙÙ„Ø§Øª (Ù†ÙØ³ Ø§Ù„Ø¨Ù†ÙŠØ©: 15XX00Y### Ø­ÙŠØ« Y = Ø§Ù„Ù„ÙØ©)
        local EQUIP_LEVEL_RANGES = {
            { base = 1502000000, slot = "helmet" }, -- Ø®ÙˆØ°Ø©
            { base = 1501000000, slot = "bag"    }, -- Ø´Ù†Ø·Ø©
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
            -- resID Ù†ÙØ³Ù‡ Ù…Ù…ÙƒÙ† ÙŠÙƒÙˆÙ† Ø§Ù„Ù€ catalog (Ø¨Ø¯ÙˆÙ† Ø±Ù‚Ù… Ù„ÙÙ„) â€” Ø¬Ø±Ù‘Ø¨ Ù†Ø¨Ù†ÙŠ set Ù…Ø¨Ø§Ø´Ø±Ø©
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
            log("Ø°Ø§ÙƒØ±Ø© Ù…Ø¹Ø¯Ø§Øª", slot, resID)
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
            log("Ø°Ø§ÙƒØ±Ø© Ø³ÙƒÙ†", weaponID, "â†’", resID)
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
                local keepRes = {}
                local sawInjected = false
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    ins = tonumber(ins)
                    if ins and ins > 0 and isInjectedIns(ins) then
                        local resID = R.insToRes[ins]
                        if resID and isInjectedRes(resID) then
                            sawInjected = true
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
                                keepRes[resID] = true
                            elseif getEquipSkinSlot(resID) then
                                local slot = getEquipSkinSlot(resID)
                                cch.equip[slot] = resID
                                cch.equip[slot .. "Ins"] = ins
                            end
                        end
                    end
                end
                if sawInjected then
                    for oldRes in pairs(cch.clothes) do
                        if not keepRes[oldRes] then cch.clothes[oldRes] = nil end
                    end
                end

                -- Ù…Ø²Ø§Ù…Ù†Ø© Ø³ÙƒÙ† Ø§Ù„Ø¨Ø±Ø§Ø´ÙˆØª Ù…Ù† FashionBag
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

                -- Ù…Ø²Ø§Ù…Ù†Ø© Ø³ÙƒÙ† Ø§Ù„Ø¬Ù„Ø§ÙŠØ¯Ø± Ù…Ù† FashionBag
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
                local keepRes = {}
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
                                keepRes[resID] = true
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
                if nAdd > 0 then
                    for oldRes in pairs(cch.clothes) do
                        if not keepRes[oldRes] then cch.clothes[oldRes] = nil end
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
            syncWeaponCacheFromLobby()
            syncClothesCacheFromLive()
            syncThrowObjectCacheFromLobby()
            ensureMatchEquipCache()
            syncMatchConfigFromCache()
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
            -- log("Ø­Ù‚Ù†", resID, insID)
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

        -- ØªØ¹Ø¯ÙŠÙ„: Ù…Ù†Ø¹ Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„Ø­Ù‚Ù†
        local function injectAll(entity)
            if _G.DX_GetVal("UNLOCK_SKIN_ALL") ~= 1 then return false end
            entity = entity or getEntity()
            if not entity or not entity.bInit then return false end
            if entity._lava_injected then return true end
            refreshItems()

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

            local n = 0
            for i, resID in ipairs(ITEMS) do
                local insID = _K.INS_BASE + i
                if injectOne(entity, resID, insID) then
                    n = n + 1
                    local c = cfg(resID)
                    if _K.GUN_SUB[subType(c)] or subType(c) == _K.MELEE_ID then
                        injectArmory(resID, insID)
                    end
                end
            end
            if n > 0 then
                entity._lava_injected = true
                _G.AddOutfit_R = R
                log("Ø­Ù‚Ù†", n, "items")
            end
            return n > 0
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

        -- ========== Ø¯ÙˆØ§Ù„ Ø§Ù„Ø®Ù„Ø¹ Ø§Ù„Ù…ÙØ­Ø³ÙŽÙ‘Ù†Ø© ==========
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
                -- Ù…Ø³Ø­ Ù…Ù† install_list
                if Arm.rsp_list and Arm.rsp_list.install_list then
                    Arm.rsp_list.install_list[weaponID] = nil
                end
                -- Ù…Ø³Ø­ Ù…Ù† FashionBag
                if fbd.UpdateCurrentFashionBagWeaponSkin then
                    fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, 0)
                end
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if bag and bag.weapon_skin_list then
                    bag.weapon_skin_list[weaponID] = nil
                end
                -- ØªØ­Ø¯ÙŠØ« ÙˆØ§Ø¬Ù‡Ø© Ø§Ù„Ø³Ù„Ø§Ø­
                local bagIdx = fbd:GetFashionBagUseIndex()
                HT.proc_skin_list_chg("weapon_skin", weaponID, 0, bagIdx, {})
                wgl:SetGunID(weaponID)
                if wgl.UpdateCurrentGunAvatar then
                    wgl:UpdateCurrentGunAvatar(weaponID, 0)
                end
                -- Ø£Ø­Ø¯Ø§Ø« Ø§Ù„ØªØ­Ø¯ÙŠØ«
                if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, 0)
                end
                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, 0)
                end
                if EventSystem and EVENTID_WARDROBE_UPDATE_GUN_LIST then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, weaponID)
                end
                log("Ø®Ù„Ø¹ Ø³ÙƒÙ† Ø³Ù„Ø§Ø­", weaponID)
            end)
        end
        -- ========== Ù†Ù‡Ø§ÙŠØ© Ø¯ÙˆØ§Ù„ Ø§Ù„Ø®Ù„Ø¹ ==========

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
            log("Ù„Ø¨Ø³ Ù‚Ù†Ø¨Ù„Ø©", st, resID)
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
                    -- Ø§Ø³ØªØ¯Ø¹Ø§Ø¡ on_puton_rsp Ù…Ø¹ ØªØ®Ø·ÙŠ AddToWearInfo Ù„Ù„Ø¨Ø±Ø§Ø´ÙˆØª ÙÙ‚Ø·
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
                    -- Ø§Ø³ØªØ¯Ø¹Ø§Ø¡ on_puton_rsp Ù…Ø¹ ØªØ®Ø·ÙŠ AddToWearInfo Ù„Ù„Ø¬Ù„Ø§ÙŠØ¯Ø± ÙÙ‚Ø·
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
                -- Ø§Ù„Ø¨Ø±Ø§Ø´ÙˆØª ÙˆØ§Ù„Ø¬Ù„Ø§ÙŠØ¯Ø±: Ù„Ø§ ÙŠÙØ·Ø¨Ù‚Ø§Ù† Ù…Ø±Ø¦ÙŠØ§Ù‹ ÙÙŠ Ø§Ù„Ù„ÙˆØ¨ÙŠØŒ ÙŠÙØ®Ø²Ù†Ø§Ù† Ù„Ù„Ø¬ÙŠÙ… ÙÙ‚Ø·
                if slot ~= "parachute" and slot ~= "glider" then
                    applyEquipVisual(resID, insID, slot)
                end
                invalidateSocialWearCache()
                log("Ù„Ø¨Ø³ Ù…Ø¹Ø¯Ø§Øª", slot, resID)
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
                log("Ù„Ø¨Ø³", kind, resID)
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
            log("Ø³ÙƒÙ† Ø³Ù„Ø§Ø­", weaponID, resID, insID)
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
            log("Ø«ÙŠÙ… Ù„ÙˆØ¨ÙŠ", resID, insID)
        end

        local function restorePersistedHallTheme()
            if not _G._addOutfitPersistLoaded then return end
            local ins = tonumber(_G._savedHallThemeIns)
            if not ins or ins <= 0 then return end
            later(2.5, function()
                if isInjectedIns(ins) then putOnHallTheme(ins) end
            end)
        end

        -- ========== Ù„ÙˆØ¨ÙŠ Ø³ÙˆØ´ÙŠØ§Ù„ ==========
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

        -- ØªØ¹Ø¯ÙŠÙ„: Ù…Ù†Ø¹ Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ Ø§Ù„Ù…ØªÙƒØ±Ø± ÙÙŠ Ø§Ù„Ù„ÙˆØ¨ÙŠ
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
                log("Ø¥Ø¹Ø§Ø¯Ø© ØªØ·Ø¨ÙŠÙ‚ Ù„ÙˆØ¨ÙŠ (Ù…Ø±Ø© ÙˆØ§Ø­Ø¯Ø©)")
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
                            socialDebounce(0.5, reapplyLobbyEquipped) -- Ø²Ù…Ù† Ø£Ø·ÙˆÙ„ Ù„ØªØ¬Ù†Ø¨ Ø§Ù„ØªÙƒØ±Ø§Ø±
                        end
                    end)
                end
            end)
        end

        -- ========== Ù‡ÙˆÙƒØ§Øª Ø§Ù„Ù„ÙˆØ¨ÙŠ ==========
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
                if WDE._lava_hooked_depot_init then return end
                WDE._lava_hooked_depot_init = true
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
                if WRH._lava_hooked_put_on then return end
                WRH._lava_hooked_put_on = true
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
                            -- Ø¥ÙƒØ³Ø³ÙˆØ§Ø± (Ù…Ø§Ø³Ùƒ/Ù†Ø¸Ø§Ø±Ø©/Ø·Ø§Ù‚ÙŠØ©): Ø§Ø®Ù„Ø¹ Ø§Ù„Ù‚Ø¯ÙŠÙ… Ø¨Ù†ÙØ³ Ø§Ù„Ù†ÙˆØ¹ Ø£ÙˆÙ„Ø§Ù‹
                            -- ÙƒÙŠ Ù„Ø§ ØªØ¸Ù‡Ø± Ø£ÙƒØ«Ø± Ù…Ù† Ø¹Ù„Ø§Ù…Ø© ØµØ­ Ø¹Ù„Ù‰ Ø¹Ù†Ø§ØµØ± Ù†ÙØ³ Ø§Ù„Ø®Ø§Ù†Ø©
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

        local function isInLobby()
            local ok, r = pcall(function()
                return GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() == true
            end)
            return ok and r == true
        end

        local function isInMatchOrGame()
            local ok, r = pcall(function()
                return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus() == true
            end)
            return ok and r == true
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
            if not slua.isValid(comp) or not resID or not (tonumber(resID) and tonumber(resID) > 0) then return false end
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

        local function isClothWornOnComp(comp, resID)
            resID = tonumber(resID)
            if not resID then return false end
            local worn = false
            pcall(function()
                local AvatarData = require("client.logic.data.AvatarData")
                if isInLobby() then
                    for _, ins in pairs(AvatarData.GetRoleWear()) do
                        ins = tonumber(ins)
                        if ins and ins > 0 then
                            local rid = R.insToRes[ins]
                            if not rid then
                                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                local d = wd:GetHallDepotItemDataByInsID(ins)
                                rid = d and tonumber(d.resID)
                            end
                            if tonumber(rid) == resID then worn = true break end
                        end
                    end
                end
            end)
            pcall(function()
                if slua.isValid(comp) and comp.GetEquippedItemDefineID3 then
                    local EAvatarSlotType = import("EAvatarSlotType")
                    local def = comp:GetEquippedItemDefineID3(EAvatarSlotType.EAvatarSlotType_ClothesEquipemtSlot)
                    if def and tonumber(def.TypeSpecificID or def.ItemID) == tonumber(resID) then
                        worn = true
                    end
                end
            end)
            return worn
        end

        local function compWearingOriginalSkin(comp)
            if not slua.isValid(comp) then return false end
            local orig = false
            pcall(function()
                if comp.GetEquippedItemDefineID3 then
                    local EAvatarSlotType = import("EAvatarSlotType")
                    local def = comp:GetEquippedItemDefineID3(EAvatarSlotType.EAvatarSlotType_ClothesEquipemtSlot)
                    local id = def and tonumber(def.TypeSpecificID or def.ItemID) or 0
                    if id > 0 and not isInjectedRes(id) then orig = true end
                end
            end)
            return orig
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
                for resID in pairs(collectAllClothResIDs()) do
                    if resID ~= outfitRes and not isFullSuitRes(resID)
                        and not isBodyClothSubType(subType(cfg(resID))) then
                        if isClothWornOnComp(comp, resID) then
                            applied = true
                            okList[#okList + 1] = tostring(resID)
                        elseif applyClothToComp(comp, resID) then
                            applied = true
                            okList[#okList + 1] = tostring(resID)
                            notify("إكسسوار OK " .. resID)
                        else
                            failList[#failList + 1] = tostring(resID)
                        end
                    end
                end
            else
                local EAvatarSlotType = import("EAvatarSlotType")
                for resID in pairs(collectAllClothResIDs()) do
                    if not isFullSuitRes(resID) then
                        local appliedOne = false
                        if applyClothToComp(comp, resID) then
                            appliedOne = true
                            notify("ملابس OK " .. resID)
                        end
                        pcall(function()
                            if comp.GetEquippedItemDefineID3 then
                                local def = comp:GetEquippedItemDefineID3(EAvatarSlotType.EAvatarSlotType_ClothesEquipemtSlot)
                                if def and tonumber(def.TypeSpecificID or def.ItemID) == tonumber(resID) then
                                    appliedOne = true
                                end
                            end
                        end)
                        if appliedOne then
                            applied = true
                            okList[#okList + 1] = tostring(resID)
                        else
                            failList[#failList + 1] = tostring(resID)
                        end
                    end
            report("body applied: outfit=" .. tostring(outfitRes) .. " ok={" .. table.concat(okList, ",") .. "} fail={" .. table.concat(failList, ",") .. "}")
            return applied
        end

        local function matchApplyOutfit(char)
            if _S.matchOutfitDone then return true end
            syncWeaponCacheFromLobby()
            syncClothesCacheFromLobby()
            local comp = char.CharacterAvatarComp2_BP
            if not slua.isValid(comp) then
                report("matchApplyOutfit: comp invalid")
                return false
            end
            local cch = cache()
            if not cch.outfitRes and (not cch.clothes or next(cch.clothes) == nil) then
                pcall(_loadEquippedCache)
                cch = cache()
            end
            if not cch.outfitRes and (not cch.clothes or next(cch.clothes) == nil) then
                report("matchApplyOutfit: no outfit or clothes configured")
                return false
            end
            local clothList = {}
            for rid in pairs(cch.clothes or {}) do clothList[#clothList + 1] = tostring(rid) end
            report("matchApplyOutfit: outfit=" .. tostring(cch.outfitRes) .. " clothes={" .. table.concat(clothList, ",") .. "}")
            local ok = applyBodyClothesToComp(comp)
            report("matchApplyOutfit result: " .. tostring(ok))
            if ok then
                _S.matchOutfitDone = true
            end
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
            local outfitRes = getDesiredOutfit()
            if outfitRes and outfitRes > 0 then
                if isFullSuitRes(outfitRes) then
                    PlayerInfo.suit_skin = outfitRes
                else
                    PlayerInfo.outfit_skin = outfitRes
                end
            end
            PlayerInfo.rolewear_list = PlayerInfo.rolewear_list or {}
            local idx = tonumber(PlayerInfo.use_rolewear) or 1
            PlayerInfo.rolewear_list[idx] = PlayerInfo.rolewear_list[idx] or {}
            local rw = PlayerInfo.rolewear_list[idx]
            rw.wear_info = rw.wear_info or {}
            for k in pairs(rw.wear_info) do rw.wear_info[k] = nil end
            local wornIDs = {}
            if outfitRes and outfitRes > 0 then
                local slot = getWearSlotForResID(outfitRes) or 3
                rw.wear_info[slot] = makeWearEntry(outfitRes)
                wornIDs[outfitRes] = true
            end
            for resID in pairs(collectAllClothResIDs()) do
                if not wornIDs[resID] then
                    local slot = getWearSlotForResID(resID)
                    if slot then rw.wear_info[slot] = makeWearEntry(resID) end
                end
            end
            PlayerInfo.wear_info = rw.wear_info
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

            -- Ø·Ø¨Ù‘Ù‚ Ø³ÙƒÙ† Ø§Ù„Ø´Ù†Ø·Ø© ÙÙ‚Ø· Ù„Ùˆ Ø§Ù„Ù„Ø§Ø¹Ø¨ Ù„Ø§Ø¨Ø³ Ø´Ù†Ø·Ø© ÙØ¹Ù„Ø§Ù‹
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
            -- Ø·Ø¨Ù‘Ù‚ Ø³ÙƒÙ† Ø§Ù„Ø®ÙˆØ°Ø© ÙÙ‚Ø· Ù„Ùˆ Ø§Ù„Ù„Ø§Ø¹Ø¨ Ù„Ø§Ø¨Ø³ Ø®ÙˆØ°Ø© ÙØ¹Ù„Ø§Ù‹
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
            notify("Ù…Ø¹Ø¯Ø§Øª: Ø®ÙˆØ°Ø©=" .. tostring(eq.HelmetAvatar) .. " Ø´Ù†Ø·Ø©=" .. tostring(eq.BagAvatar))
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

                    -- fallback Ù…Ø¹ ØªØ­Ù‚Ù‚ isWearingEquip
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

            -- Ø£Ø¶Ù Ø§Ù„Ø¯Ø§Ù„Ø© Ø¯ÙŠ Ù‚Ø¨Ù„ matchApplyEquipSkins
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

            -- 1) ØªØ­Ù‚Ù‚ Ù…Ù† SlotSyncData Ø¨Ù†ÙØ³ Ø·Ø±ÙŠÙ‚Ø© pairs Ø§Ù„Ø´ØºØ§Ù„Ø©
            local itemID = getCharEquipLevel(char, slotID)
            if itemID and itemID > 0 then return true end

            -- 2) ØªØ­Ù‚Ù‚ Ù…Ù† PlayerState EquipmentAvatarData
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
                        notify("Ø®ÙˆØ°Ø© Ù…Ø§ØªØ´ OK " .. mapEquipSkinRes(catalogHelm, helmLevel))
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
                        notify("Ø´Ù†Ø·Ø© Ù…Ø§ØªØ´ OK " .. mapEquipSkinRes(catalogBag, bagLevel))
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
                                notify("Ø¨Ø±Ø§Ø´ÙˆØª Ù…Ø§ØªØ´ OK " .. tostring(paraResID))
                            end
                        end
                    end)
                    if not ok then
                        pcall(function()
                            local r = comp:HandleEquipItem(FItemDefineID(4, paraResID), FAvatarCustomDefault())
                            if isApplySuccess(r) then
                                ok = true
                                notify("Ø¨Ø±Ø§Ø´ÙˆØª Ù…Ø§ØªØ´ OK " .. tostring(paraResID))
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
                            notify("Ø¬Ù„Ø§ÙŠØ¯Ø± Ù…Ø§ØªØ´ OK " .. tostring(gliderResID))
                        end
                    end
                end)
                if not ok then
                    pcall(function()
                        local r = comp:HandleEquipItem(FItemDefineID(4, gliderResID), FAvatarCustomDefault())
                        if isApplySuccess(r) then
                            ok = true
                            notify("Ø¬Ù„Ø§ÙŠØ¯Ø± Ù…Ø§ØªØ´ OK " .. tostring(gliderResID))
                        end
                    end)
                end
            end

            -- Ø­Ø¯Ù‘Ø« PlayerController Ø¨Ø¹Ø¯ ØªØ·Ø¨ÙŠÙ‚ Ø§Ù„Ø³ÙƒÙ†Ø§Øª (Ù…Ø´ Ù‚Ø¨Ù„ØŒ Ø¹Ø´Ø§Ù† Ù†ØªØ¬Ù†Ø¨ circular dependency)
            applyMatchEquipAvatarToController()

            -- Ø¨Ø§Ù‚ÙŠ ÙƒÙˆØ¯ SlotSyncData Ø¨Ø¯ÙˆÙ† ØªØºÙŠÙŠØ±...
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

                    -- Ø¨Ø±Ø§Ø´ÙˆØª - SlotID 11 (ParachuteEquipemtSlot)
                    if slotID == 11 and NDRid ~= 0 and cch.equip.parachute and cch.equip.parachute > 0 then
                        local paraResID = cch.equip.parachute
                        if NDRid ~= paraResID then
                            AvatarSynData.ItemID = paraResID
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end

                    -- Ø¬Ù„Ø§ÙŠØ¯Ø± - SlotID 15 (GlideEquipmtSlot)
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
            if ok then notify("Ø³Ù„Ø§Ø­ PC: " .. table.concat(skinList, ",")) end
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

            -- slot 7 ÙÙ‚Ø· = Ø¨ØªØ§Ø¹ Ø§Ù„Ø³ÙƒÙ†. Ø¨Ø§Ù‚ÙŠ Ø§Ù„Ù€ slots ÙÙŠÙ‡Ø§ Ø§Ù„Ù‚Ø·Ø¹ (attachments)
            -- ØªØ¹Ø¯ÙŠÙ„ Ø£ÙŠ slot ØªØ§Ù†ÙŠ Ø¨ÙŠØ®Ù„ÙŠ Ø§Ù„Ø³Ù„Ø§Ø­ ÙŠØ¹Ù…Ù„ reload ÙˆØªØ®ØªÙÙŠ Ø§Ù„Ù‚Ø·Ø¹
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

            -- ÙØ­Øµ Ø§Ù„Ø­Ø§Ù„Ø© Ø§Ù„ÙØ¹Ù„ÙŠØ©: Ù„Ùˆ Ø§Ù„Ø³ÙƒÙ† Ø§Ù„Ø­Ø§Ù„ÙŠ Ù…Ø·Ø§Ø¨Ù‚ Ù„Ù„Ù…Ø·Ù„ÙˆØ¨ØŒ Ù„Ø§ Ø´ÙŠØ¡
            -- Ù‡Ø°Ø§ ÙŠÙ…Ù†Ø¹ Ø§Ù„ØªÙƒØ±Ø§Ø± Ø¨Ø¯ÙˆÙ† Ø§Ø³ØªØ®Ø¯Ø§Ù… guard Ù…Ø¹ØªÙ…Ø¯ Ø¹Ù„Ù‰ Ø­Ø§Ù„Ø© Ù…Ø®Ø²Ù†Ø©
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
            notify("Ø³Ø¬Ù‘Ù„Øª " .. addedCount .. " Ø³ÙƒÙ† Ø³Ù„Ø§Ø­")
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
                -- Weapon not in hand (still in spawn/spectating): inventory-level
                -- apply is the only signal we have.
                local ok = _G.equip_weapon_avatar(char)
                if ok then
                    _S.weaponApplied = true
                    _S.weaponDiagDone = true
                else
                    _S.weaponDiagReason = "no current weapon"
                end
                return ok
            end

            local curWeaponResID = 0
            pcall(function() curWeaponResID = curWeapon:GetItemDefineID().TypeSpecificID end)
            local desiredSkin = get_skin_id(curWeaponResID, curWeaponResID)
            curWeaponResID = tonumber(curWeaponResID) or 0
            desiredSkin = tonumber(desiredSkin) or 0

            -- Idempotent success: the weapon in hand already carries the desired
            -- skin, so no change is needed. Report as applied so weaponApplied
            -- reflects "correct state" instead of "just changed".
            if curWeaponResID > 0 and desiredSkin > 0 then
                local curSkin = 0
                pcall(function()
                    local aa = curWeapon.synData
                    if aa and slua.isValid(aa) then
                        local ad = aa:Get(_K.GUN_MASTER_SYN_SLOT)
                        if ad then curSkin = slua.IndexReference(ad, "defineID").TypeSpecificID or 0 end
                    end
                end)
                if tonumber(curSkin) == desiredSkin then
                    _S.lastAppliedWeaponID = curWeaponResID
                    _S.lastAppliedSkinID = desiredSkin
                    _S.weaponApplied = true
                    _S.weaponDiagDone = true
                    return true
                end
            end

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
                notify("Ø³ÙƒÙ† Ø³Ù„Ø§Ø­ Ù…Ø·Ø¨Ù‚: " .. tostring(desiredSkin))
            else
                _S.weaponDiagReason = "apply returned false (wid=" .. tostring(curWeaponResID) .. " skin=" .. tostring(desiredSkin) .. ")"
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

        -- ØªØ¹Ø¯ÙŠÙ„ startMatchWatcher Ù„Ø§Ø³ØªØ®Ø¯Ø§Ù… Ù…Ø­Ø§ÙˆÙ„Ø§Øª Ù…Ø­Ø¯ÙˆØ¯Ø©
        local function startMatchWatcher(char)
            if _S.matchTimer then return end
            _S.matchOutfitDone = false
            _S.avatarItemsRegistered = false
            _S.weaponApplied = false
            _S.weaponDiagDone = false
            _S.lastAppliedWeaponID = 0
            _S.lastAppliedSkinID = 0

            local attempts = 0
            notify("Ø¨Ø¯Ø£ Ø§Ù„Ù…Ø±Ø§Ù‚Ø¨ ÙÙŠ Ø§Ù„Ù…Ø§ØªØ´")

            _S.matchTimer = char:AddGameTimer(1.0, true, function()
                attempts = attempts + 1
                local cur = getLocalChar()
                if not cur or not slua.isValid(cur) then return end
                pcall(matchApplyAll, cur)
                pcall(function()
                    if attempts % 5 == 0 then
                        report("matchWatcher: attempt=" .. attempts
                            .. " outfitDone=" .. tostring(_S.matchOutfitDone)
                            .. " weaponApplied=" .. tostring(_S.weaponApplied)
                            .. " weaponReason=" .. tostring(_S.weaponDiagReason or "ok")
                            .. " matchTimer=" .. tostring(not not _S.matchTimer))
                    end
                end)
                if attempts >= 15 then
                    pcall(function() if cur.RemoveGameTimer then cur:RemoveGameTimer(_S.matchTimer) end end)
                    _S.matchTimer = nil
                    log("ØªÙˆÙ‚Ù Ù…Ø¤Ù‚Øª Ø§Ù„Ù…Ø§ØªØ´ Ø¨Ø¹Ø¯ 15 Ù…Ø­Ø§ÙˆÙ„Ø©")
                end
            end)
        end

        -- ========== Ø­Ù‚Ù† Ø³ÙƒÙ†Ø§Øª Ø§Ù„Ø£Ø³Ù„Ø­Ø© ÙÙŠ ÙˆØ§Ø¬Ù‡Ø© Ø§Ù„Ø´Ù†Ø·Ø© Ø¯Ø§Ø®Ù„ Ø§Ù„Ø¬ÙŠÙ… ==========
        -- Ø¨Ø¯Ù„ ØªØ¹Ø¯ÙŠÙ„ AdditionalData (Ø§Ù„Ù„ÙŠ Ù…Ø´ Ø¨ÙŠØªØ¹Ø¯Ù„ Ù…Ù† Lua)ØŒ Ø¨Ù†Ø¹Ù…Ù„ hook Ø¹Ù„Ù‰
        -- GetWeaponAvatarRes Ø§Ù„Ù„ÙŠ Ø¨ØªØ±Ø¬Ø¹ Ø§Ù„Ø³ÙƒÙ† Ù„Ù„Ù€ backpack UI
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
                    log("[AddOutfit] hookBackpackWeaponAvatarRes: ØªÙ…")
                end
            end)
        end

        -- ========== ØªØ·Ø¨ÙŠÙ‚ Ø³ÙƒÙ† Ø§Ù„Ø³ÙŠØ§Ø±Ø© Ø¯Ø§Ø®Ù„ Ø§Ù„Ø¬ÙŠÙ… ==========
        -- Ù…ÙƒØ§ÙØ¦ Lua Ù„ÙƒÙˆØ¯ C++ Ø§Ù„Ø°ÙŠ ÙŠØ·Ø¨Ù‚ Ø³ÙƒÙ† Ø§Ù„Ø³ÙŠØ§Ø±Ø© Ø¹Ù†Ø¯ Ø±ÙƒÙˆØ¨ Ù†ÙˆØ¹ Ø§Ù„Ø³ÙŠØ§Ø±Ø© Ø§Ù„Ù…Ø·Ø§Ø¨Ù‚
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

            -- ØªØ¬Ù†Ø¨ Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ Ø¹Ù„Ù‰ Ù†ÙØ³ Ø§Ù„Ø³ÙŠØ§Ø±Ø© Ø¨Ù†ÙØ³ Ø§Ù„Ø³ÙƒÙ†
            local cacheKey = tostring(vehicle) .. "_" .. tostring(defaultAvatarID) .. "_" .. tostring(currentAvatarID)
            if cacheKey == _lastVehicleSkinKey then return end

            -- Ø§Ù„Ø­ØµÙˆÙ„ Ø¹Ù„Ù‰ itemSubType Ù„Ù„Ø³ÙŠØ§Ø±Ø© Ø§Ù„Ø­Ø§Ù„ÙŠØ© Ù…Ù† Ø¬Ø¯ÙˆÙ„ Item
            local vehicleSubType = 0
            local defaultItemCfg = cfg(defaultAvatarID)
            if defaultItemCfg then
                vehicleSubType = tonumber(defaultItemCfg.ItemSubType or defaultItemCfg.itemSubType) or 0
            end

            -- Ø¬Ù…Ø¹ Ø§Ù„Ø³ÙƒÙ†Ø§Øª Ø§Ù„Ù…Ø·Ù„ÙˆØ¨Ø© Ù…Ù† VehicleSlotList
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

            -- Fallback: Ø¥Ø¶Ø§ÙØ© Ø§Ù„Ø³ÙƒÙ†Ø§Øª Ù…Ù† vst_in_battle Ù…Ù† PlayerState
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

            -- Fallback: Ù…Ø·Ø§Ø¨Ù‚Ø© Ø¨Ù†Ø§Ø¡Ù‹ Ø¹Ù„Ù‰ Ø¨Ø§Ø¯Ø¦Ø© Ø§Ù„Ù€ ID
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

            -- Ø¥Ø°Ø§ Ø§Ù„Ø³ÙƒÙ† Ø§Ù„Ø­Ø§Ù„ÙŠ Ù…Ù† Ø§Ù„Ø³ÙƒÙ†Ø§Øª Ø§Ù„Ù…Ø®ØªØ§Ø±Ø© ÙÙŠ Ø§Ù„Ø³Ù„ÙˆØªØ§ØªØŒ Ù„Ø§ Ù†ÙØ±Ø¶ ØªØºÙŠÙŠØ±Ù‡
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


            -- ØªØ·Ø¨ÙŠÙ‚ Ø§Ù„Ø³ÙƒÙ† Ø¹Ù„Ù‰ Ø§Ù„Ø³ÙŠØ§Ø±Ø©
            pcall(function()
                local pc = getPlayerController()
                if pc and avatarComp.SetVehicleNetAvatarData then
                    avatarComp:SetVehicleNetAvatarData(pc)
                end
                -- ØªØ¹ÙŠÙŠÙ† Ø¥ÙÙƒØª Ø§Ù„ØªØ¨Ø¯ÙŠÙ„ (Ù…Ø«Ù„ SwitchEffectId = 7303001 ÙÙŠ C++)
                if avatarComp.VehicleNetAvatarData then
                    avatarComp.VehicleNetAvatarData.SwitchEffectId = 7303001
                    avatarComp.VehicleNetAvatarData.UpdateFlag = 1
                end
                avatarComp:ChangeItemAvatar(skinResID, true)
                avatarComp.CanChangeAvatar = true
            end)

            -- ØªØ´ØºÙŠÙ„ Ø¥Ø¶Ø§Ø¡Ø© LED ØªØ­Øª Ø§Ù„Ø³ÙŠØ§Ø±Ø© (Chassis Light) Ø¹Ù†Ø¯ ØªØ·Ø¨ÙŠÙ‚ Ø§Ù„Ø³ÙƒÙ†
            pcall(applyVehicleChassisLight)

            _lastVehicleSkinKey = cacheKey
        end

        -- ========== Ø¥Ø¶Ø§Ø¡Ø© ØªØ­Øª Ø§Ù„Ø³ÙŠØ§Ø±Ø© (Chassis Light) ÙÙŠ Ø§Ù„Ø¬ÙŠÙ… ==========
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
            -- VSI Ù‡Ùˆ class table Ø§Ù„Ù„ÙŠ Ù„ÙŠÙ‡ __newindex = errorØŒ Ù„Ø§Ø²Ù… Ù†Ø¹Ø¯Ù„ Ø¹Ù„Ù‰ __inner_impl
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
            _S.bootstrapped = false   -- Ø¥Ø¹Ø§Ø¯Ø© Ø¶Ø¨Ø· bootstrap
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
                notify("Ø§ÙƒØªØ´ÙØª Ø´Ø®ØµÙŠØªÙƒ ÙÙŠ Ø§Ù„Ù…Ø§ØªØ´")
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

        -- Ù‡ÙˆÙƒ ØªØ¨ÙˆÙŠØ¨ Ø§Ù„Ø£Ø³Ù„Ø­Ø© Ø§Ù„Ù…ÙØ­Ø³ÙŽÙ‘Ù† (ÙŠÙ…Ù†Ø¹ Ø§Ù„Ø¥Ø¬Ø¨Ø§Ø±)
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
                    -- ØªØ­Ù‚Ù‚ Ù…Ù…Ø§ Ø¥Ø°Ø§ ÙƒØ§Ù† Ø§Ù„Ø³ÙƒÙ† Ø§Ù„Ø­Ø§Ù„ÙŠ Ù…Ø·Ø§Ø¨Ù‚Ø§Ù‹ Ù„Ù„Ù…Ø·Ù„ÙˆØ¨
                    local currentSkin = wgl.GetCurrentEquippedSkinInsID and wgl:GetCurrentEquippedSkinInsID(weaponID) or 0
                    if injected and currentSkin == w.insID then
                        -- Ø§Ù„Ø³ÙƒÙ† Ù…Ø·Ø¨Ù‚ Ø¨Ø§Ù„ÙØ¹Ù„ØŒ Ù„Ø§ ØªÙØ¹Ù„ Ø´ÙŠØ¦Ø§Ù‹
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
                        -- Ø¥Ø°Ø§ Ù„Ù… ÙŠÙƒÙ† Ù‡Ù†Ø§Ùƒ Ø³ÙƒÙ† Ù…Ø­Ù‚ÙˆÙ†ØŒ ØªØ£ÙƒØ¯ Ù…Ù† Ù…Ø³Ø­ Ø£ÙŠ Ø³ÙƒÙ† Ù…Ø«Ø¨Øª
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
                        -- log("Ø¥Ø¹Ø§Ø¯Ø© ØªØ·Ø¨ÙŠÙ‚ Ø³ÙƒÙ† Ø¨Ø¹Ø¯ ØªØ¨Ø¯ÙŠÙ„ Ø³Ù„Ø§Ø­", weaponID, w.resID)
                    else
                        -- ØªØ­Ø¯ÙŠØ« Ø§Ù„ÙˆØ§Ø¬Ù‡Ø© Ù„Ø¥Ø²Ø§Ù„Ø© Ø§Ù„Ø³ÙƒÙ†
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
                        log("Ø¥Ø²Ø§Ù„Ø© Ø³ÙƒÙ† Ø§Ù„Ø³Ù„Ø§Ø­", weaponID)
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
                            log("UpdateCurrentGunAvatar: Ø§Ø³ØªØ®Ø¯Ø§Ù… Ø³ÙƒÙ† Ù…Ø­ÙÙˆØ¸", weaponID, insID)
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

                log("hookGunWardrobe: ØªÙ…")
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

        -- ========== ØªØ´ØºÙŠÙ„ ==========
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
        pcall(function()
            _aoReport("init: savepath=" .. tostring(_getOutfitSavePath()))
            _aoReport("init: persistLoaded=" .. tostring(not not _G._addOutfitPersistLoaded))
        end)
        start()
        pcall(hookVehicleSkinAndMusicPanel)

        -- Time-based application loop (replaces frame-based tick listener)
        -- Uses os.clock() for time tracking instead of frame counting
        _G.DX_TimerGuards = _G.DX_TimerGuards or {}
        if not _G.DX_TimerGuards.AddOutfitLoops then
            _G.DX_TimerGuards.AddOutfitLoops = true
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
                        later(2.0, reapplyLobbyEquipped)
                    end
                end)
                pcall(function()
                    if isInGamePlay() then
                        local char = getLocalChar()
                        if char then bootstrapMatch(char) end
                    end
                end)
                -- Chá»‰ force-save khi VÃ€O sáº£nh, trÃ¡nh ghi Ä‘Ã¨ file báº±ng dá»¯ liá»‡u match-state
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

        end -- AddOutfitLoops guard

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
        notify("Ø§Ù„Ø³ÙƒØ±Ø¨Øª Ø¬Ø§Ù‡Ø²")
        pcall(function() report("AddOutfit init DONE") end)
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
