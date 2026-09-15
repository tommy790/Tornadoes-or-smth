-- ============================================================================
-- TIV PROGRESSION & UPGRADE SYSTEM - Server
-- Persistent player progression, Intercept rewards for surviving tornadoes,
-- upgrade transactions, and real-time physics integration.
-- ============================================================================

TIV = TIV or {}
TIV.Progression = TIV.Progression or {}

util.AddNetworkString("TIV_SyncProgression")
util.AddNetworkString("TIV_InterceptAwarded")
util.AddNetworkString("TIV_PurchaseUpgrade")
util.AddNetworkString("TIV_RequestProgression")

TIV.Progression.PlayerData = TIV.Progression.PlayerData or {}
TIV.Progression.ActiveTracking = TIV.Progression.ActiveTracking or {}

-- ============================================================================
-- FILE PERSISTENCE HELPERS
-- ============================================================================
local DATA_DIR = "tiv/progression"

local function EnsureDataDir()
    if not file.IsDir("tiv", "DATA") then
        file.CreateDir("tiv")
    end
    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end
end

local function GetPlayerStorageKey(ply)
    if not IsValid(ply) then return "server_local" end
    if game.SinglePlayer() then return "singleplayer" end
    local sid = ply:SteamID64()
    if sid and sid ~= "" and sid ~= "0" then
        return sid
    end
    return string.gsub(ply:SteamID() or "unknown", ":", "_")
end

function TIV.Progression.GetPlayerProfile(ply)
    if not IsValid(ply) then return nil end
    local key = GetPlayerStorageKey(ply)
    if not TIV.Progression.PlayerData[key] then
        TIV.Progression.LoadPlayerProfile(ply)
    end
    return TIV.Progression.PlayerData[key]
end

function TIV.Progression.LoadPlayerProfile(ply)
    if not IsValid(ply) then return end
    EnsureDataDir()

    local key  = GetPlayerStorageKey(ply)
    local path = DATA_DIR .. "/" .. key .. ".json"

    local data = {
        current_intercepts = 0,
        total_intercepts   = 0,
        unlocked_upgrades  = {},
    }

    if file.Exists(path, "DATA") then
        local raw = file.Read(path, "DATA")
        if raw and raw ~= "" then
            local decoded = util.JSONToTable(raw)
            if istable(decoded) then
                data.current_intercepts = tonumber(decoded.current_intercepts) or 0
                data.total_intercepts   = tonumber(decoded.total_intercepts) or 0
                data.unlocked_upgrades  = decoded.unlocked_upgrades or {}
            end
        end
    end

    TIV.Progression.PlayerData[key] = data
    TIV.Progression.SyncToPlayer(ply)
    return data
end

function TIV.Progression.SavePlayerProfile(ply)
    if not IsValid(ply) then return end
    EnsureDataDir()

    local key  = GetPlayerStorageKey(ply)
    local data = TIV.Progression.PlayerData[key]
    if not data then return end

    local path = DATA_DIR .. "/" .. key .. ".json"
    file.Write(path, util.TableToJSON(data, true))
end

-- ============================================================================
-- NETWORKING
-- ============================================================================
function TIV.Progression.SyncToPlayer(ply)
    if not IsValid(ply) then return end
    local profile = TIV.Progression.GetPlayerProfile(ply)
    if not profile then return end

    net.Start("TIV_SyncProgression")
        net.WriteUInt(profile.current_intercepts or 0, 16)
        net.WriteUInt(profile.total_intercepts or 0, 16)

        local count = 0
        for id, state in pairs(profile.unlocked_upgrades or {}) do
            if state then count = count + 1 end
        end
        net.WriteUInt(count, 8)

        for id, state in pairs(profile.unlocked_upgrades or {}) do
            if state then
                net.WriteString(id)
            end
        end
    net.Send(ply)
end

-- ============================================================================
-- AWARD INTERCEPTS
-- ============================================================================
function TIV.Progression.AwardIntercepts(ply, amount, reason)
    if not IsValid(ply) or amount <= 0 then return end
    local profile = TIV.Progression.GetPlayerProfile(ply)
    if not profile then return end

    profile.current_intercepts = profile.current_intercepts + amount
    profile.total_intercepts   = profile.total_intercepts + amount

    TIV.Progression.SavePlayerProfile(ply)
    TIV.Progression.SyncToPlayer(ply)

    net.Start("TIV_InterceptAwarded")
        net.WriteUInt(amount, 8)
        net.WriteUInt(profile.current_intercepts, 16)
        net.WriteUInt(profile.total_intercepts, 16)
        net.WriteString(reason or "Severe Storm Intercept")
    net.Send(ply)

    print(string.format("[TIV] Awarded %d Intercepts to %s for: %s (Balance: %d, Total: %d)",
        amount, ply:Nick(), reason or "Storm Intercept", profile.current_intercepts, profile.total_intercepts))

    -- Trigger Wire output update on current vehicle
    local veh = ply:GetVehicle()
    if IsValid(veh) and TIV.Wire and TIV.Wire.UpdateOutputs then
        TIV.Wire.UpdateOutputs(veh)
    end
end

-- ============================================================================
-- PURCHASE UPGRADE
-- ============================================================================
function TIV.Progression.PurchaseUpgrade(ply, upgradeID)
    if not IsValid(ply) or not upgradeID then return false, "Invalid request" end

    local upgrade = TIV.Progression.GetUpgrade(upgradeID)
    if not upgrade then
        return false, "Upgrade does not exist"
    end

    local profile = TIV.Progression.GetPlayerProfile(ply)
    if not profile then
        return false, "Player profile unavailable"
    end

    if profile.unlocked_upgrades[upgradeID] then
        return false, "Upgrade is already unlocked"
    end

    if profile.current_intercepts < upgrade.cost then
        return false, string.format("Insufficient Intercepts (Requires %d, have %d)", upgrade.cost, profile.current_intercepts)
    end

    -- Process transaction
    profile.current_intercepts = profile.current_intercepts - upgrade.cost
    profile.unlocked_upgrades[upgradeID] = true

    TIV.Progression.SavePlayerProfile(ply)
    TIV.Progression.SyncToPlayer(ply)

    print(string.format("[TIV] %s unlocked upgrade: %s (Spent %d Intercepts, Balance: %d)",
        ply:Nick(), upgrade.name, upgrade.cost, profile.current_intercepts))

    -- Re-evaluate vehicle bonuses if in a vehicle
    local veh = TIV.Deploy and TIV.Deploy.ResolveVehicle and TIV.Deploy.ResolveVehicle(ply)
    if IsValid(veh) then
        if TIV.CustomComponents and TIV.CustomComponents.ApplyVehicleBonuses then
            TIV.CustomComponents.ApplyVehicleBonuses(veh)
        end
        if TIV.Wire and TIV.Wire.UpdateOutputs then
            TIV.Wire.UpdateOutputs(veh)
        end
    end

    return true, "Upgrade unlocked successfully!"
end

net.Receive("TIV_PurchaseUpgrade", function(len, ply)
    if not IsValid(ply) then return end
    local upgID = net.ReadString()
    TIV.Progression.PurchaseUpgrade(ply, upgID)
end)

net.Receive("TIV_RequestProgression", function(len, ply)
    if not IsValid(ply) then return end
    TIV.Progression.SyncToPlayer(ply)
end)

-- ============================================================================
-- STORM INTERCEPT EVALUATION LOOP
-- Monitors anchored vehicles inside high wind fields.
-- Rewards players who successfully hold position against severe tornado winds.
-- ============================================================================
timer.Create("TIV_StormInterceptTracker", 1.0, 0, function()
    local activeVehicles = TIV.Deploy and TIV.Deploy.Vehicles
    if not activeVehicles then return end

    local now = CurTime()

    for entIdx, data in pairs(activeVehicles) do
        local veh = Entity(entIdx)
        if IsValid(veh) then
            local tracker = TIV.Progression.ActiveTracking[entIdx]
            if not tracker then
                tracker = {
                    timeInCore     = 0,
                    peakWind       = 0,
                    lastPointAward = now,
                    inStorm        = false,
                }
                TIV.Progression.ActiveTracking[entIdx] = tracker
            end

            local state   = data.state or "idle"
            local windMPH = TIV.Wind and TIV.Wind.GetSpeed and TIV.Wind.GetSpeed(veh) or 0
            local driver  = veh.GetDriver and veh:GetDriver() or nil
            if not IsValid(driver) then
                -- Check for passengers or parent seat occupants
                for _, p in ipairs(player.GetAll()) do
                    if p:GetVehicle() == veh or p:GetVehicle():GetParent() == veh then
                        driver = p
                        break
                    end
                end
            end

            -- Only anchored vehicles earn intercept points
            if state == "anchored" and IsValid(driver) then
                if windMPH >= 70 then
                    tracker.inStorm    = true
                    tracker.timeInCore = tracker.timeInCore + 1.0
                    if windMPH > tracker.peakWind then
                        tracker.peakWind = windMPH
                    end

                    -- Threshold: 10s of sustained hold in >= 70 MPH, or 5s if wind is extreme (>= 130 MPH)
                    local requiredDuration = (windMPH >= 130) and 5.0 or 10.0
                    if tracker.timeInCore >= requiredDuration and (now - tracker.lastPointAward) >= requiredDuration then
                        tracker.lastPointAward = now
                        tracker.timeInCore     = 0

                        local points = (windMPH >= 150) and 2 or 1
                        local category = (windMPH >= 150) and "Violent EF4+ Core Intercept" or "Severe Tornado Intercept"
                        TIV.Progression.AwardIntercepts(driver, points, string.format("%s (%.0f MPH)", category, windMPH))
                    end
                else
                    -- Wind died down or vehicle exited storm: check if a full vortex passage was completed
                    if tracker.inStorm and tracker.peakWind >= 95 and windMPH < 35 then
                        tracker.inStorm = false
                        TIV.Progression.AwardIntercepts(driver, 2, string.format("Vortex Eye Passage Intercept (Peak %.0f MPH)", tracker.peakWind))
                        tracker.peakWind = 0
                    elseif windMPH < 40 then
                        tracker.inStorm = false
                        tracker.timeInCore = 0
                    end
                end
            else
                -- Vehicle unanchored or lofted
                tracker.timeInCore = 0
                if state == "lofted" then
                    tracker.inStorm = false
                    tracker.peakWind = 0
                end
            end
        else
            TIV.Progression.ActiveTracking[entIdx] = nil
        end
    end
end)

-- ============================================================================
-- EVENT HOOKS
-- ============================================================================
hook.Add("PlayerInitialSpawn", "TIV_ProgressionInit", function(ply)
    timer.Simple(1.5, function()
        if IsValid(ply) then
            TIV.Progression.LoadPlayerProfile(ply)
        end
    end)
end)

hook.Add("PlayerEnteredVehicle", "TIV_ProgressionEnter", function(ply, veh)
    local tivVeh = TIV.Deploy and TIV.Deploy.ResolveVehicle and TIV.Deploy.ResolveVehicle(ply)
    if IsValid(tivVeh) then
        TIV.Progression.SyncToPlayer(ply)
        if TIV.CustomComponents and TIV.CustomComponents.ApplyVehicleBonuses then
            TIV.CustomComponents.ApplyVehicleBonuses(tivVeh)
        end
    end
end)

-- ============================================================================
-- CONSOLE COMMANDS
-- ============================================================================
local function CanAdmin(ply)
    if not IsValid(ply) then return true end
    if game.SinglePlayer() then return true end
    return ply:IsAdmin()
end

concommand.Add("tiv_award_intercept", function(ply, cmd, args)
    if not CanAdmin(ply) then return end
    local amount = tonumber(args[1]) or 1
    local target = ply

    if args[2] then
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), string.lower(args[2]), 1, true) then
                target = p
                break
            end
        end
    end

    if IsValid(target) then
        TIV.Progression.AwardIntercepts(target, amount, "Manual Administrative Award")
    end
end)

concommand.Add("tiv_reset_progression", function(ply, cmd, args)
    if not CanAdmin(ply) then return end
    local target = ply
    if args[1] then
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), string.lower(args[1]), 1, true) then
                target = p
                break
            end
        end
    end

    if IsValid(target) then
        local key = GetPlayerStorageKey(target)
        TIV.Progression.PlayerData[key] = {
            current_intercepts = 0,
            total_intercepts   = 0,
            unlocked_upgrades  = {},
        }
        TIV.Progression.SavePlayerProfile(target)
        TIV.Progression.SyncToPlayer(target)
        print("[TIV] Progression reset for " .. target:Nick())
    end
end)

print("[TIV] Server progression system loaded")
