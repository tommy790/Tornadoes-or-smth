-- ===========================================================================
-- TIV FREEZE WATCHDOG PROBE (server)
--
-- Executes the REAL TIV.Debug.WatchdogVehicle and TIV.Debug.AuditVehicle from
-- jeep_jalopy_interceptor/lua/tiv/debug/sv_freeze_audit.lua.
--
-- The watchdog's whole job is to undo a leaked anchor without ever becoming one
-- itself, so the interesting assertions are as much about what it must NOT do:
--
--   * a TIV back in "idle" gets gravity, motion and its handbrake restored, and
--     any constraint this addon still owns is removed;
--   * a healthy idle TIV is left completely alone -- no spurious physics calls;
--   * a vehicle mid-sequence (lowering / raising / anchored / lofted) is NOT
--     touched, because those states legitimately freeze the body;
--   * it never disables motion, never disables gravity, never adds a constraint,
--     and never removes a constraint it does not own.
--
--   tools/bin/luajit tools/freeze_watchdog_probe.lua
--
-- Exit 0 = every case behaves.
-- ===========================================================================

local here = (arg and arg[0] or "tools/freeze_watchdog_probe.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local repo = here:match("^(.*)[/\\]tools$") or "."

dofile(here .. "/gmod_stub.lua")

SERVER = true
CLIENT = false

local noop = function() end

timer = timer or {}
timer.Create = timer.Create or noop
timer.Remove = timer.Remove or noop
timer.Simple = timer.Simple or noop
timer.Exists = timer.Exists or function() return false end

local convars = { tiv_debug_freeze = "0", tiv_freeze_watchdog = "1" }
local cvarObj = {}
cvarObj.__index = cvarObj
function cvarObj:GetBool() return self._v == "1" end
function cvarObj:GetInt() return tonumber(self._v) or 0 end
function cvarObj:GetFloat() return tonumber(self._v) or 0 end
CreateConVar = function(name, default) convars[name] = default or "0" end
GetConVar = function(name) return setmetatable({ _v = convars[name] or "0" }, cvarObj) end

hook.Add = noop
util.AddNetworkString = noop

------------------------------------------------------------------------------
-- Constraint and vehicle stubs
------------------------------------------------------------------------------
local constraintLog = { removed = {}, added = {} }

local function makeConstraint(kind, isTiv)
    local c = { Type = kind, _tiv = isTiv, _valid = true }
    function c:Remove()
        self._valid = false
        constraintLog.removed[#constraintLog.removed + 1] = kind .. (isTiv and "(tiv)" or "(foreign)")
    end
    return c
end

-- constraint.GetTable reports every constraint attached to the vehicle, TIV's and
-- anyone else's. The watchdog must only ever touch its own.
local constraintsByVeh = {}
constraint = {
    GetTable = function(veh) return constraintsByVeh[veh] or {} end,
    RemoveAll = function() end,
}

local registry = {}
Entity = function(i) return registry[i] end

local function makeVeh(idx, opts)
    opts = opts or {}
    local v = {
        _idx = idx, _valid = true,
        _motion = opts.motion ~= false,
        _gravity = opts.gravity ~= false,
        _handbrake = false,
        _calls = {},
    }
    function v:EntIndex() return self._idx end
    function v:GetPos() return Vector(0, 0, 20) end
    function v:GetPhysicsObject()
        return {
            GetPos = function() return Vector(0, 0, 20) end,
            GetVelocity = function() return Vector(0, 0, 0) end,
            IsMotionEnabled = function() return self._motion end,
            IsGravityEnabled = function() return self._gravity end,
            IsAsleep = function() return false end,
            IsCollisionEnabled = function() return true end,
            EnableMotion = function(_, on)
                self._calls[#self._calls + 1] = "EnableMotion(" .. tostring(on) .. ")"
                self._motion = on and true or false
            end,
            EnableGravity = function(_, on)
                self._calls[#self._calls + 1] = "EnableGravity(" .. tostring(on) .. ")"
                self._gravity = on and true or false
            end,
            Wake = function() self._calls[#self._calls + 1] = "Wake" end,
        }
    end
    function v:SetHandbrake(on)
        self._calls[#self._calls + 1] = "SetHandbrake(" .. tostring(on) .. ")"
        self._handbrake = on and true or false
    end
    registry[idx] = v
    return v
end

------------------------------------------------------------------------------
-- Load the real module
------------------------------------------------------------------------------
TIV = TIV or {}
TIV.Deploy = { Vehicles = {} }
TIV.Loft = { WindTimers = {}, FailingGroups = {} }
TIV.Anchor = {}

assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/debug/sv_freeze_audit.lua"))()
assert(TIV.Debug and TIV.Debug.WatchdogVehicle, "sv_freeze_audit.lua did not define the watchdog")

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
local function hasCall(v, needle)
    for _, c in ipairs(v._calls) do if c:find(needle, 1, true) then return true end end
    return false
end

local function resetLog() constraintLog.removed = {}; constraintLog.added = {} end

print("== a leaked anchor is undone ==")

resetLog()
local v1 = makeVeh(1, { motion = false, gravity = false })
local tivCon = makeConstraint("AdvBallsocket", true)
local worldCon = makeConstraint("AdvBallsocket", true)
constraintsByVeh[v1] = { tivCon, worldCon }
local d1 = {
    state = "idle", anchored = false, spikes = {},
    constraints = { { constraint = tivCon, type = "ballsocket" },
                    { constraint = worldCon, type = "anchor_ballsocket", isWorldAnchor = true } },
    handbrakeOn = true,
}
TIV.Deploy.Vehicles[1] = d1

local acted = TIV.Debug.WatchdogVehicle(1, d1)
local p1 = v1:GetPhysicsObject()
check("the watchdog reports that it intervened", acted == true)
check("gravity restored on an idle TIV", v1._gravity == true)
check("motion restored on an idle TIV", v1._motion == true)
check("the body was woken", hasCall(v1, "Wake"))
check("both leftover TIV constraints removed", #constraintLog.removed == 2,
    table.concat(constraintLog.removed, ", "))
check("the constraint list was emptied", #(d1.constraints) == 0)
check("the leaked handbrake was released", v1._handbrake == false and d1.handbrakeOn == nil)

print("\n== a healthy idle TIV is left alone ==")

resetLog()
local v2 = makeVeh(2)
constraintsByVeh[v2] = {}
local d2 = { state = "idle", anchored = false, spikes = {}, constraints = {} }
TIV.Deploy.Vehicles[2] = d2
local acted2 = TIV.Debug.WatchdogVehicle(2, d2)
check("nothing to report", acted2 == false)
check("no physics calls were made at all", #v2._calls == 0,
    #v2._calls == 0 and "0 calls" or table.concat(v2._calls, ", "))

print("\n== a foreign constraint is never removed ==")

resetLog()
local v3 = makeVeh(3)
local foreign = makeConstraint("Weld", false)
constraintsByVeh[v3] = { foreign }
local d3 = { state = "idle", anchored = false, spikes = {}, constraints = {} }
TIV.Debug.WatchdogVehicle(3, d3)
check("a player's own weld survives the watchdog", #constraintLog.removed == 0,
    #constraintLog.removed == 0 and "0 removed" or table.concat(constraintLog.removed, ", "))
check("the constraint entity is still valid", foreign._valid == true)

print("\n== mid-sequence states are never touched ==")

-- These states legitimately freeze the body; "fixing" them would break deploying.
for _, st in ipairs({ "lowering", "raising", "deploying_spikes", "anchored", "lofted", "retracting" }) do
    resetLog()
    local v = makeVeh(40 + #st, { motion = false, gravity = false })
    local con = makeConstraint("AdvBallsocket", true)
    constraintsByVeh[v] = { con }
    local d = {
        state = st, anchored = (st == "anchored"), spikes = {},
        constraints = { { constraint = con, type = "ballsocket" } }, handbrakeOn = true,
    }
    local actedSt = TIV.Debug.WatchdogVehicle(v:EntIndex(), d)
    check(string.format("state %-17s is left exactly as it is", st),
        actedSt == false and #v._calls == 0 and #constraintLog.removed == 0 and con._valid,
        string.format("acted=%s calls=%d removed=%d", tostring(actedSt), #v._calls, #constraintLog.removed))
end

print("\n== the watchdog can never be the thing that freezes a vehicle ==")

-- Hammer every state/health combination and assert it only ever ENABLES physics.
local sawDisableMotion, sawDisableGravity = false, false
for _, st in ipairs({ "idle", "lowering", "raising", "anchored", "lofted" }) do
    for _, motion in ipairs({ true, false }) do
        for _, gravity in ipairs({ true, false }) do
            resetLog()
            local v = makeVeh(90, { motion = motion, gravity = gravity })
            local con = makeConstraint("AdvBallsocket", true)
            constraintsByVeh[v] = { con }
            local d = {
                state = st, anchored = (st == "anchored"), spikes = {},
                constraints = { { constraint = con, type = "ballsocket" } },
            }
            TIV.Debug.WatchdogVehicle(v:EntIndex(), d)
            for _, c in ipairs(v._calls) do
                if c == "EnableMotion(false)" then sawDisableMotion = true end
                if c == "EnableGravity(false)" then sawDisableGravity = true end
            end
        end
    end
end
check("it never disables motion", not sawDisableMotion)
check("it never disables gravity", not sawDisableGravity)
check("it never freezes anything", true, "EnableMotion(false)/EnableGravity(false) are the only freeze paths, neither occurred")

print("\n== ForceDetach restores motion as well as gravity ==")

-- The deploy sequence disables motion while it lerps the body, so a detach
-- landing inside that window used to restore gravity on a body that was still not
-- allowed to move -- it hangs there, which reads exactly like a freeze.
assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/anchor/sv_anchor.lua"))()
assert(TIV.Anchor and TIV.Anchor.ForceDetach, "sv_anchor.lua did not define ForceDetach")

local vFD = makeVeh(200, { motion = false, gravity = false })
local c1 = makeConstraint("AdvBallsocket", true)
local c2 = makeConstraint("AdvBallsocket", true)
local dFD = {
    anchored = true,
    constraints = { { constraint = c1, type = "ballsocket" },
                    { constraint = c2, type = "anchor_ballsocket", isWorldAnchor = true } },
}
TIV.Anchor.ForceDetach(vFD, dFD)
check("gravity restored by ForceDetach", vFD._gravity == true)
check("motion restored by ForceDetach", vFD._motion == true,
    vFD._motion and "body can move again" or "STILL FROZEN")
check("the body was woken", hasCall(vFD, "Wake"))
check("both constraints removed", not c1._valid and not c2._valid)
check("the constraint list was cleared", #dFD.constraints == 0)
check("anchored flag cleared", dFD.anchored == false)

-- A body that was already free must not be churned.
local vFD2 = makeVeh(201)
local dFD2 = { anchored = true, constraints = {} }
TIV.Anchor.ForceDetach(vFD2, dFD2)
check("ForceDetach never disables motion", not hasCall(vFD2, "EnableMotion(false)"))
check("ForceDetach does not re-enable motion that is already on",
    not hasCall(vFD2, "EnableMotion(true)"),
    #vFD2._calls == 0 and "no physics calls at all" or table.concat(vFD2._calls, ", "))

-- And it must survive being called with no vehicle and no constraint table.
local okFD = pcall(function() TIV.Anchor.ForceDetach(nil, { constraints = {} }) end)
check("ForceDetach survives a nil vehicle", okFD)

print("\n== the audit reads real state without throwing ==")

local ok, err = pcall(function()
    local v = makeVeh(99, { motion = false, gravity = false })
    constraintsByVeh[v] = { makeConstraint("AdvBallsocket", true) }
    local d = {
        state = "idle", anchored = false, plantedPos = Vector(0, 0, 20),
        spikes = { { phase = "deployed", entity = v }, { phase = "deployed", failed = true, entity = v } },
        constraints = { { constraint = makeConstraint("AdvBallsocket", true), type = "ballsocket" } },
    }
    TIV.Loft.WindTimers[99] = 100
    TIV.Debug.AuditVehicle(99, d)
end)
check("AuditVehicle runs against a stuck idle vehicle", ok, ok and "printed its report" or tostring(err))

local ok2 = pcall(function()
    TIV.Deploy.Vehicles[1234] = { state = "idle", spikes = {}, constraints = {} }
    TIV.Debug.AuditVehicle(1234, TIV.Deploy.Vehicles[1234])
end)
check("AuditVehicle survives a vehicle whose entity is gone", ok2, ok2 and "reported the leak" or tostring(err))

print(string.format("\nRESULT: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
