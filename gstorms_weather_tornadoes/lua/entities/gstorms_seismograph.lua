ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Seismograph"
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Spawnable = false

local maxInteractDistance = 100
local maxRenderDistance = 200

ENT.IsSeismograph = true
ENT.MagnitudeExperiencedMax = 0

function ENT:Initialize()

    self:SetModel("models/props_c17/suitcase_passenger_physics.mdl")
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:DrawShadow(false)
	self:SetColor(Color(120, 120, 120, 255))

    if SERVER then self:SetUseType(SIMPLE_USE) end

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then phys:Wake() end

end

if SERVER then

    local out = Vector(0, 0, 0)

    function ENT:Think()

        local curTime = CurTime()
        local selfPos = self:GetPos()
        local magExperienced = GSGetGlobalMagnitude(selfPos, gs_earthquakeList.server, out)
    
        self.MagnitudeExperienced = magExperienced
        self.MagnitudeExperiencedMax = math.max(magExperienced, self.MagnitudeExperiencedMax)

        self:SetNW2Float("MagnitudeExperienced", self.MagnitudeExperienced)
        self:SetNW2Float("MagnitudeExperiencedMax", self.MagnitudeExperiencedMax)

        if (self.NextMagUpdate or 0) < CurTime() then
    
            self.NextMagUpdate = CurTime() + (engine.TickInterval() * 30)
            self:NextThink(self.NextMagUpdate)
    
            return true
    
        end
    
    end

end

function ENT:Use(activator)

    if !SERVER then return end
    if !activator:IsValid() or !activator:IsPlayer() then return end
    if self:GetPos():Distance2D(activator:GetPos()) > maxInteractDistance then return end

    self.MagnitudeExperiencedMax = 0
    self:SetNW2Float("MagnitudeExperiencedMax", nil)

end