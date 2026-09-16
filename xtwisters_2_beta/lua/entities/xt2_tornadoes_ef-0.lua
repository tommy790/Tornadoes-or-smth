AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 0
ENT.range = 2200
ENT.Force = 0
ENT.weldf = math.random(5199, 6499)
ENT.rotforce = -54
ENT.f0 =  {"5TonyEF0", "5TonyEF02", "5TonyEF03", "5TonyEF019", "PGYT_EF_0k" , "PGYT_EF_0l" , "PGYT_EF_0m" , "PGYT_EF_0n" , "PGYT_EF_0o" , "PGYT_EF_0p" , "PGYT_EF_0q" , "PGYT_EF_0r" , "PGYT_EF_0s", "PGYT_EF_0t" , "PGYT_EF_0u" , "PGYT_EF_0v" , "PGYT_EF_0w" , "PGYT_EF_0x" , "PGYT_EF_0y" , "PGYT_EF_0z", "5TonyEF020", "5TonyEF021", "5TonyEF022", "PGYT_EF_0g" , "5TonyEF018", "5TonyEF017", "5TonyEF019", "5TonyEF016", "PGYT_EF_0h" , "PGYT_EF_0i" , "PGYT_EF_0j", "PGYT_EF_0f", "5TonyEF014", "5TonyEF015", "5TonyEF011", "5TonyEF012", "5TonyEF06", "5TonyEF013", "5TonyEF07", "5TonyEF08", "PGYT_EF_0" , "PGYT_EF_0b" , "PGYT_EF_0c" , "PGYT_EF_0d" , "PGYT_EF_0e", "5TonyEF09", "5TonyEF010", "5TonyEF04", "5TonyEF05", "ff_ef0_a1", "v1_f0", "v2_f0", "v3_f0", "v4_f0", "v5_f0", "v6_f0", "v7_f0", "v8_f0", "v9_f0", "v10_f0", "v11_f0", "v12_f0",}
ENT.HasLightning = true 
ENT.Subvorts = true
ENT.isderp = false
ENT.speedmult = 0.45
ENT.HeightForceMultiplier = 0 --z tornadic force scaling (height)
ENT.GeneralForceMultiplier = 0 --x and y tornadic force scaling
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "EF0 Tornado" 

function ENT:Initialize()
  
    if SERVER then

        self.Force = math.random(65, 85)
        local function Picktornadowindfield() --There are 62 different EF-0s total, 19 small EF0, 28 large EF0, 6 small mv EF0, 9 large mv EF0
            self.windsizerand = math.random(0,61)
            if self.windsizerand >= 0 and self.windsizerand <= 18 then
                self.Subvorts = false
                self.range = 1900
                self.HeightForceMultiplier = 4.9
                self.GeneralForceMultiplier = 1.3
                self.f0 = {"5TonyEF0","5TonyEF019","PGYT_EF_0k","PGYT_EF_0u","PGYT_EF_0g","5TonyEF017","PGYT_EF_0f","5TonyEF014","5TonyEF015","5TonyEF07","PGYT_EF_0","5TonyEF010","5TonyEF05", "ff_ef0_a1", "v1_f0", "v2_f0", "v4_f0", "v6_f0", "v8_f0", "v9_f0", "v10_f0", "v12_f0"}  
                if math.random(1, 20) == 1 then
                    self.f0 = {"v5_f0", "v11_f0"}
                    self.rotforce = 54
                    self.ef0anticyclonicflag = true
                    print("Type: EF-0 Small, Anticyclonic")
                end
                if self.ef0anticyclonicflag == false then
                    print("Type: EF-0 Small")
                end
            end
            if self.windsizerand >= 19 and self.windsizerand <= 46 then
                print("Type: EF-0 Large")
                self.Subvorts = false
                self.range = 2800
                self.HeightForceMultiplier = 4.8
                self.GeneralForceMultiplier = 1.4
                self.f0 = {"PGYT_EF_0l","PGYT_EF_0n","PGYT_EF_0o","PGYT_EF_0b","PGYT_EF_0q","PGYT_EF_0r","PGYT_EF_0s","PGYT_EF_0v","PGYT_EF_0x","5TonyEF020","5TonyEF018","PGYT_EF_0h","PGYT_EF_0i","PGYT_EF_0j","5TonyEF06","5TonyEF08","PGYT_EF_0b","PGYT_EF_0c","PGYT_EF_0d","PGYT_EF_0e","5TonyEF09","5TonyEF04", "v7_f0"}
            end
            if self.windsizerand >= 47 and self.windsizerand <= 52 then
                print("Type: EF-0 Small, Subvorts")
                self.Subvorts = true
                self.range = 2200
                self.HeightForceMultiplier = 4.9
                self.GeneralForceMultiplier = 1.3
                self.f0 = {"5TonyEF02","5TonyEF03","PGYT_EF_0w","5TonyEF022","5TonyEF016","5TonyEF012", "v3_f0"} 
            end
            if self.windsizerand >= 53 and self.windsizerand <= 61 then
                print("Type: EF-0 Large, Subvorts")
                self.Subvorts = true
                self.range = 3200
                self.HeightForceMultiplier = 4.8
                self.GeneralForceMultiplier = 1.4
                self.f0 = {"PGYT_EF_0m","PGYT_EF_0t","PGYT_EF_0y","PGYT_EF_0z","5TonyEF021","5TonyEF011","5TonyEF013"}
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

