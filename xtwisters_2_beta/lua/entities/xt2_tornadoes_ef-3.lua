AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 3
ENT.range = 7200
ENT.Force = 0
ENT.weldf = 2299
ENT.rotforce = -110
ENT.f3 = {"Twister_EF3", "5TonyEF3", "5TonyEF32", "5TonyEF33", "5TonyEF36", "5TonyEF320", "5TonyEF321", "5TonyEF322", "5TonyEF318", "5TonyEF319", "5TonyEF37", "5TonyEF317", "5TonyEF316", "PGYT_EF_3c", "5TonyEF314", "5TonyEF315", "5TonyEF38", "5TonyEF312", "PGYT_EF_3d", "5TonyEF313",  "5TonyEF311", "5TonyEF39", "5TonyEF310", "5TonyEF34", "5TonyEF35", "v1_f3", "v2_f3", "v3_f3", "v4_f3", "v5_f3", "v6_f3", "v7_f3", "v8_f3", "v9_f3", "v10_f3", "v11_f3", "v12_f3", "v13_f3", "v15_f3", "v16_f3", "v17_f3", "v18_f3", "v19_f3", "v20_f3", "v21_f3", "v22_f3", "v23_f3", "v24_f3"}
ENT.HasLightning = true 
ENT.Subvorts = true 
ENT.isderp = false
ENT.speedmult = 0.55
ENT.HeightForceMultiplier = 10.0 --z tornadic force scaling (height)
ENT.GeneralForceMultiplier = 1.45 --x and y tornadic force scaling
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "EF3 Tornado" 

function ENT:Initialize()

    if SERVER then

        self.Force = math.random(136, 165)
        local function Picktornadowindfield() --There are 41 different EF-3s total, 21 small EF3s, 14 large EF3s, 3 small mv EF3s, 3 large mv EF3s
            self.windsizerand = math.random(0,44)
            if self.windsizerand >= 0 and self.windsizerand <= 20 then
                print("Type: EF-3 Small")
                    self.Subvorts = false
            self.range = 4500
                    self.f3 = {"Twister_EF3","5TonyEF3","5TonyEF32","5TonyEF33","5TonyEF320","5TonyEF322","5TonyEF319","PGYT_EF_3c","5TonyEF313","5TonyEF39","5TonyEF310","PGYT_EF_4b","5TonyEF415","5TonyEF412", "v1_f3", "v4_f3", "v5_f3", "v7_f3", "v11_f3", "v13_f3", "v17_f3"}  
            end
            if self.windsizerand >= 21 and self.windsizerand <= 34 then
                print("Type: EF-3 Large")
                    self.Subvorts = false
            self.range = 7500
                    self.f3 = {"5TonyEF36","5TonyEF321","5TonyEF318","5TonyEF317","5TonyEF316","5TonyEF315","5TonyEF312","PGYT_EF_3d","5TonyEF34", "v6_f3", "v8_f3", "v9_f3", "v12_f3", "v15_f3", "v16_f3"}  
            end
            if self.windsizerand >= 35 and self.windsizerand <= 37 then
                print("Type: EF-3 Small, Subvorts")
                    self.Subvorts = true
            self.range = 5000
                    self.f3 = {"5TonyEF314","5TonyEF35", "v2_f3", "v3_f3", "v20_f3", "v21_f3", "v23_f3", "v24_f3"} 
            end
            if self.windsizerand >= 38 and self.windsizerand <= 40 then
                print("Type: EF-3 Large, Subvorts")
                    self.Subvorts = true
                    self.range = 8000
                    self.f3 = {"5TonyEF37","5TonyEF38","5TonyEF311", "v10_f3"}
            elseif self.windsizerand >= 41 and self.windsizerand <= 42 then
                print("Type: EF-3 Small, Anticyclonic")
                self.range = 4500
                self.rotforce = 110
                self.f3 = {"v18_f3", "v19_f3"}
            elseif self.windsizerand >= 43 and self.windsizerand <= 44 then
                print("Type : EF-3 Large, Anticyclonic")
                self.range = 7500
                self.rotforce = 110
                self.f3 = {"v22_f3"}
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

