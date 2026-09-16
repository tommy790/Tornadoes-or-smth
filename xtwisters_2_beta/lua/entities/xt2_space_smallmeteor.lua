AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2explosionbase"

ENT.ExplosionSound = "explosions/explosion_large_b.mp3"
ENT.ExplosionParticle = "astral_smallmeteor_impact"
ENT.ExplosionParticleAirburst = "astral_smallmeteor_airburst"
ENT.ExplosionParticleAirburstGroundEffect = "nil"
ENT.ExplosionSoundDistance = 30000

ENT.ExplosionDamage = 1000
ENT.ExplosionDamageType = DMG_BLAST
ENT.ExplosionStrength = 100000
ENT.ExplosionRadius = 5000
ENT.ExplosionUnweld = true   

ENT.EvaporateRadius = 100
ENT.IncinerateRadius = 200
ENT.IgniteRadius =  500

ENT.AirburstHeightThreshold = 300
ENT.GroundShockwaveAirburstHeight = 0

ENT.NeedsArmed = false   
ENT.Armed = true  
ENT.Arming = false  
ENT.Exploded = false
ENT.ShockwaveProgressing = false

ENT.SecondaryShockwave = false 
ENT.SecondaryShockwaveRadius = 0 

ENT.MushroomSuction = false 
ENT.MushroomSuctionRadius = 0
ENT.MushroomSuctionWindspeed = 0

ENT.KillAfterShockwave = true  
ENT.IsProjectile = false 

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Meteor" 

ENT.Models = {"rockgranite03a", "rockgranite03b", "rockgranite03c", "rockgranite02a", "rockgranite02b", "rockgranite02c"}
ENT.TrailName = "astral_smallmeteor_entry"

function ENT:Initialize()
 
    if SERVER then

        
        self:SetModel("models/props_wasteland/"..table.Random(self.Models)..".mdl")
        self:SetMaterial("models/props_foliage/tree_deciduous_01a_trunk")
        self:SetColor( Color( 130, 130, 130, 255 ) )
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()

        if phys:IsValid() then
            phys:Wake()
            phys:SetMass(1000)
        end

        if self.IsProjectile == false then
            local canairburst = math.random(1,5)
            local airburstheight = util.TraceLine( { start = self:GetPos(), mask = MASK_SOLID_BRUSHONLY, endpos = self:GetPos() - Vector(0, 0, 6500) } )


            local MeteorImpArea = self:GetPos() 
            local startpos = util.TraceLine( { start = self:GetPos(), mask = MASK_SOLID_BRUSHONLY, endpos = self:GetPos() + Vector(math.random(-185000,185000), math.random(-185000,185000), 100000) } )

            self:SetPos( startpos.HitPos )

            local thing = math.random(1000000, 0)
            hook.Add( "Think", "MoveMeteor"..thing, function()
                if phys:IsValid() and self:IsValid() then
                    local MeteorDir = (self:GetPos() - MeteorImpArea) 
                    phys:SetAngleVelocity(Vector(255, 255, 255))
                    phys:SetVelocity(-MeteorDir*100)
                    if canairburst == 1 and math.random(1,200) == 1 and airburstheight.Hit then
                        self.ExplosionRadius = self.ExplosionRadius*1.5
                        self:Arm()
                        self:Explode()  
                    end
                else
                    hook.Remove( "Think", "MoveMeteor"..thing )
                end
            end )
        else

        end
    end
    if CLIENT then
        self.IncomingSound = CreateSound(self, Sound("misc/MeteorIncoming.wav"))
        self.IncomingSound:SetSoundLevel( 0 )
        self.IncomingSound:ChangeVolume( 1 )
        self.IncomingSound:ChangePitch(100)
        self.IncomingSound:Play()
    end
	ParticleEffectAttach(self.TrailName, PATTACH_ABSORIGIN_FOLLOW, self, 0)
end


function ENT:PhysicsCollide(data, physobj)
    self:Arm()
    self:Explode()  
end

function ENT:OnTakeDamage()
    if !self:GetPhysicsObject():IsValid() then return end
    if self.IsProjectile == false then
        self:Arm()
        self:Explode()   
    end  
end

function ENT:Use()
    if !self:GetPhysicsObject():IsValid() then return end
    --self:Arm()
    --self:Explode()   
end

function ENT:OnRemove()
    if CLIENT then
        if self.IncomingSound ~= nil then
            self.IncomingSound:Stop()
        end
    end
end