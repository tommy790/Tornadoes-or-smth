ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Computer"
ENT.Spawnable = false

local computerHarddriveAmbienceSound = "computer/computer_harddrive_ambience.wav"
local computerHarddriveAmbienceLoopTime = 5
local computerHarddriveAmbienceVolume = 0.25

if SERVER then
    hook.Add("PhysgunPickup", "GS_Computer_PhysgunPickup", function(ply, ent)
        if IsValid(ent) and ent:GetClass() == "gstorms_computer" then
            ent.GSPhysgunHeldBy = ply
        end
    end)

    hook.Add("PhysgunDrop", "GS_Computer_PhysgunDrop", function(ply, ent)
        if IsValid(ent) and ent:GetClass() == "gstorms_computer" then
            if ent.GSPhysgunHeldBy == ply then ent.GSPhysgunHeldBy = nil end
            ent.GSNextUse = CurTime() + 0.15
        end
    end)
end

local function GSStopComputerHarddriveAmbience(ent)

    if !CLIENT then return end

    if ent.GSHarddriveAmbience then
        ent.GSHarddriveAmbience:Stop()
        ent.GSHarddriveAmbience = nil
    end

    ent.GSNextHarddriveAmbience = nil

end

local function GSPlayComputerHarddriveAmbience(ent)

    if !CLIENT or !IsValid(ent) then return end

    ent.GSHarddriveAmbience = ent.GSHarddriveAmbience or CreateSound(ent, computerHarddriveAmbienceSound)
    ent.GSHarddriveAmbience:Stop()
    ent.GSHarddriveAmbience:PlayEx(computerHarddriveAmbienceVolume, 100)
    ent.GSNextHarddriveAmbience = RealTime() + computerHarddriveAmbienceLoopTime

end

function ENT:Initialize()

    self:SetModel("models/props_lab/monitor01a.mdl")
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:DrawShadow(true)

    if SERVER then

        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:SetMass(15)
            phys:Wake()
        end

    end

    if CLIENT then
        GSPlayComputerHarddriveAmbience(self)
    end

end

function ENT:Use(activator, caller, useType, value)

    if CLIENT then return end
    if !IsValid(activator) or !activator:IsPlayer() then return end
    if IsValid(self.GSPhysgunHeldBy) then return end

    local curTime = CurTime()

    if self.GSNextUse and curTime < self.GSNextUse then return end

    self.GSNextUse = curTime + 0.2

    net.Start("gs_computer_use")
    net.WriteEntity(self)
    net.Send(activator)

end

function ENT:Think()

    if CLIENT then

        if !self.GSNextHarddriveAmbience or RealTime() >= self.GSNextHarddriveAmbience then
            GSPlayComputerHarddriveAmbience(self)
        end

        self:NextThink(CurTime() + 0.25)
        return true

    end

end

function ENT:OnRemove()

    if CLIENT then
        GSStopComputerHarddriveAmbience(self)
    end

end