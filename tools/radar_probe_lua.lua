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
-- Shipped default local angle of the jeep radar screen (sh_custom_config.lua:135)
local screenAng = screenEnt:LocalToWorldAngles(__newangle(10, -125, 0))

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
    TIV.Instruments.DrawRadarScreen(screenEnt, veh, rData, screenAng)

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
            ok2 = ok2 and ((c.right and dx > 6) or (not c.right and dx < -6))
        end

        local deg, sector
        if relLine then
            deg, sector = relLine:match("^REL BRG:%s*(%d+)%s+(%u+)")
            deg = tonumber(deg)
            ok2 = ok2 and sector == c.sector
            if deg then
                -- the printed bearing must point at the same screen region as the blip
                if deg < 45 or deg >= 315 then
                    ok2 = ok2 and dy < -6
                elseif deg < 135 then
                    ok2 = ok2 and dx > 6
                elseif deg < 225 then
                    ok2 = ok2 and dy > 6
                else
                    ok2 = ok2 and dx < -6
                end
            end
        else
            ok2 = false
        end

        local ud = (dy < -6) and "ABOVE centre (=reads as AHEAD)"
            or (dy > 6) and "BELOW centre (=reads as BEHIND)"
            or "on centre line"
        local lr = (dx > 6) and "RIGHT of centre" or (dx < -6) and "LEFT of centre" or "on centre line"

        print(string.format("[%s] %-24s dx=%+7.1f dy=%+7.1f -> %s / %s",
            ok2 and "OK " or "BAD", c.name, dx, dy, ud, lr))
        print(string.format("      %-24s readout: %s", "", relLine or "(no REL BRG readout painted!)"))
        if ok2 then passed = passed + 1 end
    end
end

print("")
print(string.format("RESULT: %d/4 blips land on the correct side of the screen", passed))
os.exit(passed == 4 and 0 or 1)
