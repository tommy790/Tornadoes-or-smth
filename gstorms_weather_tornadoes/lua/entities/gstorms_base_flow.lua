ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.Spawnable = false

ENT.Flow = true

ENT.FlowWindspeed = 40

ENT.FlowTemperature = 0
ENT.FlowTemperatureCoolingTime = 30

ENT.FlowLifetime = 40
ENT.FlowLookahead = 500

ENT.FlowLinear = false
ENT.FlowLinearDirection = Vector(1, 0, 0)
ENT.FlowLinearWidth = 10000
ENT.FlowLinearLength = 4000

ENT.FlowRadial = false
ENT.FlowRadialDepth = 1000
ENT.WindspeedFalloffExponent = 2

local gsMPHToHUPerSec = 17.6

local gsDefaultPack = "GStorms: Default Resource Pack"
local gsParticleRerollMax = 8192

function ENT:GSInitParticleSelection(packName, reroll)
    if !packName or packName == "" then
        local c = GetConVar("gstorms_particle_texture")
        packName = (c and c:GetString()) or gsDefaultPack
    end

	self.ParticlePackName = packName

    local selected = self.ParticleTypesSelected
    if !selected then
        selected = {}
        self.ParticleTypesSelected = selected
    end

    if reroll or !selected.pyroclasticflow or !selected.sandstorm then
        selected.pyroclasticflow = math.random(gsParticleRerollMax)
        selected.sandstorm = math.random(gsParticleRerollMax)
    end

    self.ParticleIndexPyroclasticFlow = selected.pyroclasticflow or 1
    self.ParticleIndexSandstorm = selected.sandstorm or 1

    if self.SetParticleProfile then self:SetParticleProfile(packName) end

    if self.SetParticleIndexPyroclasticFlow then
        self:SetParticleIndexPyroclasticFlow(self.ParticleIndexPyroclasticFlow)
        self:SetParticleIndexSandstorm(self.ParticleIndexSandstorm)
    end
end

function ENT:SetupEntity()
    local pos = GSGetGroundPosition(self:GetPos())
    
    self:SetPos(pos)
    self.Position = pos
    self.EntSetup = true

    if SERVER then

        self.FlowWindspeedMax = self.FlowWindspeed

        local owner = self:GetOwner()

        if !IsValid(owner) then return end

        if !self.Autospawn then
            GSTipToClient(owner, self.PrintName.." | "..string.format("%s MPH ", self.FlowWindspeedMax))
        end
        
        if GetConVar("gstorms_sim_aim_at_players"):GetBool() then
            local p = owner:GetPos()
            self.FlowLinearDirection = Vector(p.x - pos.x, p.y - pos.y, 0):GetNormalized()
        end

    end
end

function ENT:Initialize()
    if SERVER then
        self.FlowSpawnTime = CurTime()
        self.Position = self:GetPos()
        self.FlowTemperatureCurrent = 0
        self.FlowDistRadCurrent = 0
        self.FlowLinearDirection = GSGetNormVecNoZ(1)
        self:GSInitParticleSelection(nil, true)
    end
end

function ENT:SetupDataTables()
    self:NetworkVar("Vector", 0, "FlowLinearDirection")

    self:NetworkVar("Bool", 0, "FlowLinear")
    self:NetworkVar("Bool", 1, "FlowRadial")
    self:NetworkVar("Bool", 2, "Networked")

    self:NetworkVar("Float", 0, "FlowLinearWidth")
    self:NetworkVar("Float", 1, "FlowLinearLength")
    self:NetworkVar("Float", 2, "FlowRadialDepth")
    self:NetworkVar("Float", 3, "FlowLookahead")
    self:NetworkVar("Float", 4, "FlowDistRadCurrent")
    self:NetworkVar("Float", 5, "FlowWindspeed")
    self:NetworkVar("Float", 6, "FlowTemperatureCurrent")

    self:NetworkVar("String", 0, "ParticleProfile")
    self:NetworkVar("Int", 0, "ParticleIndexPyroclasticFlow")
    self:NetworkVar("Int", 1, "ParticleIndexSandstorm")
    self:NetworkVar("Int", 2, "ParticleRevision")
end

function ENT:ReceiveEntityVariables()
    self.Position = self:GetPos()
    self.FlowLinearDirection = self:GetFlowLinearDirection()

    self.FlowLinear = self:GetFlowLinear()
    self.FlowRadial = self:GetFlowRadial()

    self.FlowLinearWidth = self:GetFlowLinearWidth()
    self.FlowLinearLength = self:GetFlowLinearLength()
    self.FlowRadialDepth = self:GetFlowRadialDepth()
    self.FlowLookahead = self:GetFlowLookahead()
    self.FlowDistRadCurrent = self:GetFlowDistRadCurrent()
    self.FlowWindspeed = self:GetFlowWindspeed()
    self.FlowTemperatureCurrent = self:GetFlowTemperatureCurrent()

    self.Networked = self:GetNetworked()

    local particleRevision = self:GetParticleRevision()

    if self.GSFlowParticleRevision ~= particleRevision then
        self.GSFlowParticleRevision = particleRevision

        local packName = self:GetParticleProfile()
        if !packName or packName == "" then packName = gsDefaultPack end

        local selected = self.ParticleTypesSelected
        if !selected then
            selected = {}
            self.ParticleTypesSelected = selected
        end

        selected.pyroclasticflow = self:GetParticleIndexPyroclasticFlow()
        selected.sandstorm = self:GetParticleIndexSandstorm()

        self.ParticlePackName = packName
        self.HasSetParticleTypesSelected = false
    end
end

function ENT:SendEntityVariables()
    self:SetFlowLinearDirection(self.FlowLinearDirection)

    self:SetFlowLinear(self.FlowLinear)
    self:SetFlowRadial(self.FlowRadial)

    self:SetFlowLinearWidth(self.FlowLinearWidth)
    self:SetFlowLinearLength(self.FlowLinearLength)
    self:SetFlowRadialDepth(self.FlowRadialDepth)
    self:SetFlowLookahead(self.FlowLookahead)
    self:SetFlowDistRadCurrent(self.FlowDistRadCurrent)
    self:SetFlowWindspeed(self.FlowWindspeed)
    self:SetFlowTemperatureCurrent(self.FlowTemperatureCurrent)

    local c = GetConVar("gstorms_particle_texture")
    local cvarPack = (c and c:GetString()) or gsDefaultPack

    if cvarPack != self.ParticlePackName then
        self:GSInitParticleSelection(cvarPack, true)
    end

    local packName = self.ParticlePackName or cvarPack
    local selected = self.ParticleTypesSelected
    if !selected then
        selected = {}
        self.ParticleTypesSelected = selected
    end

    local v1 = selected.pyroclasticflow or 1
    local v2 = selected.sandstorm or 1

    if self.GSNetParticlePackName ~= packName or self.GSNetParticleSigA ~= v1 or self.GSNetParticleSigB ~= v2 then
        self.GSNetParticlePackName = packName
        self.GSNetParticleSigA = v1
        self.GSNetParticleSigB = v2

        self:SetParticleProfile(packName)
        self:SetParticleIndexPyroclasticFlow(v1)
        self:SetParticleIndexSandstorm(v2)

        local rev = (self.GSParticleRevision or 0) + 1
        self.GSParticleRevision = rev
        self:SetParticleRevision(rev)
    end

    if !self.Networked then
        self.Networked = true
        self:SetNetworked(self.Networked)
    end
end

function ENT:Think()

    if !self.EntSetup then self:SetupEntity() end

    if CLIENT then

        self:ReceiveEntityVariables()

    elseif SERVER then

        local ct = CurTime()
        local tickInterval = engine.TickInterval() * 5

        if !self.FlowSpawnTime then
            self.FlowSpawnTime = ct
            self.Position = self:GetPos()
        end

        if !self.FlowWindspeedMax then self.FlowWindspeedMax = self.FlowWindspeed end

        local elapsed = ct - self.FlowSpawnTime
        local lifeFrac = math.Clamp(elapsed / self.FlowLifetime, 0, 1)

        if elapsed >= self.FlowLifetime then self:Remove() return end

        self.FlowWindspeed = Lerp(lifeFrac^self.WindspeedFalloffExponent, self.FlowWindspeedMax, 0)
        self.FlowDistRadCurrent = (self.FlowWindspeedMax * gsMPHToHUPerSec) * (elapsed - ((elapsed * elapsed) / (2 * self.FlowLifetime)))
        self.FlowTemperatureCurrent = math.max(self.FlowTemperature * math.Clamp((1 - (elapsed / self.FlowTemperatureCoolingTime)), 0, 1), 0)

        self:SendEntityVariables()

        self:NextThink(ct + tickInterval)
        return true

    end

end