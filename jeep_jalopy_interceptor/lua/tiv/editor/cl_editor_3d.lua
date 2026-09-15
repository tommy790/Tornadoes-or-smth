-- ============================================================================
-- TIV 3D INTERCEPTOR CONFIGURATION EDITOR - Client
-- Interactive 3D viewport, real-time component manipulation, model selection,
-- vehicle-relative coordinate axes, persistence, and deterministic Lua import/export.
-- ============================================================================

TIV = TIV or {}
TIV.Editor3D = TIV.Editor3D or {}

local SAVE_FILE_PATH = "tiv/saved_vehicle_config.json"

-- Active editor state
TIV.Editor3D.ActiveFrame       = nil
TIV.Editor3D.ActiveConfig      = nil
TIV.Editor3D.SelectedIndex     = 1
TIV.Editor3D.ClientsideModels  = {}

-- ============================================================================
-- PERSISTENCE HELPERS
-- ============================================================================
function TIV.Editor3D.SaveConfigToFile(config)
    if not istable(config) then return end
    if not file.IsDir("tiv", "DATA") then file.CreateDir("tiv") end

    -- Serialize to JSON for disk persistence
    local json = util.TableToJSON(config, true)
    file.Write(SAVE_FILE_PATH, json)
end

function TIV.Editor3D.LoadConfigFromFile(defaultModel)
    if file.Exists(SAVE_FILE_PATH, "DATA") then
        local raw = file.Read(SAVE_FILE_PATH, "DATA")
        if raw and raw ~= "" then
            local decoded, err = TIV.CustomConfig.DeserializeFromLua(raw)
            if decoded and istable(decoded.components) then
                for _, c in ipairs(decoded.components) do
                    if c.type == "armor_side" or c.type == "armor_front" or c.type == "armor_roof" then
                        if c.model == "models/props_c17/fence01a.mdl" or c.model == "models/props_combine/combine_fence01b.mdl" then
                            c.model = "models/props_phx/construct/metal_plate1x2.mdl"
                        end
                    end
                end
                return decoded
            end
        end
    end
    return TIV.CustomConfig.GetDefaultConfig(defaultModel or "models/buggy.mdl")
end

-- ============================================================================
-- CLEANUP CLIENTSIDE MODELS
-- ============================================================================
function TIV.Editor3D.ClearClientsideModels()
    for _, cs in pairs(TIV.Editor3D.ClientsideModels) do
        if IsValid(cs) then
            SafeRemoveEntity(cs)
        end
    end
    TIV.Editor3D.ClientsideModels = {}
end

-- ============================================================================
-- OPEN 3D CONFIGURATION EDITOR
-- ============================================================================
function TIV.Editor3D.Open()
    if IsValid(TIV.Editor3D.ActiveFrame) then
        TIV.Editor3D.ActiveFrame:Remove()
    end

    TIV.Editor3D.ClearClientsideModels()

    -- Resolve active vehicle model
    local ply = LocalPlayer()
    local veh = TIV.Deploy and TIV.Deploy.ResolveVehicle and TIV.Deploy.ResolveVehicle(ply)
    local vehModel = IsValid(veh) and veh:GetModel() or "models/buggy.mdl"

    -- Load config or default
    TIV.Editor3D.ActiveConfig  = TIV.Editor3D.LoadConfigFromFile(vehModel)
    TIV.Editor3D.ActiveConfig.vehicle_model = vehModel
    TIV.Editor3D.SelectedIndex = 1

    local winW = math.Clamp(ScrW() - 60, 1024, 1360)
    local winH = math.Clamp(ScrH() - 60, 720, 920)

    local frame = vgui.Create("DFrame")
    frame:SetSize(winW, winH)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)
    TIV.Editor3D.ActiveFrame = frame

    frame.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 22, 30, 252))
        draw.RoundedBox(6, 1, 1, w - 2, h - 2, Color(26, 32, 44, 255))
        draw.RoundedBox(4, 2, 2, w - 4, 46, Color(14, 18, 25, 255))

        draw.SimpleText("TIV 3D INTERCEPTOR CONFIGURATION EDITOR", "Trebuchet24", 18, 11, Color(240, 200, 50), TEXT_ALIGN_LEFT)
        draw.SimpleText("Local Vehicle Coordinate Space: +Y = Forward | +X = Right | +Z = Up", "DermaDefault", 520, 18, Color(160, 180, 210), TEXT_ALIGN_LEFT)
    end

    frame.OnRemove = function()
        TIV.Editor3D.ClearClientsideModels()
    end

    -- Close Button
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(36, 28)
    closeBtn:SetPos(frame:GetWide() - 44, 9)
    closeBtn:SetText("X")
    closeBtn:SetTextColor(Color(220, 220, 220))
    closeBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(200, 40, 40) or Color(45, 52, 66))
    end
    closeBtn.DoClick = function()
        frame:Close()
    end

    -- Layout: Left = 3D Viewport, Right = Controls & Component Tree
    local rightWidth = 440
    local viewportW  = winW - rightWidth - 28
    local mainH      = winH - 110

    -- ========================================================================
    -- 3D MODEL VIEWPORT
    -- ========================================================================
    local viewportPanel = vgui.Create("DPanel", frame)
    viewportPanel:SetPos(14, 54)
    viewportPanel:SetSize(viewportW, mainH)
    viewportPanel.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(12, 14, 20, 255))
        draw.RoundedBox(4, 1, 1, w - 2, h - 2, Color(18, 22, 32, 255))
    end

    local modelPanel = vgui.Create("DAdjustableModelPanel", viewportPanel)
    modelPanel:Dock(FILL)
    modelPanel:DockMargin(2, 2, 2, 2)
    modelPanel:SetModel(vehModel)
    modelPanel:SetCamPos(Vector(150, 150, 110))
    modelPanel:SetLookAt(Vector(0, 0, 10))
    modelPanel:SetFOV(42)

    -- Disable default auto-rotation / spinning of the entity or camera
    modelPanel.LayoutEntity = function(self, ent)
        if IsValid(ent) then
            ent:SetAngles(Angle(0, 0, 0))
            ent:SetPos(Vector(0, 0, 0))
        end
    end

    -- Viewport top bar with camera presets
    local camBar = vgui.Create("DPanel", viewportPanel)
    camBar:SetPos(10, 10)
    camBar:SetSize(viewportW - 20, 32)
    camBar.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(10, 14, 20, 220))
    end

    local function AddCamPreset(label, pos, look, fov)
        local btn = vgui.Create("DButton", camBar)
        btn:Dock(LEFT)
        btn:DockMargin(4, 4, 4, 4)
        btn:SetWide(84)
        btn:SetText(label)
        btn:SetTextColor(Color(220, 230, 245))
        btn.Paint = function(s, w, h)
            draw.RoundedBox(3, 0, 0, w, h, s:IsHovered() and Color(60, 120, 200) or Color(32, 40, 56))
        end
        btn.DoClick = function()
            modelPanel:SetCamPos(pos)
            modelPanel:SetLookAt(look)
            modelPanel:SetFOV(fov or 42)
        end
    end

    AddCamPreset("Isometric", Vector(150, 150, 110), Vector(0, 0, 10), 42)
    AddCamPreset("Front",     Vector(0, 230, 25),    Vector(0, 0, 10), 40)
    AddCamPreset("Side",      Vector(230, 0, 25),    Vector(0, 0, 10), 40)
    AddCamPreset("Top",       Vector(0, 0, 250),     Vector(0, 0, 0),  45)
    AddCamPreset("Rear",      Vector(0, -230, 25),   Vector(0, 0, 10), 40)

    -- Custom 3D Component Rendering & Coordinate Axes Gizmo
    modelPanel.PostDrawModel = function(self, ent)
        if not IsValid(ent) or not TIV.Editor3D.ActiveConfig then return end

        local config     = TIV.Editor3D.ActiveConfig
        local components = config.components or {}
        local selected   = TIV.Editor3D.SelectedIndex

        -- Render each component
        for idx, comp in ipairs(components) do
            local mdl = comp.model or "models/props_junk/harpoon002a.mdl"
            local cs  = TIV.Editor3D.ClientsideModels[idx]

            if not IsValid(cs) or cs:GetModel() ~= mdl then
                if IsValid(cs) then SafeRemoveEntity(cs) end
                cs = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
                if IsValid(cs) then
                    cs:SetNoDraw(true)
                    TIV.Editor3D.ClientsideModels[idx] = cs
                end
            end

            if IsValid(cs) then
                local worldPos = ent:LocalToWorld(comp.pos or Vector(0, 0, 0))
                local worldAng = ent:LocalToWorldAngles(comp.ang or Angle(0, 0, 0))

                cs:SetPos(worldPos)
                cs:SetAngles(worldAng)
                if comp.scale then cs:SetModelScale(comp.scale.x or 1, 0) end

                -- Material / Color tinting based on component type
                local isSel = (idx == selected)
                if isSel then
                    render.SetColorModulation(1.0, 0.85, 0.2) -- Vibrant Gold
                elseif comp.type == "spike" then
                    render.SetColorModulation(0.6, 0.6, 0.65)
                elseif comp.type == "armor_side" then
                    render.SetColorModulation(0.4, 0.7, 0.9)  -- Steel Blue
                elseif comp.type == "armor_front" then
                    render.SetColorModulation(0.9, 0.5, 0.3)  -- Heavy Rust/Orange
                else
                    render.SetColorModulation(0.8, 0.8, 0.8)
                end

                cs:DrawModel()
                render.SetColorModulation(1, 1, 1)

                -- Selected component highlight wireframe
                if isSel then
                    render.DrawWireframeBox(worldPos, worldAng, cs:OBBMins(), cs:OBBMaxs(), Color(255, 210, 40), true)
                end
            end
        end

        -- ====================================================================
        -- 3D VEHICLE COORDINATE AXES GIZMO
        -- Clearly shows Forward (+Y), Right (+X), and Up (+Z)
        -- ====================================================================
        local gizmoPos = ent:LocalToWorld(Vector(0, 75, 12))
        local fwdVec   = ent:GetForward()
        local rgtVec   = ent:GetRight()
        local upVec    = ent:GetUp()

        -- Forward Axis (RED)
        render.DrawLine(gizmoPos, gizmoPos + fwdVec * 40, Color(255, 60, 60), true)
        render.DrawWireframeSphere(gizmoPos + fwdVec * 40, 2, 6, 6, Color(255, 60, 60), true)

        -- Right Axis (GREEN)
        render.DrawLine(gizmoPos, gizmoPos + rgtVec * 40, Color(60, 255, 60), true)
        render.DrawWireframeSphere(gizmoPos + rgtVec * 40, 2, 6, 6, Color(60, 255, 60), true)

        -- Up Axis (BLUE)
        render.DrawLine(gizmoPos, gizmoPos + upVec * 40, Color(60, 140, 255), true)
        render.DrawWireframeSphere(gizmoPos + upVec * 40, 2, 6, 6, Color(60, 140, 255), true)
    end

    -- Viewport overlay instructions
    local instructions = vgui.Create("DPanel", viewportPanel)
    instructions:SetPos(10, mainH - 36)
    instructions:SetSize(viewportW - 20, 26)
    instructions.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, Color(10, 14, 20, 200))
        draw.SimpleText("Camera Controls: Left-Click + Drag: Rotate  |  Right-Click + Drag / Wheel: Zoom  |  Middle-Click: Pan",
            "DermaDefault", 10, 6, Color(170, 190, 220), TEXT_ALIGN_LEFT)
    end

    -- ========================================================================
    -- RIGHT PANEL: CONTROLS & COMPONENT EDITING
    -- ========================================================================
    local rightPanel = vgui.Create("DScrollPanel", frame)
    rightPanel:SetPos(viewportW + 24, 54)
    rightPanel:SetSize(rightWidth, mainH)
    rightPanel.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(16, 20, 28, 255))
        draw.RoundedBox(4, 1, 1, w - 2, h - 2, Color(22, 28, 38, 255))
    end

    local controlsContainer = vgui.Create("DPanel", rightPanel)
    controlsContainer:Dock(TOP)
    controlsContainer:DockMargin(12, 12, 12, 12)
    controlsContainer.Paint = function() end

    local function RefreshEditor()
        controlsContainer:Clear()

        local config     = TIV.Editor3D.ActiveConfig
        local components = config.components or {}
        local selIdx     = math.Clamp(TIV.Editor3D.SelectedIndex, 1, math.max(1, #components))
        TIV.Editor3D.SelectedIndex = selIdx
        local curComp    = components[selIdx]

        -- Component Selection Dropdown & Header
        local selHeader = vgui.Create("DPanel", controlsContainer)
        selHeader:Dock(TOP)
        selHeader:DockMargin(0, 0, 0, 8)
        selHeader:SetTall(32)
        selHeader.Paint = function(s, w, h)
            draw.SimpleText("ACTIVE COMPONENT", "DermaDefaultBold", 0, 8, Color(240, 200, 50), TEXT_ALIGN_LEFT)
        end

        local compCombo = vgui.Create("DComboBox", controlsContainer)
        compCombo:Dock(TOP)
        compCombo:DockMargin(0, 0, 0, 8)
        compCombo:SetTall(28)

        for i, c in ipairs(components) do
            local tag = string.upper(c.type or "PROP")
            compCombo:AddChoice(string.format("[%d] %s (%s)", i, c.name or "Component", tag), i, i == selIdx)
        end
        compCombo.OnSelect = function(s, idx, val, data)
            TIV.Editor3D.SelectedIndex = data
            RefreshEditor()
        end

        -- Component Management Buttons: Add, Duplicate, Mirror, Delete
        local btnRow = vgui.Create("DPanel", controlsContainer)
        btnRow:Dock(TOP)
        btnRow:DockMargin(0, 0, 0, 12)
        btnRow:SetTall(30)
        btnRow.Paint = function() end

        local function AddActionBtn(label, color, onClick)
            local btn = vgui.Create("DButton", btnRow)
            btn:Dock(LEFT)
            btn:DockMargin(0, 0, 6, 0)
            btn:SetWide(96)
            btn:SetText(label)
            btn:SetTextColor(Color(240, 240, 240))
            btn.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(color.r + 20, color.g + 20, color.b + 20) or color)
            end
            btn.DoClick = onClick
        end

        AddActionBtn("+ Add Spike", Color(45, 75, 110), function()
            table.insert(components, {
                id    = "spike_" .. (#components + 1),
                type  = "spike",
                name  = "Custom Spike " .. (#components + 1),
                group = "mid",
                model = "models/props_junk/harpoon002a.mdl",
                pos   = Vector(25, 0, 0),
                ang   = Angle(90, 0, 0),
                scale = Vector(1, 1, 1),
            })
            TIV.Editor3D.SelectedIndex = #components
            RefreshEditor()
        end)

        AddActionBtn("+ Add Armor", Color(40, 95, 80), function()
            table.insert(components, {
                id    = "armor_" .. (#components + 1),
                type  = "armor_side",
                name  = "Metal Plate " .. (#components + 1),
                group = "side",
                model = "models/props_phx/construct/metal_plate1x2.mdl",
                pos   = Vector(38, -10, 0),
                ang   = Angle(0, 0, 90),
                scale = Vector(1, 1, 1),
            })
            TIV.Editor3D.SelectedIndex = #components
            RefreshEditor()
        end)

        AddActionBtn("Duplicate", Color(80, 65, 120), function()
            if not curComp then return end
            local clone = table.Copy(curComp)
            clone.id    = clone.id .. "_copy"
            clone.name  = clone.name .. " (Copy)"
            clone.pos   = clone.pos + Vector(0, 5, 0)
            table.insert(components, clone)
            TIV.Editor3D.SelectedIndex = #components
            RefreshEditor()
        end)

        AddActionBtn("Mirror (X)", Color(110, 80, 40), function()
            if not curComp then return end
            local mirror = table.Copy(curComp)
            mirror.id    = mirror.id .. "_mirror"
            mirror.name  = mirror.name .. " (Mirrored)"
            mirror.pos   = Vector(-mirror.pos.x, mirror.pos.y, mirror.pos.z)
            mirror.ang   = Angle(mirror.ang.p, -mirror.ang.y, -mirror.ang.r)
            table.insert(components, mirror)
            TIV.Editor3D.SelectedIndex = #components
            RefreshEditor()
        end)

        if #components > 1 then
            local delBtn = vgui.Create("DButton", btnRow)
            delBtn:Dock(RIGHT)
            delBtn:SetWide(36)
            delBtn:SetText("DEL")
            delBtn:SetTextColor(Color(255, 120, 120))
            delBtn.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(180, 40, 40) or Color(70, 30, 30))
            end
            delBtn.DoClick = function()
                table.remove(components, selIdx)
                TIV.Editor3D.SelectedIndex = math.Clamp(selIdx - 1, 1, #components)
                TIV.Editor3D.ClearClientsideModels()
                RefreshEditor()
            end
        end

        if not curComp then return end

        -- Component Name & Model Section
        local metaPanel = vgui.Create("DPanel", controlsContainer)
        metaPanel:Dock(TOP)
        metaPanel:DockMargin(0, 0, 0, 10)
        metaPanel:SetTall(102)
        metaPanel.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(16, 20, 28, 200))
            draw.SimpleText("Component Name", "DermaDefault", 10, 10, Color(180, 190, 210), TEXT_ALIGN_LEFT)
            draw.SimpleText("Model / Prop Path", "DermaDefault", 10, 48, Color(180, 190, 210), TEXT_ALIGN_LEFT)
        end

        local nameEntry = vgui.Create("DTextEntry", metaPanel)
        nameEntry:SetPos(124, 6)
        nameEntry:SetSize(275, 24)
        nameEntry:SetText(curComp.name or "")
        nameEntry.OnChange = function(s)
            curComp.name = s:GetText()
        end

        local modelEntry = vgui.Create("DTextEntry", metaPanel)
        modelEntry:SetPos(124, 44)
        modelEntry:SetSize(275, 24)
        modelEntry:SetText(curComp.model or "")
        modelEntry.OnEnter = function(s)
            curComp.model = s:GetText()
        end

        -- Curated Model Dropdown Selector
        local curatedCombo = vgui.Create("DComboBox", metaPanel)
        curatedCombo:SetPos(124, 72)
        curatedCombo:SetSize(275, 22)
        curatedCombo:SetValue("Choose from curated presets...")

        local curatedList = TIV.CustomConfig.CuratedModels[curComp.type] or TIV.CustomConfig.CuratedModels.spikes
        for _, item in ipairs(curatedList) do
            curatedCombo:AddChoice(item.name, item.model)
        end
        curatedCombo.OnSelect = function(s, idx, val, modelPath)
            curComp.model = modelPath
            modelEntry:SetText(modelPath)
        end

        -- ====================================================================
        -- POSITION CONTROLS (X, Y, Z)
        -- ====================================================================
        local posSection = vgui.Create("DPanel", controlsContainer)
        posSection:Dock(TOP)
        posSection:DockMargin(0, 0, 0, 10)
        posSection:SetTall(160)
        posSection.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(16, 20, 28, 200))
            draw.SimpleText("POSITION (VEHICLE-RELATIVE)", "DermaDefaultBold", 10, 8, Color(240, 200, 50), TEXT_ALIGN_LEFT)
            draw.SimpleText("X: Right(+)/Left(-)   Y: Front(+)/Rear(-)   Z: Up(+)/Down(-)", "DermaDefault", 10, 24, Color(150, 165, 185), TEXT_ALIGN_LEFT)
        end

        local function BuildCoordRow(parent, label, axisKey, minVal, maxVal, yOffset)
            local lbl = vgui.Create("DLabel", parent)
            lbl:SetPos(10, yOffset)
            lbl:SetSize(82, 24)
            lbl:SetText(label)
            lbl:SetTextColor(Color(220, 225, 235))

            local numEntry = vgui.Create("DTextEntry", parent)
            numEntry:SetPos(96, yOffset)
            numEntry:SetSize(52, 24)
            numEntry:SetNumeric(true)
            numEntry:SetText(string.format("%.1f", curComp.pos[axisKey]))

            local slider = vgui.Create("DSlider", parent)
            slider:SetPos(154, yOffset + 4)
            slider:SetSize(156, 16)
            slider:SetSlideX(math.Remap(curComp.pos[axisKey], minVal, maxVal, 0, 1))

            local function UpdateVal(newVal)
                newVal = math.Clamp(newVal, minVal, maxVal)
                curComp.pos[axisKey] = newVal
                numEntry:SetText(string.format("%.1f", newVal))
                slider:SetSlideX(math.Remap(newVal, minVal, maxVal, 0, 1))
            end

            slider.OnValueChanged = function(s, x, y)
                local val = math.Remap(x, 0, 1, minVal, maxVal)
                curComp.pos[axisKey] = math.Round(val, 1)
                numEntry:SetText(string.format("%.1f", curComp.pos[axisKey]))
            end

            numEntry.OnEnter = function(s)
                local val = tonumber(s:GetText()) or 0
                UpdateVal(val)
            end

            -- Step nudge buttons: [-1] [+1]
            local btnMinus = vgui.Create("DButton", parent)
            btnMinus:SetPos(316, yOffset)
            btnMinus:SetSize(36, 22)
            btnMinus:SetText("-1")
            btnMinus.DoClick = function() UpdateVal(curComp.pos[axisKey] - 1) end

            local btnPlus = vgui.Create("DButton", parent)
            btnPlus:SetPos(356, yOffset)
            btnPlus:SetSize(36, 22)
            btnPlus:SetText("+1")
            btnPlus.DoClick = function() UpdateVal(curComp.pos[axisKey] + 1) end
        end

        BuildCoordRow(posSection, "Pos X (R/L):", "x", -100, 100, 48)
        BuildCoordRow(posSection, "Pos Y (F/R):", "y", -160, 160, 84)
        BuildCoordRow(posSection, "Pos Z (U/D):", "z", -50,  80,  120)

        -- ====================================================================
        -- ROTATION CONTROLS (Pitch, Yaw, Roll)
        -- ====================================================================
        local rotSection = vgui.Create("DPanel", controlsContainer)
        rotSection:Dock(TOP)
        rotSection:DockMargin(0, 0, 0, 10)
        rotSection:SetTall(170)

        local isSpike = (curComp.type == "spike")
        local hasAngledUpg = TIV.Progression.IsUnlocked("angled_spikes")
        local isAngleLocked = isSpike and not hasAngledUpg

        rotSection.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(16, 20, 28, 200))
            draw.SimpleText("ROTATION (PITCH / YAW / ROLL)", "DermaDefaultBold", 10, 8, Color(240, 200, 50), TEXT_ALIGN_LEFT)
            if isAngleLocked then
                draw.SimpleText("[LOCKED: Requires Angled Spikes upgrade in Progression]", "DermaDefaultBold", 10, 24, Color(240, 100, 80), TEXT_ALIGN_LEFT)
            else
                draw.SimpleText("Pitch: Tilt forward/back  |  Yaw: Heading  |  Roll: Lean side-to-side", "DermaDefault", 10, 24, Color(150, 165, 185), TEXT_ALIGN_LEFT)
            end
        end

        local function BuildAngleRow(parent, label, angKey, yOffset)
            local lbl = vgui.Create("DLabel", parent)
            lbl:SetPos(10, yOffset)
            lbl:SetSize(82, 24)
            lbl:SetText(label)
            lbl:SetTextColor(Color(220, 225, 235))

            local numEntry = vgui.Create("DTextEntry", parent)
            numEntry:SetPos(96, yOffset)
            numEntry:SetSize(52, 24)
            numEntry:SetNumeric(true)
            numEntry:SetText(string.format("%.1f", curComp.ang[angKey]))
            numEntry:SetEnabled(not isAngleLocked)

            local slider = vgui.Create("DSlider", parent)
            slider:SetPos(154, yOffset + 4)
            slider:SetSize(156, 16)
            slider:SetSlideX(math.Remap(curComp.ang[angKey], -180, 180, 0, 1))
            slider:SetEnabled(not isAngleLocked)

            local function UpdateVal(newVal)
                if isAngleLocked then return end
                newVal = math.Clamp(newVal, -180, 180)
                curComp.ang[angKey] = newVal
                numEntry:SetText(string.format("%.1f", newVal))
                slider:SetSlideX(math.Remap(newVal, -180, 180, 0, 1))
            end

            slider.OnValueChanged = function(s, x, y)
                if isAngleLocked then return end
                local val = math.Remap(x, 0, 1, -180, 180)
                curComp.ang[angKey] = math.Round(val, 1)
                numEntry:SetText(string.format("%.1f", curComp.ang[angKey]))
            end

            numEntry.OnEnter = function(s)
                local val = tonumber(s:GetText()) or 0
                UpdateVal(val)
            end

            local btnMinus = vgui.Create("DButton", parent)
            btnMinus:SetPos(316, yOffset)
            btnMinus:SetSize(36, 22)
            btnMinus:SetText("-5°")
            btnMinus:SetEnabled(not isAngleLocked)
            btnMinus.DoClick = function() UpdateVal(curComp.ang[angKey] - 5) end

            local btnPlus = vgui.Create("DButton", parent)
            btnPlus:SetPos(356, yOffset)
            btnPlus:SetSize(36, 22)
            btnPlus:SetText("+5°")
            btnPlus:SetEnabled(not isAngleLocked)
            btnPlus.DoClick = function() UpdateVal(curComp.ang[angKey] + 5) end
        end

        BuildAngleRow(rotSection, "Pitch:", "p", 48)
        BuildAngleRow(rotSection, "Yaw:",   "y", 84)
        BuildAngleRow(rotSection, "Roll:",  "r", 120)

        -- Quick angle snap buttons
        local snapRow = vgui.Create("DPanel", controlsContainer)
        snapRow:Dock(TOP)
        snapRow:DockMargin(0, 0, 0, 10)
        snapRow:SetTall(28)
        snapRow.Paint = function() end

        local function AddSnapBtn(label, targetAng)
            local btn = vgui.Create("DButton", snapRow)
            btn:Dock(LEFT)
            btn:DockMargin(0, 0, 6, 0)
            btn:SetWide(110)
            btn:SetText(label)
            btn:SetEnabled(not isAngleLocked)
            btn.DoClick = function()
                curComp.ang = Angle(targetAng.p, targetAng.y, targetAng.r)
                RefreshEditor()
            end
        end

        AddSnapBtn("Straight Down", Angle(90, 0, 0))
        AddSnapBtn("Outward 30°",   Angle(90, 0, curComp.pos.x > 0 and 30 or -30))
        AddSnapBtn("Flat 0°",       Angle(0, 0, 0))

        controlsContainer:InvalidateLayout(true)
        controlsContainer:SizeToChildren(false, true)
    end

    RefreshEditor()

    -- ========================================================================
    -- BOTTOM ACTION BAR: COPY, IMPORT, RESET, SAVE & APPLY
    -- ========================================================================
    local bottomBar = vgui.Create("DPanel", frame)
    bottomBar:SetPos(14, winH - 50)
    bottomBar:SetSize(winW - 28, 42)
    bottomBar.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(14, 18, 25, 255))
    end

    local function AddFooterBtn(label, color, dockSide, onClick)
        local btn = vgui.Create("DButton", bottomBar)
        btn:Dock(dockSide)
        btn:DockMargin(6, 6, 6, 6)
        btn:SetWide(170)
        btn:SetText(label)
        btn:SetTextColor(Color(255, 255, 255))
        btn.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(color.r + 25, color.g + 25, color.b + 25) or color)
        end
        btn.DoClick = onClick
        return btn
    end

    -- COPY CONFIGURATION BUTTON
    AddFooterBtn("COPY CONFIGURATION", Color(35, 120, 90), LEFT, function()
        local luaCode = TIV.CustomConfig.SerializeToLua(TIV.Editor3D.ActiveConfig)
        SetClipboardText(luaCode)

        -- Display confirmation dialog with text area
        local exportWin = vgui.Create("DFrame")
        exportWin:SetSize(650, 480)
        exportWin:Center()
        exportWin:SetTitle("TIV EXPORTED CONFIGURATION (COPIED TO CLIPBOARD)")
        exportWin:MakePopup()

        local txt = vgui.Create("DTextEntry", exportWin)
        txt:Dock(FILL)
        txt:DockMargin(10, 10, 10, 40)
        txt:SetMultiline(true)
        txt:SetText(luaCode)

        local copyAgain = vgui.Create("DButton", exportWin)
        copyAgain:SetSize(160, 28)
        copyAgain:SetPos(exportWin:GetWide() - 170, exportWin:GetTall() - 34)
        copyAgain:SetText("Copy to Clipboard")
        copyAgain.DoClick = function()
            SetClipboardText(luaCode)
            surface.PlaySound("buttons/button14.wav")
        end
    end)

    -- IMPORT CONFIGURATION BUTTON
    AddFooterBtn("IMPORT CONFIGURATION", Color(55, 80, 140), LEFT, function()
        local importWin = vgui.Create("DFrame")
        importWin:SetSize(650, 480)
        importWin:Center()
        importWin:SetTitle("IMPORT TIV CONFIGURATION (PASTE LUA TABLE OR JSON)")
        importWin:MakePopup()

        local txt = vgui.Create("DTextEntry", importWin)
        txt:Dock(FILL)
        txt:DockMargin(10, 10, 10, 40)
        txt:SetMultiline(true)
        txt:SetPlaceholderText("Paste your exported Lua configuration or JSON code here...")

        local applyBtn = vgui.Create("DButton", importWin)
        applyBtn:SetSize(180, 28)
        applyBtn:SetPos(importWin:GetWide() - 190, importWin:GetTall() - 34)
        applyBtn:SetText("Parse & Apply to Editor")
        applyBtn.DoClick = function()
            local raw = txt:GetText()
            local imported, err = TIV.CustomConfig.DeserializeFromLua(raw)
            if imported and istable(imported.components) then
                TIV.Editor3D.ActiveConfig = imported
                TIV.Editor3D.SelectedIndex = 1
                TIV.Editor3D.ClearClientsideModels()
                RefreshEditor()
                importWin:Close()
                surface.PlaySound("garrysmod/save_load1.wav")
            else
                Derma_Message("Import Failed: " .. (err or "Invalid configuration syntax"), "Import Error", "OK")
            end
        end
    end)

    -- RESET TO DEFAULTS BUTTON
    AddFooterBtn("RESET TO DEFAULTS", Color(90, 40, 40), LEFT, function()
        Derma_Query("Reset all components back to vehicle factory defaults?", "Confirm Reset",
            "Reset", function()
                TIV.Editor3D.ActiveConfig = TIV.CustomConfig.GetDefaultConfig(vehModel)
                TIV.Editor3D.SelectedIndex = 1
                TIV.Editor3D.ClearClientsideModels()
                RefreshEditor()
            end,
            "Cancel", function() end
        )
    end)

    -- SAVE & APPLY TO VEHICLE
    AddFooterBtn("SAVE & APPLY TO VEHICLE", Color(180, 120, 20), RIGHT, function()
        local config = TIV.Editor3D.ActiveConfig
        TIV.Editor3D.SaveConfigToFile(config)

        local luaStr = TIV.CustomConfig.SerializeToLua(config)
        net.Start("TIV_ApplyVehicleConfig")
            net.WriteString(luaStr)
        net.SendToServer()

        surface.PlaySound("garrysmod/save_load1.wav")
        frame:Close()
    end)
end

concommand.Add("tiv_editor", function()
    TIV.Editor3D.Open()
end)

print("[TIV] 3D Interceptor Configuration Editor loaded")
