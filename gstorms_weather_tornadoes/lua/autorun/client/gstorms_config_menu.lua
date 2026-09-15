if SERVER then return end

include("autorun/client/gstorms_particle_handler.lua")
include("autorun/gstorms_setup_convars.lua")
include("gstorms_funcs/gstorms_shared.lua")

local gsSortBlank = string.char(226, 128, 139)

function GSSortText(order, text) return string.rep(gsSortBlank, order) .. text end

language.Add("gstorms_menu_settings_general", GSSortText(1, "GStorms General"))
language.Add("gstorms_menu_settings_performance", GSSortText(2, "GStorms Performance & Compatibility"))
language.Add("gstorms_menu_settings_simulation", GSSortText(3, "GStorms Entities & Simulation"))
language.Add("gstorms_menu_settings_environment", GSSortText(4, "GStorms Environment"))
language.Add("gstorms_menu_settings_audio_visual", GSSortText(5, "GStorms Audio & Visual"))
language.Add("gstorms_menu_autospawn_main", GSSortText(1, "GStorms Autospawn General"))
language.Add("gstorms_menu_autospawn_tuning", GSSortText(2, "GStorms Autospawn Tuning"))

hook.Add("AddToolMenuCategories", "GStormsload", function()
	spawnmenu.AddToolCategory("GStorms", "01_gstorms_settings", "GStorms Settings")
	spawnmenu.AddToolCategory("GStorms", "02_gstorms_autospawn", "GStorms Autospawn Options")
	spawnmenu.AddToolCategory("GStorms", "99_gstorms_tools", "GStorms Tools")
end)

-- ADMIN-ONLY CONVAR APPLY (Option A)
-- ================================================================================================================

local gsAdminOnlyConvars = {}
local gsIsClientConvar = {}
local lst = GStormsGetConvar()

for i = 1, #lst do
	local c = lst[i]
	if c and c.name then
		local isClient = bit.band(c.flags or 0, FCVAR_LUA_CLIENT) ~= 0
		gsIsClientConvar[c.name] = isClient
		gsAdminOnlyConvars[c.name] = c.adminOnly and true or false
	end
end

local function CanEditAdminConvars()
	local ply = LocalPlayer()
	return IsValid(ply) and ply:IsAdmin(), ply
end

local gsAdminRefreshList = {}
local gsAdminLastState
local gsAdminNextCheck = 0

local function GSRegisterAdminRefresh(pnl, fn)
	if !IsValid(pnl) or !fn then return end
	pnl.GSAdminRefreshFn = fn
	gsAdminRefreshList[#gsAdminRefreshList + 1] = pnl
end

local function GSRunAdminRefresh(force)

	local isAdmin, ply = CanEditAdminConvars()
	if !IsValid(ply) then return end

	if !force and gsAdminLastState == isAdmin then return end
	gsAdminLastState = isAdmin

	for i = #gsAdminRefreshList, 1, -1 do
		local pnl = gsAdminRefreshList[i]
		if !IsValid(pnl) then
			table.remove(gsAdminRefreshList, i)
		else
			local fn = pnl.GSAdminRefreshFn
			if fn then fn(pnl, isAdmin) end
		end
	end
end

local function GSIsSpawnMenuOpen()
	if spawnmenu.IsOpen then return spawnmenu.IsOpen() end
	return IsValid(g_SpawnMenu) and g_SpawnMenu:IsVisible()
end

hook.Add("Think", "GStorms_AdminMenuRefresh", function()
	if !GSIsSpawnMenuOpen() then gsAdminNextCheck = 0 return end

	local ct = CurTime()
	if ct < (gsAdminNextCheck or 0) then return end
	gsAdminNextCheck = ct + 0.25

	GSRunAdminRefresh(false)
end)

hook.Add("OnSpawnMenuOpen", "GStorms_AdminMenuRefresh_Open", function()
	timer.Simple(0, function()
		GSRunAdminRefresh(true)
	end)
end)

local function GSIsAdminOnlyConVar(name)
	if name == "gstorms_particle_texture" then return false end
	return gsAdminOnlyConvars[name] or false
end

local function GSSetAdminConVar(name, value)
	if !CanEditAdminConvars() then return end

	timer.Simple(0, function()

		if gsIsClientConvar[name] then
			RunConsoleCommand(name, tostring(value))
		else
			RunConsoleCommand("gstorms_set_admin_cvar", name, tostring(value))
		end
	end)
end

local function GSSetPanelEnabled(pnl, enabled)
	if !IsValid(pnl) then return end
	if pnl.SetEnabled then pnl:SetEnabled(enabled) end
	if pnl.SetMouseInputEnabled then pnl:SetMouseInputEnabled(enabled) end
	if pnl.SetKeyboardInputEnabled then pnl:SetKeyboardInputEnabled(enabled) end

	local kids = pnl.GetChildren and pnl:GetChildren()
	if !kids then return end

	for i = 1, #kids do
		local ch = kids[i]
		if IsValid(ch) then
			if ch.SetEnabled then ch:SetEnabled(enabled) end
			if ch.SetMouseInputEnabled then ch:SetMouseInputEnabled(enabled) end
			if ch.SetKeyboardInputEnabled then ch:SetKeyboardInputEnabled(enabled) end
		end
	end
end

local function GSClampNumber(v, min, max, decimals)
	v = tonumber(v) or min or 0
	v = math.Clamp(v, min, max)
	return math.Round(v, decimals)
end

function GSCheckBox(option, label, convarName)

	local pnl = option:CheckBox(label, convarName)
	if !GSIsAdminOnlyConVar(convarName) then return pnl end

	local function RefreshAdminState(_, isAdmin)
		GSSetPanelEnabled(pnl, isAdmin)
	end

	RefreshAdminState(nil, CanEditAdminConvars())
	GSRegisterAdminRefresh(pnl, RefreshAdminState)

	pnl.GSAdminInitBlock = true
	timer.Simple(0, function()
		if IsValid(pnl) then pnl.GSAdminInitBlock = nil end
	end)

	local old = pnl.OnChange
	pnl.OnChange = function(self, val)
		if old then old(self, val) end
		if self.GSAdminInitBlock or !CanEditAdminConvars() then return end
		GSSetAdminConVar(convarName, val and "1" or "0")
	end

	return pnl
end

function GSNumSlider(option, label, convarName, min, max, decimals)

	local pnl = option:NumSlider(label, convarName, min, max, decimals)
	if !GSIsAdminOnlyConVar(convarName) then return pnl end

	local function RefreshAdminState(_, isAdmin)
		GSSetPanelEnabled(pnl, isAdmin)
	end

	RefreshAdminState(nil, CanEditAdminConvars())
	GSRegisterAdminRefresh(pnl, RefreshAdminState)

	pnl.GSAdminInitBlock = true
	timer.Simple(0, function()
		if IsValid(pnl) then pnl.GSAdminInitBlock = nil end
	end)

	local old = pnl.OnValueChanged
	pnl.OnValueChanged = function(self, v)
		if old then old(self, v) end
		if self.GSAdminInitBlock or !CanEditAdminConvars() then return end

		local ct = CurTime()
		if (self.GSAdminNextSend or 0) > ct then return end
		self.GSAdminNextSend = ct + 0.1

		v = GSClampNumber(v, min, max, decimals)
		GSSetAdminConVar(convarName, v)
	end

	return pnl
end

local function GSGetRegisteredParticlePacks()

	local packs = GSShaderParticleProfiles and GSShaderParticleProfiles.Packs
	if !packs then return { "GStorms: Default Resource Pack" } end

	local lst = {}
	for packName, _ in pairs(packs) do
		if packName and packName ~= "" then lst[#lst + 1] = packName end
	end

	if #lst > 1 then table.sort(lst) end
	if #lst <= 0 then lst[1] = "GStorms: Default Resource Pack" end

	return lst

end

local function GSBuildParticlePackDropdown(option)

	local dropdown = vgui.Create("DComboBox")
	dropdown:SetTooltip("The resource pack that the addon will use [Must be an admin]")

	local function Refresh(silent)

		dropdown:Clear()

		local canEdit, ply = CanEditAdminConvars()

		if canEdit then
			local packs = GSGetRegisteredParticlePacks()
			for i = 1, #packs do dropdown:AddChoice(packs[i], packs[i]) end
		else
			local active = GSGetActivePackName()
			dropdown:AddChoice(active, active)
			if !silent and IsValid(ply) then GSTipToClient(ply, "You Need To Be An Admin To Do That") end
		end

		dropdown:SetValue(GSGetActivePackName())
		dropdown:SetEnabled(canEdit)

	end

	Refresh(true)

    GSRegisterAdminRefresh(dropdown, function(self, isAdmin)
		Refresh(true)
	end)

	dropdown.OnMousePressed = function(self, mc)
		if !self:IsMenuOpen() then Refresh(false) end
		return DComboBox.OnMousePressed(self, mc)
	end

	dropdown.OnSelect = function(self, index, value, data)

		local canEdit = CanEditAdminConvars()
		if !canEdit then return end

		local packName = data or value
		if !packName or packName == "" then return end

		net.Start("gs_particle_pack_set")
		net.WriteString(packName)
		net.SendToServer()

		timer.Simple(0, function()
			if self and self:IsValid() then self:SetValue(packName) end
		end)

	end

	option:AddItem(dropdown)

end

function GSAddCollapsibleSection(parent, title, expanded, buildFn)

	local category = vgui.Create("DCollapsibleCategory", parent)

	category:SetLabel(title)
	category:SetExpanded(expanded)

	parent:AddItem(category)

	local form = vgui.Create("DForm", category)

	form:SetName("")
	form:SetSpacing(6)
	form:SetPadding(6)
	form:SetPaintBackground(false)

	if form.SetPaintBorderEnabled then form:SetPaintBorderEnabled(false) end

	form.Paint = function() end

	if form.Header then
		form.Header:SetVisible(false)
		form.Header:SetTall(0)
	end

	category:SetContents(form)

	local before, seen = form:GetChildren() or {}, {}

	for _, ch in ipairs(before) do
		seen[ch] = true
	end

	buildFn(form)

	local created = {}

	for _, ch in ipairs(form:GetChildren() or {}) do
		if !seen[ch] then table.insert(created, ch) end
	end

	return form, category, created

end

hook.Add("PopulateToolMenu", "GStormsOptionsLoad", function()

	spawnmenu.AddToolMenuOption("GStorms", "01_gstorms_settings", "GStorms_General", "#gstorms_menu_settings_general", "", "", function(panel)

		GSAddCollapsibleSection(panel, "General Settings", true, function(option)

			local resetButton = option:Button("Reset To Defaults")
			resetButton:SetTooltip("Resets all configuration options to their defaults [Must be an admin]")
			resetButton.DoClick = function()

				local canEdit, ply = CanEditAdminConvars()

				if !IsValid(ply) then return end
				if !canEdit then GSTipToClient(ply, "You Need To Be An Admin To Reset All Convars") return end

				net.Start("gs_reset_convars")
				net.SendToServer()

			end

			GSAddCollapsibleSection(panel, "Resource Packs", true, function(option)
				GSBuildParticlePackDropdown(option)
			end)

			GSCheckBox(option, "Enable Fahrenheit", "gstorms_general_fahrenheit"):SetTooltip("Switches celsius readings over to fahrenheit [gstorms_general_fahrenheit]")

		end)

	end)

	spawnmenu.AddToolMenuOption("GStorms", "01_gstorms_settings", "GStorms_Performance", "#gstorms_menu_settings_performance", "", "", function(panel)

		GSAddCollapsibleSection(panel, "Performance", true, function(option)

			local selectedPreset = 0
			local presetDropdown = vgui.Create("DComboBox")

			presetDropdown:SetSortItems(false)
			presetDropdown:SetValue("Select Quality Preset")
			presetDropdown:SetTooltip("Applies a quality preset [Must be an admin]")
			presetDropdown:AddChoice("Low Settings", 1)
			presetDropdown:AddChoice("Default Settings", 2)
			presetDropdown:AddChoice("Ultra High (Performance Intensive)", 3)

			presetDropdown.OnSelect = function(self, index, value, data)
				selectedPreset = math.Clamp(tonumber(data or index) or 0, 1, 3)
			end

			option:AddItem(presetDropdown)

			local applyPresetButton = option:Button("Apply Quality Preset")
			applyPresetButton:SetTooltip("Applies the selected quality preset [Must be an admin]")
			applyPresetButton.DoClick = function()

				local canEdit, ply = CanEditAdminConvars()

				if !IsValid(ply) then return end
				if !canEdit then GSTipToClient(ply, "You Need To Be An Admin To Apply Presets") return end

				selectedPreset = math.Clamp(tonumber(selectedPreset) or 0, 0, 3)

				if selectedPreset <= 0 then GSTipToClient(ply, "You Need To Select A Preset First") return end

				net.Start("gs_convar_preset_set")
				net.WriteUInt(selectedPreset, 8)
				net.SendToServer()

			end

			GSNumSlider(option, "Particle Amount", "gstorms_perf_particle_amount", 0.5, 1.0, 1):SetTooltip("The global particle amount multiplier, lower for better particle performance but less stunning visuals [gstorms_perf_particle_amount]")

		end)

		GSAddCollapsibleSection(panel, "Compatibility", true, function(option)

			GSCheckBox(option, "Enable Fog Modifications", "gstorms_compat_fog_modifications"):SetTooltip("Modifies world and skybox fog, turn this off if needed for compatibility purposes [gstorms_compat_fog_modifications]")
			GSCheckBox(option, "Enable Skybox Modifications", "gstorms_compat_skybox_modifications"):SetTooltip("Modifies the skybox, turn this off if needed for compatibility purposes [REQUIRES RESTART] [gstorms_compat_skybox_modifications]")
			GSCheckBox(option, "Enable Ground Modifications", "gstorms_compat_ground_modifications"):SetTooltip("Modifies the ground when snowing, turn this off if needed for compatibility purposes [gstorms_compat_ground_modifications]")

		end)

	end)

	spawnmenu.AddToolMenuOption("GStorms", "01_gstorms_settings", "GStorms_Simulation", "#gstorms_menu_settings_simulation", "", "", function(panel)

		GSAddCollapsibleSection(panel, "Simulation Settings", true, function(option)
			GSCheckBox(option, "Enable Unwelding", "gstorms_sim_unweld_props"):SetTooltip("Unwelds props, turning this off may save performance in regards to duplications [gstorms_sim_unweld_props]")
			GSCheckBox(option, "Enable Player Damage", "gstorms_sim_hurt_players"):SetTooltip("Entities damage players & NPCs [gstorms_sim_hurt_players]")
			GSCheckBox(option, "Enable Granulation", "gstorms_sim_granulation"):SetTooltip("Damages props at very high wind speeds [gstorms_sim_granulation]")
			GSCheckBox(option, "Enable Ambient Wind", "gstorms_sim_ambient_wind"):SetTooltip("This can lag with lots of props even if there are no weather entities present, turn this off for passive performance [gstorms_sim_ambient_wind]")
			GSCheckBox(option, "Enable Directional Wind Occlusion & Wind Tunneling", "gstorms_sim_wind_occlusion"):SetTooltip("Props will block wind, realistic but performance intensive with lots of props [gstorms_sim_wind_occlusion]")
		end)

		GSAddCollapsibleSection(panel, "Entity Settings", true, function(option)
			GSCheckBox(option, "Enable Touchdowns & Strengthening", "gstorms_sim_strengthening"):SetTooltip("Static entities will strengthen and static tornadoes will touch down and lift (does not affect dynamic entities) [gstorms_sim_strengthening]")
			GSCheckBox(option, "Enable Player Targeting", "gstorms_sim_aim_at_players"):SetTooltip("Aims the entity at the player when it's spawned [gstorms_sim_aim_at_players]")
			GSCheckBox(option, "Enable Random Spawn Position", "gstorms_sim_spawn_random_position"):SetTooltip("Spawns the entity at a random position and distance away from the player [gstorms_sim_spawn_random_position]")
			GSNumSlider(option, "Movement Speed", "gstorms_sim_speed", 0, 5, 1):SetTooltip("The speed at which entities will move in the world [gstorms_sim_speed]")
			GSNumSlider(option, "Max Lifetime", "gstorms_sim_max_lifetime", 60, 600, 0):SetTooltip("Maximum lifetime for tornadoes in seconds, acts as a multiplier for shorter lived vortices such as dust devils [gstorms_sim_max_lifetime]")
		end)

		GSAddCollapsibleSection(panel, "Tornado Settings", true, function(option)
			GSCheckBox(option, "Enable Subvortices", "gstorms_tornado_subvortices"):SetTooltip("Simulates subvortices in tornadoes, slightly performance intensive [gstorms_tornado_subvortices]")
			GSCheckBox(option, "Enable Inflow Jet", "gstorms_tornado_inflow_jet"):SetTooltip("Creates an inflow jet on the back side of the tornado, slightly performance intensive [gstorms_tornado_inflow_jet]")
			GSCheckBox(option, "Enable Ground Scouring", "gstorms_tornado_ground_scouring"):SetTooltip("Subvortices will scour the ground, some maps may handle decals weird which is why this is optional [gstorms_tornado_ground_scouring]")
			GSCheckBox(option, "Enable Debris Clouds", "gstorms_tornado_debris_cloud"):SetTooltip("Enables debris clouds for tornadoes [gstorms_tornado_debris_cloud]")
		end)
	
		GSAddCollapsibleSection(panel, "Volcano Settings", true, function(option)
			GSCheckBox(option, "Enable Eruptions", "gstorms_volcano_eruptions"):SetTooltip("Volcanoes will erupt, if disabled, seismic activity can still be heard but no eruption will occur [gstorms_volcano_eruptions]")
			GSCheckBox(option, "Enable Pyroclastic Flow", "gstorms_volcano_pyroclastic_flow"):SetTooltip("Creates a cloud of ash (pyroclastic flow) that burns players and props [gstorms_volcano_pyroclastic_flow]")
			GSCheckBox(option, "Enable Rock Ejection", "gstorms_volcano_rock_ejection"):SetTooltip("When a volcano erupts, rocks and debris will be ejected outwards from the explosion [gstorms_volcano_rock_ejection]")
		end)

		GSAddCollapsibleSection(panel, "Earthquake Settings", true, function(option)
			GSCheckBox(option, "Enable Aftershocks", "gstorms_earthquake_aftershocks"):SetTooltip("Enables random aftershocks after the initial large shock [gstorms_earthquake_aftershocks]")
		end)
	
		GSAddCollapsibleSection(panel, "Radio Settings", true, function(option)
			GSCheckBox(option, "Do Not Tick This Box", "gstorms_radio_easteregg"):SetTooltip("This TOTALLY does nothing and isn't important whatsoever [gstorms_radio_easteregg]")
		end)

	end)

	spawnmenu.AddToolMenuOption("GStorms", "01_gstorms_settings", "GStorms_Environment", "#gstorms_menu_settings_environment", "", "", function(panel)

		GSAddCollapsibleSection(panel, "Time Controls", true, function(option)
			GSCheckBox(option, "Pause Day", "gstorms_env_pause_day"):SetTooltip("Pauses the day and prevents time from updating [gstorms_env_pause_day]")
			GSNumSlider(option, "Day Length", "gstorms_env_day_length", 720, 2880, 0):SetTooltip("Day cycle length in seconds [gstorms_env_day_length]")
			GSNumSlider(option, "Set Time To", "gstorms_env_set_time", 0, 24, 0):SetTooltip("The time of day (24 hour clock) to set the time to [gstorms_env_set_time]")

			local setTime = option:Button("Set Time")
			setTime:SetTooltip("Sets the time to the 'Set Time To' value.")
			setTime.DoClick = function()

				local canEdit, ply = CanEditAdminConvars()
				if !IsValid(ply) then return end

				if !canEdit then GSTipToClient(ply, "You Need To Be An Admin To Do That") return end

				GSSetAdminConVar("gstorms_env_time_set", "false")
			end

		end)

		GSAddCollapsibleSection(panel, "Weather Effects", true, function(option)

			GSCheckBox(option, "Enable Rain / Snow", "gstorms_env_rain"):SetTooltip("Enables rain for entities [gstorms_env_rain]")
			GSCheckBox(option, "Enable Lightning", "gstorms_env_lightning"):SetTooltip("Enables lightning for entities [gstorms_env_lightning]")
			GSCheckBox(option, "Enable Hail", "gstorms_env_hail"):SetTooltip("Enables hailstones for entities [gstorms_env_hail]")
			GSCheckBox(option, "Enable Clouds", "gstorms_env_clouds"):SetTooltip("Enables ambient world clouds, turning this off may help with particle lag [gstorms_env_clouds]")

		end)

		GSAddCollapsibleSection(panel, "Environment Overrides", true, function(option)

			GSCheckBox(option, "Ambient Temperature Override", "gstorms_env_ambient_temperature_override"):SetTooltip("Overrides the automatically controlled ambient temperature [gstorms_env_ambient_temperature_override]")
			GSNumSlider(option, "Ambient Temperature", "gstorms_env_ambient_temperature", -30, 100, 0):SetTooltip("If ambient temperature override is enabled, this value will be set (in celsius) [gstorms_env_ambient_temperature]")

			GSCheckBox(option, "Ambient Windspeed Override", "gstorms_env_ambient_windspeed_override"):SetTooltip("Overrides the automatically controlled ambient windspeed [gstorms_env_ambient_windspeed_override]")
			GSNumSlider(option, "Ambient Windspeed", "gstorms_env_ambient_windspeed", 0, 100, 0):SetTooltip("If ambient windspeed override is enabled, this value will be set (in MPH) [gstorms_env_ambient_windspeed]")

		end)

	end)

	spawnmenu.AddToolMenuOption("GStorms", "01_gstorms_settings", "GStorms_Audio_Visual", "#gstorms_menu_settings_audio_visual", "", "", function(panel)

		GSAddCollapsibleSection(panel, "Audio & Visual Settings", true, function(option)
			GSCheckBox(option, "Enable Reactive Sounds", "gstorms_av_reactive_sounds"):SetTooltip("Reactive audio if the player is in a vehicle or if wind occlusion is enabled [gstorms_av_reactive_sounds]")
			GSCheckBox(option, "Enable Custom Screen Shake", "gstorms_av_custom_screenshake"):SetTooltip("The screen will shake if winds are strong [gstorms_av_custom_screenshake]")
			GSCheckBox(option, "Enable Post Processing", "gstorms_av_post_processing"):SetTooltip("Post processing effects for debris and condensation [gstorms_av_post_processing]")
			GSCheckBox(option, "Enable Powerflashes", "gstorms_av_powerflashes"):SetTooltip("Props with pole_, lamppost, power, transformer or utilitypole in their name will trigger a powerflash [gstorms_av_powerflashes]")
			GSCheckBox(option, "Enable Mud Coating", "gstorms_av_mud_coating"):SetTooltip("Props will change their material if the tornado is filled with dirt or mud [gstorms_av_mud_coating]")
		end)

		GSAddCollapsibleSection(panel, "Diagnostics & Windfield Visualization", false, function(option)
			GSCheckBox(option, "Enable Windfield Rendering", "gstorms_av_windfield_rendering"):SetTooltip("Renders the windfield of the entity [gstorms_av_windfield_rendering]")

			local res = GSNumSlider(option, "Windfield Resolution", "gstorms_av_windfield_resolution", 8, 144, 0)
			res:SetDecimals(0)
			res.OnValueChanged = function(self, v)
				local snapToVal = math.Round(v / 8) * 8
				if snapToVal ~= self:GetValue() then self:SetValue(snapToVal) end
			end

			GSNumSlider(option, "Windfield Update Rate (Seconds)", "gstorms_av_windfield_update_rate", 0.5, 5, 1)
			GSNumSlider(option, "Windfield Sample Height", "gstorms_av_windfield_sample_height", 10, 7000, 1)

			GSCheckBox(option, "Enable Storm Winds", "gstorms_av_windfield_storm_winds"):SetTooltip("Shows storm winds from all sources, not just the target entity [gstorms_av_windfield_storm_winds]")
			GSCheckBox(option, "Enable Velocity Mode", "gstorms_av_windfield_use_velocity"):SetTooltip("Player position based relative velocity (like a radar station) [gstorms_av_windfield_use_velocity]")
			GSCheckBox(option, "Enable Wind Vectors", "gstorms_av_windfield_wind_vectors"):SetTooltip("Renders wind vectors to show wind direction at a given point [gstorms_av_windfield_wind_vectors]")
		end)

	end)

	spawnmenu.AddToolMenuOption("GStorms", "02_gstorms_autospawn", "GStorms_Autospawn_Main", "#gstorms_menu_autospawn_main", "", "", function(panel)

		GSAddCollapsibleSection(panel, "Control Settings", true, function(option)

			GSCheckBox(option, "Enable Autospawn", "gstorms_autospawn"):SetTooltip("Enables Autospawn [gstorms_autospawn]")

			local rerollButton = option:Button("Reroll Outlooks")
			rerollButton:SetTooltip("Rerolls all outlooks for autospawn [Must be an admin]")
			rerollButton.DoClick = function()

				local canEdit, ply = CanEditAdminConvars()

				if !IsValid(ply) then return end
				if !canEdit then GSTipToClient(ply, "You Need To Be An Admin To Reroll Outlooks") return end

				net.Start("gs_reroll_outlooks")
				net.SendToServer()
			end

			GSNumSlider(option, "Season Length (Days)", "gstorms_autospawn_season_length", 1, 91, 0):SetTooltip("The length of each season in days [gstorms_autospawn_season_length]")

			GSCheckBox(option, "Enable Spring", "gstorms_autospawn_spring"):SetTooltip("Enables spring in the seasonal cycle, if no seasons are enabled it will default to spring [gstorms_autospawn_spring]")
			GSCheckBox(option, "Enable Summer", "gstorms_autospawn_summer"):SetTooltip("Enables summer in the seasonal cycle, if no seasons are enabled it will default to spring [gstorms_autospawn_summer]")
			GSCheckBox(option, "Enable Fall", "gstorms_autospawn_fall"):SetTooltip("Enables fall in the seasonal cycle, if no seasons are enabled it will default to spring [gstorms_autospawn_fall]")
			GSCheckBox(option, "Enable Winter", "gstorms_autospawn_winter"):SetTooltip("Enables winter in the seasonal cycle, if no seasons are enabled it will default to spring [gstorms_autospawn_winter]")

			local selectedSeasonIndex = 2

			local seasonDropdown = vgui.Create("DComboBox")
			seasonDropdown:SetSortItems(false)
			seasonDropdown:SetValue("Spring")
			seasonDropdown:SetTooltip("Selects which season to snap the autospawn cycle to [Must be an admin]")
			seasonDropdown:AddChoice("Winter", 1)
			seasonDropdown:AddChoice("Spring", 2)
			seasonDropdown:AddChoice("Summer", 3)
			seasonDropdown:AddChoice("Fall", 4)
			
			seasonDropdown.OnSelect = function(_, _, _, data)
				selectedSeasonIndex = math.Clamp(tonumber(data) or 2, 1, 4)
			end
			
			option:AddItem(seasonDropdown)
			
			local setSeason = option:Button("Apply Season")
			setSeason:SetTooltip("Sets the current season to the middle of the selected season [Must be an admin]")
			setSeason.DoClick = function()
			
				local canEdit, ply = CanEditAdminConvars()

				if !IsValid(ply) then return end
				if !canEdit then GSTipToClient(ply, "You Need To Be An Admin To Do That") return end
			
				net.Start("gs_set_season")
				net.WriteUInt(selectedSeasonIndex, 3)
				net.SendToServer()
			
			end

		end)

	end)

	spawnmenu.AddToolMenuOption("GStorms", "02_gstorms_autospawn", "GStorms_Autospawn_Tuning", "#gstorms_menu_autospawn_tuning", "", "", function(panel)

		GSAddCollapsibleSection(panel, "General Spawn Tuning", true, function(option)

			GSNumSlider(option, "Formation Chance", "gstorms_autospawn_formation_chance", 0.1, 4, 2):SetTooltip("The chance of anything spawning after x seconds (general multiplier for autospawn) [gstorms_autospawn_formation_chance]")
			GSNumSlider(option, "Severe Weather Chance", "gstorms_autospawn_severe_weather_chance", 1, 99, 0):SetTooltip("The favour for high risk days, higher is more severe weather days [gstorms_autospawn_severe_weather_chance]")

		end)

		GSAddCollapsibleSection(panel, "Phenomena Toggles & Frequencies", true, function(option)

			GSCheckBox(option, "Enable Thunderstorms", "gstorms_autospawn_thunderstorm"):SetTooltip("Enables thunderstorm autospawning [gstorms_autospawn_thunderstorm]")
			GSNumSlider(option, "Thunderstorm Frequency", "gstorms_autospawn_frequency_thunderstorm", 0.1, 1, 2):SetTooltip("How often thunderstorm dominant days occur (0.1 = rare, 1 = common) [gstorms_autospawn_frequency_thunderstorm]")

			GSCheckBox(option, "Enable Tornadoes", "gstorms_autospawn_tornado"):SetTooltip("Enables tornado autospawning [gstorms_autospawn_tornado]")
			GSNumSlider(option, "Tornado Frequency", "gstorms_autospawn_frequency_tornado", 0.1, 1, 2):SetTooltip("How often tornado dominant days occur (0.1 = rare, 1 = common) [gstorms_autospawn_frequency_tornado]")

			GSCheckBox(option, "Enable Landspouts", "gstorms_autospawn_landspout"):SetTooltip("Enables landspout autospawning [gstorms_autospawn_landspout]")
			GSNumSlider(option, "Landspout Frequency", "gstorms_autospawn_frequency_landspout", 0.1, 1, 2):SetTooltip("How often landspout dominant days occur (0.1 = rare, 1 = common) [gstorms_autospawn_frequency_landspout]")

			GSCheckBox(option, "Enable Derechos", "gstorms_autospawn_derecho"):SetTooltip("Enables derecho autospawning [gstorms_autospawn_derecho]")
			GSNumSlider(option, "Derecho Frequency", "gstorms_autospawn_frequency_derecho", 0.1, 1, 2):SetTooltip("How often derecho dominant days occur (0.1 = rare, 1 = common) [gstorms_autospawn_frequency_derecho]")

			GSCheckBox(option, "Enable Hurricanes", "gstorms_autospawn_hurricane"):SetTooltip("Enables hurricane autospawning [gstorms_autospawn_hurricane]")
			GSNumSlider(option, "Hurricane Frequency", "gstorms_autospawn_frequency_hurricane", 0.1, 1, 2):SetTooltip("How often hurricane dominant days occur (0.1 = rare, 1 = common) [gstorms_autospawn_frequency_hurricane]")

			GSCheckBox(option, "Enable Waterspouts", "gstorms_autospawn_waterspout"):SetTooltip("Enables waterspout autospawning [gstorms_autospawn_waterspout]")
			GSNumSlider(option, "Waterspout Frequency", "gstorms_autospawn_frequency_waterspout", 0.1, 1, 2):SetTooltip("How often waterspout dominant days occur (0.1 = rare, 1 = common) [gstorms_autospawn_frequency_waterspout]")

			GSCheckBox(option, "Enable Rainstorms", "gstorms_autospawn_rainstorm"):SetTooltip("Enables rainstorm autospawning [gstorms_autospawn_rainstorm]")
			GSNumSlider(option, "Rainstorm Frequency", "gstorms_autospawn_frequency_rainstorm", 0.1, 1, 2):SetTooltip("How often rainstorm dominant days occur (0.1 = rare, 1 = common) [gstorms_autospawn_frequency_rainstorm]")

			GSCheckBox(option, "Enable Sandstorms", "gstorms_autospawn_sandstorm"):SetTooltip("Enables sandstorm autospawning [gstorms_autospawn_sandstorm]")
			GSNumSlider(option, "Sandstorm Frequency", "gstorms_autospawn_frequency_sandstorm", 0.1, 1, 2):SetTooltip("How often sandstorm dominant days occur (0.1 = rare, 1 = common) [gstorms_autospawn_frequency_sandstorm]")

			GSCheckBox(option, "Enable Dust Devils", "gstorms_autospawn_dustdevil"):SetTooltip("Enables dust devil autospawning [gstorms_autospawn_dustdevil]")
			GSNumSlider(option, "Dust Devil Frequency", "gstorms_autospawn_frequency_dustdevil", 0.1, 1, 2):SetTooltip("How often dust devil dominant days occur (0.1 = rare, 1 = common) [gstorms_autospawn_frequency_dustdevil]")

			GSCheckBox(option, "Enable Earthquakes", "gstorms_autospawn_earthquake"):SetTooltip("Enables earthquake autospawning [gstorms_autospawn_earthquakes]")
			GSNumSlider(option, "Earthquake Min Frequency", "gstorms_autospawn_min_frequency_earthquakes", 720, 72000, 0):SetTooltip("The minimum amount of time between earthquakes in seconds [gstorms_autospawn_min_frequency_earthquakes]")
			GSNumSlider(option, "Earthquake Max Frequency", "gstorms_autospawn_max_frequency_earthquakes", 720, 72000, 0):SetTooltip("The maximum amount of time between earthquakes in seconds [gstorms_autospawn_max_frequency_earthquakes]")
			GSNumSlider(option, "Earthquake Min Magnitude", "gstorms_autospawn_earthquake_min_strength", 1, 9, 0):SetTooltip("The minimum magnitude of the autospawned earthquake [gstorms_autospawn_earthquake_min_strength]")
			GSNumSlider(option, "Earthquake Max Magnitude", "gstorms_autospawn_earthquake_max_strength", 1, 9, 0):SetTooltip("The maximum magnitude of the autospawned earthquake [gstorms_autospawn_earthquake_max_strength]")

		end)

	end)

end)