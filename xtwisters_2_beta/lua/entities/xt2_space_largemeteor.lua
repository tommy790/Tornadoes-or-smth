AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2explosionbase"

ENT.ExplosionSound = "ambient/explosions/explode_6.wav"
ENT.ExplosionSoundDistance = 0
ENT.ExplosionParticle = "astral_nuclearexplosion_shockwave"

ENT.ExplosionDamage = 1000
ENT.ExplosionDamageType = DMG_BLAST
ENT.ExplosionStrength = 100000
ENT.ExplosionRadius = 3000
ENT.ExplosionUnweld = true   

ENT.EvaporateRadius = 100
ENT.IncinerateRadius = 200
ENT.IgniteRadius =  500

ENT.NeedsArmed = false   
ENT.Armed = false  
ENT.Arming = false  
ENT.Exploded = false
ENT.ShockwaveProgressing = false

ENT.SecondaryShockwave = false  
ENT.SecondaryShockwaveRadius = 0 

ENT.MushroomSuction = false  
ENT.MushroomSuctionRadius = 3000
ENT.MushroomSuctionWindspeed = 300

ENT.ShockwaveCurrentRadius = 0
ENT.ShockwaveIncrement = 13
ENT.ShockwaveDelay = 0.01

ENT.KillAfterShockwave = true   

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Colossal meteor" 

function ENT:Initialize()
 
    if SERVER then
        self:SetModel("models/props_wasteland/rockgranite04c.mdl")
        self:SetMaterial("models/props_foliage/tree_deciduous_01a_trunk")
        self:SetColor( Color( 130, 130, 130, 255 ) )
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        local MeteorImpArea = self:GetPos() 
        local startpos = util.TraceLine( { start = self:GetPos(), mask = MASK_SOLID_BRUSHONLY, endpos = self:GetPos() + Vector(math.random(-185000,185000), math.random(-185000,185000), 100000) } )

        self:SetPos( startpos.HitPos )

        if phys:IsValid() then
            phys:Wake()
            phys:SetMass(10000)
        end

        local thing = math.random(1000000, 0)
        hook.Add( "Think", "MoveMeteor"..thing, function()
            if phys:IsValid() and self:IsValid() then
                local MeteorDir = (self:GetPos() - MeteorImpArea) 
                phys:SetAngleVelocity(Vector(255, 255, 255))
                phys:AddVelocity(-MeteorDir)
            else
                hook.Remove( "Think", "MoveMeteor"..thing )
            end
        end )

    end
	--	ParticleEffectAttach("fire_large_01",PATTACH_ABSORIGIN_FOLLOW,self,0)
end


function ENT:PhysicsCollide(data, physobj)
    if data.Speed > 500 then
        self:Arm()
        self:Explode()  
    end
end

function ENT:OnTakeDamage()
    if !self:GetPhysicsObject():IsValid() then return end
    self:Arm()
    self:Explode()   
end

function ENT:Use()
    if !self:GetPhysicsObject():IsValid() then return end
    self:Arm()
    self:Explode()   
end

