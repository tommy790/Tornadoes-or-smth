AddCSLuaFile()

local convars = {
    {name = "xt2_updatethermosrate", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_derechochance", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_hailstormchance", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_enablext2chatcommands", default = "false", flags = FCVAR_GAMEDLL},
    {name = "xt2_highcapeeventchance", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_outbreakeventchance", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_vtpcommonality", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_enableevents", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_autospawnweather", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_autospawntornadoes", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_printrisklevel", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_autospawnwhirlwinds", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_stormchance", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_rainstormchance", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_tornadochance", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_whirlwindchance", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_t_lifetime_autospawn", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_s_lifetime_autospawn", default = "5.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_noriskchance", default = "10.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_xspeed", default = "1.0", flags = FCVAR_GAMEDLL},
    {name = "xt2_screenshake", default = "true", flags = FCVAR_LUA_CLIENT},
    {name = "xt2_tlifetime", default = "400", flags = FCVAR_GAMEDLL},
    {name = "xt2_antilag", default = "1", flags = FCVAR_GAMEDLL},
    {name = "xt2_arcadesounds", default = "1", flags = FCVAR_LUA_CLIENT},
    {name = "xt2_customskyboxes", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_lightningintornadoes", default = "1", flags = FCVAR_GAMEDLL},
    {name = "xt2_subvorts", default = "1", flags = FCVAR_GAMEDLL},
    {name = "xt2_subscour", default = "1", flags = FCVAR_GAMEDLL},
    {name = "xt2_rfdsimulation", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_windblockedbyobjects", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_hurtprops", default = "1", flags = FCVAR_GAMEDLL},
    {name = "xt2_unweldprops", default = "1", flags = FCVAR_GAMEDLL},
    {name = "xt2_sharknadochance", default = "5", flags = FCVAR_GAMEDLL},
    {name = "xt2_autospawnsharknadoes", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_f12chance", default = "5", flags = FCVAR_GAMEDLL},
    {name = "xt2_autospawnf12s", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_f35chance", default = "5", flags = FCVAR_GAMEDLL},
    {name = "xt2_autospawnf35s", default = "0", flags = FCVAR_GAMEDLL},
    {name = "xt2_debriseffect", default = "1", flags = FCVAR_LUA_CLIENT}
}

for _, convar in ipairs(convars) do
    if not ConVarExists(convar.name) then
        CreateConVar(convar.name, convar.default, bit.bor(FCVAR_ARCHIVE, (convar.flags) or 0), "xTwisters 2 Generated ConVar")
    end
end