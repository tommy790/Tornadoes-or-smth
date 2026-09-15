ENT.Type = "anim"
ENT.Base = "gstorms_base_flow"
ENT.PrintName = "Sandstorm"
ENT.Spawnable = false

ENT.Flow = true

ENT.FlowWindspeed = 60

ENT.FlowTemperature = 0

ENT.FlowLifetime = 60

ENT.FlowLinear = true
ENT.FlowLinearWidth = 15000
ENT.FlowLinearLength = 30000
ENT.FlowLinearDirection = Vector(1, 0, 0)

ENT.StormPrecipitationMultiplier = 0

function ENT:Initialize()
    
    self:SetModel("models/props_c17/canister01a.mdl")
    self:SetColor(Color(0, 0, 0, 0))
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

    if SERVER then 
        self.FlowWindspeed = math.random(40, 85) 
        self.FlowLinearDirection = GSGetNormVecNoZ(1)
        if !util.IsInWorld(self:GetPos()) and self:IsValid() then self:Remove() return end
    end

end

function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end -- Constant Rendering