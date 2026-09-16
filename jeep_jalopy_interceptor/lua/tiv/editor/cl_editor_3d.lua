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
TIV.Editor3D.StepSize          = TIV.Editor3D.StepSize or 1.0
TIV.Editor3D.GhostMode         = TIV.Editor3D.GhostMode or false
TIV.Editor3D.ShowAxes          = (TIV.Editor3D.ShowAxes ~= false)
TIV.Editor3D.ShowWireframes    = TIV.Editor3D.ShowWireframes or false

-- ============================================================================
-- PERSISTENCE HELPERS
-- ============================================================================
function TIV.Editor3D.SaveConfigToFile(config)
    if not istable(config) then return end
    if not file.IsDir("tiv", "DATA") then file.CreateDir("tiv") end
    if not file.IsDir("tiv/configs", "DATA") then file.CreateDir("tiv/configs") end

    local model = string.lower(config.vehicle_model or "models/buggy.mdl")
    local json = util.TableToJSON(config, true)

    -- Save to per-model configuration file
    local modelPath = TIV.CustomConfig.GetConfigFileName(model)
    file.Write(modelPath, json)

    -- Keep legacy global path updated as latest
    file.Write(SAVE_FILE_PATH, json)
end

function TIV.Editor3D.LoadConfigFromFile(targetModel)
    targetModel = string.lower(targetModel or "models/buggy.mdl")
    local modelPath = TIV.CustomConfig.GetConfigFileName(targetModel)

    local raw = nil
    if file.Exists(modelPath, "DATA") then
        raw = file.Read(modelPath, "DATA")
    elseif file.Exists(SAVE_FILE_PATH, "DATA") then
        local legacyRaw = file.Read(SAVE_FILE_PATH, "DATA")
        if legacyRaw and legacyRaw ~= "" then
            local decoded = util.JSONToTable(legacyRaw)
            if not decoded or (decoded.vehicle_model and string.lower(decoded.vehicle_model) == targetModel) then
                raw = legacyRaw
            end
        end
    end

    if raw and raw ~= "" then
        local decoded, err = TIV.CustomConfig.DeserializeFromLua(raw)
        if decoded and istable(decoded.components) then
            decoded.vehicle_model = targetModel
            for _, c in ipairs(decoded.components) do
                if c.type == "armor_side" or c.type == "armor_front" or c.type == "armor_roof" then
                    if c.model == "models/props_c17/fence01a.mdl" or c.model == "models/props_combine/combine_fence01b.mdl" then
                        c.model = "models/props_phx/construct/metal_plate1x2.mdl"
                    end
                end
            end

            local hasAngledUpg = TIV.Progression and TIV.Progression.IsUnlocked and TIV.Progression.IsUnlocked("angled_spikes")
            if hasAngledUpg then
                -- Auto-apply angled spike preset if upgrade is active and spikes are at default 90 degrees
                for _, c in ipairs(decoded.components) do
                    if c.type == "spike" and c.ang and math.abs(c.ang.p - 90) < 0.1 and math.abs(c.ang.y) < 0.1 and math.abs(c.ang.r) < 0.1 then
                        if c.pos and c.pos.x > 0 then
                            c.ang = Angle(80, 0, 0)
                        elseif c.pos and c.pos.x < 0 then
                            c.ang = Angle(100, 0, 0)
                        end
                    end
                end
            else
                -- Lock all spikes to straight 90 degrees if upgrade has not been purchased
                for _, c in ipairs(decoded.components) do
                    if c.type == "spike" then
                        c.ang = Angle(90, 0, 0)
                    end
                end
            end

            return decoded
        end
    end

    return TIV.CustomConfig.GetDefaultConfig(targetModel)
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
    local curVehModel = IsValid(veh) and veh:GetModel() or "models/buggy.mdl"
    curVehModel = string.lower(curVehModel)

    -- Load config or default
    TIV.Editor3D.ActiveConfig  = TIV.Editor3D.LoadConfigFromFile(curVehModel)
    TIV.Editor3D.ActiveConfig.vehicle_model = curVehModel
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

    -- ========================================================================
    -- INTERCEPTOR MODEL SWITCHER BAR
    -- Allows switching the base vehicle model to configure different vehicles
    -- or entities identified as interceptors.
    -- ========================================================================
    local modelBar = vgui.Create("DPanel", frame)
    modelBar:SetPos(14, 50)
    modelBar:SetSize(winW - 28, 42)
    modelBar.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(14, 18, 25, 255))
        draw.RoundedBox(4, 1, 1, w - 2, h - 2, Color(24, 30, 42, 255))
    end

    local modelLbl = vgui.Create("DLabel", modelBar)
    modelLbl:SetPos(12, 10)
    modelLbl:SetSize(140, 22)
    modelLbl:SetText("TARGET INTERCEPTOR:")
    modelLbl:SetFont("DermaDefaultBold")
    modelLbl:SetTextColor(Color(240, 205, 50))

    local modelCombo = vgui.Create("DComboBox", modelBar)
    modelCombo:SetPos(156, 8)
    modelCombo:SetSize(210, 26)

    local modelEntry = vgui.Create("DTextEntry", modelBar)
    modelEntry:SetPos(372, 8)
    modelEntry:SetSize(180, 26)
    modelEntry:SetText(curVehModel)

    local switchBtn = vgui.Create("DButton", modelBar)
    switchBtn:SetPos(558, 8)
    switchBtn:SetSize(90, 26)
    switchBtn:SetText("Switch Model")
    switchBtn:SetTextColor(Color(255, 255, 255))
    switchBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(60, 130, 190) or Color(45, 100, 150))
    end

    local useVehBtn = vgui.Create("DButton", modelBar)
    useVehBtn:SetPos(654, 8)
    useVehBtn:SetSize(105, 26)
    useVehBtn:SetText("Use My Vehicle")
    useVehBtn:SetTextColor(Color(255, 255, 255))
    useVehBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(45, 145, 90) or Color(35, 115, 70))
    end

    local cloneBtn = vgui.Create("DButton", modelBar)
    cloneBtn:SetPos(765, 8)
    cloneBtn:SetSize(95, 26)
    cloneBtn:SetText("Clone From...")
    cloneBtn:SetTextColor(Color(255, 255, 255))
    cloneBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(110, 80, 150) or Color(85, 60, 115))
    end

    local tagBtn = vgui.Create("DButton", modelBar)
    tagBtn:SetPos(866, 8)
    tagBtn:SetSize(115, 26)
    tagBtn:SetText("Tag Aimed Entity")
    tagBtn:SetTextColor(Color(255, 255, 255))
    tagBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(165, 105, 35) or Color(130, 80, 25))
    end

    -- Layout: Left = 3D Viewport, Right = Controls & Component Tree
    local rightWidth = 440
    local viewportW  = winW - rightWidth - 28
    local panelY     = 98
    local mainH      = winH - 156

    -- ========================================================================
    -- 3D MODEL VIEWPORT
    -- ========================================================================
    local viewportPanel = vgui.Create("DPanel", frame)
    viewportPanel:SetPos(14, panelY)
    viewportPanel:SetSize(viewportW, mainH)
    viewportPanel.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(12, 14, 20, 255))
        draw.RoundedBox(4, 1, 1, w - 2, h - 2, Color(18, 22, 32, 255))
    end

    local modelPanel = vgui.Create("DAdjustableModelPanel", viewportPanel)
    modelPanel:Dock(FILL)
    modelPanel:DockMargin(2, 2, 2, 2)
    modelPanel:SetModel(curVehModel)
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

    modelPanel.PreDrawModel = function(self, ent)
        if TIV.Editor3D.GhostMode then
            render.SetBlend(0.35)
        else
            render.SetBlend(1.0)
        end
        return true
    end

    -- Viewport Quick Tools Bar (Top Bar)
    local toolBar = vgui.Create("DPanel", viewportPanel)
    toolBar:SetPos(10, 10)
    toolBar:SetSize(viewportW - 20, 32)
    toolBar.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(10, 14, 20, 220))
    end

    local function AddViewportToolBtn(label, isActiveFn, onClick)
        local btn = vgui.Create("DButton", toolBar)
        btn:Dock(LEFT)
        btn:DockMargin(4, 4, 4, 4)
        btn:SetWide(116)
        btn:SetText(label)
        btn:SetTextColor(Color(220, 235, 250))
        btn.Paint = function(s, w, h)
            local active = isActiveFn and isActiveFn()
            local bgCol = active and Color(35, 110, 160) or (s:IsHovered() and Color(45, 60, 85) or Color(24, 30, 42))
            draw.RoundedBox(3, 0, 0, w, h, bgCol)
            if active then
                surface.SetDrawColor(0, 220, 255, 200)
                surface.DrawOutlinedRect(0, 0, w, h)
            end
        end
        btn.DoClick = function(s)
            onClick(s)
        end
        return btn
    end

    AddViewportToolBtn("Focus Component", nil, function()
        if not IsValid(modelPanel.Entity) or not TIV.Editor3D.ActiveConfig then return end
        local comp = TIV.Editor3D.ActiveConfig.components and TIV.Editor3D.ActiveConfig.components[TIV.Editor3D.SelectedIndex]
        if comp then
            local targetWorld = modelPanel.Entity:LocalToWorld(comp.pos or Vector(0, 0, 0))
            modelPanel:SetLookAt(targetWorld)
            modelPanel:SetCamPos(targetWorld + Vector(45, 45, 30))
            modelPanel:SetFOV(36)
            surface.PlaySound("buttons/button14.wav")
        end
    end)

    AddViewportToolBtn("Ghost Chassis", function() return TIV.Editor3D.GhostMode == true end, function()
        TIV.Editor3D.GhostMode = not TIV.Editor3D.GhostMode
        surface.PlaySound("buttons/lightswitch2.wav")
    end)

    AddViewportToolBtn("Axes Gizmo", function() return TIV.Editor3D.ShowAxes ~= false end, function()
        TIV.Editor3D.ShowAxes = (TIV.Editor3D.ShowAxes == false)
        surface.PlaySound("buttons/lightswitch2.wav")
    end)

    AddViewportToolBtn("Wireframes", function() return TIV.Editor3D.ShowWireframes == true end, function()
        TIV.Editor3D.ShowWireframes = not TIV.Editor3D.ShowWireframes
        surface.PlaySound("buttons/lightswitch2.wav")
    end)

    AddViewportToolBtn("Reset View", nil, function()
        if IsValid(modelPanel.Entity) then
            local rmn, rmx = modelPanel.Entity:GetRenderBounds()
            local center = (rmn + rmx) * 0.5
            local size   = (rmx - rmn):Length()
            modelPanel:SetLookAt(Vector(0, 0, center.z))
            local dist = math.Clamp(size * 1.35, 140, 480)
            modelPanel:SetCamPos(Vector(dist * 0.7, dist * 0.7, dist * 0.5 + center.z))
            modelPanel:SetFOV(42)
            surface.PlaySound("buttons/button14.wav")
        end
    end)

    -- Custom 3D Component Rendering & Coordinate Axes Gizmo
    modelPanel.PostDrawModel = function(self, ent)
        if not IsValid(ent) or not TIV.Editor3D.ActiveConfig then return end
        render.SetBlend(1.0)

        local config     = TIV.Editor3D.ActiveConfig
        local components = config.components or {}
        local selected   = TIV.Editor3D.SelectedIndex
        local hasAngledUpg = TIV.Progression and TIV.Progression.IsUnlocked and TIV.Progression.IsUnlocked("angled_spikes")

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
                local compAng = comp.ang or Angle(90, 0, 0)
                if comp.type == "spike" and not hasAngledUpg then
                    compAng = Angle(90, 0, 0)
                end

                local worldPos = ent:LocalToWorld(comp.pos or Vector(0, 0, 0))
                local worldAng = ent:LocalToWorldAngles(compAng)

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

                -- Live tactical radar display preview on monitor glass in 3D editor
                if comp.type == "radar_screen" and TIV.Instruments and TIV.Instruments.DrawRadarScreen and TIV.Instruments.GetMonitorConfig then
                    local cfg = TIV.Instruments.GetMonitorConfig(cs)
                    local pScale = (comp.scale and comp.scale.x) or 1.0
                    local centerPos = cs:LocalToWorld(cfg.offset * pScale)
                    local screenAng = cs:LocalToWorldAngles(cfg.rot)
                    local scale = cfg.scale * pScale
                    local halfW = (cfg.w * 0.5) * scale
                    local halfH = (cfg.h * 0.5) * scale
                    local topLeftPos = centerPos - screenAng:Forward() * halfW - screenAng:Right() * halfH

                    cam.Start3D2D(topLeftPos, screenAng, scale)
                        render.ClearStencil()
                        render.SetStencilEnable(true)
                        render.SetStencilTestMask(0xFF)
                        render.SetStencilWriteMask(0xFF)
                        render.SetStencilReferenceValue(1)
                        render.SetStencilCompareFunction(STENCIL_ALWAYS)
                        render.SetStencilPassOperation(STENCIL_REPLACE)
                        render.SetStencilFailOperation(STENCIL_KEEP)
                        render.SetStencilZFailOperation(STENCIL_KEEP)

                        -- Mask out the exact 512x512 physical monitor face
                        surface.SetDrawColor(0, 0, 0, 255)
                        surface.DrawRect(0, 0, 512, 512)

                        render.SetStencilCompareFunction(STENCIL_EQUAL)
                        render.SetStencilPassOperation(STENCIL_KEEP)

                        TIV.Instruments.DrawRadarScreen(cs, nil, TIV.Instruments.RadarData)

                        render.SetStencilEnable(false)
                    cam.End3D2D()
                end

                -- Selected component highlight wireframe or global wireframe
                if isSel or TIV.Editor3D.ShowWireframes then
                    render.DrawWireframeBox(worldPos, worldAng, cs:OBBMins(), cs:OBBMaxs(), isSel and Color(255, 210, 40) or Color(0, 180, 255, 120), true)
                end
            end
        end

        -- ====================================================================
        -- 3D VEHICLE COORDINATE AXES GIZMO
        -- Clearly shows Forward (+Y), Right (+X), and Up (+Z)
        -- ====================================================================
        if TIV.Editor3D.ShowAxes ~= false then
            local mn, mx   = ent:GetRenderBounds()
            local gizmoPos = ent:LocalToWorld(Vector(0, mx.y * 0.75, math.max(12, mx.z * 0.35)))
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
    rightPanel:SetPos(viewportW + 24, panelY)
    rightPanel:SetSize(rightWidth, mainH)
    rightPanel.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(16, 20, 28, 255))
        draw.RoundedBox(4, 1, 1, w - 2, h - 2, Color(22, 28, 38, 255))
    end

    local controlsContainer = vgui.Create("DPanel", rightPanel)
    controlsContainer:Dock(TOP)
    controlsContainer:DockMargin(12, 12, 12, 12)
    controlsContainer.Paint = function() end

    -- Forward declarations
    local RefreshEditor
    local PopulateModelDropdown
    local SwitchToModel

    PopulateModelDropdown = function(combo, activeMdl)
        if not IsValid(combo) then return end
        combo:Clear()

        local presets = {
            { name = "HL2 Buggy / Jeep",         model = "models/buggy.mdl" },
            { name = "EP2 Jalopy / Muscle Car", model = "models/vehicle.mdl" },
            { name = "Combine APC",             model = "models/combine_apc.mdl" },
            { name = "Combine APC (Prop)",      model = "models/props_vehicles/apc001.mdl" },
            { name = "HL2 Airboat",             model = "models/airboat.mdl" },
            { name = "Van / Ambulance",         model = "models/props_vehicles/van.mdl" },
            { name = "Pickup Truck",            model = "models/props_vehicles/pickup01.mdl" },
        }

        local activeLower = string.lower(activeMdl or "")
        local matched = false

        for _, p in ipairs(presets) do
            local isSel = (activeLower == string.lower(p.model))
            if isSel then matched = true end
            combo:AddChoice(p.name .. " (" .. string.GetFileFromFilename(p.model) .. ")", p.model, isSel)
        end

        if TIV.GetIdentifiedInterceptors then
            local activeList = TIV.GetIdentifiedInterceptors()
            if #activeList > 0 then
                combo:AddSpacer()
                for _, info in ipairs(activeList) do
                    local isSel = (activeLower == string.lower(info.model))
                    if isSel then matched = true end
                    combo:AddChoice("[Active] " .. info.name, info.model, isSel)
                end
            end
        end

        if not matched and activeMdl and activeMdl ~= "" then
            combo:AddSpacer()
            combo:AddChoice("Custom: " .. string.GetFileFromFilename(activeMdl), activeMdl, true)
        end
    end

    SwitchToModel = function(targetModel)
        if not targetModel or string.Trim(targetModel) == "" then return end
        targetModel = string.lower(string.Trim(targetModel))

        -- Auto-save previous vehicle configuration before switching
        if TIV.Editor3D.ActiveConfig and TIV.Editor3D.ActiveConfig.vehicle_model then
            TIV.Editor3D.SaveConfigToFile(TIV.Editor3D.ActiveConfig)
        end

        curVehModel = targetModel

        -- Update model in 3D viewport
        if IsValid(modelPanel) then
            modelPanel:SetModel(curVehModel)
            if IsValid(modelPanel.Entity) then
                modelPanel.Entity:SetAngles(Angle(0, 0, 0))
                modelPanel.Entity:SetPos(Vector(0, 0, 0))

                local rmn, rmx = modelPanel.Entity:GetRenderBounds()
                local center = (rmn + rmx) * 0.5
                local size   = (rmx - rmn):Length()
                modelPanel:SetLookAt(Vector(0, 0, center.z))
                local dist = math.Clamp(size * 1.35, 140, 480)
                modelPanel:SetCamPos(Vector(dist * 0.7, dist * 0.7, dist * 0.5 + center.z))
            end
        end

        -- Load configuration for new model
        TIV.Editor3D.ActiveConfig = TIV.Editor3D.LoadConfigFromFile(curVehModel)
        TIV.Editor3D.ActiveConfig.vehicle_model = curVehModel
        TIV.Editor3D.SelectedIndex = 1

        -- Clear clientside preview models
        TIV.Editor3D.ClearClientsideModels()

        -- Synchronize UI inputs
        if IsValid(modelEntry) then
            modelEntry:SetText(curVehModel)
        end
        if IsValid(modelCombo) then
            PopulateModelDropdown(modelCombo, curVehModel)
        end

        if isfunction(RefreshEditor) then
            RefreshEditor()
        end
        surface.PlaySound("buttons/button14.wav")
    end

    -- Initial dropdown population and event wiring
    PopulateModelDropdown(modelCombo, curVehModel)

    modelCombo.OnSelect = function(s, idx, val, modelPath)
        if modelPath and modelPath ~= "" and string.lower(modelPath) ~= string.lower(curVehModel) then
            SwitchToModel(modelPath)
        end
    end

    modelEntry.OnEnter = function(s)
        local inputMdl = s:GetText()
        if inputMdl and inputMdl ~= "" and string.lower(inputMdl) ~= string.lower(curVehModel) then
            SwitchToModel(inputMdl)
        end
    end

    switchBtn.DoClick = function()
        local inputMdl = modelEntry:GetText()
        if inputMdl and inputMdl ~= "" then
            SwitchToModel(inputMdl)
        end
    end

    useVehBtn.DoClick = function()
        local targetEnt = (TIV.Deploy and TIV.Deploy.ResolveVehicle and TIV.Deploy.ResolveVehicle(LocalPlayer()))
        if not IsValid(targetEnt) then
            local tr = LocalPlayer():GetEyeTrace()
            if tr.Hit and IsValid(tr.Entity) and (TIV.IsSupportedVehicle(tr.Entity) or tr.Entity:IsVehicle()) then
                targetEnt = tr.Entity
            end
        end

        if IsValid(targetEnt) then
            local mdl = targetEnt:GetModel()
            if mdl and mdl ~= "" then
                SwitchToModel(mdl)
                Derma_Message("Loaded model from " .. (targetEnt:IsVehicle() and "vehicle" or "interceptor") .. ":\n" .. mdl, "Vehicle Detected", "OK")
                return
            end
        end

        Derma_Message("No vehicle or interceptor found in your cockpit or crosshairs.\nSit inside a vehicle or aim at one in the world.", "Vehicle Detection", "OK")
    end

    cloneBtn.DoClick = function()
        local menu = DermaMenu()
        local presets = {
            { name = "HL2 Buggy / Jeep",         model = "models/buggy.mdl" },
            { name = "EP2 Jalopy / Muscle Car", model = "models/vehicle.mdl" },
            { name = "Combine APC",             model = "models/combine_apc.mdl" },
            { name = "Combine APC (Prop)",      model = "models/props_vehicles/apc001.mdl" },
            { name = "HL2 Airboat",             model = "models/airboat.mdl" },
            { name = "Van / Ambulance",         model = "models/props_vehicles/van.mdl" },
            { name = "Pickup Truck",            model = "models/props_vehicles/pickup01.mdl" },
        }

        for _, p in ipairs(presets) do
            if string.lower(p.model) ~= string.lower(curVehModel) then
                menu:AddOption("Copy layout from " .. p.name, function()
                    local srcCfg = TIV.Editor3D.LoadConfigFromFile(p.model)
                    if srcCfg and istable(srcCfg.components) then
                        local clonedComponents = table.Copy(srcCfg.components)
                        TIV.Editor3D.ActiveConfig.components = clonedComponents
                        TIV.Editor3D.SelectedIndex = 1
                        TIV.Editor3D.ClearClientsideModels()
                        RefreshEditor()
                        surface.PlaySound("buttons/button15.wav")
                    end
                end)
            end
        end
        menu:Open()
    end

    tagBtn.DoClick = function()
        net.Start("TIV_TagAimedInterceptor")
        net.SendToServer()
        timer.Simple(0.25, function()
            if IsValid(modelCombo) then
                PopulateModelDropdown(modelCombo, curVehModel)
            end
        end)
    end

    -- ========================================================================
    -- UNDO / REDO HISTORY SYSTEM
    -- ========================================================================
    local undoStack = {}
    local redoStack = {}

    local function PushUndo()
        local config = TIV.Editor3D.ActiveConfig
        if not config or not istable(config.components) then return end
        table.insert(undoStack, {
            components = table.Copy(config.components),
            selIdx     = TIV.Editor3D.SelectedIndex,
        })
        if #undoStack > 35 then
            table.remove(undoStack, 1)
        end
        redoStack = {}
    end

    local function PerformUndo()
        if #undoStack == 0 then return end
        local config = TIV.Editor3D.ActiveConfig
        if not config or not istable(config.components) then return end

        table.insert(redoStack, {
            components = table.Copy(config.components),
            selIdx     = TIV.Editor3D.SelectedIndex,
        })

        local prev = table.remove(undoStack)
        config.components = table.Copy(prev.components)
        TIV.Editor3D.SelectedIndex = math.Clamp(prev.selIdx or 1, 1, #config.components)
        TIV.Editor3D.ClearClientsideModels()
        RefreshEditor()
        surface.PlaySound("buttons/button15.wav")
    end

    local function PerformRedo()
        if #redoStack == 0 then return end
        local config = TIV.Editor3D.ActiveConfig
        if not config or not istable(config.components) then return end

        table.insert(undoStack, {
            components = table.Copy(config.components),
            selIdx     = TIV.Editor3D.SelectedIndex,
        })

        local nextState = table.remove(redoStack)
        config.components = table.Copy(nextState.components)
        TIV.Editor3D.SelectedIndex = math.Clamp(nextState.selIdx or 1, 1, #config.components)
        TIV.Editor3D.ClearClientsideModels()
        RefreshEditor()
        surface.PlaySound("buttons/button14.wav")
    end

    frame.OnKeyCodePressed = function(s, code)
        if input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL) then
            if code == KEY_Z then
                PerformUndo()
            elseif code == KEY_Y then
                PerformRedo()
            end
        end
    end

    RefreshEditor = function()
        controlsContainer:Clear()

        local config     = TIV.Editor3D.ActiveConfig
        local components = config.components or {}
        local selIdx     = math.Clamp(TIV.Editor3D.SelectedIndex, 1, math.max(1, #components))
        TIV.Editor3D.SelectedIndex = selIdx
        local curComp    = components[selIdx]

        -- Component Selection Dropdown & Header
        local selHeader = vgui.Create("DPanel", controlsContainer)
        selHeader:Dock(TOP)
        selHeader:DockMargin(0, 0, 0, 6)
        selHeader:SetTall(28)
        selHeader.Paint = function(s, w, h)
            draw.SimpleText("ACTIVE COMPONENT", "DermaDefaultBold", 0, 6, Color(240, 200, 50), TEXT_ALIGN_LEFT)
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

        -- ====================================================================
        -- TOOL ROW 1: UNDO / REDO & STEP MULTIPLIER
        -- ====================================================================
        local utilRow = vgui.Create("DPanel", controlsContainer)
        utilRow:Dock(TOP)
        utilRow:DockMargin(0, 0, 0, 8)
        utilRow:SetTall(28)
        utilRow.Paint = function() end

        local undoBtn = vgui.Create("DButton", utilRow)
        undoBtn:Dock(LEFT)
        undoBtn:DockMargin(0, 0, 4, 0)
        undoBtn:SetWide(86)
        undoBtn:SetText(#undoStack > 0 and string.format("< Undo (%d)", #undoStack) or "< Undo")
        undoBtn:SetTextColor(#undoStack > 0 and Color(230, 235, 245) or Color(130, 140, 150))
        undoBtn:SetEnabled(#undoStack > 0)
        undoBtn.Paint = function(s, w, h)
            local bg = s:IsEnabled() and (s:IsHovered() and Color(55, 75, 105) or Color(32, 42, 60)) or Color(20, 24, 32)
            draw.RoundedBox(4, 0, 0, w, h, bg)
        end
        undoBtn.DoClick = PerformUndo

        local redoBtn = vgui.Create("DButton", utilRow)
        redoBtn:Dock(LEFT)
        redoBtn:DockMargin(0, 0, 12, 0)
        redoBtn:SetWide(86)
        redoBtn:SetText(#redoStack > 0 and string.format("Redo (%d) >", #redoStack) or "Redo >")
        redoBtn:SetTextColor(#redoStack > 0 and Color(230, 235, 245) or Color(130, 140, 150))
        redoBtn:SetEnabled(#redoStack > 0)
        redoBtn.Paint = function(s, w, h)
            local bg = s:IsEnabled() and (s:IsHovered() and Color(55, 75, 105) or Color(32, 42, 60)) or Color(20, 24, 32)
            draw.RoundedBox(4, 0, 0, w, h, bg)
        end
        redoBtn.DoClick = PerformRedo

        -- Step size toggle buttons: 0.1, 0.5, 1.0, 5.0, 10.0
        local stepLbl = vgui.Create("DLabel", utilRow)
        stepLbl:Dock(LEFT)
        stepLbl:DockMargin(0, 0, 6, 0)
        stepLbl:SetWide(42)
        stepLbl:SetText("Step:")
        stepLbl:SetTextColor(Color(170, 185, 205))

        local curStep = TIV.Editor3D.StepSize or 1.0
        local stepList = { 0.1, 0.5, 1.0, 5.0, 10.0 }
        for _, st in ipairs(stepList) do
            local sBtn = vgui.Create("DButton", utilRow)
            sBtn:Dock(LEFT)
            sBtn:DockMargin(0, 0, 4, 0)
            sBtn:SetWide(34)
            sBtn:SetText(tostring(st))
            sBtn:SetTextColor(Color(240, 240, 240))
            sBtn.Paint = function(s, w, h)
                local isCur = (curStep == st)
                local bg = isCur and Color(0, 160, 200) or (s:IsHovered() and Color(45, 60, 80) or Color(24, 30, 42))
                draw.RoundedBox(3, 0, 0, w, h, bg)
            end
            sBtn.DoClick = function()
                TIV.Editor3D.StepSize = st
                RefreshEditor()
                surface.PlaySound("buttons/button14.wav")
            end
        end

        -- ====================================================================
        -- TOOL ROW 2: ADD COMPONENT TOOLBAR
        -- ====================================================================
        local addRow = vgui.Create("DPanel", controlsContainer)
        addRow:Dock(TOP)
        addRow:DockMargin(0, 0, 0, 8)
        addRow:SetTall(28)
        addRow.Paint = function() end

        local function AddCreationBtn(label, color, onClick)
            local btn = vgui.Create("DButton", addRow)
            btn:Dock(LEFT)
            btn:DockMargin(0, 0, 5, 0)
            btn:SetWide(96)
            btn:SetText(label)
            btn:SetTextColor(Color(240, 240, 240))
            btn.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(color.r + 20, color.g + 20, color.b + 20) or color)
            end
            btn.DoClick = onClick
        end

        AddCreationBtn("+ Spike", Color(45, 75, 110), function()
            PushUndo()
            local hasAngledUpg = TIV.Progression and TIV.Progression.IsUnlocked and TIV.Progression.IsUnlocked("angled_spikes")
            table.insert(components, {
                id    = "spike_" .. (#components + 1),
                type  = "spike",
                name  = "Custom Spike " .. (#components + 1),
                group = "mid",
                model = "models/props_junk/harpoon002a.mdl",
                pos   = Vector(25, 0, 0),
                ang   = hasAngledUpg and Angle(80, 0, 0) or Angle(90, 0, 0),
                scale = Vector(1, 1, 1),
            })
            TIV.Editor3D.SelectedIndex = #components
            RefreshEditor()
        end)

        AddCreationBtn("+ Side Armor", Color(40, 95, 80), function()
            PushUndo()
            table.insert(components, {
                id    = "armor_s" .. (#components + 1),
                type  = "armor_side",
                name  = "Side Plate " .. (#components + 1),
                group = "side",
                model = "models/props_phx/construct/metal_plate1x2.mdl",
                pos   = Vector(42, -10, 32),
                ang   = Angle(-90, 90, 90),
                scale = Vector(1, 1, 1),
            })
            TIV.Editor3D.SelectedIndex = #components
            RefreshEditor()
        end)

        AddCreationBtn("+ Front Armor", Color(110, 70, 35), function()
            PushUndo()
            table.insert(components, {
                id    = "armor_f" .. (#components + 1),
                type  = "armor_front",
                name  = "Front Plate " .. (#components + 1),
                group = "front",
                model = "models/props_phx/construct/metal_plate1x2.mdl",
                pos   = Vector(0, 60, 35),
                ang   = Angle(-95, 90, 0),
                scale = Vector(1, 1, 1),
            })
            TIV.Editor3D.SelectedIndex = #components
            RefreshEditor()
        end)

        AddCreationBtn("+ Radar Screen", Color(60, 45, 105), function()
            PushUndo()
            table.insert(components, {
                id    = "screen_radar",
                type  = "radar_screen",
                name  = "Radar Monitor",
                group = "interior",
                model = "models/kobilica/wiremonitorsmall.mdl",
                pos   = Vector(14, 18, 40),
                ang   = Angle(10, -125, 0),
                scale = Vector(1, 1, 1),
            })
            TIV.Editor3D.SelectedIndex = #components
            RefreshEditor()
        end)

        -- ====================================================================
        -- TOOL ROW 3: COMPONENT OPERATIONS (DUPLICATE, MIRROR, DELETE)
        -- ====================================================================
        local opRow = vgui.Create("DPanel", controlsContainer)
        opRow:Dock(TOP)
        opRow:DockMargin(0, 0, 0, 10)
        opRow:SetTall(28)
        opRow.Paint = function() end

        local function AddOpBtn(label, color, onClick)
            local btn = vgui.Create("DButton", opRow)
            btn:Dock(LEFT)
            btn:DockMargin(0, 0, 5, 0)
            btn:SetWide(110)
            btn:SetText(label)
            btn:SetTextColor(Color(240, 240, 240))
            btn.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(color.r + 20, color.g + 20, color.b + 20) or color)
            end
            btn.DoClick = onClick
        end

        AddOpBtn("Duplicate", Color(70, 60, 95), function()
            if not curComp then return end
            PushUndo()
            local clone = table.Copy(curComp)
            clone.id    = clone.id .. "_copy"
            clone.name  = clone.name .. " (Copy)"
            clone.pos   = clone.pos + Vector(0, 5, 0)
            table.insert(components, clone)
            TIV.Editor3D.SelectedIndex = #components
            RefreshEditor()
        end)

        AddOpBtn("Mirror (X)", Color(95, 75, 45), function()
            if not curComp then return end
            PushUndo()
            local mirror = table.Copy(curComp)
            mirror.id    = mirror.id .. "_mirror"
            mirror.name  = mirror.name .. " (Mirrored)"
            mirror.pos   = Vector(-mirror.pos.x, mirror.pos.y, mirror.pos.z)
            local hasAngledUpg = TIV.Progression and TIV.Progression.IsUnlocked and TIV.Progression.IsUnlocked("angled_spikes")
            if curComp.type == "spike" then
                if hasAngledUpg and math.abs(mirror.ang.p - 90) < 45 then
                    mirror.ang = Angle(180 - mirror.ang.p, -mirror.ang.y, -mirror.ang.r)
                else
                    mirror.ang = Angle(90, 0, 0)
                end
            else
                mirror.ang = Angle(mirror.ang.p, -mirror.ang.y, -mirror.ang.r)
            end
            table.insert(components, mirror)
            TIV.Editor3D.SelectedIndex = #components
            RefreshEditor()
        end)

        if #components > 1 then
            local delBtn = vgui.Create("DButton", opRow)
            delBtn:Dock(RIGHT)
            delBtn:SetWide(55)
            delBtn:SetText("DEL")
            delBtn:SetTextColor(Color(255, 120, 120))
            delBtn.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(180, 40, 40) or Color(70, 30, 30))
            end
            delBtn.DoClick = function()
                PushUndo()
                table.remove(components, selIdx)
                TIV.Editor3D.SelectedIndex = math.Clamp(selIdx - 1, 1, #components)
                TIV.Editor3D.ClearClientsideModels()
                RefreshEditor()
            end
        end

        if not curComp then return end

        -- ====================================================================
        -- TOOL ROW 4: QUICK-ALIGNMENT, SNAPPING & ORIENTATION TOOLS
        -- ====================================================================
        local alignPanel = vgui.Create("DPanel", controlsContainer)
        alignPanel:Dock(TOP)
        alignPanel:DockMargin(0, 0, 0, 10)
        alignPanel:SetTall(32)
        alignPanel.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(16, 20, 28, 200))
        end

        local function AddAlignBtn(label, onClick)
            local btn = vgui.Create("DButton", alignPanel)
            btn:Dock(LEFT)
            btn:DockMargin(4, 4, 4, 4)
            btn:SetWide(82)
            btn:SetText(label)
            btn:SetTextColor(Color(220, 230, 245))
            btn.Paint = function(s, w, h)
                draw.RoundedBox(3, 0, 0, w, h, s:IsHovered() and Color(50, 75, 110) or Color(26, 32, 45))
            end
            btn.DoClick = onClick
        end

        AddAlignBtn("Snap Grid", function()
            PushUndo()
            local step = TIV.Editor3D.StepSize or 1.0
            curComp.pos.x = math.Round(curComp.pos.x / step) * step
            curComp.pos.y = math.Round(curComp.pos.y / step) * step
            curComp.pos.z = math.Round(curComp.pos.z / step) * step
            RefreshEditor()
            surface.PlaySound("buttons/button14.wav")
        end)

        AddAlignBtn("Ground (Z=0)", function()
            PushUndo()
            curComp.pos.z = 0.0
            RefreshEditor()
            surface.PlaySound("buttons/button14.wav")
        end)

        AddAlignBtn("Level Flat", function()
            PushUndo()
            curComp.ang.p = 0.0
            curComp.ang.r = 0.0
            RefreshEditor()
            surface.PlaySound("buttons/button14.wav")
        end)

        AddAlignBtn("Turn 90° CW", function()
            PushUndo()
            curComp.ang.y = math.NormalizeAngle(curComp.ang.y + 90)
            RefreshEditor()
            surface.PlaySound("buttons/button14.wav")
        end)

        AddAlignBtn("Turn 90° CCW", function()
            PushUndo()
            curComp.ang.y = math.NormalizeAngle(curComp.ang.y - 90)
            RefreshEditor()
            surface.PlaySound("buttons/button14.wav")
        end)

        AddAlignBtn("Flip 180°", function()
            PushUndo()
            curComp.ang.y = math.NormalizeAngle(curComp.ang.y + 180)
            RefreshEditor()
            surface.PlaySound("buttons/button14.wav")
        end)

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
            PushUndo()
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
            PushUndo()
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
                PushUndo()
                local val = tonumber(s:GetText()) or 0
                UpdateVal(val)
            end

            -- Step nudge buttons using active step multiplier
            local step = TIV.Editor3D.StepSize or 1.0
            local btnMinus = vgui.Create("DButton", parent)
            btnMinus:SetPos(316, yOffset)
            btnMinus:SetSize(42, 22)
            btnMinus:SetText(string.format("-%g", step))
            btnMinus.DoClick = function()
                PushUndo()
                UpdateVal(curComp.pos[axisKey] - step)
            end

            local btnPlus = vgui.Create("DButton", parent)
            btnPlus:SetPos(362, yOffset)
            btnPlus:SetSize(42, 22)
            btnPlus:SetText(string.format("+%g", step))
            btnPlus.DoClick = function()
                PushUndo()
                UpdateVal(curComp.pos[axisKey] + step)
            end
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
        local hasAngledUpg = TIV.Progression and TIV.Progression.IsUnlocked and TIV.Progression.IsUnlocked("angled_spikes")
        local isAngleLocked = isSpike and not hasAngledUpg

        -- Enforce straight 90 degree spikes if upgrade is not unlocked
        if isAngleLocked then
            curComp.ang = Angle(90, 0, 0)
        end

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
                PushUndo()
                local val = tonumber(s:GetText()) or 0
                UpdateVal(val)
            end

            local angStep = math.max((TIV.Editor3D.StepSize or 1.0) * 5, 0.5)
            local btnMinus = vgui.Create("DButton", parent)
            btnMinus:SetPos(316, yOffset)
            btnMinus:SetSize(42, 22)
            btnMinus:SetText(string.format("-%g°", angStep))
            btnMinus:SetEnabled(not isAngleLocked)
            btnMinus.DoClick = function()
                PushUndo()
                UpdateVal(curComp.ang[angKey] - angStep)
            end

            local btnPlus = vgui.Create("DButton", parent)
            btnPlus:SetPos(362, yOffset)
            btnPlus:SetSize(42, 22)
            btnPlus:SetText(string.format("+%g°", angStep))
            btnPlus:SetEnabled(not isAngleLocked)
            btnPlus.DoClick = function()
                PushUndo()
                UpdateVal(curComp.ang[angKey] + angStep)
            end
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
                PushUndo()
                curComp.ang = Angle(targetAng.p, targetAng.y, targetAng.r)
                RefreshEditor()
            end
        end

        AddSnapBtn("Straight Down", Angle(90, 0, 0))
        AddSnapBtn("Angled 10°",    (curComp.pos and curComp.pos.x > 0) and Angle(80, 0, 0) or Angle(100, 0, 0))
        AddSnapBtn("Angled 20°",    (curComp.pos and curComp.pos.x > 0) and Angle(70, 0, 0) or Angle(110, 0, 0))
        AddSnapBtn("Angled 30°",    (curComp.pos and curComp.pos.x > 0) and Angle(60, 0, 0) or Angle(120, 0, 0))
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
                if imported.vehicle_model and string.lower(imported.vehicle_model) ~= string.lower(curVehModel) then
                    SwitchToModel(imported.vehicle_model)
                end
                TIV.Editor3D.ActiveConfig = imported
                TIV.Editor3D.ActiveConfig.vehicle_model = curVehModel
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
        Derma_Query("Reset all components back to factory defaults for " .. string.GetFileFromFilename(curVehModel) .. "?", "Confirm Reset",
            "Reset", function()
                TIV.Editor3D.ActiveConfig = TIV.CustomConfig.GetDefaultConfig(curVehModel)
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
        config.vehicle_model = curVehModel
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
