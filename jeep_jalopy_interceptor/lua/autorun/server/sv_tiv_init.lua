-- ============================================================================
-- TIV SERVER INIT
-- ============================================================================
print("[TIV] Loading Tornado Intercept Vehicle v2...")

include("tiv/config/sh_config.lua")
AddCSLuaFile("tiv/config/sh_config.lua")
include("tiv/config/sv_runtime_cvars.lua")
AddCSLuaFile("tiv/config/cl_settings.lua")

include("tiv/wind/sv_wind.lua")
include("tiv/animation/sv_spike_anim.lua")
include("tiv/spikes/sv_spikes.lua")
include("tiv/anchor/sv_anchor.lua")
include("tiv/deploy/sv_deploy.lua")
include("tiv/loft/sv_loft.lua")
include("tiv/instruments/sv_instruments.lua")
include("tiv/wire/sv_wire.lua")

AddCSLuaFile("tiv/hud/cl_hud.lua")
AddCSLuaFile("tiv/instruments/cl_instruments.lua")
AddCSLuaFile("tiv/deploy/cl_deploy.lua")
AddCSLuaFile("tiv/animation/cl_spike_anim.lua")
AddCSLuaFile("tiv/wire/cl_wire.lua")
AddCSLuaFile("entities/gmod_wire_tiv_controller.lua")
AddCSLuaFile("entities/gmod_wire_expression2/core/custom/cl_tiv.lua")
AddCSLuaFile("wire/stools/tiv.lua")

print("[TIV] Server modules loaded!")