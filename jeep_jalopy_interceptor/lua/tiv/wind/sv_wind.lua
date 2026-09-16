-- ============================================================================
-- TIV WIND SYSTEM
-- Per-vehicle wind sampling (was global). One sample per vehicle per tick.
-- TIV_WindUpdate broadcast removed (was redundant with TIV_InstrumentData).
-- ApplyToEntity now takes an explicit scale instead of hard-coding 0.01.
-- ============================================================================

TIV.Wind = TIV.Wind or {}

TIV.Wind.CurrentMPH    = TIV.Config.WindDefault   -- last global sample (fallback)
TIV.Wind.Direction     = Vector(1, 0, 0)
TIV.Wind.PerVehicle    = TIV.Wind.PerVehicle or {} -- [entIndex] = { mph, dir, provider }

TIV.Wind.ManualMode    = false
TIV.Wind.ManualMPH     = 0
TIV.Wind.ManualDir     = Vector(1, 0, 0)
TIV.Wind.ManualUntil   = 0   -- 0 = no auto-expire

local MANUAL_AUTO_EXPIRE = 900 -- 15 minutes

-- Force constants (centralized magic numbers).
TIV.Wind.FORCE_PER_MPH_PER_KG = 25  -- empirical scaling

-- ============================================================================
-- INTERNAL: SAMPLE WORLD WIND AT A POSITION
-- Returns (mph, direction) without mutating globals. Caller decides what to
-- do with the value. Returns (nil, nil) if no provider responded.
--
-- GStorms API (from gstorms_probe ENT:Think):
--   GSGetGlobalWindspeedAndVectors(pos, entityList, inflowJet, envEnt, curTime, outVector, boolFlag)
--     - Returns: windspeed (number) -- single return value
--     - Writes wind direction into the pre-allocated outVector (6th arg)
--     - ConVar: "gstorms_tornado_inflow_jet" (NOT "gstorms_inflow_jet")
--     - entityList: gs_weatherEntityList.server
--     - envEnt: gs_env.server
-- ============================================================================

-- Pre-allocated output vector for GSGetGlobalWindspeedAndVectors.
-- The function writes the wind direction into this vector each call.
local gsOutVector = Vector(0, 0, 0)

local function IsFiniteNumber(value)
    return isnumber(value)
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function IsUsableVector(value)
    if not isvector(value) then return false end
    return IsFiniteNumber(value.x)
        and IsFiniteNumber(value.y)
        and IsFiniteNumber(value.z)
end

-- XT3 has used both (velocity, speed) and, in some API-facing integrations,
-- (speed, velocity). Accept either without letting NaN/inf poison physics or
-- net.WriteFloat later in the pipeline.
local function NormaliseWindReturns(first, second)
    -- Current XT3 can produce a NaN zero vector while still correctly
    -- returning speed 0 when no tornado exists. Treat a finite zero speed as
    -- calm before validating the unused direction so stale readings clear.
    if IsFiniteNumber(second) and second == 0 then
        return 0, Vector(1, 0, 0)
    end
    if IsFiniteNumber(first) and first == 0 and isvector(second) then
        return 0, Vector(1, 0, 0)
    end

    local velocity, speed
    if IsUsableVector(first) and IsFiniteNumber(second) then
        velocity, speed = first, second
    elseif IsFiniteNumber(first) and IsUsableVector(second) then
        speed, velocity = first, second
    else
        return nil, nil
    end

    if speed < 0 then return nil, nil end

    local lengthSqr = velocity:LengthSqr()
    if not IsFiniteNumber(lengthSqr) then return nil, nil end

    local direction = lengthSqr > 0.01
        and velocity:GetNormalized() or Vector(1, 0, 0)
    return math.Clamp(speed, 0, TIV.Config.WindMaxSimulated), direction
end

local function SampleGStormsTornadoWindAt(pos)
    if not isfunction(GSGetGlobalWindspeedAndVectors) then return nil, nil end
    if not gs_env or not gs_weatherEntityList then return nil, nil end

    local envEnt = gs_env.server or gs_env
    if not envEnt then return nil, nil end
    -- gs_env.server may be an entity or a table depending on GStorms version;
    -- only call IsValid on things that support it.
    if type(envEnt) ~= "table" and IsValid and not IsValid(envEnt) then return nil, nil end

    local entityList = gs_weatherEntityList.server or gs_weatherEntityList or {}

    local inflowCVar = GetConVar("gstorms_tornado_inflow_jet")
    local inflowJet  = inflowCVar and inflowCVar:GetBool() or false

    -- Reset the output vector before the call.
    gsOutVector.x, gsOutVector.y, gsOutVector.z = 0, 0, 0

    -- Full 7-argument call matching GStorms probe:
    --   GSGetGlobalWindspeedAndVectors(pos, entityList, inflowJet, envEnt, curTime, outVector, false)
    -- Returns a single number (blended windspeed in MPH).
    -- Wind direction is written into gsOutVector.
    local ok, windspeedMPH = pcall(
        GSGetGlobalWindspeedAndVectors,
        pos, entityList, inflowJet, envEnt, CurTime(), gsOutVector, false
    )
    if not ok or not IsFiniteNumber(windspeedMPH) then return nil, nil end
    if windspeedMPH <= 0 then return nil, nil end

    local _, direction = NormaliseWindReturns(gsOutVector, windspeedMPH)
    if not direction then return nil, nil end

    return math.Clamp(windspeedMPH, 0, TIV.Config.WindMaxSimulated), direction
end

-- XTwisters 3 intentionally exposes global API functions. Other weather
-- addons have historically used some of the same generic names, so resolving
-- only `GetGlobalWindspeed` is load-order dependent. Prefer namespaced/new API
-- spellings, then use the legacy globals while an XT3 convar/API marker exists.
local function GetNamespacedXT3Function(name)
    for _, namespaceName in ipairs({ "XT3", "XTwisters3" }) do
        local namespace = rawget(_G, namespaceName)
        if istable(namespace) and isfunction(namespace[name]) then
            return namespace[name]
        end
    end

    local prefixed = rawget(_G, "XT3" .. name)
    if isfunction(prefixed) then return prefixed end
    return nil
end

local function LegacyXT3Function(name)
    local fn = rawget(_G, name)
    return isfunction(fn) and fn or nil
end

local function HasXT3Marker()
    return GetConVar("xtwisters3_updatetime") ~= nil
        or GetConVar("xtwisters3_antilag") ~= nil
        or isfunction(rawget(_G, "GetGlobalWindData"))
        or isfunction(rawget(_G, "GetTornadoWindspeed"))
        or GetNamespacedXT3Function("GetGlobalWindspeed") ~= nil
end

-- Build the expensive global windfield list once per TIV wind tick. Reusing
-- it avoids rescanning all tornado entities separately for every occupied
-- interceptor, whether the per-vortex or global sampler handles the request.
local function BuildXT3Context()
    local context = { detected = HasXT3Marker(), windData = nil }
    if not context.detected then return context end

    local getData = GetNamespacedXT3Function("GetGlobalWindData")
        or LegacyXT3Function("GetGlobalWindData")
    if isfunction(getData) then
        local ok, windData = pcall(getData)
        if ok and istable(windData) then
            context.windData = windData
        end
    end

    return context
end

local function GetXT3GlobalSampler()
    local namespaced = GetNamespacedXT3Function("GetGlobalWindspeed")
    if namespaced then return namespaced end
    if not HasXT3Marker() then return nil end
    return LegacyXT3Function("GetGlobalWindspeed")
end

local function GetXT3TornadoSampler()
    return GetNamespacedXT3Function("GetTornadoWindspeed")
        or LegacyXT3Function("GetTornadoWindspeed")
end

-- Sample each valid XT3 vortex independently. This avoids the load-order
-- collision around XT3's generic `GetGlobalWindspeed` name and keeps one bad
-- third-party API tornado from disabling readings from every other vortex.
local function SampleXT3TornadoesDirectly(pos, context)
    local sampleTornado = GetXT3TornadoSampler()
    if not isfunction(sampleTornado) then return nil, nil end

    local strongestSpeed, strongestDirection = nil, nil
    local windfields = context and context.windData and context.windData[1]

    if istable(windfields) then
        for _, windfield in ipairs(windfields) do
            local ok, velocity, speed = pcall(sampleTornado, false, pos, windfield)
            if ok then
                local mph, direction = NormaliseWindReturns(velocity, speed)
                if mph and (not strongestSpeed or mph > strongestSpeed) then
                    strongestSpeed, strongestDirection = mph, direction
                end
            end
        end
    else
        -- Current XT3 and its API examples use xt3_tornadoes_* classes. Keep
        -- failures isolated so a malformed third-party vortex cannot disable
        -- wind readings from all other tornadoes.
        for _, tornado in ipairs(ents.FindByClass("xt3_tornadoes*")) do
            if IsValid(tornado) then
                local ok, velocity, speed = pcall(sampleTornado, tornado, pos)
                if ok then
                    local mph, direction = NormaliseWindReturns(velocity, speed)
                    if mph and (not strongestSpeed or mph > strongestSpeed) then
                        strongestSpeed, strongestDirection = mph, direction
                    end
                end
            end
        end
    end

    return strongestSpeed, strongestDirection
end

local function SampleXT3WindAt(pos, context)
    context = context or BuildXT3Context()
    if not context.detected then return nil, nil end

    -- The per-vortex function has an XT3-specific name and is therefore much
    -- less likely to be replaced by another weather addon. Prefer it whenever
    -- available, using the global API only as a compatibility fallback.
    local mph, direction = SampleXT3TornadoesDirectly(pos, context)
    if mph ~= nil then return mph, direction end

    local globalSampler = GetXT3GlobalSampler()
    if isfunction(globalSampler) then
        local ok, first, second = pcall(globalSampler, pos, context.windData)
        if ok then
            return NormaliseWindReturns(first, second)
        end
    end

    return nil, nil
end

-- Pick the stronger provider instead of returning the first one. Previously a
-- small positive GStorms ambient wind prevented XT3 from ever being queried,
-- which made XT3 appear unsupported whenever both popular addons were loaded.
local function SampleWorldWindAt(pos, xt3Context)
    local gsMPH, gsDirection   = SampleGStormsTornadoWindAt(pos)
    local xt3MPH, xt3Direction = SampleXT3WindAt(pos, xt3Context)

    if xt3MPH ~= nil and (gsMPH == nil or xt3MPH >= gsMPH) then
        return xt3MPH, xt3Direction, "XTwisters 3"
    end
    if gsMPH ~= nil then
        return gsMPH, gsDirection, "GStorms"
    end
    return nil, nil, nil
end

TIV.Wind.BuildXT3Context          = BuildXT3Context
TIV.Wind.SampleXT3WindAt          = SampleXT3WindAt
TIV.Wind.SampleWorldWindAt        = SampleWorldWindAt

-- ============================================================================
-- ACTIVE TORNADO TRACKING & PATH PREDICTION (GSTORMS & XTWISTERS 3)
-- Locates the active tornado entity to evaluate real-time core/side interception
-- and generate forward trajectory path prediction waypoints.
-- ============================================================================
function TIV.Wind.GetNearestActiveTornado(pos, maxDist)
    maxDist = maxDist or 45000
    local maxDistSqr = maxDist * maxDist
    local bestEnt = nil
    local bestDistSqr = maxDistSqr

    local candidates = {}
    local seen = {}

    local function addCandidate(e)
        if IsValid(e) and not seen[e] then
            seen[e] = true
            table.insert(candidates, e)
        end
    end

    -- XT3 tornado entities
    for _, e in ipairs(ents.FindByClass("xt3_tornadoes*")) do addCandidate(e) end
    for _, e in ipairs(ents.FindByClass("xtwisters3vortexbase")) do addCandidate(e) end

    -- GStorms weather entities
    for _, e in ipairs(ents.FindByClass("gstorms_weather_*")) do addCandidate(e) end
    for _, e in ipairs(ents.FindByClass("gstorms_base_entity")) do addCandidate(e) end
    if gs_weatherEntityList and gs_weatherEntityList.server then
        for _, e in pairs(gs_weatherEntityList.server) do
            if isentity(e) then addCandidate(e) end
        end
    end

    for _, ent in ipairs(candidates) do
        local cls = string.lower(ent:GetClass() or "")
        local isExcluded = string.find(cls, "earthquake", 1, true)
            or string.find(cls, "probe", 1, true)
            or string.find(cls, "seismograph", 1, true)
            or string.find(cls, "thermometer", 1, true)
            or string.find(cls, "computer", 1, true)
            or string.find(cls, "siren", 1, true)
            or string.find(cls, "volcano", 1, true)
            or string.find(cls, "anemometer", 1, true)
            or string.find(cls, "barometer", 1, true)

        local isVortex = false
        if not isExcluded then
            if string.find(cls, "xt3_tornadoes", 1, true)
                or string.find(cls, "xtwisters3vortexbase", 1, true)
                or string.find(cls, "gstorms_weather_ef", 1, true)
                or string.find(cls, "gstorms_weather_spout", 1, true)
                or string.find(cls, "gstorms_weather_dust_devil", 1, true)
                or string.find(cls, "gstorms_weather_hurricane", 1, true)
                or ent.VortexWindspeed ~= nil
                or ent.VortexCoreSize ~= nil
                or ent.Tornado == true
                or (ent.GetTornado and ent:GetTornado() == true)
                or ent.IsXT3Vortex == true or ent.IsVortex == true then
                isVortex = true
            end
        end

        if isVortex then
            local tPos = ent:GetPos()
            local dSqr = Vector(pos.x - tPos.x, pos.y - tPos.y, 0):LengthSqr()
            if dSqr < bestDistSqr then
                bestDistSqr = dSqr
                bestEnt = ent
            end
        end
    end

    if not IsValid(bestEnt) then return nil end

    local tPos = bestEnt:GetPos()
    local now = CurTime()
    local dist2D = math.sqrt(bestDistSqr)

    -- Universal track smoothing for translation vector
    if not bestEnt._TIV_LastPos then
        bestEnt._TIV_LastPos = tPos
        bestEnt._TIV_LastTime = now
        bestEnt._TIV_TrackDir = Vector(1, 0, 0)
        bestEnt._TIV_TrackSpeed = 25
    else
        local dt = now - bestEnt._TIV_LastTime
        if dt >= 0.25 then
            local dPos = tPos - bestEnt._TIV_LastPos
            local dLen = dPos:Length2D()
            if dLen > 2.0 then
                bestEnt._TIV_TrackDir = Vector(dPos.x, dPos.y, 0):GetNormalized()
                bestEnt._TIV_TrackSpeed = math.Clamp((dLen / dt) * 0.0568182, 5, 120)
            end
            bestEnt._TIV_LastPos = tPos
            bestEnt._TIV_LastTime = now
        end
    end

    -- Direction derivation
    local rawDir = bestEnt.MovementDirection or bestEnt.MovementVector
        or (bestEnt:GetVelocity():Length2D() > 15 and bestEnt:GetVelocity():GetNormalized())
        or bestEnt._TIV_TrackDir or Vector(1, 0, 0)
    local heading = Vector(rawDir.x, rawDir.y, 0):GetNormalized()
    if heading:LengthSqr() < 0.01 then heading = Vector(1, 0, 0) end

    -- Speed derivation (MPH & hammer units/sec)
    local speedMPH = bestEnt._TIV_TrackSpeed or 25
    if bestEnt.MovementSpeed and bestEnt.MovementSpeed > 0 then
        speedMPH = bestEnt.MovementSpeed * 2.23694
    elseif bestEnt:GetVelocity():Length2D() > 15 then
        speedMPH = bestEnt:GetVelocity():Length() * 0.0568182
    end
    speedMPH = math.Clamp(speedMPH, 8, 90)
    local speedUnits = speedMPH / 0.0568182

    -- Core radius (RMW / maximum wind zone)
    local coreRadius = bestEnt.VortexRMWSize
        or (bestEnt.GetNW2Float and bestEnt:GetNW2Float("VortexRMWSize", 0) > 0 and bestEnt:GetNW2Float("VortexRMWSize"))
        or bestEnt.VortexCoreSize
        or (bestEnt.GetNW2Float and bestEnt:GetNW2Float("VortexCoreSize", 0) > 0 and bestEnt:GetNW2Float("VortexCoreSize"))
        or 600

    -- Outer vortex radius
    local outerRadius = bestEnt.VortexSize
        or (bestEnt.GetVortexSize and bestEnt:GetVortexSize())
        or (bestEnt.GetNW2Float and bestEnt:GetNW2Float("VortexSize", 0) > 0 and bestEnt:GetNW2Float("VortexSize"))
        or (coreRadius * 4.5)
        or 3500

    -- Predicted waypoints calculation (using GStorms pathing curve or vector integration)
    local waypoints = {}
    if bestEnt.PathingData and istable(bestEnt.PathingData.edgePoints) and #bestEnt.PathingData.edgePoints > 0 then
        local startIdx = bestEnt.PathingData.edgePointIndex or 1
        for i = startIdx, math.min(#bestEnt.PathingData.edgePoints, startIdx + 8) do
            local pt = bestEnt.PathingData.edgePoints[i]
            if pt then
                table.insert(waypoints, { pos = Vector(pt.x, pt.y, pt.z or tPos.z) })
            end
        end
    end

    if #waypoints == 0 then
        local intervals = { 5, 10, 15, 20, 30, 45, 60 }
        for _, sec in ipairs(intervals) do
            table.insert(waypoints, {
                time = sec,
                pos  = tPos + heading * (speedUnits * sec),
            })
        end
    end

    -- Closest Point of Approach (CPA)
    local rel = Vector(pos.x - tPos.x, pos.y - tPos.y, 0)
    local proj = rel:Dot(heading)
    local eta = 0
    local cpaDist = dist2D
    local impactType = "receding"

    if proj > 0 then
        eta = proj / speedUnits
        local cpaPos = tPos + heading * proj
        cpaDist = (Vector(pos.x, pos.y, 0) - cpaPos):Length()

        if cpaDist <= coreRadius then
            impactType = "core"
        elseif cpaDist <= outerRadius then
            impactType = "side"
        else
            impactType = "miss"
        end
    else
        impactType = "receding"
        eta = 0
    end

    local bearing = math.deg(math.atan2(tPos.y - pos.y, tPos.x - pos.x))
    if bearing < 0 then bearing = bearing + 360 end

    return {
        ent         = bestEnt,
        pos         = tPos,
        heading     = heading,
        speedMPH    = speedMPH,
        speedUnits  = speedUnits,
        coreRadius  = coreRadius,
        outerRadius = outerRadius,
        dist        = dist2D,
        bearing     = bearing,
        eta         = math.Round(eta, 1),
        cpaDist     = math.Round(cpaDist, 1),
        impactType  = impactType,
        waypoints   = waypoints,
    }
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================
local function ManualActive()
    if not TIV.Wind.ManualMode then return false end
    if TIV.Wind.ManualUntil > 0 and CurTime() > TIV.Wind.ManualUntil then
        TIV.Wind.ManualMode  = false
        TIV.Wind.ManualUntil = 0
        print("[TIV] Wind manual override auto-expired.")
        return false
    end
    return true
end

function TIV.Wind.GetSpeed(veh)
    if ManualActive() then return TIV.Wind.ManualMPH end
    if IsValid(veh) then
        local entry = TIV.Wind.PerVehicle[veh:EntIndex()]
        if entry then return entry.mph end
    end
    return TIV.Wind.CurrentMPH
end

function TIV.Wind.GetDirection(veh)
    if ManualActive() then return TIV.Wind.ManualDir end
    if IsValid(veh) then
        local entry = TIV.Wind.PerVehicle[veh:EntIndex()]
        if entry then return entry.dir end
    end
    return TIV.Wind.Direction
end

-- Returns an unscaled wind force vector. Callers multiply by mass and any
-- scenario-specific scalar.
function TIV.Wind.GetForceVector(veh)
    return TIV.Wind.GetDirection(veh) * TIV.Wind.GetSpeed(veh) * TIV.Wind.FORCE_PER_MPH_PER_KG
end

function TIV.Wind.SetSpeed(mph)
    TIV.Wind.ManualMode  = true
    TIV.Wind.ManualMPH   = math.Clamp(mph, 0, TIV.Config.WindMaxSimulated)
    TIV.Wind.ManualUntil = CurTime() + MANUAL_AUTO_EXPIRE
end

function TIV.Wind.SetDirection(dir)
    TIV.Wind.ManualMode  = true
    TIV.Wind.ManualDir   = dir:GetNormalized()
    TIV.Wind.ManualUntil = CurTime() + MANUAL_AUTO_EXPIRE
end

function TIV.Wind.ClearManual()
    TIV.Wind.ManualMode  = false
    TIV.Wind.ManualUntil = 0
end

-- Apply wind force to a single entity. `scale` defaults to 1.0; pass smaller
-- values (e.g., 0.5) for lighter coupling.
function TIV.Wind.ApplyToEntity(ent, scale, veh)
    if not IsValid(ent) then return end
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return end
    if not phys:IsMotionEnabled() then return end

    local force = TIV.Wind.GetForceVector(veh) * phys:GetMass() * (scale or 1.0)
    phys:ApplyForceCenter(force)
end

-- ============================================================================
-- WIND THINK
-- Per-vehicle sampling. Each vehicle has its own wind value.
-- ============================================================================
timer.Create("TIV_WindThink", 0.1, 0, function()
    -- XT3's global wind data scans every tornado. Cache it for this tick so
    -- multiple interceptors do not each repeat the same world scan.
    local xt3Context = BuildXT3Context()

    -- Build list of active TIV vehicles.
    local activeVehicles = {}
    local seenIdx = {}
    for entIdx, data in pairs(TIV.Deploy.Vehicles or {}) do
        local veh = Entity(entIdx)
        if IsValid(veh) then
            table.insert(activeVehicles, { veh = veh, data = data, idx = entIdx })
            seenIdx[entIdx] = true
        end
    end

    -- Prune per-vehicle cache for vehicles that no longer exist.
    for idx in pairs(TIV.Wind.PerVehicle) do
        if not seenIdx[idx] then
            TIV.Wind.PerVehicle[idx] = nil
        end
    end

    if not ManualActive() then
        if #activeVehicles > 0 then
            for _, entry in ipairs(activeVehicles) do
                local mph, dir, provider = SampleWorldWindAt(entry.veh:GetPos(), xt3Context)
                if mph ~= nil then
                    TIV.Wind.PerVehicle[entry.idx] = {
                        mph      = mph,
                        dir      = dir,
                        provider = provider,
                    }
                    -- Keep the global cache updated as the last-seen sample.
                    TIV.Wind.CurrentMPH = mph
                    TIV.Wind.Direction  = dir
                end
            end
        else
            local ply = player.GetAll()[1]
            if IsValid(ply) then
                local mph, dir = SampleWorldWindAt(ply:GetPos(), xt3Context)
                if mph ~= nil then
                    TIV.Wind.CurrentMPH = mph
                    TIV.Wind.Direction  = dir
                end
            end
        end
    end

    -- Apply forces only to TIV vehicles (when not solidly anchored) + released spikes (never all props).
    for _, entry in ipairs(activeVehicles) do
        local state = entry.data and entry.data.state or "idle"
        local isSolidAnchored = (state == "anchored" and not entry.data.gravityReleased)
            or (state == "lowering" or state == "deploying_spikes")
        local windMPH = TIV.Wind.GetSpeed(entry.veh)

        if not isSolidAnchored and windMPH >= 50 then
            TIV.Wind.ApplyToEntity(entry.veh, 0.01, entry.veh)
        end

        for _, sd in ipairs(entry.data.spikes or {}) do
            if IsValid(sd.entity) and sd.phase == "released" then
                -- Released spikes are loose debris: lighter wind coupling.
                TIV.Wind.ApplyToEntity(sd.entity, 0.5, entry.veh)
            end
        end
    end

    -- Auto-deploy safety feature on high wind threshold
    local autoDeployCVar = GetConVar("tiv_auto_deploy_wind")
    local autoDeployThreshold = autoDeployCVar and autoDeployCVar:GetFloat() or 0
    if autoDeployThreshold > 0 then
        for _, entry in ipairs(activeVehicles) do
            local veh = entry.veh
            local data = entry.data
            if data and data.state == "idle" then
                local wMPH = TIV.Wind.GetSpeed(veh)
                if wMPH >= autoDeployThreshold then
                    local speed = veh:GetVelocity():Length() * 0.0568182
                    if speed < 15 and TIV.Deploy and TIV.Deploy.Deploy then
                        TIV.Deploy.Deploy(veh, data)
                    end
                end
            end
        end
    end

    -- No TIV_WindUpdate broadcast: HUD gets wind via TIV_InstrumentData.
end)

-- ============================================================================
-- COMMANDS
-- ============================================================================
local function isAuth(ply)
    if not IsValid(ply) then return true end -- server console
    return ply:IsAdmin()
end

concommand.Add("tiv_wind_set", function(ply, cmd, args)
    if not isAuth(ply) then return end
    local speed = tonumber(args[1]) or 0
    TIV.Wind.SetSpeed(speed)
    print(string.format("[TIV] Wind manual override: %d MPH (auto-expires in %ds)",
        speed, MANUAL_AUTO_EXPIRE))
end)

concommand.Add("tiv_wind_dir", function(ply, cmd, args)
    if not isAuth(ply) then return end
    local x = tonumber(args[1]) or 1
    local y = tonumber(args[2]) or 0
    local z = tonumber(args[3]) or 0
    TIV.Wind.SetDirection(Vector(x, y, z))
    print(string.format("[TIV] Wind direction set to (%s, %s, %s)", x, y, z))
end)

concommand.Add("tiv_wind_clear", function(ply, cmd, args)
    if not isAuth(ply) then return end
    TIV.Wind.ClearManual()
    print("[TIV] Wind manual override cleared.")
end)

concommand.Add("tiv_wind_status", function(ply, cmd, args)
    if not isAuth(ply) then return end
    local manual = ManualActive()
    local remaining = (TIV.Wind.ManualUntil > 0)
        and math.max(0, math.floor(TIV.Wind.ManualUntil - CurTime())) or 0

    print(string.format(
        "[TIV] Wind: %.1f MPH | Dir: %s | Mode: %s%s | GStorms: %s | XT3: %s",
        TIV.Wind.CurrentMPH,
        tostring(TIV.Wind.Direction),
        manual and "MANUAL" or "AUTO",
        manual and string.format(" (%ds left)", remaining) or "",
        isfunction(GSGetGlobalWindspeedAndVectors) and "YES" or "NO",
        HasXT3Marker() and "YES" or "NO"
    ))

    for idx, entry in pairs(TIV.Wind.PerVehicle) do
        print(string.format("  Vehicle #%d: %.1f MPH dir=%s provider=%s",
            idx, entry.mph, tostring(entry.dir), entry.provider or "unknown"))
    end
end)

print("[TIV] Wind system loaded (per-vehicle sampling, GStorms + XTwisters 3)")
