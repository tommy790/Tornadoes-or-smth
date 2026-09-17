AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Lightning Strike" 
 
ENT.Spawnable = false

ENT.ShockwaveCurrentRadius = 0
ENT.ShockwaveIncrement = 13
ENT.ShockwaveDelay = 0.01
ENT.ShockwaveProgressing = false
ENT.soundtriggered = false 

function clamp(value, mi, ma) if value < mi then value = mi end if value > ma then value = ma end return value end
function rnd(mi, ma) return math.random(1000) / 1000 * (ma - mi) + mi end

function ENT:Initialize()
    if SERVER then

        self.ShockwaveProgressing = true 
        self.striked = false 

        if !util.IsInWorld( self:GetPos() ) then
            self:Remove()
        end
    
        self:SetModel("models/props_junk/popcan01a.mdl")
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetColor( Color( 0, 0, 0, 0 ) )
        self:SetRenderMode( RENDERMODE_TRANSALPHA )
        self:SetMoveType( MOVETYPE_FLY )
        self:SetSolid( SOLID_NONE )

        local dontgoonblue = util.TraceLine( { start = self:GetPos(), endpos = self:GetPos() + Vector(0, 0, -100000) } )
        self:SetPos( dontgoonblue.HitPos )
        local phys = self:GetPhysicsObject()
    
        if phys:IsValid() then
            phys:Wake()
        end
    end
	
end

function ENT:Setup()
    local dontgoonblue = util.TraceLine( { start = self:GetPos(), endpos = self:GetPos() + Vector(0, 0, -100000) } )
    self:SetPos( dontgoonblue.HitPos )
end

function ENT:Think()
    local pos = self:GetPos()
    
    self.ShockwaveCurrentRadius = self.ShockwaveCurrentRadius+(self.ShockwaveIncrement*10)

    self:SetNWFloat("CurrentShockwaveRadius", self.ShockwaveCurrentRadius)

    if SERVER then
    
        local entities = ents.FindInSphere(self:GetPos(), 260)
        
        if self.striked == false then
            PrecacheParticleSystem("lightning_x2")
            ParticleEffect( "lightning_x2", self:GetPos(), Angle(math.random(40,-40), math.random(360,-360), 0 ) )

            for _, ent in ipairs(entities) do
            
                local phys = ent:GetPhysicsObject()
                local dist = math.Clamp((self:GetPos() - ent:GetPos()):Length(), 0, 1500)
        
                if phys and phys:IsValid() then
                    constraint.RemoveAll(ent) phys:Wake() phys:EnableMotion(true)  
                    
                    if math.random(1,10) == 1 then
                        ent:Ignite(10) 
                    end
        
                    local phys = ent:GetPhysicsObject()
        
                    local force = (ent:GetPos() - self:GetPos()):GetNormalized() * 1000 
        
                    if phys:IsValid() then
        
                        phys:AddVelocity(force)
        
                    end
        
                    local dmg = DamageInfo()
        
                    function TakeDamage( victim, damage, attacker, inflictor )
                        dmg:SetDamage( damage )
                        dmg:SetAttacker( attacker )
                        dmg:SetInflictor( inflictor )
                        dmg:SetDamageType( DMG_SHOCK )
                        victim:TakeDamageInfo( dmg )
                    end     
                    TakeDamage(ent, math.random(60,700) * (1.2 - dist/260), self, self )
        
                    if ent:IsPlayer() or ent:IsNPC() then
        
                            ents.GetAll()
                            local ents = ent:GetPos()
                            local force2 = (ent:GetPos() - self:GetPos()):GetNormalized() * 3400
                            ent:SetVelocity(force2) 
        
                    end
                end
            end

            self.striked = true  
        end

        if self.ShockwaveCurrentRadius >= 40000 then
            self.ShockwaveProgressing = false
            self.ShockwaveCurrentRadius = 0
            if !self:IsValid() then return end
            self:Remove()
        end
        
    end

    if CLIENT then
        local shockwaveRadi = self:GetNWFloat("CurrentShockwaveRadius", 0)
        local entities = ents.FindInSphere(self:GetPos(), shockwaveRadi, 0)

        for _, ent in ipairs(entities) do
            local dist = math.Clamp((self:GetPos() - ent:GetPos()):Length(), 0, 1000000)
            if self.soundtriggered == false and ent == LocalPlayer() then
                LocalPlayer():EmitSound("weather/ENVShared/Thunder/t" .. math.random(1,8) .. ".wav", 100000, 100 * math.random(80, 105) / 100, 1 * (1.0 - dist/50000))
                LocalPlayer():EmitSound(Sound("Explosions/cell_tower_explosion_0".. math.random(1,3) ..".mp3"), 100000, 100, 1 * (1.0 - dist/5000))
                self.soundtriggered = true      
            end
        end
    end

    self:NextThink(CurTime() + (self.ShockwaveDelay))
end





