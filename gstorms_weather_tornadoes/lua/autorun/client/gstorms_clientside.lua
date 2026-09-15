if SERVER then return end

-- locals and globals

local netReceive = net.Receive
local netReadString = net.ReadString
local netReadTable = net.ReadTable
local netStart = net.Start
local netWriteEntity = net.WriteEntity
local netSendToServer = net.SendToServer

local notificationAddLegacy = notification.AddLegacy
local surfacePlaySound = surface.PlaySound

local entsFindByClass = ents.FindByClass

local camStart3D = cam.Start3D
local camEnd3D = cam.End3D
local camStart3D2D = cam.Start3D2D
local camEnd3D2D = cam.End3D2D

local drawSimpleTextOutlined = draw.SimpleTextOutlined
local drawSimpleText = draw.SimpleText

local inputIsKeyDown = input.IsKeyDown

local mathFloor = math.floor
local mathRound = math.Round

-- tip + outlook table

netReceive("gs_send_tip", function()
    local tip = netReadString()
    notificationAddLegacy(tip, NOTIFY_HINT, 5)
    surfacePlaySound("ambient/water/drip2.wav")
end)

gs_clientsideoutlooktable = {}

netReceive("gs_send_outlooktable", function()
    gs_clientsideoutlooktable = netReadTable()
end)

-- For probe hud rendering etc,.

local colWhite = Color(255,255,255) -- shared colors (prevents reconstructioh and gc pressure)
local colGray215 = Color(215,215,215)
local colGray200 = Color(200,200,200)
local colBlack240 = Color(0,0,0,240)
local colBlack220 = Color(0,0,0,220)

surface.CreateFont("GSProbeFontSmall", {font = "Trebuchet MS", size = 32, weight = 1000, antialias = true, extended = true})
surface.CreateFont("GSSeismomgraphFontSmall", {font = "Trebuchet MS", size = 32, weight = 1000, antialias = true, extended = true})
surface.CreateFont("GSThermometerFontSmall", {font = "Trebuchet MS", size = 32, weight = 1000, antialias = true, extended = true})

local maxInteractDistance = 100
local maxRenderDistance = 200
local maxRenderDistanceSqr = maxRenderDistance * maxRenderDistance

local lastFPress = 0

local probeList = {}
local thermoList = {}
local seismoList = {}
local nextListRefresh = 0
local listRefreshRate = 0.25

local probeTextOffset = Vector(0, 0, 35)
local thermoTextOffset = Vector(0, 0, 25)

local function RefreshLists(curTime)
    if curTime + 3 < nextListRefresh then nextListRefresh = 0 end
    if curTime < nextListRefresh then return end
    nextListRefresh = curTime + listRefreshRate

    probeList = entsFindByClass("gstorms_probe")
    thermoList = entsFindByClass("gstorms_thermometer")
    seismoList = entsFindByClass("gstorms_seismograph*")
end

hook.Add("PostDrawEffects", "GSProbeAndThermometerDrawText", function()

    local ply = LocalPlayer()
    if !ply:IsValid() then return end

    local curTime = CurTime()
    RefreshLists(curTime)

    if #probeList == 0 and #thermoList == 0 and #seismoList == 0 then return end

    local plyPos = ply:GetPos()

    local eyePos = EyePos()
    local eyeAng = EyeAngles()

    local textAng = Angle(eyeAng.p, eyeAng.y, eyeAng.r)
    textAng:RotateAroundAxis(textAng:Right(), 90)
    textAng:RotateAroundAxis(textAng:Up(), -90)

    local useF = GetConVar("gstorms_general_fahrenheit"):GetBool()

    camStart3D(eyePos, eyeAng)

        for i = 1, #probeList do

            local ent = probeList[i]
            if !ent:IsValid() or ent.IsWireProbe then continue end

            local entPos = ent:GetPos()
            if entPos:DistToSqr(plyPos) > maxRenderDistanceSqr then continue end

            local wind = mathFloor(ent:GetNW2Float("WindspeedExperienced"))
            local windMax = mathFloor(ent:GetNW2Float("WindspeedExperiencedMax"))
            local gustMax = mathFloor(ent:GetNW2Float("WindspeedExperiencedGust3SMax"))

            local pos = entPos + probeTextOffset

            camStart3D2D(pos, textAng, 0.25)
                drawSimpleTextOutlined("WIND: " .. wind .. " MPH", "GSProbeFontSmall", 0, 0, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colBlack240)
                drawSimpleTextOutlined("WIND PEAK: " .. windMax .. " MPH", "GSProbeFontSmall", 0, 32, colGray215, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colBlack220)
                drawSimpleTextOutlined("3S GUST PEAK: " .. gustMax .. " MPH", "GSProbeFontSmall", 0, 64, colGray200, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colBlack220)
            camEnd3D2D()

        end

        for i = 1, #thermoList do

            local ent = thermoList[i]
            if !ent:IsValid() or ent.IsWireThermometer then continue end

            local entPos = ent:GetPos()
            if entPos:DistToSqr(plyPos) > maxRenderDistanceSqr then continue end

            local temp = mathFloor(ent:GetNW2Float("TemperatureExperienced"))
            local tempMax = mathFloor(ent:GetNW2Float("TemperatureExperiencedMax"))

            local t = temp
            local tMax = tempMax
            local unit = "C"
            
            if useF then
                t = (t * 9/5) + 32
                tMax = (tMax * 9/5) + 32
                unit = "F"
            end

            local pos = entPos + thermoTextOffset

            camStart3D2D(pos, textAng, 0.25)
                drawSimpleTextOutlined("TEMP: " .. mathRound(t, 1) .. " " .. unit, "GSThermometerFontSmall", 0, 0, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colBlack240)
                drawSimpleTextOutlined("TEMP PEAK: " .. mathRound(tMax, 1) .. " " .. unit, "GSThermometerFontSmall", 0, 32, colGray215, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colBlack220)
            camEnd3D2D()

        end

        for i = 1, #seismoList do

            local ent = seismoList[i]
            if !ent:IsValid() or ent.IsWireSeismograph then continue end

            local entPos = ent:GetPos()
            if entPos:DistToSqr(plyPos) > maxRenderDistanceSqr then continue end

            local mag = mathRound(ent:GetNW2Float("MagnitudeExperienced"), 1)
            local magMax = mathRound(ent:GetNW2Float("MagnitudeExperiencedMax"), 1)
            local pos = entPos + probeTextOffset

            camStart3D2D(pos, textAng, 0.25)
                drawSimpleTextOutlined("MAGNITUDE: " .. mag, "GSSeismomgraphFontSmall", 0, 0, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colBlack240)
                drawSimpleTextOutlined("MAGNITUDE PEAK: " .. magMax, "GSSeismomgraphFontSmall", 0, 32, colGray215, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colBlack220)
            camEnd3D2D()

        end

    camEnd3D()

end)

hook.Add("HUDPaint", "GSProbeAndThermometerHUD", function()

    local ply = LocalPlayer()
    if !ply:IsValid() then return end

    local ent = ply:GetEyeTrace().Entity
    if !ent:IsValid() then return end

    local plyPos = ply:GetPos()
    if ent:GetPos():Distance2D(plyPos) > maxInteractDistance then return end

    if ent.IsProbe then
        drawSimpleText('Press "USE" To Deploy Probe', "Trebuchet24", ScrW() / 2, ScrH() - 80, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        drawSimpleText('Press "F" To Reset Max Winds', "Trebuchet24", ScrW() / 2, ScrH() * 0.96, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if ent.IsThermometer then
        drawSimpleText('Press "USE" To Reset Max Temp', "Trebuchet24", ScrW() / 2, ScrH() * 0.96, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if ent.IsSeismograph then
        drawSimpleText('Press "USE" To Reset Max Magnitude', "Trebuchet24", ScrW() / 2, ScrH() * 0.96, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

end)

hook.Add("Think", "ProbeResetKeyThink", function()

    local ply = LocalPlayer()

    if !ply:IsValid() or !inputIsKeyDown(KEY_F) or CurTime() - lastFPress < 0.25 then return end

    lastFPress = CurTime()

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity

    if !ent:IsValid() or !ent.IsProbe or ent:GetPos():Distance2D(ply:GetPos()) > maxInteractDistance then return end

    netStart("gs_probe_reset")
    netWriteEntity(ent)
    netSendToServer()

end)