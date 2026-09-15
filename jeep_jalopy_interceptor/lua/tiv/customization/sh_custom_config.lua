-- ============================================================================
-- TIV VEHICLE CUSTOM CONFIGURATION - Shared
-- Deterministic, AI-friendly configuration serializer, deserializer,
-- default vehicle presets, and physics integration.
--
-- Coordinate space: Strictly Vehicle Local
--   Forward: +Y (along veh:GetForward())
--   Right:   +X (along veh:GetRight())
--   Up:      +Z (along veh:GetUp())
-- ============================================================================

TIV = TIV or {}
TIV.CustomConfig = TIV.CustomConfig or {}

-- ============================================================================
-- CURATED PROP & MODEL PRESETS FOR 3D EDITOR
-- ============================================================================
TIV.CustomConfig.CuratedModels = {
    spikes = {
        { name = "Heavy Harpoon",            model = "models/props_junk/harpoon002a.mdl" },
        { name = "Combine Ram Lever",        model = "models/props_c17/TrapPropeller_Lever.mdl" },
        { name = "Reinforced Steel Rod",     model = "models/props_c17/trappropbars_klab.mdl" },
        { name = "Industrial Hydraulic Ram", model = "models/props_wasteland/panel_lever001.mdl" },
        { name = "Ladder Rail Penetrators",  model = "models/props_c17/metalladder001.mdl" },
    },
    side_armor = {
        { name = "PHX Metal Plate 1x2",      model = "models/props_phx/construct/metal_plate1x2.mdl" },
        { name = "PHX Metal Plate 2x2",      model = "models/props_phx/construct/metal_plate2x2.mdl" },
        { name = "PHX Metal Plate 1x1",      model = "models/props_phx/construct/metal_plate1x1.mdl" },
        { name = "Corrugated Steel Sheet",   model = "models/props_c17/fence01a.mdl" },
        { name = "Combine Heavy Blast Plate",model = "models/props_combine/combine_fence01b.mdl" },
        { name = "Heavy Steel Ballast Plate",model = "models/props_c17/furnituredrawer001a_chunk01.mdl" },
        { name = "Slag Armor Panel",         model = "models/props_debris/metal_panel01a.mdl" },
        { name = "Ribbed Alloy Plate",       model = "models/props_debris/metal_panel02a.mdl" },
    },
    front_armor = {
        { name = "PHX Metal Plate 1x2",      model = "models/props_phx/construct/metal_plate1x2.mdl" },
        { name = "PHX Metal Plate 2x2",      model = "models/props_phx/construct/metal_plate2x2.mdl" },
        { name = "PHX Metal Plate 1x1",      model = "models/props_phx/construct/metal_plate1x1.mdl" },
        { name = "Combine Front Cowl",       model = "models/props_combine/combine_fence01b.mdl" },
        { name = "Angled Wedge Plate",       model = "models/props_debris/metal_panel01a.mdl" },
        { name = "Heavy Vault Shutter",      model = "models/props_lab/blastdoor001c.mdl" },
        { name = "Grille Cowling Plate",     model = "models/props_trainstation/traincar_rack001.mdl" },
    },
    roof_armor = {
        { name = "PHX Metal Plate 1x2",      model = "models/props_phx/construct/metal_plate1x2.mdl" },
        { name = "PHX Metal Plate 2x2",      model = "models/props_phx/construct/metal_plate2x2.mdl" },
        { name = "Combine Roof Shield",      model = "models/props_combine/combine_fence01b.mdl" },
        { name = "Corrugated Air Deflector", model = "models/props_c17/fence01a.mdl" },
        { name = "Slag Roof Plate",          model = "models/props_debris/metal_panel02a.mdl" },
    }
}

-- ============================================================================
-- DEFAULT FACTORY CONFIGURATIONS PER VEHICLE MODEL
-- ============================================================================
function TIV.CustomConfig.GetDefaultConfig(vehicleModel, hasAngledSpikes)
    vehicleModel = string.lower(vehicleModel or "models/buggy.mdl")

    if hasAngledSpikes == nil then
        if CLIENT and TIV.Progression and TIV.Progression.IsUnlocked then
            hasAngledSpikes = TIV.Progression.IsUnlocked("angled_spikes")
        end
    end

    local config = {
        vehicle_model = vehicleModel,
        components    = {},
    }

    local rightSpikeAng = hasAngledSpikes and Angle( 80.00, 0.00, 0.00) or Angle(90.00, 0.00, 0.00)
    local leftSpikeAng  = hasAngledSpikes and Angle(-80.00, 0.00, 0.00) or Angle(90.00, 0.00, 0.00)

    if string.find(vehicleModel, "jalopy", 1, true) then
        config.components = {
            -- 6 Standard Spikes
            { id = "spike_fr", type = "spike", name = "Front Right Spike", group = "front", model = "models/props_junk/harpoon002a.mdl", pos = Vector( 25,  45, 0), ang = rightSpikeAng, scale = Vector(1, 1, 1) },
            { id = "spike_fl", type = "spike", name = "Front Left Spike",  group = "front", model = "models/props_junk/harpoon002a.mdl", pos = Vector(-25,  45, 0), ang = leftSpikeAng,  scale = Vector(1, 1, 1) },
            { id = "spike_mr", type = "spike", name = "Mid Right Spike",    group = "mid",   model = "models/props_junk/harpoon002a.mdl", pos = Vector( 25,   0, 0), ang = rightSpikeAng, scale = Vector(1, 1, 1) },
            { id = "spike_ml", type = "spike", name = "Mid Left Spike",     group = "mid",   model = "models/props_junk/harpoon002a.mdl", pos = Vector(-25,   0, 0), ang = leftSpikeAng,  scale = Vector(1, 1, 1) },
            { id = "spike_rr", type = "spike", name = "Rear Right Spike",   group = "rear",  model = "models/props_junk/harpoon002a.mdl", pos = Vector( 25,-100, 0), ang = rightSpikeAng, scale = Vector(1, 1, 1) },
            { id = "spike_rl", type = "spike", name = "Rear Left Spike",    group = "rear",  model = "models/props_junk/harpoon002a.mdl", pos = Vector(-25,-100, 0), ang = leftSpikeAng,  scale = Vector(1, 1, 1) },

            -- Armor Panels (Metal Plates 1x2)
            { id = "armor_sl", type = "armor_side",  name = "Left Metal Plate",  group = "side",  model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(-36, -20, 0), ang = Angle(0, 0, 90), scale = Vector(1, 1, 1) },
            { id = "armor_sr", type = "armor_side",  name = "Right Metal Plate", group = "side",  model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector( 36, -20, 0), ang = Angle(0, 0, -90), scale = Vector(1, 1, 1) },
            { id = "armor_fa", type = "armor_front", name = "Front Metal Plate", group = "front", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(0, 62, 6), ang = Angle(-20, 90, 0), scale = Vector(1, 1, 1) },
        }
    elseif string.find(vehicleModel, "apc", 1, true) then
        config.components = {
            { id = "spike_fr", type = "spike", name = "Front Right Spike", group = "front", model = "models/props_junk/harpoon002a.mdl", pos = Vector( 35,  90, 0), ang = rightSpikeAng, scale = Vector(1, 1, 1) },
            { id = "spike_fl", type = "spike", name = "Front Left Spike",  group = "front", model = "models/props_junk/harpoon002a.mdl", pos = Vector(-35,  90, 0), ang = leftSpikeAng,  scale = Vector(1, 1, 1) },
            { id = "spike_mr", type = "spike", name = "Mid Right Spike",    group = "mid",   model = "models/props_junk/harpoon002a.mdl", pos = Vector( 35,  10, 0), ang = rightSpikeAng, scale = Vector(1, 1, 1) },
            { id = "spike_ml", type = "spike", name = "Mid Left Spike",     group = "mid",   model = "models/props_junk/harpoon002a.mdl", pos = Vector(-35,  10, 0), ang = leftSpikeAng,  scale = Vector(1, 1, 1) },
            { id = "spike_rr", type = "spike", name = "Rear Right Spike",   group = "rear",  model = "models/props_junk/harpoon002a.mdl", pos = Vector( 35,-110, 0), ang = rightSpikeAng, scale = Vector(1, 1, 1) },
            { id = "spike_rl", type = "spike", name = "Rear Left Spike",    group = "rear",  model = "models/props_junk/harpoon002a.mdl", pos = Vector(-35,-110, 0), ang = leftSpikeAng,  scale = Vector(1, 1, 1) },

            { id = "armor_sl", type = "armor_side",  name = "Left Metal Plate",  group = "side",  model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(-46, -10, 6), ang = Angle(0, 0, 90), scale = Vector(1, 1, 1) },
            { id = "armor_sr", type = "armor_side",  name = "Right Metal Plate", group = "side",  model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector( 46, -10, 6), ang = Angle(0, 0, -90), scale = Vector(1, 1, 1) },
            { id = "armor_fa", type = "armor_front", name = "Front Metal Plate", group = "front", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(0, 115, 10), ang = Angle(-25, 90, 0), scale = Vector(1, 1, 1) },
        }
    else
        -- Standard Buggy (jeep)
        config.components = {
            { id = "spike_fr", type = "spike", name = "Front Right Spike", group = "front", model = "models/props_junk/harpoon002a.mdl", pos = Vector( 25.00,  50.00, 0.00), ang = rightSpikeAng, scale = Vector(1.00, 1.00, 1.00) },
            { id = "spike_fl", type = "spike", name = "Front Left Spike",  group = "front", model = "models/props_junk/harpoon002a.mdl", pos = Vector(-25.00,  50.00, 0.00), ang = leftSpikeAng,  scale = Vector(1.00, 1.00, 1.00) },
            { id = "spike_mr", type = "spike", name = "Mid Right Spike",    group = "mid",   model = "models/props_junk/harpoon002a.mdl", pos = Vector( 30.00, -20.00, 0.00), ang = rightSpikeAng, scale = Vector(1.00, 1.00, 1.00) },
            { id = "spike_ml", type = "spike", name = "Mid Left Spike",     group = "mid",   model = "models/props_junk/harpoon002a.mdl", pos = Vector(-30.00, -20.00, 0.00), ang = leftSpikeAng,  scale = Vector(1.00, 1.00, 1.00) },
            { id = "spike_rr", type = "spike", name = "Rear Right Spike",   group = "rear",  model = "models/props_junk/harpoon002a.mdl", pos = Vector( 20.00,-100.00, 0.00), ang = rightSpikeAng, scale = Vector(1.00, 1.00, 1.00) },
            { id = "spike_rl", type = "spike", name = "Rear Left Spike",    group = "rear",  model = "models/props_junk/harpoon002a.mdl", pos = Vector(-20.00,-100.00, 0.00), ang = leftSpikeAng,  scale = Vector(1.00, 1.00, 1.00) },

            { id = "armor_sl", type = "armor_side",  name = "Left Metal Plate",  group = "side",  model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(-43.50, -24.50, 31.80), ang = Angle(-90.00, 90.00, 90.00), scale = Vector(1.00, 1.00, 1.00) },
            { id = "armor_sr", type = "armor_side",  name = "Right Metal Plate", group = "side",  model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector( 43.50, -24.50, 31.80), ang = Angle(-90.00, 90.00, 90.00), scale = Vector(1.00, 1.00, 1.00) },
            { id = "armor_fa", type = "armor_front", name = "Front Metal Plate", group = "front", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(  0.00,  64.00, 31.80), ang = Angle(-95.30, 90.00,  0.00), scale = Vector(1.00, 1.00, 1.00) },
        }
    end

    return config
end

-- ============================================================================
-- DETERMINISTIC CONFIGURATION SERIALIZER (AI & Human Friendly)
-- Generates clean, reproducible Lua table code.
-- ============================================================================
function TIV.CustomConfig.SerializeToLua(config)
    if not istable(config) then return "-- Error: Invalid configuration table" end

    local vehModel = config.vehicle_model or "models/buggy.mdl"
    local lines = {}

    table.insert(lines, "-- ============================================================================")
    table.insert(lines, "-- TIV INTERCEPTOR VEHICLE CONFIGURATION")
    table.insert(lines, "-- Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "-- Base Vehicle Model: " .. vehModel)
    table.insert(lines, "-- Coordinate Space: Vehicle Local")
    table.insert(lines, "--   Forward = +Y, Right = +X, Up = +Z")
    table.insert(lines, "-- ============================================================================")
    table.insert(lines, "return {")
    table.insert(lines, string.format('    vehicle_model = %q,', vehModel))
    table.insert(lines, "    components = {")

    for i, c in ipairs(config.components or {}) do
        local pos = c.pos or Vector(0, 0, 0)
        local ang = c.ang or Angle(0, 0, 0)
        local scl = c.scale or Vector(1, 1, 1)

        table.insert(lines, "        {")
        table.insert(lines, string.format('            id    = %q,', tostring(c.id or ("comp_" .. i))))
        table.insert(lines, string.format('            type  = %q,', tostring(c.type or "custom_prop")))
        table.insert(lines, string.format('            name  = %q,', tostring(c.name or ("Component " .. i))))
        table.insert(lines, string.format('            group = %q,', tostring(c.group or "misc")))
        table.insert(lines, string.format('            model = %q,', tostring(c.model or "models/props_junk/harpoon002a.mdl")))
        table.insert(lines, string.format('            pos   = Vector(%.2f, %.2f, %.2f),', pos.x, pos.y, pos.z))
        table.insert(lines, string.format('            ang   = Angle(%.2f, %.2f, %.2f),', ang.p, ang.y, ang.r))
        table.insert(lines, string.format('            scale = Vector(%.2f, %.2f, %.2f),', scl.x, scl.y, scl.z))
        table.insert(lines, "        },")
    end

    table.insert(lines, "    }")
    table.insert(lines, "}")

    return table.concat(lines, "\n")
end

-- ============================================================================
-- DETERMINISTIC CONFIGURATION DESERIALIZER
-- Safely parses Lua table format or JSON format.
-- ============================================================================
function TIV.CustomConfig.DeserializeFromLua(str)
    if not isstring(str) or string.Trim(str) == "" then
        return nil, "Empty configuration input"
    end

    -- First try JSON decoding if input starts with { or [
    local trimmed = string.Trim(str)
    if string.sub(trimmed, 1, 1) == "{" and string.find(trimmed, '"components"', 1, true) then
        local jsonResult = util.JSONToTable(trimmed)
        if istable(jsonResult) and istable(jsonResult.components) then
            -- Convert JSON arrays/tables into Vector and Angle types
            for _, c in ipairs(jsonResult.components) do
                if istable(c.pos) then c.pos = Vector(c.pos.x or 0, c.pos.y or 0, c.pos.z or 0) end
                if istable(c.ang) then c.ang = Angle(c.ang.p or c.ang.pitch or 0, c.ang.y or c.ang.yaw or 0, c.ang.r or c.ang.roll or 0) end
                if istable(c.scale) then c.scale = Vector(c.scale.x or 1, c.scale.y or 1, c.scale.z or 1) end
            end
            return jsonResult, nil
        end
    end

    -- Ensure input begins with return statement for CompileString
    local luaCode = trimmed
    if not string.find(luaCode, "^%s*return") then
        luaCode = "return " .. luaCode
    end

    -- Safe execution via CompileString with protected environment
    local chunk = CompileString(luaCode, "TIV_ConfigImport", false)
    if isstring(chunk) then
        -- Syntax error in compilation: fall back to robust regex token parser
        return TIV.CustomConfig.ParseTokensFallback(str)
    end

    -- Sandboxed environment
    local env = {
        Vector = Vector,
        Angle  = Angle,
        Color  = Color,
    }
    setfenv(chunk, env)

    local ok, res = pcall(chunk)
    if ok and istable(res) and istable(res.components) then
        -- Validate components
        for i, c in ipairs(res.components) do
            c.id    = tostring(c.id or ("comp_" .. i))
            c.type  = tostring(c.type or "custom_prop")
            c.name  = tostring(c.name or ("Component " .. i))
            c.group = tostring(c.group or "misc")
            c.model = tostring(c.model or "models/props_junk/harpoon002a.mdl")
            c.pos   = isvector(c.pos) and c.pos or Vector(0, 0, 0)
            c.ang   = isangle(c.ang) and c.ang or Angle(0, 0, 0)
            c.scale = isvector(c.scale) and c.scale or Vector(1, 1, 1)
        end
        return res, nil
    end

    return TIV.CustomConfig.ParseTokensFallback(str)
end

-- Fallback regex token parser for hand-typed or slightly malformed inputs
function TIV.CustomConfig.ParseTokensFallback(str)
    local components = {}
    local pattern = "type%s*=%s*[\"'](.-)[\"'].-model%s*=%s*[\"'](.-)[\"'].-pos%s*=%s*Vector%s*%((.-)%).-ang%s*=%s*Angle%s*%((.-)%)[%s,}]"

    for ctype, model, posStr, angStr in string.gmatch(str, pattern) do
        local px, py, pz = string.match(posStr, "([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
        local ap, ay, ar = string.match(angStr, "([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")

        table.insert(components, {
            id    = "comp_" .. (#components + 1),
            type  = ctype,
            name  = string.upper(string.sub(ctype, 1, 1)) .. string.sub(ctype, 2),
            group = "imported",
            model = model,
            pos   = Vector(tonumber(px) or 0, tonumber(py) or 0, tonumber(pz) or 0),
            ang   = Angle(tonumber(ap) or 0, tonumber(ay) or 0, tonumber(ar) or 0),
            scale = Vector(1, 1, 1),
        })
    end

    if #components > 0 then
        return {
            vehicle_model = "models/buggy.mdl",
            components    = components,
        }, nil
    end

    return nil, "Failed to parse vehicle configuration"
end

-- ============================================================================
-- VEHICLE STATS & PHYSICS EVALUATOR
-- Calculates cumulative physical parameters for a configuration and upgrades.
-- ============================================================================
function TIV.CustomConfig.CalculateVehicleStats(config, unlockedUpgrades)
    unlockedUpgrades = unlockedUpgrades or {}
    local upgBonuses = TIV.Progression.CalculateBonuses(unlockedUpgrades)

    local stats = {
        total_spikes         = 0,
        angled_spikes_count  = 0,
        side_armor_count     = 0,
        front_armor_count    = 0,
        total_armor_count    = 0,
        effective_loft_mph   = (TIV.Config and TIV.Config.LoftWindThreshold or 180) + upgBonuses.loft_threshold,
        rock_torque_mult     = upgBonuses.rock_torque_mult,
        wind_force_mult      = upgBonuses.wind_force_mult,
        anchor_hold_mult     = upgBonuses.anchor_hold_mult,
        total_ballast_mass   = upgBonuses.added_mass,
        impact_reduction     = upgBonuses.impact_reduction,
        drive_depth_bonus    = upgBonuses.drive_depth_bonus,
    }

    if not config or not config.components then
        return stats
    end

    for _, c in ipairs(config.components) do
        local ctype = c.type or ""
        if ctype == "spike" then
            stats.total_spikes = stats.total_spikes + 1
            if c.ang and (math.abs(c.ang.p - 90) > 2 or math.abs(c.ang.y) > 2 or math.abs(c.ang.r) > 2) then
                stats.angled_spikes_count = stats.angled_spikes_count + 1
            end
        elseif ctype == "armor_side" then
            stats.side_armor_count  = stats.side_armor_count + 1
            stats.total_armor_count = stats.total_armor_count + 1
            -- Side armor shields underbody and adds ballast
            stats.effective_loft_mph = stats.effective_loft_mph + 12
            stats.rock_torque_mult   = stats.rock_torque_mult * 0.90
            stats.total_ballast_mass = stats.total_ballast_mass + 120
            stats.impact_reduction   = math.Clamp(stats.impact_reduction + 0.08, 0, 0.70)
        elseif ctype == "armor_front" then
            stats.front_armor_count = stats.front_armor_count + 1
            stats.total_armor_count = stats.total_armor_count + 1
            -- Front cowl deflects wind over vehicle
            stats.effective_loft_mph = stats.effective_loft_mph + 15
            stats.wind_force_mult    = stats.wind_force_mult * 0.92
            stats.total_ballast_mass = stats.total_ballast_mass + 140
            stats.impact_reduction   = math.Clamp(stats.impact_reduction + 0.12, 0, 0.70)
        elseif ctype == "armor_roof" then
            stats.total_armor_count  = stats.total_armor_count + 1
            stats.effective_loft_mph = stats.effective_loft_mph + 10
            stats.wind_force_mult    = stats.wind_force_mult * 0.95
            stats.total_ballast_mass = stats.total_ballast_mass + 100
        end
    end

    -- Angled spikes bonus
    if stats.angled_spikes_count >= 2 and unlockedUpgrades["angled_spikes"] then
        stats.effective_loft_mph = stats.effective_loft_mph + 15
        stats.rock_torque_mult   = stats.rock_torque_mult * 0.85
        stats.anchor_hold_mult   = stats.anchor_hold_mult * 1.25
    end

    return stats
end

print("[TIV] Vehicle custom configuration module loaded")
