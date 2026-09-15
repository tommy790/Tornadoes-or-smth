-- ============================================================================
-- TIV ANCHOR SYSTEM
-- ============================================================================

TIV.Anchor = TIV.Anchor or {}

local function GetPivotLimit()
    return math.Clamp(tonumber(TIV.Config.AnchorPivotLimit) or 28, 5, 60)
end

local function GetElasticConsts(ent1, ent2)
    local wire = rawget(_G, "WireLib")
    if istable(wire) and isfunction(wire.CalcElasticConsts) then
        return wire.CalcElasticConsts(ent1, ent2)
    end
    local m1 = (IsValid(ent1) and IsValid(ent1:GetPhysicsObject())) and ent1:GetPhysicsObject():GetMass() or 1200
    local m2 = (IsValid(ent2) and IsValid(ent2:GetPhysicsObject())) and ent2:GetPhysicsObject():GetMass() or 50
    local minMass = math.min(m1, m2)
    return minMass * 150, minMass * 30
end

local function CreateWorldLatch(spike, worldEnt, forceLimit)
    if isfunction(rawget(_G, "MakeWireLatch")) then
        local const = MakeWireLatch(spike, worldEnt, 0, 0, forceLimit or 0)
        if IsValid(const) then return const end
    end
    return constraint.Weld(spike, worldEnt, 0, 0, forceLimit or 0, false, false)
end

-- ============================================================================
-- BUILD BALLSOCKET
-- ============================================================================
local function CreateSpikeBallsocket(veh, spike, localAttachPos, limitDeg, forceLimit)
    if not IsValid(veh) or not IsValid(spike) then return nil end
    return constraint.AdvBallsocket(
        veh, spike,
        0, 0,
        localAttachPos,
        Vector(0, 0, 0),
        forceLimit,
        0,
        -limitDeg, -limitDeg, -limitDeg,
         limitDeg,  limitDeg,  limitDeg,
        0, 0, 0,
        0, 0, 0,
        1
    )
end

-- ============================================================================
-- ATTACH SINGLE SPIKE
-- ============================================================================
function TIV.Anchor.AttachSingle(veh, data, spikeData, spikeTableIndex)
    if not IsValid(veh) or not IsValid(spikeData.entity) then return end

    data.constraints = data.constraints or {}

    local spike          = spikeData.entity
    local index          = spikeData.index
    local spikeWorldPos  = spike:GetPos()
    local localAttachPos = veh:WorldToLocal(spikeWorldPos)

    local spikePhys = spike:GetPhysicsObject()
    if IsValid(spikePhys) then
        spikePhys:EnableMotion(true)
        spikePhys:EnableGravity(false)
        spikePhys:SetVelocity(Vector(0, 0, 0))
        spikePhys:SetAngleVelocity(Vector(0, 0, 0))
    end

    -- 1. Vehicle-to-Spike Pivot Ballsocket
    local ballsocket = CreateSpikeBallsocket(
        veh, spike,
        localAttachPos,
        GetPivotLimit(),
        TIV.Config.BallSocketForceLimit
    )

    if IsValid(ballsocket) then
        table.insert(data.constraints, {
            constraint      = ballsocket,
            spikeIndex      = index,
            spikeTableIndex = spikeTableIndex,
            type            = "ballsocket",
            localPos        = localAttachPos,
        })
    else
        print("[TIV] WARNING: Ballsocket failed for spike " .. index)
    end

    -- 2. Wiremod Elastic / Hydraulic Dampener (Vehicle to Spike)
    -- Simulates hydraulic down-force ram on the anchor arm
    local constant, dampen = GetElasticConsts(veh, spike)
    local dampener = constraint.Elastic(
        veh, spike,
        0, 0,
        localAttachPos,
        Vector(0, 0, 0),
        constant,
        dampen,
        0,
        "",
        0,
        true
    )
    if IsValid(dampener) then
        table.insert(data.constraints, {
            constraint      = dampener,
            spikeIndex      = index,
            spikeTableIndex = spikeTableIndex,
            type            = "wire_dampener",
        })
    end

    -- 3. World Anchor via Wire Latch (or high-integrity world weld)
    local worldEnt = game.GetWorld()
    if IsValid(worldEnt) then
        local worldAnchor = CreateWorldLatch(spike, worldEnt, TIV.Config.SpikeForceLimit or 0)
        if IsValid(worldAnchor) then
            table.insert(data.constraints, {
                constraint      = worldAnchor,
                spikeIndex      = index,
                spikeTableIndex = spikeTableIndex,
                isWorldAnchor   = true,
                type            = "anchor_latch",
            })
        else
            -- Fallback to AdvBallsocket if weld fails
            local bsAnchor = constraint.AdvBallsocket(
                spike, worldEnt,
                0, 0,
                Vector(0, 0, 0),
                spikeWorldPos,
                TIV.Config.SpikeForceLimit,
                0,
                -1, -1, -1,
                 1,  1,  1,
                0, 0, 0,
                0, 0, 0,
                1
            )
            if IsValid(bsAnchor) then
                table.insert(data.constraints, {
                    constraint      = bsAnchor,
                    spikeIndex      = index,
                    spikeTableIndex = spikeTableIndex,
                    isWorldAnchor   = true,
                    type            = "anchor_ballsocket",
                })
            else
                print("[TIV] WARNING: World anchor failed for spike " .. index)
            end
        end
    end

    -- 4. NoCollide between vehicle and spike
    local nocol = constraint.NoCollide(veh, spike, 0, 0)
    if IsValid(nocol) then
        table.insert(data.constraints, {
            constraint = nocol,
            spikeIndex = index,
            type       = "nocollide",
        })
    end

    -- Re-freeze spike now that all its constraints exist.
    if IsValid(spikePhys) then
        spikePhys:SetVelocity(Vector(0, 0, 0))
        spikePhys:SetAngleVelocity(Vector(0, 0, 0))
        spikePhys:EnableMotion(false)
    end
end

-- ============================================================================
-- UNFREEZE FOR DEPLOY
-- ============================================================================
function TIV.Anchor.UnfreezeForDeploy(veh)
    if not IsValid(veh) then return end
    local phys = veh:GetPhysicsObject()
    if not IsValid(phys) then return end

    phys:EnableGravity(false)
    phys:SetVelocity(Vector(0, 0, 0))
    phys:SetAngleVelocity(Vector(0, 0, 0))
    phys:EnableMotion(true)
    phys:Wake()
end

-- ============================================================================
-- ATTACH ALL
-- ============================================================================
function TIV.Anchor.AttachAll(veh, data)
    if not IsValid(veh) then return end
    if not data.spikes or #data.spikes == 0 then return end

    TIV.Anchor.DetachAll(veh, data)
    data.constraints = {}

    for i, spikeData in ipairs(data.spikes) do
        if IsValid(spikeData.entity) then
            TIV.Anchor.AttachSingle(veh, data, spikeData, i)
        end
    end
end

-- ============================================================================
-- DETACH ALL
-- ============================================================================
function TIV.Anchor.DetachAll(veh, data)
    if not data.constraints then return end
    for _, conData in ipairs(data.constraints) do
        if IsValid(conData.constraint) then
            conData.constraint:Remove()
        end
    end
    data.constraints = {}

    if IsValid(data.lowerConstraint) then
        data.lowerConstraint:Remove()
        data.lowerConstraint = nil
    end
end

-- ============================================================================
-- CHECK INTEGRITY
-- Returns true if there is at least one intact vehicle anchor coupling.
-- ============================================================================
function TIV.Anchor.CheckIntegrity(veh, data)
    if not data.constraints then return true end

    local activeJoints = 0

    for i = #data.constraints, 1, -1 do
        local conData = data.constraints[i]
        if not IsValid(conData.constraint) then
            table.remove(data.constraints, i)
        elseif conData.type == "ballsocket" or conData.type == "wire_dampener" then
            activeJoints = activeJoints + 1
        end
    end

    return activeJoints > 0
end

-- ============================================================================
-- GET COUNTS
-- ============================================================================
function TIV.Anchor.GetCounts(data)
    local counts = { total = 0, ballsockets = 0, anchors = 0, nocollide = 0, dampeners = 0 }
    if not data.constraints then return counts end
    for _, conData in ipairs(data.constraints) do
        if IsValid(conData.constraint) then
            counts.total = counts.total + 1
            if     conData.type == "ballsocket"        then counts.ballsockets = counts.ballsockets + 1
            elseif conData.type == "anchor_latch" or conData.type == "anchor_ballsocket" then counts.anchors = counts.anchors + 1
            elseif conData.type == "wire_dampener"     then counts.dampeners   = counts.dampeners + 1
            elseif conData.type == "nocollide"         then counts.nocollide   = counts.nocollide + 1
            end
        end
    end
    return counts
end

-- ============================================================================
-- FORCE DETACH
-- ============================================================================
function TIV.Anchor.ForceDetach(veh, data)
    for _, conData in ipairs(data.constraints or {}) do
        if IsValid(conData.constraint) then
            conData.constraint:Remove()
        end
    end
    data.constraints = {}
    data.anchored    = false

    if IsValid(data.lowerConstraint) then
        data.lowerConstraint:Remove()
        data.lowerConstraint = nil
    end

    if IsValid(veh) then
        local phys = veh:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableGravity(true)
            phys:EnableMotion(true)
            phys:Wake()
        end
    end
end

-- ============================================================================
-- BREAK SPIKE
-- ============================================================================
function TIV.Anchor.BreakSpike(veh, data, spikeIndex)
    if not data.constraints then return false end
    local broke = false
    for i = #data.constraints, 1, -1 do
        local conData = data.constraints[i]
        if conData.spikeIndex == spikeIndex then
            if IsValid(conData.constraint) then
                conData.constraint:Remove()
            end
            table.remove(data.constraints, i)
            broke = true
        end
    end
    return broke
end

print("[TIV] Anchor system loaded")
