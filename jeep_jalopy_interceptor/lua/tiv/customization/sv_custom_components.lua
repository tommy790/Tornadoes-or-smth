-- ============================================================================
-- TIV CUSTOM VEHICLE COMPONENTS - Server
-- Physical armor panel mounting, component lifecycle management,
-- collision protection, and vehicle-relative local positioning.
-- ============================================================================

TIV = TIV or {}
TIV.CustomComponents = TIV.CustomComponents or {}

util.AddNetworkString("TIV_ApplyVehicleConfig")
util.AddNetworkString("TIV_RequestVehicleConfig")
util.AddNetworkString("TIV_SyncVehicleConfig")

-- Active components mapped per vehicle entity index
TIV.CustomComponents.VehicleArmor = TIV.CustomComponents.VehicleArmor or {}

-- ============================================================================
-- CLEANUP ARMOR PROPS FOR VEHICLE
-- ============================================================================
function TIV.CustomComponents.RemoveArmorProps(veh)
    if not IsValid(veh) then return end
    local entIdx = veh:EntIndex()
    local props  = TIV.CustomComponents.VehicleArmor[entIdx] or {}

    for _, p in ipairs(props) do
        if IsValid(p) then
            SafeRemoveEntity(p)
        end
    end

    TIV.CustomComponents.VehicleArmor[entIdx] = {}
    veh._TIVArmorProps = {}
end

-- ============================================================================
-- SPAWN & ATTACH ARMOR PANELS
-- Mounts armor panels solidly in the vehicle's local coordinate frame.
-- ============================================================================
function TIV.CustomComponents.SpawnArmorProps(veh, config, unlockedUpgrades)
    if not IsValid(veh) or not config or not config.components then return end
    unlockedUpgrades = unlockedUpgrades or {}

    TIV.CustomComponents.RemoveArmorProps(veh)
    local entIdx = veh:EntIndex()
    local spawnedProps = {}

    local hasSideUpgrade  = unlockedUpgrades["side_armor"] == true
    local hasFrontUpgrade = unlockedUpgrades["front_armor"] == true

    for i, comp in ipairs(config.components) do
        local ctype = comp.type or ""
        local isArmor = (ctype == "armor_side" or ctype == "armor_front" or ctype == "armor_roof")

        if isArmor then
            local allowed = true
            if ctype == "armor_side" and not hasSideUpgrade then allowed = false end
            if ctype == "armor_front" and not hasFrontUpgrade then allowed = false end

            if allowed then
                local model = comp.model or "models/props_phx/construct/metal_plate1x2.mdl"
                if not util.IsValidModel(model) then
                    model = "models/props_phx/construct/metal_plate1x2.mdl"
                end

                local localPos = comp.pos or Vector(0, 0, 0)
                local localAng = comp.ang or Angle(0, 0, 0)
                local worldPos = veh:LocalToWorld(localPos)
                local worldAng = veh:LocalToWorldAngles(localAng)

                local prop = ents.Create("prop_physics")
                if IsValid(prop) then
                    prop:SetModel(model)
                    prop:SetPos(worldPos)
                    prop:SetAngles(worldAng)
                    prop:Spawn()
                    prop:Activate()

                    prop:SetCollisionGroup(COLLISION_GROUP_WORLD)
                    prop:SetCustomCollisionCheck(true)
                    prop:SetColor(Color(180, 185, 195, 255))

                    local phys = prop:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:EnableMotion(false)
                        phys:EnableGravity(false)
                    end

                    if constraint and constraint.NoCollide then
                        constraint.NoCollide(veh, prop, 0, 0)
                    end

                    prop:SetParent(veh)
                    prop:SetLocalPos(localPos)
                    prop:SetLocalAngles(localAng)

                    prop.IsTIVArmor      = true
                    prop.PhysgunDisabled = true
                    prop.DoNotDuplicate  = true
                    prop.TIV_OwnerVehicle= veh

                    table.insert(spawnedProps, prop)
                end
            end
        end
    end

    TIV.CustomComponents.VehicleArmor[entIdx] = spawnedProps
    veh._TIVArmorProps = spawnedProps
end

-- ============================================================================
-- APPLY VEHICLE BONUSES & RECALCULATE STATS
-- ============================================================================
function TIV.CustomComponents.ApplyVehicleBonuses(veh)
    if not IsValid(veh) then return end

    local driver = veh.GetDriver and veh:GetDriver() or nil
    if not IsValid(driver) then
        for _, p in ipairs(player.GetAll()) do
            if p:GetVehicle() == veh or (IsValid(p:GetVehicle()) and p:GetVehicle():GetParent() == veh) then
                driver = p
                break
            end
        end
    end

    local unlocked = {}
    if IsValid(driver) and TIV.Progression and TIV.Progression.GetPlayerProfile then
        local prof = TIV.Progression.GetPlayerProfile(driver)
        if prof then unlocked = prof.unlocked_upgrades or {} end
    end

    local config = veh._TIVConfig or TIV.CustomConfig.GetDefaultConfig(veh:GetModel())
    local stats  = TIV.CustomConfig.CalculateVehicleStats(config, unlocked)

    veh._TIVEffectiveStats = stats

    -- Apply mass ballast to physics object
    local phys = veh:GetPhysicsObject()
    if IsValid(phys) then
        if not veh._TIVBaseMass then
            veh._TIVBaseMass = phys:GetMass()
        end
        local newMass = math.Clamp((veh._TIVBaseMass or 1500) + (stats.total_ballast_mass or 0), 500, 10000)
        phys:SetMass(newMass)
    end

    -- Trigger Wire output update
    if TIV.Wire and TIV.Wire.UpdateOutputs then
        TIV.Wire.UpdateOutputs(veh)
    end
end

-- ============================================================================
-- APPLY CONFIGURATION NETWORK RECEIVER
-- ============================================================================
net.Receive("TIV_ApplyVehicleConfig", function(len, ply)
    if not IsValid(ply) then return end

    local veh = TIV.Deploy and TIV.Deploy.ResolveVehicle and TIV.Deploy.ResolveVehicle(ply)
    if not IsValid(veh) then
        -- Find closest TIV vehicle owned by player
        local plyPos = ply:GetPos()
        local bestDist = 250 * 250
        for entIdx, data in pairs(TIV.Deploy.Vehicles or {}) do
            local candidate = Entity(entIdx)
            if IsValid(candidate) and candidate:GetPos():DistToSqr(plyPos) < bestDist then
                veh = candidate
                bestDist = candidate:GetPos():DistToSqr(plyPos)
            end
        end
    end

    if not IsValid(veh) then return end

    local rawLua = net.ReadString()
    local config, err = TIV.CustomConfig.DeserializeFromLua(rawLua)
    if not config then
        ply:ChatPrint("[TIV] Configuration import error: " .. (err or "Unknown error"))
        return
    end

    local profile = TIV.Progression.GetPlayerProfile(ply)
    local unlocked = profile and profile.unlocked_upgrades or {}

    -- Save active configuration on vehicle
    veh._TIVConfig = config

    -- Spawn physical armor panels
    TIV.CustomComponents.SpawnArmorProps(veh, config, unlocked)

    -- Rebuild vehicle spikes with custom positions and angles
    local deployData = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(veh)
    if deployData and deployData.state == "idle" then
        if TIV.Spikes and TIV.Spikes.RemoveAll then
            TIV.Anchor.DetachAll(veh, deployData)
            TIV.Spikes.RemoveAll(deployData, veh:EntIndex())
            deployData.spikesCreated = false
            TIV.Deploy.EnsureSpikes(veh, deployData)
        end
    end

    -- Reapply physics bonuses
    TIV.CustomComponents.ApplyVehicleBonuses(veh)

    ply:ChatPrint("[TIV] Vehicle configuration applied successfully!")
end)

-- ============================================================================
-- IMPACT & DEBRIS DAMAGE REDUCTION
-- Armor panels absorb kinetic debris impacts from flying tornado wreckage.
-- ============================================================================
hook.Add("EntityTakeDamage", "TIV_ArmorDamageReduction", function(target, dmginfo)
    if not IsValid(target) or not TIV.IsSupportedVehicle(target) then return end

    local stats = target._TIVEffectiveStats
    if stats and stats.impact_reduction and stats.impact_reduction > 0 then
        local reduction = stats.impact_reduction
        dmginfo:ScaleDamage(1.0 - reduction)
    end
end)

-- ============================================================================
-- VEHICLE CLEANUP
-- ============================================================================
hook.Add("TIV_VehicleRemoved", "TIV_CustomComponentsCleanup", function(veh)
    if IsValid(veh) then
        TIV.CustomComponents.RemoveArmorProps(veh)
    end
end)

print("[TIV] Server custom components module loaded")
