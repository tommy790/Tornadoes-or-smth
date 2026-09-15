include("gstorms_funcs/gstorms_shared.lua")
include("autorun/gstorms_base_entity_handler.lua")

local dayLengthSeconds = 1440 -- (seconds)
local updateSpeed = 0.1 -- (seconds)
local time = 0
local startingTimeCurTime = dayLengthSeconds / 3.85
local timeInitialized = false
local sunrise, sunset = 0.2604167, 0.8618056 -- 6:15 AM and 8:41 PM -- (minutes / 1440 (minutes per day))
local skyColorTransitionTime = 0.04 -- time to lerp between sunrise, day, sunset, and night colors...
local starSettings = {texture = "skybox/starfield", scale = 2, speed = 0.02, layers = 1, horizonFade = 0.85}
local reflectivityMaxFog = 40
local mathPi = math.pi
local tiny = 1e-9
local inv255 = 1 / 255
local gsSkyTopColorVec = Vector(0, 0, 0)
local gsSkyBottomColorVec = Vector(0, 0, 0)
local gsSunColorVec = Vector(0, 0, 0)
local gsFogColorVec = Vector(0, 0, 0)
local gsDimSunColorVec = Vector(0.1, 0.1, 0.1)
local gsFogParams = {world = {colorVec = gsFogColorVec, density = 0, fogStart = 0, fogEnd = 0}, skybox = {colorVec = gsFogColorVec, density = 0, fogStart = 0, fogEnd = 0}}
local lighting_and_environment, fog_table

gs_timetable = gs_timetable or {dayNumber = 1, t = 0}

local gsClientPhaseKeys = {
    {start = (sunrise - skyColorTransitionTime), finish = sunrise, from = "night", to = "sunrise", getVal = function(t) return (t - (sunrise - skyColorTransitionTime)) / skyColorTransitionTime end},
    {start = sunrise, finish = (sunrise + skyColorTransitionTime), from = "sunrise", to = "day", getVal = function(t) return (t - sunrise) / skyColorTransitionTime end},
    {start = (sunrise + skyColorTransitionTime), finish = (sunset - skyColorTransitionTime), from = "day", to = "day", val = 0},
    {start = (sunset - skyColorTransitionTime), finish = sunset, from = "day", to = "sunset", getVal = function(t) return (t - (sunset - skyColorTransitionTime)) / skyColorTransitionTime end},
    {start = sunset, finish = (sunset + skyColorTransitionTime), from = "sunset", to = "night", getVal = function(t) return (t - sunset) / skyColorTransitionTime end}
}

local skyPaint, tonemapController, sunEditor, envSun

if SERVER then
	net.Receive("gs_api_sync_sky", function(_, ply)
		local skyTable = net.ReadTable()
		local newFogTable = net.ReadTable()

		if !istable(skyTable) or !istable(newFogTable) then return end

		lighting_and_environment = skyTable
		fog_table = newFogTable

		net.Start("gs_api_sync_sky")
		net.WriteTable(skyTable)
		net.WriteTable(newFogTable)
		net.Broadcast()
	end)
end

if CLIENT then
	net.Receive("gs_api_sync_sky", function()
		local skyTable = net.ReadTable()
		local newFogTable = net.ReadTable()

		if !istable(skyTable) or !istable(newFogTable) then return end

		lighting_and_environment = skyTable
		fog_table = newFogTable
	end)
end

function GSResourcePackSetSky(skyTable, newFogTable)
	if !istable(skyTable) or !istable(newFogTable) then return end

	lighting_and_environment = skyTable
	fog_table = newFogTable
end

function GSGetDayLength() return dayLengthSeconds end
function GetTimeBetweenZeroAndOne(curTime, dayLengthSeconds) return (curTime % dayLengthSeconds) / dayLengthSeconds end

local function GSClamp01(x)
    if x <= 0 then return 0 elseif x >= 1 then return 1 end
    return x
end

local function Luma(red, green, blue) return red * 0.2126 + green * 0.7152 + blue * 0.0722 end
local function LerpColor(time, startColor, endColor) return Lerp(time, startColor.r, endColor.r) * inv255, Lerp(time, startColor.g, endColor.g) * inv255, Lerp(time, startColor.b, endColor.b) * inv255 end

function GSGetPhaseKeysAndVal(t)
    for i = 1, #gsClientPhaseKeys do
        local phase = gsClientPhaseKeys[i]
        if t >= phase.start and t < phase.finish then return phase.from, phase.to, (phase.val ~= nil) and phase.val or phase.getVal(t) end
    end
    return "night", "night", 0
end

local function GSBuildFogParams(fromKey, toKey, phaseLerpValue, maxPrecipMult, reflectivityFraction)
    local precipitationFraction = GSClamp01(maxPrecipMult)

    local fromFog = fog_table[fromKey]
    local toFog = fog_table[toKey]
    local fromLight = lighting_and_environment[fromKey].sky_colors
    local toLight = lighting_and_environment[toKey].sky_colors

    local fromFogDefault, toFogDefault = fromFog.default, toFog.default

    local defaultDensity = Lerp(phaseLerpValue, fromFogDefault.density, toFogDefault.density)
    local defaultFogStart = Lerp(phaseLerpValue, fromFogDefault.fog_start, toFogDefault.fog_start)
    local defaultFogEnd = Lerp(phaseLerpValue, fromFogDefault.fog_end, toFogDefault.fog_end)

    local fromFogRain, toFogRain = fromFog.rain, toFog.rain

    local rainDensity = Lerp(phaseLerpValue, fromFogRain.density, toFogRain.density)
    local rainFogStart = Lerp(phaseLerpValue, fromFogRain.fog_start, toFogRain.fog_start)
    local rainFogEnd = Lerp(phaseLerpValue, fromFogRain.fog_end, toFogRain.fog_end)

    local fromFogRainC, toFogRainC = fromFog.rain_clientside, toFog.rain_clientside

    local rainClientsideDensity = Lerp(phaseLerpValue, fromFogRainC.density, toFogRainC.density)
    local rainClientsideFogStart = Lerp(phaseLerpValue, fromFogRainC.fog_start, toFogRainC.fog_start)
    local rainClientsideFogEnd = Lerp(phaseLerpValue, fromFogRainC.fog_end, toFogRainC.fog_end)

    local defaultBottomRed, defaultBottomGreen, defaultBottomBlue = LerpColor(phaseLerpValue, fromLight.default.bottom, toLight.default.bottom)
    local rainBottomRed, rainBottomGreen, rainBottomBlue = LerpColor(phaseLerpValue, fromLight.rain.bottom, toLight.rain.bottom)

    local baseFogRed = Lerp(precipitationFraction, defaultBottomRed, rainBottomRed)
    local baseFogGreen = Lerp(precipitationFraction, defaultBottomGreen, rainBottomGreen)
    local baseFogBlue = Lerp(precipitationFraction, defaultBottomBlue, rainBottomBlue)
    local baseFogDensity = Lerp(precipitationFraction, defaultDensity, rainDensity)
    local baseFogStart = Lerp(precipitationFraction, defaultFogStart, rainFogStart)
    local baseFogEnd = Lerp(precipitationFraction, defaultFogEnd, rainFogEnd)

    gsFogColorVec:SetUnpacked(Lerp(reflectivityFraction, baseFogRed, rainBottomRed), Lerp(reflectivityFraction, baseFogGreen, rainBottomGreen), Lerp(reflectivityFraction, baseFogBlue, rainBottomBlue))

    local finalFogDensity = Lerp(reflectivityFraction, baseFogDensity, rainClientsideDensity)
    local finalFogStart = Lerp(reflectivityFraction, baseFogStart, rainClientsideFogStart)
    local finalFogEnd = Lerp(reflectivityFraction, baseFogEnd, rainClientsideFogEnd)

    gsFogParams.world.density = finalFogDensity
    gsFogParams.world.fogStart = finalFogStart
    gsFogParams.world.fogEnd = finalFogEnd
    gsFogParams.skybox.density = finalFogDensity
    gsFogParams.skybox.fogStart = finalFogStart
    gsFogParams.skybox.fogEnd = finalFogEnd

    return gsFogParams
end

local envPrecipCache = {client = 0, server = 0}

local function GetMaxPrecipitationMultiplier(lst)
    local precipitationMultMax = 0

    for _, tornado in ipairs(lst) do
        if !tornado:IsValid() or tornado.DustDevil or tornado.Flow then continue end
        precipitationMultMax = math.max(tornado.StormPrecipitationMultiplier, precipitationMultMax)
    end

    if SERVER then
        envPrecipCache.server = precipitationMultMax
    else
        envPrecipCache.client = precipitationMultMax
    end
end

function GSGetSkyTopAndBottomColors(time, maxPrecipMult)
    local precipitationFraction = GSClamp01(maxPrecipMult)

    if !GetConVar("gstorms_compat_skybox_modifications"):GetBool() then
        local day = lighting_and_environment.day
        local daySky = day.sky_colors
        local daySun = day.sun_colors

        local defaultTop = daySky.default.top
        local rainTop = daySky.rain.top
        local defaultBottom = daySky.default.bottom
        local rainBottom = daySky.rain.bottom
        local defaultSun = daySun.default
        local rainSun = daySun.rain

        gsSkyTopColorVec:SetUnpacked(Lerp(precipitationFraction, defaultTop.r, rainTop.r) * inv255, Lerp(precipitationFraction, defaultTop.g, rainTop.g) * inv255, Lerp(precipitationFraction, defaultTop.b, rainTop.b) * inv255)
        gsSkyBottomColorVec:SetUnpacked(Lerp(precipitationFraction, defaultBottom.r, rainBottom.r) * inv255, Lerp(precipitationFraction, defaultBottom.g, rainBottom.g) * inv255, Lerp(precipitationFraction, defaultBottom.b, rainBottom.b) * inv255)
        gsSunColorVec:SetUnpacked(Lerp(precipitationFraction, defaultSun.r, rainSun.r) * inv255, Lerp(precipitationFraction, defaultSun.g, rainSun.g) * inv255, Lerp(precipitationFraction, defaultSun.b, rainSun.b) * inv255)

        return gsSkyTopColorVec, gsSkyBottomColorVec, precipitationFraction, gsSunColorVec
    end

    local fromKey, toKey, phaseLerpValue = GSGetPhaseKeysAndVal(time)
    local defaultTopRed, defaultTopGreen, defaultTopBlue = LerpColor(phaseLerpValue, lighting_and_environment[fromKey].sky_colors.default.top, lighting_and_environment[toKey].sky_colors.default.top)
    local defaultBottomRed, defaultBottomGreen, defaultBottomBlue = LerpColor(phaseLerpValue, lighting_and_environment[fromKey].sky_colors.default.bottom, lighting_and_environment[toKey].sky_colors.default.bottom)
    local rainTopRed, rainTopGreen, rainTopBlue = LerpColor(phaseLerpValue, lighting_and_environment[fromKey].sky_colors.rain.top, lighting_and_environment[toKey].sky_colors.rain.top)
    local rainBottomRed, rainBottomGreen, rainBottomBlue = LerpColor(phaseLerpValue, lighting_and_environment[fromKey].sky_colors.rain.bottom, lighting_and_environment[toKey].sky_colors.rain.bottom)
    local defaultSunRed, defaultSunGreen, defaultSunBlue = LerpColor(phaseLerpValue, lighting_and_environment[fromKey].sun_colors.default, lighting_and_environment[toKey].sun_colors.default)
    local rainSunRed, rainSunGreen, rainSunBlue = LerpColor(phaseLerpValue, lighting_and_environment[fromKey].sun_colors.rain, lighting_and_environment[toKey].sun_colors.rain)

    gsSkyTopColorVec:SetUnpacked(Lerp(precipitationFraction, defaultTopRed, rainTopRed), Lerp(precipitationFraction, defaultTopGreen, rainTopGreen), Lerp(precipitationFraction, defaultTopBlue, rainTopBlue))
    gsSkyBottomColorVec:SetUnpacked(Lerp(precipitationFraction, defaultBottomRed, rainBottomRed), Lerp(precipitationFraction, defaultBottomGreen, rainBottomGreen), Lerp(precipitationFraction, defaultBottomBlue, rainBottomBlue))
    gsSunColorVec:SetUnpacked(Lerp(precipitationFraction, defaultSunRed, rainSunRed), Lerp(precipitationFraction, defaultSunGreen, rainSunGreen), Lerp(precipitationFraction, defaultSunBlue, rainSunBlue))

    return gsSkyTopColorVec, gsSkyBottomColorVec, precipitationFraction, gsSunColorVec
end

if SERVER then

    local snowBuildStart
    local snowActiveStart
    local snowWarmStart
    local snowState = false

    local function GSSetSnowState(state)
        if snowState == state then return end
        snowState = state
        SetGlobalBool("gs_is_snowing", state)
    end

    local function GSSnowHandler()
        local env = gs_env.server

        if !IsValid(env) or !env.Networked then
            snowBuildStart = nil
            snowActiveStart = nil
            snowWarmStart = nil
            GSSetSnowState(false)
            return
        end

        local temp = env.Temperature
        local entityList = gs_weatherEntityList.server
        local curTime = CurTime()
        local hasSnowSource = false

        for i = 1, #entityList do
            local ent = entityList[i]

            if IsValid(ent) and ent.Networked and ent.EnableRain and !ent.DustDevil then
                hasSnowSource = true
                break
            end
        end

        if !snowState then
            if hasSnowSource and temp <= 0 then
                snowBuildStart = snowBuildStart or curTime

                if curTime - snowBuildStart >= 30 then
                    snowBuildStart = nil
                    snowActiveStart = curTime
                    snowWarmStart = nil
                    GSSetSnowState(true)
                end
            else
                snowBuildStart = nil
            end

            return
        end

        if snowActiveStart and curTime - snowActiveStart >= 800 then
            snowBuildStart = nil
            snowActiveStart = nil
            snowWarmStart = nil
            GSSetSnowState(false)
            return
        end

        if temp > 0 then
            snowWarmStart = snowWarmStart or curTime

            if curTime - snowWarmStart >= 120 then
                snowBuildStart = nil
                snowActiveStart = nil
                snowWarmStart = nil
                GSSetSnowState(false)
                return
            end
        else
            snowWarmStart = nil
        end
    end

    local gsLastTimetableTime = nil

    local function GSPrepareDayNightEntity(ent)
        if !IsValid(ent) then return end
    
        ent:SetMoveType(MOVETYPE_NONE)
        ent:SetCollisionGroup(COLLISION_GROUP_NONE)
        ent:SetSolid(SOLID_NONE)
        ent:SetNotSolid(true)
    end

    local function GSRemoveAllButOne(entities, removeAll)
        local kept = false
        for _, ent in ipairs(entities) do
            if ent:IsValid() then
                if removeAll or kept then
                    ent:Remove()
                else
                    kept = true
                end
            end
        end
    end
    
    local forceRemoveAll = {edit_sky = true, edit_fog = true, edit_sun = true}
    
    local function GSRemoveExcessDayNightEntities(entityClasses, forceRemoveAll)
        for _, class in ipairs(entityClasses) do GSRemoveAllButOne(ents.FindByClass(class), forceRemoveAll[class]) end
    end
    
    local function GSGetRequiredDayNightEntities(entName)
    
        local found = ents.FindByClass(entName)
        local sky = found and found[1]
    
        if IsValid(sky) then
            GSPrepareDayNightEntity(sky)
            sky:SetRenderMode(RENDERMODE_TRANSALPHA)
            sky:SetColor(Color(0, 0, 0, 0))
            return sky
        end
    
        sky = ents.Create(entName)
    
        if !IsValid(sky) then return end
    
        GSPrepareDayNightEntity(sky)
        sky:SetRenderMode(RENDERMODE_TRANSALPHA)
        sky:SetColor(Color(0, 0, 0, 0))
        sky:Spawn()
        sky:Activate()
    
        return sky
    
    end

    local function GSHandleSkyboxLighting(time, maxPrecipMult)

        if !IsValid(skyPaint) then return end

        skyPaint:SetSunSize(0.1)
        skyPaint:SetSunColor(gsDimSunColorVec)

        local finalTopColorVec, finalBottomColorVec, precipitationFraction = GSGetSkyTopAndBottomColors(time, maxPrecipMult)

        skyPaint:SetTopColor(finalTopColorVec)
        skyPaint:SetBottomColor(finalBottomColorVec)

        skyPaint:SetDuskScale(0)
        skyPaint:SetDuskIntensity(0)
        skyPaint:SetDuskColor(finalBottomColorVec)

        local duskLerpValue = math.Clamp((time - sunset) / skyColorTransitionTime, 0, 1)
        local dawnLerpValue = math.Clamp((time - (sunrise - skyColorTransitionTime)) / skyColorTransitionTime, 0, 1)

        local nightStrength = math.max(1 - dawnLerpValue, duskLerpValue)
        local starAlpha = GSClamp01(nightStrength * (1 - precipitationFraction))
        local drawStars = starAlpha > 0.01

        skyPaint:Fire("DrawStars", drawStars and 1 or 0, 0)
        skyPaint:SetDrawStars(drawStars)
        skyPaint:SetStarTexture(starSettings.texture)
        skyPaint:SetStarScale(starSettings.scale)
        skyPaint:SetStarSpeed(starSettings.speed)
        skyPaint:SetStarLayers(starSettings.layers)
        skyPaint:SetStarFade(starSettings.horizonFade * starAlpha)

    end

    local gsLastAutoExposureMin, gsLastAutoExposureMax, gsLastBloomScale, gsLastToneMapRate
    local exposureScale = 0.8

    local function GSHandleTonemapFromFogBottom(maxPrecipMult, fogBottomColorVec)

        if !IsValid(tonemapController) then return end
    
        local precipitationFraction = GSClamp01(maxPrecipMult)
        local fogLuminance = math.Clamp(Luma(fogBottomColorVec.x, fogBottomColorVec.y, fogBottomColorVec.z), 0, 1) ^ 0.65
    
        local darknessAmount = 1 - fogLuminance
    
        local autoExposureMin = (Lerp(darknessAmount, 0.35, 0.90) + precipitationFraction * 0.08) * exposureScale
        local autoExposureMax = (Lerp(darknessAmount, 1.00, 2.20) + precipitationFraction * 0.15) * exposureScale
    
        if autoExposureMax < autoExposureMin then autoExposureMax = autoExposureMin end
    
        local bloomScale = Lerp(fogLuminance, 0.05, 0.35) * (1 - precipitationFraction * 0.8)
        local toneMapRate = Lerp(darknessAmount, 1.10, 0.80)
    
        if !gsLastAutoExposureMin or math.abs(autoExposureMin - gsLastAutoExposureMin) > 0.005 then
            tonemapController:Fire("SetAutoExposureMin", tostring(autoExposureMin), 0)
            gsLastAutoExposureMin = autoExposureMin
        end
    
        if !gsLastAutoExposureMax or math.abs(autoExposureMax - gsLastAutoExposureMax) > 0.005 then
            tonemapController:Fire("SetAutoExposureMax", tostring(autoExposureMax), 0)
            gsLastAutoExposureMax = autoExposureMax
        end
    
        if !gsLastBloomScale or math.abs(bloomScale - gsLastBloomScale) > 0.01 then
            tonemapController:Fire("SetBloomScale", tostring(bloomScale), 0)
            gsLastBloomScale = bloomScale
        end
    
        if !gsLastToneMapRate or math.abs(toneMapRate - gsLastToneMapRate) > 0.02 then
            tonemapController:Fire("SetTonemapRate", tostring(toneMapRate), 0)
            gsLastToneMapRate = toneMapRate
        end
    
    end

    local function GSHandleSunDayNight(time, maxPrecipMult)

        if !IsValid(envSun) then return end

        envSun:SetKeyValue("use_angles", "1")

        local _, _, _, sunColorVec = GSGetSkyTopAndBottomColors(time, maxPrecipMult)
        local visibilityFraction = 1 - GSClamp01(maxPrecipMult * 0.5) -- or keep your old scale if desired
        local isDay = (time >= sunrise and time < sunset)

        local orbitLerpValue, pitchStrength, startSize, endSize, overlaySizeMultiplier

        if isDay then
            orbitLerpValue = (time - sunrise) / math.max(sunset - sunrise, 0.001)
            pitchStrength, startSize, endSize, overlaySizeMultiplier = 75, 25, 15, 1.2
        else
            local nightSpan = (1 - sunset) + sunrise
            orbitLerpValue = math.Clamp((time >= sunset) and ((time - sunset) / nightSpan) or ((time + (1 - sunset)) / nightSpan), 0, 1)
            pitchStrength, startSize, endSize, overlaySizeMultiplier = 60, 4, 2, 0.3
            visibilityFraction = visibilityFraction * 0.5
        end

        local orbitSize = math.sin(orbitLerpValue * mathPi)
        local yaw = Lerp(orbitLerpValue, 90, 270)
        local pitch = -(orbitSize * pitchStrength)

        local colorMul = math.max(0, visibilityFraction)
        local sunColorString = string.format("%d %d %d", math.floor(sunColorVec.x * 255 * colorMul + 0.5), math.floor(sunColorVec.y * 255 * colorMul + 0.5), math.floor(sunColorVec.z * 255 * colorMul + 0.5))
        local overlaySize = math.max(0, math.floor(Lerp(orbitSize, startSize, endSize) * colorMul * overlaySizeMultiplier))

        if IsValid(sunEditor) then sunEditor:SetAngles(Angle(pitch, yaw, 0)) end

        envSun:SetAngles(Angle(pitch, yaw, 0))
        envSun:Fire("SetColor", sunColorString, 0)
        envSun:SetKeyValue("overlaycolor", sunColorString)
        envSun:SetKeyValue("size", tostring(math.floor(overlaySize)))
        envSun:SetKeyValue("overlaysize", tostring(overlaySize))
        envSun:SetKeyValue("HDRColorScale", tostring(0.4))
    end

    local pausedTime = 0
    local wasPausedLastTick = false
    
    timer.Create("GStorms_Skybox_Update", updateSpeed, 0, function()

        GetMaxPrecipitationMultiplier(gs_weatherEntityList.server)

        local lstForRemoval = {}
        local skyboxCvar = GetConVar("gstorms_compat_skybox_modifications"):GetBool()
        local fogCvar = GetConVar("gstorms_compat_fog_modifications"):GetBool()
        
        if skyboxCvar and fogCvar then
            lstForRemoval = {"edit_sun", "env_sun", "env_skypaint", "edit_fog", "edit_sky", "env_tonemap_controller"}
        elseif fogCvar then
            lstForRemoval = {"edit_fog"}
        elseif skyboxCvar then
            lstForRemoval = {"edit_sun", "env_sun", "env_skypaint", "edit_sky", "env_tonemap_controller"}
        end
        
        GSRemoveExcessDayNightEntities(lstForRemoval, forceRemoveAll)
        GSGetRequiredDayNightEntities("gstorms_env")

        if skyboxCvar then
            skyPaint = GSGetRequiredDayNightEntities("env_skypaint")
            tonemapController = GSGetRequiredDayNightEntities("env_tonemap_controller")
            sunEditor = GSGetRequiredDayNightEntities("edit_sun")
            envSun = GSGetRequiredDayNightEntities("env_sun")
        end

        GSSnowHandler()
    
        local curTime = CurTime()
        local timeShifted = false
    
        local pauseConVar = GetConVar("gstorms_env_pause_day")
        local paused = (pauseConVar and pauseConVar:GetBool()) or false
    
        local dayLengthConVar = GetConVar("gstorms_env_day_length")
        local newDayLength = (dayLengthConVar and dayLengthConVar:GetInt()) or 0
    
        if newDayLength > 0 and newDayLength ~= dayLengthSeconds then
    
            local currentFraction = (wasPausedLastTick and pausedTime) or GetTimeBetweenZeroAndOne(curTime + startingTimeCurTime, dayLengthSeconds)
    
            dayLengthSeconds = newDayLength
            startingTimeCurTime = (currentFraction * dayLengthSeconds) - (curTime % dayLengthSeconds)
    
        end
    
        local setTimeConVar = GetConVar("gstorms_env_set_time")
        local requestedTimeOffset = (((math.Clamp((setTimeConVar and setTimeConVar:GetInt()) or 0, 0, 24)) / 24) * dayLengthSeconds) - (curTime % dayLengthSeconds)

        if !timeInitialized then
            startingTimeCurTime = requestedTimeOffset
            timeInitialized = true
            timeShifted = true
        end
    
        local timeSetConVar = GetConVar("gstorms_env_time_set")
    
        if timeSetConVar and !timeSetConVar:GetBool() then
            startingTimeCurTime = requestedTimeOffset
            timeSetConVar:SetBool(true)
            timeShifted = true
        end
    
        if !paused and wasPausedLastTick then
            startingTimeCurTime = (pausedTime * dayLengthSeconds) - (curTime % dayLengthSeconds)
            timeShifted = true
        end
    
        local computedTime = GetTimeBetweenZeroAndOne(curTime + startingTimeCurTime, dayLengthSeconds)
    
        if paused then
            if !wasPausedLastTick or timeShifted then pausedTime = computedTime end
            time = pausedTime
        else
            time = computedTime
        end
    
        if gs_timetable.dayNumber <= 0 then gs_timetable.dayNumber = 1 end
        gs_timetable.t = time
    
        if !paused and gsLastTimetableTime and !timeShifted and gsLastTimetableTime > 0.95 and time < 0.05 then
            gs_timetable.dayNumber = gs_timetable.dayNumber + 1
        end
    
        gsLastTimetableTime = time
        wasPausedLastTick = paused
    
        SetGlobalFloat("gstorms_time_of_day", time)
        SetGlobalInt("gstorms_day_number", gs_timetable.dayNumber)
    
        local skyboxConVar = GetConVar("gstorms_compat_skybox_modifications")
        if !lighting_and_environment or !fog_table or !skyboxConVar or !skyboxConVar:GetBool() then return end

        local maxPrecipitationMultiplier = envPrecipCache.server
        local fromKey, toKey, phaseLerpValue = GSGetPhaseKeysAndVal(time)
        local fogParams = GSBuildFogParams(fromKey, toKey, phaseLerpValue, maxPrecipitationMultiplier, 0)
    
        GSHandleSkyboxLighting(time, maxPrecipitationMultiplier)
        GSHandleTonemapFromFogBottom(maxPrecipitationMultiplier, fogParams.world.colorVec)
        GSHandleSunDayNight(time, maxPrecipitationMultiplier)
    
    end)

    timer.Simple(1, function()
        if !GetConVar("gstorms_compat_skybox_modifications"):GetBool() then return end
        RunConsoleCommand("sv_skyname", "painted")
        startingTimeCurTime = dayLengthSeconds / 3.85
        gs_timetable.dayNumber = 1
        gs_timetable.t = 0
        SetGlobalInt("gstorms_day_number", gs_timetable.dayNumber)

        local skyboxCvar = GetConVar("gstorms_compat_skybox_modifications"):GetBool()
        local fogCvar = GetConVar("gstorms_compat_fog_modifications"):GetBool()
        local forceRemoveAllInit = {}
        local lstForRemoval = {}
        
        if skyboxCvar and fogCvar then
            lstForRemoval = {"edit_sun", "env_sun", "env_skypaint", "edit_fog", "edit_sky", "env_tonemap_controller"}
            forceRemoveAllInit = {edit_sky = true, edit_fog = true, edit_sun = true, env_skypaint = true, env_tonemap_controller = true, env_sun = true}
        elseif fogCvar then
            lstForRemoval = {"edit_fog"}
            forceRemoveAllInit = {edit_fog = true}
        elseif skyboxCvar then
            lstForRemoval = {"edit_sun", "env_sun", "env_skypaint", "edit_sky", "env_tonemap_controller"}
            forceRemoveAllInit = {edit_sky = true, edit_sun = true, env_skypaint = true, env_tonemap_controller = true, env_sun = true}
        end

        GSRemoveExcessDayNightEntities(lstForRemoval, forceRemoveAllInit)
    end)

    timer.Create("sendTimeTableToClients", 1, 0, function()
        net.Start("gs_timetable_to_clients")
        net.WriteTable(gs_timetable)
        net.Broadcast()
    end)

end

if CLIENT then

    local moonMat = Material("other/moon/gs_moon_512", "smooth noclamp")
    
    local function GSIsNight(time) return time < sunrise or time >= sunset end
    
    local function GSGetMoonAngles(time)
        local nightSpan = (1 - sunset) + sunrise
        local orbitLerpValue = (time >= sunset) and ((time - sunset) / nightSpan) or ((time + (1 - sunset)) / nightSpan)
        local orbitSize = math.sin(orbitLerpValue * mathPi)
    
        local yaw = Lerp(orbitLerpValue, 90, 270)
        local pitch = -(orbitSize * 60)
    
        return pitch, yaw
    end

    local function GSGetMoonFadeFrac(time)
        if time >= sunset and time < sunset + skyColorTransitionTime then
            return math.Clamp((time - sunset) / skyColorTransitionTime, 0, 1)
        elseif time >= sunset + skyColorTransitionTime or time < sunrise - skyColorTransitionTime then
            return 1
        elseif time >= sunrise - skyColorTransitionTime and time < sunrise then
            return 1 - math.Clamp((time - (sunrise - skyColorTransitionTime)) / skyColorTransitionTime, 0, 1)
        end
    
        return 0
    end
    
    local function GSDrawMoon()
        if !GetConVar("gstorms_compat_skybox_modifications"):GetBool() then return end
    
        local time = GetGlobalFloat("gstorms_time_of_day", 0)
        if !GSIsNight(time) then return end
    
        local maxPrecipMult = envPrecipCache.client
        local visibilityFraction = 1 - GSClamp01(maxPrecipMult * 0.75)
        local moonCol = Color(255, 255, 255, 125 * visibilityFraction * GSGetMoonFadeFrac(time))
    
        local pitch, yaw = GSGetMoonAngles(time)
        local ang = Angle(pitch, yaw, 0)
        local dir = ang:Forward()
    
        local dist = 20000
        local size = 1250
        local pos = EyePos() + dir * dist
    
        render.SetLightingMode(2)
        render.SetMaterial(moonMat)
        render.DrawQuadEasy(pos, -dir, size, size, moonCol, 0)
        render.SetLightingMode(0)
    end
    
    hook.Add("PostDraw2DSkyBox", "GStorms_DrawMoon_2DSky", function()
        GSDrawMoon()
    end)

    net.Receive("gs_timetable_to_clients", function() gs_timetable = net.ReadTable() end)
    
    local function GSGetClientTime()
        gs_timetable.t = GetGlobalFloat("gstorms_time_of_day") or 0
        gs_timetable.dayNumber = GetGlobalInt("gstorms_day_number") or math.max(gs_timetable.dayNumber, 1)
        return gs_timetable.t
    end

    local function GSApplyFog(parameters, scale, modifyColor)
        local fogScale = scale or 1
    
        render.FogMode(MATERIAL_FOG_LINEAR)
        render.FogStart(parameters.fogStart * fogScale)
        render.FogEnd(parameters.fogEnd * fogScale)
        render.FogMaxDensity(parameters.density)
    
        if modifyColor then
            render.FogColor(math.floor(parameters.colorVec.x * 255 + 0.5), math.floor(parameters.colorVec.y * 255 + 0.5), math.floor(parameters.colorVec.z * 255 + 0.5))
        end
    end

    local gsFogCache = { frame = -1, params = nil }

    local function GSComputeFogParamsCached()

        local localPlayer = LocalPlayer()

        if !IsValid(localPlayer) then return nil end
    
        local currentFrame = FrameNumber()

        if gsFogCache.frame == currentFrame and gsFogCache.params then return gsFogCache.params end
    
        local currentTime = GSGetClientTime()
        local fromKey, toKey, phaseLerpValue = GSGetPhaseKeysAndVal(currentTime)
        local reflectivityValue, _, tornadoParent = GSGetStormReflectivityValueFromPoint(localPlayer:GetPos(), false, gs_weatherEntityList.client)

        if !tornadoParent or !tornadoParent.EnableRain then reflectivityValue = 0 end
    
        gsFogCache.params = GSBuildFogParams(fromKey, toKey, phaseLerpValue, envPrecipCache.client, math.Clamp((reflectivityValue or 0) / reflectivityMaxFog, 0, 1))
        gsFogCache.frame = currentFrame

        return gsFogCache.params

    end

    local function GSHandleFogHook(parameters, scale)
        if !lighting_and_environment or !fog_table or !GetConVar("gstorms_compat_fog_modifications"):GetBool() then return end
    
        local fogParams = GSComputeFogParamsCached()
        if !fogParams then return end
    
        local skyboxConVar = GetConVar("gstorms_compat_skybox_modifications")
        GSApplyFog(fogParams[parameters], scale, skyboxConVar and skyboxConVar:GetBool())
    
        return true
    end
    
    hook.Add("SetupWorldFog", "GStorms_SetupWorldFog", function()
        return GSHandleFogHook("world")
    end)
    
    hook.Add("SetupSkyboxFog", "GStorms_SetupSkyboxFog", function(scale)
        return GSHandleFogHook("skybox", scale)
    end)

    local snowTexture = Material("nature/snowfloor001a"):GetTexture("$basetexture")
    local snowMaterialsApplied, snowMaterialBackups, snowTextureParams = false, {}, {"$basetexture", "$basetexture2"}
    local snowOverlayFragmentsOldValue = nil -- Prevents annoying world geometry that render.WorldMaterialOverride would catch but is ultimately missed in this new system
    local snowGroundMaterials = {
        ["grass"] = true,
        ["dirt"] = true,
        ["mud"] = true,
        ["sand"] = true,
        ["gravel"] = true,
        ["rock"] = true,
        ["pavement"] = true,
        ["asphalt"] = true,
        ["road"] = true,
        ["eoad"] = true,
        ["curb"] = true,
        ["land"] = true,
        ["floor"] = true,
        ["cliff"] = true,
        ["path"] = true,
    }

    local function GSNormalizeMaterialName(materialName)
        materialName = string.lower(materialName or "")
        materialName = string.gsub(materialName, "\\", "/")
        materialName = string.gsub(materialName, "^materials/", "")
        materialName = string.gsub(materialName, "%.vmt$", "")
        materialName = string.gsub(materialName, "%.vtf$", "")

        local mapMaterialName = string.match(materialName, "^maps/[^/]+/(.+)$")
        if mapMaterialName then materialName = mapMaterialName end

        materialName = string.gsub(materialName, "_wvt_patch$", "")
        materialName = string.gsub(materialName, "_patch$", "")
        materialName = string.gsub(materialName, "_%-?%d+_%-?%d+_%-?%d+$", "")

        return materialName
    end

    local function GSIsSnowGroundMaterial(materialName)
        local fileName = string.match(GSNormalizeMaterialName(materialName), "([^/]+)$") or materialName

        if snowGroundMaterials[fileName] then return true end

        for groundMaterialName, enabled in pairs(snowGroundMaterials) do
            if enabled and string.find(fileName, groundMaterialName, 1, true) then return true end
        end

        return false
    end

    local function GSApplySnowTexture(mat, backup, param)
        local oldTexture = backup[param]
    
        if oldTexture == false then return end
    
        if oldTexture == nil then
            oldTexture = mat:GetString(param)
    
            if !oldTexture or oldTexture == "" then
                backup[param] = false
                return
            end
    
            backup[param] = oldTexture
        end
    
        mat:SetTexture(param, snowTexture)
    end
    

    local function GSApplySnow(materialName, mat, state, backup)
        if state then
            backup = snowMaterialBackups[materialName]
    
            if !backup then
                backup = {}
                snowMaterialBackups[materialName] = backup
            end
    
            for i = 1, #snowTextureParams do
                GSApplySnowTexture(mat, backup, snowTextureParams[i])
            end
        else
            for param, oldTexture in pairs(backup) do
                if oldTexture and oldTexture != false then mat:SetTexture(param, oldTexture) end
            end
        end
    end

    local function GSSetSnowOverlayFragments(state)
        if state == (snowOverlayFragmentsOldValue != nil) then return end

        local conVar = GetConVar("r_renderoverlayfragment")
        if !conVar then return end

        if state then snowOverlayFragmentsOldValue = conVar:GetString() end

        RunConsoleCommand("r_renderoverlayfragment", state and "0" or snowOverlayFragmentsOldValue)

        if !state then snowOverlayFragmentsOldValue = nil end
    end

    local function GSSetSnow(state)
        state = tobool(state)

        if snowMaterialsApplied == state then
            GSSetSnowOverlayFragments(state)
            return
        end

        if state and !snowTexture then return end

        if state then
            local world = game.GetWorld()
            if !world then return end
            
            local materials = world:GetMaterials()

            for i = 1, #materials do
                local materialName = materials[i]

                if !GSIsSnowGroundMaterial(materialName) then continue end

                local mat = Material(materialName)
                if !mat or mat:IsError() then continue end

                GSApplySnow(materialName, mat, true)
            end
        else
            for materialName, backup in pairs(snowMaterialBackups) do
                local mat = Material(materialName)
                if !mat or mat:IsError() then continue end

                GSApplySnow(materialName, mat, false, backup)
            end

            snowMaterialBackups = {}
        end

        snowMaterialsApplied = state
        GSSetSnowOverlayFragments(state)
    end

    hook.Add("Think", "GS_Snow_GroundMaterials", function()
        GetMaxPrecipitationMultiplier(gs_weatherEntityList.client)
        GSSetSnow(GetGlobalBool("gs_is_snowing", false) and GetConVar("gstorms_compat_ground_modifications"):GetBool())
    end)

    hook.Add("ShutDown", "GS_Snow_GroundMaterials_Reset", function() GSSetSnow(false) end)
    
    local function SRGBToLin(x) return x * x end
    local function LinToSRGB(x) return math.sqrt(x) end
    
    local function DesaturateTowardLuma(red, green, blue, amount)
        local luminance = Luma(red, green, blue)
        return luminance + (red - luminance) * amount, luminance + (green - luminance) * amount, luminance + (blue - luminance) * amount
    end
    
    local function NormalizeHueL1(red, green, blue)
        local magnitude = red + green + blue
        if magnitude <= tiny then return 0.3333, 0.3333, 0.3333 end
        local inverseMagnitude = 1 / magnitude
        return red * inverseMagnitude, green * inverseMagnitude, blue * inverseMagnitude
    end
    
    local function ApplyPairContrast(highlightRed, highlightGreen, highlightBlue, shadowRed, shadowGreen, shadowBlue, contrastAmount)
        local midpointRed = (highlightRed + shadowRed) * 0.5
        local midpointGreen = (highlightGreen + shadowGreen) * 0.5
        local midpointBlue = (highlightBlue + shadowBlue) * 0.5
        return midpointRed + (highlightRed - midpointRed) * contrastAmount, midpointGreen + (highlightGreen - midpointGreen) * contrastAmount, midpointBlue + (highlightBlue - midpointBlue) * contrastAmount, midpointRed + (shadowRed - midpointRed) * contrastAmount, midpointGreen + (shadowGreen - midpointGreen) * contrastAmount, midpointBlue + (shadowBlue - midpointBlue) * contrastAmount
    end
    
    local function ToneMapPreserveHue(red, green, blue)
        local maxChannel = math.max(red, math.max(green, blue))
        if maxChannel <= 0 then return 0, 0, 0 end
        local inverseScale = 1 / (1 + maxChannel)
        return red * inverseScale, green * inverseScale, blue * inverseScale
    end
    
    local function ToByte(x)
        if x <= 0 then return 0 elseif x >= 1 then return 255 end
        return LinToSRGB(x) * 255
    end
    
    local function Sat01_FromLinRGB(red, green, blue)
        local maxChannel = math.max(red, math.max(green, blue))
        if maxChannel <= tiny then return 0 end
        local minChannel = math.min(red, math.min(green, blue))
        return (maxChannel - minChannel) / maxChannel
    end
    
    local function TintResponse_FromLinRGB(red, green, blue)
        local saturation = Sat01_FromLinRGB(red, green, blue)
        local tintResistance = 1 - saturation * lighting_and_environment.controls.tint_control
        if tintResistance <= 0 then return 0 elseif tintResistance >= 1 then return 1 end
        return tintResistance * tintResistance
    end
    
    local gsLightCacheFrame = -1
    local gsAmbientRed, gsAmbientGreen, gsAmbientBlue = 1, 1, 1
    local gsSunRed, gsSunGreen, gsSunBlue = 1, 1, 1
    local gsAmbientIntensity, gsSunIntensity = 0, 0
    local gsSunWrap = 0.20
    local gsContrastStrength = 1
    
    local function ComputeSkyLightPacket()

        local currentFrame = FrameNumber()
        if currentFrame == gsLightCacheFrame then return end
        gsLightCacheFrame = currentFrame
    
        local precipMultMax = envPrecipCache.client
        local topColorVec, bottomColorVec, _, sunColorVec = GSGetSkyTopAndBottomColors(GSGetClientTime(), precipMultMax)

        local volumetricAmount = GSClamp01(precipMultMax * lighting_and_environment.controls.volumetric_strength)
        local topRed, topGreen, topBlue = topColorVec.x * topColorVec.x, topColorVec.y * topColorVec.y, topColorVec.z * topColorVec.z
        local bottomRed, bottomGreen, bottomBlue = bottomColorVec.x * bottomColorVec.x, bottomColorVec.y * bottomColorVec.y, bottomColorVec.z * bottomColorVec.z
    
        local topLuminance = Luma(topRed, topGreen, topBlue)
        local bottomLuminance = Luma(bottomRed, bottomGreen, bottomBlue)
    
        local skyLuminance = (topLuminance * 0.62) + (bottomLuminance * 0.38)
        if skyLuminance < tiny then skyLuminance = tiny end

        local gradientRed, gradientGreen, gradientBlue = topRed - bottomRed, topGreen - bottomGreen, topBlue - bottomBlue
        local directLightAmount = GSClamp01((math.abs(gradientRed) + math.abs(gradientGreen) + math.abs(gradientBlue)) / skyLuminance)
    
        local exposureAmount = lighting_and_environment.controls.exposure_strength * ((skyLuminance ^ 0.80) ^ lighting_and_environment.controls.exposure_exponent)
    
        local tintBlend = lighting_and_environment.controls.tint_strength * (0.55 + 0.45 * (1 - GSClamp01(skyLuminance)))
        if tintBlend < 0 then tintBlend = 0 elseif tintBlend > 1 then tintBlend = 1 end

        local ambientBaseRed = bottomRed + (topRed - bottomRed) * 0.52
        local ambientBaseGreen = bottomGreen + (topGreen - bottomGreen) * 0.52
        local ambientBaseBlue = bottomBlue + (topBlue - bottomBlue) * 0.52
        ambientBaseRed, ambientBaseGreen, ambientBaseBlue = DesaturateTowardLuma(ambientBaseRed, ambientBaseGreen, ambientBaseBlue, tintBlend)
        gsAmbientRed, gsAmbientGreen, gsAmbientBlue = NormalizeHueL1(ambientBaseRed, ambientBaseGreen, ambientBaseBlue)

        local sunBaseRed, sunBaseGreen, sunBaseBlue = sunColorVec.x * sunColorVec.x, sunColorVec.y * sunColorVec.y, sunColorVec.z * sunColorVec.z
        local sunLuminance = Luma(sunBaseRed, sunBaseGreen, sunBaseBlue)
    
        gsSunRed, gsSunGreen, gsSunBlue = NormalizeHueL1(DesaturateTowardLuma(sunBaseRed, sunBaseGreen, sunBaseBlue, tintBlend))

        gsAmbientIntensity = exposureAmount * ((0.70 + (1 - directLightAmount) * 0.25) * (1 + volumetricAmount * 0.45))
        gsSunIntensity = exposureAmount * (sunLuminance * (1 - volumetricAmount * 0.85))
        gsSunWrap = GSClamp01((0.12 + (1 - directLightAmount) * 0.18) + (volumetricAmount * 0.48))
        gsContrastStrength = 0.55 + lighting_and_environment.controls.contrast_strength * 0.85

    end
    
    local gsNightColorModify = {
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = 0,
        ["$pp_colour_contrast"] = 1,
        ["$pp_colour_colour"] = 1,
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0
    }
    
    local function GSHandleNightColorModify()
        if !GetConVar("gstorms_compat_skybox_modifications"):GetBool() then return end
    
        local nightFraction = GSGetMoonFadeFrac(GSGetClientTime())
        if nightFraction <= 0.001 then return end
    
        local controls = lighting_and_environment and lighting_and_environment.controls
    
        local nightTimeDarknessAmount = controls and controls.night_darkness
        local nightTimeDesaturate = controls and controls.night_desaturate
    
        local darknessStrength = nightFraction * GSClamp01(nightTimeDarknessAmount)
        local desaturationStrength = nightFraction * GSClamp01(nightTimeDesaturate)
    
        gsNightColorModify["$pp_colour_addr"] = 0
        gsNightColorModify["$pp_colour_addg"] = 0
        gsNightColorModify["$pp_colour_addb"] = 0
    
        gsNightColorModify["$pp_colour_brightness"] = -darknessStrength * 0.35
        gsNightColorModify["$pp_colour_contrast"] = 1 - darknessStrength * 0.4
        gsNightColorModify["$pp_colour_colour"] = 1 - desaturationStrength
    
        gsNightColorModify["$pp_colour_mulr"] = 0
        gsNightColorModify["$pp_colour_mulg"] = 0
        gsNightColorModify["$pp_colour_mulb"] = 0
    
        DrawColorModify(gsNightColorModify)
    end
    
    hook.Add("RenderScreenspaceEffects", "GStorms_NightColorModify", function()
        GSHandleNightColorModify()
    end)
    
    function GSGetLightEnvironment(highlights, shadows, staticColor, isStaticColor)

        if !lighting_and_environment or lighting_and_environment.legacy_lighting then
            if staticColor then return staticColor end
            return highlights, shadows
        end

        ComputeSkyLightPacket()
    
        local ambientRed = gsAmbientRed * gsAmbientIntensity
        local ambientGreen = gsAmbientGreen * gsAmbientIntensity
        local ambientBlue = gsAmbientBlue * gsAmbientIntensity
        local sunRed = gsSunRed * gsSunIntensity
        local sunGreen = gsSunGreen * gsSunIntensity
        local sunBlue = gsSunBlue * gsSunIntensity
    
        if !isStaticColor then
    
            local highlightRed = SRGBToLin(highlights.r * inv255)
            local highlightGreen = SRGBToLin(highlights.g * inv255)
            local highlightBlue = SRGBToLin(highlights.b * inv255)
    
            local shadowRed = SRGBToLin(shadows.r * inv255)
            local shadowGreen = SRGBToLin(shadows.g * inv255)
            local shadowBlue = SRGBToLin(shadows.b * inv255)
    
            local adjustedHighlightRed, adjustedHighlightGreen, adjustedHighlightBlue, adjustedShadowRed, adjustedShadowGreen, adjustedShadowBlue = ApplyPairContrast(highlightRed, highlightGreen, highlightBlue, shadowRed, shadowGreen, shadowBlue, gsContrastStrength)
    
            local highlightLightRed = ambientRed + sunRed
            local highlightLightGreen = ambientGreen + sunGreen
            local highlightLightBlue = ambientBlue + sunBlue
    
            local shadowLightRed = ambientRed + sunRed * gsSunWrap
            local shadowLightGreen = ambientGreen + sunGreen * gsSunWrap
            local shadowLightBlue = ambientBlue + sunBlue * gsSunWrap
    
            local tintResponse = TintResponse_FromLinRGB((adjustedHighlightRed + adjustedShadowRed) * 0.5, (adjustedHighlightGreen + adjustedShadowGreen) * 0.5, (adjustedHighlightBlue + adjustedShadowBlue) * 0.5)
    
            highlightLightRed, highlightLightGreen, highlightLightBlue = DesaturateTowardLuma(highlightLightRed, highlightLightGreen, highlightLightBlue, tintResponse)
            shadowLightRed, shadowLightGreen, shadowLightBlue = DesaturateTowardLuma(shadowLightRed, shadowLightGreen, shadowLightBlue, tintResponse)
    
            adjustedHighlightRed = adjustedHighlightRed * highlightLightRed
            adjustedHighlightGreen = adjustedHighlightGreen * highlightLightGreen
            adjustedHighlightBlue = adjustedHighlightBlue * highlightLightBlue

            adjustedShadowRed = adjustedShadowRed * shadowLightRed
            adjustedShadowGreen = adjustedShadowGreen * shadowLightGreen
            adjustedShadowBlue = adjustedShadowBlue * shadowLightBlue
    
            adjustedHighlightRed, adjustedHighlightGreen, adjustedHighlightBlue = ToneMapPreserveHue(adjustedHighlightRed, adjustedHighlightGreen, adjustedHighlightBlue)
            adjustedShadowRed, adjustedShadowGreen, adjustedShadowBlue = ToneMapPreserveHue(adjustedShadowRed, adjustedShadowGreen, adjustedShadowBlue)
    
            return Color(ToByte(adjustedHighlightRed), ToByte(adjustedHighlightGreen), ToByte(adjustedHighlightBlue)), Color(ToByte(adjustedShadowRed), ToByte(adjustedShadowGreen), ToByte(adjustedShadowBlue))
    
        else
    
            local staticRed = SRGBToLin(staticColor.r * inv255)
            local staticGreen = SRGBToLin(staticColor.g * inv255)
            local staticBlue = SRGBToLin(staticColor.b * inv255)
    
            local sunMix = 0.35 + 0.65 * gsSunWrap
            local staticLightRed = ambientRed + sunRed * sunMix
            local staticLightGreen = ambientGreen + sunGreen * sunMix
            local staticLightBlue = ambientBlue + sunBlue * sunMix
    
            local tintResponse = TintResponse_FromLinRGB(staticRed, staticGreen, staticBlue)
            staticLightRed, staticLightGreen, staticLightBlue = DesaturateTowardLuma(staticLightRed, staticLightGreen, staticLightBlue, tintResponse)
    
            staticRed, staticGreen, staticBlue = ToneMapPreserveHue(staticRed * staticLightRed, staticGreen * staticLightGreen, staticBlue * staticLightBlue)
    
            return Color(ToByte(staticRed), ToByte(staticGreen), ToByte(staticBlue))

        end
    end
end