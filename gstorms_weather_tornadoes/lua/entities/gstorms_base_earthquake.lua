ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.Spawnable = false

include("gstorms_funcs/gstorms_shared.lua")

ENT.Earthquake = true

ENT.Magnitude = 1
ENT.Radius = 100000 -- HU from the epicenter

ENT.ShockDurationMin = 22 -- Seconds
ENT.ShockDurationMax = 26 -- Seconds

ENT.AftershockCountMin = 0
ENT.AftershockCountMax = 3

ENT.AftershockSpacingMin = 10 -- Seconds
ENT.AftershockSpacingMax = 40 -- Seconds

ENT.AftershockMagnitudeMinMult = 0.2
ENT.AftershockMagnitudeMaxMult = 0.7

ENT.ExponentMin = 0.8 -- The exponents for determining how the strength increases until it's peak at half of the duration given the phase
ENT.ExponentMax = 1.2

local mathRand = math.Rand
local mathRandom = math.random
local mathSin = math.sin
local mathSqrt = math.sqrt
local mathMin = math.min
local mathMax = math.max
local mathRound = math.Round
local stringFormat = string.format
local tinyVal = 1e-8

function ENT:GetNextProperties()
	self.ShockDuration = mathRand(self.ShockDurationMin, self.ShockDurationMax)
	self.AftershockSchedule = mathRand(self.AftershockSpacingMin, self.AftershockSpacingMax)
	self.Exponent = mathRand(self.ExponentMin, self.ExponentMax)
	self.PeakFrac = mathRand(0.25, 0.75) -- Where the shock peaks fractionally I.E a 4 second shock at a peakFrac at 0.75 would have it's configured magnitude reached at 3 seconds
	self.BaseShakeDirection = GSGetNormVecNoZ(1)
	self.ShakeDirection = Vector(0, 0, 0)
	self.ShakeDirection:SetUnpacked(self.BaseShakeDirection.x, self.BaseShakeDirection.y, 0)
	self.ShakeSeed = mathRandom(9999)
	self.ShockDurationCompleted = false
end

function ENT:StartEarthquakeShock(isAftershock)
	self:GetNextProperties()

	local curTime = self.CurTime or CurTime()
	local magMult = isAftershock and mathRand(self.AftershockMagnitudeMinMult, self.AftershockMagnitudeMaxMult) or 1

	self.PeakMagnitude = self.Magnitude * magMult
	self.CurrentMagnitude = 0

	self.ShockStartTime = curTime
	self.ShockEndTime = curTime + self.ShockDuration
	self.ShockActive = true
end

function ENT:SetupEntity()
	if SERVER then
		self.CurrentMagnitude = 0
		self.CurrentRadius = self.Radius

		self.AftershocksRemaining = mathRandom(self.AftershockCountMin, self.AftershockCountMax)
		self.NextAftershockTime = 0

		self.ShockActive = false
		self.ShockDurationCompleted = true

		self:StartEarthquakeShock(false)

		self.EntSetup = true

		local owner = self:GetOwner()

		if IsValid(owner) then
			if !self.Autospawn then
				GSTipToClient(owner, stringFormat("Earthquake | Magnitude: %.1f", self.Magnitude or 0))
			end
		end
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "CurrentMagnitude")
	self:NetworkVar("Float", 1, "CurrentRadius")
	self:NetworkVar("Float", 2, "ShakeSeed")
	self:NetworkVar("Vector", 0, "ShakeDirection")
	self:NetworkVar("Vector", 1, "Position")
	self:NetworkVar("Bool", 0, "Networked")
end

function ENT:NetworkEntityVariables()
	self:SetCurrentMagnitude(self.CurrentMagnitude)
	self:SetCurrentRadius(self.CurrentRadius)
	self:SetShakeDirection(self.ShakeDirection)
	self:SetShakeSeed(self.ShakeSeed)
	self:SetPosition(self.Position)
	if !self.Networked then
		self.Networked = true
		self:SetNetworked(self.Networked)
	end
end

function ENT:ReceiveEntityVariables()
	self.CurrentMagnitude = self:GetCurrentMagnitude()
	self.CurrentRadius = self:GetCurrentRadius()
	self.Radius = self.CurrentRadius
	self.ShakeDirection = self:GetShakeDirection()
	self.ShakeSeed = self:GetShakeSeed()
	self.Position = self:GetPosition()
	self.Networked = self:GetNetworked()
end

function ENT:LerpProperties()
	local shockDuration = self.ShockDuration

	if !shockDuration or shockDuration <= 0 then self.CurrentMagnitude = 0 return end

	local frac = (self.CurTime - self.ShockStartTime) / shockDuration

	if frac <= 0 then self.CurrentMagnitude = 0 return end

	if frac >= 1 then
		self.CurrentMagnitude = 0
		self.ShockActive = false
		self.ShockDurationCompleted = true

		if self.AftershocksRemaining > 0 then self.NextAftershockTime = self.CurTime + self.AftershockSchedule end

		return
	end

	local peakFrac = self.PeakFrac
	local t = frac <= peakFrac and frac / peakFrac or (1 - frac) / (1 - peakFrac)

	self.CurrentMagnitude = self.PeakMagnitude * (t ^ self.Exponent)
end

function ENT:HandleEarthquakeNoise()
	local baseDir = self.BaseShakeDirection or self.ShakeDirection

	if !baseDir then return end

	local seed = self.ShakeSeed or 0
	local t = self.CurTime * 0.4
	local wave = mathSin((t * 22) + seed)
	local sideWave = mathSin((t * 13) + (seed * 0.37)) * 0.35
	local x = (baseDir.x * wave) + (-baseDir.y * sideWave)
	local y = (baseDir.y * wave) + (baseDir.x * sideWave)
	local len2 = (x * x) + (y * y)

	if len2 <= tinyVal then return end

	local mult = 1 / mathSqrt(len2)

	self.ShakeDirection:SetUnpacked(x * mult, y * mult, 0)
end

function ENT:HandleEarthquakeProperties()
	if self.ShockActive then
		self:LerpProperties()
		if self.CurrentMagnitude > 0 then self:HandleEarthquakeNoise() end
		return
	end

	if !GetConVar("gstorms_earthquake_aftershocks"):GetBool() or self.AftershocksRemaining <= 0 or self.CurTime < self.NextAftershockTime then return end

	self.AftershocksRemaining = self.AftershocksRemaining - 1
	self:StartEarthquakeShock(true)
end

function ENT:Think()

	if !self:IsValid() then return end

	self.CurTime = CurTime()

	if SERVER then
		if !self.EntSetup then self:SetupEntity() end

		self:HandleEarthquakeProperties()
		self.Position = self:GetPos()
		self:NetworkEntityVariables()
	else
		self:ReceiveEntityVariables()
	end

	self:NextThink(self.CurTime + engine.TickInterval())
	return true

end