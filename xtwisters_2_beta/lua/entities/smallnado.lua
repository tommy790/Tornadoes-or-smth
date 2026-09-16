AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 4
ENT.range = 1020
ENT.Force = 2000
ENT.weldf = 309
ENT.rotforce = -77
ENT.isderp = true
ENT.f2 = {"funnelpen"}
ENT.speedmult = 0.6
ENT.HeightForceMultiplier = 6.5 --z tornadic force scaling (height)
ENT.GeneralForceMultiplier = 1.5 --x and y tornadic force scaling

ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PrintName = "Smallnado" 
ENT.Category = "Perp"

function ENT:Initialize()
    if (CLIENT) then

        if !self:IsValid() then return end
        self.f = CreateSound(self, Sound("EF2roar.wav"))
        self.f:SetSoundLevel( 19000 )
        self.f:ChangeVolume( 1 )

        for i, ply in ipairs( player.GetAll() ) do

            self.f:Play()

        end

    end

    if SERVER then

    print("This tornado's windspeed is " .. self.Force )

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
    if self.f == nil then return end
    self.f:Stop() 

end

