ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Explosion"
ENT.Spawnable = false

ENT.ParticleName = "Volcanic_Explosion_1"

ENT.Yield = 1000 -- tons of TNT
ENT.ChargeSize = 6000 -- Hammer Units (reference radius for PeakOverpressure)
ENT.PeakOverpressure = 15 -- psi at ChargeSize (effective epicenter)
ENT.PressureFalloff = 4 -- exponent for overpressure falloff

ENT.ShockwaveSpeed = 10000 -- HU/s, Think runs every tick * 4
ENT.ShockwaveRadius = 100000 -- max radius shockwave should reach

ENT.PositivePhaseDuration = 1 -- seconds (outward push after arrival)
ENT.NegativePhaseDuration = 0.5 -- seconds (inward suction after positive phase)
ENT.NegativePhaseMultiplier = 0.25 -- Negative Phase Strength Multiplier

ENT.FireballTemperature = 1200 -- °C at FireballSize
ENT.FireballTemperatureFalloff = 1.25 -- exponent for temperature distance falloff
ENT.FireballSize = 1750 -- HU
ENT.FireballCoolingTime = 4 -- seconds

local HU_TO_METERS = 0.01905
local PSI_TO_PA = 6894.757
local AIR_DENSITY = 1.225
local MS_TO_MPH = 2.236936
local MPH_TO_HU_PER_SEC = 23.4667
local BLAST_Q_SCALE = 0.25

local function GetWindspeedAtPositionFromBlastRadius(self, distHU)
    local yieldTons = math.max(self.Yield, 1)
    local W = yieldTons * 1000
    local W13 = W ^ (1 / 3)
    local rM = math.max(distHU * HU_TO_METERS, self.ChargeSize * HU_TO_METERS)
    local r0M = self.ChargeSize * HU_TO_METERS
    local Z = rM / W13
    local Z0 = r0M / W13
    local ratio = Z0 / math.max(Z, Z0)

    local overpressurePSI = self.PeakOverpressure * (ratio ^ self.PressureFalloff)

    if overpressurePSI <= 0 then return 0 end

    local overpressurePa = overpressurePSI * PSI_TO_PA
    local vMPS = math.sqrt(math.max(2 * overpressurePa * BLAST_Q_SCALE / AIR_DENSITY, 0))
    local mph = vMPS * MS_TO_MPH

    return math.max(mph, 0), overpressurePSI
end

local function GetFireballTemperatureAtPos(self, distHU, elapsed)
    if elapsed >= self.FireballCoolingTime then return 0 end

    local r = math.max(distHU, self.FireballSize)
    local ratio = self.FireballSize / r
    local spatial = ratio ^ self.FireballTemperatureFalloff
    local temporal = 1 - (elapsed / self.FireballCoolingTime)

    return self.FireballTemperature * spatial * math.max(temporal, 0)
end

local nilVector = Vector(0, 0, 0)
local damagePlayersMinPressure = 10
local damagePlayersMinWindspeed = 200
local pressureDamageMult = 5
local windDamageMult = 0.05

local function GSDamagePlayersExplosion(ply, volcano, pressurePSI, windspeedMPH)

    if !GetConVar("gstorms_sim_hurt_players"):GetBool() then return end

    if !ply or !ply:IsValid() or !volcano:IsValid() then return end

    pressurePSI = pressurePSI or 0
    windspeedMPH = windspeedMPH or 0

    if ply:IsPlayer() and GSGetIsPlayerInVehicle(ply) then return end

    local pressureMinSubtract = pressurePSI - damagePlayersMinPressure
    if pressureMinSubtract < 0 then pressureMinSubtract = 0 end

    local windMinSubtract = windspeedMPH - damagePlayersMinWindspeed
    if windMinSubtract < 0 then windMinSubtract = 0 end

    if pressureMinSubtract <= 0 and windMinSubtract <= 0 then return end

    local dmgVal = (pressureMinSubtract * pressureDamageMult) + (windMinSubtract * windDamageMult)
    if dmgVal <= 0 then return end

    local dmg = DamageInfo()
    dmg:SetDamage(dmgVal)
    dmg:SetDamageType(DMG_GENERIC)
    dmg:SetAttacker(volcano)
    dmg:SetInflictor(volcano)
    dmg:SetDamageForce(nilVector)
    ply:TakeDamageInfo(dmg)

end

function ENT:Initialize()
    self:SetModel("models/props_c17/canister01a.mdl")
    self:SetColor(Color(0, 0, 0, 0))
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self.StartTime = CurTime()

    if SERVER then GSStartParticleEffect(self, self.ParticleName, self:GetPos(), nilVector) end
end

function ENT:HandleExplosionPhysics()

    local elapsed = self.CurTime - self.StartTime
    local frontTravelTime = self.ShockwaveRadius / self.ShockwaveSpeed
    local totalPhase = self.PositivePhaseDuration + self.NegativePhaseDuration
    local totalLife = frontTravelTime + totalPhase

    if elapsed >= math.max(totalLife, self.FireballCoolingTime) and self:IsValid() then self:Remove() return end

    local pos = self:GetPos()
    local dt = engine.TickInterval() * 4
    local frontRadius = math.min(self.ShockwaveRadius, self.ShockwaveSpeed * elapsed)
    local windOcclusionConvar = GetConVar("gstorms_sim_wind_occlusion"):GetBool()

    for _, ent in ipairs(ents.FindInSphere(pos, frontRadius)) do

        if !ent:IsValid() or ent == self then continue end

        local isPlayer = ent:IsPlayer() or ent:IsNPC()
        local phys = ent:GetPhysicsObject()

        if !phys:IsValid() then continue end

        local isMotionEnabled = phys:IsMotionEnabled()
        local entPos = ent:LocalToWorld(ent:OBBCenter())
        local offset = entPos - pos
        local distHU = offset:Length()

        if distHU <= 0 then continue end

        local tHit = distHU / self.ShockwaveSpeed
        local localT = elapsed - tHit

        if localT < 0 or localT > totalPhase then continue end

        local phaseStrength, phaseDuration

        if localT <= self.PositivePhaseDuration then
            local tPos = localT / self.PositivePhaseDuration
            phaseStrength = 1 - tPos -- +1 → 0 smoothly
            phaseDuration = self.PositivePhaseDuration
        else
            local tNeg = (localT - self.PositivePhaseDuration) / self.NegativePhaseDuration
            phaseStrength = -0.5 * self.NegativePhaseMultiplier * math.sin(tNeg * math.pi) -- 0 → -0.5 → 0
            phaseDuration = self.NegativePhaseDuration
        end

        local wsMPH, pressurePSI = GetWindspeedAtPositionFromBlastRadius(self, distHU)

        wsMPH, pressurePSI = wsMPH * phaseStrength, pressurePSI * phaseStrength

        if wsMPH <= 0 then continue end

        if isPlayer then GSDamagePlayersExplosion(ent, self, pressurePSI, wsMPH) end

        local massFalloff = GSGetMassFalloff(phys:GetMass(), wsMPH)
        local dir = offset:GetNormalized()
        local wsHU = wsMPH * MPH_TO_HU_PER_SEC

        if windOcclusionConvar then wsMPH = GSWindOcclusion(ent, entPos, wsMPH, dir) end

        if ent.IsProbe then

            local explosionWindspeedSources = ent.ExplosionWindspeedSources

            if !explosionWindspeedSources then
                explosionWindspeedSources = {}
                ent.ExplosionWindspeedSources = explosionWindspeedSources
            end

            explosionWindspeedSources[self:EntIndex()] = {windspeed = wsMPH, expire = self.CurTime + (engine.TickInterval() * 5)}

            if ent.ProbeDeployed then continue end

        end

        GSRemoveConstraintsWindspeed(ent, ent:GetPos(), phys, massFalloff, self, wsMPH, isMotionEnabled)
        
        local dv = wsHU * phaseStrength * (dt / math.max(phaseDuration, 0.01))

        if isPlayer then
            ent:SetVelocity(dir * dv * 0.25 * massFalloff)
        else
            phys:AddVelocity(dir * dv * massFalloff)
        end

        if GetFireballTemperatureAtPos(self, distHU, elapsed) > 400 and ent.Ignite then
            if isPlayer and !GetConVar("gstorms_sim_hurt_players"):GetBool() then return end
            ent:Ignite(math.Clamp(self.FireballCoolingTime - elapsed, 0.1, 4), 0)
        end

    end

end

function ENT:Think()
    self.CurTime = CurTime()

    if SERVER then
        self:HandleExplosionPhysics()
        if !self.EmittedSound then
            GSEmitSoundAtAllPlayers(self:GetPos(), self.ShockwaveRadius * 2, 150, 5, math.random(50, 125), "explosion/volcanic_eruption_1.wav")
            self.EmittedSound = true
        end
    end

    self:NextThink(self.CurTime + (engine.TickInterval() * 4))
    return true
end