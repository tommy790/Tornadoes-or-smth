ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Tornado Siren"
ENT.Spawnable = false

local soundList = {{soundFile = "tornado_siren/tornado_siren.wav", loopDurationSeconds = 15}}

function ENT:Initialize()

    self:SetModel("models/es_sth10/siren_001.mdl")
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:DrawShadow(true)
    self.LastSoundPlayTime = 0

    if SERVER then
        local phys = self:GetPhysicsObject()
        if phys:IsValid() then phys:Wake() end
    end

end

function ENT:Think()

    if CLIENT then return end

    local curTime = CurTime()
    local entityList = gs_weatherEntityList.server

    for _, entity in ipairs(entityList) do

        if entity:IsValid() and ((entity.Tornado or entity.Spout) and entity.VortexWindspeed >= 40) then

            if curTime - self.LastSoundPlayTime < soundList[1].loopDurationSeconds then return end

            self:EmitSound(soundList[1].soundFile, 130, 100, 1)
            self.LastSoundPlayTime = curTime

        end

    end

    self:NextThink(curTime + (engine.TickInterval() * 60))
    return true

end

function ENT:OnRemove()
    for _, soundEntry in ipairs(soundList) do
        self:StopSound(soundEntry.soundFile)
    end
end
