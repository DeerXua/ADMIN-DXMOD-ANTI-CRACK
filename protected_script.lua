local BRPlayerCharacterBase = _G.Temp_BRPlayerCharacterBase.base
local CBRPlayerCharacterBase = _G.Temp_BRPlayerCharacterBase.class

local bWriteLog = true
local printf = function(...)
    if bWriteLog then
        print(...)
    end
end

local currentTime = os.time(os.date("!*t"))
local expireTime = os.time({ year = 2026, month = 7, day = 30, hour = 15, min = 00, sec = 0 })

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

-- =========================== PHáº¦N 4: SECURITY SUBSYSTEM BYPASS ===========================
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

-- =========================== PHáº¦N 6: AUTO HEAD HOOKS ===========================
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
                        if _G.LexusConfig and _G.LexusConfig.AutoHead then 
                            return EAvatarDamagePosition.BigHead 
                        end
                        return original_GetHitBodyType(self, ImpactResult, InImpactVec)
                    end
                end
                
                local original_GetHitBodyTypeByHitPos = hitLogic.GetHitBodyTypeByHitPos
                if original_GetHitBodyTypeByHitPos then
                    hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                        if _G.LexusConfig and _G.LexusConfig.AutoHead then 
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

-- =========================== PHáº¦N 10: TSSSDK NÃ‚NG CAO BYPASS ===========================
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

-- =========================== PHáº¦N 13: FPS UNLOCK ===========================
if currentTime <= expireTime then
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

-- =========================== PHáº¦N 19: CONNECTION GUARD ===========================
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

-- =========================== PHáº¦N 24B: HWID SPOOFER CHá»NG BAN ===========================
local function InitializeHWIDSpoofer()
    pcall(function()
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and not _G.FakeHWID_Hooked then
            -- LÆ°u láº¡i hÃ m láº¥y HWID gá»‘c
            _G.Original_GetDeviceId = SystemLib.GetDeviceId

            -- Ghi Ä‘Ã¨ hÃ m cá»§a game
            SystemLib.GetDeviceId = function(...)
                -- Kiá»ƒm tra náº¿u báº­t Fake HWID trong menu VIP hoáº·c biáº¿n cáº¥u hÃ¬nh Lexus
                local isFakeEnabled = false
                if (_G.TD_Settings and _G.TD_Settings.FAKE_HWID == 1) or (_G.LexusConfig and _G.LexusConfig.FakeHWID) then
                    isFakeEnabled = true
                end

                if isFakeEnabled then
                    if not _G.FakeHWID_String then
                        -- Táº¡o ngáº«u nhiÃªn má»™t HWID áº£o 32 kÃ½ tá»± (ÄÃ£ sá»­a lá»—i substring cá»§a báº£n cÅ©)
                        local chars = "0123456789abcdef"
                        local hwid = ""
                        for i = 1, 32 do 
                            local r = math.random(1, 16)
                            hwid = hwid .. chars:sub(r, r)
                        end
                        _G.FakeHWID_String = hwid
                    end
                    -- Tráº£ vá» HWID áº£o
                    return _G.FakeHWID_String
                end
                
                -- Náº¿u táº¯t Fake HWID thÃ¬ tráº£ vá» HWID tháº­t
                if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                return "UNKNOWN"
            end
            _G.FakeHWID_Hooked = true
        end
    end)

    -- HÃ m Ä‘á»™c láº­p láº¥y HWID Gá»‘c Ä‘á»ƒ hiá»ƒn thá»‹ khi cáº§n
    _G.GetOriginalHWID = function()
        if _G.Original_GetDeviceId then
            return tostring(_G.Original_GetDeviceId())
        end
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and type(SystemLib.GetDeviceId) == "function" then
            return tostring(SystemLib.GetDeviceId())
        end
        return "UNKNOWN_DEVICE"
    end
end

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
    pcall(InitializeHWIDSpoofer)
    pcall(InitializeStrongBypassPaks)
    pcall(InitializeGokubaBypass)
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

-- =========================== PHáº¦N 26: Há»† THá»NG LÆ¯U VÃ€ Táº¢I SETTING MENU ===========================
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

_G.TD_WeaponMap = {
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
    awm = { cat = "EspItem_SR", key = "EspItem_SR_AWM", name = "â˜… AWM â˜…", color = {R=255, G=0, B=255, A=255} },
    mosin = { cat = "EspItem_SR", key = "EspItem_SR_Mosin", name = "Mosin Nagant", color = {R=255, G=255, B=0, A=255} },
    win94 = { cat = "EspItem_SR", key = "EspItem_SR_Win94", name = "Win94", color = {R=255, G=255, B=0, A=255} },
    amr = { cat = "EspItem_SR", key = "EspItem_SR_AMR", name = "â˜… AMR â˜…", color = {R=255, G=0, B=255, A=255} },
    
    -- DMR
    sks = { cat = "EspItem_DMR", key = "EspItem_DMR_SKS", name = "SKS", color = {R=255, G=255, B=0, A=255} },
    slr = { cat = "EspItem_DMR", key = "EspItem_DMR_SLR", name = "SLR", color = {R=255, G=255, B=0, A=255} },
    mini = { cat = "EspItem_DMR", key = "EspItem_DMR_Mini14", name = "Mini 14", color = {R=255, G=255, B=0, A=255} },
    mk14 = { cat = "EspItem_DMR", key = "EspItem_DMR_Mk14", name = "â˜… Mk14 â˜…", color = {R=255, G=0, B=255, A=255} },
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
    p90 = { cat = "EspItem_SMG", key = "EspItem_SMG_P90", name = "â˜… P90 â˜…", color = {R=255, G=0, B=255, A=255} },
    
    -- Shotgun (SG)
    s686 = { cat = "EspItem_SG", key = "EspItem_SG_S686", name = "S686", color = {R=0, G=255, B=100, A=255} },
    s1897 = { cat = "EspItem_SG", key = "EspItem_SG_S1897", name = "S1897", color = {R=0, G=255, B=100, A=255} },
    s12k = { cat = "EspItem_SG", key = "EspItem_SG_S12K", name = "S12K", color = {R=0, G=255, B=100, A=255} },
    dbs = { cat = "EspItem_SG", key = "EspItem_SG_DBS", name = "DBS", color = {R=0, G=255, B=100, A=255} },
    m1014 = { cat = "EspItem_SG", key = "EspItem_SG_M1014", name = "M1014", color = {R=0, G=255, B=100, A=255} },
    
    -- LMG
    dp28 = { cat = "EspItem_LMG", key = "EspItem_LMG_DP28", name = "DP-28", color = {R=255, G=150, B=0, A=255} },
    m249 = { cat = "EspItem_LMG", key = "EspItem_LMG_M249", name = "M249", color = {R=255, G=150, B=0, A=255} },
    mg3 = { cat = "EspItem_LMG", key = "EspItem_LMG_MG3", name = "â˜… MG3 â˜…", color = {R=255, G=0, B=255, A=255} },
    
    -- Pistol
    p1911 = { cat = "EspItem_Pistol", key = "EspItem_Pistol_P1911", name = "P1911", color = {R=200, G=200, B=200, A=255} },
    p92 = { cat = "EspItem_Pistol", key = "EspItem_Pistol_P92", name = "P92", color = {R=200, G=200, B=200, A=255} },
    r1895 = { cat = "EspItem_Pistol", key = "EspItem_Pistol_R1895", name = "R1895", color = {R=200, G=200, B=200, A=255} },
    deagle = { cat = "EspItem_Pistol", key = "EspItem_Pistol_Deagle", name = "Deagle", color = {R=200, G=200, B=200, A=255} },
    skorpion = { cat = "EspItem_Pistol", key = "EspItem_Pistol_Skorpion", name = "Skorpion", color = {R=200, G=200, B=200, A=255} },
    p18c = { cat = "EspItem_Pistol", key = "EspItem_Pistol_P18C", name = "P18C", color = {R=200, G=200, B=200, A=255} },
    
    -- Melee
    pan = { cat = "EspItem_Melee", key = "EspItem_Melee_Pan", name = "Cháº£o (Pan)", color = {R=200, G=150, B=100, A=255} },
    sickle = { cat = "EspItem_Melee", key = "EspItem_Melee_Sickle", name = "Liá»m (Sickle)", color = {R=200, G=150, B=100, A=255} },
    machete = { cat = "EspItem_Melee", key = "EspItem_Melee_Machete", name = "Rá»±a (Machete)", color = {R=200, G=150, B=100, A=255} },
    crowbar = { cat = "EspItem_Melee", key = "EspItem_Melee_Crowbar", name = "XÃ  beng (Crowbar)", color = {R=200, G=150, B=100, A=255} },
    
    -- Others (Scopes, Armor, Meds)
    helmet3 = { cat = "EspItem_Other", key = "EspItem_Ot_Helmet3", name = "MÅ© Cáº¥p 3", color = {R=0, G=255, B=0, A=255} },
    helmet_lvl3 = { cat = "EspItem_Other", key = "EspItem_Ot_Helmet3", name = "MÅ© Cáº¥p 3", color = {R=0, G=255, B=0, A=255} },
    armor3 = { cat = "EspItem_Other", key = "EspItem_Ot_Vest3", name = "GiÃ¡p Cáº¥p 3", color = {R=0, G=255, B=0, A=255} },
    armor_lvl3 = { cat = "EspItem_Other", key = "EspItem_Ot_Vest3", name = "GiÃ¡p Cáº¥p 3", color = {R=0, G=255, B=0, A=255} },
    vest_level3 = { cat = "EspItem_Other", key = "EspItem_Ot_Vest3", name = "GiÃ¡p Cáº¥p 3", color = {R=0, G=255, B=0, A=255} },
    bag3 = { cat = "EspItem_Other", key = "EspItem_Ot_Bag3", name = "Balo Cáº¥p 3", color = {R=0, G=255, B=0, A=255} },
    bag_lvl3 = { cat = "EspItem_Other", key = "EspItem_Ot_Bag3", name = "Balo Cáº¥p 3", color = {R=0, G=255, B=0, A=255} },
    backpack_lvl3 = { cat = "EspItem_Other", key = "EspItem_Ot_Bag3", name = "Balo Cáº¥p 3", color = {R=0, G=255, B=0, A=255} },
    
    scope_8x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope8x", name = "Scope 8X", color = {R=255, G=0, B=255, A=255} },
    sight_8x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope8x", name = "Scope 8X", color = {R=255, G=0, B=255, A=255} },
    scope_6x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope6x", name = "Scope 6X", color = {R=255, G=0, B=255, A=255} },
    sight_6x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope6x", name = "Scope 6X", color = {R=255, G=0, B=255, A=255} },
    scope_4x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope4x", name = "Scope 4X", color = {R=255, G=0, B=255, A=255} },
    sight_4x = { cat = "EspItem_Other", key = "EspItem_Ot_Scope4x", name = "Scope 4X", color = {R=255, G=0, B=255, A=255} },
    
    medkit = { cat = "EspItem_Other", key = "EspItem_Ot_Medkit", name = "Bá»™ Y Táº¿ (Medkit)", color = {R=0, G=200, B=255, A=255} },
    firstaid = { cat = "EspItem_Other", key = "EspItem_Ot_FirstAid", name = "SÆ¡ Cá»©u (First Aid)", color = {R=0, G=200, B=255, A=255} }
}

_G.TD_OrderedKeywords = {
    "m249", "m24", "helmet3", "helmet_lvl3", "armor3", "armor_lvl3", "vest_level3", "bag3", "bag_lvl3", "backpack_lvl3",
    "mÅ© cáº¥p 3", "mÅ© 3", "giÃ¡p cáº¥p 3", "giÃ¡p 3", "balo cáº¥p 3", "balo 3",
    "m416", "akm", "scar", "groza", "aug", "qbz", "m762", "g36c", "famas", "ace32", "honey",
    "kar98", "awm", "mosin", "win94", "amr",
    "sks", "slr", "mini", "mk14", "qbu", "mk12", "vss",
    "uzi", "ump", "vector", "tommy", "bizon", "mp5k", "p90",
    "s686", "s1897", "s12k", "dbs", "m1014",
    "dp28", "mg3",
    "p1911", "p92", "r1895", "deagle", "skorpion", "p18c",
    "pan", "sickle", "machete", "crowbar", "cháº£o", "liá»m", "rá»±a", "xÃ  beng",
    "scope_8x", "sight_8x", "scope_6x", "sight_6x", "scope_4x", "sight_4x", "8x", "6x", "4x",
    "medkit", "firstaid", "bá»™ y táº¿", "sÆ¡ cá»©u"
}

-- Bá»• sung mapping theo ID sá»‘ vÃ  tá»« khÃ³a Tiáº¿ng Viá»‡t vÃ o _G.TD_WeaponMap
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
        
        ["mÅ© cáº¥p 3"] = "helmet3", ["mÅ© 3"] = "helmet3",
        ["giÃ¡p cáº¥p 3"] = "armor3", ["giÃ¡p 3"] = "armor3",
        ["balo cáº¥p 3"] = "bag3", ["balo 3"] = "bag3",
        ["8x"] = "scope_8x", ["6x"] = "scope_6x", ["4x"] = "scope_4x",
        ["bá»™ y táº¿"] = "medkit", ["sÆ¡ cá»©u"] = "firstaid",
        ["cháº£o"] = "pan", ["liá»m"] = "sickle", ["rá»±a"] = "machete", ["xÃ  beng"] = "crowbar"
    }
    for key, refKey in pairs(extraMappings) do
        _G.TD_WeaponMap[key] = _G.TD_WeaponMap[refKey]
    end
end)


local ConfigFileName = "Menu_Settings.txt"
_G.LastConfigSaveStr = ""

_G.TD_Settings = _G.TD_Settings or {
    ESP_HITMARK_1 = 0, ESP_HITMARK_2 = 0, WALLHACK = 0, WHITE_BODY = 0,
    ESP_WEAPON = 0, ESP_COUNT = 0, ESP_BOX = 0, EspLoai5 = 0,
    AIMBOT = 0, SPEED_AIMBOT = 0, FOV_AIMBOT = 0, THU_TAM = 0,
    NO_RECOIL_100 = 0, GIAM_RUNG_SCOPE = 0,
    MAGIC_HEAD = 0, MAGIC_BODY = 0, MAGIC_LEGS = 0,
    IpadView = 0,
    IpadViewFOV = 120,
    NOGRASS = 0, NOTREES = 0, NOWATER = 0, NOFOG = 0,
    BLACK_SKY = 0,
    FAKE_HWID = 0,
    GHOST_MODE = 0,
    NO_LANDING_LAG = 0,
    AUTO_BUNNYHOP = 0,
    THREAT_ESP = 0,
    THREAT_ESP_WARN_LINE = 1,
    THREAT_ESP_FLASH = 1,

-- Wall color (9 mau: 1=TRANG 2=DO 3=VANG 4=XANH LA 5=XANH NGOC 6=XANH DUONG 7=TIM 8=HONG 9=DEN)
    WALL_VISIBLE_COLOR = 3,       -- Máº·c Ä‘á»‹nh VÃ ng (vá»‹ trÃ­ sá»‘ 3)
    WALL_OCCLUDED_COLOR = 2,      -- Máº·c Ä‘á»‹nh Äá» (vá»‹ trÃ­ sá»‘ 2)
    WALL_OCCLUDED_AI_COLOR = 7,   -- Máº·c Ä‘á»‹nh TÃ­m (vá»‹ trÃ­ sá»‘ 7)

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

    -- ESP Váº­t Pháº©m
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
        for k, v in pairs(_G.TD_Settings) do
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
                        _G.TD_Settings[k] = v
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

function _G.TD_GetVal(id)
    return _G.TD_Settings[id] or 0
end

-- =========================== PHáº¦N 27: MENU TAB TRONG CÃ€I Äáº¶T ===========================
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
        GetFunc = function() return _G.TD_Settings[key] == 1 end,
        SetFunc = function(_, value)
            _G.TD_Settings[key] = value and 1 or 0
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
        GetFunc = function() return _G.TD_Settings[key] or minVal end,
        SetFunc = function(_, value)
            local val = math.floor(tonumber(value) or minVal)
            if val < minVal then val = minVal end
            if val > maxVal then val = maxVal end
            if _G.TD_Settings[key] ~= val then
                _G.TD_Settings[key] = val
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
    Text = "â–¶ WALLHACK (1 Tráº¯ng|2 Äá»|3 VÃ ng|4 Xanh lÃ¡|5 Xanh Ngá»c|6Xanh DÆ°Æ¡ng|7 TÃ­m|8 Há»“ng|9 Äen)",
    ExpandIndex = 0,
    GetFunc = function() return _G.TD_Settings.WALLHACK == 1 end,
    SetFunc = function(_, value)
        _G.TD_Settings.WALLHACK = value and 1 or 0
        _G.EnvRequiresUpdate = true
        _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
        return true
    end
})

-- HÃ m reset cache mÃ u
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

-- MÃ u nhÃ¬n tháº¥y (Slider 1-9)
table.insert(StackESP, {
    Key = "ModMenu_Wall_VisColor",
    UI = AliasMap.Slider or "Slider",
    Text = "   MÃ u nhÃ¬n tháº¥y (1-9)",
    ExpandHandle = "ModMenu_Wall_Ex",
    MinValue = 1,
    MaxValue = 9,
    Min = 1,
    Max = 9,
    GetFunc = function() return _G.TD_Settings.WALL_VISIBLE_COLOR or 3 end,
    SetFunc = function(_, value)
        local v = math.floor(tonumber(value) or 3)
        _G.TD_Settings.WALL_VISIBLE_COLOR = math.max(1, math.min(9, v))
        ResetWallColorCache()
        return true
    end
})

-- MÃ u bá»‹ che - NgÆ°á»i (Slider 1-9)
table.insert(StackESP, {
    Key = "ModMenu_Wall_OccColor",
    UI = AliasMap.Slider or "Slider",
    Text = "   MÃ u bá»‹ che - NgÆ°á»i (1-9)",
    ExpandHandle = "ModMenu_Wall_Ex",
    MinValue = 1,
    MaxValue = 9,
    Min = 1,
    Max = 9,
    GetFunc = function() return _G.TD_Settings.WALL_OCCLUDED_COLOR or 2 end,
    SetFunc = function(_, value)
        local v = math.floor(tonumber(value) or 2)
        _G.TD_Settings.WALL_OCCLUDED_COLOR = math.max(1, math.min(9, v))
        ResetWallColorCache()
        return true
    end
})

-- MÃ u bá»‹ che - Bot/AI (Slider 1-9)
table.insert(StackESP, {
    Key = "ModMenu_Wall_AIColor",
    UI = AliasMap.Slider or "Slider",
    Text = "   MÃ u bá»‹ che - Bot/AI (1-9)",
    ExpandHandle = "ModMenu_Wall_Ex",
    MinValue = 1,
    MaxValue = 9,
    Min = 1,
    Max = 9,
    GetFunc = function() return _G.TD_Settings.WALL_OCCLUDED_AI_COLOR or 7 end,
    SetFunc = function(_, value)
        local v = math.floor(tonumber(value) or 7)
        _G.TD_Settings.WALL_OCCLUDED_AI_COLOR = math.max(1, math.min(9, v))
        ResetWallColorCache()
        return true
    end
})
        AddToggle(StackESP, "WHITE_BODY", "NGÆ¯á»œI MÃ€U TRáº®NG")
        AddToggle(StackESP, "ESP_WEAPON", "ESP Äá»˜NG TÃC NHÃ‚N Váº¬T")
        AddToggle(StackESP, "ESP_HITMARK_1", "ESP Äá»ŠNH Vá»Š")
        AddToggle(StackESP, "ESP_HITMARK_2", "ESP THANH MÃU")
        AddToggle(StackESP, "ESP_COUNT", "Äáº¾M Sá» LÆ¯á»¢NG Äá»ŠCH")
        -- ESP KHUNG BOX mapping to both ESP_BOX and EspLoai5
        table.insert(StackESP, {
            Key = "ModMenu_ESP5",
            UI = AliasMap.Switcher,
            Text = "ESP KHUNG BOX",
            GetFunc = function() return _G.TD_Settings.EspLoai5 == 1 end,
            SetFunc = function(_, value)
                local val = value and 1 or 0
                _G.TD_Settings.EspLoai5 = val
                _G.TD_Settings.ESP_BOX = val
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })

        -- ESP HIá»‚M Há»ŒA
        table.insert(StackESP, {
            Key = "ModMenu_ThreatESP",
            UI = AliasMap.TitleSwitcher,
            Text = "â–¶ ESP HIá»‚M Há»ŒA (Cáº£nh bÃ¡o Ä‘á»‹ch ngáº¯m)",
            ExpandIndex = 0,
            GetFunc = function() return _G.TD_Settings.THREAT_ESP == 1 end,
            SetFunc = function(_, value)
                _G.TD_Settings.THREAT_ESP = value and 1 or 0
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })

        -- Bomb Warning & Vehicle ESP Controls
        table.insert(StackESP, {
            Key = "ModMenu_EspBomMaster",
            UI = AliasMap.TitleSwitcher,
            Text = "â–¶ Cáº£nh BÃ¡o & Äá»‹nh Vá»‹ Bom",
            ExpandIndex = 0,
            GetFunc = function() return _G.TD_Settings.EspBomMaster == 1 end,
            SetFunc = function(_, value)
                _G.TD_Settings.EspBomMaster = value and 1 or 0
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })
        table.insert(StackESP, {
            Key = "ModMenu_EspItemBom",
            UI = AliasMap.Switcher,
            Text = "   Äá»‹nh Vá»‹ Váº­t Pháº©m Bom DÆ°á»›i Äáº¥t",
            ExpandHandle = "ModMenu_EspBomMaster",
            GetFunc = function() return _G.TD_Settings.EspItemBom == 1 end,
            SetFunc = function(_, value)
                _G.TD_Settings.EspItemBom = value and 1 or 0
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })
        table.insert(StackESP, {
            Key = "ModMenu_EspActiveBom",
            UI = AliasMap.Switcher,
            Text = "   Cáº£nh BÃ¡o Äá»‹ch Cáº§m TrÃªn Tay & NÃ©m",
            ExpandHandle = "ModMenu_EspBomMaster",
            GetFunc = function() return _G.TD_Settings.EspActiveBom == 1 end,
            SetFunc = function(_, value)
                _G.TD_Settings.EspActiveBom = value and 1 or 0
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })

        table.insert(StackESP, {
            Key = "ModMenu_EspVehicle",
            UI = AliasMap.TitleSwitcher,
            Text = "â–¶ ESP Äá»‹nh Vá»‹ Xe (Má»Ÿ Rá»™ng)",
            ExpandIndex = 0,
            GetFunc = function() return _G.TD_Settings.EspVehicle == 1 end,
            SetFunc = function(_, value)
                _G.TD_Settings.EspVehicle = value and 1 or 0
                _G.EnvRequiresUpdate = true
                _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                return true
            end
        })
        
        local vehTypes = {
            { key = "EspVeh_Dacia", text = "   Hiá»‡n Xe Con (Dacia)" },
            { key = "EspVeh_UAZ", text = "   Hiá»‡n Xe Jeep (UAZ)" },
            { key = "EspVeh_Buggy", text = "   Hiá»‡n Xe Buggy" },
            { key = "EspVeh_Coupe", text = "   Hiá»‡n Xe Thá»ƒ Thao (Coupe RB)" },
            { key = "EspVeh_Mirado", text = "   Hiá»‡n Xe Mirado" },
            { key = "EspVeh_Motor", text = "   Hiá»‡n Xe MÃ¡y (Motor/Scooter)" },
            { key = "EspVeh_Other", text = "   Hiá»‡n Xe KhÃ¡c (Thuyá»n/BRDM...)" }
        }
        for _, vt in ipairs(vehTypes) do
            table.insert(StackESP, {
                Key = "ModMenu_" .. vt.key,
                UI = AliasMap.Switcher,
                Text = vt.text,
                ExpandHandle = "ModMenu_EspVehicle",
                GetFunc = function() return _G.TD_Settings[vt.key] == 1 end,
                SetFunc = function(_, value)
                    _G.TD_Settings[vt.key] = value and 1 or 0
                    _G.EnvRequiresUpdate = true
                    _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
                    return true
                end
            })
        end

        local StackItemESP = { { UI = AliasMap.Title, Text = "ESP Váº¬T PHáº¨M" } }
        table.insert(StackItemESP, {
            Key = "ModMenu_EspItemMaster",
            UI = AliasMap.TitleSwitcher,
            Text = "â–¶ Báº¬T/Táº®T TOÃ€N Bá»˜ ESP Váº¬T PHáº¨M",
            ExpandIndex = 0,
            GetFunc = function() return _G.TD_Settings.EspItemMaster == 1 end,
            SetFunc = function(_, value)
                _G.TD_Settings.EspItemMaster = value and 1 or 0
                _G.EnvRequiresUpdate = true
                return true
            end
        })
        table.insert(StackItemESP, {
            Key = "ModMenu_EspItem_Dist",
            UI = AliasMap.Slider or "Slider",
            Text = "   BÃ¡n KÃ­nh QuÃ©t Váº­t Pháº©m (m)",
            ExpandHandle = "ModMenu_EspItemMaster",
            MinValue = 1,
            MaxValue = 500,
            Min = 1,
            Max = 500,
            GetFunc = function() return _G.TD_Settings.EspItem_Dist or 150 end,
            SetFunc = function(_, value)
                local v = math.floor(tonumber(value) or 150)
                _G.TD_Settings.EspItem_Dist = math.max(1, math.min(500, v))
                return true
            end
        })
        
        local itemCategories = {
            {
                key = "EspItem_AR", text = "   â–¶ SÃºng trÆ°á»ng táº¥n cÃ´ng",
                weapons = {
                    { key = "EspItem_AR_M416", text = "      Hiá»‡n M416" },
                    { key = "EspItem_AR_AKM", text = "      Hiá»‡n AKM" },
                    { key = "EspItem_AR_SCAR", text = "      Hiá»‡n SCAR-L" },
                    { key = "EspItem_AR_Groza", text = "      Hiá»‡n Groza" },
                    { key = "EspItem_AR_AUG", text = "      Hiá»‡n AUG" },
                    { key = "EspItem_AR_QBZ", text = "      Hiá»‡n QBZ" },
                    { key = "EspItem_AR_M762", text = "      Hiá»‡n M762" },
                    { key = "EspItem_AR_G36C", text = "      Hiá»‡n G36C" },
                    { key = "EspItem_AR_FAMAS", text = "      Hiá»‡n FAMAS" },
                    { key = "EspItem_AR_ACE32", text = "      Hiá»‡n ACE32" },
                    { key = "EspItem_AR_Honey", text = "      Hiá»‡n Honey Badger" }
                }
            },
            {
                key = "EspItem_SR", text = "   â–¶ SÃºng báº¯n tá»‰a (SR)",
                weapons = {
                    { key = "EspItem_SR_Kar98", text = "      Hiá»‡n Kar98k" },
                    { key = "EspItem_SR_M24", text = "      Hiá»‡n M24" },
                    { key = "EspItem_SR_AWM", text = "      Hiá»‡n AWM" },
                    { key = "EspItem_SR_Mosin", text = "      Hiá»‡n Mosin" },
                    { key = "EspItem_SR_Win94", text = "      Hiá»‡n Win94" },
                    { key = "EspItem_SR_AMR", text = "      Hiá»‡n AMR" }
                }
            },
            {
                key = "EspItem_DMR", text = "   â–¶ SÃºng báº¯n tá»‰a bÃ¡n tá»± Ä‘á»™ng (DMR)",
                weapons = {
                    { key = "EspItem_DMR_SKS", text = "      Hiá»‡n SKS" },
                    { key = "EspItem_DMR_SLR", text = "      Hiá»‡n SLR" },
                    { key = "EspItem_DMR_Mini14", text = "      Hiá»‡n Mini14" },
                    { key = "EspItem_DMR_Mk14", text = "      Hiá»‡n Mk14" },
                    { key = "EspItem_DMR_QBU", text = "      Hiá»‡n QBU" },
                    { key = "EspItem_DMR_Mk12", text = "      Hiá»‡n Mk12" },
                    { key = "EspItem_DMR_VSS", text = "      Hiá»‡n VSS" }
                }
            },
            {
                key = "EspItem_SMG", text = "   â–¶ SÃºng tiá»ƒu liÃªn (SMG)",
                weapons = {
                    { key = "EspItem_SMG_UZI", text = "      Hiá»‡n UZI" },
                    { key = "EspItem_SMG_UMP45", text = "      Hiá»‡n UMP45" },
                    { key = "EspItem_SMG_Vector", text = "      Hiá»‡n Vector" },
                    { key = "EspItem_SMG_Tommy", text = "      Hiá»‡n Tommy Gun" },
                    { key = "EspItem_SMG_Bizon", text = "      Hiá»‡n PP-19 Bizon" },
                    { key = "EspItem_SMG_MP5K", text = "      Hiá»‡n MP5K" },
                    { key = "EspItem_SMG_P90", text = "      Hiá»‡n P90" }
                }
            },
            {
                key = "EspItem_SG", text = "   â–¶ SÃºng sÄƒn (Shotgun)",
                weapons = {
                    { key = "EspItem_SG_S686", text = "      Hiá»‡n S686" },
                    { key = "EspItem_SG_S1897", text = "      Hiá»‡n S1897" },
                    { key = "EspItem_SG_S12K", text = "      Hiá»‡n S12K" },
                    { key = "EspItem_SG_DBS", text = "      Hiá»‡n DBS" },
                    { key = "EspItem_SG_M1014", text = "      Hiá»‡n M1014" }
                }
            },
            {
                key = "EspItem_LMG", text = "   â–¶ SÃºng mÃ¡y háº¡ng nháº¹ (LMG)",
                weapons = {
                    { key = "EspItem_LMG_DP28", text = "      Hiá»‡n DP-28" },
                    { key = "EspItem_LMG_M249", text = "      Hiá»‡n M249" },
                    { key = "EspItem_LMG_MG3", text = "      Hiá»‡n MG3" }
                }
            },
            {
                key = "EspItem_Pistol", text = "   â–¶ SÃºng lá»¥c",
                weapons = {
                    { key = "EspItem_Pistol_P1911", text = "      Hiá»‡n P1911" },
                    { key = "EspItem_Pistol_P92", text = "      Hiá»‡n P92" },
                    { key = "EspItem_Pistol_R1895", text = "      Hiá»‡n R1895" },
                    { key = "EspItem_Pistol_Deagle", text = "      Hiá»‡n Desert Eagle" },
                    { key = "EspItem_Pistol_Skorpion", text = "      Hiá»‡n Skorpion" },
                    { key = "EspItem_Pistol_P18C", text = "      Hiá»‡n P18C" }
                }
            },
            {
                key = "EspItem_Melee", text = "   â–¶ VÅ© khÃ­ cáº­n chiáº¿n",
                weapons = {
                    { key = "EspItem_Melee_Pan", text = "      Hiá»‡n Cháº£o (Pan)" },
                    { key = "EspItem_Melee_Sickle", text = "      Hiá»‡n Liá»m (Sickle)" },
                    { key = "EspItem_Melee_Machete", text = "      Hiá»‡n Rá»±a (Machete)" },
                    { key = "EspItem_Melee_Crowbar", text = "      Hiá»‡n XÃ  beng (Crowbar)" }
                }
            },
            {
                key = "EspItem_Other", text = "   â–¶ Váº­t pháº©m khÃ¡c",
                weapons = {
                    { key = "EspItem_Ot_Helmet3", text = "      Hiá»‡n MÅ© Cáº¥p 3" },
                    { key = "EspItem_Ot_Vest3", text = "      Hiá»‡n GiÃ¡p Cáº¥p 3" },
                    { key = "EspItem_Ot_Bag3", text = "      Hiá»‡n Balo Cáº¥p 3" },
                    { key = "EspItem_Ot_Scope8x", text = "      Hiá»‡n Scope 8x" },
                    { key = "EspItem_Ot_Scope6x", text = "      Hiá»‡n Scope 6x" },
                    { key = "EspItem_Ot_Scope4x", text = "      Hiá»‡n Scope 4x" },
                    { key = "EspItem_Ot_Medkit", text = "      Hiá»‡n Medkit" },
                    { key = "EspItem_Ot_FirstAid", text = "      Hiá»‡n First Aid" }
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
                GetFunc = function() return _G.TD_Settings[cat.key] == 1 end,
                SetFunc = function(_, value)
                    _G.TD_Settings[cat.key] = value and 1 or 0
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
                    GetFunc = function() return _G.TD_Settings[wp.key] == 1 end,
                    SetFunc = function(_, value)
                        _G.TD_Settings[wp.key] = value and 1 or 0
                        _G.EnvRequiresUpdate = true
                        return true
                    end
                })
            end
        end

        local StackAimbot = { { UI = AliasMap.Title, Text = "AIMBOT & GIáº¢M GIáº¬T" } }
        AddToggle(StackAimbot, "AIMBOT", "Báº¬T AIMBOT")
        AddSlider(StackAimbot, "SPEED_AIMBOT", "Tá»C Äá»˜ AIMBOT", 0, 100)
        AddSlider(StackAimbot, "FOV_AIMBOT", "FOV AIMBOT", 0, 100)
        AddSlider(StackAimbot, "THU_TAM", "THU NHá»Ž TÃ‚M Báº®N", 0, 100)
        AddSlider(StackAimbot, "NO_RECOIL_100", "GIáº¢M GIáº¬T (0-100%)", 0, 100)
        AddSlider(StackAimbot, "GIAM_RUNG_SCOPE", "GIáº¢M RUNG SCOPE", 0, 100)

        -- =========================================================================================
        -- [Má»šI] TÃCH Há»¢P TOÃ€N Bá»˜ GIAO DIá»†N VÃ€ LOGIC TAB 3 Cá»¦A CODE 2 SANG CODE 1 (AIMBOT ROYAL & CUSTOM)
        -- =========================================================================================
        local StackAimbotV2 = {
            { Key = "ModMenu_AT_Ex", UI = AliasMap.TitleSwitcher, Text = "â–¶ Báº­t Aimbot Roy & Custom", ExpandIndex = 0, GetFunc = function() return _G.TD_Settings.AimTouchEnable == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchEnable = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            
            -- HIPFIRE (TÃ‚M TRáº®NG)
            { Key = "ModMenu_AT_Hip_Ex", UI = AliasMap.TitleSwitcher, Text = "   â–¶ Aimbot TÃ¢m Tráº¯ng", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.TD_Settings.AimTouchHipfire == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchHipfire = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_Hip_IgKnock", UI = AliasMap.Switcher, Text = "      Bá» Qua Äá»‹ch Knock", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.TD_Settings.AimTouchHipIgKnock == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchHipIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Hip_IgBot", UI = AliasMap.Switcher, Text = "      Bá» Qua Bot", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.TD_Settings.AimTouchHipIgBot == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchHipIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Hip_Vis", UI = AliasMap.Switcher, Text = "      Check TÆ°á»ng (VisCheck)", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.TD_Settings.AimTouchHipVisCheck == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchHipVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Hip_Prio", UI = AliasMap.Slider, Text = "      Æ¯u TiÃªn (1:TÃ¢m 2:Gáº§n 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.TD_Settings.AimTouchHipPrio or 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchHipPrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Hip_Bone", UI = AliasMap.Slider, Text = "      Vá»‹ TrÃ­ (1:Äáº§u 2:Ngá»±c 3:Bá»¥ng 4:HÃ´ng)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.TD_Settings.AimTouchHipBone or 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchHipBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Hip_Cond", UI = AliasMap.Slider, Text = "      Äiá»u Kiá»‡n (1:Báº¯n má»›i Aim, 2:LuÃ´n Aim)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.TD_Settings.AimTouchHipCond or 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchHipCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Hip_Spd", UI = AliasMap.Slider, Text = "      Äá»™ MÆ°á»£t / Tá»‘c Äá»™ (1-100)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchHipSpeed or 50 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchHipSpeed = v return true end },
            { Key = "ModMenu_AT_Hip_FOV", UI = AliasMap.Slider, Text = "      VÃ²ng FOV (1-100)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchHipFOV or 30 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchHipFOV = v return true end },
            { Key = "ModMenu_AT_Hip_Dist", UI = AliasMap.Slider, Text = "      Khoáº£ng CÃ¡ch (1-500m)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.TD_Settings.AimTouchHipDist or 250) / 5) end, SetFunc = function(_, v) _G.TD_Settings.AimTouchHipDist = v * 5 return true end },

            -- AIMBOT SHOTGUN
            { Key = "ModMenu_AT_SG_Ex", UI = AliasMap.TitleSwitcher, Text = "   â–¶ Aimbot Shotgun (Chá»‰ nháº­n Shotgun)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.TD_Settings.AimTouchSG == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSG = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_SG_AutoFire", UI = AliasMap.Switcher, Text = "      Tá»± Äá»™ng Báº¯n lÃºc tá»± Ä‘á»™ng báº¯n chá»‹u khÃ³ báº¥m báº¯n nháº­n dame vÃ  auto báº¯n sáº½ khÃ´ng lá»—i dame", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.TD_Settings.AimTouchSGAutoFire == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSGAutoFire = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_IgKnock", UI = AliasMap.Switcher, Text = "      Bá» Qua Äá»‹ch Knock", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.TD_Settings.AimTouchSGIgKnock == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSGIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_IgBot", UI = AliasMap.Switcher, Text = "      Bá» Qua Bot", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.TD_Settings.AimTouchSGIgBot == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSGIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_Vis", UI = AliasMap.Switcher, Text = "      Check TÆ°á»ng (VisCheck)", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.TD_Settings.AimTouchSGVisCheck == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSGVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_SG_Prio", UI = AliasMap.Slider, Text = "      Æ¯u TiÃªn (1:TÃ¢m 2:Gáº§n 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.TD_Settings.AimTouchSGPrio or 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSGPrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_SG_Bone", UI = AliasMap.Slider, Text = "      Vá»‹ TrÃ­ (1:Äáº§u 2:Ngá»±c 3:Bá»¥ng 4:HÃ´ng)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.TD_Settings.AimTouchSGBone or 2 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSGBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_SG_Cond", UI = AliasMap.Slider, Text = "      Äiá»u Kiá»‡n (1:Báº¯n má»›i Aim, 2:LuÃ´n Aim)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.TD_Settings.AimTouchSGCond or 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSGCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_SG_Spd", UI = AliasMap.Slider, Text = "      Äá»™ MÆ°á»£t / Tá»‘c Äá»™ (1-100)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchSGSpeed or 80 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSGSpeed = v return true end },
            { Key = "ModMenu_AT_SG_FOV", UI = AliasMap.Slider, Text = "      VÃ²ng FOV (1-100)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchSGFOV or 40 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSGFOV = v return true end },
            { Key = "ModMenu_AT_SG_Dist", UI = AliasMap.Slider, Text = "      Khoáº£ng CÃ¡ch (1-100m)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchSGDist or 30 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSGDist = v return true end },
            
            -- SCOPE ALL (SÃšNG THÆ¯á»œNG KHI Má»ž SCOPE)
            { Key = "ModMenu_AT_ScopeAll_Ex", UI = AliasMap.TitleSwitcher, Text = "   â–¶ Aimbot Má»Ÿ Scope", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.TD_Settings.AimTouchScopeAll == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeAll = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_ScopeAll_IgKnock", UI = AliasMap.Switcher, Text = "      Bá» Qua Äá»‹ch Knock", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.TD_Settings.AimTouchScopeIgKnock == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_ScopeAll_IgBot", UI = AliasMap.Switcher, Text = "      Bá» Qua Bot", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.TD_Settings.AimTouchScopeIgBot == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_ScopeAll_Vis", UI = AliasMap.Switcher, Text = "      Check TÆ°á»ng (VisCheck)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.TD_Settings.AimTouchScopeVisCheck == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_ScopeAll_Prio", UI = AliasMap.Slider, Text = "      Æ¯u TiÃªn (1:TÃ¢m 2:Gáº§n 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.TD_Settings.AimTouchScopePrio or 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopePrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_ScopeAll_Bone", UI = AliasMap.Slider, Text = "      Vá»‹ TrÃ­ (1:Äáº§u 2:Ngá»±c 3:Bá»¥ng 4:HÃ´ng)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.TD_Settings.AimTouchScopeBone or 2 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_ScopeAll_Cond", UI = AliasMap.Slider, Text = "      Äiá»u Kiá»‡n (1:Báº¯n má»›i Aim, 2:LuÃ´n Aim)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.TD_Settings.AimTouchScopeCond or 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_ScopeAll_Spd", UI = AliasMap.Slider, Text = "      Äá»™ MÆ°á»£t / Tá»‘c Äá»™ (1-100)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchScopeSpeed or 40 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeSpeed = v return true end },
            { Key = "ModMenu_AT_ScopeAll_FOV", UI = AliasMap.Slider, Text = "      VÃ²ng FOV (1-100)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchScopeFOV or 20 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeFOV = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Dist", UI = AliasMap.Slider, Text = "      Khoáº£ng CÃ¡ch (1-500m)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.TD_Settings.AimTouchScopeDist or 300) / 5) end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeDist = v * 5 return true end },
            { Key = "ModMenu_AT_ScopeAll_Pred", UI = AliasMap.Slider, Text = "      Dá»± ÄoÃ¡n HÆ°á»›ng Cháº¡y", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchScopePred or 0 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopePred = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Recoil", UI = AliasMap.Slider, Text = "      BÃ¹ Giáº­t Tá»± Äá»™ng GhÃ¬m TÃ¢m Khi Aim ( Ä‘á»ƒ táº§m 3%-4% lÃ  á»•n)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 50, min = 0, max = 50, GetFunc = function() return _G.TD_Settings.AimTouchScopeRecoil or 0 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeRecoil = v return true end },

            -- SCOPE SNIPER (SÃšNG NGáº®M/Tá»ˆA)
            { Key = "ModMenu_AT_Sniper_Ex", UI = AliasMap.TitleSwitcher, Text = "   â–¶ Aimbot Má»Ÿ Scope (SÃºng Ngáº¯m/Tá»‰a)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.TD_Settings.AimTouchScopeSniper == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchScopeSniper = v and 1 or 0; _G.EnvRequiresUpdate = true; return true end },
            { Key = "ModMenu_AT_Sniper_IgKnock", UI = AliasMap.Switcher, Text = "      Bá» Qua Äá»‹ch Knock", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.TD_Settings.AimTouchSniperIgKnock == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSniperIgKnock = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Sniper_IgBot", UI = AliasMap.Switcher, Text = "      Bá» Qua Bot", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.TD_Settings.AimTouchSniperIgBot == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSniperIgBot = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Sniper_Vis", UI = AliasMap.Switcher, Text = "      Check TÆ°á»ng (VisCheck)", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.TD_Settings.AimTouchSniperVisCheck == 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSniperVisCheck = v and 1 or 0 return true end },
            { Key = "ModMenu_AT_Sniper_Prio", UI = AliasMap.Slider, Text = "      Æ¯u TiÃªn (1:TÃ¢m 2:Gáº§n 3:HP 4:%HP)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.TD_Settings.AimTouchSniperPrio or 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSniperPrio = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Sniper_Bone", UI = AliasMap.Slider, Text = "      Vá»‹ TrÃ­ (1:Äáº§u 2:Ngá»±c 3:Bá»¥ng 4:HÃ´ng)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.TD_Settings.AimTouchSniperBone or 1 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSniperBone = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Sniper_Cond", UI = AliasMap.Slider, Text = "      Äiá»u Kiá»‡n (1:Báº¯n má»›i Aim, 2:LuÃ´n Aim)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.TD_Settings.AimTouchSniperCond or 2 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSniperCond = math.floor(v+0.5) return true end },
            { Key = "ModMenu_AT_Sniper_Spd", UI = AliasMap.Slider, Text = "      Äá»™ MÆ°á»£t / Tá»‘c Äá»™ (1-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchSniperSpeed or 30 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSniperSpeed = v return true end },
            { Key = "ModMenu_AT_Sniper_FOV", UI = AliasMap.Slider, Text = "      VÃ²ng FOV (1-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchSniperFOV or 20 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSniperFOV = v return true end },
            { Key = "ModMenu_AT_Sniper_Dist", UI = AliasMap.Slider, Text = "      Khoáº£ng CÃ¡ch (1-500m)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.TD_Settings.AimTouchSniperDist or 400) / 5) end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSniperDist = v * 5 return true end },
            { Key = "ModMenu_AT_Sniper_Pred", UI = AliasMap.Slider, Text = "      Dá»± ÄoÃ¡n HÆ°á»›ng Cháº¡y (0-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.TD_Settings.AimTouchSniperPred or 0 end, SetFunc = function(_, v) _G.TD_Settings.AimTouchSniperPred = v return true end }
        }

        local StackMagic = { { UI = AliasMap.Title, Text = "MAGIC BULLET" } }
        AddSlider(StackMagic, "MAGIC_HEAD", "MAGIC Äáº¦U", 0, 300)
        AddSlider(StackMagic, "MAGIC_BODY", "MAGIC THÃ‚N", 0, 300)
        AddSlider(StackMagic, "MAGIC_LEGS", "MAGIC CHÃ‚N", 0, 300)

        local StackEnv = { { UI = AliasMap.Title, Text = "MÃ”I TRÆ¯á»œNG & GÃ“C NHÃŒN" } }
        AddToggle(StackEnv, "FAKE_HWID", "FAKE HWID (Chá»‘ng Ghim ID Thiáº¿t Bá»‹)")
        table.insert(StackEnv, {
            Key = "ModMenu_Ipad_Ex",
            UI = AliasMap.TitleSwitcher,
            Text = "â–¶ Ipad View",
            ExpandIndex = 0,
            GetFunc = function() return _G.TD_Settings.IpadView == 1 end,
            SetFunc = function(_, value)
                _G.TD_Settings.IpadView = value and 1 or 0
                _G.EnvRequiresUpdate = true
                return true
            end
        })
        table.insert(StackEnv, {
            Key = "ModMenu_Ipad_FOV",
            UI = AliasMap.Slider,
            Text = "   GÃ³c NhÃ¬n FOV",
            ExpandHandle = "ModMenu_Ipad_Ex",
            MinValue = 1,
            MaxValue = 100,
            Min = 1,
            Max = 100,
            GetFunc = function() return (_G.TD_Settings.IpadViewFOV or 120) - 90 end,
            SetFunc = function(_, value)
                _G.TD_Settings.IpadViewFOV = 90 + math.floor(tonumber(value) or 30)
                _G.EnvRequiresUpdate = true
                return true
            end
        })
        AddToggle(StackEnv, "NOGRASS", "XÃ“A Cá»Ž")
        AddToggle(StackEnv, "NOTREES", "XÃ“A CÃ‚Y")
        AddToggle(StackEnv, "NOWATER", "XÃ“A NÆ¯á»šC")
        AddToggle(StackEnv, "NOFOG", "XÃ“A SÆ¯Æ NG MÃ™")
        AddToggle(StackEnv, "BLACK_SKY", "TRá»œI Tá»I")
        AddToggle(StackEnv, "GHOST_MODE", "ðŸ‘» GHOST MODE (Tá»± Ä‘á»™ng táº¯t khi bá»‹ quÃ©t)")
        AddToggle(StackEnv, "NO_LANDING_LAG", "ðŸƒ CHá»NG KHá»°NG KHI RÆ I")
        AddToggle(StackEnv, "AUTO_BUNNYHOP", "ðŸ° BUNNY HOP (Nháº£y liÃªn tá»¥c)")
        
        SettingPageDefine.ModMenu = {
            Key = "ModMenu", loc = "VIP MENU", UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "ModMenu_Cat1", loc = "ESP", Stack = StackESP },
                { Key = "ModMenu_Cat6", loc = "ESP Váº¬T PHáº¨M", Stack = StackItemESP },
                { Key = "ModMenu_Cat2", loc = "AIMBOT & VÅ¨ KHÃ", Stack = StackAimbot },
                { Key = "ModMenu_Cat5", loc = "AIMBOT ROYAL & CUSTOM", Stack = StackAimbotV2 },
                { Key = "ModMenu_Cat3", loc = "MAGIC BULLET", Stack = StackMagic },
                { Key = "ModMenu_Cat4", loc = "GÃ“C NHÃŒN & MÃ”I TRÆ¯á»œNG", Stack = StackEnv },
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

-- =========================== PHáº¦N 28: AURA DYEING FUNCTIONS ===========================
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
-- CÃ¡c giÃ¡ trá»‹ RGB Ä‘Ã£ Ä‘Æ°á»£c nhÃ¢n vá»›i há»‡ sá»‘ phÃ¡t sÃ¡ng 3.5 Ä‘á»ƒ táº¡o hiá»‡u á»©ng Glow/Bloom
local WALL_COLOR_PRESETS = {
    [1] = {3.5, 3.5, 3.5, 1.0},  -- Tráº¯ng phÃ¡t sÃ¡ng   (Emissive White)
    [2] = {3.5, 0.0, 0.0, 1.0},  -- Äá» phÃ¡t sÃ¡ng     (Emissive Red)
    [3] = {3.5, 3.15, 0.0, 1.0}, -- VÃ ng phÃ¡t sÃ¡ng   (Emissive Yellow)
    [4] = {0.0, 3.5, 0.0, 1.0},  -- Xanh LÃ¡ phÃ¡t sÃ¡ng(Emissive Green)
    [5] = {0.0, 3.5, 3.15, 1.0}, -- Xanh Ngá»c phÃ¡t sÃ¡ng (Emissive Cyan)
    [6] = {0.0, 0.0, 3.5, 1.0},  -- Xanh DÆ°Æ¡ng phÃ¡t sÃ¡ng (Emissive Blue)
    [7] = {0.829, 0.229, 3.829, 1.0}, -- TÃ­m phÃ¡t sÃ¡ng    (Emissive Purple)
    [8] = {3.5, 0.0, 2.1, 1.0},  -- Há»“ng phÃ¡t sÃ¡ng   (Emissive Pink)
    [9] = {0.0, 0.0, 0.0, 1.0},  -- Äen (KhÃ´ng phÃ¡t sÃ¡ng vÃ¬ cÃ¡c giÃ¡ trá»‹ gá»‘c báº±ng 0)
}
local function GetWallColorByIndex(idx)
    local p = WALL_COLOR_PRESETS[idx] or WALL_COLOR_PRESETS[3]
    return AuraColor(p[1], p[2], p[3], 1.0)
end
local function GetCurrentWallVisibleColor()
    return GetWallColorByIndex((_G.TD_Settings and _G.TD_Settings.WALL_VISIBLE_COLOR) or 3)
end
local function GetCurrentWallOccludedColor(isAI)
    if isAI then
        return GetWallColorByIndex((_G.TD_Settings and _G.TD_Settings.WALL_OCCLUDED_AI_COLOR) or 7)
    else
        return GetWallColorByIndex((_G.TD_Settings and _G.TD_Settings.WALL_OCCLUDED_COLOR) or 2)
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

-- =========================== PHáº¦N 28B: AIMTOUCH FUNCTIONS (Tá»ª CODE 2) ===========================
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
        if _G.TD_GetVal("AimTouchEnable") ~= 1 then return end
        
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

        -- LOGIC NHáº¢ CÃ’ SÃšNG Náº¾U Máº¤T Má»¤C TIÃŠU / Äá»ŠCH CHáº¾T HOáº¶C SHOTGUN Háº¾T Äáº N
        if _G.LexusState then
            if _G.LexusState.IsAutoFiring then
                pcall(function()
                    player.bIsWeaponFiring = false
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
                end)
                _G.LexusState.IsAutoFiring = false
            end
        end

        -- SHOTGUN Háº¾T Äáº N NGÆ¯NG AIM Äá»‚ GAME Náº P Äáº N
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

        -- PHÃ‚N LOáº I Cáº¤U HÃŒNH THEO TRáº NG THÃI HIá»†N Táº I
if isShotgun and _G.TD_GetVal("AimTouchSG") == 1 then
    cond = _G.TD_GetVal("AimTouchSGCond") or 1
    if _G.TD_GetVal("AimTouchSGAutoFire") == 1 then cond = 2 end
    
    -- =========================================================
    -- [FIX] SHOTGUN GRACE PERIOD - Duy trÃ¬ tráº¡ng thÃ¡i "Ä‘ang báº¯n"
    -- trong 0.6s sau phÃ¡t báº¯n cuá»‘i Ä‘á»ƒ khÃ´ng bá»‹ ngáº¯t khi pump action
    -- =========================================================
    local curTimeShotgun = os.clock()
    local isActuallyFiring = isFiring
    
    -- Náº¿u Ä‘ang báº¯n tháº­t â†’ cáº­p nháº­t thá»i gian báº¯n cuá»‘i
    if isFiring then
        _G.TD_Shotgun_LastFireTime = curTimeShotgun
        isActuallyFiring = true
    else
        -- Náº¿u vá»«a má»›i báº¯n xong (trong vÃ²ng 0.6s) â†’ váº«n coi nhÆ° Ä‘ang báº¯n
        local lastFireTime = _G.TD_Shotgun_LastFireTime or 0
        if (curTimeShotgun - lastFireTime) < 0.6 then
            isActuallyFiring = true
        end
    end
    
    -- [Tá»I Æ¯U] Äiá»u chá»‰nh grace period theo tá»«ng loáº¡i shotgun
    local wNameSG = ""
    if slua.isValid(weapon) and type(weapon.GetWeaponName) == "function" then
        wNameSG = string.lower(tostring(weapon:GetWeaponName() or ""))
    end
    local gracePeriod = 0.6 -- máº·c Ä‘á»‹nh
    if wNameSG:find("s12k") or wNameSG:find("dbs") or wNameSG:find("m1014") then 
        gracePeriod = 0.35  -- shotgun bÃ¡n tá»± Ä‘á»™ng (báº¯n nhanh)
    elseif wNameSG:find("s1897") then 
        gracePeriod = 0.85  -- pump cháº­m
    elseif wNameSG:find("s686") then 
        gracePeriod = 0.45  -- 2 nÃ²ng ngang
    end
    
    -- Ãp dá»¥ng láº¡i grace period Ä‘Ã£ tá»‘i Æ°u
    if not isFiring then
        local lastFireTime = _G.TD_Shotgun_LastFireTime or 0
        if (curTimeShotgun - lastFireTime) < gracePeriod then
            isActuallyFiring = true
        else
            isActuallyFiring = false
        end
    end
    
    -- Kiá»ƒm tra Ä‘iá»u kiá»‡n báº¯n vá»›i tráº¡ng thÃ¡i Ä‘Ã£ Ä‘Æ°á»£c "smooth"
    if cond == 1 and not isActuallyFiring then return end
    -- =========================================================
    
    prioMode = _G.TD_GetVal("AimTouchSGPrio") or 1
    boneIdx = _G.TD_GetVal("AimTouchSGBone") or 2
    speedVal = _G.TD_GetVal("AimTouchSGSpeed") or 80
    fovVal = _G.TD_GetVal("AimTouchSGFOV") or 40
    maxDistMeters = _G.TD_GetVal("AimTouchSGDist") or 30
    useVisCheck = _G.TD_GetVal("AimTouchSGVisCheck") == 1
    igKnock = _G.TD_GetVal("AimTouchSGIgKnock") == 1
    igBot = _G.TD_GetVal("AimTouchSGIgBot") == 1
            
        elseif isADS then
            if isSniper and _G.TD_GetVal("AimTouchScopeSniper") == 1 then
                cond = _G.TD_GetVal("AimTouchSniperCond") or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.TD_GetVal("AimTouchSniperPrio") or 1
                boneIdx = _G.TD_GetVal("AimTouchSniperBone") or 1
                speedVal = _G.TD_GetVal("AimTouchSniperSpeed") or 30
                fovVal = _G.TD_GetVal("AimTouchSniperFOV") or 20
                maxDistMeters = _G.TD_GetVal("AimTouchSniperDist") or 400
                useVisCheck = _G.TD_GetVal("AimTouchSniperVisCheck") == 1
                igKnock = _G.TD_GetVal("AimTouchSniperIgKnock") == 1
                igBot = _G.TD_GetVal("AimTouchSniperIgBot") == 1
                predVal = _G.TD_GetVal("AimTouchSniperPred") or 0
            elseif _G.TD_GetVal("AimTouchScopeAll") == 1 then
                cond = _G.TD_GetVal("AimTouchScopeCond") or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.TD_GetVal("AimTouchScopePrio") or 1
                boneIdx = _G.TD_GetVal("AimTouchScopeBone") or 2
                speedVal = _G.TD_GetVal("AimTouchScopeSpeed") or 40
                fovVal = _G.TD_GetVal("AimTouchScopeFOV") or 20
                maxDistMeters = _G.TD_GetVal("AimTouchScopeDist") or 300
                useVisCheck = _G.TD_GetVal("AimTouchScopeVisCheck") == 1
                igKnock = _G.TD_GetVal("AimTouchScopeIgKnock") == 1
                igBot = _G.TD_GetVal("AimTouchScopeIgBot") == 1
                predVal = _G.TD_GetVal("AimTouchScopePred") or 0
                recoilCompVal = _G.TD_GetVal("AimTouchScopeRecoil") or 0
            else
                return
            end
        else
            if not (_G.TD_GetVal("AimTouchHipfire") == 1) then return end
            cond = _G.TD_GetVal("AimTouchHipCond") or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.TD_GetVal("AimTouchHipPrio") or 1
            boneIdx = _G.TD_GetVal("AimTouchHipBone") or 1
            speedVal = _G.TD_GetVal("AimTouchHipSpeed") or 50
            fovVal = _G.TD_GetVal("AimTouchHipFOV") or 30
            maxDistMeters = _G.TD_GetVal("AimTouchHipDist") or 250
            useVisCheck = _G.TD_GetVal("AimTouchHipVisCheck") == 1
            igKnock = _G.TD_GetVal("AimTouchHipIgKnock") == 1
            igBot = _G.TD_GetVal("AimTouchHipIgBot") == 1
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
            
            -- Check tÆ°á»ng cÃ³ cache
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
        
-- [NÃ‚NG Cáº¤P V4] ULTIMATE PREDICTION: ITERATIVE + EMA + DYNAMIC BULLET SPEED + PING
if predVal > 0 then
pcall(function()
    local tVelocity = nil
    if type(bestTarget.GetVelocity) == "function" then
        tVelocity = bestTarget:GetVelocity()
    end
    
    if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0 or (tVelocity.Z and math.abs(tVelocity.Z) > 10)) then
        local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0 
        
        -- 1. BÃ™ TRá»ª PING (One-way delay + Server Tick Rate 20ms)
        local pingSec = 0.02 
        pcall(function()
            local pc = GameplayData.GetPlayerController()
            if pc and pc.PlayerState and pc.PlayerState.Ping then
                pingSec = (pc.PlayerState.Ping / 2000.0) + 0.02
            end
        end)

        -- 2. Tá»C Äá»˜ Äáº N Äá»˜NG (Láº¥y chuáº©n theo tá»«ng loáº¡i sÃºng thá»±c táº¿)
        local bulletSpeed = 880.0 -- Máº·c Ä‘á»‹nh M416/SCAR
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

        -- 3. Lá»ŒC NHIá»„U VELOCITY (EMA Smoothing - Chá»‘ng giáº­t tÃ¢m)
        if not _G.Pred_VelCache then _G.Pred_VelCache = {} end
        local tId = tostring(bestTarget)
        local oldVel = _G.Pred_VelCache[tId] or tVelocity
        local alpha = 0.4 -- Há»‡ sá»‘ mÆ°á»£t (0.4 lÃ  cÃ¢n báº±ng giá»¯a Ä‘á»™ bÃ¡m vÃ  Ä‘á»™ mÆ°á»£t)
        local smoothVel = {
            X = (oldVel.X * (1 - alpha)) + (tVelocity.X * alpha),
            Y = (oldVel.Y * (1 - alpha)) + (tVelocity.Y * alpha),
            Z = (oldVel.Z * (1 - alpha)) + ((tVelocity.Z or 0) * alpha)
        }
        _G.Pred_VelCache[tId] = smoothVel

        -- 4. Há»† Sá» BONE (Tinh chá»‰nh chuáº©n PUBG Mobile)
        local boneFactors = {
            ["head"] = 0.75, ["neck_01"] = 0.80,
            ["spine_03"] = 1.00, ["spine_02"] = 1.05, ["spine_01"] = 0.95,
            ["pelvis"] = 0.90, ["thigh_l"] = 0.40, ["thigh_r"] = 0.40,
            ["calf_l"] = 0.20, ["calf_r"] = 0.20, ["foot_l"] = 0.10, ["foot_r"] = 0.10,
        }
        local cleanBone = string.gsub(selBoneName, "%s+", "")
        local boneFactor = boneFactors[cleanBone] or 1.0
        
        -- 5. Dá»° ÄOÃN Láº¶P (Iterative Prediction - Giáº£i quyáº¿t sai sá»‘ cá»± ly xa)
        local currentToF = (distToEnemy / bulletSpeed) * (predVal / 50.0)
        local predX, predY, predZ = finalBonePos.X, finalBonePos.Y, finalBonePos.Z
        local playerLoc = player:K2_GetActorLocation()
        
        -- Láº·p 3 láº§n Ä‘á»ƒ há»™i tá»¥ tá»a Ä‘á»™ chÃ­nh xÃ¡c tuyá»‡t Ä‘á»‘i
        for i = 1, 3 do
            local totalT = (currentToF * boneFactor) + pingSec
            
            -- Vá»‹ trÃ­ Ä‘á»‹ch sau thá»i gian totalT
            predX = finalBonePos.X + (smoothVel.X * totalT)
            predY = finalBonePos.Y + (smoothVel.Y * totalT)
            predZ = finalBonePos.Z + (smoothVel.Z * totalT)
            
            -- TÃ­nh láº¡i khoáº£ng cÃ¡ch tá»›i vá»‹ trÃ­ Dá»° ÄOÃN (Thay vÃ¬ vá»‹ trÃ­ cÅ©)
            if playerLoc then
                local dx = (predX - playerLoc.X) / 100.0
                local dy = (predY - playerLoc.Y) / 100.0
                local dz = (predZ - playerLoc.Z) / 100.0
                local newDist = math.sqrt(dx*dx + dy*dy + dz*dz)
                currentToF = (newDist / bulletSpeed) * (predVal / 50.0)
            end
        end
        
        -- 6. BÃ™ TRá»ª RÆ I Äáº N (Bullet Drop) - Ãp dá»¥ng cho Má»ŒI phÃ¡t báº¯n
        local totalFinalT = (currentToF * boneFactor) + pingSec
        local gravity = 490.0 -- 1/2 * 980 cm/s2 (Chuáº©n UE4)
        local bulletDrop = gravity * (totalFinalT * totalFinalT)
        
        -- Z cuá»‘i cÃ¹ng = Z Ä‘á»‹ch di chuyá»ƒn - Z Ä‘áº¡n bá»‹ rÆ¡i do trá»ng lá»±c
        predZ = predZ - bulletDrop

        -- GÃ¡n láº¡i tá»a Ä‘á»™ cuá»‘i cÃ¹ng cho Aimbot
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
        
        -- BÃ¹ trá»« chÃªnh lá»‡ch Camera khi má»Ÿ á»‘ng ngáº¯m (ADS)
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
        
        -- RECOIL COMPENSATION (BÃ™ GIáº¬T)
        if recoilCompVal > 0 and isFiring then
            local pullDownForce = (recoilCompVal / 50.0) * 1.5
            finalPitch = finalPitch - pullDownForce
        end

        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")
        
        if isShotgun and _G.TD_GetVal("AimTouchSGAutoFire") == 1 then
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
                    if _G.LexusState then _G.LexusState.IsAutoFiring = true end
                end
            end)
        end

    end)
end

-- -- =========================================================================================
-- [FIXED] THREAT ASSESSMENT ESP - Logic Ä‘Ãºng chuáº©n + VIS CHECK (áº¨N KHI KHUáº¤T TÆ¯á»œNG)
-- =========================================================================================
local ThreatESP_Cache = {}
local ThreatESP_OriginalColors = {}
local ThreatESP_VisCache = {} -- Cache VisCheck

local function UpdateThreatAssessmentESP(LocalPlayer, PlayerController, MyHUD)
    if _G.TD_GetVal("THREAT_ESP") ~= 1 then
        -- Náº¿u táº¯t, restore táº¥t cáº£ mÃ u Ä‘Ã£ Ä‘á»•i
        for eId, origData in pairs(ThreatESP_OriginalColors) do
            pcall(function()
                local enemy = origData.actor
                if slua.isValid(enemy) and slua.isValid(enemy.Mesh) then
                    if FLinearColor then
                        enemy.Mesh:SetVisibleDyeingColor(origData.visible)
                        enemy.Mesh:SetOccludedDyeingColor(origData.occluded)
                    else
                        enemy.Mesh:SetVisibleDyeingColor(origData.visible)
                        enemy.Mesh:SetOccludedDyeingColor(origData.occluded)
                    end
                end
            end)
        end
        for k in pairs(ThreatESP_OriginalColors) do ThreatESP_OriginalColors[k] = nil end
        return
    end
    if not slua.isValid(LocalPlayer) or not slua.isValid(PlayerController) or not slua.isValid(MyHUD) then return end
    local curTime = os.clock()
    local allChars = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
    local myTeam = LocalPlayer.TeamID
    local myLoc = LocalPlayer:K2_GetActorLocation()
    if not myLoc then return end

    -- Track enemy IDs Ä‘ang Ä‘Æ°á»£c xá»­ lÃ½ Ä‘á»ƒ cleanup cache cÅ©
    local processedIds = {}

    for _, enemy in pairs(allChars) do
        if not slua.isValid(enemy) or enemy == LocalPlayer then goto continue_threat end
        if enemy.TeamID == myTeam then goto continue_threat end
        
        local eId = tostring(enemy)
        processedIds[eId] = true
        
        -- Check dead
        local isDead = false
        pcall(function()
            if enemy.bIsDead or enemy.bIsDeadFlag then isDead = true end
            if type(enemy.IsDead) == "function" and enemy:IsDead() then isDead = true end
        end)
        if isDead then 
            if ThreatESP_OriginalColors[eId] then
                pcall(function() 
                    if slua.isValid(enemy.Mesh) then
                        local orig = ThreatESP_OriginalColors[eId]
                        if FLinearColor then
                            enemy.Mesh:SetVisibleDyeingColor(orig.visible)
                            enemy.Mesh:SetOccludedDyeingColor(orig.occluded)
                        else
                            enemy.Mesh:SetVisibleDyeingColor(orig.visible)
                            enemy.Mesh:SetOccludedDyeingColor(orig.occluded)
                        end
                    end
                end)
                ThreatESP_OriginalColors[eId] = nil
            end
            goto continue_threat 
        end
        
        local dist = 0
        pcall(function() dist = LocalPlayer:GetDistanceTo(enemy) / 100 end)
        if dist > 400 or dist < 5 then goto continue_threat end
        
        -- ===== VISIBILITY CHECK Vá»šI CACHE (0.2s) - áº¨n khi khuáº¥t tÆ°á»ng =====
        local isVisible = true
        local visCacheKey = tostring(enemy)
        local cached = ThreatESP_VisCache[visCacheKey]
        if cached and (curTime - cached.time) < 0.2 then
            isVisible = cached.visible
        else
            pcall(function()
                if slua.isValid(PlayerController) and PlayerController.LineOfSightTo then
                    isVisible = PlayerController:LineOfSightTo(enemy) and true or false
                end
            end)
            ThreatESP_VisCache[visCacheKey] = { visible = isVisible, time = curTime }
        end
        
        -- ===== LOGIC ÄÃšNG: Check xem Ä‘á»‹ch cÃ³ Ä‘ang NGáº®M VÃ€O MÃŒNH khÃ´ng =====
        local isAimingAtMe = false
        local isFiringAtMe = false
        local eLoc = enemy:K2_GetActorLocation()
        
        if eLoc then
            local toMeX = myLoc.X - eLoc.X
            local toMeY = myLoc.Y - eLoc.Y
            local len = math.sqrt(toMeX*toMeX + toMeY*toMeY)
            
            if len > 10 then
                toMeX = toMeX / len
                toMeY = toMeY / len
                
                local eRot = nil
                pcall(function() eRot = enemy:K2_GetActorRotation() end)
                
                if eRot then
                    local fwdX = math.cos(math.rad(eRot.Yaw))
                    local fwdY = math.sin(math.rad(eRot.Yaw))
                    local dot = toMeX * fwdX + toMeY * fwdY
                    
                    if dot > 0.7 then
                        isAimingAtMe = true
                        local isFiring = false
                        local isADS = false
                        pcall(function()
                            isFiring = enemy.bIsWeaponFiring == true
                            isADS = enemy.bIsWeaponAiming == true or enemy.bIsGunADS == true
                        end)
                        if isFiring or isADS then
                            isFiringAtMe = true
                        end
                    end
                end
            end
        end
        
        -- ===== Xá»¬ LÃ HIá»‚N THá»Š (CÃ“ VIS CHECK) =====
        if isFiringAtMe and isVisible then
            -- TRÆ¯á»œNG Há»¢P 1: Äá»‹ch Ä‘ang NGáº®M VÃ€ Báº®N + NHÃŒN THáº¤Y â†’ Cáº¢NH BÃO Äá»Ž NHÃY
            if not ThreatESP_OriginalColors[eId] and slua.isValid(enemy.Mesh) then
                pcall(function()
                    ThreatESP_OriginalColors[eId] = {
                        actor = enemy,
                        visible = enemy.Mesh:GetVisibleDyeingColor(),
                        occluded = enemy.Mesh:GetOccludedDyeingColor()
                    }
                end)
            end
            
            local flashOn = (_G.TD_GetVal("THREAT_ESP_FLASH") == 1) and (math.floor(curTime * 6) % 2 == 0)
            local warnColor = flashOn and {R=255, G=0, B=0, A=255} or {R=200, G=30, B=30, A=255}
            
            pcall(function()
                if slua.isValid(enemy.Mesh) then
                    if FLinearColor then
                        enemy.Mesh:SetVisibleDyeingColor(FLinearColor(3.5, 0.0, 0.0, 1.0))
                        enemy.Mesh:SetOccludedDyeingColor(FLinearColor(3.5, 0.0, 0.0, 1.0))
                    else
                        enemy.Mesh:SetVisibleDyeingColor({R=255, G=0, B=0, A=255})
                        enemy.Mesh:SetOccludedDyeingColor({R=255, G=0, B=0, A=255})
                    end
                    enemy.Mesh:SetDrawHighlight(true)
                    enemy.Mesh:SetRenderCustomDepth(true)
                    enemy.Mesh:SetCustomDepthStencilValue(255)
                end
            end)
            
            MyHUD:AddDebugText("ÄANG NGáº®M Báº®N Báº N", enemy, 0.3, 
                {X=0, Y=0, Z=120}, {X=0, Y=0, Z=120}, 
                warnColor, true, false, true, nil, 1.0, true)
            
            if _G.TD_GetVal("THREAT_ESP_WARN_LINE") == 1 then
                pcall(function()
                    local KismetSystemLibrary = import("KismetSystemLibrary")
                    if KismetSystemLibrary and KismetSystemLibrary.DrawDebugLine then
                        local camManager = GameplayStatics.GetPlayerCameraManager(PlayerController, 0)
                        if slua.isValid(camManager) then
                            local camLoc = camManager:GetCameraLocation()
                            local eHeadPos = enemy:K2_GetActorLocation()
                            eHeadPos.Z = eHeadPos.Z + 80
                            KismetSystemLibrary.DrawDebugLine(
                                PlayerController, camLoc, eHeadPos,
                                FLinearColor(1.0, 0.0, 0.0, 1.0), 0.15, 3.0
                            )
                        end
                    end
                end)
            end
            
        elseif isAimingAtMe and isVisible then
            -- TRÆ¯á»œNG Há»¢P 2: Äá»‹ch Ä‘ang nhÃ¬n vá» mÃ¬nh + NHÃŒN THáº¤Y â†’ Cáº¢NH BÃO VÃ€NG
            if ThreatESP_OriginalColors[eId] then
                pcall(function()
                    if slua.isValid(enemy.Mesh) then
                        local orig = ThreatESP_OriginalColors[eId]
                        if FLinearColor then
                            enemy.Mesh:SetVisibleDyeingColor(orig.visible)
                            enemy.Mesh:SetOccludedDyeingColor(orig.occluded)
                        else
                            enemy.Mesh:SetVisibleDyeingColor(orig.visible)
                            enemy.Mesh:SetOccludedDyeingColor(orig.occluded)
                        end
                        enemy.Mesh:SetDrawHighlight(false)
                        enemy.Mesh:SetRenderCustomDepth(false)
                    end
                end)
                ThreatESP_OriginalColors[eId] = nil
            end
            
            MyHUD:AddDebugText("ÄANG NHÃŒN Vá»€ Báº N", enemy, 0.3,
                {X=0, Y=0, Z=110}, {X=0, Y=0, Z=110},
                {R=255, G=200, B=0, A=255}, true, false, true, nil, 0.7, true)
        else
            -- TRÆ¯á»œNG Há»¢P 3: KHÃ”NG nhÃ¬n vá» mÃ¬nh HOáº¶C Bá»Š KHUáº¤T TÆ¯á»œNG â†’ Restore mÃ u gá»‘c + áº¨n text
            if ThreatESP_OriginalColors[eId] then
                pcall(function()
                    if slua.isValid(enemy.Mesh) then
                        local orig = ThreatESP_OriginalColors[eId]
                        if FLinearColor then
                            enemy.Mesh:SetVisibleDyeingColor(orig.visible)
                            enemy.Mesh:SetOccludedDyeingColor(orig.occluded)
                        else
                            enemy.Mesh:SetVisibleDyeingColor(orig.visible)
                            enemy.Mesh:SetOccludedDyeingColor(orig.occluded)
                        end
                        enemy.Mesh:SetDrawHighlight(false)
                        enemy.Mesh:SetRenderCustomDepth(false)
                    end
                end)
                ThreatESP_OriginalColors[eId] = nil
            end
            -- KhÃ´ng váº½ text cáº£nh bÃ¡o â†’ tá»± Ä‘á»™ng áº©n
        end
        
        ::continue_threat::
    end

    -- Cleanup cache enemy Ä‘Ã£ cháº¿t/rá»i Ä‘i
    for eId, _ in pairs(ThreatESP_OriginalColors) do
        if not processedIds[eId] then
            ThreatESP_OriginalColors[eId] = nil
        end
    end
    
    -- Cleanup VisCache cÅ© (> 5s)
    for k, v in pairs(ThreatESP_VisCache) do
        if (curTime - v.time) > 5.0 then
            ThreatESP_VisCache[k] = nil
        end
    end
end


-- =========================================================================================
-- [NEW FEATURE 4A] DYNAMIC GHOST MODE - Táº¡m táº¯t tÃ­nh nÄƒng khi bá»‹ quÃ©t
-- =========================================================================================
local GhostMode_Active = false
local GhostMode_OriginalSettings = nil

local function UpdateGhostMode()
    -- Láº¥y tráº¡ng thÃ¡i cáº¥u hÃ¬nh cá»§a ngÆ°á»i dÃ¹ng
    local isEnabled = (_G.TD_GetVal("GHOST_MODE") == 1)
    local curTime = os.clock()
    
    -- Kiá»ƒm tra xem há»‡ thá»‘ng chá»‘ng gian láº­n cÃ³ Ä‘ang quÃ©t hay khÃ´ng
    local isScanning = (curTime - (TssSdk_LastScanTime or 0)) < 5.0

    -- TRÆ¯á»œNG Há»¢P 1: TÃ­nh nÄƒng Ä‘Æ°á»£c báº­t, phÃ¡t hiá»‡n cÃ³ quÃ©t, vÃ  chÆ°a kÃ­ch hoáº¡t áº©n
    if isEnabled and isScanning and not GhostMode_Active then
        GhostMode_Active = true
        
        -- Sao lÆ°u láº¡i toÃ n bá»™ cáº¥u hÃ¬nh hiá»‡n táº¡i cá»§a ngÆ°á»i dÃ¹ng
        GhostMode_OriginalSettings = {
            AIMBOT = _G.TD_Settings.AIMBOT or 0,
            MAGIC_HEAD = _G.TD_Settings.MAGIC_HEAD or 0,
            MAGIC_BODY = _G.TD_Settings.MAGIC_BODY or 0,
            MAGIC_LEGS = _G.TD_Settings.MAGIC_LEGS or 0,
        }
        
        -- ÄÆ°a táº¥t cáº£ cÃ¡c thÃ´ng sá»‘ nháº¡y cáº£m vá» an toÃ n (0)
        _G.TD_Settings.AIMBOT = 0
        _G.TD_Settings.MAGIC_HEAD = 0
        _G.TD_Settings.MAGIC_BODY = 0
        _G.TD_Settings.MAGIC_LEGS = 0
        
        _G.EnvRequiresUpdate = true
        _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
        print("[GHOST MODE] PhÃ¡t hiá»‡n quÃ©t bá»™ nhá»›! ÄÃ£ táº¡m thá»i vÃ´ hiá»‡u hÃ³a cÃ¡c tÃ­nh nÄƒng Ä‘á»ƒ báº£o vá»‡ tÃ i khoáº£n.")

    -- TRÆ¯á»œNG Há»¢P 2: QuÃ¡ trÃ¬nh quÃ©t káº¿t thÃºc HOáº¶C ngÆ°á»i dÃ¹ng chá»§ Ä‘á»™ng táº¯t Ghost Mode khi Ä‘ang trong tráº¡ng thÃ¡i áº©n
    elseif (GhostMode_Active and not isScanning) or (not isEnabled and GhostMode_Active) then
        -- KhÃ´i phá»¥c láº¡i cÃ¡c cÃ i Ä‘áº·t gá»‘c Ä‘Ã£ lÆ°u
        if GhostMode_OriginalSettings then
            for k, v in pairs(GhostMode_OriginalSettings) do
                _G.TD_Settings[k] = v
            end
            GhostMode_OriginalSettings = nil
        end
        
        GhostMode_Active = false
        _G.EnvRequiresUpdate = true
        _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
        print("[GHOST MODE] Tráº¡ng thÃ¡i an toÃ n. ÄÃ£ khÃ´i phá»¥c láº¡i cÃ¡c cáº¥u hÃ¬nh hoáº¡t Ä‘á»™ng ban Ä‘áº§u.")
    end
end

-- =========================== PHáº¦N 29: BRPLAYERCHARACTERBASE METHODS ===========================
function BRPlayerCharacterBase:StartAdvancedSystems()
    if not Client then return end
    
    -- Clear physics asset modification cache for the new match to force re-applying Magic Bullet
    _G.TD_ModdedPhysAssets = {}
    _G.MagicUpdateVersion = (_G.MagicUpdateVersion or 1) + 1
    
    local function Valid(obj) return slua_isValid(obj) end

    local function CheckIsAI(pawn)
        if pawn.TD_IsAICached ~= nil then return pawn.TD_IsAICached end
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
                if name and (name:find("Cobra") or name:find("è®­ç»ƒæœºå™¨äºº") or name:find("Target")) then
                    isAI = true
                end
            end
        end)
        pawn.TD_IsAICached = isAI
        return isAI
    end




    local GlobalSkelClass = import("SkeletalMeshComponent")
    
    local EMovementMode = import("EMovementMode")
    local cache_AimTouchEnable = _G.TD_GetVal("AimTouchEnable") or 0
    local cache_AUTO_BUNNYHOP = _G.TD_GetVal("AUTO_BUNNYHOP") or 0
    
    -- TIMER CHU Ká»² 0.0083s DÃ€NH CHO AIMBOT ROYAL & CUSTOM (120 FPS)
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
        
        -- Bunny Hop (Nháº£y liÃªn tá»¥c khÃ´ng khá»±ng khi giá»¯ nÃºt nháº£y)
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

        cache_AimTouchEnable = _G.TD_GetVal("AimTouchEnable") or 0
        cache_AUTO_BUNNYHOP = _G.TD_GetVal("AUTO_BUNNYHOP") or 0

        if currentTime > expireTime then
            if self.Object == LocalPlayer and not self.bHasShownExpiredNotice then
                if self.Object.IsAlive and self.Object:IsAlive() then
                    self.bHasShownExpiredNotice = true
                    pcall(function()
                        local msgBox = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
                        if msgBox and msgBox.Show then
                            local formattedExpire = os.date("%H:%M %d/%m/%Y", expireTime)
                            msgBox.Show(4, "THÃ”NG BÃO Háº¾T Háº N", "PHIÃŠN Báº¢N MOD Cá»¦A Báº N ÄÃƒ Háº¾T Háº N vÃ o lÃºc " .. formattedExpire .. "\nVUI LÃ’NG LIÃŠN Há»† Haku x DX", function() 
                                local KismetSystemLibrary = import("KismetSystemLibrary")
                                if KismetSystemLibrary then KismetSystemLibrary.LaunchURL("https://t.me/DeerXua") end
                            end, function() end, "LIÃŠN Há»†", "Há»¦Y")
                        end
                    end)
                end
            end
            return 
        end

        if self.Object == LocalPlayer and not self.bHasShownWelcomeNotice then
            if self.Object.IsAlive and self.Object:IsAlive() then
                self.bHasShownWelcomeNotice = true
                pcall(function()
                    local msgBox = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
                    if msgBox and msgBox.Show then
                        local formattedExpire = os.date("%H:%M %d/%m/%Y", expireTime)
                        msgBox.Show(4, "THÃ”NG BÃO", "WELCOME TO VIP MOD MENU\n MOD ÄÆ°á»£c Táº¡o Bá»Ÿi Haku X DX\nMá»ž CÃ€I Äáº¶T -> VIP MENU Äá»‚ TÃ™Y CHá»ˆNH\nHáº¡n sá»­ dá»¥ng Ä‘áº¿n: " .. formattedExpire, function() 
                            local KismetSystemLibrary = import("KismetSystemLibrary")
                            if KismetSystemLibrary then KismetSystemLibrary.LaunchURL("https://t.me/DeerXua") end
                        end, function() end, "THAM GIA", "Há»¦Y")
                    end
                end)
            end
        end

        local isAiming = self.Object.bIsWeaponAiming or false
        local isWallhackGlobalOn = (_G.TD_GetVal("WALLHACK") == 1)
        local isWhiteBodyOn = (_G.TD_GetVal("WHITE_BODY") == 1)            
        local espHit1 = (_G.TD_GetVal("ESP_HITMARK_1") == 1)
        local espHit2 = (_G.TD_GetVal("ESP_HITMARK_2") == 1)
        local espWeaponStance = (_G.TD_GetVal("ESP_WEAPON") == 1)
        local espCount = (_G.TD_GetVal("ESP_COUNT") == 1)

        local magicHead = 1.0 + (_G.TD_GetVal("MAGIC_HEAD") / 100.0)
        local magicBody = 1.0 + (_G.TD_GetVal("MAGIC_BODY") / 100.0)
        local magicLegs = 1.0 + (_G.TD_GetVal("MAGIC_LEGS") / 100.0)
        local BoneScaleMap = {
            ["head"] = magicHead, ["neck_01"] = magicHead,
            ["pelvis"] = magicBody, ["spine_01"] = magicBody, ["spine_02"] = magicBody, ["spine_03"] = magicBody,
            ["thigh_l"] = magicLegs, ["thigh_r"] = magicLegs, ["calf_l"] = magicLegs, ["calf_r"] = magicLegs, 
            ["foot_l"] = magicLegs, ["foot_r"] = magicLegs    
        }
        
        if self.TD_LastAimState ~= isAiming then
            self.TD_LastAimState = isAiming
            self.TD_ForceFOV = true
        end

        if not isAiming then
            if _G.TD_GetVal("IpadView") == 1 then
                pcall(function()
                    local targetTPP = _G.TD_GetVal("IpadViewFOV") or 120
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
            self.TD_ForceFOV = false
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
                        local crosshairScale = _G.TD_GetVal("THU_TAM") / 100.0
                        local scopeRecoilScale = _G.TD_GetVal("GIAM_RUNG_SCOPE") / 100.0
                        
                        shootWeaponEntity.GameDeviationFactor = 3.36 - (3.36 * crosshairScale)
                        
                        -- Cache original gun recoil values in global persistence table _G.TD_WeaponCache
                        _G.TD_WeaponCache = _G.TD_WeaponCache or {}
                        local objName = tostring(shootWeaponEntity)
                        local cache = _G.TD_WeaponCache[objName]
                        
                        if not cache then
                            local isInitialized = false
                            if shootWeaponEntity.RecoilInfo and (shootWeaponEntity.RecoilInfo.VerticalRecoilMin or 0.0) > 0.0 then
                                isInitialized = true
                            elseif (shootWeaponEntity.RecoilKick or 0.0) > 0.0 then
                                isInitialized = true
                            end
                            
                            if isInitialized then
                                cache = {
                                    TD_OrigRecoilKick = shootWeaponEntity.RecoilKick or 0.0,
                                    TD_OrigAccessoriesV = shootWeaponEntity.AccessoriesVRecoilFactor or 1.0,
                                    TD_OrigAccessoriesH = shootWeaponEntity.AccessoriesHRecoilFactor or 1.0,
                                    TD_OrigRecoilKickADS = shootWeaponEntity.RecoilKickADS or 0.20,
                                    TD_OrigModStand = shootWeaponEntity.RecoilModifierStand or 1.0,
                                    TD_OrigModCrouch = shootWeaponEntity.RecoilModifierCrouch or 1.0,
                                    TD_OrigModProne = shootWeaponEntity.RecoilModifierProne or 1.0
                                }
                                if shootWeaponEntity.RecoilInfo then
                                    cache.TD_OrigVRecoilMin = shootWeaponEntity.RecoilInfo.VerticalRecoilMin or 0.0
                                    cache.TD_OrigVRecoilMax = shootWeaponEntity.RecoilInfo.VerticalRecoilMax or 0.0
                                    cache.TD_OrigSpeedV = shootWeaponEntity.RecoilInfo.RecoilSpeedVertical or 0.0
                                    cache.TD_OrigSpeedH = shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal or 0.0
                                    cache.TD_OrigRecoveryMax = shootWeaponEntity.RecoilInfo.VerticalRecoveryMax or 0.0
                                end
                                _G.TD_WeaponCache[objName] = cache
                            end
                        end

if cache then
    -- ===== THÃŠM: TÃ­nh há»‡ sá»‘ giáº£m rung khi Ä‘ang ngáº¯m (ADS) =====
    local isADS = self.Object and self.Object.bIsWeaponAiming == true
    local scopeFactor = 1.0
    if isADS then
        local scopePercent = _G.TD_GetVal("GIAM_RUNG_SCOPE") or 0
        scopeFactor = 1.0 - (scopePercent / 100.0)
    end

    local recoilPercent = _G.TD_GetVal("NO_RECOIL_100") or 0
    if recoilPercent > 0 then
        -- Sá»¬A: Gá»™p scopeFactor vÃ o factor Ä‘á»ƒ Ã¡p dá»¥ng cho Táº¤T Cáº¢ thÃ´ng sá»‘ khi ADS
        -- Háº¡n cháº¿ tá»‘i thiá»ƒu lÃ  0.01 Ä‘á»ƒ trÃ¡nh chia cho 0 trong engine váº­t lÃ½ phÃ­a dÆ°á»›i
        local factor = math.max(0.01, (1.0 - (recoilPercent / 100.0)) * scopeFactor)
        
        shootWeaponEntity.RecoilKick = (cache.TD_OrigRecoilKick or 0.0) * factor
        shootWeaponEntity.AccessoriesVRecoilFactor = (cache.TD_OrigAccessoriesV or 1.0) * factor
        shootWeaponEntity.AccessoriesHRecoilFactor = (cache.TD_OrigAccessoriesH or 1.0) * factor
        -- LÆ¯U Ã: ÄÃ£ xÃ³a *(1.0 - scopeRecoilScale) cÅ© vÃ¬ scopeFactor Ä‘Ã£ Ä‘Æ°á»£c tÃ­nh gá»™p vÃ o factor phÃ­a trÃªn (trÃ¡nh bá»‹ giáº£m 2 láº§n gÃ¢y lá»—i toÃ¡n há»c)
        shootWeaponEntity.RecoilKickADS = (cache.TD_OrigRecoilKickADS or 0.20) * factor
        if shootWeaponEntity.RecoilInfo then
            shootWeaponEntity.RecoilInfo.VerticalRecoilMin = (cache.TD_OrigVRecoilMin or 0.0) * factor
            shootWeaponEntity.RecoilInfo.VerticalRecoilMax = (cache.TD_OrigVRecoilMax or 0.0) * factor
            shootWeaponEntity.RecoilInfo.RecoilSpeedVertical = (cache.TD_OrigSpeedV or 0.0) * factor
            shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal = (cache.TD_OrigSpeedH or 0.0) * factor
            shootWeaponEntity.RecoilInfo.VerticalRecoveryMax = (cache.TD_OrigRecoveryMax or 0.0) * factor
        end
        shootWeaponEntity.RecoilModifierStand = (cache.TD_OrigModStand or 1.0) * factor
        shootWeaponEntity.RecoilModifierCrouch = (cache.TD_OrigModCrouch or 1.0) * factor
        shootWeaponEntity.RecoilModifierProne = (cache.TD_OrigModProne or 1.0) * factor
    else
        -- Sá»¬A: ThÃªm scopeFactor vÃ o nhÃ¡nh else Ä‘á»ƒ slider váº«n hoáº¡t Ä‘á»™ng ngay cáº£ khi chÆ°a báº­t giáº£m giáº­t
        -- Háº¡n cháº¿ tá»‘i thiá»ƒu lÃ  0.01 Ä‘á»ƒ trÃ¡nh chia cho 0 trong engine váº­t lÃ½ phÃ­a dÆ°á»›i
        local factor = math.max(0.01, 1.0 * scopeFactor)
        
        shootWeaponEntity.RecoilKick = (cache.TD_OrigRecoilKick or 0.0) * factor
        shootWeaponEntity.AccessoriesVRecoilFactor = (cache.TD_OrigAccessoriesV or 1.0) * factor
        shootWeaponEntity.AccessoriesHRecoilFactor = (cache.TD_OrigAccessoriesH or 1.0) * factor
        -- LÆ¯U Ã: ÄÃ£ xÃ³a *(1.0 - scopeRecoilScale) cÅ© vÃ¬ Ä‘Ã£ tÃ­nh gá»™p vÃ o factor
        shootWeaponEntity.RecoilKickADS = (cache.TD_OrigRecoilKickADS or 0.20) * factor
        if shootWeaponEntity.RecoilInfo then
            shootWeaponEntity.RecoilInfo.VerticalRecoilMin = (cache.TD_OrigVRecoilMin or 0.0) * factor
            shootWeaponEntity.RecoilInfo.VerticalRecoilMax = (cache.TD_OrigVRecoilMax or 0.0) * factor
            shootWeaponEntity.RecoilInfo.RecoilSpeedVertical = (cache.TD_OrigSpeedV or 0.0) * factor
            shootWeaponEntity.RecoilInfo.RecoilSpeedHorizontal = (cache.TD_OrigSpeedH or 0.0) * factor
            shootWeaponEntity.RecoilInfo.VerticalRecoveryMax = (cache.TD_OrigRecoveryMax or 0.0) * factor
        end
        shootWeaponEntity.RecoilModifierStand = (cache.TD_OrigModStand or 1.0) * factor
        shootWeaponEntity.RecoilModifierCrouch = (cache.TD_OrigModCrouch or 1.0) * factor
        shootWeaponEntity.RecoilModifierProne = (cache.TD_OrigModProne or 1.0) * factor
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
                            if _G.TD_GetVal("AIMBOT") == 1 then
                                if shootWeaponEntity.AutoAimingConfig then
                                    local autoAimConfig = shootWeaponEntity.AutoAimingConfig
                                    local aimSpeedVal = 3.0 + (3.0 * (_G.TD_GetVal("SPEED_AIMBOT") / 100.0))
                                    local aimFovVal = 1.5 + (1.5 * (_G.TD_GetVal("FOV_AIMBOT") / 100.0))
                                    
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
     
            if not self.TD_NativeESP_Ready then
                pcall(function()
                    for k, markConfig in pairs(package.loaded) do
                        if type(k) == "string" and string_find(k, "ScreenMarkConfig") then
                            if type(markConfig) == "table" then
                                if markConfig[1006] then
                                    markConfig[1006].bBindBlocked = true     
                                    markConfig[1006].bBindOutScreen = true   
                                    markConfig[1006].MaxWidgetNum = 99
                                    markConfig[1006].MaxShowDistance = 6000000
                                    markConfig[1006].bScaleByDistance = false
                                    markConfig[1006].BindSocketName = "root"
                                    markConfig[1006].bUseLuaWorldSocketName = true
                                    markConfig[1006].WorldPositionOffset = FVector(0, 0, -30)
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
                                    enemyHpWidget.UIRoot.CanvasPanel_HPBarWidgets:SetRenderScale(FVector2D(1.5, 1.5))
                                end
                            end
                        end
                    end
                end)
                self.TD_NativeESP_Ready = true
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
                        if _G.TD_GetVal("NOGRASS") == 1 then ExecConsoleCmd("r.DisableGrassRender", "1") else ExecConsoleCmd("r.DisableGrassRender", "0") end
                        if _G.TD_GetVal("NOTREES") == 1 then
                            ExecConsoleCmd("foliage.DensityScale", "0"); ExecConsoleCmd("r.Foliage.DensityScale", "0")
                            ExecConsoleCmd("foliage.MinimumScreenSize", "10000"); ExecConsoleCmd("r.DisableTreeRender", "1")
                        else
                            ExecConsoleCmd("foliage.DensityScale", "1"); ExecConsoleCmd("r.Foliage.DensityScale", "1")
                            ExecConsoleCmd("foliage.MinimumScreenSize", "0.0001"); ExecConsoleCmd("r.DisableTreeRender", "0")
                        end
                        if _G.TD_GetVal("NOWATER") == 1 then
                            ExecConsoleCmd("r.Water.SingleLayer.Enable", "0"); ExecConsoleCmd("r.Show.Water", "0")
                            ExecConsoleCmd("r.Show.Translucency", "0"); ExecConsoleCmd("r.DisableWaterRender", "1")
                        else
                            ExecConsoleCmd("r.Water.SingleLayer.Enable", "1"); ExecConsoleCmd("r.Show.Water", "1")
                            ExecConsoleCmd("r.Show.Translucency", "1"); ExecConsoleCmd("r.DisableWaterRender", "0")
                        end
                        if _G.TD_GetVal("NOFOG") == 1 then
                            ExecConsoleCmd("r.SkyAtmosphere", "0"); ExecConsoleCmd("r.Atmosphere", "0")
                            ExecConsoleCmd("r.Fog", "0"); ExecConsoleCmd("r.VolumetricFog", "0"); ExecConsoleCmd("r.DisableSkyRender", "1")
                        else
                            ExecConsoleCmd("r.SkyAtmosphere", "1"); ExecConsoleCmd("r.Atmosphere", "1")
                            ExecConsoleCmd("r.Fog", "1"); ExecConsoleCmd("r.VolumetricFog", "1"); ExecConsoleCmd("r.DisableSkyRender", "0")
                        end
                        if _G.TD_GetVal("BLACK_SKY") == 1 then
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

            if not _G.TD_Active_Marks_Cache then _G.TD_Active_Marks_Cache = {} end

            for cacheKey, cacheData in pairs(_G.TD_Active_Marks_Cache) do
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
                    _G.TD_Active_Marks_Cache[cacheKey] = nil
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
                        if enemy.TD_IsAICached == nil then enemy.TD_IsAICached = CheckIsAI(enemy) end
                        
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
                            if enemy.TD_IsAICached then aiCount = aiCount + 1 else realCount = realCount + 1 end
                        end

                        if not enemy.TD_NextMeshUpdateTime or currentTickOS > enemy.TD_NextMeshUpdateTime then
                            enemy.TD_NextMeshUpdateTime = currentTickOS + 5.0 + (math_random() * 1.0)
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
                            enemy.TD_CachedMeshes = meshes
                        end
                        
                        local meshes = enemy.TD_CachedMeshes
                        local currentMeshCount = #meshes
                        local isMeshChanged = (enemy.LastMeshCountWall ~= currentMeshCount)
                        
                        if isWallhackGlobalOn then
                            local visColor = GetCurrentWallVisibleColor()
                            local occludedColor = GetCurrentWallOccludedColor(enemy.TD_IsAICached)
                            local colorHash = tostring(_G.TD_Settings.WALL_VISIBLE_COLOR) .. "_"
                                           .. tostring(_G.TD_Settings.WALL_OCCLUDED_COLOR) .. "_"
                                           .. tostring(_G.TD_Settings.WALL_OCCLUDED_AI_COLOR)
                            local auraHash = (enemy.TD_IsAICached and "ai" or "player") .. "_" .. colorHash
                            if isMeshChanged or enemy.LastAuraHash ~= auraHash or not enemy.WallhackApplied then
                                pcall(function()
                                    if isMeshChanged and enemy.TD_AuraMeshes then
                                        for _, mesh in ipairs(enemy.TD_AuraMeshes) do
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
                                enemy.TD_AuraMeshes = meshes
                            end
                        else
                            if enemy.WallhackApplied then
                                pcall(function()
                                    local auraMeshes = enemy.TD_AuraMeshes or meshes
                                    for _, mesh in ipairs(auraMeshes) do
                                        if Valid(mesh) then
                                            ResetMeshAuraComponent(mesh)
                                        end
                                    end
                                end)
                                enemy.WallhackApplied = false
                                enemy.LastAuraHash = nil
                                enemy.LastMeshCountWall = nil
                                enemy.TD_AuraMeshes = nil
                            end
                        end

                        local knockChanged = (enemy.TD_LastKnockState ~= isEnemyKnocked)
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
                            if _G.TD_Active_Marks_Cache[eStr] then
                                _G.TD_Active_Marks_Cache[eStr].hpMark = nil
                                _G.TD_Active_Marks_Cache[eStr].distMark = nil
                            end
                        end
                        enemy.TD_LastKnockState = isEnemyKnocked

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
                                            if not _G.TD_Active_Marks_Cache[eStr] then _G.TD_Active_Marks_Cache[eStr] = { actor = enemy } end
                                            _G.TD_Active_Marks_Cache[eStr].distMark = enemy.NativeDistMark
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
                                if _G.TD_Active_Marks_Cache[eStr] then _G.TD_Active_Marks_Cache[eStr].distMark = nil end
                            end
                        end

                        if espHit2 and not isEnemyKnocked then
                            if not enemy.bHasTDNativeHPBar then
                                pcall(function()
                                    if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
                                        enemy.NativeHPBarMark = InGameMarkTools.ClientAddMapMark(1006, FVecZero, 0, "", 4, enemy)
                                        enemy.bHasTDNativeHPBar = true
                                        local eStr = tostring(enemy)
                                        if not _G.TD_Active_Marks_Cache[eStr] then _G.TD_Active_Marks_Cache[eStr] = { actor = enemy } end
                                        _G.TD_Active_Marks_Cache[eStr].hpMark = enemy.NativeHPBarMark
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
                                if _G.TD_Active_Marks_Cache[eStr] then _G.TD_Active_Marks_Cache[eStr].hpMark = nil end
                            end
                        end

                        if espWeaponStance and Valid(MyHUD) and distM <= 400 then
                            pcall(function()
                                -- 1. Láº¥y thÃ´ng tin vÅ© khÃ­
                                if not enemy.TD_LastWeaponTime or currentTickOS > enemy.TD_LastWeaponTime + 1.5 then
                                    local eWeapon = nil
                                    if enemy.CurrentWeapon then eWeapon = enemy.CurrentWeapon
                                    elseif type(enemy.GetCurrentWeapon) == "function" then eWeapon = enemy:GetCurrentWeapon()
                                    elseif enemy.WeaponManagerComponent then eWeapon = enemy.WeaponManagerComponent.CurrentWeaponReplicated end
                                    
                                    local weaponName = "Tay KhÃ´ng"
                                    if Valid(eWeapon) and type(eWeapon.GetWeaponName) == "function" then weaponName = eWeapon:GetWeaponName() end
                                    enemy.TD_CachedWeaponName = tostring(weaponName)
                                    enemy.TD_LastWeaponTime = currentTickOS
                                end

                                -- 2. Láº¥y thÃ´ng tin Äá»™ng tÃ¡c / TÆ° tháº¿ (Stance)
                                local ESTEPoseState = import("ESTEPoseState")
                                local poseText = "Äá»©ng"
                                if enemy.PoseState == ESTEPoseState.Crouch then
                                    poseText = "Ngá»“i"
                                elseif enemy.PoseState == ESTEPoseState.Prone then
                                    poseText = "Náº±m"
                                end

                                -- GhÃ©p thÃ´ng tin hiá»ƒn thá»‹ (VÃ­ dá»¥: "M416 [Ngá»“i]")
                                local stateText = string.format("%s [%s]", enemy.TD_CachedWeaponName or "Tay KhÃ´ng", poseText)

                                -- 3. Kiá»ƒm tra Visibility (Check Vis) cÃ³ cache Ä‘á»ƒ tá»‘i Æ°u hÃ³a hiá»‡u nÄƒng
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
                                
                                -- Äá»•i mÃ u: Xanh lÃ¡ khi nhÃ¬n tháº¥y (Visible), Äá» khi bá»‹ che (Behind wall)
                                local textColor = _G.AimTouchVisCache[enemyId].hidden and COLOR_RED or COLOR_GREEN
                                
                                if _G.TD_GetVal("THREAT_ESP") == 1 and not _G.AimTouchVisCache[enemyId].hidden and enemy.bIsWeaponFiring == true then
                                    local flashOn = (math.floor(curTime * 6) % 2 == 0)
                                    textColor = flashOn and {R=255, G=0, B=0, A=255} or {R=80, G=0, B=0, A=255}
                                end

                                MyHUD:AddDebugText(stateText, enemy, 0.5, {X=0, Y=0, Z=-110}, {X=0, Y=0, Z=-110}, textColor, true, false, true, nil, dynamicScale, true)
                            end)
                        end

                        -- [Má»šI] LOGIC ESP KHUNG BOX
                        local showFrameUI = (_G.TD_GetVal("ESP_BOX") == 1 or _G.TD_GetVal("EspLoai5") == 1)
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
                                        if not _G.TD_OrigHitboxes then _G.TD_OrigHitboxes = {} end
                                        local PhysAssetName = ""
                                        pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
                                        if PhysAssetName == "" then PhysAssetName = "DefaultPhys" end
                                        
                                        if not _G.TD_OrigHitboxes[PhysAssetName] then 
                                            _G.TD_OrigHitboxes[PhysAssetName] = {} 
                                        end
                                        local OrigHitboxData = _G.TD_OrigHitboxes[PhysAssetName]

                                        if not _G.TD_ModdedPhysAssets then _G.TD_ModdedPhysAssets = {} end
                                        if _G.TD_ModdedPhysAssets[PhysAssetName] ~= _G.MagicUpdateVersion then
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
                                            _G.TD_ModdedPhysAssets[PhysAssetName] = _G.MagicUpdateVersion
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
                            local cMeshes = enemy.TD_CachedMeshes or {}
                            pcall(function()
                                local auraMeshes = enemy.TD_AuraMeshes or cMeshes
                                for _, comp in ipairs(auraMeshes) do
                                    if Valid(comp) then
                                        ResetMeshAuraComponent(comp)
                                    end
                                end
                            end)
                            enemy.WallhackApplied = false
                            enemy.LastAuraHash = nil
                            enemy.LastMeshCountWall = nil
                            enemy.TD_AuraMeshes = nil
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
                        local text = string.format("Káº» Äá»‹ch Xung Quanh: %d", totalEnemies)
                        MyHUD:AddDebugText(text, LocalPlayer, 0.5, FVecZero, FVecZero, COLOR_RED, true, false, true, nil, 0.8, true)
                    end
                end)
            end

            -- ==========================================================
            -- [LOGIC ESP BOM VVIP 7.0] - Gá»‘c & HoÃ n Háº£o (Chuáº©n Code Äáº§u)
            -- ==========================================================
            if _G.TD_GetVal("EspBomMaster") == 1 and (_G.TD_GetVal("EspItemBom") == 1 or _G.TD_GetVal("EspActiveBom") == 1) then
                pcall(function()
                    if Valid(MyHUD) then
                        if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                        if not _G.CachedActorClass_ForBomb then _G.CachedActorClass_ForBomb = import("Actor") end 
                        if not _G.CachedProjArray then _G.CachedProjArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForBomb) end
                        
                        local ui_util = require("client.common.ui_util")
                        local gameInstance = ui_util and ui_util.GetGameInstance()
                        
                        if gameInstance and _G.CachedGameplayStatics then
                            local curTime = os.clock()

                            -- QuÃ©t danh sÃ¡ch 0.5s/láº§n Ä‘á»ƒ chá»‘ng giáº­t FPS
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

                            -- HÃ€M Váº¼ CHUNG
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
                                                        displayName = isItem and "Bom DÃ­nh" or "BOM DÃNH"
                                                        bombColor = isItem and {R=255, G=105, B=180, A=255} or {R=255, G=0, B=255, A=255}
                                                    elseif bType == 2 then
                                                        displayName = isItem and "KhÃ³i" or "KHÃ“I"
                                                        bombColor = isItem and {R=200, G=200, B=200, A=255} or C_WHITE
                                                    elseif bType == 3 then
                                                        displayName = isItem and "Lá»­a" or "Lá»¬A"
                                                        bombColor = isItem and {R=255, G=160, B=50, A=255} or {R=255, G=100, B=0, A=255}
                                                    elseif bType == 4 then
                                                        displayName = isItem and "MÃ¹" or "MÃ™"
                                                        bombColor = isItem and {R=150, G=255, B=255, A=255} or C_CYAN
                                                    elseif bType == 5 then
                                                        displayName = isItem and "Äáº N KHÃ“I" or "Äáº N KHÃ“I"
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

                            if _G.TD_GetVal("EspItemBom") == 1 then DrawBombs(_G.CachedItemBombs, true, 50) end
                            if _G.TD_GetVal("EspActiveBom") == 1 then DrawBombs(_G.CachedActiveBombs, false, 150) end
                        end
                    end
                end)
            end

            -- ==========================================================
            -- [LOGIC ESP XE - VEHICLE ESP VVIP]
            -- ==========================================================
            if _G.TD_GetVal("EspVehicle") == 1 then
                pcall(function()
                    if Valid(MyHUD) then
                        if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                        if not _G.CachedActorClass_ForVehicle then _G.CachedActorClass_ForVehicle = import("STExtraVehicleBase") end 
                        if not _G.CachedVehicleArray then _G.CachedVehicleArray = slua.Array(UEnums.EPropertyClass.Object, import("Actor")) end
                        
                        local ui_util = require("client.common.ui_util")
                        local gameInstance = ui_util and ui_util.GetGameInstance()
                        
                        if gameInstance and _G.CachedGameplayStatics then
                            local curTime = os.clock()

                            -- QuÃ©t danh sÃ¡ch 1.0s/láº§n Ä‘á»ƒ chá»‘ng giáº­t FPS tuyá»‡t Ä‘á»‘i
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
                                                elseif string.find(nameLower, "boat") or string.find(nameLower, "aquarail") then displayName = "Thuyá»n"
                                                elseif string.find(nameLower, "glider") then displayName = "TÃ u lÆ°á»£n"
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
                                            if item.name == "Dacia" then isShow = (_G.TD_GetVal("EspVeh_Dacia") == 1)
                                            elseif item.name == "UAZ" then isShow = (_G.TD_GetVal("EspVeh_UAZ") == 1)
                                            elseif item.name == "Buggy" then isShow = (_G.TD_GetVal("EspVeh_Buggy") == 1)
                                            elseif item.name == "Coupe RB" then isShow = (_G.TD_GetVal("EspVeh_Coupe") == 1)
                                            elseif item.name == "Mirado" then isShow = (_G.TD_GetVal("EspVeh_Mirado") == 1)
                                            elseif item.name == "Motor" or item.name == "Scooter" then isShow = (_G.TD_GetVal("EspVeh_Motor") == 1)
                                            else isShow = (_G.TD_GetVal("EspVeh_Other") == 1) end

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
            -- [LOGIC ESP Váº¬T PHáº¨M - ITEM ESP VVIP]
            -- ==========================================================
            if _G.TD_GetVal("EspItemMaster") == 1 then
                pcall(function()
                    if Valid(MyHUD) then
                        if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                        
                        -- Nháº­p class Wrapper cá»§a váº­t pháº©m rÆ¡i dÆ°á»›i Ä‘áº¥t vá»›i cÆ¡ cháº¿ fallback vÃ  an toÃ n cao
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

                            -- QuÃ©t danh sÃ¡ch váº­t pháº©m dÆ°á»›i Ä‘áº¥t 1.0s/láº§n Ä‘á»ƒ báº£o toÃ n hiá»‡u nÄƒng FPS
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
                                                -- TrÃ­ch xuáº¥t ID váº­t pháº©m tá»« wrapper qua cáº¥u trÃºc FBattleItemData
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
                                                
                                                -- Láº¥y tÃªn váº­t pháº©m tÆ°Æ¡ng á»©ng tá»« DataTable cá»§a game náº¿u cÃ³ ID
                                                local itemName = ""
                                                if itemID then
                                                    pcall(function()
                                                        local itemCfg = CDataTable.GetTableData("Item", itemID)
                                                        if itemCfg then
                                                            itemName = itemCfg.ItemName or itemCfg.itemName or ""
                                                        end
                                                    end)
                                                end
                                                
                                                -- Tá»•ng há»£p chuá»—i Ä‘á»‹nh danh chá»¯ thÆ°á»ng
                                                local nameLower = string.lower(tostring(itemName) .. "_" .. tostring(itemID or "") .. "_" .. tostring(pickup))
                                                local matchedKeyword = nil
                                                local mapping = nil
                                                
                                                -- 1. TÃ¬m khá»›p trá»±c tiáº¿p theo ID trong báº£n Ä‘á»“ weapon map
                                                if itemID and _G.TD_WeaponMap[itemID] then
                                                    mapping = _G.TD_WeaponMap[itemID]
                                                else
                                                    -- 2. TÃ¬m khá»›p theo tá»« khoÃ¡ chuá»—i
                                                    for _, kw in ipairs(_G.TD_OrderedKeywords) do
                                                        if string.find(nameLower, kw) then
                                                            matchedKeyword = kw
                                                            break
                                                        end
                                                    end
                                                    if matchedKeyword then
                                                        mapping = _G.TD_WeaponMap[matchedKeyword]
                                                    end
                                                end
                                                
                                                if mapping then
                                                    -- Kiá»ƒm tra cáº¥u hÃ¬nh báº­t/táº¯t cá»§a danh má»¥c cha vÃ  cá»§a sÃºng con
                                                    if _G.TD_GetVal(mapping.cat) == 1 and _G.TD_GetVal(mapping.key) == 1 then
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

                            -- Thá»±c hiá»‡n váº½ text Ä‘á»‹nh vá»‹ cÃ¡c váº­t pháº©m há»£p lá»‡
                            if _G.CachedItems then
                                local maxItemDist = _G.TD_GetVal("EspItem_Dist") or 150
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
    self.TD_NativeESP_Ready = false
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
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
    BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
    if Client and GameplayData.RemoveCharacter ~= nil then
        GameplayData.RemoveCharacter(self.Object)
    end
end

-- =========================== PHáº¦N 30: CÃC HÃ€M Gá»C CÃ’N Láº I ===========================
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
    if _G.TD_GetVal("NO_LANDING_LAG") == 1 then
        -- Há»§y bá» CheckFallingDistanceComponent ngay khi sinh ra Ä‘á»ƒ trÃ¡nh Ä‘o Ä‘áº¡c khoáº£ng cÃ¡ch rÆ¡i trigger khuá»µu gá»‘i
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
    if _G.TD_GetVal("NO_LANDING_LAG") == 1 then
        -- BÆ°á»›c 2: can thiá»‡p trá»±c tiáº¿p vÃ o AnimInstance (dá»«ng má»i montage animation khá»±ng) vÃ  STCharacterMovement (reset tráº¡ng thÃ¡i rÆ¡i)
        pcall(function()
            if slua.isValid(self.Mesh) then
                local animIns = self.Mesh:GetAnimInstance()
                if slua.isValid(animIns) then
                    animIns:Montage_Stop(0.0) -- Dá»«ng má»i montage animation khá»±ng tiáº¿p Ä‘áº¥t
                end
            end
            if slua.isValid(self.STCharacterMovement) then
                local EMovementMode = import("EMovementMode")
                self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_Walking) -- Reset tráº¡ng thÃ¡i rÆ¡i vá» Ä‘i bá»™
                local velocity = self:GetVelocity()
                if velocity then
                    velocity.Z = 0 -- Triá»‡t tiÃªu váº­n tá»‘c rÆ¡i tháº³ng Ä‘á»©ng
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

-- =========================== PHáº¦N 31: INIT ALL MOD SYSTEMS ===========================
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
                LocalPlayer.TD_NativeESP_Ready = false
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

-- =========================== PHáº¦N 32: RETURN CLASS ===========================
local slua_class = require("class")
local CharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local FinalClassDecl = slua_class(CharacterBase, nil, BRPlayerCharacterBase)

return require("combine_class").DeclareFeature(FinalClassDecl, {
    { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
    { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
    { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
    { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
    { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
    { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
    { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
    { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
    { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
    { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" }
}, "BRPlayerCharacterBase")

if CBRPlayerCharacterBase then
    CBRPlayerCharacterBase.StartAdvancedSystems = BRPlayerCharacterBase.StartAdvancedSystems
    CBRPlayerCharacterBase.CheckAddCheckFallingDistanceComponent = BRPlayerCharacterBase.CheckAddCheckFallingDistanceComponent
    CBRPlayerCharacterBase.OnLanded = BRPlayerCharacterBase.OnLanded
    CBRPlayerCharacterBase.ReceiveBeginPlay = BRPlayerCharacterBase.ReceiveBeginPlay
    CBRPlayerCharacterBase.ReceiveEndPlay = BRPlayerCharacterBase.ReceiveEndPlay
    CBRPlayerCharacterBase.BPOnRecycled = BRPlayerCharacterBase.BPOnRecycled
    CBRPlayerCharacterBase.BPOnRespawned = BRPlayerCharacterBase.BPOnRespawned
    CBRPlayerCharacterBase.ReceiveOnRecycle = BRPlayerCharacterBase.ReceiveOnRecycle
    CBRPlayerCharacterBase.ReceiveOnSpawn = BRPlayerCharacterBase.ReceiveOnSpawn
    CBRPlayerCharacterBase.ResetMeshRelativeLocationAndRotation = BRPlayerCharacterBase.ResetMeshRelativeLocationAndRotation
    CBRPlayerCharacterBase.HandleOnMovementModeChangedNew = BRPlayerCharacterBase.HandleOnMovementModeChangedNew
    CBRPlayerCharacterBase.SwitchWeaponCheck = BRPlayerCharacterBase.SwitchWeaponCheck
end