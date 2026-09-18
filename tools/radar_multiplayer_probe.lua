-- ===========================================================================
-- TIV RADAR MULTIPLAYER PROBE
--
-- Reproduces the multiplayer defect where every radar screen showed whichever
-- jeep's TIV_RadarPathData packet arrived last.
--
-- Two jeeps face OPPOSITE ways with one tornado dead ahead of jeep A (and
-- therefore dead astern of jeep B). Both packets are delivered to the client,
-- because the server net.Sends one per player. Each screen must then show its
-- own vehicle's bearing:
--
--     jeep A's screen -> REL BRG: 000 AHEAD
--     jeep B's screen -> REL BRG: 180 ASTERN
--
-- Before the per-vehicle fix, both screens read whichever packet landed last,
-- so exactly one of them was inverted. The probe runs the packet order both
-- ways to prove the result does not depend on arrival order.
--
--   tools/bin/luajit tools/radar_multiplayer_probe.lua
--
-- Exit 0 = every screen shows its own vehicle's bearing, in both orders.
-- ===========================================================================

local here = (arg and arg[0] or "tools/radar_multiplayer_probe.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local repo = here:match("^(.*)[/\\]tools$") or "."
local TARGET = os.getenv("TIV_TARGET")
    or (repo .. "/jeep_jalopy_interceptor/lua/tiv/instruments/cl_radar_screen.lua")

------------------------------------------------------------------------------
-- Vector
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
-- Angle: real yaw/pitch/roll, so two jeeps can face opposite ways.
-- Formulas are the ones tools/gmod_stub.lua uses, which that file validates
-- against eight GMod-documented basis values.
------------------------------------------------------------------------------
local rad, sin, cos = math.rad, math.sin, math.cos
local Angle = {}
Angle.__index = Angle
function Angle:Forward()
    local rp, ry = rad(self.p or 0), rad(self.y or 0)
    return setmetatable({x = cos(rp)*cos(ry), y = cos(rp)*sin(ry), z = sin(rp)}, Vector)
end
function Angle:Right()
    local rp, ry, rr = rad(self.p or 0), rad(self.y or 0), rad(self.r or 0)
    return setmetatable({
        x =  sin(ry)*cos(rr) + cos(ry)*sin(rp)*sin(rr),
        y = -sin(ry)*sin(rr) - cos(ry)*cos(rp)*cos(rr),
        z = -cos(rp)*sin(rr),
    }, Vector)
end
function Angle:Up()
    local rp, ry, rr = rad(self.p or 0), rad(self.y or 0), rad(self.r or 0)
    return setmetatable({
        x = -sin(ry)*sin(rr) + cos(ry)*sin(rp)*cos(rr),
        y =  sin(ry)*cos(rr) + cos(ry)*sin(rp)*sin(rr),
        z =  cos(rp)*cos(rr),
    }, Vector)
end
local function mkAngle(p, y, r) return setmetatable({p=p or 0, y=y or 0, r=r or 0}, Angle) end

-- parent:LocalToWorldAngles(child): rotate the child basis by the parent's
-- angles, then report the composed basis as an Angle-like object.
local function compose(parent, child)
    local function rot(a, v)
        local rp, ry, rr = rad(a.p or 0), rad(a.y or 0), rad(a.r or 0)
        local x1, y1, z1 = v.x, cos(rr)*v.y - sin(rr)*v.z, sin(rr)*v.y + cos(rr)*v.z
        local x2, y2, z2 = cos(rp)*x1 + sin(rp)*z1, y1, -sin(rp)*x1 + cos(rp)*z1
        return setmetatable({x = cos(ry)*x2 - sin(ry)*y2, y = sin(ry)*x2 + cos(ry)*y2, z = z2}, Vector)
    end
    local out = {}
    out.Forward = function() return rot(parent, child:Forward()) end
    out.Right   = function() return rot(parent, child:Right()) end
    out.Up      = function() return rot(parent, child:Up()) end
    return out
end

------------------------------------------------------------------------------
-- World
------------------------------------------------------------------------------
local world = {}
local hooks = {}
local netReceivers = {}
local texts = {}
local clock = 0.0
local currentViewer = nil

local function makeEnt(cls, pos, ang)
    local e = {
        _pos = pos, _ang = ang or mkAngle(0, 0, 0), _class = cls,
        _nwbool = {}, _nwentity = {}, _valid = true,
    }
    function e:GetClass() return self._class end
    function e:GetPos() return self._pos end
    function e:GetModel() return "models/kobilica/wiremonitorsmall.mdl" end
    function e:GetModelScale() return 1.0 end
    function e:GetParent() return nil end
    function e:GetAngles() return self._ang end
    function e:GetForward() return self._ang:Forward() end
    function e:GetRight() return self._ang:Right() end
    function e:GetUp() return self._ang:Up() end
    function e:GetNWBool(k, d) local v = self._nwbool[k]; if v == nil then return d or false end return v end
    function e:SetNWBool(k, v) self._nwbool[k] = v end
    function e:GetNWEntity(k) return self._nwentity[k] end
    function e:SetNWEntity(k, v) self._nwentity[k] = v end
    function e:EntIndex() return self._idx or 1 end
    function e:LocalToWorld(v) return self._pos + v end
    function e:LocalToWorldAngles(a) return compose(self._ang, a or self._cfgRot or mkAngle(0,0,0)) end
    return e
end

------------------------------------------------------------------------------
-- Environment
------------------------------------------------------------------------------
local noop = function() end

local env = {}
env._G = env
for _, k in ipairs{ "math", "string", "table", "ipairs", "pairs", "next", "type",
                    "tonumber", "tostring", "setmetatable", "getmetatable",
                    "rawget", "rawset", "select", "error", "pcall", "print", "os" } do
    env[k] = _G[k]
end
env.unpack = unpack
env.STENCIL_ALWAYS, env.STENCIL_EQUAL, env.STENCIL_REPLACE, env.STENCIL_KEEP = 0, 3, 5, 1
env.TEXT_ALIGN_LEFT, env.TEXT_ALIGN_CENTER, env.TEXT_ALIGN_RIGHT = 0, 1, 2
env.TEXT_ALIGN_TOP, env.TEXT_ALIGN_BOTTOM = 3, 4

env.Vector = function(x, y, z) return setmetatable({x=x or 0, y=y or 0, z=z or 0}, Vector) end
env.Angle = mkAngle
env.Color = function(r, g, b, a) return { r=r, g=g, b=b, a=a } end
env.CurTime = function() return clock end
env.RealTime = function() return clock end
-- Must be stubbed explicitly: the sandbox's fallback metatable hands back a
-- table for any unknown global, and the radar calls FrameTime() to step the
-- Doppler signature fade.
env.FrameTime = function() return 0.016 end
env.IsValid = function(e) return e ~= nil and e ~= false and e._valid ~= false end
env.istable = function(v) return type(v) == "table" end
env.isvector = function(v) return type(v) == "table" and v.x ~= nil end
env.isentity = function(v) return type(v) == "table" and v.GetPos ~= nil end
env.isfunction = function(v) return type(v) == "function" end
env.isnumber = function(v) return type(v) == "number" end
env.isstring = function(v) return type(v) == "string" end
env.isbool = function(v) return type(v) == "boolean" end
env.math.Round = env.math.Round or function(v, d) local m = 10^(d or 0) return math.floor(v*m + 0.5)/m end
env.math.Clamp = env.math.Clamp or function(v, lo, hi) if v < lo then return lo end if v > hi then return hi end return v end
env.math.atan2 = env.math.atan2 or function(y, x) return math.atan(y, x) end
env.bit = { band = function(a,b) return math.floor(a) & math.floor(b) end,
            bor  = function(a,b) return math.floor(a) | math.floor(b) end }

local eyePos = setmetatable({x = 0, y = 0, z = 0}, Vector)
env.EyePos = function() return eyePos end
env.LocalPlayer = function() return currentViewer end

env.hook = { Add = function(n, _, fn) hooks[n] = fn end, Remove = noop, Run = noop }
env.ents = { FindByClass = function() return world end, GetAll = function() return world end }
env.surface = setmetatable({ GetTextSize = function() return 10, 10 end }, { __index = function() return noop end })
env.draw = setmetatable({
    -- Record every painted string so the probe can read REL BRG back.
    SimpleText = function(txt) texts[#texts+1] = txt end,
}, { __index = function() return noop end })
env.render = setmetatable({}, { __index = function() return noop end })
local start3d2d = 0
env.cam = setmetatable({ Start3D2D = function() start3d2d = start3d2d + 1 end }, { __index = function() return noop end })
env.util = setmetatable({ IsValidModel = function() return true end }, { __index = function() return noop end })
env.player = setmetatable({ GetAll = function() return {} end }, { __index = function() return noop end })
env.net = {
    Receive = function(name, fn) netReceivers[name] = fn end,
    Start = noop, Send = noop,
}

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

env.TIV_HEADING_OFFSET_DEG = os.getenv("TIV_HEADING_OFFSET_DEG")


-- sh_config.lua registers a calibration convar on the client. Give it a real
-- function instead of letting the sandbox's table fallback swallow it.
env.CLIENT = true
env.CreateClientConVar = function() return nil end
env.GetConVar = function() return { GetString = function() return "0" end } end

-- The radar resolves its heading correction through TIV.HeadingOffsetDeg, which
-- lives in the shared config. Load the real file into the same sandbox.
local cfgChunk, cfgErr = loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/config/sh_config.lua", "t", env)
if not cfgChunk then io.stderr:write("FAIL: could not load sh_config.lua: " .. tostring(cfgErr) .. "\n") os.exit(1) end
local cfgOk, cfgRunErr = pcall(cfgChunk)
if not cfgOk then io.stderr:write("FAIL: error in sh_config.lua: " .. tostring(cfgRunErr) .. "\n") os.exit(1) end

local chunk, err = loadfile(TARGET, "t", env)
if not chunk then io.stderr:write("FAIL: could not load " .. TARGET .. ": " .. tostring(err) .. "\n") os.exit(1) end
local ok, lerr = pcall(chunk)
if not ok then io.stderr:write("FAIL: error running " .. TARGET .. ": " .. tostring(lerr) .. "\n") os.exit(1) end

local TIV = env.TIV
if not (TIV and TIV.Instruments and TIV.Instruments.GetRadarData) then
    io.stderr:write("FAIL: TIV.Instruments.GetRadarData is not defined\n"); os.exit(1)
end
if not netReceivers["TIV_RadarPathData"] then
    io.stderr:write("FAIL: no net.Receive registered for TIV_RadarPathData\n"); os.exit(1)
end

------------------------------------------------------------------------------
-- Scenario
------------------------------------------------------------------------------
-- The server resolves the nearest active tornado FROM EACH VEHICLE'S OWN
-- POSITION, but every packet carries that vortex's TRUE WORLD position. What
-- differs between jeeps is therefore their own position and heading -- which is
-- exactly why a client that keeps one global packet and renders it against its
-- own vehicle gets the bearing wrong.
--
--   vortex V at the origin.
--   jeep A at (-20000,0) facing +X -> V is dead AHEAD, its packet carries pos (20000,0).
--   jeep B at ( 20000,0) facing +X -> V is dead ASTERN, its packet carries pos (-20000,0).
--
-- The two jeeps sit on OPPOSITE sides of the vortex and both face +X, so their
-- packets carry genuinely different pos values. Screen A must read AHEAD and
-- screen B ASTERN.
--
-- This is what makes the shared-packet bug observable: a client with one global
-- packet renders whichever pos arrived last against its own heading, so the
-- screen whose packet lost reads the exact opposite sector. With both jeeps on
-- the same side of the vortex the packets would agree and the bug would hide --
-- an earlier version of this probe made that mistake and passed against the
-- buggy code.
local VORTEX_A = setmetatable({x =  20000, y = 0, z = 0}, Vector)  -- V as A's radar reports it
local VORTEX_B = setmetatable({x = -20000, y = 0, z = 0}, Vector)  -- V as B's radar reports it

-- cfg.rot for models/kobilica/wiremonitorsmall.mdl (MONITOR_CONFIGS).
local MONITOR_ROT = mkAngle(0, 90, 90)

local function makeJeep(name, pos, yaw)
    local veh = makeEnt("prop_vehicle_jeep", pos, mkAngle(0, yaw, 0))
    veh._name = name
    local screen = makeEnt("prop_physics", pos + setmetatable({x=10, y=0, z=40}, Vector), mkAngle(0, yaw, 0))
    screen._cfgRot = MONITOR_ROT
    screen:SetNWBool("TIV_RadarScreen", true)
    screen:SetNWEntity("TIV_OwnerVehicle", veh)
    return veh, screen
end

local jeepA, screenA = makeJeep("A", setmetatable({x=-20000, y=0, z=20}, Vector), 0)
-- Jeep B faces -X and is parked beside jeep A. The hook reads EyePos() ONCE at
-- the top, not per screen, so both panels must be visible from a single eye:
-- Both panels face world -X, so the eye sits at world x below both screen
-- centres and within the 1000-unit distance cull of each.
local jeepB, screenB = makeJeep("B", setmetatable({x= 20000, y=0, z=20}, Vector), 0)


world = { screenA, screenB }

-- The local player, driving jeep A. The render hook bails out without a valid
-- LocalPlayer, and GetRadarData resolves the viewer's vehicle from this.
currentViewer = {
    _valid = true,
    GetPos = function() return setmetatable({x=0, y=0, z=40}, Vector) end,
    GetVehicle = function() return jeepA end,
}
env.LocalPlayer = function() return currentViewer end
env.TIV = env.TIV

-- Deliver one server packet. Mirrors sv_instruments.lua's TIV_RadarPathData.
local function deliver(veh, tornadoPos, dist, bearing)
    -- Trailing false/0/0 are the circulation fields the server appends after the
    -- waypoints: touchingGround, rotationDirection, rotationSpeed. Left off the
    -- ground so this probe measures bearing separation only.
    local i, args = 0, { veh, true, tornadoPos, setmetatable({x=1,y=0,z=0}, Vector),
                         30, 600, 3500, dist, bearing, 10, "core", 0,
                         false, 0, 0 }
    local saved = env.net
    env.net = setmetatable({
        ReadEntity = function() i = i + 1 return args[i] end,
        ReadBool   = function() i = i + 1 return args[i] end,
        ReadVector = function() i = i + 1 return args[i] end,
        ReadFloat  = function() i = i + 1 return args[i] end,
        ReadString = function() i = i + 1 return args[i] end,
        ReadUInt   = function() i = i + 1 return args[i] end,
        ReadInt    = function() i = i + 1 return args[i] end,
    }, { __index = saved })
    netReceivers["TIV_RadarPathData"]()
    env.net = saved
end

-- The render hook reads EyePos() ONCE at the top and distance-culls every panel
-- against it, and the two jeeps are 21000u apart, so no single eye can see both.
-- Render twice, standing on each screen's own glass normal, and read each
-- screen's REL BRG from the pass that drew it.
local MOUNT_OFFSET = setmetatable({x = 0.36, y = 0.05, z = 5.05}, Vector)

local function renderEach()
    local got = {}
    for _, sc in ipairs({ screenA, screenB }) do
        local n = compose(sc._ang, MONITOR_ROT):Up()
        local c = sc._pos + MOUNT_OFFSET
        eyePos = setmetatable({x = c.x + n.x, y = c.y + n.y, z = c.z + n.z}, Vector)

        texts = {}
        start3d2d = 0
        hooks["PostDrawTranslucentRenderables"](false, false)

        if start3d2d == 0 then
            got[sc:GetNWEntity("TIV_OwnerVehicle")._name] = "(screen was culled, nothing painted)"
        else
            local line = "(no REL BRG painted)"
            for _, t in ipairs(texts) do
                if type(t) == "string" and t:find("^REL BRG:") then line = t end
            end
            local owner = sc:GetNWEntity("TIV_OwnerVehicle")._name
            local shared = env.TIV.Instruments.RadarData
            got[owner] = string.format("%s  [screen owner=%s, shared packet veh=%s]",
                line, owner, tostring(shared and shared.veh and shared.veh._name))
        end
    end
    return got
end

------------------------------------------------------------------------------
-- Checks
------------------------------------------------------------------------------
local failures = {}
local function check(name, cond, detail)
    print(string.format("[%s] %s%s", cond and "OK " or "BAD", name,
        detail and ("  -- " .. detail) or ""))
    if not cond then failures[#failures+1] = name end
end

print("Executed real file : " .. TARGET)
print(string.format("Lua runtime        : %s (%s)", _VERSION, jit and jit.version or "no jit"))
local cfg = TIV.Instruments.GetMonitorConfig(screenA)
print(string.format("GetMonitorConfig   : rot=%s scale=%s w=%s h=%s offset=%s", tostring(cfg and cfg.rot), tostring(cfg and cfg.scale), tostring(cfg and cfg.w), tostring(cfg and cfg.h), tostring(cfg and cfg.offset)))
print("jeep A             : at (-20000,0) facing +X, vortex dead AHEAD  -> expect REL BRG: 000 AHEAD")
print("jeep B             : at ( 20000,0) facing +X, vortex dead ASTERN -> expect REL BRG: 180 ASTERN")
print("")

local function runOrder(label, first, firstPos, second, secondPos)
    -- One vortex, but each vehicle's radar reports it from its own side, so the
    -- two packets carry different pos values -- exactly as the server sends them.
    clock = clock + 0.35
    deliver(first,  firstPos,  20000, 0)
    clock = clock + 0.35
    deliver(second, secondPos, 20000, 180)

    local got = renderEach()
    local a = got["A"] or "(screen A never drawn)"
    local b = got["B"] or "(screen B never drawn)"
    print(string.format("  packet order %-12s screen A: %-22s screen B: %s", label, a, b))
    check("order " .. label .. ": jeep A reads AHEAD",  a:find("AHEAD")  ~= nil, a)
    check("order " .. label .. ": jeep B reads ASTERN", b:find("180 ASTERN") ~= nil, b)
end

print("Both packets delivered, both orders:")
runOrder("A then B", jeepA, VORTEX_A, jeepB, VORTEX_B)
runOrder("B then A", jeepB, VORTEX_B, jeepA, VORTEX_A)

-- GetRadarData must not fall back to someone else's packet.
print("")
local outsider = { GetPos = function() return setmetatable({x=0,y=0,z=0}, Vector) end,
                   GetVehicle = function() return nil end, _valid = true }
local d = TIV.Instruments.GetRadarData(nil, outsider)
check("a player in no vehicle gets no data (not another jeep's)",
    d ~= nil and d.active == false, "active=" .. tostring(d and d.active))

local stale = TIV.Instruments.RadarData
check("last-received packet is still exposed for legacy readers",
    stale ~= nil and stale.veh ~= nil, "veh=" .. tostring(stale and stale.veh and stale.veh._name))

print("")
if #failures == 0 then
    print("RESULT: every screen shows its own vehicle's bearing, in both packet orders")
    os.exit(0)
else
    print(string.format("RESULT: %d check(s) FAILED", #failures))
    for _, f in ipairs(failures) do print("  - " .. f) end
    os.exit(1)
end
