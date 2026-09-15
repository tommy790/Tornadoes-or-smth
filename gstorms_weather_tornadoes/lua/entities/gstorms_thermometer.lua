ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Thermometer"
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Spawnable = false
ENT.IsThermometer = true

local maxInteractDistance = 100
local fireRadius, fireRadiusSqr, fireFalloffExponent = 100, 10000, 2

local function GSResetThermometer(ent, networked)
	ent.TemperatureExperiencedMax = nil
	ent.VolcanoTemperatureSources = {}

	if networked then ent:SetNW2Float("TemperatureExperiencedMax", nil) end
end

function ENT:Initialize()

    self:SetModel("models/Items/battery.mdl")
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:DrawShadow(false)
    self:SetModelScale(0.5)
	self:SetColor(Color(120, 120, 120, 255))

    if SERVER then self:SetUseType(SIMPLE_USE) end

    self.TemperatureExperienced = 0

	GSResetThermometer(self)

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then phys:Wake() end

end

if SERVER then

    local out = Vector(0, 0, 0)

    function ENT:Think()

        local curTime = CurTime()
        local myPos = self:GetPos()
        local _, _, tempGlobal = GSGetGlobalWindspeedAndVectors(myPos, gs_weatherEntityList.server, GetConVar("gstorms_tornado_inflow_jet"):GetBool(), gs_env.server, curTime, out)
        local temperature = tempGlobal or 0
        local volcanoTemperatureSources = self.VolcanoTemperatureSources

        if volcanoTemperatureSources then

            for id, data in pairs(volcanoTemperatureSources) do

                if !data or (data.expire or 0) <= curTime then volcanoTemperatureSources[id] = nil continue end

                temperature = math.max(temperature, data.temperature or 0)

            end

        end

        local temperatureMax = math.Rand(175, 225)

        for _, ent in ipairs(ents.FindInSphere(myPos, fireRadius)) do

            if !ent:IsValid() or ent == self then continue end

            local class = ent:GetClass()

            if !ent:IsOnFire() and class ~= "entityflame" and class ~= "env_fire" then continue end

            local firePos = ent.WorldSpaceCenter and ent:WorldSpaceCenter() or ent:GetPos()
            local distSqr = myPos:DistToSqr(firePos)

            if distSqr > fireRadiusSqr then continue end

            temperature = math.max(temperature, temperatureMax * ((1 - math.sqrt(distSqr) / fireRadius) ^ fireFalloffExponent))

        end

        self.TemperatureExperienced = temperature
        self.TemperatureExperiencedMax = self.TemperatureExperiencedMax and math.max(self.TemperatureExperiencedMax, temperature) or temperature

        self:SetNW2Float("TemperatureExperiencedMax", self.TemperatureExperiencedMax)
        self:SetNW2Float("TemperatureExperienced", temperature)

        if (self.NextTempUpdate or 0) < curTime then

            self.NextTempUpdate = curTime + engine.TickInterval() * 30
            self:NextThink(self.NextTempUpdate)

            return true

        end

    end

	function ENT:Use(activator)

		if !activator:IsValid() or !activator:IsPlayer() then return end
		if self:GetPos():Distance2D(activator:GetPos()) > maxInteractDistance then return end

		GSResetThermometer(self, true)

	end

end