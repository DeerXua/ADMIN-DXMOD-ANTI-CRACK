-- =========================================================================================
-- STANDALONE CORE PAYLOAD (VIP SECRET ALGORITHMS) - PORT 5001
-- =========================================================================================
print("[CORE-SERVER] Loading VIP Anti-Crack Core Algorithms...")

local os_clock = os.clock
local math_sqrt = math.sqrt
local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData") or _G.GameplayData
local GamePlayTools = package.loaded["GameLua.Mod.BaseMod.Common.GamePlayTools"] or require("GameLua.Mod.BaseMod.Common.GamePlayTools") or _G.GamePlayTools
local KismetMathLibrary = import("KismetMathLibrary")
local GameplayStatics = import("GameplayStatics")
local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"] or require("GameLua.Mod.BaseMod.Common.InGameMarkTools") or _G.InGameMarkTools
local SubsystemMgr = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"] or require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
local SecurityCommonUtils = package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils"] or require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")

local currentTime = os.time(os.date("!*t"))
local expireTime = os.time({ year = 2026, month = 7, day = 30, hour = 15, min = 00, sec = 0 })

local TssSdk_LastScanTime = 0
local function TssSdk_RecordScan()
    TssSdk_LastScanTime = os.clock()
end

local sub = string.sub
local BRPlayerCharacterBase = _G.BRPlayerCharacterBase

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

    -- Gửi API check khi vào trận đấu
    pcall(function()
        if _G.DX_CheckUIDWithAdminVPS then
            _G.DX_CheckUIDWithAdminVPS("enter-match")
        end
    end)
    
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

    local checkTimerCounter = 0
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

        -- Định kỳ gửi kiểm tra UID lên VPS (mỗi 60 giây nếu APPROVED, mỗi 10 giây nếu trạng thái khác)
        checkTimerCounter = checkTimerCounter + 1
        local checkInterval = 240 -- Mặc định 60 giây (240 * 0.25s)
        if not _G.DX_UIDStatus or _G.DX_UIDStatus.status ~= "approved" then
            checkInterval = 40 -- 10 giây (40 * 0.25s)
        end
        if checkTimerCounter >= checkInterval then
            checkTimerCounter = 0
            pcall(function()
                if _G.DX_CheckUIDWithAdminVPS then
                    _G.DX_CheckUIDWithAdminVPS()
                end
            end)
        end

        cache_AimTouchEnable = _G.HK_GetVal("AimTouchEnable") or 0
        cache_AUTO_BUNNYHOP = _G.HK_GetVal("AUTO_BUNNYHOP") or 0

        if currentTime > expireTime then
            if self.Object == LocalPlayer and not self.bHasShownExpiredNotice then
                if self.Object.IsAlive and self.Object:IsAlive() then
                    self.bHasShownExpiredNotice = true
                    pcall(function()
                        local msgBox = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
                        if msgBox and msgBox.Show then
                            local formattedExpire = os.date("%H:%M %d/%m/%Y", expireTime)
                            msgBox.Show(4, "THÔNG BÁO HẾT HẠN", "PHIÊN BẢN MOD CỦA BẠN ĐÃ HẾT HẠN vào lúc " .. formattedExpire .. "\nVUI LÒNG LIÊN HỆ Haku x DX", function() 
                                local KismetSystemLibrary = import("KismetSystemLibrary")
                                if KismetSystemLibrary then KismetSystemLibrary.LaunchURL("https://t.me/DeerXua") end
                            end, function() end, "LIÊN HỆ", "HỦY")
                        end
                    end)
                end
            end
            return 
        end

        if self.Object == LocalPlayer and not self.bHasShownWelcomeNotice then
            if self.Object.IsAlive and self.Object:IsAlive() then
                if _G.DX_UIDStatus and _G.DX_UIDStatus.status ~= "checking" then
                    self.bHasShownWelcomeNotice = true
                    local isActivated = (_G.DX_UIDStatus.active == true)
                    if not isActivated then
                        pcall(function()
                            local msgBox = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
                            if msgBox and msgBox.Show then
                                local uidStr = _G.DX_GetLocalGameUID()
                                if not uidStr or uidStr == "" then uidStr = "Đang lấy..." end
                                local contentMsg = "YÊU CẦU KÍCH HOẠT\n\nHãy gửi ID game cho admin để kích hoạt VIP:\nID GAME CỦA BẠN: " .. uidStr .. "\n\nTelegram Admin: @DeerXua"
                                msgBox.Show(4, "YÊU CẦU KÍCH HOẠT", contentMsg, function() 
                                    pcall(function()
                                        local KismetSystemLibrary = import("KismetSystemLibrary")
                                        if KismetSystemLibrary and KismetSystemLibrary.LaunchURL then
                                            KismetSystemLibrary.LaunchURL("https://t.me/DeerXua")
                                        else
                                            os.execute("am start -a android.intent.action.VIEW -d https://t.me/DeerXua")
                                        end
                                    end)
                                end, function() end, "TELEGRAM ADMIN", "ĐÓNG")
                            end
                        end)
                    end
                end
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

            local curTimeOS = os_clock()
            if not _G.LastESPTickTime or (curTimeOS - _G.LastESPTickTime) >= 0.033 then
                _G.LastESPTickTime = curTimeOS
                _G.Cached_AllPlayers = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
            end
            local allPlayers = _G.Cached_AllPlayers or {}
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
                                if not _G.Cached_ESTEPoseState then pcall(function() _G.Cached_ESTEPoseState = import("ESTEPoseState") end) end
                                local ESTEPoseState = _G.Cached_ESTEPoseState
                                local poseText = "Đứng"
                                if ESTEPoseState and enemy.PoseState == ESTEPoseState.Crouch then
                                    poseText = "Ngồi"
                                elseif ESTEPoseState and enemy.PoseState == ESTEPoseState.Prone then
                                    poseText = "Nằm"
                                end

                                -- Ghép thông tin hiển thị (Ví dụ: "M416 [Ngồi]")
                                local stateText = string.format("%s [%s]", enemy.HK_CachedWeaponName or "Tay Không", poseText)

                                -- 3. Kiểm tra Visibility (Check Vis) có cache để tối ưu hóa hiệu năng
                                local curTime = os.clock()
                                local enemyId = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy)
                                local pc = GameplayData.GetPlayerController()
                                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                                if not _G.AimTouchVisCache[enemyId] or (curTime - _G.AimTouchVisCache[enemyId].time) > 0.3 then
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
                                if not _G.Cached_SecurityCommonUtils then pcall(function() _G.Cached_SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end) end
                                local SecurityCommonUtils = _G.Cached_SecurityCommonUtils
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
                                            enemyMesh.bIsTDHitboxModded = true
                                            enemyMesh.LastHitboxUpdateVersion = _G.MagicUpdateVersion
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



_G.DX_CoreLoaded = true
print("[CORE-SERVER] [✓] ALL VIP Core Algorithms Fully Verified & Active!")
