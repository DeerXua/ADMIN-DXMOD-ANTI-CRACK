-- =========================== PHẦN 31: INIT ALL MOD SYSTEMS ===========================
local function InitAllModSystems()
    pcall(function()
        RunAllBypasses()
        _G.InitModMenuTab()
        StartPeriodicRehook()
        DisableHiggsBoson()
    end)

    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then 
        -- Nếu chưa load GameplayData, thử lại sau 1s
        pcall(function()
            require("common.time_ticker").AddTimerOnce(1.0, InitAllModSystems)
        end)
        return 
    end

    local initialized = false
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
            initialized = true
        end
    end)

    -- Nếu chưa có LocalPlayer (chưa vào đảo chờ/trận đấu), tiếp tục loop thử lại sau 1s
    if not initialized then
        pcall(function()
            require("common.time_ticker").AddTimerOnce(1.0, InitAllModSystems)
        end)
    end
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
