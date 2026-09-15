ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "Landspout / Waterspout Tornado"
ENT.Spawnable = false

ENT.Spout = true
ENT.SubvorticesEnabled = false
ENT.Anticyclonic = false

ENT.MinWindspeed = 65
ENT.MaxWindspeed = 130

ENT.WidthTable = {
    {minSize = 50, maxSize = 99, weight = 50},
    {minSize = 100, maxSize = 174, weight = 40},
    {minSize = 175, maxSize = 200, weight = 30},
}

function ENT:SetupProperties()
    self.MaxLifetimeMult = math.Rand(0.75, 1)

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