#!/usr/bin/env python3
# pylint: disable=line-too-long
"""
Radar probe: executes the REAL
jeep_jalopy_interceptor/lua/tiv/instruments/cl_radar_screen.lua inside a
stubbed Garry's Mod API (real Lua via lupa) and reports where the tornado
centre icon is actually painted on the 512x512 radar canvas.

The harness supplies only the GMod API (Vector / Angle / surface / draw / ...).
It never re-implements the radar's own maths -- DrawRadarScreen is taken
straight out of the addon file.

Usage:  python3 tools/radar_probe.py [vehicle_yaw_degrees]
Exit 0 = all four bearings land on the correct side of the screen.
"""
import os
import sys

import lupa
from lupa import LuaRuntime

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(
    REPO, "jeep_jalopy_interceptor", "lua", "tiv", "instruments", "cl_radar_screen.lua"
)

TOOLS = os.path.dirname(os.path.abspath(__file__))
STUB_PATH = os.path.join(TOOLS, "gmod_stub.lua")
SELFTEST_PATH = os.path.join(TOOLS, "radar_selftest.lua")


def _read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


# Single source of truth, shared with tools/radar_probe_lua.lua (LuaJIT driver).
GMOD_STUB = _read(STUB_PATH)
SELF_TEST = _read(SELFTEST_PATH)

PROBE_TEMPLATE = r"""
local veh       = __makeent(__newvector(0, 0, 20), __newangle(0, __YAW__, 0))
local screenEnt = __makeent(__newvector(0, 0, 20), __newangle(0, __YAW__, 0))
-- shipped default local angle of the jeep radar screen (sh_custom_config.lua:135)
local screenAng = screenEnt:LocalToWorldAngles(__newangle(10, -125, 0))

local info = {
    fwd = veh:GetForward(), rgt = veh:GetRight(),
    sF  = screenAng:Forward(), sR = screenAng:Right(), sU = screenAng:Up(),
    fwdCanvasX = veh:GetForward():Dot(screenAng:Forward()),
    fwdCanvasY = veh:GetForward():Dot(screenAng:Right()),
}

-- Returns dx, dy of the tornado centre icon relative to the radar centre.
local function blipFor(tPos)
    _G.__calls = {}
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

    -- Grab the "REL BRG: nnn SECTOR" readout the telemetry box paints.
    local relLine
    for _, t in ipairs(_G.__texts) do
        if type(t.txt) == "string" and t.txt:find("^REL BRG:") then relLine = t.txt end
    end

    return blip.x + 3 - 256, blip.y + 3 - 260, relLine
end

local f, r = info.fwd, info.rgt
local origin = __newvector(0, 0, 20)

local cases = {
    { name = "tornado 2000u BEHIND", pos = origin - f * 2000, up = false, right = nil,  sector = "ASTERN" },
    { name = "tornado 2000u AHEAD",  pos = origin + f * 2000, up = true,  right = nil,  sector = "AHEAD" },
    { name = "tornado 2000u LEFT",   pos = origin - r * 2000, up = nil,   right = false, sector = "LEFT" },
    { name = "tornado 2000u RIGHT",  pos = origin + r * 2000, up = nil,   right = true,  sector = "RIGHT" },
}

local out = {}
for _, c in ipairs(cases) do
    local dx, dy, relLine = blipFor(c.pos)
    local ok, deg, sector = false, nil, nil
    if dx then
        ok = true
        if c.up ~= nil then
            ok = ok and ((c.up and dy < -6) or (not c.up and dy > 6))
        end
        if c.right ~= nil then
            ok = ok and ((c.right and dx > 6) or (not c.right and dx < -6))
        end
        if relLine then
            deg, sector = relLine:match("^REL BRG:%s*(%d+)%s+(%u+)")
            deg = tonumber(deg)
            -- The printed bearing must agree with the sector...
            ok = ok and sector == c.sector
            -- ...and the sector must agree with where the blip was drawn.
            if deg then
                if deg < 45 or deg >= 315 then
                    ok = ok and dy < -6
                elseif deg < 135 then
                    ok = ok and dx > 6
                elseif deg < 225 then
                    ok = ok and dy > 6
                else
                    ok = ok and dx < -6
                end
            end
        else
            ok = false
        end
    end
    out[#out + 1] = { name = c.name, dx = dx, dy = dy, ok = ok, deg = deg, sector = sector, rel = relLine }
end

return info, out
"""


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    lua.execute(GMOD_STUB)

    with open(TARGET, "r", encoding="utf-8", errors="replace") as fh:
        lua.execute(fh.read())

    if g.TIV is None or g.TIV.Instruments.DrawRadarScreen is None:
        print("FAIL: TIV.Instruments.DrawRadarScreen was not exported by the addon file")
        return 1

    bad = lua.execute(SELF_TEST)
    if len(bad) > 0:
        print("FAIL: GMod stub does not match Source conventions:")
        for i in range(1, len(bad) + 1):
            print("   ", bad[i])
        return 1

    veh_yaw = float(sys.argv[1]) if len(sys.argv) > 1 else 0.0
    print(f"Executed real file : {os.path.relpath(TARGET, REPO)}")
    print(f"Lua runtime        : {lua.eval('_VERSION')} (lupa {lupa.LUA_VERSION})")
    print(f"bit library        : {lua.eval('type(bit)')} / math.atan2: {lua.eval('type(math.atan2)')}")
    print("GMod stub          : self-test passed (8/8 Source basis checks)")

    info, out = lua.execute(PROBE_TEMPLATE.replace("__YAW__", repr(veh_yaw)))

    fwd, sF, sR = info["fwd"], info["sF"], info["sR"]
    print(f"vehicle            : pos=(0,0,20) yaw={veh_yaw:g}")
    print(f"  veh:GetForward() : {fwd}")
    print(f"  veh:GetRight()   : {info['rgt']}")
    print(f"screenAng forward  : {sF}  <- canvas +x axis (screen RIGHT)")
    print(f"screenAng right    : {sR}  <- canvas +y axis (screen DOWN)")
    print(f"screenAng up       : {info['sU']}  <- canvas normal (toward the driver)")
    print(
        f"vehicle forward in canvas space: canvas-x={float(info['fwdCanvasX']):+.3f}  "
        f"canvas-y={float(info['fwdCanvasY']):+.3f}   (canvas +y is screen DOWN)"
    )
    print("radar centre       : (256,260), ring radius 180")
    print()

    passed = 0
    for i in range(1, 5):
        row = out[i]
        name, dx, dy, ok = row["name"], row["dx"], row["dy"], bool(row["ok"])
        if dx is None:
            print(f"     {name:<24} -> NO on-screen blip (off-screen pip drawn instead)")
            continue
        dx, dy = float(dx), float(dy)
        ud = (
            "ABOVE centre (=reads as AHEAD)" if dy < -6
            else "BELOW centre (=reads as BEHIND)" if dy > 6
            else "on centre line"
        )
        lr = "RIGHT of centre" if dx > 6 else "LEFT of centre" if dx < -6 else "on centre line"
        rel = row["rel"] or "(no REL BRG readout painted!)"
        print(f"[{'OK ' if ok else 'BAD'}] {name:<24} dx={dx:+7.1f} dy={dy:+7.1f} -> {ud} / {lr}")
        print(f"      {'':<24} readout: {rel}")
        passed += 1 if ok else 0

    print()
    print(f"RESULT: {passed}/4 blips land on the correct side of the screen")
    return 0 if passed == 4 else 1


if __name__ == "__main__":
    sys.exit(main())
