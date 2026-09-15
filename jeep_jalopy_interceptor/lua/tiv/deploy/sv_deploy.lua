-- ============================================================================
-- TIV DEPLOY SYSTEM
-- ============================================================================

TIV.Deploy = TIV.Deploy or {}

util.AddNetworkString("TIV_DeployStatus")
util.AddNetworkString("TIV_DeployRequest")

TIV.Deploy.Vehicles  = TIV.Deploy.Vehicles  or {}
TIV.Deploy.Cooldowns = TIV.Deploy.Cooldowns or {}

local COOLDOWN_TIME = 1.5

-- ============================================================================
-- STATE INIT
-- ============================================================================
function TIV.Deploy.GetState(veh)
    if not IsValid(veh) then return nil end
    local idx = veh:EntIndex()
    if not TIV.Deploy.Vehicles[idx] then
        TIV.Deploy.Vehicles[idx] = {
            state            = "idle",
            originalPos      = nil,
            spikes           = {},
            constraints      = {},
            spikeAnims       = {},
            anchored         = false,
            spikesCreated    = false,
            sessionID        = nil,
            gravityReleased  = false,
            lowerAmount      = nil,
            lowerConstraint  = nil,
            lowerStartDist   = nil,
            lowerTargetDist  = nil,
        }
    end
    return TIV.Deploy.Vehicles[idx]
end

function TIV.Deploy.IsJeep(ent)
    return TIV.IsSupportedVehicle and TIV.IsSupportedVehicle(ent) or false
end

function TIV.Deploy.ResolveVehicle(ply)
    if TIV.ResolveVehicle then return TIV.ResolveVehicle(ply) end
    if not IsValid(ply) then return nil end
    local seat = ply:GetVehicle()
    if not IsValid(seat) then return nil end
    return seat
end

-- ============================================================================
-- BROADCAST
-- ============================================================================
function TIV.Deploy.BroadcastState(veh, state)
    net.Start("TIV_DeployStatus")
        net.WriteEntity(veh)
        net.WriteString(state)
    net.Broadcast()

    hook.Run("TIV_StateChanged", veh, state)
end

-- ============================================================================
-- HANDBRAKE
-- ============================================================================
local function ApplyHandbrake(veh)
    if not IsValid(veh) then return end
    local phys = veh:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(Vector(0, 0, 0))
        phys:SetAngleVelocity(Vector(0, 0, 0))
    end
    if veh.SetHandbrake then veh:SetHandbrake(true) end
end

local function ReleaseHandbrake(veh)
    if not IsValid(veh) then return end
    if veh.SetHandbrake then veh:SetHandbrake(false) end
end

-- ============================================================================
-- GROUND SAMPLING & STABILIZATION HELPERS
-- ============================================================================
local function SampleGroundUnderVehicle(veh)
    local min = veh:OBBMins()
    local max = veh:OBBMaxs()
    local halfW = math.max(20, (max.x - min.x) * 0.38)
    local fwdY  = math.max(25, max.y * 0.6)
    local rearY = math.min(-25, min.y * 0.6)
    local bottomZ = min.z + 10

    local probes = {
        FR = Vector(halfW, fwdY, bottomZ),
        FL = Vector(-halfW, fwdY, bottomZ),
        RR = Vector(halfW, rearY, bottomZ),
        RL = Vector(-halfW, rearY, bottomZ),
    }

    local hits = {}
    local count = 0
    local traceLen = 140

    for k, localPos in pairs(probes) do
        local worldPos = veh:LocalToWorld(localPos)
        local tr = util.TraceLine({
            start  = worldPos,
            endpos = worldPos - Vector(0, 0, traceLen),
            filter = function(ent)
                if ent == veh or ent:IsPlayer() or ent.IsTIVSpike then return false end
                return true
            end,
            mask = MASK_SOLID,
        })
        if tr.Hit then
            hits[k] = tr.HitPos
            count = count + 1
        end
    end

    return hits, count
end

local function CalculateStabilizedAngle(veh, hits, count)
    local curAng = veh:GetAngles()
    if count < 3 or not hits.FR or not hits.FL or not hits.RR or not hits.RL then
        -- Safe fallback: keep heading, level pitch and roll
        return Angle(0, curAng.y, 0)
    end

    local fwdVec   = ((hits.FR + hits.FL) * 0.5) - ((hits.RR + hits.RL) * 0.5)
    local rightVec = ((hits.FR + hits.RR) * 0.5) - ((hits.FL + hits.RL) * 0.5)
    local normal   = rightVec:Cross(fwdVec):GetNormalized()
    if normal.z < 0 then normal = -normal end

    -- Slope clamp: if slope is excessively steep (> max slope), clamp to world upright
    local maxSlopeDeg = tonumber(TIV.Config.MaxStabilizeSlope) or 45
    local minZ = math.cos(math.rad(maxSlopeDeg))
    if normal.z < minZ then
        normal = Vector(0, 0, 1)
    end

    local yawRad = math.rad(curAng.y)
    local flatForward = Vector(math.cos(yawRad), math.sin(yawRad), 0)
    local projFwd = (flatForward - normal * flatForward:Dot(normal)):GetNormalized()
    if projFwd:LengthSqr() < 0.001 then
        projFwd = Vector(math.cos(yawRad), math.sin(yawRad), 0)
    end

    local targetAng = projFwd:AngleEx(normal)
    return targetAng
end

-- ============================================================================
-- DYNAMIC CHASSIS GROUND CLEARANCE MEASUREMENT
-- Measures true clearance between lowest chassis frame points and the ground.
-- Prevents hardcoded lowering from driving wheels/skirt into terrain.
-- ============================================================================
local function MeasureChassisClearance(veh)
    local min = veh:OBBMins()
    local max = veh:OBBMaxs()

    local testPoints = {
        Vector(0, max.y * 0.4, min.z + 5),
        Vector(0, min.y * 0.4, min.z + 5),
        Vector(max.x * 0.45, 0, min.z + 5),
        Vector(min.x * 0.45, 0, min.z + 5),
        Vector(0, 0, min.z + 5),
    }

    local minClearance = 999
    local up = veh:GetUp()

    for _, pt in ipairs(testPoints) do
        local worldPt = veh:LocalToWorld(pt)
        local tr = util.TraceLine({
            start  = worldPt,
            endpos = worldPt - (up * 100),
            filter = function(ent)
                if ent == veh or ent:IsPlayer() or ent.IsTIVSpike then return false end
                return true
            end,
            mask = MASK_SOLID,
        })
        if tr.Hit then
            local dist = (worldPt - tr.HitPos):Dot(up)
            local clearance = dist - 5
            if clearance < minClearance then
                minClearance = clearance
            end
        end
    end

    if minClearance >= 999 or minClearance < 0 then
        minClearance = 7.0 -- Safe standard fallback
    end

    return minClearance
end

-- ============================================================================
-- ENSURE SPIKES EXIST
-- ============================================================================
function TIV.Deploy.EnsureSpikes(veh, data)
    local desiredSpikeCount = math.Clamp(
        TIV.Config.SpikeCount,
        TIV.Config.SpikeCountConvarMin,
        TIV.Config.SpikeCountConvarMax
    )

    if desiredSpikeCount == 0 then
        if not data.spikesCreated then
            TIV.Spikes.Create(veh, data)
            data.spikesCreated = true
        end
        return
    end

    if data.spikesCreated then
        local validCount = 0
        for _, sd in ipairs(data.spikes or {}) do
            if IsValid(sd.entity) then validCount = validCount + 1 end
        end

        if validCount > 0 and validCount ~= desiredSpikeCount and data.state == "idle" then
            print(string.format(
                "[TIV] Spike count changed (%d -> %d), rebuilding spikes...",
                validCount, desiredSpikeCount
            ))
            TIV.Anchor.DetachAll(veh, data)
            TIV.Spikes.RemoveAll(data, veh:EntIndex())
            data.spikesCreated = false
        elseif validCount > 0 then
            return
        else
            print("[TIV] Spikes missing, recreating...")
            TIV.Anchor.DetachAll(veh, data)
            data.spikesCreated = false
        end
    end

    TIV.Spikes.Create(veh, data)
    data.spikesCreated = true

    if TIV.Wire and TIV.Wire.EnsureController then
        TIV.Wire.EnsureController(veh)
    end
end

-- ============================================================================
-- COOLDOWN
-- ============================================================================
local function IsOnCooldown(ply)
    local steamID = ply:SteamID()
    local last    = TIV.Deploy.Cooldowns[steamID] or 0
    if CurTime() - last < COOLDOWN_TIME then return true end
    TIV.Deploy.Cooldowns[steamID] = CurTime()
    return false
end

-- ============================================================================
-- DRIVER CHECK
-- ============================================================================
local function IsDriverOf(ply, veh)
    if not IsValid(ply) or not IsValid(veh) then return false end
    if veh.GetDriver then
        local driver = veh:GetDriver()
        if IsValid(driver) and driver == ply then return true end
    end
    local plyVeh = ply:GetVehicle()
    if IsValid(plyVeh) then
        if plyVeh == veh then return true end
        if plyVeh:GetParent() == veh then
            if plyVeh.GetDriverSeat and plyVeh:GetDriverSeat() == plyVeh then
                return true
            end
            if veh.GetDriver then
                local driver = veh:GetDriver()
                if not IsValid(driver) then return true end
            end
        end
    end
    return false
end
TIV.Deploy.IsDriverOf = IsDriverOf

function TIV.Deploy.HandleInput(ply, veh)
    if not IsValid(veh) or not IsValid(ply) then return end
    if IsOnCooldown(ply) then return end
    if not TIV.Deploy.IsJeep(veh) then return end

    if not IsDriverOf(ply, veh) then return end

    local data = TIV.Deploy.GetState(veh)
    TIV.Deploy.EnsureSpikes(veh, data)

    if data.state == "idle" then
        TIV.Deploy.StartDeploy(ply, veh)
    elseif data.state == "anchored" then
        TIV.Deploy.StartRetract(ply, veh)
    end
end

-- ============================================================================
-- STABILIZE PHASE
-- Automatically aligns vehicle roll/pitch to sit stable and flat against
-- terrain before lowering, preventing deployment while tilted.
-- ============================================================================
function TIV.Deploy.StartStabilize(ply, veh, onStabilized)
    local data = TIV.Deploy.GetState(veh)
    local phys = veh:GetPhysicsObject()

    data.state = "stabilizing"
    TIV.Deploy.BroadcastState(veh, "stabilizing")
    ApplyHandbrake(veh)

    local hits, count = SampleGroundUnderVehicle(veh)
    local startAng  = veh:GetAngles()
    local targetAng = CalculateStabilizedAngle(veh, hits, count)

    local duration  = math.Clamp(tonumber(TIV.Config.StabilizeTime) or 0.6, 0.2, 3.0)
    local startTime = CurTime()
    local timerName = "TIV_Stabilize_" .. veh:EntIndex()

    veh:EmitSound("tiv2sounds/tiv2frontpanel.wav", 75, 100)

    timer.Create(timerName, 0.02, 0, function()
        if not IsValid(veh) then
            timer.Remove(timerName)
            return
        end

        local elapsed    = CurTime() - startTime
        local frac       = math.Clamp(elapsed / duration, 0, 1)
        local smoothFrac = frac * frac * (3 - 2 * frac)

        local p = veh:GetPhysicsObject()
        if IsValid(p) then
            p:SetVelocity(Vector(0, 0, 0))
            p:SetAngleVelocity(Vector(0, 0, 0))
            p:EnableMotion(true)
        end

        local newAng = LerpAngle(smoothFrac, startAng, targetAng)
        veh:SetAngles(newAng)

        if frac >= 1 then
            timer.Remove(timerName)
            if onStabilized then onStabilized() end
        end
    end)
end

-- ============================================================================
-- DEPLOY (STABILIZE -> PHYSICAL LOWERING -> SPIKES)
-- ============================================================================
function TIV.Deploy.StartDeploy(ply, veh)
    local data = TIV.Deploy.GetState(veh)
    local phys = veh:GetPhysicsObject()

    if IsValid(phys) and TIV.Compat and TIV.Compat.Enabled then
        local now = CurTime()
        if data.compatRecoverUntil and now < data.compatRecoverUntil then
            return
        end
        local linearSpeed  = phys:GetVelocity():Length()
        local angularSpeed = phys:GetAngleVelocity():Length()
        if linearSpeed  > TIV.Compat.MaxDeployLinearVelocity
        or angularSpeed > TIV.Compat.MaxDeployAngularVelocity then
            return
        end
    end

    -- Automatically stabilize first so it doesn't deploy while tilted
    TIV.Deploy.StartStabilize(ply, veh, function()
        if not IsValid(veh) then return end
        TIV.Deploy.PerformLowering(ply, veh)
    end)
end

-- ============================================================================
-- PERFORM LOWERING
-- Compresses suspension via active physics and Wiremod/VPhysics hydraulic tension.
-- Wheels remain in continuous collision with the ground and DO NOT clip.
-- ============================================================================
function TIV.Deploy.PerformLowering(ply, veh)
    local data = TIV.Deploy.GetState(veh)
    local phys = veh:GetPhysicsObject()

    data.state           = "lowering"
    data.originalPos     = veh:GetPos()
    data.gravityReleased = false
    TIV.Deploy.BroadcastState(veh, "lowering")

    -- Measure actual clearance between chassis skirts and ground
    local clearance    = MeasureChassisClearance(veh)
    local groundBuffer = tonumber(TIV.Config.SkirtGroundBuffer) or 1.2
    local maxTravel    = math.Clamp(clearance - groundBuffer, 1.0, tonumber(TIV.Config.MaxSuspensionTravel) or 10.0)
    data.lowerAmount   = maxTravel

    local centerPos = veh:GetPos()
    local groundTr  = util.TraceLine({
        start  = centerPos,
        endpos = centerPos - Vector(0, 0, 150),
        filter = veh,
        mask   = MASK_SOLID,
    })
    local groundPoint = groundTr.Hit and groundTr.HitPos or (centerPos - Vector(0, 0, clearance))
    local initialDist = centerPos:Distance(groundPoint)

    -- Physics remains active throughout lowering!
    if IsValid(phys) then
        phys:EnableMotion(true)
        phys:EnableGravity(true)
        phys:Wake()
    end

    -- Elastic hydraulic pull constraint
    local worldEnt = game.GetWorld()
    local constant, dampen
    if istable(rawget(_G, "WireLib")) and isfunction(WireLib.CalcElasticConsts) then
        constant, dampen = WireLib.CalcElasticConsts(veh, worldEnt)
    else
        local mass = IsValid(phys) and phys:GetMass() or 1200
        constant = mass * 150
        dampen   = mass * 30
    end

    if IsValid(data.lowerConstraint) then
        data.lowerConstraint:Remove()
        data.lowerConstraint = nil
    end

    local hydraulic = constraint.Elastic(
        veh, worldEnt,
        0, 0,
        Vector(0, 0, 0),
        groundPoint,
        constant,
        dampen,
        0,
        "",
        0,
        true -- stretchonly
    )
    data.lowerConstraint = hydraulic
    data.lowerStartDist  = initialDist
    data.lowerTargetDist = math.max(0, initialDist - maxTravel)

    local startTime     = CurTime()
    local lowerDuration = TIV.Config.LowerTime or 3.0
    local timerName     = "TIV_Lower_" .. veh:EntIndex()

    timer.Create(timerName, 0.02, 0, function()
        if not IsValid(veh) then
            timer.Remove(timerName)
            return
        end

        local elapsed    = CurTime() - startTime
        local frac       = math.Clamp(elapsed / lowerDuration, 0, 1)
        local smoothFrac = frac * frac * (3 - 2 * frac)

        local p = veh:GetPhysicsObject()
        if IsValid(p) then
            p:EnableMotion(true)
            local vel = p:GetVelocity()
            p:SetVelocity(Vector(vel.x * 0.6, vel.y * 0.6, vel.z))
            p:SetAngleVelocity(p:GetAngleVelocity() * 0.7)
            -- Steady downward assist pulling suspension down to bump stops
            local pullForce = Vector(0, 0, -p:GetMass() * 55 * (1 - smoothFrac * 0.3))
            p:ApplyForceCenter(pullForce)
        end

        if IsValid(hydraulic) then
            local curTarget = Lerp(smoothFrac, data.lowerStartDist, data.lowerTargetDist)
            hydraulic:Fire("SetSpringLength", curTarget, 0)
            hydraulic:Fire("SetSpringConstant", constant * (1 + smoothFrac * 0.5), 0)
        end

        if math.random() < 0.05 then
            veh:EmitSound("physics/metal/metal_box_strain" .. math.random(1, 4) .. ".wav",
                55, math.random(70, 90))
        end

        if frac >= 1 then
            timer.Remove(timerName)
            util.ScreenShake(veh:GetPos(), 3, 5, 0.5, 200)

            if TIV.Spikes.GetCount(data) == 0 then
                data.state    = "anchored"
                data.anchored = true
                ApplyHandbrake(veh)
                TIV.Deploy.BroadcastState(veh, "anchored")
            else
                data.state = "deploying_spikes"
                TIV.Deploy.BroadcastState(veh, "deploying_spikes")
                TIV.Spikes.Deploy(veh, data, function()
                    if not IsValid(veh) then return end
                    data.state    = "anchored"
                    data.anchored = true
                    TIV.Anchor.UnfreezeForDeploy(veh)
                    ApplyHandbrake(veh)
                    TIV.Deploy.BroadcastState(veh, "anchored")
                end)
            end
        end
    end)
end

-- ============================================================================
-- RETRACT
-- ============================================================================
function TIV.Deploy.StartRetract(ply, veh)
    local data = TIV.Deploy.GetState(veh)
    data.state = "retracting"
    TIV.Deploy.BroadcastState(veh, "retracting")

    ReleaseHandbrake(veh)

    local phys = veh:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableGravity(true)
        phys:EnableMotion(true)
        phys:Wake()
    end

    TIV.Anchor.DetachAll(veh, data)
    data.anchored = false

    if TIV.Spikes.GetCount(data) == 0 then
        TIV.Deploy.RaiseVehicle(ply, veh)
    else
        timer.Simple(0.3, function()
            if not IsValid(veh) then return end
            TIV.Spikes.Retract(veh, data, function()
                if not IsValid(veh) then return end
                TIV.Deploy.RaiseVehicle(ply, veh)
            end)
        end)
    end
end

-- ============================================================================
-- RAISE VEHICLE
-- Smoothly relaxes hydraulic pull constraint, allowing suspension to naturally
-- push vehicle body back up to driving ride height.
-- ============================================================================
function TIV.Deploy.RaiseVehicle(ply, veh)
    if not IsValid(veh) then return end

    local data  = TIV.Deploy.GetState(veh)
    data.state  = "raising"
    TIV.Deploy.BroadcastState(veh, "raising")

    local phys = veh:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableGravity(true)
        phys:EnableMotion(true)
        phys:Wake()
    end

    local hydraulic = data.lowerConstraint
    local startDist = data.lowerTargetDist or 0
    local endDist   = data.lowerStartDist or (startDist + (data.lowerAmount or 6))

    local startTime     = CurTime()
    local raiseDuration = 2.5
    local timerName     = "TIV_Raise_" .. veh:EntIndex()

    timer.Create(timerName, 0.02, 0, function()
        if not IsValid(veh) then
            timer.Remove(timerName)
            return
        end

        local elapsed    = CurTime() - startTime
        local frac       = math.Clamp(elapsed / raiseDuration, 0, 1)
        local smoothFrac = frac * frac * (3 - 2 * frac)

        if IsValid(hydraulic) then
            local curTarget = Lerp(smoothFrac, startDist, endDist)
            hydraulic:Fire("SetSpringLength", curTarget, 0)
        end

        local p = veh:GetPhysicsObject()
        if IsValid(p) then
            p:EnableMotion(true)
            local vel = p:GetVelocity()
            p:SetVelocity(Vector(vel.x * 0.7, vel.y * 0.7, vel.z))
            p:SetAngleVelocity(p:GetAngleVelocity() * 0.8)
        end

        if frac >= 1 then
            timer.Remove(timerName)

            if IsValid(data.lowerConstraint) then
                data.lowerConstraint:Remove()
                data.lowerConstraint = nil
            end

            local p = veh:GetPhysicsObject()
            if IsValid(p) then
                p:EnableGravity(true)
                p:SetVelocity(Vector(0, 0, 0))
                p:SetAngleVelocity(Vector(0, 0, 0))
                p:EnableMotion(true)
                p:Wake()
            end

            data.state    = "idle"
            data.anchored = false
            TIV.Deploy.BroadcastState(veh, "idle")

            local count = TIV.Spikes.GetCount(data)
            if count == 0
                and math.Clamp(TIV.Config.SpikeCount, 0, TIV.Config.SpikeCountConvarMax) > 0 then
                print("[TIV] Spikes lost during retract, recreating...")
                data.spikesCreated = false
                TIV.Deploy.EnsureSpikes(veh, data)
            end
        end
    end)
end

-- ============================================================================
-- AUTO CREATE SPIKES ON ENTER
-- ============================================================================
hook.Add("PlayerEnteredVehicle", "TIV_FirstEnter", function(ply, veh)
    local tivVeh = veh
    if not TIV.Deploy.IsJeep(tivVeh) then
        local parent = IsValid(veh) and veh:GetParent() or nil
        if IsValid(parent) and TIV.Deploy.IsJeep(parent) then
            tivVeh = parent
        else
            tivVeh = TIV.Deploy.ResolveVehicle(ply)
        end
    end
    if not IsValid(tivVeh) then return end
    local data = TIV.Deploy.GetState(tivVeh)
    TIV.Deploy.EnsureSpikes(tivVeh, data)
end)

-- ============================================================================
-- INPUT
-- ============================================================================
hook.Add("PlayerButtonDown", "TIV_DeployBind", function(ply, button)
    if not TIV.Config then return end
    if button ~= TIV.Config.DeployKey then return end
    local veh = TIV.Deploy.ResolveVehicle(ply)
    if not IsValid(veh) then return end
    TIV.Deploy.HandleInput(ply, veh)
end)

net.Receive("TIV_DeployRequest", function(len, ply)
    local veh = TIV.Deploy.ResolveVehicle(ply)
    if not IsValid(veh) then return end
    TIV.Deploy.HandleInput(ply, veh)
end)

-- ============================================================================
-- CLEANUP ON VEHICLE REMOVE
-- ============================================================================
hook.Add("EntityRemoved", "TIV_VehicleCleanup", function(ent)
    if not IsValid(ent) then return end
    local entIdx = ent:EntIndex()
    local data   = TIV.Deploy.Vehicles[entIdx]
    if not data then return end

    if ent.SetHandbrake then ReleaseHandbrake(ent) end
    TIV.Anchor.DetachAll(ent, data)
    TIV.Spikes.RemoveAll(data, entIdx)
    TIV.Deploy.Vehicles[entIdx] = nil

    if TIV.Wire and TIV.Wire.OnVehicleRemoved then
        TIV.Wire.OnVehicleRemoved(ent)
    end
    hook.Run("TIV_VehicleRemoved", ent)
end)

print("[TIV] Deploy system loaded")
