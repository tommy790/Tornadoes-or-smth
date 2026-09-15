if SERVER then return end

include("gstorms_funcs/gstorms_post_processing.lua")
include("gstorms_funcs/gstorms_custom_screenshake.lua")

local nilVector = Vector(0, 0, 0)

hook.Add("Think", "GSEffectCleanup", function()

    local localPlayer = LocalPlayer()
    local gsFog = GSGetGSFog()
    local curTime = CurTime()

    if !localPlayer:IsValid() then return end

    if localPlayer.GSScreenshakeHookActive then

        local last = localPlayer.GSShakeLastCallTime or 0
        local idle = curTime - last

        if idle >= 0.25 or localPlayer.GSShakeTarget <= 0 then

            GSWindspeedScreenshake(localPlayer, 0, 0, 0, 0, 0, 0)
        
            localPlayer.GSShakeAmp = 0
            localPlayer.GSShakeFreq = 0
            localPlayer.GSShakePhase = localPlayer.GSShakePhase or localPlayer.GSShakeSeed or 0
            localPlayer.GSScreenshakeHookActive = false
        
        end

    end

    if gsFog.hooked then

        local last = localPlayer.GSPostProcessFogLastCallTime or 0
        local idle = curTime - last

        if idle >= 0.25 then

            GSSetPostProcessFog(localPlayer, nilVector, 0, 0, 0, false)

            gsFog.value = 0

            hook.Remove("RenderScreenspaceEffects", "GS_Custom_Fog_PostProcessing")

            gsFog.hooked = false

        end

    end

end)