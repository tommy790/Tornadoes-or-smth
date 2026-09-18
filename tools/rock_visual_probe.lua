-- ===========================================================================
-- TIV VISUAL ROCKING PROBE (client)
--
-- Executes the REAL TIV rocking client from
-- jeep_jalopy_interceptor/lua/tiv/anchor/cl_rock.lua frame by frame and asserts
-- the properties that stop this from ever becoming the mid-air freeze it
-- replaces:
--
--   * the vehicle's physics body is NEVER touched -- no SetPos, SetAngles,
--     SetVelocity, EnableMotion, EnableGravity, Freeze or constraint call;
--   * SetRenderAngles is the only mutation, and it is cleared with nil once the
--     tilt settles, so GetAngles() goes back to the real transform;
--   * the tilt cannot accumulate, even though GMod's SetRenderAngles makes
--     GetAngles() return the override -- the stub reproduces that shadowing on
--     purpose, so a version of this file that read veh:GetAngles() would drift
--     and fail here;
--   * the lean is bounded, arrives smoothly rather than snapping, grows with
--     stress, and is independent per vehicle;
--   * when the server stops reporting -- tornado over, lofted, retracted, entity
--     removed, or the feature switched off -- the override is dropped.
--
--   tools/bin/luajit tools/rock_visual_probe.lua
--
-- Exit 0 = every property holds.
-- ===========================================================================

local here = (arg and arg[0] or "tools/rock_visual_probe.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local repo = here:match("^(.*)[/\\]tools$") or "."
local TARGET = repo .. "/jeep_jalopy_interceptor/lua/tiv/anchor/cl_rock.lua"

dofile(here .. "/gmod_stub.lua")

local bad = dofile(here .. "/radar_selftest.lua")
if #bad > 0 then
    io.stderr:write("FAIL: GMod stub does not match Source conventions:\n")
    for _, b in ipairs(bad) do io.stderr:write("    " .. b .. "\n") end
    os.exit(1)
end

CLIENT = true
SERVER = false

------------------------------------------------------------------------------
-- Convars the module reads, mutable so the probe can flip them.
------------------------------------------------------------------------------
local cvars = {
    tiv_visual_rock = "1",
    tiv_visual_rock_scale = "1",
    tiv_visual_rock_debug = "0",
}
local cvarObj = {}
cvarObj.__index = cvarObj
function cvarObj:GetBool() return self._v == "1" or self._v == "true" end
function cvarObj:GetFloat() return tonumber(self._v) or 0 end
function cvarObj:GetInt() return tonumber(self._v) or 0 end
function cvarObj:GetString() return self._v end

CreateClientConVar = function(name, default) cvars[name] = default or "0" end
CreateConVar = CreateClientConVar
GetConVar = function(name) return setmetatable({ _v = cvars[name] or "0" }, cvarObj) end

------------------------------------------------------------------------------
-- Captured hooks and net receivers
------------------------------------------------------------------------------
local hooks = {}
hook.Add = function(name, id, fn) hooks[name] = fn end

local receivers = {}
net.Receive = function(name, fn) receivers[name] = fn end

local entityRegistry = {}
Entity = function(i) return entityRegistry[i] end

local clock = 0
CurTime = function() return clock end
local frameDt = 1 / 60
FrameTime = function() return frameDt end

------------------------------------------------------------------------------
-- Vehicle stub
--
-- GetAngles() deliberately returns the render override when one is set, exactly
-- as the GMod wiki documents: "Entity:GetAngles() will return the value set by
-- this function until the override is disabled." Anything that reads GetAngles()
-- to build the next frame's tilt will compound against this.
------------------------------------------------------------------------------
local FORBIDDEN = { "SetPos", "SetAngles", "SetVelocity", "SetAngleVelocity", "Freeze",
                    "EnableMotion", "EnableGravity", "SetOwner", "SetCollisionGroup" }

local function makeVeh(idx, yaw)
    local physAng = Angle(0, yaw or 0, 0)
    local v = {
        _idx = idx, _valid = true,
        _physAng = physAng,
        _physPos = Vector(0, 0, 20),
        _renderAng = nil,
        _renderOrigin = nil,
        _renderSetCount = 0,
        _renderClearCount = 0,
        _calls = {},
    }
    function v:EntIndex() return self._idx end
    function v:GetPhysicsObject()
        return {
            GetAngles = function() return self._physAng end,
            GetPos = function() return self._physPos end,
            IsMotionEnabled = function() return true end,
            IsGravityEnabled = function() return true end,
        }
    end
    -- The physics body is the truth; the render overrides shadow the accessors.
    -- GMod documents both: SetRenderAngles makes GetAngles() return the override,
    -- and SetRenderOrigin makes GetPos() return it, "until the override is
    -- disabled". Anything reading either one to build the next frame compounds.
    function v:GetAngles() return self._renderAng or self._physAng end
    function v:GetPos() return self._renderOrigin or self._physPos end
    function v:SetRenderAngles(a)
        if a == nil then
            self._renderAng = nil
            self._renderClearCount = self._renderClearCount + 1
        else
            self._renderAng = a
            self._renderSetCount = self._renderSetCount + 1
        end
    end
    function v:SetRenderOrigin(o)
        if o == nil then
            self._renderOrigin = nil
            self._originClearCount = (self._originClearCount or 0) + 1
        else
            self._renderOrigin = o
            self._originSetCount = (self._originSetCount or 0) + 1
        end
    end
    for _, name in ipairs(FORBIDDEN) do
        v[name] = function(self, ...) self._calls[#self._calls + 1] = name; return self end
    end
    entityRegistry[idx] = v
    return v
end

-- Rotate the actual physics body, as the loft system tumbling the vehicle would.
local function tumble(v, dp, dr)
    v._physAng = Angle(v._physAng.p + dp, v._physAng.y, v._physAng.r + dr)
end


------------------------------------------------------------------------------
-- Frame stepping and packet delivery
------------------------------------------------------------------------------
local function think()
    clock = clock + frameDt
    if hooks["Think"] then hooks["Think"]() end
end

-- Mirrors sv_rock.lua's SendRecords exactly.
local netQueue, netPos = {}, 0
local function startPacket(records)
    netQueue, netPos = {}, 0
    local push = function(v) netQueue[#netQueue + 1] = v end
    push(#records)
    for _, r in ipairs(records) do
        push(r.idx)
        push(math.Clamp(math.Round(r.stress * 255), 0, 255))
        push(math.Clamp(math.Round(r.pitchN * 100), -100, 100))
        push(math.Clamp(math.Round(r.rollN * 100), -100, 100))
        push(math.Clamp(r.deployed, 0, 63))
        push(math.Clamp(r.failed, 0, 63))
        push(math.Clamp(math.Round((r.windX or 0) * 100), -100, 100))
        push(math.Clamp(math.Round((r.windY or 0) * 100), -100, 100))
    end
end
local readUInt = function() netPos = netPos + 1 return netQueue[netPos] end
net.ReadUInt = readUInt
net.ReadInt = readUInt

local function deliver()
    assert(receivers["TIV_RockData"], "cl_rock.lua did not register TIV_RockData")
    receivers["TIV_RockData"]()
end

local function packet(idx, stress, pitchN, rollN, deployed, failed, windX, windY)
    startPacket({ { idx = idx, stress = stress, pitchN = pitchN, rollN = rollN,
                    deployed = deployed, failed = failed, windX = windX, windY = windY } })
    deliver()
end

-- The server rebroadcasts every 0.1 s, so a probe that sends one packet and then
-- runs the model for three seconds is testing the stale timeout, not the rocking.
-- stream[] holds the live records; run() rebroadcasts them on the real cadence.
local stream = {}
local SEND_EVERY = 6  -- frames, == 0.1 s at 60 fps

local function setStream(idx, stress, pitchN, rollN, deployed, failed, windX, windY)
    if stress == nil then
        stream[idx] = nil
    else
        stream[idx] = { idx = idx, stress = stress, pitchN = pitchN, rollN = rollN,
                        deployed = deployed, failed = failed, windX = windX, windY = windY }
    end
end

local function broadcastStream()
    local recs = {}
    for _, r in pairs(stream) do recs[#recs + 1] = r end
    if #recs > 0 then
        startPacket(recs)
        deliver()
    end
end

local function run(frames)
    for i = 1, frames do
        if i % SEND_EVERY == 1 then broadcastStream() end
        think()
    end
end

------------------------------------------------------------------------------
-- Load the real module
------------------------------------------------------------------------------
-- Normally created by tiv/config/sh_config.lua, which this module does not use.
TIV = TIV or {}

local chunk, lerr = loadfile(TARGET)
if not chunk then io.stderr:write("FAILED TO LOAD: " .. tostring(lerr) .. "\n") os.exit(1) end
local ok, rerr = pcall(chunk)
if not ok then io.stderr:write("RUNTIME ERROR ON LOAD: " .. tostring(rerr) .. "\n") os.exit(1) end
assert(hooks["Think"], "cl_rock.lua did not register a Think hook")

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

local function pitchOf(v) return v._renderAng and (v._renderAng.p - v._physAng.p) or 0 end
local function rollOf(v) return v._renderAng and (v._renderAng.r - v._physAng.r) or 0 end

print("== it only ever touches the render override ==")

local v1 = makeVeh(11, 0)
setStream(11, 0.9, 1.0, 0.0, 4, 0, 1.0, 0.0)
run(120)

check("the vehicle model was tilted", pitchOf(v1) > 1.0, string.format("pitch offset %+.2f deg", pitchOf(v1)))
check("SetRenderAngles was used", v1._renderSetCount > 0, v1._renderSetCount .. " calls")
check("the physics body was never written to", #v1._calls == 0,
    #v1._calls == 0 and "no SetPos/SetAngles/SetVelocity/EnableMotion/EnableGravity/Freeze"
                      or ("FORBIDDEN CALLS: " .. table.concat(v1._calls, ",")))

print("\n== the tilt cannot accumulate ==")

-- 3000 frames is 50 seconds of a violent gust with the body being tumbled by the
-- physics at the same time. Because the stub hands the override back through
-- GetAngles(), an implementation that read GetAngles() to build the next frame's
-- tilt would compound here and blow straight through the bounds.
local earlyMax, lateMax = 0, 0
for i = 1, 3000 do
    if i % SEND_EVERY == 1 then broadcastStream() end
    tumble(v1, 0.7, -0.5)
    think()
    local p = math.abs(pitchOf(v1))
    if i <= 600 then
        if p > earlyMax then earlyMax = p end
    elseif i > 2400 then
        if p > lateMax then lateMax = p end
    end
end
check("pitch stays bounded over 3000 frames", earlyMax <= 7.0 and lateMax <= 7.0,
    string.format("max |pitch| early=%.3f late=%.3f (limit 6.8)", earlyMax, lateMax))
-- The real drift test: the envelope of the last 10 seconds must match the first,
-- not grow. Comparing two instantaneous samples would just be reading the wobble.
check("the late envelope matches the early one, so nothing is drifting",
    math.abs(lateMax - earlyMax) < 0.25,
    string.format("early=%.3f late=%.3f, difference %.3f deg", earlyMax, lateMax, math.abs(lateMax - earlyMax)))
check("the render transform tracks the physics body, not the last override",
    v1._renderAng ~= nil and math.abs(v1._renderAng.p - v1._physAng.p) < 7.0,
    string.format("render p=%.1f vs physics p=%.1f", v1._renderAng and v1._renderAng.p or 0, v1._physAng.p))

print("\n== bounded, smooth, and scaled by stress ==")

local v2 = makeVeh(12, 0)
setStream(12, 1.0, 1.0, 1.0, 4, 0, 1.0, 0.3)
local prev, worstJump, halfAt = 0, 0, nil
local settledGuess = 4.0
for i = 1, 300 do
    if i % SEND_EVERY == 1 then broadcastStream() end
    think()
    local p = pitchOf(v2)
    local jump = math.abs(p - prev)
    if jump > worstJump then worstJump = jump end
    if halfAt == nil and p >= settledGuess * 0.5 then halfAt = i end
    prev = p
end
check("the lean builds over several frames instead of snapping", halfAt ~= nil and halfAt > 3,
    string.format("reached half the lean on frame %s", tostring(halfAt)))
check("no single frame moves the model by more than a quarter of the lean",
    worstJump < settledGuess * 0.25,
    string.format("worst per-frame change %.4f deg vs %.2f deg limit", worstJump, settledGuess * 0.25))
check("full stress produces a lean of a few degrees, not a tip-over",
    math.abs(pitchOf(v2)) > 1.0 and math.abs(pitchOf(v2)) <= 7.0,
    string.format("pitch now %+.2f deg", pitchOf(v2)))

local vLow = makeVeh(13, 0)
setStream(13, 0.25, 1.0, 1.0, 4, 0, 1.0, 0.3)
run(300)
check("light stress leans less than full stress", math.abs(pitchOf(vLow)) < math.abs(pitchOf(v2)) * 0.75,
    string.format("stress 0.25 -> %+.2f deg vs stress 1.0 -> %+.2f deg", pitchOf(vLow), pitchOf(v2)))

local vFail = makeVeh(14, 0)
local vHold = makeVeh(15, 0)
setStream(14, 0.6, 1.0, 0.0, 1, 3, 1.0, 0.0)
setStream(15, 0.6, 1.0, 0.0, 4, 0, 1.0, 0.0)
run(300)
check("losing anchors makes the same wind move the body more",
    math.abs(pitchOf(vFail)) > math.abs(pitchOf(vHold)),
    string.format("1 live -> %+.2f deg vs 4 live -> %+.2f deg", pitchOf(vFail), pitchOf(vHold)))

print("\n== multiplayer: vehicles are independent ==")

local vA = makeVeh(21, 0)
local vB = makeVeh(22, 0)
setStream(21, 0.85, 1.0, 0.0, 4, 0, 1.0, 0.0)
setStream(22, 0.0, 0.0, 0.0, 4, 0)
run(200)
check("the stressed TIV leans", math.abs(pitchOf(vA)) > 1.0, string.format("A pitch %+.2f", pitchOf(vA)))
check("the calm TIV next to it does not", vB._renderAng == nil and #vB._calls == 0,
    string.format("B override set %d time(s), cleared %d", vB._renderSetCount, vB._renderClearCount))

print("\n== reset after the intercept ==")

-- The server stops reporting: the tornado ended, or the vehicle lofted out of its
-- anchors. No more packets arrive at all.
setStream(21, nil)
local framesToSettle = 0
for i = 1, 900 do
    think()
    if vA._renderAng == nil then
        framesToSettle = i
        break
    end
end
check("the override is cleared with nil once the tilt settles", vA._renderAng == nil,
    string.format("cleared after %d frames (~%.1f s); clear called %d time(s)",
        framesToSettle, framesToSettle * frameDt, vA._renderClearCount))
check("GetAngles() reports the real transform again",
    vA._renderAng == nil and vA:GetAngles() == vA._physAng)
check("it eased out over time rather than snapping", framesToSettle > 15,
    string.format("took %d frames (~%.2f s)", framesToSettle, framesToSettle * frameDt))
check("the physics body was still untouched throughout", #vA._calls == 0)

-- Explicit zero-stress record, which is what the server sends on transition.
local vC = makeVeh(23, 0)
setStream(23, 0.9, 1.0, 0.5, 4, 0, 1.0, 0.0)
run(200)
check("vehicle is tilted before the all-clear", vC._renderAng ~= nil,
    string.format("pitch %+.2f", pitchOf(vC)))
setStream(23, 0.0, 0.0, 0.0, 0, 0)
run(400)
check("an explicit all-clear packet relaxes the model", vC._renderAng == nil)

print("\n== entity lifecycle and the off switch ==")

local vD = makeVeh(24, 0)
setStream(24, 0.9, 1.0, 0.0, 4, 0, 1.0, 0.0)
run(120)
check("tilted before removal", vD._renderAng ~= nil)
setStream(24, nil)
entityRegistry[24] = nil
if hooks["EntityRemoved"] then hooks["EntityRemoved"](vD) end
think()
check("removing the vehicle drops its tracking", vD._renderAng == nil)

local vE = makeVeh(25, 0)
setStream(25, 0.9, 1.0, 0.0, 4, 0, 1.0, 0.0)
run(120)
check("tilted before the convar flips", vE._renderAng ~= nil)
cvars["tiv_visual_rock"] = "0"
think()
check("disabling tiv_visual_rock clears the override", vE._renderAng == nil)
think()
check("a disabled system leaves the physics alone", #vE._calls == 0)

-- EntIndex reuse: a different entity takes an index the rocker is still tracking.
cvars["tiv_visual_rock"] = "1"
local vF = makeVeh(26, 0)
setStream(26, 0.9, 1.0, 0.0, 4, 0, 1.0, 0.0)
run(120)
check("first occupant of the index is tilted", vF._renderAng ~= nil)
local vG = makeVeh(26, 0)   -- overwrites the registry entry, same EntIndex
run(2)
check("reusing the EntIndex clears the old entity's override", vF._renderAng == nil)
check("the physics of neither occupant was touched", #vF._calls == 0 and #vG._calls == 0)

print("\n== the body shift ==")

local function shiftOf(v)
    if not v._renderOrigin then return nil end
    local d = v._renderOrigin - v._physPos
    return math.sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
end

local vS = makeVeh(31, 0)
setStream(31, 1.0, 1.0, 0.0, 4, 0, 1.0, 0.0)
run(200)
local sh = shiftOf(vS)
check("the model is shifted as well as tilted", sh ~= nil and sh > 0.5,
    sh and string.format("%.2f units", sh) or "no origin override")
check("the shift stays within a couple of Source units", sh ~= nil and sh <= 3.0,
    sh and string.format("%.2f units (MAX_SHIFT 2.5 + squat)", sh) or "n/a")

-- The stub shadows GetPos() with the render origin, so a shift that fed itself
-- back would run away here exactly as the tilt would.
--
-- Deliberately run at IDENTITY angles. gmod_stub's Angle:Up() is not a reliable
-- basis away from (0,0,0) -- at (0,90,0) it returns a vector of length 1.414 --
-- so converting a local offset to world space through a tumbled body measures the
-- stub's error, not the module's. The tilt tests above DO tumble, because they
-- compare stored angle fields and never touch the basis.
local earlyS, lateS = 0, 0
for i = 1, 3000 do
    if i % SEND_EVERY == 1 then broadcastStream() end
    think()
    local m = shiftOf(vS) or 0
    if i <= 600 then
        if m > earlyS then earlyS = m end
    elseif i > 2400 then
        if m > lateS then lateS = m end
    end
end
check("the shift does not accumulate over 3000 frames", math.abs(lateS - earlyS) < 0.01,
    string.format("early=%.4f late=%.4f units", earlyS, lateS))
check("the shift converges on the exact predicted magnitude", math.abs(lateS - math.sqrt(2.5^2 + 0.875^2)) < 0.01,
    string.format("%.4f units vs predicted %.4f (MAX_SHIFT 2.5, squat 0.875)",
        lateS, math.sqrt(2.5^2 + 0.875^2)))

setStream(31, nil)
for _ = 1, 900 do
    think()
    if vS._renderOrigin == nil then break end
end
check("the origin override is cleared with nil on settle", vS._renderOrigin == nil,
    string.format("cleared after the relax; SetRenderOrigin(nil) called %d time(s)", vS._originClearCount or 0))
check("GetPos() reports the real position again", vS:GetPos() == vS._physPos)

local vNS = makeVeh(32, 0)
cvars["tiv_visual_rock_shift"] = "0"
setStream(32, 1.0, 1.0, 0.0, 4, 0, 1.0, 0.0)
run(200)
check("tiv_visual_rock_shift 0 leaves the tilt in place", math.abs(pitchOf(vNS)) > 1.0,
    string.format("pitch %+.2f", pitchOf(vNS)))
check("tiv_visual_rock_shift 0 sets no origin override", vNS._renderOrigin == nil,
    string.format("SetRenderOrigin called %d time(s)", vNS._originSetCount or 0))
cvars["tiv_visual_rock_shift"] = "1"

-- The shift is applied on top of the PHYSICS position, so measure what it would
-- do to the one thing in this addon that reads veh:GetPos(): the radar blip.
-- Executed against the real DrawRadarScreen rather than estimated.
do
    local okLoad, loadErr = pcall(function()
        TIV_HEADING_OFFSET_DEG = "0"
        TIV_RADAR_BLIP_OFFSET = "0"
        assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/config/sh_config.lua"))()
        assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/instruments/cl_radar_screen.lua"))()
    end)
    if not okLoad then
        check("radar impact of the shift could be measured", false, "could not load the radar: " .. tostring(loadErr))
    else
        local function blipWith(vpos)
            local rv = {
                GetPos = function() return vpos end,
                GetForward = function() return Vector(1, 0, 0) end,
                GetRight = function() return Vector(0, -1, 0) end,
                EntIndex = function() return 77 end,
            }
            _G.__calls = {}
            TIV.Instruments.DrawRadarScreen({ GetPos = function() return Vector(0,0,20) end }, rv, {
                active = true, veh = rv, pos = Vector(12000, 0, 0), heading = Vector(1, 0, 0),
                speedMPH = 30, coreRadius = 600, outerRadius = 3500, dist = 12000,
                bearing = 0, eta = 10, impactType = "side", waypoints = {},
                touchingGround = false, rotationDirection = 0, rotationSpeed = 0,
                receivedAt = CurTime(),
            })
            for _, c in ipairs(_G.__calls) do
                if c.op == "rect" and c.w == 6 and c.h == 6 then return c.x, c.y end
            end
            return nil
        end
        local x0, y0 = blipWith(Vector(0, 0, 20))
        -- Worst case: the whole MAX_SHIFT budget applied along one axis.
        local x1, y1 = blipWith(Vector(2.5, 0, 20))
        local dx = math.abs((x1 or 0) - (x0 or 0))
        check("the shift moves the radar blip by a fraction of a pixel", x0 ~= nil and dx < 0.1,
            x0 and string.format("%.4f px at 12000u range (blip is 6 px wide)", dx) or "no blip drawn")
    end
end

print("\n== forbidden physics calls, across every vehicle in this probe ==")
local totalForbidden = 0
for _, v in pairs(entityRegistry) do totalForbidden = totalForbidden + #v._calls end
check("no vehicle in this probe ever had its physics written to", totalForbidden == 0,
    totalForbidden == 0 and "0 forbidden calls across all vehicles" or (totalForbidden .. " forbidden calls"))

print(string.format("\nRESULT: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
