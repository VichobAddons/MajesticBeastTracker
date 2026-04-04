------------------------------------------------------
-- MajesticBeastTracker Loot UI
-- Loot Editor, Loot Summary, Loot Tooltip helpers
------------------------------------------------------

local addonName, ns = ...
local LURES = ns.LURES

-- Local aliases from shared ns constants (set by UI.lua)
local MEDIA_PATH, BACKDROP, C_BORDER_RGB, C_TOOLBAR_ICON, C_TOOLBAR_ICON_HOVER, CreateToolbarButton

-- Deferred init: UI.lua sets ns.* before this file's frames are used
local function InitShared()
    MEDIA_PATH = ns.MEDIA_PATH
    BACKDROP = ns.BACKDROP
    C_BORDER_RGB = ns.C_BORDER_RGB
    C_TOOLBAR_ICON = ns.C_TOOLBAR_ICON
    C_TOOLBAR_ICON_HOVER = ns.C_TOOLBAR_ICON_HOVER
    CreateToolbarButton = ns.CreateToolbarButton
end
-- Call immediately since UI.lua loads before us
InitShared()

-- Block 1: Loot tooltip helpers
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
    -- List each item individually (separate quality tiers)
    local items = {}
    for id, count in pairs(lootTable) do
        if count > 0 then
            local name = C_Item.GetItemNameByID(id) or ("Item " .. id)
            local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(id) or 0
            items[#items + 1] = { id = id, name = name, quality = quality, count = count }
        end
    end
    table.sort(items, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.quality < b.quality
    end)

    for _, entry in ipairs(items) do
        local displayName = entry.name
        if entry.quality > 0 then
            displayName = displayName .. " |A:Professions-ChatIcon-Quality-12-Tier" .. entry.quality .. ":12:12::1|a"
        end
        local line = displayName .. "  x" .. entry.count
        if hasTSM then
            local price = savedPrices and savedPrices[entry.id]
            if not price then price = ns.GetTSMPrice(entry.id) end
            if price then
                local value = price * entry.count
                totalValue = totalValue + value
                line = line .. "  |cffffd700" .. ns.FormatGoldPositive(value) .. "|r"
            end
        end
        local r, g, b = 0.9, 0.9, 0.9
        local itemQuality = select(3, C_Item.GetItemInfo(entry.id))
        if itemQuality then
            local color = ITEM_QUALITY_COLORS[itemQuality]
            if color then r, g, b = color.r, color.g, color.b end
        end
        GameTooltip:AddLine(line, r, g, b)
    end

    if hasTSM and totalValue > 0 then
        GameTooltip:AddLine("Value: " .. ns.FormatGoldPositive(totalValue), 1, 0.84, 0)
    end
    return totalValue
end

-- Helper: build sorted item list from loot table
local function BuildItemList(lootTable, savedPrices)
    if not lootTable then return {}, 0 end
    local items = {}
    local totalValue = 0
    local hasTSM = TSM_API ~= nil
    for id, count in pairs(lootTable) do
        if count > 0 then
            local name = C_Item.GetItemNameByID(id) or ("Item " .. id)
            local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(id) or 0
            local displayName = name
            if quality > 0 then
                displayName = displayName .. " |A:Professions-ChatIcon-Quality-12-Tier" .. quality .. ":12:12::1|a"
            end
            local priceText = ""
            if hasTSM then
                local price = savedPrices and savedPrices[id]
                if not price then price = ns.GetTSMPrice(id) end
                if price then
                    totalValue = totalValue + price * count
                    priceText = "  |cffffd700" .. ns.FormatGoldPositive(price * count) .. "|r"
                end
            end
            local r, g, b = 0.9, 0.9, 0.9
            local itemQuality = select(3, C_Item.GetItemInfo(id))
            if itemQuality then
                local color = ITEM_QUALITY_COLORS[itemQuality]
                if color then r, g, b = color.r, color.g, color.b end
            end
            items[#items + 1] = { name = displayName, count = count, priceText = priceText, r = r, g = g, b = b, sortKey = name .. string.format("%02d", quality) }
        end
    end
    table.sort(items, function(a, b) return a.sortKey < b.sortKey end)
    return items, totalValue
end

------------------------------------------------------
-- Loot Tooltip (custom frame, 3-column layout)
------------------------------------------------------
local LT_COL_ITEM = 130
local LT_COL_COUNT = 45
local LT_COL_VALUE = 65
local LT_COL_GAP = 4
local LT_RESET_X = 8 + LT_COL_ITEM + LT_COL_GAP
local LT_ALLTIME_X = LT_RESET_X + LT_COL_COUNT + LT_COL_VALUE + LT_COL_GAP
local LT_WIDTH = 8 + LT_COL_ITEM + LT_COL_GAP + (LT_COL_COUNT + LT_COL_VALUE) * 2 + LT_COL_GAP + 12
local LT_ROW_HEIGHT = 14

local lootTooltip = CreateFrame("Frame", "MBT_LootTooltip", UIParent, "BackdropTemplate")
lootTooltip:SetFrameStrata("TOOLTIP")
lootTooltip:SetClampedToScreen(true)
lootTooltip:SetBackdrop(ns.BACKDROP)
lootTooltip:SetBackdropColor(0, 0, 0, 0.95)
lootTooltip:SetBackdropBorderColor(unpack(ns.C_BORDER_RGB))
lootTooltip:EnableMouse(false)
lootTooltip:Hide()
lootTooltip.rows = {}

local lootTTTitle = lootTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lootTTTitle:SetPoint("TOPLEFT", lootTooltip, "TOPLEFT", 8, -6)

local function CreateLootTooltipRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(LT_ROW_HEIGHT)
    row.item = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.item:SetFont(row.item:GetFont(), 9)
    row.item:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.item:SetWidth(LT_COL_ITEM)
    row.item:SetJustifyH("LEFT")
    row.item:SetWordWrap(false)
    row.resetCount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.resetCount:SetFont(row.resetCount:GetFont(), 9)
    row.resetCount:SetPoint("LEFT", row, "LEFT", LT_RESET_X, 0)
    row.resetCount:SetWidth(LT_COL_COUNT)
    row.resetCount:SetJustifyH("LEFT")
    row.resetValue = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.resetValue:SetFont(row.resetValue:GetFont(), 9)
    row.resetValue:SetPoint("LEFT", row, "LEFT", LT_RESET_X + LT_COL_COUNT, 0)
    row.resetValue:SetWidth(LT_COL_VALUE)
    row.resetValue:SetJustifyH("LEFT")
    row.alltimeCount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.alltimeCount:SetFont(row.alltimeCount:GetFont(), 9)
    row.alltimeCount:SetPoint("LEFT", row, "LEFT", LT_ALLTIME_X, 0)
    row.alltimeCount:SetWidth(LT_COL_COUNT)
    row.alltimeCount:SetJustifyH("LEFT")
    row.alltimeValue = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.alltimeValue:SetFont(row.alltimeValue:GetFont(), 9)
    row.alltimeValue:SetPoint("LEFT", row, "LEFT", LT_ALLTIME_X + LT_COL_COUNT, 0)
    row.alltimeValue:SetWidth(LT_COL_VALUE)
    row.alltimeValue:SetJustifyH("LEFT")
    return row
end

function ns.ShowLootTooltip(anchor, title, resetTable, allTimeTable, savedPrices)
    local resetItems, resetTotal = BuildItemList(resetTable, savedPrices)
    local allTimeItems, allTimeTotal = BuildItemList(allTimeTable, savedPrices)
    local hasTSM = TSM_API ~= nil

    -- Collect unique keys
    local allNames = {}
    local nameSet = {}
    for _, item in ipairs(resetItems) do
        if not nameSet[item.sortKey] then nameSet[item.sortKey] = true; allNames[#allNames + 1] = item.sortKey end
    end
    for _, item in ipairs(allTimeItems) do
        if not nameSet[item.sortKey] then nameSet[item.sortKey] = true; allNames[#allNames + 1] = item.sortKey end
    end
    table.sort(allNames)

    local resetByKey = {}
    for _, item in ipairs(resetItems) do resetByKey[item.sortKey] = item end
    local allTimeByKey = {}
    for _, item in ipairs(allTimeItems) do allTimeByKey[item.sortKey] = item end

    lootTTTitle:SetText("|cffD1B559" .. title .. "|r")

    -- Measure widest item name for dynamic column width
    local measureFS = lootTTTitle  -- reuse for measuring
    local maxNameWidth = LT_COL_ITEM  -- minimum
    for _, key in ipairs(allNames) do
        local ref = allTimeByKey[key] or resetByKey[key]
        if ref then
            measureFS:SetText(ref.name)
            local w = measureFS:GetStringWidth()
            if w and w > maxNameWidth then maxNameWidth = w end
        end
    end
    measureFS:SetText("|cffD1B559" .. title .. "|r")  -- restore title
    maxNameWidth = math.min(maxNameWidth + 8, 250)  -- cap + padding

    -- Dynamic offsets based on name width
    local dynResetX = 8 + maxNameWidth + LT_COL_GAP
    local dynAlltimeX = dynResetX + LT_COL_COUNT + LT_COL_VALUE + LT_COL_GAP
    local dynWidth = 8 + maxNameWidth + LT_COL_GAP + (LT_COL_COUNT + LT_COL_VALUE) * 2 + LT_COL_GAP + 12

    local idx = 0
    local yOff = -20

    -- Header
    idx = idx + 1
    local headerRow = lootTooltip.rows[idx]
    if not headerRow or not headerRow.item then
        headerRow = CreateLootTooltipRow(lootTooltip)
        lootTooltip.rows[idx] = headerRow
    end
    headerRow:SetPoint("TOPLEFT", lootTooltip, "TOPLEFT", 0, yOff)
    headerRow:SetPoint("TOPRIGHT", lootTooltip, "TOPRIGHT", 0, yOff)
    headerRow.item:SetText("")
    headerRow.item:SetWidth(maxNameWidth)
    headerRow.resetCount:SetText("|cffffd700Reset|r")
    headerRow.resetCount:ClearAllPoints()
    headerRow.resetCount:SetPoint("LEFT", headerRow, "LEFT", dynResetX, 0)
    headerRow.resetValue:SetText("")
    headerRow.alltimeCount:SetText("|cffffd700All Time|r")
    headerRow.alltimeCount:ClearAllPoints()
    headerRow.alltimeCount:SetPoint("LEFT", headerRow, "LEFT", dynAlltimeX, 0)
    headerRow.alltimeValue:SetText("")
    headerRow:Show()
    yOff = yOff - LT_ROW_HEIGHT

    -- Item rows
    for _, key in ipairs(allNames) do
        local ri = resetByKey[key]
        local ai = allTimeByKey[key]
        local ref = ai or ri
        if ref then
            idx = idx + 1
            local row = lootTooltip.rows[idx]
            if not row or not row.item then
                row = CreateLootTooltipRow(lootTooltip)
                lootTooltip.rows[idx] = row
            end
            row:SetPoint("TOPLEFT", lootTooltip, "TOPLEFT", 0, yOff)
            row:SetPoint("TOPRIGHT", lootTooltip, "TOPRIGHT", 0, yOff)
            row.item:SetText(ref.name)
            row.item:SetTextColor(ref.r, ref.g, ref.b)
            row.item:SetWidth(maxNameWidth)
            row.resetCount:ClearAllPoints()
            row.resetCount:SetPoint("LEFT", row, "LEFT", dynResetX, 0)
            row.resetCount:SetText(ri and ("x" .. ri.count) or "|cff666666—|r")
            row.resetCount:SetTextColor(ri and 0.9 or 0.4, ri and 0.9 or 0.4, ri and 0.9 or 0.4)
            row.resetValue:ClearAllPoints()
            row.resetValue:SetPoint("LEFT", row, "LEFT", dynResetX + LT_COL_COUNT, 0)
            row.resetValue:SetText(ri and ri.priceText ~= "" and ri.priceText or "")
            row.alltimeCount:ClearAllPoints()
            row.alltimeCount:SetPoint("LEFT", row, "LEFT", dynAlltimeX, 0)
            row.alltimeCount:SetText(ai and ("x" .. ai.count) or "")
            row.alltimeCount:SetTextColor(0.9, 0.9, 0.9)
            row.alltimeValue:ClearAllPoints()
            row.alltimeValue:SetPoint("LEFT", row, "LEFT", dynAlltimeX + LT_COL_COUNT, 0)
            row.alltimeValue:SetText(ai and ai.priceText ~= "" and ai.priceText or "")
            row:Show()
            yOff = yOff - LT_ROW_HEIGHT
        end
    end

    -- Value total
    if hasTSM and (resetTotal > 0 or allTimeTotal > 0) then
        idx = idx + 1
        local totalRow = lootTooltip.rows[idx]
        if not totalRow or not totalRow.item then
            totalRow = CreateLootTooltipRow(lootTooltip)
            lootTooltip.rows[idx] = totalRow
        end
        totalRow:SetPoint("TOPLEFT", lootTooltip, "TOPLEFT", 0, yOff)
        totalRow:SetPoint("TOPRIGHT", lootTooltip, "TOPRIGHT", 0, yOff)
        totalRow.item:SetText("|cffffd700Value:|r")
        totalRow.item:SetWidth(maxNameWidth)
        totalRow.resetCount:ClearAllPoints()
        totalRow.resetCount:SetPoint("LEFT", totalRow, "LEFT", dynResetX, 0)
        totalRow.resetCount:SetText("")
        totalRow.resetValue:ClearAllPoints()
        totalRow.resetValue:SetPoint("LEFT", totalRow, "LEFT", dynResetX + LT_COL_COUNT, 0)
        totalRow.resetValue:SetText(resetTotal > 0 and ("|cffffd700" .. ns.FormatGoldPositive(resetTotal) .. "|r") or "")
        totalRow.alltimeCount:ClearAllPoints()
        totalRow.alltimeCount:SetPoint("LEFT", totalRow, "LEFT", dynAlltimeX, 0)
        totalRow.alltimeCount:SetText("")
        totalRow.alltimeValue:ClearAllPoints()
        totalRow.alltimeValue:SetPoint("LEFT", totalRow, "LEFT", dynAlltimeX + LT_COL_COUNT, 0)
        totalRow.alltimeValue:SetText(allTimeTotal > 0 and ("|cffffd700" .. ns.FormatGoldPositive(allTimeTotal) .. "|r") or "")
        totalRow:Show()
        yOff = yOff - LT_ROW_HEIGHT
    end

    -- Footer
    idx = idx + 1
    local footerRow = lootTooltip.rows[idx]
    if not footerRow or not footerRow.item then
        footerRow = CreateLootTooltipRow(lootTooltip)
        lootTooltip.rows[idx] = footerRow
    end
    footerRow:SetPoint("TOPLEFT", lootTooltip, "TOPLEFT", 0, yOff - 2)
    footerRow:SetPoint("TOPRIGHT", lootTooltip, "TOPRIGHT", 0, yOff - 2)
    footerRow.item:SetText("|cff888888Click to edit loot|r")
    footerRow.item:SetTextColor(0.5, 0.5, 0.5)
    footerRow.resetCount:SetText("")
    footerRow.resetValue:SetText("")
    footerRow.alltimeCount:SetText("")
    footerRow.alltimeValue:SetText("")
    footerRow:Show()
    yOff = yOff - LT_ROW_HEIGHT - 2

    -- Hide unused rows
    for i = idx + 1, #lootTooltip.rows do
        lootTooltip.rows[i]:Hide()
    end

    lootTooltip:SetSize(dynWidth, math.abs(yOff) + 6)
    lootTooltip:ClearAllPoints()
    -- Position near anchor but ensure visibility above everything
    lootTooltip:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 4, 0)
    lootTooltip:SetFrameLevel(100)
    lootTooltip:Show()
end

function ns.HideLootTooltip()
    lootTooltip:Hide()
end

-- Legacy tooltip function (used by global goblin hover)
-- Reusable component: format a single loot column (item + count + value)
local function FormatLootEntry(item)
    if not item then return "|cff666666—|r" end
    local text = "x" .. item.count
    if item.priceText ~= "" then text = text .. " " .. item.priceText end
    return text
end

-- Reusable component: add a loot column to tooltip
-- lootTable = { [itemID] = count }, header = "Reset" or "All Time"
local function AddLootColumnToTooltip(items, total, header, isLeft)
    -- Returns formatted lines for this column
    local lines = {}
    for _, item in ipairs(items) do
        lines[item.sortKey] = FormatLootEntry(item)
    end
    return lines, total
end

function ns.AddLootTooltipColumns(resetTable, allTimeTable, savedPrices, perBeast, perBeastReset)
    local resetItems, resetTotal = BuildItemList(resetTable, savedPrices)
    local allTimeItems, allTimeTotal = BuildItemList(allTimeTable, savedPrices)
    local hasTSM = TSM_API ~= nil

    -- Collect all unique item keys
    local allNames = {}
    local nameSet = {}
    for _, item in ipairs(resetItems) do
        if not nameSet[item.sortKey] then nameSet[item.sortKey] = true; allNames[#allNames + 1] = item.sortKey end
    end
    for _, item in ipairs(allTimeItems) do
        if not nameSet[item.sortKey] then nameSet[item.sortKey] = true; allNames[#allNames + 1] = item.sortKey end
    end
    table.sort(allNames)

    -- Build lookup by sortKey
    local resetByKey = {}
    for _, item in ipairs(resetItems) do resetByKey[item.sortKey] = item end
    local allTimeByKey = {}
    for _, item in ipairs(allTimeItems) do allTimeByKey[item.sortKey] = item end

    -- Header
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("|cffffd700Reset|r", "|cffffd700All Time|r", 1, 0.84, 0, 1, 0.84, 0)

    -- Rows: left = item name + reset entry, right = alltime entry
    for _, key in ipairs(allNames) do
        local ri = resetByKey[key]
        local ai = allTimeByKey[key]
        local ref = ai or ri
        if ref then
            local leftText = ref.name .. "  " .. FormatLootEntry(ri)
            local rightText = FormatLootEntry(ai)
            GameTooltip:AddDoubleLine(leftText, rightText, ref.r, ref.g, ref.b, 0.9, 0.9, 0.9)
        end
    end

    -- Value totals
    if hasTSM and (resetTotal > 0 or allTimeTotal > 0) then
        local leftVal = resetTotal > 0 and ("|cffffd700Value: " .. ns.FormatGoldPositive(resetTotal) .. "|r") or " "
        local rightVal = allTimeTotal > 0 and ("|cffffd700Value: " .. ns.FormatGoldPositive(allTimeTotal) .. "|r") or " "
        GameTooltip:AddDoubleLine(leftVal, rightVal, 1, 0.84, 0, 1, 0.84, 0)
    end
end

-- Helper: add per-beast breakdown lines to tooltip
function ns.AddPerBeastTooltipLines(perBeastReset, perBeastAllTime)
    if not perBeastReset and not perBeastAllTime then return end
    local resetData = perBeastReset or {}
    local allTimeData = perBeastAllTime or {}

    -- Helper: format item name with quality icon
    local function formatItem(id)
        local name = C_Item.GetItemNameByID(id) or ("Item " .. id)
        local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(id)
        if quality and quality > 0 then
            name = name .. " |A:Professions-ChatIcon-Quality-12-Tier" .. quality .. ":12:12::1|a"
        end
        return name
    end

    local function getItemColor(id)
        local r, g, b = 0.9, 0.9, 0.9
        local itemQuality = select(3, C_Item.GetItemInfo(id))
        if itemQuality then
            local color = ITEM_QUALITY_COLORS[itemQuality]
            if color then r, g, b = color.r, color.g, color.b end
        end
        return r, g, b
    end

    for _, lure in ipairs(LURES) do
        local resetBl = resetData[lure.name]
        local allTimeBl = allTimeData[lure.name]
        local hasReset = resetBl and next(resetBl)
        local hasAllTime = allTimeBl and next(allTimeBl)
        if hasReset or hasAllTime then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(
                lure.color .. lure.name .. " (Reset)|r",
                lure.color .. lure.name .. " (All Time)|r",
                1, 1, 1, 1, 1, 1)

            -- Collect all item IDs from both
            local allIDs = {}
            local idSet = {}
            for id in pairs(allTimeBl or {}) do if not idSet[id] then idSet[id] = true; allIDs[#allIDs + 1] = id end end
            for id in pairs(resetBl or {}) do if not idSet[id] then idSet[id] = true; allIDs[#allIDs + 1] = id end end
            table.sort(allIDs, function(a, b)
                return (C_Item.GetItemNameByID(a) or "") < (C_Item.GetItemNameByID(b) or "")
            end)

            for _, id in ipairs(allIDs) do
                local name = formatItem(id)
                local r, g, b = getItemColor(id)
                local rc = resetBl and resetBl[id]
                local ac = allTimeBl and allTimeBl[id]
                local leftText = rc and ("  " .. name .. " x" .. rc) or " "
                local rightText = ac and (name .. " x" .. ac) or " "
                local lr, lg, lb = rc and r or 0.4, rc and g or 0.4, rc and b or 0.4
                local rr, rg, rb = ac and r or 0.4, ac and g or 0.4, ac and b or 0.4
                GameTooltip:AddDoubleLine(leftText, rightText, lr, lg, lb, rr, rg, rb)
            end
        end
    end
end

------------------------------------------------------
-- Loot Editor Panel
------------------------------------------------------

ns.lootEditor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
ns.lootEditor:SetFrameStrata("MEDIUM")
ns.lootEditor:SetClampedToScreen(true)
ns.lootEditor:SetBackdrop(ns.BACKDROP)
ns.lootEditor:SetBackdropColor(0, 0, 0, 0.97)
ns.lootEditor:SetBackdropBorderColor(unpack(ns.C_BORDER_RGB))
ns.lootEditor:EnableMouse(true)
ns.lootEditor:Hide()
ns.lootEditor.rows = {}
ns.lootEditor.charKey = nil

local LOOT_ROW_HEIGHT = 22
local LOOT_EDITOR_WIDTH = 360
local LE_TOOLBAR_HEIGHT = 20

-- Loot Editor toolbar
local leToolbar = CreateFrame("Frame", nil, ns.lootEditor)
leToolbar:SetPoint("TOPLEFT", ns.lootEditor, "TOPLEFT", 4, -4)
leToolbar:SetPoint("TOPRIGHT", ns.lootEditor, "TOPRIGHT", -4, -4)
leToolbar:SetHeight(LE_TOOLBAR_HEIGHT)
local leToolbarBg = leToolbar:CreateTexture(nil, "BACKGROUND")
leToolbarBg:SetAllPoints()
leToolbarBg:SetColorTexture(0, 0, 0, 0.4)
local leToolbarSep = leToolbar:CreateTexture(nil, "ARTWORK")
leToolbarSep:SetHeight(1)
leToolbarSep:SetPoint("BOTTOMLEFT", leToolbar, "BOTTOMLEFT")
leToolbarSep:SetPoint("BOTTOMRIGHT", leToolbar, "BOTTOMRIGHT")
leToolbarSep:SetColorTexture(ns.C_BORDER_RGB[1], ns.C_BORDER_RGB[2], ns.C_BORDER_RGB[3], 0.3)

-- Title in toolbar
local lootTitle = leToolbar:CreateFontString(nil, "OVERLAY")
lootTitle:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
lootTitle:SetPoint("LEFT", leToolbar, "LEFT", 4, 0)
lootTitle:SetTextColor(0.82, 0.71, 0.35)
ns.lootEditor.title = lootTitle

-- Close button (toolbar)
local lootClose = CreateToolbarButton(leToolbar,
    MEDIA_PATH .. "Icon_Close", "Close", nil,
    function() ns.lootEditor:Hide() end)
lootClose:SetSize(LE_TOOLBAR_HEIGHT, LE_TOOLBAR_HEIGHT)
lootClose:SetPoint("RIGHT", leToolbar, "RIGHT", -2, 0)
lootClose.icon:SetTexCoord(0, 1, 0, 1)
lootClose:SetScript("OnEnter", function(self)
    self.icon:SetVertexColor(1, 0.3, 0.3, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
    GameTooltip:AddLine("Close", 1, 1, 1)
    GameTooltip:Show()
end)
lootClose:SetScript("OnLeave", function(self)
    self.icon:SetVertexColor(C_TOOLBAR_ICON[1], C_TOOLBAR_ICON[2], C_TOOLBAR_ICON[3], 1)
    GameTooltip:Hide()
end)

-- Allow Decrease toggle (toolbar)
ns.lootEditorAllowDecrease = false
local leDecreaseBtn = CreateToolbarButton(leToolbar,
    MEDIA_PATH .. "Icon_Lock",
    function(self)
        local state = ns.lootEditorAllowDecrease
        GameTooltip:AddLine(state and "Lock All Time" or "Unlock All Time", 1, 1, 1)
        GameTooltip:AddLine("Allow decreasing Reset and All Time counts", 0.5, 0.8, 1, true)
    end,
    nil, nil)
leDecreaseBtn:SetSize(LE_TOOLBAR_HEIGHT, LE_TOOLBAR_HEIGHT)
leDecreaseBtn:SetPoint("RIGHT", lootClose, "LEFT", -2, 0)
leDecreaseBtn.icon:SetTexCoord(0, 1, 0, 1)
leDecreaseBtn.icon:SetAlpha(0.4)
leDecreaseBtn:SetScript("OnClick", function()
    ns.lootEditorAllowDecrease = not ns.lootEditorAllowDecrease
    leDecreaseBtn.icon:SetTexture(MEDIA_PATH .. (ns.lootEditorAllowDecrease and "Icon_LockOpen" or "Icon_Lock"))
    leDecreaseBtn.icon:SetAlpha(ns.lootEditorAllowDecrease and 1.0 or 0.4)
end)

-- History toggle (toolbar)
local leHistoryBtn = CreateToolbarButton(leToolbar,
    MEDIA_PATH .. "Icon_History",
    function(self)
        GameTooltip:AddLine("Loot History", 1, 1, 1)
        GameTooltip:AddLine("View daily loot history", 0.5, 0.8, 1, true)
    end,
    nil, nil)
leHistoryBtn:SetSize(LE_TOOLBAR_HEIGHT, LE_TOOLBAR_HEIGHT)
leHistoryBtn:SetPoint("RIGHT", leDecreaseBtn, "LEFT", -2, 0)
leHistoryBtn.icon:SetTexCoord(0, 1, 0, 1)
ns.lootEditorHistoryMode = false
ns.lootEditorHistoryPage = 0  -- 0 = current, 1 = yesterday, etc
leHistoryBtn:SetScript("OnClick", function()
    ns.lootEditorHistoryMode = not ns.lootEditorHistoryMode
    leHistoryBtn.icon:SetAlpha(ns.lootEditorHistoryMode and 1.0 or 0.4)
    if ns.lootEditorHistoryMode then
        ns.lootEditorHistoryPage = 1  -- start at yesterday
        -- Hide edit controls in history mode
        leDecreaseBtn:Hide()
    else
        ns.lootEditorHistoryPage = 0
        leDecreaseBtn:Show()
    end
    if ns.lootEditor:IsShown() and ns.lootEditor.charKey then
        ns._repopulateLootEditor()
    end
end)

-- History pagination controls (left of history button)
local lePageLeft = CreateToolbarButton(leToolbar,
    MEDIA_PATH .. "Icon_ChevronLeft", "Previous Day", nil, nil)
lePageLeft:SetSize(LE_TOOLBAR_HEIGHT, LE_TOOLBAR_HEIGHT)
lePageLeft:SetPoint("RIGHT", leHistoryBtn, "LEFT", 0, 0)
lePageLeft.icon:SetTexCoord(0, 1, 0, 1)
lePageLeft:Hide()
lePageLeft:SetScript("OnClick", function()
    if not ns.lootEditor.charKey then return end
    local charData = MajesticBeastTrackerDB.chars[ns.lootEditor.charKey]
    local maxPage = charData and charData.loot and charData.loot.history and #charData.loot.history or 0
    if ns.lootEditorHistoryPage < maxPage then
        ns.lootEditorHistoryPage = ns.lootEditorHistoryPage + 1
        ns._repopulateLootEditor()
    end
end)

local lePageRight = CreateToolbarButton(leToolbar,
    MEDIA_PATH .. "Icon_ChevronRight", "Next Day", nil, nil)
lePageRight:SetSize(LE_TOOLBAR_HEIGHT, LE_TOOLBAR_HEIGHT)
lePageRight:SetPoint("RIGHT", lePageLeft, "LEFT", 0, 0)
lePageRight.icon:SetTexCoord(0, 1, 0, 1)
lePageRight:Hide()
lePageRight:SetScript("OnClick", function()
    if ns.lootEditorHistoryPage > 1 then
        ns.lootEditorHistoryPage = ns.lootEditorHistoryPage - 1
        ns._repopulateLootEditor()
    end
end)

-- Syncing overlay
local syncOverlay = CreateFrame("Frame", nil, ns.lootEditor)
syncOverlay:SetAllPoints()
syncOverlay:SetFrameLevel(ns.lootEditor:GetFrameLevel() + 10)
syncOverlay:EnableMouse(true)
syncOverlay:Hide()
local syncBg = syncOverlay:CreateTexture(nil, "BACKGROUND")
syncBg:SetAllPoints()
syncBg:SetColorTexture(0, 0, 0, 0.7)
local syncText = syncOverlay:CreateFontString(nil, "OVERLAY")
syncText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
syncText:SetPoint("CENTER", 0, 0)
syncText:SetText("|cffD1B559Loot sync in progress...|r")
ns.lootEditor.syncOverlay = syncOverlay

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
    ns.lootEditor.charKey = charKey
    if anchor ~= ns.lootEditor then
        ns.lootEditor._anchor = anchor
    end
    local charData = MajesticBeastTrackerDB.chars[charKey]
    if not charData then return end

    -- Ensure loot structure
    if not charData.loot then
        charData.loot = { thisReset = {}, allTime = {}, resetTime = GetServerTime() }
    end
    local loot = ns.GetCharLoot(charData)
    local isHistory = ns.lootEditorHistoryMode and ns.lootEditorHistoryPage > 0
    local historyEntry = nil
    local historyLoot = nil

    if isHistory then
        local history = charData.loot and charData.loot.history
        if history and history[ns.lootEditorHistoryPage] then
            historyEntry = history[ns.lootEditorHistoryPage]
            historyLoot = historyEntry.items or {}
        else
            isHistory = false
        end
    end

    -- Show/hide pagination controls
    if ns.lootEditorHistoryMode then
        lePageLeft:Show()
        lePageRight:Show()
        local histDate = historyEntry and historyEntry.date or "—"
        ns.lootEditor.title:SetText(ns.GetDemoName(charKey) .. " — " .. histDate)
    else
        lePageLeft:Hide()
        lePageRight:Hide()
        ns.lootEditor.title:SetText(ns.GetDemoName(charKey) .. " - Edit Loot")
    end

    local sortedItems = BuildSortedLootList()

    -- Layout columns
    local LE_NAME_W = 150
    local LE_RESET_X = 8 + 18 + 5 + LE_NAME_W + 4  -- icon + name + gap
    local LE_ALLTIME_X = LE_RESET_X + 80  -- reset area (count + edit + buttons)

    local yOff = -(LE_TOOLBAR_HEIGHT + 8)

    -- Column header
    if not ns.lootEditor._header then
        local hdr = CreateFrame("Frame", nil, ns.lootEditor)
        hdr:SetHeight(14)
        local hdrReset = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdrReset:SetFont(hdrReset:GetFont(), 9)
        hdrReset:SetPoint("LEFT", hdr, "LEFT", LE_RESET_X, 0)
        hdr._resetLabel = hdrReset
        local hdrAllTime = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdrAllTime:SetFont(hdrAllTime:GetFont(), 9)
        hdrAllTime:SetPoint("LEFT", hdr, "LEFT", LE_ALLTIME_X, 0)
        hdrAllTime:SetText("|cffffd700All Time|r")
        ns.lootEditor._header = hdr
    end
    ns.lootEditor._header._resetLabel:SetText(isHistory and "|cffffd700Day|r" or "|cffffd700Reset|r")
    ns.lootEditor._header:SetPoint("TOPLEFT", ns.lootEditor, "TOPLEFT", 0, yOff)
    ns.lootEditor._header:SetPoint("TOPRIGHT", ns.lootEditor, "TOPRIGHT", 0, yOff)
    ns.lootEditor._header:Show()
    yOff = yOff - 16

    for idx, entry in ipairs(sortedItems) do
        local itemID = entry.id
        local row = ns.lootEditor.rows[idx]
        if not row then
            row = CreateFrame("Frame", nil, ns.lootEditor)
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
            name:SetWidth(LE_NAME_W)
            name:SetJustifyH("LEFT")
            name:SetWordWrap(false)
            row.nameText = name

            -- Reset count display (clickable to edit)
            local countBtn = CreateFrame("Button", nil, row)
            countBtn:SetSize(36, LOOT_ROW_HEIGHT)
            countBtn:SetPoint("LEFT", row, "LEFT", LE_RESET_X, 0)
            local countLabel = countBtn:CreateFontString(nil, "OVERLAY")
            countLabel:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            countLabel:SetAllPoints()
            countLabel:SetJustifyH("CENTER")
            row.countLabel = countLabel
            row.countBtn = countBtn

            -- Inline EditBox (hidden by default)
            local editBox = CreateFrame("EditBox", nil, row, "BackdropTemplate")
            editBox:SetSize(36, 16)
            editBox:SetPoint("LEFT", row, "LEFT", LE_RESET_X, 0)
            editBox:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            editBox:SetJustifyH("CENTER")
            editBox:SetAutoFocus(false)
            editBox:SetNumeric(true)
            editBox:SetMaxLetters(5)
            editBox:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
            editBox:SetBackdropColor(0, 0, 0, 0.9)
            editBox:SetBackdropBorderColor(0.82, 0.71, 0.35, 0.6)
            editBox:SetTextColor(1, 0.84, 0)
            editBox:Hide()
            row.editBox = editBox

            -- Minus button
            local minusBtn = CreateFrame("Button", nil, row)
            minusBtn:SetSize(18, 18)
            minusBtn:SetPoint("LEFT", row, "LEFT", LE_RESET_X + 38, 0)
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
            plusBtn:SetPoint("LEFT", row, "LEFT", LE_RESET_X + 56, 0)
            local plusTex = plusBtn:CreateFontString(nil, "OVERLAY")
            plusTex:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
            plusTex:SetAllPoints()
            plusTex:SetText("|cff44ff44+|r")
            local plusHl = plusBtn:CreateTexture(nil, "HIGHLIGHT")
            plusHl:SetAllPoints()
            plusHl:SetColorTexture(0.3, 1, 0.3, 0.15)
            row.plusBtn = plusBtn

            -- All Time label (readonly)
            local allTimeLabel = row:CreateFontString(nil, "OVERLAY")
            allTimeLabel:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            allTimeLabel:SetPoint("LEFT", row, "LEFT", LE_ALLTIME_X, 0)
            allTimeLabel:SetJustifyH("LEFT")
            allTimeLabel:SetTextColor(0.7, 0.7, 0.7)
            row.allTimeLabel = allTimeLabel

            ns.lootEditor.rows[idx] = row
        end

        row:SetPoint("TOPLEFT", ns.lootEditor, "TOPLEFT", 0, yOff)
        row:SetPoint("TOPRIGHT", ns.lootEditor, "TOPRIGHT", 0, yOff)

        -- Set item data
        local tex = C_Item.GetItemIconByID(itemID)
        if tex then row.icon:SetTexture(tex) end
        local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
        if entry.quality and entry.quality > 0 then
            itemName = itemName .. " |A:Professions-ChatIcon-Quality-12-Tier" .. entry.quality .. ":17:15::1|a"
        end
        row.nameText:SetText(itemName)
        row.nameText:SetTextColor(0.9, 0.9, 0.9)

        if isHistory then
            -- History mode: read-only, show history day count
            local histCount = historyLoot[itemID] or 0
            local allCount = loot.allTime[itemID] or 0
            row.countLabel:SetText(histCount > 0 and ("|cffffd700" .. histCount .. "|r") or "|cff666666—|r")
            row.allTimeLabel:SetText(tostring(allCount))
            row.editBox:Hide()
            row.countBtn:Show()
            row.minusBtn:Hide()
            row.plusBtn:Hide()
        else
            -- Normal edit mode
            local resetCount = loot.thisReset[itemID] or 0
            local allCount = loot.allTime[itemID] or 0
            row.countLabel:SetText("|cffffd700" .. resetCount .. "|r")
            row.allTimeLabel:SetText(tostring(allCount))
            row.editBox:Hide()
            row.countBtn:Show()
            row.minusBtn:Show()
            row.plusBtn:Show()
        end

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
            ns.lootEditor.rows[capturedIdx].countLabel:SetText("|cffffd700" .. rc .. "|r")
            ns.lootEditor.rows[capturedIdx].allTimeLabel:SetText(tostring(ac))
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
            -- Reset: always decreasable
            if cl.thisReset[capturedID] and cl.thisReset[capturedID] > 0 then
                cl.thisReset[capturedID] = cl.thisReset[capturedID] - 1
                if cl.thisReset[capturedID] <= 0 then cl.thisReset[capturedID] = nil end
            end
            -- All Time: only when unlocked
            if ns.lootEditorAllowDecrease then
                if cl.allTime[capturedID] and cl.allTime[capturedID] > 0 then
                    cl.allTime[capturedID] = cl.allTime[capturedID] - 1
                    if cl.allTime[capturedID] <= 0 then cl.allTime[capturedID] = nil end
                end
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
    for i = #sortedItems + 1, #ns.lootEditor.rows do
        ns.lootEditor.rows[i]:Hide()
    end

    ns.lootEditor:SetSize(LOOT_EDITOR_WIDTH, math.abs(yOff) + 8)
    ns.lootEditor:ClearAllPoints()
    -- Anchor to main frame side (same logic as loot summary)
    local frameRight = ns.frame:GetRight() or 0
    local screenWidth = GetScreenWidth()
    if frameRight + LOOT_EDITOR_WIDTH + 8 > screenWidth then
        ns.lootEditor:SetPoint("TOPRIGHT", ns.frame, "TOPLEFT", -4, 0)
    else
        ns.lootEditor:SetPoint("TOPLEFT", ns.frame, "TOPRIGHT", 4, 0)
    end
    -- Hide loot summary when editor opens (same space)
    if ns.lootSummary and ns.lootSummary:IsShown() then
        ns.lootSummary:Hide()
    end
    ns.lootEditor:Show()

    -- Show syncing overlay when loot sync is active
    if ns.isSyncingLoot then
        ns.lootEditor.syncOverlay:Show()
    else
        ns.lootEditor.syncOverlay:Hide()
    end
end

-- Preload item data then open editor
ns.ShowLootEditor = function(anchor, charKey)
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

-- Forward reference for history pagination
ns._repopulateLootEditor = function()
    if ns.lootEditor:IsShown() and ns.lootEditor.charKey then
        PopulateLootEditor(ns.lootEditor, ns.lootEditor.charKey)
    end
end

------------------------------------------------------
-- Loot Summary Window
------------------------------------------------------
local LS_COL_ITEM = 130
local LS_COL_COUNT = 45
local LS_COL_VALUE = 70
local LS_COL_GAP = 6
local LS_RESET_X = 8 + LS_COL_ITEM + LS_COL_GAP
local LS_ALLTIME_X = LS_RESET_X + LS_COL_COUNT + LS_COL_VALUE + LS_COL_GAP
local LOOT_SUMMARY_WIDTH = 8 + LS_COL_ITEM + LS_COL_GAP + (LS_COL_COUNT + LS_COL_VALUE) * 2 + LS_COL_GAP + 12
local LOOT_SUMMARY_ROW_HEIGHT = 16

ns.lootSummary = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
ns.lootSummary:SetFrameStrata("MEDIUM")
ns.lootSummary:SetClampedToScreen(true)
ns.lootSummary:SetBackdrop(ns.BACKDROP)
ns.lootSummary:SetBackdropColor(0, 0, 0, 0.97)
ns.lootSummary:SetBackdropBorderColor(unpack(ns.C_BORDER_RGB))
ns.lootSummary:EnableMouse(true)
ns.lootSummary:SetMovable(true)
ns.lootSummary:RegisterForDrag("LeftButton")
ns.lootSummary:SetScript("OnDragStart", function(self) self:StartMoving() end)
ns.lootSummary:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
ns.lootSummary:SetScript("OnEnter", function() ns.RefreshAutoHide() end)
ns.lootSummary:SetScript("OnLeave", function() ns.RefreshAutoHide() end)
ns.lootSummary:Hide()
ns.lootSummary.rows = {}

local LOOT_SUMMARY_MAX_HEIGHT = 400
local LS_TOOLBAR_HEIGHT = 20

-- Loot Summary toolbar
local lsToolbar = CreateFrame("Frame", nil, ns.lootSummary)
lsToolbar:SetPoint("TOPLEFT", ns.lootSummary, "TOPLEFT", 4, -4)
lsToolbar:SetPoint("TOPRIGHT", ns.lootSummary, "TOPRIGHT", -4, -4)
lsToolbar:SetHeight(LS_TOOLBAR_HEIGHT)
local lsToolbarBg = lsToolbar:CreateTexture(nil, "BACKGROUND")
lsToolbarBg:SetAllPoints()
lsToolbarBg:SetColorTexture(0, 0, 0, 0.4)
local lsToolbarSep = lsToolbar:CreateTexture(nil, "ARTWORK")
lsToolbarSep:SetHeight(1)
lsToolbarSep:SetPoint("BOTTOMLEFT", lsToolbar, "BOTTOMLEFT")
lsToolbarSep:SetPoint("BOTTOMRIGHT", lsToolbar, "BOTTOMRIGHT")
lsToolbarSep:SetColorTexture(ns.C_BORDER_RGB[1], ns.C_BORDER_RGB[2], ns.C_BORDER_RGB[3], 0.3)

local lootSumTitle = lsToolbar:CreateFontString(nil, "OVERLAY")
lootSumTitle:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
lootSumTitle:SetPoint("LEFT", lsToolbar, "LEFT", 4, 0)
lootSumTitle:SetTextColor(0.82, 0.71, 0.35)
lootSumTitle:SetText("Loot Summary")

-- Close button (toolbar)
local lootSumClose = CreateToolbarButton(lsToolbar,
    MEDIA_PATH .. "Icon_Close", "Close", nil,
    function() ns.lootSummary:Hide() end)
lootSumClose:SetSize(LS_TOOLBAR_HEIGHT, LS_TOOLBAR_HEIGHT)
lootSumClose:SetPoint("RIGHT", lsToolbar, "RIGHT", -2, 0)
lootSumClose.icon:SetTexCoord(0, 1, 0, 1)
lootSumClose:SetScript("OnEnter", function(self)
    self.icon:SetVertexColor(1, 0.3, 0.3, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
    GameTooltip:AddLine("Close", 1, 1, 1)
    GameTooltip:Show()
end)
lootSumClose:SetScript("OnLeave", function(self)
    self.icon:SetVertexColor(C_TOOLBAR_ICON[1], C_TOOLBAR_ICON[2], C_TOOLBAR_ICON[3], 1)
    GameTooltip:Hide()
end)

-- Show Breakdown toggle (toolbar)
ns.lootSummaryShowBreakdown = true
local lsBreakdownBtn = CreateToolbarButton(lsToolbar,
    MEDIA_PATH .. "Icon_Results",
    function(self)
        local state = ns.lootSummaryShowBreakdown
        GameTooltip:AddLine(state and "Hide Beast Breakdown" or "Show Beast Breakdown", 1, 1, 1)
    end,
    nil, nil)
lsBreakdownBtn:SetSize(LS_TOOLBAR_HEIGHT, LS_TOOLBAR_HEIGHT)
lsBreakdownBtn:SetPoint("RIGHT", lootSumClose, "LEFT", -2, 0)
lsBreakdownBtn.icon:SetTexCoord(0, 1, 0, 1)
lsBreakdownBtn:SetScript("OnClick", function()
    ns.lootSummaryShowBreakdown = not ns.lootSummaryShowBreakdown
    lsBreakdownBtn.icon:SetAlpha(ns.lootSummaryShowBreakdown and 1.0 or 0.4)
    if ns.lootSummary:IsShown() and ns._populateLootSummary then
        ns._populateLootSummary()
        if ns._lootSumScrollbar then ns._lootSumScrollbar:SetValue(0) end
    end
end)

-- Custom scroll frame (no UIPanelScrollFrameTemplate — avoids rendering glitches)
local lsHeaderHeight = LS_TOOLBAR_HEIGHT + 4
local LS_SCROLL_SPEED = LOOT_SUMMARY_ROW_HEIGHT * 3

local lootSumScroll = CreateFrame("ScrollFrame", nil, ns.lootSummary)
lootSumScroll:SetPoint("TOPLEFT", ns.lootSummary, "TOPLEFT", 0, -lsHeaderHeight)
lootSumScroll:SetPoint("BOTTOMRIGHT", ns.lootSummary, "BOTTOMRIGHT", -8, 4)

local lootSumChild = CreateFrame("Frame", nil, lootSumScroll)
lootSumChild:SetWidth(LOOT_SUMMARY_WIDTH - 16)
lootSumScroll:SetScrollChild(lootSumChild)

-- Vertical scrollbar (custom slider)
local lsScrollbar = CreateFrame("Slider", nil, ns.lootSummary, "UISliderTemplate")
ns._lootSumScrollbar = lsScrollbar
lsScrollbar:SetPoint("TOPRIGHT", ns.lootSummary, "TOPRIGHT", -2, -lsHeaderHeight)
lsScrollbar:SetPoint("BOTTOMRIGHT", ns.lootSummary, "BOTTOMRIGHT", -2, 4)
lsScrollbar:SetWidth(6)
lsScrollbar:SetMinMaxValues(0, 1)
lsScrollbar:SetValue(0)
lsScrollbar:SetValueStep(1)
lsScrollbar:SetOrientation("VERTICAL")
lsScrollbar:SetObeyStepOnDrag(true)
lsScrollbar.thumb = lsScrollbar:GetThumbTexture()
lsScrollbar.thumb:SetPoint("CENTER")
lsScrollbar.thumb:SetColorTexture(1, 1, 1, 0.15)
lsScrollbar.thumb:SetWidth(6)
if lsScrollbar.NineSlice then lsScrollbar.NineSlice:Hide() end
lsScrollbar:SetScript("OnValueChanged", function(_, value)
    lootSumScroll:SetVerticalScroll(value)
end)
lsScrollbar:SetScript("OnEnter", function() lsScrollbar.thumb:SetColorTexture(1, 1, 1, 0.25) end)
lsScrollbar:SetScript("OnLeave", function() lsScrollbar.thumb:SetColorTexture(1, 1, 1, 0.15) end)

local function UpdateLootSumScrollbar()
    local viewH = lootSumScroll:GetHeight()
    local contentH = lootSumChild:GetHeight()
    if contentH > viewH then
        lsScrollbar:SetMinMaxValues(0, contentH - viewH)
        lsScrollbar:SetValueStep(LS_SCROLL_SPEED)
        local ratio = viewH / contentH
        lsScrollbar.thumb:SetHeight(math.max(viewH * ratio, 20))
        lsScrollbar:Show()
    else
        lootSumScroll:SetVerticalScroll(0)
        lsScrollbar:SetValue(0)
        lsScrollbar:Hide()
    end
end

lootSumScroll:EnableMouseWheel(true)
lootSumScroll:SetScript("OnMouseWheel", function(_, delta)
    lsScrollbar:SetValue(lsScrollbar:GetValue() - delta * LS_SCROLL_SPEED)
end)
lootSumScroll:SetScript("OnSizeChanged", UpdateLootSumScrollbar)
lootSumChild:SetScript("OnSizeChanged", UpdateLootSumScrollbar)

-- Column group borders (inside scroll child, resized dynamically)


local function CreateLootSummaryRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(LOOT_SUMMARY_ROW_HEIGHT)
    -- Item name
    row.item = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.item:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.item:SetWidth(LS_COL_ITEM)
    row.item:SetJustifyH("LEFT")
    row.item:SetWordWrap(false)
    -- Reset count (left-aligned in reset group)
    row.resetCount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.resetCount:SetPoint("LEFT", row, "LEFT", LS_RESET_X, 0)
    row.resetCount:SetWidth(LS_COL_COUNT)
    row.resetCount:SetJustifyH("LEFT")
    -- Reset value (left-aligned in reset group)
    row.resetValue = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.resetValue:SetPoint("LEFT", row, "LEFT", LS_RESET_X + LS_COL_COUNT, 0)
    row.resetValue:SetWidth(LS_COL_VALUE)
    row.resetValue:SetJustifyH("LEFT")
    -- AllTime count (left-aligned in alltime group)
    row.alltimeCount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.alltimeCount:SetPoint("LEFT", row, "LEFT", LS_ALLTIME_X, 0)
    row.alltimeCount:SetWidth(LS_COL_COUNT)
    row.alltimeCount:SetJustifyH("LEFT")
    -- AllTime value (left-aligned in alltime group)
    row.alltimeValue = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.alltimeValue:SetPoint("LEFT", row, "LEFT", LS_ALLTIME_X + LS_COL_COUNT, 0)
    row.alltimeValue:SetWidth(LS_COL_VALUE)
    row.alltimeValue:SetJustifyH("LEFT")
    return row
end

local function PopulateLootSummary()
    local container = lootSumChild
    local resetLoot, allTimeLoot, globalPrices, globalPerBeast, globalPerBeastReset = ns.GetGlobalLoot()
    if not resetLoot and not allTimeLoot then
        for _, row in ipairs(ns.lootSummary.rows) do row:Hide() end
        lootSumTitle:SetText("Loot Summary — No data yet")
        ns.lootSummary:SetSize(LOOT_SUMMARY_WIDTH, 40)
        return
    end

    lootSumTitle:SetText("Loot Summary")
    local hasTSM = TSM_API ~= nil

    local resetItems, resetTotal = BuildItemList(resetLoot, globalPrices)
    local allTimeItems, allTimeTotal = BuildItemList(allTimeLoot, globalPrices)

    -- Collect all unique item keys
    local allNames = {}
    local nameSet = {}
    for _, item in ipairs(resetItems) do
        if not nameSet[item.sortKey] then nameSet[item.sortKey] = true; allNames[#allNames + 1] = item.sortKey end
    end
    for _, item in ipairs(allTimeItems) do
        if not nameSet[item.sortKey] then nameSet[item.sortKey] = true; allNames[#allNames + 1] = item.sortKey end
    end
    table.sort(allNames)

    local resetByKey = {}
    for _, item in ipairs(resetItems) do resetByKey[item.sortKey] = item end
    local allTimeByKey = {}
    for _, item in ipairs(allTimeItems) do allTimeByKey[item.sortKey] = item end

    -- Measure widest item name for dynamic column width
    local measureFS = lootSumTitle
    local maxNameW = LS_COL_ITEM
    for _, key in ipairs(allNames) do
        local ref = allTimeByKey[key] or resetByKey[key]
        if ref then
            measureFS:SetText(ref.name)
            local w = measureFS:GetStringWidth()
            if w and w > maxNameW then maxNameW = w end
        end
    end
    measureFS:SetText("Loot Summary")
    maxNameW = math.min(maxNameW + 8, 250)

    local dynResetX = 8 + maxNameW + LS_COL_GAP
    local dynAlltimeX = dynResetX + LS_COL_COUNT + LS_COL_VALUE + LS_COL_GAP
    local dynWidth = 8 + maxNameW + LS_COL_GAP + (LS_COL_COUNT + LS_COL_VALUE) * 2 + LS_COL_GAP + 32

    local idx = 0
    local yOff = -2

    -- Header row
    idx = idx + 1
    local headerRow = ns.lootSummary.rows[idx]
    if not headerRow then
        headerRow = CreateLootSummaryRow(container)
        ns.lootSummary.rows[idx] = headerRow
    end
    headerRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
    headerRow:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)
    headerRow.item:SetText("")
    headerRow.item:SetWidth(maxNameW)
    headerRow.resetCount:SetText("|cffffd700Reset|r")
    headerRow.resetCount:ClearAllPoints()
    headerRow.resetCount:SetPoint("LEFT", headerRow, "LEFT", dynResetX, 0)
    headerRow.resetValue:SetText("")
    headerRow.alltimeCount:SetText("|cffffd700All Time|r")
    headerRow.alltimeCount:ClearAllPoints()
    headerRow.alltimeCount:SetPoint("LEFT", headerRow, "LEFT", dynAlltimeX, 0)
    headerRow.alltimeValue:SetText("")
    headerRow:Show()
    yOff = yOff - LOOT_SUMMARY_ROW_HEIGHT

    yOff = yOff - 2

    -- Item rows — one row per item, 3 columns
    for _, key in ipairs(allNames) do
        local ri = resetByKey[key]
        local ai = allTimeByKey[key]
        if ai or ri then
            idx = idx + 1
            local row = ns.lootSummary.rows[idx]
            if not row then
                row = CreateLootSummaryRow(container)
                ns.lootSummary.rows[idx] = row
            end
            row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
            row:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)

            -- Item name (use alltime or reset data)
            local ref = ai or ri
            row.item:SetText(ref.name)
            row.item:SetTextColor(ref.r, ref.g, ref.b)
            row.item:SetWidth(maxNameW)

            -- This Reset: count + value
            row.resetCount:ClearAllPoints()
            row.resetCount:SetPoint("LEFT", row, "LEFT", dynResetX, 0)
            row.resetValue:ClearAllPoints()
            row.resetValue:SetPoint("LEFT", row, "LEFT", dynResetX + LS_COL_COUNT, 0)
            if ri then
                row.resetCount:SetText("x" .. ri.count)
                row.resetCount:SetTextColor(0.9, 0.9, 0.9)
                row.resetValue:SetText(ri.priceText ~= "" and ri.priceText or "")
                row.resetValue:SetTextColor(0.9, 0.9, 0.9)
            else
                row.resetCount:SetText("|cff666666—|r")
                row.resetCount:SetTextColor(0.4, 0.4, 0.4)
                row.resetValue:SetText("")
            end

            -- All Time: count + value
            row.alltimeCount:ClearAllPoints()
            row.alltimeCount:SetPoint("LEFT", row, "LEFT", dynAlltimeX, 0)
            row.alltimeValue:ClearAllPoints()
            row.alltimeValue:SetPoint("LEFT", row, "LEFT", dynAlltimeX + LS_COL_COUNT, 0)
            if ai then
                row.alltimeCount:SetText("x" .. ai.count)
                row.alltimeCount:SetTextColor(0.9, 0.9, 0.9)
                row.alltimeValue:SetText(ai.priceText ~= "" and ai.priceText or "")
                row.alltimeValue:SetTextColor(0.9, 0.9, 0.9)
            else
                row.alltimeCount:SetText("")
                row.alltimeValue:SetText("")
            end

            row:Show()
            yOff = yOff - LOOT_SUMMARY_ROW_HEIGHT
        end
    end

    -- Value totals
    if hasTSM and (resetTotal > 0 or allTimeTotal > 0) then
        yOff = yOff - 4

        idx = idx + 1
        local totalRow = ns.lootSummary.rows[idx]
        if not totalRow then
            totalRow = CreateLootSummaryRow(container)
            ns.lootSummary.rows[idx] = totalRow
        end
        totalRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
        totalRow:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)
        totalRow.item:SetText("|cffffd700Value:|r")
        totalRow.item:SetWidth(maxNameW)
        totalRow.resetCount:ClearAllPoints()
        totalRow.resetCount:SetPoint("LEFT", totalRow, "LEFT", dynResetX, 0)
        totalRow.resetCount:SetText("")
        totalRow.resetValue:ClearAllPoints()
        totalRow.resetValue:SetPoint("LEFT", totalRow, "LEFT", dynResetX + LS_COL_COUNT, 0)
        totalRow.resetValue:SetText(resetTotal > 0 and ("|cffffd700" .. ns.FormatGoldPositive(resetTotal) .. "|r") or "")
        totalRow.alltimeCount:ClearAllPoints()
        totalRow.alltimeCount:SetPoint("LEFT", totalRow, "LEFT", dynAlltimeX, 0)
        totalRow.alltimeCount:SetText("")
        totalRow.alltimeValue:ClearAllPoints()
        totalRow.alltimeValue:SetPoint("LEFT", totalRow, "LEFT", dynAlltimeX + LS_COL_COUNT, 0)
        totalRow.alltimeValue:SetText(allTimeTotal > 0 and ("|cffffd700" .. ns.FormatGoldPositive(allTimeTotal) .. "|r") or "")
        totalRow:Show()
        yOff = yOff - LOOT_SUMMARY_ROW_HEIGHT
    end

    -- Per-beast breakdown (only if toggle is on)
    if ns.lootSummaryShowBreakdown and (globalPerBeastReset or globalPerBeast) then
        -- Divider between summary and breakdown
        yOff = yOff - 2
        idx = idx + 1
        local divRow = ns.lootSummary.rows[idx]
        if not divRow or not divRow.item then
            divRow = CreateLootSummaryRow(container)
            ns.lootSummary.rows[idx] = divRow
        end
        divRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
        divRow:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)
        divRow.item:SetText("|cff555555" .. string.rep("—", 60) .. "|r")
        divRow.item:SetWidth(dynWidth)
        divRow.resetCount:SetText("")
        divRow.resetValue:SetText("")
        divRow.alltimeCount:SetText("")
        divRow.alltimeValue:SetText("")
        divRow:Show()
        yOff = yOff - 10
        local perResetData = globalPerBeastReset or {}
        local perAllTimeData = globalPerBeast or {}

        for _, lure in ipairs(LURES) do
            local resetBl = perResetData[lure.name]
            local allTimeBl = perAllTimeData[lure.name]
            local hasReset = resetBl and next(resetBl)
            local hasAllTime = allTimeBl and next(allTimeBl)
            if hasReset or hasAllTime then
                -- Space before beast header (no separator frame to avoid scroll rendering glitch)
                yOff = yOff - 8

                idx = idx + 1
                local beastHeader = ns.lootSummary.rows[idx]
                if not beastHeader then
                    beastHeader = CreateLootSummaryRow(container)
                    ns.lootSummary.rows[idx] = beastHeader
                end
                beastHeader:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
                beastHeader:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)
                beastHeader.item:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
                beastHeader.item:SetWidth(dynWidth - 16)
                -- Localized header: "Zone - NPC Name"
                local zoneName = lure.name
                if lure.waypoint and lure.waypoint.map then
                    local mapInfo = C_Map.GetMapInfo(lure.waypoint.map)
                    if mapInfo and mapInfo.name then zoneName = mapInfo.name end
                end
                local npcName = ""
                if lure.npcID then
                    -- Create hidden tooltip to scan NPC name
                    if not ns._npcTooltip then
                        ns._npcTooltip = CreateFrame("GameTooltip", "MBT_NPCTooltip", nil, "GameTooltipTemplate")
                        ns._npcTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
                    end
                    ns._npcTooltip:SetHyperlink("unit:Creature-0-0-0-0-" .. lure.npcID .. "-0")
                    local line1 = _G["MBT_NPCTooltipTextLeft1"]
                    if line1 then
                        local text = line1:GetText()
                        if text and text ~= "" then npcName = text end
                    end
                    ns._npcTooltip:ClearLines()
                end
                local headerText = zoneName
                if npcName ~= "" then headerText = headerText .. " — " .. npcName end
                beastHeader.item:SetText(lure.color .. headerText .. "|r")
                beastHeader.resetCount:SetText("")
                beastHeader.resetValue:SetText("")
                beastHeader.alltimeCount:SetText("")
                beastHeader.alltimeValue:SetText("")
                beastHeader:Show()
                yOff = yOff - LOOT_SUMMARY_ROW_HEIGHT - 2
                -- Reset font for item rows back to small after header
                -- (header uses 11pt, items use default 9pt from CreateLootSummaryRow)

                local allIDs = {}
                local idSet = {}
                for id in pairs(allTimeBl or {}) do if not idSet[id] then idSet[id] = true; allIDs[#allIDs + 1] = id end end
                for id in pairs(resetBl or {}) do if not idSet[id] then idSet[id] = true; allIDs[#allIDs + 1] = id end end
                table.sort(allIDs, function(a, b)
                    return (C_Item.GetItemNameByID(a) or "") < (C_Item.GetItemNameByID(b) or "")
                end)

                for _, id in ipairs(allIDs) do
                    local name = C_Item.GetItemNameByID(id) or ("Item " .. id)
                    local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(id)
                    if quality and quality > 0 then
                        name = name .. " |A:Professions-ChatIcon-Quality-12-Tier" .. quality .. ":12:12::1|a"
                    end
                    local r, g, b = 0.9, 0.9, 0.9
                    local itemQuality = select(3, C_Item.GetItemInfo(id))
                    if itemQuality then
                        local color = ITEM_QUALITY_COLORS[itemQuality]
                        if color then r, g, b = color.r, color.g, color.b end
                    end
                    local rc = resetBl and resetBl[id]
                    local ac = allTimeBl and allTimeBl[id]

                    idx = idx + 1
                    local beastRow = ns.lootSummary.rows[idx]
                    if not beastRow then
                        beastRow = CreateLootSummaryRow(container)
                        ns.lootSummary.rows[idx] = beastRow
                    end
                    beastRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
                    beastRow:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)
                    beastRow.item:SetFont(beastRow.item:GetFont(), 9)
                    beastRow.item:SetText(name)
                    beastRow.item:SetTextColor(r, g, b)
                    beastRow.item:SetWidth(maxNameW)
                    beastRow.resetCount:ClearAllPoints()
                    beastRow.resetCount:SetPoint("LEFT", beastRow, "LEFT", dynResetX, 0)
                    beastRow.resetCount:SetText(rc and ("x" .. rc) or "|cff666666—|r")
                    beastRow.resetCount:SetTextColor(rc and 0.9 or 0.4, rc and 0.9 or 0.4, rc and 0.9 or 0.4)
                    beastRow.resetValue:SetText("")
                    beastRow.alltimeCount:ClearAllPoints()
                    beastRow.alltimeCount:SetPoint("LEFT", beastRow, "LEFT", dynAlltimeX, 0)
                    beastRow.alltimeCount:SetText(ac and ("x" .. ac) or "")
                    beastRow.alltimeCount:SetTextColor(0.9, 0.9, 0.9)
                    beastRow.alltimeValue:SetText("")
                    beastRow:Show()
                    yOff = yOff - LOOT_SUMMARY_ROW_HEIGHT
                end
            end
        end
    end

    -- Hide unused rows
    for i = idx + 1, #ns.lootSummary.rows do
        ns.lootSummary.rows[i]:Hide()
    end

    local contentH = math.abs(yOff) + 8
    lootSumChild:SetHeight(contentH)
    lootSumChild:SetWidth(dynWidth - 24)
    local windowH = math.min(contentH + lsHeaderHeight + 4, LOOT_SUMMARY_MAX_HEIGHT)
    ns.lootSummary:SetSize(dynWidth, windowH)
    ns.lootSummary._dynWidth = dynWidth

end

ns._populateLootSummary = PopulateLootSummary

local function RepositionLootSummary()
    ns.lootSummary:ClearAllPoints()
    local w = ns.lootSummary._dynWidth or LOOT_SUMMARY_WIDTH
    local frameRight = ns.frame:GetRight() or 0
    local screenWidth = GetScreenWidth()
    if frameRight + w + 8 > screenWidth then
        ns.lootSummary:SetPoint("TOPRIGHT", ns.frame, "TOPLEFT", -4, 0)
    else
        ns.lootSummary:SetPoint("TOPLEFT", ns.frame, "TOPRIGHT", 4, 0)
    end
end
ns.RepositionLootSummary = RepositionLootSummary

function ns.ToggleLootSummary()
    if ns.lootSummary:IsShown() then
        ns.lootSummary:Hide()
    else
        -- Hide loot editor when summary opens (same space)
        if ns.lootEditor and ns.lootEditor:IsShown() then
            ns.lootEditor:Hide()
        end
        PopulateLootSummary()
        RepositionLootSummary()
        ns.lootSummary:Show()
    end
end
