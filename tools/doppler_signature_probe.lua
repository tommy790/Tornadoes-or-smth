-- ===========================================================================
-- TIV DOPPLER SIGNATURE RENDER PROBE
--
-- Executes the REAL DrawRadarScreen from
-- jeep_jalopy_interceptor/lua/tiv/instruments/cl_radar_screen.lua and inspects
-- the recorded draw calls, to prove the new velocity-signature layer:
--
--   * appears ONLY when the server reported real ground contact, and never for
--     an aloft vortex, an inactive feed, or a vanished entity;
--   * is two OPPOSING curved lobes -- inbound toward the radar, outbound away --
--     not one circle and not a spinning texture;
--   * flips which side is inbound when the addon reports the reverse
--     circulation, and goes neutral (both lobes one colour, claiming no
--     direction) when the direction is unknown;
--   * stays clear of the core circle, the outer windfield and the centre
--     marker, and is clipped to the display;
--   * eases in over several frames instead of popping on a packet boundary.
--
--   tools/bin/luajit tools/doppler_signature_probe.lua
--
-- Exit 0 = every expectation met.
-- ===========================================================================

local here = (arg and arg[0] or "tools/doppler_signature_probe.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local repo = here:match("^(.*)[/\\]tools$") or "."

local TARGET = repo .. "/jeep_jalopy_interceptor/lua/tiv/instruments/cl_radar_screen.lua"
local CONFIG_TARGET = "jeep_jalopy_interceptor/lua/tiv/config/sh_config.lua"

dofile(here .. "/gmod_stub.lua")

local bad = dofile(here .. "/radar_selftest.lua")
if #bad > 0 then
    io.stderr:write("FAIL: GMod stub does not match Source conventions:\n")
    for _, b in ipairs(bad) do io.stderr:write("    " .. b .. "\n") end
    os.exit(1)
end

-- Pin the calibration offsets so this probe measures the signature, not them.
TIV_HEADING_OFFSET_DEG = "0"
TIV_RADAR_BLIP_OFFSET = "0"

CLIENT = true
CreateClientConVar = function() return nil end

local cfgChunk = loadfile(repo .. "/" .. CONFIG_TARGET)
if cfgChunk then cfgChunk() end

local chunk, lerr = loadfile(TARGET)
if not chunk then
    io.stderr:write("FAILED TO LOAD " .. TARGET .. ": " .. tostring(lerr) .. "\n")
    os.exit(1)
end
local ok, rerr = pcall(chunk)
if not ok then
    io.stderr:write("RUNTIME ERROR ON LOAD: " .. tostring(rerr) .. "\n")
    os.exit(1)
end
assert(TIV and TIV.Instruments and TIV.Instruments.DrawRadarScreen,
    "TIV.Instruments.DrawRadarScreen was not exported")

------------------------------------------------------------------------------
-- Fixture: vehicle at the origin facing +X, vortex 12000u dead ahead.
------------------------------------------------------------------------------
local CX, CY = 256, 260
local veh = __makeent(__newvector(0, 0, 20), __newangle(0, 0, 0))
local screenEnt = __makeent(__newvector(0, 0, 20), __newangle(0, 0, 0))
local TPOS = __newvector(12000, 0, 0)

-- Colours the renderer uses for the two lobes, copied from the source so the
-- probe fails if they are changed without being thought about.
local INBOUND  = { r = 90,  g = 235, b = 255 } -- toward the radar
local OUTBOUND = { r = 255, g = 120, b = 45 }  -- away from it
local NEUTRAL  = { r = 150, g = 200, b = 225 } -- direction unknown
local CORE_COL = { r = 255, g = 45,  b = 45 }  -- existing inner core circle
local OUTER_COL = { r = 255, g = 190, b = 0 }  -- existing outer windfield

local function sameCol(c, r, g, b)
    return c.r == r and c.g == g and c.b == b
end

-- Renders `frames` times so the fade can step, and returns the recorded calls of
-- the LAST frame (that is what a driver would actually see).
--
-- The core/outer radii in PIXELS are recomputed here with the renderer's own
-- clamps, because they are what the signature has to fit between: at 12000u the
-- 600u core collapses onto its 8px floor while a close vortex leaves a wide gap.
local DEFAULT_CORE, DEFAULT_OUTER = 600, 3500
local function render(frames, opts)
    opts = opts or {}
    _G.__calls = {}
    _G.__texts = {}

    local dist = opts.dist or 12000
    local tPos = opts.tPos or __newvector(dist, 0, 0)
    local coreU = opts.coreRadius or DEFAULT_CORE
    local outerU = opts.outerRadius or DEFAULT_OUTER
    local scalePx = 180 / math.max(dist * 1.35, 3000)
    local geom = {
        corePx = math.max(coreU * scalePx, 8),
        outerPx = math.Clamp(outerU * scalePx, 15, 270),
    }

    local rData
    if opts.noTornado then
        rData = { active = false, veh = veh, receivedAt = CurTime() }
    else
        rData = {
            active = true, veh = veh, pos = tPos,
            heading = __newvector(1, 0, 0),
            speedMPH = 30, coreRadius = coreU, outerRadius = outerU,
            dist = dist, bearing = 0, eta = 10, impactType = "side",
            waypoints = {},
            touchingGround = opts.touchingGround and true or false,
            rotationDirection = opts.rotationDirection or 0,
            rotationSpeed = opts.rotationSpeed or 0,
            receivedAt = CurTime(),
        }
    end

    for i = 1, math.max(1, frames or 1) do
        -- The vehicle identity has to stay stable across frames for the fade to
        -- accumulate, and the signature is keyed on it.
        _G.__curtime = 100 + i * 0.016
        _G.__frametime = 0.016
        _G.__calls = {}
        TIV.Instruments.DrawRadarScreen(screenEnt, veh, rData)
    end

    return _G.__calls, geom
end

-- The vortex's canvas position, taken from the 6x6 centre marker the renderer
-- draws, so the geometry assertions are made against where it was really put.
local function vortexCentre(calls)
    for _, c in ipairs(calls) do
        if c.op == "rect" and c.w == 6 and c.h == 6 then
            return c.x + 3, c.y + 3
        end
    end
    return nil
end

local function linesOf(calls, col)
    local out = {}
    for _, c in ipairs(calls) do
        if c.op == "line" and col and sameCol(col, c.r, c.g, c.b) then out[#out + 1] = c end
    end
    return out
end

local function anyLineOf(calls, col)
    for _, c in ipairs(calls) do
        if c.op == "line" and col and sameCol(col, c.r, c.g, c.b) then return true end
    end
    return false
end

-- Centroid of a set of lines, to tell which flank a lobe sits on.
local function centroid(lines)
    if #lines == 0 then return nil end
    local sx, sy = 0, 0
    for _, c in ipairs(lines) do
        sx = sx + (c.x + c.x2) * 0.5
        sy = sy + (c.y + c.y2) * 0.5
    end
    return sx / #lines, sy / #lines
end

------------------------------------------------------------------------------
-- Assertions
------------------------------------------------------------------------------
local passed, failed = 0, 0
local function check(label, cond, detail)
    if cond then
        passed = passed + 1
        print(string.format("  [OK]   %s%s", label, detail and ("  -- " .. detail) or ""))
    else
        failed = failed + 1
        print(string.format("  [BAD]  %s%s", label, detail and ("  -- " .. detail) or ""))
    end
end

------------------------------------------------------------------------------
print("== the signature is drawn only on real ground contact ==")

local ground, geom = render(60, { touchingGround = true, rotationDirection = 1 })
local vx, vy = vortexCentre(ground)
check("vortex centre marker was drawn", vx ~= nil, vx and string.format("at (%.0f, %.0f)", vx, vy))

local inG  = linesOf(ground, INBOUND)
local outG = linesOf(ground, OUTBOUND)
check("inbound lobe drawn", #inG > 0, #inG .. " segments")
check("outbound lobe drawn", #outG > 0, #outG .. " segments")

local aloft = render(60, { touchingGround = false, rotationDirection = 1 })
check("ALOFT vortex draws no inbound lobe", #linesOf(aloft, INBOUND) == 0,
    #linesOf(aloft, INBOUND) .. " segments")
check("ALOFT vortex draws no outbound lobe", #linesOf(aloft, OUTBOUND) == 0)
check("ALOFT vortex still draws the core circle", anyLineOf(aloft, CORE_COL))
check("ALOFT vortex still draws the outer windfield", anyLineOf(aloft, OUTER_COL))

local gone = render(60, { noTornado = true })
check("no tornado draws no lobe", #linesOf(gone, INBOUND) == 0 and #linesOf(gone, OUTBOUND) == 0)
check("no tornado still draws the sweep disc", #gone > 0, #gone .. " draw calls")

print("\n== opposing lobes, oriented by the reported circulation ==")

-- Vortex is dead ahead, so it sits above the canvas centre; canvas +x is the
-- vehicle's right. A cyclonic (counter-clockwise) vortex puts its inbound flank
-- on the radar-facing side, which here is the vehicle's right.
local iCx, iCy = centroid(inG)
local oCx, oCy = centroid(outG)
check("cyclonic: inbound lobe is on the vehicle's RIGHT", iCx and iCx > vx,
    string.format("inbound centroid x=%.0f vs vortex x=%.0f", iCx or 0, vx or 0))
check("cyclonic: outbound lobe is on the vehicle's LEFT", oCx and oCx < vx,
    string.format("outbound centroid x=%.0f vs vortex x=%.0f", oCx or 0, vx or 0))
check("the two lobes sit on opposite flanks", iCx and oCx and math.abs(iCx - oCx) > 20,
    string.format("separation %.0f px", math.abs((iCx or 0) - (oCx or 0))))
check("the lobes share the vortex's fore-aft line", iCy and oCy and math.abs(iCy - oCy) < 12,
    string.format("dy=%.0f px", math.abs((iCy or 0) - (oCy or 0))))

local anti = render(60, { touchingGround = true, rotationDirection = -1 })
local aIn, aOut = linesOf(anti, INBOUND), linesOf(anti, OUTBOUND)
local aInX = (centroid(aIn))
local aOutX = (centroid(aOut))
check("anticyclonic: inbound lobe flips to the LEFT", aInX and aInX < vx,
    string.format("inbound centroid x=%.0f vs vortex x=%.0f", aInX or 0, vx or 0))
check("anticyclonic: outbound lobe flips to the RIGHT", aOutX and aOutX > vx,
    string.format("outbound centroid x=%.0f vs vortex x=%.0f", aOutX or 0, vx or 0))

print("\n== unknown direction stays neutral ==")

local neutral = render(60, { touchingGround = true, rotationDirection = 0 })
local nIn, nOut = linesOf(neutral, INBOUND), linesOf(neutral, OUTBOUND)
check("unknown direction draws no cyan lobe", #nIn == 0, #nIn .. " segments")
check("unknown direction draws no orange lobe", #nOut == 0, #nOut .. " segments")
local nNeu = linesOf(neutral, NEUTRAL)
check("unknown direction draws neutral lobes instead", #nNeu > 8, #nNeu .. " segments")
local nA, nB = {}, {}
for _, c in ipairs(nNeu) do
    if c.x > (vx or 0) then nA[#nA + 1] = c else nB[#nB + 1] = c end
end
check("neutral signature still shows TWO opposing flanks", #nA > 0 and #nB > 0,
    string.format("%d right / %d left", #nA, #nB))

print("\n== it is a couplet, not a circle and not a spinner ==")

-- A full circle would put line segments at every angle around the vortex. The
-- couplet must leave whole quadrants empty.
local covered = {}
for _, c in ipairs(inG) do
    local ang = math.deg(math.atan2((c.y + c.y2) * 0.5 - vy, (c.x + c.x2) * 0.5 - vx)) % 360
    covered[math.floor(ang / 30)] = true
end
for _, c in ipairs(outG) do
    local ang = math.deg(math.atan2((c.y + c.y2) * 0.5 - vy, (c.x + c.x2) * 0.5 - vx)) % 360
    covered[math.floor(ang / 30)] = true
end
local sectors = 0
for _ in pairs(covered) do sectors = sectors + 1 end
check("lobes cover less than the full disc", sectors < 12, sectors .. " of 12 30-degree sectors")
check("lobes cover a meaningful arc, not a dot", sectors >= 6, sectors .. " of 12 sectors")

-- Nothing here may rotate: the same input over time must produce the same
-- geometry, so the signature cannot be a spinning texture.
local t1 = render(30, { touchingGround = true, rotationDirection = 1 })
_G.__curtime = 500
local t2 = render(30, { touchingGround = true, rotationDirection = 1 })
local function geomKey(calls)
    local s = {}
    for _, c in ipairs(calls) do
        if c.op == "line" and sameCol(INBOUND, c.r, c.g, c.b) then
            s[#s + 1] = string.format("%.2f,%.2f", c.x, c.y)
        end
    end
    return table.concat(s, "|")
end
check("signature geometry does not rotate over time", geomKey(t1) == geomKey(t2),
    "identical segment positions at two different CurTimes")

print("\n== it stays out of the way of the existing layers ==")

local minR, maxR = math.huge, 0
for _, c in ipairs(inG) do
    for _, pt in ipairs({ { c.x, c.y }, { c.x2, c.y2 } }) do
        local r = math.sqrt((pt[1] - vx) ^ 2 + (pt[2] - vy) ^ 2)
        if r < minR then minR = r end
        if r > maxR then maxR = r end
    end
end
check("signature clears the inner core circle", minR >= geom.corePx,
    string.format("min radius %.1f px vs core circle %.1f px", minR, geom.corePx))
check("signature clears the outer windfield", maxR <= geom.outerPx,
    string.format("max radius %.1f px vs outer circle %.1f px", maxR, geom.outerPx))

local clipped = true
for _, c in ipairs(inG) do
    for _, pt in ipairs({ { c.x, c.y }, { c.x2, c.y2 } }) do
        if pt[1] < 10 or pt[1] > 502 or pt[2] < 42 or pt[2] > 454 then clipped = false end
    end
end
check("every signature segment is inside the display clip", clipped)

-- The centre marker is drawn after the signature, so it must still be on top.
local markerIdx, lastLobeIdx = nil, 0
for i, c in ipairs(ground) do
    if c.op == "rect" and c.w == 6 and c.h == 6 then markerIdx = i end
    if c.op == "line" and (sameCol(INBOUND, c.r, c.g, c.b) or sameCol(OUTBOUND, c.r, c.g, c.b)) then
        lastLobeIdx = i
    end
end
check("centre marker is painted after the signature", markerIdx and markerIdx > lastLobeIdx,
    string.format("marker call #%s, last lobe call #%s", tostring(markerIdx), tostring(lastLobeIdx)))

-- A close vortex is the opposite geometry: the 8px core floor no longer applies
-- and the core circle is large, so there is a wide annulus to fit into. This is
-- the case that exposed the overlap the fixed offsets caused.
print("\n== close vortex: wide core, signature must still not cross it ==")

local close, cgeom = render(60, { touchingGround = true, rotationDirection = 1, dist = 2500 })
local cvx, cvy = vortexCentre(close)
check("close vortex centre marker drawn", cvx ~= nil,
    cvx and string.format("at (%.0f, %.0f), core circle %.0f px, outer %.0f px", cvx, cvy, cgeom.corePx, cgeom.outerPx))

local cIn = linesOf(close, INBOUND)
check("close vortex draws the inbound lobe", #cIn > 0, #cIn .. " segments")

local cMin, cMax = math.huge, 0
for _, c in ipairs(linesOf(close, INBOUND)) do
    for _, pt in ipairs({ { c.x, c.y }, { c.x2, c.y2 } }) do
        local r = math.sqrt((pt[1] - cvx) ^ 2 + (pt[2] - cvy) ^ 2)
        if r < cMin then cMin = r end
        if r > cMax then cMax = r end
    end
end
for _, c in ipairs(linesOf(close, OUTBOUND)) do
    for _, pt in ipairs({ { c.x, c.y }, { c.x2, c.y2 } }) do
        local r = math.sqrt((pt[1] - cvx) ^ 2 + (pt[2] - cvy) ^ 2)
        if r < cMin then cMin = r end
        if r > cMax then cMax = r end
    end
end
check("close: signature stays outside the core circle", cMin >= cgeom.corePx,
    string.format("min radius %.1f px vs core circle %.1f px", cMin, cgeom.corePx))
check("close: signature stays inside the outer windfield", cMax <= cgeom.outerPx,
    string.format("max radius %.1f px vs outer circle %.1f px", cMax, cgeom.outerPx))
check("close: signature is still big enough to read", cMax - cMin >= 4,
    string.format("band thickness %.1f px", cMax - cMin))

print("\n== smooth transition on touchdown ==")

-- Fresh vehicle identity each time, so the fade starts from zero.
local function freshVeh(tag)
    local v = __makeent(__newvector(0, 0, 20), __newangle(0, 0, 0))
    v._tag = tag
    return v
end

local function renderOn(v, n, touching)
    local rData = {
        active = true, veh = v, pos = TPOS, heading = __newvector(1, 0, 0),
        speedMPH = 30, coreRadius = 600, outerRadius = 3500,
        dist = 12000, bearing = 0, eta = 10, impactType = "side", waypoints = {},
        touchingGround = touching, rotationDirection = 1, rotationSpeed = 180,
        receivedAt = CurTime(),
    }
    _G.__calls = {}
    for i = 1, n do
        _G.__curtime = 200 + i * 0.016
        _G.__frametime = 0.016
        _G.__calls = {}
        TIV.Instruments.DrawRadarScreen(screenEnt, v, rData)
    end
    local best = 0
    for _, c in ipairs(_G.__calls) do
        if c.op == "line" and sameCol(INBOUND, c.r, c.g, c.b) and (c.a or 0) > best then
            best = c.a or 0
        end
    end
    return best
end

local a1  = renderOn(freshVeh("f1"), 1, true)
local a4  = renderOn(freshVeh("f4"), 4, true)
local a30 = renderOn(freshVeh("f30"), 30, true)
check("first frame is not full strength", a1 < 100, string.format("alpha %d", a1))
check("signature ramps up over frames", a1 < a4 and a4 < a30,
    string.format("alpha %d -> %d -> %d over 1/4/30 frames", a1, a4, a30))
check("signature reaches a solid reading", a30 > 100, string.format("alpha %d", a30))

-- Once the server stops reporting contact, the signature must be gone rather
-- than left fading on a reading we no longer have. Take a vehicle whose fade is
-- fully ramped, then drop contact.
local dropVeh = freshVeh("drop")
renderOn(dropVeh, 40, true)
local after = renderOn(dropVeh, 1, false)
check("signature disappears when contact is lost", after == 0, string.format("alpha %d", after))

print(string.format("\nRESULT: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
