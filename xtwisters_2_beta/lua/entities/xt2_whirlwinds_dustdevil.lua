AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 0
ENT.range = math.random(1500, 2500)
ENT.Force = 0
ENT.weldf = math.random(8199, 9499)
ENT.rotforce = -30
ENT.speedmult = 0.5
ENT.f0 =  {"trt_vD_1", "trt_vD_2", "trt_vD_3", "trt_vD_4", "trt_vD_5", "TDustDevil", "TDustDevil2", "TDustDevil3", "TDustDevil4", "TDustDevil5", "trt_vG_3"}
ENT.HasLightning = false  
ENT.Subvorts = false 
ENT.Tornadic = false 
ENT.isderp = false
ENT.speedmult = 0.6

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Dust Devil" 

function ENT:Initialize()

    if SERVER then
        self.baseRandom = math.pow(math.random(), 2.5)
        self.Force = math.floor(self.baseRandom * (140 - 3) + 3)
        local sizerandom = math.random(1, 6)
        if sizerandom < 3 then -- small fellas
            self.Force = math.random(3, 35)
            self.f0 = {"trt_vD_1", "trt_vD_2", "TDustDevil", "TDustDevil2", "TDustDevil3", "TDustDevil4", "TDustDevil5"}
            self.range = 1500
        elseif sizerandom < 5 then -- medium fellas
            self.f0 = {"trt_vD_3", "trt_vD_4", "trt_vG_3"}
            self.range = 3000
        elseif sizerandom < 6 then -- large fellas
            self.f0 = {"trt_vD_5"}
            self.range = 4000
        end

        local function GetFujita()

            local Windspeed = self.Force
        
            if Windspeed < 65 then
                self.sFScale = 0
                self.Subvorts = false 
                self.weldf = 800
            end
        
            if Windspeed >= 65 and Windspeed <= 85 then
                self.sFScale = 0
                self.Subvorts = false
                self.weldf = math.random(5199, 6499)  
            end
        
            if Windspeed >= 86 and Windspeed <= 110 then
                self.sFScale = 1
                self.Subvorts = false
                self.weldf = 3999
            end
        
            if Windspeed >= 111 and Windspeed <= 135 then
                self.sFScale = 2
                self.Subvorts = false
                self.weldf = 3099 
            end
        
            if Windspeed >= 136 and Windspeed <= 165 then
                self.sFScale = 3
                self.Subvorts = true 
                self.weldf = 2299
            end
        
            if Windspeed >= 166 and Windspeed <= 200 then
                self.sFScale = 4
                self.Subvorts = true 
                self.weldf = 209
            end
        
            if Windspeed >= 201 then
                self.sFScale = 5
                self.Subvorts = true 
                self.weldf = 50
            end
        
        end

        GetFujita()

        print("This Dust Devil's windspeed is " .. self.Force )
        print("This Dust Devil is an equivalent to/weaker than a EF" .. self.sFScale .." Tornado")
        
        
        self:startx()
            
        timer.Simple((math.random(25,70))*(GetConVar("xt2_tlifetime"):GetInt() / 400), function()
                
            if !self:IsValid() then return
                
            end
                
            self:Remove()
                
        end)

        self:testing2()

        for k, v in ipairs(self.f0) do  

            PrecacheParticleSystem(v)       
        
        end
        
        local u = table.Random(self.f0)

        print(u)

        self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetColor( Color( 0, 0, 0, 0 ) )
        self:SetRenderMode( RENDERMODE_TRANSALPHA )
        self:SetMoveType( MOVETYPE_FLY )
        self:SetSolid( SOLID_NONE )
        self:SetCollisionGroup( 1 )

        timer.Simple(0.5, function()
                
            if !self:IsValid() then return end
                    
                ParticleEffectAttach(u,PATTACH_ABSORIGIN_FOLLOW,self,0)

            end)

        end

end

function ENT:OnRemove()
    self:OnRemoveX()
end

