------------------------------------------------------
-- MajesticBeastTracker Calendar Picker Component
-- Reusable date picker with history highlight
------------------------------------------------------

local addonName, ns = ...

local CELL_SIZE = 24
local HEADER_HEIGHT = 22
local DAY_LABELS = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" }
local MONTH_NAMES = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
}

-- Get number of days in a month
local function DaysInMonth(year, month)
    local nextMonth = month + 1
    local nextYear = year
    if nextMonth > 12 then nextMonth = 1; nextYear = nextYear + 1 end
    -- Day 0 of next month = last day of this month
    return tonumber(date("%d", time({ year = nextYear, month = nextMonth, day = 0 })))
end

-- Get weekday of first day (1=Mon, 7=Sun)
local function FirstWeekday(year, month)
    local t = time({ year = year, month = month, day = 1 })
    local wday = tonumber(date("%w", t))  -- 0=Sun, 1=Mon, ..., 6=Sat
    if wday == 0 then wday = 7 end  -- shift Sunday to 7
    return wday
end

--- Create a calendar picker frame
--- @param parent Frame Parent frame
--- @param onDateSelected function Callback(dateStr "YYYY-MM-DD") called when a date is clicked
--- @return Frame calendarFrame with :SetHighlightDates(dates), :SetMonth(y,m), :Show(), :Hide()
function ns.CreateCalendarPicker(parent, onDateSelected)
    local BACKDROP = ns.BACKDROP
    local C_BORDER = ns.C_BORDER_RGB
    local GOLD = ns.C_TOOLBAR_ICON or { 0.82, 0.71, 0.35 }

    local WIDTH = 7 * CELL_SIZE + 16
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:SetBackdropBorderColor(C_BORDER[1], C_BORDER[2], C_BORDER[3])
    f:EnableMouse(true)
    f:Hide()

    -- State
    local curYear = tonumber(date("%Y"))
    local curMonth = tonumber(date("%m"))
    local highlightDates = {}  -- set of "YYYY-MM-DD" strings
    local selectedDate = nil

    -- Header: < Month Year >
    local prevBtn = CreateFrame("Button", nil, f)
    prevBtn:SetSize(20, 20)
    prevBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -4)
    local prevTex = prevBtn:CreateFontString(nil, "OVERLAY")
    prevTex:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    prevTex:SetAllPoints()
    prevTex:SetText("|cffD1B559<|r")
    prevBtn:SetScript("OnClick", function()
        curMonth = curMonth - 1
        if curMonth < 1 then curMonth = 12; curYear = curYear - 1 end
        f:Refresh()
    end)

    local nextBtn = CreateFrame("Button", nil, f)
    nextBtn:SetSize(20, 20)
    nextBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -4)
    local nextTex = nextBtn:CreateFontString(nil, "OVERLAY")
    nextTex:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    nextTex:SetAllPoints()
    nextTex:SetText("|cffD1B559>|r")
    nextBtn:SetScript("OnClick", function()
        curMonth = curMonth + 1
        if curMonth > 12 then curMonth = 1; curYear = curYear + 1 end
        f:Refresh()
    end)

    local monthLabel = f:CreateFontString(nil, "OVERLAY")
    monthLabel:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    monthLabel:SetPoint("TOP", f, "TOP", 0, -7)
    monthLabel:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    -- Day-of-week labels
    local dayLabels = {}
    for i = 1, 7 do
        local dl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dl:SetFont(dl:GetFont(), 9)
        dl:SetText(DAY_LABELS[i])
        dl:SetTextColor(0.6, 0.6, 0.6)
        dl:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (i - 1) * CELL_SIZE + CELL_SIZE / 2 - 6, -(HEADER_HEIGHT + 2))
        dayLabels[i] = dl
    end

    -- Day cells (max 42 = 6 weeks)
    local cells = {}
    for row = 0, 5 do
        for col = 0, 6 do
            local idx = row * 7 + col + 1
            local btn = CreateFrame("Button", nil, f)
            btn:SetSize(CELL_SIZE, CELL_SIZE)
            btn:SetPoint("TOPLEFT", f, "TOPLEFT",
                8 + col * CELL_SIZE,
                -(HEADER_HEIGHT + 14 + row * CELL_SIZE))

            local label = btn:CreateFontString(nil, "OVERLAY")
            label:SetFont(STANDARD_TEXT_FONT, 10)
            label:SetAllPoints()
            label:SetJustifyH("CENTER")
            label:SetJustifyV("MIDDLE")
            btn.label = label

            -- Highlight texture (for dates with data)
            local dot = btn:CreateTexture(nil, "BACKGROUND")
            dot:SetSize(4, 4)
            dot:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
            dot:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
            dot:Hide()
            btn.dot = dot

            -- Selection highlight
            local sel = btn:CreateTexture(nil, "BACKGROUND")
            sel:SetAllPoints()
            sel:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.2)
            sel:Hide()
            btn.sel = sel

            -- Hover
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.1)

            cells[idx] = btn
        end
    end

    -- Refresh display
    function f:Refresh()
        monthLabel:SetText(MONTH_NAMES[curMonth] .. " " .. curYear)

        local daysInMonth = DaysInMonth(curYear, curMonth)
        local firstDay = FirstWeekday(curYear, curMonth)
        local today = date("%Y-%m-%d")

        for idx = 1, 42 do
            local btn = cells[idx]
            local dayNum = idx - firstDay + 1
            if dayNum >= 1 and dayNum <= daysInMonth then
                local dateStr = string.format("%04d-%02d-%02d", curYear, curMonth, dayNum)
                btn.label:SetText(tostring(dayNum))
                btn:Show()

                -- Today
                if dateStr == today then
                    btn.label:SetTextColor(1, 1, 1)
                    btn.label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
                else
                    btn.label:SetTextColor(0.8, 0.8, 0.8)
                    btn.label:SetFont(STANDARD_TEXT_FONT, 10)
                end

                -- Has data dot
                if highlightDates[dateStr] then
                    btn.dot:Show()
                else
                    btn.dot:Hide()
                end

                -- Selected
                if dateStr == selectedDate then
                    btn.sel:Show()
                else
                    btn.sel:Hide()
                end

                btn:SetScript("OnClick", function()
                    selectedDate = dateStr
                    if onDateSelected then onDateSelected(dateStr) end
                    f:Refresh()
                end)
            else
                btn.label:SetText("")
                btn:Hide()
                btn.dot:Hide()
                btn.sel:Hide()
            end
        end

        -- Size: header + day labels + up to 6 rows
        local numRows = math.ceil((firstDay - 1 + daysInMonth) / 7)
        f:SetSize(WIDTH, HEADER_HEIGHT + 14 + numRows * CELL_SIZE + 8)
    end

    --- Set dates that should show a highlight dot
    --- @param dates table Set of "YYYY-MM-DD" = true
    function f:SetHighlightDates(dates)
        highlightDates = dates or {}
        f:Refresh()
    end

    --- Set displayed month
    function f:SetMonth(year, month)
        curYear = year
        curMonth = month
        f:Refresh()
    end

    --- Get selected date
    function f:GetSelectedDate()
        return selectedDate
    end

    --- Set selected date
    function f:SetSelectedDate(dateStr)
        selectedDate = dateStr
        if dateStr then
            local y, m = dateStr:match("^(%d+)-(%d+)")
            if y and m then
                curYear = tonumber(y)
                curMonth = tonumber(m)
            end
        end
        f:Refresh()
    end

    f:Refresh()
    return f
end
