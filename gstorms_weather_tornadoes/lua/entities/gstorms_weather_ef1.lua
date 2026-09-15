ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "EF-1 Tornado"
ENT.Spawnable = false

ENT.Tornado = true
ENT.Anticyclonic = false

ENT.MinWindspeed = 86
ENT.MaxWindspeed = 110

ENT.WidthTable = {
    {minSize = 50, maxSize = 124, weight = 13},
    {minSize = 125, maxSize = 349, weight = 9},
    {minSize = 350, maxSize = 699, weight = 6},
    {minSize = 700, maxSize = 999, weight = 3},
}

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

    self.VortexPositionNoiseSeed = math.random(0, 50000)

    if SERVER then 
        if !util.IsInWorld(self:GetPos()) and self:IsValid() then self:Remove() return end
        self:SetupProperties() 
    end

end