ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "Dynamic Hurricane"
ENT.Spawnable = false

ENT.Hurricane = true
ENT.Anticyclonic = false
ENT.Dynamic = true
ENT.SubvorticesEnabled = false

ENT.MinWindspeed = 0
ENT.MaxWindspeed = 0

ENT.WidthTable = {
    {minSize = 3000, maxSize = 3999, weight = 50},
    {minSize = 4000, maxSize = 4999, weight = 35},
    {minSize = 5000, maxSize = 5999, weight = 15}
}

ENT.VortexModelParameters = {alpha = 0.1, zScale = 4500, twoCelled = 0, falloffExponent = 1}

ENT.VortexPositionNoiseFrequency = 0
ENT.VortexPositionNoiseAmplitude = 0
ENT.VortexPositionNoiseSpeed = 0
ENT.VortexPositionNoiseSeed = 0

ENT.StormPrecipitationMultiplier = 0

local function GetLerpParams(self)

    local strengthTableBirth = {
        {minWS = 74,  maxWS = 95,  weight = 60}, -- Cat 1
    }
    local strengthTableMid = {
        {minWS = 74,  maxWS = 95,  weight = 35},
        {minWS = 96,  maxWS = 110, weight = 30},
        {minWS = 111, maxWS = 129, weight = 25},
        {minWS = 130, maxWS = 156, weight = 20},
        {minWS = 157, maxWS = 170, weight = 15},
    }

    if self.Autospawn then 
        strengthTableMid = GSEntityPropertiesFromCurrentRisks(self.AutospawnKey).strengthTable 
        strengthTableBirth = {{minWS = 25,  maxWS = 38,  weight = 60}}
    end

    return {
        [1] = {
            stageTimeFrac = 1,
            birth = {
                phaseLerpTimeFrac = math.Rand(0.15, 0.25),
                widthTable = {
                    {minSize = 3000, maxSize = 3999, weight = 50},
                    {minSize = 4000, maxSize = 4999, weight = 35},
                    {minSize = 5000, maxSize = 5999, weight = 15}
                },
                strengthTable = strengthTableBirth,
            },
            middle = {
                repeatStages = math.random(2),
                phaseLerpTimeFrac = math.Rand(0.45, 0.65),
                widthTable = {
                    {minSize = 3000, maxSize = 3999, weight = 50},
                    {minSize = 4000, maxSize = 4999, weight = 35},
                    {minSize = 5000, maxSize = 5999, weight = 15}
                },
                strengthTable = strengthTableMid,
            },
            death = {
                phaseLerpTimeFrac = math.Rand(0.15, 0.3),
                widthTable = {
                    {minSize = 3000, maxSize = 3999, weight = 50},
                    {minSize = 4000, maxSize = 4999, weight = 35},
                    {minSize = 5000, maxSize = 5999, weight = 15}
                },
                strengthTable = {
                    {minWS = 0,  maxWS = 0,  weight = 70},
                },
                paramsToLerpToOverride = {
                    {key = "StormPrecipitationMultiplier", value = 0},
                    {key = "StormWindspeed", value = 0},
                },
            },
            paramsToLerp = {
                {key = "VortexWindspeed"},
                {key = "VortexRMWSize"},
                {key = "StormPrecipitationMultiplier"},
                {key = "StormWindspeed"},
                {key = "VortexModelParameters.alpha", tbl = "VortexModelParameters", field = "alpha"},
                {key = "VortexModelParameters.twoCelled", tbl = "VortexModelParameters", field = "twoCelled"},
                {key = "VortexModelParameters.falloffExponent", tbl = "VortexModelParameters", field = "falloffExponent"},
            },
            currentStageEntityType = {"Hurricane"},
        },
    }

end

function ENT:SetupProperties()

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
