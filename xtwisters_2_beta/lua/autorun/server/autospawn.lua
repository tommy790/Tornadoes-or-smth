AddCSLuaFile()

-- FORTYFOUR's Autospawn Handler (this is an amalgamation of my worst thoughts...)

-- INIT GENERAL FUNCTIONS:

-- INCLUDES DYNAMIC CAPE, SRH, RH, TEMP, LAPSE, SPAWN CHANCES, QUARTERED DAYS, DAY LENGTHS, TORNADOES, DUST DEVILS, GUSTNADO'S AND MORE WHICH ALL CORRESPOND TO EVERYTHING AFOREMENTIONED... I LOVE MATH    \_(0_0|)_/  
---------------------------------------------------------------------------------------------------------------------------------------------

local DefaultSkybox = "sky_day02_10"
local HighRHSkybox = {"sky_day01_09","sky_borealis01"}
local LowRHSkybox = {"sky_day02_07","sky_day02_06","sky_day02_05","sky_day02_04","sky_day02_03","sky_day02_02","sky_day02_01","sky_day03_04","sky_day02_09"}
local number = 1
local dayLength = 1440

if SERVER then
	storedTimerNamesXT2 = {}
	local KeepTrackOfLiveTornadoes = {}
	function ResetKeepTrackOfLiveTornadoesXT2()
		if KeepTrackOfLiveTornadoes then
			KeepTrackOfLiveTornadoes = {}
		end
	end
	function CheckIfEntIsValidXT2() -- Function to handle valid ent checks to check how many tors are in the world at once.
		for k, v in ipairs(KeepTrackOfLiveTornadoes) do
			if !IsValid(v) then
				table.RemoveByValue(KeepTrackOfLiveTornadoes, v)
				spawnedTornadoesInWorld = spawnedTornadoesInWorld - 1
				math.max(0, spawnedTornadoesInWorld)
			end
		end
		math.max(0, spawnedTornadoesInWorld)
	end

	function AddEntToValidCheckXT2(entname) -- Adding to the valid check.
		if entname and IsValid(entname) then
			table.insert(KeepTrackOfLiveTornadoes, entname)
		end
	end

	function IsXT2TornadoValid(entname) -- Checking Validity
		if entname then
			if IsValid(entname) then
				return true
			else
				return false
			end
		end
	end
end

local defaultconvars = { -- Used for !xt2 resetconfig, if !xt2 resetconfig then it basically resets all of the convars to their respective defaults etc,.
    {name = "xt2_updatethermosrate", default = "5.0"},
    {name = "xt2_derechochance", default = "5.0"},
    {name = "xt2_hailstormchance", default = "5.0"},
    {name = "xt2_enablext2chatcommands", default = "false"},
    {name = "xt2_highcapeeventchance", default = "5.0"},
    {name = "xt2_outbreakeventchance", default = "5.0"},
    {name = "xt2_vtpcommonality", default = "5.0"},
    {name = "xt2_enableevents", default = "0"},
    {name = "xt2_autospawnweather", default = "0"},
    {name = "xt2_autospawntornadoes", default = "0"},
    {name = "xt2_printrisklevel", default = "0"},
    {name = "xt2_autospawnwhirlwinds", default = "0"},
    {name = "xt2_stormchance", default = "5.0"},
    {name = "xt2_rainstormchance", default = "5.0"},
    {name = "xt2_tornadochance", default = "5.0"},
    {name = "xt2_whirlwindchance", default = "5.0"},
    {name = "xt2_t_lifetime_autospawn", default = "5.0"},
    {name = "xt2_s_lifetime_autospawn", default = "5.0"},
    {name = "xt2_noriskchance", default = "10.0"},
    {name = "xt2_xspeed", default = "1.0"},
    {name = "xt2_screenshake", default = "true"},
    {name = "xt2_tlifetime", default = "400"},
    {name = "xt2_antilag", default = "1"},
    {name = "xt2_arcadesounds", default = "1"},
    {name = "xt2_customskyboxes", default = "0"},
    {name = "xt2_lightningintornadoes", default = "1"},
    {name = "xt2_subvorts", default = "1"},
    {name = "xt2_subscour", default = "1"},
    {name = "xt2_rfdsimulation", default = "0"},
    {name = "xt2_windblockedbyobjects", default = "0"},
    {name = "xt2_hurtprops", default = "1"},
    {name = "xt2_unweldprops", default = "1"},
    {name = "xt2_sharknadochance", default = "5"},
    {name = "xt2_autospawnsharknadoes", default = "0"},
    {name = "xt2_f12chance", default = "5"},
    {name = "xt2_autospawnf12s", default = "0"},
    {name = "xt2_f35chance", default = "5"},
    {name = "xt2_autospawnf35s", default = "0"},
    {name = "xt2_debriseffect", default = "1"}
}

local function roundforautospawn(number)
	if number >= 0 then
		return math.floor(number + 0.5)
	else
		return math.ceil(number - 0.5)
	end
end

local function roundforautospawn2(number)
    if number == 0 then
        return 0
    else
        return math.floor(number * 10 + 0.5) / 10
    end
end

local function TemperatureMultiplierDustDevils(temperaturemultdustdevils)
	local temperaturefactorreturn
	if temperaturemultdustdevils > 68 then
		temperaturefactorreturn = (68 / temperaturemultdustdevils)^2.5 + 0.1 -- Less common the colder it is
	else
		temperaturefactorreturn = 0 -- Sets the chance to 0 (which in my timer means that it doesn't run the spawn function)
	end
	return temperaturefactorreturn -- Return temp factor for dust devil spawn chance
end

local function RHMultDustDevilsFunction(rhmultfordustdevils)
	local returnRHmultdd
	if rhmultfordustdevils < 60 then 
		returnRHmultdd = (100/rhmultfordustdevils) + 0.25
	else
		returnRHmultdd = 0
	end
	return returnRHmultdd
end

if SERVER then
	-- INITIALIZE LOCAL and GENERAL CLASS CLASS VARIABLES
	saveOldSkyboxState = nil
	spawnedTornadoesInWorld = 0
	globalRainstormCount = 0
	globalThunderstormCount = 0
	temperature = math.random(60, 90)
	SRH = math.random(50, 125)
	Cape = math.random(500, 1500)
	RH = math.random(35, 90)
	LAPSE = (math.random(40, 99) / 10)
	local StormSpawnChance = 0
	local TornadoEveryXChance = 0
	local SharknadoEveryXChance = 0
	local F35EveryXChance = 0
	local F12EveryXChance = 0
	local RainSpawnChance = 0
	local GustnadoSpawnChance = 0
	local DustDevilSpawnChance = 0
	local FirewhirlSpawnChance = 0
	local f0
	local f1
	local f2
	local f3
	local f4
	local f5
	isNoRisk = true

	local function computeWeight(srh, cape, lapse, srhIdeal, capeIdeal, lapseIdeal, srhBase, capeBase, lapseBase, factor)
		-- Calculate ratios for SRH, CAPE, and lapse rate relative to their ideal values
		local srhRatio = srh / srhIdeal
		local capeRatio = cape / capeIdeal
		local lapseRatio = (10.0 - math.abs(lapse - lapseIdeal)) / 10.0  -- Normalize and invert lapse difference for better influence
	
		-- Adjust the weight based on the average of the ratios
		local weight = (srhRatio + capeRatio + lapseRatio) / 3 * factor
	
		-- Adjust the base calculations for SRH, CAPE, and lapse rate
		local srhBaseAdjustment = math.log((srh / srhBase) + 1)
		local capeBaseAdjustment = math.log((cape / capeBase) + 1)
		local lapseBaseAdjustment = math.log((10.0 - math.abs(lapse - lapseBase)) / 10.0 + 1) -- Adding lapses to the scenario since I didn't have lapse before.
	
		-- Combine all adjustments into the final weight calculation
		local baseAdjustment = srhBaseAdjustment * capeBaseAdjustment * lapseBaseAdjustment
	
		return weight * baseAdjustment
	end
	

	local function capeDeductionFactor(Cape, tierEffect)
		if Cape < 6000 then
			return 1 -- No deduction if Cape is below 6000
		else
			local capeExcess = Cape - 6000
			-- The deduction increases with Cape excess and is more defined for higher tiers to simulate how ideal cape conditions manifest tornadoes.
			return math.max(0, 1 - (capeExcess * 0.00002 * ((tierEffect)^1.5)))
		end
	end
	
	-- Adjusted weight function for EF-0 --AAAAAH I HATE MY LIFE I'VE REBALANCED THESE LIKE 7 TIMES ALREADY HOLY SHIT..... FUCK IT, VTP COMMONALITY SVCONVAR....
	function weightef0()
		local VTPCommonality = GetConVar("xt2_vtpcommonality"):GetInt()
		local adjustmentFactor = 1 + (0.1 * (VTPCommonality - 5))
		local deductionFactor = capeDeductionFactor(Cape, 1) -- Least affected by high Cape
		local weightef0temp = ((computeWeight(SRH, Cape, LAPSE, 100, 1500, 4.0, 50, 500, 0.0, 4)^0.65) * (4.0 * adjustmentFactor^0.2)) ^ 0.6
		weightef0temp = weightef0temp * deductionFactor
		if weightef0temp < 1 then
			weightef0temp = 1
		end
		math.max(1, weightef0temp)
		return weightef0temp
	end
	
	-- Repeating the logic for EF-1 to EF-4 with increasing tierEffect
	function weightef1()
		local VTPCommonality = GetConVar("xt2_vtpcommonality"):GetInt()
		local deductionFactor = capeDeductionFactor(Cape, 2) -- Slightly more affected
		local adjustmentFactor = 1 + (0.1 * (VTPCommonality - 5))
		local returnVal = ((computeWeight(SRH, Cape, LAPSE, 150, 2000, 5.5, 100, 1000, 4.0, 6)^0.75) * (3.5 * adjustmentFactor^0.4) * deductionFactor) ^ 0.75
		math.max(0, returnVal)
		if returnVal >= 1 then
			return returnVal
		else
			return 0
		end
	end
	
	function weightef2()
		local VTPCommonality = GetConVar("xt2_vtpcommonality"):GetInt()
		local deductionFactor = capeDeductionFactor(Cape, 3) -- Moderately affected
		local adjustmentFactor = 1 + (0.1 * (VTPCommonality - 5))
		local returnVal = ((computeWeight(SRH, Cape, LAPSE, 200, 2500, 7.0, 125, 1750, 5.0, 7)^0.825) * (3.5 * adjustmentFactor^0.6) * deductionFactor) ^ 1.05
		math.max(0, returnVal)
		if returnVal >= 1 then
			return returnVal
		else
			return 0
		end
	end
	
	function weightef3()
		local VTPCommonality = GetConVar("xt2_vtpcommonality"):GetInt()
		local deductionFactor = capeDeductionFactor(Cape, 4) -- Highly affected
		local adjustmentFactor = 1 + (0.1 * (VTPCommonality - 5))
		local returnVal = ((computeWeight(SRH, Cape, LAPSE, 250, 3000, 8.0, 225, 2000, 6.0, 5)^1.05) * (3.5 * adjustmentFactor^0.8) * deductionFactor) ^ 1.5
		math.max(0, returnVal)
		if returnVal >= 1 then
			return returnVal
		else
			return 0
		end
	end
	
	function weightef4()
		local VTPCommonality = GetConVar("xt2_vtpcommonality"):GetInt()
		local deductionFactor = capeDeductionFactor(Cape, 6) -- Significantly affected
		local adjustmentFactor = 1 + (0.1 * (VTPCommonality - 5))
		local returnVal = ((computeWeight(SRH, Cape, LAPSE, 275, 3500, 8.5, 250, 2500, 7.0, 2)^1.275) * (3.5 * adjustmentFactor) * deductionFactor) ^ 2.5
		math.max(0, returnVal)
		if returnVal >= 1 then
			return returnVal
		else
			return 0
		end
	end
	
	-- EF-5 gets the most significant deduction effect due to high Cape values
	function weightef5()
		local VTPCommonality = GetConVar("xt2_vtpcommonality"):GetInt()
		local deductionFactor = capeDeductionFactor(Cape, 8) -- Most significantly affected
		local adjustmentFactor = 1 + (0.1 * (VTPCommonality - 5))
		local returnVal = (((computeWeight(SRH, Cape, LAPSE, 300, 4400, 9.0, 300, 2750, 7.5, 1.5)^1.6) * (3.5 * adjustmentFactor^1.2) * deductionFactor) ^ 3.5 )
		math.max(0, returnVal)
		if returnVal >= 1 then
			return returnVal
		else
			return 0
		end
	end
	function GetMaxWindsForAutospawn(BooleanValIsAnticyclonic)
		local totalWeight = roundforautospawn2(weightef0()) + roundforautospawn2(weightef1()) + roundforautospawn2(weightef2()) + roundforautospawn2(weightef3()) + roundforautospawn2(weightef4()) + roundforautospawn2(weightef5())
		local randomNum = math.random(1, totalWeight)
		if BooleanValIsAnticyclonic == true then
			local MaxWindsAnticyclonic = math.random(65, 135)
			return MaxWindsAnticyclonic
		elseif randomNum <= weightef0() then
			local MaxWindsEF0 = math.random(65,85)
			return MaxWindsEF0
		elseif randomNum <= weightef0() + weightef1() then
			local MaxWindsEF1 = math.random(86,110)
			return MaxWindsEF1
		elseif randomNum <= weightef0() + weightef1() + weightef2() then
			local MaxWindsEF2 = math.random(111,135)
			return MaxWindsEF2
		elseif randomNum <= weightef0() + weightef1() + weightef2() + weightef3() then
			local MaxWindsEF3 = math.random(136,165)
			return MaxWindsEF3
		elseif randomNum <= weightef0() + weightef1() + weightef2() + weightef3() + weightef4() then
			local MaxWindsEF4 = math.random(166,200)
			return MaxWindsEF4
		else
			local MaxWindsEF5 = math.random(201,320)
			return MaxWindsEF5
		end
	end

	-- TEMPERATURE MULTIPLIER FUNCTION

	function TemperatureMultiplier(number) -- If Greater or less than 75, return less than 1 in varying floats depending on how far away from 75 the temperature is. 
		if number == 75 then
			return 1
		elseif number < 45 or number > 96 then
			return 0
		elseif number < 75 then
			return (90 - number) / 15
		else
			return (number - 55) / 20
		end
	end
end


-- IF SERVER STARTS HERE ----------------------------------------------------------------------------------------------------------------------------------------------------------------------

if SERVER then                                                                  --THIS IS WHERE IF SERVER STARTS

	-- Same as last time...
	local isHighCAPEEvent = false
	local isOutbreakEvent = false
	local outbreakEndTime = 0
	local highCAPEEventEndTime = 0
	local updateRateCAPE = 4.0
	local updateRateRH = 0.25
	local updateRateTemperature = 0.25
	local updateRateSRH = 1.5
	local updateRateLAPSE = 0.175
	local dayNumber = 0
	local CurrentWeatherType

	local IsAdminCommandSetCape = false
	local IsAdminCommandSetSRH = false
	local IsAdminCommandSetRH = false
	local IsAdminCommandSetTemp = false
	local IsAdminCommandSetLapse = false

	local targetAdminCape = 0
	local targetAdminSRH = 0
	local targetAdminRH = 0
	local targetAdminTemp = 0
	local targetAdminLapse = 0

	function returnIsThundering() -- left for DOW
		return isThundering
	end

	function returnIsRaining() -- left for DOW
		return isRaining
	end

	hook.Add("PreCleanupMap", "OnAdminCleanupForAutospawn", function()
		if storedTimerNamesXT2 ~= {} then
			for k, v in ipairs(storedTimerNamesXT2) do
				if timer.Exists(v) then
					timer.Remove(v)
				end
			end
			storedTimerNamesXT2 = {}
		end
		OnAdminCleanupAutospawn()
	end)

	function determineRainIntensity(rhlocalfunction)
		local rhlocalfunction = rhlocalfunction or RH
		local rainIntensity = 0 -- Default to no rain
		if rhlocalfunction >= 0 and rhlocalfunction <= 40 then
			local chance = math.random(100)
			if chance <= 30 then
				rainIntensity = 0 -- No rain
				return rainIntensity
			elseif chance <= 100 then
				rainIntensity = 1 -- Light rain
				return rainIntensity
			end
		elseif rhlocalfunction >= 41 and rhlocalfunction <= 64 then
			local chance = math.random(100)
			if chance <= 10 then
				rainIntensity = 0 -- No rain
				return rainIntensity
			elseif chance > 10 and chance <= 75 then
				rainIntensity = 1 -- Light rain
				return rainIntensity
			elseif chance <= 100 then
				rainIntensity = 2 -- Heavy rain
				return rainIntensity
			end
		elseif rhlocalfunction >= 65 and rhlocalfunction <= 100 then
			local chance = math.random(100)
			if chance <= 40 then
				rainIntensity = 1 -- Light rain
				return rainIntensity
			elseif chance > 40 and chance <= 80 then
				rainIntensity = 2 -- Heavy rain
				return rainIntensity
			elseif chance <= 100 then
				rainIntensity = 3 -- Extremely heavy rain
				return rainIntensity
			end
		end
	end	

	-- WEATHER ENTS --------------------------------------------------------------------------------------------------------------------------------------------------------------
	local maxNumberOfThunderstormPhases = 10
	local maxNumberOfRainstormPhases = 10
	function SpawnThunderstorm()
		local players = player.GetAll()
		if #players == 0 then
			return -- Exit if no players are present
		end
	
		local randomPlayer = players[math.random(#players)]  -- Simplified random player selection
		local playerPos = randomPlayer:GetPos() -- Get the position of the randomly selected player
		local randomOffset = Vector(math.random(-100, 100), math.random(-100, 100), 0) -- Random offset near the player
		local initialSpawnPosition = playerPos + randomOffset -- Calculate initial position for the storm
	
		local highAltitudePosition = initialSpawnPosition + Vector(0, 0, 1000) -- Set a position high above the initial position
		local traceDownToDetermineAltitude = util.TraceLine({
			start = highAltitudePosition,
			endpos = highAltitudePosition - Vector(0, 0, 10000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if not traceDownToDetermineAltitude.Hit then
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print("[XT2] Thunderstorm Attempted To Form But The Thermodynamics Weren't Right...")
			end
			return
		end
	
		local groundPosition = traceDownToDetermineAltitude.HitPos -- Get the position where the trace hit the ground
		local traceDownForGround = util.TraceLine({
			start = groundPosition,
			endpos = groundPosition - Vector(0, 0, 2000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if traceDownForGround.Hit then
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print("[XT2] Currently Thundering")
			end
			local position = traceDownForGround.HitPos + Vector(0, 0, 1000)
			if globalThunderstormCount == 0 and globalRainstormCount == 0 then
				local removeThunderstormTimer = (550 * (GetCape() / 1000 / 4 + 0.5) * (GetConVar("xt2_s_lifetime_autospawn"):GetInt() / 5)) + math.random(200,300)
				local intforrainthunder = determineRainIntensity(GetRH())
				local hailchancenum = 5^(GetConVar("xt2_hailstormchance"):GetInt() / 5)
				local hailchance = (GetRH() >= 50 and temperature <= 80 and GetCape() >= 1750) and math.random(1, hailchancenum) <= 1 and 1 or 0
				local sequences = {
					[0] = {"xt2_autospawn_thunderstorm_photogenic"},
					[1] = {"xt2_autospawn_thunderstorm_light"},
					[2] = {"xt2_autospawn_thunderstorm_light", "xt2_autospawn_thunderstorm_medium", "xt2_autospawn_thunderstorm_light"},
					[3] = {"xt2_autospawn_thunderstorm_light", "xt2_autospawn_thunderstorm_medium", "xt2_autospawn_thunderstorm_heavy", "xt2_autospawn_thunderstorm_medium", "xt2_autospawn_thunderstorm_light"},
				}
				-- Derecho sequence selection based on conditions
				local derechochancenum = 10^(GetConVar("xt2_derechochance"):GetInt() / 5)
				if GetSRH() > 200 and GetCape() > 2250 and GetRH() > 50 and math.random(1, derechochancenum) <= 1 then
					if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
						local tip = "XT2: A Severe Thunderstorm Warning Has Been Issued, This Storm Is Likely To Produce A Derecho"
						print(tip)
						DisplayTip(tip)
					end
					sequence = {"xt2_autospawn_thunderstorm_light", "xt2_autospawn_thunderstorm_medium", "xt2_autospawn_thunderstorm_derecho", "xt2_autospawn_thunderstorm_medium", "xt2_autospawn_thunderstorm_light"}
				else
					sequence = sequences[intforrainthunder] or sequences[0]
				end
	
				-- Adding hail condition adjustments
				if hailchance == 1 and LAPSE >= 7.0 then
					if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
						local tip = "XT2: A Severe Thunderstorm Warning Has Been Issued, This Storm Is Likely To Produce Baseball Sized Hail."
						print(tip)
						DisplayTip(tip)
					end
					local hailIndex = math.random(1, #sequence)
					sequence[hailIndex] = sequence[hailIndex] .. "_hail"
				end
	
				local phaseDuration = removeThunderstormTimer / #sequence
				for i, entityName in ipairs(sequence) do
					local timerName = "ThunderstormPhase_" .. i
					table.insert(storedTimerNamesXT2, tostring(timerName))
					timer.Create(timerName, phaseDuration * (i - 1), 1, function()
						table.RemoveByValue(storedTimerNamesXT2, tostring(timerName))
						if IsValid(thunderstormEnt) then
							thunderstormEnt:Remove()
						end
						thunderstormEnt = ents.Create(entityName)
						thunderstormEnt:SetPos(position)
						thunderstormEnt:Spawn()
					end)
				end
	
				local cleanupTimerName = "ThunderstormCleanup"
				table.insert(storedTimerNamesXT2, tostring(cleanupTimerName))
				timer.Create(cleanupTimerName, removeThunderstormTimer, 1, function()
					table.RemoveByValue(storedTimerNamesXT2, tostring(cleanupTimerName))
					if IsValid(thunderstormEnt) then
						thunderstormEnt:Remove()
						timer.Remove(cleanupTimerName)
					end
				end)
			end
		end
	end

	function SpawnRainstorm()
		local players = player.GetAll()
		if #players == 0 then
			return -- Exit if no players are present
		end
	
		local randomPlayer = players[math.random(#players)]  -- Simplified random player selection
		local playerPos = randomPlayer:GetPos() -- Get the position of the randomly selected player
		local randomOffset = Vector(math.random(-100, 100), math.random(-100, 100), 0) -- Random offset near the player
		local initialSpawnPosition = playerPos + randomOffset -- Calculate initial position for the storm
	
		local highAltitudePosition = initialSpawnPosition + Vector(0, 0, 1000) -- Set a position high above the initial position
		local traceDownToDetermineAltitude = util.TraceLine({
			start = highAltitudePosition,
			endpos = highAltitudePosition - Vector(0, 0, 10000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if not traceDownToDetermineAltitude.Hit then
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print("[XT2] Rainstorm Attempted To Form But The Thermodynamics Weren't Right...")
			end
			return
		end
	
		local groundPosition = traceDownToDetermineAltitude.HitPos -- Get the position where the trace hit the ground
		local traceDownForGround = util.TraceLine({
			start = groundPosition,
			endpos = groundPosition - Vector(0, 0, 2000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if traceDownForGround.Hit then
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print("[XT2] Currently Raining")
			end
			local position = traceDownForGround.HitPos + Vector(0, 0, 1000)
			if globalRainstormCount == 0 and globalThunderstormCount == 0 then
				local removeRainstormTimer = (225 * (GetCape() / 1000 / 4 + 0.5) * (GetConVar("xt2_s_lifetime_autospawn"):GetInt() / 5)) + math.random(100,150)
				local intforrainrainstorm = determineRainIntensity(RH)
				local sequences = {
					[0] = {"xt2_autospawn_rainstorm_light"},
					[1] = {"xt2_autospawn_rainstorm_light", "xt2_autospawn_rainstorm_medium", "xt2_autospawn_rainstorm_light"},
					[2] = {"xt2_autospawn_rainstorm_light", "xt2_autospawn_rainstorm_medium", "xt2_autospawn_rainstorm_heavy", "xt2_autospawn_rainstorm_medium", "xt2_autospawn_rainstorm_light"}
				}
	
				local sequence = sequences[intforrainrainstorm] or sequences[0]
				local phaseDuration = removeRainstormTimer / #sequence
	
				-- Table to hold rainstorm phase timers
				local rainstormPhaseTimers = {}
	
				for i, entityName in ipairs(sequence) do
					local timerName = "RainstormPhase_" .. i
					table.insert(storedTimerNamesXT2, tostring(timerName))
					rainstormPhaseTimers[i] = timerName -- Store timer name for removal later
					timer.Create(timerName, phaseDuration * (i - 1), 1, function()
						table.RemoveByValue(storedTimerNamesXT2, tostring(timerName))
						if IsValid(rainstormEnt) then
							rainstormEnt:Remove()
						end
						rainstormEnt = ents.Create(entityName)
						rainstormEnt:SetPos(position)
						rainstormEnt:Spawn()
					end)
				end
				table.insert(storedTimerNamesXT2, tostring(removeRainstormTimer))
				timer.Create("RainstormCleanup", removeRainstormTimer, 1, function()
					table.RemoveByValue(storedTimerNamesXT2, tostring(removeRainstormTimer))
					if IsValid(rainstormEnt) then
						rainstormEnt:Remove()
					end
					timer.Remove("checkdeathremovalrainstorm")
					-- Remove all rainstorm phase timers
					for _, timerName in ipairs(rainstormPhaseTimers) do
						if timer.Exists(timerName) then
							timer.Remove(timerName)
						end
					end
				end)
			end
		end
	end
	-- ON ADMIN CLEANUP
	function OnAdminCleanupAutospawn()
		timer.Simple(0.25, function()
			local timerNames = {
				"ResetSRHFlagTimer_",
				"ResetTempFlagTimer_",
				"ResetRHFlagTimer_",
				"ResetLapseFlagTimer_",
				"ResetCapeFlagTimer_"
			}
			
			for _, timerName in ipairs(timerNames) do
				if timer.Exists(timerName) then
					timer.Remove(timerName)
				end
			end
			spawnedTornadoesInWorld = 0
			globalRainstormCount = 0
			globalThunderstormCount = 0
	
			if saveOldSkyboxState ~= nil and GetConVar("xt2_customskyboxes"):GetInt() == 1 then
				RunConsoleCommand("sv_skyname", saveOldSkyboxState)
			elseif GetConVar("xt2_customskyboxes"):GetInt() == 1 then
				RunConsoleCommand("sv_skyname", "sky_day02_10")
			end
			ResetKeepTrackOfLiveTornadoesXT2()
		end)
	end
	
	-- SPAWN CHANCE FUNCTIONS FOR RETURNING EVERY X CHANCE OF SPAWNING FOR THE TIMERS AND FOR THE DOW / PLAYER TO SEE ---------------------------------------------------------------------------------------

    -- DISPLAY TIP FUNCTION, usage, DisplayTip("message")
    util.AddNetworkString("DisplayTip")
	function DisplayTip(message)
		if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
			if SERVER then
				for _, ply in ipairs(player.GetAll()) do
					SendTipToClient(ply, message)
				end
			else
				SendTipToClient(LocalPlayer(), message)
			end
		end
	end
    function SendTipToClient(ply, message)
        net.Start("DisplayTip")
        net.WriteString(message)
        net.Send(ply)
    end

	function RainSpawnChanceFunction(SRH, Cape, TemperatureMult, RH)
        -- Adjusting spawn chance based on CAPE -- Visit https://www.desmos.com/calculator/uyiwewethi to see how CAPE*SRH*RH is derived to get the storm risk chance.
        local capeFactor = 7/3*(Cape-250)^0.45*(Cape-250)^0.01+100 -- Cape Mult
        local rhFactor = -0.75*RH^0.5*RH^0.05+1.5 -- RH Mult
        local srhFactor = -0.035*SRH^0.5+1.5 -- SRH Mult
        local temperatureFactor = TemperatureMult -- Temperature Mult
        local finalChance = ( ( ( ( ( (capeFactor * rhFactor * srhFactor * temperatureFactor) * ( ( 1000 / Cape^1.1 ) + 0.5 ) ) ) / 4) * ((5.0 / LAPSE)^0.5) *1.4 ) ^ ((GetConVar("xt2_rainstormchance"):GetInt() / 5) ) ) / 0.7-- Take all factors into account (med) -- 9 original factor
		math.max(0, finalChance)
		if finalChance ~= 0 and finalChance <= 1 then
			finalChance = finalChance * (1/finalChance)^(1+finalChance)
		end
		if Cape <= 250 then
			return 0
		elseif Cape > 0 or SRH > 0 then
			return finalChance
		else
			return 0
		end
    end

    function StormSpawnChanceFunction(SRH, Cape, TemperatureMult, RH)
        -- Adjusting spawn chance based on CAPE -- Visit https://www.desmos.com/calculator/extqkzg77l to see how CAPE*SRH*RH is derived to get the storm risk chance.
        local capeFactor = -6/3*Cape^0.5*Cape^0.1+510 -- Cape Mult
        local rhFactor = -0.75*RH^0.5*RH^0.05+1.5 -- RH Mult
        local srhFactor = -0.035*SRH^0.5+1.5 -- SRH Mult
        local temperatureFactor = TemperatureMult -- Temperature Mult
        local finalChance = ( ( ( ( ( (capeFactor * rhFactor^4 * srhFactor * temperatureFactor) * ( ( 500 / Cape^0.85 ) + 0.4 ) ) ) / 12) * ((6.5 / LAPSE)^0.6) *1.1 ) ^ ((GetConVar("xt2_stormchance"):GetInt() / 5.0) ) ) / 0.95 -- Take all factors into account (low) -- 8 original factor
		math.max(0, finalChance)
		if finalChance ~= 0 and finalChance <= 1 then
			finalChance = finalChance * (1/finalChance)^(1+finalChance)
		end
		if Cape <= 250 then
			return 0
		elseif Cape > 0 or SRH > 0 then
			return finalChance
		else
			return 0
		end
    end

    function TornadoSpawnChanceFunction(SRH, Cape, TemperatureMult, RH)
        -- Adjusting tornado spawn chance based on CAPE -- Visit https://www.desmos.com/calculator/jetkhe4kqx to see how CAPE*SRH*RH is derived to get the tornado risk chance.
        local capeFactor = -6/3*Cape^0.5*Cape^0.18+1100 -- Cape Mult
        local rhFactor = -0.3*RH^0.5*RH^0.05+1.1 -- RH Mult
        local srhFactor = -0.04*SRH^0.5+1.5 -- SRH Mult
        local temperatureFactor = TemperatureMult -- Temperature Mult
		local capePower = 3.8  -- Highest influence
		local srhPower = 2.1   -- Second highest influence
		local lapsePower = 1.15 -- Third in influence
		local tempPower = 0.4  -- Fourth in influence
		local rhPower = 0.15    -- Least influence
	
		-- Calculate the final chance with modified exponents
		local finalChance = (((((capeFactor^capePower * srhFactor^srhPower * temperatureFactor^tempPower * rhFactor^rhPower) * (5.5 / LAPSE)^lapsePower) ^1.2) / 10000000000) / 21 ) ^ (GetConVar("xt2_tornadochance"):GetInt() / 5)
		math.max(0, finalChance)
		if Cape <= 250 then
			return 0
		end
		if Cape >= 5000 then
			finalChance = finalChance + ( (0.02^(GetConVar("xt2_tornadochance"):GetInt() / 5)) * (Cape - 5000) )
		end
		if finalChance ~= 0 and finalChance <= 2 then
			finalChance = (finalChance * (1/finalChance)^(1+finalChance)) + 2
		end
		if Cape > 0 or SRH > 0 then
			return finalChance
		else
			return 0
		end
    end

	function SharknadoSpawnChanceFunction(SRH, Cape, TemperatureMult, RH)
        -- Adjusting tornado spawn chance based on CAPE -- Visit https://www.desmos.com/calculator/jetkhe4kqx to see how CAPE*SRH*RH is derived to get the tornado risk chance.
        local capeFactor = -6/3*Cape^0.5*Cape^0.18+1100 -- Cape Mult
        local rhFactor = -0.3*RH^0.5*RH^0.05+1.1 -- RH Mult
        local srhFactor = -0.04*SRH^0.5+1.5 -- SRH Mult
        local temperatureFactor = TemperatureMult -- Temperature Mult
		local capePower = 3.8  -- Highest influence
		local srhPower = 2.1   -- Second highest influence
		local lapsePower = 1.15 -- Third in influence
		local tempPower = 0.4  -- Fourth in influence
		local rhPower = 0.15    -- Least influence
	
		-- Calculate the final chance with modified exponents
		local finalChance = (((((capeFactor^capePower * srhFactor^srhPower * temperatureFactor^tempPower * rhFactor^rhPower) * (5.5 / LAPSE)^lapsePower) ^1.2) / 10000000000) / 15 ) ^ (GetConVar("xt2_sharknadochance"):GetInt() / 5)
		math.max(0, finalChance)
		if Cape <= 250 then
			return 0
		end
		if Cape >= 5000 then
			finalChance = finalChance + ( (0.02^(GetConVar("xt2_sharknadochance"):GetInt() / 5)) * (Cape - 5000) )
		end
		if finalChance ~= 0 and finalChance <= 2 then
			finalChance = (finalChance * (1/finalChance)^(1+finalChance)) + 2
		end
		if Cape > 0 or SRH > 0 then
			return finalChance
		else
			return 0
		end
    end

	function F35SpawnChanceFunction(SRH, Cape, TemperatureMult, RH)
        -- Adjusting tornado spawn chance based on CAPE -- Visit https://www.desmos.com/calculator/jetkhe4kqx to see how CAPE*SRH*RH is derived to get the tornado risk chance.
        local capeFactor = -6/3*Cape^0.5*Cape^0.18+1100 -- Cape Mult
        local rhFactor = -0.3*RH^0.5*RH^0.05+1.1 -- RH Mult
        local srhFactor = -0.04*SRH^0.5+1.5 -- SRH Mult
        local temperatureFactor = TemperatureMult -- Temperature Mult
		local capePower = 3.8  -- Highest influence
		local srhPower = 2.1   -- Second highest influence
		local lapsePower = 1.15 -- Third in influence
		local tempPower = 0.4  -- Fourth in influence
		local rhPower = 0.15    -- Least influence
	
		-- Calculate the final chance with modified exponents
		local finalChance = (((((capeFactor^capePower * srhFactor^srhPower * temperatureFactor^tempPower * rhFactor^rhPower) * (5.5 / LAPSE)^lapsePower) ^1.2) / 10000000000) / 5 ) ^ (GetConVar("xt2_f35chance"):GetInt() / 5)
		math.max(0, finalChance)
		if Cape <= 250 then
			return 0
		end
		if Cape >= 5000 then
			finalChance = finalChance + ( (0.02^(GetConVar("xt2_f35chance"):GetInt() / 5)) * (Cape - 5000) )
		end
		if finalChance ~= 0 and finalChance <= 2 then
			finalChance = (finalChance * (1/finalChance)^(1+finalChance)) + 2
		end
		if Cape > 0 or SRH > 0 then
			return finalChance
		else
			return 0
		end
    end

	function F12SpawnChanceFunction(SRH, Cape, TemperatureMult, RH)
        -- Adjusting tornado spawn chance based on CAPE -- Visit https://www.desmos.com/calculator/jetkhe4kqx to see how CAPE*SRH*RH is derived to get the tornado risk chance.
        local capeFactor = -6/3*Cape^0.5*Cape^0.18+1100 -- Cape Mult
        local rhFactor = -0.3*RH^0.5*RH^0.05+1.1 -- RH Mult
        local srhFactor = -0.04*SRH^0.5+1.5 -- SRH Mult
        local temperatureFactor = TemperatureMult -- Temperature Mult
		local capePower = 3.8  -- Highest influence
		local srhPower = 2.1   -- Second highest influence
		local lapsePower = 1.15 -- Third in influence
		local tempPower = 0.4  -- Fourth in influence
		local rhPower = 0.15    -- Least influence
	
		-- Calculate the final chance with modified exponents
		local finalChance = (((((capeFactor^capePower * srhFactor^srhPower * temperatureFactor^tempPower * rhFactor^rhPower) * (5.5 / LAPSE)^lapsePower) ^1.2) / 10000000000) / 10 ) ^ (GetConVar("xt2_f12chance"):GetInt() / 5)
		math.max(0, finalChance)
		if Cape <= 250 then
			return 0
		end
		if Cape >= 5000 then
			finalChance = finalChance + ( (0.02^(GetConVar("xt2_f12chance"):GetInt() / 5)) * (Cape - 5000) )
		end
		if finalChance ~= 0 and finalChance <= 2 then
			finalChance = (finalChance * (1/finalChance)^(1+finalChance)) + 2
		end
		if Cape > 0 or SRH > 0 then
			return finalChance
		else
			return 0
		end
    end

	function GustnadoSpawnChanceFunction(SRH, Cape, TemperatureMult, RH)
        -- Adjusting tornado spawn chance based on CAPE -- Visit https://www.desmos.com/calculator/z9jyg1kysn to see how CAPE*SRH*RH is derived to get the gustnado risk chance.
        local capeFactor = -2/3*Cape^0.5*Cape^0.18+1300 -- Cape Mult
        local rhFactor = -0.3*RH^0.5*RH^0.05+1.1 -- RH Mult
        local srhFactor = -0.03*SRH^0.5+1.5 -- SRH Mult
        local temperatureFactor = TemperatureMult -- Temperature Mult
        local finalChance = ( ( ( (capeFactor * rhFactor * srhFactor * temperatureFactor) * ((5.5 / LAPSE)^0.5) ) ) / 1.8 ) ^ ((GetConVar("xt2_whirlwindchance"):GetInt() / 5) )
		math.max(0, finalChance)
		if finalChance ~= 0 and finalChance <= 10 then
			finalChance = (finalChance * (1/finalChance)^(1+finalChance)) + 10
		end
		if Cape <= 250 then
			return 0
		elseif Cape > 0 or SRH > 0 then
			return finalChance
		else
			return 0
		end
    end

	function DustDevilSpawnChanceFunction(SRH, TemperatureMult, RHvaldd)
        -- Adjusting tornado spawn chance based on CAPE -- Visit https://www.desmos.com/calculator/2rwhtekqmi to see how CAPE*SRH*RH is derived to get the dustdevil risk chance.
		local capeFactor = 8
        local rhFactor = 0.2*RHvaldd^0.5*RHvaldd^0.05+2.1 -- RH Mult
        local srhFactor = 0.04*SRH^0.5+2.5 -- SRH Mult
        local temperatureFactor = TemperatureMult -- Temperature Mult
        local finalChance = ( ( ( ((1.6*capeFactor) * (rhFactor^0.7) * (srhFactor^0.75) * ((5.5 / LAPSE)^0.5) * (temperatureFactor^1.25)) ) )^0.7 ) ^ ((GetConVar("xt2_whirlwindchance"):GetInt() / 5) )
		math.max(0, finalChance)
		if finalChance ~= 0 and finalChance <= 2 then
			finalChance = (finalChance * (1/finalChance)^(1+finalChance)) + 2
		end
		if Cape > 0 and SRH > 0 then
			return finalChance
		else
			return 0
		end
    end

	function FirewhirlSpawnChanceFunction(SRH, TemperatureMult, RHvaldd)
        -- Adjusting tornado spawn chance based on CAPE -- Visit https://www.desmos.com/calculator/2rwhtekqmi to see how CAPE*SRH*RH is derived to get the dustdevil risk chance.
		local capeFactor = 8
        local rhFactor = 0.2*RHvaldd^0.5*RHvaldd^0.05+2.1 -- RH Mult
        local srhFactor = 0.04*SRH^0.5+2.5 -- SRH Mult
        local temperatureFactor = TemperatureMult -- Temperature Mult
        local finalChance = ( ( ( ((1.5*capeFactor) * (rhFactor^1.25) * (srhFactor^0.7)) * ((5.5 / LAPSE)^0.5) ) )^0.7 + 2) * 50.0 * (temperatureFactor^1.25)  ^ ((GetConVar("xt2_whirlwindchance"):GetInt() / 5) )
		math.max(0, finalChance)
		if finalChance ~= 0 and finalChance <= 15 then
			finalChance = (finalChance * (1/finalChance)^(1+finalChance)) + 15
		end
		if Cape > 0 and SRH > 0 then
			return finalChance
		else
			return 0
		end
    end

	function calculateRiskLevel(SRHRISK, CapeRisk)
		-- Adjusting the formula to better match real-life assessments
		local TempMultiplier = TemperatureMultiplier(temperature) -- Assuming this function is defined elsewhere
		local riskValue = (0.25 * (SRHRISK^1.2 * 2) * (CapeRisk^2.0 * 1.6 / 1000) * ((1 / TempMultiplier) ^ 0.6) * (RH / 50 ^ 0.6) * ((LAPSE / 5.0)^0.9))
		riskValue = 0.019 * riskValue^0.7

		local function HandleCapeOverflow(SRHRISK, CapeRisk, riskValue)
			-- Addressing extreme Cape values
			if CapeRisk >= 10000 then
				if SRHRISK < 200 then
					riskValue = 2000
				elseif SRHRISK < 450 then
					riskValue = 3000
				else
					riskValue = 3800  -- Solid ENH, nearing MDT at this val
				end
			elseif CapeRisk >= 5000 and CapeRisk < 10000 then
				if SRHRISK < 200 then
					riskValue = riskValue * 0.75  -- Further reduced impact
				end
			end
			return riskValue
		end
		if Cape >= 5000 then
			riskValue = HandleCapeOverflow(SRHRISK, CapeRisk, riskValue)
		end


		-- Setting the risk levels based on the calculated riskValue
		if riskValue < 550 then
			isNoRisk = true
			return "NO RISK"
		elseif riskValue < 1300 then
			isNoRisk = false
			return "TSTM" -- General Thunderstorms
		elseif riskValue < 2500 then
			isNoRisk = false
			return "MRGL" -- Marginal Risk
		elseif riskValue < 3400 then
			isNoRisk = false
			return "SLGT" -- Slight Risk
		elseif riskValue < 4100 then
			isNoRisk = false
			return "ENH" -- Enhanced Risk
		elseif riskValue < 4850 then
			isNoRisk = false
			return "MDT" -- Moderate Risk
		else
			isNoRisk = false
			return "HIGH" -- High Risk
		end
	end
	
	
	local oldRiskType = "NO RISK"
	local currentRisk = "NO RISK"
	
	local function printWeatherUpdates(riskLevel)
		currentRisk = calculateRiskLevel(SRH, Cape) -- Calling risk once to avoid redundant call checks
		if oldRiskType ~= currentRisk and GetConVar("xt2_printrisklevel"):GetInt() == 1 then -- If risktype not equal to oldrisktype, then do the rest...

			local function StartDisplayToConsole()
				MsgC(Color(255, 255, 255), "____________________________________________________________________________________________________________________________________________\n\n")
				MsgC(Color(255, 255, 0), "DAY #" .. tostring(dayNumber) .. " OUTLOOK:\n\n")
				MsgC(Color(255, 255, 255), "[XT2] CURRENT RISK: ", Color(255, 255, 255), tostring(currentRisk), "\n\n")
				MsgC(Color(255, 255, 255), "[XT2] CURRENT TEMPERATURE: ", Color(255, 255, 255), tostring(roundforautospawn2(temperature)).." F", "\n")
				MsgC(Color(255, 255, 255), "[XT2] SRH: ", Color(255, 255, 255), tostring(roundforautospawn2(SRH)).." m^2/s^2", "\n")
				MsgC(Color(255, 255, 255), "[XT2] CAPE: ", Color(255, 255, 255), tostring(roundforautospawn2(Cape)).." J/kg", "\n")
				MsgC(Color(255, 255, 255), "[XT2] HUMIDITY: ", Color(255, 255, 255), tostring(roundforautospawn2(RH)).." %", "\n")
				MsgC(Color(255, 255, 255), "[XT2] LAPSE: ", Color(255, 255, 255), tostring(roundforautospawn2(LAPSE)).." C/Km", "\n\n")
			
				if GetConVar("xt2_autospawnweather"):GetInt() == 1 then
					MsgC(Color(255, 255, 255), "[XT2] Storm Chance Every 15 Seconds When Weathering : 1 in ", Color(255, 255, 255), tostring(roundforautospawn2(StormSpawnChance)), "\n")
					MsgC(Color(255, 255, 255), "[XT2] Rain Chance Every 15 Seconds When Weathering : 1 in ", Color(255, 255, 255), tostring(roundforautospawn2(RainSpawnChance)), "\n")
				else
					MsgC(Color(255, 255, 255), "[XT2] Storm Chance Every 15 Seconds When Weathering : 1 in DISABLED\n")
					MsgC(Color(255, 255, 255), "[XT2] Rain Chance Every 15 Seconds When Weathering : 1 in DISABLED\n")
				end
			
				if GetConVar("xt2_autospawntornadoes"):GetInt() == 1 then
					MsgC(Color(255, 255, 255), "[XT2] Tornado Chance Every 15 Seconds When Storming : 1 in ", Color(255, 255, 255), tostring(roundforautospawn2(TornadoEveryXChance)), "\n")
				else
					MsgC(Color(255, 255, 255), "[XT2] Tornado Chance Every 15 Seconds When Storming : 1 in DISABLED\n")
				end
				if GetConVar("xt2_autospawnsharknadoes"):GetInt() == 1 then
					MsgC(Color(255, 255, 255), "[XT2] Sharknado Chance Every 15 Seconds When Storming : 1 in ", Color(255, 255, 255), tostring(roundforautospawn2(SharknadoEveryXChance)), "\n")
				end
				if GetConVar("xt2_autospawnf12s"):GetInt() == 1 then
					MsgC(Color(255, 255, 255), "[XT2] F12 Chance Every 15 Seconds When Storming : 1 in ", Color(255, 255, 255), tostring(roundforautospawn2(F12EveryXChance)), "\n")
				end
				if GetConVar("xt2_autospawnf35s"):GetInt() == 1 then
					MsgC(Color(255, 255, 255), "[XT2] F35 Chance Every 15 Seconds When Storming : 1 in ", Color(255, 255, 255), tostring(roundforautospawn2(F35EveryXChance)), "\n")
				end
				if GetConVar("xt2_autospawnwhirlwinds"):GetInt() == 1 then
					MsgC(Color(255, 255, 255), "[XT2] Gustnado Chance Every 15 Seconds When Raining / Storming : 1 in ", Color(255, 255, 255), tostring(roundforautospawn2(GustnadoSpawnChance)), "\n")
					MsgC(Color(255, 255, 255), "[XT2] Dust Devil Chance Every 15 Seconds When Not Raining / Storming : 1 in ", Color(255, 255, 255), tostring(roundforautospawn2(DustDevilSpawnChance)), "\n")
					MsgC(Color(255, 255, 255), "[XT2] Firewhirl Chance Every 15 Seconds When Not Raining / Storming : 1 in ", Color(255, 255, 255), tostring(roundforautospawn2(FirewhirlSpawnChance)), "\n\n")
				else
					MsgC(Color(255, 255, 255), "[XT2] Gustnado Chance Every 15 Seconds When Raining / Storming : 1 in DISABLED\n")
					MsgC(Color(255, 255, 255), "[XT2] Dust Devil Chance Every 15 Seconds When Not Raining / Storming : 1 in DISABLED\n")
					MsgC(Color(255, 255, 255), "[XT2] Firewhirl Chance Every 15 Seconds When Not Raining / Storming : 1 in DISABLED\n\n")
				end
			
				if isHighCAPEEvent == true and GetConVar("xt2_printrisklevel"):GetInt() == 1 then
					MsgC(Color(255, 255, 0), "[XT2] CURRENTLY A HIGH CAPE EVENT\n\n")
					DisplayTip("[XT2] CURRENTLY A HIGH CAPE EVENT")
				end
			
				if isOutbreakEvent == true and GetConVar("xt2_printrisklevel"):GetInt() == 1 then
					MsgC(Color(255, 255, 0), "[XT2] CURRENTLY A TORNADO OUTBREAK EVENT (HATCHED)\n\n")
					DisplayTip("[XT2] CURRENTLY A TORNADO OUTBREAK EVENT (HATCHED)")
				end
			end
			local function TryChangingSkybox()
				if GetConVar("xt2_customskyboxes"):GetInt() == 1 then
					if RH <= 65 and isNoRisk == false then
						local SkyboxType = LowRHSkybox[math.random(1, #LowRHSkybox)]
						RunConsoleCommand("sv_skyname", tostring(SkyboxType))
						saveOldSkyboxState = SkyboxType
					elseif RH <= 100 and isNoRisk == false then
						local SkyboxType = HighRHSkybox[math.random(1, #HighRHSkybox)]
						RunConsoleCommand("sv_skyname", tostring(SkyboxType))
						saveOldSkyboxState = SkyboxType
					end
					if isNoRisk == true then
						RunConsoleCommand("sv_skyname", tostring(DefaultSkybox))
						saveOldSkyboxState = DefaultSkybox
					end
				end
			end

			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				local isTimerActive = false

				local function AttemptStartDisplayTipTimer()
					-- Only create a new timer when the previous one isn't active, this prevents displaytip spammage.
					if not isTimerActive then
						isTimerActive = true
						timer.Create("DisplayTipSendToTimer", 20, 1, function()
							if GetConVar("xt2_printrisklevel"):GetInt() == 1 and GetConVar("xt2_autospawnweather"):GetInt() == 1 then
								DisplayTip("[XT2] Current Risk: " .. currentRisk)
								StartDisplayToConsole()

								-- ADDED SKYBOX TYPE TO THIS SECTION AS WELL..
								TryChangingSkybox()
							end
							isTimerActive = false -- Reset the flag when the timer callback has been called
						end)
					end
				end
				AttemptStartDisplayTipTimer()
			end
		end
		oldRiskType = currentRisk -- Update the riskType variable with the new risk level...
	end

	-- GENERATE DAY -------------------------------------------------------------------------------------------------------------------

	-- Assuming variables like outbreakEndTime, highCAPEEventEndTime, update rates, and booleans for increasing parameters are declared outside this function

	timer.Create("updatedaynumber", dayLength, 0, function()
		dayNumber = dayNumber + 1
	end)

	local thermodynamicsUpdateRates = { -- Accessible outside of the function scope so I can call on it for modifying thermodynamics as a multiplier.
		capeupdateratemult = (math.random(5, 300) / 100) * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), -- Random between 0.5 and 3
		srhupdateratemult = (math.random(100, 300) / 100) * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), -- Random between 1 and 3
		rhupdateratemult = (math.random(25, 200) / 100) * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), -- Random between 0.25 and 2
		tempupdateratemult = (math.random(25, 200) / 100) * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), -- Random between 0.25 and 2
		lapseupdateratemult = (math.random(50, 400) / 100) * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), -- Random between 0.25 and 2
	}

	local function ChangeThermodynamicsUpdateRate() -- Function that controls the randomness factor for updating themodynamics.
		if isHighCAPEEvent then
			thermodynamicsUpdateRates = {
				capeupdateratemult = 5 * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)),
				srhupdateratemult = 2 * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), 
				rhupdateratemult = 4 * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), 
				tempupdateratemult = 4 * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)),
				lapseupdateratemult = 4 * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)) 
			}
		elseif isOutbreakEvent then
			thermodynamicsUpdateRates = {
				capeupdateratemult = 5 * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)),
				srhupdateratemult = 3 * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), 
				rhupdateratemult = 3 * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), 
				tempupdateratemult = 3 * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)),
				lapseupdateratemult = 3 * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)) 
			}
		else
			thermodynamicsUpdateRates = {
				capeupdateratemult = (math.random(100, 400) / 100) * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), -- Random between 0.5 and 3
				srhupdateratemult = (math.random(50, 200) / 100) * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), -- Random between 1 and 3
				rhupdateratemult = (math.random(100, 200) / 100) * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), -- Random between 0.25 and 2
				tempupdateratemult = (math.random(100, 200) / 100) * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)), -- Random between 0.25 and 2
				lapseupdateratemult = (math.random(100, 200) / 100) * (( ( GetConVar("xt2_updatethermosrate"):GetInt() ) / 5)) -- Random between 0.25 and 2
			}
		end
	end

	local function calculateTierWeights(noriskchanceval)
		-- Define the base weights for noriskchanceval at 1, 10, and 20
		local weightsAt1 = {1, 3, 5, 7, 8, 7, 5}
		local weightsAt10 = {8, 7, 6, 5, 4, 3, 2}
		local weightsAt20 = {1000, 80, 50, 40, 25, 15, 10}
	
		local tiers = {}
	
		-- Calculate the interpolation factor based on noriskchanceval to interpolate between my selective weight ranges for each noriskchanceval, value...
		for i = 1, #weightsAt10 do
			if noriskchanceval <= 10 then
				-- Interpolate between weights at 1 and 10
				local localFactor = (noriskchanceval - 1) / 9
				tiers[i] = weightsAt1[i] + (weightsAt10[i] - weightsAt1[i]) * localFactor
			else
				-- Interpolate between weights at 10 and 20
				local localFactor = (noriskchanceval - 10) / 10
				tiers[i] = weightsAt10[i] + (weightsAt20[i] - weightsAt10[i]) * localFactor
			end
		end
	
		-- Normalizing the weights so that their sum equals 1 so it can be passed into the following weight function.
		local totalWeight = 0
		for _, weight in ipairs(tiers) do
			totalWeight = totalWeight + weight
		end
		for i = 1, #tiers do
			tiers[i] = tiers[i] / totalWeight
		end
	
		return tiers
	end
	
	local function selectTierRandomly(weights)
		local sum = 0
		for i = 1, #weights do
			sum = sum + weights[i]
		end
		local rand = math.random()
		local accum = 0
		for i, weight in ipairs(weights) do
			accum = accum + weight / sum
			if rand <= accum then
				return i
			end
		end
		return #weights -- Return the last tier
	end

	function targetValueSelector()
		local noriskchanceval = GetConVar("xt2_noriskchance"):GetInt()
		local tierWeights = calculateTierWeights(noriskchanceval)
		local selectedTier = selectTierRandomly(tierWeights)
		
		local srhChance = math.random(1, 100)
		local capeChance = math.random(1, 100)
		
		local function generateValueWithinRange(min, max)
			return math.random(min, max)
		end
		
		local capeRanges = {
			{500, 1000}, {1000, 1750}, {1750, 2600},
			{2200, 3000}, {2800, 3750}, {3000, 4000}, {3500, 5000}
		}
		
		local srhRanges = {
			{50, 100}, {100, 175}, {125, 225},
			{150, 300}, {200, 325}, {250, 400}, {300, 450}
		}
	
		-- Initial target values based on event flags or random chance, unless overridden by admin commands
		if isHighCAPEEvent then
			if not IsAdminCommandSetCape then
				targetCape = math.random(7000, 10000)
			end
			if not IsAdminCommandSetSRH then
				targetSRH = math.random(50, 300)
			end
			if not IsAdminCommandSetRH then
				targetRH = math.random(55, 99)
			end
			if not IsAdminCommandSetTemp then
				targetTemperature = math.random(65, 92)
			end
			if not IsAdminCommandSetLapse then
				targetLapse = (math.random(50, 90)) / 10
			end
		elseif isOutbreakEvent then
			if not IsAdminCommandSetCape then
				targetCape = math.random(4500, 6500)
			end
			if not IsAdminCommandSetSRH then
				targetSRH = math.random(350, 450)
			end
			if not IsAdminCommandSetRH then
				targetRH = math.random(45, 90)
			end
			if not IsAdminCommandSetTemp then
				targetTemperature = math.random(60, 85)
			end
			if not IsAdminCommandSetLapse then
				targetLapse = (math.random(75, 95)) / 10
			end
		else
			if not IsAdminCommandSetSRH then
				targetSRH = (srhChance <= 20) and generateValueWithinRange(srhRanges[selectedTier][1] * 0.75, srhRanges[selectedTier][2]) or
							generateValueWithinRange(srhRanges[selectedTier][1], srhRanges[selectedTier][2])
			end
			if not IsAdminCommandSetCape then
				targetCape = (capeChance <= 20) and generateValueWithinRange(capeRanges[selectedTier][1] * 0.75, capeRanges[selectedTier][2]) or
							 generateValueWithinRange(capeRanges[selectedTier][1], capeRanges[selectedTier][2])
			end
			if not IsAdminCommandSetRH then
				local dryevent = math.random(1, 25)
				targetRH = (dryevent <= 1) and generateValueWithinRange(1, 35) or generateValueWithinRange(35, 90)
			end
			if not IsAdminCommandSetTemp then
				local coldevent = math.random(1, 30)
				targetTemperature = (coldevent <= 1) and generateValueWithinRange(1, 60) or generateValueWithinRange(60, 95)
			end
			if not IsAdminCommandSetLapse then
				local isothermicEvent = math.random(1, 20)
				targetLapse = (isothermicEvent <= 1) and (math.random(0, 49) / 10) or (math.random(50, 99) / 10)
			end
		end

		if IsAdminCommandSetCape == true then
			Cape = targetAdminCape
			targetCape = targetAdminCape
		end
		if IsAdminCommandSetLapse == true then
			LAPSE = targetAdminLapse
			targetLapse = targetAdminLapse
		end
		if IsAdminCommandSetRH == true then
			RH = targetAdminRH
			targetRH = targetAdminRH
		end
		if IsAdminCommandSetSRH == true then
			SRH = targetAdminSRH
			targetSRH = targetAdminSRH
		end
		if IsAdminCommandSetTemp == true then
			temperature = targetAdminTemp
			targetTemperature = targetAdminTemp
		end
	
		-- Prepare and return the target values list
		targetValuesListThermodynamics = {
			targetCape = targetCape,
			targetSRH = targetSRH,
			targetRH = targetRH,
			targetTemperature = targetTemperature,
			targetLapse = targetLapse
		}
		
		return targetValuesListThermodynamics
	end

	local function UpdateTarget() -- Controls rate of thermodynamics updating to their targets.
		local minvaluefornext = (dayLength / 2 * (math.random(11, 15) / 10) * (5 / GetConVar("xt2_updatethermosrate"):GetInt())) / 1.5
		local maxvaluefornext = (dayLength * (5 / GetConVar("xt2_updatethermosrate"):GetInt())) / 1.5
		local nextUpdateIn = math.random(minvaluefornext, maxvaluefornext)
		targetValueSelector()
		timer.Create("UpdateTargetTimer", nextUpdateIn, 1, UpdateTarget)  -- Use a constant name for the timer so it overrides the old timer.
	end

	local function UpdateThermodynamicSwitchRate() -- Controls rate of thermodynamics updating their "update speed"...
		local minvaluefornext = ((dayLength / 6 * (math.random(10, 15) / 10)) * (5 / GetConVar("xt2_updatethermosrate"):GetInt())) / 3
		local maxvaluefornext = (dayLength / 3 * (5 / GetConVar("xt2_updatethermosrate"):GetInt())) / 3
		local nextUpdateIn = math.random(minvaluefornext, maxvaluefornext)
		ChangeThermodynamicsUpdateRate()
		timer.Create("UpdateRatesTimer", nextUpdateIn, 1, UpdateThermodynamicSwitchRate)  -- Use a constant name for the timer so it overrides the old timer.
	end
	targetValueSelector()
	ChangeThermodynamicsUpdateRate()
	UpdateTarget()
	UpdateThermodynamicSwitchRate()

	local increasingSRH = true
	local increasingCAPE = true
	local increasingRH = true
	local increasingTemperature = true
	local increasingLapse = true

				-- COMMANDS FOR PLAYERS IN THE SERVER TO SET THE CAPE ETC,.

	hook.Add("PlayerSay", "SetCapeCommand", function(player, text)
		if GetConVar("xt2_enablext2chatcommands"):GetInt() == 1 and string.sub(text, 1, 12) == "!xt2 setcape" then
			if !player:IsSuperAdmin() then
				player:ChatPrint("[XT2] You Need To Be An Admin To Do That...")
				return ""
			end
			local amount, duration = string.match(text, "^!xt2 setcape (%d+%.?%d*) (%d+%.?%d*)$")
			amount = tonumber(amount)
			duration = tonumber(duration)
			if amount and duration and amount >= 500 and amount <= 10000 then
				targetAdminCape = amount
				Cape = amount
				IsAdminCommandSetCape = true
				UpdateTarget()
				local timerName = "ResetCapeFlagTimer_"
				timer.Create(timerName, duration, 1, function()
					IsAdminCommandSetCape = false
				end)
				player:ChatPrint("[XT2] Cape set to " .. amount .. " for " .. duration .. " seconds. The flag IsAdminCommandSetCape is now true and will be set to false in " .. duration .. " seconds.")
			else
				player:ChatPrint("[XT2] INVALID Command Usage. Please Use: !xt2 setcape [amount] [duration], Where Amount Is Between 500 And 10000.")
			end
			return ""
		end
	end)

	hook.Add("PlayerSay", "SetSRHCommand", function(player, text)
		if GetConVar("xt2_enablext2chatcommands"):GetInt() == 1 and string.sub(text, 1, 11) == "!xt2 setsrh" then
			if !player:IsSuperAdmin() then
				player:ChatPrint("[XT2] You Need To Be An Admin To Do That...")
				return ""
			end
			local amount, duration = string.match(text, "^!xt2 setsrh (%d+%.?%d*) (%d+%.?%d*)$")
			amount = tonumber(amount)
			duration = tonumber(duration)
			if amount and duration and amount >= 50 and amount <= 450 then
				targetAdminSRH = amount
				SRH = amount
				IsAdminCommandSetSRH = true
				UpdateTarget()
				local timerName = "ResetSRHFlagTimer_"
				timer.Create(timerName, duration, 1, function()
					IsAdminCommandSetSRH = false
				end)
				player:ChatPrint("[XT2] SRH set to " .. amount .. " for " .. duration .. " seconds. The flag IsAdminCommandSetSRH is now true and will be set to false in " .. duration .. " seconds.")
			else
				player:ChatPrint("[XT2] INVALID Command Usage. Please Use: !xt2 setsrh [amount] [duration], Where Amount Is Between 50 And 450.")
			end
			return ""
		end
	end)

	hook.Add("PlayerSay", "SetRHCommand", function(player, text)
		if GetConVar("xt2_enablext2chatcommands"):GetInt() == 1 and string.sub(text, 1, 10) == "!xt2 setrh" then
			if !player:IsSuperAdmin() then
				player:ChatPrint("[XT2] You Need To Be An Admin To Do That...")
				return ""
			end
			local amount, duration = string.match(text, "^!xt2 setrh (%d+%.?%d*) (%d+%.?%d*)$")
			amount = tonumber(amount)
			duration = tonumber(duration)
			if amount and duration and amount >= 1 and amount <= 99 then
				targetAdminRH = amount
				RH = amount
				IsAdminCommandSetRH = true
				UpdateTarget()
				local timerName = "ResetRHFlagTimer_"
				timer.Create(timerName, duration, 1, function()
					IsAdminCommandSetRH = false
				end)
				player:ChatPrint("[XT2] RH set to " .. amount .. " for " .. duration .. " seconds. The flag IsAdminCommandSetRH is now true and will be set to false in " .. duration .. " seconds.")
			else
				player:ChatPrint("[XT2] INVALID Command Usage. Please Use: !xt2 setrh [amount] [duration], Where Amount Is Between 1 And 99.")
			end
			return ""
		end
	end)

	hook.Add("PlayerSay", "SetTempCommand", function(player, text)
		if GetConVar("xt2_enablext2chatcommands"):GetInt() == 1 and string.sub(text, 1, 12) == "!xt2 settemp" then
			if !player:IsSuperAdmin() then
				player:ChatPrint("[XT2] You Need To Be An Admin To Do That...")
				return ""
			end
			local amount, duration = string.match(text, "^!xt2 settemp (%d+%.?%d*) (%d+%.?%d*)$")
			amount = tonumber(amount)
			duration = tonumber(duration)
			if amount and duration and amount >= 1 and amount <= 99 then
				targetAdminTemp = amount
				temperature = amount
				IsAdminCommandSetTemp = true
				UpdateTarget()
				local timerName = "ResetTempFlagTimer_"
				timer.Create(timerName, duration, 1, function()
					IsAdminCommandSetTemp = false
				end)
				player:ChatPrint("[XT2] Temperature set to " .. amount .. " for " .. duration .. " seconds. The flag IsAdminCommandSetTemp is now true and will be set to false in " .. duration .. " seconds.")
			else
				player:ChatPrint("[XT2] INVALID Command Usage. Please Use: !xt2 settemp [amount] [duration], Where Amount Is Between 1 And 99.")
			end
			return ""
		end
	end)

	hook.Add("PlayerSay", "SetLapseCommand", function(player, text)
		if GetConVar("xt2_enablext2chatcommands"):GetInt() == 1 and string.sub(text, 1, 13) == "!xt2 setlapse" then
			if !player:IsSuperAdmin() then
				player:ChatPrint("[XT2] You Need To Be An Admin To Do That...")
				return ""
			end
			local amount, duration = string.match(text, "^!xt2 setlapse (%d+%.?%d*) (%d+%.?%d*)$")
			amount = tonumber(amount)
			duration = tonumber(duration)
			if amount and duration and amount >= 0 and amount <= 10 then
				targetAdminLapse = amount
				LAPSE = amount
				IsAdminCommandSetLapse = true
				UpdateTarget()
				local timerName = "ResetLapseFlagTimer_"
				timer.Create(timerName, duration, 1, function()
					IsAdminCommandSetTemp = false
				end)
				player:ChatPrint("[XT2] Lapse set to " .. amount .. " for " .. duration .. " seconds. The flag IsAdminCommandSetLapse is now true and will be set to false in " .. duration .. " seconds.")
			else
				player:ChatPrint("[XT2] INVALID Command Usage. Please Use: !xt2 setlapse [amount] [duration], Where Amount Is Between 0.0 And 10.0.")
			end
			return ""
		end
	end)

	hook.Add("PlayerSay", "ResetAdminFlags", function(player, text)
		if GetConVar("xt2_enablext2chatcommands"):GetInt() == 1 and string.sub(text, 1, 21) == "!xt2 clearuserweather" then
			if !player:IsSuperAdmin() then
				player:ChatPrint("[XT2] You Need To Be An Admin To Do That...")
				return ""
			end
			local stringname = string.match(text, "^!xt2 clearuserweather")
			if stringname ~= nil or stringname ~= "" and stringname == "!xt2 clearuserweather" then
				IsAdminCommandSetCape = false
				IsAdminCommandSetLapse = false
				IsAdminCommandSetRH = false
				IsAdminCommandSetSRH= false
				IsAdminCommandSetTemp = false
				targetValueSelector()
				player:ChatPrint("[XT2] All XT2 Target Value Admin Flags Are Now Set To False")
			end
			return ""
		end
	end)

	hook.Add("PlayerSay", "RerollTargetvalue", function(player, text)
		if GetConVar("xt2_enablext2chatcommands"):GetInt() == 1 and string.sub(text, 1, 23) == "!xt2 rerolltargetvalues" then
			if !player:IsSuperAdmin() then
				player:ChatPrint("[XT2] You Need To Be An Admin To Do That...")
				return ""
			end
			local stringname = string.match(text, "^!xt2 rerolltargetvalues")
			if stringname ~= nil or stringname ~= "" and stringname == "!xt2 rerolltargetvalues" then
				targetValueSelector()
				if isHighCAPEEvent then
					isHighCAPEEvent = false
				end
				if isOutbreakEvent then
					isOutbreakEvent = false
				end
				player:ChatPrint("[XT2] Rerolled All Target Values, Thermodynamics Will Now Climb To Their New Targets... Better Luck This Time! - FORTYFOUR.")
			end
			return ""
		end
	end)

	local function ResetXT2Configs()
		for k, v in ipairs(defaultconvars) do
			if v.name and v.default then
				RunConsoleCommand(tostring(v.name), tostring(v.default))
			end
		end
	end

	hook.Add("PlayerSay", "ResetConvarsToDefaultXT2", function(player, text)
		if GetConVar("xt2_enablext2chatcommands"):GetInt() == 1 and string.sub(text, 1, 16) == "!xt2 resetconfig" then
			if !player:IsSuperAdmin() then
				player:ChatPrint("[XT2] You Need To Be An Admin To Do That...")
				return ""
			end
			local stringname = string.match(text, "^!xt2 resetconfig")
			if stringname ~= nil or stringname ~= "" and stringname == "!xt2 resetconfig" then
				ResetXT2Configs()
				player:ChatPrint("[XT2] Reset All Configurations To Default... This Will Disable Chat Commands As They Are Off By Default Unless Re-Enabled.")
			end
			return ""
		end
	end)

	local xt2Commands = { -- fml i should've done a list for this way sooner.
		{
			command = "!xt2 setcape",
			description = "Sets the cape to a specific value.",
			usage = "Usage: !xt2 setcape [amount] [duration]"
		},
		{
			command = "!xt2 setsrh",
			description = "Sets SRH to a specific value.",
			usage = "Usage: !xt2 setsrh [amount] [duration]"
		},
		{
			command = "!xt2 setrh",
			description = "Sets RH to a specific value.",
			usage = "Usage: !xt2 setrh [amount] [duration]"
		},
		{
			command = "!xt2 settemp",
			description = "Sets temperature to a specific value.",
			usage = "Usage: !xt2 settemp [amount] [duration]"
		},
		{
			command = "!xt2 setlapse",
			description = "Sets lapse to a specific value.",
			usage = "Usage: !xt2 setlapse [amount] [duration]"
		},
		{
			command = "!xt2 clearuserweather",
			description = "Clears All Admin Set Thermodynamic Flags.",
			usage = "Usage: !xt2 clearuserweather"
		},
		{
			command = "!xt2 rerolltargetvalues",
			description = "Rerolls The Target Value for Thermodynamics.",
			usage = "Usage: !xt2 rerolltargetvalues"
		},
		{
			command = "!xt2 resetconfig",
			description = "Resets All Configurations to Their Default... This Will Disable Chat Commands As They Are Off By Default Unless Re-Enabled.",
			usage = "Usage: !xt2 resetconfig"
		},
	}
	
	hook.Add("PlayerSay", "XT2HelpCommand", function(player, text)
		if string.lower(text) == "!xt2" or string.lower(text) == "!xt2 help" then
			if !player:IsSuperAdmin() then
				player:ChatPrint("[XT2] You Need To Be An Admin To Do That...")
				return ""
			end
			player:ChatPrint("\n[xTwisters 2] -- Available Commands: --\n")
			for _, cmd in ipairs(xt2Commands) do
				player:ChatPrint("------------------------------------------------")
				player:ChatPrint("Command: " .. cmd.command)
				player:ChatPrint("Description: " .. cmd.description)
				player:ChatPrint(cmd.usage .. "\n")
			end
			player:ChatPrint("------------------------------------------------")
			return ""
		end
	end)

	-- FINALLY ADJUST THE PARAMETER

	local function adjustParameter(value, rate, min, max, targetValue, increasing, dampeningFactor)
		-- Apply dampening factor to the rate
		local effectiveRate = rate * dampeningFactor
		
		if value < targetValue then
			increasing = true
		elseif value > targetValue then
			increasing = false
		end
		
		if increasing then
			value = math.min(value + effectiveRate, max)
		else
			value = math.max(value - effectiveRate, min)
		end
		
		return value, increasing
	end

	local dampeningFactorSRH, dampeningFactorCape, dampeningFactorTemperature, dampeningFactorRH, dampeningFactorLapse = 0.1, 0.1, 0.1, 0.1, 0.1

	local function updateDampeningFactors()
		dampeningFactorSRH = math.random(2, 20) / 100
		dampeningFactorCape = math.random(2, 20) / 100
		dampeningFactorTemperature = math.random(2, 20) / 100
		dampeningFactorRH = math.random(2, 20) / 100
		dampeningFactorLapse = math.random(2, 20) / 100
	end
	updateDampeningFactors()
	timer.Create("UpdateDampeningFactorsTimer", (dayLength / math.random(2, 3)), 0, updateDampeningFactors)

	function GenerateThermos() -- Generates the thermodynamics and is kind of an overall handler. Sends params in for adjusting, activates events and saves target values for what it's trying to climb to.
		local targetValueSRH = targetValuesListThermodynamics.targetSRH
		local targetValueCape = targetValuesListThermodynamics.targetCape
		local targetValueTemperature = targetValuesListThermodynamics.targetTemperature
		local targetValueRH = targetValuesListThermodynamics.targetRH
		local targetValueLapse = targetValuesListThermodynamics.targetLapse

		local currentTime = CurTime()
		-- Outbreak event start chance

		local defaultOutbreakChance = 0.00009
		local defaultHighCAPEChance = 0.000125
		local outbreakEventChance = GetConVar("xt2_outbreakeventchance"):GetInt()
		local highCAPEEventChance = GetConVar("xt2_highcapeeventchance"):GetInt()
		local adjustedOutbreakChance = defaultOutbreakChance / (5 / outbreakEventChance) ^ 3
		local adjustedHighCAPEChance = defaultHighCAPEChance / (5 / highCAPEEventChance) ^ 3

		if math.random() < adjustedOutbreakChance and not isOutbreakEvent and not isHighCAPEEvent then
			if GetConVar("xt2_enableevents"):GetInt() == 1 and GetConVar("xt2_autospawnweather"):GetInt() == 1 then
				isOutbreakEvent = true
				timer.Simple(math.random(1000, 2000)*(5 / GetConVar("xt2_updatethermosrate"):GetInt()), function()
					isOutbreakEvent = false
				end)
			end
		end

		-- High CAPE event start chance
		if math.random() < adjustedHighCAPEChance and not isOutbreakEvent and not isHighCAPEEvent then
			if GetConVar("xt2_enableevents"):GetInt() == 1 and GetConVar("xt2_autospawnweather"):GetInt() == 1 then
				isHighCAPEEvent = true
				timer.Simple(math.random(1000, 2000)*(5 / GetConVar("xt2_updatethermosrate"):GetInt()), function()
					isHighCAPEEvent = false
				end)
			end
		end

		if IsAdminCommandSetCape or IsAdminCommandSetLapse or IsAdminCommandSetRH or IsAdminCommandSetSRH or IsAdminCommandSetTemp then
			isHighCAPEEvent = false
			isOutbreakEvent = false
		end

		if not IsAdminCommandSetSRH then
			SRH, increasingSRH = adjustParameter(SRH, (updateRateSRH * thermodynamicsUpdateRates.srhupdateratemult), 50, 450, targetValueSRH, increasingSRH, dampeningFactorSRH)
		end
		if not IsAdminCommandSetCape then
			Cape, increasingCAPE = adjustParameter(Cape, (updateRateCAPE * thermodynamicsUpdateRates.capeupdateratemult), 500, 10000, targetValueCape, increasingCAPE, dampeningFactorCape)
		end
		if not IsAdminCommandSetTemp then
			temperature, increasingTemperature = adjustParameter(temperature, (updateRateTemperature * thermodynamicsUpdateRates.tempupdateratemult), 1, 99, targetValueTemperature, increasingTemperature, dampeningFactorTemperature)
		end
		if not IsAdminCommandSetRH then
			RH, increasingRH = adjustParameter(RH, (updateRateRH * thermodynamicsUpdateRates.rhupdateratemult), 1, 99, targetValueRH, increasingRH, dampeningFactorRH)
		end
		if not IsAdminCommandSetRH then
			LAPSE, increasingLapse = adjustParameter(LAPSE, (updateRateLAPSE * thermodynamicsUpdateRates.lapseupdateratemult), 1, 99, targetValueLapse, increasingLapse, dampeningFactorLapse)
		end

		-- Calculate and apply multiplication factors based on current conditions / thermodynamics
		local RHmult = (RH / 100) or 0
		local RHmultDustDevils = (100 / RH) + 0.25 or 0
		local temperaturemult = (TemperatureMultiplier(temperature)) or 0
		local temperaturemultdustdevils = (TemperatureMultiplierDustDevils(temperature)) or 0

		-- Update risk level and displaying their shenanigans
		local riskLevel = calculateRiskLevel(SRH, Cape)
		if GetConVar("xt2_autospawnweather"):GetInt() == 1 then
			if GetConVar("xt2_autospawntornadoes"):GetInt() == 1 and riskLevel ~= "NO RISK" then
				TornadoEveryXChance = TornadoSpawnChanceFunction(SRH, Cape, temperaturemult, RHmult) or 0
			else
				TornadoEveryXChance = 0
			end
			if GetConVar("xt2_autospawnsharknadoes"):GetInt() == 1 and riskLevel ~= "NO RISK" then
				SharknadoEveryXChance = SharknadoSpawnChanceFunction(SRH, Cape, temperaturemult, RHmult) or 0
			else
				SharknadoEveryXChance = 0
			end
			if GetConVar("xt2_autospawnf35s"):GetInt() == 1 and riskLevel ~= "NO RISK" then
				F35EveryXChance = F35SpawnChanceFunction(SRH, Cape, temperaturemult, RHmult) or 0
			else
				F35EveryXChance = 0
			end
			if GetConVar("xt2_autospawnf12s"):GetInt() == 1 and riskLevel ~= "NO RISK" then
				F12EveryXChance = F12SpawnChanceFunction(SRH, Cape, temperaturemult, RHmult) or 0
			else
				F12EveryXChance = 0
			end
			if GetConVar("xt2_autospawnwhirlwinds"):GetInt() == 1 then
				DustDevilSpawnChance = DustDevilSpawnChanceFunction(SRH, temperaturemultdustdevils, RHmultDustDevils) or 0
				FirewhirlSpawnChance = FirewhirlSpawnChanceFunction(SRH, temperaturemultdustdevils, RHmultDustDevils) or 0
				GustnadoSpawnChance = GustnadoSpawnChanceFunction(SRH, Cape, temperaturemult, RHmult) or 0
			else
				DustDevilSpawnChance = 0
				FirewhirlSpawnChance = 0
				GustnadoSpawnChance = 0
			end
			StormSpawnChance = StormSpawnChanceFunction(SRH, Cape, temperaturemult, RHmult) or 0
			RainSpawnChance = RainSpawnChanceFunction(SRH, Cape, temperaturemult, RHmult) or 0
			if riskLevel == "NO RISK" then
				StormSpawnChance = 0
			end
		else
			TornadoEveryXChance = 0
			StormSpawnChance = 0
			RainSpawnChance = 0
			DustDevilSpawnChance = 0
			FirewhirlSpawnChance = 0
			GustnadoSpawnChance = 0
			F12EveryXChance = 0
			F35EveryXChance = 0
			SharknadoEveryXChance = 0
		end

		printWeatherUpdates(riskLevel) -- Assuming this function prints the weather updates to the console or UI
		calculateRiskLevel(SRH, Cape)
	end

	timer.Create("UpdateThermodynamics", 3, 0, function()
		GenerateThermos()
	end)

	-- RETURN THUNDERSTORM VALUES BASED ON DYNAMIC THERMOS ---------------------------------------------------------------------------------------------------------------------------------------------

	function returnWindValRainstorm()
		local randomWindForRainstorm
		if SRH <= 50 then
			randomWindForRainstorm = math.random(1, 5)
		elseif SRH <= 100 then
			randomWindForRainstorm = math.random(5, 9)
		elseif SRH <= 200 then
			randomWindForRainstorm = math.random(9, 15)
		elseif SRH <= 300 then
			randomWindForRainstorm = math.random(15, 25)
		elseif SRH <= 400 then
			randomWindForRainstorm = math.random(25, 30)
		elseif SRH <= 450 then
			randomWindForRainstorm = math.random(28, 30)
		end
		return randomWindForRainstorm
	end

	function returnWindValThunderstorm()
		local randomWindForThunder
		if SRH <= 50 then
			randomWindForThunder = math.random(1, 5)
		elseif SRH <= 100 then
			randomWindForThunder = math.random(5, 9)
		elseif SRH <= 200 then
			randomWindForThunder = math.random(9, 15)
		elseif SRH <= 300 then
			randomWindForThunder = math.random(15, 25)
		elseif SRH <= 400 then
			randomWindForThunder = math.random(25, 30)
		elseif SRH <= 450 then
			randomWindForThunder = math.random(28, 30)
		end
		return randomWindForThunder
	end

	-- CONSTANTLY UPDATE WEATHER PROPERTIES ----------------------------------------------------------------------------------------------------------------------------------------------------------

	timer.Create("UpdateWeatherPropertiesAutospawn", 3, 0, function()
		returnWindValThunderstorm()
		returnWindValRainstorm()
	end)

	-- Simple Getters ----------------------------------------

	function GetCape()
		return (Cape) or 0
	end
	function GetSRH()
		return (SRH) or 0
	end
	function GetRH()
		return (RH) or 0
	end
	function GetTemperature()
		return (temperature) or 0
	end
	function GetHumidityForType()
		return (RH) or 0
	end

	-- Spawn Weights FOR WEATHER SELECTOR --------------------------------------------------------------------------------------------------------------------------------------------------------------

	local function weightThunderstorm()
		-- Adjust the base weight calculation to more strongly factor in CAPE and RH for thunderstorms
		-- Incorporating an SRH component to differentiate between storm and rain weights
		local baseWeight = (6 * (Cape / 1500) * (RH / 35) * 0.5) + 1
		local SRHModifier = SRH / 100 -- Adding an SRH modifier to distinguish between conditions
		local predictWeight = (baseWeight * 5.0 * (math.random(9, 11) / 20) * SRHModifier * (1.0 * (6.0 / LAPSE)^0.5)) + 1
		return predictWeight
	end
	
	local function weightRain()
		-- Adjusting the rain weight to be more sensitive to lower CAPE values and less influenced by RH
		-- Introducing a minor SRH component to keep the balance at lower SRH levels
		local baseWeight = (3 * (RH / 30) * ((2 * Cape^0.7) / 1000) * 4) + 1
		local SRHModifier = (1 + (SRH / 200) * 0.5) + 1 -- Less SRH influence compared to thunderstorms
		local predictWeight = (baseWeight * 2.25 * (math.random(9, 11) / 20) * SRHModifier * (1.0 * (6.0 / LAPSE)^0.5)) + 1
		return predictWeight
	end

	local function weightNone()
		local predictWeight = ( ( 20*(RH/35) * ((Cape^0.25)/3500) * 8 ) * (1.0 * (6.0 / LAPSE)^0.7) + 2.25 ) * 3.0 * (math.random(9, 11) / 6)
		return predictWeight 
	end

	-- WEATHER SELECTOR -- Basically, Days are split into 4 quarters on top of the storm every x chance and rain every x chance so if storm every x chance is 1, before it spawns it will check if the current days quarter is set to can spawn rain or thunder or none.

	function GetWeatherBalloonCurrentWeatherSelectorStatus() -- return for DOW Values
		returntotalweights = (
			"[XT2] WEIGHT CHANCE OF STORMING IF PRECIPITATION / WEATHER ATTEMPTS TO DEVELOP AS A THUNDERSTORM :" .. roundforautospawn2(weightThunderstorm()) .. "\n" ..
			"[XT2] WEIGHT CHANCE OF RAINING IF PRECIPITATION / WEATHER ATTEMPTS TO DEVELOP AS A RAINSTORM : " .. roundforautospawn2(weightRain()) .. "\n" ..
			"[XT2] WEIGHT CHANCE OF NONE TO FORM IF PRECIPITATION / WEATHER ATTEMPTS TO DEVELOP : " .. roundforautospawn2(weightNone())
		)
		return returntotalweights
	end

	local function GetCurrentWeatherSelector()
		local totalWeight = weightThunderstorm() + weightRain() + weightNone()
		local randomNum = math.random(1, totalWeight)
		if randomNum <= weightNone() then
			return "0"
		elseif randomNum <= weightNone() + weightRain() then
			return "1"
		else
			return "2"
		end
	end

	-- WEIGHTS FOR TORNADO --------------------------------------------------------------------------------------------------------------------------------------------------------------

    function GetSpeedMultForEnt() -- Speed mult based on SRH for the entity. (this gets called in the base as well as most Getters / Return functions)
        local SpeedMultForEnt = 0.4 + SRH/1400
        return SpeedMultForEnt
    end
	
	-- THIS SECTION IS DEDICATED TO THE ENTITIES THEMSELVES AND THEIR SPAWN CONDITIONS WHEN CALLED ON VIA THE TIMERS BELOW ----------------------------------------------------------------------------------

	spawnedTornadoesInWorld = 0

	timer.Create("CheckIfEntsAreValid", 3, 0, function()
		CheckIfEntIsValidXT2()
	end)

	function SpawnTornadoEnt()
		local players = player.GetAll()
		if #players == 0 then
			return -- Exit if no players are present
		end
	
		local randomPlayer = players[math.random(#players)]  -- Simplified random player selection
		local playerPos = randomPlayer:GetPos() -- Get the position of the randomly selected player
		local randomOffset = Vector(math.random(-15000, 15000), math.random(-15000, 15000), 0) -- Random offset near the player
		local initialSpawnPosition = playerPos + randomOffset -- Calculate initial position for the storm
	
		local highAltitudePosition = initialSpawnPosition + Vector(0, 0, 1000) -- Set a position high above the initial position
		local traceDownToDetermineAltitude = util.TraceLine({
			start = highAltitudePosition,
			endpos = highAltitudePosition - Vector(0, 0, 10000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if not traceDownToDetermineAltitude.Hit then
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print("[XT2] Tornado Attempted To Form But The Thermodynamics Weren't Right...")
			end
			return
		end
	
		local groundPosition = traceDownToDetermineAltitude.HitPos -- Get the position where the trace hit the ground
		local traceDownForGround = util.TraceLine({
			start = groundPosition,
			endpos = groundPosition - Vector(0, 0, 2000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if traceDownForGround.Hit then
			local spawnedTornado = ents.Create("xt2_autospawn_tornado")
			local spawnpostornado = traceDownForGround.HitPos + Vector(0, 0, 100)
			if spawnedTornadoesInWorld == 0 and spawnpostornado and IsValid(spawnedTornado) then
				if not IsValid(spawnedTornado) then return end
				spawnedTornado:SetPos(spawnpostornado) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
				spawnedTornado:Spawn()
				spawnedTornadoesInWorld = spawnedTornadoesInWorld + 1
			elseif spawnedTornadoesInWorld >= 1 and spawnpostornado and IsValid(spawnedTornado) then
				local rollDiceFor2ndTornado = math.random(1, 9)
				if rollDiceFor2ndTornado == 1 then
					if not IsValid(spawnedTornado) then return end
					spawnedTornado:SetPos(spawnpostornado) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
					spawnedTornado:Spawn()
					spawnedTornadoesInWorld = spawnedTornadoesInWorld + 1
				end
			else
				return
			end
		else
			--Suppress error message if the tornado cannot spawn
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print(tostring("[XT2] Tornado Attempted To Form But The Inflow Was Cut Off..."))
			end
		end
	end

	function SpawnSharknadoEnt()
		local players = player.GetAll()
		if #players == 0 then
			return -- Exit if no players are present
		end
	
		local randomPlayer = players[math.random(#players)]  -- Simplified random player selection
		local playerPos = randomPlayer:GetPos() -- Get the position of the randomly selected player
		local randomOffset = Vector(math.random(-15000, 15000), math.random(-15000, 15000), 0) -- Random offset near the player
		local initialSpawnPosition = playerPos + randomOffset -- Calculate initial position for the storm
	
		local highAltitudePosition = initialSpawnPosition + Vector(0, 0, 1000) -- Set a position high above the initial position
		local traceDownToDetermineAltitude = util.TraceLine({
			start = highAltitudePosition,
			endpos = highAltitudePosition - Vector(0, 0, 10000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if not traceDownToDetermineAltitude.Hit then
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print("[XT2] Tornado Attempted To Form But The Thermodynamics Weren't Right...")
			end
			return
		end
	
		local groundPosition = traceDownToDetermineAltitude.HitPos -- Get the position where the trace hit the ground
		local traceDownForGround = util.TraceLine({
			start = groundPosition,
			endpos = groundPosition - Vector(0, 0, 2000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if traceDownForGround.Hit then
			local spawnedTornado = ents.Create("xt2_tornadoes_sharknado")
			local spawnpostornado = traceDownForGround.HitPos + Vector(0, 0, 100)
			if spawnedTornadoesInWorld == 0 and spawnpostornado and IsValid(spawnedTornado) then
				if not IsValid(spawnedTornado) then return end
				spawnedTornado:SetPos(spawnpostornado) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
				spawnedTornado:Spawn()
				AddEntToValidCheckXT2(spawnedTornado)
				spawnedTornadoesInWorld = spawnedTornadoesInWorld + 1
			elseif spawnedTornadoesInWorld >= 1 and spawnpostornado and IsValid(spawnedTornado) then
				local rollDiceFor2ndTornado = math.random(1, 9)
				if rollDiceFor2ndTornado == 1 then
					if not IsValid(spawnedTornado) then return end
					spawnedTornado:SetPos(spawnpostornado) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
					spawnedTornado:Spawn()
					AddEntToValidCheckXT2(spawnedTornado)
					spawnedTornadoesInWorld = spawnedTornadoesInWorld + 1
				end
			else
				return
			end
		else
			--Suppress error message if the tornado cannot spawn
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print(tostring("[XT2] Tornado Attempted To Form But The Inflow Was Cut Off..."))
			end
		end
	end

	function SpawnF35LightningEnt()
		local players = player.GetAll()
		if #players == 0 then
			return -- Exit if no players are present
		end
	
		local randomPlayer = players[math.random(#players)]  -- Simplified random player selection
		local playerPos = randomPlayer:GetPos() -- Get the position of the randomly selected player
		local randomOffset = Vector(math.random(-15000, 15000), math.random(-15000, 15000), 0) -- Random offset near the player
		local initialSpawnPosition = playerPos + randomOffset -- Calculate initial position for the storm
	
		local highAltitudePosition = initialSpawnPosition + Vector(0, 0, 1000) -- Set a position high above the initial position
		local traceDownToDetermineAltitude = util.TraceLine({
			start = highAltitudePosition,
			endpos = highAltitudePosition - Vector(0, 0, 10000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if not traceDownToDetermineAltitude.Hit then
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print("[XT2] Tornado Attempted To Form But The Thermodynamics Weren't Right...")
			end
			return
		end
	
		local groundPosition = traceDownToDetermineAltitude.HitPos -- Get the position where the trace hit the ground
		local traceDownForGround = util.TraceLine({
			start = groundPosition,
			endpos = groundPosition - Vector(0, 0, 2000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if traceDownForGround.Hit then
			local spawnedTornado = ents.Create("xt2_tornadoes_f-35")
			local spawnpostornado = traceDownForGround.HitPos + Vector(0, 0, 100)
			if spawnedTornadoesInWorld == 0 and spawnpostornado and IsValid(spawnedTornado) then
				if not IsValid(spawnedTornado) then return end
				spawnedTornado:SetPos(spawnpostornado) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
				spawnedTornado:Spawn()
				AddEntToValidCheckXT2(spawnedTornado)
				spawnedTornadoesInWorld = spawnedTornadoesInWorld + 1
			elseif spawnedTornadoesInWorld >= 1 and spawnpostornado and IsValid(spawnedTornado) then
				local rollDiceFor2ndTornado = math.random(1, 9)
				if rollDiceFor2ndTornado == 1 then
					if not IsValid(spawnedTornado) then return end
					spawnedTornado:SetPos(spawnpostornado) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
					spawnedTornado:Spawn()
					AddEntToValidCheckXT2(spawnedTornado)
					spawnedTornadoesInWorld = spawnedTornadoesInWorld + 1
				end
			else
				return
			end
		else
			--Suppress error message if the tornado cannot spawn
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print(tostring("[XT2] Tornado Attempted To Form But The Inflow Was Cut Off..."))
			end
		end
	end

	function SpawnF12Ent()
		local players = player.GetAll()
		if #players == 0 then
			return -- Exit if no players are present
		end
	
		local randomPlayer = players[math.random(#players)]  -- Simplified random player selection
		local playerPos = randomPlayer:GetPos() -- Get the position of the randomly selected player
		local randomOffset = Vector(math.random(-15000, 15000), math.random(-15000, 15000), 0) -- Random offset near the player
		local initialSpawnPosition = playerPos + randomOffset -- Calculate initial position for the storm
	
		local highAltitudePosition = initialSpawnPosition + Vector(0, 0, 1000) -- Set a position high above the initial position
		local traceDownToDetermineAltitude = util.TraceLine({
			start = highAltitudePosition,
			endpos = highAltitudePosition - Vector(0, 0, 10000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if not traceDownToDetermineAltitude.Hit then
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print("[XT2] Tornado Attempted To Form But The Thermodynamics Weren't Right...")
			end
			return
		end
	
		local groundPosition = traceDownToDetermineAltitude.HitPos -- Get the position where the trace hit the ground
		local traceDownForGround = util.TraceLine({
			start = groundPosition,
			endpos = groundPosition - Vector(0, 0, 2000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if traceDownForGround.Hit then
			local spawnedTornado = ents.Create("xt2_tornadoes_f-12")
			local spawnpostornado = traceDownForGround.HitPos + Vector(0, 0, 100)
			if spawnedTornadoesInWorld == 0 and spawnpostornado and IsValid(spawnedTornado) then
				if not IsValid(spawnedTornado) then return end
				spawnedTornado:SetPos(spawnpostornado) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
				spawnedTornado:Spawn()
				AddEntToValidCheckXT2(spawnedTornado)
				spawnedTornadoesInWorld = spawnedTornadoesInWorld + 1
			elseif spawnedTornadoesInWorld >= 1 and spawnpostornado and IsValid(spawnedTornado) then
				local rollDiceFor2ndTornado = math.random(1, 9)
				if rollDiceFor2ndTornado == 1 then
					if not IsValid(spawnedTornado) then return end
					spawnedTornado:SetPos(spawnpostornado) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
					spawnedTornado:Spawn()
					AddEntToValidCheckXT2(spawnedTornado)
					spawnedTornadoesInWorld = spawnedTornadoesInWorld + 1
				end
			else
				return
			end
		else
			--Suppress error message if the tornado cannot spawn
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print(tostring("[XT2] Tornado Attempted To Form But The Inflow Was Cut Off..."))
			end
		end
	end

	function SpawnDustDevilEnt()
		local players = player.GetAll()
		if #players == 0 then
			return -- Exit if no players are present
		end
	
		local randomPlayer = players[math.random(#players)]  -- Simplified random player selection
		local playerPos = randomPlayer:GetPos() -- Get the position of the randomly selected player
		local randomOffset = Vector(math.random(-15000, 15000), math.random(-15000, 15000), 0) -- Random offset near the player
		local initialSpawnPosition = playerPos + randomOffset -- Calculate initial position for the storm
	
		local highAltitudePosition = initialSpawnPosition + Vector(0, 0, 1000) -- Set a position high above the initial position
		local traceDownToDetermineAltitude = util.TraceLine({
			start = highAltitudePosition,
			endpos = highAltitudePosition - Vector(0, 0, 10000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if not traceDownToDetermineAltitude.Hit then
			return
		end
	
		local groundPosition = traceDownToDetermineAltitude.HitPos -- Get the position where the trace hit the ground
		local traceDownForGround = util.TraceLine({
			start = groundPosition,
			endpos = groundPosition - Vector(0, 0, 2000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if traceDownForGround.Hit then
			local spawnedDustDevil = ents.Create("xt2_autospawn_whirlwinds_dustdevil")
			local spawnposDustDevil = traceDownForGround.HitPos + Vector(0, 0, 100)
			if spawnposDustDevil and IsValid(spawnedDustDevil) then
				if not IsValid(spawnedDustDevil) then return end
				spawnedDustDevil:SetPos(spawnposDustDevil) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
				spawnedDustDevil:Spawn()
			else
				return
			end
		else
			return -- Do nothing if tracedown coords are invalid :(
		end
	end

	function SpawnFirewhirlEnt()
		local players = player.GetAll()
		if #players == 0 then
			return -- Exit if no players are present
		end
	
		local randomPlayer = players[math.random(#players)]  -- Simplified random player selection
		local playerPos = randomPlayer:GetPos() -- Get the position of the randomly selected player
		local randomOffset = Vector(math.random(-15000, 15000), math.random(-15000, 15000), 0) -- Random offset near the player
		local initialSpawnPosition = playerPos + randomOffset -- Calculate initial position for the storm
	
		local highAltitudePosition = initialSpawnPosition + Vector(0, 0, 1000) -- Set a position high above the initial position
		local traceDownToDetermineAltitude = util.TraceLine({
			start = highAltitudePosition,
			endpos = highAltitudePosition - Vector(0, 0, 10000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if not traceDownToDetermineAltitude.Hit then
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print("[XT2] Thunderstorm Attempted To Form But The Thermodynamics Weren't Right...")
			end
			return
		end
	
		local groundPosition = traceDownToDetermineAltitude.HitPos -- Get the position where the trace hit the ground
		local traceDownForGround = util.TraceLine({
			start = groundPosition,
			endpos = groundPosition - Vector(0, 0, 2000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if traceDownForGround.Hit then
			local spawnedFirewhirl = ents.Create("xt2_autospawn_whirlwinds_firewhirl")
			local spawnposFirewhirl = traceDownForGround.HitPos + Vector(0, 0, 100)
			if spawnposFirewhirl and IsValid(spawnedFirewhirl) then
				if not IsValid(spawnedFirewhirl) then return end
				spawnedFirewhirl:SetPos(spawnposFirewhirl) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
				spawnedFirewhirl:Spawn()
			else
				return
			end
		else
			return -- Do not spawn ent if tracedown doesn't hit...
		end
	end

	function SpawnGustnadoEnt()
		local players = player.GetAll()
		if #players == 0 then
			return -- Exit if no players are present
		end
	
		local randomPlayer = players[math.random(#players)]  -- Simplified random player selection
		local playerPos = randomPlayer:GetPos() -- Get the position of the randomly selected player
		local randomOffset = Vector(math.random(-100, 100), math.random(-100, 100), 0) -- Random offset near the player
		local initialSpawnPosition = playerPos + randomOffset -- Calculate initial position for the storm
	
		local highAltitudePosition = initialSpawnPosition + Vector(0, 0, 1000) -- Set a position high above the initial position
		local traceDownToDetermineAltitude = util.TraceLine({
			start = highAltitudePosition,
			endpos = highAltitudePosition - Vector(0, 0, 10000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if not traceDownToDetermineAltitude.Hit then
			if GetConVar("xt2_printrisklevel"):GetInt() == 1 then
				print("[XT2] Thunderstorm Attempted To Form But The Thermodynamics Weren't Right...")
			end
			return
		end
	
		local groundPosition = traceDownToDetermineAltitude.HitPos -- Get the position where the trace hit the ground
		local traceDownForGround = util.TraceLine({
			start = groundPosition,
			endpos = groundPosition - Vector(0, 0, 2000),
			mask = MASK_SOLID_BRUSHONLY + MASK_WATER
		})
	
		if traceDownForGround.Hit then
			local spawnedGustnado = ents.Create("xt2_autospawn_whirlwinds_gustnado")
			local spawnposGustnado = traceDownForGround.HitPos + Vector(0, 0, 100)
			if spawnposGustnado and IsValid(spawnedGustnado) then
				if not IsValid(spawnedGustnado) then return end
				spawnedGustnado:SetPos(spawnposGustnado) --Add 100 units offset to Z-axis so tornadoes don't spazz and dissapear lol for no reason (WHY THE FUCK DOES IT DO THIS IT SHOULD BE UPDATING THE WORLDCOORDS)
				spawnedGustnado:Spawn()
			else
				return
			end
		else
			--Prevent ent creation if the tracedown doesn't hit anything ecksdee
			return
		end
	end

	local function UpdateWeatherTypeInSections()
		CurrentWeatherType = GetCurrentWeatherSelector()
	end

	local function UpdateAutoSpawnWeatheringTypeTimer()
		if timer.Exists("weatheringtypetimer") then
			timer.Remove("weatheringtypetimer")
		end
		local TimeValue = dayLength / 10 -- Split into 10 segments.
		timer.Create("weatheringtypetimer", TimeValue, 0, function()
			UpdateWeatherTypeInSections()
		end)
	end
	UpdateWeatherTypeInSections()
	UpdateAutoSpawnWeatheringTypeTimer()

	local function returnIsRainingXT2()
		if globalRainstormCount > 0 then
			return "YES"
		else
			return "NO"
		end
	end

	local function returnIsThunderingXT2()
		if globalThunderstormCount > 0 then
			return "YES"
		else
			return "NO"
		end
	end

	local function normalizeWeight(totalWeight, maxWeight)
		return totalWeight / maxWeight
	end
	
	local function STPandVTPChance(flag)
		local maxSTPWeight = 6.5
		local maxVTPWeight = 6.5
	
		local STPweighttotal = weightef0() + weightef1() + weightef2()
		local VTPweighttotal = weightef3() + weightef4() + weightef5()
	
		local STPratiovalue = normalizeWeight(STPweighttotal, maxSTPWeight)
		local VTPratiovalue = normalizeWeight(VTPweighttotal, maxVTPWeight)
	
		if flag == "STP" then
			STPratiovalue = STPratiovalue + ((VTPratiovalue) or 0)
			return roundforautospawn(STPratiovalue)
		elseif flag == "VTP" then
			return roundforautospawn(VTPratiovalue)
		else
			return "IMPROPER FLAG SET"
		end
	end

		-- ALL DOW RETURN VALUES -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	function ReturnThermosWeatherBalloon() -- Hey Rainbow, this is for u
		local returnthermos
		returnthermos = (
			"____________________________________________________________________________________________________________________________________________".. "\n" ..
			"DAY #"..tostring(dayNumber).." WEATHER BALLOON SOUNDING:".. "\n" .."\n" ..
			"[XT2] CURRENT RISK: "..calculateRiskLevel(SRH, Cape).. "\n" ..
			"[XT2] CURRENT TEMPERATURE: "..tostring(roundforautospawn2(temperature)).."F".. "\n" ..
			"[XT2] SRH: "..tostring(roundforautospawn2(SRH)).." m^2/s^2".. "\n" ..
			"[XT2] CAPE: "..tostring(roundforautospawn2(Cape)).." J/kg".. "\n" ..
			"[XT2] HUMIDITY: "..tostring(roundforautospawn2(RH)).."%".. "\n" ..
			"[XT2] LAPSE RATE: "..tostring(roundforautospawn2(LAPSE)).." C/km".. "\n" ..
			"[XT2] Storm Chance Every 15 Seconds When Weathering : 1 in "..tostring(roundforautospawn2(StormSpawnChance)).. "\n" ..
			"[XT2] Rain Chance Every 15 Seconds When Weathering : 1 in "..tostring(roundforautospawn2(RainSpawnChance)).. "\n" ..
			"[XT2] Tornado Chance Every 15 Seconds When Storming : 1 in "..tostring(roundforautospawn2(TornadoEveryXChance)).. "\n" ..
			"[XT2] Gustnado Chance Every 15 Seconds When Raining / Storming : 1 in "..tostring(roundforautospawn2(GustnadoSpawnChance)).. "\n" ..
			"[XT2] Dust Devil Chance Every 15 Seconds When Not Raining / Storming : 1 in "..tostring(roundforautospawn2(DustDevilSpawnChance)).. "\n" ..
			"[XT2] Firewhirl Chance Every 15 Seconds When Not Raining / Storming : 1 in "..tostring(roundforautospawn2(FirewhirlSpawnChance)).. "\n".."\n"..
			"[XT2] IS THUNDERING: "..tostring(returnIsThunderingXT2()).. "\n" ..
			"[XT2] IS RAINING: "..tostring(returnIsRainingXT2()).. "\n".."\n"..
			"[XT2] STP: "..tostring(STPandVTPChance("STP")).. "\n" ..
			"[XT2] VTP: "..tostring(STPandVTPChance("VTP")).. "\n"
		)
		if GetConVar("xt2_autospawnsharknadoes"):GetInt() == 1 or GetConVar("xt2_autospawnf12s"):GetInt() == 1 or GetConVar("xt2_autospawnf35s"):GetInt() == 1 then
			returnthermos = (
				"____________________________________________________________________________________________________________________________________________".. "\n" ..
				"DAY #"..tostring(dayNumber).." WEATHER BALLOON SOUNDING:".. "\n" .."\n" ..
				"[XT2] CURRENT RISK: "..calculateRiskLevel(SRH, Cape).. "\n" ..
				"[XT2] CURRENT TEMPERATURE: "..tostring(roundforautospawn2(temperature)).."F".. "\n" ..
				"[XT2] SRH: "..tostring(roundforautospawn2(SRH)).." m^2/s^2".. "\n" ..
				"[XT2] CAPE: "..tostring(roundforautospawn2(Cape)).." J/kg".. "\n" ..
				"[XT2] HUMIDITY: "..tostring(roundforautospawn2(RH)).."%".. "\n" ..
				"[XT2] LAPSE RATE: "..tostring(roundforautospawn2(LAPSE)).." C/km".. "\n" ..
				"[XT2] Storm Chance Every 15 Seconds When Weathering : 1 in "..tostring(roundforautospawn2(StormSpawnChance)).. "\n" ..
				"[XT2] Rain Chance Every 15 Seconds When Weathering : 1 in "..tostring(roundforautospawn2(RainSpawnChance)).. "\n" ..
				"[XT2] Tornado Chance Every 15 Seconds When Storming : 1 in "..tostring(roundforautospawn2(TornadoEveryXChance)).. "\n" ..
				"[XT2] Gustnado Chance Every 15 Seconds When Raining / Storming : 1 in "..tostring(roundforautospawn2(GustnadoSpawnChance)).. "\n" ..
				"[XT2] Dust Devil Chance Every 15 Seconds When Not Raining / Storming : 1 in "..tostring(roundforautospawn2(DustDevilSpawnChance)).. "\n" ..
				"[XT2] Firewhirl Chance Every 15 Seconds When Not Raining / Storming : 1 in "..tostring(roundforautospawn2(FirewhirlSpawnChance)).. "\n".."\n"..
				"[XT2] Sharknado Chance Every 15 Seconds When Storming : 1 in "..tostring(roundforautospawn2(SharknadoEveryXChance)).. "\n" ..
				"[XT2] F-12 Chance Every 15 Seconds When Storming : 1 in "..tostring(roundforautospawn2(F12EveryXChance)).. "\n" ..
				"[XT2] F-35 Lightning Chance Every 15 Seconds When Storming : 1 in "..tostring(roundforautospawn2(F35EveryXChance)).. "\n" .."\n"..
				"[XT2] IS THUNDERING: "..tostring(returnIsThunderingXT2()).. "\n" ..
				"[XT2] IS RAINING: "..tostring(returnIsRainingXT2()).. "\n".."\n"..
				"[XT2] STP: "..tostring(STPandVTPChance("STP")).. "\n" ..
				"[XT2] VTP: "..tostring(STPandVTPChance("VTP")).. "\n"
			)
		end
		return returnthermos
	end
	
	function ReturnWeightsWeatherBalloon()
		local totalWeight = {"WHEN WEATHER ATTEMPTS TO FORM IT RUNS THROUGH THESE WEIGHT STATISTICS... ","THUNDERSTORM WEIGHT CHANCE :"..tostring(weightThunderstorm()).." ", "RAINSTORM WEIGHT CHANCE :"..tostring(weightRain()).." ", "WEATHER FAILURE TO FORM WEIGHT CHANCE :"..tostring(weightNone()).." "}
		return totalWeight
	end
	
	function ReturnWeightEFsWeatherBalloon()
		local ef0weightDOW = roundforautospawn2(weightef0())
		local ef1weightDOW = roundforautospawn2(weightef1())
		local ef2weightDOW = roundforautospawn2(weightef2())
		local ef3weightDOW = roundforautospawn2(weightef3())
		local ef4weightDOW = roundforautospawn2(weightef4())
		local ef5weightDOW = roundforautospawn2(weightef5())
		if ef0weightDOW < 1 then
			ef0weightDOW = 0
		end
		if ef1weightDOW < 1 then
			ef1weightDOW = 0
		end
		if ef2weightDOW < 1 then
			ef2weightDOW = 0
		end
		if ef3weightDOW < 1 then
			ef3weightDOW = 0
		end
		if ef4weightDOW < 1 then
			ef4weightDOW = 0
		end
		if ef5weightDOW < 1 then
			ef5weightDOW = 0
		end
		local efweights = {"EF-0 WEIGHT: "..tostring(ef0weightDOW).." ","EF-1 WEIGHT: "..tostring(ef1weightDOW).." ","EF-2 WEIGHT: "..tostring(ef2weightDOW).." ","EF-3 WEIGHT: "..tostring(ef3weightDOW).." ","EF-4 WEIGHT: "..tostring(ef4weightDOW).." ","EF-5 WEIGHT: "..tostring(ef5weightDOW).." "}
		return efweights
	end

	-- TIMERS FOR TRY SPAWNING ENTITIES -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    timer.Create("TrySpawningWeather", 15, 0, function()
		local players = player.GetAll()
		
		local randomPlayer = players[math.random(1, #players)]
		globalThunderstormCount = math.max(0, globalThunderstormCount)
		globalRainstormCount = math.max(0, globalRainstormCount)
		
		if randomPlayer == nil then
			return
		end
		local CanSpawnWeather = GetConVar("xt2_autospawnweather"):GetInt()
        if CanSpawnWeather == 0 or GetConVar("xt2_autospawnweather"):GetInt() == 0 or globalRainstormCount ~= 0 or globalThunderstormCount ~= 0 then
            return
		else
			if globalThunderstormCount == 0 and globalRainstormCount == 0 and StormSpawnChance ~= 0 and math.random(1, StormSpawnChance) == 1 and GetConVar("xt2_autospawnweather"):GetInt() == 1 and calculateRiskLevel(SRH, Cape) ~= "NO RISK" and CurrentWeatherType == "2" then
				SpawnThunderstorm()
			end
			if globalRainstormCount == 0 and globalThunderstormCount == 0 and RainSpawnChance ~= 0 and math.random(1, RainSpawnChance) == 1 and GetConVar("xt2_autospawnweather"):GetInt() == 1 and CurrentWeatherType == "1" then
				SpawnRainstorm()
			end
		end
    end)
 
    timer.Create("TrySpawningTornado", 15, 0, function()
		local players = player.GetAll()
		
		local randomPlayer = players[math.random(1, #players)]

		globalThunderstormCount = math.max(0, globalThunderstormCount)
		globalRainstormCount = math.max(0, globalRainstormCount)
		
		if randomPlayer == nil then
			return
		end
        local CanSpawnTornadoes = GetConVar("xt2_autospawntornadoes"):GetInt()
        if CanSpawnTornadoes == 0 or TornadoEveryXChance == 0 or GetConVar("xt2_autospawntornadoes"):GetInt() == 0 or TornadoEveryXChance == "disabled" then
            return
        elseif TornadoEveryXChance > 0 and globalThunderstormCount > 0 and math.random(1, TornadoEveryXChance) == 1 and GetConVar("xt2_autospawntornadoes"):GetInt() == 1 and calculateRiskLevel(SRH, Cape) ~= "NO RISK" then
            SpawnTornadoEnt()
		else
			return
		end
    end)

	timer.Create("TrySpawningF-35", 15, 0, function()
		local players = player.GetAll()
		
		local randomPlayer = players[math.random(1, #players)]

		globalThunderstormCount = math.max(0, globalThunderstormCount)
		globalRainstormCount = math.max(0, globalRainstormCount)
		
		if randomPlayer == nil then
			return
		end
        local CanSpawnTornadoes = GetConVar("xt2_autospawnf35s"):GetInt()
        if CanSpawnTornadoes == 0 or F35EveryXChance == 0 or GetConVar("xt2_autospawnf35s"):GetInt() == 0 or F35EveryXChance == "disabled" then
            return
        elseif F35EveryXChance > 0 and globalThunderstormCount > 0 and math.random(1, F35EveryXChance) == 1 and GetConVar("xt2_autospawnf35s"):GetInt() == 1 and calculateRiskLevel(SRH, Cape) ~= "NO RISK" then
            SpawnF35LightningEnt()
		else
			return
		end
    end)

	timer.Create("TrySpawningF-12", 15, 0, function()
		local players = player.GetAll()
		
		local randomPlayer = players[math.random(1, #players)]

		globalThunderstormCount = math.max(0, globalThunderstormCount)
		globalRainstormCount = math.max(0, globalRainstormCount)
		
		if randomPlayer == nil then
			return
		end
        local CanSpawnTornadoes = GetConVar("xt2_autospawnf12s"):GetInt()
        if CanSpawnTornadoes == 0 or F12EveryXChance == 0 or GetConVar("xt2_autospawnf12s"):GetInt() == 0 or F12EveryXChance == "disabled" then
            return
        elseif F12EveryXChance > 0 and globalThunderstormCount > 0 and math.random(1, F12EveryXChance) == 1 and GetConVar("xt2_autospawnf12s"):GetInt() == 1 and calculateRiskLevel(SRH, Cape) ~= "NO RISK" then
            SpawnF12Ent()
		else
			return
		end
    end)

	timer.Create("TrySpawningSharknado", 15, 0, function()
		local players = player.GetAll()
		
		local randomPlayer = players[math.random(1, #players)]

		globalThunderstormCount = math.max(0, globalThunderstormCount)
		globalRainstormCount = math.max(0, globalRainstormCount)
		
		if randomPlayer == nil then
			return
		end
        local CanSpawnTornadoes = GetConVar("xt2_autospawnsharknadoes"):GetInt()
        if CanSpawnTornadoes == 0 or SharknadoEveryXChance == 0 or GetConVar("xt2_autospawnsharknadoes"):GetInt() == 0 or SharknadoEveryXChance == "disabled" then
            return
        elseif SharknadoEveryXChance > 0 and globalThunderstormCount > 0 and math.random(1, SharknadoEveryXChance) == 1 and GetConVar("xt2_autospawnsharknadoes"):GetInt() == 1 and calculateRiskLevel(SRH, Cape) ~= "NO RISK" then
            SpawnSharknadoEnt()
		else
			return
		end
    end)

	timer.Create("TrySpawningWhirlwinds", 15, 0, function()
		local players = player.GetAll()
		
		local randomPlayer = players[math.random(1, #players)]

		globalThunderstormCount = math.max(0, globalThunderstormCount)
		globalRainstormCount = math.max(0, globalRainstormCount)
		
		if randomPlayer == nil then
			return
		end
		local CanSpawnWhirlwinds = GetConVar("xt2_autospawnwhirlwinds"):GetInt()
		if CanSpawnWhirlwinds == 0 or DustDevilSpawnChance == 0 and GustnadoSpawnChance == 0 or DustDevilSpawnChance == "DISABLED" then
			return
		elseif globalRainstormCount == 0 and globalThunderstormCount == 0 and DustDevilSpawnChance > 0 and math.random(1, DustDevilSpawnChance) == 1 and GetConVar("xt2_autospawnwhirlwinds"):GetInt() == 1 then -- Flags in here to basically prevent dust devils from spawning when raining cuz yk the ground would be moist...
			SpawnDustDevilEnt()
		elseif GustnadoSpawnChance > 0 and math.random(1, GustnadoSpawnChance) == 1 and GetConVar("xt2_autospawnwhirlwinds"):GetInt() == 1 and GustnadoSpawnChance > 0 and globalRainstormCount > 0 or GustnadoSpawnChance > 0 and math.random(1, GustnadoSpawnChance) == 1 and GetConVar("xt2_autospawnwhirlwinds"):GetInt() == 1 and GustnadoSpawnChance > 0 and globalThunderstormCount > 0 then
			SpawnGustnadoEnt()
		elseif FirewhirlSpawnChance > 0 and math.random (1, FirewhirlSpawnChance) == 1 and GetConVar("xt2_autospawnwhirlwinds"):GetInt() == 1 and globalRainstormCount == 0 and globalThunderstormCount == 0 then
			SpawnFirewhirlEnt()
		else
			return
		end
	end)
end