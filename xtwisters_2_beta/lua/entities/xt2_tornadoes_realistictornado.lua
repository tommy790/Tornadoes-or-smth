AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 3
ENT.range = 7800
ENT.Force = 0
ENT.weldf = 2299
ENT.rotforce = -77
ENT.f3 = {"RDTX1_realistic", "trt_drillbit_1",  "PGYT_Realismnado", "v31_f4"}
ENT.HasLightning = true 
ENT.Subvorts = true 
ENT.isderp = false
ENT.speedmult = 1
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "''Realistic'' Tornado" 

function ENT:Initialize()

    if SERVER then

        self.Force = math.random(136, 200)
        local picker = math.random(0,7)

        if picker == 3 then
            self.f3 = {"RDTX3_Realistic2"}
            self.rotforce = -160
        elseif picker == 4 then
            self.f3 = {"RDTX4_Realistic3"}
            self.rotforce = -190
            self.range = 14000
            self.Force = math.random(90, 200)
        elseif picker == 5 then
            self.f3 = {"trt_jc4"}
            self.Force = math.random(180, 250)
            self.rotforce = -70
            self.range = 9000
            self.isderp = true
            self.derptype = 2
        elseif picker == 6 then
            self.f3 = {"trt_tornado_1"}
            self.rotforce = -190
            self.range = 14000
            self.Force = math.random(180, 250)
        elseif picker == 7 then
            self.f3 = {"v31_f4"}
            self.rotforce = -160
            self.Force = math.random(165, 200)
            self.range = 8000
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
    
        print("This tornado's windspeed is " .. self.Force )
        print("This tornado is an EF" .. self.sFScale )

        self:startx()

        timer.Simple(GetConVar("xt2_tlifetime"):GetInt(), function()
                
            if !self:IsValid() then return
                
            end
                
            self:Remove()
                
        end)

        self:testing2()  
        
        for k, v in ipairs(self.f3) do  

            PrecacheParticleSystem(v)

        end
        
        local u = table.Random(self.f3)

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

