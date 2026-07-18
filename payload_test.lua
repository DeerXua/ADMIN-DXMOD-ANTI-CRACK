local OriginalClass = ...

local BRPlayerCharacterBase = OriginalClass or {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}

-- ==============================================================================
-- [PHẦN 1] CẤU HÌNH & LƯU TRỮ CÀI ĐẶT
-- ==============================================================================
local ConfigFileName = "Menu_Settings.txt"
_G.LastConfigSaveStr = ""

_G.HK_Settings = _G.HK_Settings or {
    ESP_HITMARK_1 = 0, ESP_HITMARK_2 = 0, WALLHACK = 0, WHITE_BODY = 0,
    ESP_WEAPON = 0, ESP_COUNT = 0, ESP_BOX = 0, EspLoai5 = 0,
    WeaponGlow = 0, WeaponGlowColor = 5, WeaponGlowThickness = 3,
    AIMBOT = 0, SPEED_AIMBOT = 0, FOV_AIMBOT = 0, THU_TAM = 0,
    NO_RECOIL_100 = 0, GIAM_RUNG_SCOPE = 0,
    MAGIC_HEAD = 0, MAGIC_BODY = 0, MAGIC_LEGS = 0, MAGIC_DIST = 100,
    IpadView = 0, IpadViewFOV = 120,
    NOGRASS = 0, NOTREES = 0, NOWATER = 0, NOFOG = 0, BLACK_SKY = 0,
    GHOST_MODE = 0, NO_LANDING_LAG = 0, AUTO_BUNNYHOP = 0,
    THREAT_ESP = 0, SPECTATOR_HP_BAR = 0, THREAT_ESP_WARN_LINE = 1, THREAT_ESP_FLASH = 1,
    WALL_VISIBLE_COLOR = 3, WALL_OCCLUDED_COLOR = 2, WALL_OCCLUDED_AI_COLOR = 7,
    EspBomMaster = 0, EspItemBom = 0, EspActiveBom = 0, EspVehicle = 0,
    EspItemMaster = 0, EspItem_Dist = 150,
    AimTouchEnable = 0, AimTouchHipfire = 0, AimTouchScopeAll = 0,
    ModSkin = 0, UnlockWardrobe = 0,
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

local function GetConfigPaths(fileName)
    local paths = {}
    pcall(function()
        local S = import("KismetSystemLibrary")
        local platform = "Android"
        if S and S.GetPlatformName then platform = tostring(S.GetPlatformName()) end
        
        if platform == "Windows" then
            table.insert(paths, fileName)
        else
            table.insert(paths, "/sdcard/" .. fileName)
            table.insert(paths, "Menu_Settings.txt")
        end
    end)
    if #paths == 0 then table.insert(paths, fileName) end
    return paths
end

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

_G.HK_GetVal = function(id)
    return _G.HK_Settings[id] or 0
end

-- ==============================================================================
-- [PHẦN 2] MENU TAB TRONG CÀI ĐẶT
-- ==============================================================================
function _G.InitModMenuTab()
    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then LocUtil = require("client.common.LocUtil") end

    if LocUtil and not LocUtil._IsModMenuHooked then
        local old_get = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and string.sub(id, 1, 8) == "ModMenu_" then
                return string.sub(id, 9)
            end
            if old_get then return old_get(id) end
            return id
        end
        LocUtil._IsModMenuHooked = true
    end

    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    if not SettingPageDefine.ModMenu then
        local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
        local AliasMap = require("client.logic.NewSetting.Item.AliasMap") or require("client.slua.umg.NewSetting.Item.AliasMap")

        local function AddSlider(stack, key, text, minVal, maxVal)
            local item = {
                Key = "ModMenu_" .. key,
                UI = AliasMap.Slider,
                Text = text,
                MinValue = minVal, MaxValue = maxVal, Min = minVal, Max = maxVal,
                GetFunc = function() return _G.HK_Settings[key] or minVal end,
                SetFunc = function(_, value)
                    local val = math.floor(tonumber(value) or minVal)
                    if val < minVal then val = minVal end
                    if val > maxVal then val = maxVal end
                    _G.HK_Settings[key] = val
                    return true
                end
            }
            table.insert(stack, item)
        end

        local function AddSwitcher(stack, key, text)
            local item = {
                Key = "ModMenu_" .. key,
                UI = AliasMap.Switcher,
                Text = text,
                GetFunc = function() return _G.HK_Settings[key] == 1 end,
                SetFunc = function(_, value)
                    _G.HK_Settings[key] = value and 1 or 0
                    return true
                end
            }
            table.insert(stack, item)
        end

        -- Stack ESP (AURA)
        local StackESP = { { UI = AliasMap.Title, Text = "HỆ THỐNG AN TOÀN" } }
        AddSwitcher(StackESP, "WALLHACK", "▶ BẬT/TẮT ESP WALLHACK")

        -- Stack Skin
        local StackSkin = { { UI = AliasMap.Title, Text = "HỆ THỐNG SKIN CHANGER" } }
        AddSwitcher(StackSkin, "ModSkin", "▶ BẬT/TẮT MOD SKIN")

        -- Stack Skin Unlock
        local StackSkinUnlock = { { UI = AliasMap.Title, Text = "MỞ KHÓA SKIN TRẬN ĐẤU" } }
        AddSwitcher(StackSkinUnlock, "SkinUnlockAll", "▶ BẬT/TẮT UNLOCK ALL SKIN (TRẬN)")

        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            loc = "DX-MODS", text = "DX-MODS", Text = "DX-MODS", title = "DX-MODS", Title = "DX-MODS",
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "ModMenu_Cat1", loc = "AURA", text = "AURA", Text = "AURA", title = "AURA", Title = "AURA", Stack = StackESP },
                { Key = "ModMenu_CatSkin", loc = "SKIN", text = "SKIN", Text = "SKIN", title = "SKIN", Title = "SKIN", Stack = StackSkin },
                { Key = "ModMenu_CatSkinUnlock", loc = "UNLOCK SKIN", text = "UNLOCK SKIN", Text = "UNLOCK SKIN", title = "UNLOCK SKIN", Title = "UNLOCK SKIN", Stack = StackSkinUnlock }
            }
        }
        table.insert(SettingCatalog, 1, SettingPageDefine.ModMenu)
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local uiName = type(config) == "string" and config or (type(config) == "table" and config.uiname)
            if uiName == "SettingUI" then
                pcall(_G.InitModMenuTab)
            end
            if old_ShowUI then return old_ShowUI(config, unpack(args)) end
        end
        UIManager._IsModMenuHooked = true
    end
end

pcall(_G.InitModMenuTab)

pcall(function()
    local UIManager = _G.UIManager
    if UIManager and UIManager.ShowUI then
        pcall(_G.InitModMenuTab)
    end
end)

-- ==============================================================================
-- [PHẦN 3] INJECT TO ORIGINAL CLASS
-- ==============================================================================
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
