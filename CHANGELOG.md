# Changelog - Tornado Intercept Vehicle (TIV) Framework

All notable changes, architectural overhauls, and gameplay additions to the Tornado Intercept Vehicle addon are documented in this file.

---

## Simple Release Notes - Major Update

- Added 3D vehicle customization editor with live interactive preview, component mirroring, duplication, grid snapping, and precision coordinate controls.
- Added in-cabin tactical Doppler radar screen displaying real-time tornado tracking, core boundaries, and travel heading arrows with live speed badges (supports Wiremod monitors).
- Added career progression system with spendable upgrade points, career intercept tracking, and unlockable vehicle upgrades.
- Added GStorms, XTwisters 2 (XT2), and XTwisters 3 (XT3) vortex detection awarding intercepts on storm entry and accumulating points over time while holding anchored positions.
- Added comprehensive XTwisters 2 (XT2) support for wind sampling, active tornado radar tracking, forward path prediction, and anchor immunity.
- Added rock-solid hydraulic ground anchor system with true angled spike trajectory driving and retraction.
- Added physical front and side armor panels using PHX heavy metal plates with debris deflection and damage mitigation.
- Added realistic storm lofting physics with sequential anchor failure, directional tipping, and failsafe un-anchoring under extreme EF4/EF5 vortex winds.
- Added full Wiremod inputs/outputs and Expression 2 extension functions for vehicle automation and storm telemetry.
- Added tuned presets and support for the Half-Life 2 Buggy, Episode 2 Jalopy, and Combine APC.
- Added cockpit HUD overlay with live wind speeds, anchor status, storm warnings, and Doppler radar telemetry.
- Added silent HUD toast notifications for intercept milestones and earned upgrade points.
- Added client and server configuration menus in the Garry's Mod spawnmenu with customizable controls and presets.

---

## [2.0.0] - Major Field Engineering & Customization Update

This major release introduces a full career progression system, an interactive in-game 3D configuration editor, true vector-driven angled spike physics, physical armor plating with debris deflection, staged directional anchor lofting physics, full Wiremod and Expression 2 integration, and modern tactical cockpit instrumentation.

---

### Table of Contents
1. [Career Progression & Intercept Economy](#1-career-progression--intercept-economy)
2. [Interactive 3D Interceptor Configuration Editor](#2-interactive-3d-interceptor-configuration-editor)
3. [Physical Armor Plating & Debris Deflection](#3-physical-armor-plating--debris-deflection)
4. [Dynamic Angled Spike Mechanics & Vector Trajectory](#4-dynamic-angled-spike-mechanics--vector-trajectory)
5. [Clean 4-Stage Storm Aerodynamics & Windward Lofting](#5-clean-4-stage-storm-aerodynamics--windward-lofting)
6. [GStorms & XTwisters 3 (XT3) Compatibility Engine](#6-gstorms--xtwisters-3-xt3-compatibility-engine)
7. [Wiremod & Expression 2 (E2) APIs](#7-wiremod--expression-2-e2-apis)
8. [Tactical Cockpit HUD & Instruments](#8-tactical-cockpit-hud--instruments)
9. [Settings Menu, Presets, & Field Manual](#9-settings-menu-presets--field-manual)
10. [Bug Fixes & Codebase Health](#10-bug-fixes--codebase-health)

---

### 1. Career Progression & Intercept Economy

#### Core Mechanics
- **Separation of Intercepts and Currency Points**: The progression system distinguishes between **Intercepts** (event counter representing successful tornado encounters) and **Points** (spendable currency used to purchase vehicle upgrades):
  - **Tornado Intercept Count**: When an intercept begins—either when a tornado rolls over an anchored vehicle or when a vehicle deploys its anchors directly beneath a tornado—the driver and crew immediately receive **1 Intercept** logged to their career statistics.
  - **Continuous Intercept Points Accumulation Over Time**: As long as the vehicle remains anchored and survives inside the vortex, spendable **Points** steadily pile up over time:
    - **Initial Intercept Entry**: +1 Point awarded upon successfully anchoring in the vortex.
    - **Core Intercept Hold**: +1 Point every 5 seconds inside the violent inner core.
    - **Side Intercept Hold**: +1 Point every 8 seconds inside the circulating inflow / side vortex.
  - **Silent Toast Notifications**: Removed the audio chime on point awards, ensuring players can listen to authentic, roaring tornado soundscapes without disruptive audio clutter while points accumulate. Distinct visual toast notifications differentiate **Tornado Intercept Logged (+1 Intercept)** and **Intercept Points (+X Pts)**.
- **Persistent Career Profiles**: Player profiles are saved server-side in `garrysmod/data/tiv/progression/<steamid64>.json`.
  - Tracks career intercepts, spendable points, lifetime points earned, unlocked upgrade tiers, and storm statistics across server restarts with full backwards compatibility.
- **Interactive Upgrade Tree UI**: Accessible via Spawnmenu (`Q -> Options -> Tornado Interceptor -> Progression`) or chat/console (`tiv_menu`). Features visual progression tiers, cost requirements in Points, and real-time unlock statuses.

#### Upgrade Registry
| Upgrade ID | Title | Cost | Category | Effects & Stat Multipliers |
| :--- | :--- | :--- | :--- | :--- |
| `angled_spikes` | Angled Spikes | 2 Pts | Spikes | Splayed outward spike geometry, +30% anchor capacity, +25 MPH loft threshold |
| `side_armor` | Side Armor Panels | 3 Pts | Armor | 2x PHX heavy metal side plates, -20% debris damage, +25 MPH loft threshold |
| `front_armor` | Front Armor Panels | 3 Pts | Armor | Front PHX deflector cowl, -15% wind drag, -25% frontal collision damage |
| `reinforced_hydraulics` | Reinforced Hydraulic Rams | 4 Pts | Hydraulics | +50% anchor breaking force tolerance, +6 units spike drive depth |
| `roof_spoiler` | Aerodynamic Roof Cowl | 5 Pts | Aerodynamics | Streamlined roof deflector, -20% wind drag, +25 MPH loft threshold |
| `heavy_cluster_spikes` | Heavy Anchor Array | 6 Pts | Spikes | Up to 8 independent hydraulic anchors, +40% anchor hold, +30 MPH loft threshold |
| `path_screen` | Tactical Path Prediction Screen | 3 Pts | Electronics | Mounts in-cabin Wiremod monitor rendering real-time tornado tracking & predicted forward trajectory path |

#### Sandbox & Admin Tools
- Added admin console commands for progression management:
  - `tiv_award_points <amount> [player]` - Grants spendable upgrade points.
  - `tiv_award_intercept [player]` - Grants career intercept counter increment.
  - `tiv_unlock_all` - Unlocks all upgrades for the caller.
  - `tiv_reset_progression [player]` - Resets profile progression, points, and intercepts to zero.
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

### 5. Clean 4-Stage Storm Aerodynamics & Windward Lofting

#### Stage 1: Rock-Solid Ground Planting
- **Zero Artificial Chassis Forces**: When fully anchored, all external wind push forces and artificial rocking torques are completely disabled.
- **No Physics Solver Fighting**: Eliminates constraint twitching, rubber-banding, or chassis creeping against ground balljoints.
- **Dynamic Cockpit Stress Audio & Rumble**: Intense storm forces are conveyed realistically through interior screen rumbling (`util.ScreenShake`) and directional metal groan audio without displacing the physical vehicle.

#### Stage 2: Sequential Windward Anchor Shear & Natural Tipping
- **Relative Wind Vector Calculation**: The addon calculates the incoming wind angle relative to the vehicle chassis to determine windward vs. leeward exposure.
- **Windward-First Failure Sequence**: Anchors on the windward side (under maximum aerodynamic tension) snap first, progressing sequentially toward the leeward side in timed waves.
- **Physical Tipping via Leeward Pivot**: When windward anchors break, gravity is enabled, and lateral wind force naturally tips the vehicle over its intact leeward ground anchors like a real hinge.
- **Permanent Failure Flagging**: Failed spikes are marked (`sd.failed = true`) so the Anchor Guard never rebuilds constraints to sheared pins, completely preventing the mid-air anchor trap.

#### Stage 3: Clean Single-Impulse Loft
- **Instant Clean Severance**: The instant all anchors fail or integrity is lost, `TIV.Anchor.ForceDetach` and `constraint.RemoveAll(veh)` sever every constraint tethering the vehicle to the ground.
- **Single Initial Launch Impulse**: Vehicle receives a single initial upward and downwind impulse with randomized aerodynamic tumble torque.
- **Natural Gravity & Storm Flight**: No artificial continuous upward force loops. Airborne flight is governed purely by Source Engine gravity and native storm mod physics (GStorms / XT3). When the tornado passes, gravity naturally returns the vehicle to earth.
- **Automatic Post-Loft Reset**: A 15-second safety timer settles the vehicle, mounts fresh spikes, and returns the state machine to idle.

#### Stage 4: Extreme Vortex Armor Tearing
- Under extreme vortex winds (> 210 MPH EF4/EF5 core), physical welds on armor plates can shear.
- Detached panels emit metallic screeches and spark showers, flying downwind as hazardous physical debris.

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
| `Points` | NORMAL | Driver's spendable upgrade points balance |
| `TotalPoints` | NORMAL | Driver's lifetime career points earned |
| `Intercepts` | NORMAL | Driver's total count of successful tornado intercepts |
| `CurrentIntercepts`| NORMAL | Driver's spendable points (legacy alias) |
| `TotalIntercepts`| NORMAL | Driver's lifetime career intercepts (legacy alias) |
| `UpgradeCount` | NORMAL | Number of unlocked upgrades |
| `ArmorCount` | NORMAL | Number of physical armor plates installed |
| `ArmorProtection`| NORMAL | Kinetic debris damage deflection percentage (0 to 100) |
| `LoftThreshold` | NORMAL | Effective wind loft threshold in MPH |
| `WindResistanceScale` | NORMAL | Aerodynamic drag multiplier (lower = more aerodynamic) |
| `TornadoDetected`| NORMAL | 1 if active tornado is tracked within radar range, 0 otherwise |
| `TornadoDistance`| NORMAL | Distance to nearest tornado in Source hammer units |
| `TornadoDistanceM`| NORMAL | Distance to nearest tornado in meters |
| `TornadoBearing` | NORMAL | Compass bearing to tornado (0-360 degrees) |
| `TornadoSpeed`   | NORMAL | Forward translation speed of tornado in MPH |
| `TornadoETA`     | NORMAL | Estimated seconds until tornado closest point of approach |
| `TornadoCoreRadius` | NORMAL | Radius of tornado core / maximum wind zone in units |
| `TornadoOuterRadius` | NORMAL | Radius of tornado outer circulation in units |
| `TornadoImpactType` | NORMAL | Impact classification: 0=receding/clear, 1=miss, 2=side sweep, 3=direct core hit |
| `TornadoPathX`   | NORMAL | Predicted trajectory vector X component |
| `TornadoPathY`   | NORMAL | Predicted trajectory vector Y component |

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
- **Tactical Doppler Radar Screen**:
  - Mounted directly onto in-cabin Wiremod screens / dashboard monitors (`models/kobilica/wiremonitorsmall.mdl`).
  - High-resolution 3D2D CRT vector display showing real-time radar sweep beam, vehicle heading, tornado center, core boundary, and outer windfield.
  - Direct storm travel heading arrow: bold, glowing tactical vector arrow indicating exact travel direction relative to the vehicle heading with live speed badge.
  - Aligned radar orientation: strictly non-inverted track-up coordinate system (Screen UP = Vehicle Forward, Screen RIGHT = Vehicle Right).
  - Closest Point of Approach (CPA) warnings: instant color-coded alert banners for Direct Core Hits, Side Vortex Sweeps, Flank Passes, and Receding Storms.
  - Mirrored directly into the cockpit HUD instruments overlay with live ETA, distance, and bearing telemetry.
- **Mechanical Stress & Loft Alarm**: Visual warning pulsing when wind strain approaches critical shear thresholds.
- **Strict No-Emoji Styling**: All icons and typography adhere to professional aerospace/tactical vehicle telemetry styling.

---

### 9. 3D Customization Editor Tools Overhaul

- **Streamlined Viewport**: Removed legacy top-left camera preset buttons ("Isometric", "Front", "Side", "Top", "Rear").
- **Viewport Quick Tools Bar**:
  - **Focus Component**: Instantly centers and frames camera on the selected component.
  - **Ghost Chassis (X-Ray)**: Toggles semi-transparent chassis rendering (35% opacity) to view interior cabin monitors and underbody anchor assemblies.
  - **Axes Gizmo**: Toggles the 3D XYZ coordinate axes indicator.
  - **Wireframes**: Toggles bounding box wireframe overlays for placed components.
  - **Reset View**: Returns camera to default isometric view.
- **Undo / Redo History Stack**:
  - 35-level undo/redo history tracking all component modifications.
  - UI buttons (`< Undo` / `Redo >`) and keyboard shortcuts (`Ctrl+Z` / `Ctrl+Y`).
- **Precision Step Multiplier**: Toggle between `0.1`, `0.5`, `1.0`, `5.0`, and `10.0` units for fine nudging and snapping.
- **Extended Component Creation Toolbar**: Dedicated buttons for `+ Spike`, `+ Side Armor`, `+ Front Armor`, and `+ Radar Screen`.
- **Quick-Alignment & Snapping Tools**:
  - `Snap Grid`: Snaps component coordinates to active step size grid.
  - `Ground (Z=0)`: Sets elevation directly to vehicle floor/ground level.
  - `Level Flat`: Zeros out pitch and roll angles.
  - `Turn 90° CW` / `Turn 90° CCW`: Fast 90-degree heading rotation.
  - `Flip 180°`: Reverses component facing direction.
- **Strict Angled Spikes Progression Lock**: Spikes are strictly constrained to 90 degrees straight down until the `angled_spikes` upgrade is purchased.

---

### 10. Settings Menu, Presets, & Field Manual

- **Everyday Chaser Presets**:
  - **The Tank**: 6 heavy spikes, unbreakable force limits, 320 MPH loft threshold, automatic deployment at 130 MPH.
  - **Daily Driver**: 6 balanced spikes, realistic wind strain, 180 MPH loft threshold, automatic suspension lowering.
  - **Quick Spotter**: 4 corner spikes, 2.0x deploy speed for rapid storm spotting and quick escapes.
  - **Reset to Default**: Reverts all variables to factory configuration.
- **Interactive 2D Chassis Visualizer**: Real-time visual feedback for spike spread, length offsets, and group toggles.
- **Integrated Field Manual**: Operational guide detailing intercept protocols, wind resistance physics, and Wiremod E2 tutorials.

---

### 10. Bug Fixes & Codebase Health

- **Lofting System Reversion**: Reverted experimental aerodynamic flight physics and tipping routines back to the rock-solid, proven staged lofting architecture, eliminating mid-air constraint sticking and vehicle freezing.
- **Suspension Travel Fix**: Removed artificial dead weight that caused wheels to clip into geometry, preserving authentic suspension lowering distance.
- **Angled Spikes Vector Fix**: Spikes now drive, settle, and retract along their angled trajectory instead of dropping straight down.
- **Nil Safety**: Added `LocalPlayer()` and occupant vehicle validity guards across client instruments, progression trackers, and audio net receivers.
- **Collision Group Reliability**: Replaced invalid enum usage with engine-standard `COLLISION_GROUP_WORLD` and `COLLISION_GROUP_DEBRIS`.
- **WireLib Scoping**: Fixed `BaseClass` scoping in Wiremod controller entities to ensure flawless baseclass inheritance.
- **Zero Syntax Errors**: Verified entire Lua codebase across all modules with automated AST validation.
- **Doppler Radar Bearing Fix**: The radar's `BEAR:` readout (and the HUD's `BRG:` field) displayed `TIV.Wind.GetNearestActiveTornado().bearing`, which is an **absolute map angle** (`atan2` of the world offset, 0° = world +X). It never changed when the vehicle turned, so it routinely read as "ahead" while the vortex was actually astern. Both readouts now show a **track-up relative bearing** (`REL BRG: 000-359`, clockwise from the vehicle's own nose) derived from the same `relFwd`/`relRgt` projection that places the blip, plus an explicit `AHEAD / RIGHT / ASTERN / LEFT` sector label. The map angle is retained as a separately-labelled `MAP BRG` line.
- **Radar Bearing Regression Harness**: Added `tools/radar_probe.py`, `tools/e2_bearing_probe.py`, and `tools/lua_syntax_check.py`. The probes execute the *real* `DrawRadarScreen` and the *real* E2 `tivTornado*` function bodies under a stubbed GMod API and assert that the painted blip, the printed bearing, and the sector all agree for a vortex ahead / astern / left / right.
- **Multiplayer Radar Fix**: `TIV.Instruments.RadarData` was a single global table that every `TIV_RadarPathData` packet overwrote, while the server sends one packet per player resolved from that player's own vehicle. With more than one TIV jeep in the server, a screen could render another vehicle's packet: the wrong `DIST`, `ETA` and impact banner, and a `REL BRG` reading the opposite sector when the two vehicles sat on different sides of the vortex. Packets are now stored per vehicle and each screen reads only its own, via the new `TIV.Instruments.GetRadarData(veh, ply)`; `TIV.Instruments.RadarData` is retained as the local player's entry for existing readers.
- **Radar Blip Horizontal Mirror Fix**: The Doppler blip and the tornado movement arrow were painted on the wrong side of the display. `cl_radar_screen.lua` placed the blip at `cx + relRgt * scalePx`, but on these monitors increasing canvas x moves *left*, so a vortex on the vehicle's right appeared on the viewer's left while the `REL BRG` readout next to it correctly said `090 RIGHT`. Both the blip and the arrow now negate their right component (`cx - relRgt`, `arrowDirX = -headRgt`), matching the bearing text and the track-up display. The forward/back axis was already correct and is unchanged.
- **3D Editor Refresh Fix**: `TIV.Editor3D.Open()` declared `local RefreshEditor` *after* the toolbar closures that call it, so the Mirror, Duplicate and Grid Snap buttons resolved the name as a global that is never assigned. Their `if isfunction(RefreshEditor)` guard was therefore always false and those buttons never refreshed the component panel. The declaration is now hoisted above every closure in the function.
- **Radar Screen Entity Sweep Fix**: `PostDrawTranslucentRenderables` ran `ents.FindByClass("prop_physics")` every frame on every client just to locate the vehicle's single radar screen prop. The list is now maintained from `OnEntityCreated` / `EntityRemoved`, with a 1 Hz sweep as a safety net for props whose `TIV_RadarScreen` / `TIV_OwnerVehicle` network vars arrive after creation. Measured by `tools/radar_cache_probe.lua`: **300 sweeps per 300 frames → 5 sweeps**.
- **GLua Lint Gate**: Added `.glua.json` (glua-cli@0.6.0 config: TIV's addon globals declared, the E2 DSL directory excluded) so `glua lint` runs clean and can be wired into CI. A ready-made workflow is documented in `tools/README.md`.
