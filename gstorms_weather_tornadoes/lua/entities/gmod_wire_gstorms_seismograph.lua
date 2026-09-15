if !WireLib then return end

DEFINE_BASECLASS("base_wire_entity")

ENT.Type = "anim"
ENT.Base = "base_wire_entity"

ENT.PrintName = "GStorms Seismograph"
ENT.Author = "GStorms"
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Spawnable = false
ENT.AdminOnly = false

ENT.IsSeismograph = true
ENT.IsWireSeismograph = true

local maxInteractDistance = 100
local outCurrent = "Current Magnitude"
local outMax = "Max Magnitude"

function ENT:Initialize()

	self:SetModel("models/props_c17/suitcase_passenger_physics.mdl")
	self:SetRenderMode(RENDERMODE_TRANSALPHA)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:DrawShadow(false)
	self:SetColor(Color(120, 120, 120, 255))

	if !SERVER then return end

	self:SetUseType(SIMPLE_USE)

	self.MagnitudeExperienced = 0
	self.MagnitudeExperiencedMax = 0
	self.PhysgunPickupEnabled = true

	WireLib.CreateSpecialOutputs(self, {outCurrent, outMax}, {"NORMAL", "NORMAL"})
	self.Inputs = WireLib.CreateInputs(self, {"Reset Max Magnitude"})

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then phys:Wake() end

end

function ENT:ResetMaxMagnitude()

	self.MagnitudeExperiencedMax = 0

	self:SetNW2Float("MagnitudeExperiencedMax", 0)
	WireLib.TriggerOutput(self, outMax, 0)

end

function ENT:TriggerInput(name, value)

	if !SERVER then return end
	if name ~= "Reset Max Magnitude" then return end
	if value <= 0 then return end

	self:ResetMaxMagnitude()

end

function ENT:Use(activator)

	if !SERVER then return end
	if !activator:IsValid() or !activator:IsPlayer() then return end
	if self:GetPos():Distance2D(activator:GetPos()) > maxInteractDistance then return end

	self:ResetMaxMagnitude()

end

function ENT:PhysgunPickup(ply) return self.PhysgunPickupEnabled end

if SERVER then

	local out = Vector(0, 0, 0)

	function ENT:Think()

		local curTime = CurTime()
		local magExperienced = math.Round(GSGetGlobalMagnitude(self:GetPos(), gs_earthquakeList.server, out), 1)

		self.MagnitudeExperienced = magExperienced
		self.MagnitudeExperiencedMax = math.max(magExperienced, self.MagnitudeExperiencedMax or 0)

		self:SetNW2Float("MagnitudeExperienced", magExperienced)
		self:SetNW2Float("MagnitudeExperiencedMax", self.MagnitudeExperiencedMax)

		WireLib.TriggerOutput(self, outCurrent, magExperienced)
		WireLib.TriggerOutput(self, outMax, self.MagnitudeExperiencedMax)

		self:SetOverlayText(("Magnitude: %.1f\nMagnitude Peak: %.1f"):format(magExperienced, self.MagnitudeExperiencedMax))

		self:NextThink(curTime + (engine.TickInterval() * 30))
		return true

	end

	duplicator.RegisterEntityClass("gmod_wire_gstorms_seismograph", WireLib.MakeWireEnt, "Data")

end