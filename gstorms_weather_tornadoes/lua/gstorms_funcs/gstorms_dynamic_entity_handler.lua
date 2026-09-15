if CLIENT then return end

local funnelLerpEntityTypes = {Tornado = true, Spout = true, Waterspout = true, Landspout = true}
local stageEntityTypeResetList = {"Thunderstorm","Rainstorm","Spout","Tornado","Waterspout","Landspout","DustDevil","Hurricane","Derecho"}

local defaultCondensationThresholdLookAheadMin = 15
local defaultCondensationThresholdLookAheadMax = 40

local function GSResetSubvConfig(ent)
    ent.SubvConfigSet = false
    ent.SubvConfig = nil
end

local function GSGetWeightedEntry(tbl, weightKey, fallbackIndex)
    local total = 0
    for i = 1, #tbl do total = total + (tbl[i][weightKey] or 0) end
    if total <= 0 then return tbl[fallbackIndex or 1] end

    local pick = math.Rand(0, total)
    local accum = 0

    for i = 1, #tbl do
        accum = accum + (tbl[i][weightKey] or 0)
        if pick <= accum then return tbl[i] end
    end

    return tbl[#tbl]
end

local function GSGetEntryValue(src, entry)
    if entry.tbl then
        local t = src[entry.tbl]
        return t and t[entry.field]
    end

    return src[entry.key]
end

local function GSSetEntryValue(dst, entry, v, ensureTbl)
    if entry.tbl then
        local t = dst[entry.tbl]

        if !t and ensureTbl then
            t = {}
            dst[entry.tbl] = t
        end

        if t then t[entry.field] = v end
    else
        dst[entry.key] = v
    end
end

local function GSEnsureEntHasEntryFromTarget(ent, target, entry)
    local to = GSGetEntryValue(target, entry)
    if to == nil then return end

    if entry.tbl then
        ent[entry.tbl] = ent[entry.tbl] or {}

        if ent[entry.tbl][entry.field] == nil then
            ent[entry.tbl][entry.field] = to
        end

        return
    end

    local from = ent[entry.key]

    if from == nil or (entry.key == "VortexRMWSize" and from <= 0) then
        ent[entry.key] = to
    end
end

local function GSBuildPrevTargetsFromEnt(ent, stage)
    local prev = {}
    local lst = stage and stage.paramsToLerp or nil

    if lst then
        for i = 1, #lst do
            local entry = lst[i]

            if entry then
                local v = GSGetEntryValue(ent, entry)
                if v ~= nil then GSSetEntryValue(prev, entry, v, true) end
            end
        end
    end

    prev.FunnelStartHeight = ent.FunnelStartHeight or ent.FunnelMaxHeight or 0

    return prev
end

local function GSStageUsesFunnelLerp(stage)
    local t = stage and stage.currentStageEntityType
    if !t then return false end

    for i = 1, #t do
        if funnelLerpEntityTypes[t[i]] then return true end
    end

    return false
end

local function GSEnabledPhase(stage, phaseType)
    local p = stage and stage[phaseType] or nil
    if !p then return false end

    local frac = p.phaseLerpTimeFrac

    return frac == nil or frac > 0
end

local function GSSelectPhase(stage)
    if GSEnabledPhase(stage, "birth") then return "birth", 0 end
    if GSEnabledPhase(stage, "middle") then return "middle", 1 end
    if GSEnabledPhase(stage, "death") then return "death", 0 end

    return "middle", 1
end

local function GSResetStagePhaseState(ent)
    ent.FunnelBirthStartTime = nil
    ent.FunnelBirthActive = false
    ent.FunnelDeathStartTime = nil
    ent.FunnelDeathActive = false
    ent.DeathFunnelInit = false
    ent.IgnoreCondensationThreshold = false
end

local function GSApplyParamsToLerpOverride(ent, stage, phaseTbl)
    local target = ent.LerpTargets
    if !target then return end

    local override = (phaseTbl and phaseTbl.paramsToLerpToOverride) or (stage and stage.paramsToLerpToOverride) or nil
    if !override then return end

    for i = 1, #override do
        local entry = override[i]

        if entry and entry.value ~= nil then
            GSSetEntryValue(target, entry, entry.isBool and (entry.value and true or false) or entry.value, true)
        end
    end
end

local function GSSetStageEntityType(ent, stage)
    for i = 1, #stageEntityTypeResetList do
        ent[stageEntityTypeResetList[i]] = false
    end

    ent.GSStageEntityTypeKeys = stage and stage.currentStageEntityType or nil

    if ent.GSStageEntityTypeKeys then
        for i = 1, #ent.GSStageEntityTypeKeys do
            ent[ent.GSStageEntityTypeKeys[i]] = true
        end
    end
end

local function GSInitCondensationThresholdLookAheadOffset(ent)
    if ent.CondensationThresholdLookAheadOffset == nil then
        ent.CondensationThresholdLookAheadOffset = math.random(defaultCondensationThresholdLookAheadMin, defaultCondensationThresholdLookAheadMax)
    end

    return ent.CondensationThresholdLookAheadOffset
end

local function GSSetCondensationThresholdLookAhead(ent)
    ent.CondensationThresholdLookAhead = (ent.CondensationThreshold or 0) + GSInitCondensationThresholdLookAheadOffset(ent)

    return ent.CondensationThresholdLookAhead
end

local function GSGetCondensationThresholdFunnelLerp(ent, windspeed, weakening)
    local condThresh = ent.CondensationThreshold or 0
    local lookAhead = ent.CondensationThresholdLookAhead or GSSetCondensationThresholdLookAhead(ent)
    local denom = lookAhead - condThresh

    if denom <= 0 then
        return weakening and (windspeed <= condThresh and 1 or 0) or (windspeed >= condThresh and 1 or 0)
    end

    local t = math.Clamp((windspeed - condThresh) / denom, 0, 1)

    return weakening and (1 - t) or t
end

function GSDynamicTouchdowns(ent, curTime) -- For static tornadoes

    local d = ent.DynamicTouch

    if !d then

        local torOrSpout = ent.Tornado or ent.Spout
        local ws = ent.VortexWindspeed
        GSSetCondensationThresholdLookAhead(ent)

        local noCondThresh = !torOrSpout or ws <= ent.CondensationThreshold or ent.FunnelStartHeight >= ent.FunnelMaxHeight

        d = {noCond = noCondThresh, startingWS = 0, targetWS = ws, strengthLerpT = ent.MaxLifetime * math.Rand(0.4, 0.475), startH = ent.FunnelMaxHeight, lerpH = ent.FunnelStartHeight, rmwStart = ent.VortexRMWSize}
        ent.DynamicTouch = d
        
        if !noCondThresh then ent.FunnelStartHeight = ent.FunnelMaxHeight end

    end

    if d.Completed then return end

    local lifeT = math.Clamp((curTime - ent.EntityStartTime) / d.strengthLerpT, 0, 1)

    ent.VortexWindspeed = Lerp(lifeT, d.startingWS, d.targetWS)

    local condT = GSGetCondensationThresholdFunnelLerp(ent, ent.VortexWindspeed, false)

    if !d.noCond then
        ent.FunnelStartHeight = Lerp(condT, d.startH, d.lerpH)
        ent.VortexRMWSize = Lerp(condT, d.rmwStart * 0.1, d.rmwStart)
    end

    if !d.subvReset and condT >= 1 then
        d.subvReset = true
        GSResetSubvConfig(ent)
    end

    if lifeT >= 1 then d.Completed = true end

end

function GSDynamicLifts(ent, curTime)

    local touch = ent.DynamicTouch
    if !touch or !touch.Completed then return end

    local age = curTime - ent.EntityStartTime
    local d = ent.DynamicLift

    if !d then
        local strengthLerpT = ent.MaxLifetime * math.Rand(0.4, 0.475)
        local strengthLerpStart = ent.MaxLifetime - strengthLerpT

        if age < strengthLerpStart then return end

        local torOrSpout = ent.Tornado or ent.Spout
        local ws = ent.VortexWindspeed
        GSSetCondensationThresholdLookAhead(ent)

        d = {noCond = !torOrSpout or ws <= ent.CondensationThreshold or ent.FunnelStartHeight >= ent.FunnelMaxHeight, startingWS = ws, targetWS = 0, strengthLerpT = strengthLerpT, strengthLerpStart = strengthLerpStart, startH = ent.FunnelMaxHeight, lerpH = ent.FunnelStartHeight, rmwStart = ent.VortexRMWSize}
        ent.DynamicLift = d
    end

    local lifeT = math.Clamp((age - d.strengthLerpStart) / d.strengthLerpT, 0, 1)

    ent.VortexWindspeed = Lerp(lifeT, d.startingWS, d.targetWS)

    local condT = GSGetCondensationThresholdFunnelLerp(ent, ent.VortexWindspeed, true)

    if !d.noCond then
        ent.FunnelStartHeight = Lerp(condT, d.lerpH, d.startH)
        ent.VortexRMWSize = Lerp(condT, d.rmwStart, d.rmwStart * 0.1)
    end

end

local subv_noise_presets = {
	[1] = {ampMin = 0.55, ampMax = 2, freqMin = 0.00085, freqMax = 0.00110, speedMin = 1800, speedMax = 2600, detailMin = 1.25, detailMax = 1.75, peakMin = 0.48, peakMax = 0.62},
	[2] = {ampMin = 0.90, ampMax = 3, freqMin = 0.00055, freqMax = 0.00085, speedMin = 1200, speedMax = 1900, detailMin = 1.25, detailMax = 2, peakMin = 0.68, peakMax = 0.82},
	[3] = {ampMin = 0.75, ampMax = 1.5, freqMin = 0.0003, freqMax = 0.0005, speedMin = 2500, speedMax = 4500, detailMin = 1.5, detailMax = 2, peakMin = 0.4, peakMax = 0.6},
	[4] = {ampMin = 1.15, ampMax = 5, freqMin = 0.00220, freqMax = 0.004, speedMin = 3800, speedMax = 6000, detailMin = 0.70, detailMax = 1.00, peakMin = 0.52, peakMax = 1},
	[5] = {ampMin = 2.5, ampMax = 4.5, freqMin = 0.00340, freqMax = 0.006, speedMin = 3800, speedMax = 5600, detailMin = 0.5, detailMax = 0.6, peakMin = 0.5, peakMax = 0.75},
	[6] = {ampMin = 1, ampMax = 3, freqMin = 0.00100, freqMax = 0.004, speedMin = 4000, speedMax = 5600, detailMin = 1.5, detailMax = 2, peakMin = 0.30, peakMax = 0.7},
	[7] = {ampMin = 0.5, ampMax = 1, freqMin = 0.00012, freqMax = 0.00025, speedMin = 2500, speedMax = 5000, detailMin = 3.00, detailMax = 4.00, peakMin = 0.25, peakMax = 0.75}
}

function GSGetSubvortexParticleShape(ent, subvortex)

    local heightCondition = ent.FunnelMaxHeight * 0.7
    local condition1 = ent.FunnelStartHeight ~= 0 and ent.FunnelStartHeight <= heightCondition

    ent.SubvConfig = !ent.SubvConfigSet and math.random(2) or ent.SubvConfig

    if !ent.SubvConfigSet and ent.FunnelStartHeight >= 1000 and ent.FunnelStartHeight <= heightCondition and math.random(3) == 1 then ent.SubvConfig = 4 end
    if !ent.SubvConfigSet and ent.VortexRMWSize < 200 and math.random(4) == 1 and ent.FunnelStartHeight ~= 0 and ent.FunnelStartHeight < heightCondition then ent.SubvConfig = 5 end
    if ent.VortexModelParameters.twoCelled <= 0.5 and condition1 and !ent.SubvConfigSet and math.random(5) == 1 and ent.VortexRMWSize > 500 then ent.SubvConfig = 3 end
    if condition1 and ent.VortexRMWSize >= 400 and math.random(6) == 1 and !ent.SubvConfigSet then ent.SubvConfig = 6 end
    if condition1 and ent.FunnelStartHeight >= 1000 and ent.VortexRMWSize >= 400 and math.random(7) == 1 and !ent.SubvConfigSet then ent.SubvConfig = 7 end

    ent.SubvConfigSet = true

    local startHeight = 0
    local vModelParams = {alpha = math.Rand(0.3, 0.7), zScale = 4500, twoCelled = 1, falloffExponent = math.Rand(0.8, 1.2)}
    local orbitRadius, vSizeSelect, funnelWidthTable, maxHeight, lifetime
    local vortexPositionNoiseSeed = math.random(100000)

    if ent.SubvConfig == 1 then -- Medium range subvortices, small to medium, short height, generic appearance
        ent.SubvortexMaxCount = 5
        ent.SubvortexSpawnChance = 50
        orbitRadius = math.random(ent.VortexRMWSize * 0.75, math.max(ent.VortexSize * 0.04, ent.VortexRMWSize * 1.25))
        vSizeSelect = math.random(ent.VortexRMWSize * 0.075, ent.VortexRMWSize * 0.15)
        funnelWidthTable = {baseWidth = 1, midWidth = math.Rand(1.5, 2.5), topWidth = math.Rand(2.5, 3), widthExponent = math.Rand(0.8, 1.2)}
        maxHeight = math.random(400, 750)
        lifetime = math.Rand(8, 12)
    elseif ent.SubvConfig == 2 then -- Medium range subvortices, medium to large, medium height, generic appearance
        ent.SubvortexMaxCount = 5
        ent.SubvortexSpawnChance = 65
        orbitRadius = math.random(ent.VortexRMWSize * 0.75, math.max(ent.VortexSize * 0.0625, ent.VortexRMWSize * 1.5))
        vSizeSelect = math.random(ent.VortexRMWSize * 0.25, ent.VortexRMWSize * 0.3)
        funnelWidthTable = {baseWidth = 1, midWidth = math.Rand(1.5, 2), topWidth = math.Rand(2, 3), widthExponent = math.Rand(0.8, 1.2)}
        maxHeight = math.random(400, 1000)
        lifetime = math.Rand(8, 15)
    elseif ent.SubvConfig == 3 then -- Small range subvortices, medium to large, small to large height, connects to funnel start height if funnel start height meets the requirements
        ent.SubvortexMaxCount = 4
        ent.SubvortexSpawnChance = 30
        orbitRadius = math.random(ent.VortexRMWSize * 0.75, ent.VortexRMWSize)
        vSizeSelect = math.random(ent.VortexRMWSize * 0.2, ent.VortexRMWSize * 0.3)
        funnelWidthTable = {baseWidth = 1, midWidth = math.Rand(1.5, 2), topWidth = math.Rand(2, 3), widthExponent = math.Rand(0.8, 1.2)}
        maxHeight = (ent.FunnelStartHeight >= heightCondition and math.random(400, 1000)) or (ent.FunnelStartHeight == 0 and math.random(400, 1000)) or math.min(ent.FunnelStartHeight, 2500) + 250
        lifetime = math.Rand(8, 12)
    elseif ent.SubvConfig == 4 then -- Segmented subvortices, create helical structures and such as well as being very randomized
        ent.SubvortexMaxCount = 5
        ent.SubvortexSpawnChance = 40
        orbitRadius = math.random(ent.VortexRMWSize * 0.75, math.max(ent.VortexSize * 0.04, ent.VortexRMWSize * 1.5))
        vSizeSelect = math.random(ent.VortexRMWSize * 0.075, ent.VortexRMWSize * 0.15)
        funnelWidthTable = {baseWidth = 1, midWidth = math.Rand(1.5, 2.5), topWidth = math.Rand(2.5, 3), widthExponent = math.Rand(0.8, 1.2)}
        maxHeight = math.random(500, math.min(ent.FunnelStartHeight, 2000))
        startHeight = math.random(3) != 1 and maxHeight * math.Rand(0.6, 0.8) or maxHeight >= 1500 and maxHeight * math.Rand(0.6, 0.8) or 0
        lifetime = math.Rand(8, 12)
    elseif ent.SubvConfig == 5 then -- Small range subvortices, small to medium, tall in height and fast frequency and noise to simulate helical vortices
        ent.SubvortexMaxCount = 2
        ent.SubvortexSpawnChance = 25
        orbitRadius = 1
        vSizeSelect = math.random(ent.VortexRMWSize * 0.2, ent.VortexRMWSize * 0.3)
        funnelWidthTable = {baseWidth = 1, midWidth = math.Rand(1.25, 1.5), topWidth = math.Rand(1.5, 2), widthExponent = math.Rand(0.8, 1.2)}
        maxHeight = math.min(ent.FunnelStartHeight, math.random(1000, 3000))
        startHeight = math.random(2) == 1 and 0 or maxHeight * math.Rand(0.4, 0.6)
        lifetime = math.Rand(3, 6)
    elseif ent.SubvConfig == 6 then -- Meant to mimic greenfield iowa
        ent.SubvortexMaxCount = 4
        ent.SubvortexSpawnChance = 30
        maxHeight = (math.random(3) != 1 and ent.FunnelStartHeight or ent.FunnelStartHeight * math.Rand(0.5, 0.8)) + 250
        startHeight = math.random(3) != 1 and 0 or math.random(0, maxHeight * math.Rand(0.4, 0.6))
        orbitRadius = math.random(ent.VortexRMWSize * 0.75, ent.VortexRMWSize)
        vSizeSelect = math.random(ent.VortexRMWSize * 0.075, ent.VortexRMWSize * 0.15)
        lifetime = math.Rand(8, 12)
        funnelWidthTable = {baseWidth = 1, midWidth = math.Rand(1.5, 2.5), topWidth = math.Rand(2.5, 3), widthExponent = math.Rand(0.8, 1.2)}
    else -- Subvortices originating from the base of the funnel extending downwards
        ent.SubvortexMaxCount = 4
        ent.SubvortexSpawnChance = 50
        orbitRadius = math.random(ent.VortexRMWSize * 0.6, ent.VortexRMWSize * 0.8)
        vSizeSelect = math.random(ent.VortexRMWSize * 0.15, ent.VortexRMWSize * 0.3)
        funnelWidthTable = {baseWidth = 1, midWidth = math.Rand(1.5, 2), topWidth = math.Rand(2, 3), widthExponent = math.Rand(0.8, 1.2)}
        maxHeight = ent.FunnelStartHeight + 300
        startHeight = math.max(ent.FunnelStartHeight * math.Rand(0.5, 0.75), 0)
        lifetime = math.Rand(4, 6)
    end

    local noisePreset = subv_noise_presets[ent.SubvConfig] or subv_noise_presets[1]

    funnelWidthTable.midWidthHeight = math.Rand(0.4, 0.6)

    subvortex.VortexPositionNoiseDetail = math.Rand(noisePreset.detailMin, noisePreset.detailMax)
    subvortex.VortexPositionNoiseSize = 1
    subvortex.VortexPositionNoisePeak = math.Rand(noisePreset.peakMin, noisePreset.peakMax)
    subvortex.VortexModelParameters = vModelParams
    subvortex.VortexRMWSize = vSizeSelect
    subvortex.VortexSize = vSizeSelect * math.pow(12, math.pow(1 / vModelParams.falloffExponent, 0.99))
    subvortex.VortexWindspeedMultiplier = (math.random(70, 100) / 100) * ent.SubvortexStrengthMult
    subvortex.TornadoWindspeedAtPosition = 0
    subvortex.MovementVector = Vector(0, 0, 0)
    subvortex.Lifetime = lifetime
    subvortex.LifetimeStart = ent.CurTime
    subvortex.OrbitRadius = orbitRadius
    subvortex.FunnelMaxHeight = maxHeight
    subvortex.FunnelStartHeight = startHeight
    subvortex.FunnelWidthTable = funnelWidthTable
    subvortex.VortexPositionNoiseAmplitude = math.Rand(noisePreset.ampMin, noisePreset.ampMax)
    subvortex.VortexPositionNoiseFrequency = math.Rand(noisePreset.freqMin, noisePreset.freqMax)
    subvortex.VortexPositionNoiseSpeed = math.Rand(noisePreset.speedMin, noisePreset.speedMax)
    subvortex.VortexPositionNoiseSeed = vortexPositionNoiseSeed
    subvortex.WindspeedEaseExponent = math.random(50, 200) / 100

end

local chaosAmount = 0.5
local minFreqUI, maxFreqUI = 1, 7.5
local minAmp, maxAmp = 1, 8
local minSpeed, maxSpeed = 100, 750
local minDetail, maxDetail = 0.5, 1
local minPeak, maxPeak = 0.3, 1
local freqScale = 0.0001

local ropeRMW, stovepipeRMW, wedgeRMW = 75, 400, 2000

local noiseRanges = {
    rope = {
        common = {freq = {7.1, 7.5}, amp = {1.0, 1.35}, speed = {260, 330}, detail = {1.0, 1.0}, peak = {1.0, 1.0}},
        sweep = {freq = {3.0, 3.8}, amp = {3.1, 8.0}, speed = {180, 500}, detail = {0.7, 1.0}, peak = {1.0, 1.0}},
        whip = {freq = {3.9, 7.5}, amp = {2.6, 4.0}, speed = {500, 750}, detail = {0.55, 0.65}, peak = {0.3, 0.35}}
    },

    stovepipe = {
        common = {freq = {2.1, 2.8}, amp = {1.0, 3.25}, speed = {250, 330}, detail = {0.95, 1.0}, peak = {1.0, 1.0}},
        sweep = {freq = {1.0, 2.1}, amp = {6.4, 7.3}, speed = {200, 250}, detail = {0.55, 1}, peak = {1.0, 1.0}},
        whip = {freq = {2.8, 7}, amp = {1.0, 2.5}, speed = {650, 750}, detail = {0.5, 0.6}, peak = {0.4, 1.0}}
    },

    wedge = {
        common = {freq = {2.4, 2.9}, amp = {1.0, 5.4}, speed = {100, 140}, detail = {0.95, 1.0}, peak = {1.0, 1.0}},
        sweep = {freq = {1.8, 2.1}, amp = {7.4, 8.0}, speed = {100, 120}, detail = {1.0, 1.0}, peak = {1.0, 1.0}},
        whip = {freq = {4.7, 5.1}, amp = {4.8, 5.2}, speed = {650, 750}, detail = {0.5, 0.55}, peak = {0.4, 0.45}}
    }
}

local noiseDirs = {
    common = {amp = 0, freq = 0, speed = 0, detail = 0, peak = 0},
    sweep = {amp = 1, freq = -1, speed = -1, detail = -1, peak = 1},
    whip = {amp = 1, freq = 1, speed = 1, detail = -1, peak = -1}
}

local ropeLog, stovepipeLog, wedgeLog = math.log(ropeRMW), math.log(stovepipeRMW), math.log(wedgeRMW)

local function GSBlendRMW(rmw, ropeVal, stovepipeVal, wedgeVal)
    local logRMW = math.Clamp(math.log(math.max(rmw or stovepipeRMW, 1)), ropeLog, wedgeLog)

    if logRMW <= stovepipeLog then return Lerp((logRMW - ropeLog) / (stovepipeLog - ropeLog), ropeVal, stovepipeVal) end

    return Lerp((logRMW - stovepipeLog) / (wedgeLog - stovepipeLog), stovepipeVal, wedgeVal)
end

local function GSGetNoiseRange(rmw, mode, key)
    local ropeTbl = noiseRanges.rope[mode][key]
    local stovepipeTbl = noiseRanges.stovepipe[mode][key]
    local wedgeTbl = noiseRanges.wedge[mode][key]

    return GSBlendRMW(rmw, ropeTbl[1], stovepipeTbl[1], wedgeTbl[1]), GSBlendRMW(rmw, ropeTbl[2], stovepipeTbl[2], wedgeTbl[2])
end

local function GSChooseNoiseMode(rmw)
    local commonWeight = Lerp(chaosAmount, 1.75, 0.6)
    local sweepWeight = 0.15 + (chaosAmount * GSBlendRMW(rmw, 0.75, 0.85, 0.95))
    local whipWeight = 0.10 + (chaosAmount * GSBlendRMW(rmw, 0.85, 0.95, 0.55))

    local total = commonWeight + sweepWeight + whipWeight
    local roll = math.Rand(0, total)

    if roll <= commonWeight then return "common" end
    if roll <= commonWeight + sweepWeight then return "sweep" end

    return "whip"
end

local function GSPickNoiseValue(minVal, maxVal, severity, dir)
    if dir == 0 then
        return Lerp(math.Clamp(0.5 + (math.Rand(-0.5, 0.5) * chaosAmount), 0, 1), minVal, maxVal)
    end

    return Lerp(dir > 0 and severity or (1 - severity), minVal, maxVal)
end

local function GSGetNoiseProperties(tbl)
    local rmw = tbl.VortexRMWSize or stovepipeRMW
    local mode = GSChooseNoiseMode(rmw)
    local dirs = noiseDirs[mode]
    local severity = math.Rand(0, 1) ^ Lerp(chaosAmount, 2.75, 0.85)

    local minA, maxA = GSGetNoiseRange(rmw, mode, "amp")
    local minF, maxF = GSGetNoiseRange(rmw, mode, "freq")
    local minS, maxS = GSGetNoiseRange(rmw, mode, "speed")
    local minD, maxD = GSGetNoiseRange(rmw, mode, "detail")
    local minP, maxP = GSGetNoiseRange(rmw, mode, "peak")

    local ampUI = GSPickNoiseValue(minA, maxA, severity, dirs.amp)
    local freqUI = GSPickNoiseValue(minF, maxF, severity, dirs.freq)
    local speed = GSPickNoiseValue(minS, maxS, severity, dirs.speed)
    local detail = GSPickNoiseValue(minD, maxD, severity, dirs.detail)
    local peak = GSPickNoiseValue(minP, maxP, severity, dirs.peak)

    local straightChance = GSBlendRMW(rmw, 0.35, 0.18, 0.06) * (1 - (chaosAmount * 0.8))

    if math.Rand(0, 1) < straightChance * 0.35 then
        ampUI = 1
        freqUI = math.max(freqUI, GSBlendRMW(rmw, 5.5, 3.0, 2.2))
        speed = math.max(speed, GSBlendRMW(rmw, 260, 240, 140))
        detail = math.max(detail, 0.85)
        peak = math.max(peak, 0.9)
    elseif math.Rand(0, 1) < straightChance then
        ampUI = Lerp(math.Rand(0, 1) ^ 1.5, 1, ampUI)
        freqUI = math.max(freqUI, GSBlendRMW(rmw, 5.0, 2.75, 2.0))
        speed = math.max(speed, GSBlendRMW(rmw, 220, 200, 130))
        detail = math.max(detail, 0.8)
        peak = math.max(peak, 0.85)
    end

    ampUI = math.Clamp(ampUI, minAmp, maxAmp)
    freqUI = math.Clamp(freqUI, minFreqUI, maxFreqUI)
    speed = math.Clamp(speed, minSpeed, maxSpeed)
    detail = math.Clamp(detail, minDetail, maxDetail)
    peak = math.Clamp(peak, minPeak, maxPeak)

    tbl.VortexPositionNoiseAmplitude = ampUI
    tbl.VortexPositionNoiseFrequency = freqUI * freqScale
    tbl.VortexPositionNoiseSpeed = speed
    tbl.VortexPositionNoiseDetail = detail
    tbl.VortexPositionNoisePeak = peak

    return tbl
end

local funnelProfiles = {
    cylinder = {
        mode = "normal",
        weight = 2,
        baseWidth = 1,
        midWidth = {min = 1.2, max = 1.4},
        midWidthHeight = {min = 0.3, max = 0.7},
        topWidth = {min = 1.5, max = 1.8},
        widthExponent = {min = 0.75, max = 1.25},
        WidthRangeTable = {
            {rmw = 200, mul = 4},
            {rmw = 400, mul = 3},
            {rmw = 1000, mul = 2},
            {rmw = 2000, mul = 1.4},
            {rmw = 3000, mul = 1.2}
        }
    },

    topHeavy = {
        mode = "normal",
        weight = 5,
        baseWidth = 1,
        midWidth = {min = 1.5, max = 1.8},
        midWidthHeight = {min = 0.5, max = 0.7},
        topWidth = {min = 3.5, max = 4},
        widthExponent = {min = 0.75, max = 1.25},
        WidthRangeTable = {
            {rmw = 200, mul = 4},
            {rmw = 400, mul = 3},
            {rmw = 1000, mul = 2},
            {rmw = 2000, mul = 1.4},
            {rmw = 3000, mul = 1.2}
        }
    },

    midHeavy = {
        mode = "normal",
        weight = 3,
        baseWidth = 1,
        midWidth = {min = 2.75, max = 3.25},
        midWidthHeight = {min = 0.4, max = 0.6},
        topWidth = {min = 3.5, max = 4},
        widthExponent = {min = 0.75, max = 1.25},
        WidthRangeTable = {
            {rmw = 200, mul = 4},
            {rmw = 400, mul = 3},
            {rmw = 1000, mul = 2},
            {rmw = 2000, mul = 1.4},
            {rmw = 3000, mul = 1.2}
        }
    },

    cone = {
        mode = "normal",
        weight = 5,
        baseWidth = 1,
        midWidth = 2,
        midWidthHeight = {min = 0.45, max = 0.55},
        topWidth = {min = 3.25, max = 4},
        widthExponent = {min = 0.8, max = 1.2},
        WidthRangeTable = {
            {rmw = 200, mul = 4},
            {rmw = 400, mul = 3},
            {rmw = 1000, mul = 2},
            {rmw = 2000, mul = 1.4},
            {rmw = 3000, mul = 1.2}
        }
    },

    spout = {
        mode = "plain",
        baseWidth = {min = 0.5, max = 1},
        midWidth = {min = 1.5, max = 2},
        midWidthHeight = {min = 0.4, max = 0.6},
        topWidth = {min = 2.25, max = 3.5},
        widthExponent = {min = 0.75, max = 1.5}
    },

    dustDevil = {
        mode = "pow",
        baseWidth = 1,
        midWidth = {min = 0.5, max = 0.75},
        midWidthHeight = {min = 0.4, max = 0.6},
        topWidth = {min = 0.2, max = 0.5},
        widthExponent = {min = 1, max = 2},
        randExp = {min = 0.5, max = 1.5}
    }
}

local normalFunnelProfiles = {
    {weight = funnelProfiles.cylinder.weight, profile = funnelProfiles.cylinder},
    {weight = funnelProfiles.topHeavy.weight, profile = funnelProfiles.topHeavy},
    {weight = funnelProfiles.midHeavy.weight, profile = funnelProfiles.midHeavy},
    {weight = funnelProfiles.cone.weight, profile = funnelProfiles.cone}
}

local function GSFunnelProfileRand(v) return istable(v) and math.Rand(v.min, v.max) or v end

local function GSGetWidthRangeMul(tbl, vortexRMWSize)
    if !tbl or !tbl[1] then return 1 end
    if vortexRMWSize <= tbl[1].rmw then return tbl[1].mul end

    for i = 1, #tbl - 1 do
        local a, b = tbl[i], tbl[i + 1]
        if vortexRMWSize <= b.rmw then
            return Lerp((vortexRMWSize - a.rmw) / (b.rmw - a.rmw), a.mul, b.mul)
        end
    end

    return tbl[#tbl].mul
end

function GSFunnelWidthTableSelector(ent, vortexRMWSize)
    local profile = ent.DustDevil and funnelProfiles.dustDevil or ent.Spout and funnelProfiles.spout or GSGetWeightedEntry(normalFunnelProfiles, "weight", 1).profile
    local midWidth = GSFunnelProfileRand(profile.midWidth)
    local topWidth = GSFunnelProfileRand(profile.topWidth)

    if profile.mode == "normal" then
        local maxMul = GSGetWidthRangeMul(profile.WidthRangeTable, vortexRMWSize)
        local sizeInfluence = Lerp(math.Rand(0, 1) ^ 1.1, 1, maxMul)
        midWidth = midWidth * sizeInfluence
        topWidth = topWidth * sizeInfluence
    elseif profile.mode == "pow" then
        local randExp = math.Rand(profile.randExp.min, profile.randExp.max)
        midWidth = midWidth ^ randExp
        topWidth = topWidth ^ randExp
    end

    return {baseWidth = GSFunnelProfileRand(profile.baseWidth), midWidth = midWidth, midWidthHeight = GSFunnelProfileRand(profile.midWidthHeight), topWidth = topWidth, widthExponent = GSFunnelProfileRand(profile.widthExponent)}
end

local function GSRandomEntityPropertiesStormBranch(ent, tbl, tableReturn, isDynamicAutospawnApply, isDynamic, isRainstorm, isDerecho)
    tbl.VortexRMWSize = GSGetWeightedTableReturn(ent.WidthTable, "minSize", "maxSize", "weight")
    tbl.VortexWindspeed = 0

    tbl.StormWindspeed = isDerecho and math.random(58, 85) or math.random(2, 40)
    tbl.StormPrecipitationMultiplier = isDynamicAutospawnApply and 0 or (isRainstorm and math.Rand(0.35, 0.8) or math.Rand(0.7, 0.9))
    tbl.SupercellParameters = {debrisMax = 0, hookMax = 0, debrisBSize = 0, hookLenSize = math.Rand(-0.5, 0.5), hookWidSize = 1, hookAngSize = math.Rand(0.8, 1.2)}
    tbl.StormRFB = false

    if isDynamic and tableReturn then tbl = GSGetNoiseProperties(tbl) end
    if isRainstorm then tbl.EnableLightning = false end

    return tbl
end

local function GSRandomEntityPropertiesHurricaneBranch(ent, tbl, isDynamicAutospawnApply)
    tbl.StormPrecipitationMultiplier = isDynamicAutospawnApply and 0.3 or math.Rand(0.75, 0.95)
    tbl.VortexModelParameters = {alpha = 0.15, zScale = 4500, twoCelled = 0, falloffExponent = math.random(80, 90) * 0.01}
    ent.ManualFalloffExponent = true
    tbl.VortexRMWSize = GSGetWeightedTableReturn(ent.WidthTable, "minSize", "maxSize", "weight")
    tbl.VortexWindspeed = math.random(ent.MinWindspeed, ent.MaxWindspeed)

    return tbl
end

local twoCelledStrongMinSize = 150
local twoCelledFullRangeSize = 300
local twoCelledZeroSize = 1500

local twoCelledStrongMin = 0.6
local twoCelledFalloffExponent = 2
local twoCelledStep = 0.1

local function GSComputeTwoCelledValTornadoes(rmw)
    if rmw >= twoCelledZeroSize then return 0 end

    local minTwoCelledVal
    local maxTwoCelledVal

    if rmw <= twoCelledStrongMinSize then
        minTwoCelledVal = twoCelledStrongMin
        maxTwoCelledVal = 1
    elseif rmw <= twoCelledFullRangeSize then
        local minFadeT = (rmw - twoCelledStrongMinSize) / (twoCelledFullRangeSize - twoCelledStrongMinSize)

        minTwoCelledVal = twoCelledStrongMin * (1 - minFadeT)
        maxTwoCelledVal = 1
    else
        local maxFadeT = (rmw - twoCelledFullRangeSize) / (twoCelledZeroSize - twoCelledFullRangeSize)

        minTwoCelledVal = 0
        maxTwoCelledVal = (1 - maxFadeT) ^ twoCelledFalloffExponent
    end

    local invStep = 1 / twoCelledStep
    local minStep = math.ceil(minTwoCelledVal * invStep - 0.000001)
    local maxStep = math.floor(maxTwoCelledVal * invStep + 0.000001)

    if maxStep < minStep then return math.max(maxStep, 0) * twoCelledStep end

    return math.random(minStep, maxStep) * twoCelledStep
end

local function GSRandomEntityPropertiesVortexBranch(ent, tbl, notRainWrapped, isSpout, isDustDevil)

    tbl.VortexWindspeed = math.random(ent.MinWindspeed, ent.MaxWindspeed)
    tbl.VortexRMWSize = GSGetWeightedTableReturn(ent.WidthTable, "minSize", "maxSize", "weight")
    
    local twoCelledVal

    if isDustDevil or isSpout then 
        twoCelledVal = 1 
    else
        twoCelledVal = GSComputeTwoCelledValTornadoes(tbl.VortexRMWSize)
    end

    tbl.VortexModelParameters = {alpha = isDustDevil and 1 or isSpout and math.Rand(0.6, 1) or math.Rand(0.35, 0.5), zScale = 4500, twoCelled = twoCelledVal, falloffExponent = ent.VortexModelParameters.falloffExponent}

    if tbl.VortexWindspeed < 155 and !isDustDevil and math.random(Lerp(math.max((tbl.VortexWindspeed - 65) / 90, 0), 2, 3)) == 1 or (tbl.VortexRMWSize >= 200 and tbl.VortexWindspeed <= 85 and !isDustDevil) then tbl.FunnelStartHeight = tbl.FunnelMaxHeight * math.Rand(0.2, 0.8) end
    if isSpout then tbl.FunnelStartHeight = tbl.FunnelMaxHeight * math.Rand(0.725, 0.825) end
    if tbl.VortexModelParameters.twoCelled <= 0.5 and tbl.VortexRMWSize >= 800 and math.random(5) == 1 then tbl.FunnelStartHeight = math.Clamp(tbl.FunnelMaxHeight * math.Rand(0.15, 0.3), 750, 1999) end

    tbl = GSGetNoiseProperties(tbl)
    tbl.FunnelWidthTable = GSFunnelWidthTableSelector(ent, tbl.VortexRMWSize)
    tbl.StormWindspeed = isDustDevil and math.random(2, 10) or isSpout and math.random(5, 10) or 20

    if !isDustDevil and tbl.VortexWindspeed > 140 and tbl.VortexRMWSize < 650 and tbl.FunnelStartHeight == 0 and math.random(5) == 1 then tbl.FunnelCondensationRing = {activationHeight = math.random(500, 1750), radiusMultiplier = math.Rand(1.5, 2.5)} end

    tbl.SupercellParameters = isSpout and {debrisMax = 0, hookMax = 0, debrisBSize = 0, hookLenSize = math.Rand(-0.5, 0.5), hookWidSize = 1, hookAngSize = math.Rand(0.8, 1.2)} or {debrisMax = notRainWrapped and math.Rand(0.8, 1.2) or math.Rand(1.1, 1.3), hookMax = notRainWrapped and math.Rand(0.9, 1.1) or math.Rand(1, 1.1), debrisBSize = math.Rand(0.75, 1), hookLenSize = notRainWrapped and math.Rand(0.5, 1) or math.Rand(0.4, 0.6), hookWidSize = notRainWrapped and math.Rand(0.9, 1.2) or math.Rand(1.0, 1.2), hookAngSize = math.Rand(0.8, 1.2)}
    tbl.StormPrecipitationMultiplier = isSpout and math.Rand(0.35, 0.9) or (notRainWrapped and 1 or math.Rand(1.1, 1.2))

    return tbl

end

local function GSRandomEntityPropertiesAutospawnOverrides(tbl, autospawnTbl)
    if autospawnTbl then
        if autospawnTbl.stormWindspeed ~= nil then tbl.StormWindspeed = autospawnTbl.stormWindspeed end
    end

    return tbl
end

local function GSRandomEntityPropertiesDynamicOverrides(tbl, atmosphericProperties, isDynamicAutospawnApply, isAutospawn)
    if isDynamicAutospawnApply then 
        tbl.StormPrecipitationMultiplier = 0
        if isAutospawn then
            tbl.StormWindspeed = atmosphericProperties.WIND
        else
            tbl.StormWindspeed = 0
        end
    end

    return tbl
end

local function GSRandomEntityPropertiesSetAnticyclonic(ent, tbl, isTornado, isDustDevil, isSpout, isHurricane)
    if !ent.HasSetAnticyclonic then
        local chance = math.random((isDustDevil or isHurricane) and 2 or isSpout and 5 or 20) == 1
        local canBeAnticyclonic = !isTornado or tbl.VortexWindspeed <= 165

        ent.Anticyclonic = canBeAnticyclonic and chance
        ent.HasSetAnticyclonic = true
    end
end

function GSRandomEntityProperties(ent, tableReturn)

    local tbl = {}
    local atmosphericProperties = GSGetAtmosphericProperties()

    local isAutospawn = ent.Autospawn
    local isDynamic = ent.Dynamic
    local isSpout = ent.Spout
    local isDustDevil = ent.DustDevil
    local isRainstorm = ent.Rainstorm
    local isThunderstorm = ent.Thunderstorm
    local isTornado = ent.Tornado
    local isDerecho = ent.Derecho
    local isHurricane = ent.Hurricane
    local isStorm = isRainstorm or isThunderstorm or isDerecho
    local isDynamicAutospawnApply = (isDynamic and !tableReturn) or (isAutospawn and isDynamic and !tableReturn)
    local autospawnTbl = isAutospawn and GSEntityPropertiesFromCurrentRisks(ent.AutospawnKey) or nil

    tbl.CondensationThreshold = math.random(40, 90)

    if !ent.SetMaxHeight then
        tbl.FunnelMaxHeight = math.min(isDustDevil and math.random(2000, 4000) or isHurricane and math.random(8000, 11000) or math.random(5000, 7500))
    else
        tbl.FunnelMaxHeight = ent.FunnelMaxHeight
    end

    tbl.FunnelStartHeight = 0
    tbl.SetMaxHeight = true

    local chanceOfRainWrapped = (autospawnTbl and autospawnTbl.chanceOfRainWrapped) or 3
    local notRainWrapped = math.random(chanceOfRainWrapped) > 1

    tbl.chanceOfRainWrapped = chanceOfRainWrapped
    tbl.StormRFB = notRainWrapped

    if !ent.MaxLifetime then ent.MaxLifetime = GetConVar("gstorms_sim_max_lifetime"):GetInt() * (ent.MaxLifetimeMult or 1) end

    if isStorm then
        tbl = GSRandomEntityPropertiesStormBranch(ent, tbl, tableReturn, isDynamicAutospawnApply, isDynamic, isRainstorm, isDerecho)
    elseif isHurricane then
        tbl = GSRandomEntityPropertiesHurricaneBranch(ent, tbl, isDynamicAutospawnApply)
    else
        tbl = GSRandomEntityPropertiesVortexBranch(ent, tbl, notRainWrapped, isSpout, isDustDevil)
    end

    tbl = GSRandomEntityPropertiesAutospawnOverrides(tbl, autospawnTbl)
    tbl = GSRandomEntityPropertiesDynamicOverrides(tbl, atmosphericProperties, isDynamicAutospawnApply, isAutospawn)
    
    GSRandomEntityPropertiesSetAnticyclonic(ent, tbl, isTornado, isDustDevil, isSpout, isHurricane)

    if tableReturn then return tbl end
    for k, v in pairs(tbl) do ent[k] = v end

end

local function GSBuildLerpPlan(ent)
    local stages = ent.LerpParams
    local N = stages and #stages or 0
    if N <= 0 then return end

    local maxLifetime = ent.MaxLifetime or 0
    local sumStageFrac = 0

    for i = 1, N do sumStageFrac = sumStageFrac + (stages[i].stageTimeFrac or 0) end
    if sumStageFrac <= 0 then sumStageFrac = N end

    ent.LerpPlanStages = ent.LerpPlanStages or {}

    for i = 1, N do

        local st = stages[i]
        local stageLen = maxLifetime * ((st.stageTimeFrac or 1) / sumStageFrac)
        local bw = st.birth and (st.birth.phaseLerpTimeFrac or 1) or 0
        local mw = st.middle and (st.middle.phaseLerpTimeFrac or 1) or 0
        local dw = st.death and (st.death.phaseLerpTimeFrac or 1) or 0

        if bw + mw + dw <= 0 then mw = 1 end

        local total = bw + mw + dw
        local middleRepeats = st.middle and (st.middle.repeatStages or 1) or 1

        if middleRepeats < 1 then middleRepeats = 1 end

        local middleLen = mw > 0 and stageLen * (mw / total) or 0

        ent.LerpPlanStages[i] = {stageLength = stageLen, birthLength = bw > 0 and stageLen * (bw / total) or 0, middleLength = middleLen, deathLength = dw > 0 and stageLen * (dw / total) or 0, middleRepeats = middleRepeats, middleRepeatLength = middleRepeats > 0 and middleLen / middleRepeats or 0}

    end
end

local function GSBeginPhase(ent)
    local stage = ent.LerpParams and ent.LerpParams[ent.LerpStage] or nil
    local plan = ent.LerpPlanStages and ent.LerpPlanStages[ent.LerpStage] or nil

    if !stage or !plan then
        ent.DynamicLerpFinished = true
        return
    end

    GSSetStageEntityType(ent, stage)

    local phaseType = ent.LerpPhaseType
    local phaseTbl = stage[phaseType]
    local useFunnelLerp = GSStageUsesFunnelLerp(stage)

    if phaseTbl then

        if phaseTbl.widthTable then ent.WidthTable = phaseTbl.widthTable end

        if phaseTbl.strengthTable and #phaseTbl.strengthTable > 0 then
            local s = GSGetWeightedEntry(phaseTbl.strengthTable, "weight", 1)

            ent.MinWindspeed = s and (s.minWS or 0) or 0
            ent.MaxWindspeed = s and (s.maxWS or 0) or 0
        end

    end

    ent.LerpTargets = GSRandomEntityProperties(ent, true)

    GSApplyParamsToLerpOverride(ent, stage, phaseTbl)
    GSResetSubvConfig(ent)

    if ent.LerpTargets and phaseType == "death" and useFunnelLerp then
        ent.LerpTargets.FunnelStartHeight = ent.FunnelMaxHeight or ent.LerpTargets.FunnelStartHeight or 0
    end

    local target = ent.LerpTargets
    local lst = stage.paramsToLerp

    if target and lst then
        for i = 1, #lst do
            local entry = lst[i]
            if entry then GSEnsureEntHasEntryFromTarget(ent, target, entry) end
        end
    end

    ent.PrevLerpTargets = GSBuildPrevTargetsFromEnt(ent, stage)
    ent.LerpPhaseStartTime = ent.CurTime
    ent.LerpPhaseLength = (phaseType == "birth" and plan.birthLength) or (phaseType == "middle" and plan.middleRepeatLength) or (phaseType == "death" and plan.deathLength) or plan.stageLength or 1

    if phaseType == "birth" then

        ent.LerpTouchdownLength = ent.LerpPhaseLength
        ent.FunnelBirthStartTime = nil
        ent.FunnelBirthActive = false
        ent.IgnoreCondensationThreshold = false

        if useFunnelLerp then
            ent.PrevLerpTargets.FunnelStartHeight = ent.FunnelMaxHeight
            ent.FunnelStartHeight = ent.FunnelMaxHeight
            GSSetCondensationThresholdLookAhead(ent)
        end

    elseif phaseType == "middle" then

        ent.IgnoreCondensationThreshold = useFunnelLerp

    elseif phaseType == "death" then

        ent.LerpDeathLength = ent.LerpPhaseLength
        ent.FunnelDeathStartTime = nil
        ent.FunnelDeathActive = false
        ent.DeathFunnelInit = false
        ent.IgnoreCondensationThreshold = false

        if useFunnelLerp then
            GSSetCondensationThresholdLookAhead(ent)

            ent.DeathLerpUseThreshold = ent.CondensationThresholdLookAhead > ent.CondensationThreshold and ent.VortexWindspeed >= ent.CondensationThresholdLookAhead
            ent.IgnoreCondensationThreshold = !ent.DeathLerpUseThreshold
            ent.FunnelDeathStartTime = ent.CurTime
            ent.FunnelDeathActive = true
            ent.DeathFunnelInit = true
        end

    end
end

local function GSInitDynamicLerp(ent)
    ent.DynamicLerpInit = true
    ent.DynamicLerpFinished = false

    GSBuildLerpPlan(ent)

    ent.LerpStage = 1
    ent.LerpMiddleRepeatIndex = 0

    local stage = ent.LerpParams and ent.LerpParams[ent.LerpStage] or nil

    GSSetStageEntityType(ent, stage)

    ent.LerpPhaseType, ent.LerpMiddleRepeatIndex = GSSelectPhase(stage)
    ent.PrevLerpTargets = GSBuildPrevTargetsFromEnt(ent, stage) or {}
    ent.PrevLerpTargets.FunnelStartHeight = ent.FunnelMaxHeight or ent.PrevLerpTargets.FunnelStartHeight or ent.FunnelStartHeight or 0

    GSBeginPhase(ent)
end

local function GSLerpNumericParams(ent, tTime)
    local prev, target = ent.PrevLerpTargets, ent.LerpTargets
    if !prev or !target then return end

    local stage = ent.LerpParams and ent.LerpParams[ent.LerpStage] or nil
    local lst = stage and stage.paramsToLerp or nil
    if !lst then return end

    for i = 1, #lst do

        local entry = lst[i]

        if entry then
            local from = GSGetEntryValue(prev, entry)
            local to = GSGetEntryValue(target, entry)

            if from ~= nil and to ~= nil then
                if entry.isBool then
                    GSSetEntryValue(ent, entry, to and true or false, false)
                elseif type(from) == "number" and type(to) == "number" then
                    GSSetEntryValue(ent, entry, Lerp(tTime, from, to), false)
                end
            end
        end

    end
end

local function GSLerpFunnelStartHeight(ent, tTime)

    local stage = ent.LerpParams and ent.LerpParams[ent.LerpStage] or nil
    if !GSStageUsesFunnelLerp(stage) then return end

    local prev, target = ent.PrevLerpTargets, ent.LerpTargets
    if !prev or !target then return end

    local from = prev.FunnelStartHeight
    local to = target.FunnelStartHeight
    if from == nil or to == nil then return end

    local phaseType = ent.LerpPhaseType

    if phaseType == "birth" then

        GSSetCondensationThresholdLookAhead(ent)

        local ft = GSGetCondensationThresholdFunnelLerp(ent, ent.VortexWindspeed, false)

        ent.IgnoreCondensationThreshold = ent.VortexWindspeed >= ent.CondensationThreshold
        ent.FunnelStartHeight = Lerp(ft, from, to)

    elseif phaseType == "middle" then

        local fLerpTime = math.Clamp(tTime * 2, 0, 1)

        ent.FunnelStartHeight = Lerp(fLerpTime, from, to)
        ent.IgnoreCondensationThreshold = true

        if fLerpTime >= 1 then
            GSResetSubvConfig(ent)
        end

    elseif phaseType == "death" then

        if !ent.FunnelDeathActive then return end

        local len = ent.LerpDeathLength > 0 and ent.LerpDeathLength or 1
        local ft

        if ent.DeathLerpUseThreshold then
            ft = GSGetCondensationThresholdFunnelLerp(ent, ent.VortexWindspeed, true)
            ent.IgnoreCondensationThreshold = ent.VortexWindspeed > ent.CondensationThreshold
        else
            ft = math.Clamp((ent.CurTime - ent.FunnelDeathStartTime) / len, 0, 1)
            ent.IgnoreCondensationThreshold = true
        end

        ent.FunnelStartHeight = Lerp(ft, from, to)

    end

end

local function GSFinalizePrev(ent, stage)
    local prev = GSBuildPrevTargetsFromEnt(ent, stage) or {}

    prev.FunnelStartHeight = ent.FunnelStartHeight or ent.FunnelMaxHeight or prev.FunnelStartHeight
    ent.PrevLerpTargets = prev
end

local function GSStartPhase(ent, phaseType, repeatIndex, resetBirth, resetDeath)
    ent.LerpPhaseType = phaseType

    if repeatIndex ~= nil then ent.LerpMiddleRepeatIndex = repeatIndex end

    if resetBirth then
        ent.FunnelBirthStartTime = nil
        ent.FunnelBirthActive = false
    end

    if resetDeath then
        ent.DeathFunnelInit = false
        ent.FunnelDeathStartTime = nil
        ent.FunnelDeathActive = false
    end

    GSBeginPhase(ent)
end

local function GSAdvanceStage(ent)
    ent.LerpStage = (ent.LerpStage or 1) + 1
    ent.LerpMiddleRepeatIndex = 0

    local stage = ent.LerpParams and ent.LerpParams[ent.LerpStage] or nil
    local plan = ent.LerpPlanStages and ent.LerpPlanStages[ent.LerpStage] or nil

    if !stage or !plan then
        ent.DynamicLerpFinished = true
        return
    end

    GSSetStageEntityType(ent, stage)
    GSResetStagePhaseState(ent)

    ent.LerpPhaseType, ent.LerpMiddleRepeatIndex = GSSelectPhase(stage)

    GSBeginPhase(ent)
end

local function GSAdvanceLerpPhase(ent, tTime)
    if tTime < 1 or ent.DynamicLerpFinished then return end

    local stage = ent.LerpParams and ent.LerpParams[ent.LerpStage] or nil
    local plan = ent.LerpPlanStages and ent.LerpPlanStages[ent.LerpStage] or nil

    if !stage or !plan then
        ent.DynamicLerpFinished = true
        return
    end

    GSFinalizePrev(ent, stage)

    if ent.LerpPhaseType == "birth" then

        if GSEnabledPhase(stage, "middle") then
            GSStartPhase(ent, "middle", 1, true, false)
        elseif GSEnabledPhase(stage, "death") then
            GSStartPhase(ent, "death", 0, true, true)
        else
            GSAdvanceStage(ent)
        end

    elseif ent.LerpPhaseType == "middle" then

        local repeats = stage.middle and (stage.middle.repeatStages or 1) or 1

        if ent.LerpMiddleRepeatIndex < repeats then
            ent.LerpMiddleRepeatIndex = ent.LerpMiddleRepeatIndex + 1
            GSBeginPhase(ent)
        elseif GSEnabledPhase(stage, "death") then
            GSStartPhase(ent, "death", 0, true, true)
        else
            GSAdvanceStage(ent)
        end

    elseif ent.LerpPhaseType == "death" then

        GSAdvanceStage(ent)

    end
end

function GSLerpEntityParams(ent)

    if !ent.DynamicLerpInit then GSInitDynamicLerp(ent) end
    if ent.DynamicLerpFinished then return end

    local len = ent.LerpPhaseLength > 0 and ent.LerpPhaseLength or 1
    local tTime = math.Clamp((ent.CurTime - ent.LerpPhaseStartTime) / len, 0, 1)

    GSLerpNumericParams(ent, tTime)
    GSLerpFunnelStartHeight(ent, tTime)
    GSAdvanceLerpPhase(ent, tTime)

end