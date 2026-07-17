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
    
    -- Mod Skin Configs
    ModSkin = 0,
    SkinDeadBox = 0,
    SkinAttachment = 0,
    ModEmote = 0,
    KillMessage = 0,
    KillCountUI = 0,
    SkinOpenLink = 0,
    KillMessageEnable = 0,
    SkinEnable_Suit = 0, SkinSuit = 0,
    SkinEnable_Top = 0, SkinTop = 0,
    SkinEnable_Gloves = 0, SkinGloves = 0,
    SkinEnable_Bottom = 0, SkinBottom = 0,
    SkinEnable_Shoes = 0, SkinShoes = 0,
    SkinEnable_Bag = 0, SkinBag = 1,
    SkinEnable_Helmet = 0, SkinHelmet = 1,
    SkinEnable_Parachute = 0, SkinParachute = 1,
    SkinEnable_M416 = 0, SkinM416 = 1,
    SkinEnable_AKM = 0, SkinAKM = 1,
    SkinEnable_SCAR = 0, SkinSCAR = 1,
    SkinEnable_M762 = 0, SkinM762 = 1,
    SkinEnable_AUG = 0, SkinAUG = 1,
    SkinEnable_UMP = 0, SkinUMP = 1,
    SkinEnable_UZI = 0, SkinUZI = 1,
    SkinEnable_Groza = 0, SkinGroza = 1,
    SkinEnable_S12K = 0, SkinS12K = 1,
    SkinEnable_DBS = 0, SkinDBS = 1,
    SkinEnable_Dacia = 0, SkinDacia = 1,
    SkinEnable_UAZ = 0, SkinUAZ = 1,
    SkinEnable_Coupe = 0, SkinCoupe = 1,
    SkinEnable_Buggy = 0, SkinBuggy = 1,
    SkinEnable_Mirado = 0, SkinMirado = 1,
    WeaponGlow = 0,
    WeaponGlowColor = 5,
    WeaponGlowThickness = 3,
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

_G.LexusConfig = _G.LexusConfig or {}
setmetatable(_G.LexusConfig, {
    __index = function(_, key)
        local val = _G.HK_Settings[key]
        if val == nil then return false end
        return val == 1
    end,
    __newindex = function(_, key, val)
        if type(val) == "boolean" then
            _G.HK_Settings[key] = val and 1 or 0
        else
            _G.HK_Settings[key] = val
        end
    end
})

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

        local StackSkin = {
            { UI = AliasMap.Title, Text = "MOD SKIN & HIỆU ỨNG" },
            { Key = "ModMenu_ModEmote", UI = AliasMap.TitleSwitcher or "TitleSwitcher", Text = "Mở Khóa Full Hành Động VIP (Emotes) Mở Trong Trận", GetFunc = function() return _G.HK_Settings.ModEmote == 1 end, SetFunc = function(_,v) _G.HK_Settings.ModEmote = v and 1 or 0 return true end },
            { Key = "ModMenu_ModSkin", UI = AliasMap.TitleSwitcher or "TitleSwitcher", Text = "Hệ thống Mod Skin Mới Nếu Bị Ban Mở Hwid Còn Ban Nữa Tắt Mẹ Đi MỞ TÚI ĐỒ TRONG GAME ĐỂ CHỌN", GetFunc = function() return _G.HK_Settings.ModSkin == 1 end, SetFunc = function(_,v) _G.HK_Settings.ModSkin = v and 1 or 0; _G.EnvRequiresUpdate = true; if _G.Lobby_ForceRefreshSkins then pcall(_G.Lobby_ForceRefreshSkins) end return true end },
            { Key = "ModMenu_SkinDeadBox", UI = AliasMap.TitleSwitcher or "TitleSwitcher", Text = "Skin Hòm Xác (Ăn theo skin Súng/Xe) Rất Lag Máy Yếu Không Nên Bật ", GetFunc = function() return _G.HK_Settings.SkinDeadBox == 1 end, SetFunc = function(_,v) _G.HK_Settings.SkinDeadBox = v and 1 or 0 return true end },
            { Key = "ModMenu_SkinAttachment", UI = AliasMap.TitleSwitcher or "TitleSwitcher", Text = "Skin Phụ Kiện Súng (Nòng, Tay cầm, Băng đạn) Tắt Sẽ Mượt Hơn Nữa ( mở trong trận thì trận sau mới có skin phụ kiện )", GetFunc = function() return _G.HK_Settings.SkinAttachment == 1 end, SetFunc = function(_,v) _G.HK_Settings.SkinAttachment = v and 1 or 0 return true end },
            { Key = "ModMenu_KillMessage", UI = AliasMap.TitleSwitcher or "TitleSwitcher", Text = "Kill Messenger (Thông báo hạ gục VIP) Tăt Đi Sẽ Mượt Hơn", GetFunc = function() return _G.HK_Settings.KillMessage == 1 end, SetFunc = function(_,v) _G.HK_Settings.KillMessage = v and 1 or 0 return true end },
            { Key = "ModMenu_KillCountUI", UI = AliasMap.TitleSwitcher or "TitleSwitcher", Text = "Bộ Đếm Kill (Hiển thị số Kill vũ khí) Tắt Đi Sẽ Mượt Hơn", GetFunc = function() return _G.HK_Settings.KillCountUI == 1 end, SetFunc = function(_,v) _G.HK_Settings.KillCountUI = v and 1 or 0 return true end },
            { Key = "ModMenu_SkinOpenLink", UI = AliasMap.TitleSwitcher or "TitleSwitcher", Text = "Mod Skin Mũ Thì Bấm Cái Mũ Level 1 Xong Tháo Ra Là Hoạt Động Còn Skin Balo Trang Bị Balo 1 Là Hoạt Động ", GetFunc = function() return _G.HK_Settings.SkinOpenLink == 1 end, SetFunc = function(_,v) _G.HK_Settings.SkinOpenLink = v and 1 or 0; if v == true then pcall(function() local Web = require("client.slua.logic.url.logic_webview_sdk"); if Web and Web.OpenURL then Web:OpenURL("https://t.me/dung0610") end end) end return true end },
        }
        
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
                { Key = "ModMenu_Cat2", loc = "SKIN", text = "SKIN", Text = "SKIN", title = "SKIN", Title = "SKIN", Stack = StackSkin },
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

-- =========================== PHẦN 28B: MOD SKIN & EFFECTS SYSTEMS ===========================
-- ==============================================================================
-- ================= DATA & LOGIKA MOD SKIN =====================================
-- ==============================================================================
_G.VIP_Attachments = {
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

_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

_G.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.VipAttachToIndex[attachId] = index
        end
    end
end

_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.skinIdCache = _G.skinIdCache or {}
_G.skinIdCache2 = _G.skinIdCache2 or {}

_G.OutfitSkins = {
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

_G.skinIdMappings = {
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

_G.VehicleSkins = { 
    [1961001] = { 1961007, 1961010, 1961012, 1961013, 1961014, 1961015, 1961016, 1961017, 1961018, 1961020, 1961021, 1961024, 1961025, 1961029, 1961030, 1961031, 1961032, 1961033, 1961034, 1961035, 1961036, 1961037, 1961038, 1961039, 1961040, 1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047, 1961048, 1961049, 1961050, 1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057, 1961058, 1961059, 1961060, 1961061, 1961062, 1961063, 1961064, 1961065, 1961066, 1961067, 1961068, 1961069, 1961136, 1961137, 1961138, 1961139, 1961140, 1961141, 1961142, 1961143, 1961144, 1961145, 1961147, 1961148, 1961149, 1961150, 1961151, 1961152, 1961153 },
    [1903001] = { 1903005, 1903006, 1903007, 1903008, 1903011, 1903012, 1903013, 1903014, 1903015, 1903016, 1903017, 1903018, 1903019, 1903020, 1903021, 1903022, 1903023, 1903024, 1903029, 1903030, 1903031, 1903032, 1903033, 1903034, 1903035, 1903036, 1903037, 1903039, 1903040, 1903041, 1903042, 1903043, 1903044, 1903045, 1903046, 1903051, 1903052, 1903053, 1903054, 1903055, 1903056, 1903057, 1903058, 1903059, 1903060, 1903061, 1903062, 1903063, 1903066, 1903067, 1903068, 1903069, 1903070, 1903071, 1903072, 1903073, 1903074, 1903075, 1903076, 1903079, 1903080, 1903081, 1903082, 1903084, 1903085, 1903086, 1903087, 1903088, 1903089, 1903090, 1903189, 1903190, 1903191, 1903192, 1903193, 1903194, 1903195, 1903196, 1903197, 1903198, 1903199, 1903200, 1903201, 1903202, 1903203, 1903204, 1903205, 1903206, 1903207, 1903208, 1903209, 1903210, 1903211, 1903212, 1903213, 1903214, 1903215, 1903216, 1903217, 1903218, 1903219, 1903220, 1903221, 1903222, 1903223, 1903225, 1903226, 1903227, 1903228 }, 
    [1915001] = { 1915002, 1915003, 1915004, 1915005, 1915006, 1915007, 1915008, 1915009, 1915010, 1915011, 1915012, 1915013, 1915014, 1915015, 1915016, 1915017, 1915018, 1915019, 1915020, 1915021, 1915022, 1915023, 1915024, 1915025, 1915026, 1915027, 1915099 },          
    [1908001] = { 1908002, 1908003, 1908005, 1908006, 1908007, 1908008, 1908009, 1908010, 1908011, 1908012, 1908013, 1908015, 1908016, 1908017, 1908018, 1908019, 1908021, 1908023, 1908030, 1908031, 1908032, 1908033, 1908034, 1908035, 1908036, 1908037, 1908039, 1908040, 1908041, 1908043, 1908047, 1908049, 1908050, 1908051, 1908052, 1908053, 1908054, 1908055, 1908056, 1908057, 1908059, 1908060, 1908061, 1908062, 1908063, 1908064, 1908066, 1908067, 1908068, 1908069, 1908070, 1908075, 1908076, 1908077, 1908078, 1908080, 1908081, 1908082, 1908083, 1908084, 1908085, 1908086, 1908087, 1908088, 1908089, 1908091, 1908094, 1908095, 1908096, 1908097, 1908098, 1908099, 1908100, 1908101, 1908102, 1908104, 1908105, 1908106, 1908107, 1908108, 1908109, 1908110, 1908111, 1908112, 1908188, 1908189 },   
    [1907001] = { 1907007, 1907008, 1907010, 1907011, 1907012, 1907013, 1907014, 1907016, 1907018, 1907019, 1907021, 1907022, 1907023, 1907025, 1907026, 1907027, 1907028, 1907029, 1907030, 1907032, 1907033, 1907034, 1907035, 1907036, 1907037, 1907038, 1907040, 1907041, 1907043, 1907044, 1907045, 1907046, 1907047, 1907048, 1907049, 1907050, 1907051, 1907052, 1907053, 1907054, 1907055, 1907056, 1907058, 1907059, 1907060, 1907061, 1907062, 1907063, 1907064, 1907065, 1907066, 1907067, 1907068, 1907069, 1907070, 1907071, 1907072, 1907073, 1907074 }
}
_G.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

local function DownloadGameItem(id)
    local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
    local puffer_const = require('client.slua.logic.download.puffer_const')
    if puffer_manager and puffer_const and puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
        puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
    end
end
_G.download_item = DownloadGameItem

_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.skinIdCache2[targetSkinId] then
            if _G.download_item then pcall(_G.download_item, targetSkinId) end
            _G.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

_G.equip_character_avatar = function(Character)
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

            if not _G.skinIdCache[applyItemId] then
                if _G.download_item then pcall(_G.download_item, applyItemId) end
                _G.skinIdCache[applyItemId] = true
            end

            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end

    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then 
            hasGliderSlot = true
            break 
        end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end

    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.OutfitMap.Suit or 0, _G.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.OutfitMap.Bag, _G.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.OutfitMap.Helmet, _G.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.OutfitMap.Parachute or 0, _G.CustSlotType.ParachuteEquipemtSlot, false)
    end
end

_G.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end
        
        for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.get_skin_id(WeaponID) or WeaponID
                local isModified = false
                
                local SkinData = Weapon.synData:Get(7) 
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.skinIdCache[SkinID] then 
                        _G.download_item(SkinID)
                        _G.skinIdCache[SkinID] = true 
                    end
                    isModified = true
                end
                
                if SkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do 
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.skinIdCache2[targetAttachId] then 
                                                if _G.download_item then pcall(_G.download_item, targetAttachId) end
                                                _G.skinIdCache2[targetAttachId] = true 
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

_G.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = PlayerCharacter:GetCurrentVehicle()
        if not slua.isValid(Vehicle) then 
            _G.LastVehicleEntity = nil
            return 
        end
        
        if _G.LastVehicleEntity == Vehicle and _G.CurrentEquipVehicleID ~= nil then
            return
        end

        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
        if not slua.isValid(VehicleAvatar) then return end

        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = tostring(Vehicle:GetAvatarId() or "")
        local applySkinId = 0
        
        for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then 
                applySkinId = targetSkin
                break 
            end
        end

        if applySkinId and applySkinId > 0 then
            _G.skinIdCache = _G.skinIdCache or {}
            if not _G.skinIdCache[applySkinId] then 
                if _G.download_item then pcall(_G.download_item, applySkinId) end
                _G.skinIdCache[applySkinId] = true 
            end

            VehicleAvatar.curSwitchEffectId = 7303001
            if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(applySkinId, true) end
            
            _G.CurrentEquipVehicleID = applySkinId
            _G.LastVehicleEntity = Vehicle
        end
    end)
end

_G.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.LastAppliedPet then return end
        
        _G.skinIdCache = _G.skinIdCache or {}
        if not _G.skinIdCache[petSkin] then 
            if _G.download_item then pcall(_G.download_item, petSkin) end
            _G.skinIdCache[petSkin] = true 
        end
        
        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.LastAppliedPet = petSkin
    end)
end

_G.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.LexusState or not _G.LexusState.CustomTextData then return end
        local cData = _G.LexusState.CustomTextData

        if _G.OutfitSkins then
            if cData.SkinSuit and _G.OutfitSkins.Suit[cData.SkinSuit] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.OutfitSkins.Bag[cData.SkinBag] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.OutfitSkins.Helmet[cData.SkinHelmet] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[cData.SkinHelmet] end
        end

        if _G.skinIdMappings then
            if cData.SkinM416 and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][cData.SkinM416] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][cData.SkinAKM] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][cData.SkinSCAR] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][cData.SkinM762] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][cData.SkinAUG] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP] end
            
            if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][cData.SkinS12K] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][cData.SkinDBS] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][cData.SkinDBS] end
        end

        if _G.VehicleSkins then
            if cData.SkinDacia and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][cData.SkinDacia] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][cData.SkinUAZ] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][cData.SkinCoupe] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][cData.SkinBuggy] then _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][cData.SkinBuggy] end
            if cData.SkinMirado and _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][cData.SkinMirado] then _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][cData.SkinMirado] end
        end
    end)
end

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    if not _G.CachedActorArray then
        _G.CachedActorArray = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray)
    
    for _, deadBoxActor in pairs(deadBoxes) do
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    local currentBoxSkinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                        currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
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
_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_UI_Manager = nil

_G.ForceEnableKillCounterUI = function()
    pcall(function()
        local KillCounterUISubsystem = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUISubsystem and KillCounterUISubsystem.__inner_impl and not _G.KCUISystemHacked2 then
            local kcImpl = KillCounterUISubsystem.__inner_impl
            kcImpl.CheckSupportKCUI = function() return true end
            kcImpl.CheckNeedMainKillCounterUI = function(self, PlayerWeapon, PlayerID)
                if slua.isValid(PlayerWeapon) then
                    local WeaponID = PlayerWeapon:GetWeaponID()
                    self:UpdateMainKillCounterUI(true, WeaponID, _G.get_skin_id(WeaponID) or WeaponID)
                else self:UpdateMainKillCounterUI(false) end
            end
            local originalUpdateMainKillCounterUI = kcImpl.UpdateMainKillCounterUI
            kcImpl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                if bShow then AvatarID = _G.get_skin_id(WeaponID) or AvatarID end
                if originalUpdateMainKillCounterUI then originalUpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID) end
            end
            _G.KCUISystemHacked2 = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager and not _G.KCLogicHacked2 then
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if LogicKillCounter then
                LogicKillCounter.CheckSupportKC = function() return true end
                LogicKillCounter.CheckSupportKillCounterAvatar = function() return true end
                LogicKillCounter.CheckHasWeaponKillCounter = function() return true end
                LogicKillCounter.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                LogicKillCounter.GetEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetMyEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetOneWeaponKillCountInBattle = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                LogicKillCounter.GetWeaponKillCountByUid = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                _G.KCLogicHacked2 = true
            end
        end

        local ESlateVisibility = import("ESlateVisibility")
        local SwitchModes = {
            "GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode1",
            "GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2",
            "GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode3",
            "GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotBase"
        }
        for _, modePath in ipairs(SwitchModes) do
            local s, mode = pcall(require, modePath)
            if s and mode and mode.__inner_impl and not mode.__inner_impl._KCIconHidden then
                mode.__inner_impl.CheckShowKCIcon = function(self)
                    if slua.isValid(self.KillCounterImg) then 
                        self.KillCounterImg:SetVisibility(ESlateVisibility.Collapsed) 
                    end
                    if slua.isValid(self.KillCounterText) then 
                        self.KillCounterText:SetVisibility(ESlateVisibility.Collapsed) 
                    end
                end
                mode.__inner_impl._KCIconHidden = true
            end
        end
    end)
end

_G.ForceEnableKillMessage = function()
    pcall(function()
        local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
        local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
        
        if KillInfo and KillInfo.__inner_impl and not _G.KillMessageHacked then
            local originalFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then 
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id(weaponID)
                            
                            if _G.HK_GetVal("KillMessageEnable") == 1 then
                                if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                                if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit end
                            end

                            if DamageRecordData.ResultHealthStatus == 2 then 
                                _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                                
                                if not CACHED_UI_Manager then CACHED_UI_Manager = require("client.slua_ui_framework.manager") end
                                local uiMainKillCounter = CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)
                                
                                if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                                    local mainAvatarID = skinID or currentWeapon:GetWeaponMainAvatarID()
                                    uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                                    
                                    local ModuleManager = require("client.module_framework.ModuleManager")
                                    if ModuleManager then
                                        local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                                        if kcModule then
                                            local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                                            uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
                
                if originalFileItem then return originalFileItem(self, DamageRecordData) end
            end
            _G.KillMessageHacked = true
        end
    end)
end

_G.Lobby_ForceRefreshSkins = function()
    pcall(function()
        local selfUID = nil
        local TeamUpNewSystem = package.loaded["client.logic.team.TeamUpNewSystem"] or require("client.logic.team.TeamUpNewSystem")
        if TeamUpNewSystem and TeamUpNewSystem.GetSelfUID then selfUID = TeamUpNewSystem.GetSelfUID() end
        if not selfUID and _G.DataMgr and _G.DataMgr.roleData then selfUID = _G.DataMgr.roleData.uid end
        
        if selfUID then
            local TeamAvatarManager = package.loaded["client.logic.avatar.logic_team_avatar_manager"] or require("client.logic.avatar.logic_team_avatar_manager")
            if TeamAvatarManager and TeamAvatarManager.GetAvatarByUid then
                local avatar = TeamAvatarManager.GetAvatarByUid(selfUID)
                if avatar and avatar.GetEquipments and avatar.PutonEquipment then
                    _G.ForceRefreshSkinMaps()
                    local equipments = avatar:GetEquipments()
                    local count = type(equipments.Num) == "function" and equipments:Num() or #equipments
                    for i = 1, count do
                        local equip = type(equipments.Get) == "function" and equipments:Get(i-1) or equipments[i]
                        if equip and equip.itemID then
                            avatar:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                    if _G.HK_GetVal("SkinEnable_Suit") == 1 and _G.OutfitMap.Suit and _G.OutfitMap.Suit > 0 then
                        avatar:PutonEquipment(_G.OutfitMap.Suit, nil, nil)
                    end
                end
            end
        end
    end)
function _G.InitializeSkinModSystem()
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.LobbyBypassHacked then
            local originalPutonEquipment = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if attachIndex then
                    local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[holdingWeaponSkinID] then
                        local vipAttachID = _G.VIP_Attachments[holdingWeaponSkinID][attachIndex]
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
                        if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return retValue
            end
            _G.LobbyBypassHacked = true
        end
    end)
    
    pcall(function()
        local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if Common_Items_UIBP and not _G.IconBaloHacked then
        local originalInitView = Common_Items_UIBP.InitView
            Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displayResId = nil
                
                if _G.get_skin_id then
                    local skinID = _G.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then displayResId = skinID end
                end
                
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                if not displayResId and attachIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) then
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local finalSkinID = _G.get_skin_id(weaponID) or weaponID
                            if finalSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[finalSkinID] then
                                local vipAttachID = _G.VIP_Attachments[finalSkinID][attachIndex]
                                if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                            end
                        end
                    end
                end
                
                if displayResId then
                    tExtraData.displayResId = displayResId
                    if not _G.skinIdCache2[displayResId] then
                        if _G.download_item then pcall(_G.download_item, displayResId) end
                        _G.skinIdCache2[displayResId] = true
                    end
                end
                if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
            end
            _G.IconBaloHacked = true
        end
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
    if pawn.HK_IsAICached ~= nil then return pawn.HK_IsAICached end
    
    local isAI = false
    local hasChecked = false
    
    pcall(function()
        if pawn.bEnsure ~= nil then
            isAI = pawn.bEnsure
            hasChecked = true
        elseif type(pawn.GetMEnsure) == "function" then
            isAI = pawn:GetMEnsure()
            hasChecked = true
        end

        if not isAI or not hasChecked then
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
        local isModSkinOn = (_G.HK_GetVal("ModSkin") == 1)

        if not _G.TDModTickCount then _G.TDModTickCount = 0 end
        if not _G.MagicUpdateVersion then _G.MagicUpdateVersion = 1 end
        if _G.EnvRequiresUpdate == nil then _G.EnvRequiresUpdate = true end

        _G.TDModTickCount = _G.TDModTickCount + 1

        -- Cập nhật định kỳ Mod Skin mỗi 1.5 giây (khoảng 6 ticks ở chu kỳ 0.25s) và phát sáng súng mỗi 0.5 giây (2 ticks)
        if isModSkinOn then
            if not self.bHasInitializedSkinMod then
                self.bHasInitializedSkinMod = true
                pcall(function()
                    _G.InitializeSkinModSystem()
                    _G.ForceEnableKillCounterUI()
                    _G.ForceEnableKillMessage()
                    _G.ForceRefreshSkinMaps()
                end)
            end
            
            if _G.TDModTickCount % 6 == 0 then
                pcall(function()
                    _G.ForceRefreshSkinMaps()
                    _G.equip_character_avatar(LocalPlayer)
                    _G.ApplyWeaponSkins(LocalPlayer)
                    _G.ApplyVehicleSkins(LocalPlayer)
                    _G.HandlePetLogic()
                end)
            end

            if _G.TDModTickCount % 2 == 0 then
                pcall(function()
                    _G.ApplyWeaponGlow(LocalPlayer)
                end)
            end

            if _G.HK_GetVal("SkinDeadBox") == 1 then
                pcall(function()
                    _G.NeedCheckDeadBoxTimer = 15
                    local controller = GameplayData.GetPlayerController()
                    if slua_isValid(controller) then
                        _G.DeadBox_TemperRequest(controller)
                    end
                end)
            end
        else
            if self.bHasInitializedSkinMod then
                self.bHasInitializedSkinMod = nil
                -- Restore defaults
                pcall(function()
                    _G.OutfitMap = {}
                    _G.WeaponSkinMap = {}
                    _G.VehicleSkinMap = {}
                    _G.equip_character_avatar(LocalPlayer)
                    _G.ApplyWeaponSkins(LocalPlayer)
                    _G.ApplyWeaponGlow(LocalPlayer)
                end)
            end
        end
 
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