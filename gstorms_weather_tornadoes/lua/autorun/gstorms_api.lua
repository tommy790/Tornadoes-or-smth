local stringLower = string.lower
local mathClamp = math.Clamp
local mathFloor = math.floor
local mathRandom = math.random
local bitBand = bit.band

if SERVER then return end

include("autorun/gstorms_environment_handler.lua")

GSShaderParticleProfiles = GSShaderParticleProfiles or {}
if GSShaderParticleProfiles.__APILoaded then return end
GSShaderParticleProfiles.__APILoaded = true

local gsDefaultPackConst = "GStorms: Default Resource Pack"
local function GSDefaultPack() return GSShaderParticleProfiles.DefaultPackName or gsDefaultPackConst end

GSShaderParticleProfiles.Packs = GSShaderParticleProfiles.Packs or {}
GSShaderParticleProfiles.Keys = GSShaderParticleProfiles.Keys or {}
GSShaderParticleProfiles.KeyList = GSShaderParticleProfiles.KeyList or {}
GSShaderParticleProfiles.PackSkyColors = GSShaderParticleProfiles.PackSkyColors or {}
GSShaderParticleProfiles.PackSkyColorsRaw = GSShaderParticleProfiles.PackSkyColorsRaw or {}
GSShaderParticleProfiles.PackFogTables = GSShaderParticleProfiles.PackFogTables or {}

local Packs = GSShaderParticleProfiles.Packs
local RegisteredKeys = GSShaderParticleProfiles.Keys
local RegisteredKeyList = GSShaderParticleProfiles.KeyList
local PackSkyColors = GSShaderParticleProfiles.PackSkyColors
local PackSkyColorsRaw = GSShaderParticleProfiles.PackSkyColorsRaw
local PackFogTables = GSShaderParticleProfiles.PackFogTables
local ProfileEntityOverrides = setmetatable({}, {__mode = "k"})

local function GSIsColor(t) return istable(t) and t.r ~= nil and t.g ~= nil and t.b ~= nil end

local function GSCopyResourceValue(v)
	if GSIsColor(v) then return Color(v.r, v.g, v.b, v.a or 255) end
	if !istable(v) then return v end

	local out = {}

	for k, val in pairs(v) do
		out[k] = GSCopyResourceValue(val)
	end

	return out
end

local resourceFields = {
	{name = "pack_name", aliases = {"pack_name", "packName"}, default = gsDefaultPackConst},
	{name = "lighting_and_environment", aliases = {"lighting_and_environment"}},
	{name = "material", aliases = {"material"}, default = "clouds_and_weather/wispy_smoke4", supported_profiles = "all"},
	{name = "material_flags", aliases = {"material_flags", "materialFlags"}, supported_profiles = "all"},
	{name = "range_min", aliases = {"min"}},
	{name = "range_max", aliases = {"max"}},
	{name = "rotation", aliases = {"rotation"}},
	{name = "alpha_controls", aliases = {"alpha_controls", "alphaControls"}},
	{name = "entity_overrides", aliases = {"entity_overrides", "entityOverrides"}},
	{name = "particle_parameters", aliases = {"particle_parameters", "particleParams"}},
	{name = "offsets", aliases = {"offsets"}},
	{name = "alpha_windspeed", aliases = {"alpha_windspeed", "alphaFromWindspeed"}},
	{name = "alpha_condensation", aliases = {"alpha_condensation", "alphaCondensation"}},
	{name = "requirements", aliases = {"requirements"}},
	{name = "color_over_water", aliases = {"color_over_water", "colorOverWater"}},
	{name = "physics", aliases = {"physics"}},
	{name = "cloud", aliases = {"cloud"}},
	{name = "reflectivity", aliases = {"reflectivity"}},
	{name = "spin", aliases = {"spin"}},

	{name = "static_color", aliases = {"static_color", "color"}, default = Color(255, 255, 255, 255), supported_profiles = "all"},
	{name = "shaded_color", aliases = {"shaded_color", "dynamic_color", "angle_colors", "angleColors"}, supported_profiles = "all"},

	{name = "fall_speed", aliases = {"fall_speed", "fallSpeed"}, dst = "fallSpeed", default = 0, supported_profiles = "all"},
	{name = "height", aliases = {"height", "addHeight"}, dst = "addHeight", default = 0, supported_profiles = "all"},
	{name = "offset_height", source = "offsets", aliases = {"height", "addHeight"}, dst = "addHeight", only_if_present = true, supported_profiles = "all"},

	{name = "alpha_min", source = "alpha_controls", aliases = {"alpha_min", "alphaMin"}, dst = "alphaMin", default = 255, supported_profiles = "all"},
	{name = "alpha_max", source = "alpha_controls", aliases = {"alpha_max", "alphaMax"}, dst = "alphaMax", default = 255, supported_profiles = "all"},
	{name = "fade_in", source = "alpha_controls", aliases = {"fade_in", "fadeIn"}, dst = "fadeIn", default = 0, supported_profiles = "all"},
	{name = "fade_out", source = "alpha_controls", aliases = {"fade_out", "fadeOut"}, dst = "fadeOut", default = 0, supported_profiles = "all"},

	{name = "rot_min", source = "rotation", aliases = {"min", "rotMin"}, dst = "rotMin", default = 0, supported_profiles = "all"},
	{name = "rot_max", source = "rotation", aliases = {"max", "rotMax"}, dst = "rotMax", default = 0, supported_profiles = "all"},

	{name = "size_multiplier", source = "particle_parameters", aliases = {"size_multiplier", "pSizeMult"}, dst = "pSizeMult", default = 1, supported_profiles = "all"},
	{name = "size_random_multiplier", source = "particle_parameters", aliases = {"size_random_multiplier", "pSizeMultRand"}, dst = "pSizeMultRand", default = 1, supported_profiles = "all"},
	{name = "count_multiplier", source = "particle_parameters", aliases = {"count_multiplier", "pCountMult"}, dst = "pCountMult", default = 1, supported_profiles = "all"},
	{name = "lifetime", source = "particle_parameters", aliases = {"lifetime"}, dst = "lifetime", default = 0, supported_profiles = "all"},
	{name = "max_size", source = "particle_parameters", aliases = {"max_size", "particleMaxSize"}, dst = "particleMaxSize", supported_profiles = {"condensation", "subvortexcondensation", "dustdevil", "landspoutlayer"}},

	{name = "orbit_radius", source = "offsets", aliases = {"orbit_radius", "orbitRadius"}, dst = "orbitRadius", default = 0, supported_profiles = {"condensation", "subvortexcondensation", "dustdevil", "landspoutlayer"}},
	{name = "orbit_size", source = "offsets", aliases = {"size"}, dst = "orbitSize", default = 0, supported_profiles = {"condensation", "subvortexcondensation", "dustdevil", "landspoutlayer"}},
	{name = "orbit_radius_size_multiplier", source = "offsets", aliases = {"orbit_radius_size_multiplier", "orbitRadSizeMult"}, dst = "orbitRadSizeMult", default = 1, supported_profiles = {"condensation", "subvortexcondensation", "dustdevil", "landspoutlayer"}},
	{name = "centered", aliases = {"centered"}, dst = "centered", default = false, supported_profiles = {"condensation", "subvortexcondensation", "dustdevil", "landspoutlayer"}},
	{name = "spin_speed", source = "spin", aliases = {"spin_speed", "spinSpeed"}, dst = "spinSpeed", default = 0, supported_profiles = {"condensation", "subvortexcondensation", "dustdevil", "landspoutlayer"}},
	{name = "spin_direction", source = "spin", aliases = {"spin_direction", "spinDirection"}, dst = "spinDir", default = 1, supported_profiles = {"condensation", "subvortexcondensation", "dustdevil", "landspoutlayer"}, normalize_spin_dir = true},
	{name = "blend_top", aliases = {"blend_top", "blendTop"}, dst = "blendTop", default = false, supported_profiles = {"condensation", "dustdevil", "landspoutlayer"}},

	{name = "phys_x", source = "physics", aliases = {"x"}, dst = "physX", default = 0, supported_profiles = {"debris", "curtains"}},
	{name = "phys_y", source = "physics", aliases = {"y"}, dst = "physY", default = 0, supported_profiles = {"debris", "curtains"}},
	{name = "phys_z", source = "physics", aliases = {"z"}, dst = "physZ", default = 0, supported_profiles = {"debris", "curtains"}},

	{name = "alpha_windspeed_min", source = "alpha_windspeed", aliases = {"windspeed_min", "wsMin"}, dst = "afwWsMin", default = 0, supported_profiles = {"condensation", "subvortexcondensation", "mesocyclone", "hurricane", "dustdevil", "landspoutlayer", "curtains", "debris"}},
	{name = "alpha_windspeed_max", source = "alpha_windspeed", aliases = {"windspeed_max", "wsMax"}, dst = "afwWsMax", default = 0, supported_profiles = {"condensation", "subvortexcondensation", "mesocyclone", "hurricane", "dustdevil", "landspoutlayer", "curtains", "debris"}},
	{name = "alpha_windspeed_alpha_min", source = "alpha_windspeed", aliases = {"alpha_min_multiplier", "alphaMin"}, dst = "afwAlphaMin", default = 1, supported_profiles = {"condensation", "subvortexcondensation", "mesocyclone", "hurricane", "dustdevil", "landspoutlayer", "curtains", "debris"}},
	{name = "alpha_windspeed_alpha_max", source = "alpha_windspeed", aliases = {"alpha_max_multiplier", "alphaMax"}, dst = "afwAlphaMax", default = 1, supported_profiles = {"condensation", "subvortexcondensation", "mesocyclone", "hurricane", "dustdevil", "landspoutlayer", "curtains", "debris"}},

	{name = "blend_angle", aliases = {"blend_angle", "useAngleAlpha"}, dst = "useAngleAlpha", supported_profiles = {"condensation", "subvortexcondensation", "mesocyclone", "hurricane", "dustdevil", "landspoutlayer"}},
	{name = "lifetime_override", aliases = {"lifetime_override", "useLifetimeOverride"}, dst = "useLifetimeOverride", supported_profiles = {"condensation", "subvortexcondensation", "mesocyclone", "hurricane", "dustdevil", "landspoutlayer"}},

	{name = "alpha_condensation_windspeed", source = "alpha_condensation", aliases = {"windspeed", "wind_speed", "windSpeed"}, dst_min = "condWsMin", dst_max = "condWsMax", default_min = 0, default_max = 0, allow_single_value = true, supported_profiles = {"condensation"}},
	{name = "alpha_condensation_range", source = "alpha_condensation", aliases = {"range"}, dst_min = "condRangeMin", dst_max = "condRangeMax", default_min = 0, default_max = 0, allow_single_value = true, supported_profiles = {"condensation"}},
	{name = "alpha_condensation_height", source = "alpha_condensation", aliases = {"height"}, dst_min = "condHeightMin", dst_max = "condHeightMax", default_min = 0, default_max = 0, allow_single_value = true, supported_profiles = {"condensation"}},
	{name = "alpha_condensation_alpha_min", source = "alpha_condensation", aliases = {"alpha_min_multiplier", "alphaMinMult"}, dst = "condAlphaMin", default = 0, supported_profiles = {"condensation"}},
	{name = "alpha_condensation_exponent", source = "alpha_condensation", aliases = {"exponent", "exp"}, dst = "condExponent", default = 1, supported_profiles = {"condensation"}},

	{name = "requirement_wind_speed", source = "requirements", aliases = {"wind_speed", "windSpeed", "windspeed"}, dst_min = "reqWSMin", dst_max = "reqWSMax", requirement = true, supported_profiles = {"condensation", "subvortexcondensation", "mesocyclone", "hurricane", "dustdevil", "landspoutlayer", "curtains", "debris"}},
	{name = "requirement_rmw_size", source = "requirements", aliases = {"rmw_size", "rmwSize", "rmw"}, dst_min = "reqRMWMin", dst_max = "reqRMWMax", requirement = true, supported_profiles = {"condensation", "subvortexcondensation", "mesocyclone", "hurricane", "dustdevil", "landspoutlayer", "curtains", "debris"}},

	{name = "min_cloud_size", source = "cloud", aliases = {"min_cloud_size", "minCloudSize"}, dst = "cloudMinSize", default = 4500, supported_profiles = {"cloud"}},
	{name = "max_cloud_size", source = "cloud", aliases = {"max_cloud_size", "maxCloudSize"}, dst = "cloudMaxSize", default = 11000, supported_profiles = {"cloud"}},
	{name = "cloud_count_mult", source = "cloud", aliases = {"count_multiplier", "countMultiplier"}, dst = "cCountMult", default = 1, supported_profiles = {"cloud"}},

	{name = "spawn_radius", aliases = {"spawn_radius", "spawnRadius", "player_offset", "playerOffset"}, legacy_source = "reflectivity", legacy_aliases = {"spawn_radius", "spawnRadius"}, dst = "refSpawnRadius", default = 0, supported_profiles = {"stormcloud", "rainsheet", "rain", "snow", "cloud"}},
	{name = "reflectivity_height_add", source = "reflectivity", aliases = {"height_add", "heightAdd"}, dst = "addHeight", only_if_present = true, reflect_height = true, supported_profiles = {"stormcloud", "rainsheet", "rain", "snow", "cloud"}},
	{name = "reflectivity_base_size", source = "reflectivity", aliases = {"base_size", "baseSize"}, dst = "refBaseSize", default = 1, supported_profiles = {"stormcloud", "rainsheet", "rain", "snow"}},
	{name = "min_reflectivity", source = "reflectivity", aliases = {"min_reflectivity", "minReflectivity"}, dst = "refMinReflectivity", default = 0, supported_profiles = {"stormcloud", "rainsheet", "rain", "snow"}},
	{name = "max_reflectivity", source = "reflectivity", aliases = {"max_reflectivity", "maxReflectivity"}, dst = "refMaxReflectivity", default = 100, supported_profiles = {"stormcloud", "rainsheet", "rain", "snow"}},
	{name = "reflectivity_alpha_multiplier", source = "reflectivity", aliases = {"reflectivity_alpha_multiplier", "reflectivityAlphaMultiplier", "reflectivityAlphaMult"}, dst = "refAlphaMult", default = 1, supported_profiles = {"stormcloud", "rainsheet", "rain", "snow"}},
	{name = "no_alpha_reflectivity", source = "reflectivity", aliases = {"no_alpha_reflectivity", "noAlphaReflectivity"}, dst = "refNoAlphaReflectivity", supported_profiles = {"stormcloud", "rainsheet", "rain", "snow"}},

	{name = "rain_phys", dst = "rainPhys", default = true, supported_profiles = {"rain", "snow"}},

	{name = "color_over_water_alpha", source = "color_over_water", aliases = {"alpha_multiplier", "alphaMult"}, dst = "covAlphaMult", default = 1, supported_profiles = {"debris"}},
	{name = "color_over_water_profile", aliases = {"profile"}},
	{name = "color_over_water_static_color", aliases = {"static_color", "color"}},
	{name = "color_over_water_shaded_color", aliases = {"shaded_color", "dynamic_color", "angle_colors", "angleColors"}},

	{name = "flow_particle_end_size_mult", aliases = {"flow_particle_end_size_mult"}, dst = "flowSizeEndMult", default = 1, supported_profiles = {"sandstorm", "pyroclasticflow"}},
}

local resourceFieldLookup = {}
for i = 1, #resourceFields do
	resourceFieldLookup[resourceFields[i].name] = resourceFields[i]
end

local function GSSupportsProfile(field, keyLower)
	local supported = field.supported_profiles
	if !supported or supported == "all" then return true end
	if isstring(supported) then return supported == keyLower end

	for i = 1, #supported do
		if supported[i] == keyLower then return true end
	end

	return false
end

local function GSGetByAliases(t, aliases)
	if !t or !aliases then return nil, false end

	for i = 1, #aliases do
		local v = t[aliases[i]]
		if v ~= nil then return v, true end
	end

	return nil, false
end

local function GSGetSourceTable(t, source)
	if !source or source == "root" then return t end

	local sourceField = resourceFieldLookup[source]
	if !sourceField then return nil end

	local src = GSGetByAliases(t, sourceField.aliases)
	return istable(src) and src or nil
end

local function GSGetFieldValue(t, fieldName, useDefault)
	local field = resourceFieldLookup[fieldName]
	if !field then return nil, false end

	local v, ok = GSGetByAliases(GSGetSourceTable(t, field.source), field.aliases)
	if ok or !useDefault or field.default == nil then return v, ok end

	return GSCopyResourceValue(field.default), false
end

local function GSGetRawField(t, fieldName)
	return GSGetFieldValue(t, fieldName, false)
end

local function GSMergeSkyValue(base, override)
	if override == nil then return GSCopyResourceValue(base) end
	if GSIsColor(override) then return Color(override.r, override.g, override.b, override.a or 255) end
	if !istable(override) then return override end

	local out = {}

	if istable(base) then
		for k, v in pairs(base) do
			out[k] = GSCopyResourceValue(v)
		end
	end

	for k, v in pairs(override) do
		out[k] = GSMergeSkyValue(base and base[k], v)
	end

	return out
end

local environmentPhaseKeys = {"sunrise", "day", "sunset", "night"}

local function GSGetDefaultPackEnvironment()
	local defaultName = GSDefaultPack()
	return PackSkyColorsRaw[defaultName] or {}
end

local function GSSplitEnvironmentFog(envTable)
	local fogTable = {}

	for i = 1, #environmentPhaseKeys do
		local phaseKey = environmentPhaseKeys[i]
		local phaseTable = envTable[phaseKey]

		if istable(phaseTable) and istable(phaseTable.fog) then
			fogTable[phaseKey] = GSCopyResourceValue(phaseTable.fog)
			phaseTable.fog = nil
		end
	end

	return envTable, fogTable
end

local function GSNormalizePackEnvironment(packName, skyTable)
	local out = GSMergeSkyValue(GSGetDefaultPackEnvironment(), skyTable or {})
	if packName ~= GSDefaultPack() and skyTable == nil then out.legacy_lighting = true end
	return GSSplitEnvironmentFog(out)
end

local function GSCachePackEnvironment(packName, skyTable)
	local normalizedSky, normalizedFog = GSNormalizePackEnvironment(packName, skyTable)

	PackSkyColors[packName] = normalizedSky
	PackFogTables[packName] = normalizedFog

	return normalizedSky, normalizedFog
end

function GSGetPackSkyColors(packName)
	packName = GSResolvePackName(packName)

	if PackSkyColors[packName] then return PackSkyColors[packName] end

	local skyTable = PackSkyColorsRaw[packName]
	local normalizedSky = GSCachePackEnvironment(packName, skyTable)

	return normalizedSky
end

function GSGetPackFogTable(packName)
	packName = GSResolvePackName(packName)

	if PackFogTables[packName] then return PackFogTables[packName] end

	local skyTable = PackSkyColorsRaw[packName]
	local _, normalizedFog = GSCachePackEnvironment(packName, skyTable)

	return normalizedFog
end

local function GSApplyPackSkyColors(packName)
	local skyTable = GSGetPackSkyColors(packName)
	local newFogTable = GSGetPackFogTable(packName)

	net.Start("gs_api_sync_sky")
	net.WriteTable(skyTable)
	net.WriteTable(newFogTable)
	net.SendToServer()
	GSResourcePackSetSky(skyTable, newFogTable)

	return skyTable, newFogTable
end

cvars.AddChangeCallback("gstorms_particle_texture", function(_, oldValue, newValue)
	if oldValue == newValue then return end
	GSApplyPackSkyColors(newValue)
end, "GS_ApplyResourcePackSkyColors")

function GSSetDefaultResourcePack(t)
	local packName = gsDefaultPackConst

	if t then
		local rawPackName = GSGetRawField(t, "pack_name")
		if rawPackName then packName = rawPackName end
	end

	local skyColors = t and GSGetRawField(t, "lighting_and_environment")

	GSShaderParticleProfiles.DefaultPackName = packName
	Packs[packName] = Packs[packName] or {}
	PackSkyColorsRaw[packName] = skyColors and GSCopyResourceValue(skyColors) or nil
	GSCachePackEnvironment(packName, skyColors)
end

function GSGetDefaultResourcePack()
	return GSDefaultPack()
end

local gsParticleTextureCvar
local function GSGetParticleTextureCvar()
	if gsParticleTextureCvar == nil then gsParticleTextureCvar = GetConVar("gstorms_particle_texture") end
	return gsParticleTextureCvar
end

local IDX_LOOKUP = {
	stormcloud = {field = "ParticleIndexStormCloud", getter = "GetParticleIndexStormCloud"},
	rainsheet = {field = "ParticleIndexRainSheet", getter = "GetParticleIndexRainSheet"},
	mesocyclone = {field = "ParticleIndexMesocyclone", getter = "GetParticleIndexMesocyclone"},
	hurricane = {field = "ParticleIndexHurricane", getter = "GetParticleIndexHurricane"},
	condensation = {field = "ParticleIndexCondensation", getter = "GetParticleIndexCondensation"},
	subvortexcondensation = {field = "ParticleIndexSubvortexCondensation", getter = "GetParticleIndexSubvortexCondensation"},
	dustdevil = {field = "ParticleIndexDustDevil", getter = "GetParticleIndexDustDevil"},
	debris = {field = "ParticleIndexDebris", getter = "GetParticleIndexDebris"},
	rain = {field = "ParticleIndexRain", getter = "GetParticleIndexRain"},
	curtains = {field = "ParticleIndexCurtains", getter = "GetParticleIndexCurtains"},
	snow = {field = "ParticleIndexSnow", getter = "GetParticleIndexSnow"},
	pyroclasticflow = {field = "ParticleIndexPyroclasticFlow", getter = "GetParticleIndexPyroclasticFlow"},
	sandstorm = {field = "ParticleIndexSandstorm", getter = "GetParticleIndexSandstorm"},
	landspoutlayer = {field = "ParticleIndexLandspoutLayer", getter = "GetParticleIndexLandspoutLayer"},
}

function GSResolvePackName(packName)
	local def = GSDefaultPack()
	if !packName or packName == "" or !Packs[packName] then return def end
	return packName
end

function GSGetActivePackName()
	local cvar = GSGetParticleTextureCvar()
	if !cvar then return GSDefaultPack() end
	local s = cvar:GetString()
	return (s ~= "" and s) or GSDefaultPack()
end

net.Receive("gs_particle_pack_sync", function()
	local packName = net.ReadString()
	if packName == "" then return end
	packName = GSResolvePackName(packName)

	local cvar = GSGetParticleTextureCvar()
	if cvar and cvar:GetString() ~= packName then
		RunConsoleCommand("gstorms_particle_texture", packName)
	else
		GSShaderParticleProfiles.__PendingPackName = packName
		GSApplyPackSkyColors(packName)
	end
end)

local function GSSanitizePackConvar()
	local cvar = GSGetParticleTextureCvar()
	if !cvar then return end

	local want = cvar:GetString()
	local fixed = GSResolvePackName(want)
	local pending = GSShaderParticleProfiles.__PendingPackName

	if pending and pending ~= "" then
		GSShaderParticleProfiles.__PendingPackName = nil
		fixed = GSResolvePackName(pending)
	end

	if want ~= fixed then RunConsoleCommand("gstorms_particle_texture", fixed) end
end

hook.Add("InitPostEntity", "GS_SanitizeParticlePackOnLoad", function()
	GSSanitizePackConvar()
	GSApplyPackSkyColors(GSGetActivePackName())
end)

local utilCRC = util.CRC
local function GSNormalizeFlags(flags)
	if istable(flags) then
		local s = ""

		for i = 1, #flags do
			local f = flags[i]
			if f and f ~= "" then s = (s == "") and f or (s .. " " .. f) end
		end

		return s
	end

	return flags
end

local function GSBuildMaterial(packName, keyLower, index, path, flags)
	if !path or path == "" then return end

	local mat = Material(path, GSNormalizeFlags(flags))
	local base = mat and mat:GetString("$basetexture")

	if base and base ~= "" then
		local id = utilCRC(packName .. "|" .. keyLower .. "|" .. index)
		local vc = CreateMaterial("gs_shaderparticle_" .. id, "UnlitGeneric", {
			["$basetexture"] = base,
			["$translucent"] = "1",
			["$vertexcolor"] = "1",
			["$vertexalpha"] = "1",
		})

		if vc then mat = vc end
	end

	return mat
end

local function ColorMinMax(v)
	if !v then return end
	if GSIsColor(v) then return v, v, false end
	if !istable(v) then return end

	local mn = v.min or v[1]
	local mx = v.max or v[2]

	if GSIsColor(mn) then
		if GSIsColor(mx) then return mn, mx, true end
		return mn, mn, false
	end
end

local function NormalizeTimed(tbl)
	if !istable(tbl) or GSIsColor(tbl) then return tbl end
	return tbl.day ~= nil and tbl.day or tbl
end

local function NormalizeAngle(ac)
	if !istable(ac) then return end
	if ac.day ~= nil then ac = ac.day end

	local b = ac.bright or ac[1]
	local d = ac.dark or ac[2]
	if !(b and d) then return end

	return {bright = b, dark = d}
end

local function FlattenStaticColors(p, col)
	if !col then return end
	col = NormalizeTimed(col)

	if GSIsColor(col) then
		p.colStatic = col
		return
	end

	if !istable(col) then return end

	local mn, mx = ColorMinMax(col)
	if mn then
		p.colRangeMin, p.colRangeMax = mn, mx
	end
end

local function FlattenAngleColors(p, ac)
	ac = NormalizeAngle(ac)
	if !ac then return end

	local bmn, bmx, br = ColorMinMax(ac.bright or ac[1])
	local dmn, dmx, dr = ColorMinMax(ac.dark or ac[2])
	if !(bmn and dmn) then return end

	p.acBrightMin, p.acBrightMax = bmn, bmx
	p.acDarkMin, p.acDarkMax = dmn, dmx
	p.acHasRanges = (br or dr) and true or nil

	if !p.acHasRanges then
		p.acPair = {bright = bmn, dark = dmn}
	end
end

local function GSApplyColorChoice(out, staticColor, hasStatic, shadedColor, hasShaded)
	if hasStatic then
		FlattenStaticColors(out, staticColor)
		return true
	end

	if hasShaded then
		FlattenAngleColors(out, shadedColor)
		return true
	end

	return false
end

local function BuildCovColorProfile(cov)
	if !istable(cov) then return end

	local tmp = {}
	local staticColor, hasStatic = GSGetByAliases(cov, resourceFieldLookup.color_over_water_static_color.aliases)
	local shadedColor, hasShaded = GSGetByAliases(cov, resourceFieldLookup.color_over_water_shaded_color.aliases)

	if GSApplyColorChoice(tmp, staticColor, hasStatic, shadedColor, hasShaded) then return tmp end

	FlattenAngleColors(tmp, cov)
	if tmp.acPair or tmp.acBrightMin or tmp.acDarkMin then return tmp end

	FlattenStaticColors(tmp, cov)
	if tmp.colStatic or tmp.colRangeMin then return tmp end
end

local function GSReadMinMax(v, ok, field)
	if !ok then
		if field.default_min ~= nil or field.default_max ~= nil then
			return field.default_min, field.default_max, true
		end

		return nil, nil, false
	end

	if istable(v) and !GSIsColor(v) then
		local mn = GSGetByAliases(v, resourceFieldLookup.range_min.aliases)
		local mx = GSGetByAliases(v, resourceFieldLookup.range_max.aliases)

		if mn == nil then mn = mx end
		if mx == nil then mx = mn end
		if mn ~= nil then return mn, mx, true end
	end

	if field.allow_single_value then return v, v, true end

	return nil, nil, false
end

local function GSApplyProfileField(out, def, keyLower, field, onlyExplicit)
	if !field.dst and !field.dst_min then return end
	if !GSSupportsProfile(field, keyLower) then return end

	if field.reflect_height then
		local _, hasRootHeight = GSGetRawField(def, "height")
		local _, hasOffsetHeight = GSGetRawField(def, "offset_height")
		if hasRootHeight or hasOffsetHeight then return end
	end

	local src = GSGetSourceTable(def, field.source)
	local v, ok = GSGetByAliases(src, field.aliases)
	
	if !ok and field.legacy_source and field.legacy_aliases then
		local legacySrc = GSGetSourceTable(def, field.legacy_source)
		v, ok = GSGetByAliases(legacySrc, field.legacy_aliases)
	end

	if field.dst_min then
		if onlyExplicit and !ok then return end

		local mn, mx, valid = GSReadMinMax(v, ok, field)
		if !valid then return end

		if mn ~= nil then out[field.dst_min] = mn end
		if mx ~= nil then out[field.dst_max] = mx end

		if field.requirement then out.hasRequirements = true end

		return
	end

	if !ok then
		if onlyExplicit or field.only_if_present or field.default == nil then return end
		v = GSCopyResourceValue(field.default)
	end

	if field.normalize_spin_dir then v = v < 0 and -1 or 1 end

	out[field.dst] = v
end

local function GSApplyProfileFields(out, def, keyLower, onlyExplicit)
	for i = 1, #resourceFields do
		GSApplyProfileField(out, def, keyLower, resourceFields[i], onlyExplicit)
	end
end

local function GSApplyProfileColor(out, def)
	local staticColor, hasStatic = GSGetRawField(def, "static_color")
	local shadedColor, hasShaded = GSGetRawField(def, "shaded_color")

	if !GSApplyColorChoice(out, staticColor, hasStatic, shadedColor, hasShaded) then
		FlattenStaticColors(out, resourceFieldLookup.static_color.default)
	end
end


local function GSClearProfileColorFields(out)
	out.colStatic = nil
	out.colRangeMin = nil
	out.colRangeMax = nil
	out.acPair = nil
	out.acBrightMin = nil
	out.acBrightMax = nil
	out.acDarkMin = nil
	out.acDarkMax = nil
	out.acHasRanges = nil
end

local entityOverrideLegacyDustDevilMultAliases = {"dust_devil_multiplier", "dustDevilMultiplier", "dust_devil_mult", "dustDevilMult"}

local entityOverrideOrder = {
	{bit = 128, field = "IsDestroying", aliases = {"IsDestroying", "is_destroying", "isDestroying", "destroying"}},
	{bit = 1, field = "Tornado", aliases = {"Tornado", "tornado"}},
	{bit = 2, field = "Spout", aliases = {"Spout", "spout"}},
	{bit = 4, field = "DustDevil", aliases = {"DustDevil", "dust_devil", "dustDevil"}},
	{bit = 8, field = "Hurricane", aliases = {"Hurricane", "hurricane"}},
	{bit = 16, field = "Derecho", aliases = {"Derecho", "derecho"}},
	{bit = 32, field = "Thunderstorm", aliases = {"Thunderstorm", "thunderstorm"}},
	{bit = 64, field = "Rainstorm", aliases = {"Rainstorm", "rainstorm"}},
}

local dustDevilOverrideIndex = 4

local function GSCopyFlatProfile(src)
	local out = {}

	for k, v in pairs(src) do
		out[k] = v
	end

	return out
end

local function GSAddOverrideGroup(groups, groupKey, values)
	if !next(values) then return end

	groups[groupKey] = values
	groups.hasAny = true
end

local function GSFlattenEntityOverrideGroups(def, keyLower)
	local groups = {}

	for i = 1, #resourceFields do
		local field = resourceFields[i]
		local groupKey = field.source or field.name
		local values = groups[groupKey]

		if !values then
			values = {}
			groups[groupKey] = values
		end

		local oldNext = next(values)
		GSApplyProfileField(values, def, keyLower, field, true)
		if !oldNext and next(values) then groups.hasAny = true end
	end

	local staticColor, hasStatic = GSGetRawField(def, "static_color")
	local shadedColor, hasShaded = GSGetRawField(def, "shaded_color")

	if hasStatic or hasShaded then
		local values = {hasColorOverride = true}

		GSApplyColorChoice(values, staticColor, hasStatic, shadedColor, hasShaded)
		GSAddOverrideGroup(groups, "color", values)
	end

	if keyLower == "debris" then
		local cov = GSGetRawField(def, "color_over_water")

		if cov then
			local values = groups.color_over_water or {}
			local covProfile = GSGetByAliases(cov, resourceFieldLookup.color_over_water_profile.aliases)

			if covProfile then
				values.covColorProfile = covProfile
			else
				values.covColorProfile = BuildCovColorProfile(cov)
			end

			GSAddOverrideGroup(groups, "color_over_water", values)
		end
	end

	for k, values in pairs(groups) do
		if k ~= "hasAny" and !next(values) then groups[k] = nil end
	end

	return groups.hasAny and groups or nil
end

local function GSApplyEntityOverrideGroup(out, values)
	local refBaseSize = values.refBaseSize

	if values.hasColorOverride then GSClearProfileColorFields(out) end

	for k, v in pairs(values) do
		if k ~= "refBaseSize" and k ~= "hasColorOverride" then out[k] = v end
	end

	if refBaseSize then out.pSizeMult = out.pSizeMult * refBaseSize end
end

local function GSAddLegacyDustDevilOverride(compiled, baseProf, legacyDustDevilMult)
	if !legacyDustDevilMult or legacyDustDevilMult == 1 then return false end

	local groups = compiled[dustDevilOverrideIndex]
	if !groups then
		groups = {hasAny = true}
		compiled[dustDevilOverrideIndex] = groups
	end

	if groups.alpha_controls then return false end

	groups.alpha_controls = {
		alphaMin = baseProf.alphaMin * legacyDustDevilMult,
		alphaMax = baseProf.alphaMax * legacyDustDevilMult
	}

	return true
end

local function GSBuildEntityOverrideProfiles(baseProf, def, keyLower)
	local raw = GSGetRawField(def, "entity_overrides")
	local compiled, hasOverrides = {}, false

	if istable(raw) then
		for i = 1, #entityOverrideOrder do
			local ov = GSGetByAliases(raw, entityOverrideOrder[i].aliases)

			if istable(ov) then
				local groups = GSFlattenEntityOverrideGroups(ov, keyLower)

				if groups then
					compiled[i] = groups
					hasOverrides = true
				end
			end
		end
	end

	local ac = GSGetSourceTable(def, "alpha_controls")
	local legacyDustDevilMult = istable(ac) and GSGetByAliases(ac, entityOverrideLegacyDustDevilMultAliases)
	if GSAddLegacyDustDevilOverride(compiled, baseProf, legacyDustDevilMult) then hasOverrides = true end

	if !hasOverrides then return end

	local map = {}

	for stateMask = 1, 255 do
		local variant, usedGroups

		for i = 1, #entityOverrideOrder do
			local groups = compiled[i]

			if groups and bitBand(stateMask, entityOverrideOrder[i].bit) ~= 0 then
				if !variant then
					variant = GSCopyFlatProfile(baseProf)
					usedGroups = {}
				end

				for groupKey, values in pairs(groups) do
					if groupKey ~= "hasAny" and !usedGroups[groupKey] then
						GSApplyEntityOverrideGroup(variant, values)
						usedGroups[groupKey] = true
					end
				end
			end
		end

		if variant then
			variant.invLife = (variant.lifetime > 0) and (1 / variant.lifetime) or 0
			map[stateMask] = variant
		end
	end

	ProfileEntityOverrides[baseProf] = map
end

local function GSEntityOverrideStateMask(ent)
	local mask = 0

	if ent.Tornado then mask = mask + 1 end
	if ent.Spout then mask = mask + 2 end
	if ent.DustDevil then mask = mask + 4 end
	if ent.Hurricane then mask = mask + 8 end
	if ent.Derecho then mask = mask + 16 end
	if ent.Thunderstorm then mask = mask + 32 end
	if ent.Rainstorm then mask = mask + 64 end
	if ent.IsDestroying then mask = mask + 128 end

	return mask
end

local function GSApplyEntityOverrideProfile(ent, prof)
	local map = prof and ProfileEntityOverrides[prof]
	if !map then return prof end

	return map[GSEntityOverrideStateMask(ent)] or prof
end

local function GSProfileMatchesRequirements(prof, ws, rmw)
	if !prof or !prof.hasRequirements then return true end
	if prof.reqWSMin ~= nil and ws < prof.reqWSMin then return false end
	if prof.reqWSMax ~= nil and ws > prof.reqWSMax then return false end
	if prof.reqRMWMin ~= nil and rmw < prof.reqRMWMin then return false end
	if prof.reqRMWMax ~= nil and rmw > prof.reqRMWMax then return false end
	return true
end

local function GSRegisterSingleShaderParticleProfile(def, packName)
	if !def or !def.key then return end

	local keyLower = stringLower(def.key)
	if keyLower == "" then return end

	local pack = Packs[packName]
	if !pack then pack = {} Packs[packName] = pack end

	local lst = pack[keyLower]
	if !lst then lst = {count = 0} pack[keyLower] = lst end

	local index = lst.count + 1
	if def.index and def.index > 0 then
		index = mathClamp(mathFloor(def.index), 1, lst.count + 1)
		if lst[index] then index = lst.count + 1 end
	end

	local materialPath = GSGetFieldValue(def, "material", true)
	local materialFlags = GSGetFieldValue(def, "material_flags", true)

	local p = {}
	p.mat = GSBuildMaterial(packName, keyLower, index, materialPath, materialFlags)
	if !p.mat then return end

	GSApplyProfileFields(p, def, keyLower)
	GSApplyProfileColor(p, def)

	p.invLife = (p.lifetime > 0) and (1 / p.lifetime) or 0

	if p.refBaseSize then
		p.pSizeMult = p.pSizeMult * p.refBaseSize
		p.refBaseSize = nil
	end

	if keyLower == "debris" then
		local cov = GSGetRawField(def, "color_over_water") or {}
		local covProfile = GSGetByAliases(cov, resourceFieldLookup.color_over_water_profile.aliases)

		if covProfile then
			p.covColorProfile = covProfile
		else
			p.covColorProfile = BuildCovColorProfile(cov)
		end
	end

	GSBuildEntityOverrideProfiles(p, def, keyLower)

	lst.count = lst.count + 1
	for i = lst.count, index + 1, -1 do lst[i] = lst[i - 1] end
	lst[index] = p

	local reg = RegisteredKeys[keyLower]
	if !reg then
		reg = {}
		RegisteredKeys[keyLower] = reg
		RegisteredKeyList[#RegisteredKeyList + 1] = keyLower
	end

	reg[packName] = reg[packName] or true
end

function GSAddResourcePack(t)
	if !t then return end

	local packName = GSGetRawField(t, "pack_name")
	if !packName then return end

	Packs[packName] = Packs[packName] or {}

	local skyColors = GSGetRawField(t, "lighting_and_environment")
	PackSkyColorsRaw[packName] = skyColors and GSCopyResourceValue(skyColors) or nil
	GSCachePackEnvironment(packName, skyColors)

	for i = 1, #t do GSRegisterSingleShaderParticleProfile(t[i], packName) end

	if GSResolvePackName(GSGetActivePackName()) == packName then GSApplyPackSkyColors(packName) end
end

if !GSShaderParticleProfiles.__DefaultPackLoaded then
	GSShaderParticleProfiles.__DefaultPackLoaded = true
	include("autorun/client/gstorms_base_resource_pack.lua")
end

local function GSGetProfileListAndIndex(packName, keyLower, index)
	local pack = Packs[packName]
	local lst = pack and pack[keyLower]

	if !lst or !lst.count or lst.count <= 0 then
		pack = Packs[GSDefaultPack()]
		lst = pack and pack[keyLower]
		if !lst or !lst.count or lst.count <= 0 then return end
	end

	local count = lst.count
	if !index or index <= 0 then
		index = 1
	else
		index = 1 + ((mathFloor(index) - 1) % count)
	end

	return lst, index, count
end

function GSGetPackProfile(packName, keyLower, index)
	local lst, wrappedIndex = GSGetProfileListAndIndex(packName, keyLower, index)
	if !lst then return end

	return lst[wrappedIndex] or lst[1]
end

local function GSReadEntityParticleIndex(ent, keyLower)
	local lookup = IDX_LOOKUP[keyLower]
	if !lookup then return nil, false end

	local field = lookup.field and ent[lookup.field]
	if field ~= nil then return field, true end

	local fnName = lookup.getter
	local fn = fnName and ent[fnName]
	if fn then return fn(ent), true end

	return nil, false
end

local function GSEnsureParticleSelection(ent)
	if ent.HasSetParticleTypesSelected then return end

	local packName = ent.ParticlePackName or (ent.GetParticleProfile and ent:GetParticleProfile())
	if !packName or packName == "" then packName = GSGetActivePackName() end

	packName = GSResolvePackName(packName)
	ent.ParticlePackName = packName

	local selected = ent.ParticleTypesSelected
	if !selected then selected = {} ent.ParticleTypesSelected = selected end

	local defPack = Packs[GSDefaultPack()]
	local pack = Packs[packName]
	if !pack then pack = defPack end
	if !pack then ent.HasSetParticleTypesSelected = true return end

	for i = 1, #RegisteredKeyList do
		local keyLower = RegisteredKeyList[i]
		local lst = pack[keyLower]
		local count = lst and lst.count
		local usingFallback = false

		if !count or count <= 0 then
			lst = defPack and defPack[keyLower]
			count = lst and lst.count
			usingFallback = true
		end

		if !count or count <= 0 then continue end

		local index = selected[keyLower]

		if !index then
			local gotFromEnt
			index, gotFromEnt = GSReadEntityParticleIndex(ent, keyLower)

			if !index then
				index = (usingFallback and !gotFromEnt) and mathRandom(count) or 1
			end
		end

		index = mathFloor(index)
		if index <= 0 then index = 1 end

		selected[keyLower] = 1 + ((index - 1) % count)
	end

	ent.HasSetParticleTypesSelected = true
end

local function GSGetPackProfileForContext(packName, keyLower, index, ws, rmw)
	local lst, wrappedIndex, count = GSGetProfileListAndIndex(packName, keyLower, index)
	if !lst then return end

	local candidates, candidateCount = {}, 0

	for i = 1, count do
		local prof = lst[i]

		if GSProfileMatchesRequirements(prof, ws, rmw) then
			candidateCount = candidateCount + 1
			candidates[candidateCount] = prof
		end
	end

	if candidateCount <= 0 then return lst[wrappedIndex] or lst[1] end

	wrappedIndex = 1 + ((wrappedIndex - 1) % candidateCount)
	return candidates[wrappedIndex]
end

function GSGetEntProfile(ent, keyLower)
	GSEnsureParticleSelection(ent)
	local prof = GSGetPackProfileForContext(ent.ParticlePackName, keyLower, ent.ParticleTypesSelected[keyLower], ent.VortexWindspeed or 0, ent.VortexRMWSize or 0)
	return GSApplyEntityOverrideProfile(ent, prof)
end