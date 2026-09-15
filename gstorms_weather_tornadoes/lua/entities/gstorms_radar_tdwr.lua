ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "TDWR Radar"
ENT.Spawnable = false

ENT.RadarName = "TDWR"
ENT.Resolution = 84 -- Resolution
ENT.Range = 68600 -- Radius
ENT.UpdateRate = 6 -- Seconds
ENT.MaxDistanceSampleHeight = 7000 -- At a maximum distance the height of the radar beam will be (hammer units)

function ENT:Initialize()

    self:SetModel( "models/wsr88d.mdl" )
    self:SetMaterial("models/props/wsr88d")
    self:SetRenderMode( RENDERMODE_TRANSALPHA )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:DrawShadow(true)
    self:SetModelScale(0.75)
    self:SetColor(Color(195, 195, 195))

    if SERVER then
        local phys = self:GetPhysicsObject()
        if phys:IsValid() then phys:Wake() end
    end

    if CLIENT then
        self.RadarName = self.RadarName.."_"..tostring(self:EntIndex())
    end

end