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

-- Boundary coordinates of the central radar display area inside the 512x512 canvas
local CLIP_MIN_X = 10
local CLIP_MAX_X = 502
local CLIP_MIN_Y = 42
local CLIP_MAX_Y = 454

-- Cohen-Sutherland 2D line clipping algorithm
local function ComputeOutCode(x, y, xmin, ymin, xmax, ymax)
    local code = 0
    if x < xmin then
        code = bit.bor(code, 1)
    elseif x > xmax then
        code = bit.bor(code, 2)
    end
    if y < ymin then
        code = bit.bor(code, 8)
    elseif y > ymax then
        code = bit.bor(code, 4)
    end
    return code
end

local function ClipLine(x0, y0, x1, y1, xmin, ymin, xmax, ymax)
    xmin = xmin or CLIP_MIN_X
    ymin = ymin or CLIP_MIN_Y
    xmax = xmax or CLIP_MAX_X
    ymax = ymax or CLIP_MAX_Y

    local outcode0 = ComputeOutCode(x0, y0, xmin, ymin, xmax, ymax)
    local outcode1 = ComputeOutCode(x1, y1, xmin, ymin, xmax, ymax)

    while true do
        if bit.bor(outcode0, outcode1) == 0 then
            return x0, y0, x1, y1
        end
        if bit.band(outcode0, outcode1) ~= 0 then
            return nil
        end

        local outcodeOut = (outcode0 ~= 0) and outcode0 or outcode1
        local x, y

        if bit.band(outcodeOut, 8) ~= 0 then -- Top
            x = x0 + (x1 - x0) * (ymin - y0) / (y1 - y0)
            y = ymin
        elseif bit.band(outcodeOut, 4) ~= 0 then -- Bottom
            x = x0 + (x1 - x0) * (ymax - y0) / (y1 - y0)
            y = ymax
        elseif bit.band(outcodeOut, 2) ~= 0 then -- Right
            y = y0 + (y1 - y0) * (xmax - x0) / (x1 - x0)
            x = xmax
        elseif bit.band(outcodeOut, 1) ~= 0 then -- Left
            y = y0 + (y1 - y0) * (xmin - x0) / (x1 - x0)
            x = xmin
        end

        if outcodeOut == outcode0 then
            x0, y0 = x, y
            outcode0 = ComputeOutCode(x0, y0, xmin, ymin, xmax, ymax)
        else
            x1, y1 = x, y
            outcode1 = ComputeOutCode(x1, y1, xmin, ymin, xmax, ymax)
        end
    end
end

local function DrawClippedLine(x0, y0, x1, y1, r, g, b, a)
    local c0x, c0y, c1x, c1y = ClipLine(x0, y0, x1, y1, CLIP_MIN_X, CLIP_MIN_Y, CLIP_MAX_X, CLIP_MAX_Y)
    if c0x then
        surface.SetDrawColor(r, g, b, a)
        surface.DrawLine(c0x, c0y, c1x, c1y)
    end
end

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

        -- Draw PREDICTED PATH vector and waypoints (strictly clipped to display area)
        local prevX, prevY = scrX, scrY
        local waypoints = rData.waypoints or {}

        for idx, wp in ipairs(waypoints) do
            local wRel = wp - vehPos
            local wx = wRel.x * cosA - wRel.y * sinA
            local wy = wRel.x * sinA + wRel.y * cosA
            local currX = cx + wx * scalePx
            local currY = cy + wy * scalePx

            -- Draw trajectory line clipped strictly so it never shoots off into the world
            local pulseAlpha = 180 + math.sin(now * 8 + idx) * 50
            DrawClippedLine(prevX, prevY, currX, currY, 0, 235, 255, pulseAlpha)

            -- Waypoint node diamond and label only if within bounds
            if currX >= CLIP_MIN_X + 6 and currX <= CLIP_MAX_X - 28
               and currY >= CLIP_MIN_Y + 6 and currY <= CLIP_MAX_Y - 10 then
                surface.SetDrawColor(0, 235, 255, pulseAlpha)
                surface.DrawRect(currX - 3, currY - 3, 6, 6)

                local tSec = idx * 10
                draw.SimpleText("+" .. tSec .. "s", "DefaultFixed", currX + 6, currY - 5, Color(0, 230, 255, 220), TEXT_ALIGN_LEFT)
            end

            prevX, prevY = currX, currY
        end

        -- Outer Vortex Windfield Circle (clipped per segment)
        local outerPx = math.Clamp(rData.outerRadius * scalePx, 15, radarRadius * 1.5)
        local segs = 32
        for i = 0, segs - 1 do
            local a1 = math.rad((i / segs) * 360)
            local a2 = math.rad(((i + 1) / segs) * 360)
            local p1x = scrX + math.cos(a1) * outerPx
            local p1y = scrY + math.sin(a1) * outerPx
            local p2x = scrX + math.cos(a2) * outerPx
            local p2y = scrY + math.sin(a2) * outerPx
            DrawClippedLine(p1x, p1y, p2x, p2y, 255, 190, 0, 75)
        end

        -- Inner Core / Maximum Wind Zone (clipped per segment)
        local corePx = math.max(rData.coreRadius * scalePx, 8)
        local corePulse = math.sin(now * 10) * 0.2 + 0.8
        for i = 0, segs - 1 do
            local a1 = math.rad((i / segs) * 360)
            local a2 = math.rad(((i + 1) / segs) * 360)
            local p1x = scrX + math.cos(a1) * corePx
            local p1y = scrY + math.sin(a1) * corePx
            local p2x = scrX + math.cos(a2) * corePx
            local p2y = scrY + math.sin(a2) * corePx
            DrawClippedLine(p1x, p1y, p2x, p2y, 255, 45, 45, 120 * corePulse)
        end

        -- Vortex Center Icon (on-screen icon or clamped off-screen edge pip)
        if scrX >= CLIP_MIN_X and scrX <= CLIP_MAX_X and scrY >= CLIP_MIN_Y and scrY <= CLIP_MAX_Y then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawRect(scrX - 3, scrY - 3, 6, 6)
        else
            -- Off-screen indicator chevron / pip along perimeter
            local dx = scrX - cx
            local dy = scrY - cy
            local ang = math.atan2(dy, dx)
            local pipX = math.Clamp(cx + math.cos(ang) * (radarRadius + 12), CLIP_MIN_X + 8, CLIP_MAX_X - 8)
            local pipY = math.Clamp(cy + math.sin(ang) * (radarRadius + 12), CLIP_MIN_Y + 8, CLIP_MAX_Y - 8)
            local flash = (math.floor(now * 5) % 2 == 0)
            surface.SetDrawColor(255, 60, 60, flash and 255 or 100)
            surface.DrawRect(pipX - 4, pipY - 4, 8, 8)
        end

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
-- MONITOR GEOMETRY & SCREEN BOUNDS CONFIGURATION
-- Calibrated per monitor model for exact fit on glass textures without bezel clipping.
-- ============================================================================
local MONITOR_CONFIGS = {
    ["models/kobilica/wiremonitorsmall.mdl"] = {
        offset = Vector(0.36, 0.05, 5.05),
        rot    = Angle(0, 90, 90),
        scale  = 0.0171,
        w      = 512,
        h      = 512,
    },
    ["models/props_lab/monitor01b.mdl"] = {
        offset = Vector(6.58, -1.0, 0.45),
        rot    = Angle(0, 90, 90),
        scale  = 0.0175,
        w      = 512,
        h      = 512,
    },
    ["models/props_lab/monitor01a.mdl"] = {
        offset = Vector(6.58, -1.0, 0.45),
        rot    = Angle(0, 90, 90),
        scale  = 0.0175,
        w      = 512,
        h      = 512,
    },
    ["models/props_c17/tv_monitor01.mdl"] = {
        offset = Vector(5.60, 0.6, 1.5),
        rot    = Angle(0, 90, 90),
        scale  = 0.0215,
        w      = 512,
        h      = 512,
    },
    ["models/props_lab/monitor02.mdl"] = {
        offset = Vector(9.10, 13.75, 4.9),
        rot    = Angle(0, 90, 82.5),
        scale  = 0.030,
        w      = 512,
        h      = 512,
    },
}

function TIV.Instruments.GetMonitorConfig(ent)
    if not IsValid(ent) then
        return {
            offset = Vector(0.36, 0.05, 5.05),
            rot    = Angle(0, 90, 90),
            scale  = 0.0171,
            w      = 512,
            h      = 512,
        }
    end

    local mdl = string.lower(ent:GetModel() or "")
    if MONITOR_CONFIGS[mdl] then
        return MONITOR_CONFIGS[mdl]
    end

    -- Wiremod GPU monitor table integration fallback
    if WireGPU_Monitors and WireGPU_Monitors[mdl] then
        local mon = WireGPU_Monitors[mdl]
        local w = math.abs((mon.x2 or 4.5) - (mon.x1 or -4.4))
        local h = math.abs((mon.y2 or 9.5) - (mon.y1 or 0.6))
        local s = (h > 0) and (h / 512) or 0.0171
        local offX = (mon.offset and mon.offset.x or 0.3) + 0.06
        local offY = (mon.offset and mon.offset.y or 0.0)
        local offZ = (mon.offset and mon.offset.z or 5.0)
        return {
            offset = Vector(offX, offY, offZ),
            rot    = mon.rot or Angle(0, 90, 90),
            scale  = s,
            w      = 512,
            h      = 512,
        }
    end

    -- Universal default (matches Wiremod small monitor)
    return {
        offset = Vector(0.36, 0.05, 5.05),
        rot    = Angle(0, 90, 90),
        scale  = 0.0171,
        w      = 512,
        h      = 512,
    }
end

TIV.Instruments.DrawRadarScreen = DrawRadarScreen

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

                local cfg = TIV.Instruments.GetMonitorConfig(ent)
                local pScale = ent:GetModelScale() or 1.0

                local centerPos = ent:LocalToWorld(cfg.offset * pScale)
                local screenAng = ent:LocalToWorldAngles(cfg.rot)

                -- Backface culling: skip rendering when looking from behind the screen casing
                local normal = screenAng:Up()
                if (eyePos - centerPos):Dot(normal) <= 0 then
                    continue
                end

                local scale = cfg.scale * pScale
                local halfW = (cfg.w * 0.5) * scale
                local halfH = (cfg.h * 0.5) * scale

                -- Shift origin by (-halfW, -halfH) so the 512x512 canvas is centered on the monitor glass
                local topLeftPos = centerPos - screenAng:Forward() * halfW - screenAng:Right() * halfH

                cam.Start3D2D(topLeftPos, screenAng, scale)
                    render.ClearStencil()
                    render.SetStencilEnable(true)
                    render.SetStencilTestMask(0xFF)
                    render.SetStencilWriteMask(0xFF)
                    render.SetStencilReferenceValue(1)
                    render.SetStencilCompareFunction(STENCIL_ALWAYS)
                    render.SetStencilPassOperation(STENCIL_REPLACE)
                    render.SetStencilFailOperation(STENCIL_KEEP)
                    render.SetStencilZFailOperation(STENCIL_KEEP)

                    -- Mask out the exact 512x512 physical monitor face
                    surface.SetDrawColor(0, 0, 0, 255)
                    surface.DrawRect(0, 0, 512, 512)

                    render.SetStencilCompareFunction(STENCIL_EQUAL)
                    render.SetStencilPassOperation(STENCIL_KEEP)

                    DrawRadarScreen(ent, veh, rData)

                    render.SetStencilEnable(false)
                cam.End3D2D()
            end
        end
    end
end)

print("[TIV] Tactical radar screen client loaded")
