if SERVER then return end

local appWindowSizeMult = 1.5

local radarModes = {
    {id = "Reflectivity", label = "Reflectivity", buffer = "GSReflectivityDataBuffer" },
    {id = "Velocity", label = "Velocity", buffer = "GSVelocityDataBuffer" },
    {id = "StormRelativeVelocity", label = "Storm Relative Velocity", buffer = "GSStormRelativeVelocityDataBuffer"},
    {id = "CorrelationCoefficient", label = "Correlation Coefficient", buffer = "GSCorrelationCoefficientDataBuffer"},
}

surface.CreateFont("GSRadarFontLarge", {font = "DermaDefaultBold", size = ScreenScale(7), weight = 600, antialias = true, outline = true})

local GSRadarMatCircle = Material("vgui/circle")

local function GSRadarSelectMenuOpen(combo)
    return IsValid(combo) and IsValid(combo.Menu) and combo.Menu:IsVisible()
end

local function GSClearRadarCacheFields(panel)
    panel.GridSquares = panel.GridSquares or {}
    panel.GridCount = 0
    panel.Dirty = true
end

local function GSComputeRadarRects(panel, ply, radar, data, size, centerX, centerY)

    local resolution = radar.Resolution or 64
    local range = radar.Range or 1000
    local centerWorld = radar.BeamLastCenter or radar:GetPos()
    local cellPixelSize = (size / resolution)

    panel.GridCount = 0

    local cap = panel.GridSquares
    if !istable(data) then return end

    for i = 1, #data do

        local entry = data[i]
        local worldPos = entry.position
        local color = entry.color
        
        if !color or !worldPos then continue end

        local localOffset = worldPos - centerWorld

        if math.abs(localOffset.x) > range or math.abs(localOffset.y) > range then continue end

        local normX = localOffset.x / range * 1.95
        local normY = localOffset.y / range * 1.95
        local pixelX = centerX + (normX * (size / 2))
        local pixelY = centerY - (normY * (size / 2))

        panel.GridCount = panel.GridCount + 1
        cap[panel.GridCount] = cap[panel.GridCount] or {}

        local r = cap[panel.GridCount]
        r.x = math.floor(pixelX - cellPixelSize * 0.5)
        r.y = math.floor(pixelY - cellPixelSize * 0.5)
        r.w = math.ceil(cellPixelSize)
        r.h = math.ceil(cellPixelSize)
        r.color = color

    end

    panel.Dirty = false

end

function GSCreateBeamApp()
    local dFrame = vgui.Create("DFrame", GSGetComputerDesktop())
    dFrame:SetTitle("Beam")
    dFrame:SetSizable(false)
    dFrame:SetDeleteOnClose(false)
    dFrame:SetSize(math.max(560, ScrW() * 0.45 * appWindowSizeMult), math.max(420, ScrH() * 0.5 * appWindowSizeMult))
    dFrame:SetPos(ScrW() * 0.25, ScrH() * 0.18)

    local topbar = vgui.Create("DPanel", dFrame)
    topbar:Dock(TOP)
    topbar:SetTall(40)
    topbar.Paint = function(_, w, h) surface.SetDrawColor(22, 22, 26, 230) surface.DrawRect(0, 0, w, h) end

    local content = vgui.Create("DPanel", dFrame)
    content:Dock(FILL)
    content.Paint = function() end

    local selectedModeIndex = 1

    local modeLabel = vgui.Create("DLabel", topbar)
    modeLabel:SetFont("GSRadarFontLarge")
    modeLabel:SetTextColor(color_white)
    modeLabel:SetText("Mode: " .. radarModes[selectedModeIndex].label)
    modeLabel:SizeToContents()
    modeLabel:Dock(FILL)
    modeLabel:SetContentAlignment(5)

    local radarPanel

    local btnLeft = vgui.Create("DButton", topbar)
    btnLeft:SetText("◄")
    btnLeft:SetWide(40)
    btnLeft:Dock(LEFT)
    btnLeft.DoClick = function()
        selectedModeIndex = selectedModeIndex - 1

        if selectedModeIndex < 1 then selectedModeIndex = #radarModes end

        modeLabel:SetText("Mode: " .. radarModes[selectedModeIndex].label)

        LocalPlayer().GSRadarModeSelected = radarModes[selectedModeIndex].id

        if IsValid(radarPanel) then radarPanel.Dirty = true end
    end

    local rightStrip = vgui.Create("DPanel", topbar)
    rightStrip:Dock(RIGHT)
    rightStrip:SetWide(260)
    rightStrip.Paint = function() end

    local btnRight = vgui.Create("DButton", rightStrip)
    btnRight:SetText("►")
    btnRight:SetWide(40)
    btnRight:Dock(LEFT)
    btnRight.DoClick = function()

        selectedModeIndex = selectedModeIndex + 1

        if selectedModeIndex > #radarModes then selectedModeIndex = 1 end

        modeLabel:SetText("Mode: " .. radarModes[selectedModeIndex].label)

        LocalPlayer().GSRadarModeSelected = radarModes[selectedModeIndex].id

        if IsValid(radarPanel) then radarPanel.Dirty = true end

    end

    local radarSelect = vgui.Create("DComboBox", rightStrip)
    radarSelect:Dock(FILL)
    radarSelect:SetSortItems(false)

    local function GSRefreshRadarList()

        if GSRadarSelectMenuOpen(radarSelect) then return end
    
        local ply = LocalPlayer()
        local currentSelection = IsValid(ply.GSRadarSelected) and ply.GSRadarSelected or nil
    
        radarSelect:Clear()
    
        if !ply.Radars or #ply.Radars == 0 then
            radarSelect:SetValue("No Radars")
            return
        end
    
        local hasCurrentSelection = false
    
        for i = 1, #ply.Radars do
            local r = ply.Radars[i]
    
            if IsValid(r) then
                local isSelected = (r == currentSelection)
    
                if isSelected then
                    hasCurrentSelection = true
                end
    
                radarSelect:AddChoice(r.RadarName or ("Radar " .. tostring(i)), r, isSelected)
            end
        end
    
        if hasCurrentSelection and IsValid(currentSelection) then
            ply.GSRadarSelected = currentSelection
            radarSelect:SetValue(currentSelection.RadarName or "Radar")
        else
            ply.GSRadarSelected = nil
    
            for i = 1, #ply.Radars do
                local r = ply.Radars[i]
                if IsValid(r) then
                    ply.GSRadarSelected = r
                    radarSelect:SetValue(r.RadarName or "Radar")
                    break
                end
            end
    
            if !IsValid(ply.GSRadarSelected) then
                radarSelect:SetValue("No Radars")
            end
        end
    
    end

    radarSelect.OnSelect = function(_, _, _, data)
        if IsValid(data) then
            LocalPlayer().GSRadarSelected = data
            if IsValid(radarPanel) then radarPanel.Dirty = true end
        end
    end

    radarPanel = vgui.Create("DPanel", content)
    radarPanel:Dock(FILL)
    radarPanel.GridSquares = {}
    radarPanel.GridCount = 0
    radarPanel.Dirty = true
    radarPanel.ClientUpdateCheck = 0
    radarPanel.NextUIRefresh = 0
    radarPanel.Paint = function(self, w, h)

        local ply = LocalPlayer()

        surface.SetDrawColor(0, 0, 0, 240)
        surface.DrawRect(0, 0, w, h)

        local radar = ply.GSRadarSelected

        if !IsValid(radar) then
            draw.SimpleText("No Radar Selected", "GSRadarFontLarge", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local size = math.min(w, h) * 0.92 * (appWindowSizeMult * 0.75)
        local vx = (w - size) * 0.5
        local vy = (h - size) * 0.5
        local centerX = vx + size * 0.5
        local centerY = vy + size * 0.5

        if self.Dirty then
            local bufName = radarModes[selectedModeIndex].buffer

            ply.GSDataSelected = radar[bufName]

            GSComputeRadarRects(self, ply, radar, ply.GSDataSelected, size, centerX, centerY)
        end

        for i = 1, self.GridCount do

            local r = self.GridSquares[i]

            if r then
                surface.SetDrawColor(r.color.r, r.color.g, r.color.b, 255)
                surface.DrawRect(r.x, r.y, r.w, r.h)
            end

        end

        if !istable(ply.Radars) then return end

        local clipX1, clipY1 = self:LocalToScreen(math.floor(vx), math.floor(vy))
        local clipX2, clipY2 = self:LocalToScreen(math.ceil(vx + size), math.ceil(vy + size))
        
        local clipPadX = size * 0.012
        
        render.SetScissorRect(clipX1 + clipPadX, clipY1, clipX2 - clipPadX, clipY2, true)

        local range = radar.Range or 1000
        local centerWorld = radar.BeamLastCenter or radar:GetPos()

        for _, rr in ipairs(ply.Radars) do

            if !IsValid(rr) then continue end

            local localOffset = rr:GetPos() - centerWorld

            if math.abs(localOffset.x) > range or math.abs(localOffset.y) > range then continue end

            local normX = localOffset.x / range * 1.95
            local normY = localOffset.y / range * 1.95
            local px = centerX + (normX * (size / 2))
            local py = centerY - (normY * (size / 2))
            local circleRadius = size / 50
            local circleDiameter = circleRadius * 2

            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(GSRadarMatCircle)
            surface.DrawTexturedRect(px - circleRadius, py - circleRadius, circleDiameter, circleDiameter)

            draw.SimpleText(rr.RadarName or "Radar", "GSRadarFontLarge", px, py - circleRadius - (size * 0.01), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

        end

        render.SetScissorRect(0, 0, 0, 0, false)
    end

    radarPanel.Think = function(self)

        local time = CurTime()
        local ply = LocalPlayer()

        if time >= self.NextUIRefresh then
            GSRefreshRadarList()
            self.NextUIRefresh = time + 2
        end

        if time < self.ClientUpdateCheck then return end

        self.ClientUpdateCheck = time + 0.05

        if !dFrame:IsVisible() then return end

        local radar = ply.GSRadarSelected

        if !IsValid(radar) then return end

        radar.RadarUpdateTime = radar.RadarUpdateTime or time

        local bufName = radarModes[selectedModeIndex].buffer

        if ((time - radar.RadarUpdateTime) >= (radar.UpdateRate or 0.25)) or !radar[bufName] then
            GSRadarUpdateClient(ply, radar)
            radar.BeamLastCenter = radar:GetPos()
            radar.RadarUpdateTime = time
            self.Dirty = true
        end

    end

    GSSetupAppWindowControls(dFrame, 560, 420)

    dFrame.OnDesktopResized = function()
        if dFrame.GSFullscreen and dFrame.GSApplyFullscreen then dFrame:GSApplyFullscreen() end
        GSClearRadarCacheFields(radarPanel)
    end
    
    dFrame.OnSizeChanged = function()
        if IsValid(radarPanel) then GSClearRadarCacheFields(radarPanel) end
    end
    
    dFrame.OnClose = function() GSCloseApp("Beam") end
    dFrame:MakePopup()
    dFrame:SetKeyboardInputEnabled(false)
    dFrame:SetMouseInputEnabled(true)

    return dFrame

end