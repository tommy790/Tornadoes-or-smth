-- ============================================================================
-- TIV SPIKE ANIMATION - Server Side
-- Dynamic hydraulic spike deployment, terrain-adaptive ground interaction,
-- vehicle-relative coordinate calculations, and seamless mid-stroke reversal.
-- ============================================================================

TIV.SpikeAnim = TIV.SpikeAnim or {}

util.AddNetworkString("TIV_SpikeAnimStart")
util.AddNetworkString("TIV_SpikeAnimRetract")
util.AddNetworkString("TIV_SpikeAnimImpact")
util.AddNetworkString("TIV_SpikeAnimPhase")

TIV.SpikeAnim.ActiveJobs      = TIV.SpikeAnim.ActiveJobs or {}
TIV.SpikeAnim._sessionCounter = TIV.SpikeAnim._sessionCounter or 0

-- ============================================================================
-- SHARED THINK LOOP
-- Runs active hydraulic piston jobs every tick.
-- ============================================================================
timer.Create("TIV_SpikeAnimThink", 0.02, 0, function()
    for jobKey, job in pairs(TIV.SpikeAnim.ActiveJobs) do
        local ok = job.fn(job)
        if ok == false then
            TIV.SpikeAnim.ActiveJobs[jobKey] = nil
        end
    end
end)

-- ============================================================================
-- COORDINATE & ORIENTATION HELPERS
-- Strictly uses the vehicle's actual forward, right, up, and transformation
-- matrices. Never assumes world north/east corresponds to vehicle forward/right.
-- ============================================================================

-- Local angle that points the spike downward along the vehicle's down vector
local function GetParentedLocalAngle()
    return Angle(90, 0, 0)
end

-- World angle pointing downward perpendicular to the vehicle's chassis plane
local function GetSpikeDownAngle(veh)
    if not IsValid(veh) then return Angle(90, 0, 0) end
    return veh:LocalToWorldAngles(GetParentedLocalAngle())
end

-- Local position for a spike when stored in the vehicle's hydraulic ram cylinder
local function GetStoredLocalPos(offsetPos)
    local hoverOffset = TIV.Config.SpikeHoverOffset or 5
    return Vector(offsetPos.x, offsetPos.y, offsetPos.z + hoverOffset)
end

TIV.SpikeAnim.GetSpikeDownAngle     = GetSpikeDownAngle
TIV.SpikeAnim.GetParentedLocalAngle = GetParentedLocalAngle
TIV.SpikeAnim.GetStoredLocalPos     = GetStoredLocalPos

-- ============================================================================
-- TERRAIN RAYCASTING
-- Traces downward beneath the actual mounting position along the vehicle's
-- down vector (-veh:GetUp()), adapting to slopes, steps, rocks, and uneven terrain.
-- ============================================================================
local function TraceGroundForSpike(veh, mountWorldPos, data)
    local downDir = -veh:GetUp()

    local tr = util.TraceLine({
        start  = mountWorldPos,
        endpos = mountWorldPos + (downDir * 220),
        filter = function(ent)
            if ent == veh or ent:GetParent() == veh then return false end
            if data and data.spikes then
                for _, sd in ipairs(data.spikes) do
                    if sd.entity == ent then return false end
                end
            end
            return true
        end,
        mask = MASK_SOLID,
    })

    -- Fallback: if vehicle is perched on a steep slope or ledge, trace world down
    if not tr.Hit then
        local worldDown = Vector(0, 0, -1)
        tr = util.TraceLine({
            start  = mountWorldPos,
            endpos = mountWorldPos + (worldDown * 220),
            filter = function(ent)
                if ent == veh or ent:GetParent() == veh then return false end
                if data and data.spikes then
                    for _, sd in ipairs(data.spikes) do
                        if sd.entity == ent then return false end
                    end
                end
                return true
            end,
            mask = MASK_SOLID,
        })
    end

    return tr
end

-- ============================================================================
-- COMPATIBILITY & VISIBILITY FLAGS
-- ============================================================================
function TIV.SpikeAnim.ApplyVisibility(spike)
    if not IsValid(spike) then return end
    local hidden = (TIV.Config.HideSpikes == true)
        or (GetConVar("tiv_hide_spikes") and GetConVar("tiv_hide_spikes"):GetBool())
    spike:SetNoDraw(hidden)
    spike:DrawShadow(not hidden)
end

function TIV.SpikeAnim.ApplyCompatibilityFlags(spike, veh)
    if not IsValid(spike) then return end

    spike:SetNWBool("TIV_Spike", true)
    if IsValid(veh) then spike:SetNWEntity("TIV_OwnerVehicle", veh) end
    spike:SetNWBool("GStormsIgnore", true)
    spike:SetNWBool("XT3Ignore", true)

    spike.IsTIVSpike           = true
    spike.GStormsIgnore        = true
    spike.XT3Ignore            = true
    spike.XT3DoNotApplyPhysics = true
    spike.PhysgunDisabled      = true
    spike.DoNotDuplicate       = true
end

-- ============================================================================
-- GET OFFSETS FOR VEHICLE
-- ============================================================================
local function GetOffsetsForVehicle(veh)
    if not IsValid(veh) then
        return TIV.Config.SpikeOffsets.jeep
    end

    local model = string.lower(veh:GetModel() or "")
    local class = string.lower(veh:GetClass() or "")

    if class == "prop_vehicle_apc" or string.find(model, "apc", 1, true) then
        return TIV.Config.SpikeOffsets.prop_vehicle_apc or TIV.Config.SpikeOffsets.jeep
    end
    if class == "prop_vehicle_jalopy" or string.find(model, "jalopy", 1, true) then
        return TIV.Config.SpikeOffsets.jalopy or TIV.Config.SpikeOffsets.jeep
    end
    return TIV.Config.SpikeOffsets.jeep
end

-- ============================================================================
-- CREATE SPIKES ON VEHICLE
-- Mounts spikes solidly in the vehicle's local coordinate frame.
-- ============================================================================
function TIV.SpikeAnim.CreateSpikes(veh, data)
    if not IsValid(veh) then return end

    local offsets    = GetOffsetsForVehicle(veh)
    local spikeCount = math.Clamp(
        TIV.Config.SpikeCount,
        TIV.Config.SpikeCountConvarMin or 0,
        TIV.Config.SpikeCountConvarMax or 6
    )

    TIV.SpikeAnim._sessionCounter = TIV.SpikeAnim._sessionCounter + 1
    data.sessionID = tostring(TIV.Config.SessionSeed or 1000)
        .. "_" .. veh:EntIndex()
        .. "_" .. tostring(CurTime())
        .. "_" .. TIV.SpikeAnim._sessionCounter

    if spikeCount <= 0 then
        TIV.Spikes.RemoveAll(data, veh:EntIndex())
        data.spikes     = {}
        data.spikeAnims = {}
        return
    end

    TIV.Spikes.RemoveAll(data, veh:EntIndex())
    data.spikes     = {}
    data.spikeAnims = {}

    local groupFront = GetConVar("tiv_spike_group_front")
    local groupMid   = GetConVar("tiv_spike_group_mid")
    local groupRear  = GetConVar("tiv_spike_group_rear")
    local spreadOff  = GetConVar("tiv_spike_spread_offset") and GetConVar("tiv_spike_spread_offset"):GetFloat() or 0
    local lengthOff  = GetConVar("tiv_spike_length_offset") and GetConVar("tiv_spike_length_offset"):GetFloat() or 0

    for i = 1, spikeCount do
        local offsetData = offsets[i]
        if offsetData then
            local grp = offsetData.group or "mid"
            local allowed = true
            if grp == "front" and groupFront and not groupFront:GetBool() then allowed = false end
            if grp == "mid" and groupMid and not groupMid:GetBool() then allowed = false end
            if grp == "rear" and groupRear and not groupRear:GetBool() then allowed = false end

            if allowed then
                local adjPos = Vector(offsetData.pos.x, offsetData.pos.y, offsetData.pos.z)
                if adjPos.x > 0 then
                    adjPos.x = adjPos.x + spreadOff
                elseif adjPos.x < 0 then
                    adjPos.x = adjPos.x - spreadOff
                end
                adjPos.y = adjPos.y + lengthOff

                local storedLocalPos = GetStoredLocalPos(adjPos)
                local storedLocalAng = GetParentedLocalAngle()

                local spike = ents.Create("prop_physics")
                if IsValid(spike) then
                    local worldPos = veh:LocalToWorld(storedLocalPos)
                    local worldAng = veh:LocalToWorldAngles(storedLocalAng)

                    spike:SetModel(TIV.Config.SpikeModel or "models/props_c17/TrapPropeller_Lever.mdl")
                    spike:SetPos(worldPos)
                    spike:SetAngles(worldAng)
                    spike:Spawn()
                    spike:Activate()

                    spike:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                    spike:SetColor(Color(80, 80, 80, 255))
                    spike:SetMaterial("models/props_combine/metal_combinebridge001")

                    TIV.SpikeAnim.ApplyCompatibilityFlags(spike, veh)
                    TIV.SpikeAnim.ApplyVisibility(spike)
                    spike:SetCustomCollisionCheck(true)

                    local spikePhys = spike:GetPhysicsObject()
                    if IsValid(spikePhys) then
                        spikePhys:SetMass(50)
                        spikePhys:EnableMotion(false)
                        spikePhys:EnableGravity(false)
                    end

                    spike:SetParent(veh)
                    spike:SetLocalPos(storedLocalPos)
                    spike:SetLocalAngles(storedLocalAng)

                    table.insert(data.spikes, {
                        entity         = spike,
                        offset         = adjPos,
                        storedLocalPos = storedLocalPos,
                        storedLocalAng = storedLocalAng,
                        localPos       = storedLocalPos,
                        index          = i,
                        phase          = "idle",
                        name           = offsetData.name or ("Spike " .. i),
                        group          = offsetData.group or "mid",
                        groundPos      = nil,
                        groundNormal   = nil,
                    })

                    data.spikeAnims[i] = "idle"
                end
            end
        end
    end
end

-- ============================================================================
-- REPARENT SPIKE TO VEHICLE
-- ============================================================================
function TIV.SpikeAnim.ReparentSpike(veh, spike, spikeData)
    if not IsValid(veh) or not IsValid(spike) then return end

    local spikePhys = spike:GetPhysicsObject()
    if IsValid(spikePhys) then
        spikePhys:EnableMotion(false)
        spikePhys:EnableGravity(false)
    end

    TIV.SpikeAnim.ApplyCompatibilityFlags(spike, veh)
    TIV.SpikeAnim.ApplyVisibility(spike)
    spike:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    spike:SetParent(veh)
    spike:SetLocalPos(spikeData.storedLocalPos or spikeData.localPos)
    spike:SetLocalAngles(GetParentedLocalAngle())
    spikeData.phase = "idle"
end

-- ============================================================================
-- CANCEL ACTIVE JOBS FOR VEHICLE
-- ============================================================================
local function CancelVehicleJobs(sessionID)
    if not sessionID then return end
    local prefix = sessionID .. "_"
    for jobKey in pairs(TIV.SpikeAnim.ActiveJobs) do
        if string.sub(jobKey, 1, #prefix) == prefix then
            TIV.SpikeAnim.ActiveJobs[jobKey] = nil
        end
    end
end

-- ============================================================================
-- DYNAMIC DEPLOYMENT TO GROUND
-- Staggered hydraulic stroke, terrain-adaptive raycasting, and physical settle.
-- ============================================================================
function TIV.SpikeAnim.DeployToGround(veh, data, callback)
    if not IsValid(veh) then
        if callback then callback() end
        return
    end
    if not data.spikes or #data.spikes == 0 then
        if callback then callback() end
        return
    end

    local sessionID = data.sessionID or tostring(veh:EntIndex())
    CancelVehicleJobs(sessionID)

    net.Start("TIV_SpikeAnimStart")
        net.WriteEntity(veh)
        net.WriteUInt(#data.spikes, 8)
    net.Broadcast()

    local totalSpikes   = #data.spikes
    local deployedCount = 0
    local speedMult     = GetConVar("tiv_deploy_speed") and math.max(0.2, GetConVar("tiv_deploy_speed"):GetFloat()) or 1.0
    local driveDepth    = math.Clamp(GetConVar("tiv_spike_drive_depth") and GetConVar("tiv_spike_drive_depth"):GetFloat() or 18, 5, 35)

    local completionFired = false
    local function fireCompletion()
        if completionFired then return end
        completionFired = true
        if callback then callback() end
    end
    local function tickCompletion()
        deployedCount = deployedCount + 1
        if deployedCount >= totalSpikes then fireCompletion() end
    end

    for i, spikeData in ipairs(data.spikes) do
        local spike = spikeData.entity
        if not IsValid(spike) then
            tickCompletion()
        else
            local index = spikeData.index
            local grp   = spikeData.group or "mid"

            -- Staggered deployment timing: Rear anchors drop first, then Mid, then Front
            local baseDelay = 0.0
            if grp == "rear" then
                baseDelay = 0.00
            elseif grp == "mid" then
                baseDelay = 0.12
            elseif grp == "front" then
                baseDelay = 0.24
            end
            -- Subtle 30ms offset between left and right side hydraulic cylinders
            local sideJitter = (i % 2 == 0) and 0.03 or 0.00
            local stagger    = (baseDelay + sideJitter) / speedMult

            timer.Simple(stagger, function()
                if not IsValid(veh) or not IsValid(spike) then
                    tickCompletion()
                    return
                end

                -- Raycast downward from the spike's actual mounting position
                local mountWorldPos = veh:LocalToWorld(spikeData.storedLocalPos)
                local groundTrace   = TraceGroundForSpike(veh, mountWorldPos, data)

                local groundWorldPos = groundTrace.Hit and groundTrace.HitPos
                    or (mountWorldPos - veh:GetUp() * 50)
                local groundNormal   = groundTrace.HitNormal or veh:GetUp()

                -- Calculate exact ground contact and anchoring depth in vehicle's local frame
                local groundLocalPos = veh:WorldToLocal(groundWorldPos)
                local targetLocalPos = groundLocalPos + Vector(0, 0, -driveDepth)

                spikeData.groundPos      = groundWorldPos
                spikeData.groundNormal   = groundNormal
                spikeData.targetLocalPos = targetLocalPos
                spikeData.phase          = "deploying"
                data.spikeAnims[index]   = "deploying"

                net.Start("TIV_SpikeAnimPhase")
                    net.WriteEntity(veh)
                    net.WriteUInt(index, 8)
                    net.WriteString("deploying")
                net.Broadcast()

                -- Starting local position (wherever the spike currently is)
                local startLocalPos  = spike:GetLocalPos()
                local strokeStart    = CurTime()
                local strokeDuration = 0.55 / speedMult
                local settleDuration = 0.12 / speedMult
                local totalDuration  = strokeDuration + settleDuration

                local hasImpacted = false
                local jobKey      = sessionID .. "_deploy_" .. index

                TIV.SpikeAnim.ActiveJobs[jobKey] = {
                    veh   = veh,
                    spike = spike,
                    fn    = function(job)
                        if not IsValid(veh) or not IsValid(spike) then
                            tickCompletion()
                            return false
                        end

                        local elapsed = CurTime() - strokeStart

                        if elapsed < strokeDuration then
                            -- Main hydraulic stroke: smooth S-curve downward
                            local frac = math.Clamp(elapsed / strokeDuration, 0, 1)
                            local ease = math.sin(frac * math.pi * 0.5)

                            local curPos = LerpVector(ease, startLocalPos, groundLocalPos)
                            spike:SetLocalPos(curPos)
                            spike:SetLocalAngles(GetParentedLocalAngle())
                        else
                            -- Ground contact impact puff and sound
                            if not hasImpacted then
                                hasImpacted = true

                                net.Start("TIV_SpikeAnimImpact")
                                    net.WriteEntity(veh)
                                    net.WriteUInt(index, 8)
                                    net.WriteVector(groundWorldPos)
                                    net.WriteVector(groundNormal)
                                net.Broadcast()

                                spike:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav",
                                    70, math.random(95, 105))
                            end

                            -- Settling phase: penetrates to depth with hydraulic pressure rebound
                            local settleElapsed = elapsed - strokeDuration
                            local settleFrac    = math.Clamp(settleElapsed / settleDuration, 0, 1)

                            local settleRebound = math.sin(settleFrac * math.pi) * 1.5 * (1 - settleFrac)
                            local curPos        = LerpVector(settleFrac, groundLocalPos, targetLocalPos) + Vector(0, 0, -settleRebound)

                            spike:SetLocalPos(curPos)
                            spike:SetLocalAngles(GetParentedLocalAngle())

                            if settleFrac >= 1 then
                                -- Final locked position
                                spikeData.phase        = "deployed"
                                data.spikeAnims[index] = "deployed"

                                -- Unparent to attach physical ballsocket constraints
                                local finalWorldPos = veh:LocalToWorld(targetLocalPos)
                                local finalWorldAng = veh:LocalToWorldAngles(GetParentedLocalAngle())

                                spike:SetParent(nil)
                                spike:SetPos(finalWorldPos)
                                spike:SetAngles(finalWorldAng)
                                spike:SetCollisionGroup(COLLISION_GROUP_WORLD)

                                local sp = spike:GetPhysicsObject()
                                if IsValid(sp) then sp:EnableMotion(false) end

                                net.Start("TIV_SpikeAnimPhase")
                                    net.WriteEntity(veh)
                                    net.WriteUInt(index, 8)
                                    net.WriteString("deployed")
                                net.Broadcast()

                                TIV.Anchor.AttachSingle(veh, data, spikeData, i)

                                tickCompletion()
                                return false
                            end
                        end

                        return true
                    end
                }
            end)
        end
    end
end

-- ============================================================================
-- DYNAMIC RETRACTION FROM GROUND
-- Smooth hydraulic return into vehicle stored ram cylinders with staggered timing.
-- ============================================================================
function TIV.SpikeAnim.RetractFromGround(veh, data, callback)
    if not IsValid(veh) then
        if callback then callback() end
        return
    end
    if not data.spikes or #data.spikes == 0 then
        if callback then callback() end
        return
    end

    local sessionID = data.sessionID or tostring(veh:EntIndex())
    CancelVehicleJobs(sessionID)

    net.Start("TIV_SpikeAnimRetract")
        net.WriteEntity(veh)
    net.Broadcast()

    -- Detach constraints immediately so vehicle isn't anchored while retracting
    TIV.Anchor.DetachAll(veh, data)

    local totalSpikes    = #data.spikes
    local retractedCount = 0
    local speedMult      = GetConVar("tiv_deploy_speed") and math.max(0.2, GetConVar("tiv_deploy_speed"):GetFloat()) or 1.0

    local completionFired = false
    local function fireCompletion()
        if completionFired then return end
        completionFired = true
        if callback then callback() end
    end
    local function tickCompletion()
        retractedCount = retractedCount + 1
        if retractedCount >= totalSpikes then fireCompletion() end
    end

    for i, spikeData in ipairs(data.spikes) do
        local spike = spikeData.entity
        if not IsValid(spike) then
            tickCompletion()
        else
            local index = spikeData.index
            local grp   = spikeData.group or "mid"

            -- Staggered retraction: Front pulls up first, then Mid, then Rear
            local baseDelay = 0.0
            if grp == "front" then
                baseDelay = 0.00
            elseif grp == "mid" then
                baseDelay = 0.10
            elseif grp == "rear" then
                baseDelay = 0.20
            end
            local sideJitter = (i % 2 == 0) and 0.02 or 0.00
            local stagger    = (baseDelay + sideJitter) / speedMult

            timer.Simple(stagger, function()
                if not IsValid(spike) or not IsValid(veh) then
                    tickCompletion()
                    return
                end

                -- Reparent to vehicle at its current local position
                local curLocalPos = veh:WorldToLocal(spike:GetPos())
                local spikePhys   = spike:GetPhysicsObject()
                if IsValid(spikePhys) then
                    spikePhys:EnableMotion(false)
                    spikePhys:EnableGravity(false)
                end

                spike:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                spike:SetParent(veh)
                spike:SetLocalPos(curLocalPos)
                spike:SetLocalAngles(GetParentedLocalAngle())

                spikeData.phase        = "retracting"
                data.spikeAnims[index] = "retracting"

                net.Start("TIV_SpikeAnimPhase")
                    net.WriteEntity(veh)
                    net.WriteUInt(index, 8)
                    net.WriteString("retracting")
                net.Broadcast()

                local retractStart    = CurTime()
                local retractDuration = 0.48 / speedMult
                local targetLocalPos  = spikeData.storedLocalPos
                local jobKey          = sessionID .. "_retract_" .. index

                TIV.SpikeAnim.ActiveJobs[jobKey] = {
                    veh   = veh,
                    spike = spike,
                    fn    = function(job)
                        if not IsValid(spike) or not IsValid(veh) then
                            tickCompletion()
                            return false
                        end

                        local elapsed = CurTime() - retractStart
                        local frac    = math.Clamp(elapsed / retractDuration, 0, 1)
                        local ease    = frac * frac * (3 - 2 * frac)

                        local newLocalPos = LerpVector(ease, curLocalPos, targetLocalPos)
                        spike:SetLocalPos(newLocalPos)
                        spike:SetLocalAngles(GetParentedLocalAngle())

                        if frac >= 1 then
                            TIV.SpikeAnim.ReparentSpike(veh, spike, spikeData)
                            data.spikeAnims[index] = "idle"

                            net.Start("TIV_SpikeAnimPhase")
                                net.WriteEntity(veh)
                                net.WriteUInt(index, 8)
                                net.WriteString("idle")
                            net.Broadcast()

                            tickCompletion()
                            return false
                        end

                        return true
                    end
                }
            end)
        end
    end
end

-- ============================================================================
-- INTERRUPT AND RETRACT
-- Handles pressing B while deployment is currently in progress.
-- Smoothly reverses all spikes from their current positions back to stored.
-- ============================================================================
function TIV.SpikeAnim.InterruptAndRetract(veh, data, callback)
    if not IsValid(veh) or not data.spikes then
        if callback then callback() end
        return
    end

    local sessionID = data.sessionID or tostring(veh:EntIndex())
    CancelVehicleJobs(sessionID)
    TIV.Anchor.DetachAll(veh, data)

    net.Start("TIV_SpikeAnimRetract")
        net.WriteEntity(veh)
    net.Broadcast()

    local totalSpikes    = #data.spikes
    local retractedCount = 0
    local speedMult      = GetConVar("tiv_deploy_speed") and math.max(0.2, GetConVar("tiv_deploy_speed"):GetFloat()) or 1.0

    local completionFired = false
    local function fireCompletion()
        if completionFired then return end
        completionFired = true
        if callback then callback() end
    end
    local function tickCompletion()
        retractedCount = retractedCount + 1
        if retractedCount >= totalSpikes then fireCompletion() end
    end

    for _, spikeData in ipairs(data.spikes) do
        local spike = spikeData.entity
        if not IsValid(spike) then
            tickCompletion()
        else
            local index = spikeData.index

            -- Sample current real-time position
            local curLocalPos
            if IsValid(spike:GetParent()) then
                curLocalPos = spike:GetLocalPos()
            else
                curLocalPos = veh:WorldToLocal(spike:GetPos())
                spike:SetParent(veh)
                spike:SetLocalPos(curLocalPos)
                spike:SetLocalAngles(GetParentedLocalAngle())
            end

            spikeData.phase        = "retracting"
            data.spikeAnims[index] = "retracting"

            net.Start("TIV_SpikeAnimPhase")
                net.WriteEntity(veh)
                net.WriteUInt(index, 8)
                net.WriteString("retracting")
            net.Broadcast()

            local retractStart    = CurTime()
            local targetLocalPos  = spikeData.storedLocalPos
            local distFrac        = math.Clamp((curLocalPos - targetLocalPos):Length() / 40, 0.2, 1.0)
            local retractDuration = (0.45 * distFrac) / speedMult
            local jobKey          = sessionID .. "_int_retract_" .. index

            TIV.SpikeAnim.ActiveJobs[jobKey] = {
                veh   = veh,
                spike = spike,
                fn    = function(job)
                    if not IsValid(spike) or not IsValid(veh) then
                        tickCompletion()
                        return false
                    end

                    local elapsed = CurTime() - retractStart
                    local frac    = math.Clamp(elapsed / retractDuration, 0, 1)
                    local ease    = frac * frac * (3 - 2 * frac)

                    local newLocalPos = LerpVector(ease, curLocalPos, targetLocalPos)
                    spike:SetLocalPos(newLocalPos)
                    spike:SetLocalAngles(GetParentedLocalAngle())

                    if frac >= 1 then
                        TIV.SpikeAnim.ReparentSpike(veh, spike, spikeData)
                        data.spikeAnims[index] = "idle"

                        net.Start("TIV_SpikeAnimPhase")
                            net.WriteEntity(veh)
                            net.WriteUInt(index, 8)
                            net.WriteString("idle")
                        net.Broadcast()

                        tickCompletion()
                        return false
                    end

                    return true
                end
            }
        end
    end
end

-- ============================================================================
-- INTERRUPT AND DEPLOY
-- Handles pressing B while retraction is currently in progress.
-- Smoothly reverses all spikes from their current positions back to ground.
-- ============================================================================
function TIV.SpikeAnim.InterruptAndDeploy(veh, data, callback)
    if not IsValid(veh) or not data.spikes then
        if callback then callback() end
        return
    end

    local sessionID = data.sessionID or tostring(veh:EntIndex())
    CancelVehicleJobs(sessionID)

    net.Start("TIV_SpikeAnimStart")
        net.WriteEntity(veh)
        net.WriteUInt(#data.spikes, 8)
    net.Broadcast()

    local totalSpikes   = #data.spikes
    local deployedCount = 0
    local speedMult     = GetConVar("tiv_deploy_speed") and math.max(0.2, GetConVar("tiv_deploy_speed"):GetFloat()) or 1.0
    local driveDepth    = math.Clamp(GetConVar("tiv_spike_drive_depth") and GetConVar("tiv_spike_drive_depth"):GetFloat() or 18, 5, 35)

    local completionFired = false
    local function fireCompletion()
        if completionFired then return end
        completionFired = true
        if callback then callback() end
    end
    local function tickCompletion()
        deployedCount = deployedCount + 1
        if deployedCount >= totalSpikes then fireCompletion() end
    end

    for i, spikeData in ipairs(data.spikes) do
        local spike = spikeData.entity
        if not IsValid(spike) then
            tickCompletion()
        else
            local index         = spikeData.index
            local mountWorldPos = veh:LocalToWorld(spikeData.storedLocalPos)
            local groundTrace   = TraceGroundForSpike(veh, mountWorldPos, data)

            local groundWorldPos = groundTrace.Hit and groundTrace.HitPos
                or (mountWorldPos - veh:GetUp() * 50)
            local groundNormal   = groundTrace.HitNormal or veh:GetUp()
            local groundLocalPos = veh:WorldToLocal(groundWorldPos)
            local targetLocalPos = groundLocalPos + Vector(0, 0, -driveDepth)

            spikeData.groundPos      = groundWorldPos
            spikeData.groundNormal   = groundNormal
            spikeData.targetLocalPos = targetLocalPos
            spikeData.phase          = "deploying"
            data.spikeAnims[index]   = "deploying"

            net.Start("TIV_SpikeAnimPhase")
                net.WriteEntity(veh)
                net.WriteUInt(index, 8)
                net.WriteString("deploying")
            net.Broadcast()

            local curLocalPos = spike:GetLocalPos()
            local distFrac    = math.Clamp((curLocalPos - targetLocalPos):Length() / 40, 0.2, 1.0)
            local strokeStart = CurTime()
            local duration    = (0.50 * distFrac) / speedMult
            local jobKey      = sessionID .. "_int_deploy_" .. index

            TIV.SpikeAnim.ActiveJobs[jobKey] = {
                veh   = veh,
                spike = spike,
                fn    = function(job)
                    if not IsValid(veh) or not IsValid(spike) then
                        tickCompletion()
                        return false
                    end

                    local elapsed = CurTime() - strokeStart
                    local frac    = math.Clamp(elapsed / duration, 0, 1)
                    local ease    = math.sin(frac * math.pi * 0.5)

                    local newPos = LerpVector(ease, curLocalPos, targetLocalPos)
                    spike:SetLocalPos(newPos)
                    spike:SetLocalAngles(GetParentedLocalAngle())

                    if frac >= 1 then
                        spikeData.phase        = "deployed"
                        data.spikeAnims[index] = "deployed"

                        local finalWorldPos = veh:LocalToWorld(targetLocalPos)
                        local finalWorldAng = veh:LocalToWorldAngles(GetParentedLocalAngle())

                        spike:SetParent(nil)
                        spike:SetPos(finalWorldPos)
                        spike:SetAngles(finalWorldAng)
                        spike:SetCollisionGroup(COLLISION_GROUP_WORLD)

                        local sp = spike:GetPhysicsObject()
                        if IsValid(sp) then sp:EnableMotion(false) end

                        net.Start("TIV_SpikeAnimPhase")
                            net.WriteEntity(veh)
                            net.WriteUInt(index, 8)
                            net.WriteString("deployed")
                        net.Broadcast()

                        TIV.Anchor.AttachSingle(veh, data, spikeData, i)

                        tickCompletion()
                        return false
                    end

                    return true
                end
            }
        end
    end
end

print("[TIV] Dynamic spike animation system loaded")
