-- ===========================================================================
-- TIV CIRCULATION & GROUND-CONTACT PROBE
--
-- Exercises the REAL compatibility layer in
-- jeep_jalopy_interceptor/lua/tiv/wind/sv_wind.lua against entities built to
-- match what GStorms, XT2 and XT3 actually publish, and asserts:
--
--   * ground contact comes from a real addon state or a real measurement, never
--     from "a tornado exists" -- an aloft GStorms funnel must report NOT
--     touching, and an unmeasurable vortex must report UNKNOWN;
--   * rotation direction comes from the addon's own anticyclonic flag, and
--     stays UNKNOWN when no addon publishes one;
--   * the report the radar receives collapses UNKNOWN ground contact to false,
--     so the renderer can never be talked into drawing a signature.
--
--   tools/bin/luajit tools/circulation_probe.lua
--
-- Exit 0 = every case classified as expected.
-- ===========================================================================

local here = (arg and arg[0] or "tools/circulation_probe.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local repo = here:match("^(.*)[/\\]tools$") or "."

------------------------------------------------------------------------------
-- Environment. gmod_stub.lua supplies Vector/Angle/math extensions; the rest is
-- filled in here because sv_wind.lua is a server file that touches timer and
-- concommand at load time, and the ground-contact trace needs a controllable
-- world.
------------------------------------------------------------------------------
dofile(here .. "/gmod_stub.lua")

SERVER = true
CLIENT = false

-- Ground plane the fake world reports. Tests set this to move the floor.
local WORLD_GROUND_Z = 0
local TRACE_HITS = true

util.TraceLine = function(t)
    if not TRACE_HITS then
        return { Hit = false, HitPos = Vector(0, 0, 0), Fraction = 1 }
    end
    return {
        Hit = true,
        HitPos = Vector(t.start.x, t.start.y, WORLD_GROUND_Z),
        Fraction = 0.5,
    }
end

MASK_SOLID_BRUSHONLY = 33554432
MASK_WATER = 32
MASK_SOLID = 3

isvector = isvector or function(v) return getmetatable(v) == Vector end
isangle = isangle or function(a) return getmetatable(a) == Angle end
isentity = isentity or function() return false end

timer = timer or {}
timer.Create = function() end
timer.Exists = function() return false end
timer.Remove = function() end
timer.Simple = function() end

concommand = { Add = function() end }
CreateConVar = function() return { GetBool = function() return false end, GetFloat = function() return 0 end, GetInt = function() return 0 end } end
GetConVar = function() return { GetBool = function() return false end, GetFloat = function() return 0 end, GetInt = function() return 0 end } end

-- A tornado entity stub. Only the fields the compatibility layer reads, plus
-- GetPos/GetClass which the surrounding tracker uses.
local function makeTornado(class, fields, pos)
    local e = { _class = class, _pos = pos or Vector(0, 0, 0) }
    for k, v in pairs(fields or {}) do e[k] = v end
    function e:GetClass() return self._class end
    function e:GetPos() return self._pos end
    function e:GetVelocity() return Vector(0, 0, 0) end
    return e
end

-- GStorms publishes FunnelStartHeight/FunnelMaxHeight as networked accessors
-- AND as plain fields; mirror both so the accessor path is genuinely exercised.
local function makeGStorms(opts)
    opts = opts or {}
    local e = makeTornado("gstorms_weather_tornado", {
        Tornado = true,
        VortexWindspeed = opts.windspeed or 180,
        FunnelStartHeight = opts.startH,
        FunnelMaxHeight = opts.maxH or 6500,
        Anticyclonic = opts.anticyclonic,
    }, opts.pos)
    function e:GetAnticyclonic() return self.Anticyclonic == true end
    function e:GetFunnelStartHeight() return self.FunnelStartHeight end
    function e:GetFunnelMaxHeight() return self.FunnelMaxHeight end
    return e
end

------------------------------------------------------------------------------
-- Load the real wind system.
------------------------------------------------------------------------------
TIV = TIV or {}
TIV.Config = TIV.Config or { WindDefault = 5 }

local chunk = assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/wind/sv_wind.lua"))
chunk()

local W = TIV.Wind
assert(W, "sv_wind.lua did not populate TIV.Wind")

------------------------------------------------------------------------------
-- Assertions
------------------------------------------------------------------------------
local passed, failed = 0, 0

local function check(label, got, want)
    local ok = (got == want)
    if ok then
        passed = passed + 1
        print(string.format("  [OK]   %-62s -> %s", label, tostring(got)))
    else
        failed = failed + 1
        print(string.format("  [BAD]  %-62s -> %s (expected %s)", label, tostring(got), tostring(want)))
    end
end

local CYC, ANTI, UNK = W.ROTATION_CYCLONIC, W.ROTATION_ANTICYCLONIC, W.ROTATION_UNKNOWN

print("== ground contact ==")

-- GStorms: funnel bottom lerped all the way down = on the ground.
check("gstorms funnel at ground (startH 0)", W.GetTornadoGroundContact(makeGStorms({ startH = 0 })), true)
check("gstorms funnel just settled (startH 40)", W.GetTornadoGroundContact(makeGStorms({ startH = 40 })), true)
-- GStorms: still at the ceiling = entirely aloft. THIS is the case that must not
-- be faked into a touchdown.
check("gstorms funnel aloft (startH == maxH)", W.GetTornadoGroundContact(makeGStorms({ startH = 6500, maxH = 6500 })), false)
check("gstorms funnel descending (startH 3200/6500)", W.GetTornadoGroundContact(makeGStorms({ startH = 3200, maxH = 6500 })), false)
-- GStorms configured to stop short of the ground never touches down.
check("gstorms funnel configured short (startH 900)", W.GetTornadoGroundContact(makeGStorms({ startH = 900, maxH = 6500 })), false)

-- XT3 / XT2 publish no funnel state at all, so the gap is measured.
WORLD_GROUND_Z = -20
check("xt3 vortex anchored at ground", W.GetTornadoGroundContact(makeTornado("xt3_tornadoes_ef3", { AntiCyclonic = false }, Vector(100, 200, 12))), true)
WORLD_GROUND_Z = -4000
check("vortex suspended 4000u above ground", W.GetTornadoGroundContact(makeTornado("xt3_tornadoes_ef3", {}, Vector(100, 200, 12))), false)
WORLD_GROUND_Z = 0

-- The measurement can fail; that must be reported, not guessed around.
TRACE_HITS = false
check("ground trace misses -> unknown (nil)", W.GetTornadoGroundContact(makeTornado("xt2_tornadoes_dynamic", {})), nil)
TRACE_HITS = true

check("no entity -> unknown (nil)", W.GetTornadoGroundContact(nil), nil)

print("\n== rotation direction ==")

check("gstorms cyclonic (Anticyclonic false)", W.GetTornadoRotationDirection(makeGStorms({ startH = 0, anticyclonic = false })), CYC)
check("gstorms anticyclonic (Anticyclonic true)", W.GetTornadoRotationDirection(makeGStorms({ startH = 0, anticyclonic = true })), ANTI)
check("xt3 cyclonic (AntiCyclonic false)", W.GetTornadoRotationDirection(makeTornado("xt3_tornadoes_ef5", { AntiCyclonic = false })), CYC)
check("xt3 anticyclonic (AntiCyclonic true)", W.GetTornadoRotationDirection(makeTornado("xt3_tornadoes_ef5", { AntiCyclonic = true })), ANTI)
check("xt2 cyclonic (IsAnticyclonic false)", W.GetTornadoRotationDirection(makeTornado("xt2_tornadoes_dynamic", { IsAnticyclonic = false, rotforce = -54 })), CYC)
check("xt2 anticyclonic (IsAnticyclonic true)", W.GetTornadoRotationDirection(makeTornado("xt2_autospawn_tornado", { IsAnticyclonic = true, rotforce = -54 })), ANTI)
-- XT2's EF variants only flip rotforce; the sign is the only real signal there.
check("xt2 ef0 anticyclonic via rotforce sign only", W.GetTornadoRotationDirection(makeTornado("xt2_tornadoes_ef-0", { rotforce = 54 })), ANTI)
check("xt2 ef0 cyclonic via rotforce sign only", W.GetTornadoRotationDirection(makeTornado("xt2_tornadoes_ef-0", { rotforce = -54 })), CYC)
-- Nothing published at all must stay unknown, not default to cyclonic.
check("no rotation data -> unknown", W.GetTornadoRotationDirection(makeTornado("some_mod_tornado", {})), UNK)
check("no entity -> unknown", W.GetTornadoRotationDirection(nil), UNK)

print("\n== circulation report (what the radar receives) ==")

local r = W.GetTornadoCirculationReport(makeGStorms({ startH = 0, anticyclonic = true, windspeed = 210 }))
check("touchdown: touchingGround", r.touchingGround, true)
check("touchdown: rotationDirection anticyclonic", r.rotationDirection, ANTI)
check("touchdown: rotationSpeed", r.rotationSpeed, 210)

r = W.GetTornadoCirculationReport(makeGStorms({ startH = 6500, maxH = 6500, anticyclonic = false }))
check("aloft: touchingGround", r.touchingGround, false)
check("aloft: rotation still reported", r.rotationDirection, CYC)

-- The critical one: an unmeasurable vortex must not arrive as a touchdown.
TRACE_HITS = false
r = W.GetTornadoCirculationReport(makeTornado("xt2_tornadoes_dynamic", { IsAnticyclonic = false }))
check("unmeasurable ground contact -> touchingGround false", r.touchingGround, false)
TRACE_HITS = true

r = W.GetTornadoCirculationReport(makeTornado("some_mod_tornado", {}))
-- An unrecognised addon is still measured: this one sits on the floor, so the
-- trace legitimately reports contact. That is a measurement, not an assumption.
check("unknown addon sitting on the floor -> touchingGround true", r.touchingGround, true)
check("unknown addon: rotationDirection unknown", r.rotationDirection, UNK)
check("unknown addon: rotationSpeed 0", r.rotationSpeed, 0)

-- And when the floor cannot be found, the same addon must NOT arrive as a
-- touchdown. This is the case a fake "tornado exists => touching" state fails.
TRACE_HITS = false
r = W.GetTornadoCirculationReport(makeTornado("some_mod_tornado", {}))
check("unknown addon, floor unmeasurable -> touchingGround false", r.touchingGround, false)
TRACE_HITS = true

-- Aloft and unrecognised: suspended in the air, nothing to draw.
WORLD_GROUND_Z = -9000
r = W.GetTornadoCirculationReport(makeTornado("some_mod_tornado", {}))
check("unknown addon entirely aloft -> touchingGround false", r.touchingGround, false)
WORLD_GROUND_Z = 0

r = W.GetTornadoCirculationReport(nil)
check("no entity: touchingGround false", r.touchingGround, false)
check("no entity: rotationDirection unknown", r.rotationDirection, UNK)

print("\n== rotation speed ==")
check("gstorms VortexWindspeed", W.GetTornadoRotationSpeed(makeGStorms({ windspeed = 165 })), 165)
check("xt2 MaxWinds fallback", W.GetTornadoRotationSpeed(makeTornado("xt2_autospawn_tornado", { MaxWinds = 120 })), 120)
check("zero is not a usable reading", W.GetTornadoRotationSpeed(makeTornado("xt2_tornadoes_ef-0", { Force = 0 })), nil)
check("no entity -> nil", W.GetTornadoRotationSpeed(nil), nil)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
