AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 5
ENT.range = math.random(11000,9100)
ENT.Force = 0
ENT.weldf = 50
ENT.rotforce = -220
ENT.f5 = {"Twister_EF5", "5TonyEF5", "5TonyEF511", "5TonyEF52", "5TonyEF520", "5TonyEF521", "PGYT_EF_5d", "5TonyEF522", "PGYT_EF_5b", "PGYT_EF_5c","5TonyEF516", "5TonyEF518", "5TonyEF519", "5TonyEF53", "5TonyEF517", "5TonyEF54", "5TonyEF514", "5TonyEF55", "5TonyEF513",  "5TonyEF56", "5TonyEF57", "5TonyEF58", "5TonyEF59", "5TonyEF510", "El_Grande", "v1_f5", "v2_f5", "v3_f5", "v4_f5", "v5_f5", "v6_f5", "v7_f5", "v8_f5", "v9_f5", "v10_f5", "v11_f5", "v12_f5", "v13_f5", "v14_f5", "v15_f5", "v16_f5", "v17_f5", "v18_f5", "v19_f5", "v20_f5", "v21_f5", "v22_f5", "v23_f5", "v24_f5", "v25_f5", "v26_f5", "v27_f5", "v28_f5", "v29_f5", "v30_f5", "v14_f3"}
ENT.HasLightning = true 
ENT.Subvorts = true 
ENT.isderp = false
ENT.speedmult = 0.6
ENT.HeightForceMultiplier = 25 --z tornadic force scaling (height)
ENT.GeneralForceMultiplier = 1.9 --x and y tornadic force scaling
ENT.PlayerNPCForceMult = 0.2
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "EF5 Tornado" 

function ENT:Initialize()


    if SERVER then

        self.Force = math.random(200, 318)
        local function Picktornadowindfield() --There are 38 different EF-5s total, 15 small EF5s, 14 large EF5s, 5 small mv EF5s, 4 large mv EF5s and the El-Reno Tornado.

            self.windsizerand = math.random(0,34)
            if self.windsizerand >= 0 and self.windsizerand <= 15 then
                print("Type: EF-5 Small")
                    self.Subvorts = false
            self.range = 8000
                    self.f5 = {"Twister_EF5","5TonyEF520","5TonyEF521","PGYT_EF_5c","5TonyEF516","5TonyEF518","5TonyEF517","5TonyEF514","5TonyEF55","5TonyEF56","5TonyEF57","5TonyEF58","5TonyEF59","5TonyEF510","5TonyEF513", "v1_f5", "v2_f5", "v4_f5", "v5_f5", "v7_f5", "v10_f5", "v12_f5", "v17_f5", "v19_f5", "v20_f5", "v21_f5", "v26_f5", "v27_f5", "v28_f5"}  
            end
            if self.windsizerand >= 16 and self.windsizerand <= 22 then
                print("Type: EF-5 Large")
                    self.Subvorts = false
            self.range = 11000
                    self.f5 = {"5TonyEF511","PGYT_EF_5b","5TonyEF519","El_Grande", "v6_f5", "v8_f5", "v11_f5", "v13_f5", "v16_f5", "v18_f5"}  
            end
            if self.windsizerand >= 23 and self.windsizerand <= 33 then
                print("Type: EF-5 Small, Subvorts")
                    self.Subvorts = true
            self.range = 8500
                    self.f5 = {"5TonyEF5","5TonyEF52","PGYT_EF_5d","5TonyEF522","5TonyEF53","5TonyEF54", "v3_f5", "v9_f5", "v15_f5", "v23_f5", "v24_f5", "v25_f5", "v29_f5", "v30_f5"}
            end
            if self.windsizerand >= 34 and self.windsizerand <= 34 then
                print("Type: El-Reno / The Big One.")
                    self.Subvorts = true
            self.range = 17500
                self.f5 = {"v14_f3"}
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
        
        for k, v in ipairs(self.f5) do  

            PrecacheParticleSystem(v)

        end
        
        local u = table.Random(self.f5)

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

