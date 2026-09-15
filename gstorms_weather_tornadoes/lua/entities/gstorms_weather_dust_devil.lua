ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "Dust Devil"
ENT.Spawnable = false

ENT.DustDevil = true
ENT.Anticyclonic = false
ENT.SubvorticesEnabled = false

ENT.MinWindspeed = 24
ENT.MaxWindspeed = 74

ENT.WidthTable = {
    {minSize = 50, maxSize = 99, weight = 50},
    {minSize = 100, maxSize = 299, weight = 35},
    {minSize = 299, maxSize = 500, weight = 15}
}

function ENT:SetupProperties()
    self.MaxLifetimeMult = math.Rand(0.1, 0.175)

    GSRandomEntityProperties(self)
end

function ENT:Initialize()

    self:SetModel("models/props_c17/canister01a.mdl")
    self:SetColor(Color(0, 0, 0, 0))
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

    if SERVER then 
        if !util.IsInWorld(self:GetPos()) and self:IsValid() then self:Remove() return end
        self:SetupProperties() 
    end

end