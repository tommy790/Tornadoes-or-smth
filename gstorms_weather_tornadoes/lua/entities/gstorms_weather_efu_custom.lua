ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "Tornado"
ENT.Spawnable = false
ENT.Tornado = true

function ENT:Initialize()

    self:SetModel("models/props_c17/canister01a.mdl")
    self:SetColor(Color(0, 0, 0, 0))
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    
    self.VortexPositionNoiseSeed = math.random(0, 50000)

    if SERVER then if !util.IsInWorld(self:GetPos()) and self:IsValid() then self:Remove() return end end

end