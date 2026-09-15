-- ============================================================================
-- TIV LOFT SYSTEM - Comprehensive Advanced Edition
-- Features:
--   1. Dynamic Wind-Directional Failure: Windward anchors under tension fail first.
--   2. Physical Chassis Tipping: Vehicle hinges and tilts 20°-28° on remaining anchors.
--   3. Structural Fatigue & Audio: Layered deep chassis strain, creaks, pneumatic blowout.
--   4. Sacrificial Armor Panels: Extreme vortex shear tears outer panels into the storm.
--   5. Continuous Vortex Aerodynamics: Inward suction, orbital swirl, updraft, and tumbling.
--   6. Crash Landing Dynamics: Heavy impact sounds, dust shockwaves, and state settling.
--   7. Hydraulic Rollover Recovery: Self-rights overturned vehicles on [R] or tiv_recover.
-- ============================================================================

TIV = TIV or {}
TIV.Loft = TIV.Loft or {}

util.AddNetworkString("TIV_LoftEvent")
util.AddNetworkString("TIV_AnchorWarning")
util.AddNetworkString("TIV_RecoverRequest")

TIV.Loft.WindTimers    = TIV.Loft.WindTimers    or {}
TIV.Loft.FailingGroups = TIV.Loft.FailingGroups or {}

local function ReleaseSpikesOnLoft()
    local cv = GetConVar("tiv_loft_release_spikes")
    return cv and cv:GetBool() or false
end

CreateConVar("tiv_loft_release_spikes", "0",
    { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED },
    "If 1, spikes fly free as debris on loft. If 0, they stay parented to the vehicle.")

-- ============================================================================
-- STRESS CALCULATION
-- ============================================================================
function TIV.Loft.CalculateStress(windMPH, veh)
    if windMPH < 100 then return 0 end
    local threshold = (IsValid(veh) and veh._TIVEffectiveStats and veh._TIVEffectiveStats.effective_loft_mph)
        or TIV.Config.LoftWindThreshold
        or 180
    local ratio = windMPH / threshold
    return math.Clamp(ratio * ratio, 0, 1)
end

local function GetWindScale(veh)
    local base = (TIV.Compat and TIV.Compat.Enabled) and (TIV.Compat.AnchoredWindForceScale or 0.65) or 1
    if IsValid(veh) and veh._TIVEffectiveStats and veh._TIVEffectiveStats.wind_force_mult then
        base = base * veh._TIVEffectiveStats.wind_force_mult
    end
    return base
end
TIV.Loft.GetWindScale = GetWindScale

-- ============================================================================
-- SACRIFICIAL ARMOR PANEL TEARING
-- High-speed wind shear rips outer armor panels from the chassis.
-- ============================================================================
function TIV.Loft.RipArmorPanel(veh, windForceVec)
    if not IsValid(veh) or not veh._TIVArmorProps or #veh._TIVArmorProps == 0 then return end

    local entIdx = veh:EntIndex()
    local prop = nil
    for i = #veh._TIVArmorProps, 1, -1 do
        local p = veh._TIVArmorProps[i]
        if IsValid(p) then
            prop = p
            table.remove(veh._TIVArmorProps, i)
            if TIV.CustomComponents and TIV.CustomComponents.VehicleArmor and TIV.CustomComponents.VehicleArmor[entIdx] then
                table.RemoveByValue(TIV.CustomComponents.VehicleArmor[entIdx], p)
            end
            break
        end
    end

    if not IsValid(prop) then return end

    local propPos = prop:GetPos()
    prop:SetParent(nil)

    local phys = prop:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(true)
        phys:EnableGravity(true)
        phys:Wake()

        local tearDir = ((windForceVec or Vector(0, 0, 0)) + Vector(0, 0, 1) * 350 + VectorRand() * 200):GetNormalized()
        phys:ApplyForceCenter(tearDir * phys:GetMass() * 2800)
        phys:ApplyTorqueCenter(VectorRand() * 2000)
    end

    prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    prop:EmitSound("physics/metal/metal_sheet_impact_hard" .. math.random(1, 3) .. ".wav", 88, math.random(85, 115))
    prop:EmitSound("physics/metal/metal_box_break2.wav", 82, math.random(70, 90))

    local sparkFX = EffectData()
    sparkFX:SetOrigin(propPos)
    sparkFX:SetMagnitude(10)
    sparkFX:SetScale(4)
    util.Effect("Sparks", sparkFX)

    util.ScreenShake(propPos, 12, 10, 0.6, 400)

    -- Auto-clean rip debris after 20 seconds so it doesn't clutter map
    SafeRemoveEntityDelayed(prop, 20)

    -- Update vehicle mass stats (shedding ballast)
    if veh._TIVEffectiveStats and veh._TIVEffectiveStats.total_ballast_mass then
        veh._TIVEffectiveStats.total_ballast_mass = math.max(0, veh._TIVEffectiveStats.total_ballast_mass - 120)
    end
end

-- ============================================================================
-- DYNAMIC WINDWARD FAILURE SEQUENCE
-- Computes real-time tensile moment load on each anchor. Windward anchors
-- under tension fail first, while leeward anchors act as the tipping fulcrum.
-- ============================================================================
function TIV.Loft.GetWindwardFailureSequence(veh, data)
    if not IsValid(veh) or not data or not data.spikes or #data.spikes == 0 then
        return {
            { spikes = { 5, 6 }, duration = 0.8, name = "stage1" },
            { spikes = { 3, 4 }, duration = 0.8, name = "stage2" },
            { spikes = { 1, 2 }, duration = 0.8, name = "stage3" },
        }
    end

    local windDir = TIV.Wind.GetDirection(veh)
    local windLocal = veh:WorldToLocal(veh:GetPos() + windDir)

    -- Calculate tensile stress score for each spike:
    -- Lateral wind (+X right) lifts left-side spikes (-X) into high tension.
    -- Longitudinal wind (+Y tailwind) lifts rear spikes (-Y) into high tension.
    local scoredSpikes = {}
    for _, sd in ipairs(data.spikes) do
        if IsValid(sd.entity) then
            local off = sd.offset or Vector(0, 0, 0)
            local score = - (windLocal.x * off.x * 2.0) - (windLocal.y * off.y * 1.0)
            table.insert(scoredSpikes, {
                spikeData = sd,
                index     = sd.index,
                score     = score,
            })
        end
    end

    table.sort(scoredSpikes, function(a, b) return a.score > b.score end)

    local total = #scoredSpikes
    local g1, g2, g3 = {}, {}, {}
    for i, item in ipairs(scoredSpikes) do
        if i <= math.ceil(total * 0.35) then
            table.insert(g1, item.index)
        elseif i <= math.ceil(total * 0.70) then
            table.insert(g2, item.index)
        else
            table.insert(g3, item.index)
        end
    end

    if #g1 == 0 and total > 0 then table.insert(g1, scoredSpikes[1].index) end
    if #g3 == 0 and total > 0 then table.insert(g3, scoredSpikes[total].index) end

    return {
        { spikes = g1, startTime = 0.0, duration = 0.8, name = "windward" },
        { spikes = g2, startTime = 0.9, duration = 0.8, name = "mid" },
        { spikes = g3, startTime = 1.8, duration = 0.8, name = "leeward" },
    }
end

local function ClearGroupFailTimers(prefix)
    timer.Remove(prefix .. "_windward")
    timer.Remove(prefix .. "_mid")
    timer.Remove(prefix .. "_leeward")
    timer.Remove(prefix .. "_rear")
    timer.Remove(prefix .. "_front")
end

-- ============================================================================
-- FAIL SPIKE LIST
-- Breaks a set of anchor pins with explosive sounds, sparks, and screen shake.
-- ============================================================================
function TIV.Loft.FailSpikeList(veh, data, spikeIndices, duration, stageName)
    local cheatGodmode = GetConVar("tiv_cheat_godmode_anchors")
    if cheatGodmode and cheatGodmode:GetBool() then return end
    if not spikeIndices or #spikeIndices == 0 then return end

    local liveCount = 0
    for _, idx in ipairs(spikeIndices) do
        for _, sd in ipairs(data.spikes or {}) do
            if sd.index == idx and IsValid(sd.entity) then
                liveCount = liveCount + 1
                break
            end
        end
    end
    if liveCount == 0 then return end

    local staggerPerSpike = duration / #spikeIndices

    for i, spikeIdx in ipairs(spikeIndices) do
        local delay = (i - 1) * staggerPerSpike + math.Rand(0, staggerPerSpike * 0.25)

        timer.Simple(delay, function()
            if not IsValid(veh) then return end
            if data.state ~= "anchored" then return end

            if not data.gravityReleased then
                data.gravityReleased = true
                local vehPhys = veh:GetPhysicsObject()
                if IsValid(vehPhys) then vehPhys:EnableGravity(true) end
            end

            local spikeEnt, spikeData
            for _, sd in ipairs(data.spikes or {}) do
                if sd.index == spikeIdx and IsValid(sd.entity) then
                    spikeEnt  = sd.entity
                    spikeData = sd
                    break
                end
            end

            if IsValid(spikeEnt) then
                local spikePhys = spikeEnt:GetPhysicsObject()
                if IsValid(spikePhys) then
                    spikePhys:EnableMotion(true)
                    spikePhys:EnableGravity(true)
                    spikePhys:Wake()

                    local windScale = GetWindScale(veh)
                    local windForce = TIV.Wind.GetForceVector(veh) * spikePhys:GetMass() * 1.5 * windScale
                    local upForce   = Vector(0, 0, 1) * spikePhys:GetMass() * 700
                    local pullToVeh = (veh:GetPos() - spikeEnt:GetPos()):GetNormalized() * spikePhys:GetMass() * 200

                    spikePhys:ApplyForceCenter(windForce + upForce + pullToVeh)
                    spikePhys:ApplyTorqueCenter(VectorRand() * 500)
                end

                spikeEnt:SetCollisionGroup(COLLISION_GROUP_NONE)

                -- Pneumatic hydraulic blowout sound + metal snap
                spikeEnt:EmitSound("ambient/machines/steam_release_2.wav", 85, math.random(105, 120))
                spikeEnt:EmitSound("physics/metal/metal_box_break1.wav", 90, math.random(60, 75))

                local sparkFX = EffectData()
                sparkFX:SetOrigin(spikeEnt:GetPos())
                sparkFX:SetMagnitude(9)
                sparkFX:SetScale(3.5)
                util.Effect("Sparks", sparkFX)

                local dustFX = EffectData()
                dustFX:SetOrigin(spikeEnt:GetPos())
                dustFX:SetScale(1.2)
                util.Effect("WheelDust", dustFX)

                util.ScreenShake(spikeEnt:GetPos(), 14, 16, 0.8, 420)
            end

            TIV.Anchor.BreakSpike(veh, data, spikeIdx)

            -- Check sacrificial armor shedding on anchor failure
            local wMPH = TIV.Wind.GetSpeed(veh)
            if wMPH > 190 and math.random() < 0.45 then
                TIV.Loft.RipArmorPanel(veh, TIV.Wind.GetForceVector(veh))
            end

            -- Reparent spike entity after brief ejection
            timer.Simple(0.12, function()
                if not IsValid(veh) or not IsValid(spikeEnt) or not spikeData then return end
                if TIV.SpikeAnim and TIV.SpikeAnim.ReparentSpike then
                    TIV.SpikeAnim.ReparentSpike(veh, spikeEnt, spikeData)
                end
                if data.spikeAnims and spikeIdx then
                    data.spikeAnims[spikeIdx] = "idle"
                end
            end)

            local remainingBS = 0
            for _, c in ipairs(data.constraints or {}) do
                if c.type == "ballsocket" and IsValid(c.constraint) then
                    remainingBS = remainingBS + 1
                end
            end

            net.Start("TIV_AnchorWarning")
                net.WriteEntity(veh)
                net.WriteUInt(spikeIdx, 8)
            net.Broadcast()

            hook.Run("TIV_SpikeFailure", veh, spikeIdx)

            if remainingBS == 0 then
                TIV.Loft.TriggerLoft(veh, data)
            end
        end)
    end
end

-- Backward compatibility façade
function TIV.Loft.FailGroup(veh, data, groupName, duration)
    local legacyMap = { rear = { 5, 6 }, mid = { 3, 4 }, front = { 1, 2 } }
    local indices = legacyMap[groupName] or { 1, 2 }
    TIV.Loft.FailSpikeList(veh, data, indices, duration or 0.8, groupName)
end

-- ============================================================================
-- START DIRECTIONAL FAILURE
-- Evaluates real-time windward shear to tear anchors in realistic progression.
-- ============================================================================
function TIV.Loft.StartDirectionalFailure(veh, data)
    if not IsValid(veh) or not data then return end
    if data.state ~= "anchored" then return end

    local entIndex = veh:EntIndex()
    if TIV.Loft.WindTimers[entIndex] then return end

    local prefix = "TIV_GroupFail_" .. entIndex

    TIV.Loft.WindTimers[entIndex]    = CurTime()
    TIV.Loft.FailingGroups[entIndex] = true

    local sequence = TIV.Loft.GetWindwardFailureSequence(veh, data)

    print(string.format(
        "[TIV] Vehicle #%d exceeded %.0f MPH. Dynamic windward anchor failure sequence initiated.",
        entIndex, (veh._TIVEffectiveStats and veh._TIVEffectiveStats.effective_loft_mph) or TIV.Config.LoftWindThreshold or 180))

    for _, step in ipairs(sequence) do
        local stepSpikes, stepDuration, stepName = step.spikes, step.duration, step.name
        timer.Create(prefix .. "_" .. stepName, step.startTime, 1, function()
            if not IsValid(veh) or data.state ~= "anchored" then return end
            TIV.Loft.FailSpikeList(veh, data, stepSpikes, stepDuration, stepName)
        end)
    end
end

local function CleanupLoftTracking(entIdx)
    TIV.Loft.WindTimers[entIdx]    = nil
    TIV.Loft.FailingGroups[entIdx] = nil
    ClearGroupFailTimers("TIV_GroupFail_" .. entIdx)
end
TIV.Loft.CleanupTracking = CleanupLoftTracking

-- ============================================================================
-- TRIGGER FULL LOFT
-- Full chassis launch with vortex updraft, panel shedding, and tumble physics.
-- ============================================================================
function TIV.Loft.TriggerLoft(veh, data)
    if not IsValid(veh) then return end
    if data.state == "lofted" then return end

    local cheatGodmode = GetConVar("tiv_cheat_godmode_anchors")
    if cheatGodmode and cheatGodmode:GetBool() then return end

    local entIdx    = veh:EntIndex()
    local sessionID = data.sessionID

    local windSpeed = TIV.Wind.GetSpeed(veh)
    print("[TIV] ================================")
    print("[TIV] === TIV LOFT TRIGGERED       ===")
    print(string.format("[TIV] === Wind: %.0f MPH at t=%.2f ===", windSpeed, CurTime()))
    print("[TIV] ================================")

    TIV.Anchor.ForceDetach(veh, data)

    data.state    = "lofted"
    data.anchored = false
    data.loftStartTime = CurTime()
    data.lastVelZ = 0
    data.landedTime = nil

    local phys = veh:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableGravity(true)
        phys:EnableMotion(true)
        phys:Wake()

        local upForce   = Vector(0, 0, 1) * phys:GetMass() * (TIV.Config.LoftForceMultiplier or 50)
        local windForce = TIV.Wind.GetForceVector(veh) * phys:GetMass() * 0.55
        local rollTumble = veh:GetForward() * (math.random(-1, 1) * (TIV.Config.LoftTumbleForce or 1000))

        phys:ApplyForceCenter(upForce + windForce)
        phys:ApplyTorqueCenter(rollTumble)
    end

    -- Rip off an armor panel during the violent loft ejection
    TIV.Loft.RipArmorPanel(veh, TIV.Wind.GetForceVector(veh))

    if ReleaseSpikesOnLoft() then
        if TIV.Spikes.ReleaseAll then TIV.Spikes.ReleaseAll(data) end
    else
        for _, sd in ipairs(data.spikes or {}) do
            if IsValid(sd.entity) and TIV.SpikeAnim and TIV.SpikeAnim.ReparentSpike then
                TIV.SpikeAnim.ReparentSpike(veh, sd.entity, sd)
                if data.spikeAnims and sd.index then
                    data.spikeAnims[sd.index] = "idle"
                end
            end
        end
    end

    util.ScreenShake(veh:GetPos(), 25, 15, 3, 800)

    net.Start("TIV_LoftEvent")
        net.WriteEntity(veh)
    net.Broadcast()

    hook.Run("TIV_LoftEvent", veh)
    TIV.Deploy.BroadcastState(veh, "lofted")

    CleanupLoftTracking(entIdx)

    -- Safety timeout: if vehicle somehow stays lofted indefinitely, reset after 25s
    timer.Simple(25, function()
        local liveVeh  = Entity(entIdx)
        local liveData = TIV.Deploy.Vehicles and TIV.Deploy.Vehicles[entIdx]
        if not liveData or liveData.sessionID ~= sessionID then return end

        if liveData.state == "lofted" then
            liveData.state = "idle"
            liveData.anchored = false
            liveData.gravityReleased = false
            if IsValid(liveVeh) then TIV.Deploy.BroadcastState(liveVeh, "idle") end
        end
    end)
end

-- ============================================================================
-- HYDRAULIC ROLLOVER SELF-RIGHTING RECOVERY
-- Corrects overturned vehicles onto their wheels when driver activates [R].
-- ============================================================================
function TIV.Loft.SelfRightVehicle(veh, ply)
    if not IsValid(veh) then return false end
    local phys = veh:GetPhysicsObject()
    if not IsValid(phys) then return false end

    -- Check if vehicle is overturned (up vector tilted significantly from world up)
    local upDot = veh:GetUp():Dot(Vector(0, 0, 1))
    if upDot > 0.45 then
        if IsValid(ply) then ply:ChatPrint("[TIV] Vehicle is already upright.") end
        return false
    end

    veh._TIVNextRecover = veh._TIVNextRecover or 0
    if CurTime() < veh._TIVNextRecover then
        if IsValid(ply) then
            local remain = math.ceil(veh._TIVNextRecover - CurTime())
            ply:ChatPrint("[TIV] Self-righting hydraulic cooldown: " .. remain .. "s")
        end
        return false
    end
    veh._TIVNextRecover = CurTime() + 4.0

    veh:EmitSound("ambient/machines/hydraulic_1.wav", 85, 100)
    veh:EmitSound("physics/metal/metal_box_strain2.wav", 80, 85)

    local curUp = veh:GetUp()
    local targetUp = Vector(0, 0, 1)
    local rotAxis = curUp:Cross(targetUp)
    if rotAxis:LengthSqr() < 0.05 then
        rotAxis = veh:GetForward()
    else
        rotAxis = rotAxis:GetNormalized()
    end

    phys:Wake()
    phys:ApplyForceCenter(Vector(0, 0, 1) * phys:GetMass() * 340)
    phys:ApplyTorqueCenter(rotAxis * phys:GetMass() * 1500)

    local ed = EffectData()
    ed:SetOrigin(veh:GetPos())
    ed:SetScale(2.0)
    util.Effect("WheelDust", ed)

    if IsValid(ply) then
        ply:ChatPrint("[TIV] Hydraulic roll-recovery arm activated.")
    end

    return true
end

concommand.Add("tiv_recover", function(ply)
    local veh = TIV.ResolveVehicle and TIV.ResolveVehicle(ply)
    if IsValid(veh) then
        TIV.Loft.SelfRightVehicle(veh, ply)
    end
end)

concommand.Add("tiv_right_vehicle", function(ply)
    local veh = TIV.ResolveVehicle and TIV.ResolveVehicle(ply)
    if IsValid(veh) then
        TIV.Loft.SelfRightVehicle(veh, ply)
    end
end)

net.Receive("TIV_RecoverRequest", function(len, ply)
    local veh = TIV.ResolveVehicle and TIV.ResolveVehicle(ply)
    if IsValid(veh) then
        TIV.Loft.SelfRightVehicle(veh, ply)
    end
end)

-- ============================================================================
-- MAIN LOFT THINK LOOP
-- Handles:
--   1. Anchor guard and integrity maintenance
--   2. Physical chassis tipping on remaining planted anchors
--   3. Escalating metallic fatigue creaks and groans
--   4. Continuous airborne vortex aerodynamics (updraft, suction, swirl, tumble)
--   5. Heavy ground impact detection and post-loft settling
-- ============================================================================
timer.Create("TIV_LoftThink", 0.05, 0, function()
    for entIndex, data in pairs(TIV.Deploy.Vehicles or {}) do
        local veh = Entity(entIndex)
        if IsValid(veh) then
            local phys = veh:GetPhysicsObject()
            if IsValid(phys) then
                local windMPH     = TIV.Wind.GetSpeed(veh)
                local windDir     = TIV.Wind.GetDirection(veh)
                local windScale   = GetWindScale(veh)
                local windForceVec = TIV.Wind.GetForceVector(veh)
                local stress      = TIV.Loft.CalculateStress(windMPH, veh)
                local effectiveThreshold = (veh._TIVEffectiveStats and veh._TIVEffectiveStats.effective_loft_mph)
                    or TIV.Config.LoftWindThreshold
                    or 180

                -- ============================================================
                -- STATE 1: ANCHORED
                -- ============================================================
                if data.state == "anchored" then
                    -- 1. Anchor Guard: Defend against storm addons wiping joints
                    for _, sd in ipairs(data.spikes or {}) do
                        if sd.phase == "deployed" and IsValid(sd.entity) and sd.groundPos then
                            local sp = sd.entity:GetPhysicsObject()
                            if IsValid(sp) and sp:IsMotionEnabled() then
                                local plantedZ = sd.groundPos.z - (TIV.Config.SpikeDriveDepth or 18)
                                local target = Vector(sd.groundPos.x, sd.groundPos.y, plantedZ)
                                sd.entity:SetPos(target)
                                sp:SetVelocity(Vector(0, 0, 0))
                                sp:SetAngleVelocity(Vector(0, 0, 0))
                                sp:EnableMotion(false)
                                sp:EnableGravity(false)
                            end

                            local hasBS = false
                            for _, c in ipairs(data.constraints or {}) do
                                if c.spikeIndex == sd.index and c.type == "ballsocket" and IsValid(c.constraint) then
                                    hasBS = true
                                    break
                                end
                            end
                            if not hasBS and TIV.Anchor and TIV.Anchor.AttachSingle then
                                for i = #(data.constraints or {}), 1, -1 do
                                    if data.constraints[i].spikeIndex == sd.index then
                                        table.remove(data.constraints, i)
                                    end
                                end
                                TIV.Anchor.AttachSingle(veh, data, sd, sd.index)
                            end
                        end
                    end

                    -- 2. Base Wind Force & Turbulence
                    if windMPH > TIV.Config.Stress.TurbulenceMinMPH then
                        local windForce = windForceVec
                            * phys:GetMass()
                            * TIV.Config.AnchoredWindForce
                            * windScale

                        local turbulence = VectorRand() * phys:GetMass() * (stress * 22)
                        phys:ApplyForceCenter(windForce + turbulence)

                        if stress > TIV.Config.Stress.TorqueMin then
                            local rockScale = tonumber(TIV.Config.AnchoredRockTorque) or 5.5
                            if veh._TIVEffectiveStats and veh._TIVEffectiveStats.rock_torque_mult then
                                rockScale = rockScale * veh._TIVEffectiveStats.rock_torque_mult
                            end
                            local rockTorque = VectorRand() * phys:GetMass()
                                * stress * rockScale * windScale
                            phys:ApplyTorqueCenter(rockTorque)
                        end
                    end

                    -- 3. Pre-Loft Chassis Tipping (when some anchors have failed)
                    local remainingBS = 0
                    for _, c in ipairs(data.constraints or {}) do
                        if c.type == "ballsocket" and IsValid(c.constraint) then
                            remainingBS = remainingBS + 1
                        end
                    end

                    if data.gravityReleased and remainingBS > 0 and remainingBS < #data.spikes then
                        local windLocal = veh:WorldToLocal(veh:GetPos() + windDir)
                        local unanchoredOffset = Vector(
                            windLocal.x > 0 and -32 or 32,
                            windLocal.y > 0 and -40 or 40,
                            15
                        )
                        local liftPos   = veh:LocalToWorld(unanchoredOffset)
                        local liftForce = (Vector(0, 0, 1) * 0.80 + windForceVec:GetNormalized() * 0.20)
                            * phys:GetMass() * (stress * 240) * windScale
                        phys:ApplyForceOffset(liftForce, liftPos)

                        local rollSign = windLocal.x > 0 and 1 or -1
                        local rollTorque = veh:GetForward() * rollSign * phys:GetMass() * (stress * 55) * windScale
                        phys:ApplyTorqueCenter(rollTorque)
                    end

                    -- 4. Structural Metal Creak & Strain Audio
                    if stress > 0.30 then
                        data.nextCreakTime = data.nextCreakTime or 0
                        if CurTime() > data.nextCreakTime then
                            local creakInterval = math.Remap(stress, 0.3, 1.0, 1.6, 0.30)
                            data.nextCreakTime  = CurTime() + creakInterval + math.Rand(0, 0.15)

                            local creakPitch = math.floor(math.Remap(stress, 0.3, 1.0, 80, 48))
                            local creakVol   = math.floor(math.Remap(stress, 0.3, 1.0, 68, 88))
                            local soundName  = "physics/metal/metal_box_strain" .. math.random(1, 4) .. ".wav"
                            veh:EmitSound(soundName, creakVol, creakPitch)

                            if stress > 0.70 and math.random() < 0.35 then
                                veh:EmitSound("physics/metal/metal_barrel_impact_hard" .. math.random(1, 3) .. ".wav", 65, math.random(130, 160))
                            end
                        end
                    end

                    -- 5. Below / Above Threshold State Transitions
                    if windMPH < effectiveThreshold then
                        if TIV.Loft.WindTimers[entIndex] then
                            print(string.format(
                                "[TIV] Wind dropped to %.0f MPH - sequence reset for #%d",
                                windMPH, entIndex))
                            CleanupLoftTracking(entIndex)
                        end

                        if TIV.Spikes.GetCount(data) > 0 then
                            if not TIV.Anchor.CheckIntegrity(veh, data) then
                                if TIV.Compat and TIV.Compat.Enabled then
                                    TIV.Anchor.ForceDetach(veh, data)
                                    data.state         = "idle"
                                    data.anchored      = false
                                    data.spikesCreated = false
                                    data.compatRecoverUntil = CurTime() + (TIV.Compat.RecoveryCooldown or 3)
                                    TIV.Deploy.BroadcastState(veh, "idle")
                                else
                                    TIV.Loft.TriggerLoft(veh, data)
                                end
                            end
                        end
                    else
                        if TIV.Spikes.GetCount(data) == 0 then
                            if not TIV.Loft.FailingGroups[entIndex] then
                                TIV.Loft.TriggerLoft(veh, data)
                            end
                        else
                            if not TIV.Anchor.CheckIntegrity(veh, data) then
                                TIV.Loft.TriggerLoft(veh, data)
                            else
                                TIV.Loft.StartDirectionalFailure(veh, data)
                            end
                        end
                    end

                -- ============================================================
                -- STATE 2: LOFTED (CONTINUOUS VORTEX AERODYNAMICS & CRASH)
                -- ============================================================
                elseif data.state == "lofted" then
                    local vortexEnt, vortexPos, vortexDist = nil, nil, nil
                    if TIV.Wind and TIV.Wind.GetNearestVortex then
                        vortexEnt, vortexPos, vortexDist = TIV.Wind.GetNearestVortex(veh:GetPos(), 6500)
                    end

                    if windMPH > 45 then
                        local vehPos = veh:GetPos()
                        -- Updraft diminishes as vehicle ascends toward cloud deck (~3000 HU)
                        local altitudeFrac = math.Clamp(1 - (vehPos.z / 3200), 0.15, 1.0)
                        local updraftSpeed = math.Clamp(windMPH * 2.2, 80, 550) * altitudeFrac
                        local updraftForce = Vector(0, 0, 1) * phys:GetMass() * updraftSpeed * windScale
                        phys:ApplyForceCenter(updraftForce)

                        if IsValid(vortexEnt) and vortexDist and vortexDist > 100 then
                            local delta = (vortexPos - vehPos)
                            local delta2D = Vector(delta.x, delta.y, 0):GetNormalized()

                            -- Inward core suction toward funnel
                            local suctionForce = delta2D * phys:GetMass() * (windMPH * 0.75) * windScale
                            phys:ApplyForceCenter(suctionForce)

                            -- Orbital tangential circulation around the eye
                            local swirlDir = Vector(-delta2D.y, delta2D.x, 0)
                            if vortexEnt.Anticyclonic or (vortexEnt.GetAnticyclonic and vortexEnt:GetAnticyclonic()) then
                                swirlDir = Vector(delta2D.y, -delta2D.x, 0)
                            end
                            local swirlForce = swirlDir * phys:GetMass() * (windMPH * 1.1) * windScale
                            phys:ApplyForceCenter(swirlForce)
                        else
                            local windForce = windDir * phys:GetMass() * (windMPH * 1.0) * windScale
                            phys:ApplyForceCenter(windForce)
                        end

                        -- Aerodynamic cross-sectional tumbling torque
                        local localWind = veh:WorldToLocal(vehPos + windDir)
                        local rollTorque  = veh:GetForward() * (localWind.x * 25) * phys:GetMass()
                        local pitchTorque = veh:GetRight()   * (localWind.y * 18) * phys:GetMass()
                        local yawTorque   = veh:GetUp()      * (localWind.x * 12) * phys:GetMass()
                        phys:ApplyTorqueCenter(rollTorque + pitchTorque + yawTorque)

                        -- Angular damping prevents runaway RPM
                        local angVel = phys:GetAngleVelocity()
                        if angVel:LengthSqr() > 300 * 300 then
                            phys:AddAngleVelocity(-angVel * 0.04)
                        end
                    end

                    -- Crash Landing Impact Detection
                    local curVel = phys:GetVelocity()
                    local prevVelZ = data.lastVelZ or 0
                    data.lastVelZ = curVel.z

                    local tr = util.TraceLine({
                        start  = veh:GetPos(),
                        endpos = veh:GetPos() - Vector(0, 0, 80),
                        filter = veh,
                        mask   = MASK_SOLID_BRUSHONLY,
                    })

                    if tr.Hit and prevVelZ < -350 then
                        local impactSpeed = math.abs(prevVelZ)
                        local intensity   = math.Clamp(impactSpeed / 1000, 0.3, 1.5)

                        veh:EmitSound("physics/metal/metal_large_debris" .. math.random(1, 2) .. ".wav", 95, math.random(75, 95))
                        veh:EmitSound("vehicles/v8/vehicle_impact_heavy" .. math.random(1, 4) .. ".wav", 90, math.random(85, 105))

                        local ed = EffectData()
                        ed:SetOrigin(tr.HitPos)
                        ed:SetScale(intensity * 3.5)
                        util.Effect("WheelDust", ed)

                        util.ScreenShake(tr.HitPos, 22 * intensity, 18, 1.8, 1400)

                        data.lastVelZ   = 0
                        data.landedTime = CurTime()
                    end

                    -- Settle into idle once vehicle has rested on the ground
                    if data.landedTime and CurTime() - data.landedTime > 1.5 and curVel:Length() < 75 then
                        data.landedTime          = nil
                        data.state               = "idle"
                        data.anchored            = false
                        data.gravityReleased     = false
                        TIV.Deploy.BroadcastState(veh, "idle")
                        print(string.format("[TIV] Vehicle #%d settled after loft crash landing.", entIndex))
                    end
                else
                    CleanupLoftTracking(entIndex)
                end
            end
        else
            CleanupLoftTracking(entIndex)
        end
    end
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================
hook.Add("Think", "TIV_LoftCleanup", function()
    for entIndex in pairs(TIV.Loft.WindTimers) do
        local data = TIV.Deploy.Vehicles[entIndex]
        if not data or data.state ~= "anchored" then
            CleanupLoftTracking(entIndex)
        end
    end
end)

print("[TIV] Advanced loft system loaded (directional tipping, vortex physics, and self-righting)")
