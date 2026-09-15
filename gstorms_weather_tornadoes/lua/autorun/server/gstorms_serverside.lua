if CLIENT then return end

math.randomseed(os.time()) -- Random Seed for math.random

util.AddNetworkString("gs_send_tip")
util.AddNetworkString("gs_start_particle_effect")
util.AddNetworkString("gs_send_ground_data_on_server_load")
util.AddNetworkString("gs_probe_toggle")
util.AddNetworkString("gs_probe_reset")
util.AddNetworkString("gs_reset_convars")
util.AddNetworkString("gs_thermometer_reset")
util.AddNetworkString("gs_send_outlooktable")
util.AddNetworkString("gs_reroll_outlooks")
util.AddNetworkString("gs_timetable_to_clients")
util.AddNetworkString("gs_probe_deploy_tip")
util.AddNetworkString("gs_convar_preset_set")
util.AddNetworkString("gs_particle_pack_set")
util.AddNetworkString("gs_particle_pack_sync")
util.AddNetworkString("gs_spawn_entity")
util.AddNetworkString("gs_api_sync_sky")
util.AddNetworkString("gs_set_season")
util.AddNetworkString("gs_computer_use")
util.AddNetworkString("gs_pathing_tool_path_sync")
util.AddNetworkString("gs_pathing_tool_path_set")
util.AddNetworkString("gs_pathing_tool_path_update")
util.AddNetworkString("gs_pathing_tool_preview_flash")
util.AddNetworkString("gs_wind_resistance_copy")
util.AddNetworkString("gs_spike_sound")
util.AddNetworkString("gs_hailstone_damage")

local gsDefaultPack = "GStorms: Default Resource Pack"
local gsParticlePackCvar = GetConVar("gstorms_particle_texture")

local function GSGetServerPackName() return gsParticlePackCvar and gsParticlePackCvar:GetString() or gsDefaultPack end
local function GSIsAllowedToSetPack(ply) return ply:IsValid() and ply:IsAdmin() end

local function GSApplyPackToEntities(packName, reroll)
	if !gs_weatherEntityList.server then return end

	for _, ent in ipairs(gs_weatherEntityList.server) do
		if !ent:IsValid() then continue end
		if !ent.GSInitParticleSelection then continue end
		ent:GSInitParticleSelection(packName, reroll)
	end
end

local function GSSetServerPackName(packName, reroll)
	if gsParticlePackCvar then gsParticlePackCvar:SetString(packName) end

	GSApplyPackToEntities(packName, reroll)

	net.Start("gs_particle_pack_sync")
	net.WriteString(packName)
	net.Broadcast()
end

net.Receive("gs_particle_pack_set", function(_, ply)

	if !GSIsAllowedToSetPack(ply) then return end

	local packName = net.ReadString() or ""
	packName = string.Trim(packName)
	GSSetServerPackName(packName, true)

end)

hook.Add("PlayerInitialSpawn", "GS_ParticlePackSyncOnJoin", function(ply)
	timer.Simple(0, function()
		if !IsValid(ply) then return end
		net.Start("gs_particle_pack_sync")
		net.WriteString(GSGetServerPackName())
		net.Send(ply)
	end)
end)

hook.Add("PlayerSpawn", "GS_ExtinguishOnSpawn", function(ply)
	if !ply:IsValid() then return end

	ply:Extinguish()

	local rag = ply:GetRagdollEntity()
	if rag:IsValid() then rag:Extinguish() end

	for _, child in ipairs(ply:GetChildren()) do if child:IsValid() then child:Extinguish() end end
end)