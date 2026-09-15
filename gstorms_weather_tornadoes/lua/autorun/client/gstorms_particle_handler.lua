-- lua/autorun/client/gstorms_particle_handler.lua

if SERVER then return end

include("autorun/gstorms_api.lua")
include("autorun/gstorms_groundposition.lua")
include("gstorms_funcs/gstorms_shared.lua")

local mathMin, mathMax, mathClamp = math.min, math.max, math.Clamp
local mathRandom, mathRand, mathFloor = math.random, math.Rand, math.floor
local mathAtan2, mathCos, mathSin, mathSqrt, mathRad, mathTan = math.atan2, math.cos, math.sin, math.sqrt, math.rad, math.tan
local mathApproach = math.Approach
local tableSort = table.sort
local setMaterial = render.SetMaterial
local DrawQuadEasy = render.DrawQuadEasy
local hookAdd = hook.Add
local utilGetSunInfo = util.GetSunInfo
local utilTraceLine = util.TraceLine
local Vector, Color, Lerp = Vector, Color, Lerp
local CurTime, EyePos, EyeAngles = CurTime, EyePos, EyeAngles
local GetConVar = GetConVar
local IsValid = IsValid
local ScrW = ScrW
local ScrH = ScrH

local GSGetActivePackName = GSGetActivePackName
local GSGetPackProfile = GSGetPackProfile
local GSGetEntProfile = GSGetEntProfile
local GSGetUniformDistributionInCylinder = GSGetUniformDistributionInCylinder
local GSGetStormReflectivityValueFromPoint = GSGetStormReflectivityValueFromPoint
local GSGetIsVehicle = GSGetIsVehicle
local GSGetGroundMaterial = GSGetGroundMaterial
local GSReturnPositionNoiseMaxOffset = GSReturnPositionNoiseMaxOffset
local GSVortexShapeFromHeightMultiplier = GSVortexShapeFromHeightMultiplier
local GSMainVortexWindspeed = GSMainVortexWindspeed
local GSGetGlobalWindspeedAndVectors = GSGetGlobalWindspeedAndVectors
local GSIsPaused = GSIsPaused
local GSGetLightEnvironment = GSGetLightEnvironment
local GSGetSpeedFromRadius = GSGetSpeedFromRadius
local GSGetModifiedTornadoPosFromHeightAndNoise = GSGetModifiedTornadoPosFromHeightAndNoise
local GSGetModifiedTornadoOffsetFromHeightAndNoise = GSGetModifiedTornadoOffsetFromHeightAndNoise

local gsParticleAmountMult = 1
local nextThink = engine.TickInterval() * 2
local nextRun, precipNextRun = 0, 0

local twoPi, invTwoPi = math.pi * 2, 1 / (math.pi * 2)
local gsMPHToHUPerSec = 17.6

local deathFadeInv = 1 / 4

local angleAlphaTransparency = 0.75
local angleAlphaBackMult = 1 - angleAlphaTransparency
local angleAlphaHalfRange = (1 - angleAlphaBackMult) * 0.5
local angleAlphaBase = angleAlphaBackMult + angleAlphaHalfRange

local gsRopeLerp = 900
local gsFlatOffset = 100
local gsRopeLerpInv = 1 / gsRopeLerp

local tinyVal = 1e-9

local gsViewPos
local gsViewPosX, gsViewPosY, gsViewPosZ = 0, 0, 0
local gsViewForwardX, gsViewForwardY, gsViewForwardZ = 0, 0, 1
local gsViewRightX, gsViewRightY, gsViewRightZ = 1, 0, 0
local gsViewUpX, gsViewUpY, gsViewUpZ = 0, 0, 1
local gsFrustumTanX, gsFrustumTanY = 1, 1

-- POOLS & EMITTERS
local free, freeCount = {}, 0
local activeEmitters, activeEmitterCount = {}, 0

-- DRAW STATE
local drawA, drawB = {}, {}
local drawCountA, drawCountB = 0, 0
local precipDrawA, precipDrawB = {}, {}
local precipDrawCountA, precipDrawCountB = 0, 0
local finalDrawA, finalDrawB = {}, {}
local finalDrawCountA = 0
local finalDrawUsedA, finalDrawUsedB = 0, 0
local maxDist, fadeBand = 31000, 16000
local maxDistSqr = maxDist * maxDist
local fadeStart = maxDist - fadeBand
local fadeStartSqr = fadeStart * fadeStart
local fadeInv = 1 / (maxDistSqr - fadeStartSqr)
local drawUsedA, drawUsedB = 0, 0
local precipDrawUsedA, precipDrawUsedB = 0, 0

-- LIGHTING / SUN
local sunAng, sunRate, nextSun = 0, 1, 0

-- CLOUDS
local cloudGroups, cloudCount = {}, 0
local cloudParticles = {n = 0}
local cloudLast, cloudDt, cloudPack = 0, 0, ""

-- TRACE CACHES
local rainTraceStart = Vector(0, 0, 0)
local rainTraceEnd = Vector(0, 0, 0)
local rainTrace = {start = rainTraceStart, endpos = rainTraceEnd, mask = MASK_SOLID + MASK_WATER}

local flowTraceStart = Vector(0, 0, 0)
local flowTraceEnd = Vector(0, 0, 0)
local flowTraceData = {start = flowTraceStart, endpos = flowTraceEnd, mask = MASK_SOLID_BRUSHONLY + MASK_WATER}

-- CONDENSATION / ORBIT CONSTANTS
local frac1, frac2 = 1 / 3, 2 / 3
local invPhi = 0.6180339887498949
local goldenAng = 2.3999632297286533
local gsCondArtifactElimination = 0.3
local gsCenteredEffectiveRadiusMult = 0.5
local hurricaneScale = 40000 * 40000

-- SPAWNER WORK VECTOR ALLOCATIONS
local debrisGroundSample = Vector(0, 0, 0)
local outVec = Vector(0, 0, 0)

local function PGet()
	if freeCount > 0 then
		local particle = free[freeCount]
		free[freeCount] = nil
		freeCount = freeCount - 1
		return particle
	end

	return {pos = Vector(0, 0, 0), vel = Vector(0, 0, 0)}
end

local function PRecycle(particle)
	particle.prof, particle.ref, particle.col, particle.lastDrawSize, particle.lastDrawAng, particle.lastDrawAlpha, particle.lastDrawCamAng, particle.lastDrawFlatLightingT = nil, nil, nil, nil, nil, nil, nil, nil
	freeCount = freeCount + 1
	free[freeCount] = particle
end

local function BucketPush(bucket, particle)
	local count = bucket.n + 1
	bucket.n = count
	bucket[count] = particle
end

local function BucketKill(bucket, i)
	local count = bucket.n

	PRecycle(bucket[i])

	bucket[i] = bucket[count]
	bucket[count] = nil
	bucket.n = count - 1
end

local function ClearBucket(bucket)
	for i = bucket.n, 1, -1 do
		PRecycle(bucket[i])
		bucket[i] = nil
	end

	bucket.n = 0
end

-- EMITTERS

local function EnsureEmitter(ent)
	local emit = ent.GSParticleEmit

	if !emit then
		emit = {reflect = {n = 0}, precip = {n = 0}, orbit = {n = 0}, subv = {n = 0}, physics = {n = 0}, flow = {n = 0}}
		ent.GSParticleEmit = emit
	end

	emit.owner = ent

	if !ent.GSParticleEmitRegistered then
		ent.GSParticleEmitRegistered = true
		activeEmitterCount = activeEmitterCount + 1
		activeEmitters[activeEmitterCount] = emit
	end

	return emit
end

local function ClearEmitter(ent, eReflect, ePrecip, eOrbit, eSubv, ePhysics, eFlow)
	ClearBucket(eReflect)
	ClearBucket(ePrecip)
	ClearBucket(eOrbit)
	ClearBucket(eSubv)
	ClearBucket(ePhysics)
	ClearBucket(eFlow)

	ent.GSParticleDt = nil
	ent.GSParticleCamAng = nil
	ent.GSParticleLastThink = nil
	ent.GSPrecipLastThink = nil
end

local function EmitterEmpty(nReflect, nPrecip, nOrbit, nSubv, nPhysics, nFlow) return nReflect == 0 and nPrecip == 0 and nOrbit == 0 and nSubv == 0 and nPhysics == 0 and nFlow == 0 end

local function RemoveActiveEmitter(i)
	local emit = activeEmitters[i]
	local ent = emit and emit.owner

	if IsValid(ent) then ent.GSParticleEmitRegistered = nil end

	activeEmitters[i] = activeEmitters[activeEmitterCount]
	activeEmitters[activeEmitterCount] = nil
	activeEmitterCount = activeEmitterCount - 1
end

-- DRAW LIST

local function TrimDrawTail(drawList, liveCount, usedCount)
	for i = liveCount + 1, usedCount do drawList[i] = nil end
	return liveCount
end

local function GetDrawEntry(drawList, i)
	local entry = drawList[i]
	if entry then return entry end

	entry = {c = Color(255, 255, 255, 255)}
	drawList[i] = entry

	return entry
end

local function MergeSortedDrawLists()
	local i, j, k = 1, 1, 0
	local countA, countB = drawCountA, precipDrawCountA
	local out = finalDrawB

	while i <= countA and j <= countB do
		k = k + 1

		if drawA[i].distSqr >= precipDrawA[j].distSqr then
			out[k] = drawA[i]
			i = i + 1
		else
			out[k] = precipDrawA[j]
			j = j + 1
		end
	end

	for n = i, countA do
		k = k + 1
		out[k] = drawA[n]
	end

	for n = j, countB do
		k = k + 1
		out[k] = precipDrawA[n]
	end

	if k < finalDrawUsedB then
		for n = k + 1, finalDrawUsedB do
			out[n] = nil
		end
	end

	finalDrawUsedB = k
	finalDrawA, finalDrawB = finalDrawB, finalDrawA
	finalDrawCountA = k
	finalDrawUsedA, finalDrawUsedB = finalDrawUsedB, finalDrawUsedA
end

local function UpdateSun(curTime)
	if curTime < nextSun then return end
	nextSun = curTime + sunRate

	local info = utilGetSunInfo()
	local dir = info and info.direction

	if !dir then return end

	sunAng = mathAtan2(dir.y, dir.x)
end

local function GSGetAngleAlpha(ang, camAng) return angleAlphaBase + angleAlphaHalfRange * mathCos(ang - camAng) end
local function GSGetRopeFlatLightingBlend(r, size) return 1 - mathClamp((r + size - gsFlatOffset) * gsRopeLerpInv, 0, 1) end

local function SphereVisible(posX, posY, posZ, radius)
	local dx, dy, dz = posX - gsViewPosX, posY - gsViewPosY, posZ - gsViewPosZ
	local forwardDot = dx * gsViewForwardX + dy * gsViewForwardY + dz * gsViewForwardZ

	if forwardDot <= -radius then return false end

	if (dx * dx + dy * dy + dz * dz) >= (maxDist + radius) * (maxDist + radius) then return false end

	local rightDot = dx * gsViewRightX + dy * gsViewRightY + dz * gsViewRightZ
	local upDot = dx * gsViewUpX + dy * gsViewUpY + dz * gsViewUpZ
	local maxX = forwardDot * gsFrustumTanX + radius
	local maxY = forwardDot * gsFrustumTanY + radius

	return !(rightDot > maxX or rightDot < -maxX or upDot > maxY or upDot < -maxY)
end

local function PushDraw(pos, size, mat, col, ang, alpha, rot, camAng, flatLightingT, isPrecip)
	local dx, dy, dz = pos.x - gsViewPosX, pos.y - gsViewPosY, pos.z - gsViewPosZ
	local forwardDot = dx * gsViewForwardX + dy * gsViewForwardY + dz * gsViewForwardZ

	if forwardDot <= -size then return end

	local distSqr = dx * dx + dy * dy + dz * dz
	if distSqr >= maxDistSqr then return end

	local rightDot = dx * gsViewRightX + dy * gsViewRightY + dz * gsViewRightZ
	local upDot = dx * gsViewUpX + dy * gsViewUpY + dz * gsViewUpZ
	local maxX = forwardDot * gsFrustumTanX + size
	local maxY = forwardDot * gsFrustumTanY + size

	if rightDot > maxX or rightDot < -maxX or upDot > maxY or upDot < -maxY then return end
	if distSqr > fadeStartSqr then alpha = alpha * ((maxDistSqr - distSqr) * fadeInv) end
	if alpha < 1 then return end

	local drawList, drawCount

	if isPrecip then
		drawList, drawCount = precipDrawB, precipDrawCountB
	else
		drawList, drawCount = drawB, drawCountB
	end

	drawCount = drawCount + 1

	local entry = GetDrawEntry(drawList, drawCount)

	entry.p, entry.distSqr, entry.s, entry.m, entry.r = pos, distSqr, size, mat, rot

	local c = entry.c
	local colDark = col.dark

	if colDark then
		local t = (mathCos(ang - sunAng) + 1) * 0.5

		if flatLightingT and flatLightingT > 0 then
			t = t + (((mathCos(camAng - sunAng) + 1) * 0.5) - t) * flatLightingT
		end

		local bright = col.bright
		local darkR, darkG, darkB = colDark.r, colDark.g, colDark.b

		c.r = darkR + (bright.r - darkR) * t
		c.g = darkG + (bright.g - darkG) * t
		c.b = darkB + (bright.b - darkB) * t
	else
		c.r, c.g, c.b = col.r, col.g, col.b
	end

	c.a = alpha

	if isPrecip then
		precipDrawCountB = drawCount
		if drawCount > precipDrawUsedB then precipDrawUsedB = drawCount end
	else
		drawCountB = drawCount
		if drawCount > drawUsedB then drawUsedB = drawCount end
	end
end

local function SortDraw(a, b) return a.distSqr > b.distSqr end

hookAdd("PostDrawTranslucentRenderables", "GS_ParticleDraw", function(depth, skybox)
	if skybox or depth or finalDrawCountA <= 0 then return end

	local lastMat
	local viewNormal = -EyeAngles():Forward()

	for i = 1, finalDrawCountA do
		local entry = finalDrawA[i]

		if entry.m ~= lastMat then
			lastMat = entry.m
			setMaterial(lastMat)
		end

		DrawQuadEasy(entry.p, viewNormal, entry.s, entry.s, entry.c, entry.r)
	end
end)

local function SampleCol(minColor, maxColor)
	if !maxColor then return minColor end
	local t = mathRand(0, 1)
	return Color(minColor.r + (maxColor.r - minColor.r) * t, minColor.g + (maxColor.g - minColor.g) * t, minColor.b + (maxColor.b - minColor.b) * t)
end

local function PrepareColors(prof)
	if prof.acPair then
		local bright, dark = GSGetLightEnvironment(prof.acPair.bright, prof.acPair.dark, nil, false)
		return {bright = bright, dark = dark}
	end

	if prof.acHasRanges then
		local bright, dark = GSGetLightEnvironment(SampleCol(prof.acBrightMin, prof.acBrightMax), SampleCol(prof.acDarkMin, prof.acDarkMax), nil, false)
		return {bright = bright, dark = dark}
	end

	if prof.colStatic then return GSGetLightEnvironment(nil, nil, prof.colStatic, true) end

	return GSGetLightEnvironment(nil, nil, SampleCol(prof.colRangeMin, prof.colRangeMax), true)
end

-- SIMPLE HELPERS
local function ProbCount(c)
	if c <= 0 then return 0 end
	if c < 1 then return (mathRand(0, 1) < c) and 1 or 0 end
	local n = mathFloor(c)
	if mathRand(0, 1) < (c - n) then n = n + 1 end
	return n
end

local function FadeFrac(t, fadeIn, fadeOut)
	if fadeIn > 0 and t < fadeIn then return t / fadeIn end
	if fadeOut > 0 and t > 1 - fadeOut then return (1 - t) / fadeOut end
	return 1
end

local function AlphaFromWS(prof, ws)
	local alphaMin = prof.afwAlphaMin
	local alphaMax = prof.afwAlphaMax
	local range = prof.afwWsMax - prof.afwWsMin
	if range <= 0 then return alphaMax end
	return alphaMin + (alphaMax - alphaMin) * mathClamp((ws - prof.afwWsMin) / range, 0, 1)
end

-- CLOUDS

local function CloudPush(group) 
	cloudCount = cloudCount + 1 
	cloudGroups[cloudCount] = group 
end

local function CloudKill(i)
	cloudGroups[i] = cloudGroups[cloudCount]
	cloudGroups[cloudCount] = nil
	cloudCount = cloudCount - 1
end

local function ClearClouds()
	for i = cloudCount, 1, -1 do cloudGroups[i] = nil end
	cloudCount = 0
	ClearBucket(cloudParticles)
end

local function SpawnAmbientClouds(prof, col, centerPos)
	local keep = mathRand(0.55, 1)
	local sample = GSGetUniformDistributionInCylinder(centerPos, prof.refSpawnRadius, 0, 0, true)

	local pSizeMult, pSizeMultRand = prof.pSizeMult, prof.pSizeMultRand
	local cloudMinSize, cloudMaxSize = prof.cloudMinSize, prof.cloudMaxSize
	local rotMin, rotMax = prof.rotMin, prof.rotMax
	local alphaMin, alphaMax = prof.alphaMin, prof.alphaMax

	local groupR = 7000 + keep * 9000
	local groupLife = prof.lifetime * mathRand(0.5, 1.5)
	local group = {pos = Vector(sample.x, sample.y, centerPos.z + prof.addHeight + keep * 3500), r = groupR, age = 0, life = groupLife, invLife = groupLife > 0 and (1 / groupLife) or 0}

	CloudPush(group)

	local c = prof.pCountMult * gsParticleAmountMult
	local count = (c < 1) and ((c > 0 and mathRand(0, 1) <= c) and 1 or 0) or mathFloor(8 * c + mathRand(0, 1))
	if count == 0 then return end

	local zRand = groupR * 0.12

	for i = 1, count do
		local ang = mathRand(0, twoPi)
		local randomRadius = mathSqrt(mathRand(0, 1)) * groupR
		local particle = PGet()

		local ox = mathCos(ang) * randomRadius
		local oy = mathSin(ang) * randomRadius

		particle.vel:SetUnpacked(ox, oy, mathRand(-zRand, zRand))
		particle.prof = prof
		particle.ref = group
		particle.aSelect = mathRandom(alphaMin, alphaMax)
		particle.size = Lerp(mathRand(0, 1), cloudMinSize, cloudMaxSize) * pSizeMult * mathRand(1, pSizeMultRand)
		particle.rot = mathRandom(rotMin, rotMax)
		particle.baseAng = mathAtan2(oy, ox)
		particle.col = col

		BucketPush(cloudParticles, particle)
	end
end

local function UpdateClouds(prof, col, curTime, centerPos, env)
	if cloudLast == 0 then cloudLast = curTime - nextThink end

	cloudDt = curTime - cloudLast
	cloudLast = curTime

	local speed = env.Windspeed * 0.5
	local windDir = env.WindDirection
	local windDirX, windDirY = windDir.x, windDir.y
	local spawnRadius = prof.refSpawnRadius
	local backDist = spawnRadius * 0.95

	for i = cloudCount, 1, -1 do
		local group = cloudGroups[i]

		group.age = group.age + cloudDt

		if group.life > 0 and group.age >= group.life then 
			group.pos = nil 
			CloudKill(i) 
			continue 
		end

		local groupPos = group.pos

		groupPos:SetUnpacked(groupPos.x + windDirX * speed * cloudDt, groupPos.y + windDirY * speed * cloudDt, groupPos.z)

		if speed > 0 and groupPos:Distance2D(centerPos) > spawnRadius * 1.35 then
			groupPos:SetUnpacked(centerPos.x - windDirX * backDist + mathRandom(-9000, 9000), centerPos.y - windDirY * backDist + mathRandom(-9000, 9000), groupPos.z)
		end

		group.visible = SphereVisible(groupPos.x, groupPos.y, groupPos.z, group.r * 1.15)
	end

	if mathRand(0, 1) <= (0.015 * prof.cCountMult) then SpawnAmbientClouds(prof, col, centerPos) end
end

local function UpdateCloudParticles()
	for i = cloudParticles.n, 1, -1 do
		local particle = cloudParticles[i]
		local group = particle.ref

		if !group.pos then BucketKill(cloudParticles, i) continue end

		local prof = particle.prof
		local off = particle.vel
		local offX, offY, offZ = off.x, off.y, off.z - (prof.fallSpeed * cloudDt)

		off:SetUnpacked(offX, offY, offZ)

		local groupPos = group.pos
		local pos = particle.pos

		pos:SetUnpacked(groupPos.x + offX, groupPos.y + offY, groupPos.z + offZ)

		if group.visible then
			PushDraw(pos, particle.size, prof.mat, particle.col, particle.baseAng, particle.aSelect * FadeFrac(group.age * group.invLife, prof.fadeIn, prof.fadeOut), particle.rot)
		end
	end
end

-- SPAWNERS

local function SpawnRainAndDownfallSheets(entityList, prof, centerPos, plyPos, col, isRain, noHurricane, needRain)
	local count = ProbCount(prof.pCountMult * gsParticleAmountMult)
	if count == 0 then return end

	local spawnRadius = prof.refSpawnRadius
	local samplePos = isRain and plyPos or GSGetUniformDistributionInCylinder(centerPos, spawnRadius, 0, 0, true)
	local refl, h, parent = GSGetStormReflectivityValueFromPoint(samplePos, false, entityList)

	if !IsValid(parent) or !parent.Networked or refl <= prof.refMinReflectivity then return end
	if (noHurricane and parent.Hurricane) or (needRain and !parent.EnableRain) then return end

	local parentPos = parent.Position
	local parentPosX, parentPosY, parentPosZ = parentPos.x, parentPos.y, parentPos.z

	if isRain then
		if plyPos.z > parentPosZ + h + 2000 then return end

		rainTraceStart:SetUnpacked(plyPos.x, plyPos.y, plyPos.z + 100)
		rainTraceEnd:SetUnpacked(plyPos.x, plyPos.y, plyPos.z + 2000)
		
		local tr = utilTraceLine(rainTrace)
		local hitEnt = tr.Entity or tr.HitEntity

		if tr.Hit and (!IsValid(hitEnt) or !GSGetIsVehicle(hitEnt, hitEnt:GetClass())) then return end
	end

	local emit = EnsureEmitter(parent)
	local bucket = isRain and emit.precip or emit.reflect
	local alphaMult = prof.refNoAlphaReflectivity and 1 or (((refl - prof.refMinReflectivity) / prof.refMaxReflectivity) * prof.refAlphaMult)
	local addH = prof.addHeight
	local rotMin, rotMax = prof.rotMin, prof.rotMax
	local pSizeMult, pSizeMultRand = prof.pSizeMult, prof.pSizeMultRand
	local alphaMin, alphaMax = prof.alphaMin, prof.alphaMax
	local invLife = prof.invLife

	for i = 1, count do
		local particle = PGet()
		local pos = particle.pos
		local off = particle.vel

		if isRain then
			off:SetUnpacked((plyPos.x - parentPosX) + mathRandom(-spawnRadius, spawnRadius), (plyPos.y - parentPosY) + mathRandom(-spawnRadius, spawnRadius), (plyPos.z - parentPosZ) + addH)

			if prof.rainPhys then
				pos:SetUnpacked(parentPosX + off.x, parentPosY + off.y, parentPosZ + off.z)
			end
		else
			off:SetUnpacked(samplePos.x - parentPosX, samplePos.y - parentPosY, h + addH)
		end

		particle.prof = prof
		particle.age = 0
		particle.invLife = invLife
		particle.aSelect = mathRandom(alphaMin, alphaMax) * alphaMult
		particle.size = pSizeMult * mathRand(1, pSizeMultRand)
		particle.rot = mathRandom(rotMin, rotMax)
		particle.baseAng = mathAtan2(off.y, off.x)
		particle.col = col

		BucketPush(bucket, particle)
	end
end

local function GetCondEmitterState(ownerEnt, vortexEnt, centeredLocked)
	local emit = ownerEnt.GSCondEmit
	local eidx = (vortexEnt == ownerEnt) and 0 or vortexEnt:EntIndex()

	if !emit then
		emit = {}
		ownerEnt.GSCondEmit = emit
	end

	local st = emit[eidx]
	if !st then
		st = {acc = 0, hPhase = mathRand(0, 1), aPhase = mathRand(0, twoPi)}
		emit[eidx] = st
	end

	if centeredLocked then
		local cst = st.centered
		if !cst then
			cst = {acc = 0, hPhase = 0, aPhase = mathRand(0, twoPi), hCarry = 0, spawnElapsed = 0}
			st.centered = cst
		end

		return cst
	end

	return st
end

local function CoverageSample(h, startH, maxH, baseWidth, midWidth, midWidthHeight, topWidth, widthExponent, ws, rmw, orbitRadius, orbitRadSizeMult, orbitSize, particleMaxSize, avgSizeMult, rMinConst, ringH, ringR, centered)
	local rBase = rmw * GSVortexShapeFromHeightMultiplier(h, startH, maxH, baseWidth, midWidth, midWidthHeight, topWidth, widthExponent, orbitRadSizeMult, true)
	local ringMul = (h <= ringH) and (ringR * 0.875) or 1
	local size = (rBase * ringMul) * orbitRadSizeMult + orbitSize

	if particleMaxSize and size > particleMaxSize then size = particleMaxSize end

	local sizeCoreCapped = mathMax(size - orbitSize, 1)
	local r = (mathMax(rBase - (rBase * orbitRadSizeMult + orbitSize) * orbitRadSizeMult, rMinConst) + orbitRadius) * ringMul
	local avgDrawSize = size * avgSizeMult
	local effectiveR = centered and mathMax(avgDrawSize * gsCenteredEffectiveRadiusMult, 1) or r
	local comp = 1

	if !centered then
		comp = (mathMax(rBase * ringMul - sizeCoreCapped * orbitRadSizeMult, 1) * size) / mathMax(sizeCoreCapped * r, 1)
	end

	return effectiveR * (GSGetSpeedFromRadius(ws, effectiveR, rmw, 2)) / mathMax(avgDrawSize, 1), comp
end

local function SpawnCondOrbit(ownerEnt, vortexEnt, prof, attemptsMult, startH, maxH, col, ws, rmw, baseWidth, midWidth, midWidthHeight, topWidth, widthExponent, noiseAmp, noiseFreq, anticyclonic, ringH, ringR, nDetail, nPeak, supportsCondThreshold)
	local centered = prof.centered
	local centeredLocked = centered and vortexEnt == ownerEnt
	local st = GetCondEmitterState(ownerEnt, vortexEnt, centeredLocked)
	local pSizeMult, pSizeMultRand, particleMaxSize = prof.pSizeMult, prof.pSizeMultRand, prof.particleMaxSize
	local orbitRadius, orbitRadSizeMult, orbitSize = prof.orbitRadius, prof.orbitRadSizeMult, prof.orbitSize
	local rMinConst = mathMax(orbitSize * 0.5, 1, orbitRadius)
	local spanH, addH = maxH - startH, prof.addHeight
	local avgSizeMult = pSizeMult * ((1 + pSizeMultRand) * 0.5)
	local midFrac = mathClamp(midWidthHeight or 0.5, tinyVal, 1 - tinyVal)
	local fracBaseEnd, fracMidEnd = midFrac * frac2, midFrac + (1 - midFrac) * frac1

	local baseNeed, baseComp = CoverageSample(startH + spanH * (fracBaseEnd * 0.5), startH, maxH, baseWidth, midWidth, midWidthHeight, topWidth, widthExponent, ws, rmw, orbitRadius, orbitRadSizeMult, orbitSize, particleMaxSize, avgSizeMult, rMinConst, ringH, ringR, centered)
	local midNeed, midComp = CoverageSample(startH + spanH * ((fracBaseEnd + fracMidEnd) * 0.5), startH, maxH, baseWidth, midWidth, midWidthHeight, topWidth, widthExponent, ws, rmw, orbitRadius, orbitRadSizeMult, orbitSize, particleMaxSize, avgSizeMult, rMinConst, ringH, ringR, centered)
	local topNeed, topComp = CoverageSample(startH + spanH * (fracMidEnd + (1 - fracMidEnd) * 0.5), startH, maxH, baseWidth, midWidth, midWidthHeight, topWidth, widthExponent, ws, rmw, orbitRadius, orbitRadSizeMult, orbitSize, particleMaxSize, avgSizeMult, rMinConst, ringH, ringR, centered)

	st.acc = st.acc + prof.pCountMult * gsParticleAmountMult * attemptsMult * (baseNeed * fracBaseEnd + midNeed * (fracMidEnd - fracBaseEnd) + topNeed * (1 - fracMidEnd)) * (baseComp * fracBaseEnd + midComp * (fracMidEnd - fracBaseEnd) + topComp * (1 - fracMidEnd)) * ((spanH + GSReturnPositionNoiseMaxOffset(maxH, noiseAmp, noiseFreq, nDetail, nPeak)) / 7500)

	if centeredLocked then st.spawnElapsed = st.spawnElapsed + (ownerEnt.GSParticleDt or nextThink) end

	local attempts = centeredLocked and mathFloor(st.acc) or ProbCount(st.acc)
	if attempts == 0 then return end

	st.acc = st.acc - attempts

	local needSum = baseNeed + midNeed + topNeed
	local t0, t1 = baseNeed / needSum, (baseNeed + midNeed) / needSum
	local fracBaseMul = fracBaseEnd / t0
	local fracMidMul = (fracMidEnd - fracBaseEnd) / (t1 - t0)
	local fracTopMul = (1 - fracMidEnd) / (1 - t1)

	local isSubv = (vortexEnt ~= ownerEnt)
	local bucket = isSubv and EnsureEmitter(ownerEnt).subv or EnsureEmitter(ownerEnt).orbit
	local invLife = prof.invLife
	local rotMin, rotMax = prof.rotMin, prof.rotMax
	local alphaMin, alphaMax = prof.alphaMin, prof.alphaMax
	local hPhase, aPhase = st.hPhase, st.aPhase

	local blendTop = prof.blendTop
	local invDiff = 1 / maxH
	local angMul = anticyclonic and -1 or 1
	local centeredR = centered and 1 or nil

	local hCarry, centeredFracStep = 0, 0

	if centeredLocked then
		hCarry = st.hCarry

		local liftSpeed = 3 * ownerEnt.VortexModelParameters.alpha * ws - prof.fallSpeed
		if liftSpeed > 0 and spanH > tinyVal then
			centeredFracStep = liftSpeed * (st.spawnElapsed / attempts) / spanH
		end

		st.spawnElapsed = 0
	end

	local condParamHeight, condParamWS, condExponent = ownerEnt.ParticleCondHeight, ownerEnt.ParticleCondWindspeed, ownerEnt.ParticleCondExponent
	local condParamWSMax = condParamWS + ownerEnt.ParticleCondRange

	local useCondThreshold, condHeightFrac, condHeightInv, condBaseAlpha, condAlphaSpan = false, 0, 0, 1, 0

	if supportsCondThreshold and condParamHeight > 0 and ws < condParamWSMax then
		local condT = 0
		if ws > condParamWS and condParamWSMax > condParamWS then condT = (ws - condParamWS) / (condParamWSMax - condParamWS) end

		condHeightFrac = condParamHeight * (1 - condT)
		condBaseAlpha = ownerEnt.ParticleCondAlphaMin + (1 - ownerEnt.ParticleCondAlphaMin) * condT
		condAlphaSpan = 1 - condBaseAlpha

		if condHeightFrac > 0 then
			condHeightInv = 1 / condHeightFrac
			useCondThreshold = true
		end
	end

	for i = 1, attempts do
		local fracH = (hPhase < t0) and (hPhase * fracBaseMul) or (hPhase < t1) and (fracBaseEnd + (hPhase - t0) * fracMidMul) or (fracMidEnd + (hPhase - t1) * fracTopMul)

		hPhase = hPhase + invPhi
		if hPhase >= 1 then hPhase = hPhase - 1 end

		if centeredLocked and centeredFracStep > 0 then
			fracH = fracH + hCarry
			if fracH >= 1 then fracH = fracH - mathFloor(fracH) end

			hCarry = hCarry + centeredFracStep
			if hCarry >= 1 then hCarry = hCarry - mathFloor(hCarry) end
		end

		local h = startH + spanH * fracH
		local particle = PGet()
		local rBase = rmw * GSVortexShapeFromHeightMultiplier(h, startH, maxH, baseWidth, midWidth, midWidthHeight, topWidth, widthExponent, orbitRadSizeMult, true)
		local ringMul = (h <= ringH) and (ringR * mathRand(0.75, 1)) or 1
		local size = (rBase * ringMul) * orbitRadSizeMult + orbitSize

		if particleMaxSize and size > particleMaxSize then size = particleMaxSize end

		local r = (mathMax(rBase - (rBase * orbitRadSizeMult + orbitSize) * orbitRadSizeMult, rMinConst) + orbitRadius) * ringMul

		if isSubv then particle.ref = vortexEnt end

		local sizeDraw = size * pSizeMult * mathRand(1, pSizeMultRand)
		local effectiveR = centered and mathMax(sizeDraw * gsCenteredEffectiveRadiusMult, 1) or r
		local ang = ((aPhase - fracH * twoPi) * angMul) + mathRand(-1, 1) * gsCondArtifactElimination * mathMin(sizeDraw / mathMax(effectiveR, size, 1), 1)

		aPhase = aPhase + goldenAng
		if aPhase >= twoPi then aPhase = aPhase - twoPi end

		local condThresholdMul = 1
		if useCondThreshold and fracH < condHeightFrac then condThresholdMul = (condBaseAlpha + condAlphaSpan * (fracH * condHeightInv))^condExponent end

		particle.prof = prof
		particle.invLife = invLife
		particle.baseAng = ang
		particle.prog = 0
		particle.age = 0
		particle.aSelect = mathRandom(alphaMin, alphaMax) * (blendTop and (1 - h * invDiff) or 1) * condThresholdMul
		particle.size = sizeDraw
		particle.r = centeredR or r
		particle.h = h + addH
		particle.omega = GSGetSpeedFromRadius(ws, effectiveR, rmw, 2)
		particle.rot = mathRandom(rotMin, rotMax)
		particle.col = col

		BucketPush(bucket, particle)
	end

	st.hPhase = hPhase
	st.aPhase = aPhase

	if centeredLocked then
		st.hCarry = hCarry
	end
end

local function SpawnMesoAndHurricane(ent, prof, col, isHurricane, ws, rmw, mesoSize, baseH, spout)
	local count = ProbCount(mesoSize * 0.00005 * prof.pCountMult * gsParticleAmountMult * (isHurricane and 2.5 or 1))
	if count == 0 then return end

	local emit = EnsureEmitter(ent)
	local bucket = emit.orbit
	local sizeMult = isHurricane and 5625 or 3750
	local pSizeMult, pSizeMultRand = prof.pSizeMult, prof.pSizeMultRand
	local alphaMin, alphaMax = prof.alphaMin, prof.alphaMax
	local rotMin, rotMax = prof.rotMin, prof.rotMax
	local invLife = prof.invLife
	local addHeight = prof.addHeight
	local r

	for i = 1, count do
		local particle = PGet()
		local pSize = sizeMult * pSizeMult * mathRand(1, pSizeMultRand)

		particle.prof = prof
		particle.invLife = invLife
		particle.baseAng = mathRand(0, twoPi)
		particle.prog, particle.age = 0, 0
		particle.aSelect = mathRandom(alphaMin, alphaMax)

		if isHurricane then
			r = mathSqrt(rmw * rmw + (hurricaneScale - rmw * rmw) * mathRand(0, 1)) + (pSize * 0.2)
		else
			r = mathSqrt(mathRand(0, 1)) * mesoSize
		end

		particle.r = r
		particle.h = mathRandom(baseH, baseH + 2000) + addHeight
		particle.size = pSize
		particle.omega = spout and 0 or GSGetSpeedFromRadius(ws, r, rmw, 2)
		particle.rot = mathRandom(rotMin, rotMax)
		particle.col = col

		BucketPush(bucket, particle)
	end
end

local function SpawnCurt(ent, prof, col, ws, rmw, entPosX, entPosY, entPosZ, maxH, vortexSize)
	local count = ProbCount(prof.pCountMult * gsParticleAmountMult)
	if count == 0 then return end

	local emit = EnsureEmitter(ent)
	local bucket = emit.physics
	local step, baseAng, scale = twoPi / count, mathRand(0, twoPi), mathMax(rmw * 5, vortexSize * 0.2)
	local stepSize = step * 0.35
	local rotMin, rotMax = prof.rotMin, prof.rotMax
	local alphaMin, alphaMax = prof.alphaMin, prof.alphaMax
	local pSizeMult, pSizeMultRand = prof.pSizeMult, prof.pSizeMultRand
	local addHeight = prof.addHeight
	local invLife = prof.invLife
	local wsAlphaMult = AlphaFromWS(prof, ws)

	alphaMin = alphaMin * wsAlphaMult
	alphaMax = alphaMax * wsAlphaMult

	for i = 1, count do
		local ang = baseAng + step * i + mathRand(-stepSize, stepSize)
		local r = mathRand(rmw * 3, scale)
		local particle = PGet()
		local pos = particle.pos

		pos:SetUnpacked(mathCos(ang) * r + entPosX, mathSin(ang) * r + entPosY, mathRand(0, maxH) + entPosZ + addHeight)

		particle.vel:SetUnpacked(0, 0, 0)
		particle.prof = prof
		particle.invLife = invLife
		particle.r = r
		particle.age = 0
		particle.col = col
		particle.rot = mathRandom(rotMin, rotMax)
		particle.aSelect = mathRandom(alphaMin, alphaMax)
		particle.size = pSizeMult * mathRand(1, pSizeMultRand)

		BucketPush(bucket, particle)
	end
end

local function SpawnDeb(ent, prof, col, ws, rmw, entPosX, entPosY, entPosZ, startH, dustDevil)
	local count = ProbCount(prof.pCountMult * gsParticleAmountMult)
	if count == 0 then return end

	local emit = EnsureEmitter(ent)
	local bucket = emit.physics
	local covColorProf, covAlphaMult = prof.covColorProfile, prof.covAlphaMult
	local debrisHeight, debrisRad = mathMin(startH + 250, 750), mathMax(rmw * 2, !dustDevil and 500 or 1)
	local waterCol
	local addH = prof.addHeight
	local invLife = prof.invLife
	local rotMin, rotMax = prof.rotMin, prof.rotMax
	local pSizeMult, pSizeMultRand = prof.pSizeMult, prof.pSizeMultRand
	local wsAlphaMult = AlphaFromWS(prof, ws)
	local alphaMin, alphaMax = prof.alphaMin * wsAlphaMult, prof.alphaMax * wsAlphaMult

	if covColorProf then waterCol = PrepareColors(covColorProf) end

	for i = 1, count do

		local ang = mathRand(0, twoPi)
		local r = mathRandom(rmw, debrisRad)
		local particle = PGet()
		local pos = particle.pos

		pos:SetUnpacked(mathCos(ang) * r + entPosX, mathSin(ang) * r + entPosY, mathRandom(0, debrisHeight) + entPosZ + addH)

		local overWater = false

		if !dustDevil and covColorProf then
			debrisGroundSample:SetUnpacked(pos.x, pos.y, pos.z - addH)
			overWater = GSGetGroundMaterial(debrisGroundSample) == 2
		end

		particle.vel:SetUnpacked(0, 0, 0)
		particle.prof = prof
		particle.r = r
		particle.age = 0
		particle.col = (overWater and waterCol) or col
		particle.rot = mathRandom(rotMin, rotMax)
		particle.size = (r + 1000) * pSizeMult * mathRand(1, pSizeMultRand)
		particle.aSelect = mathRandom(alphaMin, alphaMax) * ((overWater and covAlphaMult) or 1)
		particle.invLife = invLife

		BucketPush(bucket, particle)
	end
end

local function FlowInvLife(ent, prof)
	if prof.invLife > 0 then return prof.invLife end

	local life = ent.ParticleLifetime or 0
	if life <= 0 then life = 12 end

	return 1 / life
end

local function FlowTraceToGround(pos)
	flowTraceStart:SetUnpacked(pos.x, pos.y, pos.z + 1000)
	flowTraceEnd:SetUnpacked(pos.x, pos.y, pos.z - 6500)

	local tr = utilTraceLine(flowTraceData)

	if tr.Hit then
		local hitPos = tr.HitPos
		pos:SetUnpacked(hitPos.x, hitPos.y, hitPos.z)
	end
end

local function SpawnFlow(ent, prof, col)
	local count = ProbCount(mathClamp((ent.FlowLinear and mathMax(mathFloor(ent.FlowLinearWidth / 2000), 1) or mathMax(mathFloor((ent.FlowDistRadCurrent + ent.FlowRadialDepth) / 2000), 1)) * ent.FlowWindspeed * 0.02, 1, 20) * prof.pCountMult * gsParticleAmountMult)
	if count == 0 then return end

	local emit = EnsureEmitter(ent)
	local bucket = emit.flow
	local entPos = ent.Position
	local entPosX, entPosY, entPosZ = entPos.x, entPos.y, entPos.z
	local invLife = FlowInvLife(ent, prof)
	local speed = ent.FlowWindspeed * gsMPHToHUPerSec * 0.4

	if ent.FlowLinear then
		local dir = ent.FlowLinearDirection
		local dirX, dirY = dir.x, dir.y
		local len = mathSqrt(dirX * dirX + dirY * dirY)
		if len <= 0.0001 then return end

		local invLen = 1 / len
		dirX, dirY = dirX * invLen, dirY * invLen

		local rightX, rightY = dirY, -dirX
		local flowPosX = entPosX + dirX * ent.FlowDistRadCurrent
		local flowPosY = entPosY + dirY * ent.FlowDistRadCurrent
		local halfW = ent.FlowLinearWidth * 0.5
		local frontDepth = mathMin(ent.FlowLinearLength, 500)
		local baseSize = mathClamp(ent.FlowLinearWidth * 0.125, 650, 3500)

		for i = 1, count do
			local particle = PGet()
			local pos = particle.pos
			local f = mathRand(-frontDepth, 0)
			local s = mathRand(-halfW, halfW)

			pos:SetUnpacked(flowPosX + dirX * f + rightX * s, flowPosY + dirY * f + rightY * s, entPosZ + prof.addHeight)
			FlowTraceToGround(pos)
			pos:SetUnpacked(pos.x, pos.y, pos.z + mathRandom(25, 125))

			particle.vel:SetUnpacked(dirX * speed, dirY * speed, 0)
			particle.prof = prof
			particle.age = 0
			particle.invLife = invLife
			particle.aSelect = mathRandom(prof.alphaMin, prof.alphaMax)
			particle.size = baseSize * prof.pSizeMult * mathRand(1, prof.pSizeMultRand)
			particle.rot = mathRandom(prof.rotMin, prof.rotMax)
			particle.col = col

			BucketPush(bucket, particle)
		end

	elseif ent.FlowRadial then
		local outer = ent.FlowDistRadCurrent
		if outer <= 1 then return end

		local inner = mathMax(outer - ent.FlowRadialDepth, 0)
		local baseSize = mathClamp(ent.FlowRadialDepth * 0.65, 650, 3200)

		for i = 1, count do
			local a = mathRand(0, twoPi)
			local r = mathSqrt(inner * inner + (mathRand(0, 1)) * (outer * outer - inner * inner))
			local dirX, dirY = mathCos(a), mathSin(a)
			local particle = PGet()
			local pos = particle.pos

			pos:SetUnpacked(entPosX + dirX * r, entPosY + dirY * r, entPosZ + prof.addHeight)
			FlowTraceToGround(pos)
			pos:SetUnpacked(pos.x, pos.y, pos.z + mathRandom(25, 125))

			particle.vel:SetUnpacked(dirX * speed, dirY * speed, 0)
			particle.prof = prof
			particle.age = 0
			particle.invLife = invLife
			particle.aSelect = mathRandom(prof.alphaMin, prof.alphaMax)
			particle.size = baseSize * prof.pSizeMult * mathRand(1, prof.pSizeMultRand)
			particle.rot = mathRandom(prof.rotMin, prof.rotMax)
			particle.col = col

			BucketPush(bucket, particle)
		end
	end
end

-- EMITTER UPDATERS

local function CacheLastDraw(particle, size, ang, alpha, camAng, flatLightingT)
	particle.lastDrawSize = size
	particle.lastDrawAng = ang
	particle.lastDrawAlpha = alpha
	particle.lastDrawCamAng = camAng
	particle.lastDrawFlatLightingT = flatLightingT
end

local function UpdateFlowBucket(bucket, dt, camAng, fadeMul)
	for i = bucket.n, 1, -1 do
		local particle = bucket[i]
		local prof = particle.prof
		local invLife = particle.invLife
		local age = particle.age + dt
		local pos = particle.pos
		local vel = particle.vel
		local lifeFrac = age * invLife

		particle.age = age

		if invLife > 0 and lifeFrac >= 1 then
			BucketKill(bucket, i)
			continue
		end

		local keep = 1 - lifeFrac
		local velX, velY = vel.x * keep, vel.y * keep
		local ang = mathAtan2(velY, velX)
		local size = particle.size * Lerp(lifeFrac, 1, prof.flowSizeEndMult)
		local alpha = particle.aSelect * FadeFrac(lifeFrac, prof.fadeIn, prof.fadeOut) * (prof.useAngleAlpha and GSGetAngleAlpha(ang, camAng) or 1) * fadeMul

		CacheLastDraw(particle, size, ang, alpha)
		PushDraw(pos, size, prof.mat, particle.col, ang, alpha, particle.rot)

		pos:SetUnpacked(pos.x + velX * dt, pos.y + velY * dt, pos.z + vel.z * keep * dt - (prof.fallSpeed * dt))
	end
end

local function UpdateReflectBucket(bucket, dt, entPosX, entPosY, entPosZ, locDirX, locDirY, fadeMul, isPrecip)
	for i = bucket.n, 1, -1 do
		local particle = bucket[i]
		local prof = particle.prof
		local invLife = particle.invLife
		local age = particle.age + dt

		particle.age = age

		local lifeFrac = age * invLife
		if invLife > 0 and lifeFrac >= 1 then BucketKill(bucket, i) continue end

		local pos = particle.pos
		local ang = particle.baseAng
		local alpha = particle.aSelect * FadeFrac(lifeFrac, prof.fadeIn, prof.fadeOut) * fadeMul
		local pSize = particle.size

		if isPrecip then
			local off = particle.vel
			local fall = prof.fallSpeed * dt
			local offX, offY, offZ = off.x + locDirX, off.y + locDirY, off.z - fall

			off:SetUnpacked(offX, offY, offZ)
			pos:SetUnpacked(pos.x + locDirX, pos.y + locDirY, pos.z - fall)

			CacheLastDraw(particle, pSize, ang, alpha)
			PushDraw(pos, pSize, prof.mat, particle.col, ang, alpha, particle.rot, nil, nil, true)
		else
			local off = particle.vel
			local offX, offY, offZ = off.x, off.y, off.z - (prof.fallSpeed * dt)

			off:SetUnpacked(offX, offY, offZ)
			pos:SetUnpacked(entPosX + offX, entPosY + offY, entPosZ + offZ)

			CacheLastDraw(particle, pSize, ang, alpha)
			PushDraw(pos, pSize, prof.mat, particle.col, ang, alpha, particle.rot)
		end
	end
end

local function UpdateOrbitBucket(bucket, dt, entPosX, entPosY, entPosZ, ws, anticyclonic, alpha, nfreq, namp, nspeed, nseed, nphase, camAng, curTime, fadeMul, angDir, nDetail, nPeak, maxH)
	local lift = 3 * dt * alpha * ws
	local dt75 = dt * 75

	for i = bucket.n, 1, -1 do
		local particle = bucket[i]
		local prof = particle.prof
		local invLife = particle.invLife
		local age = particle.age + dt
		local omega = particle.omega
		local prog = particle.prog + omega
		local h = particle.h - (prof.fallSpeed * dt) + lift

		particle.h = h
		particle.prog = prog
		particle.age = age

		local lifeFrac = invLife > 0 and age * invLife or 0
		if prog >= twoPi or (invLife > 0 and lifeFrac >= 1) then BucketKill(bucket, i) continue end

		local r = particle.r
		local ang = particle.baseAng + (prog * angDir)
		local rot = particle.rot or 0
		local spinSpeed = prof.spinSpeed or 0

		if spinSpeed ~= 0 then
			rot = rot + spinSpeed * omega * prof.spinDir * dt75
			particle.rot = rot
		end

		local offX, offY = GSGetModifiedTornadoOffsetFromHeightAndNoise(h, nfreq, namp, nspeed, anticyclonic, nseed, nphase, curTime, nDetail, nPeak, maxH)
		local pos = particle.pos

		pos:SetUnpacked(mathCos(ang) * r + entPosX + offX, mathSin(ang) * r + entPosY + offY, entPosZ + h)

		local pSize = particle.size
		local alphaOut = particle.aSelect * (FadeFrac(prof.useLifetimeOverride and lifeFrac or (prog * invTwoPi), prof.fadeIn, prof.fadeOut) * (prof.useAngleAlpha and GSGetAngleAlpha(ang, camAng) or 1) * AlphaFromWS(prof, ws)) * fadeMul
		local flatLightingT = GSGetRopeFlatLightingBlend(r, pSize)

		CacheLastDraw(particle, pSize, ang, alphaOut, camAng, flatLightingT)
		PushDraw(pos, pSize, prof.mat, particle.col, ang, alphaOut, rot, camAng, flatLightingT)
	end
end

local function UpdateSubvBucket(bucket, dt, anticyclonic, nfreq, namp, nspeed, nseed, nphase, curTime, fadeMul, angDir, nDetail, nPeak, maxH)
	local dt75 = dt * 75

	for i = bucket.n, 1, -1 do
		local particle = bucket[i]
		local prof = particle.prof
		local invLife = particle.invLife
		local age = particle.age + dt
		local prog = particle.prog + particle.omega
		local h = particle.h - (prof.fallSpeed * dt)
		local subv = particle.ref

		if !IsValid(subv) or !subv.Networked then BucketKill(bucket, i) continue end

		particle.h = h
		particle.prog = prog
		particle.age = age

		local lifeFrac = age * invLife
		if prog >= twoPi or (invLife > 0 and lifeFrac >= 1) then BucketKill(bucket, i) continue end

		local rot = particle.rot or 0
		local spinSpeed = prof.spinSpeed or 0

		if spinSpeed ~= 0 then
			rot = rot + spinSpeed * particle.omega * prof.spinDir * dt75
			particle.rot = rot
		end

		local ang = particle.baseAng + (prog * angDir)
		local subvPos = subv.Position
		local parentOffX, parentOffY = GSGetModifiedTornadoOffsetFromHeightAndNoise(h, nfreq, namp, nspeed, anticyclonic, nseed, nphase, curTime, nDetail, nPeak, maxH)
		local subvOffX, subvOffY = GSGetModifiedTornadoOffsetFromHeightAndNoise(h, subv.VortexPositionNoiseFrequency, subv.VortexPositionNoiseAmplitude, subv.VortexPositionNoiseSpeed, anticyclonic, subv.VortexPositionNoiseSeed, subv.VortexPositionNoisePhase, curTime, subv.VortexPositionNoiseDetail, subv.VortexPositionNoisePeak, subv.FunnelMaxHeight)
		local pos = particle.pos
		local subvCamAng = subv.GSParticleCamAng or 0
		local r = particle.r

		pos:SetUnpacked(mathCos(ang) * r + (subvPos.x + parentOffX + subvOffX), mathSin(ang) * r + (subvPos.y + parentOffY + subvOffY), h + subvPos.z)

		local alphaOut = particle.aSelect * (FadeFrac(prof.useLifetimeOverride and lifeFrac or (prog * invTwoPi), prof.fadeIn, prof.fadeOut) * (prof.useAngleAlpha and GSGetAngleAlpha(ang, subvCamAng) or 1) * AlphaFromWS(prof, subv.VortexWindspeed)) * fadeMul
		local pSize = particle.size
		local flatLightingT = GSGetRopeFlatLightingBlend(r, pSize)

		CacheLastDraw(particle, pSize, ang, alphaOut, subvCamAng, flatLightingT)
		PushDraw(pos, pSize, prof.mat, particle.col, ang, alphaOut, particle.rot, subvCamAng, flatLightingT)
	end
end

local function UpdatePhysicsBucket(bucket, dt, entPosX, entPosY, entPosZ, anticyclonic, nfreq, namp, nspeed, nseed, nphase, moveX, moveY, moveZ, vortexSize, vortexRMWSize, ws, forwardsSpeedMPH, vortexModelParameters, funnelWidthTable, curTime, fadeMul, nDetail, nPeak, maxH)
	local ar = dt * 2000

	for i = bucket.n, 1, -1 do
		local particle = bucket[i]
		local prof = particle.prof
		local invLife = particle.invLife
		local age = particle.age + dt

		particle.age = age

		local lifeFrac = age * invLife
		if invLife > 0 and lifeFrac >= 1 then BucketKill(bucket, i) continue end

		local pos = particle.pos
		local posX, posY, posZ = pos.x, pos.y, pos.z
		local dz = mathMax(posZ - entPosZ, 0)
		local centerX, centerY = GSGetModifiedTornadoPosFromHeightAndNoise(entPosX, entPosY, entPosZ, dz, nfreq, namp, nspeed, anticyclonic, nseed, nphase, curTime, nDetail, nPeak, maxH)
		local dx, dy = posX - centerX, posY - centerY
		local windspeed, vX, vY, vZ = GSMainVortexWindspeed(dx, dy, mathSqrt(dx * dx + dy * dy), dz, vortexSize, vortexRMWSize, ws, moveX, moveY, moveZ, forwardsSpeedMPH, anticyclonic, vortexModelParameters, funnelWidthTable, maxH)
		local vel = particle.vel
		local newVelX = mathApproach(vel.x, vX * windspeed * prof.physX, ar)
		local newVelY = mathApproach(vel.y, vY * windspeed * prof.physY, ar)
		local newVelZ = mathApproach(vel.z, vZ * windspeed * prof.physZ, ar)
		local ang = mathAtan2(dy, dx)
		local alphaOut = particle.aSelect * FadeFrac(lifeFrac, prof.fadeIn, prof.fadeOut) * fadeMul
		local pSize = particle.size

		CacheLastDraw(particle, pSize, ang, alphaOut)
		PushDraw(pos, pSize, prof.mat, particle.col, ang, alphaOut, particle.rot)

		vel:SetUnpacked(newVelX, newVelY, newVelZ)
		pos:SetUnpacked(posX + newVelX * dt, posY + newVelY * dt, posZ + newVelZ * dt - (prof.fallSpeed * dt))
	end
end

local function UpdateDeadBucket(bucket, fadeMul)
	for i = bucket.n, 1, -1 do
		local particle = bucket[i]
		PushDraw(particle.pos, particle.lastDrawSize or particle.size, particle.prof.mat, particle.col, particle.lastDrawAng or particle.baseAng or 0, (particle.lastDrawAlpha or particle.aSelect) * fadeMul, particle.rot, particle.lastDrawCamAng, particle.lastDrawFlatLightingT)
	end
end

local function UpdateDeadFlowBucket(bucket, fadeMul, deadDt)
	for i = bucket.n, 1, -1 do
		local particle = bucket[i]
		local prof = particle.prof
		local invLife = particle.invLife
		local age = particle.age + deadDt

		particle.age = age

		local size = particle.size * Lerp((invLife > 0) and mathMin(age * invLife, 1) or 1, 1, prof.flowSizeEndMult)

		particle.lastDrawSize = size

		PushDraw(particle.pos, size, prof.mat, particle.col, particle.lastDrawAng or 0, (particle.lastDrawAlpha or particle.aSelect) * fadeMul, particle.rot)
	end
end

hookAdd("RenderScene", "GSParticleCachedRenderView", function(origin, angles, fov)
	gsViewPos = origin
	gsViewPosX, gsViewPosY, gsViewPosZ = origin.x, origin.y, origin.z

	local forward = angles:Forward()
	local right = angles:Right()
	local up = angles:Up()

	gsViewForwardX, gsViewForwardY, gsViewForwardZ = forward.x, forward.y, forward.z
	gsViewRightX, gsViewRightY, gsViewRightZ = right.x, right.y, right.z
	gsViewUpX, gsViewUpY, gsViewUpZ = up.x, up.y, up.z

	local tanY = mathTan(mathRad(fov * 0.5))

	gsFrustumTanY = tanY
	gsFrustumTanX = tanY * (ScrW() / ScrH())
end)

hookAdd("Think", "GStorms_Particle_Handler_GlobalPool", function()
	local curTime = CurTime()

	if curTime + 3 < nextRun then nextRun = 0 end
	if curTime < nextRun then return end

	nextRun = curTime + nextThink
	
	local viewPos = gsViewPos or EyePos()
	gsViewPosX, gsViewPosY, gsViewPosZ = viewPos.x, viewPos.y, viewPos.z

	local centerPos = (gs_groundPositionFromServerLoad and gs_groundPositionFromServerLoad.client) or viewPos
	local debrisEnabled = GetConVar("gstorms_tornado_debris_cloud"):GetBool()
	local cloudsEnabled = GetConVar("gstorms_env_clouds"):GetBool()
	gsParticleAmountMult = GetConVar("gstorms_perf_particle_amount"):GetFloat()
	
	local eyeX, eyeY = viewPos.x, viewPos.y

	UpdateSun(curTime)

	drawCountB = 0

	local env = gs_env and gs_env.client
	if !IsValid(env) or !env.Networked then return end

	local packName = GSGetActivePackName()

	if packName ~= cloudPack or !cloudsEnabled then ClearClouds() end

	cloudPack = packName

	local entityList = gs_weatherEntityList and gs_weatherEntityList.client

	if entityList and !GSIsPaused() then
		local profStorm = GSGetPackProfile(packName, "stormcloud", 1)
		local colStorm = PrepareColors(profStorm)
		SpawnRainAndDownfallSheets(entityList, profStorm, centerPos, viewPos, colStorm, false, true)

		local profSheet = GSGetPackProfile(packName, "rainsheet", 1)
		local colSheet = PrepareColors(profSheet)
		SpawnRainAndDownfallSheets(entityList, profSheet, centerPos, viewPos, colSheet, false, false, true)

		local profRain = GSGetPackProfile(packName, (env.Temperature > 0) and "rain" or "snow", 1)
		local colRain = PrepareColors(profRain)
		SpawnRainAndDownfallSheets(entityList, profRain, centerPos, viewPos, colRain, true, false, true)

		for i = 1, #entityList do
			local ent = entityList[i]

			if !IsValid(ent) then continue end
			if !ent.Networked then continue end

			local lastThink = ent.GSParticleLastThink

			ent.GSParticleLastThink = curTime
			ent.GSParticleDt = lastThink and (curTime - lastThink) or nextThink

			local entPos = ent.Position
			local entPosX, entPosY, entPosZ = entPos.x, entPos.y, entPos.z
			
			ent.GSParticleCamAng = mathAtan2(eyeY - entPosY, eyeX - entPosX)

			if ent.Flow then
				prof = GSGetEntProfile(ent, (ent.FlowTemperature or 0) > 0 and "pyroclasticflow" or "sandstorm")
				col = PrepareColors(prof)
				SpawnFlow(ent, prof, col)
				continue
			end

			local rmw = ent.VortexRMWSize
			local startH = ent.FunnelStartHeight
			local maxH = ent.FunnelMaxHeight
			local wt = ent.FunnelWidthTable
			local bw, mw, mwh, tw, wexp = wt.baseWidth, wt.midWidth, wt.midWidthHeight, wt.topWidth, wt.widthExponent
			local ring = ent.FunnelCondensationRing
			local ringH, ringR = ring.activationHeight, ring.radiusMultiplier
			local anti = ent.Anticyclonic
			local vortexSize = ent.VortexSize
			local spout = ent.Spout
			local dustDevil = ent.DustDevil
			local hurricane = ent.Hurricane
			local tornado = ent.Tornado
			local tornadoOrSpout = tornado or spout
			local ws = ent.VortexWindspeed
			local wsPositive = ws > 0
			local subvortices = ent.Subvortices
			local subvCount = subvortices and #subvortices or 0
			local vpnAmp, vpnFreq, vpnDetail, vpnPeak = ent.VortexPositionNoiseAmplitude, ent.VortexPositionNoiseFrequency, ent.VortexPositionNoiseDetail, ent.VortexPositionNoisePeak

			if subvCount > 0 then
				local subvProf = GSGetEntProfile(ent, "subvortexcondensation")
				local subvCol = PrepareColors(subvProf)
				local subvMinWs = subvProf.afwWsMin
			
				for j = 1, subvCount do
					local subv = subvortices[j]
			
					if !IsValid(subv) then continue end
					if !subv.Networked then subv.GSParticleCamAng = nil continue end
			
					local subvPos = subv.Position
					if !subvPos then subv.GSParticleCamAng = nil continue end
			
					subv.GSParticleCamAng = mathAtan2(eyeY - subvPos.y, eyeX - subvPos.x)
			
					local sWs = subv.VortexWindspeed
					if sWs <= subvMinWs then continue end
					
					local swt = subv.FunnelWidthTable
					SpawnCondOrbit(ent, subv, subvProf, 90, subv.FunnelStartHeight, subv.FunnelMaxHeight, subvCol, sWs, subv.VortexRMWSize, swt.baseWidth, swt.midWidth, swt.midWidthHeight, swt.topWidth, swt.widthExponent, subv.VortexPositionNoiseAmplitude, subv.VortexPositionNoiseFrequency, anti, -1e30, 1, subv.VortexPositionNoiseDetail, subv.VortexPositionNoisePeak)
				end
			end

			if tornadoOrSpout and startH != maxH then
				if ws >= ent.CondensationThreshold or ent.IgnoreCondensationThreshold then
					local prof = GSGetEntProfile(ent, "condensation")
					local col = PrepareColors(prof)
					SpawnCondOrbit(ent, ent, prof, 90, startH, maxH, col, ws, rmw, bw, mw, mwh, tw, wexp, vpnAmp, vpnFreq, anti, ringH, ringR, vpnDetail, vpnPeak, true)
				end 
			
				if spout and GSGetGroundMaterial(entPos) ~= 2 then
					local prof = GSGetEntProfile(ent, "landspoutlayer")
					local col = PrepareColors(prof)
					SpawnCondOrbit(ent, ent, prof, 90, 0, mathMax(startH - 250, 1000), col, ws, rmw, tw, mw, mwh, bw, wexp, vpnAmp, vpnFreq, anti, ringH, ringR, vpnDetail, vpnPeak)
				end
			end

			if tornadoOrSpout and wsPositive then
				local prof = GSGetEntProfile(ent, "mesocyclone")
				local col = PrepareColors(prof)
				SpawnMesoAndHurricane(ent, prof, col, false, ws, rmw, mathMin(ent.MesocycloneSize, 30000), maxH, spout)
			end

			if hurricane and wsPositive then
				local prof = GSGetEntProfile(ent, "hurricane")
				local col = PrepareColors(prof)
				SpawnMesoAndHurricane(ent, prof, col, true, ws, rmw, mathMin(vortexSize, 30000), maxH, spout)
			end

			if dustDevil then
				local prof = GSGetEntProfile(ent, "dustdevil")
				local col = PrepareColors(prof)
				SpawnCondOrbit(ent, ent, prof, 90, startH, maxH, col, ws, rmw, bw, mw, mwh, tw, wexp, vpnAmp, vpnFreq, anti, ringH, ringR, vpnDetail, vpnPeak)
			end

			if debrisEnabled and !hurricane then
				local prof = GSGetEntProfile(ent, "debris")

				if (dustDevil or ws > prof.afwWsMin) then
					local col = PrepareColors(prof)
					SpawnDeb(ent, prof, col, ws, rmw, entPosX, entPosY, entPosZ, startH, dustDevil)
				end
			end

			if debrisEnabled and tornado then
				local prof = GSGetEntProfile(ent, "curtains")
				if ws > prof.afwWsMin then
					local col = PrepareColors(prof)
					SpawnCurt(ent, prof, col, ws, rmw, entPosX, entPosY, entPosZ, maxH, vortexSize)
				end
			end

			if !dustDevil and ent.StormPrecipitationMultiplier > 10 then cloudsEnabled = false end

		end
	end

	if cloudsEnabled then 
		local prof = GSGetPackProfile(packName, "cloud", 1)
		local col = PrepareColors(prof)
		UpdateClouds(prof, col, curTime, centerPos, env) 
	end
	
	UpdateCloudParticles()

	for i = activeEmitterCount, 1, -1 do
		local emit = activeEmitters[i]
		local eReflect, eOrbit, eSubv, ePhysics, eFlow, ePrecip = emit.reflect, emit.orbit, emit.subv, emit.physics, emit.flow, emit.precip
		local nReflect, nOrbit, nSubv, nPhysics, nFlow, nPrecip = eReflect.n, eOrbit.n, eSubv.n, ePhysics.n, eFlow.n, ePrecip.n
		local ent = emit.owner
		
		if !IsValid(ent) or !ent.Networked then
			local deadStart = emit.deadStart
		
			if !deadStart then
				deadStart = curTime
				emit.deadStart = deadStart
				emit.deadLastThink = curTime
				ClearBucket(ePrecip)
			end
		
			emit.deadLastThink = curTime
		
			local deadFrac = (curTime - deadStart) * deathFadeInv
		
			if deadFrac >= 1 then
				if IsValid(ent) then
					ClearEmitter(ent, eReflect, ePrecip, eOrbit, eSubv, ePhysics, eFlow)
				else
					ClearBucket(eReflect)
					ClearBucket(ePrecip)
					ClearBucket(eOrbit)
					ClearBucket(eSubv)
					ClearBucket(ePhysics)
					ClearBucket(eFlow)
				end
		
				RemoveActiveEmitter(i)
				continue
			end
		
			local fadeMul = 1 - deadFrac
		
			if nReflect > 0 then UpdateDeadBucket(eReflect, fadeMul) end
			if nOrbit > 0 then UpdateDeadBucket(eOrbit, fadeMul) end
			if nSubv > 0 then UpdateDeadBucket(eSubv, fadeMul) end
			if nPhysics > 0 then UpdateDeadBucket(ePhysics, fadeMul) end
			if nFlow > 0 then UpdateDeadFlowBucket(eFlow, fadeMul, curTime - emit.deadLastThink) end
		
			if EmitterEmpty(nReflect, nPrecip, nOrbit, nSubv, nPhysics, nFlow) then RemoveActiveEmitter(i) end
			continue
		end
		
		emit.deadStart = nil
	
		local dt = ent.GSParticleDt
		local camAng = ent.GSParticleCamAng
		
		if ent.Flow then
			UpdateFlowBucket(eFlow, dt, camAng, 1)
		else
			local entPos = ent.Position
			local ws = ent.VortexWindspeed
			local entPosX, entPosY, entPosZ = entPos.x, entPos.y, entPos.z
			local anticyclonic = ent.Anticyclonic
			local nfreq = ent.VortexPositionNoiseFrequency
			local namp = ent.VortexPositionNoiseAmplitude
			local nspeed = ent.VortexPositionNoiseSpeed
			local nseed = ent.VortexPositionNoiseSeed
			local nphase = ent.VortexPositionNoisePhase
			local nDetail = ent.VortexPositionNoiseDetail
			local nPeak = ent.VortexPositionNoisePeak
			local vortexModelParameters = ent.VortexModelParameters
			local move = ent.MovementVector
			local moveX, moveY, moveZ = move.x, move.y, move.z
			local angDir = anticyclonic and -1 or 1
			local maxH = ent.FunnelMaxHeight
	
			if nReflect > 0 then UpdateReflectBucket(eReflect, dt, entPosX, entPosY, entPosZ, 0, 0, 1, false) end
			if nOrbit > 0 then UpdateOrbitBucket(eOrbit, dt, entPosX, entPosY, entPosZ, ws, anticyclonic, vortexModelParameters.alpha, nfreq, namp, nspeed, nseed, nphase, camAng, curTime, 1, angDir, nDetail, nPeak, maxH) end
			if nSubv > 0 then UpdateSubvBucket(eSubv, dt, anticyclonic, nfreq, namp, nspeed, nseed, nphase, curTime, 1, angDir, nDetail, nPeak, maxH) end
			if nPhysics > 0 then UpdatePhysicsBucket(ePhysics, dt, entPosX, entPosY, entPosZ, anticyclonic, nfreq, namp, nspeed, nseed, nphase, moveX, moveY, moveZ, ent.VortexSize, ent.VortexRMWSize, ws, ent.ForwardsSpeedMPH, vortexModelParameters, ent.FunnelWidthTable, curTime, 1, nDetail, nPeak, maxH) end
		end
		
		if EmitterEmpty(nReflect, nPrecip, nOrbit, nSubv, nPhysics, nFlow) then RemoveActiveEmitter(i) end
	end

	if drawCountB < drawUsedB then drawUsedB = TrimDrawTail(drawB, drawCountB, drawUsedB) end
	if drawCountB > 1 then tableSort(drawB, SortDraw) end

	drawA, drawB = drawB, drawA
	drawCountA, drawCountB = drawCountB, 0
	drawUsedA, drawUsedB = drawUsedB, drawUsedA
end)

hookAdd("Think", "GStorms_Particle_Handler_Precip", function()
	local curTime = CurTime()

	if curTime + 3 < precipNextRun then precipNextRun = 0 end
	if curTime < precipNextRun then return end

	precipNextRun = curTime + engine.TickInterval()

	local env = gs_env and gs_env.client
	local entityList = gs_weatherEntityList.client
	
	if !IsValid(env) or !env.Networked or !entityList then return end
	
	precipDrawCountB = 0

	local viewPos = gsViewPos or EyePos()
	gsViewPosX, gsViewPosY, gsViewPosZ = viewPos.x, viewPos.y, viewPos.z

	local _, localDir = GSGetGlobalWindspeedAndVectors(viewPos, entityList, GetConVar("gstorms_tornado_inflow_jet"):GetBool(), env, curTime, outVec)
	local locDirX, locDirY = localDir.x, localDir.y

	for i = activeEmitterCount, 1, -1 do
		local emit = activeEmitters[i]
		local ent = emit and emit.owner

		if !emit or !IsValid(ent) or !ent.Networked or ent.Flow then continue end
		if emit.precip.n <= 0 then continue end

		local lastThink = ent.GSPrecipLastThink or curTime
		local dt = curTime - lastThink

		ent.GSPrecipLastThink = curTime

		UpdateReflectBucket(emit.precip, dt, 0, 0, 0, locDirX, locDirY, 1, true)
	end

	if precipDrawCountB < precipDrawUsedB then precipDrawUsedB = TrimDrawTail(precipDrawB, precipDrawCountB, precipDrawUsedB) end
	if precipDrawCountB > 1 then tableSort(precipDrawB, SortDraw) end

	precipDrawA, precipDrawB = precipDrawB, precipDrawA
	precipDrawCountA, precipDrawCountB = precipDrawCountB, 0
	precipDrawUsedA, precipDrawUsedB = precipDrawUsedB, precipDrawUsedA
	
	MergeSortedDrawLists()

end)