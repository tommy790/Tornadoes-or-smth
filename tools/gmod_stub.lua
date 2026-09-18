-- GMod API stub shared by tools/radar_probe.py (via lupa) and
-- tools/radar_probe_lua.lua (via real LuaJIT). Keep it in sync: it is the
-- single source of truth for both.
local sin, cos, rad = math.sin, math.cos, math.rad

---------------------------------------------------------------- Vector ------
local Vector = {}
Vector.__index = Vector
Vector.__tostring = function(v)
    return string.format("Vector(%.3f, %.3f, %.3f)", v.x, v.y, v.z)
end
Vector.__add = function(a, b) return setmetatable({x=a.x+b.x, y=a.y+b.y, z=a.z+b.z}, Vector) end
Vector.__sub = function(a, b) return setmetatable({x=a.x-b.x, y=a.y-b.y, z=a.z-b.z}, Vector) end
Vector.__mul = function(a, b)
    if type(b) == "table" then
        return setmetatable({x=a.x*b.x, y=a.y*b.y, z=a.z*b.z}, Vector)
    end
    return setmetatable({x=a.x*b, y=a.y*b, z=a.z*b}, Vector)
end
Vector.__div = function(a, b) return setmetatable({x=a.x/b, y=a.y/b, z=a.z/b}, Vector) end
Vector.__unm = function(a) return setmetatable({x=-a.x, y=-a.y, z=-a.z}, Vector) end

function Vector:Dot(o) return self.x*o.x + self.y*o.y + self.z*o.z end
function Vector:Length() return math.sqrt(self:Dot(self)) end
function Vector:LengthSqr() return self:Dot(self) end
function Vector:GetNormalized()
    local l = self:Length()
    if l == 0 then return setmetatable({x=0, y=0, z=0}, Vector) end
    return setmetatable({x=self.x/l, y=self.y/l, z=self.z/l}, Vector)
end
function Vector:Cross(o)
    return setmetatable({
        x = self.y*o.z - self.z*o.y,
        y = self.z*o.x - self.x*o.z,
        z = self.x*o.y - self.y*o.x,
    }, Vector)
end
Vector.Len = Vector.Length

_G.__newvector = function(x, y, z)
    return setmetatable({x = x or 0, y = y or 0, z = z or 0}, Vector)
end
setmetatable(Vector, { __call = function(_, x, y, z) return _G.__newvector(x, y, z) end })
_G.Vector = Vector

----------------------------------------------------------------- Angle ------
local Angle = {}
Angle.__index = Angle
Angle.__tostring = function(a)
    return string.format("Angle(%.2f, %.2f, %.2f)", a.p, a.y, a.r)
end

-- Locals are rp/ry/rr on purpose: naming one `y` would shadow the `y`
-- parameter of __newvector and silently zero that component.
function Angle:Forward()
    local rp, ry = rad(self.p), rad(self.y)
    return _G.__newvector(cos(rp)*cos(ry), cos(rp)*sin(ry), sin(rp))
end
function Angle:Right()
    local rp, ry, rr = rad(self.p), rad(self.y), rad(self.r)
    return _G.__newvector(
         sin(ry)*cos(rr) + cos(ry)*sin(rp)*sin(rr),
        -sin(ry)*sin(rr) - cos(ry)*cos(rp)*cos(rr),
        -cos(rp)*sin(rr)
    )
end
function Angle:Up()
    local rp, ry, rr = rad(self.p), rad(self.y), rad(self.r)
    return _G.__newvector(
        -sin(ry)*sin(rr) + cos(ry)*sin(rp)*cos(rr),
         sin(ry)*cos(rr) + cos(ry)*sin(rp)*sin(rr),
         cos(rp)*cos(rr)
    )
end

_G.__newangle = function(p, y, r)
    return setmetatable({p = p or 0, y = y or 0, r = r or 0}, Angle)
end
setmetatable(Angle, { __call = function(_, p, y, r) return _G.__newangle(p, y, r) end })
_G.Angle = Angle

-- parent:LocalToWorldAngles(child) -- Source ZXY order, +pitch = nose up
_G.__compose = function(parent, child)
    local function rot(a, v)
        local rp, ry, rr = rad(a.p), rad(a.y), rad(a.r)
        local vx, vy, vz = v.x, v.y, v.z
        local x1, y1, z1 = vx, cos(rr)*vy - sin(rr)*vz, sin(rr)*vy + cos(rr)*vz
        local x2, y2, z2 = cos(rp)*x1 + sin(rp)*z1, y1, -sin(rp)*x1 + cos(rp)*z1
        return _G.__newvector(cos(ry)*x2 - sin(ry)*y2, sin(ry)*x2 + cos(ry)*y2, z2)
    end
    local out = _G.__newangle(0, 0, 0)
    out.Forward = function() return rot(parent, child:Forward()) end
    out.Right   = function() return rot(parent, child:Right()) end
    out.Up      = function() return rot(parent, child:Up()) end
    return out
end

------------------------------------------------- recording draw surface ------
_G.__calls  = {}
_G.__curcol = { r = 255, g = 255, b = 255, a = 255 }
_G.__texts  = {}

surface = {
    SetDrawColor = function(r, g, b, a) _G.__curcol = { r = r, g = g, b = b, a = a } end,
    DrawRect = function(x, y, w, h)
        _G.__calls[#_G.__calls + 1] = {
            op = "rect", x = x, y = y, w = w, h = h,
            r = _G.__curcol.r, g = _G.__curcol.g, b = _G.__curcol.b,
        }
    end,
    DrawLine = function(x0, y0, x1, y1)
        _G.__calls[#_G.__calls + 1] = { op = "line", x = x0, y = y0, x2 = x1, y2 = y1 }
    end,
    DrawOutlinedRect = function() end,
    SetFont = function() end,
    SetTextColor = function() end,
    SetTextPos = function() end,
    DrawText = function() end,
    GetTextSize = function() return 10, 10 end,
}

draw = {
    SimpleText = function(txt, font, x, y, col, ax, ay)
        _G.__texts[#_G.__texts + 1] = { txt = txt, x = x, y = y }
    end,
}

local function noop() end
render = setmetatable({}, { __index = function() return noop end })
cam    = setmetatable({}, { __index = function() return noop end })
net    = setmetatable({}, { __index = function() return noop end })
util   = { AddNetworkString = noop, IsValidModel = function() return true end }
hook   = { Add = noop, Run = noop }
ents   = { FindByClass = function() return {} end, GetAll = function() return {} end }
player = { GetAll = function() return {} end }

function CurTime() return 100 end
function RealTime() return 100 end
function SysTime() return 100 end
function IsValid(e) return e ~= nil and e ~= false end
function LocalPlayer() return nil end
function EyePos() return _G.__newvector(0, 0, 0) end
function Color(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function istable(v) return type(v) == "table" end
function isentity(v) return type(v) == "table" and v.__isentity == true end
function isfunction(v) return type(v) == "function" end
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function isbool(v) return type(v) == "boolean" end

TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT = 0, 1, 2
TEXT_ALIGN_TOP, TEXT_ALIGN_BOTTOM = 3, 4
STENCIL_ALWAYS, STENCIL_EQUAL, STENCIL_REPLACE, STENCIL_KEEP = 0, 3, 5, 1

-- GMod ships LuaJIT's bit library, math.atan2, math.Clamp and math.Round;
-- stock Lua 5.x has none of them.
bit = bit or {
    band = function(a, b) return math.floor(a) & math.floor(b) end,
    bor  = function(a, b) return math.floor(a) | math.floor(b) end,
}
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
math.Clamp = math.Clamp or function(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
math.Round = math.Round or function(v, d)
    local m = 10 ^ (d or 0)
    return math.floor(v * m + 0.5) / m
end

---------------------------------------------------------- entity stub ------
_G.__makeent = function(pos, ang, model)
    local e = {
        __isentity = true, _pos = pos, _ang = ang,
        _model = model or "models/kobilica/wiremonitorsmall.mdl",
    }
    function e:GetPos() return self._pos end
    function e:GetAngles() return self._ang end
    function e:GetForward() return self._ang:Forward() end
    function e:GetRight() return self._ang:Right() end
    function e:GetUp() return self._ang:Up() end
    function e:GetModel() return self._model end
    function e:GetModelScale() return 1.0 end
    function e:EntIndex() return 1 end
    function e:LocalToWorld(v)
        local a = self._ang
        return self._pos + a:Right() * v.x + a:Forward() * v.y + a:Up() * v.z
    end
    function e:LocalToWorldAngles(a) return _G.__compose(self._ang, a) end
    function e:GetNWBool() return false end
    function e:GetNWEntity() return nil end
    return e
end


-- Convars. The harness has no real cvar system; returning 0 makes the TIV
-- resolvers fall through to TIV.Config, which is what the probes want.
if GetConVar == nil then
    GetConVar = function() return { GetString = function() return "0" end } end
end
