ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.Spawnable = false

-- [GENERAL OPTIONS]

ENT.Tornado = false
ENT.Spout = false
ENT.DustDevil = false
ENT.Hurricane = false
ENT.Derecho = false
ENT.Thunderstorm = false
ENT.Rainstorm = false
ENT.Dynamic = false
ENT.Anticyclonic = false

-- [VORTEX HANDLING]

ENT.VortexWindspeed = 201
ENT.VortexRMWSize = 500
ENT.VortexModelParameters = {alpha = 0.5, zScale = 4500, twoCelled = 1, falloffExponent = 1} -- alpha [0, 1], zScale [vortex height], swirlRatio [true / false], falloffExponent [lower < windfield, higher > windfield]

ENT.SubvorticesEnabled = true
ENT.SubvortexSpawnChance = 75
ENT.SubvortexStrengthMult = 1.5
ENT.SubvortexMaxCount = 5

-- [VORTEX VISUAL HANDLING]

ENT.VortexPositionNoiseFrequency = 0.0005
ENT.VortexPositionNoiseAmplitude = 4
ENT.VortexPositionNoiseSpeed = 500
ENT.VortexPositionNoiseDetail = 1
ENT.VortexPositionNoisePeak = 1
ENT.VortexPositionNoiseSeed = 0
ENT.VortexPositionNoisePhase = 0

ENT.FunnelStartHeight = 0
ENT.FunnelMaxHeight = 6500
ENT.FunnelWidthTable = {baseWidth = 1, midWidth = 2, midWidthHeight = 0.5, topWidth = 4, widthExponent = 1}
ENT.FunnelCondensationRing = {activationHeight = 0, radiusMultiplier = 0}

-- [STORM HANDLING]

ENT.EnableRain = false
ENT.EnableLightning = false

ENT.LightningChance = 25

ENT.StormWindspeed = 20
ENT.StormPrecipitationMultiplier = 1
ENT.StormRFB = false -- Rain free base
ENT.SupercellParameters = {debrisMax = 1, hookMax = 1, debrisBSize = 1, hookLenSize = 1, hookWidSize = 1, hookAngSize = 1}

--#######################################################################################################################################################################

ENT.Subvortices = {}
ENT.CondensationThreshold = 0

--#######################################################################################################################################################################

include("gstorms_funcs/gstorms_shared_tools.lua")
include("gstorms_funcs/gstorms_dynamic_entity_handler.lua")

local nilVector = Vector(0, 0, 0)
local gsDefaultPack = "GStorms: Default Resource Pack"
local gsParticleRerollMax = 8192

local mathRandom = math.random
local mathRound = math.Round
local mathMax = math.max
local mathMin = math.min
local mathPow = math.pow
local mathClamp = math.Clamp
local mathApproach = math.Approach
local mathFloor = math.floor
local bitBand = bit.band
local bitBor = bit.bor
local bitLshift = bit.lshift
local utilTraceLine = util.TraceLine
local utilIsInWorld = util.IsInWorld
local utilDecalEx = util.DecalEx
local entsCreate = ents.Create
local entsFindByClass = ents.FindByClass
local Material = Material
local timerSimple = timer.Simple
local gameGetWorld = game.GetWorld
local thinkStep = engine.TickInterval() * 2
local stringFormat = string.format

local adjustHeightTraceDownEnd = Vector(0, 0, 30000)
local adjustHeightTraceDownStart = Vector(0, 0, 6000)
local moveTypeVPhysics = MOVETYPE_VPHYSICS
local heightLerpSmoothingFac = 0.25 -- lower is smoother for lerping
local heightLerpRate = 70 -- Higher is faster lerping

local worldMins, worldMaxs, worldCenter, worldRadius, invWorldRadius
local edgeBiasRange = 7500
local invEdgeBiasRange = 1 / edgeBiasRange
local edgeBiasStrength = 0.00075
local centerBiasStrength = 0.00015
local pathBoundsInset = 256

local out = Vector(0, 0, 0)
local vecUp = Vector(0, 0, 1)

local matScour = Material("other/ground_scouring/ground_scouring")
local scourThreshold = 150
local scourStart = Vector(0, 0, 250)
local scourEnd = Vector(0, 0, 500)
local scourTraceData = {mask = MASK_SOLID_BRUSHONLY}
local scourTraceStart = Vector()
local scourTraceEnd = Vector()

local gsCachedSubvortices = {}
local gsCachedSubvorticesTime = 0


function ENT:GSInitParticleSelection(packName, reroll)
	if !packName or packName == "" then
		local c = GetConVar("gstorms_particle_texture")
		packName = (c and c:GetString()) or gsDefaultPack
	end

	self.ParticlePackName = packName

	local selected = self.ParticleTypesSelected
	if !selected then selected = {} self.ParticleTypesSelected = selected end

	if !reroll or !selected.condensation then
		selected.mesocyclone = mathRandom(gsParticleRerollMax)
		selected.condensation = mathRandom(gsParticleRerollMax)
		selected.subvortexcondensation = mathRandom(gsParticleRerollMax)
		selected.dustdevil = mathRandom(gsParticleRerollMax)
		selected.landspoutlayer = mathRandom(gsParticleRerollMax)
		selected.debris = mathRandom(gsParticleRerollMax)
		selected.curtains = mathRandom(gsParticleRerollMax)
		selected.hurricane = mathRandom(gsParticleRerollMax)
	end

	self.ParticleIndexMesocyclone = selected.mesocyclone or 1
	self.ParticleIndexCondensation = selected.condensation or 1
	self.ParticleIndexSubvortexCondensation = selected.subvortexcondensation or 1
	self.ParticleIndexDustDevil = selected.dustdevil or 1
	self.ParticleIndexLandspoutLayer = selected.landspoutlayer or 1
	self.ParticleIndexDebris = selected.debris or 1
	self.ParticleIndexCurtains = selected.curtains or 1
	self.ParticleIndexHurricane = selected.hurricane or 1

	if self.SetParticleProfile then self:SetParticleProfile(packName) end

	if self.SetParticleIndexMesocyclone then
		self:SetParticleIndexMesocyclone(self.ParticleIndexMesocyclone)
		self:SetParticleIndexCondensation(self.ParticleIndexCondensation)
		self:SetParticleIndexSubvortexCondensation(self.ParticleIndexSubvortexCondensation)
		self:SetParticleIndexDustDevil(self.ParticleIndexDustDevil)
		self:SetParticleIndexLandspoutLayer(self.ParticleIndexLandspoutLayer)
		self:SetParticleIndexDebris(self.ParticleIndexDebris)
		self:SetParticleIndexCurtains(self.ParticleIndexCurtains)
		self:SetParticleIndexHurricane(self.ParticleIndexHurricane)
	end
end

local function GSResolveSharedProfileValue(ent, key, mn, mx, fallback)
	if mn == nil and mx == nil then return fallback end

	if mn == nil then mn = mx end
	if mx == nil then mx = mn end
	if mn == nil then return fallback end
	if mn == mx then return mn end

	return util.SharedRandom("gs_cond_" .. ent:EntIndex() .. "_" .. key, mn, mx)
end

function ENT:SetupEntity()

    self.EntityStartTime = CurTime()
    self.Position = self:GetPos()
    self.IgnoreCondensationThreshold = false

    if SERVER then
		
        self:GSInitParticleSelection(nil, true)

        local pos = GSGetGroundPosition(self:GetPos())
		local owner = self:GetOwner()

		self.VortexPositionNoiseSeed = mathRandom(100000)
		self.VortexPositionNoisePhase = CurTime() * self.VortexPositionNoiseSpeed * (self.Anticyclonic and 0.0005 or -0.0005)
		self.VortexPositionNoiseLastTime = CurTime()

        self.Position = pos
        
		if self.PathingData and self.PathingData.edgePoints and self.PathingData.edgePoints[2] then
			local p = self.PathingData.edgePoints[2]
			self.MovementVector = Vector(p.x - pos.x, p.y - pos.y, 0):GetNormalized()
		elseif !GetConVar("gstorms_sim_aim_at_players"):GetBool() then
			self.MovementVector = GSGetNormVecNoZ(1)
		else
			if !IsValid(owner) then
				self.MovementVector = GSGetNormVecNoZ(1)
			else
				local p = owner:GetPos()
				self.MovementVector = Vector(p.x - pos.x, p.y - pos.y, 0):GetNormalized()
			end
		end

        self:SetPos(pos)

		if IsValid(owner) then
			if !self.Thunderstorm and !self.Rainstorm and !self.Derecho and !self.Autospawn then
				GSTipToClient(owner, self.PrintName.." | "..stringFormat("%s MPH | Size: %s | Eye Size: %s", !self.Dynamic and mathRound(self.VortexWindspeed, 0) or "Unknown", !self.Dynamic and mathRound(self.VortexSize, 0) or "Unknown", !self.Dynamic and mathRound(self.VortexRMWSize, 0) or "Unknown"))
			elseif !self.Autospawn then
				GSTipToClient(owner, self.PrintName.." | "..stringFormat("%s MPH ", !self.Dynamic and mathRound(self.StormWindspeed, 0) or "Unknown"))
			end
		end

	elseif CLIENT then
		local prof = GSGetEntProfile(self, "condensation")
	
		if prof then
			self.ParticleCondWindspeed = GSResolveSharedProfileValue(self, "ws", prof.condWsMin, prof.condWsMax, self.ParticleCondWindspeed)
			self.ParticleCondRange = GSResolveSharedProfileValue(self, "range", prof.condRangeMin, prof.condRangeMax, self.ParticleCondRange)
			self.ParticleCondHeight = GSResolveSharedProfileValue(self, "height", prof.condHeightMin, prof.condHeightMax, self.ParticleCondHeight)

			if prof.condAlphaMin ~= nil then self.ParticleCondAlphaMin = prof.condAlphaMin end
			if prof.condExponent ~= nil then self.ParticleCondExponent = prof.condExponent end
		end
	end

    self.EntSetup = true
    self.TouchdownConvar = GetConVar("gstorms_sim_strengthening"):GetBool()

end

local function GSAdjustHeight(newPosition)

	local serverZ = gs_heightPositionFromServerLoad and gs_heightPositionFromServerLoad.server and gs_heightPositionFromServerLoad.server.z
	local startTracePos = serverZ and Vector(newPosition.x, newPosition.y, serverZ - 10) or (newPosition + adjustHeightTraceDownStart)
	local traceDown = utilTraceLine({start = startTracePos, endpos = newPosition - adjustHeightTraceDownEnd, mask = MASK_SOLID_BRUSHONLY + MASK_WATER})
	local inWorld = utilIsInWorld(newPosition)

	if !traceDown.Hit or !utilIsInWorld(traceDown.HitPos) then return false, traceDown.HitPos, inWorld end

	local ent = traceDown.Entity
	if IsValid(ent) and ent:GetMoveType() ~= moveTypeVPhysics then return false, traceDown.HitPos, inWorld end

	return true, traceDown.HitPos, inWorld

end

function ENT:RunHeightLerp(hitPosZ)

	local curTime = self.CurTime
	local dt = curTime - (self.HeightLerpLastTime or curTime); self.HeightLerpLastTime = curTime

	if dt <= 0 then return self.HeightLerpZ or self.Position.z end

	local zVal = self.HeightLerpTargetZ or hitPosZ
	local t = zVal + (hitPosZ - zVal) * mathClamp(dt * heightLerpSmoothingFac, 0, 1)
	
	self.HeightLerpTargetZ = t
	self.HeightLerpZ = mathApproach(self.HeightLerpZ or self.Position.z, t, self.ForwardsSpeedMPH * heightLerpRate * dt)

	return self.HeightLerpZ

end


local function GSInitWorldBounds()
	if worldMins then return true end

	local w = gameGetWorld()
    if !w then return end

	worldMins, worldMaxs = w:GetModelBounds()
	worldCenter = (worldMins + worldMaxs) * 0.5
	worldCenter.z = 0

	local worldSize = worldMaxs - worldMins

	worldRadius = mathMax(worldSize.x, worldSize.y) * 0.5
	invWorldRadius = worldRadius > 0 and (1 / worldRadius) or 0

	return true
end

local function GSClampPathXYToWorld(x, y)
	if !GSInitWorldBounds() then return x, y end
	return mathClamp(x, worldMins.x + pathBoundsInset, worldMaxs.x - pathBoundsInset), mathClamp(y, worldMins.y + pathBoundsInset, worldMaxs.y - pathBoundsInset)
end

local function GSComputeEdgeAndCenterBias(pos)
	if !GSInitWorldBounds() then return end

	local x, y = pos.x, pos.y
	local nx, ny = (mathMax(edgeBiasRange - (x - worldMins.x), 0) * invEdgeBiasRange)^2, (mathMax(edgeBiasRange - (y - worldMins.y), 0) * invEdgeBiasRange)^2
	local px, py = (mathMax(edgeBiasRange - (worldMaxs.x - x), 0) * invEdgeBiasRange)^2, (mathMax(edgeBiasRange - (worldMaxs.y - y), 0) * invEdgeBiasRange)^2
	local toCenter = Vector(worldCenter.x - x, worldCenter.y - y, 0)
	local centerInfluence = mathClamp(toCenter:Length2D() * invWorldRadius, 0, 1)

	return Vector(nx - px, ny - py, 0), (centerInfluence > 0) and (toCenter:GetNormalized() * centerInfluence) or nilVector
end

local function GSRefreshMovementSpeed(self) 
	self.ForwardsSpeedMPH = self.StormWindspeed * GetConVar("gstorms_sim_speed"):GetFloat() 
	return self.ForwardsSpeedMPH
end

local function GSFinishMovement(ent, newPosition, fallbackDir, clearPathingOnFail)
	local adjustHeight, hitPos, isInWorld = GSAdjustHeight(newPosition)

	if !isInWorld and !adjustHeight then
		if clearPathingOnFail then ent.PathingData = nil end

		ent.MovementVector = fallbackDir or GSGetNormVecNoZ(1)
		ent.ChangedDirection = true
		return false
	end

	if adjustHeight then newPosition.z = ent:RunHeightLerp(hitPos.z) end

	ent.Position = newPosition
	ent:SetPos(newPosition)

	return true
end

function ENT:MovementOnPath(pathing, pos, lastDir)
	if !pathing or !pathing.points or !pathing.links then return false end

	local posX, posY = GSClampPathXYToWorld(pos.x, pos.y)
	if posX ~= pos.x or posY ~= pos.y then pos = Vector(posX, posY, pos.z) end

	local remaining = GSGetSpeedVector(Vector(1, 0, 0), GSRefreshMovementSpeed(self), thinkStep):Length2D()
	local edgePoints = pathing.edgePoints
	local edgePointIndex = mathClamp(pathing.edgePointIndex or 1, 1, #(edgePoints or {}))
	local guard = 0

	while remaining > 0 and guard < 8 do
		guard = guard + 1

		if !edgePoints or #edgePoints == 0 or !pathing.nextNode then self.PathingData = nil break end

		local target = edgePoints[edgePointIndex]
		if !target then self.PathingData = nil break end

		local targetX, targetY = GSClampPathXYToWorld(target.x, target.y)
		local dir = Vector(targetX - pos.x, targetY - pos.y, 0)
		local dist = dir:Length2D()

		if dist > 0.001 then
			dir:Div(dist)
			lastDir = dir
			
			self.MovementVector = dir

			local moveDist = mathMin(remaining, dist)
			
			pos = Vector(pos.x + dir.x * moveDist, pos.y + dir.y * moveDist, pos.z)
			pos.x, pos.y = GSClampPathXYToWorld(pos.x, pos.y)
			remaining = remaining - moveDist

			if moveDist < dist then break end
		end

		edgePointIndex = edgePointIndex + 1

		if edgePointIndex > #edgePoints then
			local prevNode = pathing.curNode
			local curNode = pathing.nextNode
			local nextNode = GSPathChooseNextNode(pathing, prevNode, curNode, lastDir, pathing.direction)
		
			if !nextNode then self.PathingData = nil break end
		
			pathing.prevNode = prevNode
			pathing.curNode = curNode
			pathing.nextNode = nextNode
			pathing.nodeIndex = curNode
			pathing.edgePoints = GSBuildPathEdgeCurve(pathing.points, curNode, nextNode, prevNode, GSGetCurveNeighbor(pathing, nextNode, curNode, curNode, true), pathing.curveSteps or 8)

			edgePoints = pathing.edgePoints
			edgePointIndex = mathMin(2, #edgePoints)
		end
	end

	if !GSFinishMovement(self, Vector(pos.x, pos.y, self.Position.z), lastDir, true) then return true end

	if self.PathingData then
		pathing.edgePointIndex = edgePointIndex
	else
		self.MovementVector = lastDir or self.MovementVector
	end

	return true
end

function ENT:Movement()

	if self:MovementOnPath(self.PathingData, self.Position, self.MovementVector) then return end

	local pos = self:GetPos()
	local movementVec = self.MovementVector
	local _, sinX, sinY, sinZ = GSNoise(pos.x, pos.y, movementVec.x, movementVec.y, movementVec.z, 0, 0, 7500, 30000, -45, 45, 1, self.CurTime)
	local forwardsSpeed = GSRefreshMovementSpeed(self)

	self.MovementVector = (self.MovementVector + (Vector(sinX, sinY, sinZ) * (0.000375 * forwardsSpeed))):GetNormalized()

	local edgeVec, centerVec = GSComputeEdgeAndCenterBias(self.Position)

	if edgeVec and !self.ChangedDirection then self.MovementVector = (self.MovementVector + (edgeVec * (edgeBiasStrength * forwardsSpeed)) + (centerVec * (centerBiasStrength * forwardsSpeed))):GetNormalized() end
	if !GSFinishMovement(self, self.Position + GSGetSpeedVector(self.MovementVector, forwardsSpeed, thinkStep), nil, false) then return end

end

local function BuildWindfieldQuads(self, localPlayerPos, resolution, tornadoPosition, vortexSize, funnelMaxHeight, isAnticyclonic, gridSize, vPosFreq, vPosAmp, vPosSpeed, vPosSeed, vPosPhase, vPosDetail, vPosPeak)

    local positions, squareSize = GSReturnListOfGridPositions(resolution, tornadoPosition, (gridSize + GSReturnPositionNoiseMaxOffset(funnelMaxHeight, vPosAmp, vPosFreq, vPosDetail, vPosPeak)) * 1.5, GetConVar("gstorms_av_windfield_sample_height"):GetInt())
    local useVelocity = GetConVar("gstorms_av_windfield_use_velocity"):GetBool()
    local entityList = gs_weatherEntityList.client
    local stormWindsConvar = GetConVar("gstorms_av_windfield_storm_winds"):GetBool()
    local inflowJetConvar = GetConVar("gstorms_tornado_inflow_jet"):GetBool()
    local envEnt = gs_env.client
	local posX, posY, posZ = tornadoPosition.x, tornadoPosition.y, tornadoPosition.z
	local curTime = self.CurTime
    local quads = {}

    if !envEnt then return quads end

    for _, pos in ipairs(positions) do
		local tPosX, tPosY, tPosZ = GSGetModifiedTornadoPosFromHeightAndNoise(posX, posY, posZ, pos.z - posZ, vPosFreq, vPosAmp, vPosSpeed, isAnticyclonic, vPosSeed, vPosPhase, curTime, vPosDetail, vPosPeak, funnelMaxHeight)
        if pos:Distance2D(Vector(tPosX, tPosY, tPosZ)) > vortexSize then continue end

		local wsRaw, velDir, _, _, tornadoWS = GSGetGlobalWindspeedAndVectors(pos, entityList, inflowJetConvar, envEnt, curTime, out)
		local ws = stormWindsConvar and wsRaw or tornadoWS
        if ws < 1 then continue end

        local col = GSReturnColorForWindspeed(ws, useVelocity, localPlayerPos, pos, false, velDir)
        if !col then continue end

        quads[#quads + 1] = {localPos = pos - tornadoPosition, col = col, size = squareSize}
    end

    return quads
end

function ENT:RenderWindfield(tornadoPos, localPlayer, localPlayerPos, vortexSize, funnelMaxHeight, isAnticyclonic, updSpeedSeconds, resolution, vPosFreq, vPosAmp, vPosSpeed, vPosSeed, vPosPhase, vPosDetail, vPosPeak)
    if !GetConVar("gstorms_av_windfield_rendering"):GetBool() or !localPlayer:IsAdmin() or self.Rainstorm or self.Thunderstorm or self.Derecho then
        self.RenderingWindfield = false
        self.WindfieldQuads = nil
        return
    end

    self.RenderingWindfield = true

    if !self.LastWindfieldUpdateTime or (self.CurTime - self.LastWindfieldUpdateTime) >= updSpeedSeconds then
        self.WindfieldQuads = BuildWindfieldQuads(self, localPlayerPos, resolution, tornadoPos, vortexSize, funnelMaxHeight, isAnticyclonic, vortexSize * 1.35, vPosFreq, vPosAmp, vPosSpeed, vPosSeed, vPosPhase, vPosDetail, vPosPeak)
        self.LastWindfieldUpdateTime = self.CurTime
    end
end

hook.Add("PreDrawEffects", "GS_DrawWindfieldQuads", function(depth, skybox)
    if skybox or !GetConVar("gstorms_av_windfield_rendering"):GetBool() then return end

    local localPlayer = LocalPlayer()
    if !IsValid(localPlayer) or !localPlayer:IsAdmin() then return end

    local entityList = gs_weatherEntityList and gs_weatherEntityList.client
    if !entityList then return end

    render.SetColorMaterial()

    for i = 1, #entityList do
        local ent = entityList[i]
        if !IsValid(ent) or !ent.RenderingWindfield or !ent.WindfieldQuads then continue end

        local quads = ent.WindfieldQuads
        local tornadoPos = ent.Position or ent:GetPos()

        for j = 1, #quads do
            local quad = quads[j]
            local size = quad.size
            render.DrawQuadEasy(tornadoPos + quad.localPos, vecUp, size, size, quad.col, 0)
        end
    end
end)

function ENT:SetDestructionParticlesTimer()

    if !self.IsDestroying or self.SetDestroyTimer then return end

    self.SetDestroyTimer = true

    timerSimple(mathRandom(12, 24), function()
        if !self:IsValid() then return end
        self.IsDestroying = false
        self.SetDestroyTimer = false
    end)

end

function ENT:SpawnWindVectorHandler(tornadoPos, vortexSize)
    
    local convar = GetConVar("gstorms_av_windfield_wind_vectors"):GetBool()

    if convar and !self.WindVectorEnt and !self.Hurricane and !self.Thunderstorm and !self.Rainstorm then

        self.WindVectorEnt = entsCreate("gstorms_windvector_handler")

        if !self.WindVectorEnt:IsValid() then return end

        self.WindVectorEnt:SetPos(tornadoPos)
        self.WindVectorEnt:SetParent(self)
        self.WindVectorEnt:Setup(vortexSize * 0.5, 256)
        self.WindVectorEnt:Spawn()

    elseif !convar and self.WindVectorEnt then
		
        if self.WindVectorEnt:IsValid() then 
            self.WindVectorEnt:Remove() 
            self.WindVectorEnt = nil
        end

    end

end

function ENT:SubvGroundScouring()

    if !GetConVar("gstorms_tornado_ground_scouring"):GetBool() or GSIsPaused() then return end

    scourTraceData.filter = LocalPlayer()

    for _, subv in ipairs(self.Subvortices) do

        if !subv:IsValid() or !subv.Networked then continue end

		local vWS = subv.VortexWindspeed
        if vWS < scourThreshold then continue end

        local pos = subv.Position
		local posX, posY, posZ = pos.x, pos.y, pos.z

        scourTraceStart:SetUnpacked(posX + scourStart.x, posY + scourStart.y, posZ + scourStart.z)
        scourTraceEnd:SetUnpacked(posX - scourEnd.x, posY - scourEnd.y, posZ - scourEnd.z)
        scourTraceData.start = scourTraceStart
        scourTraceData.endpos = scourTraceEnd

        local traceScourCheck = utilTraceLine(scourTraceData)
        if !traceScourCheck.Hit or !traceScourCheck.Entity:IsWorld() then continue end

        local scourSize = mathMin((1 + (subv.VortexRMWSize * 0.00445)), 2.5)
		local hitPos = traceScourCheck.HitPos

        utilDecalEx(matScour, traceScourCheck.Entity, hitPos, (traceScourCheck.StartPos - hitPos), Color(0, 0, 0, mathMax((vWS - scourThreshold) * 0.22, 1)), scourSize, scourSize)

    end

end

function ENT:AddSubvortices()

    if !self.SubvorticesEnabled or !GetConVar("gstorms_tornado_subvortices"):GetBool() or mathRandom(self.SubvortexSpawnChance) ~= 1 then return end
    if #self.Subvortices >= self.SubvortexMaxCount then return end

    local ent = entsCreate("gstorms_subvortex")

    if !ent:IsValid() then return end

    ent.Parent = self
    ent:SetPos(self.Position)
    ent:Spawn()

end

local function GSGetCachedSubvortices(curTime)
	if curTime >= gsCachedSubvorticesTime then
		gsCachedSubvortices = entsFindByClass("gstorms_subvortex")
		gsCachedSubvorticesTime = curTime + thinkStep
	end

	return gsCachedSubvortices
end

function ENT:RefreshSubvortices()
	self.Subvortices = {}

	local subvortices = self.Subvortices
	local allSubvortices = GSGetCachedSubvortices(self.CurTime)
	local entIndex = self:EntIndex()
	local count = 0

	for i = 1, #allSubvortices do
		local subv = allSubvortices[i]
		if !IsValid(subv) or subv:GetSubvParentEntIndex() ~= entIndex then continue end

		count = count + 1
		subvortices[count] = subv
	end

	self.Subvortices = subvortices
end

function ENT:SetupDataTables()
    self:NetworkVar("Vector", 0, "MovementVector")
    self:NetworkVar("Float", 0, "VortexSize")
    self:NetworkVar("Float", 1, "VortexRMWSize")
    self:NetworkVar("Float", 2, "VortexWindspeed")
    self:NetworkVar("Float", 3, "ForwardsSpeedMPH")
    self:NetworkVar("Float", 4, "SubvortexStrengthMult")
    self:NetworkVar("Float", 5, "VortexPositionNoisePhase")
    self:NetworkVar("Float", 7, "VortexPositionNoiseFrequency")
    self:NetworkVar("Float", 8, "VortexPositionNoiseAmplitude")
    self:NetworkVar("Float", 9, "VortexPositionNoiseSpeed")
	self:NetworkVar("Float", 10, "VortexPositionNoiseDetail")
	self:NetworkVar("Float", 11, "VortexPositionNoisePeak")
    self:NetworkVar("Float", 12, "VortexPositionNoiseSeed")
    self:NetworkVar("Float", 13, "StormPrecipitationMultiplier")
    self:NetworkVar("Float", 14, "MesocycloneSize")
    self:NetworkVar("Float", 15, "VortexModelParametersAlpha")
    self:NetworkVar("Float", 16, "VortexModelParametersZScale")
    self:NetworkVar("Float", 17, "VortexModelParametersFalloffExponent")
    self:NetworkVar("Float", 18, "FunnelWidthTableBaseWidth")
    self:NetworkVar("Float", 19, "FunnelWidthTableMidWidth")
	self:NetworkVar("Float", 20, "FunnelWidthTableMidWidthHeight")
    self:NetworkVar("Float", 21, "FunnelWidthTableTopWidth")
    self:NetworkVar("Float", 22, "FunnelWidthTableWidthExponent")
    self:NetworkVar("Float", 23, "SupercellParametersDebrisMax")
    self:NetworkVar("Float", 24, "SupercellParametersHookMax")
    self:NetworkVar("Float", 25, "SupercellParametersDebrisBSize")
    self:NetworkVar("Float", 26, "SupercellParametersHookLenSize")
    self:NetworkVar("Float", 27, "SupercellParametersHookWidSize")
    self:NetworkVar("Float", 28, "SupercellParametersHookAngSize")
    self:NetworkVar("Float", 29, "CondensationThreshold")
	self:NetworkVar("Float", 30, "FCRRadiusMultiplier")
	self:NetworkVar("Float", 31, "VortexModelParametersTwoCelled")
    self:NetworkVar("Bool", 0, "Anticyclonic")
    self:NetworkVar("Bool", 1, "EnableRain")
    self:NetworkVar("Bool", 2, "IsDestroying")
    self:NetworkVar("Bool", 3, "Tornado")
    self:NetworkVar("Bool", 4, "Spout")
    self:NetworkVar("Bool", 5, "DustDevil")
    self:NetworkVar("Bool", 6, "Derecho")
    self:NetworkVar("Bool", 7, "Hurricane")
    self:NetworkVar("Bool", 8, "Dynamic")
    self:NetworkVar("Bool", 9, "Networked")
    self:NetworkVar("Bool", 10, "Thunderstorm")
    self:NetworkVar("Bool", 11, "Rainstorm")
    self:NetworkVar("Bool", 12, "StormRFB")
    self:NetworkVar("Bool", 13, "IgnoreCondensationThreshold")
    self:NetworkVar("String", 0, "ParticleProfile")
    self:NetworkVar("Int", 0, "ParticleIndexMesocyclone")
    self:NetworkVar("Int", 1, "ParticleIndexCondensation")
    self:NetworkVar("Int", 2, "ParticleIndexSubvortexCondensation")
    self:NetworkVar("Int", 3, "ParticleIndexDustDevil")
	self:NetworkVar("Int", 4, "ParticleIndexLandspoutLayer")
    self:NetworkVar("Int", 5, "ParticleIndexDebris")
	self:NetworkVar("Int", 6, "ParticleIndexCurtains")
	self:NetworkVar("Int", 7, "ParticleIndexHurricane")
	self:NetworkVar("Int", 8, "ParticleRevision")
	self:NetworkVar("Int", 9, "BoolRevision")
	self:NetworkVar("Int", 10, "FCRActivationHeight")
	self:NetworkVar("Int", 11, "FunnelMaxHeight")
	self:NetworkVar("Int", 12, "FunnelStartHeight")
end

local function GSGetPackFallback()
	local c = GetConVar("gstorms_particle_texture")
	return (c and c:GetString()) or gsDefaultPack
end

function ENT:NetworkEntityVariables()

	local vortexModelParams = self.VortexModelParameters
	local supercellParameters = self.SupercellParameters
	local funnelWidthTable = self.FunnelWidthTable
	local funnelCondensationRing = self.FunnelCondensationRing

	self:SetMovementVector(self.MovementVector)
	self:SetVortexSize(self.VortexSize)
	self:SetVortexRMWSize(self.VortexRMWSize)
	self:SetVortexWindspeed(self.VortexWindspeed)
	self:SetForwardsSpeedMPH(self.ForwardsSpeedMPH)
	self:SetSubvortexStrengthMult(self.SubvortexStrengthMult)
	self:SetFunnelMaxHeight(mathFloor(self.FunnelMaxHeight + 0.5))
	self:SetFunnelStartHeight(mathFloor(self.FunnelStartHeight + 0.5))

	self:SetStormPrecipitationMultiplier(self.StormPrecipitationMultiplier)
	self:SetMesocycloneSize(self.MesocycloneSize)

	self:SetVortexPositionNoisePhase(self.VortexPositionNoisePhase or 0)
	self:SetVortexPositionNoiseFrequency(self.VortexPositionNoiseFrequency)
	self:SetVortexPositionNoiseAmplitude(self.VortexPositionNoiseAmplitude)
	self:SetVortexPositionNoiseSpeed(self.VortexPositionNoiseSpeed)
	self:SetVortexPositionNoiseDetail(self.VortexPositionNoiseDetail)
	self:SetVortexPositionNoisePeak(self.VortexPositionNoisePeak)
	self:SetVortexPositionNoiseSeed(self.VortexPositionNoiseSeed)

	self:SetVortexModelParametersAlpha(vortexModelParams.alpha)
	self:SetVortexModelParametersZScale(vortexModelParams.zScale)
	self:SetVortexModelParametersFalloffExponent(vortexModelParams.falloffExponent)
	self:SetVortexModelParametersTwoCelled(vortexModelParams.twoCelled)

	self:SetFunnelWidthTableBaseWidth(funnelWidthTable.baseWidth)
	self:SetFunnelWidthTableMidWidth(funnelWidthTable.midWidth)
	self:SetFunnelWidthTableMidWidthHeight(funnelWidthTable.midWidthHeight)
	self:SetFunnelWidthTableTopWidth(funnelWidthTable.topWidth)
	self:SetFunnelWidthTableWidthExponent(funnelWidthTable.widthExponent)

	self:SetFCRActivationHeight(mathFloor(funnelCondensationRing.activationHeight + 0.5))
	self:SetFCRRadiusMultiplier(funnelCondensationRing.radiusMultiplier)

	self:SetSupercellParametersDebrisMax(supercellParameters.debrisMax)
	self:SetSupercellParametersHookMax(supercellParameters.hookMax)
	self:SetSupercellParametersDebrisBSize(supercellParameters.debrisBSize)
	self:SetSupercellParametersHookLenSize(supercellParameters.hookLenSize)
	self:SetSupercellParametersHookWidSize(supercellParameters.hookWidSize)
	self:SetSupercellParametersHookAngSize(supercellParameters.hookAngSize)

	self:SetCondensationThreshold(self.CondensationThreshold)

	local anticyclonic = self.Anticyclonic
	local enableRain = self.EnableRain
	local isDestroying = self.IsDestroying
	local tornado = self.Tornado
	local spout = self.Spout
	local dustDevil = self.DustDevil
	local derecho = self.Derecho
	local hurricane = self.Hurricane
	local dynamic = self.Dynamic
	local thunderstorm = self.Thunderstorm
	local rainstorm = self.Rainstorm
	local stormRFB = self.StormRFB
	local ignoreCondensationThreshold = self.IgnoreCondensationThreshold

	local boolSig =
		(anticyclonic and 1 or 0) +
		(enableRain and 2 or 0) +
		(isDestroying and 4 or 0) +
		(tornado and 8 or 0) +
		(spout and 16 or 0) +
		(dustDevil and 32 or 0) +
		(derecho and 64 or 0) +
		(hurricane and 128 or 0) +
		(dynamic and 256 or 0) +
		(thunderstorm and 512 or 0) +
		(rainstorm and 1024 or 0) +
		(stormRFB and 2048 or 0) +
		(ignoreCondensationThreshold and 4096 or 0)

	if self.GSNetBoolSig ~= boolSig then
		self.GSNetBoolSig = boolSig
		self:SetAnticyclonic(anticyclonic)
		self:SetEnableRain(enableRain)
		self:SetIsDestroying(isDestroying)
		self:SetTornado(tornado)
		self:SetSpout(spout)
		self:SetDustDevil(dustDevil)
		self:SetDerecho(derecho)
		self:SetHurricane(hurricane)
		self:SetDynamic(dynamic)
		self:SetThunderstorm(thunderstorm)
		self:SetRainstorm(rainstorm)
		self:SetStormRFB(stormRFB)
		self:SetIgnoreCondensationThreshold(ignoreCondensationThreshold)

		local rev = (self.GSBoolRevision or 0) + 1
		self.GSBoolRevision = rev
		self:SetBoolRevision(rev)
	end

	local packName = self.ParticlePackName or self.ParticleProfileName
	if !packName or packName == "" then packName = GSGetPackFallback() end

	local selected = self.ParticleTypesSelected or {}
	self.ParticleTypesSelected = selected

	local v1 = selected.mesocyclone or 1
	local v2 = selected.condensation or 1
	local v3 = selected.subvortexcondensation or 1
	local v4 = selected.dustdevil or 1
	local v5 = selected.landspoutlayer or 1
	local v6 = selected.debris or 1
	local v7 = selected.curtains or 1
	local v8 = selected.hurricane or 1

	local a = bitBor(bitBand(v1, 65535), bitLshift(bitBand(v2, 65535), 16))
	local b = bitBor(bitBand(v3, 65535), bitLshift(bitBand(v4, 65535), 16))
	local c = bitBor(bitBand(v5, 65535), bitLshift(bitBand(v6, 65535), 16))
	local d = bitBor(bitBand(v7, 65535), bitLshift(bitBand(v8, 65535), 16))

	if self.GSNetParticlePackName ~= packName
		or self.GSNetParticleSigA ~= a
		or self.GSNetParticleSigB ~= b
		or self.GSNetParticleSigC ~= c
		or self.GSNetParticleSigD ~= d
	then
		self.GSNetParticlePackName = packName
		self.GSNetParticleSigA = a
		self.GSNetParticleSigB = b
		self.GSNetParticleSigC = c
		self.GSNetParticleSigD = d

		self:SetParticleProfile(packName)
		self:SetParticleIndexMesocyclone(v1)
		self:SetParticleIndexCondensation(v2)
		self:SetParticleIndexSubvortexCondensation(v3)
		self:SetParticleIndexDustDevil(v4)
		self:SetParticleIndexLandspoutLayer(v5)
		self:SetParticleIndexDebris(v6)
		self:SetParticleIndexCurtains(v7)
		self:SetParticleIndexHurricane(v8)

		local rev = (self.GSParticleRevision or 0) + 1
		self.GSParticleRevision = rev
		self:SetParticleRevision(rev)
	end

	if !self.Networked then
		self.Networked = true
		self:SetNetworked(true)
	end

end

function ENT:ReceiveEntityVariables()

	local fwt = self.FunnelWidthTable
	local sp = self.SupercellParameters
	local fcr = self.FunnelCondensationRing
	local vmp = self.VortexModelParameters

	self.Position = self:GetPos()
	self.MovementVector = self:GetMovementVector()
	self.VortexSize = self:GetVortexSize()
	self.VortexRMWSize = self:GetVortexRMWSize()
	self.VortexWindspeed = self:GetVortexWindspeed()
	self.ForwardsSpeedMPH = self:GetForwardsSpeedMPH()
	self.SubvortexStrengthMult = self:GetSubvortexStrengthMult()
	self.FunnelMaxHeight = mathFloor(self:GetFunnelMaxHeight() + 0.5)
	self.FunnelStartHeight = mathFloor(self:GetFunnelStartHeight() + 0.5)
	self.VortexPositionNoisePhase = self:GetVortexPositionNoisePhase()
	self.VortexPositionNoiseFrequency = self:GetVortexPositionNoiseFrequency()
	self.VortexPositionNoiseAmplitude = self:GetVortexPositionNoiseAmplitude()
	self.VortexPositionNoiseSpeed = self:GetVortexPositionNoiseSpeed()
	self.VortexPositionNoiseDetail = self:GetVortexPositionNoiseDetail()
	self.VortexPositionNoisePeak = self:GetVortexPositionNoisePeak()
	self.VortexPositionNoiseSeed = self:GetVortexPositionNoiseSeed()
	self.StormPrecipitationMultiplier = self:GetStormPrecipitationMultiplier()
	self.MesocycloneSize = self:GetMesocycloneSize()

	vmp.alpha = self:GetVortexModelParametersAlpha()
	vmp.zScale = self:GetVortexModelParametersZScale()
	vmp.falloffExponent = self:GetVortexModelParametersFalloffExponent()
	vmp.twoCelled = self:GetVortexModelParametersTwoCelled()

	fwt.baseWidth = self:GetFunnelWidthTableBaseWidth()
	fwt.midWidth = self:GetFunnelWidthTableMidWidth()
	fwt.midWidthHeight = self:GetFunnelWidthTableMidWidthHeight()
	fwt.topWidth = self:GetFunnelWidthTableTopWidth()
	fwt.widthExponent = self:GetFunnelWidthTableWidthExponent()

	fcr.activationHeight = mathFloor(self:GetFCRActivationHeight() + 0.5)
	fcr.radiusMultiplier = self:GetFCRRadiusMultiplier()

	sp.debrisMax = self:GetSupercellParametersDebrisMax()
	sp.hookMax = self:GetSupercellParametersHookMax()
	sp.debrisBSize = self:GetSupercellParametersDebrisBSize()
	sp.hookLenSize = self:GetSupercellParametersHookLenSize()
	sp.hookWidSize = self:GetSupercellParametersHookWidSize()
	sp.hookAngSize = self:GetSupercellParametersHookAngSize()

	self.CondensationThreshold = self:GetCondensationThreshold()

	local boolRevision = self:GetBoolRevision()

	if self.GSBoolRevision ~= boolRevision then
		self.GSBoolRevision = boolRevision

		self.Anticyclonic = self:GetAnticyclonic()
		self.EnableRain = self:GetEnableRain()
		self.IsDestroying = self:GetIsDestroying()
		self.Tornado = self:GetTornado()
		self.Spout = self:GetSpout()
		self.DustDevil = self:GetDustDevil()
		self.Derecho = self:GetDerecho()
		self.Hurricane = self:GetHurricane()
		self.Thunderstorm = self:GetThunderstorm()
		self.Rainstorm = self:GetRainstorm()
		self.Dynamic = self:GetDynamic()
		self.StormRFB = self:GetStormRFB()
		self.IgnoreCondensationThreshold = self:GetIgnoreCondensationThreshold()
	end

	local particleRevision = self:GetParticleRevision()

	if self.GSParticleRevision ~= particleRevision then
		self.GSParticleRevision = particleRevision

		local packName = self:GetParticleProfile()
		if !packName or packName == "" then packName = GSGetPackFallback() end

		local selected = self.ParticleTypesSelected or {}
		self.ParticleTypesSelected = selected

		selected.mesocyclone = self:GetParticleIndexMesocyclone()
		selected.condensation = self:GetParticleIndexCondensation()
		selected.subvortexcondensation = self:GetParticleIndexSubvortexCondensation()
		selected.dustdevil = self:GetParticleIndexDustDevil()
		selected.landspoutlayer = self:GetParticleIndexLandspoutLayer()
		selected.debris = self:GetParticleIndexDebris()
		selected.curtains = self:GetParticleIndexCurtains()
		selected.hurricane = self:GetParticleIndexHurricane()

		self.ParticlePackName = packName
		self.HasSetParticleTypesSelected = false
	end

	self.Networked = self:GetNetworked()

end

function ENT:HandleLightning()

	if !self.EnableLightning or self.LightningChance <= 0 or mathRandom(self.LightningChance) ~= 1 or !gs_weatherEntityList.server or !gs_heightPositionFromServerLoad.server then return end

	local startPos = gs_heightPositionFromServerLoad.server + Vector(mathRandom(-30000, 30000), mathRandom(-30000, 30000), -100)
	local trace = utilTraceLine({start = startPos, endpos = startPos - Vector(0, 0, 50000), mask = MASK_SOLID + MASK_WATER})

	if !trace.Hit or !utilIsInWorld(trace.HitPos) or GSGetStormReflectivityValueFromPoint(trace.HitPos, false, gs_weatherEntityList.server) <= 0 then return end

	local lightning = entsCreate("gstorms_lightning_entity")
	if !lightning:IsValid() then return end
	lightning:SetPos(trace.HitPos)
	lightning:Spawn()

end

function ENT:GSUpdateVortexPositionNoisePhase()
	local curTime = self.CurTime
	local dt = curTime - (self.VortexPositionNoiseLastTime or curTime)

	self.VortexPositionNoiseLastTime = curTime
	if dt <= 0 then return end

	self.VortexPositionNoisePhase = (self.VortexPositionNoisePhase or 0) + (dt * self.VortexPositionNoiseSpeed * (self.Anticyclonic and 0.0005 or -0.0005))
end

function ENT:ServersideThink()

    if self.TouchdownConvar and !self.Dynamic then 
		GSDynamicTouchdowns(self, self.CurTime) 
		GSDynamicLifts(self, self.CurTime)
	end

	self.EnableRain = GetConVar("gstorms_env_rain"):GetBool()
    self.EnableLightning = !self.Rainstorm and GetConVar("gstorms_env_lightning"):GetBool() or false
    
    self:Movement()
	self:GSUpdateVortexPositionNoisePhase()
    self:NetworkEntityVariables()
    self:SetDestructionParticlesTimer()
    self:AddSubvortices()
	self:RefreshSubvortices()
    self:HandleLightning()

    if self.Dynamic then GSLerpEntityParams(self) end
    if self.DustDevil and GSGetOnWater(self.Position) then self:Remove() end
    if self.CurTime - self.EntityStartTime > self.MaxLifetime and self:IsValid() then self:Remove() end

	self:SpawnWindVectorHandler(self.Position, self.VortexSize)
    
end

function ENT:ClientsideThink()

    self:ReceiveEntityVariables()
    self:RefreshSubvortices()

    local localPlayer = LocalPlayer()
    if !localPlayer:IsValid() then return end

	self:RenderWindfield(self.Position, localPlayer, localPlayer:GetPos(), self.VortexSize, self.FunnelMaxHeight, self.Anticyclonic, GetConVar("gstorms_av_windfield_update_rate"):GetFloat(), GetConVar("gstorms_av_windfield_resolution"):GetInt() / 1.25, self.VortexPositionNoiseFrequency, self.VortexPositionNoiseAmplitude, self.VortexPositionNoiseSpeed, self.VortexPositionNoiseSeed, self.VortexPositionNoisePhase, self.VortexPositionNoiseDetail, self.VortexPositionNoisePeak)
    self:SubvGroundScouring()

end

function ENT:Think()

    if !self:IsValid() then return end
	if !self.ManualFalloffExponent then self.VortexModelParameters.falloffExponent = Lerp((self.VortexRMWSize / 2000)^0.5, 0.35, 1.0) end

    self.CurTime = CurTime()
    self.VortexSize = self.VortexRMWSize * mathPow(12, mathPow(1 / self.VortexModelParameters.falloffExponent, 1)) * Lerp(mathMax(self.VortexWindspeed, 1) / 150, 0.15, 1)
    self.MesocycloneSize = mathMax(self.VortexRMWSize * mathMax(self.FunnelWidthTable.baseWidth, self.FunnelWidthTable.midWidth, self.FunnelWidthTable.topWidth) * 1.5, 4000, self.VortexSize * 0.4)

    if !self.EntSetup then self:SetupEntity() end

    if SERVER then
        self:ServersideThink()
    else
        self:ClientsideThink()
    end

    self:NextThink(self.CurTime + thinkStep)
    return true

end

function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end -- Constant Rendering