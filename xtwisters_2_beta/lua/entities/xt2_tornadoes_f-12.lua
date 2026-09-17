AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 12
ENT.range = 15000
ENT.Force = 0
ENT.weldf = 2299
ENT.rotforce = -110
ENT.F12 = {"RDTX6_F12"}
ENT.HasLightning = true 
ENT.Subvorts = true 
ENT.isderp = false
ENT.speedmult = 1
ENT.PlayerNPCForceMult = 0.2
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "F12 Tornado" 

function ENT:Initialize()

    if SERVER then

    self.Force = math.random(660, 738)

    print("This tornado's windspeed is " .. self.Force )
	print("This tornado is an F" .. self.sFScale )
	print("Yes the original Fujita Scale went up to 12, no there will never be an E/F6-11")
    self:startx()

    timer.Simple(GetConVar("xt2_tlifetime"):GetInt(), function()
            
        if !self:IsValid() then return
            
        end
            
        self:Remove()
            
    end)

    self:testing2()  
    
    for k, v in ipairs(self.F12) do  

        PrecacheParticleSystem(v)

    end
    
    local u = table.Random(self.F12)

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

