ENT.Type = "anim"
ENT.Base = "gstorms_base_earthquake"
ENT.PrintName = "Magnitude 5"
ENT.Spawnable = false

include("gstorms_funcs/gstorms_shared.lua")

function ENT:Initialize()

    self:SetModel("models/props_c17/canister01a.mdl")
    self:SetColor(Color(0, 0, 0, 0))
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

    if SERVER then
        if !util.IsInWorld(self:GetPos()) and self:IsValid() then self:Remove() return end
        self.Magnitude = math.Round(math.Rand(5, 5.99), 1)
    end

end