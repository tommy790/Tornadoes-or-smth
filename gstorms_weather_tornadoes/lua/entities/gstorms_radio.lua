ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Radio"
ENT.Spawnable = false

ENT.RadioActiveSound = nil
ENT.RadioNextPlayTime = 0

local soundList = {
    tornado = {sound = "radio/radio_warning.wav", order = 1},
    hurricane = {sound = "radio/hurricane_warning.wav", order = 2},
    derecho = {sound = "radio/derecho_warning.wav", order = 3},
    easteregg = {sound = "radio/real_music.wav", order = 4},
}

local soundLevel = 70
local soundPitch = 100
local soundVolume = 1
local warningCooldown = 51
local thinkDelay = engine.TickInterval() * 60

local function GSGetRadioWarning(warnedEntities)

    local bestOrder, bestSound, bestEntity

    for _, entity in ipairs(gs_weatherEntityList.server) do
            
        if !entity:IsValid() or entity.DustDevil or !entity.EntSetup or warnedEntities[entity] then continue end

        local warningEntry

        if (entity.Tornado or entity.Spout) and entity.VortexWindspeed > 40 then
            warningEntry = soundList.tornado
        elseif entity.Hurricane then
            warningEntry = soundList.hurricane
        elseif entity.Derecho then
            warningEntry = soundList.derecho
        end

        if warningEntry and (!bestOrder or warningEntry.order < bestOrder) then
            bestOrder = warningEntry.order
            bestSound = warningEntry.sound
            bestEntity = entity
            if bestOrder == 1 then break end
        end

    end

    return bestSound, bestEntity

end

function ENT:Initialize()

    self:SetModel( "models/props/cs_office/radio.mdl" )
    self:SetRenderMode( RENDERMODE_TRANSALPHA )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:DrawShadow(true)

    if SERVER then
        self.RadioWarnedEntities = setmetatable({}, {__mode = "k"})

        local phys = self:GetPhysicsObject()
        if phys:IsValid() then phys:Wake() end

        local warningSound, warningEntity = GSGetRadioWarning(self.RadioWarnedEntities)

        if warningSound then
            self:EmitSound(warningSound, soundLevel, soundPitch, soundVolume)
            self.RadioActiveSound = warningSound
            self.RadioWarnedEntities[warningEntity] = true
            self.RadioNextPlayTime = CurTime() + warningCooldown
        elseif GetConVar("gstorms_radio_easteregg"):GetBool() then
            self:EmitSound(soundList.easteregg.sound, soundLevel, soundPitch, soundVolume)
            self.RadioActiveSound = soundList.easteregg.sound
        end
    end
end

function ENT:Think()

    self.CurTime = CurTime()

    if SERVER then
        local warningSound, warningEntity = GSGetRadioWarning(self.RadioWarnedEntities)

        if warningSound and self.CurTime >= self.RadioNextPlayTime then
            if self.RadioActiveSound then self:StopSound(self.RadioActiveSound) end

            self:EmitSound(warningSound, soundLevel, soundPitch, soundVolume)
            self.RadioActiveSound = warningSound
            self.RadioWarnedEntities[warningEntity] = true
            self.RadioNextPlayTime = self.CurTime + warningCooldown
        end
    end

    self:NextThink(self.CurTime + thinkDelay)
    return true

end

function ENT:OnRemove()
    for _, soundEntry in pairs(soundList) do
        self:StopSound(soundEntry.sound)
    end
end