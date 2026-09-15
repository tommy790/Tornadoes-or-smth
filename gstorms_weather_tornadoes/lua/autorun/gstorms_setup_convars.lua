include("gstorms_funcs/gstorms_shared.lua")

local convars = {
    {name = "gstorms_sim_speed", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_tornado_subvortices", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_tornado_inflow_jet", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_sim_wind_occlusion", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_sim_granulation", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_av_mud_coating", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_sim_strengthening", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_env_rain", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_env_hail", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_env_lightning", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_sim_hurt_players", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_av_powerflashes", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_av_windfield_wind_vectors", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_sim_max_lifetime", default = "300", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_env_time_set", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_volcano_pyroclastic_flow", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_volcano_rock_ejection", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_volcano_eruptions", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_earthquake_aftershocks", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_tornado_ground_scouring", default = "1", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_radio_easteregg", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_sim_unweld_props", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_sim_aim_at_players", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_sim_spawn_random_position", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_general_fahrenheit", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},

    {name = "gstorms_env_day_length", default = "1440", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_env_set_time", default = "7.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_env_pause_day", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_env_ambient_windspeed", default = "20", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_env_ambient_temperature", default = "20", flags = FCVAR_REPLICATED, adminOnly = true},

    {name = "gstorms_autospawn_season_length", default = "10", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_winter", default = "1", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_summer", default = "1", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_fall", default = "1", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_spring", default = "1", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_severe_weather_chance", default = "50", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_formation_chance", default = "1", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_frequency_sandstorm", default = "0.9", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_frequency_dustdevil", default = "1", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_frequency_rainstorm", default = "1", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_frequency_thunderstorm", default = "1", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_frequency_landspout", default = "0.65", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_frequency_waterspout", default = "0.95", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_frequency_derecho", default = "0.8", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_frequency_tornado", default = "0.85", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_frequency_hurricane", default = "0.5", flags = FCVAR_REPLICATED, adminOnly = true},

    {name = "gstorms_autospawn_min_frequency_earthquakes", default = "1440", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_max_frequency_earthquakes", default = "43200", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_earthquake_min_strength", default = "1", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_earthquake_max_strength", default = "9", flags = FCVAR_REPLICATED, adminOnly = true},

    {name = "gstorms_autospawn_sandstorm", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_dustdevil", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_rainstorm", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_thunderstorm", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_landspout", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_waterspout", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_derecho", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_tornado", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_hurricane", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_autospawn_earthquake", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},

    {name = "gstorms_env_ambient_windspeed_override", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_env_ambient_temperature_override", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_sim_ambient_wind", default = "0.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_env_clouds", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_compat_fog_modifications", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_compat_skybox_modifications", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_compat_ground_modifications", default = "1.0", flags = FCVAR_REPLICATED, adminOnly = true},
    {name = "gstorms_particle_texture", default = "GStorms: Default Resource Pack", flags = FCVAR_REPLICATED, adminOnly = true},

    {name = "gstorms_av_reactive_sounds", default = "1.0", flags = FCVAR_LUA_CLIENT, adminOnly = false},
    {name = "gstorms_av_windfield_rendering", default = "0.0", flags = FCVAR_LUA_CLIENT, adminOnly = true},
    {name = "gstorms_av_windfield_resolution", default = "48", flags = FCVAR_LUA_CLIENT, adminOnly = true},
    {name = "gstorms_av_windfield_sample_height", default = "10", flags = FCVAR_LUA_CLIENT, adminOnly = true},
    {name = "gstorms_av_windfield_update_rate", default = "1.0", flags = FCVAR_LUA_CLIENT, adminOnly = true},
    {name = "gstorms_av_windfield_use_velocity", default = "0.0", flags = FCVAR_LUA_CLIENT, adminOnly = true},
    {name = "gstorms_av_windfield_storm_winds", default = "1.0", flags = FCVAR_LUA_CLIENT, adminOnly = true},
    {name = "gstorms_av_custom_screenshake", default = "1.0", flags = FCVAR_LUA_CLIENT, adminOnly = false},
    {name = "gstorms_av_post_processing", default = "1.0", flags = FCVAR_LUA_CLIENT, adminOnly = false},
    {name = "gstorms_perf_particle_amount", default = "1.0", flags = FCVAR_LUA_CLIENT, adminOnly = false},
    {name = "gstorms_tornado_debris_cloud", default = "1.0", flags = FCVAR_LUA_CLIENT, adminOnly = false},
}

for _, c in ipairs(convars) do CreateConVar(c.name, c.default, bit.bor(FCVAR_ARCHIVE, c.flags or 0), "GStorms Convar") end

function GStormsGetConvar() return convars end

local function GStormsResetConvarsToDefaults()
    for _, convar in ipairs(convars) do
        RunConsoleCommand(convar.name, convar.default)
    end
end

local convarPresets = {
    { -- Low Settings
        {name = "gstorms_tornado_subvortices", valueToSet = "0.0"},
        {name = "gstorms_tornado_inflow_jet", valueToSet = "0.0"},
        {name = "gstorms_sim_wind_occlusion", valueToSet = "0.0"},
        {name = "gstorms_sim_granulation", valueToSet = "0.0"},
        {name = "gstorms_av_mud_coating", valueToSet = "0.0"},
        {name = "gstorms_sim_ambient_wind", valueToSet = "0.0"},
        {name = "gstorms_tornado_debris_cloud", valueToSet = "0.0"},
        {name = "gstorms_sim_unweld_props", valueToSet = "0.0"},
        {name = "gstorms_perf_particle_amount", valueToSet = "0.75"},
    },
    { -- Default Settings
        {name = "gstorms_tornado_subvortices", valueToSet = "1.0"},
        {name = "gstorms_tornado_inflow_jet", valueToSet = "1.0"},
        {name = "gstorms_sim_wind_occlusion", valueToSet = "0.0"},
        {name = "gstorms_sim_granulation", valueToSet = "0.0"},
        {name = "gstorms_av_mud_coating", valueToSet = "1.0"},
        {name = "gstorms_sim_ambient_wind", valueToSet = "0.0"},
        {name = "gstorms_tornado_debris_cloud", valueToSet = "1.0"},
        {name = "gstorms_sim_unweld_props", valueToSet = "1.0"},
        {name = "gstorms_perf_particle_amount", valueToSet = "1.0"},
    },
    { -- Ultra high (Performance Intensive)
        {name = "gstorms_tornado_subvortices", valueToSet = "1.0"},
        {name = "gstorms_tornado_inflow_jet", valueToSet = "1.0"},
        {name = "gstorms_sim_wind_occlusion", valueToSet = "1.0"},
        {name = "gstorms_sim_granulation", valueToSet = "0.0"},
        {name = "gstorms_av_mud_coating", valueToSet = "1.0"},
        {name = "gstorms_sim_ambient_wind", valueToSet = "1.0"},
        {name = "gstorms_tornado_debris_cloud", valueToSet = "1.0"},
        {name = "gstorms_sim_unweld_props", valueToSet = "1.0"},
        {name = "gstorms_perf_particle_amount", valueToSet = "1.0"},
    },
}

if SERVER then
    net.Receive("gs_reset_convars", function(len, ply)
        if !ply:IsValid() then return end
        if !ply:IsAdmin() then return end
        GStormsResetConvarsToDefaults()
    end)

    net.Receive("gs_convar_preset_set", function(len, ply)

        if !ply:IsValid() or !ply:IsAdmin() then 
            if ply:IsValid() then GSTipToClient(ply, "You Need To Be An Admin To Do That") end
            return 
        end

        local index = net.ReadUInt(8)
        local preset = convarPresets[index]

        if !preset then return end

        for _, convar in ipairs(preset) do

            if !convar or !convar.name or convar.valueToSet == nil then continue end

            if GetConVar(convar.name) then
                RunConsoleCommand(convar.name, tostring(convar.valueToSet))
            end

        end

    end)

    -- For Admin Only Convars

    local gsAdminCvarAllow = {}

    for i = 1, #convars do
        local c = convars[i]
        if c.adminOnly and bit.band(c.flags or 0, FCVAR_LUA_CLIENT) == 0 then gsAdminCvarAllow[c.name] = true end
    end

    local function GSCanEditGStormsConvars(ply) return !IsValid(ply) or ply:IsAdmin() end

    concommand.Add("gstorms_set_admin_cvar", function(ply, cmd, args)
        if !GSCanEditGStormsConvars(ply) then return end

        local name = args[1]
        if !name or !gsAdminCvarAllow[name] then return end

        local value = args[2] or ""
        local cvar = GetConVar(name)
        if !cvar then return end

        cvar:SetString(value)
    end)

end