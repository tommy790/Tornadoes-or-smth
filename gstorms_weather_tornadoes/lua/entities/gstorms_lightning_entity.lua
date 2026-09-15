ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "GStorms: Lightning Bolt"
ENT.Spawnable = false

ENT.ParticleTypeLightning = {"gstorms_lightning_1", "gstorms_lightning_2"}

ENT.SoundList = {close = {"gstorms_thunderclose1", "gstorms_thunderclose2", "gstorms_thunderclose3", "gstorms_thunderclose4"}, far = {"gstorms_thunderfar1"}, numCloseSounds = 4, numFarSounds = 1}
ENT.NumOfCloseSounds = 4
ENT.NumOfFarSounds = 1

ENT.MaxSoundDistance = 35000
ENT.ThunderCloseSoundDistance = 8000

ENT.MaxDamage = 150
ENT.MaxDamageRadius = 750
ENT.MaxDamageRadiusOnWater = 1250

function ENT:Initialize()

    self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:SetColor( Color( 0, 0, 0, 0 ) )
    self:SetRenderMode( RENDERMODE_TRANSALPHA )
    self:SetMoveType( MOVETYPE_FLY )
    self:SetSolid( SOLID_NONE )
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

    if SERVER then
        if !util.IsInWorld(self:GetPos()) and self:IsValid() then self:Remove() return end
    end

end

ENT.Position = nil
ENT.IsOnWater = false

function ENT:StartEntity()

    GSPrecacheParticleList(self.ParticleTypeLightning)

    self.Position = GSGetGroundPosition(self:GetPos())

    if !self.Position and self:IsValid() then self:Remove() return end

    self.IsOnWater = GSGetOnWater(self.Position)

end

function ENT:RunSound()

    for _, player in player.Iterator() do

        if player:IsValid() and self:IsValid() then

            local distance = self:GetPos():Distance(player:GetPos())
            local soundType = (distance <= self.ThunderCloseSoundDistance) and self.SoundList["close"] or self.SoundList["far"]
            local numberOfSounds = soundType == self.SoundList["close"] and self.SoundList.numCloseSounds or self.SoundList.numFarSounds
            local selectedSound = soundType[math.random(numberOfSounds)]
            local pitchRandom = math.random(80, 120)
            local stringSound = "storms/thunder/" .. selectedSound .. ".wav"

            timer.Simple(GSGetSoundTravelTime(self:GetPos(), player:GetPos()), function()
                if player:IsValid() and self:IsValid() then
                    player:EmitSound(stringSound, 100, pitchRandom, GSGetSoundLevelFromDistance(distance, self.MaxSoundDistance, 1.25))
                end
            end)

        end

    end

end

local function GSElectrocuteEntity(ent)

    if !ent:IsValid() then return end

    local sparks = EffectData()
    sparks:SetOrigin(ent:WorldSpaceCenter())
    sparks:SetMagnitude(2)
    sparks:SetScale(1)
    sparks:SetRadius(16)

    util.Effect("Sparks", sparks, true)

end

function ENT:InjurePlayersAndNPCS()

    local maxRadius = self.IsOnWater and (self.MaxDamageRadiusOnWater) or self.MaxDamageRadius
    local boltPos = self.Position
    local entities = ents.FindInSphere(boltPos, maxRadius)

    for i = 1, #entities do

        local ent = entities[i]

        if ent:IsValid() then

            local isPlayerOrNPC = ent:IsPlayer() or ent:IsNPC()
            local distance = boltPos:Distance(ent:GetPos())

            if distance <= maxRadius and isPlayerOrNPC then

                local entPos = ent:GetPos()

                local roofCheckPhys = util.TraceLine({start = entPos + Vector(0, 0, 100), endpos = entPos + Vector(0, 0, 1000), mask = MASK_SOLID})

                if roofCheckPhys.Hit then return end

                local damageScale = 1 - (distance / maxRadius)
                local damage = self.MaxDamage * damageScale
                local dmgInfo = DamageInfo()

                if (ent:IsPlayer() or ent:IsNPC()) and !GetConVar("gstorms_sim_hurt_players"):GetBool() then return end

                dmgInfo:SetDamage(damage)
                dmgInfo:SetAttacker(self)
                dmgInfo:SetInflictor(self)
                dmgInfo:SetDamageType(DMG_SHOCK)
                dmgInfo:SetDamagePosition(ent:GetPos())
                ent:TakeDamageInfo(dmgInfo)

                GSElectrocuteEntity(ent)

            end
        end
    end
end

function ENT:RunEntity()

    self:StartEntity()

    GSStartParticleEffect(self, "gstorms_lightning_"..tostring(math.random(#self.ParticleTypeLightning)), self.Position)

    self:InjurePlayersAndNPCS()

    timer.Simple(2, function()
        if !self:IsValid() then return end
        self:Remove()
    end)

end

function ENT:Think()

    if self.RanEntity or !self:IsValid() then return end

    if SERVER then
        self:RunEntity()
    elseif CLIENT then
        self:RunSound()
    end

    self.RanEntity = true

    self:NextThink(CurTime())
    return true

end

function ENT:OnRemove() self:StopParticles() end
function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end -- Constant Rendering