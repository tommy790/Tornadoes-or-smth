if !WireLib then return end

ENT.Type = "anim"
ENT.Base = "base_wire_entity"

ENT.PrintName = "GStorms Probe"
ENT.Author = "GStorms"
ENT.Spawnable = false
ENT.AdminOnly = false

ENT.IsProbe = true
ENT.IsWireProbe = true

local maxInteractDistance = 100

local outCurrent = "Current Windspeed"
local outMax = "Max Windspeed"
local outGustMax = "Max Windspeed 3S Gust"

local function GSResetProbe(ent, full)
	ent.WindspeedExperiencedMax = 0
	ent.WindspeedExperiencedGust3SMax = 0

	if !full then return end

	ent.WindspeedExperiencedGust3S = 0
	ent.ExplosionWindspeedSources = {}
	ent.Gust3STimeBuffer = {}
	ent.Gust3SValueBuffer = {}
	ent.Gust3SHead, ent.Gust3STail = 1, 1
	ent.Gust3SSum = 0
end

function ENT:Initialize()

	self:SetModel("models/props_interiors/pot01a.mdl")
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:DrawShadow(false)
	self:SetMaterial("phoenix_storms/stripes")
	self:SetColor(Color(120, 120, 120, 255))

	if !SERVER then return end

	self:SetUseType(SIMPLE_USE)

	self.WindspeedExperienced = 0

	GSResetProbe(self, true)

	self.PhysgunPickupEnabled = true

	self:SetNW2Bool("ProbeDeployed", false)

	WireLib.CreateSpecialOutputs(self, {outCurrent, outMax, outGustMax}, {"NORMAL", "NORMAL", "NORMAL"})

	self.Inputs = WireLib.CreateInputs(self, {"Reset Peaks"})

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then phys:Wake() end

end

function ENT:PhysgunPickup() return self.PhysgunPickupEnabled end

if SERVER then

	local out = Vector(0, 0, 0)

	function ENT:TriggerInput(name, value)

		if name ~= "Reset Peaks" then return end
		if value <= 0 then return end

		self:ResetPeaks()

	end

	function ENT:ResetPeaks()

		GSResetProbe(self, true)

		WireLib.TriggerOutput(self, outMax, 0)
		WireLib.TriggerOutput(self, outGustMax, 0)

	end

	function ENT:ToggleDeploy()

		local newstate = !self:GetNW2Bool("ProbeDeployed", false)

		self:SetNW2Bool("ProbeDeployed", newstate)
		self.ProbeDeployed = newstate

		local phys = self:GetPhysicsObject()
		if !phys:IsValid() then return end

		local motion = !newstate

		phys:EnableMotion(motion)
		phys:EnableGravity(motion)
		self:SetMoveType(newstate and MOVETYPE_NONE or MOVETYPE_VPHYSICS)
		self.PhysgunPickupEnabled = motion

		if motion then
			phys:Wake()
		else
			phys:Sleep()
		end

	end

	function ENT:Use(activator)

		if !activator:IsValid() or !activator:IsPlayer() then return end
		if self:GetPos():Distance2D(activator:GetPos()) > maxInteractDistance then return end

		self:ToggleDeploy()

	end

	function ENT:Think()

		local curTime = CurTime()
		local ws = GSGetGlobalWindspeedAndVectors(self:GetPos(), gs_weatherEntityList.server, GetConVar("gstorms_tornado_inflow_jet"):GetBool(), gs_env.server, curTime, out, false) or 0
		local explosionWindspeedSources = self.ExplosionWindspeedSources

		if explosionWindspeedSources then

			for id, data in pairs(explosionWindspeedSources) do

				if !data or (data.expire or 0) <= curTime then explosionWindspeedSources[id] = nil continue end

				ws = math.max(ws, data.windspeed or 0)

			end

		end

		self.WindspeedExperienced = ws
		self.WindspeedExperiencedMax = math.max(self.WindspeedExperiencedMax, ws)

		local gustTimeBuffer = self.Gust3STimeBuffer
		local gustValueBuffer = self.Gust3SValueBuffer
		local head, tail = self.Gust3SHead, self.Gust3STail
		local gustSum = self.Gust3SSum + ws

		gustTimeBuffer[tail], gustValueBuffer[tail] = curTime, ws
		tail = tail + 1

		local cutoff = curTime - 3

		while head < tail and (gustTimeBuffer[head] or 0) < cutoff do
			gustSum = gustSum - (gustValueBuffer[head] or 0)
			gustTimeBuffer[head], gustValueBuffer[head] = nil, nil
			head = head + 1
		end

		self.Gust3SSum = gustSum
		self.Gust3SHead, self.Gust3STail = head, tail

		local count = tail - head
		local gust3S = count > 0 and (gustSum / count) or 0

		self.WindspeedExperiencedGust3S = gust3S
		self.WindspeedExperiencedGust3SMax = math.max(self.WindspeedExperiencedGust3SMax, gust3S)

		if head > 512 then

			local newTime, newVal, newTail = {}, {}, 1

			for i = head, tail - 1 do
				newTime[newTail], newVal[newTail] = gustTimeBuffer[i], gustValueBuffer[i]
				newTail = newTail + 1
			end

			self.Gust3STimeBuffer, self.Gust3SValueBuffer = newTime, newVal
			self.Gust3SHead, self.Gust3STail = 1, newTail

		end

		local wsOut = math.Round(ws)
		local wsMaxOut = math.Round(self.WindspeedExperiencedMax)
		local gustMaxOut = math.Round(self.WindspeedExperiencedGust3SMax)

		WireLib.TriggerOutput(self, outCurrent, wsOut)
		WireLib.TriggerOutput(self, outMax, wsMaxOut)
		WireLib.TriggerOutput(self, outGustMax, gustMaxOut)

		self:SetOverlayText(
			("Current: %.0f MPH\nMax: %.0f MPH\n3s Gust Max: %.0f MPH\nDeployed: %s"):format(
				wsOut,
				wsMaxOut,
				gustMaxOut,
				self:GetNW2Bool("ProbeDeployed", false) and "YES" or "NO"
			)
		)

		self:NextThink(curTime + engine.TickInterval())
		return true

	end

end