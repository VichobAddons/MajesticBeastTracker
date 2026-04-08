------------------------------------------------------
-- MajesticBeastTracker UI - Visual tracker
-- PSL-inspired style with BackdropTemplate
------------------------------------------------------

local addonName, ns = ...
local LURES = ns.LURES
local WEEKLIES = ns.SKINNING_WEEKLIES

-- Constants
ns.CHECKMARK_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"

-- Layout
local ICON_SIZE = 26
local COL_WIDTH = 62
local NAME_COL_WIDTH = 150
local BASE_NAME_COL_WIDTH = 150
local ROW_HEIGHT = 18
local TOOLBAR_HEIGHT = 22
local BOTTOM_BAR_HEIGHT = 20
local TITLE_HEIGHT = 4  -- reduced after title moved to toolbar
local ZONE_LABEL_HEIGHT = 10
local ICON_ROW_HEIGHT = ICON_SIZE + 6 + ZONE_LABEL_HEIGHT
local REAGENT_ICON_SIZE = 20
local REAGENT_COUNT_HEIGHT = 10
local REAGENT_GAP = 8
local REAGENT_ROW_HEIGHT = REAGENT_ICON_SIZE + REAGENT_COUNT_HEIGHT + 4
local PAD = 8

-- Consumables to track (test with Holiday Cheesewheel)
local CONSUMABLES = {
    { itemID = 242299, name = "Sanguithorn Tea", buffSpellID = 1269152, minLevel = 80 },
    { itemID = 241317, name = "Haranir Phial of Perception", buffSpellID = 1236763, altItemID = 241316, minLevel = 81 },
    { itemID = 238367, name = "Root Crab", buffSpellID = 1235216, minLevel = 80, stackable = true },
    { itemID = 237372, name = "Refulgent Razorstone", minLevel = 80, isToolEnchant = true },
    { spellID = 1223388, name = "Sharpen Your Knife", isSpell = true, minLevel = 80 },
}
local NUM_EXTRA_COLS = #CONSUMABLES
ns.CONSUMABLE_ITEMS = CONSUMABLES

-- Travel items (shown at bottom of frame)
local TRAVEL_ITEMS = {
    { itemID = 6948, name = "Hearthstone" },
    { itemID = 140192, name = "Dalaran Hearthstone", isToy = true },
    { itemID = 253629, name = "Personal Key to the Arcantina", isToy = true },
}
-- Wormhole Generator: conditional on Engineering profession + item in bags
local WORMHOLE_ITEM = { itemID = 248485, name = "Wormhole Generator: Quel'Thalas", spellID = 1229928, requiresEngineering = true, isToy = true }
-- Mage Teleport: Silvermoon City (conditional on class)
local MAGE_TELEPORT = { spellID = 1259190, name = "Teleport: Silvermoon City", isSpell = true, requiresClass = "MAGE" }
-- Vulpera Return to Camp (conditional on race)
local VULPERA_RETURN = { spellID = 312372, name = "Return to Camp", isSpell = true, requiresRace = "Vulpera" }
local TRAVEL_ICON_SIZE = 22
local TRAVEL_SPACING = 3
local TRAVEL_ROW_HEIGHT = TRAVEL_ICON_SIZE + 8

-- Colors
local C_ACCENT = CreateColor(0.82, 0.71, 0.35)
local C_BORDER_RGB = { 0.82, 0.71, 0.35 }
local C_ROW_ALT = { 0.1, 0.1, 0.14, 0.4 }
local C_SEPARATOR = { 0.82, 0.71, 0.35, 0.3 }

local MEDIA_PATH = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

local BACKDROP = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- Expose shared constants for other files (LootUI.lua, Settings.lua)
ns.MEDIA_PATH = MEDIA_PATH
ns.BACKDROP = BACKDROP
ns.C_BORDER_RGB = C_BORDER_RGB
ns.C_ACCENT = C_ACCENT
ns.ROW_HEIGHT = ROW_HEIGHT
ns.PAD = PAD
ns.NAME_COL_WIDTH = NAME_COL_WIDTH
ns.COL_WIDTH = COL_WIDTH

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
ns.frame = frame
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
    -- Reposition loot summary if open
    if ns.lootSummary and ns.lootSummary:IsShown() and ns.RepositionLootSummary then
        ns.RepositionLootSummary()
    end
end)

-- Autohide: fade in/out on hover
local function IsMouseOverAnyMBT()
    if frame:IsMouseOver() then return true end
    if ns.lootSummary and ns.lootSummary:IsShown() and ns.lootSummary:IsMouseOver() then return true end
    if ns.lootEditor and ns.lootEditor:IsShown() and ns.lootEditor:IsMouseOver() then return true end
    return false
end

function ns.RefreshAutoHide()
    if not frame:IsShown() then return end
    ns.EnsureDB()
    if MajesticBeastTrackerDB.settings.autoHide and not IsMouseOverAnyMBT() then
        UIFrameFadeOut(frame, 0.5, frame:GetAlpha(), 0)
        if ns.lootSummary and ns.lootSummary:IsShown() then
            UIFrameFadeOut(ns.lootSummary, 0.5, ns.lootSummary:GetAlpha(), 0)
        end
        if ns.lootEditor and ns.lootEditor:IsShown() then
            UIFrameFadeOut(ns.lootEditor, 0.5, ns.lootEditor:GetAlpha(), 0)
        end
    else
        UIFrameFadeIn(frame, 0.1, frame:GetAlpha(), 1)
        if ns.lootSummary and ns.lootSummary:IsShown() then
            UIFrameFadeIn(ns.lootSummary, 0.1, ns.lootSummary:GetAlpha(), 1)
        end
        if ns.lootEditor and ns.lootEditor:IsShown() then
            UIFrameFadeIn(ns.lootEditor, 0.1, ns.lootEditor:GetAlpha(), 1)
        end
    end
end

local function OnFrameEnter()
    ns.EnsureDB()
    if MajesticBeastTrackerDB.settings.autoHide then
        UIFrameFadeIn(frame, 0.1, frame:GetAlpha(), 1)
    end
end
local function OnFrameLeave()
    ns.EnsureDB()
    if MajesticBeastTrackerDB.settings.autoHide and not IsMouseOverAnyMBT() then
        UIFrameFadeOut(frame, 0.5, frame:GetAlpha(), 0)
    end
end
frame:SetScript("OnEnter", OnFrameEnter)
frame:SetScript("OnLeave", OnFrameLeave)
frame:SetScript("OnHide", function()
    if ns.lootSummary then ns.lootSummary:Hide() end
    if ns.lootEditor then ns.lootEditor:Hide() end
    if settingsDropdown then settingsDropdown:Hide() end
    if settingsSubmenu then settingsSubmenu:Hide() end
end)

------------------------------------------------------
-- Bottom Bar (timer + logout)
------------------------------------------------------
local bottomBar = CreateFrame("Frame", nil, frame)
bottomBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 4)
bottomBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
bottomBar:SetHeight(BOTTOM_BAR_HEIGHT)
bottomBar:SetFrameLevel(frame:GetFrameLevel() + 25)

local bottomBarBg = bottomBar:CreateTexture(nil, "BACKGROUND")
bottomBarBg:SetAllPoints()
bottomBarBg:SetColorTexture(0, 0, 0, 0.4)

local bottomBarSep = bottomBar:CreateTexture(nil, "ARTWORK")
bottomBarSep:SetHeight(1)
bottomBarSep:SetPoint("TOPLEFT", bottomBar, "TOPLEFT", 0, 0)
bottomBarSep:SetPoint("TOPRIGHT", bottomBar, "TOPRIGHT", 0, 0)
bottomBarSep:SetColorTexture(0.82, 0.71, 0.35, 0.3)

-- Logout button (right side of bottom bar)
local logoutBtn = CreateFrame("Button", nil, bottomBar, "SecureActionButtonTemplate")
logoutBtn:SetSize(BOTTOM_BAR_HEIGHT, BOTTOM_BAR_HEIGHT)
logoutBtn:SetAttribute("type", "macro")
logoutBtn:SetAttribute("macrotext", "/logout")
logoutBtn:RegisterForClicks("AnyUp", "AnyDown")
local logoutText = logoutBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
logoutText:SetFont(logoutText:GetFont(), 9)
logoutText:SetText("|cff999999Logout|r")
logoutText:SetPoint("CENTER")
logoutBtn:SetWidth(logoutText:GetStringWidth() + 8)
logoutBtn:SetPoint("RIGHT", bottomBar, "RIGHT", -2, 0)
logoutBtn:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight")
logoutBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
    GameTooltip:AddLine("Logout", 1, 1, 1)
    GameTooltip:AddLine("Switch character quickly", 0.5, 0.8, 1)
    GameTooltip:Show()
end)
logoutBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Timer display (left side of bottom bar)
local timerLabel = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
timerLabel:SetFont(timerLabel:GetFont(), 9)
timerLabel:SetPoint("LEFT", bottomBar, "LEFT", 6, 0)
timerLabel:SetTextColor(0.5, 0.5, 0.5)
timerLabel:Hide()

local timerBtn = CreateFrame("Button", nil, bottomBar)
timerBtn:SetHeight(BOTTOM_BAR_HEIGHT)
timerBtn:SetPoint("LEFT", bottomBar, "LEFT", 2, 0)
timerBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
timerBtn:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then
        ns.ResetTimer()
    elseif ns.IsTimerRunning() then
        ns.StopTimer()
    else
        ns.StartTimer()
    end
end)
timerBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
    GameTooltip:AddLine("Route Timer", 1, 0.82, 0)
    if ns.IsTimerRunning() then
        GameTooltip:AddLine("Click to stop", 0.7, 0.7, 0.7)
    else
        GameTooltip:AddLine("Click to start", 0.7, 0.7, 0.7)
    end
    if ns.GetTimerElapsed() > 0 then
        GameTooltip:AddLine("Right-click to reset", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end)
timerBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

------------------------------------------------------
-- Toolbar
------------------------------------------------------
local toolbar = CreateFrame("Frame", nil, frame)
toolbar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
toolbar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
toolbar:SetHeight(TOOLBAR_HEIGHT)
toolbar:SetFrameLevel(frame:GetFrameLevel() + 25)

-- Toolbar background
local toolbarBg = toolbar:CreateTexture(nil, "BACKGROUND")
toolbarBg:SetAllPoints()
toolbarBg:SetColorTexture(0, 0, 0, 0.4)

-- Toolbar separator line
local toolbarSep = toolbar:CreateTexture(nil, "ARTWORK")
toolbarSep:SetHeight(1)
toolbarSep:SetPoint("BOTTOMLEFT", toolbar, "BOTTOMLEFT", 0, 0)
toolbarSep:SetPoint("BOTTOMRIGHT", toolbar, "BOTTOMRIGHT", 0, 0)
toolbarSep:SetColorTexture(0.82, 0.71, 0.35, 0.3)

-- Toolbar title (left side)
local toolbarTitle = toolbar:CreateFontString(nil, "OVERLAY")
toolbarTitle:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
toolbarTitle:SetPoint("LEFT", toolbar, "LEFT", TOOLBAR_HEIGHT + 4, 0)
toolbarTitle:SetTextColor(0.6, 0.6, 0.6)
toolbarTitle:SetText("|cffD1B559MBT|r")  -- version set after GetMBTVersion is defined below

-- Helper: create a toolbar icon button
local TOOLBAR_ICON_SIZE = 16
local TOOLBAR_BTN_PADDING = 3
local C_TOOLBAR_ICON = { 0.82, 0.71, 0.35 }  -- gold/amber default
local C_TOOLBAR_ICON_HOVER = { 1.0, 0.88, 0.44 }  -- brighter gold on hover
ns.C_TOOLBAR_ICON = C_TOOLBAR_ICON
ns.C_TOOLBAR_ICON_HOVER = C_TOOLBAR_ICON_HOVER
local function CreateToolbarButton(parent, texture, tooltipTitle, tooltipDesc, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(TOOLBAR_HEIGHT, TOOLBAR_HEIGHT)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(TOOLBAR_ICON_SIZE, TOOLBAR_ICON_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture(texture)
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetVertexColor(C_TOOLBAR_ICON[1], C_TOOLBAR_ICON[2], C_TOOLBAR_ICON[3], 1)
    btn.icon = icon
    btn:SetScript("OnEnter", function(self)
        icon:SetVertexColor(C_TOOLBAR_ICON_HOVER[1], C_TOOLBAR_ICON_HOVER[2], C_TOOLBAR_ICON_HOVER[3], 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
        if type(tooltipTitle) == "function" then
            tooltipTitle(self)
        else
            GameTooltip:AddLine(tooltipTitle, 1, 1, 1)
            if tooltipDesc then
                GameTooltip:AddLine(tooltipDesc, 0.5, 0.8, 1, true)
            end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        icon:SetVertexColor(C_TOOLBAR_ICON[1], C_TOOLBAR_ICON[2], C_TOOLBAR_ICON[3], 1)
        GameTooltip:Hide()
        if ns.HideLootTooltip then ns.HideLootTooltip() end
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end
ns.CreateToolbarButton = CreateToolbarButton

-- Close button
local closeBtn = CreateToolbarButton(toolbar,
    MEDIA_PATH .. "Icon_Close",
    "Close", nil,
    function() ns.HideFrame() end)
closeBtn:SetPoint("RIGHT", toolbar, "RIGHT", -2, 0)
closeBtn.icon:SetTexCoord(0, 1, 0, 1)
closeBtn:SetScript("OnEnter", function(self)
    closeBtn.icon:SetVertexColor(1, 0.3, 0.3, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
    GameTooltip:AddLine("Close", 1, 1, 1)
    GameTooltip:Show()
end)
closeBtn:SetScript("OnLeave", function()
    closeBtn.icon:SetVertexColor(C_TOOLBAR_ICON[1], C_TOOLBAR_ICON[2], C_TOOLBAR_ICON[3], 1)
    GameTooltip:Hide()
end)

-- Settings dropdown button (gear icon, right of close)
local settingsBtn = CreateToolbarButton(toolbar,
    MEDIA_PATH .. "Icon_Settings",
    "Settings", nil, nil)
settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
settingsBtn.icon:SetTexCoord(0, 1, 0, 1)

-- Settings dropdown frame (custom, gold-themed)
local settingsDropdown = CreateFrame("Frame", "MBT_SettingsDropdown", UIParent, "BackdropTemplate")
settingsDropdown:SetBackdrop(ns.BACKDROP)
settingsDropdown:SetBackdropColor(0, 0, 0, 0.97)
settingsDropdown:SetBackdropBorderColor(C_BORDER_RGB[1], C_BORDER_RGB[2], C_BORDER_RGB[3])
settingsDropdown:SetFrameStrata("DIALOG")
settingsDropdown:SetFrameLevel(500)
settingsDropdown:EnableMouse(true)
settingsDropdown:Hide()
settingsDropdown:SetClampedToScreen(true)

local SD_WIDTH = 230
local SD_ROW_HEIGHT = 18
local SD_PAD = 6
local SD_GOLD = { 0.82, 0.71, 0.35 }
local SD_TEXT = { 0.9, 0.9, 0.9 }
local SD_DIM = { 0.5, 0.5, 0.5 }
local SD_ARROW = " |cffD1B559>|r"

-- Category definitions: { name, buildFunc }
local sdCurrentView = nil  -- nil = main menu, string = category name
local sdCategories = {}
local sdRowFrames = {}

local function DefineCategories()
    sdCategories = {}
    ns.EnsureDB()
    local s = MajesticBeastTrackerDB.settings

    sdCategories[#sdCategories + 1] = { name = "Route", items = function()
        local t = {}
        for _, lure in ipairs(ns.LURES) do
            local ln = lure.name
            local flatKey = "routeSkip_" .. ln:gsub("[%s']", "")
            t[#t + 1] = { text = "Skip " .. ln, get = function()
                return (s.routeSkip and s.routeSkip[ln]) or s[flatKey] or false
            end, set = function()
                if not s.routeSkip then s.routeSkip = {} end
                local newVal = not ((s.routeSkip[ln]) or s[flatKey] or false)
                s.routeSkip[ln] = newVal
                s[flatKey] = newVal
            end }
        end
        t[#t + 1] = { text = "Hide Skipped Columns", get = function() return s.routeHideSkipped end, set = function() s.routeHideSkipped = not s.routeHideSkipped end }
        t[#t + 1] = { text = "Auto-Waypoint", get = function() return s.autoRouteWaypoint end, set = function() s.autoRouteWaypoint = not s.autoRouteWaypoint end }
        return t
    end }

    sdCategories[#sdCategories + 1] = { name = "Reagents & AH", items = function()
        return {
            { text = "Show Reagent Icons", get = function() return s.showReagents ~= false end, set = function() s.showReagents = not (s.showReagents ~= false) end },
            { text = "Count All Characters", get = function() return s.reagentAllChars end, set = function() s.reagentAllChars = not s.reagentAllChars end },
            { text = "Show Missing Count", get = function() return s.showMissingCount end, set = function() s.showMissingCount = not s.showMissingCount end },
            { text = "Autofill AH Quantity", get = function() return s.ahAutofillQuantity end, set = function() s.ahAutofillQuantity = not s.ahAutofillQuantity end },
        }
    end }

    sdCategories[#sdCategories + 1] = { name = "Consumables", items = function()
        local t = {}
        for _, cons in ipairs(ns.CONSUMABLE_ITEMS) do
            local cID = cons.itemID or cons.spellID
            t[#t + 1] = { text = cons.name, get = function() return s["consShow_" .. cID] ~= false end,
                set = function() s["consShow_" .. cID] = not (s["consShow_" .. cID] ~= false) end }
        end
        return t
    end }

    sdCategories[#sdCategories + 1] = { name = "Loot Tracking", items = function()
        return {
            { text = "Enable Loot Tracking", get = function() return s.lootTracking ~= false end, set = function() s.lootTracking = not (s.lootTracking ~= false) end },
            { text = "Integrate TSM Prices", get = function() return s.tsmIntegration ~= false end, set = function() s.tsmIntegration = not (s.tsmIntegration ~= false) end },
        }
    end }

    sdCategories[#sdCategories + 1] = { name = "Warband Bank", items = function()
        return {
            { text = "Enable Deposit", get = function() return s.warbankDeposit end, set = function() s.warbankDeposit = not s.warbankDeposit end },
            { text = "Auto Deposit on Open", get = function() return s.warbankAutoDeposit end, set = function() s.warbankAutoDeposit = not s.warbankAutoDeposit end },
            { text = "Deposit Beast Rewards", get = function() return s.warbankDepositRewards end, set = function() s.warbankDepositRewards = not s.warbankDepositRewards end },
            { text = "Deposit Lure Reagents", get = function() return s.warbankDepositReagents end, set = function() s.warbankDepositReagents = not s.warbankDepositReagents end },
        }
    end }

    sdCategories[#sdCategories + 1] = { name = "Display", items = function()
        return {
            { text = "Show Weekly Knowledge", get = function() return s.showKnowledge ~= false end, set = function() s.showKnowledge = not (s.showKnowledge ~= false) end },
            { text = "Hide in Combat", get = function() return s.hideInCombat end, set = function() s.hideInCombat = not s.hideInCombat end },
            { text = "Disable in Instances", get = function() return s.disableInInstance ~= false end, set = function() s.disableInInstance = not (s.disableInInstance ~= false) end },
            { text = "Lock Frame", get = function() return s.locked end, set = function() s.locked = not s.locked end },
            { text = "Chat Notifications", get = function() return s.chatNotify ~= false end, set = function() s.chatNotify = not (s.chatNotify ~= false) end },
            { text = "Hide on Non-Skinners", get = function() return s.hideNonSkinner end, set = function() s.hideNonSkinner = not s.hideNonSkinner end },
        }
    end }

    sdCategories[#sdCategories + 1] = { name = "Borders", items = function()
        return {
            { text = "Lure + Reagent Borders", get = function() return s.showLureBorders end, set = function() s.showLureBorders = not s.showLureBorders end },
            { text = "Travel + Consumable Borders", get = function() return s.showConsBorders ~= false end, set = function() s.showConsBorders = not (s.showConsBorders ~= false) end },
        }
    end }
end

-- Submenu frame (fly-out, appears beside main menu on hover)
local settingsSubmenu = CreateFrame("Frame", "MBT_SettingsSubmenu", UIParent, "BackdropTemplate")
settingsSubmenu:SetBackdrop(ns.BACKDROP)
settingsSubmenu:SetBackdropColor(0, 0, 0, 0.97)
settingsSubmenu:SetBackdropBorderColor(C_BORDER_RGB[1], C_BORDER_RGB[2], C_BORDER_RGB[3])
settingsSubmenu:SetFrameStrata("DIALOG")
settingsSubmenu:SetFrameLevel(501)
settingsSubmenu:EnableMouse(true)
settingsSubmenu:Hide()
settingsSubmenu:SetClampedToScreen(true)

local sdMainRowFrames = {}
local sdSubRowFrames = {}
local sdActiveCategory = nil

local function GetRowFrame(pool, parent, i)
    if not pool[i] then
        local f = CreateFrame("Button", nil, parent)
        f:SetHeight(SD_ROW_HEIGHT)
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetFont(label:GetFont(), 10)
        label:SetPoint("LEFT", 4, 0)
        label:SetJustifyH("LEFT")
        f.label = label
        local right = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        right:SetFont(right:GetFont(), 10)
        right:SetPoint("LEFT", SD_WIDTH - SD_PAD * 2 - 60, 0)
        right:SetJustifyH("LEFT")
        f.right = right
        local hl = f:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.05)
        f.hl = hl
        pool[i] = f
    end
    pool[i]:SetParent(parent)
    return pool[i]
end

-- Show submenu for a category, anchored to the hovered row
local function ShowSubmenu(cat, anchorRow)
    local items = cat.items()
    local y = -SD_PAD
    local idx = 0

    -- Header
    idx = idx + 1
    local hf = GetRowFrame(sdSubRowFrames, settingsSubmenu, idx)
    hf:ClearAllPoints()
    hf:SetPoint("TOPLEFT", settingsSubmenu, "TOPLEFT", SD_PAD, y)
    hf:SetPoint("TOPRIGHT", settingsSubmenu, "TOPRIGHT", -SD_PAD, y)
    hf:SetHeight(SD_ROW_HEIGHT)
    hf.label:SetText("|cffD1B559" .. cat.name .. "|r")
    hf.right:SetText("")
    hf.hl:Hide()
    hf:EnableMouse(false)
    hf:SetScript("OnClick", nil)
    hf:SetScript("OnEnter", nil)
    hf:SetScript("OnLeave", nil)
    hf:Show()
    y = y - SD_ROW_HEIGHT

    for _, item in ipairs(items) do
        idx = idx + 1
        local f = GetRowFrame(sdSubRowFrames, settingsSubmenu, idx)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", settingsSubmenu, "TOPLEFT", SD_PAD, y)
        f:SetPoint("TOPRIGHT", settingsSubmenu, "TOPRIGHT", -SD_PAD, y)
        f:SetHeight(SD_ROW_HEIGHT)
        local isOn = item.get()
        f.label:SetText(item.text)
        f.label:SetTextColor(unpack(isOn and SD_TEXT or SD_DIM))
        f.right:ClearAllPoints()
        f.right:SetPoint("LEFT", SD_WIDTH - SD_PAD * 2 - 60, 0)
        f.right:SetJustifyH("LEFT")
        f.right:SetText(isOn and "|cff00ff00Enabled|r" or "|cffff4444Disabled|r")
        f.hl:Show()
        f:EnableMouse(true)
        local itemRef = item
        local catRef = cat
        f:SetScript("OnClick", function()
            itemRef.set()
            ns.UpdateUI()
            ShowSubmenu(catRef, anchorRow)
        end)
        f:SetScript("OnEnter", nil)
        f:SetScript("OnLeave", nil)
        f:Show()
        y = y - SD_ROW_HEIGHT
    end

    for i = idx + 1, #sdSubRowFrames do sdSubRowFrames[i]:Hide() end
    settingsSubmenu:SetSize(SD_WIDTH, math.abs(y) + SD_PAD)

    -- Position: try right side of main menu, fall back to left
    settingsSubmenu:ClearAllPoints()
    local mainRight = settingsDropdown:GetRight() or 0
    local screenW = GetScreenWidth() * UIParent:GetEffectiveScale()
    if mainRight + SD_WIDTH < screenW then
        settingsSubmenu:SetPoint("TOPLEFT", anchorRow, "TOPRIGHT", 0, SD_PAD)
    else
        settingsSubmenu:SetPoint("TOPRIGHT", anchorRow, "TOPLEFT", 0, SD_PAD)
    end
    settingsSubmenu:Show()
    sdActiveCategory = cat.name
end

-- Populate main menu
local function PopulateMainMenu()
    DefineCategories()
    local y = -SD_PAD
    local idx = 0

    for _, cat in ipairs(sdCategories) do
        idx = idx + 1
        local f = GetRowFrame(sdMainRowFrames, settingsDropdown, idx)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", settingsDropdown, "TOPLEFT", SD_PAD, y)
        f:SetPoint("TOPRIGHT", settingsDropdown, "TOPRIGHT", -SD_PAD, y)
        f:SetHeight(SD_ROW_HEIGHT)
        f.label:SetText(cat.name)
        f.label:SetTextColor(SD_TEXT[1], SD_TEXT[2], SD_TEXT[3])
        f.right:ClearAllPoints()
        f.right:SetPoint("RIGHT", -4, 0)
        f.right:SetJustifyH("RIGHT")
        f.right:SetText(SD_ARROW)
        f.hl:Show()
        f:EnableMouse(true)
        local catRef = cat
        f:SetScript("OnClick", nil)
        f:SetScript("OnEnter", function(self)
            if sdActiveCategory ~= catRef.name then
                ShowSubmenu(catRef, self)
            end
        end)
        f:SetScript("OnLeave", function()
            -- Submenu hides on its own via mouse check
        end)
        f:Show()
        y = y - SD_ROW_HEIGHT
    end

    for i = idx + 1, #sdMainRowFrames do sdMainRowFrames[i]:Hide() end
    settingsDropdown:SetSize(SD_WIDTH, math.abs(y) + SD_PAD)
end

local PopulateSettingsDropdown = PopulateMainMenu

-- Toggle dropdown on settings button click
settingsBtn:SetScript("OnClick", function(self)
    if settingsDropdown:IsShown() then
        settingsDropdown:Hide()
        settingsSubmenu:Hide()
    else
        sdActiveCategory = nil
        PopulateMainMenu()
        settingsDropdown:ClearAllPoints()
        settingsDropdown:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
        settingsDropdown:Show()
    end
end)

-- Close dropdown + submenu when clicking outside
settingsDropdown:SetScript("OnShow", function()
    settingsDropdown:RegisterEvent("GLOBAL_MOUSE_DOWN")
end)
settingsDropdown:SetScript("OnHide", function()
    settingsDropdown:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    settingsSubmenu:Hide()
    sdActiveCategory = nil
end)
settingsDropdown:SetScript("OnEvent", function(self, event)
    if event == "GLOBAL_MOUSE_DOWN" then
        if not self:IsMouseOver() and not settingsBtn:IsMouseOver()
           and not settingsSubmenu:IsMouseOver() then
            self:Hide()
        end
    end
end)

-- Autohide toggle button (eye icon) — left side of toolbar, before title
local autoHideBtn = CreateToolbarButton(toolbar,
    MEDIA_PATH .. "Icon_Show",
    function(self)
        ns.EnsureDB()
        local state = MajesticBeastTrackerDB.settings.autoHide
        GameTooltip:AddLine(state and "Auto Hide: ON" or "Auto Hide: OFF", 1, 1, 1)
        GameTooltip:AddLine("Click to toggle. Fades tracker when mouse leaves.", 0.5, 0.8, 1, true)
    end,
    nil, nil)
autoHideBtn:SetScript("OnClick", function(self)
    ns.EnsureDB()
    MajesticBeastTrackerDB.settings.autoHide = not MajesticBeastTrackerDB.settings.autoHide
    ns.RefreshAutoHide()
    local state = MajesticBeastTrackerDB.settings.autoHide
    self.icon:SetTexture(MEDIA_PATH .. (state and "Icon_Show" or "Icon_Hide"))
    self.icon:SetAlpha(state and 1.0 or 0.4)
end)
autoHideBtn:SetPoint("LEFT", toolbar, "LEFT", 2, 0)
autoHideBtn.icon:SetTexCoord(0, 1, 0, 1)
local autoHideIcon = autoHideBtn.icon

-- Title removed — version shown in toolbar ("MBT vX")
local function GetMBTVersion()
    local devLoaded = C_AddOns.IsAddOnLoaded("MajesticBeastTrackerDev")
    if devLoaded then
        return (C_AddOns.GetAddOnMetadata("MajesticBeastTrackerDev", "Version") or "?") .. " Dev"
    end
    return C_AddOns.GetAddOnMetadata("MajesticBeastTracker", "Version") or "?"
end
toolbarTitle:SetText("|cffD1B559Majestic Beast Tracker|r v" .. GetMBTVersion())

-- Lock indicator (shown in toolbar)
local lockIcon = toolbar:CreateTexture(nil, "OVERLAY")
lockIcon:SetSize(10, 10)
lockIcon:SetPoint("LEFT", toolbarTitle, "RIGHT", 4, 0)
lockIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
lockIcon:SetVertexColor(0.6, 0.6, 0.6)
lockIcon:Hide()

-- Toggle fish button (show/hide reagent icons)
local fishBtn = CreateToolbarButton(toolbar,
    MEDIA_PATH .. "Icon_Reagents",
    function(self)
        local shown = MajesticBeastTrackerDB.settings.showReagents ~= false
        GameTooltip:AddLine(shown and "Hide Reagents" or "Show Reagents", 1, 1, 1)
    end,
    nil,
    function()
        local settings = MajesticBeastTrackerDB.settings
        if settings.showReagents == nil then settings.showReagents = true end
        settings.showReagents = not settings.showReagents
        ns.UpdateUI()
    end)
fishBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -2, 0)
local fishIcon = fishBtn.icon

-- Global loot summary button (goblin icon)
local globalGoblinBtn = CreateToolbarButton(toolbar,
    MEDIA_PATH .. "Icon_Results",
    function(self)
        ns.EnsureDB()
        local resetLoot, allTimeLoot, globalPrices = ns.GetGlobalLoot()
        if resetLoot or allTimeLoot then
            ns.ShowLootTooltip(self, "Loot Summary (All Characters)", resetLoot, allTimeLoot, globalPrices)
            return  -- ShowLootTooltip handles display, skip GameTooltip:Show
        else
            GameTooltip:AddLine("Loot Summary", 0.82, 0.71, 0.35)
            GameTooltip:AddLine("No loot data yet", 0.5, 0.5, 0.5)
        end
    end,
    nil,
    function() ns.ToggleLootSummary() end)
ns.globalGoblinIcon = globalGoblinBtn.icon
ns.globalGoblinBtn = globalGoblinBtn

-- Warband Bank deposit button (bank icon, only visible when bank is open)
local warbankBtn = CreateToolbarButton(toolbar,
    MEDIA_PATH .. "Icon_Bank",
    function(self)
        GameTooltip:AddLine("Deposit Reagents to Warband Bank", 0.82, 0.71, 0.35)
        GameTooltip:AddLine("Click to deposit all tracked skinning reagents.", 0.8, 0.8, 0.8, true)
    end,
    nil,
    function() ns.DepositTrackedToWarbank() end)
warbankBtn:Hide()
ns.warbankBtn = warbankBtn

-- Auctionator shopping list button
local auctionatorBtn = CreateToolbarButton(toolbar,
    MEDIA_PATH .. "Icon_ShoppingList",
    function(self)
        GameTooltip:AddLine("Create Auctionator Shopping List", 0.82, 0.71, 0.35)
        GameTooltip:AddLine("Creates/updates 'MBT Reagents' list with all missing reagents.", 0.8, 0.8, 0.8, true)
    end,
    nil,
    function() ns.CreateAuctionatorShoppingList() end)
auctionatorBtn:Hide()
ns.auctionatorBtn = auctionatorBtn

-- Toggle TSM prices button (coin icon)
local coinBtn = CreateToolbarButton(toolbar,
    MEDIA_PATH .. "Icon_Coins",
    function(self)
        local enabled = MajesticBeastTrackerDB.settings.tsmIntegration
        if not TSM_API then
            GameTooltip:AddLine("TSM not installed", 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine(enabled and "Hide TSM Prices" or "Show TSM Prices", 1, 1, 1)
        end
    end,
    nil,
    function()
        if not TSM_API then return end
        local settings = MajesticBeastTrackerDB.settings
        settings.tsmIntegration = not settings.tsmIntegration
        ns.UpdateUI()
    end)
coinBtn:SetPoint("RIGHT", fishBtn, "LEFT", -2, 0)
local coinIcon = coinBtn.icon

------------------------------------------------------
-- Content area
------------------------------------------------------

local contentTop = -(TOOLBAR_HEIGHT + TITLE_HEIGHT + 2)

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
    box:SetBackdropBorderColor(C_BORDER_RGB[1], C_BORDER_RGB[2], C_BORDER_RGB[3], 0.7)
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


-- 1-second ticker for real-time consumable buff timers + route timer
C_Timer.NewTicker(3, function()
    if ns.isInInstance then return end
    if InCombatLockdown() then return end
    if frame:IsShown() then
        ns.RefreshConsumableLabels()
        if ns.IsTimerRunning() then
            timerLabel:SetText("|cff00ff00" .. ns.FormatTimerElapsed() .. "|r")
            timerBtn:SetWidth(math.max(timerLabel:GetStringWidth() + 4, 40))
            timerLabel:Show()
            timerBtn:Show()
        end
    end
end)

-- Separator under icons
ns.iconSep = frame:CreateTexture(nil, "ARTWORK")
ns.iconSep:SetHeight(1)
ns.iconSep:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, contentTop - REAGENT_ROW_HEIGHT - ICON_ROW_HEIGHT - 2)
ns.iconSep:SetPoint("RIGHT", frame, "RIGHT", -(PAD + 4), 0)
ns.iconSep:SetColorTexture(unpack(C_SEPARATOR))

------------------------------------------------------
-- Travel buttons (bottom of frame, below character rows)
------------------------------------------------------

local travelButtons = {}
ns.travelSep = frame:CreateTexture(nil, "ARTWORK")
ns.travelSep:SetHeight(1)
ns.travelSep:SetColorTexture(unpack(C_SEPARATOR))
ns.travelSep:Hide()

-- Travel box (border container, same style as consumable box)
local travelBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
travelBox:SetSize(NAME_COL_WIDTH, TRAVEL_ICON_SIZE + 8)
travelBox:SetBackdrop(BACKDROP)
travelBox:SetBackdropColor(0, 0, 0, 0.9)
travelBox:SetBackdropBorderColor(C_BORDER_RGB[1], C_BORDER_RGB[2], C_BORDER_RGB[3], 0.7)
travelBox:SetFrameStrata("MEDIUM")
travelBox:SetFrameLevel(201)
ns.travelBox = travelBox

local function CreateTravelButton(index, itemInfo)
    local btn = CreateFrame("Button", "MBT_TravelBtn" .. index, frame, "SecureActionButtonTemplate")
    btn:SetSize(TRAVEL_ICON_SIZE, TRAVEL_ICON_SIZE)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:Hide()

    if itemInfo.isSpell then
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", itemInfo.spellID)
    elseif itemInfo.isToy then
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
        if itemInfo.isSpell then
            GameTooltip:SetSpellByID(itemInfo.spellID)
        elseif itemInfo.isToy then
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

-- Create static travel buttons (Hearthstone + Dalaran HS + Arcantina)
for i, item in ipairs(TRAVEL_ITEMS) do
    travelButtons[i] = CreateTravelButton(i, item)
end

-- Hearthstone slot: replaceable by dragging a toy onto it
local hsBtn = travelButtons[1]

-- Apply a custom hearthstone toy to the HS slot
local function ApplyCustomHearthstone(toyItemID)
    if InCombatLockdown() then return end
    ns.EnsureDB()
    if toyItemID then
        MajesticBeastTrackerDB.settings.hearthstoneToy = toyItemID
        hsBtn:SetAttribute("type", "toy")
        hsBtn:SetAttribute("toy", toyItemID)
        hsBtn:SetAttribute("item", nil)
        hsBtn.itemInfo = { itemID = toyItemID, name = C_Item.GetItemNameByID(toyItemID) or "Hearthstone", isToy = true, isCustomHS = true }
        local tex = ns.GetItemIcon(toyItemID)
        if tex then hsBtn.icon:SetTexture(tex) end
    else
        -- Reset to default Hearthstone
        MajesticBeastTrackerDB.settings.hearthstoneToy = nil
        hsBtn:SetAttribute("type", "item")
        hsBtn:SetAttribute("item", "Hearthstone")
        hsBtn:SetAttribute("toy", nil)
        hsBtn.itemInfo = TRAVEL_ITEMS[1]
        local tex = ns.GetItemIcon(6948)
        if tex then hsBtn.icon:SetTexture(tex) end
    end
end

-- Extract the "Use:" line from the base Hearthstone tooltip (locale-safe)
local HS_USE_TEXT
do
    local tt = CreateFrame("GameTooltip", "MBT_HSCheck", nil, "GameTooltipTemplate")
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:SetItemByID(6948)
    for i = 1, tt:NumLines() do
        local line = _G["MBT_HSCheckTextLeft" .. i]
        if line then
            local text = line:GetText()
            -- The "Use:" line contains the core HS description
            if text and text:match("^Use:") then
                -- Strip the "Use: " prefix to get the description
                HS_USE_TEXT = text:gsub("^Use:%s*", "")
                break
            end
        end
    end
    tt:Hide()
end

-- Validate that a toy is a hearthstone variant (tooltip contains base HS description)
local function IsHearthstoneToy(itemID)
    if not itemID or not PlayerHasToy(itemID) or not HS_USE_TEXT then return false end
    local tt = _G["MBT_HSCheck"]
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:SetToyByItemID(itemID)
    for i = 1, tt:NumLines() do
        local line = _G["MBT_HSCheckTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text:find(HS_USE_TEXT, 1, true) then
                tt:Hide()
                return true
            end
        end
    end
    tt:Hide()
    return false
end

-- Drop zone overlay: intercepts clicks when cursor holds an item
local hsDropZone = CreateFrame("Button", nil, hsBtn)
hsDropZone:SetAllPoints()
hsDropZone:SetFrameLevel(hsBtn:GetFrameLevel() + 5)
hsDropZone:RegisterForClicks("LeftButtonUp")
hsDropZone:Hide()
hsDropZone:SetScript("OnClick", function()
    if InCombatLockdown() then return end
    local infoType, id = GetCursorInfo()
    if infoType == "item" and id and IsHearthstoneToy(id) then
        ApplyCustomHearthstone(id)
        ClearCursor()
    else
        ClearCursor()
    end
end)
-- Show drop zone only when cursor holds an item
hsBtn:HookScript("OnEnter", function()
    if GetCursorInfo() then hsDropZone:Show() end
end)
hsDropZone:SetScript("OnEnter", function()
    if not GetCursorInfo() then hsDropZone:Hide() end
end)
hsDropZone:SetScript("OnLeave", function()
    hsDropZone:Hide()
end)

-- Right-click tooltip hint + reset
local origHSEnter = hsBtn:GetScript("OnEnter")
hsBtn:SetScript("OnEnter", function(self)
    if origHSEnter then origHSEnter(self) end
    if self.itemInfo.isCustomHS then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Drag a Hearthstone toy to replace", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Shift+Right-click: Reset to default", 0.7, 0.7, 0.7)
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Drag a Hearthstone toy to replace", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end)

-- PreClick: Shift+Right-click reset
hsBtn:HookScript("PreClick", function(self, button)
    if InCombatLockdown() then return end
    if button == "RightButton" and IsShiftKeyDown() and self.itemInfo.isCustomHS then
        self:SetAttribute("type", nil)
    end
end)

-- PostClick: complete reset or restore type after blocked click
hsBtn:HookScript("PostClick", function(self, button)
    if InCombatLockdown() then return end
    if button == "RightButton" and IsShiftKeyDown() and self.itemInfo.isCustomHS then
        ApplyCustomHearthstone(nil)
    end
    -- Restore type if it was cleared by PreClick (drag-drop or blocked reset)
    if not self:GetAttribute("type") then
        if self.itemInfo.isToy then
            self:SetAttribute("type", "toy")
        else
            self:SetAttribute("type", "item")
        end
    end
end)

-- Restore saved custom HS on login (retry until DB is ready)
local function RestoreCustomHearthstone()
    ns.EnsureDB()
    local savedToy = MajesticBeastTrackerDB and MajesticBeastTrackerDB.settings and MajesticBeastTrackerDB.settings.hearthstoneToy
    if savedToy and not InCombatLockdown() then
        ApplyCustomHearthstone(savedToy)
    elseif savedToy then
        -- Combat lockdown, retry later
        C_Timer.After(2, RestoreCustomHearthstone)
    end
end
-- Defer to after PLAYER_LOGIN has set up DB
C_Timer.After(3, RestoreCustomHearthstone)
-- Conditional travel buttons (created but shown based on class/profession/race)
local wormholeBtn = CreateTravelButton(#TRAVEL_ITEMS + 1, WORMHOLE_ITEM)
local mageTeleportBtn = CreateTravelButton(#TRAVEL_ITEMS + 2, MAGE_TELEPORT)
local vulperaReturnBtn = CreateTravelButton(#TRAVEL_ITEMS + 3, VULPERA_RETURN)

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
ns.tsmTotalLabel = bottomBar:CreateFontString(nil, "OVERLAY")
ns.tsmTotalLabel:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
ns.tsmTotalLabel:SetTextColor(1, 0.84, 0)
ns.tsmTotalLabel:SetJustifyH("CENTER")
ns.tsmTotalLabel:SetPoint("CENTER", bottomBar, "CENTER", 0, 0)
ns.tsmTotalLabel:Hide()

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
-- Character rows
------------------------------------------------------

-- Forward declarations for loot editor (used in goblin button OnClick below)
-- ns.lootEditor and ns.ShowLootEditor stored in ns to reduce upvalues

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
    nameHl:SetColorTexture(0.82, 0.71, 0.35, 0.08)

    nameBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    nameBtn.label = nameLabel
    row.name = nameBtn
    row.nameLabel = nameLabel

    -- Tool icon (shown inside name cell, left side, for current char when Razorstone is active)
    local toolIcon = CreateFrame("Button", "MBT_ToolIcon" .. index, frame, "SecureActionButtonTemplate")
    toolIcon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
    -- Position set dynamically in UpdateUI (anchored to frame, not nameBtn)
    toolIcon:RegisterForClicks("AnyUp", "AnyDown")
    toolIcon:SetFrameLevel(nameBtn:GetFrameLevel() + 5)
    toolIcon:Hide()
    local toolTex = toolIcon:CreateTexture(nil, "ARTWORK")
    toolTex:SetAllPoints()
    toolTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    toolIcon.icon = toolTex
    -- Golden hover border
    local toolHl = toolIcon:CreateTexture(nil, "HIGHLIGHT")
    toolHl:SetAllPoints()
    toolHl:SetColorTexture(1, 0.84, 0, 0.3)
    toolIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.slotID then
            GameTooltip:SetInventoryItem("player", self.slotID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to apply enchant", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    toolIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Secure macro: /use <slotID> applies enchant cursor to that slot
    toolIcon:SetAttribute("type", "macro")
    row.toolIcon = toolIcon

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
        hl:SetColorTexture(0.82, 0.71, 0.35, 0.1)

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
    goblinIcon:SetTexture(MEDIA_PATH .. "Icon_Results")
    goblinIcon:SetTexCoord(0, 1, 0, 1)
    goblinIcon:SetVertexColor(C_TOOLBAR_ICON[1], C_TOOLBAR_ICON[2], C_TOOLBAR_ICON[3], 1)
    goblinBtn.icon = goblinIcon
    goblinBtn:RegisterForClicks("LeftButtonUp")
    goblinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    goblinBtn:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        if ns.lootEditor:IsShown() and ns.lootEditor.charKey == row._charKey then
            ns.lootEditor:Hide()
        else
            ns.ShowLootEditor(self, row._charKey)
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
-- Update
------------------------------------------------------

local function UpdateLockVisual()
    ns.EnsureDB()
    lockIcon[MajesticBeastTrackerDB.settings.locked and "Show" or "Hide"](lockIcon)
end
ns.UpdateLockVisual = UpdateLockVisual

local lastUpdateUI = 0
local updateUIDirty = false

-- Periodic check: if dirty flag set, run UpdateUI
C_Timer.NewTicker(2, function()
    if updateUIDirty and not ns.isInInstance and not InCombatLockdown() and frame:IsShown() then
        updateUIDirty = false
        lastUpdateUI = GetTime()
        ns._doUpdateUI()
    end
end)

function ns.UpdateUI()
    -- Throttle: max once per 2s
    local now = GetTime()
    if now - lastUpdateUI < 2 then
        updateUIDirty = true  -- will be picked up by ticker
        return
    end
    lastUpdateUI = now
    if not frame:IsShown() then return end
    ns._doUpdateUI()
end

function ns._doUpdateUI()
    local uiOk, uiErr = pcall(function()
    ns.EnsureDB()
    local currentChar = ns.GetCharKey()
    if not currentChar then return end

    -- Ensure current character level is stored
    if MajesticBeastTrackerDB.chars[currentChar] then
        MajesticBeastTrackerDB.chars[currentChar].level = UnitLevel("player")
    end

    -- Reagent layout values (needed early for header positioning)
    local showReagents = MajesticBeastTrackerDB.settings.showReagents ~= false
    local showTSM = MajesticBeastTrackerDB.settings.tsmIntegration
    local tsmExtra = (showReagents and TSM_API and showTSM) and TSM_PRICE_HEIGHT or 0
    local reagentExtra = showReagents and (REAGENT_ROW_HEIGHT + tsmExtra) or 0

    -- Route: check if a lure is skipped (global skip or Harandar level check)
    local routeSkip = MajesticBeastTrackerDB.settings.routeSkip or {}
    local harandarMinLvl = MajesticBeastTrackerDB.settings.routeHarandarMinLevel or 80
    local hideSkipped = MajesticBeastTrackerDB.settings.routeHideSkipped or false
    local lureSkipped = {}
    local visibleLureCount = 0
    for li, lure in ipairs(LURES) do
        local skipKey = "routeSkip_" .. lure.name:gsub("[%s']", "")
        lureSkipped[li] = routeSkip[lure.name] or MajesticBeastTrackerDB.settings[skipKey] or false
        if not lureSkipped[li] or not hideSkipped then
            visibleLureCount = visibleLureCount + 1
        end
    end
    local numVisibleLures = hideSkipped and visibleLureCount or #LURES
    -- Map lure index → visible column index (respects routeOrder + hideSkipped)
    local routeOrder = ns.GetRouteOrder()
    local lureToCol = {}
    local colIdx = 0
    for _, li in ipairs(routeOrder) do
        if hideSkipped and lureSkipped[li] then
            lureToCol[li] = -1  -- hidden
        else
            lureToCol[li] = colIdx
            colIdx = colIdx + 1
        end
    end

    -- Header icons: texture, count, glow
    local charData = MajesticBeastTrackerDB.chars[currentChar]
    for i, lure in ipairs(LURES) do
        local isHidden = lureToCol[i] == -1
        if isHidden then
            if not InCombatLockdown() then headerIcons[i]:Hide() end
            zoneLabels[i]:Hide()
            if reagentIcons[i] then
                for _, rBtn in ipairs(reagentIcons[i]) do rBtn:Hide() end
            end
            if lureBoxes[i] then lureBoxes[i]:Hide() end
            if tsmPriceLabels[i] then tsmPriceLabels[i]:Hide() end
        else
        local tex = ns.GetItemIcon(lure.itemID)
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

        -- Repositioning handled in InCombatLockdown-guarded block below
        if not InCombatLockdown() then
            headerIcons[i]:Show()
        end
        zoneLabels[i]:Show()

        end -- end isHidden else
    end

    -- Reposition lure icons and separator based on reagent visibility + route order
    if not InCombatLockdown() then
        for i = 1, #LURES do
            if lureToCol[i] == -1 then
                headerIcons[i]:Hide()
            else
                headerIcons[i]:ClearAllPoints()
                -- Center lure icons vertically relative to header area
                local lureY = contentTop - 2 - reagentExtra
                if not showReagents then
                    -- No reagents: center lures relative to cons+travel height
                    local consTravelH = ns.CONS_BOX_HEIGHT + 2 + TRAVEL_ICON_SIZE + 8
                    local lureH = ICON_SIZE + ZONE_LABEL_HEIGHT + 2
                    local vPad = math.max((consTravelH - lureH) / 2, 0)
                    lureY = contentTop - 2 - vPad
                end
                headerIcons[i]:SetPoint("TOPLEFT", frame, "TOPLEFT",
                    PAD + 4 + NAME_COL_WIDTH + lureToCol[i] * COL_WIDTH + (COL_WIDTH - ICON_SIZE) / 2,
                    lureY)
                zoneLabels[i]:ClearAllPoints()
                zoneLabels[i]:SetPoint("TOP", headerIcons[i], "BOTTOM", 0, -1)
            end
        end
        -- Position consumable box at contentTop
        ns.consumableBox:ClearAllPoints()
        ns.consumableBox:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, contentTop - 2)
        -- iconSep: below whichever is taller (lure icons or consumable+travel)
        local lureSepY = contentTop - reagentExtra - ICON_ROW_HEIGHT - 2
        local consSepY = contentTop - 2 - ns.CONS_BOX_HEIGHT - 2 - TRAVEL_ICON_SIZE - 8 - 4
        local sepY = math.min(lureSepY, consSepY)
        ns.iconSep:ClearAllPoints()
        ns.iconSep:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, sepY)
        ns.iconSep:SetPoint("RIGHT", frame, "RIGHT", -(PAD + 4), 0)
    end


    -- Count characters that still need a lure today (eligible - already killed - skipped - hidden)
    local hiddenCharsForCount = MajesticBeastTrackerDB.settings.hiddenChars or {}
    local charsNeedLure = {}
    for li = 1, #LURES do
        charsNeedLure[li] = 0
        if not lureSkipped[li] then
            for charKey, cData in pairs(MajesticBeastTrackerDB.chars) do
                if not hiddenCharsForCount[charKey] and ns.CanSeeLure(cData, li) then
                    -- Harandar level check
                    local skipForLevel = false
                    if LURES[li].name == "Harandar" and cData.level and cData.level < harandarMinLvl then
                        skipForLevel = true
                    end
                    if not skipForLevel then
                        local ts = cData.lures[LURES[li].name]
                        if not ts or ns.IsLureReady(ts) then
                            -- Don't count if character already has lure in bags
                            local hasBagged = cData.lureBags and cData.lureBags[LURES[li].name]
                            if not hasBagged then
                                charsNeedLure[li] = charsNeedLure[li] + 1
                            end
                        end
                    end
                end
            end
        end
    end

    -- Update fish toggle button
    fishIcon:SetDesaturated(not showReagents)
    fishIcon:SetAlpha(showReagents and 1.0 or 0.4)
    fishBtn:Show()

    -- Update autohide button visual
    local ahEnabled = MajesticBeastTrackerDB.settings.autoHide
    autoHideIcon:SetTexture(MEDIA_PATH .. (ahEnabled and "Icon_Show" or "Icon_Hide"))
    autoHideIcon:SetAlpha(ahEnabled and 1.0 or 0.4)

    -- Update coin toggle button (desaturated when TSM not installed or disabled)
    local tsmEnabled = MajesticBeastTrackerDB.settings.tsmIntegration
    local tsmActive = tsmEnabled and TSM_API
    coinIcon:SetDesaturated(not tsmActive)
    coinIcon:SetAlpha(tsmActive and 1.0 or 0.4)
    coinBtn:Show()

    -- Update global goblin button (desaturated when loot tracking is off)
    local lootTrackingOn = MajesticBeastTrackerDB.settings.lootTracking ~= false
    ns.globalGoblinIcon:SetDesaturated(not lootTrackingOn)
    ns.globalGoblinIcon:SetAlpha(lootTrackingOn and 1.0 or 0.4)
    ns.globalGoblinBtn:ClearAllPoints()
    ns.globalGoblinBtn:SetPoint("RIGHT", coinBtn, "LEFT", -2, 0)
    ns.globalGoblinBtn:Show()

    -- Dynamic button chain: globalGoblin ← auctionator ← warbank (right to left)
    local lastBtn = ns.globalGoblinBtn

    -- Auctionator button: show only when Auctionator is loaded
    if C_AddOns.IsAddOnLoaded("Auctionator") then
        ns.auctionatorBtn:ClearAllPoints()
        ns.auctionatorBtn:SetPoint("RIGHT", lastBtn, "LEFT", -2, 0)
        ns.auctionatorBtn:Show()
        lastBtn = ns.auctionatorBtn
    else
        ns.auctionatorBtn:Hide()
    end

    -- Warband bank deposit button: show only when bank open + setting enabled
    if ns.isBankOpen and MajesticBeastTrackerDB.settings.warbankDeposit then
        ns.warbankBtn:ClearAllPoints()
        ns.warbankBtn:SetPoint("RIGHT", lastBtn, "LEFT", -2, 0)
        ns.warbankBtn:Show()
    else
        ns.warbankBtn:Hide()
    end

    for i, lure in ipairs(LURES) do
        -- Skip hidden lure columns entirely
        if lureToCol[i] == -1 then
            if reagentIcons[i] then
                for _, rBtn in ipairs(reagentIcons[i]) do rBtn:Hide() end
            end
        elseif reagentIcons[i] and showReagents and lure.reagents then
            -- Always reposition reagent icons via lureToCol (handles route order + unhide restore)
            local col = lureToCol[i]
            local lureCenter = PAD + 4 + NAME_COL_WIDTH + col * COL_WIDTH + COL_WIDTH / 2
            local numR = #lure.reagents
            local totalW = numR * REAGENT_ICON_SIZE + (numR - 1) * REAGENT_GAP
            for j, rBtn in ipairs(reagentIcons[i]) do
                rBtn:ClearAllPoints()
                local rx = lureCenter - totalW / 2 + (j - 1) * (REAGENT_ICON_SIZE + REAGENT_GAP)
                rBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", rx, contentTop - 2 - 1)
            end
            local numLeft = charsNeedLure[i]
            local anyMissing = false

            -- First pass: set textures, desaturation, tooltips, calculate status
            for j, rBtn in ipairs(reagentIcons[i]) do
                if lure.reagents[j] then
                    local reagent = lure.reagents[j]
                    local tex = ns.GetItemIcon(reagent.itemID)
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
                    elseif MajesticBeastTrackerDB.settings.showMissingCount then
                        -- Show Missing Count mode: per-reagent values, centered positioning
                        rBtn.countText:ClearAllPoints()
                        rBtn.countText:SetPoint("TOP", rBtn, "BOTTOM", 0, -1)
                        rBtn.countText:SetJustifyH("CENTER")
                        rBtn.countText:SetWidth(COL_WIDTH)
                        local missing = rBtn._missing or 0
                        if missing > 0 then
                            rBtn.countText:SetText("|cffff3333-" .. missing .. "|r")
                        else
                            rBtn.countText:SetText("|cff00ff00" .. ns.CHECKMARK_ICON .. "|r")
                        end
                        rBtn.countText:Show()
                    else
                        -- Default: per-reagent have/need counts
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
                        local missing = rBtn._missing or 0
                        if missing > 0 then
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
    local showTSMPrices = hasTSM and showReagents and showTSM
    for i, lure in ipairs(LURES) do
        local label = tsmPriceLabels[i]
        if showTSMPrices and lure.reagents then
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
                local colCenter = PAD + 4 + NAME_COL_WIDTH + lureToCol[i] * COL_WIDTH + COL_WIDTH / 2
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
    local showLureBorders = MajesticBeastTrackerDB.settings.showLureBorders ~= false
    for i, lure in ipairs(LURES) do
        local box = lureBoxes[i]
        if not showLureBorders or lureToCol[i] == -1 then
            box:Hide()
        else
            local boxPad = 3
            local colX = PAD + 4 + NAME_COL_WIDTH + lureToCol[i] * COL_WIDTH
            local boxTop = contentTop - 2 + boxPad
            local boxBottom
            if showReagents and lure.reagents and #lure.reagents > 0 then
                -- Full height: reagents + lure icon
                boxBottom = contentTop - 2 - reagentExtra - ICON_SIZE - boxPad
            else
                -- No reagents: match cons+travel height
                local consTravelH = ns.CONS_BOX_HEIGHT + 2 + TRAVEL_ICON_SIZE + 8
                boxBottom = contentTop - 2 - consTravelH + boxPad
            end
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", frame, "TOPLEFT", colX - boxPad, boxTop)
            box:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", colX + COL_WIDTH + boxPad, boxBottom)
            box:Show()
        end
    end

    -- Gather eligible characters
    local keys = {}
    local hiddenChars = MajesticBeastTrackerDB.settings.hiddenChars or {}
    local showHidden = MajesticBeastTrackerDB.settings.showHiddenChars
    for key, charData in pairs(MajesticBeastTrackerDB.chars) do
        if charData.hasSkinning and (not hiddenChars[key] or showHidden) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b)
        if a == currentChar then return true end
        if b == currentChar then return false end
        return a < b
    end)

    ns.HideAllRows()

    -- Header height: max of (reagent+lure icons) vs (consumable+travel boxes)
    local lureHeaderH = reagentExtra + ICON_ROW_HEIGHT + 5
    local consHeaderH = ns.CONS_BOX_HEIGHT + 2 + TRAVEL_ICON_SIZE + 8 + 5
    local headerH = math.max(lureHeaderH, consHeaderH)
    local dynDataTop = contentTop - headerH

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
                local col = lureToCol[ci]
                if col and col >= 0 then
                    row.cells[ci]:ClearAllPoints()
                    row.cells[ci]:SetPoint("TOPLEFT", frame, "TOPLEFT",
                        PAD + 4 + NAME_COL_WIDTH + col * COL_WIDTH, yOff)
                end
            end
        end
        -- Reposition goblin icon
        if row.goblinBtn then
            row.goblinBtn:ClearAllPoints()
            local goblinX = PAD + 4 + NAME_COL_WIDTH + numVisibleLures * COL_WIDTH + 4
            row.goblinBtn:SetPoint("LEFT", frame, "TOPLEFT", goblinX, yOff - ROW_HEIGHT / 2)
        end
        local charData = MajesticBeastTrackerDB.chars[key]
        row._charKey = key
        local classColor = ns.GetClassColor(charData.class)
        local name = ns.GetDemoName(key)
        if key == currentChar then name = name .. " *" end
        local isCharHidden = hiddenChars[key]
        if isCharHidden then name = name .. " |cff666666(hidden)|r" end

        row.nameLabel:SetText(classColor .. name .. "|r")

        -- Tool icon: show only for current char when Razorstone consumable is active
        if row.toolIcon then
            local showTool = false
            if key == currentChar then
                -- Check if Razorstone is toggled on in consumable settings
                local razorID = 237372  -- Refulgent Razorstone itemID
                local showKey = "consShow_" .. razorID
                -- Only show if Razorstone is toggled on AND no enchant currently active
                local enchantActive = ns.GetToolEnchantRemaining and ns.GetToolEnchantRemaining() and ns.GetToolEnchantRemaining() > 0
                if MajesticBeastTrackerDB.settings[showKey] ~= false and not enchantActive then
                    -- Get skinning tool slot and icon
                    pcall(function()
                        local prof1, prof2 = GetProfessions()
                        local profID
                        if prof1 then
                            local _, _, _, _, _, _, sklID, _, _, _, _, pID = GetProfessionInfo(prof1)
                            if sklID == 393 then profID = pID or Enum.Profession.Skinning end
                        end
                        if not profID and prof2 then
                            local _, _, _, _, _, _, sklID, _, _, _, _, pID = GetProfessionInfo(prof2)
                            if sklID == 393 then profID = pID or Enum.Profession.Skinning end
                        end
                        if profID then
                            local s = C_TradeSkillUI.GetProfessionSlots(profID)
                            if s and s[1] then
                                local itemID = GetInventoryItemID("player", s[1])
                                if itemID then
                                    local tex = ns.GetItemIcon(itemID)
                                    if tex then
                                        row.toolIcon.icon:SetTexture(tex)
                                        row.toolIcon.slotID = s[1]
                                        row.toolIcon._pendingSlot = s[1]
                                        showTool = true
                                    end
                                end
                            end
                        end
                    end)
                end
            end
            if not InCombatLockdown() then
                if showTool then
                    if row.toolIcon._pendingSlot then
                        row.toolIcon:SetAttribute("macrotext", "/use " .. row.toolIcon._pendingSlot)
                        row.toolIcon._pendingSlot = nil
                    end
                    row.toolIcon:ClearAllPoints()
                    row.toolIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 6, yOff)
                    row.toolIcon:Show()
                    -- Shift name label right
                    row.nameLabel:ClearAllPoints()
                    row.nameLabel:SetPoint("LEFT", row.name, "LEFT", ROW_HEIGHT, 0)
                    row.nameLabel:SetPoint("RIGHT", row.name, "RIGHT", 0, 0)
                else
                    row.toolIcon:Hide()
                    row.nameLabel:ClearAllPoints()
                    row.nameLabel:SetPoint("TOPLEFT", row.name, "TOPLEFT", 0, 0)
                    row.nameLabel:SetPoint("BOTTOMRIGHT", row.name, "BOTTOMRIGHT", 0, 0)
                end
            end
        end

        row.name:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                local isHidden = MajesticBeastTrackerDB.settings.hiddenChars[key]
                local items = {
                    { text = ns.GetDemoName(key), isTitle = true },
                    { text = isHidden and "|cff00ff00Show character|r" or "|cff999999Hide character|r", func = function()
                        if isHidden then
                            MajesticBeastTrackerDB.settings.hiddenChars[key] = nil
                        else
                            MajesticBeastTrackerDB.settings.hiddenChars[key] = true
                        end
                        ns.UpdateUI()
                    end },
                    { text = "|cffff4444Remove character|r", func = function()
                        StaticPopup_Show("MBT_REMOVE_CHAR", ns.GetDemoName(key), nil, key)
                    end },
                }
                ns.ShowDropdown(self, items)
            else
                if ns.gearPopup:IsShown() and ns.gearPopup.currentKey == key then
                    ns.gearPopup:Hide()
                else
                    ns.gearPopup.currentKey = key
                    ns.ShowGearPopup(self, key)
                end
            end
        end)
        row.name:Show()
        if row.bg then row.bg:Show() end

        for i, lure in ipairs(LURES) do
            local cell = row.cells[i]
            cell.charKey = key
            local canSee = ns.CanSeeLure(charData, i)
            -- Route skip check (global skip or Harandar level)
            local isSkipped = lureSkipped[i]
            if not isSkipped and lure.name == "Harandar" and charData.level and charData.level < harandarMinLvl then
                isSkipped = true
            end
            -- Hide entire column if setting enabled (global skip only)
            if lureToCol[i] == -1 then
                cell:Hide()
            elseif isSkipped then
                cell.label:SetText("|cffff4444Skip|r")
                cell.label:SetTextColor(1, 0.27, 0.27)
                cell:SetScript("OnClick", nil)
                cell:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
                    GameTooltip:AddLine("Skipped via Route settings", 0.9, 0.3, 0.3)
                    GameTooltip:Show()
                end)
                cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
                cell:Show()
            else
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
            end -- end isSkipped else
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
                    self.icon:SetVertexColor(C_TOOLBAR_ICON_HOVER[1], C_TOOLBAR_ICON_HOVER[2], C_TOOLBAR_ICON_HOVER[3], 1)
                    local charLoot = ns.GetCharLoot(capturedData)
                    if charLoot and hasLoot then
                        ns.ShowLootTooltip(self, ns.GetDemoName(capturedKey) .. " - Loot",
                            charLoot.thisReset, charLoot.allTime, charLoot.prices)
                    else
                        GameTooltip:SetOwner(self, "ANCHOR_LEFT", -4, 0)
                        GameTooltip:AddLine(ns.GetDemoName(capturedKey) .. " - Loot", 0.82, 0.71, 0.35)
                        GameTooltip:AddLine("No loot data yet", 0.5, 0.5, 0.5)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Click to edit loot", 0.5, 0.8, 1)
                        GameTooltip:Show()
                    end
                end)
                goblin:SetScript("OnLeave", function(self)
                    self.icon:SetVertexColor(C_TOOLBAR_ICON[1], C_TOOLBAR_ICON[2], C_TOOLBAR_ICON[3], 1)
                    ns.HideLootTooltip()
                    GameTooltip:Hide()
                end)
                goblin:Show()
            end
        end
    end

    -- Consumable labels handled by 3s ticker, not here
    local playerLevel = UnitLevel("player")

    -- Count visible consumables first for even spacing
    local totalVisibleCons = 0
    for _, cons in ipairs(CONSUMABLES) do
        local showKey = "consShow_" .. (cons.itemID or cons.spellID)
        if MajesticBeastTrackerDB.settings[showKey] ~= false then
            totalVisibleCons = totalVisibleCons + 1
        end
    end
    local consSpacing = totalVisibleCons > 0 and math.max(BASE_NAME_COL_WIDTH / totalVisibleCons, ns.CONS_ITEM_WIDTH) or ns.CONS_ITEM_WIDTH

    local visibleConsIdx = 0
    for i, cons in ipairs(CONSUMABLES) do
        local meetsLevel = not cons.minLevel or playerLevel >= cons.minLevel
        ns.consumableIcons[i].icon:SetDesaturated(not meetsLevel)
        ns.consumableIcons[i].icon:SetAlpha(meetsLevel and 1.0 or 0.4)

        -- Update icon texture
        if cons.isSpell then
            local spellInfo = C_Spell.GetSpellInfo(cons.spellID)
            if spellInfo and spellInfo.iconID then
                ns.consumableIcons[i].icon:SetTexture(spellInfo.iconID)
            end
        elseif cons.itemID then
            local tex = ns.GetItemIcon(cons.itemID)
            if tex then ns.consumableIcons[i].icon:SetTexture(tex) end
        end

        -- Position button in consumable box (respect show/hide setting)
        if not InCombatLockdown() then
            local btn = ns.consumableButtons[i]
            local showKey = "consShow_" .. (cons.itemID or cons.spellID)
            local isVisible = MajesticBeastTrackerDB.settings[showKey] ~= false
            if isVisible and frame:IsShown() then
                btn:ClearAllPoints()
                local xOffset = visibleConsIdx * consSpacing + (consSpacing - ns.CONS_ICON_SIZE) / 2
                btn:SetPoint("TOPLEFT", ns.consumableBox, "TOPLEFT",
                    xOffset, -ns.CONS_PAD)
                ns.consumableLabels[i]:ClearAllPoints()
                ns.consumableLabels[i]:SetPoint("TOP", btn, "BOTTOM", 0, -1)
                ns.consumableLabels[i]:SetJustifyH("CENTER")
                btn:Show()
                ns.consumableLabels[i]:Show()
                visibleConsIdx = visibleConsIdx + 1
            else
                btn:Hide()
                ns.consumableLabels[i]:Hide()
            end
        end
    end

    -- Resize consumable box and adapt NAME_COL_WIDTH dynamically
    local consWidth = totalVisibleCons * consSpacing
    NAME_COL_WIDTH = math.max(BASE_NAME_COL_WIDTH, consWidth)
    local showConsBorders = MajesticBeastTrackerDB.settings.showConsBorders ~= false
    if not InCombatLockdown() then
        if visibleConsIdx > 0 and frame:IsShown() then
            ns.consumableBox:SetWidth(NAME_COL_WIDTH)
            ns.consumableBox:SetBackdrop(showConsBorders and BACKDROP or nil)
            if showConsBorders then
                ns.consumableBox:SetBackdropColor(0, 0, 0, 0.9)
                ns.consumableBox:SetBackdropBorderColor(C_BORDER_RGB[1], C_BORDER_RGB[2], C_BORDER_RGB[3], 0.7)
            end
            ns.consumableBox:Show()
        else
            NAME_COL_WIDTH = BASE_NAME_COL_WIDTH
            ns.consumableBox:Hide()
        end
    end

    -- Update travel buttons
    local activeTravelBtns = {}
    for _, btn in ipairs(travelButtons) do
        activeTravelBtns[#activeTravelBtns + 1] = btn
    end
    -- Wormhole: show only if player has Engineering + toy known
    local showWormhole = ns.HasEngineering() and PlayerHasToy(WORMHOLE_ITEM.itemID)
    if showWormhole then
        activeTravelBtns[#activeTravelBtns + 1] = wormholeBtn
    end
    -- Mage Teleport: show only for Mage (classID 8)
    local _, _, playerClassID = UnitClass("player")
    if playerClassID == 8 then
        activeTravelBtns[#activeTravelBtns + 1] = mageTeleportBtn
    end
    -- Vulpera Return to Camp: show only for Vulpera (raceID 35)
    local _, _, playerRaceID = UnitRace("player")
    if playerRaceID == 35 then
        activeTravelBtns[#activeTravelBtns + 1] = vulperaReturnBtn
    end

    -- Resize
    local n = math.max(#keys, 1)
    local statsExtra = 0  -- stats now shares row with consumable box
    local hasTravelBtns = #activeTravelBtns > 0
    local h = TOOLBAR_HEIGHT + TITLE_HEIGHT + 2 + headerH + n * ROW_HEIGHT + statsExtra + BOTTOM_BAR_HEIGHT + PAD + 10
    local goblinColWidth = 18  -- always reserve space for goblin column
    local w = PAD * 2 + 8 + NAME_COL_WIDTH + numVisibleLures * COL_WIDTH + goblinColWidth
    -- All frame layout operations guarded against combat lockdown
    local divY = -(TOOLBAR_HEIGHT + TITLE_HEIGHT + 2 + headerH + n * ROW_HEIGHT + 2)

    if not InCombatLockdown() then
        frame:SetSize(w, h)

        -- Title moved to toolbar (MBT vX)

        -- consumableBox already positioned above
        -- Travel separator hidden (travel buttons moved to header)
        ns.travelSep:Hide()

        -- Hide all first
        for _, btn in ipairs(travelButtons) do btn:Hide() end
        wormholeBtn:Hide()
        mageTeleportBtn:Hide()
        vulperaReturnBtn:Hide()

        -- Show + position active ones (below consumable box in header area)
        -- Position travel box below consumable box (anchored to it)
        local numTravel = #activeTravelBtns
        ns.travelBox:ClearAllPoints()
        ns.travelBox:SetPoint("TOPLEFT", ns.consumableBox, "BOTTOMLEFT", 0, -2)
        ns.travelBox:SetWidth(NAME_COL_WIDTH)
        ns.travelBox:SetHeight(TRAVEL_ICON_SIZE + 8)

        local travelSpacing = numTravel > 0 and math.max(NAME_COL_WIDTH / numTravel, TRAVEL_ICON_SIZE + TRAVEL_SPACING) or 0
        for idx, btn in ipairs(activeTravelBtns) do
            if btn.itemInfo.isSpell then
                local spellInfo = C_Spell.GetSpellInfo(btn.itemInfo.spellID)
                if spellInfo and spellInfo.iconID then btn.icon:SetTexture(spellInfo.iconID) end
            else
                local tex = ns.GetItemIcon(btn.itemInfo.itemID)
                if tex then btn.icon:SetTexture(tex) end
            end
            btn:ClearAllPoints()
            btn:SetParent(ns.travelBox)
            local xOff = (idx - 1) * travelSpacing + (travelSpacing - TRAVEL_ICON_SIZE) / 2
            btn:SetPoint("TOPLEFT", ns.travelBox, "TOPLEFT", xOff, -4)
            -- Update cooldown sweep
            if btn.itemInfo.isSpell then
                local cdInfo = C_Spell.GetSpellCooldown(btn.itemInfo.spellID)
                if cdInfo and cdInfo.duration and cdInfo.duration > 0 then
                    btn.cooldown:SetCooldown(cdInfo.startTime, cdInfo.duration)
                else
                    btn.cooldown:Clear()
                end
            else
                local start, duration, enable = C_Item.GetItemCooldown(btn.itemInfo.itemID)
                if start and duration and duration > 0 then
                    btn.cooldown:SetCooldown(start, duration)
                else
                    btn.cooldown:Clear()
                end
            end
            if frame:IsShown() then
                btn:Show()
            end
        end
        if numTravel > 0 and frame:IsShown() then
            ns.travelBox:SetBackdrop(showConsBorders and BACKDROP or nil)
            if showConsBorders then
                ns.travelBox:SetBackdropColor(0, 0, 0, 0.9)
                ns.travelBox:SetBackdropBorderColor(C_BORDER_RGB[1], C_BORDER_RGB[2], C_BORDER_RGB[3], 0.7)
            end
            ns.travelBox:Show()
        else
            ns.travelBox:Hide()
        end

        -- Position stats on the right side of bottom row (2-row layout when narrow)
        local profStats = ns.CalculateProfessionStats and ns.CalculateProfessionStats() or nil
        local hasAnyStats = profStats and (profStats.Skill > 0 or profStats.Perception > 0 or profStats.Finesse > 0 or profStats.Deftness > 0)
        local statsY = divY - 4
        if hasAnyStats then
            -- Collect visible stats
            local visibleStats = {}
            for i, stat in ipairs(STAT_LABELS) do
                local val = profStats[stat.key] or 0
                if val > 0 then
                    statsTexts[i]:SetText(stat.label .. ":" .. val)
                    visibleStats[#visibleStats + 1] = i
                else
                    statsTexts[i]:Hide()
                end
            end
            -- Calculate total width needed
            local totalStatsWidth = 0
            for _, si in ipairs(visibleStats) do
                totalStatsWidth = totalStatsWidth + statsTexts[si]:GetStringWidth() + 6
            end
            -- Available space: frame width minus consumable box
            local availableWidth = w - ns.CONS_BOX_WIDTH - PAD * 2 - 16
            local useTwoRows = totalStatsWidth > availableWidth and #visibleStats > 2
            if useTwoRows then
                -- Two rows: top row = first half, bottom row = second half
                local half = math.ceil(#visibleStats / 2)
                local rowHeight = 7
                -- Top row: first half (Skl, Per)
                local statsX = w - PAD - 4
                local topRowY = divY - 4 + rowHeight
                for ri = half, 1, -1 do
                    local si = visibleStats[ri]
                    statsTexts[si]:ClearAllPoints()
                    statsTexts[si]:SetPoint("RIGHT", frame, "TOPLEFT", statsX, topRowY)
                    statsX = statsX - statsTexts[si]:GetStringWidth() - 6
                    statsTexts[si]:Show()
                end
                -- Bottom row: second half (Fin, Dft)
                statsX = w - PAD - 4
                local bottomRowY = divY - 4 - rowHeight
                statsY = bottomRowY
                for ri = #visibleStats, half + 1, -1 do
                    local si = visibleStats[ri]
                    statsTexts[si]:ClearAllPoints()
                    statsTexts[si]:SetPoint("RIGHT", frame, "TOPLEFT", statsX, bottomRowY)
                    statsX = statsX - statsTexts[si]:GetStringWidth() - 6
                    statsTexts[si]:Show()
                end
            else
                -- Single row (right-aligned)
                local statsX = w - PAD - 4
                for ri = #visibleStats, 1, -1 do
                    local si = visibleStats[ri]
                    statsTexts[si]:ClearAllPoints()
                    statsTexts[si]:SetPoint("RIGHT", frame, "TOPLEFT", statsX, statsY)
                    statsX = statsX - statsTexts[si]:GetStringWidth() - 6
                    statsTexts[si]:Show()
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
                if lureSkipped[i] then
                    -- skip, don't count skipped routes
                elseif lure.reagents and reagentIcons[i] then
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
                ns.tsmTotalLabel:SetText("Total needed: " .. goldText)
                ns.tsmTotalLabel:Show()
            else
                ns.tsmTotalLabel:Hide()
            end
        else
            ns.tsmTotalLabel:Hide()
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

    -- Timer display (always visible)
    if ns.IsTimerRunning() then
        timerLabel:SetText("|cff00ff00" .. ns.FormatTimerElapsed() .. "|r")
    elseif ns.GetTimerElapsed() > 0 then
        timerLabel:SetText("|cff888888" .. ns.FormatTimerElapsed() .. "|r")
    else
        timerLabel:SetText("|cff555555" .. ns.FormatTimerElapsed() .. "|r")
    end
    timerLabel:Show()
    timerBtn:SetWidth(math.max(timerLabel:GetStringWidth() + 4, 50))
    timerBtn:Show()

    if #keys == 0 then
        if not charRows[1] then charRows[1] = CreateCharRow(1) end
        charRows[1].nameLabel:SetText(C_ACCENT:WrapTextInColorCode("No skinners found"))
        if not InCombatLockdown() then charRows[1].name:SetWidth(w - PAD * 2) end
        charRows[1].name:SetScript("OnClick", nil)
        charRows[1].name:Show()
        for _, cell in ipairs(charRows[1].cells) do
            cell:Hide()
        end
    end
    -- Update loot editor sync overlay
    if ns.lootEditor and ns.lootEditor:IsShown() then
        if ns.isSyncingLoot then
            ns.lootEditor.syncOverlay:Show()
            ns.lootEditor._wasSyncing = true
        else
            ns.lootEditor.syncOverlay:Hide()
            -- Refresh loot counts once when sync finishes
            if ns.lootEditor._wasSyncing and ns.lootEditor.charKey then
                ns.lootEditor._wasSyncing = nil
                ns.ShowLootEditor(ns.lootEditor, ns.lootEditor.charKey)
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
        local timerRunning = ns.IsTimerRunning()
        local timerText = timerRunning and ("|cff00ff00Stop Timer|r (" .. ns.FormatTimerElapsed() .. ")") or "Start Timer"
        ShowDropdown(self, {
            { text = "Majestic Beast Tracker", isTitle = true },
            { text = timerText, func = function()
                if ns.IsTimerRunning() then
                    ns.StopTimer()
                else
                    ns.StartTimer()
                end
            end },
            { text = "Reset Timer", func = function()
                ns.ResetTimer()
            end, disabled = timerRunning },
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
local lastAuraUpdate = 0
auraFrame:SetScript("OnEvent", function(_, event, unit)
    if ns.isInInstance then return end
    if event == "UNIT_AURA" then
        if unit ~= "player" then return end
        -- Only invalidate stats cache, don't trigger full UpdateUI
        if ns.InvalidateProfStatsCache then ns.InvalidateProfStatsCache() end
        return
    end
    -- BAG_UPDATE, TRAIT_CONFIG_UPDATED, SKILL_LINES_CHANGED trigger full update
    if event == "TRAIT_CONFIG_UPDATED" or event == "SKILL_LINES_CHANGED" then
        if ns.InvalidateProfStatsCache then ns.InvalidateProfStatsCache() end
    end
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
        -- Unregister heavy events during combat
        auraFrame:UnregisterEvent("UNIT_AURA")
        auraFrame:UnregisterEvent("BAG_UPDATE")
        if not MajesticBeastTrackerDB.settings.hideInCombat then return end
        if frame:IsShown() then
            frame._hiddenByCombat = true
            frame:Hide()
            ns.consumableBox:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Re-register events after combat
        auraFrame:RegisterEvent("UNIT_AURA")
        auraFrame:RegisterEvent("BAG_UPDATE")
        if frame._hiddenByCombat then
            frame._hiddenByCombat = nil
            if MajesticBeastTrackerDB.settings.showFrame ~= false then
                frame:Show()
            end
        end
        ns.UpdateUI()  -- refresh after combat regardless
    end
end)

-- Periodic refresh (every 30s) via timer instead of OnUpdate (avoids per-frame overhead)
C_Timer.NewTicker(30, function()
    if ns.isInInstance then return end
    if InCombatLockdown() then return end
    if frame:IsShown() then
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
            local isHiddenChar = key and MajesticBeastTrackerDB.settings.hiddenChars and MajesticBeastTrackerDB.settings.hiddenChars[key]
            if isHiddenChar then
                -- Hidden character → don't show tracker
                frame:Hide()
            elseif isSkinner then
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
    if ns.isInInstance then
        print("|cff3FC7EB[MBT]|r Disabled in instances. Change in Settings > Display.")
        return
    end
    if not InCombatLockdown() then
        frame:Show()
    end
    ns.EnsureDB()
    MajesticBeastTrackerDB.settings.showFrame = true
    ns.UpdateUI()
    ns.RefreshAutoHide()
end

function ns.HideFrame()
    if not InCombatLockdown() then
        frame:Hide()
    end
    if ns.lootEditor then ns.lootEditor:Hide() end
    if ns.lootSummary then ns.lootSummary:Hide() end
    ns.EnsureDB()
    MajesticBeastTrackerDB.settings.showFrame = false
    -- Hide consumable buttons and box
    if not InCombatLockdown() then
        for _, btn in ipairs(ns.consumableButtons) do btn:Hide() end
        ns.consumableBox:Hide()
        for _, btn in ipairs(travelButtons) do btn:Hide() end
        wormholeBtn:Hide()
        mageTeleportBtn:Hide()
        vulperaReturnBtn:Hide()
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

-- Init on login (Settings moved to Settings.lua)
local minimapInit = CreateFrame("Frame")
minimapInit:RegisterEvent("PLAYER_LOGIN")
minimapInit:SetScript("OnEvent", function()
    InitMinimapIcon()
    local ok, err = pcall(ns.InitSettings)
    if not ok then
        print("|cffff3333[MBT] Settings error:|r " .. tostring(err))
    end
    ns.EnsureDB()
    frame:SetScale(MajesticBeastTrackerDB.settings.windowScale)
end)

