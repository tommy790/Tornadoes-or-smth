if SERVER then return end

surface.CreateFont("GSMesoWatchFontLarge", {font = "Tahoma", size = ScreenScale(10), weight = 900, antialias = true})
surface.CreateFont("GSMesoWatchFontSmall", {font = "Tahoma", size = ScreenScale(6), weight = 700, antialias = true})
surface.CreateFont("GSMesoWatchFontMed", {font = "Tahoma", size = ScreenScale(8), weight = 900, antialias = true})
surface.CreateFont("GSMesoWatchFontTiny", {font = "Tahoma", size = ScreenScale(7), weight = 900, antialias = true})
surface.CreateFont("GSMesoWatchFontSmallTiny", {font = "Tahoma", size = ScreenScale(5), weight = 700, antialias = true})

local GSMesoWatchOutlineDark = Color(0, 0, 0, 230)
local GSMesoWatchOutlineLight = Color(255, 255, 255, 210)
local GSMesoWatchRiskColors = {
    TSTM = Color(195, 233, 194),
    MRGL = Color(21, 176, 84),
    SLGT = Color(255, 254, 48),
    ENH = Color(253, 162, 55),
    MDT = Color(253, 0, 23),
    HIGH = Color(254, 6, 253),
    NONE = Color(128, 128, 134)
}

local GSMesoWatchGradDown = Material("vgui/gradient-d")
local GSMesoWatchGradUp = Material("vgui/gradient-u")
local GSMesoWatchCircleMat = Material("vgui/circle")
local GSMesoWatchUiBg = Color(14, 15, 18, 245)
local GSMesoWatchUiPanel = Color(20, 21, 26, 235)
local GSMesoWatchUiPanel2 = Color(12, 13, 16, 240)
local GSMesoWatchUiBorder = Color(0, 0, 0, 220)
local GSMesoWatchUiBorderSoft = Color(255, 255, 255, 18)
local GSMesoWatchUiText = Color(235, 236, 240)
local GSMesoWatchUiTextMuted = Color(205, 207, 214)
local GSMesoWatchUiTextDim = Color(170, 172, 178)
local GSMesoWatchTextDark = Color(26, 27, 32)
local GSMesoWatchTextLight = Color(248, 248, 250)

local function GSNormalizeRisk(risk)

    local r = string.upper(tostring(risk or "NONE"))

    if r == "" then return "NONE" end

    if string.find(r, "HIGH", 1, true) then return "HIGH" end
    if string.find(r, "MDT", 1, true) or string.find(r, "MOD", 1, true) then return "MDT" end
    if string.find(r, "ENH", 1, true) then return "ENH" end
    if string.find(r, "SLGT", 1, true) or string.find(r, "SLIGHT", 1, true) then return "SLGT" end
    if string.find(r, "MRGL", 1, true) or string.find(r, "MARG", 1, true) then return "MRGL" end
    if string.find(r, "TSTM", 1, true) or string.find(r, "THUNDER", 1, true) then return "TSTM" end
    if string.find(r, "NONE", 1, true) or string.find(r, "NO ", 1, true) or string.find(r, "NO_", 1, true) or string.find(r, "NO", 1, true) then return "NONE" end

    return r

end

local function GSGetTextColorFor(bg)

    local lum = (bg.r * 0.299) + (bg.g * 0.587) + (bg.b * 0.114)
    return (lum > 165) and GSMesoWatchTextDark or GSMesoWatchTextLight

end

local function GSAccentFrom(bg, amt)
    return Color(math.Clamp(bg.r + amt, 0, 255), math.Clamp(bg.g + amt, 0, 255), math.Clamp(bg.b + amt, 0, 255), 255)
end

local function GSGetTextLum(col)
    return (col.r * 0.299) + (col.g * 0.587) + (col.b * 0.114)
end

local function GSPickColumnFonts(innerW, innerH)

    local candidates = {
        {day = "GSMesoWatchFontLarge", risk = "GSMesoWatchFontLarge", peak = "GSMesoWatchFontSmall"},
        {day = "GSMesoWatchFontMed", risk = "GSMesoWatchFontMed", peak = "GSMesoWatchFontSmallTiny"},
        {day = "GSMesoWatchFontTiny", risk = "GSMesoWatchFontTiny", peak = "GSMesoWatchFontSmallTiny"},
    }

    local dayStr = "Day 7"
    local riskStr = "SLGT"
    local peakStr = "Peak 23:59"

    local availW = innerW * 0.92
    local availH = innerH * 0.86

    for i = 1, #candidates do

        local c = candidates[i]

        surface.SetFont(c.day)
        local dayW, dayH = surface.GetTextSize(dayStr)

        surface.SetFont(c.risk)
        local riskW, riskH = surface.GetTextSize(riskStr)

        surface.SetFont(c.peak)
        local peakW, peakH = surface.GetTextSize(peakStr)

        local maxW = math.max(dayW, riskW, peakW)
        local spacing = math.max(2, math.floor(innerH * 0.045))
        local totalH = dayH + riskH + peakH + (spacing * 2)

        if maxW <= availW and totalH <= availH then return c.day, c.risk, c.peak end

    end

    local last = candidates[#candidates]
    return last.day, last.risk, last.peak

end

local function GSVal(v)
    if v == nil then return "—" end
    return isnumber(v) and tostring(math.Round(v, 2)) or tostring(v)
end

local function GSValU(v, unit)
    local s = GSVal(v)
    if s == "—" then return s end
    if !unit or unit == "" then return s end
    return s .. " " .. unit
end

local function GSWordWrap(text, font, maxW)

    if !text or text == "" then return {} end

    surface.SetFont(font)

    local words = string.Explode(" ", tostring(text))
    local lines = {}
    local cur = ""

    for i = 1, #words do

        local w = words[i]
        local test = (cur == "") and w or (cur .. " " .. w)

        local tw = surface.GetTextSize(test)

        if tw <= maxW then
            cur = test
        else
            if cur ~= "" then lines[#lines + 1] = cur end
            cur = w
        end

    end

    if cur ~= "" then lines[#lines + 1] = cur end

    return lines

end

function GSCreateMesowatchApp()

    local dFrame = vgui.Create("DFrame", GSGetComputerDesktop())
    dFrame:SetTitle("MesoWatch")
    dFrame:SetSizable(false)
    dFrame:SetDeleteOnClose(false)
    dFrame:SetSize(math.max(400, ScrW() * 0.6), math.max(360, ScrH() * 0.7))
    dFrame:SetPos(ScrW() * 0.32, ScrH() * 0.25)

    local dPnl = vgui.Create("DPanel", dFrame)
    dPnl:Dock(FILL)
    dPnl:SetMouseInputEnabled(true)

    dPnl.SelectedDay = 1
    dPnl.PageOffset = 0
    dPnl.NextCacheUpdate = 0
    dPnl.Cache = dPnl.Cache or {}
    dPnl.CacheCount = 0

    dPnl.Think = function(self)

        local time = CurTime()
        if time < self.NextCacheUpdate then return end

        self.NextCacheUpdate = time + 0.25

        local src = gs_clientsideoutlooktable
        self.CacheCount = 0

        for i = 1, 7 do

            self.CacheCount = self.CacheCount + 1
            self.Cache[self.CacheCount] = self.Cache[self.CacheCount] or {}
            local c = self.Cache[self.CacheCount]

            local e = istable(src) and src[i] or nil

            local risk = GSNormalizeRisk(e and e.RISK or "NONE")
            local col = GSMesoWatchRiskColors[risk] or GSMesoWatchRiskColors.NONE

            c.DayIndex = i
            c.DayLabel = "Day " .. tostring(i)
            c.Risk = risk
            c.Color = col
            c.TextColor = GSGetTextColorFor(col)
            c.PeakClock = GSTToClock(e and e.PEAKT or nil)

            c.CAPE = e and e.CAPE or nil
            c.SRH = e and e.SRH or nil
            c.LAPSE = e and e.LAPSE or nil
            c.RH = e and e.RH or nil
            c.SHEAR = e and e.SHEAR or nil
            c.TEMPERATURE = e and e.TEMPERATURE or nil

            c.WIND = e and e.WIND or nil
            c.SST = e and e.SST or nil
            c.VORT = e and e.VORT or nil
            c.PRESSURE = e and e.PRESSURE or nil

            c.OutlookString = e and (e.OUTLOOKSTRING or e.OUTLOOKSTRING_TEXT or e.OUTLOOK or e.OutlookString or e.Outlook or "") or ""

        end

        if self.SelectedDay > 7 then self.SelectedDay = 7 end
        if self.SelectedDay < 1 then self.SelectedDay = 1 end

    end

    dPnl.OnMouseWheeled = function(self, delta)

        if delta > 0 then self.PageOffset = math.max(self.PageOffset - 1, 0) end
        if delta < 0 then self.PageOffset = math.min(self.PageOffset + 1, math.max(0, 7 - (self.VisibleCount or 7))) end

    end

    dPnl.OnMousePressed = function(self, mc)

        if mc ~= MOUSE_LEFT then return end

        local mx, my = self:CursorPos()

        if self.ShowArrows then

            local lr = self.LeftArrowRect
            local rr = self.RightArrowRect

            if lr and mx >= lr.x and mx <= (lr.x + lr.w) and my >= lr.y and my <= (lr.y + lr.h) then
                self.PageOffset = math.max(self.PageOffset - 1, 0)
                return
            end

            if rr and mx >= rr.x and mx <= (rr.x + rr.w) and my >= rr.y and my <= (rr.y + rr.h) then
                self.PageOffset = math.min(self.PageOffset + 1, math.max(0, 7 - (self.VisibleCount or 7)))
                return
            end

        end

        local sx, sy, sw, sh = self.StripX, self.StripY, self.StripW, self.StripH
        if !sx then return end

        if mx < sx or mx > (sx + sw) or my < sy or my > (sy + sh) then return end

        local colW = self.ColW or 0
        if colW <= 0 then return end

        local idx = math.floor((mx - sx) / colW) + 1
        local dayIndex = (self.PageOffset or 0) + idx

        if dayIndex >= 1 and dayIndex <= 7 then
            self.SelectedDay = dayIndex
        end

    end

    dPnl.Paint = function(self, w, h)

        surface.SetDrawColor(GSMesoWatchUiBg)
        surface.DrawRect(0, 0, w, h)

        surface.SetDrawColor(255, 255, 255, 14)
        surface.SetMaterial(GSMesoWatchGradDown)
        surface.DrawTexturedRect(0, 0, w, h)

        surface.SetDrawColor(0, 0, 0, 90)
        surface.DrawRect(0, h - math.max(2, math.floor(h * 0.02)), w, math.max(2, math.floor(h * 0.02)))

        local pad = math.max(10, math.floor(w * 0.02))
        local stripH = math.floor(h * 0.62)
        local detailH = h - stripH - (pad * 2)
        local stripX, stripY = pad, pad
        local stripW = w - (pad * 2)

        self.StripX, self.StripY, self.StripW, self.StripH = stripX, stripY, stripW, stripH

        local minColW = math.max(90, math.floor(w * 0.13))
        local visibleCount = math.Clamp(math.floor(stripW / minColW), 3, 7)
        local colW = stripW / visibleCount

        self.VisibleCount = visibleCount
        self.ColW = colW

        local maxOffset = math.max(0, 7 - visibleCount)
        self.PageOffset = math.Clamp(self.PageOffset or 0, 0, maxOffset)

        local showArrows = (visibleCount < 7)
        self.ShowArrows = showArrows

        local radius = math.Clamp(math.floor(w * 0.006), 6, 12)
        local colRadius = math.max(4, math.floor(radius * 0.75))

        draw.RoundedBox(radius, stripX + 2, stripY + 3, stripW, stripH, Color(0, 0, 0, 120))
        draw.RoundedBox(radius, stripX, stripY, stripW, stripH, GSMesoWatchUiPanel)

        surface.SetDrawColor(255, 255, 255, 10)
        surface.SetMaterial(GSMesoWatchGradDown)
        surface.DrawTexturedRect(stripX, stripY, stripW, stripH)

        surface.SetDrawColor(GSMesoWatchUiBorder)
        surface.DrawOutlinedRect(stripX, stripY, stripW, stripH)

        surface.SetDrawColor(GSMesoWatchUiBorderSoft)
        surface.DrawOutlinedRect(stripX + 1, stripY + 1, stripW - 2, stripH - 2)

        local mx, my = self:CursorPos()
        local ot = math.Clamp(math.floor(w * 0.0012), 1, 2)

        local inset = math.max(6, math.floor(w * 0.006))
        local testInnerW = (colW - (inset * 2))
        local testInnerH = (stripH - (inset * 2))

        local fontDay, fontRisk, fontPeak = GSPickColumnFonts(testInnerW, testInnerH)

        surface.SetFont(fontDay)
        local dayW, dayH = surface.GetTextSize("Day 7")

        surface.SetFont(fontRisk)
        local riskW, riskH = surface.GetTextSize("SLGT")

        surface.SetFont(fontPeak)
        local peakW, peakH = surface.GetTextSize("Peak 23:59")

        local spacingBase = math.max(2, math.floor(testInnerH * 0.045))
        local groupH = dayH + riskH + peakH + (spacingBase * 2)

        for i = 1, visibleCount do

            local dayIndex = (self.PageOffset or 0) + i
            if dayIndex > 7 then break end

            local c = self.Cache[dayIndex]
            local bx = stripX + (i - 1) * colW
            local by = stripY
            local bw = colW
            local bh = stripH

            local bg = c and c.Color or GSMesoWatchRiskColors.NONE
            local tc = c and c.TextColor or GSMesoWatchUiText

            local isSelected = (dayIndex == (self.SelectedDay or 1))
            local isHover = (mx >= bx and mx <= (bx + bw) and my >= by and my <= (by + bh))

            local innerX = bx + inset
            local innerY = by + inset
            local innerW = bw - (inset * 2)
            local innerH = bh - (inset * 2)

            draw.RoundedBox(colRadius, innerX + 2, innerY + 3, innerW, innerH, Color(0, 0, 0, 95))
            draw.RoundedBox(colRadius, innerX, innerY, innerW, innerH, bg)

            surface.SetDrawColor(255, 255, 255, 14)
            surface.SetMaterial(GSMesoWatchGradDown)
            surface.DrawTexturedRect(innerX, innerY, innerW, innerH)

            surface.SetDrawColor(0, 0, 0, 18)
            surface.SetMaterial(GSMesoWatchGradUp)
            surface.DrawTexturedRect(innerX, innerY, innerW, innerH)

            local accent = GSAccentFrom(bg, 24)
            surface.SetDrawColor(accent)
            surface.DrawRect(innerX + 2, innerY + 2, innerW - 4, math.max(2, math.floor(innerH * 0.02)))

            surface.SetDrawColor(0, 0, 0, 160)
            surface.DrawOutlinedRect(innerX, innerY, innerW, innerH)

            if isSelected then
                surface.SetDrawColor(accent)
                surface.DrawOutlinedRect(innerX - 1, innerY - 1, innerW + 2, innerH + 2)
                surface.DrawOutlinedRect(innerX - 2, innerY - 2, innerW + 4, innerH + 4)
            elseif isHover then
                surface.SetDrawColor(255, 255, 255, 55)
                surface.DrawOutlinedRect(innerX - 1, innerY - 1, innerW + 2, innerH + 2)
            end

            local dayLabel = c and c.DayLabel or ("Day " .. tostring(dayIndex))
            local riskLabel = c and c.Risk or "NONE"
            local peakText = c and ("Peak " .. c.PeakClock) or "Peak --:--"

            local oc = (GSGetTextLum(tc) < 130) and GSMesoWatchOutlineLight or GSMesoWatchOutlineDark

            local marginY = math.max(4, math.floor(innerH * 0.08))
            local availH = innerH - (marginY * 2)
            local spacing = spacingBase

            if groupH > availH then
                spacing = math.max(2, math.floor((availH - (dayH + riskH + peakH)) * 0.5))
            end

            local totalH = dayH + riskH + peakH + (spacing * 2)
            local startY = innerY + marginY + math.max(0, (availH - totalH) * 0.5)

            local x = bx + bw * 0.5

            local yDay = startY + dayH * 0.5
            local yRisk = startY + dayH + spacing + riskH * 0.5
            local yPeak = startY + dayH + spacing + riskH + spacing + peakH * 0.5

            draw.SimpleTextOutlined(dayLabel, fontDay, x, yDay, tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, ot, oc)
            draw.SimpleTextOutlined(riskLabel, fontRisk, x, yRisk, tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, ot, oc)
            draw.SimpleTextOutlined(peakText, fontPeak, x, yPeak, tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, oc)

        end

        if showArrows then

            local btnS = math.max(18, math.floor(h * 0.07))
            local ay = stripY + stripH - btnS - 10

            local lx = stripX + 10
            local rx = stripX + stripW - btnS - 10

            self.LeftArrowRect = {x = lx, y = ay, w = btnS, h = btnS}
            self.RightArrowRect = {x = rx, y = ay, w = btnS, h = btnS}

            draw.RoundedBox(math.max(4, math.floor(radius * 0.6)), lx, ay, btnS, btnS, Color(240, 240, 240, 235))
            draw.RoundedBox(math.max(4, math.floor(radius * 0.6)), rx, ay, btnS, btnS, Color(240, 240, 240, 235))

            surface.SetDrawColor(255, 255, 255, 30)
            surface.SetMaterial(GSMesoWatchGradDown)
            surface.DrawTexturedRect(lx, ay, btnS, btnS)
            surface.DrawTexturedRect(rx, ay, btnS, btnS)

            surface.SetDrawColor(0, 0, 0, 210)
            surface.DrawOutlinedRect(lx, ay, btnS, btnS)
            surface.DrawOutlinedRect(rx, ay, btnS, btnS)

            draw.SimpleText("◄", "GSMesoWatchFontLarge", lx + btnS * 0.5, ay + btnS * 0.52, Color(18,18,18), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("►", "GSMesoWatchFontLarge", rx + btnS * 0.5, ay + btnS * 0.52, Color(18,18,18), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        end

        local detailX = pad
        local detailY = pad + stripH + pad
        local detailW = w - (pad * 2)

        local sel = self.Cache[self.SelectedDay or 1]
        local selCol = sel and sel.Color or GSMesoWatchRiskColors.NONE
        local selAccent = GSAccentFrom(selCol, 28)

        draw.RoundedBox(radius, detailX + 2, detailY + 3, detailW, detailH, Color(0, 0, 0, 120))
        draw.RoundedBox(radius, detailX, detailY, detailW, detailH, GSMesoWatchUiPanel2)

        surface.SetDrawColor(255, 255, 255, 10)
        surface.SetMaterial(GSMesoWatchGradDown)
        surface.DrawTexturedRect(detailX, detailY, detailW, detailH)

        surface.SetDrawColor(GSMesoWatchUiBorder.r, GSMesoWatchUiBorder.g, GSMesoWatchUiBorder.b, GSMesoWatchUiBorder.a)
        surface.DrawOutlinedRect(detailX, detailY, detailW, detailH)

        surface.SetDrawColor(GSMesoWatchUiBorderSoft.r, GSMesoWatchUiBorderSoft.g, GSMesoWatchUiBorderSoft.b, GSMesoWatchUiBorderSoft.a)
        surface.DrawOutlinedRect(detailX + 1, detailY + 1, detailW - 2, detailH - 2)

        local dotPad = 14
        local dotS = math.Clamp(math.floor(math.min(detailH, detailW) * 0.06), 10, 18)
        local dotX = detailX + dotPad
        local dotY = detailY + dotPad + 2

        surface.SetMaterial(GSMesoWatchCircleMat)

        surface.SetDrawColor(0, 0, 0, 140)
        surface.DrawTexturedRect(dotX - 1, dotY - 1, dotS + 2, dotS + 2)

        surface.SetDrawColor(selAccent)
        surface.DrawTexturedRect(dotX, dotY, dotS, dotS)

        if !sel then
            draw.SimpleText("Waiting for outlook data…", "GSDesktopFont", detailX + detailW * 0.5, detailY + detailH * 0.5, GSMesoWatchUiTextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local headerX = dotX + dotS + 10
        local headerY = detailY + 10

        local header = sel.DayLabel .. "  •  " .. sel.Risk .. "  •  Peak " .. sel.PeakClock
        draw.SimpleText(header, "GSDesktopFont", headerX, headerY, GSMesoWatchUiText, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        surface.SetDrawColor(255, 255, 255, 18)
        surface.DrawRect(detailX + 10, detailY + 32, detailW - 20, 1)

        local isTight = (detailH < 130 or detailW < 520)
        local detailFont = isTight and "GSMesoWatchFontSmallTiny" or "GSMesoWatchFontSmall"
        local hintFont = detailFont

        surface.SetFont(hintFont)
        local _, hintFontH = surface.GetTextSize("W")
        local hintPad = 8
        local hintY = detailY + detailH - (hintFontH + hintPad)

        local leftX = detailX + 10
        local rightX = detailX + math.floor(detailW * 0.5) + 10

        local rows = 5
        local topY = detailY + 40

        surface.SetFont(detailFont)
        local _, dfH = surface.GetTextSize("W")

        local lineStep = math.max(dfH + 2, math.floor((detailH - 96) / (rows + 3)))
        local fahrenheitConvar = GetConVar("gstorms_general_fahrenheit"):GetBool()

        local temp = sel.TEMPERATURE
        local sst = sel.SST
        
        if fahrenheitConvar then
            temp = (temp * 9/5) + 32
            sst = (sst  * 9/5) + 32
        end
        
        draw.SimpleText("CAPE: " .. GSValU(sel.CAPE, "J/kg"), detailFont, leftX, topY + (lineStep * 0), GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("SRH: " .. GSValU(sel.SRH, "m²/s²"), detailFont, leftX, topY + (lineStep * 1), GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("LAPSE: " .. GSValU(sel.LAPSE, "°C/km"), detailFont, leftX, topY + (lineStep * 2), GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("WIND: " .. GSValU(sel.WIND, "kt"), detailFont, leftX, topY + (lineStep * 3), GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("PRES: " .. GSValU(sel.PRESSURE, "hPa"), detailFont, leftX, topY + (lineStep * 4), GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        
        draw.SimpleText("RH: " .. GSValU(sel.RH, "%"), detailFont, rightX, topY + (lineStep * 0), GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("SHEAR: " .. GSValU(sel.SHEAR, "kt"), detailFont, rightX, topY + (lineStep * 1), GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("TEMP: " .. GSValU(temp, fahrenheitConvar and "°F" or "°C"), detailFont, rightX, topY + (lineStep * 2), GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("SST: " .. GSValU(sst, fahrenheitConvar and "°F" or "°C"), detailFont, rightX, topY + (lineStep * 3), GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("VORT: " .. GSValU(sel.VORT, "1e-5/s"), detailFont, rightX, topY + (lineStep * 4), GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        surface.SetDrawColor(255, 255, 255, 10)
        surface.DrawRect(detailX + math.floor(detailW * 0.5), topY, 1, (lineStep * rows) - 2)

        local outlookX = detailX + 10
        local outlookW = detailW - 20
        local outlookGap = math.max(4, math.floor(lineStep * 0.45))
        local outlookY = topY + (lineStep * rows) + outlookGap

        local outlookStr = tostring(sel.OutlookString or "")
        if outlookStr ~= "" then

            local outlookLabel = "Outlook:"
            surface.SetFont(detailFont)
            local labelW = surface.GetTextSize(outlookLabel)

            draw.SimpleText(outlookLabel, detailFont, outlookX, outlookY, GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local textX = outlookX + labelW + 6
            local textW = math.max(60, outlookW - (labelW + 6))

            local lineH = math.max(dfH, math.floor(lineStep * 0.9))
            local availH = (hintY - 6) - outlookY
            local maxLines = math.Clamp(math.floor(availH / math.max(10, lineH)), 0, 4)

            if maxLines > 0 then

                local lines = GSWordWrap(outlookStr, detailFont, textW)
                local drawLines = math.min(#lines, maxLines)

                local ly = outlookY

                for i = 1, drawLines do
                    draw.SimpleText(lines[i], detailFont, textX, ly, GSMesoWatchUiTextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    ly = ly + math.max(10, lineH)
                end

                if #lines > drawLines and drawLines > 0 then
                    draw.SimpleText("…", detailFont, textX, ly - math.max(8, math.floor(lineH * 0.45)), GSMesoWatchUiTextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

            end

        end

        draw.SimpleText("Click a day to view details • Mousewheel to scroll days", hintFont, detailX + 10, hintY, GSMesoWatchUiTextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    end

    GSSetupAppWindowControls(dFrame, 400, 360)

    dFrame.OnDesktopResized = function()
        if dFrame.GSFullscreen and dFrame.GSApplyFullscreen then dFrame:GSApplyFullscreen() end
    end
    
    dFrame.OnClose = function() GSCloseApp("MesoWatch") end
    
    dFrame:MakePopup()
    dFrame:SetKeyboardInputEnabled(false)
    dFrame:SetMouseInputEnabled(true)
    
    return dFrame

end