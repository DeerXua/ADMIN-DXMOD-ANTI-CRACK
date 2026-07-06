-- =========================== PHẦN 31: INIT ALL MOD SYSTEMS ===========================
local function ScheduleInitTimer(sec, fn)
    local ok = false
    pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(sec, fn)
            ok = true
        end
    end)
    if not ok and _G.SetTimer then
        pcall(function()
            _G.SetTimer(sec, fn)
            ok = true
        end)
    end
    if not ok then pcall(fn) end
end

local function AttachAdvancedSystemsToLocalPlayer()
    local okGameplay, GameplayData = pcall(function()
        return package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    end)
    if not okGameplay or not GameplayData then return false end

    local attached = false
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
                attached = true
            end
        end
    end)
    return attached
end

local function InitAllModSystems()
    if not _G.HK_InitAllModSystemsDone then
        _G.HK_InitAllModSystemsDone = true
        pcall(function()
            RunAllBypasses()
            _G.InitModMenuTab()
            StartPeriodicRehook()
            DisableHiggsBoson()
            if StartDXCheckLoop then
                StartDXCheckLoop()
            end
        end)
    end
    return AttachAdvancedSystemsToLocalPlayer()
end

local _initAttempt = 0
local function RetryInitAllModSystems()
    _initAttempt = _initAttempt + 1
    local attached = InitAllModSystems()
    if not attached and _initAttempt < 80 then
        ScheduleInitTimer(0.75, RetryInitAllModSystems)
    end
end

local function StartLocalPlayerAttachWatchdog()
    local tickCount = 0
    local function tick()
        tickCount = tickCount + 1
        pcall(AttachAdvancedSystemsToLocalPlayer)
        if tickCount < 180 then
            ScheduleInitTimer(2.0, tick)
        end
    end
    ScheduleInitTimer(2.0, tick)
end

ScheduleInitTimer(0.2, RetryInitAllModSystems)
StartLocalPlayerAttachWatchdog()

pcall(function()
    if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
        EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
            _initAttempt = 0
            ScheduleInitTimer(0.2, RetryInitAllModSystems)
            ScheduleInitTimer(1.0, function()
                pcall(AttachAdvancedSystemsToLocalPlayer)
            end)
            ScheduleInitTimer(3.0, function()
                pcall(AttachAdvancedSystemsToLocalPlayer)
            end)
        end)
    end
end)

pcall(function()
    if EventSystem and EventSystem.registEvent and EVENTTYPE_WARDROBE then
        local function refreshAttach()
            if _G.HK_GetVal and _G.HK_GetVal("UNLOCK_SKIN") == 1 then
                pcall(AttachAdvancedSystemsToLocalPlayer)
            end
        end
        if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST, refreshAttach)
        end
    end
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
