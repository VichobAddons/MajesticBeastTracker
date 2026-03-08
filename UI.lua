------------------------------------------------------
-- MajesticBeastTracker UI - Visual tracker
-- PSL-inspired style with BackdropTemplate
------------------------------------------------------

local addonName, ns = ...
local LURES = ns.LURES

-- Layout
local ICON_SIZE = 26
local COL_WIDTH = 40
local NAME_COL_WIDTH = 120
local ROW_HEIGHT = 18
local TITLE_HEIGHT = 22
local ICON_ROW_HEIGHT = ICON_SIZE + 6
local PAD = 8

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

-- Close button (native)
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function()
    ns.HideFrame()
end)

-- Title
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

------------------------------------------------------
-- Content area
------------------------------------------------------

local contentTop = -(TITLE_HEIGHT + 2)

-- Header icons
local headerIcons = {}
for i, lure in ipairs(LURES) do
    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    iconFrame:SetPoint("TOPLEFT", frame, "TOPLEFT",
        PAD + 4 + NAME_COL_WIDTH + (i - 1) * COL_WIDTH + (COL_WIDTH - ICON_SIZE) / 2,
        contentTop - 2)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconFrame.icon = icon

    iconFrame:EnableMouse(true)
    iconFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
        local r, g, b = unpack(lure.colorRGB)
        GameTooltip:AddLine(lure.name, r, g, b)
        GameTooltip:AddLine(lure.requiredPoints .. " pts", 0.6, 0.6, 0.6)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: Open recipe", 0.5, 0.8, 1)
        GameTooltip:AddLine("Double-click: Craft", 0.5, 0.8, 1)
        GameTooltip:AddLine("Right-click: Set waypoint", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    iconFrame.lastClicked = 0
    iconFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if lure.recipeID then
                local now = GetTime()
                if MajesticBeastTrackerDB.settings.autoCraft and C_TradeSkillUI.IsTradeSkillReady() and (now - self.lastClicked) < 1.5 then
                    C_TradeSkillUI.CraftRecipe(lure.recipeID)
                    self.lastClicked = 0
                else
                    C_TradeSkillUI.OpenRecipe(lure.recipeID)
                    self.lastClicked = now
                end
            end
        elseif button == "RightButton" then
            local wp = lure.waypoint
            if wp then
                local mapPoint = UiMapPoint.CreateFromCoordinates(wp.map, wp.x, wp.y)
                C_Map.SetUserWaypoint(mapPoint)
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                print("|cff3FC7EB[MBT]|r Waypoint set: " .. lure.color .. lure.name .. "|r")
            end
        end
    end)
    headerIcons[i] = iconFrame
end

-- Separator under icons
local iconSep = frame:CreateTexture(nil, "ARTWORK")
iconSep:SetHeight(1)
iconSep:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, contentTop - ICON_ROW_HEIGHT - 2)
iconSep:SetPoint("RIGHT", frame, "RIGHT", -(PAD + 4), 0)
iconSep:SetColorTexture(unpack(C_SEPARATOR))

------------------------------------------------------
-- Character rows
------------------------------------------------------

local charRows = {}
local dataTop = contentTop - ICON_ROW_HEIGHT - 5

local function GetStatusText(charData, lureName)
    if not charData then return "?", 0.4, 0.4, 0.4 end
    local timestamp = charData.lures[lureName]
    if not timestamp then
        return "-", 0.4, 0.4, 0.4
    elseif ns.IsLureReady(timestamp) then
        return "\226\156\147", 0.2, 0.9, 0.4
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

    row.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 6, yOffset - 1)
    row.name:SetFont(row.name:GetFont(), 10)
    row.name:SetWidth(NAME_COL_WIDTH - 4)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

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
    ns.EnsureDB()
    local currentChar = ns.GetCharKey()
    if not currentChar then return end

    -- Header icons
    for i, lure in ipairs(LURES) do
        local tex = C_Item.GetItemIconByID(lure.itemID)
        if tex then headerIcons[i].icon:SetTexture(tex) end
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

    for idx, key in ipairs(keys) do
        if not charRows[idx] then
            charRows[idx] = CreateCharRow(idx)
        end
        local row = charRows[idx]
        local charData = MajesticBeastTrackerDB.chars[key]
        local classColor = ns.GetClassColor(charData.class)
        local name = key
        if key == currentChar then name = name .. " *" end

        row.name:SetText(classColor .. name .. "|r")
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
                        print("|cff3FC7EB[MBT]|r " .. lure.color .. lure.name .. "|r marked for " .. key)
                    else
                        -- Clear the mark
                        cd.lures[lure.name] = nil
                        print("|cff3FC7EB[MBT]|r " .. lure.color .. lure.name .. "|r cleared for " .. key)
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

    -- Resize
    local n = math.max(#keys, 1)
    local h = TITLE_HEIGHT + 2 + ICON_ROW_HEIGHT + 5 + n * ROW_HEIGHT + PAD + 4
    local w = PAD * 2 + 8 + NAME_COL_WIDTH + #LURES * COL_WIDTH
    frame:SetSize(w, h)

    if #keys == 0 then
        if not charRows[1] then charRows[1] = CreateCharRow(1) end
        charRows[1].name:SetText(C_ACCENT:WrapTextInColorCode("No skinners found"))
        charRows[1].name:SetWidth(w - PAD * 2)
        charRows[1].name:Show()
        for _, cell in ipairs(charRows[1].cells) do
            cell:Hide()
        end
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
-- Periodic refresh
------------------------------------------------------

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
        frame:Show()
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

    local lureIcon = "Interface\\AddOns\\MajesticBeastTracker\\icon"

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
            .. "/mbt nuke all",
        rightText =
            "Show tracker\n\n"
            .. "Hide tracker\n\n"
            .. "Toggle frame lock\n\n"
            .. "Open settings\n\n"
            .. "Override talent points (0-40)\n\n"
            .. "Remove a character\n\n"
            .. "Clear current character\n\n"
            .. "Clear ALL data",
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

    -- Auto-Craft
    local s2 = Settings.RegisterAddOnSetting(category, "MBT_autoCraft", "autoCraft",
        MajesticBeastTrackerDB.settings, Settings.VarType.Boolean, "Auto-Craft on Double-Click", true)
    Settings.CreateCheckbox(category, s2, "Double-clicking a lure icon will craft the recipe if the profession window is open.")

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
