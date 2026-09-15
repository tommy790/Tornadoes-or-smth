ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "Derecho"
ENT.Spawnable = false

ENT.Derecho = true
ENT.SubvorticesEnabled = false

ENT.MinWindspeed = 0
ENT.MaxWindspeed = 0

ENT.WidthTable = {
    {minSize = 10, maxSize = 149, weight = 50},
    {minSize = 150, maxSize = 299, weight = 40},
    {minSize = 300, maxSize = 499, weight = 30},
}

function ENT:SetupProperties()
    self.MaxLifetimeMult = math.Rand(0.5, 0.75)

    GSRandomEntityProperties(self)
end

function ENT:Initialize()

    self:SetModel("models/props_c17/canister01a.mdl")
    self:SetColor(Color(0, 0, 0, 0))
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

    self.VortexPositionNoiseSeed = math.random(0, 50000)

    if SERVER then 
        if !util.IsInWorld(self:GetPos()) and self:IsValid() then self:Remove() return end
        self:SetupProperties() 
    end

end