AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 4
ENT.range = 8800
ENT.Force = 0
ENT.weldf = 209
ENT.rotforce = -160
ENT.f4 = {"RDT2_EF4","Twister_EF4", "5TonyEF4", "5TonyEF42", "5TonyEF411", "5TonyEF43", "5TonyEF418", "PGYT_EF_4c" , "PGYT_EF_4d" , "PGYT_EF_4e" , "PGYT_EF_4f" , "PGYT_EF_4g" , "PGYT_EF_4h" , "PGYT_EF_4i" , "PGYT_EF_4j", "5TonyEF420", "5TonyEF421", "5TonyEF422", "5TonyEF419", "5TonyEF416", "PGYT_EF_4", "PGYT_EF_4b", "5TonyEF417", "5TonyEF44", "5TonyEF414",  "5TonyEF415", "5TonyEF45", "5TonyEF412", "5TonyEF413", "5TonyEF46", "5TonyEF47", "5TonyEF48", "5TonyEF49", "5TonyEF410", "v1_f4", "v2_f4", "v3_f4", "v4_f4", "v5_f4", "v6_f4", "v7_f4", "v8_f4", "v9_f4", "v10_f4", "v11_f4", "v12_f4", "v13_f4", "v14_f4", "v15_f4", "v16_f4", "v17_f4", "v18_f4", "v19_f4", "v20_f4", "v21_f4", "v22_f4", "v23_f4", "v24_f4", "v25_f4", "v26_f4", "v27_f4", "v28_f4", "v29_f4", "v30_f4", "v31_f4"}
ENT.HasLightning = true 
ENT.Subvorts = true 
ENT.isderp = false
ENT.speedmult = 0.6
ENT.HeightForceMultiplier = 15.0 --z tornadic force scaling (height)
ENT.GeneralForceMultiplier = 1.7 --x and y tornadic force scaling
ENT.PlayerNPCForceMult = 0.25
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "EF4 Tornado" 

function ENT:Initialize()

    if SERVER then

        self.Force = math.random(166, 200)
        local function Picktornadowindfield() --There are 43 different EF-4s total, 22 small EF4s, 12 large EF4s, 5 small mv EF4s, 4 large mv EF4s
            self.windsizerand = math.random(0,45)
            if self.windsizerand >= 0 and self.windsizerand <= 21 then
                print("Type: EF-4 Small")
                    self.Subvorts = false
            self.range = 6000
                    self.f4 = {"Twister_EF4","RDT2_EF4","5TonyEF411","5TonyEF43","PGYT_EF_4d","PGYT_EF_4f","PGYT_EF_4g","PGYT_EF_4h","PGYT_EF_4i","5TonyEF420","5TonyEF421","5TonyEF422","5TonyEF419","5TonyEF413","5TonyEF48", "v1_f4", "v2_f4", "v3_f4", "v4_f4", "v5_f4", "v6_f4", "v7_f4", "v9_f4", "v10_f4", "v17_f4", "v20_f4", "v21_f4", "v24_f4", "v25_f4", "v27_f4"}  
            end
            if self.windsizerand >= 22 and self.windsizerand <= 34 then
                print("Type: EF-4 Large")
                    self.Subvorts = false
            self.range = 9000
                    self.f4 = {"5TonyEF42","PGYT_EF_4j","5TonyEF416","PGYT_EF_4","5TonyEF414","5TonyEF45","5TonyEF46","5TonyEF47","5TonyEF49","5TonyEF410", "v8_f4", "v11_f4", "v11_f4", "v18_f4", "v22_f4", "v23_f4", "v26_f4", "v28_f4", "v29_f4"}  
            end
            if self.windsizerand >= 35 and self.windsizerand <= 39 then
                print("Type: EF-4 Small, Subvorts")
                    self.Subvorts = true
            self.range = 7000
                    self.f4 = {"5TonyEF418","PGYT_EF_4c","PGYT_EF_4e","5TonyEF44", "v12_f4", "v13_f4", "v19_f4"} 
            end
            if self.windsizerand >= 40 and self.windsizerand <= 43 then
                print("Type: EF-4 Large, Subvorts")
                self.Subvorts = true
                self.range = 10000
                self.f4 = {"5TonyEF4","5TonyEF417", "v15_f4", "v30_f4"}
            end
            if self.windsizerand >= 44 and self.windsizerand <= 45 then
                print("Type: EF-4 Small, Anticyclonic")
                self.range = 6000
                self.f4 = {"v16_f4"}
                self.rotforce = 160
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
        
        for k, v in ipairs(self.f4) do  

            PrecacheParticleSystem(v)

        end
        
        local u = table.Random(self.f4)

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
                
            local penis = ParticleEffectAttach(u,PATTACH_ABSORIGIN_FOLLOW,self,0)

            if !penis then return penis end


        end)

    end

end

function ENT:OnRemove()
    self:OnRemoveX()
end

