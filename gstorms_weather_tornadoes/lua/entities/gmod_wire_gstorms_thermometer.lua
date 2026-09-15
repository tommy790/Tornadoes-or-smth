if !WireLib then return end

ENT.Type = "anim"
ENT.Base = "base_wire_entity"

ENT.PrintName = "GStorms Thermometer"
ENT.Author = "GStorms"
ENT.Spawnable = false
ENT.AdminOnly = false

ENT.IsThermometer = true
ENT.IsWireThermometer = true

local maxInteractDistance = 100

local outCurrent = "Current Temperature"
local outMax = "Max Temperature"

local fireRadius = 100
local fireRadiusSqr = fireRadius * fireRadius
local fireFalloffExponent = 2

local function GSResetThermometer(ent, networked)
	ent.TemperatureExperiencedMax = nil
	ent.VolcanoTemperatureSources = {}

	if !networked then return end

	ent:SetNW2Float("TemperatureExperiencedMax", nil)
	WireLib.TriggerOutput(ent, outMax, 0)
end

function ENT:Initialize()

	self:SetModel("models/Items/battery.mdl")
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:DrawShadow(false)
	self:SetModelScale(0.5, 0)
	self:SetColor(Color(120, 120, 120, 255))

	if !SERVER then return end

	self:SetUseType(SIMPLE_USE)

	self.TemperatureExperienced = 0
	self.PhysgunPickupEnabled = true

	GSResetThermometer(self)

	WireLib.CreateSpecialOutputs(self, {outCurrent, outMax}, {"NORMAL", "NORMAL"})
	self.Inputs = WireLib.CreateInputs(self, {"Reset Max Temp"})

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then phys:Wake() end

end

function ENT:PhysgunPickup() return self.PhysgunPickupEnabled end

if SERVER then

	local out = Vector(0, 0, 0)

	function ENT:ResetMaxTemp()

		GSResetThermometer(self, true)

	end

	function ENT:TriggerInput(name, value)

		if name ~= "Reset Max Temp" then return end
		if value <= 0 then return end

		self:ResetMaxTemp()

	end

	function ENT:Use(activator)

		if !activator:IsValid() or !activator:IsPlayer() then return end
		if self:GetPos():Distance2D(activator:GetPos()) > maxInteractDistance then return end

		self:ResetMaxTemp()

	end

	function ENT:Think()

		local curTime = CurTime()

		if !gs_weatherEntityList.server or !gs_env.server then
			self:NextThink(curTime + engine.TickInterval() * 30)
			return true
		end

		local pos = self:GetPos()
		local _, _, tempGlobal = GSGetGlobalWindspeedAndVectors(pos, gs_weatherEntityList.server, GetConVar("gstorms_tornado_inflow_jet"):GetBool(), gs_env.server, curTime, out)
		local temperature = tempGlobal or 0
		local volcanoTemperatureSources = self.VolcanoTemperatureSources

		if volcanoTemperatureSources then

			for id, data in pairs(volcanoTemperatureSources) do

				if !data or (data.expire or 0) <= curTime then volcanoTemperatureSources[id] = nil continue end

				temperature = math.max(temperature, data.temperature or 0)

			end

		end

		local temperatureMax = math.Rand(175, 225)

		for _, ent in ipairs(ents.FindInSphere(pos, fireRadius)) do

			if !ent:IsValid() or ent == self then continue end

			local class = ent:GetClass()

			if !ent:IsOnFire() and class ~= "entityflame" and class ~= "env_fire" then continue end

			local firePos = ent.WorldSpaceCenter and ent:WorldSpaceCenter() or ent:GetPos()
			local distSqr = pos:DistToSqr(firePos)

			if distSqr > fireRadiusSqr then continue end

			temperature = math.max(temperature, temperatureMax * ((1 - math.sqrt(distSqr) / fireRadius) ^ fireFalloffExponent))

		end

		self.TemperatureExperienced = temperature
		self.TemperatureExperiencedMax = self.TemperatureExperiencedMax and math.max(self.TemperatureExperiencedMax, temperature) or temperature

		local t, tMax, unit = temperature, self.TemperatureExperiencedMax, "C"

		if GetConVar("gstorms_general_fahrenheit"):GetBool() then
			t, tMax, unit = t * 9 / 5 + 32, tMax * 9 / 5 + 32, "F"
		end

		local tOut = math.Round(t, 1)
		local tMaxOut = math.Round(tMax, 1)

		self:SetNW2Float("TemperatureExperienced", tOut)
		self:SetNW2Float("TemperatureExperiencedMax", tMaxOut)

		WireLib.TriggerOutput(self, outCurrent, tOut)
		WireLib.TriggerOutput(self, outMax, tMaxOut)

		self:SetOverlayText(("Temp: %.1f %s\nTemp Peak: %.1f %s"):format(tOut, unit, tMaxOut, unit))

		self:NextThink(curTime + engine.TickInterval() * 30)
		return true

	end

	duplicator.RegisterEntityClass("gmod_wire_gstorms_thermometer", WireLib.MakeWireEnt, "Data")

end