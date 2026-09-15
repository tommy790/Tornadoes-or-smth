-- ============================================================================
-- TIV ARMOR SYSTEM
-- Heavy protective armor plates and side skirts for the HL2 Jeep & Jalopy.
-- Explicitly restricted to models/buggy.mdl and models/vehicle.mdl.
-- Will NEVER apply to third-party car mods (TDM, LVS, Simfphys, Photon, etc.).
-- ============================================================================

TIV.Armor = TIV.Armor or {}
TIV.Armor.Vehicles = TIV.Armor.Vehicles or {}

-- ============================================================================
-- ELIGIBILITY CHECK
-- Strictly matches Valve's Half-Life 2 Jeep and Jalopy.
-- Rejects all external car mods (TDM, LVS, Simfphys, LoneWolfie, SGM, etc.).
-- ============================================================================
function TIV.Armor.IsEligible(veh)
    if not IsValid(veh) then return false end

    local model = string.lower(veh:GetModel() or "")
    local class = string.lower(veh:GetClass() or "")

    -- Reject third-party vehicle frameworks
    if string.find(class, "lvs", 1, true)
    or string.find(class, "simfphys", 1, true)
    or string.find(class, "glide", 1, true)
    or string.find(class, "scar", 1, true)
    or string.find(class, "wac", 1, true) then
        return false
    end

    -- Reject third-party car mod model paths
    if string.find(model, "tdm", 1, true)
    or string.find(model, "lonewolfie", 1, true)
    or string.find(model, "sgm", 1, true)
    or string.find(model, "digger", 1, true)
    or string.find(model, "sck", 1, true)
    or string.find(model, "crsk", 1, true)
    or string.find(model, "props_vehicles", 1, true) then
        return false
    end

    -- Strictly match Half-Life 2 Jeep
    if model == "models/buggy.mdl" or (string.find(model, "buggy.mdl", 1, true) and class == "prop_vehicle_jeep") then
        return "jeep"
    end

    -- Strictly match Half-Life 2 Jalopy (Episode Two muscle car)
    if model == "models/vehicle.mdl" or model == "models/jalopy.mdl" or (string.find(model, "vehicle.mdl", 1, true) and (class == "prop_vehicle_jeep" or class == "prop_vehicle_jalopy")) then
        return "jalopy"
    end

    return false
end

function TIV.Armor.IsEnabled()
    local cvar = GetConVar("tiv_armor_enabled")
    if cvar then return cvar:GetBool() end
    return TIV.Config.ArmorEnabled ~= false
end

-- ============================================================================
-- MODEL RESOLUTION
-- ============================================================================
local function ResolvePlateModel(plate)
    if plate.model and util.IsValidModel(plate.model) then
        return plate.model
    end
    if plate.fallback and util.IsValidModel(plate.fallback) then
        return plate.fallback
    end
    return "models/props_debris/metal_panel01a.mdl"
end

-- ============================================================================
-- ATTACH ARMOR
-- ============================================================================
function TIV.Armor.Attach(veh)
    local vehType = TIV.Armor.IsEligible(veh)
    if not vehType then return false end
    if not TIV.Armor.IsEnabled() then return false end

    -- Check if armor already exists
    if veh._TIVArmor and next(veh._TIVArmor) ~= nil then
        return true
    end

    local platesConfig = TIV.Config.ArmorPlates and TIV.Config.ArmorPlates[vehType]
    if not platesConfig or #platesConfig == 0 then return false end

    veh._TIVArmor = {}
    local entIdx = veh:EntIndex()
    TIV.Armor.Vehicles[entIdx] = veh

    for _, plate in ipairs(platesConfig) do
        local mdl = ResolvePlateModel(plate)
        local armor = ents.Create("prop_physics")
        if IsValid(armor) then
            armor:SetModel(mdl)
            armor:SetPos(veh:LocalToWorld(plate.pos))
            armor:SetAngles(veh:LocalToWorldAngles(plate.ang))
            armor:Spawn()
            armor:Activate()

            armor:SetCollisionGroup(COLLISION_GROUP_WORLD)
            armor:SetColor(Color(70, 70, 75, 255))
            armor:SetMaterial("models/props_combine/metal_combinebridge001")

            local phys = armor:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
                phys:EnableCollisions(true)
            end

            armor:SetParent(veh)
            armor:SetLocalPos(plate.pos)
            armor:SetLocalAngles(plate.ang)

            armor.IsTIVArmor       = true
            armor.TIV_OwnerVehicle = veh
            armor.PhysgunDisabled  = true
            armor.DoNotDuplicate   = true

            if constraint and constraint.NoCollide then
                constraint.NoCollide(veh, armor, 0, 0)
            end

            veh._TIVArmor[plate.name] = {
                entity       = armor,
                basePos      = plate.pos,
                baseAng      = plate.ang,
                deployOffset = plate.deployOffset,
                sound        = plate.sound,
            }
        end
    end

    if TIV.Wire and TIV.Wire.UpdateOutputs then
        TIV.Wire.UpdateOutputs(veh)
    end

    return true
end

-- ============================================================================
-- DETACH ARMOR
-- ============================================================================
function TIV.Armor.Detach(veh)
    if not IsValid(veh) then return end
    local entIdx = veh:EntIndex()
    TIV.Armor.Vehicles[entIdx] = nil

    if veh._TIVArmor then
        for _, plateData in pairs(veh._TIVArmor) do
            if IsValid(plateData.entity) then
                plateData.entity:SetParent(nil)
                SafeRemoveEntity(plateData.entity)
            end
        end
        veh._TIVArmor = nil
    end

    if TIV.Wire and TIV.Wire.UpdateOutputs then
        TIV.Wire.UpdateOutputs(veh)
    end
end

-- ============================================================================
-- UPDATE ALL ACTIVE VEHICLES (ON CONVAR CHANGE)
-- ============================================================================
function TIV.Armor.UpdateAllVehicles(enabled)
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:IsVehicle() and TIV.Armor.IsEligible(ent) then
            if enabled then
                TIV.Armor.Attach(ent)
            else
                TIV.Armor.Detach(ent)
            end
        end
    end
end

-- ============================================================================
-- DEPLOY PANEL ANIMATION & AUDIO
-- Lowers hydraulic side skirts/front shield when vehicle deploys.
-- ============================================================================
function TIV.Armor.OnStateChanged(veh, state)
    if not IsValid(veh) or not veh._TIVArmor then return end

    if state == "lowering" then
        for _, plate in pairs(veh._TIVArmor) do
            if IsValid(plate.entity) and plate.deployOffset then
                plate.entity:SetLocalPos(plate.basePos + plate.deployOffset)
                if plate.sound then
                    veh:EmitSound(plate.sound, 68, 100, 0.7)
                end
            end
        end
    elseif state == "raising" or state == "idle" then
        for _, plate in pairs(veh._TIVArmor) do
            if IsValid(plate.entity) and plate.deployOffset then
                plate.entity:SetLocalPos(plate.basePos)
            end
        end
    end
end

hook.Add("TIV_StateChanged", "TIV_ArmorStateChanged", function(veh, state)
    TIV.Armor.OnStateChanged(veh, state)
end)

-- ============================================================================
-- DAMAGE MITIGATION
-- Heavy armor absorbs 35% of incoming blast/debris damage for the vehicle.
-- ============================================================================
hook.Add("EntityTakeDamage", "TIV_ArmorDamageReduction", function(target, dmginfo)
    if not IsValid(target) then return end

    local veh
    if target:IsVehicle() and target._TIVArmor and next(target._TIVArmor) ~= nil then
        veh = target
    elseif target.IsTIVArmor and IsValid(target.TIV_OwnerVehicle) then
        veh = target.TIV_OwnerVehicle
        -- Armor prop took the hit; apply spark effect and sound
        local spark = EffectData()
        spark:SetOrigin(dmginfo:GetDamagePosition())
        spark:SetNormal(dmginfo:GetDamageForce():GetNormalized())
        spark:SetMagnitude(2)
        spark:SetScale(1)
        util.Effect("Sparks", spark)

        target:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav", 70, math.random(90, 110))
    end

    if IsValid(veh) and veh._TIVArmor and next(veh._TIVArmor) ~= nil then
        -- Scale down damage by 35%
        dmginfo:ScaleDamage(0.65)
    end
end)

-- ============================================================================
-- LIFECYCLE HOOKS
-- ============================================================================
hook.Add("PlayerSpawnedVehicle", "TIV_ArmorSpawn", function(ply, veh)
    if TIV.Armor.IsEligible(veh) and TIV.Armor.IsEnabled() then
        timer.Simple(0.1, function()
            if IsValid(veh) then
                TIV.Armor.Attach(veh)
            end
        end)
    end
end)

hook.Add("PlayerEnteredVehicle", "TIV_ArmorEnter", function(ply, veh)
    local tivVeh = veh
    if not TIV.Armor.IsEligible(tivVeh) then
        local parent = IsValid(veh) and veh:GetParent() or nil
        if IsValid(parent) and TIV.Armor.IsEligible(parent) then
            tivVeh = parent
        end
    end
    if IsValid(tivVeh) and TIV.Armor.IsEligible(tivVeh) and TIV.Armor.IsEnabled() then
        TIV.Armor.Attach(tivVeh)
    end
end)

hook.Add("EntityRemoved", "TIV_ArmorCleanup", function(ent)
    if IsValid(ent) and ent:IsVehicle() then
        TIV.Armor.Detach(ent)
    end
end)

print("[TIV] Armor system loaded")
