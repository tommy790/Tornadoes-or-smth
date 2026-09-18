-- ===========================================================================
-- TIV VEHICLE DETECTION PROBE
--
-- Exercises the REAL TIV.IsSupportedVehicle from
-- jeep_jalopy_interceptor/lua/tiv/config/sh_config.lua over a matrix of actual
-- GMod vehicle classes and models, and asserts that only things which can carry
-- the TIV armour/spike/screen upgrades are treated as interceptors.
--
-- Regression covered: `ent:IsVehicle() then return true` used to short-circuit
-- the whole function, so every vehicle on the map qualified -- airboats,
-- prisoner pods, and the seats of unrelated jeeps. The radar and HUD then
-- attached to whichever one the player happened to be sitting in.
--
--   tools/bin/luajit tools/vehicle_detection_probe.lua
--
-- Exit 0 = every case classified as expected.
-- ===========================================================================

local here = (arg and arg[0] or "tools/vehicle_detection_probe.lua"):match("^(.*)[/\\][^/\\]*$") or "."
local repo = here:match("^(.*)[/\\]tools$") or "."
local TARGET = repo .. "/jeep_jalopy_interceptor/lua/tiv/config/sh_config.lua"

------------------------------------------------------------------------------
-- Minimal entity stub: only what IsSupportedVehicle touches.
------------------------------------------------------------------------------
local function makeEnt(class, model, opts)
    opts = opts or {}
    local e = {
        _class = class or "prop_physics",
        _model = model or "",
        _nw = {},
        IsTIVVehicle = opts.IsTIVVehicle,
        _TIVConfig = opts._TIVConfig,
        TIV_HasArmor = opts.TIV_HasArmor,
        TIV_Controller = opts.TIV_Controller,
    }
    function e:GetClass() return self._class end
    function e:GetModel() return self._model end
    function e:IsVehicle() return self._class:find("^prop_vehicle_") ~= nil end
    function e:GetNWBool(k, d) local v = self._nw[k]; if v == nil then return d or false end return v end
    function e:SetNWBool(k, v) self._nw[k] = v end
    return e
end

string.GetFileFromFilename = string.GetFileFromFilename
    or function(p) return (tostring(p):match("([^/\\]+)$")) or tostring(p) end
IsValid = function(e) return e ~= nil and e ~= false end
CLIENT = false
SERVER = false
CreateClientConVar = function() end

dofile(here .. "/gmod_stub.lua")
dofile(TARGET)

if not (TIV and TIV.IsSupportedVehicle) then
    io.stderr:write("FAIL: TIV.IsSupportedVehicle was not defined by " .. TARGET .. "\n")
    os.exit(1)
end

------------------------------------------------------------------------------
-- Cases: real GMod classes and models.
------------------------------------------------------------------------------
local cases = {
    -- Must be supported -------------------------------------------------
    { want = true,  why = "default HL2 jeep",
      ent = makeEnt("prop_vehicle_jeep", "models/vehicle.mdl") },
    { want = true,  why = "old jeep class",
      ent = makeEnt("prop_vehicle_jeep_old", "models/vehicle.mdl") },
    { want = true,  why = "jalopy (the muscle car the TIV is built on)",
      ent = makeEnt("prop_vehicle_jalopy", "models/props_canal/vehicle001a.mdl") },
    { want = true,  why = "APC",
      ent = makeEnt("prop_vehicle_apc", "models/props_canal/vehicle001a.mdl") },
    { want = true,  why = "explicitly tagged with the Wire TIV controller",
      ent = makeEnt("prop_vehicle_jeep", "models/vehicle.mdl", { IsTIVVehicle = true }) },
    { want = true,  why = "tagged through the networked var",
      ent = (function() local e = makeEnt("prop_vehicle_jeep", "models/vehicle.mdl")
                        e:SetNWBool("TIV_Interceptor", true) return e end)() },
    { want = true,  why = "has a TIV config attached",
      ent = makeEnt("prop_vehicle_jeep", "models/vehicle.mdl", { _TIVConfig = {} }) },

    -- Must NOT be supported ---------------------------------------------
    { want = false, why = "AIRBOAT (class)",
      ent = makeEnt("prop_vehicle_airboat", "models/airboat/airboat.mdl") },
    { want = false, why = "AIRBOAT (model keyword, wrong class)",
      ent = makeEnt("prop_vehicle_jeep", "models/airboat/airboat.mdl") },
    { want = false, why = "PRISONER POD",
      ent = makeEnt("prop_vehicle_prisoner_pod",
                    "models/props_c17/chair02a.mdl") },
    { want = false, why = "prisoner pod, tagged anyway -- exclusion must win",
      ent = makeEnt("prop_vehicle_prisoner_pod",
                    "models/props_c17/chair02a.mdl", { IsTIVVehicle = true }) },
    { want = false, why = "airboat, tagged anyway -- exclusion must win",
      ent = (function() local e = makeEnt("prop_vehicle_airboat", "models/airboat/airboat.mdl")
                        e:SetNWBool("TIV_Interceptor", true) return e end)() },
    { want = false, why = "a car seat (GMod seats are prop_vehicle_jeep)",
      ent = makeEnt("prop_vehicle_jeep",
                    "models/nova/jeep_seat.mdl") },
    { want = false, why = "PHX vehicle seat",
      ent = makeEnt("prop_vehicle_jeep",
                    "models/props_phx/carseat.mdl") },
    -- prop_vehicle_jeep IS a supported class by design: the addon converts a
    -- stock jeep into the TIV, so any jeep qualifies whatever its model.
    { want = true,  why = "a modded jeep-class vehicle (still convertible)",
      ent = makeEnt("prop_vehicle_jeep", "models/somecar/car.mdl") },
    -- The catch-all that let pods and airboats in was `ent:IsVehicle()`. A
    -- vehicle class outside the list must now be rejected on its own.
    { want = false, why = "vehicle class outside the supported list",
      ent = makeEnt("prop_vehicle_choreo_generic", "models/props_canal/boat001b.mdl") },
    { want = false, why = "a plain prop",
      ent = makeEnt("prop_physics", "models/props_junk/wood_crate001a.mdl") },
    { want = false, why = "the player themself",
      ent = makeEnt("player", "models/player/group01/male_07.mdl") },
}

------------------------------------------------------------------------------
-- Run
------------------------------------------------------------------------------
print("Executed real file : " .. TARGET)
print(string.format("Lua runtime        : %s (%s)", _VERSION, jit and jit.version or "no jit"))
print("")

local failures = 0
for _, c in ipairs(cases) do
    local got = TIV.IsSupportedVehicle(c.ent)
    local ok = (got == c.want)
    if not ok then failures = failures + 1 end
    print(string.format("[%s] %-52s class=%-28s model=%s",
        ok and "OK " or "BAD", c.why, c.ent._class,
        c.ent._model ~= "" and c.ent._model or "(none)"))
    if not ok then
        print(string.format("      expected %s, got %s", tostring(c.want), tostring(got)))
    end
end

-- GetIdentifiedInterceptors is what the 3D editor's vehicle picker lists, so it
-- must not offer a pod or an airboat as a conversion target either.
print("")
local world = {
    cases[1].ent,  -- jeep
    makeEnt("prop_vehicle_airboat", "models/airboat/airboat.mdl"),
    makeEnt("prop_vehicle_prisoner_pod", "models/props_c17/chair02a.mdl"),
}
ents = { GetAll = function() return world end }
LocalPlayer = function() return nil end
TIV.ResolveVehicle = function() return nil end

if TIV.GetIdentifiedInterceptors then
    local list = TIV.GetIdentifiedInterceptors()
    local offered = {}
    for _, item in ipairs(list) do offered[#offered+1] = item.model end
    local pods = 0
    for _, m in ipairs(offered) do
        if m:find("airboat") or m:find("chair02a") then pods = pods + 1 end
    end
    local ok = (#list == 1 and pods == 0)
    if not ok then failures = failures + 1 end
    print(string.format("[%s] editor vehicle picker offers %d candidate(s), %d of them a pod/airboat",
        ok and "OK " or "BAD", #list, pods))
else
    print("[OK ] GetIdentifiedInterceptors not defined (skipped)")
end

print("")
if failures == 0 then
    print(string.format("RESULT: all %d classification cases correct", #cases + 1))
    os.exit(0)
else
    print(string.format("RESULT: %d case(s) FAILED", failures))
    os.exit(1)
end
