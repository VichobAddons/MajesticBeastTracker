------------------------------------------------------
-- MajesticBeastTracker - Multi-Character Lure Cooldown Tracker
-- Tracks Majestic Lure beast kill cooldowns (daily reset)
-- Kill detection via LOOT_OPENED (CLEU removed in Midnight 12.0)
------------------------------------------------------

local addonName, ns = ...

-- Lure data: ordered by Talented Tracker unlock threshold
local LURES = {
    { npcID = 245688, itemID = 238652, recipeID = 1225943, name = "Eversong",    color = "|cff00ff96", colorRGB = {0, 1, 0.59},       requiredPoints = 1,  waypoint = { map = 2395, x = 0.4195, y = 0.8005 } },  -- Gloomclaw
    { npcID = 245699, itemID = 238653, recipeID = 1225944, name = "Zul'Aman",    color = "|cff00ccff", colorRGB = {0, 0.8, 1},        requiredPoints = 10, waypoint = { map = 2437, x = 0.4769, y = 0.5325 } },  -- Silverscale
    { npcID = 245690, itemID = 238654, recipeID = 1225945, name = "Harandar",    color = "|cffff9900", colorRGB = {1, 0.6, 0},        requiredPoints = 20, waypoint = { map = 2413, x = 0.6628, y = 0.4791 } },  -- Lumenfin
    { npcID = 247096, itemID = 238655, recipeID = 1225946, name = "Voidstorm",   color = "|cffa335ee", colorRGB = {0.64, 0.21, 0.93}, requiredPoints = 30, waypoint = { map = 2405, x = 0.5460, y = 0.6580 } },  -- Umbrafang
    { npcID = 247101, itemID = 238656, recipeID = 1225948, name = "Grand Beast", color = "|cffff3333", colorRGB = {1, 0.2, 0.2},      requiredPoints = 40, waypoint = { map = 2405, x = 0.4325, y = 0.8275 } },  -- Netherscythe
}
ns.LURES = LURES

-- Fast lookup: npcID -> lure index
local npcToIndex = {}
for i, lure in ipairs(LURES) do
    npcToIndex[lure.npcID] = i
end

local charKey
local MIDNIGHT_SKINNING_SKILL_LINE = 2917

-- Debug buffer for Mechanic console integration
ns.debugBuffer = {}

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("LOOT_OPENED")

------------------------------------------------------
-- Helpers
------------------------------------------------------

local function GetCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

local function GetClassColor(class)
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    return "|cffffffff"
end

local function FormatTimeLeft(seconds)
    if seconds <= 0 then return "|cff00ff00READY|r" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then
        return string.format("|cffff3333%dh %dm|r", h, m)
    else
        return string.format("|cffff9900%dm|r", m)
    end
end

local function GetLastDailyReset()
    local secondsUntil = C_DateAndTime.GetSecondsUntilDailyReset()
    return GetServerTime() + secondsUntil - 86400
end

local function IsLureReady(timestamp)
    if not timestamp then return false end
    return timestamp < GetLastDailyReset()
end

local function GetLureTimeRemaining(timestamp)
    if not timestamp then return 0 end
    if timestamp < GetLastDailyReset() then return 0 end
    return C_DateAndTime.GetSecondsUntilDailyReset()
end

local function GetLureStatus(timestamp)
    if not timestamp then
        return "|cffffff00???|r"
    elseif IsLureReady(timestamp) then
        return "|cff00ff00READY|r"
    else
        return FormatTimeLeft(GetLureTimeRemaining(timestamp))
    end
end

-- Returns: true (has skinning), false (no skinning), nil (API not ready)
local function HasSkinning()
    local prof1, prof2 = GetProfessions()
    if not prof1 and not prof2 then return nil end -- API may not be ready
    if prof1 then
        local _, _, _, _, _, _, skillLineID = GetProfessionInfo(prof1)
        if skillLineID == 393 then return true end
    end
    if prof2 then
        local _, _, _, _, _, _, skillLineID = GetProfessionInfo(prof2)
        if skillLineID == 393 then return true end
    end
    return false
end

------------------------------------------------------
-- Talented Tracker auto-detection
------------------------------------------------------

local function GetInvestedPointsForTree(configID, rootNodeID)
    local todo = { rootNodeID }
    local totalPoints = 0
    while #todo > 0 do
        local nodeID = table.remove(todo)
        local children = C_ProfSpecs.GetChildrenForPath(nodeID)
        if children then
            for _, childID in ipairs(children) do
                table.insert(todo, childID)
            end
        end
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        if info and info.activeRank and info.activeRank > 0 then
            totalPoints = totalPoints + info.activeRank
        end
    end
    return totalPoints
end

local function DetectTalentedTrackerPoints()
    if not HasSkinning() then return 0 end
    if not C_ProfSpecs then return 0 end

    local ok, configID = pcall(C_ProfSpecs.GetConfigIDForSkillLine, MIDNIGHT_SKINNING_SKILL_LINE)
    if not ok or not configID or configID == 0 then return 0 end

    local ok2, tabIDs = pcall(C_ProfSpecs.GetSpecTabIDsForSkillLine, MIDNIGHT_SKINNING_SKILL_LINE)
    if not ok2 or not tabIDs then return 0 end

    for _, tabID in ipairs(tabIDs) do
        local ok3, tabInfo = pcall(C_ProfSpecs.GetTabInfo, tabID)
        if ok3 and tabInfo and tabInfo.name then
            if tabInfo.name:lower():find("tracker") then
                return GetInvestedPointsForTree(configID, tabInfo.rootNodeID)
            end
        end
    end

    return 0
end

-- Namespace exports for UI.lua
ns.IsLureReady = IsLureReady
ns.GetLureTimeRemaining = GetLureTimeRemaining
ns.FormatTimeLeft = FormatTimeLeft
ns.GetLureStatus = GetLureStatus
ns.GetCharKey = GetCharKey
ns.GetClassColor = GetClassColor

------------------------------------------------------
-- Core functions
------------------------------------------------------

local SETTINGS_DEFAULTS = {
    showFrame = true,
    locked = false,
    showMinimap = true,
    autoCraft = true,
    windowScale = 1.0,
    minimap = { hide = false },
}

local function EnsureDB()
    if not MajesticBeastTrackerDB then MajesticBeastTrackerDB = {} end
    if not MajesticBeastTrackerDB.chars then MajesticBeastTrackerDB.chars = {} end
    if not MajesticBeastTrackerDB.settings then MajesticBeastTrackerDB.settings = {} end
    for k, v in pairs(SETTINGS_DEFAULTS) do
        if MajesticBeastTrackerDB.settings[k] == nil then
            if type(v) == "table" then
                MajesticBeastTrackerDB.settings[k] = {}
                for k2, v2 in pairs(v) do
                    MajesticBeastTrackerDB.settings[k][k2] = v2
                end
            else
                MajesticBeastTrackerDB.settings[k] = v
            end
        end
    end
end
ns.EnsureDB = EnsureDB

local function EnsureChar(key)
    EnsureDB()
    if not MajesticBeastTrackerDB.chars[key] then
        local _, class = UnitClass("player")
        MajesticBeastTrackerDB.chars[key] = {
            class = class,
            lures = {},
            hasSkinning = false,
            talentPoints = 0,
        }
    end
    if MajesticBeastTrackerDB.chars[key].hasSkinning == nil then
        MajesticBeastTrackerDB.chars[key].hasSkinning = false
    end
    if not MajesticBeastTrackerDB.chars[key].talentPoints then
        MajesticBeastTrackerDB.chars[key].talentPoints = 0
    end
end

local function RecordLureKill(index)
    EnsureChar(charKey)
    local charData = MajesticBeastTrackerDB.chars[charKey]
    charData.lures[LURES[index].name] = GetServerTime()
    local _, class = UnitClass("player")
    charData.class = class
    local requiredForThisKill = LURES[index].requiredPoints
    if requiredForThisKill > charData.talentPoints then
        charData.talentPoints = requiredForThisKill
    end
    charData.hasSkinning = true
    local lure = LURES[index]
    print("|cff3FC7EB[MBT]|r " .. lure.color .. lure.name .. "|r beast killed! Cooldown tracked.")
end

-- Detect skinning profession gear using C_TradeSkillUI.GetProfessionSlots
-- Returns the actual inventory slot IDs for the skinning profession
local function DetectSkinningGear()
    local prof1, prof2 = GetProfessions()
    local skinningProfID = nil  -- the profession enum/ID for GetProfessionSlots
    if prof1 then
        local name, _, _, _, _, _, skillLineID, _, _, _, _, profID = GetProfessionInfo(prof1)
        if skillLineID == 393 then skinningProfID = profID or Enum.Profession.Skinning end
    end
    if not skinningProfID and prof2 then
        local name, _, _, _, _, _, skillLineID, _, _, _, _, profID = GetProfessionInfo(prof2)
        if skillLineID == 393 then skinningProfID = profID or Enum.Profession.Skinning end
    end
    if not skinningProfID then return nil end

    -- Get the actual slot IDs for this profession
    local ok, slots = pcall(C_TradeSkillUI.GetProfessionSlots, skinningProfID)
    if not ok or not slots or #slots == 0 then
        -- Fallback: try Enum.Profession.Skinning directly
        ok, slots = pcall(C_TradeSkillUI.GetProfessionSlots, Enum.Profession.Skinning)
        if not ok or not slots or #slots == 0 then return nil end
    end

    local gear = {}
    for idx, slotID in ipairs(slots) do
        local itemID = GetInventoryItemID("player", slotID)
        if itemID then
            local itemName = C_Item.GetItemNameByID(itemID)
            local itemLink = GetInventoryItemLink("player", slotID)
            local icon = C_Item.GetItemIconByID(itemID)
            gear[#gear + 1] = {
                slotID = slotID,
                itemID = itemID,
                name = itemName or "",
                link = itemLink or "",
                icon = icon,
                slotType = idx == 1 and "tool" or "accessory",
            }
        end
    end
    return gear
end

local function DetectSkinningAndTalent()
    EnsureChar(charKey)
    local charData = MajesticBeastTrackerDB.chars[charKey]
    local skinning = HasSkinning()
    if skinning == true then
        charData.hasSkinning = true
        local points = DetectTalentedTrackerPoints()
        if points > 0 then
            charData.talentPoints = points
        end
        -- Save profession gear
        local gear = DetectSkinningGear()
        if gear then
            charData.gear = gear
        end
    elseif skinning == false then
        -- API confirmed no skinning, safe to clear
        charData.hasSkinning = false
        charData.talentPoints = 0
        charData.gear = nil
    end
    -- skinning == nil: API not ready, keep existing data
end

function ns.CanSeeLure(charData, lureIndex)
    if not charData.hasSkinning then return false end
    if not charData.talentPoints or charData.talentPoints <= 0 then return false end
    return charData.talentPoints >= LURES[lureIndex].requiredPoints
end

------------------------------------------------------
-- Skinning detection via LOOT_OPENED (Midnight 12.0)
-- When you skin a beast, loot window opens with target = the beast
------------------------------------------------------

local function GetNpcIDFromGUID(guid)
    if not guid then return nil end
    local npcID = select(6, strsplit("-", guid))
    return tonumber(npcID)
end

------------------------------------------------------
-- Event handler
------------------------------------------------------

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        charKey = GetCharKey()
        EnsureChar(charKey)
        local _, class = UnitClass("player")
        MajesticBeastTrackerDB.chars[charKey].class = class
        DetectSkinningAndTalent()
        C_Timer.After(5, function()
            DetectSkinningAndTalent()
            if ns.UpdateUI then ns.UpdateUI() end
        end)
        C_Timer.NewTicker(60, function()
            local before = MajesticBeastTrackerDB.chars[charKey] and MajesticBeastTrackerDB.chars[charKey].talentPoints or 0
            DetectSkinningAndTalent()
            local after = MajesticBeastTrackerDB.chars[charKey] and MajesticBeastTrackerDB.chars[charKey].talentPoints or 0
            if before ~= after and ns.UpdateUI then ns.UpdateUI() end
        end)
        -- MechanicLib integration
        local MechanicLib = LibStub and LibStub("MechanicLib-1.0", true)
        if MechanicLib then
            MechanicLib:Register(addonName, {
                version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "0.1",
                getDebugBuffer = function() return ns.debugBuffer end,
                clearDebugBuffer = function() wipe(ns.debugBuffer) end,
            })
        end

        print("|cff3FC7EB[MBT]|r Loaded! |cffffff00/mbt help|r for commands")

    elseif event == "LOOT_OPENED" then
        local targetGUID = UnitGUID("target")
        local npcID = GetNpcIDFromGUID(targetGUID)
        if npcID and npcToIndex[npcID] then
            RecordLureKill(npcToIndex[npcID])
            if ns.UpdateUI then ns.UpdateUI() end
        end
    end
end)

------------------------------------------------------
-- Slash commands
------------------------------------------------------

SLASH_MAJESTICBEASTTRACKER1 = "/mbt"
SLASH_MAJESTICBEASTTRACKER2 = "/beast"
SLASH_MAJESTICBEASTTRACKER3 = "/lure"
SlashCmdList["MAJESTICBEASTTRACKER"] = function(msg)
    msg = msg:lower():trim()
    if msg == "" or msg == "ui" or msg == "show" then
        if ns.ShowFrame then ns.ShowFrame() end
    elseif msg == "hide" then
        if ns.HideFrame then ns.HideFrame() end
    elseif msg == "lock" then
        if ns.ToggleLock then ns.ToggleLock() end
    elseif msg == "nuke all" then
        MajesticBeastTrackerDB = { chars = {}, settings = MajesticBeastTrackerDB.settings or {} }
        EnsureChar(charKey)
        DetectSkinningAndTalent()
        print("|cff3FC7EB[MBT]|r ALL data cleared.")
        if ns.UpdateUI then ns.UpdateUI() end
    elseif msg == "nuke" then
        EnsureChar(charKey)
        MajesticBeastTrackerDB.chars[charKey].lures = {}
        print("|cff3FC7EB[MBT]|r " .. charKey .. " data cleared.")
        if ns.UpdateUI then ns.UpdateUI() end
    elseif msg:find("^talent ") then
        local points = tonumber(msg:match("^talent (%d+)"))
        if points and points >= 0 and points <= 40 then
            EnsureChar(charKey)
            MajesticBeastTrackerDB.chars[charKey].talentPoints = points
            if points > 0 then
                MajesticBeastTrackerDB.chars[charKey].hasSkinning = true
            end
            print("|cff3FC7EB[MBT]|r Talented Tracker set to " .. points .. " points.")
            if ns.UpdateUI then ns.UpdateUI() end
        else
            print("|cff3FC7EB[MBT]|r Usage: /mbt talent 0-40")
        end
    elseif msg:find("^remove ") then
        local target = msg:gsub("^remove ", ""):trim()
        EnsureDB()
        local found = nil
        for key, _ in pairs(MajesticBeastTrackerDB.chars) do
            if key:lower() == target:lower() then
                found = key
                break
            end
        end
        if found then
            MajesticBeastTrackerDB.chars[found] = nil
            print("|cff3FC7EB[MBT]|r Removed " .. found)
            if ns.UpdateUI then ns.UpdateUI() end
        else
            print("|cff3FC7EB[MBT]|r Character not found: " .. target)
        end
    elseif msg == "settings" or msg == "config" or msg == "options" then
        if ns.OpenSettings then ns.OpenSettings() end
    elseif msg == "help" or msg == "?" then
        print("|cff3FC7EB[MBT]|r === Commands ===")
        print("  |cffffff00/mbt|r - Show tracker frame")
        print("  |cffffff00/mbt hide|r - Hide tracker frame")
        print("  |cffffff00/mbt lock|r - Toggle frame lock")
        print("  |cffffff00/mbt settings|r - Open settings")
        print("  |cffffff00/mbt talent N|r - Override points (0-40)")
        print("  |cffffff00/mbt remove Name-Realm|r - Remove character")
        print("  |cffffff00/mbt help|r - This help")
    else
        if ns.ShowFrame then ns.ShowFrame() end
    end
end
