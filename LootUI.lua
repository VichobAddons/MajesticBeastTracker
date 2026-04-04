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
    if not headerRow then
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
            if not row then
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
        if not totalRow then
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
    if not footerRow then
        footerRow = CreateFrame("Frame", nil, lootTooltip)
        footerRow:SetHeight(LT_ROW_HEIGHT)
        footerRow.text = footerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        footerRow.text:SetFont(footerRow.text:GetFont(), 9)
        footerRow.text:SetPoint("LEFT", footerRow, "LEFT", 8, 0)
        lootTooltip.rows[idx] = footerRow
    end
    footerRow:SetPoint("TOPLEFT", lootTooltip, "TOPLEFT", 0, yOff - 2)
    footerRow:SetPoint("TOPRIGHT", lootTooltip, "TOPRIGHT", 0, yOff - 2)
    footerRow.text:SetText("|cff888888Click to edit loot|r")
    footerRow:Show()
    yOff = yOff - LT_ROW_HEIGHT - 2

    -- Hide unused rows
    for i = idx + 1, #lootTooltip.rows do
        lootTooltip.rows[i]:Hide()
    end

    lootTooltip:SetSize(dynWidth, math.abs(yOff) + 6)
    lootTooltip:ClearAllPoints()
    lootTooltip:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
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
local LOOT_EDITOR_WIDTH = 320
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

    ns.lootEditor.title:SetText(ns.GetDemoName(charKey) .. " - Edit Loot")

    local sortedItems = BuildSortedLootList()

    local yOff = -(LE_TOOLBAR_HEIGHT + 8)
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
            editBox:SetBackdropBorderColor(0.82, 0.71, 0.35, 0.6)
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
            ns.lootEditor.rows[capturedIdx].countLabel:SetText("|cffffd700" .. rc .. "|r / " .. ac)
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
        lootSumScroll:SetVerticalScroll(0)
    end
end)

-- Scroll frame for content
local lsHeaderHeight = LS_TOOLBAR_HEIGHT + 4
local lootSumScroll = CreateFrame("ScrollFrame", nil, ns.lootSummary, "UIPanelScrollFrameTemplate")
lootSumScroll:SetPoint("TOPLEFT", ns.lootSummary, "TOPLEFT", 0, -lsHeaderHeight)
lootSumScroll:SetPoint("BOTTOMRIGHT", ns.lootSummary, "BOTTOMRIGHT", -20, 4)

local lootSumChild = CreateFrame("Frame", nil, lootSumScroll)
lootSumChild:SetWidth(LOOT_SUMMARY_WIDTH - 24)
lootSumScroll:SetScrollChild(lootSumChild)

-- Column group borders (inside scroll child, resized dynamically)
local LS_GROUP_WIDTH = LS_COL_COUNT + LS_COL_VALUE + 4

local resetBorder = CreateFrame("Frame", nil, lootSumChild, "BackdropTemplate")
resetBorder:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
resetBorder:SetBackdropBorderColor(0.82, 0.71, 0.35, 0.5)

local alltimeBorder = CreateFrame("Frame", nil, lootSumChild, "BackdropTemplate")
alltimeBorder:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
alltimeBorder:SetBackdropBorderColor(0.82, 0.71, 0.35, 0.5)

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
        resetBorder:Hide()
        alltimeBorder:Hide()
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
    headerRow.resetCount:SetText("|cffffd700Reset|r")
    headerRow.resetValue:SetText("")
    headerRow.alltimeCount:SetText("|cffffd700All Time|r")
    headerRow.alltimeValue:SetText("")
    headerRow:Show()
    yOff = yOff - LOOT_SUMMARY_ROW_HEIGHT

    -- Separator
    idx = idx + 1
    local sepRow = ns.lootSummary.rows[idx]
    if not sepRow then
        sepRow = CreateFrame("Frame", nil, container)
        sepRow:SetHeight(6)
        local sepTex = sepRow:CreateTexture(nil, "ARTWORK")
        sepTex:SetHeight(1)
        sepTex:SetPoint("LEFT", sepRow, "LEFT", 8, 0)
        sepTex:SetPoint("RIGHT", sepRow, "RIGHT", -8, 0)
        sepTex:SetColorTexture(0.3, 0.3, 0.3, 0.6)
        ns.lootSummary.rows[idx] = sepRow
    end
    sepRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
    sepRow:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)
    sepRow:Show()
    yOff = yOff - 6

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

            -- This Reset: count + value
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
        -- Separator before total
        idx = idx + 1
        local sepRow2 = ns.lootSummary.rows[idx]
        if not sepRow2 then
            sepRow2 = CreateFrame("Frame", nil, container)
            sepRow2:SetHeight(6)
            local sepTex2 = sepRow2:CreateTexture(nil, "ARTWORK")
            sepTex2:SetHeight(1)
            sepTex2:SetPoint("LEFT", sepRow2, "LEFT", 8, 0)
            sepTex2:SetPoint("RIGHT", sepRow2, "RIGHT", -8, 0)
            sepTex2:SetColorTexture(0.3, 0.3, 0.3, 0.6)
            ns.lootSummary.rows[idx] = sepRow2
        end
        sepRow2:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
        sepRow2:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)
        sepRow2:Show()
        yOff = yOff - 6

        idx = idx + 1
        local totalRow = ns.lootSummary.rows[idx]
        if not totalRow then
            totalRow = CreateLootSummaryRow(container)
            ns.lootSummary.rows[idx] = totalRow
        end
        totalRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
        totalRow:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)
        totalRow.item:SetText("|cffffd700Value:|r")
        totalRow.resetCount:SetText("")
        totalRow.resetValue:SetText(resetTotal > 0 and ("|cffffd700" .. ns.FormatGoldPositive(resetTotal) .. "|r") or "")
        totalRow.alltimeCount:SetText("")
        totalRow.alltimeValue:SetText(allTimeTotal > 0 and ("|cffffd700" .. ns.FormatGoldPositive(allTimeTotal) .. "|r") or "")
        totalRow:Show()
        yOff = yOff - LOOT_SUMMARY_ROW_HEIGHT
    end

    -- Per-beast breakdown (only if toggle is on)
    if ns.lootSummaryShowBreakdown and (globalPerBeastReset or globalPerBeast) then
        local perResetData = globalPerBeastReset or {}
        local perAllTimeData = globalPerBeast or {}

        for _, lure in ipairs(LURES) do
            local resetBl = perResetData[lure.name]
            local allTimeBl = perAllTimeData[lure.name]
            local hasReset = resetBl and next(resetBl)
            local hasAllTime = allTimeBl and next(allTimeBl)
            if hasReset or hasAllTime then
                yOff = yOff - 4
                idx = idx + 1
                local beastSep = ns.lootSummary.rows[idx]
                if not beastSep then
                    beastSep = CreateFrame("Frame", nil, container)
                    beastSep:SetHeight(6)
                    local bst = beastSep:CreateTexture(nil, "ARTWORK")
                    bst:SetHeight(1)
                    bst:SetPoint("LEFT", beastSep, "LEFT", 8, 0)
                    bst:SetPoint("RIGHT", beastSep, "RIGHT", -8, 0)
                    bst:SetColorTexture(0.82, 0.71, 0.35, 0.2)
                    ns.lootSummary.rows[idx] = beastSep
                end
                beastSep:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
                beastSep:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)
                beastSep:Show()
                yOff = yOff - 6

                idx = idx + 1
                local beastHeader = ns.lootSummary.rows[idx]
                if not beastHeader then
                    beastHeader = CreateLootSummaryRow(container)
                    ns.lootSummary.rows[idx] = beastHeader
                end
                beastHeader:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOff)
                beastHeader:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOff)
                beastHeader.item:SetText(lure.color .. lure.name .. "|r")
                beastHeader.resetCount:SetText("")
                beastHeader.resetValue:SetText("")
                beastHeader.alltimeCount:SetText("")
                beastHeader.alltimeValue:SetText("")
                beastHeader:Show()
                yOff = yOff - LOOT_SUMMARY_ROW_HEIGHT

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
                    beastRow.item:SetText("  " .. name)
                    beastRow.item:SetTextColor(r, g, b)
                    beastRow.resetCount:SetText(rc and ("x" .. rc) or "|cff666666—|r")
                    beastRow.resetCount:SetTextColor(rc and 0.9 or 0.4, rc and 0.9 or 0.4, rc and 0.9 or 0.4)
                    beastRow.resetValue:SetText("")
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
    local windowH = math.min(contentH + lsHeaderHeight + 4, LOOT_SUMMARY_MAX_HEIGHT)
    ns.lootSummary:SetSize(LOOT_SUMMARY_WIDTH, windowH)

    -- Position column group borders (inside scroll child)
    local borderTop = 0
    local borderH = contentH - 4
    resetBorder:ClearAllPoints()
    resetBorder:SetPoint("TOPLEFT", container, "TOPLEFT", LS_RESET_X - 4, borderTop)
    resetBorder:SetSize(LS_GROUP_WIDTH + 6, borderH)
    resetBorder:Show()

    alltimeBorder:ClearAllPoints()
    alltimeBorder:SetPoint("TOPLEFT", container, "TOPLEFT", LS_ALLTIME_X - 4, borderTop)
    alltimeBorder:SetSize(LS_GROUP_WIDTH + 6, borderH)
    alltimeBorder:Show()
end

ns._populateLootSummary = PopulateLootSummary

local function RepositionLootSummary()
    ns.lootSummary:ClearAllPoints()
    local frameRight = ns.frame:GetRight() or 0
    local screenWidth = GetScreenWidth()
    if frameRight + LOOT_SUMMARY_WIDTH + 8 > screenWidth then
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
        PopulateLootSummary()
        RepositionLootSummary()
        ns.lootSummary:Show()
    end
end
