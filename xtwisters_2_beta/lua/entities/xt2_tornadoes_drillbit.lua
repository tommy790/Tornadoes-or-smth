AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 5
ENT.range = 3750
ENT.Force = 0
ENT.weldf = 30
ENT.rotforce = -77
ENT.f5 = {"RDT1_EF5", "RDTX2_Drillbit1", "5TonyEF515", "v14_f5", "v22_f5"}
ENT.HasLightning = true 
ENT.Subvorts = true 
ENT.isderp = false
ENT.speedmult = 0.6
ENT.isTornado = true
ENT.InnerFunnelDistance = 400

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Drillbit Tornado" 

function ENT:Initialize()

    if SERVER then

        self.Force = math.random(160, 318)
        local function Picktornadowindfield() --There are 4 different Drillbits total
            self.windsizerand = math.random(0,3)
            if self.windsizerand >= 0 and self.windsizerand <= 0 then
                print("Type: Drillbit Small")
                    self.Subvorts = false
            self.range = 4000
                    self.f5 = {"RDT1_EF5"}  
            end
            if self.windsizerand >= 1 and self.windsizerand <= 1 then
                print("Type: Drillbit Large")
                    self.Subvorts = false
            self.range = 5000
                    self.f5 = {"5TonyEF515"}  
            end
            if self.windsizerand >= 2 and self.windsizerand <= 2 then
                print("Type: Drillbit Small, Subvorts")
                    self.Subvorts = true
            self.range = 4250
                    self.f5 = {"RDTX2_Drillbit1"} 
            end
            if self.windsizerand >= 3 and self.windsizerand <= 3 then
                print("Type: Drillbit Small")
                self.Subvorts = true
                self.range = 5500
                self.f5 = {"v14_f5", "v22_f5"}
            end
        end
        Picktornadowindfield()

        local function GetFujita()
            
            if self.Force < 65 then
                self.sFScale = 0
            end
        
            if self.Force >= 65 and self.Force <= 85 then
                self.sFScale = 0
            end
        
            if self.Force >= 86 and self.Force <= 110 then
                self.sFScale = 1
            end
        
            if self.Force >= 111 and self.Force <= 135 then
                self.sFScale = 2
            end
        
            if self.Force >= 136 and self.Force <= 165 then
                self.sFScale = 3
            end
        
            if self.Force >= 166 and self.Force <= 200 then
                self.sFScale = 4
            end
        
            if self.Force >= 201 then
                self.sFScale = 5
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

