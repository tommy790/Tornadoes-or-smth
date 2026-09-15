if !WireLib then return end

WireToolSetup.setCategory("GStorms")
WireToolSetup.open("gstorms_thermometer", "GStorms Thermometer", "gmod_wire_gstorms_thermometer", nil, "GStorms Thermometers") -- WireToolSetup.open pattern :contentReference[oaicite:4]{index=4}
WireToolSetup.SetupMax(3)

TOOL.Model = "models/Items/battery.mdl"

if CLIENT then
	language.Add("Tool.wire_gstorms_thermometer.name", "GStorms Thermometer (Wire)")
	language.Add("Tool.wire_gstorms_thermometer.desc", "Spawns A Wiremod Based GStorms Thermometer")
	language.Add("Tool.wire_gstorms_thermometer.0", "Left click to place.")
end

function TOOL:MakeEnt(ply, model, Ang, trace)
	return WireLib.MakeWireEnt(ply, {
		Class = "gmod_wire_gstorms_thermometer",
		Pos = trace.HitPos,
		Angle = Ang,
		Model = model
	}, self:GetConVars())
end

function TOOL.BuildCPanel(panel)
	panel:AddControl( "Header", { Description = "Spawns A Wiremod Based GStorms Thermometer... Supports Inputs & Outputs" } )
end
