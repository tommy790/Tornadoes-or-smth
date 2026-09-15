ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "Dynamic Dust Devil"
ENT.Spawnable = false

ENT.DustDevil = true
ENT.Anticyclonic = false
ENT.Dynamic = true
ENT.SubvorticesEnabled = false

ENT.MinWindspeed = 0
ENT.MaxWindspeed = 0

ENT.WidthTable = {
    {minSize = 50, maxSize = 99, weight = 50},
    {minSize = 100, maxSize = 299, weight = 35},
    {minSize = 299, maxSize = 500, weight = 15}
}

local function GetLerpParams(self)

    local strengthTable = {
        {minWS = 24, maxWS = 35, weight = 50},
        {minWS = 36, maxWS = 50, weight = 30},
        {minWS = 51, maxWS = 65, weight = 15},
        {minWS = 66, maxWS = 74, weight = 5},
    }

    if self.Autospawn then strengthTable = GSEntityPropertiesFromCurrentRisks(self.AutospawnKey).strengthTable end

    return {
        [1] = {
            stageTimeFrac = 1,
            birth = {
                phaseLerpTimeFrac = math.Rand(0.15, 0.25),
                widthTable = {
                    {minSize = 100, maxSize = 199, weight = 50},
                    {minSize = 200, maxSize = 299, weight = 35},
                    {minSize = 300, maxSize = 399, weight = 15}
                },
                strengthTable = strengthTable,
            },
            middle = {
                repeatStages = math.random(2),
                phaseLerpTimeFrac = math.Rand(0.45, 0.65),
                widthTable = {
                    {minSize = 100, maxSize = 199, weight = 50},
                    {minSize = 200, maxSize = 299, weight = 35},
                    {minSize = 300, maxSize = 399, weight = 15}
                },
                strengthTable = strengthTable,
            },
            death = {
                phaseLerpTimeFrac = math.Rand(0.15, 0.3),
                widthTable = {
                    {minSize = 100, maxSize = 199, weight = 50},
                    {minSize = 200, maxSize = 299, weight = 35},
                    {minSize = 300, maxSize = 399, weight = 15}
                },
                strengthTable = {
                    {minWS = 0, maxWS = 0, weight = 55},
                },
            },
            paramsToLerp = {
                {key = "VortexWindspeed"},
                {key = "VortexRMWSize"},
                {key = "VortexPositionNoiseAmplitude"},
                {key = "VortexPositionNoiseFrequency"},
                {key = "VortexPositionNoiseSpeed"},
                {key = "VortexPositionNoiseDetail"},
                {key = "VortexPositionNoisePeak"},
            },
            currentStageEntityType = {"DustDevil"},
        },
    }

end

function ENT:SetupProperties()

    self.MaxLifetimeMult = math.Rand(0.1, 0.175)
    self.LerpParams = GetLerpParams(self)

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
