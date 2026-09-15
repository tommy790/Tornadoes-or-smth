ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "Dynamic Landspout / Waterspout Tornado"
ENT.Spawnable = false

ENT.SubvorticesEnabled = false
ENT.Anticyclonic = false
ENT.Dynamic = true

ENT.MinWindspeed = 0
ENT.MaxWindspeed = 0

ENT.Thunderstorm = true

ENT.WidthTable = {
    {minSize = 50, maxSize = 124, weight = 14},
    {minSize = 125, maxSize = 299, weight = 8},
    {minSize = 300, maxSize = 699, weight = 4},
    {minSize = 700, maxSize = 999, weight = 2},
}

local function GetLerpParams(self, keyForThunderstormOrRainstorm)

    local strengthTable = {
        {minWS = 65, maxWS = 85, weight = 4},
        {minWS = 86, maxWS = 110, weight = 3},
        {minWS = 111, maxWS = 130, weight = 2},
    }

    if self.Autospawn then strengthTable = GSEntityPropertiesFromCurrentRisks(self.AutospawnKey).strengthTable end

    return {
        [1] = { -- The stages (in order) keep in mind I should be able to add or remove stages, I.E [1] = is stage 1
            stageTimeFrac = math.Rand(0.1, 0.15), -- The weighted fraction out of all of the other stageTimeFracs that it takes to progress to the next stage (out of the entities entire lifetime)
            birth = { -- birth phase ID
                phaseLerpTimeFrac = math.Rand(0.3, 0.5), -- time for this phase much like stageTimeFrac before moving over to the next phase or middle
                widthTable = { -- the width table that GSRandomEntityProperties should use for this phase
                    {minSize = 50, maxSize = 124, weight = 14},
                    {minSize = 125, maxSize = 299, weight = 8},
                    {minSize = 300, maxSize = 699, weight = 4},
                    {minSize = 700, maxSize = 999, weight = 2},
                },
                strengthTable = { -- The strength table that GSRandomEntityProperties should use
                    {minWS = 0, maxWS = 0, weight = 1}
                },
            },
            middle = {
                repeatStages = 1, -- The maximum times that this stage should repeat, the phaseLerpTimeFrac should basically get split among these, I.E if there are 2 repeats and a phaseLerpTimeFrac of 0.4 yields this phase to last 40 seconds of the lifetime, then each repeat of this phase should be 20 seconds long, I.E meaning that this phase gets ran twice before progressing to the next.
                phaseLerpTimeFrac = math.Rand(0.2, 0.4),
                widthTable = {
                    {minSize = 50, maxSize = 124, weight = 14},
                    {minSize = 125, maxSize = 299, weight = 8},
                    {minSize = 300, maxSize = 699, weight = 4},
                    {minSize = 700, maxSize = 999, weight = 2},
                },
                strengthTable = {
                    {minWS = 0, maxWS = 0, weight = 1}
                },
            },
            paramsToLerp = { -- The parameters to lerp for this stage
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
                {key = "SupercellParameters.hookAngSize", tbl = "SupercellParameters", field = "hookAngSize"}
            },
            currentStageEntityType = {keyForThunderstormOrRainstorm}, -- This is basically a key that should be set for the entity I.E so this would yield ent.Thunderstorm = true for this current stage, should be set immediately upon entering the stage
        },
        [2] = {
            stageTimeFrac = math.Rand(0.3, 0.5),
            birth = {
                phaseLerpTimeFrac = math.Rand(0.1, 0.2),
                widthTable = {
                    {minSize = 50, maxSize = 99, weight = 50},
                    {minSize = 100, maxSize = 174, weight = 40},
                    {minSize = 175, maxSize = 200, weight = 30},
                },
                strengthTable = {
                    {minWS = 65, maxWS = 85, weight = 1},
                },
            },
            middle = {
                repeatStages = math.random(2),
                phaseLerpTimeFrac = math.Rand(0.4, 0.6),
                widthTable = {
                    {minSize = 50, maxSize = 99, weight = 50},
                    {minSize = 100, maxSize = 174, weight = 40},
                    {minSize = 175, maxSize = 200, weight = 30},
                },
                strengthTable = strengthTable
            },
            death = {
                phaseLerpTimeFrac = math.Rand(0.15, 0.3),
                widthTable = {
                    {minSize = 50, maxSize = 99, weight = 50},
                    {minSize = 100, maxSize = 174, weight = 40},
                    {minSize = 175, maxSize = 200, weight = 30},
                },
                strengthTable = {
                    {minWS = 0, maxWS = 0, weight = 1},
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
                {key = "VortexModelParameters.alpha", tbl = "VortexModelParameters", field = "alpha"},
                {key = "VortexModelParameters.twoCelled", tbl = "VortexModelParameters", field = "twoCelled"},
                {key = "VortexModelParameters.falloffExponent", tbl = "VortexModelParameters", field = "falloffExponent"},
                {key = "FunnelWidthTable.baseWidth", tbl = "FunnelWidthTable", field = "baseWidth"},
                {key = "FunnelWidthTable.midWidth", tbl = "FunnelWidthTable", field = "midWidth"},
                {key = "FunnelWidthTable.midWidthHeight", tbl = "FunnelWidthTable", field = "midWidthHeight"},
                {key = "FunnelWidthTable.topWidth", tbl = "FunnelWidthTable", field = "topWidth"},
                {key = "FunnelWidthTable.widthExponent", tbl = "FunnelWidthTable", field = "widthExponent"},
                {key = "StormRFB", isBool = true},
                {key = "StormPrecipitationMultiplier"},
                {key = "StormWindspeed"},
                {key = "SupercellParameters.debrisMax", tbl = "SupercellParameters", field = "debrisMax"},
                {key = "SupercellParameters.hookMax", tbl = "SupercellParameters", field = "hookMax"},
                {key = "SupercellParameters.debrisBSize", tbl = "SupercellParameters", field = "debrisBSize"},
                {key = "SupercellParameters.hookLenSize", tbl = "SupercellParameters", field = "hookLenSize"},
                {key = "SupercellParameters.hookWidSize", tbl = "SupercellParameters", field = "hookWidSize"},
                {key = "SupercellParameters.hookAngSize", tbl = "SupercellParameters", field = "hookAngSize"}
            },
            currentStageEntityType = {"Spout"},
        },
        [3] = {
            stageTimeFrac = math.Rand(0.15, 0.3),
            middle = {
                repeatStages = 1,
                phaseLerpTimeFrac = math.Rand(0.2, 0.4),
                widthTable = {
                    {minSize = 50, maxSize = 124, weight = 14},
                    {minSize = 125, maxSize = 299, weight = 8},
                    {minSize = 300, maxSize = 699, weight = 4},
                    {minSize = 700, maxSize = 999, weight = 2},
                },
                strengthTable = {
                    {minWS = 0, maxWS = 0, weight = 1}
                },
            },
            death = {
                phaseLerpTimeFrac = math.Rand(0.2, 0.4),
                widthTable = {
                    {minSize = 50, maxSize = 124, weight = 14},
                    {minSize = 125, maxSize = 299, weight = 8},
                    {minSize = 300, maxSize = 699, weight = 4},
                    {minSize = 700, maxSize = 999, weight = 2},
                },
                strengthTable = {
                    {minWS = 0, maxWS = 0, weight = 1}
                },
                paramsToLerpToOverride = {
                    {key = "StormPrecipitationMultiplier", value = 0},
                    {key = "StormWindspeed", value = 0},
                },
            },
            paramsToLerp = {
                {key = "VortexRMWSize"},
                {key = "StormRFB", isBool = true},
                {key = "StormPrecipitationMultiplier"},
                {key = "StormWindspeed"},
                {key = "SupercellParameters.debrisMax", tbl = "SupercellParameters", field = "debrisMax"},
                {key = "SupercellParameters.hookMax", tbl = "SupercellParameters", field = "hookMax"},
                {key = "SupercellParameters.debrisBSize", tbl = "SupercellParameters", field = "debrisBSize"},
                {key = "SupercellParameters.hookLenSize", tbl = "SupercellParameters", field = "hookLenSize"},
                {key = "SupercellParameters.hookWidSize", tbl = "SupercellParameters", field = "hookWidSize"},
                {key = "SupercellParameters.hookAngSize", tbl = "SupercellParameters", field = "hookAngSize"}
            },
            currentStageEntityType = {keyForThunderstormOrRainstorm},
        },
    }
end

function ENT:SetupProperties()

    local rainstormOrThunderstorm = math.random(2) == 1 and "Thunderstorm" or "Rainstorm"

    self.MaxLifetimeMult = math.Rand(0.75, 1) * 1.5
    self.LerpParams = GetLerpParams(self, rainstormOrThunderstorm)

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