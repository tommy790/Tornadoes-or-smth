ENT.Type = "anim"
ENT.Base = "gstorms_base_flow"
ENT.PrintName = "Pyroclastic Flow"
ENT.Spawnable = false

ENT.Flow = true

ENT.FlowWindspeed = 40 -- MPH

ENT.FlowTemperature = 200 -- Celsius
ENT.FlowTemperatureCoolingTime = 30 -- seconds

ENT.FlowLifetime = 30

ENT.FlowRadial = true
ENT.FlowRadialDepth = 10000

ENT.StormPrecipitationMultiplier = 0

function ENT:Initialize()
    
    self:SetModel("models/props_c17/canister01a.mdl")
    self:SetColor(Color(0, 0, 0, 0))
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

    if SERVER then 
        self.FlowWindspeed = math.random(40, 65) 
        if !util.IsInWorld(self:GetPos()) and self:IsValid() then self:Remove() return end
    end

end

function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end -- Constant Rendering