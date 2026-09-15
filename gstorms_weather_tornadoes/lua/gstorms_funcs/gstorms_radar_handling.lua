-- RADAR & REFLECTIVITY VALUE HANDLING

-- locals / globals

local tiny = 1e-6
local calibratedValues = {angle = 300, startAngle = -0.5, tipPosRight = 0.2, tipPosBack = 0.3}
local radarZeroColor = Color(0, 0, 0)

local mathMax = math.max
local mathClamp = math.Clamp
local mathAtan2 = math.atan2
local mathCos = math.cos
local mathSin = math.sin
local mathRad = math.rad
local mathSqrt = math.sqrt
local mathRand = math.Rand
local mathAbs = math.abs

local function GSNormalize2DXY(x, y)
	local len2 = (x * x) + (y * y)

	if len2 < tiny then return 1, 0 end

	local invLen = 1 / mathSqrt(len2)

	return x * invLen, y * invLen
end

-- HURRICANES

function GSReturnReflectivityHurricane(positionInput, entityPos, vortexSize, vortexRMWSize, movementVector, anticyclonic, precipitationMax, curTime)

    local r = positionInput:Distance2D(entityPos)
    if r >= vortexSize then return 0, 0 end

    local delta = mathMax(vortexSize - vortexRMWSize, 1)
    local inner = mathClamp(r / (vortexRMWSize * 0.5), 0, 1)
    local outer = 1 - mathClamp((r - vortexRMWSize) / delta, 0, 1)
    local shapeMul = inner * outer
    local precipitationMultiplier = shapeMul ^ 0.15

    local minMulShapeMult = mathClamp((r - vortexRMWSize * 0.5) / mathMax(vortexRMWSize * 0.5, 1), 0, 1) ^ 0.5
    local minMul = Lerp((minMulShapeMult * outer) ^ 1.5, -1.0, 0.5)
    local maxSizeLerp = Lerp(shapeMul, 50000, 10000)
    
    local hurricaneShapeNoiseMultiplier = mathClamp(GSRotationalNoise(
        positionInput.x,                         -- posX
        positionInput.y,                         -- posY
        entityPos.x,                             -- centerPosX
        entityPos.y,                             -- centerPosY
        vortexRMWSize,                           -- vortexRMWSize
        vortexSize,                              -- vortexSize
        0.1,                                     -- spinSpeed
        1000,                                    -- minSize
        maxSizeLerp,                             -- maxSize
        1.5,                                     -- sizeExponent
        minMul,                                  -- minMul
        1.5,                                     -- maxMul
        0.1,                                     -- frequency
        0.5,                                     -- swirlStrength
        0.1125,                                  -- Inwards Strength
        0.975,                                   -- outerStretchScale
        curTime,                                 -- curTime
        anticyclonic
    ), 0, 1) ^ 1.25

    return precipitationMax * precipitationMultiplier * hurricaneShapeNoiseMultiplier

end

-- SUPERCELLS

local function GSResolveStartAndTipXY(mvX, mvY, debrisCenterX, debrisCenterY, hookLength, hookAngleRad, aDirection)
    mvX, mvY = GSNormalize2DXY(mvX, mvY)

    local tipAng = (mathAtan2(mvX, -mvY) + calibratedValues.startAngle) + (aDirection * mathRad(calibratedValues.angle))

    return tipAng - aDirection * hookAngleRad, debrisCenterX + mathCos(tipAng) * hookLength, debrisCenterY + mathSin(tipAng) * hookLength, mvX, mvY, -mvY, mvX
end

local frac = 1 / 3

local function GSComputeSupercellHookEchoXY(maxValueReturnHookEcho, positionInputX, positionInputY, debrisCenterX, debrisCenterY, hookLength, hookWidth, hookWidthEndMult, hookAngleRad, startAngle, aDirection)
	local low, high = 0.0, 1.0

	local widthBase = hookWidth * 0.25
	local widthDelta = hookWidth * hookWidthEndMult - widthBase

	for _ = 1, 8 do
		local span = high - low
		local t1 = low + span * frac
		local t2 = high - span * frac

		local angle1 = startAngle + aDirection * (t1 * hookAngleRad)
		local r1 = t1 * hookLength
		local dx1, dy1 = positionInputX - (debrisCenterX + mathCos(angle1) * r1), positionInputY - (debrisCenterY + mathSin(angle1) * r1)
		local hw1 = mathMax((widthBase + widthDelta * t1) * 0.5, tiny)

		local angle2 = startAngle + aDirection * (t2 * hookAngleRad)
		local r2 = t2 * hookLength
		local dx2, dy2 = positionInputX - (debrisCenterX + mathCos(angle2) * r2), positionInputY - (debrisCenterY + mathSin(angle2) * r2)
		local hw2 = mathMax((widthBase + widthDelta * t2) * 0.5, tiny)

		if (dx1 * dx1 + dy1 * dy1) / (hw1 * hw1) > (dx2 * dx2 + dy2 * dy2) / (hw2 * hw2) then low = t1 else high = t2 end
	end

	local tBest = (low + high) * 0.5
	local angle = startAngle + aDirection * (tBest * hookAngleRad)
	local r = tBest * hookLength
	local dx, dy = positionInputX - (debrisCenterX + mathCos(angle) * r), positionInputY - (debrisCenterY + mathSin(angle) * r)
	local distLine = mathSqrt(dx * dx + dy * dy)
	local lateral = mathClamp(1 - (distLine / mathMax((widthBase + widthDelta * tBest) * 0.5, tiny)), 0, 1)

    lateral = lateral * lateral * (3 - 2 * lateral)

    return lateral * maxValueReturnHookEcho
end

local function GSComputeSupercellDebrisBall(maxValueReturnDebrisBall, positionInput, debrisBall_and_centerPos, debrisBallRadius, vortexRMWSize, hookVal)
    local dx, dy = positionInput.x - debrisBall_and_centerPos.x, positionInput.y - debrisBall_and_centerPos.y
    local dist = mathSqrt(dx * dx + dy * dy)

    if dist > debrisBallRadius then return 0, hookVal end

    local rmwMult = dist < vortexRMWSize and dist / vortexRMWSize or 1

    return Lerp(dist / debrisBallRadius, maxValueReturnDebrisBall, 0) * rmwMult, hookVal * rmwMult
end

local function GSComputeSupercellShapeXY(ent, maxValueReturnParentStorm, positionInputX, positionInputY, stormSize, tipPosX, tipPosY, mvX, mvY, rightX, rightY)
    if !ent:IsValid() then return 0 end

	local tipRightOffset = stormSize * calibratedValues.tipPosRight
	local tipBackOffset = stormSize * calibratedValues.tipPosBack
    local relX, relY = positionInputX - (tipPosX + rightX * tipRightOffset - mvX * tipBackOffset), positionInputY - (tipPosY + rightY * tipRightOffset - mvY * tipBackOffset)
    local x = (relX * mvX) + (relY * mvY)
    local frontReach = stormSize * 1.2

    if x < 0 or x > frontReach then return 0 end

    local u = x / frontReach
    local atanAngle = mathAtan2((relX * rightX) + (relY * rightY), x)
	local psNoiseSeed = ent.psNoiseSeed

    if !psNoiseSeed then
		psNoiseSeed = mathRand(0, 1) * 10000
		ent.psNoiseSeed = psNoiseSeed
	end

    local t = CurTime() * 0.025 + psNoiseSeed
    local noisyR = Lerp(u, stormSize * 0.6, stormSize * 1.3) * (1 + mathSin(atanAngle * 3 + t) * 0.075 + mathCos(atanAngle * 5 - t * 0.7) * 0.05)
    local innerR = noisyR * Lerp(u, 0.4, 0.1)
    local tt = mathClamp((mathSqrt(relX * relX + relY * relY) - innerR) / (noisyR - innerR), 0, 1)
    tt = tt * tt * (3 - 2 * tt)

    local fadeMargin = 0.2

    return mathClamp((1 - tt) * mathClamp((1 - u) / fadeMargin, 0, 1) * mathClamp(u / fadeMargin, 0, 1) * maxValueReturnParentStorm, 0, maxValueReturnParentStorm)
end

function GSReturnReflectivitySupercell(ent, maxValueReturnDebrisBall, maxValueReturnHookEcho, maxValueReturnParentStorm, positionInput, debrisBall_and_centerPos, debrisBallRadius, hookLength, hookWidth, hookWidthEndMult, hookAngleDegrees, stormSize, vortexRMWSize, movementVector, anticyclonic)
    local mvX, mvY = movementVector.x, movementVector.y

    if anticyclonic then mvX, mvY = -mvX, -mvY end

	local posX, posY = positionInput.x, positionInput.y
	local debrisX, debrisY = debrisBall_and_centerPos.x, debrisBall_and_centerPos.y
	local curTime = CurTime()
    local debrisBallNoise = GSRotationalNoise(
        posX,
        posY,
        debrisX,
        debrisY,
        vortexRMWSize,
        debrisBallRadius,
        0.75,
        750,
        6000,
        1.5,
        0.25,
        2,
        0.1,
        0.3,
        0.0675,
        0.9,
        curTime,
        anticyclonic
    )

    local debrisBallRotationalNoise = mathClamp(debrisBallNoise, 0, 1) ^ 1.25
	local aDirection = -1
	local hookAngleRad = mathRad(hookAngleDegrees)
    local startAngle, tipPosX, tipPosY, basisMvX, basisMvY, rightX, rightY = GSResolveStartAndTipXY(mvX, mvY, debrisX, debrisY, hookLength, hookAngleRad, aDirection)
    local hookVal = GSComputeSupercellHookEchoXY(maxValueReturnHookEcho, posX, posY, debrisX, debrisY, hookLength, hookWidth, hookWidthEndMult, hookAngleRad, startAngle, aDirection)
    local parentVal = GSComputeSupercellShapeXY(ent, maxValueReturnParentStorm, posX, posY, stormSize, tipPosX, tipPosY, basisMvX, basisMvY, rightX, rightY)
    
    local debrisVal, hookMod = GSComputeSupercellDebrisBall(maxValueReturnDebrisBall, positionInput, debrisBall_and_centerPos, debrisBallRadius, vortexRMWSize, hookVal)
    debrisVal = debrisVal * debrisBallRotationalNoise

    return mathMax(parentVal, debrisVal * 0.75, hookMod, 0), debrisVal
end

-- DERECHO

function GSReturnReflectivityDerecho(positionInput, entityPos, stormSize, precipitationMultiplier, movementVector, curTime)
    if precipitationMultiplier <= 0 or stormSize <= 0 then return 0 end

    local movementVecX, movementVecY = movementVector.x, movementVector.y
    local forwardX, forwardY = GSNormalize2DXY(movementVecX, movementVecY)
    local relX, relY = positionInput.x - entityPos.x, positionInput.y - entityPos.y
    local frontDist = (relX * forwardX) + (relY * forwardY)

    local maxBehind = stormSize * 2
    local maxCross  = stormSize * 1.5
	local absCrossDist = mathAbs((relY * forwardX) - (relX * forwardY))

    if frontDist > stormSize * 0.25 or frontDist < -maxBehind or absCrossDist > maxCross then return 0 end

    local leadNorm = mathClamp(1 - mathAbs(frontDist) / (stormSize * 0.4), 0, 1) ^ 2
    local stratNorm = 0

    if frontDist <= 0 then stratNorm = mathClamp(1 + frontDist / maxBehind, 0, 1) ^ 1.3 end

    local crossNorm = mathClamp(1 - absCrossDist / maxCross, 0, 1) ^ 0.9

    return mathClamp(((leadNorm + stratNorm * (1 - leadNorm) * 0.6) * crossNorm) * (0.7 + GSNoise(relX, relY, movementVecX, movementVecY, movementVector.z, 0, 1, 8000, 25000, 0, 90, 0.01, curTime) * 0.6), 0, 1) * precipitationMultiplier
end

-- RADAR

local out = Vector(0, 0, 0)

local function GSRunRadar(ply, radar)

    if !CLIENT or !ply:IsValid() then return end

    local range = radar.Range
    local radarPos = radar:GetPos()
    local grid = GSReturnListOfGridPositions(radar.Resolution, radarPos, range, 0)
    local N = #grid
    local reflData, velData, ccData, sRVData = {}, {}, {}, {}
    local reflThresh = GSReturnValueColorsReflectivity()[2].windspeed
    local entityList = gs_weatherEntityList.client
    local maxSampleHeight = radar.MaxDistanceSampleHeight
    local invRange = 1 / range
    local inflowJetConvar = GetConVar("gstorms_tornado_inflow_jet"):GetBool()
    local envEnt = gs_env.client
    local curTime = CurTime()

    if !envEnt then return end

    for i = 1, N do

        local gridPos = grid[i]
        local stormShape = GSGetStormReflectivityValueFromPoint(gridPos, true, entityList) * mathRand(0.85, 1)

        gridPos.z = gridPos.z + (maxSampleHeight * mathClamp(radarPos:Distance2D(gridPos) * invRange, 0, 1))

        local refEntry = { position = gridPos, color = radarZeroColor, stormShape = stormShape }
        local velEntry = { position = gridPos, color = radarZeroColor, windspeed = 0 }
        local sRVEntry = { position = gridPos, color = radarZeroColor, windspeed = 0 }
        local ccEntry  = { position = gridPos, color = radarZeroColor, stormShape = 0 }

        if stormShape ^ 1.1 >= reflThresh then

            local ws, windDir, _, closestEntity, tornadoWS, stormWS, totalFWDSpeed = GSGetGlobalWindspeedAndVectors(gridPos, entityList, inflowJetConvar, envEnt, curTime, out)
            local wsSRV = mathMax(tornadoWS, stormWS - (totalFWDSpeed * 0.75), 1)
        
            refEntry.color = GSReturnColorForReflectivity(stormShape)
            velEntry.windspeed, velEntry.color = ws, GSReturnColorForWindspeed(ws, true, radarPos, gridPos, true, windDir)
            sRVEntry.windspeed, sRVEntry.color = wsSRV, GSReturnColorForWindspeed(wsSRV, true, radarPos, gridPos, true, windDir)
            ccEntry.stormShape, ccEntry.color = stormShape, GSReturnColorForGSCorrelationCoefficient(ws, stormShape, closestEntity.IsDestroying)
        
        end

        reflData[i] = refEntry
        velData[i] = velEntry
        sRVData[i] = sRVEntry
        ccData[i] = ccEntry

    end

    radar.GSReflectivityDataBuffer = reflData
    radar.GSVelocityDataBuffer = velData
    radar.GSStormRelativeVelocityDataBuffer = sRVData
    radar.GSCorrelationCoefficientDataBuffer = ccData

end

function GSRadarUpdateClient(ply, radar) if ply:IsValid() and radar:IsValid() then GSRunRadar(ply, radar) end end