# Changelog - Tornado Intercept Vehicle (TIV) Framework

All notable changes, architectural overhauls, and gameplay additions to the Tornado Intercept Vehicle addon are documented in this file.

---

## [2.0.0] - Major Field Engineering & Customization Update

This major release introduces a full career progression system, an interactive in-game 3D configuration editor, true vector-driven angled spike physics, physical armor plating with debris deflection, an advanced multi-stage aerodynamic lofting and rollover recovery engine, full Wiremod and Expression 2 integration, and modern tactical cockpit instrumentation.

---

### Table of Contents
1. [Career Progression & Intercept Economy](#1-career-progression--intercept-economy)
2. [Interactive 3D Interceptor Configuration Editor](#2-interactive-3d-interceptor-configuration-editor)
3. [Physical Armor Plating & Debris Deflection](#3-physical-armor-plating--debris-deflection)
4. [Dynamic Angled Spike Mechanics & Vector Trajectory](#4-dynamic-angled-spike-mechanics--vector-trajectory)
5. [Advanced Aerodynamic Lofting & Rollover Recovery](#5-advanced-aerodynamic-lofting--rollover-recovery)
6. [GStorms & XTwisters 3 (XT3) Compatibility Engine](#6-gstorms--xtwisters-3-xt3-compatibility-engine)
7. [Wiremod & Expression 2 (E2) APIs](#7-wiremod--expression-2-e2-apis)
8. [Tactical Cockpit HUD & Instruments](#8-tactical-cockpit-hud--instruments)
9. [Settings Menu, Presets, & Field Manual](#9-settings-menu-presets--field-manual)
10. [Bug Fixes & Codebase Health](#10-bug-fixes--codebase-health)

---

### 1. Career Progression & Intercept Economy

#### Core Mechanics
- **Dynamic Intercept Scoring**: Players earn Intercept points by positioning and anchoring their vehicle inside active tornado wind fields (>= 70 MPH).
  - Points accumulate progressively based on real-time ambient wind speed, proximity to tornado funnels, and duration spent anchored.
  - Core Vortex Survivor Bonus: Extra rewards for surviving violent tornado core passages (EF3+ winds exceeding 135+ MPH).
- **Persistent Career Profiles**: Player profiles are saved server-side in `garrysmod/data/tiv/progression/<steamid64>.json`.
  - Tracks lifetime intercepts, spendable intercept points, unlocked upgrade tiers, and storm statistics across server restarts.
- **Client Toast HUD Notifications**: Sleek, animated on-screen alerts display earned intercepts and milestone achievements in real time.
- **Interactive Upgrade Tree UI**: Accessible via Spawnmenu (`Q -> Options -> Tornado Interceptor -> Progression`) or chat/console (`tiv_menu`). Features visual progression tiers, cost requirements, and real-time unlock statuses.

#### Upgrade Registry
| Upgrade ID | Title | Cost | Prerequisites | Effects & Stat Multipliers |
| :--- | :--- | :--- | :--- | :--- |
| `angled_spikes` | Angled Anchor Spikes | 75 Pts | None | Splayed outward spike geometry, +15% anchor force, +15 MPH loft threshold |
| `heavy_hydraulics` | Heavy Hydraulics | 120 Pts | None | +30% deployment drive speed, +25% lowering force |
| `side_armor` | Reinforced Side Skirts | 90 Pts | None | 2x PHX heavy metal side plates, -25% debris damage, +10 MPH loft threshold |
| `front_armor` | V-Shape Storm Cowl | 110 Pts | `side_armor` | Front PHX deflector cowl, -35% frontal wind drag, -30% debris damage |
| `aero_cowls` | Aerodynamic Cowls | 140 Pts | `front_armor` | Streamlined profile, -20% wind resistance, +20 MPH loft threshold |
| `reinforced_joints` | Titanium Balljoints | 180 Pts | `angled_spikes`, `heavy_hydraulics` | Heavy-duty anchor balljoints, +50% anchor tensile strength, +25 MPH loft threshold |

#### Sandbox & Admin Tools
- Added admin console commands for progression management:
  - `tiv_add_points <steamid|name|player> <amount>` - Grants spendable Intercept points.
  - `tiv_unlock_all` - Unlocks all upgrades for the caller.
  - `tiv_reset_progression [player]` - Resets profile progression to zero.
- In-game UI shortcuts in the **Cheats / Sandbox** tab for single-player testing and server configuration.

---

### 2. Interactive 3D Interceptor Configuration Editor

#### Real-Time 3D Workspace
- Launched via console command `tiv_editor_3d`, `tiv_editor`, or the Spawnmenu settings tab.
- Full 3D interactive viewport rendered using Source Engine client rendering:
  - **Camera Controls**: Orbit around vehicle, smooth pan, mousewheel zoom, and view reset.
  - **Auto-Rotation Removed**: Stable, user-controlled orientation for precise component alignment.
  - **Chassis Coordinate Gizmo**: Visual 3D XYZ axis helper positioned at vehicle local origin `(0, 0, 0)`.
  - **Component Selection**: Select individual spikes (`spike_fr`, `spike_fl`, `spike_mr`, `spike_ml`, `spike_rr`, `spike_rl`) and armor plates (`armor_sl`, `armor_sr`, `armor_fa`).
  - **Transform Sliders**: Real-time position (X, Y, Z) and orientation (Pitch, Yaw, Roll) adjustment in vehicle-local coordinates.
  - **Angle Snap Tools**: Quick snap buttons for common angles (0°, 10°, 20°, 30°, -5°, +5°).
  - **Symmetrical Mirroring**: Instant one-click mirroring of component coordinates across the vehicle centerline (X axis inverted, Roll negated/inverted for outward splay).

#### Universal Multi-Model Support
- Independent per-model configuration profiles:
  - Half-Life 2 Jeep Buggy (`models/buggy.mdl`)
  - Half-Life 2 Jalopy (`models/vehicle.mdl`)
  - Extensible to any vehicle model or prop base.
- Switching base models dynamically re-parents components to the target model's local coordinate space.

#### AI-Friendly Configuration Export & Import
- Configurations serialize to clean, deterministic Lua tables stored in `garrysmod/data/tiv/configs/<clean_model>.txt`.
- One-click clipboard copy (`COPY ACTIVE CONFIGURATION`) exports Lua code formatted for direct insertion into custom addons or AI prompting.
- In-editor Lua importer parses raw Lua tables and JSON strings with safety sanitization and instant 3D viewport preview.

---

### 3. Physical Armor Plating & Debris Deflection

#### Armor Prop Mounting & Suspension Dynamics
- Side and front armor panels use Valve `models/props_phx/construct/metal_plate1x2.mdl`.
- Physical props are welded directly to the vehicle chassis upon unlocking or equipping armor upgrades.
- **Zero-Weight Physics Architecture**: Fixed an issue where heavy prop physics mass caused vehicle suspensions to bottom out or clip wheels into terrain. Armor plates provide visual fidelity and physical presence without adding artificial dead weight that degrades driving dynamics.
- Collision group configured to prevent collision self-interference with vehicle wheels while actively colliding with flying storm debris.

#### Debris Damage Deflection
- Server-side damage hook dynamically intercepts kinetic physics impacts:
  - Calculates impact angle relative to front and side armor panels.
  - Absorbs and deflects up to 65% of flying debris impact damage.
  - Emits directional spark effects (`metal_sparks`) and heavy ricochet sounds on impact.

---

### 4. Dynamic Angled Spike Mechanics & Vector Trajectory

#### True Vector Axis Deployment
- Spikes drive, settle, and retract along their **true angled local vector** rather than moving vertically down:
  - Outward angled orientation (Right: `Angle(80, 0, 0)`, Left: `Angle(100, 0, 0)`).
  - Spike cylinders extend outward along their local forward/up orientation vector during deployment.
  - Retraction draws spikes back into chassis storage along the exact same angled vector.
  - Restores full authentic 3.0-second deployment and retraction durations with pneumatic piston audio and ground impact effects.

#### Terrain-Adaptive Ground Tracing
- Ray traces originate from local spike mounts and travel along the angled trajectory vector to detect uneven ground, asphalt, ditch slopes, or banking angles.
- Dynamically clamps penetration depth into world geometry to ensure firm ground anchorage regardless of terrain slope.

---

### 5. Advanced Aerodynamic Lofting & Rollover Recovery

#### Multi-Stage Progressive Anchor Failure Dynamics
1. **Mechanical Stress Calculation**:
   - Stress evaluates real-time wind speed squared, vehicle angle of attack, vehicle mass, and active armor drag coefficients.
2. **Windward Anchor Failure**:
   - In winds exceeding 160-240 MPH (scaled by upgrade perks), high lateral drag shears the windward anchor balljoints first.
   - Metal shear audio and spark bursts signal anchor structural failure.
3. **Physical Chassis Tipping**:
   - When windward anchors fail, the vehicle hinges on its remaining leeward anchors, tilting 20° to 28° into the storm vortex.
4. **Secondary Anchor Shear & Full Lofting**:
   - Continued hurricane-force exposure snaps remaining anchors, transitioning vehicle state to `"lofted"`.

#### Vortex Aerodynamics & Armor Tearing
- Dynamic lift, lateral drag, and rotational tumbling forces applied directly to the physics object based on wind vectors and vehicle orientation.
- **Violent Turbulence Armor Tearing**: Extreme vortex turbulence can tear off armor panels if wind force exceeds plate weld limits, launching detached plates as hazardous physical projectiles.

#### Hydraulic Rollover Recovery System
- Overturned or inverted vehicles can activate a hydraulic self-righting system.
- Smooth upward and rotational impulse rights the vehicle onto its wheels while clearing inverted physics locks.
- Accessible via:
  - In-cabin keybind / rollover prompt.
  - Console command: `tiv_recover`.
  - Wiremod input: `Recover` (rising edge).
  - Expression 2: `Entity:tivRecover()`.

---

### 6. GStorms & XTwisters 3 (XT3) Compatibility Engine

- Automatic detection of running storm mods:
  - Checks for global `GStorm`, `gstorms`, `XTwister`, `XT3`, and active storm entity hooks.
  - Normalizes wind velocity and direction across differing coordinate conventions.
- Respects custom tornado physics and prevents conflict between TIV anchor constraints and storm pull vectors.
- Configurable compatibility scaling ConVars:
  - `tiv_compat_mode` (default `1`): Enables full interoperability mode.
  - `tiv_compat_anchored_wind_scale` (default `0.65`): Dampens lateral storm forces applied to an anchored chassis.
  - `tiv_compat_max_deploy_linear` / `tiv_compat_max_deploy_angular`: Clamp limits to ensure stable physics simulation.

---

### 7. Wiremod & Expression 2 (E2) APIs

#### Dedicated Wiremod Controller (`gmod_wire_tiv_controller`)
- Spawnable via Wiremod toolgun category or automatic internal vehicle controller link.
- Supports multi-vehicle installations: each controller binds strictly to its linked vehicle entity.

#### Wiremod Inputs & Outputs Reference

##### Inputs
| Input Name | Type | Description |
| :--- | :--- | :--- |
| `Deploy` | NORMAL | Triggers deployment sequence (lowers vehicle, drives angled spikes, anchors chassis) on rising edge (> 0) |
| `Retract` | NORMAL | Triggers retraction sequence (releases anchors, draws spikes flush, raises vehicle) on rising edge (> 0) |
| `ToggleDeploy` | NORMAL | Toggles between Deploy and Retract on rising edge |
| `EmergencyStop` | NORMAL | Aborts active sequence and safely returns vehicle to idle |
| `Reset` | NORMAL | Emergency system reset, recreates spikes, and clears failure flags |
| `Recover` | NORMAL | Activates hydraulic rollover recovery to self-right an overturned vehicle on rising edge (> 0) |
| `Enable` | NORMAL | Master control lock (1 = enabled, 0 = locked/disabled) |
| `ManualWind` | NORMAL | Enables manual wind simulation override (1 = manual, 0 = auto) |
| `WindSpeed` | NORMAL | Manual wind speed override in MPH |
| `WindDirection` | VECTOR | Manual wind direction vector |
| `Vehicle` | ENTITY | Links controller to a specific TIV vehicle entity |

##### Outputs
| Output Name | Type | Description |
| :--- | :--- | :--- |
| `State` | STRING | Current deployment state (`idle`, `lowering`, `deploying_spikes`, `anchored`, `retracting`, `raising`, `lofted`) |
| `IsDeployed` | NORMAL | 1 if fully anchored and deployed, 0 otherwise |
| `IsDeploying` | NORMAL | 1 if in deploy sequence, 0 otherwise |
| `IsRetracting` | NORMAL | 1 if in retract sequence, 0 otherwise |
| `IsAnchored` | NORMAL | 1 if anchored to ground, 0 otherwise |
| `IsIdle` | NORMAL | 1 if idle and ready, 0 otherwise |
| `IsOverturned` | NORMAL | 1 if vehicle is rolled over or upside down, 0 otherwise |
| `Speed` | NORMAL | Ground speed in MPH |
| `Altitude` | NORMAL | Vehicle altitude (Z coordinate) |
| `VerticalVelocity`| NORMAL | Vertical velocity in MPH |
| `Health` | NORMAL | Vehicle health points |
| `Vehicle` | ENTITY | Entity reference of the linked vehicle |
| `WindSpeed` | NORMAL | Ambient wind speed in MPH |
| `WindDirection` | VECTOR | Ambient wind direction vector |
| `SpikeCount` | NORMAL | Total installed spikes |
| `ActiveSpikes` | NORMAL | Number of currently deployed spikes |
| `AnchorIntegrity`| NORMAL | Anchor constraint health (1 = secure, 0 = failing/broken) |
| `Stress` | NORMAL | Normalized mechanical strain (0.0 to 1.0) |
| `LoftRisk` | NORMAL | Warning flag (1 = extreme loft risk, 0 = safe) |
| `IsLofted` | NORMAL | 1 if vehicle has been ripped from ground by tornado updrafts |
| `Driver` | ENTITY | Current driver entity |
| `CurrentIntercepts`| NORMAL | Driver's spendable Intercept points |
| `TotalIntercepts`| NORMAL | Driver's lifetime Intercept points |
| `UpgradeCount` | NORMAL | Number of unlocked upgrades |
| `ArmorCount` | NORMAL | Number of physical armor plates installed |
| `ArmorProtection`| NORMAL | Kinetic debris damage deflection percentage (0 to 100) |
| `LoftThreshold` | NORMAL | Effective wind loft threshold in MPH |
| `WindResistanceScale` | NORMAL | Aerodynamic drag multiplier (lower = more aerodynamic) |

#### Expression 2 (E2) Extension Library (`tiv`)
Comprehensive E2 functions registered under E2Lib with autocomplete syntax helpers in `cl_tiv.lua`:

```lua
@name TIV Automated Storm Interceptor
@inputs [TIV]:entity AutoDeployTargetWind
@persist State:string

if (first() | duped()) {
    runOnTick(1)
}

if (TIV:isTIV()) {
    local WindSpd = TIV:tivWindSpeed()
    local Stress  = TIV:tivStress()
    local State   = TIV:tivState()

    # Automatic deployment on high winds
    if (WindSpd >= 85 & State == "idle") {
        TIV:tivDeploy()
        print("TIV: Auto-deploying! Wind speed: " + WindSpd + " MPH")
    }

    # Emergency rollover recovery
    if (TIV:tivIsOverturned()) {
        TIV:tivRecover()
        print("TIV: Activating rollover recovery outriggers!")
    }

    # Telemetry logging
    if (changed(State)) {
        print("TIV State changed to: " + State + " (Armor: " + TIV:tivArmorProtection() + "%)")
    }
}
```

---

### 8. Tactical Cockpit HUD & Instruments

- **Modernized Layout**: Re-engineered tactical dashboard positioned cleanly on the driver's HUD.
- **Dynamic Wind Speed Gauge**: Gradient bar shifting dynamically based on wind velocity:
  - 0-40 MPH: Calm / Green
  - 40-73 MPH: Gale / Cyan
  - 73-112 MPH: EF1 / Yellow
  - 113-157 MPH: EF2 / Amber
  - 158-206 MPH: EF3 / Orange-Red
  - 207-260 MPH: EF4 / Crimson
  - 261+ MPH: EF5 / Magenta
- **Individual Spike Status Radar**: 6-point visual schematic showing deployment stage and ground contact of each anchor spike.
- **Mechanical Stress & Loft Alarm**: Visual warning pulsing when wind strain approaches critical shear thresholds.
- **Rollover Warning & Recovery Prompt**: Context-sensitive warning displayed when the vehicle overturns with one-key recovery prompt.
- **Strict No-Emoji Styling**: All icons and typography adhere to professional aerospace/tactical vehicle telemetry styling.

---

### 9. Settings Menu, Presets, & Field Manual

- **Everyday Chaser Presets**:
  - **The Tank**: 6 heavy spikes, unbreakable force limits, 320 MPH loft threshold, automatic deployment at 130 MPH.
  - **Daily Driver**: 6 balanced spikes, realistic wind strain, 180 MPH loft threshold, automatic suspension lowering.
  - **Quick Spotter**: 4 corner spikes, 2.0x deploy speed for rapid storm spotting and quick escapes.
  - **Reset to Default**: Reverts all variables to factory configuration.
- **Interactive 2D Chassis Visualizer**: Real-time visual feedback for spike spread, length offsets, and group toggles.
- **Integrated Field Manual**: Operational guide detailing intercept protocols, wind resistance physics, and Wiremod E2 tutorials.

---

### 10. Bug Fixes & Codebase Health

- **Suspension Travel Fix**: Removed artificial dead weight that caused wheels to clip into geometry, preserving authentic suspension lowering distance.
- **Angled Spikes Vector Fix**: Spikes now drive, settle, and retract along their angled trajectory instead of dropping straight down.
- **Nil Safety**: Added `LocalPlayer()` and entity validity guards across client instrument and audio net receivers.
- **Collision Group Reliability**: Replaced invalid enum usage with engine-standard `COLLISION_GROUP_WORLD` and `COLLISION_GROUP_DEBRIS`.
- **WireLib Scoping**: Fixed `BaseClass` scoping in Wiremod controller entities to ensure flawless baseclass inheritance.
- **Zero Syntax Errors**: Verified entire Lua codebase across all modules with automated AST validation.
