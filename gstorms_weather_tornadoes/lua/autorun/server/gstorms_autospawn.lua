if CLIENT then return end

include("gstorms_funcs/gstorms_shared.lua")
include("autorun/gstorms_groundposition.lua")

local SEASON = {currentSeason = "spring", currentClimate = "convective"}
local CURRENTRISKS = {sandstorm = 0, dustdevil = 0, rainstorm = 0, thunderstorm = 0, landspout = 0, waterspout = 0, derecho = 0, tornado = 0, hurricane = 0}
local HURRICANENAMES = {"Adrian", "Bianca", "Carlos", "Danielle", "Elliot", "Fernanda", "Gordon", "Helena", "Isaac", "Josephine", "Kennedy", "Lucia", "Mateo", "Nadine", "Oscar", "Paula", "Quentin", "Renata", "Sebastian", "Teresa", "Ulises", "Vanessa", "Ximena", "Yvette", "Zachary"}
local CURRENTPARAMETERS = {
    CAPE = math.random(100, 250),
    SRH = math.random(10, 50),
    LAPSE = math.Rand(4, 6),
    RH = math.random(35, 50),
    SHEAR = math.random(2, 10),
    TEMPERATURE = math.random(18, 30),
    WINDDIRECTION = GSGetNormVecNoZ(1),
    WIND = math.random(2, 8),
    SST = math.random(7, 20),
    VORT = math.random(2, 8),
    PRESSURE = math.random(1013, 1018),
    LATITUDE = math.random(30, 50)
}

local simulationControls = {
	seasons = {
		spring = {
			enabledCvar = "gstorms_autospawn_spring",
			riskCompression = 1,
			windDirection = GSGetNormVecNoZ(1),
			climateWeights = {dry = 1.35, convective = 1.85, tropical = 0.28, cold = 0.20},
		},
		summer = {
			enabledCvar = "gstorms_autospawn_summer",
			riskCompression = 1,
			windDirection = GSGetNormVecNoZ(1),
			climateWeights = {dry = 0.95, convective = 1.00, tropical = 1.55, cold = 0.00},
		},
		fall = {
			enabledCvar = "gstorms_autospawn_fall",
			riskCompression = 0.85,
			windDirection = GSGetNormVecNoZ(1),
			climateWeights = {dry = 1.15, convective = 0.65, tropical = 0.35, cold = 1.35},
		},
		winter = {
			enabledCvar = "gstorms_autospawn_winter",
			riskCompression = 0.7,
			windDirection = GSGetNormVecNoZ(1),
			climateWeights = {dry = 1.10, convective = 0.40, tropical = 0.00, cold = 2.55},
		}
	},

	entities = {
		dustdevil = {
			enabledCvar = "gstorms_autospawn_dustdevil",
			frequencyCvar = "gstorms_autospawn_frequency_dustdevil",
			baseFrequency = 1,
			minForThreat = 0.16,
			minForSevere = 0.55,
			severeIndexInfluence = 0,
			requiredRisks = {},
			noSpawnIfActive = {"thunderstorm", "rainstorm", "hurricane", "landspout", "waterspout", "tornado", "derecho"},
			seasonFrequencyMult = {winter = 0.00, spring = 1.05, summer = 1.10, fall = 0.75},
			climateMult = {dry = 2.60, convective = 0.42, tropical = 0.04, cold = 0.02},
			influences = {
				TEMPERATURE = {start = 16, peak = 33, weight = 3.00},
				RH = {peak = {0, 32}, decline = 58, weight = 3.00},
				LAPSE = {start = 6.2, peak = 9.2, weight = 2.25},
				WIND = {peak = {1, 10}, decline = 22, weight = 1.65},
				CAPE = {peak = {0, 650}, decline = 2750, weight = 0.55},
				PRESSURE = {peak = {995, 1038}, decline = 970, weight = 0.30},
			},
			entityName = "gstorms_weather_dust_devil_dynamic",
			spawnChanceMul = 3,
			minSpacing = 0.05,
			maxInWorld = 3,
		},
	
		sandstorm = {
			enabledCvar = "gstorms_autospawn_sandstorm",
			frequencyCvar = "gstorms_autospawn_frequency_sandstorm",
			baseFrequency = 1,
			minForThreat = 0.22,
			minForSevere = 0.60,
			severeIndexInfluence = 0,
			requiredRisks = {},
			noSpawnIfActive = {"thunderstorm", "rainstorm", "hurricane", "landspout", "waterspout", "tornado", "derecho"},
			seasonFrequencyMult = {winter = 0.00, spring = 1.00, summer = 1.30, fall = 0.80},
			climateMult = {dry = 2, convective = 0.28, tropical = 0.02, cold = 0.12},
			influences = {
				TEMPERATURE = {start = 8, peak = 35, weight = 1.35},
				RH = {peak = {0, 28}, decline = 58, weight = 3.25},
				LAPSE = {start = 5.5, peak = 8.8, weight = 1.35},
				WIND = {start = 11, peak = 30, weight = 3.75},
				PRESSURE = {peak = {940, 1010}, decline = 1040, weight = 1.15},
			},
			entityName = "gstorms_weather_sandstorm",
			spawnChanceMul = 1.25,
			minSpacing = 0.25,
			maxInWorld = 1,
		},
	
		tornado = {
			enabledCvar = "gstorms_autospawn_tornado",
			frequencyCvar = "gstorms_autospawn_frequency_tornado",
			baseFrequency = 1,
			minForThreat = 0.2,
			minForSevere = 0.6,
			severeIndexInfluence = 1,
			requiredRisks = {"thunderstorm"},
			noSpawnIfActive = {"hurricane", "derecho"},
			seasonFrequencyMult = {winter = 0.00, spring = 1.25, summer = 1.00, fall = 0.80},
			climateMult = {dry = 0.24, convective = 1.75, tropical = 0.70, cold = 0.55},
			influences = {
				CAPE = {start = 500, peak = {2000, 3500}, decline = 6500, weight = 2.20},
				SRH = {start = 75, peak = {200, 425}, weight = 3.50},
				SHEAR = {start = 15, peak = {28, 45}, decline = 60, weight = 3.35},
				RH = {start = 45, peak = 72, weight = 0.90},
				LAPSE = {start = 4.8, peak = 7.2, weight = 0.80},
				TEMPERATURE = {start = 8, peak = 24, decline = 37, weight = 0.55},
				WIND = {start = 4, peak = 18, decline = 42, weight = 0.85},
				VORT = {start = 1.5, peak = 9, weight = 2.25},
				PRESSURE = {peak = {930, 1012}, decline = 1038, weight = 0.45},
				LCL = {peak = {0, 1100}, decline = 2300, weight = 1.95}
			},
			entityName = "gstorms_weather_efu_dynamic",
			spawnChanceMul = 1.25,
			minSpacing = 0.25,
			maxInWorld = 1,
		},
	
		hurricane = {
			enabledCvar = "gstorms_autospawn_hurricane",
			frequencyCvar = "gstorms_autospawn_frequency_hurricane",
			baseFrequency = 1,
			minForThreat = 0.3,
			minForSevere = 0.7,
			severeIndexInfluence = 0.8,
			requiredRisks = {"thunderstorm", "rainstorm"},
			requirementsNeed = "all",
			noSpawnIfActive = {"tornado", "derecho", "hurricane"},
			seasonFrequencyMult = {winter = 0.00, spring = 0.20, summer = 1.05, fall = 0.95},
			climateMult = {dry = 0.00, convective = 0.12, tropical = 1.55, cold = 0.00},
			influences = {
				SST = {start = 25.5, peak = 29.5, weight = 3.70},
				SHEAR = {peak = {0, 14}, decline = 30, weight = 3.25},
				RH = {start = 58, peak = 84, weight = 2.65},
				CAPE = {start = 100, peak = 1200, decline = 6000, weight = 0.90},
				VORT = {start = 3, peak = 10, weight = 2.85},
				PRESSURE = {peak = {880, 995}, decline = 1020, weight = 3.50},
				LATITUDE = {start = 5, peak = {10, 30}, decline = 52, weight = 2.15},
				TEMPERATURE = {start = 23, peak = 30, weight = 1.00},
				WIND = {peak = {0, 12}, decline = 32, weight = 0.70},
			},
			entityName = "gstorms_weather_hurricane_dynamic",
			spawnChanceMul = 1.25,
			minSpacing = 0.9,
			maxInWorld = 1,
		},
	
		landspout = {
			enabledCvar = "gstorms_autospawn_landspout",
			frequencyCvar = "gstorms_autospawn_frequency_landspout",
			baseFrequency = 1,
			minForThreat = 0.2,
			minForSevere = 0.6,
			severeIndexInfluence = 0.22,
			requiredRisks = {"rainstorm", "thunderstorm"},
			noSpawnIfActive = {"derecho", "hurricane", "tornado", "thunderstorm", "rainstorm", "waterspout"},
			seasonFrequencyMult = {winter = 0.00, spring = 0.85, summer = 1.00, fall = 0.40},
			climateMult = {dry = 0.95, convective = 1.35, tropical = 0.25, cold = 0.06},
			influences = {
				CAPE = {start = 500, peak = {1000, 1500}, decline = 2500, weight = 3.10},
				SRH = {peak = {25, 125}, decline = 200, weight = 2.10},
				SHEAR = {peak = {0, 18}, decline = 35, weight = 2.75},
				LAPSE = {start = 6.8, peak = 8.8, weight = 3.00},
				RH = {start = 35, peak = {50, 72}, decline = 92, weight = 1.15},
				TEMPERATURE = {start = 14, peak = 30, weight = 1.25},
				VORT = {start = 2.5, peak = 10, weight = 3.00},
				WIND = {peak = {1, 12}, decline = 24, weight = 1.00},
				LCL = {peak = {0, 1600}, decline = 2400, weight = 1.55},
			},
			entityName = "gstorms_weather_spout_dynamic",
			spawnChanceMul = 1.25,
			minSpacing = 0.25,
			maxInWorld = 1,
		},
	
		waterspout = {
			enabledCvar = "gstorms_autospawn_waterspout",
			frequencyCvar = "gstorms_autospawn_frequency_waterspout",
			baseFrequency = 1,
			minForThreat = 0.2,
			minForSevere = 0.6,
			severeIndexInfluence = 0.18,
			requiredRisks = {"rainstorm", "thunderstorm"},
			noSpawnIfActive = {"derecho", "tornado", "hurricane", "thunderstorm", "rainstorm", "landspout"},
			seasonFrequencyMult = {winter = 0.00, spring = 0.55, summer = 0.85, fall = 1.00},
			climateMult = {dry = 0.06, convective = 0.85, tropical = 1.85, cold = 0.18},
			influences = {
				SST = {start = 17, peak = {24, 30}, decline = 34, weight = 3.20},
				RH = {start = 60, peak = 90, weight = 2.90},
				CAPE = {start = 50, peak = {300, 1400}, decline = 2500, weight = 1.65},
				SRH = {peak = {0, 125}, decline = 225, weight = 1.50},
				LAPSE = {start = 4.8, peak = 7.5, weight = 1.45},
				SHEAR = {peak = {0, 14}, decline = 28, weight = 2.85},
				WIND = {peak = {0, 12}, decline = 24, weight = 2.35},
				VORT = {start = 1.5, peak = 9, weight = 2.50},
				LATITUDE = {start = 5, peak = {15, 45}, decline = 62, weight = 0.75},
				LCL = {peak = {0, 1200}, decline = 2200, weight = 1.55},
			},
			entityName = "gstorms_weather_spout_dynamic",
			spawnChanceMul = 1.25,
			minSpacing = 0.25,
			maxInWorld = 1,
		},
	
		rainstorm = {
			enabledCvar = "gstorms_autospawn_rainstorm",
			frequencyCvar = "gstorms_autospawn_frequency_rainstorm",
			baseFrequency = 1,
			minForThreat = 0.16,
			minForSevere = 0.55,
			severeIndexInfluence = 0,
			requiredRisks = {},
			noSpawnIfActive = {"hurricane", "tornado", "derecho", "thunderstorm"},
			seasonFrequencyMult = {winter = 0.9, spring = 1.00, summer = 1.10, fall = 1.00},
			climateMult = {dry = 0.28, convective = 1.00, tropical = 1.65, cold = 1.05},
			influences = {
				RH = {start = 62, peak = 94, weight = 3.45},
				CAPE = {peak = {0, 1100}, decline = 4800, weight = 0.75},
				LAPSE = {start = 3.8, peak = 6.4, decline = 8.8, weight = 0.70},
				SHEAR = {peak = {0, 22}, decline = 48, weight = 0.55},
				TEMPERATURE = {start = -30, peak = {-8, 24}, decline = 39, weight = 0.85},
				WIND = {start = 1, peak = 14, decline = 34, weight = 0.95},
				PRESSURE = {peak = {950, 1010}, decline = 1042, weight = 1.45},
				SST = {start = 5, peak = 25, weight = 0.45},
			},
			entityName = "gstorms_weather_rainstorm_dynamic",
			spawnChanceMul = 1.25,
			minSpacing = 0.5,
			maxInWorld = 1,
		},
	
		thunderstorm = {
			enabledCvar = "gstorms_autospawn_thunderstorm",
			frequencyCvar = "gstorms_autospawn_frequency_thunderstorm",
			baseFrequency = 1,
			minForThreat = 0.25,
			minForSevere = 0.60,
			severeIndexInfluence = 0,
			requiredRisks = {},
			noSpawnIfActive = {"hurricane", "tornado", "derecho", "rainstorm"},
			seasonFrequencyMult = {winter = 0.4, spring = 1.10, summer = 1.20, fall = 0.70},
			climateMult = {dry = 0.40, convective = 1.65, tropical = 1.25, cold = 0.28},
			influences = {
				CAPE = {start = 100, peak = 2400, weight = 3.00},
				RH = {start = 45, peak = 78, weight = 2.35},
				LAPSE = {start = 4.8, peak = 7.6, weight = 1.85},
				SHEAR = {peak = {0, 32}, decline = 60, weight = 0.75},
				SRH = {peak = {0, 175}, decline = 550, weight = 0.45},
				TEMPERATURE = {start = -25, peak = 27, decline = 40, weight = 1.15},
				WIND = {start = 1, peak = 13, decline = 34, weight = 0.65},
				PRESSURE = {peak = {950, 1015}, decline = 1042, weight = 0.85},
			},
			entityName = "gstorms_weather_thunderstorm_dynamic",
			spawnChanceMul = 1.25,
			minSpacing = 0.5,
			maxInWorld = 1,
		},
	
		derecho = {
			enabledCvar = "gstorms_autospawn_derecho",
			frequencyCvar = "gstorms_autospawn_frequency_derecho",
			baseFrequency = 1,
			minForThreat = 0.2,
			minForSevere = 0.6,
			severeIndexInfluence = 0.70,
			requiredRisks = {"thunderstorm"},
			noSpawnIfActive = {"hurricane", "landspout", "waterspout", "derecho", "tornado"},
			seasonFrequencyMult = {winter = 0.00, spring = 0.85, summer = 1.20, fall = 0.30},
			climateMult = {dry = 0.48, convective = 1.45, tropical = 0.35, cold = 0.22},
			influences = {
				CAPE = {start = 750, peak = {2000, 4500}, decline = 6500, weight = 3.00},
				SHEAR = {start = 18, peak = {30, 48}, weight = 3.35},
				SRH = {peak = {0, 175}, decline = 520, weight = 0.55},
				LAPSE = {start = 5.8, peak = 8.2, weight = 2.10},
				RH = {start = 45, peak = 70, decline = 96, weight = 1.35},
				TEMPERATURE = {start = 17, peak = 32, weight = 1.75},
				WIND = {start = 7, peak = 27, weight = 2.75},
				VORT = {start = 1, peak = 7, weight = 0.85},
				PRESSURE = {peak = {945, 1010}, decline = 1038, weight = 1.05},
			},
			entityName = "gstorms_weather_derecho_dynamic",
			spawnChanceMul = 1.25,
			minSpacing = 0.75,
			maxInWorld = 1,
		},
	}
}

simulationControls.seasonParameterBase = {
	spring = {
		cape = {250, 6500},
		srh = {50, 450},
		lapse = {5.5, 8.5},
		rh = {40, 90},
		shear = {10, 35},
		temperature = {12, 20},
		wind = {3, 18},
		sst = {8, 27},
		vort = {1, 9},
		pressure = {975, 1035},
		latitude = {20, 55},
	},

	summer = {
		cape = {500, 6500},
		srh = {25, 400},
		lapse = {5.0, 8.5},
		rh = {45, 100},
		shear = {5, 25},
		temperature = {20, 26},
		wind = {2, 14},
		sst = {20, 33},
		vort = {1, 8},
		pressure = {960, 1025},
		latitude = {10, 55},
	},

	fall = {
		cape = {100, 3500},
		srh = {75, 500},
		lapse = {4.5, 7.5},
		rh = {40, 100},
		shear = {10, 40},
		temperature = {8, 18},
		wind = {4, 22},
		sst = {12, 31},
		vort = {1, 10},
		pressure = {940, 1035},
		latitude = {20, 58},
	},

	winter = {
		cape = {100, 1500},
		srh = {100, 700},
		lapse = {3.5, 7.0},
		rh = {35, 100},
		shear = {15, 50},
		temperature = {-20, -12},
		wind = {5, 30},
		sst = {-2, 22},
		vort = {2, 10},
		pressure = {930, 1055},
		latitude = {25, 65},
	},
}

simulationControls.climateParameterModification = {
	convective = {
		RH = {add = {-4, 6}},
		LAPSE = {add = {0.0, 0.6}},
		CAPE = {minMult = 0.95, maxMult = 1.15},
		SHEAR = {minMult = 0.95, maxMult = 1.10},
		SRH = {minMult = 1.00, maxMult = 1.20},
		WIND = {minMult = 0.95, maxMult = 1.15},
	},

	dry = {
		TEMPERATURE = {add = {3, 8}},
		RH = {add = {-34, -14}},
		LAPSE = {add = {0.2, 1.0}},
		CAPE = {minMult = 0.12, maxMult = 0.55},
		SHEAR = {minMult = 1.00, maxMult = 1.20},
		WIND = {add = {6, 18}, temperatureScalar = 0.12},
		PRESSURE = {add = {4, 16}},
		SST = {clamp = {2, 18}},
	},

	tropical = {
		TEMPERATURE = {add = {1, 4}},
		RH = {add = {8, 16}},
		LAPSE = {add = {-1.4, -0.6}},
		CAPE = {minMult = 0.35, maxMult = 0.80},
		SHEAR = {minMult = 0.25, maxMult = 0.70},
		SRH = {minMult = 0.35, maxMult = 0.80},
		WIND = {minMult = 0.65, maxMult = 1.00},
		PRESSURE = {add = {-26, -8}},
		SST = {add = {1.0, 3.2}},
		VORT = {add = {5, 14}},
		LATITUDE = {clamp = {6, 30}},
	},

	cold = {
		TEMPERATURE = {add = {-8, 0}, maxClamp = 8},
		RH = {add = {4, 14}},
		LAPSE = {add = {-0.4, 0.35}},
		CAPE = {minMult = 0.05, maxMult = 0.30},
		SHEAR = {add = {4, 10}},
		SRH = {add = {20, 80}},
		WIND = {add = {4, 14}},
		PRESSURE = {add = {2, 18}},
		SST = {clamp = {2, 14}},
		LATITUDE = {clamp = {25, 55}},
	},
}

local strengthBalancing = {
	tornado = {
		strengthTables = {
			strengthTable = {
				{minWS = 65,  maxWS = 85,  startWeight = 50, endWeight = 0},
				{minWS = 86,  maxWS = 110, startWeight = 25, endWeight = 0},
				{minWS = 111, maxWS = 135, startWeight = 10, endWeight = 3},
				{minWS = 136, maxWS = 165, startWeight = 4, endWeight = 7},
				{minWS = 166, maxWS = 200, startWeight = 0, endWeight = 10},
				{minWS = 201, maxWS = 250, startWeight = 0, endWeight = 8},
			},
			strengthTableAnticyclonic = {
				{minWS = 65,  maxWS = 85,  startWeight = 65, endWeight = 0},
				{minWS = 86,  maxWS = 110, startWeight = 24, endWeight = 10},
				{minWS = 111, maxWS = 135, startWeight = 8, endWeight = 15},
				{minWS = 136, maxWS = 150, startWeight = 0, endWeight = 10},
			}
		},
	},

	dustdevil = {
		strengthTables = {
			strengthTable = {
				{minWS = 24, maxWS = 35, startWeight = 65, endWeight = 12},
				{minWS = 36, maxWS = 50, startWeight = 25, endWeight = 28},
				{minWS = 51, maxWS = 65, startWeight = 8, endWeight = 30},
				{minWS = 66, maxWS = 74, startWeight = 1, endWeight = 25},
			}
		},
	},

	hurricane = {
		strengthTables = {
			strengthTable = {
				{minWS = 25,  maxWS = 38,  startWeight = 35, endWeight = 0},
				{minWS = 39,  maxWS = 73,  startWeight = 35, endWeight = 3},
				{minWS = 74,  maxWS = 95,  startWeight = 16, endWeight = 16},
				{minWS = 96,  maxWS = 110, startWeight = 8, endWeight = 18},
				{minWS = 111, maxWS = 129, startWeight = 4, endWeight = 20},
				{minWS = 130, maxWS = 156, startWeight = 2, endWeight = 18},
				{minWS = 157, maxWS = 170, startWeight = 0, endWeight = 8},
			}
		},
	},

	landspout = {
		strengthTables = {
			strengthTable = {
				{minWS = 65,  maxWS = 85,  startWeight = 65, endWeight = 20},
				{minWS = 86,  maxWS = 110, startWeight = 30, endWeight = 30},
				{minWS = 111, maxWS = 130, startWeight = 5, endWeight = 20},
			}
		},
	},

	waterspout = {
		strengthTables = {
			strengthTable = {
				{minWS = 65,  maxWS = 85,  startWeight = 65, endWeight = 20},
				{minWS = 86,  maxWS = 110, startWeight = 30, endWeight = 45},
				{minWS = 111, maxWS = 130, startWeight = 5, endWeight = 20},
			}
		},
	},
	derecho = {
		strengthTables = {
			strengthTable = {
				{minWS = 58,  maxWS = 65,  startWeight = 65, endWeight = 15},
				{minWS = 66,  maxWS = 75, startWeight = 25, endWeight = 40},
				{minWS = 76, maxWS = 85, startWeight = 3, endWeight = 20},
			}
		},
	},
}

-- Autospawn Core
------------------------------------------------------------------------------------------------------------------------------------------------------

local gsEntityOrder = {"sandstorm", "dustdevil", "rainstorm", "thunderstorm", "landspout", "waterspout", "derecho", "tornado", "hurricane"}
local gsSeasonOrder = {"winter", "spring", "summer", "fall"}
local gsClimateOrder = {"dry", "convective", "tropical", "cold"}
local gsRiskNameByIndex = {[1] = "NONE", [2] = "TSTM", [3] = "MRGL", [4] = "SLGT", [5] = "ENH", [6] = "MDT", [7] = "HIGH"}
local gsRiskIndexByName = {NONE = 1, TSTM = 2, MRGL = 3, SLGT = 4, ENH = 5, MDT = 6, HIGH = 7}
local gsSeasonKeyByID = {[1] = "winter", [2] = "spring", [3] = "summer", [4] = "fall"}

local prevOutlook = nil
local lastDayNumber = nil
local seasonCycleOffsetDays = nil
local seasonCycleInitialized = false
local startingSeasonKey = "spring"
local gsAutospawnState = {}

local autospawnUpdateSpeed = 0.5
local outlookTable = {}

local function GSClamp01(x) return math.Clamp(x, 0, 1) end
local function GSNorm(x, a, b) return GSClamp01((x - a) / math.max(b - a, 0.0001)) end
local function GSDewpointC(temperature, rh) return temperature - ((100 - rh) * 0.2) end
local function GSLCLHeightM(temperature, dewpoint) return math.max(0, 125 * (temperature - dewpoint)) end
local function GSAutospawnPickPeakT() return math.Rand(0.1, 0.9) end
local function GSAutospawnRiskIndexFromName(riskName) return gsRiskIndexByName[riskName] or 1 end
local function GSShouldCountEntForKey(ent, key) return ent.Autospawn == true and ent.AutospawnKey == key end

local function GSUpdateEntityConvars()
	for i = 1, #gsEntityOrder do
		local key = gsEntityOrder[i]
		local cfg = simulationControls.entities[key]
		cfg.enabled = GetConVar(cfg.enabledCvar):GetBool()
		cfg.frequency = GetConVar(cfg.frequencyCvar):GetFloat() * cfg.baseFrequency
	end
end

local function GSGetStringSelection(temp)
	return {
		sandstorm = {
			sentenceMild = "Patchy blowing dust is possible.",
			sentenceHigh = "Widespread blowing dust and sandstorms are expected."
		},

		dustdevil = {
			sentenceMild = "A few dust devils are possible in dry, breezy conditions.",
			sentenceHigh = "Numerous dust devils are expected in dry, breezy conditions."
		},

		rainstorm = {
			sentenceMild = temp > 0 and "Isolated showers are possible." or "Snowfall is possible",
			sentenceHigh = temp > 0 and "Heavy rainfall is possible, with localized flooding." or "Heavy snowfall is likely"
		},

		thunderstorm = {
			sentenceMild = temp > 0 and "A few thunderstorms are possible." or "Snowstorms may develop",
			sentenceHigh = temp > 0 and "Numerous thunderstorms are expected, some potentially severe." or "Snowstorms are expected"
		},

		landspout = {
			sentenceMild = "Landspouts are possible with developing convection.",
			sentenceHigh = "Landspouts are likely with developing convection."
		},

		waterspout = {
			sentenceMild = "Waterspouts are possible over area waters.",
			sentenceHigh = "Waterspouts are likely over area waters."
		},

		derecho = {
			sentenceMild = "Organized storms may produce strong to severe wind gusts.",
			sentenceHigh = "Widespread damaging winds are likely, including derecho potential."
		},

		tornado = {
			sentenceMild = "A tornado cannot be ruled out.",
			sentenceHigh = "Long tracked & violent tornadoes are possible."
		},

		hurricane = {
			sentenceMild = "Tropical storm " .. tostring(HURRICANENAMES[math.random(#HURRICANENAMES)]) .. " may make landfall with damaging winds.",
			sentenceHigh = "Hurricane " .. tostring(HURRICANENAMES[math.random(#HURRICANENAMES)]) .. " is likely to make landfall with destructive winds and life-threatening impacts."
		},
	}
end

function GSGetAtmosphericProperties() return CURRENTPARAMETERS end

local function GSFindSeasonIndex(activeSeasons, seasonKey)
	for i = 1, #activeSeasons do
		if activeSeasons[i] == seasonKey then return i end
	end

	return 1
end

local function GSGetEnabledSeasonOrder()
	local out = {}

	for i = 1, #gsSeasonOrder do
		local key = gsSeasonOrder[i]
		local def = simulationControls.seasons[key]
		if def and GetConVar(def.enabledCvar):GetBool() then out[#out + 1] = key end
	end

	if #out == 0 then out[1] = "spring" end
	return out
end

local function GSGetSeasonDayCount() return math.max(GetConVar("gstorms_autospawn_season_length"):GetInt(), 1) end

local function GSSetSeasonToPeak(seasonKey, dayNumber, dayFrac)
	local activeSeasons = GSGetEnabledSeasonOrder()
	local seasonLength = GSGetSeasonDayCount()
	local totalDays = math.max(#activeSeasons * seasonLength, 1)
	local seasonIndex = GSFindSeasonIndex(activeSeasons, seasonKey)
	local resolvedKey = activeSeasons[seasonIndex] or activeSeasons[1] or "spring"
	local baseDay = (((dayNumber or 1) - 1) + (dayFrac or 0))
	local targetDay = ((seasonIndex - 1) * seasonLength) + (seasonLength * 0.5)

	seasonCycleOffsetDays = targetDay - baseDay
	seasonCycleOffsetDays = seasonCycleOffsetDays - (math.floor(seasonCycleOffsetDays / totalDays) * totalDays)
	seasonCycleInitialized = true

	return resolvedKey
end

local function GSInitializeSeasonCycle()
	if seasonCycleInitialized then return end
	GSSetSeasonToPeak(startingSeasonKey, 1, 0)
end

local gsSeasonBlendRangeKeys = {"cape", "srh", "lapse", "rh", "shear", "temperature", "wind", "sst", "vort", "pressure", "latitude"}

local function GSGetWrappedSeasonDef(activeSeasons, index)
	local count = #activeSeasons
	if count <= 0 then return "spring", simulationControls.seasons.spring end

	index = ((index - 1) % count) + 1

	local key = activeSeasons[index]
	return key, simulationControls.seasons[key]
end

local function GSBlendNumberRange(a, b, t)
	a = a or b
	b = b or a
	if !a then return {0, 0} end
	return {Lerp(t, a[1] or 0, b[1] or a[1] or 0), Lerp(t, a[2] or a[1] or 0, b[2] or b[1] or a[2] or a[1] or 0)}
end

local function GSBlendClimateWeights(a, b, t)
	local out = {}
	a = a or b or {}
	b = b or a or {}

	for i = 1, #gsClimateOrder do
		local key = gsClimateOrder[i]
		out[key] = Lerp(t, a[key] or 0, b[key] or 0)
	end

	return out
end

local function GSBuildBlendedSeason(fromDef, toDef, t, currentDef, fromKey, toKey, currentKey)
	local out = {}
	fromDef = fromDef or currentDef
	toDef = toDef or currentDef

	local fromParams = simulationControls.seasonParameterBase[fromKey] or simulationControls.seasonParameterBase[currentKey]
	local toParams = simulationControls.seasonParameterBase[toKey] or simulationControls.seasonParameterBase[currentKey]

	for i = 1, #gsSeasonBlendRangeKeys do
		local key = gsSeasonBlendRangeKeys[i]
		out[key] = GSBlendNumberRange(fromParams and fromParams[key], toParams and toParams[key], t)
	end

	out.enabledCvar = currentDef.enabledCvar
	out.windDirection = currentDef.windDirection
	out.riskCompression = Lerp(t, fromDef.riskCompression or currentDef.riskCompression or 1, toDef.riskCompression or currentDef.riskCompression or 1)
	out.climateWeights = GSBlendClimateWeights(fromDef.climateWeights, toDef.climateWeights, t)

	return out
end

local function GSGetSeasonContext(dayNumber, dayFrac)
	local activeSeasons = GSGetEnabledSeasonOrder()
	local seasonLength = GSGetSeasonDayCount()
	local totalDays = math.max(#activeSeasons * seasonLength, 1)

	GSInitializeSeasonCycle()

	local yearDay = (((dayNumber or 1) - 1) + (dayFrac or 0)) + (seasonCycleOffsetDays or 0)
	yearDay = yearDay - (math.floor(yearDay / totalDays) * totalDays)

	local seasonIndex = math.floor(yearDay / seasonLength) + 1
	if seasonIndex > #activeSeasons then seasonIndex = #activeSeasons end

	local key = activeSeasons[seasonIndex] or "spring"
	local def = simulationControls.seasons[key]
	local seasonStartDay = (seasonIndex - 1) * seasonLength
	local progress = math.Clamp((yearDay - seasonStartDay) / math.max(seasonLength, 0.0001), 0, 1)
	local fromKey, fromDef, toKey, toDef, blendT

	if progress < 0.5 then
		fromKey, fromDef = GSGetWrappedSeasonDef(activeSeasons, seasonIndex - 1)
		toKey, toDef = key, def
		blendT = 0.5 + progress
	else
		fromKey, fromDef = key, def
		toKey, toDef = GSGetWrappedSeasonDef(activeSeasons, seasonIndex + 1)
		blendT = progress - 0.5
	end

	local blendedSeason = GSBuildBlendedSeason(fromDef, toDef, blendT, def, fromKey, toKey, key)

	return {key = key, seasonKey = key, progress = progress, dayCount = seasonLength, riskFindMultiplier = blendedSeason.riskCompression or 1, climateWeights = blendedSeason.climateWeights, season = blendedSeason, rawSeason = def, blendFrom = fromKey, blendTo = toKey, blendT = blendT}
end

local function GSPickWeightedKey(order, tbl, fallback)
	local total = 0
	for i = 1, #order do total = total + math.max(tbl[order[i]] or 0, 0) end
	if total <= 0 then return fallback end

	local r = math.Rand(0, total)

	for i = 1, #order do
		local key = order[i]
		r = r - math.max(tbl[key] or 0, 0)
		if r <= 0 then return key end
	end

	return fallback
end

local function GSPickClimateForSeason(seasonCtx, desiredIndex)
	local highBias = math.Clamp((desiredIndex - 3) / 3, 0, 1)
	local lowBias = math.Clamp((3 - desiredIndex) / 2, 0, 1)
	local src = seasonCtx.climateWeights

	return GSPickWeightedKey(gsClimateOrder, {dry = (src.dry or 0) * (1 + lowBias * 0.75), convective = (src.convective or 0) * (1 + highBias * 0.95), tropical = (src.tropical or 0) * (1 + highBias * 0.55), cold = (src.cold or 0) * (1 + lowBias * 0.65)}, "convective")
end

local gsParameterClamp = {
	CAPE = {0, 6500},
	SRH = {0, 700},
	LAPSE = {2.0, 9.8},
	RH = {10, 100},
	SHEAR = {0, 60},
	TEMPERATURE = {-60, 60},
	WIND = {0, 80},
	SST = {-5, 36},
	VORT = {0, 70},
	PRESSURE = {880, 1060},
	LATITUDE = {0, 70},
}

local gsParameterSeasonKey = {
	CAPE = "cape",
	SRH = "srh",
	LAPSE = "lapse",
	RH = "rh",
	SHEAR = "shear",
	TEMPERATURE = "temperature",
	WIND = "wind",
	SST = "sst",
	VORT = "vort",
	PRESSURE = "pressure",
	LATITUDE = "latitude",
}

local function GSClampParameterValue(paramName, value)
	local clamp = gsParameterClamp[paramName]
	if !clamp then return value end
	return math.Clamp(value, clamp[1], clamp[2])
end

local function GSGetClimateParameterRange(season, climateCfg, paramName)
	local seasonKey = gsParameterSeasonKey[paramName]
	local range = season and season[seasonKey]
	local lo = range and (range[1] or 0) or 0
	local hi = range and (range[2] or range[1] or 0) or lo
	local mod = climateCfg and climateCfg[paramName]

	if mod then
		if mod.range then
			lo = mod.range[1] or lo
			hi = mod.range[2] or mod.range[1] or hi
		else
			local add = mod.add
			lo = (lo * (mod.minMult or mod.mult or 1)) + (add and (add[1] or 0) or 0)
			hi = (hi * (mod.maxMult or mod.mult or 1)) + (add and (add[2] or add[1] or 0) or 0)
		end

		if mod.clamp then
			local clampLo = mod.clamp[1] or lo
			local clampHi = mod.clamp[2] or clampLo
			lo = math.max(lo, clampLo)
			hi = math.min(hi, clampHi)

			if hi < lo then
				lo = clampLo
				hi = clampHi
			end
		end

		if mod.minClamp then
			lo = math.max(lo, mod.minClamp)
			hi = math.max(hi, mod.minClamp)
		end

		if mod.maxClamp then
			lo = math.min(lo, mod.maxClamp)
			hi = math.min(hi, mod.maxClamp)
		end
	end

	lo = GSClampParameterValue(paramName, lo)
	hi = GSClampParameterValue(paramName, hi)

	if hi < lo then lo, hi = hi, lo end
	return lo, hi
end

local function GSRandClimateParameter(season, climateCfg, paramName)
	local lo, hi = GSGetClimateParameterRange(season, climateCfg, paramName)
	return math.Rand(lo, hi)
end

local function GSApplyClimateModifiers(params, climateCfg)
	local windMod = climateCfg and climateCfg.WIND

	if windMod and windMod.temperatureScalar then
		params.WIND = params.WIND + (windMod.temperatureScalar * params.TEMPERATURE)
	end

	params.CAPE = math.Clamp(params.CAPE, 0, 6500)
	params.SRH = math.Clamp(params.SRH, 0, 700)
	params.LAPSE = math.Clamp(params.LAPSE, 2.0, 9.8)
	params.RH = math.Clamp(params.RH, 10, 100)
	params.SHEAR = math.Clamp(params.SHEAR, 0, 60)
	params.TEMPERATURE = math.Clamp(params.TEMPERATURE, -60, 60)
	params.WIND = math.Clamp(params.WIND, 0, 80)
	params.SST = math.Clamp(params.SST, -5, 36)
	params.VORT = math.Clamp(params.VORT, 0, 70)
	params.PRESSURE = math.Clamp(params.PRESSURE, 880, 1060)
	params.LATITUDE = math.Clamp(params.LATITUDE, 0, 70)
end

local function GSGenerateParameterSet(seasonCtx, climate)
	local s = seasonCtx.season
	local climateCfg = simulationControls.climateParameterModification[climate] or simulationControls.climateParameterModification.convective

	local params = {
		PEAKT = GSAutospawnPickPeakT(),
		CAPE = GSRandClimateParameter(s, climateCfg, "CAPE"),
		SRH = GSRandClimateParameter(s, climateCfg, "SRH"),
		LAPSE = GSRandClimateParameter(s, climateCfg, "LAPSE"),
		RH = GSRandClimateParameter(s, climateCfg, "RH"),
		SHEAR = GSRandClimateParameter(s, climateCfg, "SHEAR"),
		TEMPERATURE = GSRandClimateParameter(s, climateCfg, "TEMPERATURE"),
		WIND = GSRandClimateParameter(s, climateCfg, "WIND"),
		SST = GSRandClimateParameter(s, climateCfg, "SST"),
		VORT = GSRandClimateParameter(s, climateCfg, "VORT"),
		PRESSURE = GSRandClimateParameter(s, climateCfg, "PRESSURE"),
		LATITUDE = GSRandClimateParameter(s, climateCfg, "LATITUDE"),
		WINDDIRECTION = GSGetNormVecNoZ(1),
		SEASON = seasonCtx.seasonKey,
		CLIMATE = climate,
		DAYLENGTH = GetConVar("gstorms_env_day_length"):GetFloat(),
	}

	GSApplyClimateModifiers(params, climateCfg)

	return params
end

local function GSGetInfluenceValue(x, cfg)
	local peak = cfg.peak
	local start = cfg.start
	local decline = cfg.decline

	if istable(peak) then
		local low, high = peak[1], peak[2]
		if x >= low and x <= high then return 1 end

		if x < low then
			local from = start or ((decline and decline < low) and decline or nil)
			if !from then return 0 end
			return GSNorm(x, from, low)
		end

		local to = decline and decline > high and decline or nil
		if !to then return 1 end
		return 1 - GSNorm(x, high, to)
	end

	if decline then
		if x < peak then return start and GSNorm(x, start, peak) or 1 end
		return 1 - GSNorm(x, peak, decline)
	end

	return start and GSNorm(x, start, peak) or (x >= peak and 1 or 0)
end

local function GSGetThreatSeasonClimateSupportMultiplier(cfg, seasonCtx, climateKey)
	local seasonKey = seasonCtx and seasonCtx.seasonKey or "spring"
	local seasonMult = cfg.seasonFrequencyMult and (cfg.seasonFrequencyMult[seasonKey] or 1) or 1
	local climateMult = cfg.climateMult and (cfg.climateMult[climateKey] or 1) or 1
	local support = seasonMult * climateMult

	if support <= 0 then return 0 end
	return math.Clamp(support, 0.05, 6)
end

local function GSComputeThreatRisk(key, inputs, seasonCtx, climateKey)
	local cfg = simulationControls.entities[key]
	if !cfg or !cfg.enabled then return 0 end

	local product, sumW = 1, 0

	for paramName, infl in pairs(cfg.influences) do
		local v = GSClamp01(GSGetInfluenceValue(inputs[paramName] or 0, infl))
		if v <= 0 then return 0 end

		local w = infl.weight or 1
		product = product * (v ^ w)
		sumW = sumW + w
	end

	if sumW <= 0 then return 0 end

	local base = product ^ (1 / sumW)
	local support = GSGetThreatSeasonClimateSupportMultiplier(cfg, seasonCtx, climateKey)

	if support <= 0 then return 0 end
	return GSClamp01(base ^ (1 / support))
end

local function GSPrereqsPass(key, risks)
	local cfg = simulationControls.entities[key]
	local req = cfg.requiredRisks
	if !req or #req == 0 then return true end

	local mode = cfg.requirementsNeed or "any"

	if mode == "all" then
		for i = 1, #req do
			local reqKey = req[i]
			local reqCfg = simulationControls.entities[reqKey]
			if !reqCfg or risks[reqKey] < reqCfg.minForThreat then return false end
		end
		return true
	end

	for i = 1, #req do
		local reqKey = req[i]
		local reqCfg = simulationControls.entities[reqKey]
		if reqCfg and risks[reqKey] >= reqCfg.minForThreat then return true end
	end

	return false
end

local function GSComputeRisksFromParameters(params, seasonCtx, climateKey, desiredIndex)
	local td = GSDewpointC(params.TEMPERATURE, params.RH)
	local lcl = GSLCLHeightM(params.TEMPERATURE, td)
	local inputs = {CAPE = params.CAPE, SRH = params.SRH, LAPSE = params.LAPSE, RH = params.RH, SHEAR = params.SHEAR, TEMPERATURE = params.TEMPERATURE, WIND = params.WIND, SST = params.SST, VORT = params.VORT, PRESSURE = params.PRESSURE, LATITUDE = params.LATITUDE, DEWPOINT = td, LCL = lcl}
	local rawRisks, currentRisks = {}, {}
	local convIndex, severeIndex = 0, 0
	local dominantThreat, dominantVal = nil, 0
	local severeOnly = desiredIndex and desiredIndex >= 3

	for i = 1, #gsEntityOrder do
		local key = gsEntityOrder[i]
		rawRisks[key] = GSComputeThreatRisk(key, inputs, seasonCtx, climateKey)
	end

	for i = 1, #gsEntityOrder do
		local key = gsEntityOrder[i]
		local cfg = simulationControls.entities[key]
		local riskVal = GSPrereqsPass(key, rawRisks) and rawRisks[key] or 0
		currentRisks[key] = riskVal

		if key == "thunderstorm" then convIndex = riskVal end

		local severeInfluence = cfg.severeIndexInfluence or 0

		if severeInfluence > 0 and riskVal >= cfg.minForThreat then
			local val = riskVal * severeInfluence
			if val > severeIndex then severeIndex = val end
		end

		if desiredIndex and riskVal >= cfg.minForThreat and (!severeOnly or severeInfluence > 0) then
			local threatVal = severeOnly and (riskVal * math.max(severeInfluence, 0)) or riskVal

			if threatVal > dominantVal then
				dominantThreat = key
				dominantVal = threatVal
			end
		end
	end

	local riskComputed = "NONE"

	if severeIndex < 0.20 then
		riskComputed = (convIndex >= 0.28) and "TSTM" or "NONE"
	elseif severeIndex < 0.35 then
		riskComputed = "MRGL"
	elseif severeIndex < 0.50 then
		riskComputed = "SLGT"
	elseif severeIndex < 0.65 then
		riskComputed = "ENH"
	elseif severeIndex < 0.80 then
		riskComputed = "MDT"
	else
		riskComputed = "HIGH"
	end

	return riskComputed, currentRisks, severeIndex, dominantThreat
end

local function GSBuildOutlookString(dayNumber, currentRisks, temperature)
	local stringsConcatenated = ""
	local stringSelection = GSGetStringSelection(temperature)

	for i = 1, #gsEntityOrder do
		local key = gsEntityOrder[i]
		local cfg = simulationControls.entities[key]
		if cfg.enabled then
			local v = currentRisks[key] or 0
			if v >= cfg.minForThreat then
				local entry = stringSelection[key]
				local sentence = (v >= cfg.minForSevere) and entry.sentenceHigh or entry.sentenceMild
				stringsConcatenated = stringsConcatenated .. sentence .. " "
			end
		end
	end

	return stringsConcatenated
end

local function GSAutospawnPickRiskBySevereFavor(seasonCtx)
	local severeFavor = math.Clamp(GetConVar("gstorms_autospawn_severe_weather_chance"):GetInt(), 1, 99)
	local diff = severeFavor - 50
	local sign = (diff >= 0) and 1 or -1
	local t = math.abs(diff) / 50
	local p = (t ^ 1.25) * 20
	local w1, w2, w3, w4, w5, w6, w7 = 1, 1, 1, 1, 1, 1, 1

	if p > 0 then
		local x1 = (sign == 1) and 1 or 7
		local x2 = (sign == 1) and 2 or 6
		local x3 = (sign == 1) and 3 or 5
		local x4 = 4
		local x5 = (sign == 1) and 5 or 3
		local x6 = (sign == 1) and 6 or 2
		local x7 = (sign == 1) and 7 or 1
		w1, w2, w3, w4, w5, w6, w7 = x1 ^ p, x2 ^ p, x3 ^ p, x4 ^ p, x5 ^ p, x6 ^ p, x7 ^ p
	end

	local total = w1 + w2 + w3 + w4 + w5 + w6 + w7
	local r = math.Rand(0, total)
	local idx = 7

	local weights = {w1, w2, w3, w4, w5, w6, w7}

	for i = 1, 7 do
		r = r - weights[i]
		if r <= 0 then idx = i break end
	end

	local compressed = 1 + ((idx - 1) * math.Clamp(seasonCtx.riskFindMultiplier or 1, 0, 1.5))
	local low = math.Clamp(math.floor(compressed), 1, 7)
	local high = math.Clamp(math.ceil(compressed), 1, 7)
	local frac = compressed - low
	local finalIndex = ((high > low) and (math.Rand(0, 1) < frac)) and high or low

	return gsRiskNameByIndex[finalIndex], finalIndex
end

local function GSGetClimateAveragedFrequencyMult(cfg, seasonCtx)
	local climateWeights = seasonCtx.climateWeights or {}
	local climateMult = cfg.climateMult
	if !climateMult then return 1 end

	local totalWeight, weightedMult = 0, 0

	for i = 1, #gsClimateOrder do
		local climateKey = gsClimateOrder[i]
		local w = math.max(climateWeights[climateKey] or 0, 0)

		if w > 0 then
			totalWeight = totalWeight + w
			weightedMult = weightedMult + (w * (climateMult[climateKey] or 1))
		end
	end

	if totalWeight <= 0 then return 1 end
	return weightedMult / totalWeight
end

local function GSGetEntityDayFrequencyWeight(key, seasonCtx)
	local cfg = simulationControls.entities[key]
	if !cfg or !cfg.enabled then return 0 end

	local seasonKey = seasonCtx.seasonKey or "spring"
	local seasonMult = cfg.seasonFrequencyMult and (cfg.seasonFrequencyMult[seasonKey] or 1) or 1
	local climateAvg = GSGetClimateAveragedFrequencyMult(cfg, seasonCtx)

	return math.max((cfg.frequency or cfg.baseFrequency or 1) * seasonMult * climateAvg, 0)
end

local function GSPickDominantThreatForSeason(seasonCtx, desiredIndex)
	local severeOnly = desiredIndex >= 3
	local totalWeight, selectedKey = 0, nil

	for i = 1, #gsEntityOrder do
		local key = gsEntityOrder[i]
		local cfg = simulationControls.entities[key]

		if cfg and cfg.enabled and (!severeOnly or (cfg.severeIndexInfluence or 0) > 0) then
			local w = GSGetEntityDayFrequencyWeight(key, seasonCtx)

			if w > 0 then
				totalWeight = totalWeight + w
				if math.Rand(0, totalWeight) <= w then selectedKey = key end
			end
		end
	end

	return selectedKey or (severeOnly and "tornado" or "thunderstorm")
end

local function GSBuildQuietNoneOutlook(seasonCtx)
	local climate = GSPickClimateForSeason(seasonCtx, 1)
	local tbl = GSGenerateParameterSet(seasonCtx, climate)
	local risks = {}

	for i = 1, #gsEntityOrder do
		risks[gsEntityOrder[i]] = 0
	end

	tbl.CAPE = 0
	tbl.WIND = 0
	tbl.RISK = "NONE"
	tbl.RISKS = risks
	tbl.SEVEREINDEX = 0
	tbl.DOMINANTTHREAT = nil
	tbl.DESIREDTHREAT = nil
	tbl.QUIETNONE = true

	return tbl
end

local function GSGetAutospawnTargets(targetDayNumber)
	local selectedDay = targetDayNumber or ((gs_timetable and gs_timetable.dayNumber) or 1)
	local seasonCtx = GSGetSeasonContext(selectedDay, 0.5)
	local desiredRisk, desiredIndex = GSAutospawnPickRiskBySevereFavor(seasonCtx)

	if desiredIndex == 1 then
		local noneDaySomethingChance = math.Clamp(GetConVar("gstorms_autospawn_severe_weather_chance"):GetInt(), 1, 99) * 0.01
		if math.Rand(0, 1) > noneDaySomethingChance then return GSBuildQuietNoneOutlook(seasonCtx) end
	end

	local desiredThreat = GSPickDominantThreatForSeason(seasonCtx, desiredIndex)
	local maxAttempts = 600 + (desiredIndex * 10)
	local bestTbl, bestScore = nil, -1

	for i = 1, maxAttempts do
		local climate = GSPickClimateForSeason(seasonCtx, desiredIndex)
		local tbl = GSGenerateParameterSet(seasonCtx, climate)
		local riskComputed, risks, severeIndex, dominantThreat = GSComputeRisksFromParameters(tbl, seasonCtx, climate, desiredIndex)

		tbl.RISK = riskComputed
		tbl.RISKS = risks
		tbl.SEVEREINDEX = severeIndex
		tbl.DOMINANTTHREAT = dominantThreat
		tbl.DESIREDTHREAT = desiredThreat

		local idx = GSAutospawnRiskIndexFromName(riskComputed)
		local over = math.max(idx - desiredIndex, 0)
		local desiredCfg = simulationControls.entities[desiredThreat]
		local desiredThreatRisk = desiredCfg and (risks[desiredThreat] or 0) or 0
		local threatRiskScore = desiredCfg and GSNorm(desiredThreatRisk, desiredCfg.minForThreat, 1) or 0
		local threatMatchScore = (dominantThreat == desiredThreat) and 0.45 or 0
		local score = (1 - (math.abs(idx - desiredIndex) / 6)) + (severeIndex * 0.35) + (threatRiskScore * 0.30) + threatMatchScore - (over * 0.18) + math.Rand(0, 0.0005)

		if score > bestScore then bestTbl, bestScore = tbl, score end
		if riskComputed == desiredRisk and dominantThreat == desiredThreat then return tbl end
	end

	return bestTbl
end

local function GSBroadcastOutlookTable()
	net.Start("gs_send_outlooktable")
	net.WriteTable(outlookTable)
	net.Broadcast()
end

local function GSAutospawnGenerateOutlooks(dayNumber)
	if !lastDayNumber then
		lastDayNumber = dayNumber
		prevOutlook = GSGetAutospawnTargets(dayNumber - 1)

		for i = 1, 8 do
			local targetDay = dayNumber + (i - 1)
			local tbl = GSGetAutospawnTargets(targetDay)
			outlookTable[i] = tbl
			tbl.OUTLOOKSTRING = GSBuildOutlookString(targetDay, tbl.RISKS, tbl.TEMPERATURE)
		end

		return
	end

	local dayDelta = dayNumber - lastDayNumber
	if dayDelta <= 0 then return end

	for i = 1, math.min(dayDelta, 8) do
		prevOutlook = outlookTable[1] or prevOutlook
		table.remove(outlookTable, 1)

		local targetDay = dayNumber + (#outlookTable)
		local newTbl = GSGetAutospawnTargets(targetDay)
		newTbl.OUTLOOKSTRING = GSBuildOutlookString(targetDay, newTbl.RISKS, newTbl.TEMPERATURE)
		table.insert(outlookTable, newTbl)
	end

	while #outlookTable < 8 do
		local targetDay = dayNumber + (#outlookTable)
		local newTbl = GSGetAutospawnTargets(targetDay)
		newTbl.OUTLOOKSTRING = GSBuildOutlookString(targetDay, newTbl.RISKS, newTbl.TEMPERATURE)
		table.insert(outlookTable, newTbl)
	end

	lastDayNumber = dayNumber
end

local function LerpWindDir(ax, ay, az, bx, by, bz, t)
	local v = Vector(Lerp(t, ax, bx), Lerp(t, ay, by), Lerp(t, az, bz))
	v:Normalize()
	return v
end

local function GSAutospawnApplyLerp(a, b, t)
	CURRENTPARAMETERS.CAPE = Lerp(t, a.CAPE, b.CAPE)
	CURRENTPARAMETERS.SRH = Lerp(t, a.SRH, b.SRH)
	CURRENTPARAMETERS.LAPSE = Lerp(t, a.LAPSE, b.LAPSE)
	CURRENTPARAMETERS.RH = Lerp(t, a.RH, b.RH)
	CURRENTPARAMETERS.SHEAR = Lerp(t, a.SHEAR, b.SHEAR)
	CURRENTPARAMETERS.TEMPERATURE = Lerp(t, a.TEMPERATURE, b.TEMPERATURE)
	CURRENTPARAMETERS.WIND = Lerp(t, a.WIND, b.WIND)
	CURRENTPARAMETERS.SST = Lerp(t, a.SST, b.SST)
	CURRENTPARAMETERS.VORT = Lerp(t, a.VORT, b.VORT)
	CURRENTPARAMETERS.PRESSURE = Lerp(t, a.PRESSURE, b.PRESSURE)
	CURRENTPARAMETERS.LATITUDE = Lerp(t, a.LATITUDE, b.LATITUDE)
	CURRENTPARAMETERS.WINDDIRECTION = LerpWindDir(a.WINDDIRECTION.x, a.WINDDIRECTION.y, a.WINDDIRECTION.z, b.WINDDIRECTION.x, b.WINDDIRECTION.y, b.WINDDIRECTION.z, t)
end

local function GSAutospawnLerpToTargets(dayNumber, t)
	if !prevOutlook or #outlookTable < 2 then return end

	local curOutlook = outlookTable[1]
	local nextOutlook = outlookTable[2]
	local fromOutlook, toOutlook = curOutlook, nextOutlook
	local startAbs, endAbs, curAbs = 0, 0, (dayNumber + t)

	if t < curOutlook.PEAKT then
		fromOutlook, toOutlook = prevOutlook, curOutlook
		startAbs = (dayNumber - 1) + prevOutlook.PEAKT
		endAbs = dayNumber + curOutlook.PEAKT
	else
		fromOutlook, toOutlook = curOutlook, nextOutlook
		startAbs = dayNumber + curOutlook.PEAKT
		endAbs = (dayNumber + 1) + nextOutlook.PEAKT
	end

	local lerpT = math.Clamp((curAbs - startAbs) / math.max(endAbs - startAbs, 0.0001), 0, 1)
	GSAutospawnApplyLerp(fromOutlook, toOutlook, lerpT)

	return fromOutlook, toOutlook, lerpT
end

local function GSUpdateCurrentRisks(seasonCtx, fromClimate, toClimate, climateT)
	fromClimate = fromClimate or SEASON.currentClimate or "convective"
	toClimate = toClimate or fromClimate
	climateT = math.Clamp(climateT or 0, 0, 1)

	if fromClimate == toClimate then
		local _, risks = GSComputeRisksFromParameters(CURRENTPARAMETERS, seasonCtx, fromClimate)

		for i = 1, #gsEntityOrder do
			local key = gsEntityOrder[i]
			CURRENTRISKS[key] = risks[key] or 0
		end

		return
	end

	local _, fromRisks = GSComputeRisksFromParameters(CURRENTPARAMETERS, seasonCtx, fromClimate)
	local _, toRisks = GSComputeRisksFromParameters(CURRENTPARAMETERS, seasonCtx, toClimate)

	for i = 1, #gsEntityOrder do
		local key = gsEntityOrder[i]
		CURRENTRISKS[key] = Lerp(climateT, fromRisks[key] or 0, toRisks[key] or 0)
	end
end

local function GSAutospawnHandler()
	if !gs_timetable then return end

	local t = gs_timetable.t
	local dayNumber = gs_timetable.dayNumber

	GSAutospawnGenerateOutlooks(dayNumber)

	local fromOutlook, toOutlook, lerpT = GSAutospawnLerpToTargets(dayNumber, t)
	local seasonCtx = GSGetSeasonContext(dayNumber, t)

	SEASON.currentSeasonInfo = seasonCtx
	SEASON.currentSeason = seasonCtx.seasonKey

	local fromClimate, toClimate, climateT

	if fromOutlook and toOutlook then
		fromClimate = fromOutlook.CLIMATE or SEASON.currentClimate or "convective"
		toClimate = toOutlook.CLIMATE or fromClimate
		climateT = lerpT or 0
	
		SEASON.currentClimate = (climateT >= 0.5) and toClimate or fromClimate
		SEASON.currentClimateFrom = fromClimate
		SEASON.currentClimateTo = toClimate
		SEASON.currentClimateT = climateT
	else
		fromClimate = outlookTable[1] and outlookTable[1].CLIMATE or SEASON.currentClimate or "convective"
		toClimate = fromClimate
		climateT = 0
	
		SEASON.currentClimate = fromClimate
		SEASON.currentClimateFrom = fromClimate
		SEASON.currentClimateTo = toClimate
		SEASON.currentClimateT = climateT
	end

	GSUpdateCurrentRisks(seasonCtx, fromClimate, toClimate, climateT)
	GSBroadcastOutlookTable()
end

local function GSBuildStrengthTableForRisk(srcTable, weightT)
	if !srcTable then return nil end

	weightT = math.Clamp(weightT or 0, 0, 1)

	local out = {}
	local count = #srcTable
	local startTotal, endTotal, startCenter, endCenter = 0, 0, 0, 0

	for i = 1, count do
		local entry = srcTable[i]
		local startWeight = entry.startWeight or 0
		local endWeight = entry.endWeight or 0

		startTotal = startTotal + startWeight
		endTotal = endTotal + endWeight
		startCenter = startCenter + startWeight * i
		endCenter = endCenter + endWeight * i
	end

	if startTotal <= 0 and endTotal <= 0 then
		for i = 1, count do
			local entry = srcTable[i]
			out[i] = {minWS = entry.minWS, maxWS = entry.maxWS, weight = i == 1 and 1 or 0}
		end

		return out
	end

	startCenter = startTotal > 0 and startCenter / startTotal or endCenter / endTotal
	endCenter = endTotal > 0 and endCenter / endTotal or startCenter

	local center = Lerp(weightT, startCenter, endCenter)
	local startShift = center - startCenter
	local endShift = endCenter - center
	local roundedTotal = 0

	local function SampleWeight(x, useStart)
		x = math.Clamp(x, 1, count)

		local lowI = math.floor(x)
		local highI = math.min(lowI + 1, count)
		local frac = x - lowI
		local lowEntry = srcTable[lowI]
		local highEntry = srcTable[highI]
		local lowWeight = useStart and (lowEntry.startWeight or 0) or (lowEntry.endWeight or 0)
		local highWeight = useStart and (highEntry.startWeight or 0) or (highEntry.endWeight or 0)

		return Lerp(frac, lowWeight, highWeight)
	end

	for i = 1, count do
		local entry = srcTable[i]
		local weight = math.floor(Lerp(weightT, SampleWeight(i - startShift, true), SampleWeight(i + endShift, false)))

		out[i] = {minWS = entry.minWS, maxWS = entry.maxWS, weight = weight}
		roundedTotal = roundedTotal + weight
	end

	if roundedTotal <= 0 then out[1].weight = 1 end

	return out
end

local function GSBuildStrengthTablesForKey(key, riskVal)
	local cfg = simulationControls.entities[key]
	local balance = strengthBalancing[key]

	if !cfg or !balance or !balance.strengthTables then return nil, nil end

	local weightT = GSNorm(riskVal or 0, cfg.minForThreat, 1)
	local tables = balance.strengthTables

	return GSBuildStrengthTableForRisk(tables.strengthTable, weightT), GSBuildStrengthTableForRisk(tables.strengthTableAnticyclonic, weightT)
end

function GSEntityPropertiesFromCurrentRisks(autospawnKey)
	local riskVal = CURRENTRISKS[autospawnKey] or 0
	local strengthTable, strengthTableAnticyclonic = GSBuildStrengthTablesForKey(autospawnKey, riskVal)
	local chanceOfRainWrapped = math.Clamp(math.floor(Lerp(GSNorm(CURRENTPARAMETERS.RH, 60, 90), 5, 2) + 0.5), 2, 5)

	return {strengthTable = strengthTable, strengthTableAnticyclonic = strengthTableAnticyclonic, chanceOfRainWrapped = chanceOfRainWrapped, stormWindspeed = CURRENTPARAMETERS.WIND}
end

local positionCheckOffset = Vector(0, 0, 75000)
local maxAttemptsForSpawnCheck = 80
local gsTraceMaskBySpawnMask = {any = MASK_SOLID_BRUSHONLY + MASK_WATER, landspout = MASK_SOLID_BRUSHONLY, waterspout = MASK_WATER}

local function GSGetSpawnMaskForKey(key)
	if key == "landspout" or key == "sandstorm" or key == "dustdevil" then return "landspout" end
	if key == "waterspout" then return "waterspout" end
	return "any"
end

local function GSAutospawnCountWorldForKey(key, countCache)
	if countCache and countCache[key] != nil then return countCache[key] end

	local cfg = simulationControls.entities[key]
	local className = cfg.entityName
	local count = 0
	local entsFound = ents.FindByClass(className)

	for i = 1, #entsFound do
		local ent = entsFound[i]
		if IsValid(ent) and GSShouldCountEntForKey(ent, key) then count = count + 1 end
	end

	if countCache then countCache[key] = count end
	return count
end

local function GSBlockedByActiveEntity(key, countCache)
	local cfg = simulationControls.entities[key]
	local block = cfg.noSpawnIfActive
	if !block or #block == 0 then return false end

	for i = 1, #block do
		local blockKey = block[i]
		if simulationControls.entities[blockKey] and GSAutospawnCountWorldForKey(blockKey, countCache) > 0 then return true end
	end

	return false
end

local function FetchSpawnLocationAndSpawnEntity(entToSpawn, key, dryRun)
	if !gs_heightPositionFromServerLoad or !gs_heightPositionFromServerLoad.server then return false end

	local spawnMask = GSGetSpawnMaskForKey(key)
	local maskSelected = gsTraceMaskBySpawnMask[spawnMask] or gsTraceMaskBySpawnMask.any

	for i = 1, maxAttemptsForSpawnCheck do
		local positionCheck = Vector(gs_heightPositionFromServerLoad.server.x + math.random(-20000, 20000), gs_heightPositionFromServerLoad.server.y + math.random(-20000, 20000), gs_heightPositionFromServerLoad.server.z - 25)
		local trace = util.TraceLine({start = positionCheck, endpos = positionCheck - positionCheckOffset, mask = maskSelected})

		if !trace.Hit then continue end
		if !util.IsInWorld(trace.HitPos) then continue end

		if dryRun then return true end

		local ent = ents.Create(entToSpawn)
		if !IsValid(ent) then return false end

		ent:SetPos(trace.HitPos + Vector(0, 0, 24))
		ent.Autospawn = true
		ent.AutospawnKey = key
		ent.AutospawnRisk = CURRENTRISKS[key] or 0

		if key == "landspout" then ent.IsLandspout = true end
		if key == "waterspout" then ent.IsWaterspout = true end

		ent:Spawn()
		ent:Activate()

		return true
	end

	return false
end

local function GSAutospawnExpectedPerDay(key, riskVal)
	local cfg = simulationControls.entities[key]
	if !cfg or riskVal < cfg.minForThreat then return 0 end
	return math.max((cfg.spawnChanceMul or 1) * riskVal, 0)
end

local function GSGetSpacingSeconds(cfg, dayLength)
	local spacing = cfg.minSpacing
	if !spacing or spacing <= 0 then return 0 end
	if spacing < 1 then return spacing * dayLength end
	return spacing
end

local function GSAutospawnTrySpawn(key, countCache)
	local cfg = simulationControls.entities[key]

	if cfg.maxInWorld and GSAutospawnCountWorldForKey(key, countCache) >= cfg.maxInWorld then return false end
	if GSBlockedByActiveEntity(key, countCache) then return false end

	local spawned = FetchSpawnLocationAndSpawnEntity(cfg.entityName, key)

	if spawned and countCache then countCache[key] = (countCache[key] or 0) + 1 end
	return spawned
end

local function GSAutospawnSpawnEntitiesHandler(updateSpeed)
	if !gs_timetable then return end

	local worldCountCache = {}
	local dayLength = math.max(GetConVar("gstorms_env_day_length"):GetFloat(), 1)
	local spawnClock = CurTime()
	local formationChanceMult = GetConVar("gstorms_autospawn_formation_chance"):GetFloat()

	for i = 1, #gsEntityOrder do
		local key = gsEntityOrder[i]
		local cfg = simulationControls.entities[key]

		if !cfg.enabled then continue end

		local riskVal = CURRENTRISKS[key] or 0
		local outlookRiskVal = outlookTable[1] and outlookTable[1].RISKS and outlookTable[1].RISKS[key] or 0
		if riskVal < cfg.minForThreat or outlookRiskVal < cfg.minForThreat then continue end

		local st = gsAutospawnState[key]
		if !st then
			st = {nextSpawnTime = 0}
			gsAutospawnState[key] = st
		end

		if spawnClock < st.nextSpawnTime then continue end

		local expectedPerDay = GSAutospawnExpectedPerDay(key, riskVal)
		if expectedPerDay <= 0 then continue end

		local p = ((expectedPerDay * updateSpeed) / dayLength) * formationChanceMult * 2
		if math.Rand(0, 1) >= p then continue end

		if GSAutospawnTrySpawn(key, worldCountCache) then
			st.nextSpawnTime = spawnClock + GSGetSpacingSeconds(cfg, dayLength)
		end
	end
end

local gsLastEarthquakeTime = CurTime()
local gsNextEarthquakeTime = 0

local function GSGetEarthquakeFrequencyRange()
	local minFreq = math.max(GetConVar("gstorms_autospawn_min_frequency_earthquakes"):GetInt(), 0)
	local maxFreq = math.max(GetConVar("gstorms_autospawn_max_frequency_earthquakes"):GetInt(), 0)

	if maxFreq < minFreq then minFreq, maxFreq = maxFreq, minFreq end
	return minFreq, maxFreq
end

local function GSGetEarthquakeStrengthRange()
	local minStrength = math.Clamp(GetConVar("gstorms_autospawn_earthquake_min_strength"):GetInt(), 1, 9)
	local maxStrength = math.Clamp(GetConVar("gstorms_autospawn_earthquake_max_strength"):GetInt(), 1, 9)

	if maxStrength < minStrength then minStrength, maxStrength = maxStrength, minStrength end
	return minStrength, maxStrength
end

local function GSRollNextEarthquakeTime(spawnClock, fromTime)
	local minFreq, maxFreq = GSGetEarthquakeFrequencyRange()
	gsNextEarthquakeTime = (fromTime or spawnClock or CurTime()) + math.random(minFreq, maxFreq)
end

local function GSResetEarthquakeTime()
	GSRollNextEarthquakeTime(CurTime(), gsLastEarthquakeTime or CurTime())
end

cvars.AddChangeCallback("gstorms_autospawn_min_frequency_earthquakes", GSResetEarthquakeTime, "gstorms_autospawn_min_frequency_earthquakes_autospawn")
cvars.AddChangeCallback("gstorms_autospawn_max_frequency_earthquakes", GSResetEarthquakeTime, "gstorms_autospawn_max_frequency_earthquakes_autospawn")

local function GSTrySpawningEarthquakes()
	if !GetConVar("gstorms_autospawn_earthquake"):GetBool() then return end

	local spawnClock = CurTime()

	if gsNextEarthquakeTime <= 0 then GSRollNextEarthquakeTime(spawnClock, gsLastEarthquakeTime) return end
	if spawnClock < gsNextEarthquakeTime then return end

	local minStrength, maxStrength = GSGetEarthquakeStrengthRange()
	local magnitude = math.random(minStrength, maxStrength)

	if FetchSpawnLocationAndSpawnEntity("gstorms_earthquake_m" .. magnitude, "earthquake") then
		gsLastEarthquakeTime = spawnClock
		GSRollNextEarthquakeTime(spawnClock, gsLastEarthquakeTime)
	else
		gsNextEarthquakeTime = spawnClock + 5
	end
end

local function GSResetOutlooks()
	outlookTable = {}
	prevOutlook = nil
	lastDayNumber = nil
	gsAutospawnState = {}
end

GSUpdateEntityConvars()

local lastAutospawnUpdate = CurTime()

timer.Create("gstorms_update_autospawn", autospawnUpdateSpeed, 0, function()
	local curTime = CurTime()

	if !GetConVar("gstorms_autospawn"):GetBool() then lastAutospawnUpdate = curTime return end

	local updateSpeed = math.min(curTime - lastAutospawnUpdate, autospawnUpdateSpeed * 4)
	lastAutospawnUpdate = curTime

	GSUpdateEntityConvars()
	GSAutospawnHandler()
	GSAutospawnSpawnEntitiesHandler(updateSpeed)
	GSTrySpawningEarthquakes()
end)

net.Receive("gs_reroll_outlooks", function()
	GSUpdateEntityConvars()
	GSResetOutlooks()
	GSAutospawnHandler()
end)

net.Receive("gs_set_season", function(_, ply)
	if !IsValid(ply) or !ply:IsAdmin() then return end

	local selectedID = math.Clamp(net.ReadUInt(3), 1, 4)
	local selectedKey = gsSeasonKeyByID[selectedID] or "spring"

	GSSetSeasonToPeak(selectedKey, gs_timetable and gs_timetable.dayNumber or 1, gs_timetable and gs_timetable.t or 0)
	GSUpdateEntityConvars()
	GSResetOutlooks()
	GSAutospawnHandler()
end)

-- DEBUG STARTS --------------------------------------------------------------------------------------------------------------------

/*

local function GSAutospawnDebugCopyParams(src)
	return {
		CAPE = src.CAPE,
		SRH = src.SRH,
		LAPSE = src.LAPSE,
		RH = src.RH,
		SHEAR = src.SHEAR,
		TEMPERATURE = src.TEMPERATURE,
		WIND = src.WIND,
		SST = src.SST,
		VORT = src.VORT,
		PRESSURE = src.PRESSURE,
		LATITUDE = src.LATITUDE,
		WINDDIRECTION = src.WINDDIRECTION,
	}
end

local function GSAutospawnDebugCopyRisks(src)
	local out = {}

	for i = 1, #gsEntityOrder do
		local key = gsEntityOrder[i]
		out[key] = src[key] or 0
	end

	return out
end

local function GSAutospawnDebugParamsString(p)
	local td = GSDewpointC(p.TEMPERATURE or 0, p.RH or 0)
	local lcl = GSLCLHeightM(p.TEMPERATURE or 0, td)

	return string.format("CAPE %.0f | SRH %.0f | LAPSE %.2f | RH %.0f | SHEAR %.1f | TEMP %.1f | WIND %.1f | SST %.1f | VORT %.1f | PRESS %.1f | LAT %.1f | LCL %.0fm",
		p.CAPE or 0,
		p.SRH or 0,
		p.LAPSE or 0,
		p.RH or 0,
		p.SHEAR or 0,
		p.TEMPERATURE or 0,
		p.WIND or 0,
		p.SST or 0,
		p.VORT or 0,
		p.PRESSURE or 0,
		p.LATITUDE or 0,
		lcl
	)
end

local function GSAutospawnDebugRisksString(risks)
	local out = {}

	for i = 1, #gsEntityOrder do
		local key = gsEntityOrder[i]
		out[#out + 1] = key .. "=" .. string.format("%.2f", risks[key] or 0)
	end

	return table.concat(out, ", ")
end

local function GSAutospawnDebugRollStrength(strengthTable)
	if !strengthTable then return nil end

	local total = 0

	for i = 1, #strengthTable do
		total = total + math.max(strengthTable[i].weight or 0, 0)
	end

	if total <= 0 then return nil end

	local r = math.Rand(0, total)

	for i = 1, #strengthTable do
		local entry = strengthTable[i]
		r = r - math.max(entry.weight or 0, 0)

		if r <= 0 then
			local ws = math.Rand(entry.minWS or 0, entry.maxWS or entry.minWS or 0)
			return ws, entry
		end
	end

	local entry = strengthTable[#strengthTable]
	return math.Rand(entry.minWS or 0, entry.maxWS or entry.minWS or 0), entry
end

local function GSAutospawnDebugBestStrengthFromTable(strengthTable, rerolls)
	if !strengthTable then return nil end

	local bestWS, bestEntry = nil, nil

	for i = 1, math.max(rerolls or 2, 1) do
		local ws, entry = GSAutospawnDebugRollStrength(strengthTable)

		if ws and (!bestWS or ws > bestWS) then
			bestWS = ws
			bestEntry = entry
		end
	end

	if !bestWS then return nil end
	return string.format("%.1f MPH [%s-%s]", bestWS, tostring(bestEntry.minWS), tostring(bestEntry.maxWS))
end

local function GSAutospawnDebugBestStrengthString(key, riskVal, rerolls)
	local strengthTable, strengthTableAnticyclonic = GSBuildStrengthTablesForKey(key, riskVal)
	local normal = GSAutospawnDebugBestStrengthFromTable(strengthTable, rerolls)
	local anti = GSAutospawnDebugBestStrengthFromTable(strengthTableAnticyclonic, rerolls)

	if normal and anti then return "best" .. tostring(rerolls or 2) .. "=" .. normal .. " | antiBest" .. tostring(rerolls or 2) .. "=" .. anti end
	if normal then return "best" .. tostring(rerolls or 2) .. "=" .. normal end

	return "stormWS=" .. string.format("%.1f MPH", CURRENTPARAMETERS.WIND or 0)
end

local function GSAutospawnDebugExpireActiveEntities(activeEnts, clock, dayStats)
	for i = #activeEnts, 1, -1 do
		local simEnt = activeEnts[i]

		if clock >= simEnt.deathTime then
			if dayStats then
				dayStats.deaths[simEnt.key] = (dayStats.deaths[simEnt.key] or 0) + 1
				dayStats.deathTotal = dayStats.deathTotal + 1
			end

			table.remove(activeEnts, i)
		end
	end
end

local function GSAutospawnDebugBuildActiveCountCache(activeEnts)
	local countCache = {}

	for i = 1, #activeEnts do
		local key = activeEnts[i].key
		countCache[key] = (countCache[key] or 0) + 1
	end

	return countCache
end

local function GSAutospawnDebugBlockedByActiveEntity(key, countCache)
	local cfg = simulationControls.entities[key]
	local block = cfg.noSpawnIfActive
	if !block or #block == 0 then return false end

	for i = 1, #block do
		local blockKey = block[i]
		if simulationControls.entities[blockKey] and (countCache[blockKey] or 0) > 0 then return true end
	end

	return false
end

local function GSAutospawnDebugUpdateForTime(dayNumber, t)
	gs_timetable = gs_timetable or {}
	gs_timetable.dayNumber = dayNumber
	gs_timetable.t = t

	GSAutospawnGenerateOutlooks(dayNumber)

	local fromOutlook, toOutlook, lerpT = GSAutospawnLerpToTargets(dayNumber, t)
	local seasonCtx = GSGetSeasonContext(dayNumber, t)

	SEASON.currentSeasonInfo = seasonCtx
	SEASON.currentSeason = seasonCtx.seasonKey

	local fromClimate, toClimate, climateT

	if fromOutlook and toOutlook then
		fromClimate = fromOutlook.CLIMATE or SEASON.currentClimate or "convective"
		toClimate = toOutlook.CLIMATE or fromClimate
		climateT = lerpT or 0

		SEASON.currentClimate = (climateT >= 0.5) and toClimate or fromClimate
		SEASON.currentClimateFrom = fromClimate
		SEASON.currentClimateTo = toClimate
		SEASON.currentClimateT = climateT
	else
		fromClimate = outlookTable[1] and outlookTable[1].CLIMATE or SEASON.currentClimate or "convective"
		toClimate = fromClimate
		climateT = 0

		SEASON.currentClimate = fromClimate
		SEASON.currentClimateFrom = fromClimate
		SEASON.currentClimateTo = toClimate
		SEASON.currentClimateT = climateT
	end

	GSUpdateCurrentRisks(seasonCtx, fromClimate, toClimate, climateT)

	return seasonCtx, fromOutlook, toOutlook, lerpT
end

local function GSAutospawnDebugPeakSnapshot(dayNumber)
	GSAutospawnGenerateOutlooks(dayNumber)

	local outlook = outlookTable[1]
	local peakT = outlook and outlook.PEAKT or 0.5
	local seasonCtx = GSAutospawnDebugUpdateForTime(dayNumber, peakT)
	local riskName, risks, severeIndex, dominantThreat = GSComputeRisksFromParameters(CURRENTPARAMETERS, seasonCtx, SEASON.currentClimate or "convective")

	return {
		peakT = peakT,
		outlook = outlook,
		params = GSAutospawnDebugCopyParams(CURRENTPARAMETERS),
		risks = GSAutospawnDebugCopyRisks(risks or CURRENTRISKS),
		riskName = riskName,
		severeIndex = severeIndex or 0,
		dominantThreat = dominantThreat,
		season = seasonCtx and seasonCtx.seasonKey or "unknown",
		climate = outlook and outlook.CLIMATE or SEASON.currentClimate or "unknown",
	}
end

local function GSAutospawnDebugTrySpawn(key, countCache, activeEnts, dayStats, clock, t, entityLifetime, rerolls)
	local cfg = simulationControls.entities[key]

	if cfg.maxInWorld and GSAutospawnCountWorldForKey(key, countCache) >= cfg.maxInWorld then return false end
	if GSBlockedByActiveEntity(key, countCache) then return false end
	if !FetchSpawnLocationAndSpawnEntity(cfg.entityName, key, true) then return false end

	countCache[key] = (countCache[key] or 0) + 1
	activeEnts[#activeEnts + 1] = {key = key, spawnTime = clock, deathTime = clock + entityLifetime}

	dayStats.counts[key] = (dayStats.counts[key] or 0) + 1
	dayStats.total = dayStats.total + 1

	local riskVal = CURRENTRISKS[key] or 0
	local strengthText = GSAutospawnDebugBestStrengthString(key, riskVal, rerolls)

	dayStats.spawns[#dayStats.spawns + 1] = {
		key = key,
		hour = t * 24,
		risk = riskVal,
		strength = strengthText,
		params = GSAutospawnDebugCopyParams(CURRENTPARAMETERS),
		deathClock = clock + entityLifetime,
	}

	print(string.format("[GStorms Autospawn Debug] + %.2fh %s | risk %.3f | %s | simulated death in %.1fs",
		t * 24,
		key,
		riskVal,
		strengthText,
		entityLifetime
	))

	print("    " .. GSAutospawnDebugParamsString(CURRENTPARAMETERS))

	return true
end

function GSDebugAutospawnDays(dayCount, startDayNumber, strengthRerolls)
	if CLIENT then return end

	dayCount = math.max(math.floor(dayCount or 1), 1)
	startDayNumber = startDayNumber or (gs_timetable and gs_timetable.dayNumber) or 1
	strengthRerolls = math.max(math.floor(strengthRerolls or 2), 1)

	local savedTimetable = gs_timetable and {dayNumber = gs_timetable.dayNumber, t = gs_timetable.t} or nil
	local savedOutlookTable = table.Copy(outlookTable or {})
	local savedPrevOutlook = prevOutlook
	local savedLastDayNumber = lastDayNumber
	local savedState = table.Copy(gsAutospawnState or {})
	local savedParameters = GSAutospawnDebugCopyParams(CURRENTPARAMETERS)
	local savedRisks = GSAutospawnDebugCopyRisks(CURRENTRISKS)
	local savedSeason = table.Copy(SEASON or {})

	GSUpdateEntityConvars()
	GSResetOutlooks()

	local dayLength = math.max(GetConVar("gstorms_env_day_length"):GetFloat(), 1)
	local updateSpeed = autospawnUpdateSpeed
	local formationChanceMult = GetConVar("gstorms_autospawn_formation_chance"):GetFloat()
	local lifeCvar = GetConVar("gstorms_sim_max_lifetime")
	local entityLifetime = math.max((lifeCvar and lifeCvar:GetFloat()) or dayLength, updateSpeed)
	local totalUpdates = math.max(math.ceil((dayLength * dayCount) / updateSpeed), 1)
	local clock = 0
	local activeEnts = {}
	local dayStats = {}

	print("----------------------------------------------------------------")
	print(string.format("[GStorms Autospawn Debug] Simulating %d day(s), dayLength %.1fs, updateSpeed %.1fs, updates %d, strength best-of-%d, simulated entity lifetime %.1fs",
		dayCount,
		dayLength,
		updateSpeed,
		totalUpdates,
		strengthRerolls,
		entityLifetime
	))

	for step = 0, totalUpdates - 1 do
		local absDayFrac = (step * updateSpeed) / dayLength
		local dayOffset = math.floor(absDayFrac)

		if dayOffset >= dayCount then break end

		local dayNumber = startDayNumber + dayOffset
		local t = absDayFrac - dayOffset

		if !dayStats[dayOffset] then
			local peak = GSAutospawnDebugPeakSnapshot(dayNumber)

			dayStats[dayOffset] = {
				dayNumber = dayNumber,
				peak = peak,
				counts = {},
				deaths = {},
				spawns = {},
				total = 0,
				deathTotal = 0,
			}

			print("----------------------------------------------------------------")
			print(string.format("[GStorms Autospawn Debug] Day %d | season %s | climate %s | outlook %s | severe %.3f | dominant %s | peakT %.3f / %.2fh",
				dayNumber,
				peak.season,
				peak.climate,
				peak.riskName or (peak.outlook and peak.outlook.RISK) or "NONE",
				peak.severeIndex or 0,
				tostring(peak.dominantThreat or (peak.outlook and peak.outlook.DOMINANTTHREAT) or "none"),
				peak.peakT,
				peak.peakT * 24
			))

			if peak.outlook then
				print("    Desired: " .. tostring(peak.outlook.DESIREDTHREAT or "none") .. " / " .. tostring(peak.outlook.RISK or "NONE"))
				print("    Outlook: " .. tostring(peak.outlook.OUTLOOKSTRING or GSBuildOutlookString(dayNumber, peak.outlook.RISKS or {}, peak.outlook.TEMPERATURE or 0)))
			end

			print("    Peak Atmos: " .. GSAutospawnDebugParamsString(peak.params))
			print("    Peak Risks: " .. GSAutospawnDebugRisksString(peak.risks))
		end

		local stats = dayStats[dayOffset]

		GSAutospawnDebugUpdateForTime(dayNumber, t)
		GSAutospawnDebugExpireActiveEntities(activeEnts, clock, stats)

		local countCache = GSAutospawnDebugBuildActiveCountCache(activeEnts)

		for i = 1, #gsEntityOrder do
			local key = gsEntityOrder[i]
			local cfg = simulationControls.entities[key]

			if !cfg.enabled then continue end

			local riskVal = CURRENTRISKS[key] or 0
			local outlookRiskVal = outlookTable[1] and outlookTable[1].RISKS and outlookTable[1].RISKS[key] or 0
			if riskVal < cfg.minForThreat or outlookRiskVal < cfg.minForThreat then continue end

			local st = gsAutospawnState[key]
			if !st then
				st = {nextSpawnTime = 0}
				gsAutospawnState[key] = st
			end

			if clock < st.nextSpawnTime then continue end

			local expectedPerDay = GSAutospawnExpectedPerDay(key, riskVal)
			if expectedPerDay <= 0 then continue end

			local p = ((expectedPerDay * updateSpeed) / dayLength) * formationChanceMult * 2
			if math.Rand(0, 1) >= p then continue end

			if GSAutospawnDebugTrySpawn(key, countCache, activeEnts, stats, clock, t, entityLifetime, strengthRerolls) then
				st.nextSpawnTime = clock + GSGetSpacingSeconds(cfg, dayLength)
			end
		end

		clock = clock + updateSpeed
	end

	print("----------------------------------------------------------------")
	print("[GStorms Autospawn Debug] Final counts:")

	for d = 0, dayCount - 1 do
		local stats = dayStats[d]

		if stats then
			print(string.format("Day %d | spawned %d total | simulated deaths %d total",
				stats.dayNumber,
				stats.total,
				stats.deathTotal
			))

			for i = 1, #gsEntityOrder do
				local key = gsEntityOrder[i]
				local count = stats.counts[key] or 0

				if count > 0 then
					print("    " .. key .. ": " .. count)
				end
			end
		end
	end

	local finalActive = GSAutospawnDebugBuildActiveCountCache(activeEnts)
	local activeString = ""

	for i = 1, #gsEntityOrder do
		local key = gsEntityOrder[i]
		local count = finalActive[key] or 0

		if count > 0 then
			activeString = activeString .. key .. "=" .. count .. " "
		end
	end

	print("----------------------------------------------------------------")
	print("[GStorms Autospawn Debug] Simulated active entities remainder: " .. (activeString != "" and activeString or "none"))
	print("----------------------------------------------------------------")

	outlookTable = savedOutlookTable
	prevOutlook = savedPrevOutlook
	lastDayNumber = savedLastDayNumber
	gsAutospawnState = savedState

	for k in pairs(CURRENTPARAMETERS) do CURRENTPARAMETERS[k] = nil end
	for k, v in pairs(savedParameters) do CURRENTPARAMETERS[k] = v end

	for k in pairs(CURRENTRISKS) do CURRENTRISKS[k] = nil end
	for k, v in pairs(savedRisks) do CURRENTRISKS[k] = v end

	for k in pairs(SEASON) do SEASON[k] = nil end
	for k, v in pairs(savedSeason) do SEASON[k] = v end

	if savedTimetable then
		gs_timetable = gs_timetable or {}
		gs_timetable.dayNumber = savedTimetable.dayNumber
		gs_timetable.t = savedTimetable.t
	else
		gs_timetable = nil
	end
end

timer.Simple(10, function()
	GSDebugAutospawnDays(32, 1, 2)
end)

*/

-- DEBUG ENDS ----------------------------------------------------------------------------------------------------------------------