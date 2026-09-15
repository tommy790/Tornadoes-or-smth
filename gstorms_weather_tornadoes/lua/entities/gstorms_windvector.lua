ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Wind Vector"
ENT.Spawnable = false

ENT.GSWindVector = true
ENT.RecordedWindspeed = 0

local out = Vector(0, 0, 0)
local tickDelay = engine.TickInterval() * 8

function ENT:Initialize()
    
    self:SetModel("models/hunter/plates/plate1x4x2trap1.mdl")
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetModelScale(1)
    self:SetMaterial("models/debug/debugwhite")
    self.AppliedVelocity = Vector(1, 0, 0)

    local phys = self:GetPhysicsObject()

    if !phys:IsValid() then return end

    phys:EnableMotion(false)
    phys:EnableGravity(false)
    phys:EnableDrag(false)
    phys:SetMass(1)

end

function ENT:Think()
    if CLIENT then return end

    local windspeed, vec = GSGetGlobalWindspeedAndVectors(self:GetPos(), gs_weatherEntityList.server, GetConVar("gstorms_tornado_inflow_jet"):GetBool(), gs_env.server, CurTime(), out)

    self.CurrentVec = Vector(vec.x, vec.y, 0):Angle() + Angle(0, 180, 0)

    if windspeed > 0 then self:SetAngles(self.CurrentVec)  end

    self.RecordedWindspeed = windspeed

    self:SetColor(GSReturnColorForWindspeed(self.RecordedWindspeed or 0, false))
    self:NextThink(CurTime() + (tickDelay))

    return true
end