ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Volcano"
ENT.Spawnable = false

ENT.ParticleName = "Volcanic_Explosion_1"

ENT.Yield = 1000 -- tons of TNT
ENT.ChargeSize = 6000 -- Hammer Units (reference radius for PeakOverpressure)
ENT.PeakOverpressure = 15 -- psi at ChargeSize (effective epicenter)
ENT.PressureFalloff = 3 -- exponent for overpressure falloff

ENT.ShockwaveSpeed = 10000 -- HU/s, Think runs every tick * 4
ENT.ShockwaveRadius = 100000 -- max radius shockwave should reach

ENT.PositivePhaseDuration = 1 -- seconds (outward push after arrival)
ENT.NegativePhaseDuration = 0.5 -- seconds (inward suction after positive phase)
ENT.NegativePhaseMultiplier = 0.25 -- Negative Phase Strength Multiplier

ENT.FireballTemperature = 1200 -- °C at FireballSize
ENT.FireballTemperatureFalloff = 1.25 -- exponent for temperature distance falloff
ENT.FireballSize = 1750 -- HU
ENT.FireballCoolingTime = 4 -- seconds

ENT.EmissionHeight = 3250 -- Hammer Units
ENT.BurnHeight = 3750
ENT.BurnRadius = 1750
ENT.RockList = {}

local rockModelList = {"models/props_mining/rock_caves01a.mdl", "models/props_mining/rock_caves01.mdl", "models/props_foliage/rock_forest01.mdl", "models/props_wasteland/rockgranite03a.mdl", "models/props_wasteland/rockgranite02c.mdl"}

function ENT:CreateRocks()
    if !GetConVar("gstorms_volcano_rock_ejection"):GetBool() then return end

    local pos = self:GetPos()
    local emissionHeight = self.EmissionHeight
    local lstLen = #rockModelList

    for i = 1, 100 do
        local ent = ents.Create("prop_physics")
        local phys = ent:GetPhysicsObject()

        ent:SetModel(rockModelList[math.random(lstLen)])
        ent:SetPos(pos + Vector(math.random(-500, 500), math.random(-500, 500), math.random(emissionHeight, 1000) + 1000))
        ent:Spawn()
        ent:Activate()

        if phys:IsValid() then phys:SetMass(math.random(5000, 10000)) end

        table.insert(self.RockList, ent)
    end
end

function ENT:Explode()
    if !GetConVar("gstorms_volcano_eruptions"):GetBool() then return end

    if #self.RockList > 0 then
        for _, rock in ipairs(self.RockList) do 
            if !rock:IsValid() then continue end
            rock:Remove()
        end
    end

    local ent = ents.Create("gstorms_base_explosion")
    if !ent:IsValid() then return end

    ent:SetPos(self:GetPos() + Vector(0, 0, self.EmissionHeight))
    ent:Activate()
    ent:Spawn()

    self:CreateRocks()

    timer.Simple(9, function()

        if !GetConVar("gstorms_volcano_pyroclastic_flow"):GetBool() or !self:IsValid() then return end

        local ent = ents.Create("gstorms_weather_pyroclastic_flow")
        if !ent:IsValid() then return end

        ent:SetPos(self:GetPos() + Vector(0, 0, self.EmissionHeight))
        ent:Activate()
        ent:Spawn()

    end)
end

local modelScale = 75

function ENT:Initialize()

    self:SetPos(self:GetPos())
    self:SetModel("models/props/de_inferno/de_inferno_boulder_03.mdl")
    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
    self:SetModelScale(modelScale, 0)

    local mins, maxs = self:OBBMins(), self:OBBMaxs()

    self:PhysicsInitBox(mins, maxs)
    self:SetCollisionBounds(mins, maxs)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)

    if SERVER then
        timer.Simple(0.5, function()
            if !self:IsValid() then return end
            ParticleEffect("Volcano_Smoke_Emission_1", self:GetPos() + Vector(0, 0, self.EmissionHeight), Angle(0, 0, 0), self)
        end)
    end
end

local sndPlayTime = 14.6

function ENT:Think()

    if CLIENT and (!self.LastSoundPlayTime or CurTime() - self.LastSoundPlayTime >= sndPlayTime) then

        self:EmitSound("explosion/volcano_ambient_noise.wav", 100, 100, 1, CHAN_STATIC)

        self.LastSoundPlayTime = CurTime()

    end

    if CLIENT or !self:IsValid() then return end

    self.CurTime = CurTime()
    self.LastExplosionTime = self.LastExplosionTime or self.CurTime
    self.ExplosionTime = !self.ExplosionTime and math.random(!self.InitiallyExploded and 20 or 120, !self.InitiallyExploded and 40 or 360) or self.ExplosionTime

    if self.ExplosionTime and !self.PlayedRumble and self.CurTime - self.LastExplosionTime >= self.ExplosionTime - 13.5 then

        GSEmitSoundAtAllPlayers(self:GetPos(), 60000, 75, 5, 100, "explosion/volcanic_rumble.wav")

        self.PlayedRumble = true

    end

    if self.ExplosionTime and self.CurTime - self.LastExplosionTime >= self.ExplosionTime then

        self:Explode()
        self:StopParticles()

        self.LastExplosionTime = nil
        self.ExplosionTime = nil
        self.InitiallyExploded = true
        self.PlayedRumble = false

        timer.Simple(40, function()
            if !self:IsValid() then return end
            ParticleEffect("Volcano_Smoke_Emission_1", self:GetPos() + Vector(0, 0, self.EmissionHeight), Angle(0, 0, 0), self)
        end)

    end

    if #self.RockList ~= 0 and math.random(5) == 1 then

        local ent = self.RockList[math.random(#self.RockList)]

        if !ent:IsValid() then return end

        ent:Remove()

    end

    self.BurnPos = self:GetPos() + Vector(0, 0, self.BurnHeight)

    local hurtPlayerCvar = GetConVar("gstorms_sim_hurt_players"):GetBool()

    for _, prop in ipairs(ents.FindInSphere(self.BurnPos, self.BurnRadius)) do
        local dist = self.BurnPos:Distance(prop:GetPos())
        local temperature = 400 * math.Clamp(1 - (dist / self.BurnRadius), 0, 1) ^ 3

        GSTemperatureHandler(prop, temperature, self, (prop:IsPlayer() or prop:IsNPC()), hurtPlayerCvar)

        if prop.IsThermometer then

            local volcanoTemps = prop.VolcanoTemperatureSources
        
            if !volcanoTemps then
                volcanoTemps = {}
                prop.VolcanoTemperatureSources = volcanoTemps
            end
        
            volcanoTemps[self:EntIndex()] = {temperature = temperature, expire = self.CurTime + (engine.TickInterval() * 5)}
        
        end
    end

    self:NextThink(self.CurTime + (engine.TickInterval() * 2))
    return true

end

function ENT:OnRemove()
    if SERVER then
        if #self.RockList >= 1 then
            for _, rock in ipairs(self.RockList) do
                if !rock:IsValid() then continue end 
                rock:Remove()
            end
        end
    else
        self:StopSound("explosion/volcano_ambient_noise.wav")
        self:StopSound("explosion/volcanic_rumble.wav")
    end
end

function ENT:PhysgunPickup(ply) return false end