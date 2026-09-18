-- ===========================================================================
-- TIV UPGRADE VISUAL COVERAGE PROBE
--
-- Every unlockable upgrade is supposed to put something on the vehicle. This
-- runs the REAL code -- sh_progression.lua, sh_custom_config.lua,
-- sv_custom_components.lua and sv_spikes.lua -- and checks:
--
--   * each upgrade, unlocked on its own, produces at least one visible component
--     or a measurable change to the anchor layout;
--   * EnsureArmor's idea of how many props should exist matches what
--     SpawnArmorProps actually builds, for ALL 128 upgrade combinations. If they
--     ever disagree the reconciler respawns every panel on every call;
--   * the Heavy Anchor Array really changes the anchor count (max_spikes used to
--     be accumulated by CalculateBonuses and read by nothing at all), and that
--     the creator and the reconciler agree so they cannot rebuild-loop;
--   * without it, the two extra mounts in the defaults stay unused, so the stock
--     six-anchor geometry is untouched;
--   * the editor's curated model list resolves for every component type (it was
--     keyed side_armor/front_armor/roof_armor against components typed
--     armor_side/armor_front/armor_roof, so armor parts were offered spike
--     models).
--
--   tools/bin/luajit tools/upgrade_visual_probe.lua
--
-- Exit 0 = every upgrade is visible and nothing respawns in a loop.
-- ===========================================================================

local here = (arg and arg[0] or "tools/upgrade_visual_probe.lua"):match("^(.*)[/\\][^/\\]*$") or "."
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
util.AddNetworkString = noop
util.IsValidModel = function() return true end
concommand = { Add = noop }
constraint = { NoCollide = noop, RemoveAll = noop }
file = { IsDir = function() return true end, CreateDir = noop, Write = noop,
         Exists = function() return false end, Read = function() return nil end }
function SafeRemoveEntity() end
function SafeRemoveEntityDelayed() end
COLLISION_GROUP_DEBRIS = 1
RENDERMODE_NORMAL = 0
MASK_SOLID = 3

-- One fake player, whose unlocks the test drives.
local unlocked = {}
local fakePlayer = { __isentity = true }
string.Trim = string.Trim or function(str)
    return (tostring(str):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- GMod compiles a saved config chunk and hands back either a function or, when
-- handleError is false, the error message as a string.
function CompileString(code, name, handleError)
    local fn, err = loadstring(code, name)
    if fn then return fn end
    return err or "compile error"
end

-- GMod stdlib. Deep copy that preserves metatables, so Vector/Angle survive it.
table.Copy = table.Copy or function(t, lookup)
    if type(t) ~= "table" then return t end
    lookup = lookup or {}
    if lookup[t] then return lookup[t] end
    local out = {}
    lookup[t] = out
    for k, v in pairs(t) do out[k] = table.Copy(v, lookup) end
    return setmetatable(out, getmetatable(t))
end

game = game or {}
function player.GetHumans() return { fakePlayer } end
function game.SinglePlayer() return true end

------------------------------------------------------------------------------
-- Fake props and vehicles
------------------------------------------------------------------------------
local createdProps = {}

local function makeProp()
    local p = { __isentity = true, _model = nil, _parent = nil }
    for _, m in ipairs({ "SetModel", "SetPos", "SetAngles", "Spawn", "Activate",
                         "SetCollisionGroup", "SetCustomCollisionCheck", "SetColor",
                         "SetRenderMode", "SetParent", "SetLocalPos", "SetLocalAngles",
                         "SetNWBool", "SetNWEntity" }) do
        p[m] = function(self, v) if m == "SetModel" then self._model = v end
                                  if m == "SetParent" then self._parent = v end
                                  return self end
    end
    function p:GetPhysicsObject()
        return { SetMass = noop, EnableMotion = noop, EnableGravity = noop }
    end
    createdProps[#createdProps + 1] = p
    return p
end
ents = { Create = function() return makeProp() end, GetAll = function() return {} end,
         FindByClass = function() return {} end }

local function makeVeh(model, statsOverride)
    local ang = Angle(0, 0, 0)
    local v = { __isentity = true, _model = model, _props = {} }
    function v:GetModel() return self._model end
    function v:GetClass() return "prop_vehicle_jeep" end
    function v:IsVehicle() return true end
    function v:GetNWBool() return false end
    function v:GetNWString() return "" end
    function v:GetPos() return Vector(0, 0, 20) end
    function v:GetAngles() return ang end
    function v:GetForward() return ang:Forward() end
    function v:GetRight() return ang:Right() end
    function v:GetUp() return ang:Up() end
    function v:EntIndex() return 7 end
    function v:LocalToWorld(p) return p end
    function v:LocalToWorldAngles(a) return a end
    function v:GetDriver() return fakePlayer end
    function v:GetPhysicsObject()
        return { GetMass = function() return 1000 end, SetMass = noop }
    end
    v._TIVEffectiveStats = statsOverride
    return v
end

------------------------------------------------------------------------------
-- Load the real modules
------------------------------------------------------------------------------
TIV = {}
assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/config/sh_config.lua"))()
assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/progression/sh_progression.lua"))()
assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/customization/sh_custom_config.lua"))()
assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/spikes/sv_spikes.lua"))()
assert(loadfile(repo .. "/jeep_jalopy_interceptor/lua/tiv/customization/sv_custom_components.lua"))()

TIV.Progression.GetPlayerProfile = function() return { unlocked_upgrades = unlocked } end

local ALL = TIV.Progression.GetAllUpgrades()
assert(#ALL > 0, "no upgrades registered")

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

local function setUnlocked(ids)
    unlocked = {}
    for _, id in ipairs(ids or {}) do unlocked[id] = true end
end

local MODEL = "models/buggy.mdl"

-- Run the real spawner and report what it built, by component type.
local function spawnFor(ids)
    setUnlocked(ids)
    createdProps = {}
    local veh = makeVeh(MODEL)
    local config = TIV.CustomConfig.GetDefaultConfig(MODEL, unlocked["angled_spikes"] == true)
    TIV.CustomComponents.SpawnArmorProps(veh, config, unlocked)
    -- Which component types SHOULD have been built for this unlock set.
    local allowed = {}
    for _, c in ipairs(config.components) do
        local t = c.type
        local okType = (t == "armor_side" and unlocked["side_armor"])
            or (t == "armor_front" and unlocked["front_armor"])
            or (t == "armor_roof" and unlocked["roof_spoiler"])
            or (t == "hydraulic_ram" and unlocked["reinforced_hydraulics"])
            or ((t == "radar_screen" or t == "screen") and unlocked["path_screen"])
        if okType then allowed[#allowed + 1] = t end
    end
    return #createdProps, allowed
end

print("== every upgrade puts something on the vehicle ==")

-- Upgrade -> the component type that should appear, or "spikes" for the two
-- anchor upgrades whose visual is the anchor layout itself.
local VISIBLE = {
    side_armor            = "armor_side",
    front_armor           = "armor_front",
    roof_spoiler          = "armor_roof",
    reinforced_hydraulics = "hydraulic_ram",
    path_screen           = "radar_screen",
}

for _, upg in ipairs(ALL) do
    local n, allowed = spawnFor({ upg.id })
    if VISIBLE[upg.id] then
        local found = false
        for _, t in ipairs(allowed) do if t == VISIBLE[upg.id] then found = true end end
        check(string.format("%-24s spawns a %s", upg.id, VISIBLE[upg.id]), found and n > 0,
            string.format("%d prop(s) built, types: %s", n, table.concat(allowed, ", ")))
    else
        -- angled_spikes / heavy_cluster_spikes: the visual is the anchor layout.
        setUnlocked({ upg.id })
        local veh = makeVeh(MODEL, TIV.CustomConfig.CalculateVehicleStats(
            TIV.CustomConfig.GetDefaultConfig(MODEL, unlocked["angled_spikes"] == true), unlocked))
        local count = TIV.Spikes.ResolveCount(veh)
        local cfg = TIV.CustomConfig.GetDefaultConfig(MODEL, unlocked["angled_spikes"] == true)
        local angs = {}
        for _, c in ipairs(cfg.components) do
            if c.type == "spike" and #angs < count then
                angs[#angs + 1] = string.format("%.0f", c.ang and c.ang.p or 0)
            end
        end
        if upg.id == "angled_spikes" then
            local tilted = 0
            for _, a in ipairs(angs) do if a ~= "90" then tilted = tilted + 1 end end
            check(string.format("%-24s visibly angles the anchors", upg.id), tilted > 0,
                string.format("%d of %d mounts pitched off vertical (%s)", tilted, #angs, table.concat(angs, "/")))
        else
            check(string.format("%-24s adds visible anchors", upg.id), count > 6,
                string.format("anchor count %d (stock is 6)", count))
        end
    end
end

print("\n== the Heavy Anchor Array actually changes the anchors ==")

setUnlocked({})
local plainStats = TIV.CustomConfig.CalculateVehicleStats(TIV.CustomConfig.GetDefaultConfig(MODEL, false), unlocked)
local plainVeh = makeVeh(MODEL, plainStats)
local plainCount = TIV.Spikes.ResolveCount(plainVeh)
check("max_spikes reaches the vehicle stats", plainStats.max_spikes == 6,
    string.format("stats.max_spikes = %s", tostring(plainStats.max_spikes)))
check("no upgrade -> six anchors", plainCount == 6, string.format("ResolveCount = %d", plainCount))

setUnlocked({ "heavy_cluster_spikes" })
local heavyStats = TIV.CustomConfig.CalculateVehicleStats(TIV.CustomConfig.GetDefaultConfig(MODEL, false), unlocked)
local heavyVeh = makeVeh(MODEL, heavyStats)
local heavyCount = TIV.Spikes.ResolveCount(heavyVeh)
check("heavy_cluster_spikes -> max_spikes 8", heavyStats.max_spikes == 8,
    string.format("stats.max_spikes = %s", tostring(heavyStats.max_spikes)))
check("heavy_cluster_spikes -> eight anchors", heavyCount == 8, string.format("ResolveCount = %d", heavyCount))

-- The two extra mounts must be the LAST two, so the first six are the stock ones.
local cfg = TIV.CustomConfig.GetDefaultConfig(MODEL, false)
local spikeIds = {}
for _, c in ipairs(cfg.components) do
    if c.type == "spike" then spikeIds[#spikeIds + 1] = c.id end
end
check("the config defines eight mounts", #spikeIds == 8, table.concat(spikeIds, ", "))
check("the first six are the original layout",
    table.concat(spikeIds, ",", 1, 6) == "spike_fr,spike_fl,spike_mr,spike_ml,spike_rr,spike_rl",
    table.concat(spikeIds, ",", 1, 6))

print("\n== a saved config that predates the extra mounts still gets them ==")

-- The Heavy Anchor Array's ceiling comes from max_spikes, but the count comes
-- from the mounts the config defines. A layout saved before the extra mounts
-- existed -- which is every layout anyone has actually saved, including the one
-- the user exported -- defines six, so the upgrade stayed invisible for exactly
-- the players who had already used the editor. This drives the real
-- GetSavedConfig, which is where migration runs.
local fixturePath = here .. "/fixtures/buggy_fully_upgraded.lua"
local fh = io.open(fixturePath, "r")
local fixtureText = fh and fh:read("*a") or ""
if fh then fh:close() end

local savedPath = TIV.CustomConfig.GetConfigFileName("models/buggy.mdl")
file.Exists = function(p) return p == savedPath end
file.Read   = function() return fixtureText end
TIV.CustomConfig.VehicleConfigs = {}

local function countSpikes(cfg)
    local n = 0
    for _, c in ipairs(cfg and cfg.components or {}) do
        if c.type == "spike" then n = n + 1 end
    end
    return n
end

local raw = assert(loadfile(fixturePath))()
check("the exported layout really defines only six mounts", countSpikes(raw) == 6,
    string.format("%d spike components in the file", countSpikes(raw)))

local loaded = TIV.CustomConfig.GetSavedConfig("models/buggy.mdl")
check("the saved config loads through the real GetSavedConfig", loaded ~= nil)
check("migration brings it up to the factory count", loaded and countSpikes(loaded) == 8,
    string.format("%d -> %d", countSpikes(raw), loaded and countSpikes(loaded) or -1))

-- The added mounts must sit outboard of the widest existing row, on that row's
-- own line, so they land on the layout the player arranged.
local maxX, widestY = 0, nil
for _, c in ipairs(raw.components) do
    if c.type == "spike" and math.abs(c.pos.x) > maxX then
        maxX, widestY = math.abs(c.pos.x), c.pos.y
    end
end
local added = {}
for _, c in ipairs(loaded.components) do
    if c.type == "spike" and c.group == "migrated" then added[#added + 1] = c end
end
check("exactly two mounts were added", #added == 2, string.format("%d added", #added))
local outboard, online, mirrored = true, true, {}
for _, c in ipairs(added) do
    if math.abs(c.pos.x) <= maxX then outboard = false end
    if c.pos.y ~= widestY then online = false end
    mirrored[c.pos.x > 0 and "right" or "left"] = math.abs(c.pos.x)
end
check("the new mounts sit outboard of the widest row", outboard,
    string.format("widest existing |x| = %.2f, added at +/-%.2f", maxX, mirrored.right or -1))
check("symmetrically, on the widest row's own line",
    online and mirrored.left == mirrored.right,
    string.format("y = %.2f for both", added[1] and added[1].pos.y or -1))

-- A mount added on the right must inherit the right-hand angle convention, so an
-- angled-spike layout does not get two vertical anchors bolted onto it.
local rightPitch = nil
for _, c in ipairs(raw.components) do
    if c.type == "spike" and c.pos.x > 0 and not rightPitch and c.ang then
        rightPitch = c.ang.p
    end
end
local rightAdded = nil
for _, c in ipairs(added) do if c.pos.x > 0 then rightAdded = c end end
check("the added mount inherits the side's angle convention",
    rightAdded and rightPitch and rightAdded.ang.p == rightPitch,
    string.format("existing right pitch %.2f, added %.2f", rightPitch or -1,
        rightAdded and rightAdded.ang.p or -1))

-- Idempotence: a config that already has eight must not grow.
local function deepCopy(t)
    local out = {}
    for k, v in pairs(t) do
        out[k] = (type(v) == "table") and deepCopy(v) or v
    end
    return out
end
local again = TIV.CustomConfig.MigrateSpikeMounts(deepCopy(loaded))
check("migration is idempotent", countSpikes(again) == 8,
    string.format("%d after a second pass", countSpikes(again)))

-- And the point of all of it: the upgrade now actually changes the anchors.
setUnlocked({ "heavy_cluster_spikes" })
local savedVeh = makeVeh("models/buggy.mdl",
    TIV.CustomConfig.CalculateVehicleStats(loaded, unlocked))
check("heavy_cluster_spikes yields eight anchors on a saved config",
    TIV.Spikes.ResolveCount(savedVeh) == 8,
    string.format("ResolveCount = %d (was 6 before migration)", TIV.Spikes.ResolveCount(savedVeh)))

setUnlocked({})
local savedVeh2 = makeVeh("models/buggy.mdl",
    TIV.CustomConfig.CalculateVehicleStats(loaded, unlocked))
check("...and still six without the upgrade", TIV.Spikes.ResolveCount(savedVeh2) == 6,
    string.format("ResolveCount = %d", TIV.Spikes.ResolveCount(savedVeh2)))

-- Put the file stub back for the sections below.
file.Exists = function() return false end
file.Read   = function() return nil end
TIV.CustomConfig.VehicleConfigs = {}

print("\n== the creator and the reconciler cannot disagree ==")

-- EnsureSpikes rebuilds whenever validCount ~= desiredSpikeCount. If the two sides
-- ever compute different numbers the anchors get torn down every single call.
for _, ids in ipairs({ {}, { "heavy_cluster_spikes" }, { "angled_spikes" },
                       { "angled_spikes", "heavy_cluster_spikes" } }) do
    setUnlocked(ids)
    local stats = TIV.CustomConfig.CalculateVehicleStats(
        TIV.CustomConfig.GetDefaultConfig(MODEL, unlocked["angled_spikes"] == true), unlocked)
    local veh = makeVeh(MODEL, stats)
    local creator = TIV.Spikes.ResolveCount(veh)
    local reconciler = TIV.Spikes.ResolveCount(veh)
    local defined = TIV.CustomConfig.CountSpikeComponents(veh, unlocked["angled_spikes"] == true)
    check(string.format("upgrades [%s] agree", table.concat(ids, ", ")),
        creator == reconciler and creator <= defined,
        string.format("creator=%d reconciler=%d mounts-defined=%d", creator, reconciler, defined))
end

print("\n== EnsureArmor and SpawnArmorProps agree for every combination ==")

-- 2^7 = 128 combinations. A mismatch here means every panel is deleted and
-- respawned on every EnsureArmor call.
local ids = {}
for _, u in ipairs(ALL) do ids[#ids + 1] = u.id end

-- Idempotence is the real invariant: EnsureArmor keeps its own tally of what
-- SHOULD exist and respawns everything when the tally disagrees with what is
-- actually parented. So mount once, then call it again on the same vehicle --
-- if the tally is wrong the second call tears the panels down and rebuilds them.
-- Both sides here are the real functions; nothing is recomputed by the test.
local loops = 0
local worst = nil
for mask = 0, (2 ^ #ids) - 1 do
    local combo = {}
    for bit = 0, #ids - 1 do
        if math.floor(mask / (2 ^ bit)) % 2 == 1 then combo[#combo + 1] = ids[bit + 1] end
    end
    setUnlocked(combo)

    createdProps = {}
    local veh = makeVeh(MODEL)
    TIV.CustomComponents.EnsureArmor(veh, fakePlayer)
    local first = #createdProps

    TIV.CustomComponents.EnsureArmor(veh, fakePlayer)
    local second = #createdProps

    if second ~= first then
        loops = loops + 1
        if not worst then
            worst = string.format("[%s] first call mounted %d, second call remounted %d",
                table.concat(combo, ","), first, second - first)
        end
    end
end
check("all 128 upgrade combinations are stable across repeated EnsureArmor", loops == 0,
    loops == 0 and "no combination respawns its components" or (loops .. " loop(s), e.g. " .. tostring(worst)))

print("\n== unlocking only the Path Screen actually mounts the screen ==")

-- This is the case that used to fall into EnsureArmor's "nothing wanted" branch,
-- remove any existing props and return.
setUnlocked({ "path_screen" })
createdProps = {}
local screenVeh = makeVeh(MODEL)
TIV.CustomComponents.EnsureArmor(screenVeh, fakePlayer)
check("a screen-only unlock spawns the screen", #createdProps == 1,
    string.format("%d prop(s) mounted", #createdProps))
check("and it is the screen, parented to the vehicle",
    #createdProps == 1 and createdProps[1]._parent == screenVeh)

setUnlocked({ "reinforced_hydraulics" })
createdProps = {}
TIV.CustomComponents.EnsureArmor(makeVeh(MODEL), fakePlayer)
check("a hydraulics-only unlock spawns both rams", #createdProps == 2,
    string.format("%d prop(s) mounted", #createdProps))

print("\n== the editor's curated model list resolves for every type ==")

local TYPES = { "spike", "armor_side", "armor_front", "armor_roof", "hydraulic_ram", "radar_screen" }
for _, t in ipairs(TYPES) do
    local list = TIV.CustomConfig.CuratedModels[t]
    check(string.format("CuratedModels[%q] exists", t), list ~= nil and #list > 0,
    list and (#list .. " model(s)") or "nil -> the editor silently fell back to spike models")
end

print("\n== every default config defines every visual component ==")

for _, model in ipairs({ "models/buggy.mdl", "models/vehicle.mdl", "models/props_phx/ammo_box2.mdl" }) do
    local c = TIV.CustomConfig.GetDefaultConfig(model, false)
    local have = {}
    for _, comp in ipairs(c.components or {}) do have[comp.type] = (have[comp.type] or 0) + 1 end
    local missing = {}
    for _, t in ipairs(TYPES) do
        if not have[t] then missing[#missing + 1] = t end
    end
    check(string.format("%s defines all six types", model), #missing == 0,
        #missing == 0 and string.format("spikes=%d side=%d front=%d roof=%d ram=%d screen=%d",
            have.spike or 0, have.armor_side or 0, have.armor_front or 0,
            have.armor_roof or 0, have.hydraulic_ram or 0, have.radar_screen or 0)
            or ("missing: " .. table.concat(missing, ", ")))
end

print("\n== the factory buggy layout matches the user's exported one ==")

-- The user aligned these parts in the 3D editor and exported them, so their
-- values are ground truth. The factory defaults are derived from the same
-- offsets, so they must agree -- if someone re-guesses a coordinate this fails.
local function findComp(cfg, ctype, nth)
    local n = 0
    for _, c in ipairs(cfg.components or {}) do
        if c.type == ctype then
            n = n + 1
            if not nth or n == nth then return c end
        end
    end
end

local factory = TIV.CustomConfig.GetDefaultConfig("models/buggy.mdl", false)
local roofF, roofU = findComp(factory, "armor_roof"), findComp(raw, "armor_roof")
check("factory roof position matches the exported one",
    roofF and roofU
        and math.abs(roofF.pos.x - roofU.pos.x) < 0.01
        and math.abs(roofF.pos.y - roofU.pos.y) < 0.01
        and math.abs(roofF.pos.z - roofU.pos.z) < 0.01,
    string.format("factory (%.2f, %.2f, %.2f) vs exported (%.2f, %.2f, %.2f)",
        roofF and roofF.pos.x or 0, roofF and roofF.pos.y or 0, roofF and roofF.pos.z or 0,
        roofU and roofU.pos.x or 0, roofU and roofU.pos.y or 0, roofU and roofU.pos.z or 0))
check("factory roof angle matches the exported one",
    roofF and roofU and math.abs(roofF.ang.p - roofU.ang.p) < 0.01
        and math.abs(roofF.ang.r - roofU.ang.r) < 0.01,
    string.format("factory (%.2f, %.2f, %.2f) vs exported (%.2f, %.2f, %.2f)",
        roofF and roofF.ang.p or 0, roofF and roofF.ang.y or 0, roofF and roofF.ang.r or 0,
        roofU and roofU.ang.p or 0, roofU and roofU.ang.y or 0, roofU and roofU.ang.r or 0))
check("factory roof uses the exported model", roofF and roofU and roofF.model == roofU.model,
    tostring(roofF and roofF.model))

local ramF, ramU = findComp(factory, "hydraulic_ram"), findComp(raw, "hydraulic_ram")
check("factory ram position matches the exported one",
    ramF and ramU and math.abs(math.abs(ramF.pos.x) - math.abs(ramU.pos.x)) < 0.01
        and math.abs(ramF.pos.y - ramU.pos.y) < 0.01
        and math.abs(ramF.pos.z - ramU.pos.z) < 0.01,
    string.format("factory (+/-%.2f, %.2f, %.2f) vs exported (%.2f, %.2f, %.2f)",
        math.abs(ramF and ramF.pos.x or 0), ramF and ramF.pos.y or 0, ramF and ramF.pos.z or 0,
        ramU and ramU.pos.x or 0, ramU and ramU.pos.y or 0, ramU and ramU.pos.z or 0))

-- The six original mounts, the side panels, the front panel and the screen were
-- already identical to the export, so the export also pins them.
local pins = { { "armor_side", 1 }, { "armor_side", 2 }, { "armor_front", 1 }, { "radar_screen", 1 } }
local unpinned = {}
for _, pn in ipairs(pins) do
    local f, u = findComp(factory, pn[1], pn[2]), findComp(raw, pn[1], pn[2])
    if not (f and u and math.abs(f.pos.x - u.pos.x) < 0.01
              and math.abs(f.pos.y - u.pos.y) < 0.01
              and math.abs(f.pos.z - u.pos.z) < 0.01) then
        unpinned[#unpinned + 1] = pn[1] .. " #" .. pn[2]
    end
end
check("the other exported parts still match the factory layout", #unpinned == 0,
    #unpinned == 0 and "side x2, front, screen all agree" or ("drifted: " .. table.concat(unpinned, ", ")))

print(string.format("\nRESULT: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
