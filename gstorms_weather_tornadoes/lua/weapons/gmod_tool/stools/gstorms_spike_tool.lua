include("gstorms_funcs/gstorms_shared_tools.lua")
include("autorun/client/gstorms_config_menu.lua")

TOOL.Tab = "GStorms"
TOOL.Category = "99_gstorms_tools"
TOOL.Name = "#tool.gstorms_spike_tool.name"
TOOL.Information = {{name = "left"}}
TOOL.ClientConVar = {
    deploytime = "1",
    windresistance = "65",
    invulnerability = "0",
    deploykey = "7",
    undeploykey = "8",
    deploydrop = "5",
    modelscale = "0.3"
}

local windResistMin = 65
local windResistMax = 320
local windResistInfinite = 2147483647

local deployTimeMin = 1
local deployTimeMax = 25
local deployDropMin = 0
local deployDropMax = 10

local spikeModel = "models/mechanics/robotics/i3.mdl"
local spikeMaterial = "models/props_pipes/GutterMetal01a"
local spikeSurfaceOffset = 1
local spikeModelScaleMin = 0.1
local spikeModelScaleMax = 1
local spikeModelScale = 0.3
local spikeSoundOutside = "spikes/spikes_outside_vehicle.wav"
local spikeSoundInside = "spikes/spikes_in_vehicle.wav"
local spikeSoundDeployed = "spikes/spikes_deployed_sound.wav"
local spikeSoundFadeMin = 100
local spikeSoundFadeMax = 2000

local gsSpikeParentStates = {}
local gsSpikeParentStatesList = {}
local worldDropDir = Vector(0, 0, -1)

local groundCheckUnits = 14
local groundTraceDown = Vector(0, 0, -(groundCheckUnits + 1))
local spikeWindOut = Vector()
local spikeInflowJetConvar = GetConVar("gstorms_tornado_inflow_jet")
local spikeDeployMaxAngle = 37
local spikeDeployGroundDot = math.cos(math.rad(spikeDeployMaxAngle))
local spikeDeploySpeedMaxSqr = 50 * 50

local ghostColor = Color(255, 255, 255, 150)
local spikeSoundMaxChannels = 4
local spikeSoundFadeMaxSqr = spikeSoundFadeMax * spikeSoundFadeMax
local activeSpikeSounds = {}
local activeSpikeSoundSpikes = {}
local activeSpikeSoundList = {}

local function GSIsValidSpikeTarget(ent) return IsValid(ent) and !ent:IsPlayer() and !ent:IsNPC() and !ent:IsWorld() end

local function GSGetSpikePlacement(trace, ply)
    local normal = trace.HitNormal
    local ang = normal:Angle()
    ang.p = ang.p + 90

    if normal.z > 0.5 and IsValid(ply) then
        local aimDir = ply:EyeAngles():Forward() * -1

        aimDir = aimDir - normal * aimDir:Dot(normal)

        if aimDir:LengthSqr() <= 0.0001 then
            aimDir = ply:EyeAngles():Up() * -1
            aimDir = aimDir - normal * aimDir:Dot(normal)
        end

        if aimDir:LengthSqr() > 0.0001 then
            aimDir:Normalize()
            ang = aimDir:AngleEx(normal)
        end
    end

    return trace.HitPos + normal * spikeSurfaceOffset, ang
end

local function GSSanitizeSpikeWindResistance(value, preventUnwelding)
    if preventUnwelding then return windResistInfinite end

    value = tonumber(value)
    if value == nil then return nil end
    if value == windResistInfinite then return windResistInfinite end

    return math.Clamp(value, windResistMin, windResistMax)
end

local function GSGetSpikeParentState(parent)
    local state = gsSpikeParentStates[parent]
    if state then return state end

    state = {
        parent = parent, spikes = {},
        deployTime = deployTimeMin,
        vehicleLowered = 0, vehicleStartLowered = 0, vehicleTargetLowered = 0, vehicleStartZ = 0,
        vehicleLockPos = Vector(), vehicleLockAng = Angle(),
        transitionStart = 0, transitionEnd = 0,
        frozen = false
    }

    gsSpikeParentStates[parent] = state
    gsSpikeParentStatesList[#gsSpikeParentStatesList + 1] = state

    return state
end

local function GSApplySpikeWindResistance(ent, windResistance)
    if !IsValid(ent) then return end

    ent.GSWindResistance = windResistance
    ent:SetNW2Int("GSWindResistance", windResistance or 0)

    duplicator.StoreEntityModifier(ent, "gstorms_wind_resistance", {GSWindResistance = windResistance, GSPreventUnwelding = windResistance == windResistInfinite})
end

local function GSSetSpikeVisualLowered(state, lowered)
    if !IsValid(state.parent) or !IsValid(state.spike) then return end

    state.spike:SetLocalPos(state.parent:WorldToLocal(state.parent:LocalToWorld(state.spike.GSSpikeBaseLocalPos) + worldDropDir * lowered))
    state.spike:SetLocalAngles(state.spike.GSSpikeBaseLocalAng)
    state.spike:SetNW2Float("GSSpikeLowered", lowered)
end

local function GSSendSpikeSound(ply, duration, ent, spike, deployed)
    if !IsValid(ply) or !ply:IsPlayer() then return end

    local spikeIndex = isnumber(spike) and spike or (IsValid(spike) and spike:EntIndex() or 0)

    net.Start("gs_spike_sound")
    net.WriteFloat(duration)
    net.WriteEntity(IsValid(ent) and ent or NULL)
    net.WriteUInt(spikeIndex, 16)
    net.WriteBool(deployed == true)
    net.Send(ply)
end

local function GSSetFrozen(ent, frozen)
    if !IsValid(ent) then return end

    local phys = ent:GetPhysicsObject()
    if !phys:IsValid() then return end

    phys:EnableMotion(!frozen)

    if frozen then phys:Sleep() else phys:Wake() end
end

local function GSAddParentAssemblyEnt(state, list, added, ent)
    if !GSIsValidSpikeTarget(ent) or added[ent] or ent.GSSpikeState then return end

    added[ent] = true
    list[#list + 1] = ent
end

local function GSGetParentAssemblyEnts(state)
    local list = {}
    local added = {}
    local parent = state.parent

    GSAddParentAssemblyEnt(state, list, added, parent)

    local constrainedEnts = IsValid(parent) and constraint.GetAllConstrainedEntities(parent)

    if constrainedEnts then
        for ent in pairs(constrainedEnts) do
            GSAddParentAssemblyEnt(state, list, added, ent)
        end
    end

    if IsValid(parent) then
        for _, ent in ipairs(parent:GetChildren()) do
            GSAddParentAssemblyEnt(state, list, added, ent)
        end
    end

    return list
end

local function GSEnsureParentAssemblyEnts(state)
    if state.assemblyEnts then return state.assemblyEnts end

    state.assemblyEnts = GSGetParentAssemblyEnts(state)

    return state.assemblyEnts
end

local function GSSetParentAssemblyFrozen(state, frozen)
    local ents = GSEnsureParentAssemblyEnts(state)

    state.frozen = frozen

    for i = 1, #ents do
        GSSetFrozen(ents[i], frozen)
    end
end

local function GSGetParentAssemblyWindResistance(state)
    local windResistance

    for i = #state.spikes, 1, -1 do
        local spike = state.spikes[i]
        local spikeState = IsValid(spike) and spike.GSSpikeState

        if spikeState and (spikeState.spikeTargetLowered or 0) > 0 then
            windResistance = math.max(windResistance or 0, spikeState.windResistance or windResistMin)
        end
    end

    return windResistance
end

local function GSApplyParentAssemblyWindResistance(state, windResistance)
    if !windResistance then return end

    local ents = GSEnsureParentAssemblyEnts(state)

    if !state.windRestore then
        state.windRestore = {}

        for i = 1, #ents do
            local ent = ents[i]
            state.windRestore[#state.windRestore + 1] = {ent = ent, windResistance = ent.GSWindResistance}
        end
    end

    if state.assemblyWindResistance == windResistance then return end

    state.assemblyWindResistance = windResistance

    for i = 1, #ents do
        GSApplySpikeWindResistance(ents[i], windResistance)
    end
end

local function GSRestoreParentAssemblyWindResistance(state)
    local restore = state.windRestore

    if restore then
        for i = 1, #restore do
            local data = restore[i]

            if IsValid(data.ent) then
                GSApplySpikeWindResistance(data.ent, data.windResistance)
            end
        end
    end

    state.windRestore = nil
    state.assemblyWindResistance = nil
    state.assemblyEnts = nil
end

local function GSResetParentSpikeLowering(state, unfreeze)
    state.vehicleLowered = 0
    state.vehicleStartLowered = 0
    state.vehicleTargetLowered = 0
    state.transitionStart = 0
    state.transitionEnd = 0
    state.groundContactEnt = nil
    state.groundContactNormal = nil

    GSRestoreParentAssemblyWindResistance(state)

    if unfreeze and state.frozen then GSSetParentAssemblyFrozen(state, false) end
end

local function GSSetupVehicleSpike(ply, spike, ent, cfg, addUndo, spawn)

    spike:SetModel(spikeModel)
    spike:SetModelScale(cfg.modelScale)
    spike:SetMaterial(spikeMaterial)
    spike:SetPos(ent:LocalToWorld(cfg.localPos))
    spike:SetAngles(ent:LocalToWorldAngles(cfg.localAng))
    if IsValid(ply) then spike:SetOwner(ply) end

    if spawn then
        spike:Spawn()
        constraint.NoCollide(spike, ent, 0, 0)
    end
    
    spike:SetSolid(SOLID_NONE)
    spike:SetMoveType(MOVETYPE_NONE)
    spike:SetParent(ent)

    spike.GSSpikeBaseLocalPos = cfg.localPos
    spike.GSSpikeBaseLocalAng = cfg.localAng

    spike:SetLocalPos(cfg.localPos)
    spike:SetLocalAngles(cfg.localAng)

    local parentState = GSGetSpikeParentState(ent)

    parentState.deployTime = cfg.deployTime

    local spikeState = {
        parent = ent, parentState = parentState, spike = spike,
        deployed = false, deployDrop = cfg.deployDrop, deployTime = cfg.deployTime, windResistance = cfg.windResistance,
        spikeLowered = 0, spikeStartLowered = 0, spikeTargetLowered = 0,
        transitionStart = 0, transitionEnd = 0, lastToggleFrame = -1
    }

    spike.GSSpikeState = spikeState

    duplicator.StoreEntityModifier(spike, "gstorms_spike", {
        parentIndex = ent:EntIndex(),
        localPos = cfg.localPos,
        localAng = cfg.localAng,
        deployTime = cfg.deployTime,
        deployDrop = cfg.deployDrop,
        windResistance = cfg.windResistance,
        modelScale = cfg.modelScale,
        deployKey = cfg.deployKey,
        undeployKey = cfg.undeployKey,
    })

    local spikeIndex = spike:EntIndex()

    spike:RemoveCallOnRemove("gs_spike_sound_stop")
    spike:CallOnRemove("gs_spike_sound_stop", function(ent)
        local state = ent.GSSpikeState

        if state and CurTime() < (state.transitionEnd or 0) then
            GSSendSpikeSound(ent:GetOwner(), -1, NULL, spikeIndex)
        end
    end)

    spike:SetNW2Bool("GSSpikeDeployed", false)
    spike:SetNW2Float("GSSpikeLowered", 0)

    parentState.spikes[#parentState.spikes + 1] = spike

    GSApplySpikeWindResistance(spike, cfg.windResistance)
    GSSetSpikeVisualLowered(spikeState, 0)

    if parentState.frozen then GSSetFrozen(ent, true) end

    if IsValid(ply) then
        numpad.OnDown(ply, cfg.deployKey, "GStormsSpikeDeploy", spike)
        numpad.OnDown(ply, cfg.undeployKey, "GStormsSpikeUndeploy", spike)

        if addUndo then
            undo.Create("GStorms Vehicle Spike")
                undo.AddEntity(spike)
                undo.SetPlayer(ply)
            undo.Finish()

            ply:AddCleanup("props", spike)
        end
    end

    return spikeState

end

local function GSHitGroundAt(x, y, z, filter)
    local start = Vector(x, y, z)
    local tr = util.TraceLine({start = start, endpos = start + groundTraceDown, filter = filter, mask = MASK_SOLID_BRUSHONLY})
    return tr.Hit and tr
end

local function GSGetValidSpikeState(state, index)
    local spike = state.spikes[index]
    local spikeState = IsValid(spike) and spike.GSSpikeState

    if spikeState then return spike, spikeState end

    table.remove(state.spikes, index)
end

local function GSBuildSpikeGroundFilter(state, filter)
    filter[#filter + 1] = state.parent

    for i = #state.spikes, 1, -1 do
        if IsValid(state.spikes[i]) then
            filter[#filter + 1] = state.spikes[i]
        else
            table.remove(state.spikes, i)
        end
    end
end

local function GSIsEntTouchingGround(ent, filter)
    if !IsValid(ent) then return false end

    filter[#filter + 1] = ent

    local mins, maxs = ent:WorldSpaceAABB()
    local midX = (mins.x + maxs.x) * 0.5
    local midY = (mins.y + maxs.y) * 0.5
    local startZ = mins.z + groundCheckUnits
    local insetX = math.min((maxs.x - mins.x) * 0.25, 24)
    local insetY = math.min((maxs.y - mins.y) * 0.25, 24)

    return GSHitGroundAt(midX, midY, startZ, filter) or GSHitGroundAt(mins.x + insetX, mins.y + insetY, startZ, filter) or GSHitGroundAt(maxs.x - insetX, mins.y + insetY, startZ, filter) or GSHitGroundAt(mins.x + insetX, maxs.y - insetY, startZ, filter) or GSHitGroundAt(maxs.x - insetX, maxs.y - insetY, startZ, filter)
end

local function GSAddGroundCandidate(candidates, added, ent)
    if !GSIsValidSpikeTarget(ent) or added[ent] then return end

    added[ent] = true
    candidates[#candidates + 1] = ent
end

local function GSGetSpikeGroundContactEnt(state)
    local parent = state.parent
    if !IsValid(parent) then return nil end

    local filter, added, candidates = {}, {}, {}

    GSBuildSpikeGroundFilter(state, filter)
    GSAddGroundCandidate(candidates, added, parent)

    local constrainedEnts = constraint.GetAllConstrainedEntities(parent)

    if constrainedEnts then
        for ent in pairs(constrainedEnts) do
            GSAddGroundCandidate(candidates, added, ent)
        end
    end

    for _, ent in ipairs(parent:GetChildren()) do GSAddGroundCandidate(candidates, added, ent) end

    table.sort(candidates, function(a, b) return a:EntIndex() < b:EntIndex() end)

    for i = 1, #candidates do
        local ent = candidates[i]
        local tr = GSIsEntTouchingGround(ent, filter)

        if tr then return ent, tr.HitNormal end
    end
end

local function GSSetVehicleLowered(state, lowered)
    if !IsValid(state.parent) then return end

    state.vehicleLowered = lowered
    state.vehicleLockPos.z = state.vehicleStartZ - (lowered - (state.vehicleStartLowered or 0))

    state.parent:SetPos(state.vehicleLockPos)
    state.parent:SetAngles(state.vehicleLockAng)
end

local function GSPauseTransition(state, curTime, vehicle)
    local duration = math.max((state.transitionEnd or curTime) - (state.transitionStart or curTime), deployTimeMin)
    local frac = math.Clamp((curTime - (state.transitionStart or curTime)) / duration, 0, 1)

    state.transitionStart = curTime - (frac * duration)
    state.transitionEnd = state.transitionStart + duration

    if vehicle and IsValid(state.parent) then
        state.vehicleStartZ = state.vehicleLockPos.z + ((state.vehicleLowered or 0) - (state.vehicleStartLowered or 0))
        GSSetVehicleLowered(state, state.vehicleLowered or 0)
    end
end

local function GSGetTransitionValue(state, curTime, target, startValue)
    local duration = math.max((state.transitionEnd or curTime) - (state.transitionStart or curTime), deployTimeMin)
    local t = math.Clamp((curTime - (state.transitionStart or curTime)) / duration, 0, 1)
    return t, t >= 1 and target or Lerp(t, startValue, target)
end

local function GSGetParentVehicleTarget(state)
    local target, count = 0, 0

    for i = #state.spikes, 1, -1 do
        local spike = state.spikes[i]

        if IsValid(spike) then
            count = count + 1

            if spike.GSSpikeState then
                target = math.max(target, spike.GSSpikeState.spikeTargetLowered or 0)
            end
        else
            table.remove(state.spikes, i)
        end
    end

    return target, count
end

local function GSStartVehicleTransition(state, target, deployTime)
    if !state or !IsValid(state.parent) then return end
    if state.vehicleTargetLowered == target then return end

    local pos = state.parent:GetPos()
    local ang = state.parent:GetAngles()

    state.vehicleLockPos.x = pos.x
    state.vehicleLockPos.y = pos.y
    state.vehicleLockPos.z = pos.z
    state.vehicleLockAng.p = ang.p
    state.vehicleLockAng.y = ang.y
    state.vehicleLockAng.r = ang.r
    state.vehicleStartZ = pos.z
    state.vehicleStartLowered = state.vehicleLowered or 0
    state.vehicleTargetLowered = target

    if target > 0 then GSApplyParentAssemblyWindResistance(state, GSGetParentAssemblyWindResistance(state)) end

    state.transitionStart = CurTime()
    state.transitionEnd = state.transitionStart + math.max(deployTime or state.deployTime or deployTimeMin, deployTimeMin)

    if !state.frozen then GSSetParentAssemblyFrozen(state, true) end
end

local function GSHandleSpikePostEntityPaste(spike, ply, ent, createdEntities)
    local data = spike.GSSpikeDupeData
    if !data then return end

    spike.GSSpikeDupeData = nil
    spike.PostEntityPaste = nil

    local parent = createdEntities and createdEntities[data.parentIndex]
    if !GSIsValidSpikeTarget(parent) then parent = spike:GetParent() end
    if !GSIsValidSpikeTarget(parent) then return end

    data.localPos = data.localPos or spike:GetLocalPos()
    data.localAng = data.localAng or spike:GetLocalAngles()
    data.deployTime = math.Clamp(data.deployTime or deployTimeMin, deployTimeMin, deployTimeMax)
    data.deployDrop = math.Clamp(data.deployDrop or deployDropMin, deployDropMin, deployDropMax)
    data.windResistance = GSSanitizeSpikeWindResistance(data.windResistance or windResistMin, data.windResistance == windResistInfinite)
    data.modelScale = math.Clamp(data.modelScale or spikeModelScale, spikeModelScaleMin, spikeModelScaleMax)
    data.deployKey = data.deployKey or 7
    data.undeployKey = data.undeployKey or 8

    GSSetupVehicleSpike(ply, spike, parent, data)
end

local function GSStartSpikeTransition(state, deployed, ply)
    if state.deployed == deployed then return end

    local deployDuration = math.max(state.deployTime or deployTimeMin, deployTimeMin)

    state.deployed = deployed
    state.spikeStartLowered = state.spikeLowered or 0
    state.spikeTargetLowered = deployed and state.deployDrop or 0
    state.transitionStart = CurTime()
    state.transitionEnd = state.transitionStart + deployDuration
    state.spike:SetNW2Bool("GSSpikeDeployed", deployed)

    local soundEnt = IsValid(state.parentState.groundContactEnt) and state.parentState.groundContactEnt or state.parent

    GSSendSpikeSound(ply or state.spike:GetOwner(), deployDuration, soundEnt, state.spike, deployed)

    state.parentState.deployTime = state.deployTime or state.parentState.deployTime

    GSStartVehicleTransition(state.parentState, GSGetParentVehicleTarget(state.parentState), state.deployTime)
end

local function GSForceSpikeUndeployed(state)
    state.deployed = false
    state.spikeLowered = 0
    state.spikeStartLowered = 0
    state.spikeTargetLowered = 0
    state.transitionStart = 0
    state.transitionEnd = 0
    state.spike:SetNW2Bool("GSSpikeDeployed", false)

    GSSetSpikeVisualLowered(state, 0)
    GSSendSpikeSound(state.spike:GetOwner(), -1, NULL, state.spike:EntIndex())

    GSResetParentSpikeLowering(state.parentState, true)
end

local function GSHandleSpikeToggle(ply, spike, deployed)
    if !IsValid(spike) then return end

    local state = spike.GSSpikeState
    if !state or !IsValid(state.parent) or !state.parentState then return end

    local frame = FrameNumber()
    if state.lastToggleFrame == frame then return end

    if deployed then
        state.parentState.groundContactEnt, state.parentState.groundContactNormal = GSGetSpikeGroundContactEnt(state.parentState)

        if !IsValid(state.parentState.groundContactEnt) or !state.parentState.groundContactNormal or -state.spike:GetForward():Dot(state.parentState.groundContactNormal) < spikeDeployGroundDot or state.parent:GetVelocity():LengthSqr() > spikeDeploySpeedMaxSqr then
            state.parentState.groundContactEnt = nil
            state.parentState.groundContactNormal = nil
            return
        end
    end

    state.lastToggleFrame = frame

    local windspeed = deployed and GSGetGlobalWindspeedAndVectors(state.parent:GetPos(), gs_weatherEntityList.server, spikeInflowJetConvar:GetBool(), gs_env.server, CurTime(), spikeWindOut) or 0

    if deployed and windspeed >= state.windResistance then GSForceSpikeUndeployed(state) return end

    GSStartSpikeTransition(state, deployed, ply)
end

local function GSGetSpikeMoveSound()
    local reactive = GetConVar("gstorms_av_reactive_sounds")
    if reactive and reactive:GetBool() and GSGetIsPlayerInVehicle and GSGetIsPlayerInVehicle(LocalPlayer()) then return spikeSoundInside, true end
    return spikeSoundOutside, false
end

local function GSEmitSpikeSound(snd, inVehicle, ent)
    local ply = LocalPlayer()
    local sndEnt = (inVehicle and IsValid(ply) and ply) or (IsValid(ent) and ent) or (IsValid(ply) and ply)

    if sndEnt then sndEnt:EmitSound(snd) end
end

local function GSStopSpikeMoveSound(data)
    if !data then return end

    data.token = (data.token or 0) + 1
    data.loading = false
    data.playing = false
    data.fallback = false

    if IsValid(data.channel) then
        data.channel:Stop()
        data.channel = nil
    end

    if IsValid(data.soundEnt) then
        data.soundEnt:StopSound(spikeSoundOutside)
        data.soundEnt:StopSound(spikeSoundInside)
    end

    data.sound = nil
    data.soundEnt = nil
end

local function GSGetSpikeSoundVolume(data)
    if data.inVehicle then return 1 end
    if !IsValid(data.ent) or !IsValid(LocalPlayer()) then return 1 end

    local dist = LocalPlayer():GetPos():Distance(data.ent:GetPos())
    return 1 - math.Clamp((dist - spikeSoundFadeMin) / (spikeSoundFadeMax - spikeSoundFadeMin), 0, 1)
end

local function GSPlaySpikeMoveSound(sourceIndex, data, elapsed)
    local snd, inVehicle = GSGetSpikeMoveSound()

    if data.sound == snd and data.inVehicle == inVehicle and (IsValid(data.channel) or data.loading or data.fallback) then return end

    GSStopSpikeMoveSound(data)

    local ply = LocalPlayer()
    local token = (data.token or 0) + 1

    data.token = token
    data.sound = snd
    data.inVehicle = inVehicle
    data.soundEnt = (inVehicle and IsValid(ply) and ply) or (IsValid(data.ent) and data.ent) or (IsValid(ply) and ply)
    data.loading = true
    data.playing = true

    sound.PlayFile("sound/" .. snd, "noplay", function(channel)
        if activeSpikeSounds[sourceIndex] != data or token != data.token then
            if IsValid(channel) then channel:Stop() end
            return
        end

        data.loading = false

        if !IsValid(channel) then
            data.fallback = true
            GSEmitSpikeSound(snd, inVehicle, data.ent)
            return
        end

        data.channel = channel

        channel:SetVolume(GSGetSpikeSoundVolume(data))

        local seekTime = math.Clamp(elapsed or 0, 0, math.max(channel:GetLength() - 0.01, 0))

        if seekTime > 0 then channel:SetTime(seekTime) end

        channel:Play()
    end)
end

local function GSUpdateActiveSpikeSounds(curTime)
    local ply = LocalPlayer()
    local plyPos = IsValid(ply) and ply:GetPos()
    local _, inVehicle = GSGetSpikeMoveSound()

    table.Empty(activeSpikeSoundList)

    for sourceIndex, data in pairs(activeSpikeSounds) do
        if curTime >= data.endTime or !IsValid(data.ent) or next(data.spikes) == nil then
            activeSpikeSounds[sourceIndex] = nil

            for spikeIndex in pairs(data.spikes) do activeSpikeSoundSpikes[spikeIndex] = nil end

            local wasPlaying = data.playing
            local ent = data.ent

            GSStopSpikeMoveSound(data)

            if wasPlaying and IsValid(ent) then 
                GSEmitSpikeSound(spikeSoundDeployed, inVehicle, ent) 
            end
        else
            data.distSqr = plyPos and plyPos:DistToSqr(data.ent:GetPos()) or 0

            if inVehicle or data.distSqr < spikeSoundFadeMaxSqr then
                data.sourceIndex = sourceIndex
                activeSpikeSoundList[#activeSpikeSoundList + 1] = data
            else
                GSStopSpikeMoveSound(data)
            end
        end
    end

    table.sort(activeSpikeSoundList, function(a, b) return a.distSqr < b.distSqr end)

    for i = 1, #activeSpikeSoundList do
        local data = activeSpikeSoundList[i]

        if i <= spikeSoundMaxChannels then
            GSPlaySpikeMoveSound(data.sourceIndex, data, math.Clamp(curTime - data.startTime, 0, data.duration))
            if IsValid(data.channel) then data.channel:SetVolume(GSGetSpikeSoundVolume(data)) end
        else
            GSStopSpikeMoveSound(data)
        end
    end
end

local function GSClearSpikeGhost(tool)
    if !IsValid(tool.SpikeGhost) then return end
    tool.SpikeGhost:Remove()
    tool.SpikeGhost = nil
end

if CLIENT then

    language.Add("tool.gstorms_spike_tool.name", GSSortText(4, "Hydraulic Spikes"))
    language.Add("tool.gstorms_spike_tool.desc", "Attaches deployable wind-resistant spikes to vehicles or props")
    language.Add("tool.gstorms_spike_tool.left", "Attach spike")

    net.Receive("gs_spike_sound", function()
        local duration = net.ReadFloat()
        local ent = net.ReadEntity()
        local spikeIndex = net.ReadUInt(16)
        local deployed = net.ReadBool()

        if spikeIndex <= 0 then return end

        if duration < 0 then
            local sourceIndex = activeSpikeSoundSpikes[spikeIndex]
            local data = sourceIndex and activeSpikeSounds[sourceIndex]

            activeSpikeSoundSpikes[spikeIndex] = nil

            if data then
                data.spikes[spikeIndex] = nil

                if next(data.spikes) == nil then
                    activeSpikeSounds[sourceIndex] = nil
                    GSStopSpikeMoveSound(data)
                    GSUpdateActiveSpikeSounds(CurTime())
                end
            end

            return
        end

        local curTime = CurTime()
        local sourceIndex = IsValid(ent) and ent:EntIndex() or spikeIndex
        local oldSourceIndex = activeSpikeSoundSpikes[spikeIndex]
        local data = activeSpikeSounds[sourceIndex]

        duration = math.max(duration, 0)

        if oldSourceIndex and oldSourceIndex != sourceIndex and activeSpikeSounds[oldSourceIndex] then 
            activeSpikeSounds[oldSourceIndex].spikes[spikeIndex] = nil 
        end

        if !data then
            data = {ent = ent, spikes = {}, deployed = deployed, duration = duration, startTime = curTime, endTime = curTime + duration}
            activeSpikeSounds[sourceIndex] = data
        else
            local endTime = curTime + duration

            data.ent = ent
            data.spikes = data.spikes or {}

            if data.deployed != deployed or curTime - (data.startTime or 0) > 0.1 then
                GSStopSpikeMoveSound(data)

                data.deployed = deployed
                data.duration = duration
                data.startTime = curTime
                data.endTime = endTime
            else
                data.endTime = math.max(data.endTime or 0, endTime)
                data.duration = math.max(data.duration or 0, data.endTime - data.startTime)
            end
        end

        data.spikes[spikeIndex] = true
        activeSpikeSoundSpikes[spikeIndex] = sourceIndex

        GSUpdateActiveSpikeSounds(curTime)
    end)

    hook.Add("Think", "gstorms_spike_tool_sound_think", function()
        if !next(activeSpikeSounds) then return end
        GSUpdateActiveSpikeSounds(CurTime())
    end)

    for key, defaultValue in pairs(TOOL.ClientConVar) do
        local name = "gstorms_spike_tool_" .. key

        if !ConVarExists(name) then
            CreateClientConVar(name, defaultValue, true, true)
        else
            local convar = GetConVar(name)
            local value = convar and string.lower(convar:GetString() or "") or ""

            if value == "" or value == "nil" or value == "nan" then RunConsoleCommand(name, defaultValue) end
        end
    end

    local function GSCreateSpikeKeyButton(parent, convar, label)
        local key = vgui.Create("CtrlNumPad", parent)
        key:SetSize(170, 52)
        key:SetConVar1(convar)
        key:SetLabel1(label)
        return key
    end

    function TOOL.BuildCPanel(panel)
        GSAddCollapsibleSection(panel, "Spike Options", true, function(option)
            GSCheckBox(option, "Enable Invulnerability", "gstorms_spike_tool_invulnerability"):SetTooltip("Disables unfreezing and unwelding for the vehicle/prop and spike, making them immune to all wind speeds.")
            GSNumSlider(option, "Wind Resistance (MPH)", "gstorms_spike_tool_windresistance", windResistMin, windResistMax, 0):SetTooltip("Applies this wind resistance to both the vehicle/prop and the spawned spike")
            GSNumSlider(option, "Deploy Time (Seconds)", "gstorms_spike_tool_deploytime", deployTimeMin, deployTimeMax, 1):SetTooltip("How long the spike takes to deploy and retract")
            GSNumSlider(option, "Drop Down Amount (HU)", "gstorms_spike_tool_deploydrop", deployDropMin, deployDropMax, 0):SetTooltip("The amount that the spikes will lower into the ground")
            GSNumSlider(option, "Model Scale", "gstorms_spike_tool_modelscale", spikeModelScaleMin, spikeModelScaleMax, 1):SetTooltip("The visual scale of the spawned spike model")
        end)

        local keyRow = vgui.Create("DPanel")
        keyRow:Dock(TOP)
        keyRow:SetTall(76)
        keyRow:DockMargin(0, 6, 0, 0)
        keyRow.Paint = nil

        local deployKey = GSCreateSpikeKeyButton(keyRow, "gstorms_spike_tool_deploykey", "Deploy Key")
        local undeployKey = GSCreateSpikeKeyButton(keyRow, "gstorms_spike_tool_undeploykey", "Undeploy Key")

        function keyRow:PerformLayout(w, h)
            local buttonW = math.min(170, math.max(w - 16, 1))
            local buttonH = 52
            local gap = math.min(64, math.max(24, math.floor(w * 0.12)))

            deployKey:SetSize(buttonW, buttonH)
            undeployKey:SetSize(buttonW, buttonH)

            if w < buttonW * 2 + gap then
                if self:GetTall() != 152 then self:SetTall(152) end

                deployKey:SetPos(math.floor((w - buttonW) * 0.5), 0)
                undeployKey:SetPos(math.floor((w - buttonW) * 0.5), 78)

                return
            end

            if self:GetTall() != 76 then self:SetTall(76) end

            local totalW = buttonW * 2 + gap
            local startX = math.floor((w - totalW) * 0.5)

            deployKey:SetPos(startX, 0)
            undeployKey:SetPos(startX + buttonW + gap, 0)
        end

        panel:AddItem(keyRow)
    end

    function TOOL:MakeSpikeGhost()

        if IsValid(self.SpikeGhost) then return self.SpikeGhost end

        self.SpikeGhost = ClientsideModel(spikeModel, RENDERGROUP_TRANSLUCENT)

        if !IsValid(self.SpikeGhost) then return end

        self.SpikeGhost:SetMaterial(spikeMaterial)
        self.SpikeGhost:SetRenderMode(RENDERMODE_TRANSCOLOR)
        self.SpikeGhost:SetColor(ghostColor)
        self.SpikeGhost:SetMoveType(MOVETYPE_NONE)
        self.SpikeGhost:SetNotSolid(true)
        self.SpikeGhost:SetNoDraw(true)
        self.SpikeGhost:SetModelScale(spikeModelScale, 0)

        return self.SpikeGhost

    end

    function TOOL:Think()

        if !LocalPlayer():IsValid() then return end

        local ghost = self:MakeSpikeGhost()
        if !IsValid(ghost) then return end

        local trace = LocalPlayer():GetEyeTrace()

        if !trace.Hit or !GSIsValidSpikeTarget(trace.Entity) then ghost:SetNoDraw(true) return end

        local pos, ang = GSGetSpikePlacement(trace, LocalPlayer())

        ghost:SetNoDraw(false)
        ghost:SetModelScale(math.Clamp(self:GetClientNumber("modelscale", spikeModelScale), spikeModelScaleMin, spikeModelScaleMax), 0)
        ghost:SetPos(pos)
        ghost:SetAngles(ang)
    end

    function TOOL:Holster() GSClearSpikeGhost(self) end
    function TOOL:OnRemove() GSClearSpikeGhost(self) end

end

if SERVER then

    duplicator.RegisterEntityModifier("gstorms_spike", function(ply, spike, data)
        if !IsValid(spike) or !data then return end

        spike.GSSpikeDupeData = data
        spike.PostEntityPaste = GSHandleSpikePostEntityPaste
    end)

    numpad.Register("GStormsSpikeDeploy", function(ply, spike) GSHandleSpikeToggle(ply, spike, true) end)
    numpad.Register("GStormsSpikeUndeploy", function(ply, spike) GSHandleSpikeToggle(ply, spike, false) end)

    hook.Add("Think", "gstorms_spike_tool_deploy_think", function()

        local curTime = CurTime()

        for i = #gsSpikeParentStatesList, 1, -1 do
            local state = gsSpikeParentStatesList[i]
            local parent = state.parent
            local target, count = GSGetParentVehicleTarget(state)

            if !IsValid(parent) then
                gsSpikeParentStates[parent] = nil
                table.remove(gsSpikeParentStatesList, i)
                continue
            end

            if count <= 0 then
                if (state.vehicleLowered or 0) > 0 then GSSetVehicleLowered(state, 0) end

                GSResetParentSpikeLowering(state, true)

                gsSpikeParentStates[parent] = nil
                table.remove(gsSpikeParentStatesList, i)
                continue
            end

            local phys = state.frozen and parent:GetPhysicsObject()

            if phys and phys:IsValid() and phys:IsMotionEnabled() then
                for k = #state.spikes, 1, -1 do
                    local _, spikeState = GSGetValidSpikeState(state, k)
                    if spikeState then GSForceSpikeUndeployed(spikeState) end
                end

                continue
            end

            local windspeed = GSGetGlobalWindspeedAndVectors(parent:GetPos(), gs_weatherEntityList.server, spikeInflowJetConvar:GetBool(), gs_env.server, curTime, spikeWindOut)
            local targetDirty = false

            for k = #state.spikes, 1, -1 do
                local _, spikeState = GSGetValidSpikeState(state, k)

                if spikeState and spikeState.deployed and windspeed >= spikeState.windResistance then
                    GSForceSpikeUndeployed(spikeState)
                    targetDirty = true
                end
            end

            if targetDirty then target = GSGetParentVehicleTarget(state) end

            GSStartVehicleTransition(state, target, state.deployTime)

            local filter = {}
            GSBuildSpikeGroundFilter(state, filter)

            if !GSIsEntTouchingGround(state.groundContactEnt, filter) then
                if state.vehicleLowered != state.vehicleTargetLowered then GSPauseTransition(state, curTime, true) end

                for k = #state.spikes, 1, -1 do
                    local _, spikeState = GSGetValidSpikeState(state, k)

                    if spikeState and spikeState.spikeLowered != spikeState.spikeTargetLowered then
                        GSPauseTransition(spikeState, curTime)
                    end
                end

                continue
            end

            for k = #state.spikes, 1, -1 do
                local _, spikeState = GSGetValidSpikeState(state, k)

                if !spikeState then continue end
                if spikeState.spikeLowered == spikeState.spikeTargetLowered then continue end

                local _, newSpikeLowered = GSGetTransitionValue(spikeState, curTime, spikeState.spikeTargetLowered or 0, spikeState.spikeStartLowered)

                spikeState.spikeLowered = newSpikeLowered
                GSSetSpikeVisualLowered(spikeState, newSpikeLowered)
            end

            if state.vehicleLowered == state.vehicleTargetLowered then
                if state.frozen != (state.vehicleTargetLowered > 0) then GSSetParentAssemblyFrozen(state, state.vehicleTargetLowered > 0) end
                if state.vehicleTargetLowered <= 0 then GSRestoreParentAssemblyWindResistance(state) end
                continue
            end

            local t, newVehicleLowered = GSGetTransitionValue(state, curTime, state.vehicleTargetLowered or 0, state.vehicleStartLowered)

            GSSetVehicleLowered(state, newVehicleLowered)

            if t >= 1 and state.vehicleTargetLowered > 0 and !state.frozen then GSSetParentAssemblyFrozen(state, true) end
        end

    end)

end

function TOOL:LeftClick(trace)

    if CLIENT then return true end

    if !GSIsValidSpikeTarget(trace.Entity) then return false end
    if !trace.Entity:GetPhysicsObject():IsValid() then return false end

    local ply = self:GetOwner()
    local pos, ang = GSGetSpikePlacement(trace, ply)
    local spike = ents.Create("prop_physics")
    if !IsValid(spike) then return false end

    GSSetupVehicleSpike(ply, spike, trace.Entity, {
        localPos = trace.Entity:WorldToLocal(pos),
        localAng = trace.Entity:WorldToLocalAngles(ang),
        deployTime = math.Clamp(self:GetClientNumber("deploytime", 1), deployTimeMin, deployTimeMax),
        deployDrop = math.Clamp(self:GetClientNumber("deploydrop", 5), deployDropMin, deployDropMax),
        windResistance = GSSanitizeSpikeWindResistance(self:GetClientNumber("windresistance", windResistMin), GSBool(self:GetClientNumber("invulnerability", 0))),
        modelScale = math.Clamp(self:GetClientNumber("modelscale", spikeModelScale), spikeModelScaleMin, spikeModelScaleMax),
        deployKey = self:GetClientNumber("deploykey", 7),
        undeployKey = self:GetClientNumber("undeploykey", 8)
    }, true, true)

    return true

end