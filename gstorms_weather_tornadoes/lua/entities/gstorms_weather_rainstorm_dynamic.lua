ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "Dynamic Rainstorm"
ENT.Spawnable = false

ENT.Rainstorm = true
ENT.Dynamic = true
ENT.SubvorticesEnabled = false

ENT.MinWindspeed = 0
ENT.MaxWindspeed = 0

ENT.WidthTable = {
    {minSize = 10, maxSize = 149, weight = 50},
    {minSize = 150, maxSize = 299, weight = 40},
    {minSize = 300, maxSize = 499, weight = 30},
}

local function GetLerpParams()

    return {
        [1] = {
            stageTimeFrac = 1,
            birth = {
                phaseLerpTimeFrac = math.Rand(0.15, 0.25),
                widthTable = {
                    {minSize = 10, maxSize = 149, weight = 50},
                    {minSize = 150, maxSize = 299, weight = 40},
                    {minSize = 300, maxSize = 499, weight = 30},
                },
                strengthTable = {
                    {minWS = 0, maxWS = 0, weight = 1},
                },
            },
            middle = {
                repeatStages = math.random(2),
                phaseLerpTimeFrac = math.Rand(0.45, 0.65),
                widthTable = {
                    {minSize = 10, maxSize = 149, weight = 50},
                    {minSize = 150, maxSize = 299, weight = 40},
                    {minSize = 300, maxSize = 499, weight = 30},
                },
                strengthTable = {
                    {minWS = 0, maxWS = 0, weight = 1},
                },
            },
            death = {
                phaseLerpTimeFrac = math.Rand(0.15, 0.3),
                widthTable = {
                    {minSize = 10, maxSize = 149, weight = 50},
                    {minSize = 150, maxSize = 299, weight = 40},
                    {minSize = 300, maxSize = 499, weight = 30},
                },
                strengthTable = {
                    {minWS = 0, maxWS = 0, weight = 1},
                },
                paramsToLerpToOverride = {
                    {key = "StormPrecipitationMultiplier", value = 0},
                    {key = "StormWindspeed", value = 0},
                },
            },
            paramsToLerp = {
                {key = "VortexRMWSize"},
                {key = "VortexPositionNoiseAmplitude"},
                {key = "VortexPositionNoiseFrequency"},
                {key = "VortexPositionNoiseSpeed"},
                {key = "VortexPositionNoiseDetail"},
                {key = "VortexPositionNoisePeak"},
                {key = "StormRFB", isBool = true},
                {key = "StormPrecipitationMultiplier"},
                {key = "StormWindspeed"},
                {key = "SupercellParameters.debrisMax", tbl = "SupercellParameters", field = "debrisMax"},
                {key = "SupercellParameters.hookMax", tbl = "SupercellParameters", field = "hookMax"},
                {key = "SupercellParameters.debrisBSize", tbl = "SupercellParameters", field = "debrisBSize"},
                {key = "SupercellParameters.hookLenSize", tbl = "SupercellParameters", field = "hookLenSize"},
                {key = "SupercellParameters.hookWidSize", tbl = "SupercellParameters", field = "hookWidSize"},
                {key = "SupercellParameters.hookAngSize", tbl = "SupercellParameters", field = "hookAngSize"},
            },
            currentStageEntityType = {"Rainstorm"},
        },
    }

end

function ENT:SetupProperties()

    self.MaxLifetimeMult = math.Rand(0.5, 1)
    self.LerpParams = GetLerpParams()

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