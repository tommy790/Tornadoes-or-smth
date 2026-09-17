AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 1
ENT.range = 3200
ENT.Force = 0
ENT.weldf = 3999
ENT.rotforce = -70
ENT.f1 = {"Twister_EF1", "5TonyEF1", "5TonyEF12", "5TonyEF13", "5TonyEF16", "5TonyEF118", "5TonyEF120", "PGYT_EF_1k" , "PGYT_EF_1l" , "PGYT_EF_1m" , "PGYT_EF_1n" , "PGYT_EF_1o" , "PGYT_EF_1p" , "PGYT_EF_1q" , "PGYT_EF_1r" , "PGYT_EF_1s" , "PGYT_EF_1t" , "PGYT_EF_1u", "5TonyEF121", "5TonyEF122", "5TonyEF119", "5TonyEF117", "5TonyEF116", "PGYT_EF_1f" , "PGYT_EF_1g" ,  "5TonyEF112", "5TonyEF114",  "PGYT_EF_1h" , "PGYT_EF_1i" , "PGYT_EF_1j", "5TonyEF115", "5TonyEF113", "5TonyEF17", "5TonyEF18", "5TonyEF19", "5TonyEF111", "5TonyEF110", "PGYT_EF_1", "PGYT_EF_1" , "PGYT_EF_1b" , "PGYT_EF_1c" , "PGYT_EF_1d", "PGYT_EF_1e", "5TonyEF14", "5TonyEF15", "5TonyEF16", "v1_f1", "v2_f1",  "v3_f1", "v4_f1", "v5_f1", "v6_f1", "v7_f1", "v8_f1", "v9_f1", "v10_f1", "v11_f1", "v12_f1", "v13_f1", "v14_f1", "v15_f1", "v16_f1", "v17_f1", "v18_f1", "v19_f1", "v20_f1", "v21_f1", "v22_f1"}
ENT.HasLightning = true 
ENT.Subvorts = true 
ENT.isderp = false
ENT.speedmult = 0.45
ENT.HeightForceMultiplier = 0 --z tornadic force scaling (height)
ENT.GeneralForceMultiplier = 0 --x and y tornadic force scaling
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "EF1 Tornado" 

function ENT:Initialize()

    if SERVER then
        
        self.Force = math.random(86, 110)
        local function Picktornadowindfield() --There are 62 different EF-0s total, 19 small EF0, 28 large EF0, 6 small mv EF0, 9 large mv EF0
            self.windsizerand = math.random(0,59)
            if self.windsizerand >= 0 and self.windsizerand <= 27 then
                print("Type: EF-1 Small")
                self.Subvorts = false
                self.range = 2600
                self.HeightForceMultiplier = 4.8
                self.GeneralForceMultiplier = 1.3
                self.f1 = {"Twister_EF1","5TonyEF1","5TonyEF13","5TonyEF118","PGYT_EF_1k","PGYT_EF_1l","PGYT_EF_1n","PGYT_EF_1o","PGYT_EF_1p","PGYT_EF_1r","PGYT_EF_1u","5TonyEF121","PGYT_EF_1f","5TonyEF112","5TonyEF114","PGYT_EF_1h","PGYT_EF_1j","5TonyEF115","5TonyEF113","5TonyEF17","5TonyEF18","PGYT_EF_1","PGYT_EF_1b","PGYT_EF_1c","5TonyEF15", "v1_f1", "v2_f1", "v3_f1", "v6_f1", "v7_f1", "v8_f1", "v11_f1", "v16_f1", "v21_f1"}  
            end
            if self.windsizerand >= 28 and self.windsizerand <= 38 then
                print("Type: EF-1 Large")
                self.Subvorts = false
                self.range = 3900
                self.HeightForceMultiplier = 4.9
                self.GeneralForceMultiplier = 1.4
                self.f1 = {"5TonyEF16","5TonyEF120","PGYT_EF_1s","5TonyEF119", "5TonyEF117","5TonyEF19","5TonyEF111","PGYT_EF_1d","PGYT_EF_1e","5TonyEF16", "v12_f1"}  
            end
            if self.windsizerand >= 39 and self.windsizerand <= 46 then
                print("Type: EF-1 Small, Subvorts")
                self.HeightForceMultiplier = 4.9
                self.GeneralForceMultiplier = 1.3
                self.Subvorts = true
                self.range = 2800
                self.f1 = {"PGYT_EF_1m","PGYT_EF_1q","PGYT_EF_1g","5TonyEF110", "v4_f1", "v9_f1", "v10_f1", "v13_f1", "v15_f1", "v18_f1", "v19_f1", "v22_f1"} 
            end
            if self.windsizerand >= 47 and self.windsizerand <= 55 then
                print("Type: EF-1 Large, Subvorts")
                self.Subvorts = true
                self.range = 4250
                self.HeightForceMultiplier = 4.8
                self.GeneralForceMultiplier = 1.4
                self.f1 = {"5TonyEF12","PGYT_EF_1t","5TonyEF122","5TonyEF116","5TonyEF14", "v14_f1", "v20_f1"}
            end
            if self.windsizerand >= 56 and self.windsizerand <= 57 then
                print("Type: EF-1 Small Anticyclonic")
                self.Subvorts = false
                self.HeightForceMultiplier = 4.9
                self.GeneralForceMultiplier = 1.3
                self.range = 2600
                self.rotforce = 70
                self.f1 = {"PGYT_EF_1i", "v5_f1", "v17_f1"}
            end
            if self.windsizerand >= 58 and self.windsizerand <= 59 then
                print("Type: EF-1 Large Anticyclonic")
                self.Subvorts = false
                self.range = 3900
                self.HeightForceMultiplier = 4.75
                self.GeneralForceMultiplier = 1.2
                self.rotforce = 70
                self.f1 = {"v17_f1"}
            end
        end
        Picktornadowindfield()

        print("This tornado's windspeed is " .. self.Force )
        print("This tornado is an EF" .. self.sFScale )

        self:startx()
        
        timer.Simple(GetConVar("xt2_tlifetime"):GetInt(), function()
                
            if !self:IsValid() then return
                
            end
                
            self:Remove()
                
        end)

        self:testing2()

        for k, v in ipairs(self.f1) do  

            PrecacheParticleSystem(v)       
        
        end
        
        local u = table.Random(self.f1)

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

