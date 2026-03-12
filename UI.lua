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
    { itemID = 242299, name = "Sanguithorn Tea", buffName = "Relaxed", itemName = "Sanguithorn Tea" },
    { itemID = 241317, name = "Haranir Phial of Perception", buffName = "Haranir Phial of Perception", spellID = 1236763, itemName = "Haranir Phial of Perception" },
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
local TRAVEL_SPACING = 4
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
local function GetCraftableCount(recipeID)
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

-- Title
-- Title (positioned after consumable icons area)
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, -PAD)
title:SetText(C_ACCENT:WrapTextInColorCode("Majestic Beast Tracker"))

-- Lock indicator
local lockIcon = frame:CreateTexture(nil, "OVERLAY")
lockIcon:SetSize(10, 10)
lockIcon:SetPoint("LEFT", title, "RIGHT", 4, 0)
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
    zLabel:SetFont(zLabel:GetFont(), 7)
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
end

-- Consumable box (floating panel anchored to frame, same row as lure icons)
local CONS_ICON_SIZE = 20
local CONS_SPACING = 4
local CONS_PAD = 8
local CONS_BOX_WIDTH = #CONSUMABLES * (CONS_ICON_SIZE + CONS_SPACING + 28) + CONS_PAD * 2
local CONS_BOX_HEIGHT = ICON_SIZE + 12

local consumableBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
consumableBox:SetSize(CONS_BOX_WIDTH, CONS_BOX_HEIGHT)
consumableBox:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, contentTop - 2 - REAGENT_ROW_HEIGHT + 4)
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
        -- Block if buff still has >20% duration left
        local buffInfo = C_UnitAuras.GetAuraDataBySpellName("player", cons.buffName, "HELPFUL")
        if not buffInfo and cons.itemName ~= cons.buffName then
            buffInfo = C_UnitAuras.GetAuraDataBySpellName("player", cons.itemName, "HELPFUL")
        end
        if buffInfo and buffInfo.duration and buffInfo.duration > 0 and buffInfo.expirationTime then
            local remaining = buffInfo.expirationTime - GetTime()
            if remaining / buffInfo.duration > 0.2 then
                self:SetAttribute("type", nil)
                -- Only print on mouse down, not on up (AnyUp+AnyDown fires twice)
                if not self._blockedMsg or (GetTime() - self._blockedMsg) > 1 then
                    if MajesticBeastTrackerDB.settings.chatNotify ~= false then
                        print("|cff3FC7EB[MBT]|r Buff still has " .. math.ceil(remaining / 60) .. "m left. Not consumed.")
                    end
                    self._blockedMsg = GetTime()
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

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:SetDrawEdge(true)
    btn.cooldown = cd

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

-- Weekly knowledge lines for main window (right-aligned, below stats)
local weeklyMainLines = {}
for i = 1, #ns.SKINNING_WEEKLIES do
    local line = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line:SetFont(line:GetFont(), 9)
    line:SetJustifyH("RIGHT")
    line:Hide()
    weeklyMainLines[i] = line
end

-- Helper: check if player has Engineering as second profession
local function HasEngineering()
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

local function GetStatusText(charData, lureName)
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
        gearPopupTitle:SetText(charKey)
        for _, row in ipairs(gearPopupRows) do
            row:Hide()
            row.label:Hide()
        end
        local noGear = gearPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noGear:SetPoint("TOPLEFT", gearPopupTitle, "BOTTOMLEFT", 0, -4)
        noGear:SetText("|cff666666No gear data (login required)|r")
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

    gearPopupTitle:SetText(ns.GetClassColor(charData.class) .. charKey .. "|r")

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

    return row
end

local function HideAllRows()
    for _, row in ipairs(charRows) do
        row.name:Hide()
        if row.bg then row.bg:Hide() end
        for _, cell in ipairs(row.cells) do
            cell:Hide()
        end
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
        if self:IsShown() and not self:IsMouseOver() and IsMouseButtonDown("LeftButton") then
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

        -- Craftable count (reagents from bags + bank + warbank)
        local craftable = GetCraftableCount(lure.recipeID)
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
    local reagentExtra = showReagents and REAGENT_ROW_HEIGHT or 0

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
            local singleLabel = numLeft == 0 and "|cff00ff00Done|r" or (not anyMissing and "|cff00ff00Ready|r" or nil)
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
                            rBtn.countText:SetPoint("TOPLEFT", rBtn, "BOTTOMLEFT", -2, -1)
                            rBtn.countText:SetJustifyH("LEFT")
                        elseif numR > 1 and j == numR then
                            rBtn.countText:SetPoint("TOPRIGHT", rBtn, "BOTTOMRIGHT", 2, -1)
                            rBtn.countText:SetJustifyH("RIGHT")
                        else
                            rBtn.countText:SetPoint("TOP", rBtn, "BOTTOM", 0, -1)
                            rBtn.countText:SetJustifyH("CENTER")
                        end
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
        if charData.hasSkinning and charData.talentPoints and charData.talentPoints > 0 then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b)
        if a == currentChar then return true end
        if b == currentChar then return false end
        return a < b
    end)

    HideAllRows()

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
        local charData = MajesticBeastTrackerDB.chars[key]
        local classColor = ns.GetClassColor(charData.class)
        local name = key
        if key == currentChar then name = name .. " *" end

        row.nameLabel:SetText(classColor .. name .. "|r")
        row.name:SetScript("OnClick", function(self)
            if gearPopup:IsShown() and gearPopup.currentKey == key then
                gearPopup:Hide()
            else
                gearPopup.currentKey = key
                ShowGearPopup(self, key)
            end
        end)
        row.name:Show()
        if row.bg then row.bg:Show() end

        for i, lure in ipairs(LURES) do
            local cell = row.cells[i]
            cell.charKey = key
            if ns.CanSeeLure(charData, i) then
                local text, r, g, b = GetStatusText(charData, lure.name)
                cell.label:SetText(text)
                cell.label:SetTextColor(r, g, b)
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
                cell.label:SetText("-")
                cell.label:SetTextColor(0.25, 0.25, 0.25)
                cell:SetScript("OnClick", nil)
                cell:SetScript("OnEnter", nil)
                cell:SetScript("OnLeave", nil)
            end
            cell:Show()
        end
    end

    -- Update consumable status
    for i, cons in ipairs(CONSUMABLES) do
        local count = C_Item.GetItemCount(cons.itemName or cons.itemID)
        local buffInfo = C_UnitAuras.GetAuraDataBySpellName("player", cons.buffName, "HELPFUL")
        -- Fallback: try spell ID if name didn't match
        if not buffInfo and cons.spellID and AuraUtil and AuraUtil.FindAuraByName then
            buffInfo = C_UnitAuras.GetAuraDataBySpellName("player", cons.itemName, "HELPFUL")
        end
        local remaining = buffInfo and buffInfo.expirationTime and (buffInfo.expirationTime - GetTime()) or 0
        if buffInfo and remaining > 0 then
            local m = math.ceil(remaining / 60)
            consumableLabels[i]:SetText(m .. "m")
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

        -- Update icon texture
        local tex = C_Item.GetItemIconByID(cons.itemID)
        if tex then consumableIcons[i].icon:SetTexture(tex) end

        -- Position button in consumable box
        if not InCombatLockdown() then
            local btn = consumableButtons[i]
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", consumableBox, "TOPLEFT",
                CONS_PAD + (i - 1) * (CONS_ICON_SIZE + CONS_SPACING + 28), -(CONS_BOX_HEIGHT - CONS_ICON_SIZE) / 2)
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
    local showWormhole = HasEngineering() and PlayerHasToy(WORMHOLE_ITEM.itemID)
    if showWormhole then
        activeTravelBtns[#activeTravelBtns + 1] = wormholeBtn
    end

    -- Resize (include travel row if any travel buttons)
    local n = math.max(#keys, 1)
    local hasTravelRow = #activeTravelBtns > 0
    local travelExtra = hasTravelRow and TRAVEL_ROW_HEIGHT or 0
    local h = TITLE_HEIGHT + 2 + reagentExtra + ICON_ROW_HEIGHT + 5 + n * ROW_HEIGHT + travelExtra + PAD + 4
    local w = PAD * 2 + 8 + NAME_COL_WIDTH + #LURES * COL_WIDTH
    frame:SetSize(w, h)

    -- Position travel buttons at bottom
    if not InCombatLockdown() then
        local travelY = -(TITLE_HEIGHT + 2 + reagentExtra + ICON_ROW_HEIGHT + 5 + n * ROW_HEIGHT + 2)
        if hasTravelRow then
            travelSep:ClearAllPoints()
            travelSep:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, travelY)
            travelSep:SetPoint("RIGHT", frame, "RIGHT", -(PAD + 4), 0)
            travelSep:Show()
        else
            travelSep:Hide()
        end

        -- Hide all first
        for _, btn in ipairs(travelButtons) do btn:Hide() end
        wormholeBtn:Hide()

        -- Show + position active ones
        for idx, btn in ipairs(activeTravelBtns) do
            local tex = C_Item.GetItemIconByID(btn.itemInfo.itemID)
            if tex then btn.icon:SetTexture(tex) end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT",
                PAD + 4 + (idx - 1) * (TRAVEL_ICON_SIZE + TRAVEL_SPACING),
                travelY - 3)
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
        local statsY = travelY - 3 - TRAVEL_ICON_SIZE / 2
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
