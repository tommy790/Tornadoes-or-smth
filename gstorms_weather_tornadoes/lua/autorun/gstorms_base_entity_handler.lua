include("gstorms_funcs/gstorms_shared.lua")

local mathClamp = math.Clamp
local mathMin = math.min
local mathMax = math.max
local mathSqrt = math.sqrt
local mathRandom = math.random
local GetConVar = GetConVar
local Lerp = Lerp
local dmg = DamageInfo()
local moveTypeVPhysics = MOVETYPE_VPHYSICS

local audioParams = { farSoundMaxVolume = 0.5, farSoundVolumeExponent = 0.5, farSoundMinPitch = 30, farSoundMaxPitch = 150, farSoundPitchWidthMax = 12500, farSoundPitchWidthMin = 1500, closeSoundMinPitch = 40, closeSoundMaxPitch = 250, lightSoundMinPitch = 75, lightSoundMaxPitch = 125 }
local audioFiles = { close = {path = "tornado/Tornado_Close.wav", name = "TornadoCloseSound"}, far = {path = "tornado/Tornado_Far.wav", name = "TornadoFarSound"}, lightWinds = {path = "tornado/Storm_Winds.wav", name = "LightWindsSound"} }
local audioKeys = {}
local audioKeyOwners = {}

local GSGetIsVehicle = GSGetIsVehicle
local GSGranulateAndMudCoat = GSGranulateAndMudCoat
local GSDamagePlayers = GSDamagePlayers
local GSGetStormReflectivityValueFromPoint = GSGetStormReflectivityValueFromPoint
local GSRemoveConstraintsWindspeed = GSRemoveConstraintsWindspeed
local GSHandlePowerflash = GSHandlePowerflash
local GSGetMassFalloff = GSGetMassFalloff
local GSGetGlobalWindspeedAndVectors = GSGetGlobalWindspeedAndVectors
local GSGetModifiedTornadoOffsetFromHeightAndNoise = GSGetModifiedTornadoOffsetFromHeightAndNoise
local GSWindOcclusion = GSWindOcclusion
local GSGetIsPlayerInVehicle = GSGetIsPlayerInVehicle
local GSWindspeedScreenshake = GSWindspeedScreenshake
local GSSetPostProcessFog = GSSetPostProcessFog
local GSGetGlobalMagnitude = GSGetGlobalMagnitude
local GSRemoveConstraintsEarthquake = GSRemoveConstraintsEarthquake

local engineTickInterval = engine.TickInterval
local entsGetAll = ents.GetAll
local entsFindByClass = ents.FindByClass
local propList, propListIndex, propListCount = {}, {}, 0

local nextThink = CurTime()
local lastRainSound = CurTime()
local lastEarthquakeSound = CurTime()

local windApplyMult = 4
local baseStrengthMult = 2
local pitchMult = 0.25
local rollMult = 1
local yawMult = 0.25
local addZ1 = 3 * 0.125
local addZ2 = 33 * 0.125

local nilVector = Vector(0, 0, 0)
local angularAxisScratch = Vector(0, 0, 0)
local outVec = Vector(0, 0, 0)
local earthquakeOut = Vector(0, 0, 0)
local outVecClient = Vector(0, 0, 0)
local outVecClientShake = Vector(0, 0, 0)
local closestTornadoPosModScratch = Vector(0, 0, 0)

local gsViewPos, gsViewEnt, gsAudioAnchor
local zeroAng = Angle(0, 0, 0)

gs_weatherEntityList = gs_weatherEntityList or {server = {}, client = {}}
gs_earthquakeList = gs_earthquakeList or {server = {}, client = {}}
gs_env = gs_env or {server = {}, client = {}}

local function GSStopAllPlayerSounds()
    for key, snd in pairs(audioKeys) do
        if snd then snd:FadeOut(0.1) end
        audioKeys[key] = nil
        audioKeyOwners[key] = nil
    end
end

local function GSApplyPlayerSound(soundEnt, key, file, vol, pitch)
    if !IsValid(soundEnt) then return false end

    local snd = audioKeys[key]
    local owner = audioKeyOwners[key]

    if vol <= 0 then
        if snd then snd:FadeOut(0.1) audioKeys[key] = nil end
        audioKeyOwners[key] = nil
        return false
    end

    if snd and owner ~= soundEnt then
        snd:FadeOut(0.1)
        snd = nil
        owner = nil
        audioKeys[key] = nil
        audioKeyOwners[key] = nil
    end

    if !snd then
        snd = CreateSound(soundEnt, file)
        snd:PlayEx(0, 100)
        audioKeys[key] = snd
        audioKeyOwners[key] = soundEnt
    end

    snd:ChangeVolume(vol, 0.1)
    snd:ChangePitch(pitch, 0.1)

    return true
end

local function GSAudioHandler(ply, soundEnt, curTime, ws, reactiveSounds, entityList, occlusionMult, inVehicle, playerPos)

    if !IsValid(ply) or !IsValid(soundEnt) then return end

    local sumPow, pitchPowSum = 0, 0

    local wsThresh = mathMax(ws - 40, 0)
    local closeVol = mathClamp(wsThresh * 0.02, 0, 1)
    local closePitch = mathClamp(audioParams.closeSoundMinPitch + (wsThresh * 0.005 * (audioParams.closeSoundMaxPitch - audioParams.closeSoundMinPitch)), audioParams.closeSoundMinPitch, audioParams.closeSoundMaxPitch)
    local lightVol = mathClamp(ws / 60, 0, 1) * 0.5
    local lightPitch = mathClamp(audioParams.lightSoundMinPitch + ((ws / 120) * (audioParams.lightSoundMaxPitch - audioParams.lightSoundMinPitch)), audioParams.lightSoundMinPitch, audioParams.lightSoundMaxPitch)
    local enableRain = false

    for _, t in ipairs(entityList) do

        if !t:IsValid() or !t.Networked then continue end
        if t.EnableRain then enableRain = true end

        local size, maxWS

        if t.Flow then
            size, maxWS = t.FlowDistRadCurrent, t.FlowWindspeed
        else
            size, maxWS = t.VortexSize, t.VortexWindspeed
        end

        local dist = playerPos:Distance(t.Position)
        local farMaxDist = size + (2000 * (1 + (maxWS * 0.02)))
        local base = 1 - ((dist / farMaxDist) ^ audioParams.farSoundVolumeExponent)
        local v = mathClamp(base * audioParams.farSoundMaxVolume, 0, 1) * mathClamp(maxWS / 65, 0, 1)

        if v > 0 then
            local p = mathClamp(audioParams.farSoundMaxPitch + (size - audioParams.farSoundPitchWidthMin) * (audioParams.farSoundMinPitch - audioParams.farSoundMaxPitch) / (audioParams.farSoundPitchWidthMax - audioParams.farSoundPitchWidthMin), audioParams.farSoundMinPitch, audioParams.farSoundMaxPitch)
            local w = v * v
            sumPow = sumPow + w
            pitchPowSum = pitchPowSum + p * w
        end

    end

    local farVol = mathMin(1, mathSqrt(sumPow))
    local farPitch = (sumPow > 0) and (pitchPowSum / sumPow) or audioParams.farSoundMinPitch

    if inVehicle and reactiveSounds then
        farVol, closeVol = farVol * 0.66, closeVol * 0.66
        farPitch, closePitch = farPitch * 0.5, closePitch * 0.5
        lightVol, lightPitch = lightVol * 0.66, lightPitch * 0.5
    end

    GSApplyPlayerSound(soundEnt, audioFiles.far.name, audioFiles.far.path, farVol, farPitch)
    GSApplyPlayerSound(soundEnt, audioFiles.close.name, audioFiles.close.path, closeVol, closePitch)
    GSApplyPlayerSound(soundEnt, audioFiles.lightWinds.name, audioFiles.lightWinds.path, lightVol, lightPitch)

    local reflectivityVal = GSGetStormReflectivityValueFromPoint(playerPos, false, entityList)

    if curTime - lastRainSound >= 0.4 and reflectivityVal ~= 0 and enableRain and gs_env.client.Temperature > 0 then
        local occluded = (inVehicle or occlusionMult <= 0.5)
        local stringRain = occluded and "storms/rain/rain_muted.wav" or "storms/rain/rain_unmuted.wav"
        local rainSoundMul = occluded and 0.5 or 1

        soundEnt:EmitSound(stringRain, 50, mathRandom(90, 110), Lerp(reflectivityVal * 0.02, 0, 0.3) * rainSoundMul)
        lastRainSound = curTime
    end

end

local function GSEarthquakeAudioHandler(soundEnt, magnitude, curTime)
    if curTime - lastEarthquakeSound >= 0.9 and magnitude > 0 then
        soundEnt:EmitSound("earthquake/gstorms_earthquake_sound.wav", 75, mathRandom(90, 110), (magnitude * 0.1) ^ 1.5)
        lastEarthquakeSound = curTime
    end
end

local function GSGetAngularVelocity(prop, phys, totalDir, windspeed, mult)
	if !prop:IsValid() or !phys:IsValid() then return nilVector end

	local x, y = totalDir.x, totalDir.y
	local horizLenSqr = x * x + y * y

	if horizLenSqr == 0 then return nilVector end

	local invLen = 1 / mathSqrt(horizLenSqr)

	angularAxisScratch:SetUnpacked(-y * invLen, x * invLen, 0)

	local localAxis = phys:WorldToLocalVector(angularAxisScratch)
	local scale = windspeed * baseStrengthMult * mult

	localAxis:SetUnpacked(localAxis.x * pitchMult * scale, localAxis.y * rollMult * scale, localAxis.z * yawMult * scale)

	return localAxis
end

function GSTemperatureHandler(prop, temperature, entity, isPlayerOrNPC, hurtPlayerCvar)
    if temperature <= 44 then return end
    if !isPlayerOrNPC and temperature >= 100 and !prop:IsOnFire() then prop:Ignite(10, 0) return end
    if !hurtPlayerCvar then return end

    dmg:SetDamage((temperature - 44) * 0.0125)
    dmg:SetDamageType(DMG_BURN)
    dmg:SetAttacker(entity)
    dmg:SetInflictor(entity)
    dmg:SetDamageForce(nilVector)
    prop:TakeDamageInfo(dmg)
    prop:Ignite(1, 0)
end

local function GSLimitAngularVelocity(addVelocity, physAngleVelocity, angularVelocityLimit) return physAngleVelocity >= angularVelocityLimit and nilVector or addVelocity end

local function GSPhysicsHandler(prop, propPos, tornado, maxWindspeed, combinedVel, mult, isPlayerOrNPC, isNPC, powerflashConvar, mudCoatCvar, granulationCvar, hurtPlayerCvar, unweldProps)

    local phys = prop:GetPhysicsObject()
    if !phys:IsValid() then return end

    local isMotionEnabled = phys:IsMotionEnabled()

    if (!isMotionEnabled or phys:IsAsleep()) and maxWindspeed <= 65 or prop.ProbeDeployed then return end

    GSHandlePowerflash(prop, maxWindspeed, isMotionEnabled, false, powerflashConvar)

    local massFalloff = GSGetMassFalloff(phys:GetMass(), maxWindspeed)

    if !isMotionEnabled and unweldProps then GSRemoveConstraintsWindspeed(prop, propPos, phys, massFalloff, tornado, maxWindspeed, isMotionEnabled, powerflashConvar) return end

    local isOnGround = prop:IsOnGround()
    local generalMult = 0.5

    if !isPlayerOrNPC and prop:IsRagdoll() then generalMult = 1.33 end

    local combinedMult = (isOnGround and 0.5 or 1) * generalMult * massFalloff * mult

    if !isPlayerOrNPC then
        phys:AddVelocity(combinedVel * combinedMult)
        
        if prop.GSVehicle then 
            local velLimit = GSLimitAngularVelocity(GSGetAngularVelocity(prop, phys, combinedVel, maxWindspeed, combinedMult), phys:GetAngleVelocity():Length(), 250)
            phys:AddAngleVelocity(velLimit) 
        end

        GSGranulateAndMudCoat(prop, tornado, maxWindspeed, mudCoatCvar, granulationCvar)
    else
        combinedVel.z = combinedVel.z + ((isOnGround and (isNPC and addZ1 or addZ2) or 0) * maxWindspeed)
        prop:SetVelocity(combinedVel * combinedMult * 0.35)
        GSDamagePlayers(prop, tornado, maxWindspeed, hurtPlayerCvar)
    end

end

local function GSPropListRemove(ent)
    local idx = propListIndex[ent]
    if !idx then return end

    local lastIdx = propListCount
    local last = propList[lastIdx]

    propList[idx] = last
    propList[lastIdx] = nil
    propListCount = lastIdx - 1

    if last and last ~= ent then propListIndex[last] = idx end
    propListIndex[ent] = nil
end

local function GSPropListAdd(ent)
    if !IsValid(ent) then return end
    if propListIndex[ent] then return end

    local idx = propListCount + 1
    propList[idx] = ent
    propListIndex[ent] = idx
    propListCount = idx

    ent.GSVehicle = GSGetIsVehicle(ent, ent:GetClass())
    ent:CallOnRemove("GS_PropList_Remove", GSPropListRemove)
end

local function GSPropListInit()
    propList = {}
    propListIndex = {}
    propListCount = 0

    for _, ent in ipairs(entsGetAll()) do
        GSPropListAdd(ent)
    end
end

if SERVER then
    GSPropListInit()

    hook.Add("OnEntityCreated", "GS_PropList_OnEntityCreated", function(ent)
        timer.Simple(0, function()
            GSPropListAdd(ent)
        end)
    end)

    hook.Add("PostCleanupMap", "GS_PropList_OnCleanup", function()
        GSPropListInit()
    end)
end

local function GSServersideEarthquakeHandling(prop, propPos, powerflashConvar, earthquakeList, unweldProps)
    local mag, force = GSGetGlobalMagnitude(propPos, earthquakeList, earthquakeOut)
    local phys = prop:GetPhysicsObject()

    if !phys:IsValid() then return end
    if unweldProps then GSRemoveConstraintsEarthquake(prop, propPos, phys, mag, powerflashConvar) end

    force:Mul(3.5)
    phys:AddVelocity(force)
end

local function GSServersideHandler(curTime)

    local envEnt = gs_env.server
    if !envEnt then return end

    local inflowJetConvar = GetConVar("gstorms_tornado_inflow_jet"):GetBool()
    local powerflashConvar = GetConVar("gstorms_av_powerflashes"):GetBool()
    local mudCoatCvar = GetConVar("gstorms_av_mud_coating"):GetBool()
    local granulationCvar = GetConVar("gstorms_sim_granulation"):GetBool()
    local hurtPlayerCvar = GetConVar("gstorms_sim_hurt_players"):GetBool()
    local unweldProps = GetConVar("gstorms_sim_unweld_props"):GetBool()
    local windOcclusionConvar = GetConVar("gstorms_sim_wind_occlusion"):GetBool()
    local entityList = gs_weatherEntityList.server
    local earthquakeList, hasEarthquake = gs_earthquakeList.server, false

    for i = 1, #earthquakeList do
        local ent = earthquakeList[i]
        if !IsValid(ent) or !ent.Networked then continue end
        if ent.CurrentMagnitude >= 1 then hasEarthquake = true break end
    end

    for i = 1, propListCount do
        local prop = propList[i]

        if !IsValid(prop) then GSPropListRemove(prop) continue end

        local isNPC = prop:IsNPC()
        local isPlayerOrNPC = prop:IsPlayer() or isNPC

        if !(prop:GetMoveType() == moveTypeVPhysics or isPlayerOrNPC) then continue end

        local pos = prop:GetPos()
        local windspeed, dir, temperature, tornado = GSGetGlobalWindspeedAndVectors(pos, entityList, inflowJetConvar, envEnt, curTime, outVec)

        if hasEarthquake then GSServersideEarthquakeHandling(prop, pos, powerflashConvar, earthquakeList, unweldProps) end
        if temperature > 44 then GSTemperatureHandler(prop, temperature, tornado, isPlayerOrNPC, hurtPlayerCvar) end
        if windspeed < 1 then continue end
        if windOcclusionConvar then windspeed = GSWindOcclusion(prop, pos, windspeed, dir) end

        GSPhysicsHandler(prop, pos, tornado, windspeed, dir, windApplyMult, isPlayerOrNPC, isNPC, powerflashConvar, mudCoatCvar, granulationCvar, hurtPlayerCvar, unweldProps)

    end
end

local function GSEnsureAudioAnchor()
    if IsValid(gsAudioAnchor) then return gsAudioAnchor end

    gsAudioAnchor = ClientsideModel("models/hunter/blocks/cube025x025x025.mdl", RENDERGROUP_OTHER)
    if !IsValid(gsAudioAnchor) then return nil end

    gsAudioAnchor:SetNoDraw(true)
    gsAudioAnchor:SetNotSolid(true)
    gsAudioAnchor:DrawShadow(false)
    gsAudioAnchor:SetMoveType(MOVETYPE_NONE)

    return gsAudioAnchor
end

hook.Add("RenderScene", "GSAudioCachedRenderView", function(origin)
    gsViewPos = origin
    gsViewEnt = GetViewEntity()

    local anchor = GSEnsureAudioAnchor()
    if IsValid(anchor) then
        anchor:SetPos(origin)
        anchor:SetAngles(zeroAng)
    end
end)

local function GSClientsideHandler(curTime)

    local envEnt = gs_env.client
    if !envEnt then return end

    local ply = LocalPlayer()
    local pos = gsViewPos or EyePos()
    local viewEnt = IsValid(gsViewEnt) and gsViewEnt or GetViewEntity()
    local soundEnt = IsValid(gsAudioAnchor) and gsAudioAnchor or ply
    local occEnt = IsValid(viewEnt) and viewEnt or ply
    local reactive = GetConVar("gstorms_av_reactive_sounds"):GetBool()

    local entityList = gs_weatherEntityList.client
    local windspeed, dir, _, closest, tornadoWS = GSGetGlobalWindspeedAndVectors(pos, entityList, GetConVar("gstorms_tornado_inflow_jet"):GetBool(), envEnt, curTime, outVecClient)
    local shakeMagnitude = GSGetGlobalMagnitude(pos, gs_earthquakeList.client, outVecClientShake)

    if !closest then return end

    local windspeedAudio = windspeed
    local occMult = 1
    local inVehicle = GSGetIsPlayerInVehicle(ply)

    if !inVehicle then windspeed, occMult = GSWindOcclusion(occEnt, pos, windspeed, dir) end

    tornadoWS = tornadoWS * occMult

    GSAudioHandler(ply, soundEnt, curTime, reactive and windspeedAudio * (occMult * 0.5 + 0.5) or windspeedAudio, reactive, entityList, occMult, inVehicle, pos)
    GSEarthquakeAudioHandler(soundEnt, shakeMagnitude, curTime)

    if !ply:IsOnGround() then shakeMagnitude = 0 end

    if GetConVar("gstorms_av_custom_screenshake"):GetBool() then GSWindspeedScreenshake(ply, windspeed, 50, 0, 320, 320, 0, inVehicle, shakeMagnitude, 10, 100, 150) end

    if GetConVar("gstorms_av_post_processing"):GetBool() then

        if closest != envEnt and !closest.Flow then

            local closestEntPos = closest.Position or closest:GetPos()
            local closestEntPosX, closestEntPosY, closestEntPosZ = closestEntPos.x, closestEntPos.y, closestEntPos.z
            local distanceZ = mathMax(pos.z - closestEntPosZ, 0)
            local anti = closest.Anticyclonic
            local maxH = closest.FunnelMaxHeight
            local tornadoOffX, tornadoOffY = GSGetModifiedTornadoOffsetFromHeightAndNoise(distanceZ, closest.VortexPositionNoiseFrequency, closest.VortexPositionNoiseAmplitude, closest.VortexPositionNoiseSpeed, anti, closest.VortexPositionNoiseSeed, closest.VortexPositionNoisePhase, curTime, closest.VortexPositionNoiseDetail, closest.VortexPositionNoisePeak, maxH)
            local tPosX, tPosY = closestEntPosX + tornadoOffX, closestEntPosY + tornadoOffY
            local dx, dy = pos.x - tPosX, pos.y - tPosY
            local closestDistance2D = mathSqrt(dx * dx + dy * dy)

            closestTornadoPosModScratch:SetUnpacked(tPosX, tPosY, closestEntPosZ)

            local distCtrl = mathClamp(1 - closestDistance2D / (closest.VortexRMWSize * 4), 0, 1) * 100
            local fogDensity = mathClamp((tornadoWS - 40) * 0.01, 0, 1) ^ 0.75

            GSSetPostProcessFog(ply, closestTornadoPosModScratch, fogDensity, tornadoWS, distCtrl, anti)

        end

    end

end

local function GSUpdateWeatherEntityList(server)
    if server then
        gs_weatherEntityList.server = entsFindByClass("gstorms_weather*")
        gs_earthquakeList.server = entsFindByClass("gstorms_earthquake*")
        gs_env.server = entsFindByClass("gstorms_env")[1]
    else
        gs_weatherEntityList.client = entsFindByClass("gstorms_weather*")
        gs_earthquakeList.client = entsFindByClass("gstorms_earthquake**")
        gs_env.client = entsFindByClass("gstorms_env")[1]
    end
end

hook.Add("Think", "GS_Global_Wind_Handler", function()

    local curTime = CurTime()
    if curTime < nextThink and (nextThink - curTime) <= 3 then return end -- The <= 3 condition prevents a critical bug where GMOD jumps curtime backwards after unpausing

    nextThink = curTime + engineTickInterval() * 5

    GSUpdateWeatherEntityList(SERVER)

    if SERVER then
        GSServersideHandler(curTime) 
    elseif CLIENT then
        GSClientsideHandler(curTime) 
    end

end)

hook.Add("PostCleanupMap", "gstorms_sound_reset", function() -- Resets all sound keys on world cleanup to prevent one bug
    if CLIENT then
        GSStopAllPlayerSounds()
    end
end)