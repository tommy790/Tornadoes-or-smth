AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 100
ENT.range = 10000
ENT.Force = 1000000
ENT.weldf = 6969
ENT.rotforce = -400
ENT.ORB = {"PGYT_Floating_Black_orb"}
ENT.HasLightning = false  
ENT.Subvorts = false  
ENT.isderp = false
ENT.speedmult = 1
ENT.PlayerNPCForceMult = 0.2
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "The Orb." 

function ENT:Initialize()

    if SERVER then

    print("This ORB's windspeed is " .. self.Force )
    print("THE ORB")

    self:startx()

    timer.Simple(GetConVar("xt2_tlifetime"):GetInt(), function()
            
        if !self:IsValid() then return
            
        end
            
        self:Remove()
            
    end)

    self:testing2()  
    
    for k, v in ipairs(self.ORB) do  

        PrecacheParticleSystem(v)

    end
    
    local u = table.Random(self.ORB)

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

