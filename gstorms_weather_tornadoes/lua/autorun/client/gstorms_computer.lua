if SERVER then return end

include("autorun/client/gstorms_clientside.lua")
include("autorun/gstorms_environment_handler.lua")
include("gstorms_computer_applications/gstorms_computer_applications_init.lua")

local laptopOptions = {keyInputDelay = 0.1, screenOpenRange = 100}

local desktopWindowSizeMult = 0.9

surface.CreateFont("GSDesktopFont", {font = "Tahoma", size = ScreenScale(7), weight = 600, antialias = true})
local DesktopMat = Material("computer/desktop_background.png", "smooth")

local GSDesktop = nil
local GSApps = {}
local GSIsComputerOpen = false
local GSComputerEntity = nil
local GSToggleCooldown = 0
local gsDesktopTimeText, gsDesktopTimeNextUpdate = "", 0
local computerNextPoll = 0
local playerIsNearComputer = false

function GSGetComputerDesktop() return GSDesktop end

local function GSCanReachComputer(ply, ent, maxDist)
    if !IsValid(ply) or !IsValid(ent) or ent:GetClass() ~= "gstorms_computer" then return false end
    return ply:EyePos():DistToSqr(ent:WorldSpaceCenter()) <= (maxDist * maxDist)
end

local function GSFindComputerByEyeTrace(ply, maxDist)

    if !IsValid(ply) then return nil end

    local startPos = ply:EyePos()
    local endPos = startPos + ply:GetAimVector() * maxDist
    local veh = ply:GetVehicle()
    local tr = util.TraceLine({start = startPos, endpos = endPos, filter = IsValid(veh) and {ply, veh} or ply, mask = MASK_SHOT})
    local ent = tr.Entity

    if IsValid(ent) and ent:GetClass() == "gstorms_computer" then return ent end

    return nil

end

local function GSSetScreenClicker(state)
    if vgui.CursorVisible() ~= state then gui.EnableScreenClicker(state) end
end

local function GSBringToFront(panel)
    if !IsValid(panel) then return end
    panel:SetVisible(true)
    panel:MoveToFront()
    panel:MakePopup()
    panel:SetKeyboardInputEnabled(false)
    panel:SetMouseInputEnabled(true)
end

local function GSSizeAndCenterDesktop(frame)
    local sw, sh = ScrW(), ScrH()
    local w, h = math.floor(sw * desktopWindowSizeMult), math.floor(sh * desktopWindowSizeMult)
    frame:SetSize(w, h)
    frame:Center()
end

local function GSIsAppOpen(key)
    return IsValid(GSApps[key]) and GSApps[key]:IsVisible()
end

local function GSOpenOrFocusApp(key, factory)
    local ply = LocalPlayer()

    ply.GSAppState = ply.GSAppState or {}

    if GSIsAppOpen(key) then
        GSBringToFront(GSApps[key])
        return GSApps[key]
    end

    if !IsValid(GSApps[key]) then GSApps[key] = factory() end

    local dPnl = GSApps[key]
    dPnl:SetVisible(true)
    GSBringToFront(dPnl)

    ply.GSAppState[key] = true

    return dPnl
end

function GSCloseApp(key)
    local ply = LocalPlayer()

    ply.GSAppState = ply.GSAppState or {}

    local dPnl = GSApps[key]

    if IsValid(dPnl) then
        if dPnl.GSRestoreFullscreen then dPnl:GSRestoreFullscreen() end
        dPnl:SetVisible(false)
    end

    ply.GSAppState[key] = false
end

local function GSRecordOpenApps()
    local ply = LocalPlayer()

    if !IsValid(ply) then return end

    ply.GSAppState = ply.GSAppState or {}

    for key, dPnl in pairs(GSApps) do
        ply.GSAppState[key] = IsValid(dPnl) and dPnl:IsVisible() or false
    end

end

function GSTToClock(t)
    if t == nil then return "--:--" end

    t = tonumber(t) or 0
    t = t - math.floor(t)

    local secs = math.floor(t * 86400 + 30) % 86400
    local hours = math.floor(secs / 3600)
    local minutes = math.floor((secs % 3600) / 60)

    return string.format("%02d:%02d", hours, minutes)
end

local function GSCloseComputer(force)

    local curTime = CurTime()

    if !force and curTime < GSToggleCooldown then return end

    GSToggleCooldown = curTime + laptopOptions.keyInputDelay

    GSRecordOpenApps()

    if GSStopSnekAppMusic then GSStopSnekAppMusic() end

    if IsValid(GSDesktop) then GSDesktop:SetVisible(false) end

    GSComputerEntity = nil
    GSIsComputerOpen = false
    GSSetScreenClicker(false)

end

function GSSetupAppWindowControls(dFrame, minW, minH)

    dFrame:SetSizable(false)

    local function setBounds(pnl, x, y, w, h)
        pnl:SetPos(x, y)
        pnl:SetSize(w, h)
    end

    local function fullscreenDesktop()
        if !IsValid(GSDesktop) then return end

        if GSDesktop.GSFullscreenApp ~= dFrame then
            local x, y = GSDesktop:GetPos()
            local w, h = GSDesktop:GetSize()

            GSDesktop.GSFullscreenRestoreBounds = {x = x, y = y, w = w, h = h}
            GSDesktop.GSFullscreenApp = dFrame
        end

        setBounds(GSDesktop, 0, 0, ScrW(), ScrH())
    end

    local function restoreDesktop()
        if !IsValid(GSDesktop) or GSDesktop.GSFullscreenApp ~= dFrame then return end

        local old = GSDesktop.GSFullscreenRestoreBounds

        GSDesktop.GSFullscreenApp = nil
        GSDesktop.GSFullscreenRestoreBounds = nil

        if old then
            setBounds(GSDesktop, old.x, old.y, old.w, old.h)
        else
            GSSizeAndCenterDesktop(GSDesktop)
        end
    end

    local function applyFullscreen()
        fullscreenDesktop()

        local parent = dFrame:GetParent()
        local w, h = IsValid(parent) and parent:GetSize() or ScrW(), ScrH()

        setBounds(dFrame, 0, 0, w, h)
    end

    local function restoreFullscreen()
        if !dFrame.GSFullscreen then return end

        dFrame.GSFullscreen = false
        restoreDesktop()

        local old = dFrame.GSRestoreBounds
        if old then setBounds(dFrame, old.x, old.y, old.w, old.h) end
    end

    local function toggleFullscreen()
        if dFrame.GSFullscreen then restoreFullscreen() return end

        local x, y = dFrame:GetPos()
        local w, h = dFrame:GetSize()

        dFrame.GSRestoreBounds = {x = x, y = y, w = w, h = h}
        dFrame.GSFullscreen = true

        applyFullscreen()
    end

    dFrame.GSApplyFullscreen = applyFullscreen
    dFrame.GSRestoreFullscreen = restoreFullscreen

    if IsValid(dFrame.btnMaxim) then
        dFrame.btnMaxim:SetVisible(true)
        if dFrame.btnMaxim.SetDisabled then dFrame.btnMaxim:SetDisabled(false) end
        dFrame.btnMaxim.DoClick = toggleFullscreen
    end

    local gripSize = 6
    local cornerSize = 14

    local gripDefs = {
        left = {"sizewe", true, false, false, false},
        right = {"sizewe", false, true, false, false},
        top = {"sizens", false, false, true, false},
        bottom = {"sizens", false, false, false, true},
        topLeft = {"sizenwse", true, false, true, false},
        topRight = {"sizenesw", false, true, true, false},
        bottomLeft = {"sizenesw", true, false, false, true},
        bottomRight = {"sizenwse", false, true, false, true}
    }

    local gripRects = {
        left = function(w, h) return 0, cornerSize, gripSize, h - cornerSize * 2 end,
        right = function(w, h) return w - gripSize, cornerSize, gripSize, h - cornerSize * 2 end,
        top = function(w, h) return cornerSize, 0, w - cornerSize * 2, gripSize end,
        bottom = function(w, h) return cornerSize, h - gripSize, w - cornerSize * 2, gripSize end,
        topLeft = function() return 0, 0, cornerSize, cornerSize end,
        topRight = function(w) return w - cornerSize, 0, cornerSize, cornerSize end,
        bottomLeft = function(_, h) return 0, h - cornerSize, cornerSize, cornerSize end,
        bottomRight = function(w, h) return w - cornerSize, h - cornerSize, cornerSize, cornerSize end
    }

    dFrame.GSResizeGrips = {}

    for name, data in pairs(gripDefs) do

        local grip = vgui.Create("DPanel", dFrame)

        grip:SetMouseInputEnabled(true)
        grip:SetCursor(data[1])
        grip.Paint = function() end

        grip.OnMousePressed = function(self, mc)
            if mc ~= MOUSE_LEFT or dFrame.GSFullscreen then return end

            local mx, my = input.GetCursorPos()
            local x, y = dFrame:GetPos()
            local w, h = dFrame:GetSize()

            self.Drag = {mx = mx, my = my, x = x, y = y, w = w, h = h}
            self:MouseCapture(true)
        end

        grip.OnMouseReleased = function(self)
            self.Drag = nil
            self:MouseCapture(false)
        end

        grip.Think = function(self)
            local drag = self.Drag
            if !drag then return end

            if !input.IsMouseDown(MOUSE_LEFT) then
                self.Drag = nil
                self:MouseCapture(false)
                return
            end

            local mx, my = input.GetCursorPos()
            local dx, dy = mx - drag.mx, my - drag.my
            local x, y, w, h = drag.x, drag.y, drag.w, drag.h

            if data[2] then x, w = drag.x + dx, drag.w - dx end
            if data[3] then w = drag.w + dx end
            if data[4] then y, h = drag.y + dy, drag.h - dy end
            if data[5] then h = drag.h + dy end

            if w < minW then
                if data[2] then x = drag.x + drag.w - minW end
                w = minW
            end

            if h < minH then
                if data[4] then y = drag.y + drag.h - minH end
                h = minH
            end

            setBounds(dFrame, x, y, w, h)
        end

        dFrame.GSResizeGrips[name] = grip

    end

    local oldPerformLayout = dFrame.PerformLayout

    dFrame.PerformLayout = function(self, w, h)
        if oldPerformLayout then oldPerformLayout(self, w, h) end

        local gs = self.GSResizeGrips
        if !gs then return end

        for name, grip in pairs(gs) do
            setBounds(grip, gripRects[name](w, h))
            grip:MoveToFront()
        end

        if IsValid(self.btnMaxim) then self.btnMaxim:MoveToFront() end
        if IsValid(self.btnClose) then self.btnClose:MoveToFront() end
    end

end

local GSAppDefinitions = GSGetComputerApplications()
local GSAppFactories = GSGetComputerApplicationFactories()

local function GSRestoreApps()

    local ply = LocalPlayer()

    if !IsValid(ply) or !ply.GSAppState then return end

    for key, shouldOpen in pairs(ply.GSAppState) do
        if shouldOpen then
            local factory = GSAppFactories[key]
            if factory then GSOpenOrFocusApp(key, factory) end
        end
    end

end

local function GSCreateDesktop()

    if IsValid(GSDesktop) then return GSDesktop end

    local dFrame = vgui.Create("DFrame")
    dFrame:SetTitle("")
    dFrame:ShowCloseButton(false)
    dFrame:SetDraggable(false)
    dFrame:SetSizable(false)
    dFrame:SetDeleteOnClose(false)
    dFrame:SetPopupStayAtBack(true)

    GSSizeAndCenterDesktop(dFrame)

    dFrame.Paint = function(_, w, h)

        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(DesktopMat)
        surface.DrawTexturedRect(0, 0, w, h)
    
        local curTime = CurTime()
    
        if curTime >= gsDesktopTimeNextUpdate then
    
            local tt = gs_timetable
            local dayNumber = (istable(tt) and tt.dayNumber) or 0
            local t = istable(tt) and tt.t or nil

            if t == nil and istable(tt) and tt.dayLengthSeconds then
                t = GetTimeBetweenZeroAndOne(curTime + (tt.startingTimeCurTime or 0), tt.dayLengthSeconds)
            end
    
            gsDesktopTimeText = "Day " .. tostring(dayNumber) .. "  •  " .. GSTToClock(t)
            gsDesktopTimeNextUpdate = curTime + 0.25
    
        end
    
        draw.SimpleTextOutlined(gsDesktopTimeText, "GSDesktopFont", w - 12, h - 10, Color(240,240,240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, Color(0,0,0,210))
    
    end

    dFrame.OnMousePressed = function(self)
        self:MoveToBack()
    end

    local closeBtn = vgui.Create("DButton", dFrame)
    closeBtn:SetText("✕")
    closeBtn:SetFont("GSDesktopFont")
    closeBtn:SetSize(36, 24)
    closeBtn.DoClick = function() GSCloseComputer() end

    local function PositionCloseBtn()
        closeBtn:SetPos(dFrame:GetWide() - closeBtn:GetWide() - 8, 8)
    end

    PositionCloseBtn()

    dFrame.OnScreenSizeChanged = function(self)

        GSSizeAndCenterDesktop(self)
        PositionCloseBtn()

        for _, app in pairs(GSApps) do
            if IsValid(app) and app.OnDesktopResized then app:OnDesktopResized() end
        end

    end

    dFrame.OnSizeChanged = function()
        PositionCloseBtn()
        for _, app in pairs(GSApps) do
            if IsValid(app) and app.OnDesktopResized then app:OnDesktopResized() end
        end
    end

    local iconPad = vgui.Create("DPanel", dFrame)
    iconPad:Dock(LEFT)
    iconPad:SetWide(math.max(120, math.floor(dFrame:GetWide() * 0.12)))
    iconPad.Paint = function() end

    local oldPerformLayout = dFrame.PerformLayout

    function dFrame:PerformLayout(w, h)
        if oldPerformLayout then oldPerformLayout(self, w, h) end
        iconPad:SetWide(math.max(120, math.floor(w * 0.12)))
    end

    local function GSAddDesktopIcon(parent, matPath, label, appKey, factory)

        local dPnl = vgui.Create("DButton", parent)
        dPnl:SetTall(96)
        dPnl:Dock(TOP)
        dPnl:DockMargin(16, 16, 16, 0)
        dPnl:SetText("")
        dPnl:SetDoubleClickingEnabled(false)

        local iconMat = Material(matPath or "")

        dPnl.Paint = function(_, w, h)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(iconMat)

            local s = math.min(w - 32, h - 40)

            surface.DrawTexturedRect((w - s) * 0.5, 6, s, s)
            draw.SimpleText(label or "App", "GSDesktopFont", w * 0.5, h - 18, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        function dPnl:DoClick() GSOpenOrFocusApp(appKey, factory) end

        return dPnl

    end

    for i = 1, #GSAppDefinitions do

        local app = GSAppDefinitions[i]

        GSAddDesktopIcon(iconPad, app.icon, app.text, app.key, app.factory)

    end

    return dFrame

end

local function GSOpenComputer(ent)

    local ply = LocalPlayer()
    local curTime = CurTime()

    if curTime < GSToggleCooldown then return end
    if !IsValid(ent) then return end
    if !GSCanReachComputer(ply, ent, laptopOptions.screenOpenRange) then return end

    GSToggleCooldown = curTime + laptopOptions.keyInputDelay
    GSComputerEntity = ent

    if !IsValid(GSDesktop) then GSDesktop = GSCreateDesktop() end

    GSSizeAndCenterDesktop(GSDesktop)
    GSDesktop:SetVisible(true)
    GSDesktop:MakePopup()
    GSDesktop:MoveToBack()
    GSDesktop:SetKeyboardInputEnabled(false)
    GSDesktop:SetMouseInputEnabled(true)

    GSIsComputerOpen = true

    ply.Radars = ents.FindByClass("gstorms_radar_*")

    GSSetScreenClicker(true)
    GSRestoreApps()

end

local function GSToggleComputer(ent)

    if GSIsComputerOpen then
        GSCloseComputer()
        return
    end

    GSOpenComputer(ent)

end

net.Receive("gs_computer_use", function()

    local ent = net.ReadEntity()
    if !IsValid(ent) or ent:GetClass() ~= "gstorms_computer" then return end

    GSToggleComputer(ent)

end)

hook.Add("Think", "GStorms_Computer_Background", function()

    local ply = LocalPlayer()
    local curTime = CurTime()

    if curTime + 3 < computerNextPoll then computerNextPoll = 0 end
    if !IsValid(ply) or curTime < computerNextPoll then return end

    computerNextPoll = curTime + 0.30
    playerIsNearComputer = GSFindComputerByEyeTrace(ply, laptopOptions.screenOpenRange) ~= nil

    if GSIsComputerOpen then

        ply.Radars = ents.FindByClass("gstorms_radar_*")

        if !GSCanReachComputer(ply, GSComputerEntity, laptopOptions.screenOpenRange) then
            GSCloseComputer(true)
        end

    end

end)

hook.Add("HUDPaint", "GStorms_Computer_UseHint", function()
    if !playerIsNearComputer or GSIsComputerOpen then return end
    draw.SimpleText('Press "USE" To Open Computer', "GSDesktopFont", ScrW()*0.5, ScrH()*0.92, Color(240,240,240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

hook.Add("HUDPaint", "GStorms_Computer_ExitHint", function()
    if !GSIsComputerOpen then return end
    draw.SimpleText('Press "USE" To Exit Computer', "GSDesktopFont", ScrW()*0.5, ScrH()*0.92, Color(240,240,240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

local function GSIsPhysgunBusy(ply)

    local wep = ply:GetActiveWeapon()

    return IsValid(wep) and wep:GetClass() == "weapon_physgun" and input.IsMouseDown(MOUSE_LEFT)

end

hook.Add("PlayerBindPress", "GStorms_Computer_OpenOnUse", function(ply, bind, pressed)

    if !pressed or !IsValid(ply) or bind ~= "+use" then return end

    if GSIsComputerOpen then
        GSCloseComputer()
        return true
    end

    if GSIsPhysgunBusy(ply) then return end
    if !ply:InVehicle() then return end

    local ent = GSFindComputerByEyeTrace(ply, laptopOptions.screenOpenRange)
    if !IsValid(ent) then return end

    GSOpenComputer(ent)
    return true

end)

hook.Add("ShutDown", "GS_Desktop_Shutdown", function()
    GSSetScreenClicker(false)
end)