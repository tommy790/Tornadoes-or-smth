if CLIENT then include("autorun/client/gstorms_config_menu.lua") end
if SERVER then include("gstorms_funcs/gstorms_shared.lua") end

include("gstorms_funcs/gstorms_shared_tools.lua")

TOOL.Tab = "GStorms"
TOOL.Category = "99_gstorms_tools"
TOOL.Mode = "gstorms_custom_tornado"

local gsMode = TOOL.Mode
local gsPrefix = gsMode .. "_"
local gsFunnelGap = 1000
local gsMinMaxH = gsFunnelGap + 4000
local gsFunnelTopH = 7500
local gsMaxStartH = gsFunnelTopH - gsFunnelGap

TOOL.Name = "#tool." .. gsMode .. ".name"

TOOL.ClientConVar = {
	vortexwindspeed = "201",
	vortexrmwsize = "500",
	anticyclonic = "0",
	vmp_alpha = "0.4",
	vmp_twocelled = "1",

	subvorticesenabled = "1",
	subvortexspawnchance = "75",
	subvortexstrengthmult = "1.5",
	subvortexmaxcount = "5",

	vpn_freq = "5",
	vpn_amp = "4",
	vpn_speed = "500",
	vpn_detail = "1",
	vpn_peak = "1",

	funnelstarth = "0",
	funnelmaxh = "6500",
	fwt_mid = "2",
	fwt_mid_h = "0.5",
	fwt_top = "4",
	fwt_exp = "1",
	fcr_activationh = "0",
	fcr_radiusmult = "1",

	stormwindspeed = "20",
	stormprecipmult = "1",
	rainWrapped = "0",
}

local gsToolDefaults = {}

for k, v in pairs(TOOL.ClientConVar) do gsToolDefaults[k] = v end

if CLIENT then
	language.Add("tool." .. gsMode .. ".name", GSSortText(1, "Custom Tornado"))
	language.Add("tool." .. gsMode .. ".desc", "Spawns a configurable tornado entity.")
	language.Add("tool." .. gsMode .. ".0", "Left click: Spawn the tornado")
	language.Add("tool." .. gsMode .. ".1", "Spawned.")
	language.Add("tool." .. gsMode .. ".2", "Removed.")
end

local function GSClampNum(v, mn, mx, d)
	v = math.Clamp(tonumber(v) or 0, mn, mx)
	return d and math.Round(v, d) or v
end

local function GSResolveFunnelHeights(startH, maxH, preferStart)
	startH = math.Clamp(tonumber(startH) or 0, 0, gsMaxStartH)
	maxH = math.Clamp(tonumber(maxH) or 0, gsMinMaxH, gsFunnelTopH)

	if maxH - startH < gsFunnelGap then
		if preferStart then
			maxH = startH + gsFunnelGap
			if maxH > gsFunnelTopH then maxH = gsFunnelTopH; startH = maxH - gsFunnelGap end
		else
			startH = maxH - gsFunnelGap
			if startH < 0 then startH = 0; maxH = gsMinMaxH end
		end
	end

	if startH > gsMaxStartH then startH = gsMaxStartH; maxH = gsFunnelTopH end
	if maxH < gsMinMaxH then maxH = gsMinMaxH end

	return startH, maxH
end

local function GSApplyEFUSettings(ent, t)
	ent.VortexWindspeed = t.vortexwindspeed
	ent.VortexRMWSize = t.vortexrmwsize
	ent.Anticyclonic = t.anticyclonic
	ent.VortexModelParameters.alpha = t.vmp_alpha
	ent.VortexModelParameters.twoCelled = t.vmp_twocelled

	ent.SubvorticesEnabled = t.subvorticesenabled
	ent.SubvortexSpawnChance = 100 - t.subvortexspawnchance
	ent.SubvortexStrengthMult = t.subvortexstrengthmult
	ent.SubvortexMaxCount = t.subvortexmaxcount

	ent.VortexPositionNoiseFrequency = t.vpn_freq * 0.0001
	ent.VortexPositionNoiseAmplitude = t.vpn_amp
	ent.VortexPositionNoiseSpeed = t.vpn_speed
	ent.VortexPositionNoiseDetail = t.vpn_detail
	ent.VortexPositionNoisePeak = t.vpn_peak

	local startH, maxH = GSResolveFunnelHeights(GSClampNum(t.funnelstarth, 0, gsMaxStartH, 0), GSClampNum(t.funnelmaxh, gsMinMaxH, gsFunnelTopH, 0))

	ent.FunnelStartHeight = startH
	ent.FunnelMaxHeight = maxH
	ent.FunnelWidthTable.midWidth = t.fwt_mid
	ent.FunnelWidthTable.midWidthHeight = t.fwt_mid_h
	ent.FunnelWidthTable.topWidth = t.fwt_top
	ent.FunnelWidthTable.widthExponent = t.fwt_exp
	ent.FunnelCondensationRing.activationHeight = t.fcr_activationh
	ent.FunnelCondensationRing.radiusMultiplier = t.fcr_radiusmult
	ent.FCRActivationHeight = t.fcr_activationh
	ent.FCRRadiusMultiplier = t.fcr_radiusmult

	ent.StormWindspeed = t.stormwindspeed
	ent.StormPrecipitationMultiplier = t.stormprecipmult
	ent.StormRFB = !t.rainWrapped

	local notRainWrapped = !t.rainWrapped

	ent.SupercellParameters = {debrisMax = notRainWrapped and math.Rand(0.8, 1.2) or math.Rand(1.1, 1.3), hookMax = notRainWrapped and math.Rand(0.9, 1.1) or math.Rand(1, 1.1), debrisBSize = math.Rand(0.75, 1), hookLenSize = notRainWrapped and math.Rand(0.5, 1) or math.Rand(0.4, 0.6), hookWidSize = notRainWrapped and math.Rand(0.9, 1.2) or math.Rand(1.0, 1.2), hookAngSize = math.Rand(0.8, 1.2)}

	ent.MaxLifetime = GetConVar("gstorms_sim_max_lifetime"):GetInt()
end

local function GSReadEFUSettings(tool)

	local startH, maxH = GSResolveFunnelHeights(GSClampNum(tool:GetClientNumber("funnelstarth", 0), 0, gsMaxStartH, 0), GSClampNum(tool:GetClientNumber("funnelmaxh", 6500), gsMinMaxH, gsFunnelTopH, 0))

	return {
		vortexwindspeed = GSClampNum(tool:GetClientNumber("vortexwindspeed", 201), 65, 250, 0),
		vortexrmwsize = GSClampNum(tool:GetClientNumber("vortexrmwsize", 500), 50, 3000, 0),
		stormwindspeed = GSClampNum(tool:GetClientNumber("stormwindspeed", 20), 0, 100, 0),
		anticyclonic = GSBool(tool:GetClientNumber("anticyclonic", 0)),

		vmp_alpha = GSClampNum(tool:GetClientNumber("vmp_alpha", 0.5), 0.1, 0.5, 2),
		vmp_twocelled = GSClampNum(tool:GetClientNumber("vmp_twocelled", 1), 0, 1, 1),

		subvorticesenabled = GSBool(tool:GetClientNumber("subvorticesenabled", 1)),
		subvortexspawnchance = GSClampNum(tool:GetClientNumber("subvortexspawnchance", 75), 10, 90, 0),
		subvortexstrengthmult = GSClampNum(tool:GetClientNumber("subvortexstrengthmult", 1.5), 1, 1.5, 2),
		subvortexmaxcount = GSClampNum(tool:GetClientNumber("subvortexmaxcount", 5), 1, 6, 0),

		vpn_freq = GSClampNum(tool:GetClientNumber("vpn_freq", 5), 1, 7.5, 2),
		vpn_amp = GSClampNum(tool:GetClientNumber("vpn_amp", 4), 0, 8, 2),
		vpn_speed = GSClampNum(tool:GetClientNumber("vpn_speed", 500), 100, 750, 0),
		vpn_detail = GSClampNum(tool:GetClientNumber("vpn_detail", 1), 0.5, 2, 1),
		vpn_peak = GSClampNum(tool:GetClientNumber("vpn_peak", 1), 0.1, 1, 1),

		funnelstarth = startH,
		funnelmaxh = maxH,
		fwt_mid = GSClampNum(tool:GetClientNumber("fwt_mid", 2), 1, 8, 2),
		fwt_mid_h = GSClampNum(tool:GetClientNumber("fwt_mid_h", 1), 0.1, 0.9, 1),
		fwt_top = GSClampNum(tool:GetClientNumber("fwt_top", 4), 1, 16, 2),
		fwt_exp = GSClampNum(tool:GetClientNumber("fwt_exp", 1), 0.5, 1.5, 2),
		fcr_activationh = GSClampNum(tool:GetClientNumber("fcr_activationh", 0), 0, 3000, 0),
		fcr_radiusmult = GSClampNum(tool:GetClientNumber("fcr_radiusmult", 1), 1, 3, 2),

		stormprecipmult = GSClampNum(tool:GetClientNumber("stormprecipmult", 1), 0.5, 1.5, 2),
		rainWrapped = GSBool(tool:GetClientNumber("rainWrapped", 0)),
	}
end

-- PRESET HANDLING I.E SAVING, LOADING AND DELETING --------------------------------------------------------------

if CLIENT then

	local gsPresetDir = "gstorms/gstorms_custom_tornado"
	local gsPresetKeys = {}
	
	for key in pairs(gsToolDefaults) do
		gsPresetKeys[#gsPresetKeys + 1] = key
	end
	
	table.sort(gsPresetKeys, function(a, b) return string.lower(a) < string.lower(b) end)
	
	local gsPresetBoolKeys = {
		anticyclonic = true,
		subvorticesenabled = true,
		rainWrapped = true,
	}

	local function GSGetPresetDefault(key) return gsToolDefaults[key] end

	local function GSNormalizePresetData(data)
		local out = {}

		for _, key in ipairs(gsPresetKeys) do
			local v = data and data[key]

			if v == nil then
				v = GSGetPresetDefault(key)
			end

			if gsPresetBoolKeys[key] then
				out[key] = GSBool(v)
			else
				out[key] = tostring(v)
			end
		end

		local startH, maxH = GSResolveFunnelHeights(tonumber(out.funnelstarth) or 0, tonumber(out.funnelmaxh) or 6500)

		out.funnelstarth = tostring(startH)
		out.funnelmaxh = tostring(maxH)

		return out
	end

	local function GSReadCurrentToolPreset()
		local out = {}

		for _, key in ipairs(gsPresetKeys) do
			local cv = GetConVar(gsPrefix .. key)

			if gsPresetBoolKeys[key] then
				out[key] = cv and cv:GetBool() or GSBool(GSGetPresetDefault(key))
			else
				out[key] = cv and cv:GetString() or tostring(GSGetPresetDefault(key))
			end
		end

		return GSNormalizePresetData(out)
	end

	local function GSApplyPresetToConVars(data)
		local t = GSNormalizePresetData(data)

		for _, key in ipairs(gsPresetKeys) do
			RunConsoleCommand(gsPrefix .. key, gsPresetBoolKeys[key] and (t[key] and "1" or "0") or tostring(t[key]))
		end
	end

	function GSAddPresetControls(option)
		GSAddFilePresetControls(option, {
			baseFolder = gsPresetDir,
			treeName = "Custom Tornado Presets",

			readPreset = GSReadCurrentToolPreset,
			normalizePreset = GSNormalizePresetData,
			applyPreset = GSApplyPresetToConVars,

			saveTooltip = "Saves the current custom tornado settings as a local preset",
			createFolderTooltip = "Creates a folder for organizing custom tornado presets",
			importTooltip = "Imports a preset or folder of presets from a copied JSON string",
			exportTooltip = "Copies the selected preset or folder as a JSON string so it can be shared",
			deletePresetTooltip = "Deletes the selected local preset",
			deleteFolderTooltip = "Deletes the selected folder and everything inside it",
			browserHelpText = "Single click a folder to choose where presets save. Double click a preset to load it.",

			deletePresetQueryText = function(name) return "Delete preset '" .. name .. "'?" end,
			deleteFolderQueryText = function(name) return "Delete folder '" .. name .. "' and everything inside it?" end,
		})
	end
end

------------------------------------------------------------------------------------------------------------------

if SERVER then
	duplicator.RegisterEntityModifier("gstorms_custom_tornado_props", function(ply, ent, data)
		if !ent:IsValid() or !data then return end
		if ent:GetClass() ~= "gstorms_weather_efu_custom" then return end
		GSApplyEFUSettings(ent, data)
	end)
end

function TOOL:LeftClick(trace)

	if CLIENT then return true end

	local ply = self:GetOwner()

	if ply:IsValid() and !ply:IsAdmin() then
		GSTipToClient(ply, "You Need To Be An Admin To Spawn That")
		return false
	end

	local ent = ents.Create("gstorms_weather_efu_custom")

	if !trace.Hit or !ent:IsValid() or !ply:IsValid() then return false end

	local pos = trace.HitPos + trace.HitNormal * 8
	local ang = Angle(0, ply:EyeAngles().y, 0)

	ent:SetOwner(ply)
	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent:Spawn()
	ent:Activate()

	local t = GSReadEFUSettings(self)

	GSApplyEFUSettings(ent, t)
	GSApplySpawnPathing(ply, ent)

	duplicator.StoreEntityModifier(ent, "gstorms_custom_tornado_props", t)

	undo.Create("GStorms Custom EFU")
		undo.AddEntity(ent)
		undo.SetPlayer(ply)
	undo.Finish()

	ply:AddCleanup("gstorms_weather_efu_custom", ent)

	return true

end

function TOOL.BuildCPanel(panel)

	local prefix = gsPrefix

	local function ResetToDefaults()
		for key, value in pairs(gsToolDefaults) do
			RunConsoleCommand(prefix .. key, tostring(value))
		end
	end

	GSAddCollapsibleSection(panel, "Presets", true, function(option)
		GSAddPresetControls(option)
	end)

	GSAddCollapsibleSection(panel, "General Vortex Settings", true, function(option)
		local resetButton = option:Button("Reset To Defaults")
		resetButton:SetTooltip("Resets all custom tornado configuration options to their default values")
		resetButton.DoClick = function()
			ResetToDefaults()
		end
		GSNumSlider(option, "Windspeed (MPH)", prefix .. "vortexwindspeed", 65, 250, 0):SetTooltip("The windspeed in MPH")
		GSNumSlider(option, "Radius (Hammer Units)", prefix .. "vortexrmwsize", 50, 3000, 0):SetTooltip("The radius of maximum winds")
		GSNumSlider(option, "Storm Speed (MPH)", prefix .. "stormwindspeed", 0, 100, 0):SetTooltip("The movement speed / storm windspeed of the tornado")
		GSCheckBox(option, "Anticyclonic", prefix .. "anticyclonic"):SetTooltip("Makes the vortex anticyclonic (or rotate clockwise)")
	end)

	GSAddCollapsibleSection(panel, "Vortex Model Settings", true, function(option)
		GSNumSlider(option, "Axial Stretch Rate", prefix .. "vmp_alpha", 0.1, 0.5, 2):SetTooltip("The updraft intensity / inflow intensity of the vortex, lower is a higher swirl ratio")
		GSNumSlider(option, "Two-Celled Height", prefix .. "vmp_twocelled", 0, 1, 1):SetTooltip("Controls the height of the central downdraft in the vortex, 1 = single celled, 0.5 = central downdraft at half the tornadoes height, 0 = fully two celled")
	end)

	GSAddCollapsibleSection(panel, "Subvortices", true, function(option)
		GSCheckBox(option, "Enable Subvortices", prefix .. "subvorticesenabled"):SetTooltip("Enables subvortices")
		GSNumSlider(option, "Subvortex Spawn Chance", prefix .. "subvortexspawnchance", 10, 90, 0):SetTooltip("Spawn chance for subvortices, higher is more frequent subvortex spawns")
		GSNumSlider(option, "Subvortex Strength Mult", prefix .. "subvortexstrengthmult", 1, 1.5, 2):SetTooltip("The strength multiplier for subvortices")
		GSNumSlider(option, "Subvortex Max Count", prefix .. "subvortexmaxcount", 1, 6, 0):SetTooltip("The maximum number of subvortices present in the vortex at a time")
	end)

	GSAddCollapsibleSection(panel, "Funnel", true, function(option)

		local sStart = GSNumSlider(option, "Start Height", prefix .. "funnelstarth", 0, gsMaxStartH, 0)
		sStart:SetTooltip("The starting height of the funnel")

		local sMax = GSNumSlider(option, "Max Height", prefix .. "funnelmaxh", gsMinMaxH, gsFunnelTopH, 0)
		sMax:SetTooltip("The maximum height of the funnel")

		local syncing = false

		local function SetStart(v)
			sStart:SetValue(v)
			RunConsoleCommand(prefix .. "funnelstarth", tostring(v))
		end

		local function SetMax(v)
			sMax:SetValue(v)
			RunConsoleCommand(prefix .. "funnelmaxh", tostring(v))
		end

		sMax.OnValueChanged = function(_, v)
			if syncing then return end
			syncing = true

			local startH, maxH = GSResolveFunnelHeights(sStart:GetValue(), v, false)

			SetStart(startH)
			SetMax(maxH)

			syncing = false
		end

		sStart.OnValueChanged = function(_, v)
			if syncing then return end
			syncing = true

			local startH, maxH = GSResolveFunnelHeights(v, sMax:GetValue(), true)

			SetStart(startH)
			SetMax(maxH)

			syncing = false
		end

		syncing = true
		sStart.OnValueChanged(sStart, sStart:GetValue())
		sMax.OnValueChanged(sMax, sMax:GetValue())
		syncing = false

		GSNumSlider(option, "Middle Width", prefix .. "fwt_mid", 1, 8, 2):SetTooltip("The width of the middle of the funnel")
		GSNumSlider(option, "Middle Width Height", prefix .. "fwt_mid_h", 0.1, 0.9, 1):SetTooltip("The width of the middle of the funnel")
		GSNumSlider(option, "Top Width", prefix .. "fwt_top", 1, 16, 2):SetTooltip("The width of the top of the funnel")
		GSNumSlider(option, "Width Exponent", prefix .. "fwt_exp", 0.5, 1.5, 2):SetTooltip("The exponent for transitioning from I.E base to mid width and mid to top width")

		GSNumSlider(option, "Flared Base Height", prefix .. "fcr_activationh", 0, 3000, 0):SetTooltip("The height that the flared base affects up until in hammer units")
		GSNumSlider(option, "Flared Base Radius", prefix .. "fcr_radiusmult", 1, 3, 2):SetTooltip("The radius multiplier for the flared base")
	end)

	GSAddCollapsibleSection(panel, "Visual / Noise", true, function(option)
		GSNumSlider(option, "Noise Frequency", prefix .. "vpn_freq", 1, 7.5, 2):SetTooltip("The frequency of the noise / curvature of the funnel, higher for more bends & kinks, lower for less bends & kinks")
		GSNumSlider(option, "Noise Amplitude", prefix .. "vpn_amp", 0, 8, 2):SetTooltip("The strength of the noise / curvature of the funnel")
		GSNumSlider(option, "Noise Speed", prefix .. "vpn_speed", 100, 750, 0):SetTooltip("The movement rate of the noise / curvature of the funnel, higher for faster bending and flexing")
		GSNumSlider(option, "Noise Detail", prefix .. "vpn_detail", 0.5, 2, 1):SetTooltip("The size of smaller detailed noise, lower for more random bends and kinks, higher for less random bends and kinks")
		GSNumSlider(option, "Noise Height", prefix .. "vpn_peak", 0.1, 1, 1):SetTooltip("The height where noise peaks & anchors in the funnel between 0 and 1, 1 being the top of the funnel")
	end)

	GSAddCollapsibleSection(panel, "Supercell Parameters", true, function(option)
		GSNumSlider(option, "Storm Precipitation Multiplier", prefix .. "stormprecipmult", 0.5, 1.5, 2):SetTooltip("The amount of precipitation that the storm has")
		GSCheckBox(option, "Rain Wrapped", prefix .. "rainWrapped"):SetTooltip("Whether the storm is rain wrapped or not")
		option:Help("")
	end)

end