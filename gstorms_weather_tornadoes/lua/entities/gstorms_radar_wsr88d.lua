ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "WSR-88D Doppler Weather Radar"
ENT.Spawnable = false

ENT.RadarName = "WSR-88D"
ENT.Resolution = 128 -- Resolution
ENT.Range = 175000 -- Radius
ENT.UpdateRate = 12 -- Seconds
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
    self:SetModelScale(1)
    self:SetColor(Color(195, 195, 195))

    if SERVER then
        local phys = self:GetPhysicsObject()
        if phys:IsValid() then phys:Wake() end
    end

    if CLIENT then
        self.RadarName = self.RadarName.."_"..tostring(self:EntIndex())
    end

end