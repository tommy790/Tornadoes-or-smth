AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 2
ENT.range = 4200
ENT.Force = 0
ENT.weldf = 3099
ENT.rotforce = -77
ENT.f2 = {"Twister_EF2", "5TonyEF2", "5TonyEF211", "5TonyEF22", "5TonyEF216", "5TonyEF217", "5TonyEF220", "PGYT_EF_2k" , "PGYT_EF_2l" , "PGYT_EF_2" , "PGYT_EF_2m" , "PGYT_EF_2n" , "PGYT_EF_2o" , "PGYT_EF_2p" , "PGYT_EF_2q" , "PGYT_EF_2r", "5TonyEF221", "5TonyEF222", "5TonyEF218", "5TonyEF219", "PGYT_EF_2f" , "PGYT_EF_2g", "PGYT_EF_2h" , "PGYT_EF_2i" , "PGYT_EF_2j", "5TonyEF23", "5TonyEF214", "5TonyEF215", "5TonyEF24", "5TonyEF212", "5TonyEF25",  "5TonyEF213", "5TonyEF26", "5TonyEF27", "5TonyEF28", "5TonyEF29", "5TonyEF210", "PGYT_EF_2" , "PGYT_EF_2b" , "PGYT_EF_2c" , "PGYT_EF_2d" , "PGYT_EF_2e", "Tornadotest2_base", "v1_f2", "v2_f2", "v3_f2", "v4_f2", "v5_f2", "v6_f2", "v7_f2", "v8_f2", "v9_f2", "v10_f2", "v11_f2", "v12_f2", "v13_f2", "v14_f2", "v15_f2", "v16_f2", "v17_f2", "v18_f2", "v19_f2", "v20_f2", "v21_f2", "v22_f2"}
ENT.HasLightning = true 
ENT.Subvorts = true
ENT.isderp = false
ENT.speedmult = 0.5
ENT.HeightForceMultiplier = 0 --z tornadic force scaling (height)
ENT.GeneralForceMultiplier = 0 --x and y tornadic force scaling
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "EF2 Tornado" 

function ENT:Initialize()
    if SERVER then
    
        self.Force = math.random(111, 135)    
        local function Picktornadowindfield() --There are 56 different EF-2s total, 34 small EF2s, 13 large EF2s, 5 small mv EF2s, 3 large mv EF2s, and 1 small anticyclonic EF-2
            self.windsizerand = math.random(0,62)
            if self.windsizerand >= 0 and self.windsizerand <= 33 then
                print("Type: EF-2 Small")
                self.Subvorts = false
                self.range = 2800
                self.HeightForceMultiplier = 5.25
                self.GeneralForceMultiplier = 1.4
                self.f2 = {"Twister_EF2","5TonyEF2","5TonyEF211","5TonyEF217","PGYT_EF_2l","PGYT_EF_2","PGYT_EF_2m","PGYT_EF_2n","PGYT_EF_2r","5TonyEF221","5TonyEF222","5TonyEF218","5TonyEF219","PGYT_EF_2f","PGYT_EF_2g","PGYT_EF_2h","PGYT_EF_2i","PGYT_EF_2j","5TonyEF24","5TonyEF26","5TonyEF29","PGYT_EF_2","PGYT_EF_2c", "v6_f2", "v10_f2", "v15_f2", "v16_f2", "v17_f2", "v20_f2", "v21_f2", "v22_f2"}  
            end
            if self.windsizerand >= 34 and self.windsizerand <= 47 then
                print("Type: EF-2 Large")
                self.Subvorts = false
                self.range = 4500
                self.HeightForceMultiplier = 5.1
                self.GeneralForceMultiplier = 1.5
                self.f2 = {"5TonyEF22","PGYT_EF_2o","5TonyEF214","5TonyEF215","5TonyEF212","5TonyEF25","5TonyEF213","5TonyEF27","5TonyEF210","PGYT_EF_2b","PGYT_EF_2d", "Tornadotest2_base", "v1_f2", "v2_f2", "v5_f2", "v11_f2", "v12_f2", "v13_f2", "v14_f2"}  
            end
            if self.windsizerand >= 48 and self.windsizerand <= 53 then
                print("Type: EF-2 Small, Subvorts")
                self.Subvorts = true
                self.range = 3200
                self.HeightForceMultiplier = 5.25
                self.GeneralForceMultiplier = 1.4
                self.f2 = {"PGYT_EF_2k","PGYT_EF_2p","PGYT_EF_2q","5TonyEF23","PGYT_EF_2e", "v3_f2", "v4_f2", "v9_f2"} 
            end
            if self.windsizerand >= 54 and self.windsizerand <= 57 then
                print("Type: EF-2 Large, Subvorts")
                self.Subvorts = true
                self.range = 5000
                self.HeightForceMultiplier = 5.1
                self.GeneralForceMultiplier = 1.5
                self.f2 = {"5TonyEF216","5TonyEF220","5TonyEF28", "v7_f2", "v18_f2"}
            end
            if self.windsizerand >= 58 and self.windsizerand <= 60 and math.random(1, 2) == 1 then
                print("Type: EF-2 Small Anticyclonic")
                self.Subvorts = false
                self.range = 2800
                self.HeightForceMultiplier = 5.25
                self.GeneralForceMultiplier = 1.4
                self.rotforce = 77
                self.f2 = {"v19_f2"}
            end
            if self.windsizerand >= 61 and self.windsizerand <= 62 then
                print("Type: EF-2 Large Anticyclonic")
                self.Subvorts = false
                self.range = 2800
                self.HeightForceMultiplier = 5.25
                self.GeneralForceMultiplier = 1.4
                self.rotforce = 77
                self.f2 = {"v8_f2"}
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
        
        for k, v in ipairs(self.f2) do  

            PrecacheParticleSystem(v)

        end
        
        local u = table.Random(self.f2)

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

