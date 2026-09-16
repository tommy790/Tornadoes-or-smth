AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.ExplosionSound = ""
ENT.IncomingSound = nil
ENT.ExplosionParticle = ""
ENT.ExplosionParticleAirburst = ""
ENT.ExplosionParticleAirburstGroundEffect = ""
ENT.ExplosionSoundDistance = 0

ENT.ExplosionDamage = 0
ENT.ExplosionDamageType = DMG_BLAST
ENT.ExplosionStrength = 0
ENT.ExplosionRadius = 0
ENT.ExplosionUnweld = true   

ENT.EvaporateRadius = 0
ENT.IncinerateRadius = 0
ENT.IgniteRadius =  0

ENT.AirburstHeightThreshold = 0
ENT.GroundShockwaveAirburstHeight = 0

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

ENT.ShockwaveCurrentRadius = 0
ENT.ShockwaveIncrement = 13
ENT.ShockwaveDelay = 0.01

ENT.KillAfterShockwave = true  

ENT.AirburstEmit = false   

ENT.soundtriggered = false 

function ENT:Initialize()

    self.MushroomSuctionWindspeed = self.MushroomSuctionWindspeed*0.1

 	if (SERVER) then
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetUseType( ONOFF_USE ) 
		local phys = self:GetPhysicsObject()
		if (phys:IsValid()) then
			phys:SetMass(self.Mass)
			phys:Wake()
		end
	end


    if (CLIENT) then
    end
end

function ENT:Arm()
    if SERVER then
        if !self:IsValid() then return end
        
        if self.NeedsArmed == false then
            self.Armed = true 
        else 
            if self.Armed == false and self.Arming == false and self.Exploded == false and self:IsValid() then
                self:EmitSound("buttons/button14.wav", 100)
                self.Arming = true  
                timer.Simple(1, function()
                    self.Armed = true 
                    if self:IsValid() then
                        self:EmitSound("npc/roller/mine/rmine_blip3.wav", 100)
                    end
                end)
            end	 
        end
    end
end 

function ENT:Explode()

    if !self:IsValid() then return end
    

    if self.Armed == true and self.Exploded == false then
        self:StopParticles()
        --print("Detonation.")
        self.Exploded = true 
        self.ShockwaveProgressing = true

        local pos = self:LocalToWorld(self:OBBCenter())
        local entities = ents.FindInSphere(self:GetPos(), self.ExplosionRadius)
        local cls = ents.FindInSphere(self:GetPos(), self.ExplosionRadius)

        if SERVER then

            for _, ent in ipairs(entities) do
                if ent:IsValid() and ent != self and not (ent:GetClass() == "gmod_ghost") and !ent:IsWorld() and !ent:IsWeapon() and not (ent:GetClass() == "sent_anim") then

                    local phys = ent:GetPhysicsObject()
                    local dist = math.Clamp((self:GetPos() - ent:GetPos()):Length(), 0, self.ExplosionRadius)
            
                    if dist <= math.Clamp(1500, 0, self.ExplosionRadius) and self.ShockwaveProgressing == true then
                        if ent:IsValid() and ent != self and not (ent:GetClass() == "gmod_ghost") and !ent:IsWorld() and !ent:IsWeapon() and not (ent:GetClass() == "sent_anim") then
                            if phys and phys:IsValid() then
    
                                local phys = ent:GetPhysicsObject()
                                local force = (ent:GetPos()+Vector(0,0,100) - self:GetPos()):GetNormalized() * self.ExplosionStrength * (1.0 - dist/self.ExplosionRadius)
    
                                if dist <= self.IncinerateRadius then
                                    force = force * 10
                                end
    
                                if phys:IsValid() then
                                    phys:SetVelocity(force)
                                end
                    
                                local dmg = DamageInfo()
                    
                                local function TakeDamage( victim, damage, attacker, inflictor )
                                    dmg:SetDamage( damage )
                                    dmg:SetAttacker( attacker )
                                    dmg:SetInflictor( inflictor )
                                    dmg:SetDamageType( DMG_BLAST )
                                    victim:TakeDamageInfo( dmg )
                                end     
                    

                                local isRagdoll = ent:IsRagdoll()
                                if self.ExplosionUnweld == true and !ent:IsPlayer() and !isRagdoll == true and !ent:IsVehicle() then
                                    if ( constraint.HasConstraints( ent )) then			
                                        if math.random(1,2 * (0.0 + dist/self.ExplosionRadius)) == 1 then --or dist <= self.ExplosionRadius*0.5 then
                                            ent:EmitSound("break" .. math.random(1, 4) .. ".mp3", 100)
                                            constraint.RemoveAll(ent)
                                        end
                                    end
                                    if !phys:IsMotionEnabled() then
                                        phys:Wake()
                                        phys:EnableMotion(true) 
                                    end   
                                end
    
    
                                if ent:IsPlayer() or ent:IsNPC() then
                                    local force2 = (ent:GetPos() - self:GetPos()):GetNormalized() * self.ExplosionStrength * (1.0 - dist/self.ExplosionRadius)
                                    ent:SetVelocity(force2) 
                                    TakeDamage(ent, math.Clamp(self.ExplosionDamage, 0, 200) * (1.0 - dist/(self.ExplosionRadius)), self, self )
                                else
                                    TakeDamage(ent, self.ExplosionDamage * (1.0 - dist/(self.ExplosionRadius)), self, self )     
                                end
                            end
                        end
                    end

                    if dist <= self.IgniteRadius then
                        ent:Ignite(math.random(3,15),math.random(1,10))
                    end
            
                    if dist <= self.IncinerateRadius then

                        local dmg = DamageInfo()

                        local function TakeDamage( victim, damage, attacker, inflictor )
                            dmg:SetDamage( damage )
                            dmg:SetAttacker( attacker )
                            dmg:SetInflictor( inflictor )
                            dmg:SetDamageType( DMG_BURN )
                            victim:TakeDamageInfo( dmg )
                        end    

                        if ent:IsPlayer() or ent:IsNPC() then
                            ent:SetModel("models/Humans/Charple04.mdl")
                            ParticleEffectAttach("astral_nuclearexplosion_playervaporized",4,ent,0) 
                            TakeDamage(ent, self.ExplosionDamage * (1.0 - dist/self.IncinerateRadius), self, self ) --Hurt stuff

                        end
            
                        if math.random(1,2 * (0.0 + dist/self.ExplosionRadius)) == 1 or dist <= self.IncinerateRadius * 0.5 then
                            if !ent:IsPlayer() then
                                ent:SetColor(Color(30,30,30,255))
                                ent:SetMaterial("models/props_foliage/tree_deciduous_01a_trunk")
                            end
                        end
                    end
        
                    if dist <= self.EvaporateRadius then
                        if !ent:IsPlayer() then
                            ent:Remove()
                        else
                            ent:Kill()
                        end
                    end
                end
            end

            local tr = util.TraceLine( {
                start = self:GetPos() + Vector(0,0,0),
                endpos = self:GetPos() - Vector(0,0,self.AirburstHeightThreshold),
                mask   = MASK_WATER + MASK_SOLID_BRUSHONLY
            } )

            if tr.Hit then
                ParticleEffect( self.ExplosionParticle, tr.HitPos, Angle( 0, 0, 0 ) )  
            else
                ParticleEffect( self.ExplosionParticleAirburst, self:GetPos(), Angle( 0, 0, 0 ) )  
                self.Airburst = true 
            end

            self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
            self:SetColor( Color( 0, 0, 0, 0 ) )
            self:SetRenderMode( RENDERMODE_NONE )
            self:SetMoveType( MOVETYPE_FLY )
            self:SetSolid( SOLID_NONE )
            self:DrawShadow(false)
        end
    end
end

function ENT:Think()

    if self.Exploded == true then
        local pos = self:GetPos()
        self.ShockwaveCurrentRadius = self.ShockwaveCurrentRadius+(self.ShockwaveIncrement*10)

        self:SetNWFloat("CurrentShockwaveRadius", self.ShockwaveCurrentRadius)

        local entities = ents.FindInSphere(self:GetPos(), self.ExplosionRadius)

        if SERVER then

            if self.Airburst == true then

                local tr = util.TraceLine( {
                    start = self:GetPos(),
                    endpos = self:GetPos() - Vector(0,0,self.ShockwaveCurrentRadius),
                    mask   = MASK_WATER + MASK_SOLID_BRUSHONLY
                } )
    
                if tr.Hit and self.ShockwaveCurrentRadius <= self.GroundShockwaveAirburstHeight and self.AirburstEmit == false then
                    self.AirburstEmit = true 
                    self.Airburst = false  
                    ParticleEffect( self.ExplosionParticleAirburstGroundEffect, tr.HitPos, Angle( 0, 0, 0 ) )  
                end
            end

            if self.ShockwaveCurrentRadius >= 40000 then
                self.ShockwaveProgressing = false
                self.ShockwaveCurrentRadius = 0
                --print("stopped")
                if self.KillAfterShockwave == true then
                    if !self:IsValid() then return end
                    self:Remove()
                end
            end
            
            for _, ent in ipairs(entities) do
            
                local phys = ent:GetPhysicsObject()
                local dist = (pos - ent:GetPos()):Length()
        
                if dist >= self.ShockwaveCurrentRadius-(self.ShockwaveIncrement) and dist <= self.ShockwaveCurrentRadius+(self.ShockwaveIncrement*2) and self.ShockwaveProgressing == true then
                    if ent:IsValid() and ent != self and not (ent:GetClass() == "gmod_ghost") and !ent:IsWorld() and !ent:IsWeapon() and not (ent:GetClass() == "sent_anim") then
                        if phys and phys:IsValid() then

                            local phys = ent:GetPhysicsObject()
                            local force = (ent:GetPos()+Vector(0,0,100) - self:GetPos()):GetNormalized() * self.ExplosionStrength * (1.0 - dist/self.ExplosionRadius)

                            if dist <= self.IncinerateRadius then
                                force = force * 10
                            end

                            if phys:IsValid() then
                                phys:SetVelocity(force)
                            end
                
                            local dmg = DamageInfo()
                
                            local function TakeDamage( victim, damage, attacker, inflictor )
                                dmg:SetDamage( damage )
                                dmg:SetAttacker( attacker )
                                dmg:SetInflictor( inflictor )
                                dmg:SetDamageType( DMG_BLAST )
                                victim:TakeDamageInfo( dmg )
                            end     
                
                            if self.ExplosionUnweld == true then
                                if ( constraint.HasConstraints( ent )) then			
                                    if math.random(1,2 * (0.0 + dist/self.ExplosionRadius)) == 1 then --or dist <= self.ExplosionRadius*0.5 then
                                        ent:EmitSound("break" .. math.random(1, 4) .. ".mp3", 100)
                                        constraint.RemoveAll(ent)
                                    end
                                end
                                if !phys:IsMotionEnabled() then
                                    phys:Wake()
                                    phys:EnableMotion(true) 
                                end   
                            end


                            if ent:IsPlayer() or ent:IsNPC() then
                                local force2 = (ent:GetPos() - self:GetPos()):GetNormalized() * self.ExplosionStrength * (1.0 - dist/self.ExplosionRadius)
                                ent:SetVelocity(force2) 
                                TakeDamage(ent, math.Clamp(self.ExplosionDamage, 0, 200) * (1.0 - dist/(self.ExplosionRadius*0.5)), self, self )
                                --print("detected player")
                                --print(math.Clamp(self.ExplosionDamage, 0, 200) * (1.0 - dist/(self.ExplosionRadius*0.5)))
                            else
                                TakeDamage(ent, self.ExplosionDamage * (1.0 - dist/(self.ExplosionRadius*0.5)), self, self )     
                            end
                        end
                    end
                end

                if self.SecondaryShockwave == true and dist >= self.ShockwaveCurrentRadius-(self.ShockwaveIncrement*6) and dist <= self.ShockwaveCurrentRadius-(self.ShockwaveIncrement*5) and self.ShockwaveProgressing == true then
                    if phys and phys:IsValid() then

                        local phys = ent:GetPhysicsObject()
                        local force = (ent:GetPos() - self:GetPos()):GetNormalized() * -self.ExplosionStrength*4 * (1.0 - dist/self.ExplosionRadius)
            
                        if phys:IsValid() then
                            phys:AddVelocity(force)
                        end
            
                        if ent:IsPlayer() or ent:IsNPC() then
                            local force2 = (ent:GetPos() - self:GetPos()):GetNormalized() * -self.ExplosionStrength*0.9
                            ent:SetVelocity(force2) 
                        end
                    end
                end
            end

            if self.MushroomSuction then
                local e = ents.FindInSphere(self:GetPos() + Vector(0, 0, rnd(10000,0)), self.MushroomSuctionRadius )
                self.MushroomSuctionWindspeed = clamp(self.MushroomSuctionWindspeed - 0.15, 0, math.huge)
                for i = 1 , #e do
                    local v = e[i]
                    
                    if v:IsValid() and v != self and not (v:GetClass() == "gmod_ghost") and !v:IsWorld() and !v:IsWeapon() and not (v:GetClass() == "sent_anim") then
                        local physobj = v:GetPhysicsObject()
                        if physobj:IsValid() then
                            
                            local dist = clamp((self:GetPos() - v:GetPos()):Length(), 0, math.huge)

                            if dist <= self.ShockwaveCurrentRadius then

                                local origin = self:GetPos()
                                local vorigin = v:GetPos() 					
                                local Pull = (self:GetPos() - v:GetPos())
                                Pull:Normalize()
                                local Pull2 = (self:GetPos() - v:GetPos())
                                Pull2:Normalize()
                                local Length = Vector(Pull2.x,Pull2.y,0):Length()

                                Pull = Vector(Pull.x, Pull.y, -0.0000125)

                                Pull = Pull * ( (1-(Length/self.MushroomSuctionRadius))^3.3 ) --3.3
                                local force = Pull * (34000*(1^(self.MushroomSuctionWindspeed*0.015385^1.425))) * (0.05+(5*0.2)) * (self.MushroomSuctionWindspeed*0.015385*0.5) * (1.0 - dist/self.MushroomSuctionRadius)
                                local force2 = Pull * (34000*(1^(self.MushroomSuctionWindspeed*0.015385^1.425))) * (0.05+(5*0.2)) * (self.MushroomSuctionWindspeed*0.015385*0.5) * (1.0 - dist/self.MushroomSuctionRadius)  

                                local force3 = (((force*0.35) + (force2*0.45))) * (1.0 - dist/self.MushroomSuctionRadius) 
                                mass = 50 + physobj:GetMass()*0.1 * physobj:GetMass()*0.05 / self.MushroomSuctionWindspeed

                                local gMul = 1 * clamp(self.MushroomSuctionWindspeed*0.01, 1, 8+mass) 
                                if v:IsOnGround() and !v:IsPlayer() then
                                    mass = mass * 0.2
                                    gMul = 8.33 * (1.0 - dist/self.MushroomSuctionRadius) 
                                elseif  v:IsOnGround() and v:IsPlayer() then
                                    gMul = 3.33 * (1.0 - dist/self.MushroomSuctionRadius) 
                                end

                                local isRagdoll = v:IsRagdoll()
                                if isRagdoll == true then
                                    local phys = v:GetPhysicsObject()
                                    if IsValid(phys) then
                                        gMul = 10.33 * (1.0 - dist/self.MushroomSuctionRadius) 
                                        phys:ApplyForceCenter( Vector(clamp((force3.x/2)/mass,-150,150),clamp((force3.y/2)/mass,-150,150),clamp((force3.z/2)/mass,-150,150)) * gMul * (1.0 - dist/self.MushroomSuctionRadius) )
                                    end
                                end
                                if v:IsVehicle() then
                                    gMul = 10.33 * (1.0 - dist/self.MushroomSuctionRadius) 
                                end
                                
                                if v:GetMoveType() != MOVETYPE_NOCLIP and (v:IsPlayer() or v:IsNPC()) and v:IsValid() then
                                    if v.AddVelocity then
                                        v:AddVelocity( Vector(clamp((force3.x/2)/mass,-150,150),clamp((force3.y/2)/mass,-150,150),clamp((force3.z/2 * (1.0 - rnd(6000,10000)) )/mass ,-150,150)) * gMul * (1.0 - dist/self.MushroomSuctionRadius))
                                    else
                                        v:SetVelocity( Vector(clamp((force3.x/2)/mass,-150,150),clamp((force3.y/2)/mass,-150,150),clamp((force3.z/2 * (1.0 - rnd(6000,10000)) )/mass ,-150,150)) * gMul * (1.0 - dist/self.MushroomSuctionRadius))
                                    end					
                                end

                                if (v:IsPlayer() and v:InVehicle()) or v:IsVehicle() then 
                                    else
                                    if !v:IsPlayer() and !isRagdoll == true and !v:IsVehicle()  then
                                        if dist <= self.MushroomSuctionRadius * 0.7 then 
                                            if math.random(1, clamp(4000 * (0.0 + dist/self.MushroomSuctionRadius), 1, math.huge)) == 1 then
                                                local p = v:GetPhysicsObject()	
                                                if p:IsValid() then 
                                                    
                                                if ( constraint.HasConstraints( v )) and !v:IsVehicle() and !p:IsMotionEnabled() then			
                                                    v:EmitSound("break" .. math.random(1, 4) .. ".mp3", 100)
                                                    constraint.RemoveAll(v)
                                                end

                                                if !p:IsMotionEnabled() then
                                                    p:Wake()
                                                    p:EnableMotion(true) 
                                                end   
                                            end
                                        end 
                                    end
                                end
                            
                                    if physobj:IsValid() then 
                                        physobj:AddVelocity(Vector(clamp(force3.x/mass,-500,500), clamp(force3.y/mass,-500,500), clamp(force3.z/2 * (1.0 - rnd(8000,10000))/mass * gMul, -500,500))  )
                                    end		
                                end
                            end		
                        end
                    end
                end

                local e2 = ents.FindInSphere(self:GetPos() + Vector(0, 0, rnd(10000,0)), self.ExplosionRadius )
                for i = 1 , #e2 do
                    local v = e2[i]
                    
                    if v:IsValid() and v != self and not (v:GetClass() == "gmod_ghost") and !v:IsWorld() and !v:IsWeapon() and not (v:GetClass() == "sent_anim") then
                        local physobj = v:GetPhysicsObject()
                        if physobj:IsValid() then
                            
                            local dist = clamp((self:GetPos() - v:GetPos()):Length(), 0, math.huge)

                            if dist <= self.ShockwaveCurrentRadius then

                                local origin = self:GetPos()
                                local vorigin = v:GetPos() 					
                                local Pull = (self:GetPos() - v:GetPos())
                                Pull:Normalize()
                                local Pull2 = (self:GetPos() - v:GetPos())
                                Pull2:Normalize()
                                local Length = Vector(Pull2.x,Pull2.y,0):Length()

                                Pull = Vector(Pull.x, Pull.y, -0.0000125)

                                Pull = Pull * ( (1-(Length/self.ExplosionRadius))^3.3 ) --3.3
                                local force = Pull * (34000*(1^(self.MushroomSuctionWindspeed*0.6*0.015385^1.425))) * (0.05+(5*0.2)) * (self.MushroomSuctionWindspeed*0.6*0.015385*0.5) * (1.0 - dist/self.ExplosionRadius)
                                local force2 = Pull * (34000*(1^(self.MushroomSuctionWindspeed*0.6*0.015385^1.425))) * (0.05+(5*0.2)) * (self.MushroomSuctionWindspeed*0.6*0.015385*0.5) * (1.0 - dist/self.ExplosionRadius)  

                                local force3 = (((force*0.35) + (force2*0.45))) * (1.0 - dist/self.ExplosionRadius) 
                                mass = 50 + physobj:GetMass()*10

                                local gMul = 1 * clamp(self.MushroomSuctionWindspeed*0.6*0.01, 1, 8+mass) 

                                local isRagdoll = v:IsRagdoll()
                                if isRagdoll == true then
                                    local phys = v:GetPhysicsObject()
                                    if IsValid(phys) then
                                        gMul = 10.33 * (1.0 - dist/self.ExplosionRadius) 
                                        phys:ApplyForceCenter( Vector(clamp((force3.x/2)/mass,-150,150),clamp((force3.y/2)/mass,-150,150),clamp((force3.z/2)/mass,-150,150)) * gMul * (1.0 - dist/self.ExplosionRadius) )
                                    end
                                end
                                if v:IsVehicle() then
                                    gMul = 10.33 * (1.0 - dist/self.ExplosionRadius) 
                                end
                                
                                if v:GetMoveType() != MOVETYPE_NOCLIP and (v:IsPlayer() or v:IsNPC()) and v:IsValid() then
                                    if v.AddVelocity then
                                        v:AddVelocity( Vector(clamp((force3.x/2)/mass,-150,150),clamp((force3.y/2)/mass,-150,150),clamp((force3.z/2 * (1.0 - rnd(6000,10000)) )/mass ,-150,150)) * gMul * (1.0 - dist/self.ExplosionRadius))
                                    else
                                        v:SetVelocity( Vector(clamp((force3.x/2)/mass,-150,150),clamp((force3.y/2)/mass,-150,150),clamp((force3.z/2 * (1.0 - rnd(6000,10000)) )/mass ,-150,150)) * gMul * (1.0 - dist/self.ExplosionRadius))
                                    end					
                                end

                                if (v:IsPlayer() and v:InVehicle()) or v:IsVehicle() then 
                                    else
                                    if !v:IsPlayer() and !isRagdoll == true and !v:IsVehicle()  then
                                        if dist <= self.ExplosionRadius * 0.7 then 
                                            if math.random(1, clamp(2 * (0.0 + dist*200/self.ExplosionRadius), 1, math.huge)) == 1 then
                                                local p = v:GetPhysicsObject()	
                                                if p:IsValid() then 
                                                    
                                                if ( constraint.HasConstraints( v )) and !v:IsVehicle() and !p:IsMotionEnabled() then			
                                                    v:EmitSound("break" .. math.random(1, 4) .. ".mp3", 100)
                                                    constraint.RemoveAll(v)
                                                end

                                                if !p:IsMotionEnabled() then
                                                    p:Wake()
                                                    p:EnableMotion(true) 
                                                end   
                                            end
                                        end 
                                    end
                                end
                            
                                    if physobj:IsValid() then 
                                        physobj:AddVelocity(Vector(clamp(force3.x/mass,-500,500), clamp(force3.y/mass,-500,500), clamp(force3.z/2 * (1.0 - rnd(8000,10000))/mass * gMul, -500,500))  )
                                    end		
                                end
                            end		
                        end
                    end
                end


            end

            timer.Simple(60, function()
                if !self:IsValid() then return end
                self:Remove()
            end)
        end
    end

    if CLIENT then
        if self.IncomingSound ~= nil then
            local ply = LocalPlayer()
            local dist = clamp((self:GetPos() - Vector(ply:GetPos()[1], ply:GetPos()[2], self:GetPos()[3])):Length(), 0, math.huge)
            self.IncomingSound:ChangeVolume( 1 * (1.0 - dist/25000), 0)
        end

        local shockwaveRadi = self:GetNWFloat("CurrentShockwaveRadius", 0)
        local entities = ents.FindInSphere(self:GetPos(), shockwaveRadi, 0)

        for _, ent in ipairs(entities) do
            local dist = math.Clamp((self:GetPos() - ent:GetPos()):Length(), 0, 1000000)
            if self.soundtriggered == false and ent == LocalPlayer() then
                LocalPlayer():EmitSound(self.ExplosionSound, 100000, 100, 1* (1.0 - dist/self.ExplosionSoundDistance))
                self.soundtriggered = true      
                if self.IncomingSound ~= nil then
                    self.IncomingSound:Stop()
                end
            end
        end
    end

    self:NextThink(CurTime() + (self.ShockwaveDelay))
    return true
end
