------------------------------------------------------
-- MajesticBeastTracker UI - Visual tracker
-- PSL-inspired style with BackdropTemplate
------------------------------------------------------

local addonName, ns = ...
local LURES = ns.LURES

-- Layout
local ICON_SIZE = 26
local COL_WIDTH = 62
local NAME_COL_WIDTH = 150
local ROW_HEIGHT = 18
local TITLE_HEIGHT = 22
local ZONE_LABEL_HEIGHT = 10
local ICON_ROW_HEIGHT = ICON_SIZE + 6 + ZONE_LABEL_HEIGHT
local REAGENT_ICON_SIZE = 20
local REAGENT_COUNT_HEIGHT = 10
local REAGENT_GAP = 8
local REAGENT_ROW_HEIGHT = REAGENT_ICON_SIZE + REAGENT_COUNT_HEIGHT + 4
local PAD = 8

-- Consumables to track (test with Holiday Cheesewheel)
local CONSUMABLES = {
    { itemID = 242299, name = "Sanguithorn Tea", buffName = "Relaxed", itemName = "Sanguithorn Tea", minLevel = 80 },
    { itemID = 241317, name = "Haranir Phial of Perception", buffName = "Haranir Phial of Perception", spellID = 1236763, itemName = "Haranir Phial of Perception", minLevel = 81 },
    { itemID = 238367, name = "Root Crab", buffName = "Midnight Perception", spellID = 1235216, itemName = "Root Crab", minLevel = 80, stackable = true },
}
local NUM_EXTRA_COLS = #CONSUMABLES

-- Travel items (shown at bottom of frame)
local TRAVEL_ITEMS = {
    { itemID = 6948, name = "Hearthstone" },
    { itemID = 253629, name = "Personal Key to the Arcantina", isToy = true },
}
-- Wormhole Generator: conditional on Engineering profession + item in bags
local WORMHOLE_ITEM = { itemID = 248485, name = "Wormhole Generator: Quel'Thalas", spellID = 1229928, requiresEngineering = true, isToy = true }
local TRAVEL_ICON_SIZE = 22
local TRAVEL_SPACING = 3
local TRAVEL_ROW_HEIGHT = TRAVEL_ICON_SIZE + 8

-- Colors
local C_ACCENT = CreateColor(0.25, 0.78, 0.92)
local C_BORDER_RGB = { 0.25, 0.78, 0.92 }
local C_ROW_ALT = { 0.1, 0.1, 0.14, 0.4 }
local C_SEPARATOR = { 0.25, 0.78, 0.92, 0.3 }

local BACKDROP = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

------------------------------------------------------
-- Helpers
------------------------------------------------------

-- Calculate how many times a recipe can be crafted with current reagents
function ns.GetCraftableCount(recipeID)
    if not recipeID then return 0 end
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok then return 0 end
    if not schematic or not schematic.reagentSlotSchematics then return 0 end

    local minCrafts = math.huge
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required then
            local needed = slot.quantityRequired
            if not needed or needed <= 0 then
                if slot.GetQuantityRequired then
                    needed = slot:GetQuantityRequired()
                end
                if not needed or needed <= 0 then needed = 1 end
            end
            local have = 0
            for _, reagent in ipairs(slot.reagents) do
                if reagent.itemID then
                    -- Try item name first (counts all quality variants), fallback to ID
                    local itemName = C_Item.GetItemNameByID(reagent.itemID)
                    local count = 0
                    if itemName then
                        count = C_Item.GetItemCount(itemName, true, false, true, true)
                    else
                        count = C_Item.GetItemCount(reagent.itemID, true, false, true, true)
                    end
                    have = have + count
                end
            end
            minCrafts = math.min(minCrafts, math.floor(have / needed))
        end
    end
    return minCrafts == math.huge and 0 or minCrafts
end

------------------------------------------------------
-- Main Frame
------------------------------------------------------

local frame = CreateFrame("Frame", "MajesticBeastTrackerFrame", UIParent, "BackdropTemplate")
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetFrameStrata("MEDIUM")
frame:SetFrameLevel(200)
frame:SetBackdrop(BACKDROP)
frame:SetBackdropColor(0, 0, 0, 0.95)
frame:SetBackdropBorderColor(unpack(C_BORDER_RGB))
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

-- Drag
frame:SetScript("OnDragStart", function(self)
    ns.EnsureDB()
    if not MajesticBeastTrackerDB.settings.locked then
        self:StartMoving()
    end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    MajesticBeastTrackerDB.settings.framePosition = { point, "UIParent", relPoint, x, y }
end)

-- Logout button (left of close button)
local logoutBtn = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
logoutBtn:SetHeight(16)
logoutBtn:SetAttribute("type", "macro")
logoutBtn:SetAttribute("macrotext", "/logout")
logoutBtn:RegisterForClicks("AnyUp", "AnyDown")
local logoutText = logoutBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
logoutText:SetFont(logoutText:GetFont(), 9)
logoutText:SetText("|cff999999Logout|r")
logoutText:SetPoint("CENTER")
logoutBtn:SetWidth(logoutText:GetStringWidth() + 8)
logoutBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 4)
logoutBtn:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight")
logoutBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
    GameTooltip:AddLine("Logout", 1, 1, 1)
    GameTooltip:AddLine("Switch character quickly", 0.5, 0.8, 1)
    GameTooltip:Show()
end)
logoutBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Close button (native)
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function()
    ns.HideFrame()
end)

-- Title (branding, fills empty space left of lure icons)
local titleFrame = CreateFrame("Frame", nil, frame)
titleFrame:SetAllPoints()
titleFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
titleFrame:EnableMouse(false)

local title = titleFrame:CreateFontString(nil, "OVERLAY")
title:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
title:SetText("|cff3FC7EBMajestic|r\n|cff3FC7EBBeast|r\n|cff3FC7EBTracker|r")
title:SetJustifyH("CENTER")
title:SetJustifyV("TOP")
title:SetSpacing(0)
title:SetAlpha(0.6)

local verLabel = titleFrame:CreateFontString(nil, "OVERLAY")
verLabel:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
verLabel:SetTextColor(0.5, 0.5, 0.5, 0.6)
verLabel:SetPoint("TOP", title, "BOTTOM", 0, -2)
verLabel:SetText("v" .. (C_AddOns.GetAddOnMetadata("MajesticBeastTracker", "Version") or C_AddOns.GetAddOnMetadata("MajesticBeastTrackerDev", "Version") or ""))

-- Lock indicator
local lockIcon = frame:CreateTexture(nil, "OVERLAY")
lockIcon:SetSize(10, 10)
lockIcon:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
lockIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
lockIcon:SetVertexColor(0.6, 0.6, 0.6)
lockIcon:Hide()

-- Toggle fish button (show/hide reagent icons)
local fishBtn = CreateFrame("Button", nil, frame)
fishBtn:SetSize(14, 14)
fishBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
local fishIcon = fishBtn:CreateTexture(nil, "ARTWORK")
fishIcon:SetAllPoints()
fishIcon:SetTexture("Interface\\Icons\\INV_Misc_Fish_02")
fishIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
fishBtn.icon = fishIcon
fishBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
    local shown = MajesticBeastTrackerDB.settings.showReagents ~= false
    GameTooltip:AddLine(shown and "Hide Reagents" or "Show Reagents", 1, 1, 1)
    GameTooltip:Show()
end)
fishBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
fishBtn:SetScript("OnClick", function()
    local settings = MajesticBeastTrackerDB.settings
    if settings.showReagents == nil then settings.showReagents = true end
    settings.showReagents = not settings.showReagents
    ns.UpdateUI()
end)

-- Global loot summary button (goblin icon)
local globalGoblinBtn = CreateFrame("Button", nil, frame)
globalGoblinBtn:SetSize(14, 14)
globalGoblinBtn:SetPoint("RIGHT", fishBtn, "LEFT", -20, 0)
local globalGoblinIcon = globalGoblinBtn:CreateTexture(nil, "ARTWORK")
globalGoblinIcon:SetAllPoints()
globalGoblinIcon:SetTexture("Interface\\Icons\\Achievement_GoblinHead")
globalGoblinIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
globalGoblinBtn.icon = globalGoblinIcon
globalGoblinBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
    GameTooltip:AddLine("Loot Summary (All Characters)", 0.25, 0.78, 0.92)
    local resetLoot, allTimeLoot, globalPrices = ns.GetGlobalLoot()
    ns.AddLootTooltipLines(resetLoot, "This Reset", globalPrices)
    ns.AddLootTooltipLines(allTimeLoot, "All Time", globalPrices)
    if not resetLoot and not allTimeLoot then
        GameTooltip:AddLine("No loot data yet", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end)
globalGoblinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Warband Bank deposit button (bank icon, only visible when bank is open)
local warbankBtn = CreateFrame("Button", nil, frame)
warbankBtn:SetSize(14, 14)
warbankBtn:SetPoint("RIGHT", globalGoblinBtn, "LEFT", -4, 0)
local warbankIcon = warbankBtn:CreateTexture(nil, "ARTWORK")
warbankIcon:SetAllPoints()
warbankIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_34")
warbankIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
warbankBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
    GameTooltip:AddLine("Deposit Reagents to Warband Bank", 0.25, 0.78, 0.92)
    GameTooltip:AddLine("Click to deposit all tracked skinning reagents.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
warbankBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
warbankBtn:SetScript("OnClick", function()
    ns.DepositTrackedToWarbank()
end)
warbankBtn:Hide()

-- Toggle TSM prices button (coin icon)
local coinBtn = CreateFrame("Button", nil, frame)
coinBtn:SetSize(14, 14)
coinBtn:SetPoint("RIGHT", fishBtn, "LEFT", -2, 0)
local coinIcon = coinBtn:CreateTexture(nil, "ARTWORK")
coinIcon:SetAllPoints()
coinIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
coinIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
coinBtn.icon = coinIcon
coinBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
    local enabled = MajesticBeastTrackerDB.settings.tsmIntegration
    if not TSM_API then
        GameTooltip:AddLine("TSM not installed", 0.5, 0.5, 0.5)
    else
        GameTooltip:AddLine(enabled and "Hide TSM Prices" or "Show TSM Prices", 1, 1, 1)
    end
    GameTooltip:Show()
end)
coinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
coinBtn:SetScript("OnClick", function()
    if not TSM_API then return end
    local settings = MajesticBeastTrackerDB.settings
    settings.tsmIntegration = not settings.tsmIntegration
    ns.UpdateUI()
end)

------------------------------------------------------
-- Content area
------------------------------------------------------

local contentTop = -(TITLE_HEIGHT + 2)

-- Header icons (lures) - SecureActionButton for item use
local headerIcons = {}
for i, lure in ipairs(LURES) do
    local iconFrame = CreateFrame("Button", "MBT_LureIcon" .. i, frame, "SecureActionButtonTemplate")
    iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    iconFrame:SetPoint("TOPLEFT", frame, "TOPLEFT",
        PAD + 4 + NAME_COL_WIDTH + (i - 1) * COL_WIDTH + (COL_WIDTH - ICON_SIZE) / 2,
        contentTop - 2 - REAGENT_ROW_HEIGHT)
    iconFrame:SetAttribute("type", "item")
    iconFrame:SetAttribute("item", lure.name)
    iconFrame:RegisterForClicks("AnyUp", "AnyDown")
    -- Cache item name async
    C_Item.RequestLoadItemDataByID(lure.itemID)
    local lureTicker
    lureTicker = C_Timer.NewTicker(1, function()
        local itemName = C_Item.GetItemNameByID(lure.itemID)
        if itemName and not InCombatLockdown() then
            iconFrame:SetAttribute("item", itemName)
            lureTicker:Cancel()
        end
    end, 10)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconFrame.icon = icon

    -- Lure count text (bottom-right corner of icon)
    local countText = iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    countText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 1)
    countText:SetJustifyH("RIGHT")
    countText:SetText("")
    iconFrame.countText = countText

    -- Glow border (yellow when lure in bags + usable)
    local glowSize = 2
    local glowColor = {1, 0.75, 0, 0.9}
    local gT = iconFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    gT:SetPoint("TOPLEFT", icon, "TOPLEFT", -glowSize, glowSize)
    gT:SetPoint("TOPRIGHT", icon, "TOPRIGHT", glowSize, glowSize)
    gT:SetHeight(glowSize)
    gT:SetColorTexture(unpack(glowColor))
    local gB = iconFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    gB:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -glowSize, -glowSize)
    gB:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", glowSize, -glowSize)
    gB:SetHeight(glowSize)
    gB:SetColorTexture(unpack(glowColor))
    local gL = iconFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    gL:SetPoint("TOPLEFT", icon, "TOPLEFT", -glowSize, glowSize)
    gL:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -glowSize, -glowSize)
    gL:SetWidth(glowSize)
    gL:SetColorTexture(unpack(glowColor))
    local gR = iconFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    gR:SetPoint("TOPRIGHT", icon, "TOPRIGHT", glowSize, glowSize)
    gR:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", glowSize, -glowSize)
    gR:SetWidth(glowSize)
    gR:SetColorTexture(unpack(glowColor))
    local lureGlowParts = {gT, gB, gL, gR}
    for _, g in ipairs(lureGlowParts) do g:Hide() end
    iconFrame.glow = {
        Show = function() for _, g in ipairs(lureGlowParts) do g:Show() end end,
        Hide = function() for _, g in ipairs(lureGlowParts) do g:Hide() end end,
    }

    -- Hover border highlight
    local hlSize = 1
    local hlColor = {1, 0.84, 0, 0.7}
    for _, edge in ipairs({
        {"TOPLEFT", "TOPRIGHT", hlSize, true},
        {"BOTTOMLEFT", "BOTTOMRIGHT", hlSize, true},
        {"TOPLEFT", "BOTTOMLEFT", hlSize, false},
        {"TOPRIGHT", "BOTTOMRIGHT", hlSize, false},
    }) do
        local hl = iconFrame:CreateTexture(nil, "HIGHLIGHT")
        hl:SetColorTexture(unpack(hlColor))
        if edge[4] then -- horizontal
            hl:SetPoint(edge[1], icon, edge[1], -hlSize, hlSize)
            hl:SetPoint(edge[2], icon, edge[2], hlSize, hlSize)
            hl:SetHeight(hlSize)
        else -- vertical
            hl:SetPoint(edge[1], icon, edge[1], -hlSize, hlSize)
            hl:SetPoint(edge[2], icon, edge[2], -hlSize, -hlSize)
            hl:SetWidth(hlSize)
        end
    end

    iconFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
        local r, g, b = unpack(lure.colorRGB)
        GameTooltip:AddLine(lure.name, r, g, b)
        GameTooltip:AddLine(lure.requiredPoints .. " pts required", 0.6, 0.6, 0.6)
        local lureBagName = C_Item.GetItemNameByID(lure.itemID)
        local bags = lureBagName and C_Item.GetItemCount(lureBagName) or C_Item.GetItemCount(lure.itemID)
        if bags > 0 then
            GameTooltip:AddLine("In bags: " .. bags, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: Use lure", 0.5, 0.8, 1)
        GameTooltip:AddLine("Shift-click: Open recipe / Craft", 0.5, 0.8, 1)
        GameTooltip:AddLine("Right-click: Set waypoint", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- PreClick: shift = open recipe (block item use), right = waypoint (block item use)
    iconFrame:SetScript("PreClick", function(self, button)
        if InCombatLockdown() then return end
        if button == "RightButton" or IsShiftKeyDown() then
            self:SetAttribute("type", nil)
        end
    end)
    iconFrame:SetScript("PostClick", function(self, button)
        -- Restore secure type
        if not InCombatLockdown() then
            self:SetAttribute("type", "item")
        end
        if IsShiftKeyDown() and button == "LeftButton" then
            local now = GetTime()
            -- Throttle AnyUp/AnyDown pair (< 0.1s apart)
            if (now - (self._lastPostClick or 0)) < 0.1 then return end
            self._lastPostClick = now
            if lure.recipeID then
                if C_TradeSkillUI.IsTradeSkillReady() then
                    C_TradeSkillUI.CraftRecipe(lure.recipeID)
                else
                    C_TradeSkillUI.OpenRecipe(lure.recipeID)
                end
            end
        elseif button == "RightButton" then
            local now = GetTime()
            if (now - (self._lastWaypoint or 0)) < 0.5 then return end
            self._lastWaypoint = now
            local wp = lure.waypoint
            if wp then
                local mapPoint = UiMapPoint.CreateFromCoordinates(wp.map, wp.x, wp.y)
                C_Map.SetUserWaypoint(mapPoint)
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                if MajesticBeastTrackerDB.settings.chatNotify ~= false then
                    print("|cff3FC7EB[MBT]|r Waypoint set: " .. lure.color .. lure.name .. "|r")
                end
            end
        end
    end)
    headerIcons[i] = iconFrame
end

-- Zone labels below lure icons (parented to headerIcons so they render above lure boxes)
local zoneLabels = {}
for i, lure in ipairs(LURES) do
    local zLabel = headerIcons[i]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zLabel:SetFont(zLabel:GetFont(), 9)
    local r, g, b = unpack(lure.colorRGB)
    zLabel:SetTextColor(r, g, b, 0.8)
    zLabel:SetText(lure.name)
    zLabel:SetJustifyH("CENTER")
    zLabel:SetPoint("TOP", headerIcons[i], "BOTTOM", 0, -1)
    zoneLabels[i] = zLabel
end

------------------------------------------------------
-- Reagent icons (small icons above each lure header)
------------------------------------------------------

local reagentIcons = {}  -- reagentIcons[lureIndex] = { icon1, icon2, ... }
for i, lure in ipairs(LURES) do
    reagentIcons[i] = {}
    if lure.reagents then
        local numReagents = #lure.reagents
        for j, reagent in ipairs(lure.reagents) do
            local rBtn = CreateFrame("Button", "MBT_ReagentIcon" .. i .. "_" .. j, frame)
            rBtn:SetSize(REAGENT_ICON_SIZE, REAGENT_ICON_SIZE)
            -- Center reagent(s) above the lure icon
            -- For 1 reagent: centered above lure icon
            -- For 2 reagents: side by side, centered above lure icon
            local lureCenter = PAD + 4 + NAME_COL_WIDTH + (i - 1) * COL_WIDTH + COL_WIDTH / 2
            local totalWidth = numReagents * REAGENT_ICON_SIZE + (numReagents - 1) * REAGENT_GAP
            local reagentX = lureCenter - totalWidth / 2 + (j - 1) * (REAGENT_ICON_SIZE + REAGENT_GAP)
            rBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", reagentX, contentTop - 2 - 1)

            local rIcon = rBtn:CreateTexture(nil, "ARTWORK")
            rIcon:SetAllPoints()
            rIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            rBtn.icon = rIcon

            -- Count text centered below icon
            local rCount = rBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rCount:SetFont(rCount:GetFont(), 8)
            rCount:SetPoint("TOP", rBtn, "BOTTOM", 0, -1)
            rCount:SetJustifyH("CENTER")
            rBtn.countText = rCount

            -- Pre-load item data
            C_Item.RequestLoadItemDataByID(reagent.itemID)

            -- OnLeave (static, OnEnter set dynamically in UpdateUI)
            rBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            -- Shift-click: link item to chat (useful for AH search)
            rBtn:SetScript("OnClick", function(self, button)
                if IsShiftKeyDown() then
                    local _, link = C_Item.GetItemInfo(reagent.itemID)
                    if link then
                        ChatEdit_InsertLink(link)
                    end
                end
            end)
            rBtn:RegisterForClicks("LeftButtonUp")

            reagentIcons[i][j] = rBtn
        end
    end
end

-- TSM price labels placeholder
local TSM_PRICE_HEIGHT = 10
local tsmPriceLabels = {}

-- Pre-load loot item names for tooltips
for id in pairs(ns.TRACKED_LOOT) do
    C_Item.RequestLoadItemDataByID(id)
end

-- Lure column border boxes (wraps reagent icons + lure icon)
local LURE_BOX_BACKDROP = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local lureBoxes = {}
for i = 1, #LURES do
    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetBackdrop(LURE_BOX_BACKDROP)
    box:SetBackdropColor(0, 0, 0, 0.7)
    local r, g, b = unpack(LURES[i].colorRGB)
    box:SetBackdropBorderColor(r, g, b, 0.6)
    box:SetFrameLevel(frame:GetFrameLevel() + 1)
    -- Make sure icons render on top of the box
    headerIcons[i]:SetFrameLevel(box:GetFrameLevel() + 2)
    if reagentIcons[i] then
        for _, rBtn in ipairs(reagentIcons[i]) do
            rBtn:SetFrameLevel(box:GetFrameLevel() + 2)
        end
    end
    box:Hide()  -- shown dynamically in UpdateUI
    lureBoxes[i] = box

    -- TSM price label (on top of box)
    local priceLabel = box:CreateFontString(nil, "OVERLAY")
    priceLabel:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
    priceLabel:SetTextColor(1, 0.84, 0)
    priceLabel:SetJustifyH("CENTER")
    priceLabel:SetText("")
    tsmPriceLabels[i] = priceLabel
end

-- Consumable box (floating panel anchored to frame, same row as lure icons)
local CONS_ICON_SIZE = 20
local CONS_SPACING = 4
local CONS_PAD = 6
local CONS_ITEM_WIDTH = CONS_ICON_SIZE + CONS_SPACING + 46
local CONS_BOX_WIDTH = #CONSUMABLES * CONS_ITEM_WIDTH + CONS_PAD * 2
local CONS_BOX_HEIGHT = ICON_SIZE + 12

local consumableBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
consumableBox:SetSize(CONS_BOX_WIDTH, CONS_BOX_HEIGHT)
consumableBox:SetBackdrop(BACKDROP)
consumableBox:SetBackdropColor(0, 0, 0, 0.9)
consumableBox:SetBackdropBorderColor(unpack(C_BORDER_RGB))
consumableBox:SetFrameStrata("MEDIUM")
consumableBox:SetFrameLevel(201)
local consumableIcons = {}
local consumableButtons = {}
local consumableLabels = {}
for i, cons in ipairs(CONSUMABLES) do
    local btn = CreateFrame("Button", "MBT_ConsumableBtn" .. i, consumableBox, "SecureActionButtonTemplate")
    btn:SetSize(CONS_ICON_SIZE, CONS_ICON_SIZE)
    btn:SetFrameLevel(consumableBox:GetFrameLevel() + 1)
    btn:SetAttribute("type", "item")
    btn:SetAttribute("item", cons.itemName or "")
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:Hide()
    -- Cache item name async
    C_Item.RequestLoadItemDataByID(cons.itemID)
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        local name = C_Item.GetItemNameByID(cons.itemID)
        if name and not InCombatLockdown() then
            btn:SetAttribute("item", name)
            ticker:Cancel()
        end
    end, 10)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    -- Golden border glow (shown when item in bags but buff inactive)
    -- Four edge textures around the icon
    local glowSize = 2
    local glowColor = {1, 0.75, 0, 0.9}
    local glowTop = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    glowTop:SetPoint("TOPLEFT", icon, "TOPLEFT", -glowSize, glowSize)
    glowTop:SetPoint("TOPRIGHT", icon, "TOPRIGHT", glowSize, glowSize)
    glowTop:SetHeight(glowSize)
    glowTop:SetColorTexture(unpack(glowColor))
    local glowBot = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    glowBot:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -glowSize, -glowSize)
    glowBot:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", glowSize, -glowSize)
    glowBot:SetHeight(glowSize)
    glowBot:SetColorTexture(unpack(glowColor))
    local glowLeft = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    glowLeft:SetPoint("TOPLEFT", icon, "TOPLEFT", -glowSize, glowSize)
    glowLeft:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -glowSize, -glowSize)
    glowLeft:SetWidth(glowSize)
    glowLeft:SetColorTexture(unpack(glowColor))
    local glowRight = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    glowRight:SetPoint("TOPRIGHT", icon, "TOPRIGHT", glowSize, glowSize)
    glowRight:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", glowSize, -glowSize)
    glowRight:SetWidth(glowSize)
    glowRight:SetColorTexture(unpack(glowColor))
    local glowParts = {glowTop, glowBot, glowLeft, glowRight}
    for _, g in ipairs(glowParts) do g:Hide() end
    btn.glow = {
        Show = function() for _, g in ipairs(glowParts) do g:Show() end end,
        Hide = function() for _, g in ipairs(glowParts) do g:Hide() end end,
    }

    -- Hover border highlight
    for _, info in ipairs({
        {"TOPLEFT", "TOPRIGHT", true},
        {"BOTTOMLEFT", "BOTTOMRIGHT", true},
        {"TOPLEFT", "BOTTOMLEFT", false},
        {"TOPRIGHT", "BOTTOMRIGHT", false},
    }) do
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetColorTexture(1, 0.84, 0, 0.7)
        if info[3] then
            hl:SetPoint(info[1], icon, info[1], -1, 1)
            hl:SetPoint(info[2], icon, info[2], 1, 1)
            hl:SetHeight(1)
        else
            hl:SetPoint(info[1], icon, info[1], -1, 1)
            hl:SetPoint(info[2], icon, info[2], -1, -1)
            hl:SetWidth(1)
        end
    end

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
        GameTooltip:SetItemByID(cons.itemID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: Use item", 0.5, 0.8, 1)
        GameTooltip:AddLine("Shift-click: Search in AH", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- PreClick: block on shift (AH search) or if buff has >20% remaining
    btn:SetScript("PreClick", function(self)
        if InCombatLockdown() then return end
        if IsShiftKeyDown() then
            self:SetAttribute("type", nil)
            return
        end
        -- Block if buff still has >20% duration left (skip for stackable buffs like Root Crab)
        if not cons.stackable then
            local buffInfo = C_UnitAuras.GetAuraDataBySpellName("player", cons.buffName, "HELPFUL")
            if not buffInfo and cons.itemName ~= cons.buffName then
                buffInfo = C_UnitAuras.GetAuraDataBySpellName("player", cons.itemName, "HELPFUL")
            end
            if buffInfo and buffInfo.duration and buffInfo.duration > 0 and buffInfo.expirationTime then
                local remaining = buffInfo.expirationTime - GetTime()
                if remaining / buffInfo.duration > 0.2 then
                    self:SetAttribute("type", nil)
                    if not self._blockedMsg or (GetTime() - self._blockedMsg) > 1 then
                        if MajesticBeastTrackerDB.settings.chatNotify ~= false then
                            local timeLeft = remaining >= 60 and (math.ceil(remaining / 60) .. "m") or (math.floor(remaining) .. "s")
                            print("|cff3FC7EB[MBT]|r Buff still has " .. timeLeft .. " left. Not consumed.")
                        end
                        self._blockedMsg = GetTime()
                    end
                end
            end
        end
    end)
    btn:SetScript("PostClick", function(self)
        -- Restore type attribute
        if not InCombatLockdown() then
            self:SetAttribute("type", "item")
        end
        if IsShiftKeyDown() then
            if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
                local itemName = C_Item.GetItemNameByID(cons.itemID)
                if itemName then
                    AuctionHouseFrame.SearchBar.SearchBox:SetText(itemName)
                    AuctionHouseFrame.SearchBar.SearchButton:Click()
                end
            else
                if MajesticBeastTrackerDB.settings.chatNotify ~= false then
                    print("|cff3FC7EB[MBT]|r Open the Auction House first!")
                end
            end
        end
    end)

    -- Status label to the right of icon (on consumableBox, high strata)
    local label = consumableBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetFont(label:GetFont(), 10)
    label:SetJustifyH("LEFT")

    consumableIcons[i] = btn
    consumableButtons[i] = btn
    consumableLabels[i] = label
end

-- Refresh consumable labels (called every 1s for real-time buff timers)
function ns.RefreshConsumableLabels()
    local playerLevel = UnitLevel("player")
    for i, cons in ipairs(CONSUMABLES) do
        local meetsLevel = not cons.minLevel or playerLevel >= cons.minLevel
        local count = C_Item.GetItemCount(cons.itemName or cons.itemID)
        local buffInfo = C_UnitAuras.GetAuraDataBySpellName("player", cons.buffName, "HELPFUL")
        if not buffInfo and cons.spellID then
            buffInfo = C_UnitAuras.GetAuraDataBySpellName("player", cons.itemName, "HELPFUL")
        end
        local remaining = buffInfo and buffInfo.expirationTime and (buffInfo.expirationTime - GetTime()) or 0
        if not meetsLevel then
            consumableLabels[i]:SetText("Lv" .. cons.minLevel)
            consumableLabels[i]:SetTextColor(0.4, 0.4, 0.4)
            consumableButtons[i].glow:Hide()
        elseif cons.stackable and buffInfo and remaining > 0 then
            local label = remaining >= 60 and (math.ceil(remaining / 60) .. "m") or (math.floor(remaining) .. "s")
            if count > 0 then label = label .. " " .. count .. "x" end
            consumableLabels[i]:SetText(label)
            consumableLabels[i]:SetTextColor(0.2, 0.9, 0.4)
            if count > 0 then consumableButtons[i].glow:Show() else consumableButtons[i].glow:Hide() end
        elseif buffInfo and remaining > 0 then
            consumableLabels[i]:SetText(remaining >= 60 and (math.ceil(remaining / 60) .. "m") or (math.floor(remaining) .. "s"))
            consumableLabels[i]:SetTextColor(0.2, 0.9, 0.4)
            consumableButtons[i].glow:Hide()
        elseif count > 0 then
            consumableLabels[i]:SetText(count .. "x")
            consumableLabels[i]:SetTextColor(1, 1, 1)
            consumableButtons[i].glow:Show()
        else
            consumableLabels[i]:SetText("0")
            consumableLabels[i]:SetTextColor(0.4, 0.4, 0.4)
            consumableButtons[i].glow:Hide()
        end
    end
end

-- 1-second ticker for real-time consumable buff timers
C_Timer.NewTicker(1, function()
    if frame:IsShown() then
        ns.RefreshConsumableLabels()
    end
end)

-- Separator under icons
local iconSep = frame:CreateTexture(nil, "ARTWORK")
iconSep:SetHeight(1)
iconSep:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, contentTop - REAGENT_ROW_HEIGHT - ICON_ROW_HEIGHT - 2)
iconSep:SetPoint("RIGHT", frame, "RIGHT", -(PAD + 4), 0)
iconSep:SetColorTexture(unpack(C_SEPARATOR))

------------------------------------------------------
-- Travel buttons (bottom of frame, below character rows)
------------------------------------------------------

local travelButtons = {}
local travelSep = frame:CreateTexture(nil, "ARTWORK")
travelSep:SetHeight(1)
travelSep:SetColorTexture(unpack(C_SEPARATOR))
travelSep:Hide()

local function CreateTravelButton(index, itemInfo)
    local btn = CreateFrame("Button", "MBT_TravelBtn" .. index, frame, "SecureActionButtonTemplate")
    btn:SetSize(TRAVEL_ICON_SIZE, TRAVEL_ICON_SIZE)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:Hide()

    if itemInfo.isToy then
        btn:SetAttribute("type", "toy")
        btn:SetAttribute("toy", itemInfo.itemID)
    else
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", itemInfo.name)
        -- Cache item name async
        C_Item.RequestLoadItemDataByID(itemInfo.itemID)
        local ticker
        ticker = C_Timer.NewTicker(1, function()
            local name = C_Item.GetItemNameByID(itemInfo.itemID)
            if name and not InCombatLockdown() then
                btn:SetAttribute("item", name)
                ticker:Cancel()
            end
        end, 10)
    end

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local cdHolder = CreateFrame("Frame", nil, btn)
    cdHolder:SetAllPoints()
    local cd = CreateFrame("Cooldown", nil, cdHolder, "CooldownFrameTemplate")
    cd:SetSize(TRAVEL_ICON_SIZE / 0.7, TRAVEL_ICON_SIZE / 0.7)
    cd:SetScale(0.7)
    cd:SetPoint("CENTER")
    cd:SetDrawEdge(true)
    btn.cooldown = cd

    -- Hover border highlight
    for _, info in ipairs({
        {"TOPLEFT", "TOPRIGHT", true},
        {"BOTTOMLEFT", "BOTTOMRIGHT", true},
        {"TOPLEFT", "BOTTOMLEFT", false},
        {"TOPRIGHT", "BOTTOMRIGHT", false},
    }) do
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetColorTexture(1, 0.84, 0, 0.7)
        if info[3] then
            hl:SetPoint(info[1], icon, info[1], -1, 1)
            hl:SetPoint(info[2], icon, info[2], 1, 1)
            hl:SetHeight(1)
        else
            hl:SetPoint(info[1], icon, info[1], -1, 1)
            hl:SetPoint(info[2], icon, info[2], -1, -1)
            hl:SetWidth(1)
        end
    end

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
        if itemInfo.isToy then
            GameTooltip:SetToyByItemID(itemInfo.itemID)
        else
            GameTooltip:SetItemByID(itemInfo.itemID)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: Use", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn.itemInfo = itemInfo
    return btn
end

-- Create static travel buttons (Hearthstone + Arcantina)
for i, item in ipairs(TRAVEL_ITEMS) do
    travelButtons[i] = CreateTravelButton(i, item)
end
-- Wormhole button (created but shown conditionally)
local wormholeBtn = CreateTravelButton(#TRAVEL_ITEMS + 1, WORMHOLE_ITEM)

------------------------------------------------------
-- Stats display (Skill, Perception, Finesse, Deftness)
------------------------------------------------------

local STAT_LABELS = {
    { key = "Skill",      label = "Skl", color = {1, 0.82, 0} },
    { key = "Perception", label = "Per", color = {0.2, 0.9, 0.4} },
    { key = "Finesse",    label = "Fin", color = {0.4, 0.7, 1} },
    { key = "Deftness",   label = "Dft", color = {1, 0.5, 0.2} },
}

local statsTexts = {}
for i, stat in ipairs(STAT_LABELS) do
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetFont(label:GetFont(), 9)
    label:SetTextColor(stat.color[1], stat.color[2], stat.color[3])
    label:Hide()
    statsTexts[i] = label
end

-- Total TSM cost label (below stats)
local tsmTotalLabel = frame:CreateFontString(nil, "OVERLAY")
tsmTotalLabel:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
tsmTotalLabel:SetTextColor(1, 0.84, 0)
tsmTotalLabel:SetJustifyH("RIGHT")
tsmTotalLabel:Hide()

-- Weekly knowledge lines for main window (right-aligned, below stats)
local weeklyMainLines = {}
for i = 1, #ns.SKINNING_WEEKLIES do
    local line = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line:SetFont(line:GetFont(), 9)
    line:SetJustifyH("RIGHT")
    line:Hide()
    weeklyMainLines[i] = line
end

-- Helper: format copper as short gold string (minus prefix, no color codes)
function ns.FormatGold(copper)
    if not copper or copper <= 0 then return nil end
    local gold = math.floor(copper / 10000)
    if gold >= 1000 then
        return string.format("-%.1fk g", gold / 1000)
    elseif gold > 0 then
        return "-" .. gold .. " g"
    else
        local silver = math.floor((copper % 10000) / 100)
        return "-" .. silver .. " s"
    end
end

-- Helper: format gold amount for loot display (positive, no minus)
function ns.FormatGoldPositive(copper)
    if not copper or copper <= 0 then return "0 g" end
    local gold = math.floor(copper / 10000)
    if gold >= 1000 then
        return string.format("%.1fk g", gold / 1000)
    elseif gold > 0 then
        return gold .. " g"
    else
        local silver = math.floor((copper % 10000) / 100)
        return silver .. " s"
    end
end

-- Helper: get TSM min buyout price for an item (returns copper or nil)
function ns.GetTSMPrice(itemID)
    if not TSM_API then return nil end
    local ok, price = pcall(TSM_API.GetCustomPriceValue, "DBMinBuyout", "i:" .. itemID)
    if ok and price and price > 0 then return price end
    return nil
end

-- Helper: build loot tooltip lines from item count table
function ns.AddLootTooltipLines(lootTable, header, savedPrices)
    if not lootTable then return 0 end
    local hasAny = false
    for _, c in pairs(lootTable) do
        if c > 0 then hasAny = true; break end
    end
    if not hasAny then return 0 end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(header, 1, 0.84, 0)

    local totalValue = 0
    local hasTSM = TSM_API ~= nil
    -- Group quality variants by item name
    local grouped = {}  -- name -> { count = N, ids = {id1, id2} }
    local order = {}
    for id, count in pairs(lootTable) do
        if count > 0 then
            local name = C_Item.GetItemNameByID(id) or ("Item " .. id)
            if not grouped[name] then
                grouped[name] = { count = 0, ids = {} }
                order[#order + 1] = name
            end
            grouped[name].count = grouped[name].count + count
            grouped[name].ids[#grouped[name].ids + 1] = id
        end
    end
    table.sort(order)

    for _, name in ipairs(order) do
        local entry = grouped[name]
        local line = name .. "  x" .. entry.count
        if hasTSM then
            -- Use saved price from loot time, fall back to current price
            local price
            if savedPrices then
                for _, id in ipairs(entry.ids) do
                    if savedPrices[id] then price = savedPrices[id]; break end
                end
            end
            if not price then price = ns.GetTSMPrice(entry.ids[1]) end
            if price then
                local value = price * entry.count
                totalValue = totalValue + value
                line = line .. "  |cffffd700" .. ns.FormatGoldPositive(value) .. "|r"
            end
        end
        GameTooltip:AddLine(line, 0.9, 0.9, 0.9)
    end

    if hasTSM and totalValue > 0 then
        GameTooltip:AddLine("Value: " .. ns.FormatGoldPositive(totalValue), 1, 0.84, 0)
    end
    return totalValue
end

-- Helper: check if player has Engineering as second profession
function ns.HasEngineering()
    local prof1, prof2 = GetProfessions()
    if prof1 then
        local _, _, _, _, _, _, skillLineID = GetProfessionInfo(prof1)
        if skillLineID == 202 then return true end
    end
    if prof2 then
        local _, _, _, _, _, _, skillLineID = GetProfessionInfo(prof2)
        if skillLineID == 202 then return true end
    end
    return false
end

------------------------------------------------------
-- Character rows
------------------------------------------------------

local charRows = {}
local dataTop = contentTop - REAGENT_ROW_HEIGHT - ICON_ROW_HEIGHT - 5

function ns.GetStatusText(charData, lureName)
    if not charData then return "?", 0.4, 0.4, 0.4 end
    local timestamp = charData.lures[lureName]
    if not timestamp then
        return "-", 0.4, 0.4, 0.4
    elseif ns.IsLureReady(timestamp) then
        return "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t", 0.2, 0.9, 0.4
    else
        local timeLeft = ns.GetLureTimeRemaining(timestamp)
        local h = math.floor(timeLeft / 3600)
        local m = math.floor((timeLeft % 3600) / 60)
        if h > 0 then
            return h .. "h", 0.9, 0.3, 0.3
        else
            return m .. "m", 1, 0.6, 0.2
        end
    end
end


------------------------------------------------------
-- Gear popup (shown when clicking character name)
------------------------------------------------------

local GEAR_ICON_SIZE = 24
local GEAR_PAD = 6

local gearPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
gearPopup:SetFrameStrata("DIALOG")
gearPopup:SetClampedToScreen(true)
gearPopup:SetBackdrop(BACKDROP)
gearPopup:SetBackdropColor(0, 0, 0, 0.97)
gearPopup:SetBackdropBorderColor(unpack(C_BORDER_RGB))
gearPopup:EnableMouse(true)
gearPopup:Hide()

local gearPopupTitle = gearPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
gearPopupTitle:SetPoint("TOPLEFT", gearPopup, "TOPLEFT", GEAR_PAD + 2, -GEAR_PAD)
gearPopupTitle:SetTextColor(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b)

local gearPopupRows = {}
for slot = 1, 3 do
    local row = CreateFrame("Frame", nil, gearPopup)
    row:SetHeight(GEAR_ICON_SIZE)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(GEAR_ICON_SIZE, GEAR_ICON_SIZE)
    icon:SetPoint("LEFT")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetFont(label:GetFont(), 9)
    label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    gearPopupRows[slot] = row
end

-- Stat lines in gear popup
local POPUP_STAT_LABELS = {
    { key = "skill",      label = "Skill",      color = "ffFFD100" },
    { key = "perception", label = "Perception",  color = "ff1EFF00" },
    { key = "finesse",    label = "Finesse",     color = "ff0070DD" },
    { key = "deftness",   label = "Deftness",    color = "ffA335EE" },
}

local gearPopupStatHeader = gearPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
gearPopupStatHeader:SetFont(gearPopupStatHeader:GetFont(), 9)
gearPopupStatHeader:SetTextColor(0.6, 0.6, 0.6)
gearPopupStatHeader:SetText("Base Stats against Majestic Beasts")

local gearPopupStatLines = {}
for i, info in ipairs(POPUP_STAT_LABELS) do
    local line = gearPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line:SetFont(line:GetFont(), 9)
    line:SetJustifyH("LEFT")
    gearPopupStatLines[i] = line
end

-- Weekly KP header + lines
local gearPopupWeeklyHeader = gearPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
gearPopupWeeklyHeader:SetFont(gearPopupWeeklyHeader:GetFont(), 9)
gearPopupWeeklyHeader:SetTextColor(0.6, 0.6, 0.6)
gearPopupWeeklyHeader:SetText("Weekly Knowledge")

local WEEKLIES = ns.SKINNING_WEEKLIES
local gearPopupWeeklyLines = {}
for i = 1, #WEEKLIES do
    local line = gearPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line:SetFont(line:GetFont(), 9)
    line:SetJustifyH("LEFT")
    gearPopupWeeklyLines[i] = line
end

-- Helper: layout weekly lines in gear popup, returns total height used
local function LayoutWeeklyLines(charData, anchorFontString, startY, trackMaxWidth)
    local weeklyHeight = 0
    local hasWeeklies = charData and charData.weeklies
    local weeklyExpired = charData and charData.weeklyResetTime and GetServerTime() > charData.weeklyResetTime
    local dmfUp = ns.IsDarkmoonFaireUp and ns.IsDarkmoonFaireUp()

    if hasWeeklies and not weeklyExpired then
        gearPopupWeeklyHeader:ClearAllPoints()
        gearPopupWeeklyHeader:SetPoint("TOPLEFT", anchorFontString, "BOTTOMLEFT", 2, startY)
        gearPopupWeeklyHeader:Show()
        local row = 0
        for i, w in ipairs(WEEKLIES) do
            local line = gearPopupWeeklyLines[i]
            if w.dmf and not dmfUp then
                line:Hide()
            else
                local val = charData.weeklies[w.key]
                local status
                if w.mode == "each" then
                    local total = #w.questIDs
                    local count = val or 0
                    local totalKP = total * w.kp
                    if count >= total then
                        status = "|cff00ff00" .. count .. "/" .. total .. "|r"
                    elseif count > 0 then
                        status = "|cffffff00" .. count .. "/" .. total .. "|r"
                    else
                        status = "|cffff4444" .. count .. "/" .. total .. "|r"
                    end
                    line:SetText(w.label .. " |cff888888(" .. totalKP .. " KP)|r " .. status)
                else
                    local done = val
                    local icon = done and "|cff00ff00done|r" or "|cffff4444todo|r"
                    line:SetText(w.label .. " |cff888888(" .. w.kp .. " KP)|r " .. icon)
                end
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", anchorFontString, "BOTTOMLEFT", 2, startY - 10 - row * 12)
                line:Show()
                if trackMaxWidth then
                    trackMaxWidth[1] = math.max(trackMaxWidth[1], line:GetStringWidth())
                end
                row = row + 1
            end
        end
        weeklyHeight = 6 + 10 + row * 12 + 2
    else
        gearPopupWeeklyHeader:Hide()
        for i = 1, #WEEKLIES do
            gearPopupWeeklyLines[i]:Hide()
        end
    end
    return weeklyHeight
end

-- Auto-hide when clicking elsewhere
gearPopup:SetScript("OnUpdate", function(self)
    if self:IsShown() and not self:IsMouseOver() and not frame:IsMouseOver() and IsMouseButtonDown("LeftButton") then
        self:Hide()
    end
end)

local function ShowGearPopup(anchor, charKey)
    ns.EnsureDB()
    local charData = MajesticBeastTrackerDB.chars[charKey]
    if not charData or not charData.gear or #charData.gear == 0 then
        -- No gear data — show empty message + stats if available
        gearPopupTitle:SetText(ns.GetDemoName(charKey))
        for _, row in ipairs(gearPopupRows) do
            row:Hide()
            row.label:Hide()
        end
        local noGear = gearPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noGear:SetPoint("TOPLEFT", gearPopupTitle, "BOTTOMLEFT", 0, -4)
        local isCurrentChar = charKey == ns.GetCharKey()
        local noGearMsg = isCurrentChar and "No gear equipped" or "No gear data (login required)"
        noGear:SetText("|cff666666" .. noGearMsg .. "|r")
        noGear:SetFont(noGear:GetFont(), 9)
        gearPopup.noGear = noGear

        -- Still show stats if we have them
        local statsHeight = 0
        local hasStats = charData and charData.stats and (charData.stats.skill or 0) > 0
        if hasStats then
            local headerY = -(4 + 14 + 6)
            gearPopupStatHeader:ClearAllPoints()
            gearPopupStatHeader:SetPoint("TOPLEFT", gearPopupTitle, "BOTTOMLEFT", 2, headerY)
            gearPopupStatHeader:Show()
            for i, info in ipairs(POPUP_STAT_LABELS) do
                local line = gearPopupStatLines[i]
                local val = charData.stats[info.key] or 0
                line:SetText("|c" .. info.color .. info.label .. ":|r " .. val)
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", gearPopupTitle, "BOTTOMLEFT", 2, headerY - 10 - (i - 1) * 12)
                line:Show()
            end
            statsHeight = 6 + 10 + #POPUP_STAT_LABELS * 12 + 2
        else
            gearPopupStatHeader:Hide()
            for i = 1, #POPUP_STAT_LABELS do
                gearPopupStatLines[i]:Hide()
            end
        end

        -- Weeklies in no-gear view
        local weeklyY = -(4 + 14 + statsHeight + 6)
        local weeklyHeight = LayoutWeeklyLines(charData, gearPopupTitle, weeklyY, nil)

        gearPopup:SetSize(180, GEAR_PAD * 2 + 14 + 16 + statsHeight + weeklyHeight)
        gearPopup:ClearAllPoints()
        gearPopup:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -2, 0)
        gearPopup:Show()
        return
    end

    -- Clean up previous no-gear text
    if gearPopup.noGear then gearPopup.noGear:Hide() end

    gearPopupTitle:SetText(ns.GetClassColor(charData.class) .. ns.GetDemoName(charKey) .. "|r")

    local maxLabelWidth = 0
    for slot, row in ipairs(gearPopupRows) do
        local gear = charData.gear[slot]
        if gear then
            local tex = gear.icon or C_Item.GetItemIconByID(gear.itemID)
            if tex then row.icon:SetTexture(tex) end
            row.itemLink = gear.link
            local displayName = gear.name or ""
            -- Color by item rarity from link
            if gear.link then
                local _, _, quality = GetItemInfo(gear.link)
                if quality and ITEM_QUALITY_COLORS[quality] then
                    displayName = ITEM_QUALITY_COLORS[quality].hex .. displayName .. "|r"
                end
            end
            row.label:SetText(displayName)
            row.label:SetWidth(180)
            row:SetPoint("TOPLEFT", gearPopupTitle, "BOTTOMLEFT",
                0, -(4 + (slot - 1) * (GEAR_ICON_SIZE + 3)))
            row:Show()
            row.label:Show()
            maxLabelWidth = math.max(maxLabelWidth, row.label:GetStringWidth())
        else
            row:Hide()
            row.label:Hide()
        end
    end

    local numGear = #charData.gear
    local gearHeight = numGear * (GEAR_ICON_SIZE + 3)

    -- Show stats below gear
    local statsHeight = 0
    local hasStats = charData.stats and (charData.stats.skill or 0) > 0
    if hasStats then
        local headerY = -(4 + gearHeight + 6)
        gearPopupStatHeader:ClearAllPoints()
        gearPopupStatHeader:SetPoint("TOPLEFT", gearPopupTitle, "BOTTOMLEFT", 2, headerY)
        gearPopupStatHeader:Show()
        for i, info in ipairs(POPUP_STAT_LABELS) do
            local line = gearPopupStatLines[i]
            local val = charData.stats[info.key] or 0
            line:SetText("|c" .. info.color .. info.label .. ":|r " .. val)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", gearPopupTitle, "BOTTOMLEFT", 2, headerY - 10 - (i - 1) * 12)
            line:Show()
            maxLabelWidth = math.max(maxLabelWidth, line:GetStringWidth())
        end
        statsHeight = 6 + 10 + #POPUP_STAT_LABELS * 12 + 2
    else
        gearPopupStatHeader:Hide()
        for i = 1, #POPUP_STAT_LABELS do
            gearPopupStatLines[i]:Hide()
        end
    end

    -- Show weeklies below stats
    local weeklyY = -(4 + gearHeight + statsHeight + 6)
    local widthTracker = { maxLabelWidth }
    local weeklyHeight = LayoutWeeklyLines(charData, gearPopupTitle, weeklyY, widthTracker)
    maxLabelWidth = widthTracker[1]

    local popupW = GEAR_PAD * 2 + GEAR_ICON_SIZE + 8 + math.max(maxLabelWidth, 160)
    local popupH = GEAR_PAD * 2 + 14 + gearHeight + statsHeight + weeklyHeight
    -- Set row width to cover full popup for hover tooltip
    for _, row in ipairs(gearPopupRows) do
        row:SetWidth(popupW - GEAR_PAD * 2)
    end
    gearPopup:SetSize(popupW, popupH)
    gearPopup:ClearAllPoints()
    gearPopup:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -2, 0)
    gearPopup:Show()
end

------------------------------------------------------
-- Character rows
------------------------------------------------------

-- Forward declarations for loot editor (used in goblin button OnClick below)
local ShowLootEditor
local lootEditor

local function CreateCharRow(index)
    local row = {}
    local yOffset = dataTop - (index - 1) * ROW_HEIGHT

    -- Alternating row background
    if index % 2 == 0 then
        local rowBg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        rowBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, yOffset)
        rowBg:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
        rowBg:SetHeight(ROW_HEIGHT)
        rowBg:SetColorTexture(unpack(C_ROW_ALT))
        row.bg = rowBg
    end

    -- Name button (clickable to show gear popup)
    local nameBtn = CreateFrame("Button", nil, frame)
    nameBtn:SetSize(NAME_COL_WIDTH - 4, ROW_HEIGHT)
    nameBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 6, yOffset)

    local nameLabel = nameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetAllPoints()
    nameLabel:SetFont(nameLabel:GetFont(), 10)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetJustifyV("MIDDLE")
    nameLabel:SetWordWrap(false)

    local nameHl = nameBtn:CreateTexture(nil, "HIGHLIGHT")
    nameHl:SetAllPoints()
    nameHl:SetColorTexture(0.25, 0.78, 0.92, 0.08)

    nameBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    nameBtn.label = nameLabel
    row.name = nameBtn
    row.nameLabel = nameLabel

    row.cells = {}
    for i = 1, #LURES do
        local cell = CreateFrame("Button", nil, frame)
        cell:SetSize(COL_WIDTH, ROW_HEIGHT)
        cell:SetPoint("TOPLEFT", frame, "TOPLEFT",
            PAD + 4 + NAME_COL_WIDTH + (i - 1) * COL_WIDTH,
            yOffset)

        local label = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetAllPoints()
        label:SetFont(label:GetFont(), 10)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        cell.label = label

        -- Highlight on hover
        local hl = cell:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.25, 0.78, 0.92, 0.1)

        cell.lureIndex = i
        row.cells[i] = cell
    end

    -- Goblin loot icon (right side of row)
    local goblinBtn = CreateFrame("Button", nil, frame)
    goblinBtn:SetSize(14, 14)
    local goblinX = PAD + 4 + NAME_COL_WIDTH + #LURES * COL_WIDTH + 4
    goblinBtn:SetPoint("LEFT", frame, "TOPLEFT", goblinX, yOffset - ROW_HEIGHT / 2)
    local goblinIcon = goblinBtn:CreateTexture(nil, "ARTWORK")
    goblinIcon:SetAllPoints()
    goblinIcon:SetTexture("Interface\\Icons\\Achievement_GoblinHead")
    goblinIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    goblinBtn.icon = goblinIcon
    goblinBtn:RegisterForClicks("LeftButtonUp")
    goblinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    goblinBtn:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        if lootEditor:IsShown() and lootEditor.charKey == row._charKey then
            lootEditor:Hide()
        else
            ShowLootEditor(self, row._charKey)
        end
    end)
    goblinBtn:Hide()
    row.goblinBtn = goblinBtn

    return row
end

function ns.HideAllRows()
    for _, row in ipairs(charRows) do
        row.name:Hide()
        if row.bg then row.bg:Hide() end
        for _, cell in ipairs(row.cells) do
            cell:Hide()
        end
        if row.goblinBtn then row.goblinBtn:Hide() end
    end
end

------------------------------------------------------
-- Custom dropdown
------------------------------------------------------

local dropdown

local function CreateDropdown()
    if dropdown then return dropdown end
    dropdown = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dropdown:SetFrameStrata("DIALOG")
    dropdown:SetClampedToScreen(true)
    dropdown:SetBackdrop(BACKDROP)
    dropdown:SetBackdropColor(0, 0, 0, 0.97)
    dropdown:SetBackdropBorderColor(unpack(C_BORDER_RGB))
    dropdown:EnableMouse(true)
    dropdown:Hide()
    dropdown.buttons = {}

    dropdown:SetScript("OnUpdate", function(self)
        if self:IsShown() and not self:IsMouseOver() and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
            self:Hide()
        end
    end)

    return dropdown
end

local function ShowDropdown(anchor, items)
    local dd = CreateDropdown()
    for _, btn in ipairs(dd.buttons) do btn:Hide() end

    local btnHeight = 20
    local btnWidth = 150
    local yOff = -6

    for idx, item in ipairs(items) do
        local btn = dd.buttons[idx]
        if not btn then
            btn = CreateFrame("Button", nil, dd)
            btn:SetHeight(btnHeight)
            local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("LEFT", 8, 0)
            label:SetPoint("RIGHT", -8, 0)
            label:SetJustifyH("LEFT")
            btn.label = label

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.25, 0.78, 0.92, 0.15)

            dd.buttons[idx] = btn
        end

        btn:SetPoint("TOPLEFT", dd, "TOPLEFT", 6, yOff)
        btn:SetPoint("TOPRIGHT", dd, "TOPRIGHT", -6, yOff)
        btn.label:SetText(item.text)
        if item.isTitle then
            btn.label:SetTextColor(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b)
            btn:SetScript("OnClick", nil)
            btn:Disable()
        else
            btn.label:SetTextColor(0.9, 0.9, 0.9)
            btn:Enable()
            btn:SetScript("OnClick", function()
                dd:Hide()
                if item.func then item.func() end
            end)
        end
        btn:Show()
        yOff = yOff - btnHeight
    end

    dd:SetSize(btnWidth + 12, math.abs(yOff) + 6)
    dd:ClearAllPoints()
    dd:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    dd:Show()
end

------------------------------------------------------
-- Loot Editor Panel
------------------------------------------------------

lootEditor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
lootEditor:SetFrameStrata("MEDIUM")
lootEditor:SetClampedToScreen(true)
lootEditor:SetBackdrop(BACKDROP)
lootEditor:SetBackdropColor(0, 0, 0, 0.97)
lootEditor:SetBackdropBorderColor(unpack(C_BORDER_RGB))
lootEditor:EnableMouse(true)
lootEditor:Hide()
lootEditor.rows = {}
lootEditor.charKey = nil

-- Title
local lootTitle = lootEditor:CreateFontString(nil, "OVERLAY")
lootTitle:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
lootTitle:SetPoint("TOPLEFT", lootEditor, "TOPLEFT", 8, -8)
lootTitle:SetTextColor(0.25, 0.78, 0.92)
lootEditor.title = lootTitle

-- Syncing overlay
local syncOverlay = CreateFrame("Frame", nil, lootEditor)
syncOverlay:SetAllPoints()
syncOverlay:SetFrameLevel(lootEditor:GetFrameLevel() + 10)
syncOverlay:EnableMouse(true) -- block clicks through
syncOverlay:Hide()
local syncBg = syncOverlay:CreateTexture(nil, "BACKGROUND")
syncBg:SetAllPoints()
syncBg:SetColorTexture(0, 0, 0, 0.7)
local syncText = syncOverlay:CreateFontString(nil, "OVERLAY")
syncText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
syncText:SetPoint("CENTER", 0, 0)
syncText:SetText("|cff59c7eaLoot sync in progress...|r")
lootEditor.syncOverlay = syncOverlay

-- Close button
local lootClose = CreateFrame("Button", nil, lootEditor)
lootClose:SetSize(16, 16)
lootClose:SetPoint("TOPRIGHT", -4, -4)
local lootCloseTex = lootClose:CreateFontString(nil, "OVERLAY")
lootCloseTex:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
lootCloseTex:SetAllPoints()
lootCloseTex:SetText("|cffff4444×|r")
local lootCloseHl = lootClose:CreateTexture(nil, "HIGHLIGHT")
lootCloseHl:SetAllPoints()
lootCloseHl:SetColorTexture(1, 0.3, 0.3, 0.15)
lootClose:SetScript("OnClick", function() lootEditor:Hide() end)

local LOOT_ROW_HEIGHT = 22
local LOOT_EDITOR_WIDTH = 320

-- Build sorted list of all tracked item IDs (sorted by name, then quality tier)
local function BuildSortedLootList()
    local items = {}
    for id in pairs(ns.TRACKED_LOOT) do
        local name = C_Item.GetItemNameByID(id) or ("Item " .. id)
        local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(id) or 0
        items[#items + 1] = { id = id, name = name, quality = quality }
    end
    table.sort(items, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.quality < b.quality
    end)
    return items
end

-- Inner function that actually populates the editor (called after items are cached)
local function PopulateLootEditor(anchor, charKey)
    lootEditor.charKey = charKey
    if anchor ~= lootEditor then
        lootEditor._anchor = anchor
    end
    local charData = MajesticBeastTrackerDB.chars[charKey]
    if not charData then return end

    -- Ensure loot structure
    if not charData.loot then
        charData.loot = { thisReset = {}, allTime = {}, resetTime = GetServerTime() }
    end
    local loot = ns.GetCharLoot(charData)

    lootEditor.title:SetText(ns.GetDemoName(charKey) .. " - Edit Loot")

    local sortedItems = BuildSortedLootList()

    local yOff = -24
    for idx, entry in ipairs(sortedItems) do
        local itemID = entry.id
        local row = lootEditor.rows[idx]
        if not row then
            row = CreateFrame("Frame", nil, lootEditor)
            row:SetHeight(LOOT_ROW_HEIGHT)
            row:EnableMouse(true)

            -- Item icon
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            icon:SetPoint("LEFT", 8, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.icon = icon

            -- Item name
            local name = row:CreateFontString(nil, "OVERLAY")
            name:SetFont(STANDARD_TEXT_FONT, 10)
            name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
            name:SetWidth(150)
            name:SetJustifyH("LEFT")
            name:SetWordWrap(false)
            row.nameText = name

            -- Count display (clickable to edit)
            local countBtn = CreateFrame("Button", nil, row)
            countBtn:SetSize(50, LOOT_ROW_HEIGHT)
            countBtn:SetPoint("RIGHT", row, "RIGHT", -56, 0)
            local countLabel = countBtn:CreateFontString(nil, "OVERLAY")
            countLabel:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            countLabel:SetAllPoints()
            countLabel:SetJustifyH("RIGHT")
            row.countLabel = countLabel
            row.countBtn = countBtn

            -- Inline EditBox (hidden by default)
            local editBox = CreateFrame("EditBox", nil, row, "BackdropTemplate")
            editBox:SetSize(36, 16)
            editBox:SetPoint("RIGHT", row, "RIGHT", -58, 0)
            editBox:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            editBox:SetJustifyH("CENTER")
            editBox:SetAutoFocus(false)
            editBox:SetNumeric(true)
            editBox:SetMaxLetters(5)
            editBox:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
            editBox:SetBackdropColor(0, 0, 0, 0.9)
            editBox:SetBackdropBorderColor(0.25, 0.78, 0.92, 0.6)
            editBox:SetTextColor(1, 0.84, 0)
            editBox:Hide()
            row.editBox = editBox

            -- Minus button
            local minusBtn = CreateFrame("Button", nil, row)
            minusBtn:SetSize(18, 18)
            minusBtn:SetPoint("RIGHT", row, "RIGHT", -30, 0)
            local minusTex = minusBtn:CreateFontString(nil, "OVERLAY")
            minusTex:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
            minusTex:SetAllPoints()
            minusTex:SetText("|cffff4444-|r")
            local minusHl = minusBtn:CreateTexture(nil, "HIGHLIGHT")
            minusHl:SetAllPoints()
            minusHl:SetColorTexture(1, 0.3, 0.3, 0.15)
            row.minusBtn = minusBtn

            -- Plus button
            local plusBtn = CreateFrame("Button", nil, row)
            plusBtn:SetSize(18, 18)
            plusBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            local plusTex = plusBtn:CreateFontString(nil, "OVERLAY")
            plusTex:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
            plusTex:SetAllPoints()
            plusTex:SetText("|cff44ff44+|r")
            local plusHl = plusBtn:CreateTexture(nil, "HIGHLIGHT")
            plusHl:SetAllPoints()
            plusHl:SetColorTexture(0.3, 1, 0.3, 0.15)
            row.plusBtn = plusBtn

            lootEditor.rows[idx] = row
        end

        row:SetPoint("TOPLEFT", lootEditor, "TOPLEFT", 0, yOff)
        row:SetPoint("TOPRIGHT", lootEditor, "TOPRIGHT", 0, yOff)

        -- Set item data
        local tex = C_Item.GetItemIconByID(itemID)
        if tex then row.icon:SetTexture(tex) end
        local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
        if entry.quality and entry.quality > 0 then
            itemName = itemName .. " |A:Professions-ChatIcon-Quality-12-Tier" .. entry.quality .. ":17:15::1|a"
        end
        row.nameText:SetText(itemName)
        row.nameText:SetTextColor(0.9, 0.9, 0.9)

        local resetCount = loot.thisReset[itemID] or 0
        local allCount = loot.allTime[itemID] or 0
        row.countLabel:SetText("|cffffd700" .. resetCount .. "|r / " .. allCount)
        row.editBox:Hide()
        row.countBtn:Show()

        -- Item tooltip on hover
        local capturedID = itemID
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
            GameTooltip:SetItemByID(capturedID)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Capture for closures
        local capturedIdx = idx

        -- Helper: update display after any edit
        local function RefreshRow()
            local cl = ns.GetCharLoot(charData)
            local rc = cl.thisReset[capturedID] or 0
            local ac = cl.allTime[capturedID] or 0
            lootEditor.rows[capturedIdx].countLabel:SetText("|cffffd700" .. rc .. "|r / " .. ac)
            if ns.UpdateUI then ns.UpdateUI() end
        end

        -- Click count to type a value
        row.countBtn:SetScript("OnClick", function()
            local cl = ns.GetCharLoot(charData)
            row.countBtn:Hide()
            row.editBox:SetText(tostring(cl.thisReset[capturedID] or 0))
            row.editBox:Show()
            row.editBox:SetFocus()
            row.editBox:HighlightText()
        end)

        -- EditBox: commit on Enter, cancel on Escape
        local function CommitEdit()
            local val = tonumber(row.editBox:GetText()) or 0
            local cl = ns.GetCharLoot(charData)
            local oldReset = cl.thisReset[capturedID] or 0
            local delta = val - oldReset
            cl.thisReset[capturedID] = val > 0 and val or nil
            cl.allTime[capturedID] = math.max((cl.allTime[capturedID] or 0) + delta, 0)
            if cl.allTime[capturedID] <= 0 then cl.allTime[capturedID] = nil end
            row.editBox:Hide()
            row.countBtn:Show()
            RefreshRow()
        end
        row.editBox:SetScript("OnEnterPressed", CommitEdit)
        row.editBox:SetScript("OnEscapePressed", function()
            row.editBox:Hide()
            row.countBtn:Show()
        end)
        row.editBox:SetScript("OnEditFocusLost", function()
            row.editBox:Hide()
            row.countBtn:Show()
        end)

        row.minusBtn:SetScript("OnClick", function()
            local cl = ns.GetCharLoot(charData)
            if cl.thisReset[capturedID] and cl.thisReset[capturedID] > 0 then
                cl.thisReset[capturedID] = cl.thisReset[capturedID] - 1
                if cl.thisReset[capturedID] <= 0 then cl.thisReset[capturedID] = nil end
            end
            if cl.allTime[capturedID] and cl.allTime[capturedID] > 0 then
                cl.allTime[capturedID] = cl.allTime[capturedID] - 1
                if cl.allTime[capturedID] <= 0 then cl.allTime[capturedID] = nil end
            end
            RefreshRow()
        end)

        row.plusBtn:SetScript("OnClick", function()
            local cl = ns.GetCharLoot(charData)
            cl.thisReset[capturedID] = (cl.thisReset[capturedID] or 0) + 1
            cl.allTime[capturedID] = (cl.allTime[capturedID] or 0) + 1
            RefreshRow()
        end)

        row:Show()
        yOff = yOff - LOOT_ROW_HEIGHT
    end

    -- Hide unused rows
    for i = #sortedItems + 1, #lootEditor.rows do
        lootEditor.rows[i]:Hide()
    end

    lootEditor:SetSize(LOOT_EDITOR_WIDTH, math.abs(yOff) + 8)
    lootEditor:ClearAllPoints()
    lootEditor:SetPoint("TOPLEFT", lootEditor._anchor or anchor, "TOPRIGHT", 4, 0)
    lootEditor:Show()

    -- Show syncing overlay when loot sync is active
    if ns.isSyncingLoot then
        lootEditor.syncOverlay:Show()
    else
        lootEditor.syncOverlay:Hide()
    end
end

-- Preload item data then open editor
ShowLootEditor = function(anchor, charKey)
    local pending = 0
    local allCached = true
    for id in pairs(ns.TRACKED_LOOT) do
        if not C_Item.GetItemNameByID(id) then
            allCached = false
            pending = pending + 1
            C_Item.RequestLoadItemDataByID(id, function()
                pending = pending - 1
                if pending <= 0 then
                    PopulateLootEditor(anchor, charKey)
                end
            end)
        end
    end
    if allCached then
        PopulateLootEditor(anchor, charKey)
    end
end

------------------------------------------------------
-- Update
------------------------------------------------------

local function UpdateLockVisual()
    ns.EnsureDB()
    lockIcon[MajesticBeastTrackerDB.settings.locked and "Show" or "Hide"](lockIcon)
end

function ns.UpdateUI()
    local uiOk, uiErr = pcall(function()
    ns.EnsureDB()
    local currentChar = ns.GetCharKey()
    if not currentChar then return end

    -- Header icons: texture, count, glow
    local charData = MajesticBeastTrackerDB.chars[currentChar]
    for i, lure in ipairs(LURES) do
        local tex = C_Item.GetItemIconByID(lure.itemID)
        if tex then headerIcons[i].icon:SetTexture(tex) end

        -- Check if current character can craft this lure
        local canCraft = charData and ns.CanSeeLure(charData, i)
        headerIcons[i].icon:SetDesaturated(not canCraft)
        headerIcons[i].icon:SetAlpha(canCraft and 1.0 or 0.4)

        -- Craftable count (reagents from bags + bank + warbank)
        local craftable = ns.GetCraftableCount(lure.recipeID)
        -- Lures in bags (name to count all qualities)
        local lureName = C_Item.GetItemNameByID(lure.itemID)
        if not lureName then C_Item.RequestLoadItemDataByID(lure.itemID) end
        local inBags = lureName and C_Item.GetItemCount(lureName) or C_Item.GetItemCount(lure.itemID)

        if inBags > 0 or craftable > 0 then
            local text = ""
            if inBags > 0 and craftable > 0 then
                text = "|cffffffff" .. inBags .. "|r+|cff00ff00" .. craftable .. "|r"
            elseif inBags > 0 then
                text = "|cffffffff" .. inBags .. "|r"
            else
                text = "|cff00ff00" .. craftable .. "|r"
            end
            headerIcons[i].countText:SetText(text)
            headerIcons[i].countText:Show()
        else
            headerIcons[i].countText:SetText("")
            headerIcons[i].countText:Hide()
        end

        -- Glow: yellow if lure in bags + usable by current char
        local lureReady = charData and ns.CanSeeLure(charData, i)
            and (not charData.lures[lure.name] or ns.IsLureReady(charData.lures[lure.name]))
        if inBags > 0 and lureReady then
            headerIcons[i].glow.Show()
        else
            headerIcons[i].glow.Hide()
        end

    end

    -- Reagent icons: texture, count, visibility + dynamic layout
    local showReagents = MajesticBeastTrackerDB.settings.showReagents ~= false
    local tsmExtra = (showReagents and TSM_API and MajesticBeastTrackerDB.settings.tsmIntegration) and TSM_PRICE_HEIGHT or 0
    local reagentExtra = showReagents and (REAGENT_ROW_HEIGHT + tsmExtra) or 0

    -- Reposition lure icons and separator based on reagent visibility
    if not InCombatLockdown() then
        for i = 1, #LURES do
            headerIcons[i]:ClearAllPoints()
            headerIcons[i]:SetPoint("TOPLEFT", frame, "TOPLEFT",
                PAD + 4 + NAME_COL_WIDTH + (i - 1) * COL_WIDTH + (COL_WIDTH - ICON_SIZE) / 2,
                contentTop - 2 - reagentExtra)
        end
        iconSep:ClearAllPoints()
        iconSep:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, contentTop - reagentExtra - ICON_ROW_HEIGHT - 2)
        iconSep:SetPoint("RIGHT", frame, "RIGHT", -(PAD + 4), 0)
        consumableBox:ClearAllPoints()
        consumableBox:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, contentTop - 2 - reagentExtra + 4)
    end

    -- Count characters that still need a lure today (eligible - already killed)
    local charsNeedLure = {}
    for li = 1, #LURES do
        charsNeedLure[li] = 0
        for _, cData in pairs(MajesticBeastTrackerDB.chars) do
            if ns.CanSeeLure(cData, li) then
                local ts = cData.lures[LURES[li].name]
                if not ts or ns.IsLureReady(ts) then
                    -- No kill or cooldown expired → needs a lure
                    charsNeedLure[li] = charsNeedLure[li] + 1
                end
            end
        end
    end

    -- Update fish toggle button
    fishIcon:SetDesaturated(not showReagents)
    fishIcon:SetAlpha(showReagents and 1.0 or 0.4)
    fishBtn:Show()

    -- Update coin toggle button (desaturated when TSM not installed or disabled)
    local tsmEnabled = MajesticBeastTrackerDB.settings.tsmIntegration
    local tsmActive = tsmEnabled and TSM_API
    coinIcon:SetDesaturated(not tsmActive)
    coinIcon:SetAlpha(tsmActive and 1.0 or 0.4)
    coinBtn:Show()

    -- Update global goblin button (desaturated when loot tracking is off)
    local lootTrackingOn = MajesticBeastTrackerDB.settings.lootTracking ~= false
    globalGoblinIcon:SetDesaturated(not lootTrackingOn)
    globalGoblinIcon:SetAlpha(lootTrackingOn and 1.0 or 0.4)
    globalGoblinBtn:Show()

    -- Warband bank deposit button: show only when bank open + setting enabled
    if ns.isBankOpen and MajesticBeastTrackerDB.settings.warbankDeposit then
        warbankBtn:Show()
    else
        warbankBtn:Hide()
    end

    for i, lure in ipairs(LURES) do
        if reagentIcons[i] and showReagents and lure.reagents then
            local numLeft = charsNeedLure[i]
            local anyMissing = false

            -- First pass: set textures, desaturation, tooltips, calculate status
            for j, rBtn in ipairs(reagentIcons[i]) do
                if lure.reagents[j] then
                    local reagent = lure.reagents[j]
                    local tex = C_Item.GetItemIconByID(reagent.itemID)
                    if tex then rBtn.icon:SetTexture(tex) end

                    local itemName = C_Item.GetItemNameByID(reagent.itemID)
                    local have = 0
                    if itemName then
                        have = C_Item.GetItemCount(itemName, true, false, true, true)
                    else
                        have = C_Item.GetItemCount(reagent.itemID, true, false, true, true)
                    end
                    local perLure = reagent.count
                    local reagentAllChars = MajesticBeastTrackerDB.settings.reagentAllChars ~= false
                    local totalNeed = perLure * (reagentAllChars and numLeft or 1)
                    local missing = math.max(totalNeed - have, 0)

                    rBtn.icon:SetDesaturated(missing > 0 and numLeft > 0)
                    if missing > 0 then anyMissing = true end

                    -- Store for count text decision
                    rBtn._have = have
                    rBtn._missing = missing
                    rBtn._totalNeed = totalNeed

                    -- Tooltip always per-reagent
                    rBtn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
                        GameTooltip:SetItemByID(reagent.itemID)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(string.format("Per lure: %d  |  Remaining: %d",
                            perLure, numLeft), 0.8, 0.8, 0.8)
                        if numLeft > 0 then
                            GameTooltip:AddLine(string.format("Need: %d  |  Have: %d",
                                totalNeed, have), 1, 1, 1)
                            if missing > 0 then
                                GameTooltip:AddLine("Missing: " .. missing, 0.9, 0.3, 0.3)
                            else
                                GameTooltip:AddLine("Ready to go!", 0.2, 0.9, 0.4)
                            end
                        else
                            GameTooltip:AddLine("All characters done!", 0.2, 0.9, 0.4)
                        end
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Shift-click: Link to chat", 0.5, 0.8, 1)
                        GameTooltip:Show()
                    end)

                    rBtn:Show()
                else
                    rBtn:Hide()
                end
            end

            -- Second pass: count text — single status or per-icon counts
            -- Check if any character is eligible for this lure
            local anyEligible = false
            for _, cData in pairs(MajesticBeastTrackerDB.chars) do
                if ns.CanSeeLure(cData, i) then anyEligible = true; break end
            end
            local singleLabel
            if not anyEligible then
                singleLabel = "|cff666666Locked|r"
            elseif numLeft == 0 then
                singleLabel = "|cff00ff00Done|r"
            elseif not anyMissing then
                singleLabel = "|cff00ff00Ready|r"
            end
            for j, rBtn in ipairs(reagentIcons[i]) do
                if rBtn.countText and lure.reagents[j] then
                    if singleLabel then
                        if j == 1 then
                            rBtn.countText:SetText(singleLabel)
                            -- Center across the full column width
                            rBtn.countText:ClearAllPoints()
                            local numR = #lure.reagents
                            local totalW = numR * REAGENT_ICON_SIZE + (numR - 1) * REAGENT_GAP
                            local offsetX = totalW / 2 - REAGENT_ICON_SIZE / 2
                            rBtn.countText:SetPoint("TOP", rBtn, "BOTTOM", offsetX, -1)
                            rBtn.countText:Show()
                        else
                            rBtn.countText:SetText("")
                        end
                    else
                        -- Some missing: show have/total
                        rBtn.countText:ClearAllPoints()
                        local numR = #lure.reagents
                        if numR > 1 and j == 1 then
                            rBtn.countText:SetPoint("TOPLEFT", rBtn, "BOTTOMLEFT", -6, -1)
                            rBtn.countText:SetJustifyH("LEFT")
                        elseif numR > 1 and j == numR then
                            rBtn.countText:SetPoint("TOPRIGHT", rBtn, "BOTTOMRIGHT", 6, -1)
                            rBtn.countText:SetJustifyH("RIGHT")
                        else
                            rBtn.countText:SetPoint("TOP", rBtn, "BOTTOM", 0, -1)
                            rBtn.countText:SetJustifyH("CENTER")
                        end
                        -- Constrain width to prevent overlap on multi-reagent lures
                        local maxW = numR > 1 and (COL_WIDTH / 2 - 1) or COL_WIDTH
                        rBtn.countText:SetWidth(maxW)
                        local have = rBtn._have or 0
                        local total = rBtn._totalNeed or 0
                        if rBtn._missing > 0 then
                            rBtn.countText:SetText("|cffff3333" .. have .. "/" .. total .. "|r")
                        else
                            rBtn.countText:SetText("|cff00ff00" .. have .. "|r")
                        end
                        rBtn.countText:Show()
                    end
                end
            end
        elseif reagentIcons[i] then
            for _, rBtn in ipairs(reagentIcons[i]) do
                rBtn:Hide()
            end
        end
    end

    -- Update TSM price labels
    -- Update TSM price labels (cost of missing reagents per lure)
    local hasTSM = TSM_API ~= nil
    local showTSM = hasTSM and showReagents and MajesticBeastTrackerDB.settings.tsmIntegration
    for i, lure in ipairs(LURES) do
        local label = tsmPriceLabels[i]
        if showTSM and lure.reagents then
            local totalCost = 0
            local hasPrice = true
            for j, rBtn in ipairs(reagentIcons[i]) do
                if lure.reagents[j] then
                    local missing = rBtn._missing or 0
                    if missing > 0 then
                        local price = ns.GetTSMPrice(lure.reagents[j].itemID)
                        if price then
                            totalCost = totalCost + price * missing
                        else
                            hasPrice = false
                            break
                        end
                    end
                end
            end
            if hasPrice and totalCost > 0 then
                label:SetText(ns.FormatGold(totalCost))
                label:SetTextColor(1, 0.84, 0)
                label:ClearAllPoints()
                local colCenter = PAD + 4 + NAME_COL_WIDTH + (i - 1) * COL_WIDTH + COL_WIDTH / 2
                label:SetPoint("TOP", frame, "TOPLEFT", colCenter, contentTop - 2 - REAGENT_ICON_SIZE - REAGENT_COUNT_HEIGHT - 3)
                label:Show()
            else
                label:Hide()
            end
        else
            label:Hide()
        end
    end

    -- Update lure column boxes
    for i, lure in ipairs(LURES) do
        local box = lureBoxes[i]
        if showReagents and lure.reagents and #lure.reagents > 0 then
            -- Position border box around reagent icons + lure icon
            local boxPad = 3
            local colX = PAD + 4 + NAME_COL_WIDTH + (i - 1) * COL_WIDTH
            local boxTop = contentTop - 2 + boxPad
            local boxBottom = contentTop - 2 - reagentExtra - ICON_SIZE - boxPad
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", frame, "TOPLEFT", colX - boxPad, boxTop)
            box:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", colX + COL_WIDTH + boxPad, boxBottom)
            box:Show()
        else
            box:Hide()
        end
    end

    -- Gather eligible characters
    local keys = {}
    for key, charData in pairs(MajesticBeastTrackerDB.chars) do
        if charData.hasSkinning then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b)
        if a == currentChar then return true end
        if b == currentChar then return false end
        return a < b
    end)

    ns.HideAllRows()

    local dynDataTop = contentTop - reagentExtra - ICON_ROW_HEIGHT - 5

    for idx, key in ipairs(keys) do
        if not charRows[idx] then
            charRows[idx] = CreateCharRow(idx)
        end
        local row = charRows[idx]
        -- Reposition row elements based on dynamic reagent visibility
        local yOff = dynDataTop - (idx - 1) * ROW_HEIGHT
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 6, yOff)
        if row.bg then
            row.bg:ClearAllPoints()
            row.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, yOff)
            row.bg:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
        end
        for ci = 1, #LURES do
            if row.cells and row.cells[ci] then
                row.cells[ci]:ClearAllPoints()
                row.cells[ci]:SetPoint("TOPLEFT", frame, "TOPLEFT",
                    PAD + 4 + NAME_COL_WIDTH + (ci - 1) * COL_WIDTH, yOff)
            end
        end
        -- Reposition goblin icon
        if row.goblinBtn then
            row.goblinBtn:ClearAllPoints()
            local goblinX = PAD + 4 + NAME_COL_WIDTH + #LURES * COL_WIDTH + 4
            row.goblinBtn:SetPoint("LEFT", frame, "TOPLEFT", goblinX, yOff - ROW_HEIGHT / 2)
        end
        local charData = MajesticBeastTrackerDB.chars[key]
        row._charKey = key
        local classColor = ns.GetClassColor(charData.class)
        local name = ns.GetDemoName(key)
        if key == currentChar then name = name .. " *" end

        row.nameLabel:SetText(classColor .. name .. "|r")
        row.name:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                local items = {
                    { text = ns.GetDemoName(key), isTitle = true },
                    { text = "|cffff4444Remove character|r", func = function()
                        StaticPopup_Show("MBT_REMOVE_CHAR", ns.GetDemoName(key), nil, key)
                    end },
                }
                ShowDropdown(self, items)
            else
                if gearPopup:IsShown() and gearPopup.currentKey == key then
                    gearPopup:Hide()
                else
                    gearPopup.currentKey = key
                    ShowGearPopup(self, key)
                end
            end
        end)
        row.name:Show()
        if row.bg then row.bg:Show() end

        for i, lure in ipairs(LURES) do
            local cell = row.cells[i]
            cell.charKey = key
            local canSee = ns.CanSeeLure(charData, i)
            local text, r, g, b = ns.GetStatusText(charData, lure.name)
            cell.label:SetText(text)
            if canSee then
                cell.label:SetTextColor(r, g, b)
            else
                -- Locked lure: show status dimmed
                cell.label:SetTextColor(r * 0.5, g * 0.5, b * 0.5)
            end
            if canSee then
                cell:SetScript("OnClick", function()
                    ns.EnsureDB()
                    local cd = MajesticBeastTrackerDB.chars[key]
                    if not cd then return end
                    local ts = cd.lures[lure.name]
                    if not ts or ns.IsLureReady(ts) then
                        -- Mark as killed now
                        cd.lures[lure.name] = GetServerTime()
                        if MajesticBeastTrackerDB.settings.chatNotify ~= false then
                            print("|cff3FC7EB[MBT]|r " .. lure.color .. lure.name .. "|r marked for " .. key)
                        end
                    else
                        -- Clear the mark
                        cd.lures[lure.name] = nil
                        if MajesticBeastTrackerDB.settings.chatNotify ~= false then
                            print("|cff3FC7EB[MBT]|r " .. lure.color .. lure.name .. "|r cleared for " .. key)
                        end
                    end
                    ns.UpdateUI()
                end)
                cell:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
                    local ts = charData.lures[lure.name]
                    if not ts or ns.IsLureReady(ts) then
                        GameTooltip:AddLine("Click to mark as killed", 0.7, 0.7, 0.7)
                    else
                        GameTooltip:AddLine("Click to clear", 0.7, 0.7, 0.7)
                    end
                    GameTooltip:Show()
                end)
                cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
            else
                cell:SetScript("OnClick", nil)
                cell:SetScript("OnEnter", nil)
                cell:SetScript("OnLeave", nil)
            end
            cell:Show()
        end

        -- Per-character goblin loot icon
        local goblin = row.goblinBtn
        if goblin then
            if not lootTrackingOn then
                -- Tracking off: show disabled goblin
                goblin.icon:SetDesaturated(true)
                goblin.icon:SetAlpha(0.2)
                goblin:SetScript("OnEnter", nil)
                goblin:SetScript("OnClick", nil)
                goblin:Show()
            else
                local loot = ns.GetCharLoot(charData)
                local hasLoot = loot and loot.allTime and next(loot.allTime)
                goblin.icon:SetDesaturated(not hasLoot)
                goblin.icon:SetAlpha(hasLoot and 1.0 or 0.4)
                local capturedKey = key
                local capturedData = charData
                goblin:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_LEFT", -4, 0)
                    GameTooltip:AddLine(ns.GetDemoName(capturedKey) .. " - Loot", 0.25, 0.78, 0.92)
                    local charLoot = ns.GetCharLoot(capturedData)
                    if charLoot then
                        ns.AddLootTooltipLines(charLoot.thisReset, "This Reset", charLoot.prices)
                        ns.AddLootTooltipLines(charLoot.allTime, "All Time", charLoot.prices)
                    end
                    if not hasLoot then
                        GameTooltip:AddLine("No loot data yet", 0.5, 0.5, 0.5)
                    end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Click to edit loot", 0.5, 0.8, 1)
                    GameTooltip:Show()
                end)
                goblin:Show()
            end
        end
    end

    -- Update consumable status
    ns.RefreshConsumableLabels()
    local playerLevel = UnitLevel("player")
    for i, cons in ipairs(CONSUMABLES) do
        local meetsLevel = not cons.minLevel or playerLevel >= cons.minLevel
        consumableIcons[i].icon:SetDesaturated(not meetsLevel)
        consumableIcons[i].icon:SetAlpha(meetsLevel and 1.0 or 0.4)

        -- Update icon texture
        local tex = C_Item.GetItemIconByID(cons.itemID)
        if tex then consumableIcons[i].icon:SetTexture(tex) end

        -- Position button in consumable box
        if not InCombatLockdown() then
            local btn = consumableButtons[i]
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", consumableBox, "TOPLEFT",
                CONS_PAD + (i - 1) * CONS_ITEM_WIDTH, -(CONS_BOX_HEIGHT - CONS_ICON_SIZE) / 2)
            consumableLabels[i]:ClearAllPoints()
            consumableLabels[i]:SetPoint("LEFT", btn, "RIGHT", 2, 0)
            if frame:IsShown() then
                btn:Show()
                consumableBox:Show()
            else
                btn:Hide()
                consumableBox:Hide()
            end
        end
    end

    -- Update travel buttons
    local activeTravelBtns = {}
    for _, btn in ipairs(travelButtons) do
        activeTravelBtns[#activeTravelBtns + 1] = btn
    end
    -- Wormhole: show only if player has Engineering + item in bags
    local showWormhole = ns.HasEngineering() and PlayerHasToy(WORMHOLE_ITEM.itemID)
    if showWormhole then
        activeTravelBtns[#activeTravelBtns + 1] = wormholeBtn
    end

    -- Resize
    local n = math.max(#keys, 1)
    local statsExtra = 0  -- stats now shares row with consumable box
    local tsmTotalExtra = (showTSM and TSM_API) and 14 or 0
    local consExtra = CONS_BOX_HEIGHT + 2
    local h = TITLE_HEIGHT + 2 + reagentExtra + ICON_ROW_HEIGHT + 5 + n * ROW_HEIGHT + consExtra + statsExtra + tsmTotalExtra + PAD + 4
    local goblinColWidth = 18  -- always reserve space for goblin column
    local w = PAD * 2 + 8 + NAME_COL_WIDTH + #LURES * COL_WIDTH + goblinColWidth
    if not InCombatLockdown() then
        frame:SetSize(w, h)
    end

    -- Position title branding (left of lure icons, vertically centered with icon area)
    title:ClearAllPoints()
    title:SetPoint("TOP", frame, "TOPLEFT", PAD + 4 + NAME_COL_WIDTH / 2, contentTop - 2)

    -- Divider below character rows
    local divY = -(TITLE_HEIGHT + 2 + reagentExtra + ICON_ROW_HEIGHT + 5 + n * ROW_HEIGHT + 2)

    -- Position consumable box below divider
    consumableBox:ClearAllPoints()
    consumableBox:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, divY - 4)

    -- Position travel buttons on same row as consumable box (right of it)
    if not InCombatLockdown() then
        -- Divider between char rows and bottom bar
        travelSep:ClearAllPoints()
        travelSep:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, divY)
        travelSep:SetPoint("RIGHT", frame, "RIGHT", -(PAD + 4), 0)
        travelSep:Show()

        -- Hide all first
        for _, btn in ipairs(travelButtons) do btn:Hide() end
        wormholeBtn:Hide()

        -- Show + position active ones (right of consumable box)
        local travelStartX = CONS_BOX_WIDTH + PAD + 8
        local travelY = divY - (CONS_BOX_HEIGHT - TRAVEL_ICON_SIZE) / 2 - 2
        for idx, btn in ipairs(activeTravelBtns) do
            local tex = C_Item.GetItemIconByID(btn.itemInfo.itemID)
            if tex then btn.icon:SetTexture(tex) end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT",
                travelStartX + (idx - 1) * (TRAVEL_ICON_SIZE + TRAVEL_SPACING),
                travelY)
            -- Update cooldown sweep
            local start, duration, enable = C_Item.GetItemCooldown(btn.itemInfo.itemID)
            if start and duration and duration > 0 then
                btn.cooldown:SetCooldown(start, duration)
            else
                btn.cooldown:Clear()
            end
            if frame:IsShown() then
                btn:Show()
            end
        end

        -- Position stats on the right side of bottom row
        local profStats = ns.CalculateProfessionStats and ns.CalculateProfessionStats() or nil
        local hasAnyStats = profStats and (profStats.Skill > 0 or profStats.Perception > 0 or profStats.Finesse > 0 or profStats.Deftness > 0)
        local statsY = divY - 4 - CONS_BOX_HEIGHT / 2
        if hasAnyStats then
            local statsX = w - PAD - 4
            for i = #STAT_LABELS, 1, -1 do
                local val = profStats[STAT_LABELS[i].key] or 0
                if val > 0 then
                    statsTexts[i]:SetText(STAT_LABELS[i].label .. ":" .. val)
                    statsTexts[i]:ClearAllPoints()
                    statsTexts[i]:SetPoint("RIGHT", frame, "TOPLEFT", statsX, statsY)
                    statsX = statsX - statsTexts[i]:GetStringWidth() - 6
                    statsTexts[i]:Show()
                else
                    statsTexts[i]:Hide()
                end
            end
        else
            for i = 1, #STAT_LABELS do
                statsTexts[i]:Hide()
            end
        end

        -- Total TSM cost (below stats line)
        if showTSM then
            local grandTotal = 0
            local allPriced = true
            for i, lure in ipairs(LURES) do
                if lure.reagents and reagentIcons[i] then
                    for j, rBtn in ipairs(reagentIcons[i]) do
                        if lure.reagents[j] then
                            local missing = rBtn._missing or 0
                            if missing > 0 then
                                local price = ns.GetTSMPrice(lure.reagents[j].itemID)
                                if price then
                                    grandTotal = grandTotal + price * missing
                                else
                                    allPriced = false
                                end
                            end
                        end
                    end
                end
            end
            if allPriced and grandTotal > 0 then
                local goldText = ns.FormatGold(grandTotal)
                tsmTotalLabel:SetText("Total needed: " .. goldText)
                tsmTotalLabel:ClearAllPoints()
                tsmTotalLabel:SetPoint("RIGHT", frame, "TOPLEFT", w - PAD - 4, statsY - 12)
                tsmTotalLabel:Show()
                statsY = statsY - 12
            else
                tsmTotalLabel:Hide()
            end
        else
            tsmTotalLabel:Hide()
        end

        -- Weekly knowledge lines (main window, right-aligned, below stats)
        local showKnowledge = MajesticBeastTrackerDB.settings.showKnowledge ~= false
        local curCharData = MajesticBeastTrackerDB.chars[currentChar]
        local hasWeeklyData = showKnowledge and curCharData and curCharData.weeklies
        local weeklyExpired = curCharData and curCharData.weeklyResetTime and GetServerTime() > curCharData.weeklyResetTime
        local dmfUp = ns.IsDarkmoonFaireUp and ns.IsDarkmoonFaireUp()

        if hasWeeklyData and not weeklyExpired then
            local visible = {}
            for i, wk in ipairs(WEEKLIES) do
                if wk.dmf and not dmfUp then
                    weeklyMainLines[i]:Hide()
                else
                    local val = curCharData.weeklies[wk.key]
                    local isDone = false
                    if wk.mode == "each" then
                        isDone = (val or 0) >= #wk.questIDs
                    else
                        isDone = val and true or false
                    end
                    if isDone then
                        weeklyMainLines[i]:Hide()
                    else
                        local status
                        if wk.mode == "each" then
                            local count = val or 0
                            status = wk.label .. " |cff888888(" .. (#wk.questIDs * wk.kp) .. " KP)|r |cffffff00" .. count .. "/" .. #wk.questIDs .. "|r"
                        else
                            status = wk.label .. " |cff888888(" .. wk.kp .. " KP)|r |cffff4444todo|r"
                        end
                        visible[#visible + 1] = { idx = i, text = status }
                    end
                end
            end
            -- Position below stats, right-aligned
            local lineSpacing = 11
            local weeklyStartY = statsY - 10
            for r, entry in ipairs(visible) do
                local line = weeklyMainLines[entry.idx]
                line:SetText(entry.text)
                line:ClearAllPoints()
                line:SetPoint("RIGHT", frame, "TOPLEFT", w - PAD - 4, weeklyStartY - (r - 1) * lineSpacing)
                line:Show()
            end
            -- Grow frame to fit weekly lines
            if #visible > 0 then
                frame:SetHeight(h + #visible * lineSpacing + 6)
            end
        else
            for i = 1, #WEEKLIES do
                weeklyMainLines[i]:Hide()
            end
        end
    end

    if #keys == 0 then
        if not charRows[1] then charRows[1] = CreateCharRow(1) end
        charRows[1].nameLabel:SetText(C_ACCENT:WrapTextInColorCode("No skinners found"))
        charRows[1].name:SetWidth(w - PAD * 2)
        charRows[1].name:SetScript("OnClick", nil)
        charRows[1].name:Show()
        for _, cell in ipairs(charRows[1].cells) do
            cell:Hide()
        end
    end
    -- Update loot editor sync overlay
    if lootEditor and lootEditor:IsShown() then
        if ns.isSyncingLoot then
            lootEditor.syncOverlay:Show()
            lootEditor._wasSyncing = true
        else
            lootEditor.syncOverlay:Hide()
            -- Refresh loot counts once when sync finishes
            if lootEditor._wasSyncing and lootEditor.charKey then
                lootEditor._wasSyncing = nil
                ShowLootEditor(lootEditor, lootEditor.charKey)
            end
        end
    end

    end) -- end pcall
    if not uiOk then
        print("|cffff3333[MBT ERROR]|r UpdateUI: " .. tostring(uiErr))
    end
end

------------------------------------------------------
-- Right-click menu
------------------------------------------------------

frame:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" then
        ns.EnsureDB()
        local lockText = MajesticBeastTrackerDB.settings.locked and "Unlock Frame" or "Lock Frame"
        ShowDropdown(self, {
            { text = "Majestic Beast Tracker", isTitle = true },
            { text = lockText, func = function()
                MajesticBeastTrackerDB.settings.locked = not MajesticBeastTrackerDB.settings.locked
                UpdateLockVisual()
            end },
            { text = "Reset Position", func = function()
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
                MajesticBeastTrackerDB.settings.framePosition = nil
            end },
            { text = "Settings", func = function()
                ns.OpenSettings()
            end },
            { text = "Close", func = function()
                ns.HideFrame()
            end },
        })
    end
end)

------------------------------------------------------
-- Periodic refresh + aura/bag tracking
------------------------------------------------------

local auraFrame = CreateFrame("Frame")
auraFrame:RegisterEvent("UNIT_AURA")
auraFrame:RegisterEvent("BAG_UPDATE")
auraFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
auraFrame:RegisterEvent("SKILL_LINES_CHANGED")
auraFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    ns.UpdateUI()
end)

-- Hide in combat
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(_, event)
    ns.EnsureDB()
    if not MajesticBeastTrackerDB.settings.hideInCombat then return end
    if event == "PLAYER_REGEN_DISABLED" then
        if frame:IsShown() then
            frame._hiddenByCombat = true
            frame:Hide()
            consumableBox:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if frame._hiddenByCombat then
            frame._hiddenByCombat = nil
            if MajesticBeastTrackerDB.settings.showFrame ~= false then
                frame:Show()
                ns.UpdateUI()
            end
        end
    end
end)

local elapsed = 0
frame:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed >= 30 then
        elapsed = 0
        ns.UpdateUI()
    end
end)

------------------------------------------------------
-- Init
------------------------------------------------------

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    ns.EnsureDB()
    if MajesticBeastTrackerDB.settings.framePosition then
        local pos = MajesticBeastTrackerDB.settings.framePosition
        frame:ClearAllPoints()
        frame:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
    end
    if MajesticBeastTrackerDB.settings.showFrame == false then
        frame:Hide()
    else
        -- Delay show to check if current char has skinning
        C_Timer.After(1, function()
            ns.EnsureDB()
            local hideNonSkinner = MajesticBeastTrackerDB.settings.hideNonSkinner
            if hideNonSkinner == nil then hideNonSkinner = true end -- default on
            local key = ns.GetCharKey and ns.GetCharKey()
            local charData = key and MajesticBeastTrackerDB.chars[key]
            local isSkinner = charData and charData.hasSkinning
            if isSkinner then
                frame:Show()
            elseif hideNonSkinner then
                -- Non-skinner + hide enabled → always hide on login
                frame:Hide()
            else
                frame:Show()
            end
            UpdateLockVisual()
            ns.UpdateUI()
        end)
        return
    end
    UpdateLockVisual()
    C_Timer.After(1, ns.UpdateUI)
end)

------------------------------------------------------
-- Public API
------------------------------------------------------

function ns.ShowFrame()
    frame:Show()
    ns.EnsureDB()
    MajesticBeastTrackerDB.settings.showFrame = true
    ns.UpdateUI()
end

function ns.HideFrame()
    frame:Hide()
    if lootEditor then lootEditor:Hide() end
    ns.EnsureDB()
    MajesticBeastTrackerDB.settings.showFrame = false
    -- Hide consumable buttons and box
    if not InCombatLockdown() then
        for _, btn in ipairs(consumableButtons) do btn:Hide() end
        consumableBox:Hide()
        for _, btn in ipairs(travelButtons) do btn:Hide() end
        wormholeBtn:Hide()
    end
end

function ns.ToggleLock()
    ns.EnsureDB()
    MajesticBeastTrackerDB.settings.locked = not MajesticBeastTrackerDB.settings.locked
    UpdateLockVisual()
    local state = MajesticBeastTrackerDB.settings.locked and "locked" or "unlocked"
    print("|cff3FC7EB[MBT]|r Frame " .. state .. ".")
end

------------------------------------------------------
-- Minimap Button (LibDBIcon)
------------------------------------------------------

local function InitMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1")
    local icon = LibStub("LibDBIcon-1.0")

    local lureIcon = "Interface\\AddOns\\" .. addonName .. "\\icon"

    local dataObj = LDB:NewDataObject("MajesticBeastTracker", {
        type = "data source",
        text = "Majestic Beast Tracker",
        icon = lureIcon,
        OnClick = function(_, button)
            if button == "LeftButton" then
                if frame:IsShown() then
                    ns.HideFrame()
                else
                    ns.ShowFrame()
                end
            elseif button == "RightButton" then
                ns.OpenSettings()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip then return end
            tooltip:AddLine(C_ACCENT:WrapTextInColorCode("Majestic Beast Tracker"))
            tooltip:AddLine("Left-click: Toggle window", 0.7, 0.7, 0.7)
            tooltip:AddLine("Right-click: Settings", 0.7, 0.7, 0.7)
        end,
    })

    ns.EnsureDB()
    icon:Register("MajesticBeastTracker", dataObj, MajesticBeastTrackerDB.settings.minimap)
end

------------------------------------------------------
-- Settings Panel (Interface > AddOns)
------------------------------------------------------

-- Remove character confirm popup
StaticPopupDialogs["MBT_REMOVE_CHAR"] = {
    text = "Remove %s from Majestic Beast Tracker?",
    button1 = YES,
    button2 = NO,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, data)
        if data and MajesticBeastTrackerDB and MajesticBeastTrackerDB.chars then
            MajesticBeastTrackerDB.chars[data] = nil
            print("|cff3FC7EB[MBT]|r Removed " .. data)
            if ns.UpdateUI then ns.UpdateUI() end
        end
    end,
}

-- URL copy popup
StaticPopupDialogs["MBT_URL"] = {
    text = "Copy URL (Ctrl+C):",
    button1 = CLOSE,
    whileDead = true,
    hasEditBox = true,
    editBoxWidth = 240,
    OnShow = function(dialog, data)
        local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
        editBox:SetText(data)
        editBox:SetAutoFocus(true)
        editBox:HighlightText()
        editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
        editBox:SetScript("OnTextChanged", function()
            editBox:SetText(data)
            editBox:HighlightText()
        end)
    end,
    OnHide = function(dialog)
        local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
        editBox:SetScript("OnEscapePressed", nil)
        editBox:SetScript("OnTextChanged", nil)
    end,
}

local function InitSettings()
    ns.EnsureDB()
    local category, layout = Settings.RegisterVerticalLayoutCategory("Majestic Beast Tracker")
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategoryID = category:GetID()

    local dbIcon = LibStub("LibDBIcon-1.0")

    -- Text mixin for custom text rows
    LureTracker_SettingsTextMixin = {}
    function LureTracker_SettingsTextMixin:Init(initializer)
        local data = initializer:GetData()
        self.LeftText:SetTextToFit(data.leftText or "")
        self.RightText:SetTextToFit(data.rightText or "")
    end

    -- Expand mixin for collapsible sections
    LureTracker_SettingsExpandMixin = CreateFromMixins(SettingsExpandableSectionMixin)
    function LureTracker_SettingsExpandMixin:Init(initializer)
        SettingsExpandableSectionMixin.Init(self, initializer)
        self.data = initializer.data
    end
    function LureTracker_SettingsExpandMixin:OnExpandedChanged(expanded)
        self:EvaluateVisibility(expanded)
        SettingsInbound.RepairDisplay()
    end
    function LureTracker_SettingsExpandMixin:CalculateHeight()
        return 24
    end
    function LureTracker_SettingsExpandMixin:EvaluateVisibility(expanded)
        if expanded then
            self.Button.Right:SetAtlas("Options_ListExpand_Right_Expanded", TextureKitConstants.UseAtlasSize)
        else
            self.Button.Right:SetAtlas("Options_ListExpand_Right", TextureKitConstants.UseAtlasSize)
        end
    end

    -- Version
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
    local data = { leftText = "Version: |cffFFFFFF" .. version }
    local text = layout:AddInitializer(Settings.CreateElementInitializer("LureTracker_SettingsText", data))
    function text:GetExtent() return 14 end

    -- Support button
    layout:AddInitializer(CreateSettingsButtonInitializer("Support", "Buy Me a Coffee", function()
        StaticPopup_Show("MBT_URL", nil, nil, "https://buymeacoffee.com/vichob")
    end, "Developing this addon takes a significant amount of time and effort.\nPlease consider financially supporting the developer.", true))

    -- GitHub button
    layout:AddInitializer(CreateSettingsButtonInitializer("Feedback & Help", "GitHub", function()
        StaticPopup_Show("MBT_URL", nil, nil, "https://github.com/VichobAddons/MajesticBeastTracker")
    end, "Report bugs or give feedback on GitHub.", true))

    -- Expandable: Slash Commands
    local function createExpandableSection(lay, sectionName)
        local initializer = CreateFromMixins(SettingsExpandableSectionInitializer)
        local expandData = { name = sectionName, expanded = false }
        initializer:Init("LureTracker_SettingsExpandTemplate", expandData)
        initializer.GetExtent = ScrollBoxFactoryInitializerMixin.GetExtent
        lay:AddInitializer(initializer)
        return initializer, function() return initializer.data.expanded end
    end

    local _, isExpanded = createExpandableSection(layout, "Slash Commands")

    local cmdData = {
        leftText = "|cffFFFFFF"
            .. "/mbt\n\n"
            .. "/mbt hide\n\n"
            .. "/mbt lock\n\n"
            .. "/mbt settings\n\n"
            .. "/mbt talent |cff3FC7EBN|r|cffFFFFFF\n\n"
            .. "/mbt remove |cff3FC7EBName-Realm|r|cffFFFFFF\n\n"
            .. "/mbt nuke\n\n"
            .. "/mbt nuke all\n\n"
            .. "/mbt debug |cff3FC7EBcalc|stats|gear|r",
        rightText =
            "Show tracker\n\n"
            .. "Hide tracker\n\n"
            .. "Toggle frame lock\n\n"
            .. "Open settings\n\n"
            .. "Override talent points (0-40)\n\n"
            .. "Remove a character\n\n"
            .. "Clear current character\n\n"
            .. "Clear ALL data\n\n"
            .. "Debug tools (stats breakdown)",
    }
    local cmdText = layout:AddInitializer(Settings.CreateElementInitializer("LureTracker_SettingsText", cmdData))
    function cmdText:GetExtent()
        return 28 + select(2, string.gsub(cmdData.leftText, "\n", "")) * 12
    end
    cmdText:AddShownPredicate(isExpanded)

    -- General settings
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))

    -- Show Minimap Icon
    local s1 = Settings.RegisterAddOnSetting(category, "MBT_showMinimap", "showMinimap",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Show Minimap Icon", true)
    Settings.CreateCheckbox(category, s1, "Show or hide the minimap button.")
    s1:SetValueChangedCallback(function()
        MajesticBeastTrackerDB.settings.minimap.hide = not MajesticBeastTrackerDB.settings.showMinimap
        if MajesticBeastTrackerDB.settings.showMinimap then
            dbIcon:Show("MajesticBeastTracker")
        else
            dbIcon:Hide("MajesticBeastTracker")
        end
    end)

    -- Chat Notifications
    local s2 = Settings.RegisterAddOnSetting(category, "MBT_chatNotify", "chatNotify",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Chat Notifications", true)
    Settings.CreateCheckbox(category, s2, "Show [MBT] messages in chat (waypoints, mark/clear, buff warnings).")

    -- Hide on Non-Skinners
    local s2a = Settings.RegisterAddOnSetting(category, "MBT_hideNonSkinner", "hideNonSkinner",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Hide on Non-Skinners", true)
    Settings.CreateCheckbox(category, s2a, "Don't show the tracker automatically on characters without Skinning.")

    -- Show Reagent Icons
    local s2c = Settings.RegisterAddOnSetting(category, "MBT_showReagents", "showReagents",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Show Reagent Icons", true)
    Settings.CreateCheckbox(category, s2c, "Show reagent icons above each lure column header.")
    s2c:SetValueChangedCallback(function()
        ns.UpdateUI()
    end)

    -- Reagent Count: All Characters
    local s2e = Settings.RegisterAddOnSetting(category, "MBT_reagentAllChars", "reagentAllChars",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Reagent Count: All Characters", true)
    Settings.CreateCheckbox(category, s2e, "ON: Count reagents needed for all characters. OFF: Count for a single lure only.")
    s2e:SetValueChangedCallback(function()
        ns.UpdateUI()
    end)

    -- Show Knowledge (main window only)
    local s2d = Settings.RegisterAddOnSetting(category, "MBT_showKnowledge", "showKnowledge",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Show Weekly Knowledge", true)
    Settings.CreateCheckbox(category, s2d, "Show incomplete weekly knowledge quests in the main tracker window.")
    s2d:SetValueChangedCallback(function()
        ns.UpdateUI()
    end)

    -- Hide in Combat
    local s2b = Settings.RegisterAddOnSetting(category, "MBT_hideInCombat", "hideInCombat",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Hide in Combat", false)
    Settings.CreateCheckbox(category, s2b, "Automatically hide the tracker window during combat.")

    -- Lock Frame
    local s3 = Settings.RegisterAddOnSetting(category, "MBT_locked", "locked",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Lock Frame Position", false)
    Settings.CreateCheckbox(category, s3, "Prevent the tracker window from being dragged.")
    s3:SetValueChangedCallback(function()
        UpdateLockVisual()
    end)

    -- Window Scale
    local s4 = Settings.RegisterAddOnSetting(category, "MBT_windowScale", "windowScale",
        MajesticBeastTrackerDB.settings, Settings.VarType.Number, "Window Scale", 1.0)
    local scaleOpts = Settings.CreateSliderOptions(0.5, 2.0, 0.05)
    scaleOpts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(val)
        return string.format("%d%%", val * 100)
    end)
    Settings.CreateSlider(category, s4, scaleOpts, "Scale the tracker window (50% - 200%).")
    s4:SetValueChangedCallback(function()
        frame:SetScale(MajesticBeastTrackerDB.settings.windowScale)
    end)

    -- Loot Goblin section
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Loot Goblin"))

    local sLoot = Settings.RegisterAddOnSetting(category, "MBT_lootTracking", "lootTracking",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Enable Loot Tracking", true)
    Settings.CreateCheckbox(category, sLoot, "Track skinning loot from Majestic Beasts. Shows goblin icons on character rows.")
    sLoot:SetValueChangedCallback(function()
        ns.UpdateUI()
    end)

    local sLootTSM = Settings.RegisterAddOnSetting(category, "MBT_tsmIntegration", "tsmIntegration",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Integrate TSM", false)
    Settings.CreateCheckbox(category, sLootTSM, "Show estimated reagent cost and loot value using TradeSkillMaster price data. Requires TSM addon.")
    sLootTSM:SetValueChangedCallback(function()
        ns.UpdateUI()
    end)

    -- Warband Bank
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Warband Bank"))

    local sWarbank = Settings.RegisterAddOnSetting(category, "MBT_warbankDeposit", "warbankDeposit",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Enable Warband Bank Deposit", false)
    Settings.CreateCheckbox(category, sWarbank, "Show a deposit button on the tracker when the Warband Bank is open. Click to deposit all tracked skinning reagents.")

    local sWarbankAuto = Settings.RegisterAddOnSetting(category, "MBT_warbankAutoDeposit", "warbankAutoDeposit",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Automatically Deposit on Bank Open", false)
    Settings.CreateCheckbox(category, sWarbankAuto, "Automatically deposit tracked reagents when you open the Warband Bank.")

    local sWarbankRewards = Settings.RegisterAddOnSetting(category, "MBT_warbankDepositRewards", "warbankDepositRewards",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Deposit Beast Rewards", true)
    Settings.CreateCheckbox(category, sWarbankRewards, "Include skinning loot from beast kills (hides, leather, plating, scales, etc.)")

    local sWarbankReagents = Settings.RegisterAddOnSetting(category, "MBT_warbankDepositReagents", "warbankDepositReagents",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Deposit Lure Reagents", true)
    Settings.CreateCheckbox(category, sWarbankReagents, "Include fish used to craft lures (Arcane Wyrmfish, Gore Guppy, Ominous Octopus, etc.)")

    -- Data Management
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Data Management"))

    layout:AddInitializer(CreateSettingsButtonInitializer("Clear Current Character", "Clear", function()
        StaticPopupDialogs["MBT_CLEAR_CHAR"] = {
            text = "Clear lure data for |cff3FC7EB" .. (ns.GetCharKey() or "?") .. "|r?",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                ns.EnsureDB()
                local key = ns.GetCharKey()
                if key and MajesticBeastTrackerDB.chars[key] then
                    MajesticBeastTrackerDB.chars[key].lures = {}
                    ns.UpdateUI()
                    print("|cff3FC7EB[MBT]|r " .. key .. " data cleared.")
                end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("MBT_CLEAR_CHAR")
    end, "Clear all lure cooldown data for your current character.", true))

    layout:AddInitializer(CreateSettingsButtonInitializer("|cffff6666Clear ALL Characters|r", "Clear All", function()
        StaticPopupDialogs["MBT_CLEAR_ALL"] = {
            text = "|cffff6666WARNING:|r This will delete ALL tracking data for ALL characters.\n\nAre you sure?",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                ns.EnsureDB()
                MajesticBeastTrackerDB = { chars = {}, settings = MajesticBeastTrackerDB.settings }
                ns.EnsureDB()
                ns.UpdateUI()
                print("|cff3FC7EB[MBT]|r ALL data cleared.")
            end,
            timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
        }
        StaticPopup_Show("MBT_CLEAR_ALL")
    end, "|cffff6666Permanently delete all tracking data for every character.|r", true))
end

function ns.OpenSettings()
    if ns.settingsCategoryID then
        Settings.OpenToCategory(ns.settingsCategoryID)
    end
end

-- Init on login
local minimapInit = CreateFrame("Frame")
minimapInit:RegisterEvent("PLAYER_LOGIN")
minimapInit:SetScript("OnEvent", function()
    InitMinimapIcon()
    local ok, err = pcall(InitSettings)
    if not ok then
        print("|cffff3333[MBT] Settings error:|r " .. tostring(err))
    end
    -- Apply saved scale
    ns.EnsureDB()
    frame:SetScale(MajesticBeastTrackerDB.settings.windowScale)
end)
