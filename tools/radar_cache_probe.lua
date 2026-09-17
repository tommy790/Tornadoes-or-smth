-- ===========================================================================
-- TIV RADAR SCREEN CACHE PROBE
--
-- Exercises the REAL PostDrawTranslucentRenderables hook body registered by
-- jeep_jalopy_interceptor/lua/tiv/instruments/cl_radar_screen.lua, and checks:
--
--   1. a radar screen prop is found and drawn;
--   2. ents.FindByClass is NOT called once per frame any more;
--   3. a prop whose TIV_RadarScreen network var lands after OnEntityCreated is
--      still picked up (the pending-resolution path);
--   4. a removed prop stops being drawn.
--
--   tools/bin/luajit tools/radar_cache_probe.lua
--
-- Exit 0 = all four hold.
-- ===========================================================================

local here = (arg and arg[0] or "tools/radar_cache_probe.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local repo = here:match("^(.*)[/\\]tools$") or "."
local TARGET = os.getenv("TIV_TARGET") or (repo .. "/jeep_jalopy_interceptor/lua/tiv/instruments/cl_radar_screen.lua")

------------------------------------------------------------------------------
-- Vector with DistToSqr (needed by the hook's distance cull)
------------------------------------------------------------------------------
local Vector = {}
Vector.__index = Vector
Vector.__tostring = function(v) return string.format("Vector(%.1f, %.1f, %.1f)", v.x, v.y, v.z) end
Vector.__add = function(a, b) return setmetatable({x=a.x+b.x, y=a.y+b.y, z=a.z+b.z}, Vector) end
Vector.__sub = function(a, b) return setmetatable({x=a.x-b.x, y=a.y-b.y, z=a.z-b.z}, Vector) end
Vector.__mul = function(a, b)
    if type(b) == "table" then return setmetatable({x=a.x*b.x, y=a.y*b.y, z=a.z*b.z}, Vector) end
    return setmetatable({x=a.x*b, y=a.y*b, z=a.z*b}, Vector)
end
Vector.__unm = function(a) return setmetatable({x=-a.x, y=-a.y, z=-a.z}, Vector) end
function Vector:Dot(o) return self.x*o.x + self.y*o.y + self.z*o.z end
function Vector:Length() return math.sqrt(self:Dot(self)) end
function Vector:DistToSqr(o) local d = self - o return d:Dot(d) end
function Vector:GetNormalized()
    local l = self:Length()
    if l == 0 then return setmetatable({x=0, y=0, z=0}, Vector) end
    return setmetatable({x=self.x/l, y=self.y/l, z=self.z/l}, Vector)
end

------------------------------------------------------------------------------
-- Minimal Angle (the radar screen prop is spawned unrotated in this probe)
------------------------------------------------------------------------------
local Angle = {}
Angle.__index = Angle
function Angle:Forward() return setmetatable({x=1, y=0, z=0}, Vector) end
function Angle:Right()   return setmetatable({x=0, y=-1, z=0}, Vector) end
-- The monitor glass faces the driver, i.e. down and back, so the backface cull
-- ((eyePos - centerPos):Dot(normal) > 0) passes from the driver's seat.
function Angle:Up()      return setmetatable({x=0, y=0, z=-1}, Vector) end

------------------------------------------------------------------------------
-- Test world
------------------------------------------------------------------------------
local start3d2dCount = 0  -- incremented by the stub cam.Start3D2D
local world = {}          -- every prop_physics in the "map"
local findCount = 0       -- how many times ents.FindByClass ran
local clock = 0.0

local hooks = {}

local function makeProp(pos, opts)
    opts = opts or {}
    local e = {
        _pos = pos,
        _class = "prop_physics",
        _nwbool = {},
        _nwentity = {},
        _parent = opts.parent,
        _model = opts.model or "models/kobilica/wiremonitorsmall.mdl",
        _valid = true,
    }
    function e:GetClass() return self._class end
    function e:GetPos() return self._pos end
    function e:GetModel() return self._model end
    function e:GetModelScale() return 1.0 end
    function e:GetParent() return self._parent end
    function e:GetNWBool(k, d) local v = self._nwbool[k]; if v == nil then return d or false end return v end
    function e:SetNWBool(k, v) self._nwbool[k] = v end
    function e:GetNWEntity(k) return self._nwentity[k] end
    function e:SetNWEntity(k, v) self._nwentity[k] = v end
    function e:EntIndex() return self._idx or 1 end
    function e:LocalToWorld(v) return self._pos + v end
    function e:LocalToWorldAngles() return setmetatable({}, Angle) end
    function e:GetAngles() return setmetatable({}, Angle) end
    function e:GetForward() return setmetatable({}, Angle):Forward() end
    function e:GetRight() return setmetatable({}, Angle):Right() end
    function e:GetUp() return setmetatable({}, Angle):Up() end
    return e
end

------------------------------------------------------------------------------
-- Environment the addon file is loaded into. Unknown globals resolve to a
-- no-op, so every GMod call this probe does not care about is harmless.
------------------------------------------------------------------------------
local noop = function() end

local env = {}
env._G = env
env.math = math
env.string = string
env.table = table
env.ipairs = ipairs
env.pairs = pairs
env.next = next
env.type = type
env.tonumber = tonumber
env.tostring = tostring
env.setmetatable = setmetatable
env.getmetatable = getmetatable
env.rawget = rawget
env.rawset = rawset
env.select = select
env.unpack = unpack
env.error = error
env.pcall = pcall
env.print = print
env.os = os
env.STENCIL_ALWAYS, env.STENCIL_EQUAL, env.STENCIL_REPLACE, env.STENCIL_KEEP = 0, 3, 5, 1
env.TEXT_ALIGN_LEFT, env.TEXT_ALIGN_CENTER, env.TEXT_ALIGN_RIGHT = 0, 1, 2
env.TEXT_ALIGN_TOP, env.TEXT_ALIGN_BOTTOM = 3, 4

env.Vector = function(x, y, z) return setmetatable({x=x or 0, y=y or 0, z=z or 0}, Vector) end
env.Angle = function() return setmetatable({}, Angle) end
env.Color = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
env.CurTime = function() return clock end
env.RealTime = function() return clock end
env.EyePos = function() return setmetatable({x=0, y=0, z=0}, Vector) end
env.LocalPlayer = function() return { GetPos = function() return setmetatable({x=0,y=0,z=0}, Vector) end } end
env.IsValid = function(e) return e ~= nil and e ~= false and e._valid ~= false end
env.istable = function(v) return type(v) == "table" end
env.isvector = function(v) return type(v) == "table" and v.x ~= nil end
env.isentity = function(v) return type(v) == "table" and v.GetPos ~= nil end
env.isfunction = function(v) return type(v) == "function" end
env.isnumber = function(v) return type(v) == "number" end
env.isstring = function(v) return type(v) == "string" end
env.isbool = function(v) return type(v) == "boolean" end
env.math.Round = env.math.Round or function(v, d)
    local m = 10 ^ (d or 0)
    return math.floor(v * m + 0.5) / m
end
env.math.Clamp = env.math.Clamp or function(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
env.math.atan2 = env.math.atan2 or function(y, x) return math.atan(y, x) end
env.bit = {
    band = function(a, b) return math.floor(a) & math.floor(b) end,
    bor  = function(a, b) return math.floor(a) | math.floor(b) end,
}

env.hook = {
    Add = function(name, id, fn) hooks[name] = fn end,
    Remove = function() end,
    Run = function() end,
}
env.ents = {
    FindByClass = function()
        findCount = findCount + 1
        return world
    end,
    GetAll = function() return world end,
}
env.surface = setmetatable({
    GetTextSize = function() return 10, 10 end,
}, { __index = function() return noop end })
env.draw = setmetatable({}, { __index = function() return noop end })
env.render = setmetatable({}, { __index = function() return noop end })

-- cam.Start3D2D fires exactly once per radar screen actually rendered, so it is
-- the observable "this prop was drawn" signal.
env.cam = setmetatable({
    Start3D2D = function() start3d2dCount = start3d2dCount + 1 end,
}, { __index = function() return noop end })
env.net = setmetatable({}, { __index = function() return noop end })
env.util = setmetatable({ IsValidModel = function() return true end }, { __index = function() return noop end })
env.player = setmetatable({}, { __index = function() return noop end })

-- Anything not explicitly provided falls back to the real Lua globals, then to
-- a per-name stub: a table for Capitalised names (GMod convention for library
-- tables such as TIV, E2Lib, WireGPU_Monitors) and a no-op function otherwise.
setmetatable(env, {
    __index = function(t, k)
        local base = rawget(_G, k)
        if base ~= nil then return base end
        if type(k) == "string" and k:match("^%u") then
            local stub = {}
            rawset(t, k, stub)
            return stub
        end
        return noop
    end,
})

------------------------------------------------------------------------------
-- Load the real addon file into that environment
------------------------------------------------------------------------------
local chunk, lerr = loadfile(TARGET, "t", env)
if not chunk then
    io.stderr:write("FAILED TO LOAD " .. TARGET .. ": " .. tostring(lerr) .. "\n")
    os.exit(1)
end
local ok, rerr = pcall(chunk)
if not ok then
    io.stderr:write("RUNTIME ERROR ON LOAD: " .. tostring(rerr) .. "\n")
    os.exit(1)
end

local renderHook = hooks["PostDrawTranslucentRenderables"]
local onCreated  = hooks["OnEntityCreated"]
local onRemoved  = hooks["EntityRemoved"]

if not renderHook then
    io.stderr:write("FAIL: the addon did not register PostDrawTranslucentRenderables\n")
    os.exit(1)
end

print("Executed real file : " .. TARGET)
print(string.format("Lua runtime        : %s (%s)", _VERSION, jit and jit.version or "no jit"))
print("")

local failures = 0
local function check(label, cond, detail)
    print(string.format("[%s] %s%s", cond and "OK " or "BAD", label, detail and ("  -- " .. detail) or ""))
    if not cond then failures = failures + 1 end
end

------------------------------------------------------------------------------
-- Scenario: a vehicle plus its radar screen prop, mounted as in-game
-- (server sets TIV_OwnerVehicle then TIV_RadarScreen after Spawn()).
------------------------------------------------------------------------------
local veh = makeProp(setmetatable({x=0, y=0, z=20}, Vector), { model = "models/buggy.mdl" })
local screen = makeProp(setmetatable({x=0, y=14, z=42}, Vector))

-- Active tornado track so the screen has something to draw.
env.TIV = env.TIV or {}
env.TIV.Instruments.RadarData = {
    active = true,
    veh = veh,
    pos = setmetatable({x=2000, y=0, z=20}, Vector),
    heading = setmetatable({x=1, y=0, z=0}, Vector),
    speedMPH = 30, coreRadius = 600, outerRadius = 3500,
    dist = 2000, bearing = 0, eta = 10, impactType = "core", waypoints = {},
}

local function frame(t)
    clock = t
    local cok, cerr = pcall(renderHook, false, false)
    if not cok then
        io.stderr:write("hook error at t=" .. t .. ": " .. tostring(cerr) .. "\n")
        os.exit(1)
    end
end

-- --- 1. prop with network vars already present -------------------------------
table.insert(world, veh)
table.insert(world, screen)
screen:SetNWEntity("TIV_OwnerVehicle", veh)
screen:SetNWBool("TIV_RadarScreen", true)

local sweepsBefore = findCount
frame(0.0)
check("radar screen prop is found on the first frame", findCount > sweepsBefore,
      string.format("ents.FindByClass ran %d time(s)", findCount - sweepsBefore))

-- --- 2. the per-frame sweep is gone -----------------------------------------
findCount = 0
local FRAMES = 300
for i = 1, FRAMES do frame(i / 60) end   -- 5 seconds at 60 fps
local sweeps = findCount
check("ents.FindByClass is no longer called every frame", sweeps <= 6,
      string.format("%d sweep(s) over %d frames (5s of gameplay); was %d before the fix",
                    sweeps, FRAMES, FRAMES))

-- Helper: how many radar screens render on a single frame.
local function drawsOn(t)
    start3d2dCount = 0
    frame(t)
    return start3d2dCount
end

-- Helper: how many radar screens render on a single frame.
local function drawsOn(t)
    start3d2dCount = 0
    frame(t)
    return start3d2dCount
end

-- --- 3. a prop that is not (yet) tagged is not drawn --------------------------
local late = makeProp(setmetatable({x=0, y=-20, z=42}, Vector))
table.insert(world, late)
if onCreated then onCreated(late) end          -- created WITHOUT its network vars

check("an untagged prop is not drawn", drawsOn(10.0) == 1,
      "expected 1 (only the original screen)")

-- --- 4. its network vars land a frame later ----------------------------------
-- Note the simulated clock has already jumped 5s -> 10s here. The old code
-- measured its grace window from OnEntityCreated, so a gap like this expired the
-- candidate before the network var could ever arrive and the screen never came
-- up. The window is now a leak guard only, so this must still work.
late:SetNWEntity("TIV_OwnerVehicle", veh)
late:SetNWBool("TIV_RadarScreen", true)
check("prop is adopted once its NW vars land, despite the clock gap", drawsOn(10.2) == 2,
      "expected 2")

-- --- 5. removal ---------------------------------------------------------------
-- Take it out of the map as well as firing EntityRemoved, otherwise the periodic
-- sweep would legitimately re-adopt it and mask the result.
if onRemoved then onRemoved(late) end
for i, e in ipairs(world) do
    if e == late then table.remove(world, i) break end
end
check("removed prop stops being drawn", drawsOn(10.4) == 1,
      "expected 1")

-- --- 6. an untagged prop is not drawn even after a long idle period -----------
local dud = makeProp(setmetatable({x=0, y=40, z=42}, Vector))
table.insert(world, dud)
if onCreated then onCreated(dud) end
frame(20.0)
frame(45.0)                                     -- far past any grace window
check("an untagged prop is never drawn", drawsOn(46.0) == 1,
      "expected 1 (only the original screen)")

-- ...and tagging it later still works. The pending fast path only covers props
-- tagged within PENDING_TTL of creation; beyond that the 1 Hz sweep is the
-- authoritative path, so allow up to one second for it to appear.
dud:SetNWEntity("TIV_OwnerVehicle", veh)
dud:SetNWBool("TIV_RadarScreen", true)
local adoptedAfter
for _, t in ipairs({ 46.1, 46.5, 46.9, 47.1 }) do
    if drawsOn(t) == 2 then adoptedAfter = t break end
end
check("...and tagging it later still adopts it within ~1s", adoptedAfter ~= nil,
      adoptedAfter and string.format("adopted at t=%.1f", adoptedAfter)
                   or "never adopted; expected 2 screens within a second")

print("")
if failures == 0 then
    print("RESULT: all cache behaviours correct")
else
    print(string.format("RESULT: %d failure(s)", failures))
end
os.exit(failures == 0 and 0 or 1)
