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
                _G.HK_GetVal = function(id) return 0 end
                
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
                _G.HK_GetVal = function(id) return _G.HK_Settings[id] or 0 end
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

-- =========================== PHẦN 4: SECURITY SUBSYSTEM BYPASS ===========================
local function InitializeSecuritySubsystemBypass()
    pcall(function()
        local SecuritySubsystem = package.loaded["GameLua.Mod.BaseMod.Common.Security.SecuritySubsystem"]
        if SecuritySubsystem then
            if SecuritySubsystem.StartScan then SecuritySubsystem.StartScan = function() end end
            if SecuritySubsystem.ReportViolation then SecuritySubsystem.ReportViolation = function() end end
            if SecuritySubsystem.OnDetected then SecuritySubsystem.OnDetected = function() end end
            if SecuritySubsystem.TriggerAction then SecuritySubsystem.TriggerAction = function() end end
        end
        
        local ClientSecSub = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientSecuritySubsystem"]
        if ClientSecSub then
            if ClientSecSub.OnSecurityEvent then ClientSecSub.OnSecurityEvent = function() end end
            if ClientSecSub.ReportViolation then ClientSecSub.ReportViolation = function() end end
            if ClientSecSub.HandleBanNotice then ClientSecSub.HandleBanNotice = function() end end
            if ClientSecSub.OnReceiveBanInfo then ClientSecSub.OnReceiveBanInfo = function() end end
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

-- =========================== PHẦN 6: AUTO HEAD HOOKS ===========================
local function InitializeAutoHeadHooks()
    pcall(function()
        local EAvatarDamagePosition = import("EAvatarDamagePosition")
        if not EAvatarDamagePosition then return end
        
        local modulesToHook = {
            "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
            "GameLua.Logic.Weapon.ShootWeaponEntity"
        }
        
        for _, path in ipairs(modulesToHook) do
            local hitLogic = package.loaded[path]
            if hitLogic and not hitLogic._IsHooked then
                local original_GetHitBodyType = hitLogic.GetHitBodyType
                if original_GetHitBodyType then
                    hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                        if _G.HKConfig and _G.HKConfig.AutoHead then 
                            return EAvatarDamagePosition.BigHead 
                        end
                        return original_GetHitBodyType(self, ImpactResult, InImpactVec)
                    end
                end
                
                local original_GetHitBodyTypeByHitPos = hitLogic.GetHitBodyTypeByHitPos
                if original_GetHitBodyTypeByHitPos then
                    hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                        if _G.HKConfig and _G.HKConfig.AutoHead then 
                            return EAvatarDamagePosition.BigHead 
                        end
                        return original_GetHitBodyTypeByHitPos(self, InImpactVec)
                    end
                end
                hitLogic._IsHooked = true
            end
        end
    end)
end

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

-- =========================== PHẦN 10: TSSSDK NÂNG CAO BYPASS ===========================
local function InitializeTssSdkAdvancedBypass()
    pcall(function()
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            if TssSdk.ReportCheatData then TssSdk.ReportCheatData = function() TssSdk_RecordScan() end end
            if TssSdk.ReportInfo then TssSdk.ReportInfo = function() TssSdk_RecordScan() end end
            if TssSdk.ReportHackAttack then TssSdk.ReportHackAttack = function() TssSdk_RecordScan() end end
            if TssSdk.ReportEnvironment then TssSdk.ReportEnvironment = function() TssSdk_RecordScan() end end
            if TssSdk.SendCmdEx then TssSdk.SendCmdEx = function() TssSdk_RecordScan() end end
            if TssSdk.SetValue then TssSdk.SetValue = function() TssSdk_RecordScan() end end
            if TssSdk.GetValue then TssSdk.GetValue = function() TssSdk_RecordScan() return 0 end end
            if TssSdk.TuringGetFeature then TssSdk.TuringGetFeature = function() TssSdk_RecordScan() return "" end end
            if TssSdk.AntiSpeedHack then TssSdk.AntiSpeedHack = function() TssSdk_RecordScan() return true end end
            if TssSdk.VerifyFile then TssSdk.VerifyFile = function() TssSdk_RecordScan() return true end end
            if TssSdk.QueryUserRisk then TssSdk.QueryUserRisk = function() TssSdk_RecordScan() return 0 end end
            if TssSdk.GetDeviceRisk then TssSdk.GetDeviceRisk = function() TssSdk_RecordScan() return 0 end end
            if TssSdk.ScanProcess then TssSdk.ScanProcess = function() TssSdk_RecordScan() return true end end
            if TssSdk.CheckGameIntegrity then TssSdk.CheckGameIntegrity = function() TssSdk_RecordScan() return true end end
            
            -- UPGRADE: Hook OnRecvData with plain search optimization & hook check to avoid recursion
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

-- =========================== PHẦN 24B: ULTIMATE FAKE HWID + IP + FIREBASE + XID (HK) ===========================
_G.HKConfig = _G.HKConfig or {}
_G.HK_OriginalInfo = _G.HK_OriginalInfo or {}
_G.HK_FakeData = _G.HK_FakeData or {}

-- [POPUP] Hiển thị thông báo chi tiết
local function HK_ShowPopup(msg)
    pcall(function()
        local Msg = require("client.slua.logic.Common.logic_common_msg_box") 
                 or require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(1, "[HK] Identity Spoofer", tostring(msg), 
                function() end, function() end, "OK", "ĐÓNG")
        end
    end)
end

-- [GENERATOR] Tạo dữ liệu giả thông minh (chuẩn format thật)
local function HK_GenerateFakeIP()
    local prefixes = {"192.168", "10.0", "172.16", "100.64"}
    local prefix = prefixes[math.random(1, #prefixes)]
    return string.format("%s.%d.%d", prefix, math.random(1, 254), math.random(1, 254))
end

local function HK_GenerateFirebaseID()
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
    local id = ""
    for i = 1, 22 do id = id .. chars:sub(math.random(1, #chars), math.random(1, #chars)) end
    return id
end

local function HK_GenerateXID()
    local hex = "0123456789abcdef"
    local function part(n) 
        local s = "" 
        for i=1,n do s = s .. hex:sub(math.random(1,16), math.random(1,16)) end 
        return s 
    end
    return string.format("%s-%s-%s-%s-%s", part(8), part(4), part(4), part(4), part(12))
end

local function HK_GenerateHWID()
    local chars = "0123456789abcdef"
    local hwid = "HK"
    for i = 1, 26 do hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) end
    return hwid
end

-- [LOGGING] Ghi log kiểm tra cho Spoofer
local function HK_WriteDebugLog(msg)
    pcall(function()
        local f = io.open("/sdcard/Android/data/com.vng.pubgmobile/files/loader_debug.txt", "a")
        if f then
            f:write(os.date("%Y-%m-%d %H:%M:%S") .. " [DXMOD-IDENTITY] " .. tostring(msg) .. "\n")
            f:close()
        end
    end)
end

local function HK_RegenerateAllFakeData()
    _G.HK_FakeData = {
        HWID = HK_GenerateHWID(),
        IP = HK_GenerateFakeIP(),
        Firebase = HK_GenerateFirebaseID(),
        XID = HK_GenerateXID(),
        Model = ({"iPad14,2","iPad13,1","iPhone15,3","SM-S928B","ASUS_AI701","2304FPN6DG"})[math.random(1, 6)],
        Name = "HK-Pro-Device",
        MAC = string.format("%02X:%02X:%02X:%02X:%02X:%02X", 
            math.random(0,255), math.random(0,255), math.random(0,255),
            math.random(0,255), math.random(0,255), math.random(0,255)),
        OS = ({"14.0","13.1.1","17.4.1","12.0"})[math.random(1, 4)]
    }
    
    -- Ghi log ra file để Admin kiểm tra
    local f = _G.HK_FakeData
    HK_WriteDebugLog(string.format("SPOOFED DATA CREATED -> HWID: %s | Model: %s | IP: %s | MAC: %s | OS: %s", 
        f.HWID, f.Model, f.IP, f.MAC, f.OS))
        
    return _G.HK_FakeData
end

-- [CAPTURE] Lưu thông tin thật trước khi fake
local function HK_CaptureOriginalInfo()
    pcall(function()
        if _G.HK_OriginalInfo.Captured then return end
        local S = import("KismetSystemLibrary")
        local T = import("STExtraBlueprintFunctionLibrary")
        local P = import("PlatformWrapper")
        local DataOS = package.loaded["client.logic.data.data_device_os"]
        
        if S and S.GetDeviceId then 
            pcall(function() _G.HK_OriginalInfo.HWID = S.GetDeviceId() end) 
        end
        if T and T.GetDeviceModel then 
            pcall(function() _G.HK_OriginalInfo.Model = T.GetDeviceModel() end) 
        end
        if T and T.GetDeviceName then 
            pcall(function() _G.HK_OriginalInfo.Name = T.GetDeviceName() end) 
        end
        if P and P.GetMacAddress then 
            pcall(function() _G.HK_OriginalInfo.MAC = P.GetMacAddress() end) 
        end
        if T and T.GetOSVersion then 
            pcall(function() _G.HK_OriginalInfo.OS = T.GetOSVersion() end) 
        end
        if DataOS then
            _G.HK_OriginalInfo.IP = DataOS.vClientIP
            _G.HK_OriginalInfo.Firebase = DataOS.FirebaseInstanceID
            _G.HK_OriginalInfo.XID = DataOS.AdvertisingID or DataOS.OAID
        end
        _G.HK_OriginalInfo.Captured = true
    end)
end

-- [HOOK ENGINE] Override hàm Native + Metatable data_device_os
function _G.HK_InitializeHWIDHook()
    HK_CaptureOriginalInfo()
    pcall(function()
        local S = import("KismetSystemLibrary")
        local T = import("STExtraBlueprintFunctionLibrary")
        local P = import("PlatformWrapper")
        
        if S and not _G.HK_HWID_Hooked then
            -- Hook HWID
            _G.HK_Orig_GetDeviceId = S.GetDeviceId
            function S.GetDeviceId(...)
                -- ✅ ĐỒNG BỘ: Đọc từ HK_Settings (menu Code 1)
                if _G.HK_Settings and _G.HK_Settings.FAKE_HWID == 1 then
                    if not _G.HK_FakeData.HWID then HK_RegenerateAllFakeData() end
                    return _G.HK_FakeData.HWID
                end
                return _G.HK_Orig_GetDeviceId and _G.HK_Orig_GetDeviceId(...) or "UNKNOWN"
            end
            
            -- Hook Model
            if T and T.GetDeviceModel then
                _G.HK_Orig_GetDeviceModel = T.GetDeviceModel
                function T.GetDeviceModel(...)
                    if _G.HK_Settings and _G.HK_Settings.FAKE_HWID == 1 then 
                        if not _G.HK_FakeData.Model then HK_RegenerateAllFakeData() end
                        return _G.HK_FakeData.Model 
                    end
                    return _G.HK_Orig_GetDeviceModel(...)
                end
            end
            
            -- Hook Name
            if T and T.GetDeviceName then
                _G.HK_Orig_GetDeviceName = T.GetDeviceName
                function T.GetDeviceName(...)
                    if _G.HK_Settings and _G.HK_Settings.FAKE_HWID == 1 then 
                        if not _G.HK_FakeData.Name then HK_RegenerateAllFakeData() end
                        return _G.HK_FakeData.Name 
                    end
                    return _G.HK_Orig_GetDeviceName(...)
                end
            end
            
            -- Hook OS Version
            if T and T.GetOSVersion then
                _G.HK_Orig_GetOSVersion = T.GetOSVersion
                function T.GetOSVersion(...)
                    if _G.HK_Settings and _G.HK_Settings.FAKE_HWID == 1 then 
                        if not _G.HK_FakeData.OS then HK_RegenerateAllFakeData() end
                        return _G.HK_FakeData.OS 
                    end
                    return _G.HK_Orig_GetOSVersion(...)
                end
            end
            
            -- Hook MAC
            if P and P.GetMacAddress then
                _G.HK_Orig_GetMac = P.GetMacAddress
                function P.GetMacAddress(...)
                    if _G.HK_Settings and _G.HK_Settings.FAKE_HWID == 1 then 
                        if not _G.HK_FakeData.MAC then HK_RegenerateAllFakeData() end
                        return _G.HK_FakeData.MAC 
                    end
                    return _G.HK_Orig_GetMac(...)
                end
            end
            _G.HK_HWID_Hooked = true
        end
        
        -- Hook data_device_os (IP, Firebase, XID) qua Metatable __index
        local DataOS = package.loaded["client.logic.data.data_device_os"]
        if DataOS and not _G.HK_DataOS_Hooked then
            local mt = getmetatable(DataOS) or {}
            local origIndex = mt.__index
            mt.__index = function(t, k)
                if _G.HK_Settings and _G.HK_Settings.FAKE_HWID == 1 then
                    if not _G.HK_FakeData.IP then HK_RegenerateAllFakeData() end
                    if k == "vClientIP" then return _G.HK_FakeData.IP end
                    if k == "FirebaseInstanceID" then return _G.HK_FakeData.Firebase end
                    if k == "AdvertisingID" or k == "OAID" then return _G.HK_FakeData.XID end
                end
                if type(origIndex) == "function" then return origIndex(t, k)
                elseif type(origIndex) == "table" then return origIndex[k]
                else return rawget(t, k) end
            end
            setmetatable(DataOS, mt)
            _G.HK_DataOS_Hooked = true
        end
    end)
end

-- [POPUP BUILDER] Format popup so sánh Thật > Giả
local function HK_BuildPopupON()
    local o = _G.HK_OriginalInfo
    local f = _G.HK_FakeData
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

local function HK_BuildPopupOFF()
    return "[ĐÃ KHÔI PHỤC IDENTITAS GỐC]\n\n" ..
        "HWID, IP Address, Firebase ID,\n" ..
        "XID (AdID/OAID), Device Model,\n" ..
        "MAC Address, và OS Version\n" ..
        "đã được trả về giá trị thật của thiết bị."
end

-- [MENU UI] Đã xóa khỏi menu — FakeHWID luôn chạy nền tự động

-- Tự động khởi tạo hook và LUÔN BẬT FAKE_HWID khi script load (không cần menu)
pcall(function()
    _G.HK_Settings = _G.HK_Settings or {}
    _G.HK_Settings.FAKE_HWID = 1  -- Luôn bật, không phụ thuộc menu
    HK_RegenerateAllFakeData()     -- Sinh dữ liệu giả mới ngay khi load
    _G.HK_InitializeHWIDHook()     -- Cài hook lên tất cả các hàm Native
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
    pcall(InitializeAutoHeadHooks)
    pcall(InitializeClientTLogUtilBypass)
    pcall(InitializeSTExtraBPLibraryBypass)
    pcall(InitializeSHA256Bypass)
    pcall(InitializeTssSdkAdvancedBypass)
    pcall(InitializeConnectionGuardExtended)
    pcall(InitializeMissingSubsystems)
    pcall(InitializeStrongBypassPaks)
    pcall(InitializeGokubaBypass)
    pcall(_G.HK_InitializeHWIDHook)
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
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
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

_G.HK_WeaponMap = {
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

_G.HK_OrderedKeywords = {
    "m249", "m24", "helmet3", "helmet_lvl3", "armor3", "armor_lvl3", "vest_level3", "bag3", "bag_lvl3", "backpack_lvl3",
    "mũ cấp 3", "mũ 3", "giáp cấp 3", "giáp 3", "balo cấp 3", "balo 3",
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

-- Bổ sung mapping theo ID số và từ khóa Tiếng Việt vào _G.HK_WeaponMap
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
        [501006] = "helmet3", [502003] = "armor3", [502006] = "armor3", [503003] = "bag3", [503006] = "bag3",
        [201009] = "scope_8x", [201012] = "scope_6x", [201007] = "scope_4x",
        [601005] = "medkit", [601006] = "firstaid",
        
        ["mũ cấp 3"] = "helmet3", ["mũ 3"] = "helmet3",
        ["giáp cấp 3"] = "armor3", ["giáp 3"] = "armor3",
        ["balo cấp 3"] = "bag3", ["balo 3"] = "bag3",
        ["8x"] = "scope_8x", ["6x"] = "scope_6x", ["4x"] = "scope_4x",
        ["bộ y tế"] = "medkit", ["sơ cứu"] = "firstaid",
        ["chảo"] = "pan", ["liềm"] = "sickle", ["rựa"] = "machete", ["xà beng"] = "crowbar"
    }
    for key, refKey in pairs(extraMappings) do
        _G.HK_WeaponMap[key] = _G.HK_WeaponMap[refKey]
    end
end)


local ConfigFileName = "Menu_Settings.txt"
_G.LastConfigSaveStr = ""

_G.HK_Settings = _G.HK_Settings or {
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
    SPECTATOR_HP_BAR = 0,
    THREAT_ESP_WARN_LINE = 1,
    THREAT_ESP_FLASH = 1,

-- Wall color (9 mau: 1=TRANG 2=DO 3=VANG 4=XANH LA 5=XANH NGOC 6=XANH DUONG 7=TIM 8=HONG 9=DEN)
    WALL_VISIBLE_COLOR = 3,       -- Mặc định Vàng (vị trí số 3)
    WALL_OCCLUDED_COLOR = 2,      -- Mặc định Đỏ (vị trí số 2)
    WALL_OCCLUDED_AI_COLOR = 7,   -- Mặc định Tím (vị trí số 7)

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

_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\n"
        for k, v in pairs(_G.HK_Settings) do
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
                        _G.HK_Settings[k] = v
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

function _G.HK_GetVal(id)
    return _G.HK_Settings[id] or 0
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
        
        local function AddSlider(stack, key, text, minVal, maxVal, expandHandle)
            local item = {
                Key = "ModMenu_" .. key,
                UI = AliasMap.Slider,
                Text = text,
                MinValue = minVal,
                MaxValue = maxVal,
                Min = minVal,
                Max = maxVal,
                GetFunc = function() return _G.HK_Settings[key] or minVal end,
                SetFunc = function(_, value)
                    local val = math.floor(tonumber(value) or minVal)
                    if val < minVal then val = minVal end
                    if val > maxVal then val = maxVal end
                    if _G.HK_Settings[key] ~= val then
                        _G.HK_Settings[key] = val
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
            { UI = AliasMap.Title, Text = "AURA" },
            { UI = AliasMap.Title, Text = "UID: " .. currentUID }
        }
        table.insert(StackESP, {
            Key = "ModMenu_Wall_Ex",
            UI = AliasMap.TitleSwitcher,
            Text = "▶ AURA / WALLHACK (1 Trắng|2 Đỏ|3 Vàng|4 Xanh lá|5 Xanh Ngọc|6Xanh Dương|7 Tím|8 Hồng|9 Đen)",
            ExpandIndex = 0,
            GetFunc = function() return _G.HK_Settings.WALLHACK == 1 end,
            SetFunc = function(_, value)
                _G.HK_Settings.WALLHACK = value and 1 or 0
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
            GetFunc = function() return _G.HK_Settings.WALL_VISIBLE_COLOR or 3 end,
            SetFunc = function(_, value)
                local v = math.floor(tonumber(value) or 3)
                _G.HK_Settings.WALL_VISIBLE_COLOR = math.max(1, math.min(9, v))
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
            GetFunc = function() return _G.HK_Settings.WALL_OCCLUDED_COLOR or 2 end,
            SetFunc = function(_, value)
                local v = math.floor(tonumber(value) or 2)
                _G.HK_Settings.WALL_OCCLUDED_COLOR = math.max(1, math.min(9, v))
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
            GetFunc = function() return _G.HK_Settings.WALL_OCCLUDED_AI_COLOR or 7 end,
            SetFunc = function(_, value)
                local v = math.floor(tonumber(value) or 7)
                _G.HK_Settings.WALL_OCCLUDED_AI_COLOR = math.max(1, math.min(9, v))
                ResetWallColorCache()
                return true
            end
        })
        
        table.insert(StackESP, {
            Key = "ModMenu_SpectatorHPBar",
            UI = AliasMap.TitleSwitcher or "TitleSwitcher",
            Text = "▶ ESP Đấu Giải (Tên, Đội, Máu, Súng, Khoảng cách)",
            GetFunc = function() return _G.HK_Settings.SPECTATOR_HP_BAR == 1 end,
            SetFunc = function(_, value)
                _G.HK_Settings.SPECTATOR_HP_BAR = value and 1 or 0
                return true
            end
        })
        
        SettingPageDefine.ModMenu = {
            Key = "ModMenu", 
            loc = "DX-MODS", 
            text = "DX-MODS",
            Text = "DX-MODS",
            title = "DX-MODS",
            Title = "DX-MODS",
            UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "ModMenu_Cat1", loc = "AURA", text = "AURA", Text = "AURA", title = "AURA", Title = "AURA", Stack = StackESP },
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
    return GetWallColorByIndex((_G.HK_Settings and _G.HK_Settings.WALL_VISIBLE_COLOR) or 3)
end
local function GetCurrentWallOccludedColor(isAI)
    if isAI then
        return GetWallColorByIndex((_G.HK_Settings and _G.HK_Settings.WALL_OCCLUDED_AI_COLOR) or 7)
    else
        return GetWallColorByIndex((_G.HK_Settings and _G.HK_Settings.WALL_OCCLUDED_COLOR) or 2)
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

local function IsParachuteComponent(comp)
    if not comp then return false end
    local ok, res = pcall(function()
        local name = comp.GetName and string.lower(tostring(comp:GetName())) or ""
        if string.find(name, "parachute") then return true end
        local path = comp.GetPathName and string.lower(tostring(comp:GetPathName())) or ""
        if string.find(path, "parachute") then return true end
        return false
    end)
    return ok and res or false
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
    if pawn.HK_IsAICached ~= nil then return pawn.HK_IsAICached end
    
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
        pawn.HK_IsAICached = isAI
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

-- ========================================== 
-- HÀM QUẢN LÝ NATIVE ESP (1006 SPECTATOR HP BAR)
-- ========================================== 
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then
                if not _G.LexusState then _G.LexusState = {} end
                if not _G.LexusState.TrackedMarks then _G.LexusState.TrackedMarks = {} end
                _G.LexusState.TrackedMarks[mark] = true
            end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    if _G.LexusState and _G.LexusState.TrackedMarks then
        _G.LexusState.TrackedMarks[mark] = nil
    end
end

local function InitializeNativeESP() 
    if _G.LexusState and _G.LexusState.NativeESPReady then return end
    pcall(function() 
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools") 
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig") 
        local function ApplyCfg(cfg)
            if not cfg then return end 
            if cfg[1006] then 
                cfg[1006].bBindBlocked = true
                cfg[1006].bBindOutScreen = true 
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000 
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root" 
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30) 
            end 
        end 
        ApplyCfg(currentMarkCfg) 
        for k, cfg in pairs(package.loaded) do 
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then 
                ApplyCfg(cfg) 
            end 
        end 
    end)
    if not _G.LexusState then _G.LexusState = {} end
    _G.LexusState.NativeESPReady = true 
end

-- ========================================== 
-- HÀM QUẢN LÝ NATIVE ESP (1006 SPECTATOR HP BAR)
-- ========================================== 
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then
                if not _G.LexusState then _G.LexusState = {} end
                if not _G.LexusState.TrackedMarks then _G.LexusState.TrackedMarks = {} end
                _G.LexusState.TrackedMarks[mark] = true
            end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    if _G.LexusState and _G.LexusState.TrackedMarks then
        _G.LexusState.TrackedMarks[mark] = nil
    end
end

local function HookSpectatorMethods()
    if _G.HK_SpectatorHookedGlobal then return end
    pcall(function()
        for _, className in ipairs({"STExtraPlayerController", "PlayerController", "STExtraPlayerControllerBlueprint"}) do
            local cls = import(className)
            if cls then
                -- Lưu các hàm gốc nếu chưa lưu
                if not cls.HK_Orig_IsObserver then cls.HK_Orig_IsObserver = cls.IsObserver end
                if not cls.HK_Orig_IsSpectator then cls.HK_Orig_IsSpectator = cls.IsSpectator end
                if not cls.HK_Orig_IsFriendObserver then cls.HK_Orig_IsFriendObserver = cls.IsFriendObserver end
                if not cls.HK_Orig_IsDemoPlaySpectator then cls.HK_Orig_IsDemoPlaySpectator = cls.IsDemoPlaySpectator end
                if not cls.HK_Orig_IsDemoPlayGlobalObserver then cls.HK_Orig_IsDemoPlayGlobalObserver = cls.IsDemoPlayGlobalObserver end
                if not cls.HK_Orig_IsFriendOrEnemySpectator then cls.HK_Orig_IsFriendOrEnemySpectator = cls.IsFriendOrEnemySpectator end
                
                -- Định nghĩa hàm hook động
                cls.IsObserver = function(self)
                    if _G.HK_GetVal("SPECTATOR_HP_BAR") == 1 then return true end
                    return cls.HK_Orig_IsObserver and cls.HK_Orig_IsObserver(self) or false
                end
                cls.IsSpectator = function(self)
                    if _G.HK_GetVal("SPECTATOR_HP_BAR") == 1 then return true end
                    return cls.HK_Orig_IsSpectator and cls.HK_Orig_IsSpectator(self) or false
                end
                cls.IsFriendObserver = function(self)
                    if _G.HK_GetVal("SPECTATOR_HP_BAR") == 1 then return true end
                    return cls.HK_Orig_IsFriendObserver and cls.HK_Orig_IsFriendObserver(self) or false
                end
                cls.IsDemoPlaySpectator = function(self)
                    if _G.HK_GetVal("SPECTATOR_HP_BAR") == 1 then return true end
                    return cls.HK_Orig_IsDemoPlaySpectator and cls.HK_Orig_IsDemoPlaySpectator(self) or false
                end
                cls.IsDemoPlayGlobalObserver = function(self)
                    if _G.HK_GetVal("SPECTATOR_HP_BAR") == 1 then return true end
                    return cls.HK_Orig_IsDemoPlayGlobalObserver and cls.HK_Orig_IsDemoPlayGlobalObserver(self) or false
                end
                cls.IsFriendOrEnemySpectator = function(self)
                    if _G.HK_GetVal("SPECTATOR_HP_BAR") == 1 then return true end
                    return cls.HK_Orig_IsFriendOrEnemySpectator and cls.HK_Orig_IsFriendOrEnemySpectator(self) or false
                end
            end
        end
    end)
    _G.HK_SpectatorHookedGlobal = true
end

local function InitializeNativeESP() 
    if _G.LexusState and _G.LexusState.NativeESPReady then return end
    pcall(HookSpectatorMethods)
    pcall(function() 
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools") 
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig") 
        local function ApplyCfg(cfg)
            if not cfg then return end 
            if cfg[1006] then 
                cfg[1006].bBindBlocked = true
                cfg[1006].bBindOutScreen = true 
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000 
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root" 
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30) 
            end 
            cfg[8888] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, 
                MaxShowDistance = 6000000, 
                bBindOutScreen = true,
                bBindBlocked = true, 
                bIsBindingActor = true,
                BindSocketName = "head",
                bUseLuaWorldSocketName = true, 
                WorldPositionOffset = FVector(0, 0, 30),
                bNeedPreLoad = true,
                Priority = 2 
            } 
            cfg[9999] = { 
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
        ApplyCfg(currentMarkCfg) 
        for k, cfg in pairs(package.loaded) do 
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then 
                ApplyCfg(cfg) 
            end 
        end 
    end)
    if not _G.LexusState then _G.LexusState = {} end
    _G.LexusState.NativeESPReady = true 
end

-- =========================== PHẦN 29: BRPLAYERCHARACTERBASE METHODS ===========================
function BRPlayerCharacterBase:StartAdvancedSystems()
    if not Client then return end
    if self.bAdvancedSystemsStarted then return end
    self.bAdvancedSystemsStarted = true
    
    pcall(InitializeNativeESP)
    
    local function Valid(obj) return slua_isValid(obj) end
    local GlobalSkelClass = import("SkeletalMeshComponent")
    
    local systemTimerHandle
    systemTimerHandle = self:AddGameTimer(0.25, true, function()
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

        if self.Object == LocalPlayer and not self.bHasShownWelcomeNotice then
            if self.Object.IsAlive and self.Object:IsAlive() then
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
                            local DeviceInfo = GetDeviceUID()
                            local S = import("KismetSystemLibrary")
                            local platform = "Android"
                            pcall(function()
                                if S and S.GetPlatformName then
                                    platform = tostring(S.GetPlatformName())
                                end
                            end)
                            
                            local notifyMsg = string.format(
                                "VIP MOD MENU ĐÃ ĐƯỢC KÍCH HOẠT\n\n" ..
                                "Thông tin thiết bị:\n" ..
                                "• UID: %s\n" ..
                                "• Hệ điều hành: %s\n\n" ..
                                "Hệ thống bảo mật và bypass đã hoạt động.",
                                tostring(DeviceInfo),
                                tostring(platform)
                            )
                            msgBox.Show(1, "HỆ THỐNG", notifyMsg, function() end, function() end, "OK", "ĐÓNG")
                        end, function() end, "OK", "OK")
                    end
                end)
            end
        end

        local isWallhackGlobalOn = (_G.HK_GetVal("WALLHACK") == 1)

        if not _G.TDModTickCount then _G.TDModTickCount = 0 end
        if not _G.MagicUpdateVersion then _G.MagicUpdateVersion = 1 end
        if _G.EnvRequiresUpdate == nil then _G.EnvRequiresUpdate = true end

        _G.TDModTickCount = _G.TDModTickCount + 1
 
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
                end
            end)
        end

        if _G.TDModTickCount % 2 == 0 then
            local allPlayers = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
            local localPlayerLoc = nil
            if type(LocalPlayer.K2_GetActorLocation) == "function" then
                localPlayerLoc = LocalPlayer:K2_GetActorLocation()
            end

            local myTeamID = LocalPlayer.TeamID
            local currentTickOS = os_clock()

            local globalVisColor, globalPlayerOccludedColor, globalAiOccludedColor, globalColorHash
            if isWallhackGlobalOn then
                globalVisColor = GetCurrentWallVisibleColor()
                globalPlayerOccludedColor = GetCurrentWallOccludedColor(false)
                globalAiOccludedColor = GetCurrentWallOccludedColor(true)
                globalColorHash = tostring((_G.HK_Settings and _G.HK_Settings.WALL_VISIBLE_COLOR) or 3) .. "_"
                               .. tostring((_G.HK_Settings and _G.HK_Settings.WALL_OCCLUDED_COLOR) or 2) .. "_"
                               .. tostring((_G.HK_Settings and _G.HK_Settings.WALL_OCCLUDED_AI_COLOR) or 7)
            end

            for _, enemy in pairs(allPlayers) do
                if Valid(enemy) and enemy ~= LocalPlayer and enemy.TeamID ~= myTeamID then
                    local isEnemyDead = false
                    local isEnemyKnocked = false
                    local currentHp = 100

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
                    
                    if not isEnemyDead then
                        if enemy.HK_IsAICached == nil then enemy.HK_IsAICached = CheckIsAI(enemy) end
                        
                        local distM = 0
                        enemy.HK_CachedActorLoc = nil
                        if type(LocalPlayer.GetDistanceTo) == "function" then
                            distM = LocalPlayer:GetDistanceTo(enemy) / 100
                        elseif localPlayerLoc then
                            local eLoc = type(enemy.K2_GetActorLocation) == "function" and enemy:K2_GetActorLocation()
                            if eLoc then
                                enemy.HK_CachedActorLoc = eLoc
                                distM = math_sqrt((localPlayerLoc.X-eLoc.X)^2 + (localPlayerLoc.Y-eLoc.Y)^2 + (localPlayerLoc.Z-eLoc.Z)^2) / 100
                            end
                        end
                   
                        if distM > 350 then
                            if enemy.WallhackApplied then
                                pcall(function()
                                    for _, comp in ipairs(enemy.LastAuraMeshes or {}) do
                                        if Valid(comp) then ResetMeshAuraComponent(comp) end
                                    end
                                    enemy.WallhackApplied = false
                                    enemy.LastAuraHash = nil
                                    enemy.LastAuraMeshes = nil
                                end)
                            end
                            goto continue
                        end

                        -- [NATIVE SPECTATOR ESP (1006 SCREEN MARK & 9999 BRACKETS)]
                        if _G.HK_GetVal("SPECTATOR_HP_BAR") == 1 then
                            pcall(function()
                                local show = true
                                local SecurityCommonUtils = _G.SecurityCommonUtils or (package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils"]) or import("SecurityCommonUtils")
                                if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                    if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                                end
                                if show and localPlayerLoc then
                                    local eLoc = enemy.HK_CachedActorLoc or (type(enemy.K2_GetActorLocation) == "function" and enemy:K2_GetActorLocation())
                                    if eLoc then
                                        if eLoc.Z >= 150000 then 
                                            show = false 
                                        else
                                            local distSq = (localPlayerLoc.X - eLoc.X)^2 + (localPlayerLoc.Y - eLoc.Y)^2
                                            if distSq > 2500000000 then -- 50000^2
                                                show = false
                                            end
                                        end
                                    end
                                end

                                if show then
                                    if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then 
                                        enemy:Replay_CreateEnemyFrameUI(true, true) 
                                    end
                                    if enemy.Replay_SetVisiableOfFrameUI then 
                                        enemy:Replay_SetVisiableOfFrameUI(true) 
                                    end
                                    if enemy.Replay_UpdateEnemyFrameUI then 
                                        enemy:Replay_UpdateEnemyFrameUI(hpRatio) 
                                    end
                                    
                                    local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                    if Valid(uiComp) then
                                        if enemy.HK_LastFrameUIState ~= "VISIBLE" then
                                            if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                            if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                            enemy.HK_LastFrameUIState = "VISIBLE"
                                        end
                                    end
                                else
                                    if enemy.Replay_SetVisiableOfFrameUI then 
                                        enemy:Replay_SetVisiableOfFrameUI(false) 
                                    end
                                    local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                    if Valid(uiComp) then
                                        if enemy.HK_LastFrameUIState ~= "HIDDEN" then
                                            if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                            if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                            enemy.HK_LastFrameUIState = "HIDDEN"
                                        end
                                    end
                                end
                            end)
                        else
                            pcall(function()
                                if enemy.Replay_SetVisiableOfFrameUI then 
                                    enemy:Replay_SetVisiableOfFrameUI(false) 
                                end
                                local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if enemy.HK_LastFrameUIState ~= "HIDDEN" then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                        enemy.HK_LastFrameUIState = "HIDDEN"
                                    end
                                end
                            end)
                        end

                        if not enemy.HK_NextMeshUpdateTime or currentTickOS > enemy.HK_NextMeshUpdateTime then
                            enemy.HK_NextMeshUpdateTime = currentTickOS + 1.5 + (math_random() * 1.0)
                            local meshes = enemy.HK_CachedMeshes or {}
                            local existing = {}
                            for _, m in ipairs(meshes) do existing[m] = true end
                            if Valid(enemy.Mesh) and not existing[enemy.Mesh] then
                                if not IsParachuteComponent(enemy.Mesh) then
                                    table.insert(meshes, enemy.Mesh)
                                    existing[enemy.Mesh] = true
                                end
                            end
                            if GlobalSkelClass then
                                pcall(function()
                                    local childs = enemy:GetComponentsByClass(GlobalSkelClass)
                                    if childs then
                                        local count = type(childs.Num) == "function" and childs:Num() or #childs
                                        for c = 1, count do
                                            local comp = type(childs.Get) == "function" and childs:Get(c-1) or childs[c]
                                            if Valid(comp) and not existing[comp] then
                                                if not IsParachuteComponent(comp) then
                                                    table.insert(meshes, comp)
                                                    existing[comp] = true
                                                end
                                            end
                                        end
                                    end
                                end)
                            end
                            enemy.HK_CachedMeshes = meshes
                        end
                        
                        local meshes = enemy.HK_CachedMeshes
                        local currentMeshCount = #meshes
                        local isMeshChanged = (enemy.LastAuraMeshes and #enemy.LastAuraMeshes ~= currentMeshCount)
                        
                        if isWallhackGlobalOn then
                            local visColor = globalVisColor
                            local occludedColor = enemy.HK_IsAICached and globalAiOccludedColor or globalPlayerOccludedColor
                            local auraHash = (enemy.HK_IsAICached and "ai_" or "player_") .. globalColorHash
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
                    else
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
                        -- Ẩn UI Khung Máu Gốc khi địch đã chết
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then 
                                enemy:Replay_SetVisiableOfFrameUI(false) 
                            end
                            local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) then
                                if enemy.HK_LastFrameUIState ~= "HIDDEN" then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    enemy.HK_LastFrameUIState = "HIDDEN"
                                end
                            end
                        end)
                    end
                    ::continue::
                end
            end
        end
    end)
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
    BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
    if Client and GameplayData.RemoveCharacter ~= nil then
        GameplayData.RemoveCharacter(self.Object)
    end

    -- Hủy timer gửi ping
    pcall(function()
        if self.nMatchPingTimer then
            self:RemoveGameTimer(self.nMatchPingTimer)
            self.nMatchPingTimer = nil
        end
    end)

    -- [TRACKING] Báo kết thúc trận lên Admin (Hỗ trợ cả IsLocallyControlled)
    local isLocalPlayerEnd = (self.Role == ENetRole.ROLE_AutonomousProxy) or (self.IsLocallyControlled and self:IsLocallyControlled())
    if isLocalPlayerEnd then
        self.bAdvancedSystemsStarted = nil -- reset guard for next match
        pcall(function()
            local uid = GetDeviceUID()

            local ModuleManager = package.loaded["client.module_framework.ModuleManager"]
                               or require("client.module_framework.ModuleManager")
            if ModuleManager then
                local http = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
                if http then
                    local sid = _G.DX_CurrentSessionId or ""
                    local body = string.format('{"uid":"%s","session_id":"%s"}', uid, sid)
                    http:Post(
                        DX_API_BASE .. "/api/match/end",
                        {["Content-Type"] = "application/json"},
                        body, "",
                        function() _G.DX_CurrentSessionId = nil end
                    )
                end
            end
        end)
    end
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
  if _G.HK_GetVal("NO_LANDING_LAG") == 1 then
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


-- =========================== PHẦN 29B: SPECTATOR GOD MODE BYPASS - WALLHACK KHI SPECTATE ===========================
local function InitializeSpectatorGodModeBypass()
    pcall(function()
        -- Khi spectate: bỏ mọi hạn chế visibility để wallhack hoạt động
        local origGetAllPlayers_spec = GameplayData.GetAllPlayerCharacters
        if origGetAllPlayers_spec and not _G.HK_SpectatorAllPlayerHooked then
            GameplayData.GetAllPlayerCharacters = function(...)
                local result = {}
                local ok, list = pcall(origGetAllPlayers_spec, ...)
                if ok and list then
                    for _, actor in pairs(list) do
                        if slua.isValid(actor) then
                            -- Force unhide tất cả actor khi spectate
                            pcall(function()
                                local pc = GameplayData.GetPlayerController()
                                local isSpec = pc and ((pc.IsSpectator and pc:IsSpectator())
                                    or (pc.IsDemoPlaySpectator and pc:IsDemoPlaySpectator())
                                    or (type(pc.IsInPetSpectator)=="function" and pc:IsInPetSpectator()))
                                if isSpec then
                                    if actor.SetActorHiddenInGame then actor:SetActorHiddenInGame(false) end
                                    local mesh = actor.Mesh
                                    if slua.isValid(mesh) then
                                        if mesh.SetVisibility then mesh:SetVisibility(true, true) end
                                    end
                                end
                            end)
                            table.insert(result, actor)
                        end
                    end
                end
                return result
            end
            _G.HK_SpectatorAllPlayerHooked = true
        end
    end)
end

pcall(InitializeSpectatorGodModeBypass)

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
            DX_Log(string.format("Sync Loop Tick: gameInstance=%s, gp=%s, gd=%s, actorClass=%s", 
                tostring(gameInstance ~= nil), tostring(gp ~= nil), tostring(gd ~= nil), tostring(actorClass and actorClass:GetName() or "nil")))
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
                        
                        if printDetail then
                            local className = "Unknown"
                            pcall(function() className = actor:GetClass():GetName() end)
                            local aName = "nil"
                            pcall(function() aName = rawActor:GetPathName() end)
                            local lpName = "nil"
                            pcall(function() lpName = rawLocal:GetPathName() end)
                            DX_Log(string.format("Checking actor: Class=%s, Path=%s vs localPawn=%s", 
                                className, aName, lpName))
                        end
                        
                        if rawActor and rawLocal then
                            if rawActor == rawLocal then
                                isLocal = true
                            elseif type(rawActor.GetPathName) == "function" and type(rawLocal.GetPathName) == "function" and rawActor:GetPathName() == rawLocal:GetPathName() then
                                isLocal = true
                            end
                        end
                    end

                    -- 3. Nếu là nhân vật của mình và chưa được khởi chạy Mod
                    if isLocal and not actor._DXInitialized then
                        actor._DXInitialized = true
                        DX_Log("Pushing mod functions to LocalPlayer Class: " .. tostring(actor:GetClass():GetName()))
                        
                        -- Copy toàn bộ hàm mod từ BRPlayerCharacterBase sang nhân vật hiện tại
                        local className = tostring(actor:GetClass():GetName())
                        local isClassicClass = className:find("BRPlayerCharacter") or className:find("BRPlayerCharacterBase")
                        for k, v in pairs(BRPlayerCharacterBase) do
                            if type(v) == "function" then
                                -- Chỉ ép đè các hàm hòm xác đối với Class nhân vật không phải chế độ cổ điển (như WOW/TDM)
                                if not isClassicClass and (k == "OnPlayerEnterCarryBoxState" or k == "OnPlayerLeaveCarryBoxState" or k == "ServerRPC_CarryDeadBox") then
                                    actor[k] = v
                                elseif not actor[k] then
                                    actor[k] = v
                                end
                            elseif k == "ServerRPC" or k == "ClientRPC" or k == "MulticastRPC" then
                                actor[k] = actor[k] or {}
                                for rpcKey, rpcVal in pairs(v) do
                                    actor[k][rpcKey] = rpcVal
                                end
                            end
                        end
                        
                        -- Cấu hình các biến trạng thái
                        actor.bHasShownDevNotice = false 
                        actor.bHasShownExpiredNotice = false 
                        actor.bHasShownWelcomeNotice = false
                        actor.bIsDeadFlag = false
                        actor.bForceWeaponMod = true
                        actor.HK_NativeESP_Ready = false

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
-- ==========================================================================

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
                LocalPlayer.HK_NativeESP_Ready = false
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

-- Khởi động tất cả anti-ban ngay lập tức
pcall(InitializeIDIPBanBypass)
pcall(InitializePunishmentBypass)
pcall(InitializePlayerStateBanClamp)
pcall(InitializeKillFlowIntegrityBypass)
pcall(InitializeChatReportBypass)
pcall(InitializeLobbyBanCheckBypass)
pcall(InitializeAntiBanPacketBlock)
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

return true