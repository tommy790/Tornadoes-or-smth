-- ===========================================================================
-- TIV ANCHOR LOAD MODEL PROBE (server)
--
-- Executes the REAL TIV.Rock.ComputeLoad from
-- jeep_jalopy_interceptor/lua/tiv/anchor/sv_rock.lua against the REAL
-- TIV.Loft.CalculateStress from sv_loft.lua, and asserts that the numbers the
-- client turns into a visual lean are the right ones:
--
--   * wind from the front lifts the nose; wind from a side rolls toward that
--     side, with the sign conventions measured from the Source basis rather than
--     assumed;
--   * sheared anchors make the corner they were holding fly up;
--   * everything stays inside -1..1 no matter how many anchors are gone;
--   * no wind means exactly zero, so a calm vehicle never leans;
--   * the module never touches the vehicle's physics.
--
--   tools/bin/luajit tools/rock_load_probe.lua
--
-- Exit 0 = every case classified as expected.
-- ===========================================================================

local here = (arg and arg[0] or "tools/rock_load_probe.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local repo = here:match("^(.*)[/\\]tools$") or "."

-- The Vector/Angle basis comes from the shared stub, which radar_selftest.lua
-- checks against Source's actual handedness. Hand-rolling it here produced an
-- Angle:Right() that returned (0,+1,0) instead of (0,-1,0) and inverted every
-- roll assertion in this file, so it is deliberately not reimplemented.
dofile(here .. "/gmod_stub.lua")

local bad = dofile(here .. "/radar_selftest.lua")
if #bad > 0 then
    io.stderr:write("FAIL: GMod stub does not match Source conventions:\n")
    for _, b in ipairs(bad) do io.stderr:write("    " .. b .. "\n") end
    os.exit(1)
end

SERVER = true
CLIENT = false

local noop = function() end

function isvector(v) return getmetatable(v) == Vector end

-- gmod_stub has no timer table; sv_loft.lua registers its think loop at load.
timer = timer or {}
timer.Create = timer.Create or noop
timer.Remove = timer.Remove or noop
timer.Simple = timer.Simple or noop
timer.Exists = timer.Exists or function() return false end

local fakeCvar = { GetBool = function() return false end, GetFloat = function() return 0 end,
                   GetInt = function() return 0 end, GetString = function() return "0" end }
CreateConVar = CreateConVar or function() return fakeCvar end
GetConVar = GetConVar or function() return fakeCvar end

util.Effect = noop
util.ScreenShake = noop
util.TraceLine = function() return { Hit = false } end
concommand = { Add = noop }
constraint = { RemoveAll = noop }
function EffectData() return setmetatable({}, { __index = function() return noop end }) end
function SafeRemoveEntity() end
function SafeRemoveEntityDelayed() end
function Entity(i) return nil end
MASK_SOLID = 3

------------------------------------------------------------------------------
-- Test vehicle
--
-- WorldToLocal uses the real GMod convention: local +x is FORWARD, local +y is
-- LEFT (because Angle:Right() is local -Y), local +z is up.
------------------------------------------------------------------------------
local FORBIDDEN = { "SetPos", "SetAngles", "SetVelocity", "Freeze", "SetOwner" }

local function makeVeh(pos, yaw, idx)
    local ang = _G.Angle(0, yaw, 0)
    local e = { _pos = pos, _ang = ang, _idx = idx or 7, _calls = {} }
    function e:GetPos() return self._pos end
    function e:GetAngles() return self._ang end
    function e:GetForward() return self._ang:Forward() end
    function e:GetRight() return self._ang:Right() end
    function e:GetUp() return self._ang:Up() end
    function e:EntIndex() return self._idx end
    function e:WorldToLocal(wp)
        local rel = wp - self._pos
        local f, r, u = self:GetForward(), self:GetRight(), self:GetUp()
        return _G.Vector(rel:Dot(f), -rel:Dot(r), rel:Dot(u))
    end
    function e:LocalToWorld(v)
        local f, r, u = self:GetForward(), self:GetRight(), self:GetUp()
        return self._pos + f * v.x - r * v.y + u * v.z
    end
    function e:GetPhysicsObject() return { GetVelocity = function() return _G.Vector(0,0,0) end } end
    for _, name in ipairs(FORBIDDEN) do
        e[name] = function(self, ...) self._calls[#self._calls + 1] = name return self end
    end
    return e
end

------------------------------------------------------------------------------
-- Load the real modules
------------------------------------------------------------------------------
TIV = { Config = { LoftWindThreshold = 160, SpikeDriveDepth = 18 } }
TIV.Deploy = { Vehicles = {} }
TIV.Spikes = { GetCount = function() return 0 end }
TIV.Anchor = { BreakSpike = noop, ForceDetach = noop, DetachAll = noop, AttachSingle = noop }
TIV.Compat = { Enabled = false }

assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/loft/sv_loft.lua"))()
assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/anchor/sv_rock.lua"))()

assert(TIV.Rock and TIV.Rock.ComputeLoad, "sv_rock.lua did not define TIV.Rock.ComputeLoad")
assert(TIV.Loft and TIV.Loft.CalculateStress, "sv_loft.lua did not define TIV.Loft.CalculateStress")

------------------------------------------------------------------------------
-- Scenario helpers
------------------------------------------------------------------------------
-- Four anchors at the corners of the body: +x front, +y left.
local CORNERS = {
    { x =  70, y =  45, tag = "front-left"  },
    { x =  70, y = -45, tag = "front-right" },
    { x = -70, y =  45, tag = "rear-left"   },
    { x = -70, y = -45, tag = "rear-right"  },
}

local function makeData(opts)
    opts = opts or {}
    local data = { state = "anchored", anchored = true, spikes = {}, constraints = {} }
    local dead = opts.dead or {}
    for i, c in ipairs(CORNERS) do
        data.spikes[i] = {
            index = i, phase = "deployed", failed = dead[c.tag] and true or false,
            localPos = _G.Vector(c.x, c.y, -20),
            entity = { GetPos = function() return _G.Vector(c.x, c.y, 0) end },
        }
    end
    return data
end

-- Controlled wind. GetDirection returns the direction the wind pushes TOWARD,
-- which is how GetForceVector consumes it.
local windMPH, windDir = 0, _G.Vector(1, 0, 0)
TIV.Wind = {
    GetSpeed = function() return windMPH end,
    GetDirection = function() return windDir end,
}

local function load_With(mph, dirWorld, opts)
    windMPH, windDir = mph, dirWorld
    local veh = makeVeh(_G.Vector(0, 0, 20), (opts and opts.yaw) or 0)
    local stress, pitchN, rollN, deployed, failed = TIV.Rock.ComputeLoad(veh, makeData(opts))
    return stress, pitchN, rollN, deployed, failed, veh
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
local function near(v, target, tol) return math.abs(v - target) <= (tol or 1e-6) end

print("== calm air produces no lean ==")
local s, p, r, dep, fl = load_With(0, _G.Vector(1, 0, 0))
check("no wind -> zero stress", s == 0, string.format("stress=%s", tostring(s)))
check("no wind -> zero pitch", p == 0, string.format("pitchN=%s", tostring(p)))
check("no wind -> zero roll", r == 0, string.format("rollN=%s", tostring(r)))
check("no wind still reports 4 live anchors", dep == 4 and fl == 0, string.format("deployed=%d failed=%d", dep, fl))

s = load_With(80, _G.Vector(1, 0, 0))
check("below the stress floor -> zero stress", s == 0, string.format("stress=%s (CalculateStress ignores <100 MPH)", tostring(s)))

print("\n== which way it leans (signs measured from the Source basis) ==")

-- Wind blowing toward -X arrives from the FRONT.
s, p, r = load_With(200, _G.Vector(-1, 0, 0))
check("wind from the FRONT lifts the NOSE (pitchN > 0)", p > 0.5, string.format("pitchN=%+.2f", p))
check("head-on wind produces no roll", near(r, 0, 1e-6), string.format("rollN=%+.2f", r))

-- Wind blowing toward +X arrives from BEHIND: the tail peels up.
s, p, r = load_With(200, _G.Vector(1, 0, 0))
check("wind from BEHIND lifts the TAIL (pitchN < 0)", p < -0.5, string.format("pitchN=%+.2f", p))

-- Vehicle local +Y is LEFT. Wind blowing toward -Y arrives from the LEFT.
s, p, r = load_With(200, _G.Vector(0, -1, 0))
check("wind from the LEFT rolls TOWARD THE LEFT (rollN < 0)", r < -0.5,
    string.format("rollN=%+.2f (negative roll drops the left side)", r))
check("beam wind from the left produces no pitch", near(p, 0, 1e-6), string.format("pitchN=%+.2f", p))

-- Wind blowing toward +Y arrives from the RIGHT.
s, p, r = load_With(200, _G.Vector(0, 1, 0))
check("wind from the RIGHT rolls TOWARD THE RIGHT (rollN > 0)", r > 0.5, string.format("rollN=%+.2f", r))

print("\n== the signs follow the vehicle, not the map ==")
-- Same world wind, vehicle turned 90 degrees: what was a headwind is now a beam
-- wind. If the model were using map angles this would not change.
local _, p0, r0 = load_With(200, _G.Vector(-1, 0, 0), { yaw = 0 })
local _, p90, r90 = load_With(200, _G.Vector(-1, 0, 0), { yaw = 90 })
check("yaw 0: headwind is pure pitch", math.abs(p0) > 0.5 and near(r0, 0, 1e-6),
    string.format("pitchN=%+.2f rollN=%+.2f", p0, r0))
check("yaw 90: the same wind becomes a side load", math.abs(p90) < 0.1 and math.abs(r90) > 0.3,
    string.format("pitchN=%+.2f rollN=%+.2f", p90, r90))

print("\n== sheared anchors let their corner fly ==")

-- Front anchors gone: the surviving holds are at the rear, so the nose rises.
local _, pf, _, df, ff = load_With(200, _G.Vector(0, -1, 0), { dead = { ["front-left"] = true, ["front-right"] = true } })
check("front anchors gone -> nose rises further", pf > 0,
    string.format("pitchN=%+.2f (pivot term adds nose-up), deployed=%d failed=%d", pf, df, ff))
check("failed anchors are counted", df == 2 and ff == 2, string.format("deployed=%d failed=%d", df, ff))

-- Left anchors gone: the surviving holds are on the right, so the left rises.
-- Left side up is POSITIVE roll, the opposite of the wind-from-left gesture.
local _, _, rl = load_With(200, _G.Vector(0, -1, 0), { dead = { ["front-left"] = true, ["rear-left"] = true } })
local _, _, rlWind = load_With(200, _G.Vector(0, -1, 0))
check("losing the LEFT anchors pushes roll back toward positive", rl > rlWind,
    string.format("with left anchors gone rollN=%+.2f vs intact %+.2f", rl, rlWind))

print("\n== bounds and side effects ==")

-- Hammer it with combinations that could plausibly overflow the -1..1 contract.
local worstP, worstR = 0, 0
for _, mph in ipairs({ 100, 200, 400, 900 }) do
    for _, dead in ipairs({ {}, { ["front-left"] = true }, { ["front-left"] = true, ["rear-left"] = true },
                            { ["front-left"] = true, ["front-right"] = true, ["rear-left"] = true } }) do
        for _, dir in ipairs({ _G.Vector(-1,0,0), _G.Vector(0,-1,0), _G.Vector(-0.7,-0.7,0), _G.Vector(0.3,-0.9,0.2) }) do
            local _, pp, rr = load_With(mph, dir, { dead = dead })
            if math.abs(pp) > worstP then worstP = math.abs(pp) end
            if math.abs(rr) > worstR then worstR = math.abs(rr) end
        end
    end
end
check("pitch weight never leaves -1..1", worstP <= 1.0, string.format("worst |pitchN|=%.3f", worstP))
check("roll weight never leaves -1..1", worstR <= 1.0, string.format("worst |rollN|=%.3f", worstR))

-- The module must be read-only with respect to the vehicle.
windMPH, windDir = 250, _G.Vector(-1, 0, 0)
local watched = makeVeh(_G.Vector(0, 0, 20), 0)
TIV.Rock.ComputeLoad(watched, makeData())
check("ComputeLoad never writes to the vehicle's transform", #watched._calls == 0,
    #watched._calls == 0 and "no SetPos/SetAngles/SetVelocity/Freeze" or ("called: " .. table.concat(watched._calls, ",")))

-- A vehicle with no spikes at all must not divide by zero or throw.
local ok, e = pcall(function()
    windMPH = 250
    return TIV.Rock.ComputeLoad(makeVeh(_G.Vector(0,0,20), 0), { spikes = {} })
end)
check("no spikes at all does not throw", ok, ok and "returned cleanly" or tostring(e))

print(string.format("\nRESULT: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
