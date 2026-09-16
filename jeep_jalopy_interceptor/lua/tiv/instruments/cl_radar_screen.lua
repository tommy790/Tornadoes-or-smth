-- ============================================================================
-- TIV TACTICAL DOPPLER RADAR & PATH PREDICTION SCREEN - CLIENT
-- Renders real-time tornado tracking, vortex bounds, and forward path prediction
-- directly onto in-cabin Wiremod screens / dashboard monitor props.
-- ============================================================================

TIV = TIV or {}
TIV.Instruments = TIV.Instruments or {}
TIV.Instruments.RadarData = TIV.Instruments.RadarData or { active = false }

-- ============================================================================
-- NETWORKING: RECEIVE TELEMETRY FROM SERVER
-- ============================================================================
net.Receive("TIV_RadarPathData", function()
    local veh = net.ReadEntity()
    local hasTornado = net.ReadBool()

    if not IsValid(veh) then return end

    if hasTornado then
        local pos         = net.ReadVector()
        local heading     = net.ReadVector()
        local speedMPH    = net.ReadFloat()
        local coreRadius  = net.ReadFloat()
        local outerRadius = net.ReadFloat()
        local dist        = net.ReadFloat()
        local bearing     = net.ReadFloat()
        local eta         = net.ReadFloat()
        local impactType  = net.ReadString()
        local wpCount     = net.ReadUInt(4)

        local waypoints = {}
        for i = 1, wpCount do
            table.insert(waypoints, net.ReadVector())
        end

        TIV.Instruments.RadarData = {
            active      = true,
            veh         = veh,
            pos         = pos,
            heading     = heading,
            speedMPH    = speedMPH,
            coreRadius  = coreRadius,
            outerRadius = outerRadius,
            dist        = dist,
            bearing     = bearing,
            eta         = eta,
            impactType  = impactType,
            waypoints   = waypoints,
            receivedAt  = CurTime(),
        }
    else
        TIV.Instruments.RadarData = {
            active     = false,
            veh        = veh,
            receivedAt = CurTime(),
        }
    end
end)

-- ============================================================================
-- 3D2D SCREEN RENDERING ENGINE
-- ============================================================================
local function DrawRadarScreen(screenEnt, veh, rData)
    local cx, cy = 256, 260
    local radarRadius = 180
    local now = CurTime()

    -- CRT Glass background
    surface.SetDrawColor(6, 12, 18, 255)
    surface.DrawRect(0, 0, 512, 512)

    -- Subtle CRT scanlines
    surface.SetDrawColor(0, 25, 20, 35)
    for y = 0, 512, 4 do
        surface.DrawLine(0, y, 512, y)
    end

    -- Tactical frame borders
    surface.SetDrawColor(0, 200, 255, 180)
    surface.DrawOutlinedRect(6, 6, 500, 500)
    surface.DrawOutlinedRect(8, 8, 496, 496)

    -- Header bar
    surface.SetDrawColor(0, 45, 60, 220)
    surface.DrawRect(10, 10, 492, 28)

    draw.SimpleText("TIV TACTICAL DOPPLER RADAR", "Trebuchet18", 18, 15, Color(0, 240, 255, 255), TEXT_ALIGN_LEFT)
    draw.SimpleText("GSTORMS // XT3 VECTOR MAP", "Trebuchet18", 494, 15, Color(160, 200, 220, 220), TEXT_ALIGN_RIGHT)

    -- Concentric Range Rings (Track-Up view)
    local rings = {
        { r = 60,  lbl = "500m" },
        { r = 120, lbl = "1km" },
        { r = 180, lbl = "2km" },
    }

    surface.SetDrawColor(0, 140, 110, 80)
    for _, ring in ipairs(rings) do
        local r = ring.r
        local segments = 36
        for i = 0, segments - 1 do
            local a1 = math.rad((i / segments) * 360)
            local a2 = math.rad(((i + 1) / segments) * 360)
            surface.DrawLine(
                cx + math.cos(a1) * r, cy + math.sin(a1) * r,
                cx + math.cos(a2) * r, cy + math.sin(a2) * r
            )
        end
        draw.SimpleText(ring.lbl, "DefaultFixed", cx + r - 12, cy + 2, Color(0, 180, 130, 140), TEXT_ALIGN_LEFT)
    end

    -- Crosshair axis lines
    surface.SetDrawColor(0, 180, 130, 50)
    surface.DrawLine(cx - radarRadius, cy, cx + radarRadius, cy)
    surface.DrawLine(cx, cy - radarRadius, cx, cy + radarRadius)

    -- Rotating radar sweep phosphor beam
    local sweepAng = (now * 120) % 360
    local sRad = math.rad(sweepAng)
    surface.SetDrawColor(0, 255, 170, 200)
    surface.DrawLine(cx, cy, cx + math.cos(sRad) * radarRadius, cy + math.sin(sRad) * radarRadius)

    -- Vehicle marker at center: Tactical Chevron (Facing UP = Forward)
    local vehColor = Color(50, 255, 120, 255)
    surface.SetDrawColor(vehColor.r, vehColor.g, vehColor.b, vehColor.a)
    surface.DrawLine(cx, cy - 10, cx - 7, cy + 8)
    surface.DrawLine(cx, cy - 10, cx + 7, cy + 8)
    surface.DrawLine(cx - 7, cy + 8, cx, cy + 4)
    surface.DrawLine(cx + 7, cy + 8, cx, cy + 4)

    -- Storm rendering if active
    if rData and rData.active then
        local vehPos = IsValid(veh) and veh:GetPos() or EyePos()
        local vehAng = IsValid(veh) and veh:GetAngles() or Angle(0, 0, 0)
        local tPos = rData.pos

        -- Track-Up transformation: align screen UP with vehicle forward
        local radOffset = math.rad(-vehAng.y - 90)
        local cosA = math.cos(radOffset)
        local sinA = math.sin(radOffset)

        local rel = tPos - vehPos
        local rx = rel.x * cosA - rel.y * sinA
        local ry = rel.x * sinA + rel.y * cosA

        -- Auto-scaling radar range
        local maxRangeUnits = math.max(rData.dist * 1.35, 3000)
        local scalePx = radarRadius / maxRangeUnits

        local scrX = cx + rx * scalePx
        local scrY = cy + ry * scalePx

        -- Draw PREDICTED PATH vector and waypoints
        local prevX, prevY = scrX, scrY
        local waypoints = rData.waypoints or {}

        for idx, wp in ipairs(waypoints) do
            local wRel = wp - vehPos
            local wx = wRel.x * cosA - wRel.y * sinA
            local wy = wRel.x * sinA + wRel.y * cosA
            local currX = cx + wx * scalePx
            local currY = cy + wy * scalePx

            -- Draw trajectory line
            local pulseAlpha = 180 + math.sin(now * 8 + idx) * 50
            surface.SetDrawColor(0, 235, 255, pulseAlpha)
            surface.DrawLine(prevX, prevY, currX, currY)

            -- Waypoint node diamond
            surface.DrawRect(currX - 3, currY - 3, 6, 6)

            -- Time label for key waypoints
            local tSec = idx * 10
            draw.SimpleText("+" .. tSec .. "s", "DefaultFixed", currX + 6, currY - 5, Color(0, 230, 255, 220), TEXT_ALIGN_LEFT)

            prevX, prevY = currX, currY
        end

        -- Outer Vortex Windfield Circle
        local outerPx = math.Clamp(rData.outerRadius * scalePx, 15, radarRadius * 1.5)
        surface.SetDrawColor(255, 190, 0, 75)
        local segs = 32
        for i = 0, segs - 1 do
            local a1 = math.rad((i / segs) * 360)
            local a2 = math.rad(((i + 1) / segs) * 360)
            surface.DrawLine(
                scrX + math.cos(a1) * outerPx, scrY + math.sin(a1) * outerPx,
                scrX + math.cos(a2) * outerPx, scrY + math.sin(a2) * outerPx
            )
        end

        -- Inner Core / Maximum Wind Zone
        local corePx = math.max(rData.coreRadius * scalePx, 8)
        local corePulse = math.sin(now * 10) * 0.2 + 0.8
        surface.SetDrawColor(255, 45, 45, 120 * corePulse)
        for i = 0, segs - 1 do
            local a1 = math.rad((i / segs) * 360)
            local a2 = math.rad(((i + 1) / segs) * 360)
            surface.DrawLine(
                scrX + math.cos(a1) * corePx, scrY + math.sin(a1) * corePx,
                scrX + math.cos(a2) * corePx, scrY + math.sin(a2) * corePx
            )
        end

        -- Vortex Center Icon
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawRect(scrX - 3, scrY - 3, 6, 6)

        -- Telemetry data box (Top Left)
        surface.SetDrawColor(0, 20, 25, 200)
        surface.DrawRect(14, 46, 170, 78)
        surface.SetDrawColor(0, 180, 220, 160)
        surface.DrawOutlinedRect(14, 46, 170, 78)

        local distM = math.Round(rData.dist * 0.01905)
        draw.SimpleText(string.format("DIST:  %d m", distM), "Trebuchet18", 22, 52, Color(0, 240, 255, 255))
        draw.SimpleText(string.format("SPEED: %.0f MPH", rData.speedMPH), "Trebuchet18", 22, 70, Color(255, 220, 60, 255))
        draw.SimpleText(string.format("BEAR:  %.0f DEG", rData.bearing), "Trebuchet18", 22, 88, Color(200, 220, 240, 255))
        draw.SimpleText(string.format("CORE:  %d m", math.Round(rData.coreRadius * 0.01905)), "Trebuchet18", 22, 106, Color(255, 100, 100, 255))

        -- Threat Assessment Banner (Bottom)
        local bannerY = 458
        local impact = rData.impactType or "receding"

        if impact == "core" then
            local flash = (math.floor(now * 4) % 2 == 0)
            local bCol = flash and Color(220, 30, 30, 230) or Color(120, 15, 15, 230)
            surface.SetDrawColor(bCol.r, bCol.g, bCol.b, bCol.a)
            surface.DrawRect(12, bannerY, 488, 38)
            draw.SimpleText(string.format("WARNING: DIRECT CORE IMPACT // ETA: %.0fs", rData.eta), "Trebuchet24", 256, bannerY + 7, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
        elseif impact == "side" then
            surface.SetDrawColor(220, 140, 0, 220)
            surface.DrawRect(12, bannerY, 488, 38)
            draw.SimpleText(string.format("CAUTION: SIDE VORTEX SWEEP // ETA: %.0fs", rData.eta), "Trebuchet24", 256, bannerY + 7, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER)
        elseif impact == "miss" then
            surface.SetDrawColor(0, 140, 80, 220)
            surface.DrawRect(12, bannerY, 488, 38)
            draw.SimpleText(string.format("PASSING FLANK // CLOSEST DIST: %d m", math.Round(rData.dist * 0.01905)), "Trebuchet24", 256, bannerY + 7, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
        else
            surface.SetDrawColor(30, 70, 120, 220)
            surface.DrawRect(12, bannerY, 488, 38)
            draw.SimpleText("VORTEX RECEDING // MOVING AWAY", "Trebuchet24", 256, bannerY + 7, Color(220, 240, 255, 255), TEXT_ALIGN_CENTER)
        end
    else
        -- Standby searching mode
        surface.SetDrawColor(0, 30, 40, 200)
        surface.DrawRect(12, 458, 488, 38)
        draw.SimpleText("DOPPLER RADAR ONLINE // NO VORTEX DETECTED", "Trebuchet24", 256, 465, Color(0, 230, 255, 200), TEXT_ALIGN_CENTER)

        draw.SimpleText("SCANNING MESOCYCLONES...", "Trebuchet18", cx, cy - 25, Color(0, 180, 140, 180), TEXT_ALIGN_CENTER)
        draw.SimpleText("ATMOSPHERIC STATUS: CALM", "Trebuchet18", cx, cy + 10, Color(120, 160, 180, 160), TEXT_ALIGN_CENTER)
    end
end

-- ============================================================================
-- 3D2D RENDER HOOK ON VEHICLE SCREEN PROPS
-- ============================================================================
hook.Add("PostDrawTranslucentRenderables", "TIV_RenderRadarScreens", function(bDrawingDepth, bDrawingSkybox)
    if bDrawingSkybox then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local eyePos = EyePos()

    local screens = ents.FindByClass("prop_physics")
    for _, ent in ipairs(screens) do
        if IsValid(ent) and ent:GetNWBool("TIV_RadarScreen") then
            local distSqr = ent:GetPos():DistToSqr(eyePos)
            if distSqr <= 1000 * 1000 then
                local veh = ent:GetNWEntity("TIV_OwnerVehicle")
                local rData = TIV.Instruments.RadarData

                local mdl = string.lower(ent:GetModel() or "")
                local isWireSmall = string.find(mdl, "wiremonitorsmall", 1, true) ~= nil

                local drawOffset = isWireSmall and Vector(0.35, 0, 5.0) or Vector(6.6, 0.5, 1.0)
                local scale = isWireSmall and 0.0175 or 0.0185

                local drawPos = ent:LocalToWorld(drawOffset)
                local ang = ent:GetAngles()

                ang:RotateAroundAxis(ang:Up(), 90)
                ang:RotateAroundAxis(ang:Forward(), 90)

                cam.Start3D2D(drawPos, ang, scale)
                    -- Shift origin so (cx, cy) is centered on the monitor glass
                    surface.SetDrawColor(0, 0, 0, 255)
                    DrawRadarScreen(ent, veh, rData)
                cam.End3D2D()
            end
        end
    end
end)

print("[TIV] Tactical radar screen client loaded")
