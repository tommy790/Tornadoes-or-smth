ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Mobile Radar"
ENT.Spawnable = false

ENT.RadarName = "Mobile_Radar"
ENT.Resolution = 144 -- Resolution
ENT.Range = 32600 -- Radius
ENT.UpdateRate = 3 -- Seconds
ENT.MaxDistanceSampleHeight = 2000 -- At a maximum distance the height of the radar beam will be (hammer units)

function ENT:Initialize()

    self:SetModel( "models/props_rooftop/roof_dish001.mdl" )
    self:SetRenderMode( RENDERMODE_TRANSALPHA )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:DrawShadow(true)
    self:SetModelScale(2)

    if SERVER then
        local phys = self:GetPhysicsObject()
        if phys:IsValid() then phys:Wake() end
    end

    if CLIENT then
        self.RadarName = self.RadarName.."_"..tostring(self:EntIndex())
    end

end