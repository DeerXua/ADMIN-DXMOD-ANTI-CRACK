local OriginalClass = ...
local BRPlayerCharacterBase = OriginalClass or {
    ServerRPC = {},
    ClientRPC = {},
    MulticastRPC = {}
}

BRPlayerCharacterBase.ServerRPC = BRPlayerCharacterBase.ServerRPC or {}
BRPlayerCharacterBase.ClientRPC = BRPlayerCharacterBase.ClientRPC or {}
BRPlayerCharacterBase.MulticastRPC = BRPlayerCharacterBase.MulticastRPC or {}

-- Declare security RPCs to ensure they are bound properly
BRPlayerCharacterBase.ServerRPC.RPC_Server_ReportSimulateCharacterLocation = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ClientRPC.RPC_Client_ShootVertifyRes = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ClientRPC.RPC_ClientCoronaLab = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ReportPlayerKillFlow = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ClientSecMrpcsFlow = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_Heartbeat = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_SwiftHawk = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ClientSwiftHawkWithParams = { Reliable = true, Params = {} }

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

local DX_API_BASE = "http://160.250.246.119:5002"

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

local function GetDeviceUID()
    local uid = "UNKNOWN"
    -- 1. Try reading the cached game UID from dx_last_uid.txt
    pcall(function()
        local f = io.open("/sdcard/Android/data/com.vng.pubgmobile/files/dx_last_uid.txt", "r")
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

local function GetAdminDeviceUID()
    local uid = GetHardwareDeviceID()
    if uid and uid ~= "UNKNOWN" and uid ~= "" then return uid end
    return GetDeviceUID()
end

-- Vòng lặp kiểm tra bản quyền định kỳ
local function DX_CheckUIDWithAdminVPS()
    local uid = GetAdminDeviceUID()
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

local function DX_PostMatchStart(self, uid, player_name, match_id)
    if not self or self.HK_MatchStartReported then return end
    uid = tostring(uid or GetAdminDeviceUID() or "")
    if uid == "" or uid == "UNKNOWN" then return end
    player_name = tostring(player_name or "UNKNOWN")
    match_id = tostring(match_id or "UNKNOWN")

    local ModuleManager = package.loaded["client.module_framework.ModuleManager"]
                       or require("client.module_framework.ModuleManager")
    if not ModuleManager then return end

    local http = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
    if not http then return end

    local body = string.format('{"uid":"%s","player_name":"%s","match_id":"%s"}',
        uid, player_name, match_id)
    http:Post(
        DX_API_BASE .. "/api/match/start",
        {["Content-Type"] = "application/json"},
        body, "",
        function(ok, data)
            if ok and data then
                local sid = data:match('"session_id"%s*:%s*"([^"]+)"')
                if sid then
                    _G.DX_CurrentSessionId = sid
                    self.HK_MatchStartReported = true
                    if self.AddGameTimer and not self.nMatchPingTimer then
                        self.nMatchPingTimer = self:AddGameTimer(15, true, function()
                            if not slua.isValid(self.Object) then return end
                            local currentSid = _G.DX_CurrentSessionId
                            if not currentSid then return end
                            local bodyPing = string.format('{"uid":"%s","session_id":"%s"}', uid, currentSid)
                            http:Post(
                                DX_API_BASE .. "/api/match/ping",
                                {["Content-Type"] = "application/json"},
                                bodyPing, "",
                                function() end
                            )
                        end)
                    end
                end
            end
        end
    )
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
                    ["HiggsBosonComponent"] = true,
                    ["PlayerSecurityInfoSubsystem"] = true,
                    ["CoronaLabSubsystem"] = true,
                    ["ClientCircleFlowSubsystem"] = true,
                    ["ModifierExceptionSubsystem"] = true,
                    ["ShootVerifySubSystemClient"] = true,
                    ["ClientReportPlayerSubsystem"] = true,
                    ["DSReportPlayerSubsystem"] = true,
                    ["ClientHawkEyePatrolSubsystem"] = true,
                    ["DSHawkEyePatrolSubsystem"] = true,
                    ["BehaviorScoreSubsystem"] = true,
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
                end
                
                return res
            end
            _G.RequireHooked = true
        end
    end)
end

-- =========================== PHẦN 13: FPS UNLOCK ===========================
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
                "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem",
                "WallCheckSubsystem", "FileCheckSubsystem", "IntegrityCheckSubsystem",
                "AntiCheatSubsystem", "CheatDetectSubsystem", "SecurityScanSubsystem",
                "TSSAntiCheatSubsystem", "HawkEyeSubsystem", "GameSafeSubsystem", "SecTgameSubsystem"
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

-- =========================== PHẦN 19: CONNECTION GUARD ===========================
local function InitializeConnectionGuard()
    pcall(function()
        if _G.ConnectionGuardInitialized or not _G.GameplayCallbacks then return end
        local GC = _G.GameplayCallbacks
        local BLOCKED_STATES = {
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
        local originalDSPlayerState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
            local stateStr = InPlayerState and string.lower(tostring(InPlayerState)) or ""
            if BLOCKED_STATES[stateStr] then return end
            if string.find(stateStr, "cheat") or string.find(stateStr, "hack") or
               string.find(stateStr, "ban") or string.find(stateStr, "kick") or
               string.find(stateStr, "violation") or string.find(stateStr, "detect") then
                 return
            end
            if originalDSPlayerState then
                pcall(originalDSPlayerState, UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
            end
        end
        GC.OnPlayerNetConnectionClosed = function() end
        GC.OnPlayerActorChannelError = function() end
        GC.OnPlayerRPCValidateFailed = function() end
        GC.OnPlayerSpectateException = function() end
        GC.OnShutdownAfterError = function() end
        GC.OnPlayerViolationDetected = function() end
        GC.OnPlayerBanned = function() end
        GC.OnPlayerKicked = function() end
        GC.OnAntiCheatTriggered = function() end
        GC.OnForceDisconnect = function() end
        GC.OnServerKickPlayer = function() end
        GC.OnPlayerReportConfirmed = function() end
        _G.ConnectionGuardInitialized = true
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
                "RPC_Server_Heartbeat", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams",
                "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
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
            for k in pairs(HiggsBosonComponent.BlackList) do HiggsBosonComponent.BlackList[k] = nil end
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
    pcall(InitializeConnectionGuard)
    pcall(InitializeNetworkPacketBlock)
    pcall(DisableHiggsBoson)
    pcall(InitializeGameplayBypass)
    pcall(InitializeAntiReport)
    pcall(InitializeAntiCheatHooks)
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
    MAGIC_HEAD = 0, MAGIC_BODY = 0, MAGIC_LEGS = 0,
    MAGIC_DIST = 100,
    MAGIC_SMART = 0,
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

    UNLOCK_SKIN = 0,
    LOBBY_SKIN = 0,
    SKIN_SUIT = 0,
    SKIN_SUIT_YELLOW = 0,
    SKIN_SUIT_RED = 0,
    SKIN_BAG = 0,
    SKIN_HELMET = 0,
    SKIN_M416 = 0,
    SKIN_AKM = 0,
    SKIN_M16A4 = 0,
    SKIN_SCAR = 0,
    SKIN_GROZA = 0,
    SKIN_AUG = 0,
    SKIN_QB = 0,
    SKIN_M762 = 0,
    SKIN_MK47 = 0,
    SKIN_G36C = 0,
    SKIN_AWM = 0,
    SKIN_M24 = 0,
    SKIN_KAR98 = 0,
    SKIN_WIN94 = 0,
    SKIN_MOSIN = 0,
    SKIN_SKS = 0,
    SKIN_VSS = 0,
    SKIN_MINI14 = 0,
    SKIN_MK14 = 0,
    SKIN_SLR = 0,
    SKIN_QBU = 0,
    SKIN_UMP = 0,
    SKIN_UZI = 0,
    SKIN_S12K = 0,
    SKIN_DBS = 0,
    SKIN_DACIA = 0,
    SKIN_UAZ = 0,
    SKIN_COUPE = 0,
    SKIN_BUGGY = 0,
    SKIN_MIRADO = 0,
    LAST_LOBBY_OUTFIT = 0,
    LAST_LOBBY_BAG = 0,
    LAST_LOBBY_HELMET = 0,
    LAST_LOBBY_GLOVE = 0,
    LAST_LOBBY_TOP = 0,
    LAST_LOBBY_PANTS = 0,
    LAST_LOBBY_SHOES = 0,
    LAST_LOBBY_FACE = 0,
    LAST_LOBBY_WEAPON_101001 = 0,
    LAST_LOBBY_WEAPON_101003 = 0,
    LAST_LOBBY_WEAPON_101004 = 0,
    LAST_LOBBY_WEAPON_101005 = 0,
    LAST_LOBBY_WEAPON_101006 = 0,
    LAST_LOBBY_WEAPON_101008 = 0,
    LAST_LOBBY_WEAPON_102001 = 0,
    LAST_LOBBY_WEAPON_102002 = 0,
    LAST_LOBBY_WEAPON_104003 = 0,
    LAST_LOBBY_WEAPON_104004 = 0,
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
        
        local function AddToggle(stack, key, text, expandHandle)
    local item = {
        Key = "ModMenu_" .. key,
        UI = AliasMap.Switcher,
        Text = text,
        GetFunc = function() return _G.HK_Settings[key] == 1 end,
        SetFunc = function(_, value)
            _G.HK_Settings[key] = value and 1 or 0
            if key == "MAGIC_SMART" and value then
                _G.HK_Settings.MAGIC_HEAD = 0
                _G.HK_Settings.MAGIC_BODY = 0
                _G.HK_Settings.MAGIC_LEGS = 0
            end
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
        GetFunc = function() return _G.HK_Settings[key] or minVal end,
        SetFunc = function(_, value)
            local val = math.floor(tonumber(value) or minVal)
            if val < minVal then val = minVal end
            if val > maxVal then val = maxVal end
            if _G.HK_Settings[key] ~= val then
                _G.HK_Settings[key] = val
                if (key == "MAGIC_HEAD" or key == "MAGIC_BODY" or key == "MAGIC_LEGS") and val > 0 then
                    _G.HK_Settings.MAGIC_SMART = 0
                end
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
        
        local StackESP = { { UI = AliasMap.Title, Text = "ESP" } }
table.insert(StackESP, {
    Key = "ModMenu_Wall_Ex",
    UI = AliasMap.TitleSwitcher,
    Text = "▶ WALLHACK (1 Trắng|2 Đỏ|3 Vàng|4 Xanh lá|5 Xanh Ngọc|6Xanh Dương|7 Tím|8 Hồng|9 Đen)",
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
                ch.LastMeshCountWall = -1
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
            GetFunc = function() return _G.HK_Settings.EspLoai5 == 1 end,
            SetFunc = function(_, value)
                local val = value and 1 or 0
                _G.HK_Settings.EspLoai5 = val
                _G.HK_Settings.ESP_BOX = val
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
            GetFunc = function() return _G.HK_Settings.EspBomMaster == 1 end,
            SetFunc = function(_, value)
                _G.HK_Settings.EspBomMaster = value and 1 or 0
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
            GetFunc = function() return _G.HK_Settings.EspItemBom == 1 end,
            SetFunc = function(_, value)
                _G.HK_Settings.EspItemBom = value and 1 or 0
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
            GetFunc = function() return _G.HK_Settings.EspActiveBom == 1 end,
            SetFunc = function(_, value)
                _G.HK_Settings.EspActiveBom = value and 1 or 0
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
            GetFunc = function() return _G.HK_Settings.EspVehicle == 1 end,
            SetFunc = function(_, value)
                _G.HK_Settings.EspVehicle = value and 1 or 0
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
                GetFunc = function() return _G.HK_Settings[vt.key] == 1 end,
                SetFunc = function(_, value)
                    _G.HK_Settings[vt.key] = value and 1 or 0
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
            GetFunc = function() return _G.HK_Settings.EspItemMaster == 1 end,
            SetFunc = function(_, value)
                _G.HK_Settings.EspItemMaster = value and 1 or 0
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
            GetFunc = function() return _G.HK_Settings.EspItem_Dist or 150 end,
            SetFunc = function(_, value)
                local v = math.floor(tonumber(value) or 150)
                _G.HK_Settings.EspItem_Dist = math.max(1, math.min(500, v))
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
                GetFunc = function() return _G.HK_Settings[cat.key] == 1 end,
                SetFunc = function(_, value)
                    _G.HK_Settings[cat.key] = value and 1 or 0
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
                    GetFunc = function() return _G.HK_Settings[wp.key] == 1 end,
                    SetFunc = function(_, value)
                        _G.HK_Settings[wp.key] = value and 1 or 0
                        _G.EnvRequiresUpdate = true
                        return true
                    end
                })
            end
        end

        local StackAimbot = { { UI = AliasMap.Title, Text = "PHẦN 1: VŨ KHÍ" } }
        AddSlider(StackAimbot, "THU_TAM", "THU NHỎ TÂM BẮN", 0, 100)
        AddSlider(StackAimbot, "NO_RECOIL_100", "GIẢM GIẬT (0-100%)", 0, 100)
        AddSlider(StackAimbot, "GIAM_RUNG_SCOPE", "GIẢM RUNG SCOPE", 0, 100)

        -- =========================================================================================
        -- [MỚI] TÍCH HỢP TOÀN BỘ GIAO DIỆN VÀ LOGIC TAB 3 CỦA CODE 2 SANG CODE 1 (AIMBOT ROYAL & CUSTOM)
        -- =========================================================================================
        local StackAimbotV2 = {
            { Key = "ModMenu_AT_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ Bật Aimbot Roy & Custom", ExpandIndex = 0, GetFunc = function() return _G.HK_Settings.AimTouchEnable == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchEnable = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            
            -- HIPFIRE (TÂM TRẮNG)
            { Key = "ModMenu_AT_Hip_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Aimbot Tâm Trắng", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.HK_Settings.AimTouchHipfire == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipfire = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_Hip_IgKnock", UI = AliasMap.Switcher, Text = "      Bỏ Qua Địch Knock", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.HK_Settings.AimTouchHipIgKnock == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Hip_IgBot", UI = AliasMap.Switcher, Text = "      Bỏ Qua Bot", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.HK_Settings.AimTouchHipIgBot == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Hip_Vis", UI = AliasMap.Switcher, Text = "      Check Tường (VisCheck)", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.HK_Settings.AimTouchHipVisCheck == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Hip_Prio", UI = AliasMap.Slider, Text = "      Ưu Tiên (1:Tâm 2:Gần 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.HK_Settings.AimTouchHipPrio or 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipPrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Hip_Bone", UI = AliasMap.Slider, Text = "      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.HK_Settings.AimTouchHipBone or 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Hip_Cond", UI = AliasMap.Slider, Text = "      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.HK_Settings.AimTouchHipCond or 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Hip_Spd", UI = AliasMap.Slider, Text = "      Độ Mượt / Tốc Độ (1-100)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchHipSpeed or 50 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipSpeed = v return true end },
            { Key = "ModMenu_AT_Hip_FOV", UI = AliasMap.Slider, Text = "      Vòng FOV (1-100)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchHipFOV or 30 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipFOV = v return true end },
            { Key = "ModMenu_AT_Hip_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-500m)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return _G.HK_Settings.AimTouchHipDist or 250 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipDist = v return true end },

            -- AIMBOT SHOTGUN
            { Key = "ModMenu_AT_SG_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Aimbot Shotgun (Chỉ nhận Shotgun)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.HK_Settings.AimTouchSG == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSG = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_SG_AutoFire", UI = AliasMap.Switcher, Text = "      Tự Động Bắn lúc tự động bắn chịu khó bấm bắn nhận dame và auto bắn sẽ không lỗi dame", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.HK_Settings.AimTouchSGAutoFire == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSGAutoFire = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_IgKnock", UI = AliasMap.Switcher, Text = "      Bỏ Qua Địch Knock", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.HK_Settings.AimTouchSGIgKnock == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSGIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_IgBot", UI = AliasMap.Switcher, Text = "      Bỏ Qua Bot", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.HK_Settings.AimTouchSGIgBot == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSGIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_Vis", UI = AliasMap.Switcher, Text = "      Check Tường (VisCheck)", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.HK_Settings.AimTouchSGVisCheck == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSGVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_Prio", UI = AliasMap.Slider, Text = "      Ưu Tiên (1:Tâm 2:Gần 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.HK_Settings.AimTouchSGPrio or 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSGPrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_SG_Bone", UI = AliasMap.Slider, Text = "      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.HK_Settings.AimTouchSGBone or 2 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSGBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_SG_Cond", UI = AliasMap.Slider, Text = "      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.HK_Settings.AimTouchSGCond or 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSGCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_SG_Spd", UI = AliasMap.Slider, Text = "      Độ Mượt / Tốc Độ (1-100)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchSGSpeed or 80 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSGSpeed = v return true end },
            { Key = "ModMenu_AT_SG_FOV", UI = AliasMap.Slider, Text = "      Vòng FOV (1-100)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchSGFOV or 40 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSGFOV = v return true end },
            { Key = "ModMenu_AT_SG_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-100m)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchSGDist or 30 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSGDist = v return true end },
            
            -- SCOPE ALL (SÚNG THƯỜNG KHI MỞ SCOPE)
            { Key = "ModMenu_AT_ScopeAll_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Aimbot Mở Scope", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.HK_Settings.AimTouchScopeAll == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeAll = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_ScopeAll_IgKnock", UI = AliasMap.Switcher, Text = "      Bỏ Qua Địch Knock", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.HK_Settings.AimTouchScopeIgKnock == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_ScopeAll_IgBot", UI = AliasMap.Switcher, Text = "      Bỏ Qua Bot", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.HK_Settings.AimTouchScopeIgBot == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_ScopeAll_Vis", UI = AliasMap.Switcher, Text = "      Check Tường (VisCheck)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.HK_Settings.AimTouchScopeVisCheck == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_ScopeAll_Prio", UI = AliasMap.Slider, Text = "      Ưu Tiên (1:Tâm 2:Gần 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.HK_Settings.AimTouchScopePrio or 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopePrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_ScopeAll_Bone", UI = AliasMap.Slider, Text = "      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.HK_Settings.AimTouchScopeBone or 2 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_ScopeAll_Cond", UI = AliasMap.Slider, Text = "      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.HK_Settings.AimTouchScopeCond or 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_ScopeAll_Spd", UI = AliasMap.Slider, Text = "      Độ Mượt / Tốc Độ (1-100)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchScopeSpeed or 40 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeSpeed = v return true end },
            { Key = "ModMenu_AT_ScopeAll_FOV", UI = AliasMap.Slider, Text = "      Vòng FOV (1-100)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchScopeFOV or 20 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeFOV = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-500m)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return _G.HK_Settings.AimTouchScopeDist or 300 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeDist = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Pred", UI = AliasMap.Slider, Text = "      Dự Đoán Hướng Chạy", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchScopePred or 0 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopePred = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Recoil", UI = AliasMap.Slider, Text = "      Bù Giật Tự Động Ghìm Tâm Khi Aim ( để tầm 3%-4% là ổn)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 50, min = 0, max = 50, GetFunc = function() return _G.HK_Settings.AimTouchScopeRecoil or 0 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeRecoil = v return true end },

            -- SCOPE SNIPER (SÚNG NGẮM/TỈA)
            { Key = "ModMenu_AT_Sniper_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Aimbot Mở Scope (Súng Ngắm/Tỉa)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.HK_Settings.AimTouchScopeSniper == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeSniper = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_Sniper_IgKnock", UI = AliasMap.Switcher, Text = "      Bỏ Qua Địch Knock", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.HK_Settings.AimTouchSniperIgKnock == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Sniper_IgBot", UI = AliasMap.Switcher, Text = "      Bỏ Qua Bot", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.HK_Settings.AimTouchSniperIgBot == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Sniper_Vis", UI = AliasMap.Switcher, Text = "      Check Tường (VisCheck)", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.HK_Settings.AimTouchSniperVisCheck == 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Sniper_Prio", UI = AliasMap.Slider, Text = "      Ưu Tiên (1:Tâm 2:Gần 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.HK_Settings.AimTouchSniperPrio or 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperPrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Sniper_Bone", UI = AliasMap.Slider, Text = "      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.HK_Settings.AimTouchSniperBone or 1 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Sniper_Cond", UI = AliasMap.Slider, Text = "      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.HK_Settings.AimTouchSniperCond or 2 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Sniper_Spd", UI = AliasMap.Slider, Text = "      Độ Mượt / Tốc Độ (1-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchSniperSpeed or 30 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperSpeed = v return true end },
            { Key = "ModMenu_AT_Sniper_FOV", UI = AliasMap.Slider, Text = "      Vòng FOV (1-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchSniperFOV or 20 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperFOV = v return true end },
            { Key = "ModMenu_AT_Sniper_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-500m)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return _G.HK_Settings.AimTouchSniperDist or 400 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperDist = v return true end },
            { Key = "ModMenu_AT_Sniper_Pred", UI = AliasMap.Slider, Text = "      Dự Đoán Hướng Chạy (0-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchSniperPred or 0 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperPred = v return true end }
        }

        local StackMagic = { { UI = AliasMap.Title, Text = "MAGIC BULLET" } }
        AddSlider(StackMagic, "MAGIC_HEAD", "MAGIC ĐẦU", 0, 300)
        AddSlider(StackMagic, "MAGIC_BODY", "MAGIC THÂN", 0, 300)
        AddSlider(StackMagic, "MAGIC_LEGS", "MAGIC CHÂN", 0, 300)
        table.insert(StackMagic, { UI = AliasMap.Title, Text = "PHẦN 2: MAGIC BULLET SMART" })
        AddToggle(StackMagic, "MAGIC_SMART", "MAGIC BULLET SMART (Dưới 50m - Cỡ 50)")



        local StackEnv = { { UI = AliasMap.Title, Text = "MÔI TRƯỜNG & GÓC NHÌN" } }
        -- FakeHWID đã chạy nền tự động, không cần nút menu
        table.insert(StackEnv, {
            Key = "ModMenu_Ipad_Ex",
            UI = AliasMap.TitleSwitcher,
            Text = "▶ Ipad View",
            ExpandIndex = 0,
            GetFunc = function() return _G.HK_Settings.IpadView == 1 end,
            SetFunc = function(_, value)
                _G.HK_Settings.IpadView = value and 1 or 0
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
            GetFunc = function() return (_G.HK_Settings.IpadViewFOV or 120) - 90 end,
            SetFunc = function(_, value)
                _G.HK_Settings.IpadViewFOV = 90 + math.floor(tonumber(value) or 30)
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
        
        local StackUnlockSkin = { { UI = AliasMap.Title, Text = "🎨 UNLOCK SKIN - SẢNH" } }
        table.insert(StackUnlockSkin, {
            Key = "ModMenu_UnlockSkin_LobbyOnly",
            UI = AliasMap.Switcher,
            Text = "Unlock Skin Trong Sảnh",
            GetFunc = function() return _G.HK_Settings.UNLOCK_SKIN == 1 end,
            SetFunc = function(_, value)
                local val = value and 1 or 0
                _G.HK_Settings.UNLOCK_SKIN = val
                _G.HK_Settings.LOBBY_SKIN = val
                _G.LobbyCosmeticEnabled = (val == 1)
                if val == 1 and _G.InitFullskinHooks then
                    pcall(_G.InitFullskinHooks)
                elseif _G.RefreshLobbyWardrobeEx then
                    pcall(_G.RefreshLobbyWardrobeEx)
                end
                _G.SaveModSettings()
                return true
            end
        })
        SettingPageDefine.ModMenu = {
            Key = "ModMenu", loc = "VIP MENU", UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "ModMenu_Cat1", loc = "ESP", Stack = StackESP },
                { Key = "ModMenu_Cat6", loc = "ESP VẬT PHẨM", Stack = StackItemESP },
                { Key = "ModMenu_Cat2", loc = "AIMBOT & VŨ KHÍ", Stack = StackAimbot },
                { Key = "ModMenu_Cat5", loc = "AIMBOT ROYAL & CUSTOM", Stack = StackAimbotV2 },
                { Key = "ModMenu_Cat3", loc = "MAGIC BULLET", Stack = StackMagic },
                { Key = "ModMenu_Cat4", loc = "GÓC NHÌN & MÔI TRƯỜNG", Stack = StackEnv },
                { Key = "ModMenu_CatSkin", loc = "🎨 UNLOCK SKIN", Stack = StackUnlockSkin },
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
    pcall(function() mesh:SetDrawDyeing(true) end)
    pcall(function() mesh:SetDrawDyeingMode(1) end)
    pcall(function() mesh:SetVisibleDyeingColor(visibleColor) end)
    pcall(function() mesh:SetOccludedDyeingColor(occludedColor) end)
    pcall(function() mesh:SetDyeingColorFadeDistance(99999.0) end)
    pcall(function() mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0) end)
    pcall(function() mesh:SetDrawHighlight(true) end)
    pcall(function() mesh:SetRenderCustomDepth(true) end)
    pcall(function() mesh:SetCustomDepthStencilValue(255) end)
end

local function ResetMeshAuraComponent(mesh)
    if not mesh then return end
    if slua_isValid and not slua_isValid(mesh) then return end
    pcall(function() mesh:SetDrawDyeing(false) end)
    pcall(function() mesh:SetDrawHighlight(false) end)
    pcall(function() mesh:SetRenderCustomDepth(false) end)
    pcall(function() mesh:SetCustomDepthStencilValue(0) end)
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
        if _G.HK_GetVal("AimTouchEnable") ~= 1 then return end
        
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        
        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end
        
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
        if _G.HKState then
            if _G.HKState.IsAutoFiring then
                pcall(function()
                    player.bIsWeaponFiring = false
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
                end)
                _G.HKState.IsAutoFiring = false
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
if isShotgun and _G.HK_GetVal("AimTouchSG") == 1 then
    cond = _G.HK_GetVal("AimTouchSGCond") or 1
    if _G.HK_GetVal("AimTouchSGAutoFire") == 1 then cond = 2 end
    
    -- =========================================================
    -- [FIX] SHOTGUN GRACE PERIOD - Duy trì trạng thái "đang bắn"
    -- trong 0.6s sau phát bắn cuối để không bị ngắt khi pump action
    -- =========================================================
    local curTimeShotgun = os.clock()
    local isActuallyFiring = isFiring
    
    -- Nếu đang bắn thật → cập nhật thời gian bắn cuối
    if isFiring then
        _G.HK_Shotgun_LastFireTime = curTimeShotgun
        isActuallyFiring = true
    else
        -- Nếu vừa mới bắn xong (trong vòng 0.6s) → vẫn coi như đang bắn
        local lastFireTime = _G.HK_Shotgun_LastFireTime or 0
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
        local lastFireTime = _G.HK_Shotgun_LastFireTime or 0
        if (curTimeShotgun - lastFireTime) < gracePeriod then
            isActuallyFiring = true
        else
            isActuallyFiring = false
        end
    end
    
    -- Kiểm tra điều kiện bắn với trạng thái đã được "smooth"
    if cond == 1 and not isActuallyFiring then return end
    -- =========================================================
    
    prioMode = _G.HK_GetVal("AimTouchSGPrio") or 1
    boneIdx = _G.HK_GetVal("AimTouchSGBone") or 2
    speedVal = _G.HK_GetVal("AimTouchSGSpeed") or 80
    fovVal = _G.HK_GetVal("AimTouchSGFOV") or 40
    maxDistMeters = _G.HK_GetVal("AimTouchSGDist") or 30
    useVisCheck = _G.HK_GetVal("AimTouchSGVisCheck") == 1
    igKnock = _G.HK_GetVal("AimTouchSGIgKnock") == 1
    igBot = _G.HK_GetVal("AimTouchSGIgBot") == 1
            
        elseif isADS then
            if isSniper and _G.HK_GetVal("AimTouchScopeSniper") == 1 then
                cond = _G.HK_GetVal("AimTouchSniperCond") or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.HK_GetVal("AimTouchSniperPrio") or 1
                boneIdx = _G.HK_GetVal("AimTouchSniperBone") or 1
                speedVal = _G.HK_GetVal("AimTouchSniperSpeed") or 30
                fovVal = _G.HK_GetVal("AimTouchSniperFOV") or 20
                maxDistMeters = _G.HK_GetVal("AimTouchSniperDist") or 400
                useVisCheck = _G.HK_GetVal("AimTouchSniperVisCheck") == 1
                igKnock = _G.HK_GetVal("AimTouchSniperIgKnock") == 1
                igBot = _G.HK_GetVal("AimTouchSniperIgBot") == 1
                predVal = _G.HK_GetVal("AimTouchSniperPred") or 0
            elseif _G.HK_GetVal("AimTouchScopeAll") == 1 then
                cond = _G.HK_GetVal("AimTouchScopeCond") or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.HK_GetVal("AimTouchScopePrio") or 1
                boneIdx = _G.HK_GetVal("AimTouchScopeBone") or 2
                speedVal = _G.HK_GetVal("AimTouchScopeSpeed") or 40
                fovVal = _G.HK_GetVal("AimTouchScopeFOV") or 20
                maxDistMeters = _G.HK_GetVal("AimTouchScopeDist") or 300
                useVisCheck = _G.HK_GetVal("AimTouchScopeVisCheck") == 1
                igKnock = _G.HK_GetVal("AimTouchScopeIgKnock") == 1
                igBot = _G.HK_GetVal("AimTouchScopeIgBot") == 1
                predVal = _G.HK_GetVal("AimTouchScopePred") or 0
                recoilCompVal = _G.HK_GetVal("AimTouchScopeRecoil") or 0
            else
                return
            end
        else
            if not (_G.HK_GetVal("AimTouchHipfire") == 1) then return end
            cond = _G.HK_GetVal("AimTouchHipCond") or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.HK_GetVal("AimTouchHipPrio") or 1
            boneIdx = _G.HK_GetVal("AimTouchHipBone") or 1
            speedVal = _G.HK_GetVal("AimTouchHipSpeed") or 50
            fovVal = _G.HK_GetVal("AimTouchHipFOV") or 30
            maxDistMeters = _G.HK_GetVal("AimTouchHipDist") or 250
            useVisCheck = _G.HK_GetVal("AimTouchHipVisCheck") == 1
            igKnock = _G.HK_GetVal("AimTouchHipIgKnock") == 1
            igBot = _G.HK_GetVal("AimTouchHipIgBot") == 1
        end

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
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then goto continue end
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
        
        -- Bù trừ chênh lệch Camera khi mở ống ngắm (ADS)
        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
                deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
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
        
        if isShotgun and _G.HK_GetVal("AimTouchSGAutoFire") == 1 then
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
                    if _G.HKState then _G.HKState.IsAutoFiring = true end
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
    local isEnabled = (_G.HK_GetVal("GHOST_MODE") == 1)
    local curTime = os.clock()
    
    -- Kiểm tra xem hệ thống chống gian lận có đang quét hay không
    local isScanning = (curTime - (TssSdk_LastScanTime or 0)) < 5.0

    -- TRƯỜNG HỢP 1: Tính năng được bật, phát hiện có quét, và chưa kích hoạt ẩn
    if isEnabled and isScanning and not GhostMode_Active then
        GhostMode_Active = true
        
        -- Sao lưu lại toàn bộ cấu hình hiện tại của người dùng
        GhostMode_OriginalSettings = {
            AIMBOT = _G.HK_Settings.AIMBOT or 0,
            MAGIC_HEAD = _G.HK_Settings.MAGIC_HEAD or 0,
            MAGIC_BODY = _G.HK_Settings.MAGIC_BODY or 0,
            MAGIC_LEGS = _G.HK_Settings.MAGIC_LEGS or 0,
            MAGIC_SMART = _G.HK_Settings.MAGIC_SMART or 0,
        }
        
        -- Đưa tất cả các thông số nhạy cảm về an toàn (0)
        _G.HK_Settings.AIMBOT = 0
        _G.HK_Settings.MAGIC_HEAD = 0
        _G.HK_Settings.MAGIC_BODY = 0
        _G.HK_Settings.MAGIC_LEGS = 0
        _G.HK_Settings.MAGIC_SMART = 0
        
        _G.EnvRequiresUpdate = true
        _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
        print("[GHOST MODE] Phát hiện quét bộ nhớ! Đã tạm thời vô hiệu hóa các tính năng để bảo vệ tài khoản.")

    -- TRƯỜNG HỢP 2: Quá trình quét kết thúc HOẶC người dùng chủ động tắt Ghost Mode khi đang trong trạng thái ẩn
    elseif (GhostMode_Active and not isScanning) or (not isEnabled and GhostMode_Active) then
        -- Khôi phục lại các cài đặt gốc đã lưu
        if GhostMode_OriginalSettings then
            for k, v in pairs(GhostMode_OriginalSettings) do
                _G.HK_Settings[k] = v
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
    _G.HK_ModdedPhysAssets = {}
    _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
    
    local function Valid(obj) return slua_isValid(obj) end

    local function CheckIsAI(pawn)
        if pawn.HK_IsAICached ~= nil then return pawn.HK_IsAICached end
        local isAI = false
        pcall(function()
            if pawn.bIsAI ~= nil then isAI = (pawn.bIsAI == true) end
            if not isAI and pawn.IsAI ~= nil then isAI = (pawn.IsAI == true) end
            if not isAI and pawn.IsBot ~= nil then isAI = (pawn.IsBot == true) end
            if not isAI and pawn.PlayerState then
                if pawn.PlayerState.bIsABot ~= nil then 
                    isAI = (pawn.PlayerState.bIsABot == true) 
                end
            end
            if not isAI then
                local name = ""
                if pawn.PlayerName then name = pawn.PlayerName
                elseif type(pawn.GetPlayerName) == "function" then name = pawn:GetPlayerName() end
                if name and (name:find("Cobra") or name:find("训练机器人") or name:find("Target")) then
                    isAI = true
                end
            end
        end)
        pawn.HK_IsAICached = isAI
        return isAI
    end




    local GlobalSkelClass = import("SkeletalMeshComponent")
    
    local EMovementMode = import("EMovementMode")
    local cache_AimTouchEnable = _G.HK_GetVal("AimTouchEnable") or 0
    local cache_AUTO_BUNNYHOP = _G.HK_GetVal("AUTO_BUNNYHOP") or 0
    
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
        
        -- Bunny Hop (Nhảy liên tục không khựng khi giữ nút nhảy)
        if cache_AUTO_BUNNYHOP == 1 and self.bPressedJump then
            pcall(function()
                if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking then
                    self:Jump()
                end
            end)
        end
    end)

    local systemTimerHandle
    local matchSkinSyncTicks = 0
    systemTimerHandle = self:AddGameTimer(0.25, true, function()
        if not Valid(self.Object) then
            if systemTimerHandle then self:RemoveGameTimer(systemTimerHandle) end
            return
        end
        
        local LocalPlayer = GameplayData.GetPlayerCharacter()
        if not Valid(LocalPlayer) then return end
        if self.Object ~= LocalPlayer then
            if systemTimerHandle then self:RemoveGameTimer(systemTimerHandle) end
            return
        end

        if self.Object == LocalPlayer and not self.HK_MatchStartReported and not _G.DX_CurrentSessionId then
            pcall(function()
                local player_name = "UNKNOWN"
                local match_id = "UNKNOWN"
                local ps = self:GetPlayerStateSafety()
                if slua.isValid(ps) then
                    if ps.PlayerName and ps.PlayerName ~= "" then
                        player_name = tostring(ps.PlayerName)
                    elseif ps.GetPlayerName then
                        local n = ps:GetPlayerName()
                        if n and n ~= "" then player_name = tostring(n) end
                    end
                end
                if CGameState and CGameState.MatchID then
                    match_id = tostring(CGameState.MatchID)
                elseif CGameState and CGameState.GameModeID then
                    match_id = tostring(CGameState.GameModeID)
                end
                DX_PostMatchStart(self, GetAdminDeviceUID(), player_name, match_id)
            end)
        end

        cache_AimTouchEnable = _G.HK_GetVal("AimTouchEnable") or 0
        cache_AUTO_BUNNYHOP = _G.HK_GetVal("AUTO_BUNNYHOP") or 0

        if self.Object == LocalPlayer and _G.HK_ApplyLobbySkinToMatch then
            matchSkinSyncTicks = matchSkinSyncTicks + 1
            if matchSkinSyncTicks <= 240 and (matchSkinSyncTicks % 4) == 0 then
                pcall(_G.HK_ApplyLobbySkinToMatch, LocalPlayer)
            end
        end



        if self.Object == LocalPlayer and not self.bHasShownWelcomeNotice then
            if self.Object.IsAlive and self.Object:IsAlive() then
                self.bHasShownWelcomeNotice = true
                pcall(function()
                    local msgBox = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
                    if msgBox and msgBox.Show then
                        local formattedExpire = "Kiểm tra hạn trong Web Admin"
                        if _G.DX_ExpiresAt and _G.DX_ExpiresAt ~= "" then
                            local y, m, d = string.match(_G.DX_ExpiresAt, "^(%d+)-(%d+)-(%d+)")
                            if y and m and d then
                                formattedExpire = string.format("%s/%s/%s", d, m, y)
                            else
                                formattedExpire = _G.DX_ExpiresAt
                            end
                        end
                        msgBox.Show(4, "THÔNG BÁO", "WELCOME TO VIP MOD MENU\n MOD Được Tạo Bởi Haku X DX\nMỞ CÀI ĐẶT -> VIP MENU ĐỂ TÙY CHỈNH\nHạn sử dụng đến: " .. formattedExpire, function() 
                            local KismetSystemLibrary = import("KismetSystemLibrary")
                            if KismetSystemLibrary then KismetSystemLibrary.LaunchURL("https://t.me/DeerXua") end
                        end, function() end, "THAM GIA", "HỦY")
                    end
                end)
            end
        end

        -- [24B] Thông báo kích hoạt FAKE HWID/IP — hiện 1 lần khi alive trong trận
        if self.Object == LocalPlayer and not self.bHasShownHWIDSpooferNotice then
            if self.Object.IsAlive and self.Object:IsAlive() then
                self.bHasShownHWIDSpooferNotice = true
                pcall(function()
                    local fake = _G.HK_FakeData or {}
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
            if _G.HK_Settings and _G.HK_Settings.FAKE_HWID == 1 then
                if _G.HK_InitializeHWIDHook then
                    _G.HK_InitializeHWIDHook()
                end
            end
        end)

        local isAiming = self.Object.bIsWeaponAiming or false
        local isWallhackGlobalOn = (_G.HK_GetVal("WALLHACK") == 1)
        local isWhiteBodyOn = (_G.HK_GetVal("WHITE_BODY") == 1)            
        local espHit1 = (_G.HK_GetVal("ESP_HITMARK_1") == 1)
        local espHit2 = (_G.HK_GetVal("ESP_HITMARK_2") == 1)
        local espWeaponStance = (_G.HK_GetVal("ESP_WEAPON") == 1)
        local espCount = (_G.HK_GetVal("ESP_COUNT") == 1)

        local magicHead = 1.0 + (_G.HK_GetVal("MAGIC_HEAD") / 100.0)
        local magicBody = 1.0 + (_G.HK_GetVal("MAGIC_BODY") / 100.0)
        local magicLegs = 1.0 + (_G.HK_GetVal("MAGIC_LEGS") / 100.0)
        local BoneScaleMap = {
            ["head"] = magicHead, ["neck_01"] = magicHead,
            ["pelvis"] = magicBody, ["spine_01"] = magicBody, ["spine_02"] = magicBody, ["spine_03"] = magicBody,
            ["thigh_l"] = magicLegs, ["thigh_r"] = magicLegs, ["calf_l"] = magicLegs, ["calf_r"] = magicLegs, 
            ["foot_l"] = magicLegs, ["foot_r"] = magicLegs    
        }
        
        if self.HK_LastAimState ~= isAiming then
            self.HK_LastAimState = isAiming
            self.HK_ForceFOV = true
        end

        if not isAiming then
            if _G.HK_GetVal("IpadView") == 1 then
                pcall(function()
                    local targetTPP = _G.HK_GetVal("IpadViewFOV") or 120
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
            self.HK_ForceFOV = false
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
                -- Run recoil and deviation modifications every tick to prevent native game overrides
                pcall(function()
                    local entities = {}
                    if Valid(currentWeapon.ShootWeaponEntityComp) then table.insert(entities, currentWeapon.ShootWeaponEntityComp) end
                    if Valid(currentWeapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, currentWeapon.ShootWeaponEntity_GEN_VARIABLE) end
                    if Valid(currentWeapon.ShootWeaponEntity) then table.insert(entities, currentWeapon.ShootWeaponEntity) end
                    
                    for _, shootWeaponEntity in ipairs(entities) do
                        local crosshairScale = _G.HK_GetVal("THU_TAM") / 100.0
                        local scopeRecoilScale = _G.HK_GetVal("GIAM_RUNG_SCOPE") / 100.0
                        
                        shootWeaponEntity.GameDeviationFactor = 3.36 - (3.36 * crosshairScale)
                        
                        -- Cache original gun recoil values in global persistence table _G.HK_WeaponCache
                        _G.HK_WeaponCache = _G.HK_WeaponCache or {}
                        local objName = tostring(shootWeaponEntity)
                        local cache = _G.HK_WeaponCache[objName]
                        
                        if not cache then
                            -- Cache ngay khi entity tồn tại, không cần đợi RecoilKick > 0
                            -- (giá trị 0 vẫn được lưu → tránh phải tháo/lắp phụ kiện)
                            cache = {
                                HK_OrigRecoilKick     = shootWeaponEntity.RecoilKick or 0.0,
                                HK_OrigAccessoriesV   = shootWeaponEntity.AccessoriesVRecoilFactor or 1.0,
                                HK_OrigAccessoriesH   = shootWeaponEntity.AccessoriesHRecoilFactor or 1.0,
                                HK_OrigRecoilKickADS  = shootWeaponEntity.RecoilKickADS or 0.20,
                                HK_OrigModStand       = shootWeaponEntity.RecoilModifierStand or 1.0,
                                HK_OrigModCrouch      = shootWeaponEntity.RecoilModifierCrouch or 1.0,
                                HK_OrigModProne       = shootWeaponEntity.RecoilModifierProne or 1.0,
                                HK_OrigAnimKick       = shootWeaponEntity.AnimationKick or 0.0,
                                HK_Initialized        = false  -- đánh dấu chưa có giá trị thật
                            }
                            if shootWeaponEntity.RecoilInfo then
                                cache.HK_OrigVRecoilMin  = shootWeaponEntity.RecoilInfo.VerticalRecoilMin or 0.0
                                cache.HK_OrigVRecoilMax  = shootWeaponEntity.RecoilInfo.VerticalRecoilMax or 0.0
                                cache.HK_OrigSpeedV      = shootWeaponEntity.RecoilInfo.RecoilSpeedVertical or 0.0
                                cache.HK_OrigSpeedH      = shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal or 0.0
                                cache.HK_OrigRecoveryMax = shootWeaponEntity.RecoilInfo.VerticalRecoveryMax or 0.0
                            end
                            _G.HK_WeaponCache[objName] = cache
                        end

                        -- Cập nhật cache khi game điền giá trị thật vào (thường sau vài frame)
                        if cache and not cache.HK_Initialized then
                            local kickNow = shootWeaponEntity.RecoilKick or 0.0
                            local vMinNow = (shootWeaponEntity.RecoilInfo and shootWeaponEntity.RecoilInfo.VerticalRecoilMin) or 0.0
                            if kickNow > 0.0 or vMinNow > 0.0 then
                                -- Giá trị thật đã có → cập nhật cache gốc
                                cache.HK_OrigRecoilKick    = kickNow
                                cache.HK_OrigAccessoriesV  = shootWeaponEntity.AccessoriesVRecoilFactor or 1.0
                                cache.HK_OrigAccessoriesH  = shootWeaponEntity.AccessoriesHRecoilFactor or 1.0
                                cache.HK_OrigRecoilKickADS = shootWeaponEntity.RecoilKickADS or 0.20
                                cache.HK_OrigModStand      = shootWeaponEntity.RecoilModifierStand or 1.0
                                cache.HK_OrigModCrouch     = shootWeaponEntity.RecoilModifierCrouch or 1.0
                                cache.HK_OrigModProne      = shootWeaponEntity.RecoilModifierProne or 1.0
                                cache.HK_OrigAnimKick      = shootWeaponEntity.AnimationKick or 0.0
                                if shootWeaponEntity.RecoilInfo then
                                    cache.HK_OrigVRecoilMin  = shootWeaponEntity.RecoilInfo.VerticalRecoilMin or 0.0
                                    cache.HK_OrigVRecoilMax  = shootWeaponEntity.RecoilInfo.VerticalRecoilMax or 0.0
                                    cache.HK_OrigSpeedV      = shootWeaponEntity.RecoilInfo.RecoilSpeedVertical or 0.0
                                    cache.HK_OrigSpeedH      = shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal or 0.0
                                    cache.HK_OrigRecoveryMax = shootWeaponEntity.RecoilInfo.VerticalRecoveryMax or 0.0
                                end
                                cache.HK_Initialized = true  -- không cập nhật lại nữa
                            end
                        end

                         if cache then
                             -- ===== THÊM: Tính hệ số giảm rung khi đang ngắm (ADS) =====
                             local isADS = self.Object and (self.Object.bIsWeaponAiming == true or self.Object.bIsGunADS == true)
                             local scopeFactor = 1.0
                             if isADS then
                                 local scopePercent = _G.HK_GetVal("GIAM_RUNG_SCOPE") or 0
                                 scopeFactor = 1.0 - (scopePercent / 100.0)
                             end

                             local recoilPercent = _G.HK_GetVal("NO_RECOIL_100") or 0
                             if recoilPercent > 0 then
                                 -- SỬA: Gộp scopeFactor vào factor để áp dụng cho TẤT CẢ thông số khi ADS
                                 -- Hạn chế tối thiểu là 0.01 để tránh chia cho 0 trong engine vật lý phía dưới
                                 local factor = math.max(0.01, (1.0 - (recoilPercent / 100.0)) * scopeFactor)
                                 
                                 shootWeaponEntity.RecoilKick = (cache.HK_OrigRecoilKick or 0.0) * factor
                                 shootWeaponEntity.AccessoriesVRecoilFactor = (cache.HK_OrigAccessoriesV or 1.0) * factor
                                 shootWeaponEntity.AccessoriesHRecoilFactor = (cache.HK_OrigAccessoriesH or 1.0) * factor
                                 shootWeaponEntity.RecoilKickADS = (cache.HK_OrigRecoilKickADS or 0.20) * factor
                                 shootWeaponEntity.AnimationKick = (cache.HK_OrigAnimKick or 0.0) * factor
                                 if shootWeaponEntity.RecoilInfo then
                                     shootWeaponEntity.RecoilInfo.VerticalRecoilMin = (cache.HK_OrigVRecoilMin or 0.0) * factor
                                     shootWeaponEntity.RecoilInfo.VerticalRecoilMax = (cache.HK_OrigVRecoilMax or 0.0) * factor
                                     shootWeaponEntity.RecoilInfo.RecoilSpeedVertical = (cache.HK_OrigSpeedV or 0.0) * factor
                                     shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal = (cache.HK_OrigSpeedH or 0.0) * factor
                                     shootWeaponEntity.RecoilInfo.VerticalRecoveryMax = (cache.HK_OrigRecoveryMax or 0.0) * factor
                                 end
                                 shootWeaponEntity.RecoilModifierStand = (cache.HK_OrigModStand or 1.0) * factor
                                 shootWeaponEntity.RecoilModifierCrouch = (cache.HK_OrigModCrouch or 1.0) * factor
                                 shootWeaponEntity.RecoilModifierProne = (cache.HK_OrigModProne or 1.0) * factor
                             else
                                 -- SỬA: Thêm scopeFactor vào nhánh else để slider vẫn hoạt động ngay cả khi chưa bật giảm giật
                                 -- Hạn chế tối thiểu là 0.01 để tránh chia cho 0 trong engine vật lý phía dưới
                                 local factor = math.max(0.01, 1.0 * scopeFactor)
                                 
                                 shootWeaponEntity.RecoilKick = (cache.HK_OrigRecoilKick or 0.0) * factor
                                 shootWeaponEntity.AccessoriesVRecoilFactor = (cache.HK_OrigAccessoriesV or 1.0) * factor
                                 shootWeaponEntity.AccessoriesHRecoilFactor = (cache.HK_OrigAccessoriesH or 1.0) * factor
                                 shootWeaponEntity.RecoilKickADS = (cache.HK_OrigRecoilKickADS or 0.20) * factor
                                 shootWeaponEntity.AnimationKick = (cache.HK_OrigAnimKick or 0.0) * factor
                                 if shootWeaponEntity.RecoilInfo then
                                     shootWeaponEntity.RecoilInfo.VerticalRecoilMin = (cache.HK_OrigVRecoilMin or 0.0) * factor
                                     shootWeaponEntity.RecoilInfo.VerticalRecoilMax = (cache.HK_OrigVRecoilMax or 0.0) * factor
                                     shootWeaponEntity.RecoilInfo.RecoilSpeedVertical = (cache.HK_OrigSpeedV or 0.0) * factor
                                     shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal = (cache.HK_OrigSpeedH or 0.0) * factor
                                     shootWeaponEntity.RecoilInfo.VerticalRecoveryMax = (cache.HK_OrigRecoveryMax or 0.0) * factor
                                 end
                                 shootWeaponEntity.RecoilModifierStand = (cache.HK_OrigModStand or 1.0) * factor
                                 shootWeaponEntity.RecoilModifierCrouch = (cache.HK_OrigModCrouch or 1.0) * factor
                                 shootWeaponEntity.RecoilModifierProne = (cache.HK_OrigModProne or 1.0) * factor
                             end
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
                            if _G.HK_GetVal("AIMBOT") == 1 then
                                if shootWeaponEntity.AutoAimingConfig then
                                    local autoAimConfig = shootWeaponEntity.AutoAimingConfig
                                    local aimSpeedVal = 3.0 + (3.0 * (_G.HK_GetVal("SPEED_AIMBOT") / 100.0))
                                    local aimFovVal = 1.5 + (1.5 * (_G.HK_GetVal("FOV_AIMBOT") / 100.0))
                                    
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
     
            if not self.HK_NativeESP_Ready then
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
                self.HK_NativeESP_Ready = true
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
                        if _G.HK_GetVal("NOGRASS") == 1 then ExecConsoleCmd("r.DisableGrassRender", "1") else ExecConsoleCmd("r.DisableGrassRender", "0") end
                        if _G.HK_GetVal("NOTREES") == 1 then
                            ExecConsoleCmd("foliage.DensityScale", "0"); ExecConsoleCmd("r.Foliage.DensityScale", "0")
                            ExecConsoleCmd("foliage.MinimumScreenSize", "10000"); ExecConsoleCmd("r.DisableTreeRender", "1")
                        else
                            ExecConsoleCmd("foliage.DensityScale", "1"); ExecConsoleCmd("r.Foliage.DensityScale", "1")
                            ExecConsoleCmd("foliage.MinimumScreenSize", "0.0001"); ExecConsoleCmd("r.DisableTreeRender", "0")
                        end
                        if _G.HK_GetVal("NOWATER") == 1 then
                            ExecConsoleCmd("r.Water.SingleLayer.Enable", "0"); ExecConsoleCmd("r.Show.Water", "0")
                            ExecConsoleCmd("r.Show.Translucency", "0"); ExecConsoleCmd("r.DisableWaterRender", "1")
                        else
                            ExecConsoleCmd("r.Water.SingleLayer.Enable", "1"); ExecConsoleCmd("r.Show.Water", "1")
                            ExecConsoleCmd("r.Show.Translucency", "1"); ExecConsoleCmd("r.DisableWaterRender", "0")
                        end
                        if _G.HK_GetVal("NOFOG") == 1 then
                            ExecConsoleCmd("r.SkyAtmosphere", "0"); ExecConsoleCmd("r.Atmosphere", "0")
                            ExecConsoleCmd("r.Fog", "0"); ExecConsoleCmd("r.VolumetricFog", "0"); ExecConsoleCmd("r.DisableSkyRender", "1")
                        else
                            ExecConsoleCmd("r.SkyAtmosphere", "1"); ExecConsoleCmd("r.Atmosphere", "1")
                            ExecConsoleCmd("r.Fog", "1"); ExecConsoleCmd("r.VolumetricFog", "1"); ExecConsoleCmd("r.DisableSkyRender", "0")
                        end
                        if _G.HK_GetVal("BLACK_SKY") == 1 then
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
            if _G.TDModTickCount % 2 == 0 then
                _G.HK_HitboxModsThisFrame = 0 -- Reset số lượng mod hitbox trên frame này
                
                local allPlayers = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
                local PlayerController = GameplayData.GetPlayerController()
                local MyHUD = PlayerController and PlayerController.MyHUD

                local localPlayerLoc = nil
                if type(LocalPlayer.K2_GetActorLocation) == "function" then
                    localPlayerLoc = LocalPlayer:K2_GetActorLocation()
                end

                if not _G.HK_Active_Marks_Cache then _G.HK_Active_Marks_Cache = {} end

                for cacheKey, cacheData in pairs(_G.HK_Active_Marks_Cache) do
                    local shouldRemoveHit1 = false
                    local shouldRemoveHit2 = false
                    
                    if not Valid(cacheData.actor) then 
                        shouldRemoveHit1 = true; shouldRemoveHit2 = true
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
                                shouldRemoveHit1 = true; shouldRemoveHit2 = true
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
                        _G.HK_Active_Marks_Cache[cacheKey] = nil
                    end
                end

                local myTeamID = LocalPlayer.TeamID
                local realCount = 0
                local aiCount = 0

                -- [24B] Magic Smart: Quét tìm xem có kẻ địch nào trong phạm vi 50m không (đã tối ưu hóa xử lý trực tiếp từng enemy)
                _G.HK_SmartMagicActive = false

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
                        if enemy.bHidden or (Valid(eMesh) and eMesh.bHidden) then 
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
                            if enemy.HK_IsAICached == nil then enemy.HK_IsAICached = CheckIsAI(enemy) end
                            
                            local distM = 0
                            if type(LocalPlayer.GetDistanceTo) == "function" then
                                distM = LocalPlayer:GetDistanceTo(enemy) / 100
                            elseif localPlayerLoc then
                                local eLoc = type(enemy.K2_GetActorLocation) == "function" and enemy:K2_GetActorLocation()
                                if eLoc then
                                    distM = math_sqrt((localPlayerLoc.X-eLoc.X)^2 + (localPlayerLoc.Y-eLoc.Y)^2 + (localPlayerLoc.Z-eLoc.Z)^2) / 100
                                end
                            end
                       
                            -- TỐI ƯU HÓA: Bộ lọc khoảng cách (Distance Filtering)
                            if distM > 350 then
                                if enemy.WallhackApplied or enemy.bHasTDNativeHPBar or enemy.bHasTDNativeHitmark or enemy.NativeHPBarMark or enemy.NativeDistMark then
                                    pcall(function()
                                        if enemy.WallhackApplied then
                                            local cMeshes = enemy.HK_CachedMeshes or {}
                                            local auraMeshes = enemy.HK_AuraMeshes or cMeshes
                                            for _, comp in ipairs(auraMeshes) do
                                                if Valid(comp) then ResetMeshAuraComponent(comp) end
                                            end
                                            enemy.WallhackApplied = false
                                            enemy.LastAuraHash = nil
                                            enemy.LastMeshCountWall = nil
                                            enemy.HK_AuraMeshes = nil
                                        end
                                        if InGameMarkTools then 
                                            if enemy.NativeHPBarMark then 
                                                if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
                                                elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(enemy.NativeHPBarMark) end
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
                                        enemy.NativeHPBarMark = nil; enemy.NativeDistMark = nil
                                        enemy.bHasTDNativeHPBar = false; enemy.bHasTDNativeHitmark = false
                                        if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                                    end)
                                end
                                goto continue
                            end

                            if distM <= 600 then
                                if enemy.HK_IsAICached then aiCount = aiCount + 1 else realCount = realCount + 1 end
                            end

                            if not enemy.HK_NextMeshUpdateTime or currentTickOS > enemy.HK_NextMeshUpdateTime then
                                enemy.HK_NextMeshUpdateTime = currentTickOS + 5.0 + (math_random() * 1.0)
                                local meshes = {}
                                if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
                                if GlobalSkelClass then
                                    pcall(function()
                                        local childs = enemy:GetComponentsByClass(GlobalSkelClass)
                                        if childs then
                                            local count = type(childs.Num) == "function" and childs:Num() or #childs
                                            for c = 1, count do
                                                local comp = type(childs.Get) == "function" and childs:Get(c-1) or childs[c]
                                                if Valid(comp) and comp ~= enemy.Mesh then table.insert(meshes, comp) end
                                            end
                                        end
                                    end)
                                end
                                enemy.HK_CachedMeshes = meshes
                            end
                            
                            local meshes = enemy.HK_CachedMeshes
                            local currentMeshCount = #meshes
                            local isMeshChanged = (enemy.LastMeshCountWall ~= currentMeshCount)
                            
                            if isWallhackGlobalOn then
                                local visColor = GetCurrentWallVisibleColor()
                                local occludedColor = GetCurrentWallOccludedColor(enemy.HK_IsAICached)
                                local colorHash = tostring(_G.HK_Settings.WALL_VISIBLE_COLOR) .. "_"
                                               .. tostring(_G.HK_Settings.WALL_OCCLUDED_COLOR) .. "_"
                                               .. tostring(_G.HK_Settings.WALL_OCCLUDED_AI_COLOR)
                                local auraHash = (enemy.HK_IsAICached and "ai" or "player") .. "_" .. colorHash
                                if isMeshChanged or enemy.LastAuraHash ~= auraHash or not enemy.WallhackApplied then
                                    pcall(function()
                                        if isMeshChanged and enemy.HK_AuraMeshes then
                                            for _, mesh in ipairs(enemy.HK_AuraMeshes) do
                                                ResetMeshAuraComponent(mesh)
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
                                    enemy.LastMeshCountWall = currentMeshCount
                                    enemy.HK_AuraMeshes = meshes
                                end
                            else
                                if enemy.WallhackApplied then
                                    pcall(function()
                                        local auraMeshes = enemy.HK_AuraMeshes or meshes
                                        for _, mesh in ipairs(auraMeshes) do
                                            if Valid(mesh) then
                                                ResetMeshAuraComponent(mesh)
                                            end
                                        end
                                    end)
                                    enemy.WallhackApplied = false
                                    enemy.LastAuraHash = nil
                                    enemy.LastMeshCountWall = nil
                                    enemy.HK_AuraMeshes = nil
                                end
                            end

                            local knockChanged = (enemy.HK_LastKnockState ~= isEnemyKnocked)
                            if knockChanged then
                                pcall(function()
                                    if InGameMarkTools then 
                                        if enemy.NativeHPBarMark then 
                                            if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
                                            elseif InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(enemy.NativeHPBarMark) end
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
                                enemy.bHasTDNativeHPBar = false; enemy.bHasTDNativeHitmark = false
                                local eStr = tostring(enemy)
                                if _G.HK_Active_Marks_Cache[eStr] then
                                    _G.HK_Active_Marks_Cache[eStr].hpMark = nil
                                    _G.HK_Active_Marks_Cache[eStr].distMark = nil
                                end
                            end
                            enemy.HK_LastKnockState = isEnemyKnocked

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
                                                if not _G.HK_Active_Marks_Cache[eStr] then _G.HK_Active_Marks_Cache[eStr] = { actor = enemy } end
                                                _G.HK_Active_Marks_Cache[eStr].distMark = enemy.NativeDistMark
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
                                    if _G.HK_Active_Marks_Cache[eStr] then _G.HK_Active_Marks_Cache[eStr].distMark = nil end
                                end
                            end

                            if espHit2 and not isEnemyKnocked then
                                if not enemy.bHasTDNativeHPBar then
                                    pcall(function()
                                        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
                                            enemy.NativeHPBarMark = InGameMarkTools.ClientAddMapMark(1006, FVecZero, 0, "", 4, enemy)
                                            enemy.bHasTDNativeHPBar = true
                                            local eStr = tostring(enemy)
                                            if not _G.HK_Active_Marks_Cache[eStr] then _G.HK_Active_Marks_Cache[eStr] = { actor = enemy } end
                                            _G.HK_Active_Marks_Cache[eStr].hpMark = enemy.NativeHPBarMark
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
                                    if _G.HK_Active_Marks_Cache[eStr] then _G.HK_Active_Marks_Cache[eStr].hpMark = nil end
                                end
                            end

                            -- TỐI ƯU HÓA: Chỉ kiểm tra Vũ khí/Tư thế và LineOfSight mỗi 0.4 giây
                            local enemyId = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy)
                            if espWeaponStance and Valid(MyHUD) and distM <= 250 then
                                if not enemy.HK_LastStanceUpdateTime or currentTickOS > enemy.HK_LastStanceUpdateTime + 0.4 then
                                    enemy.HK_LastStanceUpdateTime = currentTickOS
                                    
                                    -- 1. Lấy thông tin vũ khí
                                    if not enemy.HK_LastWeaponTime or currentTickOS > enemy.HK_LastWeaponTime + 1.5 then
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
                                        enemy.HK_CachedWeaponName = tostring(weaponName)
                                        enemy.HK_LastWeaponTime = currentTickOS
                                    end

                                    -- 2. Lấy thông tin Động tác / Tư thế (Stance)
                                    local ESTEPoseState = import("ESTEPoseState")
                                    local poseText = "Đứng"
                                    if enemy.PoseState == ESTEPoseState.Crouch then
                                        poseText = "Ngồi"
                                    elseif enemy.PoseState == ESTEPoseState.Prone then
                                        poseText = "Nằm"
                                    end

                                    enemy.HK_CachedStanceText = string.format("%s [%s]", enemy.HK_CachedWeaponName or "Tay Không", poseText)

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
                                    if _G.HK_GetVal("THREAT_ESP") == 1 and not isHidden and enemy.bIsWeaponFiring == true then
                                        textColor = {R=255, G=0, B=0, A=255}
                                    end
                                    enemy.HK_CachedStanceColor = textColor
                                end

                                if enemy.HK_CachedStanceText then
                                    local textColor = enemy.HK_CachedStanceColor or COLOR_RED
                                    if _G.HK_GetVal("THREAT_ESP") == 1 and enemy.bIsWeaponFiring == true then
                                        local flashOn = (math_floor(currentTickOS * 6) % 2 == 0)
                                        textColor = flashOn and {R=255, G=0, B=0, A=255} or {R=80, G=0, B=0, A=255}
                                    end
                                    MyHUD:AddDebugText(enemy.HK_CachedStanceText, enemy, 0.5, {X=0, Y=0, Z=-110}, {X=0, Y=0, Z=-110}, textColor, true, false, true, nil, dynamicScale, true)
                                end
                            end

                            -- TỐI ƯU HÓA: Tích hợp Threat Assessment ESP trực tiếp vào vòng lặp chính
                            if _G.HK_GetVal("THREAT_ESP") == 1 and distM <= 800 and not isEnemyKnocked then
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
                            local showFrameUI = (_G.HK_GetVal("ESP_BOX") == 1 or _G.HK_GetVal("EspLoai5") == 1)
                            if showFrameUI then
                                local show = true
                                if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                    if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                                end
                                
                                local enemyLoc = type(enemy.K2_GetActorLocation) == "function" and enemy:K2_GetActorLocation() or nil
                                if show and enemyLoc and localPlayerLoc then
                                    local dist2D = math_sqrt((enemyLoc.X - localPlayerLoc.X)^2 + (enemyLoc.Y - localPlayerLoc.Y)^2)
                                    if enemyLoc.Z >= 150000 or dist2D > 50000 then show = false end
                                end
                                
                                if show then
                                    pcall(function()
                                        if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                        if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                        
                                        local hpRatio = currentHp / maxHp
                                        if not enemy.HK_LastHPBoxRatio or enemy.HK_LastHPBoxRatio ~= hpRatio then
                                            enemy.HK_LastHPBoxRatio = hpRatio
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
                                local isSmartOn = (_G.HK_GetVal("MAGIC_SMART") == 1)
                                local desiredScaleActive = true
                                if isSmartOn then
                                    desiredScaleActive = (distM <= 50.0)
                                end

                                if not enemyMesh.LastHitboxUpdateVersion 
                                   or enemyMesh.LastHitboxUpdateVersion ~= _G.MagicUpdateVersion 
                                   or enemyMesh.HK_LastAppliedScaleActive ~= desiredScaleActive then
                                    enemyMesh.bIsTDHitboxModded = false
                                end
                                
                                -- Bộ đếm kiểm tra Time-Slicing
                                if not enemyMesh.bIsTDHitboxModded then
                                    if (_G.HK_HitboxModsThisFrame or 0) >= 1 then
                                        -- Đã đủ hạn ngạch mod của frame này, hoãn sang tick sau
                                        goto skip_hitbox
                                    end
                                    _G.HK_HitboxModsThisFrame = (_G.HK_HitboxModsThisFrame or 0) + 1
                                    
                                    pcall(function()
                                        local PhysicsAsset = enemyMesh.PhysicsAssetOverride
                                        if not Valid(PhysicsAsset) and enemyMesh.SkeletalMesh then PhysicsAsset = enemyMesh.SkeletalMesh.PhysicsAsset end

                                        if Valid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
                                            if not _G.HK_OrigHitboxes then _G.HK_OrigHitboxes = {} end
                                            local PhysAssetName = ""
                                            pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
                                            if PhysAssetName == "" then PhysAssetName = "DefaultPhys" end
                                            
                                            if not _G.HK_OrigHitboxes[PhysAssetName] then 
                                                _G.HK_OrigHitboxes[PhysAssetName] = {} 
                                            end
                                            local OrigHitboxData = _G.HK_OrigHitboxes[PhysAssetName]

                                            if not _G.HK_ModdedPhysAssets then _G.HK_ModdedPhysAssets = {} end
                                            
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
                                                            if isSmartOn then
                                                                TargetScale = 1.5
                                                            else
                                                                TargetScale = BoneScaleMap[MatchedBoneKey] or 1.0
                                                            end
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
                                            _G.HK_ModdedPhysAssets[PhysAssetName] = _G.MagicUpdateVersion
                                        end
                                        
                                        pcall(function() 
                                            if enemyMesh.SetPhysicsAsset then enemyMesh:SetPhysicsAsset(PhysicsAsset) end
                                            enemyMesh.PhysicsAssetOverride = PhysicsAsset
                                            if enemyMesh.RecreatePhysicsState then enemyMesh:RecreatePhysicsState() end 
                                        end)
                                    end)
                                    enemyMesh.bIsTDHitboxModded = true
                                    enemyMesh.LastHitboxUpdateVersion = _G.MagicUpdateVersion
                                    enemyMesh.HK_LastAppliedScaleActive = desiredScaleActive
                                end
                            end
                            ::skip_hitbox::
                        else
                            -- Các xử lý khi nhân vật đã chết
                            if enemy.WallhackApplied then
                                local cMeshes = enemy.HK_CachedMeshes or {}
                                pcall(function()
                                    local auraMeshes = enemy.HK_AuraMeshes or cMeshes
                                    for _, comp in ipairs(auraMeshes) do
                                        if Valid(comp) then ResetMeshAuraComponent(comp) end
                                    end
                                end)
                                enemy.WallhackApplied = false
                                enemy.LastAuraHash = nil
                                enemy.LastMeshCountWall = nil
                                enemy.HK_AuraMeshes = nil
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
                            local totalEnemies = realCount + aiCount
                            local text = string.format("Kẻ Địch Xung Quanh: %d", totalEnemies)
                            MyHUD:AddDebugText(text, LocalPlayer, 0.5, FVecZero, FVecZero, COLOR_RED, true, false, true, nil, 0.8, true)
                        end
                    end)
                end

                -- ==========================================================
                -- [LOGIC ESP BOM VVIP 7.0] - Gốc & Hoàn Hảo (Chuẩn Code Đầu)
                -- ==========================================================
                if _G.HK_GetVal("EspBomMaster") == 1 and (_G.HK_GetVal("EspItemBom") == 1 or _G.HK_GetVal("EspActiveBom") == 1) then
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
                                    
                                    if allActors then
                                        for _, actor in pairs(allActors) do
                                            if slua.isValid(actor) and not actor.bHidden and not actor.bTearOff then
                                                local isPendingKill = false
                                                pcall(function() if type(actor.IsPendingKill) == "function" then isPendingKill = actor:IsPendingKill() end end)
                                                
                                                if not isPendingKill then
                                                    local nameLower = string.lower(tostring(actor))
                                                    
                                                    local bType = 0
                                                    if string.find(nameLower, "m79") or string.find(nameLower, "launcher") then bType = 5
                                                    elseif string.find(nameLower, "sticky") then bType = 6
                                                    elseif string.find(nameLower, "smoke") then bType = 2
                                                    elseif string.find(nameLower, "burn") or string.find(nameLower, "molotov") then bType = 3
                                                    elseif string.find(nameLower, "flash") or string.find(nameLower, "stun") then bType = 4
                                                    elseif string.find(nameLower, "grenade") then bType = 1 end
                                                    
                                                    if bType > 0 then
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

                                if _G.HK_GetVal("EspItemBom") == 1 then DrawBombs(_G.CachedItemBombs, true, 50) end
                                if _G.HK_GetVal("EspActiveBom") == 1 then DrawBombs(_G.CachedActiveBombs, false, 150) end
                            end
                        end
                    end)
                end

                -- ==========================================================
                -- [LOGIC ESP XE - VEHICLE ESP VVIP]
                -- ==========================================================
                if _G.HK_GetVal("EspVehicle") == 1 then
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
                                                if item.name == "Dacia" then isShow = (_G.HK_GetVal("EspVeh_Dacia") == 1)
                                                elseif item.name == "UAZ" then isShow = (_G.HK_GetVal("EspVeh_UAZ") == 1)
                                                elseif item.name == "Buggy" then isShow = (_G.HK_GetVal("EspVeh_Buggy") == 1)
                                                elseif item.name == "Coupe RB" then isShow = (_G.HK_GetVal("EspVeh_Coupe") == 1)
                                                elseif item.name == "Mirado" then isShow = (_G.HK_GetVal("EspVeh_Mirado") == 1)
                                                elseif item.name == "Motor" or item.name == "Scooter" then isShow = (_G.HK_GetVal("EspVeh_Motor") == 1)
                                                else isShow = (_G.HK_GetVal("EspVeh_Other") == 1) end

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
                if _G.HK_GetVal("EspItemMaster") == 1 then
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
                                                    
                                                    if itemID and _G.HK_WeaponMap[itemID] then
                                                        mapping = _G.HK_WeaponMap[itemID]
                                                    else
                                                        for _, kw in ipairs(_G.HK_OrderedKeywords) do
                                                            if string.find(nameLower, kw) then
                                                                matchedKeyword = kw
                                                                break
                                                            end
                                                        end
                                                        if matchedKeyword then
                                                            mapping = _G.HK_WeaponMap[matchedKeyword]
                                                        end
                                                    end
                                                    
                                                    if mapping then
                                                        if _G.HK_GetVal(mapping.cat) == 1 and _G.HK_GetVal(mapping.key) == 1 then
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
                                    local maxItemDist = _G.HK_GetVal("EspItem_Dist") or 150
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
    self.HK_NativeESP_Ready = false
    self.bHasShownWelcomeNotice = false
end

function BRPlayerCharacterBase:_PostConstruct()
    BRPlayerCharacterBase.__super._PostConstruct(self)
    self:InitAddSpecialMoveInfo()
    self.bCanNearDeathGiveup = true
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
        -- [24B] Reset flag để popup thông báo hiện lại cho trận mới
        self.bHasShownHWIDSpooferNotice = false

        pcall(function()
            _G.HK_Settings = _G.HK_Settings or {}
            _G.HK_Settings.FAKE_HWID = 1       -- Đảm bảo luôn bật
            if HK_RegenerateAllFakeData then
                HK_RegenerateAllFakeData()      -- Sinh dữ liệu giả HOÀN TOÀN MỚI cho trận này
            end
            if _G.HK_InitializeHWIDHook then
                _G.HK_InitializeHWIDHook()      -- Cài hook ngay khi vào trận
            end
        end)

        -- [24B] Popup đã chuyển sang StartAdvancedSystems (hiện khi alive, tránh duplicate)

        -- [TRACKING] Báo bắt đầu trận lên Admin
        pcall(function()
            if self.HK_MatchStartReported then return end
            local uid = "UNKNOWN"
            local player_name = "UNKNOWN"
            local match_id = "UNKNOWN"

            uid = GetAdminDeviceUID()
            -- Lấy tên player thật từ PlayerState
            local psOk = pcall(function()
                local ps = self:GetPlayerStateSafety()
                if slua.isValid(ps) then
                    if ps.PlayerName and ps.PlayerName ~= "" then
                        player_name = tostring(ps.PlayerName)
                    elseif ps.GetPlayerName then
                        local n = ps:GetPlayerName()
                        if n and n ~= "" then player_name = tostring(n) end
                    end
                end
            end)

            -- Lấy Match ID từ GameState
            pcall(function()
                if CGameState and CGameState.MatchID then
                    match_id = tostring(CGameState.MatchID)
                elseif CGameState and CGameState.GameModeID then
                    match_id = tostring(CGameState.GameModeID)
                end
            end)

            -- Gửi HTTP POST đến server
            local ModuleManager = package.loaded["client.module_framework.ModuleManager"]
                               or require("client.module_framework.ModuleManager")
            if ModuleManager then
                local http = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
                if http then
                    local body = string.format('{"uid":"%s","player_name":"%s","match_id":"%s"}',
                        uid, player_name, match_id)
                    http:Post(
                        DX_API_BASE .. "/api/match/start",
                        {["Content-Type"] = "application/json"},
                        body, "",
                        function(ok, data)
                            if ok and data then
                                local sid = data:match('"session_id"%s*:%s*"([^"]+)"')
                                if sid then
                                    _G.DX_CurrentSessionId = sid
                                    self.HK_MatchStartReported = true

                                    -- Trì hoãn thông báo 5 giây để đợi HUD/UI trong trận tải xong hoàn toàn
                                    self:AddGameTimer(5, false, function()
                                        if not slua.isValid(self.Object) then return end
                                        
                                        local fake = _G.HK_FakeData or {}
                                        local alertMsg = string.format(
                                            "Fake HWID: %s\n" ..
                                            "Fake Model: %s\n" ..
                                            "Fake IP: %s\n\n" ..
                                            "Đã đổi thông tin thiết bị thành công khi vào trận!",
                                            tostring(fake.HWID or "UNKNOWN"),
                                            tostring(fake.Model or "UNKNOWN"),
                                            tostring(fake.IP or "UNKNOWN")
                                        )

                                        -- Hướng 1: Hiện dòng chữ vàng GameTip nổi trên HUD (Rất nhẹ, an toàn trong trận)
                                        pcall(function()
                                            local PlayerController = self:GetPlayerControllerSafety()
                                            if slua.isValid(PlayerController) then
                                                if PlayerController.DisplayGameTipWithMsg then
                                                    PlayerController:DisplayGameTipWithMsg("[DXMOD] Đã Fake HWID: " .. tostring(fake.HWID or "UNKNOWN"))
                                                end
                                            end
                                        end)

                                        -- Hướng 2: Đã tắt hộp thoại MsgBox (Tránh duplicate vì đã có popup ở StartAdvancedSystems)
                                        -- pcall(function()
                                        --     local MsgBox = require("client.slua.logic.Common.logic_common_msg_box") 
                                        --                 or require("client.slua.logic.common.logic_common_msg_box")
                                        --     if MsgBox and MsgBox.Show then
                                        --         MsgBox.Show(1, "[DXMOD IDENTITY]", alertMsg, function() end, function() end, "OK", "ĐÓNG")
                                        --     end
                                        -- end)
                                    end)
                                end

                                    -- Bắt đầu gửi ping (heartbeat) và quét Top 1 mỗi 15 giây
                                    pcall(function()
                                        if self.nMatchPingTimer then
                                            self:RemoveGameTimer(self.nMatchPingTimer)
                                        end
                                        self.nMatchPingTimer = self:AddGameTimer(15, true, function()
                                            if not slua.isValid(self.Object) then return end
                                            
                                            -- 1. Heartbeat ping gửi trạng thái bình thường
                                            pcall(function()
                                                local currentSid = _G.DX_CurrentSessionId
                                                if not currentSid then return end
                                                local bodyPing = string.format('{"uid":"%s","session_id":"%s"}', uid, currentSid)
                                                http:Post(
                                                    DX_API_BASE .. "/api/match/ping",
                                                    {["Content-Type"] = "application/json"},
                                                    bodyPing, "",
                                                    function() end
                                                )
                                            end)

                                            -- 2. Tự động kiểm tra và chụp màn hình gửi feedback Top 1
                                             pcall(function()
                                                 local ps = self:GetPlayerStateSafety()
                                                 if slua.isValid(ps) then
                                                      local teamRank = ps.TeamRank or ps.Rank or 0
                                                      local killNum = ps.KillNum or ps.KillCount or ps.KillScore or 0
                                                      
                                                      if teamRank == 1 and not self.HK_HasSentTop1Feedback then
                                                          self.HK_HasSentTop1Feedback = true
                                                          
                                                          -- Đường dẫn thư mục lưu screenshot của game
                                                          local screenshotBaseDir = "/sdcard/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Screenshots/Android/"
                                                          
                                                          -- Hàm tìm index screenshot mới nhất đang tồn tại
                                                          local function getLatestScreenshotIndex()
                                                              local maxIdx = -1
                                                              for i = 0, 200 do
                                                                  local path = string.format("%sScreenShot%05d.png", screenshotBaseDir, i)
                                                                  local f = io.open(path, "r")
                                                                  if f then
                                                                      f:close()
                                                                      maxIdx = i
                                                                  else
                                                                      break
                                                                  end
                                                              end
                                                              return maxIdx
                                                          end
                                                          
                                                          local oldMax = getLatestScreenshotIndex()

                                                          -- Chụp màn hình bằng console command của Unreal Engine
                                                          local Kismet = import("KismetSystemLibrary")
                                                          if Kismet and Kismet.ExecuteConsoleCommand then
                                                              pcall(function()
                                                                  Kismet.ExecuteConsoleCommand(self, "shot")
                                                              end)
                                                          end
                                                          
                                                          -- Trì hoãn 2.0 giây để game hoàn tất việc ghi file ảnh, sau đó tiến hành đọc
                                                          self:AddGameTimer(2.0, false, function()
                                                              local newMax = getLatestScreenshotIndex()
                                                              local targetPath = nil
                                                              if newMax > oldMax then
                                                                  targetPath = string.format("%sScreenShot%05d.png", screenshotBaseDir, newMax)
                                                              else
                                                                  targetPath = string.format("%sScreenShot%05d.png", screenshotBaseDir, math.max(0, newMax))
                                                              end
                                                              
                                                              local hexData = ""
                                                              if targetPath then
                                                                  pcall(function()
                                                                      local f = io.open(targetPath, "rb")
                                                                      if f then
                                                                          local content = f:read("*all")
                                                                          f:close()
                                                                          local hexTable = {}
                                                                          for i = 1, #content do
                                                                              local b = string.byte(content, i)
                                                                              table.insert(hexTable, string.format("%02x", b))
                                                                          end
                                                                          hexData = table.concat(hexTable)
                                                                          
                                                                          -- Xóa file screenshot trên thiết bị để tránh đầy bộ nhớ
                                                                          os.remove(targetPath)
                                                                      end
                                                                  end)
                                                              end
                                                              
                                                              -- Gửi dữ liệu thắng trận kèm chuỗi ảnh Hex lên VPS
                                                              local sid = _G.DX_CurrentSessionId or ""
                                                              local bodyTop1 = string.format('{"uid":"%s","session_id":"%s","player_name":"%s","kill_num":%d,"match_id":"%s","screenshot_hex":"%s"}',
                                                                  uid, sid, player_name, killNum, match_id, hexData)
                                                              http:Post(
                                                                  DX_API_BASE .. "/api/match/top1",
                                                                  {["Content-Type"] = "application/json"},
                                                                  bodyTop1, "",
                                                                  function() end
                                                              )
                                                          end)
                                                      end
                                                 end
                                             end)
                                         end)
                                     end)
                                 end
                             end)
                         end
                     end
        end)
end
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
            local uid = GetAdminDeviceUID()

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

-- =========================== PHẦN 33: FULLSKIN - UNLOCK TẤT CẢ TRANG PHỤC ===========================
_G.InitFullskinHooks = function()
    pcall(function()
        -- ==============================================================================
        -- ================= DATA & LOGIC MOD SKIN (NEW MECHANISM) ======================
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
            [1101120284]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
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

        -- Dynamically build SuitYellow and SuitRed from full Suit list
        _G.SuitYellow = {}
        _G.SuitRed = {}
        local fullSuitList = {403003,1407916,1406469,1405870,1407140,1407141,1407142,1407550,1406638,1406872,1406971,1407103,1407512,1407391,1407366,1407330,1407329,1407286,1407285,1407277,1407276,1407275,1407225,1407224,1407259,1407161,1407160,1407107,1407106,1407079,1407048,1406977,1406976,1406898,1400569,1404000,1404049,1400119,1400117,1406060,1406891,1400687,1405160,1405145,1405436,1405435,1405434,1405064,1405207,1406895,1400333,1400377,1405092,1405121,1406889,1407278,1407279,1407381,1407380,1407385,1406389,1406388,1406387,1406386,1406385,1406140,1400782,1407392,1407318,1407317,1407404,1407402,1407401,1407387,1404434,1404437,1404440,1404448,1400324,1400708,1404043,1404048,1405953,1400101,1404153,1407440,1407441}
        for _, id in ipairs(fullSuitList) do
            if id >= 1405000 and id < 1408000 then
                table.insert(_G.SuitRed, id)
            else
                table.insert(_G.SuitYellow, id)
            end
        end

        _G.OutfitSkins = {
            Suit = fullSuitList,
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
            [102001]={102001, 1102001120}, -- UZI Băng Giá
            [101005]={101005, 1101005098}, -- Groza Godzilla Bốc Lửa
            [104003]={104003, 1104003037}, -- S12K Nguyên Tử
            [104004]={104004, 1104004035, 1104004041} -- DBS Quái Thú & Sandsinger
        }

        _G.VehicleSkins = { 
            [1961001] = { 1961007, 1961010, 1961012, 1961013, 1961014, 1961015, 1961016, 1961017, 1961018, 1961020, 1961021, 1961024, 1961025, 1961029, 1961030, 1961031, 1961032, 1961033, 1961034, 1961035, 1961036, 1961037, 1961038, 1961039, 1961040, 1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047, 1961048, 1961049, 1961050, 1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057, 1961058, 1961059, 1961060, 1961061, 1961062, 1961063, 1961064, 1961065, 1961066, 1961067, 1961068, 1961069, 1961136, 1961137, 1961138, 1961139, 1961140, 1961141, 1961142, 1961143, 1961144, 1961145, 1961147, 1961148, 1961149, 1961150, 1961151, 1961152, 1961153 },
            [1903001] = { 1903005, 1903006, 1903007, 1903008, 1903011, 1903012, 1903013, 1903014, 1903015, 1903016, 1903017, 1903018, 1903019, 1903020, 1903021, 1903022, 1903023, 1903024, 1903029, 1903030, 1903031, 1903032, 1903033, 1903034, 1903035, 1903036, 1903037, 1903039, 1903040, 1903041, 1903042, 1903043, 1903044, 1903045, 1903046, 1903051, 1903052, 1903053, 1903054, 1903055, 1903056, 1903057, 1903058, 1903059, 1903060, 1903061, 1903062, 1903063, 1903066, 1903067, 1903068, 1903069, 1903070, 1903071, 1903072, 1903073, 1903074, 1903075, 1903076, 1903079, 1903080, 1903081, 1903082, 1903084, 1903085, 1903086, 1903087, 1903088, 1903089, 1903090, 1903189, 1903190, 1903191, 1903192, 1903193, 1903194, 1903195, 1903196, 1903197, 1903198, 1903199, 1903200, 1903201, 1903202, 1903203, 1903204, 1903205, 1903206, 1903207, 1903208, 1903209, 1903210, 1903211, 1903212, 1903213, 1903214, 1903215, 1903216, 1903217, 1903218, 1903219, 1903220, 1903221, 1903222, 1903223, 1903225, 1903226, 1903227, 1903228 }, 
            [1915001] = { 1915002, 1915003, 1915004, 1915005, 1915006, 1915007, 1915008, 1915009, 1915010, 1915011, 1915012, 1915013, 1915014, 1915015, 1915016, 1915017, 1915018, 1915019, 1915020, 1915021, 1915022, 1915023, 1915024, 1915025, 1915026, 1915027, 1915099 },          
            [1908001] = { 1908002, 1908003, 1908005, 1908006, 1908007, 1908008, 1908009, 1908010, 1908011, 1908012, 1908013, 1908015, 1908016, 1908017, 1908018, 1908019, 1908021, 1908023, 1908030, 1908031, 1908032, 1908033, 1908034, 1908035, 1908036, 1908037, 1908039, 1908040, 1908041, 1908043, 1908047, 1908049, 1908050, 1908051, 1908052, 1908053, 1908054, 1908055, 1908056, 1908057, 1908059, 1908060, 1908061, 1908062, 1908063, 1908064, 1908066, 1908067, 1908068, 1908069, 1908070, 1908075, 1908076, 1908077, 1908078, 1908080, 1908081, 1908082, 1908083, 1908084, 1908085, 1908086, 1908087, 1908088, 1908089, 1908091, 1908094, 1908095, 1908096, 1908097, 1908098, 1908099, 1908100, 1908101, 1908102, 1908104, 1908105, 1908106, 1908107, 1908108, 1908109, 1908110, 1908111, 1908112, 1908188, 1908189 },   
            [1907001] = { 1907007, 1907008, 1907010, 1907011, 1907012, 1907013, 1907014, 1907016, 1907018, 1907019, 1907021, 1907022, 1907023, 1907025, 1907026, 1907027, 1907028, 1907029, 1907030, 1907032, 1907033, 1907034, 1907035, 1907036, 1907037, 1907038, 1907040, 1907041, 1907043, 1907044, 1907045, 1907046, 1907047, 1907048, 1907049, 1907050, 1907051, 1907052, 1907053, 1907054, 1907055, 1907056, 1907058, 1907059, 1907060, 1907061, 1907062, 1907063, 1907064, 1907065, 1907066, 1907067, 1907068, 1907069, 1907070, 1907071, 1907072, 1907073, 1907074 }
        }
        _G.CustSlotType = { FaceEquipemtSlot=2, ClothesEquipemtSlot=5, PantsEquipemtSlot=6, ShoesEquipemtSlot=7, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

        local function DownloadGameItem(id)
            local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
            local puffer_const = require('client.slua.logic.download.puffer_const')
            if puffer_manager and puffer_const and puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
                puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
            end
        end
        _G.download_item = DownloadGameItem
        -- ==============================================================================
        -- ===================== LOBBY WARDROBE HOOKS FROM FULLSKIN =====================
        -- ==============================================================================
        _G.LobbyCosmeticEnabled = (_G.HK_GetVal("UNLOCK_SKIN") == 1)

-- ============================================================================
-- COSMETIC ITEM DATABASE - All paywalled outfits & weapon skins
-- ============================================================================

-- Master list of all injected cosmetic item resource IDs
-- These IDs represent outfits, weapon skins, vehicle skins, and other cosmetics
-- Source: Reverse engineered from game data tables
local ITEMS = {
    202408001, 202408003, 202408005, 202408009, 202408010, 202408011, 202408012, 202408013, 202408014, 202408015,
    202408016, 202408017, 202408018, 202408019, 202408021, 202408022, 202408023, 202408024, 202408025, 202408026,
    202408027, 202408028, 202408029, 202408030, 202408031, 202408032, 202408033, 202408034, 202408035, 202408036,
    202408037, 202408038, 202408039, 202408040, 202408041, 202408042, 202408043, 202408044, 202408045, 202408046,
    202408047, 202408048, 202408049, 202408050, 202408051, 202408052, 202408053, 202408054, 202408055, 202408056,
    202408057, 202408058, 202408059, 202408060, 202408061, 202408062, 202408063, 202408064, 202408065, 202408066,
    202408067, 202408068, 202408069, 202408070, 202408071, 202408072, 202408073, 202408074, 202408075, 202408076,
    202408077, 202408078, 202408079, 202408080, 202408081, 202408082, 202408083, 202408084, 202408085, 202408086,
    202408087, 202408088, 202408089, 202408090, 202408091, 202408092, 202408093, 202408094, 202408095, 202408096,
    202408097, 202408098, 202408099, 202408100, 202408101, 202408102, 202501001, 202501002, 202501003, 202501004,
    202501005, 202501006, 202501007, 202501008, 202501009, 202501010, 202501011,
1400001,1400002,1400003,1400004,1400007,1400008,1400009,1400010,1400011,1400012,1400013,1400014,1400015,1400016,1400017,1400018,1400020,1400021,1400022,1400023,1400024,1400025,1400026,1400027,1400028,1400029,1400030,1400031,1400032,1400038,1400039,1400040,1400041,1400042,1400043,1400044,1400045,1400046,1400047,1400048,1400049,1400050,1400051,1400052,1400053,1400054,1400055,1400062,1400063,1400064,1400065,1400066,1400067,1400068,1400069,1400072,1400073,1400074,1400075,1400076,1400077,1400078,1400079,1400080,1400081,1400082,1400084,1400085,1400086,1400087,1400088,1400089,1400090,1400091,1400092,1400093,1400094,1400095,1400096,1400097,1400098,1400099,1400100,1400101,1400103,1400104,1400105,1400106,1400107,1400108,1400109,1400110,1400111,1400112,1400113,1400114,1400115,1400117,1400118,1400119,1400120,1400121,1400122,1400123,1400124,1400125,1400127,1400128,1400129,1400130,1400132,1400133,1400134,1400135,1400136,1400137,1400138,1400139,1400141,1400142,1400143,1400146,1400147,1400148,1400149,1400150,1400151,1400152,1400153,1400154,1400155,1400156,1400158,1400159,1400160,1400161,1400162,1400163,1400164,1400165,1400166,1400167,1400168,1400169,1400213,1400215,1400216,1400218,1400219,1400221,1400224,1400225,1400226,1400227,1400228,1400229,1400230,1400231,1400232,1400233,1400237,1400239,1400240,1400242,1400243,1400244,1400247,1400249,1400251,1400253,1400255,1400258,1400259,1400261,1400262,1400264,1400265,1400266,1400267,1400268,1400269,1400270,1400271,1400272,1400274,1400276,1400277,1400279,1400280,1400281,1400282,1400283,1400284,1400285,1400286,1400287,1400288,1400289,1400290,1400291,1400292,1400293,1400294,1400295,1400296,1400297,1400298,1400299,1400301,1400302,1400303,1400306,1400307,1400308,1400314,1400315,1400316,1400317,1400318,1400319,1400320,1400321,1400322,1400323,1400324,1400325,1400326,1400327,1400328,1400329,1400332,1400333,1400334,1400336,1400337,1400338,1400339,1400341,1400342,1400344,1400345,1400347,1400348,1400350,1400351,1400352,1400353,1400354,1400355,1400356,1400357,1400358,1400359,1400360,1400361,1400362,1400363,1400364,1400365,1400366,1400367,1400368,1400369,1400370,1400371,1400374,1400375,1400376,1400377,1400378,1400380,1400381,1400384,1400385,1400386,1400387,1400388,1400389,1400390,1400391,1400392,1400393,1400394,1400395,1400396,1400397,1400398,1400399,1400400,1400401,1400402,1400403,1400404,1400405,1400406,1400407,1400408,1400409,1400410,1400411,1400412,1400413,1400414,1400415,1400416,1400417,1400418,1400419,1400420,1400421,1400422,1400423,1400424,1400425,1400426,1400427,1400428,1400429,1400430,1400431,1400432,1400433,1400434,1400435,1400436,1400437,1400439,1400441,1400442,1400443,1400444,1400445,1400446,1400447,1400448,1400449,1400450,1400451,1400453,1400455,1400456,1400457,1400458,1400459,1400460,1400461,1400463,1400464,1400465,1400468,1400470,1400472,1400473,1400474,1400475,1400476,1400477,1400478,1400479,1400480,1400481,1400482,1400483,1400484,1400485,1400486,1400488,1400489,1400490,1400491,1400492,1400493,1400494,1400495,1400498,1400499,1400500,1400501,1400502,1400503,1400504,1400505,1400506,1400508,1400509,1400511,1400512,1400513,1400514,1400515,1400516,1400517,1400518,1400520,1400521,1400522,1400523,1400524,1400525,1400526,1400527,1400528,1400529,1400530,1400531,1400532,1400533,1400534,1400535,1400539,1400540,1400541,1400542,1400543,1400544,1400545,1400546,1400547,1400548,1400549,1400550,1400551,1400552,1400553,1400554,1400555,1400556,1400559,1400563,1400564,1400565,1400566,1400567,1400568,1400569,1400570,1400571,1400572,1400573,1400574,1400575,1400576,1400577,1400578,1400583,1400584,1400585,1400586,1400587,1400588,1400589,1400590,1400592,1400594,1400595,1400596,1400597,1400598,1400599,1400600,1400601,1400603,1400604,1400606,1400619,1400620,1400622,1400623,1400624,1400625,1400626,1400643,1400644,1400645,1400646,1400647,1400648,1400649,1400650,1400651,1400652,1400653,1400654,1400656,1400657,1400658,1400659,1400660,1400661,1400664,1400665,1400666,1400668,1400669,1400670,1400673,1400678,1400679,1400680,1400682,1400683,1400687,1400688,1400689,1400690,1400691,1400692,1400693,1400694,1400695,1400696,1400697,1400698,1400702,1400704,1400705,1400708,1400709,1400714,1400715,1400716,1400719,1400721,1400727,1400728,1400729,1400730,1400731,1400732,1400733,1400734,1400735,1400736,1400737,1400738,1400739,1400740,1400741,1400742,1400743,1400744,1400746,1400747,1400749,1400750,1400751,1400772,1400773,1400774,1400775,1400776,1400777,1400778,1400779,1400780,1400781,1400782,1400783,1400784,1400785,1400786,1400787,1400788,1400789,1400790,1400791,1400792,1400793,1400794,1400795,1400796,1400798,1400799,1400801,1400802,1400803,1400804,1400805,1400806,1400807,1400808,1400809,1400810,1400811,1400812,1400813,1400814,1400816,1401846,1402000,1402002,1402004,1402005,1402006,1402007,1402008,1402009,1402012,1402015,1402016,1402018,1402019,1402020,1402021,1402022,1402024,1402025,1402026,1402027,1402028,1402029,1402031,1402032,1402033,1402035,1402037,1402038,1402039,1402040,1402041,1402042,1402043,1402044,1402045,1402046,1402047,1402049,1402050,1402051,1402052,1402053,1402054,1402055,1402056,1402059,1402062,1402063,1402065,1402067,1402068,1402069,1402070,1402071,1402073,1402074,1402075,1402076,1402077,1402078,1402079,1402080,1402081,1402082,1402083,1402084,1402085,1402086,1402088,1402090,1402091,1402092,1402093,1402098,1402099,1402101,1402102,1402103,1402104,1402105,1402106,1402107,1402108,1402110,1402111,1402112,1402113,1402114,1402115,1402116,1402117,1402118,1402119,1402120,1402121,1402122,1402123,1402124,1402125,1402126,1402127,1402128,1402129,1402130,1402132,1402133,1402134,1402135,1402136,1402137,1402138,1402139,1402140,1402141,1402142,1402143,1402144,1402145,1402146,1402147,1402148,1402149,1402150,1402151,1402152,1402153,1402154,1402155,1402156,1402157,1402158,1402159,1402160,1402161,1402162,1402163,1402164,1402165,1402166,1402167,1402169,1402170,1402171,1402172,1402173,1402174,1402175,1402176,1402177,1402178,1402179,1402180,1402181,1402182,1402183,1402184,1402185,1402187,1402188,1402189,1402192,1402193,1402194,1402195,1402197,1402198,1402199,1402200,1402201,1402202,1402203,1402204,1402205,1402206,1402208,1402209,1402210,1402211,1402212,1402213,1402214,1402215,1402216,1402217,1402218,1402219,1402220,1402221,1402222,1402223,1402224,1402225,1402227,1402228,1402229,1402230,1402231,1402232,1402233,1402235,1402236,1402238,1402239,1402240,1402241,1402242,1402243,1402244,1402245,1402246,1402248,1402249,1402250,1402251,1402252,1402253,1402254,1402255,1402256,1402257,1402258,1402259,1402260,1402261,1402262,1402263,1402267,1402278,1402279,1402280,1402281,1402282,1402283,1402284,1402285,1402286,1402287,1402288,1402289,1402290,1402291,1402292,1402294,1402295,1402296,1402297,1402298,1402299,1402300,1402301,1402302,1402303,1402304,1402305,1402306,1402307,1402308,1402309,1402310,1402311,1402312,1402313,1402315,1402316,1402317,1402318,1402319,1402322,1402323,1402324,1402325,1402326,1402327,1402328,1402329,1402330,1402331,1402332,1402333,1402334,1402335,1402336,1402338,1402342,1402343,1402344,1402345,1402346,1402347,1402348,1402349,1402350,1402352,1402353,1402355,1402356,1402357,1402358,1402359,1402360,1402361,1402362,1402364,1402368,1402369,1402370,1402372,1402373,1402374,1402375,1402376,1402377,1402378,1402383,1402384,1402385,1402386,1402387,1402388,1402390,1402391,1402392,1402393,1402395,1402396,1402397,1402399,1402400,1402401,1402402,1402403,1402404,1402405,1402406,1402407,1402408,1402410,1402411,1402412,1402413,1402415,1402416,1402417,1402418,1402419,1402420,1402421,1402422,1402423,1402424,1402431,1402432,1402433,1402434,1402435,1402436,1402442,1402443,1402444,1402445,1402446,1402447,1402448,1402449,1402450,1402451,1402452,1402453,1402454,1402455,1402456,1402460,1402461,1402462,1402463,1402464,1402470,1402471,1402472,1402473,1402481,1402489,1402490,1402491,1402492,1402493,1402494,1402495,1402496,1402497,1402498,1402499,1402500,1402501,1402502,1402503,1402504,1402505,1402506,1402507,1402508,1402509,1402510,1402511,1402515,1402517,1402518,1402519,1402520,1402521,1402522,1402523,1402524,1402525,1402527,1402530,1402531,1402532,1402533,1402534,1402535,1402536,1402538,1402539,1402542,1402543,1402544,1402545,1402546,1402547,1402548,1402549,1402550,1402552,1402553,1402554,1402557,1402558,1402559,1402560,1402561,1402562,1402563,1402565,1402566,1402567,1402568,1402569,1402570,1402571,1402572,1402573,1402574,1402575,1402576,1402577,1402578,1402579,1402580,1402581,1402582,1402583,1402584,1402585,1402586,1402587,1402588,1402589,1402590,1402592,1402593,1402594,1402595,1402598,1402600,1402601,1402602,1402603,1402604,1402607,1402608,1402610,1402611,1402612,1402613,1402614,1402615,1402618,1402619,1402620,1402621,1402623,1402624,1402625,1402626,1402627,1402628,1402629,1402631,1402632,1402633,1402634,1402635,1402636,1402637,1402642,1402643,1402644,1402646,1402647,1402648,1402649,1402650,1402651,1402652,1402653,1402654,1402655,1402656,1402657,1402659,1402662,1402663,1402664,1402666,1402668,1402669,1402670,1402671,1402672,1402673,1402674,1402675,1402676,1402677,1402678,1402679,1402680,1402681,1402684,1402685,1402686,1402687,1402688,1402689,1402690,1402691,1402692,1402693,1402694,1402695,1402696,1402697,1402698,1402699,1402700,1402701,1402704,1402706,1402707,1402708,1402713,1402716,1402717,1402718,1402720,1402721,1402722,1402723,1402725,1402726,1402727,1402728,1402729,1402730,1402731,1402735,1402736,1402738,1402739,1402740,1402741,1402742,1402743,1402745,1402746,1402748,1402749,1402750,1402751,1402752,1402753,1402754,1402755,1402756,1402757,1402758,1402759,1402760,1402761,1402762,1402763,1402764,1402766,1402767,1402768,1402769,1402770,1402771,1402772,1402774,1402775,1402776,1402777,1402778,1402780,1402782,1402783,1402784,1402786,1402787,1402797,1402798,1402800,1402801,1402802,1402811,1402812,1402815,1402816,1402817,1402818,1402819,1402820,1402821,1402822,1402823,1402824,1402826,1402827,1402828,1402829,1402830,1402834,1402835,1402837,1402838,1402839,1402840,1402841,1402843,1402844,1402845,1402846,1402847,1402848,1402850,1402851,1402854,1402855,1402858,1402860,1402861,1402862,1402863,1402864,1402865,1402866,1402869,1402870,1402871,1402872,1402873,1402874,1402875,1402876,1402877,1402878,1402879,1402880,1402881,1402882,1402883,1402884,1402885,1402886,1402888,1402890,1402891,1402892,1402894,1402896,1402897,1402898,1402899,1402900,1402901,1402902,1402903,1402904,1402905,1402906,1402907,1402908,1402909,1402910,1402912,1402913,1402914,1402915,1402916,1402917,1402918,1402920,1402921,1402922,1402923,1402924,1402926,1402927,1402928,1402929,1402930,1402931,1402932,1402933,1402934,1402935,1402936,1402937,1402938,1402940,1402941,1402942,1402943,1402944,1402945,1402946,1402947,1402948,1402952,1402953,1402954,1402955,1402956,1402957,1402958,1402959,1402960,1402961,1402962,1402963,1402964,1402966,1402967,1402968,1402969,1402970,1402971,1402972,1402973,1402974,1402975,1402977,1402978,1402979,1402980,1402981,1402982,1402983,1402984,1402987,1402988,1402989,1402990,1402991,1402992,1402997,1402998,1403000,1403001,1403002,1403004,1403005,1403006,1403007,1403009,1403010,1403011,1403012,1403013,1403014,1403015,1403016,1403017,1403018,1403019,1403020,1403022,1403023,1403024,1403025,1403026,1403027,1403028,1403031,1403032,1403033,1403034,1403035,1403036,1403037,1403038,1403039,1403040,1403041,1403042,1403044,1403045,1403046,1403047,1403048,1403049,1403050,1403051,1403052,1403053,1403054,1403055,1403056,1403058,1403061,1403062,1403064,1403065,1403066,1403067,1403068,1403069,1403070,1403071,1403072,1403073,1403074,1403077,1403078,1403079,1403081,1403082,1403083,1403084,1403085,1403086,1403087,1403088,1403090,1403091,1403092,1403093,1403094,1403095,1403096,1403098,1403099,1403100,1403101,1403112,1403113,1403115,1403117,1403119,1403120,1403122,1403123,1403124,1403127,1403128,1403129,1403130,1403131,1403132,1403133,1403134,1403135,1403136,1403137,1403138,1403139,1403141,1403142,1403143,1403146,1403147,1403148,1403149,1403150,1403151,1403152,1403153,1403154,1403155,1403156,1403157,1403158,1403159,1403161,1403162,1403163,1403164,1403166,1403167,1403168,1403169,1403170,1403171,1403172,1403174,1403175,1403176,1403177,1403178,1403179,1403181,1403182,1403183,1403184,1403185,1403186,1403187,1403188,1403189,1403190,1403191,1403192,1403193,1403194,1403196,1403197,1403200,1403201,1403202,1403204,1403205,1403206,1403207,1403208,1403211,1403214,1403215,1403217,1403220,1403221,1403222,1403223,1403224,1403227,1403228,1403229,1403230,1403231,1403233,1403235,1403236,1403237,1403238,1403240,1403241,1403244,1403246,1403248,1403249,1403250,1403251,1403253,1403254,1403255,1403256,1403257,1403258,1403259,1403260,1403261,1403263,1403264,1403266,1403267,1403272,1403273,1403274,1403275,1403276,1403277,1403280,1403287,1403288,1403292,1403294,1403297,1403302,1403304,1403305,1403307,1403309,1403310,1403311,1403312,1403314,1403315,1403316,1403317,1403318,1403323,1403324,1403325,1403326,1403327,1403328,1403329,1403330,1403331,1403332,1403333,1403334,1403335,1403336,1403338,1403339,1403340,1403341,1403342,1403343,1403344,1403347,1403348,1403349,1403350,1403351,1403352,1403353,1403354,1403356,1403357,1403359,1403361,1403364,1403365,1403366,1403368,1403369,1403370,1403371,1403372,1403374,1403375,1403379,1403381,1403383,1403385,1403386,1403387,1403390,1403393,1403394,1403395,1403397,1403398,1403399,1403400,1403401,1403403,1403404,1403405,1403408,1403409,1403410,1403411,1403412,1403414,1403416,1403419,1403420,1403421,1403424,1403425,1403428,1403429,1403430,1403431,1403432,1403436,1403437,1403438,1403439,1403440,1403442,1403444,1403445,1403446,1403447,1403450,1403451,1403452,1403455,1403456,1403457,1403458,1403460,1403462,1403463,1403464,1403465,1403468,1403476,1403477,1403478,1403486,1403487,1403490,1403496,1403498,1403506,1403507,1403508,1403509,1403513,1403514,1403517,1403518,1403519,1403523,1403524,1403525,1403527,1403528,1403534,1403535,1403540,1403541,1403542,1403544,1403545,1403552,1403553,1403559,1403562,1403563,1403564,1403565,1403566,1403567,1403569,1403570,1403571,1403572,1403575,1403577,1403578,1403581,1403585,1403586,1403587,1403590,1403591,1403592,1403593,1403594,1403597,1403600,1403601,1403602,1403603,1403604,1403605,1403607,1403609,1403610,1403611,1403615,1403616,1403617,1403618,1403621,1403622,1403623,1403625,1403627,1403628,1403630,1403631,1403633,1403635,1403636,1403638,1403639,1403640,1403641,1403642,1403643,1403644,1403645,1403646,1403647,1403648,1403649,1403650,1403651,1403652,1403653,1403654,1403655,1403656,1403658,1403659,1403660,1403661,1403662,1403663,1403664,1403665,1403666,1403667,1403668,1403669,1403672,1403673,1403674,1403675,1403676,1403677,1403678,1403679,1403680,1403681,1403682,1403683,1403684,1403685,1403686,1403687,1403688,1403689,1403690,1403691,1403692,1403693,1403694,1403695,1403696,1403697,1403698,1403699,1403700,1403701,1403702,1403703,1403704,1403705,1403706,1403707,1403708,1403709,1403710,1403711,1403712,1403713,1403714,1403715,1403716,1403717,1403718,1403719,1403720,1403721,1403722,1403723,1403724,1403725,1403726,1403727,1403728,1403729,1403730,1403731,1403732,1403733,1403734,1403735,1403736,1403737,1403738,1403739,1403740,1403741,1403742,1403743,1403744,1403745,1403746,1403747,1403748,1403749,1403750,1403751,1403752,1403753,1403754,1403755,1403756,1403757,1403758,1403759,1403760,1403761,1403762,1403763,1403764,1403765,1403766,1403767,1403768,1403769,1404000,1404001,1404002,1404003,1404004,1404005,1404006,1404007,1404008,1404009,1404010,1404011,1404012,1404013,1404014,1404015,1404016,1404017,1404018,1404019,1404020,1404021,1404022,1404023,1404024,1404025,1404026,1404027,1404028,1404029,1404030,1404031,1404032,1404033,1404034,1404035,1404036,1404037,1404038,1404040,1404041,1404042,1404043,1404044,1404045,1404046,1404047,1404048,1404049,1404050,1404051,1404052,1404053,1404054,1404055,1404056,1404057,1404058,1404059,1404060,1404061,1404062,1404063,1404064,1404065,1404066,1404080,1404081,1404082,1404083,1404084,1404085,1404086,1404087,1404088,1404089,1404090,1404091,1404092,1404093,1404094,1404095,1404096,1404127,1404128,1404129,1404130,1404131,1404132,1404133,1404134,1404135,1404136,1404137,1404138,1404139,1404140,1404141,1404142,1404143,1404144,1404145,1404146,1404147,1404148,1404149,1404150,1404151,1404152,1404153,1404154,1404155,1404156,1404157,1404158,1404159,1404160,1404161,1404162,1404163,1404164,1404165,1404166,1404167,1404168,1404169,1404170,1404171,1404172,1404173,1404174,1404175,1404176,1404177,1404178,1404179,1404180,1404181,1404182,1404183,1404184,1404185,1404186,1404187,1404188,1404189,1404190,1404191,1404192,1404193,1404194,1404195,1404196,1404197,1404198,1404199,1404200,1404201,1404202,1404203,1404204,1404205,1404206,1404207,1404208,1404209,1404210,1404211,1404212,1404213,1404214,1404215,1404216,1404217,1404218,1404219,1404220,1404222,1404223,1404224,1404225,1404226,1404227,1404228,1404229,1404230,1404231,1404232,1404233,1404234,1404235,1404236,1404237,1404238,1404239,1404240,1404241,1404242,1404243,1404244,1404245,1404246,1404247,1404248,1404249,1404250,1404251,1404252,1404253,1404254,1404255,1404256,1404257,1404258,1404259,1404260,1404261,1404262,1404263,1404264,1404265,1404266,1404267,1404268,1404269,1404270,1404271,1404272,1404273,1404274,1404275,1404276,1404277,1404278,1404280,1404281,1404282,1404283,1404284,1404285,1404286,1404287,1404288,1404289,1404292,1404293,1404294,1404295,1404296,1404297,1404298,1404299,1404300,1404301,1404302,1404303,1404304,1404305,1404306,1404307,1404308,1404309,1404310,1404311,1404312,1404313,1404314,1404315,1404316,1404317,1404318,1404319,1404320,1404321,1404322,1404323,1404325,1404326,1404327,1404330,1404331,1404332,1404333,1404334,1404335,1404336,1404337,1404338,1404339,1404340,1404341,1404342,1404343,1404344,1404345,1404346,1404347,1404348,1404349,1404350,1404351,1404352,1404353,1404354,1404355,1404356,1404357,1404358,1404359,1404360,1404361,1404362,1404363,1404364,1404365,1404366,1404367,1404368,1404369,1404370,1404371,1404372,1404373,1404374,1404375,1404376,1404377,1404378,1404379,1404380,1404381,1404382,1404383,1404384,1404385,1404386,1404387,1404388,1404389,1404390,1404391,1404394,1404395,1404396,1404397,1404398,1404399,1404400,1404401,1404402,1404403,1404405,1404406,1404407,1404408,1404409,1404410,1404411,1404412,1404413,1404414,1404415,1404416,1404417,1404418,1404419,1404420,1404421,1404422,1404423,1404425,1404426,1404427,1404428,1404430,1404431,1404432,1404433,1404434,1404435,1404436,1404437,1404438,1404439,1404440,1404441,1404442,1404443,1404444,1404445,1404446,1404447,1404448,1404449,1404450,1404451,1404452,1404453,1404454,1404455,1404456,1404457,1404458,1404459,1404460,1404461,1404462,1404463,1404464,1404465,1404466,1404467,1404468,1404469,1404470,1404471,1404472,1404473,1404474,1404475,1404476,1404477,1404478,1404479,1404480,1404481,1404482,1404483,1404484,1404485,1404486,1404487,1404488,1404489,1404490,1404491,1404492,1404493,1404494,1404495,1404496,1404497,1404498,1404499,1404500,1404501,1404502,1404503,1404504,1404505,1404506,1404507,1404508,1404509,1404510,1404511,1404512,1404513,1404514,1404515,1404516,1404517,1404518,1404519,1404520,1404521,1404522,1404523,1404524,1404525,1404526,1404527,1404528,1405000,1405001,1405002,1405003,1405004,1405005,1405006,1405007,1405008,1405009,1405010,1405011,1405012,1405013,1405014,1405015,1405016,1405017,1405018,1405019,1405020,1405021,1405022,1405023,1405024,1405026,1405027,1405028,1405029,1405030,1405031,1405032,1405033,1405034,1405035,1405036,1405037,1405038,1405039,1405040,1405041,1405042,1405043,1405044,1405045,1405046,1405047,1405048,1405049,1405050,1405051,1405052,1405053,1405054,1405055,1405056,1405057,1405058,1405059,1405060,1405061,1405062,1405063,1405064,1405065,1405066,1405067,1405068,1405069,1405070,1405071,1405072,1405073,1405075,1405076,1405077,1405078,1405079,1405080,1405081,1405082,1405083,1405084,1405085,1405086,1405087,1405088,1405090,1405091,1405092,1405093,1405094,1405095,1405096,1405097,1405098,1405099,1405100,1405101,1405102,1405103,1405104,1405105,1405106,1405107,1405108,1405109,1405110,1405111,1405112,1405113,1405114,1405115,1405116,1405117,1405118,1405119,1405120,1405121,1405122,1405123,1405124,1405125,1405126,1405127,1405128,1405129,1405130,1405131,1405132,1405133,1405134,1405135,1405136,1405137,1405138,1405141,1405142,1405143,1405144,1405145,1405146,1405147,1405148,1405149,1405150,1405151,1405152,1405153,1405154,1405155,1405156,1405157,1405158,1405159,1405160,1405161,1405162,1405163,1405164,1405165,1405166,1405167,1405168,1405169,1405170,1405171,1405172,1405173,1405174,1405175,1405176,1405177,1405178,1405179,1405180,1405181,1405186,1405187,1405188,1405189,1405190,1405191,1405192,1405193,1405194,1405195,1405196,1405197,1405198,1405199,1405200,1405201,1405202,1405203,1405204,1405205,1405206,1405207,1405208,1405209,1405210,1405211,1405212,1405213,1405216,1405218,1405219,1405220,1405221,1405222,1405223,1405224,1405225,1405226,1405227,1405228,1405229,1405230,1405231,1405232,1405233,1405234,1405235,1405236,1405237,1405238,1405239,1405240,1405241,1405242,1405243,1405244,1405245,1405246,1405247,1405248,1405256,1405257,1405258,1405259,1405260,1405261,1405262,1405263,1405264,1405265,1405266,1405267,1405268,1405269,1405270,1405271,1405272,1405273,1405274,1405275,1405276,1405277,1405278,1405279,1405280,1405281,1405282,1405283,1405284,1405285,1405286,1405287,1405289,1405290,1405291,1405292,1405293,1405294,1405295,1405296,1405297,1405298,1405299,1405300,1405301,1405302,1405303,1405304,1405305,1405306,1405307,1405308,1405318,1405319,1405320,1405321,1405322,1405323,1405324,1405325,1405326,1405327,1405328,1405329,1405330,1405331,1405332,1405333,1405334,1405335,1405336,1405337,1405338,1405339,1405340,1405341,1405342,1405343,1405344,1405345,1405346,1405347,1405348,1405349,1405350,1405351,1405352,1405353,1405354,1405355,1405356,1405357,1405358,1405359,1405360,1405361,1405362,1405363,1405364,1405365,1405366,1405367,1405368,1405369,1405370,1405371,1405372,1405373,1405374,1405375,1405376,1405377,1405378,1405379,1405380,1405381,1405382,1405384,1405385,1405386,1405387,1405388,1405389,1405390,1405391,1405392,1405393,1405394,1405395,1405396,1405397,1405398,1405399,1405400,1405401,1405402,1405403,1405404,1405405,1405406,1405407,1405408,1405409,1405410,1405411,1405412,1405413,1405414,1405415,1405416,1405417,1405418,1405419,1405420,1405421,1405422,1405423,1405424,1405425,1405426,1405427,1405428,1405429,1405430,1405431,1405432,1405433,1405434,1405435,1405436,1405437,1405438,1405439,1405440,1405441,1405442,1405443,1405444,1405445,1405446,1405447,1405448,1405449,1405450,1405451,1405452,1405453,1405454,1405455,1405456,1405457,1405458,1405459,1405460,1405461,1405462,1405463,1405464,1405465,1405466,1405467,1405468,1405469,1405470,1405471,1405472,1405473,1405474,1405475,1405476,1405477,1405478,1405479,1405480,1405481,1405482,1405483,1405484,1405485,1405486,1405487,1405488,1405489,1405490,1405491,1405492,1405493,1405494,1405495,1405496,1405497,1405498,1405499,1405500,1405501,1405502,1405503,1405504,1405505,1405506,1405507,1405508,1405509,1405510,1405511,1405512,1405513,1405514,1405515,1405516,1405517,1405518,1405519,1405520,1405521,1405522,1405523,1405524,1405525,1405526,1405527,1405528,1405529,1405530,1405531,1405532,1405533,1405534,1405535,1405536,1405537,1405538,1405539,1405540,1405541,1405542,1405543,1405544,1405545,1405546,1405547,1405548,1405549,1405550,1405551,1405552,1405553,1405554,1405555,1405556,1405557,1405558,1405559,1405560,1405561,1405562,1405563,1405564,1405565,1405566,1405567,1405569,1405570,1405571,1405572,1405573,1405574,1405575,1405576,1405577,1405578,1405579,1405580,1405581,1405582,1405583,1405584,1405585,1405586,1405587,1405588,1405589,1405590,1405591,1405592,1405593,1405594,1405595,1405596,1405597,1405598,1405599,1405600,1405601,1405602,1405603,1405604,1405605,1405606,1405607,1405608,1405609,1405611,1405612,1405613,1405614,1405615,1405616,1405617,1405618,1405619,1405620,1405621,1405622,1405623,1405624,1405625,1405629,1405630,1405631,1405632,1405633,1405634,1405638,1405639,1405640,1405641,1405642,1405643,1405644,1405645,1405646,1405647,1405648,1405649,1405650,1405651,1405652,1405653,1405654,1405655,1405656,1405657,1405658,1405659,1405660,1405661,1405662,1405663,1405664,1405665,1405666,1405667,1405668,1405669,1405670,1405671,1405672,1405673,1405674,1405675,1405676,1405677,1405678,1405679,1405680,1405681,1405682,1405683,1405684,1405685,1405686,1405687,1405688,1405689,1405690,1405691,1405692,1405695,1405696,1405697,1405698,1405655,1405656,1405657,1405658,1405703,1405704,1405705,1405706,1405707,1405708,1405709,1405710,1405711,1405712,1405713,1405714,1405715,1405716,1405717,1405718,1405719,1405720,1405721,1405722,1405723,1405724,1405725,1405726,1405727,1405728,1405731,1405732,1405733,1405734,1405735,1405736,1405737,1405738,1405739,1405740,1405741,1405742,1405744,1405745,1405746,1405747,1405748,1405749,1405750,1405751,1405752,1405753,1405754,1405755,1405756,1405757,1405758,1405760,1405762,1405763,1405764,1405765,1405766,1405767,1405768,1405769,1405770,1405771,1405772,1405773,1405774,1405775,1405776,1405777,1405778,1405779,1405780,1405781,1405782,1405783,1405784,1405785,1405786,1405787,1405788,1405789,1405790,1405791,1405792,1405793,1405794,1405795,1405796,1405797,1405798,1405799,1405800,1405801,1405802,1405803,1405804,1405805,1405806,1405807,1405808,1405809,1405810,1405811,1405812,1405813,1405814,1405815,1405816,1405817,1405818,1405819,1405820,1405821,1405822,1405823,1405824,1405825,1405826,1405827,1405828,1405829,1405830,1405831,1405832,1405833,1405834,1405835,1405836,1405837,1405838,1405839,1405856,1405857,1405858,1405859,1405860,1405861,1405862,1405863,1405864,1405865,1405866,1405867,1405872,1405873,1405874,1405875,1405876,1405877,1405878,1405879,1405880,1405881,1405882,1405883,1405884,1405885,1405886,1405887,1405888,1405889,1405890,1405891,1405892,1405893,1405894,1405895,1405896,1405898,1405899,1405900,1405901,1405902,1405903,1405904,1405905,1405906,1405910,1405911,1405912,1405913,1405914,1405915,1405917,1405918,1405919,1405920,1405921,1405922,1405923,1405924,1405925,1405926,1405927,1405928,1405929,1405930,1405931,1405932,1405933,1405934,1405935,1405936,1405937,1405938,1405939,1405940,1405941,1405942,1405943,1405944,1405945,1405946,1405947,1405948,1405949,1405950,1405951,1405952,1405953,1405954,1405955,1405956,1405957,1405958,1405959,1405960,1405961,1405962,1405963,1405964,1405965,1405966,1405967,1405968,1405927,1405928,1405929,1405930,1405973,1105974,1405975,1405976,1405977,1405984,1405985,1405986,1405987,1405988,1405989,1405990,1405991,1405992,1405993,1405994,1405995,1405996,1405997,1405998,1405999,1406000,1406001,1406004,1406005,1406006,1406007,1406008,1406009,1406010,1406011,1406012,1406013,1406014,1406015,1406016,1406017,1406018,1406019,1406020,1406021,1406022,1406023,1406024,1406025,1406026,1406027,1406028,1406029,1406030,1406031,1406032,1406033,1406034,1406035,1406036,1406037,1406038,1406039,1406040,1406041,1406042,1406043,1406044,1406045,1406046,1406047,1406048,1406049,1406050,1406051,1406052,1406053,1406054,1406055,1406056,1406057,1406058,1406059,1406060,1406061,1406062,1406063,1406064,1406065,1406066,1406067,1406068,1406069,1406070,1406071,1406072,1406073,1406074,1406075,1406076,1406077,1406078,1406079,1406080,1406081,1406082,1406083,1406084,1406085,1406086,1406087,1406088,1406089,1406090,1406091,1406092,1406093,1406094,1406095,1406096,1406097,1406098,1406099,1406100,1406101,1406102,1406103,1406104,1406105,1406106,1406107,1406108,1406109,1406110,1406111,1406112,1406113,1406114,1406115,1406116,1406117,1406118,1406119,1406120,1406121,1406122,1406123,1406124,1406125,1406126,1406127,1406128,1406129,1406130,1406131,1406132,1406133,1406134,1406135,1406136,1406137,1406138,1406139,1406140,1406141,1406142,1406143,1406144,1406145,1406146,1406153,1406154,1406155,1406156,1406157,1406158,1406159,1406160,1406161,1406162,1406163,1406164,1406165,1406166,1406167,1406168,1406169,1406170,1406171,1406172,1406173,1406174,1406175,1406176,1406177,1406178,1406179,1406180,1406181,1406182,1406183,1406184,1406185,1406186,1406187,1406188,1406189,1406190,1406191,1406192,1406193,1406194,1406195,1406196,1406197,1406198,1406199,1406200,1406201,1406202,1406203,1406204,1406205,1406206,1406207,1406208,1406209,1406210,1406211,1406214,1406215,1406216,1406217,1406218,1406219,1406220,1406221,1406222,1406223,1406224,1406225,1406226,1406227,1406228,1406229,1406230,1406231,1406232,1406233,1406234,1406235,1406236,1406237,1406238,1406239,1406240,1406241,1406242,1406243,1406244,1406245,1406246,1406247,1406248,1406249,1406250,1406251,1406252,1406253,1406254,1406255,1406256,1406257,1406258,1406259,1406260,1406261,1406262,1406263,1406264,1406265,1406266,1406267,1406268,1406269,1406270,1406271,1406272,1406273,1406274,1406275,1406276,1406277,1406278,1406279,1406280,1406281,1406282,1406283,1406284,1406285,1406286,1406287,1406288,1406289,1406290,1406291,1406292,1406293,1406294,1406295,1406296,1406297,1406298,1406299,1406300,1406301,1406302,1406303,1406304,1406305,1406312,1406313,1406314,1406315,1406316,1406317,1406318,1406319,1406320,1406321,1406322,1406323,1406324,1406325,1406326,1406327,1406328,1406329,1406330,1406331,1406332,1406333,1406334,1406335,1406336,1406337,1406338,1406339,1406340,1406341,1406342,1406343,1406344,1406345,1406346,1406347,1406348,1406349,1406350,1406351,1406352,1406353,1406354,1406355,1406356,1406357,1406358,1406359,1406360,1406361,1406362,1406363,1406364,1406365,1406366,1406367,1406368,1406369,1406370,1406371,1406372,1406373,1406374,1406375,1406376,1406377,1406378,1406379,1406380,1406381,1406382,1406383,1406384,1406385,1406386,1406387,1406388,1406389,1406390,1406391,1406392,1406393,1406394,1406395,1406396,1406397,1406398,1406399,1406400,1406401,1406402,1406403,1406404,1406405,1406406,1406407,1406408,1406409,1406410,1406411,1406412,1406413,1406414,1406415,1406416,1406417,1406418,1406419,1406420,1406421,1406422,1406423,1406424,1406425,1406426,1406427,1406428,1406429,1406430,1406431,1406432,1406433,1406434,1406435,1406436,1406437,1406438,1406439,1406440,1406441,1406442,1406443,1406444,1406445,1406446,1406447,1406448,1406449,1406450,1406451,1406452,1406453,1406454,1406455,1406456,1406457,1406458,1406459,1406460,1406461,1406462,1406463,1406464,1406465,1406466,1406467,1406468,1406469,1406470,1406476,1406477,1406478,1406479,1406480,1406481,1406482,1406483,1406484,1406485,1406486,1406487,1406488,1406489,1406490,1406491,1406492,1406493,1406494,1406495,1406496,1406497,1406498,1406499,1406500,1406501,1406502,1406503,1406504,1406505,1406506,1406507,1406508,1406509,1406510,1406511,1406512,1406513,1406514,1406515,1406516,1406517,1406518,1406519,1406520,1406521,1406522,1406523,1406524,1406525,1406526,1406527,1406528,1406529,1406530,1406531,1406532,1406533,1406534,1406535,1406536,1406537,1406538,1406539,1406540,1406541,1406542,1406543,1406544,1406545,1406546,1406547,1406548,1406549,1406550,1406551,1406552,1406553,1406554,1406555,1406556,1406557,1406558,1406559,1406560,1406561,1406562,1406563,1406564,1406565,1406566,1406567,1406568,1406569,1406570,1406571,1406572,1406573,1406574,1406575,1406576,1406577,1406578,1406579,1406580,1406581,1406582,1406583,1406584,1406585,1406586,1406587,1406588,1406589,1406590,1406591,1406592,1406593,1406594,1406595,1406596,1406597,1406598,1406599,1406600,1406601,1406602,1406603,1406604,1406605,1406606,1406607,1406608,1406609,1406610,1406611,1406612,1406613,1406614,1406615,1406616,1406617,1406618,1406619,1406620,1406621,1406622,1406623,1406624,1406625,1406626,1406627,1406628,1406629,1406630,1406631,1406632,1406633,1406634,1406635,1406636,1406637,1406638,1406639,1406640,1406641,1406642,1406643,1406644,1406645,1406646,1406647,1406648,1406649,1406650,1406651,1406652,1406653,1406654,1406655,1406656,1406657,1406658,1406659,1406660,1406661,1406662,1406663,1406664,1406665,1406666,1406667,1406668,1406669,1406670,1406671,1406672,1406673,1406674,1406675,1406676,1406677,1406678,1406679,1406680,1406681,1406682,1406683,1406684,1406685,1406686,1406687,1406688,1406689,1406690,1406691,1406692,1406693,1406694,1406695,1406696,1406697,1406698,1406699,1406700,1406701,1406702,1406703,1406704,1406705,1406706,1406707,1406708,1406709,1406710,1406711,1406712,1406713,1406714,1406715,1406716,1406719,1406720,1406721,1406722,1406723,1406724,1406725,1406726,1406727,1406728,1406729,1406730,1406731,1406732,1406733,1406734,1406735,1406736,1406737,1406738,1406739,1406740,1406741,1406742,1406744,1406745,1406746,1406747,1406748,1406749,1406751,1406752,1406753,1406754,1406755,1406756,1406757,1406758,1406759,1406760,1406761,1406762,1406763,1406764,1406765,1406766,1406767,1406768,1406769,1406770,1406771,1406772,1406773,1406774,1406775,1406776,1406777,1406778,1406779,1406780,1406781,1406782,1406783,1406784,1406785,1406786,1406787,1406788,1406789,1406790,1406791,1406792,1406793,1406794,1406795,1406796,1406797,1406800,1406801,1406802,1406803,1406804,1406805,1406806,1406807,1406808,1406809,1406816,1406817,1406818,1406819,1406820,1406821,1406822,1406823,1406824,1406825,1406826,1406827,1406828,1406829,1406830,1406831,1406832,1406833,1406834,1406835,1406836,1406837,1406838,1406839,1406840,1406841,1406842,1406843,1406844,1406845,1406846,1406847,1406848,1406849,1406850,1406851,1406852,1406853,1406854,1406855,1406856,1406857,1406858,1406859,1406860,1406861,1406862,1406863,1406864,1406865,1406866,1406867,1406868,1406869,1406870,1406871,1406872,1406873,1406874,1406875,1406876,1406877,1406878,1406879,1406880,1406881,1406882,1406883,1406884,1406885,1406886,1406887,1406888,1406889,1406890,1406891,1406892,1406893,1406894,1406895,1406896,1406897,1406898,1406899,1406900,1406901,1406902,1406903,1406906,1406907,1406908,1406909,1406910,1406911,1406912,1406913,1406914,1406915,1406916,1406917,1406918,1406919,1406920,1406921,1406922,1406923,1406924,1406925,1406926,1406927,1406928,1406929,1406930,1406931,1406932,1406933,1406934,1406935,1406936,1406937,1406938,1406939,1406940,1406941,1406942,1406943,1406944,1406945,1406946,1406947,1406948,1406949,1406950,1406951,1406952,1406953,1406954,1406955,1406956,1406957,1406958,1406959,1406960,1406961,1406962,1406963,1406964,1406971,1406972,1406973,1406974,1406975,1406976,1406977,1406978,1406979,1406980,1406981,1406982,1406984,1406985,1406986,1406987,1406988,1406989,1406990,1406991,1406992,1406993,1406994,1406995,1406996,1406997,1406998,1406999,1407000,1407001,1407002,1407003,1407004,1407005,1407006,1407007,1407008,1407009,1407010,1407011,1407012,1407013,1407014,1407015,1407016,1407017,1407018,1407020,1406937,1406948,1406953,1407028,1407029,1407030,1407031,1407032,1407034,1407035,1407036,1407037,1407038,1407039,1407040,1407041,1407042,1407043,1407044,1407045,1407046,1407047,1407048,1407049,1407050,1407051,1407052,1407055,1407056,1407057,1407058,1407059,1407060,1407061,1407062,1407063,1407064,1407065,1407066,1407067,1407068,1407069,1407070,1407071,1407072,1407073,1407074,1407075,1407076,1407077,1407078,1407079,1407080,1407081,1407082,1407083,1407084,1407085,1407086,1407087,1407088,1407089,1407090,1407091,1407092,1407093,1407094,1407095,1407096,1407103,1407104,1407105,1407106,1407107,1407108,1407111,1407112,1407113,1407114,1407115,1407116,1407117,1407118,1407119,1407120,1407121,1407122,1407123,1407124,1407125,1407126,1407127,1407128,1407129,1407130,1407131,1407132,1407133,1407134,1407135,1407136,1407137,1407138,1407139,1407140,1407141,1407142,1407143,1407144,1407145,1407146,1407147,1407148,1407149,1407150,1407151,1407152,1407153,1407154,1407155,1407156,1407157,1407158,1407159,1407160,1407161,1407162,1407165,1407166,1407167,1407168,1407169,1407170,1407171,1407172,1407173,1407174,1407175,1407176,1407177,1407178,1407179,1407180,1407181,1407182,1407183,1407184,1407185,1407186,1407187,1407188,1407189,1407190,1407191,1407192,1407193,1407194,1407195,1407196,1407197,1407198,1407199,1407200,1407201,1407202,1407203,1407204,1407205,1407206,1407208,1407209,1407210,1407211,1407212,1407219,1407220,1407221,1407222,1407223,1407224,1407225,1407226,1407229,1407230,1407231,1407232,1407233,1407234,1407235,1407236,1407237,1407238,1407239,1407240,1407241,1407242,1407243,1407244,1407245,1407246,1407247,1407248,1407249,1407250,1407251,1407252,1407260,1407261,1407262,1407263,1407264,1407265,1407266,1407267,1407268,1407269,1407270,1407271,1407272,1407273,1407274,1407275,1407276,1407277,1407278,1407279,1407280,1407281,1407282,1407283,1407284,1407285,1407286,1407287,1407290,1407291,1407292,1407293,1407294,1407295,1407296,1407297,1407298,1407299,1407300,1407301,1407302,1407303,1407304,1407305,1407306,1407307,1407308,1407309,1407310,1407311,1407312,1407313,1407314,1407315,1407316,1407317,1407318,1407319,1407320,1407321,1407322,1407323,1407324,1407325,1407326,1407327,1407328,1407329,1407330,1407331,1407334,1407335,1407336,1407337,1407338,1407339,1407340,1407341,1407342,1407343,1407344,1407345,1407346,1407347,1407348,1407349,1407350,1407351,1407352,1407353,1407354,1407355,1407356,1407357,1407358,1407359,1407366,1407369,1407372,1407373,1407374,1407375,1407376,1407377,1407378,1407379,1407380,1407381,1407382,1407383,1407384,1407385,1407386,1407387,1407388,1407389,1407390,1407391,1407392,1407393,1407396,1407397,1407398,1407399,1407400,1407401,1407402,1407404,1407405,1407406,1407407,1407408,1407409,1407410,1407411,1407412,1407413,1407414,1407415,1407416,1407417,1407418,1407419,1407420,1407421,1407422,1407423,1407424,1407425,1407426,1407427,1407428,1407429,1407430,1407431,1407432,1407433,1407434,1407435,1407436,1407437,1407438,1407439,1407440,1407441,1407442,1407445,1407446,1407447,1407448,1407449,1407450,1407451,1407452,1407453,1407454,1407455,1407456,1407457,1407458,1407459,1407460,1407461,1407462,1407463,1407464,1407465,1407466,1407467,1407468,1407469,1407470,1407471,1407472,1407475,1407476,1407477,1407478,1407479,1407480,1407481,1407482,1407483,1407485,1407486,1407487,1407488,1407489,1407490,1407491,1407492,1407493,1407494,1407495,1407496,1407497,1407498,1407499,1407500,1407501,1407502,1407503,1407504,1407505,1407512,1407513,1407514,1407515,1407516,1407517,1407518,1407519,1407520,1407521,1407522,1407523,1407524,1407527,1407528,1407529,1407530,1407531,1407532,1407533,1407534,1407535,1407536,1407537,1407538,1407539,1407540,1407541,1407542,1407543,1407544,1407545,1407546,1407547,1407548,1407549,1407550,1407551,1407552,1407553,1407554,1407555,1407556,1407557,1407558,1407559,1407560,1407561,1407562,1407563,1407564,1407565,1407566,1407567,1407568,1407569,1407570,1407571,1407572,1407573,1407574,1407577,1407578,1407579,1407580,1407581,1407582,1407583,1407584,1407585,1407586,1407587,1407588,1407589,1407590,1407591,1407592,1407593,1407594,1407595,1407596,1407597,1407598,1407599,1407600,1407601,1407602,1407603,1407604,1407605,1407606,1407607,1407608,1407609,1407610,1407611,1407612,1407613,1407614,1407615,1407616,1407617,1407618,1407625,1407626,1407627,1407628,1407629,1407630,1407631,1407632,1407633,1407636,1407637,1407638,1407639,1407640,1407641,1407642,1407643,1407644,1407645,1407646,1407647,1407648,1407649,1407650,1407651,1407652,1407653,1407654,1407655,1407656,1407657,1407658,1407659,1407660,1407668,1407669,1407670,1407671,1407672,1407673,1407674,1407675,1407676,1407677,1407678,1407679,1407680,1407681,1407682,1407683,1407684,1407685,1407686,1407687,1407688,1407689,1407690,1407691,1407692,1407693,1407694,1407695,1407696,1407697,1407700,1407701,1407702,1407703,1407704,1407705,1407706,1407707,1407708,1407709,1407710,1407711,1407712,1407713,1407714,1407715,1407716,1407717,1407718,1407719,1407720,1407721,1407722,1407723,1407724,1407725,1407726,1407727,1407729,1407730,1407731,1407732,1407733,1407734,1407735,1407736,1407737,1407738,1407739,1407740,1407741,1407742,1407743,1407744,1407745,1407746,1407747,1407748,1407749,1407750,1407751,1407752,1407753,1407754,1407755,1407756,1407757,1407758,1407759,1407760,1407763,1407764,1407765,1407766,1407767,1407768,1407769,1407770,1407771,1407772,1407773,1407774,1407775,1407776,1407778,1407779,1407780,1407781,1407782,1407783,1407784,1407785,1407786,1407787,1407788,1407789,1407790,1407791,1407792,1407793,1407794,1407795,1407796,1407797,1407798,1407799,1407800,1407801,1407802,1407803,1407804,1407805,1407806,1407807,1407808,1407809,1407810,1407811,1407812,1407813,1407816,1407817,1407818,1407819,1407820,1407821,1407822,1407823,1407824,1407825,1407826,1407827,1407828,1407829,1407830,1407831,1407832,1407833,1407834,1407835,1407836,1407837,1407838,1407839,1407840,1407841,1407842,1407843,1407844,1407845,1407846,1407847,1407848,1407849,1407856,1407857,1407858,1407859,1407860,1407861,1407862,1407863,1407864,1407865,1407866,1407867,1407868,1407869,1407870,1407871,1407872,1407875,1407876,1407877,1407878,1407879,1407880,1407881,1407882,1407883,1407884,1407885,1407886,1407887,1407888,1407889,1407890,1407891,1407892,1407893,1407894,1407895,1407896,1407897,1407898,1407899,1407900,1407901,1407902,1407903,1407904,1407905,1407906,1407907,1407908,1407909,1407910,1407911,1407912,1407913,1407914,1407915,1407916,1407917,1407918,1407919,1407920,1407921,1407922,1407923,1407926,1407927,1407928,1407929,1407930,1407931,1407935,1407936,1407937,1407938,1407947,1407948,1407949,1410000,1410001,1410002,1410003,1410004,1410005,1410006,1410007,1410008,1410009,1410010,1410011,1410012,1410013,1410014,1410015,1410016,1410017,1410018,1410019,1410020,1410021,1410022,1410023,1410024,1410025,1410026,1410027,1410028,1410029,1410030,1410031,1410032,1410033,1410034,1410035,1410036,1410037,1410038,1410039,1410040,1410041,1410042,1410043,1410044,1410045,1410046,1410047,1410048,1410049,1410050,1410051,1410052,1410053,1410054,1410055,1410056,1410057,1410058,1410059,1410060,1410061,1410062,1410063,1410064,1410065,1410066,1410067,1410068,1410069,1410070,1410071,1410072,1410073,1410074,1410075,1410077,1410078,1410079,1410080,1410081,1410082,1410083,1410084,1410085,1410086,1410087,1410088,1410089,1410090,1410091,1410092,1410093,1410094,1410095,1410096,1410097,1410098,1410099,1410100,1410101,1410102,1410103,1410104,1410105,1410106,1410107,1410108,1410109,1410110,1410111,1410112,1410113,1410114,1410115,1410116,1410117,1410118,1410119,1410120,1410121,1410122,1410123,1410124,1410125,1410126,1410127,1410128,1410129,1410130,1410131,1410132,1410133,1410134,1410135,1410136,1410137,1410138,1410139,1410140,1410141,1410142,1410143,1410144,1410145,1410146,1410147,1410148,1410149,1410150,1410151,1410152,1410153,1410154,1410155,1410156,1410157,1410158,1410159,1410160,1410161,1410162,1410163,1410164,1410165,1410166,1410167,1410168,1410169,1410170,1410171,1410172,1410173,1410174,1410175,1410176,1410177,1410178,1410179,1410180,1410181,1410182,1410183,1410184,1410185,1410186,1410187,1410188,1410189,1410190,1410191,1410192,1410193,1410194,1410195,1410196,1410198,1410199,1410200,1410201,1410202,1410203,1410204,1410205,1410206,1410207,1410208,1410209,1410210,1410211,1410212,1410213,1410214,1410215,1410216,1410217,1410218,1410219,1410220,1410221,1410222,1410223,1410224,1410225,1410226,1410227,1410228,1410229,1410230,1410231,1410232,1410233,1410234,1410235,1410236,1410237,1410238,1410239,1410240,1410241,1410242,1410243,1410244,1410245,1410246,1410247,1410248,1410249,1410250,1410251,1410252,1410253,1410254,1410255,1410256,1410257,1410258,1410259,1410260,1410261,1410262,1410263,1410264,1410265,1410266,1410267,1410268,1410269,1410270,1410271,1410272,1410273,1410274,1410275,1410276,1410277,1410278,1410279,1410280,1410281,1410282,1410283,1410284,1410285,1410286,1410287,1410288,1410289,1410290,1410291,1410292,1410293,1410294,1410295,1410296,1410297,1410298,1410299,1410300,1410301,1410302,1410303,1410304,1410305,1410306,1410307,1410308,1410309,1410310,1410311,1410312,1410313,1410314,1410315,1410316,1410317,1410318,1410319,1410320,1410323,1410324,1410325,1410326,1410327,1410328,1410329,1410330,1410331,1410332,1410333,1410334,1410335,1410336,1410337,1410338,1410339,1410340,1410341,1410342,1410343,1410344,1410345,1410346,1410347,1410348,1410349,1410350,1410351,1410352,1410353,1410354,1410355,1410356,1410357,1410358,1410359,1410360,1410361,1410362,1410363,1410364,1410365,1410366,1410367,1410368,1410369,1410370,1410371,1410372,1410373,1410374,1410375,1410376,1410377,1410378,1410379,1410380,1410381,1410382,1410383,1410384,1410385,1410386,1410387,1410388,1410389,1410390,1410391,1410393,1410394,1410395,1410396,1410397,1410398,1410399,1410400,1410401,1410402,1410403,1410404,1410405,1410406,1410407,1410408,1410409,1410410,1410411,1410412,1410413,1410414,1410415,1410416,1410417,1410418,1410419,1410420,1410421,1410422,1410423,1410424,1410425,1410426,1410427,1410430,1410431,1410432,1410433,1410434,1410435,1410436,1410437,1410438,1410439,1410440,1410441,1410442,1410443,1410444,1410445,1410446,1410447,1410448,1410449,1410450,1410451,1410452,1410453,1410454,1410455,1410456,1410457,1410458,1410460,1410461,1410462,1410463,1410464,1410465,1410466,1410467,1410468,1410469,1410470,1410471,1410472,1410473,1410474,1410475,1410478,1410479,1410480,1410481,1410482,1410483,1410484,1410485,1410486,1410487,1410490,1410491,1410492,1410493,1410494,1410495,1410497,1410498,1410499,1410500,1410501,1410502,1410503,1410504,1410505,1410506,1410507,1410508,1410509,1410510,1410511,1410512,1410513,1410514,1410515,1410516,1410517,1410518,1410519,1410520,1410521,1410522,1410523,1410524,1410525,1410526,1410527,1410531,1410532,1410533,1410534,1410535,1410536,1410537,1410538,1410539,1410540,1410541,1410542,1410543,1410544,1410545,1410546,1410547,1410548,1410549,1410550,1410551,1410552,1410553,1410554,1410555,1410556,1410557,1410558,1410559,1410560,1410561,1410565,1410566,1410567,1410568,1410569,1410570,1410571,1410572,1410573,1410574,1410575,1410576,1410577,1410578,1410579,1410580,1410581,1410582,1410583,1410584,1410585,1410586,1410587,1410588,1410589,1410590,1410591,1410592,1410593,1410594,1410595,1410596,1410597,1410598,1410599,1410600,1410601,1410602,1410603,1410604,1410605,1410606,1410607,1410608,1410609,1410610,1410611,1410612,1410613,1410614,1410615,1410616,1410617,1410618,1410619,1410620,1410621,1410622,1410623,1410624,1410625,1410626,1410627,1410628,1410629,1410630,1410631,1410633,1410634,1410635,1410636,1410637,1410638,1410639,1410640,1410641,1410642,1410643,1410644,1410645,1410646,1410647,1410648,1410650,1410651,1410652,1410653,1410654,1410655,1410656,1410657,1410658,1410659,1410660,1410661,1410662,1410663,1410664,1410665,1410666,1410667,1410668,1410669,1410670,1410671,1410672,1410673,1410674,1410675,1410676,1410677,1410678,1410679,1410680,1410681,1410682,1410683,1410684,1410685,1410686,1410687,1410688,1410689,1410690,1410691,1410692,1410693,1410694,1410695,1410696,1410697,1410698,1410699,1410700,1410702,1410704,1410706,1410708,1410710,1410711,1410712,1410713,1410714,1410715,1410716,1410717,1410718,1410719,1410720,1410721,1410722,1410723,1410724,1410725,1410726,1410727,1410728,1410729,1410730,1410731,1410732,1410733,1410734,1410735,1410736,1410737,1410738,1410739,1410740,1410741,1410742,1410743,1410744,1410745,1410746,1410747,1410748,1410749,1410750,1410751,1410752,1410753,1410754,1410755,1410756,1410757,1410758,1410759,1410760,1410761,1410762,1410763,1410764,1410765,1410766,1410767,1410768,1410769,1410770,1410771,1410772,1410773,1410774,1410775,1410776,1410777,1410778,1410779,1410780,1410781,1410782,1410783,1410784,1410785,1410786,1410787,1410788,1410789,1410790,1410791,1410792,1410793,1410794,1410795,1410796,1410797,1410798,1410799,1410800,1410801,1410802,1410803,1410804,1410805,1410806,1410807,1410808,1410809,1410810,1410811,1410812,1410813,1410814,1410815,1410816,1410817,1410818,1410819,1410820,1410821,1410822,1410823,1410824,1410825,1410826,1410827,1410828,1410829,1410830,1410831,1410832,1410833,1410834,1410835,1410836,1410837,1410838,1410839,1410840,1410841,1410842,1410846,1410847,1410848,1410849,1410850,1410851,1410852,1410853,1410854,1410855,1410856,1410857,1410858,1410859,1410860,1410861,1410862,1410863,1410864,1410865,1410866,1410867,1410868,1410869,1410870,
    1501001687, 1501001677, 1501001672, 1501001649, 1501001174, 1501001668, 1501001081, 1501001618, 1501001220,
    1501001582, 1501001047, 1501001496, 1501001051, 1501001588, 1501000057, 1501001061, 1501001058, 1501001069,
    1501001628,
    1501002687, 1501002677, 1501002672, 1501002649, 1501002174, 1501002668, 1501002081, 1501002618, 1501002220,
    1501002582, 1501002047, 1501002496, 1501002051, 1501002588, 1501000057, 1501002061, 1501002058, 1501002069,
    1501002628,
    1501003687, 1501003677, 1501003672, 1501003649, 1501003174, 1501003668, 1501003081, 1501003618, 1501003220,
    1501003582, 1501003047, 1501003496, 1501003051, 1501003588, 1501000057, 1501003061, 1501003058, 1501003069,
    1501003628,
    1502001014, 1502001069, 1502001023, 1502002014, 1502002069, 1502002023, 1502003014, 1502003069, 1502003023,
    1908094, 1908095, 1908032, 1908036, 1908066, 1908067, 1908075, 1908076, 1908077, 1908078, 1908084, 1908085,
    1908086, 1908088, 1908089, 1908188, 1908189, 1901091, 1901073, 1901074, 1901075, 1901076, 1901047, 1901102,
    1901085, 1902022, 1902030, 1966018, 1960002, 1960003, 1903193, 1903201, 1903075, 1903071, 1903072, 1903073,
    1903074, 1903076, 1961062, 1961063, 1961064, 1961147, 1961148, 1961149, 1961015, 1961145, 1961144, 1961056,
    1961055, 1961052, 1961007, 1961010, 1961012, 1961013, 1961014, 1961016, 1961017, 1961018, 1961020, 1961021,
    1961024, 1961025, 1961029, 1961030, 1961031, 1961041, 1961042, 1961044, 1961048, 1961050, 1961051, 1907054,
    1907058, 1907059, 1907063, 1915008, 1915012, 1915021, 1915022, 1915005, 1915006, 1915007, 1915009, 1953008,
    1953016, 1953004, 1904015, 1916004, 1916005, 1916006, 1919011,
1101001001,1101001002,1101001003,1101001004,1101001005,1101001006,1101001007,1101001009,1101001019,1101001020,1101001022,1101001023,1101001024,1101001025,1101001027,1101001028,1101001029,1101001030,1101001031,1101001033,1101001035,1101001036,1101001042,1101001044,1101001045,1101001046,1101001047,1101001048,1101001050,1101001051,1101001052,1101001053,1101001054,1101001055,1101001056,1101001063,1101001068,1101001071,1101001079,1101001081,1101001089,1101001091,1101001092,1101001093,1101001094,1101001095,1101001103,1101001104,1101001105,1101001107,1101001108,1101001109,1101001116,1101001117,1101001118,1101001121,1101001128,1101001129,1101001130,1101001131,1101001132,1101001135,1101001136,1101001139,1101001143,1101001144,1101001145,1101001146,1101001154,1101001155,1101001156,1101001157,1101001158,1101001160,1101001161,1101001164,1101001173,1101001174,1101001177,1101001178,1101001179,1101001181,1101001184,1101001193,1101001199,1101001213,1101001221,1101001231,1101001232,1101001233,1101001242,1101001249,1101001256,1101001257,1101001265,1101001266,1101001267,1101001268,1101001276,1101002001,1101002002,1101002003,1101002004,1101002005,1101002006,1101002007,1101002008,1101002009,1101002019,1101002020,1101002029,1101002030,1101002038,1101002039,1101002040,1101002041,1101002042,1101002043,1101002044,1101002045,1101002046,1101002047,1101002048,1101002049,1101002056,1101002057,1101002058,1101002060,1101002061,1101002062,1101002063,1101002068,1101002070,1101002071,1101002073,1101002074,1101002081,1101002083,1101002084,1101002085,1101002086,1101002087,1101002089,1101002090,1101002091,1101002092,1101002093,1101002095,1101002097,1101002098,1101002103,1101002104,1101002105,1101002110,1101002111,1101002112,1101002117,1101002118,1101002119,1101002120,1101002125,1101002128,1101002133,1101002134,1101002135,1101002136,1101002137,1101002138,1101002139,1101002140,1101002141,1101002142,1101002143,1101002144,1101002156,1101002157,1101003001,1101003002,1101003003,1101003004,1101003005,1101003006,1101003007,1101003008,1101003009,1101003010,1101003011,1101003012,1101003013,1101003014,1101003015,1101003016,1101003017,1101003018,1101003019,1101003020,1101003021,1101003022,1101003032,1101003033,1101003034,1101003035,1101003036,1101003037,1101003038,1101003039,1101003040,1101003041,1101003042,1101003043,1101003044,1101003045,1101003046,1101003048,1101003049,1101003050,1101003058,1101003059,1101003060,1101003061,1101003062,1101003063,1101003071,1101003073,1101003082,1101003083,1101003084,1101003085,1101003087,1101003088,1101003089,1101003090,1101003100,1101003101,1101003103,1101003112,1101003119,1101003120,1101003121,1101003125,1101003130,1101003131,1101003132,1101003133,1101003134,1101003135,1101003136,1101003138,1101003140,1101003141,1101003146,1101003147,1101003148,1101003150,1101003157,1101003158,1101003167,1101003168,1101003173,1101003174,1101003195,1101003196,1101003199,1101003200,1101003201,1101003208,1101003209,1101003212,1101003219,1101003227,1101004001,1101004002,1101004003,1101004004,1101004005,1101004006,1101004007,1101004008,1101004009,1101004010,1101004011,1101004013,1101004014,1101004015,1101004016,1101004017,1101004018,1101004019,1101004030,1101004031,1101004032,1101004033,1101004034,1101004035,1101004036,1101004039,1101004046,1101004049,1101004051,1101004053,1101004054,1101004055,1101004062,1101004067,1101004069,1101004070,1101004071,1101004078,1101004079,1101004086,1101004087,1101004088,1101004089,1101004090,1101004091,1101004098,1101004099,1101004107,1101004110,1101004117,1101004118,1101004119,1101004120,1101004122,1101004123,1101004124,1101004125,1101004133,1101004138,1101004145,1101004146,1101004148,1101004149,1101004150,1101004151,1101004154,1101004160,1101004163,1101004164,1101004179,1101004201,1101004209,1101004210,1101004218,1101004226,1101004227,1101004228,1101004236,1101004237,1101004238,1101004246,1101005001,1101005002,1101005012,1101005013,1101005014,1101005019,1101005025,1101005027,1101005028,1101005029,1101005030,1101005031,1101005038,1101005043,1101005044,1101005045,1101005052,1101005055,1101005066,1101005072,1101005082,1101005083,1101005084,1101005085,1101005090,1101005091,1101005098,1101005099,1101005100,1101005101,1101005102,1101005103,1101005104,1101005105,1101006001,1101006002,1101006003,1101006004,1101006005,1101006006,1101006007,1101006017,1101006018,1101006019,1101006020,1101006021,1101006023,1101006027,1101006028,1101006033,1101006036,1101006037,1101006038,1101006039,1101006040,1101006041,1101006042,1101006043,1101006044,1101006045,1101006051,1101006052,1101006053,1101006054,1101006062,1101006067,1101006068,1101006075,1101006076,1101006077,1101006085,1101006086,1101006087,1101006088,1101006089,1101007001,1101007002,1101007003,1101007004,1101007005,1101007006,1101007007,1101007008,1101007009,1101007010,1101007011,1101007012,1101007013,1101007014,1101007017,1101007018,1101007019,1101007020,1101007025,1101007033,1101007034,1101007036,1101007037,1101007038,1101007039,1101007046,1101007047,1101007048,1101007054,1101007055,1101007062,1101007063,1101007064,1101007071,1101007072,1101007073,1101007078,1101007079,1101008010,1101008011,1101008012,1101008013,1101008014,1101008015,1101008016,1101008017,1101008018,1101008019,1101008020,1101008021,1101008026,1101008029,1101008030,1101008031,1101008036,1101008039,1101008051,1101008052,1101008053,1101008054,1101008061,1101008062,1101008063,1101008070,1101008071,1101008072,1101008080,1101008081,1101008082,1101008083,1101008084,1101008087,1101008088,1101008092,1101008104,1101008106,1101008116,1101008117,1101008118,1101008126,1101008127,1101008128,1101008129,1101008136,1101008137,1101008138,1101008146,1101008154,1101008155,1101008156,1101008163,1101009001,1101009002,1101009003,1101009004,1101009005,1101009006,1101009007,1101009008,1101009009,1101009010,1101009011,1101009012,1101009013,1101009014,1101009015,1101009016,1101009019,1101009020,1101009021,1101009022,1101009023,1101010010,1101010011,1101010012,1101010013,1101010016,1101010018,1101010019,1101010020,1101010021,1101010022,1101010023,1101010024,1101010029,1101012001,1101012004,1101012009,1101012010,1101012011,1101012012,1101012013,1101012018,1101012019,1101012020,1101012021,1101012022,1101012023,1101012024,1101012025,1101012026,1101012033,1101100003,1101100004,1101100012,1101100013,1101100019,1101100020,1101100021,1101101001,1101101002,1101101003,1101101004,1101101005,1101101006,1101101007,1101102007,1101102017,1101102025,1101102026,1101102027,1101102032,1101102033,1101102041,1101102049,1102001001,1102001002,1102001003,1102001004,1102001006,1102001016,1102001017,1102001018,1102001024,1102001027,1102001028,1102001029,1102001030,1102001031,1102001036,1102001039,1102001040,1102001041,1102001044,1102001050,1102001051,1102001053,1102001058,1102001059,1102001060,1102001062,1102001063,1102001064,1102001069,1102001072,1102001073,1102001074,1102001075,1102001076,1102001077,1102001078,1102001080,1102001081,1102001082,1102001084,1102001085,1102001089,1102001090,1102001095,1102001102,1102001103,1102001104,1102001105,1102001106,1102001107,1102001108,1102001109,1102001112,1102001120,1102001121,1102001122,1102001123,1102001130,1102001131,1102001132,1102001133,1102001134,1102002001,1102002002,1102002003,1102002004,1102002005,1102002006,1102002007,1102002008,1102002009,1102002019,1102002020,1102002021,1102002023,1102002024,1102002025,1102002026,1102002027,1102002028,1102002029,1102002030,1102002031,1102002032,1102002033,1102002034,1102002035,1102002036,1102002043,1102002044,1102002045,1102002048,1102002053,1102002054,1102002061,1102002062,1102002063,1102002067,1102002068,1102002070,1102002071,1102002072,1102002080,1102002081,1102002082,1102002083,1102002084,1102002085,1102002090,1102002091,1102002092,1102002097,1102002098,1102002102,1102002103,1102002104,1102002109,1102002112,1102002117,1102002119,1102002121,1102002124,1102002129,1102002136,1102002137,1102002138,1102002139,1102002140,1102002141,1102002142,1102002143,1102002413,1102002414,1102002415,1102002416,1102002417,1102002424,1102002425,1102002426,1102002427,1102002428,1102002429,1102002430,1102002438,1102002446,1102002999,1102003001,1102003002,1102003003,1102003014,1102003015,1102003020,1102003023,1102003024,1102003025,1102003026,1102003031,1102003034,1102003039,1102003042,1102003045,1102003049,1102003050,1102003052,1102003054,1102003058,1102003063,1102003065,1102003072,1102003073,1102003080,1102003081,1102003082,1102003083,1102003084,1102003085,1102003086,1102003087,1102003088,1102003089,1102003090,1102003091,1102003092,1102003093,1102003100,1102003101,1102003102,1102003103,1102003104,1102003105,1102003199,1102004001,1102004011,1102004012,1102004013,1102004018,1102004020,1102004021,1102004022,1102004024,1102004025,1102004026,1102004027,1102004028,1102004029,1102004034,1102004038,1102004039,1102004040,1102004041,1102004042,1102004043,1102004044,1102004045,1102004048,1102004049,1102004050,1102004051,1102004052,1102004053,1102004054,1102004055,1102005001,1102005002,1102005007,1102005010,1102005011,1102005015,1102005020,1102005021,1102005022,1102005023,1102005024,1102005025,1102005027,1102005028,1102005029,1102005030,1102005031,1102005032,1102005033,1102005041,1102005042,1102005045,1102005046,1102005047,1102005048,1102005049,1102005050,1102005051,1102005052,1102005057,1102005064,1102005065,1102005066,1102005067,1102005072,1102005073,1102005074,1102005075,1102005076,1102005077,1102005078,1102007013,1102007014,1102007015,1102007016,1102007017,1102007018,1102007019,1102007022,1102007023,1102008001,1102105001,1102105002,1102105003,1102105004,1102105005,1102105012,1102105013,1102105018,1102105019,1102105020,1102105021,1102105028,1102105029,1103001001,1103001002,1103001003,1103001004,1103001005,1103001006,1103001007,1103001008,1103001009,1103001010,1103001011,1103001012,1103001013,1103001014,1103001015,1103001025,1103001026,1103001027,1103001028,1103001029,1103001030,1103001031,1103001032,1103001033,1103001035,1103001036,1103001037,1103001038,1103001039,1103001040,1103001042,1103001044,1103001045,1103001046,1103001050,1103001060,1103001068,1103001069,1103001070,1103001072,1103001079,1103001080,1103001085,1103001088,1103001089,1103001090,1103001092,1103001093,1103001094,1103001101,1103001102,1103001107,1103001110,1103001111,1103001112,1103001120,1103001121,1103001122,1103001123,1103001124,1103001125,1103001126,1103001127,1103001128,1103001129,1103001133,1103001137,1103001138,1103001139,1103001141,1103001142,1103001146,1103001154,1103001155,1103001160,1103001162,1103001166,1103001167,1103001172,1103001179,1103001180,1103001183,1103001184,1103001191,1103001192,1103001193,1103001199,1103001202,1103001203,1103002001,1103002011,1103002012,1103002013,1103002018,1103002021,1103002022,1103002023,1103002030,1103002031,1103002032,1103002033,1103002034,1103002035,1103002036,1103002037,1103002047,1103002049,1103002050,1103002051,1103002052,1103002059,1103002060,1103002063,1103002065,1103002066,1103002067,1103002070,1103002071,1103002076,1103002078,1103002080,1103002087,1103002088,1103002089,1103002094,1103002095,1103002096,1103002097,1103002098,1103002099,1103002100,1103002101,1103002102,1103002103,1103002104,1103002105,1103002106,1103002107,1103002108,1103002109,1103002110,1103002111,1103002112,1103002113,1103002114,1103002115,1103002116,1103002120,1103002121,1103002122,1103002123,1103002124,1103002125,1103002126,1103002130,1103002131,1103002132,1103002133,1103002134,1103002135,1103002136,1103002140,1103002141,1103002142,1103002143,1103002144,1103002145,1103002146,1103002150,1103002151,1103002152,1103002153,1103002154,1103002155,1103002156,1103003001,1103003002,1103003003,1103003004,1103003006,1103003014,1103003015,1103003022,1103003030,1103003031,1103003032,1103003035,1103003042,1103003044,1103003051,1103003052,1103003053,1103003055,1103003062,1103003066,1103003067,1103003068,1103003069,1103003070,1103003071,1103003072,1103003079,1103003080,1103003087,1103003092,1103003099,1103004001,1103004002,1103004003,1103004004,1103004006,1103004016,1103004017,1103004018,1103004019,1103004020,1103004021,1103004022,1103004023,1103004025,1103004026,1103004028,1103004029,1103004030,1103004037,1103004038,1103004039,1103004040,1103004041,1103004046,1103004051,1103004052,1103004053,1103004058,1103004060,1103004061,1103004062,1103004063,1103004064,1103004066,1103004067,1103004068,1103004069,1103004070,1103004071,1103004072,1103004073,1103004074,1103004075,1103004080,1103004081,1103004082,1103004087,1103004088,1103004089,1103005010,1103005011,1103005012,1103005013,1103005014,1103005015,1103005016,1103005017,1103005018,1103005019,1103005024,1103005027,1103005028,1103005029,1103005030,1103005031,1103005032,1103005033,1103005034,1103005035,1103005036,1103005037,1103005038,1103005039,1103005040,1103005041,1103005042,1103005043,1103005044,1103005045,1103005048,1103005049,1103005050,1103006001,1103006002,1103006004,1103006014,1103006015,1103006016,1103006017,1103006018,1103006019,1103006020,1103006021,1103006022,1103006023,1103006030,1103006031,1103006032,1103006033,1103006034,1103006036,1103006037,1103006038,1103006039,1103006040,1103006041,1103006046,1103006047,1103006048,1103006049,1103006050,1103006051,1103006052,1103006053,1103006058,1103006063,1103006064,1103006065,1103006066,1103006067,1103006068,1103006069,1103006070,1103006075,1103006076,1103007010,1103007011,1103007015,1103007020,1103007028,1103007029,1103007030,1103007031,1103007032,1103007033,1103007034,1103007035,1103007036,1103007037,1103007038,1103007043,1103008001,1103008004,1103008014,1103008015,1103008016,1103008017,1103008018,1103008019,1103008020,1103008021,1103008022,1103008023,1103009010,1103009011,1103009012,1103009013,1103009016,1103009017,1103009022,1103009027,1103009028,1103009029,1103009030,1103009031,1103009032,1103009037,1103009038,1103009039,1103009042,1103009043,1103009044,1103009045,1103009046,1103009051,1103009052,1103010001,1103010002,1103010003,1103010004,1103010005,1103010006,1103010007,1103010008,1103010010,1103010011,1103010012,1103010013,1103010014,1103010015,1103010016,1103010017,1103010018,1103010019,1103010020,1103011001,1103011002,1103011003,1103011004,1103011005,1103011009,1103011010,1103012010,1103012011,1103012012,1103012019,1103012024,1103012031,1103012032,1103012039,1103100007,1103100008,1103100013,1103102007,1103102008,1103103007,1104001001,1104001002,1104001004,1104001005,1104001015,1104001017,1104001018,1104001019,1104001021,1104001022,1104001023,1104001027,1104001028,1104001029,1104001030,1104001035,1104002002,1104002003,1104002004,1104002005,1104002015,1104002016,1104002017,1104002022,1104002025,1104002026,1104002027,1104002028,1104002029,1104002030,1104002032,1104002033,1104002034,1104002035,1104002036,1104002037,1104002038,1104002044,1104002045,1104002046,1104002049,1104002050,1104003001,1104003002,1104003003,1104003005,1104003015,1104003017,1104003018,1104003019,1104003026,1104003027,1104003028,1104003029,1104003030,1104003031,1104003032,1104003037,1104003038,1104003039,1104003040,1104003041,1104003046,1104003199,1104004010,1104004011,1104004012,1104004013,1104004014,1104004015,1104004017,1104004018,1104004019,1104004020,1104004021,1104004024,1104004027,1104004028,1104004029,1104004030,1104004035,1104004036,1104004041,1104004042,1104004043,1104004044,1104004045,1104004046,1104004051,1104004052,1104004053,1104004054,1104101001,1104101002,1104102001,1104102004,1104102005,1105001001,1105001002,1105001012,1105001013,1105001014,1105001020,1105001025,1105001026,1105001034,1105001035,1105001036,1105001037,1105001038,1105001040,1105001041,1105001048,1105001049,1105001050,1105001051,1105001052,1105001053,1105001054,1105001055,1105001057,1105001062,1105001069,1105001070,1105001075,1105001076,1105001077,1105001078,1105001079,1105002001,1105002011,1105002012,1105002013,1105002018,1105002021,1105002022,1105002023,1105002024,1105002027,1105002028,1105002030,1105002031,1105002035,1105002038,1105002040,1105002041,1105002042,1105002045,1105002046,1105002047,1105002048,1105002051,1105002053,1105002058,1105002063,1105002064,1105002065,1105002066,1105002071,1105002076,1105002077,1105002078,1105002083,1105002091,1105002092,1105002093,1105002096,1105002097,1105002098,1105002199,1105010001,1105010008,1105010009,1105010010,1105010011,1105010012,1105010019,1105010020,1105010021,1105010026,1105010027,1105010028,1106001001,1106001002,1106001003,1106001005,1106001015,1106001016,1106001017,1106001019,1106001020,1106002004,1106002005,1106002006,1106002016,1106002021,1106002023,1106002024,1106002025,1106002026,1106002027,1106002028,1106002029,1106003001,1106003011,1106003012,1106003013,1106003014,1106004001,1106004002,1106004003,1106004004,1106005001,1106005002,1106005004,1106005005,1106006001,1106006003,1106006013,1106006014,1106006015,1106008001,1106008002,1106008003,1106008005,1106008006,1106008007,1106008008,1106008013,1106008014,1106008015,1106008016,1106008017,1106008018,1106008019,1106008022,1106010001,1106010002,1106010003,1106011003,1107001001,1107001011,1107001012,1107001014,1107001015,1107001018,1107001019,1107001020,1107008001,1107098001,1107098002,1107098003,1108001010,1108001011,1108001012,1108001013,1108001014,1108001015,1108001016,1108001018,1108001019,1108001021,1108001022,1108001023,1108001024,1108001025,1108001026,1108001031,1108001032,1108001033,1108001037,1108001038,1108001039,1108001040,1108001041,1108001042,1108001045,1108001047,1108001048,1108001049,1108001052,1108001053,1108001057,1108001058,1108001060,1108001061,1108001062,1108001063,1108001064,1108001066,1108001067,1108001068,1108001069,1108001070,1108001071,1108001072,1108001073,1108001074,1108001075,1108001076,1108001077,1108001078,1108001081,1108001082,1108001085,1108001086,1108001087,1108001088,1108001089,1108001090,1108001091,1108001092,1108001093,1108001094,1108001095,1108001098,1108001099,1108001100,1108001103,1108001104,1108002001,1108002003,1108002010,1108002011,1108002012,1108002013,1108002014,1108002015,1108002016,1108002018,1108002020,1108002021,1108002022,1108002023,1108002024,1108002025,1108002026,1108002027,1108002028,1108002030,1108002032,1108002033,1108002037,1108002038,1108002039,1108002040,1108002043,1108002044,1108002045,1108002046,1108002047,1108002048,1108002049,1108002050,1108002051,1108002052,1108002053,1108002055,1108002059,1108002060,1108002061,1108002062,1108002063,1108003001,1108003010,1108003011,1108003012,1108003013,1108003014,1108003016,1108003017,1108003018,1108003022,1108003024,1108003025,1108004001,1108004002,1108004003,1108004004,1108004005,1108004006,1108004007,1108004008,1108004009,1108004010,1108004011,1108004012,1108004013,1108004014,1108004015,1108004016,1108004017,1108004018,1108004019,1108004020,1108004021,1108004023,1108004025,1108004026,1108004027,1108004028,1108004029,1108004030,1108004031,1108004032,1108004033,1108004034,1108004035,1108004036,1108004037,1108004038,1108004039,1108004040,1108004041,1108004042,1108004043,1108004044,1108004045,1108004046,1108004047,1108004048,1108004049,1108004050,1108004051,1108004053,1108004054,1108004057,1108004059,1108004060,1108004061,1108004062,1108004063,1108004066,1108004067,1108004068,1108004069,1108004071,1108004072,1108004073,1108004074,1108004075,1108004076,1108004077,1108004078,1108004080,1108004081,1108004082,1108004084,1108004085,1108004086,1108004087,1108004088,1108004089,1108004090,1108004091,1108004092,1108004093,1108004094,1108004095,1108004096,1108004098,1108004099,1108004100,1108004101,1108004103,1108004104,1108004105,1108004106,1108004107,1108004109,1108004110,1108004111,1108004112,1108004113,1108004116,1108004117,1108004119,1108004120,1108004121,1108004122,1108004123,1108004124,1108004125,1108004127,1108004132,1108004133,1108004134,1108004135,1108004136,1108004137,1108004138,1108004141,1108004142,1108004143,1108004145,1108004147,1108004149,1108004150,1108004151,1108004155,1108004156,1108004160,1108004161,1108004162,1108004163,1108004164,1108004167,1108004169,1108004173,1108004174,1108004175,1108004176,1108004177,1108004178,1108004179,1108004180,1108004181,1108004183,1108004184,1108004195,1108004197,1108004200,1108004201,1108004203,1108004205,1108004206,1108004207,1108004208,1108004209,1108004210,1108004212,1108004215,1108004216,1108004217,1108004220,1108004221,1108004225,1108004226,1108004227,1108004230,1108004232,1108004233,1108004234,1108004235,1108004237,1108004238,1108004239,1108004240,1108004242,1108004243,1108004244,1108004245,1108004246,1108004248,1108004250,1108004251,1108004252,1108004253,1108004254,1108004255,1108004256,1108004257,1108004258,1108004260,1108004261,1108004265,1108004266,1108004269,1108004271,1108004272,1108004273,1108004274,1108004276,1108004277,1108004283,1108004286,1108004289,1108004290,1108004291,1108004292,1108004295,1108004296,1108004298,1108004299,1108004300,1108004301,1108004303,1108004308,1108004309,1108004310,1108004312,1108004318,1108004320,1108004321,1108004324,1108004325,1108004327,1108004333,1108004334,1108004336,1108004337,1108004341,1108004342,1108004343,1108004344,1108004345,1108004346,1108004347,1108004348,1108004349,1108004350,1108004351,1108004352,1108004353,1108004356,1108004357,1108004358,1108004359,1108004360,1108004361,1108004362,1108004365,1108004366,1108004367,1108004368,1108004369,1108004370,1108004371,1108004372,1108004377,1108004378,1108004379,1108004380,1108004381,1108004382,1108004383,1108004384,1108004385,1108004386,1108004387,1108004388,1108004389,1108004390,1108004391,1108004392,1108004393,
22010009,22010010,22010011,22010012,22010013,22010015,22010017,22010018,22010019,22010020,22010021,22010022,22010024,22010026,22010027,22010028,22010029,22010030,22010033,22010035,22010036,22010037,22010038,22010039,22010040,22010042,22010044,22010045,22010048,22010049,22010051,22010052,22010054,22010055,22010057,22010058,22010059,22010060,22010062,22010063,22010065,12200501,12200601,12200701,12200801,12201201,12201301,12201401,12201801,12201901,12202001,12202601,12202801,12202901,12203101,12203201,12203401,12203601,12203801,12204001,12204201,12204401,12204601,12205001,12205201,12205401,12205601,12205801,12206001,12206801,12207001,12207201,12207301,12207401,12207501,12207701,12207901,12208001,12208201,12208401,12208601,12208801,12209001,12209101,12209201,12209301,12209501,12209801,12210001,12210201,12210601,12210801,12211401,12211501,12211801,12212001,12212201,12212401,12212601,12212701,12213001,12213201,12213401,12213601,12213801,12214001,12214201,12214401,12214601,12214701,12214801,12214901,12215001,12215101,12215201,12215401,12215504,12215506,12215507,12215511,12215513,12215514,12215515,12215516,12215517,12215518,12215519,12215520,12215521,12215522,12215528,12215529,12215530,12215532,12215533,12215534,12215535,12215601,12215701,12216001,12216101,12216301,12219001,12219002,12219003,12219004,12219006,12219007,12219008,12219009,12219021,12219022,12219024,12219026,12219030,12219043,12219044,12219045,12219046,12219047,12219048,12219049,12219050,12219051,12219052,12219053,12219054,12219055,12219061,12219064,12219065,12219067,12219068,12219069,12219071,12219072,12219073,12219074,12219078,12219080,12219082,12219083,12219084,12219085,12219086,12219088,12219089,12219091,12219095,12219097,12219098,12219099,12219100,12219107,12219108,12219109,12219110,12219112,12219113,12219114,12219121,12219201,12219203,12219204,12219205,12219206,12219207,12219208,12219209,12219210,12219211,12219212,12219213,12219214,12219215,12219216,12219217,12219218,12219219,12219220,12219223,12219224,12219225,12219226,12219227,12219228,12219230,12219236,12219239,12219240,12219242,12219244,12219245,12219249,12219251,12219253,12219254,12219255,12219256,12219257,12219258,12219270,12219271,12219272,12219274,12219275,12219276,12219277,12219278,12219279,12219280,12219291,12219293,12219294,12219295,12219296,12219297,12219298,12219299,12219300,12219301,12219302,12219303,12219304,12219305,12219306,12219309,12219310,12219313,12219314,12219315,12219317,12219319,12219326,12219328,12219329,12219331,12219332,12219334,12219335,12219339,12219340,12219341,12219343,12219344,12219345,12219346,12219348,12219350,12219352,12219353,12219354,12219355,12219361,12219362,12219363,12219364,12219365,12219366,12219367,12219368,12219370,12219377,12219379,12219381,12219383,12219395,12219396,12219397,12219398,12219415,12219416,12219417,12219418,12219419,12219420,12219422,12219424,12219425,12219426,12219427,12219429,12219430,12219431,12219433,12219435,12219438,12219440,12219441,12219442,12219443,12219444,12219445,12219446,12219450,12219452,12219453,12219454,12219455,12219458,12219459,12219461,12219462,12219463,12219468,12219470,12219471,12219472,12219499,12219501,12219503,12219504,12219505,12219509,12219510,12219512,12219523,12219524,12219525,12219526,12219527,12219528,12219529,12219530,12219532,12219535,12219537,12219538,12219539,12219540,12219545,12219546,12219551,12219552,12219559,12219561,12219562,12219563,12219564,12219565,12219567,12219574,12219575,12219576,12219579,12219581,12219585,12219586,12219587,12219594,12219596,12219597,12219601,12219607,12219608,12219609,12219610,12219616,12219617,12219618,12219619,12219621,12219624,12219625,12219626,12219639,12219640,12219641,12219643,12219644,12219645,12219649,12219656,12219657,12219659,12219661,12219667,12219668,12219677,12219679,12219680,12219681,12219682,12219684,12219685,12219686,12219690,12219691,12219692,12219693,12219694,12219698,12219699,12219703,12219710,12219715,12219716,12219720,12219721,12219722,12219723,12219725,12219726,12219814,12219819,12219824,12219825,12219829,12219836,12219840,12219841,12219842,12220001,12220002,12220003,12220004,12220005,12220006,12220007,12220008,12220009,12220011,12220012,12220013,12220014,12220016,12220017,12220019,12220020,12220021,12220022,12220023,12220028,12220040,12220042,12220043,12220044,12220045,12220046,12220048,12220049,12220054,12220063,12220064,12220065,12220073,12220074,12220081,12220082,12220093,12220094,12220095,12220096,12220097,12220098,12220099,12220110,12220111,12220116,12220121,12220126,12220131,12220140,12220141,12220142,12220143,12220157,12220158,12220159,12220160,12220161,12220163,12220168,12220170,0,0,12220173,12220174,12220176,12220177,12220178,12220179,12220180,12220182,12220183,12220184,12220187,0,0,12220200,12220205,12220210,12220211,12220212,12220213,12220214,12220215,12220216,12220218,12220219,12220220,12220221,12220226,12220228,12220229,12220233,12220235,12220237,12220238,12220239,12220240,12220241,12220243,12220246,12220247,12220248,12220249,12220250,12220251,12220252,12220257,12220258,12220259,12220264,12220269,12220274,12220275,12220276,12220277,12220278,12220279,12220280,12220285,12220286,12220287,12220288,12220289,12220300,12220301,12220302,12220303,12220305,12220307,12220308,12220310,0,0,12220313,12220314,12220315,12220316,12220320,12220324,12220330,0,12220336,12220340,12220341,12220342,12220343,12220345,12220347,12220348,12220350,12220352,12220353,12220354,12220355,12220356,12220357,12220358,12220359,12220364,12220369,12220370,12220380,12220381,12220382,12220383,12220385,12220387,12220388,12220389,12220394,12220399,12220400,12220401,12220402,12220403,12220404,12220405,12220407,12220410,12220411,12220412,12220413,12220435,12220436,12220440,12220441,12220442,12220443,12220446,12220447,12220448,12220450,12220451,12220452,12220453,12220454,12220460,12220465,12220470,12220475,12220477,12220478,12220479,12220480,12220481,12220482,12220483,12220484,12220491,12220502,12220503,12220504,12220505,12220507,12220519,12220520,12220523,12220524,12220525,12220526,12220527,12220528,12220530,1403780,1403781,12220543,12220548,12220553,12220554,12220555,12220556,12220557,12220558,12220559,12220563,12220564,12220568,12220573,12220574,12220575,12220576,12220577,12220578,12220582,12220592,12220597,12220598,12220599,12220600,12220601,12220602,12220603,12220605,12220620,12220621,12220627,12220623,12220630,12220636,12220639,12220640,12220645,12220704,12220705,12220706,12220707,12220711,12220713,12220717,12220718,12220719,12220723,12220724,12220730,12220734,12220735,12220740,12220741,12220804,12220809,12220810,12220811,12220812,12220813,12220814,12220816,12220819,12220822,12220824,12220826,12220828,12220849,12220854,12220859,12220860,12220861,12220862,12220863,12220864,12220880,12220882,12220885,12220911,12220912,12220920,12220921,12220922,12220954,12220959,12220964,12220965,12220966,12220967,12220968,12220969,12220970,12220971,
452001,452002,452003
}

local INS_BASE = 2000000000
local PKG_SLOT = 3
local MELEE_ID = 108
local GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
local NET_OK = NetErrorCode_NONE or "ok"

local R = { insToRes = {}, resToIns = {} }
local _matchApplied = false
local _weaponSkinCache = {}
_G.AddOutfitWeaponSkinCacheEx = _weaponSkinCache
local function cache()
    _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
        outfitRes = nil, outfitIns = nil,
        weapons = {},
    }
    return _G.AddOutfitEquippedCache
end

local function cfg(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    return CDataTable.GetTableData("Item", resID)
end

local function subType(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

local ST_TOP     = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Package_Slot) or 403
local ST_PANTS   = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Pants_Slot) or 404
local ST_SHOES   = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Shoes_Slot) or 405
local ST_UNDER_T = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.UnderCloth) or 450
local ST_UNDER_P = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.UnderPants) or 451
local WARDROBE_TAB_SUIT, WARDROBE_TAB_CLOTHES = 10, 3

pcall(function()
    local wm = require("client.slua.umg.Wardrobe.wardrobe_macro")
    WARDROBE_TAB_SUIT = wm.ENUM_WardrobeSubTabString.ENUM_WardrobeSubTabString_suit
    WARDROBE_TAB_CLOTHES = wm.ENUM_WardrobeSubTabString.ENUM_WardrobeSubTabString_clothes
end)

local FULL_SUIT_CLEAR_ST = {
    [ST_TOP] = true, [ST_PANTS] = true, [ST_SHOES] = true,
    [ST_UNDER_T] = true, [ST_UNDER_P] = true,
}

local function wardrobeTab(resID, depotData)
    if depotData and depotData.subTabType then return tonumber(depotData.subTabType) end
    local c = cfg(resID)
    return c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
end

local function isFullSuitRes(resID, depotData)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    local ok, xs = pcall(function()
        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
        return LogicXSuit.IsXSuit(resID)
    end)
    if ok and xs then return true end
    local tab = wardrobeTab(resID, depotData)
    if tab == WARDROBE_TAB_SUIT then return true end
    if tab == WARDROBE_TAB_CLOTHES then return false end
    for _, id in ipairs(ITEMS) do
        if tonumber(id) == resID and subType(cfg(resID)) == ST_TOP then
            return true
        end
    end
    return false
end

local function getClothKind(resID, depotData)
    resID = tonumber(resID)
    if not resID then return nil end
    local st = subType(cfg(resID))
    if st == ST_TOP then
        return isFullSuitRes(resID, depotData) and "full_suit" or "top"
    end
    if st == ST_PANTS then return "pants" end
    if st == ST_SHOES then return "shoes" end
    if st == ST_UNDER_T then return "under_top" end
    if st == ST_UNDER_P then return "under_pants" end
    return nil
end

local function subTypesToClearForKind(kind)
    if kind == "full_suit" then return FULL_SUIT_CLEAR_ST end
    if kind == "top" then return { [ST_TOP] = true } end
    if kind == "pants" then return { [ST_PANTS] = true } end
    if kind == "shoes" then return { [ST_SHOES] = true } end
    if kind == "under_top" then return { [ST_UNDER_T] = true } end
    if kind == "under_pants" then return { [ST_UNDER_P] = true } end
    return nil
end

local function isBodyClothSubType(st)
    st = tonumber(st)
    return st == ST_TOP or st == ST_PANTS or st == ST_SHOES or st == ST_UNDER_T or st == ST_UNDER_P
end

local function weaponIdFromSkin(resID)
    local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
    if not m then return nil end
    return m.WeaponID or m.WeaponId
end

local function isInjectedIns(ins)
    if _G.HK_GetVal("UNLOCK_SKIN") ~= 1 then return false end
    return ins and R.insToRes[tonumber(ins)] ~= nil
end

local function isInjectedRes(res)
    if _G.HK_GetVal("UNLOCK_SKIN") ~= 1 then return false end
    return res and R.resToIns[tonumber(res)] ~= nil
end

local function invalidateSocialWearCache()
    local s = _G.AddOutfitSocialState
    if s then
        s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
    end
end

local function saveWeaponToCache(weaponID, resID, insID)
    weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
    if not weaponID or not resID or resID <= 0 then return end
    local cch = cache()
    cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
    _weaponSkinCache[weaponID] = { resID = resID, insID = insID or 0 }
    _G.AddOutfitLastAppliedSkin = {}
    _matchApplied = false
    invalidateSocialWearCache()

    -- Persist to disk
    if _G.HK_Settings then
        _G.HK_Settings["LAST_LOBBY_WEAPON_" .. weaponID] = resID
        _G.SaveModSettings()
    end
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

local function getBagArray(resID)
    if not _G.OutfitSkins or not _G.OutfitSkins.Bag then return nil end
    for _, arr in ipairs(_G.OutfitSkins.Bag) do
        for _, id in ipairs(arr) do
            if id == resID then
                return arr
            end
        end
    end
    return nil
end

local function getHelmetArray(resID)
    if not _G.OutfitSkins or not _G.OutfitSkins.Helmet then return nil end
    for _, arr in ipairs(_G.OutfitSkins.Helmet) do
        for _, id in ipairs(arr) do
            if id == resID then
                return arr
            end
        end
    end
    return nil
end

local function isSpecialWearRes(resID, itemCfg)
    local st = subType(itemCfg or cfg(resID))
    return getBagArray(resID) or getHelmetArray(resID)
        or st == 407 or st == ST_TOP or st == ST_PANTS or st == ST_SHOES
        or st == 402 or st == 406
end

local function saveEquip(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = cfg(resID)
    local st = subType(c)
    local cch = cache()
    
    local bagArr = getBagArray(resID)
    if bagArr then
        cch.bagRes = bagArr
        cch.bagInsID = insID
        if _G.HK_Settings then
            for idx, arr in ipairs(_G.OutfitSkins.Bag or {}) do
                if arr == bagArr then
                    _G.HK_Settings.LAST_LOBBY_BAG = idx
                    break
                end
            end
            _G.SaveModSettings()
        end
    end

    local helmetArr = getHelmetArray(resID)
    if helmetArr then
        cch.helmetRes = helmetArr
        cch.helmetInsID = insID
        if _G.HK_Settings then
            for idx, arr in ipairs(_G.OutfitSkins.Helmet or {}) do
                if arr == helmetArr then
                    _G.HK_Settings.LAST_LOBBY_HELMET = idx
                    break
                end
            end
            _G.SaveModSettings()
        end
    end

    if st == 407 then
        cch.gloveRes = resID
        cch.gloveInsID = insID
        if _G.HK_Settings then
            _G.HK_Settings.LAST_LOBBY_GLOVE = resID
            _G.SaveModSettings()
        end
    elseif st == ST_TOP and getClothKind(resID) == "top" then
        cch.topRes = resID
        cch.topInsID = insID
        if _G.HK_Settings then
            _G.HK_Settings.LAST_LOBBY_TOP = resID
            _G.SaveModSettings()
        end
    elseif st == ST_PANTS then
        cch.pantsRes = resID
        cch.pantsInsID = insID
        if _G.HK_Settings then
            _G.HK_Settings.LAST_LOBBY_PANTS = resID
            _G.SaveModSettings()
        end
    elseif st == ST_SHOES then
        cch.shoesRes = resID
        cch.shoesInsID = insID
        if _G.HK_Settings then
            _G.HK_Settings.LAST_LOBBY_SHOES = resID
            _G.SaveModSettings()
        end
    elseif st == 402 or st == 406 then
        cch.faceRes = resID
        cch.faceInsID = insID
        if _G.HK_Settings then
            _G.HK_Settings.LAST_LOBBY_FACE = resID
            _G.SaveModSettings()
        end
    end

    if getClothKind(resID) == "full_suit" then
        cch.outfitRes, cch.outfitIns = resID, insID
        cch.topRes, cch.topInsID = nil, nil
        cch.pantsRes, cch.pantsInsID = nil, nil
        cch.shoesRes, cch.shoesInsID = nil, nil
        _G.AddOutfitLastLobbyOutfitRes = resID
        invalidateSocialWearCache()
        
        -- Persist to disk
        if _G.HK_Settings then
            _G.HK_Settings.LAST_LOBBY_OUTFIT = resID
            _G.HK_Settings.LAST_LOBBY_TOP = 0
            _G.HK_Settings.LAST_LOBBY_PANTS = 0
            _G.HK_Settings.LAST_LOBBY_SHOES = 0
            _G.SaveModSettings()
        end
    elseif getClothKind(resID) == "top" or st == ST_PANTS or st == ST_SHOES then
        if cch.outfitRes and isFullSuitRes(cch.outfitRes) then
            cch.outfitRes, cch.outfitIns = nil, nil
            _G.AddOutfitLastLobbyOutfitRes = nil
            invalidateSocialWearCache()
            
            -- Persist to disk
            if _G.HK_Settings then
                _G.HK_Settings.LAST_LOBBY_OUTFIT = 0
                _G.SaveModSettings()
            end
        end
    elseif GUN_SUB[st] then
        local wid = weaponIdFromSkin(resID)
        if wid then saveWeaponToCache(wid, resID, insID) end
    elseif st == MELEE_ID then
        saveWeaponToCache(MELEE_ID, resID, insID)
    end
    _matchApplied = false
end

local function syncWeaponCacheFromLobby()
    local cch = cache()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.weapon_skin_list then
            for weaponID, entry in pairs(bag.weapon_skin_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and (entry.skin_id or entry.skinId)) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    if isInjectedIns(insID) then
                        local res = tonumber(R.insToRes[insID])
                        if res and res > 0 then
                            cch.weapons[weaponID] = { resID = res, insID = insID }
                        end
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        if d and d.resID and tonumber(d.resID) > 0 then
                            cch.weapons[weaponID] = { resID = tonumber(d.resID), insID = insID }
                        end
                    end
                end
            end
        end
    end)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm.rsp_list and Arm.rsp_list.install_list then
            for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and entry.skin_id) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    if isInjectedIns(insID) then
                        local res = tonumber(R.insToRes[insID])
                        if res and res > 0 then
                            cch.weapons[weaponID] = { resID = res, insID = insID }
                        end
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        if d and d.resID and tonumber(d.resID) > 0 then
                            cch.weapons[weaponID] = { resID = tonumber(d.resID), insID = insID }
                        end
                    end
                end
            end
        end
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl.GetSkinIdByWeaponID then
            local guns = { 101001, 101002, 101003, 101004, 101005, 101006, 101007, 101008, 101009, 101010, 101012, 102001, 102002, 102003, 102004, 102005, 102007, 103001, 103002, 103003, 103004, 103005, 103006, 103007, 103008, 103009, 103010, 103011, 103012, 104001, 104002, 104003, 104004, 105001, 105002, 106001, 106002, 106003, 106004, 106005, 106006, 106007, 106008, 106010 }
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            for _, wid in ipairs(guns) do
                local insID = tonumber(wgl:GetSkinIdByWeaponID(wid)) or 0
                if insID > 0 then
                    local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
                    if d and d.resID and tonumber(d.resID) > 0 then
                        cch.weapons[wid] = { resID = tonumber(d.resID), insID = insID }
                    end
                end
            end
        end
    end)
end

local function getCachedWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    if weaponID <= 0 then return nil end
    syncWeaponCacheFromLobby()
    local w = cache().weapons[weaponID]
    if w and w.resID and w.resID > 0 then return w.resID end
    return nil
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

local function removeRoleWearBySubType(st)
    if not st then return end
    removeRoleWearBySubTypes({ [tonumber(st)] = true })
end

local function syncFashionBagRolewear()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

local function isLobbyResEquipped(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local cch = cache()
    if tonumber(cch.outfitRes) == resID then return true end
    if tonumber(cch.topRes) == resID then return true end
    if tonumber(cch.pantsRes) == resID then return true end
    if tonumber(cch.shoesRes) == resID then return true end
    if tonumber(cch.gloveRes) == resID then return true end
    if tonumber(cch.faceRes) == resID then return true end
    if type(cch.bagRes) == "table" then
        for _, v in ipairs(cch.bagRes) do
            if tonumber(v) == resID then return true end
        end
    elseif tonumber(cch.bagRes) == resID then
        return true
    end
    if type(cch.helmetRes) == "table" then
        for _, v in ipairs(cch.helmetRes) do
            if tonumber(v) == resID then return true end
        end
    elseif tonumber(cch.helmetRes) == resID then
        return true
    end
    for _, w in pairs(cch.weapons or {}) do
        if tonumber(w.resID) == resID then return true end
    end
    return false
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
    local ok2, e = pcall(dc.GetWardrobeData)
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

local function injectOne(entity, resID, insID)
    if alreadyHave(entity, resID) then
        R.resToIns[resID] = R.resToIns[resID] or insID
        R.insToRes[insID] = resID
        return true
    end
    local row = {
        instid = insID,
        res_id = resID,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
    }
    entity:AddData(row)
    pcall(function()
        local data = entity.GetDataByInsID and entity:GetDataByInsID(insID)
        if data and entity.LoadConfigForData and CDataTable.GetTableData then
            entity:LoadConfigForData(data, CDataTable.GetTableData)
        end
    end)
    R.insToRes[insID] = resID
    R.resToIns[resID] = insID
    return true
end

local function injectArmory(resID, insID)
    local wid = weaponIdFromSkin(resID)
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

local function injectAll(entity)
    entity = entity or getEntity()
    if not entity or not entity.bInit then return false end
    local n = 0
    for i, resID in ipairs(ITEMS) do
        local insID = INS_BASE + i
        if injectOne(entity, resID, insID) then
            n = n + 1
            local c = cfg(resID)
            if GUN_SUB[subType(c)] or subType(c) == MELEE_ID then
                injectArmory(resID, insID)
            end
        end
    end
    return n > 0
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
_G.RefreshLobbyWardrobeEx = refreshWardrobe

local function putOnCloth(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local kind = getClothKind(resID, d)
    if not kind then return end
    local clearMap = subTypesToClearForKind(kind)
    if not clearMap then return end

    local itemSt = subType(cfg(resID)) or ST_TOP
    local oldIns, oldRes = findWornInsBySubType(itemSt)
    removeRoleWearBySubTypes(clearMap)
    clearFashionBagSlots(clearMap)
    saveEquip(resID, insID)

    local slot = PKG_SLOT
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
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

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
        syncFashionBagRolewear()
    end)
end

local function putOnOutfit(insID)
    putOnCloth(insID)
end

local function putOnSpecialWear(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return false end
    local itemSt = subType(cfg(resID))
    if not itemSt then return false end

    local oldIns, oldRes = findWornInsBySubType(itemSt)
    local clearMap = { [itemSt] = true }
    removeRoleWearBySubTypes(clearMap)
    clearFashionBagSlots(clearMap)
    saveEquip(resID, insID)

    local slot = PKG_SLOT
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
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(itemSt, insID, resID, 0, 0)
        av:AvatarChange(resID, true, 0, 0)
        av:ProcessTakeOff()
        syncFashionBagRolewear()
    end)
    refreshWardrobe()
    onSocialWearDirty(true)
    return true
end

local function equipWeaponSkin(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not isInjectedIns(insID) then return end
    local resID = R.insToRes[insID]
    _weaponSkinCache[weaponID] = { resID = resID, insID = insID }
    saveEquip(resID, insID)

    local Arm = require("client.logic.armory.logic_armory")
    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
    local HT = require("client.logic.lobby.hall_theme_utils")
    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

    injectArmory(resID, insID)
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
end

local SOCIAL = _G.AddOutfitSocialState or {}
_G.AddOutfitSocialState = SOCIAL
SOCIAL.debGen = SOCIAL.debGen or 0
SOCIAL.wearPatchKey = SOCIAL.wearPatchKey or nil
SOCIAL.snapshotKey = SOCIAL.snapshotKey or nil
SOCIAL.fullSnapshot = SOCIAL.fullSnapshot or nil

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
    if not _G.LobbyCosmeticEnabled then return nil end
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local skin = getWeaponSkinResFast()
    if skin and skin > 0 then return skin end

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local entry = Arm.rsp_list and Arm.rsp_list.install_list
            and Arm.rsp_list.install_list[wid > 0 and wid or 101004]
        local insID = tonumber(entry and entry.skin_id) or 0
        if insID > 0 and isInjectedIns(insID) then
            skin = tonumber(R.insToRes[insID])
        elseif insID > 0 then
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if d and d.resID then skin = tonumber(d.resID) end
        end
    end)
    if skin and skin > 0 then return skin end

    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl.GetSkinIdByWeaponID and wid > 0 then
            local insID = tonumber(wgl:GetSkinIdByWeaponID(wid)) or 0
            if insID > 0 and isInjectedIns(insID) then
                skin = tonumber(R.insToRes[insID])
            end
        end
    end)
    return (skin and skin > 0) and skin or nil
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
    if not _G.LobbyCosmeticEnabled then return nil end
    local cch = cache()
    local outfitRes = tonumber(cch.outfitRes) or 0
    if outfitRes > 0 then return outfitRes end
    outfitRes = tonumber(_G.AddOutfitLastLobbyOutfitRes) or 0
    if outfitRes > 0 then return outfitRes end
    local injectedRes, anyRes
    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local function resFromIns(ins)
            ins = tonumber(ins)
            if not ins or ins <= 0 then return nil end
            if isInjectedIns(ins) then return tonumber(R.insToRes[ins]) end
            local d = wd:GetHallDepotItemDataByInsID(ins)
            return d and tonumber(d.resID) or nil
        end
        for _, ins in pairs(AvatarData.GetRoleWear()) do
            local res = resFromIns(ins)
            if res and isFullSuitRes(res) then
                if isInjectedRes(res) then injectedRes = res end
                anyRes = anyRes or res
            end
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.rolewear_list then
            for _, ins in pairs(bag.rolewear_list) do
                local res = resFromIns(ins)
                if res and isFullSuitRes(res) then
                    if isInjectedRes(res) then injectedRes = res end
                    anyRes = anyRes or res
                end
            end
        end
    end)
    if injectedRes and injectedRes > 0 then return injectedRes end
    if anyRes and anyRes > 0 then return anyRes end
    return nil
end

local function wearPatchKey()
    local outfit = resolveLobbyOutfitRes() or 0
    local skin = resolveLobbyWeaponSkinRes() or 0
    local openGun = 1
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then openGun = lds.data.OpenGun and 1 or 0 end
    end)
    return outfit .. "_" .. skin .. "_" .. openGun
end

local function syncDepotShowWeaponFlags(depot)
    depot = depot or {}
    depot.vehicle = true
    depot.helmet = true
    depot.bag = true
    depot.pet = true
    depot.idle = true
    depot.hand = true
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data then
            if lds.data.OpenGun ~= nil then depot.weapon = lds.data.OpenGun end
            if lds.data.OpenSocialWeapon ~= nil then depot.social_weapon = lds.data.OpenSocialWeapon end
        end
    end)
    return depot
end

local function applyInjectedPspace(roleData)
    if not _G.LobbyCosmeticEnabled then return end
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
        if roleData.depot_show_info.weapon == nil then
            roleData.depot_show_info.weapon = true
        end
    end
    roleData.depot_show_info = syncDepotShowWeaponFlags(roleData.depot_show_info)
end

local function patchSelfWearCache(force)
    local key = wearPatchKey()
    if not force and SOCIAL.wearPatchKey == key then return false end
    SOCIAL.wearPatchKey = key
    SOCIAL.snapshotKey = nil
    SOCIAL.fullSnapshot = nil

    local myUid = tonumber(DataMgr.roleData.uid)
    if not myUid then return false end

    local changed = false
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local d = BD:GetCacheData(myUid)
        if not d then
            BD:OnHandleMsgDataAndCallback(myUid, buildLocalRoleDataForCoupleAvatar())
            return true
        end
        local oldCloth = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local oldSkin = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        applyInjectedPspace(d)
        local nc = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local ns = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        if oldCloth ~= nc or oldSkin ~= ns or not d.bshow then changed = true end
    end)
    return force or changed
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
    if patchSelfWearCache(forceRefresh) then
        requestSocialAvatarRefresh()
    end
end

local function buildLocalRoleDataForCoupleAvatar()
    if not _G.LobbyCosmeticEnabled then return nil end
    local key = wearPatchKey()
    if SOCIAL.fullSnapshot and SOCIAL.snapshotKey == key then
        return SOCIAL.fullSnapshot
    end
    syncWeaponCacheFromLobby()
    local cch = cache()
    local ad = DataMgr.avatarData or {}
    local gender = tonumber(ad.gamegender) or 2
    if gender < 1 then gender = 2 end

    local data = {
        uid = DataMgr.roleData.uid,
        gender = gender,
        bshow = true,
        pspace_wear_ext = {
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HEAD] = { tonumber(ad.headid) or 401993, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HAIR] = { tonumber(ad.hairid) or 40601001, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { 0, 0, 0 },
        },
        depot_show_info = {
            weapon = true, social_weapon = true, idle = true,
            helmet = true, bag = true, vehicle = true, hand = true, pet = true
        },
    }

    local outfitRes = resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end

    local skinRes = resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON][1] = 0
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN][1] = skinRes
    end
    data.depot_show_info = syncDepotShowWeaponFlags(data.depot_show_info)
    SOCIAL.fullSnapshot = data
    SOCIAL.snapshotKey = wearPatchKey()
    return data
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
    if not _G.LobbyCosmeticEnabled then return end
    if not isMyWearData(wearData) then return end
    local skinRes = resolveLobbyWeaponSkinRes()
    wearData.depot_show_info = syncDepotShowWeaponFlags(wearData.depot_show_info)
    if not skinRes or skinRes <= 0 then return end
    wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
        weaponResId = 0, weaponSkinId = 0,
        diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
    }
    if wearData.mainWeaponInfo.weaponSkinId == skinRes
        and (tonumber(wearData.mainWeaponInfo.weaponResId) or 0) == 0 then
        return
    end
    wearData.mainWeaponInfo.weaponSkinId = skinRes
    wearData.mainWeaponInfo.weaponResId = 0
end

local function equipSocialHandWeapon(avatar, skinRes)
    if not avatar or not skinRes or skinRes <= 0 then return end
    if SOCIAL.lastHandSkin == skinRes then return end
    SOCIAL.lastHandSkin = skinRes
    pcall(function()
        avatar:PutonEquipment(skinRes, nil, { bIsUse = true })
    end)
end

local function shouldShowHandWeapon()
    local show = true
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then
            show = lds.data.OpenGun ~= false
        end
    end)
    return show
end

local function mergeInjectedOutfitIntoWearData(wearData)
    if not _G.LobbyCosmeticEnabled then return end
    if not isMyWearData(wearData) then return end
    local outfitRes = resolveLobbyOutfitRes()
    if not outfitRes or outfitRes <= 0 or not isFullSuitRes(outfitRes) then return end
    rememberLobbyOutfitRes(outfitRes)
    local AvatarData = require("client.logic.data.AvatarData")
    local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
    if not converted then return end
    local newList = {}
    for _, e in ipairs(wearData.WearInfoList or {}) do
        if e and e.ItemID and isBodyClothSubType(subType(cfg(e.ItemID))) then
        else
            newList[#newList + 1] = e
        end
    end
    newList[#newList + 1] = converted
    wearData.WearInfoList = newList
end

local function mergeInjectedIntoWearData(wearData)
    if not wearData then return end
    mergeInjectedWeaponIntoWearData(wearData)
    mergeInjectedOutfitIntoWearData(wearData)
end

local function reapplyLobbyEquipped()
    if not _G.LobbyCosmeticEnabled then return end
    if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
        return
    end
    syncWeaponCacheFromLobby()
    local curPage = getLobbyCurPage()

    if ENUM_LobbyPageType and curPage == ENUM_LobbyPageType.Left then
        onSocialWearDirty(true)
        return
    end

    local cch = cache()
    if cch.outfitIns and isInjectedIns(cch.outfitIns) then
        putOnOutfit(cch.outfitIns)
    end

    for wid, w in pairs(cch.weapons) do
        wid = tonumber(wid)
        if wid and w and w.resID and w.resID > 0 then
            if w.insID and isInjectedIns(w.insID) then
                equipWeaponSkin(wid, w.insID)
            else
                pcall(function() DataMgr.InitWeaponData(wid, w.resID, w.insID or 0) end)
            end
        end
    end

    pcall(function()
        local uid = tostring(DataMgr.roleData.uid)
        local LAM = require("client.logic.avatar.LobbyAvatarManager")
        local TAM = require("client.logic.avatar.logic_team_avatar_manager")
        local mainWid = tonumber(DataMgr.Weapon_ID) or 0
        local mw = mainWid > 0 and cch.weapons[mainWid] or nil
        if mw and mw.resID and mw.resID > 0 and TAM.GetAvatarByUid(uid) then
            LAM.EquipWeapon(uid, { weaponId = mainWid, skinId = mw.resID }, nil, true)
        end
    end)

    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
        end
    end)
end

local function hookLobbySwipePersistence()
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local oRsp = BD.on_get_avatar_show_rsp
        BD.on_get_avatar_show_rsp = function(self, res, target_uid, data)
            oRsp(self, res, target_uid, data)
            if not _G.LobbyCosmeticEnabled then return end
                if tonumber(target_uid) == tonumber(DataMgr.roleData.uid) then
                patchSelfWearCache(true)
                SOCIAL.forceAvatarRedraw = true
                SOCIAL.lastHandSkin = nil
                if ENUM_LobbyPageType and getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    requestSocialAvatarRefresh()
                end
            end
        end
    end)

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
            if not _G.LobbyCosmeticEnabled then
                return oUp(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
            end
            if isMyWearData(wearData) then
                mergeInjectedIntoWearData(wearData)
            end
            local showGun = isShowWeapon and shouldShowHandWeapon()
            if wearData and wearData.depot_show_info then
                showGun = showGun and wearData.depot_show_info.weapon ~= false
            end
            if isMyWearData(wearData) then
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if e and e.ItemID and isInjectedRes(e.ItemID) and isFullSuitRes(e.ItemID) then
                        rememberLobbyOutfitRes(e.ItemID)
                        break
                    end
                end
            end
            local ret = oUp(avatar, wearData, showGun, isShowHelmet, isShowBag)
            if showGun and isMyWearData(wearData) and avatar
                and ENUM_LobbyPageType and getLobbyCurPage() == ENUM_LobbyPageType.Left then
                local skin = tonumber(wearData.mainWeaponInfo and wearData.mainWeaponInfo.weaponSkinId) or 0
                if skin <= 0 then skin = resolveLobbyWeaponSkinRes() or 0 end
                if skin > 0 then equipSocialHandWeapon(avatar, skin) end
            end
            return ret
        end
    end)

    pcall(function()
        local CA = require("client.logic.avatar.CoupleAvatar")
        local Cfg = require("client.slua.logic.lobby.Left.CoupleAvatarConfig")
        local oMulti = CA._UpdateMultiAvatar
        if oMulti then
            CA._UpdateMultiAvatar = function(self, avatar, avatarType)
                if not _G.LobbyCosmeticEnabled then
                    return oMulti(self, avatar, avatarType)
                end
                local isSelf = avatarType == Cfg.AvatarType.Self
                    and self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
                if isSelf then
                    pcall(function()
                        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                        local d = BD:GetCacheData(tonumber(self.SelfUID))
                        if d then applyInjectedPspace(d) end
                    end)
                    if SOCIAL.forceAvatarRedraw then
                        self.CompareDataCache[avatarType] = nil
                        SOCIAL.forceAvatarRedraw = nil
                    end
                end
                oMulti(self, avatar, avatarType)
                if isSelf and self.isShowWeapon ~= false and shouldShowHandWeapon()
                    and ENUM_LobbyPageType and getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    local skin = resolveLobbyWeaponSkinRes()
                    if skin and skin > 0 then equipSocialHandWeapon(avatar, skin) end
                end
            end
        end
        local oHideCheck = CA.CheckSelfIsHideAvatar
        CA.CheckSelfIsHideAvatar = function(self, nSelfUId, tRoleData)
            if not _G.LobbyCosmeticEnabled then
                return oHideCheck(self, nSelfUId, tRoleData)
            end
            if tostring(nSelfUId) == tostring(DataMgr.roleData.uid) then
                return false
            end
            return oHideCheck(self, nSelfUId, tRoleData)
        end

        local oUpdate = CA.Update
        CA.Update = function(self)
            if not _G.LobbyCosmeticEnabled then return oUpdate(self) end
            local isSelf = self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
            local oHide = CA.HideAvatars
            if isSelf then
                CA.HideAvatars = function() end
            end
            local ok, err = pcall(oUpdate, self)
            CA.HideAvatars = oHide
        end

        local oRecv = CA.OnReceiveData
        CA.OnReceiveData = function(self, uid, data)
            if not _G.LobbyCosmeticEnabled then
                return oRecv(self, uid, data)
            end
            if uid == self.SelfUID and tostring(uid) == tostring(DataMgr.roleData.uid) then
                if data then
                    applyInjectedPspace(data)
                else
                    data = buildLocalRoleDataForCoupleAvatar()
                end
            end
            return oRecv(self, uid, data)
        end
    end)

    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_START then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_START, function(_, _, toPage)
                if not _G.LobbyCosmeticEnabled then return end
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    local o = resolveLobbyOutfitRes()
                    if o then rememberLobbyOutfitRes(o) end
                    patchSelfWearCache(true)
                    SOCIAL.forceAvatarRedraw = true
                end
            end)
        end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                if not _G.LobbyCosmeticEnabled then return end
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    socialDebounce(0.45, function()
                        onSocialWearDirty(true)
                    end)
                elseif ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                    SOCIAL.wearPatchKey = nil
                    socialDebounce(0.35, reapplyLobbyEquipped)
                end
            end)
        end
        if EVENTTYPE_LOBBY_SOCIAL and EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA then
            EventSystem:registEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA, function(_, _, nUId)
                if not _G.LobbyCosmeticEnabled then return end
                if tonumber(nUId) == tonumber(DataMgr.roleData.uid) then
                    socialDebounce(0.2, function() patchSelfWearCache(false) end)
                end
            end)
        end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function()
                if not _G.LobbyCosmeticEnabled then return end
                SOCIAL.wearPatchKey = nil
                SOCIAL.snapshotKey = nil
                syncWeaponCacheFromLobby()
                if ENUM_LobbyPageType and getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    socialDebounce(0.25, function() onSocialWearDirty(true) end)
                end
            end)
        end
    end)

    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        local oSwitch = lds.SwitchGun
        lds.SwitchGun = function(...)
            local r = oSwitch(...)
            SOCIAL.wearPatchKey = nil
            if ENUM_LobbyPageType and getLobbyCurPage() == ENUM_LobbyPageType.Left then
                socialDebounce(0.2, function() onSocialWearDirty(true) end)
            end
            return r
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

        if wd.GetItemIDByInsID then
            local o_gii = wd.GetItemIDByInsID
            wd.GetItemIDByInsID = function(self, insID)
                insID = tonumber(insID)
                if isInjectedIns(insID) then return R.insToRes[insID] end
                return o_gii(self, insID)
            end
        end

        if wd.GetItemSource then
            local o_gs = wd.GetItemSource
            wd.GetItemSource = function(self, insID)
                insID = tonumber(insID)
                if isInjectedIns(insID) then return EWardrobeDataSource.Wardrobe end
                return o_gs(self, insID)
            end
        end
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
    end)
end

local function hookPageFilter()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o1 = wl.IsValidCurrentPageItem
        wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
            if v and isInjectedRes(v.resID) and mainTab == 1 then
                if v.expireTS == 0 or not t or t < v.expireTS then
                    local st = v.itemSubType or subType(cfg(v.resID))
                    if st == ST_TOP then
                        local full = isFullSuitRes(v.resID, v)
                        if subTab == WARDROBE_TAB_SUIT and full then return true end
                        if subTab == WARDROBE_TAB_CLOTHES and not full then return true end
                    end
                    if v.subTabType == subTab then return true end
                end
            end
            return o1(self, mainTab, subTab, v, t)
        end
        local o2 = wl.IsCanUse
        wl.IsCanUse = function(self, resId)
            if isInjectedRes(resId) then return true end
            return o2(self, resId)
        end
        local o3 = wl.IsCharacterUse
        wl.IsCharacterUse = function(self, resId)
            resId = tonumber(resId)
            if isInjectedRes(resId) then return isLobbyResEquipped(resId) end
            return o3(self, resId)
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
        local og = Arm.GetSkinListByWeaponID
        Arm.GetSkinListByWeaponID = function(wid)
            local t = og(wid) or {}
            for resID, _ in pairs(R.resToIns) do
                if tonumber(weaponIdFromSkin(resID)) == tonumber(wid) then
                    t[resID] = t[resID] or { is_open = 1 }
                end
            end
            return t
        end
        local oa = Arm.get_weapon_skin_list_rsp
        Arm.get_weapon_skin_list_rsp = function(a, b, c, d)
            oa(a, b, c, d)
            for resID, insID in pairs(R.resToIns) do injectArmory(resID, insID) end
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
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        local o = AH.send_install_weapon_skin
        AH.send_install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if isInjectedIns(ins) then
                wid = tonumber(weaponIdFromSkin(R.insToRes[ins]) or wid)
                equipWeaponSkin(wid, ins)
                return
            end
            return o(cd, wid, ins)
        end
    end)
end

local function hookGunSkinId()
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        local o = wgl.GetSkinIdByWeaponID
        wgl.GetSkinIdByWeaponID = function(self, wid)
            local c = cache()
            local w = c.weapons[wid]
            if w and isInjectedIns(w.insID) then return w.insID end
            local Arm = require("client.logic.armory.logic_armory")
            if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                local sid = Arm.rsp_list.install_list[wid].skin_id
                if sid and isInjectedIns(sid) then return sid end
            end
            return o(self, wid)
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
                local kind = getClothKind(resID)
                if kind then
                    putOnCloth(insID)
                    return
                end
                if isSpecialWearRes(resID, c) and putOnSpecialWear(insID) then
                    return
                end
                if GUN_SUB[st] then
                    local wid = weaponIdFromSkin(resID)
                    if wid then equipWeaponSkin(wid, insID) end
                    return
                end
                if st == MELEE_ID then
                    equipWeaponSkin(MELEE_ID, insID)
                    return
                end
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetHallDepotItemDataByInsID(insID)
                if d then
                    WRH.on_depot_put_on_rsp(NET_OK, { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0, extra)
                end
                return
            end
            return o(insID, extra)
        end
    end)
end

local function hookWeaponWear()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        local o = HT.IsWeaponWear
        HT.IsWeaponWear = function(insId)
            insId = tonumber(insId)
            if isInjectedIns(insId) then
                local c = cache()
                local Arm = require("client.logic.armory.logic_armory")
                for wid, w in pairs(c.weapons) do
                    if tonumber(w.insID) == insId then
                        if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                            return tonumber(Arm.rsp_list.install_list[wid].skin_id) == insId
                        end
                        return true
                    end
                end
            end
            return o(insId)
        end
    end)
end

local function hookAvatarValid()
    pcall(function()
        local path = "GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent"
        local comp = require(path)
        if comp and comp.CheckItemValid then
            local o = comp.CheckItemValid
            comp.CheckItemValid = function(self, resID)
                local id = tonumber(resID)
                if isInjectedRes(id) or isInjectedIns(id) then return true end
                return o(self, resID)
            end
        end
    end)
end



local GUN_MASTER_SYN_SLOT = 7


local function resolveWeaponTypeID(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return 0 end
    local found = 0
    pcall(function()
        local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
        if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
    end)
    if found > 0 then return found end
    pcall(function()
        local ic = CDataTable.GetTableData("Item", weaponResID)
        if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
    end)
    return found > 0 and found or weaponResID
end



_G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
_G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}

local restoreLobbySkinsFromSettings

local function buildSkinMappings()
    syncWeaponCacheFromLobby()
    local m = _G.AddOutfitSkinIdMappings
    for k in pairs(m) do m[k] = nil end
    for wid, w in pairs(cache().weapons) do
        wid = tonumber(wid)
        if wid and w.resID and w.resID > 0 then
            m[wid] = { tonumber(w.resID) }
        end
    end
end

local function get_skin_id(currentGunId, maxIt)
    currentGunId = tonumber(currentGunId) or 0
    maxIt = tonumber(maxIt) or 0
    if currentGunId <= 0 and maxIt <= 0 then return 0 end
    buildSkinMappings()
    local m = _G.AddOutfitSkinIdMappings
    if maxIt > 0 and m[maxIt] and m[maxIt][1] then return tonumber(m[maxIt][1]) end
    local list = m[currentGunId]
    if list and list[1] then return tonumber(list[1]) end
    local typeId = resolveWeaponTypeID(currentGunId)
    if typeId > 0 and m[typeId] and m[typeId][1] then return tonumber(m[typeId][1]) end
    return currentGunId
end

local function isInRealMatch()
    local ok, r = pcall(function()
        return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
    end)
    return ok and r == true
end

local function getLocalChar()
    local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GD then return nil end
    local char = GD.GetPlayerCharacter and GD.GetPlayerCharacter()
    if char and slua.isValid(char) then return char end
    return nil
end

local function getLobbyOutfitForMatch()
    local cch = cache()
    local outfitRes = tonumber(cch.outfitRes) or 0
    if outfitRes > 0 then return outfitRes end
    outfitRes = tonumber(_G.AddOutfitLastLobbyOutfitRes) or 0
    if outfitRes > 0 then return outfitRes end
    if _G.HK_Settings and tonumber(_G.HK_Settings.LAST_LOBBY_OUTFIT or 0) > 0 then
        return tonumber(_G.HK_Settings.LAST_LOBBY_OUTFIT)
    end
    return nil
end

local function getAvatarComp2(char, needSlotData)
    if not char or not slua.isValid(char) then return nil end
    local comp
    if needSlotData then
        comp = char.AvatarComponent2
        if comp and slua.isValid(comp) and comp.NetAvatarData and comp.NetAvatarData.SlotSyncData then return comp end
    end
    comp = char.CharacterAvatarComp2_BP
    if comp and slua.isValid(comp) then return comp end
    comp = char.AvatarComponent2
    if comp and slua.isValid(comp) then return comp end
    pcall(function()
        if char.getAvatarComponent2 then comp = char:getAvatarComponent2() end
    end)
    if comp and slua.isValid(comp) then return comp end
    return nil
end

local function applyLobbyOutfitToMatch(char)
    if _G.HK_GetVal("UNLOCK_SKIN") ~= 1 then return false end
    local outfitRes = getLobbyOutfitForMatch()
    if not outfitRes or outfitRes <= 0 then return false end
    local comp = getAvatarComp2(char, false)
    if not comp then return false end

    local ok = false
    pcall(function()
        if comp.PutOnCustomEquipmentByID then
            comp:PutOnCustomEquipmentByID(outfitRes)
            ok = true
        end
    end)
    if not ok then
        pcall(function()
            if comp.HandleEquipItem then
                comp:HandleEquipItem(FItemDefineID(4, outfitRes), FAvatarCustomDefault())
                ok = true
            end
        end)
    end
    return ok
end

local function applyLobbyAvatarSlotsToMatch(char)
    if _G.HK_GetVal("UNLOCK_SKIN") ~= 1 then return false end
    local comp = getAvatarComp2(char, true)
    if not comp then return false end

    local data = comp.NetAvatarData
    local slots = data and data.SlotSyncData
    if not slots or not slua.isValid(slots) then return false end

    local slotType = _G.CustSlotType or {}
    local cch = cache()
    local backpackUtils
    pcall(function() backpackUtils = import("BackpackUtils") end)

    local function levelItem(mappedSkin, additionalItemID, levelFunc)
        if type(mappedSkin) ~= "table" then return tonumber(mappedSkin) or 0 end
        local level = 1
        if levelFunc then
            pcall(function() level = tonumber(levelFunc(additionalItemID)) or 1 end)
        end
        if level < 1 then level = 1 end
        if level > 3 then level = 3 end
        return tonumber(mappedSkin[level] or mappedSkin[1]) or 0
    end

    local changed = false
    local function setSlot(slotData, targetSlot, mappedSkin, isLevelDependent, levelFunc)
        if not targetSlot or not mappedSkin then return false end
        if not slotData or slotData.SlotID ~= targetSlot then return false end
        local itemID = mappedSkin
        if isLevelDependent then
            itemID = levelItem(mappedSkin, slotData.AdditionalItemID, levelFunc)
        else
            itemID = tonumber(itemID) or 0
        end
        if itemID <= 0 or slotData.ItemId == itemID then return false end
        if _G.download_item then pcall(_G.download_item, itemID) end
        slotData.ItemId = itemID
        return true
    end

    for i = 0, slots:Num() - 1 do
        local slotData = slots:Get(i)
        local slotChanged = false
        slotChanged = setSlot(slotData, slotType.ClothesEquipemtSlot, tonumber(cch.outfitRes) or tonumber(cch.topRes) or 0, false) or slotChanged
        slotChanged = setSlot(slotData, slotType.PantsEquipemtSlot, tonumber(cch.pantsRes) or 0, false) or slotChanged
        slotChanged = setSlot(slotData, slotType.ShoesEquipemtSlot, tonumber(cch.shoesRes) or 0, false) or slotChanged
        slotChanged = setSlot(slotData, slotType.FaceEquipemtSlot, tonumber(cch.faceRes) or 0, false) or slotChanged
        slotChanged = setSlot(slotData, slotType.BackpackEquipemtSlot, cch.bagRes, true, backpackUtils and backpackUtils.GetEquipmentBagLevel) or slotChanged
        slotChanged = setSlot(slotData, slotType.HelmetEquipemtSlot, cch.helmetRes, true, backpackUtils and backpackUtils.GetEquipmentHelmetLevel) or slotChanged
        if slotChanged then
            slots:Set(i, slotData)
            changed = true
        end
    end

    if changed then
        pcall(function() comp:OnRep_BodySlotStateChanged() end)
    end
    return changed
end

local function getSynMasterSkinID(weapon)
    if not slua.isValid(weapon) then return 0 end
    local id = 0
    pcall(function()
        local arr = weapon.synData
        if arr and slua.isValid(arr) then
            local att = arr:Get(GUN_MASTER_SYN_SLOT)
            if att then
                id = slua.IndexReference(att, "defineID").TypeSpecificID or 0
            end
        end
    end)
    return id
end

local function applyLobbyWeaponSkinToWeapon(weapon)
    if _G.HK_GetVal("UNLOCK_SKIN") ~= 1 then return false end
    if not slua.isValid(weapon) then return false end
    buildSkinMappings()

    local weaponID = 0
    pcall(function()
        if weapon.GetWeaponID then weaponID = tonumber(weapon:GetWeaponID()) or 0 end
        if weaponID <= 0 and weapon.GetItemDefineID then
            weaponID = tonumber(weapon:GetItemDefineID().TypeSpecificID) or 0
        end
    end)
    if weaponID <= 0 then return false end

    local targetSkin = get_skin_id(weaponID, weaponID)
    targetSkin = tonumber(targetSkin) or 0
    if targetSkin <= 0 or targetSkin == weaponID then return false end
    if getSynMasterSkinID(weapon) == targetSkin then return true end

    local arr = weapon.synData
    if not arr or not slua.isValid(arr) then return false end
    local att = arr:Get(GUN_MASTER_SYN_SLOT)
    if not att then return false end

    pcall(function()
        local ref = slua.IndexReference(att, "defineID")
        ref.TypeSpecificID = targetSkin
        arr:Set(GUN_MASTER_SYN_SLOT, att)
    end)

    pcall(function()
        if weapon.SetWeaponAvatarID then weapon:SetWeaponAvatarID(targetSkin) end
    end)
    pcall(function()
        if weapon.DelayHandleAvatarMeshChanged then weapon:DelayHandleAvatarMeshChanged() end
    end)
    pcall(function()
        if weapon.OnRep_synData then weapon:OnRep_synData() end
    end)
    return true
end

local function applyLobbyWeaponSkinToMatch(char)
    if _G.HK_GetVal("UNLOCK_SKIN") ~= 1 then return false end
    if not char or not slua.isValid(char) then return false end
    local weapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
    return applyLobbyWeaponSkinToWeapon(weapon)
end

local function applyLobbySkinToMatch(char)
    char = char or getLocalChar()
    if not char or not slua.isValid(char) then return false end
    restoreLobbySkinsFromSettings()
    syncWeaponCacheFromLobby()
    buildSkinMappings()
    local ok = false
    ok = applyLobbyOutfitToMatch(char) or ok
    ok = applyLobbyAvatarSlotsToMatch(char) or ok
    ok = applyLobbyWeaponSkinToMatch(char) or ok
    return ok
end

_G.HK_ApplyLobbySkinToMatch = applyLobbySkinToMatch

local _matchTimer = nil
local _matchOutfitApplied = false

local function startMatchSkinWatcher(char)
    if _matchTimer then return end
    char = char or getLocalChar()
    if not char or not slua.isValid(char) or not char.AddGameTimer then return end
    syncWeaponCacheFromLobby()
    buildSkinMappings()
    _matchOutfitApplied = false

    local elapsed = 0
    _matchTimer = char:AddGameTimer(1.5, true, function()
        elapsed = elapsed + 1.5
        local cur = getLocalChar()
        if not cur then return end
        if not _matchOutfitApplied then
            _matchOutfitApplied = applyLobbyOutfitToMatch(cur)
        end
        applyLobbySkinToMatch(cur)
        if elapsed >= 120 then
            if cur.RemoveGameTimer then pcall(function() cur:RemoveGameTimer(_matchTimer) end) end
            _matchTimer = nil
        end
    end)
end

local function stopMatchSkinWatcher()
    if _matchTimer then
        pcall(function()
            local char = getLocalChar()
            if char and char.RemoveGameTimer then char:RemoveGameTimer(_matchTimer) end
        end)
    end
    _matchTimer = nil
    _matchOutfitApplied = false
end

local function hookMatchLobbySkin()
    pcall(function()
        local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
        local o = CAC.OnAvatarAllMeshLoadedLua
        CAC.OnAvatarAllMeshLoadedLua = function(self)
            o(self)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                if self.IsSelf and not self:IsSelf() then return end
                startMatchSkinWatcher(getLocalChar())
            end)
        end
    end)

    pcall(function()
        local WAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.WeaponAvatarComponent")
        local oLoad = WAC.OnWeaponAvatarLoadedLua
        WAC.OnWeaponAvatarLoadedLua = function(self, slotID, definedID)
            oLoad(self, slotID, definedID)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                if self.IsSelf and not self:IsSelf() then return end
                local char = getLocalChar()
                if char and char.AddGameTimer then
                    char:AddGameTimer(0.2, false, function() applyLobbyWeaponSkinToMatch(getLocalChar()) end)
                end
            end)
        end
    end)

    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
                syncWeaponCacheFromLobby()
                stopMatchSkinWatcher()
            end)
        end
    end)
end

local function hookPutOnRsp()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.on_puton_rsp
        wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
            o(self, res, item, olditem, index, extra)
            if not item or not item.instid then return end
            local resID = tonumber(item.res_id)
            local insID = tonumber(item.instid)
            if not resID or not insID then return end
            local c = cfg(resID)
            local st = subType(c)
            if getClothKind(resID) == "full_suit" and isInjectedIns(insID) then
                saveEquip(resID, insID)
            elseif GUN_SUB[st] then
                local wid = weaponIdFromSkin(resID)
                if wid then cacheWeaponSkinFromIns(wid, insID) end
            elseif st == MELEE_ID then
                cacheWeaponSkinFromIns(MELEE_ID, insID)
            elseif isInjectedIns(insID) then
                saveEquip(resID, insID)
            end
        end
    end)
end

local function hookLobbyWeaponCache()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local oRsp = Arm.install_weapon_skin_rsp
        Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
            oRsp(client_data, errorCode, weapon_id, instanceID)
            if not _G.LobbyCosmeticEnabled then return end
            if errorCode == 0 or errorCode == NET_OK then
                cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
        local oH = Arm.HandleWeaponSkinChange
        Arm.HandleWeaponSkinChange = function(client_data, weapon_id, instanceID)
            oH(client_data, weapon_id, instanceID)
            if not _G.LobbyCosmeticEnabled then return end
            cacheWeaponSkinFromIns(weapon_id, instanceID)
        end
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        local o = wgl.on_put_on_weapon_wear_rsp
        wgl.on_put_on_weapon_wear_rsp = function(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            o(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            if not _G.LobbyCosmeticEnabled then return end
            if res == 0 or res == NET_OK then
                cacheWeaponSkinFromIns(weapon_id, new_skin_id)
            end
        end
    end)
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function(_, _, resOrFlag, weapon_id)
                if not _G.LobbyCosmeticEnabled then return end
                weapon_id = tonumber(weapon_id)
                if weapon_id and weapon_id > 0 then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        local insID = tonumber(wgl:GetSkinIdByWeaponID(weapon_id)) or 0
                        if insID > 0 then cacheWeaponSkinFromIns(weapon_id, insID) end
                    end)
                elseif tonumber(resOrFlag) and tonumber(resOrFlag) > 100000 then
                    pcall(function()
                        local wid = weaponIdFromSkin(resOrFlag)
                        if wid then
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local ins = wd.GetWardrobeInsIdByResId and wd:GetWardrobeInsIdByResId(resOrFlag)
                            if ins and ins > 0 then cacheWeaponSkinFromIns(wid, ins) end
                        end
                    end)
                end
            end)
        end
    end)
end

local function hookWardrobePutOnReq()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.wardrobe_puton_req
        wl.wardrobe_puton_req = function(self, insID, extra)
            insID = tonumber(insID)
            if isInjectedIns(insID) then
                local resID = R.insToRes[insID]
                local itemCfg = cfg(resID)
                local st = subType(itemCfg)
                local isSpecial = isSpecialWearRes(resID, itemCfg)
                if getClothKind(resID) then
                    putOnCloth(insID)
                    return
                end
                if isSpecial and putOnSpecialWear(insID) then
                    return
                end
                local item = { res_id = resID, count = 1, instid = insID }
                if itemCfg and itemCfg.WardrobeMainTab == 6
                    and itemCfg.WardrobeTab ~= 7
                    and itemCfg.WardrobeTab ~= 11
                then
                    local WRH = require("client.network.Protocol.WardRobeHandler")
                    WRH.on_depot_put_on_rsp("ok", item, nil, 0, insID, 0)
                    return
                end
                local WRH = require("client.network.Protocol.WardRobeHandler")
                WRH.on_depot_put_on_rsp("ok", item, nil, 0, insID, 0)
                return
            end
            return o(self, insID, extra)
        end
    end)
end

local function hookWardrobePutDownReq()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.wardrobe_put_down_req
        wl.wardrobe_put_down_req = function(self, insID)
            insID = tonumber(insID)
            if isInjectedIns(insID) then
                local resID = R.insToRes[insID]
                local itemCfg = cfg(resID)
                local st = subType(itemCfg)
                local isSpecial = isSpecialWearRes(resID, itemCfg)
                if itemCfg and itemCfg.WardrobeMainTab == 6 then
                    DataMgr.vst_skin = 0
                    local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
                    HallThemeUtils.UpdateThemeVehicleShow()
                    HallThemeUtils.ShowThemeVehicle()
                    return
                end
                if isSpecial then
                    local cch = cache()
                    if getBagArray(resID) then
                        cch.bagRes = nil
                        cch.bagInsID = nil
                        if _G.HK_Settings then
                            _G.HK_Settings.LAST_LOBBY_BAG = 0
                            _G.SaveModSettings()
                        end
                    elseif getHelmetArray(resID) then
                        cch.helmetRes = nil
                        cch.helmetInsID = nil
                        if _G.HK_Settings then
                            _G.HK_Settings.LAST_LOBBY_HELMET = 0
                            _G.SaveModSettings()
                        end
                    elseif st == 407 then
                        cch.gloveRes = nil
                        cch.gloveInsID = nil
                        if _G.HK_Settings then
                            _G.HK_Settings.LAST_LOBBY_GLOVE = 0
                            _G.SaveModSettings()
                        end
                    elseif st == ST_TOP then
                        cch.topRes = nil
                        cch.topInsID = nil
                        if _G.HK_Settings then
                            _G.HK_Settings.LAST_LOBBY_TOP = 0
                            _G.SaveModSettings()
                        end
                    elseif st == ST_PANTS then
                        cch.pantsRes = nil
                        cch.pantsInsID = nil
                        if _G.HK_Settings then
                            _G.HK_Settings.LAST_LOBBY_PANTS = 0
                            _G.SaveModSettings()
                        end
                    elseif st == ST_SHOES then
                        cch.shoesRes = nil
                        cch.shoesInsID = nil
                        if _G.HK_Settings then
                            _G.HK_Settings.LAST_LOBBY_SHOES = 0
                            _G.SaveModSettings()
                        end
                    elseif st == 402 or st == 406 then
                        cch.faceRes = nil
                        cch.faceInsID = nil
                        if _G.HK_Settings then
                            _G.HK_Settings.LAST_LOBBY_FACE = 0
                            _G.SaveModSettings()
                        end
                    end
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    local d = wd:GetHallDepotItemDataByInsID(insID)
                    local item = d and { res_id = resID, count = d.count or 1, instid = insID }
                    local WRH = require("client.network.Protocol.WardRobeHandler")
                    WRH.on_depot_put_down_rsp("ok", item, insID)
                    return
                end
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetHallDepotItemDataByInsID(insID)
                local item = d and { res_id = resID, count = d.count or 1, instid = insID }
                local WRH = require("client.network.Protocol.WardRobeHandler")
                WRH.on_depot_put_down_rsp("ok", item, insID)
                return
            end
            return o(self, insID)
        end
    end)
end

local function hookWeaponSkinPersist()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local o_send_wear = WRH.send_put_on_weapon_wear
        WRH.send_put_on_weapon_wear = function(client_data, weapon_id, extra_weapon_id_list)
            if weapon_id and weapon_id > 0 and _weaponSkinCache[weapon_id] then
                local cached = _weaponSkinCache[weapon_id]
                if isInjectedIns(cached.insID) then
                    local gunLogic = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                    gunLogic:on_put_on_weapon_wear_rsp(client_data, 0, weapon_id, cached.insID, extra_weapon_id_list)
                    return
                end
            end
            return o_send_wear(client_data, weapon_id, extra_weapon_id_list)
        end
    end)
end

restoreLobbySkinsFromSettings = function()
    pcall(function()
        if _G.HK_Settings then
            local cch = cache()
            if _G.HK_Settings.LAST_LOBBY_OUTFIT and _G.HK_Settings.LAST_LOBBY_OUTFIT > 0 then
                cch.outfitRes = _G.HK_Settings.LAST_LOBBY_OUTFIT
                cch.outfitIns = R.resToIns[_G.HK_Settings.LAST_LOBBY_OUTFIT] or 0
                _G.AddOutfitLastLobbyOutfitRes = _G.HK_Settings.LAST_LOBBY_OUTFIT
            end
            
            -- Restore Backpack
            if _G.HK_Settings.LAST_LOBBY_BAG and _G.HK_Settings.LAST_LOBBY_BAG > 0 then
                local idx = _G.HK_Settings.LAST_LOBBY_BAG
                if _G.OutfitSkins and _G.OutfitSkins.Bag and _G.OutfitSkins.Bag[idx] then
                    cch.bagRes = _G.OutfitSkins.Bag[idx]
                    cch.bagInsID = R.resToIns[cch.bagRes[1]] or 0
                end
            end

            -- Restore Helmet
            if _G.HK_Settings.LAST_LOBBY_HELMET and _G.HK_Settings.LAST_LOBBY_HELMET > 0 then
                local idx = _G.HK_Settings.LAST_LOBBY_HELMET
                if _G.OutfitSkins and _G.OutfitSkins.Helmet and _G.OutfitSkins.Helmet[idx] then
                    cch.helmetRes = _G.OutfitSkins.Helmet[idx]
                    cch.helmetInsID = R.resToIns[cch.helmetRes[1]] or 0
                end
            end

            -- Restore Gloves
            if _G.HK_Settings.LAST_LOBBY_GLOVE and _G.HK_Settings.LAST_LOBBY_GLOVE > 0 then
                local resID = _G.HK_Settings.LAST_LOBBY_GLOVE
                cch.gloveRes = resID
                cch.gloveInsID = R.resToIns[resID] or 0
            end

            -- Restore Top
            if _G.HK_Settings.LAST_LOBBY_TOP and _G.HK_Settings.LAST_LOBBY_TOP > 0 then
                cch.topRes = _G.HK_Settings.LAST_LOBBY_TOP
                cch.topInsID = R.resToIns[_G.HK_Settings.LAST_LOBBY_TOP] or 0
            end

            -- Restore Pants
            if _G.HK_Settings.LAST_LOBBY_PANTS and _G.HK_Settings.LAST_LOBBY_PANTS > 0 then
                cch.pantsRes = _G.HK_Settings.LAST_LOBBY_PANTS
                cch.pantsInsID = R.resToIns[_G.HK_Settings.LAST_LOBBY_PANTS] or 0
            end

            -- Restore Shoes
            if _G.HK_Settings.LAST_LOBBY_SHOES and _G.HK_Settings.LAST_LOBBY_SHOES > 0 then
                cch.shoesRes = _G.HK_Settings.LAST_LOBBY_SHOES
                cch.shoesInsID = R.resToIns[_G.HK_Settings.LAST_LOBBY_SHOES] or 0
            end

            -- Restore Face
            if _G.HK_Settings.LAST_LOBBY_FACE and _G.HK_Settings.LAST_LOBBY_FACE > 0 then
                cch.faceRes = _G.HK_Settings.LAST_LOBBY_FACE
                cch.faceInsID = R.resToIns[_G.HK_Settings.LAST_LOBBY_FACE] or 0
            end

            local weaponsList = {101001, 101003, 101004, 101005, 101006, 101008, 102001, 102002, 104003, 104004}
            for _, wid in ipairs(weaponsList) do
                local key = "LAST_LOBBY_WEAPON_" .. wid
                if _G.HK_Settings[key] and _G.HK_Settings[key] > 0 then
                    local resID = _G.HK_Settings[key]
                    local insID = R.resToIns[resID] or 0
                    cch.weapons[wid] = { resID = resID, insID = insID }
                    _weaponSkinCache[wid] = { resID = resID, insID = insID }
                end
            end
        end
    end)
end

local function start()
    buildSkinMappings()
    _G.LobbyGetSkinId = get_skin_id
    
    _G.skinIdMappings = _G.AddOutfitSkinIdMappings
    hookDepotInit()
    hookWardrobeData()
    hookPageFilter()
    hookArmory()
    hookGunSkinId()
    hookPutOn()
    hookWeaponWear()
    hookAvatarValid()
    hookPutOnRsp()
    hookLobbyWeaponCache()
    hookLobbySwipePersistence()
    hookWardrobePutOnReq()
    hookWardrobePutDownReq()
    hookWeaponSkinPersist()
    hookMatchLobbySkin()

    pcall(function()
        if isInRealMatch() then
            startMatchSkinWatcher(getLocalChar())
        end
    end)

    if injectAll() then
        restoreLobbySkinsFromSettings()
        refreshWardrobe()
        later(1.0, reapplyLobbyEquipped)
        return
    end
    local tries = 0
    local function retry()
        tries = tries + 1
        if injectAll() then
            restoreLobbySkinsFromSettings()
            refreshWardrobe()
            later(1.0, reapplyLobbyEquipped)
            return
        end
        if tries < 40 then later(1.5, retry) end
    end
    later(1.5, retry)
end

        start()
    end)
end

-- =========================== PHẦN 30: CÁC HÀM GỐC CÒN LẠI ===========================
function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
    self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
    self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

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
  local uMeshContainerExpectedZ = -1 + self.StandHalfHeight
  local nExpectedCapsuleRadius = self.StandRadius
  local nExpectedCapsuleHalfHeight = self.StandHalfHeight
  local uMeshExpectedRL = FVector(0, 0, 0)
  local uActorExpectedRL = FVector(0, 0, self.StandHalfHeight)
  local nTolerance = 1.0
  local bCapsuleRLCorrect = uActorRelativeLocation:Equals(uActorExpectedRL, nTolerance)
  local bMeshRLCorrect = uMeshRelativeLocation:Equals(uMeshExpectedRL, nTolerance)
  local bMeshContainerRLCorrect = nTolerance > math.abs(uMeshContainerRelativeLocationZ * uMeshContainerExpectedZ)
  local bCapsuleRadiusCorrect = nTolerance > math.abs(nCapsuleRadius * nExpectedCapsuleRadius)
  local bCapsuleHalfHeightCorrect = nTolerance > math.abs(nCapsuleHalfHeight * nExpectedCapsuleHalfHeight)
  local bAllCorrect = bStand and bCapsuleRLCorrect and bMeshRLCorrect and bMeshContainerRLCorrect and bCapsuleRadiusCorrect and bCapsuleHalfHeightCorrect
  if not bAllCorrect then
    self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount - 1
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
  local uMeshContainerExpectedZ = -1 + self.StandHalfHeight
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  if nTolerance <= math.abs(uMeshContainerRelativeLocationZ * uMeshContainerExpectedZ) then
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

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  local EPawnState = import("EPawnState")
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
    self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local EGameModeType = import("EGameModeType")
    local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = MatchModeIds[GameModeID] - self
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  local EParachuteState = import("EParachuteState")
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
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

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uGameState = GameplayData:GetGameState()
  local STExtraGameStateBase = import("STExtraGameStateBase")
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    local EGameModeType = import("EGameModeType")
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  local EMovementMode = import("EMovementMode")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

-- =========================================================================
--  TRẢ VỀ MÃ NGUỒN GỐC NẾU CHƯA ĐƯỢC DUYỆT HOẶC MẤT KẾT NỐI (ORIGINAL CODE BELOW)
-- =========================================================================

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local UKismetSystemLibrary = import("KismetSystemLibrary")
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " % tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
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

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      local EStateType = import("EStateType")
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        local ESTEPoseState = import("ESTEPoseState")
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return uPlayerState.CanUseFlaregun - self
end

-- Net Multicast and RPC helper targets
function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " % tostring(actionId))
  local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " % tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " % tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " % tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  
  local function loadLater()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " % tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") - 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " % tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
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
                LocalPlayer.HK_NativeESP_Ready = false
            end
            if type(LocalPlayer.StartAdvancedSystems) == "function" then
                pcall(function() 
                    LocalPlayer:StartAdvancedSystems() 
                end)
            end
        end
    end)
end

pcall(function() 
    require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) 
end)

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

