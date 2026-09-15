include("autorun/client/gstorms_config_menu.lua")

TOOL.Tab = "GStorms"
TOOL.Category = "99_gstorms_tools"
TOOL.Name = "#tool.gstorms_wind_resistance.name"
TOOL.ClientConVar = {windresistance = "65", invulnerability = "0"}

local windResistMin = 65
local windResistMax = 320
local windResistInfinite = 2147483647

if CLIENT then
    language.Add("tool.gstorms_wind_resistance.name", GSSortText(3, "Wind Resistance"))
    language.Add("tool.gstorms_wind_resistance.desc", "Applies a minimum threshold for props to get unfrozen and their constraints removed by winds")
    language.Add("tool.gstorms_wind_resistance.0", "Left click: Apply | Right click: Copy | Reload: Remove")
    language.Add("tool.gstorms_wind_resistance.1", "Wind resistance applied.")
    language.Add("tool.gstorms_wind_resistance.2", "Wind resistance removed.")
    language.Add("tool.gstorms_wind_resistance.3", "Wind resistance copied.")
end

local function GSIsValidProp(ent)
    if !ent or !ent:IsValid() or ent:IsPlayer() or ent:IsNPC() then return false end
    if ent:IsWorld() then return false end

    local phys = ent:GetPhysicsObject()
    if !phys:IsValid() then return false end

    return true
end

local function GSSanitizeWindResistance(value, preventUnwelding)
    if preventUnwelding then return windResistInfinite end

    value = tonumber(value)
    if value == nil then return nil end
    if value == windResistInfinite then return windResistInfinite end

    return math.Clamp(value, windResistMin, windResistMax)
end

if SERVER then

    duplicator.RegisterEntityModifier("gstorms_wind_resistance", function(ply, ent, data)
        if !ent:IsValid() or !data then return end

        if data.GSWindResistance == nil then
            ent.GSWindResistance = nil
            ent:SetNW2Int("GSWindResistance", 0)
            return
        end

        local windResistance = GSSanitizeWindResistance(data.GSWindResistance, data.GSPreventUnwelding == true)
        ent.GSWindResistance = windResistance
        ent:SetNW2Int("GSWindResistance", windResistance or 0)
    end)

end

function TOOL:LeftClick(trace)

    if CLIENT then return true end

    local ent = trace.Entity
    if !GSIsValidProp(ent) then return false end

    local preventUnwelding = self:GetClientNumber("invulnerability", 0) == 1
    local windResistance = GSSanitizeWindResistance(self:GetClientNumber("windresistance", windResistMin), preventUnwelding)

    ent.GSWindResistance = windResistance
    ent:SetNW2Int("GSWindResistance", windResistance or 0)

    duplicator.StoreEntityModifier(ent, "gstorms_wind_resistance", {
        GSWindResistance = windResistance,
        GSPreventUnwelding = windResistance == windResistInfinite
    })

    return true

end

function TOOL:RightClick(trace)

    if CLIENT then return true end

    local ent = trace.Entity
    if !GSIsValidProp(ent) then return false end

    local windResistance = ent.GSWindResistance or ent:GetNW2Int("GSWindResistance", 0)
    if windResistance <= 0 then return true end

    local infinite = windResistance == windResistInfinite
    if !infinite then
        windResistance = math.Clamp(tonumber(windResistance) or 0, windResistMin, windResistMax)
    end

    net.Start("gs_wind_resistance_copy")
    net.WriteBool(infinite)

    if !infinite then
        net.WriteUInt(windResistance, 9)
    end

    net.Send(self:GetOwner())

    return true

end

function TOOL:Reload(trace)

    if CLIENT then return true end

    local ent = trace.Entity
    if !GSIsValidProp(ent) then return false end

    ent.GSWindResistance = nil
    ent:SetNW2Int("GSWindResistance", 0)

    duplicator.ClearEntityModifier(ent, "gstorms_wind_resistance")

    return true

end

function TOOL.BuildCPanel(panel)
    GSAddCollapsibleSection(panel, "Wind Resistance Options", true, function(option)
        option:CheckBox("Enable Invulnerability", "gstorms_wind_resistance_invulnerability"):SetTooltip("Disables unfreezing and unwelding for the prop making it immune to all wind speeds.")
        option:NumSlider("Wind Resistance (MPH)", "gstorms_wind_resistance_windresistance", windResistMin, windResistMax, 0):SetTooltip("Applies a minimum threshold for props to get their constraints removed by winds, left click to apply wind resistance, right click to copy wind resistance, reload to remove it and have it behave normally.")
    end)
end

if CLIENT then

    local toolMode = "gstorms_wind_resistance"

    cvars.AddChangeCallback("gstorms_wind_resistance_windresistance", function(_, _, newValue)
        local clamped = math.Clamp(tonumber(newValue) or windResistMin, windResistMin, windResistMax)
        local clampedStr = tostring(math.floor(clamped))

        if newValue != clampedStr then
            RunConsoleCommand("gstorms_wind_resistance_windresistance", clampedStr)
        end
    end, "gstorms_wind_resistance_clamp")

    hook.Add("HUDPaint", "gstorms_wind_resistance_hoverhud", function()

        local ply = LocalPlayer()
        if !ply:IsValid() then return end

        local wep = ply:GetActiveWeapon()
        if !wep:IsValid() or wep:GetClass() != "gmod_tool" then return end

        local mode = wep.GetMode and wep:GetMode() or wep.Mode
        if mode != toolMode then return end

        local tr = ply:GetEyeTrace()
        local ent = tr.Entity

        if !ent or !ent:IsValid() or ent:IsWorld() then return end

        local windResistance = ent:GetNW2Int("GSWindResistance", 0)
        local txt = "Wind Resistance: -"

        if windResistance == windResistInfinite then
            txt = "Wind Resistance: Infinite"
        elseif windResistance > 0 then
            txt = "Wind Resistance: " .. tostring(windResistance) .. " MPH"
        end

        local pos = (tr.HitPos + Vector(0, 0, 10)):ToScreen()

        draw.WordBox(8, math.floor(pos.x), math.floor(pos.y), txt, "DermaDefaultBold", Color(0, 0, 0, 200), color_white)

    end)

    net.Receive("gs_wind_resistance_copy", function()

        local infinite = net.ReadBool()

        RunConsoleCommand("gstorms_wind_resistance_invulnerability", infinite and "1" or "0")

        if !infinite then
            local windResistance = net.ReadUInt(9)
            if windResistance <= 0 then return end

            RunConsoleCommand("gstorms_wind_resistance_windresistance", tostring(windResistance))
        end

    end)

end