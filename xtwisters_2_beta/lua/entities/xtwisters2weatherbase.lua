AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.IsWindy = true 
ENT.WindDir = Vector(0, 1, 0)
ENT.Force = 0
ENT.Weldf = 0
ENT.IsRaining = false 
ENT.IsHailing = false  
ENT.IsFoggy = true 
ENT.FogStart = 0
ENT.FogEnd = 1000
ENT.FogDensity = 1
ENT.FogColor = Vector(127,127,127) 
ENT.RainType = 0
ENT.HasLightning = true 
ENT.LightningChance = 1
ENT.RainSound = nil
ENT.IsAutospawnWeather = false

local function IsLVSVehicle(ent)
    if IsValid(ent) and ent.GetClass then
        local class = ent:GetClass()
        if string.sub(class, 1, 3) == "lvs" then
            return true
        end
    end
    return false
end

local function CoolerLerp(a, b, t) return a + (b - a) * t end
local function rnd(mi, ma) return math.random(1000) / 1000 * (ma - mi) + mi end
local OGFog = 0
local veryLightRainAudio = "Weather/ENVShared/Water/VeryLightRainLoopDefault.wav"
local lightRainAudio = "Weather/ENVShared/Water/LightRainLoopDefault.wav"
local mediumRainAudio = "Weather/ENVShared/Water/MediumRainLoopDefault.wav"
local heavyRainAudio = "Weather/ENVShared/Water/HeavyRainLoopDefault.wav"

function ENT:UpdateForceRagdolls()
    if SERVER then
        local Windspeed = self.Force
        local Windspeedmultifordamage = Windspeed - (Windspeed * (0.0003 * Windspeed))
        self.Weldf = math.Clamp(200 * 3000000000 / (Windspeedmultifordamage * 0.35 * Windspeedmultifordamage * 0.5 * Windspeedmultifordamage * 0.8 * Windspeedmultifordamage) / 40, 0, 1000000)
        timer.Create("updateforceragdolls"..tostring(self)..tostring(self:EntIndex()), 0.1, 1, function()
            if not self:IsValid() then
                return
            end
            local e = ents.GetAll()
            for i = 1, #e do
                local v = e[i]
                if v != self and not (v:GetClass() == "gmod_ghost") and not v:IsWorld() and not v:IsWeapon() and not (v:GetClass() == "sent_anim") and v:GetCollisionGroup() != 1 and v:IsValid() then
                    local forcedirection = self.WindDir + Vector(rnd(-0.5, 0.5), rnd(-0.5, 0.5), rnd(-1, 1))
                    local force = forcedirection * (Windspeedmultifordamage * 0.35 + Windspeedmultifordamage * 2 + Windspeedmultifordamage * 2 + Windspeedmultifordamage * 20)
                    local gMul2 = 1 -- Reset multiplier for each entity
                    
                    if v:IsOnGround() then
                        gMul2 = 0.15
                    else
                        gMul2 = 0.08
                    end
                    
                    if v:IsPlayer() and v:Crouching() and v:IsOnGround() then
                        gMul2 = 0.013
                    elseif v:IsRagdoll() then
                        gMul2 = gMul2 * 6
                    elseif v:IsVehicle() or IsLVSVehicle(v) == true then
                        -- Adjusting the multiplier based on force and vehicle conditions
                        if self.Force <= 65 then
                            gMul2 = gMul2 * (5 * 2.5)
                        elseif self.Force <= 100 then
                            gMul2 = gMul2 * (50 * 3)
                        elseif self.Force <= 140 then
                            gMul2 = gMul2 * (60 * 4.5)
                        elseif self.Force >= 141 then
                            gMul2 = gMul2 * (60 * 6)
                        end
                    end

                    if v:IsVehicle() or IsLVSVehicle(v) == true then
                        gMul2 = gMul2 * 1.5
                    end
                    
                    -- Apply localized force
                    if v:IsRagdoll() or v:IsVehicle() or IsLVSVehicle(v) == true then
                        local physobj = v:GetPhysicsObject()
                        if physobj:IsValid() and physobj:IsMotionEnabled() and physobj:IsValid() then
                            physobj:ApplyForceOffset(force * gMul2, v:GetPos() + Vector(rnd(-30, 30), rnd(-30, 30), rnd(-5, 10)))
                        end
                    elseif v.AddVelocity and !v:IsVehicle() and IsLVSVehicle(v) == false and v:IsValid() then
                        v:AddVelocity(force * 0.3 * gMul2)
                    elseif !v:IsVehicle() and IsLVSVehicle(v) == false and v:IsValid() then
                        v:SetVelocity(force * 0.3 * gMul2)
                    end
                end
            end
            if self:IsValid() then
                self:UpdateForceRagdolls()
            end
        end)
    end
end

function ENT:startx()
    PrecacheParticleSystem("RDTW_HeavyRain")
    PrecacheParticleSystem("RDTW_HeavyRainImp")
    PrecacheParticleSystem("RDTW_LightRain")
    PrecacheParticleSystem("RDTW_LightRainImp")
    PrecacheParticleSystem("RDTW_ModerateRain")
    PrecacheParticleSystem("RDTW_ModerateRainImp")

    OGFog = self.FogEnd

    if self.IsRaining == true and self.RainType ~= 0 then
        if self.RainType == 1 then
            self.RainParticleTop = "RDTW_LightRain"
            self.RainParticleBottom = "RDTW_LightRainImp"

            if CLIENT then
                if !self:IsValid() then return end
                self.Rainsound = nil
                self.RainSound = CreateSound(LocalPlayer(), Sound(lightRainAudio))
                self.RainSound:SetSoundLevel( 19000 )
                self.RainSound:ChangeVolume( 1 )
            end
        elseif self.RainType == 2 then
            self.RainParticleTop = "RDTW_ModerateRain"
            self.RainParticleBottom = "RDTW_ModerateRainImp"
            
            if CLIENT then
                if !self:IsValid() then return end
                self.Rainsound = nil
                self.RainSound = CreateSound(LocalPlayer(), Sound(mediumRainAudio))
                self.RainSound:SetSoundLevel( 19000 )
                self.RainSound:ChangeVolume( 1 )
            end
        elseif self.RainType == 3 then
            self.RainParticleTop = "RDTW_HeavyRain"
            self.RainParticleBottom = "RDTW_HeavyRainImp"

            if CLIENT then
                if !self:IsValid() then return end
                self.Rainsound = nil
                self.RainSound = CreateSound(LocalPlayer(), Sound(heavyRainAudio))
                self.RainSound:SetSoundLevel( 19000 )
                self.RainSound:ChangeVolume( 1 )
            end
        end
    end

    if SERVER then
        self:UpdateForceRagdolls()
    end

    if CLIENT then
        
        self.RAINHIMNOW = Vector(0,0,0)
        hook.Add( "CalcView", "GetPlyCamPos", function( ply, pos, angles, fov )
            self.RAINHIMNOW = pos
        end )

        if self.IsRaining == true and self.RainType ~= 0 then
            for i, ply in ipairs( player.GetAll() ) do
                self.RainSound:Play()
            end  
        end

        if not string.find(game.GetMap(), "night") and self.IsFoggy == true then
            hook.Add("SetupWorldFog","XT2WWorldFogOverride",function()
                render.FogMode(1)
                render.FogMaxDensity(self.FogDensity)
                render.FogColor(self.FogColor[1], self.FogColor[2], self.FogColor[3])
                render.FogStart(self.FogStart*16)
                render.FogEnd(self.FogEnd*16)
                return true
            end)

            hook.Add("SetupSkyboxFog","XT2WSkyFogOverride",function(scale)
                render.FogMode(1)
                render.FogMaxDensity(self.FogDensity)
                render.FogColor(127,127,127)
                render.FogStart(self.FogStart)
                render.FogEnd(self.FogEnd)
                return true 
            end)

            local ang = Angle(0,0,0)
            local vec_0_0_0 = Vector(0,0,0)
            local vec_0_0_n512 = Vector(0,0,-512)
            local vec_n512_n512_0 = Vector(-512,-512,0)
            local vec_512_512_0 = Vector(512,512,0)
            local vec_0_0_512 = Vector(0,0,512)
            local vec_0_n512_0 = Vector(0,-512,0)
            local vec_n512_0_n512 = Vector(-512,0,-512)
            local vec_0_512_0 = Vector(0,512,0)
            local vec_512_0_512 = Vector(512,0,512)
            local vec_512_0_0 = Vector(512,0,0)
            local vec_0_512_512 = Vector(0,512,512)
            local vec_0_n512_n512 = Vector(0,-512,-512)
            local vec_n512_0_0 = Vector(-512,0,0)

            hook.Add("PostDraw2DSkyBox","XT2WSkyOverride",function()
                local fogmode = render.GetFogMode() -- If there's fog, save it
                render.FogColor(127,127,127)
                local fogcolorR,FogColorG,FogColorB = render.GetFogColor()
                local fogcolorC = Color(fogcolorR,FogColorG,FogColorB)
                render.OverrideDepthEnable(true,false)
                
                cam.Start3D(vec_0_0_0,RenderAngles()) -- Render space!
                    render.FogMode(1) -- Turn off fog
                    render.SetColorMaterial() -- Set the texture
                    render.DrawBox(vec_0_0_n512,ang,vec_n512_n512_0,vec_512_512_0,fogcolorC,0)
                    render.DrawBox(vec_0_0_512,ang,vec_512_512_0,vec_n512_n512_0,fogcolorC,0)
                    render.DrawBox(vec_0_n512_0,ang,vec_n512_0_n512,vec_512_0_512,fogcolorC,0)
                    render.DrawBox(vec_0_512_0,ang,vec_512_0_512,vec_n512_0_n512,fogcolorC,0)
                    render.DrawBox(vec_512_0_0,ang,vec_0_512_512,vec_0_n512_n512,fogcolorC,0)
                    render.DrawBox(vec_n512_0_0,ang,vec_0_n512_n512,vec_0_512_512,fogcolorC,0)
                    render.FogMode(fogmode)
                cam.End3D()
                
                render.OverrideDepthEnable(false,false)
            end)
        end
    end
end

local Time = CurTime()
local Windspeed

function ENT:Think()------------
    if SERVER and self.IsRaining and self.RainType ~= 0 then
        if !self.JustInitializedWeather then
            print("Weather Windspeed: " .. self.Force)
            self.JustInitializedWeather = true
        end
        for _, ply in ipairs(player.GetAll()) do
            local timerName = "ApplyRainEffects_" .. ply:EntIndex()
            if not timer.Exists(timerName) then
                timer.Create(timerName, 1, 0, function() 
                    if self:IsValid() and ply:IsValid() then
                        self:ApplyRainEffectsToPlayer(ply) 
                    end
                end)
            end
        end
    end

    if CLIENT then
        self.Windspeed = self:GetNWFloat("Windspeed", 0)
        
        if self.WindRoar == nil then
            self.WindRoar = CreateSound(LocalPlayer(), Sound("Tornado/ArcadeTornadoLoop.wav"))
            self.WindRoar:Play()
        elseif self.WindRoar ~= nil then 
            self.WindRoar:ChangeVolume(self.Windspeed * 0.0020)
            self.WindRoar:ChangePitch(math.Clamp((self.Windspeed / 4) + 30, 0, 255))
        end

        if self.IsRaining == true and self.RainType ~= 0 then
            for i, ply in ipairs(player.GetAll()) do
                self.RainSound:Play()
            end  
        end

        hook.Add("CalcView", "UpdateRainEffectPosition", function(player, pos, angles, fov)
            self.RAINHIMNOW = pos
            if self.IsRaining == true and self.RainType ~= 0 and not GetIsPausedState() then
                local IndoorCheck = util.TraceLine({ start = self.RAINHIMNOW, filter = {self, player}, endpos = self.RAINHIMNOW + Vector(0, 0, 1000) })
                if not IndoorCheck.Hit then
                    ParticleEffect(self.RainParticleTop, self.RAINHIMNOW, Angle(), player) 
                    self.FogEnd = CoolerLerp(self.FogEnd, OGFog, 0.01)
                else           
                    self.FogEnd = CoolerLerp(self.FogEnd, OGFog*4, 0.01)
                end

                local RainImpEmit = GetConVar("xt2_antilag"):GetInt() == 1 and 1 or math.random(1, 20)
                for i=0, RainImpEmit do
                    local RainImp = util.TraceLine({ start = self.RAINHIMNOW + Vector(math.random(-1000, 1000), math.random(-1000, 1000), 1500), filter = self, endpos = self.RAINHIMNOW + Vector(math.random(-100, 1000), math.random(-1000, 1000), -10000) })
                    if RainImp.Hit and not GetIsPausedState() then
                        ParticleEffect(self.RainParticleBottom, RainImp.HitPos, Angle(), player)
                    end
                end
            end
        end)
    end
    if SERVER then
        local antilag = GetConVar("xt2_antilag"):GetInt()
        self:SetNWFloat( "Windspeed", self.Force )
        if math.random(1, self.LightningChance) == 1 and self.HasLightning == true then
            local t = ents.Create("lightning_bolt")
            if t:IsValid() then
                local stv = Vector( math.random(-32768, 32768), math.random(-32768, 32768), self:GetPos()[3] )

                local dontgoon = util.TraceLine( { start = stv, mask = MASK_SOLID_BRUSHONLY, endpos = stv + Vector(0, 0, 100000) } )
                if dontgoon.HitPos then
                    t:SetPos( dontgoon.HitPos )
                    t:Spawn()
                    t:Setup()
                end
            end
        end

        if self.IsHailing == true then 
            for i=0, 100 do
                if math.random(1, 5) == 1 then
                    local t = ents.Create("xt2_weather_hail")

                    if t:IsValid() then
                        for i, v in ipairs( player.GetAll() ) do
                            local position = v:GetPos() + Vector( math.random(-800, 800), math.random(-800, 800), rnd(600,1000) )

                            if math.random(1,5) == 1 then
                                position = v:GetPos() + Vector( math.random(-1800, 1800), math.random(-1800, 1800), rnd(600,1000) )
                            end

                            t:SetPos( position )
                            t:Spawn()
                        end
                    end
                end
            end
        end

        local e = ents.GetAll()

        for i = 1 , #e do
            local v = e[i]
            
            if v:IsValid() and v != self and not (v:GetClass() == "gmod_ghost") and !v:IsWorld() and !v:IsPlayer() and !v:IsNPC() and !v:IsVehicle() and IsLVSVehicle(v) == false and !v:IsWeapon() and not (v:GetClass() == "sent_anim") and v:GetCollisionGroup() != 1 then
                local physobj = v:GetPhysicsObject()
                if physobj:IsValid() then

                    local trace = {
                        start = self:GetPos() + self.WindDir*100+Vector(0,0,1000),
                        endpos = v:GetPos(),
                        filter = self
                    }

                    if GetConVar("xt2_windblockedbyobjects"):GetInt() == 1 then 
                        tr = util.TraceLine( trace )
                    else
                        tr = {}
                        tr.Entity = v
                    end
                    if tr.Entity == v then
                        local AbsoluteWeight = physobj:GetMass()
                        local Windspeed = self.Force
                        -- Pre-compute Windspeed multiplier for damage to avoid repeating the calculation
                        local Windspeedmultifordamage = Windspeed - (Windspeed * (0.0003 * Windspeed))
                        local forcedirection = self.WindDir + Vector(rnd(-0.5,0.5), rnd(-0.5,0.5), rnd(-1,1))
                        -- Calculate the common part of the force calculation to simplify the formula
                        local baseForce = forcedirection * (Windspeedmultifordamage * 24.35)
                        
                        local forceUP = Vector(0,0,100) * (Windspeed * 0.5)
                        if AbsoluteWeight >= 1 then
                            forceUP = forceUP * ((2 / AbsoluteWeight) ^ 0.15 - 0.3)
                        end
                        
                        if antilag == 1 then
                            forceUP = forceUP / 1.5
                        end
                        
                        -- Force calculation
                        local force
                        local weightCategoryMultiplier = {
                            {limit = 10, multiplier = 0.05},
                            {limit = 100, multiplier = 0.075},
                            {limit = 250, multiplier = 1.25},
                            {limit = 500, multiplier = 4.5},
                            {limit = 750, multiplier = 7.0},
                            {limit = 2000, multiplier = 6.0},
                            {limit = 8000, multiplier = 2.5, heavy = 0.2},
                            {limit = math.huge, multiplier = 0.1}
                        }
                        
                        -- Determine multiplier based on weight
                        local selectedMultiplier = 0
                        for _, category in ipairs(weightCategoryMultiplier) do
                            if AbsoluteWeight <= category.limit then
                                selectedMultiplier = category.multiplier
                                break
                            elseif category.heavy and AbsoluteWeight >= 8000 then
                                selectedMultiplier = category.heavy
                                break
                            end
                        end
                        
                        -- Adjust force for heavy props
                        if AbsoluteWeight >= 15000 then
                            selectedMultiplier = 0
                        end
                        
                        -- Adjust force based on anti-lag setting
                        if antilag == 1 then
                            if AbsoluteWeight > 10 and AbsoluteWeight <= 100 then
                                -- Special case for weight between 10 and 100 with anti-lag enabled
                                selectedMultiplier = (1.5 / 1.0) * (AbsoluteWeight / 50)
                            else
                                selectedMultiplier = (1.5 / 1.0) * (AbsoluteWeight / 50)
                                selectedMultiplier = selectedMultiplier / 1.25
                            end
                        end
                        
                        -- Calculate final force
                        if antilag == 1 then
                            force = (baseForce * selectedMultiplier) * 0.5
                        else
                            force = (baseForce * selectedMultiplier) * 1.0
                        end

                        if v:IsOnGround() then
                            gMul = 4.0*2.5
                        else
                            gMul = 6*3
                        end	

                        if !v:IsPlayer() and !v:IsRagdoll() and !v:IsVehicle() and IsLVSVehicle(v) == false then
                            local dmg = DamageInfo()
                            local function TakeDamage( victim, damage, attacker, inflictor ) dmg:SetDamage( damage ) dmg:SetAttacker( attacker ) dmg:SetInflictor( inflictor ) dmg:SetDamageType( DMG_PREVENT_PHYSICS_FORCE ) victim:TakeDamageInfo( dmg ) end
                        
                            if GetConVar("xt2_hurtprops"):GetInt() == 1 then 
                                TakeDamage( v, (1*(self.Force*0.015385)), self, self )
                            end

                            local tempweldf = self.Weldf
                            if antilag == 1 then
                                tempweldf = tempweldf / 3.5
                            else
                                tempweldf = tempweldf / 1.75
                            end

                            if math.random(1, tempweldf) == 1 and GetConVar("xt2_unweldprops"):GetInt() == 1 and physobj:IsValid() and !physobj:IsMotionEnabled() then

                                if ( constraint.HasConstraints( v )) and !v:IsVehicle() and IsLVSVehicle(v) == false then			
                                    v:EmitSound("break" .. math.random(1, 4) .. ".mp3", 100)
                                    physobj:ApplyForceCenter(forceUP*gMul)
                                    constraint.RemoveAll(v)
                                end
                                physobj:Wake()
                                physobj:EnableMotion(true)    
                            end 
                        end
                        
                        if physobj:IsValid() and physobj:IsMotionEnabled() then 
                            if !v:IsRagdoll() == true and force ~= 0 and gMul ~= 0 and v:GetPos() then
                                physobj:ApplyForceOffset(force*gMul, v:GetPos()+Vector(rnd(-30,30), rnd(-30,30), rnd(-15,15)))
                            elseif force ~= 0 and gMul ~=0 and v:GetPos() then
                                physobj:ApplyForceOffset(force*0.25, v:GetPos())
                            end
                        end		
                    end
                end
            end
        end

        local nextTickMultiplier
        if antilag == 1 then
            nextTickMultiplier = math.random(28, 30)
        elseif antilag == 0 then
            nextTickMultiplier = math.random(14, 16)
        end

        self:NextThink( CurTime() + engine.TickInterval()*nextTickMultiplier)
        return true 
    end
end

function ENT:ApplyRainEffectsToPlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local IndoorCheck = util.TraceLine({start = ply:GetPos(), endpos = ply:GetPos() + Vector(0, 0, 1000), filter = ply})
    if not IndoorCheck.HitSky then
        ParticleEffectAttach(self.RainParticleTop, PATTACH_ABSORIGIN_FOLLOW, ply, 0)
        self.FogEnd = CoolerLerp(self.FogEnd, OGFog, 0.01)
    else
        self.FogEnd = CoolerLerp(self.FogEnd, OGFog*4, 0.01)
    end
end

function ENT:OnRemoveX()
    -- Cleanup for existing hooks and sounds
    hook.Remove("CalcView", "GetPlyCamPos")
    hook.Remove("PostDraw2DSkyBox", "XT2WSkyOverride")
    hook.Remove("SetupWorldFog", "XT2WWorldFogOverride")
    hook.Remove("SetupSkyboxFog", "XT2WSkyFogOverride")

    if self.RainSound ~= nil then
        self.RainSound:Stop()
    end

    if self.WindRoar ~= nil then
        self.WindRoar:Stop()
    end

    -- Stop all player-specific rain effect timers
    for _, ply in ipairs(player.GetAll()) do
        local timerName = "ApplyRainEffects_" .. ply:EntIndex()
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
    end
end


