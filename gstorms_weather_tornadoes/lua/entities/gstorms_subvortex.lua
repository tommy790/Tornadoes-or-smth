ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Parent = nil
ENT.FunnelWidthTable = {baseWidth = 1, midWidth = 2, midWidthHeight = 0.5, topWidth = 4, widthExponent = 1}
ENT.VortexModelParameters = {alpha = 0.5, zScale = 4500, twoCelled = 1, falloffExponent = 1}
ENT.VortexWindspeed = 0

include("gstorms_funcs/gstorms_shared.lua")

-- locals / globals
local mathPi = math.pi
local twoMathPi = mathPi * 2
local nilCol = Color(0, 0, 0, 0)

local mathCos = math.cos
local mathSin = math.sin
local mathRand = math.Rand
local mathMax = math.max
local mathClamp = math.Clamp
local mathFloor = math.floor
local utilTraceLine = util.TraceLine
local engineTickInterval = engine.TickInterval
local Vector = Vector
local Lerp = Lerp
local CurTime = CurTime
local Color = Color

local GSGetSubvortexParticleShape = GSGetSubvortexParticleShape
local GSMainVortexWindspeed = GSMainVortexWindspeed

local function GSLerpEaseT(t, exponent)
	t = mathClamp(t, 0, 1)
	return t < 0.5 and 0.5 * (2 * t) ^ exponent or 1 - 0.5 * (2 * (1 - t)) ^ exponent
end

function ENT:Initialize()

	self:SetModel("models/props_c17/canister01a.mdl")
	self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	self:SetColor(nilCol)
	self:SetRenderMode(RENDERMODE_TRANSALPHA)
	self:SetMoveType(MOVETYPE_FLY)
	self:SetSolid(SOLID_NONE)
	self.CurTime = CurTime()

	if SERVER then

		local parent = self.Parent
		if !IsValid(parent) then self:Remove() return end
	
		self.SubvParentEntIndex = parent:EntIndex()
		self:SetSubvParentEntIndex(self.SubvParentEntIndex)
	
		GSGetSubvortexParticleShape(parent, self)

		self.Angle = mathRand(0, 1) * twoMathPi
		self.InitTime = self.CurTime
		self.HalfLife = self.Lifetime * 0.5
		self.InvHalfLife = self.HalfLife > 0 and (1 / self.HalfLife) or 0
		self.VortexPositionNoisePhase = self.CurTime * (self.VortexPositionNoiseSpeed or 0) * (parent.Anticyclonic and 0.0005 or -0.0005)
		self.VortexPositionNoiseLastTime = self.CurTime

		local ang = self.Angle
		local orbitRadius = self.OrbitRadius
		local parentPos = parent.Position
		local parentPosX, parentPosY, parentPosZ = parentPos.x, parentPos.y, parentPos.z
		local offX = mathCos(ang) * orbitRadius
		local offY = mathSin(ang) * orbitRadius

		self.Position = Vector(parentPosX + offX, parentPosY + offY, parentPosZ)

		local selfPos = self.Position
		local selfPosX, selfPosY = selfPos.x, selfPos.y
		local distance2D, distanceZ = selfPos:Distance2D(parentPos), selfPos.z - parentPosZ
		local movementVector = parent.MovementVector

		if orbitRadius <= parent.VortexRMWSize then
			self.TornadoWindspeedAtPosition = parent.VortexWindspeed
		else
			self.TornadoWindspeedAtPosition = GSMainVortexWindspeed(selfPosX - parentPosX, selfPosY - parentPosY, distance2D, distanceZ, parent.VortexSize, parent.VortexRMWSize, parent.VortexWindspeed, movementVector.x, movementVector.y, movementVector.z, parent.ForwardsSpeedMPH, parent.Anticyclonic, parent.VortexModelParameters, parent.FunnelWidthTable, parent.FunnelMaxHeight)
		end

		self.WindspeedSelected = self.TornadoWindspeedAtPosition * self.VortexWindspeedMultiplier
		self.Initialized = true

	end

end

local subvortexVectorCheckOffsetZ = 500
local maskSubvortices = MASK_SOLID_BRUSHONLY + MASK_WATER
local traceDataSubv = {mask = maskSubvortices}
local subvortexForwardsSpeedMult = 0.75

local function GSUpdateSubvortexPositionNoisePhase(ent)
	local curTime = ent.CurTime
	local dt = curTime - (ent.VortexPositionNoiseLastTime or curTime)

	ent.VortexPositionNoiseLastTime = curTime
	if dt <= 0 then return end

	local parent = ent.Parent
	local noiseDir = (IsValid(parent) and parent.Anticyclonic) and 0.0005 or -0.0005

	ent.VortexPositionNoisePhase = (ent.VortexPositionNoisePhase or 0) + (dt * (ent.VortexPositionNoiseSpeed or 0) * noiseDir)
end

function ENT:RotateSubvortices()

	local parent = self.Parent
	local parentPos = parent.Position
	local parentPosX, parentPosY, parentPosZ = parentPos.x, parentPos.y, parentPos.z

	local pos = self.Position
	local posX, posY = pos.x, pos.y

	local orbitRadius = self.OrbitRadius
	local distance2D = orbitRadius
	local distanceZ = pos.z - parentPosZ

	local halfLife = self.HalfLife
	local invHalfLife = self.InvHalfLife
	local dt = self.CurTime - self.InitTime

	local anticyclonic = parent.Anticyclonic
	local spinDir = anticyclonic and -1 or 1

	local movementVector = parent.MovementVector
	local tornadoWS = GSMainVortexWindspeed(posX - parentPosX, posY - parentPosY, distance2D, distanceZ, parent.VortexSize, parent.VortexRMWSize, parent.VortexWindspeed, movementVector.x, movementVector.y, movementVector.z, parent.ForwardsSpeedMPH, anticyclonic, parent.VortexModelParameters, parent.FunnelWidthTable, parent.FunnelMaxHeight)

	self.TornadoWindspeedAtPosition = tornadoWS

	local ang = self.Angle + GSGetSpeedFromRadius(tornadoWS, orbitRadius, self.VortexRMWSize, 2) * spinDir
	self.Angle = ang

	local offX = mathCos(ang) * orbitRadius
	local offY = mathSin(ang) * orbitRadius
	local posCheckX = parentPosX + offX
	local posCheckY = parentPosY + offY

	local trStart = self.GSTraceStart
	if !trStart then trStart = Vector(0, 0, 0) self.GSTraceStart = trStart end

	local trEnd = self.GSTraceEnd
	if !trEnd then trEnd = Vector(0, 0, 0) self.GSTraceEnd = trEnd end

	trStart:SetUnpacked(posCheckX, posCheckY, parentPosZ + subvortexVectorCheckOffsetZ)
	trEnd:SetUnpacked(posCheckX, posCheckY, parentPosZ - subvortexVectorCheckOffsetZ)

	traceDataSubv.start = trStart
	traceDataSubv.endpos = trEnd
	traceDataSubv.filter = self

	pos:SetUnpacked(posCheckX, posCheckY, utilTraceLine(traceDataSubv).HitPos.z)

	self:SetPos(pos)

	if invHalfLife > 0 then
		local windspeedSelected = self.WindspeedSelected
		local windspeedEaseExponent = self.WindspeedEaseExponent

		if dt <= halfLife then
			self.VortexWindspeed = Lerp(GSLerpEaseT(dt * invHalfLife, windspeedEaseExponent), 0, windspeedSelected)
		else
			self.VortexWindspeed = Lerp(GSLerpEaseT((dt - halfLife) * invHalfLife, windspeedEaseExponent), windspeedSelected, 0)
		end
	else
		self.VortexWindspeed = 0
	end

	local mv = self.MovementVector
	if !mv then mv = Vector(0, 0, 0) self.MovementVector = mv end

	if orbitRadius > 0 then
		local invOrbitRadius = spinDir / orbitRadius
		mv:SetUnpacked(offY * invOrbitRadius, -offX * invOrbitRadius, 0)
	else
		mv:SetUnpacked(0, 0, 0)
	end

	self.ForwardsSpeedMPH = tornadoWS * subvortexForwardsSpeedMult

end

function ENT:SetupDataTables()
    self:NetworkVar("Vector", 0, "SubvMovementVector")
    self:NetworkVar("Float", 0, "SubvVortexRMWSize")
    self:NetworkVar("Float", 1, "SubvVortexSize")
    self:NetworkVar("Float", 2, "SubvVortexWindspeed")
    self:NetworkVar("Float", 3, "SubvVortexPositionNoisePhase")
    self:NetworkVar("Float", 4, "SubvVortexPositionNoiseAmplitude")
    self:NetworkVar("Float", 5, "SubvVortexPositionNoiseFrequency")
    self:NetworkVar("Float", 6, "SubvVortexPositionNoiseSpeed")
    self:NetworkVar("Float", 7, "SubvVortexPositionNoiseDetail")
	self:NetworkVar("Float", 8, "SubvVortexPositionNoisePeak")
    self:NetworkVar("Float", 9, "VMPAlpha")
    self:NetworkVar("Float", 10, "VMPZScale")
    self:NetworkVar("Float", 11, "VMPTwoCelled")
    self:NetworkVar("Float", 12, "VMPFalloff")
    self:NetworkVar("Float", 13, "FWTBaseWidth")
    self:NetworkVar("Float", 14, "FWTMidWidth")
	self:NetworkVar("Float", 15, "FWTMidWidthHeight")
    self:NetworkVar("Float", 16, "FWTTopWidth")
    self:NetworkVar("Float", 17, "FWTWidthExponent")
    self:NetworkVar("Int", 0, "SubvVortexPositionNoiseSeed")
    self:NetworkVar("Int", 1, "SubvParentEntIndex")
    self:NetworkVar("Int", 2, "SubvFunnelMaxHeight")
    self:NetworkVar("Int", 3, "SubvFunnelStartHeight")
    self:NetworkVar("Bool", 0, "Networked")
end

function ENT:NetworkVars()

	self:SetSubvMovementVector(self.MovementVector)
	self:SetSubvVortexWindspeed(self.VortexWindspeed)
	self:SetSubvVortexPositionNoisePhase(self.VortexPositionNoisePhase or 0)

	if !self.Networked then
		local funnelWidthTable = self.FunnelWidthTable
		local vortexModelParameters = self.VortexModelParameters

		self:SetSubvVortexRMWSize(self.VortexRMWSize)
		self:SetSubvVortexSize(self.VortexSize)
		self:SetSubvFunnelMaxHeight(mathFloor(self.FunnelMaxHeight + 0.5))
		self:SetSubvFunnelStartHeight(mathFloor(self.FunnelStartHeight + 0.5))
		self:SetSubvVortexPositionNoiseAmplitude(self.VortexPositionNoiseAmplitude)
		self:SetSubvVortexPositionNoiseFrequency(self.VortexPositionNoiseFrequency)
		self:SetSubvVortexPositionNoiseSpeed(self.VortexPositionNoiseSpeed)
		self:SetSubvVortexPositionNoiseDetail(self.VortexPositionNoiseDetail)
		self:SetSubvVortexPositionNoisePeak(self.VortexPositionNoisePeak)
		self:SetSubvVortexPositionNoiseSeed(self.VortexPositionNoiseSeed)
		self:SetSubvParentEntIndex(self.SubvParentEntIndex or -1)

		self:SetFWTBaseWidth(funnelWidthTable.baseWidth)
		self:SetFWTMidWidth(funnelWidthTable.midWidth)
		self:SetFWTMidWidthHeight(funnelWidthTable.midWidthHeight)
		self:SetFWTTopWidth(funnelWidthTable.topWidth)
		self:SetFWTWidthExponent(funnelWidthTable.widthExponent)

		self:SetVMPAlpha(vortexModelParameters.alpha)
		self:SetVMPZScale(vortexModelParameters.zScale)
		self:SetVMPTwoCelled(vortexModelParameters.twoCelled)
		self:SetVMPFalloff(vortexModelParameters.falloffExponent)

		if !self.Networked then
			self.Networked = true
			self:SetNetworked(true)
		end
	end

end

function ENT:ReceiveNetworkVars()

	self.Position = self:GetPos()
	self.MovementVector = self:GetSubvMovementVector()
	self.VortexWindspeed = self:GetSubvVortexWindspeed()
	self.VortexPositionNoisePhase = self:GetSubvVortexPositionNoisePhase()

	local networked = self:GetNetworked()

	if !self.Networked and networked then
		self.VortexRMWSize = self:GetSubvVortexRMWSize()
		self.VortexSize = self:GetSubvVortexSize()
		self.FunnelMaxHeight = mathFloor(self:GetSubvFunnelMaxHeight() + 0.5)
		self.FunnelStartHeight = mathFloor(self:GetSubvFunnelStartHeight() + 0.5)
		self.VortexPositionNoiseAmplitude = self:GetSubvVortexPositionNoiseAmplitude()
		self.VortexPositionNoiseFrequency = self:GetSubvVortexPositionNoiseFrequency()
		self.VortexPositionNoiseSpeed = self:GetSubvVortexPositionNoiseSpeed()
		self.VortexPositionNoiseDetail = self:GetSubvVortexPositionNoiseDetail()
		self.VortexPositionNoisePeak = self:GetSubvVortexPositionNoisePeak()
		self.VortexPositionNoiseSeed = self:GetSubvVortexPositionNoiseSeed()
		self.SubvParentEntIndex = self:GetSubvParentEntIndex()

		self.FunnelWidthTable.baseWidth = self:GetFWTBaseWidth()
		self.FunnelWidthTable.midWidth = self:GetFWTMidWidth()
		self.FunnelWidthTable.midWidthHeight = self:GetFWTMidWidthHeight()
		self.FunnelWidthTable.topWidth = self:GetFWTTopWidth()
		self.FunnelWidthTable.widthExponent = self:GetFWTWidthExponent()

		self.VortexModelParameters.alpha = self:GetVMPAlpha()
		self.VortexModelParameters.zScale = self:GetVMPZScale()
		self.VortexModelParameters.twoCelled = self:GetVMPTwoCelled()
		self.VortexModelParameters.falloffExponent = self:GetVMPFalloff()
	end

	self.Networked = networked

end

function ENT:Think()

	self.CurTime = CurTime()

	if SERVER then
		if !self.Parent or !self.Parent:IsValid() then self:Remove() return end

		self:RotateSubvortices()
		GSUpdateSubvortexPositionNoisePhase(self)
		self:NetworkVars()

		if (self.CurTime - self.LifetimeStart) >= self.Lifetime then self:Remove() end
	else
		self:ReceiveNetworkVars()
	end

	self:NextThink(self.CurTime + (engineTickInterval() * 2))
	return true

end