-- ============================================================================
-- TIV CLIENT SETTINGS & FIELD MANUAL
-- Comprehensive control center, presets, spike positioning visualizer,
-- storm physics tuning, HUD configuration, Wiremod guides, and field manual.
-- ============================================================================

TIV = TIV or {}
TIV.Menu = TIV.Menu or {}

-- ============================================================================
-- COLOR PALETTE & STYLES
-- ============================================================================
local THEME = {
    bg          = Color(20, 22, 26, 255),
    panelBg     = Color(28, 31, 38, 255),
    headerBg    = Color(15, 17, 21, 255),
    accent      = Color(230, 130, 35, 255),  -- Storm amber
    accentDark  = Color(160, 85, 20, 255),
    accentBlue  = Color(50, 150, 230, 255),  -- Sky blue
    text        = Color(230, 235, 240, 255),
    textDim     = Color(150, 160, 170, 255),
    textMuted   = Color(100, 110, 120, 255),
    success     = Color(60, 200, 100, 255),
    warning     = Color(240, 180, 40, 255),
    danger      = Color(240, 60, 60, 255),
    border      = Color(50, 55, 65, 255),
    grid        = Color(40, 45, 55, 180),
}

-- ============================================================================
-- PRESETS DEFINITION
-- ============================================================================
local PRESETS = {
    {
        id          = "ef5_titan",
        name        = "EF5 Titan (Heavy Intercept)",
        color       = Color(240, 80, 50),
        desc        = "Maximum anchor reinforcement for intercepting violent EF4 and EF5 tornadoes. Unbreakable anchor force limit, elevated loft resistance, and automatic wind deployment.",
        cvars = {
            tiv_spike_count                = 6,
            tiv_spike_force                = 0,      -- 0 = unbreakable
            tiv_loft_wind_threshold        = 320,
            tiv_hide_spikes                = 0,
            tiv_compat_mode                = 1,
            tiv_compat_anchored_wind_scale = 0.35,
            tiv_auto_deploy_wind           = 130,
            tiv_deploy_speed               = 1.5,
            tiv_suspension_limit           = 0,
            tiv_deploy_handbrake           = 1,
            tiv_spike_drive_depth          = 22,
            tiv_spike_group_front          = 1,
            tiv_spike_group_mid            = 1,
            tiv_spike_group_rear           = 1,
            tiv_loft_release_spikes        = 0,
        }
    },
    {
        id          = "standard",
        name        = "Standard Interceptor (Balanced)",
        color       = Color(60, 180, 240),
        desc        = "Authentic storm intercept profile based on the real TIV 2. Features 6 balanced spikes, hydraulic suspension lowering, and realistic wind strain simulation.",
        cvars = {
            tiv_spike_count                = 6,
            tiv_spike_force                = 80000,
            tiv_loft_wind_threshold        = 180,
            tiv_hide_spikes                = 0,
            tiv_compat_mode                = 1,
            tiv_compat_anchored_wind_scale = 0.65,
            tiv_auto_deploy_wind           = 0,
            tiv_deploy_speed               = 1.0,
            tiv_suspension_limit           = 0,
            tiv_deploy_handbrake           = 1,
            tiv_spike_drive_depth          = 18,
            tiv_spike_group_front          = 1,
            tiv_spike_group_mid            = 1,
            tiv_spike_group_rear           = 1,
            tiv_loft_release_spikes        = 0,
        }
    },
    {
        id          = "scout",
        name        = "Scout Chaser (Fast & Agile)",
        color       = Color(240, 200, 40),
        desc        = "Optimized for high-speed chasing and rapid redeployment. Uses 4 corner spikes with doubled hydraulic speed for quick intercepts and fast escapes.",
        cvars = {
            tiv_spike_count                = 4,
            tiv_spike_force                = 60000,
            tiv_loft_wind_threshold        = 150,
            tiv_hide_spikes                = 0,
            tiv_compat_mode                = 1,
            tiv_compat_anchored_wind_scale = 0.75,
            tiv_auto_deploy_wind           = 0,
            tiv_deploy_speed               = 2.0,
            tiv_suspension_limit           = 0,
            tiv_deploy_handbrake           = 1,
            tiv_spike_drive_depth          = 15,
            tiv_spike_group_front          = 1,
            tiv_spike_group_mid            = 0,
            tiv_spike_group_rear           = 1,
            tiv_loft_release_spikes        = 0,
        }
    },
    {
        id          = "stealth",
        name        = "Stealth Interceptor (Clean Look)",
        color       = Color(180, 140, 240),
        desc        = "Hides physical spike models and the Wiremod controller while maintaining full physical ground anchoring. Ideal for vehicle models where props clip through bodywork.",
        cvars = {
            tiv_spike_count                = 6,
            tiv_spike_force                = 80000,
            tiv_loft_wind_threshold        = 180,
            tiv_hide_spikes                = 1,
            tiv_wire_hide_controller       = 1,
            tiv_compat_mode                = 1,
            tiv_compat_anchored_wind_scale = 0.65,
            tiv_auto_deploy_wind           = 0,
            tiv_deploy_speed               = 1.0,
            tiv_suspension_limit           = 0,
            tiv_deploy_handbrake           = 1,
            tiv_spike_drive_depth          = 18,
            tiv_spike_group_front          = 1,
            tiv_spike_group_mid            = 1,
            tiv_spike_group_rear           = 1,
        }
    },
    {
        id          = "hardcore",
        name        = "Hardcore Simulation (Breakable)",
        color       = Color(220, 50, 80),
        desc        = "High-stakes realistic simulation. Anchors can snap under lateral EF4/EF5 storm shear. If anchors fail, spikes are violently torn from the vehicle into the tornado.",
        cvars = {
            tiv_spike_count                = 6,
            tiv_spike_force                = 42000,
            tiv_loft_wind_threshold        = 165,
            tiv_hide_spikes                = 0,
            tiv_compat_mode                = 1,
            tiv_compat_anchored_wind_scale = 0.85,
            tiv_auto_deploy_wind           = 0,
            tiv_deploy_speed               = 0.8,
            tiv_suspension_limit           = 0,
            tiv_deploy_handbrake           = 1,
            tiv_spike_drive_depth          = 16,
            tiv_spike_group_front          = 1,
            tiv_spike_group_mid            = 1,
            tiv_spike_group_rear           = 1,
            tiv_loft_release_spikes        = 1,
        }
    },
    {
        id          = "defaults",
        name        = "Factory Addon Defaults",
        color       = Color(160, 160, 160),
        desc        = "Restores all TIV configuration settings, tolerances, speeds, and limits back to default vanilla values.",
        cvars = {
            tiv_spike_count                = 6,
            tiv_spike_force                = 80000,
            tiv_loft_wind_threshold        = 180,
            tiv_hide_spikes                = 0,
            tiv_wire_hide_controller       = 0,
            tiv_wire_auto_controller       = 1,
            tiv_compat_mode                = 1,
            tiv_compat_anchored_wind_scale = 0.65,
            tiv_compat_max_deploy_linear   = 650,
            tiv_compat_max_deploy_angular  = 300,
            tiv_compat_recovery_cooldown   = 3.0,
            tiv_auto_deploy_wind           = 0,
            tiv_deploy_speed               = 1.0,
            tiv_suspension_limit           = 0,
            tiv_deploy_handbrake           = 1,
            tiv_spike_drive_depth          = 18,
            tiv_spike_spread_offset        = 0,
            tiv_spike_length_offset        = 0,
            tiv_spike_group_front          = 1,
            tiv_spike_group_mid            = 1,
            tiv_spike_group_rear           = 1,
            tiv_loft_release_spikes        = 0,
        }
    }
}

function TIV.Menu.ApplyPreset(preset)
    if not preset or not preset.cvars then return end
    for cvar, val in pairs(preset.cvars) do
        RunConsoleCommand(cvar, tostring(val))
    end
    surface.PlaySound("buttons/button14.wav")
    notification.AddLegacy("[TIV] Applied preset: " .. preset.name, NOTIFY_GENERIC, 4)
end

-- ============================================================================
-- INTERACTIVE 2D SPIKE CHASSIS SCHEMATIC PANEL
-- ============================================================================
function TIV.Menu.CreateSpikeVisualizer(parent, width, height)
    local pnl = vgui.Create("DPanel", parent)
    pnl:SetSize(width or 320, height or 280)

    pnl.Paint = function(self, w, h)
        -- Dark blueprint/radar container
        draw.RoundedBox(6, 0, 0, w, h, THEME.panelBg)
        surface.SetDrawColor(THEME.border)
        surface.DrawOutlinedRect(0, 0, w, h)

        -- Radar grid lines
        surface.SetDrawColor(THEME.grid)
        local cx, cy = w / 2, h / 2
        for r = 30, math.min(w, h) / 2 - 10, 30 do
            surface.DrawOutlinedRect(cx - r, cy - r, r * 2, r * 2)
        end
        surface.DrawLine(cx, 10, cx, h - 10)
        surface.DrawLine(10, cy, w - 10, cy)

        -- Heading arrow
        draw.SimpleText("^ FRONT (NORTH)", "DermaDefaultBold", cx, 8, THEME.textDim, TEXT_ALIGN_CENTER)

        -- Vehicle chassis silhouette
        local carW = 70
        local carH = 170
        local carX = cx - carW / 2
        local carY = cy - carH / 2

        -- Shadow & body
        draw.RoundedBox(8, carX, carY, carW, carH, Color(35, 40, 50, 255))
        draw.RoundedBox(4, carX + 6, carY + 35, carW - 12, 60, Color(22, 25, 32, 255)) -- Cabin
        surface.SetDrawColor(THEME.accentDark)
        surface.DrawOutlinedRect(carX, carY, carW, carH)

        -- Wheels (4 corners)
        local function drawWheel(wx, wy)
            draw.RoundedBox(2, wx, wy, 10, 24, Color(15, 15, 18, 255))
            surface.SetDrawColor(60, 65, 75)
            surface.DrawOutlinedRect(wx, wy, 10, 24)
        end
        drawWheel(carX - 8, carY + 15)           -- FL
        drawWheel(carX + carW - 2, carY + 15)   -- FR
        drawWheel(carX - 8, carY + carH - 35)   -- RL
        drawWheel(carX + carW - 2, carY + carH - 35) -- RR

        -- Fetch ConVar offsets & groups
        local spreadOff = GetConVar("tiv_spike_spread_offset") and GetConVar("tiv_spike_spread_offset"):GetFloat() or 0
        local lengthOff = GetConVar("tiv_spike_length_offset") and GetConVar("tiv_spike_length_offset"):GetFloat() or 0
        local groupFront = GetConVar("tiv_spike_group_front") and GetConVar("tiv_spike_group_front"):GetBool() ~= false
        local groupMid   = GetConVar("tiv_spike_group_mid")   and GetConVar("tiv_spike_group_mid"):GetBool() ~= false
        local groupRear  = GetConVar("tiv_spike_group_rear")  and GetConVar("tiv_spike_group_rear"):GetBool() ~= false
        local spikeCount = GetConVar("tiv_spike_count") and GetConVar("tiv_spike_count"):GetInt() or 6

        -- Spike definitions
        local spikes = {
            { id = 1, name = "FR", group = "front", enabled = groupFront, x =  25 + spreadOff, y =  50 + lengthOff },
            { id = 2, name = "FL", group = "front", enabled = groupFront, x = -25 - spreadOff, y =  50 + lengthOff },
            { id = 3, name = "MR", group = "mid",   enabled = groupMid,   x =  30 + spreadOff, y = -20 + lengthOff },
            { id = 4, name = "ML", group = "mid",   enabled = groupMid,   x = -30 - spreadOff, y = -20 + lengthOff },
            { id = 5, name = "RR", group = "rear",  enabled = groupRear,  x =  20 + spreadOff, y = -95 + lengthOff },
            { id = 6, name = "RL", group = "rear",  enabled = groupRear,  x = -20 - spreadOff, y = -95 + lengthOff },
        }

        local scale = 0.9
        for _, spk in ipairs(spikes) do
            if spk.id <= spikeCount then
                local sx = cx + (spk.x * scale)
                local sy = cy - (spk.y * scale) -- Invert Y because +Y is forward

                local active = spk.enabled
                local spkColor = active and THEME.success or THEME.danger
                local glowSize = active and 10 or 8

                -- Pulse effect if active
                if active then
                    local pulse = math.abs(math.sin(CurTime() * 3)) * 4
                    surface.SetDrawColor(spkColor.r, spkColor.g, spkColor.b, 60)
                    surface.DrawOutlinedRect(sx - glowSize - pulse / 2, sy - glowSize - pulse / 2, (glowSize + pulse / 2) * 2, (glowSize + pulse / 2) * 2)
                end

                draw.RoundedBox(4, sx - 8, sy - 8, 16, 16, spkColor)
                draw.SimpleText(spk.name, "DermaDefaultBold", sx, sy, Color(0, 0, 0, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        -- Legend at bottom
        local ly = h - 22
        draw.RoundedBox(2, 15, ly, 8, 8, THEME.success)
        draw.SimpleText("Active Anchor", "DermaDefault", 28, ly - 1, THEME.textDim)
        draw.RoundedBox(2, 115, ly, 8, 8, THEME.danger)
        draw.SimpleText("Disabled", "DermaDefault", 128, ly - 1, THEME.textDim)
        draw.SimpleText("Wheelbase Center", "DermaDefault", w - 15, ly - 1, THEME.textMuted, TEXT_ALIGN_RIGHT)
    end

    return pnl
end

-- ============================================================================
-- SPAWNMENU TOOL MENU TABS (UTILITIES -> TIV)
-- ============================================================================
hook.Add("PopulateToolMenu", "TIV_PopulateFullSettingsMenu", function()

    -- ------------------------------------------------------------------------
    -- 1. PRESETS TAB
    -- ------------------------------------------------------------------------
    spawnmenu.AddToolMenuOption("Utilities", "TIV", "TIV_Menu_Presets", "Presets & Profiles", "", "", function(panel)
        panel:ClearControls()

        local title = panel:Help("Quick Intercept Profiles")
        title:SetFont("DermaDefaultBold")
        panel:Help("Instantly configure all vehicle, anchor, and safety settings for different storm conditions and playstyles with one click.")

        -- Master Console Launcher Button
        local launchBtn = vgui.Create("DButton", panel)
        launchBtn:SetText("OPEN FULL TIV MASTER CONSOLE")
        launchBtn:SetTall(36)
        launchBtn:SetTextColor(Color(255, 255, 255))
        launchBtn.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and THEME.accent or THEME.accentDark)
        end
        launchBtn.DoClick = function()
            RunConsoleCommand("tiv_menu")
        end
        panel:AddItem(launchBtn)

        panel:Help("Available Storm Profiles:")

        for _, preset in ipairs(PRESETS) do
            local card = vgui.Create("DPanel", panel)
            card:SetTall(75)
            card.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, THEME.panelBg)
                surface.SetDrawColor(preset.color)
                surface.DrawRect(0, 0, 4, h)
                surface.SetDrawColor(THEME.border)
                surface.DrawOutlinedRect(0, 0, w, h)
            end

            local nameLbl = vgui.Create("DLabel", card)
            nameLbl:SetPos(12, 6)
            nameLbl:SetSize(220, 20)
            nameLbl:SetFont("DermaDefaultBold")
            nameLbl:SetTextColor(preset.color)
            nameLbl:SetText(preset.name)

            local descLbl = vgui.Create("DLabel", card)
            descLbl:SetPos(12, 26)
            descLbl:SetSize(280, 42)
            descLbl:SetFont("DermaDefault")
            descLbl:SetTextColor(THEME.textDim)
            descLbl:SetWrap(true)
            descLbl:SetText(preset.desc)

            local applyBtn = vgui.Create("DButton", card)
            applyBtn:SetPos(panel:GetWide() > 300 and (panel:GetWide() - 95) or 220, 22)
            applyBtn:SetSize(75, 30)
            applyBtn:SetText("APPLY")
            applyBtn:SetTextColor(Color(255, 255, 255))
            applyBtn.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and THEME.accent or Color(45, 50, 60))
            end
            applyBtn.DoClick = function()
                TIV.Menu.ApplyPreset(preset)
            end

            panel:AddItem(card)
        end
    end)

    -- ------------------------------------------------------------------------
    -- 2. SPIKES & RADAR TAB
    -- ------------------------------------------------------------------------
    spawnmenu.AddToolMenuOption("Utilities", "TIV", "TIV_Menu_Spikes", "Spikes & Positions", "", "", function(panel)
        panel:ClearControls()

        local title = panel:Help("Spike Layout & Anchor Radar")
        title:SetFont("DermaDefaultBold")
        panel:Help("Fine-tune the count, spread, length, and ground drive depth of vehicle anchor spikes. Changes apply automatically to subsequent deploys.")

        -- 2D Schematic Radar
        local visualizer = TIV.Menu.CreateSpikeVisualizer(panel, 310, 270)
        panel:AddItem(visualizer)

        panel:Help("Anchor Spike Configuration:")
        panel:NumSlider("Installed Spikes", "tiv_spike_count", 0, 6, 0)
            :SetTooltip("Total number of spikes attached to the vehicle chassis (0 to 6).")

        panel:CheckBox("Hide Spike Models", "tiv_hide_spikes")
            :SetTooltip("Hides spike physical models while retaining full ground anchoring functionality.")

        panel:Help("Independent Pair Enable/Disable:")
        panel:CheckBox("Enable Front Spikes (FR, FL)", "tiv_spike_group_front")
        panel:CheckBox("Enable Mid Spikes (MR, ML)", "tiv_spike_group_mid")
        panel:CheckBox("Enable Rear Spikes (RR, RL)", "tiv_spike_group_rear")

        panel:Help("Spike Position Calibration:")
        panel:NumSlider("Lateral Spread Offset", "tiv_spike_spread_offset", -25, 25, 0)
            :SetTooltip("Adjusts lateral spacing of spikes outward or inward across the vehicle track.")

        panel:NumSlider("Wheelbase Length Offset", "tiv_spike_length_offset", -40, 40, 0)
            :SetTooltip("Shifts spike positions forward or rearward along the vehicle wheelbase.")

        panel:NumSlider("Ground Drive Depth", "tiv_spike_drive_depth", 5, 50, 0)
            :SetTooltip("Depth in Hammer units that hydraulic spikes penetrate below the surface.")
    end)

    -- ------------------------------------------------------------------------
    -- 3. SUSPENSION & HYDRAULICS TAB
    -- ------------------------------------------------------------------------
    spawnmenu.AddToolMenuOption("Utilities", "TIV", "TIV_Menu_Suspension", "Suspension & Deploy", "", "", function(panel)
        panel:ClearControls()

        local title = panel:Help("Suspension & Hydraulic Tuning")
        title:SetFont("DermaDefaultBold")
        panel:Help("Controls how the vehicle lowers its chassis, handles emergency handbrakes, and speeds up hydraulic deployment.")

        panel:Help("Suspension Travel Limiter:")
        panel:NumSlider("Lowering Limit (0=Auto)", "tiv_suspension_limit", 0, 15, 1)
            :SetTooltip("Distance in units the chassis lowers. Set to 0 to automatically compute the vehicle's exact suspension compression limit so tires never clip the ground.")

        panel:Help("Hydraulic Speed & Timing:")
        panel:NumSlider("Deployment Speed", "tiv_deploy_speed", 0.5, 3.0, 1)
            :SetTooltip("Speed multiplier for hydraulic lowering and raising sequence.")

        panel:CheckBox("Lock Handbrake On Anchor", "tiv_deploy_handbrake")
            :SetTooltip("Automatically locks vehicle handbrake when anchored, and releases when raising.")

        panel:Help("Storm Auto-Deployment:")
        panel:NumSlider("Auto-Deploy Wind (MPH)", "tiv_auto_deploy_wind", 0, 250, 0)
            :SetTooltip("Automatically triggers intercept deployment when wind reaches this speed while stopped (0 = disabled).")

        panel:Help("Manual Test Controls:")
        local deployBtn = panel:Button("Toggle Deploy / Retract (Current Vehicle)", "")
        deployBtn.DoClick = function()
            local ply = LocalPlayer()
            if IsValid(ply) and ply:InVehicle() then
                RunConsoleCommand("tiv_toggle")
            else
                notification.AddLegacy("[TIV] Enter a supported vehicle first!", NOTIFY_ERROR, 3)
            end
        end
    end)

    -- ------------------------------------------------------------------------
    -- 4. TORNADO & WIND PHYSICS TAB
    -- ------------------------------------------------------------------------
    spawnmenu.AddToolMenuOption("Utilities", "TIV", "TIV_Menu_Physics", "Storm & Wind Physics", "", "", function(panel)
        panel:ClearControls()

        local title = panel:Help("Tornado Intercept Physics")
        title:SetFont("DermaDefaultBold")
        panel:Help("Tuning parameters for anchor strength, storm loft thresholds, and aerodynamic drag coupling.")

        panel:Help("Anchor Failure & Loft:")
        panel:NumSlider("Loft Threshold (MPH)", "tiv_loft_wind_threshold", 50, 350, 0)
            :SetTooltip("Wind speed where vehicle anchor holds fail and tornado lofting begins.")

        panel:NumSlider("Spike Force Limit", "tiv_spike_force", 0, 200000, 0)
            :SetTooltip("Braking force limit on anchor ball-sockets. 0 = Unbreakable by lateral wind force.")

        panel:CheckBox("Release Spikes On Loft", "tiv_loft_release_spikes")
            :SetTooltip("Violently tears spikes loose as free-flying physics props when lofted.")

        panel:Help("Weather Mod Compatibility Guards:")
        panel:CheckBox("Compatibility Mode", "tiv_compat_mode")
            :SetTooltip("Enables multi-addon safety guards for GStorms, XTwisters 3, and custom tornado mods.")

        panel:NumSlider("Compat Anchored Wind Scale", "tiv_compat_anchored_wind_scale", 0.1, 1.0, 2)
            :SetTooltip("Scales lateral wind force exerted on the vehicle while firmly anchored.")

        panel:NumSlider("Compat Max Linear Vel", "tiv_compat_max_deploy_linear", 50, 5000, 0)
        panel:NumSlider("Compat Max Angular Vel", "tiv_compat_max_deploy_angular", 20, 4000, 0)
        panel:NumSlider("Compat Recovery Cooldown (s)", "tiv_compat_recovery_cooldown", 0, 30, 1)

        panel:Help("Wind Simulation Test Buttons:")
        local windSpeeds = {
            { "Calm (0 MPH)", 0 },
            { "EF1 Storm (90 MPH)", 90 },
            { "EF2 Gale (125 MPH)", 125 },
            { "EF3 Severe (150 MPH)", 150 },
            { "EF4 Violent (185 MPH)", 185 },
            { "EF5 Extreme (260 MPH)", 260 },
        }
        for _, ws in ipairs(windSpeeds) do
            local btn = panel:Button(ws[1], "")
            btn.DoClick = function()
                RunConsoleCommand("tiv_wind_set", tostring(ws[2]))
            end
        end

        local clearBtn = panel:Button("Clear Manual Wind (Resume Auto Weather)", "")
        clearBtn.DoClick = function()
            RunConsoleCommand("tiv_wind_clear")
        end
    end)

    -- ------------------------------------------------------------------------
    -- 5. HUD & INSTRUMENT COCKPIT TAB
    -- ------------------------------------------------------------------------
    spawnmenu.AddToolMenuOption("Utilities", "TIV", "TIV_Menu_HUD", "HUD & Cockpit", "", "", function(panel)
        panel:ClearControls()

        local title = panel:Help("Cockpit HUD & Telemetry")
        title:SetFont("DermaDefaultBold")
        panel:Help("Customize the instrument display shown when piloting a Tornado Intercept Vehicle.")

        panel:CheckBox("Enable Cockpit HUD", "tiv_hud_enabled")
            :SetTooltip("Toggles the cockpit instrument display on or off.")

        panel:Help("Display Units:")
        local unitBox = panel:ComboBox("Speed & Wind Unit", "tiv_hud_unit")
        unitBox:AddChoice("Miles Per Hour (MPH)", "mph")
        unitBox:AddChoice("Kilometers Per Hour (KM/H)", "kmh")
        unitBox:AddChoice("Knots (KTS)", "knots")

        panel:Help("Screen Corner Position:")
        local posBox = panel:ComboBox("HUD Position", "tiv_hud_position")
        posBox:AddChoice("Bottom Right (Default)", "0")
        posBox:AddChoice("Bottom Left", "1")
        posBox:AddChoice("Top Right", "2")
        posBox:AddChoice("Top Left", "3")

        panel:Help("HUD Scale Factor:")
        panel:NumSlider("HUD Size Scale", "tiv_hud_scale", 0.75, 1.5, 2)
            :SetTooltip("Scales the size of the cockpit instrument cluster.")

        panel:Help("Audio Alarms:")
        panel:CheckBox("Audible Warning Alarms", "tiv_hud_sound")
            :SetTooltip("Plays audible alarm klaxons during extreme wind or anchor structural failure.")

        local testSndBtn = panel:Button("Test Klaxon Alarm Sound", "")
        testSndBtn.DoClick = function()
            surface.PlaySound("ambient/alarms/klaxon1.wav")
        end
    end)

    -- ------------------------------------------------------------------------
    -- 6. WIREMOD & AUTOMATION TAB
    -- ------------------------------------------------------------------------
    spawnmenu.AddToolMenuOption("Utilities", "TIV", "TIV_Menu_Wiremod", "Wiremod & E2", "", "", function(panel)
        panel:ClearControls()

        local title = panel:Help("Wiremod & Expression 2")
        title:SetFont("DermaDefaultBold")
        panel:Help("Integrate your interceptor with Wiremod chips, gates, digital screens, and E2 automation.")

        panel:CheckBox("Auto-attach Wire Controller", "tiv_wire_auto_controller")
            :SetTooltip("Automatically attaches a Wiremod controller entity to spawned TIVs.")

        panel:CheckBox("Hide Wire Controller Model", "tiv_wire_hide_controller")
            :SetTooltip("Hides the physical model of the auto-attached Wire controller.")

        panel:Help("Wire Input Ports:")
        panel:ControlHelp("- Deploy (NORMAL): Triggers deploy sequence (1 = deploy).\n- Retract (NORMAL): Triggers retract sequence (1 = retract).\n- ToggleDeploy (NORMAL): Toggles deploy/retract on pulse.\n- EmergencyStop (NORMAL): Aborts deployment immediately.\n- Reset (NORMAL): Emergency resets faulted systems.\n- Handbrake (NORMAL): Manual override for parking brake.")

        panel:Help("Wire Output Telemetry:")
        panel:ControlHelp("- State (STRING): idle, lowering, deploying_spikes, anchored, etc.\n- IsDeployed (NORMAL): 1 when anchored, 0 otherwise.\n- WindSpeed (NORMAL): Real-time storm wind at vehicle in MPH.\n- WindDirection (VECTOR): Unit direction vector of the wind.\n- Stress (NORMAL): Wind stress ratio on anchors (0.0 to 1.0).\n- ActiveSpikes (NORMAL): Number of intact deployed spikes.\n- AnchorIntegrity (NORMAL): 1 if holding, 0 if compromised.")

        panel:Help("Expression 2 Functions:")
        panel:ControlHelp("- E:isTIV() -> number\n- E:tivState() -> string\n- E:tivWindSpeed() -> number\n- E:tivStress() -> number\n- E:tivDeploy() -> number\n- E:tivRetract() -> number\n- E:tivToggle() -> number")
    end)

    -- ------------------------------------------------------------------------
    -- 7. FIELD MANUAL & GUIDES TAB
    -- ------------------------------------------------------------------------
    spawnmenu.AddToolMenuOption("Utilities", "TIV", "TIV_Menu_Guide", "Field Manual & Guide", "", "", function(panel)
        panel:ClearControls()

        local title = panel:Help("Storm Chaser Field Manual")
        title:SetFont("DermaDefaultBold")

        panel:Help("Phase 1: Approach & Positioning")
        panel:ControlHelp("1. Track tornado trajectory via wind direction vector or radar.\n2. Drive into the expected path of the tornado.\n3. Bring vehicle to a COMPLETE STOP (< 5 MPH).\n4. Orient vehicle nose facing directly into oncoming wind for minimal drag.")

        panel:Help("Phase 2: Deployment")
        panel:ControlHelp("1. Press [B] or trigger Wire 'Deploy' input.\n2. Hydraulic suspension lowers chassis flush to the ground limit.\n3. Steel anchor spikes drive into the terrain.\n4. Dual-stage ballsocket constraints anchor vehicle to the world.")

        panel:Help("Phase 3: Interception")
        panel:ControlHelp("1. Monitor HUD wind speed and Anchor Stress bar.\n2. Normal stress is below 70% (Green to Amber).\n3. If stress exceeds 70%, the warning light pulses.\n4. If wind exceeds Loft Threshold, anchors can shear!")

        panel:Help("Phase 4: Retraction & Relocation")
        panel:ControlHelp("1. Once vortex passes, press [B] or trigger Wire 'Retract'.\n2. Spikes retract smoothly from the terrain.\n3. Suspension re-pressurizes to ride height.\n4. Handbrake disengages automatically.")

        panel:Help("Enhanced Fujita (EF) Scale Reference:")
        local efCard = vgui.Create("DPanel", panel)
        efCard:SetTall(155)
        efCard.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, THEME.panelBg)
            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, w, h)

            local rows = {
                { "EF0", "65-85 MPH",   "Light damage",     "0-20% Stress", Color(100, 220, 100) },
                { "EF1", "86-110 MPH",  "Moderate damage",  "20-40% Stress", Color(180, 220, 50) },
                { "EF2", "111-135 MPH", "Considerable",     "40-60% Stress", Color(240, 200, 40) },
                { "EF3", "136-165 MPH", "Severe damage",    "60-80% Stress", Color(240, 130, 30) },
                { "EF4", "166-200 MPH", "Devastating",      "80-95% Stress", Color(240, 60, 40) },
                { "EF5", "200+ MPH",    "Total destruction","CRITICAL STRAIN", Color(220, 20, 60) },
            }

            local y = 6
            for _, r in ipairs(rows) do
                draw.SimpleText(r[1], "DermaDefaultBold", 10, y, r[5])
                draw.SimpleText(r[2], "DermaDefault", 50, y, THEME.text)
                draw.SimpleText(r[3], "DermaDefault", 145, y, THEME.textDim)
                draw.SimpleText(r[4], "DermaDefaultBold", w - 10, y, r[5], TEXT_ALIGN_RIGHT)
                y = y + 24
            end
        end
        panel:AddItem(efCard)

        panel:Help("Troubleshooting FAQ:")
        panel:ControlHelp("Q: Vehicle won't deploy?\nA: Vehicle must be almost stopped (< 15 MPH) and on solid ground.\n\nQ: Do spikes damage the vehicle?\nA: No, all spikes and constraints are collision-filtered.\n\nQ: Can spikes snap?\nA: Yes, if Spike Force Limit is non-zero and lateral storm force exceeds the limit.")
    end)
end)

-- ============================================================================
-- STANDALONE MASTER CONSOLE WINDOW (`tiv_menu` / `tiv_settings`)
-- ============================================================================
function TIV.Menu.OpenMasterConsole()
    if IsValid(TIV.Menu.Frame) then
        TIV.Menu.Frame:Close()
    end

    local w, h = 880, 600
    local frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:SetDraggable(true)
    frame:SetSizable(false)
    frame:ShowCloseButton(false)

    frame.Paint = function(self, fw, fh)
        -- Window background
        draw.RoundedBox(8, 0, 0, fw, fh, THEME.bg)

        -- Header bar
        draw.RoundedBoxEx(8, 0, 0, fw, 50, THEME.headerBg, true, true, false, false)
        surface.SetDrawColor(THEME.accent)
        surface.DrawRect(0, 48, fw, 2)

        -- Title & Subtitle
        draw.SimpleText("TIV-2 COMMAND CONSOLE", "DermaDefaultBold", 20, 12, THEME.text)
        draw.SimpleText("ADVANCED TORNADO INTERCEPT SYSTEMS & FIELD TELEMETRY", "DermaDefault", 20, 28, THEME.accent)

        -- Outer border
        surface.SetDrawColor(THEME.border)
        surface.DrawOutlinedRect(0, 0, fw, fh)
    end

    -- Close Button
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(w - 42, 10)
    closeBtn:SetSize(32, 30)
    closeBtn:SetText("X")
    closeBtn:SetFont("DermaDefaultBold")
    closeBtn:SetTextColor(THEME.textDim)
    closeBtn.Paint = function(self, bw, bh)
        draw.RoundedBox(4, 0, 0, bw, bh, self:IsHovered() and THEME.danger or Color(35, 40, 50))
    end
    closeBtn.DoClick = function()
        frame:Close()
    end

    -- Sidebar for tab navigation
    local sidebarW = 200
    local sidebar = vgui.Create("DPanel", frame)
    sidebar:SetPos(0, 50)
    sidebar:SetSize(sidebarW, h - 50)
    sidebar.Paint = function(self, sw, sh)
        draw.RoundedBoxEx(0, 0, 0, sw, sh, THEME.headerBg, false, false, true, false)
        surface.SetDrawColor(THEME.border)
        surface.DrawLine(sw - 1, 0, sw - 1, sh)
    end

    -- Content container
    local contentArea = vgui.Create("DPanel", frame)
    contentArea:SetPos(sidebarW, 50)
    contentArea:SetSize(w - sidebarW, h - 50)
    contentArea.Paint = function(self, cw, ch)
        draw.RoundedBoxEx(0, 0, 0, cw, ch, THEME.bg, false, false, false, true)
    end

    local currentPanel = nil
    local function SwitchTab(tabFunc)
        if IsValid(currentPanel) then
            currentPanel:Remove()
        end
        currentPanel = tabFunc(contentArea)
        currentPanel:Dock(FILL)
        currentPanel:DockMargin(15, 15, 15, 15)
    end

    local tabButtons = {}
    local function AddSidebarTab(label, tabFunc)
        local btn = vgui.Create("DButton", sidebar)
        btn:SetTall(42)
        btn:Dock(TOP)
        btn:DockMargin(8, 6, 8, 0)
        btn:SetText("  " .. label)
        btn:SetFont("DermaDefaultBold")
        btn:SetContentAlignment(4)
        btn:SetTextColor(THEME.textDim)

        btn.Paint = function(self, bw, bh)
            local active = (btn.IsActive == true)
            local col = active and THEME.accentDark or (self:IsHovered() and Color(35, 40, 50) or Color(0, 0, 0, 0))
            draw.RoundedBox(6, 0, 0, bw, bh, col)
            if active then
                surface.SetDrawColor(THEME.accent)
                surface.DrawRect(0, 4, 3, bh - 8)
            end
        end

        btn.DoClick = function()
            for _, b in ipairs(tabButtons) do
                b.IsActive = false
                b:SetTextColor(THEME.textDim)
            end
            btn.IsActive = true
            btn:SetTextColor(Color(255, 255, 255))
            SwitchTab(tabFunc)
        end

        table.insert(tabButtons, btn)
        return btn
    end

    -- ========================================================================
    -- TAB 1: PRESETS
    -- ========================================================================
    local function BuildPresetsTab(parent)
        local pnl = vgui.Create("DScrollPanel", parent)

        local title = vgui.Create("DLabel", pnl)
        title:SetFont("DermaLarge")
        title:SetTextColor(THEME.text)
        title:SetText("Quick Intercept Presets")
        title:Dock(TOP)
        title:DockMargin(0, 0, 0, 5)

        local sub = vgui.Create("DLabel", pnl)
        sub:SetFont("DermaDefault")
        sub:SetTextColor(THEME.textDim)
        sub:SetText("Select an optimized operational configuration to instantly apply to your vehicle.")
        sub:Dock(TOP)
        sub:DockMargin(0, 0, 0, 15)

        for _, preset in ipairs(PRESETS) do
            local card = vgui.Create("DPanel", pnl)
            card:SetTall(80)
            card:Dock(TOP)
            card:DockMargin(0, 0, 0, 10)

            card.Paint = function(self, cw, ch)
                draw.RoundedBox(6, 0, 0, cw, ch, THEME.panelBg)
                surface.SetDrawColor(preset.color)
                surface.DrawRect(0, 0, 5, ch)
                surface.SetDrawColor(THEME.border)
                surface.DrawOutlinedRect(0, 0, cw, ch)
            end

            local nameLbl = vgui.Create("DLabel", card)
            nameLbl:SetPos(16, 8)
            nameLbl:SetSize(350, 22)
            nameLbl:SetFont("DermaDefaultBold")
            nameLbl:SetTextColor(preset.color)
            nameLbl:SetText(preset.name)

            local descLbl = vgui.Create("DLabel", card)
            descLbl:SetPos(16, 30)
            descLbl:SetSize(460, 42)
            descLbl:SetFont("DermaDefault")
            descLbl:SetTextColor(THEME.textDim)
            descLbl:SetWrap(true)
            descLbl:SetText(preset.desc)

            local applyBtn = vgui.Create("DButton", card)
            applyBtn:SetPos(495, 24)
            applyBtn:SetSize(110, 34)
            applyBtn:SetText("APPLY PRESET")
            applyBtn:SetFont("DermaDefaultBold")
            applyBtn:SetTextColor(Color(255, 255, 255))
            applyBtn.Paint = function(self, bw, bh)
                draw.RoundedBox(4, 0, 0, bw, bh, self:IsHovered() and THEME.accent or Color(45, 50, 62))
            end
            applyBtn.DoClick = function()
                TIV.Menu.ApplyPreset(preset)
            end
        end

        return pnl
    end

    -- ========================================================================
    -- TAB 2: SPIKE SCHEMATIC & POSITIONING
    -- ========================================================================
    local function BuildSpikesTab(parent)
        local pnl = vgui.Create("DPanel", parent)
        pnl.Paint = function() end

        local left = vgui.Create("DPanel", pnl)
        left:SetWide(300)
        left:Dock(LEFT)
        left:DockMargin(0, 0, 15, 0)
        left.Paint = function() end

        local vis = TIV.Menu.CreateSpikeVisualizer(left, 300, 450)
        vis:Dock(FILL)

        local right = vgui.Create("DScrollPanel", pnl)
        right:Dock(FILL)

        local rTitle = vgui.Create("DLabel", right)
        rTitle:SetFont("DermaLarge")
        rTitle:SetTextColor(THEME.text)
        rTitle:SetText("Spike Tuning & Alignment")
        rTitle:Dock(TOP)
        rTitle:DockMargin(0, 0, 0, 10)

        local function addSlider(label, cvar, min, max, dec)
            local s = vgui.Create("DNumSlider", right)
            s:SetText(label)
            s:SetMin(min)
            s:SetMax(max)
            s:SetDecimals(dec)
            s:SetConVar(cvar)
            s:Dock(TOP)
            s:DockMargin(0, 5, 0, 5)
            s:SetDark(false)
            return s
        end

        local function addCheck(label, cvar)
            local cb = vgui.Create("DCheckBoxLabel", right)
            cb:SetText(label)
            cb:SetConVar(cvar)
            cb:Dock(TOP)
            cb:DockMargin(0, 6, 0, 6)
            cb:SetTextColor(THEME.text)
            return cb
        end

        addSlider("Installed Spikes (0-6)", "tiv_spike_count", 0, 6, 0)
        addCheck("Hide Physical Spike Models", "tiv_hide_spikes")

        local div1 = vgui.Create("DLabel", right)
        div1:SetFont("DermaDefaultBold")
        div1:SetTextColor(THEME.accent)
        div1:SetText("Anchor Group Pair Controls:")
        div1:Dock(TOP)
        div1:DockMargin(0, 12, 0, 4)

        addCheck("Enable Front Spike Pair (FR, FL)", "tiv_spike_group_front")
        addCheck("Enable Middle Spike Pair (MR, ML)", "tiv_spike_group_mid")
        addCheck("Enable Rear Spike Pair (RR, RL)", "tiv_spike_group_rear")

        local div2 = vgui.Create("DLabel", right)
        div2:SetFont("DermaDefaultBold")
        div2:SetTextColor(THEME.accent)
        div2:SetText("Coordinate Alignment:")
        div2:Dock(TOP)
        div2:DockMargin(0, 12, 0, 4)

        addSlider("Lateral Spread Offset", "tiv_spike_spread_offset", -25, 25, 0)
        addSlider("Wheelbase Length Offset", "tiv_spike_length_offset", -40, 40, 0)
        addSlider("Ground Penetration Depth", "tiv_spike_drive_depth", 5, 50, 0)

        return pnl
    end

    -- ========================================================================
    -- TAB 3: HYDRAULICS & SUSPENSION
    -- ========================================================================
    local function BuildSuspensionTab(parent)
        local pnl = vgui.Create("DScrollPanel", parent)

        local title = vgui.Create("DLabel", pnl)
        title:SetFont("DermaLarge")
        title:SetTextColor(THEME.text)
        title:SetText("Hydraulic Suspension & Deploy Controls")
        title:Dock(TOP)
        title:DockMargin(0, 0, 0, 15)

        local function addSlider(label, cvar, min, max, dec)
            local s = vgui.Create("DNumSlider", pnl)
            s:SetText(label)
            s:SetMin(min)
            s:SetMax(max)
            s:SetDecimals(dec)
            s:SetConVar(cvar)
            s:Dock(TOP)
            s:DockMargin(0, 6, 0, 6)
            s:SetDark(false)
            return s
        end

        local function addCheck(label, cvar)
            local cb = vgui.Create("DCheckBoxLabel", pnl)
            cb:SetText(label)
            cb:SetConVar(cvar)
            cb:Dock(TOP)
            cb:DockMargin(0, 6, 0, 6)
            cb:SetTextColor(THEME.text)
            return cb
        end

        addSlider("Suspension Lowering Limit (0 = Auto)", "tiv_suspension_limit", 0, 15, 1)
        addSlider("Hydraulic Deployment Speed", "tiv_deploy_speed", 0.5, 3.0, 1)
        addCheck("Lock Parking Handbrake When Anchored", "tiv_deploy_handbrake")
        addSlider("Auto-Deploy Wind Trigger (MPH, 0=Off)", "tiv_auto_deploy_wind", 0, 250, 0)

        local actionTitle = vgui.Create("DLabel", pnl)
        actionTitle:SetFont("DermaDefaultBold")
        actionTitle:SetTextColor(THEME.accent)
        actionTitle:SetText("Direct Vehicle Hydraulic Actions:")
        actionTitle:Dock(TOP)
        actionTitle:DockMargin(0, 20, 0, 8)

        local actBtn = vgui.Create("DButton", pnl)
        actBtn:SetTall(36)
        actBtn:Dock(TOP)
        actBtn:DockMargin(0, 0, 0, 8)
        actBtn:SetText("TOGGLE DEPLOY / RETRACT ON CURRENT VEHICLE")
        actBtn:SetFont("DermaDefaultBold")
        actBtn:SetTextColor(Color(255, 255, 255))
        actBtn.Paint = function(self, bw, bh)
            draw.RoundedBox(6, 0, 0, bw, bh, self:IsHovered() and THEME.accent or Color(45, 52, 65))
        end
        actBtn.DoClick = function()
            RunConsoleCommand("tiv_toggle")
        end

        return pnl
    end

    -- ========================================================================
    -- TAB 4: STORM & WIND SIMULATOR
    -- ========================================================================
    local function BuildWindTab(parent)
        local pnl = vgui.Create("DScrollPanel", parent)

        local title = vgui.Create("DLabel", pnl)
        title:SetFont("DermaLarge")
        title:SetTextColor(THEME.text)
        title:SetText("Storm & Tornado Wind Physics")
        title:Dock(TOP)
        title:DockMargin(0, 0, 0, 15)

        local function addSlider(label, cvar, min, max, dec)
            local s = vgui.Create("DNumSlider", pnl)
            s:SetText(label)
            s:SetMin(min)
            s:SetMax(max)
            s:SetDecimals(dec)
            s:SetConVar(cvar)
            s:Dock(TOP)
            s:DockMargin(0, 5, 0, 5)
            s:SetDark(false)
            return s
        end

        local function addCheck(label, cvar)
            local cb = vgui.Create("DCheckBoxLabel", pnl)
            cb:SetText(label)
            cb:SetConVar(cvar)
            cb:Dock(TOP)
            cb:DockMargin(0, 5, 0, 5)
            cb:SetTextColor(THEME.text)
            return cb
        end

        addSlider("Loft Threshold (MPH)", "tiv_loft_wind_threshold", 50, 350, 0)
        addSlider("Spike Force Limit (0=Unbreakable)", "tiv_spike_force", 0, 200000, 0)
        addCheck("Violently Release Spikes When Lofted", "tiv_loft_release_spikes")
        addCheck("Compatibility Mode (GStorms / XT3)", "tiv_compat_mode")
        addSlider("Compat Anchored Wind Scale", "tiv_compat_anchored_wind_scale", 0.1, 1.0, 2)

        local simTitle = vgui.Create("DLabel", pnl)
        simTitle:SetFont("DermaDefaultBold")
        simTitle:SetTextColor(THEME.accent)
        simTitle:SetText("Interactive Wind Speed Simulator (Test Interceptor):")
        simTitle:Dock(TOP)
        simTitle:DockMargin(0, 18, 0, 8)

        local speeds = {
            { "Calm Weather (0 MPH)", 0 },
            { "EF0 Gale (75 MPH)", 75 },
            { "EF1 Storm (100 MPH)", 100 },
            { "EF2 Severe (125 MPH)", 125 },
            { "EF3 Violent (150 MPH)", 150 },
            { "EF4 Devastating (185 MPH)", 185 },
            { "EF5 Incredible (260 MPH)", 260 },
        }

        for _, sp in ipairs(speeds) do
            local btn = vgui.Create("DButton", pnl)
            btn:SetTall(28)
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, 5)
            btn:SetText(sp[1])
            btn:SetTextColor(Color(255, 255, 255))
            btn.Paint = function(self, bw, bh)
                draw.RoundedBox(4, 0, 0, bw, bh, self:IsHovered() and THEME.accent or Color(38, 42, 52))
            end
            btn.DoClick = function()
                RunConsoleCommand("tiv_wind_set", tostring(sp[2]))
                notification.AddLegacy("[TIV] Set simulated wind to " .. sp[2] .. " MPH", NOTIFY_GENERIC, 3)
            end
        end

        local clearBtn = vgui.Create("DButton", pnl)
        clearBtn:SetTall(32)
        clearBtn:Dock(TOP)
        clearBtn:DockMargin(0, 8, 0, 8)
        clearBtn:SetText("RESET TO AUTO WEATHER (CLEAR OVERRIDE)")
        clearBtn:SetFont("DermaDefaultBold")
        clearBtn:SetTextColor(Color(255, 255, 255))
        clearBtn.Paint = function(self, bw, bh)
            draw.RoundedBox(4, 0, 0, bw, bh, self:IsHovered() and THEME.danger or Color(55, 35, 40))
        end
        clearBtn.DoClick = function()
            RunConsoleCommand("tiv_wind_clear")
            notification.AddLegacy("[TIV] Cleared manual wind override", NOTIFY_GENERIC, 3)
        end

        return pnl
    end

    -- ========================================================================
    -- TAB 5: HUD & COCKPIT
    -- ========================================================================
    local function BuildHUDTab(parent)
        local pnl = vgui.Create("DScrollPanel", parent)

        local title = vgui.Create("DLabel", pnl)
        title:SetFont("DermaLarge")
        title:SetTextColor(THEME.text)
        title:SetText("Cockpit HUD & Display Customization")
        title:Dock(TOP)
        title:DockMargin(0, 0, 0, 15)

        local cb = vgui.Create("DCheckBoxLabel", pnl)
        cb:SetText("Enable Cockpit Instrument HUD")
        cb:SetConVar("tiv_hud_enabled")
        cb:Dock(TOP)
        cb:DockMargin(0, 6, 0, 10)
        cb:SetTextColor(THEME.text)

        local uLbl = vgui.Create("DLabel", pnl)
        uLbl:SetFont("DermaDefaultBold")
        uLbl:SetTextColor(THEME.accent)
        uLbl:SetText("Speedometer & Anemometer Units:")
        uLbl:Dock(TOP)
        uLbl:DockMargin(0, 6, 0, 4)

        local unitCombo = vgui.Create("DComboBox", pnl)
        unitCombo:Dock(TOP)
        unitCombo:DockMargin(0, 0, 0, 12)
        unitCombo:AddChoice("Miles Per Hour (MPH)", "mph")
        unitCombo:AddChoice("Kilometers Per Hour (KM/H)", "kmh")
        unitCombo:AddChoice("Knots (KTS)", "knots")
        local curUnit = GetConVar("tiv_hud_unit") and GetConVar("tiv_hud_unit"):GetString() or "mph"
        unitCombo:SetValue(curUnit == "kmh" and "Kilometers Per Hour (KM/H)" or (curUnit == "knots" and "Knots (KTS)" or "Miles Per Hour (MPH)"))
        unitCombo.OnSelect = function(_, _, _, val)
            RunConsoleCommand("tiv_hud_unit", val)
        end

        local pLbl = vgui.Create("DLabel", pnl)
        pLbl:SetFont("DermaDefaultBold")
        pLbl:SetTextColor(THEME.accent)
        pLbl:SetText("Screen Corner Placement:")
        pLbl:Dock(TOP)
        pLbl:DockMargin(0, 6, 0, 4)

        local posCombo = vgui.Create("DComboBox", pnl)
        posCombo:Dock(TOP)
        posCombo:DockMargin(0, 0, 0, 12)
        posCombo:AddChoice("Bottom Right (Default)", "0")
        posCombo:AddChoice("Bottom Left", "1")
        posCombo:AddChoice("Top Right", "2")
        posCombo:AddChoice("Top Left", "3")
        local curPos = GetConVar("tiv_hud_position") and GetConVar("tiv_hud_position"):GetInt() or 0
        posCombo:SetValue(curPos == 1 and "Bottom Left" or (curPos == 2 and "Top Right" or (curPos == 3 and "Top Left" or "Bottom Right (Default)")))
        posCombo.OnSelect = function(_, _, _, val)
            RunConsoleCommand("tiv_hud_position", val)
        end

        local scaleSlider = vgui.Create("DNumSlider", pnl)
        scaleSlider:SetText("HUD Size Scale")
        scaleSlider:SetMin(0.75)
        scaleSlider:SetMax(1.5)
        scaleSlider:SetDecimals(2)
        scaleSlider:SetConVar("tiv_hud_scale")
        scaleSlider:Dock(TOP)
        scaleSlider:DockMargin(0, 6, 0, 12)
        scaleSlider:SetDark(false)

        local soundCb = vgui.Create("DCheckBoxLabel", pnl)
        soundCb:SetText("Play Audible Alarms During Severe Wind & Structural Failure")
        soundCb:SetConVar("tiv_hud_sound")
        soundCb:Dock(TOP)
        soundCb:DockMargin(0, 6, 0, 12)
        soundCb:SetTextColor(THEME.text)

        local testAlarmBtn = vgui.Create("DButton", pnl)
        testAlarmBtn:SetTall(32)
        testAlarmBtn:Dock(TOP)
        testAlarmBtn:DockMargin(0, 8, 0, 8)
        testAlarmBtn:SetText("TEST EMERGENCY KLAXON SOUND")
        testAlarmBtn:SetFont("DermaDefaultBold")
        testAlarmBtn:SetTextColor(Color(255, 255, 255))
        testAlarmBtn.Paint = function(self, bw, bh)
            draw.RoundedBox(4, 0, 0, bw, bh, self:IsHovered() and THEME.warning or Color(55, 45, 30))
        end
        testAlarmBtn.DoClick = function()
            surface.PlaySound("ambient/alarms/klaxon1.wav")
        end

        return pnl
    end

    -- ========================================================================
    -- TAB 6: WIREMOD & AUTOMATION
    -- ========================================================================
    local function BuildWiremodTab(parent)
        local pnl = vgui.Create("DScrollPanel", parent)

        local title = vgui.Create("DLabel", pnl)
        title:SetFont("DermaLarge")
        title:SetTextColor(THEME.text)
        title:SetText("Wiremod & Expression 2 Integration")
        title:Dock(TOP)
        title:DockMargin(0, 0, 0, 15)

        local cb1 = vgui.Create("DCheckBoxLabel", pnl)
        cb1:SetText("Automatically Attach Wiremod Controller To Spawned TIVs")
        cb1:SetConVar("tiv_wire_auto_controller")
        cb1:Dock(TOP)
        cb1:DockMargin(0, 4, 0, 6)
        cb1:SetTextColor(THEME.text)

        local cb2 = vgui.Create("DCheckBoxLabel", pnl)
        cb2:SetText("Hide Controller Physical Entity Model")
        cb2:SetConVar("tiv_wire_hide_controller")
        cb2:Dock(TOP)
        cb2:DockMargin(0, 4, 0, 16)
        cb2:SetTextColor(THEME.text)

        local inTitle = vgui.Create("DLabel", pnl)
        inTitle:SetFont("DermaDefaultBold")
        inTitle:SetTextColor(THEME.accent)
        inTitle:SetText("Wire Inputs (Control Ports):")
        inTitle:Dock(TOP)

        local inDesc = vgui.Create("DLabel", pnl)
        inDesc:SetFont("DermaDefault")
        inDesc:SetTextColor(THEME.textDim)
        inDesc:SetWrap(true)
        inDesc:SetAutoStretchVertical(true)
        inDesc:SetText([[- Deploy (NORMAL): Triggers deploy sequence when pulsed to 1.
- Retract (NORMAL): Triggers unanchoring and suspension raising when pulsed to 1.
- ToggleDeploy (NORMAL): Toggles deployed/retracted state.
- EmergencyStop (NORMAL): Immediately halts deployment and recovers vehicle.
- Reset (NORMAL): Emergency clears faults and rebuilds spikes.
- Handbrake (NORMAL): Manually applies or releases parking brake.]])
        inDesc:Dock(TOP)
        inDesc:DockMargin(0, 4, 0, 16)

        local outTitle = vgui.Create("DLabel", pnl)
        outTitle:SetFont("DermaDefaultBold")
        outTitle:SetTextColor(THEME.accent)
        outTitle:SetText("Wire Outputs (Live Telemetry):")
        outTitle:Dock(TOP)

        local outDesc = vgui.Create("DLabel", pnl)
        outDesc:SetFont("DermaDefault")
        outDesc:SetTextColor(THEME.textDim)
        outDesc:SetWrap(true)
        outDesc:SetAutoStretchVertical(true)
        outDesc:SetText([[- State (STRING): idle, lowering, deploying_spikes, anchored, retracting, raising, lofted.
- IsDeployed (NORMAL): 1 if vehicle is anchored, 0 otherwise.
- WindSpeed (NORMAL): Current storm wind speed at vehicle in MPH.
- WindDirection (VECTOR): Unit direction vector of the wind.
- Stress (NORMAL): Wind stress ratio on anchor constraints (0.0 to 1.0).
- ActiveSpikes (NORMAL): Number of intact ground spikes.
- AnchorIntegrity (NORMAL): 1 if constraints are intact, 0 if compromised.
- VehicleSpeed (NORMAL): Vehicle ground speed in MPH.
- VerticalVelocity (NORMAL): Vehicle ascent/descent rate in MPH.]])
        outDesc:Dock(TOP)
        outDesc:DockMargin(0, 4, 0, 16)

        return pnl
    end

    -- ========================================================================
    -- TAB 7: FIELD MANUAL & EF SCALE
    -- ========================================================================
    local function BuildManualTab(parent)
        local pnl = vgui.Create("DScrollPanel", parent)

        local title = vgui.Create("DLabel", pnl)
        title:SetFont("DermaLarge")
        title:SetTextColor(THEME.text)
        title:SetText("Official Storm Intercept Field Manual")
        title:Dock(TOP)
        title:DockMargin(0, 0, 0, 15)

        local guideText = [[STEP 1: PRE-INTERCEPT APPROACH
- Use the cockpit HUD or Wiremod radar to track storm wind direction.
- Position vehicle directly into the projected path of the tornado.
- Bring the vehicle to a COMPLETE STOP (< 5 MPH).
- Align vehicle nose into the wind vector to minimize lateral surface area.

STEP 2: DEPLOYMENT EXECUTION
- Press [B] or pulse the Wire 'Deploy' input.
- Hydraulic rams lower vehicle chassis flush to suspension limits.
- Steel spikes drive into the ground terrain.
- Heavy-duty ballsocket constraints link the vehicle to the earth.

STEP 3: INTERCEPT MONITORING
- Monitor the Anchor Stress Bar on your HUD:
  * 0% - 60%: Safe holding capacity.
  * 60% - 85%: High lateral load (Caution).
  * 85% - 100%: Severe storm vortex shear.
- Audible alarm klaxons will sound if wind approaches the loft threshold!

STEP 4: RETRACTION & RELOCATION
- Once the vortex core passes, press [B] or pulse Wire 'Retract'.
- Spikes retract smoothly from the ground.
- Hydraulic suspension re-pressurizes to road height.
- Vehicle parking handbrake automatically disengages.]]

        local body = vgui.Create("DLabel", pnl)
        body:SetFont("DermaDefault")
        body:SetTextColor(THEME.text)
        body:SetWrap(true)
        body:SetAutoStretchVertical(true)
        body:SetText(guideText)
        body:Dock(TOP)
        body:DockMargin(0, 0, 0, 20)

        local efTitle = vgui.Create("DLabel", pnl)
        efTitle:SetFont("DermaDefaultBold")
        efTitle:SetTextColor(THEME.accent)
        efTitle:SetText("Enhanced Fujita (EF) Tornado Scale Reference:")
        efTitle:Dock(TOP)
        efTitle:DockMargin(0, 0, 0, 8)

        local efCard = vgui.Create("DPanel", pnl)
        efCard:SetTall(160)
        efCard:Dock(TOP)
        efCard:DockMargin(0, 0, 0, 20)
        efCard.Paint = function(self, ew, eh)
            draw.RoundedBox(6, 0, 0, ew, eh, THEME.panelBg)
            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, ew, eh)

            local rows = {
                { "EF0", "65-85 MPH",   "Light damage to trees and signs",     "0-20% Stress", Color(100, 220, 100) },
                { "EF1", "86-110 MPH",  "Roofs peeled, trailers overturned",   "20-40% Stress", Color(180, 220, 50) },
                { "EF2", "111-135 MPH", "Roofs torn, large trees snapped",     "40-60% Stress", Color(240, 200, 40) },
                { "EF3", "136-165 MPH", "Severe structural destruction",       "60-80% Stress", Color(240, 130, 30) },
                { "EF4", "166-200 MPH", "Houses leveled, vehicles thrown",     "80-95% Stress", Color(240, 60, 40) },
                { "EF5", "200+ MPH",    "Total destruction, ground swept",     "CRITICAL STRAIN", Color(220, 20, 60) },
            }

            local y = 8
            for _, r in ipairs(rows) do
                draw.SimpleText(r[1], "DermaDefaultBold", 14, y, r[5])
                draw.SimpleText(r[2], "DermaDefault", 60, y, THEME.text)
                draw.SimpleText(r[3], "DermaDefault", 180, y, THEME.textDim)
                draw.SimpleText(r[4], "DermaDefaultBold", ew - 14, y, r[5], TEXT_ALIGN_RIGHT)
                y = y + 25
            end
        end

        return pnl
    end

    -- Register sidebar tabs
    local t1 = AddSidebarTab("Quick Presets", BuildPresetsTab)
    AddSidebarTab("Spikes & Radar", BuildSpikesTab)
    AddSidebarTab("Suspension & Deploy", BuildSuspensionTab)
    AddSidebarTab("Storm & Wind", BuildWindTab)
    AddSidebarTab("Cockpit HUD", BuildHUDTab)
    AddSidebarTab("Wiremod & E2", BuildWiremodTab)
    AddSidebarTab("Field Manual", BuildManualTab)

    -- Default to Presets tab
    t1:DoClick()

    TIV.Menu.Frame = frame
end

-- Console commands to open master console
concommand.Add("tiv_menu", TIV.Menu.OpenMasterConsole)
concommand.Add("tiv_settings", TIV.Menu.OpenMasterConsole)

-- Chat command support
hook.Add("OnPlayerChat", "TIV_ChatCommand", function(ply, text)
    if ply == LocalPlayer() and (string.lower(text) == "!tiv" or string.lower(text) == "/tiv") then
        TIV.Menu.OpenMasterConsole()
        return true
    end
end)

print("[TIV] Comprehensive settings menu and master console loaded")
