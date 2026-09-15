-- ============================================================================
-- TIV CONFIG
-- ============================================================================

TIV = TIV or {}
TIV.Config = TIV.Config or {}

-- Runtime setting bounds
TIV.Config.SpikeCountConvarMin     = 0
TIV.Config.SpikeCountConvarMax     = 6
TIV.Config.SpikeForceConvarMin     = 0
TIV.Config.SpikeForceConvarMax     = 200000
TIV.Config.HideSpikes              = false
TIV.Config.CompatWindForceScaleMin = 0.1
TIV.Config.CompatWindForceScaleMax = 1.0

-- Compat slider bounds (single source of truth)
TIV.Config.CompatMaxDeployLinearMin   = 50
TIV.Config.CompatMaxDeployLinearMax   = 5000
TIV.Config.CompatMaxDeployAngularMin  = 20
TIV.Config.CompatMaxDeployAngularMax  = 4000
TIV.Config.CompatRecoveryCooldownMin  = 0
TIV.Config.CompatRecoveryCooldownMax  = 30

TIV.Config.LoftWindMin = 50

-- DEPLOYMENT
TIV.Config.DeployKey            = KEY_B
TIV.Config.LowerTime            = 3
TIV.Config.SpikeCount           = 6
TIV.Config.LowerAmount          = 4.8

-- SUSPENSION LIMITS (per vehicle model / class)
-- Maximum distance in units the chassis lowers before reaching suspension compression limit,
-- preventing the wheels from clipping into the terrain.
TIV.Config.SuspensionLimits = {
    jeep    = 4.8,
    jalopy  = 4.2,
    apc     = 5.0,
}

-- SPIKES
TIV.Config.SpikeModel           = "models/props_junk/harpoon002a.mdl"
-- Hover offset of idle spike above the offset point, in units (positive = up).
TIV.Config.SpikeHoverOffset     = 60
TIV.Config.SpikeDriveDepth      = 15
TIV.Config.SpikeDriveDuration   = 3.0
TIV.Config.SpikeRetractDuration = 3.0

-- ANCHOR / BALLSOCKET
-- Force limit of 0 = unbreakable by force. The loft system handles all
-- spike removal explicitly via TIV.Anchor.BreakSpike(). This matches the
-- original design intent and prevents the "vehicle dragged with spikes
-- planted" failure mode where joints silently break under tornado wind.
TIV.Config.SpikeForceLimit      = 0
TIV.Config.BallSocketForceLimit = 0
TIV.Config.AnchorPivotLimit     = 28

-- LOFT MECHANICS
TIV.Config.LoftWindThreshold    = 160
TIV.Config.LoftForceMultiplier  = 50
TIV.Config.LoftTumbleForce      = 1000

-- Wind force applied to vehicle while anchored
TIV.Config.AnchoredWindForce    = 0.8
TIV.Config.AnchoredRockTorque   = 5.5

-- WIND
TIV.Config.WindEnabled          = true
TIV.Config.WindDefault          = 0
TIV.Config.WindMaxSimulated     = 350

-- INSTRUMENTS
TIV.Config.InstrumentUpdateRate = 0.1

-- HUD
TIV.Config.HUDEnabled           = true

-- STRESS (centralized thresholds)
TIV.Config.Stress = {
    TurbulenceMinMPH = 50,    -- wind speed at which to start applying turbulence
    TorqueMin        = 0.3,   -- stress level at which to start rocking torque
    SoundHigh        = 0.6,   -- > this uses StressHighSoundChance
    SoundCrit        = 0.9,   -- > this uses StressCritChance
    HUDPulse         = 0.7,   -- HUD bar pulses above this stress
    HUDMarker        = 0.7,   -- visual marker on the HUD bar
}

TIV.Config.StressLowSoundChance  = 0.005
TIV.Config.StressHighSoundChance = 0.04
TIV.Config.StressCritChance      = 0.10

-- SPIKE SPACING
TIV.Config.SpikeCountMin        = TIV.Config.SpikeCountConvarMin
TIV.Config.SpikeCountMax        = TIV.Config.SpikeCountConvarMax

-- SESSION TRACKING
TIV.Config.SessionSeed          = math.random(100000, 999999)

-- ============================================================================
-- SHARED VEHICLE DETECTION
-- One source of truth for "is this a TIV?". Called from cl_deploy, sv_deploy,
-- cl_hud, sv_instruments. Add new vehicle classes/models here only.
-- ============================================================================
TIV.SupportedClasses = {
    prop_vehicle_jeep      = true,
    prop_vehicle_jeep_old  = true,
    prop_vehicle_jalopy    = true,
    prop_vehicle_apc       = true,
}

TIV.SupportedModelKeywords = { "jeep", "jalopy", "apc" }

function TIV.IsSupportedVehicle(ent)
    if not IsValid(ent) then return false end
    local class = string.lower(ent:GetClass() or "")
    if TIV.SupportedClasses[class] then return true end
    local model = string.lower(ent:GetModel() or "")
    for _, kw in ipairs(TIV.SupportedModelKeywords) do
        if string.find(model, kw, 1, true) then return true end
    end
    return false
end

-- Resolve a player's TIV vehicle, walking seat parent / GetBase if needed.
function TIV.ResolveVehicle(ply)
    if not IsValid(ply) then return nil end
    local seat = ply:GetVehicle()
    if not IsValid(seat) then return nil end
    if TIV.IsSupportedVehicle(seat) then return seat end
    local parent = seat:GetParent()
    if IsValid(parent) and TIV.IsSupportedVehicle(parent) then return parent end
    if isfunction(seat.GetBase) then
        local base = seat:GetBase()
        if IsValid(base) and TIV.IsSupportedVehicle(base) then return base end
    end
    return nil
end

-- ============================================================================
-- SPIKE OFFSETS PER VEHICLE MODEL
-- ============================================================================
TIV.Config.SpikeOffsets = {
    jeep = {
        { pos = Vector( 25,   50, 0), name = "Front Right", group = "front" },
        { pos = Vector(-25,   50, 0), name = "Front Left",  group = "front" },
        { pos = Vector( 30,  -20, 0), name = "Mid Right",   group = "mid"   },
        { pos = Vector(-30,  -20, 0), name = "Mid Left",    group = "mid"   },
        { pos = Vector( 20, -100, 0), name = "Rear Right",  group = "rear"  },
        { pos = Vector(-20, -100, 0), name = "Rear Left",   group = "rear"  },
    },
    jalopy = {
        { pos = Vector( 25,   45, 0), name = "Front Right", group = "front" },
        { pos = Vector(-25,   45, 0), name = "Front Left",  group = "front" },
        { pos = Vector( 25,    0, 0), name = "Mid Right",   group = "mid"   },
        { pos = Vector(-25,    0, 0), name = "Mid Left",    group = "mid"   },
        { pos = Vector( 25, -100, 0), name = "Rear Right",  group = "rear"  },
        { pos = Vector(-25, -100, 0), name = "Rear Left",   group = "rear"  },
    },
    prop_vehicle_apc = {
        { pos = Vector( 35,   90, 0), name = "Front Right", group = "front" },
        { pos = Vector(-35,   90, 0), name = "Front Left",  group = "front" },
        { pos = Vector( 35,   10, 0), name = "Mid Right",   group = "mid"   },
        { pos = Vector(-35,   10, 0), name = "Mid Left",    group = "mid"   },
        { pos = Vector( 35, -110, 0), name = "Rear Right",  group = "rear"  },
        { pos = Vector(-35, -110, 0), name = "Rear Left",   group = "rear"  },
    },
}

-- ============================================================================
-- WIRE CONTROLLER OFFSETS PER VEHICLE MODEL
-- Placement offsets for the auto-attached Wiremod controller entity.
-- ============================================================================
TIV.Config.WireControllerOffsets = {
    jeep = {
        pos = Vector(0, 15, 36),
        ang = Angle(0, -90, 0),
    },
    jalopy = {
        pos = Vector(0, 15, 36),
        ang = Angle(0, -90, 0),
    },
    prop_vehicle_apc = {
        pos = Vector(0, 35, 50),
        ang = Angle(0, -90, 0),
    },
}

-- ============================================================================
-- TIV ARMOR PLATES CONFIGURATION
-- Strictly applies ONLY to Half-Life 2 Jeep (buggy.mdl) and Jalopy (vehicle.mdl).
-- Never applied to third-party car mods (TDM, LVS, Simfphys, etc.).
-- ============================================================================
TIV.Config.ArmorEnabled = true

TIV.Config.ArmorPlates = {
    jeep = {
        {
            name         = "front_plow",
            model        = "models/props_c17/TrapPropeller_Blade.mdl",
            fallback     = "models/props_debris/metal_panel01a.mdl",
            pos          = Vector(0, 58, 6),
            ang          = Angle(15, 90, 0),
            deployOffset = Vector(0, 0, -4),
            sound        = "tiv2sounds/tiv2frontpanel.wav",
        },
        {
            name         = "left_skirt",
            model        = "models/props_debris/metal_panel02a.mdl",
            fallback     = "models/props_wasteland/panel_corrugatediron001a.mdl",
            pos          = Vector(-33, -20, 6),
            ang          = Angle(0, 0, 0),
            deployOffset = Vector(0, 0, -4),
            sound        = "tiv2sounds/tiv2leftpanel.wav",
        },
        {
            name         = "right_skirt",
            model        = "models/props_debris/metal_panel02a.mdl",
            fallback     = "models/props_wasteland/panel_corrugatediron001a.mdl",
            pos          = Vector(33, -20, 6),
            ang          = Angle(0, 180, 0),
            deployOffset = Vector(0, 0, -4),
            sound        = "tiv2sounds/tiv2rightpanel.wav",
        },
        {
            name         = "windshield_grate",
            model        = "models/props_c17/metalladder001.mdl",
            fallback     = "models/props_debris/metal_panel01a.mdl",
            pos          = Vector(0, 16, 28),
            ang          = Angle(38, 90, 0),
        },
        {
            name         = "roof_armor",
            model        = "models/props_debris/metal_panel01a.mdl",
            fallback     = "models/props_wasteland/panel_corrugatediron001a.mdl",
            pos          = Vector(0, -15, 43),
            ang          = Angle(0, 90, 0),
        },
    },
    jalopy = {
        {
            name         = "front_plow",
            model        = "models/props_c17/TrapPropeller_Blade.mdl",
            fallback     = "models/props_debris/metal_panel01a.mdl",
            pos          = Vector(0, 68, 6),
            ang          = Angle(15, 90, 0),
            deployOffset = Vector(0, 0, -4),
            sound        = "tiv2sounds/tiv2frontpanel.wav",
        },
        {
            name         = "left_skirt",
            model        = "models/props_debris/metal_panel02a.mdl",
            fallback     = "models/props_wasteland/panel_corrugatediron001a.mdl",
            pos          = Vector(-35, -25, 4),
            ang          = Angle(0, 0, 0),
            deployOffset = Vector(0, 0, -4),
            sound        = "tiv2sounds/tiv2leftpanel.wav",
        },
        {
            name         = "right_skirt",
            model        = "models/props_debris/metal_panel02a.mdl",
            fallback     = "models/props_wasteland/panel_corrugatediron001a.mdl",
            pos          = Vector(35, -25, 4),
            ang          = Angle(0, 180, 0),
            deployOffset = Vector(0, 0, -4),
            sound        = "tiv2sounds/tiv2rightpanel.wav",
        },
        {
            name         = "windshield_grate",
            model        = "models/props_c17/metalladder001.mdl",
            fallback     = "models/props_debris/metal_panel01a.mdl",
            pos          = Vector(0, 14, 25),
            ang          = Angle(35, 90, 0),
        },
        {
            name         = "rear_armor",
            model        = "models/props_debris/metal_panel01a.mdl",
            fallback     = "models/props_wasteland/panel_corrugatediron001a.mdl",
            pos          = Vector(0, -55, 26),
            ang          = Angle(-12, 90, 0),
        },
    },
}

