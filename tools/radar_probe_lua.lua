-- ===========================================================================
-- TIV RADAR PROBE (pure Lua driver)
--
-- Executes the REAL jeep_jalopy_interceptor/lua/tiv/instruments/
-- cl_radar_screen.lua inside the shared GMod API stub and reports where the
-- tornado centre icon is actually painted on the 512x512 radar canvas, plus
-- the "REL BRG" readout the telemetry box prints.
--
--   tools/bin/luajit tools/radar_probe_lua.lua [vehicle_yaw_degrees]
--
-- Exit 0 = the blip, the printed relative bearing, and the sector all agree
-- for a vortex ahead / astern / left / right.
--
-- Under LuaJIT this runs on GMod's actual Lua: native `bit`, native
-- `math.atan2`, Lua 5.1 number semantics -- no shim involved.
-- ===========================================================================

local here = (arg and arg[0] or "tools/radar_probe_lua.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local repo = here:match("^(.*)[/\\]tools$") or "."

local TARGET = repo .. "/jeep_jalopy_interceptor/lua/tiv/instruments/cl_radar_screen.lua"

dofile(here .. "/gmod_stub.lua")

local bad = dofile(here .. "/radar_selftest.lua")
if #bad > 0 then
    io.stderr:write("FAIL: GMod stub does not match Source conventions:\n")
    for _, b in ipairs(bad) do io.stderr:write("    " .. b .. "\n") end
    os.exit(1)
end

-- Lets the harness pin the heading correction; unset means the shipped value.
TIV_HEADING_OFFSET_DEG = os.getenv("TIV_HEADING_OFFSET_DEG")

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

if not (TIV and TIV.Instruments and TIV.Instruments.DrawRadarScreen) then
    io.stderr:write("FAIL: TIV.Instruments.DrawRadarScreen was not exported\n")
    os.exit(1)
end

local vehYaw = tonumber(arg and arg[1] or "0") or 0

print(string.format("Executed real file : %s", TARGET))
print(string.format("Lua runtime        : %s (%s)", _VERSION, jit and jit.version or "no jit"))
print(string.format("bit library        : %s / math.atan2: %s", type(bit), type(math.atan2)))
print("GMod stub          : self-test passed (8/8 Source basis checks)")

local veh       = __makeent(__newvector(0, 0, 20), __newangle(0, vehYaw, 0))
local screenEnt = __makeent(__newvector(0, 0, 20), __newangle(0, vehYaw, 0))
-- Shipped radar screen model is models/kobilica/wiremonitorsmall.mdl, whose
-- MONITOR_CONFIGS entry (cl_radar_screen.lua) uses rot = Angle(0, 90, 90).
-- The Angle(10,-125,0) in sh_custom_config.lua is the prop's mount angle, NOT
-- cfg.rot -- using it here previously made this probe's screenAng meaningless.
local screenAng = screenEnt:LocalToWorldAngles(__newangle(0, 90, 90))

local fwd, rgt = veh:GetForward(), veh:GetRight()

print(string.format("vehicle            : pos=(0,0,20) yaw=%g", vehYaw))
print("  veh:GetForward() : " .. tostring(fwd))
print("  veh:GetRight()   : " .. tostring(rgt))
print("screenAng forward  : " .. tostring(screenAng:Forward()) .. "  <- canvas +x axis (screen RIGHT)")
print("screenAng right    : " .. tostring(screenAng:Right())   .. "  <- canvas +y axis (screen DOWN)")
print("screenAng up       : " .. tostring(screenAng:Up())      .. "  <- canvas normal (toward the driver)")
print(string.format("vehicle forward in canvas space: canvas-x=%+.3f  canvas-y=%+.3f   (canvas +y is screen DOWN)",
    fwd:Dot(screenAng:Forward()), fwd:Dot(screenAng:Right())))
print("radar centre       : (256,260), ring radius 180")
print("")

local function blipFor(tPos)
    _G.__calls = {}
    _G.__texts = {}
    local rData = {
        active = true, pos = tPos, heading = __newvector(1, 0, 0),
        speedMPH = 30, coreRadius = 600, outerRadius = 3500,
        dist = tPos:Length(), bearing = 0, eta = 10,
        impactType = "core", waypoints = {},
    }
    TIV.Instruments.DrawRadarScreen(screenEnt, veh, rData)  -- the real fn takes 3 args; a 4th was silently ignored

    local blip
    for _, c in ipairs(_G.__calls) do
        if c.op == "rect" and c.w == 6 and c.h == 6 then blip = c end
    end
    if not blip then return nil end

    local relLine
    for _, t in ipairs(_G.__texts) do
        if type(t.txt) == "string" and t.txt:find("^REL BRG:") then relLine = t.txt end
    end

    return blip.x + 3 - 256, blip.y + 3 - 260, relLine
end

local origin = __newvector(0, 0, 20)

-- ---------------------------------------------------------------------------
-- THE CONTRACT THIS PROBE ENFORCES (and the one thing it cannot verify offline)
--
-- The radar is a track-up display: the centre chevron points up and the range
-- rings are labelled "Track-Up view", so canvas UP is the vehicle's nose. That
-- half was confirmed correct in game.
--
-- Canvas RIGHT could not be derived offline: it depends on how
-- cam.Start3D2D maps canvas +x onto screenAng, and reading that off
-- MONITOR_CONFIGS rot = Angle(0,90,90) gave the OPPOSITE answer to what the
-- display actually does. In game a vortex on the vehicle's right was painted on
-- the LEFT of the radar while REL BRG correctly read 090 RIGHT, which fixes the
-- orientation empirically: increasing canvas x moves LEFT.
--
-- So DrawRadarScreen must negate relRgt on canvas +x. If a future
-- change to cfg.rot or the cam.Start3D2D call flips this, this probe must be
-- re-derived from a rendered frame, not from the config.
-- ---------------------------------------------------------------------------

-- Sign of canvas +x in display terms. Empirically canvas +x is the VIEWER'S
-- LEFT, so DrawRadarScreen must negate relRgt. Set to +1 if a rendered frame
-- ever shows the opposite.
local CANVAS_X_TO_VIEWER_RIGHT = -1

local cases = {
    { name = "tornado 2000u BEHIND", pos = origin - fwd * 2000, up = false, right = nil,  sector = "ASTERN" },
    { name = "tornado 2000u AHEAD",  pos = origin + fwd * 2000, up = true,  right = nil,  sector = "AHEAD" },
    { name = "tornado 2000u LEFT",   pos = origin - rgt * 2000, up = nil,   right = false, sector = "LEFT" },
    { name = "tornado 2000u RIGHT",  pos = origin + rgt * 2000, up = nil,   right = true,  sector = "RIGHT" },
}

local passed = 0
for _, c in ipairs(cases) do
    local dx, dy, relLine = blipFor(c.pos)
    if not dx then
        print(string.format("     %-24s -> NO on-screen blip (off-screen pip drawn instead)", c.name))
    else
        local ok2 = true
        if c.up ~= nil then
            ok2 = ok2 and ((c.up and dy < -6) or (not c.up and dy > 6))
        end
        if c.right ~= nil then
            -- A vortex on the vehicle's right must appear on the viewer's right.
            local wantViewerRight = c.right
            local dxIsViewerRight = dx * CANVAS_X_TO_VIEWER_RIGHT
            ok2 = ok2 and ((wantViewerRight and dxIsViewerRight > 6)
                        or (not wantViewerRight and dxIsViewerRight < -6))
        end

        local deg, sector
        if relLine then
            deg, sector = relLine:match("^REL BRG:%s*(%d+)%s+(%u+)")
            deg = tonumber(deg)
            ok2 = ok2 and sector == c.sector
            if deg then
                -- the printed bearing must point at the same screen region as the blip
                local vx = dx * CANVAS_X_TO_VIEWER_RIGHT
                if deg < 45 or deg >= 315 then
                    ok2 = ok2 and dy < -6          -- AHEAD  -> above centre
                elseif deg < 135 then
                    ok2 = ok2 and vx > 6           -- RIGHT  -> viewer's right
                elseif deg < 225 then
                    ok2 = ok2 and dy > 6           -- ASTERN -> below centre
                else
                    ok2 = ok2 and vx < -6          -- LEFT   -> viewer's left
                end
            end
        else
            ok2 = false
        end

        local ud = (dy < -6) and "ABOVE centre (=reads as AHEAD)"
            or (dy > 6) and "BELOW centre (=reads as BEHIND)"
            or "on centre line"
        local vx0 = dx * CANVAS_X_TO_VIEWER_RIGHT
        local lr = (vx0 > 6) and "viewer RIGHT of centre" or (vx0 < -6) and "viewer LEFT of centre" or "on centre line"

        print(string.format("[%s] %-24s dx=%+7.1f dy=%+7.1f -> %s / %s",
            ok2 and "OK " or "BAD", c.name, dx, dy, ud, lr))
        print(string.format("      %-24s readout: %s", "", relLine or "(no REL BRG readout painted!)"))
        if ok2 then passed = passed + 1 end
    end
end

print("")
print(string.format("RESULT: %d/4 blips land on the correct side of the screen", passed))
os.exit(passed == 4 and 0 or 1)
