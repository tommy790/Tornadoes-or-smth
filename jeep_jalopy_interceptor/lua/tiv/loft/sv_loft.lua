-- ============================================================================
-- TIV LOFT SYSTEM
-- Clean 4-Stage Physical Architecture:
-- 1. Rock-Solid Ground Planting (Zero artificial forces while anchored)
-- 2. Sequential Windward Anchor Shear (True directional failure & physical tipping)
-- 3. Clean Single-Impulse Loft (Natural Source gravity & storm physics; no continuous flight loop)
-- 4. Armor Panel Shearing (Detaches under extreme vortex turbulence as debris)
-- ============================================================================

TIV.Loft = TIV.Loft or {}

util.AddNetworkString("TIV_LoftEvent")
util.AddNetworkString("TIV_AnchorWarning")

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

local function CleanupLoftTracking(entIdx)
    TIV.Loft.WindTimers[entIdx]    = nil
    TIV.Loft.FailingGroups[entIdx] = nil
    for wave = 1, 3 do
        timer.Remove("TIV_WaveFail_" .. entIdx .. "_" .. wave)
    end
    timer.Remove("TIV_GroupFail_" .. entIdx .. "_rear")
    timer.Remove("TIV_GroupFail_" .. entIdx .. "_mid")
    timer.Remove("TIV_GroupFail_" .. entIdx .. "_front")
end
TIV.Loft.CleanupTracking = CleanupLoftTracking

-- ============================================================================
-- ARMOR TEARING (EXTREME VORTEX / AERODYNAMIC STRESS)
-- ============================================================================
function TIV.Loft.RipArmorPanel(veh, prop, windDir)
    if not IsValid(prop) then return end

    prop:SetParent(nil)
    constraint.RemoveAll(prop)
    prop.PhysgunDisabled      = nil
    prop.TIV_OwnerVehicle     = nil
    prop.IsTIVArmor           = nil
    prop.GStormsIgnore        = nil
    prop.XT3Ignore            = nil
    prop.XT3DoNotApplyPhysics = nil

    local phys = prop:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(35)
        phys:EnableMotion(true)
        phys:EnableGravity(true)
        phys:Wake()

        local tearDir = (windDir:GetNormalized() + Vector(0, 0, 0.35) + VectorRand() * 0.2):GetNormalized()
        phys:ApplyForceCenter(tearDir * phys:GetMass() * 2400)
        phys:ApplyTorqueCenter(VectorRand() * 1200)
    end

    prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    local ed = EffectData()
    ed:SetOrigin(prop:GetPos())
    ed:SetMagnitude(8)
    ed:SetScale(2.5)
    util.Effect("Sparks", ed)

    prop:EmitSound("physics/metal/metal_sheet_impact_hard" .. math.random(6, 8) .. ".wav", 95, math.random(70, 85))
    util.ScreenShake(prop:GetPos(), 8, 10, 0.5, 300)

    -- Prune from vehicle armor cache if present
    if IsValid(veh) and veh._TIVArmorProps then
        for i = #veh._TIVArmorProps, 1, -1 do
            if veh._TIVArmorProps[i] == prop then
                table.remove(veh._TIVArmorProps, i)
            end
        end
    end

    SafeRemoveEntityDelayed(prop, 15)
end

function TIV.Loft.CheckArmorTear(veh, windMPH, windForceVec)
    if not IsValid(veh) or not veh._TIVArmorProps or #veh._TIVArmorProps == 0 then return end
    if windMPH < 210 then return end -- Only extreme vortex core forces

    -- Probabilistic check per tick to peel off an exposed panel
    if math.random() < 0.08 then
        local idx = math.random(1, #veh._TIVArmorProps)
        local prop = veh._TIVArmorProps[idx]
        if IsValid(prop) then
            TIV.Loft.RipArmorPanel(veh, prop, windForceVec)
        end
    end
end

-- ============================================================================
-- FAIL SPIKE LIST (SEQUENTIAL WAVE EXECUTION)
-- ============================================================================
function TIV.Loft.FailSpikeList(veh, data, spikesToFail, duration)
    local cheatGodmode = GetConVar("tiv_cheat_godmode_anchors")
    if cheatGodmode and cheatGodmode:GetBool() then
        return
    end
    if not IsValid(veh) or not data or #spikesToFail == 0 then return end

    if IsValid(veh) then
        veh:EmitSound("physics/metal/metal_box_break1.wav", 85, 55)
    end

    local staggerPerSpike = (duration or 0.7) / math.max(1, #spikesToFail)

    for i, sd in ipairs(spikesToFail) do
        local spikeIdx = sd.index
        local delay = (i - 1) * staggerPerSpike + math.Rand(0, staggerPerSpike * 0.2)

        timer.Simple(delay, function()
            if not IsValid(veh) or not data then return end
            if data.state ~= "anchored" then return end

            -- Mark permanently failed: Anchor Guard will NEVER recreate or re-freeze it
            sd.failed = true

            -- When the first anchor snaps, restore chassis gravity so it can naturally
            -- tilt and roll on the remaining intact leeward anchors without fighting physics.
            if not data.gravityReleased then
                data.gravityReleased = true
                local vehPhys = veh:GetPhysicsObject()
                if IsValid(vehPhys) then
                    vehPhys:EnableGravity(true)
                    vehPhys:EnableMotion(true)
                    vehPhys:Wake()
                end
            end

            local spikeEnt = sd.entity
            if IsValid(spikeEnt) then
                local spikePhys = spikeEnt:GetPhysicsObject()
                if IsValid(spikePhys) then
                    spikePhys:EnableMotion(true)
                    spikePhys:EnableGravity(true)
                    spikePhys:Wake()

                    local windScale = GetWindScale(veh)
                    local windForce = TIV.Wind.GetForceVector(veh) * spikePhys:GetMass() * 1.5 * windScale
                    local upForce   = Vector(0, 0, 1) * spikePhys:GetMass() * 600
                    local pullToVeh = (veh:GetPos() - spikeEnt:GetPos()):GetNormalized() * spikePhys:GetMass() * 150

                    spikePhys:ApplyForceCenter(windForce + upForce + pullToVeh)
                    spikePhys:ApplyTorqueCenter(VectorRand() * 400)
                end

                spikeEnt:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

                local sparkFX = EffectData()
                sparkFX:SetOrigin(spikeEnt:GetPos())
                sparkFX:SetMagnitude(8)
                sparkFX:SetScale(3)
                util.Effect("Sparks", sparkFX)

                spikeEnt:EmitSound("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", 90, math.random(60, 80))
                util.ScreenShake(spikeEnt:GetPos(), 10, 12, 0.6, 350)
            end

            -- Break the ballsocket constraint connecting vehicle to this spike
            TIV.Anchor.BreakSpike(veh, data, spikeIdx)

            -- Reparent spike to vehicle after a brief moment if not releasing as debris
            timer.Simple(0.12, function()
                if not IsValid(veh) or not IsValid(spikeEnt) or not sd then return end
                if TIV.SpikeAnim and TIV.SpikeAnim.ReparentSpike then
                    TIV.SpikeAnim.ReparentSpike(veh, spikeEnt, sd)
                end
                if data.spikeAnims and spikeIdx then
                    data.spikeAnims[spikeIdx] = "idle"
                end
            end)

            -- Count remaining ballsocket constraints
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

            -- If all anchor constraints are severed, trigger full loft immediately
            if remainingBS == 0 then
                TIV.Loft.TriggerLoft(veh, data)
            end
        end)
    end
end

-- ============================================================================
-- START DIRECTIONAL WINDWARD FAILURE
-- Calculates wind angle relative to vehicle and shears windward anchors first.
-- ============================================================================
function TIV.Loft.StartDirectionalFailure(veh, data)
    if not IsValid(veh) or not data then return end
    if data.state ~= "anchored" then return end

    local entIndex = veh:EntIndex()
    if TIV.Loft.WindTimers[entIndex] then return end

    TIV.Loft.WindTimers[entIndex]    = CurTime()
    TIV.Loft.FailingGroups[entIndex] = true

    -- 1. Gather all live, deployed spikes
    local liveSpikes = {}
    for _, sd in ipairs(data.spikes or {}) do
        if sd.phase == "deployed" and not sd.failed and IsValid(sd.entity) then
            table.insert(liveSpikes, sd)
        end
    end

    if #liveSpikes == 0 then
        TIV.Loft.TriggerLoft(veh, data)
        return
    end

    -- 2. Determine relative wind vector to calculate windward vs leeward exposure
    local windForceVec = TIV.Wind.GetForceVector(veh)
    local localWind    = veh:WorldToLocal(veh:GetPos() + windForceVec):GetNormalized()

    -- Calculate exposure for each spike along the wind vector
    -- Smaller (most negative) dot product = windward side (under tension, fails first)
    for _, sd in ipairs(liveSpikes) do
        local lpos = sd.configPos or veh:WorldToLocal(sd.entity:GetPos())
        sd._windExposure = lpos:Dot(localWind)
    end

    table.sort(liveSpikes, function(a, b)
        return (a._windExposure or 0) < (b._windExposure or 0)
    end)

    -- 3. Partition into 3 sequential waves:
    -- Wave 1: Windward anchors (most exposed)
    -- Wave 2: Mid-flank anchors
    -- Wave 3: Leeward anchors
    local count = #liveSpikes
    local wave1 = {}
    local wave2 = {}
    local wave3 = {}

    if count <= 2 then
        table.insert(wave1, liveSpikes[1])
        if count == 2 then table.insert(wave3, liveSpikes[2]) end
    elseif count <= 4 then
        table.insert(wave1, liveSpikes[1])
        table.insert(wave2, liveSpikes[2])
        if count >= 3 then table.insert(wave2, liveSpikes[3]) end
        if count == 4 then table.insert(wave3, liveSpikes[4]) end
    else
        -- 6 spikes: 2 windward, 2 mid, 2 leeward
        table.insert(wave1, liveSpikes[1])
        table.insert(wave1, liveSpikes[2])
        table.insert(wave2, liveSpikes[3])
        table.insert(wave2, liveSpikes[4])
        table.insert(wave3, liveSpikes[5])
        table.insert(wave3, liveSpikes[6])
    end

    print(string.format("[TIV] Vehicle #%d exceeding threshold. Starting Windward Failure (Wave 1: %d, Wave 2: %d, Wave 3: %d)",
        entIndex, #wave1, #wave2, #wave3))

    -- Wave 1: Immediate failure (0.05s)
    if #wave1 > 0 then
        timer.Create("TIV_WaveFail_" .. entIndex .. "_1", 0.05, 1, function()
            if not IsValid(veh) or data.state ~= "anchored" then return end
            TIV.Loft.FailSpikeList(veh, data, wave1, 0.7)
        end)
    end

    -- Wave 2: Mid failure (1.1s)
    if #wave2 > 0 then
        timer.Create("TIV_WaveFail_" .. entIndex .. "_2", 1.1, 1, function()
            if not IsValid(veh) or data.state ~= "anchored" then return end
            TIV.Loft.FailSpikeList(veh, data, wave2, 0.7)
        end)
    end

    -- Wave 3: Leeward final failure (2.2s)
    if #wave3 > 0 then
        timer.Create("TIV_WaveFail_" .. entIndex .. "_3", 2.2, 1, function()
            if not IsValid(veh) or data.state ~= "anchored" then return end
            TIV.Loft.FailSpikeList(veh, data, wave3, 0.7)
        end)
    end
end

-- ============================================================================
-- TRIGGER FULL LOFT
-- Clean single launch impulse. Natural Source gravity & storm physics handle flight.
-- ============================================================================
function TIV.Loft.TriggerLoft(veh, data)
    if not IsValid(veh) then return end
    if data.state == "lofted" then return end

    -- Cheat check: Godmode Anchors immunity
    local cheatGodmode = GetConVar("tiv_cheat_godmode_anchors")
    if cheatGodmode and cheatGodmode:GetBool() then
        return
    end

    local entIdx    = veh:EntIndex()
    local sessionID = data.sessionID

    print("[TIV] ================================")
    print("[TIV] === TIV LOFT TRIGGERED       ===")
    print(string.format("[TIV] === Wind: %.0f MPH at t=%.2f ===",
        TIV.Wind.GetSpeed(veh), CurTime()))
    print("[TIV] ================================")

    -- 1. Complete constraint severance: vehicle is fully freed from spikes & world
    TIV.Anchor.ForceDetach(veh, data)
    constraint.RemoveAll(veh)

    data.state    = "lofted"
    data.anchored = false

    -- 2. Restore vehicle gravity, motion, and physics
    local phys = veh:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableGravity(true)
        phys:EnableMotion(true)
        phys:Wake()

        -- Single initial launch impulse: fling up and downwind with random tumble torque
        local upForce   = Vector(0, 0, 1) * phys:GetMass() * (TIV.Config.LoftForceMultiplier or 1200)
        local windForce = TIV.Wind.GetForceVector(veh) * phys:GetMass() * 0.6
        local tumble    = VectorRand() * (TIV.Config.LoftTumbleForce or 350)

        phys:ApplyForceCenter(upForce + windForce)
        phys:ApplyTorqueCenter(tumble)
    end

    -- 3. Release or reparent spikes
    if ReleaseSpikesOnLoft() then
        if TIV.Spikes.ReleaseAll then
            TIV.Spikes.ReleaseAll(data)
        end
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

    -- 4. Automatic reset 15 seconds after loft to safely mount fresh spikes and return to idle
    timer.Simple(15, function()
        local liveVeh  = Entity(entIdx)
        local liveData = TIV.Deploy.Vehicles and TIV.Deploy.Vehicles[entIdx]

        if not liveData or liveData.sessionID ~= sessionID then return end

        if liveData.spikes then
            for _, sd in ipairs(liveData.spikes) do
                if IsValid(sd.entity) then SafeRemoveEntity(sd.entity) end
            end
        end
        liveData.spikes          = {}
        liveData.spikeAnims      = {}
        liveData.spikesCreated   = false
        liveData.state           = "idle"
        liveData.anchored        = false
        liveData.gravityReleased = false

        if IsValid(liveVeh) then
            TIV.Deploy.BroadcastState(liveVeh, "idle")
            if TIV.CustomComponents and TIV.CustomComponents.EnsureArmor then
                TIV.CustomComponents.EnsureArmor(liveVeh)
            end
        end
    end)
end

-- ============================================================================
-- MAIN LOFT THINK
-- ============================================================================
timer.Create("TIV_LoftThink", 0.05, 0, function()
    for entIndex, data in pairs(TIV.Deploy.Vehicles or {}) do
        if data.state == "anchored" then
            local veh = Entity(entIndex)
            if IsValid(veh) then
                local phys = veh:GetPhysicsObject()
                if IsValid(phys) then
                    local windMPH = TIV.Wind.GetSpeed(veh)
                    local stress  = TIV.Loft.CalculateStress(windMPH, veh)
                    local windScale = GetWindScale(veh)
                    local windForceVec = TIV.Wind.GetForceVector(veh)
                    local effectiveThreshold = (veh._TIVEffectiveStats and veh._TIVEffectiveStats.effective_loft_mph)
                        or TIV.Config.LoftWindThreshold
                        or 180

                    -- ===== ANCHOR GUARD =====
                    -- Defense in depth against external tornado mod unweld routines:
                    -- Re-freezes and restores balljoints ONLY on live, un-failed spikes.
                    -- Ignores sd.failed spikes to completely prevent the mid-air trap.
                    for _, sd in ipairs(data.spikes or {}) do
                        if sd.phase == "deployed" and not sd.failed and IsValid(sd.entity) and sd.groundPos then
                            local sp = sd.entity:GetPhysicsObject()
                            if IsValid(sp) and sp:IsMotionEnabled() then
                                local plantedZ = sd.groundPos.z - (TIV.Config.SpikeDriveDepth or 15)
                                local target   = Vector(sd.groundPos.x, sd.groundPos.y, plantedZ)
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
                            if not hasBS then
                                if TIV.Anchor and TIV.Anchor.AttachSingle then
                                    for i = #(data.constraints or {}), 1, -1 do
                                        if data.constraints[i].spikeIndex == sd.index then
                                            table.remove(data.constraints, i)
                                        end
                                    end
                                    TIV.Anchor.AttachSingle(veh, data, sd, sd.index)
                                end
                            end
                        end
                    end

                    -- ===== GROUND PLANTING & TIPPING FORCES =====
                    if not data.gravityReleased then
                        -- 1. Intact Anchored State: ZERO physical displacement forces on chassis.
                        -- Ground anchors hold the vehicle 100% frozen solid in place.
                        -- Screen shake and audio convey storm violence realistically without physics fighting.
                        if stress > 0.40 then
                            data.nextShakeTime = data.nextShakeTime or 0
                            if CurTime() > data.nextShakeTime then
                                data.nextShakeTime = CurTime() + 0.30
                                util.ScreenShake(veh:GetPos(), math.Clamp(stress * 3.0, 0.5, 3.0), 10, 0.35, 350)
                            end
                        end
                    else
                        -- 2. Partial Failure State: Windward anchors have snapped.
                        -- Gravity is active (phys:EnableGravity(true)).
                        -- Apply purely lateral wind force (Z <= 0) to naturally tilt the car around
                        -- the intact leeward anchor hinge without lifting it off the ground.
                        local lateralWind = Vector(windForceVec.x, windForceVec.y, math.min(0, windForceVec.z))
                            * phys:GetMass() * 0.5 * windScale
                        phys:ApplyForceCenter(lateralWind)
                    end

                    -- ===== STRESS SOUNDS =====
                    local soundChance
                    if stress > TIV.Config.Stress.SoundCrit then
                        soundChance = TIV.Config.StressCritChance
                    elseif stress > TIV.Config.Stress.SoundHigh then
                        soundChance = TIV.Config.StressHighSoundChance
                    else
                        soundChance = TIV.Config.StressLowSoundChance
                    end
                    if math.random() < soundChance then
                        veh:EmitSound("physics/metal/metal_box_strain" .. math.random(1, 4) .. ".wav", 70, math.random(40, 65))
                    end

                    -- ===== ARMOR PANEL TEARING CHECK =====
                    TIV.Loft.CheckArmorTear(veh, windMPH, windForceVec)

                    -- ===== BELOW / ABOVE THRESHOLD LOGIC =====
                    if windMPH < effectiveThreshold then
                        if TIV.Loft.WindTimers[entIndex] then
                            print(string.format("[TIV] Wind dropped to %.0f MPH - sequence reset for #%d", windMPH, entIndex))
                            CleanupLoftTracking(entIndex)
                        end

                        if TIV.Spikes.GetCount(data) > 0 then
                            if not TIV.Anchor.CheckIntegrity(veh, data) then
                                if TIV.Compat and TIV.Compat.Enabled then
                                    TIV.Anchor.ForceDetach(veh, data)
                                    data.state              = "idle"
                                    data.anchored           = false
                                    data.spikesCreated      = false
                                    data.compatRecoverUntil = CurTime() + (TIV.Compat.RecoveryCooldown or 3)
                                    TIV.Deploy.BroadcastState(veh, "idle")
                                    print(string.format("[TIV] Compat recovery: integrity lost on #%d, returning to idle for %.1fs.",
                                        entIndex, TIV.Compat.RecoveryCooldown or 3))
                                else
                                    TIV.Loft.TriggerLoft(veh, data)
                                end
                            end
                        end
                    else
                        if TIV.Spikes.GetCount(data) == 0 then
                            if not TIV.Loft.FailingGroups[entIndex] then
                                print(string.format("[TIV] 0-spike mode - instant loft at %.0f MPH", windMPH))
                                TIV.Loft.TriggerLoft(veh, data)
                            end
                        else
                            if not TIV.Anchor.CheckIntegrity(veh, data) then
                                print(string.format("[TIV] Anchors blown by force at %.0f MPH - forcing loft for #%d", windMPH, entIndex))
                                TIV.Loft.TriggerLoft(veh, data)
                            else
                                TIV.Loft.StartDirectionalFailure(veh, data)
                            end
                        end
                    end
                end
            else
                CleanupLoftTracking(entIndex)
            end
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

print("[TIV] Clean 4-Stage Loft system loaded")
