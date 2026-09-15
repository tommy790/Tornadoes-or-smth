ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Probe"
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Spawnable = false
ENT.IsProbe = true

local maxInteractDistance = 100

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
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:DrawShadow(false)
    self:SetModelScale(1)
    self:SetMaterial("phoenix_storms/stripes")
    self:SetColor(Color(120, 120, 120, 255))

    if SERVER then self:SetUseType(SIMPLE_USE) end

    self.WindspeedExperienced = 0

	GSResetProbe(self, true)

    self.PhysgunPickupEnabled = true

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then phys:Wake() end

    self:SetNW2Bool("ProbeDeployed", false)

end

if SERVER then

    local out = Vector(0, 0, 0)

    function ENT:Think()

        local curTime = CurTime()
        local ws = GSGetGlobalWindspeedAndVectors(self:GetPos(), gs_weatherEntityList.server, GetConVar("gstorms_tornado_inflow_jet"):GetBool(), gs_env.server, curTime, out)
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

		if gustTimeBuffer then

			local gustValueBuffer = self.Gust3SValueBuffer
			local head, tail = self.Gust3SHead or 1, self.Gust3STail or 1
			local gustSum = (self.Gust3SSum or 0) + ws

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

			self.WindspeedExperiencedGust3S = count > 0 and (gustSum / count) or 0
			self.WindspeedExperiencedGust3SMax = math.max(self.WindspeedExperiencedGust3SMax, self.WindspeedExperiencedGust3S)

			if head > 512 then

				local newTime, newVal, newTail = {}, {}, 1

				for i = head, tail - 1 do
					newTime[newTail], newVal[newTail] = gustTimeBuffer[i], gustValueBuffer[i]
					newTail = newTail + 1
				end

				self.Gust3STimeBuffer, self.Gust3SValueBuffer = newTime, newVal
				self.Gust3SHead, self.Gust3STail = 1, newTail

			end

		end

        self:SetNW2Float("WindspeedExperiencedMax", self.WindspeedExperiencedMax)
        self:SetNW2Float("WindspeedExperienced", ws)
		self:SetNW2Float("WindspeedExperiencedGust3SMax", self.WindspeedExperiencedGust3SMax)
		self:SetNW2Float("WindspeedExperiencedGust3S", self.WindspeedExperiencedGust3S)

        if (self.NextWindUpdate or 0) < curTime then

            self.NextWindUpdate = curTime + engine.TickInterval()
            self:NextThink(self.NextWindUpdate)

            return true

        end

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

    net.Receive("gs_probe_reset", function(len, ply)

        local ent = net.ReadEntity()
        if (!ent:IsValid() or !ent.IsProbe or ent:GetPos():Distance2D(ply:GetPos()) > maxInteractDistance) then return end

		GSResetProbe(ent, true)

        net.Start("gs_probe_reset")
        net.WriteEntity(ent)
        net.Send(ply)

    end)

	function ENT:Use(activator)

		if !activator:IsValid() or !activator:IsPlayer() then return end
		if self:GetPos():Distance2D(activator:GetPos()) > maxInteractDistance then return end

		self:ToggleDeploy()

		net.Start("gs_probe_deploy_tip")
		net.WriteEntity(self)
		net.WriteBool(self:GetNW2Bool("ProbeDeployed", false))
		net.Send(activator)

	end

end

if CLIENT then

	net.Receive("gs_probe_reset", function()

		local ent = net.ReadEntity()
		if !ent:IsValid() or !ent.IsProbe then return end

		GSResetProbe(ent)

	end)

	net.Receive("gs_probe_deploy_tip", function()

		local ent = net.ReadEntity()
		local deployed = net.ReadBool()

		if !ent:IsValid() or !ent.IsProbe then return end

		notification.AddLegacy(deployed and "Probe Deployed" or "Probe Undeployed", NOTIFY_HINT, 5)
		surface.PlaySound("ambient/water/drip2.wav")

	end)

end

function ENT:PhysgunPickup() return self.PhysgunPickupEnabled end