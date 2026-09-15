ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "EF-5 Tornado"
ENT.Spawnable = false

ENT.Tornado = true
ENT.Anticyclonic = false

ENT.MinWindspeed = 201
ENT.MaxWindspeed = 250

ENT.WidthTable = {
    {minSize = 50, maxSize = 124, weight = 5}, -- Rope / Drillbit
    {minSize = 125, maxSize = 349, weight = 5}, -- Small Stovepipe
    {minSize = 350, maxSize = 699, weight = 5}, -- Stovepipe
    {minSize = 700, maxSize = 999, weight = 5}, -- Wedge
    {minSize = 1000, maxSize = 3000, weight = 5}, -- MegaWedge
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