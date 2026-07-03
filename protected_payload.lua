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

        local StackAimbot = { { UI = AliasMap.Title, Text = "AIMBOT & GIẢM GIẬT" } }
        AddToggle(StackAimbot, "AIMBOT", "BẬT AIMBOT")
        AddSlider(StackAimbot, "SPEED_AIMBOT", "TỐC ĐỘ AIMBOT", 0, 100)
        AddSlider(StackAimbot, "FOV_AIMBOT", "FOV AIMBOT", 0, 100)
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
            { Key = "ModMenu_AT_Hip_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-500m)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.HK_Settings.AimTouchHipDist or 250) / 5) end, SetFunc = function(_, v) _G.HK_Settings.AimTouchHipDist = v * 5 return true end },

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
            { Key = "ModMenu_AT_ScopeAll_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-500m)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.HK_Settings.AimTouchScopeDist or 300) / 5) end, SetFunc = function(_, v) _G.HK_Settings.AimTouchScopeDist = v * 5 return true end },
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
            { Key = "ModMenu_AT_Sniper_Dist", UI = AliasMap.Slider, Text = "      Khoảng Cách (1-500m)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.HK_Settings.AimTouchSniperDist or 400) / 5) end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperDist = v * 5 return true end },
            { Key = "ModMenu_AT_Sniper_Pred", UI = AliasMap.Slider, Text = "      Dự Đoán Hướng Chạy (0-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.HK_Settings.AimTouchSniperPred or 0 end, SetFunc = function(_, v) _G.HK_Settings.AimTouchSniperPred = v return true end }
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
        
        SettingPageDefine.ModMenu = {
            Key = "ModMenu", loc = "VIP MENU", UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "ModMenu_Cat1", loc = "ESP", Stack = StackESP },
                { Key = "ModMenu_Cat6", loc = "ESP VẬT PHẨM", Stack = StackItemESP },
                { Key = "ModMenu_Cat2", loc = "AIMBOT & VŨ KHÍ", Stack = StackAimbot },
                { Key = "ModMenu_Cat5", loc = "AIMBOT ROYAL & CUSTOM", Stack = StackAimbotV2 },
                { Key = "ModMenu_Cat3", loc = "MAGIC BULLET", Stack = StackMagic },
                { Key = "ModMenu_Cat4", loc = "GÓC NHÌN & MÔI TRƯỜNG", Stack = StackEnv },
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

local ThreatESP_VisCache = {}
local ThreatESP_FireCache = {}

local function UpdateThreatAssessmentESP(LocalPlayer, PlayerController, MyHUD)
    if _G.HK_GetVal("THREAT_ESP") ~= 1 then
        return
    end
    
    if not slua.isValid(LocalPlayer) or not slua.isValid(PlayerController) or not slua.isValid(MyHUD) then return end
    
    local curTime = os.clock()
    local allChars = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
    local myTeam = LocalPlayer.TeamID
    local myLoc = LocalPlayer:K2_GetActorLocation()
    if not myLoc then return end
    
    for _, enemy in pairs(allChars) do
        if not slua.isValid(enemy) or enemy == LocalPlayer then goto continue_threat end
        if enemy.TeamID == myTeam then goto continue_threat end
        
        local eId = tostring(enemy)
        
        -- Check dead
        local isDead = false
        pcall(function()
            if enemy.bIsDead or enemy.bIsDeadFlag then isDead = true end
            if type(enemy.IsDead) == "function" and enemy:IsDead() then isDead = true end
        end)
        if isDead then 
            ThreatESP_FireCache[eId] = nil
            goto continue_threat 
        end
        
        -- Khoảng cách check 800m
        local dist = 0
        pcall(function() dist = LocalPlayer:GetDistanceTo(enemy) / 100 end)
        if dist > 800 or dist < 3 then goto continue_threat end
        
        -- VisCheck cache 0.1s
        local isVisible = true
        local visCacheKey = tostring(enemy)
        local cached = ThreatESP_VisCache[visCacheKey]
        if cached and (curTime - cached.time) < 0.1 then
            isVisible = cached.visible
        else
            pcall(function()
                if slua.isValid(PlayerController) and PlayerController.LineOfSightTo then
                    isVisible = PlayerController:LineOfSightTo(enemy) and true or false
                end
            end)
            ThreatESP_VisCache[visCacheKey] = { visible = isVisible, time = curTime } 
        end
        
        -- LOGIC PHÁT HIỆN MỐI ĐE DỌA 3 MỨC ĐỘ
        local threatLevel = 0
        local eLoc = enemy:K2_GetActorLocation()
        
        if eLoc then
            local toMeX = myLoc.X - eLoc.X
            local toMeY = myLoc.Y - eLoc.Y
            local len2D = math.sqrt(toMeX*toMeX + toMeY*toMeY)
            
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
                    pcall(function()
                        local ESTEPoseState = import("ESTEPoseState")
                        if enemy.PoseState == ESTEPoseState.Prone then
                            poseAdjust = -0.05
                        elseif enemy.PoseState == ESTEPoseState.Crouch then
                            poseAdjust = -0.02
                        end
                    end)
                    
                    local thresholdLook = 0.7 + poseAdjust
                    local thresholdAim = 0.9 + poseAdjust
                    
                    local isEnemyADS = false
                    local isEnemyFiring = false
                    pcall(function()
                        isEnemyADS = (enemy.bIsWeaponAiming == true) or (enemy.bIsGunADS == true)
                        isEnemyFiring = (enemy.bIsWeaponFiring == true)
                    end)
                    
                    if isEnemyFiring then
                        ThreatESP_FireCache[eId] = curTime
                    end
                    local lastFireTime = ThreatESP_FireCache[eId] or 0
                    local isRecentlyFiring = (curTime - lastFireTime) < 1.0
                    
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
        
        -- HIỂN THỊ TEXT CẢNH BÁO (KHÔNG ĐỔI MÀU MESH)
        if threatLevel >= 1 and isVisible then
            if threatLevel == 3 then
                local threatText = "  ĐANG NGẮM BẮN BẠN "
                if dist > 200 then
                    threatText = string.format("  SNIPER NGẮM BẠN [%dm] ", math.floor(dist))
                end
                
                MyHUD:AddDebugText(threatText, enemy, 0.2, 
                    {X=0, Y=0, Z=130}, {X=0, Y=0, Z=130}, 
                    {R=255, G=0, B=0, A=255}, true, false, true, nil, 1.0, true)
                
            elseif threatLevel == 2 then
                MyHUD:AddDebugText("  ĐANG AIM VỀ BẠN", enemy, 0.2,
                    {X=0, Y=0, Z=120}, {X=0, Y=0, Z=120},
                    {R=255, G=140, B=0, A=255}, true, false, true, nil, 0.9, true)
                    
            else
                MyHUD:AddDebugText("  ĐANG NHÌN VỀ BẠN", enemy, 0.2,
                    {X=0, Y=0, Z=110}, {X=0, Y=0, Z=110},
                    {R=255, G=200, B=0, A=255}, true, false, true, nil, 0.7, true)
            end
        end
        
        ::continue_threat::
    end

    -- Cleanup FireCache cũ (> 5s)
    for eId, t in pairs(ThreatESP_FireCache) do
        if (curTime - t) > 1.5 then
            ThreatESP_FireCache[eId] = nil
        end
    end

    -- Cleanup VisCache cũ (> 3s)
    for k, v in pairs(ThreatESP_VisCache) do
        if (curTime - v.time) > 1.0 then
            ThreatESP_VisCache[k] = nil
        end
    end
end



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
        }
        
        -- Đưa tất cả các thông số nhạy cảm về an toàn (0)
        _G.HK_Settings.AIMBOT = 0
        _G.HK_Settings.MAGIC_HEAD = 0
        _G.HK_Settings.MAGIC_BODY = 0
        _G.HK_Settings.MAGIC_LEGS = 0
        
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

        cache_AimTouchEnable = _G.HK_GetVal("AimTouchEnable") or 0
        cache_AUTO_BUNNYHOP = _G.HK_GetVal("AUTO_BUNNYHOP") or 0



        if self.Object == LocalPlayer and not self.bHasShownWelcomeNotice then
            if self.Object.IsAlive and self.Object:IsAlive() then
                self.bHasShownWelcomeNotice = true
                pcall(function()
                    local msgBox = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
                    if msgBox and msgBox.Show then
                        local formattedExpire = "Kiểm tra hạn trong Web Admin"
                        msgBox.Show(4, "THÔNG BÁO", "WELCOME TO VIP MOD MENU\n MOD Được Tạo Bởi Haku X DX\nMỞ CÀI ĐẶT -> VIP MENU ĐỂ TÙY CHỈNH\nHạn sử dụng đến: " .. formattedExpire, function() 
                            local KismetSystemLibrary = import("KismetSystemLibrary")
                            if KismetSystemLibrary then KismetSystemLibrary.LaunchURL("https://t.me/DeerXua") end
                        end, function() end, "THAM GIA", "HỦY")
                    end
                end)
            end
        end

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
                            local isInitialized = false
                            if shootWeaponEntity.RecoilInfo and (shootWeaponEntity.RecoilInfo.VerticalRecoilMin or 0.0) > 0.0 then
                                isInitialized = true
                            elseif (shootWeaponEntity.RecoilKick or 0.0) > 0.0 then
                                isInitialized = true
                            end
                            
                            if isInitialized then
                                cache = {
                                    HK_OrigRecoilKick = shootWeaponEntity.RecoilKick or 0.0,
                                    HK_OrigAccessoriesV = shootWeaponEntity.AccessoriesVRecoilFactor or 1.0,
                                    HK_OrigAccessoriesH = shootWeaponEntity.AccessoriesHRecoilFactor or 1.0,
                                    HK_OrigRecoilKickADS = shootWeaponEntity.RecoilKickADS or 0.20,
                                    HK_OrigModStand = shootWeaponEntity.RecoilModifierStand or 1.0,
                                    HK_OrigModCrouch = shootWeaponEntity.RecoilModifierCrouch or 1.0,
                                    HK_OrigModProne = shootWeaponEntity.RecoilModifierProne or 1.0
                                }
                                if shootWeaponEntity.RecoilInfo then
                                    cache.HK_OrigVRecoilMin = shootWeaponEntity.RecoilInfo.VerticalRecoilMin or 0.0
                                    cache.HK_OrigVRecoilMax = shootWeaponEntity.RecoilInfo.VerticalRecoilMax or 0.0
                                    cache.HK_OrigSpeedV = shootWeaponEntity.RecoilInfo.RecoilSpeedVertical or 0.0
                                    cache.HK_OrigSpeedH = shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal or 0.0
                                    cache.HK_OrigRecoveryMax = shootWeaponEntity.RecoilInfo.VerticalRecoveryMax or 0.0
                                end
                                _G.HK_WeaponCache[objName] = cache
                            end
                        end

if cache then
    -- ===== THÊM: Tính hệ số giảm rung khi đang ngắm (ADS) =====
    local isADS = self.Object and self.Object.bIsWeaponAiming == true
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
        -- LƯU Ý: Đã xóa *(1.0 - scopeRecoilScale) cũ vì scopeFactor đã được tính gộp vào factor phía trên (tránh bị giảm 2 lần gây lỗi toán học)
        shootWeaponEntity.RecoilKickADS = (cache.HK_OrigRecoilKickADS or 0.20) * factor
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
        -- LƯU Ý: Đã xóa *(1.0 - scopeRecoilScale) cũ vì đã tính gộp vào factor
        shootWeaponEntity.RecoilKickADS = (cache.HK_OrigRecoilKickADS or 0.20) * factor
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

            local allPlayers = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
            local PlayerController = GameplayData.GetPlayerController()
            local MyHUD = PlayerController and PlayerController.MyHUD

            local localPlayerLoc = nil
            pcall(function() localPlayerLoc = LocalPlayer:K2_GetActorLocation() end)

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

            for _, enemy in pairs(allPlayers) do
                if Valid(enemy) and enemy ~= LocalPlayer and enemy.TeamID ~= myTeamID then
                    local isEnemyDead = false
                    local isEnemyKnocked = false
                    local currentHp, maxHp = 100, 100

                    pcall(function()
                        if type(enemy.IsNearDeath) == "function" then isEnemyKnocked = enemy:IsNearDeath()
                        elseif enemy.bIsNearDeath ~= nil then isEnemyKnocked = enemy.bIsNearDeath end

                        if type(enemy.IsDead) == "function" then isEnemyDead = enemy:IsDead()
                        elseif enemy.bIsDead ~= nil then isEnemyDead = enemy.bIsDead
                        elseif enemy.bIsDeadFlag ~= nil then isEnemyDead = enemy.bIsDeadFlag end

                        if enemy.bHidden or (enemy.Mesh and enemy.Mesh.bHidden) then isEnemyDead = true end

                        if not isEnemyKnocked and not isEnemyDead then
                            if type(enemy.GetHealth) == "function" then currentHp = enemy:GetHealth()
                            elseif enemy.Health ~= nil then currentHp = enemy.Health end
                            if currentHp <= 0 then isEnemyDead = true end
                        end
                        
                        if type(enemy.GetHealthMax) == "function" then maxHp = enemy:GetHealthMax()
                        elseif enemy.HealthMax ~= nil then maxHp = enemy.HealthMax end
                        if maxHp <= 0 then maxHp = 100 end
                    end)
                    
                    if not isEnemyDead then
                        if enemy.HK_IsAICached == nil then enemy.HK_IsAICached = CheckIsAI(enemy) end
                        
                        local distM = 0
                        pcall(function()
                            if type(LocalPlayer.GetDistanceTo) == "function" then
                                distM = LocalPlayer:GetDistanceTo(enemy) / 100
                            elseif localPlayerLoc then
                                local eLoc = type(enemy.K2_GetActorLocation) == "function" and enemy:K2_GetActorLocation() or FVecZero
                                distM = math_sqrt((localPlayerLoc.X-eLoc.X)^2 + (localPlayerLoc.Y-eLoc.Y)^2 + (localPlayerLoc.Z-eLoc.Z)^2) / 100
                            end
                        end)
                   
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

                        if espWeaponStance and Valid(MyHUD) and distM <= 400 then
                            pcall(function()
                                -- 1. Lấy thông tin vũ khí
                                if not enemy.HK_LastWeaponTime or currentTickOS > enemy.HK_LastWeaponTime + 1.5 then
                                    local eWeapon = nil
                                    if enemy.CurrentWeapon then eWeapon = enemy.CurrentWeapon
                                    elseif type(enemy.GetCurrentWeapon) == "function" then eWeapon = enemy:GetCurrentWeapon()
                                    elseif enemy.WeaponManagerComponent then eWeapon = enemy.WeaponManagerComponent.CurrentWeaponReplicated end
                                    
                                    local weaponName = "Tay Không"
                                    if Valid(eWeapon) and type(eWeapon.GetWeaponName) == "function" then weaponName = eWeapon:GetWeaponName() end
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

                                -- Ghép thông tin hiển thị (Ví dụ: "M416 [Ngồi]")
                                local stateText = string.format("%s [%s]", enemy.HK_CachedWeaponName or "Tay Không", poseText)

                                -- 3. Kiểm tra Visibility (Check Vis) có cache để tối ưu hóa hiệu năng
                                local curTime = os.clock()
                                local enemyId = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy)
                                local pc = GameplayData.GetPlayerController()
                                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                                if not _G.AimTouchVisCache[enemyId] or (curTime - _G.AimTouchVisCache[enemyId].time) > 0.2 then
                                    local isHidden = true
                                    if Valid(pc) then
                                        pcall(function() if pc:LineOfSightTo(enemy) then isHidden = false end end)
                                    end
                                    _G.AimTouchVisCache[enemyId] = { hidden = isHidden, time = curTime }
                                end
                                
                                -- Đổi màu: Xanh lá khi nhìn thấy (Visible), Đỏ khi bị che (Behind wall)
                                local textColor = _G.AimTouchVisCache[enemyId].hidden and COLOR_RED or COLOR_GREEN
                                
                                if _G.HK_GetVal("THREAT_ESP") == 1 and not _G.AimTouchVisCache[enemyId].hidden and enemy.bIsWeaponFiring == true then
                                    local flashOn = (math.floor(curTime * 6) % 2 == 0)
                                    textColor = flashOn and {R=255, G=0, B=0, A=255} or {R=80, G=0, B=0, A=255}
                                end

                                MyHUD:AddDebugText(stateText, enemy, 0.5, {X=0, Y=0, Z=-110}, {X=0, Y=0, Z=-110}, textColor, true, false, true, nil, dynamicScale, true)
                            end)
                        end

                        -- [MỚI] LOGIC ESP KHUNG BOX
                        local showFrameUI = (_G.HK_GetVal("ESP_BOX") == 1 or _G.HK_GetVal("EspLoai5") == 1)
                        if showFrameUI then
                            pcall(function()
                                local SecurityCommonUtils = nil
                                pcall(function() SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
                                local show = true
                                if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                    if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                                end
                                
                                local enemyLoc = type(enemy.K2_GetActorLocation) == "function" and enemy:K2_GetActorLocation() or nil
                                if show and enemyLoc and localPlayerLoc then
                                    local dist2D = math.sqrt((enemyLoc.X - localPlayerLoc.X)^2 + (enemyLoc.Y - localPlayerLoc.Y)^2)
                                    if enemyLoc.Z >= 150000 or dist2D > 50000 then show = false end
                                end
                                
                                if show then
                                    if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                    if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                    
                                    local hpRatio = currentHp / maxHp
                                    if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                                    
                                    local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                    if Valid(uiComp) then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                    end
                                else
                                    if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                                    local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                    if Valid(uiComp) then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    end
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


                        local enemyMesh = enemy.Mesh or (enemy.getAvatarComponent2 and enemy:getAvatarComponent2())
                        if Valid(enemyMesh) then
                            if not enemyMesh.LastHitboxUpdateVersion or enemyMesh.LastHitboxUpdateVersion ~= _G.MagicUpdateVersion then
                                enemyMesh.bIsTDHitboxModded = false
                            end
                            
                            if not enemyMesh.bIsTDHitboxModded then
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
                                        if _G.HK_ModdedPhysAssets[PhysAssetName] ~= _G.MagicUpdateVersion then
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
                                                        local TargetScale = BoneScaleMap[MatchedBoneKey]
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
                                    end
                                end)
                                enemyMesh.bIsTDHitboxModded = true
                                enemyMesh.LastHitboxUpdateVersion = _G.MagicUpdateVersion
                            end
                        end
                    else
                        if enemy.WallhackApplied then
                            local cMeshes = enemy.HK_CachedMeshes or {}
                            pcall(function()
                                local auraMeshes = enemy.HK_AuraMeshes or cMeshes
                                for _, comp in ipairs(auraMeshes) do
                                    if Valid(comp) then
                                        ResetMeshAuraComponent(comp)
                                    end
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
                        
                        -- Nhập class Wrapper của vật phẩm rơi dưới đất với cơ chế fallback và an toàn cao
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

                            -- Quét danh sách vật phẩm dưới đất 1.0s/lần để bảo toàn hiệu năng FPS
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
                                                -- Trích xuất ID vật phẩm từ wrapper qua cấu trúc FBattleItemData
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
                                                
                                                -- Lấy tên vật phẩm tương ứng từ DataTable của game nếu có ID
                                                local itemName = ""
                                                if itemID then
                                                    pcall(function()
                                                        local itemCfg = CDataTable.GetTableData("Item", itemID)
                                                        if itemCfg then
                                                            itemName = itemCfg.ItemName or itemCfg.itemName or ""
                                                        end
                                                    end)
                                                end
                                                
                                                -- Tổng hợp chuỗi định danh chữ thường
                                                local nameLower = string.lower(tostring(itemName) .. "_" .. tostring(itemID or "") .. "_" .. tostring(pickup))
                                                local matchedKeyword = nil
                                                local mapping = nil
                                                
                                                -- 1. Tìm khớp trực tiếp theo ID trong bản đồ weapon map
                                                if itemID and _G.HK_WeaponMap[itemID] then
                                                    mapping = _G.HK_WeaponMap[itemID]
                                                else
                                                    -- 2. Tìm khớp theo từ khoá chuỗi
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
                                                    -- Kiểm tra cấu hình bật/tắt của danh mục cha và của súng con
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

                            -- Thực hiện vẽ text định vị các vật phẩm hợp lệ
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

            -- [NEW] Threat Assessment ESP
            pcall(function()
                UpdateThreatAssessmentESP(LocalPlayer, PlayerController, MyHUD)
            end)
            
            -- [NEW] Dynamic Ghost Mode
            pcall(function()
                UpdateGhostMode()
            end)
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
        pcall(function()
            _G.HK_Settings = _G.HK_Settings or {}
            _G.HK_Settings.FAKE_HWID = 1       -- Đảm bảo luôn bật
            if HK_RegenerateAllFakeData then
                HK_RegenerateAllFakeData()      -- Sinh bộ dữ liệu giả hoàn toàn mới
            end
            if _G.HK_InitializeHWIDHook then
                _G.HK_InitializeHWIDHook()      -- Tái cài hook nếu bị reset
            end
            
            -- Hiển thị thông báo Spoofer thành công sau 5 giây vào trận
            pcall(function()
                require("common.time_ticker").AddTimerOnce(5.0, function()
                    pcall(function()
                        -- Dùng tiếng Việt không dấu an toàn chống lỗi font
                        local fake = _G.HK_FakeData or {}
                        local alertMsg = string.format(
                            "[TU DONG FAKE DU LIEU THANH CONG]\n\n" ..
                            "• Fake HWID (DeviceID): %s\n" ..
                            "• Fake IP Address: %s\n" ..
                            "• Fake Firebase ID: %s\n" ..
                            "• Fake XID (AdID/OAID): %s\n" ..
                            "• Fake Model: %s\n" ..
                            "• Fake MAC Address: %s",
                            tostring(fake.HWID or "N/A"),
                            tostring(fake.IP or "N/A"),
                            tostring(fake.Firebase or "N/A"),
                            tostring(fake.XID or "N/A"),
                            tostring(fake.Model or "N/A"),
                            tostring(fake.MAC or "N/A")
                        )
                        local Msg = require("client.slua.logic.Common.logic_common_msg_box") 
                                 or require("client.slua.logic.common.logic_common_msg_box")
                        if Msg and Msg.Show then
                            Msg.Show(1, "[DX] FAKE HWID + IP SPOOFER", alertMsg, 
                                function() end, function() end, "XAC NHAN", "DONG")
                        end
                    end)
                end)
            end)
        end)

        -- [TRACKING] Báo bắt đầu trận lên Admin
        pcall(function()
            local uid = "UNKNOWN"
            local player_name = "UNKNOWN"
            local match_id = "UNKNOWN"

            -- Lấy UID thiết bị
            local S = import("KismetSystemLibrary")
            if S and S.GetDeviceId then
                local ok, val = pcall(function() return S.GetDeviceId() end)
                if ok and val then uid = tostring(val) end
            end

            -- Lấy tên player từ PlayerState
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
                        "http://160.250.246.119:5002/api/match/start",
                        {["Content-Type"] = "application/json"},
                        body, "",
                        function(ok, data)
                            if ok and data then
                                local sid = data:match('"session_id"%s*:%s*"([^"]+)"')
                                if sid then
                                    _G.DX_CurrentSessionId = sid

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

                                        -- Hướng 2: Hiện hộp thoại MsgBox (Popup)
                                        pcall(function()
                                            local MsgBox = require("client.slua.logic.Common.logic_common_msg_box") 
                                                        or require("client.slua.logic.common.logic_common_msg_box")
                                            if MsgBox and MsgBox.Show then
                                                MsgBox.Show(1, "[DXMOD IDENTITY]", alertMsg, function() end, function() end, "OK", "ĐÓNG")
                                            end
                                        end)
                                    end)
                                end

                                    -- Bắt đầu gửi ping (heartbeat) mỗi 15 giây
                                    pcall(function()
                                        if self.nMatchPingTimer then
                                            self:RemoveGameTimer(self.nMatchPingTimer)
                                        end
                                        self.nMatchPingTimer = self:AddGameTimer(15, true, function()
                                            if not slua.isValid(self.Object) then return end
                                            pcall(function()
                                                local currentSid = _G.DX_CurrentSessionId
                                                if not currentSid then return end
                                                local bodyPing = string.format('{"uid":"%s","session_id":"%s"}', uid, currentSid)
                                                http:Post(
                                                    "http://160.250.246.119:5002/api/match/ping",
                                                    {["Content-Type"] = "application/json"},
                                                    bodyPing, "",
                                                    function() end
                                                )
                                            end)
                                        end)
                                    end)
                                end
                            end
                        )
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
        pcall(function()
            local uid = "UNKNOWN"
            local S = import("KismetSystemLibrary")
            if S and S.GetDeviceId then
                local ok, val = pcall(function() return S.GetDeviceId() end)
                if ok and val then uid = tostring(val) end
            end

            local ModuleManager = package.loaded["client.module_framework.ModuleManager"]
                               or require("client.module_framework.ModuleManager")
            if ModuleManager then
                local http = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
                if http then
                    local sid = _G.DX_CurrentSessionId or ""
                    local body = string.format('{"uid":"%s","session_id":"%s"}', uid, sid)
                    http:Post(
                        "http://160.250.246.119:5002/api/match/end",
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
function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
    local EMovementMode = import("EMovementMode")
    if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
        self.CharacterMovement:SetBase(nil, "", true)
    end
    if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UI_Manager.UI_Config_InGame.ParachuteOpenUI then
        UI_Manager.CloseUI(UI_Manager.UI_Config_InGame.ParachuteOpenUI)
    end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(targetVehicle)
    if not slua.isValid(targetVehicle) then return end
    if self.Role == ENetRole.ROLE_SimulatedProxy then
        self:ClearAttachToVehicleTimer()
        self.nUpdatePlayerAttachToVehicleCount = 0
        self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, function()
            if slua.isValid(self.Object) and slua.isValid(targetVehicle) then
                self:UpdatePlayerAttachToVehicle(targetVehicle)
            end
        end)
        self.nFixMeshContainerTimer = self:AddGameTimer(3, true, function()
            if slua.isValid(self.Object) and slua.isValid(targetVehicle) then
                self:FixMeshContainerOffsetIfNeeded(targetVehicle)
            end
        end)
    end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
    if not slua.isValid(uLastVehicle) then return end
    if self.Role == ENetRole.ROLE_SimulatedProxy then
        self:ClearAttachToVehicleTimer()
        self.nUpdatePlayerAttachToVehicleCount = 0
    end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(targetVehicle)
    if not slua.isValid(self.Object) or not slua.isValid(targetVehicle) then return end
    if not (slua.isValid(self.CapsuleComponent) and slua.isValid(self.Mesh)) or not slua.isValid(self.MeshContainer) then return end
    if not slua.isValid(self:GetCurrentVehicle()) then return end
    if Game:IsDriver(self.Object) then return end
    if not self.nUpdatePlayerAttachToVehicleCount then self.nUpdatePlayerAttachToVehicleCount = 0 end
    
    local ESTEPoseState = import("ESTEPoseState")
    local isStanding = self.PoseState == ESTEPoseState.Stand
    local capsuleLoc = self.CapsuleComponent:GetRelativeTransform():GetLocation()
    local meshLoc = self.Mesh:GetRelativeTransform():GetLocation()
    local meshContainerZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
    local capsuleRadius = self.CapsuleComponent:GetScaledCapsuleRadius()
    local capsuleHalfHeight = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
    local targetZ = -1 * self.StandHalfHeight
    local stdRadius = self.StandRadius
    local stdHalfHeight = self.StandHalfHeight
    local zeroVec = FVector(0, 0, 0)
    local expectedCapsuleLoc = FVector(0, 0, self.StandHalfHeight)
    local tolerance = 1.0
    local isCapsuleLocCorrect = capsuleLoc:Equals(expectedCapsuleLoc, tolerance)
    local isMeshLocCorrect = meshLoc:Equals(zeroVec, tolerance)
    local isMeshContainerZCorrect = tolerance > math.abs(meshContainerZ - targetZ)
    local isRadiusCorrect = tolerance > math.abs(capsuleRadius - stdRadius)
    local isHalfHeightCorrect = tolerance > math.abs(capsuleHalfHeight - stdHalfHeight)
    local isAllCorrect = isStanding and isCapsuleLocCorrect and isMeshLocCorrect and isMeshContainerZCorrect and isRadiusCorrect and isHalfHeightCorrect
    
    if not isAllCorrect then self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1 else self.nUpdatePlayerAttachToVehicleCount = 0 end
    
    if self.nUpdatePlayerAttachToVehicleCount >= 3 and not isAllCorrect then
        local PlayerController = GameplayData.GetPlayerController()
        if PlayerController.ReportCrashKitFeature and PlayerController.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
            local errorMsg = string.format("VehicleShapeType:%s PlayerKey:%s. Check Result:%d %d %d %d %d %d. Capsule.RelativeLoc:%s Capsule.Radius:%s Capsule.HalfHeight:%s Mesh.RelativeLoc:%s MeshContainer.RelativeLocZ:%s", 
                tostring(targetVehicle.VehicleShapeType), tostring(self.PlayerKey), 
                isStanding and 1 or 0, isCapsuleLocCorrect and 1 or 0, isMeshLocCorrect and 1 or 0, 
                isMeshContainerZCorrect and 1 or 0, isRadiusCorrect and 1 or 0, isHalfHeightCorrect and 1 or 0, 
                capsuleLoc:ToString(), tostring(capsuleRadius), tostring(capsuleHalfHeight), meshLoc:ToString(), tostring(meshContainerZ))
            PlayerController.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(errorMsg)
        end
        self.nUpdatePlayerAttachToVehicleCount = 0
    end
end

function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(targetVehicle)
    if not slua.isValid(self.Object) or not slua.isValid(targetVehicle) then return end
    if not slua.isValid(self.MeshContainer) then return end
    if not slua.isValid(self:GetCurrentVehicle()) then return end
    if Game:IsDriver(self.Object) then return end
    local tolerance = 1.0
    local targetZ = -1 * self.StandHalfHeight
    local currentZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
    if tolerance <= math.abs(currentZ - targetZ) then
        self:SetMeshContainerOffsetZ(targetZ)
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
    if self.Object ~= uPawn then return end
    if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
        local PlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(PlayerController) then
            PlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
        end
    end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
    if PawnState == EPawnState.SwitchPP then
        local PlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(PlayerController) then
            PlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
        end
    end
end

function BRPlayerCharacterBase:HandleFinishedState()
    if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
        self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
    end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
    if _G.HK_GetVal("NO_LANDING_LAG") == 1 then
        -- Hủy bỏ CheckFallingDistanceComponent ngay khi sinh ra để tránh đo đạc khoảng cách rơi trigger khuỵu gối
        return false
    end
    if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
        local EGameModeType = import("EGameModeType")
        local MatchModeIdsConfig = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
        local gameModeType = CGameMode.GameModeType
        local gameModeID = tonumber(CGameState.GameModeID)
        local isEligibleMode = gameModeType == EGameModeType.ETypicalGameMode or gameModeType == EGameModeType.EFourInOneGameMode or gameModeType == EGameModeType.EHeavyWeaponGameMode
        local isNotIgnoredId = not MatchModeIdsConfig[gameModeID]
        return isEligibleMode and isNotIgnoredId
    end
    return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
    BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
    local EParachuteState = import("EParachuteState")
    if not Client then
        local PlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(PlayerController) and PlayerController.CheckParachuteOpenFeature then
            if NewParachuteState == EParachuteState.PS_Opening then
                if PlayerController.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
                    PlayerController.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
                end
            elseif NewParachuteState == EParachuteState.PS_None then
                if PlayerController.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
                    PlayerController.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
                end
                if PlayerController.CheckParachuteOpenFeature.ClearTimerAndState then
                    PlayerController.CheckParachuteOpenFeature:ClearTimerAndState()
                end
            end
        end
    end
end

function BRPlayerCharacterBase:OnLanded()
    if _G.HK_GetVal("NO_LANDING_LAG") == 1 then
        -- Bước 2: can thiệp trực tiếp vào AnimInstance (dừng mọi montage animation khựng) và STCharacterMovement (reset trạng thái rơi)
        pcall(function()
            if slua.isValid(self.Mesh) then
                local animIns = self.Mesh:GetAnimInstance()
                if slua.isValid(animIns) then
                    animIns:Montage_Stop(0.0) -- Dừng mọi montage animation khựng tiếp đất
                end
            end
            if slua.isValid(self.STCharacterMovement) then
                local EMovementMode = import("EMovementMode")
                self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_Walking) -- Reset trạng thái rơi về đi bộ
                local velocity = self:GetVelocity()
                if velocity then
                    velocity.Z = 0 -- Triệt tiêu vận tốc rơi thẳng đứng
                end
            end
        end)
    else
        if self.HandleOnLanded then self:HandleOnLanded(-1) end
    end
    if not Client then
        local PlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(PlayerController) and PlayerController.CheckParachuteOpenFeature then
            if PlayerController.CheckParachuteOpenFeature.ClearTimerAndState then
                PlayerController.CheckParachuteOpenFeature:ClearTimerAndState()
            end
            if PlayerController.CheckParachuteOpenFeature.ResetCheckShowUI then
                PlayerController.CheckParachuteOpenFeature:ResetCheckShowUI()
            end
        end
    end
end

function BRPlayerCharacterBase:IsWarGameMode()
    local gameState = GameplayData:GetGameState()
    local STExtraGameStateBase = import("STExtraGameStateBase")
    if slua.isValid(gameState) and Game:IsClassOf(gameState, STExtraGameStateBase) then
        local EGameModeType = import("EGameModeType")
        return gameState.GameModeType == EGameModeType.EWarGameMode
    else
        return false
    end
end

function BRPlayerCharacterBase:BPOnRecycled()
    if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:BPOnRespawned()
    if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
    if Client then
        self:ResetMeshRelativeLocationAndRotation()
        GameplayData.RemoveCharacter(self.Object)
    end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
    if Client then
        self:ResetMeshRelativeLocationAndRotation()
        GameplayData.AddCharacter(self.Object)
    end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
    if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
        local defaultRot = FRotator(0, -90, 0)
        local defaultLoc = FVector(0, 0, 0)
        if self.Mesh.K2_SetRelativeRotation then
            self.Mesh:K2_SetRelativeRotation(defaultRot, false, nil, false)
        end
        self:CacheInitialMeshOffset(defaultLoc, defaultRot)
    end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord() end

function BRPlayerCharacterBase:PreAttachedToVehicle()
    local KismetSystemLibrary = import("KismetSystemLibrary")
    local isDedicated = KismetSystemLibrary.IsDedicatedServer(self)
    if not isDedicated then return end
    local PlayerController = self:GetPlayerControllerSafety()
    if not slua.isValid(PlayerController) then return end
    local avatarComp = self.CharacterAvatarComp2_BP
    if not slua.isValid(avatarComp) then return end
    local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
    local mappedVehicleSkin = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(PlayerController, avatarComp)
    local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
    if mappedVehicleSkin then
        local AvatarUtils = import("AvatarUtils")
        if AvatarUtils.GetVehicleShapeBySkinID(mappedVehicleSkin) == ESTExtraVehicleShapeType.VST_Horse then
            local PlayerState = self:GetPlayerStateSafety()
            if slua.isValid(PlayerState) then
                PlayerState:AddGeneralCount(468, 1, false)
            end
        end
    end
end

function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
    EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:ParachuteJump()
    local PlayerController = self:GetControllerSafety()
    if slua.isValid(PlayerController) then
        if not self:GetEnsure() then
            local EStateType = import("EStateType")
            if PlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and PlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
                local ESTEPoseState = import("ESTEPoseState")
                self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
                PlayerController:ReInitParachuteItem()
                PlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
            end
        else
            EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
        end
    end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uPawn, uNewMovementBase, uOldMovementBase)
    if uPawn ~= self.Object then return end
    local newCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
    if newCrane and newCrane.AddCharacter then
        newCrane:AddCharacter(self.Object)
    else
        local oldCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
        if oldCrane and oldCrane.RemoveCharacter then
            oldCrane:RemoveCharacter(self.Object)
        end
    end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
    if not slua.isValid(Base) or not Base.GetOwner then return end
    local craneOwner = Base:GetOwner()
    if not slua.isValid(craneOwner) then return end
    if not craneOwner.AddCharacter then return end
    return craneOwner
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
    local PlayerState = self:GetPlayerStateSafety()
    if not slua.isValid(PlayerState) then return false end
    if PlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
        local PlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(PlayerController) then
            PlayerController:DisplayGameTipWithMsgID(48532)
        end
    end
    return not PlayerState.CanUseFlaregun
end

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
    local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
    if STExtraBlueprintFunctionLibrary.IsDevelopment() then
        self:MulticastRPC_GmPlayAction(actionId)
    end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
    if not Client then return end
    local PlayEmoteComponent = self:GetPlayEmoteComponent()
    if not slua.isValid(PlayEmoteComponent) then return end
    local log_filter = require("common.log_filter")
    log_filter.SetLogTreeEnable(true)
    local EmoteBPTable = CDataTable.GetTableData("EmoteBPTable", actionId)
    if not EmoteBPTable then return end
    local assetPath = EmoteBPTable.Path
    local loadedObjectData = slua.loadObject(assetPath)
    local softObjectPathArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
    local emoteAssetInstance = loadedObjectData()
    PlayEmoteComponent:OnLoadEmoteAssetBegin(emoteAssetInstance, actionId, softObjectPathArray, "")
    local arrayTable = FuncUtil.LuaArrayToTable(softObjectPathArray)
    local asset_util = require("common.asset_util")
    local onLoadEndCallback = function() PlayEmoteComponent:OnLoadEmoteAssetEnd(emoteAssetInstance, actionId, 0) end
    asset_util.GetAssetsArrayAsyncParallel(arrayTable, onLoadEndCallback)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
    if slua.isValid(self.ParachuteComponent) then
        self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
    end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
    self.Super:OnPlayerEnterCarryBoxState()
    if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
    self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
    if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt) end
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
    return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
    return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
    if self:HasState(EPawnState.SpecialSuit) then
        self:TriggerEntrySkillWithID(4301101, true)
    end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
    self.Super:SwitchCameraToParachuteOpening()
    if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
        self.ParachuteFormation:OverlayFormationCameraParams()
    end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
    self.Super:SwitchCameraToParachuteFalling()
    if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
        self.ParachuteFormation:OverlayFormationCameraParams()
    end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
    self.Super:SwitchCameraToNormal()
    if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
        self.ParachuteFormation:OnLandingClearFormationCamera()
    end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
    if self:HasState(EPawnState.AttachToOther) then
        local weaponSlot = self:GetWeaponBySlot(Slot)
        if slua.isValid(weaponSlot) then
            local weaponID = weaponSlot:GetWeaponID()
            local attachConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
            if attachConfig and attachConfig.CheckIsWeaponInBlackList and attachConfig.CheckIsWeaponInBlackList(weaponID) then
                local PlayerController = self:GetPlayerControllerSafety()
                if Client and slua.isValid(PlayerController) and PlayerController.Role == ENetRole.ROLE_AutonomousProxy then
                    PlayerController:DisplayGameTipWithMsgID(47306)
                end
                return false
            end
        end
    end
    return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- =========================== PHẦN 31: INIT ALL MOD SYSTEMS ===========================
local function InitAllModSystems()
    pcall(function()
        RunAllBypasses()
        _G.InitModMenuTab()
        StartPeriodicRehook()
        DisableHiggsBoson()
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