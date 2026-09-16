AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2explosionbase"

ENT.ExplosionSound = "ambient/explosions/explode_6.wav"
ENT.ExplosionParticle = "astral_nuclearexplosion"
ENT.ExplosionParticleAirburst = "astral_nuclearexplosionairburst"
ENT.ExplosionParticleAirburstGroundEffect = "astral_nuclearexplosionairburst_shockwaveground"
ENT.ExplosionSoundDistance = 40000

ENT.ExplosionDamage = 1000
ENT.ExplosionDamageType = DMG_BLAST
ENT.ExplosionStrength = 100000
ENT.ExplosionRadius = 25000
ENT.ExplosionUnweld = true   

ENT.EvaporateRadius = 3000
ENT.IncinerateRadius = 7000
ENT.IgniteRadius =  15000

ENT.AirburstHeightThreshold = 2000
ENT.GroundShockwaveAirburstHeight = 16000

ENT.NeedsArmed = true   
ENT.Armed = false  
ENT.Arming = false  
ENT.Exploded = false
ENT.ShockwaveProgressing = false

ENT.SecondaryShockwave = true  
ENT.SecondaryShockwaveRadius = 0 

ENT.MushroomSuction = true  
ENT.MushroomSuctionRadius = 3000
ENT.MushroomSuctionWindspeed = 300

ENT.ShockwaveCurrentRadius = 0
ENT.ShockwaveIncrement = 13
ENT.ShockwaveDelay = 0.01

ENT.KillAfterShockwave = false   

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Nuclear Bomb" 

function ENT:Initialize()
 
    if SERVER then
        self:SetModel("models/props_phx/mk-82.mdl")
        self:SetMaterial("phoenix_storms/dome")
        self:SetColor( Color( 30, 30, 30, 255 ) )
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
    
        if phys:IsValid() then
            phys:Wake()
            phys:SetMass(700)
        end
    end
	--	ParticleEffectAttach("fire_large_01",PATTACH_ABSORIGIN_FOLLOW,self,0)
end


function ENT:PhysicsCollide(data, physobj)
    if data.Speed > 500 then
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

function ENT:OnRemove() -- Blank logic for on remove do whatever u guys want

end



