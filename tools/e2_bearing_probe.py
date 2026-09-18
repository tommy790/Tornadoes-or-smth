#!/usr/bin/env python3
# pylint: disable=line-too-long
"""
E2 probe: extracts the REAL e2function bodies from
jeep_jalopy_interceptor/lua/entities/gmod_wire_expression2/core/custom/tiv.lua,
compiles them as plain Lua against a stubbed GMod/E2 API, and checks the
tornado bearing helpers against the same four bearings the radar probe uses.

Usage:  python3 tools/e2_bearing_probe.py [vehicle_yaw_degrees]
Exit 0 = relative bearing and sector are correct for all four bearings, and
         tivTornadoBearing() is confirmed to be the absolute map angle.
"""
import math
import os
import re
import sys

from lupa import LuaRuntime

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
E2_TARGET = os.path.join(
    REPO, "jeep_jalopy_interceptor", "lua", "entities",
    "gmod_wire_expression2", "core", "custom", "tiv.lua",
)

# The E2 relative-bearing function delegates to TIV.RelativeBearing, which lives
# in the shared config. Load the real one rather than re-implementing it, or the
# probe would be testing a stand-in.
CONFIG_TARGET = os.path.join(
    REPO, "jeep_jalopy_interceptor", "lua", "tiv", "config", "sh_config.lua",
)

# Reuse the radar probe's vetted GMod API stub (Vector/Angle/entity/...).
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from radar_probe import GMOD_STUB, SELF_TEST  # noqa: E402

E2_SHIM = r"""
-- Minimal E2 host shim: e2function declarations become plain Lua functions,
-- `this`/`entity`/`self` resolve to the current test vehicle.
E2Lib = { RegisterExtension = function() end }
function __e2setcost() end
E2Helper = { Descriptions = setmetatable({}, { __index = function() return "" end }) }
NULL = setmetatable({}, { __tostring = function() return "NULL" end })
Lerp = Lerp or function(f, a, b) return a + (b - a) * f end
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
"""

# e2function number entity:tivFoo()           -> local function e2_tivFoo()
# e2function number entity:tivFoo(s)          -> local upgradeID; local function e2_tivFoo()
E2_FUNC_RE = re.compile(
    r"^e2function\s+[\w\s:]+?entity:(\w+)\s*\(([^)]*)\)\s*$",
    re.MULTILINE,
)


def to_plain_lua(src: str) -> str:
    """Rewrite e2function declarations so the bodies compile as plain Lua.

    E2 injects the declared parameters as locals, so emit a `local <params>`
    line ahead of the function to keep the bodies valid Lua.
    """

    def repl(m):
        name, raw = m.group(1), m.group(2).strip()
        # E2 declares parameters as "<type> <name>"; strip the type tokens.
        names = [p.split()[-1] for p in raw.split(",") if p.strip()] if raw else []
        decl = ("local " + ", ".join(names) + "\n") if names else ""
        return f"{decl}local function e2_{name}()"

    out = E2_FUNC_RE.sub(repl, src)
    left = re.findall(r"^e2function\s+.*$", out, flags=re.MULTILINE)
    if left:
        raise AssertionError(f"unhandled e2function forms: {left}")

    # The rewritten functions are file-locals, so export them to _G for the test.
    names = re.findall(r"^local function (e2_\w+)\(\)", out, flags=re.MULTILINE)
    out += "\n-- exported by the probe harness\n"
    out += "".join(f"_G.{n} = {n}\n" for n in names)
    return out


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    lua.execute(GMOD_STUB)
    lua.execute(E2_SHIM)

    # This harness drives identity-basis vehicles, whose nose IS entity +X, so no
    # heading correction is wanted. TIV.RelativeBearing reads the override first.
    g.TIV_HEADING_OFFSET_DEG = os.environ.get("TIV_HEADING_OFFSET_DEG", "0")

    with open(CONFIG_TARGET, "r", encoding="utf-8", errors="replace") as fh:
        try:
            lua.execute(fh.read())
        except Exception as exc:  # noqa: BLE001
            print(f"FAIL: could not load {os.path.relpath(CONFIG_TARGET, REPO)}: {exc}")
            return 1
    if lua.eval("TIV.RelativeBearing") is None:
        print("FAIL: TIV.RelativeBearing is not defined after loading sh_config.lua")
        return 1

    bad = lua.execute(SELF_TEST)
    if len(bad) > 0:
        print("FAIL: GMod stub does not match Source conventions:")
        for i in range(1, len(bad) + 1):
            print("   ", bad[i])
        return 1

    with open(E2_TARGET, "r", encoding="utf-8", errors="replace") as fh:
        src = fh.read()

    plain = to_plain_lua(src)
    try:
        lua.execute(plain)
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL: could not compile the real E2 source as Lua: {exc}")
        return 1

    veh_yaw = float(sys.argv[1]) if len(sys.argv) > 1 else 0.0
    print(f"Compiled real file : {os.path.relpath(E2_TARGET, REPO)}")
    print(f"Shared helper      : {os.path.relpath(CONFIG_TARGET, REPO)} (offset {g.TIV_HEADING_OFFSET_DEG})")
    print(f"Lua runtime        : {lua.eval('_VERSION')}")
    print(f"vehicle yaw        : {veh_yaw:g}")
    print()

    # Expected map angle for a target at world (0, 2000) seen from (0, 0).
    expect_map = (math.degrees(math.atan2(2000.0, 0.0)) + 360.0) % 360.0

    result = lua.execute(f"""
        -- Tracked vortex 2000 units to the vehicle's left-front, i.e. a fixed
        -- world position; the vehicle yaw is varied to prove the relative
        -- bearing tracks the vehicle while the map bearing does not.
        local vehPos  = __newvector(0, 0, 20)
        local tornado = __newvector(0, 2000, 20)

        TIV = TIV or {{}}
        TIV.Wind = {{
            GetNearestActiveTornado = function(pos)
                return {{
                    ent = nil, pos = tornado, heading = __newvector(1, 0, 0),
                    speedMPH = 30, coreRadius = 600, outerRadius = 3500,
                    dist = 2000,
                    -- exactly what sv_wind.lua:749 computes
                    bearing = (math.deg(math.atan2(tornado.y - pos.y, tornado.x - pos.x)) + 360) % 360,
                    eta = 0, impactType = "miss", waypoints = {{}},
                }}
            end,
        }}

        local veh = __makeent(vehPos, __newangle(0, {veh_yaw}, 0))
        this = veh

        -- Ground truth from the vehicle's own basis.
        local fwd = veh:GetForward()
        local rgt = veh:GetRight()
        local rel = tornado - vehPos
        local expect = math.deg(math.atan2(rel:Dot(rgt), rel:Dot(fwd)))
        if expect < 0 then expect = expect + 360 end

        local relGot    = e2_tivTornadoRelativeBearing()
        local sectorGot = e2_tivTornadoRelativeSector()
        local mapGot    = e2_tivTornadoBearing()

        local expectSector
        if expect < 45 or expect >= 315 then expectSector = 0
        elseif expect < 135 then expectSector = 1
        elseif expect < 225 then expectSector = 2
        else expectSector = 3 end

        return {{
            vehForward = fwd,
            expect     = expect,
            relGot     = relGot,
            sectorGot  = sectorGot,
            expectSector = expectSector,
            mapGot     = mapGot,
            tornado    = tornado,
        }}
    """)

    fwd = result["vehForward"]
    expect = float(result["expect"])
    rel_got = float(result["relGot"])
    sector_got = int(result["sectorGot"])
    expect_sector = int(result["expectSector"])
    map_got = float(result["mapGot"])

    print(f"veh:GetForward()        : {fwd}")
    print(f"tornado world position  : {result['tornado']}")
    print(f"tivTornadoBearing()     : {map_got:7.2f} deg   <- absolute MAP angle (world +X toward +Y)")
    print(f"tivTornadoRelativeBearing(): {rel_got:7.2f} deg (expected {expect:7.2f})")
    print(f"tivTornadoRelativeSector() : {sector_got} (expected {expect_sector})  [0=ahead 1=right 2=astern 3=left]")
    print()

    ok = True
    if abs(rel_got - expect) > 1e-6:
        print(f"BAD  relative bearing {rel_got:.4f} != expected {expect:.4f}")
        ok = False
    else:
        print("OK   relative bearing matches the vehicle's own basis")

    if sector_got != expect_sector:
        print(f"BAD  sector {sector_got} != expected {expect_sector}")
        ok = False
    else:
        print("OK   sector matches the relative bearing")

    # The map bearing must be independent of the vehicle's heading -- that is
    # precisely why it must not be presented as a track-up bearing.
    if abs(map_got - expect_map) > 1e-6:
        print(f"BAD  map bearing {map_got:.4f} != {expect_map:.4f}")
        ok = False
    else:
        print(f"OK   tivTornadoBearing() is the fixed map angle {expect_map:.0f} deg "
              f"(unchanging as the vehicle turns)")

    print()
    print("RESULT: " + ("all E2 bearing helpers correct" if ok else "FAILURES PRESENT"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
