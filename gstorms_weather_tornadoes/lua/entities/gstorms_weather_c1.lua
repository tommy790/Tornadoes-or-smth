ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "Category 1 Hurricane"
ENT.Spawnable = false

ENT.Hurricane = true 
ENT.Anticyclonic = false
ENT.SubvorticesEnabled = false

ENT.MinWindspeed = 74
ENT.MaxWindspeed = 95

ENT.WidthTable = {
    {minSize = 3000, maxSize = 3999, weight = 50},
    {minSize = 4000, maxSize = 4999, weight = 35},
    {minSize = 5000, maxSize = 5999, weight = 15}
}

ENT.VortexModelParameters = {alpha = 0.1, zScale = 4500, twoCelled = 0, falloffExponent = 1}

ENT.VortexPositionNoiseFrequency = 0
ENT.VortexPositionNoiseAmplitude = 0
ENT.VortexPositionNoiseSpeed = 0
ENT.VortexPositionNoiseSeed = 0

function ENT:SetupProperties()
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