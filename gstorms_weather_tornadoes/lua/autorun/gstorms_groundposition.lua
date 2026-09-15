gs_groundPositionFromServerLoad = {server = nil, client = nil}
gs_heightPositionFromServerLoad = {server = nil, client = nil}

if SERVER then

    local groundPositionFromServerLoadSet = false

    local function GetBestGroundAndBestHeight(pos, checkZMin, checkZMax, check2DMax, zStep, twoDimStep, traceHeightPerIter)

        local bestG, bestH, bestTraceRequired, bestSpan = nil, nil, nil, nil
        local traceDist = Vector(0, 0, traceHeightPerIter or 30000)

        for _, gridPos in ipairs(GSReturnListOfGridPositions(math.ceil(check2DMax / twoDimStep), pos, check2DMax, 0)) do

            for z = checkZMin, checkZMax, zStep do

                local p = Vector(gridPos.x, gridPos.y, z)

                local downTr = util.TraceLine({start = p, endpos = p - traceDist, mask = bit.bor(MASK_SOLID_BRUSHONLY, MASK_WATER)})
                if !downTr.Hit or !util.IsInWorld(downTr.HitPos) then continue end

                local upTr = util.TraceLine({start = p, endpos = p + traceDist, mask = MASK_SOLID_BRUSHONLY})
                if !(upTr.Hit or upTr.HitSky) or !util.IsInWorld(upTr.HitPos) then continue end

                local ground = downTr.HitPos
                local height = upTr.HitPos
                local span = height.z - ground.z
                if span <= 0 then continue end

                local upDist = math.abs(height.z - p.z)
                local downDist = math.abs(p.z - ground.z)
                local traceRequired = math.max(upDist, downDist)

                if !bestTraceRequired or traceRequired > bestTraceRequired or (traceRequired == bestTraceRequired and (!bestSpan or span > bestSpan)) then
                    bestTraceRequired, bestSpan, bestG, bestH = traceRequired, span, ground, height
                end

            end

        end

        return bestG, bestH

    end

    hook.Add("PlayerInitialSpawn", "GS_SetGroundPositionOnServerLoad", function(ply)
        if groundPositionFromServerLoadSet then return end

        timer.Simple(0.1, function()
            if !ply:IsValid() then return end

            local origin = ply:GetPos()
            local bestG, bestH = GetBestGroundAndBestHeight(origin, -40000, 40000, 10000, 500, 500, 40000)

            if !bestG or !bestH then return end

            gs_groundPositionFromServerLoad.server = bestG
            gs_heightPositionFromServerLoad.server = bestH

            net.Start("gs_send_ground_data_on_server_load")
            net.WriteVector(bestG)
            net.WriteVector(bestH)
            net.Broadcast()

            groundPositionFromServerLoadSet = true
        end)
    end)

end

if CLIENT then

    net.Receive("gs_send_ground_data_on_server_load", function() gs_groundPositionFromServerLoad.client, gs_heightPositionFromServerLoad.client = net.ReadVector(), net.ReadVector() end)

    net.Receive("gs_start_particle_effect", function()
        local ent = net.ReadEntity()
        if !ent:IsValid() then return end
        ParticleEffect(net.ReadString(), net.ReadVector(), Angle(0, 0, 0), ent)
    end)

end