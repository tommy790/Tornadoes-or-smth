AddCSLuaFile()

local shibe = {
    "particles/RDTornadoes.pcf",
    "particles/RDExplosions.pcf",
    "particles/RDWeather.pcf",
    "particles/astralparticles.pcf", "particles/astralspaceparticles.pcf",
    "particles/Tempest_dustgust.pcf", "particles/Tempest_GMSC.pcf", "particles/trt_ResearchRescue.pcf", "particles/trt_tornadoes_a.pcf", "particles/Tempest_IntoTheStorm.pcf", "particles/Tempest_TwisterMovie.pcf", "particles/Tempest_GMSC.pcf", "particles/trt_jc4.pcf", "particles/trt_tornadoes_a.pcf", "particles/trt_Real_Tornadoes.pcf", "particles/trt_sharknadoes.pcf","particles/Tempest_Minecraft.pcf","particles/Tempest_El_Grande.pcf",
    "particles/realistictwisters.pcf",
    "particles/realistictwisters2.pcf", 
    "particles/xt2_cad.pcf", 
    "particles/xt2tornadoes_poison.pcf", 
    "particles/turbulent_tornadoes_01.pcf", "particles/turbulent_tornadoes_02.pcf", "particles/turbulent_tornadoes_03.pcf",  "particles/turbulent_tornadoes_04.pcf", "particles/turbulent_tornadoes_05.pcf",  "particles/turbulent_tornadoes_06.pcf",  "particles/turbulent_tornadoes_07.pcf",  "particles/turbulent_tornadoes_08.pcf",  "particles/turbulent_tornadoes_09.pcf",  "particles/turbulent_tornadoes_10.pcf",  "particles/turbulent_tornadoes_11.pcf",  "particles/turbulent_tornadoes_12.pcf",  "particles/turbulent_tornadoes_13.pcf",  "particles/turbulent_tornadoes_14.pcf", 
    "particles/f0_tornado.pcf", "particles/f1_tornado.pcf", "particles/f2_tornado.pcf", "particles/f3_tornado.pcf", "particles/f4_tornado.pcf", "particles/f5_tornado.pcf", "particles/f2_tornado_b.pcf", "particles/f3_tornado_b.pcf", "particles/f4_tornado_b.pcf",
    "particles/csc.pcf","particles/csc_pack.pcf","particles/ef4_good.pcf",
    "particles/FF_Rope_EF0_a1.pcf",
    "particles/Error-nado.pcf",
    "particles/toreffect.pcf"
}

for k, v in ipairs(shibe) do

    game.AddParticles(v)

    print(v)

end