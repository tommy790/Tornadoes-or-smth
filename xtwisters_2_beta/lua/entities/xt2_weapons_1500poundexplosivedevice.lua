AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2explosionbase"

ENT.ExplosionSound = "explosions/explosion_light_j.mp3"
ENT.ExplosionParticle = "RDTEXP_1500Pound"
ENT.ExplosionParticleAirburst = "RDTEXP_1500PoundAirburst"
ENT.ExplosionParticleAirburstGroundEffect = "RDTEXP_1500PoundAirburstBottom"
ENT.ExplosionSoundDistance = 30000

ENT.ExplosionDamage = 1000
ENT.ExplosionDamageType = DMG_BLAST
ENT.ExplosionStrength = 10000
ENT.ExplosionRadius = 4000
ENT.ExplosionUnweld = true   

ENT.EvaporateRadius = 0
ENT.IncinerateRadius = 10
ENT.IgniteRadius =  0

ENT.AirburstHeightThreshold = 30
ENT.GroundShockwaveAirburstHeight = 1000

ENT.NeedsArmed = true    
ENT.Armed = false   
ENT.Arming = false  
ENT.Exploded = false
ENT.ShockwaveProgressing = false

ENT.SecondaryShockwave = false 
ENT.SecondaryShockwaveRadius = 0 

ENT.MushroomSuction = false 
ENT.MushroomSuctionRadius = 0
ENT.MushroomSuctionWindspeed = 0

ENT.KillAfterShockwave = true  

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "1500 Pound Explosive" 

function ENT:Initialize()
 
    if SERVER then
        self:SetModel("models/props_phx/ww2bomb.mdl")
        self:GetMaterial("")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
    
        local phys = self:GetPhysicsObject()
    
        if phys:IsValid() then
            phys:Wake()
            phys:SetMass(680.39)
        end
    end
	--	ParticleEffectAttach("fire_large_01",PATTACH_ABSORIGIN_FOLLOW,self,0)
end


function ENT:PhysicsCollide(data, physobj)
    if data.Speed > 500 then
        self:EmitSound("weapons/rpg/shotdown.wav")
        self:Arm()
        self:Explode()  
    end
end

function ENT:PhysicsCollide(data, physobj)
    if data.Speed > 200 then
        if self.Armed or self.Arming == false then
            self:EmitSound("weapons/rpg/shotdown.wav")
        end
        self:Arm()
        self:Explode()  
    end
end

function ENT:OnTakeDamage()
    if !self:GetPhysicsObject():IsValid() then return end
    self:EmitSound("weapons/rpg/shotdown.wav")
    self:Arm()
    self:Explode()   
end

function ENT:Use()
    if !self:GetPhysicsObject():IsValid() then return end
    self:Arm()
    self:Explode()   
end

