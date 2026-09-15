if SERVER then return end

include("gstorms_computer_applications/gstorms_app_beam.lua")
include("gstorms_computer_applications/gstorms_app_mesowatch.lua")
include("gstorms_computer_applications/gstorms_app_snek.lua")

function GSGetComputerApplications()
    return {
        {key = "Beam", icon = "computer/Beam.png", text = "Beam", factory = GSCreateBeamApp},
        {key = "MesoWatch", icon = "computer/MesoWatch.png", text = "MesoWatch", factory = GSCreateMesowatchApp},
        {key = "Snek", icon = "computer/Snek.png", text = "Snek", factory = GSCreateSnekApp}
    }
end

function GSGetComputerApplicationFactories()
    return {
        Beam = GSCreateBeamApp,
        MesoWatch = GSCreateMesowatchApp,
        Snek = GSCreateSnekApp
    }
end