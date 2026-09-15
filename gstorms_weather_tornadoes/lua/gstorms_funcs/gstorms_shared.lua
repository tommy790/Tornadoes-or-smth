include("gstorms_funcs/gstorms_noise.lua")
include("gstorms_funcs/gstorms_vortex_model.lua")
include("gstorms_funcs/gstorms_radar_handling.lua")

local nilVector = Vector(0, 0, 0) -- Fallback vector generated up here so the vector doesn't have to be recreated, more performant
local tinyVal = 1e-12
local mathPi = math.pi
local twoMathPi = 2 * mathPi

local mathClamp = math.Clamp
local mathMin = math.min
local mathMax = math.max
local mathSqrt = math.sqrt
local mathAbs = math.abs
local mathRandom = math.random
local mathRand = math.Rand
local mathAtan2 = math.atan2
local mathFloor = math.floor
local mathCos = math.cos
local mathSin = math.sin
local mathPow = math.pow
local mathCeil = math.ceil
local mathExp = math.exp
local mathHuge = math.huge
local stringLower = string.lower
local ipairs = ipairs
local Lerp = Lerp
local Vector = Vector

local utilTraceLine = util.TraceLine
local constraintHasConstraints = constraint.HasConstraints
local constraintRemoveAll = constraint.RemoveAll
local timerSimple = timer.Simple
local playerIterator = player.Iterator

local guiIsGameUIVisible
local notificationAddLegacy, surfacePlaySound

if CLIENT then
    guiIsGameUIVisible = gui.IsGameUIVisible
    notificationAddLegacy = notification.AddLegacy
    surfacePlaySound = surface.PlaySound
end

local netStart = net.Start
local netWriteEntity = net.WriteEntity
local netWriteString = net.WriteString
local netWriteVector = net.WriteVector
local netWriteBool = net.WriteBool
local netSend = net.Send
local netBroadcast = net.Broadcast

local GSNoise = GSNoise
local GSVortexModel = GSVortexModel
local GSReturnReflectivityHurricane = GSReturnReflectivityHurricane
local GSReturnReflectivityDerecho = GSReturnReflectivityDerecho
local GSReturnReflectivitySupercell = GSReturnReflectivitySupercell
local GSGetModifiedTornadoOffsetFromHeightAndNoise = GSGetModifiedTornadoOffsetFromHeightAndNoise

-- ############################################################## Storms & Tornadoes ##############################################################

local function GSNormalizeXYZ(x, y, z)
	local len2 = (x * x) + (y * y) + (z * z)
	
    if len2 <= tinyVal then return 0, 0, 0 end

	local invLen = 1 / mathSqrt(len2)

	return x * invLen, y * invLen, z * invLen
end

local function GSNormalizeScaledToVector(x, y, z, scale, outVec)
	local len2 = (x * x) + (y * y) + (z * z)

    if len2 <= tinyVal then outVec:SetUnpacked(0, 0, 0) return outVec end

    local mult = scale / mathSqrt(len2)
    outVec:SetUnpacked(x * mult, y * mult, z * mult)

    return outVec
end

local function GSVectorBasedAdjustedWindspeed(mainVecNormX, mainVecNormY, mainVecNormZ, secondaryVecNormX, secondaryVecNormY, secondaryVecNormZ, minWS, maxWS)
	return minWS + ((maxWS - minWS) * (((mainVecNormX * secondaryVecNormX) + (mainVecNormY * secondaryVecNormY) + (mainVecNormZ * secondaryVecNormZ) + 1) * 0.5))
end

local gsDistanceCutoffThreshold = 0.6
local invDistanceCutoff = 1 - gsDistanceCutoffThreshold

function GSMainVortexWindspeed(dx, dy, distance2D, distanceZ, vortexSize, vortexRMWSize, vortexMaxWindspeed, movementVectorX, movementVectorY, movementVectorZ, forwardsSpeedMPH, isAnticyclonic, vortexModelParameters, funnelWidthTable, funnelMaxHeight)
	vortexMaxWindspeed = vortexMaxWindspeed + forwardsSpeedMPH

	local vt, uz, vecX, vecY, vecZ = GSVortexModel(dx, dy, distance2D, distanceZ, vortexRMWSize, vortexModelParameters.zScale, vortexModelParameters.alpha, vortexModelParameters.twoCelled, vortexModelParameters.falloffExponent, isAnticyclonic, funnelWidthTable, funnelMaxHeight)
    local distanceCutoff = 1
    
    if distance2D > vortexSize * gsDistanceCutoffThreshold then
        distanceCutoff = (vortexSize - distance2D) / (vortexSize * invDistanceCutoff)
        distanceCutoff = distanceCutoff * distanceCutoff * (3 - 2 * distanceCutoff) -- Smoothing
    end
	
    local windspeed = mathMax(vt, distance2D < vortexRMWSize and uz or 0) * distanceCutoff * vortexMaxWindspeed

	return GSVectorBasedAdjustedWindspeed(vecX, vecY, vecZ, movementVectorX, movementVectorY, movementVectorZ, mathMax(windspeed - (forwardsSpeedMPH * 2), 0), windspeed), vecX, vecY, vecZ
end

local spiralFactor = 0.6 * mathPi

local function GSComputeInflowJet(dx, dy, distance2D, vortexSize, vortexRMWSize, movementVectorX, movementVectorY, isAnticyclonic, enableInflowJet)
	if !enableInflowJet or distance2D <= vortexRMWSize or distance2D >= vortexSize then return 0 end

    local mx, my = movementVectorX, movementVectorY
    if mx == 0 and my == 0 then mx, my = 1, 0 end

    local progress = (distance2D - vortexRMWSize) / (vortexSize - vortexRMWSize)
    local delta = mathAbs((mathAtan2(dy, dx) - (mathAtan2(mx, -my) + (isAnticyclonic and progress * spiralFactor or mathPi - progress * spiralFactor)) + mathPi) % twoMathPi - mathPi)
    local t = 1 - (delta * distance2D / (vortexRMWSize * 5))

	if t <= 0 then return 0 end

	return t * (1 - progress)
end

local function GSComputeWindspeedAndVectors(propPosX, propPosY, propPosZ, tornadoPosBaseX, tornadoPosBaseY, tornadoPosModX, tornadoPosModY, dx, dy, distance2D, distanceZ, vortexSize, vortexRMWSize, vortexMaxWindspeed, movementVectorX, movementVectorY, movementVectorZ, forwardsSpeedMPH, isAnticyclonic, subvortexTable, vortexModelParameters, funnelWidthTable, funnelMaxHeight, enableInflowJet)
    local windspeed, vModelVecX, vModelVecY, vModelVecZ = GSMainVortexWindspeed(dx, dy, distance2D, distanceZ, vortexSize, vortexRMWSize, vortexMaxWindspeed, movementVectorX, movementVectorY, movementVectorZ, forwardsSpeedMPH, isAnticyclonic, vortexModelParameters, funnelWidthTable, funnelMaxHeight)
	local totalDirX, totalDirY, totalDirZ = vModelVecX * windspeed, vModelVecY * windspeed, vModelVecZ * windspeed
	local totalSubvDirX, totalSubvDirY, totalSubvDirZ = 0, 0, 0
	local subvWindspeed = 0
	local curveX, curveY = tornadoPosModX - tornadoPosBaseX, tornadoPosModY - tornadoPosBaseY

	for i = 1, #subvortexTable do
        local subv = subvortexTable[i]

		if !subv:IsValid() or !subv.Networked then continue end

		local subvPos, subvSize = subv.Position, subv.VortexSize
        local subvDistanceZ = mathMax(propPosZ - subvPos.z, 0)
        local sfmh = subv.FunnelMaxHeight
        local subvOffX, subvOffY = GSGetModifiedTornadoOffsetFromHeightAndNoise(subvDistanceZ, subv.VortexPositionNoiseFrequency, subv.VortexPositionNoiseAmplitude, subv.VortexPositionNoiseSpeed, isAnticyclonic, subv.VortexPositionNoiseSeed, subv.VortexPositionNoisePhase, subv.CurTime, subv.VortexPositionNoiseDetail, subv.VortexPositionNoisePeak, sfmh)
        local sdx, sdy = propPosX - (subvPos.x + curveX + subvOffX), propPosY - (subvPos.y + curveY + subvOffY)
        local subvDistance2D = mathSqrt(sdx * sdx + sdy * sdy)

		if subvDistance2D > subvSize then continue end

		local subvMovementVector = subv.MovementVector
        local subvortexWindspeedNew, subvVModelVecX, subvVModelVecY, subvVModelVecZ = GSMainVortexWindspeed(sdx, sdy, subvDistance2D, subvDistanceZ, subvSize, subv.VortexRMWSize, subv.VortexWindspeed, subvMovementVector.x, subvMovementVector.y, subvMovementVector.z, 0, isAnticyclonic, subv.VortexModelParameters, subv.FunnelWidthTable, sfmh)

		totalSubvDirX = totalSubvDirX + (subvVModelVecX * subvortexWindspeedNew)
		totalSubvDirY = totalSubvDirY + (subvVModelVecY * subvortexWindspeedNew)
		totalSubvDirZ = totalSubvDirZ + (subvVModelVecZ * subvortexWindspeedNew)
		subvWindspeed = mathMax(subvortexWindspeedNew, subvWindspeed)
	end

	totalDirX = totalDirX + totalSubvDirX
	totalDirY = totalDirY + totalSubvDirY
	totalDirZ = totalDirZ + totalSubvDirZ

    local combinedWS = windspeed

    if subvWindspeed > 0 then
        local totalSubvDirNormX, totalSubvDirNormY, totalSubvDirNormZ = GSNormalizeXYZ(totalSubvDirX, totalSubvDirY, totalSubvDirZ)
        combinedWS = GSVectorBasedAdjustedWindspeed(vModelVecX, vModelVecY, vModelVecZ, totalSubvDirNormX, totalSubvDirNormY, totalSubvDirNormZ, windspeed, mathMax(subvWindspeed, windspeed))
    end
    
    local inflowMul = GSComputeInflowJet(dx, dy, distance2D, vortexSize * 0.625, mathMax(vortexRMWSize * 2, 400), movementVectorX, movementVectorY, isAnticyclonic, enableInflowJet)

    combinedWS = mathMax(combinedWS, vortexMaxWindspeed * inflowMul * 0.7)
    
    local totalDirNormX, totalDirNormY, totalDirNormZ = GSNormalizeXYZ(totalDirX, totalDirY, totalDirZ)
    
    return combinedWS, totalDirNormX * combinedWS, totalDirNormY * combinedWS, totalDirNormZ * combinedWS
end

local function GSGetFlowWindspeedAndDirAndTemperature(propPosX, propPosY, originPosX, originPosY, dx, dy, distance2D, linear, width, length, depth, lookahead, directionX, directionY, flowDistCurrent, maxWindspeed, maxTemperature)

	if linear then
		local dirLen = mathMax(mathSqrt(directionX * directionX + directionY * directionY), tinyVal)
		local dirX, dirY = directionX / dirLen, directionY / dirLen
		local dX, dY = propPosX - (originPosX + dirX * flowDistCurrent), propPosY - (originPosY + dirY * flowDistCurrent)
		local halfW = width * 0.5
		local side = mathAbs((dX * dirY) - (dY * dirX))

		if side >= halfW then return 0, 0, 0, 0, 0 end

		local forward = (dX * dirX) + (dY * dirY)
		local la = mathMax(lookahead, 1)

		if forward > la or forward < -length then return 0, 0, 0, 0, 0 end

        local mult = ((1 - (side / halfW)) * (forward > 0 and (1 - forward / la) or 1) * (forward < 0 and (1 + forward / mathMax(length, 1)) or 1)) ^ 0.5
		local ws = maxWindspeed * mult

		return ws, dirX * ws, dirY * ws, 0, maxTemperature * mult
	end

	local dirLen = mathMax(distance2D, tinyVal)
	local dirX, dirY = dx / dirLen, dy / dirLen
	local mult

	if distance2D >= flowDistCurrent then
		if distance2D >= flowDistCurrent + lookahead then return 0, 0, 0, 0, 0 end
		mult = (1 - ((distance2D - flowDistCurrent) / mathMax(lookahead, 1))) ^ 0.5
	else
		if distance2D < flowDistCurrent - depth then return 0, 0, 0, 0, 0 end
		mult = (1 - ((flowDistCurrent - distance2D) / mathMax(depth, 1))) ^ 0.5
	end

	local ws = maxWindspeed * mult
	return ws, dirX * ws, dirY * ws, 0, maxTemperature * mult
end

function GSGetGlobalWindspeedAndVectors(propPos, entityList, inflowJetConvar, env, curTime, outVecG)
    if !env or !env.Networked then return 0, outVecG, 0, nil, 0, 0, 0 end

	local propPosX, propPosY, propPosZ = propPos.x, propPos.y, propPos.z
	local totalWS, totalFWDSpeed = 0, env.ForwardsSpeedMPH
	local totalTemperature = env.Temperature
	local windDir = env.WindDirection
    local stormMult, stormDirX, stormDirY, stormDirZ = GSNoise(propPosX, propPosY, windDir.x, windDir.y, windDir.z, 0, 3, 4000, 20000, 0, 45, 0.05, curTime)
	local stormWS = mathMin((stormMult * mathSqrt(stormMult)) * totalFWDSpeed, totalFWDSpeed)
	local totalStormWS = mathMax(env.Windspeed, stormWS)
	local totalDirX, totalDirY, totalDirZ = stormDirX * stormWS, stormDirY * stormWS, stormDirZ * stormWS
    local closest, closestDistanceSqr = env, mathHuge

    for i = 1, #entityList do
        local entity = entityList[i]

		if !entity:IsValid() or !entity.Networked then continue end

		local entityPos = entity.Position or entity:GetPos()
		local entityPosX, entityPosY, entityPosZ = entityPos.x, entityPos.y, entityPos.z

		if !entity.Flow then

            local distanceZ = mathMax(propPosZ - entityPosZ, 0)
			local anti = entity.Anticyclonic
			local vortexSize = entity.VortexSize
            local maxH = entity.FunnelMaxHeight
            local tornadoOffX, tornadoOffY = GSGetModifiedTornadoOffsetFromHeightAndNoise(distanceZ, entity.VortexPositionNoiseFrequency, entity.VortexPositionNoiseAmplitude, entity.VortexPositionNoiseSpeed, anti, entity.VortexPositionNoiseSeed, entity.VortexPositionNoisePhase, curTime, entity.VortexPositionNoiseDetail, entity.VortexPositionNoisePeak, maxH)
            local tPosX, tPosY = entityPosX + tornadoOffX, entityPosY + tornadoOffY
            local tdx, tdy = propPosX - tPosX, propPosY - tPosY
            local distance2DSqr = tdx * tdx + tdy * tdy

            if distance2DSqr <= closestDistanceSqr then 
                closest = entity 
                closestDistanceSqr = distance2DSqr
            end

            if distance2DSqr > vortexSize * vortexSize then continue end

			local distance2D = mathSqrt(distance2DSqr)
			local movementVector = entity.MovementVector
            local tornadoWS, tornadoDirX, tornadoDirY, tornadoDirZ = GSComputeWindspeedAndVectors(propPosX, propPosY, propPosZ, entityPosX, entityPosY, tPosX, tPosY, tdx, tdy, distance2D, distanceZ, vortexSize, entity.VortexRMWSize, entity.VortexWindspeed, movementVector.x, movementVector.y, movementVector.z, entity.ForwardsSpeedMPH, anti, entity.Subvortices, entity.VortexModelParameters, entity.FunnelWidthTable, maxH, entity.Tornado and inflowJetConvar)

			totalDirX = totalDirX + (tornadoDirX * 2)
			totalDirY = totalDirY + (tornadoDirY * 2)
			totalDirZ = totalDirZ + (tornadoDirZ * 2)
			totalWS = mathMax(totalWS, tornadoWS)

		else

            local dx, dy = propPosX - entityPosX, propPosY - entityPosY
            local distance2DBaseSqr = (dx * dx) + (dy * dy)
            local flowLinear = entity.FlowLinear
            local distance2DBase = !flowLinear and mathSqrt(distance2DBaseSqr) or nil
			local flowDir = entity.FlowLinearDirection
			local flowWS, flowDirX, flowDirY, flowDirZ, temperature = GSGetFlowWindspeedAndDirAndTemperature(propPosX, propPosY, entityPosX, entityPosY, dx, dy, distance2DBase, flowLinear, entity.FlowLinearWidth, entity.FlowLinearLength, entity.FlowRadialDepth, entity.FlowLookahead, flowDir.x, flowDir.y, entity.FlowDistRadCurrent, entity.FlowWindspeed, entity.FlowTemperatureCurrent)
            
            if distance2DBaseSqr <= closestDistanceSqr then 
                closest = entity 
                closestDistanceSqr = distance2DBaseSqr
            end

			totalWS = mathMax(totalWS, flowWS)
			totalTemperature = mathMax(temperature, totalTemperature)
			totalDirX = totalDirX + flowDirX
			totalDirY = totalDirY + flowDirY
			totalDirZ = totalDirZ + flowDirZ

		end
        
	end

    local gustMult, gustDirX, gustDirY, gustDirZ = GSNoise(propPosX, propPosY, totalDirX, totalDirY, totalDirZ, 0.5, 1.25, 250, 1000, 0, 90, 1, curTime)
	local gustMod = mathMin(gustMult, 1)
	local blendedWS = mathMax(totalStormWS, totalWS) * gustMod
    local dirMod = blendedWS * (1 - gustMod)

	totalDirX = totalDirX + (gustDirX * dirMod)
	totalDirY = totalDirY + (gustDirY * dirMod)
	totalDirZ = totalDirZ + (gustDirZ * dirMod)

    return blendedWS, GSNormalizeScaledToVector(totalDirX, totalDirY, totalDirZ, blendedWS, outVecG), totalTemperature, closest, totalWS * gustMod, totalStormWS * gustMod, totalFWDSpeed
end

local windOcclusionUpVec = Vector(0, 0, 1)
local windOcclusionTraceMask = MASK_SOLID + MASK_WATER
local windOcclusionDistanceCheck = 1000

function GSWindOcclusion(entity, propPos, windspeed, rawWindDirection)

    local windDirection = Vector(rawWindDirection.x, rawWindDirection.y, 0):GetNormalized()
    local rightVec = windDirection:Cross(windOcclusionUpVec):GetNormalized()
    local propPosMod = propPos - windDirection * 2 + windOcclusionUpVec
    local trace = {start = propPosMod, endpos = nil, mask = windOcclusionTraceMask, filter = entity}

    local dirs = {
        {-windDirection * windOcclusionDistanceCheck, 0},
        {rightVec * windOcclusionDistanceCheck, 0.35},
        {-rightVec * windOcclusionDistanceCheck, 0.35},
        {windOcclusionUpVec * windOcclusionDistanceCheck, 0.35}
    }

    local blocked, tunnel = 0, 0

    for i = 1, 4 do
        trace.endpos = propPosMod + dirs[i][1]

        local tr = utilTraceLine(trace)

        if !tr.Hit then continue end
        
        blocked, tunnel = blocked + 1, tunnel + dirs[i][2]
    end

    if blocked == 4 then return 0, 0 end

    local mult = ((4 - blocked) * 0.25) + tunnel

    return windspeed * mult, mult

end

local uwMult = 0.02670955587558985
local uwExp = 1.08

local function GSGetUnweldChanceCalc(ws) return mathFloor(1 + 1399 * mathExp(-((mathMax(ws - 65, 0) * uwMult) ^ uwExp)) + 0.5) end

local destructionSounds = {light = {path = "destruction/gs_destruction_light_", total = 6}, heavy = {path = "destruction/gs_destruction_heavy_", total = 11}}
local slp, shp, slt, sht = destructionSounds.light.path, destructionSounds.heavy.path, destructionSounds.light.total, destructionSounds.heavy.total

function GSRemoveConstraintsWindspeed(prop, propPos, phys, massFalloff, tornado, windspeed, isMotionEnabled, powerflashConvar)

    local wr = prop.GSWindResistance
    local rolled = mathRandom(mathMax(GSGetUnweldChanceCalc(windspeed) / massFalloff * 0.17, 1)) ~= 1

    if (!wr and rolled) or (wr and windspeed < wr) then return end

    phys:EnableMotion(true)

    GSHandlePowerflash(prop, windspeed, isMotionEnabled, true, powerflashConvar)

    if !constraintHasConstraints(prop) then return end

    local soundSelect = windspeed <= 140 and slp..tostring(mathRandom(slt))..".wav" or shp..tostring(mathRandom(sht))..".wav"
    local sRand = mathRandom(75, 125)

    constraintRemoveAll(prop)
    GSEmitSoundAtAllPlayers(propPos, 15000, 65, 5, sRand, soundSelect)

    if mathRandom(10) == 1 then tornado.IsDestroying = true end
    
end

function GSHandlePowerflash(prop, windspeed, isMotionEnabled, override, powerflashConvar)
    if !powerflashConvar or (!override and (isMotionEnabled or mathRandom(mathMax(175 - ((windspeed - 64) * 0.2), 1)) ~= 1)) then return end

    local model = stringLower(prop:GetModel() or "")

    if model:find("transformer", 1, true) or model:find("power", 1, true) or model:find("lamppost", 1, true) or model:find("utilitypole", 1, true) or model:find("pole_", 1, true) then
        GSStartParticleEffect(prop, "GStorms_Powerflash_Main_1", prop:LocalToWorld(prop:OBBMaxs()), nilVector)
        GSEmitSoundAtAllPlayers(prop:GetPos(), 15000, 100, 5, mathRandom(90, 110), "powerflash/powerflash_"..tostring(mathRandom(3))..".wav")
    end
end

local damagePlayersMinWind = 100
local dmg = DamageInfo()

function GSDamagePlayers(ply, tornado, windspeed, convar)

    if !convar or !ply:IsValid() or !tornado.Tornado or windspeed <= damagePlayersMinWind then return end
    if GSGetIsPlayerInVehicle(ply) then return end
    
    local wsMinWindSubtract = (windspeed - damagePlayersMinWind)

    dmg:SetDamage(wsMinWindSubtract * 0.006 * (tornado.IsDestroying and 2 or 1))
    dmg:SetDamageType(DMG_GENERIC)
    dmg:SetAttacker(tornado)
    dmg:SetInflictor(tornado)
    dmg:SetDamageForce(nilVector)
    ply:TakeDamageInfo(dmg)

    if mathRandom((45 / (wsMinWindSubtract * 0.1 + 1))) == 1 then ply:EmitSound("physics/concrete/concrete_impact_bullet"..mathRandom(4)..".wav", 60, mathRandom(95, 105)) end

end

function GSGranulateAndMudCoat(prop, tornado, windspeed, mudCoatCvar, granulationCvar)

    if mudCoatCvar and !constraintHasConstraints(prop) and windspeed > 140 and mathRandom(mathMax(150 - (windspeed - 140), 1)) == 1 then
        local colorRand = mathRandom(80, 170)
        prop:SetMaterial("other/mud/gstorms_mud")
        prop:SetColor(Color(colorRand, colorRand, colorRand, 255)) 
    end

    if !granulationCvar or windspeed < 201 then return end

    dmg:SetDamage(windspeed * 0.08)
    dmg:SetDamageType(DMG_GENERIC)
    dmg:SetAttacker(tornado)
    dmg:SetInflictor(tornado)
    dmg:SetDamageForce(nilVector)
    prop:TakeDamageInfo(dmg)

end

local function GSGetRawVortexShapeFromHeight(distanceZ, startHeight, maxHeight, funnelBaseWidth, funnelMidWidth, funnelMidHeight, funnelTopWidth, exponent)
	local span = mathMax(maxHeight - startHeight, 1)
	local normalizedHeight = mathClamp((distanceZ - startHeight) / span, 0, 1) ^ (exponent or 1)
	local midHeight = mathClamp(funnelMidHeight or 0.5, tinyVal, 1 - tinyVal)
	return normalizedHeight < midHeight and Lerp(normalizedHeight / midHeight, funnelBaseWidth, funnelMidWidth) or Lerp((normalizedHeight - midHeight) / (1 - midHeight), funnelMidWidth, funnelTopWidth)
end

function GSGetVortexShapeMod(distanceZ, maxHeight, funnelWidthTable)
	local rawMul = GSGetRawVortexShapeFromHeight(distanceZ, 0, maxHeight, funnelWidthTable.baseWidth, funnelWidthTable.midWidth, funnelWidthTable.midWidthHeight, funnelWidthTable.topWidth, funnelWidthTable.widthExponent)
	return 1 / mathMax(1, rawMul)
end

function GSVortexShapeFromHeightMultiplier(distanceZ, startHeight, maxHeight, funnelBaseWidth, funnelMidWidth, funnelMidHeight, funnelTopWidth, exponent, orbitRadSizeMult, isParticle)
	local rawMul = GSGetRawVortexShapeFromHeight(distanceZ, startHeight, maxHeight, funnelBaseWidth, funnelMidWidth, funnelMidHeight, funnelTopWidth, exponent)
	if !isParticle then return rawMul end
	local shapeCompression = 1 - orbitRadSizeMult * orbitRadSizeMult
	if shapeCompression <= tinyVal then return rawMul end
	return funnelBaseWidth + (rawMul - funnelBaseWidth) / shapeCompression
end

-- ############################################################## EARTHQUAKES ##############################################################

function GSGetGlobalMagnitude(propPos, earthquakeList, outVec)
	outVec:SetUnpacked(0, 0, 0)

	local propPosX, propPosY = propPos.x, propPos.y
	local maxMagnitude = 0
	local totalX, totalY = 0, 0

	for _, entity in ipairs(earthquakeList) do

		if !entity:IsValid() or !entity.Networked then continue end

		local magnitude = entity.CurrentMagnitude
		local radius = entity.CurrentRadius

		if magnitude <= 0 then continue end

		local entityPos = entity.Position
		local dx, dy = propPosX - entityPos.x, propPosY - entityPos.y
		local distSqr = (dx * dx) + (dy * dy)

		if distSqr >= radius * radius then continue end

		local dist = mathSqrt(distSqr)
		local falloff = 1 - (dist / radius)
		local effectiveMagnitude = magnitude * falloff

		if effectiveMagnitude <= 0 then continue end

		local dir = entity.ShakeDirection

		totalX = totalX + (dir.x * effectiveMagnitude)
		totalY = totalY + (dir.y * effectiveMagnitude)
		maxMagnitude = mathMax(maxMagnitude, effectiveMagnitude)

	end

	if maxMagnitude <= 0 then return 0, outVec end

	local len2 = (totalX * totalX) + (totalY * totalY)

	if len2 <= 0 then return maxMagnitude, outVec end

	local mult = maxMagnitude / mathSqrt(len2)

	outVec:SetUnpacked(totalX * mult, totalY * mult, 0)

	return maxMagnitude, outVec
end

function GSRemoveConstraintsEarthquake(prop, propPos, phys, mag, powerflashConvar)
    if mag <= 3 or math.random(Lerp(((mag - 3) * 0.1429) ^ 0.125, 5000, 1)) ~= 1 then return end

    phys:EnableMotion(true)

    GSHandlePowerflash(prop, 0, true, true, powerflashConvar)

    if !constraintHasConstraints(prop) then return end

    constraintRemoveAll(prop)

    local soundSelected = mag <= 5.5 and slp..tostring(mathRandom(slt))..".wav" or shp..tostring(mathRandom(sht))..".wav"

    GSEmitSoundAtAllPlayers(propPos, 15000, 65, 5, mathRandom(75, 125), soundSelected)
end

-- ############################################################## General & Getters ##############################################################

local speedVectorScale = 23.4666666667
local speedFromRadiusScale = 0.11
local outerSpinFalloff = 0.2

function GSGetSpeedVector(movementVector, movementSpeed, tickRate) return movementVector * (movementSpeed * speedVectorScale * tickRate) end
function GSGetSpeedFromRadius(vortexMaxWindspeed, radius, vortexRMWSize, updateInterval)
	local tangentialSpeed
	if radius <= vortexRMWSize then
		tangentialSpeed = vortexMaxWindspeed * (radius / vortexRMWSize)
	else
		tangentialSpeed = vortexMaxWindspeed * ((vortexRMWSize / radius)^outerSpinFalloff)
	end

	return tangentialSpeed / radius * speedFromRadiusScale * updateInterval
end

function GSReturnListOfGridPositions(resolution, position, size, heightOffset)

	local squareSize = size / resolution
	local halfGrid = size * 0.5

	local posX, posY, posZ = position.x, position.y, position.z
	local z = posZ + heightOffset

	local x = posX - halfGrid + 0.5 * squareSize
	local y0 = posY - halfGrid + 0.5 * squareSize

	local positions = {}
	local idx = 1

	for i = 1, resolution do
		local y = y0
		for j = 1, resolution do
			positions[idx] = Vector(x, y, z)
			idx = idx + 1
			y = y + squareSize
		end
		x = x + squareSize
	end

	return positions, squareSize

end

function GSGetUniformDistributionInCylinder(center, maxRadius, maxHeight, exclusionRadius, noZ)
    local a = exclusionRadius / maxRadius
    local t = mathRand(0, twoMathPi)
    local r = mathSqrt(mathRand(a*a, 1)) * maxRadius
    return Vector(center.x + r*mathCos(t), center.y + r*mathSin(t), noZ and 0 or center.z + mathRand(0, maxHeight))
end

local groundMatTypes = {[MAT_GRASS] = 3, [MAT_DIRT] = 3, [MAT_SAND] = 3, [MAT_WOOD] = 3, [MAT_CONCRETE] = 2, [MAT_METAL] = 2, [MAT_SLOSH] = 2}
local groundMatDown = Vector(0, 0, 1000)
local groundMatMask = MASK_SOLID_BRUSHONLY + MASK_WATER
local groundMatTrace = {start = nil, endpos = nil, mask = groundMatMask, output = {}}

function GSGetGroundMaterial(pos)
	groundMatTrace.start = pos
	groundMatTrace.endpos = pos - groundMatDown
	return groundMatTypes[utilTraceLine(groundMatTrace).MatType] or 3
end

local dragMult = 0.0001924933
local windspeedInfluence = 3.089263
local exponent = 0.7192985

function GSGetMassFalloff(mass, windspeed)
	local dragForce = dragMult * (windspeed ^ windspeedInfluence)
	return (dragForce / (dragForce + mass))^exponent
end

local waterUpVec = Vector(0, 0, 20)
local waterDownVec = Vector(0, 0, 1000)

function GSGetNormVecNoZ(magnitude) return Vector(mathRand(-1, 1), mathRand(-1, 1), 0):GetNormalized() * magnitude end
function GSGetOnWater(startPos) return utilTraceLine({start = startPos + waterUpVec, endpos = startPos - waterDownVec, mask = MASK_WATER}).Hit end

local groundPosStart = Vector(0, 0, 50000)
local groundPosEnd = Vector(0, 0, 20)

function GSGetGroundPosition(startPos)
    local traceUp = utilTraceLine({start = startPos, endpos = startPos + groundPosStart, mask = MASK_SOLID_BRUSHONLY})
    local traceDownFromSky = utilTraceLine({start = traceUp.HitPos - groundPosEnd, endpos = traceUp.HitPos - groundPosStart, mask = groundMatMask})
    return traceDownFromSky.Hit and traceDownFromSky.HitPos
end

function GSGetSoundTravelTime(soundPos, playerPos) return soundPos:Distance(playerPos) * 0.0001 end
function GSGetSoundLevelFromDistance(distance, maxDistance, exponent) return mathPow(mathClamp(1 - (distance / maxDistance), 0, 1), exponent) end

function GSGetWeightedTableReturn(tbl, minVal, maxVal, weight)
    local totalWeight, numTable = 0, #tbl

    for i = 1, numTable do totalWeight = totalWeight + tbl[i][weight] end

    local rand, cumulative = mathRandom() * totalWeight, 0

    for i = 1, numTable do
        local entry = tbl[i]
        cumulative = cumulative + entry[weight]
        if rand <= cumulative then return mathRandom(entry[minVal], entry[maxVal]) end
    end

    local fallback = tbl[1]
    return mathRandom(fallback[minVal], fallback[maxVal])
end

function GSGetIsVehicle(prop, propClass) return prop:IsVehicle() or propClass:StartWith("lvs_") end

function GSGetIsPlayerInVehicle(player) 
    local parent = player:IsValid() and player:GetParent()
    return parent:IsValid() and GSGetIsVehicle(parent, parent:GetClass()) or false
end

function GSGetKV(ent, t)
	if t.k1 then return (ent[t.k1][t.k2]) end
	local v = ent[t.key]
	return v
end

function GSSetKV(ent, t, value)
	if t.k1 then ent[t.k1][t.k2] = value return end
	ent[t.key] = value
end

-- ############################################################## MISCELLANEOUS / OTHER FUNCTIONS ##############################################################

function GSPrecacheParticleList(particleList) for _, v in ipairs(particleList) do PrecacheParticleSystem(v) end end

local cvReactiveSounds = GetConVar("gstorms_av_reactive_sounds")

function GSEmitSoundAtAllPlayers(soundPos, maxDistance, volume, volumeExponent, pitch, soundToPlay)
    for _, player in playerIterator() do

        if !player:IsValid() then continue end

        timerSimple(GSGetSoundTravelTime(soundPos, player:GetPos()), function()
            if !player:IsValid() then return end
        
            local vol, pit = volume, pitch
            if GSGetIsPlayerInVehicle(player) and cvReactiveSounds:GetBool() then
                vol = vol * 0.8
                pit = pit * 0.66
            end
        
            player:EmitSound(soundToPlay, vol, pit, GSGetSoundLevelFromDistance(player:GetPos():Distance(soundPos), maxDistance, volumeExponent))
        end)
    end
end

function GSIsPaused() return CLIENT and guiIsGameUIVisible() or false end

function GSTipToClient(ply, message)
    if SERVER then
        netStart("gs_send_tip")
        netWriteString(message)
        netSend(ply)
    elseif CLIENT then
		notificationAddLegacy(message, NOTIFY_HINT, 5)
		surfacePlaySound("ambient/water/drip2.wav")
    end
end

-- ############################################################## RADAR HANDLING ##############################################################

function GSLerpAndSmoothColor(windspeed, colorStops, noAlpha)
    local numColorStops = #colorStops
    local lower, upper = colorStops[1], colorStops[numColorStops]

    for i = 1, numColorStops do
        local stop = colorStops[i]
        if windspeed == stop.windspeed then return stop.color end
        if windspeed < stop.windspeed then
            upper = stop
            lower = colorStops[i - 1] or stop
            break
        end
    end

    local span = upper.windspeed - lower.windspeed
    local t = span == 0 and 0 or (windspeed - lower.windspeed) / span

    return Color(Lerp(t, lower.color.r, upper.color.r), Lerp(t, lower.color.g, upper.color.g), Lerp(t, lower.color.b, upper.color.b), noAlpha and 255 or mathMin(windspeed * 3.92, 255))
end

local GS_windspeedColors = {
    {windspeed = 0, color = Color(0, 0, 255)}, -- dark blue
    {windspeed = 65, color = Color(3, 252, 232)}, -- light blue
    {windspeed = 86, color = Color(50, 255, 50)}, -- green
    {windspeed = 111, color = Color(255, 255, 0)}, -- yellow
    {windspeed = 136, color = Color(255, 152, 0)}, -- orange
    {windspeed = 166, color = Color(255, 0, 0)}, -- red
    {windspeed = 201, color = Color(255, 0, 255)}, -- purple
    {windspeed = 320, color = Color(255, 255, 255)}, -- white
}

local GS_windspeedColorsVelocityTowards = {
    {windspeed = 0, color = Color(112, 128, 112)},
    {windspeed = 15, color = Color( 16, 96, 16)},
    {windspeed = 45, color = Color(0, 255, 0)},
    {windspeed = 70, color = Color(0, 255, 225)},
    {windspeed = 100, color = Color(0, 0, 160)},
    {windspeed = 140, color = Color(255, 0, 128)},
    {windspeed = 999, color = Color(128, 0, 208)},
}

local GS_windspeedColorsVelocityAway = {
    {windspeed = 0, color = Color(144, 128, 144)},
    {windspeed = 15, color = Color(112, 0, 0)},
    {windspeed = 45, color = Color(255, 0, 0)},
    {windspeed = 70, color = Color(255, 0, 144)},
    {windspeed = 100, color = Color(255, 96, 0)},
    {windspeed = 140, color = Color(255, 255, 0)},
    {windspeed = 999, color = Color(128, 0, 208)},
}

local GS_windspeedColorsGSCorrelationCoefficient = {
    {windspeed = 0, color = Color(150, 4, 57)},
    {windspeed = 30, color = Color(150, 4, 57)},
    {windspeed = 86, color = Color(249,196,1)},
    {windspeed = 140, color = Color(17, 12, 169)},
    {windspeed = 175, color = Color(143, 142, 153)},
    {windspeed = 190, color = Color(0, 0, 0)},
}

local GS_valueColorsReflectivity = { -- "windspeed" here is really reflectivity value, using cause too lazy to change
    {windspeed = 0, color = Color(0, 0, 0)},
    {windspeed = 20, color = Color(0, 0, 0)},
    {windspeed = 25, color = Color(16, 16, 64)},
    {windspeed = 30, color = Color(0, 128, 255)},
    {windspeed = 35, color = Color(0, 192, 0)},
    {windspeed = 45, color = Color(255, 255, 0)},
    {windspeed = 55, color = Color(255, 165, 0)},
    {windspeed = 65, color = Color(255, 0, 0)},
    {windspeed = 75, color = Color(255, 0, 255)},
    {windspeed = 85, color = Color(170, 0, 255)},
    {windspeed = 95, color = Color(255, 255, 255)},
    {windspeed = 100, color = Color(255, 255, 255)},
}

local function GSHandleRelVel(relVel, noAlpha, windspeed)
    local wsTable = relVel >= 0 and GS_windspeedColorsVelocityTowards or GS_windspeedColorsVelocityAway
    local numWSTable = #wsTable
    local absVel = mathAbs(relVel * windspeed)
    return absVel >= wsTable[numWSTable].windspeed and wsTable[numWSTable].color or GSLerpAndSmoothColor(absVel, wsTable, noAlpha)
end

function GSReturnColorForWindspeed(windspeed, convar, radarPosition, currentGridPosition, noAlpha, velDir)
    if !convar or !radarPosition then return windspeed >= GS_windspeedColors[#GS_windspeedColors].windspeed and GS_windspeedColors[#GS_windspeedColors].color or GSLerpAndSmoothColor(windspeed, GS_windspeedColors, noAlpha) end
    return GSHandleRelVel(velDir:GetNormalized():Dot((radarPosition - currentGridPosition):GetNormalized()), noAlpha, windspeed)
end

function GSReturnColorForGSCorrelationCoefficient(windspeed, stormShapeData, isDestroying)
    local windspeedModified = mathMax(stormShapeData, windspeed * (mathRandom(75, 125) / 100) * (isDestroying and 1.5 or 1))
    return windspeedModified >= GS_windspeedColorsGSCorrelationCoefficient[#GS_windspeedColorsGSCorrelationCoefficient].windspeed and GS_windspeedColorsGSCorrelationCoefficient[#GS_windspeedColorsGSCorrelationCoefficient].color or GSLerpAndSmoothColor(windspeedModified, GS_windspeedColorsGSCorrelationCoefficient, true)
end

function GSReturnValueColorsReflectivity() return GS_valueColorsReflectivity end

function GSReturnColorForReflectivity(windspeed)
    return windspeed >= GS_valueColorsReflectivity[#GS_valueColorsReflectivity].windspeed and GS_valueColorsReflectivity[#GS_valueColorsReflectivity].color or GSLerpAndSmoothColor(windspeed, GS_valueColorsReflectivity, true)
end

function GSGetStormReflectivityValueFromPoint(position, isRadar, entityList)

    local maxStormShape, maxDebrisBShape = 0, 0
    local minHeight, entityParent = nil, nil
    local threshold = GS_valueColorsReflectivity[2].windspeed

    if #entityList == 0 then return maxStormShape, minHeight, entityParent end

    for _, entity in ipairs(entityList) do

        if !entity:IsValid() or !entity.Networked or entity.DustDevil or entity.Flow then continue end

        local stormShape, debrisBShape = 0, 0
        local hurricane = entity.Hurricane
        local derecho = entity.Derecho
        local rainFreeBaseMult = (entity.StormRFB and !isRadar and !derecho and !hurricane) and mathClamp((entity.Position:Distance2D(position) - entity.MesocycloneSize * 0.75) / (entity.MesocycloneSize * 0.25), 0, 1) or 1
        local funnelMaxHeight = entity.FunnelMaxHeight

        local pm = entity.StormPrecipitationMultiplier
        local stormSize = entity.MesocycloneSize * 30

        local supercellParameters = entity.SupercellParameters
        local debrisBMax = 70 * pm * supercellParameters.debrisMax
        local hookMax = 60 * pm * supercellParameters.hookMax
        local parentMax = 75 * pm
        local debrisBRad = stormSize * 0.08 * supercellParameters.debrisBSize
        local hookLen = stormSize * 0.32 * supercellParameters.hookLenSize
        local hookWid = stormSize * 0.03 * supercellParameters.hookWidSize
        local hookAng = 180 * supercellParameters.hookAngSize

        if hurricane then
            stormShape = GSReturnReflectivityHurricane(position, entity.Position, entity.VortexSize, entity.VortexRMWSize, entity.MovementVector, entity.Anticyclonic, parentMax, entity.CurTime)
        elseif derecho then
            stormShape = GSReturnReflectivityDerecho(position, entity.Position, stormSize, parentMax, entity.MovementVector, entity.CurTime)
        else
            stormShape, debrisBShape = GSReturnReflectivitySupercell(entity, debrisBMax, hookMax, parentMax, position, entity.Position, debrisBRad, hookLen, hookWid, 25, hookAng, stormSize, entity.VortexRMWSize, -entity.MovementVector, entity.Anticyclonic)
            maxDebrisBShape = mathMax(maxDebrisBShape, debrisBShape * rainFreeBaseMult)
        end

        maxStormShape = mathMax(maxStormShape, stormShape * rainFreeBaseMult)

        if !minHeight or funnelMaxHeight < minHeight then
            minHeight = funnelMaxHeight
            entityParent = entity
        end

    end

    return mathMax(isRadar and maxStormShape or (maxStormShape - threshold), isRadar and (entityParent.IsDestroying and maxDebrisBShape * 1.25 or maxDebrisBShape) or 0, 0), minHeight, entityParent

end

-- ############################################################## HYBRID SPLIT HANDLING ##############################################################

if SERVER then
    
    function GSStartParticleEffect(ent, particleName, position, offset, useParticleEffectFunc)

        if !ent:IsValid() then return end

        PrecacheParticleSystem(particleName)

        if !useParticleEffectFunc then ParticleEffectAttach(particleName, PATTACH_ABSORIGIN_FOLLOW, ent, 0) return end

        netStart("gs_start_particle_effect")
        netWriteEntity(ent)
        netWriteString(particleName)
        netWriteVector(position + offset)
        netWriteBool(useParticleEffectFunc)
        netBroadcast()
    
    end
end