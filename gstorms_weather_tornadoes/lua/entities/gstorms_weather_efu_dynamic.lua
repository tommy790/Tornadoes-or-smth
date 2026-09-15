ENT.Type = "anim"
ENT.Base = "gstorms_base_entity"
ENT.PrintName = "Dynamic Tornado"
ENT.Spawnable = false

ENT.Anticyclonic = false
ENT.Dynamic = true

ENT.MinWindspeed = 0
ENT.MaxWindspeed = 0

ENT.Thunderstorm = true

ENT.WidthTable = {
    {minSize = 50, maxSize = 124, weight = 13},
    {minSize = 125, maxSize = 349, weight = 9},
    {minSize = 350, maxSize = 699, weight = 6},
    {minSize = 700, maxSize = 999, weight = 4},
}

local function GetLerpParams(self)
    local notRainWrapped = math.random(3) > 1

    local strengthTableNormal = {
        {minWS = 65,  maxWS = 85,  weight = 41},
        {minWS = 86,  maxWS = 110, weight = 20},
        {minWS = 111, maxWS = 135, weight = 14},
        {minWS = 136, maxWS = 165, weight = 10},
        {minWS = 166, maxWS = 200, weight = 8},
        {minWS = 201, maxWS = 250, weight = 7},
    }

    local strengthTableAnticyclonic = {
        {minWS = 65,  maxWS = 85,  weight = 52},
        {minWS = 86,  maxWS = 110, weight = 22},
        {minWS = 111, maxWS = 135, weight = 15},
        {minWS = 136, maxWS = 150, weight = 11},
    }

    local regularDeathTable = {
        {minSize = 50, maxSize = 124, weight = 13},
        {minSize = 125, maxSize = 349, weight = 9},
        {minSize = 350, maxSize = 699, weight = 6},
        {minSize = 700, maxSize = 999, weight = 4},
    }

    local widthTable = {
        {minSize = 50, maxSize = 124, weight = 6},
        {minSize = 125, maxSize = 349, weight = 6},
        {minSize = 350, maxSize = 699, weight = 6},
        {minSize = 700, maxSize = 999, weight = 5},
        {minSize = 1000, maxSize = 3000, weight = 4},
    }

    local widthTableAnticyclonic = {
        {minSize = 50, maxSize = 124, weight = 13},
        {minSize = 125, maxSize = 349, weight = 9},
        {minSize = 350, maxSize = 699, weight = 6},
        {minSize = 700, maxSize = 999, weight = 4},
    }

    local ropeOutTable = {
        {minSize = 50, maxSize = 124, weight = 13},
    }

    if self.Autospawn then

        local autospawnParameters = GSEntityPropertiesFromCurrentRisks(self.AutospawnKey)
        strengthTableAnticyclonic = autospawnParameters.strengthTableAnticyclonic
        strengthTableNormal = autospawnParameters.strengthTable
    
    end

    local strengthTableSelected = self.Anticyclonic and strengthTableAnticyclonic or strengthTableNormal

    return {
        [1] = { -- The stages (in order) keep in mind I should be able to add or remove stages, I.E [1] = is stage 1
            stageTimeFrac = math.Rand(0.1, 0.15), -- The weighted fraction out of all of the other stageTimeFracs that it takes to progress to the next stage (out of the entities entire lifetime)
            birth = { -- birth phase ID
                phaseLerpTimeFrac = math.Rand(0.3, 0.5), -- time for this phase much like stageTimeFrac before moving over to the next phase or middle
                widthTable = { -- the width table that GSRandomEntityProperties should use for this phase
                    {minSize = 50, maxSize = 124, weight = 13},
                    {minSize = 125, maxSize = 349, weight = 9},
                    {minSize = 350, maxSize = 699, weight = 6},
                    {minSize = 700, maxSize = 999, weight = 4},
                },
                strengthTable = { -- The strength table that GSRandomEntityProperties should use
                    {minWS = 0, maxWS = 0, weight = 1}
                },
            },
            middle = {
                repeatStages = 1, -- The maximum times that this stage should repeat, the phaseLerpTimeFrac should basically get split among these, I.E if there are 2 repeats and a phaseLerpTimeFrac of 0.4 yields this phase to last 40 seconds of the lifetime, then each repeat of this phase should be 20 seconds long, I.E meaning that this phase gets ran twice before progressing to the next.
                phaseLerpTimeFrac = math.Rand(0.2, 0.4),
                widthTable = {
                    {minSize = 50, maxSize = 124, weight = 13},
                    {minSize = 125, maxSize = 349, weight = 9},
                    {minSize = 350, maxSize = 699, weight = 6},
                    {minSize = 700, maxSize = 999, weight = 4},
                },
                strengthTable = {
                    {minWS = 0, maxWS = 0, weight = 1}
                },
                -- This new section basically lerps to these values by the end of the stage, I.E so these parameters by the time that this stage is over are their respective values established here. Essentially overriding what GSGetEntityProperties returns as the lerp values to use
                paramsToLerpToOverride = {
                    {key = "SupercellParameters.debrisMax", tbl = "SupercellParameters", field = "debrisMax", value = 0},
                    {key = "SupercellParameters.hookMax", tbl = "SupercellParameters", field = "hookMax", value = notRainWrapped and math.Rand(0.9, 1.1) or math.Rand(1, 1.1)},
                    {key = "SupercellParameters.debrisBSize", tbl = "SupercellParameters", field = "debrisBSize", value = math.Rand(0.75, 1)},
                    {key = "SupercellParameters.hookLenSize", tbl = "SupercellParameters", field = "hookLenSize", value = notRainWrapped and math.Rand(0.5, 1) or math.Rand(0.3, 0.6)},
                    {key = "SupercellParameters.hookWidSize", tbl = "SupercellParameters", field = "hookWidSize", value = notRainWrapped and math.Rand(0.9, 1.2) or math.Rand(1.0, 1.2)},
                    {key = "SupercellParameters.hookAngSize", tbl = "SupercellParameters", field = "hookAngSize", value = math.Rand(0.8, 1.2)}
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
            currentStageEntityType = {"Thunderstorm"}, -- This is basically a key that should be set for the entity I.E so this would yield ent.Thunderstorm = true for this current stage, should be set immediately upon entering the stage
        },
        [2] = {
            stageTimeFrac = math.Rand(0.5, 0.7),
            birth = {
                phaseLerpTimeFrac = math.Rand(0.1, 0.2),
                widthTable = {
                    {minSize = 50, maxSize = 124, weight = 13},
                    {minSize = 125, maxSize = 349, weight = 9},
                    {minSize = 350, maxSize = 699, weight = 6},
                    {minSize = 700, maxSize = 999, weight = 4},
                },
                strengthTable = {
                    {minWS = 65, maxWS = 85, weight = 1},
                    {minWS = 86, maxWS = 110, weight = 0},
                    {minWS = 111, maxWS = 135, weight = 0},
                    {minWS = 136, maxWS = 165, weight = 0},
                    {minWS = 166, maxWS = 200, weight = 0},
                    {minWS = 201, maxWS = 250, weight = 0},
                },
            },
            middle = {
                repeatStages = math.random(4),
                phaseLerpTimeFrac = math.Rand(0.4, 0.6),
                widthTable = self.Anticyclonic and widthTableAnticyclonic or widthTable,
                strengthTable = strengthTableSelected
            },
            death = {
                phaseLerpTimeFrac = math.Rand(0.15, 0.3),
                widthTable = math.random(3) == 1 and regularDeathTable or ropeOutTable,
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
            currentStageEntityType = {"Tornado"},
        },
        [3] = {
            stageTimeFrac = math.Rand(0.15, 0.3),
            middle = {
                repeatStages = 1,
                phaseLerpTimeFrac = math.Rand(0.2, 0.4),
                widthTable = {
                    {minSize = 50, maxSize = 124, weight = 10},
                    {minSize = 125, maxSize = 349, weight = 7},
                    {minSize = 350, maxSize = 699, weight = 6},
                    {minSize = 700, maxSize = 999, weight = 4},
                },
                strengthTable = {
                    {minWS = 0, maxWS = 0, weight = 1}
                },
            },
            death = {
                phaseLerpTimeFrac = math.Rand(0.2, 0.4),
                widthTable = {
                    {minSize = 50, maxSize = 124, weight = 10},
                    {minSize = 125, maxSize = 349, weight = 7},
                    {minSize = 350, maxSize = 699, weight = 6},
                    {minSize = 700, maxSize = 999, weight = 4},
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
            currentStageEntityType = {"Thunderstorm"},
        },
    }
end

function ENT:SetupProperties()

    self.MaxLifetimeMult = math.Rand(0.75, 1) * 1.5
    self.Anticyclonic = math.random(20) == 1
    self.HasSetAnticyclonic = true
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